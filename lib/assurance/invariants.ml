(* Faithful OCaml port of Anvil's sixteen VReplicaSet safety StatePreds, as pure
   {!Cluster.cluster_state} predicates for the P4 property harness. Source lines
   index the shallow Anvil clone; the per-invariant statements are transcribed
   from the [proof/] tree (objects_in_store.rs, controller_runtime_safety.rs,
   vreplicaset_controller/proof/{predicate.rs, helper_invariants/predicate.rs,
   guarantee.rs} and trusted/liveness_theorem.rs).

   Two proof regimes, two exposed buckets (they must NOT be asserted the same
   way):

   * {!always}: proved inductive from init by a [lemma_always_*], so it holds
     after every step of any trace. Safe to assert after each step from a valid
     seed. Members: #1 #2 #3 #4 #5 #6 #9 #15 #16.

   * {!eventually_always}: proved only as [lemma_eventually_always_*] /
     [leads_to_always] under crash + req_drop + pod_monkey disabled and weak
     fairness, so it holds only on the fair SUFFIX (at quiescence), never after
     every step of an unfair trace. Members: #7 #8 #10 #12 #13 #14. The three
     load-bearing Anvil lemmas are
     [lemma_eventually_always_no_other_pending_request_interferes_with_reconcile]
     (helper_invariants/proof.rs:24, requires crash + req_drop + pod_monkey
     disabled + fair) for #8,
     [lemma_true_leads_to_always_every_msg_from_key_is_pending_req_msg_of]
     (controller_runtime_safety.rs:927, requires crash disabled) for #10, and
     [lemma_eventually_always_no_pending_mutation_request_not_from_controller_on_pods]
     (helper_invariants/proof.rs:653, requires crash disabled) for #14.

   Convention firewall (anvil-ocaml): no loop keywords (List/Option/Result
   combinators only), no [_ ->] catch-all on any finite sum, no two-arm match on
   option/result (Option.fold / Result.fold), no exceptions. Every predicate is a
   total [bool]; every fallible decode goes through {!Res.t} via [Result.fold].

   #12 inductive_current_state_matches now renders Anvil's LITERAL conjunctive form
   (predicate.rs:502): [current_state_matches(vrs) AND (ongoing ==> step-shape)]
   (line 504 conjoins [current_state_matches], the ESR liveness goal #11, which is
   false on transient states: 0 pods while desired > 0, and at After_create_pod /
   After_delete_pod). The top-level [current_state_matches] conjunct — re-derived
   from the very {!current_state_matches} helper #11/{!liveness_goal} use, so the
   two agree — is asserted, and the step-shape is a CONJUNCT that fires whenever an
   ongoing reconcile exists rather than an off-goal implication hollowed to vacuity.
   Anvil never proves it from init; it only appears as the [post] of a
   [leads_to(always(post))] inside the ESR-stability lemma (liveness/
   resource_match.rs ~2874/2880, hypotheses crash + req_drop + pod_monkey disabled
   + weak fairness + desired_state_is at 2848-2853; preservation lemma
   resource_match.rs:2965). Because the [current_state_matches] conjunct is false
   off-goal, #12 lives in the {!eventually_always} bucket and must be asserted only
   at quiescence on ~fair:true traces (never after every step of a ~fair:false
   trace). *)

type invariant = {
  name : string;
  source : string;
  holds : Cluster.cluster_state -> bool;
  interesting : Cluster.cluster_state -> bool;
}

(* -- shared, controller-id-independent helpers (reused by #11 and #12) -------- *)

let vrs_ref_of (cr : Vreplica_set.t) : Common.object_ref =
  let md : Object_meta.t = Vreplica_set.metadata cr in
  Result.fold (Vreplica_set.object_ref cr) ~ok:Fun.id ~error:(fun _ ->
      {
        Common.kind = Vreplica_set.kind;
        name = Option.value ~default:"" md.name;
        namespace = Option.value ~default:"" md.namespace;
      })

(* Anvil owned_selector_match_is (liveness_theorem.rs:56): a stored object is a
   vrs-owned pod iff PodKind, vrs name-prefix, namespace == vrs ns, owner refs
   contain the vrs controller-owner ref, labels match the selector, no deletion
   timestamp. Over {!Dynamic_object.t} (the etcd value), not the typed pod. *)
let owned_selector_match_is (cr : Vreplica_set.t) (obj : Dynamic_object.t) : bool =
  let md : Object_meta.t = Dynamic_object.metadata obj in
  let vns = (Vreplica_set.metadata cr).namespace in
  Common.equal_kind (Dynamic_object.kind obj) Pod.kind
  && Option.fold md.name ~none:false ~some:Vreplica_set_reconciler.has_vrs_prefix
  && Option.is_some md.namespace
  && Option.equal String.equal md.namespace vns
  && Option.fold (Vreplica_set.controller_owner_ref cr) ~none:false
       ~some:(Object_meta.owner_references_contains md)
  && Label_selector.matches (Vreplica_set.spec cr).selector
       (Option.value ~default:Smap.empty md.labels)
  && Option.is_none md.deletion_timestamp

(* Anvil matching_pods (liveness_theorem.rs:52): resources.values() filtered. *)
let matching_pods (cr : Vreplica_set.t) (s : Cluster.cluster_state) :
    Dynamic_object.t list =
  List.filter (owned_selector_match_is cr)
    (List.map snd (Object_ref_map.bindings (Cluster.resources s)))

(* Anvil current_state_matches (liveness_theorem.rs:21) = digest #11 (the ESR
   liveness GOAL, false on transient states): the vrs is in etcd, |matching_pods|
   equals the desired replica count, and the stored vrs status.replicas equals its
   own spec.replicas (default 1). *)
let current_state_matches (cr : Vreplica_set.t) (s : Cluster.cluster_state) : bool
    =
  let vrs_ref = vrs_ref_of cr in
  Option.fold
    (Object_ref_map.find_opt vrs_ref (Cluster.resources s))
    ~none:false
    ~some:(fun obj ->
      Result.fold (Vreplica_set.unmarshal obj) ~error:(fun _ -> false)
        ~ok:(fun evrs ->
          List.length (matching_pods cr s)
          = Option.value ~default:1 (Vreplica_set.spec cr).replicas
          && Option.fold (Vreplica_set.status evrs) ~none:false
               ~some:(fun (vs : Vreplica_set.vrs_status) ->
                 vs.replicas
                 = Option.value ~default:1 (Vreplica_set.spec evrs).replicas)))

(* Invariant #6 [every_ongoing_reconcile_has_unique_id]
   (kubernetes_cluster/proof/controller_runtime_safety.rs:874) as a standalone
   top-level handle: the SINGLE source of truth referenced by both
   {!cluster_structural} and {!partition} (and the P12 non-vacuity gate). Over
   [Cluster.ongoing_reconciles s controller_id], every ongoing reconcile's
   [reconcile_id] is distinct; [interesting] fires iff >= 2 concurrent ongoing
   reconciles exist for [controller_id] — the P12 witness. *)
let unique_reconcile_id_invariant ~(controller_id : int) : invariant =
  let ongoing s = Cluster.ongoing_reconciles s controller_id in
  {
    name = "every_ongoing_reconcile_has_unique_id";
    source = "kubernetes_cluster/proof/controller_runtime_safety.rs:874";
    holds =
      (fun s ->
        let ids =
          List.map
            (fun (_k, (orc : Controller.ongoing_reconcile)) -> orc.reconcile_id)
            (Object_ref_map.bindings (ongoing s))
        in
        List.length (List.sort_uniq compare ids) = List.length ids);
    (* NB: only non-vacuous with >= 2 concurrent reconciles. *)
    interesting = (fun s -> Object_ref_map.cardinal (ongoing s) >= 2);
  }

(* GAP-2 (BUILD-SPEC-P11 §4): the shared cluster-level etcd/runtime-safety
   invariants inv1-6, independent of any CR (sourced from Anvil's
   [kubernetes_cluster] proofs, NOT [vreplicaset_controller]). Both {!always}
   (via {!partition}) and [Vsts_invariants] reuse this ONE per-controller source.

   Firewall-sanctioned FALLBACK (spec §4 / P11 Files note): rather than re-wiring
   the large {!partition}, this carries its own copy of the (cr-free) generic
   helpers + inv1-6 bodies — the exact bodies {!partition} builds — so {!always}'s
   observable result is unchanged (partition is left untouched) while the shared
   inv1-6 are exported once for the VSTS leg. *)
let cluster_structural ~controller_id =
  let resources s = Cluster.resources s in
  let etcd_objs s = List.map snd (Object_ref_map.bindings (Cluster.resources s)) in
  let scheduled s = Cluster.scheduled_reconciles s controller_id in
  let ongoing s = Cluster.ongoing_reconciles s controller_id in
  let uidc (s : Cluster.cluster_state) = s.api_server.uid_counter in
  let rvc (s : Cluster.cluster_state) = s.api_server.resource_version_counter in
  (* ---- #1 etcd_objects_have_unique_uids -------------------------------- *)
  let inv1 =
    {
      name = "etcd_objects_have_unique_uids";
      source = "kubernetes_cluster/proof/objects_in_store.rs:23";
      holds =
        (fun s ->
          (* P17 Deliverable-A fidelity fix (Objects_in_store audit): upstream
             compares the TOTAL projection [uid->0] (objects_in_store.rs:29),
             under which Verus's [None->0] is ONE fixed (unspecified) value —
             so two stored objects with [uid = None] have EQUAL projections
             and VIOLATE S1 upstream. The previous [filter_map] dropped them
             (port weaker than upstream). [-1] renders that single [None]
             projection: it sits outside the minted range ([uid_counter]
             stamping, api_server.ml:272; every SHIPPED seed floors the
             counters at >= 1 - the type admits no init floor,
             api_server.mli:72), so two [None]s
             collide exactly as upstream while a [None]/[Some] pair stays
             distinct (upstream that case is unprovable either way; [-1] is a
             representative of the unique minted-range-consistent extension
             CLASS - any out-of-minted-range sentinel is extensionally
             identical on minted-uid states). Latent under
             inv2 (which forces [uid] [Some] on every stored object), hence
             extensionally unchanged on every inv2-green graph. *)
          let uids =
            List.map
              (fun obj ->
                let md : Object_meta.t = Dynamic_object.metadata obj in
                Option.fold md.uid ~none:(-1) ~some:Common.Uid.to_int)
              (etcd_objs s)
          in
          List.length (List.sort_uniq compare uids) = List.length uids);
      interesting = (fun s -> Object_ref_map.cardinal (resources s) >= 2);
    }
  in
  (* ---- #2 each_object_in_etcd_is_weakly_well_formed --------------------- *)
  let inv2 =
    {
      name = "each_object_in_etcd_is_weakly_well_formed";
      source = "kubernetes_cluster/proof/objects_in_store.rs:33";
      holds =
        (fun s ->
          Object_ref_map.for_all
            (fun key obj ->
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Object_meta.well_formed_for_namespaced md
              && Result.fold (Dynamic_object.object_ref obj)
                   ~error:(fun _ -> false)
                   ~ok:(fun r -> Common.equal_object_ref r key)
              && Option.fold md.resource_version ~none:false ~some:(fun rv ->
                     Common.Resource_version.to_int rv < rvc s)
              && Option.fold md.uid ~none:false ~some:(fun u ->
                     Common.Uid.to_int u < uidc s))
            (resources s));
      interesting = (fun s -> not (Object_ref_map.is_empty (resources s)));
    }
  in
  (* ---- #3 each_object_in_etcd_has_at_most_one_controller_owner ---------- *)
  let inv3 =
    {
      name = "each_object_in_etcd_has_at_most_one_controller_owner";
      source = "kubernetes_cluster/proof/objects_in_store.rs:299";
      holds =
        (fun s ->
          Object_ref_map.for_all
            (fun _key obj ->
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Option.fold md.owner_references ~none:true ~some:(fun orefs ->
                  List.length (List.filter Owner_reference.is_controller orefs)
                  <= 1))
            (resources s));
      interesting =
        (fun s ->
          List.exists
            (fun obj ->
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Option.fold md.owner_references ~none:false ~some:(fun orefs ->
                  List.exists Owner_reference.is_controller orefs))
            (etcd_objs s));
    }
  in
  (* ---- #4 scheduled_cr_has_lower_uid_than_uid_counter ------------------- *)
  let inv4 =
    {
      name = "scheduled_cr_has_lower_uid_than_uid_counter";
      source = "kubernetes_cluster/proof/controller_runtime_safety.rs:15";
      holds =
        (fun s ->
          Object_ref_map.for_all
            (fun _key obj ->
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Option.fold md.uid ~none:false ~some:(fun u ->
                  Common.Uid.to_int u < uidc s))
            (scheduled s));
      interesting = (fun s -> not (Object_ref_map.is_empty (scheduled s)));
    }
  in
  (* ---- #5 triggering_cr_has_lower_uid_than_uid_counter ------------------ *)
  let inv5 =
    {
      name = "triggering_cr_has_lower_uid_than_uid_counter";
      source = "kubernetes_cluster/proof/controller_runtime_safety.rs:47";
      holds =
        (fun s ->
          Object_ref_map.for_all
            (fun _key (orc : Controller.ongoing_reconcile) ->
              let md : Object_meta.t = Dynamic_object.metadata orc.triggering_cr in
              Option.fold md.uid ~none:false ~some:(fun u ->
                  Common.Uid.to_int u < uidc s))
            (ongoing s));
      interesting = (fun s -> not (Object_ref_map.is_empty (ongoing s)));
    }
  in
  (* ---- #6 every_ongoing_reconcile_has_unique_id ------------------------ *)
  let inv6 = unique_reconcile_id_invariant ~controller_id in
  [ inv1; inv2; inv3; inv4; inv5; inv6 ]

(* Builds every record once and returns the authoritative partition as
   [(always, eventually_always)]; the three exposed lists below derive from it so
   they never drift. *)
let partition ~cr ~controller_id =
  let vrs_ref : Common.object_ref = vrs_ref_of cr in
  let vrs_md : Object_meta.t = Vreplica_set.metadata cr in
  let vrs_ns_opt = vrs_md.namespace in
  let vrs_ns = Option.value ~default:"" vrs_ns_opt in
  let vrs_kind = Vreplica_set.kind in
  let co = Vreplica_set.controller_owner_ref cr in
  let contains_co (md : Object_meta.t) =
    Option.fold co ~none:false ~some:(Object_meta.owner_references_contains md)
  in
  let neq_co oref =
    not (Option.fold co ~none:false ~some:(fun c -> Owner_reference.equal c oref))
  in
  let resources s = Cluster.resources s in
  let etcd_objs s = List.map snd (Object_ref_map.bindings (Cluster.resources s)) in
  let ongoing s = Cluster.ongoing_reconciles s controller_id in
  let scheduled s = Cluster.scheduled_reconciles s controller_id in
  let msgs s = Message.Pool.distinct (Cluster.in_flight s) in
  let uidc (s : Cluster.cluster_state) = s.api_server.uid_counter in
  let rvc (s : Cluster.cluster_state) = s.api_server.resource_version_counter in

  (* message classification (Anvil HostId / MessageContent discriminants) *)
  let is_apiserver_dst (m : Message.t) =
    Message.equal_host_id m.dst Message.Api_server
  in
  let is_src_controller_key (m : Message.t) =
    Message.equal_host_id m.src (Message.Controller (controller_id, vrs_ref))
  in
  let src_is_builtin (m : Message.t) =
    match m.src with
    | Message.Builtin_controller -> true
    | Message.Api_server | Message.Controller _ | Message.External _
    | Message.Pod_monkey ->
      false
  in
  let src_is_controller (m : Message.t) =
    match m.src with
    | Message.Controller _ -> true
    | Message.Api_server | Message.Builtin_controller | Message.External _
    | Message.Pod_monkey ->
      false
  in
  let apireq (m : Message.t) : Api_method.api_request option =
    match m.content with
    | Message.Api_request r -> Some r
    | Message.Api_response _ | Message.External_request _
    | Message.External_response _ ->
      None
  in
  let is_delete_req (m : Message.t) =
    let open Api_method in
    match m.content with
    | Message.Api_request (Delete_request _) -> true
    | Message.Api_request
        ( Get_request _ | List_request _ | Create_request _ | Update_request _
        | Update_status_request _ | Get_then_delete_request _
        | Get_then_update_request _ | Get_then_update_status_request _ ) ->
      false
    | Message.Api_response _ | Message.External_request _
    | Message.External_response _ ->
      false
  in
  let list_req_content_matches (m : Message.t) ~namespace =
    let open Api_method in
    match m.content with
    | Message.Api_request (List_request lr) ->
      Common.equal_kind lr.kind Pod.kind && String.equal lr.namespace namespace
    | Message.Api_request
        ( Get_request _ | Create_request _ | Delete_request _ | Update_request _
        | Update_status_request _ | Get_then_delete_request _
        | Get_then_update_request _ | Get_then_update_status_request _ ) ->
      false
    | Message.Api_response _ | Message.External_request _
    | Message.External_response _ ->
      false
  in
  let list_resp_objs (m : Message.t) : Dynamic_object.t list option =
    let open Api_method in
    match m.content with
    | Message.Api_response (List_response lr) -> Result.to_option lr.res
    | Message.Api_response
        ( Get_response _ | Create_response _ | Delete_response _
        | Update_response _ | Update_status_response _ | Get_then_delete_response _
        | Get_then_update_response _ | Get_then_update_status_response _ ) ->
      None
    | Message.Api_request _ | Message.External_request _
    | Message.External_response _ ->
      None
  in
  let ok_list_resps_for s req_msg =
    List.filter
      (fun (m : Message.t) ->
        Message.equal_host_id m.src Message.Api_server
        && Message.resp_msg_matches_req_msg m req_msg
        && Option.is_some (list_resp_objs m))
      (msgs s)
  in
  (* a reconcile whose pending request is the After_list_pods list-pods request,
     with every matching ok list-response passing [resp_check]. *)
  let pending_list_req_ok (orc : Controller.ongoing_reconcile) ~namespace
      ~resp_check s =
    Option.fold orc.pending_req_msg ~none:false ~some:(fun (rm : Message.t) ->
        Message.equal_host_id rm.dst Message.Api_server
        && list_req_content_matches rm ~namespace
        && List.for_all resp_check (ok_list_resps_for s rm))
  in
  (* decode the vrs reconcile-state (Value.t -> typed s) at the vrs key. *)
  let decoded_ongoing s =
    Option.bind
      (Object_ref_map.find_opt vrs_ref (ongoing s))
      (fun (orc : Controller.ongoing_reconcile) ->
        Result.fold
          (Vreplica_set_pack.unmarshal_state orc.local_state)
          ~error:(fun _ -> None)
          ~ok:(fun st -> Some (orc, st)))
  in
  (* etcd object at [key] is a same-rv, vrs-owned object in the vrs namespace
     (Anvil's "Prevents 1" block, shared by update / update_status / delete). *)
  let etcd_owned_rv s key (rv : Common.Resource_version.t option) =
    Option.fold (Object_ref_map.find_opt key (resources s)) ~none:false
      ~some:(fun eo ->
        let em : Object_meta.t = Dynamic_object.metadata eo in
        Option.equal String.equal em.namespace vrs_ns_opt
        && Option.is_some em.resource_version
        && Option.equal Common.Resource_version.equal em.resource_version rv
        && Option.is_some em.owner_references
        && contains_co em)
  in

  (* ---- #1 etcd_objects_have_unique_uids ---------------------------------- *)
  let inv1 =
    {
      name = "etcd_objects_have_unique_uids";
      source = "kubernetes_cluster/proof/objects_in_store.rs:23";
      holds =
        (fun s ->
          (* P17 Deliverable-A fidelity fix — same total-[uid->0] rendering as
             the {!cluster_structural} copy above (see the comment there); the
             firewall doc (:140-144) requires the two bodies to stay exact. *)
          let uids =
            List.map
              (fun obj ->
                let md : Object_meta.t = Dynamic_object.metadata obj in
                Option.fold md.uid ~none:(-1) ~some:Common.Uid.to_int)
              (etcd_objs s)
          in
          List.length (List.sort_uniq compare uids) = List.length uids);
      interesting = (fun s -> Object_ref_map.cardinal (resources s) >= 2);
    }
  in
  (* ---- #2 each_object_in_etcd_is_weakly_well_formed ---------------------- *)
  let inv2 =
    {
      name = "each_object_in_etcd_is_weakly_well_formed";
      source = "kubernetes_cluster/proof/objects_in_store.rs:33";
      holds =
        (fun s ->
          Object_ref_map.for_all
            (fun key obj ->
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Object_meta.well_formed_for_namespaced md
              && Result.fold (Dynamic_object.object_ref obj)
                   ~error:(fun _ -> false)
                   ~ok:(fun r -> Common.equal_object_ref r key)
              && Option.fold md.resource_version ~none:false ~some:(fun rv ->
                     Common.Resource_version.to_int rv < rvc s)
              && Option.fold md.uid ~none:false ~some:(fun u ->
                     Common.Uid.to_int u < uidc s))
            (resources s));
      interesting = (fun s -> not (Object_ref_map.is_empty (resources s)));
    }
  in
  (* ---- #3 each_object_in_etcd_has_at_most_one_controller_owner ----------- *)
  let inv3 =
    {
      name = "each_object_in_etcd_has_at_most_one_controller_owner";
      source = "kubernetes_cluster/proof/objects_in_store.rs:299";
      holds =
        (fun s ->
          Object_ref_map.for_all
            (fun _key obj ->
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Option.fold md.owner_references ~none:true ~some:(fun orefs ->
                  List.length (List.filter Owner_reference.is_controller orefs)
                  <= 1))
            (resources s));
      interesting =
        (fun s ->
          List.exists
            (fun obj ->
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Option.fold md.owner_references ~none:false ~some:(fun orefs ->
                  List.exists Owner_reference.is_controller orefs))
            (etcd_objs s));
    }
  in
  (* ---- #4 scheduled_cr_has_lower_uid_than_uid_counter -------------------- *)
  let inv4 =
    {
      name = "scheduled_cr_has_lower_uid_than_uid_counter";
      source = "kubernetes_cluster/proof/controller_runtime_safety.rs:15";
      holds =
        (fun s ->
          Object_ref_map.for_all
            (fun _key obj ->
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Option.fold md.uid ~none:false ~some:(fun u ->
                  Common.Uid.to_int u < uidc s))
            (scheduled s));
      interesting = (fun s -> not (Object_ref_map.is_empty (scheduled s)));
    }
  in
  (* ---- #5 triggering_cr_has_lower_uid_than_uid_counter ------------------- *)
  let inv5 =
    {
      name = "triggering_cr_has_lower_uid_than_uid_counter";
      source = "kubernetes_cluster/proof/controller_runtime_safety.rs:47";
      holds =
        (fun s ->
          Object_ref_map.for_all
            (fun _key (orc : Controller.ongoing_reconcile) ->
              let md : Object_meta.t = Dynamic_object.metadata orc.triggering_cr in
              Option.fold md.uid ~none:false ~some:(fun u ->
                  Common.Uid.to_int u < uidc s))
            (ongoing s));
      interesting = (fun s -> not (Object_ref_map.is_empty (ongoing s)));
    }
  in
  (* ---- #6 every_ongoing_reconcile_has_unique_id ------------------------- *)
  let inv6 = unique_reconcile_id_invariant ~controller_id in
  (* ---- #7 garbage_collector_does_not_delete_vrs_pods --------------------- *)
  let gc_ok (req : Api_method.api_request) s =
    let open Api_method in
    match req with
    | Delete_request r ->
      Option.fold r.preconditions ~none:false
        ~some:(fun (pc : Api_method.preconditions) ->
          Option.fold pc.uid ~none:false ~some:(fun u ->
              Common.Uid.to_int u < uidc s
              && Option.fold
                   (Object_ref_map.find_opt r.key (resources s))
                   ~none:true
                   ~some:(fun obj ->
                     let om : Object_meta.t = Dynamic_object.metadata obj in
                     (not
                        (contains_co om
                        && Common.equal_kind (Dynamic_object.kind obj) Pod.kind
                        && Option.equal String.equal om.namespace vrs_ns_opt))
                     || Option.fold om.uid ~none:false ~some:(fun ou ->
                            Common.Uid.to_int ou > Common.Uid.to_int u))))
    | Get_request _ | List_request _ | Create_request _ | Update_request _
    | Update_status_request _ | Get_then_delete_request _
    | Get_then_update_request _ | Get_then_update_status_request _ ->
      false
  in
  let inv7 =
    {
      name = "garbage_collector_does_not_delete_vrs_pods";
      source =
        "vreplicaset_controller/proof/helper_invariants/predicate.rs:316";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              if src_is_builtin m && is_apiserver_dst m then
                Option.fold (apireq m) ~none:true ~some:(fun req -> gc_ok req s)
              else true)
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) ->
              src_is_builtin m && is_apiserver_dst m && is_delete_req m)
            (msgs s));
    }
  in
  (* ---- #8 no_other_pending_request_interferes_with_vrs_reconcile --------- *)
  let interferes_ok (req : Api_method.api_request) s =
    let open Api_method in
    match req with
    | Get_request _ | List_request _ -> true
    | Create_request r ->
      let om : Object_meta.t = Dynamic_object.metadata r.obj in
      (not
         (Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind
         && String.equal r.namespace vrs_ns))
      || not (Option.is_some om.owner_references && contains_co om)
    | Update_request r ->
      let om : Object_meta.t = Dynamic_object.metadata r.obj in
      let key = Api_method.update_request_key r in
      (not
         (Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind
         && String.equal r.namespace vrs_ns))
      || Option.is_some om.resource_version
         && (not (etcd_owned_rv s key om.resource_version))
         && ((not (Option.is_some om.owner_references)) || not (contains_co om))
    | Update_status_request r ->
      let om : Object_meta.t = Dynamic_object.metadata r.obj in
      let key = Api_method.update_status_request_key r in
      ((not
          (Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind
          && String.equal r.namespace vrs_ns))
      || Option.is_some om.resource_version
         && not (etcd_owned_rv s key om.resource_version))
      && ((not (Common.equal_kind (Dynamic_object.kind r.obj) vrs_kind))
         || not (Common.equal_object_ref key vrs_ref))
    | Delete_request r ->
      (not
         (Common.equal_kind r.key.kind Pod.kind
         && String.equal r.key.namespace vrs_ns))
      || Option.fold r.preconditions ~none:false
           ~some:(fun (pc : Api_method.preconditions) ->
             Option.fold pc.resource_version ~none:false ~some:(fun rv ->
                 not (etcd_owned_rv s r.key (Some rv)))
             || Option.fold pc.uid ~none:false ~some:(fun u ->
                    Common.Uid.to_int u < uidc s
                    && Option.fold
                         (Object_ref_map.find_opt r.key (resources s))
                         ~none:true
                         ~some:(fun obj ->
                           let om : Object_meta.t = Dynamic_object.metadata obj in
                           (not
                              (contains_co om
                              && Common.equal_kind (Dynamic_object.kind obj)
                                   Pod.kind
                              && Option.equal String.equal om.namespace
                                   vrs_ns_opt))
                           || Option.fold om.uid ~none:false ~some:(fun ou ->
                                  Common.Uid.to_int ou > Common.Uid.to_int u))))
    | Get_then_update_request r ->
      let om : Object_meta.t = Dynamic_object.metadata r.obj in
      (not (Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind))
      || ((not (String.equal r.namespace vrs_ns))
         || Owner_reference.is_controller r.owner_ref && neq_co r.owner_ref)
         && ((not (Option.is_some om.owner_references)) || not (contains_co om))
    | Get_then_delete_request r ->
      (not
         (Common.equal_kind r.key.kind Pod.kind
         && String.equal r.key.namespace vrs_ns))
      || (Owner_reference.is_controller r.owner_ref && neq_co r.owner_ref)
    | Get_then_update_status_request r ->
      ((not (Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind))
      || not (Common.equal_kind r.owner_ref.kind vrs_kind))
      && ((not (Common.equal_kind (Dynamic_object.kind r.obj) vrs_kind))
         || not
              (Common.equal_object_ref
                 (Api_method.get_then_update_status_request_key r)
                 vrs_ref))
  in
  let inv8 =
    {
      name = "no_other_pending_request_interferes_with_vrs_reconcile";
      source =
        "vreplicaset_controller/proof/helper_invariants/predicate.rs:175";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              if is_apiserver_dst m && not (is_src_controller_key m) then
                Option.fold (apireq m) ~none:true ~some:(fun req ->
                    interferes_ok req s)
              else true)
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) ->
              is_apiserver_dst m
              && (not (is_src_controller_key m))
              && Option.is_some (apireq m))
            (msgs s));
    }
  in
  (* ---- #9 vrs_reconcile_request_only_interferes_with_itself -------------- *)
  let self_ok (req : Api_method.api_request) =
    let open Api_method in
    match req with
    | List_request _ -> true
    | Create_request r ->
      Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind
      && String.equal r.namespace vrs_ns
      &&
      let om : Object_meta.t = Dynamic_object.metadata r.obj in
      Option.fold om.owner_references ~none:false ~some:(fun orefs ->
          match orefs with
          | [ oref ] ->
            Owner_reference.is_controller oref
            && Common.equal_kind oref.kind vrs_kind
            && String.equal oref.name vrs_ref.name
          | [] | _ :: _ :: _ -> false)
    | Get_then_delete_request r ->
      Common.equal_kind r.key.kind Pod.kind
      && String.equal r.key.namespace vrs_ns
      && Owner_reference.is_controller r.owner_ref
      && Common.equal_kind r.owner_ref.kind vrs_kind
      && String.equal r.owner_ref.name vrs_ref.name
    | Get_then_update_status_request r ->
      Common.equal_object_ref
        (Api_method.get_then_update_status_request_key r)
        vrs_ref
    | Get_request _ | Update_request _ | Update_status_request _
    | Delete_request _ | Get_then_update_request _ ->
      false
  in
  let inv9 =
    {
      name = "vrs_reconcile_request_only_interferes_with_itself";
      source =
        "vreplicaset_controller/proof/helper_invariants/predicate.rs:237";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              if is_src_controller_key m then
                Option.fold (apireq m) ~none:true ~some:self_ok
              else true)
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) ->
              is_src_controller_key m && Option.is_some (apireq m))
            (msgs s));
    }
  in
  (* ---- #10 every_msg_from_key_is_pending_req_msg_of ---------------------- *)
  let inv10 =
    {
      name = "every_msg_from_key_is_pending_req_msg_of";
      source = "kubernetes_cluster/proof/controller_runtime_safety.rs:911";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              if is_src_controller_key m && is_apiserver_dst m then
                Option.fold (apireq m) ~none:true ~some:(fun _req ->
                    Option.fold
                      (Object_ref_map.find_opt vrs_ref (ongoing s))
                      ~none:false
                      ~some:(fun (orc : Controller.ongoing_reconcile) ->
                        Option.fold orc.pending_req_msg ~none:false
                          ~some:(fun pm -> Message.equal pm m)))
              else true)
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) ->
              is_src_controller_key m && Option.is_some (apireq m))
            (msgs s));
    }
  in
  (* ---- #12 inductive_current_state_matches (EVENTUALLY_ALWAYS; the literal
     conjunctive form [current_state_matches AND (ongoing ==> step-shape)] is now
     restored, faithful to predicate.rs:502/504, see module header) ------------ *)
  let resp12 resp =
    Option.fold (list_resp_objs resp) ~none:false ~some:(fun objs ->
        List.for_all (fun (o : Dynamic_object.t) -> Result.is_ok (Pod.unmarshal o))
          objs
        && List.for_all
             (fun (o : Dynamic_object.t) ->
               let om : Object_meta.t = Dynamic_object.metadata o in
               Option.is_some om.namespace
               && Option.equal String.equal om.namespace vrs_md.namespace)
             objs)
  in
  let after_update_status_shape (orc : Controller.ongoing_reconcile) =
    Option.fold orc.pending_req_msg ~none:false ~some:(fun (rm : Message.t) ->
        Message.equal_host_id rm.src (Message.Controller (controller_id, vrs_ref))
        && Message.equal_host_id rm.dst Message.Api_server
        &&
        let open Api_method in
        match rm.content with
        | Message.Api_request (Get_then_update_status_request r) ->
          Common.equal_object_ref
            (Api_method.get_then_update_status_request_key r)
            vrs_ref
          && Result.fold (Vreplica_set.unmarshal r.obj) ~error:(fun _ -> false)
               ~ok:(fun uv ->
                 Option.fold (Vreplica_set.status uv) ~none:false
                   ~some:(fun (vs : Vreplica_set.vrs_status) ->
                     vs.replicas
                     = Option.value ~default:1 (Vreplica_set.spec cr).replicas))
        | Message.Api_request
            ( Get_request _ | List_request _ | Create_request _ | Delete_request _
            | Update_request _ | Update_status_request _
            | Get_then_delete_request _ | Get_then_update_request _ ) ->
          false
        | Message.Api_response _ | Message.External_request _
        | Message.External_response _ ->
          false)
  in
  let inv12 =
    {
      name = "inductive_current_state_matches";
      source = "vreplicaset_controller/proof/predicate.rs:502";
      holds =
        (fun s ->
          current_state_matches cr s
          && Option.fold (decoded_ongoing s) ~none:true ~some:(fun (orc, st) ->
                 let open Vreplica_set_reconciler in
                 (match st.reconcile_step with
                 | Init | After_list_pods | After_update_vrs_status | Done | Error
                   ->
                   true
                 | After_create_pod _ | After_delete_pod _ -> false)
                 &&
                 match st.reconcile_step with
                 | After_list_pods ->
                   pending_list_req_ok orc ~namespace:vrs_ns ~resp_check:resp12 s
                 | After_update_vrs_status -> after_update_status_shape orc
                 | Init | Done | Error -> Option.is_none orc.pending_req_msg
                 | After_create_pod _ | After_delete_pod _ -> false));
      interesting = (fun s -> Object_ref_map.mem vrs_ref (ongoing s));
    }
  in
  (* ---- #13 vrs_in_schedule/reconcile_has_spec_and_uid_as ----------------- *)
  let spec_wo_repl_eq a b =
    Vreplica_set.vrs_spec_equal
      (Vreplica_set.spec_without_replicas (Vreplica_set.spec a))
      (Vreplica_set.spec_without_replicas (Vreplica_set.spec b))
  in
  let vrs_repl v = Option.value ~default:1 (Vreplica_set.spec v).replicas in
  let inv13 =
    {
      name = "vrs_in_schedule/reconcile_has_spec_and_uid_as";
      source =
        "vreplicaset_controller/proof/helper_invariants/predicate.rs:449,459";
      holds =
        (fun s ->
          let sched_ok =
            Option.fold
              (Object_ref_map.find_opt vrs_ref (scheduled s))
              ~none:true
              ~some:(fun dyn ->
                let dm : Object_meta.t = Dynamic_object.metadata dyn in
                Option.equal Common.Uid.equal dm.uid vrs_md.uid
                && Result.fold (Vreplica_set.unmarshal dyn)
                     ~error:(fun _ -> false)
                     ~ok:(fun svrs ->
                       spec_wo_repl_eq svrs cr && vrs_repl svrs = vrs_repl cr))
          in
          let ong_ok =
            Option.fold
              (Object_ref_map.find_opt vrs_ref (ongoing s))
              ~none:true
              ~some:(fun (orc : Controller.ongoing_reconcile) ->
                let tm : Object_meta.t =
                  Dynamic_object.metadata orc.triggering_cr
                in
                Option.equal Common.Uid.equal tm.uid vrs_md.uid
                && Result.fold
                     (Vreplica_set.unmarshal orc.triggering_cr)
                     ~error:(fun _ -> false)
                     ~ok:(fun tvrs ->
                       spec_wo_repl_eq tvrs cr && vrs_repl tvrs = vrs_repl cr))
          in
          sched_ok && ong_ok);
      interesting =
        (fun s ->
          Object_ref_map.mem vrs_ref (scheduled s)
          || Object_ref_map.mem vrs_ref (ongoing s));
    }
  in
  (* ---- #14 no_pending_mutation_request_not_from_controller_on_pods ------- *)
  let no_mutate_pod (req : Api_method.api_request) =
    let open Api_method in
    match req with
    | Create_request r ->
      not (Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind)
    | Update_request r ->
      not (Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind)
    | Update_status_request r ->
      not (Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind)
    | Delete_request r -> not (Common.equal_kind r.key.kind Pod.kind)
    | Get_then_delete_request r -> not (Common.equal_kind r.key.kind Pod.kind)
    | Get_then_update_request r ->
      not (Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind)
    | Get_request _ | List_request _ | Get_then_update_status_request _ -> true
  in
  let inv14 =
    {
      name = "no_pending_mutation_request_not_from_controller_on_pods";
      source =
        "vreplicaset_controller/proof/helper_invariants/predicate.rs:340";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              if (not (src_is_controller m || src_is_builtin m)) && is_apiserver_dst m
              then Option.fold (apireq m) ~none:true ~some:no_mutate_pod
              else true)
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) ->
              (not (src_is_controller m || src_is_builtin m))
              && is_apiserver_dst m
              && Option.is_some (apireq m))
            (msgs s));
    }
  in
  (* ---- #15 filtered_pods_invariant_matrix ------------------------------- *)
  let resp15 tcr s resp =
    Option.fold (list_resp_objs resp) ~none:false ~some:(fun objs ->
        List.for_all
          (fun (o : Dynamic_object.t) ->
            let om : Object_meta.t = Dynamic_object.metadata o in
            Result.is_ok (Pod.unmarshal o)
            && Option.is_some om.namespace
            && Option.equal String.equal om.namespace
                 (Vreplica_set.metadata tcr).namespace
            && Option.fold om.resource_version ~none:false ~some:(fun rv ->
                   Common.Resource_version.to_int rv < rvc s)
            &&
            let okey =
              Result.fold (Dynamic_object.object_ref o) ~ok:Fun.id
                ~error:(fun _ -> vrs_ref)
            in
            Option.fold
              (Object_ref_map.find_opt okey (resources s))
              ~none:true
              ~some:(fun eo ->
                let em : Object_meta.t = Dynamic_object.metadata eo in
                if
                  Option.equal Common.Resource_version.equal em.resource_version
                    om.resource_version
                then Object_meta.equal em om
                else true))
          objs)
  in
  let inv15 =
    {
      name = "filtered_pods_invariant_matrix";
      source =
        "vreplicaset_controller/proof/helper_invariants/predicate.rs:359";
      holds =
        (fun s ->
          Option.fold (decoded_ongoing s) ~none:true ~some:(fun (orc, st) ->
              Result.fold
                (Vreplica_set.unmarshal orc.triggering_cr)
                ~error:(fun _ -> false)
                ~ok:(fun tcr ->
                  let open Vreplica_set_reconciler in
                  let tref =
                    Result.fold (Vreplica_set.object_ref tcr) ~ok:Fun.id
                      ~error:(fun _ -> vrs_ref)
                  in
                  let tns = (Vreplica_set.metadata tcr).namespace in
                  Common.equal_object_ref tref vrs_ref
                  && Object_meta.well_formed_for_namespaced
                       (Vreplica_set.metadata tcr)
                  && Option.fold st.filtered_pods ~none:true ~some:(fun pods ->
                         List.for_all
                           (fun (pod : Pod.t) ->
                             let pm : Object_meta.t = Pod.metadata pod in
                             let pkey =
                               Result.fold (Pod.object_ref pod) ~ok:Fun.id
                                 ~error:(fun _ -> vrs_ref)
                             in
                             Option.equal String.equal pm.namespace tns
                             && Option.fold
                                  (Object_ref_map.find_opt pkey (resources s))
                                  ~none:true
                                  ~some:(fun eo ->
                                    let em : Object_meta.t =
                                      Dynamic_object.metadata eo
                                    in
                                    if
                                      Option.equal Common.Resource_version.equal
                                        em.resource_version pm.resource_version
                                    then
                                      Option.fold
                                        (Vreplica_set.controller_owner_ref tcr)
                                        ~none:false
                                        ~some:
                                          (Object_meta.owner_references_contains em)
                                    else true)
                             && Option.fold pm.resource_version ~none:false
                                  ~some:(fun rv ->
                                    Common.Resource_version.to_int rv < rvc s))
                           pods)
                  &&
                  match st.reconcile_step with
                  | After_list_pods ->
                    pending_list_req_ok orc
                      ~namespace:(Option.value ~default:"" tns)
                      ~resp_check:(resp15 tcr s) s
                  | Init | After_update_vrs_status | After_create_pod _
                  | After_delete_pod _ | Done | Error ->
                    true)));
      interesting =
        (fun s ->
          Option.fold (decoded_ongoing s) ~none:false ~some:(fun (_orc, st) ->
              let open Vreplica_set_reconciler in
              Option.is_some st.filtered_pods));
    }
  in
  (* ---- #16 local_pods_are_bound_to_vrs_with_key (guarantee) -------------- *)
  let resp16 resp =
    Option.fold (list_resp_objs resp) ~none:false ~some:(fun objs ->
        List.for_all
          (fun (o : Dynamic_object.t) ->
            let om : Object_meta.t = Dynamic_object.metadata o in
            Option.equal String.equal om.namespace (Some vrs_ref.namespace)
            && Option.fold om.owner_references ~none:true ~some:(fun orefs ->
                   List.length (List.filter Owner_reference.is_controller orefs)
                   <= 1))
          objs)
  in
  let inv16 =
    {
      name = "local_pods_are_bound_to_vrs_with_key";
      source = "vreplicaset_controller/proof/guarantee.rs:45";
      holds =
        (fun s ->
          Option.fold (decoded_ongoing s) ~none:true ~some:(fun (orc, st) ->
              let open Vreplica_set_reconciler in
              Option.fold st.filtered_pods ~none:true ~some:(fun pods ->
                  List.for_all
                    (fun (pod : Pod.t) ->
                      let pm : Object_meta.t = Pod.metadata pod in
                      Option.fold pm.name ~none:false
                        ~some:Vreplica_set_reconciler.has_vrs_prefix
                      && Option.equal String.equal pm.namespace
                           (Some vrs_ref.namespace)
                      && Option.fold pm.owner_references ~none:false
                           ~some:(fun orefs ->
                             List.exists
                               (fun (o : Owner_reference.t) ->
                                 Owner_reference.is_controller o
                                 && Common.equal_kind o.kind vrs_kind
                                 && String.equal o.name vrs_ref.name)
                               orefs))
                    pods)
              &&
              match st.reconcile_step with
              | After_list_pods ->
                pending_list_req_ok orc ~namespace:vrs_ref.namespace
                  ~resp_check:resp16 s
              | Init | After_update_vrs_status | After_create_pod _
              | After_delete_pod _ | Done | Error ->
                true));
      interesting =
        (fun s ->
          Option.fold (decoded_ongoing s) ~none:false ~some:(fun (_orc, st) ->
              let open Vreplica_set_reconciler in
              Option.fold st.filtered_pods ~none:false ~some:(fun ps ->
                  not (ps = []))));
    }
  in
  ( (* always: proved inductive from init by [lemma_always_*] *)
    [ inv1; inv2; inv3; inv4; inv5; inv6; inv9; inv15; inv16 ],
    (* eventually_always: proved as [lemma_eventually_always_*] / [leads_to_always]
       under crash + req_drop + pod_monkey disabled + weak fairness *)
    [ inv7; inv8; inv10; inv12; inv13; inv14 ] )

let always ~cr ~controller_id = fst (partition ~cr ~controller_id)
let eventually_always ~cr ~controller_id = snd (partition ~cr ~controller_id)

let all ~cr ~controller_id =
  let always_invs, eventually_always_invs = partition ~cr ~controller_id in
  always_invs @ eventually_always_invs

let liveness_goal ~cr =
  {
    name = "current_state_matches";
    source = "vreplicaset_controller/trusted/liveness_theorem.rs:21";
    holds = current_state_matches cr;
    interesting = (fun s -> not (matching_pods cr s = []));
  }

let conjunction invs s = List.for_all (fun i -> i.holds s) invs
let first_violated invs s = List.find_opt (fun i -> not (i.holds s)) invs

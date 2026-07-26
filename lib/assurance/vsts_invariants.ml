(* BUILD-SPEC-P11 §4: the VStatefulSet safety invariants + liveness goal, the
   VSTS sibling of {!Invariants} (which is VReplicaSet-hardwired). Reuses the
   {!Invariants.invariant} record, {!Invariants.conjunction},
   {!Invariants.first_violated} and the shared cluster-level inv1-6 exposed as
   {!Invariants.cluster_structural} (GAP-2), so both controllers assert the same
   etcd/runtime-safety core from ONE source.

   [always ~cr ~controller_id] = [Invariants.cluster_structural ~controller_id]
   (inv1-6) followed by the three VSTS-specific invariants:

   1. {b vsts_reconcile_request_only_interferes_with_itself} (widen VRS inv9):
      every in-flight message whose source is [Controller(controller_id, vsts_ref)]
      carries an [api_request] in the VSTS repertoire, well-formed for the vsts.

      Deviation from the §4 prose, recorded deliberately: the prose enumerates the
      repertoire as "Create Pod|PVC, Get / Get_then_delete on Pod|PVC". The actual
      {!V_stateful_set_reconciler} emits FIVE request families - [List_request]
      (list pods, the FIRST thing it does), [Get_request] (get a pvc),
      [Create_request] (a pod OR a pvc), [Get_then_update_request] (update a pod)
      and [Get_then_delete_request] (delete a condemned / outdated pod). Because the
      invariant "widens" VRS inv9 (which ALREADY allowed [List_request]) it must
      keep List allowed and ADD the pvc-get and the get-then-update; narrowing to
      the prose subset would make the invariant FALSE the moment the reconcile sends
      its first list-pods request, so the faithful, holding repertoire is the one
      the reconciler actually emits. Every OTHER arm ([Delete_request],
      [Update_request], [Update_status_request], [Get_then_update_status_request] -
      the vsts reconcile writes no status) is rejected. Exhaustive match over the
      nine-arm request sum; no wildcard.

   2. {b owned_pods_have_wellformed_ordinal_identity} (the VSTS analogue of VRS
      inv15/16): every etcd Pod carrying the vsts controller owner-ref has a name of
      the form [pod_name parent ord] with [get_ordinal parent name = Some ord],
      [ord >= 0], and an [ordinal_label] equal to [string_of_int ord]. Ownership is
      the owner-ref alone (NOT the name shape) so the name-shape is the asserted
      content, not the precondition; the P10 [get_ordinal] injective-inverse fix is
      what makes it checkable.

   3. {b owned_pvcs_bound_to_vsts}: every etcd PVC carrying the vsts controller
      owner-ref is in the vsts namespace and has a [pvc_name]-shaped name.

      HONEST-VACUITY disclosure (BUILD-SPEC-P11 §0 / §10.6, the P5/P6 precedent):
      the faithful {!V_stateful_set_reconciler.make_pvc} stamps NO owner reference
      on the PVCs it creates (real-Kubernetes StatefulSet PVCs are not
      owner-ref-bound to the set; they survive it, modulo the retention policy). So
      the owner-ref-owned-PVC set is EMPTY in every reachable state - even under
      [vct:true] - and this invariant holds vacuously by construction. Its
      [interesting] never fires. This is DISCLOSED and pinned with a measured
      0-count witness ([t_p11_vsts_invariants]); it corrects the §4(3) assumption
      that PVCs carry an owner-ref, and is not tuned to fake a positive. The
      operational PVC lifecycle is witnessed by the P10 executable spine instead. *)

(* -- shared local helpers (cr-keyed, controller-id-keyed) ------------------- *)

let vsts_ref_of (cr : V_stateful_set.t) : Common.object_ref =
  let md : Object_meta.t = V_stateful_set.metadata cr in
  Result.fold (V_stateful_set.object_ref cr) ~ok:Fun.id ~error:(fun _ ->
      {
        Common.kind = V_stateful_set.kind;
        name = Option.value ~default:"" md.name;
        namespace = Option.value ~default:"" md.namespace;
      })

let etcd_objs (s : Cluster.cluster_state) : Dynamic_object.t list =
  List.map snd (Object_ref_map.bindings (Cluster.resources s))

(* the pods in etcd carrying the vsts controller owner-ref (ownership by
   owner-ref ALONE, so a malformed name is still "owned" and thus checkable). *)
let owned_pods (co : Owner_reference.t option) (s : Cluster.cluster_state) :
    Dynamic_object.t list =
  List.filter
    (fun (obj : Dynamic_object.t) ->
      Common.equal_kind (Dynamic_object.kind obj) Pod.kind
      &&
      let md : Object_meta.t = Dynamic_object.metadata obj in
      Option.fold co ~none:false ~some:(Object_meta.owner_references_contains md))
    (etcd_objs s)

(* the PVCs in etcd carrying the vsts controller owner-ref (empty by
   construction - make_pvc stamps no owner-ref; see the module header). *)
let owned_pvcs (co : Owner_reference.t option) (s : Cluster.cluster_state) :
    Dynamic_object.t list =
  List.filter
    (fun (obj : Dynamic_object.t) ->
      Common.equal_kind (Dynamic_object.kind obj) Persistent_volume_claim.kind
      &&
      let md : Object_meta.t = Dynamic_object.metadata obj in
      Option.fold co ~none:false ~some:(Object_meta.owner_references_contains md))
    (etcd_objs s)

let ordinal_label_is (md : Object_meta.t) (ord : int) : bool =
  let labels = Option.value ~default:Smap.empty md.labels in
  Option.equal String.equal
    (Smap.find_opt V_stateful_set_reconciler.ordinal_label labels)
    (Some (string_of_int ord))

let has_pod_name_label (md : Object_meta.t) : bool =
  let labels = Option.value ~default:Smap.empty md.labels in
  Option.is_some (Smap.find_opt V_stateful_set_reconciler.pod_name_label labels)

(* -- current_state_matches (§4 (a)(b)(c); the ESR leads_to TARGET) ---------- *)

let current_state_matches (cr : V_stateful_set.t) (s : Cluster.cluster_state) :
    bool =
  let vsts_ref = vsts_ref_of cr in
  let vsts_ns = vsts_ref.namespace in
  let parent =
    Option.value ~default:"" (Object_meta.name (V_stateful_set.metadata cr))
  in
  let co = V_stateful_set.controller_owner_ref cr in
  let n = Option.value ~default:1 (V_stateful_set.spec cr).replicas in
  let owned_pod_at (ord : int) : bool =
    let key : Common.object_ref =
      {
        Common.kind = Pod.kind;
        name = V_stateful_set_reconciler.pod_name parent ord;
        namespace = vsts_ns;
      }
    in
    Option.fold
      (Object_ref_map.find_opt key (Cluster.resources s))
      ~none:false
      ~some:(fun (obj : Dynamic_object.t) ->
        let md : Object_meta.t = Dynamic_object.metadata obj in
        Common.equal_kind (Dynamic_object.kind obj) Pod.kind
        && Option.fold co ~none:false
             ~some:(Object_meta.owner_references_contains md)
        && ordinal_label_is md ord
        && has_pod_name_label md
        && Result.fold (Pod.unmarshal obj) ~error:(fun _ -> false)
             ~ok:(fun (pod : Pod.t) ->
               V_stateful_set_reconciler.pod_spec_matches cr pod))
  in
  (* (a) the CR is in etcd *)
  Option.is_some (Object_ref_map.find_opt vsts_ref (Cluster.resources s))
  (* (b) each ordinal 0..n-1 is present as a valid owned pod *)
  && List.for_all owned_pod_at (List.init (max 0 n) Fun.id)
  (* (c) EXACTLY n owned pods (no owned pod survives at ordinal >= n) *)
  && List.length (owned_pods co s) = n

(* -- the three VSTS-specific always invariants ------------------------------ *)

let vsts_invariants ~(cr : V_stateful_set.t) ~(controller_id : int) :
    Invariants.invariant list =
  let vsts_ref = vsts_ref_of cr in
  let vsts_ns = vsts_ref.namespace in
  let parent =
    Option.value ~default:"" (Object_meta.name (V_stateful_set.metadata cr))
  in
  let co = V_stateful_set.controller_owner_ref cr in
  let sp : Stateful_set.ss_spec = V_stateful_set.spec cr in
  let n = Option.value ~default:1 sp.replicas in
  let msgs (s : Cluster.cluster_state) = Message.Pool.distinct (Cluster.in_flight s) in
  let is_src_controller_key (m : Message.t) =
    Message.equal_host_id m.src (Message.Controller (controller_id, vsts_ref))
  in
  let apireq (m : Message.t) : Api_method.api_request option =
    match m.content with
    | Message.Api_request r -> Some r
    | Message.Api_response _ | Message.External_request _
    | Message.External_response _ ->
      None
  in
  let is_vsts_controller_owner (oref : Owner_reference.t) : bool =
    Owner_reference.is_controller oref
    && Common.equal_kind oref.kind V_stateful_set.kind
    && String.equal oref.name vsts_ref.name
  in
  let no_foreign_controller_owner (md : Object_meta.t) : bool =
    Option.fold md.owner_references ~none:true ~some:(fun orefs ->
        List.for_all
          (fun (o : Owner_reference.t) ->
            (not (Owner_reference.is_controller o)) || is_vsts_controller_owner o)
          orefs)
  in
  (* the VSTS repertoire self-check (see module header for the deviation note). *)
  let self_ok (req : Api_method.api_request) : bool =
    let open Api_method in
    match req with
    | List_request lr ->
      Common.equal_kind lr.kind Pod.kind && String.equal lr.namespace vsts_ns
    | Get_request r ->
      (* the VSTS reconciler's SOLE Get emitter is Get_pvc (PVC-keyed); a
         Pod-keyed Get is never emitted, so accepting only PVC keeps this a
         faithful tripwire on the documented repertoire (P11 review fix). *)
      Common.equal_kind r.key.kind Persistent_volume_claim.kind
      && String.equal r.key.namespace vsts_ns
    | Create_request r ->
      String.equal r.namespace vsts_ns
      &&
      let om : Object_meta.t = Dynamic_object.metadata r.obj in
      let k = Dynamic_object.kind r.obj in
      if Common.equal_kind k Pod.kind then
        Option.fold om.owner_references ~none:false ~some:(fun orefs ->
            match orefs with
            | [ oref ] -> is_vsts_controller_owner oref
            | [] | _ :: _ :: _ -> false)
      else if Common.equal_kind k Persistent_volume_claim.kind then
        (* controller PVCs carry NO owner-ref (make_pvc); accept when the create
           does not claim a FOREIGN controller owner. *)
        no_foreign_controller_owner om
      else false
    | Get_then_update_request r ->
      String.equal r.namespace vsts_ns
      && Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind
      && is_vsts_controller_owner r.owner_ref
    | Get_then_delete_request r ->
      Common.equal_kind r.key.kind Pod.kind
      && String.equal r.key.namespace vsts_ns
      && is_vsts_controller_owner r.owner_ref
    | Get_then_update_status_request _ | Update_request _
    | Update_status_request _ | Delete_request _ ->
      false
  in
  let inv_self =
    {
      Invariants.name = "vsts_reconcile_request_only_interferes_with_itself";
      source = "vstatefulset_controller/proof/helper_invariants/predicate.rs (widened inv9)";
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
  let inv_ordinal =
    {
      Invariants.name = "owned_pods_have_wellformed_ordinal_identity";
      source = "vstatefulset_controller/proof/predicate.rs (ordinal identity)";
      holds =
        (fun s ->
          List.for_all
            (fun (obj : Dynamic_object.t) ->
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Option.fold md.name ~none:false ~some:(fun name ->
                  Option.fold
                    (V_stateful_set_reconciler.get_ordinal parent name)
                    ~none:false
                    ~some:(fun ord ->
                      ord >= 0
                      && String.equal name
                           (V_stateful_set_reconciler.pod_name parent ord)
                      && ordinal_label_is md ord)))
            (owned_pods co s));
      interesting = (fun s -> not (owned_pods co s = []));
    }
  in
  (* a pvc_name-shaped name for SOME template in the CR spec at SOME ordinal
     0..n-1 (dead under this model - no PVC is owner-ref-owned - but the honest
     shape check for when/if a PVC ever carries the vsts owner-ref). *)
  let pvc_name_shaped (name : string) : bool =
    let tmpls = Option.value ~default:[] sp.volume_claim_templates in
    List.exists
      (fun (t : Persistent_volume_claim.t) ->
        let tmpl_name = Option.value ~default:"" t.metadata.name in
        List.exists
          (fun ord ->
            String.equal name
              (V_stateful_set_reconciler.pvc_name tmpl_name parent ord))
          (List.init (max 0 n) Fun.id))
      tmpls
  in
  let inv_pvc =
    {
      Invariants.name = "owned_pvcs_bound_to_vsts";
      source = "vstatefulset_controller/proof/predicate.rs (pvc binding)";
      holds =
        (fun s ->
          List.for_all
            (fun (obj : Dynamic_object.t) ->
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Option.equal String.equal md.namespace (Some vsts_ns)
              && Option.fold md.name ~none:false ~some:pvc_name_shaped)
            (owned_pvcs co s));
      interesting = (fun s -> not (owned_pvcs co s = []));
    }
  in
  [ inv_self; inv_ordinal; inv_pvc ]

let always ~(cr : V_stateful_set.t) ~(controller_id : int) :
    Invariants.invariant list =
  Invariants.cluster_structural ~controller_id
  @ vsts_invariants ~cr ~controller_id

let liveness_goal ~(cr : V_stateful_set.t) : Invariants.invariant =
  let co = V_stateful_set.controller_owner_ref cr in
  {
    Invariants.name = "vsts_current_state_matches";
    source = "vstatefulset_controller/trusted (ordinal-stable ESR goal)";
    holds = current_state_matches cr;
    interesting = (fun s -> not (owned_pods co s = []));
  }

(* BUILD-SPEC-P21 §2: the VSTS internal GUARANTEE family - the exact dual of
   P20's rely register. P20 ported
   [vstatefulset_controller/trusted/rely_guarantee.rs]: what the ENVIRONMENT is
   assumed to promise the VSTS controller, never discharged. These four members
   are the other half - what the VSTS controller GUARANTEES to everyone else -
   and unlike the rely conditions they ARE discharged upstream, by
   [internal_guarantee_condition_holds]
   (proof/internal_rely_guarantee.rs:1003) and
   [internal_guarantee_condition_holds_on_all_vsts] (:1196).

   - G1 vsts_internal_guarantee_create_req (:562-578), LIFTED over
     VSTS-controller-sourced creates
   - G2 vsts_internal_guarantee_get_then_delete_req (:581-586), LIFTED
   - G3 vsts_internal_guarantee_get_then_update_req (:589-599), LIFTED
   - G4 no_interfering_request_between_vsts (:544-559), upstream's own StatePred

   G4 IS STRICTLY STRONGER THAN [G1 && G2 && G3], deliberately: its match at
   :550-557 also carries the read-only arms (:551, List/Get => true) and the
   FORBIDDEN-KIND arm (:556, [_ => false]) which rules out Delete, Update,
   UpdateStatus and GetThenUpdateStatus outright, whereas G1-G3 lifted
   individually are vacuously true on every request kind but their own. So a
   reconciler that emitted a plain Update would redden G4 while leaving G1-G3
   green. That asymmetry is the point: it is what stops this family from
   repeating P20 review-finding A, where [R3 <=> R1 && R2] was shipped as a
   measurement but was a THEOREM of the code and could not fail. No identity pin
   is shipped here.

   All four traverse [Message.Pool.distinct (Cluster.in_flight s)] - the
   [inv_self] projection precedent (vsts_invariants.ml:152), P19's
   (msg_provenance.ml:22-23) and P20's (rely_conditions.ml:21-22). Upstream's
   forall at :546-549 quantifies over [s.in_flight()] alone. Every rendering
   decision and every deviation is disclosed in the .mli. *)

let msgs (s : Cluster.cluster_state) : Message.t list =
  Message.Pool.distinct (Cluster.in_flight s)

(* The [Api_request] payload projection (the [inv_self] helper shape,
   vsts_invariants.ml:156-162; P19 msg_provenance.ml:28-33; P20
   rely_conditions.ml:28-33): [Some r] on a request, [None] on the three
   non-request contents - an exhaustive 4-arm match, no wildcard. *)
let api_request_of (m : Message.t) : Api_method.api_request option =
  match m.content with
  | Message.Api_request r -> Some r
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    None

(* Upstream's shared premise at :546-549: the message is in flight, its content
   is an APIRequest, and its source is EXACTLY
   [HostId::Controller(controller_id, vsts.object_ref())] - the controller id
   AND the CR key both. The port's [Message.host_id] is
   [Controller of int * Common.object_ref] (message.mli:40), the exact analogue,
   so no narrowing happens here. [None] means the message is out of premise, so
   every member's [holds] folds it to [true] and every [interesting] folds it to
   [false]. The five src arms are spelled out (no wildcard). *)
let vsts_request_of ~(controller_id : int) ~(cr_key : Common.object_ref)
    (m : Message.t) : Api_method.api_request option =
  match m.src with
  | Message.Controller (cid, key) ->
    if Int.equal cid controller_id && Common.equal_object_ref key cr_key then
      api_request_of m
    else None
  | Message.Api_server | Message.Builtin_controller | Message.Pod_monkey
  | Message.External _ ->
    None

(* The CR's namespace and name. Upstream reads [vsts.metadata.namespace->0] and
   [vsts.metadata.name->0] - Verus [->0] on a [None] is an arbitrary total-map
   value, i.e. UNCONSTRAINED, not false. The port folds a missing field to the
   empty string, which is what the reconciler itself already does
   (v_stateful_set_reconciler.ml:268-269 for the name, :604 / :642 for the
   namespace, both [Option.value ~default:""]). Disclosed in the .mli: on the
   shipped scenarios both fields are [Some], so the two renderings coincide
   there and the deviation is unreachable rather than merely unlikely. *)
let cr_namespace (cr : V_stateful_set.t) : string =
  Option.value ~default:"" (Object_meta.namespace (V_stateful_set.metadata cr))

let cr_name (cr : V_stateful_set.t) : string =
  Option.value ~default:"" (Object_meta.name (V_stateful_set.metadata cr))

(* Upstream's premise reads [vsts.object_ref()], which is
   [{kind: VStatefulSetView::kind(), name: metadata.name->0,
     namespace: metadata.namespace->0}]. The port EXPORTS
   [V_stateful_set.object_ref], but it is [Common.object_ref Res.t] - partial,
   because it refuses a CR whose name or namespace is [None]. A total classifier
   must not consume it (the P19 M2 / P20 R1 precedent), and folding the error
   arm to "no key" would make the whole family silently VACUOUS on exactly the
   CRs the port cannot key - the failure mode this port audits for.

   So the key is built directly from the same [->0] rendering already used by
   {!cr_name} and {!cr_namespace}, which keeps the three readings consistent by
   construction. Disclosed in the .mli. *)
let cr_key_of (cr : V_stateful_set.t) : Common.object_ref =
  {
    Common.kind = V_stateful_set.kind;
    name = cr_name cr;
    namespace = cr_namespace cr;
  }

(* A TOTAL substring. [String.sub] raises [Invalid_argument] on a bad range, and
   the house rule is that errors are values; the guard on the [Some] line
   establishes the precondition, so the accessor cannot raise.

   P18's [pvc_name_matches] (helper_invariants.ml:32-43) calls [String.sub]
   with ranges made safe only by the surrounding control flow. That is correct
   as written but not locally checkable; this rendering is, and the difference
   is disclosed rather than silently "fixed" in P18's copy. *)
let sub_opt (s : string) (pos : int) (len : int) : string option =
  if pos >= 0 && len >= 0 && pos + len <= String.length s then
    Some (String.sub s pos len) (* @total-accessor *)
  else None

(* Upstream [pod_name_match] (proof/predicate.rs:146-148):
   [exists |ord: nat| name == pod_name(vsts_name, ord)]. The port already owns
   the decision procedure for that existential - the reconciler's own
   [get_ordinal] (v_stateful_set_reconciler.mli:98) is the partial inverse of
   [pod_name] (:91) - so the existential is rendered by INVERSION, not by
   search. This is P18's rendering (helper_invariants.ml:58-62), reused rather
   than re-litigated. *)
let pod_name_matches (parent : string) (name : string) : bool =
  Option.is_some (V_stateful_set_reconciler.get_ordinal parent name)

(* Upstream [pvc_name_match] (proof/predicate.rs:140-143):
   [exists |i: (StringView, nat)| name == pvc_name(i.0, vsts_name, i.1)
    && dash_free(i.0)]. The template component is a genuinely abstract-string
   existential, so it is rendered structurally: strip the minted
   ["vstatefulset-"] prefix, split at the first dash (the [dash_free] conjunct
   is what makes that split unambiguous), and require the remainder to invert
   through [get_ordinal].

   This DUPLICATES P18's [pvc_name_matches] (helper_invariants.ml:32-43) rather
   than calling it, because that binding is private to [Helper_invariants] and
   is not exported (helper_invariants.mli exports two vals only). The
   duplication is deliberate and is pinned: t_p21_guarantee asserts the two
   agree on a shared corpus, so a later divergence is caught rather than
   silently tolerated. *)
let pvc_name_matches (parent : string) (name : string) : bool =
  let prefix = "vstatefulset-" in
  String.starts_with ~prefix name
  && Option.fold
       (sub_opt name (String.length prefix)
          (String.length name - String.length prefix))
       ~none:false
       ~some:(fun rest ->
         Option.fold (String.index_opt rest '-') ~none:false ~some:(fun i ->
             Option.fold
               (sub_opt rest (i + 1) (String.length rest - i - 1))
               ~none:false
               ~some:(fun after_tmpl ->
                 Option.is_some
                   (V_stateful_set_reconciler.get_ordinal parent
                      (prefix ^ after_tmpl)))))

(* Upstream [owner_reference_eq_without_uid(r, vsts.controller_owner_ref())]
   (kubernetes_api_objects/spec/owner_reference.rs:37-42 - four conjuncts:
   controller, block_owner_deletion, kind, name). The port EXPORTS that exact
   predicate as [Owner_reference.eq_without_uid] (owner_reference.mli:26), so it
   is called, not re-rendered. [V_stateful_set.controller_owner_ref] is
   [t -> Owner_reference.t option] (v_stateful_set.mli:42); a [None] there means
   the CR has no controller owner ref to match, so the conjunct is FALSE - the
   E1-boundary reading P18 documented (helper_invariants.mli:151). *)
let matches_cr_controller_ref (cr : V_stateful_set.t) (r : Owner_reference.t) :
    bool =
  Option.fold
    (V_stateful_set.controller_owner_ref cr)
    ~none:false
    ~some:(fun (co : Owner_reference.t) -> Owner_reference.eq_without_uid r co)

(* Upstream :568-571:
   [exists |r| req.obj.metadata.owner_references == Some(Seq::empty().push(r))
    && owner_reference_eq_without_uid(r, vsts.controller_owner_ref())].
   The sequence is [Seq::empty().push(r)] - EXACTLY ONE element - so this is a
   singleton test, NOT [owner_references_contains] and NOT [List.exists]. It is
   strictly stronger than P20 R1's existential collapse
   (rely_conditions.ml:77-79), and it must not be weakened to match it: a
   two-ref object satisfies P20's shape and violates this one. The three list
   arms are spelled out. *)
let owner_refs_are_exactly_cr_controller (cr : V_stateful_set.t)
    (md : Object_meta.t) : bool =
  Option.fold md.owner_references ~none:false ~some:(fun l ->
      match l with
      | [ r ] -> matches_cr_controller_ref cr r
      | [] -> false
      | _ :: _ :: _ -> false)

(* Upstream :595: [req.obj.metadata.owner_references == Some(Seq::empty().push(
   req.owner_ref))]. Note this one is STRUCTURAL EQUALITY against the request's
   own [owner_ref] - uid included - so it uses [Owner_reference.equal]
   (owner_reference.mli:30), NOT [eq_without_uid]. The uid-insensitive
   comparison against the CR is the SEPARATE conjunct at :596. Conflating the
   two would silently weaken G3. *)
let owner_refs_are_exactly (r : Owner_reference.t) (md : Object_meta.t) : bool =
  Option.fold md.owner_references ~none:false ~some:(fun l ->
      match l with
      | [ x ] -> Owner_reference.equal x r
      | [] -> false
      | _ :: _ :: _ -> false)

(* G1's per-request predicate, upstream [vsts_internal_guarantee_create_req]
   (:562-578). The kind dispatch is upstream's two IMPLICATIONS at :567 and
   :574, so every kind other than Pod and PersistentVolumeClaim satisfies both
   vacuously and the arm is [true]; the remaining eight [Common.kind]
   constructors (common.mli:35-46) are spelled out, no wildcard.

   [req.key().name] at :572 is read as [md.name] rather than through
   [Api_method.create_request_key]: upstream's [CreateRequest::key] is
   [{kind: obj.kind, namespace: req.namespace, name: obj.metadata.name->0}], and
   the [md.name is Some] conjunct at :564 has ALREADY been required by the time
   the Pod arm is evaluated, so the two readings coincide. The port's
   [create_request_key] is [Res.t]-typed hence partial (api_method.mli:137-139)
   and a total classifier must not consume it - the P19 M2 precedent
   (msg_provenance.ml:38-44) and P20's (rely_conditions.ml:94-97). *)
let guarantee_create_req (cr : V_stateful_set.t)
    (r : Api_method.create_request) : bool =
  let md : Object_meta.t = Dynamic_object.metadata r.obj in
  (* :563 *)
  String.equal r.namespace (cr_namespace cr)
  (* :564-566 *)
  && Option.is_some md.name
  && Option.is_none md.generate_name
  && Option.is_none md.finalizers
  &&
  match Dynamic_object.kind r.obj with
  | Common.Pod ->
    (* :568-572 *)
    owner_refs_are_exactly_cr_controller cr md
    && Option.fold md.name ~none:false ~some:(pod_name_matches (cr_name cr))
  | Common.Persistent_volume_claim ->
    (* :575-576 *)
    Option.is_none md.owner_references
    && Option.fold md.name ~none:false ~some:(pvc_name_matches (cr_name cr))
  | Common.Config_map | Common.Custom_resource _ | Common.Daemon_set
  | Common.Role | Common.Role_binding | Common.Secret | Common.Service
  | Common.Service_account | Common.Stateful_set ->
    true

(* G2's per-request predicate, upstream
   [vsts_internal_guarantee_get_then_delete_req] (:581-586). Four flat
   conjuncts, no kind dispatch: the request kind is CONSTRAINED to Pod at :583
   rather than dispatched on. [get_then_delete_request] carries [key] and
   [owner_ref] directly (api_method.mli:81-84), so nothing partial is touched. *)
let guarantee_get_then_delete_req (cr : V_stateful_set.t)
    (r : Api_method.get_then_delete_request) : bool =
  (* :582 *)
  String.equal r.key.Common.namespace (cr_namespace cr)
  (* :583 *)
  && Common.equal_kind r.key.Common.kind Common.Pod
  (* :584 *)
  && pod_name_matches (cr_name cr) r.key.Common.name
  (* :585 *)
  && matches_cr_controller_ref cr r.owner_ref

(* G3's per-request predicate, upstream
   [vsts_internal_guarantee_get_then_update_req] (:589-599). Nine flat
   conjuncts. The first two (:590-591) are the request/object agreement clauses
   - the request's [name]/[namespace] must match the carried object's metadata -
   and they are what make a laundered object detectable. :595 and :596 are the
   TWO DISTINCT owner-ref conjuncts described at {!owner_refs_are_exactly}. *)
let guarantee_get_then_update_req (cr : V_stateful_set.t)
    (r : Api_method.get_then_update_request) : bool =
  let md : Object_meta.t = Dynamic_object.metadata r.obj in
  (* :590 *)
  Option.fold md.name ~none:false ~some:(String.equal r.name)
  (* :591 *)
  && Option.fold md.namespace ~none:false ~some:(String.equal r.namespace)
  (* :592 *)
  && Common.equal_kind (Dynamic_object.kind r.obj) Common.Pod
  (* :593 *)
  && String.equal r.namespace (cr_namespace cr)
  (* :594 *)
  && pod_name_matches (cr_name cr) r.name
  (* :595 - structural, uid included *)
  && owner_refs_are_exactly r.owner_ref md
  (* :596 - uid-insensitive, against the CR *)
  && matches_cr_controller_ref cr r.owner_ref
  (* :597-598 *)
  && Option.is_none md.deletion_timestamp
  && Option.is_none md.finalizers

(* G4's per-request arm dispatch, upstream [no_interfering_request_between_vsts]
   (:550-557). All NINE [Api_method.api_request] constructors
   (api_method.mli:103-112) are spelled out against upstream's five-arm match:
   the two read-only arms (:551) are [true], the three constrained arms delegate
   to G1/G2/G3, and upstream's [_ => false] (:556) is expanded into the four
   request kinds the VSTS controller is guaranteed never to issue.

   The comment at :555 names only three of those four ("VSTS controller will not
   issue DeleteRequest, UpdateRequest and UpdateStatusRequest"); the [_] arm
   also captures GetThenUpdateStatusRequest, and this rendering follows the
   CODE, not the comment. *)
let no_interfering_request (cr : V_stateful_set.t)
    (r : Api_method.api_request) : bool =
  match r with
  | Api_method.List_request _ | Api_method.Get_request _ -> true
  | Api_method.Create_request c -> guarantee_create_req cr c
  | Api_method.Get_then_delete_request d -> guarantee_get_then_delete_req cr d
  | Api_method.Get_then_update_request u -> guarantee_get_then_update_req cr u
  | Api_method.Delete_request _ | Api_method.Update_request _
  | Api_method.Update_status_request _
  | Api_method.Get_then_update_status_request _ ->
    false

(* The lifting shared by all four members: fold a per-request predicate over the
   VSTS-controller-sourced requests in flight. Out-of-premise messages fold to
   [true], which is the implication's own vacuous case. *)
let all_vsts_requests ~(controller_id : int) ~(cr_key : Common.object_ref)
    ~(select : Api_method.api_request -> bool)
    ~(pred : Api_method.api_request -> bool) (s : Cluster.cluster_state) : bool =
  List.for_all
    (fun (m : Message.t) ->
      Option.fold
        (vsts_request_of ~controller_id ~cr_key m)
        ~none:true
        ~some:(fun r -> (not (select r)) || pred r))
    (msgs s)

(* The [interesting] mirror: the premise fires somewhere. *)
let some_vsts_request ~(controller_id : int) ~(cr_key : Common.object_ref)
    ~(select : Api_method.api_request -> bool) (s : Cluster.cluster_state) : bool
    =
  List.exists
    (fun (m : Message.t) ->
      Option.fold
        (vsts_request_of ~controller_id ~cr_key m)
        ~none:false
        ~some:select)
    (msgs s)

let is_create (r : Api_method.api_request) : bool =
  match r with
  | Api_method.Create_request _ -> true
  | Api_method.Get_request _ | Api_method.List_request _
  | Api_method.Delete_request _ | Api_method.Update_request _
  | Api_method.Update_status_request _ | Api_method.Get_then_delete_request _
  | Api_method.Get_then_update_request _
  | Api_method.Get_then_update_status_request _ ->
    false

let is_get_then_delete (r : Api_method.api_request) : bool =
  match r with
  | Api_method.Get_then_delete_request _ -> true
  | Api_method.Get_request _ | Api_method.List_request _
  | Api_method.Create_request _ | Api_method.Delete_request _
  | Api_method.Update_request _ | Api_method.Update_status_request _
  | Api_method.Get_then_update_request _
  | Api_method.Get_then_update_status_request _ ->
    false

let is_get_then_update (r : Api_method.api_request) : bool =
  match r with
  | Api_method.Get_then_update_request _ -> true
  | Api_method.Get_request _ | Api_method.List_request _
  | Api_method.Create_request _ | Api_method.Delete_request _
  | Api_method.Update_request _ | Api_method.Update_status_request _
  | Api_method.Get_then_delete_request _
  | Api_method.Get_then_update_status_request _ ->
    false

let any_request (_ : Api_method.api_request) : bool = true

(* The upstream source literals, in member order. Exported so the regression can
   pin the (name, source) DISJOINTNESS firewall without restating them. *)
let guarantee_sources : string list =
  [
    "vstatefulset_controller/proof/internal_rely_guarantee.rs:562";
    "vstatefulset_controller/proof/internal_rely_guarantee.rs:581";
    "vstatefulset_controller/proof/internal_rely_guarantee.rs:589";
    "vstatefulset_controller/proof/internal_rely_guarantee.rs:544";
  ]

let guarantee_family ~(cr : V_stateful_set.t) ~(controller_id : int) :
    Invariants.invariant list =
  let cr_key = cr_key_of cr in
  let g1 =
    {
      Invariants.name = "vsts_internal_guarantee_create_req";
      source = "vstatefulset_controller/proof/internal_rely_guarantee.rs:562";
      holds =
        all_vsts_requests ~controller_id ~cr_key ~select:is_create
          ~pred:(fun r ->
            match r with
            | Api_method.Create_request c -> guarantee_create_req cr c
            | Api_method.Get_request _ | Api_method.List_request _
            | Api_method.Delete_request _ | Api_method.Update_request _
            | Api_method.Update_status_request _
            | Api_method.Get_then_delete_request _
            | Api_method.Get_then_update_request _
            | Api_method.Get_then_update_status_request _ ->
              true);
      interesting = some_vsts_request ~controller_id ~cr_key ~select:is_create;
    }
  in
  let g2 =
    {
      Invariants.name = "vsts_internal_guarantee_get_then_delete_req";
      source = "vstatefulset_controller/proof/internal_rely_guarantee.rs:581";
      holds =
        all_vsts_requests ~controller_id ~cr_key ~select:is_get_then_delete
          ~pred:(fun r ->
            match r with
            | Api_method.Get_then_delete_request d ->
              guarantee_get_then_delete_req cr d
            | Api_method.Get_request _ | Api_method.List_request _
            | Api_method.Create_request _ | Api_method.Delete_request _
            | Api_method.Update_request _ | Api_method.Update_status_request _
            | Api_method.Get_then_update_request _
            | Api_method.Get_then_update_status_request _ ->
              true);
      interesting =
        some_vsts_request ~controller_id ~cr_key ~select:is_get_then_delete;
    }
  in
  let g3 =
    {
      Invariants.name = "vsts_internal_guarantee_get_then_update_req";
      source = "vstatefulset_controller/proof/internal_rely_guarantee.rs:589";
      holds =
        all_vsts_requests ~controller_id ~cr_key ~select:is_get_then_update
          ~pred:(fun r ->
            match r with
            | Api_method.Get_then_update_request u ->
              guarantee_get_then_update_req cr u
            | Api_method.Get_request _ | Api_method.List_request _
            | Api_method.Create_request _ | Api_method.Delete_request _
            | Api_method.Update_request _ | Api_method.Update_status_request _
            | Api_method.Get_then_delete_request _
            | Api_method.Get_then_update_status_request _ ->
              true);
      interesting =
        some_vsts_request ~controller_id ~cr_key ~select:is_get_then_update;
    }
  in
  let g4 =
    {
      Invariants.name = "no_interfering_request_between_vsts";
      source = "vstatefulset_controller/proof/internal_rely_guarantee.rs:544";
      holds =
        all_vsts_requests ~controller_id ~cr_key ~select:any_request
          ~pred:(no_interfering_request cr);
      interesting = some_vsts_request ~controller_id ~cr_key ~select:any_request;
    }
  in
  [ g1; g2; g3; g4 ]

(* E3: upstream internal_rely_guarantee.rs:606-611, the LIFT of L2/E5 over every
   VSTS-kind key of [Cluster.ongoing_reconciles]. Modeled structurally on
   {!Invariants.unique_reconcile_id_invariant} (invariants.mli:44-49): a
   controller_id-only single [Invariants.invariant], not a per-cr family member -
   upstream's own signature takes only [controller_id], so [guarantee_family]'s
   [~cr:V_stateful_set.t -> ...] shape (every existing G1-G4 member genuinely
   consumes [~cr], internal_guarantee.mli:202-205) would be the wrong fit, not a
   clean extension. [holds]/[interesting] are total, pure, exception-free;
   [Object_ref_map.for_all]/[.exists] are the total-fold combinators (Map.S,
   object_ref_map.ml:17), no wildcard on the two-arm kind check ([not (...)] is
   the exhaustive complement of a single-constructor comparison, not a wildcard
   match). *)
let local_pods_and_pvcs_are_bound_to_vsts ~(controller_id : int) :
    Invariants.invariant =
  {
    Invariants.name = "local_pods_and_pvcs_are_bound_to_vsts";
    source = "vstatefulset_controller/proof/internal_rely_guarantee.rs:606";
    holds =
      (fun (s : Cluster.cluster_state) ->
        Object_ref_map.for_all
          (fun (k : Common.object_ref) (_orc : Controller.ongoing_reconcile) ->
            (not (Common.equal_kind k.Common.kind V_stateful_set.kind))
            || Local_binding.holds_at_key ~controller_id ~cr_key:k s)
          (Cluster.ongoing_reconciles s controller_id));
    interesting =
      (* P14 N3 - OWN premise mirror, not L2's per-key interesting witness. *)
      (fun (s : Cluster.cluster_state) ->
        Object_ref_map.exists
          (fun (k : Common.object_ref) (_orc : Controller.ongoing_reconcile) ->
            Common.equal_kind k.Common.kind V_stateful_set.kind)
          (Cluster.ongoing_reconciles s controller_id));
  }

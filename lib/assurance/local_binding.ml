(* BUILD-SPEC-P23 §2: the controller-LOCAL binding register - the E-ledger
   re-partition that retires P21's E3/E4/E5 deferral.

   P21 ledgered three upstream [pub open spec fn] of
   [vstatefulset_controller/proof/internal_rely_guarantee.rs] as EXCLUDED on the
   ground that the port's [Controller.ongoing_reconcile.local_state] is an
   untyped [Value.t] and the VSTS reconcile step is not exposed
   (BUILD-SPEC-P21 §2.2, internal_guarantee.mli:160-204). Both halves are false
   today: [pending_req_msg : Message.t option] is exposed (controller.mli:57)
   and the typed state is reachable through
   [V_stateful_set_pack.unmarshal_state] (v_stateful_set_pack.mli:16) onto the
   seven-field record at v_stateful_set_reconciler.mli:45-53 with its
   seventeen-constructor [step] at :14-33.

   The three upstream functions are NESTED, not overlapping:
   - E3 :606-611  [local_pods_and_pvcs_are_bound_to_vsts] - the LIFT of E5 over
     every VSTS-kind key in [ongoing_reconciles]; one conjunct, six-line body.
     EXCLUDED through P24 (§2.2): every shipped scenario was single-CR, so the
     lift collapsed to L2-at-the-scenario-key. That is "L2 wearing a hat", the
     exact ground P21 used for its own E1. SHIPPED by P25 over the committed
     multi-CR graphs, via [holds_at_key] (BUILD-SPEC-P25 §1.1).
   - E4 :613-638  a pure [(cr_key, local_state) -> bool] - SHIPPED here as L1.
   - E5 :640-664  E4 at the decoded local state, plus the [AfterListPod]
     pending/in-flight block - SHIPPED here as L2 (it calls E4 at :642).

   L2's [holds] therefore strictly implies L1's. The containment is DELIBERATE
   (the P21 G4-vs-G1/G2/G3 precedent): shipping E5 alone would put E4's text
   inside a member cited :640 while :613 stayed ledgered EXCLUDED - a FALSE
   ledger. Two members also make E4's vacuity separately MEASURABLE through
   per-member [interesting]. The consequence is disclosed in the .mli:
   [Invariants.first_violated] is first-in-list-order, so any shared-conjunct
   failure names L1 and leaves L2 looking green.

   DUPLICATE-AND-PIN, not export (the house precedent stated in-tree at
   internal_guarantee.ml:131-136). Everything this family needs from
   {!Internal_guarantee} is private to that module, and the list-request /
   list-response / ok-response helpers are local [let]s inside a function body
   in invariants.ml (:334, :348, :361, :371), so they are not callable either.
   They are copied with their origins cited, and transposed VRS -> VSTS the way
   {!Vsts_step_view} transposed [Step_view]. NOT duplicated:
   [pvc_name_matches] - the pvcs conjunct (:629-637) is excluded with a pin, so
   a third copy is not created.

   Every [holds]/[interesting] is total, pure and exception-free; every match on
   a finite sum is exhaustive (the seventeen reconcile steps, the nine
   [Api_method.api_request] and nine [Api_method.api_response] constructors, the
   four [Message.message_content] constructors), no wildcard arms. *)

(* The in-flight projection, copied from internal_guarantee.ml:34-35 (itself the
   [inv_self] precedent, vsts_invariants.ml:152). Upstream's forall at :652-657
   quantifies over [s.in_flight()]. *)
let msgs (s : Cluster.cluster_state) : Message.t list =
  Message.Pool.distinct (Cluster.in_flight s)

(* The CR's namespace and name, copied from internal_guarantee.ml:75-79 with its
   disclosed reading: Verus [metadata.namespace->0] / [name->0] on a [None] is
   an arbitrary total-map value, i.e. UNCONSTRAINED, and the port folds a
   missing field to the empty string - what the reconciler itself does
   (v_stateful_set_reconciler.ml:268-269, :604, :642, all
   [Option.value ~default:""]). On the shipped scenarios both fields are [Some],
   so the two renderings coincide there. *)
let cr_namespace (cr : V_stateful_set.t) : string =
  Option.value ~default:"" (Object_meta.namespace (V_stateful_set.metadata cr))

let cr_name (cr : V_stateful_set.t) : string =
  Option.value ~default:"" (Object_meta.name (V_stateful_set.metadata cr))

(* Upstream's [cr_key], copied from internal_guarantee.ml:93-98 together with
   its totality decision: the port EXPORTS [V_stateful_set.object_ref], but it
   is [Common.object_ref Res.t] - partial, refusing a CR whose name or namespace
   is [None] - and a total classifier must not consume it (the P19 M2 / P20 R1
   precedent). Folding its error arm to "no key" would make the whole family
   silently VACUOUS on exactly the CRs the port cannot key. *)
let cr_key_of (cr : V_stateful_set.t) : Common.object_ref =
  {
    Common.kind = V_stateful_set.kind;
    name = cr_name cr;
    namespace = cr_namespace cr;
  }

(* Upstream [pod_name_match] (proof/predicate.rs:146-148,
   [exists |ord: nat| name == pod_name(vsts_name, ord)]), rendered by INVERSION
   through the reconciler's own [get_ordinal] (v_stateful_set_reconciler.mli:98),
   the partial inverse of [pod_name] (:91). This is P18's rendering
   (helper_invariants.ml:58-62) as reused by P21
   (internal_guarantee.ml:113-121), copied rather than re-litigated. *)
let pod_name_matches (parent : string) (name : string) : bool =
  Option.is_some (V_stateful_set_reconciler.get_ordinal parent name)

(* The three per-pod sub-conjuncts shared by upstream :619-621 (the needed
   forall) and :625-627 (the condemned forall):
     pod.metadata.name is Some
     pod_name_match(pod.metadata.name->0, cr_key.name)
     pod.metadata.namespace == Some(cr_key.namespace)
   The first two collapse into one [Option.fold ~none:false], which is the
   [is Some] conjunct and its consequent read together. *)
let pod_bound ~(key_name : string) ~(key_namespace : string) (pod : Pod.t) :
    bool =
  let pm : Object_meta.t = Pod.metadata pod in
  Option.fold pm.name ~none:false ~some:(pod_name_matches key_name)
  && Option.equal String.equal pm.namespace (Some key_namespace)

(* E4's body, upstream :613-638, MINUS the pvcs forall (:629-637).

   C1, the NEEDED forall (:617-622). Upstream quantifies over indices with an
   [is Some] guard; the port has [needed : Pod.t option list]
   (v_stateful_set_reconciler.mli:47), so the index is eliminated entirely by
   [List.for_all] and THE [is Some] GUARD IS THE [~none:true]. That identity is
   the whole reason the fold direction is what it is.

   C2, the CONDEMNED forall (:623-628). Upstream has NO [Some] guard here
   (:624 reads [let pod = condemned_pods[i];] directly), and the port's
   [condemned : Pod.t list] (mli:49) has no option layer, so the two agree
   without a fold.

   EXCLUDED WITH A PIN: the pvcs forall :629-637 (six sub-conjuncts). Its only
   writers are v_stateful_set_reconciler.ml:509 and :553, both through
   [make_pvcs] (:292-296), which is [Option.value ~default:[]
   sp.volume_claim_templates] mapped and filtered - hence [[]] whenever
   [volume_claim_templates] is [None], which is exactly [vct:false]
   (scenario.ml:240-241), the only shape any P23 leg seeds. The omission is made
   behavior-free by an in-test assertion that every decoded ongoing state has
   [pvcs = []] on every P23 graph; the moment a [vct:true] leg lands, that pin
   reddens. Porting it instead would add a THIRD copy of [pvc_name_matches] for
   six sub-conjuncts that cannot fire. *)
let bound_in_local_state ~(key_name : string) ~(key_namespace : string)
    (st : V_stateful_set_reconciler.s) : bool =
  (* :617-622 *)
  List.for_all
    (fun (p : Pod.t option) ->
      Option.fold p ~none:true ~some:(pod_bound ~key_name ~key_namespace))
    st.V_stateful_set_reconciler.needed
  (* :623-628 *)
  && List.for_all
       (pod_bound ~key_name ~key_namespace)
       st.V_stateful_set_reconciler.condemned

(* L1's [interesting]: PREMISE-MIRRORING, not "the decode succeeded". At least
   one of the two ported quantifiers has a witness. The [inv16] precedent
   (invariants.ml:1016-1021) requires a NON-EMPTY [filtered_pods] for the same
   reason: counting a bare decode success would let a decode-DEFAULT register as
   assurance. *)
let local_binding_witness (st : V_stateful_set_reconciler.s) : bool =
  List.exists Option.is_some st.V_stateful_set_reconciler.needed
  || not (st.V_stateful_set_reconciler.condemned = [])

(* Upstream :647 plus :648-651 read as one content test - the request is a
   [ListRequest { kind: Kind::PodKind, namespace: cr_key.namespace }]. Copied
   from invariants.ml:334-347 (a private local [let] there), transposed VRS ->
   VSTS. All nine request constructors and all four content constructors are
   spelled out. *)
let list_req_content_matches (m : Message.t) ~(namespace : string) : bool =
  match m.content with
  | Message.Api_request (Api_method.List_request lr) ->
    Common.equal_kind lr.Api_method.kind Pod.kind
    && String.equal lr.Api_method.namespace namespace
  | Message.Api_request
      ( Api_method.Get_request _ | Api_method.Create_request _
      | Api_method.Delete_request _ | Api_method.Update_request _
      | Api_method.Update_status_request _
      | Api_method.Get_then_delete_request _
      | Api_method.Get_then_update_request _
      | Api_method.Get_then_update_status_request _ ) ->
    false
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    false

(* Upstream :657 [is_ok_resp(msg.content->APIResponse_0)] plus :659's
   [get_list_response().res.unwrap()], read together as "the content is a
   [List_response] whose [res] is [Ok]". Copied from invariants.ml:348-360.
   This is NARROWER than upstream's generic ok-ness and is disclosed as such in
   the .mli; it is sound only because :656 [resp_msg_matches_req_msg] has
   already pinned the response to the list request. *)
let list_resp_objs (m : Message.t) : Dynamic_object.t list option =
  match m.content with
  | Message.Api_response (Api_method.List_response lr) ->
    Result.to_option lr.Api_method.res
  | Message.Api_response
      ( Api_method.Get_response _ | Api_method.Create_response _
      | Api_method.Delete_response _ | Api_method.Update_response _
      | Api_method.Update_status_response _
      | Api_method.Get_then_delete_response _
      | Api_method.Get_then_update_response _
      | Api_method.Get_then_update_status_response _ ) ->
    None
  | Message.Api_request _ | Message.External_request _
  | Message.External_response _ ->
    None

(* The inner forall's PREMISE, upstream :652-657: in flight (:653), source is
   the api server (:655), the response matches the pending request (:656), and
   it is an ok response (:657). Copied from invariants.ml:361-368. *)
let ok_list_resps_for (s : Cluster.cluster_state) (req_msg : Message.t) :
    Message.t list =
  List.filter
    (fun (m : Message.t) ->
      Message.equal_host_id m.src Message.Api_server
      && Message.resp_msg_matches_req_msg m req_msg
      && Option.is_some (list_resp_objs m))
    (msgs s)

(* The inner forall's CONSEQUENT, upstream :659-661, and ONLY that: every object
   of the response carries [metadata.namespace == Some(cr_key.namespace)].
   [inv16]'s extra controller-owner-ref conjunct (invariants.ml:978-980) is
   DELIBERATELY NOT copied - upstream :660-661 carries one conjunct. *)
let resp_objs_in_namespace ~(namespace : string) (m : Message.t) : bool =
  Option.fold (list_resp_objs m) ~none:false ~some:(fun objs ->
      List.for_all
        (fun (o : Dynamic_object.t) ->
          let om : Object_meta.t = Dynamic_object.metadata o in
          Option.equal String.equal om.namespace (Some namespace))
        objs)

(* E5's second conjunct's consequent, upstream :644-662. [~none:false] IS
   upstream :645 [pending_req_msg is Some], the same polarity as [inv16]'s
   [pending_list_req_ok] (invariants.ml:371-376). *)
let after_list_pod_ok ~(namespace : string) (orc : Controller.ongoing_reconcile)
    (s : Cluster.cluster_state) : bool =
  Option.fold orc.pending_req_msg ~none:false ~some:(fun (rm : Message.t) ->
      (* :646 *)
      Message.equal_host_id rm.dst Message.Api_server
      (* :647-651 *)
      && list_req_content_matches rm ~namespace
      (* :652-662 *)
      && List.for_all (resp_objs_in_namespace ~namespace) (ok_list_resps_for s rm))

(* E5's second conjunct, upstream :643: an IMPLICATION guarded by
   [local_state.reconcile_step == AfterListPod], rendered as an EXHAUSTIVE
   17-arm match on [V_stateful_set_reconciler.step]
   (v_stateful_set_reconciler.mli:14-33) - the [inv16] shape
   (invariants.ml:1009-1015). No wildcard arm. *)
let step_binding ~(namespace : string) (orc : Controller.ongoing_reconcile)
    (st : V_stateful_set_reconciler.s) (s : Cluster.cluster_state) : bool =
  match st.V_stateful_set_reconciler.reconcile_step with
  | After_list_pod -> after_list_pod_ok ~namespace orc s
  | Init | Get_pvc | After_get_pvc | Create_pvc | After_create_pvc | Skip_pvc
  | Create_needed | After_create_needed | Update_needed | After_update_needed
  | Delete_condemned | After_delete_condemned | Delete_outdated
  | After_delete_outdated | Done | Error ->
    true

(* L2's [interesting] mirrors :643 plus :645 exactly: the step IS
   [After_list_pod] and the pending slot IS occupied. *)
let is_after_list_pod (st : V_stateful_set_reconciler.s) : bool =
  V_stateful_set_reconciler.step_equal
    st.V_stateful_set_reconciler.reconcile_step After_list_pod

(* The lookup/decode skeleton shared by both members and by both of their
   predicates, with BOTH out-of-premise directions supplied by the caller so the
   fold direction is visible at the member rather than buried here.

   [~absent] is E3's GUARD, BORROWED DELIBERATELY. Upstream :608 is
   [contains_key(k) && k.kind == VStatefulSetView::kind()], restricted here to
   the ONE scenario key; E4 is a pure function of [(cr_key, local_state)] and
   has no guard of its own, and E5's own body indexes a Verus TOTAL map
   unguarded (:641). The port has no total map, so the absent-key case folds to
   [~absent]. This is a rendering narrowing, not fidelity, and it is disclosed
   in the .mli in those words. [Object_ref_map.for_all] is deliberately NOT used
   here: that is E3's lift, which P23 excluded and P25 un-excluded - by calling
   OUT to this module ([holds_at_key], consumed by internal_guarantee.ml's
   standalone E3 value), not by duplicating the lift into it (BUILD-SPEC-P25
   §1.1).

   [~undecodable] mirrors Verus's unconstrained [unmarshal(...)->Ok_0] on a
   non-[Ok]: the house out-of-premise rule already stated at
   internal_guarantee.ml:53-55 - out of premise folds [holds] to [true] and
   [interesting] to [false]. There is no [Res.fold]; [Res.t] is
   [('a, Err.t) result] (res.mli:7), so stdlib [Result.fold] is used - the
   shipped idiom at invariants.ml:379-386 and fault_check.ml:431-436. Never a
   two-arm result match.

   [Cluster.ongoing_reconciles] is TOTAL: a missing controller id yields the
   empty map (cluster.mli:78-82), so a wrong [~controller_id] sends every state
   out of premise rather than raising. *)
let at_reconcile ~(controller_id : int) ~(cr_key : Common.object_ref)
    ~(absent : bool) ~(undecodable : bool)
    ~(decoded :
       Controller.ongoing_reconcile ->
       V_stateful_set_reconciler.s ->
       Cluster.cluster_state ->
       bool) (s : Cluster.cluster_state) : bool =
  Option.fold
    (Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id))
    ~none:absent
    ~some:(fun (orc : Controller.ongoing_reconcile) ->
      Result.fold
        (V_stateful_set_pack.unmarshal_state orc.local_state)
        ~error:(fun _ -> undecodable)
        ~ok:(fun (st : V_stateful_set_reconciler.s) -> decoded orc st s))

(* P25 §1.1: L2's decoded predicate at an ARBITRARY key, by partial-applying the
   existing [at_reconcile] skeleton - the ONE exported hook that lets
   {!Internal_guarantee}'s E3 lift fold L2 over every VSTS-kind key of
   [Cluster.ongoing_reconciles] without a third copy of L1/L2's body. Doc
   comment in the .mli. *)
let holds_at_key ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : bool =
  at_reconcile ~controller_id ~cr_key ~absent:true ~undecodable:true
    ~decoded:(fun (orc : Controller.ongoing_reconcile)
                  (st : V_stateful_set_reconciler.s) (s : Cluster.cluster_state) ->
      bound_in_local_state ~key_name:cr_key.Common.name
        ~key_namespace:cr_key.Common.namespace st
      && step_binding ~namespace:cr_key.Common.namespace orc st s)
    s

(* The upstream source literals, in member order L1, L2. BOTH ARE BARE: no
   parenthetical qualifier, ever. [t_p21_regression.ml:479-483] extracts the
   line with [String.rindex_opt s ':'] fed to [int_of_string_opt]; a qualifier
   makes that return [None], the member silently DROPS OUT of
   [roster_guarantee_lines] and the E-ledger firewall pin PASSES while the
   member is invisible. That is a vacuously-green pin. The four in-tree members
   at internal_guarantee.ml:377/:396/:416/:436 carry the same bare shape. *)
let binding_sources : string list =
  [
    "vstatefulset_controller/proof/internal_rely_guarantee.rs:613";
    "vstatefulset_controller/proof/internal_rely_guarantee.rs:640";
  ]

let binding_family ~(cr : V_stateful_set.t) ~(controller_id : int) :
    Invariants.invariant list =
  let cr_key = cr_key_of cr in
  let key_name = cr_key.Common.name in
  let key_namespace = cr_key.Common.namespace in
  let l1 =
    {
      Invariants.name = "vsts_local_pods_and_pvcs_bound_in_local_state";
      source = "vstatefulset_controller/proof/internal_rely_guarantee.rs:613";
      holds =
        at_reconcile ~controller_id ~cr_key ~absent:true ~undecodable:true
          ~decoded:(fun _orc st _s ->
            bound_in_local_state ~key_name ~key_namespace st);
      interesting =
        at_reconcile ~controller_id ~cr_key ~absent:false ~undecodable:false
          ~decoded:(fun _orc st _s -> local_binding_witness st);
    }
  in
  let l2 =
    {
      Invariants.name = "vsts_local_pods_and_pvcs_bound_with_key";
      source = "vstatefulset_controller/proof/internal_rely_guarantee.rs:640";
      holds =
        (* :642-663 via {!holds_at_key} - the ONE copy of L2's decoded body
           (P26 rider R1; P25 section 1.1 carried this reshape as the
           one-copy cleanup). *)
        holds_at_key ~controller_id ~cr_key;
      interesting =
        at_reconcile ~controller_id ~cr_key ~absent:false ~undecodable:false
          ~decoded:(fun orc st _s ->
            is_after_list_pod st && Option.is_some orc.pending_req_msg);
    }
  in
  [ l1; l2 ]

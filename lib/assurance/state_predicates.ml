(* BUILD-SPEC-P24 §2 / RULING §1-§3: the VSTS state-predicate register, the
   first shipped members of
   [vstatefulset_controller/proof/liveness/state_predicates.rs].

   The upstream file lives under [liveness/] but is entirely STATE-level: all
   34 [StatePred] occurrences are [-> StatePred<ClusterState>] and the file has
   zero [TempPred] / [ActionPred] / [leads_to] / [eventually] / [always(]
   (BUILD-SPEC-P24 §1, re-measured in the main loop). That is what makes it
   portable into a SAFETY register at all.

   TWO members, in family order:
   - M1 [local_state_is_valid] (:192-249), cited :192.
   - M3 [resp_msg_is_ok_list_resp_of_pods] (:107-133) closed over the state by
     [pending_list_pod_resp_in_flight] (:70-85), cited :107.

   THE THIRD CANDIDATE, M2, IS CUT, AND THE CUT IS A RECORDED NEGATIVE RESULT
   rather than an omission: upstream [req_msg_is_list_pod_req] (:45-57) closed
   by [pending_list_pod_req_in_flight] (:59-66), rendered as an invariant over
   this port's four graphs, is ENTIRELY CONTAINED in P23's shipped L2. The full
   record - the per-conjunct partition, the measurement that settles :49, and
   what a future phase would have to build to buy it - is the NEGATIVE RESULT
   block below and the matching block in the .mli. Do not re-add M2 without
   first reading it.

   SOURCE-STRING RULE, applied uniformly: the [source] names the upstream
   [pub open spec fn] whose CONJUNCTS the member renders, not the wrapper that
   turns them into a [StatePred]. RULING §4 fixes M1's as
   [state_predicates.rs:192]; M3 follows the same rule (:107 holds every ported
   conjunct, :70 supplies only the premise plumbing). BOTH are BARE - no
   parenthetical qualifier, ever - for the reason restated at
   [predicate_sources] below.

   DUPLICATE-AND-PIN, not export. [local_binding.mli] exports its two vals and
   nothing else, and [reconcile_correspondence.mli] likewise, so every helper
   this family borrows from them is COPIED with its origin cited - the house
   precedent stated in-tree at internal_guarantee.ml:131-136. The ONE new
   export this phase takes is [V_stateful_set_reconciler.objects_to_pods]
   (RULING §3.2), a pure-visibility change on live production logic.

   Every [holds]/[interesting] is total, pure and exception-free; every match on
   a finite sum is exhaustive (the seventeen reconcile steps, the nine
   [Api_method.api_request] and nine [Api_method.api_response] constructors, the
   four [Message.message_content] constructors), no wildcard arms; and upstream's
   index quantifiers are ELIMINATED ([List.mapi] to pair each slot with its
   ordinal, [List.find_opt] to select, [List.for_all] / [List.filter] /
   [List.fold_left] elsewhere) - no [List.nth], no [arr.(i)], no guarded
   raw-index wrapper. [List.to_seqi] and [Seq.find_opt] do NOT exist on this
   switch (OCaml 5.3.0); see [with_ordinals] below. *)

(* ---- helpers COPIED from {!Local_binding} (P23), origins cited ---------- *)

(* The in-flight projection, local_binding.ml:51-52 (itself internal_guarantee.ml
   :34-35, itself the [inv_self] precedent at vsts_invariants.ml:152). *)
let msgs (s : Cluster.cluster_state) : Message.t list =
  Message.Pool.distinct (Cluster.in_flight s)

(* The CR's namespace and name, local_binding.ml:61-65, with the same disclosed
   reading: Verus [metadata.namespace->0] / [name->0] on a [None] is an
   arbitrary total-map value, i.e. UNCONSTRAINED, and the port folds a missing
   field to the empty string - what the reconciler itself does
   (v_stateful_set_reconciler.ml:268-269, :604, :642). *)
let cr_namespace (cr : V_stateful_set.t) : string =
  Option.value ~default:"" (Object_meta.namespace (V_stateful_set.metadata cr))

let cr_name (cr : V_stateful_set.t) : string =
  Option.value ~default:"" (Object_meta.name (V_stateful_set.metadata cr))

(* Upstream's [cr_key], local_binding.ml:73-78 (itself internal_guarantee.ml
   :93-98) together with its totality decision: [V_stateful_set.object_ref] is
   [Common.object_ref Res.t] - partial, refusing a CR whose name or namespace is
   [None] - and a total classifier must not consume it (the P19 M2 / P20 R1
   precedent). *)
let cr_key_of (cr : V_stateful_set.t) : Common.object_ref =
  {
    Common.kind = V_stateful_set.kind;
    name = cr_name cr;
    namespace = cr_namespace cr;
  }

(* local_binding.ml:174-188 verbatim (there a copy of invariants.ml:348-360):
   "the content is a [List_response] whose [res] is [Ok]", carrying upstream
   :113 and :114 together. The narrowing versus a generic [is_ok_resp] is the
   one P23 already disclosed (local_binding.mli:97-101). *)
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

(* local_binding.ml:193-200 verbatim (there a copy of invariants.ml:361-368).
   For M3 this is the POPULATION upstream :80-81 quantifies over, narrowed by
   :113-:114 - see [ok_list_resp_shape] for why that narrowing is where it is. *)
let ok_list_resps_for (s : Cluster.cluster_state) (req_msg : Message.t) :
    Message.t list =
  List.filter
    (fun (m : Message.t) ->
      Message.equal_host_id m.src Message.Api_server
      && Message.resp_msg_matches_req_msg m req_msg
      && Option.is_some (list_resp_objs m))
    (msgs s)

(* local_binding.ml:244-246: the step IS [After_list_pod]. *)
let is_after_list_pod (st : V_stateful_set_reconciler.s) : bool =
  V_stateful_set_reconciler.step_equal
    st.V_stateful_set_reconciler.reconcile_step After_list_pod

(* The lookup/decode skeleton, local_binding.ml:272-286 verbatim, with its two
   out-of-premise directions still supplied by the caller so the fold direction
   is visible at the member. [~absent] is E3's borrowed guard restricted to the
   ONE scenario key; [~undecodable] mirrors Verus's unconstrained
   [unmarshal(...)->Ok_0] under the house out-of-premise rule
   (internal_guarantee.ml:53-55): [holds] folds to [true], [interesting] to
   [false]. [Cluster.ongoing_reconciles] is TOTAL - a missing controller id
   yields the empty map (cluster.mli:78-82) - so a wrong [~controller_id] sends
   every state out of premise rather than raising. *)
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

(* ---- M1's own ingredients ------------------------------------------------ *)

(* Upstream [replicas] (trusted/liveness_theorem.rs:84-89):
   [vsts.spec.replicas] with [None] folded to 1. The reconciler itself renders
   it identically at v_stateful_set_reconciler.ml:545-546. *)
let replicas_of (cr : V_stateful_set.t) : int =
  Option.value ~default:1 (V_stateful_set.spec cr).Stateful_set.replicas

(* Upstream :235-:238 index [state.needed] at [needed_index] and at
   [needed_index - 1]. The index is ELIMINATED, per the assurance-family rule
   local_binding.mli:292-293 states about itself: each slot is PAIRED with its
   ordinal by a pure combinator pass and then SELECTED by [List.find_opt], so
   there is no [List.nth], no [arr.(i)] and no guarded raw-index wrapper
   anywhere in this module.

   MAIN-LOOP-GROUND-TRUTH.md:79 names [List.to_seqi] + [Seq.find_opt]; NEITHER
   exists in the stdlib on this switch (OCaml 5.3.0 - only [String] and [Array]
   have a [to_seqi], and [Seq]'s is [find] / [find_map]). Build-verified
   correction: [List.mapi] does the pairing and [List.find_opt] the selection,
   which is the same index-elimination with names that compile.

   The OUTER option is "there is no such slot"; the INNER option is upstream's
   own [Pod.t option] slot. An absent slot is out of premise, so both readers
   below fold it to [true] - upstream cannot index out of range there either,
   because conjunct :230-231 pins [needed_index < needed.len()] at
   [CreateNeeded]/[UpdateNeeded] and conjunct :242 pins [needed_index > 0] at
   [AfterCreateNeeded]/[AfterUpdateNeeded]. *)
let with_ordinals (slots : Pod.t option list) : (int * Pod.t option) list =
  List.mapi (fun (ord : int) (p : Pod.t option) -> (ord, p)) slots

let slot_at (needed : Pod.t option list) (i : int) : Pod.t option option =
  Option.map snd
    (List.find_opt
       (fun ((j, _) : int * Pod.t option) -> j = i)
       (with_ordinals needed))

let slot_is_none (needed : Pod.t option list) (i : int) : bool =
  Option.fold (slot_at needed i) ~none:true ~some:Option.is_none

let slot_is_some (needed : Pod.t option list) (i : int) : bool =
  Option.fold (slot_at needed i) ~none:true ~some:Option.is_some

(* Upstream's [locally_at_step_or!] (proof/predicate.rs:185-197) renders as an
   EXHAUSTIVE 17-arm match on [V_stateful_set_reconciler.step]
   (v_stateful_set_reconciler.mli:14-33) with grouped arms and NO wildcard - the
   [step_binding] precedent (local_binding.ml:232-240, itself the [inv16] shape
   at invariants.ml:1009-1015). Never a [List.mem] over a literal step list:
   that silently omits a newly-added step instead of forcing a revisit. *)

(* :230's group. *)
let at_pvc_or_needed_step (step : V_stateful_set_reconciler.step) : bool =
  match step with
  | Get_pvc | After_get_pvc | Create_pvc | After_create_pvc | Skip_pvc
  | Create_needed | Update_needed ->
    true
  | Init | After_list_pod | After_create_needed | After_update_needed
  | Delete_condemned | After_delete_condemned | Delete_outdated
  | After_delete_outdated | Done | Error ->
    false

(* :242's group. *)
let at_after_needed_step (step : V_stateful_set_reconciler.step) : bool =
  match step with
  | After_create_needed | After_update_needed -> true
  | Init | After_list_pod | Get_pvc | After_get_pvc | Create_pvc
  | After_create_pvc | Skip_pvc | Create_needed | Update_needed
  | Delete_condemned | After_delete_condemned | Delete_outdated
  | After_delete_outdated | Done | Error ->
    false

(* :248's group, which upstream NEGATES ([!locally_at_step_or!(...)]). *)
let at_condemned_or_later_step (step : V_stateful_set_reconciler.step) : bool =
  match step with
  | Delete_condemned | After_delete_condemned | Delete_outdated
  | After_delete_outdated | Done ->
    true
  | Init | After_list_pod | Get_pvc | After_get_pvc | Create_pvc
  | After_create_pvc | Skip_pvc | Create_needed | After_create_needed
  | Update_needed | After_update_needed | Error ->
    false

(* M1's PREMISE, and it is upstream's own, not an invention of this port.
   [local_state_is_valid] is never asserted bare: it is reached only through
   [local_state_is_valid_and_coherent] (:181-190), and EVERY call site of that
   conjoins an [at_vsts_step(vsts, controller_id, at_step![...])] guard
   (state_predicates.rs:142/151/162/171/884/891/905/912/921/928 and the
   resource_match.rs sites). Measured over every such site, the union of those
   guards is exactly the FOURTEEN post-partition steps below; [Init],
   [AfterListPod] and [Error] never appear among them.

   The guard is LOAD-BEARING, not decoration: [needed] is written once, at the
   [After_list_pod] arm (v_stateful_set_reconciler.ml:550-558), so at [Init] and
   [After_list_pod] the decoded [needed] is still [[]] while conjunct :194 wants
   [needed.len() == replicas]. Dropping the guard would make M1 red on states
   upstream never asserts it at - a red that is not a finding. *)
let at_valid_step (step : V_stateful_set_reconciler.step) : bool =
  match step with
  | Get_pvc | After_get_pvc | Create_pvc | After_create_pvc | Skip_pvc
  | Create_needed | After_create_needed | Update_needed | After_update_needed
  | Delete_condemned | After_delete_condemned | Delete_outdated
  | After_delete_outdated | Done ->
    true
  | Init | After_list_pod | Error -> false

(* M1's body: upstream [local_state_is_valid] :192-249, FOURTEEN of its
   twenty-three conjuncts. The NINE EXCLUDED-WITH-A-PIN ones (:197 :198 :199
   :215-221 :223-228 :233 :244 :246, plus the :193 [pvc_cnt] binding they all
   read, and - since stage B measured it - :241) are enumerated in the .mli
   with the pin that kills each; nothing about [pvcs] or [pvc_index] appears
   below, and neither does [get_largest_unmatched_pods].

   Upstream's [needed_index]/[condemned_index] are [nat]. The port's fields are
   [int] (v_stateful_set_reconciler.mli:48, :50), so the [>= 0] half of :195 and
   :196 is written out rather than carried by the type. That is the nat TYPE
   rendered, not an extra conjunct - and it is disclosed in the .mli. *)
let local_state_is_valid ~(parent : string) ~(namespace : string)
    ~(replicas : int) (st : V_stateful_set_reconciler.s) : bool =
  let step = st.V_stateful_set_reconciler.reconcile_step in
  let needed = st.V_stateful_set_reconciler.needed in
  let condemned = st.V_stateful_set_reconciler.condemned in
  let needed_index = st.V_stateful_set_reconciler.needed_index in
  let condemned_index = st.V_stateful_set_reconciler.condemned_index in
  let needed_len = List.length needed in
  let condemned_len = List.length condemned in
  (* :194 *)
  needed_len = replicas
  (* :195 *)
  && needed_index >= 0
  && needed_index <= needed_len
  (* :196 *)
  && condemned_index >= 0
  && condemned_index <= condemned_len
  (* :200-204 - the NEEDED forall. Upstream's [is Some] guard IS the
     [~none:true], the identity P23 established at local_binding.ml:107-108.
     :202 wants the EXACT ordinal-indexed name [pod_name(parent, ord)], which is
     strictly stronger than P23 L1's "some ordinal parses" (its
     [pod_name_matches] is [Option.is_some (get_ordinal parent name)]), so it is
     rendered forwards through [pod_name], not by inversion. *)
  && List.for_all
       (fun ((ord, po) : int * Pod.t option) ->
         Option.fold po ~none:true ~some:(fun (pod : Pod.t) ->
             let pm : Object_meta.t = Pod.metadata pod in
             Option.equal String.equal pm.name
               (Some (V_stateful_set_reconciler.pod_name parent ord))
             && Option.equal String.equal pm.namespace (Some namespace)))
       (with_ordinals needed)
  (* :205-214 - the CONDEMNED forall. No [Some] guard upstream (:207 reads
     [state.condemned[i]] directly) and no option layer in the port's
     [condemned : Pod.t list], so the two agree without a fold. :210 ([name is
     Some]) and :211 ([get_ordinal ... is Some]) collapse into the two nested
     [~none:false] folds; :212's [>= replicas] ordinal BOUND has no P23
     counterpart at all. *)
  && List.for_all
       (fun (pod : Pod.t) ->
         let pm : Object_meta.t = Pod.metadata pod in
         Option.fold pm.name ~none:false ~some:(fun (n : string) ->
             Option.fold
               (V_stateful_set_reconciler.get_ordinal parent n)
               ~none:false
               ~some:(fun (o : int) -> o >= replicas))
         && Option.equal String.equal pm.namespace (Some namespace))
       condemned
  (* :230-231 *)
  && ((not (at_pvc_or_needed_step step)) || needed_index < needed_len)
  (* :235 *)
  && ((not
         (V_stateful_set_reconciler.step_equal step Create_needed))
     || slot_is_none needed needed_index)
  (* :236 *)
  && ((not
         (V_stateful_set_reconciler.step_equal step After_create_needed))
     || slot_is_none needed (needed_index - 1))
  (* :237 *)
  && ((not
         (V_stateful_set_reconciler.step_equal step Update_needed))
     || slot_is_some needed needed_index)
  (* :238 *)
  && ((not
         (V_stateful_set_reconciler.step_equal step After_update_needed))
     || slot_is_some needed (needed_index - 1))
  (* :239 *)
  && ((not
         (V_stateful_set_reconciler.step_equal step Delete_condemned))
     || condemned_index < condemned_len)
  (* :240 *)
  && ((not
         (V_stateful_set_reconciler.step_equal step After_delete_condemned))
     || condemned_index > 0)
  (* :241 IS NOT HERE - it moved to EXCLUDE-WITH-A-PIN before the phase sealed,
     on the REACHABILITY ground, exactly as RULING section 1's open obligation
     required. Stage B's [reconcile_step] occupancy histogram (probe B2,
     p24_witness.ml) measured [After_delete_outdated] at 0 on ALL FOUR graphs
     BL0/BLc/BLd/BLm, pinned here as
     [P24_witness.after_delete_outdated_occupancy_everywhere = 0] with
     [Delete_outdated] itself non-zero on every graph as its positive control.
     Its guard can never fire, so its consequent
     ([get_largest_unmatched_pods(vsts, needed) is Some]) is a green that could
     not have been red - the same defect condition :246 is excluded on. The pin
     is measured on THESE graphs and is NEVER inherited from
     t_p11_vsts_liveness.ml:113-114, which is a different, smaller 20-state
     [fair:true] P11 graph. See the .mli. *)
  (* :242 *)
  && ((not (at_after_needed_step step)) || needed_index > 0)
  (* :248 *)
  && (at_condemned_or_later_step step || condemned_index = 0)

(* M1's [interesting] is upstream's own [at_vsts_step] conjunct and nothing
   weaker: the reconcile at the CR key exists, decodes, AND its step is one of
   the fourteen at which upstream ever asserts the predicate. Counting a bare
   decode success would let a decode-DEFAULT register as assurance - the [inv16]
   ground P23 reused at local_binding.ml:137-141. *)
let local_state_valid_witness (st : V_stateful_set_reconciler.s) : bool =
  at_valid_step st.V_stateful_set_reconciler.reconcile_step

(* ==== THE NEGATIVE RESULT: M2 IS CUT, AND THIS IS THE FINDING ==============
   Upstream [req_msg_is_list_pod_req] (:45-57) closed over the cluster state by
   [pending_list_pod_req_in_flight] (:59-66) was written, built, measured and
   mutation-tested as a third member of this family, and the main loop has RULED
   it CUT. This block is the record; the .mli carries the same one for
   consumers. It is a FINDING, not a deletion, and re-adding the member without
   answering it would re-ship P23's L2 under a fresh
   [state_predicates.rs:45] citation.

   THE RESULT, in one sentence: rendered as an INVARIANT over this port's four
   graphs, all seven of that predicate's conjuncts are ENTIRELY CONTAINED in
   P23's shipped L2 - five of them literally, one by entailment from the port's
   own rendering premise, and the last one, :49, by measuring TRUE at every
   state at which it is ever evaluated.

   THE PER-CONJUNCT PARTITION, which is what "contained" means here.
   - FIVE ARE LITERALLY L2's. :50 ([dst == APIServer]) is local_binding.ml:221;
     :51 (the content is an [APIRequest]) is the literal [false] arms of L2's
     own [list_req_content_matches], local_binding.ml:164-166; :52 (the request
     is a [ListRequest]) is :153-155; :53-56 ([kind: PodKind] and
     [namespace: cr_key.namespace]) is :151-166; and :64
     ([pending_req_msg_is]) is discharged by reading the [pending_req_msg] slot,
     which L2 (:217-225) already does.
   - :65 ([s.in_flight().contains(req_msg)]) IS ENTAILED BY THE PORT'S OWN
     RENDERING PREMISE, and the entailment is MEASURED, not argued. Upstream's
     [pending_list_pod_req_in_flight] is a liveness MILESTONE, so asserted of
     every parked state it would be red by construction; the port therefore
     narrowed the premise to the DELIVERY WINDOW ("parked at [AfterListPod],
     pending slot [Some], no matching response in flight yet"). Stage B counted
     the raw-in-flight population and that window SEPARATELY, by two different
     routes, and got 8 / 52 / 48 / 744 BOTH times, on every one of the four
     graphs. Equal populations means no reachable state in the premise has :65
     false, which is why mutant M2b' was STRUCK as unfailable. Both probes stay
     LIVE in {!P24_witness} ([pending_still_in_flight] and [delivery_window])
     and [t_p24_state_predicates] now ASSERTS their equality, so this half of
     the finding is a row rather than a sentence.
   - :49 ([req_msg.src == Controller(controller_id, vsts_key)]) IS THE ONE
     CONJUNCT L2 GENUINELY LACKS, AND IT IS UNWITNESSED. Its absence from L2 is
     real: exactly one [.src] occurrence exists across local_binding.ml/.mli and
     it is on the RESPONSE variable inside [ok_list_resps_for] (:193-200), while
     [after_list_pod_ok] (:217-225) checks [rm.dst] and the content and never
     [rm.src]; upstream internal_rely_guarantee.rs:640-664, L2's own source, has
     no [req_msg.src] conjunct either. But probe B4 measures the pending
     request's [src] over the WHOLE parked-with-pending population - denominators
     16 / 112 / 288 / 1560 on SP0 / SPc / SPd / SPm - and the
     src-is-NOT-this-controller count is {b 0 on all four}, pinned as
     [P24_witness.pending_src_not_controller_everywhere]. Upstream :49 is TRUE
     at every state at which it is evaluated. It is a GREEN THAT COULD NOT HAVE
     BEEN RED - this phase's own defect condition, the one that already excluded
     :241, :246 and the eight PVC conjuncts.

   WHY THE M2a' MUTANT DID NOT RESCUE IT. M2a' (swap [.src] for [.dst] in the
   ported :49) WAS run and DID redden the P24 leg with P23's leg green in the
   same run. It does not discriminate. Because the src is [Controller (id, key)]
   at every state in the premise and the dst is [Api_server] at every state in
   the premise, the swapped conjunct is FALSE on the ENTIRE premise population,
   so the leg reds trivially. That shows the conjunct is load-bearing FOR THE
   MUTANT; it does not show :49 has any exercisable content. The ship gate as
   written (RULING §2: "M2 ships iff at least one of M2a' / M2b' is SEEN RED on
   the P24 leg while the P23 leg stays GREEN") was UNDERSPECIFIED - it did not
   require the mutant to be NON-TRIVIALLY falsifying - which is the same class
   of error as RULING §3.3's vacuity-only gate, and the main loop has said so
   rather than letting the gate's letter carry a member its spirit rejects.

   WHAT WOULD BUY :49. A graph carrying a pending request at [AfterListPod]
   whose [src] is NOT [Controller (controller_id, cr_key)] - some other
   controller's request parked in this controller's slot, or an [Api_server] /
   [Pod_monkey] / [External] source. NO CURRENT SEED PRODUCES ONE:
   [Message.controller_req_msg] (lib/cluster/message.ml:175-179) is the only
   constructor the reconcile path uses and it always stamps
   [~src:(Controller (controller_id, cr_key))]. Producing one requires a NEW
   SEED, and adding a seed would move the shared graphs and every committed
   P13-P23 pin with them. So it is NOT added, and :49 is CARRIED TO P25 exactly
   the way upstream :112's unobserved owner-reference reject path already is
   (see the M3 block below): disclosed, pinned at zero, with the seed that would
   buy it named and deliberately not built.

   WHAT CAME OUT WITH M2. [req_msg_is_list_pod_req] (the :49-:56 rendering),
   [list_req_content_matches] (its :51-56 half, itself a copy of
   local_binding.ml:151-166) and [matching_resp_in_flight] (the
   reconcile_correspondence.ml:103-107 copy that supplied the delivery-window
   narrowing) all lost their only consumer here and are REMOVED - a helper whose
   last consumer goes away goes with it. The WITNESS-side copies do NOT go:
   {!P24_witness}'s [pending_src_*], [pending_still_in_flight] and
   [delivery_window] probes are now this negative result's evidence and stay
   assertable. *)

(* ---- M3's own ingredients ------------------------------------------------ *)

(* Upstream :115 reads [resp_objs.map_values(|obj| obj.object_ref())
   .no_duplicates()], and [DynamicObjectView::object_ref()] is
   [ObjectRef { kind, name: metadata.name->0, namespace: metadata.namespace->0 }]
   - two [->0] readings of an [Option]. The port's [Dynamic_object.object_ref]
   (dynamic_object.mli:29) is [Common.object_ref Res.t], i.e. PARTIAL, and a
   total classifier must not consume it (the P19 M2 / P20 R1 precedent that
   [cr_key_of] above already applies), so the ref is built totally with the same
   [Option.value ~default:""] rendering. On any state where the ported :128-:129
   conjuncts hold, both fields are [Some] and the two renderings coincide. *)
let dyn_object_ref (o : Dynamic_object.t) : Common.object_ref =
  let om : Object_meta.t = Dynamic_object.metadata o in
  {
    Common.kind = Dynamic_object.kind o;
    name = Option.value ~default:"" om.name;
    namespace = Option.value ~default:"" om.namespace;
  }

(* [Seq.no_duplicates] over a Verus [Seq], rendered as a fold that carries the
   refs already seen - gather, never scatter, and no index. *)
let no_duplicate_object_refs (objs : Dynamic_object.t list) : bool =
  snd
    (List.fold_left
       (fun ((seen : Common.object_ref list), (ok : bool))
            (o : Dynamic_object.t) ->
         let r = dyn_object_ref o in
         (r :: seen, ok && not (List.exists (Common.equal_object_ref r) seen)))
       ([], true) objs)

(* M3's body: the PURE-SHAPE half of upstream
   [resp_msg_is_ok_list_resp_of_pods] and nothing else. SEVEN conjuncts ship -
   :115, :126, :127, :128, :129, :130 and :132 - and the two ETCD-CONSUMING
   ones, :116-118 and :119-124, are EXCLUDED-WITH-A-PIN on a SCOPE ground
   documented at the bottom of this file and in the .mli.

   WHERE :113 AND :114 WENT. They are carried by [list_resp_objs] and therefore
   by the [ok_list_resps_for] POPULATION, not by this consequent. That is
   deliberate and is disclosed in the .mli: a matched ERROR list-response is
   reachable on the fault graphs ([Cluster.drop_req] forms one through
   [Message.form_matched_err_resp_msg]), and upstream only ever asserts
   [resp_msg_is_ok_list_resp_of_pods] under the :79-83 EXISTENTIAL, never of
   every matching response, so hoisting :114 into the consequent would redden
   the member on a path upstream makes no claim about.

   :126 IS ENTAILED BY :127 AND IS THEREFORE NOT SEPARATELY KILLABLE, disclosed
   here on the same terms as :65 and :113/:114 rather than left implied. [Pod] is
   [Resource_view.Make (R)] (k8s_objects/views/pod.ml:64), and that functor's
   [unmarshal] (k8s_objects/resource_view.ml:58-68) opens with

     if Common.equal_kind dk R.kind then ... else error (Err.Kind_mismatch ...)

   so [Result.is_ok (Pod.unmarshal o)] IMPLIES
   [Common.equal_kind (Dynamic_object.kind o) Pod.kind] for every
   [Dynamic_object.t], on every graph and on any forged state. Deleting :126
   would not change this predicate's truth value ANYWHERE, so no DELETION mutant
   of it can redden and no test can be written that :126 alone passes. What a
   token-swap mutant of the [Pod.kind] CONSTANT demonstrates is that the shape
   check is REACHED and EVALUATED - which is worth having, and is what the
   [t_p24_mutation] M3a row records - but it is not evidence that the conjunct
   CARRIES anything, because a strengthened conjunct reddens whether or not the
   original was load-bearing. :126 STAYS: it is upstream's conjunct, fidelity is
   the reason it is here, and this note is the honest label rather than a
   deletion. (The same reading applies to :132: [objects_to_pods]
   (v_stateful_set_reconciler.ml:461-463) is [Result.is_error (Pod.unmarshal o)]
   over the SAME [objs], so :132 and the [List.for_all] of :127 are mutually
   entailing. It too is ported for fidelity.)

   The [~none:false] arm is unreachable by construction - every element of
   [ok_list_resps_for] already has [Some] objs - and takes [resp_objs_in_namespace]'s
   polarity (local_binding.ml:207) rather than inventing one.

   NO [~owner_ref] PARAMETER SURVIVES. It existed only to instantiate upstream
   :112's [owned_objs] filter for the two excluded conjuncts; with them gone the
   CR's controller owner reference is not read by this family at all, and
   carrying a parameter nothing consumes would be the dead code the house rule
   forbids. The probes that measure the exclusion's evidence keep their own
   copies in {!P24_witness} tier 3, where they are live. *)
let ok_list_resp_shape ~(namespace : string) (m : Message.t) : bool =
  Option.fold (list_resp_objs m) ~none:false
    ~some:(fun (objs : Dynamic_object.t list) ->
      (* :115 *)
      no_duplicate_object_refs objs
      (* :125-131 *)
      && List.for_all
           (fun (o : Dynamic_object.t) ->
             let om : Object_meta.t = Dynamic_object.metadata o in
             (* :126 - ENTAILED by :127 on the next line
                (resource_view.ml:58-68 errors [Kind_mismatch] unless the kinds
                match), so it is ported for FIDELITY and is NOT separately
                killable. See the note above and the .mli. *)
             Common.equal_kind (Dynamic_object.kind o) Pod.kind
             (* :127 *)
             && Result.is_ok (Pod.unmarshal o)
             (* :128 *)
             && Option.is_some om.name
             (* :129-130 - the [is Some] conjunct and its consequent read
                together, the [pod_bound] identity at local_binding.ml:95. This
                one conjunct IS carried by P23's L2
                ([resp_objs_in_namespace], local_binding.ml:206-212); the
                containment is disclosed in the .mli. *)
             && Option.equal String.equal om.namespace (Some namespace))
           objs
      (* :132 - the newly exported reconciler helper. *)
      && Option.is_some (V_stateful_set_reconciler.objects_to_pods objs))

(* THE STAGE-B FORK RESOLVED NON-ZERO, THE CONJUNCTS WERE SHIPPED, THEY WERE
   REFUTED, AND THE MAIN LOOP HAS RULED: :116-118 AND :119-124 ARE
   EXCLUDED-WITH-A-PIN ON A **SCOPE** GROUND.

   THE GROUND, stated so a consumer can check it rather than take it.
   1. Upstream scopes the coherence itself. state_predicates.rs:116 reads, in
      full and verbatim:

        // coherence with etcd which preserves across steps taken by other
        // controllers satisfying rely conditions

      and :111, one line above the [owned_objs] binding those conjuncts
      quantify over, reads

        // these objects can be guarded by rely conditions

   2. THIS PORT HAS NO RELY-CONDITION MACHINERY. That is a fact about the port,
      stated as one: {!Rely_conditions} carries the P12 rely/guarantee
      correspondence members, and nothing in [lib/] constrains which writers may
      touch a CR-owned object between a list response being formed and being
      observed. There is no predicate here that a writer could be required to
      satisfy.
   3. THE FAULT GRAPHS INJECT, BY CONSTRUCTION, EXACTLY THE WRITERS THE
      ASSUMPTION EXCLUDES. BLc replays a crash-orphaned request late; BLm runs
      the pod monkey. Both are rely-violating by design - that is what the
      budget dimension is FOR.
   4. Therefore asserting these two conjuncts over BLc and BLm asserts
      upstream's predicate OUTSIDE ITS STATED SCOPE. Relaxing the leg assertion,
      or narrowing M3's premise until the failures fall outside it, would each
      be the retune this project forbids. EXCLUSION WITH A PIN is the phase's
      established mechanism - it is used nine times in M1 - and it is the one
      applied here.

   THE PIN IS A MEASURED REFUTATION WITH ATTRIBUTION, NOT A VACUITY, WHICH IS
   WHY IT IS STRONGER THAN THE OTHER NINE. The PVC pin and the :241 / :246 pins
   record a green that could not have been red. This one records conjuncts that
   were rendered, run over all four graphs and SEEN RED at named states. Every
   number below is ASSERTED, in [P24_witness]'s MEASURED block and in
   [t_p24_state_predicates]'s [scope_exclusion_pin] case, off probe B5 - which
   stays LIVE after the conjuncts are gone, because it is now the pin's
   evidence:

   - :116-118 SET-EQUALITY failures 0 / 8 / 0 / 72 on SP0 / SPc / SPd / SPm,
     the SPc 8 splitting 4 (etcd holds a valid-owned object the response does
     not) + 4 (the response holds an owned object etcd no longer has) and the
     SPm 72 splitting 32 + 40, each direction on its own traversal;
   - :119-124 COHERENCE failures 0 / 4 / 0 / 40, and EVERY ONE of them the :122
     key-presence conjunct (the :123 half contributes zero);
   - [weakly_eq]'s OWN comparison disagreements: 0 metadata, 0 kind and 0 spec
     on EVERY graph, over a comparison population of 8 / 60 / 40 / 736 that is
     asserted non-zero first. THIS IS THE LOAD-BEARING FACT. It is what makes
     the diagnosis "the in-flight response is STALE relative to etcd" rather
     than "[weakly_eq] is wrong", so it is pinned rather than narrated;
   - MULTI-MATCHING-RESPONSE states 0 on every graph (bucket ["2+"] of a
     three-column histogram that SUMS to the parked-with-pending population),
     which rules out a universal-vs-existential artifact: no premise state
     carries two matching ok list-responses that could disagree.

   AND THE ATTRIBUTION WAS MEASURED BEFORE THE CONJUNCTS CAME OUT. With them
   still shipped, M3's per-state RED count on the replica was 0 / 8 / 0 / 72 -
   EQUAL, graph by graph, to the union of the two probe columns. The member's
   red set was exactly the set probe B5 selects, so the exclusion removes those
   states and nothing else. That identity is no longer assertable (the shipped
   member is green everywhere now); both halves are PRINTED side by side in the
   B5 dump, where the shipped column must read 0 and the refutation column must
   read the pinned 0 / 8 / 0 / 72.

   WHAT CAME OUT WITH THEM. [weakly_eq] (proof/predicate.rs:26-30),
   [owned_objs] (:112), [valid_owned_object] (predicate.rs:44-52),
   [etcd_valid_owned_refs] and [ref_set_equal] were all written, all correct as
   far as they were exercised, and all lost their only consumer here. They are
   REMOVED rather than kept behind a flag, because a helper whose last consumer
   goes away goes with it. [weakly_eq]'s status is recorded in the .mli so P25
   can restore it in four lines: it was PORTED, its METADATA arm was
   MUTATION-KILLED, its SPEC arm was a recorded test gap, and it is gone as a
   CONSEQUENCE OF THE SCOPE EXCLUSION and not of any defect in it.

   RECORDED FOR P25, superseding RULING §3.3(4)'s SHIP-fork reading. P25's :256
   flagship is 114 lines of the same etcd-wide correlation at much larger
   scale. It does NOT inherit a rendered precedent: it inherits this exclusion
   and the rely-condition question underneath it. Either P25 lands
   rely-condition machinery (at which point these two conjuncts, [weakly_eq]
   with them, come back into scope together and this pin retires), or it
   excludes :256 on the same SCOPE ground - and it may not commit an
   etcd-coherence conjunct without answering that first. *)

(* ---- the family ---------------------------------------------------------- *)

(* The upstream source literals, in member order M1, M3. BOTH ARE BARE: no
   parenthetical qualifier, ever. [t_p21_regression.ml:479-483] extracts the
   line with [String.rindex_opt s ':'] fed to [int_of_string_opt]; a qualifier
   makes that return [None], the member silently DROPS OUT of the roster and the
   firewall pin PASSES while the member is invisible. That is a vacuously-green
   pin, this project's named failure mode. Per-conjunct partition detail belongs
   in this comment and in the .mli, never in the string.

   :45 IS ABSENT ON PURPOSE. The cut member's citation is not parked here in any
   form - not as a qualified string, not as a commented-out entry - because a
   source list is the roster's input and a cut member must not be reachable
   through it. Its record is the NEGATIVE RESULT block above. *)
let predicate_sources : string list =
  [
    "vstatefulset_controller/proof/liveness/state_predicates.rs:192";
    "vstatefulset_controller/proof/liveness/state_predicates.rs:107";
  ]

let predicate_family ~(cr : V_stateful_set.t) ~(controller_id : int) :
    Invariants.invariant list =
  let cr_key = cr_key_of cr in
  let parent = cr_key.Common.name in
  let namespace = cr_key.Common.namespace in
  let replicas = replicas_of cr in
  let m1 =
    {
      Invariants.name = "vsts_local_state_is_valid";
      source = "vstatefulset_controller/proof/liveness/state_predicates.rs:192";
      holds =
        at_reconcile ~controller_id ~cr_key ~absent:true ~undecodable:true
          ~decoded:(fun _orc st _s ->
            (* the borrowed [at_vsts_step] premise, then :194-:248 *)
            (not (at_valid_step st.V_stateful_set_reconciler.reconcile_step))
            || local_state_is_valid ~parent ~namespace ~replicas st);
      interesting =
        at_reconcile ~controller_id ~cr_key ~absent:false ~undecodable:false
          ~decoded:(fun _orc st _s -> local_state_valid_witness st);
    }
  in
  let m3 =
    {
      Invariants.name = "vsts_pending_list_pod_resp_in_flight";
      source = "vstatefulset_controller/proof/liveness/state_predicates.rs:107";
      holds =
        at_reconcile ~controller_id ~cr_key ~absent:true ~undecodable:true
          ~decoded:(fun orc st s ->
            (not (is_after_list_pod st))
            || Option.fold orc.pending_req_msg ~none:true
                 ~some:(fun (rm : Message.t) ->
                   List.for_all
                     (ok_list_resp_shape ~namespace)
                     (ok_list_resps_for s rm)));
      interesting =
        at_reconcile ~controller_id ~cr_key ~absent:false ~undecodable:false
          ~decoded:(fun orc st s ->
            is_after_list_pod st
            && Option.fold orc.pending_req_msg ~none:false
                 ~some:(fun (rm : Message.t) ->
                   not (ok_list_resps_for s rm = [])));
    }
  in
  [ m1; m3 ]

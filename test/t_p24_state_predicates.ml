(* BUILD-SPEC-P24 sections 2-4 and RULING.md sections 1-3 - the P24
   STATE-PREDICATE measurement:
   {!Anvil_checker.Fault_check.check_state_predicates_under_faults} (the M1/M3
   family of {!Anvil_assurance.State_predicates.predicate_family}) over the four
   graphs SP0 / SPc / SPd / SPm, which are P23's BL0 / BLc / BLd / BLm ridden
   UNCHANGED.

   ==== WHAT THIS FILE PINS: THREE MEASURED ZEROES AND ONE MEASURED REFUTATION =

   RULING section 7 sequences the phase A (write) -> B (measure) -> C (mutate),
   and a pin typed before its measurement is a guess dressed as evidence. Stage
   A therefore pinned no P24 number at all. Stage B has since run and this file
   asserts THREE measured literals that are ZEROES a phase decision rests on,
   all read out of {!P24_witness} and never typed here:
   [after_delete_outdated_occupancy_everywhere] (the :241 exclusion pin),
   [ok_resp_some_unowned_obj_everywhere] (the owner-reference filter's
   never-observed reject path) and [pending_src_not_controller_everywhere] (the
   zero that CUT the M2 candidate: upstream :49 is TRUE at every state at which
   it is evaluated, over denominators 16 / 112 / 288 / 1560). Each sits behind
   its own POSITIVE CONTROLS, so none is a vacuous zero.

   THE FAMILY HAS TWO MEMBERS BECAUSE OF THE THIRD OF THOSE. M2 - upstream
   [req_msg_is_list_pod_req] :45-57 closed by [pending_list_pod_req_in_flight]
   :59-66 - was written, built, measured and mutation-tested, and is CUT: five
   of its seven conjuncts are literally P23's L2, :65 is entailed by the port's
   own rendering premise (the [pending_still_in_flight] / [delivery_window]
   equality this file asserts), and :49, the one conjunct L2 genuinely lacks,
   is unwitnessed at 0. The negative result is recorded in
   state_predicates.ml{,i}; what this file keeps is its EVIDENCE, in the B4
   case, which is why the src probes outlived the member.

   A THIRD GROUP JOINED THEM WITH THE MAIN LOOP'S SCOPE RULING, AND IT IS NOT A
   ZERO. Upstream's :116-118 and :119-124 are EXCLUDED-WITH-A-PIN on a SCOPE
   ground, and the [scope_exclusion_pin] case below asserts the MEASURED
   REFUTATION that licensed the exclusion - set-equality failures 0 / 8 / 0 / 72
   with both containment directions, coherence failures 0 / 4 / 0 / 40 all of
   them the :122 key, [weakly_eq] disagreeing NOWHERE on any arm, and no premise
   state carrying two matching responses. Those are not vacuity pins; they are
   the evidence that stops an exclusion decaying into an omission, and every one
   of them is behind a positive control that says the probe really ran.

   Every OTHER assertion below is one of exactly three kinds:

   1. SEMANTIC - the leg is clean, [violated] is [None], the run is decisive,
      the replica explored the leg's own graph, a premise fires at all;
   2. AN INHERITED P13-P23 PIN, re-derived on the new leg. These are the
      pin-safety rows and they are the point of the phase's "no committed pin
      can move" claim: the P24 leg rides P23's [(seed, bound, budget, depth)]
      and graphs are FAMILY-BLIND ([Model_check.explore], model_check.mli:57-63,
      takes no invariant argument at all), so the state counts, the decoded
      counts, the parked counts and the ok-list-response counts must come back
      byte-identical. A move here is a phase-STOP, never a retune;
   3. A RELATION between two numbers the run itself computes. TWO of the three
      shapes here have teeth without naming a literal, because one side is read
      off the graph and a coordinated retune cannot satisfy them: a PARTITION
      summing to a population the GRAPH reports (drop a bucket and it goes
      short), and an IDENTITY between a test-side projection and the shipped
      member's own [interesting] (two routes, one number).
      THE THIRD SHAPE - the SIX PROBE-POPULATION SUBSET ORDERINGS - DOES NOT,
      and an earlier revision of this header sold all three alike, which was
      wrong about these six. They are [parked_with_pending <= parked],
      [delivery_window <= parked_with_pending] and [ok_resp_in_flight <=
      parked_with_pending] in [inherited_population]; [ok_resp_with_objs <=
      ok_resp_in_flight] and [ok_resp_owned <= ok_resp_in_flight] in the B3
      control; and [pending_in_flight <= parked_with_pending] in B4. In every
      one of them the narrower side is the wider side's OWN combinator with one
      further test conjoined ([parked] -> [parked_with_pending] ->
      [on_pending ...], p24_witness.ml:478-499, and [List.exists p l] implying
      [l <> []] for the two B3 rows), so the containment holds for EVERY
      implementation of either side and on EVERY graph, a moved one included.
      No mutation of the projections' bodies can redden them. They are kept as
      SHAPE checks - a probe pair wired end for end would red - and each is
      LABELLED "SHAPE (no teeth)" at its site. They are not evidence, and no
      verdict in this phase cites one.
      TWO OTHER [<=] ROWS ARE NOT IN THAT SET AND ARE NOT CLAIMED TO BE
      TOOTHLESS: the leg's [gate <= union] row on the fault legs compares a
      LEG-COMPUTED number with a test-side one across a module boundary, and
      B5's [coherence_key_absent <= set_eq_resp_extra] relates two separately
      computed refutation columns. Neither is a containment by construction.

   THE FIVE MEASUREMENTS ARE COMPUTED AND PRINTED; TWO GROUPS ARE ALSO
   ASSERTED. The dump block at the bottom of this file prints B1 (gate and
   per-member counts on all four graphs), B2 (the [reconcile_step] occupancy
   histogram), B3 ([owned_objs] non-emptiness over the ok-list-response
   population), B4 (the [rm.src = Controller (controller_id, cr_key)] positive
   control over the parked population, and the complement that CUT M2) and B5
   (the SCOPE-EXCLUSION refutation with its attribution). Stage B has RUN and
   read those rows. THREE of them became vacuity literals in {!P24_witness}'s
   MEASURED block - [after_delete_outdated_occupancy_everywhere], the :241
   exclusion pin, asserted by the step-histogram case below behind its own
   positive control; [ok_resp_some_unowned_obj_everywhere], the owner-reference
   filter's reject-path zero, asserted by the B3 control case behind ITS own
   positive controls; and [pending_src_not_controller_everywhere], the zero on
   which the M2 candidate was cut, asserted by the B4 case behind the histogram
   partition that de-tautologised it. B5 became the SCOPE-EXCLUSION pins,
   asserted in full by [scope_exclusion_pin]. Every OTHER number the dump prints
   - B1 in full, B3's [owned_objs] non-emptiness itself, B4's POSITIVE src
   column and the rest of its histogram - is consumed as disclosed prose in
   [State_predicates]'s interface and no test may assert it.
   Printing at TOP LEVEL rather than inside an Alcotest case is deliberate:
   Alcotest captures a case's stdout and shows it only on failure, so a number
   printed inside a passing case is a number nobody reads. The precedent is
   t_p4_enumerator.ml:176-186.

   ==== WHAT A RED MEANS HERE ==============================================

   Upstream uses these predicates as milestones in a DISCHARGED liveness proof,
   so a red is not "the environment misbehaved" but a FIDELITY DIVERGENCE in
   the port - the port's reconciler reached a local state, or parked on a
   request, that upstream's proof says it cannot - and it is a real finding.
   The P21/P23 epistemic reading carries over unchanged.

   THAT READING HOLDS ONLY WHERE UPSTREAM ASSERTS THE CONJUNCT OF EXECUTIONS
   THIS LEG EXPLORES, AND THE [legs] CASE IS GREEN BECAUSE OF AN EXCLUSION.
   With M3's two ETCD-CONSUMING conjuncts shipped on stage B's measured non-zero
   [owned_objs] fork, SPc and SPm were REFUTED: :116-118 failed at 8 / 72 states
   and :119-124 at 4 / 40, every :119-124 failure the :122 key-presence
   conjunct, with [weakly_eq]'s own comparison disagreeing at ZERO states on
   every graph and every arm - i.e. the cause was STALENESS of an in-flight
   response relative to etcd, from a writer landing between the response's
   formation and its observation (a crash-orphaned request on BLc, the pod
   monkey on BLm). Upstream's own comment at state_predicates.rs:116 scopes that
   coherence to steps "taken by other controllers satisfying rely conditions",
   this port has no rely-condition machinery, and BLc / BLm inject exactly those
   rely-violating writers. The main loop has therefore EXCLUDED both conjuncts
   on a SCOPE ground.

   THE ASSERTION BELOW WAS NEVER RELAXED AND M3's PREMISE WAS NEVER NARROWED -
   either would have been the retune this project forbids. What changed is the
   CONJUNCTION: M3 ships its seven pure-shape conjuncts. The refutation itself is
   PINNED in [scope_exclusion_pin], which is the only thing that keeps this
   green honest: a reader can see exactly what was excluded, on which graphs, by
   how much, in which direction, and that [weakly_eq] was never the cause.

   ==== PER-MEMBER ATTRIBUTION COMES FROM A REPLICA, NEVER FROM THE LEG =====

   [Invariants.first_violated] (invariants.ml:1046) is FIRST-IN-LIST-ORDER, so a
   leg-level [violated] names the EARLIEST member that fails and says nothing
   about the rest. With the family at two members whose premises are disjoint in
   the step dimension (M1 is silent at [AfterListPod], M3 fires only there) the
   name happens to be unambiguous today - but that is a property of the current
   partition, not of the mechanism, and it was NOT true while the cut M2 shared
   M3's premise. Every per-member count below is therefore still computed
   test-side over a local replica of the leg's product graph (the
   t_p21_guarantee.ml:193-237 technique), with the replica's [Mc.states_seen]
   asserted equal to the leg's own [states] BEFORE any count is read.

   ==== THE PROJECTIONS LIVE IN {!P24_witness}, NOT HERE ====================

   {!Anvil_assurance.State_predicates} exports exactly two vals
   ([predicate_sources], [predicate_family]), so the lookup / decode /
   list-response projections a COUNTER needs are not callable, and re-exporting
   them to make a test easier would widen a shipped surface for a test's
   convenience. They are duplicated ONCE, in {!P24_witness} tier 3, with their
   origins cited - the duplicate-and-pin house precedent
   (internal_guarantee.ml:131-136). Duplicating them a second time in each of
   the three P24 exes would let B1-B4 mean different things in different files.
   Where the duplication is load-bearing it is PINNED below by the test-side
   projection agreeing with the shipped member's own [interesting].

   TEST-ORDERING RULE (P12 finding 1, P13-P23 precedent): every test asserts
   the SEMANTIC facts FIRST - outcome, [violated], decisive, replica
   faithfulness, floors - and only THEN the exact inherited pins.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum (both [Mc.outcome] arms; the
   seventeen reconcile steps and the response constructors live in
   {!P24_witness}), no two-arm match on [option]/[result], total accessors
   only, no indexing, no exceptions, Alcotest as the sanctioned failure
   primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Sp = Anvil_assurance.State_predicates
module W = P24_witness

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = W.witness_desired
let ordinals : int list = W.p24_ordinals
let depth : int = W.witness_depth
let bound : Bound.t = W.p24_bound ~desireds:[ desired ]
let cr : V_stateful_set.t = Scenario.vsts ~desired ()
let family : Invariants.invariant list = Sp.predicate_family ~cr ~controller_id
let cr_key : Common.object_ref = W.cr_key_of cr

(* The CR's controller owner reference. It is an [option]
   (v_stateful_set.mli:42) and probe B3's whole verdict turns on it being
   [Some]: a [None] makes every owner-ref filter empty and reports a vacuous
   ZERO that is indistinguishable from the EXCLUDE fork. Asserted as a POSITIVE
   CONTROL before any owned count is read. *)
let owner_ref : Owner_reference.t option = V_stateful_set.controller_owner_ref cr

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) -------- *)

let decisive (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let is_clean (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

(* [Mc.Refuted] carries no [states] field (model_check.mli:39); [-1] is the
   shipped sentinel. Every leg below is expected clean, so the sentinel
   surfacing in a pin assertion is itself a loud diagnosis. *)
let states_of (r : Fc.fault_report) : int =
  match r.outcome with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let gate_of (r : Fc.fault_report) : int =
  Option.value r.gate_states ~default:(-1)

let violated_name (r : Fc.fault_report) : string =
  Option.fold r.violated ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ==== the leg runs (lazy: no test pays for an unused exploration) ========= *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget)
    ~(require_fault : bool) : Fc.fault_report =
  Fc.check_state_predicates_under_faults ~depth ~req_drop ~pod_monkey bound
    budget ~desired ~ordinals ~require_fault

let sp0 : Fc.fault_report Lazy.t =
  lazy (leg ~req_drop:false ~pod_monkey:false W.zero_budget ~require_fault:false)

let spc : Fc.fault_report Lazy.t =
  lazy (leg ~req_drop:false ~pod_monkey:false W.spc_budget ~require_fault:true)

let spd : Fc.fault_report Lazy.t =
  lazy (leg ~req_drop:true ~pod_monkey:false W.spd_budget ~require_fault:true)

let spm : Fc.fault_report Lazy.t =
  lazy (leg ~req_drop:false ~pod_monkey:true W.spm_budget ~require_fault:true)

(* ==== LOCAL replicas of the legs' product graphs ===========================
   Same seed / bound / budget / depth through the exported
   {!Fc.faulted_successors}; every consuming test asserts [Mc.states_seen]
   against the leg's own [states] FIRST (the P13 M3/M5 precedent - a drifted
   replica would silently measure a DIFFERENT graph and every count below it
   would be a number about nothing). *)

let seed_of ~(req_drop : bool) ~(pod_monkey : bool) : Cluster.cluster_state =
  Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true ~req_drop
    ~pod_monkey ()

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget) :
    Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed_of ~req_drop ~pod_monkey) ]

let sp0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false W.zero_budget)

let spc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false W.spc_budget)

let spd_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:true ~pod_monkey:false W.spd_budget)

let spm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:true W.spm_budget)

(* ==== the INHERITED P13-P21 graphs, re-explored for pin safety =============
   Their own bound and their own seed builder (no [~ordinals]) - the P21 leg's
   inputs exactly, read through the chain rather than re-typed. This phase
   edits none of them; the case exists so the family-blindness ARGUMENT is
   measured rather than trusted. *)

let inherited_bound : Bound.t = P21_witness.p21_bound ~desireds:[ desired ]

let inherited_reach ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors inherited_bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:
      [
        Fc.faulted_of_seed
          (Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey
             ~vct ());
      ]

(* ---- counting projections over a replica --------------------------------- *)

let count (reach : Fc.faulted Mc.reachable)
    (p : Cluster.cluster_state -> bool) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) -> p f.cs)

let fires (reach : Fc.faulted Mc.reachable) (name : string) : int =
  count reach (W.member_interesting family name)

let reds (reach : Fc.faulted Mc.reachable) (name : string) : int =
  count reach (fun (s : Cluster.cluster_state) ->
      not (W.member_holds family name s))

(* the probes of {!P24_witness} tier 3, instantiated at THIS leg's coordinates
   once, so no row can accidentally probe a different controller or key *)
let decoded : Cluster.cluster_state -> bool = W.decoded ~controller_id ~cr_key

let decode_failed : Cluster.cluster_state -> bool =
  W.decode_failed ~controller_id ~cr_key

let has_reconcile : Cluster.cluster_state -> bool =
  W.has_reconcile ~controller_id ~cr_key

let parked : Cluster.cluster_state -> bool = W.parked ~controller_id ~cr_key

let parked_with_pending : Cluster.cluster_state -> bool =
  W.parked_with_pending ~controller_id ~cr_key

let delivery_window : Cluster.cluster_state -> bool =
  W.delivery_window ~controller_id ~cr_key

let ok_resp_in_flight : Cluster.cluster_state -> bool =
  W.ok_resp_in_flight ~controller_id ~cr_key

let ok_resp_with_objs : Cluster.cluster_state -> bool =
  W.ok_resp_with_objs ~controller_id ~cr_key

let ok_resp_owned : Cluster.cluster_state -> bool =
  W.ok_resp_with_owned_objs ~controller_id ~cr_key ~owner_ref

let ok_resp_unowned_only : Cluster.cluster_state -> bool =
  W.ok_resp_with_unowned_objs_only ~controller_id ~cr_key ~owner_ref

let ok_resp_no_objs : Cluster.cluster_state -> bool =
  W.ok_resp_with_no_objs ~controller_id ~cr_key

let ok_resp_some_unowned_obj : Cluster.cluster_state -> bool =
  W.ok_resp_with_some_unowned_obj ~controller_id ~cr_key ~owner_ref

let src_is_controller : Cluster.cluster_state -> bool =
  W.pending_src_is_controller ~controller_id ~cr_key

let src_is_not_controller : Cluster.cluster_state -> bool =
  W.pending_src_is_not_controller ~controller_id ~cr_key

let pending_in_flight : Cluster.cluster_state -> bool =
  W.pending_still_in_flight ~controller_id ~cr_key

let pvcs_non_empty (s : Cluster.cluster_state) : bool =
  W.at_orc ~controller_id ~cr_key
    (fun _ (st : V_stateful_set_reconciler.s) _ ->
      not (st.V_stateful_set_reconciler.pvcs = []))
    s

(* ---- probe B5, the SCOPE-EXCLUSION refutation, at this leg's coordinates ---
   The CR's namespace is read off [cr_key] rather than re-derived, so the etcd
   side of upstream's [valid_owned_object_filter] and the member's own premise
   cannot disagree about which namespace they are talking about. *)

let cr_namespace : string = cr_key.Common.namespace

let set_eq_fails : Cluster.cluster_state -> bool =
  W.set_equality_fails ~controller_id ~cr_key ~namespace:cr_namespace ~owner_ref

let set_eq_etcd_extra : Cluster.cluster_state -> bool =
  W.set_equality_etcd_extra ~controller_id ~cr_key ~namespace:cr_namespace
    ~owner_ref

let set_eq_resp_extra : Cluster.cluster_state -> bool =
  W.set_equality_resp_extra ~controller_id ~cr_key ~namespace:cr_namespace
    ~owner_ref

let set_eq_comparable : Cluster.cluster_state -> bool =
  W.set_equality_comparable ~controller_id ~cr_key ~namespace:cr_namespace
    ~owner_ref

let coherence_fails : Cluster.cluster_state -> bool =
  W.coherence_fails ~controller_id ~cr_key ~owner_ref

let coherence_key_absent : Cluster.cluster_state -> bool =
  W.coherence_key_absent ~controller_id ~cr_key ~owner_ref

let weakly_eq_metadata_ne : Cluster.cluster_state -> bool =
  W.weakly_eq_metadata_disagrees ~controller_id ~cr_key ~owner_ref

let weakly_eq_kind_ne : Cluster.cluster_state -> bool =
  W.weakly_eq_kind_disagrees ~controller_id ~cr_key ~owner_ref

let weakly_eq_spec_ne : Cluster.cluster_state -> bool =
  W.weakly_eq_spec_disagrees ~controller_id ~cr_key ~owner_ref

let weakly_eq_ran : Cluster.cluster_state -> bool =
  W.weakly_eq_ran ~controller_id ~cr_key ~owner_ref

let histogram (reach : Fc.faulted Mc.reachable) : (string * int) list =
  W.step_occupancy ~count:(count reach) ~controller_id ~cr_key

let src_histogram (reach : Fc.faulted Mc.reachable) : (string * int) list =
  W.pending_src_occupancy ~count:(count reach) ~controller_id ~cr_key

let multiplicity_histogram (reach : Fc.faulted Mc.reachable) :
    (string * int) list =
  W.ok_resp_multiplicity_occupancy ~count:(count reach) ~controller_id ~cr_key

(* the four rows, in matrix order (zero budget FIRST - the MG5 lesson) *)
let rows :
    (string * Fc.fault_report Lazy.t * Fc.faulted Mc.reachable Lazy.t * int)
    list =
  [
    ("SP0", sp0, sp0_reach, W.sp0_states);
    ("SPc", spc, spc_reach, W.spc_states);
    ("SPd", spd, spd_reach, W.spd_states);
    ("SPm", spm, spm_reach, W.spm_states);
  ]

(* ==== THE HISTOGRAM COLUMN LABELS, TYPED INDEPENDENTLY OF THE HISTOGRAM =====
   [P24_witness.step_occupancy] is [List.map _ all_steps],
   [pending_src_occupancy] is [List.map _ all_src_labels] and
   [ok_resp_multiplicity_occupancy] is [List.map _ all_multiplicity_labels], so
   a row reading

     check int "one column per step" (List.length W.all_steps) (List.length hist)

   is [n = n]: it holds for EVERY implementation, and in particular it cannot
   see a column DROPPED from the enumeration, which is the one failure the row
   claims to guard. THE PAIRED SUM ROW DOES NOT CLOSE THE HOLE EITHER - a
   dropped ZERO-occupancy column leaves the sum unchanged, and five of the
   seventeen step columns ([Get_pvc], [After_get_pvc], [Create_pvc],
   [After_create_pvc], [Skip_pvc], all PVC-step dead under [vct:false]) and five
   of the six src buckets measure zero on all four graphs. Between them the two
   rows guarded nothing at all for those ten columns.

   The three label lists are therefore typed HERE, once, read off
   {!V_stateful_set_reconciler.step} (v_stateful_set_reconciler.mli:14-31),
   {!Message.host_id} (message.mli:37-45) and the three multiplicity classes,
   and the histograms' OWN labels are asserted against them IN ORDER. Dropping a
   column now reddens whatever its occupancy, and an ADDED constructor is caught
   one level earlier still: [P24_witness.step_label] and [src_label] are
   exhaustive wildcard-free matches, so a new arm is a BUILD error there before
   it can be a silent omission here. *)

let expected_step_labels : string list =
  [
    "Init";
    "After_list_pod";
    "Get_pvc";
    "After_get_pvc";
    "Create_pvc";
    "After_create_pvc";
    "Skip_pvc";
    "Create_needed";
    "After_create_needed";
    "Update_needed";
    "After_update_needed";
    "Delete_condemned";
    "After_delete_condemned";
    "Delete_outdated";
    "After_delete_outdated";
    "Done";
    "Error";
  ]

let expected_src_labels : string list =
  [
    "Controller_this";
    "Controller_other";
    "Api_server";
    "Builtin_controller";
    "External";
    "Pod_monkey";
  ]

let expected_multiplicity_labels : string list = [ "0"; "1"; "2+" ]
let labels_of (hist : (string * int) list) : string list = List.map fst hist

(* ==== AN ACCUMULATING CHECKER, SO NO ROW CAN BE SHADOWED ===================
   [Alcotest.check] aborts the case at the FIRST failing row. A case built as a
   SEQUENCE of them therefore stops measuring exactly when something is wrong:
   every row below the first red goes unobserved, and a gate that only works
   while everything passes is not a gate. That is precisely what happened to
   [check_leg] - a refuted leg killed the case at the [is_clean] row and the P23
   GRAPH PIN, the three non-vacuity premise floors, the per-member red counts
   and the gate/interesting-union coupling were all dead for that leg, in the
   one situation they exist for.

   So each row RECORDS its verdict as a (possibly empty) list of failure
   descriptions, the case concatenates them, and ONE assertion at the end
   compares the whole list against [[]]. Every row is then observed on every
   run, a red names EVERY failing row at once, and the TEST-ORDERING RULE above
   keeps its meaning: order now decides the order failures are REPORTED in, not
   which of them are measured.

   AND IT IS THE SHAPE OF EVERY CASE IN THIS FILE, not of [check_leg] alone.
   Treating it as a [check_leg] repair was the same defect one level up: the
   argument for it is about a SEQUENCE of independent facts, and eight other
   cases here were still sequences. In particular [pin_safety] asserts the five
   INHERITED graph literals in a row, so under the old shape a single moved pin
   left the other four UNMEASURED - the phase's pin-safety claim was carried by
   whichever pin happened to move first. Every case whose body states more than
   one independent fact now ends in exactly one {!report}; the four-leg helpers
   ([check_population], [check_scope_pin]) RETURN their rows so the case that
   calls them four times still reports once, across all four graphs. *)

let row_bool (label : string) ~(actual : bool) : string list =
  if actual then [] else [ label ^ " -- expected true, got false" ]

let row_int (label : string) ~(expected : int) ~(actual : int) : string list =
  if Int.equal expected actual then []
  else [ Printf.sprintf "%s -- expected %d, got %d" label expected actual ]

let row_string (label : string) ~(expected : string) ~(actual : string) :
    string list =
  if String.equal expected actual then []
  else [ Printf.sprintf "%s -- expected %s, got %s" label expected actual ]

let row_list_string (label : string) ~(expected : string list)
    ~(actual : string list) : string list =
  if List.equal String.equal expected actual then []
  else
    [
      Printf.sprintf "%s -- expected [%s], got [%s]" label
        (String.concat "; " expected)
        (String.concat "; " actual);
    ]

(* [Option.fold]'s [~none:] is EAGER, so both arms here are constants/closures
   over already-computed values - never a recursive call. *)
let show_opt_int (o : int option) : string =
  Option.fold o ~none:"<none>" ~some:string_of_int

let row_opt_int (label : string) ~(expected : int option) ~(actual : int option)
    : string list =
  if Option.equal Int.equal expected actual then []
  else
    [
      Printf.sprintf "%s -- expected %s, got %s" label (show_opt_int expected)
        (show_opt_int actual);
    ]

let report (label : string) (failures : string list) : unit =
  Alcotest.(check (list string))
    (label
   ^ ": EVERY row of this case is observed on EVERY run - this list is empty, \
      or it names every failing row at once (accumulate-then-assert: no row can \
      be shadowed by an earlier one aborting the case)")
    [] failures

(* ==== family shape ========================================================= *)

let test_family_shape () =
  report "family_shape"
    (List.concat
       [
         row_list_string
           "predicate_family = the two upstream names, in member order M1, M3 \
            (the M2 candidate is CUT - see the negative result in \
            state_predicates.mli)"
           ~expected:W.member_names
           ~actual:
             (List.map
                (fun (i : Invariants.invariant) -> i.Invariants.name)
                family);
         row_list_string
           "member sources = predicate_sources, same order (the .mli's exposed \
            literals)"
           ~expected:Sp.predicate_sources
           ~actual:
             (List.map
                (fun (i : Invariants.invariant) -> i.Invariants.source)
                family);
         row_int "predicate_family cardinal = 2"
           ~expected:W.predicate_cardinal ~actual:(List.length family);
         row_list_string
           "the CUT member's name appears NOWHERE in the shipped family - a \
            member removed from the source list but left in the record list \
            would still be asserted by the leg while being invisible to the \
            roster sweep"
           ~expected:[]
           ~actual:
             (List.filter
                (String.equal "vsts_pending_list_pod_req_in_flight")
                (List.map
                   (fun (i : Invariants.invariant) -> i.Invariants.name)
                   family));
         row_int
           "the leg labels and the member names are the shapes every printed \
            row is keyed on"
           ~expected:4 ~actual:(List.length W.leg_labels);
       ])

(* ==== PIN SAFETY: the five INHERITED P13-P21 graphs, re-EXPLORED =========== *)

let test_pin_safety () =
  (* P22's and P23's four graphs are re-asserted inside the leg rows below
     (SP0/SPc/SPd/SPm reuse them exactly). This case covers the OTHER five,
     including the [vct:true] L0v graph no P24 leg runs. A moved pin is a
     STOP, never a retune. *)
  report "pin_safety"
    (List.concat
       [
         row_int "pin safety L0 = 76" ~expected:W.l0_states
           ~actual:
             (Mc.states_seen
                (inherited_reach ~req_drop:false ~pod_monkey:false ~vct:false
                   P21_witness.zero_budget));
         row_int "pin safety Lc = 464" ~expected:W.lc_states
           ~actual:
             (Mc.states_seen
                (inherited_reach ~req_drop:false ~pod_monkey:false ~vct:false
                   P21_witness.lc_budget));
         row_int "pin safety Ld = 744" ~expected:W.ld_states
           ~actual:
             (Mc.states_seen
                (inherited_reach ~req_drop:true ~pod_monkey:false ~vct:false
                   P21_witness.ld_budget));
         row_int "pin safety Lm = 1976" ~expected:W.lm_states
           ~actual:
             (Mc.states_seen
                (inherited_reach ~req_drop:false ~pod_monkey:true ~vct:false
                   P21_witness.lm_budget));
         row_int "pin safety L0v = 116 (vct:true, replica only)"
           ~expected:W.l0v_states
           ~actual:
             (Mc.states_seen
                (inherited_reach ~req_drop:false ~pod_monkey:false ~vct:true
                   P21_witness.zero_budget));
       ])

(* ==== the four legs ========================================================
   SEMANTIC facts, the INHERITED graph pin, and the NON-VACUITY floors. No P24
   number is asserted HERE: the gate and the per-member counts are PRINTED by
   the dump block below and stayed PROSE - stage B pinned only the two zeroes
   named in this file's header, and neither of them is in this case. *)

let check_leg (label : string) (r : Fc.fault_report)
    (reach : Fc.faulted Mc.reachable) ~(states : int) ~(require_fault : bool) :
    unit =
  (* THE GATE's comparand, computed up front. On the zero-budget leg
     [~require_fault:false], so the leg's gate closure is exactly the union of
     the two members' [interesting]; on the fault legs it is that union
     INTERSECTED with "a fault was taken", hence a subset. Coupled to the
     replica WITHOUT a literal either way. *)
  let union =
    count reach (fun (s : Cluster.cluster_state) ->
        List.exists
          (fun (name : string) -> W.member_interesting family name s)
          W.member_names)
  in
  report label
    (List.concat
       [
         (* SEMANTIC first - the TEST-ORDERING RULE, which now governs the order
            failures are REPORTED in and no longer decides which rows run. *)
         row_bool
           (label
          ^ ": outcome CLEAN - the state predicates HELD (a red here is a \
             FIDELITY divergence in the port: upstream uses these as milestones \
             in a DISCHARGED liveness proof)")
           ~actual:(is_clean r);
         row_string (label ^ ": violated = None") ~expected:"<none>"
           ~actual:(violated_name r);
         row_bool (label ^ ": decisive") ~actual:(decisive r);
         row_int
           (label ^ ": replica explored the leg's exact graph (states_seen)")
           ~expected:(states_of r) ~actual:(Mc.states_seen reach);
         (* NON-VACUITY FLOORS, one per member. A phase whose new register fired
            nowhere would be a green about nothing. THESE ARE THE ROWS THE OLD
            SEQUENCING KILLED FIRST: a refuted leg aborted the case one row
            above them. There are TWO of them because the family has two
            members; the third floor went with the CUT M2, and its population -
            the delivery window - is still measured, in [check_population] and
            in the B4 case, as the cut's evidence rather than as a member's
            premise. *)
         row_bool
           (label
          ^ ": family gate > 0 - the NON-VACUITY FLOOR; a zero here means the \
             leg asserted a family that never fired")
           ~actual:(gate_of r > 0);
         row_bool
           (label
          ^ ": M1 premise fires (the reconcile is at one of the FOURTEEN steps \
             at which upstream ever asserts local_state_is_valid)")
           ~actual:(fires reach W.m1_name > 0);
         row_bool
           (label
          ^ ": M3 premise fires - a matching ok List_response really is in \
             flight (P23 measured this population at 8 / 60 / 48 / 816)")
           ~actual:(fires reach W.m3_name > 0);
         (* per-member reds are ENTAILED by the clean outcome above (the leg
            asserts the conjunction over the same graph the replica explored),
            so these are a cross-check on the replica, not a new measurement -
            and when the leg is NOT clean they are the ATTRIBUTION, which is
            exactly when the old sequencing made them unobservable. *)
         List.concat_map
           (fun (name : string) ->
             row_int
               (label ^ ": " ^ name
              ^ " red = 0 on the replica, which the CLEAN outcome entails - a \
                 disagreement means the replica is not the leg's graph")
               ~expected:0 ~actual:(reds reach name))
           W.member_names;
         (* THE INHERITED GRAPH PIN, re-measured. Graphs are FAMILY-BLIND, so a
            move here is a phase-STOP - which is why it may never again sit
            downstream of a row that can abort the case. *)
         row_int
           (label
          ^ ": graph states = P23's committed pin, re-measured under a \
             DIFFERENT asserted family - this is prediction P1 and the whole \
             basis of the no-committed-pin-can-move claim")
           ~expected:states ~actual:(states_of r);
         (if require_fault then
            row_bool
              (label
             ^ ": the leg's gate is a SUBSET of the two members' \
                interesting-union (it is intersected with 'a fault was taken')")
              ~actual:(gate_of r <= union)
          else
            row_int
              (label
             ^ ": the leg's gate IS the two members' interesting-union - the \
                ONE coupling with teeth between the leg's family binding and \
                this suite, asserted without naming a number. It is also what \
                would redden if the CUT M2 were quietly re-added to the leg's \
                family without being re-added here")
              ~expected:union ~actual:(gate_of r));
       ])

let test_sp0 () =
  check_leg "SP0" (Lazy.force sp0) (Lazy.force sp0_reach) ~states:W.sp0_states
    ~require_fault:false

let test_spc () =
  check_leg "SPc" (Lazy.force spc) (Lazy.force spc_reach) ~states:W.spc_states
    ~require_fault:true

let test_spd () =
  check_leg "SPd" (Lazy.force spd) (Lazy.force spd_reach) ~states:W.spd_states
    ~require_fault:true

let test_spm () =
  check_leg "SPm" (Lazy.force spm) (Lazy.force spm_reach) ~states:W.spm_states
    ~require_fault:true

(* ==== the INHERITED premise-side population, re-derived on the P24 leg =====
   Every count in this case is a P23-MEASURED pin, re-derived through THIS
   phase's own probes. That is what makes "the P24 leg rides P23's graphs"
   a measurement rather than an argument: the graphs agree not only in SIZE
   but in the shape of the population each probe selects. *)

let check_population (label : string) (reach : Fc.faulted Mc.reachable)
    ~(dec : int) ~(parked_n : int) ~(ok_resps : int) : string list =
  List.concat
    [
      (* SEMANTIC first *)
      row_int
        (label
       ^ ": decode FAILURES = 0 (P23 prediction 4, inherited) - the \
          ~undecodable fold arm of State_predicates.at_reconcile is NEVER \
          exercised on a shipped graph, which is what makes the mutation \
          suite's unit-level decode row a control rather than a formality")
        ~expected:W.decode_failures_everywhere
        ~actual:(count reach decode_failed);
      row_int
        (label
       ^ ": every state whose reconcile EXISTS also DECODES (the same 0 read \
          from the other side)")
        ~expected:(count reach has_reconcile) ~actual:(count reach decoded);
      row_bool
        (label
       ^ ": the reconcile at the CR key is present somewhere (premise floor)")
        ~actual:(count reach has_reconcile > 0);
      (* THE PARKED CHAIN'S ORDERING - AND THESE THREE ROWS HAVE NO TEETH, which
         the file header now says instead of the opposite. Each narrower side is
         the wider one CONJOINED with a further test in the same combinator:
         [parked_with_pending] is [parked]'s [After_list_pod] plus
         [pending_req_msg] being [Some] (p24_witness.ml:478-488), and
         [delivery_window] and [ok_resp_in_flight] are both [on_pending] (:490-499),
         i.e. [parked_with_pending] plus one predicate on the pending request.
         So the containments hold for EVERY implementation of either side and on
         EVERY graph, a moved one included, and no mutation of the projections'
         BODIES can redden them. They are kept as SHAPE checks - a probe pair
         wired end for end would red - and they are labelled as that, not cited
         as evidence anywhere in this phase. *)
      row_bool
        (label
       ^ ": SHAPE (no teeth): parked-with-pending <= parked at After_list_pod")
        ~actual:(count reach parked_with_pending <= count reach parked);
      row_bool
        (label
       ^ ": SHAPE (no teeth): the delivery window <= parked-with-pending - it is \
          that population CONJOINED with 'no matching response yet', so this is \
          structural, never measured")
        ~actual:(count reach delivery_window <= count reach parked_with_pending);
      row_bool
        (label
       ^ ": SHAPE (no teeth): M3's ok-response premise <= parked-with-pending, \
          structural for the same reason")
        ~actual:(count reach ok_resp_in_flight <= count reach parked_with_pending);
  (* THE :65 ENTAILMENT, ASSERTED RATHER THAN NARRATED. This is one half of the
     negative result that CUT M2 (state_predicates.ml's NEGATIVE RESULT block):
     upstream :65 is [s.in_flight().contains(req_msg)], and the port's rendering
     premise was the DELIVERY WINDOW. The two populations are computed by
     genuinely different routes - [Message.Pool.mem] against the network on one
     side, "no matching response is in flight" on the other - and they agree
     graph for graph. Equal populations is what "entailed" MEANS here: there is
     no reachable state in that premise at which :65 is false, so it could never
     have been coverage. Asserted WITHOUT a literal, so it is a relation the run
     computes on both sides and a coordinated retune cannot satisfy it. *)
      row_int
        (label
       ^ ": upstream :65 is ENTAILED - the raw-in-flight population EQUALS the \
          delivery window, by two independent routes. This is the measurement \
          that struck the M2b' mutant and then formed half of the finding that \
          CUT M2")
        ~expected:(count reach delivery_window)
        ~actual:(count reach pending_in_flight);
      row_int
        (label
       ^ ": M3's own interesting = the test-side ok-List-response projection")
        ~expected:(count reach ok_resp_in_flight)
        ~actual:(fires reach W.m3_name);
      (* THE INHERITED PINS, last *)
      row_int
        (label ^ ": decoded ongoing states = P23's pin")
        ~expected:dec ~actual:(count reach decoded);
      row_int
        (label ^ ": states at After_list_pod = P23's parked pin")
        ~expected:parked_n ~actual:(count reach parked);
      row_int
        (label
       ^ ": states with a matching ok List_response in flight = P23's pin (M3's \
          premise population, 8 / 60 / 48 / 816)")
        ~expected:ok_resps ~actual:(count reach ok_resp_in_flight);
    ]

let test_population () =
  report "inherited_population"
    (List.concat
       [
         check_population "SP0" (Lazy.force sp0_reach) ~dec:W.decoded_bl0
           ~parked_n:W.parked_bl0 ~ok_resps:W.ok_list_resps_bl0;
         check_population "SPc" (Lazy.force spc_reach) ~dec:W.decoded_blc
           ~parked_n:W.parked_blc ~ok_resps:W.ok_list_resps_blc;
         check_population "SPd" (Lazy.force spd_reach) ~dec:W.decoded_bld
           ~parked_n:W.parked_bld ~ok_resps:W.ok_list_resps_bld;
         check_population "SPm" (Lazy.force spm_reach) ~dec:W.decoded_blm
           ~parked_n:W.parked_blm ~ok_resps:W.ok_list_resps_blm;
       ])

(* ==== M1's SEVEN PVC-PINNED CONJUNCTS, and the ONE pin they all die on =====
   RULING section 1: :197 :198 :199 :215-221 :223-228 :233 :244 (with the :193
   [pvc_cnt] binding they all read) are [pvc_cnt] / PVC-step dead under
   [vct:false]. Seven separate conjuncts of ONE upstream predicate collapsing
   onto ONE pin is the phase's largest SINGLE-PIN exclusion, so the pin is
   asserted on P24's OWN legs rather than cited from P23's. Its RED CAPABILITY
   is measured next door in t_p24_mutation (a throwaway [vct:true] replica),
   because a pin never SEEN to redden is not evidence.

   :246 is PVC-FAMILY but is NOT one of the seven: it is excluded on the
   REACHABILITY ground it shares with :241, so retiring this pin brings SEVEN
   conjuncts back into scope and not eight. The phase's other two exclusions
   (M3's :116-118 and :119-124) rest on a THIRD ground entirely and are pinned
   in [scope_exclusion_pin]. *)

let test_pvc_exclusion_pin () =
  report "pvc_exclusion_pin"
    (List.concat_map
       (fun ((label, _, reach, _) :
              string
              * Fc.fault_report Lazy.t
              * Fc.faulted Mc.reachable Lazy.t
              * int) ->
         let r = Lazy.force reach in
         List.concat
           [
             row_bool
               (label
              ^ ": the pin is not vacuous for want of decoded states (decoded \
                 > 0)")
               ~actual:(count r decoded > 0);
             row_int
               (label
              ^ ": NO decoded ongoing state has a PVC - M1's SEVEN PVC-pinned \
                 conjuncts are behaviour-free; the moment a vct:true leg lands \
                 they all come back into scope together")
               ~expected:W.pvcs_non_empty_everywhere
               ~actual:(count r pvcs_non_empty);
           ])
       rows)

(* ==== the STEP HISTOGRAM's COVERAGE GUARD, and the :241 PIN (probe B2) =====
   Stage B has run, and ONE column of this histogram became a pin: upstream
   :241 moved to EXCLUDE-WITH-A-PIN because [After_delete_outdated] measured 0
   occupancy on all four graphs. Everything that guards that reading is
   asserted here, in this order:

   - the seventeen columns SUM to the decoded population, so a step dropped
     from [P24_witness.all_steps] makes the sum SHORT and reddens - which is
     the failure mode that would make the :241 zero wrong in the SAFE-LOOKING
     direction;
   - the fourteen VALID-step columns sum to M1's own [interesting], which is
     upstream's [at_vsts_step] premise - so the histogram and the shipped
     member agree about which steps are in M1's premise;
   - the [After_list_pod] column IS the parked count, which is M3's premise step
     (and was the CUT M2 candidate's too, which is why the delivery-window
     probes below still key on it);
   - the [Delete_outdated] column is NON-ZERO (the POSITIVE CONTROL for the
     pin: the pipeline is entered, so the zero one line later is a measured
     vacuity and not an unexplored region);
   - and only THEN the pin itself,
     [P24_witness.after_delete_outdated_occupancy_everywhere].

   All but the last are read off the graph on both sides. The last names the
   FIRST of the three stage-B vacuity literals this phase pins (the second is
   the owner-reference filter's reject-path zero, asserted in the B3 control
   case above; the third is B4's src complement, the zero the M2 candidate was
   cut on), and it is single-sourced in {!P24_witness}. *)

let test_step_histogram_is_total () =
  report "step_histogram"
    (List.concat_map
       (fun ((label, _, reach, _) :
              string
              * Fc.fault_report Lazy.t
              * Fc.faulted Mc.reachable Lazy.t
              * int) ->
         let r = Lazy.force reach in
         let hist = histogram r in
         List.concat
           [
             row_list_string
               (label
              ^ ": the histogram's COLUMNS ARE the seventeen reconcile steps, \
                 in order, against a list typed INDEPENDENTLY of all_steps - \
                 so a step dropped from the enumeration reddens HERE whatever \
                 its occupancy. The old row compared the histogram's length \
                 with the length of the list it is built from (n = n) and the \
                 sum row below cannot see a dropped ZERO column, so five \
                 PVC-dead columns were unguarded.")
               ~expected:expected_step_labels ~actual:(labels_of hist);
             row_int
               (label
              ^ ": the seventeen columns SUM to the decoded population - a step \
                 missing from all_steps would make this SHORT, which is the \
                 failure mode that would corrupt stage B's reading of :241")
               ~expected:(count r decoded) ~actual:(W.hist_total hist);
             row_int
               (label
              ^ ": the FOURTEEN valid-step columns sum to M1's own interesting \
                 - the histogram and the shipped member agree about upstream's \
                 at_vsts_step premise")
               ~expected:(fires r W.m1_name) ~actual:(W.valid_step_total hist);
             row_opt_int
               (label
              ^ ": the After_list_pod column IS the parked count (M3's premise \
                 step)")
               ~expected:(Some (count r parked))
               ~actual:(W.hist_lookup hist "After_list_pod");
             (* THE :241 EXCLUSION PIN and its POSITIVE CONTROL, control FIRST,
                so a zero that came from an unentered pipeline could never be
                read as a measured vacuity. *)
             row_bool
               (label
              ^ ": :241 CONTROL: the Delete_outdated column is NON-ZERO, so the \
                 outdated pipeline IS entered on this graph and the zero \
                 asserted next is a measured vacuity rather than an unexplored \
                 region")
               ~actual:
                 (Option.fold (W.hist_lookup hist "Delete_outdated")
                    ~none:false ~some:(fun (n : int) -> n > 0));
             row_opt_int
               (label
              ^ ": :241 PIN: After_delete_outdated occupancy is 0 - its guard \
                 never fires, so the conjunct is a green that could not have \
                 been red, and it is EXCLUDED-WITH-A-PIN on THESE graphs, never \
                 on P11's")
               ~expected:(Some W.after_delete_outdated_occupancy_everywhere)
               ~actual:(W.hist_lookup hist "After_delete_outdated");
           ])
       rows)

(* ==== probe B3's CONTROLS (the measurement itself is printed, not pinned) ==
   RULING section 3.3 gates M3's two etcd-consuming conjuncts on ONE question:
   is [owned_objs] ever non-empty on the ok-list-response population? The
   ANSWER is stage B's. What has to be true for either answer to MEAN
   anything is asserted here:

   1. the CR really has a controller owner reference. If it did not, every
      owner-ref filter would be empty and a vacuous ZERO would be
      indistinguishable from a measured EXCLUDE fork - a missed keyed lookup
      passing vacuously is this project's named failure mode;
   2. the population is non-empty and the responses carry OBJECTS at all, so
      the filter has something to reject;
   3. owned, unowned-only and no-objects PARTITION the population, summed
      against the count the GRAPH reports rather than against each other.

   THE PARTITION USED TO BE A TAUTOLOGY AND IS NOT ONE ANY MORE. It read
   [owned + (population && not owned) = population], which holds for ANY
   implementation of the positive projection - a constant one included - so it
   was a green that could not have been red. Both complements now come off the
   response objects by their own route ([P24_witness.ok_resp_with_unowned_objs_only]
   and [P24_witness.ok_resp_with_no_objs], neither of which mentions the
   positive projection), so making [ok_resp_with_owned_objs] constant now
   breaks the sum. SEEN RED by exactly that mutation, and the observation is
   recorded in the mutation ledger of BUILD-SPEC-P24.

   AND THE THIRD COLUMN IS WHY THE OLD PROBE WAS ALSO MIS-DESCRIBED. The
   old [unowned_only] reported 0 / 0 / 8 / 40; every one of those states is a
   state whose matching responses carry NO objects at all, i.e.
   [ok_resps - with_objs], not a state where the owner-ref filter rejected
   anything. The genuine reject path is
   [P24_witness.ok_resp_with_some_unowned_obj] and it is PINNED at zero below,
   as a finding rather than as a convenience. *)

let test_owned_objs_probe_controls () =
  report "owned_objs_probe_controls"
    (List.concat
       [
         row_bool
           "B3 control: the CR HAS a controller owner reference - without it \
            every owner-ref filter is empty and a vacuous zero would read \
            exactly like a measured EXCLUDE fork"
           ~actual:(Option.is_some owner_ref);
         List.concat_map
           (fun ((label, _, reach, _) :
                  string
                  * Fc.fault_report Lazy.t
                  * Fc.faulted Mc.reachable Lazy.t
                  * int) ->
             let r = Lazy.force reach in
             List.concat
               [
                 row_bool
                   (label
                  ^ ": B3 control: the ok-List-response population is \
                     NON-EMPTY, so the owner-ref filter has something to run on")
                   ~actual:(count r ok_resp_in_flight > 0);
                 (* THE TEETH IN THIS ROW ARE THE [> 0] HALF, and the row says so
                    rather than letting the reader credit the ordering: the
                    [<=] half is the structural containment the file header
                    lists (both sides are [on_pending] over the same
                    [ok_list_resps_for], and [List.exists] implies non-empty),
                    so it cannot redden. What is MEASURED is that the filter had
                    real objects to run on. *)
                 row_bool
                   (label
                  ^ ": B3 control: responses carrying OBJECTS are > 0 (THE \
                     MEASURED HALF - the filter is applied to real objects, not \
                     folded over an empty list) and <= the premise population \
                     (SHAPE, no teeth)")
                   ~actual:
                     (count r ok_resp_with_objs > 0
                     && count r ok_resp_with_objs <= count r ok_resp_in_flight);
                 row_bool
                   (label
                  ^ ": B3 control: SHAPE (no teeth): owned <= the premise \
                     population")
                   ~actual:(count r ok_resp_owned <= count r ok_resp_in_flight);
                 row_int
                   (label
                  ^ ": B3 control: carries-objects and carries-NO-objects \
                     PARTITION the premise population, each computed by its own \
                     traversal (exists non-empty vs for-all empty), summed \
                     against the GRAPH's own count")
                   ~expected:(count r ok_resp_in_flight)
                   ~actual:(count r ok_resp_with_objs + count r ok_resp_no_objs);
                 row_int
                   (label
                  ^ ": B3 control: owned + unowned-only + no-objects PARTITION \
                     the premise population, summed against the count the GRAPH \
                     reports - and NEITHER complement is the positive \
                     projection subtracted, so a constant owned-projection \
                     breaks this row")
                   ~expected:(count r ok_resp_in_flight)
                   ~actual:
                     (count r ok_resp_owned + count r ok_resp_unowned_only
                    + count r ok_resp_no_objs);
                 (* THE REJECT-PATH ORDERING, asserted BEFORE the zero it makes
                    readable: a state where EVERY object is unowned is in
                    particular a state where SOME object is unowned, so
                    unowned-only can never exceed the reject-path count. If the
                    pin below were 0 while this row were not, the two probes
                    would be measuring different populations. *)
                 row_bool
                   (label
                  ^ ": B3 control: unowned-only <= some-object-rejected \
                     (every-object unowned implies some-object unowned)")
                   ~actual:
                     (count r ok_resp_unowned_only
                     <= count r ok_resp_some_unowned_obj);
                 (* THE REJECT-PATH PIN. Stated as a FINDING: on this phase's
                    four graphs the owner-reference filter is never observed to
                    reject a single object. Its two positive controls are the
                    rows above - the CR really has a controller owner ref, and
                    the responses really carry objects - so this zero is "the
                    filter ran on real objects and accepted all of them", never
                    "the filter was never applied". *)
                 row_int
                   (label
                  ^ ": B3 PIN: the owner-ref filter REJECTS no object anywhere \
                     - no matching ok list-response on any P24 graph carries an \
                     object that fails owner_references_contains, so M3's :112 \
                     filter has no observed reject path and that is a measured \
                     finding, not a convenience")
                   ~expected:W.ok_resp_some_unowned_obj_everywhere
                   ~actual:(count r ok_resp_some_unowned_obj);
               ])
           rows;
       ])

(* ==== THE SCOPE-EXCLUSION PIN (probe B5) ==================================
   Upstream :116-118 and :119-124 are EXCLUDED-WITH-A-PIN on a SCOPE ground -
   this phase's THIRD exclusion ground, distinct from the PVC pin's SHAPE
   ground (seven M1 conjuncts) and from :241 / :246's REACHABILITY ground (two).
   Upstream's own comment at state_predicates.rs:116 reads, verbatim,
   "coherence with etcd which preserves across steps taken by other controllers
   satisfying rely conditions"; this port has no rely-condition machinery; and
   BLc / BLm inject by construction exactly the rely-violating writers that
   assumption excludes (a crash-orphaned request applied late; the pod monkey).
   Asserting those conjuncts there asserts upstream's predicate OUTSIDE ITS
   STATED SCOPE.

   THIS CASE IS WHY THE EXCLUSION IS NOT AN OMISSION. Every other exclusion in
   the phase pins a VACUITY; this one pins a MEASURED REFUTATION, so the
   numbers are ASSERTED here rather than left as prose in an interface. If a
   later revision quietly drops the exclusion's evidence, this case reddens.

   ORDER, and it is the house order: the CONTROLS that make a zero a MEASURED
   zero come first (the CR really has an owner reference, the premise
   population is non-empty, the set equality really compared two NON-EMPTY
   sides somewhere, [weakly_eq] really ran on a found etcd object, and no
   premise state carries two matching responses), then the RELATIONS the run
   computes on both sides, and only then the literals. *)

let check_scope_pin (label : string) (reach : Fc.faulted Mc.reachable)
    ~(set_eq : int) ~(etcd_extra : int) ~(resp_extra : int) ~(coherence : int)
    ~(key_absent : int) : string list =
  (* the multiplicity histogram: totality, then the positive bucket, then the
     pin. A premise state carrying TWO matching ok responses would make "the
     member is red" and "this response is stale" different claims. *)
  let mhist = multiplicity_histogram reach in
  List.concat
    [
      (* ---- CONTROLS ------------------------------------------------------ *)
      row_bool
        (label
       ^ ": B5 control: M3's premise population is NON-EMPTY, so the excluded \
          conjuncts had states to be evaluated at")
        ~actual:(count reach ok_resp_in_flight > 0);
      row_bool
        (label
       ^ ": B5 control: the SET EQUALITY compared two NON-EMPTY sides \
          somewhere - without this row a zero failure count could be an \
          empty-versus-empty comparison rather than a measured agreement")
        ~actual:(count reach set_eq_comparable > 0);
      row_bool
        (label
       ^ ": B5 control: weakly_eq really RAN - some owned response object was \
          looked up in etcd and FOUND, so the three arm zeroes below are \
          measured agreements and not an unexplored region")
        ~actual:(count reach weakly_eq_ran > 0);
      row_list_string
        (label
       ^ ": B5 control: the multiplicity histogram's BUCKETS ARE 0 / 1 / 2+, \
          in order, against a list typed INDEPENDENTLY of \
          all_multiplicity_labels. The old row was the same n = n form the step \
          and src rows carried; unlike those two it hid no live hole (the [2+] \
          bucket has its own lookup pin below, and [0] / [1] are non-zero \
          everywhere so the sum row sees them go), and it is restated in the \
          guarding form anyway rather than left as the one tautology of its \
          kind in the file")
        ~expected:expected_multiplicity_labels ~actual:(labels_of mhist);
      row_int
        (label
       ^ ": B5 control: the three multiplicity buckets SUM to the \
          parked-with-pending population - a dropped bucket would make this \
          SHORT instead of quietly reporting zero")
        ~expected:(count reach parked_with_pending)
        ~actual:(W.hist_total mhist);
      row_opt_int
        (label
       ^ ": B5 control: the EXACTLY-ONE bucket IS M3's premise population, so \
          the zero below is 'never two', not 'never any'")
        ~expected:(Some (count reach ok_resp_in_flight))
        ~actual:(W.hist_lookup mhist "1");
      row_opt_int
        (label
       ^ ": B5 PIN: NO premise state carries two matching ok List_responses, \
          so the per-state attribution below is not a \
          universal-versus-existential artifact")
        ~expected:(Some W.multi_matching_ok_resps_everywhere)
        ~actual:(W.hist_lookup mhist W.multi_resp_label);
      (* ---- RELATIONS, both sides read off the graph ---------------------- *)
      row_int
        (label
       ^ ": B5 relation: the two set-equality DIRECTIONS are DISJOINT - they \
          sum to the failure count, so no state fails both ways and each \
          direction's literal below is attributable on its own")
        ~expected:(count reach set_eq_fails)
        ~actual:(count reach set_eq_etcd_extra + count reach set_eq_resp_extra);
      row_bool
        (label
       ^ ": B5 relation: a missing key implies the response's owned ref is \
          absent from etcd's valid-owned set, so :122's population is \
          contained in the response-side direction")
        ~actual:
          (count reach coherence_key_absent <= count reach set_eq_resp_extra);
      row_int
        (label
       ^ ": B5 relation: EVERY :119-124 failure is the :122 KEY-PRESENCE \
          conjunct - the two columns are equal, so the :123 weakly_eq half \
          contributes nothing. This is the sharp form of the claim the \
          exclusion rests on.")
        ~expected:(count reach coherence_fails)
        ~actual:(count reach coherence_key_absent);
      (* ---- THE LITERALS -------------------------------------------------- *)
      row_int
        (label
       ^ ": B5 PIN :116-118: the owned-object-ref SET EQUALITY failure count \
          (EXCLUDED-WITH-A-PIN on the SCOPE ground - upstream scopes this \
          coherence to steps taken by other controllers satisfying RELY \
          CONDITIONS, and this port has none)")
        ~expected:set_eq ~actual:(count reach set_eq_fails);
      row_int
        (label
       ^ ": B5 PIN :116-118 direction ONE: etcd holds a valid-owned object the \
          response does NOT carry")
        ~expected:etcd_extra ~actual:(count reach set_eq_etcd_extra);
      row_int
        (label
       ^ ": B5 PIN :116-118 direction TWO: the response holds an owned object \
          etcd NO LONGER has")
        ~expected:resp_extra ~actual:(count reach set_eq_resp_extra);
      row_int
        (label
       ^ ": B5 PIN :119-124: the coherence forall's failure count (EXCLUDED on \
          the same SCOPE ground)")
        ~expected:coherence ~actual:(count reach coherence_fails);
      row_int
        (label
       ^ ": B5 PIN :122: the key-presence half of it, measured separately")
        ~expected:key_absent ~actual:(count reach coherence_key_absent);
      (* THE LOAD-BEARING ZEROES. These are what make the diagnosis "the
         in-flight response is STALE relative to etcd" instead of "weakly_eq is
         wrong", and they are pinned rather than narrated for exactly that
         reason. Their positive control is the weakly_eq-really-ran row above. *)
      row_int
        (label
       ^ ": B5 PIN: weakly_eq's METADATA arm (Object_meta.equal over \
          without_resource_version) disagrees at ZERO states - weakly_eq is \
          NOT the cause of the refutation")
        ~expected:W.weakly_eq_metadata_disagreements_everywhere
        ~actual:(count reach weakly_eq_metadata_ne);
      row_int
        (label ^ ": B5 PIN: weakly_eq's KIND arm disagrees at ZERO states")
        ~expected:W.weakly_eq_kind_disagreements_everywhere
        ~actual:(count reach weakly_eq_kind_ne);
      row_int
        (label
       ^ ": B5 PIN: weakly_eq's SPEC arm disagrees at ZERO states - the third \
          arm whose source mutant SURVIVED stage C, and this is the \
          measurement that says why")
        ~expected:W.weakly_eq_spec_disagreements_everywhere
        ~actual:(count reach weakly_eq_spec_ne);
    ]

let test_scope_exclusion_pin () =
  report "scope_exclusion_pin"
    (List.concat
       [
         row_bool
           "B5 control: the CR HAS a controller owner reference - a None would \
            empty every owned filter below and turn the whole refutation into \
            a vacuous zero"
           ~actual:(Option.is_some owner_ref);
         check_scope_pin "SP0" (Lazy.force sp0_reach)
           ~set_eq:W.set_equality_failures_sp0
           ~etcd_extra:W.set_equality_etcd_extra_sp0
           ~resp_extra:W.set_equality_resp_extra_sp0
           ~coherence:W.coherence_failures_sp0
           ~key_absent:W.coherence_key_absent_sp0;
         check_scope_pin "SPc" (Lazy.force spc_reach)
           ~set_eq:W.set_equality_failures_spc
           ~etcd_extra:W.set_equality_etcd_extra_spc
           ~resp_extra:W.set_equality_resp_extra_spc
           ~coherence:W.coherence_failures_spc
           ~key_absent:W.coherence_key_absent_spc;
         check_scope_pin "SPd" (Lazy.force spd_reach)
           ~set_eq:W.set_equality_failures_spd
           ~etcd_extra:W.set_equality_etcd_extra_spd
           ~resp_extra:W.set_equality_resp_extra_spd
           ~coherence:W.coherence_failures_spd
           ~key_absent:W.coherence_key_absent_spd;
         check_scope_pin "SPm" (Lazy.force spm_reach)
           ~set_eq:W.set_equality_failures_spm
           ~etcd_extra:W.set_equality_etcd_extra_spm
           ~resp_extra:W.set_equality_resp_extra_spm
           ~coherence:W.coherence_failures_spm
           ~key_absent:W.coherence_key_absent_spm;
         (* AND THE ROW THAT COUPLES THE PIN TO THE SHIPPED MEMBER. The
            refutation above is NON-ZERO on SPc and SPm while M3 as shipped is
            GREEN on every graph - because M3 no longer carries those two
            conjuncts. Asserting both in one case is what stops a reader
            concluding either that the refutation went away or that the leg's
            green covers it. *)
         List.concat_map
           (fun ((label, _, reach, _) :
                  string
                  * Fc.fault_report Lazy.t
                  * Fc.faulted Mc.reachable Lazy.t
                  * int) ->
             row_int
               (label
              ^ ": the SHIPPED M3 is red at ZERO states - it carries the SEVEN \
                 pure-shape conjuncts only, and the refutation pinned above \
                 belongs to the two conjuncts it no longer carries")
               ~expected:0
               ~actual:(reds (Lazy.force reach) W.m3_name))
           rows;
       ])

(* ==== probe B4: THE MEASUREMENT THAT CUT M2, AND ITS CONTROLS ==============
   THIS CASE OUTLIVED THE MEMBER IT WAS WRITTEN FOR. Upstream :49
   ([req_msg.src == Controller(controller_id, vsts_key)]) was the ONE conjunct
   of the seven the M2 candidate rendered that P23's L2 does not carry - its
   entire claimed new coverage, once :65 measured ENTAILED by the port's own
   rendering premise (the equality [check_population] asserts above). B4
   measured it, and the complement is ZERO on all four graphs over denominators
   16 / 112 / 288 / 1560. Upstream :49 is TRUE at every state at which it is
   ever evaluated - a GREEN THAT COULD NOT HAVE BEEN RED, the same defect
   condition that excluded :241, :246 and the eight PVC conjuncts - so the
   member bought nothing over L2 and the main loop CUT it. The full record is
   the NEGATIVE RESULT block in state_predicates.ml{,i}.

   THE ZERO IS NOW A PIN, and that is the one thing that changed here when M2
   went: [P24_witness.pending_src_not_controller_everywhere]. An exclusion whose
   evidence is not asserted decays, one revision at a time, into an omission,
   and a CUT MEMBER is the sharpest version of that risk - nothing else in the
   tree would notice if this measurement drifted.

   NO RED RATE WAS EVER PREDICTED FOR :49 AND NONE IS RECORDED. The
   "structurally always true, hence 100% of parked states" reading was REFUTED
   as unmeasured (verdict C6, adopted), and lib/cluster/message.ml:175-179 is
   plausibility-from-construction on the zero-budget graph, not a measurement
   across the fault graphs where adversarial actions exist. What is asserted
   below is a MEASUREMENT ON THESE FOUR GRAPHS, which is exactly what the cut
   rests on: it says :49 has no witness HERE, not that it could not have one.
   What would produce one - a pending request sourced anywhere but this
   controller - needs a new seed, and a new seed would move the shared graphs.

   THE PARTITION USED TO BE A TAUTOLOGY AND IS NOT ONE ANY MORE, WHICH IS WHY
   THE PIN CAN LEAN ON IT. The negative polarity read
   [parked_with_pending && not src_is_controller], so the sum held for ANY
   implementation of the positive projection, a constant one included. It is now
   read off a SRC HISTOGRAM ([P24_witness.pending_src_occupancy]) built by an
   exhaustive five-arm match on {!Message.host_id} with the [Controller] arm
   split by the [(id, key)] it carries - constructor match plus field equality,
   versus the positive projection's structural [Message.equal_host_id]. TWO rows
   have teeth: the six buckets SUM to the parked-with-pending population (a
   dropped bucket makes the sum short and it reddens - SEEN, by dropping
   [Builtin_controller]), and the [Controller_this] bucket AGREES with the
   positive projection (two routes, one number). Both were SEEN RED by making
   [pending_src_is_controller] constant, and the observations are recorded in the
   mutation ledger of BUILD-SPEC-P24.

   A THIRD ROW USED TO BE LISTED HERE AS HAVING TEETH AND DOES NOT HAVE THEM.
   "The other five buckets sum to the negative polarity" relates
   [P24_witness.src_other_total] (:595-599, the histogram total minus the
   [Controller_this] bucket) to [count src_is_not_controller] (:601-609), and
   BOTH sides are folds of the SAME [src_label] classification through the SAME
   [on_pending] combinator - the second is not a second route, it is the first
   one re-associated. On these four graphs it is additionally 0 = 0, because
   every one of the five buckets and the negative polarity itself measure ZERO
   (that zero IS the B4 pin). It is kept because it is the STRUCTURAL guarantee
   the de-tautologising rewrite bought - the negative polarity is READ OFF the
   histogram and never SUBTRACTED from the positive one - and it would acquire
   teeth the moment a graph witnessed a non-controller src. Until then it is
   labelled at its site as carrying no red capability. *)

let test_src_positive_control_partition () =
  report "src_positive_control_partition"
    (List.concat_map
       (fun ((label, _, reach, _) :
              string
              * Fc.fault_report Lazy.t
              * Fc.faulted Mc.reachable Lazy.t
              * int) ->
         let r = Lazy.force reach in
         let shist = src_histogram r in
         List.concat
           [
             row_bool
               (label
              ^ ": B4 control: the parked-with-pending population is NON-EMPTY")
               ~actual:(count r parked_with_pending > 0);
             (* THE PARTITION FIRST - it is the headline control, and the
                histogram rows below are the backstops that say WHY it is not an
                identity. *)
             row_int
               (label
              ^ ": B4 control: src-IS-controller and src-is-NOT-controller \
                 PARTITION the parked-with-pending population, summed against \
                 the count the GRAPH reports (so a coordinated retune cannot \
                 make the two agree with each other instead of with the states)")
               ~expected:(count r parked_with_pending)
               ~actual:
                 (count r src_is_controller + count r src_is_not_controller);
             row_list_string
               (label
              ^ ": B4 control: the src histogram's BUCKETS ARE the six host_id \
                 classifications, in order, against a list typed INDEPENDENTLY \
                 of all_src_labels - a bucket dropped from the enumeration \
                 reddens here whatever its occupancy, and five of the six \
                 measure zero on every graph, so the old length row (n = n) and \
                 the sum row below left them unguarded")
               ~expected:expected_src_labels ~actual:(labels_of shist);
             row_int
               (label
              ^ ": B4 control: the six src buckets SUM to the \
                 parked-with-pending population - a bucket dropped from \
                 all_src_labels would make this SHORT, which is the failure \
                 mode that would corrupt the split above")
               ~expected:(count r parked_with_pending)
               ~actual:(W.hist_total shist);
             row_opt_int
               (label
              ^ ": B4 control: the Controller_this bucket AGREES with the \
                 positive projection - two independent routes (constructor \
                 match plus field equality vs Message.equal_host_id) reporting \
                 ONE number, so a constant positive projection reddens here too")
               ~expected:(Some (count r src_is_controller))
               ~actual:(W.hist_lookup shist W.this_controller_src_label);
             row_int
               (label
              ^ ": B4 control: SHAPE (no teeth today): the OTHER five src \
                 buckets sum to src-is-NOT-controller. Both sides fold the SAME \
                 src_label classification through the same on_pending, so this \
                 is a re-association rather than a second route, and on these \
                 four graphs it is 0 = 0. It records that the negative polarity \
                 is READ OFF the histogram and never SUBTRACTED from the \
                 positive one, and it acquires teeth only on a graph that \
                 witnesses a non-controller src")
               ~expected:(count r src_is_not_controller)
               ~actual:(W.src_other_total shist);
             row_bool
               (label
              ^ ": B4 control: SHAPE (no teeth): the RAW-IN-FLIGHT population \
                 (upstream :65) is a subset of parked-with-pending - structural, \
                 since pending_still_in_flight is that population conjoined with \
                 a network-membership test. Its EQUALITY with the delivery \
                 window, which is what makes :65 entailed and which DOES have \
                 teeth, is asserted in inherited_population")
               ~actual:(count r pending_in_flight <= count r parked_with_pending);
             (* THE PIN, LAST, behind every control above. This is the number
                the M2 candidate was cut on, and it is the only B4 column that
                is a literal. *)
             row_int
               (label
              ^ ": B4 PIN: NOT ONE parked pending request is sourced anywhere \
                 but Controller (controller_id, cr_key), so upstream :49 is \
                 TRUE wherever it is evaluated - a green that could not have \
                 been red. This is the measurement the M2 candidate was CUT on \
                 (state_predicates.mli's NEGATIVE RESULT block); a non-zero \
                 here means a graph now WITNESSES :49 and the cut has to be \
                 revisited, not retuned")
               ~expected:W.pending_src_not_controller_everywhere
               ~actual:(count r src_is_not_controller);
           ])
       rows)

(* ==== THE STAGE-B MEASUREMENT DUMP ========================================
   Printed at TOP LEVEL, before [Alcotest.run], because Alcotest captures a
   case's stdout and shows it only on failure - a number printed inside a
   PASSING case is a number nobody reads (t_p4_enumerator.ml:176-186 is the
   precedent for printing here). NOTHING BELOW IS ASSERTED. Stage B reads
   these rows, writes them into {!P24_witness}'s MEASURED block, and only then
   may a test name a literal. *)

let dump_row (label : string) (r : Fc.fault_report)
    (reach : Fc.faulted Mc.reachable) : unit =
  Printf.printf "  %s  states=%d  gate=%d  M1_int=%d  M3_int=%d\n" label
    (states_of r) (gate_of r) (fires reach W.m1_name) (fires reach W.m3_name)

let dump_hist (label : string) (reach : Fc.faulted Mc.reachable) : unit =
  Printf.printf "  %s  reconcile_step occupancy (decoded=%d):\n" label
    (count reach decoded);
  List.iter
    (fun ((step, n) : string * int) ->
      Printf.printf "      %-24s %d\n" step n)
    (histogram reach)

let dump_owned (label : string) (reach : Fc.faulted Mc.reachable) : unit =
  Printf.printf
    "  %s  ok_resps=%d  with_objs=%d  with_OWNED_objs=%d  unowned_ONLY=%d  \
     no_objs=%d  some_obj_REJECTED=%d\n"
    label
    (count reach ok_resp_in_flight)
    (count reach ok_resp_with_objs)
    (count reach ok_resp_owned)
    (count reach ok_resp_unowned_only)
    (count reach ok_resp_no_objs)
    (count reach ok_resp_some_unowned_obj)

let dump_src (label : string) (reach : Fc.faulted Mc.reachable) : unit =
  Printf.printf
    "  %s  parked=%d  parked_with_pending=%d  src_IS_controller=%d  \
     src_NOT_controller=%d  raw_in_flight=%d  delivery_window=%d\n"
    label (count reach parked)
    (count reach parked_with_pending)
    (count reach src_is_controller)
    (count reach src_is_not_controller)
    (count reach pending_in_flight)
    (count reach delivery_window);
  List.iter
    (fun ((bucket, n) : string * int) ->
      Printf.printf "      src %-20s %d\n" bucket n)
    (src_histogram reach)

let dump_scope (label : string) (reach : Fc.faulted Mc.reachable) : unit =
  Printf.printf
    "  %s  premise=%d  comparable=%d  SETEQ_fail=%d (etcd_extra=%d \
     resp_extra=%d)  COH_fail=%d (key_absent=%d)  wq_ran=%d  wq_meta_ne=%d  \
     wq_kind_ne=%d  wq_spec_ne=%d\n"
    label
    (count reach ok_resp_in_flight)
    (count reach set_eq_comparable)
    (count reach set_eq_fails)
    (count reach set_eq_etcd_extra)
    (count reach set_eq_resp_extra)
    (count reach coherence_fails)
    (count reach coherence_key_absent)
    (count reach weakly_eq_ran)
    (count reach weakly_eq_metadata_ne)
    (count reach weakly_eq_kind_ne)
    (count reach weakly_eq_spec_ne);
  (* The SHIPPED M3's red count beside the EXCLUDED conjuncts' refutation. The
     first must be 0 on every graph (M3 ships the seven pure-shape conjuncts
     only); the second is the pinned refutation the exclusion rests on. Before
     the exclusion these two were measured EQUAL on all four graphs
     (0 / 8 / 0 / 72), which is what ATTRIBUTED the leg's red to these two
     conjuncts and nothing else. *)
  Printf.printf "      m3_red_SHIPPED=%d  excluded_conjunct_refutation=%d\n"
    (reds reach W.m3_name)
    (count reach (fun (s : Cluster.cluster_state) ->
         set_eq_fails s || coherence_fails s));
  List.iter
    (fun ((bucket, n) : string * int) ->
      Printf.printf "      matching_ok_resps %-4s %d\n" bucket n)
    (multiplicity_histogram reach)

let () =
  Printf.printf
    "\n\
     [t_p24_state_predicates] ==== STAGE-B MEASUREMENT DUMP ====\n\
     [t_p24_state_predicates] Stage B has RUN. FOUR groups below are pinned as \
     literals - B2's After_delete_outdated column, as \
     P24_witness.after_delete_outdated_occupancy_everywhere, the :241 \
     exclusion pin; B3's reject-path column, as \
     P24_witness.ok_resp_some_unowned_obj_everywhere, the owner-ref filter's \
     never-observed-rejecting zero; B4's src_NOT_controller column, as \
     P24_witness.pending_src_not_controller_everywhere, the zero the M2 \
     candidate was CUT on; and ALL of block B5, the SCOPE-EXCLUSION refutation \
     for upstream :116-118 and :119-124. The first three are VACUITIES; B5 is a \
     measured REFUTATION and is pinned for that reason. Every other number here \
     is PRINTED and consumed as disclosed prose in state_predicates.mli; none \
     of them may be quoted as a pin.\n\n\
     B1  gate and per-member interesting for the TWO shipped members (per-member \
     counts come from the REPLICA, never from the leg's violated field):\n";
  List.iter
    (fun ((label, r, reach, _) :
           string
           * Fc.fault_report Lazy.t
           * Fc.faulted Mc.reachable Lazy.t
           * int) ->
      dump_row label (Lazy.force r) (Lazy.force reach))
    rows;
  Printf.printf
    "\n\
     B2  reconcile_step occupancy (SETTLED upstream :241 - After_delete_outdated \
     is 0 on all four, so :241 is EXCLUDED-WITH-A-PIN, and the pin is measured \
     HERE and never inherited from the P11 graph's own zero; every other \
     step-gated row's guard measured OCCUPIED and those rows stay PORTED):\n";
  List.iter
    (fun ((label, _, reach, _) :
           string
           * Fc.fault_report Lazy.t
           * Fc.faulted Mc.reachable Lazy.t
           * int) ->
      dump_hist label (Lazy.force reach))
    rows;
  Printf.printf
    "\n\
     B3  owned_objs non-emptiness over the ok-list-response population \
     (SETTLED RULING section 3.3's fork NON-ZERO, so :116-118 and :119-124 \
     were SHIPPED and then REFUTED; they are now EXCLUDED-WITH-A-PIN on the \
     SCOPE ground and the refutation is pinned in block B5):\n";
  List.iter
    (fun ((label, _, reach, _) :
           string
           * Fc.fault_report Lazy.t
           * Fc.faulted Mc.reachable Lazy.t
           * int) ->
      dump_owned label (Lazy.force reach))
    rows;
  Printf.printf
    "\n\
     B4  rm.src = Controller (controller_id, cr_key) over the parked \
     population (REPLACED the refuted 100%%-red prediction for upstream :49, \
     and then CUT the M2 candidate: src_NOT_controller is 0 on all four over \
     denominators 16 / 112 / 288 / 1560, so :49 is a green that could not have \
     been red. raw_in_flight = delivery_window is the :65 entailment, the other \
     half of the same finding):\n";
  List.iter
    (fun ((label, _, reach, _) :
           string
           * Fc.fault_report Lazy.t
           * Fc.faulted Mc.reachable Lazy.t
           * int) ->
      dump_src label (Lazy.force reach))
    rows;
  Printf.printf
    "\n\
     B5  the SCOPE-EXCLUSION refutation, with attribution (upstream :116-118 \
     and :119-124, EXCLUDED-WITH-A-PIN on upstream's own rely-condition scope \
     comment at state_predicates.rs:116). Every column here is ASSERTED in the \
     scope_exclusion_pin case, because this pin records a MEASURED REFUTATION \
     rather than a vacuity:\n";
  List.iter
    (fun ((label, _, reach, _) :
           string
           * Fc.fault_report Lazy.t
           * Fc.faulted Mc.reachable Lazy.t
           * int) ->
      dump_scope label (Lazy.force reach))
    rows;
  Printf.printf
    "\n[t_p24_state_predicates] ==== END STAGE-B DUMP ====\n\n";
  flush stdout

let () =
  Alcotest.run "p24_state_predicates"
    [
      ( "family_shape",
        [
          Alcotest.test_case
            "predicate_family = M1 :192 / M3 :107, sources = \
             predicate_sources, cardinal 2 (the M2 candidate is CUT)"
            `Quick test_family_shape;
        ] );
      ( "pin_safety",
        [
          Alcotest.test_case
            "the five INHERITED P13-P21 graph pins survive the new leg \
             (graphs are FAMILY-BLIND)"
            `Quick test_pin_safety;
        ] );
      ( "legs",
        [
          Alcotest.test_case
            "SP0: zero-budget - GREEN, both premises live, gate IS the \
             interesting-union"
            `Quick test_sp0;
          Alcotest.test_case "SPc: crash-only - GREEN, both premises live"
            `Quick test_spc;
          Alcotest.test_case "SPd: drop-only - GREEN, both premises live"
            `Quick test_spd;
          Alcotest.test_case "SPm: monkey-only - GREEN, both premises live"
            `Quick test_spm;
        ] );
      ( "inherited_population",
        [
          Alcotest.test_case
            "decode failures 0, decoded / parked / ok-list-response counts are \
             P23's committed pins, re-derived through P24's own probes"
            `Quick test_population;
        ] );
      ( "pvc_exclusion_pin",
        [
          Alcotest.test_case
            "NO decoded ongoing state has a PVC on any P24 graph - M1's SEVEN \
             PVC-pinned conjuncts are behaviour-free"
            `Quick test_pvc_exclusion_pin;
        ] );
      ( "step_histogram",
        [
          Alcotest.test_case
            "probe B2 is TOTAL: the 17 columns sum to the decoded population, \
             the 14 valid-step columns sum to M1's interesting, and \
             After_list_pod IS the parked count"
            `Quick test_step_histogram_is_total;
        ] );
      ( "owned_objs_probe",
        [
          Alcotest.test_case
            "probe B3's controls: the CR HAS an owner ref, the population is \
             non-empty and carries objects, owned + unowned-only partition it"
            `Quick test_owned_objs_probe_controls;
        ] );
      ( "src_positive_control",
        [
          Alcotest.test_case
            "probe B4: the two src polarities PARTITION the parked-with-pending \
             population, and the PIN the M2 candidate was cut on - upstream \
             :49 has NO witness on any graph (src_NOT_controller = 0 over \
             16 / 112 / 288 / 1560)"
            `Quick test_src_positive_control_partition;
        ] );
      ( "scope_exclusion_pin",
        [
          Alcotest.test_case
            "probe B5: :116-118 and :119-124 are EXCLUDED on a SCOPE ground, \
             and the REFUTATION that licensed the exclusion is pinned - \
             0/8/0/72 and 0/4/0/40, every coherence failure the :122 key, and \
             weakly_eq disagreeing NOWHERE"
            `Quick test_scope_exclusion_pin;
        ] );
    ]

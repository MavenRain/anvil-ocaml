(* BUILD-SPEC-P15 §4.4 / §4.5 / §4.6 - the five premise-matrix legs L0..L4 of
   the RECONCILE-SIDE correspondence family
   ({!Anvil_assurance.Reconcile_correspondence}, R1-R4), their gates, the §4.3
   side-condition checker's verdict, R1's structural zero with its
   anti-artifact sweep, and the two supplementary flag-enabled probes that
   make the L2/L3 vacuity honest.

   WHAT THIS EXE ESTABLISHES.

   1. PREDICTION P15-A, measured and CONFIRMED as a negative result: the
      unmutated crash edge refutes NOTHING in this family. L1 and L4 are
      clean and decisive with a REAL crash taken, and the crash's only
      visible effect is on the gate counts (64 -> 368 / 304). Combined with
      P14 (whose network-guarded family the same crash makes newly
      non-vacuous, and whose allocator-reset mutant it reddens), that is the
      phase's structural claim: crash sensitivity is determined by WHERE an
      invariant's guard lives, not by what the invariant says -
      [restart_controller] empties [ongoing_reconciles] (destroying every
      guard here) and preserves [s.network] (preserving every guard there).

   2. The §4.5 premise-necessity matrix, reported per leg with its fault
      counter rather than as bare passes: crash_disabled is
      measured-unnecessary-in-this-model for R2/R3/R4 (L1: clean, decisive,
      crash REALLY taken, post-crash exercise 148/148/156); req_drop_disabled
      and pod_monkey_disabled are VACUOUS AT THE LEG (L2/L3: the fault edge
      was NEVER taken - the leg's seed pins the flag false and flags only
      flip true -> false, so no budget can enable the edge; asserted as
      vacuity, never as a pass) and measured-unnecessary-in-this-model for
      R2/R3/R4 via the flag-enabled probes L2x/L3x (clean, decisive, edge
      really taken). MANDATORY QUALIFIER (§8.3), here as everywhere: none of
      this is a defect in Anvil - upstream's premises serve an UNBOUNDED
      inductive proof over an ARBITRARY reconciler; a bounded single-scenario
      model failing to exhibit the excluded counterexample is weak evidence
      about the model, not about the premise.

   3. The §4.3 side-condition verdict that makes R2/R4 mean anything: both
      instantiations ([Fc.vsts_pending_states] / [Fc.vsts_none_states]) are
      VALIDATED by the executable checkers over the legs' own reachable
      continue_reconcile triples, non-vacuously (the triple sets are
      non-empty and both landing classes are populated). §4.3's "no
      non-vacuous instantiation exists" branch was NOT taken.

   4. R1's gate is 0 at [desired = 1] and the zero is STRUCTURAL
      ([ongoing_reconciles] is keyed by [object_ref]; one CR key can never
      hold two ongoing reconciles), proved not-a-bound-artifact by the
      binding-ceiling sweep (P14's N5 protocol) and made non-vacuous on P12's
      multi-CR [1;1] shape, where R1 fires at 928 / 1856 states and holds
      EVERYWHERE.

   TEST-ORDERING RULE (P12 finding 1, P13/P14 precedent): every test asserts
   the SEMANTIC facts FIRST - outcome clean, [violated = None], decisive,
   fault counter where the claim needs one - and only THEN the brittle exact
   counts, so a shifted pin can never redden the exe before the load-bearing
   assertion runs.

   Every pinned number comes from {!P15_witness} (single source of truth);
   none is re-typed here.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum (both [Mc.outcome] arms, all twelve
   [Step.t] arms, all four [Message.message_content] arms - payload wildcards
   only, never an arm wildcard), no [List.nth/hd/tl], no
   [raise/assert/failwith/Option.get], Alcotest as the sanctioned failure
   primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Cc = Anvil_checker.Cluster_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Rc = Anvil_assurance.Reconcile_correspondence

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P15_witness.witness_desired
let depth : int = P15_witness.witness_depth
let bound : Bound.t = P15_witness.p15_bound ~desireds:[ desired ]

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) -------- *)

let decisive (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let is_clean (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

let states_of (r : Fc.fault_report) : int =
  match r.outcome with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let gate_of (r : Fc.fault_report) : int = Option.value r.gate_states ~default:(-1)

(* ==== the five legs (lazy: no test pays for an exploration it does not use) = *)

let leg (budget : Fc.budget) ~(require_fault : bool) : Fc.fault_report =
  Fc.check_reconcile_correspondence_under_faults ~depth bound budget ~desired
    ~require_fault

let l0_report : Fc.fault_report Lazy.t =
  lazy (leg P15_witness.zero_budget ~require_fault:false)

let l1_report : Fc.fault_report Lazy.t =
  lazy (leg P15_witness.l1_budget ~require_fault:true)

let l2_report : Fc.fault_report Lazy.t =
  lazy (leg P15_witness.l2_budget ~require_fault:false)

let l3_report : Fc.fault_report Lazy.t =
  lazy (leg P15_witness.l3_budget ~require_fault:false)

let l4_report : Fc.fault_report Lazy.t =
  lazy (leg P15_witness.l4_budget ~require_fault:true)

(* ==== the family, and its members individually ==============================
   Instantiated EXACTLY as the leg instantiates them: R2/R4 over the leg's own
   baked-in, side-condition-validated predicates ([Fc.vsts_pending_states] /
   [Fc.vsts_none_states]) - a re-implementation here could drift from what the
   leg asserts. *)

let family : Invariants.invariant list =
  Rc.family ~controller_id ~pending_states:Fc.vsts_pending_states
    ~none_states:Fc.vsts_none_states

let r1 : Invariants.invariant =
  Rc.pending_req_of_key_is_unique_with_unique_id ~controller_id

let r2 : Invariants.invariant =
  Rc.pending_req_in_flight_or_resp_in_flight_at_reconcile_state ~controller_id
    ~expected:Fc.vsts_pending_states

let r3 : Invariants.invariant =
  Rc.pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg
    ~controller_id

let r4 : Invariants.invariant =
  Rc.no_pending_req_msg_at_reconcile_state ~controller_id
    ~expected:Fc.vsts_none_states

(* ==== LOCAL replicas of the legs' product graphs ============================
   The per-member counts, the all-states union gates, the fault-dimension
   maxima and the side-condition triples need the reachable set itself, which
   [fault_report] does not carry. Same seed / bound / budget / depth through
   the exported {!Fc.faulted_successors}; every consuming test asserts
   [Mc.states_seen] against the leg's own [states] FIRST (the P13 M3/M5
   precedent - a drifted replica would silently measure a different graph). *)

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ()

let reach_of ?(b : Bound.t = bound) ?(d : int = depth)
    ?(from : Cluster.cluster_state = seed) (budget : Fc.budget) :
    Fc.faulted Mc.reachable =
  Mc.explore ~depth:d
    ~successors:(Fc.faulted_successors b budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed from ]

let l0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of P15_witness.zero_budget)

let l1_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of P15_witness.l1_budget)

let l4_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of P15_witness.l4_budget)

(* ---- slices of a product graph -------------------------------------------- *)

let all_states (_ : Fc.faulted) : bool = true
let post_crash (f : Fc.faulted) : bool = f.crashes >= 1
let post_drop (f : Fc.faulted) : bool = f.drops >= 1
let post_monkey (f : Fc.faulted) : bool = f.monkeys >= 1

(* [interesting]-fires count for ONE member over a slice. *)
let fires (reach : Fc.faulted Mc.reachable) ~(slice : Fc.faulted -> bool)
    (i : Invariants.invariant) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f && i.Invariants.interesting f.cs)

(* The union gate the leg computes, recomputed locally - what lets the tests
   pin the all-states union on a [require_fault:true] leg. *)
let union_gate (reach : Fc.faulted Mc.reachable) ~(slice : Fc.faulted -> bool) :
    int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f
      && List.exists
           (fun (i : Invariants.invariant) -> i.Invariants.interesting f.cs)
           family)

(* States at which SOME family member's [holds] is FALSE - the probe-side
   cleanliness check (the probes never run the leg function). *)
let family_violations (reach : Fc.faulted Mc.reachable) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      List.exists
        (fun (i : Invariants.invariant) -> not (i.Invariants.holds f.cs))
        family)

let holds_violations (reach : Fc.faulted Mc.reachable)
    (i : Invariants.invariant) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      not (i.Invariants.holds f.cs))

let max_over (reach : Fc.faulted Mc.reachable) ~(proj : Fc.faulted -> int) : int
    =
  Mc.fold_states reach ~init:0 ~f:(fun (acc : int) (f : Fc.faulted) ->
      max acc (proj f))

let max_in_flight (reach : Fc.faulted Mc.reachable) : int =
  max_over reach ~proj:(fun (f : Fc.faulted) ->
      Message.Pool.cardinal (Cluster.in_flight f.cs))

(* Concurrently-pending ongoing reconciles at one state - the R1 mechanism
   measurement ([interesting] needs this >= 2). *)
let pending_count (cs : Cluster.cluster_state) : int =
  Object_ref_map.fold
    (fun (_ : Common.object_ref) (rs : Controller.ongoing_reconcile)
         (acc : int) ->
      acc
      + Option.fold ~none:0
          ~some:(fun (_ : Message.t) -> 1)
          rs.Controller.pending_req_msg)
    (Cluster.ongoing_reconciles cs controller_id)
    0

let max_concurrent_pending (reach : Fc.faulted Mc.reachable) : int =
  max_over reach ~proj:(fun (f : Fc.faulted) -> pending_count f.cs)

(* ==== the §4.3 side-condition apparatus =====================================
   The checkers quantify over the leg's REACHABLE continue_reconcile
   transition triples. Those are edge-derived: from every reachable product
   state, each [Cc.bounded_labelled_successors] edge labelled
   [Step.Controller_step] whose key satisfies continue_reconcile's
   precondition CLASS - key ongoing, model not done, not errored
   (controller.ml:183-205) - is a continue edge; run_scheduled requires the
   key NOT ongoing and end_reconcile requires done-or-errored, so the three
   classes are mutually exclusive and the classification cannot mislabel an
   edge. Each continue edge contributes the exact
   [(triggering_cr, resp_o, pre_state)] the transition consumed, with [recv]
   projected to a response view precisely as [continue_reconcile] projects it
   (controller.ml:121-125, transcribed below). *)

type triple = Dynamic_object.t * Value.t Io.response_view option * Value.t

(* [Controller.response_content_of_msg], transcribed (it is not exported):
   exhaustive over the four content variants; the two request variants are
   precondition-excluded on a continue edge and yield [None]. *)
let response_view_of_msg (m : Message.t) : Value.t Io.response_view option =
  match m.Message.content with
  | Message.Api_response r -> Some (Io.K_response r)
  | Message.External_response v -> Some (Io.External_response v)
  | Message.Api_request _ | Message.External_request _ -> None

(* The reconcile model the scenario ACTUALLY registers (the VStatefulSet pack,
   scenario.ml:287-309) - read off the cluster rather than rebuilt, so the
   side condition is validated against the reconciler the leg's graph really
   executes. *)
let registered_model : Controller.reconcile_model option =
  Option.map
    (fun (cm : Cluster.controller_model) ->
      Controller.model_of_controller ~kind:cm.Cluster.kind cm.Cluster.reconciler)
    (Imap.find_opt controller_id cluster.Cluster.controller_models)

let continue_triples_of_state (model : Controller.reconcile_model)
    (cs : Cluster.cluster_state) : triple list =
  List.filter_map
    (fun ((step, _post) : Step.t * Cluster.cluster_state) ->
      match step with
      | Step.Controller_step (cid, recv, key_o) ->
        if cid = controller_id then
          Option.bind key_o (fun (key : Common.object_ref) ->
              Option.bind
                (Object_ref_map.find_opt key
                   (Cluster.ongoing_reconciles cs controller_id))
                (fun (rs : Controller.ongoing_reconcile) ->
                  if
                    (not
                       (model.Controller.reconcile_done
                          rs.Controller.local_state))
                    && not
                         (model.Controller.reconcile_error
                            rs.Controller.local_state)
                  then
                    Some
                      ( rs.Controller.triggering_cr,
                        Option.bind recv response_view_of_msg,
                        rs.Controller.local_state )
                  else None))
        else None
      | Step.Api_server_step _ | Step.Builtin_controllers_step _
      | Step.Schedule_controller_reconcile_step _
      | Step.Restart_controller_step _ | Step.Disable_crash_step _
      | Step.Drop_req_step _ | Step.Disable_req_drop_step
      | Step.Pod_monkey_step _ | Step.Disable_pod_monkey_step
      | Step.External_step _ | Step.Stutter_step -> None)
    (Cc.bounded_labelled_successors bound cluster cs)

let continue_triples (model : Controller.reconcile_model)
    (reach : Fc.faulted Mc.reachable) : triple list =
  Mc.fold_states reach ~init:[] ~f:(fun (acc : triple list) (f : Fc.faulted) ->
      List.rev_append (continue_triples_of_state model f.cs) acc)

(* How many triples LAND in [expected] (the transition conjunct's domain):
   the non-vacuity measurement for each checker. *)
let landing_count (model : Controller.reconcile_model)
    ~(expected : Value.t -> bool) (triples : triple list) : int =
  List.fold_left
    (fun (acc : int) ((cr, resp_o, pre) : triple) ->
      let post_state, _req_o = model.Controller.transition cr resp_o pre in
      if expected post_state then acc + 1 else acc)
    0 triples

(* ==== the shared leg semantics (asserted BEFORE any count) ================== *)

let check_leg_semantics (label : string) (r : Fc.fault_report) : unit =
  Alcotest.(check bool) (label ^ ": outcome clean (no counterexample)") true
    (is_clean r);
  Alcotest.(check bool) (label ^ ": violated = None") true
    (Option.is_none r.violated);
  Alcotest.(check bool) (label ^ ": outcome decisive (frontier emptied)") true
    (decisive r);
  Alcotest.(check bool)
    (label ^ ": gate_states positive (the union gate is NOT vacuous)") true
    (gate_of r > 0);
  Alcotest.(check bool) (label ^ ": fault_free_states positive") true
    (r.fault_free_states > 0);
  Alcotest.(check bool)
    (label ^ ": max_uid_seen STRICTLY below uid_ceiling (interpretable)") true
    (r.max_uid_seen < r.bound.uid_ceiling);
  Alcotest.(check bool)
    (label ^ ": max_rv_seen STRICTLY below rv_ceiling (interpretable)") true
    (r.max_rv_seen < r.bound.rv_ceiling);
  Alcotest.(check bool)
    (label ^ ": max_crashes_seen within budget (budget pruning is sound)") true
    (r.max_crashes_seen <= r.budget.max_crashes);
  Alcotest.(check bool)
    (label ^ ": max_drops_seen within budget") true
    (r.max_drops_seen <= r.budget.max_drops);
  Alcotest.(check bool)
    (label ^ ": max_monkeys_seen within budget") true
    (r.max_monkeys_seen <= r.budget.max_monkey_ops)

(* If a run here ever reports [violated] naming a P14 member, the family lists
   were unioned somewhere (the §3 masking trap): that is a harness bug, not a
   finding. [check_leg_semantics] already asserts [violated = None] on every
   clean leg, and [t_p15_regression] rejects the union by NAME. *)

(* ==== L0: zero-budget control =============================================== *)

let test_l0_control () =
  let r = Lazy.force l0_report in
  check_leg_semantics "L0" r;
  (* The control really is fault-free: every fault dimension at zero. *)
  Alcotest.(check int) "L0: max_crashes_seen = 0 (budget clips every crash edge)"
    P15_witness.l0_max_crashes_seen r.max_crashes_seen;
  Alcotest.(check int) "L0: max_drops_seen = 0" 0 r.max_drops_seen;
  Alcotest.(check int) "L0: max_monkeys_seen = 0" 0 r.max_monkeys_seen;
  Alcotest.(check int) "L0: crash_witness_states = 0 (crash-free graph)"
    P15_witness.l0_crash_witness_states r.crash_witness_states;
  Alcotest.(check bool)
    "L0: states = fault_free_states (the graph IS the fault-free slice)" true
    (states_of r = r.fault_free_states);
  Alcotest.(check bool) "L0: pruned_by_ceiling (disclosed)" true
    r.pruned_by_ceiling;
  Alcotest.(check bool)
    "L0: pruned_by_budget (the seed's crash flag is ON, so the budget clips \
     real crash edges)"
    true r.pruned_by_budget;
  (* The §4.4 cross-check IDENTITY, asserted against the live leg rather than
     assumed by derivation: with all caps 0 this graph is the fault-free slice
     of P13's G1 / P14's G2 graph. *)
  Alcotest.(check int)
    "L0: states = P13's G1 fault_free_states (same seed/bound/depth, all caps 0)"
    P13_witness.g1_fault_free_states (states_of r);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L0: states (pinned)" P15_witness.l0_states (states_of r);
  Alcotest.(check int) "L0: gate_states (pinned)" P15_witness.l0_gate_states
    (gate_of r);
  Alcotest.(check int) "L0: fault_free_states (pinned)"
    P15_witness.l0_fault_free_states r.fault_free_states;
  Alcotest.(check int) "L0: settled_with_faults_live (pinned)"
    P15_witness.l0_settled_with_faults_live r.settled_with_faults_live;
  Alcotest.(check int) "L0: max_uid_seen (pinned)" P15_witness.l0_max_uid_seen
    r.max_uid_seen;
  Alcotest.(check int) "L0: max_rv_seen (pinned)" P15_witness.l0_max_rv_seen
    r.max_rv_seen

let test_l0_members () =
  let reach = Lazy.force l0_reach in
  let r = Lazy.force l0_report in
  (* The local replica really is the leg's graph. *)
  Alcotest.(check int)
    "L0: local replica graph size = the leg's own states (replica faithful)"
    (states_of r) (Mc.states_seen reach);
  Alcotest.(check bool) "L0: replica frontier emptied" true
    (Mc.frontier_emptied reach);
  (* The leg's gate is the union the replica recomputes - MEASURED EQUAL. *)
  Alcotest.(check int)
    "L0: recomputed all-states union gate = the leg's gate_states" (gate_of r)
    (union_gate reach ~slice:all_states);
  (* SEMANTIC first: the control is valid for R2/R3/R4 - each genuinely
     exercised with all three upstream premises held. *)
  let count (i : Invariants.invariant) = fires reach ~slice:all_states i in
  Alcotest.(check bool) "L0: R2 interesting fires (> 0)" true (count r2 > 0);
  Alcotest.(check bool) "L0: R3 interesting fires (> 0)" true (count r3 > 0);
  Alcotest.(check bool) "L0: R4 interesting fires (> 0)" true (count r4 > 0);
  (* R1's ZERO, asserted explicitly as a MEASURED STRUCTURAL vacuity, not
     skipped: [ongoing_reconciles] is keyed by [object_ref], so this single-CR
     seed can never hold two ongoing reconciles and R1's two-pending premise
     is unreachable - at ANY ceiling (see the sweep test). NOT a bound
     artifact. *)
  Alcotest.(check int)
    "L0: R1 interesting fires NOWHERE at desired = 1 (STRUCTURAL zero, pinned)"
    P15_witness.r1_interesting_l0 (count r1);
  (* The §5 re-measurement: fault-free lock-step traffic peaks at ONE in-flight
     message; the max_in_flight ceiling (8) is nowhere near binding. *)
  Alcotest.(check int) "L0: max in-flight cardinal over the graph (pinned)"
    P15_witness.l0_max_in_flight_seen (max_in_flight reach);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L0: R2 interesting count (pinned)"
    P15_witness.r2_interesting_l0 (count r2);
  Alcotest.(check int) "L0: R3 interesting count (pinned)"
    P15_witness.r3_interesting_l0 (count r3);
  Alcotest.(check int) "L0: R4 interesting count (pinned)"
    P15_witness.r4_interesting_l0 (count r4)

(* ==== L1: crash-only - the crash_disabled premise (crs.rs:414) ============== *)

let test_l1_crash_leg () =
  let r = Lazy.force l1_report in
  check_leg_semantics "L1" r;
  (* The non-vacuity core of the premise verdict: the crash edge was REALLY
     taken, and the gate counts only post-crash exercise. *)
  Alcotest.(check bool) "L1: max_crashes_seen >= 1 (a REAL crash occurred)" true
    (r.max_crashes_seen >= 1);
  Alcotest.(check bool)
    "L1: crash_witness_states positive (post-crash slice non-empty)" true
    (r.crash_witness_states > 0);
  Alcotest.(check bool)
    "L1: gate_states <= crash_witness_states (the gate is INSIDE the \
     post-crash slice)"
    true
    (gate_of r <= r.crash_witness_states);
  Alcotest.(check int) "L1: max_drops_seen = 0 (crash dimension ISOLATED)" 0
    r.max_drops_seen;
  Alcotest.(check int) "L1: max_monkeys_seen = 0 (crash dimension ISOLATED)" 0
    r.max_monkeys_seen;
  Alcotest.(check bool) "L1: pruned_by_ceiling (disclosed)" true
    r.pruned_by_ceiling;
  Alcotest.(check bool) "L1: pruned_by_budget (the 2nd crash edge is clipped)"
    true r.pruned_by_budget;
  (* PREDICTION P15-A, the crash-side half: the leg is CLEAN across a real
     crash (the semantic checks above), and the graph strictly grew vs L0 -
     the crash's only visible effect is on the counts, not the verdict. *)
  Alcotest.(check bool)
    "L1 (P15-A): strictly more states than L0 (the crash budget is \
     load-bearing)"
    true
    (states_of r > states_of (Lazy.force l0_report));
  (* The §4.4 cross-check IDENTITY: same seed / bound / budget / depth as P13's
     G1 and P14's G2 legs, so the product set is literally theirs. A drift here
     means seed or bound moved - investigate, do not re-pin. *)
  Alcotest.(check int)
    "L1: states = P13's G1 states (identical product graph, different family)"
    P13_witness.g1_states (states_of r);
  Alcotest.(check int)
    "L1: crash_witness_states = P13's G1 crash_witness_states"
    P13_witness.g1_crash_witness_states r.crash_witness_states;
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L1: states (pinned)" P15_witness.l1_states (states_of r);
  Alcotest.(check int) "L1: gate_states (pinned, post-crash union)"
    P15_witness.l1_gate_states (gate_of r);
  Alcotest.(check int) "L1: crash_witness_states (pinned)"
    P15_witness.l1_crash_witness_states r.crash_witness_states;
  Alcotest.(check int) "L1: fault_free_states (pinned)"
    P15_witness.l1_fault_free_states r.fault_free_states;
  Alcotest.(check int) "L1: settled_with_faults_live (pinned via P13's 10)"
    P15_witness.l1_settled_with_faults_live r.settled_with_faults_live;
  Alcotest.(check int) "L1: max_uid_seen (pinned)" P15_witness.l1_max_uid_seen
    r.max_uid_seen;
  Alcotest.(check int) "L1: max_rv_seen (pinned)" P15_witness.l1_max_rv_seen
    r.max_rv_seen;
  Alcotest.(check int) "L1: max_crashes_seen (pinned)"
    P15_witness.l1_max_crashes_seen r.max_crashes_seen

let test_l1_members () =
  let reach = Lazy.force l1_reach in
  let r = Lazy.force l1_report in
  Alcotest.(check int)
    "L1: local replica graph size = the leg's own states (replica faithful)"
    (states_of r) (Mc.states_seen reach);
  Alcotest.(check bool) "L1: replica frontier emptied" true
    (Mc.frontier_emptied reach);
  (* The leg's post-crash gate is the union the replica recomputes. *)
  Alcotest.(check int)
    "L1: recomputed post-crash union gate = the leg's gate_states" (gate_of r)
    (union_gate reach ~slice:post_crash);
  let all (i : Invariants.invariant) = fires reach ~slice:all_states i in
  let post (i : Invariants.invariant) = fires reach ~slice:post_crash i in
  (* SEMANTIC first: clean-under-crash is non-vacuous PER MEMBER for R2/R3/R4 -
     each is exercised at genuinely post-crash states. *)
  Alcotest.(check bool) "L1: R2 fires POST-CRASH (> 0)" true (post r2 > 0);
  Alcotest.(check bool) "L1: R3 fires POST-CRASH (> 0)" true (post r3 > 0);
  Alcotest.(check bool) "L1: R4 fires POST-CRASH (> 0)" true (post r4 > 0);
  (* R1 stays structurally vacuous under crash too - the crash does not mint a
     second CR key. Pinned zero, both slices. *)
  Alcotest.(check int) "L1: R1 interesting count (pinned STRUCTURAL zero)"
    P15_witness.r1_interesting_l1 (all r1);
  Alcotest.(check int) "L1: R1 post-crash interesting count (pinned zero)"
    P15_witness.r1_interesting_l1_post_crash (post r1);
  (* The §5 re-measurement, crash side: the orphaned pre-crash request makes
     the peak 2 - still four times below the ceiling 8. No retune (disclosed
     in P15_witness). *)
  Alcotest.(check int) "L1: max in-flight cardinal over the graph (pinned)"
    P15_witness.l1_max_in_flight_seen (max_in_flight reach);
  (* The all-states union gate, recomputed (the leg only reports post-crash). *)
  Alcotest.(check int) "L1: all-states union gate (pinned)"
    P15_witness.l1_gate_states_all
    (union_gate reach ~slice:all_states);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L1: R2 interesting count (pinned)"
    P15_witness.r2_interesting_l1 (all r2);
  Alcotest.(check int) "L1: R3 interesting count (pinned)"
    P15_witness.r3_interesting_l1 (all r3);
  Alcotest.(check int) "L1: R4 interesting count (pinned)"
    P15_witness.r4_interesting_l1 (all r4);
  Alcotest.(check int) "L1: R2 post-crash interesting count (pinned)"
    P15_witness.r2_interesting_l1_post_crash (post r2);
  Alcotest.(check int) "L1: R3 post-crash interesting count (pinned)"
    P15_witness.r3_interesting_l1_post_crash (post r3);
  Alcotest.(check int) "L1: R4 post-crash interesting count (pinned)"
    P15_witness.r4_interesting_l1_post_crash (post r4)

(* ==== L2: drops-only - VACUOUS BY CONSTRUCTION (asserted, not skipped) ====== *)

let test_l2_drop_leg_vacuous () =
  let r = Lazy.force l2_report in
  check_leg_semantics "L2" r;
  (* THE VACUITY, asserted explicitly with its mechanism: the leg's seed is
     [Scenario.vsts_seed_faults ~req_drop:false], and fault flags only flip
     true -> false, so NO budget can enable [Step.Drop_req_step]. The drop cap
     is 1 but the edge is NEVER taken: this leg measures NOTHING about
     req_drop_disabled and must never be read as that premise's pass
     ([[feedback-workflow-zero-findings-may-be-vacuous]]). The honest
     measurement is the flag-enabled probe L2x below. *)
  Alcotest.(check int) "L2: budget really admits one drop (cap = 1)" 1
    r.budget.Fc.max_drops;
  Alcotest.(check int)
    "L2: max_drops_seen = 0 against cap 1 - the drop edge was NEVER taken \
     (VACUOUS by construction, pinned)"
    P15_witness.l2_max_drops_seen r.max_drops_seen;
  Alcotest.(check int) "L2: max_crashes_seen = 0" 0 r.max_crashes_seen;
  Alcotest.(check int) "L2: max_monkeys_seen = 0" 0 r.max_monkeys_seen;
  Alcotest.(check int) "L2: crash_witness_states = 0" 0 r.crash_witness_states;
  (* Byte-identity with L0, asserted against BOTH live legs: a budget that can
     enable nothing leaves the product graph exactly the control's. *)
  Alcotest.(check int) "L2: states = L0's live states (graph identical)"
    (states_of (Lazy.force l0_report))
    (states_of r);
  Alcotest.(check int) "L2: gate_states = L0's live gate (graph identical)"
    (gate_of (Lazy.force l0_report))
    (gate_of r);
  (* The post-drop slice is EMPTY - the per-member form of the vacuity: every
     post-drop member count is 0 because no post-drop state exists at all. *)
  let reach = reach_of P15_witness.l2_budget in
  Alcotest.(check int)
    "L2: replica graph size = the leg's states (replica faithful)" (states_of r)
    (Mc.states_seen reach);
  Alcotest.(check int)
    "L2: post-drop slice is EMPTY (no reachable state has drops >= 1)" 0
    (Mc.count_states_where reach post_drop);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L2: states (pinned = L0's)" P15_witness.l2_states
    (states_of r);
  Alcotest.(check int) "L2: gate_states (pinned = L0's)"
    P15_witness.l2_gate_states (gate_of r)

(* ==== L3: monkey-only - VACUOUS BY CONSTRUCTION (same mechanism) ============ *)

let test_l3_monkey_leg_vacuous () =
  let r = Lazy.force l3_report in
  check_leg_semantics "L3" r;
  (* Same mechanism as L2: seed pins [~pod_monkey:false], no budget can enable
     [Step.Pod_monkey_step]. Cap 1, edge never taken, measures NOTHING about
     pod_monkey_disabled. Honest measurement: probe L3x below. *)
  Alcotest.(check int) "L3: budget really admits one monkey op (cap = 1)" 1
    r.budget.Fc.max_monkey_ops;
  Alcotest.(check int)
    "L3: max_monkeys_seen = 0 against cap 1 - the monkey edge was NEVER taken \
     (VACUOUS by construction, pinned)"
    P15_witness.l3_max_monkeys_seen r.max_monkeys_seen;
  Alcotest.(check int) "L3: max_crashes_seen = 0" 0 r.max_crashes_seen;
  Alcotest.(check int) "L3: max_drops_seen = 0" 0 r.max_drops_seen;
  Alcotest.(check int) "L3: crash_witness_states = 0" 0 r.crash_witness_states;
  Alcotest.(check int) "L3: states = L0's live states (graph identical)"
    (states_of (Lazy.force l0_report))
    (states_of r);
  Alcotest.(check int) "L3: gate_states = L0's live gate (graph identical)"
    (gate_of (Lazy.force l0_report))
    (gate_of r);
  let reach = reach_of P15_witness.l3_budget in
  Alcotest.(check int)
    "L3: replica graph size = the leg's states (replica faithful)" (states_of r)
    (Mc.states_seen reach);
  Alcotest.(check int)
    "L3: post-monkey slice is EMPTY (no reachable state has monkeys >= 1)" 0
    (Mc.count_states_where reach post_monkey);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L3: states (pinned = L0's)" P15_witness.l3_states
    (states_of r);
  Alcotest.(check int) "L3: gate_states (pinned = L0's)"
    P15_witness.l3_gate_states (gate_of r)

(* ==== L4: all three budgets at once - re-measures L1 only =================== *)

let test_l4_all_faults () =
  let r = Lazy.force l4_report in
  check_leg_semantics "L4" r;
  (* The crash dimension is exercised... *)
  Alcotest.(check bool) "L4: max_crashes_seen >= 1 (a REAL crash occurred)" true
    (r.max_crashes_seen >= 1);
  (* ...and the drop/monkey dimensions are VACUOUS AT THE LEG (same seed-flag
     mechanism as L2/L3), so L4 re-measures L1 and nothing more. Pinned as
     vacuity, not silently passed over. *)
  Alcotest.(check int)
    "L4: max_drops_seen = 0 against cap 1 (drop dimension VACUOUS at the leg)"
    P15_witness.l4_max_drops_seen r.max_drops_seen;
  Alcotest.(check int)
    "L4: max_monkeys_seen = 0 against cap 1 (monkey dimension VACUOUS at the \
     leg)"
    P15_witness.l4_max_monkeys_seen r.max_monkeys_seen;
  (* Byte-identity with the live L1 leg: only the crash dimension fires, so the
     {1;1;1} budget reaches exactly the {1;0;0} product set. *)
  Alcotest.(check int) "L4: states = L1's live states (graph identical)"
    (states_of (Lazy.force l1_report))
    (states_of r);
  Alcotest.(check int) "L4: gate_states = L1's live gate (graph identical)"
    (gate_of (Lazy.force l1_report))
    (gate_of r);
  Alcotest.(check int) "L4: crash_witness_states = L1's live crash witness"
    (Lazy.force l1_report).crash_witness_states r.crash_witness_states;
  (* The replica agrees, member by member: the drop/monkey caps moved nothing. *)
  let reach = Lazy.force l4_reach in
  Alcotest.(check int)
    "L4: replica graph size = the leg's states (replica faithful)" (states_of r)
    (Mc.states_seen reach);
  Alcotest.(check int) "L4: post-drop slice EMPTY" 0
    (Mc.count_states_where reach post_drop);
  Alcotest.(check int) "L4: post-monkey slice EMPTY" 0
    (Mc.count_states_where reach post_monkey);
  Alcotest.(check int) "L4: all-states union gate (pinned, = L1's)"
    P15_witness.l4_gate_states_all
    (union_gate reach ~slice:all_states);
  Alcotest.(check int) "L4: R2 interesting count = L1's pin (same graph)"
    P15_witness.r2_interesting_l1
    (fires reach ~slice:all_states r2);
  Alcotest.(check int) "L4: R3 interesting count = L1's pin (same graph)"
    P15_witness.r3_interesting_l1
    (fires reach ~slice:all_states r3);
  Alcotest.(check int) "L4: R4 interesting count = L1's pin (same graph)"
    P15_witness.r4_interesting_l1
    (fires reach ~slice:all_states r4);
  Alcotest.(check int) "L4: R1 interesting count = 0 (structural, same graph)"
    P15_witness.r1_interesting_l1
    (fires reach ~slice:all_states r1);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L4: states (pinned = L1's)" P15_witness.l4_states
    (states_of r);
  Alcotest.(check int) "L4: gate_states (pinned = L1's)"
    P15_witness.l4_gate_states (gate_of r);
  Alcotest.(check int) "L4: crash_witness_states (pinned = L1's)"
    P15_witness.l4_crash_witness_states r.crash_witness_states

(* ==== the §4.3 side-condition verdict ======================================= *)

let test_side_condition () =
  (* The model the leg's scenario actually registers must exist at all. *)
  Alcotest.(check bool) "side condition: the registered VSTS model exists" true
    (Option.is_some registered_model);
  Option.fold ~none:()
    ~some:(fun (model : Controller.reconcile_model) ->
      (* The INIT conjunct is genuinely DISCRIMINATING, not trivially true:
         the R2 instantiation rejects the reconciler's init state. (Upstream's
         [forall s. state(s) ==> s != init()] is checked exactly, unbounded -
         see reconcile_correspondence.mli.) *)
      Alcotest.(check bool)
        "side condition: vsts_pending_states (init ()) = false (init conjunct \
         discriminates)"
        false
        (Fc.vsts_pending_states (model.Controller.init ()));
      let l0_triples = continue_triples model (Lazy.force l0_reach) in
      let l1_triples = continue_triples model (Lazy.force l1_reach) in
      (* SEMANTIC first: the transition conjunct is EXERCISED - the triple sets
         are non-empty and BOTH landing classes are populated, so neither
         checker verdict below is vacuous (the .mli's disclosed duty). *)
      Alcotest.(check bool)
        "side condition: L0 triple set non-empty (transition conjunct \
         exercised)"
        true
        (List.length l0_triples > 0);
      Alcotest.(check bool)
        "side condition: L0 has triples landing in pending states" true
        (landing_count model ~expected:Fc.vsts_pending_states l0_triples > 0);
      Alcotest.(check bool)
        "side condition: L0 has triples landing in none states" true
        (landing_count model ~expected:Fc.vsts_none_states l0_triples > 0);
      (* THE VERDICTS: both instantiations VALIDATED over the legs' own
         reachable triples. R2/R4 were therefore measured at instantiations
         satisfying their upstream side conditions
         (controller_runtime_safety.rs:100 / :507); §4.3's "no non-vacuous
         instantiation exists" branch was NOT taken. *)
      Alcotest.(check bool)
        "side condition: state_comes_with_a_pending_request HOLDS on L0's \
         reachable triples"
        true
        (Rc.state_comes_with_a_pending_request model
           ~expected:Fc.vsts_pending_states l0_triples);
      Alcotest.(check bool)
        "side condition: state_comes_with_no_pending_request HOLDS on L0's \
         reachable triples"
        true
        (Rc.state_comes_with_no_pending_request model
           ~expected:Fc.vsts_none_states l0_triples);
      Alcotest.(check bool)
        "side condition: state_comes_with_a_pending_request HOLDS on L1's \
         reachable triples"
        true
        (Rc.state_comes_with_a_pending_request model
           ~expected:Fc.vsts_pending_states l1_triples);
      Alcotest.(check bool)
        "side condition: state_comes_with_no_pending_request HOLDS on L1's \
         reachable triples"
        true
        (Rc.state_comes_with_no_pending_request model
           ~expected:Fc.vsts_none_states l1_triples);
      (* The two landing classes PARTITION each triple set exactly (every
         continue landing decodes; pending/none are complements over decodable
         states) - measured, and load-bearing for reading the counts below. *)
      Alcotest.(check int)
        "side condition: L0 landing classes partition the triple set"
        (List.length l0_triples)
        (landing_count model ~expected:Fc.vsts_pending_states l0_triples
        + landing_count model ~expected:Fc.vsts_none_states l0_triples);
      Alcotest.(check int)
        "side condition: L1 landing classes partition the triple set"
        (List.length l1_triples)
        (landing_count model ~expected:Fc.vsts_pending_states l1_triples
        + landing_count model ~expected:Fc.vsts_none_states l1_triples);
      (* Exact MEASURED pins LAST. *)
      Alcotest.(check int) "side condition: L0 continue triples (pinned)"
        P15_witness.l0_continue_triples (List.length l0_triples);
      Alcotest.(check int) "side condition: L0 land-pending (pinned)"
        P15_witness.l0_triples_landing_pending
        (landing_count model ~expected:Fc.vsts_pending_states l0_triples);
      Alcotest.(check int) "side condition: L0 land-none (pinned)"
        P15_witness.l0_triples_landing_none
        (landing_count model ~expected:Fc.vsts_none_states l0_triples);
      Alcotest.(check int) "side condition: L1 continue triples (pinned)"
        P15_witness.l1_continue_triples (List.length l1_triples);
      Alcotest.(check int) "side condition: L1 land-pending (pinned)"
        P15_witness.l1_triples_landing_pending
        (landing_count model ~expected:Fc.vsts_pending_states l1_triples);
      Alcotest.(check int) "side condition: L1 land-none (pinned)"
        P15_witness.l1_triples_landing_none
        (landing_count model ~expected:Fc.vsts_none_states l1_triples))
    registered_model

(* ==== R1's structural zero: the binding-ceiling sweep (P14's N5 protocol) === *)

let test_r1_ceiling_sweep () =
  (* The ceiling that actually BINDS here is [reconcile_ceiling = 2] (it is
     what makes [pruned_by_ceiling] true on every leg), so that is the one
     swept - raising uid/rv ceilings the reports say were never reached would
     be a priori invariance, not evidence. At rc 4+ the shipped depth stops
     being decisive (depth binds first), so the higher points run at raised
     depth, exactly as P14's sweep did. *)
  let sweep ~(rc : int) ~(d : int) (budget : Fc.budget) :
      Fc.faulted Mc.reachable =
    reach_of ~b:{ bound with Bound.reconcile_ceiling = rc } ~d budget
  in
  let zb = P15_witness.zero_budget in
  let r_low = sweep ~rc:P15_witness.rc_sweep_low ~d:depth zb in
  let r_mid =
    sweep ~rc:P15_witness.rc_sweep_mid ~d:P15_witness.rc_sweep_mid_depth zb
  in
  let r_high =
    sweep ~rc:P15_witness.rc_sweep_high ~d:P15_witness.rc_sweep_high_depth zb
  in
  let r_crash =
    sweep ~rc:P15_witness.rc_sweep_low ~d:P15_witness.l1_rc_low_depth
      P15_witness.l1_budget
  in
  (* SEMANTIC first: every swept graph is decisively explored and CLEAN - the
     family holds at every reachable state of every sweep point. *)
  Alcotest.(check bool) "sweep: rc-low frontier emptied" true
    (Mc.frontier_emptied r_low);
  Alcotest.(check bool) "sweep: rc-mid frontier emptied" true
    (Mc.frontier_emptied r_mid);
  Alcotest.(check bool) "sweep: rc-high frontier emptied" true
    (Mc.frontier_emptied r_high);
  Alcotest.(check bool) "sweep: crash-only rc-low frontier emptied" true
    (Mc.frontier_emptied r_crash);
  Alcotest.(check int) "sweep: rc-low family violations = 0" 0
    (family_violations r_low);
  Alcotest.(check int) "sweep: rc-mid family violations = 0" 0
    (family_violations r_mid);
  Alcotest.(check int) "sweep: rc-high family violations = 0" 0
    (family_violations r_high);
  Alcotest.(check int) "sweep: crash-only rc-low family violations = 0" 0
    (family_violations r_crash);
  (* THE ANTI-ARTIFACT EVIDENCE: R1's zero survives every raised ceiling, and
     the MECHANISM is measured stronger than the count - no reachable state
     ever holds two concurrently-pending ongoing reconciles, because
     [ongoing_reconciles] is keyed by [object_ref] and the seed has ONE CR
     key. The zero is structural, not a bound artifact. *)
  Alcotest.(check int) "sweep: R1 interesting = 0 at rc-low (pinned)"
    P15_witness.r1_interesting_swept
    (fires r_low ~slice:all_states r1);
  Alcotest.(check int) "sweep: R1 interesting = 0 at rc-mid (pinned)"
    P15_witness.r1_interesting_swept
    (fires r_mid ~slice:all_states r1);
  Alcotest.(check int) "sweep: R1 interesting = 0 at rc-high (pinned)"
    P15_witness.r1_interesting_swept
    (fires r_high ~slice:all_states r1);
  Alcotest.(check int) "sweep: R1 interesting = 0 at crash-only rc-low (pinned)"
    P15_witness.r1_interesting_swept
    (fires r_crash ~slice:all_states r1);
  Alcotest.(check int) "sweep: max concurrent pending = 1 at rc-low (pinned)"
    P15_witness.max_concurrent_pending_single_cr
    (max_concurrent_pending r_low);
  Alcotest.(check int) "sweep: max concurrent pending = 1 at rc-mid (pinned)"
    P15_witness.max_concurrent_pending_single_cr
    (max_concurrent_pending r_mid);
  Alcotest.(check int) "sweep: max concurrent pending = 1 at rc-high (pinned)"
    P15_witness.max_concurrent_pending_single_cr
    (max_concurrent_pending r_high);
  Alcotest.(check int)
    "sweep: max concurrent pending = 1 at crash-only rc-low (pinned)"
    P15_witness.max_concurrent_pending_single_cr
    (max_concurrent_pending r_crash);
  (* Exact MEASURED graph sizes LAST. *)
  Alcotest.(check int) "sweep: rc-low states (pinned)"
    P15_witness.l0_rc_low_states (Mc.states_seen r_low);
  Alcotest.(check int) "sweep: rc-mid states (pinned)"
    P15_witness.l0_rc_mid_states (Mc.states_seen r_mid);
  Alcotest.(check int) "sweep: rc-high states (pinned)"
    P15_witness.l0_rc_high_states (Mc.states_seen r_high);
  Alcotest.(check int) "sweep: crash-only rc-low states (pinned)"
    P15_witness.l1_rc_low_states (Mc.states_seen r_crash)

let test_r1_desired_two_and_multi_cr () =
  (* [desired = 2] is still ONE CR key (two replicas), so R1 stays structurally
     vacuous - the discriminating variable is CR COUNT, not replica count. *)
  let d2_bound = P15_witness.p15_bound ~desireds:[ P15_witness.desired_two ] in
  let d2_seed =
    Scenario.vsts_seed_faults ~desired:P15_witness.desired_two ~crash:true
      ~req_drop:false ~pod_monkey:false ()
  in
  let d2 = reach_of ~b:d2_bound ~from:d2_seed P15_witness.l1_budget in
  Alcotest.(check bool) "desired=2: frontier emptied" true
    (Mc.frontier_emptied d2);
  Alcotest.(check int) "desired=2: family violations = 0" 0
    (family_violations d2);
  Alcotest.(check int) "desired=2: R1 interesting = 0 (pinned - one CR key)"
    P15_witness.r1_interesting_desired_two
    (fires d2 ~slice:all_states r1);
  Alcotest.(check int) "desired=2: max concurrent pending = 1 (pinned)"
    P15_witness.max_concurrent_pending_single_cr (max_concurrent_pending d2);
  Alcotest.(check int) "desired=2: states (pinned)"
    P15_witness.desired_two_states (Mc.states_seen d2);
  (* P12's multi-CR [1;1] shape DOES mint two concurrently-ongoing reconciles,
     and there R1 is non-vacuously exercised and CLEAN: it fires at hundreds
     of states and its [holds] is violated at none. This is what licenses
     calling the desired=1 zero structural rather than unexercisable. *)
  let mc_bound = P15_witness.p15_bound ~desireds:P15_witness.multi_cr_desireds in
  let mc_seed =
    Scenario.vsts_seed_multi_faults ~desireds:P15_witness.multi_cr_desireds
      ~crash:true ~req_drop:false ~pod_monkey:false
  in
  let mc_zero = reach_of ~b:mc_bound ~from:mc_seed P15_witness.zero_budget in
  let mc_crash = reach_of ~b:mc_bound ~from:mc_seed P15_witness.l1_budget in
  Alcotest.(check bool) "multi-CR zero-budget: frontier emptied" true
    (Mc.frontier_emptied mc_zero);
  Alcotest.(check bool) "multi-CR crash-only: frontier emptied" true
    (Mc.frontier_emptied mc_crash);
  (* SEMANTIC first: R1 really is exercised on both graphs. *)
  Alcotest.(check bool) "multi-CR zero-budget: R1 interesting fires (> 0)" true
    (fires mc_zero ~slice:all_states r1 > 0);
  Alcotest.(check bool) "multi-CR crash-only: R1 interesting fires (> 0)" true
    (fires mc_crash ~slice:all_states r1 > 0);
  (* ...and CLEAN where exercised. *)
  Alcotest.(check int)
    "multi-CR zero-budget: R1 holds violated NOWHERE (pinned)"
    P15_witness.r1_holds_violations_multi_cr
    (holds_violations mc_zero r1);
  Alcotest.(check int) "multi-CR crash-only: R1 holds violated NOWHERE (pinned)"
    P15_witness.r1_holds_violations_multi_cr
    (holds_violations mc_crash r1);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "multi-CR zero-budget: states (pinned)"
    P15_witness.multi_cr_zero_states (Mc.states_seen mc_zero);
  Alcotest.(check int) "multi-CR zero-budget: R1 interesting count (pinned)"
    P15_witness.r1_interesting_multi_cr_zero
    (fires mc_zero ~slice:all_states r1);
  Alcotest.(check int) "multi-CR crash-only: states (pinned)"
    P15_witness.multi_cr_crash_states (Mc.states_seen mc_crash);
  Alcotest.(check int) "multi-CR crash-only: R1 interesting count (pinned)"
    P15_witness.r1_interesting_multi_cr_crash
    (fires mc_crash ~slice:all_states r1)

(* ==== the SUPPLEMENTARY flag-enabled probes (honest L2/L3 counterparts) =====
   NOT the leg: the same family conjunction over a direct product graph whose
   seed enables the flag the leg's seed pins off - the only way the drop and
   monkey premises are measurable at all. Each carries a flag-ON zero-budget
   control. *)

let test_l2x_drop_probe () =
  let l2x_seed =
    Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:true
      ~pod_monkey:false ()
  in
  let probe = reach_of ~from:l2x_seed P15_witness.l2_budget in
  let control = reach_of ~from:l2x_seed P15_witness.zero_budget in
  (* SEMANTIC first: decisive, the drop edge REALLY taken, and the family
     clean everywhere - PREDICTION P15-C confirmed ([Network.deliver] removes
     the request as it adds the matched error response, so exactly one XOR
     disjunct holds at every step; if this ever reds, read [Network.deliver]
     before believing a refutation). With the §8.3 qualifier this makes
     req_drop_disabled measured-unnecessary-IN-THIS-MODEL for R2/R3/R4. *)
  Alcotest.(check bool) "L2x: frontier emptied (decisive)" true
    (Mc.frontier_emptied probe);
  Alcotest.(check int)
    "L2x: max drops over the graph = 1 (the drop edge WAS taken)"
    P15_witness.l2x_max_drops_seen
    (max_over probe ~proj:(fun (f : Fc.faulted) -> f.drops));
  Alcotest.(check int) "L2x: family violations = 0 (clean under a REAL drop)" 0
    (family_violations probe);
  Alcotest.(check int) "L2x: no crash taken (dimension isolated)" 0
    (max_over probe ~proj:(fun (f : Fc.faulted) -> f.crashes));
  Alcotest.(check int) "L2x: no monkey taken (dimension isolated)" 0
    (max_over probe ~proj:(fun (f : Fc.faulted) -> f.monkeys));
  (* The flag-ON zero-budget control: clean, decisive, exercised - so the
     probe's cleanliness is not an artifact of the enabled flag itself. *)
  Alcotest.(check bool) "L2x control: frontier emptied" true
    (Mc.frontier_emptied control);
  Alcotest.(check int) "L2x control: family violations = 0" 0
    (family_violations control);
  Alcotest.(check int) "L2x control: states (pinned)"
    P15_witness.l2x_control_states (Mc.states_seen control);
  Alcotest.(check int) "L2x control: union gate (pinned)"
    P15_witness.l2x_control_gate_states
    (union_gate control ~slice:all_states);
  Alcotest.(check int) "L2x control: R2 interesting (pinned)"
    P15_witness.r2_interesting_l2x_control
    (fires control ~slice:all_states r2);
  Alcotest.(check int) "L2x control: R3 interesting (pinned)"
    P15_witness.r3_interesting_l2x_control
    (fires control ~slice:all_states r3);
  Alcotest.(check int) "L2x control: R4 interesting (pinned)"
    P15_witness.r4_interesting_l2x_control
    (fires control ~slice:all_states r4);
  (* Exact MEASURED pins LAST: the probe graph and its per-member exercise,
     including the POST-DROP slice that makes the verdict non-vacuous per
     member. *)
  Alcotest.(check int) "L2x: states (pinned)" P15_witness.l2x_states
    (Mc.states_seen probe);
  Alcotest.(check int) "L2x: all-states union gate (pinned)"
    P15_witness.l2x_gate_states_all
    (union_gate probe ~slice:all_states);
  Alcotest.(check int) "L2x: max in-flight cardinal (pinned)"
    P15_witness.l2x_max_in_flight_seen (max_in_flight probe);
  Alcotest.(check int) "L2x: R1 interesting (pinned zero, structural)"
    P15_witness.r1_interesting_l2x
    (fires probe ~slice:all_states r1);
  Alcotest.(check int) "L2x: R2 interesting (pinned)"
    P15_witness.r2_interesting_l2x
    (fires probe ~slice:all_states r2);
  Alcotest.(check int) "L2x: R3 interesting (pinned)"
    P15_witness.r3_interesting_l2x
    (fires probe ~slice:all_states r3);
  Alcotest.(check int) "L2x: R4 interesting (pinned)"
    P15_witness.r4_interesting_l2x
    (fires probe ~slice:all_states r4);
  Alcotest.(check int) "L2x: R1 post-drop interesting (pinned zero)"
    P15_witness.r1_interesting_l2x_post_drop
    (fires probe ~slice:post_drop r1);
  Alcotest.(check int) "L2x: R2 post-drop interesting (pinned)"
    P15_witness.r2_interesting_l2x_post_drop
    (fires probe ~slice:post_drop r2);
  Alcotest.(check int) "L2x: R3 post-drop interesting (pinned)"
    P15_witness.r3_interesting_l2x_post_drop
    (fires probe ~slice:post_drop r3);
  Alcotest.(check int) "L2x: R4 post-drop interesting (pinned)"
    P15_witness.r4_interesting_l2x_post_drop
    (fires probe ~slice:post_drop r4)

let test_l3x_monkey_probe () =
  let l3x_seed =
    Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
      ~pod_monkey:true ()
  in
  let probe = reach_of ~from:l3x_seed P15_witness.l3_budget in
  let control = reach_of ~from:l3x_seed P15_witness.zero_budget in
  (* SEMANTIC first: decisive, the monkey edge REALLY taken, family clean
     everywhere. With the §8.3 qualifier: pod_monkey_disabled
     measured-unnecessary-in-this-model for R2/R3/R4. *)
  Alcotest.(check bool) "L3x: frontier emptied (decisive)" true
    (Mc.frontier_emptied probe);
  Alcotest.(check int)
    "L3x: max monkeys over the graph = 1 (the monkey edge WAS taken)"
    P15_witness.l3x_max_monkeys_seen
    (max_over probe ~proj:(fun (f : Fc.faulted) -> f.monkeys));
  Alcotest.(check int)
    "L3x: family violations = 0 (clean under a REAL monkey op)" 0
    (family_violations probe);
  Alcotest.(check int) "L3x: no crash taken (dimension isolated)" 0
    (max_over probe ~proj:(fun (f : Fc.faulted) -> f.crashes));
  Alcotest.(check int) "L3x: no drop taken (dimension isolated)" 0
    (max_over probe ~proj:(fun (f : Fc.faulted) -> f.drops));
  (* The flag-ON zero-budget control. Its gate and per-member counts were NOT
     measured (P15_witness discloses the gap), so only the measured facts are
     asserted: size, cleanliness, decisiveness. *)
  Alcotest.(check bool) "L3x control: frontier emptied" true
    (Mc.frontier_emptied control);
  Alcotest.(check int) "L3x control: family violations = 0" 0
    (family_violations control);
  Alcotest.(check int) "L3x control: states (pinned)"
    P15_witness.l3x_control_states (Mc.states_seen control);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L3x: states (pinned)" P15_witness.l3x_states
    (Mc.states_seen probe);
  Alcotest.(check int) "L3x: all-states union gate (pinned)"
    P15_witness.l3x_gate_states_all
    (union_gate probe ~slice:all_states);
  Alcotest.(check int) "L3x: max in-flight cardinal (pinned)"
    P15_witness.l3x_max_in_flight_seen (max_in_flight probe);
  Alcotest.(check int) "L3x: R1 interesting (pinned zero, structural)"
    P15_witness.r1_interesting_l3x
    (fires probe ~slice:all_states r1);
  Alcotest.(check int) "L3x: R2 interesting (pinned)"
    P15_witness.r2_interesting_l3x
    (fires probe ~slice:all_states r2);
  Alcotest.(check int) "L3x: R3 interesting (pinned)"
    P15_witness.r3_interesting_l3x
    (fires probe ~slice:all_states r3);
  Alcotest.(check int) "L3x: R4 interesting (pinned)"
    P15_witness.r4_interesting_l3x
    (fires probe ~slice:all_states r4);
  Alcotest.(check int) "L3x: R1 post-monkey interesting (pinned zero)"
    P15_witness.r1_interesting_l3x_post_monkey
    (fires probe ~slice:post_monkey r1);
  Alcotest.(check int) "L3x: R2 post-monkey interesting (pinned)"
    P15_witness.r2_interesting_l3x_post_monkey
    (fires probe ~slice:post_monkey r2);
  Alcotest.(check int) "L3x: R3 post-monkey interesting (pinned)"
    P15_witness.r3_interesting_l3x_post_monkey
    (fires probe ~slice:post_monkey r3);
  Alcotest.(check int) "L3x: R4 post-monkey interesting (pinned)"
    P15_witness.r4_interesting_l3x_post_monkey
    (fires probe ~slice:post_monkey r4)

let () =
  Alcotest.run "p15_reconcile_correspondence"
    [
      ( "l0_control",
        [
          Alcotest.test_case
            "L0: family clean + decisive with all three premises held" `Quick
            test_l0_control;
          Alcotest.test_case
            "L0: per-member exercise (R2-R4 fire; R1 structurally 0)" `Quick
            test_l0_members;
        ] );
      ( "l1_crash_disabled",
        [
          Alcotest.test_case
            "L1: clean + decisive ACROSS a real crash (P15-A confirmed)" `Quick
            test_l1_crash_leg;
          Alcotest.test_case
            "L1: per-member post-crash exercise (non-vacuous per member)"
            `Quick test_l1_members;
        ] );
      ( "l2_req_drop_disabled",
        [
          Alcotest.test_case
            "L2: VACUOUS at the leg (drop edge never enabled) - asserted"
            `Quick test_l2_drop_leg_vacuous;
        ] );
      ( "l3_pod_monkey_disabled",
        [
          Alcotest.test_case
            "L3: VACUOUS at the leg (monkey edge never enabled) - asserted"
            `Quick test_l3_monkey_leg_vacuous;
        ] );
      ( "l4_all_faults",
        [
          Alcotest.test_case
            "L4: re-measures L1; drop/monkey dimensions vacuous at the leg"
            `Quick test_l4_all_faults;
        ] );
      ( "side_condition",
        [
          Alcotest.test_case
            "R2/R4 instantiations VALIDATED over the legs' reachable triples"
            `Quick test_side_condition;
        ] );
      ( "r1_structural_zero",
        [
          Alcotest.test_case
            "R1's desired=1 zero survives the binding-ceiling sweep" `Quick
            test_r1_ceiling_sweep;
          Alcotest.test_case
            "R1 non-vacuous and clean on P12's multi-CR shape; desired=2 \
             still one key"
            `Quick test_r1_desired_two_and_multi_cr;
        ] );
      ( "premise_probes",
        [
          Alcotest.test_case
            "L2x: req_drop premise measured with the drop edge REALLY taken \
             (P15-C)"
            `Quick test_l2x_drop_probe;
          Alcotest.test_case
            "L3x: pod_monkey premise measured with the monkey edge REALLY \
             taken"
            `Quick test_l3x_monkey_probe;
        ] );
    ]

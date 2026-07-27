(* BUILD-SPEC-P14 §4.4 / §4.5 - the two shipped legs of the ID-LEVEL
   correspondence family ({!Anvil_assurance.Correspondence}, the five
   [kubernetes_cluster/proof/network.rs] StatePreds), plus the PER-MEMBER
   non-vacuity counts and the robustness witness.

   WHAT THIS EXE ESTABLISHES. P13 closed with an honest negative: mutating the
   crash transition refuted NOTHING, because no shipped invariant reads a
   message. These two legs are the first decisive verdicts in this port in which
   an invariant that READS [s.network.in_flight] is checked across a real
   [Step.Restart_controller_step] edge:

     G1  crash-DISABLED (all three budget caps 0): the family is clean and
         decisive over the 76-state fault-free graph, and FOUR of its five
         members are genuinely exercised there;
     G2  crash-ENABLED ([budget_crash_only]): the family is clean and decisive
         over the 464-state product graph, with 296 gate states that are BOTH
         post-crash AND exercising a member, and ALL FIVE members exercised.

   Both legs seed [~crash:true] and differ ONLY in [budget.max_crashes], so they
   are one experiment with one variable, not two experiments.

   THE FINDING THIS EXE PINS (and does not paper over). N5's [interesting]
   ([cardinal (in_flight s) >= 2]) fires at ZERO of G1's 76 crash-free states and
   at 84 of G2's states, ALL 84 of them post-crash. So §4.4's claim that G1
   "establishes the family is non-vacuous before any crash" is true for N1-N4 and
   FALSE for N5: fault-free this scenario is strict request/response lock-step, so
   at most one message is ever in flight, and the crash edge is the ONLY source of
   two concurrent in-flight messages in this bounded graph. It is not a
   [max_in_flight] artifact (the ceiling is 8). See {!P14_witness.n5_interesting_g1}
   for the full disclosure. This strengthens rather than weakens the phase: N5 is
   the only member that can see an rpc-id COLLISION, and the crash is the only
   thing that creates the two-message state in which a collision is possible -
   which is exactly why mutant MA (allocator reset on restart) bites.

   TEST-ORDERING RULE (§3 trap 1, inherited from P12 finding 1 and P13). Every
   test asserts the SEMANTIC facts FIRST - outcome clean, [violated = None],
   decisive, gate > 0 - and only THEN the brittle exact counts. Alcotest halts at
   the first failing check, so a mutant that shifts a pinned count must not be
   able to redden the exe BEFORE the load-bearing semantic assertion runs; that is
   precisely how P12 shipped its Refuted path with zero observed-red coverage.

   Every pinned number comes from {!P14_witness} (single source of truth); none is
   re-typed here.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches (both [Mc.outcome] arms named), no [List.nth/hd/tl], no
   [raise/assert/failwith/Option.get], Alcotest as the sanctioned failure
   primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Correspondence = Anvil_assurance.Correspondence

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P14_witness.witness_desired
let depth : int = P14_witness.witness_depth
let bound : Bound.t = P14_witness.p14_bound ~desireds:[ desired ]

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) --------- *)

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

(* ==== the two shipped legs (lazy: the cheap per-member counts and the
   discriminators must not pay for an exploration they do not use) ============ *)

let g1_report : Fc.fault_report Lazy.t =
  lazy
    (Fc.check_correspondence_under_faults ~depth bound P14_witness.zero_budget
       ~desired ~require_crash:false)

let g2_report : Fc.fault_report Lazy.t =
  lazy
    (Fc.check_correspondence_under_faults ~depth bound P14_witness.witness_budget
       ~desired ~require_crash:true)

(* ==== a LOCAL replica of each leg's product graph =========================== *)

(* The per-member counts need the reachable set itself, which [fault_report] does
   not carry (it exposes only the leg's own union gate). This rebuilds the SAME
   graph from the SAME seed / bound / budget / depth via the exported
   {!Fc.faulted_successors}. That the replica matches is not assumed: every
   per-member test asserts [Mc.states_seen] against the leg's own [states] first
   (the P13 M3/M5 precedent - a local gate replica that drifted from the checker's
   would silently measure a different graph). *)

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false

let reach_of (budget : Fc.budget) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed seed ]

let g1_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of P14_witness.zero_budget)

let g2_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of P14_witness.witness_budget)

(* [interesting]-fires count for ONE member, over all states or over the
   post-crash slice only. *)
let fires (reach : Fc.faulted Mc.reachable) ~(post_crash : bool)
    (i : Invariants.invariant) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      ((not post_crash) || f.crashes >= 1) && i.interesting f.cs)

(* The five members, individually, exactly as {!Correspondence} exports them -
   the per-member exports are what make this test possible at all, since the
   conjunction's gate is a UNION and four dead members plus one live one look
   exactly like five live ones. *)

let n1 : Invariants.invariant = Correspondence.in_flight_lower_than_allocator

let n2 : Invariants.invariant =
  Correspondence.pending_req_lower_than_allocator ~controller_id

let n3 : Invariants.invariant =
  Correspondence.in_flight_req_id_differs_from_pending ~controller_id

let n4 : Invariants.invariant =
  Correspondence.in_flight_req_from_controller_valid_id cluster

let n5 : Invariants.invariant = Correspondence.in_flight_unique_id

(* ==== the shared fault-dimension semantics ================================== *)

(* What makes a clean verdict mean anything at all, asserted BEFORE any count.
   [fault_free_states > 0] is the contrast partner of [crash_witness_states]; the
   strict [< ceiling] checks are the BUILD-SPEC-P8 §4 interpretability condition
   without which a bounded verdict cannot be read. *)
let check_leg_semantics (label : string) (r : Fc.fault_report) : unit =
  Alcotest.(check bool) (label ^ ": outcome clean (no counterexample)") true
    (is_clean r);
  Alcotest.(check bool) (label ^ ": violated = None") true
    (Option.is_none r.violated);
  Alcotest.(check bool) (label ^ ": outcome decisive (frontier emptied)") true
    (decisive r);
  Alcotest.(check bool)
    (label ^ ": gate_states positive (the leg is NOT vacuous)") true
    (gate_of r > 0);
  Alcotest.(check bool) (label ^ ": fault_free_states positive") true
    (r.fault_free_states > 0);
  Alcotest.(check int) (label ^ ": max_drops_seen = 0 (drops budgeted out)") 0
    r.max_drops_seen;
  Alcotest.(check int) (label ^ ": max_monkeys_seen = 0 (monkey budgeted out)") 0
    r.max_monkeys_seen;
  Alcotest.(check bool)
    (label ^ ": max_uid_seen STRICTLY below uid_ceiling (interpretable)") true
    (r.max_uid_seen < r.bound.uid_ceiling);
  Alcotest.(check bool)
    (label ^ ": max_rv_seen STRICTLY below rv_ceiling (interpretable)") true
    (r.max_rv_seen < r.bound.rv_ceiling);
  Alcotest.(check bool)
    (label ^ ": max_crashes_seen within budget (budget pruning is sound)") true
    (r.max_crashes_seen <= r.budget.max_crashes)

(* ==== G1: crash-DISABLED ==================================================== *)

let test_g1_crash_disabled () =
  let r = Lazy.force g1_report in
  check_leg_semantics "G1" r;
  (* The crash dimension really is clipped: the flag is ON in the seed but the
     budget admits no crash edge, so the post-crash slice is EMPTY. This is what
     separates G1 from G2 - one variable. *)
  Alcotest.(check int) "G1: max_crashes_seen = 0 (budget clips every crash edge)"
    0 r.max_crashes_seen;
  Alcotest.(check int) "G1: crash_witness_states = 0 (crash-free graph)" 0
    r.crash_witness_states;
  Alcotest.(check bool) "G1: states = fault_free_states (the graph IS the \
                         fault-free slice)" true
    (states_of r = r.fault_free_states);
  Alcotest.(check bool) "G1: pruned_by_ceiling (disclosed)" true
    r.pruned_by_ceiling;
  Alcotest.(check bool) "G1: pruned_by_budget (every crash edge clipped)" true
    r.pruned_by_budget;
  (* The §4.5 IDENTITY, ASSERTED rather than assumed by derivation: the product
     graph depends only on (seed, bound, budget, depth), so with all caps 0 it is
     precisely the fault-free slice of P13's G1 graph. *)
  Alcotest.(check int)
    "G1: states = P13's G1 fault_free_states (same seed/bound/depth, all caps 0)"
    P13_witness.g1_fault_free_states (states_of r);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "G1: states (pinned)" P14_witness.g1_states (states_of r);
  Alcotest.(check int) "G1: gate_states (pinned)" P14_witness.g1_gate_states
    (gate_of r);
  Alcotest.(check int) "G1: crash_witness_states (pinned)"
    P14_witness.g1_crash_witness_states r.crash_witness_states;
  Alcotest.(check int) "G1: fault_free_states (pinned)"
    P14_witness.g1_fault_free_states r.fault_free_states;
  Alcotest.(check int) "G1: max_uid_seen (pinned)" P14_witness.g1_max_uid_seen
    r.max_uid_seen;
  Alcotest.(check int) "G1: max_rv_seen (pinned)" P14_witness.g1_max_rv_seen
    r.max_rv_seen;
  Alcotest.(check int) "G1: max_crashes_seen (pinned)"
    P14_witness.g1_max_crashes_seen r.max_crashes_seen

(* ==== G2: crash-ENABLED - the headline ====================================== *)

let test_g2_crash_enabled () =
  let r = Lazy.force g2_report in
  check_leg_semantics "G2" r;
  (* The non-vacuity core: the crash edge was REALLY taken, and the gate counts
     only states reached through one ([require_crash = true]). *)
  Alcotest.(check bool) "G2: max_crashes_seen >= 1 (a REAL crash occurred)" true
    (r.max_crashes_seen >= 1);
  Alcotest.(check bool)
    "G2: crash_witness_states positive (post-crash slice non-empty)" true
    (r.crash_witness_states > 0);
  Alcotest.(check bool)
    "G2: gate_states <= crash_witness_states (the gate is INSIDE the post-crash \
     slice, so it is crash evidence)"
    true
    (gate_of r <= r.crash_witness_states);
  (* The crash dimension is ISOLATED: no other adversary contributed, so a
     verdict here is attributable to the crash edge. *)
  Alcotest.(check bool) "G2: pruned_by_ceiling (disclosed)" true
    r.pruned_by_ceiling;
  Alcotest.(check bool) "G2: pruned_by_budget (the 2nd crash edge is clipped)"
    true r.pruned_by_budget;
  (* G1/G2 CONTRAST, semantic: the one changed variable moved the graph. *)
  Alcotest.(check bool)
    "G2: strictly more states than G1 (the crash budget is load-bearing)" true
    (states_of r > states_of (Lazy.force g1_report));
  Alcotest.(check bool)
    "G2: strictly more gate states than G1 (post-crash exercise is NEW evidence)"
    true
    (gate_of r > gate_of (Lazy.force g1_report));
  (* The §4.5 IDENTITY: same seed / bound / budget / depth as P13's G1 leg, so
     the reachable product set is literally P13's. Only the invariant differs. *)
  Alcotest.(check int)
    "G2: states = P13's G1 states (identical product graph, different invariant)"
    P13_witness.g1_states (states_of r);
  Alcotest.(check int) "G2: crash_witness_states = P13's G1 crash_witness_states"
    P13_witness.g1_crash_witness_states r.crash_witness_states;
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "G2: states (pinned)" P14_witness.g2_states (states_of r);
  Alcotest.(check int) "G2: gate_states (pinned)" P14_witness.g2_gate_states
    (gate_of r);
  Alcotest.(check int) "G2: crash_witness_states (pinned)"
    P14_witness.g2_crash_witness_states r.crash_witness_states;
  Alcotest.(check int) "G2: fault_free_states (pinned)"
    P14_witness.g2_fault_free_states r.fault_free_states;
  Alcotest.(check int) "G2: max_uid_seen (pinned)" P14_witness.g2_max_uid_seen
    r.max_uid_seen;
  Alcotest.(check int) "G2: max_rv_seen (pinned)" P14_witness.g2_max_rv_seen
    r.max_rv_seen;
  Alcotest.(check int) "G2: max_crashes_seen (pinned)"
    P14_witness.g2_max_crashes_seen r.max_crashes_seen

(* ==== per-member [interesting]-fires counts ================================= *)

(* G1's crash-free graph. N1-N4 fire; N5 does NOT - the disclosed finding. The
   ZERO is asserted here as a MEASURED fact with its reason, not deleted: an
   assertion silently dropped because it failed is the vacuity this project has
   already been bitten by ([[feedback-workflow-zero-findings-may-be-vacuous]]). *)
let test_per_member_interesting_g1 () =
  let reach = Lazy.force g1_reach in
  let r = Lazy.force g1_report in
  (* The local replica really is the leg's graph. *)
  Alcotest.(check int)
    "G1: local replica graph size = the leg's own states (replica is faithful)"
    (states_of r) (Mc.states_seen reach);
  let count (i : Invariants.invariant) = fires reach ~post_crash:false i in
  (* SEMANTIC first: the four members that DO fire, fire. *)
  Alcotest.(check bool) "G1: N1 interesting fires (> 0)" true (count n1 > 0);
  Alcotest.(check bool) "G1: N2 interesting fires (> 0)" true (count n2 > 0);
  Alcotest.(check bool) "G1: N3 interesting fires (> 0)" true (count n3 > 0);
  Alcotest.(check bool) "G1: N4 interesting fires (> 0)" true (count n4 > 0);
  (* THE FINDING, asserted rather than assumed: N5 is VACUOUS on the crash-free
     graph. Fault-free this scenario is strict request/response lock-step, so
     [cardinal (in_flight s) >= 2] is unreachable. NOT a max_in_flight artifact -
     the assertion below pins a >= 4 FLOOR on that ceiling (twice what N5's
     [>= 2] premise needs), so a future retune cannot quietly re-explain this
     zero as a ceiling clip. CORRECTED (review): the comment used to say the
     assertion "pins that it is 8"; it pins a floor, not the literal. The
     stronger evidence lives in the reconcile_ceiling sweep, which varies the
     ceiling that actually BINDS and measures the in-flight peak at 1
     throughout. *)
  Alcotest.(check bool)
    "G1: max_in_flight ceiling is >= 2x the 2 messages N5 needs (so the zero \
     below is NOT a ceiling artifact)"
    true
    (bound.Bound.max_in_flight >= 4);
  Alcotest.(check int)
    "G1: N5 interesting fires NOWHERE on the crash-free graph (MEASURED \
     vacuity - see P14_witness.n5_interesting_g1)"
    0 (count n5);
  (* The leg's union gate is exactly N1's set here (MEASURED): N1's
     [cardinal >= 1] premise subsumes every other member's. *)
  Alcotest.(check int)
    "G1: gate_states = N1's interesting count (the union IS N1's set)"
    (count n1) (gate_of r);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "G1: N1 interesting count (pinned)"
    P14_witness.n1_interesting_g1 (count n1);
  Alcotest.(check int) "G1: N2 interesting count (pinned)"
    P14_witness.n2_interesting_g1 (count n2);
  Alcotest.(check int) "G1: N3 interesting count (pinned)"
    P14_witness.n3_interesting_g1 (count n3);
  Alcotest.(check int) "G1: N4 interesting count (pinned)"
    P14_witness.n4_interesting_g1 (count n4);
  Alcotest.(check int) "G1: N5 interesting count (pinned ZERO)"
    P14_witness.n5_interesting_g1 (count n5)

(* G2's crash-enabled graph. ALL FIVE fire, and each fires at post-crash states -
   which is the per-member form of the crash-tolerance claim. *)
let test_per_member_interesting_g2 () =
  let reach = Lazy.force g2_reach in
  let r = Lazy.force g2_report in
  Alcotest.(check int)
    "G2: local replica graph size = the leg's own states (replica is faithful)"
    (states_of r) (Mc.states_seen reach);
  let all (i : Invariants.invariant) = fires reach ~post_crash:false i in
  let post (i : Invariants.invariant) = fires reach ~post_crash:true i in
  (* SEMANTIC first: every member is exercised, and exercised POST-CRASH. *)
  Alcotest.(check bool) "G2: N1 interesting fires (> 0)" true (all n1 > 0);
  Alcotest.(check bool) "G2: N2 interesting fires (> 0)" true (all n2 > 0);
  Alcotest.(check bool) "G2: N3 interesting fires (> 0)" true (all n3 > 0);
  Alcotest.(check bool) "G2: N4 interesting fires (> 0)" true (all n4 > 0);
  Alcotest.(check bool)
    "G2: N5 interesting fires (> 0) - the crash makes the member G1 could not \
     exercise non-vacuous"
    true (all n5 > 0);
  Alcotest.(check bool) "G2: N1 fires POST-CRASH (> 0)" true (post n1 > 0);
  Alcotest.(check bool) "G2: N2 fires POST-CRASH (> 0)" true (post n2 > 0);
  Alcotest.(check bool) "G2: N3 fires POST-CRASH (> 0)" true (post n3 > 0);
  Alcotest.(check bool) "G2: N4 fires POST-CRASH (> 0)" true (post n4 > 0);
  Alcotest.(check bool) "G2: N5 fires POST-CRASH (> 0)" true (post n5 > 0);
  (* THE MECHANISM, measured: EVERY state exercising N5 is post-crash. The crash
     edge is the only source of two concurrently in-flight messages here - it
     orphans the pre-crash request (restart_controller empties
     ongoing_reconciles but not s.network) and the orphan has no consumer. This
     is also why N5 is the member an allocator-reset mutant can collide. *)
  Alcotest.(check int)
    "G2: N5's interesting set is ENTIRELY post-crash (all = post_crash) - the \
     crash is the ONLY source of 2 concurrent in-flight messages"
    (all n5) (post n5);
  (* The contrast with G1 that makes the finding a finding rather than a typo. *)
  Alcotest.(check bool)
    "G2: N5 fires here but NOWHERE in G1 (the crash budget is what makes N5 \
     non-vacuous)"
    true
    (all n5 > 0 && P14_witness.n5_interesting_g1 = 0);
  (* The leg's union gate is exactly N1's post-crash set (MEASURED). *)
  Alcotest.(check int)
    "G2: gate_states = N1's post-crash interesting count (the union IS N1's set)"
    (post n1) (gate_of r);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "G2: N1 interesting count (pinned)"
    P14_witness.n1_interesting_g2 (all n1);
  Alcotest.(check int) "G2: N2 interesting count (pinned)"
    P14_witness.n2_interesting_g2 (all n2);
  Alcotest.(check int) "G2: N3 interesting count (pinned)"
    P14_witness.n3_interesting_g2 (all n3);
  Alcotest.(check int) "G2: N4 interesting count (pinned)"
    P14_witness.n4_interesting_g2 (all n4);
  Alcotest.(check int) "G2: N5 interesting count (pinned)"
    P14_witness.n5_interesting_g2 (all n5);
  Alcotest.(check int) "G2: N1 post-crash interesting count (pinned)"
    P14_witness.n1_interesting_g2_post_crash (post n1);
  Alcotest.(check int) "G2: N2 post-crash interesting count (pinned)"
    P14_witness.n2_interesting_g2_post_crash (post n2);
  Alcotest.(check int) "G2: N3 post-crash interesting count (pinned)"
    P14_witness.n3_interesting_g2_post_crash (post n3);
  Alcotest.(check int) "G2: N4 post-crash interesting count (pinned)"
    P14_witness.n4_interesting_g2_post_crash (post n4);
  Alcotest.(check int) "G2: N5 post-crash interesting count (pinned)"
    P14_witness.n5_interesting_g2_post_crash (post n5)

(* ==== robustness: the uid / rv ceilings do NOT bind at the witness ========== *)

(* MEASURED max_uid 3 < 6 and max_rv 2 < 6, so RAISING both must leave the
   reachable product graph - hence every count - unchanged.

   HONEST LABEL (review finding F6). This row is a REGRESSION GUARD, not
   evidence. It varies the two ceilings the SAME report says were never reached,
   so its invariance is guaranteed a priori: a ceiling that never clipped
   anything cannot change anything when it is raised. It is retained because a
   FUTURE retune that made uid or rv binding would redden it, which is worth
   catching - but the anti-artifact argument the phase actually needs is the
   BINDING-ceiling sweep in [test_reconcile_ceiling_sweep] below, which varies
   [reconcile_ceiling], the ceiling that really does prune here.

   SELF-CONTAINED FLOOR (P12 review NIT-3, restated by §4.5): the first two
   checks assert [gate > 0] OUTRIGHT on BOTH runs. Without them every relative
   comparison below is satisfied by a degenerate always-0 (empty-graph) gate and
   the whole test passes vacuously - a previous phase shipped exactly that. *)
let test_robustness_raised_ceilings () =
  let r0 = Lazy.force g2_report in
  let raised =
    {
      bound with
      Bound.uid_ceiling = bound.Bound.uid_ceiling + 3;
      rv_ceiling = bound.Bound.rv_ceiling + 3;
    }
  in
  let r1 =
    Fc.check_correspondence_under_faults ~depth raised P14_witness.witness_budget
      ~desired ~require_crash:true
  in
  (* SELF-CONTAINED FLOORS first: both gates are positive on their own terms. *)
  Alcotest.(check bool)
    "robustness: BASE gate is positive (SELF-CONTAINED floor, not a relative \
     comparison)"
    true (gate_of r0 > 0);
  Alcotest.(check bool)
    "robustness: RAISED gate is positive (SELF-CONTAINED floor)" true
    (gate_of r1 > 0);
  (* Then the semantics of the raised-ceiling leg on its own terms. *)
  Alcotest.(check bool) "robustness: raised-ceiling leg is clean" true
    (is_clean r1);
  Alcotest.(check bool) "robustness: raised-ceiling leg has violated = None" true
    (Option.is_none r1.violated);
  Alcotest.(check bool) "robustness: raised-ceiling leg is decisive" true
    (decisive r1);
  Alcotest.(check bool)
    "robustness: raised-ceiling leg still took a REAL crash" true
    (r1.max_crashes_seen >= 1);
  Alcotest.(check bool)
    "robustness: raised ceilings are still STRICTLY above the achieved maxima"
    true
    (r1.max_uid_seen < raised.Bound.uid_ceiling
    && r1.max_rv_seen < raised.Bound.rv_ceiling);
  (* Then the invariance itself. *)
  Alcotest.(check bool) "robustness: raised gate does not shrink" true
    (gate_of r1 >= gate_of r0);
  Alcotest.(check int)
    "robustness: gate_states IDENTICAL (uid/rv are not the binding ceilings)"
    (gate_of r0) (gate_of r1);
  Alcotest.(check int) "robustness: states IDENTICAL" (states_of r0)
    (states_of r1);
  Alcotest.(check int) "robustness: crash_witness_states unchanged"
    r0.crash_witness_states r1.crash_witness_states;
  Alcotest.(check int) "robustness: fault_free_states unchanged"
    r0.fault_free_states r1.fault_free_states;
  Alcotest.(check int) "robustness: max_uid_seen unchanged" r0.max_uid_seen
    r1.max_uid_seen;
  Alcotest.(check int) "robustness: max_rv_seen unchanged" r0.max_rv_seen
    r1.max_rv_seen

(* ==== the BINDING ceiling: N5's G1 zero survives raising it (finding F6) ====

   WHY THIS EXISTS. The phase's second headline is "N5 is vacuous on the
   crash-free graph, and that is NOT a ceiling artifact". That claim used to be
   argued only against [max_in_flight = 8] - provably non-binding, since the
   graph never holds more than one message - while the G1 report's own
   [pruned_by_ceiling = true] can only come from [reconcile_ceiling = 2], which
   nothing varied. So the ONE ceiling that actually clips this run was the one
   ceiling never tested, and if raising it turned N5's zero into a positive count
   the headline would be wrong.

   MEASURED, and it does not: re-running the G1 leg at [reconcile_ceiling] 3 and
   6 GROWS the graph (76 -> 112 -> 220 states) and the gate (32 -> 48 -> 96),
   both raised runs stay clean and DECISIVE, and N5's [interesting] count stays
   0 at both. Stronger than the count, and the real reason: the LARGEST
   [Message.Pool.cardinal (Cluster.in_flight s)] over the whole crash-free graph
   is 1 at every ceiling, so N5's [>= 2] premise is structurally unreachable
   fault-free rather than merely unreached at this bound. The growth assertions
   are what make this evidence rather than another a-priori invariance: they
   prove the varied ceiling really binds.

   DISCLOSED: the high leg needs a raised DEPTH. At [reconcile_ceiling = 4] with
   the shipped [depth = 40] the run is NOT decisive and [pruned_by_ceiling] flips
   to false - depth becomes the binding limit before the ceiling does - so the
   high run is made at {!P14_witness.rc_sweep_high_depth}. *)

let g1_at (rc : int) ~(depth : int) : Fc.fault_report =
  Fc.check_correspondence_under_faults ~depth
    { bound with Bound.reconcile_ceiling = rc }
    P14_witness.zero_budget ~desired ~require_crash:false

let g1_reach_at (rc : int) ~(depth : int) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:
      (Fc.faulted_successors
         { bound with Bound.reconcile_ceiling = rc }
         P14_witness.zero_budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed seed ]

(* The largest number of in-flight message OCCURRENCES at any state of a graph.
   N5's premise is [>= 2], so this is the quantity that decides whether N5 can
   fire at all - a count of 1 is a structural statement, not a budget one. *)
let max_in_flight (reach : Fc.faulted Mc.reachable) : int =
  Mc.fold_states reach ~init:0 ~f:(fun (acc : int) (f : Fc.faulted) ->
      max acc (Message.Pool.cardinal (Cluster.in_flight f.cs)))

let test_reconcile_ceiling_sweep () =
  let base_reach = Lazy.force g1_reach in
  let r0 = Lazy.force g1_report in
  let rc_low = P14_witness.rc_sweep_low in
  let rc_high = P14_witness.rc_sweep_high in
  let r_low = g1_at rc_low ~depth in
  let r_high = g1_at rc_high ~depth:P14_witness.rc_sweep_high_depth in
  let reach_low = g1_reach_at rc_low ~depth in
  let reach_high = g1_reach_at rc_high ~depth:P14_witness.rc_sweep_high_depth in
  (* THE SWEPT CEILING REALLY IS HIGHER than the shipped one, and the shipped one
     really is the one that PRUNES - without both, everything below is an
     a-priori invariance like the uid/rv row above. *)
  Alcotest.(check bool)
    "sweep: the raised reconcile ceilings are strictly above the shipped one"
    true
    (rc_low > bound.Bound.reconcile_ceiling && rc_high > rc_low);
  Alcotest.(check bool)
    "sweep: the SHIPPED G1 run reports pruned_by_ceiling (some ceiling really \
     clips it)"
    true r0.pruned_by_ceiling;
  (* AND IT BINDS: raising it GROWS the graph and the gate. This is what the
     uid/rv row could not say about itself. *)
  Alcotest.(check bool)
    "sweep: raising reconcile_ceiling GROWS the crash-free graph (the ceiling \
     BINDS - unlike uid/rv)"
    true
    (states_of r_low > states_of r0 && states_of r_high > states_of r_low);
  Alcotest.(check bool) "sweep: and GROWS the gate" true
    (gate_of r_low > gate_of r0 && gate_of r_high > gate_of r_low);
  (* Both raised legs are readable on their own terms. *)
  Alcotest.(check bool) "sweep: the rc-low leg is clean" true (is_clean r_low);
  Alcotest.(check bool) "sweep: the rc-low leg is decisive" true (decisive r_low);
  Alcotest.(check bool) "sweep: the rc-high leg is clean" true (is_clean r_high);
  Alcotest.(check bool) "sweep: the rc-high leg is decisive" true
    (decisive r_high);
  Alcotest.(check bool) "sweep: both raised legs have violated = None" true
    (Option.is_none r_low.violated && Option.is_none r_high.violated);
  Alcotest.(check bool) "sweep: both raised gates are positive (not vacuous)"
    true
    (gate_of r_low > 0 && gate_of r_high > 0);
  (* The local replicas are the legs' own graphs, so the N5 counts below are
     counted over what the legs actually explored. *)
  Alcotest.(check int) "sweep: rc-low replica = the rc-low leg's states"
    (states_of r_low) (Mc.states_seen reach_low);
  Alcotest.(check int) "sweep: rc-high replica = the rc-high leg's states"
    (states_of r_high) (Mc.states_seen reach_high);
  (* THE ANTI-ARTIFACT EVIDENCE: N5's crash-free count is STILL 0 at both raised
     ceilings. Had it become positive, N5's vacuity would have been a bound
     artifact and the phase's second headline would be WRONG. *)
  Alcotest.(check int)
    "sweep: N5's interesting count is STILL 0 at the raised reconcile ceiling \
     (its G1 vacuity is NOT a ceiling artifact)"
    P14_witness.n5_interesting_g1_raised_ceiling
    (fires reach_low ~post_crash:false n5);
  Alcotest.(check int)
    "sweep: and STILL 0 at the higher one"
    P14_witness.n5_interesting_g1_raised_ceiling
    (fires reach_high ~post_crash:false n5);
  (* THE MECHANISM, which is stronger than the count: the crash-free graph never
     holds two messages at once at ANY of these ceilings, so N5's [>= 2] premise
     is structurally unreachable rather than merely unreached. *)
  Alcotest.(check int)
    "sweep: max in-flight OCCURRENCES on the shipped crash-free graph"
    P14_witness.g1_max_in_flight_seen (max_in_flight base_reach);
  Alcotest.(check int) "sweep: max in-flight unchanged at the raised ceiling"
    P14_witness.g1_max_in_flight_seen (max_in_flight reach_low);
  Alcotest.(check int) "sweep: max in-flight unchanged at the higher one"
    P14_witness.g1_max_in_flight_seen (max_in_flight reach_high);
  Alcotest.(check bool)
    "sweep: that maximum is BELOW the 2 occurrences N5's premise needs (which is \
     WHY the count is 0)"
    true
    (P14_witness.g1_max_in_flight_seen < 2);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "sweep: rc-low states (pinned)"
    P14_witness.g1_rc_low_states (states_of r_low);
  Alcotest.(check int) "sweep: rc-low gate_states (pinned)"
    P14_witness.g1_rc_low_gate_states (gate_of r_low);
  Alcotest.(check int) "sweep: rc-high states (pinned)"
    P14_witness.g1_rc_high_states (states_of r_high);
  Alcotest.(check int) "sweep: rc-high gate_states (pinned)"
    P14_witness.g1_rc_high_gate_states (gate_of r_high)

let () =
  Alcotest.run "p14_correspondence"
    [
      ( "g1_crash_disabled",
        [
          Alcotest.test_case
            "id-level family clean + decisive on the crash-FREE graph" `Quick
            test_g1_crash_disabled;
        ] );
      ( "g2_crash_enabled",
        [
          Alcotest.test_case
            "id-level family clean + decisive ACROSS a real controller crash"
            `Quick test_g2_crash_enabled;
        ] );
      ( "per_member_non_vacuity",
        [
          Alcotest.test_case
            "G1: N1-N4 exercised, N5 vacuous (MEASURED finding)" `Quick
            test_per_member_interesting_g1;
          Alcotest.test_case
            "G2: all five exercised, and N5 only ever post-crash" `Quick
            test_per_member_interesting_g2;
        ] );
      ( "robustness",
        [
          Alcotest.test_case
            "raising uid/rv ceilings moves nothing (regression guard)" `Quick
            test_robustness_raised_ceilings;
          Alcotest.test_case
            "raising the BINDING ceiling grows the graph and N5's G1 zero \
             survives"
            `Quick test_reconcile_ceiling_sweep;
        ] );
    ]

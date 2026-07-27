(* BUILD-SPEC-P15 §4.6: the SINGLE SOURCE OF TRUTH for the P15 reconcile-side
   correspondence witness - the bound, the shape, the five premise-matrix
   budgets, and every pinned MEASURED number of the L0..L4 legs, the
   side-condition verdict, the R1 structural-zero evidence and the two
   supplementary flag-enabled probes. A shared non-test module (not in the
   [dune] [(names ...)] list, so dune links it into every test exe), following
   the [p14_witness.ml] / [p13_witness.ml] / [p12_witness.ml] precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. [t_p15_reconcile_correspondence]
   reads every count from here and re-types none of them.
   ([lib/checker/fault_check.mli]'s prose disclosure of the same runs is
   documentation, not a second assertion site. [t_p15_regression] deliberately
   re-types P13's, P12's AND P14's committed literals - that duplication IS the
   firewall and is documented there.)

   RETUNE DISCLOSURE (BUILD-SPEC-P15 §5 directs a RE-measurement of
   [max_in_flight], not inheritance of P14's non-retune). {!p15_bound} is
   [P14_witness.p14_bound] UNCHANGED, itself [P13_witness.p13_bound] unchanged -
   P15 needed NO retune. MEASURED: the largest [Message.Pool.cardinal] is
   {!l0_max_in_flight_seen} = 1 on L0's crash-free graph and
   {!l1_max_in_flight_seen} = 2 on L1/L4's crash-enabled graph, against the
   ceiling 8 - the post-crash orphan inflation is real (1 -> 2) and nowhere near
   binding. Both crash legs close in < 0.1 s CPU against the ~150 s alarm.

   Firewall: List/Option/fold combinators only, no loop keywords, no wildcard
   match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

(* The P13 crash-only shape, unretuned through TWO phases now (see the
   disclosure above): [reconcile_ceiling = 2] on the P12 base. *)
let p15_bound ~(desireds : int list) : Bound.t = P14_witness.p14_bound ~desireds

(* The single-CR witness shape and depth, shared with P13 AND P14 so the three
   phases' legs explore the SAME product graph and cross-check on its counts
   rather than being unrelated experiments (BUILD-SPEC-P15 §4.4). *)
let witness_desired : int = P14_witness.witness_desired
let witness_depth : int = P14_witness.witness_depth

(* ==== the §4.5 premise-matrix budgets ======================================
   Five legs, identical except for the budget; each single-fault budget puts
   exactly ONE upstream fault-disabled premise under test:
     L0 zero      control  (all three premises held; family MUST be clean)
     L1 {1;0;0}   crash_disabled        (controller_runtime_safety.rs:414)
     L2 {0;1;0}   req_drop_disabled     (:415)
     L3 {0;0;1}   pod_monkey_disabled   (:416)
     L4 {1;1;1}   all three at once. *)

let zero_budget : Fc.budget = P14_witness.zero_budget
let l1_budget : Fc.budget = P14_witness.witness_budget
let l2_budget : Fc.budget = { Fc.max_crashes = 0; max_drops = 1; max_monkey_ops = 0 }
let l3_budget : Fc.budget = { Fc.max_crashes = 0; max_drops = 0; max_monkey_ops = 1 }
let l4_budget : Fc.budget = Fc.budget_default

(* ==== L0: zero-budget control (§4.5) ======================================= *)

(* [check_reconcile_correspondence_under_faults ~depth (p15_bound
   ~desireds:[witness_desired]) zero_budget ~desired:witness_desired
   ~require_crash:false]. MEASURED: [No_counterexample], decisive, both pruning
   flags true, 0.013 s CPU + 0.006 s replica. The family is clean with all
   three upstream premises held - the control every other leg is read against. *)

(* DERIVED, not re-typed - the same load-bearing IDENTITY P14's G1 used: the
   product graph depends only on (seed, bound, budget, depth), never on the
   invariant checked over it, and this leg uses P13's G1 seed, bound and depth
   exactly. With all three caps at 0 the graph IS the fault-free slice of P13's
   G1 graph: 76 states. The leg test ASSERTS the identity against the live run. *)
let l0_states : int = P13_witness.g1_fault_free_states
let l0_fault_free_states : int = P13_witness.g1_fault_free_states
let l0_crash_witness_states : int = P13_witness.m4_zero_budget_crash_witness_states

(* MEASURED 64, and MEASURED EQUAL to the replica's recomputed all-states union
   gate. Twice P14's 32 on the same 76-state graph: this family's R2/R3/R4
   premises are reconcile-shaped (they also fire at response-consumed states
   where P14's message-shaped premises do not). *)
let l0_gate_states : int = 64

(* Achieved maxima on the 76-state graph, pinned as literals exactly as P14
   pinned its G1 maxima: their equality with P13's is a scenario coincidence
   (the counters are driven by the fault-free prefix), not the graph identity
   above, so deriving them would assert something untrue. *)
let l0_max_uid_seen : int = 3
let l0_max_rv_seen : int = 2
let l0_max_crashes_seen : int = 0

(* MEASURED 1: the one reachable settled state still holding a live fault flag
   on the crash-free graph (a graph-only count, but no prior phase pinned the
   zero-budget value, so it is a literal). *)
let l0_settled_with_faults_live : int = 1

(* The §5 re-measurement, crash-free side: lock-step request/response traffic
   never holds two messages at once (P14 measured the same 1). *)
let l0_max_in_flight_seen : int = 1

(* -- per-member [interesting]-fires counts on L0's 76 states ----------------
   MEASURED over the leg's own replica, never predicted. R1's ZERO is
   STRUCTURAL, not a bound artifact: [ongoing_reconciles] is keyed by
   [object_ref], so a single-CR seed can never hold two concurrently-ongoing
   reconciles regardless of any ceiling - see the rc sweep and the multi-CR
   exercise below, which prove exactly that. *)
let r1_interesting_l0 : int = 0
let r2_interesting_l0 : int = 32
let r3_interesting_l0 : int = 32
let r4_interesting_l0 : int = 32

(* ==== L1: crash-only {1;0;0} - tests crash_disabled (crs.rs:414) =========== *)

(* [~require_crash:true]. MEASURED: [No_counterexample], decisive, both pruning
   flags true, crash edge REALLY taken, 0.077 s CPU + 0.053 s replica.
   PREDICTION P15-A CONFIRMED as a measured NEGATIVE result: the unmutated
   crash edge refutes NOTHING in this reconcile-guarded family; its only
   visible effect is on the gate counts (64 -> 368 all-states / 304
   post-crash). So crash_disabled is measured-unnecessary-IN-THIS-MODEL for
   R2/R3/R4 - with §8.3's mandatory qualifier: upstream's premise serves an
   UNBOUNDED inductive proof over an ARBITRARY reconciler, and a bounded
   single-scenario model failing to exhibit the excluded counterexample is weak
   evidence about the model, not about the premise. *)

(* DERIVED by the graph identity: same seed / bound / budget / depth as P13's
   G1 leg and P14's G2 leg, so the reachable product set is literally theirs
   (464 / 388 / 76, uid 3, rv 2, crashes 1). Only the asserted family differs,
   hence only [gate_states] and [outcome] can differ. The three phases
   cross-check on these pins (BUILD-SPEC-P15 §4.4). *)
let l1_states : int = P13_witness.g1_states
let l1_crash_witness_states : int = P13_witness.g1_crash_witness_states
let l1_fault_free_states : int = P13_witness.g1_fault_free_states
let l1_max_uid_seen : int = P13_witness.g1_max_uid_seen
let l1_max_rv_seen : int = P13_witness.g1_max_rv_seen
let l1_max_crashes_seen : int = P13_witness.g1_max_crashes_seen

(* [settled_with_faults_live] is a GRAPH-only count (it reads no invariant), so
   on the identical graph it is P13's own measured 10 - derived, and the leg
   test asserts it against the live report. *)
let l1_settled_with_faults_live : int = P13_witness.g1_settled_with_faults_live

(* MEASURED 304: post-crash states at which SOME member of R1-R4 is exercised
   ([require_crash = true]). Strictly larger than P14's 296 on the same graph:
   the reconcile-side premises survive at post-crash states whose network is
   EMPTY (92 of them), where P14's message-shaped premises go dark. *)
let l1_gate_states : int = 304

(* MEASURED 368: the same union WITHOUT the post-crash requirement, recomputed
   over the leg's replica (the leg reports only its own [require_crash] gate). *)
let l1_gate_states_all : int = 368

(* The §5 re-measurement, crash side: the crash orphans exactly one pre-crash
   request (restart empties [ongoing_reconciles], not [s.network]), so the peak
   is 2 - four times below the ceiling 8. No retune. *)
let l1_max_in_flight_seen : int = 2

(* -- per-member counts on L1's 464 states, all-states / post-crash ----------
   MEASURED. Every member exercised for R2/R3/R4 both overall and post-crash,
   so clean-under-crash is non-vacuous per member; R1 stays structurally 0. *)
let r1_interesting_l1 : int = 0
let r2_interesting_l1 : int = 180
let r3_interesting_l1 : int = 180
let r4_interesting_l1 : int = 188
let r1_interesting_l1_post_crash : int = 0
let r2_interesting_l1_post_crash : int = 148
let r3_interesting_l1_post_crash : int = 148
let r4_interesting_l1_post_crash : int = 156

(* ==== L2: drops-only {0;1;0} - tests req_drop_disabled (crs.rs:415) ========
   MEASURED VACUOUS BY CONSTRUCTION, and pinned as such rather than reported as
   a pass ([[feedback-workflow-zero-findings-may-be-vacuous]]): the leg's seed
   is [Scenario.vsts_seed_faults ~req_drop:false], fault flags only flip
   true -> false, so NO budget can enable [Step.Drop_req_step]. The drop edge
   was NEVER taken ([max_drops_seen = 0] against cap 1) and the graph is
   byte-identical to L0's - this leg measures NOTHING about req_drop_disabled.
   The honest measurement lives in the SUPPLEMENTARY flag-enabled probe below. *)

(* DERIVED = L0's, and that identity is the vacuity mechanism itself; the leg
   test asserts it against both live runs. *)
let l2_states : int = l0_states
let l2_gate_states : int = l0_gate_states
let l2_max_drops_seen : int = 0

(* ==== L3: monkey-only {0;0;1} - tests pod_monkey_disabled (crs.rs:416) =====
   Same mechanism as L2, same verdict: [max_monkeys_seen = 0] against cap 1,
   graph byte-identical to L0. Vacuous by construction of the leg. *)
let l3_states : int = l0_states
let l3_gate_states : int = l0_gate_states
let l3_max_monkeys_seen : int = 0

(* ==== L4: budget_default {1;1;1} - all three premises at once ==============
   MEASURED: graph byte-identical to L1's (464 / 388 / 76). Only the CRASH
   dimension is exercised - [max_drops_seen = 0] and [max_monkeys_seen = 0] by
   the same seed-flag mechanism as L2/L3 - so at the leg L4 re-measures L1 and
   its drop/monkey dimensions are VACUOUS. Derived pins; the leg test asserts
   the identity against the live L1 report. *)
let l4_states : int = l1_states
let l4_gate_states : int = l1_gate_states
let l4_gate_states_all : int = l1_gate_states_all
let l4_crash_witness_states : int = l1_crash_witness_states
let l4_max_drops_seen : int = 0
let l4_max_monkeys_seen : int = 0

(* ==== the §4.3 side-condition verdict (what makes R2/R4 honest) ============
   MEASURED against [Controller.model_of_controller] over the model the leg's
   scenario ACTUALLY registers - the VStatefulSet pack (scenario.ml:287-309),
   NOT VReplicaSet as §4.3's "VRS reconciler" phrasing suggests; the triples
   are the reconcile transitions the leg's graph really executes. Verdicts:
   [state_comes_with_a_pending_request Fc.vsts_pending_states] = TRUE and
   non-vacuous on every graph measured (init conjunct genuinely discriminating:
   [vsts_pending_states (init ())] = false), and the dual
   [state_comes_with_no_pending_request Fc.vsts_none_states] = TRUE and
   non-vacuous (no init conjunct - upstream's own asymmetry, crs.rs:507). So R2
   and R4 were measured at VALIDATED instantiations; §4.3's "no non-vacuous
   instantiation exists" branch was NOT taken.

   The triples are edge-derived: over every reachable product state, each
   [Cluster_check.bounded_labelled_successors] edge whose [Step.Controller_step]
   satisfies continue_reconcile's precondition class (key ongoing, not done,
   not errored - mutually exclusive with run_scheduled's not-ongoing and
   end_reconcile's done-or-errored) contributes
   [(triggering_cr, resp_view recv, local_state)]. Landing counts partition
   each triple set exactly (every continue landing decodes): 24 + 36 = 60 on
   L0's graph, 126 + 222 = 348 on L1's. *)

let l0_continue_triples : int = 60
let l0_triples_landing_pending : int = 24
let l0_triples_landing_none : int = 36
let l1_continue_triples : int = 348
let l1_triples_landing_pending : int = 126
let l1_triples_landing_none : int = 222

(* ==== R1's structural zero: the binding-ceiling sweep (P14's N5 protocol) ==
   R1's gate is 0 at [desired = 1] and the zero is STRUCTURAL, not a bound
   artifact. MEASURED, all decisive with the frontier emptied, R1's
   [interesting] = 0 and the per-state maximum of concurrently-pending ongoing
   reconciles = 1 at EVERY point:
     zero-budget  rc 2 (shipped) -> 76 states     (pinned above as {!l0_states})
     zero-budget  rc 3           -> 112
     zero-budget  rc 4 @depth 60 -> 148
     zero-budget  rc 6 @depth 100 -> 220
     crash-only   rc 2 (shipped) -> 464           (pinned above as {!l1_states})
     crash-only   rc 3 @depth 60 -> 984
   plus [desired = 2] (still ONE CR key, two replicas), crash-only rc 2:
   852 states, R1 = 0, max concurrent pending = 1. MECHANISM:
   [ongoing_reconciles] is keyed by [object_ref], so a single-CR seed can never
   hold two ongoing reconciles regardless of any ceiling. (The raised-ceiling
   legs run at raised depth for the same reason P14's did: at rc 4 the shipped
   depth 40 stops being decisive - depth binds before the ceiling.) *)

let rc_sweep_low : int = 3
let l0_rc_low_states : int = 112
let rc_sweep_mid : int = 4
let rc_sweep_mid_depth : int = 60
let l0_rc_mid_states : int = 148
let rc_sweep_high : int = 6
let rc_sweep_high_depth : int = 100
let l0_rc_high_states : int = 220
let l1_rc_low_depth : int = 60
let l1_rc_low_states : int = 984
let r1_interesting_swept : int = 0
let max_concurrent_pending_single_cr : int = 1
let desired_two : int = 2
let desired_two_states : int = 852
let r1_interesting_desired_two : int = 0

(* -- and the seed that DOES exercise R1: P12's multi-CR concurrency shape ---
   Two concurrently-ongoing reconciles ARE reachable at one controller with the
   multi-CR [1;1] seed. MEASURED (frontier emptied on both graphs): R1's
   [interesting] fires at 928 of 3864 zero-budget states (2.70 s) and 1856 of
   10552 crash-only states (8.12 s), and R1's [holds] is violated at ZERO
   reachable states on both - R1 is non-vacuously exercised and clean there. *)
let multi_cr_desireds : int list = P13_witness.witness_desireds
let multi_cr_zero_states : int = 3864
let r1_interesting_multi_cr_zero : int = 928
let multi_cr_crash_states : int = 10552
let r1_interesting_multi_cr_crash : int = 1856
let r1_holds_violations_multi_cr : int = 0

(* ==== SUPPLEMENTARY flag-enabled probes (the honest L2/L3 counterparts) ====
   NOT the leg: the same four-member family conjunction evaluated over a direct
   product graph whose SEED enables the fault flag the leg's seed pins off -
   the only way the drop/monkey premises can be measured at all (flags only
   flip true -> false). Each probe carries its own flag-ON zero-budget control.

   L2x (seed [~req_drop:true], budget {0;1;0}): MEASURED clean, decisive, drop
   edge REALLY taken (max drops seen 1), 0.137 s. Confirms PREDICTION P15-C
   (drop leg clean: [Network.deliver] REMOVES the request as it adds the
   matched error response, so exactly one XOR disjunct holds at every step).
   req_drop_disabled is measured-unnecessary-in-this-model for R2/R3/R4 - with
   the same §8.3 qualifier as L1's verdict.

   L3x (seed [~pod_monkey:true], budget {0;0;1}): MEASURED clean, decisive,
   monkey edge REALLY taken, 1.425 s. pod_monkey_disabled likewise
   measured-unnecessary-in-this-model for R2/R3/R4.

   L4x (ALL flags live, budget {1;1;1}, depth 16 per the P13 settling-leg
   retune precedent - depth 40 measured-blows the 150 s alarm on this shape) is
   MEASURED but deliberately NOT asserted by any test: 41645 states, gate
   37203, all three fault edges taken on one graph, clean so far - but
   decisive = FALSE (frontier NOT emptied), so it is an honest coverage limit,
   not a verdict, and 78.5 s of CPU would buy the battery a pin on a
   non-verdict while more than halving its alarm headroom. Recorded here so the
   measurement is not lost; per-member counts at that depth:
   all/post-crash/post-drop/post-monkey R1 = 0/0/0/0,
   R2 = R3 = 23469/20472/20807/18067, R4 = 13734/11037/11485/11566. *)

let l2x_states : int = 744
let l2x_gate_states_all : int = 688
let l2x_max_drops_seen : int = 1
let l2x_max_in_flight_seen : int = 1
let r1_interesting_l2x : int = 0
let r2_interesting_l2x : int = 512
let r3_interesting_l2x : int = 512
let r4_interesting_l2x : int = 176
let r1_interesting_l2x_post_drop : int = 0
let r2_interesting_l2x_post_drop : int = 448
let r3_interesting_l2x_post_drop : int = 448
let r4_interesting_l2x_post_drop : int = 112

(* The flag-ON zero-budget control: the req_drop flag doubles L0's 76 states
   (each state gains a [Step.Disable_req_drop_step] flag-off copy) and the
   family stays clean and exercised. R2/R3/R4 each fire at 64 states. *)
let l2x_control_states : int = 152
let l2x_control_gate_states : int = 128
let r2_interesting_l2x_control : int = 64
let r3_interesting_l2x_control : int = 64
let r4_interesting_l2x_control : int = 64

let l3x_states : int = 1976
let l3x_gate_states_all : int = 1680
let l3x_max_monkeys_seen : int = 1
let l3x_max_in_flight_seen : int = 2
let r1_interesting_l3x : int = 0
let r2_interesting_l3x : int = 840
let r3_interesting_l3x : int = 840
let r4_interesting_l3x : int = 840
let r1_interesting_l3x_post_monkey : int = 0
let r2_interesting_l3x_post_monkey : int = 776
let r3_interesting_l3x_post_monkey : int = 776
let r4_interesting_l3x_post_monkey : int = 776

(* The monkey-flag-ON zero-budget control: MEASURED 152 states, clean,
   decisive. (Its gate and per-member counts were NOT measured, so no such pin
   exists here and the test asserts none - a predicted assertion is exactly
   what this file exists to prevent.) *)
let l3x_control_states : int = 152

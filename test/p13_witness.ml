(* BUILD-SPEC-P13 section 4.5: the SINGLE SOURCE OF TRUTH for the P13 fault-leg
   witness - the bound, the budgets, the witness [desired] / [desireds] / [depth],
   and every pinned MEASURED number. A shared non-test module (not in the [dune]
   [(names ...)] list, so dune links it into every test exe), following the
   [p12_witness.ml] precedent: keeping the pins here means a future re-tune cannot
   drift [t_p13_faults] and [t_p13_mutation] into asserting different witnesses.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. The P13 test exes read every count
   from here. ([lib/checker/fault_check.mli] reports the same measurements as
   prose disclosure, which section 5 explicitly requires; that is documentation of
   a run, not a second assertion site.)

   RETUNE DISCLOSURE (BUILD-SPEC-P13 section 5 requires every retune to be named
   here as well as in the .mli). {!p13_bound} is the P12 witness bound
   ([P12_witness.p12_bound], test/p12_witness.ml:9-22) with ONE dimension changed:
   [reconcile_ceiling] is FORCED to 2 instead of P12's [n + 1]. At [desireds = [1]]
   that is P12's own value (no change); at the [1; 1] witness it is a REDUCTION
   from 3, and it was necessary: at [reconcile_ceiling = 3] the G2 leg was killed
   after 561.67 s user / 9 m 49.99 s wall without producing a verdict (far past
   section 5's ~120 s bar), while at 2 it is decisive in 6.645 s wall. COVERAGE
   COST, stated rather than hidden: 2 still admits the two CONCURRENT reconcile
   starts that the [>= 2]-concurrent witness needs, but it clips runs that would
   start a THIRD sequential pass, so uniqueness is checked over fewer sequential
   passes than P12's fault-free leg. Uniqueness holds CONSTRUCTIONALLY (the
   monotone [Controller.Reconcile_id_allocator.allocate] hands out distinct ids at
   any ceiling), so the clip bounds COVERAGE, not truth - the same disclosure
   [Cluster_check.check_unique_reconcile_id_vsts] already carries. Deriving the
   bound from [P12_witness.p12_bound] rather than re-typing its six numbers keeps
   the P12 shape itself single-sourced too.

   Firewall: List/Option/fold combinators only, no loop keywords, no wildcard
   match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

let p13_bound ~(desireds : int list) : Bound.t =
  { (P12_witness.p12_bound ~desireds) with Bound.reconcile_ceiling = 2 }

(* The witness shapes. [witness_desired] is the single-CR safety/settling witness
   (G1, G3); [witness_desireds] is P12's two-1-replica-CR concurrency witness
   (G2), the cheapest seed admitting >= 2 concurrent ongoing reconciles. *)
let witness_desired : int = 1
let witness_desireds : int list = [ 1; 1 ]

(* The exploration depth every shipped P13 pin was measured at. Equal to
   [Fault_check]'s own [default_depth], passed explicitly so each pin names the
   dimension it is bounded by. *)
let witness_depth : int = 40

(* The budget the three shipped legs are pinned at: the crash dimension ISOLATED
   (BUILD-SPEC-P13 section 8), so a refutation is attributable to the crash and
   the graph stays small enough to close. *)
let witness_budget : Fc.budget = Fc.budget_crash_only

(* The all-zero budget: every adversary's [Step.t] arm still enumerated, but every
   fault edge clipped. Used by the M4 budget pin (BUILD-SPEC-P13 section 6). *)
let zero_budget : Fc.budget =
  { Fc.max_crashes = 0; max_drops = 0; max_monkey_ops = 0 }

(* ==== MEASURED pins ======================================================== *)

(* G1 [check_invariants_under_faults]: the FULL shipped VSTS [always] suite over
   the crash-only product graph. [p13_bound ~desireds:[witness_desired]],
   [witness_budget], [witness_depth]. MEASURED: No_counterexample, decisive,
   both pruning flags true, 0.317 s wall. So the whole shipped VSTS safety suite
   survives a real controller crash DECISIVELY, checked at 388 post-crash states. *)
let g1_states : int = 464
let g1_gate_states : int = 388
let g1_crash_witness_states : int = 388
let g1_fault_free_states : int = 76
let g1_settled_with_faults_live : int = 10
let g1_max_uid_seen : int = 3
let g1_max_rv_seen : int = 2
let g1_max_crashes_seen : int = 1

(* G2 [check_unique_reconcile_id_under_faults]: P12's uniqueness gate strengthened
   into the crash dimension. [p13_bound ~desireds:witness_desireds] (the retuned
   [reconcile_ceiling = 2] above), [witness_budget], [witness_depth]. MEASURED:
   No_counterexample, decisive, both pruning flags true, 6.645 s wall. The 2784
   gate states are >= 2-concurrent-reconciles-AFTER-A-CRASH, strictly stronger
   than P12's fault-free 6952 (whose every state had [crashes = 0]). *)
let g2_states : int = 10552
let g2_gate_states : int = 2784
let g2_crash_witness_states : int = 6688
let g2_fault_free_states : int = 3864
let g2_settled_with_faults_live : int = 85
let g2_max_uid_seen : int = 5
let g2_max_rv_seen : int = 4
let g2_max_crashes_seen : int = 1

(* G3 [check_settles_after_disable] at [witness_budget]: the load-bearing settling
   witness. [p13_bound ~desireds:[witness_desired]], [witness_depth]. MEASURED:
   No_counterexample, decisive, 2.145 s wall. After a REAL crash and the
   [Disable_*] prefix, all 10 states where the run stops match the desired state.

   NOT PINNED HERE (deliberately): the [budget_default] variant of this leg, which
   REFUTES at [depth = 16] and costs 1 m 36.40 s wall. Its full measurement and
   the reconcile_ceiling-starvation diagnosis live in
   [Fault_check.check_settles_after_disable]'s .mli; it is kept out of
   [t_p13_faults] because one 96 s test would leave that exe no headroom under the
   150 s harness alarm (measured wall/cpu ratios as bad as 34% under memory
   pressure). *)
let g3_states : int = 1856
let g3_gate_states : int = 10
let g3_crash_witness_states : int = 1552
let g3_fault_free_states : int = 304
let g3_settled_with_faults_live : int = 30
let g3_max_uid_seen : int = 3
let g3_max_rv_seen : int = 2
let g3_max_crashes_seen : int = 1

(* The invariant [Invariants.first_violated] names at the hand-forged
   duplicate-uid state of the G1 Refuted-branch discriminator: inv1
   [etcd_objects_have_unique_uids] (Anvil kubernetes_cluster proofs), the FIRST
   member of [Invariants.cluster_structural]. MEASURED, not assumed. *)
let forged_dup_uid_violated_name : string = "etcd_objects_have_unique_uids"

(* The invariant [Fault_check]'s G3 leg names on a refutation: the VSTS ESR
   liveness goal. MEASURED at the disclosed [budget_default] run and re-measured
   by the forged-quiescent discriminator. *)
let g3_violated_name : string = "vsts_current_state_matches"

(* ==== BUILD-SPEC-P13 section 6: the M3 / M4 / M5 automated pins ============= *)

(* M3 (vacuity detector). The SAME crash-only product exploration as G1, seeded
   [~crash:false] instead of [~crash:true]: the [Restart_controller_step]
   precondition (cluster.rs:377) reads the per-controller [crash_enabled] flag,
   so with the flag down the fault edge is never ENABLED and the whole crash
   dimension must vanish. MEASURED: 38 states, of which 0 are post-crash and 0
   satisfy G1's gate predicate.

   The [~crash:true] POSITIVE control needs no new pin: that exploration IS the
   G1 graph, so its state count is {!g1_states} and its gate count is
   {!g1_gate_states} (388 - measured equal to the real gate's, which also
   confirms the test's local gate replica matches [check_invariants_under_faults]
   exactly). 38 vs 76 is not a discrepancy with {!g1_fault_free_states}: the
   flag-ON seed reaches each of those 38 cluster states both before and after
   [Disable_crash_step], 38 + 38 = 76. *)
let m3_crash_free_states : int = 38
let m3_crash_free_crash_witness_states : int = 0
let m3_crash_free_gate_states : int = 0

(* M4 (budget pin). G1's gate run unchanged except [budget = ]{!zero_budget}: the
   crash edge is still ENABLED (the seed keeps [crash_enabled = true]) but every
   instance of it is clipped by the cap, which is what separates this pin from M3
   (flag down) - one tests the model's precondition, the other the checker's
   budget. MEASURED: [No_counterexample], decisive, [crash_witness_states = 0],
   [gate_states = Some 0], [pruned_by_budget = true], [max_crashes_seen = 0], and
   76 states, which is exactly {!g1_fault_free_states}. That equality is an
   IDENTITY, not a coincidence: with all three caps at 0 the admitted edges are
   precisely the non-fault ones, so the reachable set is precisely the
   [crashes = drops = monkeys = 0] slice of the G1 graph. Asserting it against
   {!g1_fault_free_states} therefore adds a cross-check instead of a second pin. *)
let m4_zero_budget_crash_witness_states : int = 0
let m4_zero_budget_gate_states : int = 0

(* M5 (classifier pin). The G2 product graph explored with a LOCAL copy of
   [Fault_check.faulted_successors] whose twelve-arm classifier mis-reads
   [Step.Restart_controller_step] (cluster.rs:377) as a non-fault, i.e. the exact
   defect a wildcard [_ ->] arm would introduce. MEASURED under the
   mis-classifier: 7024 states, max crashes 0 (the counter never moves, so every
   [crashes >= 1] witness would silently read as vacuous), and 3512 of those
   states still have a [Restart_controller_step] successor enabled - the edges ARE
   there, only uncharged, which is what makes the blindness a real defect rather
   than an absence of restarts.

   The REAL-classifier half needs no new pin: it is the G2 exploration, so
   {!g2_states} (10552), {!g2_crash_witness_states} (6688) and
   {!g2_max_crashes_seen} (1) are reused. *)
let m5_misclassified_states : int = 7024
let m5_misclassified_max_crashes : int = 0
let m5_misclassified_restart_edge_states : int = 3512

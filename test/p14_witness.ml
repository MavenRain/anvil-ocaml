(* BUILD-SPEC-P14 §4.5: the SINGLE SOURCE OF TRUTH for the P14 id-level
   correspondence witness - the bound, the shape, the budgets, and every pinned
   MEASURED number of the two legs. A shared non-test module (not in the [dune]
   [(names ...)] list, so dune links it into every test exe), following the
   [p13_witness.ml] / [p12_witness.ml] precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. [t_p14_correspondence] and
   [t_p14_mutation] read every count from here and re-type none of them.
   ([lib/checker/fault_check.mli] reports the same measurements as prose
   disclosure, which §5 requires; that is documentation of a run, not a second
   assertion site. [t_p14_regression] deliberately re-types P13's and P12's
   committed literals - that duplication IS the firewall and is documented
   there.)

   RETUNE DISCLOSURE (§5 requires every retune to be named here as well as in the
   .mli). {!p14_bound} is [P13_witness.p13_bound] UNCHANGED - P14 needed NO
   retune. §5 flagged a new inflation source (post-crash orphan messages never
   drain, so [max_in_flight] should bind harder here than in any prior phase) and
   directed that [max_in_flight] be retuned FIRST if a run did not close. It did
   not bite: at the P13 shape both legs are DECISIVE with the frontier emptied,
   G1 in 0.01 s and G2 in 0.06 s of CPU, versus the ~120 s bar. The orphan
   inflation is real but bounded - [reconcile_ceiling = 2] clips the run before
   enough orphans accumulate to approach [max_in_flight = 8].

   CORRECTED (review): this used to add "and the measured peak is the
   {!n5_interesting_g2} states holding exactly 2 in flight". Nothing measured a
   peak - [fault_report] carries no in-flight maximum, and N5's [interesting] is
   [cardinal >= 2], a LOWER bound consistent with 3 or more. What IS now measured
   is {!g1_max_in_flight_seen} = 1, the largest [Message.Pool.cardinal] over the
   whole CRASH-FREE graph, and it stays 1 at every [reconcile_ceiling] in the
   sweep. On the crash-enabled graph the honest statement is the lower bound:
   [cardinal >= 2] at {!n5_interesting_g2} states. Deriving
   the bound from [P13_witness.p13_bound] rather than re-typing its numbers keeps
   the P13 shape single-sourced through P14 as well.

   Firewall: List/Option/fold combinators only, no loop keywords, no wildcard
   match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

(* The P13 crash-only shape, unretuned (see the disclosure above). *)
let p14_bound ~(desireds : int list) : Bound.t = P13_witness.p13_bound ~desireds

(* The single-CR witness shape and depth, shared with P13 so the two phases'
   legs are directly comparable rather than two unrelated experiments. *)
let witness_desired : int = P13_witness.witness_desired
let witness_depth : int = P13_witness.witness_depth

(* The two budgets. BOTH legs seed [~crash:true] (the flag ON, so
   [Step.Restart_controller_step] is enumerated at all) and differ ONLY in
   [budget.max_crashes] - one variable, so G1 and G2 are comparable. *)
let zero_budget : Fc.budget = P13_witness.zero_budget
let witness_budget : Fc.budget = P13_witness.witness_budget

(* ==== G1: crash-DISABLED (§4.4) ============================================= *)

(* [check_correspondence_under_faults ~depth (p14_bound ~desireds:[witness_desired])
   zero_budget ~desired:witness_desired ~require_crash:false].
   MEASURED: [No_counterexample], decisive, both pruning flags true, 0.01 s CPU.
   Establishes the family is non-vacuous BEFORE any crash - for four of its five
   members; see {!n5_interesting_g1}, which is the phase's honest exception. *)

(* DERIVED, not re-typed, and the derivation is a load-bearing IDENTITY rather
   than a convenience. The product graph depends only on (seed, bound, budget,
   depth) - never on the invariant checked over it - and P14's leg uses P13's G1
   seed, bound and depth exactly. With all three caps at 0 the admitted edges are
   precisely the non-fault ones, so this graph IS the [crashes = drops =
   monkeys = 0] slice of P13's G1 graph: 76 states, the same 76 that
   [P13_witness.g1_fault_free_states] pins and that P13's own M4 pin already
   identified. [t_p14_correspondence] ASSERTS the identity against the live leg
   rather than assuming it, so a divergence reddens instead of tracking. *)
let g1_states : int = P13_witness.g1_fault_free_states
let g1_fault_free_states : int = P13_witness.g1_fault_free_states
let g1_crash_witness_states : int = P13_witness.m4_zero_budget_crash_witness_states

(* NEW in P14: [require_crash = false], so the gate counts states exercising SOME
   member with no post-crash requirement. MEASURED 32, and measured EQUAL to
   {!n1_interesting_g1} - N1's [cardinal >= 1] subsumes N4's and N5's premises
   and (measured) covers N2's and N3's here too, so the union of the five
   interesting sets IS N1's. *)
let g1_gate_states : int = 32

(* The achieved maxima on the 76-state graph. Pinned as literals: that they equal
   P13's G1 maxima is a coincidence of this scenario (the uid/rv counters are
   driven by the fault-free prefix), not the structural identity above, so
   deriving them would assert something untrue. *)
let g1_max_uid_seen : int = 3
let g1_max_rv_seen : int = 2
let g1_max_crashes_seen : int = 0

(* ==== G2: crash-ENABLED - the headline (§4.4) =============================== *)

(* [check_correspondence_under_faults ~depth (p14_bound ~desireds:[witness_desired])
   witness_budget ~desired:witness_desired ~require_crash:true].
   MEASURED: [No_counterexample], decisive, both pruning flags true, 0.06 s CPU.
   The id-level correspondence family survives a REAL controller crash, checked
   at 296 states that are BOTH post-crash AND exercising a member. *)

(* DERIVED by the same identity as G1's: same seed, same bound, same depth, same
   [budget_crash_only] as P13's G1 leg, so the reachable product set is literally
   P13's G1 product set (464 / 388 / 76 / uid 3 / rv 2 / crashes 1). Only the
   invariant differs, hence only [gate_states] and [outcome] can differ. *)
let g2_states : int = P13_witness.g1_states
let g2_crash_witness_states : int = P13_witness.g1_crash_witness_states
let g2_fault_free_states : int = P13_witness.g1_fault_free_states
let g2_max_uid_seen : int = P13_witness.g1_max_uid_seen
let g2_max_rv_seen : int = P13_witness.g1_max_rv_seen
let g2_max_crashes_seen : int = P13_witness.g1_max_crashes_seen

(* NEW in P14 and the number the phase exists to produce: post-crash states at
   which some member of the family is genuinely exercised. MEASURED 296, and
   measured EQUAL to {!n1_interesting_g2_post_crash}. Strictly smaller than P13's
   G1 gate (388) because this family's [interesting] premises are message-shaped
   and 92 post-crash states have an EMPTY network. *)
let g2_gate_states : int = 296

(* ==== per-member [interesting]-fires counts (§4.4 / §4.5) ==================
   All ten MEASURED by counting over the leg's own product graph
   ([Fc.faulted_successors] from [Scenario.vsts_seed_faults ~crash:true
   ~req_drop:false ~pod_monkey:false]), never predicted. These are what make a
   clean verdict mean something per MEMBER rather than only for the conjunction:
   the conjunction's gate is a UNION, so four dead members and one live one look
   exactly like five live ones. *)

(* -- on G1's crash-free graph (76 states) ---------------------------------- *)
let n1_interesting_g1 : int = 32
let n2_interesting_g1 : int = 32

(* CORRECTED (review), 32 -> 16. N3 originally borrowed N2's [interesting], which
   is not a witness that N3 was non-trivially EVALUATED: with a pending request
   present but no api REQUEST in flight, N3's inner [List.for_all] ranges over
   nothing and is vacuously true. N3 now requires both conjuncts, and exactly half
   the old count turns out to have been those vacuous states. The leg's
   [gate_states] is unchanged (32 / 296) because that gate is a UNION dominated by
   N1 - which is itself why per-member counts exist. *)
let n3_interesting_g1 : int = 16

let n4_interesting_g1 : int = 16

(* MEASURED ZERO, and reported as a FINDING rather than deleted (§4.5's rule:
   "if some member's [interesting] never fires, that is a REAL VACUITY FINDING").

   N5's [interesting] is [Message.Pool.cardinal (in_flight s) >= 2]
   (correspondence.ml:198). On the crash-FREE graph it fires at NO state: this
   scenario's fault-free message discipline is strictly request/response
   lock-step (the controller sends one request and blocks on
   [pending_req_msg]; the api server consumes it and sends exactly one
   response), so at most ONE message is ever in flight. It is NOT a
   [max_in_flight] artifact - that ceiling is 8, four times the required 2.

   CONSEQUENCE, stated rather than hidden: §4.4's claim that G1 "establishes the
   family is non-vacuous BEFORE any crash" holds for N1-N4 and is FALSE for N5.
   N5 is vacuous fault-free and becomes non-vacuous ONLY under crash
   ({!n5_interesting_g2} = {!n5_interesting_g2_post_crash} = 84, i.e. every state
   exercising N5 is post-crash). That is the phase's mechanism measured directly:
   the crash edge is the ONLY source of two concurrently in-flight messages in
   this bounded graph, because [restart_controller] drops the owning reconcile
   while leaving the request in [s.network], and the orphan then has no consumer
   (correspondence.mli:26-34).

   MEASURED CORRECTION (review) to the sentence that used to close this note. It
   said MA refutes "because MA is the only way to make two in-flight messages
   COLLIDE, and N5 is the only member that can see a collision". That mechanism is
   NOT what was measured: MA refutes via {b N1}
   ([every_in_flight_msg_has_lower_id_than_allocator]) at [steps = 6], and no
   collision ever forms. Resetting the counter to 0 makes every SURVIVING
   pre-crash message instantly violate [rpc_id < counter], which trips N1 one step
   before a reused id could be handed out. N5's role is narrower and still real:
   it is the member that WOULD catch a collision if one formed, and its 84 = 84
   identity is what shows the crash edge is the only source of two concurrently
   in-flight messages here. *)
let n5_interesting_g1 : int = 0

(* -- on G2's crash-enabled graph (464 states), ALL states ------------------- *)
let n1_interesting_g2 : int = 328
let n2_interesting_g2 : int = 180
let n3_interesting_g2 : int = 100 (* CORRECTED (review): was 180 *)
let n4_interesting_g2 : int = 156
let n5_interesting_g2 : int = 84

(* -- on G2's graph, restricted to the POST-CRASH slice ([crashes >= 1]) ------
   The stronger non-vacuity: each member is exercised at states reached THROUGH a
   real [Step.Restart_controller_step] edge, which is what a crash-tolerance
   claim needs. N5's is EQUAL to its unrestricted count - see
   {!n5_interesting_g1}. *)
let n1_interesting_g2_post_crash : int = 296
let n2_interesting_g2_post_crash : int = 148
let n3_interesting_g2_post_crash : int = 84 (* CORRECTED (review): was 148 *)
let n4_interesting_g2_post_crash : int = 140
let n5_interesting_g2_post_crash : int = 84

(* ==== §4.4 G3: the forged-collision discriminator =========================== *)

(* The member [Invariants.first_violated] names at the hand-forged state carrying
   two DISTINCT in-flight messages that share an [rpc_id]: N5, the only member
   that reads a second message. MEASURED, not assumed - N1 (both ids below the
   counter), N2/N3 (no ongoing reconcile holds a pending request at the seed) and
   N4 (the forged [src] is the scenario's registered controller id) all HOLD
   there, so the forge isolates N5. *)
let forged_collision_violated_name : string =
  "every_in_flight_msg_has_no_replicas_and_has_unique_id"

(* The forged states' shared shape: the allocator wound forward to this counter
   (so N1's strict [<] is satisfied by both ids), and the two rpc ids used by the
   collided and the distinct-id control states. All strictly below the counter.

   [forged_collided_ids] / [forged_distinct_ids] are reused verbatim by the N3
   isolation forge below, where the SAME pair means the same thing: the first
   component is the in-flight api request's id and the second is the pending
   request's, so [(3, 3)] is a collision and [(3, 4)] is its control. *)
let forged_allocator_count : int = 8
let forged_collided_ids : int * int = (3, 3)
let forged_distinct_ids : int * int = (3, 4)

(* ==== the PER-MEMBER isolation forges (review finding F1) ===================
   G3 forges a violation of N5 only. N2, N3 and N4's [holds] had NO refutation
   coverage at all: trivialising any of them to [fun _ -> true] left every P14
   test green, so three fifths of the family's rejecting behaviour shipped
   unobserved. Each member now gets a hand-built state that violates IT and a
   sibling that satisfies it, all sharing {!forged_allocator_count} so the
   comparison against the counter is the same one G3 uses.

   MEASURED (probe, then asserted by [t_p14_mutation]): at each violating forge
   EXACTLY the target member's [holds] is [false] and the other four are [true],
   so the red is attributable to that member and to nothing else. *)

(* N2. The pending request's id EQUALS the counter - the boundary at which
   [rpc_id < counter] first fails, so the forge is minimal rather than wildly out
   of range. Derived, not re-typed: the two must move together. *)
let forged_pending_violating_id : int = forged_allocator_count

(* N2's control: a pending request strictly below the counter. *)
let forged_pending_ok_id : int = 3

(* N4. A controller id that is NOT a key of [Scenario.vsts_cluster.controller_models]
   (the scenario registers exactly {!Anvil_assurance.Scenario.controller_id} = 0).
   MEASURED [Imap.mem 97 controller_models = false]; the test ASSERTS both that
   and the registered id's membership before concluding anything. *)
let forged_unregistered_controller_id : int = 97

(* ==== the N1 live-allocator discriminator (review finding F3) ===============
   MC's boundary state carries one in-flight message whose [rpc_id] EQUALS
   {!forged_allocator_count}, so N1's strict [<] REJECTS it. Its sibling is that
   SAME state with the allocator wound ONE further and nothing else changed, so
   the id is now strictly below the counter and N1 ACCEPTS. The pair differs in
   NOTHING BUT [s.rpc_id_allocator], which is what makes it able to detect "the
   harness is reading the wrong counter": a member reading a constant, a stale
   snapshot or some other counter returns the SAME verdict on both. Derived from
   {!forged_allocator_count} rather than re-typed - the two must move together. *)
let forged_n1_counter_above : int = forged_allocator_count + 1

(* ==== the BINDING-ceiling sweep for N5's G1 zero (review finding F6) ========
   The robustness leg varied [uid_ceiling] / [rv_ceiling], which the same report
   says were never reached (3 < 6, 2 < 6) - so its invariance was guaranteed a
   priori and was NOT evidence. The ceiling that actually binds is
   [reconcile_ceiling = 2]: it is the sole source of the G1 report's
   [pruned_by_ceiling = true]. MEASURED by re-running the G1 leg at raised
   reconcile ceilings; N5's [interesting] count stays 0 at every one, and the
   MAXIMUM in-flight cardinal over the whole crash-free graph stays 1, so the
   [>= 2] premise is structurally unreachable fault-free rather than merely
   unreached at this bound. N5's vacuity is NOT a bound artifact.

   MEASURED, all clean and DECISIVE:
     rc 2 (shipped) -> 76 states, gate 32, N5 0, max in flight 1
     rc 3           -> 112 states, gate 48, N5 0, max in flight 1
     rc 4 @depth 60 -> 148 states, gate 64, N5 0, max in flight 1
     rc 6 @depth 100 -> 220 states, gate 96, N5 0, max in flight 1
   DISCLOSED: at rc 4 with the shipped [depth = 40] the run is NOT decisive and
   [pruned_by_ceiling] flips to FALSE (depth binds before the ceiling does), which
   is why the high leg is run at a raised depth. *)

let rc_sweep_low : int = 3
let g1_rc_low_states : int = 112
let g1_rc_low_gate_states : int = 48
let rc_sweep_high : int = 6
let rc_sweep_high_depth : int = 100
let g1_rc_high_states : int = 220
let g1_rc_high_gate_states : int = 96

(* N5's [interesting] count on the crash-free graph at EVERY swept ceiling. The
   same zero as {!n5_interesting_g1}, kept separate because it is a different
   MEASUREMENT (a different graph) that happens to agree. *)
let n5_interesting_g1_raised_ceiling : int = 0

(* The largest [Message.Pool.cardinal (Cluster.in_flight s)] over the crash-free
   graph, at the shipped ceiling and at every swept one. ONE - the lock-step
   discipline itself, measured. *)
let g1_max_in_flight_seen : int = 1

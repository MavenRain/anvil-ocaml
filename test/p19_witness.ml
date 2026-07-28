(* BUILD-SPEC-P19 section 4: the SINGLE SOURCE OF TRUTH for the P19
   message-provenance witness - the bound, the shape, the four matrix leg
   budgets (L0 / Lc / Ld / Lm, NO vct dimension this phase - the k6-class
   cut, spec section 4 / section 8.2: no P19 member's premise reads PVCs or
   volumes), every pinned MEASURED number of the
   {!Anvil_checker.Fault_check.check_msg_provenance_under_faults} legs,
   their per-member [interesting] counts, and the ORPHAN-REPLICA floor pins
   (spec section 4). A shared non-test module (not in the [dune]
   [(names ...)] list, so dune links it into every test exe that references
   it), following the [p18_witness.ml] / [p17_witness.ml] / [p16_witness.ml]
   precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. [t_p19_provenance] (and later
   [t_p19_regression]) read every count from here and re-type none of them.
   ([lib/checker/fault_check.mli]'s prose disclosure of the same runs is
   documentation, not a second assertion site.)

   GRAPH IDENTITY, DERIVED NOT RE-TYPED: the legs use P16-P18's exact seed
   family ([Scenario.vsts_seed_faults ~crash:true], [vct] ABSENT = [false] -
   the leg signature has no [?vct]), bound, depth and matrix budgets, and
   the product graph depends only on (seed, bound, budget, depth) - never
   on the invariant list checked over it - so the four graphs ARE
   P13-P18's L0 / Lc / Ld / Lm graphs and every graph-only constant below
   is DERIVED from {!P18_witness} (itself derived from P17/P16 <- P15/P13).
   Only the family-dependent numbers (gates, per-member counts, the orphan
   floor block) are new measurements, MEASURED 2026-07-27 on this branch
   (B3, spec section 5 table).

   THE ORPHAN REPLICA (spec section 4) is a NEW graph - the generic/vrs
   spine from [Scenario.seed_with_orphan ~desired:1 ~fair:false] under
   plain [Scenario.productive_successors] at [Bound.default] - so its
   literals are NEW, not derivations: no shipped phase ever pinned a
   reachability count on that spine (t_p4_enumerator only DRIVES it for
   witness search, and the B3 depth sweep shows why: 43 states at depth 2,
   1518 at depth 4 - BFS exhaustion is intractable there, so the replica
   is deliberately DEPTH-LIMITED, disclosed below).

   CPU TIMES ([Sys.time], leg-call-only, measured in the B3 probe, same
   machine as the battery): L0 0.012 s, Lc 0.067 s, Ld 0.133 s, Lm
   0.813 s; orphan replica incl. counts + the M1 control 0.475 s - all far
   under the ~150 s harness alarm.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   wildcard match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

(* The P13 crash-only shape, unretuned through SIX phases now. *)
let p19_bound ~(desireds : int list) : Bound.t = P18_witness.p18_bound ~desireds

(* Single-CR witness shape and depth, shared with P13-P18 so the legs explore
   the SAME product graphs those phases pinned. *)
let witness_desired : int = P18_witness.witness_desired
let witness_depth : int = P18_witness.witness_depth

(* The section-4 matrix budgets, DERIVED from P18 (never re-typed):
     L0  zero    {0;0;0}  non-vacuity floor, fault-free
     Lc  crash   {1;0;0}  crash dimension
     Ld  drop    {0;1;0}  drop fabricates responses only
     Lm  monkey  {0;0;1}  the monkey-sourced-message leg (M2's only floor) *)
let zero_budget : Fc.budget = P18_witness.zero_budget
let lc_budget : Fc.budget = P18_witness.lc_budget
let ld_budget : Fc.budget = P18_witness.ld_budget
let lm_budget : Fc.budget = P18_witness.lm_budget

(* ==== L0: zero-budget control ============================================= *)

(* States DERIVED by graph identity (= P18 L0 = P13 G1's fault-free slice,
   76). Verdict/decisiveness pins live in [t_p19_provenance], not here. *)
let l0_states : int = P18_witness.l0_states

(* MEASURED 32: the [~require_fault:false] union gate - a PROPER subset of
   the 76 (the seed's in-flight pool is EMPTY, so no member's premise fires
   there) = M1's 16 + M4's 16 exactly: the two premises fire on DISJOINT
   state sets on this graph (a pending controller request and a pooled
   api-server response never coexist at desired 1 fault-free - the
   reconciler holds one request in flight and consumes its response before
   issuing the next; measured disjointness of this scenario, not a law). *)
let l0_gate_states : int = 32

(* -- per-member [interesting]-fires counts on L0's 76 states ---------------
   MEASURED. M1 = 16 (a controller-tagged in-flight message); M4 = 16 (an
   api-server-sourced RESPONSE in flight - the violation-shaped premise,
   .mli disclosure); M2 = M3 = 0 (no monkey budget / the builtin never
   fires on the vsts spine - honest N5 vacuity, spec section 5 predictions
   3-4; M3's floor lives on the orphan replica below). *)
let m1_interesting_l0 : int = 16
let m2_interesting_l0 : int = 0
let m3_interesting_l0 : int = 0
let m4_interesting_l0 : int = 16

(* ==== Lc: crash-only {1;0;0} ============================================== *)

(* States / slices DERIVED by graph identity (= P18 Lc = P13 G1:
   464 / 388 / 76). *)
let lc_states : int = P18_witness.lc_states
let lc_crash_witness_states : int = P18_witness.lc_crash_witness_states
let lc_fault_free_states : int = P18_witness.lc_fault_free_states

(* MEASURED 296: the [~require_fault:true] post-crash union gate - a proper
   subset of the 388 post-crash states (M1 140 + M4 192 with a 36-state
   overlap: the crash orphans the pre-crash request in the pool, so the
   restarted reconciler's request CAN coexist with a stale response). *)
let lc_gate_states : int = 296

(* -- per-member counts, all-states / post-crash. MEASURED: M1 156/140,
   M4 208/192, M2 = M3 = 0/0 (honest vacuity). *)
let m1_interesting_lc : int = 156
let m1_interesting_lc_post_crash : int = 140
let m2_interesting_lc : int = 0
let m2_interesting_lc_post_crash : int = 0
let m3_interesting_lc : int = 0
let m3_interesting_lc_post_crash : int = 0
let m4_interesting_lc : int = 208
let m4_interesting_lc_post_crash : int = 192

(* ==== Ld: drop-only {0;1;0} =============================================== *)

(* States / fault-free slice DERIVED by graph identity (= P18 Ld = P15 L2x:
   744 / 152). *)
let ld_states : int = P18_witness.ld_states
let ld_fault_free_states : int = P18_witness.ld_fault_free_states

(* MEASURED 448: the post-drop union gate = M1's 32 + M4's 416 exactly
   (disjoint again post-drop) - a proper subset of the 592 post-drop
   states. M4 dominates this leg: the drop edge consumes the pending
   request and fabricates its Error RESPONSE (api-server-sourced), which
   feeds M4's premise while STARVING M1's (the controller's request is
   gone from the pool), hence M1's 64/32 vs L0-like density elsewhere -
   measured mechanism note, not a law. *)
let ld_gate_states : int = 448

(* -- per-member counts, all-states / post-drop. MEASURED: M1 64/32,
   M4 448/416, M2 = M3 = 0/0. *)
let m1_interesting_ld : int = 64
let m1_interesting_ld_post_drop : int = 32
let m2_interesting_ld : int = 0
let m2_interesting_ld_post_drop : int = 0
let m3_interesting_ld : int = 0
let m3_interesting_ld_post_drop : int = 0
let m4_interesting_ld : int = 448
let m4_interesting_ld_post_drop : int = 416

(* ==== Lm: monkey-only {0;0;1} - M2's only live leg ======================== *)

(* States / fault-free slice DERIVED by graph identity (= P18 Lm = P15 L3x:
   1976 / 152). *)
let lm_states : int = P18_witness.lm_states
let lm_fault_free_states : int = P18_witness.lm_fault_free_states

(* MEASURED 1824: the post-monkey union gate SATURATES the whole post-monkey
   slice (1824 states, the number P17's S2-saturated gate measured on this
   same graph): every post-monkey state keeps SOME in-scope message in
   flight (monkey requests linger in the pool - delivery is a separate
   step - and the api server answers them). Unlike P17 no single member
   saturates it (M2 832, M1 336, M4 1184): the UNION covers the slice,
   the members individually do not - measured coverage of this scenario. *)
let lm_gate_states : int = 1824

(* -- per-member counts, all-states / post-monkey. MEASURED: M1 368/336,
   M2 832/832 (the ONLY leg where M2's premise fires, spec section 5
   prediction 4; every monkey-sourced in-flight message is by definition
   post-monkey, hence the equal slices), M4 1216/1184, M3 0/0 (the monkey
   writes pods; nothing on this spine ever orphans an object, so the
   builtin GC stays silent). *)
let m1_interesting_lm : int = 368
let m1_interesting_lm_post_monkey : int = 336
let m2_interesting_lm : int = 832
let m2_interesting_lm_post_monkey : int = 832
let m3_interesting_lm : int = 0
let m3_interesting_lm_post_monkey : int = 0
let m4_interesting_lm : int = 1216
let m4_interesting_lm_post_monkey : int = 1184

(* ==== The ORPHAN REPLICA (spec section 4) - M3's non-vacuity floor ========
   Generic/vrs spine, [Scenario.seed_with_orphan ~desired:1 ~fair:false],
   plain [Scenario.productive_successors Scenario.cluster Bound.default],
   [Mc.explore] at depth 4. DEPTH-LIMITED BY DESIGN, disclosed: the B3
   sweep measured 43 states at depth 2 (M3 already fires at 11, but M1's
   premise NOT yet - the control would be vacuously green) and 1518 at
   depth 4 (every section-4 requirement lands); the ~35x growth per 2
   plies makes BFS exhaustion intractable on this spine (the reason
   t_p4_enumerator DRIVES it instead of exploring it), so
   [frontier_emptied = false] is asserted as the honest shape of the
   replica and every count below is a depth-4-replica fact, NOT a
   total-reachability fact. *)
let orphan_desired : int = 1
let orphan_depth : int = 4

(* MEASURED 1518: the replica's reachable states at depth 4. *)
let orphan_states : int = 1518

(* MEASURED 679: M3's floor - states with a builtin-GC-sourced in-flight
   message (>= 1 as spec section 5 prediction 3 requires; the GC's delete
   on the orphan pod is REALLY in flight on this spine), with M3, M2 and
   M4 all VIOLATION-FREE across the 1518 (asserted semantically in
   [t_p19_provenance]). *)
let m3_interesting_orphan : int = 679

(* -- the other members on the replica, MEASURED (context for the floor):
   M2 = 1408 (the generic spine runs a LIVE pod monkey - t_p4's seeds
   drive it - and M2 stays green across all its emissions: bonus green
   surface, not vacuity), M4 = 532 (api-server responses in flight),
   M1's premise fires at 12 states. *)
let m1_interesting_orphan : int = 12
let m2_interesting_orphan : int = 1408
let m4_interesting_orphan : int = 532

(* MEASURED 12: the LIVE RED CONTROL (spec section 5 prediction 6) - the
   vrs spine stamps [Controller (0, vrs-kind key)] with the SAME
   controller id 0 the vsts spine uses, so M1's kind check fails at EVERY
   M1-premise state of the replica (12 = [m1_interesting_orphan]:
   premise-fire and violation coincide here because every controller tag
   on this spine is vrs-kind). M1 is MODEL-CONDITIONAL (msg_provenance.mli)
   and is NEVER asserted as an invariant on this replica - t_p19_provenance
   runs [Model_check.check_safety] with M1 ALONE and requires [Refuted]
   with the violated member naming M1. *)
let m1_violations_orphan : int = 12

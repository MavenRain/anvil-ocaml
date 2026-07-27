(* BUILD-SPEC-P18 section 4: the SINGLE SOURCE OF TRUTH for the P18
   helper-family witness - the bound, the shape, the five leg budgets
   (L0 / Lc / Ld / Lm at [vct:false], L0v at [vct:true]), every pinned
   MEASURED number of the {!Anvil_checker.Fault_check.
   check_helper_invariants_under_faults} legs, their per-member
   [interesting] counts, and the E1/E4 exclusion-pin counts. A shared
   non-test module (not in the [dune] [(names ...)] list, so dune links it
   into every test exe that references it), following the [p17_witness.ml]
   / [p16_witness.ml]
   / [p15_witness.ml] / [p14_witness.ml] / [p13_witness.ml] precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. [t_p18_helper] and
   [t_p18_regression] read every count from here and re-type none of them.
   ([lib/checker/fault_check.mli]'s prose disclosure of the same runs is
   documentation, not a second assertion site. [t_p18_regression]'s
   COMMITTED-literal firewall block is the one sanctioned duplication, and
   it duplicates P17's committed pins, not these.)

   GRAPH IDENTITY, DERIVED NOT RE-TYPED: the legs use P16/P17's exact seed
   family ([Scenario.vsts_seed_faults ~crash:true], with [vct] a REAL
   dimension again this phase), bound, depth and matrix budgets, and the
   product graph depends only on (seed, bound, budget, depth) - never on
   the invariant list checked over it - so the four [vct:false] graphs ARE
   P16/P17's L0 / Lc / Ld / Lm graphs and the [vct:true] zero-budget graph
   IS P16's L0v graph (t_p16_req_resp ran it at this same desired / bound /
   depth); every graph-only constant below is DERIVED from {!P17_witness} /
   {!P16_witness}. Only the family-dependent numbers (gates, per-member
   counts, E-pins) are new measurements.

   Only the family-dependent numbers (gates, per-member counts, E-pins)
   are new measurements, MEASURED 2026-07-27 on this branch (B3). Every
   spec section 4 prediction landed EXACTLY (1-5 all CONFIRMED, spec
   section 5): the four vct:false graphs are P13-P17's 76/464/744/1976,
   H1's counts are the P17 S1/S3 slice to the state (52/296/376/1624, post
   slices 244/272/1520), H2 is 0 on every vct:false state with an 80-state
   floor on L0v, and Lm is clean across the monkey-rely gap.

   WALL TIMES (leg-only runs, startup-subtracted, same machine as the
   battery): L0 0.08 s, Lc 0.18 s, Ld 0.48 s, Lm 2.26 s, L0v 0.05 s - all
   far under the ~150 s harness alarm.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   wildcard match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

(* The P13 crash-only shape, unretuned through FIVE phases now. *)
let p18_bound ~(desireds : int list) : Bound.t = P17_witness.p17_bound ~desireds

(* Single-CR witness shape and depth, shared with P13-P17 so the legs explore
   the SAME product graphs those phases pinned. *)
let witness_desired : int = P17_witness.witness_desired
let witness_depth : int = P17_witness.witness_depth

(* The section-4 matrix budgets, DERIVED from P17 (never re-typed):
     L0  zero    {0;0;0}  non-vacuity floor, fault-free, vct:false
     Lc  crash   {1;0;0}  crash dimension (predicted store-inert for H1/H2)
     Ld  drop    {0;1;0}  drop fabricates responses only
     Lm  monkey  {0;0;1}  THE RELY-GAP PROBE (spec section 4 prediction 4)
     L0v zero    {0;0;0}  at vct:TRUE - H2's non-vacuity floor *)
let zero_budget : Fc.budget = P17_witness.zero_budget
let lc_budget : Fc.budget = P17_witness.lc_budget
let ld_budget : Fc.budget = P17_witness.ld_budget
let lm_budget : Fc.budget = P17_witness.lm_budget

(* ==== L0: zero-budget control, vct:false ================================== *)

(* States DERIVED by graph identity (= P17 L0 = P16 L0 = P13 G1's fault-free
   slice, 76). Verdict/decisiveness pins live in [t_p18_helper], not here. *)
let l0_states : int = P17_witness.l0_states

(* MEASURED 52: the [~require_fault:false] union gate. UNLIKE G7's
   saturated gate, a PROPER subset of the 76: H1's [interesting] is 0 at
   the seed (the store holds only the CR) and H2's is 0 at every vct:false
   state, so the gate = H1's own count exactly. *)
let l0_gate_states : int = 52

(* -- per-member [interesting]-fires counts on L0's 76 states ---------------
   MEASURED. H1 = 52 - the P17 S1/S3 slice TO THE STATE (spec section 4
   prediction 2 CONFIRMED; asserted per leg as a scenario fact, never a
   law - the name-matched slice and P17's owner-carrying slice coincide on
   these graphs). H2 = 0 (honest vacuity, P14 N5: the 0 IS the result). *)
let h1_interesting_l0 : int = 52
let h2_interesting_l0 : int = 0

(* ==== Lc: crash-only {1;0;0}, vct:false =================================== *)

(* States / slices DERIVED by graph identity (= P17 Lc = P13 G1:
   464 / 388 / 76). *)
let lc_states : int = P17_witness.lc_states
let lc_crash_witness_states : int = P17_witness.lc_crash_witness_states
let lc_fault_free_states : int = P17_witness.lc_fault_free_states

(* MEASURED 244: the [~require_fault:true] post-crash union gate = H1's
   post-crash count exactly (crash moves no store-side truth). *)
let lc_gate_states : int = 244

(* -- per-member counts, all-states / post-crash. MEASURED: H1 296 / 244
   (the P17 S1 slice exactly, prediction 2 CONFIRMED), H2 0 / 0 (honest
   vacuity). *)
let h1_interesting_lc : int = 296
let h1_interesting_lc_post_crash : int = 244
let h2_interesting_lc : int = 0
let h2_interesting_lc_post_crash : int = 0

(* ==== Ld: drop-only {0;1;0}, req_drop:true, vct:false ===================== *)

(* States / fault-free slice DERIVED by graph identity (= P17 Ld = P15 L2x:
   744 / 152). *)
let ld_states : int = P17_witness.ld_states
let ld_fault_free_states : int = P17_witness.ld_fault_free_states

(* MEASURED 272: the post-drop union gate = H1's post-drop count. *)
let ld_gate_states : int = 272

(* -- per-member counts, all-states / post-drop. MEASURED: H1 376 / 272
   (the P17 S1 slice exactly, DILUTED density carried over - P17's honest
   negative, 376/744 = 50.5% vs 52/76 = 68.4% on L0), H2 0 / 0. *)
let h1_interesting_ld : int = 376
let h1_interesting_ld_post_drop : int = 272
let h2_interesting_ld : int = 0
let h2_interesting_ld_post_drop : int = 0

(* ==== Lm: monkey-only {0;0;1}, pod_monkey:true, vct:false =================
   THE PHASE HEADLINE LEG (spec section 4 prediction 4): upstream proves
   H1/H2 only under the monkey rely conditions; the port's monkey is
   rely-unconstrained but candidate-restricted. Clean-or-not is MEASURED,
   and a refutation is investigated (port first), never suppressed. *)

(* States / fault-free slice DERIVED by graph identity (= P17 Lm = P15 L3x:
   1976 / 152). *)
let lm_states : int = P17_witness.lm_states
let lm_fault_free_states : int = P17_witness.lm_fault_free_states

(* MEASURED 1520: the post-monkey union gate = H1's post-monkey count.
   THE HEADLINE RESULT rides this leg: clean + decisive across 1520
   post-monkey premise-firing states (prediction 4 CONFIRMED - the
   rely-unconstrained but candidate-restricted monkey cannot break H1). *)
let lm_gate_states : int = 1520

(* -- per-member counts, all-states / post-monkey. MEASURED: H1 1624 /
   1520 (the P17 S1 slice exactly - the monkey amplifies the premise,
   82.2% density vs L0's 68.4%), H2 0 / 0. Prediction 5's mechanism note
   (Lm max_uid_seen = 4 via monkey-DELETE + reconciler re-create) is
   asserted in [t_p18_helper] off the leg report, not pinned here (the
   maxima are graph constants already carried by P16's prose and P17's
   leg checks). *)
let h1_interesting_lm : int = 1624
let h1_interesting_lm_post_monkey : int = 1520
let h2_interesting_lm : int = 0
let h2_interesting_lm_post_monkey : int = 0

(* ==== L0v: zero-budget, vct:TRUE - H2's non-vacuity floor ================= *)

(* States DERIVED by graph identity from P16's L0v (116): t_p16_req_resp ran
   [check_req_resp_under_faults] at this same seed tuple
   ([~crash:true ~req_drop:false ~pod_monkey:false ~vct:true], desired 1),
   bound, zero budget and depth, and the graph does not depend on the
   invariant list - P18's first vct:true graph is NOT a new literal. *)
let l0v_states : int = P16_witness.l0v_states

(* Graph maxima on L0v, DERIVED from P16 (graph constants, family-blind). *)
let l0v_max_uid_seen : int = P16_witness.l0v_max_uid_seen
let l0v_max_rv_seen : int = P16_witness.l0v_max_rv_seen

(* MEASURED 80: the [~require_fault:false] union gate on L0v (H1 OR H2
   fires) = H2's own count - the 68 H1-firing states are a strict SUBSET
   of the 80 H2-firing ones on this graph (the reconciler creates the
   ordinal's PVC before its pod, so a matching pod never exists without
   its PVC; measured containment, not a law). *)
let l0v_gate_states : int = 80

(* -- per-member counts on L0v's 116 states. MEASURED: H1 = 68, the first
   pod-premise count at vct:true (NEW - no prior phase measured one); H2 =
   80, the de-vacuation floor, strictly positive as spec section 4
   prediction 3 requires ([t_p18_helper] asserts the > 0 semantically;
   this pin carries the exact number). *)
let h1_interesting_l0v : int = 68
let h2_interesting_l0v : int = 80

(* ==== E1 / E4 exclusion pins (spec section 3) ============================= *)

(* MEASURED (B3); asserted by [t_p18_regression] (B4) over the same
   replicas:

   E1 (the uid-exact sibling, upstream :36-49): on the L0 replica, the
   uid-exact rendering and H1 agree state-by-state - MEASURED delta 0
   (the port has no CR-delete edge, so the created-deleted-recreated
   same-name corner is unreachable) - with a forged wrong-uid CONTROL
   seen red on the uid-exact rendering while H1 holds (the control is a
   forge-side assertion in t_p18_regression, not a pinned count).

   E4 (the owned-PVC GC member, upstream :796): on the L0v replica,
   COUNTING CONVENTION disclosed: SUMMED over the replica's 116 states -
   each (state, stored-PVC-key) pair contributes 1. Owner-ref-carrying
   ([Some l] with [l] non-empty) stored PVCs: MEASURED 0 (make_pvc stamps
   none - the member upstream guards is vacuous in the port even at
   vct:true). CONTROL: 80 stored-PVC pairs (the detector looked at real
   PVCs; = [h2_interesting_l0v] because desired 1 mints at most one PVC
   per state, an observed coincidence of this scenario). *)
let e1_delta_l0 : int = 0
let e4_owned_pvcs_l0v : int = 0
let e4_control_pvcs_l0v : int = 80

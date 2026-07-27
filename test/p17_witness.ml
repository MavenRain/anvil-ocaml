(* BUILD-SPEC-P17 section 4: the SINGLE SOURCE OF TRUTH for the P17
   store-side witness - the bound, the shape, the four matrix budgets, and
   every pinned MEASURED number of the four G7 legs (L0 / Lc / Ld / Lm, all
   at the [vct:false] default - the vct dimension is deliberately out of
   scope this phase, k6-class, disclosed in [fault_check.mli]), their
   per-member [interesting] counts, and the E1/E2 exclusion-pin counts. A
   shared non-test module (not in the [dune] [(names ...)] list, so dune
   links it into every test exe), following the [p16_witness.ml] /
   [p15_witness.ml] / [p14_witness.ml] / [p13_witness.ml] precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. [t_p17_store] and
   [t_p17_regression] read every count from here and re-type none of them.
   ([lib/checker/fault_check.mli]'s prose disclosure of the same runs is
   documentation, not a second assertion site. [t_p17_regression]'s
   COMMITTED-literal firewall block is the one sanctioned duplication, and
   it duplicates P16's committed pins, not these.)

   GRAPH IDENTITY, DERIVED NOT RE-TYPED: the G7 legs use P16's exact seed
   ([Scenario.vsts_seed_faults ~crash:true], [vct] absent = [false]), bound,
   depth and matrix budgets, and the product graph depends only on
   (seed, bound, budget, depth) - never on the invariant list checked over
   it - so the four graphs ARE P16's L0 / Lc / Ld / Lm graphs and every
   graph-only constant below is DERIVED from {!P16_witness} (itself derived
   from P13/P15). Only the family-dependent numbers (gates, per-member
   counts, E-pins) are new measurements, MEASURED 2026-07-27 on this branch.

   WALL TIMES (measured with the leg runs, same machine as the battery):
   L0 0.010 s, Lc 0.059 s, Ld 0.130 s, Lm 0.782 s - all far under the
   ~150 s harness alarm.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   wildcard match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

(* The P13 crash-only shape, unretuned through FOUR phases now. *)
let p17_bound ~(desireds : int list) : Bound.t = P16_witness.p16_bound ~desireds

(* Single-CR witness shape and depth, shared with P13-P16 so the legs explore
   the SAME product graphs those phases pinned. *)
let witness_desired : int = P16_witness.witness_desired
let witness_depth : int = P16_witness.witness_depth

(* The section-4 matrix budgets, DERIVED from P16 (never re-typed):
     L0 zero    {0;0;0}  non-vacuity floor, fault-free
     Lc crash   {1;0;0}  the P15-A mirror (crash never touches the store)
     Ld drop    {0;1;0}  drop fabricates responses only
     Lm monkey  {0;0;1}  THE LEVERAGE EDGE (monkey writes ride the handlers) *)
let zero_budget : Fc.budget = P16_witness.zero_budget
let lc_budget : Fc.budget = P16_witness.lc_budget
let ld_budget : Fc.budget = P16_witness.ld_budget
let lm_budget : Fc.budget = P16_witness.lm_budget

(* ==== L0: zero-budget control ============================================= *)

(* MEASURED: clean, decisive, both pruning flags true. States DERIVED by
   graph identity (= P16 L0 = P13 G1's fault-free slice, 76). *)
let l0_states : int = P16_witness.l0_states

(* MEASURED 76: the [~require_fault:false] union gate = ALL 76 states - S2's
   [interesting] (store non-empty) fires everywhere because the seed itself
   stores the CR, so on every one of the four graphs the union gate MEASURES
   EQUAL to its counted slice (all-states here; the post-fault slice on
   Lc/Ld/Lm). NOT vacuous and NOT trivial: the per-member counts below show
   WHICH member saturates it (S2) and which fire on proper subsets (S1/S3). *)
let l0_gate_states : int = 76

(* -- per-member [interesting]-fires counts on L0's 76 states ---------------
   MEASURED over the leg's replica. S1 ([cardinal >= 2]) is 0 at the seed
   (one stored object: the CR) and fires only after the first pod create -
   52 of 76 states; S3's witness (a stored object carrying an
   [is_controller] entry) MEASURES EQUAL to S1's count on every one of the
   four graphs (52/296/376/1624): the first pod create is the reconciler's,
   and its pod carries the controller ref, so the >= 2-objects slice and the
   controller-ref slice coincide on these graphs (an observed coincidence of
   this scenario, asserted per leg, not a law). *)
let s1_interesting_l0 : int = 52
let s2_interesting_l0 : int = 76
let s3_interesting_l0 : int = 52

(* ==== Lc: crash-only {1;0;0} - the P15-A mirror =========================== *)

(* MEASURED: clean, decisive, crash edge REALLY taken. States / slices
   DERIVED by graph identity (= P16 Lc = P13 G1: 464 / 388 / 76). *)
let lc_states : int = P16_witness.lc_states
let lc_crash_witness_states : int = P16_witness.lc_crash_witness_states
let lc_fault_free_states : int = P16_witness.lc_fault_free_states

(* MEASURED 388: the post-crash union gate = the whole post-crash slice
   (S2 saturates it, same mechanism as L0's). Non-vacuous: the clean crash
   verdict is judged at 388 genuinely post-crash states. *)
let lc_gate_states : int = 388

(* MEASURED per-member counts, all-states / post-crash. Crash moves NO
   store-side truth (prediction confirmed): the leg is clean with a
   saturated gate, and the store premises keep firing across the crash
   (S1 244 of the 388 post-crash states). *)
let s1_interesting_lc : int = 296
let s2_interesting_lc : int = 464
let s3_interesting_lc : int = 296
let s1_interesting_lc_post_crash : int = 244
let s2_interesting_lc_post_crash : int = 388
let s3_interesting_lc_post_crash : int = 244

(* ==== Ld: drop-only {0;1;0} =============================================== *)

(* MEASURED: clean, decisive, drop edge REALLY taken. States / fault-free
   slice DERIVED by graph identity (= P16 Ld = P15 L2x: 744 / 152). *)
let ld_states : int = P16_witness.ld_states
let ld_fault_free_states : int = P16_witness.ld_fault_free_states

(* MEASURED 592: the post-drop union gate = the whole post-drop slice. *)
let ld_gate_states : int = 592

(* MEASURED per-member counts, all-states / post-drop. HONEST-NEGATIVE
   (spec section 4's "Ld premise counts ~ L0's" prediction REFUTED under
   the density reading): S1/S3 fire at 376/744 = 50.5% of Ld's states vs
   52/76 = 68.4% of L0's - the fabricated Error response stalls the
   reconciler's create on the dropped branch, DILUTING the >= 2-objects
   slice, so the drop edge does perturb the premise DENSITY even though it
   never touches the store content itself (the mechanism half of the
   prediction stands, measured: [max_uid_seen]/[max_rv_seen] are L0's
   exact 3/2 on Ld). Recorded as a finding, not massaged. *)
let s1_interesting_ld : int = 376
let s2_interesting_ld : int = 744
let s3_interesting_ld : int = 376
let s1_interesting_ld_post_drop : int = 272
let s2_interesting_ld_post_drop : int = 592
let s3_interesting_ld_post_drop : int = 272

(* ==== Lm: monkey-only {0;0;1} - the leverage edge ========================= *)

(* MEASURED: clean, decisive, monkey edge REALLY taken. States / fault-free
   slice DERIVED by graph identity (= P16 Lm = P15 L3x: 1976 / 152). *)
let lm_states : int = P16_witness.lm_states
let lm_fault_free_states : int = P16_witness.lm_fault_free_states

(* MEASURED 1824: the post-monkey union gate = the whole post-monkey slice. *)
let lm_gate_states : int = 1824

(* MEASURED per-member counts, all-states / post-monkey. Prediction
   CONFIRMED - the monkey is the amplification edge: S1/S3 density rises to
   1624/1976 = 82.2% (vs L0's 68.4%, Ld's 50.5%) and the monkey's injected
   create is a REAL transitive etcd write ([max_uid_seen] = [max_rv_seen]
   = 4 on this graph alone at [vct:false], P16-D's own datum) - yet all
   three members hold at every one of the 1976 states: the server-side
   guards absorb the monkey churn. *)
let s1_interesting_lm : int = 1624
let s2_interesting_lm : int = 1976
let s3_interesting_lm : int = 1624
let s1_interesting_lm_post_monkey : int = 1520
let s2_interesting_lm_post_monkey : int = 1824
let s3_interesting_lm_post_monkey : int = 1520

(* ==== E1 / E2 exclusion pins (spec section 3), measured on the L0 graph == *)

(* MEASURED 0: E1's strengthening delta is EXTENSIONALLY EMPTY on the L0
   graph - the upstream :110/:185 well-formed members (weakly + the
   [installed_types]-driven [unmarshallable_object] / [valid_object]
   conjuncts, evaluated with the leg cluster's OWN [installed_types])
   agree with shipped S2 state-by-state at all 76 states. The exclusion is
   measured, not asserted. *)
let e1_delta_l0 : int = 0

(* MEASURED 0: E2's premise rendering (a stored key whose kind is NOT a
   custom-resource kind AND equals the VStatefulSet kind) is satisfied at
   ZERO of the 76 L0 states - unsatisfiable exactly as the upstream
   contradiction predicts (objects_in_store.rs:270-271 vs
   spec/resource.rs:122-123). *)
let e2_premise_l0 : int = 0

(* MEASURED 76: the E2 CONTROL - a vsts-kind stored key exists at EVERY L0
   state (the seed stores the CR), so the premise's second conjunct alone is
   satisfiable everywhere and the zero above is attributable to the
   CONTRADICTION, never to an empty store. *)
let e2_control_l0 : int = 76

(* MEASURED 0: the kind-coverage control for BOTH pins - no L0 state stores
   a key that is a custom-resource kind other than the VStatefulSet kind, so
   E1's builtin+custom conjunction quantifies over every stored key and its
   state-by-state agreement with S2 is about the same key set. *)
let uncovered_kind_l0 : int = 0

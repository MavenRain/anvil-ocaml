(* BUILD-SPEC-P22 section 6: the SINGLE SOURCE OF TRUTH for the P22
   scale-down witness - the bound, the seed's surplus-ordinal list, the four
   leg-matrix budgets (SL0 / SLc / SLd / SLm), and every pinned MEASURED
   number of the
   {!Anvil_checker.Fault_check.check_scale_down_under_faults} leg (states,
   family gates and per-member [interesting] counts over the four NEW
   graphs). A shared non-test module (not in the [dune] [(names ...)] list,
   so dune links it into every test exe that references it), following the
   [p21_witness.ml] / [p20_witness.ml] precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. [t_p22_scaledown],
   [t_p22_mutation] and [t_p22_regression] read every count from here and
   re-type none of them. ([lib/checker/fault_check.mli]'s prose disclosure
   of the same runs, and BUILD-SPEC-P22 section 8, are documentation, not
   second assertion sites.)

   THE ONE SANCTIONED EXCEPTION (the P14-P21 firewall rationale, stated at
   p21_witness.ml:18-30 and honoured unchanged): [t_p22_regression.ml]
   re-types the five INHERITED graph literals (76 / 464 / 744 / 1976 / 116)
   as its prior-phase firewall, and holds them against this module's chain
   re-exports below. Those are P13-P21's numbers, not P22-MEASURED ones, and
   the duplication is the POINT: "fix the red by editing the witness" has to
   redden somewhere. No P22-MEASURED count - the four SL state pins, the
   four SL gates or the sixteen per-member [interesting] counts below - is
   re-typed anywhere.

   GRAPH IDENTITY. The P22 graphs are NEW - the first phase since P20 to add
   any - and they are new BY SEED, not by seam: {!p22_bound} below is the
   leg's OWN record (P13's shape widened ADDITIVELY for the seed's one extra
   stored pod + one extra server-stamped create), and no committed input
   ([P13_witness.p13_bound], [Bound.default], [Scenario.vsts_seed_faults],
   [Scenario.vsts_cluster], [Scenario.controller_id],
   [Cluster.enabled_successors], [Fault_check.faulted_equal]/[hash]) is
   edited, so the five committed graphs are untouched BY CONSTRUCTION and
   their pins are re-exported below as pure chain derivations (P22 <- P21 <-
   P20 <- ... <- P13). MEASURED, not merely argued: t_p21_guarantee
   re-explored all five on the post-B3 tree - 76 / 464 / 744 / 1976 / 116
   byte-identical.

   THE HEADLINE (BUILD-SPEC-P22 sections 4/8, MEASURED 2026-07-30): {b G2
   [interesting] > 0 on EVERY leg} - SL0's count is the phase gate
   (prediction 1) that removes P21's family-wide G2 vacuity
   (p21_witness.ml:55-67); these are the first G2-live
   (condemned-exercising) VSTS graphs. Every leg CLEAN and DECISIVE; red 0
   on every member over every graph; on every leg the local replica's
   [Model_check.states_seen] matched the leg's own [states] EXACTLY.

   WHAT A RED WOULD MEAN: unchanged from P21 (p21_witness.ml:45-53) - G1-G4
   are discharged upstream, so a red on these graphs says the port's own
   reconciler emitted a request upstream proves its reconciler never emits:
   a FIDELITY divergence in the port, and a real finding. What is NEW here
   is only that G2's conjuncts (the owner-ref conjunct included - mutant
   MG6's target) are finally EVALUATED inside explored graphs, so P21's MG6
   stops being INERT-BY-VACUITY. The family gate below is the union gate G1
   dominates (the .mli-disclosed unfalsifiability); the per-member G2 floors
   therefore live in the TESTS, per member, never in the gate.

   CEILING DISCIPLINE (BUILD-SPEC-P8 section 4 rule; BUILD-SPEC-P22
   section 8 diagnosis): [max_uid_seen] / [max_rv_seen] stay STRICTLY below
   the widened 7/7 ceilings on every leg (worst case SLm - recorded in the
   spec, deliberately not pinned here). [pruned_by_ceiling = true] on all
   four legs and the residual was DIAGNOSED, not waved through: widening
   every OTHER ceiling leaves SL0 byte-identical, and ONLY
   [reconcile_ceiling] 2 -> 3 moves the graph (still pruning at 3) - the
   residual is exactly the inherited P13 [reconcile_ceiling = 2]
   coverage-cost clip (p13_witness.ml:13-29) that every committed graph
   asserts [true] (t_p14_correspondence.ml:467). [pruned_by_budget = true]
   on every leg including SL0: the seed's crash flag is ON and the budget
   clips the crash edges, the committed zero-budget rows' exact shape.

   PREDICTION 6, SCORED HONESTLY (spec section 8): [max_uid] 3 -> 4 vs the
   P21 L0 baseline CONFIRMED the one-extra-create arithmetic, but [max_rv]
   moved 2 -> 4 (+2, not +1): the condemned Get_then_delete's DELETE is a
   second rv-advancing write the estimate did not count. Recorded, not
   reworded.

   PROVENANCE OF EVERY NUMBER BELOW: MEASURED 2026-07-30 on this branch at
   stage B3 by the throwaway probes [probe/zz_p22_probe.ml] /
   [probe/zz_p22_ceiling.ml] (deleted after landing; replica technique =
   t_p21_guarantee.ml:193-237 verbatim), tabulated at BUILD-SPEC-P22
   section 8. [t_p22_scaledown] re-derives every one of them through the
   shipped exe; a disagreement between the two is a phase-STOP datum
   recorded at the pin, never a number to retune. Wall time: the full
   four-leg pass plus replicas ran ~67 s (SLm dominates) - under the ~150 s
   harness alarm.

   CONFIRMED BY MUTATION: the P22 matrix rows are RECORDED in
   t_p22_mutation.ml's header and BUILD-SPEC-P22 sections 5/8.1, re-typed
   nowhere else - this header stays qualitative by its own rule (P21 review
   finding 6: no MS/MG table literal in witness prose). MS3 and MS5 run
   AUTOMATED on every battery pass (MS3, the seed-sabotage control, in
   t_p22_scaledown; MS5, the premise wiring, in t_p22_mutation); the
   source-mutant rows MS1/MS2/MS4/MS6 follow the manual Edit-apply / probe /
   Edit-revert protocol and their verdicts land with the mutation stage.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   exceptions, no wildcard match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

(* ==== the P22 bound: an OWN record, DERIVED additively, never an edit ======
   BUILD-SPEC-P22 section 3. The P13 crash-only shape (unretuned through nine
   phases) with exactly THREE fields widened for the seed's one extra stored
   pod and one extra server-stamped create: [max_objects_per_kind] 4 -> 5,
   [uid_ceiling] 6 -> 7, [rv_ceiling] 6 -> 7. Derived from
   {!P13_witness.p13_bound} - the phase that owns the shape - rather than
   re-typed, so a P13 retune propagates here instead of silently diverging;
   [p13_bound] itself is NOT edited and the committed graphs keep their
   bound. The "+1" headroom is disclosed as landing on an already-slack P13
   ceiling: the measured maxima sit strictly below it (header). *)
let p22_bound ~(desireds : int list) : Bound.t =
  let base : Bound.t = P13_witness.p13_bound ~desireds in
  {
    base with
    Bound.max_objects_per_kind = base.Bound.max_objects_per_kind + 1;
    uid_ceiling = base.Bound.uid_ceiling + 1;
    rv_ceiling = base.Bound.rv_ceiling + 1;
  }

(* Single-CR witness shape and depth, DERIVED (shared with P13-P21);
   [p22_ordinals] is the phase's one NEW shape constant: a single surplus
   pod at ordinal 1 (>= the desired 1, so condemned-by-construction;
   pod-0 deliberately ABSENT, so the fault-free trace also exercises the
   create path - BUILD-SPEC-P22 section 2's reconcile trace). *)
let witness_desired : int = P21_witness.witness_desired
let witness_depth : int = P21_witness.witness_depth
let p22_ordinals : int list = [ 1 ]

(* The section-3 matrix budgets, DERIVED from P21 (never re-typed):
     SL0  zero    {0;0;0}  fault-free control ([~require_fault:false])
     SLc  crash   {1;0;0}  crash dimension
     SLd  drop    {0;1;0}  drop dimension  ([~req_drop:true])
     SLm  monkey  {0;0;1}  monkey dimension ([~pod_monkey:true])
   Leg ORDER is the MG5 lesson (zero-budget FIRST, then faults): the B3
   probe ran the fault legs only after SL0's phase gate passed, and
   t_p22_scaledown's test order preserves that discipline. *)
let zero_budget : Fc.budget = P21_witness.zero_budget
let slc_budget : Fc.budget = P21_witness.lc_budget
let sld_budget : Fc.budget = P21_witness.ld_budget
let slm_budget : Fc.budget = P21_witness.lm_budget

(* ==== PIN SAFETY: the five committed graph pins, DERIVED ===================
   P22 touches no committed seed, no committed bound field and no state
   field ({!p22_bound} is a NEW record), so all five committed graphs are
   untouched BY CONSTRUCTION; re-exported for the chain (P23 derives from
   here) and for t_p22_regression's firewall. MEASURED unmoved on the
   post-B3 tree (header). *)
let l0_states : int = P21_witness.l0_states
let lc_states : int = P21_witness.lc_states
let ld_states : int = P21_witness.ld_states
let lm_states : int = P21_witness.lm_states
let l0v_states : int = P21_witness.l0v_states

(* ==== the four NEW graphs: states and family gates =========================
   MEASURED (B3 probe, 2026-07-30) at [~desired = witness_desired],
   [~ordinals = p22_ordinals], [depth = witness_depth], {!p22_bound}.
   [gate_states] semantics are the P21 leg's verbatim (SOME member's premise
   fires, AND [budget_fault_taken] on the [~require_fault:true] legs). *)
let sl0_states : int = 88
let slc_states : int = 808
let sld_states : int = 1144
let slm_states : int = 10216
let sl0_gate_states : int = 20
let slc_gate_states : int = 276
let sld_gate_states : int = 96
let slm_gate_states : int = 2080

(* ==== per-member [interesting] counts ======================================
   MEASURED (B3 probe, 2026-07-30), G1/G2/G3/G4 in family order per graph.
   THE PHASE HEADLINE: every G2 count is NON-ZERO - on all four legs, not
   just SL0 - so P21's family-wide G2 vacuity ([interesting] = 0 on all five
   committed graphs) is REMOVED on this family, and the Delete_condemned
   emission is finally inside explored graphs. *)
let g1_interesting_sl0 : int = 4
let g2_interesting_sl0 : int = 4
let g3_interesting_sl0 : int = 4
let g4_interesting_sl0 : int = 20
let g1_interesting_slc : int = 80
let g2_interesting_slc : int = 104
let g3_interesting_slc : int = 32
let g4_interesting_slc : int = 296
let g1_interesting_sld : int = 32
let g2_interesting_sld : int = 40
let g3_interesting_sld : int = 16
let g4_interesting_sld : int = 136
let g1_interesting_slm : int = 240
let g2_interesting_slm : int = 432
let g3_interesting_slm : int = 704
let g4_interesting_slm : int = 2120

(* ==== the red headline =====================================================
   MEASURED (B3 probe, 2026-07-30): red 0 for EVERY member over EVERY new
   graph - the reconciler's Delete_condemned emission carries exactly the
   owner ref upstream proves it carries, measured on the first graphs that
   could have said otherwise. ONE constant, deliberately (the p21_witness
   rationale): the sixteen per-member red assertions all read it, so a
   future phase that measures a genuine red cannot "fix" one row without
   the other fifteen naming the same constant. *)
let scale_down_red_everywhere : int = 0

(* ==== family shape =========================================================
   NO NEW FAMILY is the phase's design pin (BUILD-SPEC-P22 section 2): the
   leg asserts the SHIPPED P21 register, so the cardinal is DERIVED, and
   t_p22_regression's roster records the identity loudly. *)
let guarantee_cardinal : int = P21_witness.guarantee_cardinal

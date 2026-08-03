(* BUILD-SPEC-P21 section 6: the SINGLE SOURCE OF TRUTH for the P21
   internal-guarantee witness - the bound, the shape, the four leg-matrix
   budgets (L0 / Lc / Ld / Lm), every pinned MEASURED number of the
   {!Anvil_checker.Fault_check.check_internal_guarantee_under_faults} leg
   (gates and per-member [interesting] counts over all five committed
   graphs), and the E-ledger cardinals of
   [vstatefulset_controller/proof/internal_rely_guarantee.rs]. A shared
   non-test module (not in the [dune] [(names ...)] list, so dune links it
   into every test exe that references it), following the [p20_witness.ml] /
   [p19_witness.ml] / [p18_witness.ml] precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. [t_p21_guarantee],
   [t_p21_mutation] and [t_p21_regression] read every count from here and
   re-type none of them. ([lib/checker/fault_check.mli]'s prose disclosure of
   the same runs, and BUILD-SPEC-P21 sections 8/8.1, are documentation, not
   second assertion sites.)

   THE ONE SANCTIONED EXCEPTION (the P14/P19/P20 firewall rationale, stated
   at p20_witness.ml:18-26 and honoured unchanged): [t_p21_regression.ml]
   re-types the five INHERITED graph literals (76 / 464 / 744 / 1976 / 116)
   as its prior-phase firewall, and holds them against this module. Those are
   P13-P20's numbers, not P21-MEASURED ones, and the duplication is the
   POINT: "fix the red by editing the witness" has to redden somewhere, which
   is impossible if every guard reads the very binding it is guarding. No
   P21-MEASURED count - the four gates or the twenty per-member
   [interesting] counts below - is re-typed anywhere. (The four upstream
   CITATION coordinates in [ledger_shipped_lines] also appear inside
   [t_p21_regression]'s committed (name, source) literals - the
   classification firewall, same rationale: file coordinates, not measured
   counts, and the duplication is what makes a citation drift redden.)

   GRAPH IDENTITY, DERIVED NOT RE-TYPED. The P21 leg threads NO new seam: no
   new [Bound.t] field, no [Cluster.cluster_state] field, no [?vct]
   (BUILD-SPEC-P21 section 3, the phase's strongest pin-safety property). It
   uses P16-P20's exact seed family ([Scenario.vsts_seed_faults
   ~crash:true], [vct] ABSENT = [false]), bound, depth and matrix budgets,
   and the product graph depends only on (seed, bound, budget, depth) -
   never on the invariant list checked over it - so the four leg graphs ARE
   the committed L0 / Lc / Ld / Lm and every graph-only constant below is
   DERIVED from {!P20_witness} (itself P19 <- P18 <- P17/P16 <- P15/P13).
   The [vct:true] L0v pin is DERIVED the same way. P21 introduces NO new
   graph constant at all - the first phase since P19 to add none (P20 added
   Lf and C1).

   WHAT A RED WOULD MEAN ON THE GUARANTEE FAMILY, said once here because
   these are the only pins in the tree that count it: G1-G4 are what the
   VSTS controller GUARANTEES to everyone else, and unlike P20's rely they
   ARE discharged upstream ([internal_guarantee_condition_holds],
   internal_rely_guarantee.rs:1003; [..._on_all_vsts], :1196). The epistemic
   reading is therefore the INVERSE of P20's: a P20 red indicts nobody (the
   environment left the assumed region); a red HERE says the port's own
   reconciler emitted a request upstream proves its reconciler never emits -
   a FIDELITY divergence in the port, and a real finding.

   HONEST VACUITY, family-wide (P14 N5; spec prediction 4 REFUTED in
   direction (a)): G2 ([vsts_internal_guarantee_get_then_delete_req]) is
   vacuous on ALL FIVE graphs - [interesting] = 0 everywhere, not just on
   L0. At [desired = 1] with no scale-down the reconciler never reaches its
   delete steps (v_stateful_set_reconciler.ml:734/:779), so G2's green is
   honest vacuity family-wide (the P20 PVC-arm class: disclosed, never
   narrowed away); its only live witness would be a scale-down scenario,
   banked as a P22 candidate. Direction (b) of the same refutation: G3
   FIRES on fault-free L0 ([interesting] 4) - the rolling-update path emits
   [Get_then_update_request] even in the fault-free run, against the spec's
   "plausibly zero on L0" lean. Consequence recorded at t_p21_mutation's
   MG6 row: a mutant whose only red witness is a G2 premise is INERT on
   every committed graph.

   L0v IS REPLICA-ONLY: the leg threads no [?vct] and builds its seed
   internally with [vct] absent, so the [vct:true] seed CANNOT reach it -
   exactly the t_p20_rely Leg-A shape (its L0v exists only as the
   pin-safety replica [l0v_reach]). The L0v row below is graph pin plus
   per-member counts; it has NO leg outcome and NO gate, and every consumer
   says so.

   PROVENANCE OF EVERY NUMBER BELOW: MEASURED 2026-07-28 on this branch by
   the throwaway probe [probe/zz_p21_probe.ml] (stage-B3 analogue; replica
   technique = t_p20_rely's [reach_of]/[fires]/[reds] verbatim), tabulated
   at BUILD-SPEC-P21 section 8. [t_p21_guarantee] re-derives every one of
   them through the shipped exe; a disagreement between the two is a
   phase-STOP datum recorded at the pin, never a number to retune. All five
   committed pins reproduced EXACTLY on the probe run; every leg CLEAN and
   DECISIVE; red 0 on every member over every graph.

   WALL TIME: the probe's full five-graph pass (leg plus local replica per
   graph, plus the MG7 re-replicas) completed in ~2 minutes on this machine
   - far under the ~150 s harness alarm; the shipped exe does strictly less
   exploration than the probe did.

   CONFIRMED BY MUTATION (a pin never SEEN to fail is not evidence; the
   matrix is manual - reconciler mutants need a full re-exploration - and
   its rows are RECORDED in t_p21_mutation.ml's header, protocol Edit apply
   / probe / Edit revert / [git diff --stat] empty per row; the moved-pin
   and red TABLES live there and in BUILD-SPEC-P21 section 8.1, re-typed
   nowhere else - this header stays qualitative by its own rule). MEASURED
   there: MG1 moved ALL FIVE graph pins and reddened G4 alone; MG2 and MG4
   each moved Lc and Lm and reddened G1 first; MG7 collapsed every
   [interesting] below to 0 at a non-matching
   controller id with red still 0 (vacuous truth, not vacuous falsity). So
   the pins, the counts and the premise have each been seen to move.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   exceptions, no wildcard match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

(* The P13 crash-only shape, unretuned through EIGHT phases now. P21 adds no
   field to it (BUILD-SPEC-P21 section 3: no new seam), which is why the five
   pin re-assertions below are derivations re-MEASURED rather than an
   inherited assumption left unexercised. *)
let p21_bound ~(desireds : int list) : Bound.t = P20_witness.p20_bound ~desireds

(* Single-CR witness shape and depth, shared with P13-P20 so the leg explores
   the SAME product graphs those phases pinned. *)
let witness_desired : int = P20_witness.witness_desired
let witness_depth : int = P20_witness.witness_depth

(* The section-3 matrix budgets, DERIVED from P20 (never re-typed):
     L0  zero    {0;0;0}  fault-free control ([~require_fault:false])
     Lc  crash   {1;0;0}  crash dimension
     Ld  drop    {0;1;0}  drop dimension  ([~req_drop:true])
     Lm  monkey  {0;0;1}  monkey dimension ([~pod_monkey:true])
   Unlike P20, L0/Lc/Ld are NOT vacuity rows here: the guarantee family's
   premise is CONTROLLER-sourced traffic, which exists without any adversary.
   The fault-dimension legs measure whether faults can PROVOKE the reconciler
   into an off-repertoire emission; MEASURED: they cannot. *)
let zero_budget : Fc.budget = P20_witness.zero_budget
let lc_budget : Fc.budget = P20_witness.lc_budget
let ld_budget : Fc.budget = P20_witness.ld_budget
let lm_budget : Fc.budget = P20_witness.lm_budget

(* ==== PIN SAFETY (spec section 3: "no new seam") ===========================
   The five committed graph pins, DERIVED from the phase that first measured
   each (P20 <- P19 <- ... <- P13; L0v via P20 <- P18 <- P16), so a moved pin
   reddens HERE and in that phase's own exe simultaneously. The leg touches
   no seed, no bound field and no state field, so all five MUST come back
   unmoved; a drift is a phase-STOP, never a retune.

   MEASURED (probe, 2026-07-28): all five unchanged. *)
let l0_states : int = P20_witness.l0_states
let lc_states : int = P20_witness.lc_states
let ld_states : int = P20_witness.ld_states
let lm_states : int = P20_witness.lm_states
let l0v_states : int = P20_witness.l0v_states

(* ==== the family-level gates (spec prediction 3) ===========================
   [gate_states] = states passing the leg's OWN gate predicate
   (fault_check.ml:1093-1099): SOME member's premise fires (a VSTS-sourced
   request in flight) AND, on the [~require_fault:true] legs Lc/Ld/Lm,
   [budget_fault_taken] - so those three gates sit BELOW their graph's G4
   [interesting] count by exactly the pre-fault states, while L0's
   ([~require_fault:false]) equals its G4 count (G4's premise is ANY
   VSTS-sourced request, i.e. the family-level premise). MEASURED non-zero
   on every leg, so no leg is an N5-vacuity row at the family level -
   prediction 3 CONFIRMED. L0v has no gate (replica-only row; the leg never
   runs on it). *)
let l0_gate_states : int = 16
let lc_gate_states : int = 140
let ld_gate_states : int = 32
let lm_gate_states : int = 336

(* ==== per-member [interesting] counts ======================================
   MEASURED (probe, 2026-07-28), G1/G2/G3/G4 in family order per graph. Every
   G2 count is 0 - the family-wide honest vacuity described in the header -
   and every OTHER member fires on every graph, including G3 on the
   fault-free L0 (prediction 4 refuted in both directions). *)
let g1_interesting_l0 : int = 4
let g2_interesting_l0 : int = 0
let g3_interesting_l0 : int = 4
let g4_interesting_l0 : int = 16
let g1_interesting_lc : int = 68
let g2_interesting_lc : int = 0
let g3_interesting_lc : int = 16
let g4_interesting_lc : int = 156
let g1_interesting_ld : int = 24
let g2_interesting_ld : int = 0
let g3_interesting_ld : int = 8
let g4_interesting_ld : int = 64
let g1_interesting_lm : int = 24
let g2_interesting_lm : int = 0
let g3_interesting_lm : int = 200
let g4_interesting_lm : int = 368
let g1_interesting_l0v : int = 8
let g2_interesting_l0v : int = 0
let g3_interesting_l0v : int = 4
let g4_interesting_l0v : int = 28

(* ==== the red headline =====================================================
   MEASURED (probe, 2026-07-28): red 0 for EVERY member over EVERY graph -
   the port's reconciler emits nothing upstream proves it never emits, on any
   committed graph, under any single-dimension fault budget. ONE constant,
   deliberately: the twenty per-member red assertions all read it, so a
   future phase that measures a genuine red cannot "fix" one row without the
   other nineteen naming the same constant. *)
let guarantee_red_everywhere : int = 0

(* ==== family shape =========================================================
   The G1-G4 cardinal. internal_guarantee.mli declines to assert it (the
   no-exception house rule); the tests pin it from here. *)
let guarantee_cardinal : int = 4

(* ==== the E-ledger cardinals (spec section 2.2) ============================
   [proof/internal_rely_guarantee.rs] has exactly NINE [pub open spec fn]
   ([rg -c 'pub open spec fn'] = 9, counted at build time). The partition is
   TOTAL and DISJOINT.

   RE-PARTITIONED BY P23 (BUILD-SPEC-P23 §2.2), and this is a RE-PARTITION,
   NOT A RED. P21 wrote 4 shipped + 5 excluded and ledgered E3-E5
   (:606 / :613 / :640) as the controller-LOCAL register, excluded on the
   ground that the port's [ongoing_reconcile.local_state] is an untyped
   [Value.t] and the VSTS reconcile step is not exposed. Both halves are false
   today ([pending_req_msg] is exposed at controller.mli:57 and the typed state
   is reachable through [V_stateful_set_pack.unmarshal_state]), so P23 SHIPS
   E4 :613 as L1 and E5 :640 as L2
   ({!Anvil_assurance.Local_binding.binding_family}). The reversal was
   PRE-AUTHORIZED in those words: BUILD-SPEC-P22.md:279-281 records that
   t_p21_regression's clause "reds only if P23 ships E3-E5, deliberately".

   RE-PARTITIONED AGAIN BY P25 (BUILD-SPEC-P25 §1.1, §2), superseding the P23
   paragraph's E3 bullet: E3 :606 - the LIFT of E5 over every VSTS-kind key in
   [ongoing_reconciles], "L2 wearing a hat" on every single-CR scenario, the
   exact ground P21 used for its own E1 - now SHIPS as the standalone
   {!Anvil_assurance.Internal_guarantee.local_pods_and_pvcs_are_bound_to_vsts},
   evaluated over the UNCHANGED committed multi-CR graphs (P12 fair
   [desireds=[1;1]] rc=3, P13 G2 crash rc=2) that de-vacuize the lift.

   The partition after P25 is 7 shipped + 2 excluded, still total and disjoint
   at nine:
     shipped 7 - G4 :544, G1 :562, G2 :581, G3 :589 (P21);
                 E3 :606 (P25); L1 :613, L2 :640 (P23)
     E1      1 - :522, the quantified closure; collapses to G4 on a single-CR
                 scenario, so shipping it would be "G4 wearing a hat"
     E2      1 - :528; ALREADY SHIPPED semantically as P19's M1 under its
                 [helper_invariants.rs:1213] citation (re-measured at P21:
                 SEMANTICALLY IDENTICAL, one [is_controller_id] unfolding
                 apart)
   Shipped lines ASCENDING (G4's :544 is lowest; upstream defines the StatePred
   before its helpers). P23 RENAMED the joint E3/E4/E5 bucket down to an
   E3-only bucket rather than shrinking it in place, and P25 RENAMED THAT
   BUCKET AWAY entirely when E3 shipped, so a stale reader of either retired
   name fails to compile instead of silently reading a narrower bucket. *)
let ledger_spec_fn_count : int = 9
let ledger_shipped_lines : int list = [ 544; 562; 581; 589; 606; 613; 640 ]
let ledger_e1_lines : int list = [ 522 ]
let ledger_e2_lines : int list = [ 528 ]

(* BUILD-SPEC-P23 section 6: the SINGLE SOURCE OF TRUTH for the P23
   controller-LOCAL binding witness - the bound, the leg-matrix shape
   constants, the five leg budgets (BL0 / BLc / BLd / BLm / BN0) and, once
   stage B has run, every pinned MEASURED number of the
   {!Anvil_checker.Fault_check.check_local_binding_under_faults} leg. A shared
   non-test module (not in the [dune] [(names ...)] list, so dune links it into
   every test exe that references it), following the [p22_witness.ml] /
   [p21_witness.ml] / [p20_witness.ml] precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. The P23 tests read every count
   from here and re-type none of them. ([lib/checker/fault_check.mli]'s prose
   disclosure of the same runs, and BUILD-SPEC-P23 section 8, are
   documentation, not second assertion sites.)

   THE ONE SANCTIONED EXCEPTION (the P14-P22 firewall rationale, stated at
   p21_witness.ml:18-30 and honoured unchanged): [t_p23_regression.ml] will
   re-type the INHERITED graph literals as its prior-phase firewall and hold
   them against this module's chain re-exports below. Those are P13-P22's
   numbers, not P23-MEASURED ones, and the duplication is the POINT: "fix the
   red by editing the witness" has to redden somewhere.

   ==== STATUS OF THIS MODULE, STATED HONESTLY ==============================
   STAGE B HAS RUN (BUILD-SPEC-P23 section 8, 2026-07-30) and stage C ran the
   whole mutation matrix on top of it (section 8.10). Everything from the
   [==== MEASURED] banner below down to [l2_name] IS a P23 measurement and is
   PINNED: the four gates, the per-member [interesting] counts, the red zeros,
   the premise-side counters. Everything ABOVE that banner is what remains
   DERIVED shape constants and CHAIN RE-EXPORTS of already-committed pins. The
   two kinds must never be confused, because they fail differently: a MEASURED
   constant that moves is a phase-STOP diagnosis, never a retune.

   Nothing was back-filled into section 4's ten PREDICTIONS and no prediction
   was edited to agree with a measurement. Prediction 5 was REFUTED - the
   needed conjunct is LIVE, not vacuous (section 8.3) - and prediction 6 was
   CONFIRMED (section 8.5); both are recorded as such at their constants below.

   THERE IS NO SECOND MEASURED BLOCK TO ADD HERE. The one block below is
   closed. A later phase that measures something new opens its own witness
   module; appending a second block here would re-type numbers this file
   already owns and break the no-number-in-two-files rule stated above.

   GRAPH IDENTITY, and why the committed pins cannot move. The P23 leg REUSES
   P22's graphs rather than adding any: same seed
   ({!Anvil_assurance.Scenario.vsts_seed_with_pods} at the same [~desired] /
   [~ordinals]), same bound (derived from {!P22_witness.p22_bound} with no
   widening), same budgets, same depth. [Fault_check.run_leg] passes
   [Model_check.explore] only [~depth ~successors ~equal ~hash ~init] and
   [explore] takes no invariant argument, so GRAPHS ARE FAMILY-BLIND: swapping
   the asserted family cannot move a state count. No committed input
   ([P13_witness.p13_bound], [Bound.default], [Scenario.vsts_seed_faults],
   [Scenario.vsts_cluster], [Scenario.controller_id],
   [Cluster.enabled_successors], [Fault_check.faulted_equal]/[hash]) is
   edited. A moved pin is a phase-STOP, never a retune.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   exceptions, no wildcard match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

(* ==== the P23 bound: an OWN record, DERIVED, never an edit =================
   BUILD-SPEC-P23 section 3. Derived from {!P22_witness.p22_bound} - the phase
   that owns the widening - rather than re-typed, so a P22 retune propagates
   here instead of silently diverging; [p22_bound] itself is NOT edited and
   the committed graphs keep their bound.

   NO WIDENING IS APPLIED. The spec authorises an ADDITIVE widening only if
   the [~ordinals:[0;1]] needed-live instantiation demands one, and that
   instantiation is UNMEASURED and CONDITIONAL (BUILD-SPEC-P23 section 3, leg
   BN0). Until it is measured, the identity derivation is what keeps the four
   shipped legs on P22's graphs exactly - which is the whole basis of
   prediction 8. *)
let p23_bound ~(desireds : int list) : Bound.t =
  P22_witness.p22_bound ~desireds

(* Single-CR witness shape and depth, DERIVED (shared with P13-P22).
   [p23_ordinals] is the SHIPPED instantiation, derived from P22's - one
   surplus pod at ordinal 1, pod-0 deliberately absent - so the four shipped
   legs sit on P22's graphs by construction.

   [p23_needed_ordinals] is the CONDITIONAL de-vacuizer of BUILD-SPEC-P23
   section 2.1 exclusion 2: pod-0 PRESENT makes L1's [needed] forall non-empty
   (with [~ordinals:[1]] the single needed slot is [None] forever, so
   upstream :617's [is Some] guard is false at every state and the conjunct is
   VACUOUS). It is UNMEASURED, it adds [Update_needed] / [Get_then_update]
   traffic no committed graph contains, and it falls OUTSIDE the shipped
   seed-integrity predicate ([Scenario.vsts_seed_pods_intact] requires every
   requested ordinal be [>= replicas], which 0 is not), so the BN0 leg ships
   ONLY if stage B measures it convergent and bounded. The constant is
   recorded here so the decision is made against a named shape rather than a
   literal typed at the call site. *)
let witness_desired : int = P22_witness.witness_desired
let witness_depth : int = P22_witness.witness_depth
let p23_ordinals : int list = P22_witness.p22_ordinals
let p23_needed_ordinals : int list = 0 :: P22_witness.p22_ordinals

(* The section-3 matrix budgets, DERIVED from P22 (never re-typed):
     BL0  zero    {0;0;0}  fault-free control ([~require_fault:false])
     BLc  crash   {1;0;0}  crash dimension
     BLd  drop    {0;1;0}  drop dimension  ([~req_drop:true])
     BLm  monkey  {0;0;1}  monkey dimension ([~pod_monkey:true])
     BN0  zero    {0;0;0}  CONDITIONAL needed-live control
   Leg ORDER is the MG5 lesson (zero-budget FIRST, then faults): BL0's phase
   gate (L2 [interesting] > 0, prediction 1) is diagnosed before any fault leg
   is run. *)
let zero_budget : Fc.budget = P22_witness.zero_budget
let blc_budget : Fc.budget = P22_witness.slc_budget
let bld_budget : Fc.budget = P22_witness.sld_budget
let blm_budget : Fc.budget = P22_witness.slm_budget

(* ==== PIN SAFETY: the nine committed graph pins, DERIVED ===================
   P23 touches no committed seed, no committed bound field and no state field,
   and graphs are family-blind, so all nine committed graphs are untouched BY
   CONSTRUCTION. Re-exported for the chain (P24 derives from here) and for
   t_p23_regression's firewall.

   The five P13-P21 pins (76 / 464 / 744 / 1976 / 116) and the four P22 pins
   (88 / 808 / 1144 / 10216) with P22's four gates (20 / 276 / 96 / 2080). *)
let l0_states : int = P22_witness.l0_states
let lc_states : int = P22_witness.lc_states
let ld_states : int = P22_witness.ld_states
let lm_states : int = P22_witness.lm_states
let l0v_states : int = P22_witness.l0v_states
let sl0_states : int = P22_witness.sl0_states
let slc_states : int = P22_witness.slc_states
let sld_states : int = P22_witness.sld_states
let slm_states : int = P22_witness.slm_states
let sl0_gate_states : int = P22_witness.sl0_gate_states
let slc_gate_states : int = P22_witness.slc_gate_states
let sld_gate_states : int = P22_witness.sld_gate_states
let slm_gate_states : int = P22_witness.slm_gate_states

(* ==== PREDICTION 8, recorded as a DERIVATION, not as a new literal =========
   BUILD-SPEC-P23 section 4 prediction 8: the four shipped P23 legs reuse
   P22's [(seed, bound, budget, depth)] exactly, and graphs are family-blind,
   so their state counts must EQUAL P22's. Expressing that as an alias rather
   than as four new numbers is what makes the prediction falsifiable in one
   place: if stage B measures anything else, these bindings are what redden,
   and the answer is a phase-STOP diagnosis, never a retune. *)
let bl0_states : int = sl0_states
let blc_states : int = slc_states
let bld_states : int = sld_states
let blm_states : int = slm_states

(* ==== family shape ========================================================
   The register's cardinal (L1 :613, L2 :640). The (name, source) literals
   themselves live in [Anvil_assurance.Local_binding.binding_sources] and are
   restated by t_p23_regression under the firewall rationale (a guard must not
   read the very binding it guards); they are NOT re-typed here. *)
let binding_cardinal : int = 2

(* ==== MEASURED (BUILD-SPEC-P23 section 8, stage B, 2026-07-30) =============
   ONE block, landed after the leg was run, each constant answering a numbered
   prediction of section 4. Nothing here was back-filled into the predictions
   and no prediction was edited to agree with a measurement - prediction 5 was
   REFUTED and is recorded as such (section 8.3), not repaired.

   Every t_p23_* pin reads THIS module. No number below appears in any other
   file except t_p23_regression's deliberate re-typing of the INHERITED
   P13-P22 literals (the firewall rationale at the head of this file). *)

(* ---- 8.1: the four shipped legs' family GATE (prediction 9: UNPREDICTED,
   now measured). The gate is the leg-COMPUTED union of the two members'
   [interesting] (fault_check.ml's [~gate] closure over the leg's OWN [invs]),
   surfaced as [fault_report.gate_states] - the ONE coupling with teeth
   between the leg's family binding and this test suite (BUILD-SPEC-P22's F2
   correction, restated in BUILD-SPEC-P23 section 3). These are NOT derivable
   from P22's 20 / 276 / 96 / 2080: a different family's interesting-union is
   a different number, and they are far LARGER because the binding family's
   premises are cheaper to satisfy, which is not a stronger register. *)
let bl0_gate_states : int = 68
let blc_gate_states : int = 560
let bld_gate_states : int = 816
let blm_gate_states : int = 7920

(* ---- 8.1: per-member [interesting], from the REPLICA technique
   (t_p21_guarantee.ml:193-237). PER-MEMBER ATTRIBUTION IS NOT AVAILABLE FROM
   THE LEG: L1 is CONTAINED in L2 (upstream :642 calls E4) and
   [Invariants.first_violated] (invariants.ml:1046) is FIRST-IN-LIST-ORDER, so
   the leg's [violated] would name L1 for ANY shared-conjunct failure and L2
   would look green. Every per-member count below is therefore computed
   test-side over a replica whose [Mc.states_seen] is asserted equal to the
   leg's own [states] first. *)
let l1_interesting_bl0 : int = 52
let l1_interesting_blc : int = 516
let l1_interesting_bld : int = 664
let l1_interesting_blm : int = 6496
let l2_interesting_bl0 : int = 16
let l2_interesting_blc : int = 112
let l2_interesting_bld : int = 288
let l2_interesting_blm : int = 1560

(* ---- 8.1 / prediction 3: red = 0 for BOTH members on ALL four graphs. ONE
   constant, deliberately (the [P21_witness.guarantee_red_everywhere]
   precedent): the eight per-member red assertions all read it, so a future
   phase that measures a genuine red cannot "fix" one row without the other
   seven naming the same constant. A red here is a FIDELITY DIVERGENCE in the
   port, not an environment datum. *)
let binding_red_everywhere : int = 0

(* ---- 8.1: the premise-side counters, same replicas.

   [decoded_*] is the count of states whose reconcile at the scenario CR key
   EXISTS and DECODES. On every P23 graph it equals the count of states where
   the reconcile merely exists, which is the same statement as
   [decode_failures_everywhere = 0] read from the other side; the suite
   asserts both, because the two are independent observations and the
   equality is the content. *)
let decoded_bl0 : int = 76
let decoded_blc : int = 680
let decoded_bld : int = 1056
let decoded_blm : int = 8872

(* Prediction 4, CONFIRMED: decode failures are 0 on every P23 graph, so the
   [~undecodable] fold arm of [Local_binding.at_reconcile] is NEVER exercised.
   That is exactly what makes matrix row MB6 (flip [~undecodable:true] to
   [false] on L1's [holds]) a real control rather than a formality: a mutant
   that changes nothing PROVES this counter, and one that changes something
   REFUTES the prediction. Basis: [marshal_state] always writes all seven
   members (v_stateful_set_pack.mli), so port-produced states never default. *)
let decode_failures_everywhere : int = 0

(* Prediction 5, REFUTED (section 8.3). It said L1's needed-witness count is
   EXACTLY 0 on BL0/BLc/BLd/BLm because [~ordinals:[1]] leaves the single
   needed slot [None] forever. It is not 0. The cites in BUILD-SPEC-P23
   section 2.1 are accurate; the INFERENCE from them fails, because the port
   RE-RECONCILES: pod-0 is created in one round and a LATER round re-lists the
   pods, so [partition_pods] puts the now-existing pod-0 into the needed slot
   as [Some]. The needed conjunct C1 ships AS WRITTEN - no exclusion, no pin,
   no de-vacuizer. The mechanism is pinned below, not argued. *)
let needed_witness_bl0 : int = 20
let needed_witness_blc : int = 200
let needed_witness_bld : int = 208
let needed_witness_blm : int = 3616

(* Prediction 5's second half, CONFIRMED: the condemned witness is > 0
   everywhere (the surplus pod at ordinal 1 is condemned every round). *)
let condemned_witness_bl0 : int = 32
let condemned_witness_blc : int = 456
let condemned_witness_bld : int = 520
let condemned_witness_blm : int = 3136

(* Section 8.3's MEASURED mechanism for the refutation, on BL0. Every one of
   the 20 needed-witness states has pod-0 IN ETCD and none lacks it, which is
   the round-to-round mechanism and no other. The 36 states that hold pod-0
   with the slot still [None] are the ones INSIDE the round that created it -
   precisely the half of the section 2.1 argument that IS true. *)
let bl0_needed_witness_with_pod0 : int = 20
let bl0_needed_witness_without_pod0 : int = 0
let bl0_pod0_in_etcd : int = 64

(* THE COMPLEMENT, and a CORRECTION to section 8.3 that is recorded rather than
   quietly absorbed. Section 8.3 prints "pod-0 in etcd AND needed slot None =
   36" beside "pod-0 in etcd (all states) = 64" and "needed_some AND pod-0 in
   etcd = 20". Those three cannot all describe the same complement: 64 - 20 is
   44, not 36. Both readings are MEASURED here and pinned separately, because
   they are two different predicates and only one of them is the complement:

   - [bl0_pod0_in_etcd_no_witness] = 44: pod-0 is stored and L1's needed
     WITNESS does not fire. This is the arithmetic complement of the 20, and it
     includes states with no ongoing reconcile at all and states whose decoded
     [needed] list is EMPTY (the round has not partitioned yet).
   - [bl0_pod0_in_etcd_decoded_no_witness] = 36: pod-0 is stored, the reconcile
     at the CR key EXISTS and DECODES, and the needed witness still does not
     fire. This is the reading that reproduces section 8.3's printed 36, and it
     is the intended one - the states INSIDE the round that created pod-0,
     which is the half of BUILD-SPEC-P23 section 2.1's argument that IS true.
     The eight-state gap to 44 is the states holding pod-0 with NO ongoing
     reconcile at all, which no statement about a needed slot can be about.
   - [bl0_pod0_in_etcd_needed_slot_none] = 24: the strictest reading - pod-0
     stored, decoded, the [needed] list NON-EMPTY, and every slot in it [None].
     The twelve-state gap to 36 is the decoded states whose [needed] list is
     still [[]] because the round has not partitioned yet.

   All three are pinned, because "the needed slot is None" is three different
   predicates and the probe dump does not say which it meant. Recording them
   all is what turns an inconsistent dump into a measurement. *)
let bl0_pod0_in_etcd_no_witness : int = 44
let bl0_pod0_in_etcd_decoded_no_witness : int = 36
let bl0_pod0_in_etcd_needed_slot_none : int = 24

(* Section 8.6, the PVCS-EXCLUSION PIN. The pvcs forall :629-637 is NOT
   ported; the omission is made behavior-free by this pin, asserted over EVERY
   P23 graph: no decoded ongoing state has a PVC. 10684 decoded states across
   the four graphs and not one PVC, so the pin is not vacuous for want of
   decoded states. The moment a [vct:true] leg lands it reddens - t_p23_mutation
   measures exactly that (row MB7) on a THROWAWAY [vct:true] replica. *)
let pvcs_non_empty_everywhere : int = 0

(* Section 8.5 supporting row: states at [After_list_pod], and the subset
   whose PENDING request is a pod [List_request] in the CR's namespace
   addressed to the api server (upstream :646-651). The three counts coincide
   with [l2_interesting_*] on every graph, and that coincidence is the
   MEASURED content of 8.5: upstream :646-651 is not a filter that happens to
   pass, it is exercised at 100 percent of the states where it can be. They
   are recorded as their OWN literals rather than derived from
   [l2_interesting_*], because deriving them would assert the coincidence
   instead of measuring it. *)
let parked_bl0 : int = 16
let parked_blc : int = 112
let parked_bld : int = 288
let parked_blm : int = 1560
let parked_pod_list_bl0 : int = 16
let parked_pod_list_blc : int = 112
let parked_pod_list_bld : int = 288
let parked_pod_list_blm : int = 1560

(* Prediction 6, CONFIRMED on EVERY graph (section 8.5): states parked at
   [After_list_pod] with a pending request AND at least one matching ok
   [List_response] in flight - the PREMISE of L2's inner forall :652-657. This
   was the prediction most likely to be refuted and it was UNVERIFIED in the
   tree; the conjunct is LIVE, so it is DISCLOSED, not pulled. *)
let ok_list_resps_bl0 : int = 8
let ok_list_resps_blc : int = 60
let ok_list_resps_bld : int = 48
let ok_list_resps_blm : int = 816

(* "The premise fires" is weaker than "the body is evaluated": on BL0 all 8 of
   the 8 states carry a matching ok [List_response] whose [objs] list is
   NON-EMPTY, so [resp_objs_in_namespace] (upstream :659-661) is applied to
   real objects rather than folding over an empty list. *)
let bl0_ok_list_resps_with_objs : int = 8

(* Section 8.1's MEASURED gate decomposition on BL0: the two premises are
   DISJOINT there (at [After_list_pod] the partition has not run yet, so
   [needed] and [condemned] are both empty and L1's witness is false exactly
   where L2's is true), and the gate is a clean sum. NEITHER MEMBER DOMINATES
   - the P23 analogue of P21's "G1 dominates the union gate" disclosure, with
   the opposite verdict. The disjointness is a BL0 fact only: on the fault
   graphs the union is strictly smaller than the sum. *)
let bl0_gate_l1_only : int = 52
let bl0_gate_l2_only : int = 16
let bl0_gate_both : int = 0

(* ---- family shape, MEASURED-adjacent: the two member names, in family
   order. The (name, source) LITERALS are restated by t_p23_regression under
   the firewall rationale (a guard must not read the very binding it guards)
   and are NOT re-typed here; these names are what the per-member counting
   projections address the family BY, so a rename makes every projection
   constantly [false] and the [> 0] floors in t_p23_local_binding redden
   LOUDLY before any count could quietly go 0. *)
let l1_name : string = "vsts_local_pods_and_pvcs_bound_in_local_state"
let l2_name : string = "vsts_local_pods_and_pvcs_bound_with_key"

(* ==== THE MUTATION MATRIX, RUN (section 8.10), and what stays open =======
   - The SOURCE rows HAVE been run. Stage C, 2026-07-30: reconciler and member
     edits whose observable is a full re-exploration, each applied and reverted
     by the manual Edit-apply / probe / Edit-revert protocol, with the restore
     proof and a re-verification of all thirteen committed pins in section
     8.11. Outcomes: MB1 KILLED (BL0 flips CLEAN -> REFUTED and [violated]
     names L2). MB2 as specced in section 5 SURVIVED - the recipe was wrong
     about the mechanism, [pod_filter] already requiring the ordinal to parse -
     and MB2-b, the same edit plus TWO more coordinated reconciler sites,
     KILLED with L1 red = 32. MB3 MEASURED rather than argued. MB4 TRAP HELD,
     L2 staying green by design. MB5 KILLED. MB6 SURVIVED at graph level, its
     fold being dead code under prediction 4's zero above, then KILLED at unit
     level by t_p23_mutation's [mb6_decode_failure_fold], which supplies the
     undecodable local state no graph produces. MB7 KILLED, so the
     pvcs-are-empty pin above HAS now been seen to redden. MB8 KILLED FOUR
     independent assertions: three were measured in the matrix run itself, and
     the fourth - t_p21_regression's POSITIVE bare-source row at
     t_p21_regression.ml:465-471, RESHAPED onto the committed literals
     [613; 640] because the original shape took its expected value from the
     expression under test and was MEASURED to pass under this very mutant -
     was measured in the review-fix pass, where it fails
     Expected: [613; 640] / Received: [640]. MB9, added by that same pass,
     KILLED at unit level by t_p23_mutation's [mb9_inner_consequent]: L2's
     inner-forall CONSEQUENT (upstream :659-661) is RED on a forged in-flight
     ok [List_response] carrying an out-of-namespace object and GREEN on the
     same shape carrying the CR's own namespace, with four controls passing
     first. The controls behaved: X1 and X2 KILLED with the graph pins
     UNMOVED, and X3, the over-pinning control, SURVIVED as required.
   - Section 7's conditional was measured NOT TRIGGERED. It said that if L1
     could not be SEEN red it must be downgraded to EXCLUDE-WITH-A-PIN. L1 HAS
     been seen red (MB2-b), so it SHIPS AS A MEMBER and no re-partition of the
     E-ledger follows. What section 7 keeps is only the weaker reading: L1 is
     hard to falsify, three coordinated source edits hard, and the shipped seed
     pods are built from [pod_name] directly rather than through [make_pod], so
     seed integrity is untouched by that mutant.
   - STILL OPEN, disclosed rather than deleted (section 8.10). L2's
     GRAPH-level red capability rests on MB1 alone: MB9 gives L2's
     inner-forall CONSEQUENT its own red-capability row, but that row is at
     STATE level and its state is REACHABLE-BY-FORGERY ONLY - no shipped
     graph reaches it, because no shipped leg's api server answers a
     namespaced list with an out-of-namespace object - so it is not a claim
     that the consequent fires on a shipped graph. Upstream :646
     ([pending_req_msg.dst] is the api server) still has no mutation row of
     its own. MB4's wrong-namespace [Get_then_delete]
     leaves L2 red = 0 on BL0 and BLc with the leg CLEAN, and is caught only by
     graph-size and premise-vacuity pins elsewhere, so a red anywhere in the
     battery is NOT L2 coverage. And under a real shared-conjunct red (MB3 on
     BL0) L2's GATED red column reports nothing at all - L1 [interesting] 64
     with red 32, L2 [interesting] 16 with red 0 - while L2's UNGATED [holds]
     is false at exactly the same 32 states. Only the ungated column shows the
     containment; that hazard is disclosed in [local_binding.mli], not closed.
     One thing section 8.8 asked for is also deliberately NOT done: no
     [monkey_forge] leg was added, because MB2-b reached L1 without one.
   - BN0 ([~ordinals:[0;1]], section 8.4) is MEASURED but NOT SHIPPED as a leg:
     its only purpose was to de-vacuize a conjunct that 8.3 measures live, so
     shipping a fifth graph would add a pin and a seed-integrity obligation for
     no assurance. [p23_needed_ordinals] above stays as the recorded shape. Its
     measured numbers (88 states at a depth-25 fixpoint, gate 68, L1 52, L2 16,
     needed-witness 52) are deliberately NOT pinned here - pinning a graph no
     shipped exe explores would be a pin nothing can move. *)

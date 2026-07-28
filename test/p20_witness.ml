(* BUILD-SPEC-P20 section 5: the SINGLE SOURCE OF TRUTH for the P20
   rely-condition witness - the bound, the shape, the four Leg-A matrix
   budgets (L0 / Lc / Ld / Lm), the two FORGE graphs (Lf, and the C1
   containment control), every pinned MEASURED number of the
   {!Anvil_checker.Fault_check.check_rely_conditions_under_faults} and
   {!Anvil_checker.Fault_check.check_rely_forge_under_faults} legs, their
   per-member [interesting] and RED counts, the P18-H1 cross-reads that carry
   spec predictions 5 and 7, and the E4 scope-ledger cardinals. A shared
   non-test module (not in the [dune] [(names ...)] list, so dune links it
   into every test exe that references it), following the [p19_witness.ml] /
   [p18_witness.ml] / [p17_witness.ml] precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. [t_p20_rely], [t_p20_mutation]
   and [t_p20_regression] read every count from here and re-type none of them.
   ([lib/checker/fault_check.mli]'s prose disclosure of the same runs is
   documentation, not a second assertion site.)

   THE ONE SANCTIONED EXCEPTION, added at B6 (the P14/P19 firewall rationale):
   [t_p20_regression.ml:105-109] re-types the five INHERITED graph literals
   (76 / 464 / 744 / 1976 / 116) as its prior-phase firewall, and holds them
   against this module. Those are P13-P19's numbers, not P20-MEASURED ones,
   and the duplication is the POINT: "fix the red by editing the witness" has
   to redden somewhere, which is impossible if every guard reads the very
   binding it is guarding. No P20-MEASURED count - the gates, the per-member
   [interesting]/red counts, {!lf_states}, {!c1_states}, {!c1_forged_key_states}
   or the E4 cardinals - is re-typed anywhere.

   GRAPH IDENTITY, DERIVED NOT RE-TYPED: Leg A uses P16-P19's exact seed
   family ([Scenario.vsts_seed_faults ~crash:true], [vct] ABSENT = [false] -
   the leg signature has no [?vct]), bound, depth and matrix budgets, and the
   product graph depends only on (seed, bound, budget, depth) - never on the
   invariant list checked over it - so the four Leg-A graphs ARE P13-P19's
   L0 / Lc / Ld / Lm graphs and every graph-only constant below is DERIVED
   from {!P19_witness} / {!P18_witness} (themselves derived from
   P17 <- P16 <- P15/P13). The [vct:true] L0v pin is DERIVED from
   {!P18_witness} (itself P16's).

   THE TWO FORGE GRAPHS ARE NEW LITERALS, and they are the ONLY new graph
   constants this phase introduces (spec section 5 prediction 8). They come
   from the SAME seed / budget / depth as Lm and differ from it in exactly
   one input: [Bound.monkey_forge] is a one-element list, so the pod-monkey
   candidate list is [max_objects_per_kind + 1] long instead of
   [max_objects_per_kind] (cluster.ml:748-768). Lf carries
   {!Anvil_checker.Fault_check.rely_violating_forge}, C1 carries
   {!Anvil_checker.Fault_check.rely_respecting_forge}.

   WHAT A RED COUNT MEANS ON THE RELY FAMILY, said once here because these
   are the only pins in the tree that count them: R1/R2/R3 are what upstream
   ASSUMES about the environment and never discharges (rely_conditions.mli),
   so a red state is an ASSUMPTION-VIOLATION datum - the environment left the
   region upstream's proof assumes - and is NOT a defect in Anvil and NOT a
   soundness finding against the port.

   PROVENANCE OF EVERY NUMBER BELOW: MEASURED 2026-07-27 on this branch by
   [t_p20_rely] itself (stage B4). Stage B3 measured the same quantities with
   a THROWAWAY probe; B4 re-derived them through this shipped exe and every
   B3 number reproduced EXACTLY, with zero disagreements. Where B4 and B3 had
   disagreed, the B4 number would be the pin and the disagreement would be
   recorded at the pin - there was none.

   WALL TIME (the whole exe, both forge graphs included, same machine as the
   battery): 22.4 s standalone / 25.2 s inside [dune build @runtest] - far
   under the ~150 s harness alarm. The two forge graphs dominate it: Lf and C1
   are each explored TWICE (once by the leg, once by the local replica the
   per-member counts need), and at ~7000 states apiece that is ~3.5x Lm's
   1976.

   CONFIRMED BY MUTATION (a pin never SEEN to fail is not evidence). Two
   single-token mutations in [rely_conditions.ml] together neuter the family
   on its Pod arm ([vsts_prefix] -> a string nothing starts with, and the
   collapse test's [V_stateful_set.kind] -> [Pod.kind]). MEASURED: {!lm_states}'
   leg flips REFUTED -> CLEAN, so the headline verdict tracks the family and is
   not a constant. Predicted and observed NOT to move under the same mutant:
   {!lm_gate_states} stayed > 0 (the premise mirrors read only [src] and
   message content, never the reddening mechanism) and {!lm_states} stayed
   1976 (the product graph is family-blind - the derivation the whole witness
   chain rests on). Both mutations were reverted by exact [Edit] and [git diff]
   verified empty against the index.

   Firewall: List/Option/fold combinators only, no loop keywords, no wildcard
   match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

(* The P13 crash-only shape, unretuned through SEVEN phases now - and this
   phase is the first to ADD a field to it ([Bound.monkey_forge], default
   [[]]), which is exactly why prediction 1 below is a measured gate rather
   than an inherited assumption. *)
let p20_bound ~(desireds : int list) : Bound.t = P19_witness.p19_bound ~desireds

(* Single-CR witness shape and depth, shared with P13-P19 so the legs explore
   the SAME product graphs those phases pinned. *)
let witness_desired : int = P19_witness.witness_desired
let witness_depth : int = P19_witness.witness_depth

(* The section-4 matrix budgets, DERIVED from P19 (never re-typed):
     L0  zero    {0;0;0}  fault-free control - an honest VACUITY row here
     Lc  crash   {1;0;0}  crash dimension    - an honest VACUITY row here
     Ld  drop    {0;1;0}  drop dimension     - an honest VACUITY row here
     Lm  monkey  {0;0;1}  THE HEADLINE LEG, and the family's only live one
   Lf and C1 reuse [lm_budget] unchanged: the forge rides the EXISTING
   [Step.Pod_monkey_step] and is charged [Monkeys], so no fourth budget
   dimension exists (spec section 4.2's second hard prohibition). *)
let zero_budget : Fc.budget = P19_witness.zero_budget
let lc_budget : Fc.budget = P19_witness.lc_budget
let ld_budget : Fc.budget = P19_witness.ld_budget
let lm_budget : Fc.budget = P19_witness.lm_budget

(* ==== PIN SAFETY (spec section 4.2 / section 5 prediction 1) ==============
   The five committed graph pins, re-asserted with [Bound.monkey_forge]
   PRESENT and defaulted to [[]]. The argument that they cannot move is in
   [bound.mli] ([Cluster_check.state_equal] / [state_hash] /
   [Fault_check.faulted_equal] / [faulted_hash] read only
   [Cluster.cluster_state] and the three counters, never a [Bound.t]), but
   the spec required the argument be MEASURED and not merely argued - a green
   argument that was never run is not evidence. Each is DERIVED from the
   phase that first measured it, so a moved pin reddens HERE and in that
   phase's own exe simultaneously.

   MEASURED (B4): all five unchanged, prediction 1 CONFIRMED. *)
let l0_states : int = P19_witness.l0_states
let lc_states : int = P19_witness.lc_states
let ld_states : int = P19_witness.ld_states
let lm_states : int = P19_witness.lm_states

(* The [vct:TRUE] zero-budget graph, DERIVED from P18 (itself P16's). Leg A
   has no [?vct] (fault_check.mli: the monkey emits pod-keyed requests only,
   so R1/R2's PVC arm is unreachable regardless), so this pin is checked
   through a local replica off the [~vct:true] seed rather than through a
   leg - it is a PIN-SAFETY check on the [Bound.t] edit, not a rely
   measurement. *)
let l0v_states : int = P18_witness.l0v_states

(* ==== Leg A: L0 / Lc / Ld - the HONEST VACUITY rows ========================
   Spec section 5 prediction 2. No monkey step is enabled on these three
   budgets, so no message with [src = Pod_monkey] can exist, so every
   member's premise ([interesting]) is structurally 0 and every member is
   vacuously green. This is a MODELLING FACT reported as a vacuity row (the
   P14 N5 discipline), never as a pass: nothing about the rely condition was
   exercised on L0, Lc or Ld.

   MEASURED (B4): union gate 0 on all three, every per-member [interesting]
   0, every per-member RED 0. Prediction 2 CONFIRMED. *)
let l0_gate_states : int = 0
let lc_gate_states : int = 0
let ld_gate_states : int = 0
let r1_interesting_l0 : int = 0
let r2_interesting_l0 : int = 0
let r3_interesting_l0 : int = 0
let r1_interesting_lc : int = 0
let r2_interesting_lc : int = 0
let r3_interesting_lc : int = 0
let r1_interesting_ld : int = 0
let r2_interesting_ld : int = 0
let r3_interesting_ld : int = 0

(* ==== Lm: monkey-only {0;0;1} - THE HEADLINE, and it is FORGE-FREE ========
   Spec section 5 predictions 3 and 4, on a graph P13 committed and five
   phases have re-measured. The port's monkey re-sends STORED pods
   byte-identically (cluster.ml:748-756), and every pod the reconciler mints
   carries the VSTS CONTROLLER OWNER REF ([make_owner_references],
   v_stateful_set_reconciler.ml:218-220, stamped into the pod metadata by
   [make_pod] at :379) - exactly what rely_guarantee.rs:68-69 (R1's conjunct
   (b)) and :82-83 / :85 (R2's conjuncts (b)/(c)) forbid a monkey request to
   carry. So every monkey [Create_pod] / [Update_pod] on a stored vsts pod is
   ALREADY a rely-violating in-flight message. No forge is needed to cross the
   rely boundary; the boundary has been crossed since P13.

   THE REDNESS RESTS ON THAT OWNER-REF CONJUNCT ALONE (BUILD-SPEC-P20
   REVIEW-FIX D; this block used to credit the minted NAME PREFIX,
   v_stateful_set_reconciler.ml:191, and mention no owner ref). The minted
   name is vsts-prefixed and that conjunct fails too, but the phase MEASURED
   the prefix conjunct non-load-bearing from both sides: section 7's ML2 row
   (the family's [has_vsts_prefix] forced constant-false - not one leg moved)
   and its ML1 row (the reconciler's minted prefix mutated - R1/R2 stayed RED
   while H1's premise starved 1624 -> 0), both in t_p20_mutation.ml and
   tabulated at BUILD-SPEC-P20 section 5.4. The prefix conjunct is present but
   NOT load-bearing.

   MEASURED (B4) - the non-vacuity floor first (prediction 3): R3's gate on
   Lm is 832 > 0, so the leg measured something. *)
let lm_gate_states : int = 832

(* -- per-member [interesting]-fires counts over Lm's 1976 states. MEASURED
   (B4): R1 208 (a monkey-sourced [Create_request] in flight), R2 208 (an
   [Update_request]), R3 832 (ANY monkey-sourced [Api_request] - the four
   arms the monkey actually emits, P19's measured repertoire, so R3's premise
   is strictly wider than R1's + R2's). *)
let r1_interesting_lm : int = 208
let r2_interesting_lm : int = 208
let r3_interesting_lm : int = 832

(* -- per-member RED counts over the same 1976 states. MEASURED (B4):
   R1 208 of 208 and R2 208 of 208 - EVERY premise-firing state is red on
   both arms - and R3 416 of 832, the union of the two (the R1-red and
   R2-red state sets are DISJOINT here: measured, since a monkey create and
   a monkey update never coexist in flight at [max_in_flight = 3] on this
   graph).

   {b THE PHASE-STOP CLAUSE (spec section 5.4).} Had [r2_red_lm] measured 0,
   section 1's premise-refutation would itself have been refuted, the
   headline would have died, and the phase would have STOPPED for a spec
   revision. It is 208. *)
let r1_red_lm : int = 208
let r2_red_lm : int = 208
let r3_red_lm : int = 416

(* ==== Prediction 5: the CORRECTED READING of P18's headline ===============
   P18 reported "Lm CLEAN = the monkey-rely headline landed as predicted".
   That reading was wrong, and P20 measures why: H1 is green on Lm even
   though the assumption its upstream proof RESTS ON is false there
   (helper_invariants.rs:82 requires the monkey rely). So P18's Lm result is
   an EMERGENT-ROBUSTNESS result, not a rely-consistency one.

   MEASURED DIRECTLY (B4), not inferred from P18's committed numbers:
   P18's H1 red count over the SAME 1976-state Lm graph is 0, while R3 is
   red at {!r3_red_lm} = 416 of them. Assumption violated WITHOUT
   consequence. Prediction 5 CONFIRMED. *)
let h1_red_lm : int = 0

(* ==== Prediction 6: the R3 <=> R1 && R2 redundancy identity ===============
   [rely_conditions.mli] discloses the redundancy UP FRONT (the P17
   overlap-misread discipline applied before the fact): R3's match at
   rely_guarantee.rs:23-27 has exactly two constrained arms and they are R1's
   and R2's bodies. R1/R2 exist for ATTRIBUTION - so a measurement can say
   WHICH arm reddens - not as independent facts.

   WHAT THE PIN BUYS, and it is narrow (BUILD-SPEC-P20 REVIEW-FIX A; this
   block previously claimed it measured "agreement between two separate
   renderings", which is FALSE). The 0 is FORCED BY CONSTRUCTION and holds for
   ANY definition of the two helpers: R3's two constrained arms
   (rely_conditions.ml:240, :241) call the IDENTICAL [rely_create_req] /
   [rely_update_req] that R1 (:180) and R2 (:208) call, over the identical
   [msgs s] (:21-22) reached through the identical [monkey_request_of]
   (:39-44). Per message the three verdicts are (R1, R2, R3) =
   (rely_create_req, true, rely_create_req) on a Create,
   (true, rely_update_req, rely_update_req) on an Update, and (true, true,
   true) on the other seven arms and on [None]; since
   [for_all f l && for_all g l = for_all (fun x -> f x && g x) l], the
   identity holds pointwise. So this pin is a REFACTOR GUARD on R3's
   arm-DISPATCH shape - it reddens if R3 stops routing Create/Update to the
   helpers R1/R2 route them to - and it is BLIND to every defect INSIDE those
   helpers: forcing [rely_create_req] to a constant [true] still yields 0
   disagreements on all six graphs. Checking it at 16,692 states across six
   graphs therefore yields exactly the information ONE state yields. The
   honest statements of the same fact are rely_conditions.mli:73-75 and
   t_p20_mutation.ml:30-33.

   MEASURED (B4): 0 disagreeing states on every graph this phase explores -
   L0 (76), Lc (464), Ld (744), Lm (1976), Lf (7064) and C1 (6368), 16,692
   states in total. Prediction 6 CONFIRMED, and forced. *)
let r3_identity_disagreements : int = 0

(* ==== Lf: the RELY-VIOLATING forge leg (spec section 4.3) =================
   THE ONLY NEW GRAPH CONSTANTS OF THE PHASE (prediction 8). Same seed /
   budget / depth as Lm; the single input that differs is
   [Bound.monkey_forge = [Fault_check.rely_violating_forge ~desired:1]].

   FRAMING, and it must travel with the number: Lf's red is an
   ASSUMPTION-NECESSITY witness. It shows the rely condition is LOAD-BEARING
   for H1 rather than decorative. It is not a defect in Anvil, and it is not
   "we broke H1" - the forge is precisely an environment step upstream's
   [environment_rely] slot forbids.

   MEASURED (B4): 7064 states. *)
let lf_states : int = 7064

(* Leg B's gate, and it is NOT "a forge step was taken": it counts states
   where the forged object has ACTUALLY REACHED ETCD and H1's [pod_premise]
   fires on its key (fault_check.ml:1025-1047, the premise copied verbatim
   from helper_invariants.ml:58-62). A zero here would mean the leg measured
   NOTHING - the create was rejected at admission, or the name does not parse
   as an ordinal, or the namespace is wrong - and would have to be read as a
   failed experiment, never as a clean run.

   MEASURED (B4): 1560 > 0. *)
let lf_gate_states : int = 1560

(* MEASURED (B4) 1560: H1's red count over the same 7064 states - EXACTLY the
   gate. H1 is red at precisely the gated states and nowhere else, which is
   the attribution the gate exists to license: the red is the forged pod's,
   not the run's. Prediction 7 CONFIRMED. *)
let h1_red_lf : int = 1560

(* -- the rely family read over Lf (context rows, not the leg's own claim -
   Leg B checks H1/H2, not R1-R3). MEASURED (B4): every member's premise
   fires far more often than on Lm (the forge adds a pod-monkey candidate at
   every state), and R1/R2 are red at EVERY premise-firing state again. *)
let r1_interesting_lf : int = 712
let r2_interesting_lf : int = 712
let r3_interesting_lf : int = 2848
let r1_red_lf : int = 712
let r2_red_lf : int = 712
let r3_red_lf : int = 1424

(* ==== C1: the CONTAINMENT CONTROL (spec section 7 row C1) =================
   The measured stand-in for the rely-respecting forger LEG that section 1
   deliberately did not ship (upstream's own containment lemmas
   helper_lemmas.rs:92-102 / :80-90 make that leg's green a foregone
   conclusion). [Bound.monkey_forge = [Fault_check.rely_respecting_forge
   ~desired:1]]: byte-identical to the violating forge except in the two
   rely-relevant fields (non-vsts-prefixed name, no vsts owner ref), and it
   KEEPS the finalizer - which is what makes the control sharp. H1's green
   here is attributable to its premise never firing on the name, not to a
   harmless payload.

   This row is what makes Lf's red DECISIVE: it attributes the red to
   RELY-VIOLATION rather than to forging as such.

   MEASURED (B4): 6368 states. *)
let c1_states : int = 6368

(* MEASURED (B4) 0: H1's red count over C1's 6368 states. The control is
   GREEN. *)
let h1_red_c1 : int = 0

(* MEASURED (B4) 864: states where the RESPECTING forge's key is present in
   etcd, counted WITHOUT the [pod_premise] conjunct.

   THE EXCEPTION A READER MUST KNOW (B3 MEASURED-CORRECTION 2, and
   fault_check.mli carries it too): C1's [gate_states] is STRUCTURALLY 0 no
   matter how well the run went, because the respecting forge's key never
   satisfies [pod_premise] - that is the entire point of the control. So
   section 4.3's "a zero gate means the leg measured nothing" does NOT apply
   to C1; reading C1's zero as a failed experiment inverts the row's meaning.
   THIS count, not the gate, is what proves the C1 forge actually LANDED
   rather than being rejected at admission - so C1's green is CONTAINMENT,
   not admission rejection. *)
let c1_forged_key_states : int = 864

(* -- the rely family read over C1 (context rows). MEASURED (B4): the
   [interesting] counts match Lf's exactly (712 / 712 / 2848 - the monkey's
   emission structure is the same, one extra candidate either way), while the
   RED counts fall back to Lm's exactly (208 / 208 / 416). The
   rely-RESPECTING forge adds no rely violation of its own, exactly as its
   name says: every red on C1 is one the echo monkey was already producing on
   Lm forge-free. *)
let r1_interesting_c1 : int = 712
let r2_interesting_c1 : int = 712
let r3_interesting_c1 : int = 2848
let r1_red_c1 : int = 208
let r2_red_c1 : int = 208
let r3_red_c1 : int = 416

(* ==== E1 / E4 exclusion-pin cardinals (spec section 3) ====================

   E1 (the OTHER-CONTROLLER rely, rely_guarantee.rs:32 / :39): excluded
   because both shipped spines install exactly ONE controller model, so
   upstream's [controller_models.remove(controller_id)] is EMPTY and the
   [forall other_id] is vacuously true in every reachable state of every leg.
   That is the HONEST reason, not "out of scope", and it is
   scenario-conditional: a P9-style two-controller spine would make E1 live.
   The pin reddens if a future spine installs a second controller, re-opening
   E1 rather than leaving it silently stale.

   MEASURED (B4): 1 controller model on each spine, 0 after removing
   [Scenario.controller_id]. *)
let spine_controller_models : int = 1
let spine_controller_models_after_removal : int = 0

(* E4 SCOPE PIN (spec section 3, corrected by B1). [trusted/rely_guarantee.rs]
   has exactly 12 [pub open spec fn] - the spec body says 13, which B1
   COUNTED and refuted. The SHIPPED/LEDGERED partition is total at 12:
   3 shipped (R1 :57, R2 :76, R3 :17) + E1 2 (:32, :39) + E3 3 (:92, :105,
   :120) + E2 4 (:133, :152, :164, :176). *)
let e4_spec_fn_count : int = 12
let e4_shipped_lines : int list = [ 17; 57; 76 ]
let e4_e1_lines : int list = [ 32; 39 ]
let e4_e3_lines : int list = [ 92; 105; 120 ]
let e4_e2_lines : int list = [ 133; 152; 164; 176 ]

(* E3's permissiveness roster (spec section 3): the seven
   [Api_method.api_request] arms upstream's [_ => true] at
   rely_guarantee.rs:26 admits ("Deletion/UpdateStatus requests are
   allowed"). The count is the family's own exhaustive match arity minus the
   two constrained arms, and [t_p20_rely] asserts each one green under a
   MAXIMALLY rely-violating payload with two red controls beside it, so the
   green is content and not an injection that never landed. *)
let e3_permitted_arms : int = 7

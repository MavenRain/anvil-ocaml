(* BUILD-SPEC-P24 section 6 - the prior-phase firewall and the roster's
   generation step for the phase that ships the STATE-PREDICATE register, the
   first shipped members of
   [vstatefulset_controller/proof/liveness/state_predicates.rs].

   THE CLASSIFICATION, in its exact MEASURED wording, because the tempting
   sentence here is the one that goes stale. The novelty gate is FILE-level and
   the probe that measures it is
   [rg -n 'state_predicates' lib test -g '!*.md'], which exited 1 before this
   phase. The un-flagged form recorded at BUILD-SPEC-P23.md:765 now exits 0 on
   MARKDOWN SELF-MATCHES ONLY - the count rises as the phase documents itself -
   so that form must never be quoted; quoting it would manufacture a fake
   regression, the same class of defect as a fake green. What is NOT claimed:
   that the CONJUNCTS are new to the tree. One of M3's is already carried by
   P23's L2, and that containment is disclosed per-member in
   state_predicates.mli rather than sold as coverage.

   THE FAMILY IS TWO MEMBERS, AND IT WAS THREE. The M2 candidate (upstream
   [req_msg_is_list_pod_req] :45 closed by :59-66) was written, measured,
   mutation-tested and CUT, because rendered over these four graphs it is
   ENTIRELY CONTAINED in P23's L2 - five conjuncts literally, :65 by a measured
   entailment, and :49 unwitnessed at 0 over denominators 16 / 112 / 288 / 1560.
   That is a FINDING, recorded in state_predicates.ml{,i}, and it is why this
   file's committed pairs, roster-coverage rows and source partition all speak
   of TWO. A copy-forward that still names :45 reds here, which is the point.

   ---- what this file DOES --------------------------------------------------

   - THE PRIOR-PHASE FIREWALL: the P13-P23 graph literals re-typed here (the
     one sanctioned duplication - p21_witness.ml:18-30 states the standing
     rationale, p24_witness.ml restates it for this phase) AND held against the
     chain {!P24_witness} claims to derive them from. "Fix the red by editing
     the witness" has to redden somewhere, and this is where. P23's four GATE
     pins (68 / 560 / 816 / 7920) and its premise-side pins are included: they
     are P23-MEASURED, hence PRIOR-phase for P24. THE THREE GRAPH-DETERMINING
     CHAIN PARAMETERS ARE INCLUDED TOO - [witness_desired] = 1,
     [witness_depth] = 40 and the shipped ordinals = [1] - because P13-P23 held
     each of them only in the [x = x] alias form and no test in this tree pinned
     them against a number (section 1a states the case). NO P24-MEASURED NUMBER
     IS RE-TYPED HERE. Stage B pinned THREE vacuity literals -
     [P24_witness.after_delete_outdated_occupancy_everywhere = 0], the :241
     exclusion pin; [P24_witness.ok_resp_some_unowned_obj_everywhere = 0], the
     owner-reference filter's reject-path zero; and
     [P24_witness.pending_src_not_controller_everywhere = 0], the zero the M2
     candidate was CUT on - and the main loop's SCOPE ruling added the probe-B5
     SCOPE-EXCLUSION pins (the measured refutation of upstream :116-118 and
     :119-124). Every one of them is asserted where it is MEASURED, in
     t_p24_state_predicates' step-histogram, B3-control, B4 and
     [scope_exclusion_pin] cases, and none is re-typed here: the firewall
     exists to catch a witness edited to match a moved GRAPH, and NONE of those
     is a graph literal.

   - THE COMMITTED MEMBER IDENTITIES: M1's and M3's (name, source) pairs
     as LITERALS (the P17 [expected_pairs] pattern,
     t_p17_regression.ml:170-178), checked pair-for-pair against the shipped
     register in family order, so a rename, a re-sourced citation, an added /
     dropped / reordered member reddens HERE regardless of how the family is
     implemented. BOTH SOURCES ARE BARE and that is load-bearing: a
     parenthetical qualifier makes t_p21_regression's [line_of_source] return
     [None] and the member vanishes from the roster sweep silently
     (t_p24_mutation's MP8 row exhibits it). The CUT M2 candidate's :45 is
     ABSENT from the committed pairs rather than parked there as a qualified
     string: a cut member must not be reachable through the roster's input.

   - THE ROSTER, EXTENDED TO SIXTEEN AND THE SELF-EXCLUSION MOVED (the
     P20->P21->P22->P23 mechanism, re-run): t_p23_regression's roster was
     FIFTEEN with its own P23 entry excluded by label. HERE the P23 label loses
     its "THIS phase" marker and moves INTO the swept set, and the
     self-exclusion keys on [p24_label]. A VERBATIM COPY-FORWARD OF THE P23
     ROSTER REDS: that file's assertions name FIFTEEN explicitly.

   - THE SWEEP: the predicate family against the other FIFTEEN roster suites
     via {!Pair_guard.pair_leaks}, BOTH argument orders, expecting [[]]
     everywhere. RULING section 5 makes this an explicit obligation of the
     phase ("[pair_leaks] must be run in BOTH argument orders against the full
     roster and confirmed [[]] - that is not automatic"), and the sweep is
     SEEN red-capable against the roster's own P24 self-entry.

   - THE E-LEDGER IS UNTOUCHED IN EFFECT, NOT MERELY IN INTENT. Every
     assertion of t_p21_regression's reversal clause filters on the literal
     prefix ["vstatefulset_controller/proof/internal_rely_guarantee.rs:"]
     (:405-406) and every P24 source is [.../liveness/state_predicates.rs:NNN],
     so the P24 roster addition cannot reach that filter. This file MEASURES
     that rather than asserting it as a plan: it checks that no P24 source
     bears the guarantee prefix, and that the SIXTEEN-suite roster's
     guarantee-line inventory is still exactly {!P21_witness.ledger_shipped_lines}.
     A P24 member that acquired an internal_rely_guarantee.rs citation would
     redden here AND silently re-partition a ledger this phase does not own.

   ---- what it does NOT do (anti-duplication, the P15-P23 rationale) --------

   It does NOT re-run any leg (t_p24_state_predicates does), does NOT
   model-check anything (pure list work, milliseconds), does NOT re-pin any P24
   MEASURED number (there is none), and does NOT duplicate the E-LEDGER
   REVERSAL SWEEP, which keeps its SINGLE ASSERTION SITE in t_p21_regression
   (the house convention t_p22_regression.ml:93-96 names) - a file P24 EDITS,
   to add its roster entry, exactly as P23 did.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum, no two-arm match on
   [option]/[result], total accessors only, no indexing, no exceptions,
   Alcotest as the sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vsts_invariants = Anvil_assurance.Vsts_invariants
module Correspondence = Anvil_assurance.Correspondence
module Rec_corr = Anvil_assurance.Reconcile_correspondence
module Rr = Anvil_assurance.Req_resp_correspondence
module Ois = Anvil_assurance.Objects_in_store
module Hi = Anvil_assurance.Helper_invariants
module Mp = Anvil_assurance.Msg_provenance
module Rely = Anvil_assurance.Rely_conditions
module Ig = Anvil_assurance.Internal_guarantee
module Lb = Anvil_assurance.Local_binding
module Sp = Anvil_assurance.State_predicates
module W = P24_witness

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = W.witness_desired

(* The INHERITED chain bound for the P16 suite instantiation (the rv leg's own
   bound) - NOT {!P24_witness.p24_bound}, which is the P22/P23/P24 leg record
   and instantiates no roster suite. *)
let inherited_bound : Bound.t = P21_witness.p21_bound ~desireds:[ desired ]

(* P24's swept family: the state-predicate register instantiated with the
   arguments fault_check.ml's leg passes. That the leg passes these arguments
   is NOT asserted here (this file runs no leg); where leg-side drift IS caught
   is t_p24_state_predicates' leg-COMPUTED gate, which stage B pins. *)
let family : Invariants.invariant list =
  Sp.predicate_family ~cr:(Scenario.vsts ~desired ()) ~controller_id

let names_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.name) invs

let sources_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.source) invs

(* ==== 1. the prior-phase firewall ==========================================
   The graph literals as committed on the P13-P23 branches, held against the
   witness module P24's exes actually read. P24 adds NO seam: its bound is an
   identity derivation of P23's, it edits no committed seed, no state field and
   NOT the shared [faulted] block (fault_check.ml:37-145 - the one edit that
   could perturb all fourteen legs' graphs at once), and [run_leg] passes
   [explore] no invariant argument, so graphs are FAMILY-BLIND and these are
   pure derivation guards. A drift is a phase-STOP, never a retune. *)

let committed_l0_states : int = 76
let committed_lc_states : int = 464
let committed_ld_states : int = 744
let committed_lm_states : int = 1976
let committed_l0v_states : int = 116
let committed_sl0_states : int = 88
let committed_slc_states : int = 808
let committed_sld_states : int = 1144
let committed_slm_states : int = 10216
let committed_sl0_gate : int = 20
let committed_slc_gate : int = 276
let committed_sld_gate : int = 96
let committed_slm_gate : int = 2080

(* P23's OWN measurements, PRIOR-phase for P24: the four gates of the
   local-binding leg and the premise-side counters t_p24_state_predicates
   re-derives on the P24 legs. Re-deriving them under a DIFFERENT asserted
   family is the phase's evidence that graphs are family-blind, so the
   literals have to live somewhere a retune of the witness cannot follow. *)
let committed_bl0_gate : int = 68
let committed_blc_gate : int = 560
let committed_bld_gate : int = 816
let committed_blm_gate : int = 7920
let committed_decoded_bl0 : int = 76
let committed_decoded_blc : int = 680
let committed_decoded_bld : int = 1056
let committed_decoded_blm : int = 8872
let committed_parked_bl0 : int = 16
let committed_parked_blc : int = 112
let committed_parked_bld : int = 288
let committed_parked_blm : int = 1560
let committed_ok_list_resps_bl0 : int = 8
let committed_ok_list_resps_blc : int = 60
let committed_ok_list_resps_bld : int = 48
let committed_ok_list_resps_blm : int = 816
let committed_pvcs_non_empty : int = 0
let committed_decode_failures : int = 0

(* PREDICTION P1's BACKSTOP, AND IT HAS TO NAME A LITERAL.
   [P24_witness.sp0_states] and its three siblings are ALIASES
   (p24_witness.ml:190-193) of [bl0_states]..., which are themselves aliases
   (:147-150) of [P23_witness]'s, which alias P22's. So the form this file used
   to carry -

     check int "prediction P1: SPc states ARE BLc's" P23_witness.blc_states
       W.spc_states

   - is [x = x]. It holds for EVERY possible graph and observes nothing: if a
   widened SPc budget grew BLc from 808 to 812 states and the chain were
   re-pinned to match, the row would still pass, which is precisely the
   phase-STOP it claims to detect. The graph counts are P22-COMMITTED
   (88 / 808 / 1144 / 10216, the same four the [committed_sl*_states] above
   name), and P24's four legs must land on them, so THAT is what is asserted -
   a literal a retune of the witness cannot follow. Re-typed here rather than
   read off [committed_sl0_states] so that the SP row survives on its own if the
   SL chain is ever re-shaped. NOT a P24 measurement: it is P22's number, and
   prediction P1 is the claim that P24 inherits it. *)
let committed_sp0_states : int = 88
let committed_spc_states : int = 808
let committed_spd_states : int = 1144
let committed_spm_states : int = 10216

let test_p24_graph_constants_are_the_committed_literals () =
  Alcotest.(check int) "P24 L0 states = the committed 76" committed_l0_states
    W.l0_states;
  Alcotest.(check int) "P24 Lc states = the committed 464" committed_lc_states
    W.lc_states;
  Alcotest.(check int) "P24 Ld states = the committed 744" committed_ld_states
    W.ld_states;
  Alcotest.(check int) "P24 Lm states = the committed 1976" committed_lm_states
    W.lm_states;
  Alcotest.(check int)
    "P24 L0v states = the committed 116 (vct:true, replica only)"
    committed_l0v_states W.l0v_states;
  Alcotest.(check int) "P24 SL0 states = P22's committed 88" committed_sl0_states
    W.sl0_states;
  Alcotest.(check int) "P24 SLc states = P22's committed 808"
    committed_slc_states W.slc_states;
  Alcotest.(check int) "P24 SLd states = P22's committed 1144"
    committed_sld_states W.sld_states;
  Alcotest.(check int) "P24 SLm states = P22's committed 10216"
    committed_slm_states W.slm_states;
  Alcotest.(check int) "P24 SL0 gate = P22's committed 20" committed_sl0_gate
    W.sl0_gate_states;
  Alcotest.(check int) "P24 SLc gate = P22's committed 276" committed_slc_gate
    W.slc_gate_states;
  Alcotest.(check int) "P24 SLd gate = P22's committed 96" committed_sld_gate
    W.sld_gate_states;
  Alcotest.(check int) "P24 SLm gate = P22's committed 2080" committed_slm_gate
    W.slm_gate_states;
  (* P23's four gates: PRIOR-phase measurements for P24 *)
  Alcotest.(check int) "P24 BL0 gate = P23's committed 68" committed_bl0_gate
    W.bl0_gate_states;
  Alcotest.(check int) "P24 BLc gate = P23's committed 560" committed_blc_gate
    W.blc_gate_states;
  Alcotest.(check int) "P24 BLd gate = P23's committed 816" committed_bld_gate
    W.bld_gate_states;
  Alcotest.(check int) "P24 BLm gate = P23's committed 7920" committed_blm_gate
    W.blm_gate_states;
  (* P23's premise-side counters, which t_p24_state_predicates re-derives on
     the P24 legs through P24's OWN probes *)
  Alcotest.(check (list int))
    "P24's decoded-state chain re-exports = P23's committed 76 / 680 / 1056 / \
     8872"
    [
      committed_decoded_bl0;
      committed_decoded_blc;
      committed_decoded_bld;
      committed_decoded_blm;
    ]
    [ W.decoded_bl0; W.decoded_blc; W.decoded_bld; W.decoded_blm ];
  Alcotest.(check (list int))
    "P24's parked chain re-exports = P23's committed 16 / 112 / 288 / 1560 \
     (probe B4 quantifies over exactly this population)"
    [
      committed_parked_bl0;
      committed_parked_blc;
      committed_parked_bld;
      committed_parked_blm;
    ]
    [ W.parked_bl0; W.parked_blc; W.parked_bld; W.parked_blm ];
  Alcotest.(check (list int))
    "P24's ok-List-response chain re-exports = P23's committed 8 / 60 / 48 / \
     816 (probe B3 quantifies over exactly this population)"
    [
      committed_ok_list_resps_bl0;
      committed_ok_list_resps_blc;
      committed_ok_list_resps_bld;
      committed_ok_list_resps_blm;
    ]
    [
      W.ok_list_resps_bl0;
      W.ok_list_resps_blc;
      W.ok_list_resps_bld;
      W.ok_list_resps_blm;
    ];
  Alcotest.(check int)
    "the PVC pin M1's SEVEN PVC-pinned conjuncts die on = P23's committed 0"
    committed_pvcs_non_empty W.pvcs_non_empty_everywhere;
  Alcotest.(check int) "decode failures = P23's committed 0"
    committed_decode_failures W.decode_failures_everywhere;
  (* PREDICTION P1, against the COMMITTED LITERALS rather than against the chain
     the witness derives the four numbers from. This is the row a moved graph
     has to get past: [t_p24_state_predicates] checks the four legs against
     [W.sp*_states], so a witness re-pinned to a moved graph goes green THERE,
     and only a literal typed outside the chain reddens. *)
  Alcotest.(check (list int))
    "prediction P1: the four P24 leg graphs ARE the committed 88 / 808 / 1144 \
     / 10216 - a LITERAL, because the chain P24_witness derives them from makes \
     every same-chain comparison an identity"
    [
      committed_sp0_states;
      committed_spc_states;
      committed_spd_states;
      committed_spm_states;
    ]
    [ W.sp0_states; W.spc_states; W.spd_states; W.spm_states ]

(* ==== 1a. THE CHAIN PARAMETERS, AGAINST LITERALS ===========================

   THIS CASE WAS THIRTEEN [x = x] ROWS AND COULD NOT FAIL. It is the same defect
   prediction P1's backstop had one case up, one link further out. Twelve rows
   had the shape

     check int "P24 L0 = P23's L0 (derivation, not coincidence)"
       P23_witness.l0_states W.l0_states

   and [W.l0_states] IS [P23_witness.l0_states]: p24_witness.ml's tier 1 is
   aliases by construction and says so at :106-110. So the row read
   [P23_witness.l0_states = P23_witness.l0_states], which holds for every
   possible graph - a MOVED one, and a chain re-pinned to match it, included.
   THE THIRTEENTH ROW WAS THE SAME SHAPE AND ITS COMMENT DEFENDED IT as "a
   relation between two DIFFERENT bindings": it held [W.sl*_states] against
   [W.bl*_states], and p23_witness.ml:139-142 is [let bl0_states = sl0_states],
   so after substitution it too was [P23_witness.sl0_states =
   P23_witness.sl0_states]. Being two different NAMES is not being two different
   things.

   ---- WHAT IS COVERED, AND WHERE ------------------------------------------
   The nine graph counts those rows named are pinned against COMMITTED LITERALS
   in [test_p24_graph_constants_are_the_committed_literals] above: 76 / 464 /
   744 / 1976 / 116 for L0..L0v and P22's 88 / 808 / 1144 / 10216 for SL0..SLm.
   P23's own four graphs are reached by the SP rows there, because
   [W.sp0_states] IS [W.bl0_states] (p24_witness.ml:199-202), so
   [committed_sp0_states = W.sp0_states] IS the assertion [88 = W.bl0_states].
   Each of those is a real relation - one side is a literal typed in THIS file,
   outside the chain - so a witness re-pinned to a moved graph reddens there.
   NOTHING IS RESTATED HERE THAT THOSE ROWS ALREADY CARRY: a row entailed by a
   row that already exists adds no red capability, which is the defect this
   rewrite is removing, not one to re-introduce under a new name.

   ---- WHAT WAS COVERED NOWHERE, AND IS ASSERTED BELOW ----------------------
   The three CHAIN PARAMETERS. [witness_desired] and [witness_depth] alias phase
   by phase back to p13_witness.ml:42 and :48, the ordinals back to
   p22_witness.ml:127, and the prior phases hold them in exactly the [x = x]
   form deleted above - t_p20_regression.ml:144-145 and t_p21_regression.ml:
   177-178 for the depth, t_p22_regression.ml:175-178 for the depth and the
   desired, t_p23_regression.ml:192-197 for all three - so no test in this tree
   pinned any of them against a NUMBER. They are graph-DETERMINING: [desired]
   and the ordinals pick
   the seed ([Scenario.vsts_seed_with_pods]), [depth] bounds every leg's
   exploration, and a change to any of the three moves all four P24 legs while
   every alias row in every phase stays green. A red here is a phase-STOP, never
   a retune.

   ---- WHY THE OTHER REMEDY WAS REJECTED RATHER THAN TAKEN -----------------
   The obvious repair is to make each deleted row real by pinning its OTHER end
   - [check int committed_l0_states P23_witness.l0_states]. That was tried on
   paper and dropped, because [W.l0_states] IS [P23_witness.l0_states]: they are
   ONE binding under two names, so that row and
   [check int committed_l0_states W.l0_states] one case up are the SAME
   assertion, and adding it would restate an existing row instead of adding red
   capability - the very defect being removed. Same for P23's four graph counts:
   p23_witness.ml:139-142 aliases [bl0_states] to [sl0_states], so the SL rows
   one case up already pin them and a BL row would be a third name for the same
   assertion. Nothing is added here on that ground.

   ---- WHAT REMAINS UNASSERTABLE, AND THE ONE RESIDUAL GAP ------------------
   The DERIVATION itself is not assertable. "[W.x] is derived from
   [P23_witness.x] rather than re-typed" is a property of the SOURCE TEXT; an
   alias and a re-typed literal that AGREES are indistinguishable at run time,
   which is exactly why the deleted rows could not fail on the tree as written -
   both of their sides were one binding, so no input reddens them.
   THE RESIDUAL GAP, STATED RATHER THAN PAPERED OVER: the deleted rows would
   have fired in one hypothetical two-edit future - someone replaces a
   p24_witness alias with a literal that agrees TODAY, and a LATER phase then
   moves the P23 chain underneath it. Nothing in THIS file would red then, since
   the committed literal and the re-typed alias would both still say 76. Where
   the alarm actually lives, per number: for the counts P24's own legs
   RE-DERIVE - P23's four graphs, its four gates and its premise-side counters -
   [t_p24_state_predicates] MEASURES them on the live graph, so a real move reds
   there whatever the witness says. For L0..L0v and SL0..SLm, which no P24 leg
   re-derives, the alarm belongs to the phase that owns them:
   t_p21_regression.ml:149 and t_p22_regression.ml:148 hold those same literals
   against THEIR OWN witnesses, so a P21/P22 move reds there first. That is a
   different and later alarm than the deleted rows advertised, and saying so is
   the point - a row that cannot fail today is not insurance for tomorrow. The
   derivation itself is enforced by review of p24_witness.ml (its tier-1 header
   at :106-110 states the rule), not by this file. *)

let committed_witness_desired : int = 1
let committed_witness_depth : int = 40
let committed_ordinals : int list = [ 1 ]

let test_p24_chain_parameters_are_the_committed_literals () =
  Alcotest.(check int)
    "P24's witness_desired = the committed 1 (p13_witness.ml:42, aliased \
     unchanged through P14-P23) - it picks the seed, so a move here moves all \
     four legs"
    committed_witness_desired W.witness_desired;
  Alcotest.(check int)
    "P24's witness_depth = the committed 40 (p13_witness.ml:48) - it bounds \
     every leg's exploration, so a move here moves all four legs"
    committed_witness_depth W.witness_depth;
  Alcotest.(check (list int))
    "P24's shipped ordinals = the committed [1] (p22_witness.ml:127) - the pod \
     ordinals the seed plants"
    committed_ordinals W.p24_ordinals

(* ==== 1b. THE SHAPE CONSTANTS, NAMED SO A PIN CANNOT HIDE AMONG THEM =======
   {!P24_witness}'s integer constants come in exactly three kinds: the DERIVED
   chain re-exports (each pinned above against a committed literal), the family
   SHAPE constants (facts about what was WRITTEN), and the MEASURED literals -
   the THREE stage-B vacuity zeroes
   ([after_delete_outdated_occupancy_everywhere],
   [ok_resp_some_unowned_obj_everywhere] and
   [pending_src_not_controller_everywhere], the last of which CUT the M2
   candidate) plus the probe-B5 SCOPE-EXCLUSION pins the main loop's ruling
   added (the measured refutation of upstream :116-118 and :119-124). NONE of
   the measured kind is a graph literal, and each is asserted where it is
   measured, in t_p24_state_predicates; this file deliberately does not re-type
   them, because the firewall exists to catch a witness edited to match a MOVED
   GRAPH. What is named here is the SHAPE kind, so that a measured pin landing
   in the witness can never be mistaken for one of them. *)

let test_stage_a_pins_no_measurement () =
  Alcotest.(check int)
    "the only P24-OWNED cardinal in the witness is the family's, and it is a \
     shape fact - 2, M1 and M3, after the M2 candidate was CUT (RULING said 3; \
     the cut is a FINDING recorded in state_predicates.mli, not a retune) - \
     never a measurement"
    2 W.predicate_cardinal;
  Alcotest.(check int)
    "...and the four leg labels, likewise a shape fact" 4
    (List.length W.leg_labels);
  Alcotest.(check int)
    "the member-name list has one entry per member, so the per-member \
     projections cannot silently address fewer members than the family has"
    W.predicate_cardinal
    (List.length W.member_names);
  Alcotest.(check int)
    "the step enumeration probe B2 folds over is the reconciler's full \
     SEVENTEEN (a short list would make the histogram silently non-total)"
    17
    (List.length W.all_steps);
  Alcotest.(check (list string))
    "the seventeen step labels are DISTINCT - a duplicated label would merge \
     two columns of the histogram and hide one step's occupancy"
    (List.sort_uniq String.compare (List.map W.step_label W.all_steps))
    (List.sort String.compare (List.map W.step_label W.all_steps));
  Alcotest.(check int)
    "and the three steps EXCLUDED from M1's borrowed at_vsts_step premise are \
     named (Init, After_list_pod, Error), so the valid-step total is the \
     complement of a stated set rather than a second 17-arm match that could \
     drift"
    3
    (List.length W.non_valid_step_labels)

(* ==== 2. the COMMITTED member identities ================================== *)

let m1_name : string = "vsts_local_state_is_valid"
let m3_name : string = "vsts_pending_list_pod_resp_in_flight"

(* THE CUT MEMBER'S NAME, committed as a literal for ONE purpose: to assert its
   ABSENCE. The M2 candidate (upstream :45 closed by :59-66) was written,
   measured, mutation-tested and CUT on the finding recorded in
   state_predicates.mli. A committed name that is only ever asserted absent is
   what stops the cut from being undone by a copy-forward: without it, re-adding
   the member would simply extend [committed_predicate_pairs] and every row
   here would go green about three members again. *)
let cut_m2_name : string = "vsts_pending_list_pod_req_in_flight"

let cut_m2_source : string =
  "vstatefulset_controller/proof/liveness/state_predicates.rs:45"

(* BARE. No parenthetical qualifier, ever - see the header and MP8. The
   SOURCE-STRING RULE (state_predicates.mli): each source names the upstream
   [pub open spec fn] whose CONJUNCTS the member renders, not the wrapper that
   lifts them to a [StatePred]. *)
let m1_source : string =
  "vstatefulset_controller/proof/liveness/state_predicates.rs:192"

let m3_source : string =
  "vstatefulset_controller/proof/liveness/state_predicates.rs:107"

let committed_predicate_pairs : (string * string) list =
  [ (m1_name, m1_source); (m3_name, m3_source) ]

(* P23's two, re-typed here ONLY so the roster-coverage rows below can be keyed
   on COMMITTED literals rather than on a family filtered against itself (the
   P22-review F2 correction). *)
let committed_binding_pairs : (string * string) list =
  [
    ( "vsts_local_pods_and_pvcs_bound_in_local_state",
      "vstatefulset_controller/proof/internal_rely_guarantee.rs:613" );
    ( "vsts_local_pods_and_pvcs_bound_with_key",
      "vstatefulset_controller/proof/internal_rely_guarantee.rs:640" );
  ]

let test_family_names_and_pairs () =
  Alcotest.(check (list string))
    "predicate_family is M1/M3 in member order" [ m1_name; m3_name ]
    (names_of family);
  (* THE CUT, ASSERTED. Both halves, because a re-added member could come back
     under either its old name or its old citation and only one of these rows
     would see it. *)
  Alcotest.(check (list string))
    "the CUT M2 candidate's NAME is absent from the shipped family - a member \
     re-added here without its finding being answered reddens THIS row"
    []
    (List.filter (String.equal cut_m2_name) (names_of family));
  Alcotest.(check (list string))
    "...and its SOURCE :45 is absent from predicate_sources, so it cannot \
     re-enter the roster sweep through the source list either"
    []
    (List.filter (String.equal cut_m2_source) Sp.predicate_sources);
  Alcotest.(check (list (pair string string)))
    "family (name, source) pairs = the committed literals, in member order"
    committed_predicate_pairs
    (Pair_guard.pairs_of family);
  Alcotest.(check (list string))
    "family sources = predicate_sources, in order (the .mli's exposed literals)"
    Sp.predicate_sources (sources_of family);
  Alcotest.(check int) "predicate_family cardinal" W.predicate_cardinal
    (List.length family);
  (* the member NAMES the counting projections address the family by, pinned
     against the same literals - a rename would blind every per-member count in
     t_p24_state_predicates and t_p24_mutation at once. *)
  Alcotest.(check (list string))
    "the witness's member names = the committed two"
    [ m1_name; m3_name ] W.member_names

(* ==== 3. THE ROSTER - sixteen suites, and the self-exclusion MOVED ======== *)

let p19_label : string = "Msg_provenance.provenance_family (P19)"
let p20_label : string = "Rely_conditions.rely_family (P20)"
let p21_label : string = "Internal_guarantee.guarantee_family (P21)"

let p22_label : string =
  "Internal_guarantee.guarantee_family @ scale-down leg (P22)"

(* DEMOTED: the "THIS phase" marker moves off P23's label - in THIS file only;
   t_p23_regression keeps its own marker and its own self-exclusion. *)
let p23_label : string = "Local_binding.binding_family (P23)"
let p24_label : string = "State_predicates.predicate_family (P24, THIS phase)"

(* The P21 and P22 roster entries are the SAME expression (P22 shipped no new
   family), bound separately so the roster has two entries. *)
let p21_family : Invariants.invariant list =
  Ig.guarantee_family ~cr:(Scenario.vsts ~desired ()) ~controller_id

let p22_family : Invariants.invariant list =
  Ig.guarantee_family ~cr:(Scenario.vsts ~desired ()) ~controller_id

let p23_family : Invariants.invariant list =
  Lb.binding_family ~cr:(Scenario.vsts ~desired ()) ~controller_id

let shipped_suites : (string * Invariants.invariant list) list =
  let vrs = Scenario.vrs ~desired:1 in
  let vsts = Scenario.vsts ~desired:1 () in
  [
    ("Invariants.cluster_structural", Invariants.cluster_structural ~controller_id);
    ("Invariants.always", Invariants.always ~cr:vrs ~controller_id);
    ("Invariants.eventually_always", Invariants.eventually_always ~cr:vrs ~controller_id);
    ("Vsts_invariants.always", Vsts_invariants.always ~cr:vsts ~controller_id);
    ("Correspondence.family (P14)", Correspondence.family cluster ~controller_id);
    ( "Reconcile_correspondence.family (P15)",
      Rec_corr.family ~controller_id ~pending_states:Fc.vsts_pending_states
        ~none_states:Fc.vsts_none_states );
    ("Req_resp_correspondence.rv_family (P16)", Rr.rv_family inherited_bound);
    ("Req_resp_correspondence.matched_family (P16)", Rr.matched_family ~controller_id);
    ("Objects_in_store.store_family (P17)", Ois.store_family ~controller_id);
    ( "Helper_invariants.helper_family (P18)",
      Hi.helper_family ~cr:(Scenario.vsts ~desired ~vct:false ()) ~controller_id );
    (p19_label, Mp.provenance_family ~controller_id);
    (p20_label, Rely.rely_family);
    (p21_label, p21_family);
    (p22_label, p22_family);
    (p23_label, p23_family);
    (p24_label, family);
  ]

(* The roster's LABELS, committed as a literal list: a verbatim copy of the P23
   roster, a dropped entry, or an un-demoted P23 marker reddens here before the
   sweep can quietly not-look at the omission. *)
let committed_roster : string list =
  [
    "Invariants.cluster_structural";
    "Invariants.always";
    "Invariants.eventually_always";
    "Vsts_invariants.always";
    "Correspondence.family (P14)";
    "Reconcile_correspondence.family (P15)";
    "Req_resp_correspondence.rv_family (P16)";
    "Req_resp_correspondence.matched_family (P16)";
    "Objects_in_store.store_family (P17)";
    "Helper_invariants.helper_family (P18)";
    p19_label;
    p20_label;
    p21_label;
    p22_label;
    p23_label;
    p24_label;
  ]

let others : (string * Invariants.invariant list) list =
  List.filter
    (fun ((label, _) : string * Invariants.invariant list) ->
      not (String.equal label p24_label))
    shipped_suites

let roster_pairs : (string * string) list =
  List.concat_map
    (fun ((_, invs) : string * Invariants.invariant list) ->
      Pair_guard.pairs_of invs)
    shipped_suites

(* COVERAGE keyed on COMMITTED LITERALS (P22-review finding F2). Fed
   [Pair_guard.pairs_of <a roster family>] this function filters
   [roster_pairs] against a list it was itself built from and can never return
   anything but [[]]; fed the section-2 literals it has teeth. *)
let missing_from_roster (pairs : (string * string) list) :
    (string * string) list =
  List.filter (fun (p : string * string) -> not (List.mem p roster_pairs)) pairs

let test_roster_is_sixteen_and_covers_the_newest_phases () =
  Alcotest.(check (list string))
    "the roster is SIXTEEN suites - t_p23_regression's fifteen with the P23 \
     marker demoted, PLUS the P24 entry (a verbatim copy-forward REDS: that \
     file names FIFTEEN explicitly)"
    committed_roster
    (List.map
       (fun ((label, _) : string * Invariants.invariant list) -> label)
       shipped_suites);
  Alcotest.(check int)
    "fifteen suites are swept (the P24 self-entry is excluded; the P23 entry \
     is IN the swept set now)"
    (List.length committed_roster - 1)
    (List.length others);
  Alcotest.(check bool)
    "the P23 entry really is in the swept set (the demotion happened)" true
    (List.exists
       (fun ((label, _) : string * Invariants.invariant list) ->
         String.equal label p23_label)
       others);
  (* COVERAGE: the COMMITTED literals against the roster's LIVE inventory. *)
  Alcotest.(check (list (pair string string)))
    "every COMMITTED P23 binding pair is in the roster's live inventory" []
    (missing_from_roster committed_binding_pairs);
  Alcotest.(check (list (pair string string)))
    "every COMMITTED P24 predicate pair is in the roster's live inventory - \
     the row that would redden if the P24 entry were dropped from the roster"
    []
    (missing_from_roster committed_predicate_pairs)

(* ==== 4. the sweep: DISJOINT from all fifteen ==============================
   RULING section 5 makes this an explicit obligation and notes it is NOT
   automatic. P24 ships two genuinely new members, so every row expects [[]].
   {!Pair_guard.pair_leaks} detects a shared NAME or a shared SOURCE in either
   list, so ONE order already covers both leak directions; the second order
   makes that coverage explicit rather than inferred. *)

let leaks_against (suites : (string * Invariants.invariant list) list) :
    string list =
  List.concat_map
    (fun ((suite, invs) : string * Invariants.invariant list) ->
      Pair_guard.pair_leaks
        ("P24 -> " ^ suite)
        (Pair_guard.pairs_of family)
        (Pair_guard.pairs_of invs)
      @ Pair_guard.pair_leaks
          ("P24 <- " ^ suite)
          (Pair_guard.pairs_of invs)
          (Pair_guard.pairs_of family))
    suites

let test_family_is_disjoint_from_shipped_suites () =
  Alcotest.(check (list string))
    "no P24 predicate member shares a name or source with any of the FIFTEEN \
     other shipped suites (both argument orders, incl. P21's, P22's and \
     P23's) - RULING section 5's explicit obligation, which is not automatic"
    []
    (leaks_against others);
  (* The sweep is SEEN red-capable: the same detector, run against the roster's
     own P24 self-entry, reports every member in both orders - so the empty
     list above is a MEASURED absence, not a broken traversal (the D3 lesson:
     [pair_leaks] against a shorter roster still returns [[]]). *)
  Alcotest.(check int)
    "sweep control: the roster's own P24 entry reports every member, both \
     orders"
    (2 * List.length family)
    (List.length
       (leaks_against
          (List.filter
             (fun ((label, _) : string * Invariants.invariant list) ->
               String.equal label p24_label)
             shipped_suites)))

(* ==== 5. THE SOURCE-FILE PARTITION, i.e. the E-ledger untouched IN EFFECT ==
   NOT the E-ledger reversal SWEEP - that keeps its single assertion site in
   t_p21_regression (header), a file this phase EDITS to add the roster entry.
   What is measured HERE is the thing that makes editing that file safe: every
   P24 source names [liveness/state_predicates.rs] and NONE bears the
   [internal_rely_guarantee.rs:] prefix the clause filters on, so the SIXTEEN-
   suite roster's guarantee-line inventory is byte-identical to the FIFTEEN-
   suite one. A P24 member that acquired a guarantee citation would silently
   re-partition a ledger this phase does not own. *)

let guarantee_prefix : string =
  "vstatefulset_controller/proof/internal_rely_guarantee.rs:"

let predicate_prefix : string =
  "vstatefulset_controller/proof/liveness/state_predicates.rs:"

let sub_opt (s : string) (pos : int) (len : int) : string option =
  if pos >= 0 && len >= 0 && pos + len <= String.length s then
    Some (String.sub s pos len) (* @total-accessor *)
  else None

let line_of_source (s : string) : int option =
  Option.bind (String.rindex_opt s ':') (fun (i : int) ->
      Option.bind
        (sub_opt s (i + 1) (String.length s - i - 1))
        int_of_string_opt)

let predicate_lines : int list =
  List.filter_map line_of_source Sp.predicate_sources

let roster_guarantee_lines : int list =
  List.sort_uniq Int.compare
    (List.filter_map line_of_source
       (List.sort_uniq String.compare
          (List.filter_map
             (fun ((_, src) : string * string) ->
               if String.starts_with ~prefix:guarantee_prefix src then Some src
               else None)
             roster_pairs)))

let test_source_file_partition () =
  (* BARE-SOURCE first: if any source acquired a qualifier, [predicate_lines]
     is short and everything below it would be a claim about both members
     while reading fewer. *)
  Alcotest.(check int)
    "both P24 sources are BARE and parse to a line (a parenthetical qualifier \
     makes line_of_source return None - MP8's exhibit)"
    (List.length Sp.predicate_sources)
    (List.length predicate_lines);
  Alcotest.(check (list int))
    "the P24 lines are M1 :192, M3 :107, in member order - :45 is ABSENT \
     because the M2 candidate is CUT"
    [ 192; 107 ]
    predicate_lines;
  Alcotest.(check bool)
    "every P24 source names proof/liveness/state_predicates.rs" true
    (List.for_all
       (String.starts_with ~prefix:predicate_prefix)
       Sp.predicate_sources);
  Alcotest.(check (list string))
    "and NO P24 source bears the internal_rely_guarantee.rs prefix that \
     t_p21_regression's E-ledger clause filters on - this is what makes the \
     roster addition unable to reach that clause"
    []
    (List.filter
       (String.starts_with ~prefix:guarantee_prefix)
       Sp.predicate_sources);
  (* the inventory itself, measured over the SIXTEEN-suite roster *)
  Alcotest.(check (list int))
    "the SIXTEEN-suite roster's internal_rely_guarantee.rs inventory is still \
     exactly the ledger's shipped bucket (G4 :544, G1 :562, G2 :581, G3 :589, \
     L1 :613, L2 :640) - adding P24 moved nothing"
    P21_witness.ledger_shipped_lines roster_guarantee_lines;
  Alcotest.(check (list int))
    "and no P24 line collides with a ledgered guarantee line, in either \
     direction"
    []
    (List.filter
       (fun (n : int) -> List.mem n P21_witness.ledger_shipped_lines)
       predicate_lines)

let () =
  Alcotest.run "p24_regression"
    [
      ( "prior_phase_firewall",
        [
          Alcotest.test_case
            "P24's graph constants are the committed P13-P23 literals (incl. \
             P23's four gates and its premise-side counters)"
            `Quick test_p24_graph_constants_are_the_committed_literals;
          Alcotest.test_case
            "P24's three CHAIN PARAMETERS (desired, depth, ordinals) are the \
             committed 1 / 40 / [1] - the graph-determining inputs no phase \
             pinned against a number"
            `Quick test_p24_chain_parameters_are_the_committed_literals;
          Alcotest.test_case
            "the witness's SHAPE constants are shape facts, not measurements - \
             so no stage-B pin can hide among them"
            `Quick test_stage_a_pins_no_measurement;
        ] );
      ( "family_classification",
        [
          Alcotest.test_case
            "predicate_family = M1 :192 / M3 :107, committed (name, source) \
             pairs, BARE sources, and the CUT M2 candidate absent from both \
             the family and predicate_sources"
            `Quick test_family_names_and_pairs;
        ] );
      ( "roster",
        [
          Alcotest.test_case
            "the roster is SIXTEEN suites; P23 demoted into the swept set; \
             coverage of the COMMITTED literals"
            `Quick test_roster_is_sixteen_and_covers_the_newest_phases;
        ] );
      ( "disjointness",
        [
          Alcotest.test_case
            "family DISJOINT from every other shipped suite (Pair_guard, both \
             orders; sweep SEEN red-capable on the self-entry)"
            `Quick test_family_is_disjoint_from_shipped_suites;
        ] );
      ( "source_file_partition",
        [
          Alcotest.test_case
            "both P24 sources are BARE liveness/state_predicates.rs citations, \
             and the roster's internal_rely_guarantee.rs inventory is unmoved"
            `Quick test_source_file_partition;
        ] );
    ]

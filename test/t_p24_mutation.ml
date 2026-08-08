(* BUILD-SPEC-P24 section 5 and RULING.md section 7 (stage C) - confirm-by-
   mutation for the P24 state-predicate register: the matrix that makes
   t_p24_state_predicates' green MEAN something. A pin never SEEN to fail is
   not evidence.

   ==== STATUS: STAGE C HAS RUN, AND THE MAIN LOOP HAS SINCE RULED ==========

   This exe itself closes the rows that can be closed AUTOMATICALLY - at STATE
   level, on forged inputs. It pins no P24 measurement: every number it names
   is either 0, 1, a list length, or an INHERITED P13-P23 literal read through
   {!P24_witness}. What has ALSO happened, and is recorded per row below and in
   BUILD-SPEC-P24 section 5, is that stage C applied and reverted the SOURCE
   mutants with the Edit tool ([git checkout --] never invoked; [git diff
   --stat] empty after every row):

     M1a       (:212 [>=] -> [>])                      KILLED, both levels
     M1b       (:202's exact ordinal-indexed name
                WEAKENED into P23's L1)                KILLED at STATE level,
                                                       with L1 GREEN in the same
                                                       run - so "M1 is strictly
                                                       stronger than L1" is
                                                       EVIDENCED. Graph level
                                                       UNMOVED, as a WEAKENING
                                                       mutant must leave an
                                                       already-green leg
     M2a'      (:49 [.src] -> [.dst])                  KILLED, both levels,
                                                       with the P23 leg GREEN in
                                                       the same run - AND THE
                                                       KILL WAS TRIVIAL. See the
                                                       M2 block below: M2 is CUT
     M3a       (:128 [is_some] -> [is_none], after
                the row was RETARGETED off :126)       KILLED, both levels. The
                                                       earlier :126 kind swap
                                                       also killed, but :126 is
                                                       ENTAILED by :127 and its
                                                       DELETION mutant was seen
                                                       GREEN EVERYWHERE, so that
                                                       kill is not evidence about
                                                       :126. See the M3a block
     M3b       ([weakly_eq]'s METADATA arm made a
                tautology)                             KILLED at STATE level by
                                                       the (now removed) M3d row
     M3b-spec  ([weakly_eq]'s SPEC arm made a
                tautology)                             SURVIVED - a real test gap

   NOT RUN as a source mutant, and not claimed: M3c's GRAPH-level half.

   ==== THE RULING, AND WHY FOUR OF THE ROWS ABOVE ARE HISTORY ==============

   Upstream :116-118 (the owned-object-ref SET equality against
   [Cluster.resources]) and :119-124 (the coherence forall whose body :123 is
   [weakly_eq]) are now EXCLUDED-WITH-A-PIN on a SCOPE ground. Upstream's own
   comment at state_predicates.rs:116 scopes that coherence to "steps taken by
   other controllers satisfying rely conditions"; this port has no
   rely-condition machinery; and the BLc / BLm graphs inject by construction
   exactly the rely-violating writers the assumption excludes. So M3 ships its
   SEVEN pure-shape conjuncts (:115, :126, :127, :128, :129, :130, :132) and
   [weakly_eq], [owned_objs], [valid_owned_object], [etcd_valid_owned_refs] and
   [ref_set_equal] are GONE from {!Anvil_assurance.State_predicates}.

   CONSEQUENCES FOR THIS FILE, stated rather than quietly applied:
   - M3b and M3b-spec name a function that no longer exists. Their verdicts are
     kept above as HISTORY, because "the metadata arm was mutation-killed and
     the spec arm was a test gap" is exactly what a later phase needs in order
     to restore [weakly_eq] responsibly. Neither row is re-runnable.
   - M3c's and M3d's STATE-LEVEL rows are REMOVED from
     [test_m3_shape_conjuncts]. Both asserted M3 RED on a state that only the
     excluded conjuncts could see; with those conjuncts gone the member is
     green there and the rows would have had to be inverted, which would have
     turned two red-capability exhibits into two assertions about nothing. What
     they demonstrated is NOT lost - it was promoted to a MEASURED pin over the
     real graphs (probe B5, [t_p24_state_predicates]'s [scope_exclusion_pin]),
     which is strictly stronger than a forged state: 0 / 8 / 0 / 72 set-equality
     failures and 0 / 4 / 0 / 40 coherence failures, every one of the latter the
     :122 key-presence conjunct, with [weakly_eq]'s own arms disagreeing NOWHERE.

   ==== AND A SECOND RULING: THE M2 CANDIDATE IS CUT ========================

   Upstream [req_msg_is_list_pod_req] (:45-57) closed by
   [pending_list_pod_req_in_flight] (:59-66) is no longer a member of
   {!Anvil_assurance.State_predicates.predicate_family}; the cardinal is TWO.
   Rendered as an invariant over this port's four graphs it is entirely
   contained in P23's L2: five conjuncts literally, :65 by an entailment the
   equal populations MEASURE, and :49 - the one conjunct L2 lacks - unwitnessed
   at 0 over denominators 16 / 112 / 288 / 1560. The M2a' row below records why
   its own kill did not rescue the member. CONSEQUENCES FOR THIS FILE, stated
   rather than quietly applied:
   - [test_m2_novel_conjuncts] is REMOVED, with [foreign_src_req] and
     [parked_pending]. Every row in it read a verdict off a member that no
     longer exists; inverting them would have turned a red-capability exhibit
     into an assertion about nothing, which is the M3c/M3d mistake one phase
     earlier in this same file.
   - What those rows demonstrated is NOT lost. It was promoted to a MEASURED
     pin over the four real graphs - [t_p24_state_predicates]'s B4 case, which
     asserts [P24_witness.pending_src_not_controller_everywhere = 0] behind the
     src-histogram partition, plus the raw-in-flight / delivery-window equality
     in [inherited_population]. That is strictly stronger than a forged state.

   THE BASELINE IS NOW ALL-GREEN, AND THAT CHANGES HOW THE VERDICTS ABOVE READ.
   Before the SCOPE ruling, [p24_state_predicates] reported 2 failures of 11
   cases at BASELINE ([legs 1 SPc] and [legs 3 SPm]), so only SP0 and SPd carried
   graph-level discrimination signal and every "KILLED, both levels" meant those
   two went [OK] -> [FAIL] (4 failures where the baseline had 2). The baseline is
   now 0 failures, so a re-run of M1a / M3a would show all four graphs available
   to redden. Those verdicts were recorded against the OLD baseline and are NOT
   silently re-read against the new one: what they established (each mutant seen
   red on SP0 and SPd, with the P23 leg green in the same run) stands unchanged,
   and the extra graphs are upside nobody has measured.

   ==== the matrix (BUILD-SPEC-P24 section 5, as re-scoped by RULING) ========

   M1a  THE CONDEMNED ORDINAL BOUND, upstream :212
        ([get_ordinal(pod.name) >= replicas]). This conjunct has NO P23
        counterpart at all - P23's L1 renders only [pod_name_match], i.e.
        "SOME ordinal parses" (local_binding.ml:86-87), and never compares the
        ordinal to [replicas]. SOURCE MUTANT (stage C): flip [>=] to [>].
        PREDICTED: RED on all four graphs. OBSERVED: RED on the two graphs that
        carry signal - SP0 and SPd went [OK] -> [FAIL] at
        t_p24_state_predicates.ml's [outcome CLEAN] assertion, and the
        [m1_novel_conjuncts] control below went red in the same run; SPc and
        SPm were already red at THE BASELINE THAT ROW RAN AGAINST (M3's
        then-shipped etcd conjuncts). The "all four" half of the prediction was
        therefore UNTESTABLE when it ran, not confirmed - and it has NOT been
        re-read against the all-green baseline the SCOPE exclusion and the M2
        cut produced, because the row was never re-run.
        STATE-LEVEL ANALOGUE: CLOSED BELOW in
        [m1_novel_conjuncts] - a condemned entry at ordinal 0 with
        [replicas = 1] reds M1 while P23's L1 stays GREEN on the same state,
        which is the discrimination claim itself rather than an argument for
        it.

   M1b  THE EXACT ORDINAL-INDEXED NAME, upstream :202
        ([name == Some(pod_name(parent, ord))]). STRICTLY STRONGER than L1's
        existential. SOURCE MUTANT: weaken it to "some ordinal parses", i.e.
        degrade M1 into L1. PREDICTED: RED - this is the conjunct that proves
        M1 is stronger than L1.

        {b THE SOURCE MUTANT HAS BEEN RUN, AND IT KILLED, SO THE PREDICTION IS
        DISCHARGED.} It was not one of RULING section 7's required rows; the
        seal wave ran it anyway, because the phase's headline discrimination
        claim rested on it. The conjunct
        [Option.equal String.equal pm.name
           (Some (V_stateful_set_reconciler.pod_name parent ord))] was replaced
        by L1's existential
        [Option.fold pm.name ~none:false ~some:(fun n ->
           Option.is_some (V_stateful_set_reconciler.get_ordinal parent n))].
        RESHAPE DISCLOSED (house rule: a mutant killed by a BUILD ERROR is not
        caught): the tuple binder [ord] was renamed [_ord] in the mutant, since
        the weakened body no longer reads the slot ordinal and the
        unused-variable warning would have made this a build-error kill. It then
        compiled clean and died as an ASSERTION, in the [m1_novel_conjuncts]
        row below - "M1b: M1 is RED when the pod named for ordinal 1 sits in
        needed slot ORDINAL 0", [Expected: false / Received: true] - with the
        three ASSERTs preceding it in the same block passing UNDER the mutant,
        so the red is attributable to the conjunct and not to a broken
        injection. DISCRIMINATION in the SAME run: [p23_local_binding] green
        ("11 tests run"), [p23_mutation], [p23_regression] and
        [p24_regression] green. Reverted with the Edit tool.

        {b WHAT IT EARNS, AND WHERE IT STOPS.} "M1 is strictly stronger than
        P23's L1" is now EVIDENCED rather than predicted: the mutant collapsed
        M1 into L1 and an assertion caught it while L1 stayed green on the same
        state. It is earned at STATE level. [p24_state_predicates] stayed green
        under the mutant, its log byte-identical to baseline modulo run-id and
        timing, which is what a WEAKENING mutant must do to an already-green
        leg - so this row carries NO graph-level signal and must never be quoted
        for one. STATE-LEVEL ANALOGUE: CLOSED BELOW - the pod named
        [pod_name parent 1] sitting in needed slot ORDINAL 0 reds M1 and leaves
        L1 GREEN.

   M2a' THE [.src] CONJUNCT, upstream :49
        ([req_msg.src == Controller(controller_id, vsts_key)]). ==== ITS
        SUBJECT IS CUT. THIS ROW IS THE REASON, AND IT IS THE MOST IMPORTANT
        ENTRY IN THIS MATRIX. ==== :49 is GENUINELY absent from L2 (refute
        verdict C5, confirmed: exactly one [.src] occurrence exists across
        local_binding.ml/.mli and it is on the RESPONSE variable inside
        [ok_list_resps_for] :193-200, while [after_list_pod_ok] :217-225 checks
        [rm.dst] and never [rm.src]; upstream internal_rely_guarantee.rs:640-664
        likewise has no [req_msg.src] conjunct). The SOURCE MUTANT (swap [.src]
        for [.dst]) WAS RUN and DID redden the P24 leg (SP0 and SPd newly
        [FAIL]) with [p23_local_binding] reporting "Test Successful ... 11 tests
        run" and [p23_mutation] / [p23_regression] green in the SAME run, which
        is the letter of the ship gate.

        {b THE KILL IS TRIVIAL AND DOES NOT DISCRIMINATE.} Probe B4 measures
        the pending request's [src] as [Controller (controller_id, cr_key)] at
        EVERY state of the parked-with-pending population (16 / 112 / 288 /
        1560, complement 0 on all four, pinned as
        [P24_witness.pending_src_not_controller_everywhere]) and its [dst] as
        [Api_server] there likewise. Swapping [.src] for [.dst] therefore makes
        the conjunct FALSE on the ENTIRE premise population, so the leg reds by
        FALSIFICATION rather than by finding a state the original conjunct
        separates. It shows the conjunct is load-bearing FOR THE MUTANT; it does
        NOT show :49 has exercisable content. Upstream :49 is a GREEN THAT COULD
        NOT HAVE BEEN RED - this phase's own defect condition, the one that
        excluded :241, :246 and the eight PVC conjuncts.

        {b THE GATE WAS UNDERSPECIFIED AND THE MAIN LOOP HAS SAID SO.} RULING
        section 2's gate asked only that a mutant be SEEN RED with P23 green; it
        did not require the mutant to be NON-TRIVIALLY falsifying. That is the
        same class of error as RULING 3.3's vacuity-only gate. With :49
        unwitnessed and :65 entailed, the M2 candidate's remaining five
        conjuncts are P23's L2 (local_binding.ml:151-166, :217-225, :221), so
        the member bought NOTHING and it is CUT. The negative result lives in
        state_predicates.ml{,i}; the evidence stays live in {!P24_witness}'s B4
        probes and is ASSERTED by [t_p24_state_predicates]. THE STATE-LEVEL ROW
        IS REMOVED, not inverted: with no member to read, "M2 is RED here" has
        no subject.

   M2b' THE RAW-REQUEST IN-FLIGHT MEMBERSHIP, upstream :65
        ([s.in_flight().contains(req_msg)]). ==== STRUCK BEFORE THE CUT, AND
        THE STRIKE IS THE CUT'S OTHER HALF. ==== It can never fire. Stage B
        measured the raw-in-flight population at 8 / 52 / 48 / 744 and the
        delivery window at 8 / 52 / 48 / 744 - EQUAL on all four graphs -
        because the rendering premise ("parked, pending Some, no matching
        response yet") ENTAILS :65 through the shipped invariant
        [pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg]
        (reconcile_correspondence.ml:213). Identical populations mean there was
        no reachable state in that premise at which :65 is false, so a source
        mutant of it had nothing to redden. That equality is now ASSERTED, not
        recorded: [t_p24_state_predicates]'s [inherited_population] case compares
        [P24_witness.pending_still_in_flight] against
        [P24_witness.delivery_window] on every graph, by two independent routes
        and without naming a literal. The STATE-LEVEL row is removed with M2a''s,
        for the same reason.

   M3a  AN M3 SHAPE CONJUNCT (:115 no-duplicate object refs, :126 the kind is
        PodKind, :127 it unmarshals as a Pod, :128-130 name/namespace, :132
        [objects_to_pods] is Some). RULING section 3.1: killable at GRAPH
        level, no forged response needed. SOURCE MUTANT (stage C): flip a
        token.

        THE ROW'S TARGET MOVED, AND THE REASON IS A CORRECTION, NOT A RETUNE.
        The originally recorded mutant swapped :126's [Pod.kind] constant for
        [V_stateful_set.kind] inside this family's own [ok_list_resp_shape]
        (never inside the reconciler's [objects_to_pods] / [pod_filter], which
        hazard 2 below forbids) and was {b OBSERVED} to kill at GRAPH level (SP0
        and SPd newly [FAIL]) and at STATE level in [m3_shape_conjuncts], with
        [p23_local_binding] green in the same run. That observation stands, but
        it is not evidence ABOUT :126: :126 is ENTAILED by :127 on the very next
        line - [Pod] is [Resource_view.Make (R)] (views/pod.ml:64) and that
        functor's [unmarshal] (resource_view.ml:58-68) returns
        [Err.Kind_mismatch] unless the kinds match - so DELETING :126 changes
        nothing anywhere, and a red from a STRENGTHENED conjunct is a red about
        reachability, not about load-bearing. {b THE DELETION MUTANT WAS RUN AND
        IS THE EVIDENCE FOR THAT}: with the :126 conjunct removed outright,
        [p24_state_predicates], [p24_mutation], [p24_regression] and
        [p23_local_binding] were ALL GREEN - nothing anywhere observed its
        absence. The entailment is now disclosed in [state_predicates.ml] and
        the .mli exactly as :65 and :113/:114 are, and the conjunct STAYS
        (fidelity is why it is there).

        THE ROW NOW TARGETS :128, [Option.is_some om.name], which no neighbour
        entails: [unmarshal] passes [Dynamic_object.metadata] through without
        reading [name] (resource_view.ml:58-64), :126 reads only the kind,
        :129-130 read only the namespace, and :132 is :127 quantified over the
        same [objs]. SOURCE MUTANT: [Option.is_some om.name] ->
        [Option.is_none om.name]. {b OBSERVED}: it KILLED M3 at GRAPH level on
        ALL FOUR legs of [p24_state_predicates] (5 failures - the four [legs]
        cases plus the [scope_exclusion_pin] coupling row that asserts the
        shipped M3 is red at zero states), with [violated] naming
        [vsts_pending_list_pod_resp_in_flight] and the replica attributing 8 red
        states on SP0, while [p23_local_binding], [p23_mutation] and
        [p23_regression] stayed GREEN in the SAME run. The attribution is
        readable only because [check_leg] now ACCUMULATES its rows: under the
        old sequencing the case aborted at [is_clean] and the per-member red
        count was never reached.

        STATE-LEVEL ANALOGUES: CLOSED BELOW in [m3_shape_conjuncts], including
        the two that L2 does NOT carry (:115 and :126-127), each with P23's L2
        shown GREEN on the same state. Note the same caveat there: the :126
        state-level row exhibits the conjunct RENDERED and READABLE on a forged
        object, and does not claim it is separately killable.

   M3b  A TOKEN INSIDE THE PORTED [weakly_eq]. ==== RETIRED WITH THE
        CONJUNCT. ==== The function is gone from
        {!Anvil_assurance.State_predicates}, so the row is not re-runnable and
        no future stage may claim it. Its VERDICT is kept because it is the
        record a restorer needs: making [weakly_eq]'s METADATA arm a tautology
        (compare [a]'s metadata with [a]'s) was KILLED at state level by the
        M3d row, and unmoved at graph level, which is what a WEAKENING mutant
        must do. Making its SPEC arm a tautology the same way SURVIVED EVERY
        SUITE - nothing reddened anywhere and [p24_state_predicates]' failure
        set was byte-identical to the baseline - because the phase's only drift
        fixture rebuilt the object with [~spec] UNCHANGED and no shipped graph
        reaches a state where a listed object's spec disagrees with etcd's copy.
        That SPEC gap is now MEASURED rather than merely suspected:
        [P24_witness.weakly_eq_spec_disagreements_everywhere = 0] on all four
        graphs, over a comparison population asserted non-zero first. So
        [weakly_eq] left this tree mutation-confirmed on its metadata arm,
        incidentally covered on its kind arm, and with a measured hole on its
        spec arm - and it left as a CONSEQUENCE OF THE SCOPE EXCLUSION, not of
        any defect in it.

   M3c  THE OWNED-REF SET EQUALITY, upstream :116-118. ==== RETIRED WITH THE
        CONJUNCT. ==== Its source mutant was never run, and its state-level
        analogue (a response claiming an OWNED object etcd does not hold, with
        P23's L2 GREEN) is REMOVED from [test_m3_shape_conjuncts] below. The
        conjunct is EXCLUDED-WITH-A-PIN on the SCOPE ground, and its evidence
        is now a MEASURED refutation over the real graphs rather than a forged
        state - which is the stronger artefact, not the weaker one.

   ==== AND THE FACT THAT OUTRANKS EVERY ROW ABOVE FOR M3 ====================
        The refutation those two conjuncts produced is REAL and is PINNED, in
        [P24_witness]'s MEASURED block and asserted by
        [t_p24_state_predicates]'s [scope_exclusion_pin] case: :116-118 fails at
        0 / 8 / 0 / 72 states on SP0 / SPc / SPd / SPm (SPc splitting 4 + 4 and
        SPm 32 + 40 across the two containment directions) and :119-124 at
        0 / 4 / 0 / 40, EVERY one of the latter the :122 key-presence conjunct.
        [weakly_eq]'s own comparison disagrees at ZERO states on every graph and
        every arm, so the cause is STALENESS of an in-flight response relative
        to etcd (a crash-orphaned request applied late on BLc, the pod monkey on
        BLm) and never the comparison. Upstream scopes that coherence to steps
        taken by other controllers satisfying RELY CONDITIONS, which this port
        does not model, so the conjuncts are EXCLUDED rather than the leg
        relaxed - relaxing the assertion, or narrowing M3's premise until the
        failures fell outside it, would each have been the retune this project
        forbids. The rows in this file are STATE-level and are not the evidence
        for any of that; the pin is.

   ~~M2a (the selection sketch's row)~~ REJECTED. "Swap the Pod kind
        constructor in the ported ListRequest shape" targets upstream :53-56,
        which L2 ALREADY carries (local_binding.ml:151-166), so it would redden
        P23's leg too and fails this phase's own discrimination bar (refute
        verdicts C15 and C22, both confirmed; adopted). It is recorded here as
        rejected so it cannot be re-proposed as an oversight.

   MP5  PREMISE WIRING (in-test, RUNS BELOW on every battery pass): the family
        instantiated at [controller_id + 1], evaluated over the REAL SP0
        replica. PREDICT: both members' [interesting] = 0 AND red = 0 - vacuous
        TRUTH, not vacuous falsity. Mechanism: [Cluster.ongoing_reconciles] is
        TOTAL and yields the empty map for a missing id (cluster.mli:78-82), so
        [find_opt] is [None] at every state and the [~absent] fold takes over.
        MEASURED BELOW. The red column is asserted SEPARATELY from the
        interesting column rather than inferred from it: with the CUT M2 in the
        family there was a member whose [holds] read [~controller_id] a SECOND
        time (through :49), so the two columns were genuinely independent
        claims. Neither shipped member does that today, but the row keeps both
        columns - an out-of-premise member must be vacuously TRUE, and a family
        that went vacuously FALSE at the wrong id would still be a defect.

   MP6  THE DECODE-FAILURE FOLD (in-test, RUNS BELOW): the [~undecodable:true]
        argument of [State_predicates.at_reconcile]. Decode failures are 0 on
        every shipped graph (P23's prediction 4, re-derived on the P24 legs by
        t_p24_state_predicates), so on those graphs that fold is DEAD CODE and
        no graph-level assertion however exact could kill a mutation of it.
        This row supplies the input at UNIT level instead of disclosing the
        gap.

   MP7  THE PVC-EXCLUSION PIN's RED CAPABILITY (in-test, RUNS BELOW): a
        THROWAWAY [vct:true] seed. M1 excludes SEVEN conjuncts on this one pin
        (:197 :198 :199 :215-221 :223-228 :233 :244, together with the :193
        [pvc_cnt] binding every one of them reads), which is the phase's
        largest single-pin exclusion, so "excluded with a pin" has to mean
        excluded-and-watched rather than omitted. (:246 is PVC-FAMILY but does
        NOT die on this pin - it shares :241's REACHABILITY ground; retiring the
        PVC pin brings SEVEN conjuncts back into scope, not eight.)
        Deliberately a FLOOR, not a pin: no shipped leg explores this graph and
        committing its size would be a number nothing can move.

   MP8  THE BARE-SOURCE TRAP (in-test, RUNS BELOW): append a parenthetical
        qualifier to a source string. [t_p21_regression]'s [line_of_source]
        (:443-447) is [String.rindex_opt ':'] fed to [int_of_string_opt], so a
        qualifier returns [None], the member silently DROPS OUT of the roster,
        AND THE FIREWALL PIN STILL PASSES while the member is invisible. That
        vacuous green is the failure this row exhibits, and it is why BOTH shipped
        P24 sources are BARE.

   A mutant killed by a BUILD ERROR or by a TIMEOUT is NOT caught - reshape it
   (house rule). Every row below that claims a red is SEEN red in the same
   assertion block as its accepted control, so no red is attributable to a
   broken injection.

   ==== what the STATE-LEVEL rows are, and what they are NOT ================

   They are red capability for NAMED conjuncts, on states built from THIS
   phase's own seed with the reconciler's OWN [make_pod] / [Pod.marshal]
   payloads. THEY DO NOT PROVE THE PORT CAN REACH SUCH A STATE - only a source
   mutant re-explored over the graph does that. Source mutants HAVE been run
   (the status block above), so M1a and M3a carry graph-level evidence for the
   conjuncts that SHIP. M1b's source row does NOT, even though it has now been
   run and killed: it is a WEAKENING mutant, so it left the already-green leg
   green and the kill is state-level only - what it earns is the discrimination
   claim (M1 collapsed into L1 was caught, with L1 green on the same state), not
   reachability. This file's own rows must not be quoted for reachability
   either. AND M2a' IS THE STANDING WARNING ABOUT EXACTLY THIS
   FILE'S GENRE: it was run at graph level, it killed, and it still was not
   evidence, because its target is true on the whole premise population and the
   mutant merely falsified it everywhere. A state-level row forging a violating
   state proves even less. M3b's, M3c's and M2's subjects are all gone from the
   tree, and their evidence now lives in [t_p24_state_predicates] - the
   [scope_exclusion_pin] and B4 cases, MEASURED over the four real graphs, which
   is graph-level evidence of a stronger kind than any forged state here. Saying
   so is the point; the repo's recurring overclaim class is recorded at
   BUILD-SPEC-P22.md:113-119.

   Two hazards this file must never create (RULING section 5):
   1. it must never edit the shared [faulted] block (fault_check.ml:37-145) -
      every leg reaches it through [run_leg], so a widening would retroactively
      perturb all FOURTEEN legs' graphs at once;
   2. it must NEVER mutate [objects_to_pods] or [pod_filter] in place. They are
      live production logic called from the reconcile path
      (v_stateful_set_reconciler.ml:537 and :544), so mutating the shared
      implementation would alter reconcile behaviour, hence reachability, hence
      the pins. EXPORTING is safe; MUTATING is not. Mutants go in the NEW
      family only.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum, no two-arm match on
   [option]/[result], total accessors only, no indexing, no exceptions,
   Alcotest as the sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Sp = Anvil_assurance.State_predicates
module Lb = Anvil_assurance.Local_binding
module Vsr = V_stateful_set_reconciler
module Pack = V_stateful_set_pack
module W = P24_witness

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = W.witness_desired
let ordinals : int list = W.p24_ordinals
let depth : int = W.witness_depth
let bound : Bound.t = W.p24_bound ~desireds:[ desired ]
let cr : V_stateful_set.t = Scenario.vsts ~desired ()
let family : Invariants.invariant list = Sp.predicate_family ~cr ~controller_id

(* P23's register, instantiated at the SAME arguments. Every discrimination row
   below reads it: a P24 member earns its place by reddening on a state that
   leaves P23's corresponding member GREEN, and at state level that pairing IS
   the claim rather than an argument for it. (The gate's other half - that the
   mutant must not simply falsify its target on the whole premise population -
   is what the CUT M2 candidate failed; see the M2a' matrix row.) *)
let p23_family : Invariants.invariant list =
  Lb.binding_family ~cr ~controller_id

let m1_name : string = W.m1_name
let m3_name : string = W.m3_name
let l1_name : string = W.l1_name
let l2_name : string = W.l2_name

(* ==== the CR's own coordinates, READ off the CR, never typed =============== *)

let ns : string = W.namespace_of cr
let cr_key : Common.object_ref = W.cr_key_of cr
let elsewhere_ns : string = ns ^ "-p24-elsewhere"

(* [replicas] as {!Sp} reads it (state_predicates.ml:176-177): [spec.replicas]
   with [None] folded to 1. The M1a row's whole point is the comparison
   [ordinal >= replicas], so the row asserts this value rather than assuming
   the scenario's shape. *)
let replicas : int =
  Option.value ~default:1 (V_stateful_set.spec cr).Stateful_set.replicas

(* ==== the forged-state base: THIS phase's seed, reconcile INSTALLED ========
   [Cluster.cluster_state] and [Controller.state] are plain public records
   (cluster.mli:19-36, controller.mli:66-73), so the injection is a record
   update, not a state-machine step. The [Imap] entry could be absent, in which
   case [install] returns the seed UNCHANGED and every red row would silently
   become a green about nothing - so each row asserts the injection LANDED
   before it reads a verdict. The whole block is the one at
   t_p23_mutation.ml:241-308, re-used unchanged. *)

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true ~req_drop:false
    ~pod_monkey:false ()

let install (orc : Controller.ongoing_reconcile) : Cluster.cluster_state =
  Option.fold
    (Imap.find_opt controller_id seed.Cluster.controller_and_externals)
    ~none:seed
    ~some:(fun (ce : Cluster.controller_and_external) ->
      let cs : Controller.state = ce.Cluster.controller in
      {
        seed with
        Cluster.controller_and_externals =
          Imap.add controller_id
            {
              ce with
              Cluster.controller =
                {
                  cs with
                  Controller.ongoing_reconciles =
                    Object_ref_map.add cr_key orc
                      cs.Controller.ongoing_reconciles;
                };
            }
            seed.Cluster.controller_and_externals;
      })

let reconcile_state ~(step : Vsr.step) ~(needed : Pod.t option list)
    ~(condemned : Pod.t list) : Vsr.s =
  {
    Vsr.reconcile_step = step;
    needed;
    needed_index = 0;
    condemned;
    condemned_index = 0;
    pvcs = [];
    pvc_index = 0;
  }

let forge ~(step : Vsr.step) ~(needed : Pod.t option list)
    ~(condemned : Pod.t list) ~(pending : Message.t option) :
    Cluster.cluster_state =
  install
    {
      Controller.triggering_cr = V_stateful_set.marshal cr;
      pending_req_msg = pending;
      local_state = Pack.marshal_state (reconcile_state ~step ~needed ~condemned);
      reconcile_id = 0;
    }

(* ---- P26 FORGED-STATE builders (BUILD-SPEC-P26 section 2) -----------------
   [reconcile_state] above hard-codes both cursors to 0; the FS rows violate
   exactly one cursor implication each, so the two index cursors are
   parameterized here. [pvcs] stays [[]] and [pvc_index] stays 0 - the rows
   are seed-free and touch nothing PVC-shaped. Fresh names throughout: a
   reused binding name would shadow silently (section 1.6). *)

let reconcile_state_at ~(step : Vsr.step) ~(needed : Pod.t option list)
    ~(needed_index : int) ~(condemned : Pod.t list) ~(condemned_index : int) :
    Vsr.s =
  {
    Vsr.reconcile_step = step;
    needed;
    needed_index;
    condemned;
    condemned_index;
    pvcs = [];
    pvc_index = 0;
  }

let forge_at ~(step : Vsr.step) ~(needed : Pod.t option list)
    ~(needed_index : int) ~(condemned : Pod.t list) ~(condemned_index : int)
    ~(pending : Message.t option) : Cluster.cluster_state =
  install
    {
      Controller.triggering_cr = V_stateful_set.marshal cr;
      pending_req_msg = pending;
      local_state =
        Pack.marshal_state
          (reconcile_state_at ~step ~needed ~needed_index ~condemned
             ~condemned_index);
      reconcile_id = 0;
    }

let injection_landed (s : Cluster.cluster_state) : bool =
  Option.fold
    (Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id))
    ~none:false
    ~some:(fun (o : Controller.ongoing_reconcile) ->
      Result.is_ok (Pack.unmarshal_state o.Controller.local_state))

(* The injection: a record update on [Network.state] (network.mli:9), the same
   plain-record discipline [install] uses on [Controller.state]
   (t_p23_mutation.ml:896-904). *)
let with_in_flight (m : Message.t) (s : Cluster.cluster_state) :
    Cluster.cluster_state =
  {
    s with
    Cluster.network =
      { Network.in_flight = Message.Pool.add m (Cluster.in_flight s) };
  }

(* ---- payloads: the reconciler's OWN [make_pod] objects, metadata replaced --
   the t_p20/p21/p22/p23_mutation discipline (spec and status are never
   test-local fictions). [Vsr.make_pod] builds its metadata from
   [Object_meta.default ()] and sets [name], [labels], [annotations] and
   [owner_references] but NOT [namespace] - the api server stamps that on
   create - so the faithful shape of a listed pod is the STAMPED one. *)

let repod (md : Object_meta.t) (p : Pod.t) : Pod.t = Pod.with_metadata md p

let listed_pod (ord : int) : Pod.t =
  let p : Pod.t = Vsr.make_pod cr ord in
  repod { (Pod.metadata p) with Object_meta.namespace = Some ns } p

let good_pod0 : Pod.t = listed_pod 0
let good_pod1 : Pod.t = listed_pod 1

(* Upstream :204 / :214: [pod.metadata.namespace == Some(cr_key.namespace)] -
   the sub-conjunct M1 SHARES with P23's L1, kept as the CONTAINMENT datum so
   the discrimination rows above it cannot be read as "M1 reds on everything". *)
let foreign_ns_pod : Pod.t =
  repod
    { (Pod.metadata good_pod1) with Object_meta.namespace = Some elsewhere_ns }
    good_pod1

(* ---- pending requests: upstream :49-:56 ---------------------------------- *)

let list_req (namespace : string) : Api_method.api_request =
  Api_method.List_request { Api_method.kind = Pod.kind; namespace }

(* [Message.controller_req_msg] (message.rs:82) builds
   [src = Controller (controller_id, cr_key)], [dst = Api_server] - upstream :49
   and :50 satisfied BY CONSTRUCTION. That construction is also, measured over
   the graphs rather than read off the constructor, why upstream :49 has no
   witness anywhere (probe B4) and why the M2 candidate is CUT. Here the request
   is only the thing M3's forged responses are formed FROM, so that upstream's
   :655 api-server source and :656 [resp_msg_matches_req_msg] hold by
   construction too. *)
let pod_list_req : Message.t =
  Message.controller_req_msg controller_id cr_key (Message.Rpc_id.of_int 24)
    (list_req ns)

(* ---- the SEED-READ baseline for every M3 row -------------------------------
   The baseline payload is READ OFF THE SEED's etcd rather than typed: the
   objects upstream's [valid_owned_object_filter] (predicate.rs:44-52) admits
   for this CR. Each row below then perturbs exactly ONE shape conjunct on top
   of it, so the verdict is attributable to that conjunct.

   ITS ORIGINAL REASON IS GONE AND IT IS KEPT ANYWAY, DELIBERATELY. It was
   introduced because M3 then carried upstream's two ETCD-CONSUMING conjuncts,
   so a forged response whose objects were not the ones etcd holds would have
   reddened M3 on those conjuncts whatever its SHAPE was, making every shape row
   unattributable. Those two conjuncts are now EXCLUDED-WITH-A-PIN on the SCOPE
   ground, so nothing here reads [Cluster.resources] any more - but a payload
   built from the seed's own etcd is still strictly better than a hand-typed
   object, and swapping it out would perturb four green rows for no gain. The
   rows still assert it is NON-EMPTY before reading any verdict: an empty
   baseline would make every "M3 is RED" row a green about nothing. *)

let seed_owner_ref : Owner_reference.t option =
  V_stateful_set.controller_owner_ref cr

let etcd_owned_objs : Dynamic_object.t list =
  Option.fold seed_owner_ref ~none:[] ~some:(fun (r : Owner_reference.t) ->
      List.filter
        (fun (o : Dynamic_object.t) ->
          let om : Object_meta.t = Dynamic_object.metadata o in
          Common.equal_kind (Dynamic_object.kind o) Pod.kind
          && Option.is_some om.Object_meta.name
          && Option.equal String.equal om.Object_meta.namespace (Some ns)
          && Object_meta.owner_references_contains om r)
        (List.map snd (Object_ref_map.bindings (Cluster.resources seed))))

(* The CONTAINMENT datum's payload: a pod OUTSIDE the CR's namespace whose
   owner references are STRIPPED, so upstream :129-130 - the conjunct P23's L2
   shares - fires on both registers and nothing else does. *)
let foreign_ns_obj : Dynamic_object.t =
  Dynamic_object.with_namespace elsewhere_ns
    (Pod.marshal
       (repod
          { (Pod.metadata good_pod0) with Object_meta.owner_references = None }
          good_pod0))

(* A NON-pod object in the CR's own namespace: the CR itself, marshalled. Its
   [kind] is VStatefulSet, so upstream :126 and :127 both fire, while P23's L2
   (which reads only the namespace, local_binding.ml:206-212) stays GREEN. *)
let non_pod_obj : Dynamic_object.t =
  Dynamic_object.with_namespace ns (V_stateful_set.marshal cr)

(* The FS15 payload (BUILD-SPEC-P26 section 2): a marshalled [listed_pod]
   whose [metadata.name] is [None] - the repod discipline above, with the
   namespace kept as the CR's own so upstream :129-130 (and P23's L2) stay
   GREEN and only :128 can fire. A nameless ref renders name "" in
   [dyn_object_ref] (state_predicates.ml:445-452) while every seed-read
   object is named, so :115 sees no duplicate. *)
let nameless_pod_obj : Dynamic_object.t =
  Pod.marshal
    (repod { (Pod.metadata good_pod0) with Object_meta.name = None } good_pod0)

let parked_with (objs : Dynamic_object.t list) : Cluster.cluster_state =
  with_in_flight
    (Message.form_list_resp_msg pod_list_req { Api_method.res = Ok objs })
    (forge ~step:Vsr.After_list_pod ~needed:[] ~condemned:[]
       ~pending:(Some pod_list_req))

(* ---- per-state family projections ---------------------------------------- *)

let holds (fam : Invariants.invariant list) (name : string)
    (s : Cluster.cluster_state) : bool =
  W.member_holds fam name s

let fires (fam : Invariants.invariant list) (name : string)
    (s : Cluster.cluster_state) : bool =
  W.member_interesting fam name s

(* ==== family shape ========================================================= *)

let test_family_shape () =
  Alcotest.(check (list string))
    "predicate_family = M1, M3 in member order (the M2 candidate is CUT - \
     state_predicates.mli's NEGATIVE RESULT block)"
    W.member_names
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family);
  Alcotest.(check int) "predicate_family cardinal" W.predicate_cardinal
    (List.length family);
  (* by-name addressing is what every row below rides; a rename would make
     every projection constantly [false] and every red row silently green. *)
  List.iter
    (fun (name : string) ->
      Alcotest.(check bool) (name ^ " is addressable by name") true
        (List.exists
           (fun (i : Invariants.invariant) ->
             String.equal i.Invariants.name name)
           family))
    W.member_names;
  Alcotest.(check int)
    "P23's binding_family is instantiated alongside it at the SAME arguments \
     (every discrimination row below reads both)"
    W.binding_cardinal
    (List.length p23_family);
  (* the M1a row compares an ordinal to [replicas]; assert the value rather
     than assume the scenario's shape. *)
  Alcotest.(check int)
    "the scenario CR has replicas = 1, so ordinal 0 is NEEDED and ordinal 1 is \
     CONDEMNED - the comparison M1a's row turns on"
    1 replicas

(* ==== M1's TWO NOVEL CONJUNCTS, each with P23's L1 shown GREEN =============
   This is the phase's central claim at state level: M1 is not "L1 wearing a
   hat". Upstream :202 wants the EXACT ordinal-indexed name where L1 wants only
   that SOME ordinal parses, and the [>= replicas] bound of upstream :212 has
   NO L1 counterpart at all. Both rows put the SAME state to both registers.

   THE STEP IS [Delete_condemned], AND THE CHOICE IS EVIDENCE-DRIVEN. It has to
   be one of the FOURTEEN steps in M1's borrowed [at_vsts_step] premise, or the
   verdict would be an out-of-premise fold rather than a red. The obvious
   candidate is [Skip_pvc], which gates none of the cursor implications at all
   - but probe B2's occupancy dump (printed by t_p24_state_predicates) shows
   ALL FIVE PVC-family steps at ZERO on every one of the four shipped graphs,
   so a forged state there would sit at a step no graph reaches and the row
   would be red capability for a configuration the port never enters.
   [Delete_condemned] has non-zero occupancy on all four, so these rows are at
   least ANCHORED to a reached step. They still do not prove the port can reach
   THIS state - only a source mutant re-explored over the graph does that - and
   the header says so.

   [Delete_condemned] gates exactly one cursor implication, upstream :239
   ([condemned_index < condemned.len()]), which is why every row below carries
   a NON-EMPTY [condemned]: with [condemned = []] the implication is [0 < 0]
   and M1 would be red for a reason that is not the row's subject. *)

let m1_state ~(needed : Pod.t option list) ~(condemned : Pod.t list) :
    Cluster.cluster_state =
  forge ~step:Vsr.Delete_condemned ~needed ~condemned ~pending:None

let test_m1_novel_conjuncts () =
  (* --- the accepted control FIRST ----------------------------------------- *)
  let accepted = m1_state ~needed:[ Some good_pod0 ] ~condemned:[ good_pod1 ] in
  Alcotest.(check bool) "control: the injection landed" true
    (injection_landed accepted);
  Alcotest.(check bool)
    "control: M1's premise FIRES on it (Delete_condemned is one of the \
     fourteen at_vsts_step steps AND has non-zero occupancy on every shipped \
     graph), so the reds below are attributable to the payload and not to a \
     dead premise"
    true
    (fires family m1_name accepted);
  Alcotest.(check bool)
    "control: the reconciler's OWN shapes are GREEN for M1 - needed slot 0 \
     holds pod-0, condemned holds pod-1 at ordinal >= replicas"
    true
    (holds family m1_name accepted);
  Alcotest.(check bool) "control: and GREEN for P23's L1 too" true
    (holds p23_family l1_name accepted);
  (* --- M1a: upstream :212, the ordinal BOUND with no L1 counterpart -------- *)
  let m1a = m1_state ~needed:[ None ] ~condemned:[ good_pod0 ] in
  Alcotest.(check bool) "M1a: the injection landed" true (injection_landed m1a);
  Alcotest.(check bool) "M1a: M1's premise fires" true (fires family m1_name m1a);
  Alcotest.(check bool)
    "M1a: M1 is RED on a condemned entry whose ordinal is 0 - upstream :212 \
     wants get_ordinal(name) >= replicas, and this is the conjunct P23 has NO \
     counterpart for"
    false
    (holds family m1_name m1a);
  Alcotest.(check bool)
    "M1a DISCRIMINATION: P23's L1 is GREEN on the SAME state - its pod_name_match \
     only asks that SOME ordinal parses (local_binding.ml:86-87) and it never \
     compares the ordinal to replicas. This is what 'M1 is strictly stronger' \
     means, exhibited rather than argued."
    true
    (holds p23_family l1_name m1a);
  (* --- M1b: upstream :202, the EXACT ordinal-indexed name ------------------ *)
  let m1b = m1_state ~needed:[ Some good_pod1 ] ~condemned:[ good_pod1 ] in
  Alcotest.(check bool) "M1b: the injection landed" true (injection_landed m1b);
  Alcotest.(check bool) "M1b: M1's premise fires" true (fires family m1_name m1b);
  Alcotest.(check bool)
    "M1b: M1 is RED when the pod named for ordinal 1 sits in needed slot \
     ORDINAL 0 - upstream :202 wants name == Some (pod_name parent ord) for \
     THAT slot's ordinal"
    false
    (holds family m1_name m1b);
  Alcotest.(check bool)
    "M1b DISCRIMINATION: P23's L1 is GREEN on the SAME state - it inverts \
     through get_ordinal and any parseable pod name satisfies it, whichever \
     slot the pod is in"
    true
    (holds p23_family l1_name m1b);
  (* --- the CONTAINMENT datum, so the two rows above are not read as "M1 reds
         on everything": the namespace sub-conjunct is SHARED, and there both
         registers red together. *)
  let shared = m1_state ~needed:[ None ] ~condemned:[ foreign_ns_pod ] in
  Alcotest.(check bool)
    "CONTAINMENT: a condemned pod in a FOREIGN namespace reds M1 (upstream \
     :214)"
    false
    (holds family m1_name shared);
  Alcotest.(check bool)
    "CONTAINMENT: ...and reds P23's L1 too - that sub-conjunct is SHARED, \
     which is exactly why the two rows above had to show L1 GREEN to mean \
     anything"
    false
    (holds p23_family l1_name shared)

(* ==== the P26 FORGED-STATE rows FS1-FS14 (BUILD-SPEC-P26 section 2) ========
   One row per unexercised M1 conjunct site - the route
   state_predicates.mli:364-374 records: forge a decoded state at a step
   inside [at_valid_step] violating exactly that conjunct, assert M1 RED with
   the accepted-state control asserted GREEN first, and P23's L1 GREEN on the
   SAME state (discrimination). Negative index forgeries are representable
   because the port's cursors are [int] where upstream's are [nat]
   (state_predicates.ml:253-256) - that is why the [>= 0] halves exist as
   deletable sites at all. Isolation is ENFORCED by the stage-C deletion
   trials, not argued here; each row's label names its ONE subject conjunct. *)

let test_p26_m1_forged_rows () =
  (* --- the accepted control FIRST, through the SAME builder every row
         rides, so the reds below are attributable to each row's payload and
         not to [forge_at]'s plumbing ---------------------------------------- *)
  let accepted =
    forge_at ~step:Vsr.Delete_condemned ~needed:[ Some good_pod0 ]
      ~needed_index:0 ~condemned:[ good_pod1 ] ~condemned_index:0 ~pending:None
  in
  Alcotest.(check bool) "control: the injection landed" true
    (injection_landed accepted);
  Alcotest.(check bool) "control: M1's premise FIRES on the forge_at state"
    true
    (fires family m1_name accepted);
  Alcotest.(check bool)
    "control: the reconciler's OWN shapes are GREEN through forge_at at the \
     cursor values [reconcile_state] hard-codes"
    true
    (holds family m1_name accepted);
  Alcotest.(check bool) "control: and GREEN for P23's L1 too" true
    (holds p23_family l1_name accepted);
  (* --- the four-assert row discipline, shared by all fourteen rows -------- *)
  let fs_row ~(label : string) ~(why : string) (s : Cluster.cluster_state) :
      unit =
    Alcotest.(check bool) (label ^ ": the injection landed") true
      (injection_landed s);
    Alcotest.(check bool) (label ^ ": M1's premise fires") true
      (fires family m1_name s);
    Alcotest.(check bool) (label ^ ": M1 is RED - " ^ why) false
      (holds family m1_name s);
    Alcotest.(check bool)
      (label
      ^ " DISCRIMINATION: P23's L1 is GREEN on the SAME state - \
         bound_in_local_state reads only the pods' names and namespaces \
         (local_binding.ml:126-136), never a cursor and never a step")
      true
      (holds p23_family l1_name s)
  in
  fs_row ~label:"FS1(:194)"
    ~why:
      "needed has length 0 while replicas is 1; :239 stays green (0 < 1 on \
       the non-empty condemned) and :248 stays green (Delete_condemned is \
       condemned-or-later)"
    (m1_state ~needed:[] ~condemned:[ good_pod1 ]);
  fs_row ~label:"FS2(:195 half A)"
    ~why:
      "needed_index -1 fails >= 0 while -1 <= 1 keeps half B green; at Done \
       every step gate is off and :248 is green (Done is condemned-or-later)"
    (forge_at ~step:Vsr.Done ~needed:[ Some good_pod0 ] ~needed_index:(-1)
       ~condemned:[] ~condemned_index:0 ~pending:None);
  fs_row ~label:"FS3(:195 half B)"
    ~why:
      "needed_index 2 fails <= needed_len 1 while 2 >= 0 keeps half A green; \
       the :230-231 gate is off at Done"
    (forge_at ~step:Vsr.Done ~needed:[ Some good_pod0 ] ~needed_index:2
       ~condemned:[] ~condemned_index:0 ~pending:None);
  fs_row ~label:"FS4(:196 half A)"
    ~why:
      "condemned_index -1 fails >= 0 while -1 <= 1 keeps half B green; the \
       :239 and :240 gates are off at Done"
    (forge_at ~step:Vsr.Done ~needed:[ Some good_pod0 ] ~needed_index:0
       ~condemned:[ good_pod1 ] ~condemned_index:(-1) ~pending:None);
  fs_row ~label:"FS5(:196 half B)"
    ~why:
      "condemned_index 2 fails <= condemned_len 1; Done avoids :239 (whose \
       gate would also red at Delete_condemned) and :248 is green there"
    (forge_at ~step:Vsr.Done ~needed:[ Some good_pod0 ] ~needed_index:0
       ~condemned:[ good_pod1 ] ~condemned_index:2 ~pending:None);
  fs_row ~label:"FS6(:230-231)"
    ~why:
      "needed_index 1 fails < needed_len 1 at Create_needed - the \
       state_predicates.mli:368-369 example; :235 stays green (slot 1 is out \
       of range and folds none -> true) and :195 half B stays green (1 <= 1)"
    (forge_at ~step:Vsr.Create_needed ~needed:[ Some good_pod0 ]
       ~needed_index:1 ~condemned:[] ~condemned_index:0 ~pending:None);
  fs_row ~label:"FS7(:235)"
    ~why:
      "slot 0 is Some at Create_needed where the conjunct wants None - the \
       mli:369-370 example; :230-231 stays green (0 < 1)"
    (forge_at ~step:Vsr.Create_needed ~needed:[ Some good_pod0 ]
       ~needed_index:0 ~condemned:[] ~condemned_index:0 ~pending:None);
  fs_row ~label:"FS8(:236)"
    ~why:
      "slot needed_index - 1 = 0 is Some at After_create_needed where the \
       conjunct wants None; :242 stays green (1 > 0) and the :230-231 gate \
       is off"
    (forge_at ~step:Vsr.After_create_needed ~needed:[ Some good_pod0 ]
       ~needed_index:1 ~condemned:[] ~condemned_index:0 ~pending:None);
  fs_row ~label:"FS9(:237)"
    ~why:
      "slot 0 is None at Update_needed where the conjunct wants Some; :194 \
       stays green (length 1 = replicas) and :230-231 stays green (0 < 1)"
    (forge_at ~step:Vsr.Update_needed ~needed:[ None ] ~needed_index:0
       ~condemned:[] ~condemned_index:0 ~pending:None);
  fs_row ~label:"FS10(:238)"
    ~why:
      "slot needed_index - 1 = 0 is None at After_update_needed where the \
       conjunct wants Some; :242 stays green (1 > 0)"
    (forge_at ~step:Vsr.After_update_needed ~needed:[ None ] ~needed_index:1
       ~condemned:[] ~condemned_index:0 ~pending:None);
  fs_row ~label:"FS11(:239)"
    ~why:
      "condemned_index 1 fails < condemned_len 1 at Delete_condemned; :196 \
       half B stays green (1 <= 1) and :248 stays green (condemned-or-later)"
    (forge_at ~step:Vsr.Delete_condemned ~needed:[ Some good_pod0 ]
       ~needed_index:0 ~condemned:[ good_pod1 ] ~condemned_index:1
       ~pending:None);
  fs_row ~label:"FS12(:240)"
    ~why:
      "condemned_index 0 fails > 0 at After_delete_condemned; the :239 gate \
       is off there and :196 half A stays green (0 >= 0)"
    (forge_at ~step:Vsr.After_delete_condemned ~needed:[ Some good_pod0 ]
       ~needed_index:0 ~condemned:[ good_pod1 ] ~condemned_index:0
       ~pending:None);
  fs_row ~label:"FS13(:242)"
    ~why:
      "needed_index 0 fails > 0 at After_create_needed - the mli:370-371 \
       example; :236 stays green (slot -1 is out of range and folds none -> \
       true)"
    (forge_at ~step:Vsr.After_create_needed ~needed:[ None ] ~needed_index:0
       ~condemned:[] ~condemned_index:0 ~pending:None);
  fs_row ~label:"FS14(:248)"
    ~why:
      "condemned_index 1 fails = 0 at Create_needed, which is NOT \
       condemned-or-later - the mli:371-372 example; needed [None] keeps :235 \
       green and :196 half B stays green (1 <= 1)"
    (forge_at ~step:Vsr.Create_needed ~needed:[ None ] ~needed_index:0
       ~condemned:[ good_pod1 ] ~condemned_index:1 ~pending:None)

(* ==== M3's SHAPE CONJUNCTS, and which of them L2 does NOT carry ============
   RULING section 3.1 ships upstream :108-115 and :125-132 unconditionally and
   says they are killable at GRAPH level. The rows here are the STATE-level
   half, and they separate the two conjuncts that are genuinely M3's (:115 the
   no-duplicate object refs, :126-127 the kind / unmarshals-as-a-Pod pair) from
   the one that P23's L2 already carries (:129-130, the namespace).

   Every state is parked with the SAME pending request and ONE forged in-flight
   ok [List_response] formed FROM it (so upstream's :655 api-server source and
   :656 [resp_msg_matches_req_msg] hold BY CONSTRUCTION rather than by a
   hand-typed rpc id that could drift). *)

let test_m3_shape_conjuncts () =
  let accepted = parked_with etcd_owned_objs in
  (* --- controls that the forgery LANDED and is SELECTED, before any verdict *)
  Alcotest.(check bool) "control: the injection landed" true
    (injection_landed accepted);
  Alcotest.(check bool)
    "control: the CR HAS a controller owner reference - without it the \
     seed-read baseline below is empty and every RED row becomes a green about \
     nothing"
    true
    (Option.is_some seed_owner_ref);
  Alcotest.(check bool)
    "control: the seed-read baseline is NON-EMPTY - the response really carries \
     the pods the seed's etcd holds for this CR, so each row below is \
     attributable to the ONE shape conjunct it perturbs"
    true
    (not (etcd_owned_objs = []));
  Alcotest.(check int)
    "control: EXACTLY ONE matching ok List_response is in flight - upstream \
     :79-83 SELECTS it, so List.for_all is NOT folding over the empty list \
     (the vacuity that would make every row below a green about nothing)"
    1
    (List.length (W.ok_list_resps_for accepted pod_list_req));
  Alcotest.(check int)
    "control: the SAME parked shape with NO response in flight selects ZERO - \
     that is the vacuous green this whole case exists to avoid"
    0
    (List.length
       (W.ok_list_resps_for
          (forge ~step:Vsr.After_list_pod ~needed:[] ~condemned:[]
             ~pending:(Some pod_list_req))
          pod_list_req));
  Alcotest.(check bool) "control: M3's premise FIRES on the accepted state" true
    (fires family m3_name accepted);
  Alcotest.(check bool)
    "control: a response carrying exactly the pods the seed's etcd holds for \
     this CR is GREEN for M3 - all SEVEN shipped pure-shape conjuncts"
    true
    (holds family m3_name accepted);
  Alcotest.(check bool) "control: and GREEN for P23's L2" true
    (holds p23_family l2_name accepted);
  (* --- :115, the no-duplicate object refs: NOT carried by L2 --------------
         The SAME objects listed twice. Every other shipped conjunct is a
         [List.for_all] over the objects, which duplication cannot move, so
         only :115 can fire. *)
  let dup = parked_with (etcd_owned_objs @ etcd_owned_objs) in
  Alcotest.(check bool) "M3a(:115): M3's premise fires" true
    (fires family m3_name dup);
  Alcotest.(check bool)
    "M3a(:115): M3 is RED on a response carrying the SAME object ref twice - \
     upstream :115 is Seq::no_duplicates over the objects' refs"
    false
    (holds family m3_name dup);
  Alcotest.(check bool)
    "M3a(:115) DISCRIMINATION: P23's L2 is GREEN on the SAME state - \
     resp_objs_in_namespace (local_binding.ml:206-212) reads only the \
     namespace and has no cardinality conjunct at all"
    true
    (holds p23_family l2_name dup);
  (* --- :126-127, kind is PodKind / it unmarshals as a Pod: NOT carried by L2
         Added ON TOP of the seed-read baseline; only :126 and :127 can fire. *)
  let non_pod = parked_with (non_pod_obj :: etcd_owned_objs) in
  Alcotest.(check bool) "M3a(:126-127): M3's premise fires" true
    (fires family m3_name non_pod);
  Alcotest.(check bool)
    "M3a(:126-127): M3 is RED on a listed object whose kind is NOT PodKind \
     (the CR itself, marshalled) - upstream :126 and :127"
    false
    (holds family m3_name non_pod);
  Alcotest.(check bool)
    "M3a(:126-127) DISCRIMINATION: P23's L2 is GREEN on the SAME state - the \
     object carries the CR's OWN namespace, which is all L2 looks at"
    true
    (holds p23_family l2_name non_pod);
  (* --- :129-130, the namespace: SHARED with L2, kept as the containment datum
         The only conjunct that fires is the one both registers carry. *)
  let foreign = parked_with (foreign_ns_obj :: etcd_owned_objs) in
  Alcotest.(check bool)
    "CONTAINMENT(:129-130): M3 is RED on an object OUTSIDE the CR's namespace"
    false
    (holds family m3_name foreign);
  Alcotest.(check bool)
    "CONTAINMENT(:129-130): ...and so is P23's L2 - that conjunct is SHARED, \
     which is why the two rows above had to show L2 GREEN to mean anything"
    false
    (holds p23_family l2_name foreign)

(* ==== the P26 FORGED-STATE row FS15, M3's :128 (BUILD-SPEC-P26 section 2) ==
   The last unexercised buyable site: :128 wants [metadata.name is Some] of
   every listed object. Disclosed FS15 risk note (spec section 2): :127
   ([Pod.unmarshal]) and :132 ([objects_to_pods]) on a nameless pod object
   are expected green by CODE READING, not by measurement; if either also
   reds, the stage-C deletion trial stays green after deleting :128 and the
   survivor is recorded as a FINDING - the forgery is never retuned to force
   the trial red. *)

let test_p26_m3_128_row () =
  (* --- the accepted control FIRST ----------------------------------------- *)
  let accepted = parked_with etcd_owned_objs in
  Alcotest.(check bool) "control: the injection landed" true
    (injection_landed accepted);
  Alcotest.(check bool)
    "control: the seed-read baseline is NON-EMPTY - the nameless object below \
     is added ON TOP of a real payload, so the red is attributable to the ONE \
     conjunct it perturbs"
    true
    (not (etcd_owned_objs = []));
  Alcotest.(check bool) "control: M3's premise FIRES on the accepted state"
    true
    (fires family m3_name accepted);
  Alcotest.(check bool) "control: the accepted payload is GREEN for M3" true
    (holds family m3_name accepted);
  Alcotest.(check bool) "control: and GREEN for P23's L2" true
    (holds p23_family l2_name accepted);
  (* --- FS15: upstream :128, the name-is-Some conjunct --------------------- *)
  let fs15 = parked_with (nameless_pod_obj :: etcd_owned_objs) in
  Alcotest.(check bool) "FS15(:128): the injection landed" true
    (injection_landed fs15);
  Alcotest.(check bool) "FS15(:128): M3's premise fires" true
    (fires family m3_name fs15);
  Alcotest.(check bool)
    "FS15(:128): M3 is RED on a listed pod object whose metadata.name is None \
     - upstream :128 wants name is Some; the namespace is still the CR's own \
     so :129-130 cannot fire, and a nameless ref renders name \"\" \
     (state_predicates.ml:445-452) so :115 sees no duplicate"
    false
    (holds family m3_name fs15);
  Alcotest.(check bool)
    "FS15(:128) DISCRIMINATION: P23's L2 is GREEN on the SAME state - \
     resp_objs_in_namespace (local_binding.ml:206-212) reads only the \
     namespace, which is present"
    true
    (holds p23_family l2_name fs15)

(* ==== WHERE THE M3c AND M3d ROWS WENT ======================================
   Two further rows used to live at the end of the case above:

     M3c(:116-118)  a response claiming an OWNED object that etcd does not
                    hold - M3 RED, P23's L2 GREEN;
     M3d(:123)      a response whose owned object's metadata has DRIFTED from
                    etcd's copy while its KEY is still present, so :122 held and
                    only [weakly_eq] could fire - M3 RED, L2 GREEN.

   Both are REMOVED, together with their fixtures ([listed_obj], [dyn_key],
   [in_etcd], [drift]), because the conjuncts they exercised are now
   EXCLUDED-WITH-A-PIN on the SCOPE ground and the member is GREEN on those
   states. Keeping them would have meant inverting two red-capability exhibits
   into assertions about nothing, and keeping their fixtures would have left
   helpers with no consumer - the dead code the house rule forbids.

   THE EVIDENCE IS NOT LOST, IT WAS PROMOTED. What those two rows showed on
   FORGED states is now MEASURED on the four REAL graphs by probe B5 and
   asserted by [t_p24_state_predicates]'s [scope_exclusion_pin]: the set
   equality fails at 0 / 8 / 0 / 72 states and the coherence forall at
   0 / 4 / 0 / 40, with the containment directions and the :122 / :123 split
   pinned separately. A refutation reached by the port's own transitions
   outranks a red on a state nobody proved reachable, so the exclusion is
   better evidenced now than the rows it replaced. *)

(* ==== the SP0 replica, for MP5 and MP7's control ========================== *)

let sp0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (Mc.explore ~depth
       ~successors:(Fc.faulted_successors bound W.zero_budget cluster)
       ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
       ~init:[ Fc.faulted_of_seed seed ])

let count_where (reach : Fc.faulted Mc.reachable)
    (p : Cluster.cluster_state -> bool) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) -> p f.cs)

(* ==== MP5: PREMISE WIRING ================================================== *)

let test_mp5_premise_wiring () =
  let reach = Lazy.force sp0_reach in
  (* replica faithfulness FIRST: a drifted replica would silently measure a
     different graph (the P13 M3/M5 precedent). The pin is P23's, INHERITED. *)
  Alcotest.(check int)
    "MP5: replica states = the graph P23 committed and P24 rides unchanged"
    W.sp0_states (Mc.states_seen reach);
  (* the contrast, at the RIGHT id: every premise is live somewhere. The exact
     counts are stage B's and are PRINTED by t_p24_state_predicates; what is
     asserted here is only the floor. *)
  List.iter
    (fun (name : string) ->
      Alcotest.(check bool)
        (name
       ^ ": interesting > 0 at the TRUE controller id (the contrast the row \
          below is a contrast WITH)")
        true
        (count_where reach (W.member_interesting family name) > 0))
    W.member_names;
  let wrong_id : Invariants.invariant list =
    Sp.predicate_family ~cr ~controller_id:(controller_id + 1)
  in
  List.iter
    (fun (name : string) ->
      Alcotest.(check int)
        (name
       ^ ": interesting = 0 over ALL of SP0 at controller_id + 1 - the premise \
          keys on the id, so a non-zero per-member interesting is the only \
          evidence the family was wired to the leg's controller at all")
        0
        (count_where reach (W.member_interesting wrong_id name));
      (* THE VACUOUS-TRUTH COLUMN, and the ONLY independence claim that survives
         the M2 cut. The old justification here - "the CUT M2 candidate read the
         id a SECOND time through :49, so the two were independent claims" - was
         false for this scenario even before the cut (M2's :49 conjunct sat
         BEHIND the same [at_reconcile] premise, so it could never be reached at
         an id whose reconcile map is empty) and is moot now that M2 is gone.
         What IS independent is the POLARITY: [interesting] is built with
         [~absent:false ~undecodable:false] and [holds] with
         [~absent:true ~undecodable:true] (state_predicates.ml:661-698), so the
         two columns read OPPOSITE arms of the same fold. Flipping [holds]'s
         [~absent:true] to [~absent:false] - the token that makes an absent
         reconcile a vacuous TRUTH rather than a vacuous FALSITY - leaves the
         column above at 0 and reddens this one at every state. That mutant is
         the reason this row is asserted rather than inferred; it was run, and
         it is in the mutation ledger of BUILD-SPEC-P24. *)
      Alcotest.(check int)
        (name
       ^ ": red = 0 over ALL of SP0 at controller_id + 1 - vacuous TRUTH, not \
          vacuous falsity (ongoing_reconciles is TOTAL, cluster.mli:78-82). \
          This is the ~absent:true / ~undecodable:true arm of at_reconcile, \
          the OPPOSITE polarity to the interesting column above: flipping that \
          one token reddens THIS row and leaves that one at 0.")
        0
        (count_where reach (fun (s : Cluster.cluster_state) ->
             not (W.member_holds wrong_id name s))))
    W.member_names

(* ==== MP6: the DECODE-FAILURE FOLD, given an input that EXERCISES it ======= *)

let undecodable_local_state : Value.t =
  Value.of_json (`String "MP6: deliberately not a marshalled reconcile state")

let undecodable_state : Cluster.cluster_state =
  install
    {
      Controller.triggering_cr = V_stateful_set.marshal cr;
      pending_req_msg = None;
      local_state = undecodable_local_state;
      reconcile_id = 0;
    }

let decodes_at_cr_key (s : Cluster.cluster_state) : bool option =
  Option.map
    (fun (o : Controller.ongoing_reconcile) ->
      Result.is_ok (Pack.unmarshal_state o.Controller.local_state))
    (Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id))

let test_mp6_decode_failure_fold () =
  (* Two controls FIRST, in order. Without them a failed injection reads as
     "the member holds" through the [~absent:true] fold and this whole case
     would be a green measuring the untouched seed. *)
  Alcotest.(check (option bool))
    "MP6 control: the ongoing reconcile IS installed at the CR key, and its \
     local_state is UNDECODABLE - the input no shipped graph produces (decode \
     failures are 0 on all four)"
    (Some false)
    (decodes_at_cr_key undecodable_state);
  Alcotest.(check (option bool))
    "MP6 control: the SAME injection with a well-formed local_state DOES \
     decode - so the line above is the codec refusing, not the injection \
     missing"
    (Some true)
    (decodes_at_cr_key
       (forge ~step:Vsr.Skip_pvc ~needed:[ None ] ~condemned:[] ~pending:None));
  (* THE ROW: [~undecodable:true] on both shipped members. *)
  List.iter
    (fun (name : string) ->
      Alcotest.(check bool)
        (name
       ^ ": HOLDS on an undecodable local state - this is [~undecodable:true] \
          in State_predicates.predicate_family, and flipping that single token \
          is a mutant NOTHING in the graph battery can kill, because that fold \
          is dead code where decode failures are 0")
        true
        (W.member_holds family name undecodable_state);
      Alcotest.(check bool)
        (name
       ^ ": ...and is OUT OF PREMISE there ([~undecodable:false] on the \
          interesting side) - out of premise is holds TRUE and interesting \
          FALSE, never both")
        false
        (W.member_interesting family name undecodable_state))
    W.member_names

(* ==== MP7: the PVC-EXCLUSION PIN's RED CAPABILITY ==========================
   M1 excludes SEVEN conjuncts on the pin "no decoded ongoing state has a PVC"
   (RULING section 1; :246 is PVC-family but dies on the REACHABILITY ground it
   shares with :241, not on this pin), so that pin has to be seen to redden or
   "excluded with a pin" degrades to "omitted". A throwaway [vct:true] seed
   makes [make_pvcs]
   (v_stateful_set_reconciler.ml:292-296) return a non-empty list. Deliberately
   a FLOOR, not a pin: no shipped leg explores this graph and committing its
   size would be a number nothing can move. *)

let vct_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (Mc.explore ~depth
       ~successors:(Fc.faulted_successors bound W.zero_budget cluster)
       ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
       ~init:
         [
           Fc.faulted_of_seed
             (Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true
                ~req_drop:false ~pod_monkey:false ~vct:true ());
         ])

let decoded_pvcs_non_empty (s : Cluster.cluster_state) : bool =
  W.at_orc ~controller_id ~cr_key
    (fun _ (st : Vsr.s) _ -> not (st.Vsr.pvcs = []))
    s

let test_mp7_pvc_pin_reddens () =
  let reach = Lazy.force vct_reach in
  Alcotest.(check bool)
    "MP7: the throwaway vct:true graph really explored (a dead graph would \
     make the floor below vacuous)"
    true
    (Mc.states_seen reach > 0);
  Alcotest.(check bool)
    "MP7: the PVCS-ARE-EMPTY pin REDDENS on a vct:true seed - so M1's SEVEN \
     PVC-pinned conjuncts are excluded-and-watched, not omitted"
    true
    (count_where reach decoded_pvcs_non_empty > 0);
  Alcotest.(check int)
    "MP7 control: the same projection is 0 on the SHIPPED vct:false SP0 graph"
    W.pvcs_non_empty_everywhere
    (count_where (Lazy.force sp0_reach) decoded_pvcs_non_empty)

(* ==== MP8: the BARE-SOURCE TRAP, exhibited =================================
   A verbatim copy of [t_p21_regression.ml:479-483]'s parser - the
   guarded-total [sub_opt] and [line_of_source]. Copied rather than shared,
   because the point of the row is what THAT parser does; a shared helper that
   drifted would take the exhibit with it. *)

let sub_opt (s : string) (pos : int) (len : int) : string option =
  if pos >= 0 && len >= 0 && pos + len <= String.length s then
    Some (String.sub s pos len) (* @total-accessor *)
  else None

let line_of_source (s : string) : int option =
  Option.bind (String.rindex_opt s ':') (fun (i : int) ->
      Option.bind
        (sub_opt s (i + 1) (String.length s - i - 1))
        int_of_string_opt)

let test_mp8_bare_source_trap () =
  Alcotest.(check int)
    "MP8: every shipped P24 source parses to a line number (a qualifier on \
     EITHER of them makes the member invisible to t_p21_regression's roster \
     sweep while the firewall pin still PASSES)"
    (List.length Sp.predicate_sources)
    (List.length (List.filter_map line_of_source Sp.predicate_sources));
  Alcotest.(check (list int))
    "MP8: and they parse to M1 :192, M3 :107, in member order - :45 is ABSENT \
     because the M2 candidate is CUT, and a cut member must not survive as a \
     source string either"
    [ 192; 107 ]
    (List.filter_map line_of_source Sp.predicate_sources);
  Alcotest.(check bool)
    "MP8: a PARENTHETICAL QUALIFIER makes line_of_source return None - the \
     member then DROPS OUT of the roster silently, which is why the \
     per-conjunct partition lives in the .mli and never in a source string"
    true
    (Option.is_none
       (line_of_source
          "vstatefulset_controller/proof/liveness/state_predicates.rs:192 (15 \
           of 23 conjuncts)"));
  Alcotest.(check bool)
    "MP8: so does a trailing space, and so does a non-numeric tail - the \
     parser is int_of_string_opt on everything after the LAST colon"
    true
    (Option.is_none
       (line_of_source
          "vstatefulset_controller/proof/liveness/state_predicates.rs:192 ")
    && Option.is_none
         (line_of_source
            "vstatefulset_controller/proof/liveness/state_predicates.rs:one-\
             ninety-two"))

let () =
  Alcotest.run "p24_mutation"
    [
      ( "family_shape",
        [
          Alcotest.test_case
            "predicate_family = M1/M3, addressable by name, alongside P23's \
             binding_family at the same arguments"
            `Quick test_family_shape;
        ] );
      ( "m1_novel_conjuncts",
        [
          Alcotest.test_case
            "M1a :212 (the ordinal bound) and M1b :202 (the exact \
             ordinal-indexed name) each red M1 while P23's L1 stays GREEN"
            `Quick test_m1_novel_conjuncts;
        ] );
      ( "m3_shape_conjuncts",
        [
          Alcotest.test_case
            "M3's :115 no-duplicates and :126-127 kind/unmarshal each red M3 \
             with L2 GREEN; :129-130 reds both (the containment datum). The \
             :116-118 and :123 rows are RETIRED - those conjuncts are EXCLUDED \
             on the SCOPE ground and their evidence is now a measured pin."
            `Quick test_m3_shape_conjuncts;
        ] );
      ( "p26_m1_forged_rows",
        [
          Alcotest.test_case
            "FS1-FS14: each of the fourteen unexercised M1 cursor and slot \
             conjunct sites reds M1 on a forged state while P23's L1 stays \
             GREEN (BUILD-SPEC-P26 section 2)"
            `Quick test_p26_m1_forged_rows;
        ] );
      ( "p26_m3_128_row",
        [
          Alcotest.test_case
            "FS15: a nameless listed pod object reds M3's :128 while P23's \
             L2 stays GREEN (BUILD-SPEC-P26 section 2)"
            `Quick test_p26_m3_128_row;
        ] );
      ( "mp5_premise_wiring",
        [
          Alcotest.test_case
            "the family at controller_id + 1 is interesting 0 AND red 0 over \
             all of SP0 - vacuous TRUTH, not vacuous falsity"
            `Quick test_mp5_premise_wiring;
        ] );
      ( "mp6_decode_failure_fold",
        [
          Alcotest.test_case
            "both members HOLD and are OUT OF PREMISE on an undecodable \
             local state - the fold no graph assertion can reach"
            `Quick test_mp6_decode_failure_fold;
        ] );
      ( "mp7_pvc_pin",
        [
          Alcotest.test_case
            "the pin M1's SEVEN PVC-excluded conjuncts die on REDDENS on a \
             throwaway vct:true seed, and is 0 on the shipped one"
            `Quick test_mp7_pvc_pin_reddens;
        ] );
      ( "mp8_bare_source_trap",
        [
          Alcotest.test_case
            "both P24 sources are BARE and parse; a parenthetical \
             qualifier makes the member silently invisible"
            `Quick test_mp8_bare_source_trap;
        ] );
    ]

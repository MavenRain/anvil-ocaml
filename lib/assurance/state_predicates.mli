(** P24 VSTS state-predicate register (BUILD-SPEC-P24 §2, settled by
    [~/Documents/anvil-ocaml-p24-harness/RULING.md] §1-§3): the first shipped
    members of
    [vstatefulset_controller/proof/liveness/state_predicates.rs].

    {b Why a file under [liveness/] belongs in a SAFETY register.} All 34
    [StatePred] occurrences in that file are [-> StatePred<ClusterState>] and it
    contains {b zero} [TempPred] / [ActionPred] / [leads_to] / [eventually] /
    [always(] (BUILD-SPEC-P24 §1, [rg] re-measured in the main loop). Nothing
    here is temporal.

    {b NOVELTY, in its exact MEASURED wording, and it is FILE-level.} The
    repaired probe [rg -n 'state_predicates' lib test -g '!*.md'] exited 1
    before this module (MEASURED; the un-flagged form recorded at
    BUILD-SPEC-P23.md:765 now exits 0 on markdown self-matches only and must
    never be quoted). So these are the first shipped members from
    [state_predicates.rs] at all. What is {b not} claimed: that the CONJUNCTS
    are new to the tree - M3's :129-130 is already carried by P23's L2, and that
    containment is spelled out per member below.

    {b WHAT A RED MEANS HERE.} Upstream uses these predicates as milestones in a
    discharged liveness proof, so a red is not "the environment misbehaved" but
    a {b FIDELITY DIVERGENCE in the port} - the port's reconciler reached a
    local state, or parked on a request, that upstream's proof says it cannot -
    and it is a real finding. The P21/P23 epistemic reading carries over
    unchanged.

    {b THAT READING HAS ONE STANDING QUALIFICATION AND THIS PHASE HAD TO USE
    IT.} It holds only for conjuncts upstream asserts of the executions this
    port explores. Where upstream itself SCOPES a conjunct to executions the
    port does not model, a red is neither a port defect nor environment noise -
    it is the conjunct being read outside its scope, and the honest response is
    to EXCLUDE the conjunct with a pin that records the refutation, never to
    relax the assertion or narrow the premise until the red falls outside it.
    That is what happened to M3's two etcd-consuming conjuncts; the M3 section
    below is the whole record.

    {b MEMBER PARTITION.} Family cardinal {b 2}, in this order:

    - {b M1} [local_state_is_valid] (:192-249), cited {b :192}. Fourteen of its
      twenty-three conjuncts PORT; {b nine} are EXCLUDED-WITH-A-PIN - seven on
      the PVC pin (a SHAPE ground) and two, :241 and :246, on a REACHABILITY
      ground of this phase's own. P25 later measured eight of the nine (the
      seven plus :246) premise-OCCUPIED on L0v at [vct:true] and re-filed
      them RED-CAPABILITY-PENDING; only :241's ground survives [vct:true]
      unchanged. See the grounds below.
    - {b M3} [resp_msg_is_ok_list_resp_of_pods] (:107-133) closed over the
      cluster state by [pending_list_pod_resp_in_flight] (:70-85), cited
      {b :107}. Its {b SEVEN PURE-SHAPE conjuncts SHIP} (:115, :126, :127, :128,
      :129, :130, :132); its {b two ETCD-CONSUMING conjuncts} :116-118 and
      :119-124 are {b EXCLUDED-WITH-A-PIN on a SCOPE ground}, and [weakly_eq]
      came out with them. This leg is GREEN on all four graphs. Read the M3
      section below before quoting that green: it is green {e because} of an
      exclusion whose evidence is a MEASURED REFUTATION, pinned as such.

    {b THE CARDINAL IS 2 AND IT WAS 3, AND THE MISSING MEMBER IS A RECORDED
    NEGATIVE RESULT, NOT AN OMISSION.} A third candidate - upstream
    [req_msg_is_list_pod_req] (:45-57) closed over the cluster state by
    [pending_list_pod_req_in_flight] (:59-66), which would have been cited
    {b :45} - was written, built, measured on all four graphs and
    mutation-tested, and is {b CUT}. Rendered as an INVARIANT over this port's
    graphs it is ENTIRELY CONTAINED in P23's shipped L2. The whole finding - the
    per-conjunct partition, the measurement, why its own mutant did not rescue
    it, and what would be needed to buy the one conjunct L2 lacks - is the
    {b NEGATIVE RESULT} section below. A consumer who reads the family and
    concludes "P24 says nothing about the parked REQUEST" is right about the
    shipped register and wrong about the phase: the phase measured it and
    reports that P23 already covers it.

    {b THE PHASE HAS ELEVEN EXCLUSIONS AND THEY REST ON THREE DIFFERENT
    GROUNDS ON THESE FOUR GRAPHS - P25 ADDED A FOURTH NAME FOR THE
    [vct:true]-FACING STATUS OF EIGHT OF THEM. A consumer who reads
    "excluded with a pin" as one thing is wrong about seven of them.}

    - {b SHAPE} - the PVC pin [P23_witness.pvcs_non_empty_everywhere = 0]. The
      guarded configuration is unreachable because no seed of THESE four
      graphs builds it. {b SEVEN M1 conjuncts}: :197, :198, :199, :215-221,
      :223-228, :233, :244 (with the :193 [pvc_cnt] binding they all read).
      Landing a [vct:true] leg retires this pin and brings all EIGHT
      PVC-family conjuncts back at once - these seven AND :246, not seven;
      P25 measured exactly that on L0v (the RED-CAPABILITY-PENDING ground
      below).
    - {b REACHABILITY} - a step-occupancy zero on THIS phase's four graphs. The
      guard never fires, so the conjunct is a green that could not have been
      red. {b TWO M1 conjuncts}: :241 (pinned by
      [P24_witness.after_delete_outdated_occupancy_everywhere = 0], and STILL
      zero on P25's L0v) and :246 (whose [pvc_index] is only ever mutated
      inside the [Get_pvc] family, unreachable on every [vct:false] graph, so
      it sits at a vacuous [0 == 0] HERE - P25 measured it LIVE at
      [vct:true]; see below). :246 is PVC-FAMILY by subject but does {e not}
      die on the PVC pin.
    - {b SCOPE} - upstream's own stated assumption does not hold in this port.
      The conjunct is not vacuous and not unreachable; it was RENDERED, RUN and
      REFUTED, and it is excluded because asserting it here asserts upstream's
      predicate outside the scope upstream gives it. {b TWO M3 conjuncts}:
      :116-118 and :119-124.
    - {b RED-CAPABILITY-PENDING} (added by P25) - the premise is proven
      non-vacuous (occupancy measured nonzero on L0v, P18's committed
      116-state [vct:true] graph) but no mutant has yet been shown to redden
      the conjunct at any occupied state, so it is neither a proven invariant
      nor a proven vacuity. {b EIGHT M1 conjuncts under vct:true}: :197,
      :198, :199, :215-221, :223-228, :233, :244, :246 - all eight, because
      landing a [vct:true] leg retires the SHAPE ground (the PVC pin itself
      reddens) for all eight at once, not seven; see the corrected count
      below. They stay excluded until a named mutant (corrupt the
      Create_pvc/Skip_pvc guard, or the [pvc_index] derivation) is run
      against L0v and shown to redden at least one. The occupancy pins are
      [P25_witness.l0v_get_pvc_family_occupancy = 40] and
      [P25_witness.l0v_246_premise_nonvacuity = 8], asserted by
      [t_p25_state_predicates].

    The first two grounds pin a VACUITY. The third pins a MEASURED REFUTATION
    WITH ATTRIBUTION, which is a stronger obligation and is discharged with
    stronger evidence - see the M3 section. The fourth pins a MEASURED
    NON-VACUITY whose red capability is PENDING (the P26 mutant named above).

    {b SOURCE-STRING RULE.} Each [source] names the upstream [pub open spec fn]
    whose {e conjuncts} the member renders, not the wrapper that lifts them to a
    [StatePred]. RULING §4 fixes M1's as [state_predicates.rs:192]; M3 follows
    the same rule, because :107 holds every ported conjunct while :70 supplies
    only the premise plumbing. A consumer re-deriving the citations must apply
    that rule, not the "outermost enclosing [StatePred]" rule P23 used for L2
    :640. {b [:45] IS NOT IN [predicate_sources] IN ANY FORM} - not qualified,
    not commented out. A source list is the roster's input
    (t_p21_regression.ml:479-483 parses it), so a cut member left there would
    re-enter every sweep that reads it; the cut is recorded in prose, where it
    belongs.

    {b M1 - NINE CONJUNCTS ARE EXCLUDED-WITH-A-PIN, AND THEY DO NOT ALL DIE ON
    THE SAME PIN. THE SPLIT IS LOAD-BEARING.} EIGHT of the nine are the
    PVC family by subject, and SEVEN of those collapse onto ONE
    already-committed pin - the same pin that killed P23's PVC forall. That is
    stated here rather than left implicit because seven separate conjuncts of a
    single upstream predicate collapsing onto one pin is the phase's largest
    single-pin exclusion. The NINTH is {b :241}, added before the phase sealed
    on stage B's own measurement, and it does {e not} rest on the PVC pin at
    all: it is excluded on REACHABILITY - a green that could not have been red.
    {b :246 and :241 SHARE that reachability ground ON THESE GRAPHS; the other
    SEVEN rest on the PVC pin.} A consumer who reads "nine excluded, one pin"
    is wrong about two of them, and a consumer who retires the PVC pin (by
    landing a [vct:true] leg) brings EIGHT conjuncts back into scope, not
    seven (not nine): P25's C1 probe evaluated :246's [pvc_index = pvc_cnt]
    equality at every premise-firing L0v state and it HELD on each, so :246
    returns to scope WITH the seven - still excluded, no mutant has yet
    shown red capability at an occupied state; see the
    RED-CAPABILITY-PENDING ground above. Only :241 stays behind: its step
    occupancy is zero even on L0v.

    - The eight PVC-family conjuncts are {b :197} ([pvc_index <= pvc_cnt]),
      {b :198}
      ([pvcs.len() == pvc_cnt]), {b :199} ([GetPVC ==> pvc_index < pvcs.len()]),
      {b :215-221} (the pvcs forall), {b :223-228} (the pvc-name block),
      {b :233} ([AfterCreatePVC ==> pvc_index > 0]), {b :244}
      ([locally_at_step_or!(GetPVC, AfterGetPVC, CreatePVC, SkipPVC) ==>
      pvc_index < pvc_cnt]) and {b :246}, together with the :193 [pvc_cnt]
      binding every one of them reads. The FIRST SEVEN die on the PVC pin
      HERE; :246 does not, for the reason two bullets down; at [vct:true]
      all EIGHT sit RED-CAPABILITY-PENDING together.
    - {b The pin is [P23_witness.pvcs_non_empty_everywhere = 0]}
      (p23_witness.ml:287), measured over {b 10,684} decoded states on all four
      committed graphs BL0/BLc/BLd/BLm. It is the identical pin P23 used to
      exclude the pvcs forall :629-637 of [internal_rely_guarantee.rs:613]
      (local_binding.mli:108-121). Independently re-derived from
      v_stateful_set_reconciler.ml:478-514: [Get_pvc] is entered only when
      [List.length state.pvcs > 0], and [state.pvcs] is always [[]] because
      [make_pvcs] (:292-296) folds an absent [volume_claim_templates], which is
      exactly [vct:false] (scenario.ml:240-241) - the only shape any of THESE
      four legs seeds. The moment a [vct:true] leg lands, that pin reddens and
      these SEVEN come back into scope together, with :246 making EIGHT -
      P25 measured it on L0v (the RED-CAPABILITY-PENDING ground above).
    - {b :246 is excluded on a different, subtler ground and the distinction
      matters.} Its guarding steps ([CreateNeeded] / [UpdateNeeded]) {e are}
      live. Its conclusion [pvc_index == pvc_cnt] is dead HERE anyway, because
      [pvc_index] is only ever mutated inside the [Get_pvc]-family arms,
      unreachable on every [vct:false] graph, so it sits at a vacuous
      [0 == 0] on all four and no real mutation to PVC-index tracking could
      turn it red on them. That is the house's "green that could not have
      been red" defect condition - a REACHABILITY exclusion, not a shape
      exclusion. At [vct:true] the index is LIVE and the equality was
      EVALUATED and HELD (P25's C1, stage B); see the
      RED-CAPABILITY-PENDING ground above.

    {b M1 - WHERE THE GENUINE NOVELTY IS.} :200-204 requires
    [name == Some(pod_name(parent, ord))], the {e exact} ordinal-indexed name,
    whereas P23's shipped L1 only requires that {e some} ordinal parses
    ([pod_name_matches] is [Option.is_some (get_ordinal parent name)],
    local_binding.ml:86-87) - strictly stronger. And :212's condemned
    [get_ordinal(...) >= replicas] bound has {b no P23 counterpart at all}.

    {b M1 - :241 IS EXCLUDED-WITH-A-PIN, AND THE PIN IS THIS PHASE'S OWN.} :241
    is [AfterDeleteOutdated ==> get_largest_unmatched_pods(vsts, needed) is
    Some]. It PORTED provisionally in stage A against RULING section 1's open
    obligation; stage B discharged that obligation and it is now EXCLUDED, before
    the phase seals, on the REACHABILITY ground.

    {b THE PIN, in the exact wording a consumer may quote:} this phase's own
    [reconcile_step] occupancy histogram - [P24_witness.step_occupancy], probe
    B2, run over BL0/BLc/BLd/BLm - measures the [After_delete_outdated] column
    at {b 0 on all four graphs}, pinned as
    [P24_witness.after_delete_outdated_occupancy_everywhere = 0], so :241's
    guard never fires, its consequent is a green that could not have been red,
    and it is EXCLUDED-WITH-A-PIN on that REACHABILITY ground - the ground
    :246 shared on these graphs, while the other SEVEN M1 exclusions rest on
    the PVC pin and M3's two rest on the SCOPE ground.

    {b The pin is measured on THESE graphs and is NEVER inherited from P11.} The
    only other [After_delete_outdated = 0] pin in the tree is
    t_p11_vsts_liveness.ml:113-114, and it lives on a {e different}, smaller
    20-state [fair:true] P11 graph;
    [rg 'After_delete_outdated|delete_outdated' test/p23_witness.ml] returns
    zero hits. Extrapolating that pin onto BL0/BLc/BLd/BLm is precisely the
    P11-graph evidence caveat this project already applies to the excluded
    outdated pipeline, and it is the error RULING section 1 names by hand.
    {b It is not a vacuous zero}: the sibling [Delete_outdated] column measures
    8 / 76 / 64 / 1272 on the same four graphs, so the outdated pipeline IS
    entered and the reconciler simply never advances past it under any shipped
    seed. That floor is asserted as a POSITIVE CONTROL immediately before the
    pin, and the histogram's own totality assertion (seventeen columns summing
    to the decoded population) forbids the zero from being a dropped column.

    {b The same histogram settles the OTHER step-conditioned rows, and settles
    them the other way.} :230-231, :235-:240, :242 and :248 were in :241's
    position - step-conditioned with no step histogram, since
    [needed_witness]/[condemned_witness] measure "some slot is populated", a
    different predicate from "[reconcile_step] = X". Probe B2 measures every one
    of their guarding steps as occupied on every graph ([Create_needed],
    [After_create_needed], [Update_needed], [After_update_needed],
    [Delete_condemned], [After_delete_condemned] are all non-zero on all four),
    so they stay PORTED and their guards are LIVE. Only [After_delete_outdated]
    and the five [Get_pvc]-family columns are empty.
    Unconditional on any state that reaches the premise below are :194, :195,
    :196, :200-204 and :205-214.

    {b AN OCCUPIED GUARD IS OCCUPANCY, NOT COVERAGE, AND THIS PARAGRAPH USED TO
    SAY "EXERCISED".} That word is withdrawn. A live guard means the conjunct is
    EVALUATED at reachable states; it says nothing about whether REMOVING the
    conjunct would be noticed. It would not be: deleting :230-231, :235, :236,
    :237, :238, :239, :240, :242 or :248 - individually, or all of them together
    with :194, :195 and :196 - leaves every one of the 82 test executables GREEN.
    The measurement is the DELETION block below, and it is the thing to quote
    about this member's coverage.

    {b M1 - THE STEP PREMISE IS BORROWED FROM UPSTREAM'S CALL SITES, AND IT IS A
    RENDERING NARROWING.} [local_state_is_valid] is never asserted bare
    upstream: it is reached only through [local_state_is_valid_and_coherent]
    (:181-190), and every call site of that conjoins
    [at_vsts_step(vsts, controller_id, at_step![...])]
    (state_predicates.rs:142/151/162/171/884/891/905/912/921/928 plus the
    resource_match.rs sites). The union of those guards, taken over every site,
    is exactly the FOURTEEN post-partition steps - [GetPVC], [AfterGetPVC],
    [CreatePVC], [AfterCreatePVC], [SkipPVC], [CreateNeeded],
    [AfterCreateNeeded], [UpdateNeeded], [AfterUpdateNeeded], [DeleteCondemned],
    [AfterDeleteCondemned], [DeleteOutdated], [AfterDeleteOutdated], [Done] -
    and [Init], [AfterListPod] and [Error] never appear among them. The port
    conjoins that union as M1's premise, rendered as an EXHAUSTIVE 17-arm match.
    {b Without it M1 would be red for a reason that is not a finding}: [needed]
    is written once, at the [After_list_pod] arm
    (v_stateful_set_reconciler.ml:550-558), so at [Init] and [After_list_pod]
    the decoded [needed] is still [[]] while :194 wants
    [needed.len() == replicas]. This is the same shape of borrowing P23 disclosed
    for its absent-key guard (local_binding.mli:85-92): a narrowing, recorded
    here, not sold as fidelity.

    {b M1 - THE [nat] RENDERING.} Upstream's [needed_index] and [condemned_index]
    are [nat], so :195's and :196's lower bounds are carried by the type. The
    port's fields are [int] (v_stateful_set_reconciler.mli:48, :50), so [>= 0] is
    written out. That is the nat TYPE rendered, not an extra conjunct; a red on
    it would be the port producing a negative cursor, which is exactly the class
    of divergence this register exists to catch.

    {b ==== THE DELETION MEASUREMENT: THIS FAMILY'S EARNED COVERAGE IS FOUR
    SITES OF TWENTY-TWO ==============================================}

    {b THIS IS A FIRST-CLASS RESULT OF THE PHASE, ON THE SAME FOOTING AS THE
    SCOPE EXCLUSION AND THE M2 CUT, AND IT IS WHAT A CONSUMER MUST READ BEFORE
    QUOTING THIS FAMILY AS COVERAGE.}

    {b A FLIP MUTANT AND A DELETION MUTANT TEST DIFFERENT THINGS.} Flipping
    [Option.is_some om.name] to [Option.is_none om.name] reds - but only because
    [name] is [Some] at every object of every ok list-response on all four
    graphs, so the flipped conjunct is FALSE on the whole population and the leg
    reds by FALSIFICATION. That shows the MUTANT is false; it does not show the
    CONJUNCT contributes anything. {b DELETING the conjunct is the honest test of
    contribution}: if every test stays green with the conjunct gone, the conjunct
    has no red capability on these graphs. The M2 candidate below was CUT on
    exactly this reasoning; this block applies it to M1 and M3, which the phase
    had not done.

    {b METHOD.} Each conjunct deleted on its own, [dune build @default], all 82
    test executables run INDIVIDUALLY, restored with the Edit tool, and
    [git diff --stat] confirmed byte-identical to baseline after every row. Where
    plain deletion orphaned a module-level helper and the build died on warning
    32 / 27 - a build error is NOT a measurement - the row was RESHAPED by
    neutralising the conjunct in place as [(<conjunct> || true)], the same
    weakening ([A && (X || true) && B] = [A && B]) with every identifier still
    referenced. Five rows were reshaped: M1 :230-231, :242, :248 and M3 :115,
    :129-130. No assertion was relaxed and nothing was deleted permanently.

    {b THE COUNT IS 16 AND 6 SITES, NOT 14 AND 7.} Those are the counts of
    upstream conjuncts PORTED. M1 renders :195 and :196 as TWO sites each (the
    [>= 0] halves are written out because the port's cursors are [int] where
    upstream's are [nat]), so 14 upstream conjuncts are 16 deletable sites; M3
    renders :129 and :130 as ONE [Option.equal], so 7 upstream conjuncts are 6
    deletable sites. 22 sites in all.

    {b WHICH SITES HAVE RED CAPABILITY - FOUR, plus ONE CLASS.}

    - {b M1 :200-204} (the NEEDED forall). Killed by [t_p24_mutation]'s
      [m1_novel_conjuncts], row [M1b]: the pod named for ordinal 1 sitting in
      needed slot ORDINAL 0.
    - {b M1 :205-214} (the CONDEMNED forall). Killed by the same case, row [M1a]:
      a condemned entry whose ordinal is 0 against :212's [>= replicas] bound.
    - {b M3 :115} (no duplicate object refs). Killed by [t_p24_mutation]'s
      [m3_shape_conjuncts], row [M3a(:115)].
    - {b M3 :129-130} (the namespace). Killed by the same case, row
      [CONTAINMENT(:129-130)] - and that row asserts P23's L2 RED on the SAME
      state, so this kill is SHARED with P23 and is not coverage P24 adds.
    - {b THE CLASS {:126, :127, :132} HAS RED CAPABILITY 1 AND ITS MEMBERS HAVE
      0.} Deleting :126 alone, :127 alone or :132 alone leaves all 82 GREEN;
      deleting all three TOGETHER is killed by [m3_shape_conjuncts]'s
      [M3a(:126-127)] row. This is the mutual entailment stated two bullets above
      in the M3 section, now MEASURED rather than argued: :127 implies :126
      through [Resource_view]'s [Kind_mismatch], and :132 is :127 quantified over
      the same [objs], so no state - forged or reached - separates any member
      from its class.

    {b WHICH DO NOT.} M1 :194, both halves of :195, both halves of :196,
    :230-231, :235, :236, :237, :238, :239, :240, :242 and :248 - fourteen sites,
    all GREEN individually and GREEN when neutralised SIMULTANEOUSLY - and M3
    :128, whose only mutant in the record was the FLIP this block opens with.

    {b SO THE COVERAGE THIS FAMILY EARNS OVER P23 IS THREE CONJUNCT SITES: M1
    :200-204, M1 :205-214 AND M3 :115.} Not fourteen, not twenty-one, not
    twenty-two. Any prose that reads the ported count as a coverage count is
    wrong, and the two places in this interface that did have been corrected
    above.

    {b NOT ONE OF THE 22 DELETIONS WAS CAUGHT BY ANYTHING THE FOUR GRAPHS DRIVE,
    AND THAT IS FORCED, NOT ACCIDENTAL.} All four kills are [t_p24_mutation] rows
    on hand-FORGED states. Deleting a conjunct WEAKENS [holds]; the leg asserts
    [holds] at every reachable state of BL0/BLc/BLd/BLm and is CLEAN on all four;
    and neither member's [interesting] reads its own body ([local_state_valid_witness]
    is [at_valid_step], and M3's is the parked-with-a-matching-response premise).
    A deletion mutant could only be caught by an assertion that some member is RED
    at some reachable state, and this phase has none for a SHIPPED conjunct - the
    two that were red, :116-118 and :119-124, are the SCOPE exclusion.
    {b The four graphs contribute ZERO deletion-kill capability to this register.}
    What they buy is the leg's greenness and the vacuity / refutation pins, which
    is real and is a different thing.

    {b EVERY ONE OF THEM STAYS SHIPPED, AND THE ZEROES ARE THE EXPECTED
    OBSERVATION, NOT A DEFECT.} Fidelity to upstream is why these conjuncts are
    here. A Verus invariant is a predicate the reconciler PRESERVES, so no state
    the reconciler reaches can falsify it - that is what "invariant" means - and
    on a small explored graph family the expected per-conjunct red capability is
    exactly zero. {b This is a statement about what BL0/BLc/BLd/BLm EXERCISE, not
    about the port}, and it is not a licence to remove anything: dropping a
    conjunct upstream writes would make this register a strictly weaker predicate
    than the one its [source] cites, and the citation is the point of the
    register.

    {b WHAT WOULD EXERCISE THE REST - TWO ROUTES, WHICH COST DIFFERENTLY.}

    - {b FORGED-STATE ROUTE - seed-free, moves no pin.} One [t_p24_mutation] row
      per unexercised conjunct on the existing [M1a] / [M1b] pattern: forge a
      decoded {!V_stateful_set_reconciler.s} at a step inside [at_valid_step]
      violating exactly that conjunct ([needed] of length [<> replicas] for :194,
      [needed_index = needed_len] at [Create_needed] for :230-231, a [Some] slot
      at [needed_index] at [Create_needed] for :235, [needed_index = 0] at
      [After_create_needed] for :242, [condemned_index > 0] at [Create_needed]
      for :248), assert M1 RED with the accepted-state control asserted GREEN
      first. Additive to a test file; touches no seed, no bound, no pin. It would
      buy deletion-kill capability for all fourteen unexercised M1 sites and for
      :128. It buys NOTHING for {:126, :127, :132} - only the class is killable.
    - {b GRAPH ROUTE - the only one that could let THESE four graphs carry the
      coverage, and it is a P25 DECISION.} It needs states where the invariant is
      violated by the port's OWN execution, which the reconciler never produces
      because upstream proves it preserves them. That takes a NEW SEED or a NEW
      FAULT DIMENSION - a writer corrupting the ongoing-reconcile local state, or
      the foreign-owned object :112's reject path needs, or the foreign-sourced
      pending request :49 needs - and {b any of those moves BL0/BLc/BLd/BLm and
      every committed P13-P23 pin with them}. A moved pin is a phase-STOP, so it
      is deliberately NOT built here; it rides into P25 on exactly the terms :49
      and :112 already ride on.

    {b ==== THE NEGATIVE RESULT: THE M2 CANDIDATE IS CUT ==================}

    {b THIS IS A FINDING, NOT A DELETION, AND IT IS THE PHASE'S SECOND-LARGEST
    RESULT AFTER THE SCOPE EXCLUSION.} Upstream [req_msg_is_list_pod_req]
    (:45-57) closed over the cluster state by [pending_list_pod_req_in_flight]
    (:59-66) was written as a third member, built, run on all four graphs,
    measured, and mutation-tested with a source mutant that killed. It is CUT,
    and the reason is a measurement: rendered as an INVARIANT over the graphs
    this port explores, {b all seven of its conjuncts are ENTIRELY CONTAINED in
    P23's shipped L2}. It buys NOTHING here. Re-adding it without answering the
    measurement below would re-ship five of L2's conjuncts under a fresh
    [state_predicates.rs:45] citation, which is exactly the double-counted
    coverage the phase gate exists to block.

    {b THE PER-CONJUNCT PARTITION, which is what "contained" means.}

    - {b FIVE ARE LITERALLY L2's.} [:50] ([dst == APIServer]) is
      local_binding.ml:221. [:51] (the content is an [APIRequest]) is the literal
      [false] arms of L2's own [list_req_content_matches],
      local_binding.ml:164-166. [:52] (the request is a [ListRequest]) is
      local_binding.ml:153-155. [:53-56] ([kind: PodKind],
      [namespace: cr_key.namespace]) is local_binding.ml:151-166. [:64]
      ([pending_req_msg_is]) is definitionally discharged by reading the
      [pending_req_msg] slot, which L2's [after_list_pod_ok] (:217-225) already
      does.
    - {b [:65] IS ENTAILED BY THE PORT'S OWN RENDERING PREMISE, AND THE
      ENTAILMENT IS MEASURED, NOT ARGUED.} ([s.in_flight().contains(req_msg)],
      the RAW REQUEST's own network membership.) Upstream's
      [pending_list_pod_req_in_flight] is a liveness MILESTONE, asserted at a
      point in a leads-to chain, not an invariant of every state - asserted of
      every parked state it would be red by construction, because :65 is false
      exactly once the api server has answered. The port therefore narrowed the
      premise to the {b DELIVERY WINDOW}: parked at [AfterListPod], the pending
      slot is [Some], and no matching response is in flight yet (the
      reconcile_correspondence.ml:103-107 disjunct). That narrowing is
      defensible, and it makes :65 a CONSEQUENCE of the premise rather than an
      independent conjunct: with a pending request and no matching response yet,
      the request is necessarily still on the wire - the port already ships the
      invariant that says so
      ([pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg],
      reconcile_correspondence.ml:213).

      {b THE EVIDENCE, ON ALL FOUR GRAPHS.} Stage B counted the raw-in-flight
      population ([Message.Pool.mem rm (Cluster.in_flight s)] over
      parked-with-pending states, [P24_witness.pending_still_in_flight]) at
      {b 8 / 52 / 48 / 744}, and the delivery window
      ([P24_witness.delivery_window]) at {b 8 / 52 / 48 / 744}. {b The two
      populations are EQUAL on every one of BL0/BLc/BLd/BLm}, by two independent
      routes. Identical populations mean there is no reachable state in that
      premise at which :65 is false: no mutation of it could ever be seen red
      here, which is why the M2b' mutant row was STRUCK as unfailable. The
      equality is now {b ASSERTED} rather than recorded, without naming a
      literal, in [t_p24_state_predicates]'s [inherited_population] case - so
      this half of the finding stays a row and cannot decay into a sentence.
    - {b [:49] IS THE ONE CONJUNCT L2 GENUINELY LACKS, AND IT IS UNWITNESSED.}
      ([req_msg.src == Controller(controller_id, vsts_key)].) Its absence from
      L2 is real and was never in doubt: exactly one [.src] occurrence exists
      across local_binding.ml/.mli and it is on the {e response} variable inside
      [ok_list_resps_for] (:193-200); [after_list_pod_ok] (:217-225) checks
      [rm.dst] and the content, never [rm.src]; upstream
      internal_rely_guarantee.rs:640-664, L2's own source, has no [req_msg.src]
      conjunct either. What was at issue is whether the conjunct has EXERCISABLE
      CONTENT here.

      {b IT DOES NOT, AND THE MEASUREMENT IS PINNED.} Probe B4 classifies the
      pending request's [src] over the WHOLE parked-with-pending population -
      denominators {b 16 / 112 / 288 / 1560} on SP0 / SPc / SPd / SPm - by an
      EXHAUSTIVE five-arm match on {!Message.host_id} with the [Controller] arm
      split by the [(id, key)] it carries. The [Controller_this] bucket is the
      whole population; the other five (Controller_other, Api_server,
      Builtin_controller, External, Pod_monkey) are {b 0 on every graph}, and
      the complement is pinned as
      [P24_witness.pending_src_not_controller_everywhere = 0]. Upstream :49 is
      {b TRUE at every state at which it is ever evaluated}: a {b GREEN THAT
      COULD NOT HAVE BEEN RED} - this phase's own defect condition, the same one
      that excluded :241, :246 and the eight PVC conjuncts.

    {b WHY THE M2a' MUTANT DID NOT RESCUE THE MEMBER.} M2a' (swap [.src] for
    [.dst] in the ported :49) WAS run at graph level and DID redden the P24 leg
    (SP0 and SPd moved [OK] -> [FAIL]) while [p23_local_binding] reported "Test
    Successful ... 11 tests run" and [p23_mutation] / [p23_regression] stayed
    green in the SAME run. That is the letter of the ship gate, and it still is
    not evidence. Because the src is [Controller (id, key)] and the dst is
    [Api_server] at EVERY state of the premise population, the swapped conjunct
    is FALSE on the ENTIRE premise, so the leg reds by {b FALSIFICATION} rather
    than by separating any two states. It shows the conjunct is load-bearing FOR
    THE MUTANT; it does not show :49 has content.

    {b THE SHIP GATE WAS UNDERSPECIFIED, AND SAYING SO IS PART OF THE RESULT.}
    RULING §2 wrote: "M2 ships iff at least one of M2a' / M2b' is SEEN RED on
    the P24 leg while the P23 local-binding leg stays GREEN in the same run. If
    neither discriminates, M2 is L2 wearing a hat and is CUT from the phase."
    The gate did not require the mutant to be {b NON-TRIVIALLY} falsifying. That
    is the same class of error as RULING §3.3's vacuity-only gate - a gate that
    asks the wrong question gets a confident answer to it - and the main loop
    has ruled on the gate's spirit rather than letting its letter carry a member
    the measurement rejects.

    {b WHAT WOULD BUY :49, AND WHY IT IS NOT BUILT.} A graph carrying a pending
    request at [AfterListPod] whose [src] is NOT
    [Controller (controller_id, cr_key)] - another controller's request parked
    in this controller's slot, or an [Api_server] / [Pod_monkey] / [External]
    source. {b NO CURRENT SEED PRODUCES ONE}: [Message.controller_req_msg]
    (lib/cluster/message.ml:175-179) is the only constructor the reconcile path
    uses and it always stamps [~src:(Controller (controller_id, cr_key))]. A new
    seed would be needed, and {b adding a seed would move the shared graphs} and
    every committed P13-P23 pin with them, so none is added. :49 is CARRIED TO
    P25 exactly the way upstream :112's unobserved owner-reference reject path
    is (see the M3 section): disclosed, pinned at zero, with the seed that would
    buy it named and deliberately not built. {b NO RED-RATE IS CLAIMED FOR IT
    EITHER WAY}: the "structurally always true, so 100% of parked states"
    reading was refuted as UNMEASURED, and the 0 above is a measurement on
    THESE FOUR GRAPHS - it says :49 has no witness HERE, never that it could not
    have one.

    {b WHAT CAME OUT WITH THE MEMBER, AND WHAT DID NOT.} [req_msg_is_list_pod_req]
    (the :49-:56 rendering), [list_req_content_matches] (its :51-56 half, a copy
    of local_binding.ml:151-166) and [matching_resp_in_flight] (the
    reconcile_correspondence.ml:103-107 copy that supplied the delivery-window
    narrowing) all lost their only consumer in this module and are REMOVED - a
    helper whose last consumer goes away goes with it. The WITNESS-side probes
    do {e not} go: [P24_witness.pending_src_is_controller],
    [pending_src_is_not_controller], [pending_src_occupancy],
    [pending_still_in_flight] and [delivery_window] are this finding's evidence
    and stay ASSERTABLE, which is why {!P24_witness} still measures a population
    no shipped member reads.

    {b M3 - SHIPS ITS SEVEN PURE-SHAPE CONJUNCTS; ITS TWO ETCD-CONSUMING
    CONJUNCTS ARE EXCLUDED-WITH-A-PIN ON A SCOPE GROUND.} RULING §3 partitioned
    [resp_msg_is_ok_list_resp_of_pods] into a pure-shape half and an
    etcd-consuming half and gated the second on a stage-B measurement. That gate
    was answered NON-ZERO, both conjuncts shipped, and they were then REFUTED on
    two of the four graphs. The main loop has ruled on that refutation and this
    is the settled partition:

    - {b SEVEN PURE-SHAPE conjuncts SHIP} - upstream :108-115 and :125-132.
      Rendered as: [:115] no duplicate object refs, [:126] every
      object's [kind] is [PodKind], [:127] every object unmarshals as a [Pod],
      [:128] its [metadata.name] is [Some], [:129] and [:130] its
      [metadata.namespace] is [Some] the CR's, and [:132] [objects_to_pods] is
      [Some]. (:129 and :130 are two upstream conjuncts read together as one
      [Option.equal], the [pod_bound] identity at local_binding.ml:95-100 - one
      rendering, two conjuncts, which is why the count is seven and not six.)
      It is non-vacuous on the already-committed
      ok-list-response population {b 8 / 60 / 48 / 816}
      ([P23_witness.ok_list_resps_*], p23_witness.ml:312-315), with all 8 of
      BL0's carrying a NON-EMPTY [objs] list (:321). {b The POPULATION
      non-vacuity is all that claim may be read as.} An earlier revision of this
      bullet added "and it is killable at GRAPH level - no forged response is
      needed", and the DELETION block below {b REFUTES that for all seven}:
      deleting any one of them leaves all 82 executables GREEN except :115 and
      :129-130, and both of those are killed by FORGED responses in
      [t_p24_mutation], never by anything BL0/BLc/BLd/BLm drive. It could not be
      otherwise - deletion WEAKENS [holds], the leg asserts [holds] everywhere
      and is CLEAN on all four graphs, and M3's [interesting] does not read
      [ok_list_resp_shape] - so no graph-level DELETION mutant of a shipped
      conjunct can redden this leg at all.
    - {b :129-130 is CONTAINED in P23's L2} ([resp_objs_in_namespace],
      local_binding.ml:206-212, upstream :659-661). It is ported for fidelity,
      not claimed as new coverage.
    - {b :126 IS ENTAILED BY :127 AND IS NOT SEPARATELY KILLABLE}, on the same
      terms as :65 above and :113/:114 below. [Pod] is [Resource_view.Make (R)]
      (k8s_objects/views/pod.ml:64) and that functor's [unmarshal]
      (k8s_objects/resource_view.ml:58-68) returns [Err.Kind_mismatch] unless
      [Common.equal_kind dk R.kind], so [Result.is_ok (Pod.unmarshal o)] implies
      the kind equality for EVERY [Dynamic_object.t] - on every graph and on any
      forged state. Deleting :126 would not change this member's truth value
      anywhere, so no DELETION mutant of it can redden and it is not claimed as
      coverage. A token-swap of its [Pod.kind] constant DOES redden (it is a
      STRENGTHENING, and [t_p24_mutation]'s M3a row keeps that observation for
      what it shows: the shape check is reached and evaluated), but that is not
      evidence the conjunct carries anything. {b :132 stands in the same
      relation}: [V_stateful_set_reconciler.objects_to_pods] (:461-463) is
      [Result.is_error (Pod.unmarshal o)] over the same [objs], so :132 and the
      [List.for_all] of :127 are mutually entailing. Both conjuncts stay -
      upstream writes them, fidelity is why they are here - and the count of
      SEVEN is a count of upstream conjuncts PORTED, never of seven independent
      gates.
    - {b :113 and :114 are rendered as the POPULATION FILTER, not as consequent
      conjuncts.} They are carried by [list_resp_objs] inside
      [ok_list_resps_for] (local_binding.ml:174-200's shape). A matched ERROR
      list-response is reachable on the fault graphs - [Cluster.drop_req] forms
      one through [Message.form_matched_err_resp_msg] - and upstream asserts
      [resp_msg_is_ok_list_resp_of_pods] only under the :79-83 EXISTENTIAL,
      never of every matching response, so hoisting :114 into the consequent
      would redden the member on a path upstream makes no claim about. The cost
      of that placement, stated plainly: :113 and :114 are not separately
      killable in this member.
    - {b The two ETCD-CONSUMING conjuncts are EXCLUDED-WITH-A-PIN on the SCOPE
      ground}: :116-118 (the [owned_objs] / [s.resources()] object-ref set
      equality) and :119-124 (the forall whose body is :122 key-presence and
      :123 [weakly_eq]). They were not skipped. The gate RULING §3.3 set was one
      stage-B measurement - is [owned_objs], i.e. [resp_objs] filtered by
      [Object_meta.owner_references_contains (V_stateful_set.controller_owner_ref
      cr)], ever non-empty on the 8/60/48/816 population? {b MEASURED NON-EMPTY:
      8 / 60 / 40 / 776} (probe B3) - so both conjuncts SHIPPED, [weakly_eq] was
      WRITTEN, and the leg was then REFUTED on two graphs. The exclusion is the
      main loop's ruling on that refutation and the next three bullets are its
      whole substance: the GROUND, the PINNED EVIDENCE, and what came out with
      them.
    - {b THE OWNER-REF FILTER IS NEVER SEEN TO REJECT ANYTHING, AND THAT IS A
      FINDING, NOT A FOOTNOTE.} An earlier revision of this paragraph reported an
      "unowned-only complement of 0 / 0 / 8 / 40" and it was wrong twice over.
      That probe was defined as [population && not owned], so it could not
      distinguish "the filter rejected every object" from "there was nothing to
      filter" - and 0 / 0 / 8 / 40 is in fact the SECOND of those, exactly
      [ok_resps - with_objs], the states whose matching responses carry an EMPTY
      [objs] list. Re-measured on its own route the population splits THREE ways
      over 8 / 60 / 48 / 816: owned {b 8 / 60 / 40 / 776}, every-object-unowned
      {b 0 / 0 / 0 / 0}, no-objects-at-all {b 0 / 0 / 8 / 40}. And the reject
      path proper - some object of some matching ok response FAILING
      [Object_meta.owner_references_contains] - measures {b 0 / 0 / 0 / 0} and is
      PINNED at zero ([P24_witness.ok_resp_some_unowned_obj_everywhere]). So
      upstream :112's filter is only ever observed ACCEPTING on these four
      graphs; its rejecting direction has no witness here and no mutation of it
      could be seen red. That is disclosed rather than papered over, and it is
      carried into P25 with the rest of §3.3(4): a seed that plants a
      foreign-owned object is what would buy the missing direction.
    - {b THE SCOPE GROUND, stated so a consumer can check it rather than take
      it.} Upstream state_predicates.rs:116 carries this comment, quoted in
      full and verbatim, immediately above the set equality:

      {v // coherence with etcd which preserves across steps taken by other
   // controllers satisfying rely conditions v}

      and :111, one line above the [owned_objs] binding both conjuncts
      quantify over, reads {v // these objects can be guarded by rely conditions v}

      So upstream does not assert this coherence unconditionally: it asserts it
      of an execution in which the OTHER writers satisfy rely conditions.
      {b This port has no rely-condition machinery} - a fact about the port,
      stated as one. {!Rely_conditions} carries the P12 rely/guarantee
      correspondence members and nothing in [lib/] constrains which writers may
      touch a CR-owned object between a list response being formed and being
      observed; there is no predicate a writer could be required to satisfy.
      And {b the BLc and BLm graphs inject, by construction, exactly the
      rely-violating writers the assumption excludes} - a crash-orphaned request
      applied late, and the pod monkey. That is what those budget dimensions are
      FOR. Asserting these two conjuncts over those graphs therefore asserts
      upstream's predicate {b outside its stated scope}. Relaxing the leg
      assertion, or narrowing M3's premise until the failures fell outside it,
      would each be the retune this project forbids;
      EXCLUSION-WITH-A-PIN is the established mechanism and is what is applied.
    - {b THE PIN IS A MEASURED REFUTATION WITH ATTRIBUTION, AND EVERY NUMBER IS
      ASSERTED.} This is what makes it stronger than the phase's other nine:
      those record a vacuity, this records conjuncts that were RENDERED, RUN
      over all four graphs and SEEN RED at named states. Probe B5 stays LIVE in
      [P24_witness] after the conjuncts are gone, because it is now the pin's
      evidence, and [t_p24_state_predicates]'s [scope_exclusion_pin] case
      asserts all of it on SP0 / SPc / SPd / SPm:

      - :116-118 SET-EQUALITY failures {b 0 / 8 / 0 / 72}, with the two
        containment DIRECTIONS measured on separate traversals and pinned
        separately: "etcd holds a valid-owned object the response does not"
        {b 0 / 4 / 0 / 32} and "the response holds an owned object etcd no
        longer has" {b 0 / 4 / 0 / 40}. The two directions are asserted DISJOINT
        (they sum to the failure count), so neither literal leans on the other.
      - :119-124 COHERENCE failures {b 0 / 4 / 0 / 40}, and the :122
        key-presence half measured on its own route at the same
        {b 0 / 4 / 0 / 40}. The two columns being EQUAL is the sharp form of
        "every coherence failure is :122": the response names an owned object
        whose key has since left etcd, and the :123 [weakly_eq] half contributes
        nothing at all.
      - {b [weakly_eq]'s OWN comparison disagreements: 0 metadata, 0 kind and
        0 spec on EVERY graph.} THIS IS THE LOAD-BEARING FACT and it is pinned,
        not narrated: it is what makes the diagnosis {e "the in-flight response
        is STALE relative to etcd"} rather than {e "[weakly_eq] is wrong"}. Its
        POSITIVE CONTROL is asserted immediately before it - some owned response
        object really was looked up in etcd and FOUND, at 8 / 60 / 40 / 736
        states - so the three zeroes are measured agreements and not an
        unexplored region.
      - {b MULTI-MATCHING-RESPONSE states 0 everywhere}, read off a three-column
        histogram ("0", "1", "2+") whose columns SUM to the parked-with-pending
        population and whose "1" column IS the 8 / 60 / 48 / 816 premise
        population. This rules out a universal-versus-existential artifact: no
        premise state carries two matching ok list-responses that could
        disagree about staleness.
      - {b AND THE ATTRIBUTION, measured before the conjuncts came out}: with
        them still shipped, M3's per-state RED count on the replica was
        {b 0 / 8 / 0 / 72} - EQUAL, graph by graph, to the union of the two
        failure columns. The member's red set was EXACTLY the set probe B5
        selects, so the exclusion removes those states and nothing else. That
        identity is no longer assertable (M3 is green everywhere now), which is
        why both halves are PRINTED side by side in the B5 dump: the shipped
        column must read 0 and the refutation column the pinned 0 / 8 / 0 / 72.
    - {b [weakly_eq] WAS PORTED, WAS MUTATION-KILLED ON ITS METADATA ARM, AND IS
      REMOVED AS A CONSEQUENCE OF THE SCOPE EXCLUSION - NOT OF ANY DEFECT IN
      IT.} Recorded here so P25 can restore it in four lines. It was a port of
      predicate.rs:26-30 whose every ingredient is already exported
      ([Dynamic_object.metadata]/[.kind]/[.spec] dynamic_object.mli:20/17/23,
      [Object_meta.without_resource_version] :76, [Object_meta.equal] :109,
      [Common.equal_kind] common.mli:48, [Value.equal] value.mli:23;
      [Dynamic_object.equal] dynamic_object.mli:51 is {b not} a shortcut - it
      also compares [status] and does not exclude [resource_version], exactly
      the two fields upstream's comment at predicate.rs:25 says the relation
      must tolerate). Stage C tautologised each arm in turn: the METADATA arm
      was {b SEEN RED}, killed at state level by t_p24_mutation's M3d row; the
      KIND arm was incidentally covered by the :126 shape row; the {b SPEC arm
      SURVIVED}, a recorded TEST GAP whose cause is now itself MEASURED
      ([P24_witness.weakly_eq_spec_disagreements_everywhere = 0] over a
      non-zero comparison population - no shipped graph reaches a state where a
      listed object's spec disagrees with etcd's copy). {b AND ONE MORE GAP,
      found while mutation-confirming the B5 probes and disclosed rather than
      omitted}: dropping [Object_meta.without_resource_version] from the
      metadata arm - comparing raw metadata, resource version included -
      SURVIVED, the column staying 0 on all four graphs. On these graphs an
      in-flight response object whose key is still in etcd matches etcd's copy
      EXACTLY, so upstream's resource-version TOLERANCE has no witness here and
      nothing distinguishes [weakly_eq]'s metadata arm from raw
      [Object_meta.equal]. A restorer must not read that arm as confirmed in
      that direction. [owned_objs] (:112),
      [valid_owned_object] (predicate.rs:44-52), [etcd_valid_owned_refs] and
      [ref_set_equal] came out with it, all for the same reason: their last
      consumer went away, and a helper whose last consumer goes away goes with
      it. The M3c and M3d state-level mutation rows went too, and
      t_p24_mutation records where and why.
    - {b :256 [local_state_is_coherent_with_etcd] IS EXCLUDED-WITH-A-PIN ON
      THE SAME SCOPE GROUND AS :116-124, MEASURED THIS PHASE RATHER THAN
      ARGUED. THIS SUPERSEDES THE FORWARD POINTER PREVIOUSLY HERE.} P25 did
      not render :256's 114-line conjunct family; it measured whether
      upstream's own etcd-coherence scoping (the same rely-condition gap that
      excluded :116-124) already forecloses it, and the answer is yes.
    - {b THE SCOPE GROUND, RESTATED FOR :256's OWN UPSTREAM TEXT.} Upstream
      state_predicates.rs:252-255 carries this comment immediately above the
      [pub open spec fn], quoted in full:

      {v // coherence between local state and etcd state
      // Note: there are many exceptions when the object is just updated or the index
      // haven't been incremented yet
      // message predicates for each exceptional states carry the necessary information
      // to repair the coherence v}

      Upstream does not assert this coherence unconditionally either: it
      depends on MESSAGE-CARRIED repair information supplied by
      exception-tracking machinery this port does not have - the identical
      gap :569-585 already names for :116-124 ({b this port has no
      rely-condition machinery}). :256 is not a new scope question; it is the
      same one at larger scale.
    - {b THE MEASUREMENT: EVERY PINNED FAILURE IS CLASS (d) - NO WRITE OF ANY
      KIND IN FLIGHT.} [t_p25_probe_coherence] (probe-coherence-run.log)
      reproduces the pinned SET-EQUALITY and COHERENCE fail populations
      EXACTLY as a positive control (0/8/0/72 and 0/4/0/40 on
      SP0/SPc/SPd/SPm) before classifying each fail state into four buckets:
      (a) a rely-violating pod-monkey write in flight, (b) a monkey write
      satisfying R1/R2, (c) a controller-sourced write with no monkey write,
      (d) no write in flight at all. SET-EQUALITY: SPc {b 8/8} class (d),
      SPm {b 72/72} class (d). COHERENCE: SPc {b 4/4} class (d), SPm
      {b 40/40} class (d). {b a=b=c=0 on every graph, every conjunct.} 100%
      of the pinned failure population is class (d).
    - {b THE OVER-EXCLUSION COMPLEMENT: A RELY-GUARD WOULD BE WRONG IN BOTH
      DIRECTIONS.} {b 144} SPm states carrying a rely-violating write in
      flight PASS the etcd-coherence checks anyway. A guard built to exclude
      "rely-violating write in flight" states would therefore wrongly exclude
      144 states needing no exclusion, while doing nothing for the 124 (80
      set-eq + 44 coherence) class-(d) failures, which have no write in
      flight to key off of. The effective premise of such a rely-scoped
      restoration is {b 8/60/48/672} (SPm's 816-state premise minus the 144
      complement) - and the class-(d) failures sit INSIDE that narrowed
      premise, not outside it, so scoping the restore to "no rely-violating
      write in flight" rescues none of them.
    - {b THE STRUCTURAL GROUND: AN IN-FLIGHT GUARD CANNOT SEE AN
      ALREADY-CONSUMED WRITE.} Every class-(d) failure is, by construction of
      the classification, a state with NO write of any kind outstanding: the
      divergence is not a writer currently violating rely conditions, it is a
      write - most plausibly a Delete, upstream's own rely-exempt request
      kind (rely_guarantee.rs:26, "Deletion/UpdateStatus requests are
      allowed"; ported at rely_conditions.ml:224-227/242-246) - that already
      LANDED and was CONSUMED before the observation state, the identical
      signature P24 attributed to :119-124's failures (mli:610-613, "the
      response names an owned object whose key has since left etcd"). No
      predicate evaluated AT the observation state, rely-scoped or not, can
      see a write that is no longer in flight; the missing information is
      exactly what upstream's :253-255 comment says is carried by message
      predicates this port does not implement.
    - {b :256 IS THEREFORE EXCLUDED-WITH-A-PIN ON THE SCOPE GROUND - THE
      THIRD MEMBER OF THAT GROUP, alongside :116-118 and :119-124.} It does
      not ship as a conjunct or a family this phase;
      [weakly_eq]/[pod_spec_weakly_eq]-class comparison (rs:292) stays OUT
      for the same reason mli:636-666 already gives. The REACHABILITY ground
      (:241, :246) and the SHAPE ground (the other seven M1 PVC-family
      conjuncts) are UNAFFECTED and UNCHANGED by this entry - :256 is a
      distinct upstream member, not a re-partition of M1.
    - {b THE PIN, in the wording a consumer may quote:} [P25_witness]'s
      coherence-classification probe, run over SP0/SPc/SPd/SPm, asserts:
      set-eq class-d 0/8/0/72, coherence class-d 0/4/0/40, a=b=c=0
      everywhere, over-exclusion complement 0/0/0/144, effective premise
      8/60/48/672. Literals live in test/p25_witness.ml; a
      scope_exclusion_pin_256 Alcotest case in the P25 state-predicates test
      file asserts all of it, mirroring t_p24_state_predicates.ml's
      scope_exclusion_pin case exactly.

    {b M3 - THE OWNER REFERENCE IS AN [option] WHERE UPSTREAM'S IS TOTAL, AND
    THE FAMILY NO LONGER READS IT.} [V_stateful_set.controller_owner_ref]
    (v_stateful_set.mli:42) returns [Owner_reference.t option]. It was read once
    per family instantiation, for upstream :112's [owned_objs] filter and the
    etcd side of :116-118; with both conjuncts EXCLUDED it has no consumer in
    this module and the [~owner_ref] parameter is gone rather than carried
    unused. It is still read by {!P24_witness}'s probes, where the [Option] is
    folded to [false] and [t_p24_state_predicates] asserts [Option.is_some] on
    it as a POSITIVE CONTROL before any owned count: a [None] would empty every
    filter and turn the whole pinned refutation into a vacuous zero, which is
    this project's named failure mode.

    {b M3 - THE SET EQUALITY WAS COMPARED AS A SET, NEVER BY LENGTH.} Recorded
    because the rendering decision travels with the conjunct if P25 restores it.
    Upstream :117-118 equates two Verus [Set]s of [ObjectRef]. The port compared
    two [Common.object_ref list]s by MUTUAL CONTAINMENT over
    [Common.equal_object_ref] (common.mli:61) - not by length, because two
    equal-length lists can disagree and a Verus set is duplicate-free where a
    list is not. The etcd side was read through [Object_ref_map.bindings], the
    deterministic domain enumeration {!Object_ref_map} documents as the stand-in
    for Anvil's [Map] iteration, taking each VALUE's own [object_ref] and not
    the map key, because that is what upstream's [.values().map(...)] does.
    {!P24_witness}'s B5 probes carry that rendering forward unchanged, which is
    what makes the pinned numbers numbers about upstream's conjunct.

    {b PLUMBING.} [local_binding.mli] exports its two vals and nothing else, and
    [reconcile_correspondence.mli] its six members and its [family], so every
    helper this family borrows from them is DUPLICATED with its origin cited -
    the house precedent stated in-tree at internal_guarantee.ml:131-136. The one
    new export this phase takes is
    [V_stateful_set_reconciler.objects_to_pods] (RULING §3.2), a pure-visibility
    change on live production logic with zero existing VSTS copies;
    [pod_filter] is {b not} exported, because it belongs to the un-selected
    [resp_msg_is_pending_list_pod_resp_in_flight_with_n_condemned_pods] (:87-104).
    Neither helper may ever be mutated in place by the mutation matrix: both are
    called from the reconcile path in the same file
    (v_stateful_set_reconciler.ml:537 and :544), so mutating the shared
    implementation would alter reachability and hence committed pins. Mutants go
    in this family only.

    {b House rules.} Every [holds]/[interesting] is total, pure and
    exception-free: no [raise], no [failwith], no partial accessor, no two-arm
    option/result match ([Option.fold] / [Result.fold] only), and NO INDEXING -
    upstream's [state.needed[needed_index]] and [state.needed[needed_index - 1]]
    at :235-:238 are eliminated by pairing each slot with its ordinal
    ([List.mapi]) and selecting with [List.find_opt], with the
    out-of-range case folded to [true] as out of premise, and there is no
    [List.nth], no [arr.(i)] and no guarded raw-index wrapper. Every match on a
    finite sum is exhaustive - the seventeen reconcile steps (four separate
    17-arm matches, one per [locally_at_step_or!] group plus the premise), the
    nine [Api_method.api_request] and nine [Api_method.api_response]
    constructors and the four [Message.message_content] constructors are all
    spelled out, no wildcard arms. Each [locally_at_step_or!] is a match and
    never a [List.mem] over a literal step list, which would silently omit a
    newly-added step instead of forcing a revisit. *)

val predicate_sources : string list
(** The two upstream [source] strings, in member order M1, M3
    ([".../liveness/state_predicates.rs:192"]; [":107"]) - exposed so the P24
    regression can assert the family's rendered sources agree with this list in
    member order, without restating them.

    {b [":45"] IS ABSENT AND ITS ABSENCE IS ASSERTED.} The M2 candidate is CUT
    (the NEGATIVE RESULT section of the module doc above), and a cut member must
    not survive in the ONE list every roster sweep reads as its input.
    [t_p24_regression] therefore carries the cut citation as a committed literal
    for the sole purpose of checking it is {e not} here, so that a copy-forward
    cannot quietly restore the member.

    {b BOTH ARE BARE, AND THAT IS LOAD-BEARING AND SILENT WHEN VIOLATED.}
    No parenthetical qualifier, ever - not [":192 (15 of 23 conjuncts)"], not
    the [vsts_invariants.ml:217] style, nothing.
    [t_p21_regression.ml:479-483] extracts the line number with
    [String.rindex_opt s ':'] fed to [int_of_string_opt]; a qualifier makes that
    return [None], the member silently DROPS OUT of the roster, {b and the
    firewall pin still PASSES while the member is invisible}. That is a
    vacuously-green pin, this project's named failure mode. The two in-tree P23
    members at local_binding.ml:297-298 and the four P21 members at
    internal_guarantee.ml:377/:396/:416/:436 carry exactly this bare shape.
    Per-conjunct partition detail belongs in the module doc above, never in a
    source string. *)

val predicate_family :
  cr:V_stateful_set.t -> controller_id:int -> Invariants.invariant list
(** The M1/M3 records, in that order (expected cardinal 2; pinned by the P24
    regression, not asserted here - no-exception house rule). The signature
    mirrors {!Local_binding.binding_family},
    {!Internal_guarantee.guarantee_family} and
    {!Helper_invariants.helper_family}, and BOTH arguments are genuinely
    consumed: [~cr] supplies the [cr_key] whose [name] and [namespace] every
    member reads and the [replicas] bound :194 and :212 compare against;
    [~controller_id] selects the [ongoing_reconciles] map the lookup goes
    through.

    {b [~controller_id] LOST ITS SECOND CONSUMER WITH THE CUT MEMBER, AND THAT
    IS WORTH KNOWING BEFORE WIRING A MUTANT AT IT.} The CUT candidate's :49
    conjunct read [~controller_id] again, inside [holds], to require the parked
    request's [src] to be [Controller (controller_id, cr_key)]; nothing in the
    shipped family does that any more. So a wrong [~controller_id] now only
    SILENCES this family (every state falls out of premise) where it used to
    also RED one member. [t_p24_mutation]'s MP5 row still asserts both columns
    for that reason - see its comment.

    {b THREE of [~cr]'s stage-A consumers are gone, each with its ruling.}
    :241's [get_largest_unmatched_pods] went when :241 was EXCLUDED on the
    REACHABILITY ground, so [local_state_is_valid] no longer takes the CR at
    all; [controller_owner_ref] - which instantiated M3's :112 [owned_objs]
    filter and the etcd side of its :116-118 set equality - went when those two
    conjuncts were EXCLUDED on the SCOPE ground; and the [namespace] reading
    that fed the CUT member's :53-56 went with the member. [~cr] is still
    genuinely consumed through the [cr_key], the [namespace] M3's :129-130
    compares against, and the [replicas] above; what it no longer supplies is
    any etcd-side or request-side reading.

    Each member's [interesting] is its OWN premise mirror (P14 N3 - no
    borrowing), and neither of them is "the decode succeeded":

    - {b M1} fires when the reconcile at [cr_key] exists, decodes, and its step
      is one of the fourteen at which upstream ever asserts
      [local_state_is_valid] - upstream's own [at_vsts_step] conjunct, not a
      bare decode. Counting a bare decode success would let a decode-DEFAULT
      register as assurance, the [inv16] ground reused at
      local_binding.ml:137-141.
    - {b M3} fires when the step IS [AfterListPod], the pending slot IS [Some],
      and at least one matching ok [List_response] is in flight - the premise
      P23 already measured at {b 8 / 60 / 48 / 816}
      ([P23_witness.ok_list_resps_*]), re-measured identically by this phase's
      probe B3.

    {b THE DELIVERY WINDOW IS NO LONGER ANY MEMBER'S PREMISE, AND IT IS STILL
    MEASURED.} It was the CUT candidate's [interesting] (parked at
    [AfterListPod], pending [Some], no matching response yet), measured at
    {b 8 / 52 / 48 / 744}. {!P24_witness} keeps it as [delivery_window] because
    its EQUALITY with the raw-in-flight population is what makes upstream :65
    entailed, and that equality is asserted on every graph by
    [t_p24_state_predicates]. Nothing in this module reads it.

    {b Premise wiring.} [Cluster.ongoing_reconciles] is TOTAL - a missing
    controller id yields the empty map (cluster.mli:78-82) - so instantiating
    this family at the wrong [~controller_id] sends every state out of premise:
    both members' [interesting] go to 0 and both stay green. That is the shape
    of the standard premise-wiring mutant, and it is why a non-zero per-member
    [interesting] is the only evidence that the family was wired to the leg's
    controller at all.

    {b Attribution.} [Invariants.first_violated] (invariants.ml:1046) is
    FIRST-IN-LIST-ORDER and the leg's [~violated] resolves through it
    (fault_check.ml:249-258). M1 and M3 have disjoint premises in the step
    dimension (M1 is silent at [AfterListPod]; M3 fires only there), so a single
    leg-level [violated] name happens to be unambiguous today. {b That is a
    property of the current partition, not of the mechanism}, and it was NOT
    true while the CUT candidate shared M3's premise and sat ahead of it in list
    order - any conjunct they both saw would have resolved to the candidate and
    left M3 looking green. Per-member attribution therefore still comes from
    per-member red / [interesting] counts on a REPLICA (the
    t_p21_guarantee.ml:193-237 technique), NOT from the leg's [violated] name.
    *)

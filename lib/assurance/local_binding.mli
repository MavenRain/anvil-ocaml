(** P23 VSTS controller-LOCAL binding register (BUILD-SPEC-P23 §2): the two
    members of [vstatefulset_controller/proof/internal_rely_guarantee.rs] that
    constrain what the reconciler is holding in its OWN local state, as opposed
    to what it has put on the wire.

    P21 ({!Internal_guarantee}) shipped the four WIRE members of that file - what
    the VSTS controller guarantees about the requests it emits. This family is
    the other axis of the same file: the pods the reconcile round has decoded
    into [needed] and [condemned] are bound to the CR whose key the round is
    running under, and (L2) the round parked at [AfterListPod] really is parked
    on a pod-list request in the CR's namespace.

    {b NOVELTY, in its exact MEASURED wording, and it is MEMBER-level not
    FILE-level.} The member probe
    [rg -n 'source = "[^"]*internal_rely_guarantee.rs:(606|613|640)' lib test]
    returned ZERO hits (exit 1) before this module, so these are {b the first
    shipped members sourced to the CONTROLLER-LOCAL binding functions :613 and
    :640}. The companion FILE probe
    [rg -n 'source = "[^"]*internal_rely_guarantee' lib test] returns FOUR hits
    (internal_guarantee.ml:377/:396/:416/:436), so it is {b NOT} claimed - and
    must never be written - that these are the first members from that file.
    P21 could truthfully make the file-level claim; P23 cannot.

    {b WHAT A RED MEANS HERE.} Upstream DISCHARGES both members as cluster
    invariants ([lemma_local_pods_and_pvcs_are_bound_to_vsts_with_key_preserves_...],
    internal_rely_guarantee.rs:668). So the P21 epistemic reading carries over
    unchanged: a red is NOT "the environment misbehaved" but a {b FIDELITY
    DIVERGENCE in the port} - the port's own reconciler decoded, or parked on, a
    local state upstream proves it never holds - and it is a real finding.

    {b E-LEDGER RE-PARTITION} (BUILD-SPEC-P23 §2.2). The file has exactly NINE
    [pub open spec fn]. P21's partition was 4 shipped + 5 excluded; after this
    phase it is 6 shipped + 3 excluded, still total and disjoint:
    G4 :544, G1 :562, G2 :581, G3 :589 (P21), L1 :613 and L2 :640 (here), with
    E1 :522, E2 :528 and E3 :606 excluded. This re-partition is PRE-AUTHORIZED -
    BUILD-SPEC-P22.md:279-281 records that [t_p21_regression]'s ledger clause
    "reds only if P23 ships E3-E5, deliberately".

    {b Why E3 :606 stays excluded.} E3 is the LIFT of E5 over every VSTS-kind key
    in [ongoing_reconciles] (:608-609, one conjunct, six-line body). Every
    shipped scenario is single-CR (scenario.ml:249-253), so the map holds at most
    the one VSTS key and E3 collapses to L2-at-the-scenario-key, or is vacuously
    true. That is "L2 wearing a hat" - the exact ground P21 used for its own E1
    (BUILD-SPEC-P21.md:132). A two-CR spine de-vacuizes it; that is a later
    phase.

    {b L1} [local_pods_and_pvcs_are_bound_to_vsts_with_key_in_local_state]
    (:613-638), a pure [(cr_key, local_state) -> bool] upstream. Ported at the
    scenario CR key ONLY: look the reconcile up, decode, then TWO of upstream's
    three foralls.

    - {b C1, the needed forall} (:617-622). Upstream quantifies over indices with
      an [is Some] guard; the port has [needed : Pod.t option list]
      (v_stateful_set_reconciler.mli:47), so the index is eliminated by
      [List.for_all] and {b the [is Some] guard IS the [~none:true]}. Body: the
      pod's [metadata.name] is [Some] and inverts through [get_ordinal], and its
      [metadata.namespace] is [Some cr_key.namespace].
    - {b C2, the condemned forall} (:623-628). The same three sub-conjuncts with
      {b NO [Some] guard} - upstream :624 reads [condemned_pods[i]] directly -
      and the port's [condemned : Pod.t list] (mli:49) has no option layer, so
      the two agree without a fold.
    - {b [pod_name_match]} (proof/predicate.rs:146-148) is rendered by INVERSION
      through the reconciler's own [get_ordinal] (v_stateful_set_reconciler.mli:98),
      reusing P18/P21's decision verbatim (internal_guarantee.ml:113-121) rather
      than re-litigating it.

    {b L2} [local_pods_and_pvcs_are_bound_to_vsts_with_key] (:640-664): the same
    lookup/decode skeleton, then E5's two conjuncts - (a) :642, L1's body at the
    decoded state, and (b) :643-663, the [AfterListPod] implication rendered as
    an EXHAUSTIVE 17-arm match on [V_stateful_set_reconciler.step]
    (mli:14-33), the [inv16] shape (invariants.ml:1009-1015), no wildcard. The
    [AfterListPod] block requires a pending request ([~none:false] {b IS}
    upstream :645 [pending_req_msg is Some]) addressed to the api server (:646)
    whose content is [ListRequest { kind: PodKind, namespace: cr_key.namespace }]
    (:647-651), and requires every matching ok list-response in flight
    (:652-657) to carry only objects in the CR's namespace (:659-661, and ONLY
    that conjunct - [inv16]'s extra owner-ref conjunct at invariants.ml:978-980
    is deliberately NOT copied, because upstream :660-661 carries one).

    {b RENDERING NARROWINGS - disclosed, and NOT sold as fidelity.} The repo's
    recurring overclaim class is recorded at BUILD-SPEC-P22.md:113-119; the
    precedent for disclosing a narrowing in the rendering is
    internal_guarantee.mli:53-61.

    - {b THE ABSENT-KEY GUARD IS BORROWED FROM E3.} E4 is a pure function of
      [(cr_key, local_state)] with no guard of its own, and E5's own body indexes
      a Verus TOTAL map unguarded (:641
      [s.ongoing_reconciles(controller_id)[cr_key].local_state]). The port has no
      total map, so BOTH members fold the absent-key case to [true] - which is
      E3's :608 premise [contains_key(k) && k.kind == VStatefulSetView::kind()],
      restricted to the ONE scenario key. The source strings stay bare :613 and
      :640; this sentence is where the borrowing is recorded.
    - {b THE DECODE-FAILURE ARM.} Verus reads [unmarshal(...)->Ok_0], which on a
      non-[Ok] is an UNCONSTRAINED total-map value. The port folds a decode error
      to [true] in [holds] and [false] in [interesting] - the house
      out-of-premise rule already stated at internal_guarantee.ml:53-55.
    - {b OK-RESPONSE NARROWING.} Upstream :657 [is_ok_resp(msg.content->APIResponse_0)]
      is rendered as "the content is a [List_response] whose [res] is [Ok]"
      (invariants.ml:348-360's shape). That is NARROWER than upstream's generic
      ok-ness. It is sound only because :656 [resp_msg_matches_req_msg] has
      already pinned the response to the list request; it is not a verbatim port.
    - {b CR-KEY RENDERING.} [cr_key] is built from the same [->0] reading P21
      uses (internal_guarantee.ml:75-98): [V_stateful_set.object_ref] is
      [Res.t]-typed hence partial, and a total classifier must not consume it,
      so [metadata.name]/[namespace] fold to [""] when absent. On the shipped
      scenarios both are [Some], so the renderings coincide.

    {b EXCLUDED WITH A PIN: the pvcs forall :629-637.} Its six sub-conjuncts
    ([name is Some], [pvc_name_match], [generate_name is None], [namespace ==
    Some(cr_key.namespace)], [owner_references is None], [finalizers is None])
    CANNOT FIRE on any P23 graph. The only writers of [state.pvcs] are
    v_stateful_set_reconciler.ml:509 and :553, both through [make_pvcs]
    (:292-296), which is [Option.value ~default:[] sp.volume_claim_templates]
    mapped and filtered - hence [[]] whenever [volume_claim_templates] is [None],
    which is exactly [vct:false] (scenario.ml:240-241), the only shape the P23
    legs seed. The exclusion is made behavior-free by an in-test assertion, over
    EVERY P23 graph, that every decoded ongoing state has [pvcs = []]; the moment
    a [vct:true] leg lands, that pin reddens. Porting the conjunct instead would
    add a THIRD copy of [pvc_name_matches] (internal_guarantee.ml:137-152 is
    already a deliberate duplicate of helper_invariants.ml:32-43) for six
    sub-conjuncts that cannot fire.

    {b PREDICTED VACUITY OF C1, MEASURED AND {e REFUTED} (BUILD-SPEC-P23 §4
    prediction 5, refuted in §8.3).} The phase committed, before measuring, that
    C1 would be VACUOUS on the shipped instantiation: [needed] is written ONCE,
    at the [After_list_pod] arm (v_stateful_set_reconciler.ml:550-558, from
    [partition_pods]), and [Create_needed] only advances [needed_index]
    (:641-658) without writing the created pod back, so with
    [~desired:1 ~ordinals:[1]] the single needed slot looked [None] forever and
    :617's [is Some] guard false at every state. {b Those cites are accurate and
    the INFERENCE from them is wrong.} The port RE-RECONCILES: pod-0 is created
    in one round, and a LATER round re-lists the pods and [partition_pods] puts
    the now-existing pod-0 into the needed slot as [Some]. C1's forall is
    therefore NOT empty - MEASURED needed-witness states
    {b 20 / 200 / 208 / 3616} on BL0/BLc/BLd/BLm ([P23_witness.needed_witness_*]),
    every one of BL0's 20 with pod-0 in etcd and none without, which is that
    mechanism and no other. {b The needed conjunct SHIPS as written: no
    exclusion, no pin, no de-vacuizer.} The fall-back decision rule this block
    used to carry (EXCLUDE-WITH-A-PIN with an all-[None] assertion) is STRUCK,
    not deferred: its precondition never existed. A consumer must NOT apply it to
    C1. The [~desired:1 ~ordinals:[0;1]] de-vacuizer was measured anyway rather
    than dropped unmeasured (BN0, §8.4: fixpoint at depth 25, 88 states, gate 68,
    needed slot [Some] in 52 states, CLEAN, reds 0) and is NOT shipped as a leg,
    because it fixes a non-problem. It remains true, and still disclosed, that
    that instantiation falls OUTSIDE the shipped seed-integrity predicate
    (scenario.ml:495-517 requires every requested ordinal be [>= replicas], which
    ordinal 0 is not), so any future use of it needs its own integrity check
    rather than a reuse; §8.4 records the one that was written for BN0.

    {b L2's INNER FORALL (:652-662): its PREMISE IS LIVE} (BUILD-SPEC-P23 §4
    prediction 6, CONFIRMED in §8.5). It fires only in states where an ok
    [List_response] matching the pending request is still in flight while the
    reconcile is parked at [After_list_pod]. That premise is MEASURED non-zero on
    EVERY shipped graph: {b 8 / 60 / 48 / 816} ([P23_witness.ok_list_resps_*]),
    and on BL0 all 8 of those states carry a matching ok [List_response] with a
    NON-EMPTY [objs] list, so :659-661 is applied to real objects rather than
    folding over nothing. The conjunct is DISCLOSED, not pulled; the "pull it
    with the count as its pin" alternative does not apply. {b What is still NOT
    claimed:} the inner forall's CONSEQUENT has never been SEEN red on a shipped
    graph - no member is red anywhere - so its red capability rests on a
    dedicated row in [t_p23_mutation], and NO red count is asserted for it here.

    {b CONTAINMENT, and its ATTRIBUTION CONSEQUENCE.} :642 calls E4, so L2's
    [holds] STRICTLY IMPLIES L1's. The containment is DELIBERATE and has house
    precedent: P21 shipped G4 knowing it is strictly stronger than
    [G1 && G2 && G3] and made the overlap the design point
    (BUILD-SPEC-P21.md:108-126). Shipping E5 alone would put E4's text inside a
    member cited :640 while :613 stayed ledgered EXCLUDED - a FALSE ledger.
    {b The consequence: [Invariants.first_violated] (invariants.ml:1046) is
    FIRST-IN-LIST-ORDER, and the leg's [~violated] resolves through it
    (fault_check.ml:249-258), so for ANY shared-conjunct failure L1 is the member
    named and L2 looks green.} Per-member attribution therefore requires
    per-member red/[interesting] counts from a REPLICA (the
    t_p21_guarantee.ml:193-237 technique), NOT the leg's [violated] name.

    {b EARNS-ITS-KEEP, phrased narrowly on purpose (BUILD-SPEC-P23 §7).} "The new
    register catches what P21 misses" is FALSE for L1: the mutant that reds L1
    also reds G2, because upstream :584
    [pod_name_match(req.key().name, vsts.metadata.name->0)] is a G2 conjunct too.
    The claim survives for {b L2's list-request conjunct ONLY} - G4's read-only
    arm is [ListRequest(_) | GetRequest(_) => true] (upstream :551) - and the
    MEASURED form of it (matrix row MB1, BUILD-SPEC-P23 §8.10) is narrower than
    the blanket "invisible to G1-G4" this block used to assert: a
    wrong-namespace pod list is {b invisible to G1-G4 AS A RED, while still
    perturbing their graphs}. Under MB1 [t_p21_guarantee]'s four legs each stay
    CLEAN with [violated = None], so the P21 register really does not SEE the
    fault as a guarantee violation; what the P21 and P22 batteries do red on is
    premise-VACUITY floors and graph-size pins (the graph itself moves, BL0
    88 -> 76 and BLc 808 -> 424). Only L2 reds: BL0 [violated] names L2 with L2
    [interesting] 16 and red 16, L1 out of premise at 0.

    L1 is additionally close to a THEOREM of the port: its name conjunct inverts
    through the same [get_ordinal] that [partition_pods] used to build
    [condemned], and its namespace conjunct cannot red because the pod list is
    namespace-scoped from the CR's own namespace
    (v_stateful_set_reconciler.ml:527-531). {b That is a statement of how HARD L1
    is to falsify, and it is no longer a live decision rule.} The conditional
    this block used to carry - "if that cannot be SEEN red, L1 must be downgraded
    to EXCLUDE-WITH-A-PIN" - was measured NOT TRIGGERED and is STRUCK. Matrix row
    MB2-b reddened L1 with THREE coordinated reconciler edits (mint an
    unparseable pod name, stop [pod_filter] rejecting it, stop [partition_pods]
    dropping it): BL0 goes REFUTED naming L1 with {b L1 red = 32}. {b L1 SHIPS AS
    A MEMBER.} The single-site recipe of §5 MB2 SURVIVED, and the reason is in
    the tree rather than in L1 - [pod_filter] (:421-432) already requires
    [get_ordinal] to parse, so the defaulted-ordinal branch is unreachable.

    {b MEASURED} (BUILD-SPEC-P23 §8.1-§8.11; every number below is a committed
    pin in [test/p23_witness.ml], single-sourced, and this block is prose that
    quotes them, never a second assertion site). Four shipped graphs, BL0 zero
    budget / BLc crash / BLd drop / BLm monkey, all at
    [~desired:1 ~ordinals:[1] ~depth:40] over [P23_witness.p23_bound].

    - {b Every leg CLEAN and DECISIVE}, [violated] = [<none>], and {b red = 0 for
      BOTH members on EVERY graph} (replica technique, [Mc.states_seen] on the
      replica asserted equal to the leg's own [states] first).
    - {b States} 88 / 808 / 1144 / 10216, byte-identical to P22's, exactly as
      family-blindness requires; the thirteen committed pins
      (76 / 464 / 744 / 1976 / 116 and P22's four states plus gates
      20 / 276 / 96 / 2080) all came back UNMOVED, twice: once at measurement and
      again after the mutation matrix was restored.
    - {b Gate counts} (the register's OWN two-member union, never a family union)
      {b 68 / 560 / 816 / 7920}. These were UNPREDICTED and are not derivable
      from P22's 20 / 276 / 96 / 2080; they are far LARGER, which is this
      family's premises being cheaper to satisfy than G1-G4's, {e not} a stronger
      register.
    - {b Per-member [interesting]:} L1 {b 52 / 516 / 664 / 6496}, L2
      {b 16 / 112 / 288 / 1560}. Both members are live on every graph, so neither
      is a green that never fires.
    - {b Gate decomposition on BL0:} L1 only 52, L2 only 16, BOTH 0, union 68 =
      the leg's own [gate_states]. The two premises are DISJOINT on that graph
      and the mechanism is visible in the port: at [After_list_pod] the partition
      has not run yet, so [needed] and [condemned] are both empty and L1's
      witness is false exactly where L2's is true. Unlike P21's "G1 dominates the
      union gate", neither member dominates here; the gate is a clean sum.
    - {b Decoded ongoing states} 76 / 680 / 1056 / 8872 with {b decode failures
      0 / 0 / 0 / 0}, so the decode-failure fold above is never exercised on a
      graph. That is what makes it a dead branch at graph level, and why its
      coverage is a UNIT row rather than a graph assertion (below).
    - {b C1, the needed forall: LIVE}, witness states 20 / 200 / 208 / 3616.
      {b C2, the condemned forall: LIVE}, witness states 32 / 456 / 520 / 3136.
    - {b L2's inner ok-[List_response] premise: LIVE}, 8 / 60 / 48 / 816, with
      BL0's 8 carrying non-empty [objs]. The parked-with-pending count is
      16 / 112 / 288 / 1560 and the list-request content test (upstream
      :646-651) holds at 100 percent of those states, so that conjunct is
      exercised rather than merely passed.
    - {b The pvcs pin holds:} decoded states with a NON-EMPTY [pvcs] are
      {b 0 / 0 / 0 / 0} against 76 / 680 / 1056 / 8872 decoded states, so the
      exclusion above is behavior-free and not vacuous for want of decoded
      states.

    {b RED CAPABILITY, MEASURED (§8.10, the matrix RUN).} A green means nothing
    without it, so what killed what is recorded here. MB1 (wrong-namespace pod
    list) KILLED, naming L2, with the P21 control corrected to the honest form
    quoted above. MB2-b KILLED with L1 red = 32, which is what strikes the L1
    downgrade rule. MB7 KILLED: the pvcs pin HAS now been SEEN to redden on a
    [~vct:true] seed, so "excluded with a pin" here means excluded-and-watched.
    MB8 KILLED four independent assertions, including the POSITIVE one that
    :613 and :640 are PRESENT in [roster_guarantee_lines] - three of the four
    were measured in the matrix run itself, and that positive row is the fourth,
    measured in the review-fix pass after it was RESHAPED onto the committed
    literals (as first written it derived its expected value from the expression
    under test and was measured to PASS under this same mutant). X1 (negate L2's
    unique
    conjunct) and X2 (negate L1's body) both KILLED with the graph pins UNMOVED.
    MB6 SURVIVED at graph level - it mutates the dead decode-failure branch, and
    a mutation of dead code cannot be killed by a graph assertion however exact -
    and was then KILLED at UNIT level by [t_p23_mutation]'s
    [mb6_decode_failure_fold], which supplies the undecodable local state the
    graphs never produce. MB4 SURVIVED {e by design} (it is the trap row: a
    wrong-namespace [Get_then_delete] is not an L2 red, and a red anywhere is not
    L2 coverage), and X3 SURVIVED {e by design} (swapping two pure conjuncts of
    [pod_bound] leaves every suite green and every pin byte-identical, which is
    the evidence that the suite is pinned on behaviour and not on syntax).

    {b THE CONTAINMENT CONSEQUENCE IS NOW A MEASUREMENT, not an argument (MB3).}
    Under the MB2-b mutant on BL0: L1 [interesting] 64, red 32, [nholds] 32; L2
    [interesting] 16, red {b 0}, [nholds] {b 32}. L2's [holds] is false at
    exactly the same 32 states, yet L2 reports nothing in the leg's [violated]
    (first-in-list-order names L1) and nothing in the replica's red column (L2 is
    out of premise there). {b Only the UNGATED [holds] column shows L2 false
    too}, which is the disclosed hazard above, confirmed.

    {b STILL NOT CLAIMED.} No member has been seen red on a SHIPPED graph, and
    none should be: every red above is a deliberate mutant. In particular L2's
    inner-forall CONSEQUENT (:659-661) carries a measured PREMISE and a dedicated
    [t_p23_mutation] row for its red capability, but no red COUNT; E3 :606 stays
    excluded and un-de-vacuized until a two-CR spine lands; and no [~vct:true]
    LEG is shipped, only the [~vct:true] mutation row.

    {b House rules.} Every [holds]/[interesting] is total, pure and
    exception-free: no [raise], no [failwith], no partial accessor, no two-arm
    option/result match ([Option.fold] / [Result.fold] only), no [List.nth] and
    no [arr.(i)] (the upstream index quantifiers are eliminated by [List.for_all]
    / [List.exists] / [List.filter] over the decoded lists), and every match on a
    finite sum is exhaustive - the seventeen reconcile steps, the nine
    [Api_method.api_request] and nine [Api_method.api_response] constructors and
    the four [Message.message_content] constructors are spelled out, no wildcard
    arms. *)

val binding_sources : string list
(** The two upstream [source] strings, in member order L1, L2
    ([".../proof/internal_rely_guarantee.rs:613"]; [":640"]) - exposed so the
    P23 regression can assert the family's rendered sources agree with this list
    in member order, without restating them.

    {b BOTH ARE BARE, and that is LOAD-BEARING AND SILENT WHEN VIOLATED.} No
    parenthetical qualifier, ever - not ["...:613 (needed+condemned only)"], not
    the [vsts_invariants.ml:217] style, nothing.
    [t_p21_regression.ml:358-362] extracts the line number with
    [String.rindex_opt s ':'] fed to [int_of_string_opt]; a qualifier makes that
    return [None], the member silently DROPS OUT of [roster_guarantee_lines]
    ([:366-374]), {b and the E-ledger firewall pin at [:385-396] still PASSES
    while the member is invisible}. That is a vacuously-green pin, this
    project's named failure mode. The four in-tree members at
    internal_guarantee.ml:377/:396/:416/:436 carry exactly this bare shape; the
    phase additionally commits a POSITIVE assertion that both 613 and 640 are
    PRESENT in [roster_guarantee_lines], because the firewall's negative form
    cannot see an absent member. *)

val binding_family :
  cr:V_stateful_set.t -> controller_id:int -> Invariants.invariant list
(** The L1/L2 records, in that order (expected cardinal 2; pinned by the P23
    regression, not asserted here - no-exception house rule). Signature mirrors
    {!Internal_guarantee.guarantee_family} and
    {!Helper_invariants.helper_family}, and BOTH arguments are genuinely
    consumed: [~cr] supplies the [cr_key] whose [name] and [namespace] every
    conjunct reads, and [~controller_id] selects the [ongoing_reconciles] map
    the lookup goes through.

    Each member's [interesting] is its OWN premise mirror (P14 N3 - no
    borrowing), and neither is "the decode succeeded":

    - L1 fires when the reconcile at [cr_key] exists AND decodes AND at least
      one of the two ported quantifiers has a witness
      ([List.exists Option.is_some needed || condemned <> []]). The [inv16]
      precedent (invariants.ml:1016-1021) requires a NON-EMPTY [filtered_pods]
      for the same reason: counting a bare decode success would let a
      decode-DEFAULT register as assurance.
    - L2 fires when that reconcile's step IS [After_list_pod] and its
      [pending_req_msg] IS [Some] - upstream :643 plus :645 exactly. Anything
      weaker (for instance "decode ok") would make the member look live while
      its whole second conjunct sleeps.

    {b Premise wiring.} [Cluster.ongoing_reconciles] is TOTAL - a missing
    controller id yields the empty map (cluster.mli:78-82) - so instantiating
    this family at the wrong [~controller_id] sends every state out of premise:
    both members' [interesting] go to 0 and both stay green. That is the shape
    of the standard premise-wiring mutant, and it is why a non-zero per-member
    [interesting] is the only evidence that the family was wired to the leg's
    controller at all. *)

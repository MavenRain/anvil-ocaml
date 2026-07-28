(** P20 VSTS pod-monkey RELY conditions (BUILD-SPEC-P20 §2): the port's first
    ASSUMPTION register.

    Every family this port shipped before P20 asserts something upstream
    PROVES - each member's [source] points into a [proof/] (or [spec/]) file and
    is discharged by a Verus [lemma_always_*]. These three members are the
    opposite epistemic object: they are what upstream ASSUMES about the
    ENVIRONMENT and never discharges.
    [vsts_rely_conditions_pod_monkey] lives in
    [vstatefulset_controller/trusted/rely_guarantee.rs], is threaded into the
    composition record's [environment_rely] slot
    (composition/vstatefulset_reconciler.rs:23) and is consumed as a PREMISE,
    never as a conclusion. A member RED on a leg is therefore an
    assumption-violation datum - "the environment left the region upstream's
    proof assumes" - and NOT a defect in Anvil and NOT a soundness finding
    against the port.

    {b NOVELTY, in its MEASURED wording (B2 re-ran both sweeps).} Two claims,
    each an exact literal sweep, and both narrower than BUILD-SPEC-P20 §1's
    prose (B1 REFUTED the §1 wording; the corrections are recorded in the spec's
    MEASURED-CORRECTIONS section):

    - [rg 'source = "[^"]*rely_guarantee' lib/ test/] returns ZERO hits before
      this module, so no shipped [source] cited [rely_guarantee.rs] at all.
    - [rg 'source = "[^"]*trusted' lib/] returns TWO pre-existing hits, not one.
      {b The trailing [/] earlier carried on this sweep was a DEFECT}
      (BUILD-SPEC-P20 REVIEW-FIX B): it hid the second hit, whose source string
      has [trusted] followed by a SPACE. Re-run without it, the sweep returns
      the three new members plus, (a) [invariants.ml:1040],
      ["vreplicaset_controller/trusted/liveness_theorem.rs:21"], inside
      [Invariants.liveness_goal] (:1037-1043) - a LIVENESS GOAL and a member of
      no shipped safety family: the family lists close at :1023-1035,
      [partition] returns [inv1..inv16], and [liveness_goal] is defined AFTER
      it, reachable through neither [always], [eventually_always] nor [all];
      and (b) [vsts_invariants.ml:297],
      ["vstatefulset_controller/trusted (ordinal-stable ESR goal)"], inside
      [Vsts_invariants.liveness_goal] (:293-300) - likewise a LIVENESS GOAL and
      a member of no shipped safety family, VERIFIED the same way:
      [vsts_invariants] closes its list at :286
      ([inv_self; inv_ordinal; inv_pvc]), [always] (:288-291) is
      [Invariants.cluster_structural] appended to [vsts_invariants] and nothing
      else, and [liveness_goal] is defined AFTER both at :293. That module
      exports only [always], [liveness_goal] and [current_state_matches]
      (vsts_invariants.mli:11, :39, :43) - no [eventually_always], no [all] -
      and every caller of [Vsts_invariants.liveness_goal] uses it as a
      [leads_to] TARGET (cluster_check.ml:541, :572; t_p13_faults.ml:369),
      never as a safety member.
      The same sweep over [test/] exits 1, so the pre-P20 count of
      [trusted]-region-sourced shipped invariant VALUES is {b TWO} over the
      whole tree; both pre-exist at [15aedfd]. Neither is in a safety family,
      so R1-R3 are still the first [trusted]-sourced members of a shipped
      SAFETY family, and that narrowed form is the whole claim; the blanket
      "zero shipped invariant carries a trusted/ source" of §1 is false as
      written.

    {b Projection.} All three members traverse
    [Message.Pool.distinct (Cluster.in_flight s)] - the [inv_self] projection
    precedent (vsts_invariants.ml:152) and P19's (msg_provenance.ml:22-23).
    Upstream's [forall |msg|] premise at rely_guarantee.rs:19-23 quantifies over
    [s.in_flight()] ALONE - there is no [pending_req_msg] conjunct - so
    [Cluster.in_flight] is the exact analogue and the controller's
    [pending_req_msg] slot (controller.mli:57) is deliberately NOT also ranged
    over. The choice is numerically load-bearing rather than cosmetic:
    BUILD-SPEC-P20 §2.3 records that P15/P16 measured the wire pool and the
    pending slot DIVERGING under crash and drop, so ranging over both would move
    the Lc/Ld counts.

    {b Fully CR-agnostic and controller-id-agnostic, and this is FIDELITY.}
    Upstream quantifies [exists |vsts: VStatefulSetView|] over ALL vsts views
    (:68-69, :82-85), so the predicate genuinely does not depend on the scenario
    CR; the COLLAPSE below is what lets the port render that existential exactly
    rather than narrowing it. P18's helper family is CR-PARAMETERIZED by
    contrast ([helper_family ~cr], helper_invariants.ml:51) and discloses the
    resulting narrowing of upstream's existential to THE scenario CR
    (helper_invariants.mli:98-101, plus the H1 premise-rendering notes at
    :63-72); P20 needs no such disclosure.
    No [~cr], no [~controller_id] and no [?vct] is threaded - threading any of
    them would be unclaimed strength (the P18 residual-1 discipline) - which is
    why {!rely_family} is a plain list VALUE, not a function.

    Every [holds]/[interesting] is total, pure and exception-free; every match
    on a finite sum is exhaustive (no wildcard arm - upstream's [_ => true] arms
    are spelled out constructor by constructor, see the PERMISSIVENESS block).

    {b DELIBERATE LIFT (R1/R2 carry upstream HELPER names).} Upstream's only
    [StatePred] here is R3 (:17). [vsts_rely_create_req] (:57) is a plain
    [bool]-valued per-REQUEST predicate and [vsts_rely_update_req] (:76) is a
    per-request [StatePred]; neither is an [Invariants.invariant] as written. P20
    ships them LIFTED: R1's [holds s] is "every in-flight message with
    [src = Pod_monkey] and content [Api_request (Create_request req)] satisfies
    upstream :57", and R2's likewise for [Update_request] / :76. The closure is
    NOT minted by the port - it is upstream's OWN [forall msg] at :19-23
    restricted to its matching arm at :24 (resp. :25), so R3's body is literally
    R1's arm conjoined with R2's arm. That is why the members keep upstream's
    helper names and their :57 / :76 sources. A reader comparing [name] against
    upstream will find a [bool] helper rather than a [StatePred]; this block is
    that reader's answer.

    {b THE OWNER-REF EXISTENTIAL COLLAPSE (the key rendering argument, and it is
    EXACT).} Upstream's ownership conjuncts (:68-69, :82-83, :85) read
    [!exists |vsts: VStatefulSetView|
    md.owner_references_contains(vsts.controller_owner_ref())], quantifying over
    an infinite type. It is renderable EXACTLY because [controller_owner_ref]
    FIXES three of the five [Owner_reference.t] fields
    (owner_reference.mli:4-10) and leaves exactly two free. Port
    [V_stateful_set.controller_owner_ref] (v_stateful_set.ml:173-184, record
    literal :177-183) pins [block_owner_deletion = Some true] (:178),
    [controller = Some true] (:179) and [kind = V_stateful_set.kind] (:180),
    while [name] (:181) and [uid] (:182) come from the CR's own metadata.
    Ranging over all [VStatefulSetView] values makes [name] range over all
    strings and [uid] over all uids, the other three staying pinned, so

    {v
      exists vsts. owner_references_contains md (controller_owner_ref vsts)
        <=> exists r in owner_references md.
              r.block_owner_deletion = Some true
              && r.controller = Some true
              && Common.equal_kind r.kind V_stateful_set.kind
    v}

    and the family renders the right-hand side ([is_vsts_controller_owner_ref]).
    This is an EQUIVALENCE - neither a narrowing nor a widening - which is
    exactly where P18's H1 had to narrow and disclose instead. Three notes, each
    measured:

    - {b The [->0] unwraps do not break it}: upstream's spec-level
      [controller_owner_ref] uses [->0] on [metadata.name] / [metadata.uid],
      which in Verus are arbitrary-but-fixed on [None]. That only WIDENS the
      free range of [name]/[uid], which the collapse already treats as fully
      free, so the equivalence survives.
    - {b The port function is OPTION-TYPED} (B1 MEASURED-CORRECTION; §2.1 words
      it as building a bare record): it is
      [Owner_reference.t option], [None] when [metadata.name] or [metadata.uid]
      is absent (v_stateful_set.ml:173-174, an in-file comment discloses the
      divergence from Anvil's unwrap). The collapse is unaffected because the
      rendered right-hand side never CALLS [controller_owner_ref] - it tests the
      three pinned fields directly - and the option's [None] case corresponds to
      the unwrap case already covered above.
    - {b [owner_references] is itself an option}
      ([Owner_reference.t list option], object_meta.mli:16). [None] means the
      object carries no owner references at all, so the existential is [false]
      there and the NEGATED conjunct PASSES. Rendered [Option.fold ~none:false]
      - the reading of [Object_meta.owner_references_contains] itself
      (object_meta.mli:94-96) and of shipped [inv_self]
      (vsts_invariants.ml:193).

    {b DELIBERATE REDUNDANCY, disclosed up front.} [R3 <=> R1 && R2] BY
    CONSTRUCTION: R3's match at :23-27 has exactly two constrained arms, and
    they are R1's and R2's bodies. These are NOT three independent facts. R1 and
    R2 exist for ATTRIBUTION - so a measurement can say WHICH arm reddens, which
    R3 alone cannot - and the identity is pinned as a measured fact over every
    reachable state of every leg (BUILD-SPEC-P20 §5 prediction 6) rather than
    left for a reviewer to notice. Stating the overlap in advance is the P17
    overlap-misread discipline applied before the fact, not after it.

    {b R1} [vsts_rely_create_req] (:57-73), lifted over monkey-sourced
    [Create_request]s. Per request, on [Dynamic_object.kind r.obj]:

    - {b Pod / PersistentVolumeClaim} (:59): (a) the created object is NOT
      vsts-prefixed, where upstream reads [metadata.name] when [is Some] and
      ELSE [metadata.generate_name] (:61-66, and an absent [generate_name] makes
      the inner test [false]) - rendered as nested [Option.fold], never a
      [match] on an option; and (b) the COLLAPSE test above is FALSE on
      [metadata.owner_references] (:68-69).
    - {b every other kind}: [true] (:71), spelled out over the remaining NINE
      [Common.kind] constructors (common.mli:35-46), no wildcard.
    - {b KIND-READ DISCLOSURE}: the kind is read as [Dynamic_object.kind r.obj]
      directly rather than through [create_request_key], which is [Res.t]-typed
      hence partial on a missing metadata name (api_method.mli:137-139); a
      total, exception-free classifier must not consume it. The kind component
      it would carry is [obj.kind] verbatim, so the direct read loses nothing -
      the P19 M2 precedent (msg_provenance.mli's per-arm key-read block).

    {b R2} [vsts_rely_update_req] (:76-90), lifted over monkey-sourced
    [Update_request]s. This member is a STATE predicate, not a message
    predicate: conjunct (b) reads the CURRENT etcd object. Per request, for
    Pod / PersistentVolumeClaim kinds: (a) [not (has_vsts_prefix req.name)]
    (:80); (b) the STORED object at [req.key()] is not vsts-owned (:82-83,
    collapse test); (c) the NEW object does not BECOME vsts-owned (:85, collapse
    test). Every other kind [true] (:87), nine arms spelled out. Notes:

    - {b MISSING-KEY RENDERING (disclosed deviation)}: Verus [s.resources()[k]]
      on an ABSENT key is an arbitrary total-map value, so upstream's conjunct
      (b) is unconstrained there. The port reads
      [Cluster.lookup_resource s (Api_method.update_request_key r)] and folds
      [Option.fold ~none:true] - absent key => conjunct (b) PASSES - the P17
      [Option.fold md.uid ~none:(-1)] total-projection precedent. The choice is
      a genuine semantic pick, not a forced one; it cannot affect the P20
      headline because conjunct (a) already fails on every stored vsts pod, so
      the arbitrary-value case is never the reason a state is red.
    - {b KIND-READ}: upstream's dispatch at :78 matches [req.obj.kind] - the
      OBJECT's kind, not the key's - so the port reads
      [Dynamic_object.kind r.obj]. The two coincide here
      ([update_request_key] is [{obj.kind; namespace; name}],
      api_method.mli:121-122); the object read is the literal one.

    {b R3} [vsts_rely_conditions_pod_monkey] (:17-29) - upstream's actual
    always-member and the predicate sitting in the [environment_rely] slot. For
    every in-flight message with [src = Pod_monkey] and content
    [Api_request req]: [Create_request => R1], [Update_request => R2], and:

    - {b PERMISSIVENESS IS CONTENT, not a default}: upstream's [_ => true] at
      :26 carries the comment "Deletion/UpdateStatus requests are allowed". It
      is rendered as an EXHAUSTIVE match spelling out all seven remaining
      [Api_method.api_request] arms ([Get_request], [List_request],
      [Delete_request], [Update_status_request], [Get_then_delete_request],
      [Get_then_update_request], [Get_then_update_status_request];
      api_method.mli:103-113) returning [true]. A wildcard arm here would erase
      the phase's own subject matter - the deliberate SHAPE of what VSTS lets
      the environment do - and it is also what pins exclusion E3
      (BUILD-SPEC-P20 §3: the [vsts_rely_*] helpers at :92 / :105 / :120 are
      reachable only through [vsts_rely] (:39, :45-53), never through the monkey
      rely).

    {b PVC-ARM INERTNESS (measured elsewhere, stated here).} The Pod /
    PersistentVolumeClaim arm of R1 and R2 is structurally half-dead on every
    live graph: the shipped monkey emits pod-keyed requests only - exactly what
    P19's M2 [all_requests_from_pod_monkey_are_api_pod_requests] asserts, and
    P19 recorded the monkey's live repertoire as the four permitted pod-keyed
    arms (msg_provenance.mli's "Emergent green" block, citing
    pod_monkey.ml:58-116) - so the PVC branch's ONLY red witness is a forge
    (P19's M4-External-arm precedent). The arm is NOT narrowed away; it is
    disclosed as forge-only, and the claim that no LIVE graph reddens it is a
    prediction for B3 to measure, not a result asserted here.

    {b Classification firewall.} All three (name, source) pairs are new and
    distinct by exact string from every shipped pair - see the NOVELTY sweeps
    above, which are the strong form of that statement for the [source]
    component; [t_p20_regression] sweeps this family against ALL shipped suites
    via [Pair_guard.pair_leaks], both directions. *)

val rely_sources : string list
(** The three upstream [source] strings, in member order R1, R2, R3
    ([".../trusted/rely_guarantee.rs:57"]; [":76"]; [":17"]) - exposed so the
    P20 regression can pin the (name, source) DISJOINTNESS firewall and the E4
    scope ledger without restating the literals. *)

val rely_family : Invariants.invariant list
(** The R1/R2/R3 records, in that order (expected cardinal 3; pinned by
    [t_p20_regression], not asserted here - no-exception house rule).

    A plain list VALUE, not a function: the phase is CR-agnostic and
    controller-id-agnostic, and per the module doc that is FIDELITY (upstream
    quantifies over ALL [VStatefulSetView]s and the collapse renders that
    exactly), not convenience.

    Each member's [interesting] is its OWN premise mirror (P14 N3 - no
    borrowing), so a non-vacuity count attributes to the member that produced
    it: R1 fires on some in-flight [src = Pod_monkey] message carrying
    [Api_request (Create_request _)], R2 on the same with [Update_request _],
    R3 on the same with ANY [Api_request _] (upstream's own premise at :19-23).
    On a graph with no enabled monkey step all three are 0 - an honest
    N5-style vacuity reading, never a pass. *)

(** P18 pod/PVC metadata invariants (BUILD-SPEC-P18 §2): the two portable
    always-members of Anvil's
    [vstatefulset_controller/proof/helper_invariants.rs] (1494 lines, 11
    [StatePred]s of which 4 are true always-invariants; the other two
    always-members and the eventually-only members are excluded with measured
    pins - spec §3), exposed as a named CR-parameterized family for the P18
    dedicated fault leg. Every [holds]/[interesting] is total, pure and
    exception-free; the one list match is exhaustive (no wildcard arm).

    {b Disambiguation - the drift, and its FIX.} The shipped [inv_self] source
    string used to cite
    ["vstatefulset_controller/proof/helper_invariants/predicate.rs (widened
    inv9)"] (vsts_invariants.ml:217) - a path that does not exist: that
    directory layout belongs to vreplicaset_controller, and vstatefulset has
    the single flat file [proof/helper_invariants.rs]. P18 and P19 both
    deferred the fix on the belief that it would move committed (name, source)
    pins in four regression exes (P18 spec §8.3).

    {b P20 stage B6 measured that belief and REFUTED it}, then applied the fix
    (BUILD-SPEC-P20 §6 D4). The sweep: [rg 'helper_invariants/predicate'
    test/] returns ZERO hits, and the four exes that mention [inv_self] at all
    (t_p11_vsts_invariants.ml:169, t_p11_mutation.ml:225, t_p13_mutation.ml:38,
    t_p19_regression.ml:380) carry only its NAME - never its source - while
    [pair_guard.ml:29-49] computes every (name, source) pair DYNAMICALLY off
    the live suites and all four call sites assert against the empty list. So
    the fix moved no pin, which [git diff --stat] confirmed.

    [inv_self] now cites
    ["vreplicaset_controller/proof/helper_invariants/predicate.rs:237 (widened
    inv9; vstatefulset has no upstream analogue)"] - the real file and line of
    [vrs_reconcile_request_only_interferes_with_itself], with the widening
    disclosed. MEASURED against anvil-ref: [rg 'only_interferes_with_itself'
    src/controllers/vstatefulset_controller/] returns ZERO hits, so there is
    no vstatefulset original to cite. The trailing parenthetical also keeps
    the string distinct from [Invariants]' own VRS inv9 (invariants.ml:680),
    which cites the same file:line bare. THIS family's [source] strings cite
    [proof/helper_invariants.rs], so the two families stay (name,
    source)-disjoint by construction either way.

    {b H1}
    [all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref]
    (:52-69, [lemma_always] :75 via [init_invariant] :244): for every stored
    KEY with kind Pod, the CR's namespace and a [pod_name]-shaped name, the
    stored object has [deletion_timestamp = None], [finalizers = None] and
    [owner_references = Some [r]] for a single [r] equal to the CR's
    controller owner-ref modulo uid ([Owner_reference.eq_without_uid],
    owner_reference.ml:26-30 = upstream owner_reference.rs:37-42: compares
    controller / block_owner_deletion / kind / name, uid EXCLUDED - not the
    uid-sensitive [owner_references_contains]/[owner_references_only_contains]
    and not the block_owner_deletion-blind [is_vsts_controller_owner]).
    Deviations, each deliberate:

    - {b Name matcher}: upstream [pod_name_match] (predicate.rs:146-148) is
      existential over nat ordinals through the uninterpreted-but-TRUSTED
      decimal rendering [int_to_string_view] (string_view.rs:41; the
      abstract-string existential belongs to [pvc_name_match]'s TEMPLATE
      component, predicate.rs:140-143, not to pod ordinals); the port has no
      such function and uses the constructive inverse
      [Option.is_some (get_ordinal parent name)]
      (v_stateful_set_reconciler.ml:206-214). Under upstream's own trusted
      exec axioms ([i32_to_string]/[usize_to_string], string_view.rs:20-32,
      pin [int_to_string_view] to Rust's [to_string] - canonical decimal)
      the two matchers AGREE on every name whose ordinal is representable as
      an OCaml int: non-canonical renderings such as a ["00"] segment match
      NEITHER (no int renders to ["00"]; the injectivity axiom gives at most
      one preimage). The only genuine strengthening corner is MAGNITUDE:
      ordinals exceeding OCaml's [int] fail [get_ordinal]'s
      [int_of_string_opt] parse where upstream's unbounded nat would match.
      On reachable states the domains coincide: every stored pod name is
      minted by [pod_name] (canonical, small) and monkey candidates are the
      stored pods themselves (cluster.ml:748-755).
    - {b [~none:false] consequent}: [V_stateful_set.controller_owner_ref cr]
      is an Option ([None] when the CR lacks name/uid); the owner-ref conjunct
      folds it [~none:false], so an ill-formed CR REFUTES on any
      premise-matched pod rather than passing vacuously (conservative,
      red-capable; the [Vsts_invariants] precedent). Upstream excludes this
      corner by well-formedness.
    - {b The [Some \[\]] corner}: [make_owner_references] degrades to [\[\]]
      when the CR lacks name/uid (v_stateful_set_reconciler.ml:218-220), so
      [make_pod] can in principle emit [owner_references = Some \[\]]; the
      exhaustive one-element list match ([\[ r \]] accepted,
      [\[\] | _ :: _ :: _] refused) refutes it. Unreachable on the well-formed
      scenario CR.
    - {b Ill-formed-CR PREMISE rendering}: [parent] and [vsts_ns] render the
      CR's name/namespace with [Option.value ~default:""]
      (helper_invariants.ml:54-55), where upstream reads
      [vsts.object_ref().name/.namespace] ([metadata.name->0], an UNSPECIFIED
      value when [None] - the corner upstream excludes by well-formedness).
      A name-less CR therefore premise-matches ["vstatefulset--<ord>"]-shaped
      pod names (and the analogous PVC shapes for H2); on H1 any such
      premise hit then REFUTES via the [~none:false] consequent above (H2
      checks its ordinary three-None consequent). Unreachable on the
      scenario CR, which always carries name/uid.
    - {b Premise inversion vs the shipped suite} (apparent-overlap guard):
      both shipped VSTS pod invariants key ownership by OWNER-REF
      (vsts_invariants.ml:66-67, deliberate); H1 keys by NAME SHAPE in the
      CR's namespace and asserts the owner-ref only in the CONSEQUENT. H1 is
      the name-keyed complement of
      [owned_pods_have_wellformed_ordinal_identity]'s owner-ref-keyed
      quantification; neither subsumes the other.
    - {b dt-conjunct mutation note} (for the P18 matrix): no single-site
      source mutation can violate the [deletion_timestamp] conjunct -
      api_server create OVERRIDES the request's dt to [None]
      (api_server.ml:265-274) while passing [owner_references] AND
      [finalizers] through untouched.

    {b H2}
    [all_pvcs_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_or_owner_ref]
    (:1063-1076, [lemma_always] :1078 via [init_invariant] :1210; B1 decision:
    GO - upstream verbatim IS the three-None conjunction
    [owner_references is None && deletion_timestamp is None && finalizers is
    None]): for every stored KEY with kind PersistentVolumeClaim and a
    [pvc_name]-shaped name, the stored object has all three metadata fields
    [None] (asserted in upstream's order). The port's [make_pvc] stamps NO
    owner reference (v_stateful_set_reconciler.ml:279-286, disclosed at
    vsts_invariants.ml:41-50), which SATISFIES the no-owner-ref conjunct on
    reachable states. Deviations:

    - {b Premise narrowing (CR-parameterization)}: upstream H2 takes NO vsts
      argument - its premise is [exists |vsts_name| pvc_name_match(key.name,
      vsts_name)] over ALL strings, with NO namespace conjunct (:1065-1068).
      The CR-parameterized port narrows the existential to THE scenario CR's
      name (and, faithfully, adds no namespace conjunct). Port-H2 therefore
      checks a SUBSET of the keys upstream checks; on reachable states the
      domains coincide (every stored PVC is minted by [make_pvcs] for this
      CR).
    - {b In-family matcher}: the port ships no PVC-name inverse
      (v_stateful_set_reconciler.mli exports [pvc_name] but no PVC analogue of
      [get_ordinal]), so the round-trip matcher lives inside the family: strip
      the ["vstatefulset-"] prefix, split at the FIRST dash - a dash-free
      template can only be the first segment, realising upstream's
      [dash_free] premise (predicate.rs:140-143) structurally - and certify
      the remainder as [parent ^ "-" ^ ord] via the exported canonical
      [get_ordinal]. Same trusted-interpretation AGREEMENT as H1's matcher
      (canonical decimal on OCaml-int-representable ordinals; magnitude is
      the only strengthening corner), and the same reachable-state
      coincidence argument.
    - {b Honest vacuity off the vct leg}: on vct:false graphs no PVC ever
      exists, so H2's [interesting] never fires there; per-member count 0 IS
      the result, asserted per leg (P14 N5 discipline). Non-vacuity comes from
      the vct:true leg only.

    {b Rely-gap headline} (spec §4 prediction 4): upstream proves both members
    only under [vsts_rely_conditions(_pod_monkey)]
    (helper_invariants.rs:82-86 / :1084-1086); the port's monkey is
    rely-UNCONSTRAINED but candidate-RESTRICTED (it re-sends the STORED pods
    byte-identically), so whether the members survive the Lm leg is a
    measurement, not a static reading. Cross-note correcting
    BUILD-SPEC-P17.md:226's literal wording: a monkey CREATE on a live key is
    rejected [Object_already_exists]; only delete+recreate mints a fresh uid -
    which [eq_without_uid] ignores.

    {b CORRECTED READING (P20, BUILD-SPEC-P20 §6 D5).} P18's headline was
    readable as "Lm clean = the port's monkey stayed rely-CONSISTENT". P20
    measured that reading FALSE, on the same Lm graph and with no committed
    number moved. {!Rely_conditions.rely_family} renders the very assumption
    these two members are proved under (rely_guarantee.rs:17, plus its :57/:76
    request helpers) and it is REFUTED there: R3 red at 416 of its 832
    premise-firing states, R1 and R2 red at 208 of 208 each. The mechanism is
    the candidate restriction itself - a re-sent STORED vsts pod carries the
    vsts controller owner ref that rely_guarantee.rs:68-69 / :82-83 / :85
    forbid a monkey request to carry, and P20 measured by mutation that this
    OWNER-REF conjunct alone carries the result (the name-prefix conjunct is
    NOT load-bearing). So {b H1} holding on Lm is {b emergent robustness}: H1
    survives an environment OUTSIDE the region upstream's proof assumes, and
    its premise demonstrably FIRES there ([P18_witness.h1_interesting_lm] =
    1624, p18_witness.ml:151), so the green is not vacuous.
    {b The claim is H1's ALONE, and H2 is excluded from it}
    (BUILD-SPEC-P20 REVIEW-FIX E; this sentence used to read "H1/H2", which
    contradicted this same file's own vacuity note 25 lines up at :138-141):
    H2's premise never fires on any [vct:false] graph, Lm included, because no
    such graph ever mints a PVC - [p18_witness.ml:153] pins
    [h2_interesting_lm = 0]. {b H2 survived nothing on Lm}; its green there is
    HONEST VACUITY, not robustness. The narrowed reading is the one
    BUILD-SPEC-P18.md:341 and fault_check.mli:1185-1186 already ship, both of
    which say H1 only.
    Emergent robustness is not evidence of rely-compliance, and it is not a soundness finding
    against Anvil either: H1's and H2's upstream lemmas take the rely in their
    [requires] (helper_invariants.rs:82-86 / :1084-1086, the two cites already
    given above), so outside it those two lemmas assert nothing. That is a
    statement about THESE lemmas, not a claim about what Anvil proves elsewhere.
    Pins in test/p20_witness.ml, asserted by t_p20_rely. *)

val helper_sources : string list
(** The two upstream [source] strings
    (["vstatefulset_controller/proof/helper_invariants.rs:52"] and [":1063"])
    - exposed so the P18 regression can pin the (name, source) DISJOINTNESS
    firewall without restating the literals. *)

val helper_family :
  cr:V_stateful_set.t -> controller_id:int -> Invariants.invariant list
(** The H1/H2 records, in that order (expected cardinal 2; pinned by
    t_p18_regression, not asserted here - no-exception house rule). Signature
    mirrors [Vsts_invariants.always]; [controller_id] is threaded for
    call-site uniformity with the sibling families and is UNUSED by H1/H2
    (both are pure store predicates; the natural message-side P19 extension -
    spec §3 E6 - would consume it). Each member's [interesting] is its own
    premise mirror (P14 N3 - no borrowing): a stored key matching the member's
    premise exists; NOT "store non-empty", which saturates (P17 G7 lesson). *)

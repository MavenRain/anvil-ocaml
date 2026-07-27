(** P17 store-side object invariants (BUILD-SPEC-P17 §2-REVISED): the three
    always-members of Anvil's [kubernetes_cluster/proof/objects_in_store.rs]
    (S1 [etcd_objects_have_unique_uids] :23, S2
    [each_object_in_etcd_is_weakly_well_formed] :33 with helper :13-21, S3
    [each_object_in_etcd_has_at_most_one_controller_owner] :299), exposed as a
    named family for the P17 dedicated fault leg.

    {b Physical reuse, not a port.} The base suite ALREADY ships S1/S2/S3 as
    inv1/inv2/inv3 of {!Invariants.cluster_structural} under the same [source]
    strings (invariants.ml:155/:186/:208; the firewall copies inside [partition]
    at :400/:421/:443 carry the same bodies), consumed by [Invariants.always]
    and [Vsts_invariants.always] and asserted under fault budgets since P13 —
    so {!store_family} is a FILTER over the very records
    {!Invariants.cluster_structural} builds (selected by {!store_sources}), no
    re-transcription and no wrappers. A second copy would be drift risk and
    would break any (name, source) classification firewall by construction.

    {b Classification (deliberate divergence).} The P14-P16 regression suites
    pin their families DISJOINT from the base suite by (name, source) pairs;
    this family is instead pinned as an INCLUSION in
    [Invariants.cluster_structural] (t_p17_regression, stage B3) — S1/S2/S3
    ARE base-suite members, and the four existing disjointness guards for the
    P14-P16 families remain in force (this same phase k3-STRENGTHENS them from
    name-string proxies to (name, source) pairs — strengthened, not removed;
    spec section 7).

    {b Deliverable A — conjunct-for-conjunct fidelity re-audit} of the three
    shipped [holds] against upstream (audited 2026-07-27, B2; upstream lines
    re-read at point of use):

    - {b S1} (:23-31) vs inv1 (invariants.ml:153-182). Quantifier: upstream
      [forall] over distinct contained key pairs; port pairwise-distinctness via
      [sort_uniq] over the map's bindings — EXACT (bindings enumerate exactly
      the contained keys, once each). Projection: GAP FOUND AND FIXED (B2).
      Upstream compares the TOTAL projection [uid->0] (:29): Verus's [None->0]
      is one fixed (unspecified) value, so two stored objects with [uid = None]
      have EQUAL projections and VIOLATE S1 upstream, while the port's previous
      [List.filter_map] silently dropped [None] uids and PASSED such states
      (port weaker than upstream — the SAME direction as the P16 Q2 both-[None]
      deviation, F4, mirrored only message-side/state-side). Fixed in BOTH
      physical copies (:153-182 and the
      [partition] copy at :400): [Option.fold md.uid ~none:(-1)
      ~some:Common.Uid.to_int] renders [None->0] as [-1], outside the minted
      [uid_counter] range (api_server.ml:272 mints from the counter; the type
      admits no floor at init — api_server.mli:72 — but every SHIPPED seed
      floors the counters at >= 1, scenario.ml, so the argument is
      per-shipped-scenario, not typed), and two
      [None]s collide exactly as upstream. Residual disclosed deviation: a
      [None]/[Some] pair is UNPROVABLE either way upstream (the unspecified
      value is unconstrained vs any minted uid); the port renders it distinct —
      [-1] is a representative of the unique minted-range-consistent extension
      CLASS (any sentinel outside the minted range is extensionally identical
      on minted-uid states; they differ only on forgeable negative [Some]
      uids). The fix is latent under
      inv2/S2 (every stored object's [uid] is [Some] on every inv2-green
      state), so it is extensionally unchanged on every battery graph; the full
      battery stays green (B2, measured).
    - {b S2} (:33-39, helper [etcd_object_is_weakly_well_formed] :13-21) vs
      inv2 (invariants.ml:184-204). All FOUR helper conjuncts present
      (including [object_ref == key], the one the spec's own S2 summary
      omitted — spec §2 MEASURED-CORRECTION):
      {ol
      {- [well_formed_for_namespaced] (:16): upstream spec/object_meta.rs:
         196-201 = [name]/[namespace]/[resource_version]/[uid] all [Some];
         port object_meta.ml:85-89 — the same four conjuncts. EXACT.}
      {- [object_ref() == key] (:17): upstream [object_ref] is total
         (spec/dynamic.rs:19-29, [recommends] name/namespace [Some]); the
         port's is [Result]-valued (dynamic_object.ml:16-28, [Err] iff [name]
         or [namespace] is [None]) folded fail-loud [~error:(fun _ -> false)].
         On the [Ok] side both build the same [{kind; name; namespace}]
         triple. EXACT at member level: the [Err] arm fires only in states
         conjunct 1 already rejects.}
      {- [resource_version->0 < resource_version_counter] (:18): port
         [Option.fold ~none:false ~some:(< rvc)]. The [~none:false] arm fires
         only where conjunct 1 already rejects; [Some] side exact. EXACT at
         member level.}
      {- [uid->0 < uid_counter] (:19): same shape. EXACT at member level.}}
      Quantifier (:35-37): [Object_ref_map.for_all] = the
      [contains_key]-guarded [forall]. EXACT. NO GAP.
    - {b S3} (:299-312) vs inv3 (invariants.ml:206-228). Guard: upstream binds
      [owners = owner_references->0] before the implication but inspects it
      only under [owner_references is Some ==> ...]; port
      [Option.fold ~none:true]. EXACT. Filter (:306-308,
      [o.controller is Some && o.controller->0], = [controller_owner_filter]
      spec/owner_reference.rs:33-35): port [Owner_reference.is_controller]
      ([Option.value ~default:false o.controller], owner_reference.ml:24) —
      identical on all three cases ([None]/[Some false]/[Some true]). EXACT.
      Bound (:309): [List.length (List.filter is_controller orefs) <= 1].
      EXACT. NO GAP.

    {b [interesting] audits} (each member's own premise, P14 N3 discipline;
    re-verified invariants.ml:153-228 post-fix):
    - inv1 [cardinal >= 2] (:180) — exactly S1's premise (a distinct contained
      pair exists iff cardinal >= 2). EXACT mirror.
    - inv2 store-non-empty (:202) — exactly S2's premise (some contained key).
      EXACT mirror.
    - inv3 some-stored-object-has-an-[is_controller]-entry (:219-227) —
      STRICTLY STRONGER than S3's literal per-key guard
      ([owner_references is Some]): an object with [Some \[\]] (or [Some]
      without a controller entry) fires the guard but not this witness. Kept
      deliberately: the witness certifies the filtered count is >= 1 (the
      [<= 1] bound within one of tight), and it is conservative for
      non-vacuity pins (every witness state is a premise-fired state). Spec
      §2-REVISED wording corrected in place (MEASURED-CORRECTION, B2).

    {b Exclusions} (spec §3; measured pins land in B3):
    - {b E1} the well-formed strengthening: [etcd_object_is_well_formed]
      (:101, = weakly + [unmarshallable_object] + [valid_object] over
      [installed_types]), quantified at :110
      ([each_builtin_object_in_etcd_is_well_formed]) and :185
      ([each_custom_object_in_etcd_is_well_formed]). Excluded because every
      shipped scenario wires permissive [installed_types] (sweep
      [rg ": Api_server.installed_types"] over lib/, 2026-07-27: exactly three
      values exist — scenario.ml:36-43 vrs, :162-167 [vd_and_vrs_installed],
      :261-267 [vsts_installed] — each with [valid_object]/[valid_transition]/
      [unmarshallable_*] all [fun _ -> true]), making the strengthening
      extensionally the weakly member there. B3 pins the delta extensionally
      empty on the L0 graph (measured, not asserted).
    - {b E2} [each_object_in_etcd_is_well_formed<T>] (:267): premise verified
      contradictory by reading :240-:297 (B2, 2026-07-27). The :270-271
      premise is
      [s.resources().contains_key(key) && (key.kind !is CustomResourceKind &&
      key.kind == T::kind())] with [T: CustomResourceView], and
      [kind_is_custom_resource() ensures Self::kind() is CustomResourceKind]
      (spec/resource.rs:122-123), so [key.kind == T::kind()] forces [key.kind]
      IS a [CustomResourceKind] — contradicting the first conjunct. The member
      is vacuously true upstream as written (its own lemma :276-297 proves it
      by [always_weaken] from the :110/:185 members, not from the premise).
      Document-only exclusion; NOT ported.

    {b Adjacency} (grep-before-claim, the P16 overclaim lesson):
    - S3 vs inv16: [resp16] (invariants.ml:968-977) applies the same
      [<= 1]-[is_controller] filter to LIST-RESPONSE bodies, and inv16
      (:979-1018) requires reconciler-local pods to carry a controller ref
      naming the vrs; S3/inv3 is the STORE-side quantification of that
      property.
    - S2 is the upstream invariant named by req_resp_correspondence.mli's Q2
      disclosure (the both-[None] rv premise, F4) — the P17 legs (B3) turn
      that "latent, unreachable under S2" argument into a measurement.

    {b Novelty claim (narrow).} Sweep
    [rg "unique_uids|weakly_well_formed|at_most_one_controller"] over lib/ +
    test/ (2026-07-27, B2): every existing per-member assertion of S1/S2/S3 is
    one of (a) forged-STATE unit checks (t_p4_invariants.ml:709-711 crafted
    negatives; t_p13_faults.ml:250-253 forged dup-uid discriminator under a
    crash budget — a hand-built state, not a trajectory), (b) [first_violated]
    name pins under mutation (t_p5_mutation.ml:118-119), (c) fault-FREE pinned
    per-member [interesting] counts on the decisive fair graph
    (t_p11_vsts_invariants.ml:160-171). Every TRAJECTORY-leg assertion of
    these members evaluates them only inside the conjunction of the full
    [always]/VSTS union (masking discipline). The narrow claim is therefore:
    no fault_check leg has ever asserted the three store members ALONE with
    per-member [interesting] counts under a MEASURED fault gate; the P17 leg
    (B3) is the first such unmasked store-side measurement. Nothing stronger
    is claimed. *)

val store_sources : string list
(** The three upstream [source] strings selecting the family out of
    {!Invariants.cluster_structural} ([objects_in_store.rs:23]/[:33]/[:299]) —
    exposed so the B3 regression can pin the (name, source) INCLUSION without
    restating the strings. *)

val store_family : controller_id:int -> Invariants.invariant list
(** The S1/S2/S3 records, PHYSICALLY the elements of
    [Invariants.cluster_structural ~controller_id] whose [source] is listed in
    {!store_sources} (a filter — same closures, no copies). Expected cardinal
    3; pinned by t_p17_regression (B3), not asserted here (no-exception house
    rule). See the module doc for the per-conjunct fidelity verdicts, the
    [interesting] audits, exclusions E1/E2 and the narrowed novelty claim. *)

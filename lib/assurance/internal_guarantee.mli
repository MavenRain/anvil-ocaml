(** P21 VSTS internal GUARANTEE register (BUILD-SPEC-P21 §2): the exact DUAL of
    P20's rely family.

    P20 ({!Rely_conditions}) ported what upstream ASSUMES about the environment
    and never discharges ([trusted/rely_guarantee.rs]). These four members are
    the other half - what the VSTS controller GUARANTEES to everyone else - and
    unlike the rely conditions they ARE discharged upstream:
    [internal_guarantee_condition_holds]
    (vstatefulset_controller/proof/internal_rely_guarantee.rs:1003) and
    [internal_guarantee_condition_holds_on_all_vsts] (:1196) prove them over
    the composed cluster. The epistemic reading is therefore INVERTED from
    P20's: a P20 red says "the environment left the region upstream assumes"
    and indicts nobody; a red HERE says the port's own reconciler emitted a
    request upstream proves its reconciler never emits - a FIDELITY divergence
    in the port, and a real finding (BUILD-SPEC-P21 §4 prediction 2).
    fault_check.mli's leg block restates this framing.

    {b NOVELTY, in its MEASURED wording.} The sweep, run WITHOUT a trailing
    slash and WITHOUT any narrowing suffix (the exact defect class that cost
    P20 a review finding - its [trusted/] sweep hid [vsts_invariants.ml:297],
    whose source string has [trusted] followed by a SPACE):

    - [rg -n 'source = "[^"]*internal_rely_guarantee' lib/ test/] returned
      ZERO hits (exit 1) before this module, so {b no shipped member cited
      [proof/internal_rely_guarantee.rs] at all before P21}. That narrowed
      sentence is the whole claim. It is NOT claimed that this is the port's
      first [proof/]-sourced family (it obviously is not), nor its first
      guarantee-flavoured member:
      ["vreplicaset_controller/proof/guarantee.rs:45"] is already cited once
      (invariants.ml:986).
    - The companion sweep [rg -n 'source = "[^"]*rely_guarantee' lib/ test/]
      matches BOTH upstream [*rely_guarantee.rs] files and returns exactly
      P20's three members (rely_conditions.ml:171/:199/:231) plus this
      module's four - every other hit is a quotation inside a BUILD-SPEC.

    {b Projection.} All four members traverse
    [Message.Pool.distinct (Cluster.in_flight s)] - the [inv_self] projection
    precedent (vsts_invariants.ml:152), P19's (msg_provenance.ml:22-23) and
    P20's (rely_conditions.ml:21-22). Upstream's [forall |msg|] at
    internal_rely_guarantee.rs:546-549 quantifies over [s.in_flight()] ALONE -
    no [pending_req_msg] conjunct - so [Cluster.in_flight] is the exact
    analogue, and the controller's [pending_req_msg] slot (controller.mli:57)
    is deliberately not also ranged over (the P20 block records why that
    choice is numerically load-bearing under crash and drop).

    {b Parameterization (the P18 shape, and its disclosed narrowing).} Upstream
    G4's premise is
    [msg.src == HostId::Controller(controller_id, vsts.object_ref())] (:549),
    and its body reads the CR's namespace, name and controller owner ref. The
    port's [Message.host_id] is [Controller of int * Common.object_ref]
    (message.mli:40) - the exact analogue - so every member genuinely consumes
    BOTH [~cr] and [~controller_id]; this is [Helper_invariants.helper_family]'s
    signature for the same reason, not P20's plain-list shape. The disclosure
    that comes with it: upstream's own quantified closure
    [vsts_internal_guarantee_conditions] (:522) is
    [forall vsts. G4(controller_id, vsts)], and CR-parameterization narrows
    that [forall] to THE scenario CR - exactly the narrowing
    [helper_invariants.mli] discloses for H2. On a single-CR scenario the
    closure COLLAPSES to G4 at the scenario CR, which is why :522 is excluded
    as E1 rather than shipped as a fifth member (BUILD-SPEC-P21 §2.2; a
    two-CR spine is the experiment that would make it live).

    {b CR-KEY RENDERING (the totality decision).} The premise needs
    [vsts.object_ref()]. The port EXPORTS [V_stateful_set.object_ref], but it
    is [Common.object_ref Res.t] - partial, refusing a CR whose name or
    namespace is [None] - and a total classifier must not consume it (the P19
    M2 / P20 kind-read precedent). Folding its error arm to "no key" would
    make the whole family silently VACUOUS on exactly the CRs the port cannot
    key - the failure mode this port audits for. So the key is built directly
    from the same [->0] rendering the family already uses for the CR's name
    and namespace: Verus [metadata.name->0] / [namespace->0] on [None] is an
    arbitrary total-map value; the port folds both to [""], which is what the
    reconciler itself does (v_stateful_set_reconciler.ml:268-269, :604, :642,
    all [Option.value ~default:""]). On the shipped scenarios both fields are
    [Some], so the renderings coincide and the deviation is unreachable rather
    than merely unlikely.

    {b G1} [vsts_internal_guarantee_create_req] (:562-578), LIFTED over
    VSTS-controller-sourced [Create_request]s the way P20 lifted R1/R2 from
    upstream's per-request [bool] helpers. Flat conjuncts first: the request
    namespace equals the CR's (:563); [metadata.name is Some],
    [generate_name is None], [finalizers is None] (:564-566). Then the kind
    dispatch - upstream's TWO IMPLICATIONS at :567 and :574, so every kind
    other than Pod and PersistentVolumeClaim satisfies both vacuously and the
    remaining nine [Common.kind] constructors are spelled out [true]:

    - {b Pod arm} (:568-572): [owner_references == Some(Seq::empty().push(r))]
      - a SINGLETON sequence, so the port tests a ONE-element list, not
      membership. This is strictly stronger than P20 R1's existential collapse
      (rely_conditions.ml:77-79) and must not be weakened to match it: a
      two-ref object satisfies P20's shape and violates this one. The single
      [r] must satisfy [Owner_reference.eq_without_uid] against
      [V_stateful_set.controller_owner_ref cr] (owner_reference.mli:26 IS
      upstream's [owner_reference_eq_without_uid],
      kubernetes_api_objects/spec/owner_reference.rs:37-42 - called, not
      re-rendered); a [None] controller owner ref makes the conjunct FALSE,
      the E1-boundary reading P18 documented (helper_invariants.mli:72-77).
      Plus [pod_name_match] (:572), rendered by INVERSION through the
      reconciler's own [get_ordinal] - P18's rendering
      (helper_invariants.ml:58-62), reused rather than re-litigated.
    - {b PersistentVolumeClaim arm} (:575-576): [owner_references is None]
      and [pvc_name_match]. The PVC matcher DUPLICATES P18's private
      [pvc_name_matches] (helper_invariants.ml:32-43) because that binding is
      not exported; the duplication is deliberate and PINNED - [t_p21_guarantee]
      asserts the two copies agree on a shared name corpus, probing each
      BEHAVIOURALLY through its module's exported surface, so a later
      divergence is caught rather than silently tolerated. This copy's
      substring accessor is a guarded total [sub_opt] rather than P18's
      control-flow-protected [String.sub]; the difference is locally-checkable
      totality, disclosed here rather than silently "fixed" in P18's copy.
    - {b KIND-READ}: [req.key().name] at :572 is read as [metadata.name]
      directly rather than through [Api_method.create_request_key], which is
      [Res.t]-typed hence partial (api_method.mli:137-139); the [:564]
      conjunct has already required [name is Some] by the time the Pod arm is
      evaluated, so the two readings coincide - the P19 M2 precedent.

    {b G2} [vsts_internal_guarantee_get_then_delete_req] (:581-586), LIFTED
    over VSTS-controller-sourced [Get_then_delete_request]s. Four flat
    conjuncts, no kind dispatch (the kind is CONSTRAINED to Pod at :583, not
    dispatched on): request key in the CR's namespace (:582), key kind Pod
    (:583), [pod_name_match] on the key's name (:584), and the request's
    carried [owner_ref] equal to the CR's controller owner ref modulo uid
    (:585). [get_then_delete_request] carries [key] and [owner_ref] directly
    (api_method.mli:81-84), so nothing partial is touched.

    {b G3} [vsts_internal_guarantee_get_then_update_req] (:589-599), LIFTED
    over VSTS-controller-sourced [Get_then_update_request]s. Nine flat
    conjuncts. The first two (:590-591) are the request/object AGREEMENT
    clauses - the request's [name]/[namespace] must match the carried object's
    metadata - which is what makes a laundered object detectable. Then: object
    kind Pod (:592), request namespace equals the CR's (:593),
    [pod_name_match] (:594), and the TWO DISTINCT owner-ref conjuncts:

    - :595 is STRUCTURAL equality of [metadata.owner_references] against a
      singleton of the request's OWN [owner_ref] - uid included, so it is
      [Owner_reference.equal] (owner_reference.mli:30);
    - :596 is the uid-INSENSITIVE comparison of that [owner_ref] against the
      CR's controller owner ref ([eq_without_uid]).

    Conflating the two would silently weaken G3; the family renders them as
    separate conjuncts. Finally [deletion_timestamp is None] and
    [finalizers is None] (:597-598).

    {b G4} [no_interfering_request_between_vsts] (:544-559) - upstream's own
    [StatePred], shipped whole, and {b STRICTLY STRONGER than
    [G1 && G2 && G3]}, deliberately. Its match at :550-557 also carries the
    READ-ONLY arms ([ListRequest | GetRequest => true], :551) and the
    FORBIDDEN-KIND arm ([_ => false], :556), which the port expands into the
    four request kinds the VSTS controller is guaranteed never to issue:
    [Delete_request], [Update_request], [Update_status_request],
    [Get_then_update_status_request]. (Upstream's comment at :555 names only
    three of the four; the rendering follows the CODE, not the comment.)
    G1-G3 lifted individually are vacuously true off their own kind, so a
    reconciler emitting a plain [Update_request] reddens G4 while leaving
    G1-G3 green - a real cross-member attribution datum, measured as mutation
    row MG1. {b No identity pin is shipped}: P20's [R3 <=> R1 && R2] pin was a
    THEOREM of the code (review finding A), and the analogous identity here is
    FALSE on purpose; nothing in this family or its tests asserts one.

    {b E-ledger} (BUILD-SPEC-P21 §2.2; the file has exactly NINE
    [pub open spec fn], 4 shipped + 5 excluded, total and disjoint): E1 :522
    (the quantified closure - collapses to G4 on a single-CR scenario, above);
    E2 :528 ([every_msg_from_vsts_controller_carries_vsts_key] - ALREADY
    SHIPPED as P19's M1 under its [helper_invariants.rs:1213] citation; P19's
    "semantic duplicate" call RE-MEASURED this phase: SEMANTICALLY IDENTICAL,
    one [is_controller_id] unfolding apart, bridged by upstream itself at
    [liveness/proof.rs:903-927]; spec §2.2); E3 :606 /
    E4 :613 / E5 :640 (the controller-LOCAL register - needs the typed VSTS
    reconcile state, and the port's [Controller.ongoing_reconcile.local_state]
    is an untyped [Value.t], controller.mli:60; deferred as real plumbing, the
    strongest remaining unoccupied register in the file).

    Every [holds]/[interesting] is total, pure and exception-free; every match
    on a finite sum is exhaustive - the nine [Api_method.api_request]
    constructors (api_method.mli:103-112), the five [Message.host_id]
    constructors (message.mli:38-42) and the eleven [Common.kind] constructors
    are spelled out, no wildcard arms.

    {b Classification firewall.} All four (name, source) pairs are new and
    distinct by exact string from every shipped pair - the NOVELTY sweeps
    above are the strong form for the [source] component -
    and [t_p21_regression] sweeps this family against ALL shipped suites via
    [Pair_guard.pair_leaks], both directions. *)

val guarantee_sources : string list
(** The four upstream [source] strings, in member order G1, G2, G3, G4
    ([".../proof/internal_rely_guarantee.rs:562"]; [":581"]; [":589"];
    [":544"] - G4's line is lowest because upstream defines the [StatePred]
    before its per-request helpers; the list is in MEMBER order, not line
    order) - exposed so [t_p21_regression] can assert the family's rendered
    sources agree with this list in member order. The regression ALSO commits
    its own literal copies of all four (name, source) pairs, deliberately
    (the firewall rationale: a guard must not read the very binding it
    guards), so this export supplements the restated literals, never
    replaces them. *)

val guarantee_family :
  cr:V_stateful_set.t -> controller_id:int -> Invariants.invariant list
(** The G1/G2/G3/G4 records, in that order (expected cardinal 4; pinned by
    [t_p21_regression], not asserted here - no-exception house rule).
    Signature mirrors {!Helper_invariants.helper_family}, and unlike that
    family's [controller_id] (threaded for uniformity, unused) BOTH arguments
    are genuinely consumed by every member: the shared premise is "in-flight
    message with [src = Controller (controller_id, cr_key)]" for the CR's
    [->0]-rendered key.

    Each member's [interesting] is its OWN premise mirror (P14 N3 - no
    borrowing), so a non-vacuity count attributes to the member that produced
    it: G1 fires on some in-flight VSTS-sourced [Create_request], G2 on
    [Get_then_delete_request], G3 on [Get_then_update_request], G4 on ANY
    VSTS-sourced [Api_request] (upstream's own premise at :546-549). G2/G3
    fire only where the reconciler reaches its delete/update steps; MEASURED
    (BUILD-SPEC-P21 §8, refuting §4 prediction 4 in BOTH directions): G2 is 0
    on ALL FIVE committed graphs - the delete steps are dead code at
    [desired = 1], reported as an honest N5-style vacuity row family-wide,
    never as a pass - while G3 fires even on the fault-free zero-budget graph
    (the rolling-update path emits [Get_then_update_request] unprovoked). *)

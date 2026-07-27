(** BUILD-SPEC-P16: the REQUEST/RESPONSE correspondence family, four Anvil
    [StatePred<ClusterState>]s from
    [src/kubernetes_cluster/proof/req_resp.rs], the first shipped members
    that open a response message's BODY and relate it to [s.api_server]
    WHILE quantifying over ALL in-flight messages. Both halves of that
    qualifier are load-bearing (P16-review correction F1; verified against
    the counterexample CLASS directly, 2026-07-27: [rg "list_resp_objs"]
    enumerates every shipped response-body opener - resp15/resp16 only - and
    the two consumers below are scope-checked; the
    [rg "first|nothing before|No shipped"] sweep located the claim SITES to
    rewrite, it is not the verification):
    P14's N-family ({!Correspondence}) quantifies over all in-flight
    messages but reads only [rpc_id]s, and P15's R-family
    ({!Reconcile_correspondence}) reads only [pending_req_msg] identity -
    neither opens a body - while shipped inv15
    [filtered_pods_invariant_matrix] and inv16
    [local_pods_are_bound_to_vrs_with_key] ([Invariants.always],
    invariants.ml:872-965 / :968-1018) DO open list-response bodies and
    relate them to [resources s] / the rv counter, but only for the single
    pending list request of one decoded ongoing VRS reconcile, never over
    all in-flight messages. Transcribed against the durable upstream
    checkout at [~/Documents/anvil-ref], so every [source] string is
    checkable:

    - Q1 [object_in_ok_get_response_has_smaller_rv_than_etcd]
      (kubernetes_cluster/proof/req_resp.rs:14-22)
    - Q2 [object_in_ok_get_resp_is_same_as_etcd_with_same_rv]
      (req_resp.rs:69-78)
    - Q3 [key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_pending_req]
      (req_resp.rs:136-149)
    - Q5 [key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req]
      (req_resp.rs:345-361)

    {b The family splits into TWO lists by guard home, and the split is the
    phase's subject.} {!rv_family} (Q1, Q2) is guarded on the network and
    etcd and never reads a reconcile; {!matched_family} (Q3, Q5) couples an
    in-flight response to [ongoing_reconciles] through
    [Message.resp_msg_matches_req_msg]. P14 and P15 established that crash
    sensitivity is determined by WHERE a guard lives; these two lists carry
    that thesis onto the drop and monkey fault dimensions, so they are
    asserted on SEPARATE checker legs and never unioned, with each other or
    with {!Correspondence.family}, {!Reconcile_correspondence.family},
    {!Invariants.always} or {!Vsts_invariants.always}: a union would move
    committed pinned counts, and under mutation MD a P14 member could fire
    first and mask Q5, the phase's intended witness (BUILD-SPEC-P16 section
    4.4: a [violated] naming a non-P16 member is a harness bug, not a
    finding).

    {b Q4 is DELIBERATELY EXCLUDED
    ([key_of_object_in_matched_ok_update_resp_message_is_same_as_key_of_pending_req],
    req_resp.rs:240-255).} This is a statement about THIS PORT's shipped
    reconcilers, not a claim that upstream's statement is redundant. In this
    port, Q4's premise is structurally unreachable in every shipped
    controller and every fault configuration: no shipped reconciler ever
    issues a plain [Update_request]. VStatefulSet, VReplicaSet and
    VDeployment all use the combined [Get_then_update*] forms
    (v_stateful_set_reconciler.ml:697, vreplica_set_reconciler.ml:179,
    v_deployment_reconciler.ml:335/:376), which produce the DISTINCT
    [Get_then_update_response] constructor and so can never satisfy Q4's
    [is_ok_update_response] premise. The only other producer of an OK update
    response would be a pod-monkey [Update_pod] request, whose response
    carries the monkey's freshly allocated [rpc_id] ([update_pod],
    pod_monkey.ml:87-100, allocation at :90-92; :57-69 is [create_pod] -
    cite corrected per P16-review F3) and
    therefore cannot satisfy [resp_msg_matches_req_msg] against a
    controller's pending request without violating the already-shipped P14
    member [every_in_flight_msg_has_no_replicas_and_has_unique_id]. Shipping
    Q4 load-bearing would reproduce P14's N5 failure exactly: a member whose
    premise is unreachable, whose clean verdict is empty, and whose
    per-member count is 0 on every graph. The exclusion is MEASURED, not
    asserted: the P16 regression suite pins the structural fact (no shipped
    reconciler's reachable request set contains a plain [Update_request])
    directly off the real reconcilers; if that pin ever reddens because a
    future controller gains a plain [Update_request], Q4 becomes portable and
    this note must be revisited (BUILD-SPEC-P16 section 2).

    {b Partiality differences from upstream, handled explicitly.} Upstream's
    [DynamicObjectView::object_ref()] is TOTAL; the port's
    {!Dynamic_object.object_ref} is result-valued (it errors when
    [metadata.name] or [metadata.namespace] is unset). Every key comparison
    below folds that result rather than assuming totality: an object whose
    ref cannot be formed matches NO key, so in premise position (Q2) the
    member goes vacuous and in consequent position (Q3, Q5) it refutes, never
    silently passes. Likewise upstream's [resource_version->0] and
    [get_get_request()] / [get_create_request()] projections are partial
    (arbitrary off their domain); the port renders each as an option or a
    both-Some conjunction, choosing vacuity in premise position and fail-loud
    falsity in consequent position, as documented per member.

    {b Honest limits (BUILD-SPEC-P16 section 8).} Nothing here is proved.
    Upstream proves all these statements [always] in Verus; every verdict
    this family produces is bounded falsification up to (depth, {!Bound.t},
    fault budget) on one VStatefulSet scenario. A clean drop or monkey leg
    over these members is a NEGATIVE result and must be reported as one. *)

val object_in_ok_get_response_has_smaller_rv_than_etcd : Invariants.invariant
(** Q1 (req_resp.rs:14-22): every in-flight OK get response carries an object
    whose [metadata.resource_version] is [Some] and strictly smaller than
    [s.api_server.resource_version_counter]. Nullary. The counter is read
    directly off the public {!Api_server.state} record field
    (api_server.mli:24-28); no accessor is added (BUILD-SPEC-P16 section
    4.1). A response object with [resource_version = None] REFUTES the member
    (upstream's [is Some] conjunct failing), it does not vacuate it.
    [interesting] fires iff at least one in-flight OK get response exists:
    predicted zero under the vct:false seed, where no [Get_request] is ever
    issued (P16-E), and that vacuity is a measurement, not an argument.

    {b Upstream flakiness note.} Upstream's own authors mark the PROOF of
    this lemma flaky ([// TODO: investigate flaky proof], req_resp.rs:24).
    The STATEMENT is what is ported and is authoritative here; do not cite
    the upstream proof as solid support for this member. *)

val object_in_ok_get_resp_is_same_as_etcd_with_same_rv :
  Bound.t -> Invariants.invariant
(** Q2 (req_resp.rs:69-78): if an in-flight OK get response's object matches
    a key stored in [s.api_server.resources] and the stored and response
    objects carry the SAME resource version, the two objects are equal
    ({!Dynamic_object.equal}, upstream's derived [==]).

    {b Disclosed strengthening (BUILD-SPEC-P16 sections 2 and 8.3).}
    Upstream parameterizes by a single [key]; this member is universally
    closed over the BOUND KEY SET: the keys of [s.api_server.resources],
    capped per kind by [max_objects_per_kind] following the checker's own
    candidate-key discipline (the per-kind [take] of cluster.ml:719-732),
    which is why it takes the {!Bound.t}. Strictly stronger than any single
    instantiation among the visited keys, and BOUNDED relative to full
    universal closure: a key beyond the per-kind cap is never visited, one
    more disclosed dimension of "falsification up to [Bound.t]".

    Both [resource_version->0] projections are rendered as "both [Some] and
    equal", so a missing resource version fails the premise (vacuity) rather
    than comparing arbitrary values. {b Disclosed DIRECTION of that
    deviation (P16-review F4).} In Verus the [->0] projection is TOTAL, so
    at a state where BOTH rvs are [None] upstream's rv-equality premise is
    reflexively TRUE and upstream Q2 DEMANDS object equality there; this
    rendering makes that premise FALSE instead, so the port ACCEPTS
    both-[None] states upstream rejects - a premise STRENGTHENING, i.e. an
    invariant WEAKENING. Latent exactly as long as every stored object
    carries [Some] resource_version, which is upstream's
    [each_object_in_etcd_is_weakly_well_formed] (objects_in_store.rs:33) -
    shipped here as inv2 (invariants.ml:184-204, in
    [Invariants.cluster_structural] / [always]) but never asserted on a
    P16 leg (the section-4.4 masking discipline keeps the suites separate),
    so on the P16 graphs the unreachability of both-[None] remains an
    ARGUMENT until BUILD-SPEC-P17 measures the premise store-side.
    [interesting] fires iff Q2's OWN full premise fires at a key the closure
    actually visits: some in-flight OK get response matching a stored bound
    key with equal resource version. Predicted zero under the vct:false seed
    (P16-E). *)

val key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_pending_req :
  controller_id:int -> Invariants.invariant
(** Q3 (req_resp.rs:136-149): every in-flight OK get response that matches
    ([Message.resp_msg_matches_req_msg], message.mli:242, upstream argument
    order (resp, req)) the pending request of some ongoing reconcile carries
    an object whose key equals that pending GET request's key. Universally
    closed over all bound keys of [ongoing_reconciles] where upstream
    parameterizes by (controller_id, key), the same treatment P15 gave its
    R-family; upstream's [key.kind is CustomResourceKind] premise is
    discharged by construction because scheduling only ever binds keys of the
    controller model's custom-resource kind (cluster.ml:654-660). The
    consequent's projection of the pending request as a GET request cannot
    miss under the matching premise (the response/request constructor pairing
    inside [resp_msg_matches_req_msg]); were that pairing ever broken, the
    member refutes rather than vacuates. [interesting] fires iff Q3's OWN
    full antecedent fires: an ongoing reconcile holds a pending request and
    some in-flight OK get response matches it. Predicted zero under the
    vct:false seed (P16-E), where no get request is ever issued. *)

val key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req :
  controller_id:int -> Invariants.invariant
(** Q5 (req_resp.rs:345-361), the phase headline: every in-flight OK CREATE
    response that matches the pending request of some ongoing reconcile,
    where that pending create request names its object
    ([obj.metadata.name is Some]; generate-name creates are excluded
    upstream, req_resp.rs:358), carries an object whose key equals the
    pending create request's key (upstream [create_req.key()], ported as the
    result-valued {!Api_method.create_request_key}, whose error case is
    exactly [name = None] and is therefore unreachable under the name
    antecedent; it refutes rather than vacuates if reached). Universally
    closed over bound keys like Q3. Upstream's quantifier trigger sits on
    [resp_msg_matches_req_msg] rather than [in_flight().contains]; triggers
    guide the Verus prover and do not change the ported statement. This is
    the member mutation MD must flip on the drop leg: the fabricated drop
    response inherits the request's [rpc_id] and so SATISFIES the matching
    premise, and only its [res = Error] body keeps Q5's [is_ok] premise
    false (BUILD-SPEC-P16 section 3, P16-C). [interesting] fires iff Q5's
    OWN full antecedent fires, including the name-is-Some conjunct: the one
    member predicted non-vacuous even under the vct:false seed (P16-E). *)

val rv_family : Bound.t -> Invariants.invariant list
(** List A, [Q1; Q2] in upstream order: the members guarded on network +
    etcd, reading no reconcile state. Consumed only by its own checker leg
    with [list_select = Rv_list], asserted SEPARATELY from
    {!matched_family} and never unioned with it or with any other shipped
    suite (module header; BUILD-SPEC-P16 section 4.4). The {!Bound.t}
    instantiates Q2's bound-key closure and must be the same bound the
    consuming leg explores under, or the per-member [interesting] counts
    stop being evidence about that leg. *)

val matched_family : controller_id:int -> Invariants.invariant list
(** List B, [Q3; Q5] in upstream order: the reconcile-COUPLED members, whose
    guards read [ongoing_reconciles(controller_id)] through
    [resp_msg_matches_req_msg]. Consumed only by its own checker leg with
    [list_select = Matched_list], asserted SEPARATELY from {!rv_family} and
    never unioned with it or with any other shipped suite (module header;
    BUILD-SPEC-P16 section 4.4). [controller_id] is upstream's
    [self.controller_models.contains_key(controller_id)] requires premise:
    pass the id of a registered controller model or both members are
    trivially vacuous (an empty [ongoing_reconciles] map). *)

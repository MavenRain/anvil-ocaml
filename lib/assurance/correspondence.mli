(** BUILD-SPEC-P14: the ID-LEVEL controller-runtime correspondence family — the
    first invariants in this port that constrain message IDENTITY, i.e. that
    relate an [Rpc_id.t] to {!Cluster.cluster_state}'s allocator or to another
    message's id.

    {b MEASURED CORRECTION to this module's original header.} It first claimed
    these were "the first invariants in this port that READ A MESSAGE". That is
    FALSE and was caught in review: shipped inv9
    [vrs_reconcile_request_only_interferes_with_itself]
    (invariants.ml:656-675) quantifies over
    [Message.Pool.distinct (Cluster.in_flight s)], and it sits in
    {!Invariants.always} ([always] is observationally
    [cluster_structural @ \[inv9; inv15; inv16\]], invariants.mli:58); inv8 and
    inv14 read messages too, and {!Vsts_invariants} ships a VSTS analogue of
    inv9. What is genuinely absent before P14 is any invariant relating a
    message's [rpc_id] to [s.rpc_id_allocator] or to another message's [rpc_id] —
    [Rpc_id] was compared only inside [Message.equal] (message.ml:142) and
    [Message.resp_msg_matches_req_msg] (message.ml:287-292). The narrower claim is
    the true one and is the only one this module asserts. The phase's
    crash-sensitivity result is UNAFFECTED: P13's suite already contained
    message-reading interference invariants and still refuted nothing under the
    crash mutants, which is precisely the gap the id-level members close.

    Five Anvil [StatePred<ClusterState>]s from
    [src/kubernetes_cluster/proof/network.rs], ported as pure
    {!Cluster.cluster_state} predicates reusing {!Invariants.invariant}:

    - N1 [every_in_flight_msg_has_lower_id_than_allocator] (network.rs:35-41)
    - N2 [every_pending_req_msg_has_lower_id_than_allocator] (network.rs:76-83)
    - N3 [every_in_flight_req_msg_has_different_id_from_pending_req_msg_of_every_ongoing_reconcile]
      (network.rs:254-268)
    - N4 [every_in_flight_req_msg_from_controller_has_valid_controller_id]
      (network.rs:312-320)
    - N5 [every_in_flight_msg_has_no_replicas_and_has_unique_id]
      (network.rs:382-394)

    Transcribed against the upstream checkout, not reconstructed from memory, so
    the [source] strings are checkable rather than nominal.

    {b The gap this closes (BUILD-SPEC-P14 section 1).} P13 measured an honest
    negative result: mutating the crash transition refuted NOTHING, because every
    member of the shipped suite is etcd-local, counter-monotone, or about request
    interference — [rg pending_req_msg] over [lib/assurance/] and [lib/checker/]
    reaches only the VRS [partition] closure and {!Cluster_check}'s state
    equality. So P13 certified the shipped invariants ACROSS a crash without
    certifying the crash TRANSITION. This family is the missing dimension:
    [restart_controller] (cluster.ml:291-324) empties [ongoing_reconciles] —
    dropping every [pending_req_msg] — while touching neither [s.network] nor
    [s.rpc_id_allocator], so a pre-crash request survives in flight with no
    owning reconcile, and survives PERMANENTLY (a post-crash response has no
    consumer: [Controller_step] filters recv to [dst = Controller (cid, _)],
    cluster.ml:617-624, but [continue_reconcile] needs an ongoing reconcile at
    the key, controller.ml:191-204, and both [run_scheduled_reconcile] and
    [end_reconcile] require [recv = None], controller.ml:138 / :272).

    {b Why this is a SEPARATE list and never appended to an existing one.}
    {!Vsts_invariants.always} feeds both the fault-free legs in {!Cluster_check}
    AND P13's G1 at [fault_check.ml:318]. Appending here would move P13's
    committed pinned counts (464 states, gate 388, fault_free 76 - CORRECTED in
    review: this originally read "464 / 152 states, gate 388 / 76", which
    mis-transcribed P13's M1-MUTANT before/after pair as if it were two pins;
    152 and 76 are what G1 becomes UNDER M1, not anything P13 committed) and
    silently
    rewrite a shipped result. The family is exported on its own and consumed only
    by its own leg.

    {b ID-LEVEL, and the word is load-bearing.} These five constrain rpc-id
    DISCIPLINE: ids stay below the monotone allocator, and no two in-flight
    messages collide on one. They do NOT state the request/response lifecycle.
    Upstream's [pending_req_in_flight_or_resp_in_flight_at_reconcile_state]
    ([controller_runtime_safety.rs:90-97], with four
    [lemma_xor_preserves_during_*_step] cases) is the natural sixth member and is
    DELIBERATELY not shipped (BUILD-SPEC-P14 section 2): its disjunct is
    genuinely necessary — between api-server handling and controller delivery the
    REQUEST is gone and only the RESPONSE is in flight, and [drop_req]
    (cluster.ml:350+) additionally converts a request into an error response via
    [Message.form_matched_err_resp_msg] — so a version written without the
    disjunct is false in the crash-FREE graph too and its refutation would prove
    nothing about crashes. Deferring it is a scope decision, not an oversight.
    Say "id-level" wherever this family is described; do not let
    "correspondence" silently widen.

    {b Disclosed deviation from P13's discipline.} P13 held [lib/cluster/]
    pristine ([fault_check.mli:18-19]). P14 modifies it by exactly ONE purely
    additive accessor, [Message.Rpc_id_allocator.rpc_id_count]
    (BUILD-SPEC-P14 section 4.1), because N1 and N2 compare an [Rpc_id.t] against
    the allocator's counter and the counter was unreadable. It adds no state, no
    behaviour and no transition, and it mirrors the sibling accessor
    [Controller.Reconcile_id_allocator.reconcile_count] (controller.ml:48) that
    {!Cluster_check} already consumes. This module does not inherit P13's
    stronger "lib/cluster/ untouched" claim.

    {b Honest limits.} Upstream PROVES these five inductive in Verus; nothing
    here is proved. Any verdict obtained with this family is bounded
    falsification up to (depth, {!Bound.t}, fault budget), and a clean verdict is
    evidence that the crash transition preserves ID discipline — not that it is
    faithful in every other respect. P13's negative result is NARROWED by this
    family, not erased. *)

val in_flight_lower_than_allocator : Invariants.invariant
(** N1 (network.rs:35-41): every in-flight message's [rpc_id] is strictly below
    [s.rpc_id_allocator]'s counter. [interesting] fires once anything is in
    flight. This is the member that makes the allocator's monotonicity
    observable, and therefore the member an allocator-RESET mutation attacks. *)

val pending_req_lower_than_allocator :
  controller_id:int -> Invariants.invariant
(** N2 (network.rs:76-83): every ongoing reconcile's [pending_req_msg], when
    present, carries an [rpc_id] strictly below the allocator's counter. The
    [contains_key] premise is discharged by [Object_ref_map.for_all] visiting
    only bound keys; the [is Some] premise by the [~none:true] leg of
    [Option.fold]. [interesting] fires iff some ongoing reconcile is actually
    awaiting a response — while every [pending_req_msg] is [None] this member is
    vacuously true. *)

val in_flight_req_id_differs_from_pending :
  controller_id:int -> Invariants.invariant
(** N3 (network.rs:254-268): for every ongoing reconcile holding a pending
    request, no OTHER in-flight api REQUEST carries that request's [rpc_id].
    [Message.equal] (all four fields) is Anvil's [msg != pending_req] guard.
    Shares N2's [interesting]. *)

val in_flight_req_from_controller_valid_id : Cluster.t -> Invariants.invariant
(** N4 (network.rs:312-320): every in-flight api request whose [src] is a
    controller names a controller id that the cluster's model registry knows.
    Takes a {!Cluster.t} because upstream reads [self.controller_models] — a
    field of the CLUSTER (the static model registry), not of the cluster STATE.
    [interesting] fires iff some in-flight api request has a controller [src]. *)

val in_flight_unique_id : Invariants.invariant
(** N5 (network.rs:382-394): every in-flight message has multiplicity exactly one
    AND shares its [rpc_id] with no other in-flight message. The multiplicity
    conjunct is the one place {!Multiset.S.count} is genuinely needed —
    [distinct] cannot state it. Upstream's weaker
    [every_in_flight_msg_has_unique_id] (network.rs:514-522) is DERIVED from this
    one (network.rs:530) and is deliberately not a separate member: shipping both
    would double the per-state cost for zero discrimination. [interesting]
    requires [cardinal >= 2], i.e. two OCCURRENCES rather than two distinct
    messages ([cardinal] is Anvil [m.len()], multiset.mli:53-54), so it witnesses
    either conjunct doing work — two distinct messages make the uniqueness
    conjunct discriminating, one message present twice makes the no-replicas
    conjunct discriminating. *)

val family : Cluster.t -> controller_id:int -> Invariants.invariant list
(** [N1; N2; N3; N4; N5] in upstream order, the list a checker leg consumes.
    Takes the {!Cluster.t} that N4 needs; BUILD-SPEC-P14 section 4.2 sketched
    this as [controller_id]-only, which cannot type-check once N4 is faithful to
    upstream's [self.controller_models] premise. *)

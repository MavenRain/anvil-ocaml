(** BUILD-SPEC-P15: the RECONCILE-SIDE correspondence family — four Anvil
    [StatePred<ClusterState>]s whose guards live on the ongoing-reconcile side
    of the state, where every P14 member ({!Correspondence}) is guarded on the
    network side. Transcribed against the durable upstream checkout at
    [~/Documents/anvil-ref], not reconstructed from memory, so every [source]
    string is checkable:

    - R1 [pending_req_of_key_is_unique_with_unique_id]
      (kubernetes_cluster/proof/network.rs:104-117)
    - R2 [pending_req_in_flight_or_resp_in_flight_at_reconcile_state]
      (kubernetes_cluster/proof/controller_runtime_liveness.rs:131-145)
    - R3 [pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg]
      (controller_runtime_liveness.rs:147-168)
    - R4 [no_pending_req_msg_at_reconcile_state]
      (controller_runtime_liveness.rs:105-110)

    {b Why the guard's LOCATION is the phase's subject.} [restart_controller]
    (cluster.ml:291-324) empties [ongoing_reconciles] and leaves [s.network]
    untouched: the crash edge destroys every guard in THIS family while
    preserving every guard in P14's. BUILD-SPEC-P15 section 3's prediction
    P15-A: the unmutated crash edge refutes nothing here because at the crash
    instant all four members are vacuously true — crash sensitivity is
    determined by where a guard lives, not by what the invariant says.

    {b Universal closure over keys (disclosed strengthening).} Upstream states
    all four per-[key] (and proves them for arbitrary [key]). Every member
    here is shipped universally closed over ALL bound keys of
    [Cluster.ongoing_reconciles], so each is ONE {!Invariants.invariant}
    rather than one per key — strictly stronger than any single instantiation
    and the same treatment P14 gave N2/N3 (BUILD-SPEC-P15 section 2/R1).

    {b R3 is asserted STRONGER than upstream proves it.} Upstream's ensures
    for R3 is [true_pred().leads_to(always(lift_state(..)))]
    (controller_runtime_safety.rs:422), not [always]. Asserting R3 after every
    step is a deliberate bounded strengthening; a refutation near the seed is
    the leads-to shape appearing empirically and MUST NOT be reported as a
    port defect without inspecting the counterexample lasso (BUILD-SPEC-P15
    sections 2 and 8).

    {b R2/R4 are theorems only under side conditions.} Upstream proves R2
    [always] only for instantiations satisfying
    [state_comes_with_a_pending_request] (controller_runtime_safety.rs:100,
    defined :90-93) and R4 only under the dual (:507). Ship-and-measure at an
    instantiation violating its side condition and any refutation says nothing
    about the port. Validate with {!state_comes_with_a_pending_request} /
    {!state_comes_with_no_pending_request} BEFORE measuring, and derive the
    instantiation from the reconciler's step encoding rather than inventing it
    (BUILD-SPEC-P15 section 4.3).

    {b The two deliberately EXCLUDED lookalikes.}
    [pending_req_in_flight_at_reconcile_state]
    (controller_runtime_liveness.rs:112-120) and
    [resp_in_flight_matches_pending_req_at_reconcile_state] (:170-181) — and
    [req_msg_is_the_in_flight_pending_req_at_reconcile_state] (:122-129) with
    them — are NOT members: upstream never proves them [always]; they are
    leads-to TARGETS inside the liveness argument (:339-353). Shipping them in
    an always-suite would assert the controller is permanently mid-request,
    false the moment a reconcile ends. Excluding them is faithfulness, not
    scope-trimming (BUILD-SPEC-P15 section 2).

    {b Why this is a SEPARATE list and never appended to an existing one.}
    {!Invariants.always} and {!Vsts_invariants.always} feed [Cluster_check]
    and P13's G1 (fault_check.ml:318); {!Correspondence.family} feeds P14's
    G2. Appending would move those phases' committed pinned counts — and
    unioning with P14's family would MASK this phase's headline: under
    mutation MA, N1 fires one step before an rpc-id collision can form, so a
    combined leg would report N1 and never evaluate R3's exclusivity
    (BUILD-SPEC-P15 sections 3 and 4.2). Consumed only by its own checker leg.

    {b Honest limits.} Nothing here is proved. Upstream proves R1, R2, R4
    [always] and R3 [leads_to always] in Verus; every verdict this family
    produces is bounded falsification up to (depth, [Bound.t], fault budget)
    on one VRS scenario. A clean family under a fault budget is evidence about
    THIS bounded model, never a defect finding (or absolution) for Anvil's
    premises (BUILD-SPEC-P15 section 8). *)

val pending_req_of_key_is_unique_with_unique_id :
  controller_id:int -> Invariants.invariant
(** R1 (network.rs:104-117): if an ongoing reconcile holds a pending request,
    every OTHER ongoing reconcile's pending request carries a different
    [rpc_id]. Universally closed over all bound keys (see the module header);
    the upstream premises ([contains_key], [is Some], [key != other_key]) are
    rendered as [Object_ref_map.for_all] over bound keys, [Option.fold]
    [~none:true] legs, and a [Common.equal_object_ref] disjunct. It is here
    rather than in P14 because it is the declared premise of BOTH R3's
    upstream lemma (controller_runtime_safety.rs:417) AND R2's
    (controller_runtime_safety.rs:103), and belongs with the members it
    supports. [interesting] requires at least TWO ongoing reconciles both
    holding [Some] pending requests — with fewer, the inner quantifier ranges
    over nothing and R1 is vacuous, which is EXPECTED structurally at
    [desired = 1] and must be disclosed as such by the consuming leg
    (BUILD-SPEC-P15 sections 4.2 and 4.4). *)

val pending_req_in_flight_or_resp_in_flight_at_reconcile_state :
  controller_id:int -> expected:(Value.t -> bool) -> Invariants.invariant
(** R2 (controller_runtime_liveness.rs:131-145): at every ongoing reconcile
    whose [local_state] satisfies [expected] (upstream's
    [at_expected_reconcile_states], crl.rs:98-103), the reconcile has a
    pending REQUEST ([has_pending_req_msg], crl.rs:21-25 — [is Some] AND
    api-request-or-external-request content, the content conjunct being
    load-bearing), that request was sent by this controller with this key
    ([request_sent_by_controller_with_key], crl.rs:56-68), and the request or
    a matching response is in flight. [expected] is upstream's
    [current_state: spec_fn(ReconcileLocalState) -> bool] instantiation over
    the port's [Value.t] local state; it MUST be validated with
    {!state_comes_with_a_pending_request} before R2 is measured — an upstream
    theorem only under that side condition. [interesting] fires iff some bound
    key's local state satisfies [expected]. *)

val pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg :
  controller_id:int -> Invariants.invariant
(** R3 (controller_runtime_liveness.rs:147-168), the phase headline: for every
    ongoing reconcile holding a pending REQUEST, (provenance) the request was
    sent by this controller with this key, (existence) the request or a
    matching response is in flight, and (EXCLUSIVITY) never both. Exclusivity
    is the dimension no P14 member states: a response attributable to a
    request that is still outstanding — precisely what an rpc-id collision
    manufactures. Universally closed over keys. Asserted after EVERY step,
    which is STRONGER than upstream's [leads_to(always(..))] proof
    (controller_runtime_safety.rs:422) — see the module header before reading
    any refutation as a port bug. [interesting] fires iff some ongoing
    reconcile satisfies [has_pending_req_msg] (content conjunct included: a
    pending non-request would leave R3 vacuous and does not count as
    exercise). *)

val no_pending_req_msg_at_reconcile_state :
  controller_id:int -> expected:(Value.t -> bool) -> Invariants.invariant
(** R4 (controller_runtime_liveness.rs:105-110): at every ongoing reconcile
    whose [local_state] satisfies [expected], [pending_req_msg] is [None]
    ([no_pending_req_msg], crl.rs:31-33). R2's dual — same guard shape,
    pending-request polarity flipped — an upstream theorem only under the dual
    side condition (controller_runtime_safety.rs:507), validated by
    {!state_comes_with_no_pending_request}. [interesting] fires iff some bound
    key's local state satisfies [expected], at R4's OWN instantiation. *)

val state_comes_with_a_pending_request :
  Controller.reconcile_model ->
  expected:(Value.t -> bool) ->
  (Dynamic_object.t * Value.t Io.response_view option * Value.t) list ->
  bool
(** Executable rendering of upstream's R2 side condition
    [state_comes_with_a_pending_request] (controller_runtime_safety.rs:90-93):
    (init conjunct) no [expected] state is the reconciler's init state, and
    (transition conjunct) every transition landing in an [expected] state
    returned [Some] request. The triples are the leg's REACHABLE
    [(triggering_cr, resp_o, pre_state)] transition inputs.

    {b Disclosed bounded-vs-universal weakening (BUILD-SPEC-P15 section 4.3).}
    Upstream quantifies the transition conjunct over ALL
    [(cr, resp_o, pre_state)]; this check ranges only over the supplied
    reachable triples, so [true] means "no reachable counterexample to the
    side condition" — the same epistemic status as every other verdict in this
    port, never a proof of the side condition. The INIT conjunct is NOT
    bounded: upstream's [forall |s| state(s) ==> s != init()] is equivalent
    under value equality to [not (expected (init ()))], which is checked
    exactly. An empty triple list therefore validates only the init conjunct
    and must be reported as vacuous for the transition conjunct, not as a
    pass. *)

val state_comes_with_no_pending_request :
  Controller.reconcile_model ->
  expected:(Value.t -> bool) ->
  (Dynamic_object.t * Value.t Io.response_view option * Value.t) list ->
  bool
(** Executable rendering of upstream's R4 side condition — the dual premise of
    [lemma_always_no_pending_req_msg_at_reconcile_state]
    (controller_runtime_safety.rs:507): every transition landing in an
    [expected] state returned [None] for the request. Same bounded-quantifier
    weakening and reporting duty as {!state_comes_with_a_pending_request};
    upstream's dual has NO init conjunct ([no_pending_req_msg] holds trivially
    at reconcile start) and that asymmetry is preserved here, so an empty
    triple list validates NOTHING and must be reported as vacuous. *)

val family :
  controller_id:int ->
  pending_states:(Value.t -> bool) ->
  none_states:(Value.t -> bool) ->
  Invariants.invariant list
(** [R1; R2; R3; R4] in upstream order — the list the P15 checker leg
    consumes, and ONLY that leg: never append it to {!Invariants.always},
    {!Vsts_invariants.always} or {!Correspondence.family} (module header;
    BUILD-SPEC-P15 section 4.2). [pending_states] instantiates R2 and
    [none_states] instantiates R4; both must be DERIVED from the reconciler's
    step encoding and validated with their side-condition checkers before any
    measurement — if no non-vacuous instantiation exists, ship the leg with
    the empty instantiation recorded as a measured result rather than
    fabricating one (BUILD-SPEC-P15 section 4.3). *)

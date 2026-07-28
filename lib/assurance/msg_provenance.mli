(** P19 message-provenance (sender-tag) invariants (BUILD-SPEC-P19 §2): the
    E6-register message sibling
    [every_msg_from_vsts_controller_carries_vsts_key] of Anvil's
    [vstatefulset_controller/proof/helper_invariants.rs:1213] plus the three
    unshipped sender-classification always-members of
    [kubernetes_cluster/proof/network.rs] (:570 / :618 / :540), exposed as a
    named family for the P19 dedicated fault leg (the claim of the register
    P18's E6 guard reserved: "until a deliberate P19 port claims it",
    t_p18_regression's guard comment, re-scoped this phase per BUILD-SPEC-P19
    §6). Every [holds]/[interesting] is total, pure and exception-free; every
    match on a finite sum is exhaustive (no wildcard arm - upstream's
    [_ => false] arms are spelled out constructor by constructor).

    {b Projection.} All four members traverse
    [Message.Pool.distinct (Cluster.in_flight s)] - the [inv_self] projection
    precedent (vsts_invariants.ml:152). Every classifier is per-message, so
    multiplicity adds nothing to truth or to [interesting].

    {b CR-agnostic by design.} M1 needs [controller_id] only; M2-M4 are
    cluster-level (upstream states them on [Cluster] with no controller
    argument). No [~cr] is threaded - that would be unclaimed strength (the
    P18 residual-1 discipline).

    {b M1} [every_msg_from_vsts_controller_carries_vsts_key] (:1213-1222,
    lemma :1224-1260): every in-flight message whose [src] is
    [Controller (cid, key)] with [cid = controller_id] has
    [Common.equal_kind key.kind V_stateful_set.kind]; the four
    non-[Controller] arms are out of premise ([true]). Notes, each
    deliberate:

    - {b NAME-COLLISION DISCLOSURE (E2', armed)}:
      [internal_rely_guarantee.rs:528-540] defines a semantic duplicate
      under the SAME upstream name (bridged in [liveness/proof.rs:903-926]).
      This family cites [helper_invariants.rs:1213] ONLY; the [source]
      string is the pin (BUILD-SPEC-P19 §3 E2').
    - {b MODEL-CONDITIONAL}: the upstream lemma requires
      [controller_models.contains_pair(controller_id,
      vsts_controller_model())] (:1231); on a non-vsts spine M1 is NOT
      claimed. The orphan replica (BUILD-SPEC-P19 §4) measures M1 there as
      a live RED CONTROL - the generic spine stamps
      [Controller (controller_id, vrs-kind key)] messages - and never
      asserts it as an invariant (spec §8.5).
    - {b Register distinctness from [inv_self]} (the apparent-overlap trap
      that motivated P18's E6 exclusion): [inv_self] filters by EXACT src
      equality [Controller (controller_id, vsts_ref)] and then constrains
      the PAYLOAD (vsts_invariants.ml:153-155, :214-232); M1 quantifies
      over ANY [cr_key] carrying the matching id and constrains only the
      TAG's kind. A message from [Controller (controller_id, wrong-key)]
      passes [inv_self] silently and is exactly what M1 polices.

    {b M2} [all_requests_from_pod_monkey_are_api_pod_requests] (:570-587,
    lemma :589): every in-flight message with [src] [Pod_monkey] has [dst]
    [Api_server], content [Api_request r], and [r] in one of the four
    pod-keyed write arms ([Create_request] / [Update_request] /
    [Update_status_request] / [Delete_request], each with key kind
    [Pod.kind]); the five remaining arms ([Get_request], [List_request],
    [Get_then_delete_request], [Get_then_update_request],
    [Get_then_update_status_request]) are upstream's [_ => false] at :583
    spelled out. Notes:

    - {b PER-ARM KEY-READ DISCLOSURE (B1-measured)}: upstream reads the
      uniform [req.key().kind]; the port exports PER-REQUEST key
      projections and no sum-level [key ()] (api_method.mli:103-137).
      Update / Update_status / Delete read [(update_request_key r).kind] /
      [(update_status_request_key r).kind] / [(delete_request_key r).kind]
      - each exactly the upstream key construction; Create reads
      [Dynamic_object.kind r.obj] directly, because [create_request_key]
      is [Res.t]-typed (partial on a missing metadata name,
      api_method.mli:137-139) and a total, exception-free classifier must
      not consume it - the kind component it would carry is [obj.kind]
      verbatim, so the direct read loses nothing.
    - {b Emergent green}: the shipped monkey's live repertoire is exactly
      the four permitted arms, all pod-keyed (pod_monkey.ml:58-116, req-msg
      constructions at :66/:81/:97/:113), so M2's green on live graphs is
      EMERGENT. Red capability, as MEASURED this phase (BUILD-SPEC-P19 §7):
      the forge battery, AND the MN1' row - a suppressed src/dst swap in
      [form_create_resp_msg] (message.ml:208) reddens M2 on the Lm leg and
      on the orphan replica (111 states), forge-free, because a create
      RESPONSE then inherits [src Pod_monkey] and [api_request_of] is
      [None] on a response, so the [Option.fold ~none:false] rejects
      (t_p19_mutation.ml:142-178). The ML1 attribution flip leaves M2
      GREEN - it moves the message OUT of M2's premise and reddens M3, not
      M2 (spec §7's ML1 row).

    {b M3} [all_requests_from_builtin_controllers_are_api_delete_requests]
    (:618-628, lemma :630): every in-flight message with [src]
    [Builtin_controller] has [dst] [Api_server] and content
    [Api_request (Delete_request _)]. Notes:

    - {b STRICT-DELETE reading}: upstream's [content.is_delete_request()]
      is macro-generated over strictly [DeleteRequest] (the invocation
      spans spec/message.rs:321-326), so [Get_then_delete_request] is NOT
      a delete here - the accepting arm is [Delete_request] alone, the
      other eight arms [false], no wildcard.
    - {b SEMANTIC-OVERLAP DISCLOSURE (shipped [inv7])}: the (name, source)
      firewall is SYNTACTIC, so it does not mean M3's substance is
      unasserted elsewhere. Shipped
      [garbage_collector_does_not_delete_vrs_pods]
      ([Invariants.eventually_always]'s inv7, invariants.ml:527-546, source
      [vreplicaset_controller/proof/helper_invariants/predicate.rs:316])
      already forces a DELETE on the {builtin src, api-server dst, api
      request} intersection - its [gc_ok] returns [false] on all eight
      non-[Delete_request] arms (invariants.ml:522-525) - with extra uid
      and owner-ref preconditions on top. M3 is still distinct: it also
      covers builtin-sourced messages with [dst] other than [Api_server]
      and with NON-request content, where inv7's guard is vacuously true;
      and it carries none of inv7's uid preconditions. The mirror of the
      M1-vs-[inv_self] note above.
    - {b Predicted vacuity + the orphan floor}: the port GC emits exactly
      this shape (builtin_controllers.ml:101-103), but no vsts-spine graph
      fires the builtin (the seeded CR is never deleted; vsts pods carry
      live owner refs - BUILD-SPEC-P19 §5 prediction 3), so M3's
      [interesting] count 0 on all four legs is an honest N5-style
      negative. The non-vacuity floor is the ORPHAN REPLICA (spec §4),
      where the GC actually fires.

    {b M4} [no_pending_request_to_api_server_from_api_server_or_external]
    (:540-549, lemma :551): NO in-flight message has ([src] [Api_server]
    or [External _]) AND [dst] [Api_server] AND content [Api_request _] -
    a negative universal, rendered as
    [List.for_all (fun m -> not (in_scope_src m && dst_api m && is_req m))].
    Notes:

    - {b DISCLOSED DEVIATION - violation-shaped [interesting]}: for a
      negative universal the premise IS the violation, so [interesting] is
      deliberately SOURCE-IN-SCOPE only (some in-flight message has [src]
      [Api_server] or [External _]): API responses make it fire on every
      post-first-response state - the non-vacuity reading is "the
      classifier actually inspected an in-scope message", never a
      near-violation count.
    - {b External-arm inertness (measured this phase)}: both shipped
      spines install [external_model = None] (scenario.ml:62 / :296), so
      [Step.External_step] is never enabled and no message with [src]
      [External _] exists on any live graph - the arm is structurally
      unexercised outside the forge battery; forge F-M4b is its only red
      witness (BUILD-SPEC-P19 §8.4). The arm is NOT narrowed.

    {b Classification firewall.} All four (name, source) pairs are new and
    distinct by exact string from every shipped pair (P14 cites
    network.rs:35/:76/:254/:312/:382 - E1' pins the :312 valid-id conjunct
    as ALREADY SHIPPED there, P14 N4 - and P18 cites
    helper_invariants.rs:52/:1063); [t_p19_regression] sweeps the family
    against ALL shipped suites via [Pair_guard.pair_leaks], both
    directions. *)

val provenance_sources : string list
(** The four upstream [source] strings, in member order M1-M4
    (["vstatefulset_controller/proof/helper_invariants.rs:1213"];
    ["kubernetes_cluster/proof/network.rs:570"]; [":618"]; [":540"]) -
    exposed so the P19 regression can pin the (name, source) DISJOINTNESS
    firewall without restating the literals. *)

val provenance_family : controller_id:int -> Invariants.invariant list
(** The M1/M2/M3/M4 records, in that order (expected cardinal 4; pinned by
    t_p19_regression, not asserted here - no-exception house rule).
    [controller_id] is consumed by M1 alone; M2-M4 are cluster-level
    (upstream states them on [Cluster] with no controller argument), and no
    [~cr] is threaded - the module doc's unclaimed-strength note. Each
    member's [interesting] is its own premise mirror (P14 N3 - no
    borrowing): M1 a controller-tagged message with the matching id, M2 a
    monkey-sourced message, M3 a builtin-sourced message, M4 an in-scope
    source - with M4's violation-shaped deviation disclosed in the module
    doc. *)

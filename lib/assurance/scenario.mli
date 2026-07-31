(** The canonical VReplicaSet reconcile scenario, shared by the P4 property
    harness and (later) the P5 bounded model checker so both assurance legs
    exercise the SAME system.

    A {!Cluster.t} running exactly the vreplicaset controller at {!controller_id},
    plus a reachable {e seed} {!Cluster.cluster_state} in which the custom resource
    is already stored in etcd — Anvil's [desired_state_is] antecedent
    (kubernetes_cluster/spec/esr.rs). Reusable, deterministic, no randomness (the
    QCheck sampling lives in [test/]). *)

val controller_id : int
(** The single controller id ([0]) the vreplicaset reconciler is installed under. *)

val kind : Common.kind
(** The VReplicaSet kind, [Custom_resource "vreplicaset"] (= {!Vreplica_set.kind}). *)

val cluster : Cluster.t
(** The static cluster parameters: [installed_types] that validate the vreplicaset
    kind (and admit its pods), and a single {!Cluster.controller_model} = the
    {!Vreplica_set_pack} controller at {!controller_id}, with no external system.
    Anvil [Cluster] (cluster.rs:92). *)

val vrs : desired:int -> Vreplica_set.t
(** A well-formed VReplicaSet named [vrs1] in namespace [ns] with uid [1], exactly
    one controller owner reference, [desired] replicas, and a selector ([app=x]) and
    pod template. Satisfies {!Vreplica_set.state_validation}; [controller_owner_ref]
    is [Some]. This is the object {!seed} stores in etcd. *)

val vrs_ref : Common.object_ref
(** The CR key [{ kind = ]{!kind}[; name = "vrs1"; namespace = "ns" }]. *)

val vd : desired:int -> V_deployment.t
(** A well-formed VDeployment named [vd1] in namespace [ns] with uid [1],
    resource_version [0], [desired] replicas, and the shared [app=x] selector and
    matching pod template (the same {!vrs} builders), so
    {!V_deployment.state_validation} holds. Seeded by the P9 two-controller exec
    witness; additive to the vrs-only {!cluster}. *)

val vd_ref : Common.object_ref
(** The VDeployment CR key
    [{ kind = ]{!V_deployment.kind}[; name = "vd1"; namespace = "ns" }]. *)

val vd_and_vrs_installed : Api_server.installed_types
(** A multi-kind {!Api_server.installed_types} admitting BOTH the vreplicaset and
    vdeployment custom resources (and pods). Predicates are permissive; only
    [marshalled_default_status] dispatches by {!Common.kind} (exhaustively):
    vreplicaset gives the vrs default status, vdeployment the empty vdeployment
    status ([`Null]), and every builtin kind a [`Null] default. Used by the P9
    two-controller convergence witness; the vrs-only {!cluster} is untouched. *)

val vsts : desired:int -> ?vct:bool -> unit -> V_stateful_set.t
(** A well-formed VStatefulSet named [vsts1] in namespace [ns] with uid [1],
    resource_version [0], a non-empty [service_name], [desired] replicas, and the
    shared [app=x] selector and matching pod template (the same {!vrs} builders),
    so {!V_stateful_set.state_validation} holds and [controller_owner_ref] is
    [Some]. With [~vct:true] the spec carries exactly one volumeClaimTemplate (a
    dash-free-named PVC in [ns] with a [Some] spec, which the reconciler's
    [make_pvcs] specialises per ordinal); [~vct:false] (the default) omits it.
    Seeded by the P10 VStatefulSet witness; additive to the vrs-only
    {!cluster}. *)

val vsts_named : name:string -> ?vct:bool -> desired:int -> unit -> V_stateful_set.t
(** {!vsts} with a parameterized metadata [name] and [service_name] (both = [name]);
    the per-CR builder behind {!vsts_seed_multi}. Reuses the {!vsts} metadata base and
    overrides only the name, so [vsts_named ~name:"vsts1" ~vct ~desired ()] is
    byte-identical to [vsts ~desired ?vct ()] — [vsts] is now a thin delegation. *)

val vsts_ref : Common.object_ref
(** The VStatefulSet CR key
    [{ kind = ]{!V_stateful_set.kind}[; name = "vsts1"; namespace = "ns" }]. *)

val vsts_installed : Api_server.installed_types
(** A multi-kind {!Api_server.installed_types} admitting the vstatefulset custom
    resource (and the Pods / PersistentVolumeClaims it manages). Predicates are
    permissive; only [marshalled_default_status] dispatches by {!Common.kind}
    (exhaustively): vstatefulset gives the VSS default status (the [ready_replicas]
    status, [{ "readyReplicas": null }]) and every other kind a [`Null] default.
    Used by the P10 VStatefulSet witness; the vrs-only {!cluster} is untouched. *)

val vsts_cluster : Cluster.t
(** The runnable VSTS cluster: [installed_types = ]{!vsts_installed} (admits the
    VStatefulSet CR + Pod + PVC; [marshalled_default_status] already dispatches
    exhaustively over {!Common.kind}), controller registry = the
    {!V_stateful_set_pack} controller at {!controller_id}. Built EXACTLY as the
    internal VRS {!cluster} but with the VSTS pack + installed types. The
    [Cluster.t] the VSTS BMC/ESR legs explore, and the argument the VSTS legs pass
    to {!productive_successors} / {!Cluster_check.settled}. *)

val vsts_seed_faults :
  desired:int ->
  crash:bool ->
  req_drop:bool ->
  pod_monkey:bool ->
  ?vct:bool ->
  unit ->
  Cluster.cluster_state
(** {!vsts_seed} with the three disruptor toggles set INDEPENDENTLY: [crash] is
    the {!controller_id} entry's [crash_enabled] (Anvil's [RestartController]
    fault, cluster.rs:377), [req_drop] the api-server transient-failure switch
    (Anvil's [DropReq], cluster.rs:439) and [pod_monkey] the pod disruptor
    (cluster.rs:492). The CR is still admitted through a REAL
    {!Api_server.handle_create_request} (uid/resource_version server-stamped,
    never forged) against a fresh empty api-server, so the reachable
    uid/rv/counter shape is exactly {!vsts_seed}'s. Introduced by P13 to isolate
    ONE fault dimension at a time.

    {b Reachability / soundness (BUILD-SPEC-P13 §3).} {!Cluster.init}
    (cluster.rs:110, [lib/cluster/cluster.ml:75-97]) REQUIRES all three flags
    TRUE, so a seed with any flag [false] is NOT an init state. Exploring from it
    is nonetheless SOUND: every flag combination componentwise <=
    [(true, true, true)] is reachable from an init state by a prefix of
    [Step.Disable_crash_step] / [Disable_req_drop_step] /
    [Disable_pod_monkey_step], each of which flips only its own flag
    (cluster.rs:407, :472, :526 =
    [lib/cluster/cluster.ml:337], [:385], [:445]). So a safety violation found
    from such a seed is a genuine violation of a REACHABLE behaviour, and a clean
    verdict is falsification-up-to-bounds of the SUFFIX behaviours starting
    there. The pre-existing [~fair:true] seeds already rest on precisely this
    argument (they are the all-disabled suffix).

    {b MEASURED correction to BUILD-SPEC-P13 §3.} The spec asserts that the
    all-faults-ON seed [~crash:true ~req_drop:true ~pod_monkey:true] "is the
    FIRST seed in the repo that satisfies [Cluster.init] outright". That is FALSE
    as measured: [Cluster.init vsts_cluster (vsts_seed_faults ~desired:1
    ~crash:true ~req_drop:true ~pod_monkey:true) = false]. The all-ON seed does
    satisfy every FAULT-FLAG conjunct of [Cluster.init], which is the
    load-bearing part, but the remaining
    [Api_server.init] conjunct demands an EMPTY etcd
    ([lib/cluster/api_server.ml:73], [Object_ref_map.is_empty resources]) while
    the seed already holds the server-created CR ([etcd_cardinal = 1]). Isolated
    by measurement: the same state with an empty etcd - and nothing else changed
    - gives [Cluster.init = true], so the non-empty etcd is the ONLY failing
    conjunct.

    {b SECOND correction (review stage).} An earlier draft of this note added
    that the all-ON seed is the FIRST seed in the repo to satisfy the fault-flag
    conjuncts. That is also false and has been removed: {!vsts_seed} with
    [~fair:false] delegates to the identical [vsts_seed_faults ~crash:true
    ~req_drop:true ~pod_monkey:true] call ([lib/assurance/scenario.ml:380-382]),
    so it IS this seed by value, and it is live pre-P13 at
    [lib/checker/cluster_check.ml:503] (as is the VRS {!seed} [~fair:false] at
    [:365]). No test compares seeds, so that clause could never have reddened.
    Soundness is unaffected: the already-created CR rests on the SAME standing
    argument every seed in this module rests on (a client created the CR before
    the reconcile starts, see {!seed}), and the flag prefix argument above covers
    the fault dimension.

    {b [?vct] (P16, BUILD-SPEC-P16 section 4.3).} Threads to the {!vsts} CR
    builder: [~vct:true] seeds a CR carrying a volumeClaimTemplate, which is
    what makes the VSTS reconciler's PVC arm - and hence any [Get_request] at
    all - reachable (v_stateful_set_reconciler.ml:580, :603-611; the pod
    create is NOT vct-gated). DEFAULT [false]: every pre-P16 call site
    produces a BYTE-IDENTICAL seed value, so P13's 464/152/388/76, P14's
    76/32 and 464/296 and P15's 76/64 and 464/304/388/76 pins all flow
    through unchanged. A [~vct:true] seed is a DIFFERENT scenario and its
    counts are NOT comparable with those pins (BUILD-SPEC-P16 section 8.6).
    The trailing [unit] exists because OCaml cannot erase an optional
    argument followed only by labelled ones (warning 16, measured): total
    labelled application without a positional argument after [?vct] does not
    default it, so the spec's alternative leading position does not
    compile. *)

val vsts_seed : desired:int -> fair:bool -> Cluster.cluster_state
(** Mirror of {!seed} for VSTS: the {!vsts} CR ([Scenario.vsts ~desired], default
    [?vct:false]) created into etcd by a REAL {!Api_server.handle_create_request}
    against a fresh empty api-server, so its uid/resource_version are STAMPED by the
    create (never forged into metadata) and the api-server counters advance strictly
    past them — the same reachable uid/rv/counter shape {!seed} carries. The VSTS
    controller is scheduled at {!controller_id} ([Controller.init] reconcile state);
    disruptors gated by [fair] ([false] = full nondeterminism for safety; [true] =
    the fair suffix for ESR). Since P13 a thin delegation to
    [{!vsts_seed_faults} ~desired ~crash:(not fair) ~req_drop:(not fair)
    ~pod_monkey:(not fair) ()] (default [?vct:false]), so behaviour is
    unchanged; see {!vsts_seed_faults}
    for the reachability argument that licenses a [~fair:true] (all-disabled,
    hence non-{!Cluster.init}) seed. *)

val vsts_seed_with_pods :
  desired:int ->
  ordinals:int list ->
  crash:bool ->
  req_drop:bool ->
  pod_monkey:bool ->
  ?vct:bool ->
  unit ->
  Cluster.cluster_state
(** {!vsts_seed_faults} plus one hand-built surplus Pod per element of
    [ordinals]: the first G2-live (condemned-exercising) VSTS seed
    (BUILD-SPEC-P22 section 2). Chains REAL {!Api_server.handle_create_request}
    calls against a fresh empty api-server ([uid_counter = 1]): first the
    {!vsts}[ ~desired] CR exactly as {!vsts_seed_faults} admits it (uid 1
    server-stamped), then, folded over [ordinals], one Pod named
    [V_stateful_set_reconciler.pod_name parent ord]
    (["vstatefulset-vsts1-<ord>"]) in ["ns"] whose sole owner reference is the
    LIVE CR's controller owner ref - read back from etcd at {!vsts_ref},
    unmarshalled, and passed through [V_stateful_set.controller_owner_ref], so
    its uid is the server-stamped 1 by construction, never forged. That SAME
    single read supplies [parent]: the ref's [name] field IS the live CR's
    [metadata.name] (v_stateful_set.ml:173-184), so the pod name cannot drift
    from the CR the reconciler reads - there is no ["vsts1"] literal in the
    seed. Every create response is DISCARDED by design: this is seed
    construction, not protocol - uid/rv stamping is the server's, and seed
    integrity is asserted by {!vsts_seed_pods_intact} (and the P22 seed test
    through it), not inferred from responses. The create path
    VALIDATES but does not strip the owner ref ([metadata_validity_check],
    api_server.ml:90-97: Invalid iff MORE than one ref; ours has exactly one).

    {b PRECONDITION - the CALLER's obligation, checkable by
    {!vsts_seed_pods_intact} (P22 review finding F3).} [ordinals] must be
    {b DISTINCT} and each element {b >= [desired]}. This builder DEGRADES
    SILENTLY otherwise, and the degraded seed is indistinguishable from a good
    one at the report level: a REPEATED ordinal makes the second
    {!Api_server.handle_create_request} an [Object_already_exists] no-op that
    returns the state UNCHANGED (api_server.ml), and the fold discards that
    response, so a requested surplus pod is simply missing; an ordinal
    [< desired] is never condemned. Either way [partition_pods] yields
    [condemned = []], the G2-live [Get_then_delete_request] is never emitted,
    G2's per-member [interesting] is 0 - and the leg STILL reports outcome
    CLEAN with a non-zero [gate_states], because that union gate is DOMINATED
    BY G1 (the disclosure recorded on
    [Fault_check.check_scale_down_under_faults], lib/checker/fault_check.mli).
    That is
    precisely P21's G2 vacuity returning under a green verdict, which is the
    one outcome this seed exists to eliminate. If the CR read that supplies the
    owner ref should ever fail (unreachable: the CR create succeeds by
    construction), NO pod is created at all rather than an unowned one, so the
    predicate reds instead of the leg going quietly vacuous.

    {b Why the pod is condemned-by-construction.} [partition_pods]
    ([lib/controllers/v_stateful_set_reconciler.ml:399-416], upstream
    model/reconciler.rs:641-654) puts EVERY owned, canonically-named pod whose
    parsed ordinal is [>= replicas] into [condemned] (descending). The seeded
    pod passes [pod_filter] ([:421-432]) by construction - it carries exactly
    the CR's controller owner ref and its name round-trips through
    [get_ordinal] - so each [ord >= desired] in [ordinals] lands in
    [condemned] and the reconcile's Delete_condemned arm ([:716-747]) fires
    the G2-live [Get_then_delete_request]. A mismatched owner-ref uid would
    instead make the pod GC-orphaned ([Builtin_controllers.object_is_orphaned]
    shape, builtin_controllers.ml:64-81) and silently reproduce the exact G2
    vacuity this seed exists to remove.

    This is a scale-down RESIDUE, not a scale-down EDGE (BUILD-SPEC-P22
    section 7): no step mutates a live CR's spec, so the seed hand-builds the
    post-scale-down state (desired + surplus ordinals) - exactly the state
    shape upstream's condemned logic quantifies over. Fault toggles and [?vct]
    exactly as {!vsts_seed_faults}, whose BUILD-SPEC-P13 §3 reachability
    argument covers the flag dimension; the pod creates rest on the same
    standing "a client created it first" argument as every seeded CR here. *)

val vsts_seed_pods_intact : Cluster.cluster_state -> ordinals:int list -> bool
(** The seed-integrity obligation of {!vsts_seed_with_pods} as a TOTAL
    predicate (P22 review finding F3): [true] iff the state actually carries,
    for every requested ordinal, a pod that [pod_filter]
    ([lib/controllers/v_stateful_set_reconciler.ml:421-432]) will ADMIT and
    [partition_pods] ([:399-416]) can therefore condemn. Conjunct by conjunct:

    - [ordinals] are pairwise DISTINCT (a repeat is the silent-drop path: the
      second create is an [Object_already_exists] no-op and one requested
      surplus pod never exists, though every remaining conjunct still passes);
    - the CR is present at {!vsts_ref}, unmarshals as a {!V_stateful_set.t},
      and its metadata carries a name, a namespace and a uid;
    - the CR's replica count - read the reconciler's OWN way, [None] meaning 1
      ([lib/controllers/v_stateful_set_reconciler.ml:545-548]) - is
      NON-NEGATIVE (a negative count sends the reconcile to [error_state]
      before [partition_pods] ever runs, so nothing is condemned);
    - for EVERY [ord] in [ordinals]: [ord >= replicas], since [partition_pods]
      condemns only those ([:412]) and a SMALLER ordinal is [needed] instead -
      this is the [< desired] half of {!vsts_seed_with_pods}'s precondition,
      CHECKED here rather than assumed; the pod is PRESENT at its canonical ref
      ([Pod.kind], the CR's namespace, [V_stateful_set_reconciler.pod_name
      parent ord]); its [owner_references] holds EXACTLY ONE reference; that
      reference matches the CR's controller owner ref on EVERY field
      [Owner_reference.equal] compares ([owner_reference.ml:26-33]) - uid EQUAL
      to the uid stored on the LIVE CR in this same state (read off the state,
      never the literal 1 - the api-server stamps it, and a mismatch is
      precisely the GC-orphan shape, builtin_controllers.ml:64-81), plus
      [name = parent], [kind = V_stateful_set.kind] and
      [controller = block_owner_deletion = Some true], because [pod_filter]
      admits through [Object_meta.owner_references_contains]
      ([object_meta.ml:72-75]) - full-reference equality, NOT uid alone, so a
      uid-only check would pass a pod the reconciler silently drops; and the
      pod's name ROUND-TRIPS through
      [V_stateful_set_reconciler.get_ordinal parent] back to [ord].

    Parent name, namespace, uid and replica count are read from the live CR's
    own metadata/spec, not from [V_stateful_set.controller_owner_ref], so the
    check does not reuse the builder's derivation. Total and combinator-only
    ([Option.fold]/[Result.fold]/[List.for_all]): no exception, no partial
    accessor, no [Bound]/depth/exploration cost - it is a pure read of the
    seed.

    {b What a [false] means.} The leg about to be run is G2-VACUOUS and will
    still report CLEAN: the pod is dropped by [pod_filter], [condemned] is
    empty, no [Get_then_delete_request] is emitted, G2's [interesting] is 0,
    and the union [gate_states] stays non-zero because it is dominated by G1
    (the disclosure on [Fault_check.check_scale_down_under_faults],
    lib/checker/fault_check.mli). Callers of {!vsts_seed_with_pods} (and of
    [Fault_check.check_scale_down_under_faults], which forwards [~ordinals]
    unchecked) discharge that precondition with this predicate;
    t_p22_scaledown asserts it for the shipped instantiation
    [~desired:1 ~ordinals:[1]] and exercises its RED capability (absent pod,
    doctored owner uid, emptied owner-ref list). *)

val vsts_seed_multi_faults :
  desireds:int list ->
  crash:bool ->
  req_drop:bool ->
  pod_monkey:bool ->
  Cluster.cluster_state
(** {!vsts_seed_multi} with the three disruptor toggles set INDEPENDENTLY, exactly
    as {!vsts_seed_faults} does for {!vsts_seed}: one VStatefulSet [vstsN] per
    element of [desireds], each admitted through a real
    {!Api_server.handle_create_request} (uid/rv server-stamped, distinct
    {!Object_ref_map} keys), all under the single {!controller_id}. The P13 seed
    for the crash-strengthened concurrent-reconcile witness ([cardinal(ongoing) >=
    2] reached AFTER a crash). The BUILD-SPEC-P13 §3 reachability argument
    recorded on {!vsts_seed_faults} applies verbatim: any flag combination
    componentwise <= [(true, true, true)] is the suffix of an init behaviour after
    a prefix of the three flag-flipping [Disable_*] steps (cluster.rs:407, :472,
    :526), so violations found here are genuine and clean verdicts are
    falsification-up-to-bounds of those suffixes. *)

val vsts_seed_multi : desireds:int list -> fair:bool -> Cluster.cluster_state
(** A multi-CR VSTS seed: one VStatefulSet [vstsN] per element of [desireds], each
    created through a real {!Api_server.handle_create_request} (uid/rv server-stamped,
    distinct keys), all under the single {!controller_id}. Unlike {!vsts_seed} (one CR
    => [ongoing_reconciles] never holds >= 2 => inv6 vacuous), a >= 2-element
    [desireds] lets the reachable graph reach [cardinal(ongoing) >= 2], the
    non-vacuity witness for {!Invariants.unique_reconcile_id_invariant}. The VSTS
    analogue of {!seed_multi}. [~fair] as in {!vsts_seed}. Since P13 a thin
    delegation to [{!vsts_seed_multi_faults} ~desireds ~crash:(not fair)
    ~req_drop:(not fair) ~pod_monkey:(not fair)], so behaviour is unchanged. *)

val seed : desired:int -> fair:bool -> Cluster.cluster_state
(** A reachable initial cluster state: the {!Cluster.init} shape (empty controller
    reconcile state, fresh rpc allocator) but with {!vrs}[ ~desired] already stored
    in etcd under {!vrs_ref}, its uid/resource_version freshly issued and the
    api-server [uid_counter] / [resource_version_counter] advanced STRICTLY past
    them (so {!Invariants} #2's [< counter] bounds hold). Models a client having
    created the CR before the reconcile starts.

    This is NOT a {!Cluster.init} state (etcd is non-empty); it is a reachable
    successor of one, and every safety invariant holds here.

    [~fair:true] disables the three liveness toggles ([crash_enabled],
    [req_drop_enabled], [pod_monkey_enabled] all [false]) — the fair suffix Anvil's
    liveness proof assumes, used to drive toward a quiescent state for the liveness
    goal ({!Invariants.liveness_goal}). [~fair:false] leaves them enabled (full
    nondeterminism, including request drops / pod-monkey / crashes): the
    safety-invariant properties must hold under these too. *)

val seed_multi : desireds:int list -> fair:bool -> Cluster.cluster_state
(** A reachable state with one VReplicaSet CR per element of [desireds] — keys
    [vrs1], [vrs2], ... with distinct names, uids [1 .. List.length desireds] and
    distinct resource_versions [0 .. List.length desireds - 1], each getting that
    element's replica count — all stored in etcd, the api-server counters
    ([uid_counter], [resource_version_counter = List.length desireds]) advanced
    strictly past every uid/rv so every stored object is freshly issued. [seed_multi
    ~desireds:[d]] coincides with {!seed}[ ~desired:d].

    Widens the single-CR {!seed} so that >= 2 concurrent ongoing reconciles
    become reachable, de-vacuising {!Invariants} #6
    [every_ongoing_reconcile_has_unique_id] (whose [interesting] precondition is
    [>= 2] entries in the ongoing-reconcile map). Every ALWAYS safety invariant
    holds in this state. [~fair] as in {!seed}. *)

val seed_with_pods :
  desired:int -> existing:int -> fair:bool -> Cluster.cluster_state
(** A reachable state: {!vrs}[ ~desired] plus [existing] pods it already owns,
    all stored in etcd. Each pod carries the vrs controller owner reference
    (= [Vreplica_set.controller_owner_ref (]{!vrs}[ ~desired)]), selector-matching
    [app=x] labels, a [vreplicaset-vrs1-]-prefixed name, no deletion timestamp,
    and a fresh uid ([2 .. existing+1], the CR being uid 1) and a distinct fresh
    resource_version ([1 .. existing], the CR being rv 0), both strictly below the
    advanced counters ([resource_version_counter = existing+1]).

    Widens {!seed} so [After_list_pods] returns a non-empty list and the
    reconcile records [filtered_pods = Some (_ :: _)], de-vacuising
    {!Invariants} #15 [filtered_pods_invariant_matrix] and #16
    [local_pods_are_bound_to_vrs_with_key] (whose [interesting] precondition is a
    non-empty [filtered_pods]). When [existing > desired] the scale-DOWN
    [After_delete_pod] path is also exercised. Every ALWAYS safety invariant
    holds here. [~fair] as in {!seed}. *)

val seed_with_orphan : desired:int -> fair:bool -> Cluster.cluster_state
(** A reachable state: {!vrs}[ ~desired] plus one orphan pod whose sole
    (controller) owner reference points to a vreplicaset uid that is absent from
    etcd. Because every owner reference is [owner_gone], the built-in garbage
    collector's precondition ([Builtin_controllers.object_is_orphaned]) holds and
    a productive [Builtin_controllers_step] issues a delete request for the
    orphan. The orphan is uid 2 / rv 1 (the CR being uid 1 / rv 0), each rv
    distinct and strictly below the counters ([resource_version_counter = 2]) so
    both stored objects are freshly issued,
    and its ghost owner ref is not the vrs controller owner ref (so #7's
    [contains_co] guard stays false and the invariant is non-vacuously true).

    Widens {!seed} so an in-flight BuiltinController delete on a pod becomes
    reachable, de-vacuising {!Invariants} #7
    [garbage_collector_does_not_delete_vrs_pods] (whose [interesting] precondition
    is exactly such a message). Every ALWAYS safety invariant holds here. [~fair]
    as in {!seed}. *)

val productive_successors :
  Cluster.t ->
  Bound.t ->
  Cluster.cluster_state ->
  (Step.t * Cluster.cluster_state) list
(** {!Cluster.enabled_successors}[ b t s] over the GIVEN installed cluster [t],
    keeping only the productive step families — [Api_server_step (Some _)],
    [Builtin_controllers_step _], [Controller_step _],
    [Schedule_controller_reconcile_step _], [Pod_monkey_step _], [External_step _]
    — and dropping the no-op / failure / liveness-toggle steps
    ([Api_server_step None], [Restart_controller_step], [Disable_crash_step],
    [Drop_req_step], [Disable_req_drop_step], [Disable_pod_monkey_step],
    [Stutter_step]). The {!Step.t} match is exhaustive (no wildcard). The VRS legs
    pass {!cluster} (behaviour identical to the former [Cluster.t]-free form); the
    VSTS legs pass {!vsts_cluster}. *)

val is_quiescent : Bound.t -> Cluster.cluster_state -> bool
(** [productive_successors b s = []]: no api-server / controller / gc / schedule /
    pod-monkey step can still change the state. The ONLY states at which the
    liveness goal {!Invariants.liveness_goal} is expected to hold ([current_state_
    matches] is a [leads_to] target, false on transient states by design; digest). *)

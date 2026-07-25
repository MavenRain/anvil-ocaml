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
  Bound.t -> Cluster.cluster_state -> (Step.t * Cluster.cluster_state) list
(** {!Cluster.enabled_successors}[ b ]{!cluster}[ s] keeping only the productive
    step families — [Api_server_step (Some _)], [Builtin_controllers_step _],
    [Controller_step _], [Schedule_controller_reconcile_step _], [Pod_monkey_step _],
    [External_step _] — and dropping the no-op / failure / liveness-toggle steps
    ([Api_server_step None], [Restart_controller_step], [Disable_crash_step],
    [Drop_req_step], [Disable_req_drop_step], [Disable_pod_monkey_step],
    [Stutter_step]). The {!Step.t} match is exhaustive (no wildcard). *)

val is_quiescent : Bound.t -> Cluster.cluster_state -> bool
(** [productive_successors b s = []]: no api-server / controller / gc / schedule /
    pod-monkey step can still change the state. The ONLY states at which the
    liveness goal {!Invariants.liveness_goal} is expected to hold ([current_state_
    matches] is a [leads_to] target, false on transient states by design; digest). *)

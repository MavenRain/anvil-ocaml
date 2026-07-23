(** Anvil source: kubernetes_cluster/spec/cluster.rs ([ClusterState],
    [ControllerAndExternalState], [Cluster], [ControllerModel], [Cluster::init],
    [Cluster::next_step] and the twelve host actions).

    The compound cluster transition system: the top-level state machine that
    interleaves the six host machines (api server, builtin controllers /
    garbage collector, controller, external system, pod monkey, network) over a
    shared {!cluster_state}. Anvil's [next] is [exists step, next_step(s, s',
    step)]; the Hilbert existential does not port, so {!next_step} is exposed as
    the executable {e relation} and {!enabled_successors} as the [choose]-free,
    {!Bound.t}-bounded successor enumeration (architecture finding 14).

    Every message-carrying host action is the Anvil "network-baked-in"
    composition (architecture finding 8): the host machine's result AND
    {!Network.deliver}'s result, both required [Enabled], updating the host
    sub-state, the network, and (controller / gc / pod-monkey) the shared
    [rpc_id_allocator] together. *)

type controller_and_external = {
  controller : Controller.state;
  external_ : External.state option;
  crash_enabled : bool;
}
(** Anvil [ControllerAndExternalState] (cluster.rs:33): one controller's internal
    state, its optional paired external system, and whether it may still crash
    (restart). [external_] is [Some] iff the controller model installs an
    external system. *)

type cluster_state = {
  api_server : Api_server.state;
  controller_and_externals : controller_and_external Imap.t;
  network : Network.state;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
  req_drop_enabled : bool;
  pod_monkey_enabled : bool;
}
(** Anvil [ClusterState] (cluster.rs:21): the whole cluster state — the api
    server / etcd store, the per-id controller-and-external states, the network's
    in-flight bag, the global monotone rpc-id allocator, and the two failure
    toggles (network request drop, pod monkey). A plain public record (mirrors
    the {!Api_method} record style). *)

type controller_model = {
  reconciler :
    (module Controller_pack.CONTROLLER
       with type R.s = Value.t
        and type R.ereq = Value.t
        and type R.eresp = Value.t);
  kind : Common.kind;
  external_model : External.model option;
}
(** Anvil [ControllerModel] (cluster.rs:100): the installed reconcile behaviour
    plus the optional external-system model. Anvil's [reconcile_model] field is
    the untyped [ReconcileModel]; here the drivable reconciler is carried as a
    {!Controller_pack.CONTROLLER} first-class-module pack (whose [R.s] / [R.ereq]
    / [R.eresp] are all {!Value.t}, the untyped wire form), from which
    {!Controller.model_of_controller} recovers the [ReconcileModel] on demand — a
    bare [(module Reconciler.RECONCILER)] cannot be driven (it has no
    [unmarshal_cr] to recover the typed cr), so the full pack is stored. [kind]
    is Anvil's [ReconcileModel.kind]. *)

type t = {
  installed_types : Api_server.installed_types;
  controller_models : controller_model Imap.t;
}
(** Anvil [Cluster] (cluster.rs:92): the state machine's static parameters — the
    installed custom-resource types (api-server validation / unmarshal dispatch)
    and the controllers running in the cluster, keyed by controller id. *)

val resources : cluster_state -> Api_server.stored_state
(** Anvil [ClusterState::resources] (cluster.rs:46): the api server's etcd store,
    [s.api_server.resources]. *)

val in_flight : cluster_state -> Message.Pool.t
(** Anvil [ClusterState::in_flight] (cluster.rs:41): the network's in-flight
    message bag, [s.network.in_flight]. *)

val ongoing_reconciles :
  cluster_state -> int -> Controller.ongoing_reconcile Object_ref_map.t
(** Anvil [ClusterState::ongoing_reconciles] (cluster.rs:51): the ongoing
    reconciles of controller [id]. Anvil indexes the (possibly absent) map entry;
    a missing controller id yields the empty map (total). *)

val scheduled_reconciles :
  cluster_state -> int -> Dynamic_object.t Object_ref_map.t
(** Anvil [ClusterState::scheduled_reconciles] (cluster.rs:56): the scheduled
    reconciles of controller [id]; empty map when the id is absent (total). *)

val lookup_resource :
  cluster_state -> Common.object_ref -> Dynamic_object.t option
(** Anvil [s.resources()[key]] under a [contains_key] guard: the etcd lookup by
    key, [None] when absent. Required by the ESR goal ({!Esr}). *)

val init : t -> cluster_state -> bool
(** Anvil [Cluster::init] (cluster.rs:110): the initial-state predicate — the api
    server, builtin controllers and network are initial, request-drop and pod
    monkey are enabled, and for every controller model its state exists and is
    initial, crash is enabled, and (if the model installs an external system) the
    external state exists and is initial. *)

val api_server_next :
  t -> (cluster_state, Message.t option, unit) Action.t
(** Anvil [Cluster::api_server_next] (cluster.rs:173): the api-server host action.
    Precondition: [received_msg_destined_for(recv, APIServer)] AND the api-server
    handler is [Enabled] AND {!Network.deliver} is [Enabled]. Transition: update
    [api_server] and [network] together. *)

val builtin_controllers_next :
  t -> (cluster_state, Builtin_controllers.choice * Common.object_ref, unit) Action.t
(** Anvil [Cluster::builtin_controllers_next] (cluster.rs:209): the garbage
    collector host action. Feeds a live [resources] snapshot and the shared
    allocator to the GC; both host and network must be [Enabled]; updates
    [network] and [rpc_id_allocator]. *)

val controller_next :
  t -> (cluster_state, int * Message.t option * Common.object_ref option, unit) Action.t
(** Anvil [Cluster::controller_next] / [chosen_controller_next] (cluster.rs:246,
    263): run the controller indexed by the input's first component. Precondition
    requires the model to exist, the scheduled-cr key to be [Some], the received
    message (if any) to be destined for [Controller(id, key)], and both the
    controller step and the network to be [Enabled]; updates [controller_and_
    externals.(id).controller], [network] and [rpc_id_allocator]. The controller
    machine's internal step [choose] collapses to the (at most one) enabled step
    among run / continue / end for the given input. *)

val schedule_controller_reconcile :
  t -> (cluster_state, int * Common.object_ref, unit) Action.t
(** Anvil [Cluster::schedule_controller_reconcile] (cluster.rs:331): schedule
    controller [id] to reconcile [object_key] when that key exists in etcd and
    matches the controller's kind. No network side; inserts the current stored
    object into the controller's [scheduled_reconciles]. *)

val restart_controller : t -> (cluster_state, int, unit) Action.t
(** Anvil [Cluster::restart_controller] (cluster.rs:377): reset controller [id]
    to empty ongoing / scheduled maps (crash-restart model), preserving its
    [reconcile_id_allocator]. Enabled only while crash is enabled. *)

val disable_crash : t -> (cluster_state, int, unit) Action.t
(** Anvil [Cluster::disable_crash] (cluster.rs:407): stop controller [id]
    crashing (a liveness constraint); sets [crash_enabled] to [false]. *)

val drop_req : t -> (cluster_state, Message.t * Api_method.api_error, unit) Action.t
(** Anvil [Cluster::drop_req] (cluster.rs:439): intercept a request to the api
    server and reply to the sender with [Api_method.api_error] (transient-failure
    model). Enabled only while [req_drop_enabled], on an in-flight api-request
    message; updates [network] only. *)

val disable_req_drop : t -> (cluster_state, unit, unit) Action.t
(** Anvil [Cluster::disable_req_drop] (cluster.rs:472): stop the network dropping
    requests (a liveness constraint); sets [req_drop_enabled] to [false]. Always
    enabled. *)

val pod_monkey_next : t -> Pod_monkey.step -> (cluster_state, Pod.t, unit) Action.t
(** Anvil [Cluster::pod_monkey_next] (cluster.rs:492): the pod monkey firing one
    request for [pod]. Anvil's [PodMonkeyStep(PodView)] hides {e which} of the
    four pod operations behind the host machine's internal [choose] (all four are
    unconditionally enabled); that [choose] is made an explicit parameter here —
    one {!Action.t} per {!Pod_monkey.step}. Enabled only while [pod_monkey_
    enabled] (and the network is [Enabled]); updates [network] and [rpc_id_
    allocator]. {!next_step} on a [Pod_monkey_step] quantifies over all four. *)

val disable_pod_monkey : t -> (cluster_state, unit, unit) Action.t
(** Anvil [Cluster::disable_pod_monkey] (cluster.rs:526): stop the pod monkey (a
    liveness constraint); sets [pod_monkey_enabled] to [false]. Always enabled. *)

val external_next :
  t -> (cluster_state, int * Message.t option, unit) Action.t
(** Anvil [Cluster::external_next] / [chosen_external_next] (cluster.rs:543, 560):
    run the external system paired with controller [id]. Precondition requires
    the model to exist with an external model, the received message (if any) to
    be destined for [External(id)], and both host and network [Enabled]; updates
    [controller_and_externals.(id).external_] and [network]. *)

val stutter : t -> (cluster_state, unit, unit) Action.t
(** Anvil [Cluster::stutter] (cluster.rs:599): the no-op action ([s' = s]); keeps
    [always(next)] true. Always enabled. *)

val next_step : t -> cluster_state -> Step.t -> cluster_state -> bool
(** Anvil [Cluster::next_step] (cluster.rs:153): the compound transition relation.
    An exhaustive twelve-arm match on {!Step.t}; each arm is the corresponding
    host action's [Action.forward input s s']. *)

val next_rel : t -> cluster_state -> Step.t -> cluster_state -> bool
(** Alias of {!next_step} for the assurance spine. Anvil's [next] is [exists step,
    next_step(s, s', step)]; the existential does not port, so callers quantify
    over {!enabled_successors} instead. *)

val enabled_successors :
  Bound.t -> t -> cluster_state -> (Step.t * cluster_state) list
(** Anvil [Cluster::next] made executable (architecture finding 14): every
    ([step], [s']) with [next_step t s step s'], drawn from a step domain each of
    whose unbounded indices is bounded by {!Bound.t} — in-flight [recv] messages
    by [max_in_flight], resource / pod / gc keys by [max_objects_per_kind],
    controller ids by [max_controllers]. No cap is imposed beyond {!Bound.t}; the
    per-field bug classes a bound may exclude are documented on {!Bound.t}. *)

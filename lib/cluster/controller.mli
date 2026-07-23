(** Anvil source: kubernetes_cluster/spec/controller/{types.rs,
    state_machine.rs}.

    The controller host: the reconcile driver of the cluster transition system.
    It promotes a {e scheduled} cr key into an {e ongoing} reconcile, invokes the
    installed reconciler's [reconcile_core] with the matched response, turns a
    produced request into a sent {!Message.t}, and removes reconciles that report
    done / error. Three actions ({!run_scheduled_reconcile} /
    {!continue_reconcile} / {!end_reconcile}) selected by the {!controller} state
    machine.

    Anvil's [ReconcileLocalState], [ExternalRequest] and [ExternalResponse] are
    all [Value] (types.rs:15, message.rs:10/12), so a reconcile's local state is
    carried untyped as {!Value.t} and the reconcile program is the untyped
    {!reconcile_model} — Anvil's [ReconcileModel] (types.rs:54). That erasure is
    what lets one concrete {!state} host every controller in the cluster's
    heterogeneous controller map. *)

type reconcile_id = int
(** Anvil [ReconcileId = nat] (types.rs:27): a per-controller unique reconcile
    identifier, also usable as a happens-before timestamp. A counter, never an
    arithmetic operand beyond the allocator's [+1]. *)

module Reconcile_id_allocator : sig
  (** Anvil [ReconcileIdAllocator] (types.rs:31): a monotone counter handing out
      a fresh {!reconcile_id} per reconcile start. *)
  type t

  val init : unit -> t
  (** [ReconcileIdAllocator { reconcile_id_counter = 0 }] (state_machine.rs:143):
      the fresh allocator. *)

  val allocate : t -> t * reconcile_id
  (** Anvil [ReconcileIdAllocator::allocate] (types.rs:47): returns
      [(advanced_allocator, allocated_id)] where [allocated_id] is the CURRENT
      counter and [advanced_allocator] has [counter + 1]. Thread the returned
      allocator forward for uniqueness; do NOT pre-increment. *)
end

type ongoing_reconcile = {
  triggering_cr : Dynamic_object.t;
      (** The cr snapshot captured at {!run_scheduled_reconcile}; never mutated
          while the reconcile is ongoing (reconcile_core always receives this
          original, not a live cr). *)
  pending_req_msg : Message.t option;
      (** The request this reconcile is awaiting a response to; [None] iff not
          waiting. Overwritten every {!continue_reconcile} step. *)
  local_state : Value.t;  (** The reconcile program's evolving untyped state. *)
  reconcile_id : reconcile_id;  (** The id assigned at start. *)
}
(** Anvil [OngoingReconcile] (types.rs:62): the per-cr in-flight reconcile
    record, the value type of {!state.ongoing_reconciles}. *)

type state = {
  ongoing_reconciles : ongoing_reconcile Object_ref_map.t;
      (** Active reconcile loops, keyed by cr {!Common.object_ref}; key present
          iff a reconcile is in progress for that cr. *)
  scheduled_reconciles : Dynamic_object.t Object_ref_map.t;
      (** Cr keys queued to start, mapped to the triggering cr snapshot. *)
  reconcile_id_allocator : Reconcile_id_allocator.t;
}
(** Anvil [ControllerState] (types.rs:9): the entire per-controller host state. *)

type step = Run_scheduled_reconcile | Continue_reconcile | End_reconcile
(** Anvil [ControllerStep] (types.rs:69): the three-variant step selector, matched
    exhaustively (no [_ ->]) in {!controller}'s [step_to_action]. *)

type action_input = {
  recv : Message.t option;  (** The message (if any) delivered this step. *)
  scheduled_cr_key : Common.object_ref option;
      (** Which cr key this step operates on (chosen by the scheduler). *)
  rpc_id_allocator : Message.Rpc_id_allocator.t;
      (** Allocator for the rpc id of any request this step sends. *)
}
(** Anvil [ControllerActionInput] (types.rs:75). *)

type action_output = {
  send : Message.Pool.t;
      (** Messages emitted this step (empty, or a singleton request). *)
  rpc_id_allocator : Message.Rpc_id_allocator.t;
      (** The (possibly advanced) allocator to thread forward. *)
}
(** Anvil [ControllerActionOutput] (types.rs:81). *)

type reconcile_model = {
  kind : Common.kind;
      (** The cr kind this controller reconciles; gates every action by key
          kind. *)
  init : unit -> Value.t;  (** Anvil [ReconcileModel.init]: the fresh local
                               state. *)
  transition :
    Dynamic_object.t ->
    Value.t Io.response_view option ->
    Value.t ->
    Value.t * Value.t Io.request_view option;
      (** Anvil [ReconcileModel.transition] = reconcile_core: given
          [(triggering_cr, optional response, current local_state)], produce
          [(new local_state, optional request)]. Anvil's [RequestContent] /
          [ResponseContent] (types.rs:17/22) are [Value.t Io.request_view] /
          [Io.response_view]. *)
  reconcile_done : Value.t -> bool;
      (** Anvil [ReconcileModel.done]: this reconcile finished successfully. *)
  reconcile_error : Value.t -> bool;
      (** Anvil [ReconcileModel.error]: this reconcile hit an error. *)
}
(** Anvil [ReconcileModel] (types.rs:54): the installed reconcile program, a
    bundle of untyped ([Value]-based) closures — passed to each action, not
    stored in {!state}. Anvil connects a typed reconciler to it only through
    view equalities (in proof); {!model_of_controller} is the executable bridge. *)

val make_model :
  kind:Common.kind ->
  init:(unit -> Value.t) ->
  transition:
    (Dynamic_object.t ->
    Value.t Io.response_view option ->
    Value.t ->
    Value.t * Value.t Io.request_view option) ->
  reconcile_done:(Value.t -> bool) ->
  reconcile_error:(Value.t -> bool) ->
  reconcile_model
(** Labelled constructor for a {!reconcile_model} (Anvil [ReconcileModel]
    (types.rs:54)); the way a Phase-3 reconciler supplies its own untyped
    program. *)

val run_scheduled_reconcile :
  reconcile_model -> (state, action_input, action_output) Action.t
(** Anvil [run_scheduled_reconcile(model)] (state_machine.rs:9): promote a
    scheduled cr into a fresh ongoing reconcile. Precondition (state_machine.rs
    :11): key Some of matching kind, currently scheduled, no message consumed,
    not already reconciling. Transition (state_machine.rs:18): allocate a
    reconcile id, insert the initialized ongoing reconcile, remove the scheduled
    entry, send nothing. *)

val continue_reconcile :
  reconcile_model ->
  controller_id:int ->
  (state, action_input, action_output) Action.t
(** Anvil [continue_reconcile(model, controller_id)] (state_machine.rs:42): run
    one reconcile_core step. Precondition (state_machine.rs:44): key Some of
    matching kind, ongoing, not done, not errored, and the recv/pending
    correlation — a pending request requires a matching delivered response
    ({!Message.resp_msg_matches_req_msg}), no pending request requires no message.
    Transition (state_machine.rs:63): build the response, invoke reconcile_core,
    turn a produced request into one sent {!Message.t} (allocating one rpc id via
    [controller_req_msg] / [controller_external_req_msg]), and re-insert the
    ongoing reconcile with its new pending request and local state ([triggering_cr]
    and [reconcile_id] preserved). *)

val end_reconcile :
  reconcile_model -> (state, action_input, action_output) Action.t
(** Anvil [end_reconcile(model)] (state_machine.rs:108): remove a done / errored
    ongoing reconcile. Precondition (state_machine.rs:110): key Some of matching
    kind, ongoing, done OR errored, no message consumed. Transition
    (state_machine.rs:122): remove the ongoing reconcile; send nothing. Does NOT
    re-schedule — requeue is an external host's responsibility. *)

val init : state
(** Anvil [controller().init] (state_machine.rs:139): the initial controller
    state — empty [ongoing_reconciles] and [scheduled_reconciles], a
    zero-counter {!Reconcile_id_allocator}. *)

val controller :
  reconcile_model ->
  controller_id:int ->
  (state, action_input, action_input, action_output, step) State_machine.t
(** Anvil [controller(model, controller_id)] (state_machine.rs:137): the reconcile
    driver as a {!State_machine.t}. Its [init] predicate asserts the empty-maps /
    zero-counter start; [step_to_action] selects among the three actions
    exhaustively; [action_input] passes the host input through unchanged (Anvil's
    identity [action_input], state_machine.rs:160). The cluster's
    [enabled_successors] drives it via {!State_machine.next_results} over a
    bounded step list. *)

val model_of_controller :
  kind:Common.kind ->
  (module Controller_pack.CONTROLLER
     with type R.s = Value.t
      and type R.ereq = Value.t
      and type R.eresp = Value.t) ->
  reconcile_model
(** Adapt a typed installed controller ({!Controller_pack.CONTROLLER}) into the
    untyped {!reconcile_model} the driver runs, unpacking it locally to invoke
    [R.reconcile_core] (Anvil [ControllerModel.reconcile_model]). [R.k] is
    recovered from the [triggering_cr] via [unmarshal_cr]; an unmarshal failure
    (never reached for a well-formed cr of the gated {!kind}) is the total no-op
    [(state, None)], the honest completion of Anvil's proof-discharged unmarshal.

    Two crux notes (see the P2 build status report): the reconcile loop threads
    the local state and the external request/response through the reconciler, and
    Anvil makes all three [Value], so this requires a pack whose [R.s] / [R.ereq]
    / [R.eresp] are {!Value.t}. The fully-erased {!Controller_pack.packed} hides
    them and so cannot be driven directly; and {!Controller_pack.CONTROLLER}
    carries no runtime cr kind, so [kind] is supplied explicitly (Anvil's
    [ReconcileModel.kind]). *)

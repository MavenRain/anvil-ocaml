(** Anvil source: kubernetes_cluster/spec/builtin_controllers/
    {types.rs, state_machine.rs, garbage_collector.rs}.

    The builtin-controllers host and its single controller, the garbage
    collector. Both {!choice} and {!step} are single-variant today; they are
    matched exhaustively (no [_ ->]) so a future variant is a compile error, not
    a silent fall-through. The host {!state} is [unit] -- all data rides in
    {!action_input}/{!action_output}. The GC forms a single [DeleteRequest]
    MESSAGE to the api server; it never mutates [resources] itself (deletion
    happens later, when the api server processes that request). *)

type choice = Garbage_collector
(** Anvil [BuiltinControllerChoice] (builtin_controllers/types.rs:13): which
    builtin controller the top-level machine picked. Only the garbage collector
    is modelled. *)

val equal_choice : choice -> choice -> bool
(** Structural equality on {!choice} (Anvil derived [==]); exhaustive, no
    wildcard. *)

type step = Run_garbage_collector
(** Anvil [BuiltinControllersStep] (builtin_controllers/types.rs:9): the only
    step is to run the garbage collector. *)

type state = unit
(** Anvil builtin-controllers [StateMachine] state ([()], types.rs:29): the host
    keeps no local state. *)

type action_input = {
  choice : choice;
  key : Common.object_ref;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
  resources : Dynamic_object.t Object_ref_map.t;
}
(** Anvil [BuiltinControllersActionInput] (builtin_controllers/types.rs:17): the
    picked [choice], the object [key] the GC considers deleting, the RPC-id
    allocator for the delete request, and a snapshot of the cluster store
    ([StoredState = Map<ObjectRef, DynamicObjectView>]). *)

type action_output = {
  send : Message.Pool.t;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
}
(** Anvil [BuiltinControllersActionOutput] (builtin_controllers/types.rs:24): the
    emitted messages (a singleton delete request) and the advanced allocator
    threaded back to the caller (rpc-id monotonicity). *)

val run_garbage_collector : (state, action_input, action_output) Action.t
(** Anvil [run_garbage_collector] (garbage_collector.rs:15). Precondition
    ([&&&], :22-36): the choice is the GC, [key] is present in [resources], its
    metadata carries an owner-references sequence that [is Some] and has length
    [> 0], and EVERY owner reference is orphaned -- the referred owner (resolved
    to an [ObjectRef] in [key]'s namespace) is absent from [resources], or
    present with a [uid] differing from the one recorded in the reference (a
    [None] stored uid also counts as a mismatch). Transition (:38-53): build a
    [DeleteRequest] carrying the object's current [uid] as a precondition and
    [None] resource-version, wrap it in a message from [Builtin_controller] to
    [Api_server], allocate its rpc_id, and return the singleton send with the
    advanced allocator. *)

val init : state -> bool
(** Anvil [builtin_controllers().init] (state_machine.rs:9): every [unit] state
    is initial ([true]). *)

val state_machine :
  (state, action_input, action_input, action_output, step) State_machine.t
(** Anvil [builtin_controllers()] (state_machine.rs:7): the host state machine --
    [init], [step_to_action] mapping [Run_garbage_collector] to
    {!run_garbage_collector}, and the identity [action_input]. *)

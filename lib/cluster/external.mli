(** Anvil source: kubernetes_cluster/spec/external/{types.rs, state_machine.rs}.

    The external host and the controller-supplied {!model} that parameterises it.
    {!state} wraps one opaque local {!Value.t}; the single
    {!handle_external_request} action consumes an [External_request] message and
    replies with an [External_response] (src/dst swapped, rpc_id preserved). The
    model READS [resources] but never mutates the cluster store. *)

type local_state = Value.t
(** Anvil [ExternalLocalState = Value] (external/types.rs:9): the opaque
    marshalled local state, only mutated by the model's [transition]. *)

type state = { state : local_state }
(** Anvil [ExternalState] (external/types.rs:11): the entire external host state
    -- a single local-state field. *)

type model = {
  init : unit -> local_state;
  transition :
    Value.t ->
    local_state ->
    Dynamic_object.t Object_ref_map.t ->
    local_state * Value.t;
}
(** Anvil [ExternalModel] (external/types.rs:15): the two spec fns parameterising
    the host, carried as data (a record of closures). [init] produces the initial
    local state; [transition] maps an [External_request] payload, the current
    local state, and a read-only [StoredState] snapshot to a new local state and
    an [External_response] payload -- argument order [(request, state, resources)],
    result [(new_state, response)]. *)

type step = Handle_external_request
(** Anvil [ExternalStep] (external/types.rs:20): the sole step -- consume a
    request and reply. *)

type action_input = {
  recv : Message.t option;
  resources : Dynamic_object.t Object_ref_map.t;
}
(** Anvil [ExternalActionInput] (external/types.rs:24): the optionally-received
    message and the [StoredState] snapshot passed to the model. *)

type action_output = { send : Message.Pool.t }
(** Anvil [ExternalActionOutput] (external/types.rs:29): the emitted messages --
    always the single response. *)

val transition_by_external :
  model ->
  Message.t ->
  Dynamic_object.t Object_ref_map.t ->
  state ->
  state * Message.t
(** Anvil [transition_by_external] (external/state_machine.rs:8): run
    [model.transition] on the [External_request] payload of [req_msg], the current
    [state.state], and [resources]; update only the local-state field; and form
    the reply via [form_external_resp_msg] (src/dst swapped, rpc_id kept). Anvil
    [recommends] the content is an [External_request]; the recommendation is
    completed totally -- a non-[External_request] content (unreachable through
    {!handle_external_request}'s precondition) leaves state and message unchanged
    (no fabricated payload, no exception). *)

val handle_external_request :
  model -> (state, action_input, action_output) Action.t
(** Anvil [handle_external_request] (external/state_machine.rs:21). Precondition
    (:23-26): [recv] is [Some] and its content is an [External_request].
    Transition (:27-34): run {!transition_by_external} and emit the singleton
    response. *)

val init : model -> state -> bool
(** Anvil [external(model).init] (external/state_machine.rs:40): the initial
    state is the one whose local state equals [model.init ()]. *)

val external_ :
  model ->
  (state, action_input, action_input, action_output, step) State_machine.t
(** Anvil [external(model)] (external/state_machine.rs:38): the host state machine
    -- [init model], [step_to_action] mapping [Handle_external_request] to
    {!handle_external_request}, and the identity [action_input]. (Named
    [external_] because [external] is an OCaml keyword.) *)

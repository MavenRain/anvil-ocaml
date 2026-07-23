(** Anvil source: kubernetes_cluster/spec/pod_monkey/{types.rs, state_machine.rs}.

    The pod monkey: an adversarial actor with no local state that fires
    create/update/update-status/delete pod REQUESTS at the api server. Every
    action is unconditionally enabled (precondition [true] -- "the monkey does
    not need a precondition to constrain itself") and leaves the [unit] {!state}
    unchanged; each emits exactly one request message (src [Pod_monkey], dst
    [Api_server]) plus the advanced allocator. The monkey never mutates
    [resources]; the api server applies the requests later. *)

type state = unit
(** Anvil [PodMonkeyState = ()] (pod_monkey/types.rs:8): the monkey keeps no
    local state. *)

type action_input = {
  pod : Pod.t;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
}
(** Anvil [PodMonkeyActionInput] (pod_monkey/types.rs:17): the pod the monkey
    acts on (source of namespace/name/marshal/object_ref) and the allocator for
    the outgoing request's rpc_id. *)

type action_output = {
  send : Message.Pool.t;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
}
(** Anvil [PodMonkeyActionOutput] (pod_monkey/types.rs:22): the emitted singleton
    request and the advanced allocator threaded back to the caller. *)

type step =
  | Create_pod
  | Update_pod
  | Update_pod_status
  | Delete_pod
(** Anvil [PodMonkeyStep] (pod_monkey/types.rs:10): the four requests the monkey
    can fire. Matched exhaustively (no wildcard). *)

val create_pod : (state, action_input, action_output) Action.t
(** Anvil [create_pod] (pod_monkey/state_machine.rs:8): precondition [true]; send
    a [CreateRequest] for [pod]'s namespace and marshalled object, with the
    advanced allocator returned. *)

val delete_pod : (state, action_input, action_output) Action.t
(** Anvil [delete_pod] (pod_monkey/state_machine.rs:32): precondition [true]; send
    a [DeleteRequest] for [pod]'s object ref with no preconditions ([None] -- the
    monkey imposes no delete precondition). *)

val update_pod : (state, action_input, action_output) Action.t
(** Anvil [update_pod] (pod_monkey/state_machine.rs:54): precondition [true]; send
    an [UpdateRequest] for [pod]'s namespace, name and marshalled object. *)

val update_pod_status : (state, action_input, action_output) Action.t
(** Anvil [update_pod_status] (pod_monkey/state_machine.rs:79): precondition
    [true]; send an [UpdateStatusRequest] for [pod]'s namespace, name and
    marshalled object. *)

val init : state -> bool
(** Anvil [pod_monkey().init] (pod_monkey/state_machine.rs:106): every [unit]
    state is initial ([true]). *)

val state_machine :
  (state, action_input, action_input, action_output, step) State_machine.t
(** Anvil [pod_monkey()] (pod_monkey/state_machine.rs:104): the host state machine
    -- [init], the [step_to_action] mapping ([Create_pod] to {!create_pod},
    [Update_pod] to {!update_pod}, [Update_pod_status] to {!update_pod_status},
    [Delete_pod] to {!delete_pod}), and the identity [action_input]. *)

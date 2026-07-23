(* Anvil source: kubernetes_cluster/spec/pod_monkey/{types.rs, state_machine.rs}.

   The pod monkey: an adversarial actor with NO local state ([PodMonkeyState =
   ()]) that fires create/update/update-status/delete pod REQUESTS at the api
   server. Every action has precondition [true] ("the monkey does not need a
   precondition to constrain itself") and leaves its [()] state unchanged; each
   emits exactly one request message (src [Pod_monkey], dst [Api_server]) and the
   advanced allocator. The monkey never mutates [resources]; the api server
   applies the requests later.

   Anvil's [metadata.namespace->0]/[metadata.name->0] and [pod.object_ref()] are
   spec-partial under the [true] precondition (no [Some]/well-formedness guard).
   The firewall forbids exceptions, so these total to a documented [~default] in
   the (unreachable-for-a-well-formed-pod) missing-field case -- the same
   total-completion discipline the network host uses for its
   precondition-guaranteed [remove_one]. *)

type state = unit

type action_input = {
  pod : Pod.t;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
}

type action_output = {
  send : Message.Pool.t;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
}

type step =
  | Create_pod
  | Update_pod
  | Update_pod_status
  | Delete_pod

(* Anvil [input.pod.metadata.namespace->0]: the namespace unwrap. Total
   completion with [""] when absent (unreachable for a well-formed pod). *)
let pod_namespace (pod : Pod.t) : string =
  Option.value ~default:"" (Object_meta.namespace (Pod.metadata pod))

(* Anvil [input.pod.metadata.name->0]: the name unwrap, completed as above. *)
let pod_name (pod : Pod.t) : string =
  Option.value ~default:"" (Object_meta.name (Pod.metadata pod))

(* Anvil [input.pod.object_ref()]: the pod's [ObjectRef]. [Pod.object_ref]
   returns [Res.t] (name/namespace may be absent); the total completion rebuilds
   the same [{kind; namespace; name}] key from the [pod_namespace]/[pod_name]
   defaults in the unreachable ill-formed case. *)
let pod_object_ref (pod : Pod.t) : Common.object_ref =
  Result.value (Pod.object_ref pod)
    ~default:
      { Common.kind = Pod.kind; namespace = pod_namespace pod; name = pod_name pod }

(* Anvil create_pod (pod_monkey/state_machine.rs:8). [allocate] returns
   [(advanced, id)]: the message carries the current [id] (:15), the output the
   [advanced] allocator (:26). *)
let create_pod : (state, action_input, action_output) Action.t =
  let precondition (_input : action_input) (_s : state) : bool = true in
  let transition (input : action_input) (s : state) : state * action_output =
    let advanced, allocated =
      Message.Rpc_id_allocator.allocate input.rpc_id_allocator
    in
    let content =
      Message.create_req_msg_content (pod_namespace input.pod) (Pod.marshal input.pod)
    in
    let create_req_msg = Message.pod_monkey_req_msg allocated content in
    (s, { send = Message.Pool.singleton create_req_msg; rpc_id_allocator = advanced })
  in
  { precondition; transition }

(* Anvil delete_pod (pod_monkey/state_machine.rs:32): [preconditions = None]. *)
let delete_pod : (state, action_input, action_output) Action.t =
  let precondition (_input : action_input) (_s : state) : bool = true in
  let transition (input : action_input) (s : state) : state * action_output =
    let advanced, allocated =
      Message.Rpc_id_allocator.allocate input.rpc_id_allocator
    in
    let content =
      Message.delete_req_msg_content (pod_object_ref input.pod) None
    in
    let delete_req_msg = Message.pod_monkey_req_msg allocated content in
    (s, { send = Message.Pool.singleton delete_req_msg; rpc_id_allocator = advanced })
  in
  { precondition; transition }

(* Anvil update_pod (pod_monkey/state_machine.rs:54). *)
let update_pod : (state, action_input, action_output) Action.t =
  let precondition (_input : action_input) (_s : state) : bool = true in
  let transition (input : action_input) (s : state) : state * action_output =
    let advanced, allocated =
      Message.Rpc_id_allocator.allocate input.rpc_id_allocator
    in
    let content =
      Message.update_req_msg_content (pod_namespace input.pod) (pod_name input.pod)
        (Pod.marshal input.pod)
    in
    let update_req_msg = Message.pod_monkey_req_msg allocated content in
    (s, { send = Message.Pool.singleton update_req_msg; rpc_id_allocator = advanced })
  in
  { precondition; transition }

(* Anvil update_pod_status (pod_monkey/state_machine.rs:79). *)
let update_pod_status : (state, action_input, action_output) Action.t =
  let precondition (_input : action_input) (_s : state) : bool = true in
  let transition (input : action_input) (s : state) : state * action_output =
    let advanced, allocated =
      Message.Rpc_id_allocator.allocate input.rpc_id_allocator
    in
    let content =
      Message.update_status_req_msg_content (pod_namespace input.pod)
        (pod_name input.pod) (Pod.marshal input.pod)
    in
    let update_status_req_msg = Message.pod_monkey_req_msg allocated content in
    ( s,
      {
        send = Message.Pool.singleton update_status_req_msg;
        rpc_id_allocator = advanced;
      } )
  in
  { precondition; transition }

let init (_s : state) : bool = true

let step_to_action (step : step) : (state, action_input, action_output) Action.t =
  match step with
  | Create_pod -> create_pod
  | Update_pod -> update_pod
  | Update_pod_status -> update_pod_status
  | Delete_pod -> delete_pod

let state_machine :
    (state, action_input, action_input, action_output, step) State_machine.t =
  {
    State_machine.init;
    step_to_action;
    action_input = (fun (_step : step) (input : action_input) -> input);
  }

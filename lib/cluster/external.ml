(* Anvil source: kubernetes_cluster/spec/external/{types.rs, state_machine.rs}.

   The external host: a controller-supplied model of an out-of-cluster system.
   [ExternalState] wraps a single opaque [Value] local state; [ExternalModel]
   parameterises the machine with two spec fns ([init], [transition]) carried as
   data (a record of closures -- the machine is parametric over them, so no
   specific controller's logic is inlined here). The single action consumes an
   [External_request] message and replies with an [External_response] (src/dst
   swapped, rpc_id preserved). [resources] is read-only input to the model's
   transition; the external host never mutates the cluster store. *)

type local_state = Value.t

type state = { state : local_state }

type model = {
  init : unit -> local_state;
  transition :
    Value.t ->
    local_state ->
    Dynamic_object.t Object_ref_map.t ->
    local_state * Value.t;
}

type step = Handle_external_request

type action_input = {
  recv : Message.t option;
  resources : Dynamic_object.t Object_ref_map.t;
}

type action_output = { send : Message.Pool.t }

(* Anvil transition_by_external (external/state_machine.rs:8). [recommends
   req_msg.content is ExternalRequest]; the action precondition guarantees it.
   The [->ExternalRequest_0] payload projection becomes an exhaustive match on
   [message_content]: the three non-request contents are unreachable under the
   recommendation and complete totally by leaving state and message unchanged. *)
let transition_by_external (model : model) (req_msg : Message.t)
    (resources : Dynamic_object.t Object_ref_map.t) (s : state) : state * Message.t =
  match req_msg.Message.content with
  | Message.External_request request ->
      let inner_s_prime, resp = model.transition request s.state resources in
      let resp_msg = Message.form_external_resp_msg req_msg resp in
      ({ state = inner_s_prime }, resp_msg)
  | Message.Api_request _ | Message.Api_response _ | Message.External_response _ ->
      (s, req_msg)

(* Anvil handle_external_request precondition clause 2 (external/state_machine.rs
   :25): the received message's content is an [External_request]. Exhaustive
   match on the four-variant [message_content], no wildcard. *)
let content_is_external_request (c : Message.message_content) : bool =
  match c with
  | Message.External_request _ -> true
  | Message.Api_request _ | Message.Api_response _ | Message.External_response _ ->
      false

let handle_external_request (model : model) :
    (state, action_input, action_output) Action.t =
  (* Precondition (:23-26): [recv is Some] and its content [is ExternalRequest].
     Combinator over the [recv] option (no two-arm match on the option). *)
  let precondition (input : action_input) (_s : state) : bool =
    input.recv
    |> Option.fold ~none:false
         ~some:(fun (m : Message.t) -> content_is_external_request m.Message.content)
  in
  (* Transition (:27-34): unwrap [recv] (precondition-guaranteed [Some]; the
     [None] branch is an unreachable total completion emitting nothing), run
     {!transition_by_external}, and emit the singleton response. *)
  let transition (input : action_input) (s : state) : state * action_output =
    input.recv
    |> Option.fold
         ~none:(s, { send = Message.Pool.empty })
         ~some:(fun (req_msg : Message.t) ->
           let s_prime, resp_msg =
             transition_by_external model req_msg input.resources s
           in
           (s_prime, { send = Message.Pool.singleton resp_msg }))
  in
  { precondition; transition }

let init (model : model) (s : state) : bool = Value.equal s.state (model.init ())

let step_to_action (model : model) (step : step) :
    (state, action_input, action_output) Action.t =
  match step with Handle_external_request -> handle_external_request model

let external_ (model : model) :
    (state, action_input, action_input, action_output, step) State_machine.t =
  {
    State_machine.init = init model;
    step_to_action = step_to_action model;
    action_input = (fun (_step : step) (input : action_input) -> input);
  }

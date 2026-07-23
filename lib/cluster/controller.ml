(* Anvil source: kubernetes_cluster/spec/controller/{types.rs, state_machine.rs}.

   The controller host: the reconcile driver. It turns a *scheduled* cr key into
   an *ongoing* reconcile, repeatedly invokes the installed reconciler's
   [reconcile_core] with the matched response, turns a produced request into a
   sent {!Message.t}, and removes reconciles that report done / error. Three
   actions ([run_scheduled_reconcile] / [continue_reconcile] / [end_reconcile])
   and the [controller] state machine that selects among them.

   Faithful-port notes threaded through:
   - Anvil's [ReconcileLocalState], [ExternalRequest] and [ExternalResponse] are
     all [Value] (types.rs:15, message.rs:10/12). So a reconcile's local state is
     carried untyped as {!Value.t}, and the reconcile program is the untyped
     {!reconcile_model} — exactly Anvil's [ReconcileModel] (types.rs:54), whose
     [RequestContent]/[ResponseContent] (types.rs:17/22) are the two-variant
     [Io.request_view]/[Io.response_view] at [Value.t]. This is what lets one
     concrete {!state} host every controller in the cluster's heterogeneous map.
   - Verus [->0] / [x[k]] projections that are total only under a precondition
     become {!Option.fold} over {!Object_ref_map.find_opt}: the precondition-
     excluded [None] branch is a total no-op (the state unchanged), never a
     partial unwrap or an exception.
   - The pending-request / received-response correlation invariant lives entirely
     in {!continue_reconcile}'s precondition, reproduced conjunct for conjunct
     (state_machine.rs:44-62).
   - The allocators (rpc-id and reconcile-id) return the OLD counter as the id and
     an allocator advanced by one; the returned allocator is threaded forward. *)

type reconcile_id = int

(* Anvil [ReconcileIdAllocator] (types.rs:31): a monotone counter. [allocate]
   returns the current counter as the id and an allocator with [counter + 1]
   (types.rs:47) — allocate-old-then-increment, so ids never repeat as long as
   the returned allocator is threaded forward. *)
module Reconcile_id_allocator = struct
  type t = { reconcile_id_counter : reconcile_id }

  let init () : t = { reconcile_id_counter = 0 }

  let allocate (a : t) : t * reconcile_id =
    ({ reconcile_id_counter = a.reconcile_id_counter + 1 }, a.reconcile_id_counter)
end

(* Anvil [OngoingReconcile] (types.rs:62): the per-cr in-flight reconcile record.
   [triggering_cr] is the snapshot captured at [run_scheduled_reconcile] and is
   never mutated while the reconcile is ongoing; [local_state] is the reconcile
   program's evolving untyped state. *)
type ongoing_reconcile = {
  triggering_cr : Dynamic_object.t;
  pending_req_msg : Message.t option;
  local_state : Value.t;
  reconcile_id : reconcile_id;
}

(* Anvil [ControllerState] (types.rs:9). *)
type state = {
  ongoing_reconciles : ongoing_reconcile Object_ref_map.t;
  scheduled_reconciles : Dynamic_object.t Object_ref_map.t;
  reconcile_id_allocator : Reconcile_id_allocator.t;
}

(* Anvil [ControllerStep] (types.rs:69): the three-variant step selector, matched
   exhaustively in {!select_action} (no [_ ->]). *)
type step = Run_scheduled_reconcile | Continue_reconcile | End_reconcile

(* Anvil [ControllerActionInput] (types.rs:75). *)
type action_input = {
  recv : Message.t option;
  scheduled_cr_key : Common.object_ref option;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
}

(* Anvil [ControllerActionOutput] (types.rs:81). *)
type action_output = {
  send : Message.Pool.t;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
}

(* Anvil [ReconcileModel] (types.rs:54), untyped over {!Value.t} exactly as the
   spec: [transition] is Anvil's reconcile_core [(triggering_cr, resp, state) ->
   (state', req)]. [RequestContent]/[ResponseContent] are [Value.t
   Io.request_view]/[Io.response_view]. *)
type reconcile_model = {
  kind : Common.kind;
  init : unit -> Value.t;
  transition :
    Dynamic_object.t ->
    Value.t Io.response_view option ->
    Value.t ->
    Value.t * Value.t Io.request_view option;
  reconcile_done : Value.t -> bool;
  reconcile_error : Value.t -> bool;
}

let make_model ~kind ~init ~transition ~reconcile_done ~reconcile_error :
    reconcile_model =
  { kind; init; transition; reconcile_done; reconcile_error }

(* Anvil [continue_reconcile] precondition (state_machine.rs:54): the delivered
   message's content [is APIResponse || is ExternalResponse]. Exhaustive over the
   four {!Message.message_content} variants; the two request variants are
   [false]. *)
let is_response_content (c : Message.message_content) : bool =
  match c with
  | Message.Api_response _ | Message.External_response _ -> true
  | Message.Api_request _ | Message.External_request _ -> false

(* Anvil [continue_reconcile] transition (state_machine.rs:66-74): a received
   message becomes the [Some] response handed to reconcile_core — [APIResponse]
   to [KubernetesResponse], else [ExternalResponse]. Exhaustive over the four
   content variants; the two request variants (precondition-excluded, since a
   consumed message must be a response) yield [None], the total completion of
   Anvil's [content->ExternalResponse_0] projection. *)
let response_content_of_msg (m : Message.t) : Value.t Io.response_view option =
  match m.Message.content with
  | Message.Api_response r -> Some (Io.K_response r)
  | Message.External_response v -> Some (Io.External_response v)
  | Message.Api_request _ | Message.External_request _ -> None

(* Anvil [run_scheduled_reconcile] (state_machine.rs:9): promote a scheduled cr
   into a fresh ongoing reconcile. *)
let run_scheduled_reconcile (model : reconcile_model) :
    (state, action_input, action_output) Action.t =
  let precondition (input : action_input) (s : state) : bool =
    (* state_machine.rs:11-17: key is Some, kind matches, currently scheduled, no
       message consumed, not already reconciling. *)
    Option.fold ~none:false
      ~some:(fun (cr_key : Common.object_ref) ->
        Common.equal_kind cr_key.Common.kind model.kind
        && Object_ref_map.mem cr_key s.scheduled_reconciles
        && Option.is_none input.recv
        && not (Object_ref_map.mem cr_key s.ongoing_reconciles))
      input.scheduled_cr_key
  in
  let transition (input : action_input) (s : state) : state * action_output =
    (* state_machine.rs:18-38: allocate a reconcile id, insert the initialized
       ongoing reconcile, remove the scheduled entry, advance the allocator; send
       nothing, pass the rpc allocator through. *)
    let no_send =
      { send = Message.Pool.empty; rpc_id_allocator = input.rpc_id_allocator }
    in
    Option.fold ~none:(s, no_send)
      ~some:(fun (cr_key : Common.object_ref) ->
        Option.fold ~none:(s, no_send)
          ~some:(fun (triggering_cr : Dynamic_object.t) ->
            let new_allocator, reconcile_id =
              Reconcile_id_allocator.allocate s.reconcile_id_allocator
            in
            let initialized =
              {
                triggering_cr;
                pending_req_msg = None;
                local_state = model.init ();
                reconcile_id;
              }
            in
            let s' =
              {
                ongoing_reconciles =
                  Object_ref_map.add cr_key initialized s.ongoing_reconciles;
                scheduled_reconciles =
                  Object_ref_map.remove cr_key s.scheduled_reconciles;
                reconcile_id_allocator = new_allocator;
              }
            in
            (s', no_send))
          (Object_ref_map.find_opt cr_key s.scheduled_reconciles))
      input.scheduled_cr_key
  in
  { Action.precondition; transition }

(* Anvil [continue_reconcile] (state_machine.rs:42): run one reconcile_core step
   of an existing ongoing reconcile. *)
let continue_reconcile (model : reconcile_model) ~(controller_id : int) :
    (state, action_input, action_output) Action.t =
  let precondition (input : action_input) (s : state) : bool =
    (* state_machine.rs:44-62: else-branch is [false] (key None disables the
       action). When Some: kind matches, is ongoing, not done, not errored, and
       the recv/pending correlation holds — pending Some requires a matching
       response, pending None requires no message. *)
    Option.fold ~none:false
      ~some:(fun (cr_key : Common.object_ref) ->
        Common.equal_kind cr_key.Common.kind model.kind
        && Option.fold ~none:false
             ~some:(fun (rec_state : ongoing_reconcile) ->
               (not (model.reconcile_done rec_state.local_state))
               && (not (model.reconcile_error rec_state.local_state))
               && Option.fold
                    ~none:(Option.is_none input.recv)
                    ~some:(fun (pending : Message.t) ->
                      Option.fold ~none:false
                        ~some:(fun (recv_msg : Message.t) ->
                          is_response_content recv_msg.Message.content
                          && Message.resp_msg_matches_req_msg recv_msg pending)
                        input.recv)
                    rec_state.pending_req_msg)
             (Object_ref_map.find_opt cr_key s.ongoing_reconciles))
      input.scheduled_cr_key
  in
  let transition (input : action_input) (s : state) : state * action_output =
    (* state_machine.rs:63-104: build the response, invoke reconcile_core, turn a
       produced request into a single sent message (allocating one rpc id), and
       re-insert the ongoing reconcile with its new pending request and local
       state (triggering_cr and reconcile_id preserved). *)
    let passthrough =
      { send = Message.Pool.empty; rpc_id_allocator = input.rpc_id_allocator }
    in
    Option.fold ~none:(s, passthrough)
      ~some:(fun (cr_key : Common.object_ref) ->
        Option.fold ~none:(s, passthrough)
          ~some:(fun (rec_state : ongoing_reconcile) ->
            let resp_o = Option.bind input.recv response_content_of_msg in
            let local_state', req_o =
              model.transition rec_state.triggering_cr resp_o
                rec_state.local_state
            in
            let pending_req_msg, send, rpc_id_allocator' =
              Option.fold
                ~none:(None, Message.Pool.empty, input.rpc_id_allocator)
                ~some:(fun (req : Value.t Io.request_view) ->
                  let next_alloc, req_id =
                    Message.Rpc_id_allocator.allocate input.rpc_id_allocator
                  in
                  let msg =
                    match req with
                    | Io.K_request r ->
                      Message.controller_req_msg controller_id cr_key req_id r
                    | Io.External_request v ->
                      Message.controller_external_req_msg controller_id cr_key
                        req_id v
                  in
                  (Some msg, Message.Pool.singleton msg, next_alloc))
                req_o
            in
            let rec_state' =
              { rec_state with pending_req_msg; local_state = local_state' }
            in
            let s' =
              {
                s with
                ongoing_reconciles =
                  Object_ref_map.add cr_key rec_state' s.ongoing_reconciles;
              }
            in
            (s', { send; rpc_id_allocator = rpc_id_allocator' }))
          (Object_ref_map.find_opt cr_key s.ongoing_reconciles))
      input.scheduled_cr_key
  in
  { Action.precondition; transition }

(* Anvil [end_reconcile] (state_machine.rs:108): remove a done / errored ongoing
   reconcile. Does NOT re-schedule — requeue is an external host's job. *)
let end_reconcile (model : reconcile_model) :
    (state, action_input, action_output) Action.t =
  let precondition (input : action_input) (s : state) : bool =
    (* state_machine.rs:110-120: else-branch [false]; when Some: kind matches, is
       ongoing, done OR errored, no message consumed. *)
    Option.fold ~none:false
      ~some:(fun (cr_key : Common.object_ref) ->
        Common.equal_kind cr_key.Common.kind model.kind
        && Option.fold ~none:false
             ~some:(fun (rec_state : ongoing_reconcile) ->
               (model.reconcile_done rec_state.local_state
               || model.reconcile_error rec_state.local_state)
               && Option.is_none input.recv)
             (Object_ref_map.find_opt cr_key s.ongoing_reconciles))
      input.scheduled_cr_key
  in
  let transition (input : action_input) (s : state) : state * action_output =
    (* state_machine.rs:122-133: remove the ongoing reconcile; send nothing. *)
    let no_send =
      { send = Message.Pool.empty; rpc_id_allocator = input.rpc_id_allocator }
    in
    Option.fold ~none:(s, no_send)
      ~some:(fun (cr_key : Common.object_ref) ->
        ( {
            s with
            ongoing_reconciles =
              Object_ref_map.remove cr_key s.ongoing_reconciles;
          },
          no_send ))
      input.scheduled_cr_key
  in
  { Action.precondition; transition }

(* Anvil [controller().step_to_action] (state_machine.rs:153): exhaustive over the
   three steps, no wildcard. *)
let select_action (model : reconcile_model) ~(controller_id : int) (step : step)
    : (state, action_input, action_output) Action.t =
  match step with
  | Run_scheduled_reconcile -> run_scheduled_reconcile model
  | Continue_reconcile -> continue_reconcile model ~controller_id
  | End_reconcile -> end_reconcile model

(* Anvil [controller().init] (state_machine.rs:139): empty maps, zero-counter
   allocator. *)
let init : state =
  {
    ongoing_reconciles = Object_ref_map.empty;
    scheduled_reconciles = Object_ref_map.empty;
    reconcile_id_allocator = Reconcile_id_allocator.init ();
  }

(* Anvil [controller(model, controller_id)] (state_machine.rs:137): the reconcile
   driver as a {!State_machine.t}. [action_input] passes the host input through
   unchanged (Anvil's identity [action_input], state_machine.rs:160). *)
let controller (model : reconcile_model) ~(controller_id : int) :
    (state, action_input, action_input, action_output, step) State_machine.t =
  {
    State_machine.init =
      (fun (s : state) ->
        Object_ref_map.is_empty s.ongoing_reconciles
        && Object_ref_map.is_empty s.scheduled_reconciles
        && s.reconcile_id_allocator = Reconcile_id_allocator.init ());
    step_to_action = select_action model ~controller_id;
    action_input = (fun (_ : step) (input : action_input) -> input);
  }

(* Adapt a typed installed controller (a {!Controller_pack.CONTROLLER}) into the
   untyped {!reconcile_model} the driver runs. Anvil's [ReconcileModel] is fully
   [Value]-based (types.rs:54); a typed reconciler crosses into it through the
   pack. The reconcile loop threads the local state, external request and
   external response through the reconciler, and Anvil makes all three [Value] —
   so this consumes a pack whose [R.s]/[R.ereq]/[R.eresp] are {!Value.t}. See the
   .mli for why the fully-erased {!Controller_pack.packed} cannot be driven and
   why [kind] must be supplied. *)
let model_of_controller ~(kind : Common.kind)
    (pack :
      (module Controller_pack.CONTROLLER
         with type R.s = Value.t
          and type R.ereq = Value.t
          and type R.eresp = Value.t)) : reconcile_model =
  let module C =
    (val pack
        : Controller_pack.CONTROLLER
        with type R.s = Value.t
         and type R.ereq = Value.t
         and type R.eresp = Value.t)
  in
  {
    kind;
    init = C.R.reconcile_init_state;
    transition =
      (fun (cr : Dynamic_object.t) (resp : Value.t Io.response_view option)
           (local_state : Value.t) ->
        (* Anvil's reconcile_core takes the untyped [DynamicObjectView]; the typed
           [reconcile_core] takes [R.k], recovered via [unmarshal_cr]. Anvil
           discharges the unmarshal by proof; here a failure (never reached for a
           well-formed cr of the gated kind) is the total no-op [(state, None)]. *)
        Result.fold
          ~ok:(fun k -> C.R.reconcile_core ~cr:k ~resp ~state:local_state)
          ~error:(fun (_ : Err.t) -> (local_state, None))
          (C.unmarshal_cr cr));
    reconcile_done = C.R.reconcile_done;
    reconcile_error = C.R.reconcile_error;
  }

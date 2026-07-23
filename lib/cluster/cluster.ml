(* Anvil source: kubernetes_cluster/spec/cluster.rs.

   The compound cluster transition system. Each of the twelve host actions is a
   faithful port of the corresponding Anvil [Cluster] spec fn; the
   message-carrying ones reproduce the "network-baked-in" composition (finding
   8) verbatim: run the host machine, feed its [send] batch to {!Network.deliver}
   with the same [recv], and require BOTH results [Enabled]. Anvil's Hilbert
   [choose] (the host machine's [next_result], and [Cluster::next]'s existential
   step) does not port; it is replaced downstream by explicit enumeration
   ({!enabled_successors}) and, where a compound action wraps a multi-step host,
   by taking the (at most one, for the controller) enabled host step. *)

type controller_and_external = {
  controller : Controller.state;
  external_ : External.state option;
  crash_enabled : bool;
}

type cluster_state = {
  api_server : Api_server.state;
  controller_and_externals : controller_and_external Imap.t;
  network : Network.state;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
  req_drop_enabled : bool;
  pod_monkey_enabled : bool;
}

type controller_model = {
  reconciler :
    (module Controller_pack.CONTROLLER
       with type R.s = Value.t
        and type R.ereq = Value.t
        and type R.eresp = Value.t);
  kind : Common.kind;
  external_model : External.model option;
}

type t = {
  installed_types : Api_server.installed_types;
  controller_models : controller_model Imap.t;
}

(* --- Accessors (Anvil ClusterState::resources / in_flight / ...) --- *)

let resources (s : cluster_state) : Api_server.stored_state = s.api_server.resources
let in_flight (s : cluster_state) : Message.Pool.t = s.network.in_flight

let ongoing_reconciles (s : cluster_state) (controller_id : int) :
    Controller.ongoing_reconcile Object_ref_map.t =
  Option.fold ~none:Object_ref_map.empty
    ~some:(fun cae -> cae.controller.ongoing_reconciles)
    (Imap.find_opt controller_id s.controller_and_externals)

let scheduled_reconciles (s : cluster_state) (controller_id : int) :
    Dynamic_object.t Object_ref_map.t =
  Option.fold ~none:Object_ref_map.empty
    ~some:(fun cae -> cae.controller.scheduled_reconciles)
    (Imap.find_opt controller_id s.controller_and_externals)

let lookup_resource (s : cluster_state) (key : Common.object_ref) :
    Dynamic_object.t option =
  Api_server.lookup key s.api_server.resources

(* --- Action-result combinators (exhaustive on the two-variant [Action.result],
   no wildcard; used so the rest threads options with combinators). --- *)

let enabled_to_opt (r : ('s, unit) Action.result) : 's option =
  match r with Action.Enabled (s', ()) -> Some s' | Action.Disabled -> None

let host_enabled (r : ('s, 'o) Action.result) : ('s * 'o) option =
  match r with Action.Enabled (s', o) -> Some (s', o) | Action.Disabled -> None

(* --- init (cluster.rs:110) --- *)

let init (t : t) (s : cluster_state) : bool =
  Api_server.init s.api_server
  && Builtin_controllers.init ()
  && (Network.network).net_init s.network
  && s.req_drop_enabled
  && s.pod_monkey_enabled
  && Imap.for_all
       (fun key (cm : controller_model) ->
         Option.fold ~none:false
           ~some:(fun cae ->
             let model =
               Controller.model_of_controller ~kind:cm.kind cm.reconciler
             in
             (Controller.controller model ~controller_id:key).init cae.controller
             && cae.crash_enabled
             && Option.fold ~none:true
                  ~some:(fun em ->
                    Option.fold ~none:false
                      ~some:(fun ext -> External.init em ext)
                      cae.external_)
                  cm.external_model)
           (Imap.find_opt key s.controller_and_externals))
       t.controller_models

(* --- api_server_next (cluster.rs:173) --- *)

let api_server_next (t : t) : (cluster_state, Message.t option, unit) Action.t =
  let result (input : Message.t option) (s : cluster_state) =
    let ( let* ) = Option.bind in
    let* aps', (ho : Api_server.action_output) =
      host_enabled
        (Action.next_action_result
           (Api_server.handle_request t.installed_types)
           { Api_server.recv = input }
           s.api_server)
    in
    let msg_ops = { Message.recv = input; send = ho.send } in
    let* net' =
      enabled_to_opt
        (Action.next_action_result Network.deliver msg_ops s.network)
    in
    Some (aps', net')
  in
  {
    Action.precondition =
      (fun input s ->
        Message.received_msg_destined_for input Message.Api_server
        && Option.is_some (result input s));
    transition =
      (fun input s ->
        Option.fold ~none:(s, ())
          ~some:(fun (aps', net') ->
            ({ s with api_server = aps'; network = net' }, ()))
          (result input s));
  }

(* --- builtin_controllers_next / garbage collector (cluster.rs:209) --- *)

let builtin_controllers_next (_ : t) :
    (cluster_state, Builtin_controllers.choice * Common.object_ref, unit) Action.t
    =
  let result ((choice, key) : Builtin_controllers.choice * Common.object_ref)
      (s : cluster_state) =
    let ( let* ) = Option.bind in
    let* _, (ho : Builtin_controllers.action_output) =
      host_enabled
        (Action.next_action_result Builtin_controllers.run_garbage_collector
           {
             Builtin_controllers.choice;
             key;
             rpc_id_allocator = s.rpc_id_allocator;
             resources = s.api_server.resources;
           }
           ())
    in
    let msg_ops = { Message.recv = None; send = ho.send } in
    let* net' =
      enabled_to_opt
        (Action.next_action_result Network.deliver msg_ops s.network)
    in
    Some (ho, net')
  in
  {
    Action.precondition = (fun input s -> Option.is_some (result input s));
    transition =
      (fun input s ->
        Option.fold ~none:(s, ())
          ~some:(fun ((ho : Builtin_controllers.action_output), net') ->
            ( { s with network = net'; rpc_id_allocator = ho.rpc_id_allocator },
              () ))
          (result input s));
  }

(* --- chosen_controller_next / controller_next (cluster.rs:246,263) --- *)

let chosen_controller_next (t : t) (controller_id : int) :
    (cluster_state, Message.t option * Common.object_ref option, unit) Action.t =
  let result ((recv, key_opt) : Message.t option * Common.object_ref option)
      (s : cluster_state) =
    let ( let* ) = Option.bind in
    let* cm = Imap.find_opt controller_id t.controller_models in
    let* cae = Imap.find_opt controller_id s.controller_and_externals in
    let* key = key_opt in
    let model = Controller.model_of_controller ~kind:cm.kind cm.reconciler in
    let sm = Controller.controller model ~controller_id in
    let ci =
      {
        Controller.recv;
        scheduled_cr_key = Some key;
        rpc_id_allocator = s.rpc_id_allocator;
      }
    in
    (* Anvil's host [next_result] chooses one enabled step; run / continue / end
       are mutually exclusive for a fixed key, so at most one is enabled and the
       head is deterministic. *)
    let* hs', (ho : Controller.action_output) =
      List.nth_opt
        (State_machine.next_results sm
           ~steps:
             [
               Controller.Run_scheduled_reconcile;
               Controller.Continue_reconcile;
               Controller.End_reconcile;
             ]
           ci cae.controller)
        0
    in
    let msg_ops = { Message.recv; send = ho.send } in
    let* net' =
      enabled_to_opt
        (Action.next_action_result Network.deliver msg_ops s.network)
    in
    Some (cae, hs', net', ho)
  in
  {
    Action.precondition =
      (fun (recv, key_opt) s ->
        Imap.mem controller_id t.controller_models
        && Option.is_some key_opt
        && Option.fold ~none:false
             ~some:(fun key ->
               Message.received_msg_destined_for recv
                 (Message.Controller (controller_id, key)))
             key_opt
        && Option.is_some (result (recv, key_opt) s));
    transition =
      (fun (recv, key_opt) s ->
        Option.fold ~none:(s, ())
          ~some:(fun (cae, hs', net', (ho : Controller.action_output)) ->
            let cae' = { cae with controller = hs' } in
            ( {
                s with
                controller_and_externals =
                  Imap.add controller_id cae' s.controller_and_externals;
                network = net';
                rpc_id_allocator = ho.rpc_id_allocator;
              },
              () ))
          (result (recv, key_opt) s));
  }

let controller_next (t : t) :
    (cluster_state, int * Message.t option * Common.object_ref option, unit)
    Action.t =
  {
    Action.precondition =
      (fun (controller_id, recv, key) s ->
        (chosen_controller_next t controller_id).precondition (recv, key) s);
    transition =
      (fun (controller_id, recv, key) s ->
        (chosen_controller_next t controller_id).transition (recv, key) s);
  }

(* --- schedule_controller_reconcile (cluster.rs:331) --- *)

let schedule_controller_reconcile (t : t) :
    (cluster_state, int * Common.object_ref, unit) Action.t =
  {
    Action.precondition =
      (fun (controller_id, object_key) s ->
        Option.is_some (lookup_resource s object_key)
        && Imap.mem controller_id t.controller_models
        && Option.fold ~none:false
             ~some:(fun (cm : controller_model) ->
               Common.equal_kind object_key.Common.kind cm.kind)
             (Imap.find_opt controller_id t.controller_models));
    transition =
      (fun (controller_id, object_key) s ->
        let new_state =
          let ( let* ) = Option.bind in
          let* cae = Imap.find_opt controller_id s.controller_and_externals in
          let* obj = lookup_resource s object_key in
          let cae' =
            {
              cae with
              controller =
                {
                  cae.controller with
                  scheduled_reconciles =
                    Object_ref_map.add object_key obj
                      cae.controller.scheduled_reconciles;
                };
            }
          in
          Some
            {
              s with
              controller_and_externals =
                Imap.add controller_id cae' s.controller_and_externals;
            }
        in
        Option.fold ~none:(s, ()) ~some:(fun s' -> (s', ())) new_state);
  }

(* --- restart_controller (cluster.rs:377) --- *)

let restart_controller (t : t) : (cluster_state, int, unit) Action.t =
  {
    Action.precondition =
      (fun controller_id s ->
        Imap.mem controller_id t.controller_models
        && Option.fold ~none:false
             ~some:(fun cae -> cae.crash_enabled)
             (Imap.find_opt controller_id s.controller_and_externals));
    transition =
      (fun controller_id s ->
        let new_state =
          Option.map
            (fun cae ->
              let cae' =
                {
                  cae with
                  controller =
                    {
                      Controller.ongoing_reconciles = Object_ref_map.empty;
                      scheduled_reconciles = Object_ref_map.empty;
                      reconcile_id_allocator =
                        cae.controller.reconcile_id_allocator;
                    };
                }
              in
              {
                s with
                controller_and_externals =
                  Imap.add controller_id cae' s.controller_and_externals;
              })
            (Imap.find_opt controller_id s.controller_and_externals)
        in
        Option.fold ~none:(s, ()) ~some:(fun s' -> (s', ())) new_state);
  }

(* --- disable_crash (cluster.rs:407) --- *)

let disable_crash (t : t) : (cluster_state, int, unit) Action.t =
  {
    Action.precondition =
      (fun controller_id _s -> Imap.mem controller_id t.controller_models);
    transition =
      (fun controller_id s ->
        let new_state =
          Option.map
            (fun cae ->
              let cae' = { cae with crash_enabled = false } in
              {
                s with
                controller_and_externals =
                  Imap.add controller_id cae' s.controller_and_externals;
              })
            (Imap.find_opt controller_id s.controller_and_externals)
        in
        Option.fold ~none:(s, ()) ~some:(fun s' -> (s', ())) new_state);
  }

(* --- drop_req (cluster.rs:439) --- *)

let drop_req (_ : t) :
    (cluster_state, Message.t * Api_method.api_error, unit) Action.t =
  let result ((req_msg, api_err) : Message.t * Api_method.api_error)
      (s : cluster_state) =
    let resp = Message.form_matched_err_resp_msg req_msg api_err in
    let msg_ops =
      { Message.recv = Some req_msg; send = Message.Pool.singleton resp }
    in
    enabled_to_opt (Action.next_action_result Network.deliver msg_ops s.network)
  in
  {
    Action.precondition =
      (fun ((req_msg, _api_err) as input) s ->
        s.req_drop_enabled
        && (match req_msg.Message.dst with
           | Message.Api_server -> true
           | Message.Builtin_controller | Message.Controller _
           | Message.External _ | Message.Pod_monkey -> false)
        && (match req_msg.Message.content with
           | Message.Api_request _ -> true
           | Message.Api_response _ | Message.External_request _
           | Message.External_response _ -> false)
        && Option.is_some (result input s));
    transition =
      (fun input s ->
        Option.fold ~none:(s, ())
          ~some:(fun net' -> ({ s with network = net' }, ()))
          (result input s));
  }

(* --- disable_req_drop (cluster.rs:472) --- *)

let disable_req_drop (_ : t) : (cluster_state, unit, unit) Action.t =
  {
    Action.precondition = (fun () _s -> true);
    transition = (fun () s -> ({ s with req_drop_enabled = false }, ()));
  }

(* --- pod_monkey_next (cluster.rs:492); the four pod operations (all
   precondition-[true]) that Anvil's [PodMonkeyStep(PodView)] hides in the host
   [choose] are made an explicit [op] parameter. --- *)

let pod_op_action (op : Pod_monkey.step) :
    (Pod_monkey.state, Pod_monkey.action_input, Pod_monkey.action_output) Action.t
    =
  match op with
  | Pod_monkey.Create_pod -> Pod_monkey.create_pod
  | Pod_monkey.Update_pod -> Pod_monkey.update_pod
  | Pod_monkey.Update_pod_status -> Pod_monkey.update_pod_status
  | Pod_monkey.Delete_pod -> Pod_monkey.delete_pod

let pod_monkey_next (_ : t) (op : Pod_monkey.step) :
    (cluster_state, Pod.t, unit) Action.t =
  let act = pod_op_action op in
  let result (pod : Pod.t) (s : cluster_state) =
    let ( let* ) = Option.bind in
    let* _, (ho : Pod_monkey.action_output) =
      host_enabled
        (Action.next_action_result act
           { Pod_monkey.pod; rpc_id_allocator = s.rpc_id_allocator }
           ())
    in
    let msg_ops = { Message.recv = None; send = ho.send } in
    let* net' =
      enabled_to_opt
        (Action.next_action_result Network.deliver msg_ops s.network)
    in
    Some (ho, net')
  in
  {
    Action.precondition =
      (fun pod s -> s.pod_monkey_enabled && Option.is_some (result pod s));
    transition =
      (fun pod s ->
        Option.fold ~none:(s, ())
          ~some:(fun ((ho : Pod_monkey.action_output), net') ->
            ( { s with network = net'; rpc_id_allocator = ho.rpc_id_allocator },
              () ))
          (result pod s));
  }

let pod_monkey_actions (t : t) : (cluster_state, Pod.t, unit) Action.t list =
  List.map (pod_monkey_next t)
    [
      Pod_monkey.Create_pod;
      Pod_monkey.Update_pod;
      Pod_monkey.Update_pod_status;
      Pod_monkey.Delete_pod;
    ]

(* --- disable_pod_monkey (cluster.rs:526) --- *)

let disable_pod_monkey (_ : t) : (cluster_state, unit, unit) Action.t =
  {
    Action.precondition = (fun () _s -> true);
    transition = (fun () s -> ({ s with pod_monkey_enabled = false }, ()));
  }

(* --- chosen_external_next / external_next (cluster.rs:543,560) --- *)

let chosen_external_next (t : t) (controller_id : int) :
    (cluster_state, Message.t option, unit) Action.t =
  let result (recv : Message.t option) (s : cluster_state) =
    let ( let* ) = Option.bind in
    let* cm = Imap.find_opt controller_id t.controller_models in
    let* em = cm.external_model in
    let* cae = Imap.find_opt controller_id s.controller_and_externals in
    let* ext = cae.external_ in
    let* ext', (ho : External.action_output) =
      host_enabled
        (Action.next_action_result
           (External.handle_external_request em)
           { External.recv; resources = s.api_server.resources }
           ext)
    in
    let msg_ops = { Message.recv; send = ho.send } in
    let* net' =
      enabled_to_opt
        (Action.next_action_result Network.deliver msg_ops s.network)
    in
    Some (cae, ext', net')
  in
  {
    Action.precondition =
      (fun recv s ->
        Imap.mem controller_id t.controller_models
        && Option.fold ~none:false
             ~some:(fun (cm : controller_model) ->
               Option.is_some cm.external_model)
             (Imap.find_opt controller_id t.controller_models)
        && Message.received_msg_destined_for recv
             (Message.External controller_id)
        && Option.is_some (result recv s));
    transition =
      (fun recv s ->
        Option.fold ~none:(s, ())
          ~some:(fun (cae, ext', net') ->
            let cae' = { cae with external_ = Some ext' } in
            ( {
                s with
                controller_and_externals =
                  Imap.add controller_id cae' s.controller_and_externals;
                network = net';
              },
              () ))
          (result recv s));
  }

let external_next (t : t) :
    (cluster_state, int * Message.t option, unit) Action.t =
  {
    Action.precondition =
      (fun (controller_id, recv) s ->
        (chosen_external_next t controller_id).precondition recv s);
    transition =
      (fun (controller_id, recv) s ->
        (chosen_external_next t controller_id).transition recv s);
  }

(* --- stutter (cluster.rs:599) --- *)

let stutter (_ : t) : (cluster_state, unit, unit) Action.t =
  {
    Action.precondition = (fun () _s -> true);
    transition = (fun () s -> (s, ()));
  }

(* --- next_step (cluster.rs:153): exhaustive twelve-arm dispatch --- *)

let next_step (t : t) (s : cluster_state) (step : Step.t) (s' : cluster_state) :
    bool =
  match step with
  | Step.Api_server_step recv -> Action.forward (api_server_next t) recv s s'
  | Step.Builtin_controllers_step (choice, key) ->
      Action.forward (builtin_controllers_next t) (choice, key) s s'
  | Step.Controller_step (controller_id, recv, key) ->
      Action.forward (controller_next t) (controller_id, recv, key) s s'
  | Step.Schedule_controller_reconcile_step (controller_id, key) ->
      Action.forward (schedule_controller_reconcile t) (controller_id, key) s s'
  | Step.Restart_controller_step controller_id ->
      Action.forward (restart_controller t) controller_id s s'
  | Step.Disable_crash_step controller_id ->
      Action.forward (disable_crash t) controller_id s s'
  | Step.Drop_req_step (msg, err) -> Action.forward (drop_req t) (msg, err) s s'
  | Step.Disable_req_drop_step -> Action.forward (disable_req_drop t) () s s'
  | Step.Pod_monkey_step pod ->
      List.exists (fun act -> Action.forward act pod s s') (pod_monkey_actions t)
  | Step.Disable_pod_monkey_step ->
      Action.forward (disable_pod_monkey t) () s s'
  | Step.External_step (controller_id, recv) ->
      Action.forward (external_next t) (controller_id, recv) s s'
  | Step.Stutter_step -> Action.forward (stutter t) () s s'

let next_rel = next_step

(* --- enabled_successors (finding 14): bounded, choose-free enumeration --- *)

let enabled_successors (b : Bound.t) (t : t) (s : cluster_state) :
    (Step.t * cluster_state) list =
  let take n xs = List.filteri (fun i _ -> i < n) xs in
  let succ step res = Option.map (fun s' -> (step, s')) (enabled_to_opt res) in
  let distinct_in = Message.Pool.distinct s.network.in_flight in
  (* messages destined for the api server, capped by max_in_flight *)
  let for_api =
    take b.max_in_flight
      (List.filter
         (fun (m : Message.t) -> Message.equal_host_id m.dst Message.Api_server)
         distinct_in)
  in
  let api_steps =
    List.filter_map
      (fun recv ->
        succ (Step.Api_server_step recv)
          (Action.next_action_result (api_server_next t) recv s))
      (None :: List.map (fun m -> Some m) for_api)
  in
  (* drop_req: each in-flight api-request crossed with every api error. The
     error domain is finite by construction (twelve variants), so it is
     enumerated in full and needs no Bound.t field. *)
  let for_api_req =
    List.filter
      (fun (m : Message.t) ->
        match m.content with
        | Message.Api_request _ -> true
        | Message.Api_response _ | Message.External_request _
        | Message.External_response _ -> false)
      for_api
  in
  let all_api_errors =
    Api_method.
      [
        Bad_request;
        Conflict;
        Forbidden;
        Invalid;
        Object_not_found;
        Object_already_exists;
        Not_supported;
        Internal_error;
        Timeout;
        Server_timeout;
        Transaction_abort;
        Other;
      ]
  in
  let drop_steps =
    List.concat_map
      (fun (m : Message.t) ->
        List.filter_map
          (fun err ->
            succ (Step.Drop_req_step (m, err))
              (Action.next_action_result (drop_req t) (m, err) s))
          all_api_errors)
      for_api_req
  in
  (* controller ids, capped by max_controllers; reused by controller / schedule
     / restart / disable_crash / external families *)
  let controller_ids =
    take b.max_controllers (List.map fst (Imap.bindings t.controller_models))
  in
  let controller_steps =
    List.concat_map
      (fun controller_id ->
        let recvs =
          None
          :: List.map
               (fun m -> Some m)
               (take b.max_in_flight
                  (List.filter
                     (fun (m : Message.t) ->
                       match m.dst with
                       | Message.Controller (cid, _) -> cid = controller_id
                       | Message.Api_server | Message.Builtin_controller
                       | Message.External _ | Message.Pod_monkey -> false)
                     distinct_in))
        in
        (* scheduled_cr_key ranges over scheduled AND ongoing keys: continue /
           end reconcile steps key on ongoing_reconciles (run removes the key
           from scheduled), so ongoing keys must be enumerated too or those
           steps become unreachable -- honouring "never silently truncate". *)
        let keys =
          List.map fst
            (Object_ref_map.bindings (scheduled_reconciles s controller_id))
          @ List.map fst
              (Object_ref_map.bindings (ongoing_reconciles s controller_id))
        in
        List.concat_map
          (fun recv ->
            List.filter_map
              (fun key ->
                succ
                  (Step.Controller_step (controller_id, recv, Some key))
                  (Action.next_action_result (controller_next t)
                     (controller_id, recv, Some key)
                     s))
              keys)
          recvs)
      controller_ids
  in
  let schedule_steps =
    List.concat_map
      (fun controller_id ->
        Option.fold ~none:[]
          ~some:(fun (cm : controller_model) ->
            let keys =
              take b.max_objects_per_kind
                (List.filter_map
                   (fun (k, _) ->
                     if Common.equal_kind k.Common.kind cm.kind then Some k
                     else None)
                   (Object_ref_map.bindings s.api_server.resources))
            in
            List.filter_map
              (fun key ->
                succ
                  (Step.Schedule_controller_reconcile_step (controller_id, key))
                  (Action.next_action_result (schedule_controller_reconcile t)
                     (controller_id, key)
                     s))
              keys)
          (Imap.find_opt controller_id t.controller_models))
      controller_ids
  in
  let restart_steps =
    List.filter_map
      (fun controller_id ->
        succ
          (Step.Restart_controller_step controller_id)
          (Action.next_action_result (restart_controller t) controller_id s))
      controller_ids
  in
  let disable_crash_steps =
    List.filter_map
      (fun controller_id ->
        succ
          (Step.Disable_crash_step controller_id)
          (Action.next_action_result (disable_crash t) controller_id s))
      controller_ids
  in
  let external_steps =
    List.concat_map
      (fun controller_id ->
        let recvs =
          None
          :: List.map
               (fun m -> Some m)
               (take b.max_in_flight
                  (List.filter
                     (fun (m : Message.t) ->
                       match m.dst with
                       | Message.External cid -> cid = controller_id
                       | Message.Api_server | Message.Builtin_controller
                       | Message.Controller _ | Message.Pod_monkey -> false)
                     distinct_in))
        in
        List.filter_map
          (fun recv ->
            succ
              (Step.External_step (controller_id, recv))
              (Action.next_action_result (external_next t) (controller_id, recv)
                 s))
          recvs)
      controller_ids
  in
  (* builtin / garbage collector: candidate keys are the stored object keys,
     capped by max_objects_per_kind PER KIND (like schedule_steps / pod_candidates
     which filter to a kind before [take]). A single cross-kind [take] would apply
     the per-kind cap to the whole resource set and silently drop GC candidates
     for orphans of later-sorting kinds. *)
  let all_gc_keys = List.map fst (Object_ref_map.bindings s.api_server.resources) in
  let gc_kinds =
    List.fold_left
      (fun acc (k : Common.object_ref) ->
        if List.exists (Common.equal_kind k.kind) acc then acc else k.kind :: acc)
      [] all_gc_keys
  in
  let gc_keys =
    List.concat_map
      (fun kd ->
        take b.max_objects_per_kind
          (List.filter (fun (k : Common.object_ref) -> Common.equal_kind k.kind kd) all_gc_keys))
      gc_kinds
  in
  let builtin_steps =
    List.filter_map
      (fun key ->
        succ
          (Step.Builtin_controllers_step
             (Builtin_controllers.Garbage_collector, key))
          (Action.next_action_result (builtin_controllers_next t)
             (Builtin_controllers.Garbage_collector, key)
             s))
      gc_keys
  in
  (* pod monkey: candidate pods are the stored Pod objects, capped by
     max_objects_per_kind. This excludes pod-monkey states reached from pods
     never present in etcd (the object-count-symmetry bug class of
     max_objects_per_kind). *)
  let pod_candidates =
    take b.max_objects_per_kind
      (List.filter_map
         (fun (k, obj) ->
           if Common.equal_kind k.Common.kind Common.Pod then
             Result.to_option (Pod.unmarshal obj)
           else None)
         (Object_ref_map.bindings s.api_server.resources))
  in
  let pod_steps =
    List.concat_map
      (fun pod ->
        List.filter_map
          (fun op ->
            succ (Step.Pod_monkey_step pod)
              (Action.next_action_result (pod_monkey_next t op) pod s))
          [
            Pod_monkey.Create_pod;
            Pod_monkey.Update_pod;
            Pod_monkey.Update_pod_status;
            Pod_monkey.Delete_pod;
          ])
      pod_candidates
  in
  let singleton_steps =
    List.filter_map
      (fun (step, res) -> succ step res)
      [
        ( Step.Disable_req_drop_step,
          Action.next_action_result (disable_req_drop t) () s );
        ( Step.Disable_pod_monkey_step,
          Action.next_action_result (disable_pod_monkey t) () s );
        (Step.Stutter_step, Action.next_action_result (stutter t) () s);
      ]
  in
  List.concat
    [
      api_steps;
      drop_steps;
      builtin_steps;
      controller_steps;
      schedule_steps;
      restart_steps;
      disable_crash_steps;
      external_steps;
      pod_steps;
      singleton_steps;
    ]

(* Reconcile-driver tests (BUILD-SPEC-P2 "## Tests", t_reconcile_driver):
   a trivial RECONCILER (one create then done), installed as a first-class-module
   pack and adapted through [Controller.model_of_controller], driven the full
   loop: run_scheduled_reconcile -> continue_reconcile (emits a create request)
   -> [api server creates and replies] -> continue_reconcile (reaches done) ->
   end_reconcile (removes the reconcile). The pending request captured by the
   first continue is matched by [Message.resp_msg_matches_req_msg] against the
   response the api server would send. *)

let child_obj =
  Dynamic_object.make ~kind:Common.Config_map
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name "child"
      |> Object_meta.with_namespace "ns")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

(* One-create-then-done reconciler: on the first step (no response yet) it emits a
   Kubernetes create request; on the next step (response delivered) it reports
   done. *)
module Create_R = struct
  type s = Value.t
  type k = Dynamic_object.t
  type ereq = Value.t
  type eresp = Value.t

  let reconcile_init_state () = Value.of_json (`String "start")

  let reconcile_core ~cr:(_ : k) ~(resp : eresp Io.response_view option)
      ~(state : s) : s * ereq Io.request_view option =
    let _ = state in
    Option.fold resp
      ~none:
        ( Value.of_json (`String "created"),
          Some
            (Io.K_request
               (Api_method.Create_request { Api_method.namespace = "ns"; obj = child_obj }))
        )
      ~some:(fun _ -> (Value.of_json (`String "done"), None))

  let reconcile_done (s : s) = Value.equal s (Value.of_json (`String "done"))
  let reconcile_error (_ : s) = false
end

module Create_C :
  Controller_pack.CONTROLLER
    with type R.s = Value.t
     and type R.ereq = Value.t
     and type R.eresp = Value.t = struct
  module R = Create_R

  let id = 0
  let marshal_state (s : R.s) = s
  let unmarshal_cr (o : Dynamic_object.t) : R.k Res.t = Res.ok o
end

let model = Controller.model_of_controller ~kind:Common.Config_map (module Create_C)

let cr_ref = { Common.kind = Common.Config_map; name = "cm"; namespace = "ns" }

let cr_obj =
  Dynamic_object.make ~kind:Common.Config_map
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name "cm"
      |> Object_meta.with_namespace "ns")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let alloc0 = Message.Rpc_id_allocator.init ()

(* Initial controller state with the cr already scheduled (the schedule step is
   exercised in t_cluster; here we start from a scheduled cr). *)
let s0 : Controller.state =
  {
    Controller.init with
    Controller.scheduled_reconciles = Object_ref_map.add cr_ref cr_obj Object_ref_map.empty;
  }

let ci ~recv ~alloc : Controller.action_input =
  { Controller.recv; scheduled_cr_key = Some cr_ref; rpc_id_allocator = alloc }

let test_driver () =
  (* 1. run_scheduled_reconcile: scheduled -> ongoing. *)
  let run = Controller.run_scheduled_reconcile model in
  let in1 = ci ~recv:None ~alloc:alloc0 in
  Alcotest.(check bool) "run enabled" true (run.Action.precondition in1 s0);
  let s1, _o1 = run.Action.transition in1 s0 in
  Alcotest.(check bool) "cr is now ongoing" true
    (Object_ref_map.mem cr_ref s1.Controller.ongoing_reconciles);
  Alcotest.(check bool) "cr no longer scheduled" false
    (Object_ref_map.mem cr_ref s1.Controller.scheduled_reconciles);

  (* 2. continue_reconcile #1: reconcile_core emits a create request. *)
  let cont = Controller.continue_reconcile model ~controller_id:0 in
  let in2 = ci ~recv:None ~alloc:alloc0 in
  Alcotest.(check bool) "continue #1 enabled" true (cont.Action.precondition in2 s1);
  let s2, (o2 : Controller.action_output) = cont.Action.transition in2 s1 in
  Alcotest.(check int) "one request message sent" 1 (Message.Pool.cardinal o2.send);
  let pending =
    Option.bind
      (Object_ref_map.find_opt cr_ref s2.Controller.ongoing_reconciles)
      (fun (r : Controller.ongoing_reconcile) -> r.pending_req_msg)
  in
  Alcotest.(check bool) "pending request recorded" true (Option.is_some pending);

  (* 3. the api server would create [child] and reply; the response matches the
     pending request (per resp_msg_matches_req_msg). *)
  let resp_msg_opt =
    Option.map
      (fun (p : Message.t) ->
        Message.form_create_resp_msg p { Api_method.res = Ok child_obj })
      pending
  in
  Alcotest.(check bool) "response matches the pending request" true
    (Option.fold pending ~none:false ~some:(fun p ->
         Option.fold resp_msg_opt ~none:false ~some:(fun resp ->
             Message.resp_msg_matches_req_msg resp p)));

  (* 4. continue_reconcile #2 with the matching response: reconcile reaches done. *)
  let in3 = ci ~recv:resp_msg_opt ~alloc:o2.rpc_id_allocator in
  Alcotest.(check bool) "continue #2 enabled" true (cont.Action.precondition in3 s2);
  let s3, _o3 = cont.Action.transition in3 s2 in
  Alcotest.(check bool) "reconcile reached done" true
    (Option.fold
       (Object_ref_map.find_opt cr_ref s3.Controller.ongoing_reconciles)
       ~none:false
       ~some:(fun (r : Controller.ongoing_reconcile) ->
         model.Controller.reconcile_done r.local_state));

  (* 5. end_reconcile: the finished reconcile is removed. *)
  let fin = Controller.end_reconcile model in
  let in4 = ci ~recv:None ~alloc:o2.rpc_id_allocator in
  Alcotest.(check bool) "end enabled" true (fin.Action.precondition in4 s3);
  let s4, _o4 = fin.Action.transition in4 s3 in
  Alcotest.(check bool) "reconcile removed" false
    (Object_ref_map.mem cr_ref s4.Controller.ongoing_reconciles)

let () =
  Alcotest.run "reconcile_driver"
    [ ("loop", [ Alcotest.test_case "run -> create -> continue -> end" `Quick test_driver ]) ]

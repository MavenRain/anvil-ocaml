(* VReplicaSet end-to-end driver test (BUILD-SPEC-P3 "## 8. Tests",
   t_vreplica_set_driver; mirrors t_reconcile_driver). The real
   Vreplica_set_pack.Controller is installed through
   [Controller.model_of_controller] and driven the full reconcile loop for a
   well-formed VReplicaSet (desired 1, no existing pods):

     run_scheduled_reconcile
       -> continue (List_request) -> feed List_response Ok []
       -> continue (Create_request) -> feed Create_response Ok pod
       -> continue (Get_then_update_status_request) -> feed the status response
       -> continue reaches Done -> end_reconcile removes it.

   At every hop the pending request is matched by [resp_msg_matches_req_msg] and
   the local state round-trips through the pack codec (the pack + erase adapter's
   integration proof). *)

let labels_xy = Smap.add "app" "x" Smap.empty

(* The vrs carries exactly one controller owner reference (update_vrs_replicas
   requires it) plus name/namespace/uid (make_pod / controller_owner_ref). *)
let parent_ref : Owner_reference.t =
  {
    block_owner_deletion = Some true;
    controller = Some true;
    kind = Common.Custom_resource "deployment";
    name = "parent";
    uid = Common.Uid.of_int 9;
  }

let cr_metadata : Object_meta.t =
  {
    (Object_meta.default ()) with
    name = Some "vrs1";
    namespace = Some "ns";
    uid = Some (Common.Uid.of_int 1);
    owner_references = Some [ parent_ref ];
  }

let cr_spec : Vreplica_set.vrs_spec =
  Vreplica_set.vrs_spec_default ()
  |> Vreplica_set.spec_with_replicas 1
  |> Vreplica_set.spec_with_selector { match_labels = Some labels_xy }
  |> Vreplica_set.spec_with_template
       { metadata = Some (Object_meta.default ()); spec = None }

let vrs : Vreplica_set.t =
  Vreplica_set.make ~metadata:cr_metadata ~spec:cr_spec ~status:None

let cr_ref = { Common.kind = Vreplica_set.kind; name = "vrs1"; namespace = "ns" }
let cr_obj = Vreplica_set.marshal vrs

(* An arbitrary pod object the api server would return from the Create. *)
let created_pod =
  Pod.marshal
    (Pod.make
       ~metadata:(Object_meta.default () |> Object_meta.with_name "vreplicaset-vrs1-x")
       ~spec:None ~status:None)

let model =
  Controller.model_of_controller ~kind:Vreplica_set.kind
    (module Vreplica_set_pack.Controller)

let alloc0 = Message.Rpc_id_allocator.init ()

let s0 : Controller.state =
  {
    Controller.init with
    Controller.scheduled_reconciles =
      Object_ref_map.add cr_ref cr_obj Object_ref_map.empty;
  }

let ci ~recv ~alloc : Controller.action_input =
  { Controller.recv; scheduled_cr_key = Some cr_ref; rpc_id_allocator = alloc }

let pending_of (s : Controller.state) : Message.t option =
  Option.bind
    (Object_ref_map.find_opt cr_ref s.Controller.ongoing_reconciles)
    (fun (r : Controller.ongoing_reconcile) -> r.pending_req_msg)

(* The local state at [cr_ref] round-trips through the pack codec. *)
let check_state_roundtrips (label : string) (s : Controller.state) : unit =
  Alcotest.(check bool) (label ^ ": local state unmarshals") true
    (Option.fold
       (Object_ref_map.find_opt cr_ref s.Controller.ongoing_reconciles)
       ~none:false
       ~some:(fun (r : Controller.ongoing_reconcile) ->
         Result.fold (Vreplica_set_pack.unmarshal_state r.local_state)
           ~error:(fun (_ : Err.t) -> false)
           ~ok:(fun st ->
             Value.equal r.local_state (Vreplica_set_pack.marshal_state st))))

(* One continue hop: assert it is enabled, transition, assert one request went
   out and the pending request is answered by [form resp] (matches the request);
   return the produced response message + next state + rpc allocator. *)
let hop (cont : (Controller.state, Controller.action_input, Controller.action_output) Action.t)
    ~(label : string) ~(recv : Message.t option) ~(alloc : Message.Rpc_id_allocator.t)
    ~(s : Controller.state)
    ~(form : Message.t -> Message.t) :
    Message.t option * Controller.state * Message.Rpc_id_allocator.t =
  let input = ci ~recv ~alloc in
  Alcotest.(check bool) (label ^ " enabled") true (cont.Action.precondition input s);
  let s', (o : Controller.action_output) = cont.Action.transition input s in
  Alcotest.(check int) (label ^ ": one request sent") 1 (Message.Pool.cardinal o.send);
  check_state_roundtrips label s';
  let pending = pending_of s' in
  let resp = Option.map form pending in
  Alcotest.(check bool) (label ^ ": response matches request") true
    (Option.fold pending ~none:false ~some:(fun p ->
         Option.fold resp ~none:false ~some:(fun r ->
             Message.resp_msg_matches_req_msg r p)));
  (resp, s', o.rpc_id_allocator)

let test_driver () =
  (* run_scheduled_reconcile: scheduled -> ongoing. *)
  let run = Controller.run_scheduled_reconcile model in
  let in1 = ci ~recv:None ~alloc:alloc0 in
  Alcotest.(check bool) "run enabled" true (run.Action.precondition in1 s0);
  let s1, _ = run.Action.transition in1 s0 in
  Alcotest.(check bool) "cr now ongoing" true
    (Object_ref_map.mem cr_ref s1.Controller.ongoing_reconciles);

  let cont = Controller.continue_reconcile model ~controller_id:0 in

  (* continue #1: Init -> List_request; feed List_response Ok []. *)
  let resp1, s2, a2 =
    hop cont ~label:"list" ~recv:None ~alloc:alloc0 ~s:s1 ~form:(fun p ->
        Message.form_list_resp_msg p { Api_method.res = Ok [] })
  in

  (* continue #2: After_list_pods (scale up) -> Create_request; feed the pod. *)
  let resp2, s3, a3 =
    hop cont ~label:"create" ~recv:resp1 ~alloc:a2 ~s:s2 ~form:(fun p ->
        Message.form_create_resp_msg p { Api_method.res = Ok created_pod })
  in

  (* continue #3: After_create_pod 0 -> Get_then_update_status_request. *)
  let resp3, s4, a4 =
    hop cont ~label:"status" ~recv:resp2 ~alloc:a3 ~s:s3 ~form:(fun p ->
        Message.form_get_then_update_status_resp_msg p { Api_method.res = Ok created_pod })
  in

  (* continue #4: After_update_vrs_status + Ok -> Done (no further request). *)
  let in5 = ci ~recv:resp3 ~alloc:a4 in
  Alcotest.(check bool) "done-step enabled" true (cont.Action.precondition in5 s4);
  let s5, (o5 : Controller.action_output) = cont.Action.transition in5 s4 in
  Alcotest.(check int) "no request at done step" 0 (Message.Pool.cardinal o5.send);
  Alcotest.(check bool) "reconcile reached Done" true
    (Option.fold
       (Object_ref_map.find_opt cr_ref s5.Controller.ongoing_reconciles)
       ~none:false
       ~some:(fun (r : Controller.ongoing_reconcile) ->
         model.Controller.reconcile_done r.local_state));

  (* end_reconcile: the finished reconcile is removed. *)
  let fin = Controller.end_reconcile model in
  let in6 = ci ~recv:None ~alloc:o5.rpc_id_allocator in
  Alcotest.(check bool) "end enabled" true (fin.Action.precondition in6 s5);
  let s6, _ = fin.Action.transition in6 s5 in
  Alcotest.(check bool) "reconcile removed" false
    (Object_ref_map.mem cr_ref s6.Controller.ongoing_reconciles)

let () =
  Alcotest.run "vreplica_set_driver"
    [
      ( "loop",
        [
          Alcotest.test_case "run -> list -> create -> status -> done -> end"
            `Quick test_driver;
        ] );
    ]

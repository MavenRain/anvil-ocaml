(* VDeployment reconcile_core tests (BUILD-SPEC-P9 §5, t_v_deployment_reconciler;
   mirrors t_vreplica_set_reconciler.ml): every transition of the pure typed core
   driven with hand-built inputs — Init -> List(vreplicaset); empty list -> create;
   a matching ready VReplicaSet at replicas < desired -> scale; create Ok -> ensure;
   scale Ok -> ensure; the After_ensure_new_vrs barrier (index 0 -> Done, an old
   vrs -> scale-down); the scale-down loop -> Done; and Error routing on wrong-kind
   / absent / error responses, an out-of-range cursor and a missing namespace. The
   emitted request is named by its Kubernetes verb (exhaustive over the api_request
   sum); step assertions use [V.step_equal]. *)

module V = V_deployment_reconciler

let labels_xy = Smap.add "app" "x" Smap.empty
let selector : Label_selector.t = { match_labels = Some labels_xy }
let tmpl_metadata = Object_meta.with_labels labels_xy (Object_meta.default ())

let good_template : Pod_template_spec.t =
  { metadata = Some tmpl_metadata; spec = Some (Pod_spec.default ()) }

(* The VDeployment's controller owner reference (= [controller_owner_ref cr]):
   the vd1/uid-1 vdeployment-kind ref that every owned VReplicaSet carries. *)
let vd_owner_ref : Owner_reference.t =
  {
    block_owner_deletion = Some true;
    controller = Some true;
    kind = V_deployment.kind;
    name = "vd1";
    uid = Common.Uid.of_int 1;
  }

let vd_metadata : Object_meta.t =
  {
    (Object_meta.default ()) with
    name = Some "vd1";
    namespace = Some "ns";
    uid = Some (Common.Uid.of_int 1);
    resource_version = Some (Common.Resource_version.of_int 0);
  }

let vd_cr (desired : int) : V_deployment.t =
  V_deployment.make ~metadata:vd_metadata
    ~spec:
      {
        (V_deployment.vd_spec_default ()) with
        replicas = Some desired;
        selector;
        template = good_template;
      }
    ~status:()

(* A well-formed VReplicaSet the VDeployment owns: matching selector/template, in
   [ns], carrying [vd_owner_ref], so [valid_owned_vrs] and
   [match_template_without_hash] both hold. *)
let owned_vrs ~(name : string) ~(uid : int) ~(replicas : int option)
    ~(status : Vreplica_set.vrs_status option) : Vreplica_set.t =
  Vreplica_set.make
    ~metadata:
      {
        (Object_meta.default ()) with
        name = Some name;
        namespace = Some "ns";
        uid = Some (Common.Uid.of_int uid);
        owner_references = Some [ vd_owner_ref ];
      }
    ~spec:{ Vreplica_set.replicas; selector; template = Some good_template }
    ~status

(* A ready VReplicaSet at [replicas] whose status reports the same count (so the
   readiness gate in [mismatch_replicas] is satisfied). *)
let ready_vrs ~(name : string) ~(uid : int) ~(replicas : int) : Vreplica_set.t =
  owned_vrs ~name ~uid ~replicas:(Some replicas)
    ~status:(Some { Vreplica_set.replicas })

(* -- output inspectors -- *)

let step_of (s : V.s) : V.step = s.reconcile_step

let check_step (msg : string) (expected : V.step) (s : V.s) : unit =
  Alcotest.(check bool) msg true (V.step_equal expected (step_of s))

(* Name the emitted request by its Kubernetes verb (exhaustive over api_request;
   the External arm is void). *)
let req_kind (r : Io.void Io.request_view option) : string =
  Option.fold r ~none:"none" ~some:(fun (rv : Io.void Io.request_view) ->
      match rv with
      | Io.K_request q -> (
        match q with
        | Api_method.List_request _ -> "list"
        | Api_method.Create_request _ -> "create"
        | Api_method.Get_then_update_request _ -> "get_then_update"
        | Api_method.Get_request _ | Api_method.Delete_request _
        | Api_method.Update_request _ | Api_method.Update_status_request _
        | Api_method.Get_then_delete_request _
        | Api_method.Get_then_update_status_request _ ->
          "other")
      | Io.External_request _ -> .)

let check_req (msg : string) (expected : string)
    (out : V.s * Io.void Io.request_view option) : unit =
  Alcotest.(check string) msg expected (req_kind (snd out))

(* The kind carried by an emitted List request, if any (exhaustive over
   api_request). *)
let list_kind (r : Io.void Io.request_view option) : Common.kind option =
  Option.bind r (fun (rv : Io.void Io.request_view) ->
      match rv with
      | Io.K_request q -> (
        match q with
        | Api_method.List_request { Api_method.kind; namespace = _ } -> Some kind
        | Api_method.Create_request _ | Api_method.Get_request _
        | Api_method.Delete_request _ | Api_method.Update_request _
        | Api_method.Update_status_request _ | Api_method.Get_then_delete_request _
        | Api_method.Get_then_update_request _
        | Api_method.Get_then_update_status_request _ ->
          None)
      | Io.External_request _ -> .)

(* -- response builders (K_response only; External_response is void) -- *)

let list_resp (objs : Dynamic_object.t list) : Io.void Io.response_view option =
  Some (Io.K_response (Api_method.List_response { res = Ok objs }))

let list_err : Io.void Io.response_view option =
  Some
    (Io.K_response (Api_method.List_response { res = Error Api_method.Internal_error }))

let create_resp (vrs : Vreplica_set.t) : Io.void Io.response_view option =
  Some (Io.K_response (Api_method.Create_response { res = Ok (Vreplica_set.marshal vrs) }))

let get_then_update_resp (vrs : Vreplica_set.t) : Io.void Io.response_view option =
  Some
    (Io.K_response
       (Api_method.Get_then_update_response { res = Ok (Vreplica_set.marshal vrs) }))

(* State at the [After_list_vrs] wait (fresh, empty old list, cursor 0). *)
let at_list : V.s =
  { V.reconcile_step = After_list_vrs; new_vrs = None; old_vrs_list = []; old_vrs_index = 0 }

let some_vrs = owned_vrs ~name:"vd1-0" ~uid:2 ~replicas:(Some 1) ~status:None

(* ===== 1. Init -> After_list_vrs + List(vreplicaset) ===== *)
let test_init_list () =
  let out = V.reconcile_core ~cr:(vd_cr 3) ~resp:None ~state:(V.reconcile_init_state ()) in
  check_step "init -> After_list_vrs" V.After_list_vrs (fst out);
  check_req "init emits List_request" "list" out;
  Alcotest.(check bool) "the List targets the vreplicaset kind" true
    (Option.fold (list_kind (snd out)) ~none:false ~some:(fun k ->
         Common.equal_kind k Vreplica_set.kind))

(* ===== 2. After_list_vrs + [] -> create path (After_create_new_vrs + Create) ===== *)
let test_empty_list_create () =
  let out = V.reconcile_core ~cr:(vd_cr 3) ~resp:(list_resp []) ~state:at_list in
  check_step "empty list -> After_create_new_vrs" V.After_create_new_vrs (fst out);
  check_req "empty list emits Create_request" "create" out

(* ===== 3. After_list_vrs + a matching ready VRS at replicas < desired -> scale ===== *)
let test_ready_scale () =
  let vrs = ready_vrs ~name:"vd1-0" ~uid:2 ~replicas:1 in
  let out =
    V.reconcile_core ~cr:(vd_cr 3) ~resp:(list_resp [ Vreplica_set.marshal vrs ])
      ~state:at_list
  in
  check_step "ready VRS below desired -> After_scale_new_vrs" V.After_scale_new_vrs
    (fst out);
  check_req "scale emits Get_then_update_request" "get_then_update" out

(* ===== 4. After_create_new_vrs + Create Ok -> After_ensure_new_vrs ===== *)
let test_create_ensures () =
  let out =
    V.reconcile_core ~cr:(vd_cr 3) ~resp:(create_resp some_vrs)
      ~state:
        { V.reconcile_step = After_create_new_vrs; new_vrs = None; old_vrs_list = []; old_vrs_index = 0 }
  in
  check_step "create Ok -> After_ensure_new_vrs" V.After_ensure_new_vrs (fst out);
  check_req "create-done emits no request" "none" out

(* ===== 5. After_scale_new_vrs + Get_then_update Ok -> After_ensure_new_vrs ===== *)
let test_scale_ensures () =
  let out =
    V.reconcile_core ~cr:(vd_cr 3) ~resp:(get_then_update_resp some_vrs)
      ~state:
        { V.reconcile_step = After_scale_new_vrs; new_vrs = Some some_vrs; old_vrs_list = []; old_vrs_index = 0 }
  in
  check_step "scale Ok -> After_ensure_new_vrs" V.After_ensure_new_vrs (fst out);
  check_req "scale-done emits no request" "none" out

(* ===== 6. After_ensure_new_vrs, index 0 -> Done (barrier, resp-free) ===== *)
let test_ensure_done () =
  let out =
    V.reconcile_core ~cr:(vd_cr 3) ~resp:None
      ~state:
        { V.reconcile_step = After_ensure_new_vrs; new_vrs = Some some_vrs; old_vrs_list = []; old_vrs_index = 0 }
  in
  check_step "ensure, no old vrs -> Done" V.Done (fst out);
  check_req "done emits no request" "none" out

(* ===== 7. After_ensure_new_vrs with an old vrs -> scale-down ===== *)
let test_ensure_scale_down () =
  let old = owned_vrs ~name:"vd1-old" ~uid:3 ~replicas:(Some 2) ~status:None in
  let out =
    V.reconcile_core ~cr:(vd_cr 3) ~resp:None
      ~state:
        { V.reconcile_step = After_ensure_new_vrs; new_vrs = Some some_vrs; old_vrs_list = [ old ]; old_vrs_index = 1 }
  in
  check_step "ensure with an old vrs -> After_scale_down_old_vrs"
    V.After_scale_down_old_vrs (fst out);
  check_req "scale-down emits Get_then_update_request" "get_then_update" out;
  Alcotest.(check int) "scale-down decrements the cursor" 0 (fst out).old_vrs_index

(* ===== 8. After_scale_down_old_vrs loop: continue at index>0, Done at index 0 ===== *)
let test_scale_down_loop () =
  let old = owned_vrs ~name:"vd1-old" ~uid:3 ~replicas:(Some 2) ~status:None in
  (* one more old to scale: index 1 -> emits another Get_then_update, cursor 0 *)
  let cont =
    V.reconcile_core ~cr:(vd_cr 3) ~resp:(get_then_update_resp old)
      ~state:
        { V.reconcile_step = After_scale_down_old_vrs; new_vrs = Some some_vrs; old_vrs_list = [ old ]; old_vrs_index = 1 }
  in
  check_step "scale-down loop -> After_scale_down_old_vrs" V.After_scale_down_old_vrs
    (fst cont);
  check_req "scale-down loop emits Get_then_update_request" "get_then_update" cont;
  (* cursor exhausted (index 0) -> Done *)
  let done_ =
    V.reconcile_core ~cr:(vd_cr 3) ~resp:(get_then_update_resp old)
      ~state:
        { V.reconcile_step = After_scale_down_old_vrs; new_vrs = Some some_vrs; old_vrs_list = [ old ]; old_vrs_index = 0 }
  in
  check_step "scale-down loop at index 0 -> Done" V.Done (fst done_);
  check_req "scale-down loop done emits no request" "none" done_

(* ===== 9. Error routing ===== *)
let test_error_routing () =
  (* wrong-kind response (Create where a List is awaited) *)
  check_step "wrong-kind resp -> Error" V.Error
    (fst (V.reconcile_core ~cr:(vd_cr 3) ~resp:(create_resp some_vrs) ~state:at_list));
  (* an absent response at a waiting step *)
  check_step "absent resp at waiting step -> Error" V.Error
    (fst (V.reconcile_core ~cr:(vd_cr 3) ~resp:None ~state:at_list));
  (* an Error api payload *)
  check_step "Error payload -> Error" V.Error
    (fst (V.reconcile_core ~cr:(vd_cr 3) ~resp:list_err ~state:at_list));
  (* an out-of-range cursor at the barrier (index > len) *)
  check_step "cursor > old_vrs_list length -> Error" V.Error
    (fst
       (V.reconcile_core ~cr:(vd_cr 3) ~resp:None
          ~state:
            { V.reconcile_step = After_ensure_new_vrs; new_vrs = Some some_vrs; old_vrs_list = []; old_vrs_index = 2 }));
  (* a missing namespace at Init (honest unwrap of Anvil's proof-discharged field) *)
  let cr_no_ns =
    V_deployment.make ~metadata:{ vd_metadata with namespace = None }
      ~spec:(V_deployment.spec (vd_cr 3)) ~status:()
  in
  check_step "init w/ no namespace -> Error (honest unwrap)" V.Error
    (fst (V.reconcile_core ~cr:cr_no_ns ~resp:None ~state:(V.reconcile_init_state ())))

let () =
  Alcotest.run "v_deployment_reconciler"
    [
      ( "transitions",
        [
          Alcotest.test_case "1 init -> list(vreplicaset)" `Quick test_init_list;
          Alcotest.test_case "2 empty list -> create" `Quick test_empty_list_create;
          Alcotest.test_case "3 ready VRS below desired -> scale" `Quick test_ready_scale;
          Alcotest.test_case "4 create Ok -> ensure" `Quick test_create_ensures;
          Alcotest.test_case "5 scale Ok -> ensure" `Quick test_scale_ensures;
          Alcotest.test_case "6 ensure index 0 -> done" `Quick test_ensure_done;
          Alcotest.test_case "7 ensure w/ old -> scale-down" `Quick test_ensure_scale_down;
          Alcotest.test_case "8 scale-down loop -> done" `Quick test_scale_down_loop;
        ] );
      ( "guards",
        [ Alcotest.test_case "9 error routing" `Quick test_error_routing ] );
    ]

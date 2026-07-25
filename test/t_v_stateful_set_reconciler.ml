(* VStatefulSet reconcile_core tests (Phase 10, t_v_stateful_set_reconciler;
   mirrors t_v_deployment_reconciler.ml): every one of the 17 typed steps driven
   with hand-built inputs — Init (list vs done), After_list_pod dispatch, the
   PVC probe/create/skip loop, the create/update needed-pod loop, condemned
   scale-down, outdated pruning, and the Done/Error sinks. The emitted request is
   named by its Kubernetes verb (exhaustive over the api_request sum); step
   assertions use [V.step_equal].

   Convention firewall: no loop keywords; no [_ ->] wildcard on a finite sum
   (api_request enumerated, the External arm void-refuted); Option.fold /
   Result.fold for options/results. *)

module V = V_stateful_set_reconciler
module Scenario = Anvil_assurance.Scenario

(* -- CR fixtures -- *)

let cr = Scenario.vsts ~desired:3 ()
let cr_vct = Scenario.vsts ~desired:3 ~vct:true ()

(* A CR whose pod template spec differs from [cr]'s (a non-default
   service_account_name that survives [pod_spec_matches]'s normalization), so a
   pod built from it is "unmatched" against [cr]. *)
let mismatched_cr : V_stateful_set.t =
  {
    cr with
    spec =
      {
        cr.spec with
        template =
          {
            cr.spec.template with
            spec = Some { (Pod_spec.default ()) with service_account_name = Some "v2" };
          };
      };
  }

(* A CR marked for deletion (deletion_timestamp set): Init short-circuits to Done. *)
let cr_deleting : V_stateful_set.t =
  { cr with metadata = { cr.metadata with deletion_timestamp = Some "2026-01-01" } }

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
        | Api_method.Get_request _ -> "get"
        | Api_method.Get_then_update_request _ -> "get_then_update"
        | Api_method.Get_then_delete_request _ -> "get_then_delete"
        | Api_method.Delete_request _ | Api_method.Update_request _
        | Api_method.Update_status_request _
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

let get_resp (res : (Dynamic_object.t, Api_method.api_error) result) :
    Io.void Io.response_view option =
  Some (Io.K_response (Api_method.Get_response { res }))

let create_resp (res : (Dynamic_object.t, Api_method.api_error) result) :
    Io.void Io.response_view option =
  Some (Io.K_response (Api_method.Create_response { res }))

let get_then_update_resp (res : (Dynamic_object.t, Api_method.api_error) result) :
    Io.void Io.response_view option =
  Some (Io.K_response (Api_method.Get_then_update_response { res }))

let get_then_delete_resp (res : (unit, Api_method.api_error) result) :
    Io.void Io.response_view option =
  Some (Io.K_response (Api_method.Get_then_delete_response { res }))

(* -- pod/pvc fixtures -- *)

let a_pod = V.make_pod cr 0
let a_pvc : Persistent_volume_claim.t = List.hd (V.make_pvcs cr_vct 0)
let matched_pod = V.make_pod cr 0
let stale_pod2 = V.make_pod mismatched_cr 2

let at (step : V.step) : V.s = { V.init with reconcile_step = step }

(* ===== 1. Init: no deletion_timestamp -> After_list_pod + List(pod) ===== *)
let test_init_list () =
  let out = V.reconcile_core ~cr ~resp:None ~state:(V.reconcile_init_state ()) in
  check_step "init -> After_list_pod" V.After_list_pod (fst out);
  check_req "init emits List_request" "list" out;
  Alcotest.(check bool) "the List targets the pod kind" true
    (Option.fold (list_kind (snd out)) ~none:false ~some:(fun k ->
         Common.equal_kind k Pod.kind))

(* ===== 1b. Init: deletion_timestamp set -> Done, no request ===== *)
let test_init_deleting () =
  let out = V.reconcile_core ~cr:cr_deleting ~resp:None ~state:(V.reconcile_init_state ()) in
  check_step "init w/ deletion_timestamp -> Done" V.Done (fst out);
  check_req "deleting init emits no request" "none" out

(* ===== 2. After_list_pod: empty list, no vct -> Create_needed dispatch ===== *)
let test_after_list_create_needed () =
  let out = V.reconcile_core ~cr ~resp:(list_resp []) ~state:(at V.After_list_pod) in
  check_step "empty list (no vct) -> Create_needed" V.Create_needed (fst out);
  check_req "dispatch emits no request (two-phase handoff)" "none" out

(* ===== 2b. After_list_pod: empty list, WITH vct -> Get_pvc dispatch ===== *)
let test_after_list_get_pvc () =
  let out = V.reconcile_core ~cr:cr_vct ~resp:(list_resp []) ~state:(at V.After_list_pod) in
  check_step "empty list (vct) -> Get_pvc" V.Get_pvc (fst out);
  check_req "dispatch emits no request" "none" out

(* ===== 3. Get_pvc -> Get(pvc) + After_get_pvc ===== *)
let test_get_pvc () =
  let out =
    V.reconcile_core ~cr:cr_vct ~resp:None
      ~state:{ V.init with reconcile_step = Get_pvc; pvcs = V.make_pvcs cr_vct 0; pvc_index = 0 }
  in
  check_step "Get_pvc -> After_get_pvc" V.After_get_pvc (fst out);
  check_req "Get_pvc emits Get_request" "get" out

(* ===== 4. After_get_pvc: Ok -> Skip_pvc; NotFound -> Create_pvc; other -> Error ===== *)
let test_after_get_pvc () =
  let ok =
    V.reconcile_core ~cr:cr_vct
      ~resp:(get_resp (Ok (Persistent_volume_claim.marshal a_pvc)))
      ~state:(at V.After_get_pvc)
  in
  check_step "After_get_pvc Ok -> Skip_pvc" V.Skip_pvc (fst ok);
  let nf =
    V.reconcile_core ~cr:cr_vct
      ~resp:(get_resp (Error Api_method.Object_not_found))
      ~state:(at V.After_get_pvc)
  in
  check_step "After_get_pvc NotFound -> Create_pvc" V.Create_pvc (fst nf);
  let other =
    V.reconcile_core ~cr:cr_vct
      ~resp:(get_resp (Error Api_method.Conflict))
      ~state:(at V.After_get_pvc)
  in
  check_step "After_get_pvc Conflict -> Error" V.Error (fst other)

(* ===== 5. Create_pvc -> Create(pvc) + After_create_pvc ===== *)
let test_create_pvc () =
  let out =
    V.reconcile_core ~cr:cr_vct ~resp:None
      ~state:{ V.init with reconcile_step = Create_pvc; pvcs = V.make_pvcs cr_vct 0; pvc_index = 0 }
  in
  check_step "Create_pvc -> After_create_pvc" V.After_create_pvc (fst out);
  check_req "Create_pvc emits Create_request" "create" out;
  Alcotest.(check int) "Create_pvc advances pvc cursor" 1 (fst out).pvc_index

(* ===== 6. After_create_pvc: Ok / AlreadyExists advance; other -> Error ===== *)
let test_after_create_pvc () =
  let base : V.s =
    { V.init with reconcile_step = After_create_pvc; pvcs = [ a_pvc ]; pvc_index = 1;
      needed = [ None ]; needed_index = 0 }
  in
  let ok = V.reconcile_core ~cr:cr_vct ~resp:(create_resp (Ok (Pod.marshal a_pod))) ~state:base in
  check_step "After_create_pvc Ok -> Create_needed (advance)" V.Create_needed (fst ok);
  let exists =
    V.reconcile_core ~cr:cr_vct
      ~resp:(create_resp (Error Api_method.Object_already_exists)) ~state:base
  in
  check_step "After_create_pvc AlreadyExists -> Create_needed (advance)" V.Create_needed
    (fst exists);
  let other =
    V.reconcile_core ~cr:cr_vct ~resp:(create_resp (Error Api_method.Conflict)) ~state:base
  in
  check_step "After_create_pvc Conflict -> Error" V.Error (fst other)

(* ===== 7. Skip_pvc advances the cursor ===== *)
let test_skip_pvc () =
  let out =
    V.reconcile_core ~cr ~resp:None
      ~state:{ V.init with reconcile_step = Skip_pvc; pvcs = [ a_pvc ]; pvc_index = 0;
               needed = [ None ]; needed_index = 0 }
  in
  check_step "Skip_pvc -> Create_needed (advance)" V.Create_needed (fst out)

(* ===== 8. Create_needed -> Create(pod) + After_create_needed ===== *)
let test_create_needed () =
  let out =
    V.reconcile_core ~cr ~resp:None
      ~state:{ V.init with reconcile_step = Create_needed; needed = [ None ]; needed_index = 0 }
  in
  check_step "Create_needed -> After_create_needed" V.After_create_needed (fst out);
  check_req "Create_needed emits Create_request" "create" out;
  Alcotest.(check int) "Create_needed advances needed cursor" 1 (fst out).needed_index

(* ===== 9. After_create_needed: Ok / AlreadyExists advance; other -> Error ===== *)
let test_after_create_needed () =
  let base : V.s =
    { V.init with reconcile_step = After_create_needed; needed = [ None ]; needed_index = 1;
      condemned = []; condemned_index = 0 }
  in
  let ok = V.reconcile_core ~cr ~resp:(create_resp (Ok (Pod.marshal a_pod))) ~state:base in
  check_step "After_create_needed Ok -> Delete_outdated (advance)" V.Delete_outdated (fst ok);
  let exists =
    V.reconcile_core ~cr ~resp:(create_resp (Error Api_method.Object_already_exists)) ~state:base
  in
  check_step "After_create_needed AlreadyExists -> Delete_outdated" V.Delete_outdated (fst exists);
  let other =
    V.reconcile_core ~cr ~resp:(create_resp (Error Api_method.Internal_error)) ~state:base
  in
  check_step "After_create_needed error -> Error" V.Error (fst other)

(* ===== 10. Update_needed -> Get_then_update(pod) + After_update_needed ===== *)
let test_update_needed () =
  let out =
    V.reconcile_core ~cr ~resp:None
      ~state:{ V.init with reconcile_step = Update_needed; needed = [ Some a_pod ]; needed_index = 0 }
  in
  check_step "Update_needed -> After_update_needed" V.After_update_needed (fst out);
  check_req "Update_needed emits Get_then_update_request" "get_then_update" out;
  Alcotest.(check int) "Update_needed advances needed cursor" 1 (fst out).needed_index

(* ===== 11. After_update_needed: Ok advances; error -> Error ===== *)
let test_after_update_needed () =
  let base : V.s =
    { V.init with reconcile_step = After_update_needed; needed = [ Some a_pod ]; needed_index = 1;
      condemned = []; condemned_index = 0 }
  in
  let ok = V.reconcile_core ~cr ~resp:(get_then_update_resp (Ok (Pod.marshal a_pod))) ~state:base in
  check_step "After_update_needed Ok -> Delete_outdated (advance)" V.Delete_outdated (fst ok);
  let other =
    V.reconcile_core ~cr ~resp:(get_then_update_resp (Error Api_method.Conflict)) ~state:base
  in
  check_step "After_update_needed error -> Error" V.Error (fst other)

(* ===== 12. Delete_condemned -> Get_then_delete(pod) + After_delete_condemned ===== *)
let test_delete_condemned () =
  let condemned_pod = V.make_pod cr 2 in
  let out =
    V.reconcile_core ~cr ~resp:None
      ~state:{ V.init with reconcile_step = Delete_condemned; condemned = [ condemned_pod ];
               condemned_index = 0 }
  in
  check_step "Delete_condemned -> After_delete_condemned" V.After_delete_condemned (fst out);
  check_req "Delete_condemned emits Get_then_delete_request" "get_then_delete" out;
  Alcotest.(check int) "Delete_condemned advances condemned cursor" 1
    (fst out).condemned_index

(* ===== 13. After_delete_condemned: Ok / NotFound advance; other -> Error ===== *)
let test_after_delete_condemned () =
  let base : V.s =
    { V.init with reconcile_step = After_delete_condemned; condemned = [ V.make_pod cr 2 ];
      condemned_index = 1 }
  in
  let ok = V.reconcile_core ~cr ~resp:(get_then_delete_resp (Ok ())) ~state:base in
  check_step "After_delete_condemned Ok -> Delete_outdated (advance)" V.Delete_outdated (fst ok);
  let nf =
    V.reconcile_core ~cr ~resp:(get_then_delete_resp (Error Api_method.Object_not_found)) ~state:base
  in
  check_step "After_delete_condemned NotFound -> Delete_outdated" V.Delete_outdated (fst nf);
  let other =
    V.reconcile_core ~cr ~resp:(get_then_delete_resp (Error Api_method.Forbidden)) ~state:base
  in
  check_step "After_delete_condemned error -> Error" V.Error (fst other)

(* ===== 14. Delete_outdated: unmatched -> Get_then_delete; all-matched -> Done ===== *)
let test_delete_outdated () =
  let unmatched =
    V.reconcile_core ~cr ~resp:None
      ~state:{ V.init with reconcile_step = Delete_outdated; needed = [ Some stale_pod2 ] }
  in
  check_step "Delete_outdated w/ unmatched -> After_delete_outdated" V.After_delete_outdated
    (fst unmatched);
  check_req "Delete_outdated w/ unmatched emits Get_then_delete_request" "get_then_delete"
    unmatched;
  let all_matched =
    V.reconcile_core ~cr ~resp:None
      ~state:{ V.init with reconcile_step = Delete_outdated; needed = [ Some matched_pod ] }
  in
  check_step "Delete_outdated all-matched -> Done" V.Done (fst all_matched);
  check_req "Delete_outdated all-matched emits no request" "none" all_matched

(* ===== 15. After_delete_outdated: Ok / NotFound -> Done; other -> Error ===== *)
let test_after_delete_outdated () =
  let ok =
    V.reconcile_core ~cr ~resp:(get_then_delete_resp (Ok ())) ~state:(at V.After_delete_outdated)
  in
  check_step "After_delete_outdated Ok -> Done" V.Done (fst ok);
  let nf =
    V.reconcile_core ~cr
      ~resp:(get_then_delete_resp (Error Api_method.Object_not_found))
      ~state:(at V.After_delete_outdated)
  in
  check_step "After_delete_outdated NotFound -> Done" V.Done (fst nf);
  let other =
    V.reconcile_core ~cr
      ~resp:(get_then_delete_resp (Error Api_method.Internal_error))
      ~state:(at V.After_delete_outdated)
  in
  check_step "After_delete_outdated error -> Error" V.Error (fst other)

(* ===== 16 & 17. Done and Error are stable sinks (no request) ===== *)
let test_sinks () =
  let d = V.reconcile_core ~cr ~resp:None ~state:(at V.Done) in
  check_step "Done -> Done" V.Done (fst d);
  check_req "Done emits no request" "none" d;
  let e = V.reconcile_core ~cr ~resp:None ~state:(at V.Error) in
  check_step "Error -> Error" V.Error (fst e);
  check_req "Error emits no request" "none" e

let () =
  Alcotest.run "v_stateful_set_reconciler"
    [
      ( "transitions",
        [
          Alcotest.test_case "1 init -> list(pod)" `Quick test_init_list;
          Alcotest.test_case "1b init deleting -> done" `Quick test_init_deleting;
          Alcotest.test_case "2 after_list -> create_needed" `Quick test_after_list_create_needed;
          Alcotest.test_case "2b after_list (vct) -> get_pvc" `Quick test_after_list_get_pvc;
          Alcotest.test_case "3 get_pvc -> get" `Quick test_get_pvc;
          Alcotest.test_case "4 after_get_pvc branches" `Quick test_after_get_pvc;
          Alcotest.test_case "5 create_pvc -> create" `Quick test_create_pvc;
          Alcotest.test_case "6 after_create_pvc branches" `Quick test_after_create_pvc;
          Alcotest.test_case "7 skip_pvc advances" `Quick test_skip_pvc;
          Alcotest.test_case "8 create_needed -> create" `Quick test_create_needed;
          Alcotest.test_case "9 after_create_needed branches" `Quick test_after_create_needed;
          Alcotest.test_case "10 update_needed -> get_then_update" `Quick test_update_needed;
          Alcotest.test_case "11 after_update_needed branches" `Quick test_after_update_needed;
          Alcotest.test_case "12 delete_condemned -> get_then_delete" `Quick test_delete_condemned;
          Alcotest.test_case "13 after_delete_condemned branches" `Quick test_after_delete_condemned;
          Alcotest.test_case "14 delete_outdated branches" `Quick test_delete_outdated;
          Alcotest.test_case "15 after_delete_outdated branches" `Quick test_after_delete_outdated;
          Alcotest.test_case "16/17 done & error sinks" `Quick test_sinks;
        ] );
    ]

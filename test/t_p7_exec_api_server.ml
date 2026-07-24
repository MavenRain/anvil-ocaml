(* P7 exec-shim tests: the in-memory {!Exec_api_server} backend (BUILD-SPEC-P7
   §4). Against a fresh server with the vreplicaset [installed_types], exercises
   the etcd verbs and pins the uid / resource-version counters EXACTLY across a
   short sequence:

     CREATE stamps a uid+rv (counters 0,0 -> 1,1); GET returns it; a second CREATE
     of the same ref is rejected [Object_already_exists] and writes nothing
     (counters stay 1,1); LIST returns the created object of the kind; a
     Get_then_update_status composite succeeds with no spurious [Conflict] and
     bumps rv only (1,1 -> 1,2); DELETE bumps rv (1,2 -> 1,3) and a following GET
     is [Object_not_found]. uid advances on CREATE alone; rv on every write.

   This counter discipline is the target of mutation M1 (neuter uid/rv stamping):
   under M1 the counters never advance and every counter assertion here flips red. *)

module Exec = Anvil_exec.Exec_api_server
module Scenario = Anvil_assurance.Scenario

let installed = Scenario.cluster.Cluster.installed_types
let cr () = Vreplica_set.marshal (Scenario.vrs ~desired:3)
let cr_ref = Scenario.vrs_ref

let owner_ref =
  match Vreplica_set.controller_owner_ref (Scenario.vrs ~desired:3) with
  | Some r -> r
  | None -> Alcotest.fail "scenario cr is missing its controller owner ref"

let fresh () : Exec.t =
  match Exec.create ~installed () with
  | Ok t -> t
  | Error e -> Alcotest.failf "create: %s" (Err.show e)

let run (t : Exec.t) (req : Api_method.api_request) : Api_method.api_response =
  match Exec.request t req with
  | Ok resp -> resp
  | Error e -> Alcotest.failf "transport error: %s" (Err.show e)

let counters (t : Exec.t) : int * int =
  let s = Exec.state t in
  (s.Api_server.uid_counter, s.Api_server.resource_version_counter)

(* Exhaustive response projectors (all nine variants, no [_ ->] catch-all). *)
let as_create (r : Api_method.api_response) :
    (Dynamic_object.t, Api_method.api_error) result =
  let open Api_method in
  match r with
  | Create_response { res } -> res
  | Get_response _ | List_response _ | Delete_response _ | Update_response _
  | Update_status_response _ | Get_then_delete_response _
  | Get_then_update_response _ | Get_then_update_status_response _ ->
      Alcotest.fail "expected a Create_response"

let as_get (r : Api_method.api_response) :
    (Dynamic_object.t, Api_method.api_error) result =
  let open Api_method in
  match r with
  | Get_response { res } -> res
  | Create_response _ | List_response _ | Delete_response _ | Update_response _
  | Update_status_response _ | Get_then_delete_response _
  | Get_then_update_response _ | Get_then_update_status_response _ ->
      Alcotest.fail "expected a Get_response"

let as_list (r : Api_method.api_response) :
    (Dynamic_object.t list, Api_method.api_error) result =
  let open Api_method in
  match r with
  | List_response { res } -> res
  | Get_response _ | Create_response _ | Delete_response _ | Update_response _
  | Update_status_response _ | Get_then_delete_response _
  | Get_then_update_response _ | Get_then_update_status_response _ ->
      Alcotest.fail "expected a List_response"

let as_delete (r : Api_method.api_response) : (unit, Api_method.api_error) result =
  let open Api_method in
  match r with
  | Delete_response { res } -> res
  | Get_response _ | Create_response _ | List_response _ | Update_response _
  | Update_status_response _ | Get_then_delete_response _
  | Get_then_update_response _ | Get_then_update_status_response _ ->
      Alcotest.fail "expected a Delete_response"

let as_gtus (r : Api_method.api_response) :
    (Dynamic_object.t, Api_method.api_error) result =
  let open Api_method in
  match r with
  | Get_then_update_status_response { res } -> res
  | Get_response _ | Create_response _ | List_response _ | Delete_response _
  | Update_response _ | Update_status_response _ | Get_then_delete_response _
  | Get_then_update_response _ ->
      Alcotest.fail "expected a Get_then_update_status_response"

(* [Object_already_exists]? — exhaustive over the twelve api_errors, no wildcard. *)
let is_already_exists (res : ('a, Api_method.api_error) result) : bool =
  let open Api_method in
  match res with
  | Ok _ -> false
  | Error Object_already_exists -> true
  | Error
      ( Bad_request | Conflict | Forbidden | Invalid | Object_not_found
      | Not_supported | Internal_error | Timeout | Server_timeout
      | Transaction_abort | Other ) ->
      false

let is_not_found (res : ('a, Api_method.api_error) result) : bool =
  let open Api_method in
  match res with
  | Ok _ -> false
  | Error Object_not_found -> true
  | Error
      ( Bad_request | Conflict | Forbidden | Invalid | Object_already_exists
      | Not_supported | Internal_error | Timeout | Server_timeout
      | Transaction_abort | Other ) ->
      false

let test_lifecycle () =
  let open Api_method in
  let t = fresh () in
  Alcotest.(check (pair int int)) "fresh counters are zero" (0, 0) (counters t);

  let c1 = run t (Create_request { namespace = "ns"; obj = cr () }) in
  Alcotest.(check bool) "CREATE succeeds" true (Result.is_ok (as_create c1));
  Alcotest.(check (pair int int)) "CREATE stamps uid+rv" (1, 1) (counters t);

  let g1 = run t (Get_request { key = cr_ref }) in
  Alcotest.(check bool) "GET finds the created object" true
    (Result.is_ok (as_get g1));

  let c2 = run t (Create_request { namespace = "ns"; obj = cr () }) in
  Alcotest.(check bool) "second CREATE is Object_already_exists" true
    (is_already_exists (as_create c2));
  Alcotest.(check (pair int int)) "rejected CREATE writes nothing" (1, 1)
    (counters t);

  let l1 = run t (List_request { kind = Vreplica_set.kind; namespace = "ns" }) in
  Alcotest.(check int) "LIST returns the one created object" 1
    (match as_list l1 with Ok os -> List.length os | Error _err -> -1);

  let gt =
    run t
      (Get_then_update_status_request
         { namespace = "ns"; name = "vrs1"; owner_ref; obj = cr () })
  in
  Alcotest.(check bool) "Get_then_update_status succeeds (no spurious Conflict)"
    true (Result.is_ok (as_gtus gt));
  Alcotest.(check (pair int int)) "UPDATE_STATUS bumps rv only" (1, 2)
    (counters t);

  let d1 = run t (Delete_request { key = cr_ref; preconditions = None }) in
  Alcotest.(check bool) "DELETE succeeds" true (Result.is_ok (as_delete d1));
  Alcotest.(check (pair int int)) "DELETE bumps rv" (1, 3) (counters t);

  let g2 = run t (Get_request { key = cr_ref }) in
  Alcotest.(check bool) "GET after DELETE is Object_not_found" true
    (is_not_found (as_get g2))

let () =
  Alcotest.run "p7_exec_api_server"
    [
      ( "etcd-verbs-and-counters",
        [ Alcotest.test_case "create/get/list/update/delete + counters" `Quick
            test_lifecycle ] );
    ]

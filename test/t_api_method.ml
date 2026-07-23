(* api_method construction + projection tests:
     - every api_request (9) and api_response (9) variant is constructed
       (compile-level exhaustiveness of both sums);
     - every api_error (12) variant is constructed;
     - a couple of request `key` projections and a `well_formed` check. *)

let oref = { Common.kind = Common.Pod; name = "p"; namespace = "ns" }

let dobj =
  Dynamic_object.make ~kind:Common.Pod
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name "p"
      |> Object_meta.with_namespace "ns")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let ctrl_ref =
  let open Owner_reference in
  { (default ()) with controller = Some true; name = "owner" }

let plain_ref = Owner_reference.default ()

let all_errors : Api_method.api_error list =
  let open Api_method in
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

let requests : Api_method.api_request list =
  let open Api_method in
  [
    Get_request { key = oref };
    List_request { kind = Common.Pod; namespace = "ns" };
    Create_request { namespace = "ns"; obj = dobj };
    Delete_request { key = oref; preconditions = None };
    Update_request { namespace = "ns"; name = "p"; obj = dobj };
    Update_status_request { namespace = "ns"; name = "p"; obj = dobj };
    Get_then_delete_request { key = oref; owner_ref = ctrl_ref };
    Get_then_update_request
      { namespace = "ns"; name = "p"; owner_ref = ctrl_ref; obj = dobj };
    Get_then_update_status_request
      { namespace = "ns"; name = "p"; owner_ref = ctrl_ref; obj = dobj };
  ]

let responses : Api_method.api_response list =
  let open Api_method in
  [
    Get_response { res = Ok dobj };
    List_response { res = Ok [ dobj ] };
    Create_response { res = Ok dobj };
    Delete_response { res = Ok () };
    Update_response { res = Ok dobj };
    Update_status_response { res = Error Object_not_found };
    Get_then_delete_response { res = Ok () };
    Get_then_update_response { res = Ok dobj };
    Get_then_update_status_response { res = Ok dobj };
  ]

(* Compile-level exhaustiveness: each tag_* function matches EVERY constructor
   of its sum with NO [_ ->] arm, so adding (or removing) a variant fails to
   compile (dune's -warn-error +8 turns the non-exhaustive-match warning into an
   error). These matches ARE the guard the module comment claims; the runtime
   List.length checks below are a redundant belt-and-braces count. *)
let tag_error : Api_method.api_error -> int = function
  | Bad_request -> 0
  | Conflict -> 1
  | Forbidden -> 2
  | Invalid -> 3
  | Object_not_found -> 4
  | Object_already_exists -> 5
  | Not_supported -> 6
  | Internal_error -> 7
  | Timeout -> 8
  | Server_timeout -> 9
  | Transaction_abort -> 10
  | Other -> 11

let tag_request : Api_method.api_request -> int = function
  | Get_request _ -> 0
  | List_request _ -> 1
  | Create_request _ -> 2
  | Delete_request _ -> 3
  | Update_request _ -> 4
  | Update_status_request _ -> 5
  | Get_then_delete_request _ -> 6
  | Get_then_update_request _ -> 7
  | Get_then_update_status_request _ -> 8

let tag_response : Api_method.api_response -> int = function
  | Get_response _ -> 0
  | List_response _ -> 1
  | Create_response _ -> 2
  | Delete_response _ -> 3
  | Update_response _ -> 4
  | Update_status_response _ -> 5
  | Get_then_delete_response _ -> 6
  | Get_then_update_response _ -> 7
  | Get_then_update_status_response _ -> 8

let test_exhaustive () =
  (* Force the compile-checked matches to be used, and confirm the tags cover a
     contiguous range: every listed value maps through its total match. *)
  Alcotest.(check (list int))
    "api_error tags" [ 0; 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11 ]
    (List.sort compare (List.map tag_error all_errors));
  Alcotest.(check (list int))
    "api_request tags" [ 0; 1; 2; 3; 4; 5; 6; 7; 8 ]
    (List.sort compare (List.map tag_request requests));
  Alcotest.(check (list int))
    "api_response tags" [ 0; 1; 2; 3; 4; 5; 6; 7; 8 ]
    (List.sort compare (List.map tag_response responses))

let test_keys () =
  Alcotest.(check bool) "get_request_key" true
    (Common.equal_object_ref oref (Api_method.get_request_key { key = oref }));
  Alcotest.(check bool) "delete_request_key" true
    (Common.equal_object_ref oref
       (Api_method.delete_request_key { key = oref; preconditions = None }));
  (* update_request_key derives {obj.kind; namespace; name}. *)
  Alcotest.(check bool) "update_request_key" true
    (Common.equal_object_ref
       { Common.kind = Common.Pod; name = "p"; namespace = "ns" }
       (Api_method.update_request_key
          { namespace = "ns"; name = "p"; obj = dobj }));
  (* create_request_key is fallible on an absent metadata.name. *)
  Alcotest.(check bool) "create_request_key ok" true
    (Result.fold
       ~ok:
         (Common.equal_object_ref
            { Common.kind = Common.Pod; name = "p"; namespace = "ns" })
       ~error:(fun _ -> false)
       (Api_method.create_request_key { namespace = "ns"; obj = dobj }))

let test_well_formed () =
  Alcotest.(check bool) "controller owner well_formed" true
    (Api_method.get_then_delete_well_formed
       { key = oref; owner_ref = ctrl_ref });
  Alcotest.(check bool) "non-controller owner not well_formed" false
    (Api_method.get_then_delete_well_formed
       { key = oref; owner_ref = plain_ref })

let () =
  Alcotest.run "api_method"
    [
      ( "construction",
        [ Alcotest.test_case "exhaustive" `Quick test_exhaustive ] );
      ( "projection",
        [
          Alcotest.test_case "keys" `Quick test_keys;
          Alcotest.test_case "well_formed" `Quick test_well_formed;
        ] );
    ]

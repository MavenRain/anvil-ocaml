(* API-server host tests (BUILD-SPEC-P2 "## Tests", t_api_server):
   - create stamps uid + rv onto the object and increments BOTH counters;
   - a conflicting update (rv mismatch) yields [Conflict];
   - delete with a finalizer stamps a deletion_timestamp instead of removing;
   - a get on an absent key yields [ObjectNotFound].

   CONFIRM-BY-MUTATION (feedback-confirm-tests-by-mutation), guard (c):
   [test_create]'s "uid_counter advances by one" (and the paired "stamped uid=3")
   assertion pins the create uid/rv stamping in [Api_server.handle_create_request]
   (api_server.ml:280-285 / :252-254). Neuter the counter bump
   ([uid_counter = s.uid_counter + 1] -> [uid_counter = s.uid_counter]), rebuild,
   and this test flips to failing; restore the [+ 1] and it is green again. Every
   mutation was restored (tree left green). *)

let permissive : Api_server.installed_types =
  {
    Api_server.unmarshallable_spec = (fun _ _ -> true);
    unmarshallable_status = (fun _ _ -> true);
    valid_object = (fun _ -> true);
    valid_transition = (fun _ _ -> true);
    marshalled_default_status = (fun _ -> Value.of_json `Null);
  }

let cm_ref = { Common.kind = Common.Config_map; name = "cm"; namespace = "ns" }

let cm_meta () =
  Object_meta.default ()
  |> Object_meta.with_name "cm"
  |> Object_meta.with_namespace "ns"

let cm_obj ?(meta = cm_meta ()) () =
  Dynamic_object.make ~kind:Common.Config_map ~metadata:meta
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

(* Counters seeded non-zero so the stamped snapshots (uid=3, rv=7) and the
   post-write counters (4, 8) are unambiguous. *)
let s0 : Api_server.state =
  { Api_server.resources = Object_ref_map.empty; uid_counter = 3; resource_version_counter = 7 }

let test_create () =
  let req = { Api_method.namespace = "ns"; obj = cm_obj () } in
  let s1, (resp : Api_method.create_response) =
    Api_server.handle_create_request permissive req s0
  in
  (* CONFIRM-BY-MUTATION (c): both counters advance by one. *)
  Alcotest.(check int) "uid_counter advances by one" 4 s1.Api_server.uid_counter;
  Alcotest.(check int) "rv_counter advances by one" 8
    s1.Api_server.resource_version_counter;
  Alcotest.(check bool) "response is Ok" true
    (Result.fold ~ok:(fun _ -> true) ~error:(fun _ -> false) resp.res);
  let stored = Api_server.lookup cm_ref s1.Api_server.resources in
  Alcotest.(check bool) "object stored at its ref" true (Option.is_some stored);
  (* stamped with the PRE-increment snapshots: uid=3, rv=7. *)
  let stamped_ok =
    Option.fold stored ~none:false ~some:(fun o ->
        let m : Object_meta.t = Dynamic_object.metadata o in
        Option.equal Common.Uid.equal m.uid (Some (Common.Uid.of_int 3))
        && Option.equal Common.Resource_version.equal m.resource_version
             (Some (Common.Resource_version.of_int 7)))
  in
  Alcotest.(check bool) "object stamped uid=3 rv=7" true stamped_ok

(* A store already holding a Config_map named "p0" in "default". With
   [uid_counter = 0] the OLD [generate_name ^ string_of_int uid_counter] oracle
   regenerates exactly "p0", collides on the defensive contains_key re-check and
   returns ObjectAlreadyExists; the freshness-respecting oracle must pick a name
   disjoint from every existing key (generated_name_spec). *)
let p0_ref = { Common.kind = Common.Config_map; name = "p0"; namespace = "default" }

let p0_obj =
  Dynamic_object.make ~kind:Common.Config_map
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name "p0"
      |> Object_meta.with_namespace "default")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let test_create_generate_name_fresh () =
  let s =
    {
      Api_server.resources = Object_ref_map.add p0_ref p0_obj Object_ref_map.empty;
      uid_counter = 0;
      resource_version_counter = 0;
    }
  in
  let gen_meta = Object_meta.default () |> Object_meta.with_generate_name "p" in
  let req = { Api_method.namespace = "default"; obj = cm_obj ~meta:gen_meta () } in
  let s1, (resp : Api_method.create_response) =
    Api_server.handle_create_request permissive req s
  in
  (* CONFIRM-BY-MUTATION (FIX 1): the OLD oracle collides with "p0" and rejects;
     the fresh oracle succeeds. *)
  Alcotest.(check bool) "create with only generate_name succeeds" true
    (Result.fold ~ok:(fun _ -> true) ~error:(fun _ -> false) resp.res);
  let created_name =
    Result.fold ~error:(fun _ -> None)
      ~ok:(fun o -> (Dynamic_object.metadata o).Object_meta.name)
      resp.res
  in
  Alcotest.(check bool) "generated name differs from the existing p0" true
    (Option.fold created_name ~none:false ~some:(fun nm ->
         not (String.equal nm "p0")));
  Alcotest.(check bool) "the fresh object is stored under its generated name" true
    (Option.fold created_name ~none:false ~some:(fun nm ->
         Option.is_some
           (Api_server.lookup
              { Common.kind = Common.Config_map; name = nm; namespace = "default" }
              s1.Api_server.resources)));
  Alcotest.(check bool) "pre-existing p0 is untouched" true
    (Option.is_some (Api_server.lookup p0_ref s1.Api_server.resources));
  Alcotest.(check int) "store now holds both objects" 2
    (Object_ref_map.cardinal s1.Api_server.resources)

let test_update_conflict () =
  let s1, _ =
    Api_server.handle_create_request permissive
      { Api_method.namespace = "ns"; obj = cm_obj () }
      s0
  in
  (* an update carrying a resource_version that does not match the stored one
     (stored rv = 7) must Conflict. *)
  let upd_meta =
    cm_meta ()
    |> Object_meta.with_resource_version (Common.Resource_version.of_int 999)
  in
  let ureq : Api_method.update_request =
    {
      Api_method.namespace = "ns";
      name = "cm";
      obj = cm_obj ~meta:upd_meta ();
    }
  in
  let _s2, (uresp : Api_method.update_response) =
    Api_server.handle_update_request permissive ureq s1
  in
  Alcotest.(check bool) "rv mismatch yields Conflict" true
    (Result.fold ~ok:(fun _ -> false)
       ~error:(fun e -> Api_method.equal_api_error e Api_method.Conflict)
       uresp.res)

let test_delete_with_finalizer () =
  let fin_meta = cm_meta () |> Object_meta.with_finalizers [ "f1" ] in
  let s1, _ =
    Api_server.handle_create_request permissive
      { Api_method.namespace = "ns"; obj = cm_obj ~meta:fin_meta () }
      s0
  in
  let s2, (dresp : Api_method.delete_response) =
    Api_server.handle_delete_request { Api_method.key = cm_ref; preconditions = None } s1
  in
  let stored = Api_server.lookup cm_ref s2.Api_server.resources in
  Alcotest.(check bool) "object retained (has finalizer)" true
    (Option.is_some stored);
  Alcotest.(check bool) "deletion_timestamp stamped" true
    (Option.fold stored ~none:false ~some:(fun o ->
         let m : Object_meta.t = Dynamic_object.metadata o in
         Option.is_some m.deletion_timestamp));
  Alcotest.(check int) "rv advanced by the delete write"
    (s1.Api_server.resource_version_counter + 1)
    s2.Api_server.resource_version_counter;
  Alcotest.(check bool) "delete response is Ok" true
    (Result.fold ~ok:(fun () -> true) ~error:(fun _ -> false) dresp.res)

let test_get_absent () =
  let resp = Api_server.handle_get_request { Api_method.key = cm_ref } s0 in
  Alcotest.(check bool) "get on absent key yields ObjectNotFound" true
    (Result.fold ~ok:(fun _ -> false)
       ~error:(fun e -> Api_method.equal_api_error e Api_method.Object_not_found)
       resp.res)

let () =
  Alcotest.run "api_server"
    [
      ( "handlers",
        [
          Alcotest.test_case "create stamps uid+rv" `Quick test_create;
          Alcotest.test_case "create generate_name is fresh" `Quick
            test_create_generate_name_fresh;
          Alcotest.test_case "update conflict" `Quick test_update_conflict;
          Alcotest.test_case "delete with finalizer" `Quick
            test_delete_with_finalizer;
          Alcotest.test_case "get absent" `Quick test_get_absent;
        ] );
    ]

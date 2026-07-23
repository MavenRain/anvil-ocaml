(* BUILD-SPEC P4 §5 "t_p4_oracle" — the api-server correspondence oracle property.

   The differential: for an arbitrary permissive [Api_server.installed_types], an
   arbitrary [Api_server.state] (a small etcd store of vrs/pod/configmap
   [Dynamic_object]s with populated metadata + advanced uid/rv counters), and an
   arbitrary in-flight api-request [Message.t], our ported request handler
   [Api_server.transition_by_etcd] agrees with the independent golden oracle
   [Oracle_api_server.handle] — i.e. [Oracle_api_server.agrees it msg state] holds.
   [agrees] compares the resulting etcd stores structurally (as maps of
   [Dynamic_object.t]) AND the response messages ([Message.equal]).

   Two layers guard against a vacuously-true differential (the [fun _ -> true]
   trap):

   (1) A QCheck property (`prop_agree`, 2000 samples) fuzzes the triple. The
       request generator is CONDITIONED on the store (target keys drawn from the
       store's own keys or from an overlapping pool; delete/update preconditions
       drawn to sometimes match, sometimes conflict with, the stored uid/rv), so
       create/get/list/delete/update/update_status and the three get_then_*
       composites, plus the not-found / already-exists / uid-rv-conflict error
       paths, are all reached. On failure the printer dumps the request and BOTH
       handlers' (store, response-message) results.

   (2) A directed suite (`agree_cases`, 29 cases) pins every verb AND every error
       path explicitly: each asserts BOTH [agrees = true] AND that the PORT's
       response carries the intended outcome (the expected [api_error], or success)
       — so a case labelled "conflict" genuinely exercised the conflict branch, not
       an accidental success both sides happened to agree on.

   Confirm-by-mutation (spec §5/§6, differential flavour): `mutation_tests` stand a
   locally-mutated copy of the oracle (ONE branch flipped) next to the port and
   watch the differential go false — the message-comparison leg via a GET handler
   that always reports ObjectNotFound, the store-comparison leg via a DELETE
   handler mutated to a no-op. A transient library-side mutation was also performed
   during build (documented, restored — git tree left clean) at the foot of this
   file.

   Conventions (anvil-ocaml), enforced here too: no loop keywords; every finite sum
   ([message_content] 4, [api_request]/[api_response] 9, [api_error] 12) matched
   exhaustively, no [_ ->] catch-all; no two-arm [match] on [option]/[result]
   (Option.fold / Result.fold); no exceptions. *)

module Gen = QCheck.Gen
module Oracle_api_server = Anvil_assurance.Oracle_api_server

let ( let* ) = Gen.bind

(* -- small value / key constructors ---------------------------------------- *)

let uid = Common.Uid.of_int
let rv = Common.Resource_version.of_int
let null : Value.t = Value.of_json `Null
let jstr (s : string) : Value.t = Value.of_json (`String s)
let base_meta : Object_meta.t = Object_meta.default ()
let ref_of (kind : Common.kind) (name : string) (namespace : string) : Common.object_ref =
  { Common.kind; name; namespace }

let vrs_kind : Common.kind = Common.Custom_resource "VReplicaSet"

(* One controller owner-reference, plus a non-controller and a foreign variant.
   Stored objects that carry [Some [ctrl_owner]] make the get_then_* "owned" path
   fire when a request presents the same [ctrl_owner]; [noncontroller_owner]
   drives the not-well-formed (BadRequest) leg; a mismatched owner drives the
   TransactionAbort leg. *)
let ctrl_owner : Owner_reference.t =
  {
    Owner_reference.block_owner_deletion = None;
    controller = Some true;
    kind = vrs_kind;
    name = "vrs1";
    uid = uid 1;
  }

let noncontroller_owner : Owner_reference.t = { ctrl_owner with controller = Some false }
let other_owner : Owner_reference.t = { ctrl_owner with name = "other"; uid = uid 99 }

let dyn ~(kind : Common.kind) ~(meta : Object_meta.t) ~(spec : Value.t) ~(status : Value.t) :
    Dynamic_object.t =
  Dynamic_object.make ~kind ~metadata:meta ~spec ~status

let mkobj ?(k = Common.Config_map) ?(nm = "cm") ?(ns = "ns") ?u ?r ?owners ?fins ?dt
    ?(spec = null) ?(status = null) () : Dynamic_object.t =
  let meta =
    {
      base_meta with
      name = Some nm;
      namespace = Some ns;
      uid = Option.map uid u;
      resource_version = Option.map rv r;
      owner_references = owners;
      finalizers = fins;
      deletion_timestamp = dt;
    }
  in
  dyn ~kind:k ~meta ~spec ~status

(* -- installed_types variants (all PURE: same function each side of the
      differential; a mismatch would localise a port bug, never nondeterminism) - *)

let name_is (o : Dynamic_object.t) (s : string) : bool =
  Option.fold ~none:false ~some:(String.equal s) (Object_meta.name (Dynamic_object.metadata o))

let it_permissive : Api_server.installed_types =
  {
    Api_server.unmarshallable_spec = (fun _ _ -> true);
    unmarshallable_status = (fun _ _ -> true);
    valid_object = (fun _ -> true);
    valid_transition = (fun _ _ -> true);
    marshalled_default_status = (fun _ -> null);
  }

(* Rejects the spec of a [Secret] — drives the create/update BadRequest
   (unmarshallable) admission leg. *)
let it_reject_secret : Api_server.installed_types =
  { it_permissive with unmarshallable_spec = (fun k _ -> not (Common.equal_kind k Common.Secret)) }

(* Rejects objects named "bad" — drives the [state_validation] Invalid leg. *)
let it_reject_named : Api_server.installed_types =
  { it_permissive with valid_object = (fun o -> not (name_is o "bad")) }

(* Rejects a transition into an object named "notrans" — drives the
   [transition_validation] Invalid leg on update. *)
let it_reject_transition : Api_server.installed_types =
  { it_permissive with valid_transition = (fun n _ -> not (name_is n "notrans")) }

(* A non-null default status — the created object's status comes from here, so
   this varies the created-object shape both sides must stamp identically. *)
let it_status_json : Api_server.installed_types =
  { it_permissive with marshalled_default_status = (fun _ -> jstr "default") }

let g_it : Api_server.installed_types Gen.t =
  Gen.oneof_list [ it_permissive; it_reject_secret; it_reject_named; it_reject_transition; it_status_json ]

(* -- renderers (exhaustive; used by the QCheck printer) --------------------- *)

let error_name (e : Api_method.api_error) : string =
  match e with
  | Api_method.Bad_request -> "BadRequest"
  | Api_method.Conflict -> "Conflict"
  | Api_method.Forbidden -> "Forbidden"
  | Api_method.Invalid -> "Invalid"
  | Api_method.Object_not_found -> "ObjectNotFound"
  | Api_method.Object_already_exists -> "ObjectAlreadyExists"
  | Api_method.Not_supported -> "NotSupported"
  | Api_method.Internal_error -> "InternalError"
  | Api_method.Timeout -> "Timeout"
  | Api_method.Server_timeout -> "ServerTimeout"
  | Api_method.Transaction_abort -> "TransactionAbort"
  | Api_method.Other -> "Other"

let obj_name (o : Dynamic_object.t) : string =
  Option.value ~default:"?" (Object_meta.name (Dynamic_object.metadata o))

let show_ref (k : Common.object_ref) : string =
  Printf.sprintf "%s|%s|%s" (Common.show_kind k.Common.kind) k.Common.namespace k.Common.name

let res_obj (r : (Dynamic_object.t, Api_method.api_error) result) : string =
  Result.fold ~ok:(fun o -> "Ok " ^ obj_name o) ~error:(fun e -> "Err " ^ error_name e) r

let res_unit (r : (unit, Api_method.api_error) result) : string =
  Result.fold ~ok:(fun () -> "Ok") ~error:(fun e -> "Err " ^ error_name e) r

let res_list (r : (Dynamic_object.t list, Api_method.api_error) result) : string =
  Result.fold ~ok:(fun l -> Printf.sprintf "Ok[%d]" (List.length l))
    ~error:(fun e -> "Err " ^ error_name e) r

let render_api_response (resp : Api_method.api_response) : string =
  match resp with
  | Api_method.Get_response r -> "get " ^ res_obj r.Api_method.res
  | Api_method.List_response r -> "list " ^ res_list r.Api_method.res
  | Api_method.Create_response r -> "create " ^ res_obj r.Api_method.res
  | Api_method.Delete_response r -> "delete " ^ res_unit r.Api_method.res
  | Api_method.Update_response r -> "update " ^ res_obj r.Api_method.res
  | Api_method.Update_status_response r -> "updateStatus " ^ res_obj r.Api_method.res
  | Api_method.Get_then_delete_response r -> "getThenDelete " ^ res_unit r.Api_method.res
  | Api_method.Get_then_update_response r -> "getThenUpdate " ^ res_obj r.Api_method.res
  | Api_method.Get_then_update_status_response r -> "getThenUpdateStatus " ^ res_obj r.Api_method.res

let render_request (req : Api_method.api_request) : string =
  match req with
  | Api_method.Get_request r -> "get " ^ show_ref r.Api_method.key
  | Api_method.List_request r ->
    Printf.sprintf "list %s/%s" (Common.show_kind r.Api_method.kind) r.Api_method.namespace
  | Api_method.Create_request r ->
    Printf.sprintf "create %s/%s" r.Api_method.namespace (obj_name r.Api_method.obj)
  | Api_method.Delete_request r -> "delete " ^ show_ref r.Api_method.key
  | Api_method.Update_request r ->
    Printf.sprintf "update %s/%s" r.Api_method.namespace r.Api_method.name
  | Api_method.Update_status_request r ->
    Printf.sprintf "updateStatus %s/%s" r.Api_method.namespace r.Api_method.name
  | Api_method.Get_then_delete_request r -> "getThenDelete " ^ show_ref r.Api_method.key
  | Api_method.Get_then_update_request r ->
    Printf.sprintf "getThenUpdate %s/%s" r.Api_method.namespace r.Api_method.name
  | Api_method.Get_then_update_status_request r ->
    Printf.sprintf "getThenUpdateStatus %s/%s" r.Api_method.namespace r.Api_method.name

let render_content (c : Message.message_content) : string =
  match c with
  | Message.Api_request req -> render_request req
  | Message.Api_response resp -> render_api_response resp
  | Message.External_request _ -> "external_request"
  | Message.External_response _ -> "external_response"

let show_store (store : Api_server.stored_state) : string =
  Object_ref_map.fold
    (fun (k : Common.object_ref) o acc ->
      acc
      ^ Printf.sprintf "    %s -> %s\n" (show_ref k)
          (Yojson.Safe.to_string (Dynamic_object.to_json o)))
    store ""

(* -- message plumbing ------------------------------------------------------- *)

let src_key : Common.object_ref = ref_of vrs_kind "vrs1" "ns"

let mk_msg ?(rpc = 0) (content : Message.message_content) : Message.t =
  Message.form_msg ~src:(Message.Controller (0, src_key)) ~dst:Message.Api_server
    ~rpc_id:(Message.Rpc_id.of_int rpc) ~content

(* -- generators (request conditioned on the store) -------------------------- *)

let g_kind : Common.kind Gen.t =
  Gen.oneof_list [ Common.Config_map; Common.Pod; vrs_kind; Common.Secret ]

let g_name : string Gen.t = Gen.oneof_list [ "a"; "b"; "c"; "p0"; "p1"; "vrs1"; "bad" ]
let g_ns : string Gen.t = Gen.oneof_list [ "ns"; "default" ]
let g_value : Value.t Gen.t = Gen.oneof_list [ null; jstr "a"; jstr "b"; Value.of_json (`Int 1) ]

let g_stored : (Common.object_ref * Dynamic_object.t) Gen.t =
  let* kind = g_kind in
  let* name = g_name in
  let* namespace = g_ns in
  let* u = Gen.int_bound 8 in
  let* r = Gen.int_bound 8 in
  let* owners = Gen.oneof_list [ None; Some [ ctrl_owner ]; Some [ noncontroller_owner ] ] in
  let* fins = Gen.oneof_list [ None; Some []; Some [ "f1" ] ] in
  let* dt = Gen.oneof_list [ None; Some "2000-01-01T00:00:00Z" ] in
  let* spec = g_value in
  let* status = g_value in
  let meta =
    {
      base_meta with
      name = Some name;
      namespace = Some namespace;
      uid = Some (uid u);
      resource_version = Some (rv r);
      owner_references = owners;
      finalizers = fins;
      deletion_timestamp = dt;
    }
  in
  Gen.return (ref_of kind name namespace, dyn ~kind ~meta ~spec ~status)

let g_store : Api_server.stored_state Gen.t =
  let* items = Gen.list_size (Gen.int_bound 4) g_stored in
  Gen.return
    (List.fold_left (fun m (k, o) -> Object_ref_map.add k o m) Object_ref_map.empty items)

(* Counters pinned strictly above every stored uid/rv (stored draws are <= 8),
   modelling an already-advanced api server (spec §5 "advanced counters"). *)
let g_state : Api_server.state Gen.t =
  let* store = g_store in
  let* extra_u = Gen.int_bound 20 in
  let* extra_r = Gen.int_bound 20 in
  Gen.return
    {
      Api_server.resources = store;
      uid_counter = 100 + extra_u;
      resource_version_counter = 100 + extra_r;
    }

let store_keys (store : Api_server.stored_state) : Common.object_ref list =
  Object_ref_map.fold (fun k _ acc -> k :: acc) store []

(* A target key that OVERLAPS the store with good probability: an existing key or
   a fresh pool key. Overlap drives already-exists / owned / conflict; disjoint
   drives not-found. *)
let g_key (store : Api_server.stored_state) : Common.object_ref Gen.t =
  let* kind = g_kind in
  let* name = g_name in
  let* namespace = g_ns in
  let fresh = ref_of kind name namespace in
  match store_keys store with
  | [] -> Gen.return fresh
  | _ :: _ as existing -> Gen.oneof [ Gen.oneof_list existing; Gen.return fresh ]

let stored_uid (store : Api_server.stored_state) (key : Common.object_ref) :
    Common.Uid.t option =
  Option.bind (Object_ref_map.find_opt key store) (fun o -> (Dynamic_object.metadata o).uid)

let stored_rv (store : Api_server.stored_state) (key : Common.object_ref) :
    Common.Resource_version.t option =
  Option.bind (Object_ref_map.find_opt key store) (fun o ->
      (Dynamic_object.metadata o).resource_version)

(* A precondition uid: match the stored one, an arbitrary (likely-wrong) one, or
   absent — so Conflict and its absence are both reached. *)
let g_pre_uid (store : Api_server.stored_state) (key : Common.object_ref) :
    Common.Uid.t option Gen.t =
  Gen.oneof
    [
      Gen.return (stored_uid store key);
      Gen.map (fun n -> Some (uid n)) (Gen.int_bound 8);
      Gen.return None;
    ]

let g_pre_rv (store : Api_server.stored_state) (key : Common.object_ref) :
    Common.Resource_version.t option Gen.t =
  Gen.oneof
    [
      Gen.return (stored_rv store key);
      Gen.map (fun n -> Some (rv n)) (Gen.int_bound 8);
      Gen.return None;
    ]

(* An object addressed at [key], with metadata (name/namespace/uid/rv drawn to
   sometimes match, sometimes diverge from the store) used for update-like
   requests. *)
let g_obj_at (store : Api_server.stored_state) (key : Common.object_ref) : Dynamic_object.t Gen.t
    =
  let* name_opt = Gen.oneof_weighted [ (4, Gen.return (Some key.Common.name)); (1, Gen.return None) ] in
  let* ns_opt =
    Gen.oneof_weighted
      [ (4, Gen.return (Some key.Common.namespace)); (1, Gen.oneof_list [ Some "elsewhere"; None ]) ]
  in
  let* uid_opt = g_pre_uid store key in
  let* rv_opt = g_pre_rv store key in
  let* owners = Gen.oneof_list [ None; Some [ ctrl_owner ]; Some [ ctrl_owner; other_owner ] ] in
  let* fins = Gen.oneof_list [ None; Some []; Some [ "f1" ] ] in
  let* dt = Gen.oneof_list [ None; Some "2000-01-01T00:00:00Z" ] in
  let* spec = g_value in
  let* status = g_value in
  let meta =
    {
      base_meta with
      name = name_opt;
      namespace = ns_opt;
      uid = uid_opt;
      resource_version = rv_opt;
      owner_references = owners;
      finalizers = fins;
      deletion_timestamp = dt;
    }
  in
  Gen.return (dyn ~kind:key.Common.kind ~meta ~spec ~status)

let g_owner : Owner_reference.t Gen.t =
  Gen.oneof_list [ ctrl_owner; noncontroller_owner; other_owner ]

let g_get store = Gen.map (fun k -> Message.get_req_msg_content k) (g_key store)

let g_list _store =
  let* kind = g_kind in
  let* ns = g_ns in
  Gen.return (Message.list_req_msg_content kind ns)

let g_create store =
  let* key = g_key store in
  let* use_gen = Gen.oneof_weighted [ (3, Gen.return false); (1, Gen.return true) ] in
  let* ns_match = Gen.oneof_weighted [ (4, Gen.return true); (1, Gen.return false) ] in
  let* owners = Gen.oneof_list [ None; Some [ ctrl_owner ]; Some [ ctrl_owner; other_owner ] ] in
  let* spec = g_value in
  let obj_ns = if ns_match then Some key.Common.namespace else Some "elsewhere" in
  let meta =
    if use_gen then { base_meta with generate_name = Some "gen"; namespace = obj_ns; owner_references = owners }
    else { base_meta with name = Some key.Common.name; namespace = obj_ns; owner_references = owners }
  in
  Gen.return
    (Message.create_req_msg_content key.Common.namespace (dyn ~kind:key.Common.kind ~meta ~spec ~status:null))

let g_delete store =
  let* key = g_key store in
  let* precond =
    Gen.oneof_weighted
      [
        (1, Gen.return None);
        ( 3,
          let* u = g_pre_uid store key in
          let* r = g_pre_rv store key in
          Gen.return (Some ({ Api_method.uid = u; resource_version = r } : Api_method.preconditions))
        );
      ]
  in
  Gen.return (Message.delete_req_msg_content key precond)

let g_update store =
  let* key = g_key store in
  let* obj = g_obj_at store key in
  Gen.return (Message.update_req_msg_content key.Common.namespace key.Common.name obj)

let g_update_status store =
  let* key = g_key store in
  let* obj = g_obj_at store key in
  Gen.return (Message.update_status_req_msg_content key.Common.namespace key.Common.name obj)

let g_gtd store =
  let* key = g_key store in
  let* owner = g_owner in
  Gen.return (Message.get_then_delete_req_msg_content key owner)

let g_gtu store =
  let* key = g_key store in
  let* owner = g_owner in
  let* obj = g_obj_at store key in
  Gen.return (Message.get_then_update_req_msg_content key.Common.namespace key.Common.name owner obj)

let g_gtus store =
  let* key = g_key store in
  let* owner = g_owner in
  let* obj = g_obj_at store key in
  Gen.return
    (Message.get_then_update_status_req_msg_content key.Common.namespace key.Common.name owner obj)

let g_content store =
  Gen.oneof
    [
      g_get store;
      g_list store;
      g_create store;
      g_delete store;
      g_update store;
      g_update_status store;
      g_gtd store;
      g_gtu store;
      g_gtus store;
    ]

let g_msg (st : Api_server.state) : Message.t Gen.t =
  let* rpc = Gen.int_bound 6 in
  let* content = g_content st.Api_server.resources in
  Gen.return (mk_msg ~rpc content)

let g_triple : (Api_server.installed_types * Api_server.state * Message.t) Gen.t =
  let* it = g_it in
  let* st = g_state in
  let* msg = g_msg st in
  Gen.return (it, st, msg)

let print_triple ((it, st, msg) : Api_server.installed_types * Api_server.state * Message.t) :
    string =
  let os, om = Oracle_api_server.handle it msg (Oracle_api_server.of_api_server st) in
  let ps, pm = Api_server.transition_by_etcd it msg st in
  Printf.sprintf
    "\nREQUEST: %s\nSTATE (uid=%d rv=%d):\n%sORACLE store:\n%sORACLE resp: %s\nPORT store:\n%sPORT resp: %s\n"
    (render_content msg.Message.content) st.Api_server.uid_counter
    st.Api_server.resource_version_counter (show_store st.Api_server.resources)
    (show_store os.Oracle_api_server.resources)
    (render_content om.Message.content)
    (show_store ps.Api_server.resources)
    (render_content pm.Message.content)

let prop_agree =
  QCheck.Test.make ~count:2000 ~name:"port transition_by_etcd agrees with the golden oracle"
    (QCheck.make ~print:print_triple g_triple)
    (fun (it, st, msg) -> Oracle_api_server.agrees it msg st)

(* -- directed coverage: every verb + every error path ----------------------- *)

(* A store exercising each stored shape a handler branches on: a finalizer-free
   config map, a finalizer-bearing one, a pod owned by [ctrl_owner], and a CR. *)
let st_rich : Api_server.state =
  let add k name obj s = Object_ref_map.add (ref_of k name "ns") obj s in
  Object_ref_map.empty
  |> add Common.Config_map "cm" (mkobj ~nm:"cm" ~u:2 ~r:3 ())
  |> add Common.Config_map "cmf" (mkobj ~nm:"cmf" ~u:4 ~r:5 ~fins:[ "f1" ] ())
  |> add Common.Pod "p1" (mkobj ~k:Common.Pod ~nm:"p1" ~u:8 ~r:9 ~owners:[ ctrl_owner ] ())
  |> add vrs_kind "vrs1" (mkobj ~k:vrs_kind ~nm:"vrs1" ~u:1 ~r:2 ())
  |> fun resources -> { Api_server.resources; uid_counter = 50; resource_version_counter = 50 }

(* The PORT response's error (or None on success), for asserting a directed case
   actually took its intended branch. *)
let resp_err (m : Message.t) : Api_method.api_error option =
  let e r = Result.fold ~ok:(fun _ -> None) ~error:(fun x -> Some x) r in
  match m.Message.content with
  | Message.Api_response resp -> (
    match resp with
    | Api_method.Get_response r -> e r.Api_method.res
    | Api_method.List_response r -> e r.Api_method.res
    | Api_method.Create_response r -> e r.Api_method.res
    | Api_method.Delete_response r -> e r.Api_method.res
    | Api_method.Update_response r -> e r.Api_method.res
    | Api_method.Update_status_response r -> e r.Api_method.res
    | Api_method.Get_then_delete_response r -> e r.Api_method.res
    | Api_method.Get_then_update_response r -> e r.Api_method.res
    | Api_method.Get_then_update_status_response r -> e r.Api_method.res)
  | Message.Api_request _ -> None
  | Message.External_request _ -> None
  | Message.External_response _ -> None

(* Each case: agrees = true AND the port took the expected branch (expected =
   [None] means success, [Some e] means the api_error e). *)
let agree_case (label, it, content, state, expected) : unit Alcotest.test_case =
  Alcotest.test_case label `Quick (fun () ->
      let msg = mk_msg content in
      Alcotest.(check bool) (label ^ ": port agrees with oracle") true
        (Oracle_api_server.agrees it msg state);
      let got = resp_err (snd (Api_server.transition_by_etcd it msg state)) in
      Alcotest.(check bool) (label ^ ": port took the expected branch") true
        (Option.equal Api_method.equal_api_error got expected))

let ok = None
let err e = Some e

let cm_key = ref_of Common.Config_map "cm" "ns"
let p1_key = ref_of Common.Pod "p1" "ns"

let agree_cases : (string * Api_server.installed_types * Message.message_content * Api_server.state
                   * Api_method.api_error option) list =
  [
    (* get *)
    ("get present", it_permissive, Message.get_req_msg_content cm_key, st_rich, ok);
    ( "get absent",
      it_permissive,
      Message.get_req_msg_content (ref_of Common.Config_map "nope" "ns"),
      st_rich,
      err Api_method.Object_not_found );
    (* list *)
    ("list", it_permissive, Message.list_req_msg_content Common.Config_map "ns", st_rich, ok);
    (* create *)
    ( "create fresh",
      it_permissive,
      Message.create_req_msg_content "ns" (mkobj ~nm:"cmX" ()),
      st_rich,
      ok );
    ( "create already-exists",
      it_permissive,
      Message.create_req_msg_content "ns" (mkobj ~nm:"cm" ()),
      st_rich,
      err Api_method.Object_already_exists );
    ( "create namespace mismatch",
      it_permissive,
      Message.create_req_msg_content "ns" (mkobj ~nm:"cmZ" ~ns:"other" ()),
      st_rich,
      err Api_method.Bad_request );
    ( "create generate_name",
      it_permissive,
      Message.create_req_msg_content "ns"
        (dyn ~kind:Common.Config_map
           ~meta:{ base_meta with generate_name = Some "gen"; namespace = Some "ns" }
           ~spec:null ~status:null),
      st_rich,
      ok );
    ( "create rejected by state_validation",
      it_reject_named,
      Message.create_req_msg_content "ns" (mkobj ~nm:"bad" ()),
      st_rich,
      err Api_method.Invalid );
    (* delete *)
    ("delete no-finalizer removes", it_permissive, Message.delete_req_msg_content cm_key None, st_rich, ok);
    ( "delete finalizer stamps",
      it_permissive,
      Message.delete_req_msg_content (ref_of Common.Config_map "cmf" "ns") None,
      st_rich,
      ok );
    ( "delete absent",
      it_permissive,
      Message.delete_req_msg_content (ref_of Common.Config_map "nope" "ns") None,
      st_rich,
      err Api_method.Object_not_found );
    ( "delete uid conflict",
      it_permissive,
      Message.delete_req_msg_content cm_key
        (Some { Api_method.uid = Some (uid 999); resource_version = None }),
      st_rich,
      err Api_method.Conflict );
    ( "delete rv conflict",
      it_permissive,
      Message.delete_req_msg_content cm_key
        (Some { Api_method.uid = None; resource_version = Some (rv 999) }),
      st_rich,
      err Api_method.Conflict );
    (* update *)
    ( "update changed",
      it_permissive,
      Message.update_req_msg_content "ns" "cm" (mkobj ~nm:"cm" ~r:3 ~spec:(jstr "changed") ()),
      st_rich,
      ok );
    ( "update absent",
      it_permissive,
      Message.update_req_msg_content "ns" "nope" (mkobj ~nm:"nope" ()),
      st_rich,
      err Api_method.Object_not_found );
    ( "update rv conflict",
      it_permissive,
      Message.update_req_msg_content "ns" "cm" (mkobj ~nm:"cm" ~r:999 ~spec:(jstr "x") ()),
      st_rich,
      err Api_method.Conflict );
    ( "update uid conflict",
      it_permissive,
      Message.update_req_msg_content "ns" "cm" (mkobj ~nm:"cm" ~u:999 ~spec:(jstr "x") ()),
      st_rich,
      err Api_method.Conflict );
    ( "update CR unconditional is Invalid",
      it_permissive,
      Message.update_req_msg_content "ns" "vrs1" (mkobj ~k:vrs_kind ~nm:"vrs1" ~spec:(jstr "x") ()),
      st_rich,
      err Api_method.Invalid );
    ( "update no-op",
      it_permissive,
      Message.update_req_msg_content "ns" "cm" (mkobj ~nm:"cm" ()),
      st_rich,
      ok );
    (* update_status *)
    ( "update_status changed",
      it_permissive,
      Message.update_status_req_msg_content "ns" "cm" (mkobj ~nm:"cm" ~status:(jstr "st") ()),
      st_rich,
      ok );
    ( "update_status no-op",
      it_permissive,
      Message.update_status_req_msg_content "ns" "cm" (mkobj ~nm:"cm" ()),
      st_rich,
      ok );
    (* get_then_delete *)
    ( "get_then_delete owned",
      it_permissive,
      Message.get_then_delete_req_msg_content p1_key ctrl_owner,
      st_rich,
      ok );
    ( "get_then_delete not owned",
      it_permissive,
      Message.get_then_delete_req_msg_content cm_key ctrl_owner,
      st_rich,
      err Api_method.Transaction_abort );
    ( "get_then_delete not well-formed",
      it_permissive,
      Message.get_then_delete_req_msg_content p1_key noncontroller_owner,
      st_rich,
      err Api_method.Bad_request );
    ( "get_then_delete absent",
      it_permissive,
      Message.get_then_delete_req_msg_content (ref_of Common.Config_map "nope" "ns") ctrl_owner,
      st_rich,
      err Api_method.Object_not_found );
    (* get_then_update *)
    ( "get_then_update owned",
      it_permissive,
      Message.get_then_update_req_msg_content "ns" "p1" ctrl_owner
        (mkobj ~k:Common.Pod ~nm:"p1" ~spec:(jstr "changed") ()),
      st_rich,
      ok );
    ( "get_then_update not owned",
      it_permissive,
      Message.get_then_update_req_msg_content "ns" "cm" ctrl_owner (mkobj ~nm:"cm" ()),
      st_rich,
      err Api_method.Transaction_abort );
    (* get_then_update_status *)
    ( "get_then_update_status owned",
      it_permissive,
      Message.get_then_update_status_req_msg_content "ns" "p1" ctrl_owner
        (mkobj ~k:Common.Pod ~nm:"p1" ~status:(jstr "st") ()),
      st_rich,
      ok );
    ( "get_then_update_status not owned",
      it_permissive,
      Message.get_then_update_status_req_msg_content "ns" "cm" ctrl_owner (mkobj ~nm:"cm" ()),
      st_rich,
      err Api_method.Transaction_abort );
  ]

(* -- confirm-by-mutation: a local oracle copy with ONE branch flipped -------- *)

let stores_equal (a : Api_server.stored_state) (b : Api_server.stored_state) : bool =
  Object_ref_map.equal Dynamic_object.equal a b

(* Replicates the library [agrees] but parameterised on the golden handler, so a
   mutated stand-in can be substituted. [differs_via Oracle_api_server.handle] is
   exactly [Oracle_api_server.agrees]. *)
let differs_via handle (it : Api_server.installed_types) (msg : Message.t)
    (api_state : Api_server.state) : bool =
  let os, om = handle it msg (Oracle_api_server.of_api_server api_state) in
  let ps, pm = Api_server.transition_by_etcd it msg api_state in
  stores_equal os.Oracle_api_server.resources ps.Api_server.resources && Message.equal om pm

(* Mutant A: the GET handler always reports ObjectNotFound (the "found" arm
   dropped). On a GET of a present key the port returns [Ok obj] but the mutant
   returns [Err ObjectNotFound] — the MESSAGE-comparison leg of the differential
   must then fire false. *)
let handle_mutant_get (it : Api_server.installed_types) (msg : Message.t)
    (s : Oracle_api_server.state) : Oracle_api_server.state * Message.t =
  match msg.Message.content with
  | Message.Api_request (Api_method.Get_request _) ->
    ( s,
      Message.form_get_resp_msg msg
        ({ Api_method.res = Error Api_method.Object_not_found } : Api_method.get_response) )
  | Message.Api_request
      ( Api_method.List_request _ | Api_method.Create_request _ | Api_method.Delete_request _
      | Api_method.Update_request _ | Api_method.Update_status_request _
      | Api_method.Get_then_delete_request _ | Api_method.Get_then_update_request _
      | Api_method.Get_then_update_status_request _ ) ->
    Oracle_api_server.handle it msg s
  | Message.Api_response _ -> Oracle_api_server.handle it msg s
  | Message.External_request _ -> Oracle_api_server.handle it msg s
  | Message.External_response _ -> Oracle_api_server.handle it msg s

(* Mutant B: the DELETE handler is a no-op (returns the store unchanged with a
   spurious [Ok ()]). On a delete of a present, finalizer-free object the port
   REMOVES the key but the mutant keeps it — the STORE-comparison leg must fire
   false. *)
let handle_mutant_delete (it : Api_server.installed_types) (msg : Message.t)
    (s : Oracle_api_server.state) : Oracle_api_server.state * Message.t =
  match msg.Message.content with
  | Message.Api_request (Api_method.Delete_request _) ->
    (s, Message.form_delete_resp_msg msg ({ Api_method.res = Ok () } : Api_method.delete_response))
  | Message.Api_request
      ( Api_method.Get_request _ | Api_method.List_request _ | Api_method.Create_request _
      | Api_method.Update_request _ | Api_method.Update_status_request _
      | Api_method.Get_then_delete_request _ | Api_method.Get_then_update_request _
      | Api_method.Get_then_update_status_request _ ) ->
    Oracle_api_server.handle it msg s
  | Message.Api_response _ -> Oracle_api_server.handle it msg s
  | Message.External_request _ -> Oracle_api_server.handle it msg s
  | Message.External_response _ -> Oracle_api_server.handle it msg s

let mutation_tests =
  [
    Alcotest.test_case "baseline: honest oracle agrees on GET" `Quick (fun () ->
        let msg = mk_msg (Message.get_req_msg_content cm_key) in
        Alcotest.(check bool) "baseline GET agrees" true
          (differs_via Oracle_api_server.handle it_permissive msg st_rich));
    Alcotest.test_case "mutant A (GET->not-found) breaks the message leg" `Quick (fun () ->
        let msg = mk_msg (Message.get_req_msg_content cm_key) in
        Alcotest.(check bool) "mutated GET disagrees" false
          (differs_via handle_mutant_get it_permissive msg st_rich));
    Alcotest.test_case "baseline: honest oracle agrees on DELETE" `Quick (fun () ->
        let msg = mk_msg (Message.delete_req_msg_content cm_key None) in
        Alcotest.(check bool) "baseline DELETE agrees" true
          (differs_via Oracle_api_server.handle it_permissive msg st_rich));
    Alcotest.test_case "mutant B (DELETE->no-op) breaks the store leg" `Quick (fun () ->
        let msg = mk_msg (Message.delete_req_msg_content cm_key None) in
        Alcotest.(check bool) "mutated DELETE disagrees" false
          (differs_via handle_mutant_delete it_permissive msg st_rich));
  ]

let () =
  Alcotest.run "p4_oracle"
    [
      ("property", [ QCheck_alcotest.to_alcotest prop_agree ]);
      ("directed", List.map agree_case agree_cases);
      ("mutation", mutation_tests);
    ]

(* Transient library-side mutation performed during build (spec §5/§6, restored;
   git tree left clean):
     lib/assurance/oracle_api_server.ml handle_get_request — the found arm
       [~some:(fun o -> Ok o)] was changed to [~some:(fun _ -> Error
       Api_method.Object_not_found)].
     Rebuilt and ran this executable: the "property" QCheck went RED (a GET of a
       present key: port Ok, oracle Err) and every "get present"/composite-owned
       directed case failed.
     Reverted the edit; suite back to green; `git diff lib` empty. *)

(* P7 exec-shim: the in-memory executable api-server backend and correspondence
   oracle. See exec_api_server.mli for the contract and the honest-limit
   documentation. The store is a mutable {!Api_server.state}; every request is
   driven through the trusted P2 {!Api_server.transition_by_etcd}; the transport
   effect is the identity monad ([type 'a io = 'a]). *)

type t = {
  mutable st : Api_server.state;
  installed : Api_server.installed_types;
  mutable rpc : Message.Rpc_id_allocator.t;
  self : Message.host_id;
}

type 'a io = 'a

type check = { response : Api_method.api_response; agreed : bool }

(* Render an api_error for a seed-rejection [Err.t] detail. Exhaustive over the
   twelve variants (no [_ ->]); the shim ships no [pp] dependency. *)
let api_error_to_string (e : Api_method.api_error) : string =
  match e with
  | Bad_request -> "bad_request"
  | Conflict -> "conflict"
  | Forbidden -> "forbidden"
  | Invalid -> "invalid"
  | Object_not_found -> "object_not_found"
  | Object_already_exists -> "object_already_exists"
  | Not_supported -> "not_supported"
  | Internal_error -> "internal_error"
  | Timeout -> "timeout"
  | Server_timeout -> "server_timeout"
  | Transaction_abort -> "transaction_abort"
  | Other -> "other"

(* Allocate a fresh rpc id (threading the monotone allocator forward) and wrap
   [req] in a request message from this server's controller host to the
   api-server. Mutates only [t.rpc]; leaves [t.st] untouched so the pre-transition
   state remains available to the oracle. *)
let build_msg (t : t) (req : Api_method.api_request) : Message.t =
  let rpc', rid = Message.Rpc_id_allocator.allocate t.rpc in
  t.rpc <- rpc';
  {
    Message.src = t.self;
    dst = Message.Api_server;
    rpc_id = rid;
    content = Message.Api_request req;
  }

(* Apply the trusted transition in place and unwrap the response content. A
   non-response payload is a porting-invariant violation, surfaced as [Err.t]
   (exhaustive four-arm match on [message_content], no [_ ->]). *)
let apply (t : t) (msg : Message.t) :
    (Api_method.api_response, Err.t) result =
  let st', resp_msg = Api_server.transition_by_etcd t.installed msg t.st in
  t.st <- st';
  match resp_msg.Message.content with
  | Message.Api_response r -> Ok r
  | Message.Api_request _ | Message.External_request _
  | Message.External_response _ ->
      Error
        (Err.Malformed_value
           {
             kind = "api_response";
             detail = "api-server returned non-response content";
           })

let request (t : t) (req : Api_method.api_request) :
    (Api_method.api_response, Err.t) result io =
  apply t (build_msg t req)

let request_checked (t : t) (req : Api_method.api_request) :
    (check, Err.t) result =
  let msg = build_msg t req in
  (* the oracle judges the SAME message against the PRE-transition state *)
  let agreed = Oracle_api_server.agrees t.installed msg t.st in
  Res.map (fun response -> { response; agreed }) (apply t msg)

let state (t : t) : Api_server.state = t.st

let lookup (t : t) (k : Common.object_ref) : Dynamic_object.t option =
  Api_server.lookup k t.st.Api_server.resources

(* Run [obj] through a real CREATE cycle, folding the agreement/error into the
   seeding partiality channel so seeding stays total. *)
let seed_one (t : t) () (obj : Dynamic_object.t) : unit Res.t =
  let namespace =
    Option.value ~default:"default"
      (Object_meta.namespace (Dynamic_object.metadata obj))
  in
  let req = Api_method.Create_request { Api_method.namespace; obj } in
  Res.bind (request t req) (fun resp ->
      match resp with
      | Api_method.Create_response { res = Ok _ } -> Res.ok ()
      | Api_method.Create_response { res = Error e } ->
          Res.error
            (Err.Malformed_value
               {
                 kind = "seed";
                 detail = "seed CREATE rejected: " ^ api_error_to_string e;
               })
      | Api_method.Get_response _ | Api_method.List_response _
      | Api_method.Delete_response _ | Api_method.Update_response _
      | Api_method.Update_status_response _
      | Api_method.Get_then_delete_response _
      | Api_method.Get_then_update_response _
      | Api_method.Get_then_update_status_response _ ->
          Res.error
            (Err.Malformed_value
               {
                 kind = "seed";
                 detail = "api-server returned a non-create response to a CREATE";
               }))

let create ~installed ?(seed = []) () : t Res.t =
  let st0 =
    {
      Api_server.resources = Object_ref_map.empty;
      uid_counter = 0;
      resource_version_counter = 0;
    }
  in
  let placeholder =
    {
      Common.kind = Common.Custom_resource "vreplicaset";
      name = "_";
      namespace = "default";
    }
  in
  (* the responder host id is only echoed into [dst] and never read back, so any
     valid requester ref works; derive it from the first seed when present. *)
  let cr_ref_res =
    match seed with
    | [] -> Res.ok placeholder
    | obj :: _ -> Dynamic_object.object_ref obj
  in
  Res.bind cr_ref_res (fun cr_ref ->
      let t =
        {
          st = st0;
          installed;
          rpc = Message.Rpc_id_allocator.init ();
          self = Message.Controller (0, cr_ref);
        }
      in
      Res.map (fun () -> t) (Res.fold_m (seed_one t) () seed))

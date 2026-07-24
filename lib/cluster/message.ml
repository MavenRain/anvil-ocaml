(* Anvil source: kubernetes_cluster/spec/message.rs.

   The message/transport layer. Every fn here is a total, side-effect-free port
   of an Anvil spec fn; Verus [_ => false] and partial [->0] projections become
   exhaustive matches and Option/Result combinators (no exceptions). *)

module Rpc_id = struct
  type t = int

  let zero = 0
  let of_int n = n
  let to_int t = t
  let equal (a : int) (b : int) : bool = Int.equal a b
  let compare (a : int) (b : int) : int = Int.compare a b
end

type host_id =
  | Api_server
  | Builtin_controller
  | Controller of int * Common.object_ref
  | External of int
  | Pod_monkey

let equal_host_id (a : host_id) (b : host_id) : bool =
  match (a, b) with
  | Api_server, Api_server -> true
  | Builtin_controller, Builtin_controller -> true
  | Controller (i1, k1), Controller (i2, k2) ->
    Int.equal i1 i2 && Common.equal_object_ref k1 k2
  | External i1, External i2 -> Int.equal i1 i2
  | Pod_monkey, Pod_monkey -> true
  | ( ( Api_server | Builtin_controller | Controller _ | External _
      | Pod_monkey ),
      _ ) ->
    false

(* Anvil [HostId::is_controller_id] (message.rs:242): the four non-[Controller]
   arms are Anvil's [_ => false], spelled out exhaustively (no wildcard). *)
let is_controller_id (h : host_id) (controller_id : int) : bool =
  match h with
  | Controller (id, _) -> Int.equal id controller_id
  | Api_server | Builtin_controller | External _ | Pod_monkey -> false

type message_content =
  | Api_request of Api_method.api_request
  | Api_response of Api_method.api_response
  | External_request of Value.t
  | External_response of Value.t

(* Structural equality on the nine-variant [APIRequest] sum; each arm compares
   the paired struct's fields through the P1 equality functions. The trailing
   arm enumerates all nine constructors on the left, so a new request variant is
   a compile error (never a silent match). *)
let equal_api_request (a : Api_method.api_request) (b : Api_method.api_request) :
    bool =
  let open Api_method in
  match (a, b) with
  | Get_request x, Get_request y -> Common.equal_object_ref x.key y.key
  | List_request x, List_request y ->
    Common.equal_kind x.kind y.kind && String.equal x.namespace y.namespace
  | Create_request x, Create_request y ->
    String.equal x.namespace y.namespace && Dynamic_object.equal x.obj y.obj
  | Delete_request x, Delete_request y ->
    Common.equal_object_ref x.key y.key
    && Option.equal equal_preconditions x.preconditions y.preconditions
  | Update_request x, Update_request y ->
    String.equal x.namespace y.namespace
    && String.equal x.name y.name
    && Dynamic_object.equal x.obj y.obj
  | Update_status_request x, Update_status_request y ->
    String.equal x.namespace y.namespace
    && String.equal x.name y.name
    && Dynamic_object.equal x.obj y.obj
  | Get_then_delete_request x, Get_then_delete_request y ->
    Common.equal_object_ref x.key y.key
    && Owner_reference.equal x.owner_ref y.owner_ref
  | Get_then_update_request x, Get_then_update_request y ->
    String.equal x.namespace y.namespace
    && String.equal x.name y.name
    && Owner_reference.equal x.owner_ref y.owner_ref
    && Dynamic_object.equal x.obj y.obj
  | Get_then_update_status_request x, Get_then_update_status_request y ->
    String.equal x.namespace y.namespace
    && String.equal x.name y.name
    && Owner_reference.equal x.owner_ref y.owner_ref
    && Dynamic_object.equal x.obj y.obj
  | ( ( Get_request _ | List_request _ | Create_request _ | Delete_request _
      | Update_request _ | Update_status_request _ | Get_then_delete_request _
      | Get_then_update_request _ | Get_then_update_status_request _ ),
      _ ) ->
    false

(* Structural equality on the nine-variant [APIResponse] sum. Each response
   carries a [res : (_, api_error) result]; Result/List equality via combinators
   (no two-arm match on result). *)
let equal_api_response (a : Api_method.api_response)
    (b : Api_method.api_response) : bool =
  let open Api_method in
  let eq_obj = Result.equal ~ok:Dynamic_object.equal ~error:equal_api_error in
  let eq_unit = Result.equal ~ok:(fun () () -> true) ~error:equal_api_error in
  let eq_objs =
    Result.equal ~ok:(List.equal Dynamic_object.equal) ~error:equal_api_error
  in
  match (a, b) with
  | Get_response x, Get_response y -> eq_obj x.res y.res
  | List_response x, List_response y -> eq_objs x.res y.res
  | Create_response x, Create_response y -> eq_obj x.res y.res
  | Delete_response x, Delete_response y -> eq_unit x.res y.res
  | Update_response x, Update_response y -> eq_obj x.res y.res
  | Update_status_response x, Update_status_response y -> eq_obj x.res y.res
  | Get_then_delete_response x, Get_then_delete_response y -> eq_unit x.res y.res
  | Get_then_update_response x, Get_then_update_response y -> eq_obj x.res y.res
  | Get_then_update_status_response x, Get_then_update_status_response y ->
    eq_obj x.res y.res
  | ( ( Get_response _ | List_response _ | Create_response _ | Delete_response _
      | Update_response _ | Update_status_response _ | Get_then_delete_response _
      | Get_then_update_response _ | Get_then_update_status_response _ ),
      _ ) ->
    false

let equal_message_content (a : message_content) (b : message_content) : bool =
  match (a, b) with
  | Api_request x, Api_request y -> equal_api_request x y
  | Api_response x, Api_response y -> equal_api_response x y
  | External_request x, External_request y -> Value.equal x y
  | External_response x, External_response y -> Value.equal x y
  | ( ( Api_request _ | Api_response _ | External_request _
      | External_response _ ),
      _ ) ->
    false

type t = {
  src : host_id;
  dst : host_id;
  rpc_id : Rpc_id.t;
  content : message_content;
}

let equal (a : t) (b : t) : bool =
  equal_host_id a.src b.src
  && equal_host_id a.dst b.dst
  && Rpc_id.equal a.rpc_id b.rpc_id
  && equal_message_content a.content b.content

module Pool = Multiset.Make (struct
  type nonrec t = t

  let equal = equal
end)

module Rpc_id_allocator = struct
  type t = { rpc_id_counter : int }

  let init () : t = { rpc_id_counter = 0 }

  (* Anvil [RPCIdAllocator::allocate] (message.rs:52): allocated id = CURRENT
     counter; the returned allocator carries [counter + 1]. *)
  let allocate (a : t) : t * Rpc_id.t =
    ({ rpc_id_counter = a.rpc_id_counter + 1 }, Rpc_id.of_int a.rpc_id_counter)

  (* Anvil [RPCIdAllocator] (message.rs:36) is its monotone [rpc_id_counter], so
     counter equality is faithful state equality. *)
  let equal (a : t) (b : t) : bool = Int.equal a.rpc_id_counter b.rpc_id_counter
end

type message_ops = { recv : t option; send : Pool.t }

let form_msg ~(src : host_id) ~(dst : host_id) ~(rpc_id : Rpc_id.t)
    ~(content : message_content) : t =
  { src; dst; rpc_id; content }

let controller_req_msg (controller_id : int) (cr_key : Common.object_ref)
    (req_id : Rpc_id.t) (req : Api_method.api_request) : t =
  form_msg
    ~src:(Controller (controller_id, cr_key))
    ~dst:Api_server ~rpc_id:req_id ~content:(Api_request req)

let controller_external_req_msg (controller_id : int)
    (cr_key : Common.object_ref) (req_id : Rpc_id.t) (req : Value.t) : t =
  form_msg
    ~src:(Controller (controller_id, cr_key))
    ~dst:(External controller_id)
    ~rpc_id:req_id
    ~content:(External_request req)

let built_in_controller_req_msg (rpc_id : Rpc_id.t)
    (msg_content : message_content) : t =
  form_msg ~src:Builtin_controller ~dst:Api_server ~rpc_id ~content:msg_content

let pod_monkey_req_msg (rpc_id : Rpc_id.t) (msg_content : message_content) : t =
  form_msg ~src:Pod_monkey ~dst:Api_server ~rpc_id ~content:msg_content

(* The nine [form_*_resp_msg] builders (Anvil macro [declare_form_resp_msg_
   functions], message.rs:461): each swaps [src]/[dst], preserves [rpc_id], and
   wraps the response struct in [Api_response (<X>_response resp)]. *)
let form_get_resp_msg (req_msg : t) (resp : Api_method.get_response) : t =
  form_msg ~src:req_msg.dst ~dst:req_msg.src ~rpc_id:req_msg.rpc_id
    ~content:(Api_response (Api_method.Get_response resp))

let form_list_resp_msg (req_msg : t) (resp : Api_method.list_response) : t =
  form_msg ~src:req_msg.dst ~dst:req_msg.src ~rpc_id:req_msg.rpc_id
    ~content:(Api_response (Api_method.List_response resp))

let form_create_resp_msg (req_msg : t) (resp : Api_method.create_response) : t =
  form_msg ~src:req_msg.dst ~dst:req_msg.src ~rpc_id:req_msg.rpc_id
    ~content:(Api_response (Api_method.Create_response resp))

let form_delete_resp_msg (req_msg : t) (resp : Api_method.delete_response) : t =
  form_msg ~src:req_msg.dst ~dst:req_msg.src ~rpc_id:req_msg.rpc_id
    ~content:(Api_response (Api_method.Delete_response resp))

let form_update_resp_msg (req_msg : t) (resp : Api_method.update_response) : t =
  form_msg ~src:req_msg.dst ~dst:req_msg.src ~rpc_id:req_msg.rpc_id
    ~content:(Api_response (Api_method.Update_response resp))

let form_update_status_resp_msg (req_msg : t)
    (resp : Api_method.update_status_response) : t =
  form_msg ~src:req_msg.dst ~dst:req_msg.src ~rpc_id:req_msg.rpc_id
    ~content:(Api_response (Api_method.Update_status_response resp))

let form_get_then_delete_resp_msg (req_msg : t)
    (resp : Api_method.get_then_delete_response) : t =
  form_msg ~src:req_msg.dst ~dst:req_msg.src ~rpc_id:req_msg.rpc_id
    ~content:(Api_response (Api_method.Get_then_delete_response resp))

let form_get_then_update_resp_msg (req_msg : t)
    (resp : Api_method.get_then_update_response) : t =
  form_msg ~src:req_msg.dst ~dst:req_msg.src ~rpc_id:req_msg.rpc_id
    ~content:(Api_response (Api_method.Get_then_update_response resp))

let form_get_then_update_status_resp_msg (req_msg : t)
    (resp : Api_method.get_then_update_status_response) : t =
  form_msg ~src:req_msg.dst ~dst:req_msg.src ~rpc_id:req_msg.rpc_id
    ~content:(Api_response (Api_method.Get_then_update_status_response resp))

(* The nine [*_req_msg_content] builders (message.rs:157): wrap an [APIRequest]
   struct in [Api_request]. Record fields are resolved by the constructor
   context. *)
let get_req_msg_content (key : Common.object_ref) : message_content =
  Api_request (Api_method.Get_request { key })

let list_req_msg_content (kind : Common.kind) (namespace : string) :
    message_content =
  Api_request (Api_method.List_request { kind; namespace })

let create_req_msg_content (namespace : string) (obj : Dynamic_object.t) :
    message_content =
  Api_request (Api_method.Create_request { namespace; obj })

let delete_req_msg_content (key : Common.object_ref)
    (preconditions : Api_method.preconditions option) : message_content =
  Api_request (Api_method.Delete_request { key; preconditions })

let update_req_msg_content (namespace : string) (name : string)
    (obj : Dynamic_object.t) : message_content =
  Api_request (Api_method.Update_request { namespace; name; obj })

let update_status_req_msg_content (namespace : string) (name : string)
    (obj : Dynamic_object.t) : message_content =
  Api_request (Api_method.Update_status_request { namespace; name; obj })

let get_then_delete_req_msg_content (key : Common.object_ref)
    (owner_ref : Owner_reference.t) : message_content =
  Api_request (Api_method.Get_then_delete_request { key; owner_ref })

let get_then_update_req_msg_content (namespace : string) (name : string)
    (owner_ref : Owner_reference.t) (obj : Dynamic_object.t) : message_content =
  Api_request
    (Api_method.Get_then_update_request { namespace; name; owner_ref; obj })

let get_then_update_status_req_msg_content (namespace : string) (name : string)
    (owner_ref : Owner_reference.t) (obj : Dynamic_object.t) : message_content =
  Api_request
    (Api_method.Get_then_update_status_request
       { namespace; name; owner_ref; obj })

(* Anvil [received_msg_destined_for] (message.rs:233): [None] is vacuously true;
   combinator, not a two-arm match on the option. *)
let received_msg_destined_for (recv : t option) (host_id : host_id) : bool =
  Option.fold ~none:true ~some:(fun (m : t) -> equal_host_id m.dst host_id) recv

(* Anvil [resp_msg_matches_req_msg] (message.rs:98): API-block OR external-block.
   Each block matches the (resp, req) content pair; the API block additionally
   requires the paired request/response kind (positional pairing: the request and
   response sums share source order, so equal tags = paired kinds). The trailing
   enumerated arms keep the sums exhaustive. *)
let resp_msg_matches_req_msg (resp_msg : t) (req_msg : t) : bool =
  let crossover =
    equal_host_id resp_msg.dst req_msg.src
    && equal_host_id resp_msg.src req_msg.dst
    && Rpc_id.equal resp_msg.rpc_id req_msg.rpc_id
  in
  let paired_kind (resp : Api_method.api_response)
      (req : Api_method.api_request) : bool =
    let open Api_method in
    match (resp, req) with
    | Get_response _, Get_request _ -> true
    | List_response _, List_request _ -> true
    | Create_response _, Create_request _ -> true
    | Delete_response _, Delete_request _ -> true
    | Update_response _, Update_request _ -> true
    | Update_status_response _, Update_status_request _ -> true
    | Get_then_delete_response _, Get_then_delete_request _ -> true
    | Get_then_update_response _, Get_then_update_request _ -> true
    | Get_then_update_status_response _, Get_then_update_status_request _ -> true
    | ( ( Get_response _ | List_response _ | Create_response _
        | Delete_response _ | Update_response _ | Update_status_response _
        | Get_then_delete_response _ | Get_then_update_response _
        | Get_then_update_status_response _ ),
        _ ) ->
      false
  in
  let api_block =
    match (resp_msg.content, req_msg.content) with
    | Api_response resp, Api_request req -> crossover && paired_kind resp req
    | ( ( Api_request _ | Api_response _ | External_request _
        | External_response _ ),
        _ ) ->
      false
  in
  let external_block =
    match (resp_msg.content, req_msg.content) with
    | External_response _, External_request _ -> crossover
    | ( ( Api_request _ | Api_response _ | External_request _
        | External_response _ ),
        _ ) ->
      false
  in
  api_block || external_block

(* Anvil [form_matched_err_resp_msg] (message.rs:126): match the request kind and
   build the paired [*_response] carrying [Error err]. Anvil [recommends] the
   content is an [Api_request]; the three non-request contents are unreachable in
   a well-formed cluster and return the input unchanged (total completion of the
   [recommends], no exception). *)
let form_matched_err_resp_msg (req_msg : t) (err : Api_method.api_error) : t =
  let open Api_method in
  match req_msg.content with
  | Api_request req -> (
    match req with
    | Get_request _ -> form_get_resp_msg req_msg { res = Error err }
    | List_request _ -> form_list_resp_msg req_msg { res = Error err }
    | Create_request _ -> form_create_resp_msg req_msg { res = Error err }
    | Delete_request _ -> form_delete_resp_msg req_msg { res = Error err }
    | Update_request _ -> form_update_resp_msg req_msg { res = Error err }
    | Update_status_request _ ->
      form_update_status_resp_msg req_msg { res = Error err }
    | Get_then_delete_request _ ->
      form_get_then_delete_resp_msg req_msg { res = Error err }
    | Get_then_update_request _ ->
      form_get_then_update_resp_msg req_msg { res = Error err }
    | Get_then_update_status_request _ ->
      form_get_then_update_status_resp_msg req_msg { res = Error err })
  | Api_response _ | External_request _ | External_response _ -> req_msg

let form_external_resp_msg (req_msg : t) (resp : Value.t) : t =
  form_msg ~src:req_msg.dst ~dst:req_msg.src ~rpc_id:req_msg.rpc_id
    ~content:(External_response resp)

(* Anvil source: kubernetes_api_objects/spec/api_method.rs, error.rs,
   preconditions.rs, api_resource.rs. *)

type api_error =
  | Bad_request
  | Conflict
  | Forbidden
  | Invalid
  | Object_not_found
  | Object_already_exists
  | Not_supported
  | Internal_error
  | Timeout
  | Server_timeout
  | Transaction_abort
  | Other

let equal_api_error (a : api_error) (b : api_error) : bool =
  match (a, b) with
  | Bad_request, Bad_request -> true
  | Conflict, Conflict -> true
  | Forbidden, Forbidden -> true
  | Invalid, Invalid -> true
  | Object_not_found, Object_not_found -> true
  | Object_already_exists, Object_already_exists -> true
  | Not_supported, Not_supported -> true
  | Internal_error, Internal_error -> true
  | Timeout, Timeout -> true
  | Server_timeout, Server_timeout -> true
  | Transaction_abort, Transaction_abort -> true
  | Other, Other -> true
  | ( ( Bad_request | Conflict | Forbidden | Invalid | Object_not_found
      | Object_already_exists | Not_supported | Internal_error | Timeout
      | Server_timeout | Transaction_abort | Other ),
      _ ) ->
    false

type preconditions = {
  uid : Common.Uid.t option;
  resource_version : Common.Resource_version.t option;
}

let preconditions_default () : preconditions =
  { uid = None; resource_version = None }

let with_uid_from_object_meta (m : Object_meta.t) (p : preconditions) :
    preconditions =
  { p with uid = m.uid }

let with_resource_version_from_object_meta (m : Object_meta.t)
    (p : preconditions) : preconditions =
  { p with resource_version = m.resource_version }

let equal_preconditions (a : preconditions) (b : preconditions) : bool =
  Option.equal Common.Uid.equal a.uid b.uid
  && Option.equal Common.Resource_version.equal a.resource_version
       b.resource_version

type api_resource = { kind : Common.kind }

let equal_api_resource (a : api_resource) (b : api_resource) : bool =
  Common.equal_kind a.kind b.kind

type get_request = { key : Common.object_ref }
type list_request = { kind : Common.kind; namespace : string }
type create_request = { namespace : string; obj : Dynamic_object.t }

type delete_request = {
  key : Common.object_ref;
  preconditions : preconditions option;
}

type update_request = {
  namespace : string;
  name : string;
  obj : Dynamic_object.t;
}

type update_status_request = {
  namespace : string;
  name : string;
  obj : Dynamic_object.t;
}

type get_then_delete_request = {
  key : Common.object_ref;
  owner_ref : Owner_reference.t;
}

type get_then_update_request = {
  namespace : string;
  name : string;
  owner_ref : Owner_reference.t;
  obj : Dynamic_object.t;
}

type get_then_update_status_request = {
  namespace : string;
  name : string;
  owner_ref : Owner_reference.t;
  obj : Dynamic_object.t;
}

type api_request =
  | Get_request of get_request
  | List_request of list_request
  | Create_request of create_request
  | Delete_request of delete_request
  | Update_request of update_request
  | Update_status_request of update_status_request
  | Get_then_delete_request of get_then_delete_request
  | Get_then_update_request of get_then_update_request
  | Get_then_update_status_request of get_then_update_status_request

let get_request_key (r : get_request) : Common.object_ref = r.key
let delete_request_key (r : delete_request) : Common.object_ref = r.key

let update_request_key (r : update_request) : Common.object_ref =
  {
    Common.kind = Dynamic_object.kind r.obj;
    namespace = r.namespace;
    name = r.name;
  }

let update_status_request_key (r : update_status_request) : Common.object_ref =
  {
    Common.kind = Dynamic_object.kind r.obj;
    namespace = r.namespace;
    name = r.name;
  }

let get_then_delete_request_key (r : get_then_delete_request) :
    Common.object_ref =
  r.key

let get_then_update_request_key (r : get_then_update_request) :
    Common.object_ref =
  {
    Common.kind = Dynamic_object.kind r.obj;
    namespace = r.namespace;
    name = r.name;
  }

let get_then_update_status_request_key (r : get_then_update_status_request) :
    Common.object_ref =
  {
    Common.kind = Dynamic_object.kind r.obj;
    namespace = r.namespace;
    name = r.name;
  }

let create_request_key (r : create_request) : Common.object_ref Res.t =
  let open Res in
  let* name =
    of_option
      ~none:(Err.Missing_field { owner = "obj.metadata"; field = "name" })
      (Object_meta.name (Dynamic_object.metadata r.obj))
  in
  ok { Common.kind = Dynamic_object.kind r.obj; name; namespace = r.namespace }

let get_then_delete_well_formed (r : get_then_delete_request) : bool =
  Owner_reference.is_controller r.owner_ref

let get_then_update_well_formed (r : get_then_update_request) : bool =
  Owner_reference.is_controller r.owner_ref

let get_then_update_status_well_formed (r : get_then_update_status_request) :
    bool =
  Owner_reference.is_controller r.owner_ref

type get_response = { res : (Dynamic_object.t, api_error) result }
type list_response = { res : (Dynamic_object.t list, api_error) result }
type create_response = { res : (Dynamic_object.t, api_error) result }
type delete_response = { res : (unit, api_error) result }
type update_response = { res : (Dynamic_object.t, api_error) result }
type update_status_response = { res : (Dynamic_object.t, api_error) result }
type get_then_delete_response = { res : (unit, api_error) result }
type get_then_update_response = { res : (Dynamic_object.t, api_error) result }

type get_then_update_status_response = {
  res : (Dynamic_object.t, api_error) result;
}

type api_response =
  | Get_response of get_response
  | List_response of list_response
  | Create_response of create_response
  | Delete_response of delete_response
  | Update_response of update_response
  | Update_status_response of update_status_response
  | Get_then_delete_response of get_then_delete_response
  | Get_then_update_response of get_then_update_response
  | Get_then_update_status_response of get_then_update_status_response

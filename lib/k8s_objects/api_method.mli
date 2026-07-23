(** Anvil source: kubernetes_api_objects/spec/api_method.rs (the [APIRequest] /
    [APIResponse] sums and their per-kind request/response structs),
    error.rs ([APIError]), preconditions.rs ([PreconditionsView]) and
    api_resource.rs ([ApiResourceView]).

    [Watch] and [Patch] are intentionally not modelled by Anvil and so are
    absent here too. *)

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
(** [APIError] (error.rs): twelve unit variants, the [Err] of every response. *)

val equal_api_error : api_error -> api_error -> bool
(** Structural equality on {!api_error}. *)

type preconditions = {
  uid : Common.Uid.t option;
  resource_version : Common.Resource_version.t option;
}
(** [PreconditionsView] (preconditions.rs). *)

val preconditions_default : unit -> preconditions
(** [PreconditionsView::default]: both fields [None]. *)

val with_uid_from_object_meta : Object_meta.t -> preconditions -> preconditions
(** [with_uid_from_object_meta]: take [uid] from an object's metadata. *)

val with_resource_version_from_object_meta :
  Object_meta.t -> preconditions -> preconditions
(** [with_resource_version_from_object_meta]. *)

val equal_preconditions : preconditions -> preconditions -> bool
(** Structural equality on {!preconditions}. *)

type api_resource = { kind : Common.kind }
(** [ApiResourceView] (api_resource.rs): a single [kind] field. *)

val equal_api_resource : api_resource -> api_resource -> bool
(** Structural equality on {!api_resource}. *)

type get_request = { key : Common.object_ref }
(** [GetRequest]; [key] is the target [ObjectRef]. *)

type list_request = { kind : Common.kind; namespace : string }
(** [ListRequest]: a kind within a namespace. *)

type create_request = { namespace : string; obj : Dynamic_object.t }
(** [CreateRequest]. *)

type delete_request = {
  key : Common.object_ref;
  preconditions : preconditions option;
}
(** [DeleteRequest]. *)

type update_request = {
  namespace : string;
  name : string;
  obj : Dynamic_object.t;
}
(** [UpdateRequest]. *)

type update_status_request = {
  namespace : string;
  name : string;
  obj : Dynamic_object.t;
}
(** [UpdateStatusRequest]; same field set as [UpdateRequest]. *)

type get_then_delete_request = {
  key : Common.object_ref;
  owner_ref : Owner_reference.t;
}
(** [GetThenDeleteRequest]. *)

type get_then_update_request = {
  namespace : string;
  name : string;
  owner_ref : Owner_reference.t;
  obj : Dynamic_object.t;
}
(** [GetThenUpdateRequest]. *)

type get_then_update_status_request = {
  namespace : string;
  name : string;
  owner_ref : Owner_reference.t;
  obj : Dynamic_object.t;
}
(** [GetThenUpdateStatusRequest]; same shape as [GetThenUpdateRequest]. *)

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
      (** [APIRequest]: nine variants, one per request struct, source order. *)

val get_request_key : get_request -> Common.object_ref
(** [GetRequest::key]: [self.key]. *)

val delete_request_key : delete_request -> Common.object_ref
(** [DeleteRequest::key]: [self.key]. *)

val update_request_key : update_request -> Common.object_ref
(** [UpdateRequest::key]: [{obj.kind; namespace; name}]. *)

val update_status_request_key : update_status_request -> Common.object_ref
(** [UpdateStatusRequest::key]: [{obj.kind; namespace; name}]. *)

val get_then_delete_request_key : get_then_delete_request -> Common.object_ref
(** [GetThenDeleteRequest::key]: [self.key]. *)

val get_then_update_request_key : get_then_update_request -> Common.object_ref
(** [GetThenUpdateRequest::key]: [{obj.kind; namespace; name}]. *)

val get_then_update_status_request_key :
  get_then_update_status_request -> Common.object_ref
(** [GetThenUpdateStatusRequest::key]: [{obj.kind; namespace; name}]. *)

val create_request_key : create_request -> Common.object_ref Res.t
(** [CreateRequest::key]: [{obj.kind; namespace; obj.metadata.name}]; the name
    unwrap becomes {!Err.Missing_field} when absent. *)

val get_then_delete_well_formed : get_then_delete_request -> bool
(** [GetThenDeleteRequest::well_formed]: [owner_ref] is a controller. *)

val get_then_update_well_formed : get_then_update_request -> bool
(** [GetThenUpdateRequest::well_formed]: [owner_ref] is a controller. *)

val get_then_update_status_well_formed :
  get_then_update_status_request -> bool
(** [GetThenUpdateStatusRequest::well_formed]: [owner_ref] is a controller. *)

type get_response = { res : (Dynamic_object.t, api_error) result }
(** [GetResponse]. *)

type list_response = { res : (Dynamic_object.t list, api_error) result }
(** [ListResponse]; the [Ok] payload is a sequence of objects. *)

type create_response = { res : (Dynamic_object.t, api_error) result }
(** [CreateResponse]. *)

type delete_response = { res : (unit, api_error) result }
(** [DeleteResponse]; [Ok] is [()] — the deleted object is not returned. *)

type update_response = { res : (Dynamic_object.t, api_error) result }
(** [UpdateResponse]. *)

type update_status_response = { res : (Dynamic_object.t, api_error) result }
(** [UpdateStatusResponse]. *)

type get_then_delete_response = { res : (unit, api_error) result }
(** [GetThenDeleteResponse]; [Ok] is [()]. *)

type get_then_update_response = { res : (Dynamic_object.t, api_error) result }
(** [GetThenUpdateResponse]. *)

type get_then_update_status_response = {
  res : (Dynamic_object.t, api_error) result;
}
(** [GetThenUpdateStatusResponse]. *)

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
      (** [APIResponse]: nine variants, one per response struct, source order. *)

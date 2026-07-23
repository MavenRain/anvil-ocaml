(** Anvil source: kubernetes_api_objects/spec/owner_reference.rs
    ([OwnerReferenceView] and its free spec functions). *)

type t = {
  block_owner_deletion : bool option;
  controller : bool option;
  kind : Common.kind;
  name : string;
  uid : Common.Uid.t;
}
(** [OwnerReferenceView]: five fields; [block_owner_deletion]/[controller] are
    optional, [kind]/[name]/[uid] are not. *)

val default : unit -> t
(** Anvil's [OwnerReferenceView::default] is [uninterp] (present only to satisfy
    the [implement_field_wrapper_type] macro). We provide a documented,
    all-empty placeholder: both options [None], [kind = Custom_resource ""],
    empty [name], [uid] zero. *)

val to_object_reference : t -> namespace:string -> Common.object_ref
(** Anvil [owner_reference_to_object_reference]: [{kind; namespace; name}]. *)

val is_controller : t -> bool
(** Anvil [controller_owner_filter]: [controller] is [Some true]. *)

val eq_without_uid : t -> t -> bool
(** Anvil [owner_reference_eq_without_uid]: compares [controller],
    [block_owner_deletion], [kind] and [name] (deliberately excludes [uid]). *)

val equal : t -> t -> bool
(** Structural equality over all five fields. *)

val to_json : t -> Yojson.Safe.t
(** Marshal (serde_json analogue); optionals dropped when [None]. *)

val of_json : Yojson.Safe.t -> t Res.t
(** Unmarshal; {!Err.Missing_field} on an absent required field. *)

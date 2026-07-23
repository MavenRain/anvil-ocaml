(** Anvil source: kubernetes_api_objects/spec/dynamic.rs ([DynamicObjectView]),
    the untyped object the {!Resource_view.Make} functor marshals to and
    unmarshals from. *)

type t
(** [DynamicObjectView]: [{kind; metadata; spec; status}] with [spec]/[status]
    marshalled {!Value.t}s. Abstract; build with {!make}. *)

val make :
  kind:Common.kind ->
  metadata:Object_meta.t ->
  spec:Value.t ->
  status:Value.t ->
  t
(** The struct constructor used by {!Resource_view.Make.marshal}. *)

val kind : t -> Common.kind
(** The [kind] field. *)

val metadata : t -> Object_meta.t
(** The [metadata] field. *)

val spec : t -> Value.t
(** The marshalled [spec] field. *)

val status : t -> Value.t
(** The marshalled [status] field. *)

val object_ref : t -> Common.object_ref Res.t
(** Anvil [object_ref]: [{kind; metadata.name; metadata.namespace}]; the two
    [Option] unwraps become {!Err.Missing_field} when absent. *)

val with_metadata : Object_meta.t -> t -> t
(** Anvil [with_metadata]. *)

val with_name : string -> t -> t
(** Anvil [with_name]: sets [metadata.name]. *)

val with_namespace : string -> t -> t
(** Anvil [with_namespace]: sets [metadata.namespace]. *)

val with_resource_version : Common.Resource_version.t -> t -> t
(** Anvil [with_resource_version]: sets [metadata.resource_version]. *)

val with_uid : Common.Uid.t -> t -> t
(** Anvil [with_uid]: sets [metadata.uid]. *)

val with_deletion_timestamp : string -> t -> t
(** Anvil [with_deletion_timestamp]: sets [metadata.deletion_timestamp]. *)

val equal : t -> t -> bool
(** Structural equality (kind, metadata, spec, status). *)

val to_json : t -> Yojson.Safe.t
(** Whole-object marshal. *)

val of_json : Yojson.Safe.t -> t Res.t
(** Whole-object unmarshal. *)

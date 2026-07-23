(** Anvil source: kubernetes_api_objects/spec/object_meta.rs ([ObjectMetaView],
    ten fields, all optional).

    The [with_*]/[add_*]/[without_*] mutators take their data first and the
    subject last so they compose under [|>] (Anvil's method-receiver order is
    not observable); the query functions take the subject first. *)

type t = {
  name : string option;
  generate_name : string option;
  namespace : string option;
  resource_version : Common.Resource_version.t option;
  uid : Common.Uid.t option;
  labels : string Smap.t option;
  annotations : string Smap.t option;
  owner_references : Owner_reference.t list option;
  finalizers : string list option;
  deletion_timestamp : string option;
}
(** [ObjectMetaView]. Exactly these ten optional fields — no
    [creation_timestamp], [cluster_name], etc. *)

val default : unit -> t
(** [ObjectMetaView::default]: every field [None]. *)

val name : t -> string option
(** The [name] field; the derived [object_ref] requires it (function form used
    by {!Resource_view.Make}). *)

val namespace : t -> string option
(** The [namespace] field; required by the derived [object_ref]. *)

val with_name : string -> t -> t
(** Anvil [with_name]. *)

val with_generate_name : string -> t -> t
(** Anvil [with_generate_name]. *)

val with_namespace : string -> t -> t
(** Anvil [with_namespace]. *)

val with_labels : string Smap.t -> t -> t
(** Anvil [with_labels]. *)

val add_label : string -> string -> t -> t
(** Anvil [add_label key value]: insert into the existing labels map or a fresh
    empty one. *)

val without_label : string -> t -> t
(** Anvil [without_label key]: remove from labels when present, else unchanged. *)

val without_labels : t -> t
(** Anvil [without_labels]: labels [None]. *)

val with_annotations : string Smap.t -> t -> t
(** Anvil [with_annotations]. *)

val without_annotations : t -> t
(** Anvil [without_annotations]. *)

val add_annotation : string -> string -> t -> t
(** Anvil [add_annotation key value]. *)

val with_resource_version : Common.Resource_version.t -> t -> t
(** Anvil [with_resource_version]. *)

val without_resource_version : t -> t
(** Anvil [without_resource_version]. *)

val with_owner_references : Owner_reference.t list -> t -> t
(** Anvil [with_owner_references]. *)

val with_finalizers : string list -> t -> t
(** Anvil [with_finalizers]. *)

val without_finalizers : t -> t
(** Anvil [without_finalizers]. *)

val with_deletion_timestamp : string -> t -> t
(** Anvil [with_deletion_timestamp]. *)

val without_deletion_timestamp : t -> t
(** Anvil [without_deletion_timestamp]. *)

val owner_references_contains : t -> Owner_reference.t -> bool
(** Anvil [owner_references_contains]: [Some refs => refs.contains r], else
    [false]. *)

val owner_references_only_contains : t -> Owner_reference.t -> bool
(** Anvil [owner_references_only_contains]: [Some refs => refs = [r]], else
    [false]. *)

val finalizers_as_set : t -> Sset.t
(** Anvil [finalizers_as_set]: [None => empty], else the finalizers as a set. *)

val well_formed_for_namespaced : t -> bool
(** Anvil [well_formed_for_namespaced]: [name], [namespace], [resource_version]
    and [uid] all [Some]. The only well-formedness predicate. *)

val equal : t -> t -> bool
(** Structural equality over all ten fields. *)

val to_json : t -> Yojson.Safe.t
(** Marshal; optionals dropped when [None]. *)

val of_json : Yojson.Safe.t -> t Res.t
(** Unmarshal; absent optionals read back as [None]. *)

(** Anvil source: kubernetes_api_objects/spec/config_map.rs ([ConfigMapView] and
    its [implement_resource_view_trait!] instance).

    A ConfigMap has no [spec]/[status] field; its [data] is treated as the spec
    (Anvil: [Spec = ConfigMapSpecView = Option<Map<StringView,StringView>>],
    [Status = EmptyStatusView = ()]). *)

type t = { metadata : Object_meta.t; data : string Smap.t option }
(** [ConfigMapView]: exactly [metadata] and [data] (no [binary_data]/[immutable];
    Anvil does not model those yet). *)

type spec = string Smap.t option
(** [ConfigMapSpecView]: the type of [data]. *)

type status = unit
(** [EmptyStatusView]. *)

(** The derived [ResourceView] surface (Anvil's macro output): [kind], [default],
    [metadata]/[spec]/[status] projections, [recombine], the spec/status codecs,
    [state_validation]/[transition_validation] (both constantly [true] for
    ConfigMap), and the derived [object_ref]/[marshal]/[unmarshal]. *)
include
  Resource_view.RESOURCE_VIEW
    with type t := t
     and type spec := spec
     and type status := status

val make : metadata:Object_meta.t -> data:string Smap.t option -> t
(** Struct constructor. *)

val with_metadata : Object_meta.t -> t -> t
(** Anvil [with_metadata]. *)

val with_data : string Smap.t -> t -> t
(** Anvil [with_data]: wraps a map in [Some]. *)

val data : t -> spec
(** The [data] field (equal to the [spec] projection). *)

val equal : t -> t -> bool
(** Structural equality (metadata and data). *)

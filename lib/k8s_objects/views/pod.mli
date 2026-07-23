(** Anvil source: kubernetes_api_objects/spec/pod.rs ([PodView] and its
    [implement_resource_view_trait!] instance).

    [PodView] is [{metadata; spec; status}] with a bare [metadata], an optional
    [PodSpecView] spec (in [Pod_spec]) and a unit [PodStatusView]
    ([EmptyStatusView]) status. *)

type t = {
  metadata : Object_meta.t;
  spec : Pod_spec.t option;
  status : unit option;
}
(** [PodView]: bare [metadata], optional [spec]/[status]. *)

type spec = Pod_spec.t option
(** The [Spec] associated type: [Option<PodSpecView>] (marshalled default [None]). *)

type status = unit option
(** The [Status] associated type: [Option<PodStatusView>] where
    [PodStatusView = EmptyStatusView = ()]. *)

(** The derived [ResourceView] surface (Anvil's macro output): [kind] ([Pod]),
    [default], [metadata]/[spec]/[status] projections, [recombine], the
    spec/status codecs, [state_validation] ([self.spec is Some]),
    [transition_validation] (constantly [true]), and the derived
    [object_ref]/[marshal]/[unmarshal]. *)
include
  Resource_view.RESOURCE_VIEW
    with type t := t
     and type spec := spec
     and type status := status

val make : metadata:Object_meta.t -> spec:spec -> status:status -> t
(** Struct constructor. *)

val with_metadata : Object_meta.t -> t -> t
(** Anvil [with_metadata]. *)

val with_spec : Pod_spec.t -> t -> t
(** Anvil [with_spec]: wraps a [PodSpecView] in [Some]. *)

val equal : t -> t -> bool
(** Structural equality (metadata, spec, status). *)

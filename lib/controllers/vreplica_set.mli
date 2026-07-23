(** Anvil source: controllers/vreplicaset_controller/trusted/spec_types.rs
    ([VReplicaSetView] + its [implement_resource_view_trait!] instance).

    Unlike [StatefulSetView], [VReplicaSetView.spec] is a {b bare}
    [VReplicaSetSpecView] (not an [Option]) and [status] is
    [Option<VReplicaSetStatusView>]; the selector inside the spec is a bare
    [LabelSelectorView]. Realised through {!Resource_view.Make}. *)

type vrs_spec = {
  replicas : int option;
  selector : Label_selector.t;
  template : Pod_template_spec.t option;
}
(** [VReplicaSetSpecView]: [replicas] optional; [selector] bare (not optional);
    [template] optional. *)

type vrs_status = { replicas : int }
(** [VReplicaSetStatusView]: a single required [replicas] count (default [0]). *)

type t = {
  metadata : Object_meta.t;
  spec : vrs_spec;
  status : vrs_status option;
}
(** [VReplicaSetView]: bare [metadata] and bare [spec]; optional [status]. *)

type spec = vrs_spec
(** The [Spec] associated type: a bare [VReplicaSetSpecView]. *)

type status = vrs_status option
(** The [Status] associated type: [Option<VReplicaSetStatusView>]. *)

val kind_name : string
(** The custom-resource kind string ["vreplicaset"]; [kind = Custom_resource
    kind_name]. *)

val vrs_spec_default : unit -> vrs_spec
(** [VReplicaSetSpecView::default]: [replicas] [None], [selector] its default,
    [template] [None]. *)

val vrs_spec_equal : vrs_spec -> vrs_spec -> bool
(** Structural equality on {!vrs_spec}. *)

val vrs_status_default : unit -> vrs_status
(** [VReplicaSetStatusView::default]: [replicas = 0]. *)

val vrs_status_equal : vrs_status -> vrs_status -> bool
(** Structural equality on {!vrs_status}. *)

(** The derived [ResourceView] surface (Anvil's macro output): [kind]
    ([Custom_resource "vreplicaset"]), [default], [metadata]/[spec]/[status]
    projections, [recombine], the spec/status codecs, [state_validation]
    (spec_types.rs:57), [transition_validation] ([true]), and the derived
    [object_ref]/[marshal]/[unmarshal]. *)
include
  Resource_view.RESOURCE_VIEW
    with type t := t
     and type spec := spec
     and type status := status

val controller_owner_ref : t -> Owner_reference.t option
(** Anvil [controller_owner_ref] (spec_types.rs:21). Anvil unwraps
    [metadata.name]/[metadata.uid] under well-formedness; lacking that invariant
    we return [None] when either is absent. The reference is a controller owner
    ([controller = Some true], [block_owner_deletion = Some true]). *)

val make : metadata:Object_meta.t -> spec:spec -> status:status -> t
(** Struct constructor. *)

val with_metadata : Object_meta.t -> t -> t
(** Anvil [with_metadata]. *)

val with_spec : spec -> t -> t
(** Anvil [with_spec]: sets the (bare) [VReplicaSetSpecView]. *)

val with_status : vrs_status -> t -> t
(** Anvil [with_status]: wraps a [VReplicaSetStatusView] in [Some]. *)

val spec_with_replicas : int -> vrs_spec -> vrs_spec
(** [VReplicaSetSpecView::set_replicas]. *)

val spec_without_replicas : vrs_spec -> vrs_spec
(** [VReplicaSetSpecView::unset_replicas]. *)

val spec_with_selector : Label_selector.t -> vrs_spec -> vrs_spec
(** [VReplicaSetSpecView::set_selector]. *)

val spec_with_template : Pod_template_spec.t -> vrs_spec -> vrs_spec
(** [VReplicaSetSpecView::set_template]. *)

val status_with_replicas : int -> vrs_status -> vrs_status
(** [VReplicaSetStatusView::set_replicas]. *)

val status_default : unit -> vrs_status
(** [VReplicaSetStatusView::default]: [replicas = 0]. *)

val equal : t -> t -> bool
(** Structural equality (metadata, spec, status). *)

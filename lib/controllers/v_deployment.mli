(** Anvil source: controllers/vdeployment_controller/trusted/spec_types.rs
    ([VDeploymentView] + its [implement_resource_view_trait!] instance).

    [VDeploymentView.spec] is a bare [VDeploymentSpecView]; [template] inside the
    spec is a {b bare} [PodTemplateSpecView] (unlike [VReplicaSetView] where it is
    optional); [status] is [Option<VDeploymentStatusView>] with
    [VDeploymentStatusView = EmptyStatusView], realised as [unit] (the
    {!Config_map} empty-status pattern). Realised through {!Resource_view.Make}. *)

type vd_spec = {
  replicas : int option;
  selector : Label_selector.t;
  template : Pod_template_spec.t;
  min_ready_seconds : int option;
  progress_deadline_seconds : int option;
  strategy : Deployment_strategy.t option;
  revision_history_limit : int option;
  paused : bool option;
}
(** [VDeploymentSpecView]: [replicas] optional; [selector] bare; [template] bare
    (required, not optional); the remaining k8s Deployment knobs optional. *)

type status = unit
(** [VDeploymentStatusView] = [EmptyStatusView] = [()]. *)

type t = {
  metadata : Object_meta.t;
  spec : vd_spec;
  status : status;
}
(** [VDeploymentView]: bare [metadata] and bare [spec]; empty [status]. *)

type spec = vd_spec
(** The [Spec] associated type. *)

val kind_name : string
(** The custom-resource kind string ["vdeployment"]. *)

val vd_spec_default : unit -> vd_spec
(** [VDeploymentSpecView::default]: [replicas]/optionals [None]; [selector] and
    [template] their defaults; [paused] [None]. *)

val vd_spec_equal : vd_spec -> vd_spec -> bool
(** Structural equality on {!vd_spec}. *)

(** The derived [ResourceView] surface (Anvil's macro output): [kind]
    ([Custom_resource "vdeployment"]), [default], [metadata]/[spec]/[status]
    projections, [recombine], the spec/status codecs, [state_validation]
    (spec_types.rs [_state_validation]), [transition_validation] ([true]), and the
    derived [object_ref]/[marshal]/[unmarshal]. *)
include
  Resource_view.RESOURCE_VIEW
    with type t := t
     and type spec := spec
     and type status := status

val controller_owner_ref : t -> Owner_reference.t option
(** Anvil [controller_owner_ref]. A controller owner ([controller = Some true],
    [block_owner_deletion = Some true]); [None] when [metadata.name] or
    [metadata.uid] is absent (lacking Anvil's well-formedness invariant). *)

val make : metadata:Object_meta.t -> spec:spec -> status:status -> t
(** Struct constructor. *)

val equal : t -> t -> bool
(** Structural equality (metadata, spec, status). *)

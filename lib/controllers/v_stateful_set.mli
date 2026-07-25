(** Anvil source: controllers/vstatefulset_controller/trusted/spec_types.rs
    ([VStatefulSetView] + its [implement_resource_view_trait!] instance) and
    trusted/exec_types.rs::state_validation.

    VStatefulSet is a {b single} controller managing Pods + PVCs directly. Its
    spec is field-for-field the built-in [StatefulSetSpecView], so the CR [spec]
    REUSES {!Stateful_set.ss_spec} and [status] REUSES {!Stateful_set.ss_status}
    [option] (one source of truth for the codecs). It differs from the built-in
    {!Stateful_set} only in [kind] ([Custom_resource "vstatefulset"]), a rich
    [state_validation], and the shared immutable-field [transition_validation].
    Realised through {!Resource_view.Make}. *)

type t = {
  metadata : Object_meta.t;
  spec : Stateful_set.ss_spec;
  status : Stateful_set.ss_status option;
}
(** [VStatefulSetView]: bare [metadata] and bare [spec]; optional [status]. *)

type spec = Stateful_set.ss_spec
(** The [Spec] associated type: the built-in [StatefulSetSpecView] (bare,
    required). *)

type status = Stateful_set.ss_status option
(** The [Status] associated type: [Option<StatefulSetStatusView>] (default
    [None]). *)

val kind_name : string
(** The custom-resource kind string ["vstatefulset"]. *)

(** The derived [ResourceView] surface (Anvil's macro output): [kind]
    ([Custom_resource "vstatefulset"]), [default], [metadata]/[spec]/[status]
    projections, [recombine], the spec/status codecs, [state_validation]
    (exec_types.rs [state_validation]), the meaningful [transition_validation]
    (immutable-field check), and the derived [object_ref]/[marshal]/[unmarshal]. *)
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

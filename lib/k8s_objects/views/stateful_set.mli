(** Anvil source: kubernetes_api_objects/spec/stateful_set.rs ([StatefulSetView]
    and its [implement_resource_view_trait!] instance).

    [StatefulSetView] is [{metadata; spec; status}] with a bare [metadata].
    Unlike ConfigMap/Pod, its [transition_validation] is meaningful: an
    immutable-field check across the old and new specs. *)

type ordinals = { start : int option }
(** [StatefulSetOrdinalsView]. *)

type rolling_update = { partition : int option; max_unavailable : int option }
(** [RollingUpdateStatefulSetStrategyView]. *)

type update_strategy = {
  type_ : string option;
  rolling_update : rolling_update option;
}
(** [StatefulSetUpdateStrategyView]; field [type_] is literally named [type_] in
    Anvil. *)

type retention_policy = {
  when_deleted : string option;
  when_scaled : string option;
}
(** [StatefulSetPersistentVolumeClaimRetentionPolicyView]. *)

type ss_spec = {
  min_ready_seconds : int option;
  ordinals : ordinals option;
  persistent_volume_claim_retention_policy : retention_policy option;
  pod_management_policy : string option;
  replicas : int option;
  revision_history_limit : int option;
  selector : Label_selector.t;
  service_name : string;
  template : Pod_template_spec.t;
  update_strategy : update_strategy option;
  volume_claim_templates : Persistent_volume_claim.t list option;
}
(** [StatefulSetSpecView]: eleven fields; [selector]/[service_name]/[template]
    are not optional. *)

type ss_status = { ready_replicas : int option }
(** [StatefulSetStatusView]: only [ready_replicas]. *)

type t = {
  metadata : Object_meta.t;
  spec : ss_spec option;
  status : ss_status option;
}
(** [StatefulSetView]: bare [metadata], optional [spec]/[status]. *)

type spec = ss_spec option
(** The [Spec] associated type: [Option<StatefulSetSpecView>] (default [None]). *)

type status = ss_status option
(** The [Status] associated type: [Option<StatefulSetStatusView>] (default
    [None]). *)

val ordinals_default : unit -> ordinals
(** [StatefulSetOrdinalsView::default]: [start] [None]. *)

val ordinals_equal : ordinals -> ordinals -> bool
(** Structural equality on {!ordinals}. *)

val rolling_update_default : unit -> rolling_update
(** [RollingUpdateStatefulSetStrategyView::default]: both [None]. *)

val rolling_update_equal : rolling_update -> rolling_update -> bool
(** Structural equality on {!rolling_update}. *)

val update_strategy_default : unit -> update_strategy
(** [StatefulSetUpdateStrategyView::default]: both [None]. *)

val update_strategy_equal : update_strategy -> update_strategy -> bool
(** Structural equality on {!update_strategy}. *)

val retention_policy_default : unit -> retention_policy
(** [StatefulSetPersistentVolumeClaimRetentionPolicyView::default]: both [None]. *)

val retention_policy_equal : retention_policy -> retention_policy -> bool
(** Structural equality on {!retention_policy}. *)

val ss_spec_default : unit -> ss_spec
(** [StatefulSetSpecView::default]: options [None]; [selector]/[template] their
    own defaults; [service_name] [""]. *)

val ss_spec_equal : ss_spec -> ss_spec -> bool
(** Full structural equality on {!ss_spec} (all eleven fields). *)

val ss_spec_immutable_eq : ss_spec -> ss_spec -> bool
(** stateful_set.rs:49 immutable-field check: [ss_spec_immutable_eq old new] is
    [true] iff [old] and [new] agree on every field EXCEPT [replicas], [template]
    and [persistent_volume_claim_retention_policy] (those three are mutable). The
    [transition_validation] rule. *)

val ss_spec_to_json : ss_spec -> Yojson.Safe.t
(** Marshal an {!ss_spec} (serde_json analogue); optionals dropped when [None]. *)

val ss_spec_of_json : Yojson.Safe.t -> ss_spec Res.t
(** Unmarshal an {!ss_spec}; {!Err.Missing_field} on an absent required field. *)

val ss_status_default : unit -> ss_status
(** [StatefulSetStatusView::default]: [ready_replicas] [None]. *)

val ss_status_equal : ss_status -> ss_status -> bool
(** Structural equality on {!ss_status}. *)

val ss_status_to_json : ss_status -> Yojson.Safe.t
(** Marshal an {!ss_status} (serde_json analogue); optional dropped when [None]. *)

val ss_status_of_json : Yojson.Safe.t -> ss_status Res.t
(** Unmarshal an {!ss_status}. *)

(** The derived [ResourceView] surface (Anvil's macro output): [kind]
    ([Stateful_set]), [default], [metadata]/[spec]/[status] projections,
    [recombine], the spec/status codecs, [state_validation] ([spec is Some] and
    [replicas >= 0] when present), the meaningful [transition_validation]
    (immutable-field check), and the derived [object_ref]/[marshal]/[unmarshal]. *)
include
  Resource_view.RESOURCE_VIEW
    with type t := t
     and type spec := spec
     and type status := status

val make : metadata:Object_meta.t -> spec:spec -> status:status -> t
(** Struct constructor. *)

val with_metadata : Object_meta.t -> t -> t
(** Anvil [with_metadata]. *)

val with_spec : ss_spec -> t -> t
(** Anvil [with_spec]: wraps a [StatefulSetSpecView] in [Some]. *)

val equal : t -> t -> bool
(** Structural equality (metadata, spec, status). *)

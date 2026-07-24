(** Anvil source: controllers/vdeployment_controller/trusted/spec_types.rs
    ([DeploymentStrategyView] + [RollingUpdateDeploymentView]).

    A plain field view (like {!Label_selector} / {!Pod_template_spec}), NOT a
    [Resource_view]. The VDeployment reconcile_core does not read the strategy;
    it is carried in the spec and constrained by [state_validation] for fidelity
    with Anvil's model. *)

type strategy_type =
  | Recreate
  | Rolling_update
      (** [DeploymentStrategyView.type_]: the two k8s strategy kinds. A finite
          sum; every match on it is exhaustive with no wildcard. JSON forms
          ["Recreate"] / ["RollingUpdate"]. *)

type rolling_update = {
  max_surge : int option;
  max_unavailable : int option;
}
(** [RollingUpdateDeploymentView]. Both bounds optional. *)

type t = {
  type_ : strategy_type option;
  rolling_update : rolling_update option;
}
(** [DeploymentStrategyView]: optional type and optional rolling-update block. *)

val default : unit -> t
(** [DeploymentStrategyView::default]: both fields [None]. *)

val strategy_type_equal : strategy_type -> strategy_type -> bool
(** Structural equality on {!strategy_type}. *)

val equal : t -> t -> bool
(** Structural equality on {!t}. *)

val to_json : t -> Yojson.Safe.t
(** Encode as [{ "type"?: "Recreate"|"RollingUpdate"; "rollingUpdate"?: {maxSurge?, maxUnavailable?} }]. *)

val of_json : Yojson.Safe.t -> t Res.t
(** Inverse of {!to_json}; an unknown [type] string is a {!Err.Decode_error}. *)

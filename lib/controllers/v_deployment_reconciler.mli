(** Anvil source: controllers/vdeployment_controller/model/reconciler.rs
    ([reconcile_core] + helpers) and trusted/step.rs (the step enum, view form),
    with [valid_owned_vrs] / [match_template_without_hash] from
    trusted/liveness_theorem.rs ported inline.

    The typed {!Reconciler.RECONCILER} for VDeployment: a controller that manages
    {!Vreplica_set} children the way {!Vreplica_set_reconciler} manages Pods. The
    rolling-update state machine scales the new VReplicaSet by +/-1 per reconcile
    (readiness-gated on the child's [status.replicas]) and scales old VReplicaSets
    to zero. Anvil's proof-discharged unwraps are replaced by explicit guards
    routed to the error step; on well-formed input the ported core takes exactly
    Anvil's branches. *)

type step =
  | Init
  | After_list_vrs
  | After_create_new_vrs
  | After_scale_new_vrs
  | After_ensure_new_vrs
  | After_scale_down_old_vrs
  | Done
  | Error
      (** Anvil [VDeploymentReconcileStepView] (step.rs), view form. All nullary;
          the scale-down cursor lives in {!s}, not in the step. *)

val step_equal : step -> step -> bool
(** Structural equality on {!step}. *)

val step_to_json : step -> Yojson.Safe.t
(** Encode a step as [{ "step": <tag> }] (no payload; every step is nullary). *)

val step_of_json : Yojson.Safe.t -> step Res.t
(** Inverse of {!step_to_json}; an unknown tag is a {!Err.Decode_error}. *)

type s = {
  reconcile_step : step;
  new_vrs : Vreplica_set.t option;
  old_vrs_list : Vreplica_set.t list;
  old_vrs_index : int;
}
(** [VDeploymentReconcileState]. [old_vrs_list] is written once at
    {!After_list_vrs} and read across the scale-down loop; [old_vrs_index] is the
    loop cursor ([>= 0] by construction), decremented in
    {!After_scale_down_old_vrs}. All fields round-trip through the pack codec. *)

val reconcile_init_state : unit -> s
(** [reconcile_init_state]: {!Init}, no new VReplicaSet, empty old list, cursor [0]. *)

val reconcile_core :
  cr:V_deployment.t ->
  resp:Io.void Io.response_view option ->
  state:s ->
  s * Io.void Io.request_view option
(** [reconcile_core]: the pure spec-level state machine (§2.3 of BUILD-SPEC-P9). *)

val reconcile_done : s -> bool
(** [reconcile_done]: step is {!Done}. *)

val reconcile_error : s -> bool
(** [reconcile_error]: step is {!Error}. *)

(** The typed void reconciler, ready for {!Erase.Void_erase}. *)
module R :
  Reconciler.RECONCILER
    with type k = V_deployment.t
     and type s = s
     and type ereq = Io.void
     and type eresp = Io.void

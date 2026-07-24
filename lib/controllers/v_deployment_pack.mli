(** The reconcile-state codec plus the driver-ready CONTROLLER pack for the
    VDeployment controller (model/reconciler.rs state; the kubernetes cluster's
    controller-map entry).

    Marshals {!V_deployment_reconciler.s} to {!Value.t} and erases the typed void
    reconciler through {!Erase.Void_erase}, producing a uniform
    {!Controller_pack.CONTROLLER} the P2 reconcile driver can run. The whole
    reconcile state (step, [new_vrs], [old_vrs_list], [old_vrs_index]) round-trips
    through {!marshal_state}/{!unmarshal_state}, since {!Erase.Void_erase} calls
    them on every transition; the child VReplicaSet objects marshal via
    {!Vreplica_set.marshal}. *)

val marshal_state : V_deployment_reconciler.s -> Value.t
(** Marshal the reconcile-state as
    [{ "step": <step>; "newVrs"?: <vrs>; "oldVrsList": <vrs list>; "oldVrsIndex": <int> }]. *)

val unmarshal_state : Value.t -> V_deployment_reconciler.s Res.t
(** Inverse of {!marshal_state}; fails ({!Res.t}) on a corrupt store. [oldVrsList]
    defaults to [[]] and [oldVrsIndex] to [0] when absent. *)

(** The state/CR codec supplied to {!Erase.Void_erase}. Its [id] is [1], distinct
    from {!Vreplica_set_pack}'s [0], so the two controllers occupy distinct keys in
    the cluster controller map. *)
module Codec :
  Erase.STATE_CODEC
    with type s = V_deployment_reconciler.s
     and type k = V_deployment.t

(** The VDeployment controller erased to a uniform [Value]-based pack; ready for
    [Controller.model_of_controller ~kind]. *)
module Controller :
  Controller_pack.CONTROLLER
    with type R.s = Value.t
     and type R.ereq = Value.t
     and type R.eresp = Value.t
     and type R.k = V_deployment.t

val packed : Controller_pack.packed
(** {!Controller} as a first-class-module pack for the cluster controller map. *)

val kind : Common.kind
(** The VDeployment kind ([Custom_resource "vdeployment"]). *)

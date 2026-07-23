(** Anvil source: the reconcile-state codec plus the driver-ready CONTROLLER pack
    for the VReplicaSet controller (model/reconciler.rs state; the kubernetes
    cluster's controller-map entry).

    Marshals {!Vreplica_set_reconciler.s} to {!Value.t} and erases the typed void
    reconciler through {!Erase.Void_erase}, producing a uniform
    {!Controller_pack.CONTROLLER} the P2 reconcile driver can run. *)

val marshal_state : Vreplica_set_reconciler.s -> Value.t
(** Marshal the reconcile-state onto the untyped store as
    [{ "step": <step>, "filteredPods"?: <pod list> }]. *)

val unmarshal_state : Value.t -> Vreplica_set_reconciler.s Res.t
(** Inverse of {!marshal_state}; fails ({!Res.t}) on a corrupt store. *)

(** The state/CR codec supplied to {!Erase.Void_erase}. *)
module Codec :
  Erase.STATE_CODEC
    with type s = Vreplica_set_reconciler.s
     and type k = Vreplica_set.t

(** The VReplicaSet controller erased to a uniform [Value]-based pack; ready for
    [Controller.model_of_controller ~kind]. *)
module Controller :
  Controller_pack.CONTROLLER
    with type R.s = Value.t
     and type R.ereq = Value.t
     and type R.eresp = Value.t
     and type R.k = Vreplica_set.t

val packed : Controller_pack.packed
(** {!Controller} as a first-class-module pack for the cluster controller map. *)

val kind : Common.kind
(** The VReplicaSet kind ([Custom_resource "vreplicaset"]). *)

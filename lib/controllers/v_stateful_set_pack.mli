(** Anvil source: the reconcile-state codec plus the driver-ready CONTROLLER pack
    for the VStatefulSet controller (model/reconciler.rs state; the kubernetes
    cluster's controller-map entry).

    Marshals {!V_stateful_set_reconciler.s} to {!Value.t} and erases the typed
    void reconciler through {!Erase.Void_erase}, producing a uniform
    {!Controller_pack.CONTROLLER} the P2 reconcile driver can run. *)

val marshal_state : V_stateful_set_reconciler.s -> Value.t
(** Marshal the reconcile-state onto the untyped store as
    [{ "step": <step>, "needed": <pod option list>, "neededIndex": <int>,
       "condemned": <pod list>, "condemnedIndex": <int>, "pvcs": <pvc list>,
       "pvcIndex": <int> }]. Every field is always present: {!Erase.Void_erase}
    round-trips the whole state each transition, so no cursor may be dropped. *)

val unmarshal_state : Value.t -> V_stateful_set_reconciler.s Res.t
(** Inverse of {!marshal_state}; fails ({!Res.t}) on a corrupt store. *)

(** The state/CR codec supplied to {!Erase.Void_erase}. *)
module Codec :
  Erase.STATE_CODEC
    with type s = V_stateful_set_reconciler.s
     and type k = V_stateful_set.t

(** The VStatefulSet controller erased to a uniform [Value]-based pack; ready for
    [Controller.model_of_controller ~kind]. *)
module Controller :
  Controller_pack.CONTROLLER
    with type R.s = Value.t
     and type R.ereq = Value.t
     and type R.eresp = Value.t
     and type R.k = V_stateful_set.t

val packed : Controller_pack.packed
(** {!Controller} as a first-class-module pack for the cluster controller map. *)

val kind : Common.kind
(** The VStatefulSet kind ([Custom_resource "vstatefulset"]). *)

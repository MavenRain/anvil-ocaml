(** Anvil source: kubernetes_cluster/spec/controller/state_machine.rs (the
    typed-reconciler -> [ReconcileModel] boundary).

    Anvil's [ReconcileModel] is fully [Value]-based; a {b typed} reconciler with
    [ereq = eresp = Io.void] reaches the driver only after its state is
    marshalled to [Value] and its void external I/O is erased to [Value]. This
    functor performs that erasure once, for every void controller. *)

(** The state/CR codec a void reconciler supplies so its typed local state can
    cross the untyped store boundary. [unmarshal_state] must be the exact
    inverse of [marshal_state] on every value the latter can emit (the driver
    stores only what [marshal_state] produced). *)
module type STATE_CODEC = sig
  (** The reconciler-local state (Anvil [S]). *)
  type s

  (** The typed custom-resource view (Anvil [K]). *)
  type k

  (** The controller's key in the cluster's [Map<int, _>]. *)
  val id : int

  (** Marshal the typed local state onto the untyped store. *)
  val marshal_state : s -> Value.t

  (** Recover the typed local state from the untyped store; MAY fail on a
      corrupt store, so returns {!Res.t}. Must invert {!marshal_state}. *)
  val unmarshal_state : Value.t -> s Res.t

  (** Recover the typed custom resource from an untyped stored object; MAY
      fail (malformed [Value] / wrong [kind]). *)
  val unmarshal_cr : Dynamic_object.t -> k Res.t
end

(** Erase a typed void reconciler [V] (one whose external I/O is [Io.void]) plus
    its codec [C] into a uniform [Value]-based {!Controller_pack.CONTROLLER}: the
    inner reconciler marshals state at every boundary and erases void external
    I/O ([K_*] passes through; an impossible external response maps to
    no-response, an unconstructible external request is refuted). Observationally
    identity on the reachable behaviours, since no external message is ever
    delivered to a void reconciler in a well-formed cluster. *)
module Void_erase
    (V : Reconciler.RECONCILER
           with type ereq = Io.void
            and type eresp = Io.void)
    (C : STATE_CODEC with type s = V.s and type k = V.k) :
  Controller_pack.CONTROLLER
    with type R.s = Value.t
     and type R.k = V.k
     and type R.ereq = Value.t
     and type R.eresp = Value.t

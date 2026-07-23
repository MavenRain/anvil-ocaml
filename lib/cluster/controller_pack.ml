(* Anvil source: kubernetes_cluster/spec/cluster.rs
   ([ControllerAndExternalState] / the [Map<int, _>] controller map).

   Anvil's cluster stores a heterogeneous [Map<int, ControllerAndExternalState>]:
   the controller-under-verification sits ALONGSIDE the builtin garbage
   collector, so at least two structurally different controllers coexist, and
   the untyped network carries marshalled [Dynamic_object] payloads
   ([spec:Value, status:Value]). A single-parameter functor [Make(R)] can host
   exactly one reconciler; pinning one [R.k] IS the erasure that Anvil's
   [Map<int,_>] avoids.

   So the cluster boundary models a controller as a FIRST-CLASS MODULE pack from
   the start (architecture §3.5, integrating finding 6): a [CONTROLLER] bundles
   a {!Reconciler.RECONCILER} with its cluster id and the two marshalling
   adapters that cross the typed/untyped boundary. The typing the functor buys
   lives inside [R]; at the map it is intentionally erased, and that erasure is
   documented here rather than hidden. *)

module type CONTROLLER = sig
  (** The typed reconciler this controller runs. *)
  module R : Reconciler.RECONCILER

  (** The controller's key in the cluster's [Map<int, _>]. *)
  val id : int

  (** Marshal the reconciler-local state onto the untyped wire/store. *)
  val marshal_state : R.s -> Value.t

  (** Recover the typed custom resource from an untyped stored object; MAY fail
      (a malformed [Value] or a wrong [kind]), so it returns {!Res.t} — the
      honest replacement for Anvil's proof-discharged unmarshal. *)
  val unmarshal_cr : Dynamic_object.t -> R.k Res.t
end

(** A controller erased to a uniform pack, so heterogeneous controllers (the
    controller-under-verification and the builtin GC) live in one
    [Imap.t]. *)
type packed = (module CONTROLLER)

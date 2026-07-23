(* Anvil source: reconciler/spec/reconciler.rs (the [Reconciler<S, K, EReq,
   EResp>] trait).

   The controller-under-verification, modelled as a small state machine the
   cluster's controller host drives. The four members are exactly Anvil's four
   trait methods. Anvil keeps S/K/EReq/EResp as trait type parameters (not
   associated types) only to connect spec and exec Reconcilers through view
   equalities; OCaml has no such obligation, so they become associated module
   types, which is the more natural encoding.

   This is a module TYPE, not an implementation: Phase 2 defines the contract
   and the controller host that consumes it; a concrete reconciler (e.g.
   vreplicaset) is Phase 3. *)

module type RECONCILER = sig
  (** The reconciler-local state threaded across reconcile steps. *)
  type s

  (** The typed custom-resource view the reconciler manages (Anvil [K :
      CustomResourceView]). *)
  type k

  (** The request payload to the external system, or {!Io.void} if none. *)
  type ereq

  (** The response payload from the external system, or {!Io.void} if none. *)
  type eresp

  (** Anvil [reconcile_init_state]: the local state a reconcile round starts
      from. *)
  val reconcile_init_state : unit -> s

  (** Anvil [reconcile_core]: given the custom resource [cr], the response to
      the previous request (if any), and the current local [state], produce the
      next local state and the next request to send (if any). Pure and total —
      the one function the assurance spine reasons about. *)
  val reconcile_core :
    cr:k ->
    resp:eresp Io.response_view option ->
    state:s ->
    s * ereq Io.request_view option

  (** Anvil [reconcile_done]: this reconcile round has finished successfully. *)
  val reconcile_done : s -> bool

  (** Anvil [reconcile_error]: this reconcile round ended in error (requeued
      sooner). *)
  val reconcile_error : s -> bool
end

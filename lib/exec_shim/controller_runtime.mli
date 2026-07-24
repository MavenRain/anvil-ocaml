(** P7 exec-shim: the reconcile driver (Anvil's [controller_runtime]).

    Anvil source: the executable reconcile manager that a live controller runs -
    watch for changes, dedup and requeue reconcile requests, and invoke the
    installed reconciler's [reconcile_core] against the api-server. Here that loop
    is generic over a {!Concurrency.CONCURRENCY} and a {!K8s_client.K8S_CLIENT};
    with the {!Concurrency.Direct} backend the entire driver is DETERMINISTIC.

    It drives the {b erased} {!Controller.reconcile_model} - which is exactly the
    P3 [reconcile_core] wrapped by {!Controller.model_of_controller}: a step
    function [transition : triggering_cr -> response_view option -> local_state ->
    (local_state', request_view option)]. The driver realises Anvil's
    [continue_reconcile] correlation: feed each produced {!Io.request_view} to the
    client, feed the {!Io.response_view} back, to a done/error fixpoint.

    {b Where P7 closes the P5/P6 vacuity honestly.} The P5 checker and the P6
    liveness skeleton could only reach the reconcile BODY vacuously under a finite
    [rv_ceiling] (Done was pruned). This driver runs the {e unbounded} executable
    reconcile: with no counter ceiling the api-server just stamps increasing
    resource versions, so [reconcile_with] actually reaches [Done] and the pods
    are actually created. The convergence the bounded checker could not witness is
    the concrete deliverable here. *)

type outcome =
  | Reconciled
      (** The reconcile reached [reconcile_done] (Anvil's stable-reconcile
          completion for this pass). *)
  | Errored
      (** The reconcile reached [reconcile_error] (the reconciler signalled a
          terminal error; the driver stops, as Anvil's [end_reconcile] does). *)
  | Incomplete of int
      (** The [fuel] budget was exhausted before done/error, carrying the fuel
          remaining ([0]). Deterministic fuel replaces an unbounded loop
          (loop-keyword ban); an [Incomplete] is the HONEST non-termination
          witness, not a silent success. The only value currently produced is
          [Incomplete 0] (emitted at fuel exhaustion); the [int] payload is
          reserved for a future partial-progress measure. *)

val outcome_equal : outcome -> outcome -> bool
(** Structural equality on {!outcome} (both [Incomplete] payloads compared),
    for tests and the requeue decision. *)

module Make
    (C : Concurrency.CONCURRENCY)
    (K : K8s_client.K8S_CLIENT with type 'a io = 'a C.t) : sig
  val reconcile_with :
    client:K.t ->
    model:Controller.reconcile_model ->
    cr:Dynamic_object.t ->
    fuel:int ->
    (outcome, Err.t) result C.t
  (** One reconcile pass to a fixpoint. Starting from [model.init ()], repeatedly:
      stop with [Reconciled]/[Errored] if the local state is done/error; else run
      [model.transition cr resp state]; if it produced a [K_request], send it via
      [K.request] and feed the [K_response] back next step; if [None], step again
      with no response. Bounded by [fuel] (each transition consumes one unit).

      The triggering [cr] is the captured snapshot, never re-read mid-pass -
      faithful to Anvil, where [reconcile_core] always receives the original cr.
      An {!Io.External_request} (constructible only for a non-void-erased model;
      never for the vreplicaset pack) is a transport the in-memory api-server has
      no subsystem for, and surfaces as a total [Err.t], not a crash. *)

  val run_controller :
    client:K.t ->
    model:Controller.reconcile_model ->
    queue:Common.object_ref list ->
    fuel:int ->
    max_rounds:int ->
    (outcome Object_ref_map.t, Err.t) result C.t
  (** The watch / dedup / requeue loop (Anvil's [controller_runtime] manager),
      over an explicit deterministic work [queue] - the in-memory stand-in for a
      live informer's change stream. Each round: dedup the pending keys by
      {!Common.object_ref}; for each, GET the cr from the client and
      [reconcile_with] it to a fixpoint; requeue any key whose outcome is
      [Errored] or [Incomplete] for the next round. Bounded by [max_rounds]
      (deterministic termination; a round that clears the queue stops early).
      Returns the terminal {!outcome} recorded per cr key. A GET that finds no
      object (the cr was deleted) drops that key from the work set, not an error.
      A key whose non-deleted GET keeps failing requeues every round; at
      [max_rounds] exhaustion the map reports that key's LAST-round outcome
      ([Errored]), which may be transient-and-unsettled rather than a settled
      terminal verdict - read a round-exhausted [Errored] as "not yet converged",
      not "permanently failed". *)
end

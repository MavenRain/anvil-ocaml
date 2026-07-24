(** A deterministic executable driver for {b several} reconcilers over {b one}
    shared api-server store, driven to a JOINT fixpoint.

    This is the P9 payoff harness: running the VDeployment and VReplicaSet
    controllers together, the VDeployment controller creates a VReplicaSet child
    and scales it +1 per reconcile (gated on the child's [status.replicas]), while
    the VReplicaSet controller creates a Pod per replica and writes that status
    back. Neither converges alone; interleaving them reaches the stable
    reconciliation the bounded assurance legs could only witness vacuously.

    Like {!Controller_runtime}, this models heterogeneous reconcilers as a plain
    list of {!Controller.reconcile_model}s with no non-interference guarantee
    (Anvil's compositional rely/guarantee story is proof-only and has no OCaml
    analogue) — the joint fixpoint is an operational witness, not a theorem. *)

module Make
    (C : Concurrency.CONCURRENCY)
    (K : K8s_client.K8S_CLIENT with type 'a io = 'a C.t) : sig
  type report = {
    rounds : int;
    converged : bool;
  }
  (** [rounds] = rounds executed; [converged] = a full round both performed no
      store write AND drove every reconciler to [Reconciled] (the joint fixpoint)
      within [max_rounds]. A fuel-starved or wedged round that merely lists
      without a write is NOT convergence — it does not satisfy the
      [Reconciled] conjunct. *)

  val run_to_fixpoint :
    client:K.t ->
    models:Controller.reconcile_model list ->
    namespace:string ->
    rv:(unit -> int) ->
    fuel:int ->
    max_rounds:int ->
    (report, Err.t) result C.t
  (** Each round, for each model in order: list the model's [kind] within
      [namespace] and {!Controller_runtime.reconcile_with} each returned custom
      resource to a per-CR fixpoint under [fuel]. [rv] reads the backend's
      resource-version write-clock (for {!Exec_api_server},
      [(Exec_api_server.state client).resource_version_counter]); a round whose
      [rv] is unchanged is the joint fixpoint. Bounded by [max_rounds]. *)
end

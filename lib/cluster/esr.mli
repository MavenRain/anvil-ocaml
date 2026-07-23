(** Anvil source: kubernetes_cluster/spec/esr.rs
    ([desired_state_is], [eventually_stable_reconciliation]).

    The eventually-stable-reconciliation goal, as {!Comp_cat.Temporal} formulas
    over the {!Cluster.cluster_state}. This is the property Anvil's ~55k lines of
    Verus proof establish; here it is only the {e statement}, evaluated by the
    assurance spine (Phase 5 lasso model checking), never proved. A functor over
    a P1 {!Resource_view.RESOURCE_VIEW} because [desired_state_is] must unmarshal
    the stored object as the custom resource's type. *)

module Make (R : Resource_view.RESOURCE_VIEW) : sig
  (** Anvil [desired_state_is(cr)]: the cr's key exists in etcd with the same
      uid and spec as [cr] and no deletion timestamp (and [cr] itself names a
      namespaced object). A [state_pred] over the cluster state. *)
  val desired_state_is :
    R.t -> Cluster.cluster_state Comp_cat.Temporal.state_pred

  (** Anvil [eventually_stable_reconciliation_per_cr(cr, current_state_matches)]:
      [always(desired_state_is cr) ~> always(current_state_matches cr)]. *)
  val eventually_stable_reconciliation_per_cr :
    cr:R.t ->
    current_state_matches:(R.t -> Cluster.cluster_state Comp_cat.Temporal.state_pred) ->
    Cluster.cluster_state Comp_cat.Temporal.t

  (** Anvil [eventually_stable_reconciliation]: [tla_forall] of the per-cr goal.
      Anvil quantifies over all cr of the type; a computable rendering quantifies
      over an explicit finite [crs] (the conjunction of the instances), which is
      the bounded ESR the model checker can evaluate. *)
  val eventually_stable_reconciliation :
    crs:R.t list ->
    current_state_matches:(R.t -> Cluster.cluster_state Comp_cat.Temporal.state_pred) ->
    Cluster.cluster_state Comp_cat.Temporal.t
end

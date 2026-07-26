(** BUILD-SPEC-P11 §4: the VStatefulSet safety invariants + liveness goal, the
    VSTS sibling of the VReplicaSet-hardwired {!Invariants}. Every [holds] /
    [interesting] is total, pure and exception-free; every [Common.kind] /
    [api_request] match is exhaustive (no wildcard on a finite sum).

    Reuses {!Invariants.invariant}, {!Invariants.conjunction},
    {!Invariants.first_violated} and the shared cluster-level inv1-6 exposed via
    {!Invariants.cluster_structural} (GAP-2), so both controllers assert the same
    etcd/runtime-safety core from ONE source. *)

val always : cr:V_stateful_set.t -> controller_id:int -> Invariants.invariant list
(** The [always] (per-step inductive) safety invariants for the VSTS controller:
    {!Invariants.cluster_structural}[ ~controller_id] (the shared inv1-6) followed
    by the three VSTS invariants -

    - [vsts_reconcile_request_only_interferes_with_itself]: every in-flight message
      from [Controller(controller_id, vsts_ref)] carries an [api_request] in the
      VSTS repertoire, well-formed for the vsts. The repertoire is the FULL set the
      {!V_stateful_set_reconciler} emits ([List_request] pods, [Get_request] pvc,
      [Create_request] pod|pvc, [Get_then_update_request] pod,
      [Get_then_delete_request] pod), widening VRS inv9 (which already permitted
      [List_request]); every other arm ([Delete] / [Update] / [Update_status] /
      [Get_then_update_status] - the reconcile writes no status) is rejected.
    - [owned_pods_have_wellformed_ordinal_identity]: every etcd Pod owned by the
      vsts (owner-ref) has a [pod_name parent ord] name with
      [get_ordinal parent name = Some ord], [ord >= 0] and
      [ordinal_label = string_of_int ord].
    - [owned_pvcs_bound_to_vsts]: every etcd PVC owned by the vsts (owner-ref) is in
      the vsts namespace with a [pvc_name]-shaped name. HONEST-VACUITY: the faithful
      {!V_stateful_set_reconciler.make_pvc} stamps NO owner-ref on PVCs (real-k8s
      StatefulSet PVC retention), so the owned-PVC set is EMPTY in every reachable
      state and this invariant holds vacuously by construction (its [interesting]
      never fires). DISCLOSED, pinned with a measured 0-count witness; not tuned to
      fake a positive.

    Asserted after every step from [Scenario.vsts_seed ~fair:false] explored over
    [Scenario.vsts_cluster]. *)

val liveness_goal : cr:V_stateful_set.t -> Invariants.invariant
(** The ESR [leads_to] TARGET [current_state_matches] for the VSTS (NOT in
    {!always}: a transient-false goal, checked only at a settled state). *)

val current_state_matches : V_stateful_set.t -> Cluster.cluster_state -> bool
(** The VSTS converged shape (§4, the rewrite of the VRS replica-count goal for
    ordinal identity). True iff, with [n = Option.value ~default:1
    (V_stateful_set.spec cr).replicas]:
    (a) the CR's ref is present in [Cluster.resources s];
    (b) each ordinal [0..n-1] is present as an owned Pod named [pod_name parent ord],
        carrying [ordinal_label]/[pod_name_label] and the vsts controller owner-ref,
        with [pod_spec_matches cr] (template match modulo injected
        volumes/hostname/subdomain);
    (c) EXACTLY [n] owned Pods (no owned Pod survives at ordinal [>= n]).
    There is NO status conjunct: the VSTS [reconcile_core] writes no status, so
    gating on one would make the goal vacuous by construction (§4 / §10.4). *)

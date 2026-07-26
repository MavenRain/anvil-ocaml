(** The load-bearing Anvil safety invariants, ported as pure boolean
    {!Cluster.cluster_state} predicates for the P4 property harness (Leg 1 of the
    assurance spine; architecture §4).

    Each Verus [StatePred<ClusterState>] in Anvil's [proof/] tree becomes one
    {!invariant} here, but the two proof regimes are kept in SEPARATE buckets and
    must NOT be asserted the same way:

    - {!always}: proved inductive from init by a [lemma_always_*]
      ([inv s && next s s' ==> inv s']), so it holds after every step of any
      trace. The harness discharges the two-state obligation OPERATIONALLY: start
      at a valid {!Scenario.seed}, take only {!Cluster.enabled_successors} steps,
      and assert the {!conjunction} of {!always} after every step.

    - {!eventually_always}: proved only as [lemma_eventually_always_*] /
      [leads_to_always] under crash + req_drop + pod_monkey disabled and weak
      fairness, so it holds only on the fair SUFFIX (at quiescence). It must NOT
      be asserted after every step of an unfair ([~fair:false]) trace; assert it
      only at quiescence on [~fair:true] traces.

    Nothing is proved; the
    downgrade from Anvil's machine-checked total correctness is deliberate and is
    stated in the architecture (§4): this is falsification by sampling.

    Source citations index the shallow clone [<scratchpad>/anvil-ref]; the
    per-invariant statements are in [<scratchpad>/p4_anvil_digest.md]. *)

type invariant = {
  name : string;  (** the Anvil spec-fn name, e.g. ["etcd_objects_have_unique_uids"]. *)
  source : string;  (** ["<file>:<line>"] in the Anvil clone. *)
  holds : Cluster.cluster_state -> bool;
      (** The [StatePred], closed over the scenario's cr and controller id. Pure;
          total; no exception. *)
  interesting : Cluster.cluster_state -> bool;
      (** The invariant's non-trivial precondition (architecture finding 14): the
          witness that this state actually EXERCISES the invariant rather than
          satisfying it vacuously (e.g. "an in-flight foreign api request exists",
          "≥2 objects are in etcd", "an owned pod exists", "a reconcile for the vrs
          is ongoing"). [t_p4_enumerator] asserts every invariant's [interesting] is
          reached under {!Bound.default}; an invariant whose [interesting] never
          fires is checked vacuously and the bounds must be widened. *)
}

val cluster_structural : controller_id:int -> invariant list
(** The shared cluster-level etcd/runtime-safety invariants inv1-6 (unique uids,
    weakly-well-formed + uid/rv monotone, <= 1 controller owner, scheduled/triggering
    CR uid < counter, unique reconcile ids). Independent of any CR — sourced from
    Anvil's [kubernetes_cluster] proofs, not [vreplicaset_controller]. Exposed so
    both {!always} and the VStatefulSet leg ([Vsts_invariants.always]) reuse ONE
    source. [always ~cr ~controller_id] is observationally
    [cluster_structural ~controller_id @ [inv9; inv15; inv16]] (unchanged result;
    the shared inv1-6 bodies are the exact ones {!always} asserts). *)

val always : cr:Vreplica_set.t -> controller_id:int -> invariant list
(** The nine ALWAYS-invariants: #1 [etcd_objects_have_unique_uids],
    #2 [each_object_in_etcd_is_weakly_well_formed],
    #3 [each_object_in_etcd_has_at_most_one_controller_owner],
    #4 [scheduled_cr_has_lower_uid_than_uid_counter],
    #5 [triggering_cr_has_lower_uid_than_uid_counter],
    #6 [every_ongoing_reconcile_has_unique_id],
    #9 [vrs_reconcile_request_only_interferes_with_itself],
    #15 [filtered_pods_invariant_matrix] and
    #16 [local_pods_are_bound_to_vrs_with_key]. Each is proved inductive from init
    by a [lemma_always_*], hence holds after every step and is safe to assert
    after each step from a valid seed. Several are inductive only in conjunction
    (Anvil's [stronger_next] bundles), so callers check the whole list via
    {!conjunction}, never a single predicate in isolation. *)

val eventually_always : cr:Vreplica_set.t -> controller_id:int -> invariant list
(** The six EVENTUALLY_ALWAYS-invariants:
    #7 [garbage_collector_does_not_delete_vrs_pods],
    #8 [no_other_pending_request_interferes_with_vrs_reconcile],
    #10 [every_msg_from_key_is_pending_req_msg_of],
    #12 [inductive_current_state_matches],
    #13 [vrs_in_schedule/reconcile_has_spec_and_uid_as] and
    #14 [no_pending_mutation_request_not_from_controller_on_pods]. These are NOT
    proved inductive from init. Anvil proves them as [lemma_eventually_always_*] /
    [leads_to_always] under crash + req_drop + pod_monkey disabled and weak
    fairness, so each holds only on the fair SUFFIX. Assert them ONLY at
    quiescence on [~fair:true] traces, NEVER after every step of a [~fair:false]
    trace. The three load-bearing lemmas:
    [lemma_eventually_always_no_other_pending_request_interferes_with_reconcile]
    (helper_invariants/proof.rs:24) proves #8 (requires crash + req_drop +
    pod_monkey disabled + fair);
    [lemma_true_leads_to_always_every_msg_from_key_is_pending_req_msg_of]
    (controller_runtime_safety.rs:927) proves #10 (requires crash disabled);
    [lemma_eventually_always_no_pending_mutation_request_not_from_controller_on_pods]
    (helper_invariants/proof.rs:653) proves #14 (requires crash disabled).

    #12 [inductive_current_state_matches]: the OCaml rendering is now the FAITHFUL
    literal conjunctive form. Anvil's literal
    (vreplicaset_controller/proof/predicate.rs:502) is
    [current_state_matches(vrs) AND (ongoing ==> step-shape)] and only ever
    appears as the [post] of a [leads_to(always(post))] inside the ESR-stability
    lemma (liveness/resource_match.rs ~2874/2880). The port asserts the top-level
    [current_state_matches] conjunct (the same predicate #11/{!current_state_matches}
    use, so the two agree) and conjoins the step-shape whenever an ongoing reconcile
    exists — no longer the vacuous [current_state_matches ==> step-shape]. Because
    the [current_state_matches] conjunct is false off-goal, #12 stays in the
    {!eventually_always} bucket and is asserted only at quiescence on [~fair:true]
    traces. *)

val all : cr:Vreplica_set.t -> controller_id:int -> invariant list
(** [always @ eventually_always]: the full fifteen (digest #1-#10 and #12-#16).
    Provided for the enumerator's non-vacuity sweep ([t_p4_enumerator] asserts
    every invariant's [interesting] is reachable under {!Bound.default}). Do NOT
    assert this whole list after every step: its {!eventually_always} members hold
    only on the fair suffix. Excludes #11 {!liveness_goal} (a [leads_to] target,
    not an invariant). *)

val liveness_goal : cr:Vreplica_set.t -> invariant
(** Digest #11 [current_state_matches] (vreplicaset_controller/trusted/
    liveness_theorem.rs:21): the number of matching pods equals the desired replica
    count and the etcd status agrees. This is the ESR [leads_to] GOAL, FALSE on
    transient states by design; check [holds] ONLY where {!Scenario.is_quiescent},
    and treat a pass as a bounded sample, never as a liveness proof. *)

val conjunction : invariant list -> Cluster.cluster_state -> bool
(** [List.for_all (fun i -> i.holds s) is]. Over {!always} it is the safety check
    the harness asserts after each step; over {!eventually_always} it is the check
    asserted only at quiescence on a [~fair:true] trace. *)

val first_violated :
  invariant list -> Cluster.cluster_state -> invariant option
(** The first invariant whose [holds] is [false] at [s], for QCheck counterexample
    reporting ([None] iff the {!conjunction} holds). *)

(** [Vsts_liveness]: the vstatefulset ESR liveness skeleton (Anvil
    [controllers/vstatefulset_controller/proof/liveness]), the P11 sibling of
    {!Vrs_liveness}, ported as a {!Comp_cat.Rule} entailment derivation whose SHAPE
    regression-locks Anvil's proof structure and whose every per-edge operational
    side-condition is discharged by the P5 bounded model checker ({!Discharge}).
    Compiled documentation, NOT machine-checked. Each [leads_to] edge is a
    {!Comp_cat.Rule.wf1} whose [closure]/[drives] obligations are CHECKED over the
    bounded reachable graph; the wf1 omega-induction (fair progress ⇒ [~>]) is
    TRUSTED-on-stream. A clean derivation verifies the bounded system and transfers
    no part of Anvil's Verus theorem.

    {b Honest scope gaps} (documented, not defects — mirror BUILD-SPEC-P6 §4.7):

    1. Consequent [always] dropped. The derived goal is
       [always(desired_state_is) ~> current_state_matches], not
       [~> always(current_state_matches)]: the kernel has no [leads_to_always], so
       the outer-[always] stability step is trusted (cross-checked non-vacuously by
       the settled ESR gate {!Cluster_check.check_esr_settled_vsts}, [gate_states =
       Some 1]).
    2. Antecedent [always] via a trusted tautology, alongside fairness and
       [[]next] ([assume]d, not finite-graph facts).
    3. [wf1]'s internal omega-induction is trusted-on-stream. Only
       [closure]/[drives]/[[]j] are model-checked.
    4. Bounded. Everything holds only up to {!settling_bound}; transfers nothing
       from Anvil's Verus theorem.
    5. Front discharged as reachability, not a single-step drive. The scheduling
       step [always(desired) ~> at Init] is [assume]d, gated by a bounded
       {!Discharge.reaches_holds}, because in the cyclic reconcile model it is
       genuinely multi-step (a [wf1] there correctly fails to discharge — the P6
       self-catch). Weaker evidence than the body edges' [closure]+[drives].
    6. First-pass slice + bound-artifact discipline (BUILD-SPEC-P11 §7.3). The
       body chain [Init -> After_list_pod -> Create_needed -> After_create_needed
       -> Delete_outdated -> Done] (five edges — the MEASURED trajectory, see
       {!edges}) is faithful to the FIRST reconcile pass from a fresh cluster
       ([vct:false], desired = 1, no stale pods): VSTS reaches [Done] in ONE pass
       (the [Delete_outdated] scan finds no outdated pod and steps straight to
       [Done]), so [reconcile_ceiling = 1] isolates that pass. Any
       [Refuted] transferring evidence is interpretable ONLY where
       [max_uid_seen]/[max_rv_seen] stay STRICTLY below their ceilings; at
       {!settling_bound} they do (MEASURED [3 < 4], [2 < 5] — pinned in
       [t_p11_vsts_esr]), so a starved "settled" state cannot masquerade as a real
       non-match. Steady-state re-reconcile and the multi-round rolling update are
       witnessed OPERATIONALLY by the P7/P10 executable spine ([vct:true]), NOT
       claimed here as a bounded proof. *)

val controller_id : int
(** The scenario controller id ({!Scenario.controller_id}). *)

val cr_key : Common.object_ref
(** The scenario vsts key ({!Scenario.vsts_ref}). *)

val settling_bound : Bound.t
(** The finite fair {!Bound.t} at which the [desired = 1], [vct:false] reachable
    graph closes so every edge discharge is decisive — the §7.2 VSTS settling
    bound, RECONCILE-bounded ([reconcile_ceiling = 1] isolates the first pass so
    [Done] and the match are reached without an rv squeeze). The default [bound]
    of every function below. Identical field set to the bound
    {!Cluster_check.check_esr_settled_vsts} is tested at, so the liveness
    milestones and the settled ESR gate range over the SAME graph. *)

(** {2 Named milestone formulas}

    All are hash-consed [lift_state]s, so the middle [q] of one edge's [p ~> q] is
    {!Comp_cat.Temporal.equal} to the next edge's [q ~> r] antecedent — exactly
    what {!Comp_cat.Rule.leads_to_trans} matches on. *)

val f_desired_state_is :
  desired:int -> Cluster.cluster_state Comp_cat.Temporal.t
(** [lift_state (Esr.Make(V_stateful_set).desired_state_is (Scenario.vsts
    ~desired ()))] — the ESR antecedent: the cr present in etcd with matching
    uid/spec. *)

val f_scheduled : Cluster.cluster_state Comp_cat.Temporal.t
(** [lift_state (Vsts_step_view.scheduled_only ...)] — a reconcile is queued, not
    started. *)

val f_at :
  V_stateful_set_reconciler.step -> Cluster.cluster_state Comp_cat.Temporal.t
(** [lift_state (Vsts_step_view.at_step ... step)] — the reconcile is at [step]. *)

val f_at_creating : Cluster.cluster_state Comp_cat.Temporal.t
(** [lift_state (Vsts_step_view.at_phase ... is_create_phase)] — the index-erased
    create-pod milestone ("at some [Create_needed | After_create_needed]"). *)

val f_current_state_matches :
  desired:int -> Cluster.cluster_state Comp_cat.Temporal.t
(** [lift_state (Vsts_invariants.current_state_matches (Scenario.vsts ~desired
    ()))] — the ESR target (the ordinal-stable converged shape). *)

val spec : desired:int -> Cluster.cluster_state Comp_cat.Temporal.t
(** The ambient assumption every {!Comp_cat.Rule} combinator in the derivation
    shares: the conjunction of the init condition, [always [next]], and the
    controller fairness leaf — a stable hash-consed value reused by every
    {!Comp_cat.Rule.assume}. Its conjuncts are TRUSTED axioms of the fair scenario
    (disruptors off), NOT re-checked. *)

(** {2 The discharged skeleton} *)

type edge = {
  name : string;
      (** The Anvil lemma this edge ports, e.g. ["lemma_init_to_after_list_pod"]. *)
  fact : Cluster.cluster_state Comp_cat.Rule.fact;
      (** The [spec |= pre ~> post] entailment token the edge established. *)
  report : Discharge.edge_report;
      (** The P5 evidence that discharged the edge's operational obligation(s). *)
}
(** One discharged [leads_to] edge of the skeleton: provenance, entailment fact,
    and the bounded-model-checking evidence behind it. *)

val edges : ?bound:Bound.t -> desired:int -> edge list Comp_cat.Res.t
(** The ordered reconcile-BODY edges — the MEASURED [desired = 1], [vct:false],
    fresh-cluster trajectory [at Init ~> at After_list_pod ~> at Create_needed ~>
    at After_create_needed ~> at Delete_outdated ~> at Done] — each a
    {!Comp_cat.Rule.wf1} whose [closure]/[drives] obligations are discharged by
    {!Discharge} over the bounded graph seeded at [Scenario.vsts_seed ~desired
    ~fair:true]. FIVE single-step edges, correcting the BUILD-SPEC §7.1 sketch by
    measurement (the "MEASURE, do not tune" discipline): [Create_needed] /
    [After_create_needed] are two SEQUENTIAL controller steps (a single-step
    [wf1.drives] cannot span them as one create-phase PRE), and a fresh create
    still traverses the [Delete_outdated] scan (which finds nothing and steps to
    [Done], never reaching [After_delete_outdated]). VSTS [reconcile_core] writes
    NO status, so there is still no status-update edge (unlike VRS). [Error] as
    soon as any edge's obligation is not [Ok true]. [bound] defaults to
    {!settling_bound}. *)

val esr_derivation :
  ?bound:Bound.t ->
  desired:int ->
  Cluster.cluster_state Comp_cat.Rule.fact Comp_cat.Res.t
(** The assembled top entailment [spec |= always(desired_state_is) ~>
    current_state_matches], chained by {!Comp_cat.Rule.leads_to_trans} from three
    parts: a FRONT [always desired ~> at Init] ([assume]d, gated by a bounded
    {!Discharge.reaches_holds} — the cyclic scheduling step is multi-step, not a
    single-step [wf1] drive, the P6 self-catch); the BODY {!edges} (step-to-step
    [wf1]s); and the TAIL [at Done ~> current_state_matches]
    ({!Comp_cat.Rule.leads_to_weaken} over a {!Discharge.invariant_holds} of
    [Done => current_state_matches]). [Error] if any part failed to discharge or a
    middle did not match by {!Comp_cat.Temporal.equal} — the regression-lock: a
    proof-shape regression is [Comp_cat.Err.Ill_formed], never a wrong [Ok]. *)

val esr_statement_core :
  desired:int -> Cluster.cluster_state Comp_cat.Temporal.t
(** The exact formula {!esr_derivation}'s goal must equal:
    [Comp_cat.Temporal.leads_to (Comp_cat.Temporal.always (f_desired_state_is
    ~desired)) (f_current_state_matches ~desired)] — the de-stabilized ESR core
    (see the module's honest scope gap #1). Built independently of the derivation
    so the equality is a genuine cross-lock. *)

val matches_esr_statement :
  ?bound:Bound.t -> desired:int -> bool Comp_cat.Res.t
(** [Comp_cat.Res.ok true] iff {!esr_derivation}'s {!Comp_cat.Rule.goal_of} is
    {!Comp_cat.Temporal.equal} to {!esr_statement_core} — the P11 headline: the
    machine-assembled, per-edge-discharged derivation establishes exactly the
    intended ESR core statement, and its shape is locked to Anvil's. *)

val tail_matches_is_stable :
  ?bound:Bound.t -> desired:int -> Discharge.edge_report
(** The bounded evidence for the one trusted lifting the kernel cannot chain (the
    outer [always]). Three composed {!Discharge} checks over the fair
    no-disruptor reachable graph: [Done] is REACHABLE ({!Discharge.reaches_holds}),
    a MATCHING [Done] is reachable, and the stability invariant
    [current_state_matches s || not (at_done s)] holds at every reachable state
    ({!Discharge.invariant_holds}) — the decidable content of Anvil's
    [leads_to_always] step. In the combined report, [holds] requires all three
    verdicts AND both reaches' [frontier_emptied] (a truncated reach never yields a
    green tail); [witnesses] is the [Done]-and-matches state count;
    [states_checked] / [frontier_emptied] are the invariant leg's. Recorded, NOT
    folded into {!esr_derivation}. HONEST LIMIT: witnesses the settled match on the
    bounded FIRST-pass slice only ([reconcile_ceiling = 1]); if [Done] is pruned at
    every feasible bound the report is honestly vacuous ([witnesses = 0]), the
    P6-tail precedent — disclosed by the measured milestone-count witness in
    [t_p11_vsts_liveness], not tuned away. *)

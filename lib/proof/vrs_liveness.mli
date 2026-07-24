(** [Vrs_liveness]: the vreplicaset eventually-stable-reconciliation (ESR)
    liveness skeleton (Anvil
    [controllers/vreplicaset_controller/proof/liveness]), ported as a
    {!Comp_cat.Rule} entailment derivation whose SHAPE regression-locks Anvil's
    proof structure and whose every per-edge operational side-condition is
    discharged by the P5 bounded model checker ({!Discharge}). This is the P6
    "typed entailment DSL" (architecture §5 P6 row): compiled documentation, NOT
    machine-checked. Each [leads_to] edge is a {!Comp_cat.Rule.wf1} whose
    [closure]/[drives] obligations are CHECKED over the bounded reachable graph;
    the wf1 omega-induction (fair progress ⇒ [~>]) is TRUSTED-on-stream and only
    ever cross-checked on lassos (arch §2.6, §4). A clean derivation verifies the
    bounded system and transfers no part of Anvil's Verus theorem.

    {b Honest scope gap} (documented, not a defect). Anvil's top goal is
    [always(desired_state_is) ~> always(current_state_matches)]
    ({!Esr.Make.eventually_stable_reconciliation_per_cr}). The {!Comp_cat.Rule}
    kernel carries no [leads_to_always] / stability combinator, so the derived
    goal is the DE-STABILIZED core [always(desired_state_is) ~>
    current_state_matches] (a shape-level [leads_to]); the outer-[always]
    stability step is the one trusted lifting the skeleton names but does not
    chain, and it is cross-checked — non-vacuously since P8, see the
    tail-witness note below — by {!tail_matches_is_stable}.

    {b First-pass scope} (second honest limit). The linear body chain [Init ->
    After_list_pods -> at_creating -> After_update_vrs_status -> Done] is faithful
    to the FIRST scale-up reconcile pass from an empty cluster only. In a
    steady-state cycle the pod created in pass 1 persists, so [After_list_pods]
    sees [diff = 0] and skips the create phase — i.e. edge e2's [closure] is
    genuinely FALSE beyond the first pass. {!tightened_bound}
    ([reconcile_ceiling = 1], BUILD-SPEC-P8 §1) is the ceiling that ISOLATES
    that first pass — the create-skip is a second-INVOCATION phenomenon, so
    bounding invocations excludes it without capping the resource version; P6
    verifies first-pass reconcile liveness on the fully-explored bounded slice,
    and claims nothing about steady-state cycles (see the [tightened_bound]
    source comment).

    {b Tail witnesses at the reconcile-bounded feasible bound} (third honest
    limit, MEASURED — BUILD-SPEC-P8 §3.3; before P8 this note recorded honest
    VACUITY, [at Done = 0], mirroring P5's ESR quiescence gate [gate_states =
    Some 0]). At {!tightened_bound} ([reconcile_ceiling = 1] admitting
    [rv_ceiling = 4]) the 23-state reachable graph (frontier emptied) reaches
    EVERY milestone (measured counts: [at Init = 2], [After_list_pods = 4],
    [After_create_pod _ = 4], [After_update_vrs_status = 5], [at Done = 3],
    [current_state_matches = 9]), so the FRONT, all body edges e1-e4 AND the
    tail have POSITIVE witnesses — the single pass reaches [Done], every
    reachable [Done] state satisfies the match (3 matching-[Done] states), and
    e4's [drives] fires on witnessed transitions. Net: the derivation's SHAPE
    proves [always(desired) ~> current_state_matches] (the regression-lock; its
    goal is {!Comp_cat.Temporal.equal} to {!esr_statement_core}) and witnessed
    runs DO reach the match — but only on the bounded first-pass slice: one
    reconcile invocation, [desired = 1], decisive relative to these ceilings
    only (arch §4). Steady-state re-reconcile stability remains outside this
    graph (P7's unbounded executable spine witnesses it operationally). *)

val controller_id : int
(** The scenario controller id ({!Scenario.controller_id}). *)

val cr_key : Common.object_ref
(** The scenario vrs key ({!Scenario.vrs_ref}). *)

val tightened_bound : Bound.t
(** The finite fair {!Bound.t} at which the [desired = 1] reachable graph closes
    (frontier empties) so every edge discharge is decisive — mirrors the P5
    decisive-ESR bound (small [uid_ceiling] / [rv_ceiling] / [max_in_flight] /
    [max_objects_per_kind] / [max_controllers]). RECONCILE-bounded since P8
    ([reconcile_ceiling = 1], BUILD-SPEC-P8 §3.3): the invocation ceiling
    isolates the first pass, letting [rv_ceiling] rise to 4 so [Done] and the
    match are reached (see the module's tail-witness note). The default [bound]
    of every function below. *)

(** {2 Named milestone formulas}

    All are hash-consed [lift_state]s, so the middle [q] of one edge's [p ~> q] is
    {!Comp_cat.Temporal.equal} to the next edge's [q ~> r] antecedent — which is
    exactly what {!Comp_cat.Rule.leads_to_trans} matches on. *)

val f_desired_state_is :
  desired:int -> Cluster.cluster_state Comp_cat.Temporal.t
(** [lift_state (Esr.Make(Vreplica_set).desired_state_is (Scenario.vrs ~desired))]
    — the ESR antecedent: the cr present in etcd with matching uid/spec. *)

val f_scheduled : Cluster.cluster_state Comp_cat.Temporal.t
(** [lift_state (Step_view.scheduled_only ...)] — a reconcile is queued, not
    started. *)

val f_at :
  Vreplica_set_reconciler.step -> Cluster.cluster_state Comp_cat.Temporal.t
(** [lift_state (Step_view.at_step ... step)] — the reconcile is at [step]. *)

val f_at_creating : Cluster.cluster_state Comp_cat.Temporal.t
(** [lift_state (Step_view.at_phase ... is_after_create_pod)] — the index-erased
    pod-adjust milestone ("at some [After_create_pod _]"). *)

val f_current_state_matches :
  desired:int -> Cluster.cluster_state Comp_cat.Temporal.t
(** [lift_state (Invariants.liveness_goal ~cr).holds] — the ESR target (#11
    [current_state_matches]). *)

val spec : desired:int -> Cluster.cluster_state Comp_cat.Temporal.t
(** The ambient assumption every {!Comp_cat.Rule} combinator in the derivation
    shares: the conjunction of the init condition, [always [next]], and the
    weak-fairness of the controller actions — assembled from {!Comp_cat.Temporal}
    constructors so it is a stable hash-consed value reused by every
    {!Comp_cat.Rule.assume}. Its conjuncts are TRUSTED axioms of the fair scenario
    (disruptors off), exactly the facts {!Comp_cat.Rule.assume} introduces; they
    are NOT re-checked (fairness is not a finite-graph property). *)

(** {2 The discharged skeleton} *)

type edge = {
  name : string;
      (** The Anvil lemma this edge ports, e.g.
          ["lemma_from_after_list_pods_to_after_create_pod"]. *)
  fact : Cluster.cluster_state Comp_cat.Rule.fact;
      (** The [spec |= pre ~> post] entailment token the edge established. *)
  report : Discharge.edge_report;
      (** The P5 evidence that discharged the edge's operational obligation(s). *)
}
(** One discharged [leads_to] edge of the skeleton: provenance, entailment fact,
    and the bounded-model-checking evidence behind it. *)

val edges : ?bound:Bound.t -> desired:int -> edge list Comp_cat.Res.t
(** The ordered reconcile-BODY edges ([at Init ~> at After_list_pods ~>
    at_creating ~> at After_update_vrs_status ~> at Done]), each a
    {!Comp_cat.Rule.wf1} whose [closure]/[drives] obligations are discharged by
    {!Discharge} over the bounded graph seeded at [Scenario.seed ~desired
    ~fair:true]. These are the reconcile advances that ARE clean single-step
    drives; the scheduling FRONT and the [Done ⇒ matches] TAIL are discharged
    separately inside {!esr_derivation} (reachability / invariant, not [wf1]).
    [Error] as soon as any edge's obligation is not [Ok true] (a broken or vacuous
    edge; see {!Discharge.obligation}). [bound] defaults to {!tightened_bound}. *)

val esr_derivation :
  ?bound:Bound.t ->
  desired:int ->
  Cluster.cluster_state Comp_cat.Rule.fact Comp_cat.Res.t
(** The assembled top entailment [spec |= always(desired_state_is) ~>
    current_state_matches], chained by {!Comp_cat.Rule.leads_to_trans} from three
    parts: a FRONT [always desired ~> at Init] — the scheduling step, [assume]d
    and gated by a bounded {!Discharge.reaches_holds} ([at Init] is reachable from
    the fair desired seed), because in the cyclic reconcile model it is multi-step,
    not a single-step [wf1] drive (a [wf1] there correctly fails to discharge — the
    P6 self-catch); the BODY {!edges} (step-to-step [wf1]s); and the TAIL [at Done
    ~> current_state_matches] ({!Comp_cat.Rule.leads_to_weaken} over a
    {!Discharge.invariant_holds}). [Error] if any part failed to discharge or a
    middle did not match by {!Comp_cat.Temporal.equal} — the regression-lock: a
    proof-shape regression is [Comp_cat.Err.Ill_formed], never a wrong [Ok]. *)

val esr_statement_core :
  desired:int -> Cluster.cluster_state Comp_cat.Temporal.t
(** The exact formula {!esr_derivation}'s goal must equal:
    [Comp_cat.Temporal.leads_to (Comp_cat.Temporal.always (f_desired_state_is
    ~desired)) (f_current_state_matches ~desired)] — the de-stabilized ESR core
    (see the module's honest scope gap). Built independently of the derivation so
    the equality is a genuine cross-lock. *)

val matches_esr_statement :
  ?bound:Bound.t -> desired:int -> bool Comp_cat.Res.t
(** [Comp_cat.Res.ok true] iff {!esr_derivation}'s {!Comp_cat.Rule.goal_of} is
    {!Comp_cat.Temporal.equal} to {!esr_statement_core} — the P6 headline: the
    machine-assembled, per-edge-discharged derivation establishes exactly the
    intended ESR core statement, and its shape is locked to Anvil's. *)

val tail_matches_is_stable :
  ?bound:Bound.t -> desired:int -> Discharge.edge_report
(** The bounded evidence for the one trusted lifting the kernel cannot chain (the
    outer [always]), NON-VACUOUS since P8 (BUILD-SPEC-P8 §3.3; formerly honestly
    vacuous when [rv_ceiling = 2] pruned [Done]). Three composed {!Discharge}
    checks over the fair no-disruptor reachable graph: [Done] is REACHABLE
    ({!Discharge.reaches_holds}), a MATCHING [Done] is reachable, and the
    stability invariant [current_state_matches s || not (at_done s)] holds at
    every reachable state ({!Discharge.invariant_holds}) — the decidable content
    of Anvil's [leads_to_always] stability step. In the combined report, [holds]
    requires all three verdicts AND both reaches' [frontier_emptied] (a
    truncated reach never yields a green tail); [witnesses] is the
    [Done]-and-matches state count (MEASURED [3 > 0] at {!tightened_bound},
    [desired = 1] — positive settled-match evidence, no longer the whole-graph
    count); [states_checked] / [frontier_emptied] are the invariant leg's.
    Recorded, NOT folded into {!esr_derivation}.

    {b Honest limit} (see the module-doc tail-witness note): this witnesses the
    settled match on the bounded FIRST-pass slice only ([reconcile_ceiling =
    1]), decisive relative to these ceilings (arch §4) — not a stability proof
    of the perpetual re-reconcile (P7's unbounded executable spine witnesses
    that operationally). *)

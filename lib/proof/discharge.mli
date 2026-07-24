(** [Discharge]: turn a wf1 / invariant edge's OPERATIONAL side-condition into a
    verdict computed by the P5 bounded model checker, so a {!Comp_cat.Rule}
    obligation is CHECKED by finite enumeration rather than asserted (architecture
    §2.6 "CHECKED by lasso model checking", §4 Leg 2, P6 row). Every discharge
    explores the bounded reachable graph from a seed with {!Model_check.explore}
    over {!Cluster_check.bounded_successors} (all P2 single-step + P5 multi-step
    bounds baked in), then answers a first-order question about that finite graph
    with {!Model_check.count_states_where} — never an infinite behaviour, never a
    loop keyword.

    The residual is exactly P5's: a clean discharge is verification of the BOUNDED
    system under {!Bound.t}, transferring nothing from Anvil's Verus liveness
    theorem (arch §4); and it is only as strong as the graph is exercised, which
    {!edge_report.witnesses} makes visible
    ([[feedback-workflow-zero-findings-may-be-vacuous]]). *)

type edge_report = {
  holds : bool;
      (** The edge property held at every reachable state it was tested at. *)
  witnesses : int;
      (** How many reachable states satisfied the edge's [pre] — the finding-14
          non-vacuity count. [0] means the obligation was VACUOUS (the antecedent
          was never reached under these bounds) and so verifies nothing. *)
  states_checked : int;
      (** Distinct reachable states explored — the graph size the verdict ranges
          over ({!Model_check.states_seen}). *)
  frontier_emptied : bool;
      (** Whether {!Model_check.explore} closed the reachable set within [depth]
          (bounded-exhaustive); if [false] the graph is truncated and even a
          [holds = true] is falsification-only, not decisive (arch §4). *)
}
(** The evidence one edge discharge produced: the verdict plus the non-vacuity /
    exhaustiveness metadata that keeps a green edge honest. *)

val closure_holds :
  Bound.t ->
  Cluster.t ->
  init:Cluster.cluster_state ->
  pre:(Cluster.cluster_state -> bool) ->
  post:(Cluster.cluster_state -> bool) ->
  edge_report
(** The wf1 [closure] obligation [pre /\ next => pre' \/ post'] over the bounded
    graph: for every reachable [s] with [pre s], every
    {!Cluster_check.bounded_successors} [s'] satisfies [pre s' || post s'].
    [holds] iff [count_states_where reach (fun s -> pre s && List.exists (fun s' ->
    not (pre s' || post s')) (bounded_successors bound cluster s)) = 0]; [witnesses
    = count_states_where reach pre]. A safety-shaped edge invariant, hence
    decidable over the bounded graph. *)

val drives_holds :
  Bound.t ->
  Cluster.t ->
  init:Cluster.cluster_state ->
  pre:(Cluster.cluster_state -> bool) ->
  forward:(Step.t -> bool) ->
  post:(Cluster.cluster_state -> bool) ->
  edge_report
(** The wf1 [drives] obligation [pre /\ next /\ forward => post'] over the bounded
    graph: for every reachable [s] with [pre s], every
    {!Cluster_check.bounded_labelled_successors} [(step, s')] with [forward step]
    satisfies [post s']. [forward] selects the driving action by its {!Step.t}
    label (the reconcile-advancing [Controller_step] for this cr), enumerated with
    NO wildcard. [holds] iff no forward-labelled successor of a [pre]-state lands
    outside [post]. *)

val invariant_holds :
  Bound.t ->
  Cluster.t ->
  init:Cluster.cluster_state ->
  inv:(Cluster.cluster_state -> bool) ->
  edge_report
(** The [[]j] obligation for {!Comp_cat.Rule.borrow_inv} / the [Done => matches]
    tail: every reachable state satisfies [inv] ([count_states_where reach (fun s
    -> not (inv s)) = 0]). Reachability (arch §0.1.1), so [holds = true] with
    [frontier_emptied] is decisive for the bounded system. [witnesses =
    states_checked] (an [always] has no separate antecedent to exercise). *)

val reaches_holds :
  ?depth:int ->
  Bound.t ->
  Cluster.t ->
  init:Cluster.cluster_state ->
  pre:(Cluster.cluster_state -> bool) ->
  post:(Cluster.cluster_state -> bool) ->
  edge_report
(** The non-vacuous liveness cross-check (arch §0.1.3 / P5 [check_reaches]):
    [post] is reachable within [depth] from the seed ([count_states_where reach
    post > 0]) and [pre] is reached ([witnesses > 0]). The decidable goal-
    REACHABILITY content that the P5 honest limit
    ({!Cluster_check.effectively_quiescent}) leaves as the real liveness signal
    when the ESR quiescence gate is vacuous. Not a wf1 obligation — a
    corroborating report the skeleton records alongside [closure]/[drives]. *)

val obligation : edge_report -> bool Comp_cat.Res.t
(** Adapt an {!edge_report} to a {!Comp_cat.Rule} side-condition thunk's payload:
    [Comp_cat.Res.ok true] iff [holds && witnesses > 0 && frontier_emptied]. A
    VACUOUS report ([witnesses = 0]), a truncated graph ([not frontier_emptied]),
    or a genuine violation ([not holds]) is [Comp_cat.Res.error (Comp_cat.Err.
    Ill_formed { fn = "Discharge.obligation"; why = ... })], so the wf1 /
    init_invariant call consuming it does NOT build a fact — a broken or
    unexercised edge fails the derivation rather than passing silently
    ([[feedback-confirm-tests-by-mutation]],
    [[feedback-workflow-zero-findings-may-be-vacuous]]). *)

(** [Vsts_step_view]: read the vstatefulset controller's reconcile position out of
    a {!Cluster.cluster_state}, so the P11 liveness skeleton ({!Vsts_liveness})
    can phrase its [leads_to] milestones as ordinary
    {!Comp_cat.Temporal.state_pred}s. The mechanical VStatefulSet sibling of
    {!Step_view} (BUILD-SPEC-P11 §6): same ongoing-reconcile / unmarshal template,
    only the pack ({!V_stateful_set_pack}) and reconciler-step type
    ({!V_stateful_set_reconciler.step}) are VSTS-named. Pure, total, no exception:
    an absent reconcile or an [unmarshal_state] failure is [None], never a raise. *)

val reconcile_step_of :
  controller_id:int ->
  cr_key:Common.object_ref ->
  Cluster.cluster_state ->
  V_stateful_set_reconciler.step option
(** The reconcile step controller [controller_id] is at for the cr [cr_key]:
    [Some step] iff an ongoing reconcile is keyed at [cr_key] in
    {!Cluster.ongoing_reconciles} and its [local_state]
    {!V_stateful_set_pack.unmarshal_state}s to a state whose [reconcile_step] is
    [step]; [None] if no reconcile is ongoing for [cr_key] or the stored [Value.t]
    fails to unmarshal (the latter is unreachable on states this driver reaches
    but is a total branch, not an exception — discharged via [Option.map] /
    [Option.bind] / [Result.fold], never a two-arm [match]). *)

val at_step :
  controller_id:int ->
  cr_key:Common.object_ref ->
  V_stateful_set_reconciler.step ->
  Cluster.cluster_state ->
  bool
(** [reconcile_step_of ... s = Some step] by
    {!V_stateful_set_reconciler.step_equal} — the milestone
    {!Comp_cat.Temporal.state_pred} for a reconcile position. The 17-arm
    {!V_stateful_set_reconciler.step} carries no payload, so [at_step] matches a
    single reconcile position exactly; a phase spanning several arms uses
    {!at_phase}. *)

val at_phase :
  controller_id:int ->
  cr_key:Common.object_ref ->
  (V_stateful_set_reconciler.step -> bool) ->
  Cluster.cluster_state ->
  bool
(** [reconcile_step_of ... s = Some step] with [phase step] — the index-erased
    milestone (e.g. "at some create-pod phase [Create_needed | After_create_needed]"),
    for a phase whose exact arm a concrete [desired] fixes but the skeleton names
    abstractly. *)

val scheduled_only :
  controller_id:int ->
  cr_key:Common.object_ref ->
  Cluster.cluster_state ->
  bool
(** [cr_key] is in {!Cluster.scheduled_reconciles} for [controller_id] and NOT in
    {!Cluster.ongoing_reconciles} — the kickoff antecedent ("a reconcile is queued
    but has not started"), the source of the [Run_scheduled_reconcile] edge. *)

val no_ongoing :
  controller_id:int ->
  cr_key:Common.object_ref ->
  Cluster.cluster_state ->
  bool
(** No ongoing reconcile is keyed at [cr_key] for [controller_id]
    ([reconcile_step_of ... = None]). *)

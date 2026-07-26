(** [Vsts_step_view]: read the vstatefulset controller's reconcile position out of
    a {!Cluster.cluster_state}. Implementation of [vsts_step_view.mli]; the
    mechanical VStatefulSet transposition of {!Step_view} (BUILD-SPEC-P11 §6) —
    the ongoing-reconcile / unmarshal template with the VSTS pack + reconciler-step
    types. Pure and total: an absent reconcile or an [unmarshal_state] failure is
    [None], never an exception. *)

(** The typed reconcile [step] controller [controller_id] is at for the cr
    [cr_key], or [None] if no reconcile is ongoing there or its stored
    [local_state] fails to unmarshal. Partiality is discharged by
    [Option.map] / [Option.bind] / [Result.fold] — never a two-arm
    [option]/[result] match, never a raise. *)
let reconcile_step_of ~controller_id ~cr_key (s : Cluster.cluster_state) :
    V_stateful_set_reconciler.step option =
  Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id)
  |> Option.map (fun (orc : Controller.ongoing_reconcile) -> orc.local_state)
  |> fun lo ->
  Option.bind lo (fun v ->
      V_stateful_set_pack.unmarshal_state v
      |> Result.fold
           ~ok:(fun (st : V_stateful_set_reconciler.s) -> Some st.reconcile_step)
           ~error:(fun _ -> None))

(** The milestone predicate "the reconcile is exactly at [step]", by
    {!V_stateful_set_reconciler.step_equal}. *)
let at_step ~controller_id ~cr_key step (s : Cluster.cluster_state) : bool =
  Option.fold
    (reconcile_step_of ~controller_id ~cr_key s)
    ~none:false
    ~some:(fun st -> V_stateful_set_reconciler.step_equal st step)

(** The index-erased milestone "the reconcile is at some step satisfying
    [phase]" (e.g. "at some create-pod phase"). *)
let at_phase ~controller_id ~cr_key phase (s : Cluster.cluster_state) : bool =
  Option.fold
    (reconcile_step_of ~controller_id ~cr_key s)
    ~none:false ~some:phase

(** No ongoing reconcile is keyed at [cr_key] for [controller_id]. *)
let no_ongoing ~controller_id ~cr_key (s : Cluster.cluster_state) : bool =
  Option.is_none (reconcile_step_of ~controller_id ~cr_key s)

(** The kickoff antecedent: [cr_key] is queued in
    {!Cluster.scheduled_reconciles} for [controller_id] and NOT yet ongoing. *)
let scheduled_only ~controller_id ~cr_key (s : Cluster.cluster_state) : bool =
  Object_ref_map.mem cr_key (Cluster.scheduled_reconciles s controller_id)
  && no_ongoing ~controller_id ~cr_key s

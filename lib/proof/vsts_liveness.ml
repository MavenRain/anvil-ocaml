(** [Vsts_liveness]: the vstatefulset ESR liveness skeleton, the P11 sibling of
    {!Vrs_liveness}, ported as a {!Comp_cat.Rule} entailment derivation whose SHAPE
    regression-locks Anvil's proof structure and whose every per-edge operational
    side-condition is discharged by the P5 bounded model checker ({!Discharge}).
    Implementation of [vsts_liveness.mli]; compiled documentation, NOT
    machine-checked. See the [.mli] for the honest scope gaps (consequent [always]
    dropped, antecedent tautology / fairness / [[]next] assumed, wf1
    trusted-on-stream, bounded, front as reachability, first-pass slice +
    bound-artifact discipline). *)

module E = Esr.Make (V_stateful_set)

(** The scenario controller id. *)
let controller_id = Scenario.controller_id

(** The scenario vsts key. *)
let cr_key = Scenario.vsts_ref

(** The §7.2 VSTS settling bound: the finite fair {!Bound.t} at which the
    [desired = 1], [vct:false] reachable graph closes (frontier empties) so every
    edge discharge is decisive. RECONCILE-bounded ([reconcile_ceiling = 1]): VSTS
    at a fresh desired = 1 with no stale pods reaches [Done] in ONE reconcile pass
    (the multi-pass one-pod-per-round rolling only triggers when [Delete_outdated]
    fires on an outdated pod — absent on a fresh create), so bounding invocations
    isolates the first pass and dissolves the rv-ceiling vacuity without an rv
    squeeze. Identical field set to the bound [Cluster_check.check_esr_settled_vsts]
    is tested at ([t_p11_vsts_esr]), so the liveness milestones and the settled ESR
    gate ([gate_states = Some 1], MEASURED) range over the SAME graph. The
    bound-artifact caveat (§7.3) is discharged there: [max_uid_seen = 3 < 4],
    [max_rv_seen = 2 < 5] — the ceilings never bite, so no starved "settled" state
    can masquerade as a real non-match. *)
let settling_bound : Bound.t =
  {
    max_in_flight = 2;
    max_objects_per_kind = 2;
    max_controllers = 1;
    uid_ceiling = 4;
    rv_ceiling = 5;
    reconcile_ceiling = 1;
    max_reconcile_depth = 8;
  }

(** The bounded next-relation: [s'] is a {!Cluster_check.bounded_successors} of
    [s] under {!settling_bound} over the runnable VSTS cluster. Seeds the trusted
    [[]next] axiom and the [fair]/[lift_action] leaf; the kernel does not evaluate
    its content. *)
let next_ap (s : Cluster.cluster_state) (s' : Cluster.cluster_state) : bool =
  List.exists
    (fun t -> Cluster_check.state_equal s' t)
    (Cluster_check.bounded_successors settling_bound Scenario.vsts_cluster s)

(* ---- milestone formulas (all hash-consed [lift_state]s, stable names) ------ *)

(** [lift_state (E.desired_state_is (Scenario.vsts ~desired ()))] — the ESR
    antecedent. Name is the hash-cons key; stable across the derivation. *)
let f_desired_state_is ~desired : Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.lift_state ~name:"desired_state_is"
    (E.desired_state_is (Scenario.vsts ~desired ()))

(** [lift_state (Vsts_step_view.scheduled_only ...)] — a reconcile is queued, not
    started. *)
let f_scheduled : Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.lift_state ~name:"scheduled"
    (Vsts_step_view.scheduled_only ~controller_id ~cr_key)

(** A stable hash-cons tag for each reconcile [step] constructor (all 17 arms
    enumerated, no wildcard) so [f_at] milestones with equal steps are
    {!Comp_cat.Temporal.equal}. *)
let step_tag (step : V_stateful_set_reconciler.step) : string =
  match step with
  | Init -> "Init"
  | After_list_pod -> "After_list_pod"
  | Get_pvc -> "Get_pvc"
  | After_get_pvc -> "After_get_pvc"
  | Create_pvc -> "Create_pvc"
  | After_create_pvc -> "After_create_pvc"
  | Skip_pvc -> "Skip_pvc"
  | Create_needed -> "Create_needed"
  | After_create_needed -> "After_create_needed"
  | Update_needed -> "Update_needed"
  | After_update_needed -> "After_update_needed"
  | Delete_condemned -> "Delete_condemned"
  | After_delete_condemned -> "After_delete_condemned"
  | Delete_outdated -> "Delete_outdated"
  | After_delete_outdated -> "After_delete_outdated"
  | Done -> "Done"
  | Error -> "Error"

(** [lift_state (Vsts_step_view.at_step ... step)] — the reconcile is exactly at
    [step]. *)
let f_at (step : V_stateful_set_reconciler.step) :
    Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.lift_state
    ~name:("at_" ^ step_tag step)
    (Vsts_step_view.at_step ~controller_id ~cr_key step)

(** The index-erased create-pod phase: "at some [Create_needed |
    After_create_needed]". Every OTHER reconcile arm is [false] (all 17 arms
    enumerated, no wildcard). *)
let is_create_phase (step : V_stateful_set_reconciler.step) : bool =
  match step with
  | Create_needed | After_create_needed -> true
  | Init | After_list_pod | Get_pvc | After_get_pvc | Create_pvc
  | After_create_pvc | Skip_pvc | Update_needed | After_update_needed
  | Delete_condemned | After_delete_condemned | Delete_outdated
  | After_delete_outdated | Done | Error ->
    false

(** [lift_state (Vsts_step_view.at_phase ... is_create_phase)] — the index-erased
    "at creating" milestone. *)
let f_at_creating : Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.lift_state ~name:"at_creating"
    (Vsts_step_view.at_phase ~controller_id ~cr_key is_create_phase)

(** The raw ESR target predicate (the ordinal-stable [current_state_matches]) at
    [desired]. *)
let current_state_matches ~desired (s : Cluster.cluster_state) : bool =
  Vsts_invariants.current_state_matches (Scenario.vsts ~desired ()) s

(** [lift_state (Vsts_invariants.current_state_matches ...)] — the ESR target. *)
let f_current_state_matches ~desired :
    Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.lift_state ~name:"current_state_matches"
    (current_state_matches ~desired)

(** The raw "reconcile is at [Done]" predicate, reused by the tail edge and its
    stability cross-check. *)
let at_done (s : Cluster.cluster_state) : bool =
  Vsts_step_view.at_step ~controller_id ~cr_key V_stateful_set_reconciler.Done s

(** The ambient assumption every {!Comp_cat.Rule} combinator shares: the
    conjunction of the init condition, [always [next]], and controller fairness.
    Built from {!Comp_cat.Temporal} constructors so hash-consing makes every
    per-[desired] rebuild the same node (the sharing {!Comp_cat.Rule.assume}
    requires). Its conjuncts are TRUSTED axioms, not re-checked. *)
let spec ~desired : Cluster.cluster_state Comp_cat.Temporal.t =
  let open Comp_cat.Temporal in
  conj
    (f_desired_state_is ~desired)
    (conj
       (always (lift_action ~name:"cluster_next" next_ap))
       (lift_state ~name:"fair_controller" (fun _ -> true)))

(* ---- the discharged skeleton ---------------------------------------------- *)

type edge = {
  name : string;
  fact : Cluster.cluster_state Comp_cat.Rule.fact;
  report : Discharge.edge_report;
}

(** The {!Step.t} label of the controller run/continue/end action for this cr
    (all 12 arms enumerated, no wildcard). *)
let controller_label (step : Step.t) : bool =
  match step with
  | Controller_step (cid, _, kopt) ->
    cid = controller_id
    && Option.fold kopt ~none:false ~some:(fun k ->
           Common.equal_object_ref k cr_key)
  | Api_server_step _ | Builtin_controllers_step _
  | Schedule_controller_reconcile_step _ | Restart_controller_step _
  | Disable_crash_step _ | Drop_req_step _ | Disable_req_drop_step
  | Pod_monkey_step _ | Disable_pod_monkey_step | External_step _ | Stutter_step
    ->
    false

(** The wf1 crux: one step edge. Wires the three trusted facts ([always_next],
    [pre_enables], [fair]) so wf1's connecting-formula checks pass — the
    [enabled_pred]/name reused in both [pre_enables]'s consequent and [fair]'s
    premise so they are the SAME hash-consed node — and discharges the two CHECKED
    obligations ([closure], [drives]) via {!Discharge}. Returns the {!edge} record
    on [Ok], with the closure report as evidence ([drives] is folded into the
    obligation thunk). Reused VERBATIM from {!Vrs_liveness.wf1_edge}, only the
    runnable cluster is {!Scenario.vsts_cluster}. *)
let wf1_edge ~name ~pre_pred ~pre_name ~post_pred ~post_name ~forward_label
    ~forward_ap ~forward_name ~bound ~init ~desired : edge Comp_cat.Res.t =
  let open Comp_cat.Temporal in
  let pre = lift_state ~name:pre_name pre_pred in
  let post = lift_state ~name:post_name post_pred in
  let enabled_pred s =
    List.exists
      (fun (step, _) -> forward_label step)
      (Cluster_check.bounded_labelled_successors bound Scenario.vsts_cluster s)
  in
  let e = lift_state ~name:("enabled_" ^ forward_name) enabled_pred in
  let sp = spec ~desired in
  let always_next =
    Comp_cat.Rule.assume ~spec:sp
      (always (lift_action ~name:"cluster_next" next_ap))
  in
  let pre_enables =
    Comp_cat.Rule.assume ~spec:sp (always (implies pre e))
  in
  let fair =
    Comp_cat.Rule.assume ~spec:sp
      (weak_fairness
         ~pre_name:("enabled_" ^ forward_name)
         enabled_pred ~fwd_name:forward_name forward_ap)
  in
  let c_rep =
    Discharge.closure_holds bound Scenario.vsts_cluster ~init ~pre:pre_pred
      ~post:post_pred
  in
  let d_rep =
    Discharge.drives_holds bound Scenario.vsts_cluster ~init ~pre:pre_pred
      ~forward:forward_label ~post:post_pred
  in
  Comp_cat.Rule.wf1 ~spec:sp ~pre ~post
    ~closure:(fun () -> Discharge.obligation c_rep)
    ~drives:(fun () -> Discharge.obligation d_rep)
    ~always_next ~pre_enables ~fair
  |> Result.map (fun fact -> { name; fact; report = c_rep })

(** The ordered reconcile-BODY edges for [desired], each a {!wf1_edge}. Mirrors
    the MEASURED [desired = 1], [vct:false], fresh-cluster reconcile trajectory
    (read off [v_stateful_set_reconciler.ml] [reconcile_core] AND confirmed by the
    per-step reachable-state counts pinned in [t_p11_vsts_liveness]):

    {[ Init -> After_list_pod -> Create_needed -> After_create_needed
            -> Delete_outdated -> Done ]}

    FIVE edges. Two honest corrections to the BUILD-SPEC §7.1 SKETCH (which guessed
    a 3-edge [Init -> After_list_pod -> create-phase -> Done] chain), forced by the
    measurement (the "MEASURE, do not tune" discipline):

    - [Create_needed] and [After_create_needed] are TWO sequential controller steps
      (request-emit then response-process), NOT index-variants of one phase: a
      {!Comp_cat.Rule.wf1} [drives] is single-step, so a multi-member create-phase
      cannot serve as an edge PRE (from [Create_needed] the controller drives to
      [After_create_needed], i.e. INTO the phase, not to its exit). VSTS
      [reconcile_core] writes no status, so there is still no status-update edge
      (unlike VRS).
    - a fresh [desired = 1] create still traverses the [Delete_outdated] scan:
      [After_create_needed]'s [create_or_after_update_needed_helper] advances to
      [Delete_outdated] once every needed pod is created; with no outdated pod,
      [get_largest_unmatched_pods] is [None] so [Delete_outdated] steps straight to
      [Done] (no request; [After_delete_outdated] is never reached — pinned [= 0]).

    Every edge is a clean single-step controller drive; the scheduling FRONT
    ([always desired ~> at Init]) and the tail ([Done ~> matches]) are NOT —
    discharged as reachability / invariant inside {!esr_derivation}. Fail-fast via
    {!Comp_cat.Res.all}. [bound] defaults to {!settling_bound}. *)
let[@warning "-16"] edges ?(bound = settling_bound) ~desired :
    edge list Comp_cat.Res.t =
  let init = Scenario.vsts_seed ~desired ~fair:true in
  let mk ~name ~pre ~post ~forward_name =
    wf1_edge ~name
      ~pre_pred:(Vsts_step_view.at_step ~controller_id ~cr_key pre)
      ~pre_name:("at_" ^ step_tag pre)
      ~post_pred:(Vsts_step_view.at_step ~controller_id ~cr_key post)
      ~post_name:("at_" ^ step_tag post)
      ~forward_label:controller_label ~forward_ap:next_ap ~forward_name ~bound
      ~init ~desired
  in
  let e1 =
    mk ~name:"lemma_init_to_after_list_pod"
      ~pre:V_stateful_set_reconciler.Init
      ~post:V_stateful_set_reconciler.After_list_pod
      ~forward_name:"controller_list"
  in
  let e2 =
    mk ~name:"lemma_after_list_to_create_needed"
      ~pre:V_stateful_set_reconciler.After_list_pod
      ~post:V_stateful_set_reconciler.Create_needed
      ~forward_name:"controller_create_needed"
  in
  let e3 =
    mk ~name:"lemma_create_needed_to_after_create_needed"
      ~pre:V_stateful_set_reconciler.Create_needed
      ~post:V_stateful_set_reconciler.After_create_needed
      ~forward_name:"controller_after_create_needed"
  in
  let e4 =
    mk ~name:"lemma_after_create_needed_to_delete_outdated"
      ~pre:V_stateful_set_reconciler.After_create_needed
      ~post:V_stateful_set_reconciler.Delete_outdated
      ~forward_name:"controller_scan_outdated"
  in
  let e5 =
    mk ~name:"lemma_delete_outdated_to_done"
      ~pre:V_stateful_set_reconciler.Delete_outdated
      ~post:V_stateful_set_reconciler.Done
      ~forward_name:"controller_done"
  in
  Comp_cat.Res.all [ e1; e2; e3; e4; e5 ]

(** The exact formula {!esr_derivation}'s goal must equal — the de-stabilized ESR
    core, built independently of the derivation so the equality is a genuine
    cross-lock. *)
let esr_statement_core ~desired : Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.leads_to
    (Comp_cat.Temporal.always (f_desired_state_is ~desired))
    (f_current_state_matches ~desired)

(** The assembled top entailment [spec |= always(desired_state_is) ~>
    current_state_matches], chained by {!Comp_cat.Rule.leads_to_trans} from three
    parts: FRONT [always desired ~> at Init] (reachability-discharged [assume]);
    the BODY {!edges} (three step-to-step [wf1]s); and TAIL [at Done ~>
    current_state_matches] ({!Comp_cat.Rule.leads_to_weaken} over a bounded
    invariant). Threaded with {!Result.bind}; a middle mismatch, a failed
    obligation, or a failed edge is [Err.Ill_formed] (the regression-lock: a
    proof-shape regression is never a wrong [Ok]). *)
let[@warning "-16"] esr_derivation ?(bound = settling_bound) ~desired :
    Cluster.cluster_state Comp_cat.Rule.fact Comp_cat.Res.t =
  let open Comp_cat.Temporal in
  let sp = spec ~desired in
  let init = Scenario.vsts_seed ~desired ~fair:true in
  Result.bind (edges ~bound ~desired) (fun es ->
      match es with
      | [ e1e; e2e; e3e; e4e; e5e ] ->
        let f_desired = f_desired_state_is ~desired in
        let f_init = f_at V_stateful_set_reconciler.Init in
        (* FRONT: reachability-discharged [assume] of [always desired ~> at
           Init]. Gated on [reaches_holds]: [at Init] reachable and [desired]
           exercised from the fair seed. *)
        let front_rep =
          Discharge.reaches_holds bound Scenario.vsts_cluster ~init
            ~pre:(E.desired_state_is (Scenario.vsts ~desired ()))
            ~post:
              (Vsts_step_view.at_step ~controller_id ~cr_key
                 V_stateful_set_reconciler.Init)
        in
        Result.bind (Discharge.obligation front_rep) (fun (_ : bool) ->
            let front_fact =
              Comp_cat.Rule.assume ~spec:sp (leads_to (always f_desired) f_init)
            in
            (* TAIL: discharge [Done => matches] as a bounded invariant, then
               weaken [Done ~> Done] into [Done ~> current_state_matches]. *)
            let f_done = f_at V_stateful_set_reconciler.Done in
            let f_csm = f_current_state_matches ~desired in
            let tail_rep =
              Discharge.invariant_holds bound Scenario.vsts_cluster ~init
                ~inv:(fun s ->
                  (not (at_done s)) || current_state_matches ~desired s)
            in
            Result.bind (Discharge.obligation tail_rep) (fun (_ : bool) ->
                let tail_pre =
                  Comp_cat.Rule.assume ~spec:sp
                    (always (implies f_done f_done))
                in
                let j =
                  Comp_cat.Rule.assume ~spec:sp (always (implies f_done f_csm))
                in
                Result.bind
                  (Comp_cat.Rule.leads_to_weaken ~pre:tail_pre ~post:j
                     (Comp_cat.Rule.leads_to_self ~spec:sp f_done))
                  (fun tail_fact ->
                    (* Chain FRONT ; e1 ; e2 ; e3 ; e4 ; e5 ; TAIL. *)
                    Result.bind
                      (Comp_cat.Rule.leads_to_trans e5e.fact tail_fact)
                      (fun c5 ->
                        Result.bind
                          (Comp_cat.Rule.leads_to_trans e4e.fact c5)
                          (fun c4 ->
                            Result.bind
                              (Comp_cat.Rule.leads_to_trans e3e.fact c4)
                              (fun c3 ->
                                Result.bind
                                  (Comp_cat.Rule.leads_to_trans e2e.fact c3)
                                  (fun c2 ->
                                    Result.bind
                                      (Comp_cat.Rule.leads_to_trans e1e.fact c2)
                                      (fun c1 ->
                                        Comp_cat.Rule.leads_to_trans front_fact
                                          c1))))))))
      | _ ->
        Error
          (Comp_cat.Err.Ill_formed
             {
               fn = "Vsts_liveness.esr_derivation";
               why = "unexpected edge count";
             }))

(** [Ok true] iff {!esr_derivation}'s {!Comp_cat.Rule.goal_of} is
    {!Comp_cat.Temporal.equal} to {!esr_statement_core} — the P11 headline
    cross-lock. *)
let[@warning "-16"] matches_esr_statement ?(bound = settling_bound) ~desired :
    bool Comp_cat.Res.t =
  Result.map
    (fun fact ->
      Comp_cat.Temporal.equal
        (Comp_cat.Rule.goal_of fact)
        (esr_statement_core ~desired))
    (esr_derivation ~bound ~desired)

(** The bounded evidence for the trusted outer-[always] the kernel cannot chain.
    Three composed {!Discharge} checks over the fair-seed reachable graph: (a)
    [Done] is REACHABLE; (b) a MATCHING [Done] is reachable; (c) the stability
    invariant [current_state_matches s || not (at_done s)] holds at every reachable
    state — the decidable content of Anvil's [leads_to_always] step. Combined
    report: [holds] requires all three verdicts AND the two reaches'
    [frontier_emptied] explicitly (a truncated reach could miss a late falsifier);
    [witnesses] is the [Done]-and-matches state count;
    [states_checked]/[frontier_emptied] come from the invariant leg. Recorded, NOT
    folded into {!esr_derivation}. If [Done] is pruned at every feasible bound the
    report is honestly vacuous ([witnesses = 0]) — disclosed by the measured
    milestone-count witness, not tuned away. *)
let[@warning "-16"] tail_matches_is_stable ?(bound = settling_bound) ~desired :
    Discharge.edge_report =
  let init = Scenario.vsts_seed ~desired ~fair:true in
  let done_reached =
    Discharge.reaches_holds bound Scenario.vsts_cluster ~init ~pre:at_done
      ~post:at_done
  in
  let matched_done s = at_done s && current_state_matches ~desired s in
  let match_reached =
    Discharge.reaches_holds bound Scenario.vsts_cluster ~init ~pre:matched_done
      ~post:matched_done
  in
  let stability =
    Discharge.invariant_holds bound Scenario.vsts_cluster ~init
      ~inv:(fun s -> current_state_matches ~desired s || not (at_done s))
  in
  {
    Discharge.holds =
      done_reached.Discharge.holds && match_reached.Discharge.holds
      && stability.Discharge.holds
      && done_reached.Discharge.frontier_emptied
      && match_reached.Discharge.frontier_emptied
      && stability.Discharge.frontier_emptied;
    witnesses = match_reached.Discharge.witnesses;
    states_checked = stability.Discharge.states_checked;
    frontier_emptied = stability.Discharge.frontier_emptied;
  }

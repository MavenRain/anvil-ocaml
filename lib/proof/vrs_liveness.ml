(** [Vrs_liveness]: the vreplicaset ESR liveness skeleton, ported as a
    {!Comp_cat.Rule} entailment derivation whose SHAPE regression-locks Anvil's
    proof structure and whose every per-edge operational side-condition is
    discharged by the P5 bounded model checker ({!Discharge}). Implementation of
    [vrs_liveness.mli]; compiled documentation, NOT machine-checked.

    {b Honest scope gaps} (documented, not defects — BUILD-SPEC-P6 §4.7):

    1. Consequent [always] dropped. The derived goal is
       [always(desired_state_is) ~> current_state_matches], not
       [~> always(current_state_matches)]: the kernel has no [leads_to_always], so
       the outer-[always] stability step is trusted, cross-checked by
       {!tail_matches_is_stable}.
    2. Antecedent [always] via a trusted tautology. [[](always desired => desired)]
       is [assume]d (temporal validity, not a finite-graph fact), alongside
       fairness and [[]next].
    3. [wf1]'s internal omega-induction is trusted-on-stream. Only
       [closure]/[drives]/[[]j] are model-checked.
    4. Bounded. Everything holds only up to {!tightened_bound}; transfers nothing
       from Anvil's Verus theorem.
    5. Front discharged as reachability, not a single-step drive. The scheduling
       step [always(desired) ~> at Init] is [assume]d, gated by a bounded
       {!Discharge.reaches_holds} ([at Init] reachable from the fair [desired]
       seed), because in the cyclic reconcile model it is genuinely multi-step
       (Anvil's [always eventually scheduled] + [wf(run)]), NOT a [wf1]
       single-step [drives] — a [wf1] there correctly fails to discharge. Weaker
       evidence than the body edges' [closure]+[drives]; the P6 self-catch.
    6. Tail / match WITNESSED since P8 (MEASURED; BUILD-SPEC-P8 §3.3 — formerly
       honestly VACUOUS when [rv_ceiling = 2] pruned [Done], mirroring P5's
       honest-vacuity ESR gate [gate_states = Some 0]). At the P8
       reconcile-bounded {!tightened_bound} ([reconcile_ceiling = 1],
       [rv_ceiling = 4]) the 23-state graph (frontier emptied) reaches every
       milestone: [Init = 2], [After_list_pods = 4], [After_create_pod _ = 4],
       [After_update_vrs_status = 5], [Done = 3], [current_state_matches = 9]
       — all POSITIVE, so e4's [drives] ([After_update_vrs_status ~> Done]) and
       the tail ([Done => current_state_matches], and
       {!tail_matches_is_stable} with 3 matching-[Done] witnesses) are now
       discharged non-vacuously. HONEST LIMIT: this is the bounded FIRST-pass
       slice only — one reconcile invocation from the empty cluster, decisive
       relative to these ceilings (arch §4); steady-state re-reconcile is P7's
       unbounded operational witness, not claimed here. *)

module E = Esr.Make (Vreplica_set)

(** The scenario controller id. *)
let controller_id = Scenario.controller_id

(** The scenario vrs key. *)
let cr_key = Scenario.vrs_ref

(** The decisive-ESR bound at which the [desired = 1] reachable graph closes
    (frontier empties) so every edge discharge is decisive. Field set mirrors
    {!Bound.t} exactly. Since P8 it is RECONCILE-bounded: [reconcile_ceiling =
    1] isolates the first reconcile pass, which lets [rv_ceiling] rise to 4 so
    the pass reaches [Done] (BUILD-SPEC-P8 §0/§1/§3.3).

    Empirically tuned (BUILD-SPEC-P6 §4.1, "verify empirically — do not guess";
    numbers read off the {!Discharge} reports at the [desired = 1],
    [Scenario.seed ~fair:true] seed):

    - [reconcile_ceiling = 1] is the load-bearing P8 field: it prunes every
      state whose per-controller [reconcile_id_counter] exceeds 1, i.e. the
      SECOND and later reconcile invocations. With the second pass excluded,
      [rv_ceiling = 4] admits both content writes of the single pass (create
      pod, then update status) and the graph still closes: 23 states,
      [frontier_emptied = true], every body-edge [pre] reached
      ([witnesses > 0]), and — new with P8 — [Done] reached (3 states) and
      [current_state_matches] reached (9 states), so e4's [drives] and the tail
      are discharged with POSITIVE witnesses (see {!tail_matches_is_stable}).
      [uid_ceiling = 4] gives the pass's pod-create uid headroom;
      [max_in_flight = 2], [max_objects_per_kind = 2], [max_reconcile_depth =
      8] are unchanged from P6 (the single pass needs no more).
    - HISTORY — why [rv_ceiling >= 3] alone (P6, no reconcile ceiling) broke
      e2, the tension P8 dissolves (BUILD-SPEC-P8 §0). e2 is [After_list_pods
      ~> at_creating]. In the FIRST reconcile pass from the empty seed,
      [filtered_pods = []], [diff = desired - 0 = 1 > 0], so the pass MUST
      enter the create phase — e2's [post] ([at_creating]) genuinely holds for
      every successor. But with reconcile invocations UNBOUNDED, [rv >= 3]
      admitted a SECOND cycle: the pod created in pass 1 persists in etcd, so a
      later [After_list_pods] sees [filtered_pods = [that pod]], [diff = 0],
      and advances DIRECTLY to [After_update_vrs_status], SKIPPING
      [at_creating] — a real successor outside e2's [post], so [closure] was
      correctly [false] (and the un-clipped growth also truncated the
      exploration, [frontier_emptied = false]). So P6 had to hold [rv_ceiling
      = 2], which pruned the second write and left [Done] and the match
      unreachable — the honestly-VACUOUS tail. The create-skip is a
      SECOND-INVOCATION phenomenon, not an rv phenomenon: bounding invocations
      ([reconcile_ceiling = 1]) excludes it directly, no rv squeeze needed.
      The checker refusing to certify e2 in steady state was correct then and
      is not overridden now — the second pass is out of scope, not certified.

    HONEST SCOPE (unchanged by P8, read before trusting the green): the linear
    body chain [Init -> list -> create -> update -> Done] is faithful to, and
    P6 verifies, the FIRST scale-up reconcile pass from an empty cluster ONLY;
    steady-state cycles (where create is skipped) are a different, branching
    chain the skeleton does not claim ([reconcile_ceiling = 1] is chosen to
    scope the claim honestly, not to suppress a counterexample — the
    perpetual re-reconcile is witnessed operationally by P7's unbounded
    executable spine instead). Any "ESR verified" reading must be qualified to
    this first-pass bounded slice (arch §4). *)
let tightened_bound : Bound.t =
  {
    max_in_flight = 2;
    max_objects_per_kind = 2;
    max_controllers = 1;
    uid_ceiling = 4;
    rv_ceiling = 4;
    reconcile_ceiling = 1;
    max_reconcile_depth = 8;
    monkey_forge = [];
  }

(** The bounded next-relation: [s'] is a {!Cluster_check.bounded_successors} of
    [s] under {!tightened_bound}. Seeds the trusted [[]next] axiom and the
    [fair]/[lift_action] leaf; the kernel does not evaluate its content. *)
let next_ap (s : Cluster.cluster_state) (s' : Cluster.cluster_state) : bool =
  List.exists
    (fun t -> Cluster_check.state_equal s' t)
    (Cluster_check.bounded_successors tightened_bound Scenario.cluster s)

(* ---- milestone formulas (all hash-consed [lift_state]s, stable names) ------ *)

(** [lift_state (E.desired_state_is (Scenario.vrs ~desired))] — the ESR
    antecedent. Name is the hash-cons key; stable across the derivation. *)
let f_desired_state_is ~desired : Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.lift_state ~name:"desired_state_is"
    (E.desired_state_is (Scenario.vrs ~desired))

(** [lift_state (Step_view.scheduled_only ...)] — a reconcile is queued, not
    started. *)
let f_scheduled : Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.lift_state ~name:"scheduled"
    (Step_view.scheduled_only ~controller_id ~cr_key)

(** A stable hash-cons tag for each reconcile [step] constructor (all 7 arms
    enumerated, no wildcard) so [f_at] milestones with equal steps are
    {!Comp_cat.Temporal.equal}. *)
let step_tag (step : Vreplica_set_reconciler.step) : string =
  match step with
  | Init -> "Init"
  | After_list_pods -> "After_list_pods"
  | After_create_pod i -> "After_create_pod_" ^ string_of_int i
  | After_delete_pod i -> "After_delete_pod_" ^ string_of_int i
  | After_update_vrs_status -> "After_update_vrs_status"
  | Done -> "Done"
  | Error -> "Error"

(** [lift_state (Step_view.at_step ... step)] — the reconcile is exactly at
    [step]. *)
let f_at (step : Vreplica_set_reconciler.step) :
    Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.lift_state
    ~name:("at_" ^ step_tag step)
    (Step_view.at_step ~controller_id ~cr_key step)

(** The index-erased pod-adjust phase: "at some [After_create_pod _]". Every
    OTHER reconcile arm is [false] (all 7 arms enumerated, no wildcard). *)
let is_after_create_pod (step : Vreplica_set_reconciler.step) : bool =
  match step with
  | After_create_pod _ -> true
  | Init | After_list_pods | After_delete_pod _ | After_update_vrs_status
  | Done | Error ->
    false

(** [lift_state (Step_view.at_phase ... is_after_create_pod)] — the index-erased
    "at creating" milestone. *)
let f_at_creating : Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.lift_state ~name:"at_creating"
    (Step_view.at_phase ~controller_id ~cr_key is_after_create_pod)

(** The raw ESR target predicate (#11 [current_state_matches]) at [desired]. *)
let current_state_matches ~desired (s : Cluster.cluster_state) : bool =
  (Invariants.liveness_goal ~cr:(Scenario.vrs ~desired)).holds s

(** [lift_state (Invariants.liveness_goal ~cr).holds] — the ESR target. *)
let f_current_state_matches ~desired :
    Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.lift_state ~name:"current_state_matches"
    (current_state_matches ~desired)

(** The raw "reconcile is at [Done]" predicate, reused by the tail edge and its
    stability cross-check. *)
let at_done (s : Cluster.cluster_state) : bool =
  Step_view.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Done s

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

(** The wf1 crux (BUILD-SPEC-P6 §4.4): one step edge. Wires the three trusted
    facts ([always_next], [pre_enables], [fair]) so wf1's connecting-formula
    checks pass — the [enabled_pred]/name reused in both [pre_enables]'s
    consequent and [fair]'s premise so they are the SAME hash-consed node — and
    discharges the two CHECKED obligations ([closure], [drives]) via
    {!Discharge}. Returns the {!edge} record on [Ok], with the closure report as
    evidence ([drives] is folded into the obligation thunk). *)
let wf1_edge ~name ~pre_pred ~pre_name ~post_pred ~post_name ~forward_label
    ~forward_ap ~forward_name ~bound ~init ~desired : edge Comp_cat.Res.t =
  let open Comp_cat.Temporal in
  let pre = lift_state ~name:pre_name pre_pred in
  let post = lift_state ~name:post_name post_pred in
  let enabled_pred s =
    List.exists
      (fun (step, _) -> forward_label step)
      (Cluster_check.bounded_labelled_successors bound Scenario.cluster s)
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
    Discharge.closure_holds bound Scenario.cluster ~init ~pre:pre_pred
      ~post:post_pred
  in
  let d_rep =
    Discharge.drives_holds bound Scenario.cluster ~init ~pre:pre_pred
      ~forward:forward_label ~post:post_pred
  in
  Comp_cat.Rule.wf1 ~spec:sp ~pre ~post
    ~closure:(fun () -> Discharge.obligation c_rep)
    ~drives:(fun () -> Discharge.obligation d_rep)
    ~always_next ~pre_enables ~fair
  |> Result.map (fun fact -> { name; fact; report = c_rep })

(** The ordered reconcile-BODY edges for [desired], each a {!wf1_edge}. Mirrors
    the real [desired = 1] reconcile trajectory confirmed against
    [vreplica_set_reconciler.ml]: [Init -> After_list_pods -> After_create_pod 0
    -> After_update_vrs_status -> Done]. These four ARE clean single-step [wf1]
    drives; the scheduling FRONT ([always desired ~> at Init]) and the tail
    ([Done ~> matches]) are NOT — they are discharged as reachability /
    invariant inside {!esr_derivation}, not as [wf1] edges (BUILD-SPEC-P6 §4.5:
    a [wf1] on the cyclic scheduling step correctly FAILS its [drives], the P6
    self-catch). Every body edge uses the [controller_label] forward. Fail-fast
    via {!Comp_cat.Res.all} (first non-[Ok] short-circuits). [bound] defaults to
    {!tightened_bound}. *)
let[@warning "-16"] edges ?(bound = tightened_bound) ~desired :
    edge list Comp_cat.Res.t =
  let init = Scenario.seed ~desired ~fair:true in
  let mk ~name ~pre_pred ~pre_name ~post_pred ~post_name ~forward_name =
    wf1_edge ~name ~pre_pred ~pre_name ~post_pred ~post_name
      ~forward_label:controller_label ~forward_ap:next_ap ~forward_name ~bound
      ~init ~desired
  in
  let e1 =
    mk ~name:"lemma_init_to_after_list_pods"
      ~pre_pred:
        (Step_view.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Init)
      ~pre_name:("at_" ^ step_tag Vreplica_set_reconciler.Init)
      ~post_pred:
        (Step_view.at_step ~controller_id ~cr_key
           Vreplica_set_reconciler.After_list_pods)
      ~post_name:("at_" ^ step_tag Vreplica_set_reconciler.After_list_pods)
      ~forward_name:"controller_list"
  in
  let e2 =
    mk ~name:"lemma_after_list_to_create"
      ~pre_pred:
        (Step_view.at_step ~controller_id ~cr_key
           Vreplica_set_reconciler.After_list_pods)
      ~pre_name:("at_" ^ step_tag Vreplica_set_reconciler.After_list_pods)
      ~post_pred:(Step_view.at_phase ~controller_id ~cr_key is_after_create_pod)
      ~post_name:"at_creating" ~forward_name:"controller_create"
  in
  let e3 =
    mk ~name:"lemma_create_to_after_update_status"
      ~pre_pred:(Step_view.at_phase ~controller_id ~cr_key is_after_create_pod)
      ~pre_name:"at_creating"
      ~post_pred:
        (Step_view.at_step ~controller_id ~cr_key
           Vreplica_set_reconciler.After_update_vrs_status)
      ~post_name:
        ("at_" ^ step_tag Vreplica_set_reconciler.After_update_vrs_status)
      ~forward_name:"controller_update_status"
  in
  let e4 =
    mk ~name:"lemma_after_update_status_to_done"
      ~pre_pred:
        (Step_view.at_step ~controller_id ~cr_key
           Vreplica_set_reconciler.After_update_vrs_status)
      ~pre_name:
        ("at_" ^ step_tag Vreplica_set_reconciler.After_update_vrs_status)
      ~post_pred:
        (Step_view.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Done)
      ~post_name:("at_" ^ step_tag Vreplica_set_reconciler.Done)
      ~forward_name:"controller_done"
  in
  Comp_cat.Res.all [ e1; e2; e3; e4 ]

(** The exact formula {!esr_derivation}'s goal must equal — the de-stabilized ESR
    core, built independently of the derivation so the equality is a genuine
    cross-lock. *)
let esr_statement_core ~desired : Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.leads_to
    (Comp_cat.Temporal.always (f_desired_state_is ~desired))
    (f_current_state_matches ~desired)

(** The assembled top entailment [spec |= always(desired_state_is) ~>
    current_state_matches], chained by {!Comp_cat.Rule.leads_to_trans} from three
    parts (BUILD-SPEC-P6 §4.6):

    - FRONT [always desired ~> at Init]: the scheduling step is genuinely
      MULTI-step in the cyclic reconcile model (Anvil's [always eventually
      scheduled] + [wf(run)]), so a single-step [wf1] there correctly fails to
      discharge — the P6 self-catch. Instead it is [assume]d, but only after a
      bounded {!Discharge.reaches_holds} witnesses that [at Init] is reachable
      from the fair [desired] seed ([at Init] reached, [desired] exercised);
      [Error] otherwise, so a vacuous / truncated front sinks the whole
      derivation honestly.
    - BODY {!edges}: the four step-to-step [wf1]s, each closure+drives
      discharged.
    - TAIL [at Done ~> current_state_matches]: discharge [Done => matches] as a
      bounded invariant, then {!Comp_cat.Rule.leads_to_weaken} [leads_to_self
      Done] into [Done ~> matches].

    Threaded with {!Result.bind}; a middle mismatch, a failed obligation, or a
    failed edge is [Err.Ill_formed] (the regression-lock: a proof-shape
    regression is never a wrong [Ok]). *)
let[@warning "-16"] esr_derivation ?(bound = tightened_bound) ~desired :
    Cluster.cluster_state Comp_cat.Rule.fact Comp_cat.Res.t =
  let open Comp_cat.Temporal in
  let sp = spec ~desired in
  let init = Scenario.seed ~desired ~fair:true in
  Result.bind (edges ~bound ~desired) (fun es ->
      match es with
      | [ e1e; e2e; e3e; e4e ] ->
        let f_desired = f_desired_state_is ~desired in
        let f_init = f_at Vreplica_set_reconciler.Init in
        (* FRONT: reachability-discharged [assume] of [always desired ~> at
           Init]. Gated on [reaches_holds]: [at Init] reachable and [desired]
           exercised from the fair seed. *)
        let front_rep =
          Discharge.reaches_holds bound Scenario.cluster ~init
            ~pre:(E.desired_state_is (Scenario.vrs ~desired))
            ~post:
              (Step_view.at_step ~controller_id ~cr_key
                 Vreplica_set_reconciler.Init)
        in
        Result.bind (Discharge.obligation front_rep) (fun (_ : bool) ->
            let front_fact =
              Comp_cat.Rule.assume ~spec:sp (leads_to (always f_desired) f_init)
            in
            (* TAIL: discharge [Done => matches] as a bounded invariant, then
               weaken [Done ~> Done] into [Done ~> current_state_matches]. Since
               P8 (reconcile-bounded tightened_bound) this invariant holds
               NON-vacuously: [Done] is reachable (3 states, MEASURED) and each
               satisfies the match — positive witnesses; cross-checked with the
               composed reachability report in [tail_matches_is_stable]. *)
            let f_done = f_at Vreplica_set_reconciler.Done in
            let f_csm = f_current_state_matches ~desired in
            let tail_rep =
              Discharge.invariant_holds bound Scenario.cluster ~init
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
                    (* Chain FRONT ; e1 ; e2 ; e3 ; e4 ; TAIL. *)
                    Result.bind
                      (Comp_cat.Rule.leads_to_trans e4e.fact tail_fact)
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
                                    Comp_cat.Rule.leads_to_trans front_fact c1)))))))
      | _ ->
        Error
          (Comp_cat.Err.Ill_formed
             {
               fn = "Vrs_liveness.esr_derivation";
               why = "unexpected edge count";
             }))

(** [Ok true] iff {!esr_derivation}'s {!Comp_cat.Rule.goal_of} is
    {!Comp_cat.Temporal.equal} to {!esr_statement_core} — the P6 headline
    cross-lock. *)
let[@warning "-16"] matches_esr_statement ?(bound = tightened_bound) ~desired :
    bool Comp_cat.Res.t =
  Result.map
    (fun fact ->
      Comp_cat.Temporal.equal
        (Comp_cat.Rule.goal_of fact)
        (esr_statement_core ~desired))
    (esr_derivation ~bound ~desired)

(** The bounded evidence for the trusted outer-[always] the kernel cannot chain —
    NON-VACUOUS under the P8 reconcile-bounded {!tightened_bound}
    (BUILD-SPEC-P8 §3.3; formerly honestly vacuous when [rv_ceiling = 2] pruned
    [Done]). Three composed {!Discharge} checks over the fair-seed reachable
    graph: (a) [Done] is REACHABLE ({!Discharge.reaches_holds},
    [post = at_done]); (b) a MATCHING [Done] is reachable
    ([post = at_done && current_state_matches]); (c) the stability invariant
    [current_state_matches s || not (at_done s)] holds at every reachable state
    ({!Discharge.invariant_holds}) — the decidable content of Anvil's
    [leads_to_always] step. Combined report: [holds] requires all three verdicts
    AND the two reaches' [frontier_emptied] explicitly (a truncated reach could
    miss a late falsifier, so a truncated graph never yields a green tail);
    [witnesses] is the [Done]-and-matches state count (MEASURED [3 > 0] at
    [desired = 1] — the positive stability evidence the vacuous tail lacked);
    [states_checked]/[frontier_emptied] come from the invariant leg. Recorded,
    NOT folded into {!esr_derivation}. HONEST LIMIT: witnesses the single-pass
    ([reconcile_ceiling = 1]) first-scale-up slice settling to the match and
    staying there — decisive only relative to these ceilings (arch §4), nothing
    of Anvil's unbounded theorem, and nothing about steady-state re-reconcile
    (P7's unbounded executable spine witnesses that operationally). *)
let[@warning "-16"] tail_matches_is_stable ?(bound = tightened_bound) ~desired :
    Discharge.edge_report =
  let init = Scenario.seed ~desired ~fair:true in
  let done_reached =
    Discharge.reaches_holds bound Scenario.cluster ~init ~pre:at_done
      ~post:at_done
  in
  let matched_done s = at_done s && current_state_matches ~desired s in
  let match_reached =
    Discharge.reaches_holds bound Scenario.cluster ~init ~pre:matched_done
      ~post:matched_done
  in
  let stability =
    Discharge.invariant_holds bound Scenario.cluster ~init
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

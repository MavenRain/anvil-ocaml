(* BUILD-SPEC-P6 §5 bullet 3 — [t_p6_vrs_liveness], THE HEADLINE.

   The assembled ESR liveness skeleton for [desired = 1], corrected shape
   (BUILD-SPEC-P6 §4.5/§4.6): [edges] is the reconcile BODY only — the four
   step-to-step [wf1]s [Init -> After_list_pods -> at_creating ->
   After_update_vrs_status -> Done] — while the scheduling FRONT ([always
   desired ~> at Init]) and the [Done ~> matches] TAIL are discharged inside
   [esr_derivation] as reachability / invariant, NOT as [wf1] edges (a [wf1] on
   the cyclic scheduling step correctly fails its [drives]: the P6 self-catch).

   - [edges ~desired:1] is [Ok] with the FOUR body edges;
   - EVERY edge's [report.witnesses > 0] (non-vacuity — asserted PER EDGE, so no
     edge is discharged over an antecedent the bounded graph never reaches),
     and each edge's [report.holds] and [report.frontier_emptied];
   - [esr_derivation ~desired:1] is [Ok] (front reachability + tail invariant
     discharged, every middle matched by {!Comp_cat.Temporal.equal});
   - [matches_esr_statement ~desired:1] is [Ok true];
   - [Rule.goal_of] the derivation {!Comp_cat.Temporal.equal}s
     {!Vrs_liveness.esr_statement_core} (the independent cross-lock);
   - [tail_matches_is_stable] has [holds = true] and [witnesses > 0] (the bounded
     evidence for the trusted outer-[always]).

   Convention firewall: no loop keywords, no [_ ->] wildcard, [Result.fold] for
   results. *)

module Vl = Anvil_proof.Vrs_liveness
module Dis = Anvil_proof.Discharge

let desired = 1

(* The frozen [.mli] shape [?bound -> desired:int -> t] leaves [?bound]
   un-erasable when only [~desired] is applied, so every call passes [~bound]
   explicitly (its value IS the default {!Vrs_liveness.tightened_bound}). *)
let bound : Bound.t = Vl.tightened_bound

(* Extract the edge list, defaulting to [] on [Error] (the [edges Ok] assertion
   below catches an actual [Error]; this only keeps the per-edge fold total). *)
let edges_list : Vl.edge list =
  Result.fold ~ok:Fun.id ~error:(fun _ -> []) (Vl.edges ~bound ~desired)

let edges_ok : bool =
  Result.fold ~ok:(fun _ -> true) ~error:(fun _ -> false) (Vl.edges ~bound ~desired)

(* The four reconcile-BODY edges, in skeleton order. *)
let expected_names =
  [
    "lemma_init_to_after_list_pods";
    "lemma_after_list_to_create";
    "lemma_create_to_after_update_status";
    "lemma_after_update_status_to_done";
  ]

(* ---- (1) edges is Ok with the four named body edges ---- *)

let test_edges_ok () =
  Alcotest.(check bool) "edges ~desired:1 is Ok" true edges_ok;
  Alcotest.(check int) "edges: exactly 4 body edges" 4 (List.length edges_list);
  Alcotest.(check (list string)) "edges: names in skeleton order" expected_names
    (List.map (fun (e : Vl.edge) -> e.name) edges_list)

(* ---- (2) EVERY edge non-vacuous: report.witnesses > 0 (asserted per edge) ---- *)

let test_every_edge_nonvacuous () =
  (* Guard: the fold below is only meaningful over a non-empty edge list. *)
  Alcotest.(check bool) "edges present for per-edge non-vacuity" true
    (List.length edges_list > 0);
  List.iter
    (fun (e : Vl.edge) ->
      Alcotest.(check bool)
        (Printf.sprintf "edge %s: report.witnesses > 0 (non-vacuous)" e.name)
        true
        (e.report.Dis.witnesses > 0);
      Alcotest.(check bool)
        (Printf.sprintf "edge %s: report.holds" e.name)
        true e.report.Dis.holds;
      Alcotest.(check bool)
        (Printf.sprintf "edge %s: report.frontier_emptied" e.name)
        true e.report.Dis.frontier_emptied)
    edges_list

(* ---- (3) esr_derivation is Ok ---- *)

let test_derivation_ok () =
  Alcotest.(check bool) "esr_derivation ~desired:1 is Ok" true
    (Result.fold ~ok:(fun _ -> true) ~error:(fun _ -> false)
       (Vl.esr_derivation ~bound ~desired))

(* ---- (4) matches_esr_statement is Ok true ---- *)

let test_matches_statement () =
  Alcotest.(check bool) "matches_esr_statement ~desired:1 is Ok true" true
    (Result.fold ~ok:Fun.id ~error:(fun _ -> false) (Vl.matches_esr_statement ~bound ~desired))

(* ---- (5) goal_of derivation Temporal.equal esr_statement_core ---- *)

let test_goal_equals_core () =
  let equal_goal =
    Result.fold ~error:(fun _ -> false)
      ~ok:(fun fact ->
        Comp_cat.Temporal.equal
          (Comp_cat.Rule.goal_of fact)
          (Vl.esr_statement_core ~desired))
      (Vl.esr_derivation ~bound ~desired)
  in
  Alcotest.(check bool)
    "goal_of derivation Temporal.equal esr_statement_core (cross-lock)" true
    equal_goal

(* ---- (6) tail_matches_is_stable: holds && witnesses > 0 ---- *)

let test_tail_stable () =
  let r = Vl.tail_matches_is_stable ~bound ~desired in
  Alcotest.(check bool) "tail_matches_is_stable: holds" true r.Dis.holds;
  Alcotest.(check bool) "tail_matches_is_stable: witnesses > 0" true (r.Dis.witnesses > 0);
  Alcotest.(check bool) "tail_matches_is_stable: frontier_emptied" true r.Dis.frontier_emptied

(* ---- (7) MEASURED reachability witness counts (P8 non-vacuity surface) ----

   Since P8 (BUILD-SPEC-P8 §3.3) [tightened_bound] is RECONCILE-bounded:
   [reconcile_ceiling = 1] excludes the second reconcile invocation (the
   create-skip pass whose successor genuinely violated e2's closure at
   [rv >= 3]), which lets [rv_ceiling] rise to 4 so the single pass reaches
   [Done]. Asserting the EXACT measured counts keeps the non-vacuity VISIBLE
   rather than assumed ([[feedback-workflow-zero-findings-may-be-vacuous]]):
   the front, e1/e2/e3 AND e4/tail milestones now all have POSITIVE witnesses —
   [Done = 3] and [current_state_matches = 9], formerly the honest-vacuity
   zeros this test recorded under the P6 [rv_ceiling = 2] bound. Numbers
   MEASURED on this 23-state graph (deterministic; no randomness in
   {!Scenario}). Honest limit: the bounded FIRST-pass slice only (one reconcile
   invocation from the empty cluster); steady-state cycles are out of scope. *)

module Mc = Anvil_checker.Model_check
module Cc = Anvil_checker.Cluster_check
module Sv = Anvil_proof.Step_view
module Invariants = Anvil_assurance.Invariants
module Scenario = Anvil_assurance.Scenario

let controller_id = Scenario.controller_id
let cr_key = Scenario.vrs_ref
let cluster : Cluster.t = Scenario.cluster
let seed : Cluster.cluster_state = Scenario.seed ~desired ~fair:true

(* The index-erased create phase (7 reconcile arms enumerated, no wildcard). *)
let is_after_create_pod (step : Vreplica_set_reconciler.step) : bool =
  match step with
  | After_create_pod _ -> true
  | Init | After_list_pods | After_delete_pod _ | After_update_vrs_status | Done
  | Error ->
    false

let reachable =
  Mc.explore ~depth:64
    ~successors:(Cc.bounded_successors bound cluster)
    ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ seed ]

let count p = Mc.count_states_where reachable p
let at step = Sv.at_step ~controller_id ~cr_key step
let at_creating = Sv.at_phase ~controller_id ~cr_key is_after_create_pod
let csm = (Invariants.liveness_goal ~cr:(Scenario.vrs ~desired)).holds

let test_measured_witness_counts () =
  (* graph shape: fully explored, decisive. *)
  Alcotest.(check int) "reachable states = 23" 23 (Mc.states_seen reachable);
  Alcotest.(check bool) "frontier emptied (decisive)" true
    (Mc.frontier_emptied reachable);
  (* front + e1/e2/e3: pre AND post milestones reached -> POSITIVE witnesses. *)
  Alcotest.(check int) "at Init reached (front / e1 pre) = 2" 2
    (count (at Vreplica_set_reconciler.Init));
  Alcotest.(check int) "at After_list_pods reached (e1 post / e2 pre) = 4" 4
    (count (at Vreplica_set_reconciler.After_list_pods));
  Alcotest.(check int) "at After_create_pod _ reached (e2 post / e3 pre) = 4" 4
    (count at_creating);
  Alcotest.(check int) "at After_update_vrs_status reached (e3 post / e4 pre) = 5"
    5 (count (at Vreplica_set_reconciler.After_update_vrs_status));
  Alcotest.(check bool) "front + e1/e2/e3 milestones all non-vacuous (> 0)" true
    (count (at Vreplica_set_reconciler.Init) > 0
    && count (at Vreplica_set_reconciler.After_list_pods) > 0
    && count at_creating > 0
    && count (at Vreplica_set_reconciler.After_update_vrs_status) > 0);
  (* e4 post ([Done]) and the match: POSITIVE since P8 (reconcile_ceiling = 1
     admits rv_ceiling = 4, so the single pass reaches Done) -> the tail /
     e4-drives are discharged NON-vacuously. *)
  Alcotest.(check int) "at Done reached = 3 (P8: single pass reaches Done)" 3
    (count (at Vreplica_set_reconciler.Done));
  Alcotest.(check int)
    "current_state_matches reached = 9 (positive tail witnesses)" 9 (count csm);
  Alcotest.(check bool) "tail milestones non-vacuous (> 0)" true
    (count (at Vreplica_set_reconciler.Done) > 0 && count csm > 0)

let () =
  Alcotest.run "p6_vrs_liveness"
    [
      ("edges_ok", [ Alcotest.test_case "edges Ok with 4 named body edges" `Quick test_edges_ok ]);
      ("every_edge_nonvacuous", [ Alcotest.test_case "per-edge witnesses > 0" `Quick test_every_edge_nonvacuous ]);
      ("derivation_ok", [ Alcotest.test_case "esr_derivation Ok" `Quick test_derivation_ok ]);
      ("matches_statement", [ Alcotest.test_case "matches_esr_statement Ok true" `Quick test_matches_statement ]);
      ("goal_equals_core", [ Alcotest.test_case "goal_of == esr_statement_core" `Quick test_goal_equals_core ]);
      ("tail_stable", [ Alcotest.test_case "tail_matches_is_stable holds & non-vacuous" `Quick test_tail_stable ]);
      ("measured_witness_counts", [ Alcotest.test_case "MEASURED reachability counts (P8 non-vacuity surface)" `Quick test_measured_witness_counts ]);
    ]

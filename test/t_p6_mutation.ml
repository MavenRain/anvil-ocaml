(* BUILD-SPEC-P6 §5 bullet 4 — [t_p6_mutation], CONFIRM-BY-MUTATION
   ([[feedback-confirm-tests-by-mutation]]).

   A green derivation is worthless unless every load-bearing check is SEEN to turn
   red under a deliberate corruption. Each mutation here is a local, in-test
   alternate predicate / ordering / statement — NOTHING in the source tree is
   edited, so there is nothing to restore
   ([[feedback-review-agents-may-leave-mutations]]). Each test asserts BOTH the
   green baseline and the red mutant, so the flip is exhibited.

   M1  wrong [post] on a real edge (e2's post -> [at Done]) makes the edge's
       [drives]/[closure] discharge FAIL, so its [obligation] is [Error] — the
       discharge is what would flip [edges] (hence [esr_derivation]) to [Error].
   M2  the REAL body edges ([Vrs_liveness.edges ~desired:1], which IS [Ok])
       chained by [leads_to_trans] in CORRECT skeleton order build [Ok] (assembled
       goal [at Init ~> at Done]); swapping e2/e3 breaks a {!Comp_cat.Temporal.
       equal} middle -> [Err.Ill_formed]. Exercises the real discharged edges, not
       synthetic self-loops.
   M3  [Vrs_liveness.matches_esr_statement ~desired:1] is [Ok true] (intact) and
       the REAL derivation goal ([goal_of (esr_derivation ~desired:1)]) is
       [Temporal.equal] to [esr_statement_core] but NOT to a wrong-TARGET statement
       ([at Init ~> current_state_matches]) — the goal-equality cross-lock rejects a
       corrupted target.
   M4  neuter the discharge (an [obligation] that ignores the report and returns
       [Ok true]) -> a KNOWN-bad report that the real [obligation] rejects now
       "builds" — proving [Discharge.obligation] is load-bearing.

   Convention firewall: no loop keywords, no [_ ->] wildcard (12-arm [Step.t]
   enumerated), [Result.fold]/[Option.fold] for results/options. *)

module Vl = Anvil_proof.Vrs_liveness
module Dis = Anvil_proof.Discharge
module Sv = Anvil_proof.Step_view
module Scenario = Anvil_assurance.Scenario

let desired = 1
let controller_id = Scenario.controller_id
let cr_key = Scenario.vrs_ref
let bound : Bound.t = Vl.tightened_bound
let cluster : Cluster.t = Scenario.cluster
let init : Cluster.cluster_state = Scenario.seed ~desired ~fair:true

let is_ok_bool (r : bool Comp_cat.Res.t) : bool =
  Result.fold ~ok:(fun _ -> true) ~error:(fun _ -> false) r

let is_ok_fact (r : Cluster.cluster_state Comp_cat.Rule.fact Comp_cat.Res.t) : bool =
  Result.fold ~ok:(fun _ -> true) ~error:(fun _ -> false) r

(* The reconcile-advancing controller label for this cr (all 12 [Step.t] arms
   enumerated, no wildcard). *)
let controller_label (step : Step.t) : bool =
  match step with
  | Controller_step (cid, _, kopt) ->
    Int.equal cid controller_id
    && Option.fold kopt ~none:false ~some:(fun k -> Common.equal_object_ref k cr_key)
  | Api_server_step _ | Builtin_controllers_step _
  | Schedule_controller_reconcile_step _ | Restart_controller_step _
  | Disable_crash_step _ | Drop_req_step _ | Disable_req_drop_step
  | Pod_monkey_step _ | Disable_pod_monkey_step | External_step _ | Stutter_step ->
    false

(* The index-erased create phase (7 reconcile arms enumerated, no wildcard). *)
let is_after_create_pod (step : Vreplica_set_reconciler.step) : bool =
  match step with
  | After_create_pod _ -> true
  | Init | After_list_pods | After_delete_pod _ | After_update_vrs_status | Done
  | Error ->
    false

(* Edge e2's real pre/post and the wrong (mutated) post. *)
let pre_list = Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.After_list_pods
let post_creating = Sv.at_phase ~controller_id ~cr_key is_after_create_pod
let post_wrong = Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Done

(* ======================================================================== *)
(* M1: wrong post on edge e2 -> discharge FAILS -> obligation Error            *)
(* ======================================================================== *)

let test_m1_wrong_post () =
  (* baseline (green): the correct post discharges. *)
  let d_ok =
    Dis.drives_holds bound cluster ~init ~pre:pre_list ~forward:controller_label
      ~post:post_creating
  in
  Alcotest.(check bool) "M1 baseline: correct post drives holds" true d_ok.Dis.holds;
  Alcotest.(check bool) "M1 baseline: correct post obligation Ok" true
    (is_ok_bool (Dis.obligation d_ok));
  (* mutant (red): post = at Done makes the forward-labelled successor
     (at some After_create_pod) escape post. *)
  let d_bad =
    Dis.drives_holds bound cluster ~init ~pre:pre_list ~forward:controller_label
      ~post:post_wrong
  in
  Alcotest.(check bool) "M1 mutant: wrong post drives holds=false" false d_bad.Dis.holds;
  Alcotest.(check bool) "M1 mutant: wrong post obligation Error" false
    (is_ok_bool (Dis.obligation d_bad));
  (* and the closure obligation likewise flips (the edges/derivation gate). *)
  let c_bad = Dis.closure_holds bound cluster ~init ~pre:pre_list ~post:post_wrong in
  Alcotest.(check bool) "M1 mutant: wrong post closure holds=false" false c_bad.Dis.holds;
  Alcotest.(check bool) "M1 mutant: wrong post closure obligation Error" false
    (is_ok_bool (Dis.obligation c_bad))

(* ======================================================================== *)
(* M2: leads_to_trans middle-matching is load-bearing (reorder -> Error)        *)
(* ======================================================================== *)

(* Shared helpers for M2/M3, built on the REAL derivation (no synthetic
   self-loops): the four discharged body-edge facts in skeleton order, a
   right-fold chain over [leads_to_trans], and a 2nd/3rd swap. [Vl.edges
   ~desired:1] IS [Ok] with 4 facts, so [real_facts] has length 4 and [swap_23]
   always fires (asserted in M2). *)
let real_facts : Cluster.cluster_state Comp_cat.Rule.fact list =
  Result.fold ~error:(fun _ -> [])
    ~ok:(List.map (fun (e : Vl.edge) -> e.fact))
    (Vl.edges ~bound ~desired)

(* Chain a fact list by [leads_to_trans] right-to-left: [f0 ~> (f1 ~> (... fn))].
   Exhaustive list match ([] / cons), no wildcard; [Result.bind] threads the
   short-circuit so a mismatched middle yields [Err.Ill_formed]. *)
let chain (facts : Cluster.cluster_state Comp_cat.Rule.fact list) :
    Cluster.cluster_state Comp_cat.Rule.fact Comp_cat.Res.t =
  match List.rev facts with
  | [] ->
    Error
      (Comp_cat.Err.Ill_formed { fn = "t_p6_mutation.chain"; why = "empty chain" })
  | last :: rest_rev ->
    List.fold_left
      (fun acc f -> Result.bind acc (fun a -> Comp_cat.Rule.leads_to_trans f a))
      (Ok last) rest_rev

(* Swap the 2nd and 3rd elements ([e2]/[e3]). Named catch-all [other], NOT a
   wildcard [_ ->]; shorter lists pass through (the length-4 assertion guards). *)
let swap_23 (facts : 'a list) : 'a list =
  match facts with
  | a :: b :: c :: d :: rest -> a :: c :: b :: d :: rest
  | other -> other

let test_m2_reorder () =
  (* baseline: [edges ~desired:1] gives the FOUR real body-edge facts. *)
  Alcotest.(check int) "M2 baseline: edges gives 4 real body facts" 4
    (List.length real_facts);
  (* baseline (green): the REAL edges chained in CORRECT order build [Ok], and the
     assembled goal is exactly [at Init ~> at Done] — so the chain touched the real
     discharged body edges, not synthetic self-loops. *)
  let correct = chain real_facts in
  Alcotest.(check bool) "M2 baseline: correct-order real body chain is Ok" true
    (is_ok_fact correct);
  Alcotest.(check bool) "M2 baseline: chained goal is (at Init ~> at Done)" true
    (Result.fold ~error:(fun _ -> false)
       ~ok:(fun fact ->
         Comp_cat.Temporal.equal
           (Comp_cat.Rule.goal_of fact)
           (Comp_cat.Temporal.leads_to
              (Vl.f_at Vreplica_set_reconciler.Init)
              (Vl.f_at Vreplica_set_reconciler.Done)))
       correct);
  (* mutant (red flip): swapping e2/e3 breaks a [leads_to_trans] middle
     ([at_creating] vs [After_update_vrs_status]) -> [Err.Ill_formed]. *)
  let swapped = chain (swap_23 real_facts) in
  Alcotest.(check bool) "M2 mutant: swapped-order real body chain is Error" true
    (not (is_ok_fact swapped))

(* ======================================================================== *)
(* M3: goal-equality cross-lock is load-bearing (wrong target -> not equal)     *)
(* ======================================================================== *)

let test_m3_wrong_target () =
  (* baseline: the headline cross-lock on the REAL derivation is intact. *)
  Alcotest.(check bool) "M3 baseline: matches_esr_statement ~desired:1 is Ok true"
    true
    (Result.fold ~ok:Fun.id ~error:(fun _ -> false)
       (Vl.matches_esr_statement ~bound ~desired));
  (* the REAL derivation goal ([None] only if the derivation failed — caught by the
     baseline above). *)
  let real_goal =
    Result.fold ~error:(fun _ -> None)
      ~ok:(fun fact -> Some (Comp_cat.Rule.goal_of fact))
      (Vl.esr_derivation ~bound ~desired)
  in
  let correct_stmt = Vl.esr_statement_core ~desired in
  (* a WRONG-TARGET statement: [at Init ~> current_state_matches] (wrong
     antecedent — not [always desired_state_is]). *)
  let wrong_stmt =
    Comp_cat.Temporal.leads_to
      (Vl.f_at Vreplica_set_reconciler.Init)
      (Vl.f_current_state_matches ~desired)
  in
  (* baseline (green): the real goal Temporal.equals [esr_statement_core]. *)
  Alcotest.(check bool) "M3 baseline: real goal Temporal.equal esr_statement_core"
    true
    (Option.fold ~none:false
       ~some:(fun g -> Comp_cat.Temporal.equal g correct_stmt)
       real_goal);
  (* mutant (red flip): against the wrong-TARGET statement the cross-lock equality
     is false — a corrupted ESR statement is rejected. *)
  Alcotest.(check bool)
    "M3 mutant: real goal NOT Temporal.equal a wrong-target statement" false
    (Option.fold ~none:false
       ~some:(fun g -> Comp_cat.Temporal.equal g wrong_stmt)
       real_goal)

(* ======================================================================== *)
(* M4: neuter the discharge -> a known-bad report now "builds"                  *)
(* ======================================================================== *)

(* A genuinely-bad edge report (violated: holds=false), exactly what a wrong-post
   discharge produces. *)
let bad_report : Dis.edge_report =
  Dis.closure_holds bound cluster ~init ~pre:pre_list ~post:post_wrong

(* The neutered discharge: ignores the report, always accepts — the mutation. *)
let neutered_obligation (_ : Dis.edge_report) : bool Comp_cat.Res.t = Ok true

let test_m4_neuter_discharge () =
  Alcotest.(check bool) "M4: the bad report genuinely does not hold" false bad_report.Dis.holds;
  (* baseline (green): the REAL discharge rejects the bad edge. *)
  Alcotest.(check bool) "M4 baseline: real obligation REJECTS the bad edge (Error)" false
    (is_ok_bool (Dis.obligation bad_report));
  (* mutant (red): neutered discharge ACCEPTS it -> a known-bad edge would build,
     proving Discharge.obligation is load-bearing. *)
  Alcotest.(check bool) "M4 mutant: neutered obligation ACCEPTS the bad edge (Ok)" true
    (is_ok_bool (neutered_obligation bad_report))

let () =
  Alcotest.run "p6_mutation"
    [
      ("M1_wrong_post", [ Alcotest.test_case "wrong edge post -> discharge Error" `Quick test_m1_wrong_post ]);
      ("M2_reorder", [ Alcotest.test_case "reordered chain -> leads_to_trans Error" `Quick test_m2_reorder ]);
      ("M3_wrong_target", [ Alcotest.test_case "wrong esr target -> goal not equal" `Quick test_m3_wrong_target ]);
      ("M4_neuter_discharge", [ Alcotest.test_case "neutered discharge accepts a bad edge" `Quick test_m4_neuter_discharge ]);
    ]

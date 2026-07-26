(* BUILD-SPEC-P11 §7 / §8 "t_p11_vsts_liveness" — the VStatefulSet ESR liveness
   skeleton witness: the {!Vsts_liveness} derivation type-checks + assembles to
   exactly the ESR core ([matches_esr_statement] true), and the MEASURED
   per-milestone reachable-state counts are PINNED (vacuity made VISIBLE).

   MEASURED-AND-PINNED (desired = 1, vct:false, the §7.2 settling bound, depth 40,
   the fair:true reachable graph = the SAME 20-state graph the settled ESR gate
   ranges over in t_p11_vsts_esr, [gate_states = Some 1]):

   - the body trajectory is the MEASURED single-step chain (NOT the BUILD-SPEC §7.1
     3-edge sketch — corrected by measurement, "MEASURE, do not tune"):
       Init(2) -> After_list_pod(4) -> Create_needed(2) -> After_create_needed(4)
                -> Delete_outdated(2) -> Done(2).
     [Create_needed]/[After_create_needed] are two SEQUENTIAL controller steps (a
     single-step wf1.drives cannot span them as one phase PRE); a fresh create
     still traverses the [Delete_outdated] scan, which finds nothing and steps
     straight to [Done] ([After_delete_outdated] = 0). VSTS reconcile_core writes
     no status, so there is no status-update milestone.
   - EVERY milestone count is POSITIVE — the tail is NON-VACUOUS: [current_state_
     matches] = 8, and BOTH [Done] states match ([Done && match] = 2,
     [Done && not match] = 0). [tail_matches_is_stable] holds with [witnesses = 2]
     over the frontier-emptied 20-state graph — positive settled-match evidence.

   HONEST LIMITS (BUILD-SPEC-P11 §10): every verdict is falsification-up-to
   (depth, {!Bound.t}); the skeleton witnesses ONE reconcile invocation from a
   fresh cluster reaching the ordinal-stable match, never the perpetual
   re-reconcile / multi-round rolling update (those are P7/P10's operational
   spine, vct:true). The wf1 omega-induction is trusted-on-stream.

   Convention: no loop keywords (List.for_all); no [_ ->] wildcard (the create-
   phase predicate lists all 17 [step] arms); Option/Result folds, [Int.equal]. *)

module Vl = Anvil_proof.Vsts_liveness
module Sv = Anvil_proof.Vsts_step_view
module D = Anvil_proof.Discharge
module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Vi = Anvil_assurance.Vsts_invariants
module R = V_stateful_set_reconciler

let desired = 1
let depth = 40
let bound = Vl.settling_bound
let controller_id = Scenario.controller_id
let cr_key = Scenario.vsts_ref

(* the fair:true reachable graph at the settling bound *)
let reach =
  let seed = Scenario.vsts_seed ~desired ~fair:true in
  Mc.explore ~depth
    ~successors:(Cc.bounded_successors bound Scenario.vsts_cluster)
    ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ seed ]

let count p = Mc.count_states_where reach p
let at (st : R.step) s = Sv.at_step ~controller_id ~cr_key st s
let matches s = Vi.current_state_matches (Scenario.vsts ~desired ()) s

(* the create-pod phase (2 arms of the 17-arm sum; all arms enumerated) *)
let is_create_phase (step : R.step) : bool =
  match step with
  | Create_needed | After_create_needed -> true
  | Init | After_list_pod | Get_pvc | After_get_pvc | Create_pvc
  | After_create_pvc | Skip_pvc | Update_needed | After_update_needed
  | Delete_condemned | After_delete_condemned | Delete_outdated
  | After_delete_outdated | Done | Error ->
    false

let is_ok_true (r : bool Comp_cat.Res.t) : bool =
  Result.fold r ~ok:(fun b -> b) ~error:(fun _ -> false)

(* ---- (1) the P11 headline: the machine-assembled, per-edge-discharged
   derivation equals exactly the ESR core statement. ---- *)

let test_matches_esr_statement () =
  Alcotest.(check bool) "matches_esr_statement ~desired:1 = Ok true" true
    (is_ok_true (Vl.matches_esr_statement ~bound ~desired))

(* ---- (2) the 5 body edges all discharge with POSITIVE (non-vacuous) witnesses;
   the whole derivation is Ok (front reachability + tail invariant discharged). ---- *)

let test_edges_discharge_nonvacuous () =
  Alcotest.(check bool) "esr_derivation ~desired:1 is Ok" true
    (Result.fold (Vl.esr_derivation ~bound ~desired)
       ~ok:(fun _ -> true) ~error:(fun _ -> false));
  Result.fold (Vl.edges ~bound ~desired)
    ~ok:(fun es ->
      Alcotest.(check int) "5 body edges" 5 (List.length es);
      Alcotest.(check bool) "every edge holds with witnesses > 0" true
        (List.for_all
           (fun (e : Vl.edge) -> e.report.D.holds && e.report.D.witnesses > 0)
           es))
    ~error:(fun _ -> Alcotest.fail "edges = Error (an edge failed to discharge)")

(* ---- (3) MEASURE + PIN the per-milestone reachable-state counts. The graph is
   the SAME 20-state fair:true graph as t_p11_vsts_esr. Every count POSITIVE — the
   tail is NON-VACUOUS (no honest-0 disclosure needed at this bound). ---- *)

let test_milestone_counts_pinned () =
  Alcotest.(check int) "reachable-state count = 20 (MEASURED, matches esr suite)"
    20 (Mc.states_seen reach);
  Alcotest.(check int) "at Init = 2 (MEASURED)" 2 (count (at R.Init));
  Alcotest.(check int) "at After_list_pod = 4 (MEASURED)" 4
    (count (at R.After_list_pod));
  Alcotest.(check int) "at Create_needed = 2 (MEASURED)" 2
    (count (at R.Create_needed));
  Alcotest.(check int) "at After_create_needed = 4 (MEASURED)" 4
    (count (at R.After_create_needed));
  Alcotest.(check int) "at create-phase = 6 (MEASURED)" 6
    (count (Sv.at_phase ~controller_id ~cr_key is_create_phase));
  Alcotest.(check int) "at Delete_outdated = 2 (MEASURED)" 2
    (count (at R.Delete_outdated));
  Alcotest.(check int) "at After_delete_outdated = 0 (scan steps direct to Done)"
    0 (count (at R.After_delete_outdated));
  Alcotest.(check int) "at Done = 2 (MEASURED)" 2 (count (at R.Done));
  Alcotest.(check int) "current_state_matches = 8 (MEASURED — POSITIVE, tail non-vacuous)"
    8 (count matches)

(* ---- (4) the tail (the trusted outer-[always] evidence) is NON-VACUOUS: both
   reachable [Done] states satisfy the match, and [tail_matches_is_stable] holds
   over the frontier-emptied graph with positive witnesses. ---- *)

let test_tail_nonvacuous () =
  Alcotest.(check int) "Done AND match = 2 (both Done states converge)" 2
    (count (fun s -> at R.Done s && matches s));
  Alcotest.(check int) "Done AND NOT match = 0 (no non-converged Done)" 0
    (count (fun s -> at R.Done s && not (matches s)));
  let r = Vl.tail_matches_is_stable ~bound ~desired in
  Alcotest.(check bool) "tail_matches_is_stable holds" true r.D.holds;
  Alcotest.(check int) "tail witnesses = 2 (MEASURED, POSITIVE)" 2 r.D.witnesses;
  Alcotest.(check bool) "tail frontier emptied (decisive on bounded graph)" true
    r.D.frontier_emptied;
  Alcotest.(check int) "tail states_checked = 20 (MEASURED)" 20 r.D.states_checked

let () =
  Alcotest.run "p11_vsts_liveness"
    [
      ( "derivation",
        [
          Alcotest.test_case "matches_esr_statement true" `Quick
            test_matches_esr_statement;
          Alcotest.test_case "5 edges discharge, witnesses > 0" `Quick
            test_edges_discharge_nonvacuous;
        ] );
      ( "milestones",
        [
          Alcotest.test_case
            "per-milestone reachable-state counts pinned (all POSITIVE)" `Quick
            test_milestone_counts_pinned;
        ] );
      ( "tail",
        [
          Alcotest.test_case "tail non-vacuous: both Done states match, stable"
            `Quick test_tail_nonvacuous;
        ] );
    ]

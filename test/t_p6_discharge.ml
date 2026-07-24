(* BUILD-SPEC-P6 §5 bullet 2 — [t_p6_discharge].

   The P5 bridge {!Discharge} turns a wf1 / invariant edge's operational
   side-condition into a bounded-model-checker verdict. On a REAL edge of the
   [desired = 1] skeleton (the [Init -> After_list_pods] step) under
   {!Vrs_liveness.tightened_bound}:

   - [closure_holds] / [drives_holds] / [invariant_holds] / [reaches_holds] all
     return [holds = true] with [witnesses > 0] and [frontier_emptied = true], and
     [obligation] is [Ok true];
   - a deliberately-wrong [post] ([fun _ -> false]) gives [holds = false] so
     [obligation] is [Error] (the VIOLATION guard);
   - a [pre] never reached ([fun _ -> false]) gives [witnesses = 0] so [obligation]
     is [Error] (the VACUITY guard) even though [holds] is trivially [true].

   Convention firewall: no loop keywords, no [_ ->] wildcard (the 12-arm [Step.t]
   [controller_label] is fully enumerated), [Result.fold] for results. *)

module Dis = Anvil_proof.Discharge
module Sv = Anvil_proof.Step_view
module Vl = Anvil_proof.Vrs_liveness
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants

let desired = 1
let controller_id = Scenario.controller_id
let cr_key = Scenario.vrs_ref
let bound : Bound.t = Vl.tightened_bound
let cluster : Cluster.t = Scenario.cluster
let init : Cluster.cluster_state = Scenario.seed ~desired ~fair:true

(* [Ok _ -> true], [Error _ -> false] without a two-arm result match. *)
let is_ok (r : bool Comp_cat.Res.t) : bool =
  Result.fold ~ok:(fun _ -> true) ~error:(fun _ -> false) r

(* The real edge's [pre]/[post] milestone predicates (edge e1: at Init ->
   at After_list_pods). *)
let pre_init = Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Init

let post_list =
  Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.After_list_pods

(* The reconcile-advancing controller label for this cr (all 12 [Step.t] arms
   enumerated, no wildcard) — byte-identical to {!Vrs_liveness}'s internal
   [controller_label], the [forward] the [drives] obligation selects on. *)
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

(* The [Done => matches] tail invariant predicate (the same one
   {!Vrs_liveness.esr_derivation} discharges). *)
let at_done = Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Done

let current_state_matches (s : Cluster.cluster_state) : bool =
  (Invariants.liveness_goal ~cr:(Scenario.vrs ~desired)).holds s

let tail_inv (s : Cluster.cluster_state) : bool =
  (not (at_done s)) || current_state_matches s

(* A wrong post: nothing is [post], so a [pre]-state advancing to a distinct step
   escapes [pre \/ post]. *)
let false_pred (_ : Cluster.cluster_state) : bool = false

(* ---- (a) the four discharges on the REAL edge: holds/witnesses/frontier ---- *)

let test_closure_real () =
  let r = Dis.closure_holds bound cluster ~init ~pre:pre_init ~post:post_list in
  Alcotest.(check bool) "closure real: holds" true r.holds;
  Alcotest.(check bool) "closure real: witnesses > 0 (pre reached)" true (r.witnesses > 0);
  Alcotest.(check bool) "closure real: frontier_emptied" true r.frontier_emptied;
  Alcotest.(check bool) "closure real: states_checked > 0" true (r.states_checked > 0);
  Alcotest.(check bool) "closure real: obligation Ok true" true (is_ok (Dis.obligation r))

let test_drives_real () =
  let r =
    Dis.drives_holds bound cluster ~init ~pre:pre_init ~forward:controller_label
      ~post:post_list
  in
  Alcotest.(check bool) "drives real: holds" true r.holds;
  Alcotest.(check bool) "drives real: witnesses > 0" true (r.witnesses > 0);
  Alcotest.(check bool) "drives real: frontier_emptied" true r.frontier_emptied;
  Alcotest.(check bool) "drives real: obligation Ok true" true (is_ok (Dis.obligation r))

let test_invariant_real () =
  let r = Dis.invariant_holds bound cluster ~init ~inv:tail_inv in
  Alcotest.(check bool) "invariant real (Done=>matches): holds" true r.holds;
  Alcotest.(check bool) "invariant real: witnesses > 0" true (r.witnesses > 0);
  Alcotest.(check bool) "invariant real: witnesses = states_checked" true
    (Int.equal r.witnesses r.states_checked);
  Alcotest.(check bool) "invariant real: frontier_emptied" true r.frontier_emptied;
  Alcotest.(check bool) "invariant real: obligation Ok true" true (is_ok (Dis.obligation r))

let test_reaches_real () =
  (* [pre] reached (at Init) and [post] reachable (at After_list_pods) — both are
     reachable at the closing [tightened_bound] (unlike [at Done], which the
     rv-starved closing graph never reaches; see the module finding). *)
  let r = Dis.reaches_holds bound cluster ~init ~pre:pre_init ~post:post_list in
  Alcotest.(check bool) "reaches real: holds (post reachable)" true r.holds;
  Alcotest.(check bool) "reaches real: witnesses > 0 (pre reached)" true (r.witnesses > 0);
  Alcotest.(check bool) "reaches real: frontier_emptied" true r.frontier_emptied;
  Alcotest.(check bool) "reaches real: obligation Ok true" true (is_ok (Dis.obligation r))

(* ---- (b) VIOLATION: a wrong post -> holds=false -> obligation Error ---- *)

let test_wrong_post_violates () =
  let rc = Dis.closure_holds bound cluster ~init ~pre:pre_init ~post:false_pred in
  Alcotest.(check bool) "wrong post closure: holds=false" false rc.holds;
  Alcotest.(check bool) "wrong post closure: witnesses > 0 (pre still reached)" true
    (rc.witnesses > 0);
  Alcotest.(check bool) "wrong post closure: obligation Error" false (is_ok (Dis.obligation rc));
  let rd =
    Dis.drives_holds bound cluster ~init ~pre:pre_init ~forward:controller_label
      ~post:false_pred
  in
  Alcotest.(check bool) "wrong post drives: holds=false" false rd.holds;
  Alcotest.(check bool) "wrong post drives: obligation Error" false (is_ok (Dis.obligation rd))

(* ---- (c) VACUITY: a pre never reached -> witnesses=0 -> obligation Error ---- *)

let test_never_reached_pre_vacuous () =
  let r = Dis.closure_holds bound cluster ~init ~pre:false_pred ~post:post_list in
  Alcotest.(check int) "vacuous pre closure: witnesses = 0" 0 r.witnesses;
  Alcotest.(check bool) "vacuous pre closure: holds=true (trivially, no pre-state)" true r.holds;
  Alcotest.(check bool) "vacuous pre closure: frontier_emptied" true r.frontier_emptied;
  Alcotest.(check bool) "vacuous pre closure: obligation Error (VACUITY guard)" false
    (is_ok (Dis.obligation r));
  let rr = Dis.reaches_holds bound cluster ~init ~pre:false_pred ~post:at_done in
  Alcotest.(check int) "vacuous pre reaches: witnesses = 0" 0 rr.witnesses;
  Alcotest.(check bool) "vacuous pre reaches: obligation Error" false (is_ok (Dis.obligation rr))

let () =
  Alcotest.run "p6_discharge"
    [
      ("closure_real", [ Alcotest.test_case "closure holds on the real edge" `Quick test_closure_real ]);
      ("drives_real", [ Alcotest.test_case "drives holds on the real edge" `Quick test_drives_real ]);
      ("invariant_real", [ Alcotest.test_case "Done=>matches invariant holds" `Quick test_invariant_real ]);
      ("reaches_real", [ Alcotest.test_case "reaches holds on the real edge" `Quick test_reaches_real ]);
      ("wrong_post_violates", [ Alcotest.test_case "wrong post -> holds=false -> Error" `Quick test_wrong_post_violates ]);
      ("never_reached_pre_vacuous", [ Alcotest.test_case "unreached pre -> witnesses=0 -> Error" `Quick test_never_reached_pre_vacuous ]);
    ]

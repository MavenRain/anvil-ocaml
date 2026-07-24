(* BUILD-SPEC-P8 §6 "t_p8_mutation" — confirm-by-mutation for the P8 settling
   machinery. The temporary LIBRARY mutants — M1 dropping the reconcile disjunct
   from {!Cc.over_ceiling}-via-[bounded_successors], M2 making {!Cc.settled}
   unconditionally true, M3 corrupting the ESR target in [Invariants] — were
   each applied, SEEN to turn t_p8_settle red at the pinned assertion, and
   reverted; only the green pins ship. These tests are the always-on in-tree
   ANALOGUES of those mutants, mirroring t_p5_mutation's shadowed-variant style:

   - M1: a locally NEUTERED over_ceiling (uid/rv clauses only) restores the
     perpetual reschedule churn: the settled-gate count collapses to 0 (the P5
     [gate_states = Some 0] vacuity), while the REAL pruning yields > 0 — the
     reconcile disjunct is exactly what creates the settled state.
   - M2: an unconditionally-true settled gate admits NON-MATCHING states (the
     seed, mid-pass states), which t_p8_settle's "every settled state matches"
     pin rejects; the real gate admits none.
   - M3: a corrupted target (the [desired + 1] matcher) is REFUTED at the real
     settled gate, and the refuting state satisfies the REAL matcher — the gate
     is exercised at real states, non-vacuously.
   - M4: a planted-divergence detector over the settled-state produced values
     (etcd object count, reconcile count, uid/rv finals), mirroring
     t_p7_mutation's M4: the true finals show zero divergences, planted drifts
     are each detected.

   Convention firewall: no loop keywords (BFS via recursion + List folds); no
   [_ ->] wildcard (two-arm {!Mc.outcome} / list matches are exhaustive);
   Option.fold for options; [Int.equal] not [Stdlib.(=)]. *)

module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants

let desired = 1
let cluster : Cluster.t = Scenario.cluster
let fair_seed : Cluster.cluster_state = Scenario.seed ~desired ~fair:true

(* The §4 settling bound at [desired = 1] (as in t_p8_settle). *)
let settling_bound : Bound.t =
  {
    Bound.max_in_flight = 8;
    max_objects_per_kind = desired + 2;
    max_controllers = 1;
    uid_ceiling = desired + 3;
    rv_ceiling = desired + 3;
    reconcile_ceiling = 2;
    max_reconcile_depth = 16;
  }

let matches_of d = (Invariants.liveness_goal ~cr:(Scenario.vrs ~desired:d)).holds

let is_no_ce (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with Mc.No_counterexample _ -> true | Mc.Refuted _ -> false

let is_refuted (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with Mc.Refuted _ -> true | Mc.No_counterexample _ -> false

let bad_state_of (o : Cluster.cluster_state Mc.outcome) :
    Cluster.cluster_state option =
  match o with
  | Mc.No_counterexample _ -> None
  | Mc.Refuted { lasso; _ } ->
      (match Array.to_list lasso.Mc.loop with [] -> None | s :: _ -> Some s)

let real_reach (depth : int) : Cluster.cluster_state Mc.reachable =
  Mc.explore ~depth
    ~successors:(Cc.bounded_successors settling_bound cluster)
    ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ fair_seed ]

(* ---- M1: the NEUTERED over_ceiling (reconcile disjunct dropped) — the
   in-tree analogue of deleting the P8 clause from {!Cc.over_ceiling} ---- *)

let neutered_over_ceiling (b : Bound.t) (s : Cluster.cluster_state) : bool =
  s.api_server.uid_counter > b.uid_ceiling
  || s.api_server.resource_version_counter > b.rv_ceiling

let neutered_successors (b : Bound.t) (s : Cluster.cluster_state) :
    Cluster.cluster_state list =
  List.map snd
    (List.filter
       (fun (_step, s') -> not (neutered_over_ceiling b s'))
       (Cluster.enabled_successors b cluster s))

let neutered_settled (b : Bound.t) (s : Cluster.cluster_state) : bool =
  List.for_all
    (fun (_step, s') -> Cc.state_equal s s')
    (List.filter
       (fun (_step, s') -> not (neutered_over_ceiling b s'))
       (Scenario.productive_successors b s))

let test_m1_prune_neutered () =
  let neutered_reach =
    Mc.explore ~depth:20
      ~successors:(neutered_successors settling_bound)
      ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ fair_seed ]
  in
  Alcotest.(check int)
    "M1: NEUTERED pruning -> 0 settled states (the P5 vacuity returns)" 0
    (Mc.count_states_where neutered_reach (neutered_settled settling_bound));
  Alcotest.(check bool)
    "M1: REAL pruning -> settled states exist (the disjunct is load-bearing)"
    true
    (Mc.count_states_where (real_reach 30) (Cc.settled settling_bound cluster)
    > 0)

(* ---- M2: an unconditionally-true settled gate admits non-matching states —
   exactly what t_p8_settle's "every settled state matches" pin catches ---- *)

let test_m2_gate_corrupted () =
  let reach = real_reach 30 in
  let corrupt_gate (_s : Cluster.cluster_state) : bool = true in
  Alcotest.(check bool)
    "M2: corrupted (always-true) gate admits NON-MATCHING states" true
    (Mc.count_states_where reach (fun s ->
         corrupt_gate s && not (matches_of desired s))
    > 0);
  Alcotest.(check int)
    "M2: the REAL settled gate admits none (every settled state matches)" 0
    (Mc.count_states_where reach (fun s ->
         Cc.settled settling_bound cluster s && not (matches_of desired s)))

(* ---- M3: a corrupted ESR target is REFUTED at the real settled gate — the
   gate is exercised at real states, not vacuous ---- *)

let test_m3_target_corrupted () =
  let reach = real_reach 30 in
  let gate = Cc.settled settling_bound cluster in
  (* the [desired + 1] matcher: requires one more pod than the reconcile
     creates, so every settled state fails it. *)
  let corrupted_target = matches_of (desired + 1) in
  let mut =
    Mc.check_reaches reach ~target:corrupted_target ~quiescent:gate
      ~equal:Cc.state_equal
  in
  Alcotest.(check bool)
    "M3: corrupted (desired + 1) target -> REFUTED at the settled gate" true
    (is_refuted mut);
  Option.iter
    (fun (s : Cluster.cluster_state) ->
      Alcotest.(check bool)
        "M3: the refuting state is genuinely settled AND satisfies the REAL matcher"
        true
        (gate s && matches_of desired s))
    (bad_state_of mut);
  (* the same real target is CLEAN at the gate (baseline the mutant diverges
     from). *)
  Alcotest.(check bool) "M3 baseline: the REAL target is clean at the gate" true
    (is_no_ce
       (Mc.check_reaches reach ~target:(matches_of desired) ~quiescent:gate
          ~equal:Cc.state_equal))

(* ---- M4: planted-divergence detector on the settled-state produced values
   (mirrors t_p7_mutation's M4). BFS collector as in t_p8_settle — the abstract
   {!Mc.reachable} does not expose states. ---- *)

let reachable_states ~(bound : Bound.t) ~(depth : int) :
    Cluster.cluster_state list =
  let succ = Cc.bounded_successors bound cluster in
  let visited : (int, Cluster.cluster_state list) Hashtbl.t =
    Hashtbl.create 4096
  in
  let seen s =
    Hashtbl.find_opt visited (Cc.state_hash s)
    |> Option.map (List.exists (Cc.state_equal s))
    |> Option.value ~default:false
  in
  let mark s =
    let h = Cc.state_hash s in
    Hashtbl.replace visited h
      (s :: Option.value ~default:[] (Hashtbl.find_opt visited h))
  in
  let rec bfs frontier level acc =
    match frontier with
    | [] -> acc
    | _ :: _ ->
      if level >= depth then acc
      else
        let next =
          List.fold_left
            (fun fr s ->
              List.fold_left
                (fun fr s' ->
                  if Cc.state_equal s s' then fr
                  else if seen s' then fr
                  else (mark s'; s' :: fr))
                fr (succ s))
            [] frontier
        in
        bfs (List.rev next) (level + 1) (List.rev_append next acc)
  in
  let () = if not (seen fair_seed) then mark fair_seed in
  bfs [ fair_seed ] 0 [ fair_seed ]

type divergence = { field : string; expected : int; actual : int }

let field_of (d : divergence) : string = d.field

let show_div (d : divergence) : string =
  Printf.sprintf "%s: expected %d, actual %d" d.field d.expected d.actual

(* Compare each settled-state produced value against an expectation; a
   mismatch is a detected divergence. *)
let divergences ~(objects : int) ~(reconciles : int) ~(uid : int) ~(rv : int)
    (s : Cluster.cluster_state) : divergence list =
  let check name expected actual acc =
    if Int.equal expected actual then acc
    else { field = name; expected; actual } :: acc
  in
  check "etcd_objects" objects
    (Object_ref_map.cardinal (Cluster.resources s))
    (check "reconcile_id_counter" reconciles (Cc.max_reconcile_id s)
       (check "uid_counter" uid s.api_server.uid_counter
          (check "rv_counter" rv s.api_server.resource_version_counter [])))

let test_m4_planted_divergence () =
  let settled_states =
    List.filter
      (Cc.settled settling_bound cluster)
      (reachable_states ~bound:settling_bound ~depth:30)
  in
  Alcotest.(check bool) "M4: >= 1 settled state" true
    (not (settled_states = []));
  (* the TRUE finals at [desired = 1] (MEASURED): the pod + the vrs in etcd;
     both passes ran; uid_counter 3 (the allocator's NEXT uid after vrs, pod);
     rv 3 (seed write, create, status). *)
  let all_divs =
    List.concat_map
      (divergences ~objects:(desired + 1) ~reconciles:2 ~uid:3 ~rv:3)
      settled_states
  in
  (match all_divs with
  | [] -> ()
  | _ :: _ ->
      Alcotest.failf "M4: true finals diverged — %s"
        (String.concat "; " (List.map show_div all_divs)));
  (* plant a drift in EACH value: every planted field is detected. *)
  Alcotest.(check bool) "M4: planted drifts -> each of the 4 fields detected"
    true
    (List.for_all
       (fun s ->
         let detected =
           List.map field_of
             (divergences ~objects:(desired + 2) ~reconciles:3 ~uid:4 ~rv:4 s)
         in
         List.for_all
           (fun f -> List.exists (String.equal f) detected)
           [ "etcd_objects"; "reconcile_id_counter"; "uid_counter"; "rv_counter" ])
       settled_states)

let () =
  Alcotest.run "p8_mutation"
    [
      ( "confirm-by-mutation",
        [
          Alcotest.test_case
            "M1: neutered over_ceiling -> vacuity returns; real -> settled" `Quick
            test_m1_prune_neutered;
          Alcotest.test_case
            "M2: always-true gate admits non-matching; real gate none" `Quick
            test_m2_gate_corrupted;
          Alcotest.test_case
            "M3: corrupted target REFUTED at the settled gate" `Quick
            test_m3_target_corrupted;
          Alcotest.test_case
            "M4: planted divergence on settled finals detected" `Quick
            test_m4_planted_divergence;
        ] );
    ]

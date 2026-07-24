(* BUILD-SPEC-P8 §5 "t_p8_settle" — the P8 settling-state suite. Under the §4
   settling bound ([reconcile_ceiling = 2]) the reconcile-bounded settled [Done]
   is REACHABLE and MATCHING (test 1), {!Cluster_check.check_esr_settled} is
   decisively NON-VACUOUS — [gate_states = Some n], [n > 0], the vacuity P5/P6
   shipped with resolved (test 2) — and the [reconcile_ceiling] is LOAD-BEARING:
   raising it to a perpetual value reproduces the P5 [Some 0] vacuity, proving
   the ceiling (not a fluke of the scenario) creates the settled state (test 3).
   Test 4 pins the exact MEASURED settled-state shape; test 5 re-asserts the P6
   tail non-vacuity from the consumer side; test 6 checks the new pruning admits
   no false safety counterexample.

   HONEST LIMIT (BUILD-SPEC-P8 §7): all of this witnesses a BOUNDED number of
   reconcile invocations settling to the match and staying there — never the
   perpetual re-reconcile, which P7's unbounded executable spine witnesses
   operationally. [decisive] is relative to these ceilings (arch §4).

   Convention firewall: no loop keywords (BFS via recursion + List folds); no
   [_ ->] wildcard (only the exhaustive two-arm {!Model_check.outcome} and list
   [[] | _ :: _]); Option.fold for options; [Int.equal] not [Stdlib.(=)]. *)

module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vl = Anvil_proof.Vrs_liveness
module Dis = Anvil_proof.Discharge

(* The §4 settling bound: pass 1 reaches the match (reachability leg); pass 2
   (find-pods, create-skip, status no-op — no rv bump) confirms it STAYS matched
   without churning content; pass 3 is pruned, so the post-pass-2 state is
   {!Cc.settled}. The uid/rv ceilings leave room for the single creating pass
   ([desired] creates + one status write) and never fire themselves. *)
let settling_bound ~(desired : int) : Bound.t =
  {
    Bound.max_in_flight = 8;
    max_objects_per_kind = desired + 2;
    max_controllers = 1;
    uid_ceiling = desired + 3;
    rv_ceiling = desired + 3;
    reconcile_ceiling = 2;
    max_reconcile_depth = 16;
  }

(* ---- outcome accessors (two-arm match = exhaustive enumeration of the sum) ---- *)

let is_no_ce (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with Mc.No_counterexample _ -> true | Mc.Refuted _ -> false

let decisive_of (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let gate_positive (o : int option) : bool =
  Option.fold ~none:false ~some:(fun n -> n > 0) o

let gate_is_zero (o : int option) : bool =
  Option.fold ~none:false ~some:(fun n -> Int.equal n 0) o

let matches_of desired = (Invariants.liveness_goal ~cr:(Scenario.vrs ~desired)).holds

(* ---- reachable-state collector (BFS via recursion + folds; no loop keywords;
   mirrors t_p5_cluster_check) — test 4 needs the actual states to inspect the
   settled shape, which the abstract {!Mc.reachable} does not expose ---- *)

let reachable_states ~(bound : Bound.t) ~(desired : int) ~(depth : int) :
    Cluster.cluster_state list =
  let seed = Scenario.seed ~desired ~fair:true in
  let succ = Cc.bounded_successors bound Scenario.cluster in
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
  let () = if not (seen seed) then mark seed in
  bfs [ seed ] 0 [ seed ]

(* ---- (1) the settled Done is REACHABLE and every settled state MATCHES ---- *)

let test_settled_reachable_and_matching () =
  let desired = 3 in
  let bound = settling_bound ~desired in
  let seed = Scenario.seed ~desired ~fair:true in
  let reach =
    Mc.explore ~depth:40
      ~successors:(Cc.bounded_successors bound Scenario.cluster)
      ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ seed ]
  in
  let settled_here = Cc.settled bound Scenario.cluster in
  Alcotest.(check bool) "settled state reachable (count > 0)" true
    (Mc.count_states_where reach settled_here > 0);
  Alcotest.(check int) "every settled state matches (0 settled-and-NOT-matching)"
    0
    (Mc.count_states_where reach (fun s ->
         settled_here s && not (matches_of desired s)));
  let r : Cc.report = Cc.check_esr_settled ~depth:40 bound ~desired in
  Alcotest.(check bool) "check_esr_settled clean (No_counterexample)" true
    (is_no_ce r.outcome)

(* ---- (2) check_esr_settled is NON-VACUOUS and decisive: the gate count is
   POSITIVE (the P5 [Some 0] resolved), the frontier emptied, the 3rd pass was
   clipped ([pruned = true]) and rv stayed at/under its ceiling ---- *)

let test_esr_settled_nonvacuous_decisive () =
  let desired = 3 in
  let bound = settling_bound ~desired in
  let r : Cc.report = Cc.check_esr_settled ~depth:40 bound ~desired in
  Alcotest.(check bool) "gate_states = Some n with n > 0 (NON-VACUOUS)" true
    (gate_positive r.gate_states);
  Alcotest.(check bool) "No_counterexample" true (is_no_ce r.outcome);
  Alcotest.(check bool) "decisive = true (frontier emptied)" true
    (decisive_of r.outcome);
  Alcotest.(check bool) "pruned = true (the 3rd reconcile pass was clipped)" true
    r.pruned;
  (* STRICT < (review finding: [<=] is tautological — [collect_metadata] folds
     its maxima over in-ceiling states only, so [<=] can never fail).
     Strictly-below IS falsifiable (fails iff a state AT the ceiling is
     reached) and witnesses that the uid/rv clauses never fired: the
     [pruned = true] above is attributable to the reconcile clause alone, and
     the settled gate is not uid/rv-starved (the .mli interpretation
     discipline for a settled [Refuted]). *)
  Alcotest.(check bool) "max_uid_seen STRICTLY below uid_ceiling (never fired)"
    true (r.max_uid_seen < bound.uid_ceiling);
  Alcotest.(check bool) "max_rv_seen STRICTLY below rv_ceiling (never fired)"
    true (r.max_rv_seen < bound.rv_ceiling)

(* ---- (3) the reconcile_ceiling is LOAD-BEARING: raised to a perpetual value
   the reschedule is never pruned, every state keeps a state-changing productive
   successor, and the gate collapses back to the P5 vacuity ([Some 0]) ---- *)

let test_reconcile_ceiling_load_bearing () =
  let desired = 3 in
  let bound =
    { (settling_bound ~desired) with Bound.reconcile_ceiling = 1000 }
  in
  (* SAME depth as the positive control (test 2) — review finding: at a
     shallower depth [Some 0] would hold by TRUNCATION alone (no settled state
     within reach even WITH the ceiling), confounding the experiment. At equal
     depth the ONLY difference is the ceiling. *)
  let r : Cc.report = Cc.check_esr_settled ~depth:40 bound ~desired in
  Alcotest.(check bool)
    "gate_states = Some 0 (P5 vacuity reproduced without the ceiling)" true
    (gate_is_zero r.gate_states)

(* ---- (4) the exact MEASURED settled-state shape (desired = 1, small graph).

   MEASURED NUANCE vs BUILD-SPEC-P8 §2/§5.4 (the test pins what is TRUE): the
   reconcile-id bump happens at RUN time ([run_scheduled_reconcile] allocates,
   controller.ml), not at schedule time, so after pass 2 drains the
   [Schedule_controller_reconcile] step re-ARMS [scheduled_reconciles] one more
   time WITHOUT bumping the counter. The settled state is therefore the re-armed
   one — [scheduled_reconciles] holds the CR, and its only productive successor
   (running pass 3) is pruned. The content shape is as specified: [desired]
   owned pods + the vrs ([desired + 1] etcd objects), matching status, drained
   network, no ONGOING reconcile, and [max_reconcile_id = 2]. *)

let test_settled_state_shape () =
  let desired = 1 in
  let bound = settling_bound ~desired in
  let settled_states =
    List.filter
      (Cc.settled bound Scenario.cluster)
      (reachable_states ~bound ~desired ~depth:30)
  in
  let all (p : Cluster.cluster_state -> bool) : bool =
    List.for_all p settled_states
  in
  let scheduled_sum (s : Cluster.cluster_state) : int =
    Imap.fold
      (fun _id (cae : Cluster.controller_and_external) acc ->
        acc + Object_ref_map.cardinal cae.controller.scheduled_reconciles)
      s.controller_and_externals 0
  in
  let ongoing_sum (s : Cluster.cluster_state) : int =
    Imap.fold
      (fun _id (cae : Cluster.controller_and_external) acc ->
        acc + Object_ref_map.cardinal cae.controller.ongoing_reconciles)
      s.controller_and_externals 0
  in
  Alcotest.(check bool) ">= 1 settled state in the reachable set" true
    (not (settled_states = []));
  Alcotest.(check bool) "settled: current_state_matches (pods + status)" true
    (all (matches_of desired));
  Alcotest.(check bool) "settled: desired + 1 etcd objects (pods + vrs)" true
    (all (fun s ->
         Int.equal (Object_ref_map.cardinal (Cluster.resources s)) (desired + 1)));
  Alcotest.(check bool) "settled: network drained (in_flight empty)" true
    (all (fun (s : Cluster.cluster_state) ->
         Int.equal (Message.Pool.cardinal s.network.in_flight) 0));
  Alcotest.(check bool) "settled: no ONGOING reconcile" true
    (all (fun s -> Int.equal (ongoing_sum s) 0));
  Alcotest.(check bool)
    "settled: reschedule re-armed once more (scheduled holds the CR, its run pruned)"
    true
    (all (fun s -> Int.equal (scheduled_sum s) 1));
  Alcotest.(check bool) "settled: reconcile_id_counter = 2 (both passes ran)" true
    (all (fun s -> Int.equal (Cc.max_reconcile_id s) 2))

(* ---- (5) the P6 tail is non-vacuous from the consumer side: the reconcile-
   bounded tightened_bound reaches Done AND the matching-Done witnesses are
   positive AND the stability invariant frontier emptied ---- *)

let test_p6_tail_nonvacuous () =
  let r : Dis.edge_report =
    Vl.tail_matches_is_stable ~bound:Vl.tightened_bound ~desired:1
  in
  Alcotest.(check bool) "tail_matches_is_stable: holds" true r.Dis.holds;
  Alcotest.(check bool) "tail_matches_is_stable: witnesses > 0 (non-vacuous)"
    true (r.Dis.witnesses > 0);
  Alcotest.(check bool) "tail_matches_is_stable: frontier_emptied" true
    r.Dis.frontier_emptied

(* ---- (6) safety unaffected: the reconcile-ceiling pruning only DROPS
   successors, so it cannot manufacture a safety counterexample ---- *)

let test_safety_unaffected () =
  let desired = 3 in
  let bound = settling_bound ~desired in
  (* shallow full-nondeterminism sanity leg: at depth 6 NO ceiling can fire
     (the pass-3 run sits ~30 sequential levels deep), so this leg alone would
     be VACUOUS w.r.t. the new pruning (review finding) — hence the fair-graph
     leg below, which checks safety on the very graph where test 2 proves the
     reconcile ceiling FIRED ([pruned = true] at depth 40). *)
  let r : Cc.report = Cc.check_always ~depth:6 bound ~desired in
  Alcotest.(check bool) "check_always clean under settling_bound (shallow)" true
    (is_no_ce r.outcome);
  Alcotest.(check bool) "no invariant violated" true (Option.is_none r.violated);
  let cr = Scenario.vrs ~desired in
  let inv =
    Invariants.conjunction
      (Invariants.always ~cr ~controller_id:Scenario.controller_id)
  in
  let seed = Scenario.seed ~desired ~fair:true in
  let reach =
    Mc.explore ~depth:40
      ~successors:(Cc.bounded_successors bound Scenario.cluster)
      ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ seed ]
  in
  Alcotest.(check bool)
    "check_safety clean on the fair PRUNED graph (reconcile ceiling fired)"
    true
    (is_no_ce (Mc.check_safety reach ~inv ~equal:Cc.state_equal))

let () =
  Alcotest.run "p8_settle"
    [
      ( "settled_reachable",
        [ Alcotest.test_case "settled Done reachable + every settled state matches" `Quick test_settled_reachable_and_matching ] );
      ( "esr_settled_nonvacuous",
        [ Alcotest.test_case "gate_states POSITIVE, decisive, pruned, rv at/under ceiling" `Quick test_esr_settled_nonvacuous_decisive ] );
      ( "ceiling_load_bearing",
        [ Alcotest.test_case "perpetual reconcile_ceiling reproduces the P5 Some 0 vacuity" `Quick test_reconcile_ceiling_load_bearing ] );
      ( "settled_shape",
        [ Alcotest.test_case "exact MEASURED settled-state shape (desired = 1)" `Quick test_settled_state_shape ] );
      ( "p6_tail_nonvacuous",
        [ Alcotest.test_case "tail_matches_is_stable holds, witnesses > 0, decisive" `Quick test_p6_tail_nonvacuous ] );
      ( "safety_unaffected",
        [ Alcotest.test_case "check_always clean under settling_bound" `Quick test_safety_unaffected ] );
    ]

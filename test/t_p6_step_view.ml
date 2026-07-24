(* BUILD-SPEC-P6 §5 bullet 1 — [t_p6_step_view].

   The accessor {!Step_view} reads the vreplicaset controller's reconcile
   position out of a {!Cluster.cluster_state}. This file pins:

   - on {!Scenario.seed} (before any reconcile runs) [reconcile_step_of] is
     [None], [no_ongoing] is [true], [scheduled_only] is [false];
   - after the reconcile is SCHEDULED (one schedule step) [scheduled_only] holds
     and it is still [no_ongoing] / [reconcile_step_of = None];
   - after the reconcile is RUN (a [Run_scheduled_reconcile] Controller step) the
     position is [Some Init], [at_step Init] / [at_phase] / [no_ongoing] /
     [scheduled_only] all AGREE;
   - a corrupt [Value.t] as [local_state] returns [None] (the [unmarshal_state]
     failure branch), never an exception.

   Convention firewall: no loop keywords (BFS via recursion + List folds), no
   [_ ->] wildcard arm, [Option.fold] for options. *)

module Sv = Anvil_proof.Step_view
module Vl = Anvil_proof.Vrs_liveness
module Cc = Anvil_checker.Cluster_check
module Scenario = Anvil_assurance.Scenario

let desired = 1
let controller_id = Scenario.controller_id
let cr_key = Scenario.vrs_ref
let bound : Bound.t = Vl.tightened_bound
let seed : Cluster.cluster_state = Scenario.seed ~desired ~fair:true

(* The index-erased "at some [After_create_pod _]" phase (all 7 reconcile arms
   enumerated, no wildcard) — the same predicate {!Vrs_liveness.f_at_creating}
   lifts, rebuilt here so the accessor agreement can be asserted. *)
let is_after_create_pod (step : Vreplica_set_reconciler.step) : bool =
  match step with
  | After_create_pod _ -> true
  | Init | After_list_pods | After_delete_pod _ | After_update_vrs_status | Done
  | Error ->
    false

(* ---- reachable-state collector (BFS via recursion + folds; no loop keywords),
   deduped by the sound cluster equality/hash — mirrors t_p5_cluster_check. ---- *)
let reachable_states ~(depth : int) : Cluster.cluster_state list =
  let succ = Cc.bounded_successors bound Scenario.cluster in
  let visited : (int, Cluster.cluster_state list) Hashtbl.t = Hashtbl.create 4096 in
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
                (fun fr s' -> if seen s' then fr else (mark s'; s' :: fr))
                fr (succ s))
            [] frontier
        in
        bfs (List.rev next) (level + 1) (List.rev_append next acc)
  in
  let () = if not (seen seed) then mark seed in
  bfs [ seed ] 0 [ seed ]

let states : Cluster.cluster_state list = reachable_states ~depth:40

(* The first reachable state (if any) satisfying [pred]. *)
let find (pred : Cluster.cluster_state -> bool) : Cluster.cluster_state option =
  List.find_opt pred states

(* ---- (1) the plain seed: nothing scheduled, nothing ongoing ---- *)

let test_seed_none () =
  Alcotest.(check bool) "seed: reconcile_step_of is None" true
    (Option.is_none (Sv.reconcile_step_of ~controller_id ~cr_key seed));
  Alcotest.(check bool) "seed: no_ongoing" true
    (Sv.no_ongoing ~controller_id ~cr_key seed);
  Alcotest.(check bool) "seed: not scheduled_only" false
    (Sv.scheduled_only ~controller_id ~cr_key seed);
  Alcotest.(check bool) "seed: not at Init" false
    (Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Init seed)

(* ---- (2) a SCHEDULED-not-run state: scheduled_only holds, still no ongoing ---- *)

let test_scheduled_only () =
  let s = find (Sv.scheduled_only ~controller_id ~cr_key) in
  Alcotest.(check bool) "a scheduled_only state is reachable" true (Option.is_some s);
  Option.iter
    (fun st ->
      Alcotest.(check bool) "scheduled_only: scheduled_only" true
        (Sv.scheduled_only ~controller_id ~cr_key st);
      Alcotest.(check bool) "scheduled_only: no_ongoing (agrees)" true
        (Sv.no_ongoing ~controller_id ~cr_key st);
      Alcotest.(check bool) "scheduled_only: reconcile_step_of None (agrees)" true
        (Option.is_none (Sv.reconcile_step_of ~controller_id ~cr_key st));
      Alcotest.(check bool) "scheduled_only: not at Init" false
        (Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Init st))
    s

(* ---- (3) a RUN state: reconcile_step_of = Some Init, all accessors agree ---- *)

let test_at_init () =
  let s = find (Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Init) in
  Alcotest.(check bool) "an at-Init state is reachable (after Run_scheduled_reconcile)"
    true (Option.is_some s);
  Option.iter
    (fun st ->
      (* reconcile_step_of = Some Init *)
      Alcotest.(check bool) "at_init: reconcile_step_of is Some Init" true
        (Option.fold
           (Sv.reconcile_step_of ~controller_id ~cr_key st)
           ~none:false
           ~some:(fun step ->
             Vreplica_set_reconciler.step_equal step Vreplica_set_reconciler.Init));
      (* at_step / at_phase / no_ongoing / scheduled_only all agree *)
      Alcotest.(check bool) "at_init: at_step Init true" true
        (Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Init st);
      Alcotest.(check bool) "at_init: at_step After_list_pods false" false
        (Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.After_list_pods st);
      Alcotest.(check bool) "at_init: at_phase is_after_create_pod false" false
        (Sv.at_phase ~controller_id ~cr_key is_after_create_pod st);
      Alcotest.(check bool) "at_init: no_ongoing false (a reconcile IS ongoing)" false
        (Sv.no_ongoing ~controller_id ~cr_key st);
      Alcotest.(check bool) "at_init: not scheduled_only (already started)" false
        (Sv.scheduled_only ~controller_id ~cr_key st))
    s

(* ---- (4) the unmarshal-failure branch: a corrupt local_state -> None ---- *)

(* A cluster_state whose controller carries an ongoing reconcile keyed at [cr_key]
   whose [local_state] is a corrupt (non-object) [Value.t]. [unmarshal_state]
   fails, so [reconcile_step_of] takes its [Result.fold ~error] branch and returns
   [None] — the total, no-exception partiality the [.mli] promises. *)
let corrupt_state : Cluster.cluster_state =
  let bad_oc : Controller.ongoing_reconcile =
    {
      Controller.triggering_cr = Vreplica_set.marshal (Scenario.vrs ~desired);
      pending_req_msg = None;
      local_state = Value.of_json (`String "not-a-reconcile-state-object");
      reconcile_id = 0;
    }
  in
  let cstate : Controller.state =
    {
      Controller.ongoing_reconciles =
        Object_ref_map.add cr_key bad_oc Object_ref_map.empty;
      scheduled_reconciles = Object_ref_map.empty;
      reconcile_id_allocator = Controller.Reconcile_id_allocator.init ();
    }
  in
  {
    seed with
    Cluster.controller_and_externals =
      Imap.add controller_id
        { Cluster.controller = cstate; external_ = None; crash_enabled = false }
        Imap.empty;
  }

let test_unmarshal_failure () =
  Alcotest.(check bool)
    "corrupt local_state: reconcile_step_of is None (unmarshal failure, no raise)"
    true
    (Option.is_none (Sv.reconcile_step_of ~controller_id ~cr_key corrupt_state));
  Alcotest.(check bool) "corrupt local_state: no_ongoing true (unmarshal failure)" true
    (Sv.no_ongoing ~controller_id ~cr_key corrupt_state);
  Alcotest.(check bool) "corrupt local_state: not at Init" false
    (Sv.at_step ~controller_id ~cr_key Vreplica_set_reconciler.Init corrupt_state)

let () =
  Alcotest.run "p6_step_view"
    [
      ( "seed_none",
        [ Alcotest.test_case "plain seed: None / no_ongoing / not scheduled" `Quick test_seed_none ] );
      ( "scheduled_only",
        [ Alcotest.test_case "scheduled-not-run: scheduled_only + accessors agree" `Quick test_scheduled_only ] );
      ( "at_init",
        [ Alcotest.test_case "run: Some Init + accessors agree" `Quick test_at_init ] );
      ( "unmarshal_failure",
        [ Alcotest.test_case "corrupt Value.t local_state -> None" `Quick test_unmarshal_failure ] );
    ]

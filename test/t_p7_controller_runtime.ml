(* P7 exec-shim tests: the reconcile driver {!Controller_runtime} (BUILD-SPEC-P7
   §4) - the P7 convergence payoff. Against a fresh in-memory store seeded with a
   [replicas = N] vreplicaset:

   - [reconcile_with] reaches [Reconciled] and the store then holds EXACTLY N
     owned pods (the unbounded executable reconcile actually creates them, unlike
     the vacuous bounded checker);
   - a second [reconcile_with] on the converged store is idempotent (still N pods,
     no further Create);
   - [run_controller] over the cr key returns [Reconciled] for it and terminates
     within [max_rounds], the store holding N pods;
   - [run_controller] over a key ABSENT from the store drops it (empty result, no
     error);
   - exhausting [fuel] yields [Incomplete 0].

   Targets of mutation M2 (drop the K_request send) and M3 (skip the store
   persist): M2 stalls the reconcile ([Incomplete], 0 pods); M3 leaves the store
   empty (seed unpersisted), so convergence never completes - both flip the
   [Reconciled] / "N pods" assertions red. *)

module Exec = Anvil_exec.Exec_api_server
module Direct = Anvil_exec.Concurrency.Direct
module CR = Anvil_exec.Controller_runtime
module Scenario = Anvil_assurance.Scenario
module R = CR.Make (Direct) (Exec)

let desired = 3
let installed = Scenario.cluster.Cluster.installed_types
let cr = Vreplica_set.marshal (Scenario.vrs ~desired)
let key = Scenario.vrs_ref

let model =
  Controller.model_of_controller ~kind:Vreplica_set.kind
    (module Vreplica_set_pack.Controller)

let count_pods (t : Exec.t) : int =
  Object_ref_map.fold
    (fun _k obj acc ->
      if Common.equal_kind (Dynamic_object.kind obj) Pod.kind then acc + 1 else acc)
    (Exec.state t).Api_server.resources 0

let fresh_seeded () : Exec.t =
  match Exec.create ~installed ~seed:[ cr ] () with
  | Ok t -> t
  | Error e -> Alcotest.failf "create: %s" (Err.show e)

let expect_reconciled label (r : (CR.outcome, Err.t) result) : unit =
  match r with
  | Ok o ->
      Alcotest.(check bool) (label ^ ": Reconciled") true
        (CR.outcome_equal o CR.Reconciled)
  | Error e -> Alcotest.failf "%s transport error: %s" label (Err.show e)

let test_reconcile_converges () =
  let t = fresh_seeded () in
  expect_reconciled "first pass" (R.reconcile_with ~client:t ~model ~cr ~fuel:100);
  Alcotest.(check int) "store holds exactly N owned pods" desired (count_pods t);
  expect_reconciled "second pass"
    (R.reconcile_with ~client:t ~model ~cr ~fuel:100);
  Alcotest.(check int) "idempotent: still N pods, no new Create" desired
    (count_pods t)

let test_run_controller () =
  let t = fresh_seeded () in
  (match R.run_controller ~client:t ~model ~queue:[ key ] ~fuel:100 ~max_rounds:5 with
  | Ok result ->
      Alcotest.(check bool) "key outcome is Reconciled" true
        (Option.fold
           (Object_ref_map.find_opt key result)
           ~none:false
           ~some:(fun o -> CR.outcome_equal o CR.Reconciled))
  | Error e -> Alcotest.failf "run_controller transport error: %s" (Err.show e));
  Alcotest.(check int) "store holds N pods after run_controller" desired
    (count_pods t)

let test_run_controller_missing_key () =
  let t =
    match Exec.create ~installed () with
    | Ok t -> t
    | Error e -> Alcotest.failf "create: %s" (Err.show e)
  in
  match R.run_controller ~client:t ~model ~queue:[ key ] ~fuel:100 ~max_rounds:5 with
  | Ok result ->
      Alcotest.(check bool) "absent key is dropped (empty result)" true
        (Object_ref_map.is_empty result)
  | Error e -> Alcotest.failf "run_controller transport error: %s" (Err.show e)

let test_fuel_exhaustion () =
  let t = fresh_seeded () in
  match R.reconcile_with ~client:t ~model ~cr ~fuel:1 with
  | Ok o ->
      Alcotest.(check bool) "tiny fuel yields Incomplete 0" true
        (CR.outcome_equal o (CR.Incomplete 0))
  | Error e -> Alcotest.failf "reconcile transport error: %s" (Err.show e)

let () =
  Alcotest.run "p7_controller_runtime"
    [
      ( "convergence",
        [
          Alcotest.test_case "reconcile_with -> Reconciled + N pods (idempotent)"
            `Quick test_reconcile_converges;
          Alcotest.test_case "run_controller over [key] -> Reconciled" `Quick
            test_run_controller;
          Alcotest.test_case "run_controller drops an absent key" `Quick
            test_run_controller_missing_key;
          Alcotest.test_case "fuel exhaustion -> Incomplete 0" `Quick
            test_fuel_exhaustion;
        ] );
    ]

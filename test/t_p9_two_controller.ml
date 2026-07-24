(* P9 exec-shim payoff (BUILD-SPEC-P9 §5, t_p9_two_controller; mirrors
   t_p7_controller_runtime.ml): the "controller of controllers" convergence
   witness. A VDeployment (desired replicas) is seeded into an
   {!Exec_api_server} built with the multi-kind [installed_types], and BOTH the
   VDeployment and VReplicaSet controllers are driven over that one shared store
   to a JOINT fixpoint by {!Multi_controller.run_to_fixpoint}.

   Neither controller converges alone: the VDeployment's rolling-update
   [mismatch_replicas] gate scales the child VReplicaSet by +1 only once the
   child's [status.replicas] reflects readiness — which is the OTHER controller's
   output. Interleaving them, the store settles at exactly one VReplicaSet with
   [spec.replicas = desired], exactly [desired] pods, no old VReplicaSet, and both
   reconcilers idempotent (a second [run_to_fixpoint] performs no store write).

   This is the executable convergence the P5 bounded checker and P6 liveness
   skeleton could reach only vacuously under a finite ceiling. Targets of the
   §3 mutants: M1 (drop the Create) leaves 0 VReplicaSets; M2 (always-scale) never
   stabilises within [max_rounds] (converged = false); M3 (off-by-one scale) stalls
   below [desired] — each flips an assertion below red. *)

module Exec = Anvil_exec.Exec_api_server
module Direct = Anvil_exec.Concurrency.Direct
module Mc = Anvil_exec.Multi_controller
module Scenario = Anvil_assurance.Scenario
module M = Mc.Make (Direct) (Exec)

let installed = Scenario.vd_and_vrs_installed

let vd_model =
  Controller.model_of_controller ~kind:V_deployment.kind
    (module V_deployment_pack.Controller)

let vrs_model =
  Controller.model_of_controller ~kind:Vreplica_set.kind
    (module Vreplica_set_pack.Controller)

(* VDeployment first, then VReplicaSet: each round the VDeployment observes the
   PREVIOUS round's child readiness before scaling, then the VReplicaSet
   materialises the new replica count. *)
let models = [ vd_model; vrs_model ]

let fresh ~desired : Exec.t =
  Result.fold
    (Exec.create ~installed
       ~seed:[ V_deployment.marshal (Scenario.vd ~desired) ]
       ())
    ~ok:(fun (t : Exec.t) -> t)
    ~error:(fun (e : Err.t) -> Alcotest.failf "create: %s" (Err.show e))

(* The backend's resource-version write-clock: a round that leaves it unchanged
   is the joint fixpoint. *)
let rv_of (t : Exec.t) () : int =
  (Exec.state t).Api_server.resource_version_counter

let converge (t : Exec.t) : M.report =
  Result.fold
    (M.run_to_fixpoint ~client:t ~models ~namespace:"ns" ~rv:(rv_of t) ~fuel:100
       ~max_rounds:20)
    ~ok:(fun (r : M.report) -> r)
    ~error:(fun (e : Err.t) -> Alcotest.failf "run_to_fixpoint: %s" (Err.show e))

let count_kind (t : Exec.t) (k : Common.kind) : int =
  Object_ref_map.fold
    (fun _key obj acc ->
      if Common.equal_kind (Dynamic_object.kind obj) k then acc + 1 else acc)
    (Exec.state t).Api_server.resources 0

(* The [spec.replicas] of every stored VReplicaSet (an unmarshal failure records
   [-1] so a corrupt store still fails the pinned equality loudly). *)
let vrs_replicas (t : Exec.t) : int list =
  Object_ref_map.fold
    (fun _key obj acc ->
      if Common.equal_kind (Dynamic_object.kind obj) Vreplica_set.kind then
        Result.fold (Vreplica_set.unmarshal obj)
          ~ok:(fun (v : Vreplica_set.t) ->
            Option.value ~default:(-1) (Vreplica_set.spec v).replicas :: acc)
          ~error:(fun (_ : Err.t) -> -1 :: acc)
      else acc)
    (Exec.state t).Api_server.resources []

let check_converged ~(desired : int) () : unit =
  let t = fresh ~desired in
  let r = converge t in
  Alcotest.(check bool)
    (Printf.sprintf "desired=%d: joint fixpoint reached" desired)
    true r.M.converged;
  Alcotest.(check int)
    (Printf.sprintf "desired=%d: exactly one vreplicaset (no old vrs)" desired)
    1
    (count_kind t Vreplica_set.kind);
  Alcotest.(check (list int))
    (Printf.sprintf "desired=%d: the vreplicaset is at spec.replicas=desired"
       desired)
    [ desired ] (vrs_replicas t);
  Alcotest.(check int)
    (Printf.sprintf "desired=%d: exactly desired pods" desired)
    desired (count_kind t Pod.kind);
  (* idempotent: a second run writes nothing -> a single no-op round, converged *)
  let r2 = converge t in
  Alcotest.(check bool)
    (Printf.sprintf "desired=%d: second run converged (no-op)" desired)
    true r2.M.converged;
  Alcotest.(check int)
    (Printf.sprintf "desired=%d: second run is a single no-op round" desired)
    1 r2.M.rounds;
  Alcotest.(check int)
    (Printf.sprintf "desired=%d: still exactly one vreplicaset" desired)
    1
    (count_kind t Vreplica_set.kind);
  Alcotest.(check int)
    (Printf.sprintf "desired=%d: still exactly desired pods" desired)
    desired (count_kind t Pod.kind)

(* Robustness guard (review LOW fix): [converged] requires BOTH an unchanged
   write-clock AND every reconciler [Reconciled]. With [fuel:1] each reconciler
   emits only its opening [List] (a read) and hits [Incomplete] before any write,
   so the round leaves [rv] unchanged yet nothing is settled. A joint fixpoint
   must NOT be reported: this pins [converged = false] (it would be a false
   positive under the rv-only test the fix replaced) and that no child was
   created. *)
let check_fuel_starved_not_converged () : unit =
  let t = fresh ~desired:3 in
  let r =
    Result.fold
      (M.run_to_fixpoint ~client:t ~models ~namespace:"ns" ~rv:(rv_of t) ~fuel:1
         ~max_rounds:3)
      ~ok:(fun (r : M.report) -> r)
      ~error:(fun (e : Err.t) ->
        Alcotest.failf "run_to_fixpoint: %s" (Err.show e))
  in
  Alcotest.(check bool)
    "fuel-starved read-only rounds are NOT a joint fixpoint" false r.M.converged;
  Alcotest.(check int) "fuel=1: no vreplicaset created" 0
    (count_kind t Vreplica_set.kind);
  Alcotest.(check int) "fuel=1: no pod created" 0 (count_kind t Pod.kind)

let () =
  Alcotest.run "p9_two_controller"
    [
      ( "convergence",
        [
          Alcotest.test_case "desired=1 converges (1 vrs @1, 1 pod, idempotent)"
            `Quick (check_converged ~desired:1);
          Alcotest.test_case "desired=2 converges (1 vrs @2, 2 pods, idempotent)"
            `Quick (check_converged ~desired:2);
          Alcotest.test_case "desired=3 converges (1 vrs @3, 3 pods, idempotent)"
            `Quick (check_converged ~desired:3);
        ] );
      ( "robustness",
        [
          Alcotest.test_case "fuel-starved round is not a false joint fixpoint"
            `Quick check_fuel_starved_not_converged;
        ] );
    ]

(* P7 exec-shim demo (BUILD-SPEC-P7 §3): a deterministic VReplicaSet
   reconcile-to-convergence, in process, with no network.

   This binary is the concrete payoff over P5/P6: the UNBOUNDED executable
   reconcile actually reaches [Reconciled] and actually creates the pods - the
   convergence the bounded checker (P5) and the liveness skeleton (P6) could only
   witness vacuously under a finite [rv_ceiling]. It seeds a fresh in-memory
   {!Exec_api_server} with a [replicas = 3] VReplicaSet (0 owned pods), drives it
   through {!Controller_runtime.run_controller} under the deterministic
   {!Concurrency.Direct} backend, and checks the fixpoint: exactly three owned
   pods in the store and a [Reconciled] outcome for the cr key.

   As an entrypoint (not library code) it is allowed [print_endline] and [exit];
   it still uses no loop keyword, no wildcard on a finite sum, and no exception -
   every partiality flows through {!Res.t} and is discharged with [Result.fold]. *)

let desired : int = 3

(* Count the pods currently persisted in the api-server store. The store holds
   only the seeded vreplicaset plus the pods the reconcile created, so the
   [Pod.kind] count equals the created-pod count. Enumerated with a map fold (no
   loop keyword); the kind test is the total {!Common.equal_kind}. *)
let count_pods (client : Exec_api_server.t) : int =
  Object_ref_map.fold
    (fun _key obj acc ->
      if Common.equal_kind (Dynamic_object.kind obj) Pod.kind then acc + 1 else acc)
    (Exec_api_server.state client).Api_server.resources 0

let () =
  let installed = Anvil_assurance.Scenario.cluster.Cluster.installed_types in
  let cr = Vreplica_set.marshal (Anvil_assurance.Scenario.vrs ~desired) in
  let key = Anvil_assurance.Scenario.vrs_ref in
  let model =
    Controller.model_of_controller ~kind:Vreplica_set.kind
      (module Vreplica_set_pack.Controller)
  in
  let module R = Controller_runtime.Make (Concurrency.Direct) (Exec_api_server) in
  (* Seed the store with the cr, then run the manager over its key. With
     [Concurrency.Direct] the [C] monad is the identity, so [run_controller]
     returns the result value directly. *)
  let outcome_res =
    Res.bind (Exec_api_server.create ~installed ~seed:[ cr ] ()) (fun client ->
        Res.map
          (fun result -> (client, result))
          (R.run_controller ~client ~model ~queue:[ key ] ~fuel:100 ~max_rounds:5))
  in
  Result.fold outcome_res
    ~error:(fun (e : Err.t) ->
      print_endline ("operator: transport/porting error: " ^ Err.show e);
      exit 1)
    ~ok:(fun (client, result) ->
      let pods = count_pods client in
      let reconciled =
        Option.fold
          (Object_ref_map.find_opt key result)
          ~none:false
          ~some:(fun o ->
            Controller_runtime.outcome_equal o Controller_runtime.Reconciled)
      in
      let converged = Int.equal pods desired && reconciled in
      print_endline
        (Printf.sprintf
           "operator: VReplicaSet vrs1 desired=%d -> pods=%d, key outcome \
            Reconciled=%b"
           desired pods reconciled);
      if not converged then (
        print_endline "operator: FAILED - reconcile did not converge as expected";
        exit 1)
      else
        print_endline
          "operator: OK - executable reconcile reached the fixpoint (3 owned pods, \
           Reconciled)")

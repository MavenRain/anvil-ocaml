(* P7 exec-shim tests: the correspondence oracle along a REAL executable
   trajectory (BUILD-SPEC-P7 §4). A whole vreplicaset reconcile is driven through
   {!Controller_runtime.reconcile_with}, but the {!K8s_client.K8S_CLIENT} backend
   is a thin wrapper that runs each request through {!Exec_api_server.request_checked}
   and folds the {!Exec_api_server.check.agreed} bit into a flag. The reconcile
   reaches [Reconciled] AND every request agrees with the golden P4
   {!Oracle_api_server} - the executable-trajectory correspondence.

   This is the target of mutation M4: computing [agrees] on the POST-transition
   state (after the store mutated) would miss a divergence that only the
   pre-transition check can see (see t_p7_mutation's planted-divergence test). *)

module Exec = Anvil_exec.Exec_api_server
module Direct = Anvil_exec.Concurrency.Direct
module CR = Anvil_exec.Controller_runtime
module Scenario = Anvil_assurance.Scenario

(* A K8S_CLIENT that checks every request against the oracle and records whether
   agreement ever failed. [type 'a io = 'a] so it slots under {!Concurrency.Direct}. *)
module Checked = struct
  type t = { inner : Exec.t; mutable all_agreed : bool }
  type 'a io = 'a

  let request (c : t) (req : Api_method.api_request) :
      (Api_method.api_response, Err.t) result =
    Result.map
      (fun ({ response; agreed } : Exec.check) ->
        if not agreed then c.all_agreed <- false;
        response)
      (Exec.request_checked c.inner req)
end

let installed = Scenario.cluster.Cluster.installed_types
let cr = Vreplica_set.marshal (Scenario.vrs ~desired:3)

let model =
  Controller.model_of_controller ~kind:Vreplica_set.kind
    (module Vreplica_set_pack.Controller)

let test_correspondence () =
  let inner =
    match Exec.create ~installed ~seed:[ cr ] () with
    | Ok t -> t
    | Error e -> Alcotest.failf "create: %s" (Err.show e)
  in
  let client = { Checked.inner; all_agreed = true } in
  let module R = CR.Make (Direct) (Checked) in
  (match R.reconcile_with ~client ~model ~cr ~fuel:100 with
  | Ok o ->
      Alcotest.(check bool) "reconcile reaches Reconciled" true
        (CR.outcome_equal o CR.Reconciled)
  | Error e -> Alcotest.failf "reconcile transport error: %s" (Err.show e));
  Alcotest.(check bool) "oracle agreed on EVERY request along the trajectory" true
    client.Checked.all_agreed

let () =
  Alcotest.run "p7_correspondence"
    [
      ( "executable-trajectory-oracle",
        [ Alcotest.test_case "reconcile agrees with the golden re-port" `Quick
            test_correspondence ] );
    ]

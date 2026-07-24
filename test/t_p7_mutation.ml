(* P7 exec-shim tests: the confirm-by-mutation spine on P7 itself (BUILD-SPEC-P7
   §4). Four mutants, each SEEN to flip a P7 assertion green -> red then restored
   (the tree ships GREEN). The mutants are documented here and were exercised by
   temporarily applying each, rebuilding, running the pinning exe, observing the
   red assertion, then reverting.

   M1  neuter uid/rv stamping in {!Exec_api_server} (in [apply], keep the old
       counters instead of the transitioned [st'.uid_counter]/[rv_counter]).
       PINNED BY t_p7_exec_api_server (and [test_m1_counters] below): the counters
       never advance, so the exact counter assertions flip red.

   M2  drop the [K_request] -> [K.request] send in {!Controller_runtime.reconcile_with}
       (treat it as [None]). PINNED BY t_p7_controller_runtime (and
       [test_m23_creates_persist]): no Create is ever issued, so the store holds 0
       pods and the reconcile never reaches Done (Incomplete) - both the "N pods"
       and "Reconciled" assertions flip red.

   M3  skip the store persist in {!Exec_api_server} (drop [t.st <- st'] in [apply]).
       PINNED BY t_p7_controller_runtime (and [test_m23_creates_persist]): every
       request still computes the right RESPONSE, but nothing is persisted - so
       the seeded cr itself is not stored, the later Get_then_update_status finds
       no object, the reconcile never reaches Done, and convergence fails
       ([Reconciled] and the "N pods" assertions flip red). It documents that the
       oracle judges each TRANSITION, not the persisted store: the correspondence
       [agreed] bit is unaffected (only the convergence sub-assertion goes red).

   M4  compute [agrees] on the POST-transition state in
       {!Exec_api_server.request_checked} (move the [Oracle_api_server.agrees]
       call to AFTER [apply]). PINNED BY [test_m4_planted_divergence] below: with a
       one-off planted oracle disagreement, the correct PRE-state check reports
       [agreed = false]; the mutant re-checks the POST-state where the request now
       hits [Object_already_exists] (oracle and port agree again), so it reports
       [agreed = true] and MISSES the divergence - the assertion flips red. *)

module Exec = Anvil_exec.Exec_api_server
module Direct = Anvil_exec.Concurrency.Direct
module CR = Anvil_exec.Controller_runtime
module Scenario = Anvil_assurance.Scenario
module R = CR.Make (Direct) (Exec)

let desired = 3
let installed = Scenario.cluster.Cluster.installed_types
let cr = Vreplica_set.marshal (Scenario.vrs ~desired)

let model =
  Controller.model_of_controller ~kind:Vreplica_set.kind
    (module Vreplica_set_pack.Controller)

let count_pods (t : Exec.t) : int =
  Object_ref_map.fold
    (fun _k obj acc ->
      if Common.equal_kind (Dynamic_object.kind obj) Pod.kind then acc + 1 else acc)
    (Exec.state t).Api_server.resources 0

(* M1: the CREATE must stamp and advance the uid/rv counters. *)
let test_m1_counters () =
  let t =
    match Exec.create ~installed () with
    | Ok t -> t
    | Error e -> Alcotest.failf "create: %s" (Err.show e)
  in
  let s0 = Exec.state t in
  Alcotest.(check (pair int int)) "fresh counters" (0, 0)
    (s0.Api_server.uid_counter, s0.Api_server.resource_version_counter);
  (match Exec.request t (Api_method.Create_request { namespace = "ns"; obj = cr }) with
  | Ok _ -> ()
  | Error e -> Alcotest.failf "create req: %s" (Err.show e));
  let s1 = Exec.state t in
  Alcotest.(check (pair int int)) "CREATE advances uid+rv" (1, 1)
    (s1.Api_server.uid_counter, s1.Api_server.resource_version_counter)

(* M2 + M3: the reconcile must issue the Creates AND persist them - the store must
   actually hold N pods at the fixpoint. *)
let test_m23_creates_persist () =
  let t =
    match Exec.create ~installed ~seed:[ cr ] () with
    | Ok t -> t
    | Error e -> Alcotest.failf "create: %s" (Err.show e)
  in
  (match R.reconcile_with ~client:t ~model ~cr ~fuel:100 with
  | Ok o ->
      Alcotest.(check bool) "reconcile reaches Reconciled" true
        (CR.outcome_equal o CR.Reconciled)
  | Error e -> Alcotest.failf "reconcile: %s" (Err.show e));
  Alcotest.(check int) "store persists exactly N created pods" desired
    (count_pods t)

(* M4: [request_checked] must judge the oracle on the PRE-transition state. The
   plant: a [valid_object] that returns true on odd calls and false on even ones.
   On a fresh CREATE, [agrees] runs the oracle first (call #1 -> true -> object
   created) then the port (call #2 -> false -> rejected as Invalid): the two
   DISAGREE, so a pre-state check reports [agreed = false]. The M4 mutant checks
   the POST-state, where the object now exists and BOTH sides short-circuit to
   [Object_already_exists] before ever consulting [valid_object] - they agree
   again, so the mutant reports [agreed = true] and misses the planted divergence. *)
let test_m4_planted_divergence () =
  let calls = ref 0 in
  let planted =
    {
      installed with
      Api_server.valid_object =
        (fun _obj ->
          incr calls;
          !calls mod 2 = 1);
    }
  in
  let t =
    match Exec.create ~installed:planted () with
    | Ok t -> t
    | Error e -> Alcotest.failf "create: %s" (Err.show e)
  in
  match
    Exec.request_checked t
      (Api_method.Create_request { namespace = "ns"; obj = cr })
  with
  | Ok chk ->
      Alcotest.(check bool)
        "pre-state check DETECTS the planted oracle divergence" false
        chk.Exec.agreed
  | Error e -> Alcotest.failf "request_checked: %s" (Err.show e)

let () =
  Alcotest.run "p7_mutation"
    [
      ( "confirm-by-mutation",
        [
          Alcotest.test_case "M1: CREATE advances the counters" `Quick
            test_m1_counters;
          Alcotest.test_case "M2/M3: reconcile issues+persists N pods" `Quick
            test_m23_creates_persist;
          Alcotest.test_case "M4: agrees is judged on the pre-transition state"
            `Quick test_m4_planted_divergence;
        ] );
    ]

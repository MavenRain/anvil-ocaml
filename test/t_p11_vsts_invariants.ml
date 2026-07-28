(* BUILD-SPEC-P11 §4 / Stage 2 - the VStatefulSet safety-invariant harness.

   Two exploration regimes, each the right tool for its obligation:

   * fair:TRUE is DECISIVE. With the three disruptors off, the reachable graph
     from [Scenario.vsts_seed ~desired ~fair:true] over [Scenario.vsts_cluster]
     is FINITE and fully explored ([frontier_emptied]); it is BFS'd once and used
     for the exhaustive safety check, the pinned non-vacuity counts and the goal
     measurement.

   * fair:FALSE is NON-BFS-ABLE. With the disruptors on, the pod-monkey allocates
     a fresh rpc id on every op and there is NO rpc ceiling in {!Bound.t}, so the
     state never re-converges and the graph is INFINITE (a full BFS does not
     terminate). Safety under full nondeterminism is therefore sampled by random
     enabled-step traces, exactly as the VReplicaSet harness ([t_p4_invariants])
     does for the same reason.

   Obligations:

   (S1) SAFETY, decisive: every [Vsts_invariants.always] invariant (the shared
        inv1-6 + the three VSTS invariants) has ZERO holds-violations across the
        WHOLE fair:true reachable graph.

   (S2) SAFETY, sampled: on random enabled-step traces from [vsts_seed ~fair:false]
        over [vsts_cluster], the [Invariants.conjunction] of [always] holds at
        EVERY state. A violation names the invariant and FAILS (never reclassified).

   (V) NON-VACUITY, pinned: each invariant's [interesting]-witness count over the
       decisive fair:true graph is MEASURED and PINNED. Content-bearing + inv1-5
       are positive; two are DISCLOSED vacuous (not tuned away):
       - inv6 [every_ongoing_reconcile_has_unique_id] needs >= 2 concurrent
         reconciles (a multi-CR seed) : 0 here. P12 supplies that witness:
         [Cluster_check.check_unique_reconcile_id_vsts] over the multi-CR
         [Scenario.vsts_seed_multi] de-vacuifies inv6 (gate_states > 0),
         while this single-CR pin genuinely stays 0.
       - [owned_pvcs_bound_to_vsts] is vacuous BY CONSTRUCTION - the faithful
         [make_pvc] stamps no owner-ref on PVCs, so the owned-PVC set is empty in
         every reachable state (even vct:true) : 0. (§0 honest-vacuity precedent.)

   (G) GOAL discrimination: [current_state_matches] is FALSE at the transient seed
       and reachable-true in a PINNED number of states (the ordinal-stable converged
       shape is reached) - it is not [fun _ -> true].

   Firewall honoured in the test: List/Option combinators only (no loop keywords),
   exhaustive matches, Option.fold not two-arm option match, Alcotest / QCheck as
   the sanctioned failure primitives. *)

module Gen = QCheck.Gen
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vsts_invariants = Anvil_assurance.Vsts_invariants
module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check

let controller_id : int = Scenario.controller_id
let desired : int = 2
let cr_of ~desired : V_stateful_set.t = Scenario.vsts ~desired ()

let always_of ~desired : Invariants.invariant list =
  Vsts_invariants.always ~cr:(cr_of ~desired) ~controller_id

(* The decisive fair:true bound: uid/rv ceilings above the single creating pass
   (1 CR + [desired] pods) so they are not themselves the binding constraint;
   [reconcile_ceiling = 2] admits the first-pass converge plus one re-reconcile.
   [max_controllers = 1] matches the single controller in [vsts_cluster]. *)
let bfs_bound ~(desired : int) : Bound.t =
  {
    Bound.max_in_flight = 8;
    max_objects_per_kind = desired + 2;
    max_controllers = 1;
    uid_ceiling = desired + 4;
    rv_ceiling = desired + 4;
    reconcile_ceiling = 2;
    max_reconcile_depth = 16;
    monkey_forge = [];
  }

let reach_fair ~(desired : int) : Cluster.cluster_state Mc.reachable =
  Mc.explore ~depth:40
    ~successors:(Cc.bounded_successors (bfs_bound ~desired) Scenario.vsts_cluster)
    ~equal:Cc.state_equal ~hash:Cc.state_hash
    ~init:[ Scenario.vsts_seed ~desired ~fair:true ]

let holds_violations (r : Cluster.cluster_state Mc.reachable)
    (inv : Invariants.invariant) : int =
  Mc.count_states_where r (fun s -> not (inv.holds s))

let interesting_count (r : Cluster.cluster_state Mc.reachable)
    (inv : Invariants.invariant) : int =
  Mc.count_states_where r inv.interesting

let find_inv (invs : Invariants.invariant list) (name : string) :
    Invariants.invariant option =
  List.find_opt (fun (i : Invariants.invariant) -> String.equal i.name name) invs

let interesting_of (r : Cluster.cluster_state Mc.reachable)
    (invs : Invariants.invariant list) (name : string) : int =
  Option.fold (find_inv invs name) ~none:(-1) ~some:(interesting_count r)

(* ---- (S1) SAFETY, decisive over the whole fair:true reachable graph ------- *)

let test_safety_decisive () =
  let r = reach_fair ~desired in
  Alcotest.(check bool)
    "fair:true exploration is decisive (frontier emptied - a full graph)" true
    (Mc.frontier_emptied r);
  List.iter
    (fun (i : Invariants.invariant) ->
      Alcotest.(check int)
        (Printf.sprintf "always %S: zero holds-violations across the graph" i.name)
        0 (holds_violations r i))
    (always_of ~desired)

(* ---- (S2) SAFETY, sampled on random fair:false enabled-step traces -------- *)

(* A random enabled-step trace from [vsts_seed ~fair:false]: draw one successor
   uniformly each step (whole [enabled_successors] set, disruptor steps included),
   fuel 40, stopping early if the successor set empties. Bounded recursion;
   [List.nth_opt] keeps it total. *)
let g_trace : Cluster.cluster_state list Gen.t =
 fun rng ->
  let s0 = Scenario.vsts_seed ~desired ~fair:false in
  let rec walk fuel (s : Cluster.cluster_state)
      (acc : Cluster.cluster_state list) : Cluster.cluster_state list =
    if fuel <= 0 then List.rev acc
    else
      match Cluster.enabled_successors Bound.default Scenario.vsts_cluster s with
      | [] -> List.rev acc
      | _ :: _ as succs ->
        let idx = Gen.int_bound (List.length succs - 1) rng in
        Option.fold (List.nth_opt succs idx) ~none:(List.rev acc)
          ~some:(fun ((_step, s') : Step.t * Cluster.cluster_state) ->
            walk (fuel - 1) s' (s' :: acc))
  in
  s0 :: walk 40 s0 []

let test_safety_sampled =
  let always2 = always_of ~desired in
  QCheck.Test.make ~count:250
    ~name:"fair:false: always-conjunction holds at every state of every trace"
    (QCheck.make ~print:(fun states -> Printf.sprintf "<trace len %d>" (List.length states))
       g_trace)
    (fun states ->
      List.for_all
        (fun (s : Cluster.cluster_state) ->
          Option.fold
            (Invariants.first_violated always2 s)
            ~none:true
            ~some:(fun (i : Invariants.invariant) ->
              QCheck.Test.fail_reportf
                "always invariant %S violated on a reachable fair:false state"
                i.name))
        states)

(* ---- (V) NON-VACUITY, pinned interesting counts (vacuity disclosed) ------- *)

(* PINNED from the decisive fair:true desired=2 graph (MEASURED). A change means
   the reachable graph or an invariant's exercise surface moved and must be
   re-justified (bound-artifact / vacuity visibility, arch finding 14). The two
   zeros are the DISCLOSED honest-vacuity outcomes, not tuned away. *)
let pinned_interesting : (string * int) list =
  [
    ("etcd_objects_have_unique_uids", 38);
    ("each_object_in_etcd_is_weakly_well_formed", 50);
    ("each_object_in_etcd_has_at_most_one_controller_owner", 38);
    ("scheduled_cr_has_lower_uid_than_uid_counter", 25);
    ("triggering_cr_has_lower_uid_than_uid_counter", 44);
    ("every_ongoing_reconcile_has_unique_id", 0 (* DISCLOSED: single-CR seed => 0 here (TRUE); the >=2-concurrent witness is supplied by P12 Cluster_check.check_unique_reconcile_id_vsts *));
    ("vsts_reconcile_request_only_interferes_with_itself", 12);
    ("owned_pods_have_wellformed_ordinal_identity", 38);
    ("owned_pvcs_bound_to_vsts", 0 (* DISCLOSED: make_pvc stamps no PVC owner-ref *));
  ]

let test_non_vacuity () =
  let r = reach_fair ~desired in
  let invs = always_of ~desired in
  List.iter
    (fun (name, expected) ->
      Alcotest.(check int)
        (Printf.sprintf "interesting-count %S (pinned)" name)
        expected (interesting_of r invs name))
    pinned_interesting

(* ---- (G) MEASURED graph size + goal discrimination (pinned) --------------- *)

let pinned_states_seen = 50
let pinned_goal_reachable_true = 32

let test_measurements () =
  let r = reach_fair ~desired in
  Alcotest.(check int) "reachable states_seen (pinned)" pinned_states_seen
    (Mc.states_seen r);
  Alcotest.(check bool) "goal FALSE at the transient seed (no pods yet)" false
    (Vsts_invariants.current_state_matches (cr_of ~desired)
       (Scenario.vsts_seed ~desired ~fair:true));
  Alcotest.(check int) "goal reachable-true count (pinned converged shape)"
    pinned_goal_reachable_true
    (Mc.count_states_where r
       (Vsts_invariants.current_state_matches (cr_of ~desired)))

let () =
  Alcotest.run "p11_vsts_invariants"
    [
      ( "safety_decisive",
        [
          Alcotest.test_case
            "every always invariant holds across the whole fair:true graph"
            `Quick test_safety_decisive;
        ] );
      ( "safety_sampled_fair_false",
        [ QCheck_alcotest.to_alcotest test_safety_sampled ] );
      ( "non_vacuity",
        [
          Alcotest.test_case
            "pinned interesting-counts (vacuity disclosed)" `Quick
            test_non_vacuity;
        ] );
      ( "measurements",
        [
          Alcotest.test_case "pinned graph size + goal discrimination" `Quick
            test_measurements;
        ] );
    ]

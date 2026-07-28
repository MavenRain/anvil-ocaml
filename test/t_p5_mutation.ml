(* BUILD-SPEC P5 §4 "t_p5_mutation" — confirm-by-mutation on the ENUMERATOR
   (architecture finding 14, the non-vacuity spine; [[feedback-confirm-by-mutation]]).

   A clean [check_always] / [check_esr] run is worthless if the bounded exploration
   never actually reaches the interleavings the invariants target — a vacuous pass.
   This file proves the exploration DOES reach violating / goal-relevant states, by
   deliberately corrupting the model (a locally-built value, never shared state) so
   that a REACHABLE state trips the checker, and asserting the checker returns
   [Refuted] under the SAME bound. It is NOT a claim that production code is wrong;
   it is the guard that the bounds are non-vacuous.

   Three independent mutations (each a fresh value / local closure, so nothing in
   the tree is mutated and there is nothing to restore —
   [[feedback-review-agents-may-leave-mutations]]):

   M1 (SAFETY, corrupted seed): a duplicate-uid object is injected into the seed's
      etcd, violating [etcd_objects_have_unique_uids]. The engine's [check_safety]
      over [bounded_successors] returns [Refuted], and [violated] (computed exactly
      as the driver's [check_always] does, via [Invariants.first_violated] on the
      counterexample state) NAMES that invariant. Baseline (uncorrupted seed) is
      clean — the mutation is what flips it.

   M2 (SAFETY, reached-state witness): a synthetic wrapper invariant "the uid
      counter never advances past the seed value" is violated ONLY by a state that
      the exploration steps FORWARD into (a productive object write). [check_safety]
      returns [Refuted] and the counterexample state's [uid_counter] is strictly
      above the seed's — proving the explorer reaches productive interleavings, not
      just the seed. (This is the independent second safety mutation.)

   M3 (ESR target, confirm-by-mutation DISCRIMINATED by the bound): the ESR target
      [current_state_matches] is mutated to the always-false predicate. Both
      [Scenario.is_quiescent] AND the BUG-2 [Cluster_check.effectively_quiescent]
      are structurally unreachable here (0 reachable gate states — the reconcile is
      perpetually re-triggered), so a REACHABLE stand-in — [current_state_matches]
      itself — is the [check_reaches] gate. The mutation is non-vacuous because its
      catch tracks REACHING the goal region: under a bound generous enough to
      create the pod and update the status the always-false target REFUTES at a
      matching state (and that state genuinely satisfies [current_state_matches]),
      while under a bound too rv-starved to complete the reconcile the SAME
      always-false target is CLEAN. The bound is the mutation axis; a checker that
      never reached the goal region would be CLEAN in both, so the discrimination
      is the proof the exploration reaches it.

   Convention firewall: no loop keywords; the only matches are the exhaustive
   two-arm {!Model_check.outcome} and list [[] | _ :: _]; Option.fold for options;
   [Int.equal] not [Stdlib.(=)]. *)

module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants

let desired = 1
let cr : Vreplica_set.t = Scenario.vrs ~desired
let controller_id : int = Scenario.controller_id
let bound : Bound.t = Bound.default
let cluster : Cluster.t = Scenario.cluster
let succ = Cc.bounded_successors bound cluster
let always_invs : Invariants.invariant list = Invariants.always ~cr ~controller_id
let always_conj : Cluster.cluster_state -> bool = Invariants.conjunction always_invs

let explore_from (depth : int) (seed : Cluster.cluster_state) : Cluster.cluster_state Mc.reachable =
  Mc.explore ~depth ~successors:succ ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ seed ]

let is_no_ce (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with Mc.No_counterexample _ -> true | Mc.Refuted _ -> false

let is_refuted (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with Mc.Refuted _ -> true | Mc.No_counterexample _ -> false

(* The counterexample state = the head of the lasso loop (the bad state). *)
let bad_state_of (o : Cluster.cluster_state Mc.outcome) : Cluster.cluster_state option =
  match o with
  | Mc.No_counterexample _ -> None
  | Mc.Refuted { lasso; _ } ->
    (match Array.to_list lasso.Mc.loop with [] -> None | s :: _ -> Some s)

(* Exactly the driver's [violated_of]: which always-invariant broke at the bad state. *)
let violated_of (invs : Invariants.invariant list) (o : Cluster.cluster_state Mc.outcome) :
    Invariants.invariant option =
  Option.bind (bad_state_of o) (Invariants.first_violated invs)

(* ======================================================================== *)
(* M1: corrupted-seed safety mutation -> Refuted + violated names invariant    *)
(* ======================================================================== *)

let clean_seed : Cluster.cluster_state = Scenario.seed ~desired ~fair:false

let corrupted_seed : Cluster.cluster_state =
  let dup_key : Common.object_ref =
    { Common.kind = Vreplica_set.kind; name = "dup"; namespace = "default" }
  in
  Option.fold
    (Object_ref_map.find_opt Scenario.vrs_ref clean_seed.Cluster.api_server.Api_server.resources)
    ~none:clean_seed
    ~some:(fun (obj : Dynamic_object.t) ->
      {
        clean_seed with
        Cluster.api_server =
          {
            clean_seed.Cluster.api_server with
            Api_server.resources =
              Object_ref_map.add dup_key obj clean_seed.Cluster.api_server.Api_server.resources;
          };
      })

let test_m1_safety_corrupted_seed () =
  (* baseline: the real seed is clean under the always conjunction. *)
  let base = Mc.check_safety (explore_from 4 clean_seed) ~inv:always_conj ~equal:Cc.state_equal in
  Alcotest.(check bool) "M1 baseline: uncorrupted seed is clean (No_counterexample)" true (is_no_ce base);
  (* mutation: the duplicate-uid object makes the seed violate unique-uids. *)
  let o = Mc.check_safety (explore_from 4 corrupted_seed) ~inv:always_conj ~equal:Cc.state_equal in
  Alcotest.(check bool) "M1: corrupted seed -> Refuted" true (is_refuted o);
  Alcotest.(check bool) "M1: a violated invariant is named" true
    (Option.is_some (violated_of always_invs o));
  Option.iter
    (fun (i : Invariants.invariant) ->
      Alcotest.(check string) "M1: violated names etcd_objects_have_unique_uids"
        "etcd_objects_have_unique_uids" i.name)
    (violated_of always_invs o)

(* ======================================================================== *)
(* M2: reached-state witness — a wrapper invariant a stepped-forward state trips *)
(* ======================================================================== *)

let seed_uid : int = clean_seed.Cluster.api_server.Api_server.uid_counter

(* "the uid counter never grows past the seed" — false at any state that wrote a
   fresh object; such a state is only REACHED by stepping the reconcile forward. *)
let no_uid_growth (s : Cluster.cluster_state) : bool =
  s.Cluster.api_server.Api_server.uid_counter <= seed_uid

let test_m2_safety_reached_state () =
  let fair_seed = Scenario.seed ~desired ~fair:true in
  let o = Mc.check_safety (explore_from 20 fair_seed) ~inv:no_uid_growth ~equal:Cc.state_equal in
  Alcotest.(check bool) "M2: a reachable state advances the uid counter -> Refuted" true (is_refuted o);
  Alcotest.(check bool) "M2: a counterexample state exists" true (Option.is_some (bad_state_of o));
  Option.iter
    (fun (s : Cluster.cluster_state) ->
      Alcotest.(check bool)
        "M2: the counterexample state's uid_counter is STRICTLY above the seed (forward interleaving reached)"
        true (s.Cluster.api_server.Api_server.uid_counter > seed_uid))
    (bad_state_of o)

(* ======================================================================== *)
(* M3: ESR target mutation (surrogate quiescence = the reachable goal region)   *)
(* ======================================================================== *)

(* A bound generous enough to CREATE the pod and UPDATE the status, so the fair
   reconcile reaches [current_state_matches]; and one too rv-starved to complete. *)
let generous_bound : Bound.t =
  {
    Bound.max_in_flight = 4;
    max_objects_per_kind = 4;
    max_controllers = 1;
    uid_ceiling = 4;
    rv_ceiling = 6;
    reconcile_ceiling = 8;
    max_reconcile_depth = 8;
    monkey_forge = [];
  }

let tight_bound : Bound.t =
  {
    Bound.max_in_flight = 2;
    max_objects_per_kind = 2;
    max_controllers = 1;
    uid_ceiling = 2;
    rv_ceiling = 1;
    reconcile_ceiling = 8;
    max_reconcile_depth = 4;
    monkey_forge = [];
  }

let explore_with (b : Bound.t) (depth : int) (seed : Cluster.cluster_state) :
    Cluster.cluster_state Mc.reachable =
  Mc.explore ~depth ~successors:(Cc.bounded_successors b cluster) ~equal:Cc.state_equal
    ~hash:Cc.state_hash ~init:[ seed ]

let test_m3_esr_target () =
  let goal : Invariants.invariant = Invariants.liveness_goal ~cr in
  let fair_seed = Scenario.seed ~desired ~fair:true in
  (* honest baseline: the driver's check_esr is clean, but that is a VACUOUS
     universal (0 reachable effectively_quiescent gate states; asserted in
     t_p5_cluster_check's liveness_gap). Here the non-vacuity is the discriminator. *)
  Alcotest.(check bool) "M3 baseline: check_esr is clean (honest, but a vacuous universal)" true
    (is_no_ce (Cc.check_esr ~depth:14 generous_bound ~desired).outcome);
  (* mutation, generous bound: always-false target REFUTES at a reachable matching
     state -> the goal region IS reached and the real predicate IS exercised. *)
  let reach_g = explore_with generous_bound 14 fair_seed in
  let mut_g = Mc.check_reaches reach_g ~target:(fun _ -> false) ~quiescent:goal.holds ~equal:Cc.state_equal in
  Alcotest.(check bool) "M3: mutated (always-false) target -> Refuted under generous bound (goal reached)" true (is_refuted mut_g);
  Option.iter
    (fun (s : Cluster.cluster_state) ->
      Alcotest.(check bool) "M3: the refuting state actually satisfies current_state_matches (real predicate exercised)"
        true (goal.holds s))
    (bad_state_of mut_g);
  (* DISCRIMINATOR: under the rv-starved tight bound the reconcile cannot complete,
     [current_state_matches] is unreachable, so the SAME always-false target is
     CLEAN — proving the Refuted above genuinely tracks reaching the goal region. *)
  let reach_t = explore_with tight_bound 20 fair_seed in
  let mut_t = Mc.check_reaches reach_t ~target:(fun _ -> false) ~quiescent:goal.holds ~equal:Cc.state_equal in
  Alcotest.(check bool) "M3 discriminator: rv-starved bound cannot reach the goal -> always-false target is CLEAN" true (is_no_ce mut_t)

let () =
  Alcotest.run "p5_mutation"
    [
      ("M1_safety_corrupted_seed", [ Alcotest.test_case "corrupted seed -> Refuted + violated names invariant" `Quick test_m1_safety_corrupted_seed ]);
      ("M2_safety_reached_state", [ Alcotest.test_case "reached forward state trips wrapper invariant" `Quick test_m2_safety_reached_state ]);
      ("M3_esr_target", [ Alcotest.test_case "mutated ESR target -> Refuted over reachable goal region" `Quick test_m3_esr_target ]);
    ]

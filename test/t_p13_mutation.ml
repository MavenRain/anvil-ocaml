(* BUILD-SPEC-P13 section 6 - the confirm-by-mutation matrix for the fault legs.

   A clean, decisive [No_counterexample] out of [t_p13_faults] is evidence only if
   the fault machinery would MOVE when the thing it measures breaks. This exe
   supplies that evidence for the three AUTOMATED pins M3 / M4 / M5. The two
   MANUAL mutants M1 / M2 are real-source mutants of [lib/cluster/cluster.ml]:
   they were applied with the Edit tool, MEASURED, and REVERTED, so only the green
   tree ships ([git diff --stat lib/cluster/] is empty). Their measurements are
   recorded below, because the M1 result CONTRADICTS the spec's prediction and
   that contradiction is a load-bearing fact about what this phase can and cannot
   detect.

   ---- M1 (MANUAL, real source, NOT shipped) ---------------------------------

   Mutant: in [restart_controller] (lib/cluster/cluster.ml:309, Anvil
   cluster.rs:377) replace [Controller.ongoing_reconciles = Object_ref_map.empty]
   with [cae.controller.ongoing_reconciles], i.e. a controller restart no longer
   forgets the reconciles that were in flight when it crashed.

   BUILD-SPEC-P13 section 6 PREDICTED that G1 refutes ("a pre-crash ongoing
   reconcile survives a restart"). MEASURED: it does NOT. All three legs stay
   [No_counterexample], decisive, [violated = None]:

     leg  baseline states / gate      M1 states / gate     settled_with_faults_live
     G1   464 / 388                   152 / 76             10 -> 2
     G2   10552 / 2784                7728 / 2784          85 -> 8
     G3   1856 / 10                   608 / 2              30 -> 6

   So no member of the shipped nine-invariant VSTS [always] suite is sensitive to
   this mutation, and the reason is structural rather than incidental: every
   invariant in the suite is either etcd-local ([etcd_objects_have_unique_uids],
   [each_object_in_etcd_is_weakly_well_formed],
   [each_object_in_etcd_has_at_most_one_controller_owner],
   [owned_pods_have_wellformed_ordinal_identity], [owned_pvcs_bound_to_vsts]) or
   monotone in the uid / id counters ([scheduled_cr_has_lower_uid_than_uid_counter],
   [triggering_cr_has_lower_uid_than_uid_counter],
   [every_ongoing_reconcile_has_unique_id]) or about request interference
   ([vsts_reconcile_request_only_interferes_with_itself]). Carrying a pre-crash
   ongoing reconcile forward violates none of them: the surviving entries keep
   their already-distinct ids and their already-lower uids. What M1 breaks is a
   TRANSITION-relation fact ("restart clears the controller's in-flight work"),
   and a state-invariant suite cannot express that.

   M1 IS nonetheless caught, by the pinned reachable-set metadata: [t_p13_faults]
   fails 3 of its 9 cases, first at t_p13_faults.ml:474 "G1: states (pinned)",
   [Expected 464 / Received 152]. That is the honest reading of the phase: for
   transition-level faithfulness the discriminator is the pinned shape of the
   reachable set, not a refutation. (Note G2's gate count is UNCHANGED at 2784
   under M1, so a gate-only pin would have missed it; the state and
   crash-witness pins are the ones doing the work.)

   ---- M2 (MANUAL, real source, NOT shipped) ---------------------------------

   Mutant: in the same record replace [reconcile_id_allocator =
   cae.controller.reconcile_id_allocator] with
   [Controller.Reconcile_id_allocator.init ()], i.e. a restart resets the id
   allocator, where upstream deliberately preserves it (cluster.rs:388-392).

   PREDICTION (section 6): G2 does NOT refute, because a restart CLEARS
   [ongoing_reconciles], so the post-crash epoch re-allocates from 0 into an EMPTY
   map and the ids in [ongoing_reconciles] stay pairwise distinct. MEASURED: the
   prediction HOLDS. G2 is [No_counterexample] with [violated = None] at every
   depth measured - depth 14: 8480 states (baseline 5310), depth 18: 37530
   (baseline 9440); at the shipped depth 40 the mutant no longer finishes inside
   the 150 s harness alarm (142.47 s CPU, killed), where the baseline is decisive
   in 6.1 s.

   So inv6 [every_ongoing_reconcile_has_unique_id] is INSENSITIVE to allocator
   reset, exactly as section 6 said, and no crash adversary for inv6 is claimed
   here (none was measured, and section 6 forbids inventing one).

   Where the sensitivity actually lives, MEASURED: in DECISIVENESS, not in a
   refutation. [Bound.reconcile_ceiling] prunes on
   [Controller.Reconcile_id_allocator.reconcile_count] (BUILD-SPEC-P8 section
   3.2), so resetting the allocator hands the post-crash epoch a fresh pass
   allowance and the frontier stops emptying: G1 goes 464 states / decisive to
   1191 states / NON-decisive, G3 goes 1856 / decisive to 4744 / NON-decisive,
   both still [violated = None]. [t_p13_faults] therefore reddens on M2 at a
   SEMANTIC assertion, t_p13_faults.ml:430 "G1: outcome decisive (frontier
   emptied)", [Expected true / Received false] - which is precisely why section
   4.5 mandates semantic-before-pinned ordering.

   ---- M3 / M4 / M5 (AUTOMATED, permanent) -----------------------------------

   M3 the crash FLAG is load-bearing (model precondition), M4 the crash BUDGET is
   load-bearing (checker clip), M5 the twelve-arm classifier is load-bearing (a
   wildcard arm would silently uncharge the crash). Each is verified to
   DISCRIMINATE: it carries its own positive control in the same test, so the
   assertion cannot pass by being vacuously zero.

   Every pinned number comes from [P13_witness]; none is re-typed here.

   Firewall honoured: List/Option/fold combinators only (no loop keywords), no
   wildcard arm on any finite sum (the mis-classifying [Step.t] match below writes
   out all twelve constructors), no [List.nth]/[hd]/[tl], no
   [raise]/[assert]/[failwith]/[Option.get], Alcotest as the sanctioned failure
   primitive. *)

module Fc = Anvil_checker.Fault_check
module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vsts_invariants = Anvil_assurance.Vsts_invariants

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let single_bound : Bound.t = P13_witness.p13_bound ~desireds:[ P13_witness.witness_desired ]
let multi_bound : Bound.t = P13_witness.p13_bound ~desireds:P13_witness.witness_desireds

(* ---- shared readers over an outcome / report (no two-arm option match) ---- *)

let is_clean (o : Fc.faulted Mc.outcome) : bool =
  match o with Mc.No_counterexample _ -> true | Mc.Refuted _ -> false

let decisive (o : Fc.faulted Mc.outcome) : bool =
  match o with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let states_of (o : Fc.faulted Mc.outcome) : int =
  match o with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let gate_of (r : Fc.fault_report) : int = Option.value r.gate_states ~default:(-1)

let inv_name (i : Invariants.invariant option) : string =
  Option.fold ~none:"None" ~some:(fun (v : Invariants.invariant) -> v.name) i

(* ---- shared exploration of the product graph -------------------------------

   The same wiring [Fault_check.run_leg] uses (fault_check.ml:274-279), reproduced
   here because the gates take no fault flags and no custom successor relation:
   M3 needs a [~crash:false] seed and M5 needs a mis-classifying successor
   relation, neither of which is reachable through the three shipped gates, and
   BUILD-SPEC-P13 section 4.3 fixes the exported interface (so widening it for the
   tests is not an option). *)

let explore_with (successors : Fc.faulted -> Fc.faulted list)
    (seed : Cluster.cluster_state) : Fc.faulted Mc.reachable =
  Mc.explore ~depth:P13_witness.witness_depth ~successors
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed seed ]

let total_states (r : Fc.faulted Mc.reachable) : int =
  Mc.count_states_where r (fun (_ : Fc.faulted) -> true)

let crash_witness_states (r : Fc.faulted Mc.reachable) : int =
  Mc.count_states_where r (fun (f : Fc.faulted) -> f.crashes >= 1)

let max_crashes_seen (r : Fc.faulted Mc.reachable) : int =
  Mc.fold_states r ~init:0 ~f:(fun (acc : int) (f : Fc.faulted) ->
      Int.max acc f.crashes)

(* ==== M3: the crash FLAG is load-bearing (vacuity detector) ================= *)

(* BUILD-SPEC-P13 section 6 M3: "the same gate seeded [~crash:false] MUST report
   [crash_witness_states = 0] and [gate_states = Some 0]".

   The three gates hardcode [~crash:true] in their seeds and expose no fault
   flags, so this is run through the exported core ([faulted_of_seed] +
   [faulted_successors] + [Model_check.explore]) with G1's own gate predicate
   replicated locally. The replica is validated, not assumed: on the
   [~crash:true] seed it MUST reproduce {!P13_witness.g1_gate_states}, the count
   the real [check_invariants_under_faults] gate returns.

   Why the flag alone must kill the dimension: [Restart_controller_step]'s
   precondition (cluster.ml:293-298, Anvil cluster.rs:377) requires the
   per-controller [crash_enabled] flag, so with the flag down the edge is never
   ENABLED - no budget is involved. That is the difference from M4. *)

let g1_invs : Invariants.invariant list =
  Vsts_invariants.always
    ~cr:(Scenario.vsts ~desired:P13_witness.witness_desired ())
    ~controller_id

let g1_gate_pred (f : Fc.faulted) : bool =
  f.crashes >= 1
  && List.exists (fun (i : Invariants.invariant) -> i.interesting f.cs) g1_invs

let m3_reach (crash : bool) : Fc.faulted Mc.reachable =
  explore_with
    (Fc.faulted_successors single_bound P13_witness.witness_budget cluster)
    (Scenario.vsts_seed_faults ~desired:P13_witness.witness_desired ~crash
       ~req_drop:false ~pod_monkey:false ())

let test_m3_crash_flag_load_bearing () =
  let off = m3_reach false in
  let on = m3_reach true in
  (* SEMANTIC FIRST. (1) The [~crash:false] graph is non-empty, so its zeroes are
     a real absence of crashes and not an empty exploration. *)
  Alcotest.(check bool)
    "M3 crash:false graph is NON-EMPTY (zeroes are not vacuous)" true
    (total_states off > 0);
  (* (2) The POSITIVE control: with the identical bound, budget and successor
     relation, the [~crash:true] seed DOES witness crashes and DOES populate the
     gate. This is the discrimination: the two runs differ only in the flag. *)
  Alcotest.(check bool) "M3 crash:true positive control: post-crash states > 0"
    true
    (crash_witness_states on > 0);
  Alcotest.(check bool) "M3 crash:true positive control: gate > 0" true
    (Mc.count_states_where on g1_gate_pred > 0);
  (* (3) The pin itself: the crash dimension VANISHES with the flag down. *)
  Alcotest.(check int) "M3 crash:false: crash_witness_states = 0"
    P13_witness.m3_crash_free_crash_witness_states (crash_witness_states off);
  Alcotest.(check int) "M3 crash:false: gate_states = 0"
    P13_witness.m3_crash_free_gate_states (Mc.count_states_where off g1_gate_pred);
  Alcotest.(check int) "M3 crash:false: max_crashes_seen = 0" 0
    (max_crashes_seen off);
  (* (4) Brittle exact counts LAST. The [~crash:true] control reproduces the real
     G1 graph and the real G1 gate, which validates the local replica. *)
  Alcotest.(check int) "M3 crash:false: states (pinned)"
    P13_witness.m3_crash_free_states (total_states off);
  Alcotest.(check int) "M3 crash:true: states = the G1 graph (pinned)"
    P13_witness.g1_states (total_states on);
  Alcotest.(check int) "M3 local gate replica = the real G1 gate (pinned)"
    P13_witness.g1_gate_states
    (Mc.count_states_where on g1_gate_pred)

(* ==== M4: the crash BUDGET is load-bearing ================================== *)

(* BUILD-SPEC-P13 section 6 M4: "[max_crashes = 0] MUST give
   [crash_witness_states = 0] and [pruned_by_budget = true]".

   Unlike M3 this goes through the REAL gate - [budget] is a positional parameter
   of [check_invariants_under_faults], so the whole shipped leg can be re-run with
   every cap at zero. The seed still has [crash_enabled = true], so the crash edge
   is ENABLED and then CLIPPED: [pruned_by_budget = true] is the checker admitting
   it truncated the graph, and [crash_witness_states = 0] is the consequence. *)

let test_m4_zero_budget_clips_crash () =
  let zero =
    Fc.check_invariants_under_faults ~depth:P13_witness.witness_depth
      single_bound P13_witness.zero_budget ~desired:P13_witness.witness_desired
  in
  let funded =
    Fc.check_invariants_under_faults ~depth:P13_witness.witness_depth
      single_bound P13_witness.witness_budget ~desired:P13_witness.witness_desired
  in
  (* SEMANTIC FIRST: the zero-budget run is still a real, clean, decisive check
     over a non-empty graph - the pin below reports an absent adversary, not a
     broken run. *)
  Alcotest.(check bool) "M4 zero budget: outcome clean" true (is_clean zero.outcome);
  Alcotest.(check bool) "M4 zero budget: outcome decisive" true
    (decisive zero.outcome);
  Alcotest.(check string) "M4 zero budget: violated = None" "None"
    (inv_name zero.violated);
  Alcotest.(check bool) "M4 zero budget: graph is NON-EMPTY" true
    (states_of zero.outcome > 0);
  (* The POSITIVE control: the same gate at [budget_crash_only] DOES witness a
     crash, so the zero-budget zeroes are attributable to the cap. *)
  Alcotest.(check bool) "M4 positive control: funded budget witnesses a crash"
    true
    (funded.crash_witness_states > 0 && funded.max_crashes_seen >= 1);
  (* The pin: caps at zero clip the fault edge and say so. *)
  Alcotest.(check int) "M4 zero budget: crash_witness_states = 0"
    P13_witness.m4_zero_budget_crash_witness_states zero.crash_witness_states;
  Alcotest.(check int) "M4 zero budget: gate_states = Some 0"
    P13_witness.m4_zero_budget_gate_states (gate_of zero);
  Alcotest.(check int) "M4 zero budget: max_crashes_seen = 0" 0
    zero.max_crashes_seen;
  Alcotest.(check bool) "M4 zero budget: pruned_by_budget = true (cap bit)" true
    zero.pruned_by_budget;
  (* Brittle counts LAST. The zero-budget reachable set IS the fault-free slice of
     the G1 graph (all three caps at 0 admit exactly the non-fault edges), so this
     is a cross-check against an existing pin rather than a new one. *)
  Alcotest.(check int) "M4 zero-budget graph = G1's fault-free slice (pinned)"
    P13_witness.g1_fault_free_states (states_of zero.outcome);
  Alcotest.(check int) "M4 positive control: crash_witness_states (pinned)"
    P13_witness.g1_crash_witness_states funded.crash_witness_states

(* ==== M5: the twelve-arm classifier is load-bearing ========================= *)

(* BUILD-SPEC-P13 section 6 M5: a local copy of [faulted_successors] that
   mis-classifies [Step.Restart_controller_step] as a non-fault must be caught -
   with it [max_crashes_seen] stays 0 while restart edges are still taken, so the
   REAL classifier must give [max_crashes_seen >= 1] on the G2 graph.

   This is the defect a wildcard [_ ->] arm would introduce, which is why
   [Fault_check.step_dimension] writes out all twelve constructors and why this
   copy does too: the mutant differs from the real classifier in EXACTLY one arm
   ([Restart_controller_step _ -> None] instead of [Some Crashes]). *)

type dimension = Crashes | Drops | Monkeys

(* Constructor spelling and arm order copied from [Fault_check.step_dimension]
   (fault_check.ml:74-88), which in turn copies [Scenario.productive_successors]
   (lib/assurance/scenario.ml:660-679). THE MUTATION is the
   [Restart_controller_step] arm. *)
let mis_dimension (step : Step.t) : dimension option =
  match step with
  | Step.Api_server_step _
  | Step.Builtin_controllers_step _
  | Step.Controller_step _
  | Step.Schedule_controller_reconcile_step _ ->
      None
  | Step.Pod_monkey_step _ -> Some Monkeys
  | Step.External_step _ -> None
  | Step.Restart_controller_step _ -> None (* THE MUTATION: should be Crashes *)
  | Step.Disable_crash_step _ -> None
  | Step.Drop_req_step _ -> Some Drops
  | Step.Disable_req_drop_step | Step.Disable_pod_monkey_step | Step.Stutter_step
    ->
      None

(* The FAITHFUL copy of the same classifier, written out beside the mutant so the
   single-arm difference is readable at a glance. It is used only to RECOGNISE the
   crash edge for the "restart edges are still taken" half of M5; the load-bearing
   assertion about the real classifier goes through the exported
   [Fault_check.faulted_successors] itself, never through this copy. *)
let real_dimension (step : Step.t) : dimension option =
  match step with
  | Step.Api_server_step _
  | Step.Builtin_controllers_step _
  | Step.Controller_step _
  | Step.Schedule_controller_reconcile_step _ ->
      None
  | Step.Pod_monkey_step _ -> Some Monkeys
  | Step.External_step _ -> None
  | Step.Restart_controller_step _ -> Some Crashes
  | Step.Disable_crash_step _ -> None
  | Step.Drop_req_step _ -> Some Drops
  | Step.Disable_req_drop_step | Step.Disable_pod_monkey_step | Step.Stutter_step
    ->
      None

let is_restart_step (step : Step.t) : bool =
  real_dimension step
  |> Option.fold ~none:false ~some:(fun (dim : dimension) ->
         match dim with Crashes -> true | Drops | Monkeys -> false)

let mis_charge (b : Fc.budget) (f : Fc.faulted) (cs : Cluster.cluster_state)
    (dim : dimension) : Fc.faulted option =
  match dim with
  | Crashes ->
      let crashes = f.crashes + 1 in
      if crashes > b.max_crashes then None
      else Some { Fc.cs; crashes; drops = f.drops; monkeys = f.monkeys }
  | Drops ->
      let drops = f.drops + 1 in
      if drops > b.max_drops then None
      else Some { Fc.cs; crashes = f.crashes; drops; monkeys = f.monkeys }
  | Monkeys ->
      let monkeys = f.monkeys + 1 in
      if monkeys > b.max_monkey_ops then None
      else Some { Fc.cs; crashes = f.crashes; drops = f.drops; monkeys }

let mis_successors (bound : Bound.t) (b : Fc.budget) (cl : Cluster.t)
    (f : Fc.faulted) : Fc.faulted list =
  List.filter_map
    (fun (((step : Step.t), (cs : Cluster.cluster_state)) :
           Step.t * Cluster.cluster_state) ->
      Option.fold ~none:(Some { f with Fc.cs }) ~some:(mis_charge b f cs)
        (mis_dimension step))
    (Cc.bounded_labelled_successors bound cl f.cs)

let restart_edge_state (bound : Bound.t) (f : Fc.faulted) : bool =
  List.exists
    (fun (((step : Step.t), (_ : Cluster.cluster_state)) :
           Step.t * Cluster.cluster_state) -> is_restart_step step)
    (Cc.bounded_labelled_successors bound cluster f.cs)

let g2_seed : Cluster.cluster_state =
  Scenario.vsts_seed_multi_faults ~desireds:P13_witness.witness_desireds
    ~crash:true ~req_drop:false ~pod_monkey:false

let test_m5_classifier_load_bearing () =
  let real =
    explore_with
      (Fc.faulted_successors multi_bound P13_witness.witness_budget cluster)
      g2_seed
  in
  let mis =
    explore_with
      (mis_successors multi_bound P13_witness.witness_budget cluster)
      g2_seed
  in
  (* SEMANTIC FIRST, load-bearing half: the REAL classifier charges the crash on
     the G2 graph, so every [crashes >= 1] witness in [t_p13_faults] rests on a
     counter that actually moves. *)
  Alcotest.(check bool) "M5 REAL classifier: max_crashes_seen >= 1" true
    (max_crashes_seen real >= 1);
  Alcotest.(check bool) "M5 REAL classifier: post-crash slice non-empty" true
    (crash_witness_states real > 0);
  (* SEMANTIC, mutant half: the restart edges ARE still there under the
     mis-classifier (so its 0 is blindness, not an absence of restarts) ... *)
  Alcotest.(check bool)
    "M5 mutant graph is NON-EMPTY (blindness, not an empty run)" true
    (total_states mis > 0);
  Alcotest.(check bool)
    "M5 mutant: restart edges are STILL enumerated (uncharged, not absent)" true
    (Mc.count_states_where mis (restart_edge_state multi_bound) > 0);
  (* ... and yet the mutant's counter never moves: exactly the defect a wildcard
     [_ ->] arm would hide. *)
  Alcotest.(check int) "M5 mutant: max_crashes_seen stays 0 (caught)"
    P13_witness.m5_misclassified_max_crashes (max_crashes_seen mis);
  Alcotest.(check int) "M5 mutant: crash_witness_states stays 0 (caught)" 0
    (crash_witness_states mis);
  (* Brittle exact counts LAST. The real half reuses the G2 pins; only the mutant
     graph needs its own. *)
  Alcotest.(check int) "M5 REAL: max_crashes_seen (pinned)"
    P13_witness.g2_max_crashes_seen (max_crashes_seen real);
  Alcotest.(check int) "M5 REAL: states = the G2 graph (pinned)"
    P13_witness.g2_states (total_states real);
  Alcotest.(check int) "M5 REAL: crash_witness_states (pinned)"
    P13_witness.g2_crash_witness_states (crash_witness_states real);
  Alcotest.(check int) "M5 mutant: states (pinned)"
    P13_witness.m5_misclassified_states (total_states mis);
  Alcotest.(check int) "M5 mutant: states with a restart edge (pinned)"
    P13_witness.m5_misclassified_restart_edge_states
    (Mc.count_states_where mis (restart_edge_state multi_bound))

let () =
  Alcotest.run "p13_mutation"
    [
      ( "m3_crash_flag",
        [
          Alcotest.test_case
            "crash:false kills the crash dimension (vacuity detector)" `Quick
            test_m3_crash_flag_load_bearing;
        ] );
      ( "m4_crash_budget",
        [
          Alcotest.test_case "max_crashes = 0 clips the crash edge and says so"
            `Quick test_m4_zero_budget_clips_crash;
        ] );
      ( "m5_classifier",
        [
          Alcotest.test_case
            "mis-classifying Restart_controller_step is caught" `Quick
            test_m5_classifier_load_bearing;
        ] );
    ]

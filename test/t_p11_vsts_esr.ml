(* BUILD-SPEC-P11 §5 / §8 "t_p11_vsts_esr" — the VStatefulSet checker-entry-point
   suite: the VSTS siblings of the P5/P8 [t_p5_cluster_check] / [t_p8_settle]
   verdicts, demonstrating the generic BMC engine + the P6/P8 discharge machinery
   GENERALIZE to a second controller.

   MEASURED-AND-PINNED (desired = 1, the §7.2 settling bound, depth 40):
   - {!Cc.check_esr_settled_vsts}: [No_counterexample {decisive = true}],
     [gate_states = Some 1] (POSITIVE — the VSTS settled ESR gate is reachable and
     NON-VACUOUS), [max_uid_seen = 3 < 4], [max_rv_seen = 2 < 5] (STRICTLY below
     the ceilings — the bound-artifact guard, §7.3: a [Refuted] would be
     interpretable), [pruned = true] (the 2nd reconcile pass was clipped by
     [reconcile_ceiling = 1]). Raising uid/rv ceilings leaves the gate at [Some 1]
     and the maxima unchanged (3, 2) — the count is real, not a ceiling artifact.
   - {!Cc.check_esr_temporal_vsts} AGREES with it (same CLASS + [decisive]).
   - {!Cc.check_esr_vsts} (the honest VACUOUS companion): [gate_states = Some 0] —
     the unpruned {!Cc.effectively_quiescent_vsts} gate is structurally unreachable
     on the perpetually re-triggered model (P8 discipline; the contrast is what is
     under test, not a verdict).
   - {!Cc.check_always_vsts} (safety, [~fair:false]): clean, no invariant broken,
     but [decisive = false] — the full-nondeterminism graph does NOT fixpoint at
     feasible depth (pod-monkey allocates fresh rpc ids with no rpc ceiling; the
     REGIME NOTE / VRS [t_p5_cluster_check] precedent). The DECISIVE clean safety
     verdict is on the BFS-able [~fair:true] graph (20 reachable states) — the
     Stage-2 "decisive ~fair:true BFS for safety" regime, mirrored here.

   HONEST LIMITS (BUILD-SPEC-P11 §10): every verdict is falsification-up-to
   (depth, {!Bound.t}); [decisive] verifies only the bounded system, never Anvil's
   Verus theorem. The settled leg witnesses a BOUNDED number of reconcile passes
   settling to the ordinal-stable match, never the perpetual re-reconcile.

   Convention: no loop keywords (List folds); no [_ ->] wildcard (only exhaustive
   two-arm {!Mc.outcome} matches); Option.fold for options; [Int.equal]. *)

module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Vi = Anvil_assurance.Vsts_invariants
module Invariants = Anvil_assurance.Invariants

(* The §7.2 VSTS settling bound (MEASURED to reach [Done] + match in ONE pass;
   [reconcile_ceiling = 1] isolates the first pass, uid/rv ceilings never fire —
   the maxima land strictly below them). *)
let settling_bound : Bound.t =
  {
    Bound.max_in_flight = 2;
    max_objects_per_kind = 2;
    max_controllers = 1;
    uid_ceiling = 4;
    rv_ceiling = 5;
    reconcile_ceiling = 1;
    max_reconcile_depth = 8;
  }

let depth = 40

(* ---- outcome accessors (two-arm match = exhaustive enumeration of the SUM,
   not an option/result) ---- *)

let is_no_ce (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with Mc.No_counterexample _ -> true | Mc.Refuted _ -> false

let decisive_of (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with
  | Mc.No_counterexample { decisive } -> decisive
  | Mc.Refuted _ -> false

let class_tag (o : Cluster.cluster_state Mc.outcome) : string =
  match o with
  | Mc.No_counterexample _ -> "No_counterexample"
  | Mc.Refuted _ -> "Refuted"

let gate_eq (n : int) (o : int option) : bool =
  Option.fold ~none:false ~some:(fun m -> Int.equal m n) o

(* ---- (1) SAFETY. The [~fair:false] entry point is clean + no invariant broken,
   and HONESTLY [decisive = false] (its graph never fixpoints); the DECISIVE clean
   safety verdict is the [~fair:true] BFS leg (mirrors t_p8_settle test 6). ---- *)

let test_always_vsts_clean_and_decisive_fair () =
  let desired = 1 in
  (* entry point: full nondeterminism, shallow (depth 40 explodes — REGIME NOTE) *)
  let r : Cc.report = Cc.check_always_vsts ~depth:6 settling_bound ~desired in
  Alcotest.(check bool) "check_always_vsts clean (No_counterexample)" true
    (is_no_ce r.outcome);
  Alcotest.(check bool) "no VSTS invariant violated" true
    (Option.is_none r.violated);
  Alcotest.(check bool)
    "check_always_vsts decisive = FALSE (fair:false graph never fixpoints)" false
    (decisive_of r.outcome);
  (* decisive safety on the BFS-able fair:true graph (the Stage-2 regime) *)
  let cr = Scenario.vsts ~desired () in
  let inv =
    Invariants.conjunction (Vi.always ~cr ~controller_id:Scenario.controller_id)
  in
  let seed = Scenario.vsts_seed ~desired ~fair:true in
  let reach =
    Mc.explore ~depth
      ~successors:(Cc.bounded_successors settling_bound Scenario.vsts_cluster)
      ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ seed ]
  in
  let o = Mc.check_safety reach ~inv ~equal:Cc.state_equal in
  Alcotest.(check bool) "fair:true BFS safety clean" true (is_no_ce o);
  Alcotest.(check bool) "fair:true BFS safety DECISIVE (frontier emptied)" true
    (decisive_of o);
  Alcotest.(check int) "fair:true reachable-state count = 20 (MEASURED)" 20
    (Mc.states_seen reach)

(* ---- (2) the NON-VACUOUS settled ESR gate: gate_states = Some 1 (MEASURED and
   PINNED), clean, decisive, pruned. ---- *)

let test_esr_settled_vsts_nonvacuous () =
  let desired = 1 in
  let r : Cc.report = Cc.check_esr_settled_vsts ~depth settling_bound ~desired in
  Alcotest.(check bool) "gate_states = Some 1 (POSITIVE — NON-VACUOUS, MEASURED)"
    true (gate_eq 1 r.gate_states);
  Alcotest.(check bool) "check_esr_settled_vsts clean (No_counterexample)" true
    (is_no_ce r.outcome);
  Alcotest.(check bool) "decisive = true (frontier emptied on the fair graph)" true
    (decisive_of r.outcome);
  Alcotest.(check bool)
    "pruned = true (the 2nd reconcile pass clipped by reconcile_ceiling = 1)" true
    r.pruned

(* ---- (3) the bound-artifact guard (§7.3): the uid/rv ceilings never fired, so a
   settled Refuted (had there been one) would be a REAL non-match, not a starved
   artifact. STRICT < is the falsifiable form (collect_metadata folds maxima over
   in-ceiling states, so <= is tautological). ---- *)

let test_esr_settled_maxima_strictly_below_ceilings () =
  let desired = 1 in
  let r : Cc.report = Cc.check_esr_settled_vsts ~depth settling_bound ~desired in
  Alcotest.(check int) "max_uid_seen = 3 (MEASURED)" 3 r.max_uid_seen;
  Alcotest.(check int) "max_rv_seen = 2 (MEASURED)" 2 r.max_rv_seen;
  Alcotest.(check bool) "max_uid_seen STRICTLY below uid_ceiling (never fired)" true
    (r.max_uid_seen < settling_bound.uid_ceiling);
  Alcotest.(check bool) "max_rv_seen STRICTLY below rv_ceiling (never fired)" true
    (r.max_rv_seen < settling_bound.rv_ceiling)

(* ---- (4) the formula-faithful temporal cross-check AGREES with the settled leg
   on both CLASS and [decisive]. ---- *)

let test_temporal_agrees_with_settled () =
  let desired = 1 in
  let settled : Cc.report =
    Cc.check_esr_settled_vsts ~depth settling_bound ~desired
  in
  let temporal : Cc.report =
    Cc.check_esr_temporal_vsts ~depth settling_bound ~desired
  in
  Alcotest.(check string) "CLASS agrees (settled vs temporal)"
    (class_tag settled.outcome) (class_tag temporal.outcome);
  Alcotest.(check bool) "decisive flag agrees (settled vs temporal)" true
    (Bool.equal (decisive_of settled.outcome) (decisive_of temporal.outcome));
  (* pin the shared verdict so a future drift is visible *)
  Alcotest.(check bool) "both No_counterexample" true
    (is_no_ce settled.outcome && is_no_ce temporal.outcome);
  Alcotest.(check bool) "both decisive" true
    (decisive_of settled.outcome && decisive_of temporal.outcome)

(* ---- (4b) NON-VACUITY of the temporal cross-check (the P11 review fix). The
   fairness filter {!Cc.fair_lasso_vsts} admits a fair pure-stutter loop ONLY at a
   {!Cc.settled} state (the ceiling-pruned P8 quiescence, reachable — gate = Some
   1), so the ESR formula is genuinely evaluated there. A deliberately-broken
   target [fun _ _ -> false] therefore FLIPS the verdict to [Refuted] (the fair
   settled stutter fails the goal), proving the clean verdict on the real target is
   corroboration, not a goal-independent tautology. (Before the fix — fairness gated
   on the unreachable [effectively_quiescent_vsts] — this stayed clean for ANY
   target, the vacuity the review caught.) ---- *)

let test_temporal_nonvacuous_on_broken_target () =
  let desired = 1 in
  let real : Cc.report =
    Cc.check_esr_temporal_vsts ~depth settling_bound ~desired
  in
  let broken : Cc.report =
    Cc.check_esr_temporal_vsts ~depth
      ~current_state_matches:(fun _ _ -> false)
      settling_bound ~desired
  in
  Alcotest.(check bool) "real target: clean (No_counterexample)" true
    (is_no_ce real.outcome);
  Alcotest.(check bool)
    "broken target [fun _ _ -> false]: Refuted (leg is NOT goal-independent)" false
    (is_no_ce broken.outcome)

(* ---- (5) the honest VACUOUS companion: gate_states = Some 0 pinned (the
   unpruned quiescence gate is structurally unreachable — the settled-vs-unsettled
   contrast made VISIBLE, P8 discipline). ---- *)

let test_esr_vsts_honestly_vacuous () =
  let desired = 1 in
  let r : Cc.report = Cc.check_esr_vsts ~depth settling_bound ~desired in
  Alcotest.(check bool)
    "gate_states = Some 0 (VACUOUS — unpruned quiescence unreachable, PINNED)" true
    (gate_eq 0 r.gate_states)

let () =
  Alcotest.run "p11_vsts_esr"
    [
      ( "always_vsts",
        [
          Alcotest.test_case
            "check_always_vsts clean; fair:true BFS safety decisive (20 states)"
            `Quick test_always_vsts_clean_and_decisive_fair;
        ] );
      ( "esr_settled_vsts_nonvacuous",
        [
          Alcotest.test_case "gate_states = Some 1, clean, decisive, pruned" `Quick
            test_esr_settled_vsts_nonvacuous;
        ] );
      ( "esr_settled_vsts_bound_artifact_guard",
        [
          Alcotest.test_case
            "max_uid = 3, max_rv = 2, STRICTLY below ceilings" `Quick
            test_esr_settled_maxima_strictly_below_ceilings;
        ] );
      ( "temporal_agrees",
        [
          Alcotest.test_case
            "check_esr_temporal_vsts AGREES (class + decisive) with settled" `Quick
            test_temporal_agrees_with_settled;
        ] );
      ( "temporal_nonvacuous",
        [
          Alcotest.test_case
            "broken target flips check_esr_temporal_vsts to Refuted (non-vacuous)"
            `Quick test_temporal_nonvacuous_on_broken_target;
        ] );
      ( "esr_vsts_vacuous",
        [
          Alcotest.test_case "check_esr_vsts gate_states = Some 0 (honest vacuity)"
            `Quick test_esr_vsts_honestly_vacuous;
        ] );
    ]

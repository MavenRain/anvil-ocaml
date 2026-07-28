(* BUILD-SPEC P5 §4 "t_p5_cluster_check" — the two assurance legs on the
   vreplicaset {!Scenario}, with the finding-14 achieved-vs-ceiling reporting and
   the {!Cluster_check.check_esr} / {!Cluster_check.check_esr_temporal} cross-check.

   HONEST OUTCOMES (spec §4: "assert No_counterexample and DOCUMENT decisive as
   achieved-or-not, do not fake it"; §6.1 anti-over-claim). Empirically established
   for this port (see the in-repo probe transcript that calibrated these):

   1. Under {!Bound.default} the reachable set NEVER fixpoints: the monotone
      [rpc_id_allocator] and per-controller [reconcile_id_allocator] counters are
      part of the sound {!Cluster_check.state_equal} but are NOT capped by any
      {!Bound.t} field (only [uid_ceiling] / [rv_ceiling] are). The
      schedule -> run_reconcile -> end_reconcile loop allocates a fresh reconcile
      id every round WITHOUT advancing uid/rv, so distinct states are produced
      without bound and the frontier never empties. Hence [check_always] and
      [check_esr] return [No_counterexample {decisive = false}] under the default
      bound — strict falsification-up-to-depth, with [max_uid_seen] / [max_rv_seen]
      strictly BELOW the (never-fired) ceilings and [pruned = false].

   2. Under a TIGHTENED bound (tiny [uid_ceiling] / [rv_ceiling]) the write-driven
      reconcile churn is pruned early, the reachable set is finite (10 states), the
      frontier empties, and [check_esr] achieves [No_counterexample
      {decisive = true}] — with [pruned = true] and [max_uid_seen] / [max_rv_seen]
      AT the ceilings (the honest cost of decisiveness: it is verification only of
      the bounded system UNDER THESE ceilings, arch §6.1). [check_always]
      (full-nondeterminism [~fair:false]) does NOT fixpoint at feasible depth even
      tightened — the crash / req_drop / pod_monkey branching explodes (>3000
      states by depth 10) — so its honest verdict stays [decisive = false].

   3. THE LIVENESS GATE IS STRUCTURALLY UNREACHABLE — AND SO WAS THE BUG-2 FIX
      (empirically established, [t_p5_investigate]). [Scenario.is_quiescent]
      ([productive_successors = []]) is never true on a reachable state
      ([schedule_controller_reconcile] is always enabled while the CR is in etcd).
      {!Cluster_check.check_esr} now gates on {!Cluster_check.effectively_quiescent}
      instead ("no STATE-CHANGING productive successor"), the sound bounded-Done
      notion — but on THIS vreplicaset model effectively_quiescent is ALSO 0 of the
      reachable set at every feasible bound: the reconcile is perpetually
      re-triggered (schedule -> run -> ... -> end churns the monotone rpc/reconcile
      allocators and keeps messages in flight, and after end_reconcile clears the
      scheduled entry the reschedule re-ADDS the CR, so it is not the idempotent
      self-loop). So [check_esr]'s clean verdict is an HONEST VACUOUS universal.
      The non-vacuous, decidable liveness content here is goal-REACHABILITY:
      [current_state_matches] (the ESR target) IS reachable (>= 1 matching state),
      and the confirm-by-mutation DISCRIMINATOR is the bound — a generous bound
      reaches the goal region (the always-false-target oracle REFUTES), a
      rv_ceiling=1 bound cannot complete the reconcile (the same oracle is CLEAN).
      Asserted below so both the gap (0 quiescent / 0 effectively-quiescent) and
      the real non-vacuity (goal reachable, bound-discriminated) are on the record.

   4. {!Cluster_check.check_esr_temporal} now AGREES with {!Cluster_check.check_esr}
      (the §6.4 cross-check, BUG-3 fix): the driver passes the mandated fairness
      filter ({!Cluster_check.fair_lasso} via [effectively_quiescent]) to
      {!Model_check.check_temporal}, which REJECTS the seed's always-enabled unfair
      STUTTER self-loop lasso (a fair run cannot stutter forever while a
      state-changing productive step is enabled, arch §4). Both are CLEAN, and the
      classes are asserted EQUAL. The filter is LOAD-BEARING and the agreement
      non-vacuous: with NO filter, {!Model_check.check_temporal} REFUTES that same
      unfair lasso — so removing the filter is exactly what breaks the agreement.

   Convention firewall: no loop keywords (BFS via recursion + List folds); no
   [_ ->] wildcard (only the exhaustive two-arm {!Model_check.outcome} and list
   [[] | _ :: _]); Option.fold for options; [Int.equal] not [Stdlib.(=)]. *)

module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants

let default_bound : Bound.t = Bound.default

(* A tightened bound whose write ceilings clip the reconcile churn so the fair
   reachable set is finite and the frontier empties (decisive is achievable). Its
   rv_ceiling = 1 is too tight to CREATE a pod and UPDATE the status, so the
   reconcile never reaches [current_state_matches] under it (the discriminator). *)
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

(* A bound generous enough (uid_ceiling 4 / rv_ceiling 6) that the reconcile CAN
   create the pod and update the status, so [current_state_matches] is reachable —
   the non-vacuity witness that the exploration reaches the ESR-goal region. *)
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

(* ---- outcome accessors (two-arm match = exhaustive enumeration of the sum) ---- *)

let is_no_ce (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with Mc.No_counterexample _ -> true | Mc.Refuted _ -> false

let is_refuted (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with Mc.Refuted _ -> true | Mc.No_counterexample _ -> false

let decisive_of (o : Cluster.cluster_state Mc.outcome) : bool =
  match o with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

(* [Some 0]: the honest surfaced ESR vacuity (Fix C) — the gate is reachable at
   0 states, so a clean {!check_esr} verifies nothing about ESR. *)
let gate_is_zero (o : int option) : bool =
  Option.fold ~none:false ~some:(fun n -> Int.equal n 0) o

(* ---- (1) check_always under the default bound: clean, indecisive, ceilings
   never fired, no invariant violated ---- *)

let check_always_default (desired : int) () =
  let r : Cc.report = Cc.check_always ~depth:6 default_bound ~desired in
  let tag = Printf.sprintf "check_always default desired=%d" desired in
  Alcotest.(check bool) (tag ^ ": No_counterexample (no safety violation)") true (is_no_ce r.outcome);
  Alcotest.(check bool) (tag ^ ": decisive=false (default bound never fixpoints)") false (decisive_of r.outcome);
  Alcotest.(check bool) (tag ^ ": max_uid_seen strictly BELOW uid_ceiling") true (r.max_uid_seen < default_bound.uid_ceiling);
  Alcotest.(check bool) (tag ^ ": max_rv_seen strictly BELOW rv_ceiling") true (r.max_rv_seen < default_bound.rv_ceiling);
  Alcotest.(check bool) (tag ^ ": pruned=false (ceilings never fired)") false r.pruned;
  Alcotest.(check bool) (tag ^ ": no invariant violated") true (Option.is_none r.violated);
  Alcotest.(check bool) (tag ^ ": gate_states=None (safety leg has no liveness gate)") true
    (Option.is_none r.gate_states)

(* ---- (2a) check_esr under the default bound: clean, indecisive, ceilings never
   fired, strictly below ---- *)

let check_esr_default (desired : int) () =
  let r : Cc.report = Cc.check_esr ~depth:40 default_bound ~desired in
  let tag = Printf.sprintf "check_esr default desired=%d" desired in
  Alcotest.(check bool) (tag ^ ": No_counterexample (no quiescent off-goal state)") true (is_no_ce r.outcome);
  Alcotest.(check bool) (tag ^ ": decisive=false (default bound never fixpoints)") false (decisive_of r.outcome);
  Alcotest.(check bool) (tag ^ ": max_uid_seen strictly BELOW uid_ceiling") true (r.max_uid_seen < default_bound.uid_ceiling);
  Alcotest.(check bool) (tag ^ ": max_rv_seen strictly BELOW rv_ceiling") true (r.max_rv_seen < default_bound.rv_ceiling);
  Alcotest.(check bool) (tag ^ ": pruned=false") false r.pruned

(* ---- (2b) check_esr under the TIGHT bound: clean AND decisive=true (frontier
   empties), pruned=true, counters AT the ceilings ---- *)

let check_esr_tight_decisive (desired : int) () =
  let r : Cc.report = Cc.check_esr ~depth:20 tight_bound ~desired in
  let tag = Printf.sprintf "check_esr tight desired=%d" desired in
  Alcotest.(check bool) (tag ^ ": No_counterexample") true (is_no_ce r.outcome);
  Alcotest.(check bool) (tag ^ ": decisive=TRUE (tight bound fixpoints)") true (decisive_of r.outcome);
  Alcotest.(check bool) (tag ^ ": pruned=true (ceilings fired — decisive is relative to them)") true r.pruned;
  Alcotest.(check bool) (tag ^ ": max_uid_seen at/under uid_ceiling") true (r.max_uid_seen <= tight_bound.uid_ceiling);
  Alcotest.(check bool) (tag ^ ": max_rv_seen at/under rv_ceiling") true (r.max_rv_seen <= tight_bound.rv_ceiling);
  Alcotest.(check bool) (tag ^ ": gate_states=Some 0 (honest ESR vacuity surfaced — Fix C)") true
    (gate_is_zero r.gate_states)

(* ---- reachable-state collector (BFS via recursion + folds; no loop keywords),
   shared by the liveness-gap and non-vacuity assertions ---- *)

let reachable_states ~(bound : Bound.t) ~(desired : int) ~(depth : int) :
    Cluster.cluster_state list =
  let seed = Scenario.seed ~desired ~fair:true in
  let succ = Cc.bounded_successors bound Scenario.cluster in
  let visited : (int, Cluster.cluster_state list) Hashtbl.t =
    Hashtbl.create 4096
  in
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
                (fun fr s' ->
                  if Cc.state_equal s s' then fr
                  else if seen s' then fr
                  else (mark s'; s' :: fr))
                fr (succ s))
            [] frontier
        in
        bfs (List.rev next) (level + 1) (List.rev_append next acc)
  in
  let () = if not (seen seed) then mark seed in
  bfs [ seed ] 0 [ seed ]

let matches_of desired = (Invariants.liveness_goal ~cr:(Scenario.vrs ~desired)).holds

let count_where p ~bound ~desired ~depth =
  List.length (List.filter p (reachable_states ~bound ~desired ~depth))

(* The non-vacuity ORACLE: is [current_state_matches] reachable? An always-false
   target with [quiescent = current_state_matches] as the gate makes
   {!Model_check.check_reaches} REFUTE at the first reachable matching state, so
   [Refuted] iff the goal region is reached. The gate is the REAL ESR predicate
   (not a p&&!p surrogate); [effectively_quiescent] can't be the gate here because
   it is unreachable (the finding). *)
let reaches_goal ~(bound : Bound.t) ~(desired : int) ~(depth : int) : bool =
  let seed = Scenario.seed ~desired ~fair:true in
  let reach =
    Mc.explore ~depth
      ~successors:(Cc.bounded_successors bound Scenario.cluster)
      ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ seed ]
  in
  is_refuted
    (Mc.check_reaches reach ~target:(fun _ -> false) ~quiescent:(matches_of desired)
       ~equal:Cc.state_equal)

(* ---- (3) the honest ESR gap: neither is_quiescent NOR the BUG-2 fix
   effectively_quiescent is reachable (0 states), so check_esr's clean verdict is a
   VACUOUS universal — BUT the real target current_state_matches IS reachable, the
   non-vacuity the checker actually rests on. ---- *)

let test_liveness_gap () =
  Alcotest.(check int) "0 reachable is_quiescent states (tight)" 0
    (count_where (Scenario.is_quiescent tight_bound) ~bound:tight_bound ~desired:1 ~depth:30);
  Alcotest.(check int)
    "0 reachable effectively_quiescent states (tight) — the BUG-2 fix is ALSO unreachable here"
    0 (count_where (Cc.effectively_quiescent tight_bound) ~bound:tight_bound ~desired:1 ~depth:30);
  Alcotest.(check int) "0 reachable is_quiescent states (generous)" 0
    (count_where (Scenario.is_quiescent generous_bound) ~bound:generous_bound ~desired:1 ~depth:14);
  Alcotest.(check int) "0 reachable effectively_quiescent states (generous)" 0
    (count_where (Cc.effectively_quiescent generous_bound) ~bound:generous_bound ~desired:1 ~depth:14);
  Alcotest.(check bool)
    ">= 1 reachable current_state_matches state (generous) — goal region IS reached (real non-vacuity)"
    true (count_where (matches_of 1) ~bound:generous_bound ~desired:1 ~depth:14 >= 1)

(* ---- check_esr non-vacuity, confirm-by-mutation DISCRIMINATED by the bound ---- *)

let check_esr_nonvacuous (desired : int) () =
  let tag = Printf.sprintf "check_esr non-vacuity desired=%d" desired in
  let r : Cc.report = Cc.check_esr ~depth:14 generous_bound ~desired in
  Alcotest.(check bool) (tag ^ ": check_esr is clean") true (is_no_ce r.outcome);
  Alcotest.(check bool) (tag ^ ": check_esr surfaces gate_states=Some 0 even at the generous bound (Fix C)")
    true (gate_is_zero r.gate_states);
  Alcotest.(check int) (tag ^ ": 0 reachable effectively_quiescent gate states (honest vacuity)")
    0 (count_where (Cc.effectively_quiescent generous_bound) ~bound:generous_bound ~desired ~depth:14);
  Alcotest.(check bool) (tag ^ ": >= 1 reachable current_state_matches state (goal region reached)")
    true (count_where (matches_of desired) ~bound:generous_bound ~desired ~depth:14 >= 1);
  (* always-false target REFUTES under the generous bound (goal reached — the real
     predicate IS exercised) and is CLEAN under the rv-starved tight bound (goal
     unreachable) — the refutation tracks reaching the goal, not a tautology. *)
  Alcotest.(check bool) (tag ^ ": always-false-target oracle REFUTED under generous bound (goal reachable)")
    true (reaches_goal ~bound:generous_bound ~desired ~depth:14);
  Alcotest.(check bool) (tag ^ ": always-false-target oracle CLEAN under rv-starved tight bound (goal unreachable)")
    false (reaches_goal ~bound:tight_bound ~desired ~depth:20)

(* ---- (4) check_esr / check_esr_temporal cross-check (BUG-3 fix) ---- *)

let esr_goal ~(desired : int) : Cluster.cluster_state Comp_cat.Temporal.t =
  let cr = Scenario.vrs ~desired in
  let module E = Esr.Make (Vreplica_set) in
  E.eventually_stable_reconciliation_per_cr ~cr
    ~current_state_matches:(fun cr' -> (Invariants.liveness_goal ~cr:cr').holds)

let test_esr_temporal_crosscheck () =
  let desired = 1 in
  let bound = tight_bound in
  (* cheap: fixpoints at ~10 states *)
  let depth = 12 in
  let esr : Cc.report = Cc.check_esr ~depth bound ~desired in
  let esrt : Cc.report = Cc.check_esr_temporal ~depth bound ~desired in
  Alcotest.(check bool) "check_esr is clean (No_counterexample)" true (is_no_ce esr.outcome);
  (* BUG-3 fix: check_esr_temporal passes the fairness filter, so its clean/refuted
     CLASS EQUALS check_esr's (both clean at this good bound). *)
  Alcotest.(check bool) "check_esr_temporal CLASS EQUALS check_esr's"
    (is_no_ce esr.outcome) (is_no_ce esrt.outcome);
  Alcotest.(check bool) "both clean at the good bound (post-fair-filter)" true
    (is_no_ce esr.outcome && is_no_ce esrt.outcome);
  (* Fix D: the fair-IGNORE (an unfair refuter neither refutes nor counts against
     decisiveness) makes the [decisive] flag AGREE too, not just the class. Both
     fixpoint at the tight bound (decisive=true). Before Fix D the always-enabled
     unfair seed-stutter zeroed check_esr_temporal's [all_true], so it reported
     decisive=false while check_esr reported decisive=true — reverting Fix D
     flips the equality assertion below. *)
  Alcotest.(check bool) "check_esr is decisive at the tight bound" true (decisive_of esr.outcome);
  Alcotest.(check bool) "check_esr_temporal DECISIVE flag EQUALS check_esr's (Fix D)"
    (decisive_of esr.outcome) (decisive_of esrt.outcome);
  Alcotest.(check bool) "both decisive at the tight bound (post-fair-ignore)" true
    (decisive_of esr.outcome && decisive_of esrt.outcome);
  (* Fix C: both drivers surface the honest ESR vacuity in the report. *)
  Alcotest.(check bool) "check_esr surfaces gate_states=Some 0 (honest vacuity)" true
    (gate_is_zero esr.gate_states);
  Alcotest.(check bool) "check_esr_temporal surfaces gate_states=Some 0 (honest vacuity)" true
    (gate_is_zero esrt.gate_states);
  (* the agreement is NON-VACUOUS: the filter is LOAD-BEARING. With NO fairness
     filter, check_temporal REFUTES the unfair seed-stutter lasso — so removing the
     filter is exactly what would break the agreement. *)
  let seed = Scenario.seed ~desired ~fair:true in
  let goal = esr_goal ~desired in
  let no_filter =
    Mc.check_temporal ~depth
      ~successors:(Cc.bounded_successors bound Scenario.cluster)
      ~equal:Cc.state_equal ~init:[ seed ] ~goal ()
  in
  Alcotest.(check bool)
    "load-bearing: WITHOUT the fairness filter check_temporal REFUTES the unfair stutter lasso"
    true (is_refuted no_filter)

let () =
  Alcotest.run "p5_cluster_check"
    [
      ( "check_always_default",
        List.map (fun d -> Alcotest.test_case (Printf.sprintf "desired=%d clean/indecisive" d) `Quick (check_always_default d)) [ 0; 1; 2 ] );
      ( "check_esr_default",
        List.map (fun d -> Alcotest.test_case (Printf.sprintf "desired=%d clean/indecisive/below-ceilings" d) `Quick (check_esr_default d)) [ 0; 1; 2 ] );
      ( "check_esr_tight_decisive",
        List.map (fun d -> Alcotest.test_case (Printf.sprintf "desired=%d clean/DECISIVE/pruned" d) `Quick (check_esr_tight_decisive d)) [ 0; 1; 2 ] );
      ( "check_esr_nonvacuous",
        [ Alcotest.test_case "goal reachable (generous) vs not (tight) — confirm-by-mutation on the bound" `Quick (check_esr_nonvacuous 1) ] );
      ( "liveness_gap",
        [ Alcotest.test_case "0 is_quiescent AND 0 effectively_quiescent, but >=1 current_state_matches" `Quick test_liveness_gap ] );
      ( "esr_temporal_crosscheck",
        [ Alcotest.test_case "check_esr_temporal class EQUALS check_esr (both clean); fair filter load-bearing" `Quick test_esr_temporal_crosscheck ] );
    ]

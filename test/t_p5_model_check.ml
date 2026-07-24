(* BUILD-SPEC P5 §4 "t_p5_model_check" — the generic {!Model_check} engine on
   TOY int-graph state machines (no cluster dependency), exercising every public
   entry point and the confirm-by-mutation obligation.

   Coverage (spec §4 bullets a-f + the enumerator mutation):
   (a) a safety violation reachable at a bounded depth -> [check_safety] returns
       [Refuted] with the exact bad state and a stem whose every edge is a real
       successor.
   (b) a graph whose reachable frontier empties within [depth] -> a clean run has
       [decisive = true] (the reachability diameter was reached).
   (c) the SAME graph explored to too small a [depth] -> [decisive = false]
       (strict falsification-only, arch §4).
   (d) a genuine livelock cycle -> [check_temporal] refutes [eventually q] (the
       formula is [Verdict.False] on the never-[q] behaviour) and [satisfied_by]
       agrees on the hand-built cycle lasso.
   (e) the [fair] filter rejects an unfair livelock lasso (a run that stutters
       forever while an enabled productive exit is ignored) so it is NOT reported
       (arch §4: a lasso failing [fair] is not a valid counterexample for a
       fairness-antecedent property).
   (f) [to_behaviour] / [satisfied_by] agree with a hand-built
       {!Comp_cat.Behaviour.Lasso} under {!Comp_cat.Temporal_eval.holds}.
   (mutation) confirm-by-mutation on the enumerator: neutering [equal] to
       always-false makes (b) LOSE [decisive] (a suppressed self-loop is now
       re-enqueued every level, so the frontier never empties within the depth
       fuel guard); the mutation is a local function value, so nothing in the tree
       is mutated and there is nothing to restore ([[feedback-confirm-tests-by-mutation]]).

   Convention firewall honoured: no for/while/return/break/continue (recursion +
   List/Option combinators only); no [_ ->] on a finite sum (the only matches are
   the exhaustive two-arm {!Model_check.outcome} and the exhaustive list
   [[] | _ :: _]); no two-arm match on option/result (Option.fold / Option.value);
   int successor tables are total via [List.assoc_opt] + [Option.value] (no int
   wildcard match, no [Stdlib.(=)] operator). *)

module Mc = Anvil_checker.Model_check

(* A total successor function from an adjacency table; absent keys -> no successors. *)
let succ_of (tbl : (int * int list) list) (s : int) : int list =
  Option.value ~default:[] (List.assoc_opt s tbl)

let ieq = Int.equal
let ihash = Fun.id

(* ---- outcome accessors (the two-arm match IS the exhaustive enumeration of the
   {!Model_check.outcome} sum; not an option/result) ---- *)

let is_refuted (o : int Mc.outcome) : bool =
  match o with Mc.Refuted _ -> true | Mc.No_counterexample _ -> false

let is_no_ce (o : int Mc.outcome) : bool =
  match o with Mc.Refuted _ -> false | Mc.No_counterexample _ -> true

let decisive_of (o : int Mc.outcome) : bool =
  match o with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let lasso_of (o : int Mc.outcome) : int Mc.lasso option =
  match o with Mc.Refuted { lasso; _ } -> Some lasso | Mc.No_counterexample _ -> None

(* ======================================================================== *)
(* The branchy DAG used by (a)/(b)/(c):
     0 -> {1,2}   1 -> {3}   2 -> {3,4}   3,4 self-loop
   reachable {0,1,2,3,4}; state 4 is reached at distance 2 (0 -> 2 -> 4). The
   leaves 3,4 self-loop so the graph is STUTTER-CLOSED (every state has a real
   self-loop) — the toy analogue of the cluster's always-enabled [Stutter_step],
   which makes each Refuted [{ loop = [| s |] }] a REAL run (never fabricated). *)
(* ======================================================================== *)

let dag_tbl = [ (0, [ 1; 2 ]); (1, [ 3 ]); (2, [ 3; 4 ]); (3, [ 3 ]); (4, [ 4 ]) ]
let dag = succ_of dag_tbl

(* Every consecutive stem pair is a REAL edge of [succ]. *)
let stem_edges_real (succ : int -> int list) (stem : int array) : bool =
  let n = Array.length stem in
  let rec go i =
    if i + 1 >= n then true
    else if List.exists (ieq stem.(i + 1)) (succ stem.(i)) then go (i + 1)
    else false
  in
  go 0

(* A lasso is a REAL run: every consecutive pair of [stem ++ loop] is a real edge
   AND the loop closes (its last state steps to its first). This is exactly what
   Fix B guarantees — [check_temporal] never fabricates a stutter self-loop, so a
   Refuted lasso always passes this. *)
let is_real_lasso (succ : int -> int list) (l : int Mc.lasso) : bool =
  let seq = Array.append l.Mc.stem l.Mc.loop in
  let n = Array.length seq in
  let rec chain i =
    if i + 1 >= n then true
    else if List.exists (ieq seq.(i + 1)) (succ seq.(i)) then chain (i + 1)
    else false
  in
  let ln = Array.length l.Mc.loop in
  ln >= 1 && chain 0 && List.exists (ieq l.Mc.loop.(0)) (succ l.Mc.loop.(ln - 1))

(* (a) safety violation reachable at depth 2: state 4 is bad. *)
let test_safety_violation () =
  let reach = Mc.explore ~depth:2 ~successors:dag ~equal:ieq ~hash:ihash ~init:[ 0 ] in
  let o = Mc.check_safety reach ~inv:(fun s -> not (ieq s 4)) ~equal:ieq in
  Alcotest.(check bool) "safety violation is Refuted" true (is_refuted o);
  Alcotest.(check bool) "the Refuted outcome carries a lasso" true (Option.is_some (lasso_of o));
  Option.iter
    (fun (l : int Mc.lasso) ->
      Alcotest.(check int) "loop is the single bad state" 1 (Array.length l.loop);
      Alcotest.(check int) "the bad state is exactly 4" 4 l.loop.(0);
      Alcotest.(check bool) "stem ends at the bad state" true
        (ieq l.stem.(Array.length l.stem - 1) 4);
      Alcotest.(check bool) "every stem edge is a real successor" true
        (stem_edges_real dag l.stem);
      Alcotest.(check int) "stem is the shortest 0->2->4 path (length 3)" 3
        (Array.length l.stem))
    (lasso_of o)

(* (b) frontier empties within depth -> decisive=true; (c) too small -> false. *)
let test_frontier_empties_decisive () =
  let r3 = Mc.explore ~depth:3 ~successors:dag ~equal:ieq ~hash:ihash ~init:[ 0 ] in
  Alcotest.(check bool) "depth 3 empties the frontier" true (Mc.frontier_emptied r3);
  Alcotest.(check int) "5 distinct reachable states" 5 (Mc.states_seen r3);
  let o = Mc.check_safety r3 ~inv:(fun _ -> true) ~equal:ieq in
  Alcotest.(check bool) "clean run with an emptied frontier is No_counterexample" true (is_no_ce o);
  Alcotest.(check bool) "clean + emptied => decisive=true" true (decisive_of o)

let test_depth_too_small_indecisive () =
  let r2 = Mc.explore ~depth:2 ~successors:dag ~equal:ieq ~hash:ihash ~init:[ 0 ] in
  Alcotest.(check bool) "depth 2 does NOT empty the frontier" false (Mc.frontier_emptied r2);
  let o = Mc.check_safety r2 ~inv:(fun _ -> true) ~equal:ieq in
  Alcotest.(check bool) "clean but non-emptied => decisive=false (falsification-only)" false
    (decisive_of o)

(* ======================================================================== *)
(* (d) livelock: pure 2-cycle 0<->1, q never holds. *)
(* ======================================================================== *)

let cyc = succ_of [ (0, [ 1 ]); (1, [ 0 ]) ]
let q_never (s : int) : bool = ieq s 99
let eventually_q_never : int Comp_cat.Temporal.t =
  Comp_cat.Temporal.eventually (Comp_cat.Temporal.lift_state ~name:"q99" q_never)

let test_livelock_refutes_eventually () =
  let o = Mc.check_temporal ~depth:6 ~successors:cyc ~equal:ieq ~init:[ 0 ]
      ~goal:eventually_q_never () in
  Alcotest.(check bool) "check_temporal refutes 'eventually q' on the livelock" true (is_refuted o);
  (* Fix B / confirm-by-mutation: [cyc] is 0<->1 with NO self-loops, so the ONLY
     real refuting lasso is the genuine cycle { loop = [| 0; 1 |] }. The engine
     must return a REAL run — before Fix B it fabricated { loop = [| 0 |] } (0
     does not self-loop), which fails [is_real_lasso]; after Fix B it returns the
     real 2-cycle. Reverting Fix B flips this assertion. *)
  Option.iter
    (fun (l : int Mc.lasso) ->
      Alcotest.(check bool) "the returned Refuted lasso is a REAL run (no fabricated self-loop)" true
        (is_real_lasso cyc l))
    (lasso_of o);
  (* the genuine cycle lasso itself refutes 'eventually q' under the P0 evaluator. *)
  let cycle_lasso : int Mc.lasso = { stem = [||]; loop = [| 0; 1 |] } in
  Alcotest.(check bool) "eventually q is Verdict.False on the genuine 0<->1 cycle" true
    (Comp_cat.Verdict.is_false (Mc.satisfied_by ~goal:eventually_q_never cycle_lasso))

(* ======================================================================== *)
(* (e) fair filter: 0 -> {1,2}, 1 -> {0}, 2 terminal; q = (s = 2).
   A fair run must eventually take the enabled exit to the terminal 2; a run
   whose loop never reaches a terminal state stutters/livelocks unfairly. *)
(* ======================================================================== *)

let exit_tbl = [ (0, [ 1; 2 ]); (1, [ 0 ]) ]
let exit_succ = succ_of exit_tbl
let q_two (s : int) : bool = ieq s 2
let eventually_q_two : int Comp_cat.Temporal.t =
  Comp_cat.Temporal.eventually (Comp_cat.Temporal.lift_state ~name:"q2" q_two)

let terminal (s : int) : bool =
  match exit_succ s with [] -> true | _ :: _ -> false

(* A lasso is fair iff its loop reaches a terminal (quiescent) state — weak
   fairness forces a fair run off any stutter/livelock that ignores an enabled
   productive exit. *)
let fair_reaches_terminal (l : int Mc.lasso) : bool = Array.exists terminal l.Mc.loop

let test_fair_filter_rejects_livelock () =
  let no_fair = Mc.check_temporal ~depth:6 ~successors:exit_succ ~equal:ieq ~init:[ 0 ]
      ~goal:eventually_q_two () in
  Alcotest.(check bool) "without the fair filter the unfair livelock IS reported" true
    (is_refuted no_fair);
  let with_fair = Mc.check_temporal ~depth:6 ~successors:exit_succ ~equal:ieq ~init:[ 0 ]
      ~fair:fair_reaches_terminal ~goal:eventually_q_two () in
  Alcotest.(check bool)
    "the fair filter rejects the unfair livelock lasso, so nothing is reported" true
    (is_no_ce with_fair)

(* ======================================================================== *)
(* (f) satisfied_by / to_behaviour agree with a hand-built Behaviour.Lasso. *)
(* ======================================================================== *)

let vstr (v : Comp_cat.Verdict.t) : string =
  match v with
  | Comp_cat.Verdict.True -> "True"
  | Comp_cat.Verdict.False -> "False"
  | Comp_cat.Verdict.Unknown -> "Unknown"

let test_satisfied_by_matches_behaviour () =
  (* a lasso that reaches q=2 in its loop: eventually q = True. *)
  let reaching : int Mc.lasso = { stem = [| 0 |]; loop = [| 2 |] } in
  let via_sat = Mc.satisfied_by ~goal:eventually_q_two reaching in
  let via_beh =
    Comp_cat.Temporal_eval.holds eventually_q_two
      (Comp_cat.Behaviour.Lasso { stem = [| 0 |]; loop = [| 2 |] })
  in
  Alcotest.(check string) "satisfied_by = holds(to_behaviour) [reaching case]" (vstr via_beh)
    (vstr via_sat);
  Alcotest.(check string) "and both are True (the lasso reaches q)" "True" (vstr via_sat);
  (* a lasso that never reaches q: eventually q = False. *)
  let never : int Mc.lasso = { stem = [||]; loop = [| 0 |] } in
  let via_sat2 = Mc.satisfied_by ~goal:eventually_q_two never in
  Alcotest.(check string) "satisfied_by = holds(to_behaviour) [never case]"
    (vstr (Comp_cat.Temporal_eval.holds eventually_q_two (Mc.to_behaviour never)))
    (vstr via_sat2);
  Alcotest.(check string) "and both are False (q never reached)" "False" (vstr via_sat2)

(* ======================================================================== *)
(* confirm-by-mutation on the enumerator: self-loop graph 0 -> 1 -> 1. *)
(* ======================================================================== *)

let selfloop = succ_of [ (0, [ 1 ]); (1, [ 1 ]) ]

let test_mutation_neuter_equal_loses_decisive () =
  (* Baseline: the sound [equal] suppresses the 1->1 self-loop, the frontier
     empties, decisive is achievable. *)
  let base = Mc.explore ~depth:10 ~successors:selfloop ~equal:ieq ~hash:ihash ~init:[ 0 ] in
  Alcotest.(check bool) "sound equal: frontier empties (self-loop suppressed)" true
    (Mc.frontier_emptied base);
  Alcotest.(check int) "sound equal: exactly 2 distinct states" 2 (Mc.states_seen base);
  (* Mutation: neuter [equal] to always-false. The self-loop is no longer
     recognised, so state 1 is re-enqueued at every level up to the [depth] fuel
     guard: the frontier never empties (decisive is LOST) and the state count
     inflates. The mutation is a local closure — nothing in the tree changes, so
     there is nothing to restore. *)
  let mutd =
    Mc.explore ~depth:10 ~successors:selfloop ~equal:(fun _ _ -> false) ~hash:ihash ~init:[ 0 ]
  in
  Alcotest.(check bool) "neutered equal: frontier NEVER empties (decisive lost)" false
    (Mc.frontier_emptied mutd);
  Alcotest.(check bool) "neutered equal: state count inflates past the sound count" true
    (Mc.states_seen mutd > Mc.states_seen base)

(* ======================================================================== *)
(* (g) UNSOUND-decisive regression (reviewer's diamond DAG).  succ
   0 -> {1,2}, 1 -> {2,3}, 2 -> {3}, 3 self-loops (stutter-closed); init {0}.
   The DFS lasso enumerator is bounded by simple-path STATE-COUNT (extend while
   path len < depth) while [frontier_emptied] is a BFS EDGE-distance closure.
   This DAG's BFS edge-diameter is 3 (frontier empties at depth 3) but its
   longest simple path is 4 states (0->1->2->3), so the real refuting lasso
   { stem=[|0;1;2|]; loop=[|3|] } (4 states, 3 self-loops so the loop is real) is
   NEVER enumerated at depth 3 while the frontier has already emptied.  The OLD
   gate [emptied && all_true] therefore wrongly reports decisive=true; the
   [depth >= states] gate makes depth 3 non-decisive.  Confirm-by-mutation: with
   the old gate the "decisive=false" assertion below would flip to a failure. *)
(* ======================================================================== *)

let diamond = succ_of [ (0, [ 1; 2 ]); (1, [ 2; 3 ]); (2, [ 3 ]); (3, [ 3 ]) ]

(* [eventually (= n)] on a run: True iff the run ever visits [n]. *)
let f_eq (n : int) : int Comp_cat.Temporal.t =
  Comp_cat.Temporal.eventually
    (Comp_cat.Temporal.lift_state ~name:(Printf.sprintf "eq%d" n) (ieq n))

(* neg (F(=1) /\ F(=2) /\ F(=3)) : refuted exactly by a run visiting all of
   1, 2 and 3 — only the full 4-state path 0->1->2->3 does so. *)
let diamond_goal : int Comp_cat.Temporal.t =
  Comp_cat.Temporal.neg
    (Comp_cat.Temporal.conj
       (Comp_cat.Temporal.conj (f_eq 1) (f_eq 2))
       (f_eq 3))

let test_diamond_state_count_gate () =
  let r3 = Mc.explore ~depth:3 ~successors:diamond ~equal:ieq ~hash:ihash ~init:[ 0 ] in
  Alcotest.(check bool) "diamond: frontier empties within edge-depth 3" true
    (Mc.frontier_emptied r3);
  Alcotest.(check int) "diamond: 4 distinct reachable states" 4 (Mc.states_seen r3);
  (* depth 3 < states 4: the 4-state refuting lasso is NOT enumerable, yet the
     frontier emptied.  The OLD gate would return decisive=true here; the
     state-count gate makes it non-decisive (this is the mutation witness). *)
  let o3 =
    Mc.check_temporal ~depth:3 ~successors:diamond ~equal:ieq ~init:[ 0 ] ~goal:diamond_goal ()
  in
  Alcotest.(check bool) "depth 3: no refuter enumerable -> No_counterexample" true (is_no_ce o3);
  Alcotest.(check bool) "depth 3: UNSOUND-decisive avoided (decisive=false)" false
    (decisive_of o3);
  (* depth 4 >= states 4: the refuter { stem=[|0;1;2|]; loop=[|3|] } IS
     enumerated -> Refuted.  So depth 3's clean run was strictly bounded, never
     a real verification. *)
  let o4 =
    Mc.check_temporal ~depth:4 ~successors:diamond ~equal:ieq ~init:[ 0 ] ~goal:diamond_goal ()
  in
  Alcotest.(check bool) "depth 4 (>= states): the refuting lasso IS found -> Refuted" true
    (is_refuted o4);
  Option.iter
    (fun (l : int Mc.lasso) ->
      Alcotest.(check bool) "depth 4 refuter: every stem edge is a real successor" true
        (stem_edges_real diamond l.stem);
      Alcotest.(check bool) "depth 4 refuter is a REAL run (loop closes via 3->3)" true
        (is_real_lasso diamond l);
      Alcotest.(check bool) "depth 4 refuter genuinely falsifies the goal (Verdict.False)" true
        (Comp_cat.Verdict.is_false (Mc.satisfied_by ~goal:diamond_goal l)))
    (lasso_of o4)

(* ======================================================================== *)
(* (h) GENUINE-CYCLE decisiveness (Fix A).  fig = 0 -> {1,2}, 1 -> {0}, 2 -> {0}
   (total, NO self-loops).  It has two genuine 2-cycles (0<->1, 0<->2).  The
   conjunctive-liveness goal neg (GF(=1) /\ GF(=2)) is refuted ONLY by a
   figure-eight run that visits BOTH 1 and 2 infinitely often — e.g. (0 1 0 2)^w
   — which is NON-SIMPLE (revisits 0) and so is NEVER enumerated by the
   simple-lasso DFS.  Every SIMPLE lasso (0 1)^w / (0 2)^w satisfies the goal, so
   [all_true] stays true.  The [depth >= states] gate alone would then wrongly
   report decisive=true (a false verification); the [not cyclic] gate catches the
   genuine cycle and drops decisive to false.  Confirm-by-mutation: dropping [not
   cyclic] flips the "decisive=false" assertion.  A hand-built figure-eight lasso
   is exhibited as Verdict.False to prove the real refuter exists. *)
(* ======================================================================== *)

let fig = succ_of [ (0, [ 1; 2 ]); (1, [ 0 ]); (2, [ 0 ]) ]

let gf (n : int) : int Comp_cat.Temporal.t =
  Comp_cat.Temporal.always
    (Comp_cat.Temporal.eventually
       (Comp_cat.Temporal.lift_state ~name:(Printf.sprintf "eq%d" n) (ieq n)))

(* neg (GF(=1) /\ GF(=2)) : refuted by a run visiting 1 AND 2 infinitely often. *)
let fig_goal : int Comp_cat.Temporal.t =
  Comp_cat.Temporal.neg (Comp_cat.Temporal.conj (gf 1) (gf 2))

let test_genuine_cycle_not_decisive () =
  let r3 = Mc.explore ~depth:3 ~successors:fig ~equal:ieq ~hash:ihash ~init:[ 0 ] in
  Alcotest.(check bool) "fig: frontier empties within edge-depth 3" true (Mc.frontier_emptied r3);
  Alcotest.(check int) "fig: 3 distinct reachable states" 3 (Mc.states_seen r3);
  let o =
    Mc.check_temporal ~depth:3 ~successors:fig ~equal:ieq ~init:[ 0 ] ~goal:fig_goal ()
  in
  (* the DFS enumerates only the simple cycles (0 1)^w / (0 2)^w, each of which
     SATISFIES the goal, so no refuter is emitted. *)
  Alcotest.(check bool) "fig: no SIMPLE refuter enumerable -> No_counterexample" true (is_no_ce o);
  (* but a genuine cycle exists, so decisive MUST be false — the simple-lasso
     enumeration is incomplete (Fix A).  Reverting [not cyclic] flips this. *)
  Alcotest.(check bool) "fig: genuine cycle -> decisive=false (Fix A)" false (decisive_of o);
  (* the real refuter is a figure-eight visiting both 1 and 2 forever. *)
  let fig8 : int Mc.lasso = { stem = [||]; loop = [| 0; 1; 0; 2 |] } in
  Alcotest.(check bool) "the figure-eight lasso is a REAL run of fig" true (is_real_lasso fig fig8);
  Alcotest.(check bool) "neg (GF1 /\\ GF2) is Verdict.False on the figure-eight (real refuter exists)" true
    (Comp_cat.Verdict.is_false (Mc.satisfied_by ~goal:fig_goal fig8))

let () =
  Alcotest.run "p5_model_check"
    [
      ("safety_reachability", [ Alcotest.test_case "(a) violation -> Refuted with valid stem" `Quick test_safety_violation ]);
      ("decisiveness",
       [
         Alcotest.test_case "(b) frontier empties -> decisive=true" `Quick test_frontier_empties_decisive;
         Alcotest.test_case "(c) depth too small -> decisive=false" `Quick test_depth_too_small_indecisive;
       ]);
      ("temporal_livelock", [ Alcotest.test_case "(d) livelock refutes eventually q" `Quick test_livelock_refutes_eventually ]);
      ("fair_filter", [ Alcotest.test_case "(e) fair filter rejects the unfair livelock" `Quick test_fair_filter_rejects_livelock ]);
      ("behaviour_crosscheck", [ Alcotest.test_case "(f) satisfied_by agrees with Behaviour.Lasso" `Quick test_satisfied_by_matches_behaviour ]);
      ("enumerator_mutation", [ Alcotest.test_case "neuter equal -> loses decisive (non-vacuity)" `Quick test_mutation_neuter_equal_loses_decisive ]);
      ("diamond_state_count_gate", [ Alcotest.test_case "(g) DAG whose simple path exceeds edge-diameter -> not decisive" `Quick test_diamond_state_count_gate ]);
      ("genuine_cycle_gate", [ Alcotest.test_case "(h) genuine cycle -> not decisive (figure-eight refuter unenumerated)" `Quick test_genuine_cycle_not_decisive ]);
    ]

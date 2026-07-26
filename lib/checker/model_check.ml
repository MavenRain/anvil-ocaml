(* The generic bounded lasso model checker (arch
   [comp-cat-ocaml/lib/temporal/ARCHITECTURE-anvil-ocaml.md] §2.7 / §4 Leg 2;
   normative contract [lib/checker/BUILD-SPEC-P5.md]).  Generic over the state
   type ['a]; the only [Comp_cat] surface it touches is the P0 temporal core
   ([Behaviour] / [Temporal] / [Verdict] / [Temporal_eval]), so it is
   upstreamable to [comp_cat/lib/temporal/model_check] later.

   Honest-limit notes (BUILD-SPEC §6, must appear in-code):
   1. [decisive = true] is verification ONLY of the bounded system under the
      caller's [successors] — never Anvil's Verus theorem, never arbitrary
      cluster size (arch §4 anti-over-claim).  For the reachability legs
      ([check_safety] / [check_reaches]) it needs only that the frontier emptied
      within [depth].  The formula leg ([check_temporal]) needs MORE: the DFS
      enumerates SIMPLE lassos only (a simple stem closed by a stutter
      self-loop, or a simple stem + a SIMPLE re-entry cycle), so it is complete
      — and [decisive] sound — exactly when the reachable graph is acyclic
      modulo self-loops (no GENUINE, >= 2-state cycle) AND [depth >= states]
      (every simple path fits).  A genuine cycle admits non-simple
      (figure-eight) runs the DFS never emits, so [check_temporal] then reports
      [decisive = false] (strict falsification).  The cluster driver's graph is
      a stutter-only DAG (monotone counters, §0.1), so it is acyclic modulo the
      stutter self-loop and the condition holds; the DAG argument is stated, not
      proved, in OCaml, and is guarded by the confirm-by-mutation tests.
   2. Every [Refuted] carries a REAL run: consecutive [stem] states are related
      by [successors], and the [loop] closes under a genuine edge.
      [check_temporal] emits the stutter self-loop candidate ONLY when the state
      genuinely self-loops ([s] in [successors s]) — it NEVER fabricates a
      self-loop the system lacks.  The reachability legs present the bad state as
      [{ loop = [| s |] }]; that is a real run under the STUTTER-CLOSED
      precondition (every reachable state self-loops), which the cluster
      satisfies via the always-enabled [Stutter_step].  A lasso is NEVER
      fabricated. *)

type 'a lasso = { stem : 'a array; loop : 'a array }

let to_behaviour (l : 'a lasso) : 'a Comp_cat.Behaviour.t =
  Comp_cat.Behaviour.Lasso { stem = l.stem; loop = l.loop }

type 'a outcome =
  | Refuted of { lasso : 'a lasso; steps : int }
  | No_counterexample of { decisive : bool; depth : int; states : int }

(* The explored reachable graph.  [pred] maps a discovered state (bucketed by
   [hash], scanned with the caller's [equal]) to the BFS parent it was first
   reached from (init states have no entry); [order] is the BFS discovery order
   (init-first) used to pick the first counterexample deterministically. *)
type 'a reachable = {
  pred : (int, ('a * 'a) list) Hashtbl.t;
  hash : 'a -> int;
  order : 'a list;
  frontier_emptied : bool;
  depth : int;
  states : int;
}

let bucket_mem tbl hash equal s =
  Hashtbl.find_opt tbl (hash s)
  |> Option.map (List.exists (fun x -> equal x s))
  |> Option.value ~default:false

let explore ~depth ~successors ~equal ~hash ~init =
  let visited : (int, 'a list) Hashtbl.t = Hashtbl.create 1024 in
  let pred : (int, ('a * 'a) list) Hashtbl.t = Hashtbl.create 1024 in
  let mark s =
    let h = hash s in
    let bucket = Option.value ~default:[] (Hashtbl.find_opt visited h) in
    Hashtbl.replace visited h (s :: bucket)
  in
  let record_pred child parent =
    let h = hash child in
    let bucket = Option.value ~default:[] (Hashtbl.find_opt pred h) in
    Hashtbl.replace pred h ((child, parent) :: bucket)
  in
  let seen s = bucket_mem visited hash equal s in
  let init_rev =
    List.fold_left
      (fun acc s -> if seen s then acc else (mark s; s :: acc))
      [] init
  in
  let rec bfs frontier level order_rev count =
    match frontier with
    | [] -> (order_rev, count, true)
    | _hd :: _tl ->
        if level >= depth then (order_rev, count, false)
        else
          let next_rev, order_rev', count' =
            List.fold_left
              (fun acc s ->
                List.fold_left
                  (fun (nf, ord, cnt) s' ->
                    if equal s s' then (nf, ord, cnt)
                    else if seen s' then (nf, ord, cnt)
                    else (
                      mark s';
                      record_pred s' s;
                      (s' :: nf, s' :: ord, cnt + 1)))
                  acc (successors s))
              ([], order_rev, count) frontier
          in
          bfs (List.rev next_rev) (level + 1) order_rev' count'
  in
  let order_rev, states, emptied =
    bfs (List.rev init_rev) 0 init_rev (List.length init_rev)
  in
  {
    pred;
    hash;
    order = List.rev order_rev;
    frontier_emptied = emptied;
    depth;
    states;
  }

let frontier_emptied r = r.frontier_emptied
let states_seen r = r.states
let count_states_where r pred = List.length (List.filter pred r.order)

(* One left fold over the deduped visited set ([order] holds each DISTINCT
   reachable state exactly once, in BFS discovery order).  Purely additive over
   [count_states_where], which is the special case [f acc s = acc + (if pred s
   then 1 else 0)]: it lets a caller derive MANY aggregates (maxima, several
   counts, pruning flags) in a SINGLE pass instead of one traversal per
   statistic.  The BFS order is an implementation detail and is NOT part of the
   contract; only "each distinct state once" is. *)
let fold_states r ~init ~f = List.fold_left f init r.order

(* Parent of [s] in the BFS tree (None for an init state / an unknown state). *)
let pred_of r ~equal s =
  Option.map snd
    (Option.bind
       (Hashtbl.find_opt r.pred (r.hash s))
       (List.find_opt (fun (child, _p) -> equal child s)))

(* The BFS path init -> s (inclusive), as an array, via the predecessor map. *)
let path_to r ~equal s =
  let rec walk cur acc =
    Option.fold ~none:(cur :: acc)
      ~some:(fun parent -> walk parent (cur :: acc))
      (pred_of r ~equal cur)
  in
  Array.of_list (walk s [])

let refuted_at r ~equal s =
  let stem = path_to r ~equal s in
  Refuted
    { lasso = { stem; loop = [| s |] }; steps = Array.length stem + 1 }

let clean r =
  No_counterexample
    { decisive = r.frontier_emptied; depth = r.depth; states = r.states }

let check_safety r ~inv ~equal =
  Option.fold ~none:(clean r)
    ~some:(fun s -> refuted_at r ~equal s)
    (List.find_opt (fun s -> not (inv s)) r.order)

let check_reaches r ~target ~quiescent ~equal =
  Option.fold ~none:(clean r)
    ~some:(fun s -> refuted_at r ~equal s)
    (List.find_opt (fun s -> quiescent s && not (target s)) r.order)

let satisfied_by ~goal l =
  Comp_cat.Temporal_eval.holds goal (to_behaviour l)

let check_temporal ~depth ~successors ~equal ~init ?fair ~goal () =
  (* [decisive] needs the reachability diameter; reuse [explore] with a
     constant (trivially sound) hash to obtain frontier-emptied + state count,
     while the DFS below enumerates the actual lasso witnesses. *)
  let reach = explore ~depth ~successors ~equal ~hash:(fun _ -> 0) ~init in
  let emptied = reach.frontier_emptied in
  let n_states = reach.states in
  let fair_ok l = Option.fold ~none:true ~some:(fun f -> f l) fair in
  let has_found (f, _, _) = Option.is_some f in
  (* Fold a candidate lasso into [(first_refuter, all_evaluated_true, cyclic)];
     short-circuits once a refuter is found.  A [Verdict.False] lasso that is
     UNFAIR is a counterexample for neither leg: it is not reported (arch §4),
     and it is NOT evidence against decisiveness either — a fairness-antecedent
     goal is not weakened by unfair behaviours — so it is IGNORED entirely
     rather than zeroing [all_true] (Fix D).  [cyclic] is threaded untouched
     here; it is set in [dfs] when a genuine (>= 2-state) re-entry cycle is
     traversed. *)
  let consider l acc =
    let found, all_true, cyclic = acc in
    if Option.is_some found then acc
    else
      let v = Comp_cat.Temporal_eval.holds goal (to_behaviour l) in
      if Comp_cat.Verdict.is_false v then
        (if fair_ok l then (Some l, all_true, cyclic) else acc)
      else (found, all_true && Comp_cat.Verdict.is_true v, cyclic)
  in
  (* If [s'] re-enters the current [ordered] path (init-first) at index [i],
     the genuine cycle lasso { stem = path[0..i-1]; loop = path[i..] }. *)
  let find_reentry s' ordered =
    let rec scan idx lst =
      match lst with
      | [] -> None
      | x :: xs -> if equal x s' then Some idx else scan (idx + 1) xs
    in
    Option.map
      (fun i ->
        let arr = Array.of_list ordered in
        {
          stem = Array.sub arr 0 i;
          loop = Array.sub arr i (Array.length arr - i);
        })
      (scan 0 ordered)
  in
  let rec dfs path_rev len acc =
    if has_found acc then acc
    else
      match path_rev with
      | [] -> acc
      | current :: rest_rev ->
          let ordered = List.rev path_rev in
          let succs = successors current in
          (* (a) the maximal simple path so far, closed by its stutter self-loop
             — ONLY when [current] genuinely self-loops (Fix B: never fabricate a
             self-loop the transition system does not have). *)
          let acc =
            if List.exists (equal current) succs then
              consider
                { stem = Array.of_list (List.rev rest_rev); loop = [| current |] }
                acc
            else acc
          in
          List.fold_left
            (fun acc s' ->
              if has_found acc then acc
              else
                let reentry = find_reentry s' ordered in
                (* A re-entry whose loop spans >= 2 distinct states is a GENUINE
                   (non-self) cycle; its presence means non-simple runs exist that
                   the simple-lasso DFS never emits, so [decisive] cannot be
                   claimed (Fix A). *)
                let genuine_cycle =
                  Option.fold ~none:false
                    ~some:(fun l -> Array.length l.loop >= 2)
                    reentry
                in
                let acc =
                  Option.fold ~none:acc ~some:(fun l -> consider l acc) reentry
                in
                let acc =
                  if genuine_cycle then
                    let f, at, _ = acc in
                    (f, at, true)
                  else acc
                in
                if Option.is_none reentry && len < depth then
                  dfs (s' :: path_rev) (len + 1) acc
                else acc)
            acc succs
  in
  let found, all_true, cyclic =
    List.fold_left
      (fun acc s0 -> if has_found acc then acc else dfs [ s0 ] 1 acc)
      (None, true, false) init
  in
  (* [decisive] gate.  Three independent conditions, all necessary:
       - [emptied]: the BFS reachability diameter was reached within [depth].
       - [depth >= n_states]: a simple path visits at most [n_states] distinct
         states, so EVERY simple-path lasso is enumerated only when [depth] is at
         least the state count (else a refuter longer than [depth] states is
         missed while the BFS frontier has already emptied — a DAG whose longest
         simple path exceeds its BFS edge-diameter).
       - [not cyclic]: the DFS enumerates SIMPLE lassos only.  On a graph with a
         GENUINE (>= 2-state) cycle, a non-simple (figure-eight) run can refute a
         conjunctive-liveness goal while every simple lasso holds, so [all_true]
         is not sufficient there.  [cyclic] is set iff such a cycle was
         traversed; when set, [decisive] drops to [false] (strict falsification).
     [all_true] already ignores unfair refuters (Fix D).  Together these make
     [decisive=true] sound exactly on graphs acyclic modulo self-loops (the
     cluster's stutter-only DAG).  Refuted is unaffected — it never depends on
     this gate. *)
  Option.fold
    ~none:
      (No_counterexample
         {
           decisive = emptied && all_true && depth >= n_states && not cyclic;
           depth;
           states = n_states;
         })
    ~some:(fun l ->
      Refuted { lasso = l; steps = Array.length l.stem + Array.length l.loop })
    found

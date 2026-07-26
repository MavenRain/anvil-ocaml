(** The generic bounded lasso model checker (architecture
    [comp-cat-ocaml/lib/temporal/ARCHITECTURE-anvil-ocaml.md] §2.7 "the checker"
    and §4 Leg 2). Generic over the state type ['a]; depends only on the P0
    temporal core ([Comp_cat.{Temporal,Behaviour,Verdict,Temporal_eval}]), never
    on the cluster — written generic precisely so it is upstreamable to
    [comp_cat/lib/temporal/model_check] (§2.7's intended home) later, and housed
    here to keep P5 a single-repo deliverable.

    Where the fixpoints actually get computed: [always]/[eventually] are Kleene
    fixed points on the finite reachable-state set, obtained by breadth-bounded
    reachability over [successors] — NOT by [Comp_cat] omega-colimits (arch §2.1,
    finding 4). The reified {!Comp_cat.Temporal.t} AST is walked by the P0
    evaluator on each enumerated lasso.

    {b Soundness contract.} Every [Refuted] carries a lasso that is a REAL run of
    the transition system (consecutive states related by [successors], and the
    loop closes under a genuine edge — the stutter self-loop is used ONLY at
    states that genuinely self-loop, never fabricated). [No_counterexample
    {decisive=true}] is returned only when the bounded system was exhaustively
    explored: for the reachability legs ([check_safety] / [check_reaches]) that
    is exactly "the frontier emptied within [depth]"; for the formula leg
    ([check_temporal]) it ADDITIONALLY requires [depth >= states] and that the
    reachable graph be acyclic modulo self-loops (no genuine >= 2-state cycle),
    since the DFS enumerates SIMPLE lassos only. Otherwise [decisive=false] and
    the result is strict falsification-up-to-[depth], never verification
    (arch §4). *)

type 'a lasso = { stem : 'a array; loop : 'a array }
(** An ultimately-periodic run: [stem] then the infinitely-repeated nonempty
    [loop]. Mirrors {!Comp_cat.Behaviour.Lasso}'s payload so {!to_behaviour} can
    hand it to the P0 evaluator. [loop] is assumed nonempty. *)

val to_behaviour : 'a lasso -> 'a Comp_cat.Behaviour.t
(** Inject a {!lasso} into {!Comp_cat.Behaviour.t} as a [Lasso {stem; loop}], so
    {!Comp_cat.Temporal_eval.holds} evaluates a formula on it exactly (finite
    suffix-classes ⇒ two-valued). *)

type 'a outcome =
  | Refuted of { lasso : 'a lasso; steps : int }
      (** A concrete counterexample behaviour; [lasso] is a real run and [steps]
          is [|stem| + |loop|]. Never returned without exhibiting a real
          refutation. *)
  | No_counterexample of { decisive : bool; depth : int; states : int }
      (** No counterexample up to [depth]. [decisive] iff the reachable frontier
          emptied within [depth] (exhaustive over the bounded system); else
          strict falsification-only. [states] = distinct reachable states seen. *)
(** The result of a check. Verification is bounded: even [decisive=true] is
    verification only of the bounded system under the caller's [successors], and
    transfers no guarantee to arbitrary size nor any part of Anvil's Verus
    theorem (arch §4). *)

type 'a reachable
(** The explored reachable-state graph: the visited set, predecessor edges (for
    path reconstruction), and whether the frontier emptied within [depth].
    Opaque; produced by {!explore}, consumed by the [check_*] procedures. *)

val explore :
  depth:int ->
  successors:('a -> 'a list) ->
  equal:('a -> 'a -> bool) ->
  hash:('a -> int) ->
  init:'a list ->
  'a reachable
(** Breadth-first reachability from [init] over [successors], deduping states with
    [equal] bucketed by [hash] (which MUST satisfy [equal a b ==> hash a = hash b]
    — see the driver's sound hash; an unsound hash breaks termination, arch §3.2).
    Explores at most [depth] levels. A self-loop ([equal s s']) is never
    re-enqueued. [successors] already encodes all bounds (this function prunes
    nothing). Deterministic in [successors] list order. *)

val frontier_emptied : 'a reachable -> bool
(** [true] iff {!explore} closed the reachable set before hitting [depth] (the
    reachability diameter was reached) — the precondition for [decisive=true]. *)

val states_seen : 'a reachable -> int
(** The number of distinct reachable states in the explored graph. *)

val count_states_where : 'a reachable -> ('a -> bool) -> int
(** The number of distinct reachable states satisfying the predicate. The driver
    uses it to surface the ESR gate-state count (the count of reachable
    effectively-quiescent states): a count of [0] means the ESR universal is
    VACUOUS, so a clean verdict there verifies nothing and must be reported as a
    modeling gap rather than as "ESR holds" ([[feedback-workflow-zero-findings-may-be-vacuous]]). *)

val fold_states : 'a reachable -> init:'b -> f:('b -> 'a -> 'b) -> 'b
(** Fold [f] over the explored reachable set: visits each DISTINCT reachable
    state EXACTLY ONCE, in an UNSPECIFIED order (the traversal order is an
    implementation detail and is not part of this contract). {!count_states_where}
    is the special case [fold_states r ~init:0 ~f:(fun n s -> if pred s then n + 1
    else n)]. Provided so a caller needing several aggregates over the same graph
    (maxima, several gate counts, pruning flags) computes them in ONE pass rather
    than one traversal per statistic; the P13 fault report is the intended
    consumer. Purely additive: {!explore} / {!check_safety} / {!check_reaches} /
    {!count_states_where} are unchanged. *)

val check_safety :
  'a reachable -> inv:('a -> bool) -> equal:('a -> 'a -> bool) -> 'a outcome
(** Refute a STATE invariant [inv] by reachability (arch §0.1.1: safety is
    reachability, no genuine cycle needed). The first reachable [s] with
    [not (inv s)] yields [Refuted] with lasso [{ stem = path init→s; loop = [|s|]
    }] — the stutter self-loop, a real fair-modulo-stutter behaviour on which
    [always (lift inv)] is [False] at the head. If none and {!frontier_emptied}
    then [No_counterexample {decisive=true}]; else [decisive=false]. *)

val check_reaches :
  'a reachable ->
  target:('a -> bool) ->
  quiescent:('a -> bool) ->
  equal:('a -> 'a -> bool) ->
  'a outcome
(** The DAG liveness specialization (arch §0.1.3): refute "every reachable
    quiescent state satisfies [target]". The first reachable [s] with
    [quiescent s && not (target s)] yields [Refuted] (a fair run that settles
    off-goal), lasso [{ stem = path; loop = [|s|] }]. Clean iff no such state;
    [decisive] as in {!check_safety}. Sound for ESR because the caller runs it
    from the fair seed where weak fairness forces every run to a quiescent
    state. *)

val check_temporal :
  depth:int ->
  successors:('a -> 'a list) ->
  equal:('a -> 'a -> bool) ->
  init:'a list ->
  ?fair:('a lasso -> bool) ->
  goal:'a Comp_cat.Temporal.t ->
  unit ->
  'a outcome
(** The formula-faithful path (arch §2.7): enumerate lasso runs up to [depth]
    (simple-path stems by the on-path visited set; close a loop when a successor
    re-enters the current path; also emit each maximal simple path terminated by
    its stutter self-loop) and evaluate {!Comp_cat.Temporal_eval.holds}[ goal
    (to_behaviour l)] on each. The first lasso whose verdict is
    {!Comp_cat.Verdict.False} AND (when [fair] is given) satisfying [fair] yields
    [Refuted] — a lasso failing [fair] is NOT a valid counterexample for a
    fairness-antecedent property (arch §4), and is IGNORED (it neither refutes
    nor counts against [decisive]). [No_counterexample {decisive}] where
    [decisive] requires the frontier emptied, [depth >= states], every FAIR
    enumerated lasso evaluated to [True], AND that no genuine (>= 2-state) cycle
    was traversed — the DFS enumerates simple lassos only, so a genuine cycle
    (whose non-simple runs it cannot emit) forces [decisive = false]. The
    stutter self-loop candidate is emitted ONLY at states that genuinely
    self-loop, so a [Refuted] lasso is always a real run. This is the
    demonstration that ESR/safety {!Comp_cat.Temporal.t} formulas evaluate on
    real lassos via the P0 topos-of-trees semantics; the
    [check_safety]/[check_reaches] procedures are cross-checked against it. *)

val satisfied_by :
  goal:'a Comp_cat.Temporal.t -> 'a lasso -> Comp_cat.Verdict.t
(** [Comp_cat.Temporal_eval.holds goal (to_behaviour l)] — the exact two-valued
    verdict of [goal] on the lasso [l]. Thin; for tests and the cross-check. *)

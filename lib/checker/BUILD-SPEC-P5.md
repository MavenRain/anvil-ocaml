# BUILD-SPEC P5 — Bounded lasso model checker (BMC)

Normative contract for Phase 5 of the anvil-ocaml port. Hand-authored (the
design crux); builders implement `.ml` bodies + tests against it; the adversarial
review audits against it. Architecture: `comp-cat-ocaml/lib/temporal/
ARCHITECTURE-anvil-ocaml.md` §2.7 (the checker) + §4 Leg 2 (what BMC means) + §5
(P5 row). P5 = the **assurance spine's second leg**, consuming P0 (comp_cat
temporal core), P2 (`Cluster.enabled_successors` / `Bound.t` / `Esr`), and P4's
qcheck-free `anvil_assurance` (`Scenario` / `Invariants`) — the reason P4 was
built qcheck-free was precisely so P5 reuses it without a test-only dep.

## 0. What P5 is, and the honesty contract

P5 turns a bounded cluster into a **finite reachable-state graph** and answers two
questions by exhaustive exploration up to a depth `D` and an explicit `Bound.t`:

- **Safety** (`Invariants.always`): does any reachable state violate a load-bearing
  safety invariant? A violation is reported as a concrete counterexample **lasso**.
- **ESR / bounded liveness** (`Invariants.liveness_goal` = #11
  `current_state_matches`, the ESR `leads_to` target): from the fair seed, does
  every reachable **quiescent** state satisfy `current_state_matches`? A
  non-matching quiescent state is a genuine ESR counterexample.

**The single anti-over-claim (arch §4).** P5 reports *falsification up to `D` and
the bounds*, never universal verification. A clean run is
`No_counterexample { decisive }` where `decisive = true` **only** when the
bounded system was fully explored: for the reachability legs
(`check_safety`/`check_reaches`) that is exactly "the reachable frontier emptied
within `D`"; for the formula leg (`check_temporal`) it **additionally** requires
`D >= states` and that the reachable graph be **acyclic modulo self-loops** (no
genuine `>= 2`-state cycle), because the DFS enumerates SIMPLE lassos only — a
genuine cycle admits non-simple (figure-eight) runs it never emits (fix-pass A;
see §6). Even then it is verification only *of the bounded system under this
`Bound.t`*, transferring **no** guarantee to arbitrary cluster size and **no**
part of Anvil's Verus theorem. When `D` is hit with a non-empty frontier (or a
genuine cycle is traversed), `decisive = false` (strict falsification-only).

### 0.1 The load-bearing soundness insight (why this is decidable at all)

The api-server `uid_counter` / `resource_version_counter`, the `rpc_id_allocator`,
and the `reconcile_id_allocator` are **monotone**: every object write and every
message emission strictly advances a counter. Therefore **no productive step ever
returns to an earlier state** — the bounded productive reachable graph is a **DAG**
whose only cycles are the always-enabled `Stutter_step` self-loop (`s' = s`) and
any genuinely counter-free step. Consequences P5 is built on:

1. **Safety is reachability.** A safety counterexample is a finite prefix ending in
   a bad state; no genuine cycle is needed. The counterexample lasso is
   `{ stem = path_to_bad ; loop = [| bad |] }` (the stutter self-loop), which is a
   *real fair-modulo-stutter behaviour* on which `always inv` is already `False` at
   the head of the loop, so `Temporal_eval.holds (always inv)` on it is exactly
   `False`. Fairness is irrelevant to safety.
2. **Finiteness needs the counter ceilings.** `Cluster.enabled_successors` (P2)
   bounds only the *single-step* domains (`max_in_flight` / `max_objects_per_kind`
   / `max_controllers`); it does **not** cap counter growth (`bound.mli` says so:
   `uid_ceiling` / `rv_ceiling` / `max_reconcile_depth` are "reserved for the
   Phase-5 depth-bounded model-checking driver and are NOT yet consumed in P2").
   So **P5's explorer must prune** any successor whose `api_server.uid_counter >
   uid_ceiling` or `resource_version_counter > rv_ceiling` (and cap exploration by
   `D`, which subsumes `max_reconcile_depth`). With the ceilings, every counter
   domain is finite, every single-step domain is `Bound.t`-finite, so the reachable
   set is finite and BFS terminates at a fixpoint (the reachability diameter).
3. **ESR reduces to quiescence reachability.** Under `Scenario.seed ~fair:true`
   the three disruptors (crash / req_drop / pod_monkey) are disabled, so the fair
   suffix is the productive DAG driving monotonically toward `Done`. A fair run
   cannot stutter forever while a productive step is enabled (weak fairness), so
   every fair run reaches a **quiescent** state (`Scenario.is_quiescent b s`,
   i.e. `productive_successors = []`). Hence ESR holds up to the bounds **iff every
   reachable quiescent state satisfies `current_state_matches`** — a decidable
   check on the finite DAG. A reachable quiescent non-matching state is a real
   counterexample (a fair run that settles off-goal).

**Pruning is soundness-critical (arch finding 14).** A ceiling too tight silently
excludes the very interleaving an invariant targets, so a pass can be *vacuous*.
P5 therefore (a) reports the achieved bound (max counters seen, frontier state,
whether pruning fired) against the `Bound.t` caps, and (b) ships
**confirm-by-mutation on the enumerator**: for each checked invariant, a
deliberately-broken model must make the checker *refute* under the same bounds —
proving the exploration actually reaches violating states, not passing vacuously
(`[[feedback-confirm-tests-by-mutation]]`).

## 1. Module layout (new library `anvil_checker`, `lib/checker/`)

Flat library `anvil_checker`; `dune` mirrors `lib/assurance/dune`
(`-open Anvil_support … -open Anvil_cluster -open Anvil_controllers`, libraries
include `comp_cat`). Two modules; strict `.mli` on both.

- `model_check.ml/.mli` — the **generic engine**, generic over the state type `'a`
  (no cluster dependency; depends only on `Comp_cat.{Temporal,Behaviour,Verdict,
  Temporal_eval}`). Written generic precisely so it is upstreamable to
  `comp_cat/lib/temporal/model_check` (arch §2.7's intended home) later; housed
  here to keep P5 a single-repo deliverable.
- `cluster_check.ml/.mli` — the **cluster driver**: the sound `cluster_state`
  equality + hash, the counter-ceiling pruned successor function, and the two
  assurance entry points (`check_always`, `check_esr`) wired to `Scenario` /
  `Invariants` / `Esr`, with `Bound.t` reporting.

Plus two **additive P2 edits** (needed for the sound state equality; the allocators
are abstract monotone counters with no comparison surface):
- `lib/cluster/message.ml/.mli` `Rpc_id_allocator`: add `val equal : t -> t -> bool`.
- `lib/cluster/controller.ml/.mli` `Reconcile_id_allocator`: add `val equal : t -> t -> bool`.
Both = counter equality; faithful (the allocator IS its counter), purely additive,
no behaviour change. Doc-comment each with the Anvil field.

## 2. `model_check.mli` (generic engine — the crux, authored below)

See `model_check.mli` in this directory (hand-authored). The contract in prose:

```
type 'a lasso = { stem : 'a array; loop : 'a array }
```
Mirror of `Comp_cat.Behaviour.Lasso`'s payload (`loop` nonempty). `to_behaviour`
injects it into `Comp_cat.Behaviour.t` so the P0 evaluator can run on it.

```
type 'a outcome =
  | Refuted of { lasso : 'a lasso ; steps : int }
  | No_counterexample of { decisive : bool ; depth : int ; states : int }
```
- `Refuted` — a concrete counterexample behaviour was found; `lasso` is a **real**
  run of the system (every consecutive pair satisfies `successors`, and
  `loop`'s last element steps to `loop`'s first). SOUND: never returned unless a
  real refutation is exhibited.
- `No_counterexample { decisive }` — none found up to `depth`; `decisive = true`
  iff the reachable frontier emptied within `depth` (fixpoint reached ⇒ exhaustive
  over the bounded system). `states` = distinct reachable states seen.

**`explore`** — BFS from the `init` states over `successors`, deduping with
`equal` via a **sound hash** (see §3.2), pruning nothing (the caller's
`successors` already encodes bounds). Returns the visited set, a predecessor edge
map (for path reconstruction), and `frontier_emptied : bool` (true ⇒ reachability
diameter reached within `depth`). Caps at `depth` levels; a self-loop
(`equal s s'`) never re-enqueues.

**`check_safety`** — refute a *state* invariant `inv : 'a -> bool` by reachability:
first reachable `s` with `not (inv s)` ⇒ `Refuted { lasso = { stem = path init→s ;
loop = [| s |] } }` (the stutter loop; `always (lift inv)` is `False` at `s`). If
none and `frontier_emptied` ⇒ `No_counterexample { decisive = true }`; else
`decisive = false`. The path is reconstructed from the predecessor map.

**`check_reaches`** — the liveness specialization for the DAG (§0.1.3): given a
`target : 'a -> bool` and a `quiescent : 'a -> bool`, refute "every reachable
quiescent state satisfies target" — first reachable `s` with `quiescent s && not
(target s)` ⇒ `Refuted { lasso = { stem = path ; loop = [| s |] } }`. Clean iff no
such state; `decisive` as in `explore`.

**`check_temporal`** — the **formula-faithful** path that genuinely exercises the
P0 temporal core: enumerate lasso runs up to `depth` (simple-path stems by the
DFS visited-on-path set; close a loop when a successor re-enters the current path;
also emit each maximal simple path terminated by its stutter self-loop), and for
each candidate lasso evaluate `Comp_cat.Temporal_eval.holds goal (to_behaviour l)`.
The first lasso whose verdict is `Verdict.False` **and** (when given) passing the
caller `fair : 'a lasso -> bool` filter ⇒ `Refuted` — a lasso failing `fair` is
NOT a valid counterexample for a fairness-antecedent property (arch §4) and is
IGNORED (it neither refutes nor counts against `decisive`, fix-pass D). The
stutter self-loop candidate is emitted ONLY at states that genuinely self-loop
(`s` in `successors s`), so a `Refuted` lasso is always a real run (fix-pass B).
`No_counterexample { decisive }` where `decisive` requires frontier-emptied AND
`depth >= states` AND every FAIR enumerated lasso evaluated to `True` AND no
genuine (`>= 2`-state) cycle was traversed (fix-pass A). This path is the demonstration
that ESR/safety `Comp_cat.Temporal.t` formulas evaluate on **real cluster lassos**
via the topos-of-trees lasso semantics; `check_safety`/`check_reaches` are the
efficient decision procedures it is cross-checked against.

`satisfied_by : goal -> 'a lasso -> Verdict.t` = `Temporal_eval.holds goal
(to_behaviour l)` (thin, for tests + cross-check).

Determinism: BFS/DFS visit order is the `successors` list order; no `Random`, no
`Hashtbl.hash`-order dependence in *results* (the sound hash is a bucket key only,
never affects which counterexample is chosen — the chosen one is the
first-in-BFS/DFS-order).

## 3. `cluster_check.mli` (cluster driver — the crux, authored below)

### 3.1 Sound `cluster_state` equality (`state_equal`)

Compose the leaf equalities; **every field participates** (omitting any — especially
a counter — could merge distinct states and hide a counterexample, an unsound
`decisive`):

```
state_equal a b =
     Api_server:    Object_ref_map.equal Dynamic_object.equal a.resources b.resources
                 && Int.equal uid_counter && Int.equal resource_version_counter
  && controllers:   Imap.equal cae_equal a.c_and_e b.c_and_e
  && Network:       Multiset.equal (Pool) a.in_flight b.in_flight        (order-insensitive bag)
  && rpc allocator: Rpc_id_allocator.equal
  && Bool.equal req_drop_enabled && Bool.equal pod_monkey_enabled
where cae_equal = Controller.state eq && Option.equal External.state eq && Bool.equal crash_enabled
      Controller.state eq = Object_ref_map.equal ongoing_eq
                         && Object_ref_map.equal Dynamic_object.equal scheduled
                         && Reconcile_id_allocator.equal
      ongoing_eq = Dynamic_object.equal triggering_cr && Option.equal Message.equal pending_req_msg
                && Value.equal local_state && Int.equal reconcile_id
      External.state eq = Value.equal .state
```
`Object_ref_map` / `Imap` are `Map.Make(_)` ⇒ expose `equal : (v->v->bool)->t->t->
bool` (equal keys by the map's `compare`, equal values). `Message.Pool` is
`Multiset.Make(Message)` ⇒ `equal` is order-insensitive (correct: the in-flight
bag has no order). No `Stdlib.(=)`/polymorphic compare anywhere (would diverge on
closures inside `installed_types`, and is order-sensitive on maps).

### 3.2 Sound hash (`state_hash`) — bucket key only, MUST satisfy `equal ⇒ hash-equal`

Fold **order-insensitive** structural summaries (so equal maps/bags with different
internal tree shape still hash equal):
```
state_hash s =
  mix [ uid_counter ; resource_version_counter ;
        Object_ref_map.cardinal resources ;
        Pool.cardinal in_flight ;
        bool→int req_drop_enabled ; bool→int pod_monkey_enabled ;
        Imap.cardinal c_and_e ;
        Σ over ongoing/scheduled maps of cardinals ]   (* sums are commutative *)
```
Explicitly **do NOT** use `Hashtbl.hash` on the raw record (map tree shape /
physical Value identity would give equal states different hashes ⇒ the visited set
misses them ⇒ non-termination). The visited set is `Hashtbl.Make` over
`(state_hash, state_equal)`. A too-coarse hash only costs collisions (resolved by
`state_equal`), never correctness; an unsound hash breaks termination — so this
recipe is conservative by construction (only counts + counters + bools).

### 3.3 Ceiling-pruned successors (`bounded_successors`)

```
bounded_successors bound cluster s =
  Cluster.enabled_successors bound cluster s              (* P2: single-step bounds *)
  |> List.filter_map (fun (step, s') ->
       if s'.api_server.uid_counter > bound.uid_ceiling then None
       else if s'.api_server.resource_version_counter > bound.rv_ceiling then None
       else Some s')                                      (* multi-step ceilings: P5 *)
```
Drop the `Step.t` label for exploration (the engine works on states), BUT keep a
parallel labelled variant `bounded_labelled_successors` returning `(Step.t * s')`
for **counterexample traces** (report the step sequence that reaches the bad
state — far more useful than bare states). `max_reconcile_depth` is subsumed by the
global depth `D` (documented mapping; a reconcile round is bounded by `D` steps).
The engine `successors` closes over `bound` + `Scenario.cluster`.

### 3.4 Entry points

```
type report = {
  outcome : Cluster.cluster_state Model_check.outcome ;
  bound : Bound.t ;
  max_uid_seen : int ; max_rv_seen : int ;   (* achieved vs ceiling, finding 14 *)
  pruned : bool ;                              (* did a ceiling fire? *)
  violated : Invariants.invariant option ;     (* which invariant broke (safety) *)
}

check_always : ?depth:int -> Bound.t -> desired:int -> report
  (* seed = Scenario.seed ~desired ~fair:false (full nondeterminism);
     inv  = Invariants.conjunction (Invariants.always ~cr ~controller_id);
     Model_check.check_safety over bounded_successors; on Refuted, set `violated`
     = Invariants.first_violated (always …) (the bad state).  The `always` bucket
     ONLY — never eventually_always (those hold only on the fair suffix; asserting
     them per-step is the P4 Finding-A misclassification). *)

check_esr : ?depth:int -> Bound.t -> desired:int -> report
  (* seed = Scenario.seed ~desired ~fair:true (disruptors off = fair suffix);
     target    = (Invariants.liveness_goal ~cr).holds   (#11 current_state_matches)
     quiescent = Scenario.is_quiescent bound
     Model_check.check_reaches over bounded_successors.  Clean ⇒ ESR holds up to
     bounds; Refuted ⇒ a fair run settles off-goal. *)

check_esr_temporal : ?depth:int -> Bound.t -> desired:int -> report
  (* the formula-faithful cross-check: goal = Esr.Make(Vreplica_set)
     .eventually_stable_reconciliation_per_cr ~cr
       ~current_state_matches:(fun cr -> Temporal.lift_state ~name
                                 (Invariants.liveness_goal ~cr).holds)
     run through Model_check.check_temporal.  Its clean/refuted verdict must AGREE
     with check_esr on the same bounds (a test asserts agreement — the decision
     procedure and the P0 temporal evaluator cross-validate). *)
```
`cr = Scenario.vrs ~desired`, `controller_id = Scenario.controller_id`,
`cluster = Scenario.cluster`. Provide a `Bound.t` small enough to fixpoint quickly
(e.g. `Bound.default` or a tightened local one) so the DAG is fully explored and
`decisive = true` is actually achieved in tests.

## 4. Tests (`test/t_p5_*.ml`, wired into `test/dune`; run the exe directly —
`dunecho test` hangs, use `perl -e 'alarm 180; exec @ARGV' _build/default/test/
t_p5_*.exe`)

- `t_p5_model_check` — the generic engine on **toy graphs** (small hand-built
  `int` state machines, no cluster): (a) a safety violation reachable at depth 2 ⇒
  `Refuted` with the exact bad state + a valid stem; (b) a graph whose frontier
  empties ⇒ `No_counterexample { decisive = true }`; (c) same graph with `depth`
  too small ⇒ `decisive = false`; (d) a genuine cycle/livelock ⇒ `check_temporal`
  refutes `eventually q`; (e) the `fair` filter rejects an unfair livelock lasso so
  it is NOT reported; (f) `to_behaviour`/`satisfied_by` agree with a hand-built
  `Behaviour.Lasso` under `Temporal_eval`. **Confirm-by-mutation**: neuter the
  `equal` (make it always-false) ⇒ (b) loses `decisive` / diverges within a fuel
  guard; restore.
- `t_p5_state_eq` — `state_equal`/`state_hash` soundness: reflexive; a counter bump
  ⇒ unequal (and the checker treats the two as distinct); two states built with
  different map insertion order but equal contents ⇒ equal AND `state_hash` equal
  (the order-insensitivity that termination depends on). `Rpc_id_allocator.equal`
  after `allocate` ⇒ unequal.
- `t_p5_cluster_check` — the assurance legs on the vreplicaset scenario:
  `check_always` for `desired ∈ {0,1,2}` ⇒ `No_counterexample` (assert `decisive`
  for a bound that fixpoints); `check_esr` ⇒ `No_counterexample` (every reachable
  quiescent state matches); `check_esr_temporal` **agrees** with `check_esr`;
  `max_uid_seen`/`max_rv_seen` reported below the ceilings.
- `t_p5_mutation` — **confirm-by-mutation on the enumerator** (finding 14, the
  non-vacuity spine): for each of a representative safety invariant AND the ESR
  target, a locally-corrupted seed/model must make the checker `Refuted` under the
  SAME `Bound.t` (proving the bounds reach the violating interleaving); the
  `violated` field names the expected invariant. Each mutation is applied, the
  refutation observed, then restored (tree clean); an independent second mutation
  cross-confirms (`[[feedback-review-agents-may-leave-mutations]]`).

## 5. Convention firewall (audited; `[[INDEX-conventions]]`)

No loop keywords (`for`/`while`/`return`/`break`/`continue`) — BFS/DFS via
recursion + `List.fold_left`/`Queue` (a `Queue` is a library value, not a loop
keyword; recursion drives it). No `_ ->` wildcard on any finite sum — the `Step.t`
match in the labelled successor path is fully enumerated (12 arms). No two-arm
`match` on `option`/`result` — use `Option.fold`/`Option.map`/combinators. No
exceptions (`Res.t`/`option`), no `unwrap`/`assert`/`panic`, no `Stdlib.(=)`
polymorphic compare / `Hashtbl.hash` on states. `.mli` on every module; doc-comment
+ Anvil-or-arch source pointer on every public `val`. Dual-license headers not
required (in-repo lib). Combinators over mutation; gather-not-scatter.

## 6. Faithfulness / honest-limit notes (must appear in-code)

1. `decisive` is verification **only of the bounded system under this `Bound.t`** —
   never Anvil's theorem, never arbitrary cluster size (arch §4 anti-over-claim).
   For `check_temporal` it further requires `depth >= states` **and** an
   acyclic-modulo-self-loop reachable graph (fix-pass A): the DFS enumerates simple
   lassos only, so a genuine `>= 2`-state cycle (whose non-simple runs it cannot
   emit) forces `decisive = false`. The cluster graph is a stutter-only DAG, so
   this holds; the DAG argument is stated, not proved, in OCaml.
2. The DAG argument (§0.1) assumes the counter monotonicity that P1/P2 encode; a
   mutation test guards that pruning actually fires and that violations are
   reachable (non-vacuity).
3. **`check_esr` is an HONEST VACUOUS universal on this vreplicaset model.** The
   liveness gate — `Scenario.is_quiescent` and its intended replacement
   `effectively_quiescent` (no *state-changing* productive successor) — is
   empirically reachable at **0 states** at every feasible `Bound.t`: the reconcile
   never settles (the non-idempotent reschedule re-adds the CR; the monotone
   `rpc_id`/`reconcile_id` churn keeps producing fresh states). So a clean
   `check_esr` verifies **nothing** about ESR. This is a real *modeling* gap
   (Anvil-fidelity), not a checker bug, and it is **surfaced**, not hidden: the
   report field `gate_states : int option` is `Some 0` exactly when the universal
   is vacuous (fix-pass C). The **non-vacuous, decidable** liveness content here is
   goal-REACHABILITY (`current_state_matches` is reached within `depth`), witnessed
   by the bound-discriminated reaches-goal / M3 oracle (REFUTES under a generous
   bound, CLEAN under an rv-starved tight one). `effectively_quiescent` remains the
   correct definition and the general hook the day a counter-free settling state is
   modelled.
4. `check_esr` and `check_esr_temporal` are cross-checked on BOTH the clean/refuted
   class AND the `decisive` flag (fix-pass D makes `decisive` agree by ignoring
   unfair lassos rather than zeroing `all_true`); disagreement is a bug in one,
   caught by the agreement test.
5. The reachability legs (`check_safety`/`check_reaches`) present a bad state as
   `{ loop = [| s |] }`; that is a real run under the **stutter-closed precondition**
   (every reachable state self-loops), which the cluster satisfies via the
   always-enabled `Stutter_step`. `check_temporal` does NOT assume it and never
   fabricates a self-loop (fix-pass B).

### 6.1 Fix-pass addendum (2026-07-23) — two review rounds, 4 soundness fixes

The assurance spine caught real soundness bugs in the two decision procedures
(the `state_equal`/`state_hash` core and the convention firewall came back clean
both rounds). All fixed and confirm-by-mutation verified (each seen to bite via a
revert-probe): **A** decisive gated on `not cyclic` (genuine-cycle detection);
**B** `cand_a` stutter loop emitted only on a real self-loop (no fabricated run);
**C** `gate_states` surfaces the honest ESR vacuity instead of a misleading clean;
**D** unfair refuters ignored for decisiveness so `check_esr_temporal` agrees on
`decisive`. Green: `dunecho build` 0/0 + `dune build @check`; 28 P5 tests + 20 P4
regression. An independent refute-by-default re-review reproduced no residual
soundness violation.
</content>

# BUILD-SPEC-P13: fault-tolerant assurance (crash / transient-failure legs)

Normative in-repo contract for Phase 13 of the anvil-ocaml port. Hand-authored
before any code, in the P2..P12 tradition. Build agents implement THIS file.

Build env: `eval $(opam env --switch=anvil-ocaml --set-switch); dunecho build`
(0 warnings / 0 errors required). `dune test` HANGS; run one exe as
`perl -e 'alarm 150; exec @ARGV' _build/default/test/<name>.exe`. Whole battery:
`for e in _build/default/test/*.exe; do perl -e 'alarm 150; exec @ARGV' "$e" || echo "FAIL $e"; done`.

Branch: `p13-fault-assurance` off `main` @ `8a2a1ff`. Stage with `git add`; do
NOT commit (the user commits).

---

## 1. The gap this phase closes

The port already transcribes ALL twelve Anvil cluster actions
(`lib/cluster/step.ml:11-47` vs upstream `kubernetes_cluster/spec/cluster.rs:75`)
and `Cluster.enabled_successors` (`lib/cluster/cluster.ml:547-795`) enumerates
every one of them, faults included: `Restart_controller_step` (Anvil's crash
model), `Drop_req_step` (transient API failure), `Pod_monkey_step`,
`Builtin_controllers_step` (GC), plus the three `Disable_*` steps.

But the fault surface does NO load-bearing work in any decisive result today.
`Scenario.*seed*` sets `crash_enabled = req_drop_enabled = pod_monkey_enabled =
not fair` (`lib/assurance/scenario.ml:322-350, 365-402`), and:

- every DECISIVE gate seeds `~fair:true`, i.e. all three faults OFF:
  `check_esr` / `check_esr_settled` / `check_esr_temporal` (cluster_check.ml:390,
  432, 456), `check_esr_settled_vsts` / `check_esr_vsts` / `check_esr_temporal_vsts`
  (:540, :571, :668), and both P12 unique-reconcile-id gates (:643, :649);
- the only faults-ON legs are `check_always` (:365) and `check_always_vsts`
  (:503), and both are NON-decisive (infinite graph at `fair:false`).

So P12's headline `gate_states = Some 6952` witness is a FAULT-FREE witness, and
no invariant in the suite has ever been checked to a decisive verdict against a
crash. P13 makes the fault dimension load-bearing.

P13 is an ASSURANCE-CONSTRUCTION phase, NOT a model change. `lib/cluster/` is
NOT modified except as M1/M2 MUTANTS that must be reverted (section 6).

## 2. The design: a fault budget in the state, not in the enumerator

`Model_check.explore` takes `successors : 'a -> 'a list`, so a per-PATH fault
count cannot live in `Bound.t` (which bounds the per-STATE successor
enumeration). Instead P13 checks a PRODUCT transition system whose state carries
the fault counters:

```ocaml
type faulted = {
  cs : Cluster.cluster_state;
  crashes : int;   (* Restart_controller_step edges taken on the path *)
  drops : int;     (* Drop_req_step edges taken *)
  monkeys : int;   (* Pod_monkey_step edges taken *)
}
```

Two consequences, both load-bearing:

1. **Decisiveness.** Budget-clipping the fault edges makes the faults-ON graph
   finite, so P13 reports DECISIVE verdicts where `check_always_vsts ~fair:false`
   could only report non-decisive. The honest reading is "falsification up to
   (depth, `Bound.t`, `budget`)": one more disclosed dimension, strictly more
   than the zero faults checked today.
2. **The counters ARE the path witness.** Non-vacuity ("this state was reached
   AFTER a real crash") is a plain state predicate `crashes >= 1` on the product,
   so P13 needs NO edge-labelled exploration. Do not add one.

`Bound.t` is NOT extended (that would break 12 explicit record literals for no
gain). The budget is its own type in the new module, and its `.mli` MUST state
the reason above.

## 3. Reachability justification (soundness; state this in the .mli)

`Cluster.init` (`lib/cluster/cluster.ml:79-97`) REQUIRES all three fault flags
TRUE. So a seed with any flag false is not an init state. It is still SOUND to
explore from it, because every flag combination that is componentwise <=
`(true, true, true)` is reachable from an init state by a prefix of
`Disable_crash_step` / `Disable_req_drop_step` / `Disable_pod_monkey_step`, each
of which only flips its flag (cluster.ml:337, :385, :445). A safety violation
found from such a seed is therefore a genuine violation of a reachable
behaviour; a clean verdict is falsification-up-to-bounds of the SUFFIX
behaviours starting there. The pre-existing `~fair:true` seeds already rely on
exactly this argument (they are the all-disabled suffix). Note that the P13 G3
seed (all three faults ON) is the FIRST seed in the repo that satisfies
`Cluster.init` outright.

> **MEASURED CORRECTION (build stage 1, and pinned by
> `t_p13_faults.test_g3_seed_init_conjuncts`).** The last sentence above is
> FALSE as written and must not be quoted. `Cluster.init` at the all-faults-ON
> G3 seed measures **false**, because `Api_server.init`
> (`lib/cluster/api_server.ml:73`) requires an EMPTY etcd and the seed already
> holds the server-created CR. The corrected, measured claim, which is the
> load-bearing one and is the version written into `lib/assurance/scenario.mli`:
> the G3 seed satisfies every FAULT-FLAG conjunct of `Cluster.init`
> (`crash_enabled && req_drop_enabled && pod_monkey_enabled`),
> and the etcd conjunct is the ONLY failing one (the identical state with an
> empty etcd gives `Cluster.init = true`).
>
> **SECOND CORRECTION (review stage).** An earlier draft of this block repaired
> the sentence above by claiming the G3 seed is the *first* seed in the repo to
> satisfy the fault-flag conjuncts. That primacy claim is ALSO false and has been
> removed: `Scenario.vsts_seed ~desired ~fair:false` delegates to the identical
> `vsts_seed_faults ~crash:true ~req_drop:true ~pod_monkey:true` call
> (`lib/assurance/scenario.ml:380-382`), so it IS this seed by value, and it is
> live pre-P13 at `lib/checker/cluster_check.ml:503` (as is the VRS
> `Scenario.seed ~desired ~fair:false` at `:365`). No test compared seeds, so the
> primacy half could never have reddened. What is P13's own is the BUDGETED
> PRODUCT over such a seed, not the seed. Seed soundness is unaffected: the
> already-created CR rests on the same standing "a client created the CR before
> the reconcile starts" argument every seed in `scenario.ml` already rests on,
> and the `Disable_*` prefix argument above still covers the fault dimension.

## 4. What to build

### 4.1 `lib/checker/model_check.{ml,mli}` (one purely additive val)

```ocaml
val fold_states : 'a reachable -> init:'b -> f:('b -> 'a -> 'b) -> 'b
```
Doc: visits each DISTINCT reachable state exactly once, order unspecified;
`count_states_where` is the special case counting a predicate. Do NOT change
`explore` / `check_safety` / `check_reaches` / `count_states_where` behaviour:
all 47 existing exes must stay green.

### 4.2 `lib/assurance/scenario.{ml,mli}` (additive seeds, zero behaviour change)

```ocaml
val vsts_seed_faults :
  desired:int -> crash:bool -> req_drop:bool -> pod_monkey:bool -> Cluster.cluster_state

val vsts_seed_multi_faults :
  desireds:int list -> crash:bool -> req_drop:bool -> pod_monkey:bool -> Cluster.cluster_state
```

Implement by generalising the existing bodies: `vsts_seed ~desired ~fair` MUST
become `vsts_seed_faults ~desired ~crash:(not fair) ~req_drop:(not fair)
~pod_monkey:(not fair)` and `vsts_seed_multi ~desireds ~fair` likewise, so the
`~fair` seeds stay BYTE-IDENTICAL in behaviour (verify: the whole battery stays
green and the P12 pin 6952 is unchanged). Objects are still admitted through the
REAL `Api_server.handle_create_request` (uid/rv server-stamped, never forged).
The `.mli` carries the section-3 reachability argument.

### 4.3 `lib/checker/fault_check.{ml,mli}` (NEW, the phase)

```ocaml
type budget = { max_crashes : int; max_drops : int; max_monkey_ops : int }
val budget_default : budget            (* { 1; 1; 1 } *)
val budget_crash_only : budget         (* { 1; 0; 0 } *)

type faulted = { cs : Cluster.cluster_state; crashes : int; drops : int; monkeys : int }

val faulted_of_seed : Cluster.cluster_state -> faulted   (* counters at 0 *)
val faulted_equal : faulted -> faulted -> bool           (* Cluster_check.state_equal AND the 3 ints *)
val faulted_hash : faulted -> int                        (* Cluster_check.state_hash mixed with the 3 ints *)

val faulted_successors : Bound.t -> budget -> Cluster.t -> faulted -> faulted list

type fault_report = {
  outcome : faulted Model_check.outcome;
  bound : Bound.t;
  budget : budget;
  max_uid_seen : int;
  max_rv_seen : int;
  max_crashes_seen : int;
  max_drops_seen : int;
  max_monkeys_seen : int;
  pruned_by_ceiling : bool;
  pruned_by_budget : bool;
  violated : Invariants.invariant option;
  gate_states : int option;
  crash_witness_states : int;
  fault_free_states : int;
  settled_with_faults_live : int;
}

val check_invariants_under_faults : ?depth:int -> Bound.t -> budget -> desired:int -> fault_report
val check_unique_reconcile_id_under_faults : ?depth:int -> Bound.t -> budget -> desireds:int list -> fault_report
val check_settles_after_disable : ?depth:int -> Bound.t -> budget -> desired:int -> fault_report
```

`faulted_successors` maps each `(step, cs')` of
`Cluster_check.bounded_labelled_successors bound cluster f.cs` to a `faulted`,
classifying the step with an EXHAUSTIVE twelve-arm match (copy the exact
constructor spelling and arm order from `lib/assurance/scenario.ml:619-638`; NO
`_ ->` arm):

- `Restart_controller_step _` -> `crashes + 1`, DROP the successor if it would
  exceed `budget.max_crashes`;
- `Drop_req_step _` -> `drops + 1`, drop if over `budget.max_drops`;
- `Pod_monkey_step _` -> `monkeys + 1`, drop if over `budget.max_monkey_ops`;
- all nine remaining arms (`Api_server_step`, `Builtin_controllers_step`,
  `Controller_step`, `Schedule_controller_reconcile_step`, `Disable_crash_step`,
  `Disable_req_drop_step`, `Disable_pod_monkey_step`, `External_step`,
  `Stutter_step`) -> counters UNCHANGED.

The three `Disable_*` steps are fault-DISABLING, not faults: they must never
consume budget, or G3 becomes unreachable.

Metadata is computed in ONE `Model_check.fold_states` pass over the reachable
product set: the five maxima, `crash_witness_states` (`crashes >= 1`),
`fault_free_states` (all three counters 0), `settled_with_faults_live` (see G3),
and both pruning flags. `pruned_by_ceiling` for a visited state is
`List.length (Cluster.enabled_successors bound cluster f.cs) >
List.length (Cluster_check.bounded_labelled_successors bound cluster f.cs)`;
`pruned_by_budget` is "some labelled successor was dropped by a budget cap".
Reuse `Cluster_check.state_equal` / `state_hash` / `bounded_labelled_successors`
/ `settled` (all already exported); do NOT re-derive them.

### 4.4 The three gates

**G1 `check_invariants_under_faults ~desired`** (the experiment; may find a real
defect). Seed `Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
~pod_monkey:false`, `budget_crash_only`. Invariants: the FULL shipped suite
`Vsts_invariants.always ~cr:(Scenario.vsts ~desired ()) ~controller_id:Scenario.controller_id`
(= `Invariants.cluster_structural` inv1-6 plus the 3 VSTS invariants). Check
`Invariants.conjunction invs` via `Model_check.check_safety`; on `Refuted` set
`violated = Invariants.first_violated ...` at the counterexample state.
`gate_states = Some (count where crashes >= 1 && some inv .interesting)`.

**If G1 REFUTES, that is a RESULT, not a build failure.** Report the named
invariant and the counterexample. Then, and only then, decide:
(a) the port's invariant is STRONGER than Anvil's crash-tolerant version -> a
fidelity finding; weaken it ONLY with a verbatim upstream citation showing
Anvil's statement is conditioned on the reconcile being ongoing (or similar),
and record the citation in the .mli; or (b) it is a genuine modeling gap ->
disclose it in the .mli and pin the refutation as the expected outcome.
NEVER weaken or delete an invariant just to make a gate green, and never
narrow the suite to dodge a refutation.

**G2 `check_unique_reconcile_id_under_faults ~desireds`** (P12 strengthened).
Seed `Scenario.vsts_seed_multi_faults ~desireds ~crash:true ~req_drop:false
~pod_monkey:false`, `budget_crash_only`, invariant
`Invariants.unique_reconcile_id_invariant ~controller_id:Scenario.controller_id`.
`gate_states = Some (count where cardinal(ongoing) >= 2 && crashes >= 1)`: the
>= 2-concurrent-reconciles-AFTER-A-CRASH witness, strictly stronger than P12's
6952 (which had `crashes = 0` by construction). Witness `desireds = [1; 1]`.

**G3 `check_settles_after_disable ~desired`** (Anvil `failures_liveness` shape).
Seed `Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:true
~pod_monkey:true` (satisfies every fault-flag conjunct of `Cluster.init`, but
NOT `Cluster.init` itself - see the MEASURED CORRECTION in section 3),
`budget_default`. Use
`Model_check.check_reaches` (read its .mli doc first and honour its exact
target/quiescent contract) with
`target f = Cluster_check.settled bound cluster f.cs && all three fault flags
FALSE in f.cs` (crash flag via the `controller_and_externals` entry for
`Scenario.controller_id`). Non-vacuity contrast, both measured in the same fold:
`fault_free_states > 0` (the Disable trio is actually taken) and
`settled_with_faults_live` = count of states that are `settled` while any fault
flag is still TRUE. Report both; do not assert a predicted value for
`settled_with_faults_live` in the spec, MEASURE it and pin what you measure.

### 4.5 Tests

- `test/p13_witness.ml` (shared non-test module, `p12_witness.ml` precedent:
  NOT in `(names)`, dune links it into every exe): single source of truth for
  the P13 bound, the budgets, `witness_desireds`, and every pinned measured
  number. No pinned number may appear in two files.
- `test/t_p13_faults.ml`: the three gates; for each assert the SEMANTIC facts
  FIRST (outcome shape, `violated`, decisiveness, gate > 0 or the disclosed
  pinned value) and only THEN the brittle exact counts. This ordering is
  mandatory: P12 review finding 1 was a confirm-by-mutation that reddened at a
  pinned count before reaching the semantic assertion, leaving the Refuted path
  with zero coverage. Include a `test_gate_refutes_forged_collision`-style
  discriminator per gate: a hand-forged faulted state that MUST be `Refuted`, so
  the Refuted branch is genuinely covered. Include a robustness leg with a
  self-contained floor (`gate > 0`), not only relative comparisons.
- `test/t_p13_mutation.ml`: the automated pins M3/M4/M5 of section 6.
- Add the three modules to `test/dune` `(names ...)` (t_p13_faults,
  t_p13_mutation; p13_witness stays unnamed) -> 49 exes. Battery target 49/49.

## 5. Tractability

Crash-only with budget 1 multiplies the P12 graph by the number of distinct
post-crash epochs, so expect low single-digit growth over P12's 8580 states.
Start from the P12 bound shape (`test/p12_witness.ml:9-24`) and
`desireds = [1; 1]`. If a gate exceeds ~120 s, retune in this order:
`reconcile_ceiling` down, then `depth` down, then `max_in_flight` down, and
DOCUMENT every retune in `p13_witness.ml` plus the .mli. Never silently drop
coverage: if a dimension is reduced, say so in the report docs.

## 6. Confirm-by-mutation matrix

M1 and M2 are MANUAL mutants of real `lib/cluster/cluster.ml` source, applied
with the Edit tool, MEASURED, then REVERTED (only green pins ship; `git status`
must show `lib/cluster/` untouched at the end). Never `git checkout` a file to
revert a mutation while it holds unstaged fixes (P12 process lesson: it wipes
them). M3/M4/M5 are permanent automated pins.

- **M1 (faithfulness):** make `restart_controller` NOT clear
  `ongoing_reconciles`. PREDICTION: G1 refutes (a pre-crash ongoing reconcile
  survives a restart). MEASURE and record which invariant breaks.
- **M2 (faithfulness):** make `restart_controller` reset
  `reconcile_id_allocator` to `Controller.Reconcile_id_allocator.init ()` instead
  of preserving it (upstream preserves it deliberately, cluster.rs:388-392).
  PREDICTION: G2 does NOT refute, because a restart CLEARS `ongoing_reconciles`,
  so the post-crash epoch re-allocates from 0 into an empty map and the ids in
  `ongoing_reconciles` stay pairwise distinct. If the measurement confirms this,
  DISCLOSE in the .mli that inv6 is insensitive to allocator reset and name
  where crash-sensitivity actually lives (G1 / G3). Do NOT claim a crash
  adversary for inv6 that the measurement does not support, and do NOT invent a
  new invariant just to manufacture one.

> **MEASURED OUTCOMES of M1 and M2 (build stage 5; full disclosure lives on
> `check_invariants_under_faults` and `check_unique_reconcile_id_under_faults`
> in `fault_check.mli`, protocol in the header of `test/t_p13_mutation.ml`).**
> **M1's PREDICTION FAILED.** Keeping the pre-crash `ongoing_reconciles` refutes
> NOTHING: G1, G2 and G3 all stay `No_counterexample`, `decisive = true`,
> `violated = None`. The mutant is caught only by the PINNED counts (G1 464
> states down to 152, `gate_states` 388 down to 76; G2's `gate_states` stays
> 2784, so a gate-only pin would have missed it). The reason is structural: every
> member of the nine-invariant suite is etcd-local, or monotone in the uid /
> reconcile-id counters, or about request interference, and a surviving ongoing
> reconcile keeps its already-distinct id and already-lower uid. M1 breaks a
> TRANSITION-relation fact ("a restart clears the controller's in-flight work"),
> which a state-invariant suite cannot express.
> **M2's prediction HELD** (no refutation), for the reason given above it.
> Taken together these two are the phase's honest NEGATIVE result: P13 certifies
> the shipped invariants ACROSS a crash, and does NOT certify the faithfulness
> of the crash transition itself. Making a shipped invariant genuinely
> crash-SENSITIVE needs a `pending_req_msg`-correspondence invariant family of
> the kind upstream keeps in
> `src/kubernetes_cluster/proof/controller_runtime_safety.rs`; that is P14 work,
> deliberately not smuggled in here.
- **M3 (vacuity detector, automated):** the same gate seeded `~crash:false`
  MUST report `crash_witness_states = 0` and `gate_states = Some 0`.
- **M4 (budget pin, automated):** `max_crashes = 0` MUST give
  `crash_witness_states = 0` and `pruned_by_budget = true`.
- **M5 (classifier pin, automated):** a local copy of `faulted_successors` that
  mis-classifies `Restart_controller_step` as a non-fault MUST be caught: with
  it, `max_crashes_seen` stays 0 while restart edges are still taken, so assert
  the real classifier gives `max_crashes_seen >= 1` on the G2 graph.

## 7. Convention firewall (non-negotiable)

Combinators only: no `for` / `while`, no `Iterator::scan`-style rewrap, fold /
map / filter_map over explicit recursion where a combinator exists. No wildcard
(`_ ->`) arm on ANY finite sum, the twelve-arm `Step.t` match above especially.
No exceptions, `assert`, `failwith`, `Option.get`, `List.nth` in `lib/`
(guarded `Option.fold` / `nth_opt` instead); `bin/` may exit. No two-arm match
on `option` / `result` (use combinators). No mutable state in `lib/`. Doc
comment on EVERY `.mli` item, each ported concept citing its Anvil source as
`file.rs:line`. Records in the new module follow the `Cluster_check.report`
precedent (plain readable fields).

## 8. Honest limits (bake into code and docs)

Bounded falsification up to (depth, `Bound.t`, `budget`); transfers no part of
Anvil's Verus theorem. The fault budget is a NEW disclosed dimension: a bug
needing more than `max_crashes` crashes (or more drops / monkey ops) on one path
is excluded by construction. G1/G2 explore the crash dimension ONLY (req_drop
and pod_monkey off) to isolate it and stay decisive; G3 is the only leg with all
three live. `settled` treats `Pod_monkey_step` as PRODUCTIVE
(`scenario.ml:619-638`), so a state can only be `settled` once the monkey is
disabled or has no enabled op: state this explicitly in the G3 docs, since it is
why G3 needs the Disable trio and not merely a quiet suffix.

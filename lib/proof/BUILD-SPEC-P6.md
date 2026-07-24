# BUILD-SPEC-P6 — Typed entailment DSL: the vreplicaset ESR liveness skeleton

Normative contract for **P6** of the anvil-ocaml port (architecture
`comp-cat-ocaml/lib/temporal/ARCHITECTURE-anvil-ocaml.md` §5 P6 row; DESIGN
§2.6/§2.7). Hand-authored (design + the three crux `.mli` are load-bearing); the
`.ml` bodies and tests are delegated to the build workflow and MUST satisfy this
contract and the published signatures verbatim.

## 0. What P6 is (and is not)

**Is:** the vreplicaset eventually-stable-reconciliation (ESR) liveness proof
*skeleton* (Anvil `controllers/vreplicaset_controller/proof/liveness`) ported as
a `Comp_cat.Rule` entailment derivation. Every `leads_to` edge is a
`Comp_cat.Rule.wf1` (or a `borrow_inv`/`leads_to_weaken`) whose **operational
side-conditions are DISCHARGED by the P5 bounded model checker** (`Discharge`),
and whose chaining shape is checked by `Comp_cat.Temporal.equal` middle-matching
(the regression-lock on Anvil's proof structure).

**Is not:** machine-checked. The `wf1` omega-induction (fair progress ⇒ `~>`) is
TRUSTED-on-stream; only the finite-graph obligations (`closure`/`drives`/`[]j`)
are CHECKED. A clean derivation verifies the **bounded** system under `Bound.t`
and transfers **no** part of Anvil's Verus theorem (arch §4). This is
"compiled documentation" (P6 row).

The P0 `Comp_cat.Rule` fact kernel already exists (`assume`, `leads_to_self`,
`leads_to_trans`, `or_leads_to`, `leads_to_weaken`, `leads_to_apply`,
`borrow_inv`, `init_invariant`, `wf1`). **P6 adds NO combinator to P0** — it is a
pure consumer, self-contained in `anvil-ocaml/lib/proof/`. Do not edit
comp-cat-ocaml.

## 1. Deliverable

New library `anvil_proof` at `lib/proof/` (dune already written; deps mirror
`lib/checker/dune` + `anvil_checker`). Three modules + tests + this spec:

- `step_view.{mli✔,ml}` — read the reconcile position out of a `cluster_state`.
- `discharge.{mli✔,ml}` — the P5 bridge: finite-graph edge obligations.
- `vrs_liveness.{mli✔,ml}` — the skeleton derivation + the ESR headline.
- `test/t_p6_step_view.ml`, `test/t_p6_discharge.ml`, `test/t_p6_vrs_liveness.ml`,
  `test/t_p6_mutation.ml` (confirm-by-mutation).

The `.mli` are FROZEN (published). Implement to them exactly.

## 2. `step_view.ml` — the accessor

Reuse the P4 template `lib/assurance/invariants.ml:223-226` verbatim in shape:

```
let reconcile_step_of ~controller_id ~cr_key s =
  Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id)
  |> Option.map (fun (orc : Controller.ongoing_reconcile) -> orc.local_state)
  |> fun lo ->
  Option.bind lo (fun v ->
    Vreplica_set_pack.unmarshal_state v
    |> Result.fold ~ok:(fun (st : Vreplica_set_reconciler.s) -> Some st.reconcile_step)
                   ~error:(fun _ -> None))
```

- `at_step ... step s = Option.fold (reconcile_step_of ...) ~none:false
  ~some:(fun st -> Vreplica_set_reconciler.step_equal st step)`.
- `at_phase ... phase s = Option.fold (reconcile_step_of ...) ~none:false
  ~some:phase`.
- `scheduled_only ~controller_id ~cr_key s = Object_ref_map.mem cr_key
  (Cluster.scheduled_reconciles s controller_id) && no_ongoing ...`.
- `no_ongoing ... s = Option.is_none (reconcile_step_of ...)`.

**Conventions:** NO two-arm `match` on `option`/`result` — use
`Option.fold`/`Option.map`/`Option.bind`/`Result.fold`. NO loop keywords. Confirm
`Object_ref_map.mem`/`find_opt` exist (they do: invariants.ml uses `find_opt`,
`bindings`, `cardinal`, `for_all`, `is_empty`); if `mem` is absent use
`Option.is_some (find_opt ...)`.

## 3. `discharge.ml` — the P5 bridge

One private helper builds the reachable graph once per call:

```
let reach bound cluster ~init ~depth =
  Model_check.explore ~depth
    ~successors:(Cluster_check.bounded_successors bound cluster)
    ~equal:Cluster_check.state_equal ~hash:Cluster_check.state_hash
    ~init:[ init ]
```

`depth` default = a value that fixpoints the tightened graph; expose
`?depth` only on `reaches_holds` per the `.mli` (the others take the module's
internal default, e.g. `64` — large enough that `frontier_emptied` is the real
gate, not `depth`). Then, using ONLY `Model_check.count_states_where` /
`states_seen` / `frontier_emptied` (never a hand-rolled fold; no loop keywords):

- `closure_holds bound cluster ~init ~pre ~post`:
  ```
  let r = reach ... in
  let bad = Model_check.count_states_where r (fun s ->
    pre s && List.exists (fun s' -> not (pre s' || post s'))
                         (Cluster_check.bounded_successors bound cluster s)) in
  { holds = (bad = 0);
    witnesses = Model_check.count_states_where r pre;
    states_checked = Model_check.states_seen r;
    frontier_emptied = Model_check.frontier_emptied r }
  ```
- `drives_holds ... ~pre ~forward ~post`: as above but `bad` uses
  `Cluster_check.bounded_labelled_successors` and
  `List.exists (fun (step, s') -> forward step && not (post s'))`.
- `invariant_holds ... ~inv`: `bad = count_states_where r (fun s -> not (inv s))`;
  `witnesses = states_checked`.
- `reaches_holds ?depth ... ~pre ~post`:
  `{ holds = (count_states_where r post > 0); witnesses = count_states_where r pre;
     states_checked; frontier_emptied }`.
- `obligation rep =`
  `if rep.holds && rep.witnesses > 0 && rep.frontier_emptied then Comp_cat.Res.ok true`
  `else Comp_cat.Res.error (Comp_cat.Err.Ill_formed { fn = "Discharge.obligation";
   why = <"violated" | "vacuous (witnesses=0)" | "graph truncated"> })`.
  Choose `why` by testing `holds`, then `witnesses > 0`, then `frontier_emptied`
  (a plain `if/else if` chain of boolean guards — NOT a keyword loop).

`edge_report` fields are public (mirrors `Cluster_check.report`'s public fields —
the "no pub fields" convention is about newtype opacity, not these evidence
records).

## 4. `vrs_liveness.ml` — the skeleton

### 4.1 Constants

- `controller_id = Scenario.controller_id`, `cr_key = Scenario.vrs_ref`.
- `tightened_bound` = the finite fair bound at which the `desired = 1` reachable
  graph closes AND every body milestone (through `After_update_vrs_status` and
  `Done`) is reached. Field set (confirm against `bound.mli`): `{ max_in_flight;
  max_objects_per_kind; max_controllers; uid_ceiling; rv_ceiling;
  max_reconcile_depth }`. **`rv_ceiling = 1` is too tight** — one reconcile pass
  writes (create pod, then update status), so it needs `rv` past 1 to reach
  `After_update_vrs_status`/`Done`; a too-tight ceiling prunes the reconcile
  before those milestones and starves the body edges. **TUNE empirically, do not
  guess** — the answer is NON-MONOTONE: `rv_ceiling = 2` is the minimum-AND-only
  value satisfying every criterion. `rv = 1` starves (e4 pre never reached);
  `rv >= 3` is WORSE — the graph explodes past the frontier
  (`frontier_emptied = false`) AND e2's `closure` becomes genuinely FALSE (in a
  second cycle the pass-1 pod persists, `diff = 0`, so `After_list_pods` skips
  `at_creating` and advances straight to `After_update_vrs_status` — a real
  successor outside e2's `post`; the checker correctly refuses). Final bound:
  `{ max_in_flight = 2; max_objects_per_kind = 2; max_controllers = 1;
  uid_ceiling = 3; rv_ceiling = 2; max_reconcile_depth = 8 }` — `rv_ceiling = 2`
  is the ceiling that ISOLATES the first scale-up pass (§4.7 gap 6). At it, at
  `desired = 1` from `Scenario.seed ~fair:true`: (a) `frontier_emptied` true
  (14-state closed graph), (b) every body edge `witnesses > 0` and `holds = true`,
  (c) the tail invariant holds, (d) the front `reaches_holds` holds & non-vacuous.
  Record these numbers + the WHY in the `tightened_bound` source comment.

### 4.2 Milestone formulas (all hash-consed `lift_state`s)

Build each with `Comp_cat.Temporal.lift_state ~name pred`. STABLE names (the
hash-cons key) — reuse the SAME name string everywhere a milestone recurs, so the
`leads_to` middles are `Temporal.equal`:

- `f_desired_state_is ~desired` : `lift_state ~name:"desired_state_is"
  (Esr.Make(Vreplica_set).desired_state_is (Scenario.vrs ~desired))`.
- `f_scheduled` : `lift_state ~name:"scheduled" (Step_view.scheduled_only
  ~controller_id ~cr_key)`.
- `f_at step` : `lift_state ~name:("at_" ^ step_tag step) (Step_view.at_step
  ~controller_id ~cr_key step)` where `step_tag` names each `step` constructor
  (fully enumerated, no wildcard).
- `f_at_creating` : `lift_state ~name:"at_creating" (Step_view.at_phase
  ~controller_id ~cr_key is_after_create_pod)` where `is_after_create_pod` matches
  `After_create_pod _ -> true` and every OTHER `step` arm `-> false` (enumerate
  all 7 arms; no `_ ->`).
- `f_current_state_matches ~desired` : `lift_state ~name:"current_state_matches"
  (Invariants.liveness_goal ~cr:(Scenario.vrs ~desired)).holds`.

### 4.3 `spec` (the shared ambient assumption)

A single stable value threaded through every `assume`/`wf1`. Content is
documentation; the kernel only checks facts SHARE it. Build once per `desired`:

```
spec ~desired =
  Temporal.conj (f_desired_state_is ~desired)
    (Temporal.conj (Temporal.always (lift_action ~name:"cluster_next" next_ap))
       (lift_state ~name:"fair_controller" (fun _ -> true)))
```

where `next_ap s s' = List.exists (fun t -> Cluster_check.state_equal s' t)
(Cluster_check.bounded_successors tightened_bound Scenario.cluster s)` (a genuine
bounded next-relation; trusted as the `[]next` axiom). Memoize `spec ~desired` so
every combinator gets the physically-same node.

### 4.4 The `wf1_edge` helper (the crux — one place, correct once)

Every step edge is one call. Given `~pre_pred ~pre_name ~post_pred ~post_name
~forward_label ~forward_ap ~forward_name ~bound ~init ~desired`, returns
`(edge, Comp_cat.Res.t)`:

1. `pre = lift_state ~name:pre_name pre_pred`,
   `post = lift_state ~name:post_name post_pred`.
2. `enabled_pred s = List.exists (fun (step, _) -> forward_label step)
   (Cluster_check.bounded_labelled_successors bound Scenario.cluster s)`,
   `e = lift_state ~name:("enabled_" ^ forward_name) enabled_pred`.
3. Assumed (trusted spec) facts — all `Rule.assume ~spec:(spec ~desired)`:
   - `always_next = assume (Temporal.always (lift_action ~name:"cluster_next"
     next_ap))` (SAME `next_ap`/name as §4.3 so it is one node).
   - `pre_enables = assume (Temporal.always (Temporal.implies pre e))`.
   - `fair = assume (Temporal.weak_fairness ~pre_name:("enabled_" ^ forward_name)
     enabled_pred ~fwd_name:forward_name forward_ap)`. (This is
     `leads_to (always e) (lift_action forward)`; `wf1` checks `fair`'s premise is
     `always e` and `pre_enables`'s consequent is `e` — they MUST be the same node,
     so reuse `enabled_pred` + the name.)
4. Discharge the two CHECKED obligations:
   - `c_rep = Discharge.closure_holds bound Scenario.cluster ~init ~pre:pre_pred
     ~post:post_pred`.
   - `d_rep = Discharge.drives_holds bound Scenario.cluster ~init ~pre:pre_pred
     ~forward:forward_label ~post:post_pred`.
5. `fact_res = Rule.wf1 ~spec:(spec ~desired) ~pre ~post
     ~closure:(fun () -> Discharge.obligation c_rep)
     ~drives:(fun () -> Discharge.obligation d_rep)
     ~always_next ~pre_enables ~fair`.
6. Return `Result.map (fun fact -> { name; fact; report = c_rep }) fact_res`
   (record the closure report as the edge evidence; `d_rep` is folded into the
   `obligation`). Name via the caller.

**Forward labels** (each `forward_label : Step.t -> bool`, all 12 `Step.t` arms
enumerated, no wildcard):
- schedule: `Schedule_controller_reconcile_step (cid, k) -> cid = controller_id &&
  Common.equal_object_ref k cr_key`, all else `false`.
- controller (run/continue/end): `Controller_step (cid, _, kopt) -> cid =
  controller_id && Option.fold kopt ~none:false ~some:(fun k ->
  Common.equal_object_ref k cr_key)`, all else `false`.

(Ref equality is `Common.equal_object_ref : object_ref -> object_ref -> bool`.)

**Forward action_preds** (`forward_ap : cluster_state -> cluster_state -> bool`)
may be a faithful placeholder named for the action (they seed only the trusted
`fair`/`lift_action` leaf, whose CONTENT the kernel does not evaluate): use
`next_ap` (bounded successor) — sound as "some fair step relates s,s'".

### 4.5 The edge list (`edges`) — the reconcile BODY, desired = 1

The reconcile core (P3) for `desired = 1`, empty cluster, walks
`Init → After_list_pods → After_create_pod _ → After_update_vrs_status → Done`
(confirmed against `vreplica_set_reconciler.ml`). `edges` is exactly the BODY
chain — the reconcile advances that ARE clean single-step `wf1` drives:

| # | name | pre → post | forward |
|---|------|-----------|---------|
| e1 | `lemma_init_to_after_list_pods` | `at Init` → `at After_list_pods` | controller |
| e2 | `lemma_after_list_to_create` | `at After_list_pods` → `at_creating` | controller |
| e3 | `lemma_create_to_after_update_status` | `at_creating` → `at After_update_vrs_status` | controller |
| e4 | `lemma_after_update_status_to_done` | `at After_update_vrs_status` → `at Done` | controller |

Each row = one `wf1_edge`. `edges` returns them as `edge list Comp_cat.Res.t`
(fail-fast: `Comp_cat.Res.all`, which preserves order and short-circuits on the
first `Error` — NO loop keyword, NO exception).

**The front (getting INTO `at Init`) is NOT a `wf1` edge.** In the cyclic
reconcile model (Init→…→Done→end→idle→schedule→run→Init→…), the schedule/run step
is NOT a single-step `drives`: from a reachable `desired_state_is` state a
reconcile may already be ongoing, so `Schedule_controller_reconcile` does not
yield `scheduled_only` in one step, and a `wf1` `desired ~> scheduled`/`~> at Init`
correctly FAILS its `drives` discharge (the checker refusing a false single-step
claim — the assurance spine working, like the P4/P5 self-catches). Anvil proves
this as a MULTI-STEP `always eventually scheduled` + `wf(run)` argument. The
honest bounded realization is a **reachability discharge**, done in §4.6, not
here. `f_scheduled` stays exposed as the milestone the reachability front passes
through, but is not in the `wf1` chain.

### 4.6 Assembly (`esr_derivation`)

Front (reachability-discharged), body (`edges`), tail (invariant-discharged
weaken), chained by `leads_to_trans`:

```
1. front = a REACHABILITY-discharged assumption (the scheduling/fairness step):
     front_rep = Discharge.reaches_holds tightened_bound Scenario.cluster ~init
                   ~pre:desired_state_is ~post:(at_step Init)
     if Discharge.obligation front_rep is Ok true then
        front_fact = assume spec (leads_to (always f_desired_state_is) (f_at Init))
     else Error (at Init is NOT reachable from the fair desired seed — vacuous
        or truncated; the whole derivation fails, honestly).
   (Antecedent is `always desired_state_is` to match the ESR shape; it is an
   ASSUMED leads_to justified by the bounded reachability of `at Init` from the
   `desired` seed — Anvil's `always eventually scheduled` step, discharged as
   reachability, not a single-step drive. Record front_rep as an edge.)
2. tail = an INVARIANT-discharged assumption:
     tail_rep = Discharge.invariant_holds tightened_bound Scenario.cluster ~init
                  ~inv:(fun s -> (not (at_done s)) || current_state_matches s)
     if Discharge.obligation tail_rep is Ok true then
        j = assume spec ([](at_done => current_state_matches))
        tail_fact = leads_to_weaken ~pre:(assume spec ([](at_done => at_done)))
                       ~post:j (leads_to_self ~spec (f_at Done))
        ⇒ at Done ~> current_state_matches
     else Error (the tail invariant did not hold / was vacuous).
3. chain = leads_to_trans front_fact
             (leads_to_trans e1 (leads_to_trans e2 (leads_to_trans e3
               (leads_to_trans e4 tail_fact))))
     ⇒ (always desired_state_is) ~> current_state_matches
```

`front_fact`'s consequent (`at Init`) is `e1`'s antecedent, so the first
`leads_to_trans` middle matches; `e4`'s consequent (`at Done`) is `tail_fact`'s
antecedent. `leads_to_trans` folds the middles by `Temporal.equal`; a mismatch is
`Err.Ill_formed`. Thread all `Res.t` with `Result.bind` (NO two-arm match).
`esr_derivation` returns the final `fact Comp_cat.Res.t`. (`init` everywhere =
`Scenario.seed ~desired ~fair:true`.)

- `esr_statement_core ~desired = Temporal.leads_to (Temporal.always
  (f_desired_state_is ~desired)) (f_current_state_matches ~desired)`.
- `matches_esr_statement ~desired = Result.map (fun fact ->
  Temporal.equal (Rule.goal_of fact) (esr_statement_core ~desired))
  (esr_derivation ~desired)` — flatten to `bool Comp_cat.Res.t` (`Result.bind`
  into `Res.ok`).
- `tail_matches_is_stable ~desired = Discharge.invariant_holds tightened_bound
  Scenario.cluster ~init:(Scenario.seed ~desired ~fair:true)
  ~inv:(fun s -> (not (current_state_matches_reached s)) || current_state_matches s)`
  — the decidable content of Anvil's `leads_to_always` stability step; the honest
  evidence for the consequent-`always` gap. (Simplest faithful form: `inv = fun s
  -> current_state_matches s || not (at_done s || past_done s)`; if a clean
  "already-matched" predicate is unavailable, use `inv = current_state_matches`
  RESTRICTED to the sub-graph reachable from the first matching state — document
  the exact predicate chosen.)

`init` everywhere = `Scenario.seed ~desired ~fair:true` (the fair, disruptor-off
seed Anvil's leads_to assumes).

### 4.7 Honest scope gaps (put in module doc + here; DO NOT paper over)

1. **Consequent `always` dropped.** Derived goal is `always(desired) ~>
   current_state_matches`, not `~> always(current_state_matches)`. The kernel has
   no `leads_to_always`; the stability step is trusted, cross-checked by
   `tail_matches_is_stable`.
2. **Antecedent `always` via a trusted tautology.** `[](always desired =>
   desired)` is `assume`d (temporal validity, not a finite-graph fact), alongside
   fairness and `[]next`.
3. **`wf1` internal omega-induction trusted-on-stream.** Only `closure`/`drives`/
   `[]j` are model-checked; a bug in `wf1` itself is caught only by
   mutation-confirmed lasso checking (arch §2.6), not by P6.
4. **Bounded.** Everything holds only up to `tightened_bound`; transfers nothing
   from Anvil's Verus theorem (arch §4).
5. **Front discharged as reachability, not a single-step drive.** The scheduling
   step `always(desired) ~> at Init` is `assume`d, gated by a bounded
   `reaches_holds` (at Init is reachable from the fair desired seed), because in
   the cyclic reconcile model it is genuinely multi-step (Anvil's `always
   eventually scheduled` + `wf(run)`), NOT a `wf1` single-step `drives` — a `wf1`
   there correctly fails to discharge. Weaker evidence than the body edges'
   `closure`+`drives`; stated as such. This is a P6 self-catch (the discharge
   refused a false `wf1`), analogous to P4 Finding-A / the P5 vacuity surface.
6. **First-pass scale-up scope.** The linear body chain is faithful to the FIRST
   reconcile pass from an empty cluster only; in steady state the pass-1 pod
   persists so `After_list_pods` skips the create phase (e2's `closure` is
   genuinely false beyond pass 1). `rv_ceiling = 2` isolates that pass. P6 claims
   first-pass reconcile liveness on the fully-explored 14-state slice, nothing
   about steady-state cycles. This is the SECOND P6 self-catch — the checker
   refusing to certify e2 at `rv >= 3` is what pins the honest scope (§4.1).

## 5. Tests (alcotest; run via `_build/default/test/t_p6_*.exe`, `dune test`
hangs — wrap `perl -e 'alarm 180; exec @ARGV' ...`)

- `t_p6_step_view`: on `Scenario.seed`, `reconcile_step_of` is `None` before run,
  `Some Init` after one `Run_scheduled_reconcile`; `at_step`/`at_phase`/
  `scheduled_only`/`no_ongoing` agree; unmarshal-failure path returns `None`
  (feed a corrupt `Value.t`).
- `t_p6_discharge`: `closure_holds`/`drives_holds`/`invariant_holds`/`reaches_holds`
  return `holds = true` with `witnesses > 0` and `frontier_emptied = true` for the
  real edges; `obligation` is `Ok true`. A deliberately-wrong `post`
  (`fun _ -> false`) gives `holds = false` ⇒ `obligation` `Error`. A `pre` never
  reached (`fun _ -> false`) gives `witnesses = 0` ⇒ `obligation` `Error`
  (VACUITY guard).
- `t_p6_vrs_liveness` (the headline): `edges ~desired:1` is `Ok` with the 4 body
  edges, EVERY edge's `report.witnesses > 0` (**non-vacuity — assert per edge**);
  `esr_derivation ~desired:1` is `Ok`; `matches_esr_statement ~desired:1` is
  `Ok true`; `Rule.goal_of` the derivation `Temporal.equal`s `esr_statement_core`;
  `tail_matches_is_stable` `holds = true`, `witnesses > 0`.
- `t_p6_mutation` (**confirm-by-mutation**, [[feedback-confirm-tests-by-mutation]]):
  each mutation MUST be SEEN to turn a green assertion red, then be reverted /
  isolated (no leftover mutation in the tree,
  [[feedback-review-agents-may-leave-mutations]]):
  1. break one edge's `post` milestone (e.g. e2 `post = f_at Done`) ⇒ that edge's
     `drives`/`closure` fails ⇒ `edges` is `Error` ⇒ `esr_derivation` `Error`.
  2. swap two edges' order (break the `leads_to_trans` middle) ⇒ `Err.Ill_formed`.
  3. corrupt `esr_statement_core` (wrong target) ⇒ `matches_esr_statement`
     `Ok false`.
  4. neuter a discharge (`closure_holds` always `holds=true`) ⇒ a KNOWN-bad edge
     now builds — the mutation proves the discharge is load-bearing.
  Implement mutations as in-test alternate predicates/orderings (not source
  edits) where possible; if a source edit is unavoidable, isolate it in one agent
  and INDEPENDENTLY verify `git diff` is empty afterward.

## 6. Conventions firewall (hook-enforced; a violation fails the build)

- NO loop keywords (`for`/`while`/`loop`/`return`/`break`/`continue`) — combinators
  (`List.fold_left`/`for_all`/`exists`/`map`, `Option.fold`, `Result.bind`).
- NO wildcard `_ ->` on a finite sum: `Step.t` (12), `Vreplica_set_reconciler.step`
  (7), `Verdict.t`, `Comp_cat.Temporal.view`. Enumerate every arm.
- NO two-arm `match` on `option`/`result` — `Option.fold`/`Result.fold`/bind.
- NO exceptions (no `assert`/`failwith`/`raise`); partiality via `Res.t`.
- Doc comment on EVERY `.mli` item (already so) and every non-obvious `.ml` let.
- `Comp_cat.Res`/`Comp_cat.Err` for the Rule/obligation channel; anvil `Res`/`Err`
  for `unmarshal_state`. Keep them straight (two different `Res`).
- `Comp_cat.Res.t` is a TRANSPARENT alias `('a, Comp_cat.Err.t) result`, so
  construct/deconstruct with the ambient `Ok`/`Error` and `Result.bind`/`map`/
  `fold` and the `Comp_cat.Err.Ill_formed { fn; why }` constructor DIRECTLY — do
  not depend on `Comp_cat.Res.ok`/`.error` being exposed by the wrapped lib. The
  Rule combinators return `('a, Comp_cat.Err.t) result`; pattern-match via
  `Result.bind`, never a two-arm `match`.

## 7. Process

Hand-authored: this spec + `dune` + the three `.mli` (done). Build workflow
(sequential, bounded ≤7 findings / ≤56 agents per [[feedback_workflow_bounds_caps]]):
Foundation (`step_view.ml` + `dune` wire + confirm `Object_ref_map`/`Common`
ref-equality/`Bound` fields/`Comp_cat.Res` access) → Discharge → Vrs_liveness →
Tests → Greenup. Then an adversarial review workflow (lenses: derivation-shape
fidelity / discharge soundness / non-vacuity / convention firewall / honesty-of-
claims → refute-by-default verify) → fix pass. Build:
`eval $(opam env --switch=anvil-ocaml --set-switch); dunecho build`.
```

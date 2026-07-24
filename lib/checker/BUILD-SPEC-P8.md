# BUILD-SPEC-P8: the reconcile-bounded settling state (closes the P5/P6 vacuity)

Normative contract for anvil-ocaml **Phase 8**. Hand-authored crux (this file +
the `.mli` deltas below); the `.ml` bodies + tests are delegated to a build
workflow. Architecture: `comp-cat-ocaml/lib/temporal/ARCHITECTURE-anvil-ocaml.md`
§4 Leg 2; extends BUILD-SPEC-P5.md and BUILD-SPEC-P6.md.

Build/run (identical to P5-P7):
`eval $(opam env --switch=anvil-ocaml --set-switch); dunecho build` (expect 0/0).
`dune test` HANGS — run built exes directly:
`perl -e 'alarm 180; exec @ARGV' _build/default/test/t_p8_*.exe`.

Branch: `p8-settling-state` off `p7-exec-shim` HEAD (`ae4362d`). STAGE only, never
commit (user commits own msg).

---

## §0. The problem P8 fixes (both are HONEST-VACUOUS today)

**P5 (`check_esr`, cluster_check.ml:289).** The liveness gate
`effectively_quiescent bound s` (cluster_check.ml:139) = "every
`Scenario.productive_successors bound s` is `state_equal` to `s`". It is
**never true** on any reachable state, so `gate_states = Some 0` and a clean
`check_esr` is a VACUOUS universal (BUILD-SPEC-P5 §6, the code's own HONEST LIMIT
note). Root cause: `state_equal` (cluster_check.ml:48) compares EVERY field
including the two monotone correlation allocators
(`rpc_id_allocator`, per-controller `reconcile_id_allocator`), and the reconcile
**re-schedules perpetually** — `Schedule_controller_reconcile_step` is enabled
whenever the CR key is in etcd and NOT already scheduled/ongoing
(controller.ml:134-136), and `run_scheduled_reconcile` allocates a FRESH
`reconcile_id` on every scheduled→ongoing transition (controller.ml:151). So
every reachable state has a state-CHANGING productive successor (the next
reschedule bumps `reconcile_id`); `effectively_quiescent` holds nowhere.

**P6 (`vrs_liveness` tail, `tail_matches_is_stable`, vrs_liveness.ml:457).** At
`tightened_bound` (vrs_liveness.ml:107, `rv_ceiling = 2`) the reconcile never
reaches `Done`: reaching `Done` needs ~`desired+1` content-writes (create each of
`desired` pods + one status write), each bumping `resource_version_counter` past
`rv_ceiling = 2`, so those states are pruned by `over_ceiling`
(cluster_check.ml:93). Hence `Done = 0` and `current_state_matches = 0`
(the permanent measured-counts witness test records these zeros). The tail is a
shape-correct VACUOUS discharge.

**The tension both phases hit (P5 §6.1 / P6 bottom line).** A SINGLE `rv_ceiling`
cannot serve both goals: it must be **high** (`>= desired+1`) to reach `Done`, yet
**low** (`<= 2`) to exclude the *steady-state create-skip* that breaks P6's e2
`closure` edge. The create-skip is a **second-reconcile-pass** phenomenon (on the
first pass no pods exist, so the create branch fires and drives forward; only a
LATER pass, finding the pods already present, skips the create and violates e2's
"pre => succ in pre|post" closure). No `rv` bound separates the two.

---

## §1. The fix: bound the number of reconcile INVOCATIONS, not the rv

Add a NEW bound dimension — `reconcile_ceiling` — orthogonal to `rv_ceiling`.
Bounding reconcile invocations excludes the SECOND pass (hence the create-skip
that breaks e2) **without lowering `rv_ceiling`**, so `rv_ceiling` can be raised
enough to reach `Done` on the first pass. This dissolves the §0 tension: one pass
reaches a `Done` state that (a) matches (`desired` owned pods created + status
updated) and (b) is **genuinely settled** — its only productive successor is the
next reschedule, which the ceiling prunes, so it has NO state-changing productive
successor. That reachable, matching, settled `Done` is the counter-free settling
state P5/P6 flagged as the future hook.

**Honest framing (state in code + memory, do NOT overclaim).** This witnesses a
BOUNDED number of reconcile passes settling to the match and staying there; it
does NOT verify the perpetual re-reconcile (which the UNBOUNDED P7 executable
spine already witnesses operationally — that is P7's payoff, cited here). Under
arch §4 the `decisive` flag remains verification only of the bounded system under
these ceilings.

**Design stance: ADDITIVE.** P5's shipped `state_equal` / `effectively_quiescent`
/ `check_esr` and their tests stay byte-identical and GREEN (still honestly
vacuous at `Bound.default`). P8 adds a parallel non-vacuous path and a new bound
field with a backward-compatible default. Only P6's `tightened_bound` and its
tail witness test change (that IS the vacuity being resolved).

---

## §2. Soundness argument (the review's crux lens)

1. **Pruning is unconditionally sound.** `over_ceiling` only DROPS successors; it
   never merges distinct states (unlike a symmetry-reduction quotient, which would
   need a subtle equivariance argument — deliberately NOT taken here). A dropped
   successor is reported via `report.pruned = true`; every `decisive` claim is
   relative to the ceilings (arch §4, BUILD-SPEC-P5 §6). Adding a
   `reconcile_id_counter > reconcile_ceiling` disjunct to `over_ceiling` is the
   same discipline as the existing `uid`/`rv` clauses.

2. **The settled `Done` is genuinely reachable and quiescent.** From
   `seed ~fair:true` (disruptors OFF: `crash/req_drop/pod_monkey = false`,
   scenario.ml:120-143), the single fair reconcile pass creates `desired` pods and
   updates status, reaching `Done`; `end_reconcile` clears the ongoing entry
   (cluster.ml:627, controller.ml `end_reconcile`), draining the network (each
   step consumes its own response before advancing, so `Done ⟹ in_flight empty`).
   At that state the only enabled productive step is
   `Schedule_controller_reconcile` (Api_server needs `Some msg` — none in flight;
   Pod_monkey/crash/req_drop OFF; no orphan for the GC). CORRECTED (review
   2026-07-24; t_p8_settle test 4 pins the measured shape): that schedule step
   does NOT bump the counter — allocation happens at RUN time
   (`run_scheduled_reconcile`, controller.ml:151) — so its successor (the
   re-armed `scheduled_reconciles`) is a state CHANGE and the drained `Done`
   itself is NOT settled. The settled state is the RE-ARMED successor: its only
   productive move, running the next pass, WOULD bump `reconcile_id_counter`
   past `reconcile_ceiling` and is pruned. Hence ITS ceiling-pruned
   productive-successor set is EMPTY ⟹ `settled = true` (reachable one step
   after the drained `Done`).

3. **`settled` and the ESR target are quotient-free and content-only.** The gate
   and `current_state_matches` (`liveness_goal`, invariants.ml:892) read only etcd
   CONTENT (matching owned pods + VRS status), so they are well-defined on the
   exact (un-quotiented) graph; there is no equivariance obligation.

4. **The correlation ids are equality-only (documented for completeness, not
   relied on).** `resp_msg_matches_req_msg` (message.ml:287) correlates by
   `Rpc_id.equal` + host-id equality + structural paired-kind; `Rpc_id.compare`
   has NO call site in the transition relation; both allocators are
   fresh-allocate + `Int.equal`. So even the fallback quotient would be sound —
   but P8 does NOT take it (pruning suffices), keeping the soundness surface
   minimal.

---

## §3. Code deltas (exact)

### 3.1 `lib/cluster/bound.ml` / `bound.mli` — new field
Add `reconcile_ceiling : int` to `Bound.t` (place after `rv_ceiling`). `.mli` doc:
"The largest per-controller `reconcile_id` (number of reconcile INVOCATIONS) any
run may reach. Excludes multi-reconcile-interference / steady-state-re-reconcile
bugs that need more than this many invocations. Like `uid_ceiling`/`rv_ceiling` it
is a MULTI-STEP exploration limit, reserved for the checker; P2 does not enforce
it." `default`: set `reconcile_ceiling = 8` (loose — preserves existing
`Bound.default` exploration behavior; no existing test's reachable set is clipped
by 8 invocations at the current small depths). **Every `Bound.t` record literal in
the tree must gain the field** (grep `{ *max_in_flight` / `Bound.default with`);
where a test builds a `Bound.t` inline, add `reconcile_ceiling = 8` unless it is a
P8 settling bound (see §4).

### 3.2 `lib/checker/cluster_check.ml` / `.mli` — prune + settled gate + entry point
- **`max_reconcile_id (s : Cluster.cluster_state) : int`** (helper): fold
  `s.controller_and_externals` taking `Int.max` of each
  `cae.controller.reconcile_id_allocator.reconcile_id_counter` (via
  `Controller.Reconcile_id_allocator`'s counter — expose an accessor if the record
  field is abstract; a `val reconcile_count : t -> int` on the allocator is the
  clean addition, mirroring its existing `equal`). No wildcard, no loop keyword
  (use `Imap.fold`).
- **`over_ceiling`**: add disjunct `|| max_reconcile_id s > bound.reconcile_ceiling`.
  This flows into `bounded_successors` / `bounded_labelled_successors` and thus
  into P6's `Discharge.reach`, so ALL exploration clips the (ceiling+1)-th pass.
- **`settled : Bound.t -> Cluster.t -> Cluster.cluster_state -> bool`** (NEW,
  additive — do NOT touch `effectively_quiescent`): `List.for_all (fun (_step,s')
  -> state_equal s s')` over the CEILING-PRUNED productive successors, i.e.
  `List.filter (fun (_step,s') -> not (over_ceiling bound s'))
  (Scenario.productive_successors bound s)`. `.mli`: document it as the
  reconcile-bounded refinement of `effectively_quiescent` — identical intent ("no
  state-changing productive successor") but counting a ceiling-pruned reschedule as
  no successor, so under a `reconcile_ceiling` bound it IS reachable (the settled
  `Done`), unlike `effectively_quiescent` which stays vacuous.
- **`check_esr_settled : ?depth:int -> Bound.t -> desired:int -> report`** (NEW):
  a copy of `check_esr` with `quiescent = settled bound Scenario.cluster` and
  `gate_states = Some (count_states_where reach (settled bound Scenario.cluster))`.
  Under a §4 settling bound, `gate_states = Some n, n > 0` and every settled state
  matches ⟹ `No_counterexample {decisive=true}` NON-VACUOUSLY. Leave `check_esr` /
  `check_esr_temporal` / `effectively_quiescent` UNCHANGED; add an `.mli` note
  cross-referencing `check_esr_settled` as the non-vacuous companion.

### 3.3 `lib/proof/vrs_liveness.ml` (P6) — consume the reachable Done
- **`tightened_bound`**: set `reconcile_ceiling = 1`; raise `uid_ceiling` and
  `rv_ceiling` to `>= desired + 2` (the tests use `~desired:1`, so `uid_ceiling`/
  `rv_ceiling = 4` comfortably reaches the single-pass `Done`; keep
  `max_in_flight`/`max_objects_per_kind` as-is or +1 if the pass needs it). Verify
  the frontier still EMPTIES (finite: one pass + reschedule pruned) so `decisive`
  is achievable.
- **`tail_matches_is_stable`** (and any tail edge that read `Done = 0`): rebuild on
  `Discharge.reaches_holds` with `post = at_done` (and a second with `post = fun s
  -> at_done s && current_state_matches ~desired s`), which is `count_states_where
  r post > 0` ⟹ NON-VACUOUS once `Done` is reachable. The tail's `always matches`
  stability is now witnessed by: from the settled seed the reachable graph's
  `current_state_matches` count is `> 0` AND no reachable state (within the bound)
  falsifies it after `Done` (an `invariant_holds`-style check gated on `at_done`
  reachability). Keep it HONEST: report the achieved counts.
- **The measured-counts witness test** (currently asserts `Done = 0`,
  `matches = 0`): UPDATE its expected values to the new POSITIVE counts (the actual
  numbers come from a run; the test asserts the measured non-zero counts, making
  non-vacuity VISIBLE — the P6 §fix-2(a) discipline, now with positive witnesses).
- Confirm **e2's `closure` now HOLDS** at `reconcile_ceiling = 1` (the create-skip
  second pass is excluded). If a residual edge still fails, that is a real finding
  for the review, not something to paper over.

### 3.4 `lib/assurance/scenario.ml` — none required
`seed ~fair:true` already reaches the settled `Done` under a §4 bound. (Optional
convenience: none — do not add unused seeds.)

---

## §4. The P8 settling bound (used by the new tests + P6 tail)

```
settling_bound ~desired = {
  max_in_flight        = 8;
  max_objects_per_kind = desired + 2;   (* room for the created pods            *)
  max_controllers      = 1;
  uid_ceiling          = desired + 3;   (* one uid per created pod + slack      *)
  rv_ceiling           = desired + 3;   (* create x desired + status write      *)
  max_reconcile_depth  = 16;
  reconcile_ceiling    = 2;             (* pass 1 settles; pass 2 = content no-op,
                                           confirms it STAYS matched; pass 3 pruned *)
}
```
Rationale for `reconcile_ceiling = 2` in the NEW tests: pass 1 reaches the match
(reachability leg); pass 2 (find-pods, create-skip, status no-op ⟹ no rv bump,
handle_update_status no-op branch, api_server.ml:565) confirms STABILITY without
churning content; pass 3 pruned ⟹ the pass-2 `Done` is `settled`. P6's
`tightened_bound` uses `reconcile_ceiling = 1` (it only needs `Done` reachable +
e2 sound; keep it minimal). Both must EMPTY the frontier (assert `decisive`).

---

## §5. Tests — `test/t_p8_settle.ml` (Alcotest, name `p8_settle`)
Wire the bare name into `test/dune`'s single `(tests (names ...))` stanza after the
p7 group. Suite (`~desired:3` unless noted):
1. **settled Done reachable + matches**: explore from `seed ~desired ~fair:true`
   under `settling_bound`; assert `count_states_where reach (settled bound cluster)
   > 0` AND every settled state satisfies `current_state_matches` (equivalently the
   `check_esr_settled` outcome is `No_counterexample`).
2. **`check_esr_settled` NON-VACUOUS + decisive**: `report.gate_states = Some n`
   with `n > 0`; `outcome = No_counterexample {decisive = true}`;
   `report.pruned = true` (the 3rd pass was clipped) with
   `max_rv_seen <= rv_ceiling`.
3. **reconcile_ceiling is load-bearing**: with `reconcile_ceiling` raised to a
   large value (perpetual), `gate_states = Some 0` again (reproduces the P5
   vacuity) — proving the ceiling is what creates the settled state, not a fluke.
4. **exact settled-state shape** (`~desired:1` for a small graph): assert the
   settled state has `desired` owned pods, VRS status replicas = `desired`, empty
   `in_flight`, no ONGOING reconcile, the re-armed `scheduled` entry (§2.2
   corrected mechanism — the settled state is the re-armed one, not the drained
   un-armed `Done`), `reconcile_id_counter = 2`.
5. **P6 tail non-vacuous**: `Vrs_liveness.tail_matches_is_stable ~desired:1`
   returns `{ holds = true; witnesses > 0; frontier_emptied = true }`; the
   measured-counts test's `Done`/`matches` counts are `> 0`.
6. **safety unaffected**: `check_always` under `settling_bound` is still clean (the
   new pruning does not admit a false safety counterexample).

## §6. Confirm-by-mutation (`test/t_p8_mutation.ml`, name `p8_mutation`)
Each mutant SEEN red→green then reverted; only GREEN pins ship
([[feedback-confirm-tests-by-mutation]]). At least:
- **M1 (prune neutered)**: drop the `reconcile_id_counter` disjunct from
  `over_ceiling` ⟹ churn returns ⟹ `check_esr_settled` `gate_states = Some 0`
  (vacuous) — test #2 must then FAIL. (This is the automated in-tree analogue: an
  M-flag or a local shadowed `over_ceiling`.)
- **M2 (settled gate corrupted)**: `settled` returns `true` unconditionally ⟹
  test #4's exact-shape / #1's "every settled matches" catches a non-settled or
  non-matching state slipping the gate.
- **M3 (target broken)**: corrupt `current_state_matches` (e.g. require
  `desired+1` pods) ⟹ `check_esr_settled` REFUTES (the settled `Done` fails the
  target) — witnesses the gate is exercised, not vacuous.
- **M4 (planted divergence)**: an in-tree planted-divergence detector on the
  settled-state produced values (pods = desired, `reconcile_id_counter = 2`,
  rv/uid at expected finals), mirroring P7's M4.

## §7. Honest limits (bake into `.mli` docs + memory; anti-overclaim)
- Witnesses a BOUNDED reconcile count settling + staying matched; NOT the
  perpetual re-reconcile (P7's unbounded executable spine witnesses that
  operationally — cite it). `decisive` = verification of the bounded system under
  these ceilings only (arch §4), never Anvil's Verus theorem.
- `reconcile_ceiling` is a real bound with an excluded bug class (multi-pass
  interference); report achieved reconcile count vs the cap alongside uid/rv.
- P8 takes the SOUND pruning route, NOT symmetry reduction; it does not claim a
  counter quotient. The equality-only id analysis (§2.4) is documented as why a
  quotient WOULD be sound, not as a dependency.

## §8. Process (mirror P5-P7)
Hand-authored crux = this file + the `.mli` deltas (§3). DELEGATE via a bounded
build workflow (≤7 findings, ≤56 agents [[feedback_workflow_bounds_caps]]):
Foundation (bound field + allocator accessor + all record-literal sites) →
Checker (over_ceiling + settled + check_esr_settled) → P6 (tightened_bound + tail +
witness test) → Tests+Mutation → Greenup. Then a bounded adversarial review
workflow (soundness-of-pruning + settled-reachability + P6-tail-non-vacuity +
convention-firewall + test-vacuity lenses → refute-by-default 2-skeptic verify →
synth), check `agents_error = 0` before trusting any all-clear
([[feedback-workflow-zero-findings-may-be-vacuous]]), stage leftover-mutation sweep
([[feedback-review-agents-may-leave-mutations]]). STAGE only; user commits.

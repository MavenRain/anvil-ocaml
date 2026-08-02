# BUILD-SPEC-P22: the scale-down scenario (the G2-live graph)

Phase 22 of the port. Follows P21 (internal guarantee register, sealed at
`e0fa83e`). Branch: `p22-scale-down` off `e0fa83e`.

## 0. Provenance of this spec, stated honestly

Authored from an 8-agent scout wave (`wf_af693751-d77`, agents_done=8,
agents_error=0 - a FULL wave, unlike P21's 3-of-10) plus main-loop spot checks
of every load-bearing cite. The state-count figures in section 4 are
STRUCTURAL ESTIMATES - the scouts were read-only and never ran the checker.
Every claim below carries the command or file:line that produced it; a
reviewer re-runs rather than re-trusts.

The candidate pick was adversarial: candidate B (E3-E5 controller-local
register, internal_rely_guarantee.rs :606/:613/:640) is NOT blocked - the
typed round-trip codec exists (`V_stateful_set_pack.unmarshal_state`, total
`Res.t` decode) - but it was DEFERRED to P23 because E4's condemned conjunct
is vacuous on every shipped graph: without THIS phase's graph, B would ship a
second G2-style vacuity. A's graph gives E4's condemned clause its live
witness for free. B's remaining preconditions are recorded in section 7.

## 1. Why this phase (the vacuity is measured, and closing it is grep-checkable)

P21 shipped the VSTS internal guarantee register G1-G4 and MEASURED G2
(`get_then_delete`, upstream :581) VACUOUS on ALL FIVE committed graphs:
`fault_check.mli:1866` records "interesting = 0 everywhere - at desired = 1
with no scale-down", and `BUILD-SPEC-P21.md:364` records mutant MG6 (wrong
owner_ref on the Delete_condemned emit) as INERT-BY-VACUITY, naming "a
G2-exercising scenario (scale-down)" as P22 material. This phase is that
scenario. Its falsification duty is discharged by converting MG6 from INERT
to REFUTED (section 5, MS1).

Novelty, MEASURED (all commands from repo root, no trailing slash on dir
args - the P20 lesson):

- `rg -n 'vsts_seed_with_pods|check_scale_down' lib test` - ZERO hits; both
  names are new.
- `rg -ni 'scale' lib test` - the ONLY seeded scale-down in the tree is VRS
  (`seed_with_pods`, scenario.ml:596-616, After_delete_pod path), never VSTS.
  The full VSTS seed surface (scenario.mli:51-205) has NO surplus-pod
  parameter.
- `rg -n 'condemned' lib test` - all hits are reconciler mechanics or the
  P10 UNIT test that drives Delete_condemned by overriding `~state` directly
  (t_v_stateful_set_reconciler.ml:262-272), never a seeded graph.
- The novelty claim is "first G2-live (condemned-exercising) VSTS graph",
  NOT "first desired>=2 VSTS graph": p15_witness.ml:260 already ships a
  desired=2 crash-only VSTS graph (852 states) for R1 only. The wider claim
  is FALSE; do not let it back in during doc passes.

## 2. The scenario (`Scenario.vsts_seed_with_pods`) - design pinned

**The mechanism this exploits (verified both sides):** upstream deletion is
driven purely by surplus ordinals. `partition_pods` (anvil-ref
model/reconciler.rs:641-654; port v_stateful_set_reconciler.ml:399-416) puts
every owned, canonically-named pod with ordinal >= replicas into `condemned`
(descending); `handle_delete_condemned` (upstream :489-514; port :716-747,
emit at :732-739) fires `Get_then_delete_request` with the CR's controller
owner ref. `pod_filter` (port :421-432) admits a pod iff it carries the CR's
controller owner ref AND its name round-trips through `get_ordinal` as
canonical `vstatefulset-<parent>-<ord>` (`pod_name`, :190-191).

**The seed** (new fn beside `vsts_seed_faults`, which is NOT edited):

```
vsts_seed_with_pods ~desired ~ordinals ~crash ~req_drop ~pod_monkey ?(vct = false) ()
```

chains TWO real `Api_server.handle_create_request` calls from
`uid_counter = 1` (the vsts_seed_faults style, scenario.ml:355-368, NOT the
VRS forge-into-map style): (1) the `vsts ~desired` CR - server stamps uid 1;
(2) per ordinal in `~ordinals`, a hand-built Pod named
`pod_name("vsts1", ord)` in `"ns"`, `owner_references = [controller ref of
vsts1 with uid 1]` - server stamps uid 2.... The create path VALIDATES but
does not strip owner refs (`metadata_validity_check`, api_server.ml:90-97:
Invalid iff MORE THAN ONE ref; ours has exactly one).

**The shipped instantiation is `~desired:1 ~ordinals:[1]`** - pod-0 ABSENT,
one surplus pod at ordinal 1. Reconcile trace (why it converges AND stays
small): List -> Create pod-0 (fresh `make_pod` matches the template, so
Delete_outdated immediately yields None -> Done, :763-765) ->
Delete_condemned fires the G2-live Get_then_delete on `vstatefulset-vsts1-1`
-> pod leaves etcd -> later reconciles find condemned=[] -> Done (absorbing,
:798). Every round strictly drains the surplus; the MG5 blow-up mechanism
(off-namespace pods invisible to the namespace-scoped list, 8h22m,
BUILD-SPEC-P21.md:363) is excluded by construction because the surplus pod is
IN "ns" and pod_filter-visible.

**Seed-integrity obligations (assert, don't assume):** the seeded pod's
owner-ref uid MUST equal the LIVE CR uid (1); a mismatch makes GC's
`object_is_orphaned` (builtin_controllers.ml:64-81) true and silently
reproduces the exact G2 vacuity this phase removes (section 5, MS3 measures
that failure mode). t_p22_scaledown carries an explicit seed test: the pod is
present at its ref post-seed, carries exactly one owner ref with uid 1, and
its name round-trips through the reconciler's ordinal parse.

**No new family - and no union either.** The leg asserts the SHIPPED P21
register `Internal_guarantee.guarantee_family ~cr ~controller_id` (G1-G4)
**ALONE**, on the NEW graph. Verbatim from the shipped leg
(`fault_check.ml:1134-1135`):

```
let invs = Internal_guarantee.guarantee_family ~cr ~controller_id in
let inv = Invariants.conjunction invs in
```

That is the leg's ENTIRE invariant surface - no second family appears
anywhere in `check_scale_down_under_faults`. NO structural suite is
asserted: not `Invariants.cluster_structural`, not `Invariants.always`, not
`Vsts_invariants.always`. Section 3's `invs =` line is the whole of it, and
neither `t_p22_scaledown` nor `t_p22_mutation` evaluates
`Invariants.cluster_structural` on any P22 graph (`rg -n cluster_structural
test` hits ONLY `t_p22_regression.ml:265/:289`, where the name is a ROSTER
entry - a (name, source) row in the family census - and is never evaluated
on a state). An earlier draft of this paragraph said "plus the structural
suite"; that was FALSE and is finding F1 of section 9 - the repo's
recurring OVERCLAIM class (P14 F1, P16 F1, P17 finding 2). Do not let it
back in during doc passes. The honest consequence is section 7's disclosed
scope limit.

**Why the union was NOT taken (a rule, not an omission).** Unioning two
families is the P15 MASKING TRAP, forbidden in-tree at
`fault_check.ml:476-482` - re-read and verified verbatim at those exact
lines on 2026-07-30, no drift: "THE MASKING TRAP (BUILD-SPEC-P15 section
3): the family is asserted ALONE, never unioned with
{!Correspondence.family}, {!Invariants.always} or {!Vsts_invariants.always}
... a unioned leg would report N1 and never evaluate R3's exclusivity,
masking the phase's headline. A [violated] naming a P14 member here means
the lists were unioned somewhere: harness bug, not a finding." The argument
binds P22 mechanically, not just by analogy: the leg's `~violated` is
`violated_of invs` (`fault_check.ml:1141`), which resolves through
`Invariants.first_violated invs` (`fault_check.ml:249-258`) - FIRST match in
LIST ORDER. Union a structural suite in and a structural member can be the
one named, masking the guarantee member this phase exists to measure. G2 is
that member, and MS1 (section 8.1) is the row that would have been silently
lost.

The phase's assurance content is therefore the measurement: G2's premise
fires, G1-G4 stay green, and MG6 becomes refutable. P17 is the precedent
for a phase whose novelty is an unmasked measurement rather than a new
predicate surface.

## 3. The leg (`Fault_check.check_scale_down_under_faults`, EOF of fault_check.ml)

Clones the newest leg's shape (`check_internal_guarantee_under_faults`,
ml:1076-1099, mli:1788-1796):

```
?(depth = default_depth) ?(req_drop = false) ?(pod_monkey = false)
(bound : Bound.t) (budget : budget) ~(desired : int)
~(ordinals : int list) ~(require_fault : bool) : fault_report
```

seed = `Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true
~req_drop ~pod_monkey ()`; cr = `Scenario.vsts ~desired ()`; invs =
`Internal_guarantee.guarantee_family ~cr ~controller_id` and NOTHING ELSE
(section 2: no structural suite, no union of families); standard union
gate with `budget_fault_taken` under `~require_fault` (the P21 shape) -
"union" here means the OR over the register's own four members
(`List.exists ... invs`, ml:1142-1148), never a union of two families. The
G2-premise-fires assertion (`G2 interesting > 0`) lives in the TEST, per
member, not in the union gate (which G1 dominates - the P21 .mli discloses
that unfalsifiability; restate it here).

**What actually catches leg-side family drift (corrected 2026-07-30 - the
obvious answer is WRONG).** It is NOT the per-member `interesting` pins. A
sibling traced the data flow: `t_p22_scaledown`'s `family` is a TEST-LOCAL
binding and the successor relation takes no invariant argument, so those
per-member counts are computed ENTIRELY test-side and would NOT move if the
leg swapped families. The only leg-side coupling is the leg-COMPUTED gate:
`fault_check.ml:1142-1148` builds `~gate` over the LEG's own `invs`, and it
surfaces as `fault_report.gate_states`, pinned at 20/276/96/2080. Swap the
leg's family and those four numbers move. Residual, stated honestly: that
coupling is a COUNT, so a DIFFERENT family whose interesting-union happens
to coincide on all four graphs would evade the pin, and nothing in the repo
reads the leg's `invs` binding directly - it is local and unexported.
Exposing the leg's family for a direct pin is on the P23 list (section 7).

**Bound: own record, never an edit.** `P22_witness.p22_bound =
{ P13_witness.p13_bound with ... }` raising `max_objects_per_kind` and the
uid/rv ceilings for the one extra pod + one extra create. Raise until
`pruned_by_ceiling = 0` on SL0 or disclose the residual. Do NOT touch
`p13_bound`, `Bound.default`, `Scenario.vsts_seed_faults`, `vsts_cluster`,
`controller_id`, `Cluster.enabled_successors`, or `faulted_equal`/`hash` -
the pin-safety verdict (scout, confirmed by fault_check.ml:268-300 -
`Bound.t` is a per-call immutable record; graphs depend only on
(seed, bound, budget, depth), never the invariant list) is SAFE
CONDITIONAL on additive-only.

**Legs and order (the MG5 lesson: zero-budget FIRST, then faults):**

| leg | budget          | require_fault |
| SL0 | zero            | false         |
| SLc | crash-only      | true          |
| SLd | drop            | true          |
| SLm | monkey          | true          |

`report_decisive` is a documented PHANTOM (BUILD-SPEC-P20.md:782-783); use
the local exhaustive 2-arm outcome projection per t_p21_guarantee.ml:107-110.

## 4. Predictions, committed BEFORE the build

1. **SL0: G2 interesting > 0.** The phase-defining prediction. If 0, the
   phase STOPS and diagnoses the seed (MS3/MS4 name the two known ways to
   be silently wrong).
2. All four legs clean + decisive; G1-G4 GREEN everywhere; G4's forbidden
   arm reachable-but-unfired. A G4 red is a fidelity divergence and a real
   finding, not noise.
3. The five committed pins are BYTE-IDENTICAL: L0 76 / Lc 464 / Ld 744 /
   Lm 1976 / L0v 116 (the battery's existing exes re-assert them; a moved
   pin is a phase-STOP).
4. SLc/SLd may legitimately produce TransactionAbort/ObjectNotFound on the
   condemned delete (api-server GetThenDelete semantics; port tolerance at
   :748-761 accepts Ok-or-NotFound). These are NOT reds; if a red appears
   here the first suspect is the checker's classification, not the port.
5. SL0 state count: same order as L0 76 / L0v 116 (low hundreds).
   NON-BINDING estimate; SLm grows most (+4 monkey ops per extra stored pod
   per state, budget-capped at 1 op).
6. Peak in-flight and uid/rv maxima: one extra create beyond the L0 run's
   constants (max_uid 3 -> 4 expected). Measured, not asserted, in sect. 8.

## 5. Mutation matrix (the only thing that makes a green mean anything)

All source mutants are MANUAL Edit-apply / Edit-revert (never `git
checkout --`), residue-scanned after each row.

- **MS1 (HEADLINE, = P21's MG6 re-applied):** wrong `owner_ref` on the
  Delete_condemned emit (v_stateful_set_reconciler.ml:732-739, upstream
  :734). Predict: SL0 flips clean -> **Refuted naming exactly the G2
  member** (owner-ref conjunct, internal_guarantee.ml G2 block; upstream
  :585), G1/G3 green - the per-member attribution P21 predicted at
  BUILD-SPEC-P21.md:248 and could not measure. Control: the five committed
  pins byte-identical under the SAME mutant (the arm is dead code on every
  old graph - that is P21's measured MG6 verdict).
- **MS2 (TRAP ROW, negative control):** the SAME mutation on the OTHER
  emitter - the Delete_outdated arm (:777-784). Predict: ALL legs green
  including SL0 (arm dead on this seed: pod-0 is freshly created and
  template-matching, :763-765). This is the measured witness for "a green
  matrix on the wrong emitter is NOT G2 coverage".
- **MS3 (seed-sabotage control):** surplus pod owner-ref uid 99 in a
  THROWAWAY seed variant (in-test, no source edit). Predict: pod_filter
  drops the pod, condemned = [], and the t_p22 G2-premise-fires assertion
  REDDENS. Proves the gate catches mis-seeding. Record whether GC contests
  the orphan (graph shape datum), whatever is measured.
- **MS4 (partition boundary):** `>= replicas` -> `> replicas` in
  partition_pods (:399-416). Predict: ordinal-1 pod never condemned;
  premise-fires assertion red; graph still converges (Delete_outdated scans
  needed ordinals only, so the surplus pod persists benignly).
- **MS5 (premise wiring, = P21's MG7 port):** in-test family instantiation
  with `controller_id + 1`. Predict: every member's interesting = 0 on SL0.
- **MS6 (fault-interaction datum):** After_delete_condemned's
  NotFound-tolerance (:748-761) narrowed to Ok-only. Predict: SL0
  byte-identical (the one delete finds its pod, resp is Ok; tolerance arm
  unexercised fault-free); SLm is where the arm is load-bearing (monkey
  deletes the condemned pod first). Family stays green in both; record the
  SLm graph delta. Hedged on purpose - either measured outcome is the
  datum.

A mutant killed by a build error or timeout is NOT caught - reshape it
(house rule). MS1 must be SEEN to name G2; MS2 must be SEEN green.

## 6. Files

- `lib/assurance/scenario.ml` / `.mli` - `vsts_seed_with_pods` (additive;
  vsts_seed_faults untouched).
- `lib/checker/fault_check.ml` / `.mli` - `check_scale_down_under_faults`
  at EOF, full house .mli block (WHAT-A-RED-MEANS / Shape / leg matrix /
  honest-vacuity / MEASURED).
- `lib/checker/BUILD-SPEC-P22.md` - this file; section 8 lands with the
  measurements.
- `test/p22_witness.ml` - UNLISTED in dune (names) (witness convention,
  p21_witness.ml:8-10); p22_bound + all new pins, single-sourced.
- `test/t_p22_scaledown.ml` / `t_p22_mutation.ml` / `t_p22_regression.ml` -
  dune (names) 73 -> 76, appended before the closing paren.
- `test/t_p22_regression.ml` extends the roster to FOURTEEN (append
  p22_label with the "(P22, THIS phase)" marker, demote P21's label into
  the swept set, self-exclusion keyed on p22_label, re-type the five
  inherited graph literals, derive from P21_witness, Pair_guard both
  orders). `t_p21_regression.ml` is NOT edited (candidate A leaves its
  E-ledger reversal clause standing - that clause reds only if P23 ships
  E3-E5, deliberately).
- Suggested commit subject:
  `feat(assurance): P22 scale-down scenario (first G2-live VSTS graph; MG6 INERT -> refutable)`

## 7. Limits, disclosed

- **This is a scale-down RESIDUE, not a scale-down EDGE.** `Step.t`
  (step.ml:11-47) has no client/CR-mutation step and no host ever emits an
  Update_request for the CR, so a live 2->1 spec transition is
  unrepresentable without new cluster surface. The seed hand-builds the
  post-scale-down state (desired=1 + surplus pod) - exactly the state shape
  upstream's condemned logic quantifies over. Say "G2-live graph", never
  "scale-down transition".
- **SCOPE LIMIT: no structural invariant is evaluated on ANY P22 graph.**
  The leg asserts G1-G4 alone (section 2), so `Invariants.cluster_structural
  ~controller_id` - inv1-6, the shared cluster-level etcd/runtime-safety
  suite (unique uids; weakly-well-formed + uid/rv monotone; <= 1 controller
  owner; scheduled/triggering CR uid < counter; unique reconcile ids;
  `invariants.mli:51-59`) - is NEVER evaluated on SL0/SLc/SLd/SLm. Concrete
  consequence, stated so no one has to rediscover it: this phase PLANTS a
  surplus pod straight into etcd via the seed, and a structural anomaly
  introduced by that plant (a uid collision, an rv that is not monotone, a
  second controller owner ref, a uid at or past the counter) would pass P22
  SILENTLY - every leg would still be CLEAN and DECISIVE with red 0. What
  the phase does check about the plant is narrower and deliberate: the
  seed-integrity test (section 2) asserts presence-at-ref, exactly-one owner
  ref with uid 1, and canonical-name round-trip. That is a targeted
  hand-check of THIS seed, not inv1-6. The union that would close the gap is
  the one the P15 masking trap forbids (section 2); the right shape is a
  SEPARATE structural leg over the same seed, not a unioned family. P23
  author: this is the first thing to weigh before reusing this graph.
- **Deferred, P23 bank (mechanism gaps in what the leg can be pinned on):**
  expose the leg's family for a DIRECT pin. Today the only leg-side catcher
  of a family swap is the gate COUNT (section 3), because `invs` is a local
  unexported binding and every per-member `interesting` figure in the tests
  is computed test-side. A different family with an identical
  interesting-union on all four graphs would evade the 20/276/96/2080 pins.
- vct:false only. The vct:true scale-down (PVC retention under condemned
  deletes) is deferred; it grows the graph with the PVC walk.
- The desired=0 variant (upstream-legal, replicas >= 0) is untested in the
  port's builders and NOT shipped; noted as a possible measured secondary.
- E3-E5 (P23 bank) preconditions, recorded so they are not rediscovered:
  (a) needs THIS graph for E4's condemned clause; (b) needs a named
  headline mutant; (c) consciously re-opens t_p21_regression.ml:557-573;
  (d) `unmarshal_state` silently defaults needed/condemned/pvcs/indices -
  decode-defaults must be counted separately or the register ships a
  vacuous pass; (e) E5's AfterListPod branch reads pending_req_msg beyond
  the local-state decode.
- Scout state-count estimates are unmeasured until section 8 lands.

## 8. MEASURED (2026-07-30, stage B3, throwaway probes `probe/zz_p22_probe.ml`
+ `probe/zz_p22_ceiling.ml`, deleted after landing; replica technique =
t_p21_guarantee.ml:193-237 verbatim, replica `states_seen` matched the leg's
own `states` on EVERY leg)

**THE PHASE GATE PASSED: G2 interesting = 4 > 0 on SL0** - prediction 1
CONFIRMED, the first G2-live VSTS graph. Every leg CLEAN and DECISIVE; **red 0
on every member over every graph** (prediction 2 CONFIRMED). Wall time: full
four-leg pass + replicas ~67 s (SLm dominates).

Bound (probe literal; the shipped `P22_witness.p22_bound` derives it from
`P13_witness.p13_bound ~desireds:[1]` instead of re-typing): the P13 shape
`{max_in_flight = 8; max_objects_per_kind = 4; max_controllers = 1;
uid_ceiling = 6; rv_ceiling = 6; reconcile_ceiling = 2;
max_reconcile_depth = 24; monkey_forge = []}` widened ADDITIVELY:
`max_objects_per_kind` 4 -> **5**, `uid_ceiling` 6 -> **7**, `rv_ceiling`
6 -> **7**. No further retune was needed (see the ceiling diagnosis below).
Budgets = the P21 literals via the witness chain: SL0 `{0;0;0}`
(`~require_fault:false`), SLc `budget_crash_only` = `{1;0;0}`, SLd `{0;1;0}`
(`~req_drop:true`), SLm `{0;0;1}` (`~pod_monkey:true`), all fault legs
`~require_fault:true`; depth 40; `~desired:1 ~ordinals:[1]`.

| leg | states | gate | G1 int/red | G2 int/red | G3 int/red | G4 int/red | max_uid/rv |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SL0 | 88 | 20 | 4/0 | 4/0 | 4/0 | 20/0 | 4/4 |
| SLc | 808 | 276 | 80/0 | 104/0 | 32/0 | 296/0 | 4/4 |
| SLd | 1144 | 96 | 32/0 | 40/0 | 16/0 | 136/0 | 4/4 |
| SLm | 10216 | 2080 | 240/0 | 432/0 | 704/0 | 2120/0 | 5/6 |

Secondary aggregates (recorded, not pinned): crash_witness_states SLc 720
(0 elsewhere); fault_free_states SL0 88 / SLc 88 / SLd 176 / SLm 176;
settled_with_faults_live 1 / 14 / 15 / 67.

**Ceiling discipline.** `max_uid_seen`/`max_rv_seen` stay STRICTLY below the
7/7 ceilings on every leg (worst case SLm 5/6) - the BUILD-SPEC-P8 §4
interpretation rule holds. `pruned_by_ceiling = true` on all four legs, and
the residual was DIAGNOSED, not waved through (section 3's "raise until 0 or
disclose"): SL0 re-run at `max_objects_per_kind 9` / `uid,rv_ceiling 15`
(variant A) and additionally `max_in_flight 16` / `max_reconcile_depth 48`
(variant B) is BYTE-IDENTICAL (88 states, gate 20, still pruning), so no
object/uid/rv/in-flight/depth ceiling binds; only `reconcile_ceiling` 2 -> 3
(variant C) moves the graph (88 -> 124, gate 28, STILL pruning at 3, still
clean/decisive). The residual is exactly the P13 `reconcile_ceiling = 2`
COVERAGE-COST clip (p13_witness.ml:13-29) that is asserted `true` on every
committed graph (t_p14_correspondence.ml:467/:525-527); P22 inherits it
unchanged rather than re-opening P13's measured 9m49s blow-up dimension.
`pruned_by_budget = true` on every leg incl. SL0 - the seed's crash flag is
ON and the budget clips the crash edges, the committed zero-budget rows'
exact shape (t_p13_faults.ml:474, t_p15_reconcile_correspondence.ml:371-373).

**Predictions, scored honestly:**

1. **CONFIRMED (the phase-defining one):** SL0 G2 interesting = 4 > 0. The
   fault legs were run only after this gate passed (probe order enforced it).
2. **CONFIRMED:** all four legs clean + decisive; G1-G4 red 0 everywhere; G4
   interesting > 0 with red 0 on every leg (reachable-but-unfired).
3. **CONFIRMED:** `t_p21_guarantee.exe` re-run on the post-B3 tree: 9 tests
   OK, the five committed pins 76/464/744/1976/116 byte-identical. Bonus
   datum: the probe also re-derived P21's L0 through the live
   `check_internal_guarantee_under_faults` (76 states) while measuring the
   prediction-6 baseline.
4. **CONFIRMED at the green level:** no red appeared on SLc/SLd (or
   anywhere), so the GetThenDelete tolerance classification was never put on
   trial; the disclosure stands for future legs.
5. **MEASURED, estimate CONFIRMED:** SL0 = 88 states - same order as L0 76 /
   L0v 116, and inside the 76..116 bracket. The non-binding "SLm grows most"
   lean also held, and by more than "low hundreds" language suggests:
   SLm = 10216 (5.2x P21's Lm 1976; the extra stored pod multiplies monkey
   interleavings). SLc 808 and SLd 1144 grew ~1.5-1.7x their P21 rows.
6. **SPLIT - recorded, not reworded.** `max_uid` 3 -> 4 CONFIRMED exactly
   (both sides measured: P21-L0 baseline 3, SL0 4 - the seed's one extra
   create). But the same "one extra create" arithmetic implies rv +1, and
   `max_rv` MEASURED 2 -> 4 (+2): the condemned GetThenDelete's DELETE is a
   second rv-advancing write the estimate did not count. REFUTED in the rv
   dimension; the ceilings still hold (4 < 7) because the +1 headroom was
   applied to an already-slack P13 ceiling, not because the estimate was
   right. SLm reaches 5/6 (the monkey's own create/delete ops).

### 8.1 Mutation matrix MEASURED (2026-07-30, stage B5)

Protocol per source row (MS1/MS2/MS4/MS6): pre-mutation bytes saved to
untracked scratch, mutant Edit-applied, `dune build` (every mutant built at
0 errors / 0 warnings - none was killed by a build error or timeout),
exes run under a 600 s alarm, then Edit-reverted and `cmp`-verified
BYTE-IDENTICAL to the saved bytes with t_p22_scaledown re-run green (6/6,
exit 0) before the next row. Leg-level `violated` names were read off a
throwaway probe (`probe/zz_b5_probe.ml`, B3 probe-literal form, deleted
after landing) because an Alcotest leg test aborts at its first failing
check ("outcome CLEAN") before the violated-name assertion runs. MS3/MS5
are the AUTOMATED rows; their measurements re-run on every battery pass.

| row | prediction (section 5) | measured | verdict |
| --- | --- | --- | --- |
| MS1 | SL0 flips clean -> Refuted naming exactly the G2 member; G1/G3 green; five committed pins byte-identical under the same mutant | SL0 REFUTED, `violated=vsts_internal_guarantee_get_then_delete_req` (verbatim probe output); mutant SL0 replica 92 states: G2 int=8 red=8, G1 int=4 red=0, G3 int=4 red=0, G4 int=24 red=8 (containment; family order names G2); t_p22_scaledown all four legs FAIL at "outcome CLEAN"; controls green: t_p21_guarantee 9 OK with pins 76/464/744/1976/116 byte-identical, t_p21_mutation 6 OK | **CONFIRMED** - MG6 INERT -> REFUTED; the phase's falsification duty discharged |
| MS2 | ALL legs green including SL0 (arm dead on this seed) | SEEN GREEN: same wrong-name mutation on the Delete_outdated arm, t_p22_scaledown 6/6 OK exit 0; SL0 byte-identical (88 states, gate 20, int 4/4/4/20, red 0) | **CONFIRMED** - the measured witness that a green matrix on the wrong emitter is NOT G2 coverage |
| MS3 | pod_filter drops the pod, condemned = [], premise-fires assertion reds; record the GC-orphan contest | AUTOMATED (t_p22_scaledown, every battery pass): sabotaged uid-99 seed's G2 interesting = 0 at the same-depth discriminating pair while the good seed fires; GC-orphan contest datum (B4): the sabotaged zero-budget graph DIVERGES (~4x states per 2 depth levels: 197/861/3787/16330 at depths 6/8/10/12 - the MG5 blow-up class), hence the ms3_depth = 10 pair documented in the exe header | **CONFIRMED** |
| MS4 | ordinal-1 pod never condemned; premise-fires assertion red; graph still converges | SL0 CLEAN and decisive at 76 states (P21's L0 count - ALL delete traffic gone), G2 int=0 red=0; the exe reds at THE PHASE GATE assertion on every leg plus MS3's good-seed floor (5 failures, exit 1); seed_integrity green | **CONFIRMED** - the surplus pod persists benignly |
| MS5 | every member interesting = 0 at controller_id + 1 on SL0 | AUTOMATED (t_p22_mutation, every battery pass): SL0 replica pinned at 88 first, all four members interesting = 0 AND red = 0 at the wrong id, with the G2-live contrast (int 4) at the true id | **CONFIRMED** - vacuous truth, not vacuous falsity |
| MS6 | SL0 byte-identical; SLm is where the arm is load-bearing; family green in both; record the SLm delta (hedged: either outcome is the datum) | SL0 byte-identical (88/20, int 4/4/4/20; leg green); SLm 10216 -> 10160 (-56), gate 2080 and member interesting 240/432/704/2120 UNCHANGED, red 0, clean + decisive; ADDITIONALLY SLc 808 -> 804 (-4) and SLd 1144 -> 1128 (-16) - the NotFound tolerance is load-bearing on ALL THREE fault legs, not SLm alone (prediction 4's disclosed ObjectNotFound surface, now measured) | **PARTIAL** - SL0-identical, family-green and the SLm delta CONFIRMED; the SLm-only localization REFUTED by the SLc/SLd deltas |

**MS1 reshape note (mutant-shape lesson, disclosed honestly).** The first
MS1 shape applied - owner-ref uid forged to 99 - is INVISIBLE to G2: the
owner-ref conjunct is `Owner_reference.eq_without_uid` (upstream
`owner_reference_eq_without_uid`, owner_reference.rs:37-42 - uid-exempt BY
DESIGN, disclosed at internal_guarantee.ml:154-158). Measured under that
shape: SL0 stayed CLEAN at 92 states with G2 int=8 red=0 - the
uid-SENSITIVE api-server GetThenDelete refuses the delete, the pod
persists, and the premise fires MORE while the guarantee still holds. Per
the reshape house rule the row was re-cut to break a uid-EXEMPT conjunct
(the owner-ref NAME), which produced the predicted refutation. Corollary
datum: a uid-only owner-ref forgery is a mutation class G2 cannot see,
exactly as upstream specifies.

## 9. REVIEW (2026-07-30, post-landing) - provenance and every finding

**Provenance of the review, stated as honestly as section 0 states the
spec's.** Two independent passes over the landed P22 diff:

1. A `ctxcat-review` wave: **3 agents, agents_error = 0** (a FULL wave - the
   zero-findings-may-be-vacuous check was run FIRST, so the low yield is a
   real measurement, not dead agents). Funnel: **1 raw -> 1 upheld -> 1
   survivor.**
2. One **opus adversarial correctness pass**, added because the mechanical
   finders skew to conventions and miss logic bugs. It produced **3
   findings**.

Union = **THREE distinct findings, ALL severity LOW.** The mechanical
wave's single survivor DUPLICATED F3, so the wave contributed no finding
the adversarial pass had not already found - itself the datum that the
finder lens was the weaker instrument on this diff.

### F1 (LOW) - BUILD-SPEC-P22.md section 2 OVERCLAIMED the leg's invariants

**Claim as shipped:** section 2 said the leg asserts the P21 register
"plus the structural suite". **Reality:** the leg asserts G1-G4 ALONE -
`fault_check.ml:1134-1135` is `let invs = Internal_guarantee.guarantee_family
~cr ~controller_id in let inv = Invariants.conjunction invs`, with no other
family anywhere in `check_scale_down_under_faults`. Section 3 of this very
spec already listed only `guarantee_family`, so the document contradicted
itself. Neither `t_p22_scaledown` nor `t_p22_mutation` evaluates
`Invariants.cluster_structural` on any P22 graph. This is the repo's
recurring OVERCLAIM class: P14 F1, P16 F1, P17 finding 2 - four phases in a
row, which is a process signal, not four coincidences.

**Resolution (this pass, doc-only - no code change was warranted):**
- Section 2 rewritten to state what shipped: G1-G4 ALONE, with the leg's
  two lines quoted verbatim and the "no structural suite" statement made
  explicit against all three candidate suites.
- The WHOLE spec was swept for the same claim rather than the one line
  patched: `rg -n 'suite|Invariants\.always|union|unioned|family'` over the
  file. Exactly ONE site carried the false claim (section 2, then line 99).
  One ADJACENT site was ambiguous rather than false - section 3's "standard
  union gate" - and was disambiguated in place ("union" = the OR over the
  register's own four members, never a union of families). Sections 4, 5, 8
  and 8.1 were checked and state only `guarantee_family` / G1-G4.
- The `.mli` doc blocks were swept for a leak: `rg -n structural` over
  `lib/checker/fault_check.mli` and `lib/assurance/scenario.mli`. The claim
  did NOT leak. `fault_check.mli:1894-1895` independently says "family
  ({!Internal_guarantee.guarantee_family}, G1-G4 - deliberately NO new
  family)", and `scenario.mli` has no `structural` occurrence at all. The
  `structural` hits in `fault_check.mli` (:288, :961, :994) belong to the
  P13/P16/P21 blocks and are correct there.
- **Why the union was not taken** is now RECORDED rather than left as an
  apparent oversight (section 2): the P15 masking trap at
  `fault_check.ml:476-482`, whose text was re-read and verified verbatim at
  those exact lines (no drift), plus the mechanical reason it binds P22 -
  `~violated` is `violated_of invs` (ml:1141) resolving through
  `Invariants.first_violated` (ml:249-258), FIRST match in LIST ORDER, so a
  unioned structural member could be named and mask G2.
- **The honest cost is now disclosed** in section 7 as a SCOPE LIMIT: inv1-6
  are never evaluated on SL0/SLc/SLd/SLm, so a structural anomaly introduced
  by planting a surplus pod into etcd passes P22 silently, with the correct
  remedy named (a separate structural leg over the same seed, NOT a union).

### F2 (LOW) - t_p22_regression.ml carried a TAUTOLOGICAL identity assertion

**Claim as shipped:** the "no new family" row asserted `pairs_of p21_family =
pairs_of family` - both sides derived from the SAME shipped expression, so
the test could not fail and the header's "this file asserts that identity"
was an overclaim.

**Resolution: ALREADY FIXED by a sibling agent** (that file is not this
author's to edit; recorded here for the phase record). The sibling replaced
the tautological row with TWO committed-literal rows (`family =
committed_guarantee_pairs` and `p21_family = committed_guarantee_pairs`,
G1-G4 with sources `internal_rely_guarantee.rs:562/581/589/544`),
de-tautologised the three coverage rows (`missing_from_roster` now takes
committed `(string * string)` literals instead of the same shipped
expressions `roster_pairs` is built from), and rewrote the header to drop
the "this file asserts that identity" overclaim.

**CORRECTION carried by F2, and it corrects a natural wrong answer.**
Leg-side family drift is **NOT** caught by the per-member `interesting`
pins. The sibling traced the data flow: `t_p22_scaledown`'s `family` is a
TEST-LOCAL binding and the successor relation takes no invariant argument,
so those counts are computed ENTIRELY test-side and would NOT move if the
leg swapped families. The actual catcher is the leg-COMPUTED gate:
`fault_check.ml:1142-1148` builds `~gate` over the LEG's own `invs`,
surfaced as `fault_report.gate_states` and pinned at 20/276/96/2080.
Residual, stated rather than waved: that coupling is a COUNT, so a
different family with an identical interesting-union on all four graphs
would evade it, and nothing in the repo reads the leg's `invs` binding
directly because it is local and unexported. "Expose the leg's family for a
direct pin" is now on the deferred/P23 list (section 7). The same
correction is folded into section 3 so a reader of the leg spec meets it
before the test record.

### F3 (LOW) - Scenario.vsts_seed_with_pods degraded SILENTLY on failure

**Claim as shipped:** every failure path inside the seed builder degraded
silently, so a MIS-PARAMETERISED call would produce a leg that is G2-VACUOUS
but CLEAN - i.e. the exact failure mode section 5's MS3 exists to catch,
arriving through a route MS3 does not cover (MS3 sabotages the owner-ref
uid, not the builder's own error paths). This is the finding the mechanical
survivor duplicated.

**Resolution: fix LANDED in `lib/assurance/scenario.ml`, verification CUT
SHORT** - the agent that landed it was killed mid-run, before its
verification completed, and `scenario.ml` is under concurrent edit by a
sibling this pass. So the fix is recorded as LANDED-BUT-NOT-RE-VERIFIED by
this author. **Open action for whoever closes P22:** confirm the shipped
`vsts_seed_with_pods` failure paths are loud (or gate-visible) and re-run
`t_p22_scaledown` green (6/6, exit 0) with the four state pins
88/808/1144/10216 and gates 20/276/96/2080 byte-identical, before this
section is treated as closed.

**Severity note.** All three are LOW because none moves a pin or changes a
measured verdict: F1 and F2 are truth-in-documentation/assertion-strength,
F3 is a robustness gap on a call site the phase currently gets right. The
five committed graph pins (76/464/744/1976/116) and the four P22 pins are
untouched by every resolution above.

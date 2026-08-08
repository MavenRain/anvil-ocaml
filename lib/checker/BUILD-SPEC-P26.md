# BUILD-SPEC-P26: fifteen FORGED-STATE rows, the superseding measurement pins (full-evaluation, inertness, guarantee quads, resp occupancy), riders R1/R2, and the ml:623/:639 probe

## 0. Phase identity, bounds, and baseline

Repo: `~/Documents/anvil-ocaml` @ `560d89e` (P25 committed). Tree CLEAN and **85 exes**
[MEASURED this session: `git status --short` empty; `rg -o 't_\w+' test/dune | sort -u |
wc -l` = 85]. Upstream reference: `~/Documents/anvil-ref` (read-only).

Selection: RULING-P26-SELECTION.md, 2026-08-07, scouts U1-U4 + probe X23 + mutation
trials X1 (`~/Documents/anvil-ocaml-p26-harness/`). Backing evidence:
`probe-p26-run-unmutated.log`, `probe-p26-run-mutated.log`,
`probe-p26-run-mutated-485.log`, `t_p26_probe.SOURCE.ml`, `PRE-EDIT-test-dune.bytes`,
`PRE-MUTATION-v_stateful_set_reconciler.ml.bytes`,
`PRE-MUTATION2-v_stateful_set_reconciler.ml.bytes`. Phase bounds: <=7 findings,
<=56 agents.

**P26 ships four things, NO new top-level lib module, NO committed pin moved**
(RULING:9):

1. The **FORGED-STATE red-capability block**: fifteen new rows on the codebase's own
   recorded seed-free route (state_predicates.mli:364-374), landed by EXTENDING
   `test/t_p24_mutation.ml` (C6, section 1.6). Fourteen unexercised M1 sites plus M3
   :128. Section 2.
2. The **8 vct:true conjuncts STAY EXCLUDED**; P26 ships the superseding measurement
   pins in a new registered pin exe `test/t_p26_pins.ml` (85 -> 86 exes): the
   full-evaluation pin, the inertness pin (ml:485/:489), the guarantee quad pins, the
   resp occupancy pins with the isolated List_response column (C2). Section 3.
3. **Guarantee-side :133-180 register and :522**: measurement PINNED, register and
   :522 stay deferred. G2 :581 is recorded vacuous-pending-scale-down (C3). Ledger
   stays 9 = 7 shipped [544;562;581;589;606;613;640] + 2 excluded [522;528]
   (p21_witness.ml:242-245 [MEASURED this session]).
4. **Riders**: R1, the l2 reshape onto `Local_binding.holds_at_key` (C5). R2, the
   prose correction of the stale BUILD-SPEC-P24.md:1233-1245 framing, in this spec
   only (section 1.7), never in place (P22 precedent).

The ml:623/:639 Get_pvc-family mutant runs in stage C as a PROBE only (C4). The
commit-green decision for the 8 conjuncts stays a P27 decision even if the probe reds
(RULING:43-45).

### 0.1 Measured grounds

Every number in this spec traces to one of these sources. Copy numbers. Never
recompute them.

| number | value | source line |
| --- | --- | --- |
| L0v states_seen | 116 | probe-p26-run-unmutated.log:5 |
| L0v decoded / pvc_cnt (info, no pin) | 104 / 1 | probe-p26-run-unmutated.log:6 |
| L0v blanket (at_valid_step) occupancy | 80 | probe-p26-run-unmutated.log:7 |
| :197 premise / violating | 80 / 0 | probe-p26-run-unmutated.log:8 |
| :198 premise / violating | 80 / 0 | probe-p26-run-unmutated.log:9 |
| :199 premise / violating | 8 / 0 | probe-p26-run-unmutated.log:10 |
| :215-221 premise / violating | 80 / 0 | probe-p26-run-unmutated.log:11 |
| :223-228 premise / violating | 40 / 0 | probe-p26-run-unmutated.log:12 |
| :233 premise / violating | 8 / 0 | probe-p26-run-unmutated.log:13 |
| :244 premise / violating | 32 / 0 | probe-p26-run-unmutated.log:14 |
| :246 (P25 premise idx>0) premise / violating | 8 / 0 | probe-p26-run-unmutated.log:15 |
| :246u bare step gate (info, WARN-only) | 8 / 0 | probe-p26-run-unmutated.log:16 |
| FAIR [1;1] states_seen | 8580 | probe-p26-run-unmutated.log:19 |
| FAIR inv6 gate | 6952 | probe-p26-run-unmutated.log:20 |
| CRASH G2 [1;1] states_seen | 10552 | probe-p26-run-unmutated.log:21 |
| CRASH inv6 post-crash gate | 2784 | probe-p26-run-unmutated.log:22 |
| FAIR G1 create premise (per CR) | 668 | probe-p26-run-unmutated.log:23,27 |
| FAIR G2 get_then_delete premise (per CR) | 0 | probe-p26-run-unmutated.log:24,28 |
| FAIR G3 get_then_update premise (per CR) | 440 | probe-p26-run-unmutated.log:25,29 |
| FAIR G4 no_interfering premise (per CR) | 2088 | probe-p26-run-unmutated.log:26,30 |
| CRASH G1 premise (per CR) | 1224 | probe-p26-run-unmutated.log:31,35 |
| CRASH G2 premise (per CR) | 0 | probe-p26-run-unmutated.log:32,36 |
| CRASH G3 premise (per CR) | 32 | probe-p26-run-unmutated.log:33,37 |
| CRASH G4 premise (per CR) | 2328 | probe-p26-run-unmutated.log:34,38 |
| guarantee violating, every member, every CR, both graphs | 0 | probe-p26-run-unmutated.log:23-38 |
| FAIR Create_response states / distinct_msgs | 2064 / 2128 | probe-p26-run-unmutated.log:41 |
| FAIR Other bucket states / distinct_msgs | 3464 / 3760 | probe-p26-run-unmutated.log:45 |
| FAIR ANY_response states / msgs, SUM-MATCH | 5000 / 5888 | probe-p26-run-unmutated.log:46 |
| CRASH Create_response states / distinct_msgs | 3552 / 3936 | probe-p26-run-unmutated.log:47 |
| CRASH Other bucket states / distinct_msgs | 3152 / 3264 | probe-p26-run-unmutated.log:51 |
| CRASH ANY_response states / msgs, SUM-MATCH | 6080 / 7200 | probe-p26-run-unmutated.log:52 |
| L0v Create_response states | 8 | probe-p26-run-unmutated.log:53 |
| L0v Get_response states | 8 | probe-p26-run-unmutated.log:56 |
| L0v Other bucket states / distinct_msgs | 12 / 12 | probe-p26-run-unmutated.log:57 |
| L0v ANY_response states, SUM-MATCH | 28 | probe-p26-run-unmutated.log:58 |
| Update_response / Delete_response states, all three graphs | 0 | probe-p26-run-unmutated.log:42,43,48,49,54,55 |
| Get_response states, FAIR / CRASH | 0 | probe-p26-run-unmutated.log:44,50 |
| l0v_get_pvc_family_occupancy (committed pin) | 40 | p25_witness.ml:243 (was :238 at 560d89e; the LEG3 guard-row update shifts the line +5, value byte-identical) |
| l0v_246_premise_nonvacuity (committed pin) | 8 | p25_witness.ml:244 (was :239 at 560d89e; same shift, value byte-identical) |
| ledger 9 = 7 shipped + 2 excluded | [544;562;581;589;606;613;640] / [522;528] | p21_witness.ml:242-245 |
| L0v step occupancy Create_pvc / After_create_pvc / Skip_pvc | 4 / 8 / 4 | RULING:42-43 (carried; not in the unmutated log) |
| forged-row unit cost | ~16-17 LOC/row | RULING:16-17, measured off t_p24_mutation.ml:719-735, :736-751 |

Values carried from the RULING or the probe log are EXPECTED REPRODUCTION TARGETS.
Stage B must reproduce each pinned value with its own run before any committed prose
calls it measured (the P25 section 0.3 discipline, carried forward unchanged).

### 0.2 The novelty gate (runs BEFORE stage A, again at seal)

No new lib-side evaluator of the 8 excluded conjuncts may appear. The probe closures
stay in test/harness (RULING:161-163).

Concrete form: record the baseline hit set at 560d89e, then diff.

```
rg -n 'state_predicates\.rs:(197|198|199|215|223|233|244|246)|:197 |:198 |:199 |:215-221|:223-228|:233 |:244 |:246 ' lib -g '!*.md'
```

Capture the baseline ONCE, before stage A: run the command verbatim and write its
full output to `~/Documents/anvil-ocaml-p26-harness/novelty-gate-baseline-560d89e.txt`.
That captured file IS the baseline. The stage-A re-run, the stage-B re-run, the
stage-C re-run, and the seal re-run must each diff EMPTY against that file, plus at
most the sanctioned state_predicates.mli append of section 6.1 (prose only, no
`let`). Any new hit that binds code is a phase-STOP.

Do NOT gate on a hand-written line list. An earlier draft of this section described
the baseline as two locations (the state_predicates.ml:247-248 comment and the
state_predicates.mli:97-115 exclusion block); a verbatim re-run of the command at
560d89e refuted that description [MEASURED this session]. The true baseline hit set
is 19 lines across THREE files: state_predicates.ml:247,248,339,583 (4 hits),
state_predicates.mli:77,78,87,90,102,138,152,157,169,171,203,461 (12 hits), and
lib/checker/fault_check.mli:2272,2461,2463 (3 hits). All 19 sit inside comment or
doc-comment prose; none binds code [MEASURED this session, each hit line read]. Use
these counts only as a cross-check on the captured file. The captured file, not this
prose, is what every gate diffs against.

### 0.3 Measurement discipline

- Builds: `opam exec --switch=anvil-ocaml -- dune build --root ~/Documents/anvil-ocaml @runtest`
  (dune is NOT on PATH). Redirect output to a file. Never pipe through `tail`.
- Cached `@runtest` is vacuous. Every ship gate runs `--force`, or `dune exec` on the
  single exe (RULING:160-161).
- `dune build` exit 0 alone proves nothing. Verify the built artifact exists (`ls` the
  `_build` path) before reading a green.
- Read the Alcotest `N failures!` summary line, not the `> ` cursor line. Do not pass
  `-q`.
- Gates read the worktree. Before calling a staged tree green, require
  `git diff --name-only` empty (index equals worktree).

## 1. Contested items C1-C6, resolved

Each subsection records the decision and its ground. Judge leanings are from
RULING:118-138. No leaning is overturned.

### 1.1 C1: the four occupancy literals are PROMOTED to Alcotest pins

Decision: PROMOTE (:199=8, :233=8, :244=32, blanket=80) to Alcotest-pinned literals
in `t_p26_pins.ml`. Ground: each literal is now reproduced twice, once by P25's
measurement (BUILD-SPEC-P25.md:392-393 spec-recorded prose) and once by probe X23
(probe-p26-run-unmutated.log:7,10,13,14). P25's recorded WARN-only rationale was
single-run provenance plus the only-two-literals-flip-a-decision rule
(p25_witness.ml:241-244; was :236-239 at 560d89e). The full-evaluation pin (section
3.1) already asserts all eight premises as literals, so keeping these four WARN-only
would leave the pin exe asserting a strict subset of what it prints. The two
committed P25 pin VALUES (40 and 8) are untouched and byte-identical; the LEG3
guard-row update (blast table, test/p25_witness.ml row) shifts their lines from
:238-239 at 560d89e to :243-244.

### 1.2 C2: the List_response column is ADDED in P26

Decision: ADD the isolated List_response column to the pin exe. Ground: one match-arm
split in `resp_kind_label` (t_p26_probe.SOURCE.ml:329-339 folds `List_response _` to
"Other"), same graphs, zero new exploration. List_response is the actual :750 premise
kind and today it hides inside "Other" (12/12 on L0v, nonzero everywhere,
probe-p26-run-unmutated.log:45,51,57; RULING:124-127). The List column literals are
FRESH-MEASURED at stage B and pinned then, deliberately not pre-stated (the P25 LEG3
precedent, BUILD-SPEC-P25.md:660). Pre-stated constraint: per graph, List
distinct_msgs plus residual-Other distinct_msgs must equal the old Other bucket
(3760 FAIR, 3264 CRASH, 12 L0v), and the SUM-MATCH control must stay green.

### 1.3 C3: G2 :581 multi-CR vacuity is RECORDED-AND-DEFERRED

Decision: record as vacuous-pending-scale-down. Ground: premise=0 on BOTH multi-CR
graphs (probe-p26-run-unmutated.log:24,28,32,36); desired=1 per CR, and no scale-down
ever emits Get_then_delete_request (RULING:53-55). A scale-down/desireds seed moves
the committed multi-CR graphs, so it belongs to the 1a phase-owner cost class
(section 7). The pin exe pins the premise=0 literal itself, so a graph that later
un-vacuizes G2 reds a pin instead of drifting silently.

### 1.4 C4: the ml:623/:639 mutant runs inside P26 stage C, as a PROBE

Decision: run it (stage C, section 4.2). Ground: the trial infrastructure exists and
is proven twice this cycle (PRE-MUTATION byte files + cp/cmp restores, RULING:2-4);
reachability is already measured (L0v occupancy Create_pvc 4, After_create_pvc 8,
Skip_pvc 4, RULING:42-43); one site per trial. A red does NOT change P26 scope. The
commit-green decision stays P27 (no mid-phase scope expansion).

### 1.5 C5: rider R1 (l2 reshape) SHIPS

Decision: ship. Ground: the blast radius is enumerable and small.
`internal_guarantee.ml:467` already delegates to `Local_binding.holds_at_key`
[MEASURED this session], while `local_binding.ml:338-348`'s l2 record still writes
its own decoded closure (ml:342-348). The reshape replaces exactly that closure with
a `holds_at_key ~controller_id ~cr_key` call, leaving ONE copy of L2's decoded body.
Byte-stable surfaces: l2's `name` (ml:340), l2's `source` string
`...internal_rely_guarantee.rs:640` (ml:341), l1's `source` `...rs:613` (ml:328),
l2's `interesting` (ml:349-353), `binding_sources`, and `binding_cardinal` 2. Battery
LEG2 re-runs after the reshape (stage C). A LEG2 red after R1 is a REAL FINDING,
never weakened.

### 1.6 C6: the fifteen rows EXTEND t_p24_mutation.ml (no new mutation exe)

Decision: extend `test/t_p24_mutation.ml`. Grounds:

- The recorded route names this file: "One [t_p24_mutation] row per unexercised
  conjunct on the existing [M1a]/[M1b] pattern" (state_predicates.mli:364-366).
- The forge infrastructure is file-local: `install` (t_p24_mutation.ml:472-493),
  `reconcile_state` (:495-505), `forge` (:507-516), `injection_landed` (:552-557,
  was :518-523 at 560d89e), `listed_pod`/`good_pod0`/`good_pod1` (:579-584, was
  :545-550), `holds`/`fires` (:676-682, was :632-637), `m1_state` (:740-742, was
  :696-698), `parked_with` (:668, was :624-627). This spec's own stage A insertions
  shift every binding after :516 downward; the "was" numbers are the 560d89e
  positions. A new exe would duplicate roughly 200 LOC of this infrastructure or
  force exports nothing else needs.
- Stage A then touches NO test/dune line, and the exe roster changes exactly once
  this phase (stage B's pin exe, 85 -> 86). The ruling's C6 note "suite count
  85 -> 86" counted only the alternative mutation exe; under this decision the total
  is still 86 because only `t_p26_pins` registers.

New top-level names must be FRESH (`forge_at`, `reconcile_state_at`,
`nameless_pod_obj`, `test_p26_m1_forged_rows`, `test_p26_m3_128_row`). Never reuse an
existing binding name: a shadowed same-named test fn binds the later one and prints
green with the case count unchanged. Stage-A gate: the `p24_mutation` Alcotest case
count goes 7 -> 9 (the registration list, the Alcotest.run block at
t_p24_mutation.ml:1348 in the staged tree, was :1117-1171 at 560d89e, gains two
groups).

### 1.7 Rider R2: correction of the stale BUILD-SPEC-P24.md item-1b framing

BUILD-SPEC-P24.md:1233-1245 frames "EIGHTEEN CONJUNCT SITES WITH NO RED CAPABILITY"
as the fourteen M1 sites, M3 :128, "plus the {:126, :127, :132} class", and offers
the forged-state route as buying "all fourteen M1 sites and :128". That framing is
STALE in one respect: the {:126, :127, :132} class needs NOTHING. The class already
has red capability 1, bought by the M3a(:126-127) row (t_p24_mutation.ml:839-853),
and state_predicates.mli:318-325 records it MEASURED: deleting all three together is
killed; no state, forged or reached, separates any member from its class. So the
buyable set is exactly FIFTEEN sites (fourteen M1 plus M3 :128), which is what P26
ships. BUILD-SPEC-P24.md itself is NEVER edited (P22 precedent: correct in next-spec
prose, never in place). This subsection is the correction.

## 2. The fifteen FORGED-STATE rows

House term: FORGED-STATE rows (RULING:11). Pattern: the existing M1a/M1b rows
(t_p24_mutation.ml:719-735, :736-751) and the M3a row (:839-853). Unit cost ~16-17
LOC per row (RULING:16-17), ~250-300 LOC total plus the small builders below.

**Route constraints (binding).** The rows are seed-free, bound-free, and pin-free,
exactly as state_predicates.mli:372 records ("Additive to a test file; touches no
seed, no bound, no pin"). A row that turns out to need a seed or a bound is a
phase-STOP, not an improvisation (RULING:157-159). Every row asserts, in order:
(1) `injection_landed`, (2) M1's (or M3's) premise FIRES, (3) the member is RED,
(4) P23's L1 (or L2) is GREEN on the SAME state (discrimination). Each new test fn
opens with the accepted-state GREEN control before any red row (the
t_p24_mutation.ml:700-718 discipline). Never edit an assertion to force green.

**New builders (2-3, per RULING:17-18).** Additive, placed beside the existing forge
section of t_p24_mutation.ml:

1. `reconcile_state_at ~step ~needed ~needed_index ~condemned ~condemned_index`:
   `reconcile_state` (:495-505) with the two index cursors parameterized (pvcs stays
   `[]`, pvc_index stays 0).
2. `forge_at`: `forge` (:507-516) over builder 1.
3. `nameless_pod_obj`: a marshalled `listed_pod` whose `metadata.name` is `None`
   (the :128 payload; repod discipline of :543-547).

Negative index forgeries are representable because the port's cursors are `int`
where upstream's are `nat` (state_predicates.ml:253-256 discloses this; it is why
the `>= 0` halves exist as deletable sites at all). Out-of-range slot reads fold to
`true` (`slot_at`/`slot_is_none`/`slot_is_some`, state_predicates.ml:172-182), which
the isolation column below relies on.

**Per-row table.** Deletable site = the conjunct's line(s) in
lib/assurance/state_predicates.ml (the stage-C deletion target). Record = the mli
line that lists the site as unexercised (state_predicates.mli:327-330 for M1,
:330 for :128). All M1 rows use `forge_at` unless marked `m1_state`. The test cr's
replicas is 1 by COMMITTED LITERAL, not by inference: p13_witness.ml:42
(`let witness_desired : int = 1`) aliases unchanged down the witness chain to
`P24_witness.witness_desired` (p24_witness.ml:118); t_p24_mutation.ml:425 binds
`desired = W.witness_desired` and :429 builds the cr with `Scenario.vsts ~desired ()`;
`vsts` delegates to `vsts_named` (scenario.ml:249-250), which sets
`Stateful_set.replicas = Some desired` (scenario.ml:236); and
t_p24_regression.ml:395-404 already Alcotest-pins `committed_witness_desired = 1`
against `W.witness_desired`. The accepted control at t_p24_mutation.ml:702 (one
needed slot, M1 green, so :194 forces replicas = 1) stays as corroboration only; it
is no longer the ground.

| row | upstream site | deletable site (state_predicates.ml) | forged state (step; needed; n_idx; condemned; c_idx) | why only this conjunct reds |
| --- | --- | --- | --- | --- |
| FS1 | :194 needed_len = replicas | :266-267 | `m1_state`: Delete_condemned; `[]`; 0; `[good_pod1]`; 0 | len 0 <> 1; :239 green (0<1), :248 green (condemned-or-later) |
| FS2 | :195 half A n_idx >= 0 | :268-269 | Done; `[Some good_pod0]`; -1; `[]`; 0 | -1 <= 1 keeps half B green; all step gates off at Done, :248 green |
| FS3 | :195 half B n_idx <= needed_len | :268,:270 | Done; `[Some good_pod0]`; 2; `[]`; 0 | 2 >= 0 keeps half A green; :230-231 gate off at Done |
| FS4 | :196 half A c_idx >= 0 | :271-272 | Done; `[Some good_pod0]`; 0; `[good_pod1]`; -1 | -1 <= 1 keeps half B green; :239/:240 gates off |
| FS5 | :196 half B c_idx <= condemned_len | :271,:273 | Done; `[Some good_pod0]`; 0; `[good_pod1]`; 2 | Done avoids :239 (whose gate would also red at Delete_condemned); :248 green |
| FS6 | :230-231 n_idx < needed_len at pvc/needed steps | :304-305 | Create_needed; `[Some good_pod0]`; 1; `[]`; 0 | mli:368-369's own example; :235 green (slot 1 out of range folds none->true); :195b green (1<=1) |
| FS7 | :235 slot None at n_idx at Create_needed | :306-309 | Create_needed; `[Some good_pod0]`; 0; `[]`; 0 | slot 0 is Some; :230-231 green (0<1); mli:369-370's example |
| FS8 | :236 slot None at n_idx-1 at After_create_needed | :310-313 | After_create_needed; `[Some good_pod0]`; 1; `[]`; 0 | slot 0 is Some; :242 green (1>0); :230-231 gate off |
| FS9 | :237 slot Some at n_idx at Update_needed | :314-317 | Update_needed; `[None]`; 0; `[]`; 0 | slot 0 is None; :194 green (len 1); :230-231 green (0<1) |
| FS10 | :238 slot Some at n_idx-1 at After_update_needed | :318-321 | After_update_needed; `[None]`; 1; `[]`; 0 | slot 0 is None; :242 green (1>0) |
| FS11 | :239 c_idx < condemned_len at Delete_condemned | :322-325 | Delete_condemned; `[Some good_pod0]`; 0; `[good_pod1]`; 1 | 1 < 1 false; :196b green (1<=1); :248 green |
| FS12 | :240 c_idx > 0 at After_delete_condemned | :326-329 | After_delete_condemned; `[Some good_pod0]`; 0; `[good_pod1]`; 0 | 0 > 0 false; :239 gate off; :196a green |
| FS13 | :242 n_idx > 0 at after-needed steps | :343-344 | After_create_needed; `[None]`; 0; `[]`; 0 | mli:370-371's example; :236 green (slot -1 folds none->true) |
| FS14 | :248 not-condemned-or-later => c_idx = 0 | :345-346 | Create_needed; `[None]`; 0; `[good_pod1]`; 1 | mli:371-372's example; needed `[None]` keeps :235 green; :196b green (1<=1) |
| FS15 | M3 :128 name is Some | :537-538 | `parked_with (nameless_pod_obj :: etcd_owned_objs)` | namespace present keeps :129-130 and L2 green; a nameless ref renders name `""` (ml:445-452), no duplicate for :115; :127/:132 expected green (see risk note) |

FS15 risk note (disclosed): :127 (`Pod.unmarshal`) and :132 (`objects_to_pods`) on a
nameless pod object are expected green by code reading, not by measurement. If either
also reds, the FS15 deletion trial (section 4.1) stays green after deleting :128 and
the survivor is recorded as a FINDING. Do not retune the forgery to force the trial
red; redesign only as a recorded finding-driven follow-up.

Isolation is ENFORCED by stage C, not argued: each deletion trial deletes exactly one
site and requires exactly its row to red (section 4.1).

## 3. The pin exe: `test/t_p26_pins.ml` (stage B, 85 -> 86)

Derived from the preserved `t_p26_probe.SOURCE.ml` (graph constructions :65-104,
:233-285 byte-for-byte; conjunct closures :109-231; report shape kept). Registered in
test/dune. It is an Alcotest suite with ONE pin per test case, so a failing pin reds
its own case and the run still completes every other case. Graph-identity positive
controls (states_seen, inv6 gates) keep the probe's printf shape: a mismatch prints
`MISMATCH-WARN` and the run CONTINUES (t_p26_probe.SOURCE.ml:8-11,:399-401; the P25
F5 observability trap, deliberately not reproduced: RULING:114-116). The exe never
calls `exit`. Firewall: combinators only, no loop keywords, no exceptions, no
two-arm match on Option/Result, no wildcard on a finite sum, no raw indexing
(t_p26_probe.SOURCE.ml:49-51).

Two disclosed renderings ride with the pins, copied from the probe
(RULING:105-107): :220 `state_validation` rendered `Option.is_some pvc.spec`
(v_stateful_set.ml:81-86); :223-228 rendered as a total positional zip, short
`pvcs` renders false.

### 3.1 Pin roster (every literal cited in section 0.1)

| pin group | Alcotest-pinned literals | notes |
| --- | --- | --- |
| Full-evaluation pin (C1: PROMOTED) | premises :197=80, :198=80, :199=8, :215-221=80, :223-228=40, :233=8, :244=32, :246=8; violating=0 for all eight; blanket=80 | all 8 excluded conjuncts have implemented violation halves, evaluated on L0v, NON-VACUOUS (log:8-15); :246u stays WARN-only info (log:16) |
| Inertness pin | :197 violating=0 AND :198 violating=0, in a case named for ml:485/:489 | the doc comment records the ground: :198 pins pvcs.len=pvc_cnt=1 at every blanket state, so a state minted by a mutated else-leg would carry pvc_index=2>1 and redden :197; violating=0 proves BOTH dispatch_after_list else-legs (v_stateful_set_reconciler.ml:485 Delete_condemned, :489 Delete_outdated) unreachable on L0v (After_list_pod always takes ml:479-482 via ml:565). Evidence: probe-p26-run-mutated.log and probe-p26-run-mutated-485.log byte-identical per row (RULING:27-35) |
| Guarantee quad pins | FAIR 8580: G1=668, G3=440, G4=2088; CRASH 10552: G1=1224, G3=32, G4=2328; violating=0 everywhere; vsts1 = vsts2 asserted per member (identical per CR) | log:19-38; G2 premise=0 pinned as the C3 vacuity record, prose "vacuous-pending-scale-down" |
| Resp occupancy pins | Create_response states 2064 FAIR / 3552 CRASH / 8 L0v; Get_response 8 L0v; Update_response=0 and Delete_response=0 on all three graphs; Get_response=0 FAIR and CRASH | log:41-58 |
| List_response column (C2) | FRESH-MEASURED at stage B, pinned then | constraint: List + residual-Other distinct_msgs = 3760 FAIR / 3264 CRASH / 12 L0v; SUM-MATCH stays green (log:46,52,58) |
| Graph-identity controls (WARN-only, not Alcotest) | L0v 116, blanket 80 duplicate print, FAIR 8580, inv6 6952, CRASH 10552, post-crash 2784 | printf MISMATCH-WARN shape; the same literals also gate as Alcotest pins where listed above |

All P26 pins are ADDITIVE. No P13-P25 literal changes value (RULING:149-151). The 8
conjuncts are NOT committed green: exclusion ground stays RED-CAPABILITY-PENDING,
refined by the inertness pin.

## 4. Mutation matrix (stage C)

Per-trial discipline, every row: (1) run unmutated first and reproduce the pins
(positive control); (2) save pre-edit bytes (`cp` to the harness dir); (3) apply ONE
edit; (4) build to a file, run `--force`, record; (5) restore by `cp` then verify
`cmp` byte-identical, NEVER `git checkout`/`git restore`; (6) re-run unmutated and
see green again. No review and no measurement inside a mutation window. No concurrent
session may touch the repo during a window. A mutant killed by a BUILD error or a
timeout is NOT caught.

### 4.1 The fifteen deletion trials (ship gate for section 2)

One trial per FS row, one site per trial, in table order. Delete the row's deletable
site from lib/assurance/state_predicates.ml (for FS1 the site is the leading
conjunct: replace `needed_len = replicas` with `true`; for every other site remove
the whole `&& (...)` group; both edits compile). Run the suite forced. The gate:

- The row's OWN case reds (read the `N failures!` summary).
- Restore by cp + cmp byte-identical.
- A row that stays green under its deletion is recorded as a FINDING and is never
  edited to force a pass (RULING:22-24). The finding defers to P27; the row still
  ships as written.

### 4.2 The ml:623/:639 probe trial (PROBE only, C4)

Two trials, ONE site per trial: v_stateful_set_reconciler.ml:623 (Create_pvc arm)
then :639 (Skip_pvc arm), the Get_pvc-family pvc_index advance (RULING:42-43). Save
pre-edit bytes first (the same file already has two PRE-MUTATION byte files in the
harness; mint fresh ones for these trials). Run the pin exe against L0v, record
whether any of the 8 conjunct pins reds. Restore cp + cmp byte-identical. NOTE:
this file also hosts the never-mutate-in-place surfaces `pod_filter` (ml:421-432)
and `objects_to_pods` (ml:461-463); the trials touch neither (RULING:152-156). A red does
NOT change P26 scope. The commit decision stays P27.

### 4.3 Standing gates (not mutants)

- LEG2 re-run after R1: a red is a REAL FINDING, never weakened.
- Forced full battery at stage C close: cached `@runtest` is vacuous; only `--force`
  counts.

## 5. Stage plan

### Stage A: rows + riders

Land: the fifteen FS rows + builders in test/t_p24_mutation.ml (C6); rider R1
(local_binding.ml:338-348 reshape onto `holds_at_key`); rider R2 is already in this
spec (section 1.7); the section 6.1 mli append.

Gates:
- Novelty gate (section 0.2) re-run immediately before landing: diff EMPTY against
  the captured baseline file (plus at most the sanctioned section 6.1 mli append).
- Build green; forced `@runtest` RC=0; STILL 85 exes (stage A adds none; test/dune
  untouched).
- Alcotest case count for `p24_mutation` is 9 (was 7); both new case names present
  in the run listing (shadowed-binding guard, section 1.6).
- R1 byte-stability: `git diff` shows the l2 `holds` hunk ONLY inside
  local_binding.ml:338-348; l1/l2 `source` strings (:328, :341), `binding_sources`,
  and `binding_cardinal` 2 byte-stable.
- Battery coordinates hold: the pinned anchors still sit at internal_guarantee.mli:232,
  local_binding.mli:331, state_predicates.mli:861 (rg -n each anchor string; any
  drift is a phase-STOP).
- LEG2 re-run after R1 (first pass; repeated at stage C close).

### Stage B: the pin exe

Land: `test/t_p26_pins.ml` + its test/dune name (85 -> 86).

Gates:
- Every section 3.1 literal reproduced EXACTLY by this stage's own forced run. A
  mismatch is a phase-STOP finding, not a pin adjustment.
- The run output contains ZERO `MISMATCH-WARN` and ZERO `SUM-MISMATCH-WARN` lines
  (rg the output file).
- List_response column literals minted, pinned, and the bucket-sum constraint of
  section 1.2 verified.
- Novelty gate re-run diffs EMPTY against the captured baseline file (the pin exe
  lives in test/, not lib/).
- G2 premise=0 pin carries the vacuous-pending-scale-down prose (C3).

### Stage C: mutation trials + battery

Run: the fifteen deletion trials (4.1), then the ml:623/:639 probe trials (4.2),
serialized, each with its own restore + post-restore green re-run. Then the forced
full battery + LEG2 re-run (4.3).

Gates:
- 15/15 deletion trials red (or survivors recorded as FINDINGS, count against the
  <=7 findings bound).
- Probe trial outcomes recorded in the seal, with the scope note: commit-green stays
  P27 either way.
- `git status --short` and `git diff --name-only` empty of every trial file after
  restores (worktree equals index; mutation residue is a stop-and-investigate).
- Novelty gate re-run after all restores: diff EMPTY against the captured baseline
  file (section 0.2).
- Forced battery green; LEG2 green or a recorded finding.

### Seal (appended at seal time; do not write it now)

The seal section is appended when the phase closes. It must reconcile every
EXPECTED REPRODUCTION TARGET against the phase's own measurements (the P25
section 0.3 rule: predictions must not outlive their measurements) and re-run the
novelty gate and the frozen-roster byte-stability check against 560d89e.

## 6. Blast table

| file:line | change | stage |
| --- | --- | --- |
| test/t_p24_mutation.ml:495-516 (beside) | +`reconcile_state_at`, +`forge_at`, +`nameless_pod_obj` (fresh names, additive) | A |
| test/t_p24_mutation.ml:766+ (after test_m1_novel_conjuncts) | +`test_p26_m1_forged_rows` (FS1-FS14, ~230-240 LOC) | A |
| test/t_p24_mutation.ml:~860+ (after test_m3_shape_conjuncts) | +`test_p26_m3_128_row` (FS15, ~17 LOC) | A |
| test/t_p24_mutation.ml:1117-1171 | +2 Alcotest groups (case count 7 -> 9) | A |
| lib/assurance/local_binding.ml:338-348 | R1: l2 `holds` closure -> `holds_at_key ~controller_id ~cr_key`; name/source/interesting byte-stable | A |
| lib/assurance/state_predicates.mli (APPEND after :933, end of file) | P26 superseding-pin record, plain comment, prose only (see 6.1) | A |
| lib/checker/BUILD-SPEC-P26.md | this file (carries R2) | A |
| test/t_p26_pins.ml | NEW exe (~450-520 LOC, derived from t_p26_probe.SOURCE.ml) | B |
| test/dune | +1 name: t_p26_pins (85 -> 86) | B |
| test/p25_witness.ml:177-200 | LEG3 leg3_case_counts guard maintenance: ("t_p24_mutation", 7 -> 9) at stage A; +("t_p26_pins", 27) at stage B. This list is the deliberate-registration half of the shadowed-binding guard (doc comment p25_witness.ml:169-176) and is NOT in the section 7 frozen roster; the spec's own stage gates (case count 7 -> 9, suite 85 -> 86, forced battery green) are unsatisfiable without it. Side effect: the two committed P25 pin lines shift :238-239 -> :243-244, values byte-identical. | A+B |
| lib/assurance/state_predicates.ml:266-346, :537-538 | deletion trials ONLY; restored cp + cmp; never committed | C |
| lib/controllers/v_stateful_set_reconciler.ml:623, :639 | probe trials ONLY; restored cp + cmp; never committed. (An earlier draft of this row wrote lib/reconciler/, a directory that holds no reconciler module; the probe target is lib/controllers/.) | C |

### 6.1 The mli record placement (deviation, with ground)

RULING:150 says the superseding pins "land in the state_predicates.mli exclusion
block + a new witness exe". The exclusion block sits at state_predicates.mli:97-115,
ABOVE the frozen battery coordinate at :861, so inserting lines there moves the :861
coordinate, and a moved pin is a phase-STOP (RULING:147-148). Resolution: the record
text is APPEND-ONLY at the END of the file (after :933), a plain `(* ... *)` comment
block titled "P26 superseding pins", cross-referencing :97-115 and t_p26_pins.ml.
The :97-115 block itself is NOT edited; its now-stale "until a named mutant ... is
run" sentence is corrected by this spec's prose only (the P22/P24 precedent). Any
count-bearing phrase in the appended text carries the LEG exempt-marker discipline
(t_p25_reconcile.ml:805-811) so the layer-2 scanner does not read history as
current form.

## 7. Frozen-pin roster (phase-STOP on any motion)

Copied verbatim from RULING-P26-SELECTION.md, section "Pin-safety (binding)"
(RULING:140-163):

> - NO committed pin moves in P26. FROZEN roster byte-stable: guarantee_cardinal 4,
>   binding_cardinal 2, ledger_spec_fn_count 9, shipped [544;562;581;589;606;613;640],
>   excluded [522;528] (p21_witness.ml:242-245); battery coordinate pins
>   internal_guarantee.mli:232, local_binding.mli:331, state_predicates.mli:861; LEG1
>   exempt markers; LEG2 partition-reconciliation and LEG4 0-XOR-11 cite gates keep
>   watching - a red there is a REAL FINDING, never weakened. A moved pin is a
>   phase-STOP.
> - All P26 pins are ADDITIVE: superseding measurement pins land in the
>   state_predicates.mli exclusion block + a new witness exe; no P13-P25 literal
>   changes value. The 8 conjuncts are NOT committed green.
> - Never edit fault_check.ml:37-145. Never mutate pod_filter/objects_to_pods in
>   place (pod_filter v_stateful_set_reconciler.ml:421-432, objects_to_pods
>   :461-463). NOTE: the ml:623/:639 mutant
>   trials and nothing else touch that same file - every trial saves pre-edit bytes
>   first and restores by cp + cmp byte-identical, never git checkout/restore; one
>   mutant per trial; no review or measurement inside a mutation window.
> - The forged-state rows must remain seed-free/bound-free/pin-free exactly as
>   state_predicates.mli:372 records; any row found to need a seed or bound is a
>   phase-STOP, not an improvisation.
> - Cached @runtest is vacuous; every ship gate runs --force (or dune exec on the
>   single exe). Novelty gate before stage A: no lib-side evaluator of the 8 excluded
>   conjuncts may appear (the probe closures stay in test/harness); rg the 8 site
>   cites over lib/ -g '!*.md' must stay empty of new evaluators.

Placement deviation for the second bullet's mli clause is recorded in section 6.1,
with its ground (protecting the frozen :861 coordinate, which the same roster
freezes).

## 8. Deferred-to-P27 ledger

The RULING's closing table, adjusted for the C1-C6 resolutions of section 1:

| item | status | ground |
| --- | --- | --- |
| Commit-green for the 8 vct:true conjuncts | EXCLUDED, RED-CAPABILITY-PENDING (refined) | ml:485/:489 mutants proven inert (unreachable legs, pinned by the inertness pin); the next named mutant ml:623/:639 RUNS as a P26 stage-C probe (C4 resolved); even a red defers the commit decision to P27 |
| Guarantee-side :133-180 / :522 | superseding pin recorded (P26 pin exe) | non-vacuous on multi-CR but violating=0 everywhere; G2 :581 premise=0 both graphs, pinned and recorded vacuous-pending-scale-down (C3); needs a graph that can distinguish the register (scale-down seed, phase-owner class of item 1a, or forbidden-kind occupancy) |
| Resp-side triad :666+ preservation lemma | occupancy pinned; List_response column isolated and pinned by P26 (C2 resolved); port deferred | proof fn over (s,s') pairs, no transition-shaped register exists; port cost L, argued-only on shape |
| Other-controller rely :32-55/:92-129 | vacuous by construction | second-controller seed is phase-owner (scenario.ml:68,:308 single-entry Imap; no controller-count param, scenario.mli:304-359); rely port cost L |
| Item 1a foreign-sourced pending request | phase-owner cost recorded | >=30 pinned/cited sites across 5 files ride the 16/112/288/1560 denominators (message.ml:175-179 stamps Controller src unconditionally) |
| Item 5 outdated pipeline (rs:773-856) | phase-owner cost recorded | After_delete_outdated 0/0/0/0 on all shipped graphs vs positive control Delete_outdated 8/76/64/1272; needs a template-stale-pod seed |
| Deletion-trial survivors, if any (4.1) | FINDING carried, row ships as written | a survivor is a test gap, never an edited assertion |

## 9. SEAL (phase closed 2026-08-08)

All gates ran against 560d89e plus the staged diff. Harness evidence:
`~/Documents/anvil-ocaml-p26-harness/`.

### 9.1 Stage outcomes [MEASURED]

- Stage A green: 15 forged-state rows landed; `p24_mutation` Alcotest case count
  7 -> 9 with both new case names in the run listing; R1 applied with
  `binding_sources`/`binding_cardinal` byte-stable; novelty baseline captured
  (19 hits, matches the section 0.2 cross-check exactly); forced @runtest RC=0.
- Stage B green: `test/t_p26_pins.ml` runs 27 cases; suite 85 -> 86; every
  section 3.1 literal reproduced by this stage's own forced run; zero
  `MISMATCH-WARN` and zero `SUM-MISMATCH-WARN` lines; List_response column
  minted and pinned: FAIR 2880 + 880 = 3760, CRASH 3200 + 64 = 3264,
  L0v 8 + 4 = 12, every bucket-sum constraint green.
- Stage C: deletion trials 12/15 KILLED with per-row attribution
  (stageC-c*-FS*-mutant.log). FS6/FS13/FS14 COMPILE_FAIL: the deletion form is
  rejected by warning 32 (unused value) at state_predicates.ml:192/:203/:213,
  so those rows' kill capability is UNPROVEN; the rows ship as written and the
  three results are carried as findings. Probe trials: ml:623 and ml:639 BOTH
  KILLED; the :197 pin reported violating counts 28 and 20 respectively, and
  the :246 pin plus the inertness pin also went red during the trials. Red
  capability now exists for the 8 excluded conjuncts; the commit-green decision
  stays with P27 (section 4.2 scope note). Every restore verified cp + cmp
  byte-identical; post-restore worktree equals index. Forced battery 86/86
  green (p26-forced-battery.log). LEG2 re-run green.

### 9.2 Findings ledger (bound: 7)

Five findings of seven used:
1-3. FS6/FS13/FS14 COMPILE_FAIL (above): kill capability unproven, test gap
  candidates for P27.
4. Review HIGH: sections 4.2 and 7 swapped the two never-mutate-in-place
  functions. Live tree: `pod_filter` at v_stateful_set_reconciler.ml:421-432,
  `objects_to_pods` at :461-463. Fixed in place; the same swap in prior phase
  notes is corrected there.
5. Review MED: section 1.6 cited 560d89e line numbers that this spec's own
  stage A insertions shift, with no drift caveat. Fixed in place with
  was-at-560d89e annotations; the registration-list cite moved to
  t_p24_mutation.ml:1348.

The review wave (run wf_911b231f-18f: 5 static finders including one
cross-file adversarial pass, then one refuter per finding; 7 agents, 0 errors)
CONFIRMED both review findings and reported no code defect. Both fixes are
prose-only edits to this file, made after the stage C battery; no compiled
byte changed after that battery, so its result stands.

### 9.3 Seal gates re-run [MEASURED]

- Novelty gate: seal re-run diffs EMPTY against the captured baseline
  (novelty-gate-seal-rerun.txt, novelty-seal.sorted; rc=0) and is byte-identical
  to the stage-C re-run. The section 6.1 append allowance was not needed: the
  appended mli text contains no token the gate command matches.
- Frozen roster byte-stable: HEAD is 560d89e; the staged diff names exactly the
  seven section 6 blast paths. p21_witness.ml:242-245, internal_guarantee.mli:232,
  local_binding.mli:331, fault_check.ml:37-145 and
  v_stateful_set_reconciler.ml sit in files ABSENT from the diff, so they are
  byte-identical to 560d89e. The one frozen coordinate inside a modified file,
  state_predicates.mli:861, is untouched: that file's single hunk is the
  sanctioned append at :934-960.
- Worktree equals index (`git diff --name-only` empty) after the review wave
  and after the seal edits.

### 9.4 Prediction reconciliation (P25 section 0.3 rule)

- Case counts: predicted 7 -> 9 and 27; measured 7 -> 9 and 27. Suite count:
  predicted 85 -> 86; measured 86.
- t_p26_pins.ml size: predicted ~450-520 LOC; landed 828 lines. The overshoot
  is the C2 List_response column plus per-pin doc comments; no scope change.
- Registration list: predicted at t_p24_mutation.ml:1117-1171; landed at :1348
  (this spec's own insertions shift it; section 1.6 reconciled).
- p25_witness.ml pin lines: predicted stable at :238-239; landed at :243-244
  with values byte-identical (LEG3 guard maintenance, section 6 blast row).
- Deletion trials: predicted 15/15 red; measured 12 KILLED + 3 COMPILE_FAIL
  (findings 1-3). Probe: no prediction was made; both sites killed.

Sealed by the P26 review-and-seal pass, 2026-08-08. The diff is STAGED only.
The user commits with `git commit -s`; the message draft is
`~/Documents/anvil-ocaml-p26-harness/commit-message-p26.txt`.

---

*Written by the P26 design wave's spec writer, 2026-08-07, against 560d89e (tree
clean, 85 exes [MEASURED]). Sources: RULING-P26-SELECTION.md (authoritative pick);
probe-p26-run-unmutated.log (all Section 0.1 numbers); t_p26_probe.SOURCE.ml;
BUILD-SPEC-P25.md (house style + frozen precedent); fresh rg/Read measurements
marked [MEASURED] inline. Never commit for the user; stage only. The SEAL
(section 9) was appended at phase close, 2026-08-08.*

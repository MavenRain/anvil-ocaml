# BUILD-SPEC-P27: the split promotion note for :197/:246 and the FS6/FS13/FS14 closure, a DOC-ONLY phase

## 0. Phase identity, bounds, and baseline

Repo: `/Users/oobi/Documents/anvil-ocaml`. Selection: RULING-P27-SELECTION.md,
2026-08-08 (mech scout + triage + FS probe wave,
`/Users/oobi/Documents/anvil-ocaml-p27-harness/`). Prior-phase evidence:
`/Users/oobi/Documents/anvil-ocaml-p26-harness/` (read-only).

At selection time the repo sat at 560d89e with the P26 diff STAGED and not
committed; index equals worktree, `git diff --name-only` empty [MEASURED at
selection: RULING-P27-SELECTION.md:3-8]. Stage A of THIS spec runs only after the
user commits that diff (section 0.0).

**P27 ships two items, NO new seed, NO pin moved, NO lib-side evaluator, NO new
exe** (RULING-P27-SELECTION.md:14):

1. **SPLIT PROMOTION.** One append-only note in `lib/assurance/state_predicates.mli`
   reclassifies :197 and :246 as PROBE-CONFIRMED red-capable on L0v and keeps the
   other six conjuncts at RED-CAPABILITY-PENDING. Grounds in section 1.1; the exact
   note text in section 2.
2. **FS6/FS13/FS14 CLOSURE.** This spec closes the three carried P26 findings with
   the P27 constant-true probe evidence. Section 3. The probe trials already ran in
   the selection wave; no trial runs in the build stages.

There is NO third item (RULING-P27-SELECTION.md:79-83): the triage found exactly
one READY-at-cost-S item, and it is ship item 2.

Phase bounds: <=2 findings, about 17 agents remain after the selection wave
[PREDICTED; RULING-P27-SELECTION.md:11 recorded 2 findings / about 20 agents at
selection time]. PREDICTED findings consumption for P27 itself: ZERO. The FS trio
closes three carried findings, and the probes produced kills, not findings
(RULING-P27-SELECTION.md:85-87).

This file is NEW and stays UNTRACKED through the whole phase. Never stage it.
Never stage, commit, or push anything in P27; print proposed commit messages for
the user (RULING-P27-SELECTION.md:117-118).

### 0.0 HARD PRECONDITION for stage A (binding; RULING-P27-SELECTION.md:89-106)

Do NOT run stage A, B, or C, and do NOT edit `lib/assurance/state_predicates.mli`,
before ALL of these pass:

1. The user has committed the staged P26 diff. This agent never commits
   (never-commit rule; RULING-P27-SELECTION.md:97-98).
2. Record the new baseline SHA at stage-A start:
   `git -C /Users/oobi/Documents/anvil-ocaml rev-parse HEAD`. Call it `<P27SHA>`.
   Require `<P27SHA>` != 560d89e (the P26 commit must exist,
   RULING-P27-SELECTION.md:91-93). Write `<P27SHA>` into the stage-A log and into
   the seal.
3. Clean tree: `git -C /Users/oobi/Documents/anvil-ocaml status --porcelain -uno`
   prints NOTHING (no staged and no unstaged tracked change), and the full
   `--porcelain` output lists AT MOST the single untracked row
   `?? lib/checker/BUILD-SPEC-P27.md` (this spec is the one sanctioned untracked
   file). Anything else is a STOP.
4. Re-verify the key coordinates against the COMMITTED tree, before any edit:
   - `wc -l lib/assurance/state_predicates.mli` = 960 [MEASURED this session at
     560d89e plus the staged diff; the commit changes no bytes,
     RULING-P27-SELECTION.md:99-101].
   - The P26 append block occupies state_predicates.mli:935-960: the title line
     `==== P26 superseding pins` sits at :935 and the closing `*)` at :960
     [MEASURED this session, block read in full].
   - The exclusion block sits at state_predicates.mli:97-115 and the frozen
     battery coordinate at state_predicates.mli:861: re-verify by `rg -n` on the
     anchor strings, the BUILD-SPEC-P26.md:401-403 stage-A gate pattern.
   - Any drift in any of these coordinates is a phase-STOP, not a re-aim
     (RULING-P27-SELECTION.md:102-106).

### 0.1 Measured grounds

Every number in this spec traces to one of these sources. Copy numbers. Never
recompute them.

| number | value | source line | tag |
| --- | --- | --- | --- |
| :197 violating, ml:623 Create_pvc-arm mutant | 28 | stageC-probe-623-mutant.log:11 | MEASURED, line re-read this session |
| :246 violating, ml:623 mutant | 4 | stageC-probe-623-mutant.log:18 | MEASURED, line re-read this session |
| :197 violating, ml:639 Skip_pvc-arm mutant | 20 | stageC-probe-639-mutant.log:11 | MEASURED (RULING-P27-SELECTION.md:27-29) |
| :246 violating, ml:639 mutant | 4 | stageC-probe-639-mutant.log:18 | MEASURED (RULING-P27-SELECTION.md:27-29) |
| six pending conjuncts violating, BOTH trials | 0 | stageC-probe-623-mutant.log:12-17, stageC-probe-639-mutant.log:12-17 | MEASURED, 623 lines re-read this session |
| post-restore suite, both probe trials | 27 tests, RC=0 | stageC-probe-623-restored.log:100-101, stageC-probe-639-restored.log:100-101 | MEASURED (RULING-P27-SELECTION.md:30-33) |
| L0v battery size | 116 states | t_p26_pins.ml:60-73 | MEASURED prior phase (RULING-P27-SELECTION.md:50-52) |
| FAIR / CRASH battery sizes | 8580 / 10552 states | probe-p26-run-unmutated.log:19,:21 via BUILD-SPEC-P26.md:59,:61 | MEASURED prior phase |
| FS6 trial result | `1 failure! in 0.051s. 9 tests run.`, RC=1 | p27-trial-FS6-mutant.log:60,:61 | MEASURED, lines re-read this session |
| FS13 trial result | `1 failure! in 0.080s. 9 tests run.`, RC=1 | p27-trial-FS13-mutant.log:88,:89 | MEASURED, lines re-read this session |
| FS14 trial result | `1 failure! in 0.048s. 9 tests run.`, RC=1 | p27-trial-FS14-mutant.log:91,:92 | MEASURED, lines re-read this session |
| final green, c2 invocation | `Test Successful in 0.049s. 9 tests run.`, RUNNER-RC-C2=0 | p27-trial-final-green.log:16,:17 | MEASURED, lines re-read this session |
| final green, c3 invocation | `Test Successful in 0.042s. 9 tests run.`, RUNNER-RC-C3=0 | p27-trial-final-green.log:33,:34 | MEASURED, lines re-read this session |
| suite exe count | 86 | BUILD-SPEC-P26.md:589-590 (predicted 85 -> 86; measured 86) | MEASURED prior phase |
| P26 novelty baseline hit set | 19 lines across 3 files | BUILD-SPEC-P26.md:115-121 | MEASURED prior phase, at 560d89e |
| mli length at baseline | 960 lines | `wc -l lib/assurance/state_predicates.mli` | MEASURED this session |
| new novelty hits from the section 2 note | 3 lines, all > :960 | section 0.2 enumeration rule | PREDICTED; MEASURED enumeration at stage A governs |

Values carried from the RULING or from prior-phase logs are EXPECTED REPRODUCTION
TARGETS for the gates that re-touch them. P27 adds no new measurement of its own
except the novelty-hit enumeration and the stage C battery.

### 0.2 The novelty gate (capture BEFORE stage A; every stage and the seal diff against it)

No new lib-side evaluator of the 8 excluded conjuncts may appear
(RULING-P27-SELECTION.md:112-114). The gate command, VERBATIM from
BUILD-SPEC-P26.md:102:

```
rg -n 'state_predicates\.rs:(197|198|199|215|223|233|244|246)|:197 |:198 |:199 |:215-221|:223-228|:233 |:244 |:246 ' lib -g '!*.md'
```

Capture the baseline ONCE, after the section 0.0 gate passes and BEFORE any stage-A
edit: run the command verbatim from the repo root and write its FULL output to
`/Users/oobi/Documents/anvil-ocaml-p27-harness/novelty-gate-baseline-<P27SHA>.txt`,
with `<P27SHA>` the SHA recorded in section 0.0. That captured file IS the
baseline. The stage-A re-run, the stage-C re-run, and the seal re-run must each be
diffed against that file.

PREDICTED baseline content: the same 19-line, 3-file hit set that
BUILD-SPEC-P26.md:115-121 records for 560d89e, with unchanged line numbers.
Grounds: the P26 diff appends at the mli END (all 12 mli hits sit at or below
:461, far above :935); `lib/assurance/state_predicates.ml` is NOT in the P26 diff
(BUILD-SPEC-P26.md:459: deletion trials only, never committed); the P26 appended
mli text contains no token the gate command matches (BUILD-SPEC-P26.md:573-576).
A baseline that differs from this prediction is a stop-and-investigate BEFORE any
edit. The captured file, not this prose, is what every gate diffs against; do NOT
gate on a hand-written line list (the BUILD-SPEC-P26.md:112-121 lesson).

The ONLY sanctioned delta, at every re-run: ADDITIONS confined to the NEW P27
append block in `lib/assurance/state_predicates.mli` at lines GREATER THAN 960.
The section 2 note names :197 and :246 on purpose, so new hits are EXPECTED.
PREDICTED, if the section 2 text is pasted verbatim: exactly 3 new hit lines (the
`:197 ` bullet line, the `:246 ` bullet line, and the one pending-six line that
carries `:215-221` and `:223-228`). At each re-run, enumerate every new hit
MEASURED into the stage log: file, line number, and the containing block. Any new
hit outside state_predicates.mli lines > 960, any new hit in any other file, or
any hit that binds code (any `let`) is a phase-STOP.

### 0.3 Measurement discipline

Carried from BUILD-SPEC-P26.md:123-134, unchanged:

- Builds: `opam exec --switch=anvil-ocaml -- dune build --root
  /Users/oobi/Documents/anvil-ocaml @runtest` (dune is NOT on PATH). Redirect
  output to a file. Never pipe through `tail`.
- Cached `@runtest` is vacuous. Every ship gate runs `--force`, or `dune exec` on
  the single exe.
- `dune build` exit 0 alone proves nothing. Verify the built artifact exists
  (`ls` the `_build` path) before reading a green.
- Read the Alcotest `N failures!` summary line, not the `> ` cursor line. Do not
  pass `-q`.
- Gates read the worktree. The P27 phase diff stays UNSTAGED (never `git add`), so
  the stage C green is read with `git diff --name-only <P27SHA>` naming exactly
  the sanctioned file, not with an empty diff.

P27 additions:

- Runner-script pattern, REQUIRED: a subagent's Bash cwd RESETS between calls.
  Put cd + build + run in ONE zsh file with absolute paths and execute that file.
  The proven form for this repo is
  `/Users/oobi/Documents/anvil-ocaml-p27-harness/run-p27-trial.zsh`.
- Copy numbers from section 0.1. Never recompute them.
- NO mutation trial runs in P27. The probe evidence already exists (sections 1
  and 3). If any step edits a compiled file other than the section 2 mli append,
  STOP.

## 1. Grounds

### 1.1 Split promotion of :197 and :246 (RULING-P27-SELECTION.md item 1)

Two named mutants reddened exactly two of the eight excluded conjuncts, on the
committed L0v graph (116 states, t_p26_pins.ml:60-73), all figures MEASURED:

- ml:623 Create_pvc-arm mutant: :197 violating=28
  (stageC-probe-623-mutant.log:11) and :246 violating=4
  (stageC-probe-623-mutant.log:18).
- ml:639 Skip_pvc-arm mutant: :197 violating=20
  (stageC-probe-639-mutant.log:11) and :246 violating=4
  (stageC-probe-639-mutant.log:18).
- The six other conjuncts (:198, :199, :215-221, :223-228, :233, :244) measured
  violating=0 in BOTH trials (stageC-probe-623-mutant.log:12-17,
  stageC-probe-639-mutant.log:12-17). No named mutant has reddened them, so they
  STAY at RED-CAPABILITY-PENDING.

Mutant sites: `lib/controllers/v_stateful_set_reconciler.ml:623` and `:639`. Both
trials were restored byte-identical and the post-restore suite ran green, 27
tests, RC=0 (stageC-probe-623-restored.log:100-101,
stageC-probe-639-restored.log:100-101) [MEASURED, RULING-P27-SELECTION.md:30-33].

Consequences, binding:

- `test/t_p26_pins.ml` does NOT change. The hard Alcotest pins for :197 and :246
  (t_p26_pins.ml:514-517,:542-544) and the inertness pin (t_p26_pins.ml:555-559)
  stay the committed L0v regression signal (RULING-P27-SELECTION.md:38-40).
- No lib-side evaluator of the 8 conjuncts appears; the novelty gate of section
  0.2 stays in force (RULING-P27-SELECTION.md:41-42).
- The frozen battery coordinate at state_predicates.mli:861 does not move; a
  moved pin is a phase-STOP (RULING-P27-SELECTION.md:42-44).
- Standing caveat, carried into the section 2 note: the two confirmed conjuncts
  were probed on L0v ONLY, never on the FAIR (8580-state) or CRASH (10552-state)
  batteries (RULING-P27-SELECTION.md:50-52). Two confirmed does NOT close the
  octet.

### 1.2 FS6/FS13/FS14 closure grounds (RULING-P27-SELECTION.md item 2)

The P27 probe applied the primary constant-true neutralization form at each
conjunct call line. Each mutant COMPILED and reddened its TARGET row, with
the Alcotest summary line `1 failure!` in 9 tests run, all figures MEASURED.
Selectivity limitation (P27 review wave, finding 2): the 14 FS rows run inside
ONE Alcotest case (p26_m1_forged_rows, test/t_p24_mutation.ml:890-896), and
fs_row stops the case at the first red row. So the FS6 trial did not run rows
FS7-FS14, and the FS13 trial did not run FS14. Only the FS14 trial shows all 13
prior rows green before its own red. The `1 failure!` figure counts Alcotest
CASES, not FS rows. The closure claim below is red-capability of each target
row; it is NOT a row-selectivity claim for FS6 or FS13:

- FS6 (:230-231): `1 failure! in 0.051s. 9 tests run.`
  (p27-trial-FS6-mutant.log:60), RC=1 (p27-trial-FS6-mutant.log:61). Restore cmp
  byte-identical against PRE-TRIAL-FS6-state_predicates.ml.bytes.
- FS13 (:242): `1 failure! in 0.080s. 9 tests run.`
  (p27-trial-FS13-mutant.log:88), RC=1 (p27-trial-FS13-mutant.log:89). Restore
  cmp byte-identical against PRE-TRIAL-FS13-state_predicates.ml.bytes.
- FS14 (:248): `1 failure! in 0.048s. 9 tests run.`
  (p27-trial-FS14-mutant.log:91), RC=1 (p27-trial-FS14-mutant.log:92). Restore
  cmp byte-identical against PRE-TRIAL-FS14-state_predicates.ml.bytes.
- Final green after all restores, BOTH invocation forms:
  `Test Successful in 0.049s. 9 tests run.` with RUNNER-RC-C2=0
  (p27-trial-final-green.log:16,:17) and
  `Test Successful in 0.042s. 9 tests run.` with RUNNER-RC-C3=0
  (p27-trial-final-green.log:33,:34). Worktree diff empty after the wave
  [MEASURED, RULING-P27-SELECTION.md:68].

Legality across the commit gate: the trial target
`lib/assurance/state_predicates.ml` is NOT part of the staged P26 diff
(BUILD-SPEC-P26.md:459: deletion trials only, never committed), so these trials
were legal before the P26 commit (RULING-P27-SELECTION.md:69-72).

Kill-quality note: each red is a genuine assertion failure read from the
`N failures!` summary line with the full 9-test count present, not a build error
and not a timeout; each mutant compiled (RULING-P27-SELECTION.md:59-64).

### 1.3 No third item

The selection rule allowed at most one more deferred item, and only at
classification READY with cost S. The triage found exactly one such item: the
FS6/FS13/FS14 trio, which is already ship item 2. Every other triage item is
BLOCKED or DEFER-AGAIN (RULING-P27-SELECTION.md:79-83; section 8).

## 2. The mli append-only note (exact text, ready to paste)

Placement: APPEND after state_predicates.mli:960 (the end of file at the recorded
baseline). The new block starts at :961, after one separating empty line, and
follows the P26 block at :935-960. NEVER touch mli:97-115 (the exclusion block),
:861 (the frozen battery coordinate), or :935-960 (the P26 block). Apply with the
Edit tool, anchored on the final `*)` line of the P26 block; the edit is pure
addition. One plain `(* ... *)` OCaml comment block, prose only, no `let`, in the
same format as the :935-960 precedent [MEASURED this session, block read].

Marker check before pasting: BUILD-SPEC-P26.md:471-474 requires the LEG
exempt-marker discipline (t_p25_reconcile.ml:805-811) on count-bearing phrases in
appended mli text. At stage A, check the text below against that discipline and
add the markers it requires, mirroring the final form of the :935-960 block. If a
LEG guard nevertheless reds at stage C, that red is a REAL FINDING, never
weakened.

The note text:

```
(* ==== P27 split promotion note (append-only; BUILD-SPEC-P27 section 2) ====

   This block reclassifies exactly two of the eight vct:true conjuncts that
   the EXCLUDED-WITH-A-PIN block at :97-115 above holds out as
   RED-CAPABILITY-PENDING. Two conjuncts are now PROBE-CONFIRMED red-capable
   on the committed L0v graph (116 states, [test/t_p26_pins.ml]:60-73):

   - :197 (pvc_index <= pvc_cnt): the ml:623 Create_pvc-arm mutant measured
     violating=28 and the ml:639 Skip_pvc-arm mutant measured violating=20
     (stageC-probe-623-mutant.log:11; stageC-probe-639-mutant.log:11).
   - :246 (the P25 premise form, idx>0): both mutants measured violating=4
     (stageC-probe-623-mutant.log:18; stageC-probe-639-mutant.log:18).

   Mutant sites: [lib/controllers/v_stateful_set_reconciler.ml]:623 and
   :639, one mutant per trial. Both trials were restored byte-identical
   (cp + cmp) and the post-restore suite ran green, 27 tests, RC=0
   (stageC-probe-623-restored.log:100-101,
   stageC-probe-639-restored.log:100-101).

   The other six conjuncts (:198, :199, :215-221, :223-228, :233, :244)
   STAY at RED-CAPABILITY-PENDING: both trials measured violating=0 for
   all six (stageC-probe-623-mutant.log:12-17,
   stageC-probe-639-mutant.log:12-17). No named mutant has reddened them.

   Standing caveat: two confirmed conjuncts do NOT close the octet. The
   probes ran on L0v only, never on the FAIR (8580-state) or CRASH
   (10552-state) batteries. The eight conjuncts stay EXCLUDED from
   committed green. The :97-115 block, the frozen battery coordinate at
   :861, and the P26 block above are NOT edited; this note is the
   append-only correction (the P22/P24 precedent). Grounds, stage gates,
   and the pending-mutant ledger: [lib/checker/BUILD-SPEC-P27.md]. *)
```

Novelty interaction, PREDICTED (the section 0.2 rule governs): exactly 3 lines of
this note match the gate command: the `- :197 (pvc_index ...` line, the
`- :246 (the P25 ...` line, and the `(:198, :199, :215-221, :223-228, ...` line.
All other coordinate mentions carry a comma, a parenthesis, a semicolon, or a
range form the pattern does not match. Enumerate the MEASURED hits at stage A.

## 3. Findings closure: FS6/FS13/FS14 CLOSED

Carried rows: the P26 seal ledger, BUILD-SPEC-P26.md:551-560 (section 9.2),
findings 1-3 at BUILD-SPEC-P26.md:554-555: FS6/FS13/FS14 COMPILE_FAIL, kill
capability UNPROVEN, test-gap candidates for P27. Grounds detail:
BUILD-SPEC-P26.md:521 and :540-542 (the deletion form was rejected by warning 32
at state_predicates.ml:192/:203/:213, so the rows shipped as written and the
three results were carried as findings).

Disposition: CLOSED. The P27 probe evidence of section 1.2 proves all three rows
red-capable via the constant-true form: each row compiled and reddened when
targeted (`1 failure!` in 9 tests run counts CASES; the case stops at the first
red row, see the section 1.2 selectivity limitation), restored cmp-identical,
and the suite finished green 9/9 on both the c2 and the c3 invocations
(p27-trial-final-green.log:16-17,:33-34).

Edit forms recorded per site (RULING-P27-SELECTION.md:73-77):

- PRIMARY, exercised and MEASURED red: constant-true neutralization at the
  conjunct call lines, state_predicates.ml:305, :344, :346.
- FALLBACK, recorded and NOT exercised [PREDICTED]: constant-true rewrite at the
  definition sites, state_predicates.ml:192, :203, :213, where the deletion form
  is rejected by warning 32 (BUILD-SPEC-P26.md:521,:540-542).

The FS rows in test/t_p24_mutation.ml (:890, :936, :943) do NOT change
(RULING-P27-SELECTION.md:76-77). This closure consumes ZERO new findings; it
closes three carried ones (RULING-P27-SELECTION.md:85-87). The seal (section 9)
records the closure in its own findings ledger.

## 4. Mutation matrix (stage C): EMPTY

Stages A-C run ZERO mutation trials. The probe evidence in sections 1 and 3
came from the P27 SELECTION WAVE: three FS mutation windows against
state_predicates.ml, opened and restored cmp-identical before this spec
existed and before stage A (RULING-P27-SELECTION.md:54-77,:134-140;
p27-trial-*.log). Standing gates only, carried from BUILD-SPEC-P26.md:377-381:

- Forced full battery at stage C close; cached `@runtest` is vacuous, only
  `--force` counts.
- LEG2/LEG3/LEG4 watch gates keep watching. A red there is a REAL FINDING, never
  weakened.

## 5. Stage plan

### Stage A: the mli append

Order is binding:

1. Section 0.0 HARD PRECONDITION gate, in full. Record `<P27SHA>`.
2. Section 0.2 baseline capture, to
   `/Users/oobi/Documents/anvil-ocaml-p27-harness/novelty-gate-baseline-<P27SHA>.txt`.
3. Apply the section 2 note with the Edit tool (append-only, after :960).
4. Build green via the runner-script pattern (section 0.3): one zsh file,
   absolute paths, output redirected to a stage-A log in the p27 harness.

Gates:

- Build RC=0 AND the built artifact exists (`ls` the `_build` path;
  BUILD-SPEC-P26.md:129-130).
- `git diff --name-only <P27SHA>` lists EXACTLY `lib/assurance/state_predicates.mli`;
  `git diff <P27SHA>` shows ONE hunk, pure additions, all after :960.
- Coordinates hold: :97-115, :861, and :935-960 byte-identical to `<P27SHA>`
  (the single-hunk check above proves it; re-run the rg anchors of section 0.0
  as the belt-and-braces check).
- Novelty re-run diffs against the captured baseline: ONLY the sanctioned delta
  (section 0.2), with every new hit ENUMERATED MEASURED in the stage-A log.
  PREDICTED: 3 hits, all in state_predicates.mli at lines > 960.
- Still 86 exes; test/dune untouched (`git diff <P27SHA> -- test/` is EMPTY).

### Stage B: intentionally EMPTY

P27 lands no stage B artifact. NO new exe, NO new pin, NO test edit. Why:

- The ruling ships documentation only (RULING-P27-SELECTION.md:14,:85-87); the
  regression signal for :197/:246 already exists in committed form in
  test/t_p26_pins.ml (:514-517,:542-544,:555-559; RULING-P27-SELECTION.md:38-40).
- A new pin exe or a lib-side evaluator would collide with the novelty gate
  (RULING-P27-SELECTION.md:112-114) and with the frozen roster (section 7).
- The suite count stays 86 (BUILD-SPEC-P26.md:589-590); test/dune is untouched.

The empty stage keeps the A/B/C lettering parallel with P26, so cross-phase
citations stay aligned.

### Stage C: forced battery and phase-close checks

- Forced full battery green, 86/86 exes (`--force`; read the `N failures!`
  summary line; no `-q`). Output to a stage-C log in the p27 harness.
- LEG2/LEG3 guards UNCHANGED: P27 makes zero test-file edits, so
  leg3_case_counts and every guard row stay byte-identical (the
  BUILD-SPEC-P26.md:458 row is P26 history, not P27 work). A LEG red is a REAL
  FINDING, never weakened.
- Novelty re-diff against the captured baseline: the delta must be byte-identical
  to the stage-A delta (same 3 enumerated hits, PREDICTED).
- Frozen-roster byte check: `git diff --name-only <P27SHA>` still lists exactly
  the one mli path, so every section 7 roster file is byte-identical to
  `<P27SHA>`; the frozen coordinates inside the one modified file are proven by
  the single-hunk-after-:960 check.
- Print the proposed commit message to
  `/Users/oobi/Documents/anvil-ocaml-p27-harness/commit-message-p27.txt`. The
  user stages and commits; this spec stays untracked until the user stages it at
  commit time.

### Seal (appended at seal time; do not write it now)

The seal section is appended when the phase closes (section 9 placeholder). It
must reconcile every PREDICTED figure in this spec against the phase's own
measurements (the P25 section 0.3 rule carried by BUILD-SPEC-P26.md:438-443):
the 3-hit novelty enumeration, the 86/86 battery, the zero-findings prediction,
and the agent usage. It must re-run the novelty gate and the frozen-roster byte
check against `<P27SHA>`.

## 6. Blast table

Exactly ONE tracked repo file changes in P27. Any second tracked-file change is a
phase-STOP.

| file:line | change | stage |
| --- | --- | --- |
| lib/assurance/state_predicates.mli (APPEND after :960, end of file) | the section 2 note, one plain `(* ... *)` comment block, prose only, no `let` | A |
| lib/checker/BUILD-SPEC-P27.md (NEW, UNTRACKED, never staged this phase) | this file | pre-A |

### 6.1 Placement ground

The exclusion block sits at mli:97-115, ABOVE the frozen battery coordinate at
:861; inserting lines there moves the coordinate, and a moved pin is a phase-STOP
(RULING-P27-SELECTION.md:110-111; BUILD-SPEC-P26.md:462-474 records the same
resolution for the P26 note). The end-of-file append preserves every frozen
coordinate; it is the P22/P24 append-only correction convention that
BUILD-SPEC-P26.md:467-471 records and the P26 block restates at
state_predicates.mli:951-955.

## 7. Frozen-pin roster (phase-STOP on any motion)

Carried VERBATIM from BUILD-SPEC-P26.md section 7 (:476-503), which copied
RULING-P26-SELECTION.md:140-163:

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

P27 addenda, binding this phase:

- test/t_p26_pins.ml is UNTOUCHED this phase (RULING-P27-SELECTION.md:38-40).
- fault_check.ml:37-145 is never edited (roster bullet above; carried).
- pod_filter (v_stateful_set_reconciler.ml:421-432) and objects_to_pods
  (:461-463) are never mutated in place. These are the LIVE coordinates; the P26
  review finding 4 fixed a swap of the two names (BUILD-SPEC-P26.md:556-559).
- NO test file changes at all in P27. The only sanctioned edit is the section 2
  mli append. P26's "pins land in the exclusion block" clause carried the section
  6.1 placement deviation; P27 inherits the same resolution (end-of-file append).

## 8. Deferred-to-P28+ ledger

Carried from the RULING-P27-SELECTION.md deferred table (:120-132), adjusted for
the two P27 ship items:

| item | status | ground |
| --- | --- | --- |
| Red-capability trials for the six pending conjuncts (:198, :199, :215-221, :223-228, :233, :244) | DEFERRED to P28+, mutant families NAMED [PREDICTED scoping, one family per trial] | too-short-pvcs mutant for :199/:233/:244; metadata-corruption mutant for :215-221; pvc-name-templating mutant for :223-228 (RULING-P27-SELECTION.md:45-49,:125). One site per trial; saved pre-edit bytes in the p27+ harness dirs only; violating=0 in both P26 probe trials is the MEASURED ground for the deferral |
| FAIR/CRASH re-measurement of :197/:246 | DEFERRED | probes ran on L0v only (t_p26_pins.ml:60-73); promotion to committed FAIR/CRASH gating is the same moved-pin plus novelty-gate collision as full promotion (RULING-P27-SELECTION.md:126) |
| Guarantee-side :133-180 register / :522 | BLOCKED | violating=0 everywhere on both multi-CR graphs; G2 :581 premise=0 on both; needs a graph that can distinguish the register; the quad pins sit in t_p26_pins.ml, so the P26 commit (this phase's precondition) unblocks only the pin dependency, not the missing graph; cost M (RULING-P27-SELECTION.md:127) |
| Resp-triad :666+ preservation lemma | DEFER-AGAIN | proof fn over (s,s') pairs; no transition-shaped OCaml register exists; port cost L, argued-only on shape (RULING-P27-SELECTION.md:128) |
| Second-controller seed (other-controller rely :32-55/:92-129) | DEFER-AGAIN | vacuous by construction: scenario.ml:28 controller_id=0 and scenario.ml:68 single-entry Imap; no controller-count constructor (scenario.mli:304-359); rely port cost L (RULING-P27-SELECTION.md:129) |
| Item 1a foreign-sourced pending request | DEFER-AGAIN | lib/cluster/message.ml:175-179 stamps Controller src unconditionally; a new seed moves the shared graphs and forces re-measurement of a >=30-site pin floor across 5 files; cost L (RULING-P27-SELECTION.md:130) |
| Item 5 outdated pipeline (liveness/state_predicates.rs:773-856) | DEFER-AGAIN | After_delete_outdated occupancy 0/0/0/0 on all shipped graphs vs positive control Delete_outdated 8/76/64/1272; needs a template-stale-pod seed, graph-moving per the U4 phase-owner rule; cost M (RULING-P27-SELECTION.md:131) |
| Full promotion of all 8 vct:true conjuncts (scout option 2) | REJECTED for P27 | only :197/:246 have measured kills; full promotion needs an in-place edit above the frozen :861 coordinate (phase-STOP) and a lib-side evaluator (forbidden); cost L (RULING-P27-SELECTION.md:124) |

## 9. SEAL (2026-08-08, phase close)

### 9.1 Stage outcomes [MEASURED]

- `<P27SHA>` = d1fd7da0ac65503b9561ab981081ea02d771f000. The section 0.0 gate
  passed in full before any edit (p27-stageA-gates.log).
- Stage A: the section 2 note landed as ONE pure-addition hunk
  (`@@ -958,3 +958,35 @@`, numstat 32/0), block state_predicates.mli:962-992;
  build RC=0; 86 exes present (p27-stageA-build.log).
- Stage B: EMPTY, as section 5 plans.
- Stage C: forced full battery 86/86 green, ZERO `failures!` summary lines;
  reconcile_driver (LEG gates, log:118) and p26_pins (log:1097) both ran green
  (p27-stageC-forced-battery.log; p27-stageC-gates.log).
- Novelty gate: the 19-hit baseline is byte-identical to the P26 capture. After
  the append: exactly 3 sanctioned additions, state_predicates.mli:969, :972,
  :981, all inside the :962-992 block; none binds code. The gate form is a
  sorted set-diff because rg emits nondeterministic file order across runs
  (measured note, p27-stageA-gates.log).

### 9.2 Findings ledger (bound 2; PREDICTED zero new; MEASURED 2, at the bound)

- FS6, FS13, FS14 (carried from BUILD-SPEC-P26.md:554-555): CLOSED per
  section 3.
- NEW finding 1 (LOW, review wave, CONFIRMED): the stage-A gate log header said
  "no mutation windows in P27" while the three FS probe windows ran in the P27
  SELECTION WAVE; the old section 4 wording carried the same conflation. FIXED
  in place: the log header and section 4 now say stages A-C ran zero windows
  and name the selection-wave trials. No gate result was invalidated: the
  windows were closed and restored cmp-identical before stage A
  (p27-trial-final-green.log:16-17,:33-34).
- NEW finding 2 (MED, review wave, CONFIRMED): sections 1.2 and 3 and the
  draft commit message said each FS mutant reddened EXACTLY its own row. The
  14 rows run in ONE Alcotest case that stops at the first red row, so full
  selectivity is evidenced only for the FS14 trial, and `1 failure!` counts
  CASES, not rows. FIXED in place: sections 1.2 and 3 and the commit message
  now claim red-capability only and disclose the stop-at-first-red limitation.
  The section 3 closure stands: red-capability is what it closes.
- Session ledger after this phase: 5 pre-build + 2 review = 7 of the 7-finding
  session bound.

### 9.3 Seal gates re-run [MEASURED]

- Novelty: p27-seal-novelty-rerun.txt (22 lines, RG-RC=0). Sorted set-diff vs
  the baseline = the same 3 sanctioned additions only. Sorted diff vs the
  stage-C rerun = EMPTY (RC=0).
- Frozen roster: `git diff --name-only d1fd7da` = exactly
  lib/assurance/state_predicates.mli; `status --porcelain` adds only this
  untracked spec; the mli is still 992 lines.
- Review-wave integrity: both PRE-REVIEW byte snapshots cmp RC=0 against the
  live files. The wave ran 4 read-only safe-run-auditor agents; zero errors;
  35 clean checks (workflow wf_90daa8b0-c2c).
- The section 9.2 fixes touch ONLY this untracked spec, one harness log, and
  the commit-message draft. No tracked file moved after stage C, so the
  stage-C battery result stands.

### 9.4 Prediction reconciliation (P25 section 0.3 rule)

- Baseline: PREDICTED 19 hits over 3 files -> MEASURED byte-identical to the
  P26 capture. MATCH.
- Novelty delta: PREDICTED 3 hits at mli lines > 960 -> MEASURED 3
  (:969, :972, :981). MATCH.
- Battery: PREDICTED 86/86 -> MEASURED 86/86, zero failure summaries. MATCH.
- New findings: PREDICTED zero -> MEASURED 2 (both prose overclaims in the
  phase's own records; both CONFIRMED by the refuter; both fixed in place;
  neither touches the mli note or any tracked code). MISS, reconciled in
  section 9.2.
- Deviation log: (a) rg output order is nondeterministic across runs; the gate
  form is a sorted set-diff (stage A note). (b) The stage-A log first wrote
  the block range as :962-993; recomputed to :962-992 before the commit
  message. (c) The first seal-gate run hit "permission denied" on
  capture-novelty-p27.zsh (lost execute bit) and produced NO rerun file, so
  its diffs were vacuous; detected, re-run via `zsh <script>`, figures above
  are from the real run.
- Agent usage: selection + design waves ~8, review wave 4; well under the
  56-agent session bound.

SEALED 2026-08-08. The phase is CLOSED. The user stages
lib/assurance/state_predicates.mli plus this file and commits with
`git commit -s` and the message in
anvil-ocaml-p27-harness/commit-message-p27.txt. The agent never commits.

---

*Written by the P27 design wave's spec writer, 2026-08-08, against 560d89e plus
the staged P26 diff (index equals worktree at selection,
RULING-P27-SELECTION.md:3-8). Sources: RULING-P27-SELECTION.md (authoritative
pick, read in full); BUILD-SPEC-P26.md (house shape and frozen precedent);
state_predicates.mli:930-960 (append-block format, read this session); fresh log
line re-reads marked in section 0.1. Never commit for the user. This file stays
UNTRACKED; the user stages it at commit time.*

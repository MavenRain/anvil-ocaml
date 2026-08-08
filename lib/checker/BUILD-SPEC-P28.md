# BUILD-SPEC-P28: the probe-confirmation note for :199/:215-221/:223-228/:244, a DOC-ONLY phase

## 0. Phase identity, bounds, and baseline

Repo: `/Users/oobi/Documents/anvil-ocaml`. Selection: RULING-P28-SELECTION.md,
2026-08-08 (scout + adversarial refuter + three family probe trials,
`/Users/oobi/Documents/anvil-ocaml-p28-harness/`). Prior-phase evidence:
`/Users/oobi/Documents/anvil-ocaml-p27-harness/` (read-only). Direct structural
precedent: lib/checker/BUILD-SPEC-P27.md, also a doc-only phase; this spec
mirrors its section skeleton.

**P28 ships ONE item, NO new seed, NO pin moved, NO lib-side evaluator, NO new
exe, NO test edit** (RULING-P28-SELECTION.md:43-54):

1. **PROBE-CONFIRMATION NOTE.** One append-only note in
   `lib/assurance/state_predicates.mli` reclassifies :199, :215-221, :223-228,
   and :244 as PROBE-CONFIRMED red-capable on the committed L0v graph and
   records :198 and :233 as RED-CAPABILITY-PENDING with named grounds. Grounds
   in section 1; the exact note text in section 2.

There is NO second item. The probe trials already ran in the P28 selection
wave; no trial runs in the build stages (RULING-P28-SELECTION.md:13-28).

Phase bounds, recorded: the phase ledger is 7 findings and 56 agents. Consumed
at spec-writing time: 0 of 7 findings; about 5 of 56 agents (about 2 at
selection, RULING-P28-SELECTION.md:9, plus 3 in this design wave). PREDICTED
findings consumption for P28 itself: ZERO. Section 3 holds the ledger.

This file is NEW and stays UNTRACKED through the whole phase. Never stage it
during the phase. At commit time the user stages it TOGETHER WITH the mli
(section 6; the P27 omission must not repeat). Never stage, commit, or push
anything in P28; print proposed commit messages for the user.

### 0.0 HARD PRECONDITION: SATISFIED and MEASURED this session

The RULING-P28-SELECTION.md:58-63 hard gate required the P27-spec follow-up
commit to land before stage A. That gate is SATISFIED, MEASURED this session,
not assumed:

- `git -C /Users/oobi/Documents/anvil-ocaml log --oneline -1` printed
  `20e6161 P27 spec: add BUILD-SPEC-P27.md omitted from c0858ba` [MEASURED
  this session].
- `git -C /Users/oobi/Documents/anvil-ocaml status --short` printed NOTHING:
  the tree is clean and the index is empty [MEASURED this session, before this
  spec file existed].
- `<P28SHA>` = 20e6161. The ruling's rider clause (commit declined) is MOOT.

Stage A still re-verifies, in order, before any edit:

1. HEAD is still 20e6161: `git -C /Users/oobi/Documents/anvil-ocaml rev-parse
   HEAD`. Write the result into the stage-A log. A different SHA is a STOP.
2. Clean tree: `git -C /Users/oobi/Documents/anvil-ocaml status --porcelain
   -uno` prints NOTHING, and the full `--porcelain` output lists AT MOST the
   single untracked row `?? lib/checker/BUILD-SPEC-P28.md` (this spec is the
   one sanctioned untracked file). Anything else is a STOP.
3. Re-verify the key coordinates against the live tree:
   - `wc -l lib/assurance/state_predicates.mli` = 992 [MEASURED this session
     at 20e6161; the live tail is line 992].
   - The P27 append block occupies state_predicates.mli:962-992: the title
     line `==== P27 split promotion note` sits at :962 and the closing `*)`
     at :992 [MEASURED this session, block read in full].
   - The exclusion block sits at state_predicates.mli:97-115 and the frozen
     battery coordinate at state_predicates.mli:861: re-verify by `rg -n` on
     the anchor strings (the BUILD-SPEC-P26.md:401-403 stage-A gate pattern)
     [both anchors re-read this session].
   - Any drift in any of these coordinates is a phase-STOP, not a re-aim.

### 0.1 Measured grounds

Every number in this spec traces to one of these sources. Copy numbers. Never
recompute them.

| number | value | source line | tag |
| --- | --- | --- | --- |
| :199 violating, trial A ml:495 mutant | 8, of premise 16 | p28-trial-A495-mutant.log:13 | MEASURED, line re-read this session |
| :244 violating, trial A ml:495 mutant | 8, of premise 40 | p28-trial-A495-mutant.log:17 | MEASURED, line re-read this session |
| trial A premise side effects | :197/:198/:215-221 80->48; :223-228 40->48; :246 8->0 | p28-trial-A495-mutant.log:11,:12,:14,:15,:18 | MEASURED, lines re-read this session |
| trial A graph shift | L0v states_seen 92 (expect 116); blanket occupancy 48 (expect 80) | p28-trial-A495-mutant.log:8,:10 | MEASURED, lines re-read this session |
| trial A failure count | 11 failures! of 27, RC=1 | RULING-P28-SELECTION.md:21 | MEASURED at selection; log tail not re-read |
| :215-221 violating, trial B ml:287 mutant | 80, of premise 80 | p28-trial-B287-mutant.log:14 | MEASURED, line re-read this session |
| trial B collateral | ZERO: every other conjunct premise MATCH, violating=0 | p28-trial-B287-mutant.log:11-19 | MEASURED, lines re-read this session |
| :223-228 violating, trial C ml:282 mutant | 40, of premise 40 | p28-trial-C282-mutant.log:15 | MEASURED, line re-read this session |
| trial C collateral | ZERO: every other conjunct premise MATCH, violating=0 | p28-trial-C282-mutant.log:11-19 | MEASURED, lines re-read this session |
| :233 under trial A | premise=8 MATCH, violating=0 | p28-trial-A495-mutant.log:16 | MEASURED, line re-read this session |
| build guards, each trial | BUILD-RC=0; BUILD-SOURCE-COPY matches worktree | each mutant log:1,:3 | MEASURED, lines re-read this session |
| final green control | `Test Successful in 0.010s. 27 tests run.`; RUNNER-RC=0 | p28-trial-final-green.log:100,:101 | MEASURED, lines re-read this session |
| restores | cmp byte-identical vs PRE-TRIAL-{A,B,C}-v_stateful_set_reconciler.ml.bytes; `git diff --name-only` EMPTY after | RULING-P28-SELECTION.md:25-28 | MEASURED at selection |
| L0v battery size | 116 states | t_p26_pins.ml:60-73; p28-trial-final-green.log:8 | MEASURED, green-log line re-read this session |
| pvc_cnt on L0v | 1 (single-entry volume_claim_templates) | lib/assurance/scenario.ml:240-241; p28-trial-final-green.log:9 | MEASURED, both cites re-read this session |
| FAIR / CRASH battery sizes | 8580 / 10552 states | p28-trial-final-green.log:22,:24 | MEASURED, lines re-read this session |
| suite exe count | 86 | BUILD-SPEC-P27.md:501 (stage C measured 86/86) | MEASURED prior phase |
| P27 seal novelty hit set | 22 lines (19-line P26 baseline + 3 P27 additions at mli :969,:972,:981) | BUILD-SPEC-P27.md:504-508,:533-535 | MEASURED prior phase, at d1fd7da |
| mli length at baseline | 992 lines | `wc -l lib/assurance/state_predicates.mli` | MEASURED this session |
| new novelty hits from the section 2 note | 10 lines, all > :992 | section 0.2 enumeration; regex applied to the drafted note this session | PREDICTED for stage A; MEASURED enumeration at stage A governs |
| mli length after the append | 1038 lines (992 + 1 blank + 45 note lines) | section 2 | PREDICTED |

Values carried from the RULING or from prior-phase logs are EXPECTED
REPRODUCTION TARGETS for the gates that re-touch them. P28 adds no new
measurement of its own except the novelty-hit enumeration and the stage C
battery.

### 0.2 The novelty gate (capture BEFORE stage A; every stage and the seal diff against it)

No new lib-side evaluator of the 8 excluded conjuncts may appear
(RULING-P28-SELECTION.md:51-52). The gate command, VERBATIM from
BUILD-SPEC-P27.md:105:

```
rg -n 'state_predicates\.rs:(197|198|199|215|223|233|244|246)|:197 |:198 |:199 |:215-221|:223-228|:233 |:244 |:246 ' lib -g '!*.md'
```

Capture the baseline ONCE, after the section 0.0 stage-A re-check passes and
BEFORE any stage-A edit: run the command verbatim from the repo root
`/Users/oobi/Documents/anvil-ocaml` and write its FULL output to
`/Users/oobi/Documents/anvil-ocaml-p28-harness/novelty-gate-baseline-<P28SHA>.txt`,
with `<P28SHA>` the SHA recorded in section 0.0 (20e6161). That captured file
IS the baseline. The stage-A re-run, the stage-C re-run, and the seal re-run
must each be diffed against that file as a SORTED SET-DIFF: rg emits
nondeterministic file order across runs (the P27 seal note,
BUILD-SPEC-P27.md:506-508).

PREDICTED baseline content: the same 22-line hit set that the P27 seal re-run
measured at d1fd7da (19-line P26 baseline + the 3 P27 additions at mli :969,
:972, :981; BUILD-SPEC-P27.md:533-535), with unchanged line numbers. Grounds:
commit 20e6161 adds only lib/checker/BUILD-SPEC-P27.md, a .md file the gate
command excludes via `-g '!*.md'`. A baseline that differs from this
prediction is a stop-and-investigate BEFORE any edit. The captured file, not
this prose, is what every gate diffs against; do NOT gate on a hand-written
line list.

The ONLY sanctioned delta, at every re-run: ADDITIONS confined to the NEW P28
append block in `lib/assurance/state_predicates.mli` at lines GREATER THAN
992. The section 2 note names the conjunct coordinates on purpose, so new hits
are EXPECTED. This spec file itself is exempt from the gate: the command
carries `-g '!*.md'`.

PREDICTED new hits if the section 2 text is pasted verbatim: exactly 10 hit
lines. The enumeration below comes from applying the gate regex to the drafted
note text this session (note-relative line -> predicted mli line; the block
starts at mli :994, so mli line = 993 + note line). Alternation care: the
tokens `:197 `, `:198 `, `:199 `, `:233 `, `:244 `, `:246 ` each require a
trailing space; `:215-221` and `:223-228` match bare.

| note line | predicted mli line | matching token(s) | fragment |
| --- | --- | --- | --- |
| 12 | :1005 | `:199 ` | `... inclusive): :199 measured` |
| 13 | :1006 | `:244 ` | `... and :244 measured violating=8 ...` |
| 15 | :1008 | `:215-221`, `:223-228` | `(:197/:198/:215-221 80->48, :223-228` |
| 16 | :1009 | `:246 ` | `40->48, :246 8->0), a disclosed ...` |
| 18 | :1011 | `:215-221` | `:215-221 measured violating=80 ...` |
| 22 | :1015 | `:223-228` | `[ord + 1]): :223-228 measured ...` |
| 27 | :1020 | `:198 ` | `- :198 (pvcs.len = pvc_cnt) needs ...` |
| 32 | :1025 | `:233 ` | `- :233 (AfterCreatePVC => idx>0) ...` |
| 34 | :1027 | `:246 ` | `:197/:246 probe site (one site ...` |
| 36 | :1029 | `:233 ` | `Whether :233 is unkillable-without-the-banned-site ...` |

All other coordinate mentions in the note carry a slash, a comma, a period, a
parenthesis, or a log-name suffix the pattern does not match. At each re-run,
enumerate every new hit MEASURED into the stage log: file, line number, and
the containing block. Any new hit outside the new mli block (state_predicates.mli
lines > 992), any new hit in any other file, or any hit that binds code (any
`let`) is a phase-STOP. None of the 10 predicted hit lines contains `let`
[MEASURED against the draft this session].

### 0.3 Measurement discipline

Carried from BUILD-SPEC-P27.md:135-161, unchanged:

- Builds: `opam exec --switch=anvil-ocaml -- dune build --root
  /Users/oobi/Documents/anvil-ocaml @runtest` (dune is NOT on PATH). Redirect
  output to a file. Never pipe through `tail`.
- Cached `@runtest` is vacuous. Every ship gate runs `--force`, or `dune exec`
  on the single exe.
- `dune build` exit 0 alone proves nothing. Verify the built artifact exists
  (`ls` the `_build` path) before reading a green.
- Read the Alcotest `N failures!` summary line, not the `> ` cursor line. Do
  not pass `-q`.
- Gates read the worktree. The phase diff stays UNSTAGED until commit time, so
  the stage C green is read with `git diff --name-only <P28SHA>` naming
  exactly the sanctioned mli path, not with an empty diff. At commit time,
  after the user stages BOTH blast files, `git diff --name-only` (worktree vs
  index) must print NOTHING before the staged tree is called green: gates
  validate the worktree, commits ship the index.
- Runner-script pattern, REQUIRED: a subagent's Bash cwd RESETS between
  calls. Put cd + build + run in ONE zsh file with absolute paths and execute
  that file via `zsh <script>` (a lost execute bit made a P27 seal-gate run
  vacuous, BUILD-SPEC-P27.md:560-563). The proven probe form for this repo is
  `/Users/oobi/Documents/anvil-ocaml-p28-harness/run-p28-probe.zsh`.
- Copy numbers from section 0.1. Never recompute them.
- NO mutation trial runs in P28 stages A-C, and NO probe re-runs. The probe
  evidence already exists (section 1); the three selection-wave windows are
  CLOSED (RULING-P28-SELECTION.md:71-72; this spec post-dates the final green
  control). If any step edits a compiled file other than the section 2 mli
  append, STOP.
- Mark every figure PREDICTED or MEASURED. The seal reconciles every
  prediction against the phase's own measurements.

## 1. Grounds

### 1.1 Probe confirmation of :199, :215-221, :223-228, :244 (RULING-P28-SELECTION.md:11-31)

Three named mutants reddened four of the eight excluded conjuncts, on the
committed L0v graph (116 states, t_p26_pins.ml:60-73), all figures MEASURED.
One mutation window each, serialized; saved pre-edit bytes + cp/cmp restores,
never git checkout; all three windows closed before any build-stage work.
Recipe: run-p28-probe.zsh, a byte-copy of P26's run-p26-stageC-probe.zsh
(build ONLY test/t_p26_pins.exe, stale-artifact cmp guard, judge by the
trailing Alcotest summary) (RULING-P28-SELECTION.md:13-17).

- Trial A, ml:495 (create_or_skip_pvc_helper loop-back guard; the comparison
  relaxed from strict to inclusive, `<` to `<=`): :199 violating=8 of premise
  16 (p28-trial-A495-mutant.log:13) and :244 violating=8 of premise 40
  (p28-trial-A495-mutant.log:17). DISCLOSED side effects: the mutant shifted
  the premises of other conjuncts (:197/:198/:215-221 80->48, :223-228
  40->48, :246 8->0; log:11,:12,:14,:15,:18) and the graph itself
  (states_seen 92, blanket occupancy 48; log:8,:10). 11 failures! of 27,
  RC=1 (RULING-P28-SELECTION.md:21; the premise pins red as a side effect,
  disclosed by the refuter in advance).
- Trial B, ml:287 (make_pvc record field `spec = tmpl.spec` set to
  `spec = None`): :215-221 violating=80 of premise 80
  (p28-trial-B287-mutant.log:14). ZERO collateral: every other conjunct held
  premise MATCH, violating=0 (log:11-19).
- Trial C, ml:282 (make_pvc name argument `ord` replaced by `ord + 1`):
  :223-228 violating=40 of premise 40 (p28-trial-C282-mutant.log:15). ZERO
  collateral: every other conjunct held premise MATCH, violating=0
  (log:11-19).

Site content re-verified against the live tree this session:
lib/controllers/v_stateful_set_reconciler.ml:495 is the strict `<` loop-back
guard; :287 is the `spec = tmpl.spec` record field; :282 is the
`pvc_name tmpl_name vsts_name ord` name argument.

All BUILD-RC=0, BUILD-SOURCE-COPY matches worktree (each mutant log:1,:3).
Every restore cmp byte-identical
(PRE-TRIAL-{A,B,C}-v_stateful_set_reconciler.ml.bytes). Final green control
after all restores: `Test Successful in 0.010s. 27 tests run.`, RUNNER-RC=0
(p28-trial-final-green.log:100-101); `git diff --name-only` EMPTY
(RULING-P28-SELECTION.md:25-28).

Consequences, binding:

- `test/t_p26_pins.ml` does NOT change. The committed pins stay the L0v
  regression signal.
- No lib-side evaluator of the 8 conjuncts appears; the section 0.2 novelty
  gate stays in force.
- The frozen battery coordinate at state_predicates.mli:861 does not move; a
  moved pin is a phase-STOP (RULING-P28-SELECTION.md:67-70).
- Standing caveat, carried into the section 2 note: the probes ran on L0v
  ONLY (116 states), never on the FAIR (8580-state) or CRASH (10552-state)
  batteries. Six confirmed does NOT close the octet; all eight conjuncts STAY
  EXCLUDED from committed green.

### 1.2 The two conjuncts still without a kill (RULING-P28-SELECTION.md:31-41)

- **:198 (pvcs.len = pvc_cnt)**: needs a length-INCREASING pvcs mutant
  (duplicate an entry). pvc_cnt is pinned to 1 on L0v: scenario.ml:240-241
  holds the single-entry `[ vsts_pvc_template ]` list [cite re-verified
  against the live file this session; the file is
  lib/assurance/scenario.ml]. A shortening mutant can only take 1 to 0,
  which INERTs the whole PVC step family. Different mechanism from all three
  run families; RED-CAPABILITY-PENDING with this named scoping.
- **:233 (AfterCreatePVC => idx>0)**: STRUCTURALLY BLOCKED. After_create_pvc's
  pvc_index is set only by the `state.pvc_index + 1` at ml:623 [cite
  re-verified this session], which is the banned :197/:246 probe site
  (one-site-per-trial ban on reuse). Trial A measured :233 at premise 8
  MATCH, violating=0 (p28-trial-A495-mutant.log:16). Whether :233 is
  unkillable-without-the-banned-site is a phase-owner decision, not a trial
  gap.

### 1.3 No second item

The ruling ships the documentation note and nothing else: NO pin moves, NO new
exe, NO test edit, NO lib-side evaluator; the suite stays 86 exes
(RULING-P28-SELECTION.md:51-54).

## 2. The mli append-only note (exact text, ready to paste)

Placement: APPEND after state_predicates.mli:992 (the live tail, MEASURED
today). Line 993 is a new blank separator line; the new block starts at :994
and follows the P27 block at :962-992. The build stage RE-VERIFIES the live
tail before appending (`wc -l` = 992 and the closing `*)` at :992); any drift
is a STOP. NEVER touch mli:97-115 (the exclusion block), :861 (the frozen
battery coordinate), :935-960 (the P26 block), or :962-992 (the P27 block).
Apply with the Edit tool, anchored on the final `*)` line of the P27 block;
the edit is pure addition. One plain `(* ... *)` OCaml comment block, prose
only, no `let`, in the same format as the :962-992 precedent [MEASURED this
session, block read in full].

The note text (45 lines; 43 as drafted, plus two lines added by the
APPLIED review findings P28-1/P28-2, section 3):

```
(* ==== P28 probe confirmation note (append-only; BUILD-SPEC-P28 section 2) ====

   This block reclassifies four more of the eight vct:true conjuncts that
   the EXCLUDED-WITH-A-PIN block at :97-115 above holds out as
   RED-CAPABILITY-PENDING. Four conjuncts are now PROBE-CONFIRMED
   red-capable on the committed L0v graph (116 states,
   [test/t_p26_pins.ml]:60-73), adding to the P27-confirmed :197/:246.
   Probe sites, all in [lib/controllers/v_stateful_set_reconciler.ml],
   one mutant per trial:

   - Trial A, site :495 (create_or_skip_pvc_helper loop-back guard, the
     comparison relaxed from strict to inclusive): :199 measured
     violating=8 of premise 16 and :244 measured violating=8 of premise
     40 (p28-trial-A495-mutant.log:11-19). This mutant also shifted the
     premises of other conjuncts (:197/:198/:215-221 80->48, :223-228
     40->48, :246 8->0), a disclosed side effect.
   - Trial B, site :287 (make_pvc record field [spec] set to [None]):
     :215-221 measured violating=80 of premise 80 with zero collateral;
     every other conjunct held premise MATCH, violating=0
     (p28-trial-B287-mutant.log:11-19).
   - Trial C, site :282 (make_pvc name argument [ord] replaced by
     [ord + 1]): :223-228 measured violating=40 of premise 40 with zero
     collateral (p28-trial-C282-mutant.log:11-19).

   Two conjuncts STAY at RED-CAPABILITY-PENDING:

   - :198 (pvcs.len = pvc_cnt) needs a length-INCREASING pvcs mutant:
     pvc_cnt is pinned to 1 on L0v ([lib/assurance/scenario.ml]:240-241,
     the single-entry volume_claim_templates list), so a shortening
     mutant can only take 1 to 0, which inerts the whole PVC step
     family. Different mechanism from all three run families.
   - :233 (AfterCreatePVC => idx>0) is structurally blocked: the
     After_create_pvc pvc_index is set only at ml:623, the banned
     :197/:246 probe site (one site per trial). Trial A measured :233
     at premise 8 MATCH, violating=0 (p28-trial-A495-mutant.log:16).
     Whether :233 is unkillable-without-the-banned-site is a
     phase-owner decision, not a trial gap.

   Standing caveat (P27 precedent): the probes ran on L0v only, never
   on the FAIR (8580-state) or CRASH (10552-state) batteries. All
   eight conjuncts stay EXCLUDED from committed green. The :97-115
   block, the frozen battery coordinate at :861, and the P26 and P27
   blocks above are NOT edited; this note is the append-only
   correction (the P22/P24/P27 precedent). Grounds, stage gates, and
   the pending ledger: [lib/checker/BUILD-SPEC-P28.md]. *)
```

Novelty interaction: the section 0.2 table enumerates the 9 predicted hit
lines [MEASURED against this draft by running the gate regex over it this
session]. Enumerate the MEASURED hits at stage A.

## 3. Findings ledger (phase bound: 7; none consumed yet)

- Phase bounds: 7 findings, 56 agents (section 0). Consumed at spec-writing
  time: 0 of 7 findings; about 5 of 56 agents.
- Carried open findings: NONE. FS6/FS13/FS14 were closed by P27
  (BUILD-SPEC-P27.md section 9.2). The P28 selection-wave refuter findings
  were EMPTY (RULING-P28-SELECTION.md:8).
- PREDICTED new findings this phase: ZERO. Caution: P27 predicted zero and
  measured 2 (prose overclaims caught by its review wave,
  BUILD-SPEC-P27.md:510-529). The seal must reconcile this prediction with
  its own overclaim lens.
- MEASURED 2026-08-08, review wave (4 read-only finders + 1 batched
  adversarial verifier, 0 agent errors): TWO findings, both CONFIRMED,
  both qualifier omissions in the section 2 note versus
  RULING-P28-SELECTION.md:33-41. P28-1 (MED): the :233 bullet dropped
  the clause that unkillable-without-the-banned-site is a phase-owner
  decision, not a trial gap. P28-2 (LOW): the :198 bullet dropped the
  different-mechanism-from-all-three-run-families scoping. Ledger: 2 of
  7 consumed. DISPOSITION: both APPLIED 2026-08-08, before any commit;
  the section 2 note grew from 43 to 45 lines (the :233 clause adds one
  sanctioned novelty hit, predicted mli :1029), the section 2 fence and
  the live mli block stay byte-identical, and the stage A gates plus
  the stage C forced battery RE-RAN against the revised bytes (the
  second pass governs; first-pass evidence preserved in p28-stageA.log
  and p28-stageC-battery-pass1.log, both green: 9/9 predicted hits and
  BATTERY-RC=0 with zero failures! lines).
- A LEG red, a battery red, or a novelty-gate violation at any stage is a
  REAL FINDING, recorded here, never weakened.

## 4. Mutation matrix (stage C): EMPTY

Stages A-C run ZERO mutation trials and ZERO probe re-runs. P28 is doc-only:
no compiled file changes except the section 2 mli append (a comment block).
The probe evidence in section 1 came from the P28 SELECTION WAVE: three
mutation windows against lib/controllers/v_stateful_set_reconciler.ml, opened
and restored cmp-identical before this spec existed and before stage A
(RULING-P28-SELECTION.md:13-28,:71-72; p28-trial-*.log). Standing gates only:

- Forced full battery at stage C close; cached `@runtest` is vacuous, only
  `--force` counts.
- LEG2/LEG3/LEG4 watch gates keep watching. A red there is a REAL FINDING,
  never weakened.

## 5. Stage plan

### Stage A: the mli append

Order is binding:

1. Section 0.0 stage-A re-check, in full. Record `<P28SHA>` (expected
   20e6161) in the stage-A log.
2. Section 0.2 baseline capture, to
   `/Users/oobi/Documents/anvil-ocaml-p28-harness/novelty-gate-baseline-<P28SHA>.txt`.
3. Re-verify the live mli tail (section 2: `wc -l` = 992, closing `*)` at
   :992), then apply the section 2 note with the Edit tool (append-only,
   blank line at :993, block at :994-1038).
4. Build green via the runner-script pattern (section 0.3): one zsh file,
   absolute paths, output redirected to a stage-A log in the p28 harness.

Gates:

- Build RC=0 AND the built artifact exists (`ls` the `_build` path).
- `git diff --name-only <P28SHA>` lists EXACTLY
  `lib/assurance/state_predicates.mli`; `git diff <P28SHA>` shows ONE hunk,
  pure additions, all after :992.
- Frozen roster byte-stable: the :861 line and the :97-115 block are
  unchanged (the single-hunk-after-:992 check proves it; re-run the rg
  anchors of section 0.0 as the belt-and-braces check). The :962-992 P27
  block and the :935-960 P26 block are unchanged the same way.
- Novelty re-run, sorted set-diff against the captured baseline: ONLY the
  sanctioned delta (section 0.2), with every new hit ENUMERATED MEASURED in
  the stage-A log. PREDICTED: 10 hits, all in state_predicates.mli at lines
  greater than 992, matching the section 0.2 table.
- Still 86 exes; test/ untouched (`git diff <P28SHA> -- test/` is EMPTY).

### Stage B: intentionally EMPTY

P28 lands no stage B artifact. NO new exe, NO new pin, NO test edit. Ground
(P27 precedent, BUILD-SPEC-P27.md:373-385):

- The ruling ships documentation only (RULING-P28-SELECTION.md:43-54); the
  committed L0v regression signal already exists in test/t_p26_pins.ml, and
  the trial reds prove the pins catch the named mutants.
- A new pin exe or a lib-side evaluator would collide with the novelty gate
  and with the frozen roster (section 7).
- The suite count stays 86; test/dune is untouched.

The empty stage keeps the A/B/C lettering parallel with P26 and P27, so
cross-phase citations stay aligned.

### Stage C: forced battery and phase-close checks

- Forced full battery green, all 86 exes:
  `opam exec --switch=anvil-ocaml -- dune build --root
  /Users/oobi/Documents/anvil-ocaml @runtest --force`, run from the repo
  root via the runner script. Cached runs are vacuous; only `--force`
  counts. Output redirected to a stage-C log; never pipe through `tail`.
  Judge by the trailing Alcotest summaries (`N failures!` lines) and the RC.
- LEG2/LEG3/LEG4 guards UNCHANGED: P28 makes zero test-file edits. A LEG red
  is a REAL FINDING, never weakened.
- Novelty re-run, sorted set-diff against the captured baseline: the delta
  must be byte-identical to the stage-A delta (same 10 enumerated hits,
  PREDICTED).
- Frozen-roster byte check: `git diff --name-only <P28SHA>` still lists
  exactly the one mli path, so every section 7 roster file is byte-identical
  to `<P28SHA>`; the frozen coordinates inside the one modified file are
  proven by the single-hunk-after-:992 check.
- Worktree==index check at commit time: the user stages
  `lib/assurance/state_predicates.mli` AND `lib/checker/BUILD-SPEC-P28.md`
  TOGETHER; then `git diff --name-only` (worktree vs index) must print
  NOTHING before the staged tree is called green. Print the proposed commit
  message to
  `/Users/oobi/Documents/anvil-ocaml-p28-harness/commit-message-p28.txt`.
  The user commits with `git commit -s`; this agent never commits.

### Seal (appended at seal time; do not write it now)

The seal section is appended when the phase closes (section 9, not written
now). It must reconcile every PREDICTED figure in this spec against the
phase's own measurements: the 10-hit novelty enumeration, the 1038-line mli,
the 86/86 battery, the zero-findings prediction, and the agent usage. It must
re-run the novelty gate and the frozen-roster byte check against `<P28SHA>`.

## 6. Blast table

Exactly TWO paths change in P28. Any other tracked-file change is a
phase-STOP. NO pin moves, NO new exe, NO test edit; the suite stays 86.

| file:line | change | stage |
| --- | --- | --- |
| lib/assurance/state_predicates.mli (APPEND after :992, end of file; blank :993, block :994-1038) | the section 2 note, one plain `(* ... *)` comment block, prose only, no `let` | A |
| lib/checker/BUILD-SPEC-P28.md (NEW, UNTRACKED through the phase) | this file | pre-A |

Both paths are staged TOGETHER at commit time by the user. Ground: the P27
omission must not repeat. Commit c0858ba claimed BUILD-SPEC-P27.md in its
message but lacked the file; the repair landed only at 20e6161
(RULING-P28-SELECTION.md:58-63). The commit-message draft names both paths.

### 6.1 Placement ground

The exclusion block sits at mli:97-115, ABOVE the frozen battery coordinate
at :861; inserting lines there moves the coordinate, and a moved pin is a
phase-STOP (RULING-P28-SELECTION.md:67-70). The end-of-file append preserves
every frozen coordinate; it is the P22/P24 append-only correction convention
that the P26 block (:935-960) and the P27 block (:962-992) both restate. The
live tail is :992, MEASURED today; the build stage re-verifies it before
appending (section 2).

## 7. Frozen-pin roster (phase-STOP on any motion)

Carried VERBATIM from BUILD-SPEC-P27.md section 7 (:435-473), with cites
re-verified against the live tree at 20e6161 this session where marked:

- NO committed pin moves. FROZEN roster byte-stable: guarantee_cardinal 4,
  binding_cardinal 2, ledger_spec_fn_count 9, shipped
  [544;562;581;589;606;613;640], excluded [522;528] (p21_witness.ml:242-245);
  battery coordinate pins internal_guarantee.mli:232 [re-verified this
  session: the cardinal-4 pin comment], local_binding.mli:331 [re-verified
  this session: the cardinal-2 pin comment], state_predicates.mli:861
  [re-verified this session: the cardinal-2 pin comment]; LEG1 exempt
  markers; LEG2 partition-reconciliation and LEG4 0-XOR-11 cite gates keep
  watching. A red there is a REAL FINDING, never weakened. A moved pin is a
  phase-STOP.
- The exclusion block state_predicates.mli:97-115 [re-verified this session:
  the RED-CAPABILITY-PENDING ground with the eight conjuncts listed at
  :101-102] is NOT edited. The section 2 note supersedes by APPEND only.
- Never edit fault_check.ml:37-145 [re-verified this session: the file is
  lib/checker/fault_check.ml, 1292 lines, the range exists].
- pod_filter (v_stateful_set_reconciler.ml:421-432) and objects_to_pods
  (:461-463) are never mutated in place [re-verified this session:
  `let pod_filter` at :421, `let objects_to_pods` at :461].
- The three P28 probe sites are CLOSED: v_stateful_set_reconciler.ml:495
  (trial A), :287 (trial B), :282 (trial C). Windows closed, restores
  cmp-verified byte-identical, final green control passed before this spec
  existed (RULING-P28-SELECTION.md:25-28,:71-72). Site content re-verified
  this session (section 1.1). No P28 stage reopens them.
- ml:623 stays the banned :197/:246 skew site (one-site-per-trial ban on
  reuse; RULING-P28-SELECTION.md:37-41) [re-verified this session:
  `pvc_index = state.pvc_index + 1` at :623].
- test/t_p26_pins.ml is UNTOUCHED this phase. NO test file changes at all.
  The only sanctioned edit is the section 2 mli append.
- The forged-state rows stay seed-free/bound-free/pin-free exactly as
  state_predicates.mli:372 records; any row found to need a seed or bound is
  a phase-STOP, not an improvisation.
- Cached `@runtest` is vacuous; every ship gate runs `--force`. The novelty
  gate of section 0.2 runs before stage A, at stage A, at stage C, and at
  the seal.

## 8. Deferred-to-P29+ ledger

Carried from BUILD-SPEC-P27.md section 8 (:475-489), with the six-conjunct
row SPLIT per RULING-P28-SELECTION.md:74-81: :199, :215-221, :223-228, and
:244 move into this phase's pick (sections 1 and 2); :198 and :233 stay
deferred with named grounds. FAIR/CRASH re-measurement now covers all six
probe-confirmed conjuncts.

| item | status | ground |
| --- | --- | --- |
| :198 (pvcs.len = pvc_cnt) red-capability | DEFERRED to P29+, mechanism NAMED | needs a length-INCREASING pvcs mutant (duplicate an entry); pvc_cnt is pinned to 1 on L0v (lib/assurance/scenario.ml:240-241, re-verified this session), so a shortening mutant can only take 1 to 0, which INERTs the whole PVC step family; different mechanism from all three run families (RULING-P28-SELECTION.md:33-36) |
| :233 (AfterCreatePVC => idx>0) red-capability | DEFERRED, STRUCTURALLY BLOCKED | After_create_pvc's pvc_index is set only at ml:623, the banned :197/:246 probe site; trial A measured :233 premise 8 MATCH, violating=0 (p28-trial-A495-mutant.log:16); unkillable-without-the-banned-site is a phase-owner decision, not a trial gap (RULING-P28-SELECTION.md:37-41) |
| FAIR/CRASH re-measurement of the six probe-confirmed conjuncts (:197, :246, :199, :215-221, :223-228, :244) | DEFERRED | every probe ran on L0v only (116 states); promotion to committed FAIR/CRASH gating is the same moved-pin plus novelty-gate collision as full promotion (carried BUILD-SPEC-P27.md:483; scope widened per RULING-P28-SELECTION.md:77-78) |
| Guarantee-side :133-180 register / :522 | BLOCKED | carried, condensed from BUILD-SPEC-P27.md:484: violating=0 everywhere on both multi-CR graphs; G2 :581 premise=0 on both; needs a graph that can distinguish the register; cost M |
| Resp-triad :666+ preservation lemma | DEFER-AGAIN | carried, condensed from BUILD-SPEC-P27.md:485: proof fn over (s,s') pairs; no transition-shaped OCaml register exists; port cost L |
| Second-controller seed (other-controller rely :32-55/:92-129) | DEFER-AGAIN | carried, condensed from BUILD-SPEC-P27.md:486: vacuous by construction (scenario.ml:28 controller_id=0, scenario.ml:68 single-entry Imap; no controller-count constructor, scenario.mli:304-359); rely port cost L |
| Item 1a foreign-sourced pending request | DEFER-AGAIN | carried, condensed from BUILD-SPEC-P27.md:487: lib/cluster/message.ml:175-179 stamps Controller src unconditionally; a new seed moves the shared graphs and forces re-measurement of a >=30-site pin floor across 5 files; cost L |
| Item 5 outdated pipeline (liveness/state_predicates.rs:773-856) | DEFER-AGAIN | carried, condensed from BUILD-SPEC-P27.md:488: After_delete_outdated occupancy 0/0/0/0 on all shipped graphs vs positive control Delete_outdated 8/76/64/1272; needs a template-stale-pod seed, graph-moving per the U4 phase-owner rule; cost M |
| Full promotion of all 8 vct:true conjuncts | REJECTED again for P28 | six of eight now have measured kills, but full promotion still needs an in-place edit above the frozen :861 coordinate (phase-STOP) and a lib-side evaluator (forbidden); carried from BUILD-SPEC-P27.md:489 |

---

*Written by the P28 design wave's spec writer, 2026-08-08, against 20e6161
(main, clean tree, empty index; MEASURED this session). Sources:
RULING-P28-SELECTION.md (authoritative pick, read in full);
BUILD-SPEC-P27.md (section skeleton and register precedent, read in full);
state_predicates.mli:962-992 (append-block format, read this session);
p28-trial-{A495,B287,C282}-mutant.log:1-25 and p28-trial-final-green.log
(read this session); live-tree cite re-verification marked in sections 0.1,
1, and 7. Never commit for the user. This file stays UNTRACKED; the user
stages it at commit time together with the mli.*

## 9. SEAL (close-out, 2026-08-08, written after battery pass 2)

### 9.1 PREDICTED vs MEASURED

| Item | PREDICTED | MEASURED |
|---|---|---|
| mli line count | 1036 (design); 1038 after review fixes | 1038 |
| Diff vs 20e6161 | one hunk, pure addition after :992 | `@@ -992,0 +993,46 @@`, numstat `46 0`, only the mli |
| Novelty additions | 9 (design); 10 after review fixes | 10, all in the new block >992, includes :1029 |
| Novelty removals | 0 | 0 (22-line baseline intact) |
| Review findings | 0 | 2: P28-1 MED, P28-2 LOW, both APPLIED |
| Forced battery | green 86/86 | green 86/86, twice (pass 1 and pass 2), zero `failures!` lines |
| Findings budget | <= 7 | 2 consumed |
| Agent budget | <= 56 | approximately 10 used |

### 9.2 Battery record (includes the killed attempt)

- Pass 1: `p28-stageC-battery-pass1.log`, BATTERY-RC=0, 86 suites green. It
  attests the pre-review-fix bytes. Archived as the pass-1 attest.
- Killed attempt: `p28-stageC-battery-pass2-killed-0927.log`. The run reached
  69 of 86 suites, all green, zero failures. An external signal stopped the
  wrapper at 09:27 (session compaction). This is not a test failure.
- Pass 2 (binding): `p28-stageC-battery.log`, BATTERY-RC=0 at :1391, 86
  `Test Successful` lines, zero `failures!` lines. It ran the sealed bytes.

### 9.3 Sealed bytes

- `lib/assurance/state_predicates.mli`: md5 dc13365b9f6f7976cf7b1440922c61bf,
  67940 bytes, mtime 2026-08-08 09:24. The mtime predates battery pass 2, so
  pass 2 attests exactly these bytes.
- `lib/checker/BUILD-SPEC-P28.md`: md5 e8f85e0bdf0de4994463d955ee1c8f85,
  34235 bytes, mtime 09:25, at battery time. This section 9 was appended
  after the battery. The spec is outside the build graph (markdown, excluded
  by the novelty gate's `-g '!*.md'`), and the section-2 fence is untouched,
  so the append does not invalidate the attest. The post-append md5 lives in
  the session report, not here (a file cannot contain its own hash).

### 9.4 Seal gates (p28-seal.log, all green)

- Gate 1: battery trailer present, RC=0, zero failure lines.
- Gate 2: sealed-bytes md5s and mtimes above.
- Gate 3: novelty seal re-run, 32 lines, byte-identical to the stage-A pass-2
  re-run (cmp RC=0), zero removals vs the 22-line baseline.
- Gate 4: blast radius exact: worktree diff vs 20e6161 is only the mli,
  numstat `46 0`, one hunk. Index empty (nothing staged during the phase).
  Porcelain shows ` M` mli plus `?? BUILD-SPEC-P28.md`. NOTE: the gate
  script's expectation string ("only ?? BUILD-SPEC-P28.md") was stale, copied
  from the pre-append pre-check. The measured porcelain is the correct sealed
  state. The real invariants hold: no other path is dirty, the index is empty.
- Gate 5: frozen anchors hold: MLI-WC=1038, cardinal-2 pin at :861, exclusion
  block hit at :97, anchor :992 unchanged.

### 9.5 Commit instruction (user action; never done by the assistant)

- Stage BOTH paths together: `lib/assurance/state_predicates.mli` AND
  `lib/checker/BUILD-SPEC-P28.md` (do not repeat the P27 omission).
- Verify worktree == index after staging (`git diff --name-only` empty).
- Commit with `git commit -s` and the message in
  `~/Documents/anvil-ocaml-p28-harness/commit-message-p28.txt`.

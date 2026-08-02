# BUILD-SPEC-P24: the state-predicate register (`liveness/state_predicates.rs`, the first member from the P24/P25 bank)

Phase 24 of the port. Follows P23 (controller-local binding register, sealed at
`834e272`). Branch: `p24-state-predicates` off `834e272`.

## 0. Provenance of this spec, stated honestly

**BOTH waves have now run, the design wave moved two of the three candidate members, and stage-B/C measurement then CUT one of the three outright (section 2.2).**
P23's precedent held: the design wave **OVERTURNED the selection wave's member
partition** (`BUILD-SPEC-P23.md:38-48` records the same thing happening one phase
back). Sections 2-5 below are no longer a sketch - they are the settled ruling.
The full ruling, with every citation and both forks of every open gate, is
`~/Documents/anvil-ocaml-p24-harness/RULING.md`; sections 2-5 here are its
operative summary and do not restate its evidence tables.

- **Phase-selection wave** - run 2026-07-31, run id `wf_4c59ff83-801`,
  `agentCount = 10` (NINE scouts plus one judge), `scoutsExpected = 9`,
  `scoutsReturned = 9`, **`agents_error` 0, `agents_empty_result` 0**,
  802,728 subagent tokens, 294 tool calls, 1,052 s wall.
  Scout keys: `A-statepred-feasibility`, `B-statepred-nonvacuity`,
  `C-structural-leg-revived`, `D-e3-lift-devacuization`, `E-candidate-c-mc2`,
  `F-upstream-census`, `G-conventions-and-pins`,
  `H-review-and-reconciliation-debt`, `I-cost-and-blowup`.
  Durable copies (NOT in `/private/tmp`, which gets reaped mid-session):
  `~/Documents/anvil-ocaml-p24-harness/selection-wave-wf_4c59ff83-801.json` and
  `selection-wave-journal.jsonl`. The judge's `pick` / `pickRationale` /
  `rejected` / `staleBlockersRetired` / `contradictions` / `preconditions` /
  `redCapability` / `pinSafety` / `deferredToP25` fields are the source for
  sections 1, 2, 4, 5 and 7 and are transcribed here, not re-litigated.
- **Main-loop verification (this author, 2026-07-31).** Baseline established
  before any wave ran: see section 0.1. The multi-CR correction in section 1 was
  found in the main loop and handed to the scouts as ground truth.
- **Design-settlement wave** - run 2026-07-31, run id `wf_1ffb9959-411`,
  `agentCount = 14`, 968,802 subagent tokens, 1,345 s wall. All SEVEN settle
  agents returned (`A-m1-conjunct-partition`, `B-m2-overclaim-gate`,
  `C-m3-and-weakly-eq`, `D-leg-and-witness-shape`, `E-vacuity-and-red-capability`,
  `F-doc-debt-and-reconciliation`, `G-pin-safety-and-blast-radius`), and
  `refute-overclaim` returned 14 verdicts. **`agents_error` 6: `refute-vacuity`
  x2, `refute-mechanics` x2, and `judge-settled-ruling` x2, every one on
  "You've hit your session limit - resets 12:10pm (America/Vancouver)". The
  workflow therefore returned `ruling: null`.** Per the house rule that a
  quota-choked wave does not fail safe, the judge was NOT re-spawned: the ruling
  below was issued INLINE by the main loop from the salvaged journal, at
  2026-07-31 09:08 PDT, three hours before the quota reset.
  Durable salvage (NOT `/private/tmp`, which gets reaped):
  `~/Documents/anvil-ocaml-p24-harness/RULING.md`,
  `DESIGN-WAVE-DIGEST.md`, `DESIGN-WAVE-REFUTE.md`,
  `design-wave-journal-wf_1ffb9959-411.jsonl`, `design-wave-salvage/*.json`.
- **CAVEAT ON THE REFUTER.** `refute-overclaim`'s task notification carried "the
  safety classifier was unavailable when reviewing this subagent's work." Every
  refute verdict the ruling leans on (C5, C6, C14, C15, C19, C21, C22) was
  re-checked against a cited `file:line` before adoption. Verdicts adopted are
  named as such in `RULING.md`; none was taken on the refuter's authority alone.

### 0.1 Baseline, MEASURED before anything was touched

- HEAD `834e272683a05d830b8a39fc0cb8f6f98d25391f` (2026-07-31T04:34:13-07:00),
  `git status --porcelain` = 0 lines, tree CLEAN at phase start.
- **`dune` IS NOT ON PATH.** The switch is a named opam switch. Use
  `opam exec --switch=anvil-ocaml -- dune build @default` (and `@runtest`) from
  the repo root. This session produced TWO FAKE GREENS before the switch was
  found: `dune build ... | tail -20; echo $?` reports the exit code of `tail`,
  so a `command not found` reads as `RC=0`. Confirm dune actually emitted output.
- `@default` GREEN. One pre-existing warning, `lib/cluster/erase.mli:46`
  Warning 67 unused functor parameter `C`.
- `@runtest` GREEN, `RC=0`: **79 test executables, 547 Alcotest cases, 0
  failures.** Full log and per-suite table in the harness dir.
- Row that confirms a P23 correction: `p22_scaledown` runs **7** cases, so
  `BUILD-SPEC-P22.md`'s recorded "6/6" was indeed stale
  (`BUILD-SPEC-P23.md:787-790`).

### 0.2 What the SHIPPED tree is, as of the reconciliation pass

Sections 2-5 below were written as a settled RULING, before stages A/B/C ran.
They are kept as the ruling, with every place the shipped tree DIVERGES from
them marked in-line. The five divergences, in one place so nothing has to be
reconstructed from the prose:

1. **M1 is 14 PORT / 9 EXCLUDE-WITH-A-PIN, not 15 / 8** - `:241` was discharged
   by stage B's step histogram and moved to EXCLUDE (2.1). SEVEN of the nine die
   on the PVC pin; `:246` and `:241` share a REACHABILITY ground.
2. **M2 IS CUT. The family cardinal is 2, not 3** (2.2, rewritten as the
   phase's NEGATIVE RESULT; section 0.4 below states the gate defect). `:65`
   measured ENTAILED by the port's own rendering premise, so `M2b'` was STRUCK
   (P8); `:49`, the one conjunct P23's L2 does not carry, measured **UNWITNESSED
   - complement 0 on all four graphs over denominators 16/112/288/1560** (P7',
   pinned as `pending_src_not_controller_everywhere`); and `M2a'`, which did red
   the leg with P23's green, reds by **falsifying the conjunct on the entire
   premise population**, so it does not discriminate. With `:49` unwitnessed and
   `:65` entailed, the remaining five conjuncts ARE L2 and the member buys
   nothing.
3. **M3's etcd fork resolved NON-ZERO**, so both etcd-consuming conjuncts
   shipped and `weakly_eq` was written (2.3) - and the leg was then **REFUTED on
   BLc and BLm** (P9).
4. **THE MAIN LOOP RULED ON THAT REFUTATION: `:116-118` and `:119-124` are
   EXCLUDED-WITH-A-PIN on a SCOPE ground** (2.3, and section 0.3 below). M3
   ships its **SEVEN pure-shape conjuncts**; `weakly_eq`, `owned_objs`,
   `valid_owned_object`, `etcd_valid_owned_refs` and `ref_set_equal` are removed
   as dead code; the refutation itself is PINNED, in full, as probe B5. The
   phase now has **ELEVEN exclusions on THREE grounds** - SHAPE (7), REACHABILITY
   (2), SCOPE (2).
5. **The two probe complements were tautologies and were repaired** (5.0.1), and
   the repair added the phase's SECOND vacuity literal
   (`ok_resp_some_unowned_obj_everywhere = 0`, the owner-ref filter's
   never-observed reject path). The B4 repair is what made the THIRD one
   assertable: `pending_src_not_controller_everywhere = 0`, the zero the M2 cut
   rests on. With the B5 pins, `p24_witness.ml` now carries **three** vacuity
   literals and the SCOPE-EXCLUSION group.
6. **THE PHASE'S PER-CONJUNCT COVERAGE IS FOUR SITES OUT OF TWENTY-TWO, MEASURED
   BY DELETION** (0.5, measured after the seal wave, the phase's headline
   coverage result). Only M1 `:200-204`, M1 `:205-214`, M3 `:115` and M3
   `:129-130` redden anything when they are removed; the other eighteen sites are
   green on all 82 executables with the conjunct gone. All four kills come from
   FORGED states in `t_p24_mutation` and NOT ONE from BL0/BLc/BLd/BLm. Everything
   stays SHIPPED - fidelity to upstream is why the conjuncts are there - but the
   phase may not be read as covering what it does not kill.

**Build/test state of the shipped tree.** `dune build @default` exits 0 clean and
`dune build @runtest` exits 0 clean: **all 82 executables green**, verified both
through `@runtest` and by running the executables individually.
**No committed P13-P23 pin moved.**

**P24's OWN gate counts moved when M2 was cut, and that is not a pin move.** The
gate is the OR over the register's own members' `interesting`, so dropping a
member shrinks it: `60 / 516 / 608 / 7360` where the three-member family
measured `68 / 560 / 640 / 8088`. Those are P24-MEASURED numbers, PRINTED prose,
never literals in `p24_witness.ml` and never asserted (the leg's gate is checked
against the run's own union, without a literal). The COMMITTED pins - P13-P21
76/464/744/1976/116; P22 88/808/1144/10216 with gates 20/276/96/2080; P23 gates
68/560/816/7920 and decoded 76/680/1056/8872 - are all byte-identical, before
and after the cut.

### 0.3 THE 3.3 GATE WAS UNDERSPECIFIED, AND SAYING SO IS PART OF THE RECORD

Section 2.3(3) gated the two etcd-consuming conjuncts on **one** question: is
`owned_objs` ever non-empty on the ok-list-response population? Non-zero was
read as "therefore ship". That inference was **necessary but not sufficient, and
the gate as written did not notice.** The gate asked about **VACUITY** - would
the conjunct be a green that could not have been red? - and the answer came back
**non-empty AND RED**. A non-vacuous conjunct is a conjunct worth asserting only
if upstream asserts it of the executions the leg explores, and nothing in the
gate asked that. The missing clause, stated plainly for the phases that inherit
this shape:

> A conjunct's population being non-empty licenses only that a mutation of it
> could be SEEN. It does not license asserting it. Before shipping, also ask:
> does upstream SCOPE this conjunct to an assumption the port does not model?
> If it does, non-emptiness is exactly what turns the gap into a red.

Upstream scoped it in a comment one line above the conjunct
(`state_predicates.rs:116`), which the gate did read - and quoted - without
drawing the consequence. P25 inherits the repaired gate, not the original.

### 0.4 THE 2. SHIP GATE WAS UNDERSPECIFIED IN THE SAME WAY, AND M2 IS THE COST

Section 2's gate read, verbatim:

> M2 SHIPS if and only if at least one of `M2a'` / `M2b'` is SEEN RED on the P24
> leg while the P23 local-binding leg stays GREEN in the same run. If neither
> discriminates, M2 is L2 wearing a hat and is CUT from the phase.

`M2b'` was struck as unfailable before stage C. `M2a'` was run and DID redden
the leg with P23's green in the same run, and the gate's letter therefore said
SHIP. **The gate's letter was wrong, because it never required the mutant to be
NON-TRIVIALLY falsifying.** `.src` is `Controller(controller_id, cr_key)` and
`.dst` is `Api_server` at EVERY state of the premise population, so swapping
them makes the conjunct FALSE everywhere in the premise: the leg reds by
falsification, not by separating two states. A mutant that falsifies its target
on the whole premise proves the conjunct is load-bearing FOR THE MUTANT and
nothing about whether the conjunct has content.

This is the same defect as 0.3's - a gate asking the wrong question and getting
a confident answer to it - one section earlier in the same spec. The missing
clause, stated for the phases that inherit this shape:

> A mutant reddening the leg licenses a ship only if the ORIGINAL conjunct is
> true at some states of the premise and false at others, i.e. only if the
> mutant separates the population rather than emptying it. Pair every
> discrimination mutant with a POSITIVE-CONTROL measurement of the original
> conjunct's own truth over the premise population, and read the mutant only
> after that measurement is non-degenerate.

The positive control existed - probe B4 - and it reported `src_NOT_controller`
= **0 on all four graphs**. Read in the gate's order (mutant first) that number
looked like a reassurance; read in the repaired order it is the disqualifier.
P25 inherits the repaired gate. The full finding is section 2.2.

### 0.5 THE DELETION MEASUREMENT: THE PHASE'S EARNED COVERAGE IS FOUR SITES OF TWENTY-TWO

This is the phase's headline coverage result. It carries the same weight as the
SCOPE exclusion (0.3, 2.3.1) and the M2 cut (0.4, 2.2), and it was UNMEASURED
until after the seal wave.

**A FLIP MUTANT AND A DELETION MUTANT TEST DIFFERENT THINGS, AND THIS PHASE HAD
ONLY EVER RUN FLIPS.** Flipping `Option.is_some om.name` to
`Option.is_none om.name` reds - but only because `name` is `Some` at every object
of every ok list-response on all four graphs, so the flipped conjunct is FALSE on
the whole population and the leg reds by FALSIFICATION. That shows the MUTANT is
false. It does not show the CONJUNCT contributes anything. **DELETING the conjunct
is the honest test of contribution**: if every test stays green with the conjunct
gone, the conjunct has no red capability on these graphs. The phase already CUT
its M2 candidate on exactly this reasoning (0.4: upstream `:49` measured true at
every state at which it is evaluated, so `M2a'` reddened by emptying the premise
rather than by separating it) and then never applied the same test to M1 or M3.

**METHOD.** For every conjunct M1 and M3 ship: delete just that conjunct with the
Edit tool, `dune build @default`, run all 82 test executables INDIVIDUALLY (never
`@runtest` alone - it aborts at the first failing executable), record what
reddens and which assertion names it, restore with the Edit tool, and confirm
`git diff --stat` is byte-identical to the baseline diffstat. Where plain deletion
orphans a module-level helper and the build dies on warning 32
(`unused-value-declaration`) or 27 (`unused-var-strict`) - **that is a build
error, not a measurement** - the row was RESHAPED by neutralising the conjunct in
place as `(<conjunct> || true)`, which is the same weakening
(`A && (X || true) && B` = `A && B`) with every identifier still referenced. Five
rows were reshaped and each is marked below. No assertion was relaxed, no
conjunct was deleted permanently, and the tree is byte-identical afterwards.

**THE COUNT, TAKEN FROM THE CODE RATHER THAN ADOPTED.** An audit reported 14
conjuncts for M1 and 7 for M3; those are counts of UPSTREAM conjuncts PORTED, and
the count of DELETABLE SITES is different in both directions. M1's
`local_state_is_valid` ships **14 upstream conjuncts as 16 sites**: `:195` and
`:196` each have their `>= 0` half written out separately, because the port's
cursors are `int` where upstream's are `nat`. M3's `ok_list_resp_shape` ships
**7 upstream conjuncts as 6 sites**: `:129` and `:130` are one `Option.equal`.
**22 sites, 22 rows**, plus two aggregate rows. The distinction is now
load-bearing rather than pedantic, because the `:195`/`:196` halves and the
`:129`/`:130` pair are each measured as ONE thing.

| # | site | shape | all 82 | killed by |
| --- | --- | --- | --- | --- |
| D01 | M1 `:194` `needed_len = replicas` | deleted | GREEN | - |
| D02 | M1 `:195` `needed_index >= 0` | deleted | GREEN | - |
| D03 | M1 `:195` `needed_index <= needed_len` | deleted | GREEN | - |
| D04 | M1 `:196` `condemned_index >= 0` | deleted | GREEN | - |
| D05 | M1 `:196` `condemned_index <= condemned_len` | deleted | GREEN | - |
| D06 | M1 `:200-204` the NEEDED forall | deleted | **RED 81/82** | `t_p24_mutation` / `m1_novel_conjuncts` / `M1b` - "M1 is RED when the pod named for ordinal 1 sits in needed slot ORDINAL 0" |
| D07 | M1 `:205-214` the CONDEMNED forall | deleted | **RED 81/82** | `t_p24_mutation` / `m1_novel_conjuncts` / `M1a` - "M1 is RED on a condemned entry whose ordinal is 0" |
| D08 | M1 `:230-231` | RESHAPED (`at_pvc_or_needed_step` orphaned) | GREEN | - |
| D09 | M1 `:235` | deleted | GREEN | - |
| D10 | M1 `:236` | deleted | GREEN | - |
| D11 | M1 `:237` | deleted | GREEN | - |
| D12 | M1 `:238` | deleted | GREEN | - |
| D13 | M1 `:239` | deleted | GREEN | - |
| D14 | M1 `:240` | deleted | GREEN | - |
| D15 | M1 `:242` | RESHAPED (`at_after_needed_step` orphaned) | GREEN | - |
| D16 | M1 `:248` | RESHAPED (`at_condemned_or_later_step` orphaned) | GREEN | - |
| D17 | M3 `:115` no-duplicate object refs | RESHAPED (`no_duplicate_object_refs` orphaned) | **RED 81/82** | `t_p24_mutation` / `m3_shape_conjuncts` / `M3a(:115)` |
| D18 | M3 `:126` kind is `PodKind` | deleted | GREEN | - |
| D19 | M3 `:127` unmarshals as a `Pod` | deleted | GREEN | - |
| D20 | M3 `:128` `metadata.name` is `Some` | deleted | GREEN | - |
| D21 | M3 `:129-130` namespace | RESHAPED (`~namespace` orphaned) | **RED 81/82** | `t_p24_mutation` / `m3_shape_conjuncts` / `CONTAINMENT(:129-130)` |
| D22 | M3 `:132` `objects_to_pods` is `Some` | deleted | GREEN | - |
| D23 | M1's **14 non-forall sites SIMULTANEOUSLY** | reshaped, two `\|\| true` groups | GREEN | - |
| D24 | M3 `:126` + `:127` + `:132` **TOGETHER** | deleted | **RED 81/82** | `t_p24_mutation` / `m3_shape_conjuncts` / `M3a(:126-127)` |

**WHICH CONJUNCTS HAVE RED CAPABILITY.** Exactly four sites: M1 `:200-204`, M1
`:205-214`, M3 `:115`, M3 `:129-130`. Plus **one entailment CLASS**, `{:126,
:127, :132}`, which has red capability 1 as a class and 0 per member. Everything
else - M1 `:194`, both halves of `:195`, both halves of `:196`, `:230-231`,
`:235`, `:236`, `:237`, `:238`, `:239`, `:240`, `:242`, `:248`, and M3 `:128` -
has **NO red capability anywhere in the tree**.

**AND OF THE FOUR, ONLY THREE ARE COVERAGE P24 ADDS.** `:129-130` is disclosed as
CONTAINED in P23's L2, and the row that kills its deletion is the CONTAINMENT
datum: `t_p24_mutation` asserts P23's L2 is RED on the same state. So the coverage
this phase earns OVER P23 is **M1 `:200-204`, M1 `:205-214` and M3 `:115`** -
three conjunct sites - and nothing more.

**THE TWO AUDIT CLAIMS WERE VERIFIED RATHER THAN ADOPTED, AND BOTH HOLD.**
Neutralising `:194`, both halves of `:195` and `:196`, `:230-231`, `:235`-`:240`,
`:242` and `:248` SIMULTANEOUSLY leaves all 82 green (D23), and deleting M3's
`:128` leaves all 82 green (D20). Two differences from the audit, both reported
rather than absorbed: the counts are 16 and 6 SITES against its 14 and 7 upstream
conjuncts (above), and the `{:126, :127, :132}` class result (D18/D19/D22 green
individually, D24 RED together) is new - the audit listed only `:128`.

**THE STRUCTURAL REASON, WHICH IS THE SHARPEST FORM OF THE RESULT: NOT ONE OF THE
22 DELETIONS WAS CAUGHT BY ANYTHING THE FOUR GRAPHS DRIVE.** All four kills are
`t_p24_mutation` rows on hand-FORGED states. That is not an accident of
test-writing; it is forced by the leg's shape. Deleting a conjunct WEAKENS
`holds`; this leg asserts `holds` at every reachable state of BL0/BLc/BLd/BLm and
is CLEAN on all four; and neither member's `interesting` reads its own body
(M1's is `at_valid_step`, M3's is the parked-with-a-matching-response premise).
So no graph-driven assertion in this phase can, even in principle, be reddened by
a deletion mutant - it would take an assertion that some member is RED at some
reachable state, and this phase has none for a SHIPPED conjunct (the two that
were red, `:116-118` and `:119-124`, are the SCOPE exclusion). **The four graphs
contribute ZERO deletion-kill capability to this register.** What they buy is the
leg's own greenness and the vacuity/refutation pins, which is real and is a
different thing from per-conjunct coverage. Section 2.3(1)'s "killable at GRAPH
level - no forged response needed" is therefore **REFUTED for all seven M3
conjuncts**, and 5.'s M3a row does not discharge it either (see that row).

**THEY ALL STAY SHIPPED, AND THE ZEROES ARE THE EXPECTED OBSERVATION.** Fidelity
to upstream is why these conjuncts are here. A Verus invariant is a predicate the
reconciler PRESERVES, so no state the reconciler reaches can falsify it - that is
what "invariant" means - and on a small explored graph family the expected
per-conjunct red capability is exactly zero. **This is a statement about what
BL0/BLc/BLd/BLm EXERCISE, not a defect in the port**, and it is not a licence to
delete anything: removing a conjunct upstream writes would make this register a
strictly weaker predicate than the one it cites, and the citation is the whole
point of the register.

**WHAT WOULD EXERCISE THE REST - TWO ROUTES, WHICH COST DIFFERENTLY AND MUST NOT
BE CONFLATED.**

1. **FORGED-STATE ROUTE - seed-free, moves no pin, buys kill capability but never
   graph coverage.** Add one `t_p24_mutation` row per unexercised conjunct on the
   existing `M1a`/`M1b` pattern: forge a decoded `V_stateful_set_reconciler.s` at
   a step inside `at_valid_step` that violates exactly that conjunct - `needed` of
   length `<> replicas` for `:194`, `needed_index = needed_len` at `Create_needed`
   for `:230-231`, a `Some` slot at `needed_index` at `Create_needed` for `:235`,
   `needed_index = 0` at `After_create_needed` for `:242`, `condemned_index > 0`
   at `Create_needed` for `:248`, and so on - assert M1 RED, with the
   accepted-state control asserted GREEN first. This is additive to a test file,
   touches no seed, no bound and no pin, and it would buy deletion-kill capability
   for all 14 unexercised M1 sites and for `:128`. It buys NOTHING for `{:126,
   :127, :132}`: they are mutually entailing, so no state, forged or reached,
   distinguishes any one of them from its class, and only the class is killable.
2. **GRAPH ROUTE - the only one that could ever let THESE four graphs carry the
   coverage, and it is a P25 decision.** It needs states where the invariant is
   violated by the port's OWN execution, which the reconciler never produces
   because upstream proves it preserves them. Getting one needs a NEW SEED or a
   NEW FAULT DIMENSION - a writer that corrupts the ongoing-reconcile local state,
   or the foreign-owned object `:112`'s reject path needs, or the
   foreign-sourced pending request `:49` needs. **Any of those moves
   BL0/BLc/BLd/BLm and every committed P13-P23 pin with them** (P13-P21
   76/464/744/1976/116; P22 88/808/1144/10216 with gates 20/276/96/2080; P23 gates
   68/560/816/7920 and decoded 76/680/1056/8872), and a moved pin is a phase-STOP.
   So it is NOT built here. It rides into P25 on exactly the terms `:49` and
   `:112` already ride on, and P25 must decide it deliberately rather than
   discover it.

## 1. Why this phase

**The register is unoccupied at MEMBER level and that is grep-checkable - but
the P23-recorded gate command is now BROKEN and must be repaired before it is
quoted.**

- `BUILD-SPEC-P23.md:765` records the novelty gate as
  `rg -n 'state_predicates' lib test` = exit 1. **That command now exits 0.**
  Scout A measured SIX hits, every one a self-match inside `BUILD-SPEC-P23.md`
  (`:35`, `:36`, `:762`, `:765`, `:767`, `:768`). Re-measured by this author
  after THIS file was written: **14 hits**, the extra eight being self-matches
  in `BUILD-SPEC-P24.md`. The count rising as the phase documents itself is
  exactly the pathology, and it is why the count must never be the gate.
- **The repaired gate is `rg -n 'state_predicates' lib test -g '!*.md'`, which
  exits 1 today (MEASURED by this author, `new_rc=1`).** Use that one. Quoting
  the old form would manufacture a fake regression, the same class of defect as
  a fake green.
- Upstream counts RE-MEASURED by this author, not taken on report:
  `rg -c 'pub open spec fn'` = **46**, `rg -c 'StatePred'` = **34**, and
  `rg -c 'TempPred|ActionPred|leads_to'` = **exit 1** (zero), confirming the
  file is entirely state-level.
- Upstream surface, MEASURED and agreeing with P23's record: **46
  `pub open spec fn`**, **34 `StatePred` occurrences**. Scout A additionally
  established that all 34 `StatePred` are `-> StatePred<ClusterState>` and that
  the file contains **zero** `TempPred` / `ActionPred` / `leads_to` /
  `eventually` / `always(` (rg exit 1), so despite living under `liveness/`
  **the whole file is state-level and none of it is temporal**. That is what
  makes it portable to a safety register at all.
- Occupancy context from scout F: the port occupies only **12 of 175** spec-fn
  registers across the whole `vstatefulset_controller` tree, and
  `state_predicates.rs` is its single largest unoccupied file.

**Non-vacuity is MEASURED, not argued - and uniquely so among the candidates.**
Every picked member evaluates on the four committed P23 graphs ridden unchanged
(`bl*_states` are aliases of `sl*_states`, `p23_witness.ml:139-142`), so the
population it runs on is already pinned:

- decoded states **76 / 680 / 1056 / 8872** with decode failures **0**
  (`p23_witness.ml:208-211`, `:220`);
- needed-slot witness **20 / 200 / 208 / 3616** (`:230-233`) - itself the
  measured round-to-round-carry that refuted P23's prediction 5;
- condemned witness **32 / 456 / 520 / 3136** (`:237-240`), complements
  44 / 36 / 24 (`:277-279`);
- parked pod-list requests **16 / 112 / 288 / 1560** (`:298-305`), measured to
  coincide with **100%** of `After_list_pod` parked states;
- ok list-responses **8 / 60 / 48 / 816** (`:312-315`), with **8 of 8** BL0
  responses carrying NON-EMPTY `objs` (`:321`) - body-on-real-data, not
  premise-fires-only.

No other candidate has a committed non-vacuity number for its NEW members.

## 2. The family - SETTLED by the design wave

Module `lib/assurance/state_predicates.ml{,i}`. Public surface is exactly two
vals, per the `local_binding.mli:300,:320` precedent:

    val predicate_sources : string list
    val predicate_family :
      cr:V_stateful_set.t -> controller_id:int -> Invariants.invariant list

**Naming ruling.** `predicate_*`, not `state_*`. One settle agent argued `state_*`
on the `helper_invariants` precedent (drop the generic tail noun); overruled,
because the two more recent precedents keep the TAIL noun and drop the modifier
(`Local_binding` -> `binding_*`, `Internal_guarantee` -> `guarantee_*`).
`Helper_invariants` is the outlier only because "invariants" would collide with
the `Invariants` module; "predicates" collides with nothing, and `state_family`
misreads as "a family of states" in a codebase where `cluster_state` is
everywhere.

**Family cardinal = 3** (M1, M2, M3) was the design wave's ruling, subject to the
two MEASURED gates named below. **AS SHIPPED THE CARDINAL IS 2** (M1, M3): the
M2 gate was RUN and the member is **CUT** on the measurement in 2.2, which is
this phase's NEGATIVE RESULT. The "provisionally 2" figure one agent proposed
was rejected at design time on grounds the refuter demolished, and it is not
what vindicated it - the cut rests on stage-B and stage-C MEASUREMENTS taken
after the member was written, not on the design-time argument.

### 2.1 M1 - `state_predicates.rs:35` + `:192` - SHIPS. AS SHIPPED: 14 conjuncts PORT, 9 EXCLUDE-WITH-A-PIN, 0 BLOCKED.

The design wave ruled 15 PORT / 8 EXCLUDE with `:241` PORTING *provisionally*
against an open stage-B obligation. **Stage B discharged that obligation and
`:241` moved to EXCLUDE-WITH-A-PIN before the phase sealed**, so the SHIPPED
partition is **14 / 9** - the number `state_predicates.mli` and
`fault_check.mli` carry. The nine do NOT all die on one pin: eight are the PVC
family, while `:246` and `:241` are excluded on REACHABILITY.

The span citation `:192-249` stays correct (this is NOT a misattribution the way
P23's E3/E4/E5 was). What was wrong in the sketch is the implicit claim that all
23 `&&&`-conjuncts ship 1:1.

**EXCLUDE-WITH-A-PIN, the PVC EIGHT:** `:197 :198 :199 :215-221 :223-228 :233
:244 :246`, together with the `:193` `pvc_cnt` binding every one of them reads.
(This is the accounting `state_predicates.mli` ships: eight CONJUNCTS plus one
BINDING. The design wave wrote the same set as "`:193 ... :244`, and `:246` with
them"; the two differ only in whether `:193` is counted as a conjunct, and both
leave M1 at 23 conjuncts = 14 PORT + 9 EXCLUDE. Quote the `.mli`'s form.)
All are `pvc_cnt`/PVC-step dead under
`vct:false`. The pin
already exists and is already measured on all four committed graphs:
`p23_witness.ml:287` `pvcs_non_empty_everywhere = 0` across 10,684 decoded
states. Independently re-derived from `v_stateful_set_reconciler.ml:478-514`:
`Get_pvc` is entered only when `List.length state.pvcs > 0`, and `state.pvcs` is
always `[]` because `make_pvcs` folds an absent `volume_claim_templates`.
**Eight separate conjuncts of ONE upstream predicate die on the same pin that
killed P23's PVC forall** - the `.mli` must say so, not leave it implicit.

`:246` is excluded on a different, subtler ground and the distinction must
survive into the doc comment: its guarding steps (`Create_needed`/`Update_needed`)
ARE live, but its conclusion `pvc_index == pvc_cnt` is dead regardless, because
`pvc_index` is only ever mutated inside the unreachable `Get_pvc`-family arms, so
it sits at a vacuous `0 == 0` forever. A real mutation to PVC-index tracking
could never turn it red. That is the house's "green that could not have been red"
defect condition, i.e. a REACHABILITY exclusion, not a shape exclusion.

**PORT (15 as ruled, 14 as SHIPPED once `:241` moved).** Zero plumbing,
confirmed: every helper the predicate touches is
already exported (`v_stateful_set_reconciler.mli` `pod_name` :91, `pvc_name` :94,
`get_ordinal` :98, `get_largest_unmatched_pods` :125) and `type s` (:45-53) is
fully public with every field the predicate reads. As shipped,
`get_largest_unmatched_pods` is no longer reached at all - it was `:241`'s
consequent, and with `:241` excluded `local_state_is_valid` does not take the CR.

**Where M1's genuine novelty actually is** (the selection sketch undersold this;
found in the main loop):
- `:200-204` requires `name == Some(pod_name(parent, ord))` - the EXACT
  ordinal-indexed name. P23's shipped L1 only requires that SOME ordinal parses
  (`pod_name_matches` = `Option.is_some (get_ordinal parent name)`). Strictly
  stronger.
- `:212`'s condemned `get_ordinal(...) >= replicas` bound has **no P23
  counterpart at all**.

**Non-vacuity, already measured against committed pins:** decoded
76/680/1056/8872 with 0 decode failures; needed 20/200/208/3616
(`p23_witness.ml:230-233`); condemned 32/456/520/3136 (`:237-240`). Rows 1/2/3/7/8
fire unconditionally on any decoding state.

**OPEN, carried into stage B as a measurement, not an assumption.** One settle
agent called `:241` (the `AfterDeleteOutdated` implication) vacuous. Refute
verdict C19 refuted that as UNMEASURED and the refutation is ADOPTED: the only
`After_delete_outdated = 0` pin lives at `t_p11_vsts_liveness.ml:113-114`, on a
DIFFERENT, smaller 20-state `fair:true` P11 graph, and
`rg 'After_delete_outdated|delete_outdated' test/p23_witness.ml` returns zero
hits. Extrapolating a P11-graph pin onto BL0/BLc/BLd/BLm is exactly the
P11-graph evidence-caveat this phase already applies to the excluded outdated
pipeline. Row 11 and the step-conditioned rows 13-20 and 23 are in the same
position: `needed_witness`/`condemned_witness` measure "some slot is populated",
which is a DIFFERENT predicate from "`reconcile_step` = X" (refute verdict C3,
confirmed against `local_binding.ml:142-144`).

  -> **Stage B MUST add a `reconcile_step` occupancy histogram to
  `p24_witness.ml`, measured on all four graphs.** `:241` PORTS provisionally; if
  its guarding step measures 0 occupancy on all four, it moves to
  EXCLUDE-WITH-A-PIN BEFORE the phase seals, with a pin measured on THESE graphs
  and never inherited from P11.

  -> **DISCHARGED. The histogram was added (`P24_witness.step_occupancy`, probe
  B2) and measured `After_delete_outdated` at 0 / 0 / 0 / 0 on BL0/BLc/BLd/BLm,
  pinned as `P24_witness.after_delete_outdated_occupancy_everywhere = 0` behind
  a POSITIVE CONTROL that the sibling `Delete_outdated` column is non-zero
  (8 / 76 / 64 / 1272) and behind the histogram's own totality assertion. So
  `:241` is EXCLUDED-WITH-A-PIN in the shipped tree, on the same REACHABILITY
  ground as `:246`, and nothing is inherited from `t_p11_vsts_liveness.ml`.**
  The same histogram settled the OTHER step-gated rows the other way:
  `Create_needed` 4/32/32/176, `Update_needed` 4/28/16/640,
  `After_create_needed` 8/72/160/560, `After_update_needed` 8/56/128/1440,
  `Delete_condemned` 4/56/40/312, `After_delete_condemned` 8/120/176/992 - all
  occupied, so `:230-231`, `:235`-`:240`, `:242` and `:248` stay PORTED and
  their guards are LIVE. Only `After_delete_outdated` and the five
  `Get_pvc`-family columns are empty. **DIVERGENCE, measured in 0.5: "their
  guards are live" is OCCUPANCY, not coverage, and this sentence used to read
  "stay PORTED and exercised", which overclaimed. Deleting `:230-231`, `:235`,
  `:236`, `:237`, `:238`, `:239`, `:240`, `:242` or `:248` - individually, or all
  of them together with `:194`/`:195`/`:196` - leaves all 82 executables GREEN.
  An occupied guard means the conjunct is EVALUATED; it says nothing about
  whether removing it would be noticed.**

### 2.2 M2 - `state_predicates.rs:45` + `:59` - **CUT. This is the phase's NEGATIVE RESULT.**

> **RULED, and this section is a post-hoc report rather than the design wave's
> voice.** The member was written, built, run on all four graphs, measured and
> mutation-tested. It is **CUT**. Rendered as an INVARIANT over the graphs this
> port explores, upstream `req_msg_is_list_pod_req` (`:45-57`) closed by
> `pending_list_pod_req_in_flight` (`:59-66`) is **ENTIRELY CONTAINED in P23's
> shipped L2**. The family cardinal is **2**. The record below is the finding,
> not an apology for a deletion: re-adding the member without answering it would
> re-ship five of L2's conjuncts under a fresh `state_predicates.rs:45`
> citation, which is exactly the double-counted coverage the phase gate exists
> to block.

This was the phase's named overclaim risk ("M2 is L2 wearing a hat"). The design
wave answered "mostly a hat, with a thin genuinely-new brim". **The measurements
answered: the brim is not there.**

#### The per-conjunct partition, as MEASURED

| upstream conjunct | status AS MEASURED |
| --- | --- |
| `:50` dst | **ALREADY L2** - `local_binding.ml:221` checks `rm.dst` |
| `:51` content is APIRequest | **ALREADY L2** - `list_req_content_matches` :164-166, literal `false` arms |
| `:52` req is ListRequest | **ALREADY L2** - :153-155 |
| `:53-56` kind + namespace | **ALREADY L2** - :151-166, `Common.equal_kind lr.kind Pod.kind && String.equal lr.namespace namespace` |
| `:64` pending_req_msg_is | **ALREADY L2** - discharged by reading the `pending_req_msg` slot, which `after_list_pod_ok` :217-225 already does |
| `:65` `s.in_flight().contains(req_msg)` | ruled NOVEL by the design wave; **MEASURED ENTAILED** by the port's own rendering premise - raw-in-flight population EQUALS the delivery window at 8/52/48/744 on all four graphs (P8). Nothing to redden; `M2b'` STRUCK |
| `:49` `req_msg.src = Controller(controller_id, vsts_key)` | genuinely absent from L2, and **MEASURED UNWITNESSED**: complement **0 on all four graphs** over denominators **16/112/288/1560** (P7', pinned as `pending_src_not_controller_everywhere`). TRUE at every state at which it is evaluated - a **green that could not have been red** |

Five literally L2's, one entailed, one unwitnessed. **Zero conjuncts left.**

`.src` really is absent from L2, and that was never the question: exactly ONE
`.src` occurrence exists in `local_binding.ml`/`.mli`, and it is on the RESPONSE
variable inside `ok_list_resps_for` (:193-200); `after_list_pod_ok` (:217-225)
checks `rm.dst` and the content, never `rm.src`. Upstream
`internal_rely_guarantee.rs:640-664` (L2's own source) likewise has no
`req_msg.src` conjunct. (Refute verdict C5, confirmed; adopted.) **The question
was whether the conjunct has EXERCISABLE CONTENT on these graphs, and it does
not.**

`:65` is a strictly narrower window than anything L2 checks, because delivery is
ATOMIC: upstream `kubernetes_cluster/spec/network/state_machine.rs:9-28` does
`in_flight.remove(recv).add(send)` in one transition, and the port mirrors it at
`lib/cluster/network.ml:19-37` (`Message.Pool.remove_one m s.in_flight` unioned
with the send). Once a response exists, that request occurrence is gone. (Refute
verdict C7, confirmed; adopted.) **That is also exactly why it is entailed
here**: the port narrowed the premise to the DELIVERY WINDOW (parked at
`AfterListPod`, pending `Some`, no matching response yet), and the shipped
`reconcile_correspondence.ml:213` xor invariant turns that premise into ":65
holds". The two populations are equal on every graph, by two independent routes,
and that equality is now **ASSERTED** - without a literal - by
`t_p24_state_predicates`'s `inherited_population` case.

#### The ship gate, why its letter said SHIP, and why its spirit says CUT

**REJECTED long before stage C - the sketch's M2a mutant** ("swap the Pod kind
constructor in the ported `ListRequest` shape"). It targets `:53-56`, which L2
ALREADY carries, so it would redden P23's leg too. (Refute verdicts C15 and C22,
both confirmed against `local_binding.ml:217-225` and `:151-166`; adopted.)

**The replacement mutants:**
- **M2a'** - swap `.src` -> `.dst` in the ported `:49` conjunct.
- **M2b'** - swap the raw-in-flight membership combinator (`List.exists` ->
  `List.for_all`, or the `Message.Pool` membership equivalent) in `:65`.

> **The gate as written:** M2 SHIPS if and only if at least one of M2a' / M2b'
> is SEEN RED on the P24 leg while the P23 local-binding leg stays GREEN in the
> same run. If neither discriminates, M2 is L2 wearing a hat and is CUT from the
> phase.
>
> **`M2b'` STRUCK** by P8 before stage C ran - it can never fire.
>
> **`M2a'` RUN, and it KILLED**: with `.src` swapped for `.dst`,
> `p24_state_predicates` went from 2 failures to 4 (SP0 and SPd newly `[FAIL]`)
> while `p23_local_binding` reported "Test Successful ... 11 tests run" in the
> SAME run (`p23_mutation` and `p23_regression` green too).
>
> **AND THE KILL DOES NOT DISCRIMINATE.** `.src` is
> `Controller(controller_id, cr_key)` and `.dst` is `Api_server` at EVERY state
> of the premise population (probe B4, 16/112/288/1560 with complement 0), so
> the swapped conjunct is FALSE on the ENTIRE premise and the leg reds by
> **FALSIFICATION**. It shows the conjunct is load-bearing FOR THE MUTANT; it
> shows nothing about whether `:49` has content. **The gate was underspecified -
> it never required the mutant to be NON-TRIVIALLY falsifying - which is the
> same class of error as 0.3's vacuity-only gate. Section 0.4 states the
> repaired clause. M2 IS CUT.**

#### What would buy `:49`, and why it is not built

A graph carrying a pending request at `AfterListPod` whose `src` is NOT
`Controller(controller_id, cr_key)` - another controller's request parked in
this controller's slot, or an `Api_server` / `Pod_monkey` / `External` source.
**No current seed produces one**: `Message.controller_req_msg`
(`lib/cluster/message.ml:175-179`) is the only constructor the reconcile path
uses and it always stamps `~src:(Controller (controller_id, cr_key))`. Buying it
needs a NEW SEED, and **adding a seed would move the shared graphs** and every
committed P13-P23 pin with them, so none is added. `:49` is CARRIED TO P25
exactly the way upstream `:112`'s unobserved owner-reference reject path is:
disclosed, pinned at zero, with the seed that would buy it named and
deliberately not built.

**Do NOT carry the "100%-red" prediction into this spec, in either direction.**
Refute verdict C6 refuted it as unmeasured and the refutation is adopted: the
structural support (`lib/cluster/message.ml:175-179`) is
plausibility-from-construction on BL0, not a measurement across the FAULT graphs
BLc/BLd/BLm where adversarial actions exist. Stage B therefore ran the positive
control over every parked state on all four graphs and **MEASURED
16 / 112 / 288 / 1560, i.e. the whole parked-with-pending population, with the
complement 0**. That is a measurement ON THESE FOUR GRAPHS - it says `:49` has
no witness HERE, never that it could not have one. The complement is now a
LITERAL in `p24_witness.ml` (`pending_src_not_controller_everywhere`) precisely
because the cut rests on it; 5.0.1 records how it stopped being a tautology
first, which is what makes it leanable-on.

#### What came out with the member

`req_msg_is_list_pod_req` (the `:49`-`:56` rendering), `list_req_content_matches`
(its `:51-56` half, a copy of `local_binding.ml:151-166`) and
`matching_resp_in_flight` (the `reconcile_correspondence.ml:103-107` copy that
supplied the delivery-window narrowing) all lost their only consumer in
`state_predicates.ml` and are REMOVED - a helper whose last consumer goes away
goes with it. `t_p24_mutation`'s `m2_novel_conjuncts` case went too, with
`foreign_src_req` and `parked_pending`.

**The WITNESS probes did NOT go, and that is deliberate.**
`P24_witness.pending_src_is_controller`, `pending_src_is_not_controller`,
`pending_src_occupancy`, `src_other_total`, `pending_still_in_flight` and
`delivery_window` (renamed from `m2_window` - it names a population, not a
member) are now this finding's EVIDENCE and stay ASSERTABLE. An exclusion whose
evidence is not asserted decays into an omission one revision at a time, and a
CUT MEMBER is the sharpest version of that risk: nothing else in the tree would
notice if the measurement drifted.

### 2.3 M3 - `state_predicates.rs:70` + `:107` - SHIPS, SPLIT. The "GATED on weakly_eq" reason is VOID.

> **AS SHIPPED (see 2.3.1): M3 ships its SEVEN PURE-SHAPE conjuncts** - `:115`,
> `:126`, `:127`, `:128`, `:129`, `:130`, `:132` - and its two etcd-consuming
> conjuncts `:116-118` and `:119-124` are **EXCLUDED-WITH-A-PIN on a SCOPE
> ground**, with the refutation they produced pinned in full. Everything from
> here to 2.3.1 is the pre-build ruling, kept as written.

Two settle agents split on M3; the refuter settled it against the one that wanted
M3 cut.

**(a) The sketch's stated gate is void.** The sketch gated M3 on porting
`predicate.rs:26 weakly_eq`, "absent from the port". It is absent as a FUNCTION,
but every ingredient is already public, so the port is ~4 lines, not a plumbing
project (main-loop measured; table in
`~/Documents/anvil-ocaml-p24-harness/MAIN-LOOP-GROUND-TRUTH.md:32-40`):
`Dynamic_object.metadata/.kind/.spec` (dynamic_object.mli:20/17/23),
`Object_meta.without_resource_version` (:76), `Object_meta.equal` (:109),
`Common.equal_kind` (common.mli:48), `Value.equal` (value.mli:23).
`Dynamic_object.equal` (dynamic_object.mli:51-52) is NOT a shortcut - it also
compares `status` and does not exclude `resource_version`.

**(b) The "cut M3 to P25" ruling is unsound as argued.** It rested on "P23's own
pin shows `:116-124`'s premise fires 8-of-8 on BL0". **That pin does not exist.**
The only 8-of-8 BL0 pin is `bl0_ok_list_resps_with_objs = 8`
(`p23_witness.ml:321`), whose own comment says it measures `resp_objs`
NON-EMPTINESS - a strictly weaker fact than `state_predicates.rs:112`'s
`owned_objs = resp_objs.filter(owner_references_contains(vsts.controller_owner_ref()))`.
`rg -n 'owned' test/p23_witness.ml` returns ZERO hits. (Refute verdict C14,
confirmed against `p23_witness.ml:307-321` and `state_predicates.rs:107-124`;
adopted. C20 and C11 independently confirm the owned subset is unmeasured.)

**(c) The plumbing question is single-item, not a pair.** Of the two `.ml`-only
helpers, only `objects_to_pods` (`v_stateful_set_reconciler.ml:461`, feeding
conjunct `:132`) is reached by M3's two picked functions. `pod_filter` (:421)
belongs to the UN-SELECTED
`resp_msg_is_pending_list_pod_resp_in_flight_with_n_condemned_pods` (`:87-104`)
and is irrelevant to M3.

**RULING on M3:**

1. **The 7 pure-shape conjuncts SHIP unconditionally** (`:108-115`, `:125-132`).
   Non-vacuous on the already-measured ok-list-response population 8/60/48/816,
   with real non-empty response objects on BL0 (`p23_witness.ml:321`). Killable
   at GRAPH level - no forged response needed, which resolves the sketch's own
   conditional M3a row in favour of a graph-level mutant.
   **DIVERGENCE - "killable at GRAPH level, no forged response needed" is
   REFUTED for all seven, by the deletion measurement in 0.5.** The population
   non-vacuity stands. The killability claim does not: deleting any one of the
   seven leaves all 82 executables GREEN except `:115` and `:129-130`, and those
   two are killed by FORGED responses in `t_p24_mutation`, not by anything
   BL0/BLc/BLd/BLm drive. It cannot be otherwise - deletion WEAKENS `holds`, the
   leg asserts `holds` everywhere and is CLEAN on all four graphs, and M3's
   `interesting` does not read `ok_list_resp_shape` - so no graph-level deletion
   mutant of a shipped conjunct can redden this leg at all. What the ruling should
   have said, and what P25 inherits, is that the POPULATION is non-vacuous at
   graph level; killability was never measured before the conjuncts shipped.
2. **EXPORT `objects_to_pods` from `v_stateful_set_reconciler.mli`.** Pure
   visibility change, no `.ml` body edit, mirroring `vreplica_set_reconciler.mli:60`'s
   identical export for a different controller, alongside the eight reconciler
   helpers already exported for exactly this assurance-consumer role. It is NOT
   the `pvc_name_matches` situation (`local_binding.mli:108-121`,
   REFUSE-and-exclude): that predicate had two existing copies and was proven
   unreachable on every P23 graph, whereas `objects_to_pods` has zero existing
   VSTS copies and is live production logic (`v_stateful_set_reconciler.ml:537`).
   **Shadowing note for the `.mli` doc comment:** nothing today does
   `open V_stateful_set_reconciler` (only `Vreplica_set_reconciler`, five times,
   all in `invariants.ml`), so there is no collision today - but warnings 44/45
   are globally disabled in all three dune stanzas, so a FUTURE co-open would
   shadow SILENTLY rather than loudly. Build-verify this export; do not assume it.
3. **The two etcd-consuming conjuncts (`:116-118` set equality, `:119-124` forall
   whose body is `:123`) are GATED on ONE new stage-B measurement**: is
   `owned_objs` (owner-ref-filtered) ever non-empty on the 8/60/48/816
   ok-list-response population?
   - **non-zero on any graph** -> ship both in full. Every constituent is already
     public (`Cluster.resources` cluster.mli:70, `Object_ref_map` bindings/fold,
     `V_stateful_set.controller_owner_ref` v_stateful_set.mli:42), and `weakly_eq`
     is written in P24 and mutation-tested (M3b).
   - **zero on every graph** -> EXCLUDE-WITH-A-PIN, phrased as a behaviour-free
     assertion that `owned_objs = []` on every ok-list-response state across
     BL0/BLc/BLd/BLm (the P23 PVC ruling's shape), and **`weakly_eq` is NOT
     written in P24** - an unused 4-line predicate would be dead code carrying
     warning 32, and P25's precondition ("weakly_eq lands with a seen-red row")
     is then simply still open, which costs nothing, because the harm claimed for
     deferring rested on the nonexistent pin refuted in (b).
4. **Record the fork for P25 either way**: an EXCLUDE fork means P25's `:256`
   flagship (114 lines of the same etcd-wide correlation at much larger scale)
   inherits the identical unmeasured-vacuity risk and must budget the analogous
   measurement before committing any etcd-coherence conjunct.

**FORK RESOLVED - NON-ZERO, AND THIS IS WHAT SHIPPED.** Probe B3 measured
`owned_objs` non-empty at **8 / 60 / 40 / 776** over the 8 / 60 / 48 / 816
ok-list-response population, so item 3's first branch applies: **both
etcd-consuming conjuncts SHIP in full and `weakly_eq` IS WRITTEN** (a 4-line
port of `predicate.rs:26-30`, plus `valid_owned_object` from
`predicate.rs:44-52` for the etcd side, `:116-118` compared by MUTUAL
CONTAINMENT and never by length, `:122`'s missing key folded to `false` and
never to a vacuous pass, and `controller_owner_ref`'s `None` folded OUT OF
PREMISE behind an `Option.is_some` positive control). Item 4's P25 record is
therefore the SHIP fork: `:256` inherits a rendered precedent rather than an
open gate - and it inherits the red below with it.

**AND THE CONSEQUENCE THE GATE DID NOT ANTICIPATE (prediction P9).** The gate
asked only about VACUITY, and it was **UNDERSPECIFIED** for exactly that reason
(section 0.3). The answer is non-vacuous **AND RED**: with both conjuncts
shipped the leg was CLEAN on BL0 and BLd and **REFUTED on BLc and BLm**.
Attribution is measured, not guessed - on BLc `:116-118` fails at 8 states and
`:119-124` at 4; on BLm 72 and 40; every `:119-124` failure is the `:122`
key-presence conjunct, and `weakly_eq`'s own metadata, kind and spec comparisons
disagree at ZERO states on every graph. Both modes are STALENESS of an in-flight
response relative to etcd, from a writer landing between the response's
formation and its observation (a crash-orphaned request applied late on BLc, the
pod monkey on BLm).

### 2.3.1 THE MAIN LOOP'S RULING: EXCLUDED-WITH-A-PIN ON A **SCOPE** GROUND

Upstream `state_predicates.rs:116` carries this comment, verbatim, immediately
above the set equality:

```
// coherence with etcd which preserves across steps taken by other controllers satisfying rely conditions
```

and `:111`, one line above the `owned_objs` binding both conjuncts quantify
over, reads `// these objects can be guarded by rely conditions`.

The ground, in three checkable parts:

1. **Upstream scopes the coherence itself** - it is asserted of an execution in
   which the other writers satisfy rely conditions, not unconditionally.
2. **This port has no rely-condition machinery.** A fact about the port, stated
   as one: `Rely_conditions` carries the P12 rely/guarantee correspondence
   members, and nothing in `lib/` constrains which writers may touch a CR-owned
   object between a list response being formed and being observed.
3. **BLc and BLm inject, by construction, exactly the rely-violating writers the
   assumption excludes** - a crash-orphaned request applied late, and the pod
   monkey. That is what those budget dimensions are FOR.

Therefore asserting these two conjuncts over those graphs asserts upstream's
predicate **outside its stated scope**. Relaxing the `legs` assertion, or
narrowing M3's premise until the failures fell outside it, would each be the
retune this project forbids. **EXCLUSION-WITH-A-PIN is the phase's established
mechanism (nine prior uses) and is what applies.** This is a THIRD exclusion
ground: distinct from the PVC pin (SHAPE, 7 M1 conjuncts) and from `:241`/`:246`
(REACHABILITY, 2).

**THE PIN IS A MEASURED REFUTATION WITH ATTRIBUTION, AND EVERY NUMBER IS
ASSERTED.** The other nine exclusions pin a vacuity; this one pins conjuncts
that were rendered, run and SEEN RED. Probe B5 in `test/p24_witness.ml` stays
live after the conjuncts are gone - it is now the pin's evidence - and
`t_p24_state_predicates`' `scope_exclusion_pin` case asserts, on
SP0/SPc/SPd/SPm:

| pinned column | SP0 | SPc | SPd | SPm |
|---|---|---|---|---|
| `:116-118` set-equality failures | 0 | 8 | 0 | 72 |
| ...direction ONE (etcd holds a valid-owned object the response does not) | 0 | 4 | 0 | 32 |
| ...direction TWO (the response holds an owned object etcd no longer has) | 0 | 4 | 0 | 40 |
| `:119-124` coherence failures | 0 | 4 | 0 | 40 |
| ...of which the `:122` key-presence half | 0 | 4 | 0 | 40 |
| `weakly_eq` metadata / kind / spec disagreements | 0 | 0 | 0 | 0 |
| multi-matching-response states | 0 | 0 | 0 | 0 |

**THE B5 PROBES WERE THEMSELVES CONFIRMED BY MUTATION, AND ONE MUTANT
SURVIVED.** Flipping `coherence_key_missing`'s `Option.is_none` to
`Option.is_some` was **KILLED** (the coherence pins and the containment relation
both reddened), so those columns are not greens that could not have been red.
Dropping `Object_meta.without_resource_version` from the metadata arm - i.e.
comparing raw metadata, resource version included - **SURVIVED**: the column
stayed 0 on all four graphs. That is a measured fact that strengthens the
staleness diagnosis (an in-flight object whose key is still in etcd matches
etcd's copy exactly, rv included) while disclosing a NEW gap: upstream's
resource-version TOLERANCE (`predicate.rs:25`) has no witness on these graphs,
and nothing here distinguishes `weakly_eq`'s metadata arm from raw
`Object_meta.equal`. Recorded in `state_predicates.mli` and `p24_witness.ml` for
whoever restores it.

Each pin sits behind a positive control asserted first, so no zero is an
unexplored region: the CR really has a controller owner reference; the premise
population is non-empty (8/60/48/816); the set equality really compared two
NON-EMPTY sides somewhere (8/60/40/736); `weakly_eq` really RAN on a found etcd
object (8/60/40/736); and the multiplicity histogram's three columns sum to the
parked-with-pending population with the "exactly one" column equal to the
premise population. The two set-equality directions are asserted DISJOINT (they
sum to the failure count) and `:122`'s population is asserted contained in
direction TWO, so no literal leans on another.

**THE ATTRIBUTION, measured before the conjuncts came out.** With them still
shipped, M3's per-state RED count on the replica was **0 / 8 / 0 / 72** -
EQUAL, graph by graph, to the union of the two failure columns. The member's red
set was exactly the set probe B5 selects, so the exclusion removes those states
and nothing else. That identity is no longer assertable (M3 is green
everywhere); both halves are printed side by side in the B5 dump, where the
shipped column must read 0 and the refutation column the pinned 0/8/0/72.

**WHAT CAME OUT WITH THEM, and it is not a defect verdict.** `weakly_eq`
(`predicate.rs:26-30`), `owned_objs` (`:112`), `valid_owned_object`
(`predicate.rs:44-52`), `etcd_valid_owned_refs` and `ref_set_equal` all lost
their only consumer and are REMOVED - a helper whose last consumer goes away
goes with it. `state_predicates.mli` records `weakly_eq`'s standing so P25 can
restore it in four lines: **PORTED, MUTATION-KILLED on its metadata arm,
incidentally covered on its kind arm, a measured TEST GAP on its spec arm, and
removed as a CONSEQUENCE OF THE SCOPE EXCLUSION and not of any defect in it.**
The M3c and M3d state-level mutation rows went with them; `t_p24_mutation.ml`
records where and why, and that their evidence was promoted to the B5 pin, which
is graph-level and therefore stronger than a forged state.

**P25's record is REWRITTEN, superseding item 4 above.** `:256` does not inherit
a rendered precedent; it inherits this exclusion and the rely-condition question
underneath it. Either P25 lands rely-condition machinery - at which point both
conjuncts and `weakly_eq` come back into scope together and this pin retires -
or it excludes `:256` on the same SCOPE ground. It may not commit an
etcd-coherence conjunct without answering that first.

With the exclusion applied, `@runtest` is **GREEN on all 82 executables**.

## 3. The leg - SETTLED. A verified clone of P23's.

Verified against BOTH `fault_check.ml:1186-1211` (P23) and
`fault_check.ml:1123-1148` (`check_scale_down_under_faults`, P22 - the same
triple-optional-arg shape one phase further back).

    val check_state_predicates_under_faults :
      ?depth:int -> ?req_drop:bool -> ?pod_monkey:bool ->
      Bound.t -> budget -> desired:int -> ordinals:int list ->
      require_fault:bool -> fault_report

Body is the P23 leg with `Local_binding.binding_family` swapped for
`State_predicates.predicate_family`: same `Scenario.vsts_cluster`,
`Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true ~req_drop
~pod_monkey ()`, same `run_leg` call, same `~violated:(violated_of invs)`, same
`~gate` counting states where a fault is taken (when `require_fault`) AND some
member's `interesting` fires.

It rides P23's four committed graphs BL0/BLc/BLd/BLm UNCHANGED - no new seeds,
bounds, budgets, or depth. Its `.mli` doc block follows the
`fault_check.mli:2014-2073` archetype: `{b P24 LEG}`, "WHAT A RED MEANS HERE",
"THE FAMILY IS ASSERTED ALONE" (the P15 masking trap), "PER-MEMBER ATTRIBUTION IS
NOT AVAILABLE FROM THIS LEG", "Shape:".

**Per-member attribution, when the tests need it, comes from a REPLICA** whose
`Mc.states_seen` equals the leg's own `states` (the `t_p21_guarantee.ml:193-237`
technique) - NEVER from the leg's `violated`, because `Invariants.first_violated`
(`invariants.ml:1046`) is FIRST-IN-LIST-ORDER.

**Two hazards this leg must not create** (section 5.1 expands):
1. Do NOT edit the shared `faulted` block (`fault_check.ml:37-145`).
2. The mutation matrix must NEVER mutate `objects_to_pods`/`pod_filter` in place.

## 4. Predictions - written BEFORE the build

Per the house rule that predictions-before and measurements-after go stale, these
are written now, and stage B gets its OWN reconciliation step whose job is to
mark each row CONFIRMED / MOVED / UNTRIGGERED. Do not silently overwrite them.

| # | prediction | basis | status |
| --- | --- | --- | --- |
| P1 | Every committed pin (P13-P21 76/464/744/1976/116; P22 88/808/1144/10216 states, 20/276/96/2080 gates; P23 68/560/816/7920 gates) stays byte-identical | family-blindness is a type-signature fact, section 5.1 | **CONFIRMED.** Every literal came back byte-identical, before and after the fork, the control repair and every stage-C mutant; P23's decoded 76/680/1056/8872 re-measures unchanged too. `movedPins` is EMPTY. While the leg was REFUTED its own `states` printed the `-1` sentinel on SPc/SPm; after the SCOPE exclusion (2.3.1) all four legs are clean and all four state counts print unchanged |
| P2 | P24's own gate counts are NEW pins, of the same order as P23's 68/560/816/7920 | rides the same four graphs | **MEASURED 60 / 516 / 608 / 7360 AS SHIPPED**, same order as predicted. Per-member `interesting`: M1 52/516/680/6664, M3 8/60/48/816. With the M2 candidate still in the family the gate measured 68 / 560 / 640 / 8088 and its own `interesting` was 8/52/48/744; the gate SHRANK when the member was cut, because it is the OR over the register's own members. These are PRINTED prose, never literals in `p24_witness.ml` and never asserted against a literal, so the change is not a pin move - the leg's gate is checked against the run's own interesting-union |
| P3 | `reconcile_step` occupancy for `After_delete_outdated` is 0 on all four graphs | inferred from the P11-graph pin, EXPLICITLY not evidence here | **CONFIRMED, and re-measured on THESE graphs: 0/0/0/0** -> `:241` moved to EXCLUDE-WITH-A-PIN, pinned as `P24_witness.after_delete_outdated_occupancy_everywhere`; positive control `Delete_outdated` = 8/76/64/1272 |
| P4 | `Create_needed`/`Update_needed` occupancy is NON-zero on all four graphs | dispatch routes there whenever `pvcs = []` and a needed slot remains, which under `vct:false` is always | **CONFIRMED** (`Create_needed` 4/32/32/176, `Update_needed` 4/28/16/640) -> rows 13-20, 23 stay PORTED |
| P5 | `owned_objs` non-empty on at least one ok-list-response state | UNMEASURED; `resp_objs` non-empty is 8-of-8 on BL0 but is a weaker fact | **CONFIRMED: 8/60/40/776** of the 8/60/48/816 population -> M3's etcd conjuncts SHIP and `weakly_eq` is WRITTEN. **The "unowned-only complement 0/0/8/40" first written here was WRONG** (see 5.0.1): that probe was `population && not owned` and 0/0/8/40 is the count of states whose responses carry NO objects at all. Re-measured on its own route the split is owned **8/60/40/776**, every-object-unowned **0/0/0/0**, no-objects **0/0/8/40**, and the owner-ref filter's REJECT path measures **0/0/0/0** and is pinned there. |
| P6 | `rm.src = Controller(controller_id, cr_key)` on every parked state, all four graphs | `message.ml:175-179` construction; plausibility only, refuted as a measurement | **MEASURED 16/112/288/1560** (the whole parked-with-pending population). **The complement's tautology has SINCE BEEN REPAIRED** (5.0.1): it is now read off a six-bucket src HISTOGRAM built by an exhaustive five-arm match on `Message.host_id`, measuring `Controller_this` 16/112/288/1560 and ZERO in each of the other five, summing to the population and agreeing with the positive projection by a second route. So the number IS now a measured absence of counterexamples on these four graphs - still not the refuted "structurally 100%" argument |
| P7 | M2a' reds P24 while P23's leg stays green | `.src` is absent from L2 (C5) | **CONFIRMED AS A FACT AND REJECTED AS EVIDENCE.** `p24_state_predicates` went 2 failures -> 4 (SP0 and SPd newly `[FAIL]` at the `outcome CLEAN` assertion) and `t_p24_mutation`'s `m2_novel_conjuncts` control reddened, while `p23_local_binding` reported "Test Successful ... 11 tests run" and `p23_mutation` / `p23_regression` stayed green. **The prediction was the wrong prediction**: `.src` is `Controller(id,key)` and `.dst` is `Api_server` on the ENTIRE premise population, so the mutant FALSIFIES the conjunct everywhere rather than separating any two states. See P7' |
| P7' | NEW, unpredicted, and it CUT A MEMBER: `:49` is TRUE at every state at which it is evaluated | probe B4's complement, read off the de-tautologised src histogram | **MEASURED 0 on all four graphs** over denominators 16/112/288/1560 -> `:49` is a green that could not have been red, so with `:65` entailed (P8) and the other five conjuncts already L2, **M2 buys nothing and is CUT**. Pinned as `P24_witness.pending_src_not_controller_everywhere`; the gate defect that let P7 look like a ship is stated in 0.4 |
| P8 | NEW, unpredicted: `:65`'s raw-in-flight population equals the delivery window | the delivery-window narrowing entails `:65` through the shipped `reconcile_correspondence.ml:213` xor invariant | **MEASURED EQUAL: 8/52/48/744 = 8/52/48/744 on all four** -> `:65` is ENTAILED, not coverage; M2b' STRUCK. Now ASSERTED on every graph, by two independent routes and without a literal, in `t_p24_state_predicates`'s `inherited_population` case, because it is half the evidence for the cut |
| P9 | NEW, unpredicted: do M3's shipped etcd conjuncts hold on all four graphs? | not predicted by the spec or the ruling; the gate only asked about vacuity | **MEASURED RED on BLc and BLm.** `:116-118` failed at 8 / 72 states, `:119-124` at 4 / 40; every `:119-124` failure the `:122` key-presence conjunct and `weakly_eq`'s own comparison disagreeing at ZERO states everywhere. Cause: staleness of an in-flight response vs etcd under writers upstream's rely conditions exclude (crash-orphaned request on BLc, pod monkey on BLm). **SETTLED by the main loop (2.3.1): both conjuncts are EXCLUDED-WITH-A-PIN on a SCOPE ground and the refutation is PINNED as probe B5** - re-measured on this pass and reproduced exactly (0/8/0/72 and 0/4/0/40, splits 4+4 and 32+40, all coherence failures `:122`, `weakly_eq` disagreeing nowhere, no multi-matching states). M3's red set was measured EQUAL to the probe union graph by graph before removal. |
| P10 | NEW, unpredicted: is the ported `weakly_eq` mutation-confirmed in FULL? | not predicted; the spec asked only for "flip a token inside `weakly_eq`" | **NO - only in PART, and the function has since been REMOVED with its conjunct (2.3.1).** The METADATA arm was SEEN RED (state level, the M3d row). The KIND arm is incidentally covered by the `:126` shape row. **The SPEC arm SURVIVED** tautologising, and the reason is now itself MEASURED and PINNED: `weakly_eq_spec_disagreements_everywhere = 0` on all four graphs over a comparison population of 8/60/40/736 asserted non-zero first, i.e. no shipped graph reaches a state where a listed object's spec disagrees with etcd's. The verdict is kept as the record a restorer needs; `state_predicates.mli` says PORTED, metadata-arm-killed, spec-arm gap, removed for SCOPE and not for defect. |

## 5. Mutation matrix - settled starting set

Each mutant is applied and reverted with the Edit tool - **never `git checkout --`,
which restores from the INDEX and would destroy uncommitted work** - and every row
is residue-scanned with `git diff --stat` afterwards. A mutant killed by a BUILD
ERROR or a TIMEOUT is NOT caught; reshape it. A survivor is a test gap.

**THE BASELINE THESE VERDICTS WERE RECORDED AGAINST IS NOT THE SHIPPED ONE, AND
BOTH ARE STATED SO NEITHER READING IS SILENTLY SUBSTITUTED.**

- **WHEN THE ROWS RAN**, `p24_state_predicates` reported **2 failures of 11
  cases** - `legs 1 SPc` and `legs 3 SPm` - on M3's then-shipped etcd conjuncts
  (P9, ruling still open). Only **SP0** and **SPd** carried graph-level
  discrimination signal, so a graph-level kill meant those two went `[OK]` ->
  `[FAIL]`: 4 failures where the baseline had 2. Every other suite was green.
- **THE SHIPPED TREE IS ALL-GREEN**: the SCOPE exclusion (2.3.1) made all four
  legs clean and the M2 cut (2.2) removed a member, so `@runtest` is green on
  all 82 executables and `p24_state_predicates` has 0 failures.

Which baseline a row ran against is stated PER ROW, because the two waves did
not share one. M1a's and M2a''s verdicts are recorded against the FIRST baseline
and are NOT re-read against the second: what each established - the mutant seen
red on SP0 and SPd with the P23 leg green in the same run - stands unchanged,
and the extra two graphs are upside nobody has measured, because neither row was
re-run. **The two SEAL-WAVE rows ran against the SECOND, all-green baseline and
therefore had all four graphs available**: M3a's retargeted `:128` mutant, which
reddened all four `legs` cases plus the coupling row, and M1b, which is a
weakening mutant and so left the graph level unmoved by construction. Rows whose
SUBJECT is gone from the tree (M2a', M2b', M3b, M3b-spec, M3c) are marked as such
and are not re-runnable.

| row | mutant | expectation | OBSERVED |
| --- | --- | --- | --- |
| M1a | flip the condemned ordinal bound `>=` -> `>` (upstream `:212`, the conjunct with no P23 counterpart) | RED on all four graphs | **KILLED, both levels.** Graph: SP0 and SPd newly `[FAIL]` at the `outcome CLEAN` assertion. State: `t_p24_mutation`'s `m1_novel_conjuncts` control, `Expected: true / Received: false`. `p23_local_binding` green. The "all four graphs" half is UNTESTABLE on this tree (SPc/SPm already red), not confirmed |
| M1b | weaken the exact needed name `= Some (pod_name parent ord)` to "some ordinal parses" (i.e. degrade M1 into P23's L1) | RED - this is the conjunct that proves M1 is stronger than L1 | **KILLED AT STATE LEVEL, WITH L1 GREEN IN THE SAME RUN - SO "M1 IS STRICTLY STRONGER THAN P23's L1" IS EVIDENCED, NOT PREDICTED.** RUN in the seal wave (it was not one of RULING section 7's required rows; it was run anyway, because the phase's headline discrimination claim rested on it). Mutation: in `local_state_is_valid`, upstream `:200-204`'s NEEDED forall, the exact conjunct `Option.equal String.equal pm.name (Some (V_stateful_set_reconciler.pod_name parent ord))` replaced by L1's weaker existential `Option.fold pm.name ~none:false ~some:(fun n -> Option.is_some (V_stateful_set_reconciler.get_ordinal parent n))` - i.e. M1 degraded into L1. RESHAPED, disclosed: the tuple binder `ord` -> `_ord`, because the weakened body no longer reads the slot ordinal and the unused-variable warning would have turned this into a BUILD-ERROR kill, which is not a catch. It then compiled clean (`dune build @default` RC=0, empty log) and died as an **assertion**: `t_p24_mutation` RC=1, `1 failure! in 0.046s. 8 tests run.`, case `m1_novel_conjuncts`, `FAIL M1b: M1 is RED when the pod named for ordinal 1 sits in needed slot ORDINAL 0`, `Expected: false / Received: true`. The three preceding ASSERTs in that block (`the injection landed`, `M1's premise fires`, and both M1a rows) passed UNDER the mutant, so the red is attributable to the conjunct and not to a broken injection. DISCRIMINATION in the SAME run: `t_p23_local_binding` RC=0 `Test Successful in 26.696s. 11 tests run.`, `t_p23_mutation` / `t_p23_regression` / `t_p24_regression` RC=0. **HONEST LIMIT - the kill is STATE-LEVEL ONLY**: `t_p24_state_predicates` stayed RC=0 with its log byte-identical to baseline modulo run-id/timing, which is what a WEAKENING mutant must do to an already-green leg, so no graph-level signal exists for M1b and this row may never be quoted for one. Reverted with the Edit tool (`git checkout --` / `git restore` never invoked); rebuild RC=0 and `t_p24_mutation` back to `Test Successful ... 8 tests run.`, so the suite really re-ran on restored bytes |
| M2a' | `.src` -> `.dst` in the ported `:49` conjunct | RED on P24, **GREEN on P23's leg in the same run**. The ship gate rested on this row alone. | **KILLED, both levels - AND THE KILL IS TRIVIAL, SO THE MEMBER IS CUT.** Graph: SP0 and SPd newly `[FAIL]`. State: `m2_novel_conjuncts` control red. Same run: `p23_local_binding` "Test Successful ... 11 tests run". But `.src` is `Controller(id,key)` and `.dst` is `Api_server` on the WHOLE premise population (B4: 16/112/288/1560, complement 0), so the mutant falsifies the conjunct everywhere instead of separating states. Load-bearing for the mutant, silent about `:49`. See 0.4 and 2.2; the state-level case is REMOVED with the member |
| ~~M2b'~~ | ~~raw-in-flight membership combinator swap (`List.exists` -> `List.for_all`) in `:65`~~ | **STRUCK** (P8): the raw-in-flight population EQUALS the delivery window at 8/52/48/744 on all four graphs, so no reachable state in that premise has `:65` false and the mutant can never fire. | NOT RUN, and it may not be: a mutant with nothing to redden is not evidence either way. The equality it rests on is now an ASSERTED row rather than a recorded number |
| M3a | flip a token in an M3 shape conjunct (`:108-115`/`:125-132`) | RED at graph level, no forged response | **KILLED, both levels - BUT THE ROW WAS RETARGETED FROM `:126` TO `:128`, AND THE `:126` KILL IS NOT EVIDENCE ABOUT `:126`.** It FIRST ran as `:126`'s kind constant `Pod.kind` -> `V_stateful_set.kind`, inside this family's own `ok_list_resp_shape` and NEVER inside `objects_to_pods`/`pod_filter` (hazard 2), and SP0 and SPd did go newly `[FAIL]`. **That observation stands as an observation and is withdrawn as a claim about `:126`**: `:126` is ENTAILED by `:127` on the next line (`Pod` is `Resource_view.Make (R)`, `views/pod.ml:64`, and that functor's `unmarshal`, `resource_view.ml:58-68`, returns `Err.Kind_mismatch` unless the kinds match), and the phase's OWN DELETION mutant of `:126` - the conjunct removed from `ok_list_resp_shape` outright - was **SEEN GREEN EVERYWHERE**: `p24_state_predicates`, `p24_mutation`, `p24_regression` and `p23_local_binding` all RC=0, nothing in the tree observing its absence. A red from STRENGTHENING an entailed conjunct is a red about reachability, not about load-bearing, so the earlier "exactly as 2.3(1) predicted" reading of it is **WITHDRAWN**. The conjunct STAYS (fidelity), disclosed as entailed-and-not-separately-killable in `state_predicates.ml{,i}` the way `:65` and `:113`/`:114` are. **THE ROW NOW TARGETS `:128`** (`Option.is_some om.name` -> `Option.is_none om.name`), which no neighbour entails - `unmarshal` passes `Dynamic_object.metadata` through without reading `name`, `:126` reads only the kind, `:129-130` only the namespace, and `:132` is `:127` quantified. **OBSERVED there, and THIS is what discharges 2.3(1)'s "killable at GRAPH level, no forged response" ruling**: 5 failures on `p24_state_predicates` - all four `legs` cases plus the `scope_exclusion_pin` coupling row - with `violated` naming `vsts_pending_list_pod_resp_in_flight` and the replica attributing 8 red states on SP0, while `p23_local_binding`, `p23_mutation` and `p23_regression` stayed GREEN in the SAME run. State: the `m3_shape_conjuncts` accepted-control reddened after all six of its vacuity controls passed. Both mutants reverted with the Edit tool. **THE `:128` HALF IS WITHDRAWN AS A CLAIM ABOUT `:128`, BY THE DELETION MEASUREMENT IN 0.5, AND FOR THE SAME REASON THE `:126` HALF WAS WITHDRAWN.** `Option.is_some om.name` -> `Option.is_none om.name` is a FLIP, and `om.name` is `Some` at every object of every ok list-response on all four graphs, so the flipped conjunct is FALSE on the whole population and the leg reds by FALSIFICATION - the same defect as `M2a'` in 0.4. The DELETION of `:128` is **GREEN on all 82 executables** (row D20). `:128` therefore has NO red capability in the shipped tree, this row discharges nothing about `:128`, and **2.3(1)'s "killable at GRAPH level, no forged response" ruling is NOT discharged by it, nor by any other shipped M3 conjunct** |
| M3b | flip a token inside the ported `weakly_eq` | **NOW REQUIRED** - section 2.3(3) resolved non-zero (P5), so `weakly_eq` is written; state-level analogue M3d is CLOSED in `t_p24_mutation.ml` | **PARTLY KILLED, THEN RETIRED - see P10 and 2.3.1.** METADATA arm tautologised: **KILLED at STATE level** by the M3d row (`Expected: false / Received: true`), graph level unmoved as a weakening mutant must be. SPEC arm tautologised: **SURVIVED**, a real test gap. `weakly_eq` is now REMOVED with its conjunct, so the row is not re-runnable and no later stage may claim it |
| M3c | flip a containment direction in the ported `:116-118` set equality | state-level analogue CLOSED in `t_p24_mutation.ml`; graph-level row is stage C's | **RETIRED WITH THE CONJUNCT (2.3.1).** The source mutant was never run and the state-level analogue is REMOVED from `t_p24_mutation.ml` - `:116-118` is EXCLUDED-WITH-A-PIN on the SCOPE ground, so M3 is green on that state. The evidence was PROMOTED: the same containment direction is now measured over the four real graphs and pinned at 0/4/0/40 (`set_equality_resp_extra_*`), which outranks a red on a forged state |
| ~~M2a (sketch)~~ | ~~swap the Pod kind constructor in the ported ListRequest shape~~ | **REJECTED** - L2 already carries `:53-56`, so it reds P23 too and cannot discriminate | NOT RUN, by ruling |

#### 5.0.1 The CONTROL-DE-TAUTOLOGISING rows, applied and OBSERVED

The two probe-control partitions were rewritten so neither complement is the
positive projection subtracted, and each rewrite was confirmed by mutating the
positive projection to a constant. Every row below is an OBSERVATION, run on the
staged tree, killed by an **assertion** (no build error, no timeout - each run
completed in ~2s), and reverted with the Edit tool - `git checkout --` /
`git restore` were never invoked. After the last revert `git diff --stat` is
EMPTY and `git status --short` lists only the intended P24 entries, so no mutant
residue survives.

**Line anchors below are re-derived against the SHIPPED tree.** The numbers the
rows were first written with (`:698`, `:708`, `:793`, `:785`) were the line
numbers of the trees that actually ran; the reconciliation pass edited comment
blocks above them, and the review-fix pass then converted every case in the file
to the accumulating shape (section 5.0.2), which moved them again. Where they
differ, the ORIGINAL is given alongside. **The row LABELS below are the stable
anchor** - line numbers in this table are a convenience, the quoted assertion
text is the identity.

| row | mutant | OBSERVED |
| --- | --- | --- |
| MC1 | `P24_witness.ok_resp_with_owned_objs` -> constant `true` | **KILLED** at `t_p24_state_predicates.ml:1010` (`:698` when it ran), `SP0: B3 control: owned <= the premise population`, `Expected: true / Received: false`. Reshaped to MC1' because the subset row fired before the partition row. |
| MC1' | `P24_witness.ok_resp_with_owned_objs` -> constant `false` | **KILLED** at `t_p24_state_predicates.ml:1022` (`:708` when it ran), the three-way B3 partition row, `Expected: 8 / Received: 0` on SP0. This is the row that was previously unfailable. |
| MC2 | `P24_witness.pending_src_is_controller` -> constant `false` | **KILLED** at the `Controller_this` bucket-agreement row - `t_p24_state_predicates.ml:1366` in the shipped tree, `:793` in the PRE-REORDER tree that ran it - `Expected: Some 0 / Received: Some 16`. B4's rows were then reordered so the partition speaks first, which is what moved that row. |
| MC2' | same mutant, after the reorder | **KILLED** at `t_p24_state_predicates.ml:1340` (`:785` when it ran), the B4 partition row itself, `Expected: 16 / Received: 0` on SP0. |
| MC3 | MC2 live **and** the OLD subtracted complement `parked_with_pending && not pending_src_is_controller` restored | **THE PARTITION ROW PASSED.** The case log shows the partition `ASSERT` completing and the failure moving to the new histogram backstop. This is the direct measurement that the shipped-A partition control was a green that could not have been red; the histogram route is what gives it teeth. |

The "fired before" / "the failure moved to" readings in MC1 and MC3 are
statements about the SEQUENCING THAT RAN THEM. Under 5.0.2's accumulating shape
those cases no longer stop at a first red, so a re-run of MC1 would name the
subset row and the partition row together. What each row ESTABLISHED - the
mutant seen red, on the named assertion - stands; the "which row spoke first"
half is history and may not be quoted as current behaviour.

#### 5.0.2 The REVIEW-FIX rows (four audit defects), applied and OBSERVED

Four defects were found by an independent audit after the seal. Three of the
fixes make a claim that only a mutant can settle, so each was run. Same
discipline as 5.0.1: applied and reverted with the Edit tool, never
`git checkout --` / `git restore`; each kill is an ASSERTION failure, not a
build error or a timeout; `git diff` against the staged blob is EMPTY for every
mutated file afterwards.

| row | mutant | OBSERVED |
| --- | --- | --- |
| RF-D2 | drop `Vsr.Init` from `p24_witness.ml`'s `all_steps` (an OCCUPIED column: 8 / 52 / 48 / 616) | **BOTH ROWS REPORTED, ON ALL FOUR LEGS.** `p24_state_predicates` `step_histogram` fails with an EIGHT-element list: the columns-are-the-seventeen-steps row AND the later columns-SUM-to-decoded row, for SP0 (`expected 76, got 68`), SPc (`680 / 628`), SPd (`1056 / 1008`) and SPm (`8872 / 8256`). Under the pre-fix `Alcotest.check` sequence only SP0's FIRST row would have been reported and the other seven would have gone unmeasured. This is the direct measurement that the accumulating shape now covers the whole file and not `check_leg` alone |
| RF-D3 | `state_predicates.ml` M3's `source` -> `"...state_predicates.rs:107 (shape conjuncts only)"` (a parenthetical qualifier, the MB8 shape) | **DIFFERENTIAL, both halves run.** With the row written against COMMITTED LITERALS: `p21_regression` `family_classification` RED, `Expected: [] / Received: [("vsts_pending_list_pod_resp_in_flight", "...state_predicates.rs:107")]`. With the OLD self-filtering row (`missing_from_roster (Sp.predicate_family ...)`) restored and the SAME mutant live: **exit 0, 6 of 6 cases green.** The old row could not see a drifted source at all, because it filtered `roster_pairs` against pairs recomputed from the value the roster entry itself holds - P22-review finding F2 |
| RF-D4 | `state_predicates.ml` M1's `holds`: `~absent:true` -> `~absent:false` (the vacuous-TRUTH token) | **KILLED, and the entailment claim REFUTED.** `p24_mutation` `mp5_premise_wiring`: the `interesting = 0 over ALL of SP0 at controller_id + 1` row logs `ASSERT` and PASSES, and the row below it - `red = 0 ... at controller_id + 1` - FAILS `Expected: 0 / Received: 88`. So the red column is NOT a restatement of the interesting column: the two read opposite arms of the same `at_reconcile` fold and one token separates them. The justification the audit struck (`the CUT M2 candidate read the id a SECOND time through :49`) was false and is replaced by this measurement |

Defect 1 (stale cites) is not mutation-testable and was closed by re-resolving
every citation into this phase's edited files against the shipped line numbers.

**Also required in stage C, and missing from the sketch:** run
`Pair_guard.pair_leaks` in BOTH argument orders against the full roster and
confirm `[]`. P24 gets a roster entry in `shipped_suites`/`committed_roster`
(`t_p21_regression.ml:272-316`), exactly as P23 did (`:249-257` documents the
precedent), and that check is not automatic.

**RUN, AND `[]` BOTH WAYS.** Measured by temporarily instrumenting
`t_p24_regression.ml` (print block removed afterwards; `git diff --stat` shows
only the intended P24 entries): roster swept = **15** suites, family = **2**
members, roster pairs = **67**; ORDER A (`family_pairs` = P24, `suite_pairs` =
roster) = `[]`, ORDER B (arguments swapped) = `[]`. The detector is SEEN
red-capable in the same run by the roster's own P24 self-entry reporting
`2 * 2 = 4` hits, so `[]` is a measured absence rather than a broken traversal.
**RE-MEASURED AFTER THE M2 CUT, not adjusted by arithmetic**: with the third
member the same probe reported family = 3, roster pairs = 68 and `2 * 3 = 6`
self-hits. The self-hit count is also ASSERTED every run, as
`2 * List.length family`, so that half of the control cannot go stale.

### 5.1 Pin safety - a type-signature fact, plus two hazards to simply not create

Family-blindness is not a convention. `Model_check.explore`
(`model_check.mli:57-63`) takes NO invariant at all, and `check_safety` /
`check_reaches` (`:96-117`) apply the invariant only AFTER `explore` has built the
reachable graph. `run_leg` (`fault_check.ml:268-300`) hardcodes
`~equal:faulted_equal ~hash:faulted_hash` and exposes neither to any of its 14
(soon 15) call sites - all verified sharing the same two top-level bindings
(`fault_check.ml:46,54`; call sites `:276-277, 324, 377, 508, 580, 628, 683, 714,
771, 817, 876, 1039, 1091, 1140, 1203`).

**HAZARD 1, named by no one in the selection sketch.** That blindness is
contingent on nobody editing the SHARED `faulted` block itself
(`fault_check.ml:37-145`: the type, `faulted_equal`, `faulted_hash`,
`faulted_successors`). Every leg reaches it through `run_leg`, so a
P24-motivated widening of it - for instance to host `weakly_eq`-based comparison
for M3 - would retroactively perturb **all fourteen** legs' graphs at once, not
just the new one. Do not touch it.

**HAZARD 2.** The mutation matrix must NEVER mutate `objects_to_pods` or
`pod_filter` in place. They are live production logic called from the reconcile
path in the same file (`v_stateful_set_reconciler.ml:537` and `:544`), so
mutating the shared implementation would alter reconcile behaviour, hence
reachability, hence the pins. Mutants go in the NEW family only. EXPORTING is
safe; MUTATING is not. (Refute verdict C21, confirmed; adopted.)

**The E-ledger is untouched in EFFECT, not merely in intent.** Every assertion in
`t_p21_regression.ml:505-583` filters on the literal prefix
`"vstatefulset_controller/proof/internal_rely_guarantee.rs:"` (`:468-469`), and
every P24 source is `state_predicates.rs:NNN`. The near-certain P24 roster
addition cannot reach the guarantee-prefix filter.

**A moved pin is a phase-STOP, never a retune.**

### 5.2 Conventions this family is bound by

- **Source strings MUST be BARE** (`state_predicates.rs:192`, no parenthetical).
  The roster parser at `t_p21_regression.ml:479-483` uses `String.rindex_opt ':'`
  + `int_of_string_opt`; a qualifier makes the member silently DROP OUT of the
  roster while the firewall pin still passes. The per-conjunct partition goes in
  a companion pin COMMENT, never in `sources`.
- **`locally_at_step_or!` renders as an EXHAUSTIVE 17-arm match** on
  `V_stateful_set_reconciler.step`, grouped arms, NO wildcard, per `step_binding`
  (`local_binding.ml:227-240`). Never `List.mem` over a literal step list - that
  silently omits a newly-added step instead of forcing a revisit.
- **Eliminate the index.** Upstream indexes at `:235-238`
  (`needed[needed_index]`, `needed[needed_index - 1]`). No `List.nth`, no
  `arr.(i)`, no guarded raw-index wrapper. (`List.nth_opt` appears across
  `lib/controllers` but NOT in `lib/assurance`, whose own `.mli` claims exactly
  this at `local_binding.mli:292-293`.) **BUILD-VERIFIED CORRECTION:** the
  ruling and `MAIN-LOOP-GROUND-TRUTH.md:79` name `List.to_seqi` + `Seq.find_opt`
  and **NEITHER EXISTS on this switch (OCaml 5.3.0)** - only `String` and
  `Array` have a `to_seqi`, and `Seq`'s selector is `find` / `find_map`. Stage A
  hit two build failures on exactly that. The shipped rendering is `List.mapi`
  to pair each slot with its ordinal plus `List.find_opt` to select
  (`state_predicates.ml`'s `with_ordinals` / `slot_at`), which is the same
  index-elimination with names that compile. Do not re-quote the `to_seqi` form.
- **No exceptions, no two-arm match on `Option`/`Result`** - combinators only.
  `Option.fold ~none:` is EAGER, so never put a recursive call in it.
- **`p24_witness.ml` is UNLISTED in `test/dune`** so dune links it into every exe
  that references it. Three tiers: DERIVED chain re-exports
  (`p24_bound = P23_witness.p23_bound`, `sp0_states = bl0_states`, ...), shape
  constants, then ONE measured block. **NO PINNED NUMBER MAY APPEAR IN TWO
  FILES**; the single sanctioned exception is `t_p24_regression.ml` re-typing
  INHERITED literals as a firewall.
- **`test/dune (names ...)` goes 79 -> 82**: `t_p24_state_predicates`,
  `t_p24_mutation`, `t_p24_regression`.
- **Build/test invocation:** `opam exec --switch=anvil-ocaml -- dune build @default`
  and `@runtest`, from the repo root. `dune` is NOT on PATH. Never pipe through
  `tail` - that reports tail's exit code and manufactures a fake green.
- **`lib/assurance/dune` and `lib/checker/dune` need ZERO edits** (no
  `(modules ...)` restriction, no hand-written wrapper `.mli`); warning 9 is off
  identically in all three stanzas (`lib/assurance/dune:6`, `lib/checker/dune:6`,
  `test/dune:26`).

### 5.3 Doc debt - 3 defer to P25, 1 NEW one rides P24

The three debts recorded at phase start are CONFIRMED verbatim as read today, but
NONE is scheduled onto P24: P24's file list never opens `internal_guarantee.mli`,
`BUILD-SPEC-P23.md`, or `p21_witness.ml`, and P24's own text already cites the
correct facts around each drift, so leaving the stale prose does not corrupt any
P24 citation. They ride P25's reconciliation battery.

**NEW, previously unrecorded, and it DOES ride P24** because `fault_check.mli` is
a file P24 already opens to append the 14th leg's doc block:
**`fault_check.mli:2035-2038`** claims the P23 leg "retires P21's E3/E4/E5
deferral". False - only E4/E5 retire; **E3 stays excluded**, per the same commit's
`local_binding.mli` and the committed `ledger_e3_lines` pin. Two-line drive-by
correction; verify the exact current text before editing.

Second-order: `BUILD-SPEC-P23.md:360`'s `internal_guarantee.mli:185/:197`
citation is accurate TODAY but is a dependency of the first debt's eventual fix -
re-verify (do not re-derive) it whenever that lands. A P25 obligation, not an
edit today.


## 6. Files - SETTLED

- `lib/assurance/state_predicates.ml` / `.mli` - NEW family, surface
  `predicate_sources` + `predicate_family`.
- `lib/checker/fault_check.ml` / `.mli` - the 14th leg
  `check_state_predicates_under_faults`, appended. **Do NOT touch the shared
  `faulted` block at `fault_check.ml:37-145`** (section 5.1 hazard 1).
- `lib/checker/fault_check.mli:2035-2038` - two-line doc-debt correction that
  rides P24 because the file is already open (section 5.3).
- `lib/controllers/v_stateful_set_reconciler.mli` - EXPORT `objects_to_pods`.
  Pure-visibility addition, no `.ml` body edit, mirroring
  `vreplica_set_reconciler.mli:60` (section 2.3(2)). `pod_filter` is NOT needed -
  it belongs to an un-selected upstream member.
- `test/p24_witness.ml` - UNLISTED in `test/dune` per the witness convention;
  single source of truth for every new number.
- `test/t_p24_state_predicates.ml`, `t_p24_mutation.ml`, `t_p24_regression.ml` -
  registered in `test/dune (names)`, which goes **79 -> 82**. `t_p24_mutation`'s
  `m2_novel_conjuncts` case is REMOVED with the cut member (2.2); its evidence
  moved to `t_p24_state_predicates`'s B4 case, which is a MEASURED pin over the
  four real graphs and therefore strictly stronger than the forged states it
  replaces.
- `test/t_p21_regression.ml` - the roster entry in
  `shipped_suites`/`committed_roster`, per the `:248-256` precedent, plus the
  `Pair_guard.pair_leaks` check in both argument orders.
- **CUT, with its helpers:** the M2 candidate (`req_msg_is_list_pod_req` /
  `pending_list_pod_req_in_flight`) and, with it, `req_msg_is_list_pod_req`'s
  rendering, `list_req_content_matches` and `matching_resp_in_flight` in
  `state_predicates.ml`, plus the `:45` entry of `predicate_sources`. Section
  2.2 is the finding. `P24_witness`'s `pending_src_*`, `pending_still_in_flight`
  and `delivery_window` probes are KEPT and are now that finding's asserted
  evidence.
- `weakly_eq` (`predicate.rs:26`) is written into the family **only if** the
  stage-B `owned_objs` measurement comes back non-zero (section 2.3(3)); it is
  ~4 lines from already-public primitives, not a plumbing project. It came back
  non-zero (8/60/40/776), so `weakly_eq` WAS written and live, together with
  `valid_owned_object` (`predicate.rs:44-52`), `etcd_valid_owned_refs`,
  `ref_set_equal` and `owned_objs`. **ALL FIVE ARE NOW REMOVED (2.3.1): the
  SCOPE exclusion took their only consumer, and a helper whose last consumer
  goes away goes with it.** `state_predicates.mli` records `weakly_eq` as
  PORTED, metadata-arm MUTATION-KILLED, spec-arm a measured TEST GAP (P10), and
  removed for SCOPE and not for defect - four lines to restore.
- `lib/assurance/dune` and `lib/checker/dune` need **zero** edits.

## 7. Limits and inherited debt, disclosed

**Stale blockers this wave RETIRED (do not re-raise them):**

1. `BUILD-SPEC-P23.md:760-761` "P24 must bring a de-vacuizing spine WITH it" -
   **the spine already exists**: `Scenario.vsts_seed_multi` (`scenario.mli:323`)
   and `vsts_seed_multi_faults` (`:304`), consumed by shipped legs, gate pins
   6952 (P12 fair) and 2784 (P13 G2 crash).
2. `BUILD-SPEC-P23.md:752` "candidate B CANNOT BE RED" - **overstated**. Single-
   token SYSTEM mutants (`api_server.ml:300`/`:301`) would red inv1/2/4/5. The
   spec conflated mutating the SEED with mutating the SYSTEM. Candidate B's
   NO_GO survives on a DIFFERENT ground: it ships zero new upstream register,
   and inv1-6 are already leg-asserted (P11 S1 pins 38/50/38/25/44; P13 G1 gate
   388) with inv6 already non-vacuous multi-CR (P12 gate 6952, P13 G2 2784).
3. `p23_witness.ml:83-85` "adds Update_needed / Get_then_update traffic no
   committed graph contains" - **refuted** by committed `g3_interesting`
   4/32/16/704 (`p22_witness.ml:176`/`180`/`184`/`188`).
4. `BUILD-SPEC-P23.md:765`'s novelty-gate literal - broken, see section 1.
5. `t_p13_faults.ml:334` is a **singleton** `~desireds:[ desired ]`, so it is
   NOT multi-CR evidence. The real committed multi-CR measurements are P15's
   3864/10552 and P13 G2's 2784.

**Live documentation debt P24 must not cite as current (scout H, verified):**
`internal_guarantee.mli:160-171` still says "4 shipped + 5 excluded ... E4 `:613`
/ E5 `:640` deferred, the strongest remaining unoccupied register". P23's 6+3
re-partition superseded that (`t_p21_regression.ml:577-583`, the 6 + 1 + 1 + 1
totality row; `:549` was never a line of that file), and the text carries no
supersession marker. Also cite `p21_witness.ml:140-144`, NOT the drifted
`:148-152`. And `BUILD-SPEC-P23.md:740` says "helper_family at
`fault_check.ml:1134`" - `:1134` actually holds `guarantee_family`; it is the
swap SITE, not helper_family's definition.

**PIN SAFETY.** The leg rides the four committed graphs and graphs are
family-blind (`Model_check.explore` receives no invariant,
`fault_check.ml:274-279`), so NO committed graph pin can move: P13-P21
**76 / 464 / 744 / 1976 / 116**, P22 **88 / 808 / 1144 / 10216** with gates
**20 / 276 / 96 / 2080**, P23 gates **68 / 560 / 816 / 7920** all stay
byte-identical, and they DID, before and after the M2 cut. Gate counts are
leg-local AND family-dependent, so P24's own gate numbers are not pins at all:
they are printed prose, they moved from 68/560/640/8088 to 60/516/608/7360 when
the cut removed a member's `interesting` from the union, and nothing asserts
them against a literal (0.2). Because every P24 source string
is `state_predicates.rs`, the E-ledger sweep (`t_p21_regression.ml:505-583`) is
untouched. **A moved pin is a phase-STOP, never a retune.**

**COST, MEASURED by scout I.** No new graphs means the P22-precedent battery
scale (~67 s). The named cliffs to stay away from: `reconcile_ceiling = 3` DNF'd
at **9m50s with no verdict** on `[1;1]` (`p13_witness.ml:16-20`), and a multi-CR
pod-monkey graph is estimated 45k-100k+ states.

**DEFERRED TO P25**, in the judge's priority order:

1. `:256` `local_state_is_coherent_with_etcd` as the flagship - **but its
   precondition has CHANGED (2.3.1).** P24 did land `weakly_eq` with a seen-red
   row and then EXCLUDED the conjunct that consumed it, on a SCOPE ground, so
   `:256` inherits that exclusion and the rely-condition question underneath it
   rather than a rendered precedent. Either P25 lands rely-condition machinery -
   which retires this pin and brings `:116-118`, `:119-124` and `weakly_eq` back
   into scope together - or it excludes `:256` on the same ground. It may not
   commit an etcd-coherence conjunct without answering that first.
1a. **UPSTREAM `:49`'s REJECT DIRECTION, carried exactly the way `:112`'s is.**
   Every pending request on every P24 graph is `Controller(controller_id,
   cr_key)`-sourced (`pending_src_not_controller_everywhere = 0` over
   16/112/288/1560), which is what CUT M2 (2.2). Buying it needs a seed that
   parks a request sourced elsewhere, and **adding a seed moves the shared
   graphs**, so P24 did not add one. A phase that wants the request-side
   register must budget that seed and the pin re-measurement it forces, and must
   NOT re-ship the member on the strength of `M2a'` alone - see 0.4.
1b. **THE EIGHTEEN CONJUNCT SITES WITH NO RED CAPABILITY (0.5), AND THE CHOICE
   BETWEEN THE TWO ROUTES THAT WOULD BUY THEM.** M1 `:194`, both halves of
   `:195` and `:196`, `:230-231`, `:235`-`:240`, `:242`, `:248`, and M3 `:128`
   plus the `{:126, :127, :132}` class are all SHIPPED and all measured GREEN
   under deletion. The FORGED-STATE route (one `t_p24_mutation` row per conjunct,
   the `M1a`/`M1b` pattern) is seed-free and moves no pin, and would buy all
   fourteen M1 sites and `:128`; the GRAPH route, the only one that could make
   BL0/BLc/BLd/BLm carry the coverage, needs a new seed or a new fault dimension
   and **moves the shared graphs and every committed P13-P23 pin with them**, so
   it is the same budgeted decision as 1a. Nothing can buy the
   `{:126, :127, :132}` class member-by-member; it is mutually entailing and only
   the class is killable. P25 must choose deliberately, and must not read the
   leg's CLEAN verdict on four graphs as having already covered these.

2. **The E3 lift** (`internal_rely_guarantee.rs:606`) on the multi-CR zero+crash
   spine at rc=2. It was the strongest runner-up and its spine blocker is
   retired, but its red capability is only INFERRED - the `api_server.ml:287`
   mutant was never run and may be preempted by the seed-integrity gate. Two
   named probes must run first. The sanctioned three-file E-ledger re-partition
   rides with it.
3. The `vct:true` PVC leg, gated on a Get_pvc/Create_pvc step-occupancy probe.
4. **The reconciliation battery** (scout H's `t_p2X_reconcile`): tuple /
   partition / case-count / cite-pin legs, landed in the SAME change as the
   D1/D2/D3 documentation fixes so the fix pass is GATED rather than trusted.
   P23's evidence for needing this is that its own fix pass introduced six new
   prose inconsistencies. It ships zero upstream register, so it rides P25
   rather than being a phase.
5. Outdated-pipeline members `:773`-`:852`, pending a de-vacuizing seed probe.
6. Resp-side create/update/delete members, pending one replica probe measuring
   resp-in-flight counts on all four committed graphs.

**REJECTED outright** (do not re-open without new evidence): candidate B (zero
new register), candidate C / `fault_report.family` (**MC2 is not exhibitable** -
`binding_family` is refuted by the committed pins alone, and `helper_family`'s H1
premise is true at the very seed of all four SL graphs, so its union
near-certainly moves the pinned 20/88), and any `reconcile_ceiling>=3` or
multi-CR pod-monkey graph shape.

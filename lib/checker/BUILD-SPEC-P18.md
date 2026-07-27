# BUILD-SPEC-P18: VSTS pod/PVC metadata invariants (helper_invariants.rs)

Normative spec for Phase 18, branch `p18-helper-invariants` off `0c0662d` (P17).
The P2..P17 spec discipline. Upstream ref file:
`anvil-ref/src/controllers/vstatefulset_controller/proof/helper_invariants.rs`
(1494 lines, 11 StatePreds of which only 4 are true always-invariants; this
phase ports the 2 that are portable, ledgers the rest). Scout evidence:
7-agent workflow `wf_b08dde8b-48a` (0 errors), archived at
`<scratchpad>/p18-scout-evidence.json` — build agents consult it before
re-deriving anything.

Build environment: `eval $(opam env --switch=anvil-ocaml --set-switch)`, then
`dunecho build`. `dune test` HANGS — run exes under
`perl -e 'alarm 150; exec @ARGV' _build/default/test/<name>.exe`.

## 1. Why this phase (evidence-driven, from the P17 scout + this session's 7-scout workflow)

1. **Named by P17's own scouting** (5-scout wf `wf_2a157137-4f7`, all
   GO_WITH_CHANGES): the vsts_controller_proof pod-metadata member was the
   recorded best P18 candidate.
2. **Genuinely new content, swept — no P16-F1/P17-premise-break recurrence**:
   `all_pods_in_etcd` has ZERO hits in the port; NO shipped invariant reads pod
   `finalizers` anywhere in lib/assurance or lib/checker (the only finalizers
   code in assurance is the P16 oracle model); none asserts
   deletion_timestamp-None or exactly-one-owner-ref over stored pods. The
   member is absent from every shipped suite, so classification is the
   P14-P16 DISJOINT-family pattern — P17's filter pattern is structurally
   unavailable (the member is CR-parameterized; nothing in
   `cluster_structural` corresponds).
3. **Zero seed cost + a live empirical headline**: pods already exist in the
   shipped fault graphs (P17 measured S1/S3 firing on 52/76 L0 states), so the
   family is non-vacuous on day one. And upstream proves the pod member ONLY
   under `vsts_rely_conditions_pod_monkey` (helper_invariants.rs:82,
   rely_guarantee.rs:17-29) while the port's monkey is unconstrained — whether
   the member survives the Lm leg is a real, undecided-by-static-reading
   measurement (section 4, prediction 4).

## 2. The family (lib/assurance/helper_invariants.{ml,mli})

Module named after the upstream FILE, the house convention (objects_in_store,
req_resp, correspondence). **Disambiguation, disclosed in the .mli:** the
shipped `inv_self` source string cites
`vstatefulset_controller/proof/helper_invariants/predicate.rs (widened inv9)`
(vsts_invariants.ml:217) — that directory layout belongs to
vreplicaset_controller; vstatefulset has the single file
`proof/helper_invariants.rs`. The drifted string is NOT fixed this phase
(moving a shipped `source` string moves k3 (name, source) pins in four
committed regression exes); recorded as a residual in section 8. P18's own
source strings cite the REAL path.

Signature mirrors `Vsts_invariants`: the family takes the CR (and whatever
`Vsts_invariants.always` threads — B1 confirms the exact signature from
`vsts_invariants.mli`) and returns `Invariants.invariant list`. The family
stays **CR-parameterized like upstream** — a universal closure over all CRs
would be a genuine k5-class strengthening and is NOT taken (section 8).

### H1 — the pod member (upstream :52-69, VERBATIM transcription target)

```
name   = "all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref"
source = "vstatefulset_controller/proof/helper_invariants.rs:52"
```

Upstream body (helper_invariants.rs:52-69): for every stored `pod_key` with
`kind == PodKind && namespace == vsts.namespace && pod_name_match(pod_key.name,
vsts.name)`, the object has `deletion_timestamp is None`, `finalizers is None`,
and `owner_references == Some [r]` for some `r` with
`owner_reference_eq_without_uid(r, vsts.controller_owner_ref())`
(owner_reference.rs:37-42: compares controller/block_owner_deletion/kind/name,
uid EXCLUDED).

Port rendering decisions (each disclosed in the .mli):

- **Name matcher**: the port has NO `pod_name_match`
  (upstream predicate.rs:146-148 is existential over nat ordinals through the
  uninterpreted-but-trusted decimal rendering `int_to_string_view`,
  string_view.rs:41 — the abstract-string existential belongs to
  `pvc_name_match`'s TEMPLATE component, predicate.rs:140-143). Use the
  constructive inverse: `Option.is_some (get_ordinal <parent> <name>)`
  (v_stateful_set_reconciler.ml:206-214, already used by
  vsts_invariants.ml:245, `inv_ordinal`).
  **MEASURED-CORRECTION (P18 review, 2026-07-27; doc-only — no code or pin
  moves):** this bullet previously called the port matcher STRONGER (a
  subset of upstream's names). Under upstream's own trusted exec axioms —
  `i32_to_string`/`usize_to_string` (string_view.rs:20-32) pin
  `int_to_string_view` to Rust's `to_string`, canonical decimal — the two
  matchers AGREE on every name whose ordinal fits in an OCaml int;
  non-canonical renderings (e.g. a `00` segment) match NEITHER matcher (no
  int renders to `00`; injectivity gives at most one preimage). The
  strict-subset reading held only in nonstandard models of the
  uninterpreted fn, inconsistent with the trusted exec ensures (and in such
  models the subset direction can also invert). The only genuine
  strengthening corner is MAGNITUDE: ordinals beyond OCaml's `int` fail
  `get_ordinal`'s `int_of_string_opt` parse where upstream's unbounded nat
  would match. On reachable states the domains coincide — every stored pod
  name is minted by `pod_name` (canonical, small) and monkey candidates are
  the stored pods themselves (cluster.ml:748-755).
- **Owner-ref clause**: `Option.fold md.owner_references ~none:false
  ~some:(fun l -> match l with [ r ] -> Owner_reference.eq_without_uid r co
  | [] | _ :: _ :: _ -> false)` — the inv_self list-match shape
  (vsts_invariants.ml:192-196). Do NOT use `owner_references_contains` /
  `owner_references_only_contains` (both full-equality, uid-sensitive,
  object_meta.ml:72-80) and do NOT use `is_vsts_controller_owner` (a third
  equivalence that also ignores block_owner_deletion).
  `Owner_reference.eq_without_uid` exists and is exported
  (owner_reference.ml:26-30).
- **`co` is an Option**: `V_stateful_set.controller_owner_ref cr` returns
  Option (None when the CR lacks name/uid). Fold `~none:false` on the
  CONSEQUENT — conservative, red-capable (an ill-formed CR REFUTES rather than
  vacuously passes), the vsts_invariants precedent (:75, :126). Upstream
  excludes this corner by well-formedness. Related disclosed corner:
  `make_owner_references` degrades to `[]` when the CR lacks name/uid
  (reconciler:218-220), so `make_pod` can in principle emit
  `owner_references = Some []` — unreachable on the well-formed scenario CR.
- **`interesting`** = premise mirror (P14 N3 lesson — NO borrowing): there
  exists a stored object with kind Pod, namespace = CR's, name matching. Not
  "store non-empty" (that saturates — the P17 G7 lesson).
- **dt/finalizers conjuncts**: `Option.is_none` on both. NOTE for the matrix:
  no single-site source mutation can violate the dt conjunct — api_server
  create OVERRIDES request deletion_timestamp to None (api_server.ml:265-274,
  which passes owner_references AND finalizers through UNTOUCHED) — see MB3.

**Premise-inversion disclosure** (prevents an apparent-overlap misread): both
shipped VSTS pod invariants key ownership by OWNER-REF
(vsts_invariants.ml:66-67, deliberate); H1 keys by NAME SHAPE in the CR's
namespace. H1 is the name-keyed complement of inv_ordinal's owner-ref-keyed
quantification.

### H2 — the PVC member (upstream :1063, always-lemma at :1078)

```
name   = "all_pvcs_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_or_owner_ref"
source = "vstatefulset_controller/proof/helper_invariants.rs:1063"
```

B1 MUST first read upstream :1063-1076 verbatim and the port's PVC naming
(make_pvc, reconciler:279-288) and derive the PVC name matcher the same way
(constructive inverse of the PVC naming function; if the port ships no
inverse, write the round-trip matcher inside the family). The port's
`make_pvc` stamps NO owner reference (disclosed at vsts_invariants.ml:41-50),
which SATISFIES the no-owner-ref conjunct.

- On the four vct:false legs H2 is structurally vacuous (no PVC ever exists)
  — those are honest-vacuity rows, the P14 N5 discipline: per-member count 0
  IS the result, asserted per leg.
- Non-vacuity comes from the ONE vct:true leg (L0v, section 4).

**PRE-AUTHORIZED FALLBACK (do not improvise a different one):** if B1 finds
the PVC surface non-derivable (no canonical naming inverse, or upstream :1063
turns out not to be the three-None conjunction) — H2 moves to ledger entry E7
with the discovered blocker quoted, the family ships H1-only, the leg loses
`?vct` and L0v, and E4's pin degrades to document-only. Record the fallback as
a MEASURED-CORRECTION in this section, not silently.

**MEASURED (B1, 2026-07-27): H2 = GO; E7 stays empty.** Upstream :1063-1076
re-read verbatim: it IS the three-None conjunction, consequent order
`owner_references is None && deletion_timestamp is None && finalizers is
None` (:1071-1073), premise `contains_key(pvc_key) && pvc_key.kind ==
PersistentVolumeClaimKind && exists |vsts_name| pvc_name_match(pvc_key.name,
vsts_name)` (:1065-1068). TWO facts the section above under-specified, both
disclosed in the shipped .mli rather than spec-fixed: (a) upstream H2 takes
NO vsts argument — the name existential ranges over ALL strings and there is
NO namespace conjunct; the CR-parameterized port narrows the existential to
the scenario CR's name (premise narrowing, reachable-state domains coincide)
and faithfully adds no namespace conjunct. (b) The port ships NO PVC-name
inverse (v_stateful_set_reconciler.mli exports `pvc_name` only), so the
matcher is the in-family round-trip parse: strip `"vstatefulset-"`, split at
the FIRST dash (dash-free template = first segment, realising upstream
`dash_free`, predicate.rs:140-143), certify the remainder via the exported
canonical `get_ordinal` on the re-prefixed tail. `make_pvc`
(v_stateful_set_reconciler.ml:260-289) confirmed: name = `pvc_name tmpl
vsts_name ord`, CR's namespace, NO owner_references/finalizers/dt stamped.
Seed vct parameter name confirmed: `?vct:bool` on `Scenario.vsts_seed_faults`
(scenario.mli:89). Family signature confirmed against vsts_invariants.mli:11
(`cr` + `controller_id` threaded; controller_id unused by H1/H2, disclosed).

### Classification firewall

t_p18_regression pins DISJOINTNESS in the k3 style: the family's
(name, source) pairs leak into NO shipped suite or family, and vice versa —
via the NEW shared `pair_guard` module (D2, section 6). P17's committed pins
are duplicated as literals (the one sanctioned duplication).

## 3. Deliberate exclusions, each with a MEASURED pin (the Q4/P14-N5 discipline)

- **E1 the uid-exact sibling** (:36-49, eventually-only, lemma :700): differs
  from H1 ONLY in the owner-ref clause (exact equality incl. uid vs
  eq-without-uid); the gap is precisely the created-deleted-recreated-same-name
  CR corner (comment :33-35), which needs a CR-delete edge the port does not
  have (step alphabet step.ml:11-47 deletes pods only; the seeded CR is never
  GC-collectible). Pin: on the L0 replica, evaluate BOTH renderings state-by-
  state and assert delta = 0 (uid-exact never diverges from H1 fault-free);
  CONTROL: a forged state whose pod owner-ref carries a wrong uid must make
  the uid-exact rendering fail while H1 holds — the delta detector SEEN
  red-capable.
- **E2 the dead spec** (:248, `vsts_pods_only_have_one_vsts_owner_ref`): NO
  lemma and NO uses anywhere in anvil-ref/src (rg-swept this session).
  Document-only exclusion; cite the sweep in the .mli.
- **E3 the faults-disabled member** (:811, eventually-only, lemma :837):
  requires crash_disabled AND req_drop_disabled AND pod_monkey_disabled
  (:842-844) — structurally incompatible with a measured fault leg.
  Document-only.
- **E4 the owned-PVC GC member** (:796, always, lemma :1018): "PVCs OWNED by
  vsts" is empty in the port by construction — make_pvc stamps no owner refs —
  so the member is vacuous even at vct:true. Pin (cheap off the L0v replica):
  count stored PVCs carrying a non-empty owner_references = 0, with CONTROL
  count stored PVCs >= 1 (proves the detector looked at real PVCs). If H2
  falls back (E7), degrade to document-only and say so.
- **E5 the four schedule/reconcile members** (:1262/:1269/:1276/:1288):
  eventually-only (weak-fairness + leads-to premises; lemmas
  :1414/:1451/:1300/:1339). Document-only; portable someday as eventually
  legs, not as always members.
- **E6 the message sibling** (:1213, `every_msg_from_vsts_controller_carries_vsts_key`,
  always, cheapest upstream lemma — only there_is_the_controller_state):
  excluded because (a) the port's message-guarantee register is already
  occupied by shipped `inv_self` (widened inv9, vsts_invariants.ml:214-230),
  inviting exactly the apparent-overlap misreads P17's review flagged, and
  (b) its port rendering was not scouted; the phase's novelty claim is
  store-side. Pin: regression assert no shipped member name equals the :1213
  name (guards the register). REVERSAL CLAUSE: natural P19 candidate as part
  of a message-correspondence extension.
- **E7 (reserved)**: the H2 fallback slot — empty unless section 2's
  pre-authorized fallback fires.

## 4. The leg (Fault_check.check_helper_invariants_under_faults)

Clone the G7 shape (fault_check.ml:614-636: private `run_leg`, union gate,
`violated_of`, `budget_fault_taken`) with ONE disclosed deviation from G7:
**add `?vct:bool` (default false)** — G7's omission was a deliberate k6-class
scope cut; H2's non-vacuity floor needs the vct:true seed, and the arg pattern
already exists on `check_req_resp_under_faults`. Seed
`Scenario.vsts_seed_faults ~desired:1 ~crash:true ...` exactly as G7 plus the
vct threading (B1 confirms the seed's vct parameter name from scenario.mli).

There is NO `report_decisive` symbol in the repo (phantom — P17 scouting
confirmed): decisiveness is the local per-test projection
(t_p17_store.ml:71-74 shape).

Legs (bound = P13's, depth 40, desired 1; budget literals via the witness
chain — zero/lc/ld/lm re-exported through p17_witness.ml:49-52):

| leg | budget | vct | require_fault |
| L0  | zero {0;0;0}   | false | false |
| Lc  | crash {1;0;0}  | false | true  |
| Ld  | drop {0;1;0}   | false | true  |
| Lm  | monkey {0;0;1} | false | true  |
| L0v | zero {0;0;0}   | true  | false |

Cross-check constants: the four vct:false graphs must be EXACTLY
76 / 464 / 744 / 1976 (same seed, bound, budget as G7/P13-P17). If any
drifted, STOP and diagnose — do not retune. For L0v: B1 checks p16_witness
for committed vct-leg constants; if P16's L0v ran the same seed/bound/depth,
cross-assert its states count; else pin the new literal in p18_witness with a
note that it is P18's first vct graph constant.

Per-member counts: test-side LOCAL REPLICA (t_p17_store.ml:145-188 discipline)
— replica faithfulness asserted FIRST (states_of replica = leg's states_seen),
then fires-by-name over slices all/post_crash/post_drop/post_monkey, then the
union gate recomputed locally.

**Expected (predictions, to be measured; honest-negative discipline: record
refutations of these predictions as findings, not failures):**

1. All 5 legs clean + DECISIVE; the four vct:false graph constants match
   P13-P17 exactly.
2. H1 per-member counts = the P17 S1/S3 slice: 52 (L0) / 296 (Lc) / 376 (Ld)
   / 1624 (Lm). Mechanism: H1's `interesting` fires iff >= 1 matching pod is
   stored, and P17 measured S1=S3 on exactly the >=1-owner-carrying-pod slice
   (p17_witness.ml:72-76 forbids elevating that to a law — if the counts land,
   assert per leg as scenario fact; if they diverge, the premise difference
   (name-match vs owner-carrying) is the first suspect and the divergence is a
   RESULT).
3. H2 counts 0/0/0/0 on the vct:false legs (structural vacuity, the N5
   discipline) AND a strictly positive floor on L0v.
4. **Lm clean DESPITE the monkey-rely gap — the phase headline.** Upstream
   proves H1 only under `vsts_rely_conditions_pod_monkey` (forbids
   vsts-prefixed names and vsts owner refs in monkey creates,
   rely_guarantee.rs:57-73); the port's monkey is rely-UNCONSTRAINED but
   candidate-RESTRICTED: it re-sends the STORED pods byte-identically
   (pod_monkey.ml:57-100, cluster.ml:748-755) — create on a live key is
   rejected Object_already_exists, update merge preserves
   dt/uid/rv/status and re-takes the same owner_references/finalizers
   (api_server.ml:449-462), delete removes a no-finalizer pod outright, and
   delete+recreate mints a fresh uid which eq_without_uid ignores.
   DISPOSITION IF REFUTED: investigate the mechanism FIRST; the leading
   suspect is the update merge taking REQUEST owner_references/finalizers. A
   refutation reachable only by metadata the upstream rely forbids would be
   rely-consistent upstream behavior (divergence-disclosed, not a port
   defect) — but the shipped monkey cannot fabricate such metadata, so if Lm
   reds, suspect the port first.
5. Lm max_uid = 4 via monkey-DELETE + reconciler re-create. NOT
   "the monkey create really lands": BUILD-SPEC-P17.md:226's literal reading
   is FALSE (create on a present key is rejected; only delete frees the key).
   P18 must not import that premise; cross-note it when writing the .mli.

## 5. MEASURED (B3, 2026-07-27; B4 appends the matrix outcomes)

Runs: `t_p18_helper` legs + a temporary probe (deleted), branch
`p18-helper-invariants`, seed `Scenario.vsts_seed_faults ~desired:1
~crash:true ~req_drop ~pod_monkey ~vct ()`, bound = P13's, depth 40. Replica
faithfulness held on all five legs (replica `states_seen` = leg `states`).
Every pin lives in `test/p18_witness.ml` (single source); this table is
disclosure, not a second assertion site.

| leg | vct | budget | rf | verdict | states | gate | cws | ffs | uid/rv | c/d/m seen | H1 all/slice | H2 all/slice | wall |
|-----|-----|--------|----|---------|--------|------|-----|-----|--------|-----------|--------------|--------------|------|
| L0  | f | zero {0;0;0}   | f | clean+DECISIVE | 76   | 52   | 0   | 76  | 3/2 | 0/0/0 | 52 / —        | 0 / —   | 0.08 s |
| Lc  | f | crash {1;0;0}  | t | clean+DECISIVE | 464  | 244  | 388 | 76  | 3/2 | 1/0/0 | 296 / 244 pc  | 0 / 0   | 0.18 s |
| Ld  | f | drop {0;1;0}   | t | clean+DECISIVE | 744  | 272  | 0   | 152 | 3/2 | 0/1/0 | 376 / 272 pd  | 0 / 0   | 0.48 s |
| Lm  | f | monkey {0;0;1} | t | clean+DECISIVE | 1976 | 1520 | 0   | 152 | 4/4 | 0/0/1 | 1624 / 1520 pm| 0 / 0   | 2.26 s |
| L0v | t | zero {0;0;0}   | f | clean+DECISIVE | 116  | 80   | 0   | 116 | 4/3 | 0/0/0 | 68 / —        | 80 / —  | 0.05 s |

**Predictions, judged BY NUMBER:**

1. **CONFIRMED.** All five legs clean + decisive; the four vct:false graphs
   are EXACTLY 76 / 464 / 744 / 1976 (P13-P17 identity, no drift) and L0v is
   EXACTLY P16's 116.
2. **CONFIRMED — exactly.** H1 = 52 / 296 / 376 / 1624, the P17 S1/S3 slice
   TO THE STATE on every leg, including the post-fault slices (244 post-crash,
   272 post-drop, 1520 post-monkey). Asserted per leg as scenario facts
   (p17_witness.ml:72-76 discipline: the name-matched and owner-carrying
   premises coincide ON THESE GRAPHS, never elevated to a law).
3. **CONFIRMED.** H2 = 0/0/0/0 on the vct:false legs (honest vacuity, per-leg
   pinned) and the L0v floor is strictly positive: 80 of 116 states.
4. **CONFIRMED — the phase headline.** Lm clean + DECISIVE across 1520
   post-monkey H1-premise states: the rely-UNCONSTRAINED but
   candidate-RESTRICTED monkey cannot violate H1 on this graph. This measures
   the shipped monkey only (section 8.6 residual stands: a fabricating monkey
   remains future surface).
5. **CONFIRMED.** Lm max_uid_seen = 4 (= P16's Lm graph constant; max_rv = 4)
   via monkey-DELETE + reconciler re-create; asserted off the leg report in
   t_p18_helper. The false BUILD-SPEC-P17.md:226 literal reading was not
   imported.

**Measured beyond the predictions (facts, not corrections):**

- **L0v gate = 80 = H2's own count; H1's 68 states are a strict SUBSET of
  H2's 80.** Mechanism: the reconciler creates the ordinal's PVC before its
  pod, so a matching pod never exists without its PVC on this graph. Measured
  containment of this scenario, not a law.
- **E1 pin MEASURED: delta 0** on the L0 replica (uid-exact sibling vs H1
  state-by-state; the CR-delete corner is unreachable, as section 3 argued).
  Forge CONTROL is B4 scope (t_p18_regression).
- **E4 pin MEASURED: 0 owner-ref-carrying stored PVCs / 80 control
  stored-PVC (state, key) pairs** on the L0v replica, counting convention
  summed-over-states (disclosed in p18_witness.ml). Control 80 =
  h2_interesting_l0v because desired 1 mints at most one PVC per state — an
  observed coincidence of this scenario.
- Gate = the fault-slice H1 count on every fault leg (crash/drop move no
  store-side truth for this family; the monkey amplifies but cannot break it).
- Wall times: leg-only runs, startup-subtracted: 0.08 / 0.18 / 0.48 / 2.26 /
  0.05 s — all far under the ~150 s harness alarm.

## 6. P17 review-debt carried on this branch (D1/D2 — the kN roster has no k4; not minting one, section 8)

- **D1 uid-boundary forge parity** (P17 disclosed residual): t_p17_mutation.ml
  `test_s2_forge` gives the rv-boundary witness 4 checks (AT-counter, exact
  violated_names, interesting_fires, refuted/check_safety SEEN — :479-491) but
  the uid-boundary witness only the first 2 (:494-504). Fix: mirror :484-491
  for `uid_at_counter`; the header claim at :173-176 ("every forge runs
  through the leg's own check_safety with Refuted SEEN") becomes TRUE by the
  fix — reconcile its wording if it still overstates.
- **D2 pair_guard extraction** (P17 disclosed residual, bigger than recorded:
  BOTH `pairs_of` AND `pair_leaks` are byte-identical quadruplicates):
  t_p14_regression.ml:132/137, t_p15_regression.ml:175/180,
  t_p16_regression.ml:307/312, t_p17_regression.ml:145/153. Extract into
  `test/pair_guard.ml` — a non-(names) module (the dune tests stanza links
  those into every exe, p17_witness.ml:6-9 precedent) carrying its OWN alias
  of `Anvil_assurance.Invariants` (test/dune's -open flags omit it,
  test/dune:22-24). Rewire all 4 exes; t_p18_regression uses it from birth.
  Pure refactor: the 4 exes' assertions byte-unchanged, battery re-green is
  the proof.

## 7. Mutation matrix (Edit-applied, Edit-reverted, each revert re-verified by git diff; never `git checkout`; if the permission classifier DENIES a lib/ edit, record it and fall back to disclosed analysis — k7)

Six rows + per-conjunct forges. Every prediction is directional; a mutant
firing OPPOSITE to prediction is a harness bug until proven a finding (P14 M1
trap discipline).

- **MB1 owner-ref forge at source** (`make_owner_references` returns a 2-list
  `[co; co]`): predict ALL 5 legs red naming H1 at the first pod create.
- **MB2 finalizer stamp** (`make_pod` sets `finalizers = Some ["anvil.dev/p18"]`):
  create passes finalizers through UNTOUCHED — predict all 5 legs red naming
  H1. This is the finalizers-conjunct de-vacuizer: the conjunct is
  true-by-construction on every shipped graph (no scenario seeds finalizer
  pods), so MB2 is the ONLY source-level evidence the conjunct is load-bearing.
- **MB3 dt stamp, predicted-INERT negative control** (`make_pod` sets
  `deletion_timestamp = Some t`): api_server create OVERRIDES dt to None —
  predict ALL legs byte-identical (graphs AND counts). If MB3 moves anything,
  that is a harness bug or a real api_server finding — STOP and diagnose.
- **MB3' the compound dt mutant** (P17 MO-b precedent — no single-site dt
  mutant exists, as scouted): api_server create KEEPS request dt AND make_pod
  stamps dt. Predict red naming H1 (dt conjunct). Disclose compoundness in the
  row header.
- **MB4 PVC owner-ref stamp** (`make_pvc` stamps `Some [co]`): predict L0v red
  naming H2 while the four vct:false legs stay BYTE-UNCHANGED — the vct leg
  SEEN load-bearing. (Falls away with E7.)
- **MB5 cross-phase negative control** (P13's M1: restart KEEPS
  ongoing_reconciles): predict every P18 leg stays clean + decisive; only the
  known Lc graph movement appears (464 -> 152 was P14's G2 shrink; P17's MA
  moved its Lc pin 464 -> 452 — B4 records which constant moves HERE with the
  actual number). Proves pins move, not the family.

**Per-conjunct forges** (P14 pattern, D1 parity discipline FROM BIRTH — all 4
checks on every forge): forged states violating EXACTLY one conjunct each —
(H1) dt Some / finalizers Some / two owner refs / wrong-name owner ref /
`Some []` — plus (H2) an owner-ref-bearing / dt-stamped / finalizer-carrying
PVC (the H2 dt and finalizers forges are a P18-review addition: as first
shipped, H2's owner-ref conjunct was the only one with red evidence —
deleting the dt or finalizers conjunct from H2's `holds` left every exe
green). Each asserts the exact violated name via the leg's own
`violated_of`/`check_safety` with Refuted SEEN, plus a negative control
state seen NOT refuted.

**MEASURED-CORRECTION (B4, 2026-07-27): the "make_pod stamps" sites named
by MB2/MB3/MB3' above are DOUBLY absorbed, and the effective site is one
layer deeper.** `make_pod` pipes its md literal through `init_identity` ->
`update_identity`, whose identity re-stamp CLEARS `finalizers` and
`deletion_timestamp` (v_stateful_set_reconciler.ml:250-251) BEFORE any
create request is formed — a reconciler-side laundering layer this section
did not name (it attributed the dt absorption to the api_server override
alone). MEASURED: the md-literal variants (MB2-a, MB3-a) are FULLY INERT —
both exes green, every pin at its committed value. The rows were therefore
run at the laundering site itself (update_identity :250 for finalizers,
:251 for dt — the md fields as they leave the reconciler), labelled MB2-b /
MB3-b / MB3' (= :251 + api_server :273) in the exe banner. Row semantics
preserved; stamp site corrected; the extra absorption layer is itself a
measured datum (the dt conjunct now has THREE layers: md-literal laundered,
surviving stamp server-overridden, only stamp + passthrough reds).

**MEASURED (B4, 2026-07-27), row-by-row.** Protocol: each mutant
Edit-applied alone, `dunecho build`, `t_p18_mutation` + `t_p18_helper` run,
Edit-reverted, revert verified `git diff lib/controllers/ lib/cluster/`
EMPTY, rebuilt — six cycles (MB3 ran twice, once per layer), no
`git checkout`, no two rows ever live at once, no permission denial (k7
never fired).

- **MB1 — prediction REFUTED (recorded as a finding, the honest-negative
  discipline; green-where-red-predicted, diagnosed per the directional-trap
  rule).** No leg refuted: all five anchor violated-name checks printed
  `<none>`, every clean/decisive check passed. Mechanism: the admission
  guard `metadata_validity_check` (api_server.ml:90-97) rejects the
  2-controller create, so no pod is EVER stored and H1's premise STARVES —
  P17's MO-a row measured this same absorption for this same mutant, which
  the MB1 prediction contradicted (the two predictions could not both
  hold; MO-a's won). Measured collapse: L0 graph 76 -> 68 (replica faithful
  at 68), H1 fires 0 on L0, Lc post-crash gate 0, Ld post-drop gate 0, Lm
  monkey edge STARVED (`max_monkeys_seen` 0 — candidates are the stored
  pods), L0v H2 floor SURVIVED (make_pvc does not call
  make_owner_references) while H1's premise died; every H1 forge failed
  loud at base extraction ("stored pod: missing"). H1's two-ref red
  capability is SEEN at forge level (`test_h1_owner_forges`); the
  double-guard reading (guard, not the member, keeps the store clean) is
  re-confirmed for the name-keyed member.
- **MB2 — CONFIRMED at the effective site (MB2-b, :250).** All five legs
  flip clean -> Refuted naming H1 (anchor's first check printed the full
  name; all five `t_p18_helper` legs reddened at `outcome clean`, L0v
  included). Graph pins HELD (L0 76 / L0v 116 in seed_shape) — the
  finalizer-carrying pod is ADMITTED, so the api_server passthrough claim
  is confirmed while the reddening is H1's own `is_none finalizers`
  conjunct: the ONLY source-level evidence the conjunct is load-bearing,
  as predicted. (MB2-a: inert, see the correction.)
- **MB3 — CONFIRMED (INERT), at BOTH layers.** MB3-a (md literal) and
  MB3-b (:251, the stamp that reaches the server) each ran both exes FULLY
  GREEN: every state/gate/member-count pin byte-identical
  (76/464/744/1976/116; 52/244/272/1520/80; H1 52/296/376/1624/68; H2
  0/0/0/0/80). Two distinct mechanisms measured: reconciler laundering
  (a), server override (b).
- **MB3' — CONFIRMED.** Stamp-that-survives (:251) + server passthrough
  (:273): all five legs flip clean -> Refuted naming H1 (anchor's first
  check printed it); seed_shape stayed FULLY green (the CR's own create
  carries dt None — the refutation lands at the first pod create, exactly
  the compound's point).
- **MB4 — CONFIRMED, both halves.** L0v flipped clean -> Refuted naming H2
  BY NAME (anchor: four `<none>`s then the full H2 name at L0v);
  the four vct:false legs ran BYTE-UNCHANGED — evidence: `t_p18_helper`'s
  four vct:false cases passed IN FULL (every pin) plus the anchor's four
  `<none>` violated-name checks; the anchor's own leg pins sit after its
  aborting L0v check and were NOT evaluated (and `t_p18_mutation` carries
  no H1/H2 per-member count pins — those live in `t_p18_helper`). Only
  other red: the H2 forge's base-accepted control caught the
  real stored PVC now carrying the ref. The `?vct` argument G7 omitted is
  exactly what carries H2's red capability.
- **MB5 — CONFIRMED (the required cross-phase negative).** Refutes
  nothing: all violated-names `<none>`, all clean/decisive green, all
  edges taken, maxima unmoved, L0/Ld/Lm/L0v pins passed IN FULL. The
  constant that moves is **Lc states: 464 -> 152 — EXACTLY P14's G2 number
  under this same mutant** (restart-as-no-op collapses post-crash
  continuations onto the 76 fault-free states, x2 for the crash counter;
  contrast P17's MA, a different restart mutant, which moved it to 452).
  The Lc gate/H1-count pins sit after the aborting states check and were
  NOT evaluated (the P17 MA precedent). Pins move, not the family.
- **Forges (automated, permanent) — all green on the true model** with the
  D1 4-check parity from birth; the wrong-uid control is SEEN accepted
  (`eq_without_uid`, not `Owner_reference.equal` — the E1 boundary), the
  non-matching-key controls SEEN accepted (premise really key-name-keyed),
  and under MB2-b/MB3'/MB4 the base-accepted controls correctly reddened
  (the bases are REAL stored objects and the store had gone bad).

Battery: `test/dune` 62 -> 64 (`t_p18_mutation`, `t_p18_regression`);
post-revert full re-runs green (see section 5's exes plus both new ones,
plus the four D2-rewired regressions and the D1-touched `t_p17_mutation`).

## 8. Limits + residuals (disclosed, not hidden)

1. **CR-parameterization kept** (no k5 strengthening): a universal closure
   over all CRs would be genuine added strength upstream does not claim; the
   family threads the scenario CR exactly as Vsts_invariants does.
2. **vct matrix beyond L0v deferred** (P16 8.6 remains open; L0v is the
   minimal non-vacuity floor for H2, not a vct-native matrix).
3. **inv_self citation drift NOT fixed** (vsts_invariants.ml:217 cites the
   VRS-layout path): fixing it moves k3 (name, source) pins in four committed
   exes; deferred to a phase that touches those pins anyway. P18's own source
   strings cite the real file.
4. **kN roster gap**: k1-k3/k5-k7 are established labels with no committed
   defining roster and k4 does not exist; P18 therefore labels its debt items
   D1/D2 and does NOT mint k4.
5. **S2-uid parity outside t_p17_mutation** (D1 fixes the known instance;
   no sweep for further parity gaps in other phases' forges this phase).
6. **The monkey-rely divergence is measured, not closed**: even a clean Lm
   only shows the SHIPPED monkey cannot violate H1; a richer monkey (arbitrary
   fabricated pods) remains future surface (natural companion to E6's P19
   reversal clause).

## Files

- `lib/assurance/helper_invariants.{ml,mli}` — the family (new).
- `lib/checker/fault_check.{ml,mli}` — the leg + MEASURED doc block (edit).
- `test/p18_witness.ml` — pins; graph constants DERIVED from p17_witness where
  identical, new literals only for L0v + gates + member counts.
- `test/t_p18_helper.ml` — 5 legs + replica counts + semantics checks.
- `test/t_p18_mutation.ml` — matrix rows MB1-MB5 (+MB3') + per-conjunct forges,
  6-row banner header in the t_p17_mutation.ml format.
- `test/t_p18_regression.ml` — classification firewall (via pair_guard) +
  E1/E4/E6 pins + P17-literal duplication.
- `test/pair_guard.ml` — D2 (new, non-names module).
- `test/t_p14_regression.ml` / `t_p15_regression.ml` / `t_p16_regression.ml` /
  `t_p17_regression.ml` — D2 rewire only.
- `test/t_p17_mutation.ml` — D1 only.
- `test/dune` — 3 new exes (t_p18_helper, t_p18_mutation, t_p18_regression);
  battery 61 -> 64.

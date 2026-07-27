# BUILD-SPEC-P17: store-side object invariants (objects_in_store.rs)

Normative spec for Phase 17, branch `p17-objects-in-store` off `90325b6` (P16).
Pattern: the P2..P16 spec discipline. Upstream ref:
`~/Documents/anvil-ref/src/kubernetes_cluster/proof/objects_in_store.rs`
(328 lines, all safety/always-invariants, no leads-to).

## 1. Why this phase (evidence-driven, from the P16 post-commit review + scout)

Three facts picked this family over four rivals (api_server/transition_validation,
objects_in_reconcile, garbage_collector, vsts_controller_proof — all scouted
GO_WITH_CHANGES 2026-07-27, wf_2a157137-4f7):

1. **It discharges the P16 review's own unreachability premise.** The fidelity
   lens confirmed Q2's rv-equality is rendered strictly stronger than upstream
   (both-None state accepted by the port, rejected upstream — LOW, disclosed,
   latent). The reviewer's unreachability argument rests on upstream's
   `each_object_in_etcd_is_weakly_well_formed` — exactly member S2 here. Porting
   and measuring it turns "latent only, unreachable" from an argument into a
   measurement.
2. **It completes the fault-dimension triptych.** P14/P15 attributed crash
   sensitivity, P16 drop sensitivity. These guards live SERVER-SIDE in the
   api_server write handlers, so the predicted signature is the mirror image:
   crash-insensitive (honest negative — crash never touches the store),
   drop-insensitive (honest negative — drop fabricates responses, store
   untouched), monkey-premise-amplified (pod_monkey drives create/update/
   update-status/delete through the same handlers). This is the first family
   where the MONKEY edge is the leverage edge.
3. **First STATE-side family.** Every P14–P16 member reads messages/reconciles;
   no shipped member has ever quantified over `resources s` (the etcd map)
   alone. All machinery exists today; premises do NOT depend on `vct` (unlike
   P16-E: no Get_request dependence; the store is non-empty from the seed).

   MEASURED-CORRECTION (B2, 2026-07-27): the second sentence is FALSE
   unqualified. Sweep `rg "objects_in_store"` over lib/ + test/: the base
   suite ALREADY ships S1/S2/S3 as inv1/inv2/inv3 under the same `source`
   strings (invariants.ml:156/:174/:196 in `Invariants.cluster_structural`,
   copies :388/:406/:428 in `partition`), consumed by `Invariants.always`
   (:1010) and `Vsts_invariants.always` (vsts_invariants.ml:288) and asserted
   under fault budgets since P13 (t_p13_faults.ml:241/:456). The true narrow
   claim: no member of the P14–P16 ASSURANCE families reads the store alone,
   and no store-side statement has ever ridden a DEDICATED leg with
   per-member interesting counts under a measured fault gate. The .mli
   discloses the adjacency and makes no "first" claim.

## 2. The family (`lib/assurance/objects_in_store.{ml,mli}`)

One list, `store_family` (all three guards live server-side; no split needed —
disclose the contrast with P16's two-list shape and why it does not recur here).
All members universally closed over stored keys (the k5-class disclosed
strengthening, same as P15/P16).

MEASURED-CORRECTION (B2, 2026-07-27): the k5-class label is WRONG here.
Upstream S1/S2/S3 are already state-level universally quantified over keys
(objects_in_store.rs:25-28/:35/:301), unlike P15/P16's per-key
parameterizations, so iterating the finite `Object_ref_map` is the EXACT
upstream statement (its foralls are `contains_key`-guarded) — no closure
strengthening arises and no `Bound.t` cap is applied (contrast Q2's
`bound_keys`, req_resp_correspondence.ml:188-204). The .mli discloses
"exact closure", not a k5 strengthening. Also measured while re-deriving S2:
the helper (:13-21) has FOUR conjuncts — the summary below omits
`obj.object_ref() == key` (:17); the port carries it (fold of the
result-valued `Dynamic_object.object_ref`, fail-loud).

- **S1 `etcd_objects_have_unique_uids`** (objects_in_store.rs:23): pairwise
  distinct `uid` over all objects in `resources s`. `interesting` = >= 2 stored
  objects (premise fires only after the first pod create at desired=1 — pin the
  count per leg to prove non-vacuity, P16 precedent).
- **S2 `each_object_in_etcd_is_weakly_well_formed`** (:33, helper :13): every
  stored object's metadata has `name` Some, `namespace` Some, `resource_version`
  Some and `< s.api_server.resource_version_counter`, `uid` Some and
  `< s.api_server.uid_counter`. Transcribe the helper's exact conjunct list from
  upstream — do NOT trust this summary; re-derive from :13-:60.
  `interesting` = store non-empty.
- **S3 `each_object_in_etcd_has_at_most_one_controller_owner`** (:299): each
  stored object's `owner_references` contains at most one
  `Owner_reference.is_controller` entry. `interesting` = some stored object has
  `Some` owner_references. NOTE inv16 (invariants.ml:952-961) checks the SAME
  <=1-controller property on LIST-RESPONSE bodies / reconciler-local pods; S3 is
  the store-side quantification. Name this adjacency in the .mli (the P16
  overclaim lesson: grep for neighbours BEFORE writing any "first" claim).

Each member carries its own `interesting` mirroring exactly its own premise
(P14 N3 lesson — no borrowing).

### 2-REVISED (reconciled design, 2026-07-27, follows the two corrections above)

Because inv1/inv2/inv3 ARE S1/S2/S3 (same source strings), the family must NOT
re-transcribe them — a second copy is drift risk and would break any
(name, source) classification firewall by construction. Reconciled shape:

- `store_family` RE-EXPORTS the exact `Invariants.cluster_structural` records
  (physical reuse, single source of truth). MEASURED (main-loop, 2026-07-27):
  all three already carry premise-mirroring `interesting` fields — inv1
  `cardinal >= 2` (= S1's pairwise premise), inv2 store-non-empty, inv3
  some-stored-object-has-a-controller-ref (invariants.ml:153-214) — so no
  wrapper is needed; re-verify at point of use.
- Deliverable A (fidelity re-audit): conjunct-for-conjunct audit of the three
  `holds` against upstream :13-21/:23-31/:33-40/:299-310. MEASURED so far:
  inv2 carries all FOUR helper conjuncts including `object_ref == key` via
  fail-loud `Result.fold ~error:(fun _ -> false)`. Any gap found = a real
  finding on the base suite; fixing it must keep the battery green (a
  refutation instead would be a major finding, report it, do not massage).
- Classification: t_p17_regression pins family = INCLUSION in
  `cluster_structural` by (name, source) pairs — a DELIBERATE divergence from
  the P14-P16 disjointness pattern, disclosed in the .mli; the four existing
  disjointness guards for the P14-P16 families remain in force (section 7's
  k3 strengthens their bodies to (name, source) pairs - strengthened, not
  removed; "untouched" was this phase's own third instance of the
  P14/P16-F1 overclaim class, caught by the P17 review).
- The novelty claim, narrowed per the corrections: the base suite has asserted
  these members only inside a UNION (masking discipline, P16 .mli) and never
  with per-member interesting counts under a measured fault gate; the P17 leg
  asserts the three ALONE = the first unmasked store-side measurement. The
  .mli says exactly this and nothing stronger.
- Section 5 note: while a mutant is applied, base-suite legs (t_p13 etc.)
  would ALSO redden — the observation protocol runs ONLY the t_p17 exes under
  mutation (already the protocol; now load-bearing).

MEASURED-CORRECTION (B2 apply, 2026-07-27) — Deliverable A outcome + two
corrections to this section:

1. Deliverable A found ONE gap. inv1/S1: upstream compares the TOTAL
   projection `uid->0` (objects_in_store.rs:29) under which Verus's `None->0`
   is one fixed unspecified value, so two stored objects with `uid = None`
   VIOLATE S1 upstream; the shipped `List.filter_map` dropped `None` uids and
   passed them (port weaker than upstream). FIXED in BOTH physical copies
   (`Option.fold md.uid ~none:(-1) ~some:Common.Uid.to_int`; -1 is outside the
   minted uid_counter range, api_server.ml:272). Latent under inv2 (uid Some
   on every stored object), extensionally unchanged on every inv2-green graph;
   full battery re-run green (58 exes). Residual disclosed deviation: a
   None/Some pair is unprovable either way upstream; the port renders it
   distinct. S2: all four helper conjuncts EXACT (conjuncts 2-4 exact at
   member level — their fail-loud/None arms fire only where conjunct 1 already
   rejects). S3: EXACT per conjunct (`is_controller` = upstream's
   `controller is Some && controller->0`, owner_reference.ml:24). Verdicts
   recorded per conjunct in objects_in_store.mli.
2. "all three already carry premise-mirroring `interesting` fields" is TOO
   STRONG for inv3: its witness (some stored object has an `is_controller`
   entry) is STRICTLY STRONGER than S3's literal per-key guard
   (`owner_references is Some` — `Some []` fires the guard but not the
   witness). inv1/inv2 mirror exactly. inv3's strengthening is kept
   deliberately (conservative: every witness state is a premise-fired state;
   it certifies the filtered count >= 1). Disclosed in the .mli.
3. Line-anchor drift caused by fix (1): the anchors cited in §1's correction
   block and above (`invariants.ml:156/:174/:196`, copies `:388/:406/:428`,
   range `:153-214`) are now `:155/:186/:208`, copies `:400/:421/:443`, range
   `:153-228`.
4. E2 verified by reading objects_in_store.rs:240-:297: the :270-271 premise
   `contains_key && (key.kind !is CustomResourceKind && key.kind == T::kind())`
   IS contradictory (`kind_is_custom_resource() ensures Self::kind() is
   CustomResourceKind`, spec/resource.rs:122-123); its own lemma :276-297
   proves the member by `always_weaken` from :110/:185, not from the premise.
   The scout read stands — document-only exclusion, NOT ported.

## 3. Deliberate exclusions, each with a MEASURED pin (the Q4/P14-N5 discipline)

- **E1 the well-formed strengthening** (:101/:110/:185): upgrade of "weakly" to
  full validation via `installed_types`. Constant-true in every shipped scenario
  because `scenario.ml:261-265` wires permissive `installed_types`
  (`fun _ -> true`). Pin: a regression test asserting the strengthening delta is
  extensionally empty on the L0 graph (evaluate both predicates, assert equal
  outcomes state-by-state), so the exclusion is measured, not asserted.
  MEASURED (B3): delta = 0 of 76 states, kind-coverage control 0
  (t_p17_regression, pins in p17_witness.ml).
- **E2 `:267`** (premise at :271 is a contradictory `&&` — vacuous even
  upstream as written). Pin: cite the upstream lines in the .mli; add a
  regression assertion that the port's rendering of that premise is unsatisfiable
  on the L0 graph IF cheap; otherwise document-only exclusion with the upstream
  contradiction quoted verbatim. Verify the contradiction by READING :240-:280 —
  if the scout misread it (e.g. it is satisfiable), PORT the member instead and
  record the correction.
  MEASURED (B3): the pin was cheap (the L0 replica already exists for E1) -
  premise-satisfying states 0 of 76, vsts-kind-key control 76 of 76
  (t_p17_regression, pins in p17_witness.ml). B2's contradiction read stands.

## 4. The leg (`Fault_check.check_objects_in_store_under_faults`)

Clone the P16 G6 shape (`fault_check.ml:521+`): `?req_drop ?pod_monkey`
(default false), standard seed (`vsts_seed_faults ~crash:true`, desired=1),
`p13_bound`, `default_depth` 40, caller budget. Gate = `require_fault`-style via
`budget_fault_taken` (:516) — NOT the crash-only gate (see F6 below). Per-member
interesting counts exported, same as P16.

MEASURED-CORRECTION (B3, 2026-07-27): the two anchors above drifted under the
B1 F6 move (`budget_fault_taken` hoisted above G5). Current: G6 comment block
`fault_check.ml:518`, `check_req_resp_under_faults` `:560`;
`budget_fault_taken` `:453`. The built G7 lands at `:590` (comment) / `:614`
(`check_objects_in_store_under_faults`). Also "exported, same as P16"
clarified at point of use: as in P16, the per-member counts are computed in
the leg test over LOCAL replicas through the exported `faulted_successors`
(t_p16_req_resp.ml:201-239 precedent), not carried in `fault_report`.

Legs to measure (all `vct:false`; vct legs deliberately out of scope, k6-class,
disclose): **L0** zero-budget; **Lc** crash-only {1;0;0}; **Ld** drop-only
{0;1;0}; **Lm** monkey-only {0;0;1}. Cross-checks: L0 must be 76 states and
Lc 464, Ld 744, Lm 1976 (the P13/P14/P15/P16 product-graph constants — if the
seed drifted, STOP and diagnose).

Expected (predictions, to be measured, honest-negative discipline: record
refutations of these predictions as findings, not failures):
- All four legs clean + decisive.
- S1 interesting = 0 until the first create; > 0 on every leg at depth 40.
- Crash moves NO store-side truth (Lc clean with gates > 0) — P15-A mirror.
- Ld premise counts ~ L0's (drop fabricates responses only).
- Lm premise counts amplified (monkey create/update/delete churn).

MEASURED (B3, 2026-07-27; single-sourced in test/p17_witness.ml, asserted in
test/t_p17_store.ml; wall times 0.010/0.059/0.130/0.782 s):
- State cross-check PASSED: L0 76, Lc 464, Ld 744, Lm 1976 - the P13-P16
  product-graph constants, no seed drift.
- Prediction 1 CONFIRMED: all four legs clean + decisive, `violated = None`.
- Prediction 2 CONFIRMED: S1 = 52/296/376/1624 (> 0 everywhere, < states on
  every leg - 0 at the seed's single-object store). NOTE the union gate
  SATURATES (L0 76, Lc 388 = post-crash slice, Ld 592 = post-drop, Lm 1824 =
  post-monkey) because S2's interesting (store non-empty) fires at every
  state; the discriminating signal is the per-member counts.
- Prediction 3 CONFIRMED (measured negative, P15-A mirror): Lc clean, gate
  388 > 0, crash edge really taken; per-member post-crash 244/388/244.
- Prediction 4 REFUTED under the density reading (recorded as a finding):
  Ld S1/S3 density is 376/744 = 50.5% vs L0's 52/76 = 68.4% - the fabricated
  Error stalls the reconciler's create on the dropped branch, diluting the
  >= 2-objects slice. The CONTENT half stands measured: Ld's
  max_uid/max_rv = 3/2, L0's exact values (store untouched by drops).
- Prediction 5 CONFIRMED: Lm S1/S3 = 1624 (82.2% density), max_uid = max_rv
  = 4 on this vct:false graph alone (the monkey create really lands).
- MEASURED COINCIDENCE (asserted per leg, a scenario fact not a law): S3's
  count equals S1's on all four graphs (52/296/376/1624) - the first create
  is the reconciler's controller-ref-bearing pod, so the two slices
  coincide.

## 5. Mutation matrix (Edit-applied, Edit-reverted, each revert re-verified;
   never `git checkout`; if the permission classifier DENIES a lib/cluster edit,
   record it and fall back to disclosed analysis — do NOT work around, k7)

- **MU (headline)**: api_server create stops advancing `uid_counter`
  (api_server.ml:~300) → two creates stamp equal uids → S1 flips RED on L0
  already (any-budget mutant; the state-side analogue of P16's MR).
- **MR' (cross-phase)**: create stops advancing `resource_version_counter`
  (api_server.ml:~301) — P16's MR verbatim. Predict: S2 RED (stored rv no longer
  < rvc) AND P16's Q1 still RED (committed behaviour) → one mutant refuting a
  message-side AND a state-side member = the cross-phase datum.
- **MO-a (guard-witness)**: `make_owner_references` duplicates the controller
  ref (v_stateful_set_reconciler.ml:~218-220) ALONE. Predict GREEN everywhere —
  the api_server admission guard (api_server.ml:~87-93) rejects >1 controller
  owner, so the create fails and S3 never sees the bad object. A GREEN here is
  the guard's load-bearing witness (a measurement, not a failed mutant).
- **MO-b (compound)**: MO-a + weaken the admission guard (api_server.ml:~93).
  Predict S3 RED. Records that S3 reads owner refs; discloses the double-guard
  structure (scout: no single-site RED mutant exists for S3).
- **MA (negative control, P14's)**: `restart_controller` also resets
  `s.rpc_id_allocator`. Predict: refutes NOTHING in store_family (rpc ids are
  not uids), Lc shrink to P14's numbers.
- **MD (negative control, P16's)**: drop fabricates `Ok` (message.ml:~346).
  Predict: INERT on store_family (store untouched by responses) while P16's
  Ld/Matched stays RED — the message-side/state-side contrast datum.
- Forge tests per member (state-level, in test/): each forged state violates
  EXACTLY its target member; audited for tautology/entailment
  (feedback-confirm-tests-by-mutation).

MEASURED (B4, 2026-07-27; the full row-by-row record with mechanisms lives in
test/t_p17_mutation.ml's header — this is the summary):
- **MU: leg-RED half CONFIRMED, named-member prediction REFUTED (recorded as
  a finding, the P16 MS precedent).** All four legs flip clean -> Refuted, L0
  included (any-budget confirmed), but `violated` names **S2, not the
  predicted S1**: the SEED's CR is created through the real
  `handle_create_request` (scenario.ml:355-368), so under MU the seed itself
  already violates S2's strict `uid->0 < uid_counter` conjunct — one step
  before any duplicate uid can form. The S1-naming reasoning was sound for a
  hand-seeded store and wrong for this scenario's API-created seed.
- **MR' CONFIRMED, both halves**: S2 RED state-side AND P16's Q1 RED
  message-side under the same application — the cross-phase datum (one mutant
  refuting members in two families on opposite sides of the api boundary).
- **MO-a CONFIRMED (guard-witness, a measurement not a failed mutant)**: GREEN
  everywhere; the admission guard absorbs the duplicated controller ref (it
  also starves the Lm monkey edge — see the file for the mechanism).
- **MO-b CONFIRMED**: the compound (MO-a + guard count weakened `> 1` -> `> 2`
  at api_server.ml:95) flips the legs RED naming exactly S3; seed and forges
  stay green. The scout's no-single-site-RED-mutant prediction for S3 stands
  MEASURED.
- **MA CONFIRMED (required negative)**: refutes NOTHING store-side; the only
  red is the Lc states pin 464 -> 452 — P16's exact number for the same
  mutant (product-state merging, the P15 M1 lesson; names asserted first,
  pins last, by design).
- **MD CONFIRMED on the family, graph half REFINED**: INERT on the store
  family while P16's Ld/Matched still reds naming Q5 under the SAME
  application — the message-side/state-side contrast datum. Refinement: the
  Ld GRAPH pin moves 744 -> 648 (fabricated identical Ok responses merge the
  per-error fan-out states) — the pin moving, not the family.
- Battery after all reverts: 61 exes / 0 failing; lib/cluster/ and
  lib/controllers/ diffs EMPTY (residue-scanned).

## 6. P16 review-debt fixes carried on this branch (all 7 verified findings)

- **F1 (HIGH, overclaim)**: "first shipped members that open a response BODY /
  relate a message to etcd; nothing before this module" is FALSE — shipped inv15
  `filtered_pods_invariant_matrix` (invariants.ml:884-949, in `always` :1005)
  opens list-response bodies via resp15 (:856-882, wired at :940) and relates
  them to `resources s`/`rvc s`; inv16/resp16 similar. Sweep THE CLAIM (rg
  "first|nothing before|No shipped") across req_resp_correspondence.mli:1-8,
  fault_check.mli:741-744, BUILD-SPEC-P16.md:46-48 + any other hits; narrow to
  the true claim (first CLUSTER-proof members quantifying over ALL in-flight
  messages, vs inv15/16's single-pending-VRS-request scope).
- **F2 (MEDIUM, overclaim)**: "first leg that CAN take Drop_req_step/
  Pod_monkey_step; no shipped seed ever switched it on; every shipped fault leg
  seeds false/false" is FALSE — `check_settles_after_disable` (pre-P16 :555)
  seeds all three flags TRUE with caller budget since P13; t_p13_faults.ml
  :171/:194 seed all-on. TRUE claim (verified): no shipped leg RUN ever TOOK a
  drop/monkey edge (G3 ran at `budget_crash_only`, p13_witness.ml:53), and P16's
  are the first legs to take them under a MEASURED fault gate. Fix at
  fault_check.mli:743-745, fault_check.ml:535, p16_witness.ml:165-166,
  t_p16_req_resp.ml:14, BUILD-SPEC-P16.md:32-37.
- **F3 (LOW, cite drift)**: pod_monkey.ml:57-69 is `create_pod`; the Update_pod
  fresh-rpc_id code is `update_pod` at :87-100 (allocate :90-92). Fix
  req_resp_correspondence.mli:47-49 + BUILD-SPEC-P16.md:166.
- **F4 (LOW, disclosure)**: strengthen req_resp_correspondence.mli:115-117 — in
  Verus, upstream Q2's both-None rv premise is reflexively TRUE (total `->0`
  projection), so the port's both-Some rendering is a premise strengthening =
  invariant weakening, latent under S2 (this phase measures the premise).
- **F5 (LOW, naming)**: BUILD-SPEC-P16.md:167-168 names the P14 member by
  upstream's weaker, deliberately-not-shipped name; use the shipped name.
- **F6 (LOW, latent gate)**: `check_reconcile_correspondence_under_faults`
  gained `?req_drop ?pod_monkey` (P16) but kept the crash-only gate
  `(not require_crash) || crashes >= 1` (fault_check.ml:496) → `require_crash:
  true` on a drop/monkey budget yields a structurally-0 gate SILENTLY. Fix:
  replace the crash conjunct with `budget_fault_taken budget f` — extensionally
  identical on every shipped graph (all require_crash:true callers use
  crash-only budgets where the disjunction collapses to crashes>=1), so every
  committed pin must be UNCHANGED; re-run the full battery to prove it, and
  rename the parameter require_crash -> require_fault (fix in-repo callers;
  document the rename in the .mli next to P15's disclosure).
- **F7 (LOW, silent-clean)**: t_p16_mutation.ml manual-anchor legs assert
  `report_clean` but never `report_decisive` (:999-1004, also ld_rv :863) — a
  frontier-truncated No_counterexample under a manual mutant reads as clean.
  Add `report_decisive` asserts at all 7 sites (the unmutated legs are decisive,
  so the battery stays green; under manual mutants the protocol now fails loud).

## 7. P16 open-LOW hardening carried on this branch

- **k2**: add a premise-side count to the Q4 pin — count matched OK
  Update_responses on the Lm graph (expect 0; a nonzero count reopens the Q4
  exclusion argument).
- **k3**: strengthen the four base-suite disjointness guards from name-string
  proxy to (name, source) pairs.
- **k1**: NOT changed further this phase — F6 makes more legs share
  `budget_fault_taken`, whose disjunction remains the right semantics for the
  shipped single-dimension budgets; the mixed-budget caveat stays disclosed in
  the existing comment (:508-515).

## 8. Process, build, and disclosure rules

- Build: `eval $(opam env --switch=anvil-ocaml --set-switch); dunecho build`.
  `dune test` HANGS — run exes via
  `perl -e 'alarm 150; exec @ARGV' _build/default/test/<name>.exe`.
- STAGE everything, never commit (suggested subject:
  `feat(assurance): P17 store-side object invariants (objects_in_store.rs S1-S3 + monkey-leverage leg)`).
- Every measured number lands in `test/p17_witness.ml` single-sourced; every
  claim in .mli text must carry MEASURED provenance or be marked a prediction.
- Scout line numbers above (api_server.ml:87-93/270-301/356-371/492-535/641,
  scenario.ml:261-265/311-319, cluster.ml:744-770, pod_monkey.ml:57-94,
  v_stateful_set_reconciler.ml:218-220/361/379) are FRESH (2026-07-27) but must
  each be re-verified at point of use; correct the spec in place if drifted
  (MEASURED-CORRECTION blocks, P14 discipline).
- The overclaim lesson, applied prospectively: before writing ANY "first/only/
  never/all" sentence in .mli or spec text, rg the repo for the claim's
  counterexample class and cite the sweep in the text.

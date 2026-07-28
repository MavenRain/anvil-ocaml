# BUILD-SPEC-P19: message-provenance invariants (the E6 reversal clause)

Phase 19 of the anvil-ocaml assurance port. Branch `p19-msg-provenance` off
`b010766` (P18). Ports the sender-tag/provenance register: upstream
`vstatefulset_controller/proof/helper_invariants.rs:1213`
(`every_msg_from_vsts_controller_carries_vsts_key`) plus the three unshipped
cluster sender-classification always-members of
`kubernetes_cluster/proof/network.rs` (`:540` / `:570` / `:618`), asserted
ALONE under the four matrix fault budgets, with an orphan-spine non-vacuity
floor for the builtin member. Battery 64 -> 67 exes. NEVER `git commit` —
stage only.

## 1. Why this phase (evidence-driven, from the P18 reversal clause + this session's 7-scout workflow `wf_f20ed3d5-895`, 7/7 returned, 0 errors)

P18's E6 exclusion carries an explicit REVERSAL CLAUSE ("natural P19
candidate as part of a message-correspondence extension",
BUILD-SPEC-P18.md:220-221) and the shipped E6 register guard's own comment
pre-authorizes the claim ("until a deliberate P19 port claims it",
t_p18_regression.ml:219-221). The scout wave confirmed both former blockers
discharged:

- **Renderable**: port messages carry their sender — `Message.t.src :
  host_id` with `Controller of int * Common.object_ref`
  (message.mli:37-45,69-75), and `object_ref` carries `kind`, so the :1213
  quantifier is a 5-arm exhaustive match on `m.src`.
- **Genuinely distinct from `inv_self`** (the apparent-overlap trap that
  motivated E6): `inv_self` filters by EXACT src equality
  `Controller (controller_id, vsts_ref)` then constrains the PAYLOAD
  (vsts_invariants.ml:153-155,214-232); :1213 quantifies over ANY cr_key
  with the matching id and constrains only the TAG's kind. A message from
  `Controller (controller_id, wrong-key)` passes `inv_self` silently and is
  exactly what M1 polices.
- **Upstream's own grouping**: all four members appear together as
  stronger_next conjuncts in the :1213-consuming proof
  (helper_invariants.rs:1200-1208) — the family is upstream's, not minted.

Rivals (banked, section 8): S3 fabricating-monkey Lf leg (strongest P20
lead — GO_WITH_CHANGES, touches the core `Cluster.t` record), S5
controller-local binding family (`internal_rely_guarantee.rs:926-931`,
unoccupied register), S7 `controller_runtime_safety` CR-validity trio.
S4 CR-delete edge REJECTED on fidelity as stated (upstream's 12-variant
step enum has no such edge; renderable instead as a forged stale-uid seed —
banked in the recast form). S2 vct-native matrix is under phase-weight
(P16 already pinned Lcv/Ldv/Lmv graphs 1136/1832/3224 — a "first vct
matrix" headline would be refuted at review). S6 installed_types NO_GO
(decidable by static reading).

## 2. The family (`lib/assurance/msg_provenance.ml/.mli`)

New disjoint module, P14-P16 style (P17's filter pattern unavailable — no
member is shipped anywhere: rg-swept, zero hits in lib/ and test/).
Signature mirrors the P18 template (helper_invariants.mli:132-138):

```ocaml
val provenance_sources : string list
val provenance_family : controller_id:int -> Invariants.invariant list
```

CR-agnostic: M1 needs `controller_id` only; M2-M4 are cluster-level
(upstream states them on `Cluster` with no controller argument). Do NOT
thread a `~cr` — that would be unclaimed strength (P18 residual 1
discipline). All four members traverse `Message.Pool.distinct
(Cluster.in_flight s)` — the `inv_self` projection precedent
(vsts_invariants.ml:152); classifiers are per-message, multiplicity adds
nothing.

### M1 — the controller tag member (upstream helper_invariants.rs:1213-1222, lemma :1224-1260)

- name `every_msg_from_vsts_controller_carries_vsts_key`, source
  `"vstatefulset_controller/proof/helper_invariants.rs:1213"`.
- holds: every in-flight msg whose src is `Controller (cid, key)` with
  `cid = controller_id` has `Common.equal_kind key.kind V_stateful_set.kind`.
  Exhaustive 5-arm match on host_id; the four non-Controller arms `true`
  (out of premise), NO wildcard.
- interesting: some in-flight msg has src `Controller (controller_id, _)`.
- Upstream lemma cost is the cheapest in the file: init/next/type-installed/
  model + `lemma_always_there_is_the_controller_state` only — no rely
  premises. MODEL-CONDITIONAL: the lemma requires
  `controller_models.contains_pair(controller_id, vsts_controller_model())`
  (:1231); on a non-vsts spine M1 is NOT claimed (section 4's orphan
  replica MUST NOT assert it — see the live-control note there).
- NAME-COLLISION DISCLOSURE (armed): `internal_rely_guarantee.rs:528-540`
  defines a semantic duplicate under the SAME upstream name (bridged in
  liveness/proof.rs:903-926). P19 cites helper_invariants.rs:1213 ONLY;
  the .mli carries this note (E2', section 3).

### M2 — the pod-monkey classifier (upstream network.rs:570-587, lemma :589)

- name `all_requests_from_pod_monkey_are_api_pod_requests`, source
  `"kubernetes_cluster/proof/network.rs:570"`.
- holds: every in-flight msg with src `Pod_monkey` has dst `Api_server`,
  content `Api_request r`, and r classified by an EXHAUSTIVE 9-arm match
  on the request sum (the `self_ok` template, vsts_invariants.ml:176-212):
  `Create_request` / `Update_request` / `Delete_request` /
  `Update_status_request` -> the request's key kind = `Pod.kind`; the five
  remaining arms (`Get_request`, `List_request`, `Get_then_delete_request`,
  `Get_then_update_request`, `Get_then_update_status_request`) -> `false`
  (upstream's `_ => false` at :583 spelled out, NO wildcard).
- Key derivation per arm (upstream's uniform `req.key().kind`): B1 CONFIRM
  whether the port's Api_method (lib/k8s_objects/api_method.mli) exports a
  request-key projection; if not, read per-arm (Create/Update/Update_status:
  `Dynamic_object.kind r.obj`; Delete: `r.key.kind`) and disclose the
  per-arm reading in the .mli.
- interesting: some in-flight msg has src `Pod_monkey`.
- The port monkey's real repertoire is exactly the four permitted arms,
  all pod-keyed (pod_monkey.ml:64-113: create/delete/update/update_status
  via `pod_monkey_req_msg`) — M2's green is emergent, its red capability
  comes from forges + ML1 (section 7).
- MEASURED-CORRECTION (B4, the red-capability enumeration above REFUTED on
  BOTH halves; section 7's MN1' and ML1 rows). (i) The forges are NOT the
  only forge-free source of an M2 red: the **MN1'** row (a suppressed
  src/dst swap in `form_create_resp_msg`, message.ml:208) reddens M2 on the
  **Lm** leg and on the orphan replica (111 states), because a create
  RESPONSE then inherits `src Pod_monkey` and `api_request_of` is `None` on
  a response. (ii) **ML1 does not redden M2 at all**: the attribution flip
  moves the message OUT of M2's premise, and its measured red names **M3**
  (section 7's ML1 row: "M2 green"). The corrected reading (forges + MN1',
  live and forge-free, never ML1) is what `msg_provenance.mli`'s M2 block
  ships.
- MEASURED-CORRECTION (B1): the monkey's live op span is pod_monkey.ml:58-116
  (req-msg constructions at :66/:81/:97/:113), not :64-113. Cosmetic; ML1's
  ":66 create arm" citation is exact.
- MEASURED-CORRECTION (B1/B2, the key-projection CONFIRM resolved): the port
  exports PER-REQUEST key projections and no sum-level `key()`
  (api_method.mli:103-137). B2 reads Update / Update_status / Delete via
  `(update_request_key r).kind` / `(update_status_request_key r).kind` /
  `(delete_request_key r).kind` (each exactly the upstream key construction;
  NOT the fallback's raw field reads suggested above) and Create via
  `Dynamic_object.kind r.obj`, because `create_request_key` is `Res.t`-typed
  (partial on a missing metadata name) and a total classifier must not
  consume it. Per-arm reading disclosed in the .mli.

### M3 — the builtin classifier (upstream network.rs:618-628, lemma :630)

- name `all_requests_from_builtin_controllers_are_api_delete_requests`,
  source `"kubernetes_cluster/proof/network.rs:618"`.
- holds: every in-flight msg with src `Builtin_controller` has dst
  `Api_server` and content `Api_request (Delete_request _)`. Upstream's
  `content.is_delete_request()` is macro-generated over strictly
  `DeleteRequest` (spec/message.rs:322-326) — `Get_then_delete_request` is
  NOT a delete here; the match arm is `Delete_request` alone, other eight
  arms `false`, NO wildcard.
- interesting: some in-flight msg has src `Builtin_controller`.
- The port GC emits exactly this shape (builtin_controllers.ml:101-103:
  `delete_req_msg_content key (Some preconditions)` via
  `built_in_controller_req_msg`).
- MEASURED-CORRECTION (B1): the `is_delete_request` macro INVOCATION spans
  spec/message.rs:321-326 (starts one line earlier than the :322-326 cited
  above). Cosmetic.
- MEASURED-CORRECTION (review, the in-module citation): `msg_provenance.ml`
  cited the `content.is_delete_request()` conjunct at network.rs:**624**,
  but :624 is `&&& msg.dst is APIServer`; the delete conjunct is :**625**
  (re-read in anvil-ref). Citation-only: the port's semantics (the strict
  `Delete_request` arm plus the dst conjunct) already match :624-625 in
  full. Corrected in the module comment.
- PREDICTED VACUOUS ON ALL FOUR LEGS (prediction 3): no vsts-spine graph
  fires the builtin (the seeded CR is never deleted; vsts pods carry live
  owner refs). The non-vacuity floor is the ORPHAN REPLICA (section 4) —
  the E4-style control discipline, pre-authorized here so a 0-row is an
  honest N5-style negative, not a masked failure.

### M4 — the no-reflexive/external-request member (upstream network.rs:540-549, lemma :551)

- name `no_pending_request_to_api_server_from_api_server_or_external`,
  source `"kubernetes_cluster/proof/network.rs:540"`.
- holds: NO in-flight msg has (src `Api_server` or `External _`) AND dst
  `Api_server` AND content `Api_request _`. Negative universal: render as
  `List.for_all (fun m -> not (in_scope_src m && dst_api m && is_req m))`.
- interesting: some in-flight msg has src `Api_server` or `External _` —
  the classifier actually inspected a message in scope. DISCLOSED
  DEVIATION from the violation-shaped premise convention: for a negative
  universal the premise IS the violation, so interesting is deliberately
  source-in-scope (API responses make it fire on every post-first-response
  state; the .mli carries this note).
- The `External _` arm is expected structurally inert on shipped spines
  (B1 CONFIRM item 5); if so, disclose in the .mli — do not narrow the arm.
- MEASURED-CORRECTION (review, the in-module citation): `msg_provenance.ml`
  cited M4's source scope at network.rs:**543**, but :543 is
  `&&& #[trigger] s.in_flight().contains(msg)`; the
  `(msg.src is APIServer || msg.src is External)` disjunction is :**544**
  (re-read in anvil-ref). Citation-only; the rendering is unchanged.
  Corrected in the module comment.

### Classification firewall

New (name, source) pairs, all four distinct by exact string from every
shipped pair (verified this session: P14 cites network.rs:35/:76/:254/
:312/:382; P18 cites helper_invariants.rs:52/:1063; pair_leaks compares
exact strings, pair_guard.ml:38-49). t_p19_regression sweeps
`provenance_family` vs ALL shipped suites (P14/P15/P16/P17/P18 + always/
VSTS base suites — the t_p18_regression.ml:195-198 roster PLUS the P18
family) via `Pair_guard.pair_leaks`, both directions covered by the
either-component detector.

MEASURED-CORRECTION (review, the firewall's REACH): the sweep compares
exact (name, source) STRINGS, so it certifies citation-level novelty and
NOT that a member's substance is unasserted elsewhere. One real semantic
overlap exists and is now disclosed in `msg_provenance.mli`'s M3 block:
shipped `garbage_collector_does_not_delete_vrs_pods`
(`Invariants.eventually_always` inv7, invariants.ml:527-546, source
`vreplicaset_controller/proof/helper_invariants/predicate.rs:316`, inside
the very roster this file sweeps) already forces a DELETE on the
{builtin src, api-server dst, api request} intersection, its `gc_ok`
returning `false` on all eight non-`Delete_request` arms
(invariants.ml:522-525). M3 remains distinct: it also covers builtin
sourced messages with `dst` other than `Api_server` and with NON-request
content, where inv7 is vacuously true, and it carries none of inv7's uid
preconditions. So "first assertion site" is scoped to these citations,
not to the members' substance (`t_p19_provenance`'s header claim 1,
likewise corrected).

## 3. Deliberate exclusions, each with a pin (the Q4/P14-N5 discipline)

- **E1' the valid-controller-id conjunct** (helper_invariants.rs:1206's
  `every_in_flight_req_msg_from_controller_has_valid_controller_id`):
  ALREADY SHIPPED as P14 N4 (correspondence.ml:164, source
  network.rs:312). Including it would be a pair_guard leak, not a member.
  Pin: the mechanical disjointness sweep (section 2) + one doc line.
- **E2' the internal_rely_guarantee.rs:528 duplicate** of :1213 (same
  upstream name, bridged via liveness/proof.rs:903-926): source-citation
  decision only — P19 cites helper_invariants.rs:1213. Document-only; the
  pair_guard source string IS the pin.
- **E3' the payload-register siblings**: `vsts_guarantee` (guarantee.rs)
  and `vsts_internal_guarantee_conditions` (internal_rely_guarantee.rs:522)
  constrain controller REQUEST PAYLOADS — the register `inv_self` occupies
  (widened inv9). Document-only exclusions; porting them would re-open the
  P17-review overlap-misread class E6 was originally excluded for.
- **E4' the network.rs remainder**: B1 enumerates `pub open spec fn` over
  network.rs, crosses out P14's five + these three, and ledgers every
  leftover always-member with a one-line reason (expected: response-side /
  rpc-id members inside P14's register, or eventually-only). If B1 finds an
  unshipped always sender-classification sibling, it does NOT join the
  family this phase (scope pin) — it is ledgered with a reversal clause.
  - MEASURED (B1 enumeration, B5 realisation): network.rs has exactly 13
    `pub open spec fn` — :15 :19 :35 :76 :104 :171 :254 :312 :382 :514 :540
    :570 :618. P14's five (:35 N1, :76 N2, :254 N3, :312 N4 = E1', :382 N5)
    and P19's three (:540 M4, :570 M2, :618 M3) are crossed out; the five
    leftovers are ledgered with one-line reasons in
    `test/t_p19_regression.ml` (`e4_leftovers`): :15
    `rpc_id_counter_is(rpc_id)` and :19 `rpc_id_counter_is_no_smaller_than`
    are rpc_id-PARAMETERIZED (no closed always-member to port; lemma :23
    premises :15 to get :19), :104
    `pending_req_of_key_is_unique_with_unique_id` and :171
    `every_in_flight_req_msg_has_different_id_from_pending_req_msg_of` are
    KEY-parameterized specializations inside P14's pending-req rpc-id
    register (:171 is exactly what shipped N3 :254 quantifies over), and
    :514 `every_in_flight_msg_has_unique_id` is an always-member strictly
    WEAKER than shipped N5 :382 (upstream derives it by `always_weaken` at
    :530-535; correspondence.ml:185-188 already records that). SCOPE PIN
    DISCHARGED: NO unshipped always sender-classification sibling remains,
    so E4' carries no reversal clause this phase. The ledger is not a
    comment — `t_p19_regression` BUILDS the two crossed-out lines from the
    live `Correspondence.family` / `provenance_family` records and checks
    them against the committed B1 text, then re-derives the accounting
    (crossed-out lines + ledgered leftovers = the 13, each once), so a
    rename, a source drift, or a P20 that ships a leftover without a ledger
    edit reddens there.
  - MEASURED-CORRECTION (review, the guard's REACH; the last clause above
    overclaims). Both the ledger and the accounting assert read exactly two
    family records, `Correspondence.family` (P14) and `provenance_family`
    (P19), and the six leftover strings are ONE binding (`e4_leftovers`)
    placed on both sides of the comparison, so that half is a tautology.
    What the guard really catches: a rename, a source drift, a member added
    to or dropped from EITHER of those two families, and a leftover
    promoted INTO one of them without a ledger edit. What it does NOT
    catch: a leftover shipped by a NEW family module (the pattern every
    phase P14-P19 actually used), which leaves all three assertions
    byte-identical. That case must be caught by the new phase's own ledger
    edit; the comments in `test/t_p19_regression.ml` now state this scope.
- **E5' (reserved)**: fallback slot. If B1 refutes a member's rendering
  premise (section 6 gate), that member moves here with the refutation
  recorded, and the family ships at 3 members rather than silently
  re-scoping.

## 4. The leg (`Fault_check.check_msg_provenance_under_faults`) + the orphan floor replica

Clone the P18 H-leg shape (fault_check.ml:664-691: `run_leg`, pointwise
lift `fun f -> inv f.cs`, `violated_of`, `default_depth`,
`require_fault`/`budget_fault_taken` gate, union-interesting gate count)
with ONE disclosed deviation: **NO `?vct` arg** — mirror G7's k6-class cut
(fault_check.ml:648-651 documents the pattern), because no P19 member's
premise reads PVCs or volumes; vct adds no rows here. Seed
`Scenario.vsts_seed_faults ~desired:1 ~crash:true ~req_drop ~pod_monkey ()`
exactly as G7 (:620). Family = `Msg_provenance.provenance_family
~controller_id:Scenario.controller_id`.

MEASURED-CORRECTION (B1): the G7 vct-cut doc block spans
fault_check.ml:647-652, not :648-651. Cosmetic.

Legs (P13's bound, depth 40, desired 1; budget literals via the witness
module): L0 zero / Lc crash / Ld drop / Lm monkey — the four matrix
budgets. `report_decisive` is a PHANTOM symbol; decisiveness is the local
per-test projection (t_p17_store.ml:71-74 shape).

**The orphan floor replica (test-level, NOT a leg)**: explore
`Scenario.cluster` (the generic/vrs spine, scenario.mli:17) from
`Scenario.seed_with_orphan ~desired ~fair:false` with plain productive
successors (B1 CONFIRM item 3 locates the shipped orphan-test template and
its exact explore call). There the GC actually fires
("[After_delete_pod] path is also exercised", scenario.mli:256-259).
Assert: (a) M3.interesting on >= 1 state — the floor; (b) M3.holds on
every reached state; (c) M2 and M4 hold on every reached state
(cluster-level members travel); (d) M1 is NOT asserted as an invariant
there — it is MODEL-CONDITIONAL (section 2). INSTEAD: if B1 confirms the
orphan spine stamps `Controller (Scenario.controller_id, vrs-kind key)`
messages, add the LIVE RED CONTROL: `Model_check.check_safety` over the
replica with M1 alone must land `Refuted` with violated naming M1 — M1's
red capability witnessed on a REAL graph, forge-free (prediction 6). If
the spine uses a different controller id, the control degrades to the MC1
forge only, and the spec's prediction 6 is recorded REFUTED-BY-B1 with the
measured id facts.

MEASURED-CORRECTION (B3, the replica's explore realised): the shipped
orphan-test template DRIVES the spine (t_p4_enumerator drive/run_random,
:169/:170) precisely because plain-productive-successor BFS cannot exhaust
it - the B3 depth sweep measured 43 states at depth 2 and 1518 at depth 4
(~35x per 2 plies). The replica is therefore `Mc.explore` at DEPTH 4 over
`Scenario.productive_successors Scenario.cluster Bound.default` from
`seed_with_orphan ~desired:1 ~fair:false`, DEPTH-LIMITED with
`frontier_emptied = false` asserted as the replica's honest shape
(p19_witness.ml carries the disclosure). Depth 2 would NOT do: M3's floor
already fires there (11 states) but M1's premise fires NOWHERE, leaving
the red control vacuously green; at depth 4 every section-4 requirement
(a)-(d) lands. Every replica count is a depth-4-replica fact, not a
total-reachability fact. One measured bonus: the generic spine runs a
LIVE pod monkey, so M2's premise fires at 1408 of the 1518 states and M2
is green across all of them - un-predicted green surface, recorded in
section 5.

## 5. MEASURED (B3 fills; predictions committed NOW, by number)

1. **Graph pins**: L0/Lc/Ld/Lm = 76/464/744/1976 EXACT (graph = f(seed,
   bound, budget, depth), never the invariant list — fault_check.ml:656-660).
   Any drift = STOP, diagnose seed drift, never retune.
2. **All four members hold on every reachable state of every leg** (all
   are upstream-proved always; a violation is a FINDING, not a port bug —
   stop and write it up before touching anything).
3. **M3 interesting = 0 on all four legs** (honest N5-style rows), floor
   carried by the orphan replica (>= 1 interesting state, M3 green there).
4. **M2 interesting = 0 on L0/Lc/Ld; > 0 on Lm** (monkey messages exist
   only under a monkey budget; in-flight monkey requests are real states —
   pod_monkey.ml sends into the pool, delivery is a separate step).
5. **M1 and M4 interesting > 0 on every leg** (first controller request /
   first api response lands in the pool within depth 40 on every budget).
6. **The orphan replica refutes M1 alone** (live red control) — gated on
   B1's controller-id confirmation, see section 4's degrade clause.
7. **Battery 64 -> 67** (3 new exes), all green; `lib/cluster` +
   `lib/controllers` mutation residue EMPTY at stage time.

### MEASURED (B3, 2026-07-27; B4/B5 append the matrix + firewall outcomes)

Runs: `t_p19_provenance` legs + a transient probe version of the same exe
(depth sweep, replaced in place), branch `p19-msg-provenance`, seed
`Scenario.vsts_seed_faults ~desired:1 ~crash:true ~req_drop ~pod_monkey ()`
(no vct arg - the leg has none), bound = P13's, depth 40. Replica
faithfulness held on all four legs (replica `states_seen` = leg `states`);
recomputed union gates matched `gate_states` on all four. Every pin lives
in `test/p19_witness.ml` (single source); this table is disclosure, not a
second assertion site. Times are `Sys.time` CPU seconds, leg-call-only.

| leg | budget | rf | verdict | states | gate | cws | ffs | uid/rv | c/d/m seen | M1 all/slice | M2 all/slice | M3 all/slice | M4 all/slice | cpu |
|-----|--------|----|---------|--------|------|-----|-----|--------|-----------|--------------|--------------|--------------|--------------|-----|
| L0 | zero {0;0;0}   | f | clean+DECISIVE | 76   | 32   | 0   | 76  | 3/2 | 0/0/0 | 16 / -        | 0 / -     | 0 / - | 16 / -         | 0.012 s |
| Lc | crash {1;0;0}  | t | clean+DECISIVE | 464  | 296  | 388 | 76  | 3/2 | 1/0/0 | 156 / 140 pc  | 0 / 0     | 0 / 0 | 208 / 192 pc   | 0.067 s |
| Ld | drop {0;1;0}   | t | clean+DECISIVE | 744  | 448  | 0   | 152 | 3/2 | 0/1/0 | 64 / 32 pd    | 0 / 0     | 0 / 0 | 448 / 416 pd   | 0.133 s |
| Lm | monkey {0;0;1} | t | clean+DECISIVE | 1976 | 1824 | 0   | 152 | 4/4 | 0/0/1 | 368 / 336 pm  | 832 / 832 pm | 0 / 0 | 1216 / 1184 pm | 0.813 s |

Orphan replica (NOT a leg: generic/vrs spine, `seed_with_orphan ~desired:1
~fair:false`, plain productive successors at `Bound.default`, depth 4,
`frontier_emptied = false` - the section-4 MEASURED-CORRECTION):

| replica | states | M1 int/viol | M2 int/viol | M3 int/viol | M4 int/viol | M1-alone check_safety | cpu |
|---------|--------|-------------|-------------|-------------|-------------|-----------------------|-----|
| orphan d=4 | 1518 | 12 / 12 | 1408 / 0 | 679 / 0 | 532 / 0 | REFUTED, first_violated(family) = M1 | 0.475 s |

**Predictions, judged BY NUMBER:**

1. **CONFIRMED.** All four legs clean + decisive; the four graphs are
   EXACTLY 76 / 464 / 744 / 1976 (P13-P18 identity, no drift), with
   cws/ffs and uid/rv maxima matching the P16 graph constants per leg.
2. **CONFIRMED.** All four members hold at every reachable state of every
   leg (`violated = None` on all four; the orphan replica additionally
   shows M2/M3/M4 violation-free on a fifth, foreign graph).
3. **CONFIRMED.** M3 interesting = 0/0/0/0 on the four legs (both slices,
   honest N5 rows) and the orphan floor is strictly positive: 679 of 1518
   replica states carry a builtin-GC-sourced in-flight message, with M3
   green at all 1518.
4. **CONFIRMED.** M2 interesting = 0/0/0 on L0/Lc/Ld and 832 on Lm (832
   post-monkey - the two slices coincide: every monkey-sourced in-flight
   message is by definition post-monkey).
5. **CONFIRMED.** M1 = 16/156/64/368 and M4 = 16/208/448/1216, all > 0 on
   every leg.
6. **CONFIRMED.** The orphan replica refutes M1 asserted ALONE
   (`check_safety` = `Refuted`, `first_violated` over the full family at
   the counterexample state names M1) - the live red control, forge-free:
   the spine stamps `Controller (0, vrs-kind key)` at the SAME controller
   id 0 (B1's id fact, confirmed at runtime). M1's 12 premise states and
   12 violating states COINCIDE (every controller tag on that spine is
   vrs-kind).
7. **OPEN at B3** (by design): battery is 64 -> 65 with `t_p19_provenance`;
   the remaining two exes (`t_p19_mutation`, `t_p19_regression`) land in
   B4/B5. Full battery green at 65 (B3 run).

**Measured beyond the predictions (facts, not corrections):**

- **The seed's in-flight pool is EMPTY**, so no member fires there and the
  union gate is a PROPER subset on L0/Lc/Ld (32 < 76, 296 < 388 post-crash,
  448 < 592 post-drop): the gate is load-bearing, P18-style, not
  G7-saturated.
- **L0 gate 32 = M1's 16 + M4's 16 exactly** (disjoint premises on this
  graph: a pending controller request and a pooled api-server response
  never coexist fault-free at desired 1); Ld's post-drop gate 448 = 32 +
  416, disjoint again; Lc's 296 = 140 + 192 - 36 (the crash orphans the
  pre-crash request, letting it coexist with a stale response).
- **Lm's gate 1824 SATURATES the post-monkey slice** (= P17's S2-saturated
  gate count on this same graph) - but via the UNION only: no single
  member covers it (M2 832, M1 336, M4 1184).
- **Ld is M4-dominated** (M4 448/416 vs M1 64/32): the drop edge consumes
  the pending request and fabricates its api-server-sourced Error
  response, feeding M4's premise while starving M1's.
- **The orphan spine runs a LIVE pod monkey**: M2 interesting at 1408 of
  1518 replica states, violation-free - bonus green surface for M2 on a
  graph no leg explores.
- CPU times (`Sys.time`, leg-call-only): 0.012 / 0.067 / 0.133 / 0.813 s;
  orphan replica incl. counts + control 0.475 s - all far under the
  ~150 s harness alarm.

## 6. The E6 pin re-scope (the ONLY committed-test edit; pre-authorized)

`t_p18_regression.ml:224-245` (`test_e6_register_guard`): add
`("Msg_provenance.provenance_family (P19)", provenance_family ~controller_id)`
to the `hits_of` sweep roster (the `:233` cons list) and REPLACE the
absence assertion (:243-245) with the expectation of EXACTLY the P19 hit:
`[ "Msg_provenance.provenance_family (P19) ships " ^ e6_name ]`. The
`h1_name` positive control (:239-242) stays byte-unchanged. Update the
comment to record the claim ("claimed by P19 as specified at
BUILD-SPEC-P18.md:220-221"). Authorization: the pin's own text — "keeping
the message-guarantee register unambiguously inv_self's **until a
deliberate P19 port claims it**". The P18 disjointness sweep
(`shipped_suites`, :195-198) is NOT touched — P19-vs-shipped sweeps live
in t_p19_regression, which owns them.

MEASURED-CORRECTION (B5, the re-scope's disclosure surface): the section
above scopes the edit to the guard's body and its inline comment, but TWO
further strings in the same file still asserted the OLD claim after that
edit — the file-header bullet ("the upstream :1213 name must equal NO
shipped member name", :41-47) and the Alcotest case label ("E6: the :1213
name is shipped by no suite", :520 as committed). Both were left stale by a
literal reading of "the `:233` cons list + the `:243-245` assertion", and
both are DISCLOSURE, not measurement: a reader of a green battery would
have been told the opposite of what the guard now checks. Both were
rewritten to the re-scoped claim (shipped by EXACTLY the P19 family, and by
no other suite) as part of the same section-6 re-scope; no assertion,
control, or number changed, and the P18 disjointness sweep stays untouched.

**B1 gate (hard)**: before any build step, B1 re-verifies against live
files: the four upstream member bodies at the cited lines; message.mli's
host_id/content shapes; the CONFIRM items 1-7 (sections 2-4 + E4'
enumeration + item 6: no P19 member premise reads PVCs, justifying the
no-vct cut; item 7: `Common.object_ref` record shape + the controller
stamp site for ML3). Every CONFIRM lands in this spec as a
MEASURED-CORRECTION line if it deviates. A refuted RENDERING premise moves
the member to E5' (section 3) — the family never silently re-scopes.

## 7. Mutation matrix (Edit-applied, Edit-reverted, each revert verified by `git diff --stat` + battery re-green; never `git checkout --`; stage BEFORE any file-mutating sweep)

Forge battery first (t_p19_mutation.ml, 4-check parity per forge — the D1
discipline: holds false, interesting true, conjunction false, violated
names the member):

- **F-M1**: in-flight msg src `Controller (controller_id, pod-kind key)` —
  M1 red.
- **F-M2a/b/c**: src `Pod_monkey` with (a) `List_request` content (a
  false-arm), (b) pod-keyed `Get_request` (false-arm with pod kind — the
  arm, not the kind, must decide), (c) dst not `Api_server` — each M2 red.
- **F-M3**: src `Builtin_controller` with `Update_request` pod content —
  M3 red (`Get_then_delete_request` variant as a second row: red proves
  the strict-Delete reading).
- **F-M4**: src `Api_server`, dst `Api_server`, `Get_request` content —
  M4 red; sibling with src `External 0` — red (the External arm SEEN).

Lib rows (mechanism predictions committed now; graph literals are NEVER
pinned on mutant graphs — pin violated-name + mechanism only):

- **ML1 attribution flip**: pod_monkey.ml:66 (create arm)
  `pod_monkey_req_msg` -> `built_in_controller_req_msg`. Lm leg RED naming
  **M3** (monkey creates now carry the builtin tag; create is not delete);
  M2 stays green (its premise empties for that op). The cross-member
  attribution datum, P14-MA style.
- **ML2 floor-is-load-bearing**: builtin_controllers.ml:101 delete ->
  update content. All four legs PREDICTED INERT (builtin never fires on
  the vsts spine — prediction 3's mechanism); the ORPHAN REPLICA goes RED
  naming M3. This row is the proof that the replica floor is load-bearing;
  if the legs redden instead, prediction 3 was wrong — record and stop.
- **ML3 tag-kind stamp**: at the controller message stamp site (B1 item 7;
  expected `Message.controller_req_msg controller_id cr_key ...` in the
  controller/reconciler step path), mutate the embedded key's kind to
  `Pod.kind` (`{ key with kind = Pod.kind }`). Every leg RED naming M1 at
  the first controller message. inv_self is EXPECTED to stay green (it
  matches exact src `(controller_id, vsts_ref)`; the mutated src no longer
  matches, so inv_self's premise empties — the register-distinctness datum,
  measured, closing the loop on section 1's static argument).
- **MN1 negative control**: api_server response formation — suppress the
  src/dst swap in one `form_*_resp_msg` path (B1 pins the site). Family
  PREDICTED INERT (responses with src Controller: M1's kind check still
  passes — the key is the vsts ref; M4 sees content Api_response — out of
  scope); P16 `matched_family` expected RED (pairing broken). The
  family-measures-provenance-not-pairing boundary datum. If the family
  reddens, the prediction is recorded REFUTED with the mechanism.

Revert discipline: `sd` empty-pattern reverts FORBIDDEN (the
feedback-sd-empty-revert trap) — save pre-mutation bytes and rewrite, or
Edit the exact line back; verify by `git diff --stat` (only intended files)
+ battery re-green after EACH row.

### MEASURED (B4, 2026-07-27) — the matrix outcomes, judged by row

Method: every row Edit-applied at ONE site, `dunecho build`, the decisive
exes run, then reverted by rewriting the saved pre-mutation bytes (shasums
re-verified; `git diff --stat` EMPTY after each) and the touched exes
re-run green. The forge battery (`t_p19_mutation`, 6 cases: seed shape +
F-M1 / F-M2a,b,c / F-M3,F-M3' / F-M4a,b + the manual anchor) went green on
its first run and stayed green under every row except where noted.

MEASURED-CORRECTION (review, the F-M3 row's CONJUNCT coverage): as first
built, F-M3's control and both forges all sent
`Builtin_controller -> Api_server` with an `Api_request`, so only the
request ARM was varied and M3's other two conjuncts (the
`dst = Api_server` equality and the `Option.fold ... ~none:false`
non-request arm) had NO red witness anywhere (M3's premise is 0/0 on all
four legs, and every one of the orphan replica's 679 premise states is a
real GC delete addressed to the api server). Deleting either conjunct left
the whole battery green. Two rows were added to `test_f_m3`: **F-M3''**
(the GC's real delete sent to a CONTROLLER: the dst conjunct, F-M2c's
shape at the builtin source) and **F-M3'''** (a builtin-sourced RESPONSE:
the `~none:false` arm). Both are ISOLATIONs: M1 keys on a `Controller`
src, M2 on `Pod_monkey`, and M4's source scope excludes
`Builtin_controller`, so only M3 reddens. The F-M3 row's forge count is
therefore 4, not 2; case count unchanged.

| row | site | predicted | MEASURED | verdict |
|-----|------|-----------|----------|---------|
| ML1 | pod_monkey.ml:66 create arm -> `built_in_controller_req_msg` | Lm RED naming **M3**, M2 green, other legs inert | Lm Refuted, `violated` = M3 BY NAME; L0/Lc/Ld passed IN FULL (every pin); orphan replica ALSO red at M3 (679 violating states on the mutant's own graph) | **CONFIRMED** |
| ML2 | builtin_controllers.ml:101 delete -> update of the same key | four legs INERT, orphan replica RED naming **M3** | four legs passed IN FULL (M3's 0/0 vacuity rows included), `t_p19_mutation` FULLY green; replica red at "M3 violation-free" with **679** violating states = the floor `m3_interesting_orphan` | **CONFIRMED** |
| ML3 | controller.ml:234 tag kind -> `Pod.kind` | every leg RED naming **M1**; `inv_self` green | all four legs Refuted naming M1 (anchor's FIRST check printed the full M1 name); `t_p11_vsts_invariants` **safety_decisive PASSED** — `inv_self` (vsts_invariants.ml:214) never notices what M1 rejects | **CONFIRMED** + one correction below |
| MN1 | message.ml:200 `form_get_resp_msg` swap suppressed | family INERT, P16 `matched_family` RED | family BYTE-IDENTICAL (both P19 exes fully green, every pin incl. M4's counts); `t_p16_req_resp` red on EXACTLY its three vct:TRUE cases | CONFIRMED **but vacuous** — see correction |
| MN1' | message.ml:208 `form_create_resp_msg` swap suppressed (the reachable variant) | (implied inert) | L0/Lc/Ld family SILENT with only graph pins moving (76->28, 464->260, 744->312); **Lm RED naming M2**; orphan replica red at M2 (111 states) | **REFUTED on the monkey leg** |

- **MEASURED-CORRECTION (ML3, unpredicted second-order effect).** The
  tag-kind mutant also COLLAPSES the graph downstream: the api server
  stamps its response `dst = req.src`, which under the mutant is no longer
  the controller's own host id, so responses become undeliverable and the
  reconciler stalls after its first request. Seen as
  `t_p11_vsts_invariants`'s non_vacuity case reddening
  (interesting-count `etcd_objects_have_unique_uids` 38 -> 0: nothing but
  the CR is ever stored) and `t_p16_req_resp` reddening broadly. The
  ATTRIBUTION half is unaffected — the refutation lands at the FIRST
  controller message, before any response is needed — and the orphan
  replica passed IN FULL under ML3 (its depth-4 horizon never reaches a
  response delivery).
- **MEASURED-CORRECTION (MN1 site, the B1 pin refined).** B1 pinned the
  response-swap site at `form_get_resp_msg`, but that site is
  **UNREACHABLE on all four P19 legs**: the legs are vct:false (the
  k6-class cut, section 4) and the VSTS reconciler's sole `Get` emitter is
  `Get_pvc`, so no get response is ever formed. Evidence, two-sided: every
  P19 pin stayed byte-identical (a mis-stamped get response would have
  moved M4's api-server-sourced counts), and `t_p16_req_resp` reddened on
  exactly its three vct:TRUE cases (`l0v_vct`, `ldv_vct_drop`,
  `lcv_supplementary`) while its four vct:false cases stayed green. The
  MN1 row's inertness is therefore true but VACUOUS on the P19 legs, so
  the row was re-run at the reachable sibling site (MN1', same one-line
  shape, `form_create_resp_msg`) — the section's "one `form_*_resp_msg`
  path" realised where the legs actually execute.
- **MEASURED (MN1', the spec's prediction REFUTED on Lm — recorded
  honestly).** The boundary is NOT "provenance never sees pairing
  breakage". On L0/Lc/Ld the prediction holds exactly as written (clean,
  `violated = None`, decisive; a response inheriting
  `Controller (controller_id, vsts_ref)` still carries a vsts-kind tag, so
  M1 passes, and M4 sees `Api_response`, out of its `Api_request` scope) —
  with only the graph pins moving, the "pins move, the family does not"
  shape. On **Lm** the family REDDENS naming **M2**: the monkey's create
  RESPONSE inherits `src Pod_monkey`, and M2 — faithful to upstream
  network.rs:570-587 — asserts that every `Pod_monkey`-sourced in-flight
  message IS an api request (`api_request_of` is `None` on a response, so
  the `Option.fold ~none:false` rejects). One class of pairing breakage IS
  a provenance violation: a suppressed swap that lets a RESPONSE inherit a
  request-only sender tag. The same red appears on the orphan replica
  (111 violating states, its live monkey). BONUS: this is M2's red
  capability witnessed on a LIVE graph, forge-free — section 2 predicted
  M2's red would come only from forges + ML1.
- **Battery**: 64 -> 66 at B4 (`t_p19_provenance` + `t_p19_mutation`);
  `t_p19_regression` lands in B5 for the predicted 67. Full `dunecho
  runtest` green at 66. `lib/cluster` / `lib/controllers` mutation residue
  EMPTY at stage time (four saved files re-verified by shasum;
  `git diff --stat` empty).
- **Graph pins UNMOVED across every restored row**: L0/Lc/Ld/Lm =
  76/464/744/1976, gates 32/296/448/1824 — the P13-P18 identity, never
  retuned.

### MEASURED (B5, 2026-07-27) — the regression firewall + the final battery

`test/t_p19_regression.ml` landed with 8 cases in 3 groups, green on its
first run (0.001 s — no graph is explored there; every fact is a list
comparison over the shipped invariant records).

| group | case | outcome |
|-------|------|---------|
| prior_phase_firewall | P18/P16 witness constants = the committed literals (76/464/744/1976, slices 388/76/152/152, gates 52/244/272/1520, H1/H2 L0 52/0, L0v 116) | PASS |
| prior_phase_firewall | P19's four graph constants + four slices are DERIVED from that chain, not re-measured | PASS |
| family_classification | names, committed (name, source) pairs, `provenance_sources` order, cardinal 4 | PASS |
| family_classification | DISJOINT from all 10 shipped suites, BOTH argument orders, + self-sweep control (8 = 2 x 4 hits) | PASS |
| exclusion_pins | E1' — N4's pair absent from the family, family disjoint from P14's five, positive control finds N4 in `Correspondence.family` | PASS |
| exclusion_pins | E2' — the family's only `vstatefulset_controller/` citation is `helper_invariants.rs:1213`; zero `internal_rely_guarantee.rs` citations | PASS |
| exclusion_pins | E3' — `inv_self`'s name still shipped by `Vsts_invariants.always` (control) and absent from the P19 family | PASS |
| exclusion_pins | E4' — the built ledger equals the committed B1 text; accounting re-derives the 13, each once; P19's network members are exactly :540 :570 :618 | PASS |

- **The shipped-suite roster is 10** (the `t_p18_regression.ml:179-198`
  nine PLUS `Helper_invariants.helper_family` — the suite whose own E6
  guard P19 claimed, and therefore the one a P19 leak would poison first).
- **Both directions asserted, not inferred.** `Pair_guard.pair_leaks` is
  either-component, so one argument order already detects a leak in either
  list; the sweep runs `P19 -> suite` AND `P19 <- suite` anyway so the
  claim is visible in the code rather than resting on a reading of the
  detector. The self-sweep control (family vs itself, 8 hits) is what makes
  the empty leak list a MEASURED absence rather than a dead traversal.
- **The E4' ledger is load-bearing, not a comment**: its two crossed-out
  lines are rendered from the live `Correspondence.family` /
  `provenance_family` records (line numbers parsed off the `source`
  strings, names read off the records) and compared with the committed B1
  text (section 3 E4'). Scope, per section 3's MEASURED-CORRECTION: those
  two families are ALL the guard reads, and the leftover half of the
  comparison is a tautology (one binding on both sides), so a leftover
  shipped by a NEW family module is outside its reach.
- **Prediction 7 (section 5) — CONFIRMED.** Battery **64 -> 67**: 67 test
  exes built, `dunecho test` = **0 failed, 453 passed, 0 skipped, 453
  run**. `dunecho build` = 0 errors, 0 warnings.
- **MEASURED-CORRECTION (B5, the battery command).** Sections 5 and 7 write
  the battery run as `dunecho runtest`; `dunecho` accepts only
  `build | test | fmt | doc` and rejects `runtest` as an invalid MODE
  argument. Every battery figure in this file (65 at B3, 66 at B4, 67 here)
  was produced by `dunecho test`, which is dune's `@runtest` alias — the
  numbers stand, the command name in the prose did not.
- **Graph pins UNMOVED at stage time**: L0/Lc/Ld/Lm = 76/464/744/1976, now
  asserted from THREE independent sites (the P19 legs, P18's own battery,
  and this regression's literal re-pin of P18's committed values).
- **`lib/cluster` / `lib/controllers` mutation residue EMPTY** at stage
  time: `git status` lists no modified file outside the section-Files set.

## 8. Limits + residuals (disclosed, not hidden) + banked P20 candidates

1. **The monkey-rely divergence stays open** (P18 residual 6): M2
   classifies the SHIPPED monkey's emissions; a fabricating monkey (S3's
   Lf leg, GO_WITH_CHANGES) is the natural P20 — its scout evidence
   (Cluster.t forge field, rely_guarantee.rs:17-90 adversary shapes,
   per-conjunct H1 asymmetry predictions) is banked in the session's scout
   archive and this file's section 1.
2. **vct matrix beyond L0v still deferred** (P16 8.6): P19's no-vct cut is
   the same k6 class, with the stronger justification (no member reads
   PVCs at all).
3. **inv_self citation drift NOT fixed** (P18 residual 3 carried: fixing
   it moves k3 pins in four committed exes; P19 does not touch those pins).
4. **External-arm inertness** (M4): if B1 confirms no shipped spine takes
   an External step, the arm is structurally unexercised on live graphs —
   forge F-M4b is its only red witness; disclosed in the .mli.
5. **M1 is model-conditional**: claimed on the vsts spine only; the orphan
   replica measures it as a red CONTROL, never asserts it as an invariant.
6. **Banked candidates** (scout verdicts, this session): S3 Lf-monkey
   (P20 lead), S5 `local_pods_and_pvcs_are_bound_to_vsts` controller-local
   family, S7 `controller_runtime_safety` CR-validity trio, S4-recast
   stale-uid orphan seed + GC-live leg.

## Files

- `lib/assurance/msg_provenance.{ml,mli}` — the family (new).
- `lib/checker/fault_check.{ml,mli}` — the leg + MEASURED doc block (edit,
  append-only after the P18 leg; shipped legs byte-identical).
  - MEASURED-CORRECTION (B1): the P18 leg (fault_check.ml:664-691) is NOT
    last in the file - G2 `check_unique_reconcile_id_under_faults`
    (:701-722) and G3 `check_settles_after_disable` (:754-776) follow it.
    "Append-only after the P18 leg" is realised as APPEND AT EOF (after
    :776), which keeps every shipped leg byte-identical AND line-stable;
    the .mli `val` + doc are likewise appended at the .mli's EOF (after
    the G3 entry, :1393).
- `lib/checker/BUILD-SPEC-P19.md` — this file.
- `test/p19_witness.ml` — pins; graph constants DERIVED from p18/p17
  witnesses where identical, new literals only for gates + member counts +
  the orphan-replica floor.
- `test/t_p19_provenance.ml` — 4 legs + replica counts + semantics checks
  + the orphan floor replica (section 4).
- `test/t_p19_mutation.ml` — forge battery + ML1-ML3/MN1 records, 6-row
  banner header in the t_p18_mutation.ml format.
- `test/t_p19_regression.ml` — classification firewall (pair_guard, both
  directions, all shipped suites incl. P18) + E1'-E4' pins + P18-literal
  duplication (the sanctioned duplication).
- `test/t_p18_regression.ml` — section 6 re-scope ONLY.
- `test/dune` — 3 new exes; battery 64 -> 67.

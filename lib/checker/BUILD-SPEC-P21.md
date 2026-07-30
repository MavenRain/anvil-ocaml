# BUILD-SPEC-P21: the VSTS internal GUARANTEE register (the dual of P20's rely)

Phase 21 of the anvil-ocaml assurance port. Branch `p21-internal-guarantee` off
`eda1135` (P20). Ports Anvil's
`vstatefulset_controller/proof/internal_rely_guarantee.rs` GUARANTEE side
(`:544` and its three per-request helpers `:562` / `:581` / `:589`) as a new
disjoint family, and measures it on the five ALREADY-COMMITTED fault graphs.
Battery 70 -> 73 exes. NEVER `git commit` - stage only.

## 0. Provenance of this spec, stated honestly

The P21 scout wave (`wf_f8e9fdd0-3c6`, 10 agents) **largely died on quota**:
`agents_done=3`, `agents_error=7`. Two distinct caps were hit - a session limit
and a **weekly** limit (resets Jul 31 09:00 America/Vancouver). The three agents
that returned were the two PROCESS scouts (`S6-leg-conventions`,
`S8-mutation-conventions`) plus a critic that ran on their degraded two-scout
digest. **Every agent assigned a decisive question died**: register choice
(S1), port feasibility (S2), the E-ledger (S3), the competing candidate (S4),
seam/pin safety (S5), the battery (S7), the P20 debt (S9).

Consequence, and it is a real limit on this document: **sections 1-4 below were
established INLINE in the main context, not by delegated scouts, and they have
had no independent adversarial pass.** Every claim in them carries the literal
command that produced it so a later reviewer can re-run rather than re-trust.
The convention material in sections 5-7 does rest on the two surviving scouts.
Treat every number here as MEASURED-BY-ONE-OBSERVER until the review wave runs.

## 1. Why this phase (the register is unoccupied, and that is grep-checkable)

P20 shipped the port's first ASSUMPTION register:
`vstatefulset_controller/trusted/rely_guarantee.rs`, what the environment must
promise the VSTS controller, assumed and never discharged. **P21 is its exact
dual**: what the VSTS controller GUARANTEES to everyone else. It lives in
`proof/`, not `trusted/`, and it IS discharged upstream - by
`internal_guarantee_condition_holds` (`internal_rely_guarantee.rs:1003`) and
`internal_guarantee_condition_holds_on_all_vsts` (`:1196`).

That pairing is the phase thesis: **P20 measured that the port's pod monkey
VIOLATES the rely condition it is assumed to respect (R1/R2 red 208/208 on the
committed Lm graph). P21 asks the other half - does the port's own VSTS
reconciler HONOR the guarantee it is proved to honor?**

**NOVELTY, in its measured wording.** The whole upstream file is unoccupied:

```
$ rg -n 'source = "[^"]*internal_rely_guarantee' lib/ test/
(exit 1, ZERO hits)
```

Run WITHOUT a trailing slash and WITHOUT any narrowing suffix - the exact defect
that cost P20 a review finding (its `trusted/` sweep hid
`vsts_invariants.ml:297`, whose source string is `trusted` followed by a SPACE).
The companion sweep, which matches BOTH upstream `*rely_guarantee.rs` files:

```
$ rg -n 'source = "[^"]*rely_guarantee' lib/ test/
lib/assurance/rely_conditions.ml:171   (trusted/rely_guarantee.rs:57)
lib/assurance/rely_conditions.ml:199   (trusted/rely_guarantee.rs:76)
lib/assurance/rely_conditions.ml:231   (trusted/rely_guarantee.rs:17)
+ 3 quotations of those same lines inside BUILD-SPEC-P20.md
(exit 0)
```

So every existing hit is P20's own, on the OTHER file. The shippable claim, and
the only one that may appear in prose anywhere, is: **no shipped member cites
`proof/internal_rely_guarantee.rs` at all before P21.** It is NOT claimed that
this is the port's first `proof/`-sourced family (it obviously is not) nor its
first guarantee-flavoured one (`vreplicaset_controller/proof/guarantee.rs` is
already cited once).

**Why this register and not the banked alternative.** The other banked P21
candidate was `kubernetes_cluster/proof/controller_runtime_safety.rs`. It is
**already partly occupied**, which decides it:

```
$ rg -n 'source = "[^"]*controller_runtime_safety[^"]*"' lib/
lib/assurance/invariants.ml:122  :874  every_ongoing_reconcile_has_unique_id
lib/assurance/invariants.ml:237  :15   scheduled_cr_has_lower_uid_than_uid_counter
lib/assurance/invariants.ml:253  :47   triggering_cr_has_lower_uid_than_uid_counter
lib/assurance/invariants.ml:472  :15   (second scenario)
lib/assurance/invariants.ml:488  :47   (second scenario)
lib/assurance/invariants.ml:701  :911  every_msg_from_key_is_pending_req_msg_of
```

Four distinct predicates from that file are shipped already (P12 + the
`Invariants` core). `internal_rely_guarantee.rs` has zero. Unoccupied beats
partly-occupied.

## 2. The family (`lib/assurance/internal_guarantee.ml` / `.mli`)

Upstream has exactly **nine** `pub open spec fn` in the file
(`rg -c 'pub open spec fn' <file>` = 9). The partition below is TOTAL and
DISJOINT - every one of the nine lands in exactly one bucket.

### 2.1 SHIPPED (4 members)

| id | upstream | line | shape |
| --- | --- | --- | --- |
| G1 | `vsts_internal_guarantee_create_req` | `:562` | per-request `bool`, LIFTED over VSTS-controller-sourced creates |
| G2 | `vsts_internal_guarantee_get_then_delete_req` | `:581` | per-request `bool`, LIFTED |
| G3 | `vsts_internal_guarantee_get_then_update_req` | `:589` | per-request `bool`, LIFTED |
| G4 | `no_interfering_request_between_vsts` | `:544` | upstream's own `StatePred`, shipped whole |

G1-G3 are lifted the way P20 lifted R1/R2 from the per-request `bool` helpers
`vsts_rely_create_req` / `vsts_rely_update_req`. G4 is upstream's own
always-member, the way P20's R3 was.

**G4 IS STRICTLY STRONGER THAN `G1 && G2 && G3`, and this is the design point
that avoids repeating P20 review-finding A.** P20 shipped a pin asserting
`R3 <=> R1 && R2`; review found that was a THEOREM of the code (R3's constrained
arms call the same helpers over the same message list, and
`for_all f l && for_all g l = for_all (fun x -> f x && g x) l`), so the pin
could not fail under ANY mutation of the helpers. Here the analogous identity is
**false on purpose**: G4's `match` at `:550-557` also carries

- the READ-ONLY arms - `ListRequest | GetRequest => true` (`:551`), and
- the FORBIDDEN-KIND arm - `_ => false` (`:556`), which rules out
  `DeleteRequest`, `UpdateRequest`, `UpdateStatusRequest` and
  `GetThenUpdateStatusRequest` outright,

while G1/G2/G3 lifted individually constrain only their own request kind and are
vacuously true on every other kind. So a mutation that makes the reconciler emit
a plain `Update_request` **reddens G4 and leaves G1/G2/G3 green**. That is a
real cross-member attribution datum, and section 6 row MG1 measures it. No
`g4_identity_disagreements`-style pin is shipped; if a refactor guard on arm
dispatch is wanted, it must be labelled a refactor guard and nothing more.

### 2.2 EXCLUDED, each with a pin (the Q4 / P14-N5 discipline)

| id | upstream | line | why excluded |
| --- | --- | --- | --- |
| E1 | `vsts_internal_guarantee_conditions` | `:522` | `forall vsts. G4(controller_id, vsts)`. On a single-CR scenario this COLLAPSES to G4 at the scenario CR, so shipping it would be G4 wearing a hat. Same scenario-conditional vacuity P20 recorded as its own E1. A two-controller / two-CR spine de-vacuizes it; that is a P22. |
| E2 | `every_msg_from_vsts_controller_carries_vsts_key` | `:528` | **ALREADY SHIPPED** as P19's M1, cited to `helper_invariants.rs:1213`. P19's ledger flagged this exact name collision (its E2'). The build MUST re-read both upstream definitions and the shipped OCaml member and record whether they are semantically identical or merely near - P19 asserted "semantic duplicate" and that assertion has never been re-measured. **RE-MEASURED (build): SEMANTICALLY IDENTICAL**, not merely near. The two definitions differ by exactly one unfolding of the `pub open` spec fn `is_controller_id` (`message.rs:242-247`): quantifier, trigger, in-flight premise, conclusion, projection (`->Controller_1.kind`) and key comparison agree token-for-token (both even carry the same dead `let content` binding). Upstream certifies the identity itself with a one-assert bridge, `liveness/proof.rs:903-927` (direction B implies A, then `always_weaken`); the converse is the same single unfolding. The asymmetry is role, not semantics: `helper_invariants.rs:1213` is the PROVEN member (always-lemma `:1224-1260`, carried in `liveness/spec.rs`), while `:528` is only a bundle hypothesis (`predicate.rs:130`) whose truth derives from the bridge. So the shipped citation to `helper_invariants.rs:1213` is the better of the two names, and the exclusion ground stands. |
| E3 | `local_pods_and_pvcs_are_bound_to_vsts` | `:606` | the CONTROLLER-LOCAL register. Needs the typed VSTS reconcile state, and the port's `Controller.ongoing_reconcile.local_state` is an untyped `Value.t` (`controller.mli:60`). Real plumbing, not a rendering choice. BANKED for P22. |
| E4 | `..._with_key_in_local_state` | `:613` | helper of E3. |
| E5 | `..._with_key` | `:640` | helper of E3; additionally constrains `pending_req_msg` and the `AfterListPod` step, so it needs step-level reconcile introspection the port does not expose either. |

4 shipped + 5 excluded = 9. Total, disjoint.

### 2.3 Family shape

Upstream G4's premise is
`msg.src == HostId::Controller(controller_id, vsts.object_ref())` (`:549`), and
its body reads `vsts.metadata.namespace`, `vsts.metadata.name` and
`vsts.controller_owner_ref()`. The port's `Message.host_id` is
`Controller of int * Common.object_ref` (`message.mli:40`) - the exact analogue.

So the family needs BOTH the CR and the controller id, i.e. the P18 shape:

```ocaml
val guarantee_family : cr:V_stateful_set.t -> controller_id:int -> Invariants.invariant list
```

Not P20's plain-list shape - here every member genuinely consumes both. The
`.mli` must DISCLOSE that CR-parameterization narrows upstream's `forall vsts`
(E1) to THE scenario CR, exactly as `helper_invariants.mli` discloses it.

### 2.4 Rendering notes (each is a decision, and each goes in the `.mli`)

- **Projection**: `Message.Pool.distinct (Cluster.in_flight s)`, the `inv_self`
  precedent (`vsts_invariants.ml:152`), P19's (`msg_provenance.ml:22-23`) and
  P20's (`rely_conditions.ml:21-22`). Upstream's `forall` at `:546-549`
  quantifies over `s.in_flight()` alone.
- **Owner-ref comparison**: `Owner_reference.eq_without_uid`
  (`owner_reference.mli:26`) IS upstream's `owner_reference_eq_without_uid`
  (`kubernetes_api_objects/spec/owner_reference.rs:37-42`, four conjuncts:
  controller, block_owner_deletion, kind, name). Already exported; do not
  re-render it. The E1 boundary P18 documented applies unchanged.
- **Exactly-one owner ref**: upstream `:568-571` requires
  `owner_references == Some(Seq::empty().push(r))` - a ONE-element sequence, not
  "contains". Render as a one-element list test, NOT `List.exists`. This is
  strictly stronger than P20's R1 collapse and must not be weakened to match it.
- **Name matchers**: upstream `pod_name_match` (`proof/predicate.rs:146-148`)
  and `pvc_name_match` (`:140-143`). P18 already shipped `pvc_name_matches`
  (`helper_invariants.ml:32`) and documented why the abstract-string existential
  is narrowed; REUSE that decision and cite it rather than re-litigating it.
- **No `match` on `option` / `result`**, no partial accessors, no `List.nth`, no
  wildcard arm on a finite sum. The nine `Api_method.api_request` constructors
  (`api_method.mli:103-112`) and the five `Message.host_id` constructors get
  spelled out. House rules, hook-enforced.

## 3. The leg

One new leg, appended at EOF of `lib/checker/fault_check.ml`, following the P20
Leg-A wiring verbatim (`fault_check.ml:862-884`):

```ocaml
let check_internal_guarantee_under_faults ?(depth = default_depth)
    ?(req_drop = false) ?(pod_monkey = false) (bound : Bound.t)
    (budget : budget) ~(desired : int) ~(require_fault : bool) : fault_report
```

**No new seam. No new `Bound` field. No `Cluster.cluster_state` field.** This is
the phase's strongest pin-safety property and it must be stated as such: the
guarantee quantifies over in-flight messages tagged with a controller src, and
the port has tagged them since P19. **All five committed pins must therefore come
back UNMOVED: L0 76, Lc 464, Ld 744, Lm 1976, L0v 116.** A moved pin is a
phase-STOP, not a number to update.

No `?vct` is threaded: no member reads PVC *templates* (G1's PVC arm reads the
requested object, which is present on the vct:false legs too). Disclose the cut
as P20 disclosed its own, and note it is a cut, not a proof of irrelevance.

## 4. Predictions, committed BEFORE the build

Written down now so the build can REFUTE them. The port's reconciler was read
inline and appears faithful, so the honest prior is "green everywhere", and a
green that was never at risk is worth nothing - hence section 6.

1. **G1-G4 all GREEN on all five committed legs.** Grounds: `make_pod`
   (`v_stateful_set_reconciler.ml:361-383`) sets exactly one owner ref via
   `make_owner_references` (`:218-220`, a one-or-zero-element list), a
   `pod_name`-minted name, no `generate_name`, no finalizers; `make_pvc`
   (`:260-289`) builds from `Object_meta.default ()` with name/namespace/labels
   only, so `owner_references` is `None` as G1's PVC arm requires; both create
   sites pass the CR's namespace (`:604-618`, `:642-650`).
2. **G4's forbidden-kind arm is NON-VACUOUS but never fires.** The reconciler
   emits exactly `List_request` (`:530`), `Get_request` (`:580`),
   `Create_request` (`:614`, `:649`), `Get_then_update_request` (`:697`),
   `Get_then_delete_request` (`:734`, `:779`) - precisely upstream's permitted
   set. So the `_ => false` arm should be reachable-but-unfired on every live
   graph. **If it fires, that is a fidelity divergence and a real finding.**
3. **`interesting` is non-zero on every leg** (VSTS-sourced requests are in
   flight on all five graphs). A zero here is an N5-style vacuity row and must
   be reported as one, not hidden.
4. **G2/G3 fire only where the reconciler reaches its delete/update steps** -
   plausibly zero on L0. Predicted, so a zero is a recorded row rather than a
   surprise.

Any prediction that measurement refutes gets a MEASURED-CORRECTION section
appended to this file, in the P19/P20 style. Refutation is the valuable output.

## 5. Mutation matrix (the only thing that makes a green mean anything)

Protocol, from the surviving `S8-mutation-conventions` scout and the standing
rules: **stage BEFORE any file-mutating sweep**; apply with `Edit`, revert with
`Edit`; NEVER `git checkout --` (destroys uncommitted work) and NEVER
`sd -s '' '<line>'` to revert a deletion (explodes the file - swap line <-> marker
instead); verify each revert with `git diff --stat` plus a battery re-green.

| row | mutation | prediction |
| --- | --- | --- |
| MG1 | make the reconciler emit `Update_request` where it emits `Get_then_update_request` (`:697`) | **G4 RED, G1/G2/G3 GREEN** - the section-2.1 strictness claim, and the row that proves G4 is not `G1&&G2&&G3` |
| MG2 | drop the owner ref in `make_owner_references` (`:218-220`) -> `[]` | G1 RED (Pod arm, `:568-571`); G4 RED via G1 |
| MG3 | give `make_pvc` an owner ref (`:279-286`) | G1 RED (PVC arm, `:575`) only |
| MG4 | mint a non-`pod_name` pod name in `make_pod` (`:377`) | G1 RED via `pod_name_match` (`:572`) |
| MG5 | mutate the create request's namespace (`:650`) off the CR's | G1 RED via `:563` |
| MG6 | wrong owner ref on the `Get_then_delete` request (`:734`) | G2 RED (`:585`), G1/G3 GREEN - per-member attribution |
| MG7 | swap the family's `~controller_id` for a non-matching id | ALL members go vacuously GREEN with `interesting` 0 - the premise-necessity row (P15 discipline) |

MG7 is the one that catches the worst failure mode - a family that is green
because its premise never fires. It must be run even though it is "obviously"
going to pass.

## 6. Files

- `lib/assurance/internal_guarantee.{ml,mli}` - the family (new).
- `lib/checker/fault_check.{ml,mli}` - one leg, APPENDED AT EOF; every shipped
  leg must stay byte-identical.
- `lib/checker/BUILD-SPEC-P21.md` - this file.
- `test/p21_witness.ml` - every pinned constant as a named `let`; the five
  inherited graph literals DERIVED from the p19/p20 witnesses, not re-typed,
  except in `t_p21_regression.ml` where re-typing them IS the prior-phase
  firewall (the sanctioned P14/P19 duplication).
- `test/t_p21_guarantee.ml`, `test/t_p21_mutation.ml`,
  `test/t_p21_regression.ml` - added to `test/dune`'s `(tests (names ...))`.
  Battery 70 -> 73.

**`t_p20_regression.ml`'s `committed_roster` is a literal 12-label list asserted
against `shipped_suites`** (P20 residual 7). P21 must EXTEND it and move the P20
label out of the self-exclusion filter into the swept set. A verbatim copy
forward reddens immediately - that assertion is its own guard.

## 7. Limits, disclosed

1. Sections 1-4 had no independent adversarial pass (section 0). The review wave
   is owed and is not optional.
2. E1's collapse is scenario-conditional, not a theorem. A two-CR spine is the
   experiment that would make it live.
3. E3-E5 (the controller-local register) are DEFERRED for a stated reason -
   untyped `local_state` - not because they are uninteresting. They are the
   strongest remaining unoccupied register in this file.
4. P20 residual 9 stands: `t_p20_mutation.ml`'s F-R1a / F-R1b / F-R2a /
   F-R3-update rows must stay alive; P21 must not disturb them.
5. Build/env: `dunecho build @runtest` is INVALID (`dunecho` takes one MODE arg,
   and `dune` is not on the default PATH). Working form:
   `eval $(opam env --switch=anvil-ocaml --set-switch) && dune build @runtest`.
   `ocamlformat` is NOT installed in that switch and all nine pre-existing dune
   files already report "needs promotion" - pre-existing committed state, do NOT
   promote.

## 8. MEASURED (2026-07-28, throwaway probe `probe/zz_p21_probe.ml`; replica
technique = t_p20_rely.ml:250-255 verbatim, bound/budgets read off the
P12-P20 witness chain, never re-typed)

**All five committed pins reproduced EXACTLY - the section-3 phase-STOP was
never tripped:** L0 76, Lc 464, Ld 744, Lm 1976, L0v 116. Every leg CLEAN and
DECISIVE; **red 0 on every member over every graph.**

| leg | states | gate | G1 int/red | G2 int/red | G3 int/red | G4 int/red |
| --- | --- | --- | --- | --- | --- | --- |
| L0 | 76 | 16 | 4/0 | 0/0 | 4/0 | 16/0 |
| Lc | 464 | 140 | 68/0 | 0/0 | 16/0 | 156/0 |
| Ld | 744 | 32 | 24/0 | 0/0 | 8/0 | 64/0 |
| Lm | 1976 | 336 | 24/0 | 0/0 | 200/0 | 368/0 |
| L0v | 116 | replica-only | 8/0 | 0/0 | 4/0 | 28/0 |

- **Prediction 1 CONFIRMED**: G1-G4 green on all five graphs.
- **Prediction 2 CONFIRMED at the green level**: no red anywhere, so the
  forbidden-kind arm never fired; the mutation matrix (MG1) is what makes that
  green mean something.
- **Prediction 3 CONFIRMED**: the family gate is non-zero on every leg
  (16/140/32/336, and G4's interesting is 28 on the L0v replica). Unlike P20,
  **L0/Lc/Ld are NOT vacuity rows** - the guarantee family's premise is
  CONTROLLER-sourced traffic, which exists without any adversary. The
  fault-dimension legs here measure whether faults can PROVOKE the reconciler
  into an off-repertoire emission; they cannot.
- **Prediction 4 REFUTED in both directions, recorded honestly.**
  (a) **G2 (`get_then_delete`) is vacuous on ALL FIVE graphs**, not just L0:
  `interesting = 0` everywhere. At `desired = 1` with no scale-down the
  reconciler never reaches its delete steps
  (v_stateful_set_reconciler.ml:734/:779). G2's green is honest vacuity
  family-wide (the P20 PVC-arm class: disclosed, not narrowed away); its only
  live witness would be a scale-down scenario (desired shrinks, or stored pods
  exceed desired) - banked as a P22 candidate. Consequence for section 5:
  **MG6 is predicted INERT on every committed graph** (its red witness is a
  G2 premise that never fires); the row is still run, and an unexpectedly
  moving pin there would be a real finding.
  (b) **G3 fires on fault-free L0** (interesting 4): the rolling-update path
  emits `Get_then_update_request` even in the fault-free run, against the
  "plausibly zero on L0" lean.
- **L0v is replica-only**: the leg threads no `?vct` (section 3's cut), and
  its seed is built internally, so the 116-state row is the family evaluated
  directly over the local replica of the vct:true zero-budget graph - the
  exact t_p20_rely L0v pattern. Reported as such wherever the row is cited.

### 8.1 Mutation matrix MEASURED (protocol: Edit apply / probe / Edit revert / `git diff --stat` empty, per row)

Provenance, stated honestly: rows MG1-MG4 were run by the measurement agent,
which was then killed by the session token limit BETWEEN MG5's apply and its
probe run, leaving the MG5 mutant live in the tree (the exact
die-between-apply-and-restore failure mode). The orphan was detected by
`git status`, reverted by `Edit`, and every completed row's revert was
verified `git diff --stat`-empty in the agent transcript before its numbers
were salvaged. MG5-MG7 were completed inline afterwards.

| row | leg outcome | violated (first) | pins (L0/Lc/Ld/Lm/L0v vs 76/464/744/1976/116) | member reds | verdict vs section-4/5 prediction |
| --- | --- | --- | --- | --- | --- |
| MG1 `Update_request` swap `:697` | REFUTED on all four legs | `no_interfering_request_between_vsts` | ALL FIVE MOVED: 72/452/736/1752/112 | G4 only: 4/16/8/200/4. G1=G2=G3=0 everywhere | **CONFIRMED** - the strictness row. G4 is not `G1&&G2&&G3`: no other member sees the forbidden kind |
| MG2 `make_owner_references` -> `[]` | REFUTED on all four legs | `vsts_internal_guarantee_create_req` | 76 OK / 444 MOVED / 744 OK / 1928 MOVED / 116 OK | G1=G4: 8/80/32/208/8 | **CONFIRMED** (G1 RED, G4 via containment) |
| MG3 `make_pvc` given an owner ref | all four legs CLEAN, pins OK | none (leg-invisible) | ALL FIVE UNMOVED on legs; L0v replica reds | L0v replica ONLY: G1 red=4, G4 red=4 (G2 0, G3 0) | **PARTLY REFUTED**: G1 RED confirmed but ONLY on the vct:true L0v replica (the leg's no-`?vct` cut makes the PVC arm dead on all four leg graphs), and G4 reds too, so ":575 only" was wrong twice. This row is the measured justification for keeping the replica-only fifth row |
| MG4 non-invertible pod name `:377` | REFUTED on all four legs | `vsts_internal_guarantee_create_req` | 76 OK / 444 MOVED / 744 OK / 1928 MOVED / 116 OK | numerically identical to MG2 (G1=G4: 8/80/32/208/8; L0v G1 int 12 red 8) | **CONFIRMED** (G1 RED via `pod_name_match`); the MG2-identity is a datum: both mutants collapse to "created pod fails the same three-conjunct arm" |

Violated-name ordering datum: MG2/MG4 report `violated = G1` (family order,
first violated member wins); MG1 reports `violated = G4` (sole violated
member). Both behaviors match `violated_of`'s documented family-order
semantics.

Rows completed inline after the agent death (same per-row protocol):

| row | leg outcome | violated (first) | pins | member reds | verdict vs section-4/5 prediction |
| --- | --- | --- | --- | --- | --- |
| MG5 create namespace off-CR `:650` | **UNMEASURABLE: STATE-SPACE BLOW-UP** | n/a | n/a (no row ever flushed) | n/a | The probe ran 8h22m wall-clock at ~91% CPU (866 MB RSS, actively exploring, not wedged) without completing even L0, vs ~2 min for the full five-graph baseline; killed deliberately. Mechanism: pods created in the off-CR namespace are invisible to the reconciler's own list/get, so reconcile never converges and the bounded product explodes. The blow-up IS the row's datum: the mutant is behaviorally catastrophic long before any invariant is evaluated, and `:563`'s red remains formally unwitnessed at this bound |
| MG6 wrong owner ref on `Get_then_delete` `:734` | all four legs CLEAN, ALL pins OK | none | 76/464/744/1976/116 all OK | zero everywhere; table numerically IDENTICAL to baseline | **REFUTED BY VACUITY**: section 5 predicted G2 RED, but G2 `interesting=0` on every graph (baseline section 8) means the `Delete_condemned` arm is dead code at desired=1 - the mutated request never enters any graph. INERT, the honest-vacuity reading; a G2-exercising scenario (scale-down) is P22 material |
| MG7 family at `~controller_id:(id+1)` (probe-side, `probe/zz_p21_probe.ml` MG7 block) | replica evaluation over L0 and Lm | n/a | L0 76 / Lm 1976 (same graphs) | `interesting=0 red=0` for ALL FOUR members on both graphs | **CONFIRMED** - the premise-necessity row: every member keys on `controller_id`, so the family cannot be green-by-accident at the wrong id; `red=0` (not red=all) also confirms vacuous truth, not vacuous falsity |

Post-matrix verification: the MG7 run doubled as the final pin re-check on the
reverted tree - all five pins OK, all four legs clean and decisive, so the
matrix left no residue. `git diff --stat` empty of tracked changes after every
revert (MG5's revert performed by the main loop after the orphan detection;
MG6's verified inline).

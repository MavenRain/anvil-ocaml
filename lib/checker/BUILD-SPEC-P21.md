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
| E2 | `every_msg_from_vsts_controller_carries_vsts_key` | `:528` | **ALREADY SHIPPED** as P19's M1, cited to `helper_invariants.rs:1213`. P19's ledger flagged this exact name collision (its E2'). The build MUST re-read both upstream definitions and the shipped OCaml member and record whether they are semantically identical or merely near - P19 asserted "semantic duplicate" and that assertion has never been re-measured. |
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

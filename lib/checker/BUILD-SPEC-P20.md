# BUILD-SPEC-P20: the VSTS pod-monkey rely condition (the first ASSUMPTION register)

Phase 20 of the anvil-ocaml assurance port. Branch `p20-rely-conditions` off
`15aedfd` (P19). Ports Anvil's `vstatefulset_controller/trusted/rely_guarantee.rs`
monkey rely condition (`:17` and its two request helpers `:57` / `:76`) as a new
disjoint family, measures it on the five ALREADY-COMMITTED fault graphs, and adds
one rely-VIOLATING forge leg (`Lf`) that makes the assumption's necessity
observable. Battery 67 -> 70 exes. NEVER `git commit` - stage only.

## 1. Why this phase (evidence-driven, from an 8-scout workflow `wf_214d9309-550`, 9/9 returned, 0 errors)

**The register is the novelty, and it is grep-checkable.** Every family this port
has shipped (P14-P19, plus the older `Invariants` / `Vsts_invariants` cores)
asserts something upstream **PROVES**: each member's `source` points into a
`proof/` file and is discharged by a Verus `lemma_always_*`. A rely condition is
the opposite epistemic object: it is what upstream **ASSUMES about the
environment** and never discharges. `vsts_rely_conditions_pod_monkey` lives in
`trusted/`, is threaded into the composition record's `environment_rely` slot
(`composition/vstatefulset_reconciler.rs:23`), and is consumed as a premise -
never as a conclusion.

The novelty claim is therefore checkable by grep rather than by argument, which
matters: this port has been burned three times by "first to do X" claims that a
later review refuted (P14's overclaim class, P16 F1, P17's premise break).

> **MEASURED-CORRECTION (B1 found it, B2 re-ran both sweeps, B7 re-ran them a
> third time). The sweep as this section originally worded it is REFUTED.** The
> original wording was: "zero shipped `Invariants.invariant` carries a `source`
> under `trusted/`" plus "`rg rely_guarantee lib/ test/` returns only
> `BUILD-SPEC-P3.md:15`". **Both are FALSE.**
>
> - `rg 'source = "[^"]*trusted' lib/` returns **two PRE-EXISTING hits** (see
>   REVIEW-FIX B below: B1/B2/B7 all ran this sweep with a trailing `/`, which
>   hid the second). So the blanket "zero" claim is false as written.
> - `rg rely_guarantee lib/ test/` returns 18 hits, not one, and they are the
>   DIFFERENT upstream file `internal_rely_guarantee.rs` or prose.
>
> **The two claims that survive measurement, and the only two that may be
> shipped in prose anywhere:**
>
> 1. `rg 'source = "[^"]*rely_guarantee' lib/ test/` exited 1 with ZERO hits
>    before this phase. Post-P20 it returns exactly the three new members
>    (`rely_conditions.ml:171`, `:199`, `:231`). No shipped `source` cited
>    `rely_guarantee.rs` at all before P20.
> 2. Every `trusted`-region-sourced invariant VALUE in the tree is a LIVENESS
>    GOAL and a member of no shipped safety family. So R1-R3 are the **first
>    `trusted`-sourced members of a shipped SAFETY family** - narrower than the
>    original claim, and that narrowed form is what `rely_conditions.mli` ships.

> **REVIEW-FIX B (post-B7 review): the sweep's trailing `/` was a DEFECT and
> the pre-P20 count is TWO, not one.** Every earlier run of the second sweep
> (B1, B2, B7) used `rg 'source = "[^"]*trusted/'`. The trailing `/` hides
> `vsts_invariants.ml:297`, whose source string is
> `"vstatefulset_controller/trusted (ordinal-stable ESR goal)"` - `trusted`
> followed by a **SPACE**. Re-run without it, against the live tree:
>
> ```
> $ rg -n 'source = "[^"]*trusted' lib/
> lib/assurance/rely_conditions.ml:171:      source = "vstatefulset_controller/trusted/rely_guarantee.rs:57";
> lib/assurance/rely_conditions.ml:199:      source = "vstatefulset_controller/trusted/rely_guarantee.rs:76";
> lib/assurance/rely_conditions.ml:231:      source = "vstatefulset_controller/trusted/rely_guarantee.rs:17";
> lib/assurance/vsts_invariants.ml:297:    source = "vstatefulset_controller/trusted (ordinal-stable ESR goal)";
> lib/assurance/invariants.ml:1040:    source = "vreplicaset_controller/trusted/liveness_theorem.rs:21";
> (exit 0)
>
> $ rg -n 'source = "[^"]*trusted' test/
> (exit 1, no hits)
> ```
>
> Three of the five are this phase's own members. The **pre-P20 count is TWO**,
> and both pre-exist at `15aedfd` at exactly these line numbers (verified with
> `git show 15aedfd:<file>` over all 222 `.ml`/`.mli` files in that tree):
>
> 1. `invariants.ml:1040`,
>    `vreplicaset_controller/trusted/liveness_theorem.rs:21`, inside
>    `Invariants.liveness_goal` (`:1037-1043`) - a LIVENESS GOAL and a member of
>    no shipped safety family: `partition` returns `inv1..inv16` and closes at
>    `invariants.ml:1023-1035`, `liveness_goal` is defined AFTER it, and it is
>    reachable through neither `always`, `eventually_always` nor `all`.
> 2. `vsts_invariants.ml:297`,
>    `vstatefulset_controller/trusted (ordinal-stable ESR goal)`, inside
>    `Vsts_invariants.liveness_goal` (`:293-300`). The same argument, VERIFIED
>    rather than asserted: `vsts_invariants` closes its list at `:286`
>    (`[inv_self; inv_ordinal; inv_pvc]`); `always` (`:288-291`) is
>    `Invariants.cluster_structural ~controller_id @ vsts_invariants ~cr
>    ~controller_id` and nothing else; `liveness_goal` is defined AFTER both, at
>    `:293`. The module exports only `always`, `liveness_goal` and
>    `current_state_matches` (`vsts_invariants.mli:11`, `:39`, `:43`) - there is
>    no `eventually_always` and no `all` here - and every caller of
>    `Vsts_invariants.liveness_goal` uses it as a `leads_to` TARGET
>    (`cluster_check.ml:541`, `:572`; `t_p13_faults.ml:369`;
>    `fault_check.mli:1311`), never as a safety member. No shipped safety family
>    pulls it in.
>
> So the narrowed novelty claim **stands**, now on a sweep that actually
> reproduces. Corrected at every site that carried the trailing `/` or the
> derived count of one: `rely_conditions.mli`, this file's §1 (here), the
> MEASURED-CORRECTIONS section's B2 item 4, and its B7 item 6.

**The headline is a refutation of a committed reading, found before the build.**
The banked P19 lead (section 8.6) proposed a fabricating monkey on the premise
that "the port monkey is rely-UNCONSTRAINED but candidate-restricted, so the rely
boundary has never been exercised" (`t_p18_helper.ml:17-18`, P18 prediction 4).
**That premise is false.** The port's monkey re-sends STORED pods byte-identically
(`cluster.ml:748-756`), the reconciler mints vsts pod names as
`"vstatefulset-" ^ parent ^ "-" ^ ord` (`v_stateful_set_reconciler.ml:190-191`),
and upstream proves every vsts-managed pod name carries that prefix
(`helper_lemmas.rs:92-102 pod_name_match_implies_has_vsts_prefix`). A stored vsts
pod also carries the vsts controller owner ref. So every Lm `Update_pod` /
`Create_pod` on a stored vsts pod is **already a rely-violating in-flight
message**: `vsts_rely_update_req`'s `!has_vsts_prefix(req.name)` (`:80`) fails, and
`vsts_rely_create_req`'s prefix (`:61-66`) and owner-ref (`:68-69`) conjuncts both
fail.

> **MEASURED-CORRECTION (B5), a NECESSITY qualifier on the sentence above.**
> Both conjuncts DO fail - the sentence is true - but **neither is NECESSARY,
> and the prefix conjunct is not load-bearing at all**. Measured from both
> sides, by mutation: deleting the FAMILY's prefix test (§7 ML2) moved not one
> leg, and deleting the MINTED prefix from the objects (§7 ML1) left R1 and R2
> RED because `make_pod` still installs the vsts controller owner ref
> (`make_owner_references`, `v_stateful_set_reconciler.ml:218-220`, stamped
> into the pod metadata by `make_pod` at `:379`). **This section's
> premise-refutation - the whole headline - rests on the OWNER-REF conjunct
> alone** (`rely_guarantee.rs:68-69` for R1, `:82-83` / `:85` for R2). Full
> numbers at §5.4. Any prose about the premise-refutation must attribute it
> there; attributing it to the prefix would be an unmeasured claim.

> **REVIEW-FIX D (post-B7 review): the rule above was stated here and then
> BROKEN at four shipped sites.** Each explained the Lm headline by the minted
> NAME PREFIX with no owner-ref mention anywhere in the block, which is exactly
> the unmeasured attribution this section forbids. All four now attribute the
> redness to the OWNER-REF conjunct (`rely_guarantee.rs:68-69` /
> `:82-83` / `:85`), cite the reconciler's owner-ref installation
> (`make_owner_references`, `v_stateful_set_reconciler.ml:218-220`, stamped by
> `make_pod` at `:379`) rather than its name-minting site `:191`, and record
> that the prefix conjunct is present but NOT load-bearing, citing the §5.4
> ML1 / ML2 rows:
>
> - `test/p20_witness.ml`'s Lm headline block.
> - `test/t_p20_rely.ml`'s exe-header item 2.
> - `test/t_p20_rely.ml`'s prefix-literal section, whose "a drift among the
>   three would silently empty the whole family" is FALSE as written: a drift
>   empties the PREFIX CONJUNCT only (this file's §2.3 already carried the
>   correction; the test did not).
> - `lib/checker/fault_check.mli`'s Lm headline bullet (the fourth site, found
>   by `rg 'already a rely-violating'`).
>
> The owner-ref installation line range was verified against the file before
> citing: `:218-220` is `make_owner_references`, and `:379` is where `make_pod`
> puts its result into the minted pod's `owner_references`.

The rely boundary has been crossed since P13. **P18's "Lm CLEAN = the monkey-rely
headline landed as predicted" is therefore not a rely-consistency result; it is
an emergent-robustness result** - H1 held on Lm *even though the assumption its
upstream proof rests on is false there*. P20's job is to make that observable and
to state the corrected reading at every site that carries the old one (section 6).

**The fidelity bar is met at the Verus `requires` level.** The red/green asymmetry
is not a modelling choice, it is citable:

| upstream member | lemma requires the monkey rely? | cite |
| H1 pods-in-etcd metadata | YES | `helper_invariants.rs:82` |
| H2 pvcs-in-etcd metadata | YES (but monkey emits no PVC request) | `:1085` |
| M1 msgs carry vsts key | NO | `:1227-1231` |
| M2 monkey reqs are pod reqs | NO | `network.rs:591-592` |
| M4 no self/external pending | NO | `network.rs:552-554` |
| S1-S3 store-side | NO | `objects_in_store.rs:316-317` |

And the rely is **bespoke, not a convention**: `vreplicaset`, `vdeployment` and
`rabbitmq` all set `environment_rely: true_pred()`. Only VSTS constrains its
environment, so measuring the constraint measures something real.

**Rivals rejected** (ranker `wf_214d9309-550`, each with a cited reason):
S7 `controller_runtime_safety` trio - CONTENT COLLAPSE (`scheduled_reconciles[k]`
and `triggering_cr` are verbatim copies of `etcd[k]` and no reachable step mutates
a CR spec, so all three members hold the identical truth value in every reachable
state), plus a fidelity inversion (upstream derives the etcd member from admission
control the port disables at `scenario.ml:265`). S5
`local_pods_and_pvcs_are_bound_to_vsts` (real cite `internal_rely_guarantee.rs:606`,
the banked `:926-931` was the lemma block) - three of four conjuncts are vacuous or
already shipped (condemned vacuous at `desired=1`; pvcs zero on every `vct:false`
graph; the AfterListPod pending-shape shipped by P15 R3/R4). S4-recast GC /
stale-uid - ~80% already shipped as `Scenario.seed_with_orphan` (`scenario.ml:638`),
and its headline member `garbage_collector_deletion_enabled` is a literal alias of
the port's own `Builtin_controllers.precondition` (`builtin_controllers.ml:78`) -
asserting it measures the model against itself. S8's P20-C CR-handoff family - its
own scout concedes 4 of 7 members are structurally enforced by port guards and
unfalsifiable by any fault.

**Arm A (the inside-rely forger) is deliberately NOT a leg.** A monkey that
fabricates arbitrary NON-vsts-prefixed pods is 100% inside the rely and strictly
more adversarial than today's echo monkey - but it is **provably green** on H1/H2
by upstream's own containment lemmas (`helper_lemmas.rs:92-102` for pods, `:80-90`
for PVCs): H1/H2's premise set is a strict SUBSET of the names the rely forbids
the monkey to touch. Spending a leg to confirm a foregone conclusion is
phase-weight bloat. The containment is stated as prose in the `.mli` and pinned as
a **control row** in the mutation matrix (section 7 row C1), not as a leg.

## 2. The family (`lib/assurance/rely_conditions.ml/.mli`)

New disjoint module, P14-P16/P18-P19 style (P17's filter pattern unavailable - no
member is shipped anywhere; rg-swept, zero hits in `lib/` and `test/`). Signature:

```ocaml
val rely_sources : string list
val rely_family : Invariants.invariant list
```

**Fully CR-agnostic and controller-id-agnostic** - stronger than every prior
family, and this is FIDELITY, not convenience. Upstream quantifies
`exists |vsts: VStatefulSetView|` over ALL vsts views (`:68-69`, `:82-85`), so the
predicate genuinely does not depend on the scenario CR. P18's H1 had to NARROW
that existential to the scenario CR and disclose the narrowing
(BUILD-SPEC-P18 §2); P20 does not, because of the collapse argument below. No
`~cr`, no `~controller_id`, no `?vct` is threaded - threading any of them would be
unclaimed strength (the P18 residual-1 discipline). `rely_family` is a plain
`Invariants.invariant list` value, not a function.

### 2.1 The owner-ref existential collapse (the key rendering argument)

Upstream's `!exists |vsts: VStatefulSetView| md.owner_references_contains(vsts.controller_owner_ref())`
quantifies over an infinite type. It is renderable EXACTLY, not approximately,
because `controller_owner_ref` FIXES three fields and leaves only two free.
Port's `V_stateful_set.controller_owner_ref` (`v_stateful_set.ml:173-181`) builds
`{ block_owner_deletion = Some true; controller = Some true; kind = V_stateful_set.kind; name; uid }`
where `name`/`uid` come from the CR's own metadata. Ranging over all
`VStatefulSetView` values makes `name` range over all strings and `uid` over all
uids, while the other three stay pinned. Therefore

```
exists vsts. owner_references_contains md (vsts.controller_owner_ref ())
  <=>  exists r in owner_references md.
         r.block_owner_deletion = Some true
         && r.controller = Some true
         && Common.equal_kind r.kind V_stateful_set.kind
```

This is an EQUIVALENCE (neither a narrowing nor a widening), and the family
renders the right-hand side.

> **MEASURED-CORRECTIONS (B2), three of them, all at this site. The collapse
> RENDERING is correct; the surrounding facts were wrong.**
>
> 1. **Span.** `controller_owner_ref` spans `v_stateful_set.ml:173-184` (record
>    literal `:177-183`), NOT `:173-181`. Fields: `:178`
>    `block_owner_deletion = Some true`, `:179` `controller = Some true`,
>    `:180` `kind`, `:181` `name`, `:182` `uid`. Three pinned, two free, exactly
>    as the collapse argument needs.
> 2. **Return type.** The port's `controller_owner_ref` returns
>    `Owner_reference.t option` (`Option.bind` on `metadata.name`, `Option.map`
>    on `metadata.uid`), not the bare record this section's wording implies. The
>    collapse is unaffected: the rendered right-hand side never CALLS the
>    function, it tests the three pinned fields directly.
> 3. **Omission.** `Object_meta.owner_references` is
>    `Owner_reference.t list option` (`object_meta.mli:16`), not a plain list, so
>    the collapse test needs `Option.fold ~none:false` BEFORE the `List.exists`.
>    `None` = no owner references = the NEGATED conjunct passes. Disclosed in
>    `rely_conditions.mli`.
Upstream's spec-level `controller_owner_ref` uses `->0` unwraps on `metadata.name`
/ `metadata.uid`, which in Verus are arbitrary-but-fixed on `None`; that only
widens the free range of `name`/`uid`, which the collapse already treats as fully
free, so the equivalence survives. Disclose this in the `.mli`.

### 2.2 The lift disclosure (why R1/R2 carry helper names)

Upstream's only ALWAYS-member here is R3 (`:17`). `vsts_rely_create_req` (`:57`)
and `vsts_rely_update_req` (`:76`) are per-REQUEST predicates, not `StatePred`s,
so they cannot be `Invariants.invariant` records as written. P20 ships them
**lifted**: `holds s` = "every in-flight message with `src = Pod_monkey` and
content `Api_request (Create_request _)` satisfies upstream `:57`" (resp.
`Update_request` / `:76`). The lift is upstream's OWN closure - it is exactly the
`forall msg` at `:19-23` restricted to the matching arm at `:24` (resp. `:25`) -
so the members keep upstream's helper names and `:57` / `:76` sources.
**This must be disclosed in the `.mli` as a DELIBERATE LIFT**, because a reader
comparing `name` against upstream will find a `bool`-typed helper, not a
`StatePred`.

### 2.3 Members

- **R1** `vsts_rely_create_req`, source
  `vstatefulset_controller/trusted/rely_guarantee.rs:57`. Lifted over monkey-sourced
  `Create_request`s. Per request: if the created object's kind is `Pod` or
  `Persistent_volume_claim` then (a) NOT vsts-prefixed - upstream reads
  `metadata.name` when `is Some`, ELSE `metadata.generate_name` (`:61-66`); render
  with `Option.fold`, never a `match` on the option; and (b) the collapse test of
  §2.1 is FALSE on `metadata.owner_references`. All other kinds: `true` (`:71`),
  spelled out arm by arm on `Common.kind`, **no wildcard**.
- **R2** `vsts_rely_update_req`, source `rely_guarantee.rs:76`. Lifted over
  monkey-sourced `Update_request`s. This one is a **StatePred, not a message
  predicate**: conjunct 2 (`:82-83`) reads `s.resources()[req.key()]`, the CURRENT
  etcd object. Per request, for `Pod` / `Persistent_volume_claim` kinds:
  (a) `not (has_vsts_prefix req.name)` (`:80`); (b) the STORED object at
  `req.key()` is not vsts-owned (collapse test); (c) the NEW object does not
  become vsts-owned (collapse test) (`:85`). **Missing-key rendering**: Verus
  `s.resources()[k]` on an absent key is an arbitrary total-map value, so the
  conjunct is unconstrained there; the port renders the lookup with
  `Option.fold ~none:true` (absent => conjunct (b) passes) and DISCLOSES it, the
  P17 `Option.fold md.uid ~none:(-1)` total-projection precedent. This choice
  cannot affect the headline: conjunct (a) already fails on every stored vsts pod.

> **CLARIFICATION, not a spec error (B2).** R2's kind dispatch is on
> `req.obj.kind` (`rely_guarantee.rs:78`), the OBJECT's kind, not
> `req.key().kind`; this section says only "for `Pod` /
> `Persistent_volume_claim` kinds". The port reads `Dynamic_object.kind r.obj`
> directly. The two coincide - `update_request_key` is
> `{obj.kind; namespace; name}` (`api_method.mli:121-122`) - but the object read
> is the literal upstream one.
>
> **MEASURED-CORRECTION (B5) on the last sentence.** "conjunct (a) already
> fails" is true but is the WRONG reason to be relaxed about the missing-key
> rendering, because conjunct (a) turns out not to be load-bearing (§1's
> necessity qualifier, §5.4 row ML2). The rendering is safe for a reason that
> survives: conjunct (c) reads the NEW object, not the store, and it fails on
> every stored vsts pod the monkey re-sends regardless of what the absent-key
> lookup returns.
- **R3** `vsts_rely_conditions_pod_monkey`, source `rely_guarantee.rs:17` -
  upstream's actual always-member and the one in the `environment_rely` slot.
  `forall` in-flight msg with `src = Pod_monkey && content is Api_request`:
  `Create => R1`, `Update => R2`, and **`_ => true` at `:26` rendered as an
  EXHAUSTIVE match** over every remaining `Api_method` request arm. The
  permissiveness is load-bearing upstream content ("Deletion/UpdateStatus requests
  are allowed"), not a default - a wildcard arm here would erase the phase's own
  subject matter.

**Deliberate redundancy, disclosed.** `R3 <=> R1 && R2` by construction. The three
members are NOT three independent facts; R1/R2 exist so the measurement can
ATTRIBUTE which arm reddens, which R3 alone cannot. The equivalence is asserted as
a pinned identity over every reachable state of every leg (section 5, prediction
6) - stating it as a measured identity rather than leaving a reviewer to notice
the overlap is the P17 overlap-misread discipline applied in advance.

**Projection.** All three traverse `Message.Pool.distinct (Cluster.in_flight s)` -
the `inv_self` / P19 precedent (`vsts_invariants.ml:152`, `msg_provenance.mli:15-17`).
Every classifier is per-message, so multiplicity adds nothing to truth or to
`interesting`.

> **MEASURED (B2), the projection question this section raised.** Upstream's
> `forall |msg|` premise at `rely_guarantee.rs:19-23` quantifies over
> `s.in_flight()` ALONE - there is no `pending_req_msg` conjunct - so
> `Cluster.in_flight` is the exact analogue and the controller's
> `pending_req_msg` slot (`controller.mli:57`) is deliberately NOT also ranged
> over. The choice is numerically load-bearing rather than cosmetic: P15/P16
> measured the wire pool and the pending slot DIVERGING under crash and drop, so
> ranging over both would move the Lc/Ld numbers. Disclosed at
> `rely_conditions.mli:33-43`.

**`interesting` (premise mirrors, P14 N3 - no borrowing).** R1: some in-flight
message with `src = Pod_monkey` and content `Api_request (Create_request _)`.
R2: same with `Update_request`. R3: same with any `Api_request`.

**`has_vsts_prefix`.** Upstream (`proof/predicate.rs:40`) is
`exists suffix. name == VStatefulSetView::kind()->CustomResourceKind_0 + "-" + suffix`,
i.e. a literal prefix test. Port renders `String.starts_with ~prefix:"vstatefulset-"`.

> **MEASURED-CORRECTION (B2), accessor and literal count.** `Common.show_kind`
> renders `CustomResource(vstatefulset)` (`common.ml:63`), so it is NOT a usable
> accessor for the pin; the bare string is `V_stateful_set.kind_name`
> (`v_stateful_set.mli:28`). And the reconciler does NOT derive its prefix from
> the kind: `v_stateful_set_reconciler.ml:191` (`pod_name`) and `:207`
> (`get_ordinal`) each hard-code `"vstatefulset-"` INDEPENDENTLY, so **three
> literals must agree**, not two. B2 ships the literal in the family (rather
> than `kind_name ^ "-"`) precisely so a `kind_name` drift cannot silently
> re-point the family away from the names the reconciler actually mints. The
> three-way agreement is a shipped TEST pin, as this section requires.
>
> **MEASURED-CORRECTION (B5), what that pin can and cannot see.** B5 measured
> that a family whose prefix test is deleted outright leaves every leg unmoved
> (§5.4 row ML2), so "a drift here silently empties the whole family" is FALSE
> as a general statement: it empties the prefix CONJUNCT, and the owner-ref
> conjunct keeps the headline red. The four `t_p20_mutation` rows F-R1a / F-R1b /
> F-R2a / F-R3-update are the only witnesses that discriminate the prefix
> conjunct **in the battery the sweep covered**: B5 ran
> `dune build @runtest --force` under the ML2 mutant over all **69** exes then
> present and found exactly one failing exe at exactly those four cases. The
> claim is scoped to that 69-exe battery; B6's later addition
> (`t_p20_regression`) does no model checking and adds no leg, so B7 carries the
> claim forward at 70 without re-running the mutant, and says so rather than
> restating it as if the sweep had been at 70. `t_p20_rely.ml:499-505`'s "behavioural
> prefix pin" does NOT discriminate it: its payload also carries the vsts owner
> ref, so its red survives the prefix test being deleted. Every assertion in
> that case is true; the case does not establish what its comment says.

> **REVIEW-FIX C (post-B7 review): `t_p20_rely`'s own comments now say this
> too.** The correction above was recorded HERE and nowhere else, so the test
> kept presenting the positive case as the family's behavioural prefix pin. Two
> `t_p20_rely.ml` comments are corrected - the prefix-literal section heading
> and the `(b)` block above the constrained-arm controls, which claimed "a red
> here proves the family's `\"vstatefulset-\"` literal agrees with the minting
> site". The POSITIVE payload is **OVER-DETERMINED**: `rely_violating_forge`'s
> object is minted by `make_pod`, which stamps BOTH a vsts-prefixed name
> (`v_stateful_set_reconciler.ml:376`) AND the vsts controller owner ref
> (`:379`), and R1 is a conjunction (`rely_conditions.ml:103-105`), so the
> owner-ref conjunct ALONE produces the red - which is why the whole exe stayed
> green under §7's ML2 mutant. The prefix conjunct is pinned by
> `t_p20_mutation`'s **F-R1a / F-R1b / F-R2a** rows and nowhere else, and the
> comments now cite them.
>
> **The ASYMMETRY is real and is preserved.** The NEGATIVE assertion
> (`t_p20_rely.ml:509-516`, the rely-RESPECTING forge's non-vsts name leaving
> R1 green under the identical create arm) is NOT over-determined - green there
> needs BOTH conjuncts to pass, so it does rule out a prefix test that matches
> everything, exactly as its own comment says. That comment is UNCHANGED. No
> assertion was added, removed or altered by this fix; it is comment text only.

## 3. Deliberate exclusions, each with a pin (the Q4 / P14-N5 discipline)

- **E1** `vsts_rely` (`:39`) and `vsts_rely_conditions` (`:32`) - the
  OTHER-CONTROLLER rely, not the monkey rely. Excluded because both shipped spines
  install exactly one controller model (`scenario.ml`), so
  `controller_models.remove(controller_id)` is EMPTY and the `forall other_id` is
  vacuously true in every reachable state of every leg. Pin: a test asserting the
  removal set is empty on both spines, so a future multi-controller scenario
  (P9-style) reddens the pin and re-opens E1 rather than leaving it silently
  stale. **This is the honest reason - not "out of scope".**
- **E2** `vsts_guarantee` (`:133`) and the `vsts_guarantee_*_req` trio
  (`:152`/`:164`/`:176`) - the GUARANTEE direction (what VSTS promises OTHERS).
  Excluded because P19's E3' already pinned this register to `inv_self` (widened
  inv9): it constrains controller REQUEST PAYLOADS. Porting it would re-open the
  P17-review overlap-misread class. Pin: P19's E3' guard already exists
  (`t_p19_regression.ml:340-346`); P20 adds the `rely_guarantee.rs:133` source to
  its exclusion assertion so the two phases' ledgers agree.
- **E3** `vsts_rely_get_then_update_req` (`:92`), `vsts_rely_delete_req` (`:105`),
  `vsts_rely_get_then_delete_req` (`:120`) - reachable ONLY through `vsts_rely`
  (`:45-53`), never through the monkey rely, whose match at `:23-27` has exactly
  two constrained arms. They are E1's helpers, and fall with E1. Pin: the
  exhaustive-match test on R3 asserts the Delete / Update_status / Get / List /
  Get_then_* arms all return `true`, which IS the `:26` semantics.
- **E4 SCOPE PIN** ~~`trusted/rely_guarantee.rs` has exactly **13**
  `pub open spec fn`~~ — **MEASURED-CORRECTION (B1, re-counted independently by
  B4 and again by B6): the file has exactly 12, not 13.**
  `rg 'pub open spec fn' src/controllers/vstatefulset_controller/trusted/rely_guarantee.rs`
  returns 12 lines: `:17 :32 :39 :57 :76 :92 :105 :120 :133 :152 :164 :176`. This
  is a CARDINALITY error in the spec, not a partition defect — the
  SHIPPED/LEDGERED partition is **total AND disjoint at 12**: 3 shipped
  (R1 `:57`, R2 `:76`, R3 `:17`) + E1 2 (`:32`, `:39`) + E3 3 (`:92`, `:105`,
  `:120`) + E2 4 (`:133`, `:152`, `:164`, `:176`), with no orphan. The pinned
  number is **12** (`p20_witness.ml:328 e4_spec_fn_count`).
  DONE: all 12 are counted, each is listed as shipped (R1/R2/R3) or ledgered
  (E1/E2/E3), and the partition is asserted total. Unlike P19's E4' ledger,
  this guard reads **every shipped suite** (section 6 D2), not just this
  phase's family. **B6 shipped that widened form**: `t_p20_rely.ml:825-856` pins
  the ledger off `Rely_conditions.rely_sources` (the shipped side), and
  `t_p20_regression.ml`'s E4 REVERSAL CLAUSE re-derives it over all TWELVE
  roster suites, so an E1/E2/E3 line shipped by any other module reddens and
  RE-OPENS the exclusion instead of leaving it silently stale.

## 4. The two legs

### 4.1 Leg A - `Fault_check.check_rely_conditions_under_faults` (zero new graph)

Appended at `fault_check.ml:826` and `fault_check.mli:1477` (the `.ml` is 825
lines, ending with P19's `check_msg_provenance_under_faults` at `:803-825`; the
`.mli` is 1476 lines ending with the P19 doc block `:1404-1476`). Every shipped leg
stays byte-identical and line-stable - the P19 append-at-EOF discipline.

> **CONFIRMED (B1 measured the append points, B3 shipped against them).** The
> `.ml` was 825 lines and the `.mli` 1476, exactly as stated; both legs plus the
> four forge constructors were appended at EOF and no shipped leg moved. This is
> a spec claim that survived measurement, recorded here so a later reader can
> tell it apart from the ones that did not.

Signature mirrors P19's: `?depth -> ?req_drop -> ?pod_monkey -> Bound.t -> budget
-> desired:int -> require_fault:bool -> fault_report`. **No `?vct`**: the monkey
emits only pod-keyed requests (P19 M2 pins exactly this), so the PVC arm of R1/R2
is unreachable on any graph regardless of `vct`. This is a stronger justification
than P19's k6 cut, and it is DISCLOSED rather than silently inherited.

Runs on the five ALREADY-COMMITTED graphs. All pins DERIVE from `p19_witness` /
`p18_witness` (the P19<-P18<-P17<-P16<-P15/P13 derivation chain); P20 introduces
**no new graph constant** for Leg A.

### 4.2 The forge seam, and why it is `Bound.t` and not `Cluster.t`

`cluster.ml:744-747` already documents its own candidate restriction as a SEARCH
decision tied to `max_objects_per_kind`: "candidate pods are the stored Pod
objects, capped by max_objects_per_kind. This excludes pod-monkey states reached
from pods never present in etcd (the object-count-symmetry bug class...)".

That settles the design and reframes the phase. The port's monkey is **not a
weaker MODEL** than upstream's (upstream's monkey has precondition `true`); it is
the same model under a **search restriction**. So the forge list belongs in
`Bound.t`, alongside the cap that already governs the same list - not in
`Cluster.t`, and emphatically not in `cluster_state`.

`Bound.t` gains `monkey_forge : Pod.t list` with default `[]`. At `cluster.ml:748`:

```ocaml
let pod_candidates =
  take b.max_objects_per_kind (stored_pods s) @ b.monkey_forge
```

Forged candidates are appended AFTER the capped stored list and are deliberately
NOT subject to `max_objects_per_kind` - they are an explicit, finite, hand-authored
list, and capping them could silently drop the witness the leg exists to produce.
DISCLOSE this asymmetry in `bound.mli`.

**PIN SAFETY - argued, then MEASURED.** `Cluster_check.state_equal`
(`cluster_check.ml:48-58`) and `state_hash` (`:75-87`) read ONLY
`Cluster.cluster_state`; `faulted_equal` / `faulted_hash` (`fault_check.ml:46-55`)
are those plus the three counters. Neither reads `Bound.t`. With
`monkey_forge = []` the appended list is empty, so the successor list is
element-for-element identical and all five pins are unchanged. A green argument
that was never run is not evidence ([[feedback-confirm-tests-by-mutation]]), so
it was run.

> **MEASURED (B3 probe, then B4 as a shipped pin).** With `Bound.monkey_forge`
> present and defaulted to `[]`: L0 **76**, Lc **464**, Ld **744**, Lm **1976**,
> L0v **116**. None moved. Cross-checked two ways at B3 (the probe re-explored
> each graph directly, AND the five committed witness exes `t_p13_faults`,
> `t_p15_reconcile_correspondence`, `t_p16_req_resp`, `t_p18_helper`,
> `t_p19_provenance` each exit 0 with the field in place), then re-measured at
> B4 through `test/t_p20_rely.ml`'s `pin_safety` case. L0v has no P20 leg
> (Leg A takes no `?vct`), so it is checked through a `~vct:true` replica: a
> pin-safety check on the `Bound.t` edit, not a rely measurement.
>
> **MEASURED-CORRECTIONS (B3), two, both at this site.**
>
> 1. **Blast radius confirmed EXACTLY at 13** full `Bound.t` record literals -
>    the sites B1 enumerated: `bound.ml:11`, `vsts_liveness.ml:34`,
>    `vrs_liveness.ml:103`, `p12_witness.ml:13`, `t_p11_vsts_invariants.ml:68`,
>    `t_p11_vsts_esr.ml:45`, `t_p11_mutation.ml:57`, `t_p5_cluster_check.ml:77`
>    and `:91`, `t_p5_mutation.ml:153` and `:164`, `t_p8_settle.ml:35`,
>    `t_p8_mutation.ml:40`. No other site needed an edit.
> 2. **`Bound.t`'s field count is now 8, not 7.** `bound.mli`'s closing "which
>    fields P2 actually consumes" block was updated accordingly: `monkey_forge`
>    is a FOURTH field the single-step `Cluster.enabled_successors` enumeration
>    reads, and it is the only one that WIDENS the successor set rather than
>    narrowing it.

**Two hard prohibitions**, both cited: a forge flag in `Cluster.cluster_state`
plus a `Disable_pod_forge_step` would DOUBLE all five pins exactly as `req_drop`
already does (`p15_witness.ml:318`); and a 13th `Step.t` arm plus a fourth
`Forges` budget dimension buys nothing over `Step.Pod_monkey_step of Pod.t`
(`step.ml:37`), which already carries an ARBITRARY `Pod.t` and is already charged
`Monkeys` (`fault_check.ml:81` `step_dimension`), while forcing edits to ~10
exhaustive `Step` matches across `lib/` and `test/`.

### 4.3 Leg B - `Lf`, the rely-VIOLATING forge

One forged pod, fired through the existing `Pod_monkey_step`, on the monkey budget.
Forge shape, and every clause of it is load-bearing:

- name **IS** vsts-prefixed (`"vstatefulset-<parent>-<ord>"` form) so the rely is
  violated (R1 conjunct a, R2 conjunct a);
- ordinal **OUTSIDE** the reconciler's live range `0..desired-1`. **This avoids the
  vacuous-green trap**: `create_request_admission_check` returns
  `Object_already_exists` on a name collision (`api_server.ml:243-245`), so a
  forged ordinal inside the live range makes the create a no-op and `Lf` reports a
  clean run that is worthless;
- carries the vsts controller owner ref (R1 conjunct b), which is what makes it
  land inside H1's `pod_premise` (`helper_invariants.ml:58`);
- carries a finalizer and/or no deletion timestamp per what actually reaches etcd:
  `handle_create_request` preserves `owner_references` and `finalizers` from the
  request and resets ONLY `deletion_timestamp` (`api_server.ml:265-273`), so
  forge-by-finalizer lands and forge-by-deletionTimestamp does NOT (the P18 MB3
  three-layer laundering result, reused rather than rediscovered).

> **MEASURED-CORRECTION (B3): this list omits a FIFTH load-bearing clause, the
> NAMESPACE.** All four clauses above are correct, but a forge built from
> `V_stateful_set_reconciler.make_pod` alone is **silently vacuous**: `make_pod`
> (`v_stateful_set_reconciler.ml:361-383`) leaves `metadata.namespace = None`
> because the reconciler supplies the namespace on the create REQUEST, not on
> the object. The monkey would then key the request at namespace `""`
> (`Pod_monkey.pod_namespace`'s `~default:""`, `pod_monkey.ml:38-39`), and H1's
> `pod_premise` namespace conjunct (`helper_invariants.ml:60`) could never fire:
> gate 0, leg measures nothing. `Fault_check.rely_violating_forge` therefore
> sets the namespace EXPLICITLY from the CR (`"ns"`), and `fault_check.mli`
> documents the clause.
>
> **MEASURED-CORRECTION (B3): Leg B's signature drops `~require_fault`** (Leg A
> keeps it, per §4.1). A forged object can only reach etcd through a
> `Pod_monkey_step`, which `budget_fault_taken` already counts, so
> `gate_states > 0` implies `monkeys >= 1` and the conjunct would be a no-op.
> Disclosed in the `.mli`.

**The non-vacuity floor for `Lf` is NOT "a forge step was taken".** It must count
states where the forged object ACTUALLY reached etcd AND H1's `pod_premise` fires
on it. Pin that count; for `Lf` a zero would mean the leg measured nothing.
MEASURED: `Lf`'s floor is **1560**, and H1's red count over that graph is also
exactly **1560** (§5.2).

> **MEASURED-CORRECTION (B3): "a zero gate means the leg measured nothing" is
> WRONG for the C1 control.** The rely-RESPECTING forge's key never satisfies
> `pod_premise` - that IS the point of the control - so C1's floor is
> **structurally** 0 no matter how well the run went. C1's evidence is
> `clean && decisive` on H1/H2 plus a SEPARATE "forged key present in etcd"
> count (measured **864** of 6368 states). Reading C1's zero as a failed
> experiment inverts the row's meaning. `fault_check.mli` carries the exception.
>
> **MEASURED-CORRECTION (B3): §7's C1 row needed a shipped constructor, so B3
> shipped one.** §1 drops the rely-respecting forger as a LEG and §7 keeps it as
> a control row, but without a constructor the control cannot run and `Lf`'s red
> is not attributable. `Fault_check.rely_respecting_forge` is byte-identical to
> `rely_violating_forge` except in the two rely-relevant fields (non-vsts-prefixed
> name, no vsts owner ref) and **keeps the finalizer**, which is what makes the
> control sharp: H1's green there is attributable to its premise never firing,
> not to a harmless payload.

**FRAMING, and the `.mli` must say it in these words.** `Lf`'s red is an
**assumption-necessity witness**, not a defect in Anvil and not "we broke H1". It
shows the rely condition is load-bearing for H1 rather than decorative. A reviewer
reading `Lf` red without this framing will read it as a soundness finding, which it
is not.

## 5. MEASURED (predictions committed before the build; verdicts and shipped pins below)

**Status: CLOSED. All eight predictions have a verdict, both phase-STOP clauses
were evaluated and neither fired, and every number below is a SHIPPED pin read
out of `test/p20_witness.ml` by a committed exe. Nothing in this section is TBD.**

### 5.0 The eight predictions, with their verdicts

| # | prediction (as committed, before the build) | verdict | where measured |
| --- | --- | --- | --- |
| 1 | Graph pins unchanged with `monkey_forge = []`: L0 76, Lc 464, Ld 744, Lm 1976, L0v 116 | CONFIRMED | B3 probe, B4 shipped |
| 2 | R1/R2/R3 `interesting` = 0 on L0, Lc, Ld (honest N5 vacuity, never dressed as a pass) | CONFIRMED | B4 shipped |
| 3 | Non-vacuity floor is Lm; R3's gate on Lm > 0 | CONFIRMED | B4 shipped |
| 4 | **THE HEADLINE** - R3 RED on Lm forge-free on a committed graph, BOTH arms red. Phase-STOP if R2's red on Lm = 0 | CONFIRMED, **STOP NOT TRIGGERED** | B4 shipped |
| 5 | P18's H1 stays GREEN on Lm while R3 is RED there | CONFIRMED | B4 shipped, measured directly |
| 6 | `R3 <=> R1 && R2` at every reachable state of every leg | CONFIRMED, 0 disagreements | B4 shipped, 6 graphs |
| 7 | `Lf` reddens H1, at a floor counting forged-object-in-etcd AND `pod_premise` fired | CONFIRMED | B4 shipped |
| 8 | The `Lf` graph pin is NEW **and is P20's only new graph constant**; record it, do not predict it | RECORDED: **7064**; the "only" clause **REFUTED** (see §5.5 item 4) | B4 shipped, refuted at B7 |

**Prediction 4's phase-STOP clause, evaluated explicitly**: the clause was "if
R2's red count on Lm is 0, §1's premise-refutation is itself refuted, the
headline dies, and the phase STOPS for a spec revision". R2's red count on Lm is
**208**, not 0. The clause did not fire; §1's premise-refutation stands. B5 later
sharpened WHICH conjunct carries it (see §5.3 and §1's MEASURED-CORRECTION).

### 5.1 Leg A - the five committed graphs, forge-free (`monkey_forge = []`)

Bound = P13's shape, `desired = 1`, depth 40. Every count below is over the
leg's own reachable set. Sources: `test/p20_witness.ml`, asserted by
`test/t_p20_rely.ml`.

| leg | budget {crash;drop;monkey} | states | outcome | `violated` | R3 gate | R1 int / red | R2 int / red | R3 int / red |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| L0  | {0;0;0} | 76   | CLEAN, DECISIVE | none | 0   | 0 / 0     | 0 / 0     | 0 / 0     |
| Lc  | {1;0;0} | 464  | CLEAN, DECISIVE | none | 0   | 0 / 0     | 0 / 0     | 0 / 0     |
| Ld  | {0;1;0} | 744  | CLEAN, DECISIVE | none | 0   | 0 / 0     | 0 / 0     | 0 / 0     |
| Lm  | {0;0;1} | 1976 | **REFUTED**     | **R1** (`vsts_rely_create_req`) | **832** | 208 / **208** | 208 / **208** | 832 / **416** |
| L0v | {0;0;0}, `vct:true` | 116 | (pin-safety replica only) | n/a | n/a | n/a | n/a | n/a |

Reading the table honestly, in the words the shipped assertions use:

- **L0 / Lc / Ld are VACUITY rows, not passes.** Gate 0 means no monkey-sourced
  message exists on those graphs at all, so all three members are vacuously true.
  `check_vacuity_row` says "VACUOUSLY" and "honest vacuity, not a pass" in its own
  failure text. This is the P14 N5 discipline, not a green.
- **L0v carries NO rely measurement.** Leg A has no `?vct` (§4.1), so L0v is
  reached through a `~vct:true` replica and exists only to show the `Bound.t`
  edit moved no `vct:true` pin.
- **Lm is the whole phase.** `red = interesting` on BOTH arms (208 = 208 and
  208 = 208): every state whose premise fires is red. That coincidence is
  asserted semantically before the exact pins and is recorded as a **measured
  property of this scenario, not a law**.
- R3's red (416) is exactly R1's red plus R2's red (208 + 208) here because no
  single state carries both a monkey `Create_request` and a monkey
  `Update_request`; that is an observation about this graph, not a claimed
  identity. The claimed identity is prediction 6, below.

### 5.2 Leg B - the forge graphs (`Lf`) and the containment control (`C1`)

Both at Lm's budget with `~pod_monkey:true ~req_drop:false`, one forged pod in
`Bound.monkey_forge`. Leg B takes no `~require_fault` (MEASURED-CORRECTION 5
from B3, at §4.3 below).

| leg | forge | states | outcome | `violated` | gate | H1 red | R1 int / red | R2 int / red | R3 int / red |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Lf | `rely_violating_forge ~desired` | **7064** | **REFUTED** | **H1** | **1560** | **1560** | 712 / 712 | 712 / 712 | 2848 / 1424 |
| C1 | `rely_respecting_forge ~desired` | **6368** | CLEAN, DECISIVE | none | **0** (structural) | **0** | 712 / 208 | 712 / 208 | 2848 / 416 |

- **`Lf`'s H1 red (1560) EQUALS its gate (1560)**, asserted as an equality rather
  than as two independent pins. That equality is the attribution the floor exists
  to license: H1 is red at precisely the states where the forged object reached
  etcd and `pod_premise` fired on its key.
- **C1's gate is 0 STRUCTURALLY and that is the control working, not failing**
  (B3 MEASURED-CORRECTION 2, at §4.3). C1's non-vacuity evidence is a separate
  count: the respecting forge's key is present in etcd at **864** of 6368 states.
  So C1's green is CONTAINMENT, not admission rejection.
- C1 still shows R1/R2/R3 red at 208/208/416 - the SAME counts as forge-free Lm.
  The rely-respecting forge adds no rely violation of its own, exactly as its
  name says; the residual red is the stored-pod echo Lm already measured.
- **P20 introduces TWO new graph constants, not one** (`lf_states = 7064` and
  `c1_states = 6368`, both literals in `test/p20_witness.ml`). Prediction 8's
  "only" clause is REFUTED; see §5.5 item 4. Every OTHER graph pin in this phase
  DERIVES from `p19_witness` / `p18_witness` along the
  P19 <- P18 <- P17 <- P16 <- P15/P13 chain, so the derivation discipline itself
  is intact - the miscount is in the prediction, not in the witness module.

### 5.3 Prediction 5 and prediction 6, measured directly

- **Prediction 5 (the corrected reading of P18's headline).** P18's `helper_family`
  was run on P20's OWN Lm replica rather than inferred from P18's committed
  numbers: **H1 red = 0 while R3 red = 416**, on the same 1976 states. The green
  is guarded against vacuity first - H1's premise fires at **1624** states there
  (`P18_witness.h1_interesting_lm`). So: the assumption upstream's H1 proof rests
  on is FALSE on Lm, and H1 holds anyway. **Emergent robustness, not
  rely-consistency.** §6's D5 lands this reading at every committed site that
  carried the old one.
- **Prediction 6 (`R3 <=> R1 && R2`).** **0 disagreements**, measured at every
  reachable state of **six** graphs: L0 (76), Lc (464), Ld (744), Lm (1976),
  Lf (7064), C1 (6368) - 76+464+744+1976+7064+6368 = **16,692** states in
  total. B3's probe covered four; Lc and Ld are B4's extension.
  The identity is the §2.3 disclosed redundancy, pinned as a measurement rather
  than left for a reviewer to notice.

> **REVIEW-FIX A (post-B7 review): what this pin buys, and two shipped sites
> that OVERSTATED it.** The 0 is **FORCED BY CONSTRUCTION** and holds for ANY
> definition of the two helpers. R3's two constrained arms
> (`rely_conditions.ml:240`, `:241`) call the IDENTICAL `rely_create_req` /
> `rely_update_req` that R1 (`:180`) and R2 (`:208`) call, over the identical
> `msgs s` (`:21-22`) reached through the identical `monkey_request_of`
> (`:39-44`). Per message the verdicts are `(R1,R2,R3) =
> (rely_create_req, true, rely_create_req)` on a Create,
> `(true, rely_update_req, rely_update_req)` on an Update, and all-`true` on the
> other seven arms and on `None`; since
> `for_all f l && for_all g l = for_all (fun x -> f x && g x) l`, the identity
> holds pointwise. So the pin is a **REFACTOR GUARD on R3's arm-DISPATCH
> shape** - it reddens only if R3 stops routing Create/Update to the helpers
> R1/R2 route them to - and it is **BLIND to every defect inside those
> helpers**: forcing `rely_create_req` to a constant `true` still yields 0
> disagreements on all six graphs. Checking it at **16,692** states across six
> graphs yields exactly the information ONE state yields.
>
> `rely_conditions.mli:73-75` and `t_p20_mutation.ml:30-33` already stated this
> honestly and were left alone. Two sites did not, and are corrected:
> `test/p20_witness.ml`'s prediction-6 block ("this is NOT a tautology ... the
> pin measures AGREEMENT BETWEEN TWO SEPARATE RENDERINGS") and
> `fault_check.mli`'s prediction-6 bullet ("this pins agreement between two
> separate renderings rather than a tautology"). Two further siblings found by
> `rg` carried the same error and are corrected the same way:
> `t_p20_mutation.ml`'s ML2' bullet ("the two independent renderings agree even
> when both are wrong together") and its copy at this file's B5
> MEASURED-CORRECTION 5. R3's rendering is UNCHANGED: the redundancy is
> deliberate and disclosed at §2.3; only the description of what the pin buys
> was wrong.

### 5.4 CONFIRMED BY MUTATION (B4 + B5), including two REFUTED predictions

Every mutation below was applied and reverted by exact `Edit`, with `git diff`
verified empty against the index. `git checkout --` was never used
([[feedback-confirm-tests-by-mutation]], [[feedback-mutation-driver-git-checkout-destroys-uncommitted]]).

| row | mutation | predicted | MEASURED | verdict |
| --- | --- | --- | --- | --- |
| ML2' | `rely_conditions.ml` `vsts_prefix` -> non-matching AND the collapse test's `V_stateful_set.kind` -> `Pod.kind` | Lm flips REFUTED -> CLEAN; gate unmoved; graph unmoved | Lm REFUTED -> CLEAN (`violated` `"vsts_rely_create_req"` -> `"<none>"`), gate stayed > 0, graph stayed exactly **1976** | CONFIRMED on all three halves |
| ML2 | `has_vsts_prefix` alone to constant `false` | "every leg reddens" | **not one leg moved**; Lm anchor passed IN FULL (gate 832, R1 208, R2 208, R3 416, H1 red 0, graph 1976); `t_p20_rely` fully green, 14/14 | **REFUTED** |
| ML1 | `v_stateful_set_reconciler.ml:191` minted prefix -> `"zzz-p20-mutant-"` | R1/R2 go GREEN on Lm while H1's premise starves | H1's premise starved 1624 -> **0** (H1 half CONFIRMED); **R1/R2 stayed RED** (R1/R2 half REFUTED); unpredicted: Lm graph 1976 -> **1928**, Leg B's Lf REFUTED -> **CLEAN** | **REFUTED on its R1/R2 half**, CONFIRMED on its H1 half |

**Why both refutations point the same way, and what they cost §1.** ML2 deleted
the FAMILY's prefix test and nothing moved. ML1 deleted the MINTED prefix from
the objects and R1/R2 still did not move. Both conjuncts of §1's argument do
fail on a stored vsts pod, but **neither is necessary, and the prefix one is not
load-bearing at all**: §1's premise-refutation - the entire headline - survives
the prefix test being deleted outright. **The headline rests on the OWNER-REF
conjunct alone** (`rely_guarantee.rs:68-69` / `:82-83` / `:85`). §1 carries this
as a MEASURED-CORRECTION; any prose about the premise-refutation must attribute
it there.

ML2's non-movement was established by a FORCED full-battery sweep
(`dune build @runtest --force`, all 69 exes of that stage re-run, exit 1): exactly
ONE failing exe (`t_p20_mutation`) at exactly FOUR cases (F-R1a, F-R1b, F-R2a and
the F-R3 update differential). Within the battery that sweep covered, those four
rows are the only prefix-conjunct witnesses. The claim is scoped to that 69-exe
run and B7 does not restate it at 70 (scope disclosed at §2.3).

### 5.5 MEASURED-CORRECTIONS at this site

1. **The build command in this spec was wrong (B1).** `dunecho build @runtest` is
   a cmdliner arity error (`dunecho` takes a single MODE argument) and `dune` is
   not on the default PATH. The working invocation is
   `eval $(opam env --switch=anvil-ocaml --set-switch) && dune build @runtest`
   (or `dunecho test` inside that switch). **`dune build @runtest` is the real
   gate for this phase and `dunecho fmt` is not available**: ocamlformat is NOT
   installed in the `anvil-ocaml` switch (B4 measured this), so no `.ml` file can
   be format-checked, and all NINE pre-existing `dune` files (`lib/cluster`,
   `lib/reconciler`, `lib/controllers`, `bin`, `lib/checker`, `lib/proof`,
   `lib/exec_shim`, `lib/assurance`, `test`) already report "needs promotion".
   That is COMMITTED tree state, not something P20 introduced. **Do not promote**
   - it would rewrite nine committed `dune` files for no measured gain.
2. **`report_decisive` is STILL a phantom (B1 confirmed, B4 re-confirmed).** This
   section said "report every leg with `report_decisive`"; no such symbol exists
   in the tree. Every leg is reported through the LOCAL decisive projection, the
   two-arm `Model_check.outcome` match at `test/t_p17_store.ml:71-79`.
3. **`Model_check.Refuted` carries NO `states` field (B4).** It is
   `Refuted of { lasso; steps }` (`model_check.mli:39`); only `No_counterexample`
   carries `{ decisive; depth; states }` (`:43`). The consequence for THIS
   section's tables: the two REFUTED legs (**Lm** and **Lf**) cannot report their
   graph size through the leg report at all, so their 1976 / 7064 pins are read
   off the LOCAL REPLICA - which is the strictly better read anyway, since the
   replica is the graph every per-member count in the tables is taken over. The
   `states_of` projection returns the shipped `-1` sentinel on `Refuted` (the
   `t_p17_store.ml:81-84` / `t_p19_provenance.ml:87-90` convention), and
   `check_replica_faithful` is therefore applied to the CLEAN legs
   (L0 / Lc / Ld / C1) only.
4. **REFUTED at B7: prediction 8's "P20's only new graph constant" is FALSE.**
   The sweep is `rg -n '^let [a-z0-9_]+ : int' test/p20_witness.ml` plus reading
   each binding's right-hand side: the graph-size bindings are `l0_states`,
   `lc_states`, `ld_states`, `lm_states` (all four DERIVED from
   `P19_witness`), `l0v_states` (derived from `P18_witness`), and then **two
   bare literals**, `lf_states = 7064` AND `c1_states = 6368`. C1's graph is
   just as new as Lf's. The prediction was written when §1 had dropped the
   rely-respecting forger as a LEG and §7 kept it as a control ROW; B3 then had
   to ship `rely_respecting_forge` to make the control runnable (§4.3's third
   correction), and a control forge changes `Bound.monkey_forge`, hence explores
   its own product graph. Recorded rather than softened: the honest statement is
   "**Lf and C1 are P20's two new graph constants; every other graph pin
   derives**". The mistake is a miscount in the prediction, not a break in the
   derivation discipline, and no shipped assertion depended on the "only".
5. **B3's probe numbers and B4's shipped pins do not disagree anywhere (B4).**
   B3's §5 numbers came from a throwaway probe (`scratch_p20/`, deleted after the
   run). B4 re-derived every one of them through committed test code and **every
   B3 number reproduced EXACTLY on the first shipped run**. The tables above are
   the SHIPPED pins; where a shipped pin and B3's probe could have differed the
   shipped pin would win, and there is no such difference to record. B4 measured
   strictly MORE than B3 in two places (prediction 6 on six graphs rather than
   four; the L0v pin-safety replica), and those additions are in the tables.

## 6. Committed-test edits (pre-authorized; each is a defect, not a preference)

P19 re-scoped P18's E6 guard under the same clause. All three edits below were
CONFIRMED against committed code before this spec was written.

- **D1 (MEDIUM) - the E2' guard is vacuous.** `t_p19_regression.ml:320-321` pins
  `internal_rely_guarantee_prefix = "kubernetes_cluster/proof/internal_rely_guarantee.rs"`.
  **That path does not exist upstream**; the only such file is
  `src/controllers/vstatefulset_controller/proof/internal_rely_guarantee.rs` (and
  `msg_provenance.mli:32` cites it WITHOUT a directory). So the assertion "no
  family member cites internal_rely_guarantee.rs" can never fire. Fix the literal;
  the guard must still pass (M1 cites `helper_invariants.rs`), and the corrected
  guard must be CONFIRMED BY MUTATION.

  > **D1 DISCHARGED (B6), and a MEASURED-CORRECTION on the gate.** "The guard
  > must still PASS" is correct but INSUFFICIENT as a stage gate: a guard that
  > passes is exactly what the vacuous version already did. The gate actually
  > used is a **two-sided differential** - the same mutation run against the OLD
  > guard and the CORRECTED one. MEASURED: `fd` over anvil-ref finds exactly ONE
  > `internal_rely_guarantee.rs` in the whole tree and it is
  > `src/controllers/vstatefulset_controller/proof/`'s;
  > `kubernetes_cluster/proof/` has none. With M1's source temporarily
  > re-pointed to the forbidden same-named duplicate, the OLD literal left **all
  > 8 cases GREEN** and the corrected literal takes **exactly the E2' assertion
  > RED**. The corrected guard passes unmutated.
- **D2 (MEDIUM) - the E4' ledger misclassifies a SHIPPED member as a leftover.**
  `t_p19_regression.ml:435-437` lists network.rs `:104`
  `pending_req_of_key_is_unique_with_unique_id` among `e4_leftovers`, reasoning it
  is "key-parameterized ... inside P14's register". But
  `reconcile_correspondence.ml:127-131` has SHIPPED that EXACT name and source
  (`kubernetes_cluster/proof/network.rs:104`) since P15. The blind spot P19's own
  F1 MEASURED-CORRECTION described as hypothetical - "a leftover shipped in a NEW
  module leaves the guard green" - **has already fired**. Reclassify `:104` as
  SHIPPED-by-P15-R1 with the cite, and widen the ledger guard to read every
  shipped suite instead of `p14_family` + `provenance_family` only.

  > **D2 DISCHARGED (B6), plus a MEASURED-CORRECTION this bullet missed.**
  > Widening the roster was not sufficient on its own: `render_member` TAGS every
  > ledger line and `:104` had no tag, so the reclassified line rendered as
  > `UNTAGGED` in the committed ledger text. It now carries
  > `"P15 R1, = the D2 reclassification"`. That was measured, not predicted - the
  > `UNTAGGED` string is visible in D2's own mutation failure output. THE
  > DIFFERENTIAL: with P15 R1's source temporarily mutated `network.rs:104` ->
  > `:999`, the ledger's failure output shows the two pre-existing crossed-out
  > lines **byte-identical** and only the D2-added third line moved, so the
  > pre-D2 ledger would have been GREEN and the corrected one goes RED. A forced
  > full-battery sweep under that mutation (`dune build @runtest --force`, the
  > 70-exe battery of that stage) found exactly ONE failing exe at exactly ONE
  > case, so within the battery that sweep covered the corrected guard is the
  > only witness for P15 R1's `network.rs:104` citation.
  >
  > **D2's blind spot is NARROWED, not CLOSED**, and `t_p19_regression.ml` says
  > so at the ledger: `e4_leftovers` is still the SAME binding on both sides of
  > the comparison, and a member shipped by a module absent from the roster is
  > still out of reach. Keeping the roster current is each phase's own edit.
- **D3 (HIGH, silent-vacuity risk) - the disjointness firewall's roster.**
  `t_p19_regression.ml:229-246` carries `shipped_suites` with 10 entries. P20's
  regression must ship **12**: the 10, plus `Msg_provenance.provenance_family`
  (P19's own family, which the P19 roster does not include), plus P20's
  `Rely_conditions.rely_family`. Copying the roster verbatim leaves P19 uncovered
  while `pair_leaks` still reports `[]` - a green that verifies nothing. The
  widened roster must be CONFIRMED BY MUTATION to actually cover P19.

  > **D3 DISCHARGED (B6), with a MEASURED-CORRECTION and an honest
  > qualification.** CORRECTION: this bullet implies the 12-entry roster is used
  > uniformly; it cannot be. `Rely_conditions.rely_family` is one of the twelve
  > and no family is disjoint from itself, so the sweep runs against **eleven**.
  > The self-entry is not dead weight - it replaces `t_p19_regression.ml:293`'s
  > ad-hoc `("SELF (control)", family)` as the sweep's red-capability control
  > (2 x 3 = 6 hits). Both cardinals are asserted (12 labels, 11 swept). THE
  > DIFFERENTIAL: with R3's source temporarily re-pointed to M1's, the ten-entry
  > roster left the sweep **GREEN** and the twelve-entry roster takes it **RED**,
  > naming the collision in both argument orders. **HONEST QUALIFICATION,
  > recorded at the guard so the differential is not over-read**: under the
  > ten-entry roster the mutation was invisible to THE SWEEP, not to the file -
  > three other assertions still reddened (the committed (name, source) pairs,
  > the roster-label pin, and the E4 reversal clause). What D3 buys is the case
  > those three cannot see: a member that keeps a VALID citation and collides
  > with a P19 member on the NAME.
  >
  > **`pair_guard.ml` spans `:29-49`, not `:29-48`** (the span carried in P18/P19
  > prose): the file is 49 lines and `pair_leaks`'s last line is `family_pairs`
  > at `:49`. Corrected at all three citing sites.

**D4 (carried residual, cheap, INCLUDE ONLY IF B1 VERIFIES).** P18 §2/§8.3 and
P19 §8.3 state that fixing the `inv_self` citation drift (`vsts_invariants.ml:217`
cites the VRS `helper_invariants/predicate.rs` layout) "moves k3 (name, source)
pins in four committed regression exes". Scout S10 refutes the blocker:
`test/pair_guard.ml` computes pairs DYNAMICALLY off the live suites, all four exes
only assert `[] = leaked`, and a literal sweep finds ZERO occurrences of
`inv_self`'s source string in any committed test. If B1 reproduces that sweep, the
fix is a one-line Edit plus a battery re-run and P20 takes it, retiring a
three-phase-old residual. **If B1 finds even one literal, D4 is DROPPED** and the
residual is re-stated with the corrected reason - do not force it.

**D4 TAKEN (B6).** B6 re-ran the sweep itself rather than taking B1's verdict on
trust: `rg 'helper_invariants/predicate' test/` returns ZERO hits, and the four
test files that mention `inv_self` at all carry only its NAME
(`t_p11_vsts_invariants.ml:169`, `t_p11_mutation.ml:225`, `t_p13_mutation.ml:38`,
`t_p19_regression.ml:380`). The fix moved no pin, verified by `git diff --stat`.
The corrected citation is **not** a vstatefulset path: `rg
'only_interferes_with_itself' src/controllers/vstatefulset_controller/` returns
ZERO hits upstream, so there is no vstatefulset original — the member is a
widening of VRS's `vrs_reconcile_request_only_interferes_with_itself` and now
cites it: `vreplicaset_controller/proof/helper_invariants/predicate.rs:237
(widened inv9; vstatefulset has no upstream analogue)`.

> **MEASURED-CORRECTION (B6, re-measured and partly corrected by B7): D1 and
> D2's own edits DRIFTED `t_p19_regression.ml`'s line numbers.** Any later stage
> citing the pre-B6 numbers will be wrong. B7 re-measured every entry against
> `git show HEAD:test/t_p19_regression.ml` (the committed side) and the live
> file, because B6 reported this table from memory of its own edits:
>
> | binding | committed (HEAD) | post-fix (staged) |
> | --- | --- | --- |
> | file length | 544 lines | **635** lines (B6 reported 693; **WRONG**) |
> | `shipped_suites` | `:229` | `:241` |
> | the SELF-control sweep | `:281` | `:293` |
> | `internal_rely_guarantee_prefix` | `:320` | `:351` |
> | `inv_self_name` | `:348` | **`:379`** (B6 reported `:349` -> `:380`, off by one on BOTH sides) |
> | `e4_leftover_lines` | `:425` | `:492` |
>
> The same two commands also CONFIRM D2 independently of B6's own guard:
> `e4_leftover_lines` is `[15; 19; 104; 171; 514]` at HEAD and
> `[15; 19; 171; 514]` staged. `104` is gone, which is exactly the
> reclassification D2 exists to make. §6's D1/D2/D3 bullets above still quote the
> PRE-EDIT numbers, deliberately, because that is where the defects were found;
> use this table to locate them post-fix.

**D5 (the §1 reading correction, landed in B7) - PROSE ONLY, no committed number
moved.** §1 promised to "state the corrected reading at every site that carries
the old one". B7 swept for the old reading with
`rg -n 'rely-UNCONSTRAINED|RELY-GAP|rely-gap|rely-consisten' lib/ test/ bin/` and
landed the correction at **seven** sites, which is two more than the five the
stage brief named:

| site | what carried the old reading |
| --- | --- |
| `test/t_p18_helper.ml` header item 2 | "whether the member survives the Lm leg is MEASURED here" |
| `test/t_p18_helper.ml` Lm banner comment | "THE RELY-GAP PROBE" |
| `test/t_p18_helper.ml` `test_lm`'s HEADLINE comment | "clean here means the ... monkey cannot violate H1" |
| `test/t_p18_helper.ml` Alcotest case label | "Lm: monkey-only (THE RELY-GAP PROBE)" |
| `lib/assurance/helper_invariants.mli` "Rely-gap headline" block | "whether the members survive the Lm leg is a measurement" |
| `test/p18_witness.ml` budget table | "Lm ... THE RELY-GAP PROBE" |
| `lib/checker/fault_check.mli` P18 MEASURED block | "the rely-UNCONSTRAINED but candidate-RESTRICTED monkey cannot violate H1" |

plus a cross-phase correction block at `lib/checker/BUILD-SPEC-P18.md`'s §5
prediction-4 entry (the same reading in P18's own spec).

The corrected reading, in the words landed at each site: **H1 held on Lm even
though the rely premise is FALSE there. That is emergent robustness, not
rely-compliance.** Each site cites P20's measured `r3_red_lm` 416 of an 832 gate,
`r1_red_lm` / `r2_red_lm` 208 of 208, and `h1_red_lm` 0, and attributes the
mechanism to the OWNER-REF conjunct (per §1's necessity qualifier), never to the
name prefix.

> **MEASURED-CORRECTION (B7), line-number drift in the stage brief.** The brief
> located P18's `.mli` site at `helper_invariants.mli:122`; that line is inside
> H2's premise-narrowing bullet and carries no rely reading. The site that
> actually carries it is the "Rely-gap headline" block at
> `helper_invariants.mli:143-151` (pre-edit numbering). The four
> `t_p18_helper.ml` line numbers in the brief (`:17-18`, `:382`, `:387`, `:493`)
> were all correct pre-edit.
>
> **VERIFIED PROSE-ONLY**: `git diff --stat` over the D5 edit set shows changes
> only inside comments and doc blocks; no `let ... : int` binding, no
> `Alcotest.(check ...)` expected value and no witness literal moved. The
> `test/t_p18_helper.ml` Alcotest case LABEL did change (it is display text, not
> a pin) and is called out here so the diff is not read as a silent pin move.

> **REVIEW-FIX E (post-B7 review): D5's corrected reading OVERCLAIMED for H2,
> which is VACUOUS on Lm.** The block D5 landed at
> `helper_invariants.mli` said both members "survive an environment OUTSIDE the
> region upstream's proof assumes". H2 survived nothing there. H2's premise
> never fires on any `vct:false` graph - no such graph ever mints a PVC, which
> **the same file says 25 lines earlier** in its "Honest vacuity off the vct
> leg" bullet - and `test/p18_witness.ml:153` pins `h2_interesting_lm = 0`.
> H2's Lm green is honest VACUITY, not robustness, and the corrected reading was
> contradicting that file's own vacuity note.
>
> The sentence is narrowed to **H1 alone**, which is what
> `BUILD-SPEC-P18.md:341` ("So H1 holding on Lm is **emergent robustness**") and
> `fault_check.mli:1185-1186` ("H1's Lm green is therefore EMERGENT ROBUSTNESS")
> already said - the two sites D5 landed correctly. One clause is added
> recording H2's vacuity with the `p18_witness.ml:153` cite, and H1's own
> non-vacuity guard is cited alongside it
> (`P18_witness.h1_interesting_lm` = 1624, `p18_witness.ml:151`), so the
> corrected reading no longer rests on an unguarded green either.
> All three cited line numbers were checked against the files before editing.
> Nothing else in the block moved: H1's and H2's upstream lemmas BOTH take the
> rely in their `requires`, so the "not a soundness finding" clause still
> applies to both members and is unchanged.

## 7. Mutation matrix (Edit-applied, Edit-reverted, each revert verified by `git diff --stat` + battery re-green; never `git checkout --`; stage BEFORE any file-mutating sweep)

Rows follow the `t_p19_mutation.ml` banner format (mechanism + predicted + measured
per row). Minimum roster; B4 adds rows as evidence demands.

- **F-R1a/b/c** forges reddening R1's three conjuncts INDEPENDENTLY (prefix via
  `name`; prefix via `generate_name` with `name = None`; owner-ref collapse). Each
  at 4-check parity + isolation + controls. The `generate_name` row matters: it is
  the ONLY witness for upstream's `:63-66` else-branch.
- **F-R2a/b/c** likewise for R2's three conjuncts, including the STORED-object
  conjunct (b), whose only red witness is a state where etcd already holds a
  vsts-owned object at the request's key.
- **F-R3** a monkey-sourced message on a PERMITTED arm (Delete / Update_status)
  that must leave R3 GREEN - the `:26` permissiveness is content, so it needs a
  positive control, not just an absence.
- **F-PVC** the structurally-inert PVC arm of R1/R2 (P19's M4-External-arm
  precedent): its ONLY red witness is a forge, and the `.mli` must say so.

  > **MEASURED-CORRECTION (B5).** `Persistent_volume_claim` has NO view module in
  > this tree: `lib/k8s_objects/views/` holds exactly `pod.mli`, `config_map.mli`
  > and `stateful_set.mli`, so this row cannot marshal a PVC through a view. It is
  > built by KIND-RETAGGING a marshalled pod through `Dynamic_object.make`
  > (metadata / spec / status carried across untouched), which is strictly better
  > for the row anyway: the PVC red and the nine other-kind accepts then differ
  > from each other in `Dynamic_object.kind` ALONE.

- **C1 (the containment control)** a rely-RESPECTING forge (non-vsts-prefixed,
  no vsts owner ref) must leave H1 GREEN on `Lf`. This is what makes prediction 7's
  red DECISIVE - it attributes the red to rely-violation rather than to forging as
  such - and it is the measured stand-in for the arm-A leg dropped in section 1.

  > **DISCHARGED.** B3 shipped the constructor this row needs
  > (`Fault_check.rely_respecting_forge`; see §4.3's correction). MEASURED: C1 is
  > **6368** states, CLEAN and DECISIVE, H1 red **0**, with the respecting forge's
  > key present in etcd at **864** states. Its gate is structurally 0 and that is
  > the control WORKING (§4.3). B5 added a second, graph-free level: the same
  > containment measured at the STATE level, exhibiting the `get_ordinal`
  > starvation mechanism behind the structural zero.

- **ML1** mutate the reconciler's pod-name prefix (`v_stateful_set_reconciler.ml:191`)
  and predict R1/R2 go GREEN on Lm while H1's premise starves - the register-
  distinctness measurement (P19 ML3's role), proving the family is reading the
  prefix and not something correlated with it.

  > **MEASURED-CORRECTION (B5): this row OVER-PREDICTS and is REFUTED on its
  > R1/R2 half** (its H1 half is CONFIRMED). H1's premise DID starve, 1624 -> **0**,
  > because `get_ordinal` (`:207`) both prefix-checks and round-trips through the
  > mutated `pod_name`. But **R1 and R2 stayed RED**: `make_pod` still installs
  > the vsts controller owner ref (`make_owner_references`, `:218-219`, untouched
  > by the `:191` mutation), so R1 conjunct (b) and R2 conjuncts (b)/(c) still
  > fail on every stored vsts-owned pod the monkey re-sends. The mechanical
  > reason is one §1 itself supplies, which is why the refutation was avoidable
  > in principle and is recorded prominently rather than softened.
  >
  > **Unpredicted second-order effects, recorded because this row predicted
  > neither** (the P19 ML3 precedent): the mutant MOVES THE GRAPH, Lm 1976 ->
  > **1928** (the reconciler classifies listed pods through `get_ordinal` and now
  > recognises none of its own), and it EVAPORATES THE LEG-B WITNESS - `Lf` goes
  > REFUTED -> CLEAN, because `rely_violating_forge` builds its pod through the
  > same `make_pod`, so H1's premise never fires on it. Register distinctness
  > stated positively: H1 and Leg B depend on the MINTING literal; the rely
  > family's headline does not. No graph identity is claimed under a mutant -
  > 1928 is the MUTANT's count.

- **ML2** mutate `has_vsts_prefix` in the FAMILY to a constant `false` and confirm
  every leg reddens - a liveness check on the classifier itself.

  > **MEASURED-CORRECTION (B5): this row is REFUTED AS WORDED, and it is spelled
  > backwards.** Every use of that classifier sits under a NEGATION (R1 conjunct
  > (a) is `not (name_or_generate_has_vsts_prefix md)`, R2 conjunct (a) is
  > `not (has_vsts_prefix r.name)`), so a constant `false` makes the family
  > strictly MORE permissive and cannot redden anything. MEASURED: **not one leg
  > moved** (full numbers at §5.4). The corrected liveness row is the TWO-token
  > **ML2'** - `vsts_prefix` -> a non-matching string AND the collapse test's
  > `V_stateful_set.kind` -> `Pod.kind` - which flips Lm REFUTED -> CLEAN while
  > the gate stays > 0 and the graph pin stays exactly 1976. EITHER TOKEN ALONE
  > IS INSUFFICIENT, which is the finding: neutering only the prefix leaves R1
  > conjunct (b) and R2 conjuncts (b)/(c) failing on stored vsts pods.
  >
  > **MEASURED-CORRECTION (B5), a spelling trap worth carrying forward.** The
  > constant-`false` mutant cannot be spelled
  > `let has_vsts_prefix (_name : string) : bool = false` - it orphans
  > `vsts_prefix`, and `lib/assurance/dune:6`'s `-w +a-4-9-40-41-42-44-45-70`
  > makes warning 32 an ERROR, so the build FAILS and dune leaves the previously
  > built exe in place, printing a stale green. The shipped spelling is
  > `false && String.starts_with ~prefix:vsts_prefix name`. **Methodology rule
  > for every future single-token mutation in this tree: verify the build
  > SUCCEEDED before reading any test output.**

- **MN1** the D1/D2/D3 guards, each confirmed by mutation (section 6).

  > **DISCHARGED in B6** (not B4/B5: the three guards live in
  > `t_p19_regression.ml` / `t_p20_regression.ml`, which B5 does not touch). Each
  > is a TWO-SIDED differential - the same mutation run against the OLD guard and
  > the CORRECTED one - because "fix it and check it still passes" is exactly
  > what the vacuous version already did. Results at §6's D1/D2/D3 blocks.
  > **No §7 row remains unrun.**

> **MEASURED-CORRECTION (B5): the P14-P19 ISOLATION FORM is impossible for this
> family.** Those exes assert `violated_names = [target]`. §2.3's disclosed
> `R3 <=> R1 && R2` means any state that reddens an arm reddens R3 too, so every
> forge row here asserts `violated_names = [target; R3]` - the target arm, R3,
> and nothing else. That is the P19 isolation PLUS an on-the-spot re-measurement
> of prediction 6's identity at every forged state, not a weakened one.

Every row states its mechanism BEFORE running, and records the measured result
even when it refutes the prediction (the P19 MN1' discipline - the honest
refutation is worth more than the confirmation). **Two rows of this matrix were
REFUTED (ML1 partly, ML2 entirely) and both refutations are stated above at the
row itself, not only in the tail.**

## 8. Limits + residuals (disclosed, not hidden) + banked P21 candidates

1. **E1's vacuity is scenario-conditional**: single-controller spines make the
   other-controller rely trivially true. A P9-style two-controller spine would
   make E1 live; that is a real P21.
2. **The PVC arm never fires on any live graph** (the monkey emits pod-keyed
   requests only). Forge-only witness, disclosed in the `.mli`.
3. **`Lf` is one forged pod, not a forge SPACE.** The leg demonstrates necessity;
   it does not explore the rely-violation lattice. A systematic forge enumeration
   is P21-class and would need its own pins.
4. **Arm A (rely-respecting forger) is prose + one control row**, not a leg -
   justified by upstream containment (`helper_lemmas.rs:92-102` / `:80-90`), so the
   port has NOT measured a broad rely-safe adversary.
5. **`vct` matrix beyond L0v still deferred** (P16 §8.6 / P17 k6). P20's cut has
   the strongest justification yet (the rely predicate never reads PVCs, so vct
   legs would be outcome-identical while roughly doubling runtime in a 70-exe
   battery). NOTE S10's finding that P16 §8.6's blanket ban on cross-phase
   derivation of `vct:true` counts is itself stale - P18 already derived L0v from
   P16 (`p18_witness.ml:155-160`).
6. **Banked P21 candidates**: S5 `local_pods_and_pvcs_are_bound_to_vsts`
   (`internal_rely_guarantee.rs:606`) restricted to its C1 needed-pod conjunct -
   the only non-vacuous, unshipped content, and its firing is UNMEASURED, so it
   needs a probe first; the two-controller spine that de-vacuizes E1; the
   systematic forge space of residual 3.
7. **The 12-entry roster is a thing a P21 must EXTEND, never copy** (added at
   B6). `t_p20_regression.ml`'s `committed_roster` is a literal 12-label list
   asserted against `shipped_suites`, so a verbatim copy forward reddens
   immediately - that assertion IS the D3 fix's own guard. P21 must add its
   family AND move the P20 label out of the self-exclusion filter into the
   swept set.
8. **D2's blind spot is narrowed, not closed** (added at B6). `e4_leftovers` is
   still the SAME binding on both sides of the comparison, and a member shipped
   by a module absent from the roster remains out of reach. Keeping the roster
   current is each phase's own edit; no guard can do it for them.
9. **The rely family's own red-capability rests on the OWNER-REF conjunct
   alone** (added at B5, restated at B7). Measured twice by mutation (§5.4). A
   P21 that wants a prefix-conjunct regression must keep
   `t_p20_mutation.ml`'s F-R1a / F-R1b / F-R2a / F-R3-update rows alive: within
   B5's forced 69-exe sweep those four were the only cases that reddened under
   the prefix mutant (scope disclosed at §2.3).

## Files

- `lib/assurance/rely_conditions.{ml,mli}` - the family (new).
- `lib/cluster/bound.{ml,mli}` - `monkey_forge : Pod.t list` field, default `[]`
  (edit; the ONLY `lib/cluster/` edit besides the one-line `cluster.ml:748`).
- `lib/cluster/cluster.ml` - the `:748` candidate append (edit, one line).
- `lib/checker/fault_check.{ml,mli}` - Leg A + Leg B + MEASURED doc block
  (APPEND AT EOF: `.ml:826`, `.mli:1477`; every shipped leg byte-identical).
- `lib/checker/BUILD-SPEC-P20.md` - this file.
- `test/p20_witness.ml` - pins; graph constants DERIVED from p19/p18 witnesses,
  new literals only for the TWO forge graphs (Lf 7064 and C1 6368), the gates
  and the member counts.

  > **MEASURED-CORRECTION (B6): `p20_witness.ml`'s banner claim "every P20 exe
  > reads every count from here and re-types none of them" is FALSE, and
  > deliberately so.** `t_p20_regression.ml:105-109` re-types the FIVE INHERITED
  > graph literals (76 / 464 / 744 / 1976 / 116) as its prior-phase firewall.
  > That is the sanctioned P14/P19 duplication: "fix the red by editing the
  > witness" cannot redden in a guard that reads the very binding it guards. The
  > banner now records the exception and states the surviving property, which is
  > the one that matters: **no P20-MEASURED count is re-typed anywhere.**
- `test/t_p20_rely.ml` - the two legs + semantics checks + the `R3 <=> R1 && R2`
  identity + the E1-E4 exclusion pins.
- `test/t_p20_mutation.ml` - forge battery + F/C/ML/MN rows, banner header in the
  `t_p19_mutation.ml` format.
- `test/t_p20_regression.ml` - classification firewall (`pair_guard`, both
  directions, `shipped_suites` = 12) + D1/D2/D3 fixes + E-ledger pins.
- `test/t_p19_regression.ml` - D1 + D2 fixes ONLY (section 6).
- `lib/assurance/vsts_invariants.ml` - D4, the one-line `inv_self` source fix
  (added to this manifest at B6; the spec body left D4's file unnamed).
- `lib/assurance/helper_invariants.mli` - D4's disambiguation block, rewritten
  from "deliberately NOT fixed this phase" to the measured fix (B6); plus D5's
  corrected reading of P18's headline (B7, prose only).
- `test/dune` - 3 new exes; battery 67 -> 70.
- D5's remaining sites (B7, PROSE ONLY, no committed number moved):
  `test/t_p18_helper.ml` (four sites), `test/p18_witness.ml` (budget table),
  `lib/checker/fault_check.mli` (the P18 MEASURED block),
  `lib/checker/BUILD-SPEC-P18.md` (§5 prediction 4, cross-phase note).

> **MEASURED-CORRECTION (B4, restated by B5 and B6): "battery 67 -> 70" is a
> PHASE total and was repeatedly misread as a per-stage one.** Per stage the
> battery went 67 (B3) -> **68** (B4 ships `t_p20_rely`) -> **69** (B5 ships
> `t_p20_mutation`) -> **70** (B6 ships `t_p20_regression`). B7 adds no exe and
> re-measures **70**. `test/p20_witness.ml` is a shared module and is
> deliberately NOT in `test/dune`'s `(names ...)`, per the `p19_witness.ml` /
> `p18_witness.ml` precedent, so the `(names ...)` cardinal equals the exe count.

> **MEASURED-CORRECTION (B4): `Fault_check.forge_key` is NOT exported.**
> `fault_check.mli` exposes `forge_finalizer` (`:1590`), `forge_ordinal`
> (`:1601`), `rely_violating_forge` (`:1613`), `rely_respecting_forge` (`:1653`)
> and `check_rely_forge_under_faults` (`:1674`); `forge_key`
> (`fault_check.ml:980`) stays internal. B3's C1 correction requires a "forged
> key present in etcd" count, which needs that key, so `t_p20_rely.ml` rebuilds
> it locally with the SAME `~default:""` completions (`Pod.kind` /
> `md.namespace` / `md.name`) and discloses why a `Res.t` read would be wrong
> there. Not a defect; a note for anyone who expects the count to reuse the
> library function.

## MEASURED-CORRECTIONS (spec claims that are factually wrong about the tree)

Recorded per the stage contract: where the spec and the tree disagree, the
CORRECTED fact is what gets built. Each entry names the stage that measured it.

### Re-measured in B2 (the family stage)

1. **§2.1 span.** `controller_owner_ref` spans `v_stateful_set.ml:173-184`
   (record literal `:177-183`), NOT `:173-181`. Fields: `:178`
   `block_owner_deletion = Some true`, `:179` `controller = Some true`, `:180`
   `kind`, `:181` `name`, `:182` `uid`. The three-fixed/two-free collapse
   RENDERING is correct; only the cited span was wrong.
2. **§2.1 type.** The port's `controller_owner_ref` returns
   `Owner_reference.t option` (`Option.bind` on `metadata.name`, `Option.map` on
   `metadata.uid`), not the bare record the spec's wording implies. The collapse
   is unaffected: the rendered right-hand side never CALLS the function, it
   tests the three pinned fields directly.
3. **§2.1 omission.** `Object_meta.owner_references` is
   `Owner_reference.t list option` (`object_meta.mli:16`), not a plain list, so
   the collapse test needs `Option.fold ~none:false` BEFORE the `List.exists`;
   `None` = no owner references = the negated conjunct PASSES. Disclosed in the
   `.mli`.
4. **§1 novelty sweep is REFUTED as worded** (B1 found it, B2 re-ran both
   sweeps). `rg 'source = "[^"]*trusted' lib/` returns **TWO** pre-existing
   hits - `invariants.ml:1040`
   (`vreplicaset_controller/trusted/liveness_theorem.rs:21`, inside
   `Invariants.liveness_goal`, `:1037-1043`) and `vsts_invariants.ml:297`
   (`vstatefulset_controller/trusted (ordinal-stable ESR goal)`, inside
   `Vsts_invariants.liveness_goal`, `:293-300`) - so "zero shipped
   `Invariants.invariant` carries a `source` under `trusted/`" is FALSE. **This
   item said ONE because B1/B2/B7 all ran the sweep with a trailing `/`, which
   hid the second hit; see REVIEW-FIX B at §1 for the corrected sweep's actual
   output and the per-hit reachability check.** The two claims that survive
   measurement, and the only two that may be shipped in prose:
   (a) `rg 'source = "[^"]*rely_guarantee' lib/ test/` returns ZERO hits
   (exit 1) before this phase; (b) BOTH pre-existing `trusted`-sourced
   invariant values are LIVENESS GOALS and members of no shipped safety family
   (the VRS family lists close at `invariants.ml:1023-1035`; the VSTS list
   closes at `vsts_invariants.ml:286` and `always` at `:288-291`, both before
   `liveness_goal` at `:293`), so R1-R3 are the first `trusted`-sourced members
   of a shipped SAFETY family. The `rg rely_guarantee lib/ test/` claim ("only
   BUILD-SPEC-P3.md:15") is also false - 18 hits, all the DIFFERENT upstream
   file `internal_rely_guarantee.rs` or prose.
5. **§2.3 `has_vsts_prefix` accessor.** `Common.show_kind` renders
   `CustomResource(vstatefulset)` (`common.ml:63`), so it is NOT a usable
   accessor for the pin; the bare string is `V_stateful_set.kind_name`
   (`v_stateful_set.mli:28`). The reconciler does NOT derive its prefix from the
   kind: `v_stateful_set_reconciler.ml:191` (`pod_name`) and `:207`
   (`get_ordinal`) each hard-code `"vstatefulset-"` independently, so THREE
   literals must agree. B2 ships the spec's literal in the family (rather than
   `kind_name ^ "-"`) precisely so a `kind_name` drift cannot silently re-point
   the family away from the names the reconciler actually mints; the three-way
   agreement is a B4 TEST pin, as §2.3 requires.

### CLARIFICATION, not a spec error (B2)

- **§2.3 R2's kind dispatch** is on `req.obj.kind` (`rely_guarantee.rs:78`), the
  OBJECT's kind, not `req.key().kind`; the spec says only "for Pod /
  Persistent_volume_claim kinds". The port reads `Dynamic_object.kind r.obj`
  directly. The two coincide - `update_request_key` is
  `{obj.kind; namespace; name}` (`api_method.mli:121-122`) - but the object read
  is the literal upstream one.

### Carried from B1, NOT re-measured in B2

- **§3 E4 pin literal is 12**, not 13: `trusted/rely_guarantee.rs` has exactly
  12 `pub open spec fn`. The SHIPPED/LEDGERED partition is total at 12
  (3 shipped + E1 2 + E3 3 + E2 4).
- **§5 / build command**: `dunecho build @runtest` is a cmdliner arity error;
  the working invocation is
  `eval $(opam env --switch=anvil-ocaml --set-switch) && dune build @runtest`
  (or `dunecho test` inside that switch).
- **§5 `report_decisive` is still a PHANTOM** - use the local decisive
  projection (`t_p17_store.ml:71-79`).
- **§4.1/§4.2 append points and blast radius**: `fault_check.ml` is 825 lines
  (append at `:826`), `fault_check.mli` 1476 (append at `:1477`); adding
  `Bound.monkey_forge` touches 13 FULL record literals.

### Measured in B3 (the seam and the two legs)

**All eight §5 predictions CONFIRMED, including the two that were phase-STOP
conditions.** Numbers came from a throwaway probe (`scratch_p20/`, deleted after
the run) that called the shipped leg functions directly and recomputed the
per-member counts with a local replica over the same graphs
(`Fault_check.faulted_successors` / `faulted_equal` / `faulted_hash`,
`Model_check.explore` at `depth = 40`). B4 owns the shipped pins and must
REPRODUCE these through `test/p20_witness.ml`; nothing below is asserted by a
committed test yet. Bound = P13's shape, `desired = 1`.

1. **PIN SAFETY, MEASURED not argued (the stage gate).** With
   `Bound.monkey_forge` present and defaulted to `[]`: L0 **76**, Lc **464**,
   Ld **744**, Lm **1976**, L0v **116** — all five unchanged. Cross-checked two
   ways: the probe re-explored each graph directly, AND the five committed
   witness exes (`t_p13_faults`, `t_p15_reconcile_correspondence`,
   `t_p16_req_resp`, `t_p18_helper`, `t_p19_provenance`) each exit 0 with the
   field in place.
2. **Vacuity rows honest.** Leg A on L0 / Lc / Ld: CLEAN, DECISIVE,
   `gate_states = Some 0` on all three. Per-member on L0: R1/R2/R3 all
   `interesting = 0`, all red = 0.
3. **Non-vacuity floor.** R3's gate on Lm = **832 > 0**.
4. **THE HEADLINE HOLDS, forge-free, on a COMMITTED graph.** Leg A on Lm is
   REFUTED, `violated` naming R1. Per-member over the same 1976 states:
   **R1 red 208** of 208 `interesting`, **R2 red 208** of 208, **R3 red 416** of
   832. The spec made "R2 red count = 0 on Lm" a phase-STOP; R2's red count is
   208, so §1's premise-refutation stands.
5. **The corrected reading of P18's headline, measured.** P18's H1 red count on
   that same Lm graph is **0** while R3 is red at 416 states. Assumption violated
   WITHOUT consequence — an emergent-robustness result, not a rely-consistency
   one.
6. **`R3 <=> R1 && R2`**: **0 disagreements** on every graph measured — L0 (76),
   Lm (1976), Lf (7064), C1 (6368).
7. **Lf reddens H1.** Leg B on `monkey_forge = [rely_violating_forge ~desired:1]`
   is REFUTED naming H1, `gate_states = Some 1560` (states where the forged pod
   reached etcd AND H1's `pod_premise` fires on its key). The H1 red count over
   that graph is ALSO exactly **1560** — H1 is red at precisely the gated states,
   which is the attribution the floor exists to license.
8. **The Lf graph pin is NEW and MEASURED: 7064** (vs Lm's 1976 forge-free).
   The **C1 containment control** (§7 row C1) measures **6368** states, CLEAN and
   DECISIVE, H1 red count **0**, with the respecting forge's key present in etcd
   at **864** states — so C1's green is containment, not admission rejection.
   That is what makes prediction 7's red decisive.

Extra rows B4 will want: on Lf the rely members read R1 712 / R2 712 / R3 1424
red at 712 / 712 / 2848 `interesting`; on C1 they read R1 208 / R2 208 / R3 416
red at the same 712 / 712 / 2848 `interesting` — the rely-RESPECTING forge adds
no rely violation of its own, exactly as its name says.

### MEASURED-CORRECTIONS from B3

1. **§4.3 omits a FIFTH load-bearing forge clause: the NAMESPACE.** The spec
   lists four clauses (vsts-prefixed name / ordinal outside the live range /
   vsts controller owner ref / finalizer-not-deletionTimestamp). All four are
   correct, but a forge built from `V_stateful_set_reconciler.make_pod` alone is
   **silently vacuous**: `make_pod` (`v_stateful_set_reconciler.ml:361-383`)
   leaves `metadata.namespace = None` because the reconciler supplies the
   namespace on the create REQUEST, not on the object. The monkey would then key
   the request at namespace `""` (`Pod_monkey.pod_namespace`'s `~default:""`,
   `pod_monkey.ml:38-39`), and H1's `pod_premise` namespace conjunct
   (`helper_invariants.ml:60`) could never fire — gate 0, leg measures nothing.
   `Fault_check.rely_violating_forge` sets the namespace explicitly from the CR
   (`"ns"`), and the `.mli` documents the clause.
2. **§4.3's "a zero gate means the leg measured nothing" is wrong for the C1
   control.** The rely-RESPECTING forge's key never satisfies `pod_premise` —
   that is the point of the control — so its floor is **structurally** 0 no
   matter how well the run went. C1's evidence is `clean && decisive` on H1/H2
   plus a separate "forged key in etcd" count (measured 864 of 6368), not
   `gate_states`. The `.mli` carries the exception; reading C1's zero as a failed
   experiment inverts the row's meaning.
3. **§7 row C1 needs a shipped constructor, so B3 shipped one.** `§1` drops the
   rely-respecting forger as a LEG and `§7` keeps it as a control row, but
   without the control `Lf`'s red is not attributable. `Fault_check.rely_respecting_forge`
   is byte-identical to `rely_violating_forge` except in the two rely-relevant
   fields (non-vsts-prefixed name, no vsts owner ref) and **keeps the
   finalizer**, which is what makes the control sharp: H1's green there is
   attributable to its premise never firing, not to a harmless payload.
4. **§4.2's blast radius confirmed exactly at 13** full `Bound.t` record
   literals, the sites B1 enumerated: `bound.ml:11`, `vsts_liveness.ml:34`,
   `vrs_liveness.ml:103`, `p12_witness.ml:13`, `t_p11_vsts_invariants.ml:68`,
   `t_p11_vsts_esr.ml:45`, `t_p11_mutation.ml:57`, `t_p5_cluster_check.ml:77`
   and `:91`, `t_p5_mutation.ml:153` and `:164`, `t_p8_settle.ml:35`,
   `t_p8_mutation.ml:40`. No other site needed an edit.
5. **Leg B's signature drops `~require_fault`** (Leg A keeps it, per §4.1). A
   forged object can only reach etcd through a `Pod_monkey_step`, which
   `budget_fault_taken` already counts, so `gate_states > 0` implies
   `monkeys >= 1` and the conjunct would be a no-op. Disclosed in the `.mli`.
6. **`Bound.t` field count is now 8, not 7**, and `bound.mli`'s closing
   "which fields P2 actually consumes" block was updated: `monkey_forge` is a
   FOURTH field the single-step `Cluster.enabled_successors` enumeration reads,
   and it is the only one that WIDENS rather than narrows.

### Measured in B4 (the shipped pins) - B3 REPRODUCED, 0 disagreements

B3's numbers came from a throwaway probe. B4 re-derived every one of them
through **shipped, committed test code** (`test/p20_witness.ml` +
`test/t_p20_rely.ml`, 14 test cases, 22.4 s standalone / 25.2 s inside the
battery, far under the ~150 s harness alarm). **Every B3 number reproduced
EXACTLY on the first shipped run. There is no disagreement to report between
B3's probe and B4's shipped measurement** - which is itself the finding worth
stating, because the stage contract made a disagreement the most important
thing B4 could return.

All eight §5 predictions CONFIRMED as shipped pins, including both phase-STOP
conditions:

1. **PIN SAFETY (the stage gate), re-MEASURED with `Bound.monkey_forge`
   present and defaulted to `[]`**: L0 **76**, Lc **464**, Ld **744**,
   Lm **1976**, L0v **116**. None moved. L0v has no P20 leg (Leg A has no
   `?vct`), so it is checked through a `~vct:true` replica - a pin-safety
   check on the `Bound.t` edit, not a rely measurement.
2. **Vacuity rows honest.** L0 / Lc / Ld: CLEAN, DECISIVE, gate **0**, and
   every per-member `interesting` AND every per-member red count **0** on all
   three. Shipped as `check_vacuity_row`, whose assertion labels say
   "VACUOUSLY" and "honest vacuity, not a pass" in the failure text itself.
3. **Non-vacuity floor**: R3's gate on Lm = **832 > 0**.
4. **THE HEADLINE, forge-free on a committed graph.** Leg A on Lm REFUTED,
   `violated` naming R1. Over the same 1976 states: **R1 red 208 of 208**
   `interesting`, **R2 red 208 of 208**, **R3 red 416 of 832**. §5.4's
   phase-STOP clause is NOT triggered: R2's red count is 208, not 0, so §1's
   premise-refutation stands. Both arms are red at *every* state where their
   premise fires - asserted semantically (`red = interesting`) before the
   exact pins, and recorded as a measured coincidence of this scenario, never
   as a law.
5. **The corrected reading of P18's headline, measured DIRECTLY** (P18's H1
   run on P20's own Lm replica, not inferred from P18's committed numbers):
   H1 red **0** while R3 is red at 416. The test first asserts H1's premise
   really fires there (1624, read from `P18_witness`), so the green cannot be
   vacuous. Emergent robustness, not rely-consistency.
6. **`R3 <=> R1 && R2`: 0 disagreements** - and B4 measured it on **SIX**
   graphs, not B3's four: L0 (76), **Lc (464)**, **Ld (744)**, Lm (1976),
   Lf (7064), C1 (6368). The two added graphs are the extension B4 contributes
   over B3.
7. **`Lf` reddens H1.** Leg B REFUTED naming H1, `gate_states = Some` **1560**,
   and H1's red count over the graph is **1560** - equal to the gate, asserted
   as an equality (`H1 red = gate`) rather than as two independent pins, which
   is the attribution the floor exists to license.
8. **`Lf` graph pin NEW: 7064.** C1 control: **6368** states, CLEAN, DECISIVE,
   H1 red **0**, respecting-forge key present in etcd at **864** states.
   Rely-family context rows reproduced exactly: Lf R1 712 / R2 712 / R3 1424
   red at 712 / 712 / 2848 `interesting`; C1 R1 208 / R2 208 / R3 416 red at
   the same 712 / 712 / 2848.

**CONFIRMED BY MUTATION** ([[feedback-confirm-tests-by-mutation]]; the two
mutations were applied and reverted by exact `Edit`, `git diff` verified empty
against the index, never `git checkout --`). Two single-token mutations in
`rely_conditions.ml` together neuter the family on its Pod arm - `vsts_prefix`
`"vstatefulset-"` -> `"zzz-p20-mutant-"`, and the collapse test's
`Common.equal_kind r.kind V_stateful_set.kind` -> `... Pod.kind`. **MEASURED:
Lm flips REFUTED -> CLEAN**, so the headline verdict tracks the family and is
not a constant. Two things deliberately did NOT move under the mutant, both
predicted and both observed: the Lm **gate stayed > 0** (the premise mirrors
read only `src` and message content, never the reddening mechanism) and the
Lm **graph pin stayed 1976** (the product graph is family-blind, which is the
derivation the whole witness chain rests on).

### MEASURED-CORRECTIONS from B4

1. **`Model_check.Refuted` carries NO `states` field.** It is
   `Refuted of { lasso : 'a lasso; steps : int }` (`model_check.mli:39`); only
   `No_counterexample` carries `{ decisive; depth; states }` (`:43`). §5's
   "report every leg with `report_decisive`" already fell to B1's phantom
   finding, but the consequence for the *state counts* was unrecorded: the two
   REFUTED legs of this phase (**Lm** and **Lf**) cannot report their graph
   size through the leg report at all. B4 reads those two graph pins off the
   LOCAL REPLICA instead - which is the strictly better read anyway, since the
   replica is the graph every per-member count is taken over - and the
   `states_of` projection returns the shipped `-1` sentinel on `Refuted` (the
   `t_p17_store.ml:81-84` / `t_p19_provenance.ml:87-90` convention). The
   `check_replica_faithful` bundle is therefore applied to the CLEAN legs
   (L0 / Lc / Ld / C1) only, and Lm / Lf say so at the assertion.
2. **`Fault_check.forge_key` is NOT exported.** `fault_check.mli` exposes
   `forge_finalizer` (`:1590`), `forge_ordinal` (`:1601`),
   `rely_violating_forge` (`:1613`), `rely_respecting_forge` (`:1653`) and
   `check_rely_forge_under_faults` (`:1674`) - `forge_key` (`fault_check.ml:980`)
   stays internal. B3's MEASURED-CORRECTION 2 requires B4 to count "forged key
   present in etcd" for the C1 row, which needs that key, so `t_p20_rely.ml`
   rebuilds it locally with the SAME `~default:""` completions
   (`Pod.kind` / `md.namespace` / `md.name`) and discloses why a `Res.t` read
   would be wrong there. Not a defect - a note for anyone who expects the
   count to reuse the library function.
3. **§Files' "battery 67 -> 70" is a PHASE total, not a B4 total.** B4 ships
   exactly ONE new exe (`t_p20_rely`), so the battery is **68** at the end of
   this stage. `t_p20_mutation` (§7's forge/F/C/ML/MN matrix) and
   `t_p20_regression` (§6's D1/D2/D3 fixes + the 12-suite firewall) are still
   unwritten and carry the remaining 2. `p20_witness.ml` is a shared module and
   is deliberately NOT in `test/dune`'s `(names ...)`, per the
   `p19_witness.ml` / `p18_witness.ml` precedent.
4. **§3's E4 pin needed no further correction, and B4 re-counted it
   independently**: `rg 'pub open spec fn' src/controllers/vstatefulset_controller/trusted/rely_guarantee.rs`
   returns **12** lines (`:17 :32 :39 :57 :76 :92 :105 :120 :133 :152 :164
   :176`), confirming B1's correction of the spec body's "13". The shipped
   partition is total AND disjoint at 12 (3 shipped + E1 2 + E3 3 + E2 4), and
   the SHIPPED side is read off `Rely_conditions.rely_sources` by parsing the
   trailing line number - never re-typed - so a family edit that re-points a
   source reddens the ledger.

### Measured in B5 (the mutation matrix) - TWO §7 PREDICTIONS REFUTED

B5 ships ONE new exe, `test/t_p20_mutation.ml` (12 cases, 16.8 s standalone /
17.1 s in the battery), taking the battery to **69**. Six permanent automated
rows break R1's three conjuncts and R2's three conjuncts INDEPENDENTLY off a
base whose in-flight pool is empty; two more cover the `:26` permissiveness
and the PVC arm; the C1 containment control is measured at two levels.
Three MANUAL rows were applied by `Edit`, SEEN, and reverted by `Edit` with
`git diff` verified empty against the index (never `git checkout --`).

**The most valuable result of the stage is a pair of refutations**, and they
converge on the same fact from opposite directions:

1. **§7's ML2 prediction is REFUTED.** §7 says "mutate `has_vsts_prefix` in
   the FAMILY to a constant `false` and confirm every leg reddens". Every use
   of that classifier sits under a NEGATION (R1 conjunct (a) is
   `not (name_or_generate_has_vsts_prefix md)`, R2 conjunct (a) is
   `not (has_vsts_prefix r.name)`), so forcing it to `false` makes the family
   strictly MORE permissive and cannot redden anything. **MEASURED: not one
   leg moved.** The Lm anchor passed IN FULL - `violated` still R1, still
   REFUTED, gate still 832, R1 red 208, R2 red 208, R3 red 416, H1 red 0, H1
   interesting 1624, graph still 1976 - and `t_p20_rely` ran FULLY GREEN, all
   14 cases. A FORCED full-battery sweep (`dune build @runtest --force`, all
   **69** exes re-run, exit 1) found **exactly one** failing exe,
   `t_p20_mutation`, at **exactly four** cases: F-R1a, F-R1b, F-R2a and the
   F-R3 update differential.
2. **§7's ML1 prediction is REFUTED on its R1/R2 half** (its H1 half is
   CONFIRMED). §7 says "mutate the reconciler's pod-name prefix
   (`v_stateful_set_reconciler.ml:191`) and predict R1/R2 go GREEN on Lm while
   H1's premise starves". H1's premise DID starve - it fires at 0 states,
   down from the committed 1624 - because `get_ordinal` (`:207`) both
   prefix-checks and round-trips through the mutated `pod_name`. But **R1 and
   R2 stayed RED**: `make_pod` still installs the vsts controller owner ref
   (`make_owner_references`, `:218-219`, untouched by the mutation), so R1
   conjunct (b) and R2 conjuncts (b)/(c) still fail on every stored vsts-owned
   pod the monkey re-sends. The anchor's semantic verdicts (violated = R1,
   REFUTED, monkey taken, gate > 0, R1/R2/R3 each red somewhere) all still
   passed under the mutant.

3. **CONSEQUENCE, and it corrects §1's own wording.** §1 says a monkey op on
   a stored vsts pod fails "`vsts_rely_create_req`'s prefix (`:61-66`) and
   owner-ref (`:68-69`) conjuncts both". Both DO fail - but **neither is
   NECESSARY**, and the prefix one is not load-bearing at all: §1's
   premise-refutation, the whole headline, survives the prefix test being
   deleted outright. The headline rests on the OWNER-REF conjunct alone. This
   was measured from both sides (ML2 removed the prefix and nothing moved;
   ML1 removed the minted prefix from the objects and nothing moved either).

4. **B4's "behavioural prefix pin" does not discriminate the prefix.**
   `t_p20_rely.ml:499-505` pins "a monkey create of a RECONCILER-MINTED vsts
   pod reddens R1" as the behavioural stand-in for the family's unexported
   literal. Its payload is `rely_violating_forge`'s object, which ALSO carries
   the vsts owner ref, so the red survives the prefix conjunct being deleted -
   which is why `t_p20_rely` is fully green under ML2. Every assertion in that
   case is true; the case simply does not establish what its comment says it
   does. B5's F-R1a / F-R1b / F-R2a rows are, by the forced 69-exe sweep
   above, the tree's ONLY prefix-conjunct witnesses.

5. **ML2' (the reachable variant) CONFIRMED on all three halves**, and it is
   the liveness row §7's ML2 was reaching for. `vsts_prefix` ->
   `"zzz-p20-mutant-"` AND the collapse test's
   `Common.equal_kind r.kind V_stateful_set.kind` -> `... Pod.kind` together
   flip Lm **REFUTED -> CLEAN** (`violated` goes `"vsts_rely_create_req"` ->
   `"<none>"`), while the Lm **gate stays > 0** and the Lm **graph pin stays
   exactly 1976** - both predicted not to move, both observed not to move.
   `t_p20_rely`'s entire `pin_safety` case and its L0/Lc/Ld vacuity rows also
   passed under the mutant, as did prediction 6's identity (0 disagreements -
   **REVIEW-FIX A**: that outcome is FORCED, not informative. The renderings
   are NOT independent; R3's constrained arms call the same helpers R1 and R2
   call, so the identity cannot move under a mutant of those helpers' bodies.
   Full argument at §5.3's REVIEW-FIX A.).

6. **ML1's unpredicted second-order effects**, recorded because §7 predicted
   neither (the P19 ML3 precedent): the mutant MOVES THE GRAPH, Lm 1976 ->
   **1928** (the reconciler classifies listed pods through `get_ordinal` and
   now recognises none of its own), and it EVAPORATES THE LEG-B WITNESS - the
   rely-VIOLATING forge leg goes **REFUTED -> CLEAN**, because
   `rely_violating_forge` builds its pod through the same `make_pod`, so H1's
   premise never fires on it. Register distinctness stated positively: H1 and
   Leg B depend on the MINTING literal; the rely family's headline does not.
   No graph identity is claimed under a mutant - 1928 is the MUTANT's count.

### MEASURED-CORRECTIONS from B5

1. **§7's ML2 row is spelled wrong in direction** (see above): a constant
   `false` cannot redden a family whose every use of the classifier is
   negated. The corrected liveness row is the TWO-token ML2', recorded in
   `t_p20_mutation.ml`'s banner with its measured flip.
2. **§7's ML1 row over-predicts.** "R1/R2 go GREEN on Lm" is false for a
   mechanical reason the spec itself supplies elsewhere (§1 lists the
   owner-ref conjunct as an independent failure). Only the H1-starvation half
   holds.
3. **A constant-`false` mutant of `has_vsts_prefix` cannot be spelled
   `let has_vsts_prefix (_name : string) : bool = false`** - it orphans
   `vsts_prefix` and `lib/assurance/dune:6`'s `-w +a-4-9-40-41-42-44-45-70`
   makes warning 32 an ERROR, so the build fails and a stale exe runs instead.
   The shipped spelling is `false && String.starts_with ~prefix:vsts_prefix
   name`. A methodology note for every future single-token mutation in this
   tree: **verify the build succeeded before reading the test output**, since
   dune leaves the previously-built exe in place.
4. **`Persistent_volume_claim` has NO view module in this tree.**
   `lib/k8s_objects/views/` holds exactly `pod.mli`, `config_map.mli` and
   `stateful_set.mli`, so §7's F-PVC row cannot marshal a PVC through a view.
   It is built by KIND-RETAGGING a marshalled pod through
   `Dynamic_object.make` (metadata / spec / status carried across untouched),
   which is strictly better for the row anyway: the PVC red and the nine
   other-kind accepts then differ from each other in `Dynamic_object.kind`
   ALONE.
5. **The P14-P19 isolation form is IMPOSSIBLE for this family.** Those exes
   assert `violated_names = [target]`. §2.3's disclosed `R3 <=> R1 && R2`
   means any state that reddens an arm reddens R3 too, so B5 asserts
   `violated_names = [target; R3]` - the target arm, R3, and nothing else.
   That is the P19 isolation PLUS an on-the-spot re-measurement of prediction
   6's identity at every forged state, not a weakened one.
6. **§Files' "3 new exes / battery 70" remains a PHASE total.** B5 ships ONE
   exe, `t_p20_mutation`, so the battery is **69** at the end of this stage;
   `t_p20_regression` (§6's D1/D2/D3 + the 12-entry `shipped_suites`
   firewall) carries the last one. §7's **MN1 row therefore belongs to B6**,
   not to B5: its three guards live in `t_p19_regression.ml` /
   `t_p20_regression.ml`, neither of which B5 touches. The omission is
   recorded in `t_p20_mutation.ml`'s banner so it is visible rather than
   silent.

### Measured in B6 (the debt discharge + the firewall) - §7's MN1 row, all four defects

B6 ships ONE new exe, `test/t_p20_regression.ml` (7 cases, 0.002 s - it does no
model checking, only list work over live invariant records), taking the battery
to **70** at exit 0. It also applies D1 + D2 at their own site
(`test/t_p19_regression.ml`) and D4 at `lib/assurance/vsts_invariants.ml:217`.

**§7's MN1 row is discharged: D1, D2 and D3 are each CONFIRMED BY MUTATION, and
each mutation is a two-sided differential** - the SAME mutation run against the
OLD guard and the CORRECTED one, so the evidence is "opposite verdicts", not
"the new guard can fail". Every mutation was applied and reverted by exact
`Edit`, with `git diff` verified empty against the index; `git checkout --` was
never used.

1. **D1 CONFIRMED, and the old guard measured VACUOUS.**
   `t_p19_regression.ml:320-321`'s prefix was
   `"kubernetes_cluster/proof/internal_rely_guarantee.rs"`; measured with `fd`
   over anvil-ref, the Anvil tree holds exactly ONE `internal_rely_guarantee.rs`
   and it is `src/controllers/vstatefulset_controller/proof/`'s -
   `kubernetes_cluster/proof/` has none. THE DIFFERENTIAL: with M1's source
   temporarily re-pointed to
   `"vstatefulset_controller/proof/internal_rely_guarantee.rs:528"` (exactly the
   same-named duplicate E2' exists to forbid) and `m1_source` moved with it so
   the two neighbouring asserts stay green and this one is isolated - the OLD
   literal left **all 8 cases GREEN**, the corrected literal takes **exactly the
   E2' assertion RED** (`Expected: [] / Received:
   ["vstatefulset_controller/proof/internal_rely_guarantee.rs:528"]`). The
   corrected guard still PASSES unmutated, as §6 required.
2. **D2 CONFIRMED, both halves.** `:104` is reclassified as SHIPPED-by-P15-R1
   (`reconcile_correspondence.ml:127-131`), `e4_leftover_lines` drops from five
   entries to four, and the CROSSED-OUT side of the ledger is now built from
   **every suite in `shipped_suites`** rather than from `p14_family` +
   `provenance_family`. THE DIFFERENTIAL: with P15's R1 source temporarily
   mutated `network.rs:104 -> :999`, the ledger's failure output shows the two
   PRE-EXISTING crossed-out lines **byte-identical** and only the D2-added third
   line moved (`:104 ... (P15 R1) -> :999 ... (UNTAGGED)`) - so the pre-D2
   ledger would have been GREEN under this mutation, and the corrected one goes
   RED. A FORCED full-battery sweep under that mutation (`dune build @runtest
   --force`) found **exactly one** failing exe at **exactly one** case, so the
   corrected guard is the tree's ONLY witness for P15 R1's `network.rs:104`
   citation.
3. **D3 CONFIRMED - and it is the sharpest of the three, because the defect is
   a green that verifies nothing.** `t_p20_regression.ml`'s roster is TWELVE
   suites: P19's ten, plus `Msg_provenance.provenance_family`, plus
   `Rely_conditions.rely_family` (excluded from the sweep's right-hand side by
   LABEL - no family is disjoint from itself; the self-entry doubles as the
   red-capability control, 2 x 3 = 6 hits). THE DIFFERENTIAL: R3's source
   temporarily re-pointed to M1's
   `"vstatefulset_controller/proof/helper_invariants.rs:1213"` - with the P19
   entry REMOVED (P19's ten-entry roster copied forward verbatim, which is
   precisely the D3 defect) **the sweep stayed GREEN**; with the twelve-entry
   roster it goes **RED**, naming the collision in both argument orders.
   **HONEST QUALIFICATION, recorded at the guard so the differential is not
   over-read**: under the ten-entry roster the mutation was invisible to THE
   SWEEP, not to the file - three other assertions still reddened (the committed
   (name, source) pairs, the roster-label pin, and the E4 reversal clause). What
   D3 buys is the case those three cannot see: a P20/P21 member that keeps a
   valid citation and collides with a P19 member on the NAME.
4. **D4 TAKEN, and B6 re-ran the sweep itself rather than trusting B1's
   verdict.** `rg 'helper_invariants/predicate' test/` returns ZERO hits; the
   four test files that mention `inv_self` carry only its NAME
   (`t_p11_vsts_invariants.ml:169`, `t_p11_mutation.ml:225`,
   `t_p13_mutation.ml:38`, `t_p19_regression.ml:380`); `pair_guard.ml:29-49`
   computes pairs dynamically off live suites. `git diff --stat` confirms the
   fix moved no pin - the only `.ml` line changed is the source string itself.
   A permanent regression guard for it ships in `t_p20_regression.ml`
   (`test_d4_inv_self_citation`), which also asserts the drifted path is cited
   by NO suite in the roster.
5. **The E4 REVERSAL CLAUSE is new in B6 and is D2's lesson applied to P20's own
   ledger.** `t_p20_rely.ml:825-856` reads `Rely_conditions.rely_sources` and
   nothing else - the exact scope D2 proved insufficient. `t_p20_regression.ml`
   re-derives the `trusted/rely_guarantee.rs` line set over all twelve suites
   and asserts (a) the only lines shipped anywhere are R1/R2/R3's `[17; 57; 76]`
   and (b) no E1/E2/E3 line is shipped by anybody. MEASURED: both hold.
6. **Battery 70 exes, exit 0, ~60 s wall** (`dune build @runtest`, 177.7 s user
   at 310% cpu). `test/dune`'s `(names ...)` now has 70 entries with no
   duplicates (`rg -o '\bt_[a-z0-9_]+' -N test/dune | sort -u | wc -l` = 70 =
   the unsorted count).

### MEASURED-CORRECTIONS from B6

1. **§3's E4 SCOPE PIN cardinality is corrected IN PLACE at the §3 site**, as
   the stage contract required: the file has **12** `pub open spec fn`, not 13.
   B6 re-counted it a third time (after B1 and B4) and the partition is total
   AND disjoint at 12 with no orphan, so this is a CARDINALITY error in the
   spec body, not a partition defect.
2. **§6's D3 wording implies the 12-entry roster is a superset used the same
   way; it cannot be.** `Rely_conditions.rely_family` is one of the twelve, and
   a family is never disjoint from itself, so the sweep runs against **eleven**
   of the twelve. The self-entry is not dead weight - it replaces
   `t_p19_regression.ml:293`'s ad-hoc `("SELF (control)", family)` and is the
   sweep's red-capability control. Both cardinals are asserted (12 labels, 11
   swept).
3. **§6's D2 "widen the ledger guard to read every shipped suite" needed a
   `member_tags` entry too**, not just a roster widening: `render_member` tags
   every line and `:104` had no tag, so the reclassified line rendered as
   `UNTAGGED` in the committed ledger text. It now carries
   `"P15 R1, = the D2 reclassification"`. Measured, not predicted - the
   `UNTAGGED` string is visible in the D2 mutation's own failure output.
4. **§6's D1 "the guard must still PASS (M1 cites `helper_invariants.rs`)" is
   correct but insufficient as a stage gate.** A guard that passes is exactly
   what the vacuous version also did; that is the defect. The gate B6 actually
   used is the two-sided differential (old literal GREEN / new literal RED under
   one mutation), and the same shape was used for D2 and D3. Recorded because
   "fix it and check it still passes" would have re-shipped the defect class.
5. **D4's corrected citation is NOT a vstatefulset path.** The natural repair
   ("vstatefulset has the flat `proof/helper_invariants.rs`, so point there")
   is wrong: `rg 'only_interferes_with_itself'
   src/controllers/vstatefulset_controller/` returns ZERO hits, so upstream has
   no vstatefulset analogue at all. The honest citation is VRS's real
   `helper_invariants/predicate.rs:237` with the widening disclosed in the
   string. The trailing parenthetical also keeps it distinct from
   `Invariants`' own VRS inv9 (`invariants.ml:680`), which cites the same
   file:line bare.
6. **§7's MN1 row belonged to B6 and is now discharged**, closing B5's
   correction 8. No §7 row remains unrun.

### Measured in B7 (finalise) - the spec is now TBD-free, and one more prediction fell

B7 ships **no new exe and no new feature**. It folds every stage's corrections
into the spec **at the site each one corrects** (they had been accumulating only
in this tail), fills §5 with the shipped tables, lands §1's promised reading
correction at every site that carried the old reading, and re-runs the sweeps
this phase's claims rest on rather than inheriting them.

1. **§5 is CLOSED.** All eight predictions carry a verdict, both phase-STOP
   clauses are evaluated explicitly in the text (neither fired), and the leg /
   member tables are shipped pins read out of `test/p20_witness.ml`.
   `rg 'B[1-7] must|B[1-7] fills|TBD|TODO|FIXME'` over the spec returns exactly
   three lines, all SELF-REFERENTIAL: §5's "Nothing in this section is TBD", this
   section's own heading, and this sentence. No unfilled instruction to a stage
   ("B1 must ...", "B3 fills ...") remains anywhere.
2. **B3 vs B4 reconciled, with the rule stated.** Where B3's throwaway probe and
   B4's shipped pin could differ, the SHIPPED pin wins. MEASURED: there is no
   such difference; every B3 number reproduced exactly. B4 measured strictly
   more in two places (prediction 6 on six graphs rather than four, and the L0v
   pin-safety replica) and both additions are in §5's tables.
   `fault_check.mli`'s MEASURED block, which still described its numbers as
   "B3's measurement to be REPRODUCED, not as an asserted constant", now records
   that B4 reproduced them and ships them as pins.
3. **A NINTH REFUTATION, found by B7's own overclaim sweep: prediction 8's
   "P20's ONLY new graph constant" is FALSE.** `c1_states = 6368` is a second
   bare literal graph constant in `test/p20_witness.ml`, alongside
   `lf_states = 7064`; the containment control varies `Bound.monkey_forge` too
   and therefore explores its own product graph. The witness module was already
   right (`p20_witness.ml:38` and `:227` say "the ONLY new graph constants",
   plural); the spec's prediction and `fault_check.mli:1735` carried the
   singular, and both are corrected. Recorded prominently because a refutation
   found while finalising is exactly the kind that gets quietly softened.
4. **The §6 D5 reading correction landed at SEVEN sites** (the stage brief named
   five; B7's `rg` sweep found two more, `test/p18_witness.ml` and
   `lib/checker/fault_check.mli`), plus a cross-phase note in
   `BUILD-SPEC-P18.md`. PROSE ONLY: the removed lines in that edit set are
   comments, doc blocks and one Alcotest display label; no `let ... : int`
   binding and no expected value moved.
5. **OVERCLAIM SWEEP over B7's own new prose.** Sweep:
   `git diff -- lib/ test/ | rg '^\+'` then
   `rg -i '\bfirst\b|\bonly\b|\bnever\b|\balways\b|\bstrictly\b|\bunique\b|\bmost\b|\bbest\b|\bevery\b'`.
   MEASURED over B7's 795 added lines: **99 lines carry one of the nine tokens**,
   of which **53 carry an exclusivity token** (`first` / `only` / `strictly` /
   `unique` / `most` / `best`); the remaining 46 are ordinary uses of
   `never` / `always` / `every` ("`git checkout --` was never used", "every row
   states its mechanism"). Reading all 53: **11 are load-bearing exclusivity or
   novelty CLAIMS about the tree. 5 were NARROWED, 1 was REFUTED outright (at 3
   sites), and 5 were kept because the sweep or the mechanism that establishes
   them is cited at the claim itself.**

   The 5 NARROWED: (a) `helper_invariants.mli`'s "upstream simply never claimed
   anything about this region" -> scoped to H1's and H2's own `requires`
   (`helper_invariants.rs:82-86` / `:1084-1086`), because "what Anvil proves
   elsewhere" was never swept; (b) §2.3's and (c) §5.4's "the tree's ONLY
   prefix-conjunct witnesses" -> both scoped to the 69-exe battery B5's forced
   sweep actually covered, with the reason B7 carries them forward at 70 without
   re-running the mutant stated rather than assumed; (d) §6 D2's "the tree's only
   witness for `network.rs:104`" -> same scoping; (e) §8 residual 9's restatement
   of (b)/(c) -> same scoping.

   The 1 REFUTED: prediction 8's "P20's ONLY new graph constant" (item 3),
   corrected at §5.0, §5.2 and `fault_check.mli`.

   The 5 KEPT, each with its evidence at the claim: §1's two narrowed novelty
   claims (both `rg` commands quoted, re-run at B7, second one widened to
   `test/`); `bound.mli`'s "`monkey_forge` is the only one of the four consumed
   fields that WIDENS" (bounded over a 4-element list a reader can check in
   `bound.mli`); "B4 measured strictly MORE than B3 in two places" (both named);
   and "the local replica is the strictly better read" (justified inline: the
   replica IS the graph every per-member count is taken over).
6. **§1's novelty sweep re-run a THIRD time (B1, B2, B7) and WIDENED - and the
   trailing `/` in it was a DEFECT, corrected post-B7 (REVIEW-FIX B at §1).**
   `rg 'source = "[^"]*rely_guarantee' lib/ test/` returns exactly the three new
   members and nothing else; `rg 'source = "[^"]*trusted' lib/` (no trailing
   slash) returns `invariants.ml:1040` **and `vsts_invariants.ml:297`** plus the
   three new members; the same sweep over `test/` exits 1. So the pre-P20 count
   of `trusted`-sourced invariant values is **TWO** over the whole tree, both
   pre-existing at `15aedfd`, both LIVENESS GOALS
   (`Invariants.liveness_goal` and `Vsts_invariants.liveness_goal`), and
   neither reachable through any shipped safety family - checked per hit at
   REVIEW-FIX B. B7's earlier "ONE" was an artefact of the trailing `/`, which
   hid the second hit's `trusted `-plus-SPACE source string. The narrowed claim
   shipped in `rely_conditions.mli` is what survives, and it survives the
   corrected sweep unchanged; §1's original blanket wording is marked FALSE at
   §1 itself.
7. **Battery: 70 exes, 0 failures, verified per-exe rather than off a summary
   line.** `dune build @runtest` exits 0 with empty output. A forced re-run
   (`dune build @runtest --force`) exits 0 and yields **70** `Testing \`...'`
   banners, **70 distinct** exe names, **70** `Test Successful` lines and
   **zero** `FAIL` / `[ERROR]` lines.
8. **Residue scan CLEAN.** `git diff -- lib/cluster lib/controllers` (working vs
   index) is EMPTY. The staged diff touches `lib/cluster/` in exactly three
   files - `bound.ml` (the field), `bound.mli` (the field's doc + the consumed-
   fields block) and `cluster.ml` (the one-line `@ b.monkey_forge` append plus
   its comment) - and touches `lib/controllers/` in **zero** files. No mutation
   from any stage's experiments survives anywhere in either directory.

### MEASURED-CORRECTIONS from B7

1. **Prediction 8's "only new graph constant" clause is REFUTED** (item 3
   above). The honest statement is "Lf and C1 are P20's two new graph
   constants". Corrected at §5.0, §5.2, §5.5 item 4 and `fault_check.mli:1735`.
2. **The stage brief's `helper_invariants.mli:122` is the wrong line.** That
   line sits inside H2's premise-narrowing bullet and carries no rely reading.
   The site that carries it is the "Rely-gap headline" block at
   `helper_invariants.mli:143-151` (pre-edit numbering). The brief's four
   `t_p18_helper.ml` line numbers were all correct pre-edit.
3. **The old reading lived at SEVEN sites, not five.** `test/p18_witness.ml:59`
   and `lib/checker/fault_check.mli:1176` also carried it, and neither was named
   in the brief. Found by
   `rg -n 'rely-UNCONSTRAINED|RELY-GAP|rely-gap|rely-consisten' lib/ test/ bin/`.
4. **`fault_check.mli`'s P20 MEASURED block was stale in its provenance, not in
   its numbers.** It told the reader to treat its numbers as "B3's measurement
   to be REPRODUCED, not as an asserted constant"; B4 had already reproduced and
   shipped them. Corrected in place; no number moved.
5. **B6's `t_p19_regression.ml` line-drift table is wrong in two entries.**
   B7 re-measured it against `git show HEAD:test/t_p19_regression.ml` rather than
   taking B6's report: the file is **635** lines post-fix, not the 693 B6
   reported, and `inv_self_name` moved `:348` -> `:379`, not `:349` -> `:380`
   (off by one on both sides). The other four entries reproduce exactly. The
   corrected table is at §6. The same two commands re-confirm D2 from outside its
   own guard: `e4_leftover_lines` is `[15; 19; 104; 171; 514]` at HEAD and
   `[15; 19; 171; 514]` staged, so `104` really was reclassified.
6. **`t_p20_rely` runs slower than B4 recorded on a loaded machine**: 42.6 s in
   B7's forced run versus B4's 22.4 s standalone / 25.2 s in the battery, and
   `t_p20_mutation` 35.0 s versus B5's 16.8 s. Same pass/fail, same pins; the
   difference is machine load, not a measurement change. Recorded so a later
   stage does not read the timing as a regression, and because the phase's
   runtime budget note ("far under the ~150 s harness alarm") should be read
   with that variance in mind.

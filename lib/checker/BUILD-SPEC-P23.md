# BUILD-SPEC-P23: the controller-LOCAL binding register (E4/E5, the E-ledger re-partition)

Phase 23 of the port. Follows P22 (scale-down scenario, sealed at `abceb7e`).
Branch: `p23-local-binding` off `abceb7e`.

## 0. Provenance of this spec, stated honestly

Two workflow waves and one main-loop verification pass produced everything
below. Named, with their counts, so a reviewer can see which claim rests on
which agent:

- **Phase-selection wave** - `tasks/wvk9j8b0z.output`, `agentCount = 10`
  (NINE scouts plus one judge), `scoutsExpected = 9`, `scoutsReturned = 9`,
  **0 errors**. The nine scout keys: `A-e35-feasibility`,
  `A-e35-nonvacuity`, `B-structural-leg`, `C-family-export`,
  `D-upstream-novelty`, `E-pins-and-battery`, `F-review-debt`,
  `G-conventions`, `H-blowup-risk`. Its judged rationale is the source for
  section 1's non-vacuity proxy evidence and for the P24/P25 bank in section
  7. Re-read with `jq -r ".result.judged.rationale" <file>`.
- **Design-settlement wave** - `tasks/w0ghsx8lq.output`, `agentCount = 4`
  (THREE settle reports plus one reconcile critic), `expected = 3`,
  `returned = 3`, **0 errors**. Report keys and verdicts: `upstream-partition`
  (SETTLED, two members, E3 excluded), `port-plumbing` (fully settled, one
  correction to BUILD-SPEC-P22.md:325), `c-blast-radius` (C is low blast
  radius but its benefit is undemonstrated). The critic's `partition`,
  `memberSpecs`, `plumbingPlan`, `cDecision` and `residualRisks` fields are
  the AUTHORITATIVE source for sections 2, 3, 6 and 7 and are transcribed
  here, not re-litigated.
- **Main-loop verification (this author, 2026-07-30).** Every load-bearing
  cite below was re-read in the tree or in anvil-ref before it was written.
  Upstream `internal_rely_guarantee.rs:598-664` was read in full. The only
  drift found against the ruling is cosmetic and is noted where it occurs
  (the ruling's `internal_guarantee.ml:75-98` span for `cr_key_of` /
  `cr_name` / `cr_namespace` is real but the three bindings sit at `:75`,
  `:78` and `:93`; the ruling's `state_predicates.rs` is at
  `proof/liveness/state_predicates.rs`, not `proof/state_predicates.rs`).

**The design ruling OVERTURNED the selection wave's phase sketch on the
member partition, and this must be said once, plainly, so it is not
reintroduced during doc passes.** The sketch attributed E4's needed and
condemned conjuncts (`:617-622`, `:623-628`) to `:606`. That is WRONG. The
three upstream functions are **NESTED, not overlapping**: E3 (`:606-611`) is a
one-conjunct lift that calls E5 at `:609`; E5 (`:640-664`) calls E4 at `:642`;
E4 (`:613-638`) is a pure `(cr_key, local_state) -> bool`. E3's whole body is
six lines and contains no needed / condemned / pvcs text of its own; the next
`pub open spec fn` starts at `:613`. Any member carrying those conjuncts MUST
cite `:613`. Verified by this author against the anvil-ref file, not taken on
report.

**Every state count, gate count and per-member `interesting` figure for the
P23 legs in this document is UNMEASURED.** The waves were read-only and never
ran the checker. Section 4's numbers are predictions, not measurements;
section 8 is where measurement lands.

## 1. Why this phase (the register is unoccupied at MEMBER level, and that is grep-checkable)

Novelty, MEASURED (both commands from the anvil-ocaml repo root, no trailing
slash on dir args - the P20 lesson):

- **The member-level probe.**
  `rg -n 'source = "[^"]*internal_rely_guarantee.rs:(606|613|640)' lib test`
  -> **ZERO hits, exit 1**. No shipped member anywhere in the tree cites
  E3, E4 or E5.
- **The companion file-level probe, and the honest reading of it.**
  `rg -n 'source = "[^"]*internal_rely_guarantee' lib test` -> **FOUR hits,
  exit 0**: `internal_guarantee.ml:377` (`:562`), `:396` (`:581`), `:416`
  (`:589`), `:436` (`:544`). Those are P21's G1-G4. **So the novelty claim is
  MEMBER-level, not FILE-level.** P21 could truthfully write "zero
  `internal_rely_guarantee.rs` citations anywhere" (its own header,
  `t_p21_regression.ml:5-8`); P23 cannot, and must not. The correct sentence
  is "the first shipped member sourced to the CONTROLLER-LOCAL binding
  functions `:613` / `:640`", never "the first member from that file".

Non-vacuity, MEASURED BY PROXY (this is why the selection wave ranked this
candidate first, and it is proxy evidence, not a direct measurement of L1 or
L2):

- E4's **condemned** conjunct rides G2's premise. G2 (`get_then_delete`,
  upstream `:581`) `interesting` is **0 on all five P21 graphs**
  (`p21_witness.ml:168` L0, `:172` Lc, `:176` Ld, `:180` Lm, `:184` L0v) and
  **4 / 104 / 40 / 432** on P22's SL0 / SLc / SLd / SLm (`p22_witness.ml:175`,
  `:179`, `:183`, `:187`). P22's graph is load-bearing for this phase exactly
  as `BUILD-SPEC-P22.md:322-324` precondition (a) predicted.
- E4's **needed** conjunct rides G3's premise. G3 `interesting` is
  **4 / 32 / 16 / 704** on the P22 graphs (`p22_witness.ml:176`, `:180`,
  `:184`, `:188`). **This is a proxy that section 4 predicts will FAIL for
  L1's needed conjunct on the shipped instantiation** - see prediction 5 and
  section 2.2 exclusion (2). Recording the proxy and its predicted failure
  together is the point.
- E5's `AfterListPod` premise is directly measured elsewhere: **4 of 20**
  states at `After_list_pod` on the P11 VSTS liveness graph
  (`t_p11_vsts_liveness.ml:100-104`). That graph is not a P23 graph, so it is
  evidence that the step is reachable at all, not evidence about SL0-SLm.

The blocker P21 recorded is STALE and this phase retires it.
`BUILD-SPEC-P21.md:134-136` excluded E3/E4/E5 on the ground that the port's
`Controller.ongoing_reconcile.local_state` is an untyped `Value.t` and the
step is not exposed. Both halves are false today: `pending_req_msg :
Message.t option` is exposed at `controller.mli:57`, and the typed state is
reachable through `V_stateful_set_pack.unmarshal_state : Value.t ->
V_stateful_set_reconciler.s Res.t` (`v_stateful_set_pack.mli:16-17`) onto the
seven-field record at `v_stateful_set_reconciler.mli:45-53` with its
seventeen-constructor `step` at `:14-33` (counted: 17). The
decode-inside-a-predicate idiom already ships (`invariants.ml:379-386`,
`fault_check.ml:431-436`).

## 2. The family (`lib/assurance/local_binding.ml` / `.mli`) - design pinned

Upstream `proof/internal_rely_guarantee.rs` has exactly **nine**
`pub open spec fn` (`rg -c 'pub open spec fn' <file>` = 9, re-counted this
pass). P21's partition of those nine is re-partitioned by this phase; the
result stays TOTAL and DISJOINT at nine (section 2.2).

### 2.1 SHIPPED (2 members)

| id | upstream | line | shape |
| --- | --- | --- | --- |
| L1 | `local_pods_and_pvcs_are_bound_to_vsts_with_key_in_local_state` | `:613` | pure `(cr_key, local_state) -> bool`; three foralls upstream, TWO ported |
| L2 | `local_pods_and_pvcs_are_bound_to_vsts_with_key` | `:640` | L1 at the decoded local state, PLUS the `AfterListPod` pending/in-flight block |

**Both source strings MUST BE BARE.** Exactly
`"vstatefulset_controller/proof/internal_rely_guarantee.rs:613"` and
`"...:640"` - no parenthetical qualifier, ever. `t_p21_regression.ml:358-362`
extracts the line with `String.rindex_opt s ':'` fed to `int_of_string_opt`; a
qualifier in the `vsts_invariants.ml:217` style makes `line_of_source` return
`None`, the member silently DROPS OUT of `roster_guarantee_lines`
(`t_p21_regression.ml:366-374`), and the E-ledger firewall pin at `:385-396`
PASSES while the member is invisible. That is a vacuously-green pin - this
project's named failure mode. Both sites were re-read this pass.

---

**L1 - `vsts_local_pods_and_pvcs_bound_in_local_state`**
source: `vstatefulset_controller/proof/internal_rely_guarantee.rs:613`

*holds.* At the scenario CR key ONLY. Look the reconcile up, then decode:

```
Option.fold (Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id))
  ~none:true
  ~some:(fun orc ->
    Result.fold (V_stateful_set_pack.unmarshal_state orc.local_state)
      ~error:(fun _ -> true)
      ~ok:(fun st -> C1 && C2))
```

- `~none:true` is **E3's guard, borrowed deliberately** (`:608`
  `contains_key(k) && k.kind == VStatefulSetView::kind()`, restricted to the
  one key). E4 itself is a pure function of `(cr_key, local_state)` and has no
  guard of its own. This is a rendering narrowing, not fidelity, and it is
  disclosed in the `.mli` in those words.
- `~error:true` mirrors Verus's unconstrained `unmarshal(...)->Ok_0` on a
  non-`Ok`. It is the house out-of-premise rule already stated at
  `internal_guarantee.ml:53-55`: out of premise folds `holds` to `true` and
  `interesting` to `false`.
- **C1, the needed forall, upstream `:617-622`** (verbatim from the re-read):
  `forall |i| #![trigger needed_pods[i]] 0 <= i < needed_pods.len() &&
  needed_pods[i] is Some ==> { let pod = needed_pods[i]->0; &&&
  pod.metadata.name is Some &&& pod_name_match(pod.metadata.name->0,
  cr_key.name) &&& pod.metadata.namespace == Some(cr_key.namespace) }`.
  Ported as `List.for_all` over `st.needed` (`Pod.t option list`,
  `v_stateful_set_reconciler.mli:47`) of `Option.fold ~none:true ~some:(fun
  pod -> Option.fold (Object_meta.name (Pod.metadata pod)) ~none:false
  ~some:(pod_name_matches cr_name) && Option.equal String.equal (Object_meta.
  namespace (Pod.metadata pod)) (Some cr_namespace))`. **The `is Some` guard
  IS the `~none:true`** - that identity is the whole reason the fold direction
  is what it is, and it goes in the `.mli`.
- **C2, the condemned forall, upstream `:623-628`**: the same three
  sub-conjuncts with **NO `Some` guard** (`:624 let pod = condemned_pods[i];`).
  Ported as `List.for_all` over `st.condemned` (`Pod.t list`, mli:`:49`) of
  the same body without the option layer.
- `pod_name_match` (`proof/predicate.rs:146-148`, `exists |ord: nat| name ==
  pod_name(vsts_name, ord)`) is rendered by **INVERSION** through
  `V_stateful_set_reconciler.get_ordinal` (`v_stateful_set_reconciler.mli:98`),
  reusing P18/P21's decision verbatim (`internal_guarantee.ml:113-121`) rather
  than re-litigating it.

*interesting.* **Premise-mirroring, NOT "decode succeeded"**: the reconcile at
`cr_key` exists AND decodes AND at least one of the two ported quantifiers has
a witness -
`List.exists Option.is_some st.needed || not (st.condemned = [])`.
Precedent: `inv16`'s `interesting` requires a NON-EMPTY filtered_pods
(`invariants.ml:1016-1021`). Counting a bare decode success would let a
decode-DEFAULT register as assurance - the `BUILD-SPEC-P22.md:325-327` trap
(d), narrowed by this phase's ruling (section 7).

*exclusions.* Two, each with its own treatment:

1. **The pvcs conjunct `:629-637` is NOT PORTED - EXCLUDE-WITH-A-PIN.**
   Upstream's six sub-conjuncts (`name is Some`, `pvc_name_match`,
   `generate_name is None`, `namespace == Some(cr_key.namespace)`,
   `owner_references is None`, `finalizers is None`) CANNOT FIRE on any P23
   graph. The only writers of `state.pvcs` are
   `v_stateful_set_reconciler.ml:553` (`let pvcs = make_pvcs cr 0 in`) and
   `:509`; `make_pvcs` (`:292-296`) is `Option.value ~default:[]
   sp.volume_claim_templates` mapped and filtered, hence `[]` whenever
   `volume_claim_templates` is `None`, which is exactly `vct:false`
   (`scenario.ml:240-241`). The leg's cr and seed are `vct:false`
   (`fault_check.ml:1129-1133` is the pattern being cloned;
   `BUILD-SPEC-P22.md:318` records `vct:false only`).
   **PIN:** an in-test assertion over EVERY P23 graph that every decoded
   ongoing state has `pvcs = []`. The omission is then behavior-free and the
   moment a `vct:true` leg lands, the pin reddens. Shipping the conjunct
   instead would add a THIRD copy of `pvc_name_matches`
   (`internal_guarantee.ml:137-152` is already a deliberate duplicate of
   `helper_invariants.ml:32-43`) for six sub-conjuncts that cannot fire - dead
   code wearing the costume of assurance.
2. **The needed conjunct C1 IS ported but is VACUOUS on the P22
   instantiation**, and that must be disclosed rather than discovered.
   `needed` is written ONCE, at the `After_list_pod` arm
   (`v_stateful_set_reconciler.ml:550-558`, from `partition_pods`), and
   `Create_needed` only advances `needed_index` (`:641-658`) - it never writes
   the created pod back. With `~desired:1 ~ordinals:[1]` the single needed
   slot is `None` forever, so `:617`'s `is Some` guard is false at every
   state. **The de-vacuizer, REQUIRED unless it is measured infeasible:** a
   SECOND instantiation `~desired:1 ~ordinals:[0;1]` (needed-live AND
   condemned-live). Two hazards, both disclosed, both UNMEASURED:
   (a) the shipped seed-integrity predicate (`scenario.ml:495-517`) is
   **INAPPLICABLE** at ordinal 0 because it requires, for EVERY requested
   ordinal, that the ordinal be `>= replicas` (`:508-509`); the second
   instantiation needs its OWN integrity check, not a reuse;
   (b) the graph is entirely UNMEASURED - pod-0 present means
   `Update_needed` / `Get_then_update` traffic that no committed graph
   contains. **Decision rule, committed now:** measure it in stage B; if it
   converges and stays bounded, ship it as the needed-live leg; if it blows up
   or reds, FALL BACK to EXCLUDE-WITH-A-PIN on the needed conjunct with the
   all-`None` assertion as the pin.

---

**L2 - `vsts_local_pods_and_pvcs_bound_with_key`**
source: `vstatefulset_controller/proof/internal_rely_guarantee.rs:640`

*holds.* Same lookup/decode skeleton as L1 (`~none:true` = E3's `:608` guard,
`~error:true` = the unconstrained `->Ok_0`), then E5's TWO conjuncts.

- **(a) `:642`** - L1's body at the decoded state, ported verbatim. The
  containment is deliberate; see the disclosure below.
- **(b) `:643-663`** - `local_state.reconcile_step == AfterListPod ==> {...}`
  rendered as an **EXHAUSTIVE 17-arm match** on
  `V_stateful_set_reconciler.step` (`mli:14-33`): `| After_list_pod -> block`
  and the other sixteen constructors spelled out `-> true`. No wildcard. The
  `inv16` shape (`invariants.ml:1009-1015`).
  `block = Option.fold orc.pending_req_msg ~none:false ~some:(fun rm ->
  Message.equal_host_id rm.dst Message.Api_server &&
  list_req_content_matches rm ~namespace:cr_key.namespace &&
  List.for_all resp_ok (ok_list_resps_for s rm))`.
  - `~none:false` **IS** upstream `:645` `pending_req_msg is Some`, same
    polarity as `inv16`'s `pending_list_req_ok` (`invariants.ml:371`).
  - `list_req_content_matches` is the exhaustive-arm content test
    (`invariants.ml:334`) requiring `Common.equal_kind lr.kind Pod.kind &&
    String.equal lr.namespace namespace` - that is `:647` plus `:648-651`
    (`ListRequest { kind: Kind::PodKind, namespace: cr_key.namespace }`) in
    one test.
  - `ok_list_resps_for s rm` = `List.filter` over
    `Message.Pool.distinct (Cluster.in_flight s)` of
    `Message.equal_host_id m.src Message.Api_server &&
    Message.resp_msg_matches_req_msg m rm &&
    Option.is_some (list_resp_objs m)` - i.e. `:653` in-flight, `:655`
    `msg.src is APIServer`, `:656` `resp_msg_matches_req_msg`, `:657`
    `is_ok_resp` (the `invariants.ml:348-368` shape verbatim).
  - `resp_ok m` = every object of the response has
    `metadata.namespace = Some cr_key.namespace` - `:659-661`, and ONLY that.
    **Do NOT copy `inv16`'s extra owner-ref conjunct** (`invariants.ml:978-980`);
    upstream `:660-661` carries one conjunct.

*interesting.* Mirrors `:643` plus `:645` exactly: the reconcile at `cr_key`
exists, decodes, `st.reconcile_step = After_list_pod`, and
`Option.is_some orc.pending_req_msg`. Anything weaker (for instance "decode
ok") makes the member look live while its whole second conjunct sleeps.

*exclusions.* **No conjunct of E5 is dropped.** Two RENDERING narrowings that
must be disclosed in the `.mli` and NOT sold as fidelity:

1. **THE GUARD IS BORROWED FROM E3.** E5's own body indexes a Verus total map
   unguarded (`:641 s.ongoing_reconciles(controller_id)[cr_key].local_state`);
   the port has no total map, so the absent-key case folds to `true` - which
   is E3's `:608` premise restricted to the one key. The source string stays
   bare `:640`; the `.mli` says in words that the guard comes from `:606`.
   Skipping this disclosure is the repo's recurring OVERCLAIM class
   (`BUILD-SPEC-P22.md:113-119` records the "plus the structural suite" draft
   as finding F1, with P14 F1 / P16 F1 / P17 finding 2 as the prior offences).
   Precedent for disclosing a narrowing-in-the-rendering:
   `internal_guarantee.mli:53-61`.
2. **`is_ok_resp(msg.content->APIResponse_0)` (`:657`) is rendered as "the
   content is a `List_response` whose `res` is `Ok`"** (`Result.to_option` on
   `api_method.mli:154`'s `res`, the `invariants.ml:348-360` shape). That is
   NARROWER than upstream's generic ok-ness, and it is sound only because
   `:656 resp_msg_matches_req_msg` already pins the response to the list
   request. Say that; do not claim a verbatim port.

*separate, test-side, NOT part of the member.* A count of states where
`ok_list_resps_for s rm` is **non-empty** - the premise of the inner forall
`:652-657`. **Its liveness is UNKNOWN.** It is UNVERIFIED whether a matching
ok `List_response` is ever in flight while the reconcile is still parked at
`After_list_pod`; nothing in the tree measures it today. **Do NOT assume it is
non-zero.** If that count is 0 on every P23 graph, either the `.mli` MEASURED
block discloses it in those words, or the conjunct is PULLED with that count
as its pin. Prediction 6 in section 4 states this as a falsifiable claim.

### 2.2 The E-LEDGER RE-PARTITION (this is a re-partition, not a red)

| id | upstream | line | disposition after P23 |
| --- | --- | --- | --- |
| G4 | `no_interfering_request_between_vsts` | `:544` | SHIPPED (P21) |
| G1 | `vsts_internal_guarantee_create_req` | `:562` | SHIPPED (P21) |
| G2 | `vsts_internal_guarantee_get_then_delete_req` | `:581` | SHIPPED (P21) |
| G3 | `vsts_internal_guarantee_get_then_update_req` | `:589` | SHIPPED (P21) |
| L1 | `..._with_key_in_local_state` | `:613` | **SHIPPED (P23, THIS phase)** |
| L2 | `..._with_key` | `:640` | **SHIPPED (P23, THIS phase)** |
| E1 | `vsts_internal_guarantee_conditions` | `:522` | EXCLUDED (collapses to G4 on a single-CR scenario) |
| E2 | `every_msg_from_vsts_controller_carries_vsts_key` | `:528` | EXCLUDED (already shipped as P19's M1 under `helper_invariants.rs:1213`) |
| E3 | `local_pods_and_pvcs_are_bound_to_vsts` | `:606` | **EXCLUDED-AND-LEDGERED (new ground, below)** |

**6 shipped + 1 + 1 + 1 = 9. Total and disjoint.**

**Why E3 is EXCLUDED and not a third member.** E3 is the LIFT of E5 over all
VSTS-kind keys in `ongoing_reconciles` (`:608-609`, one conjunct, six-line
body). Every shipped scenario is single-CR (`scenario.ml:249-250`,
`vsts_ref = { kind = V_stateful_set.kind; name = "vsts1"; namespace = "ns" }`
at `:252-253`), so the map holds at most the one VSTS key and E3 collapses to
L2-at-the-scenario-key, or is vacuously true. That is **"L2 wearing a hat"** -
the EXACT ground P21 used for its own E1 (`BUILD-SPEC-P21.md:132`: "On a
single-CR scenario this COLLAPSES to G4 at the scenario CR, so shipping it
would be G4 wearing a hat"). A two-CR spine de-vacuizes E3; that is a later
phase, not P23.

**Why L1 is a separate member even though L2 CONTAINS it.** `:642` calls E4,
so L2's `holds` strictly implies L1's. The containment is DELIBERATE and has
house precedent: P21 shipped G4 knowing it is strictly stronger than
`G1 && G2 && G3` and made the overlap the design point
(`BUILD-SPEC-P21.md:108-126`). Shipping E5 alone would put E4's text inside a
member cited `:640` while `:613` stayed ledgered EXCLUDED - a FALSE ledger of
exactly the class P21 flagged for its E2 (`BUILD-SPEC-P21.md:133`). Two
members also make E4's vacuity separately MEASURABLE through per-member
`interesting`, instead of hiding it inside E5.

**CONSEQUENCE OF THE CONTAINMENT, disclosed here and again in the `.mli`.**
`Invariants.first_violated` (`invariants.ml:1046`,
`List.find_opt (fun i -> not (i.holds s)) invs`) is FIRST-IN-LIST-ORDER, and
the leg's `~violated` resolves through it (`fault_check.ml:249-258`). **So
for ANY shared-conjunct failure, L1 is the member named and L2 looks green.**
Per-member attribution therefore requires per-member red/`interesting` counts
from a REPLICA (the `t_p21_guarantee.ml:193-237` technique), NOT the leg's
`violated` name. This is disclosed the way P21 disclosed G1's domination of
the union gate.

**The re-partition is PRE-AUTHORIZED, so it is not a red.**
`BUILD-SPEC-P22.md:279-281` states verbatim that `t_p21_regression.ml` is not
edited by P22 because "that clause reds only if P23 ships E3-E5,
deliberately", and `t_p22_regression.ml:67-69` and `:93-96` keep the single
assertion site in `t_p21_regression`. P23 is the phase that trips it, by
design. Section 6 lists the exact edits.

### 2.3 Family shape

Both members need the CR (for `cr_key` / name / namespace) and the controller
id, so the P18/P21 keyword shape applies unchanged
(`BUILD-SPEC-P21.md:148-152`). Exported surface is exactly two vals, the
`internal_guarantee.mli:185/:197` shape (verified: `rg -n '^val '
lib/assurance/internal_guarantee.mli` returns exactly those two lines):

```ocaml
val binding_sources : string list
val binding_family : cr:V_stateful_set.t -> controller_id:int -> Invariants.invariant list
```

**No dune edit.** `lib/assurance/dune` already lists `anvil_controllers` (for
`V_stateful_set_pack` / `V_stateful_set_reconciler`) and `anvil_cluster` (for
`Cluster` / `Controller` / `Message` / `Object_ref_map`), all `-open`ed.

**NOTHING NEW NEEDS EXPORTING from any existing `.mli`.** That is a deliberate
finding of the port-plumbing report, not an accident: the whole family is
buildable against today's public surface.

### 2.4 Rendering notes (each is a decision, and each goes in the `.mli`)

- **Lookup**: `Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s
  controller_id)`. `Cluster.ongoing_reconciles` is total - a missing
  controller id yields the empty map (`cluster.mli:78-82`).
  `Object_ref_map` has no `.mli` and is `include Map.Make(...)`
  (`lib/cluster/object_ref_map.ml:17-26`), so the full total `Map.S` surface
  is in scope. Precedents: `invariants.ml:379-386`, `vsts_step_view.ml:15-22`.
  **Do NOT use `Object_ref_map.for_all` here** - that is E3's lift, which this
  phase EXCLUDES.
- **Decode**: `V_stateful_set_pack.unmarshal_state : Value.t ->
  V_stateful_set_reconciler.s Res.t` (`v_stateful_set_pack.mli:16-17`). There
  is NO `Res.fold`; `Res.t = ('a, Err.t) result` (`res.mli:7`), so use stdlib
  `Result.fold ~error ~ok` - the shipped idiom at `fault_check.ml:431-436` and
  `invariants.ml:379-386`. Never a two-arm result match.
- **DUPLICATE-AND-PIN, not export.** Everything L1/L2 needs from
  `Internal_guarantee` is PRIVATE. Copy, with a comment citing the origin, and
  add the agreement pin - the house precedent is stated in-tree at
  `internal_guarantee.ml:131-136`. Copied: `msgs`
  (`internal_guarantee.ml:34-35`); `cr_namespace` / `cr_name` / `cr_key_of`
  (`:75`, `:78`, `:93`, with its disclosed reason for NOT calling
  `V_stateful_set.object_ref`, which is partial); `pod_name_matches`
  (`:113-121`). The list-request / list-response / ok-response helpers are
  local `let`s inside a function body in `invariants.ml`
  (`list_req_content_matches :334`, `list_resp_objs :348`,
  `ok_list_resps_for :361`, `pending_list_req_ok :371`), so they are not
  callable either - transpose them VRS -> VSTS the way `Vsts_step_view`
  transposed `Step_view`. **NOT duplicated: `pvc_name_matches`** - the pvcs
  conjunct is excluded-with-a-pin, so a third copy is not created.
- **House rules, hook-enforced.** No `raise` / `failwith`; no two-arm
  option/result match (`Option.fold` / `Result.fold` / `Option.bind`); no
  `List.nth` and no `arr.(i)` (`List.for_all` / `List.exists` / `List.filter`
  over the decoded lists); exhaustive matches on the seventeen steps and on
  every `Message` / `Api_method` sum. `lib/assurance` is clean today
  (`rg -c 'raise |failwith' lib/assurance/*.ml` returns no count lines; the
  only textual hits are prose at `internal_guarantee.ml:102` and `:134`).

## 3. The leg (`Fault_check.check_local_binding_under_faults`, EOF of fault_check.ml)

One new leg appended after `fault_check.ml:1148` (current EOF), cloning
`check_scale_down_under_faults` (`ml:1123-1148`) verbatim except for the
`invs` line:

```
?(depth = default_depth) ?(req_drop = false) ?(pod_monkey = false)
(bound : Bound.t) (budget : budget) ~(desired : int)
~(ordinals : int list) ~(require_fault : bool) : fault_report
```

- **seed** = `Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true
  ~req_drop ~pod_monkey ()` (`fault_check.ml:1129-1132`, unchanged).
- **cr** = `Scenario.vsts ~desired ()` (`:1133`, unchanged).
- **invs** = `Local_binding.binding_family ~cr ~controller_id` **and NOTHING
  ELSE.**
- gate = the standard union gate with `budget_fault_taken` under
  `~require_fault` (`fault_check.ml:1142-1148`). "Union" here means the OR
  over the register's OWN two members (`List.exists ... invs`), never a union
  of two families.

**THE ASSERTED-ALONE RULE.** The family is asserted ALONE: not unioned with
`Internal_guarantee.guarantee_family`, not with
`Invariants.cluster_structural`, not with `Invariants.always`, not with
`Vsts_invariants.always`. This is the P15 MASKING TRAP, forbidden in-tree at
`fault_check.ml:476-482` (re-read at those exact lines this pass, no drift):
the family is asserted ALONE, never unioned, because a unioned leg reports the
first member in list order and never evaluates the member the phase exists to
measure. The argument binds P23 mechanically, not by analogy: `~violated` is
`violated_of invs` (`fault_check.ml:1141` in the cloned leg) resolving through
`Invariants.first_violated` (`fault_check.ml:249-258` ->
`invariants.ml:1046`), FIRST match in LIST ORDER. A `violated` naming a P21
or structural member on a P23 leg means the lists were unioned somewhere:
harness bug, not a finding.

**Bound: its own record, never an edit.** `P23_witness.p23_bound` is derived
from `P22_witness.p22_bound` (`p22_witness.ml:111`, itself derived from
`P13_witness.p13_bound`), widened ADDITIVELY only if the `~ordinals:[0;1]`
instantiation demands it. Do NOT touch `p13_bound`, `p21_bound`, `p22_bound`,
`Bound.default`, `Scenario.vsts_seed_faults`, `vsts_cluster`, `controller_id`,
`Cluster.enabled_successors`, or `faulted_equal` / `faulted_hash`.

**Pin safety, and why it is structural rather than hoped for.** `run_leg`
calls `Model_check.explore` with only `~depth ~successors ~equal ~hash ~init`
(`fault_check.ml:274-279`) and `explore` takes no invariant argument
(`model_check.mli:57-63`); `fault_metadata` (`ml:202-233`) reads only
`~bound ~budget ~cluster ~controller_id`. **Graphs are family-blind.** So a
new leg that reuses `(seed, bound, budget, depth)` cannot move any committed
graph. The committed pins that must come back BYTE-IDENTICAL:
**76 / 464 / 744 / 1976 / 116** (P13-P21, `p21_witness.ml:148-152` re-exported
into `p22_witness.ml:148-152`) and **88 / 808 / 1144 / 10216** (P22,
`p22_witness.ml:159-162`), with P22's four gates **20 / 276 / 96 / 2080**
(`p22_witness.ml:163-166`). **A moved pin is a phase-STOP, never a retune.**

**Legs and order (the MG5 lesson: zero-budget FIRST, then faults):**

| leg | instantiation | budget | require_fault |
| BL0 | `~desired:1 ~ordinals:[1]` | zero | false |
| BLc | `~desired:1 ~ordinals:[1]` | crash-only | true |
| BLd | `~desired:1 ~ordinals:[1]` | drop | true |
| BLm | `~desired:1 ~ordinals:[1]` | monkey | true |
| BN0 | `~desired:1 ~ordinals:[0;1]` | zero | false |

BN0 is the **needed de-vacuizer** and is CONDITIONAL (section 2.2 exclusion
2): it ships only if stage B measures it convergent and bounded. Its graph is
UNMEASURED. If it is dropped, the needed conjunct becomes
EXCLUDE-WITH-A-PIN with the all-`None` assertion as its pin, and that fact
goes in the `.mli` MEASURED block, not in a footnote.

`report_decisive` is a documented PHANTOM (`BUILD-SPEC-P20.md:782-783`); use
the local exhaustive two-arm outcome projection per
`t_p21_guarantee.ml:107-110`.

**What catches leg-side family drift (the P22 F2 correction, restated because
it corrects a natural wrong answer).** It is NOT the per-member `interesting`
pins - those are computed ENTIRELY test-side from a test-local `family`
binding, and would not move if the leg swapped families. The only leg-side
coupling is the leg-COMPUTED gate (`fault_check.ml:1142-1148`), surfaced as
`fault_report.gate_states`. The residual is stated rather than waved: that
coupling is a COUNT, so a DIFFERENT family whose interesting-union coincides
on every graph would evade it. Exposing the leg's family for a direct pin is
CANDIDATE C, and section 7 records why it is not shipped here.

## 4. Predictions, committed BEFORE the build

Written down now so the build can REFUTE them. Numbered so section 8 can
answer them one for one. Everything here is a prediction; NONE of it is a
measurement.

1. **PHASE GATE: L2 `interesting` > 0 on BL0.** The reconcile parks at
   `After_list_pod` with a pending list request on the way to the
   condemned delete, so L2's premise must fire. If it is 0, the phase STOPS
   and diagnoses the decode path and the step projection before anything else
   is written. (Support, not proof: `After_list_pod` is measured reachable at
   4 of 20 states on a DIFFERENT graph, `t_p11_vsts_liveness.ml:100-104`.)
2. **PIN REPRODUCTION.** The nine committed graph pins come back
   BYTE-IDENTICAL: **76 / 464 / 744 / 1976 / 116** and
   **88 / 808 / 1144 / 10216**, with P22's four gates
   **20 / 276 / 96 / 2080** unmoved. Structural argument in section 3
   (graphs are family-blind). A moved pin is a phase-STOP.
3. **All shipped legs CLEAN and DECISIVE; L1 and L2 GREEN on every graph;
   red = 0 everywhere.** A red is a fidelity divergence and a real finding,
   not noise. Note the attribution caveat: because L1 is contained in L2, a
   shared-conjunct red names L1 and leaves L2 apparently green (section 2.2).
4. **DECODE FAILURES = 0 on every P23 graph.** The `~error:true` fold is
   therefore never exercised, and the test carries that count as a separate
   assertion rather than inferring it. Basis: `marshal_state` always writes
   all seven members (`v_stateful_set_pack.ml:57-69`), so on port-produced
   states the decode defaults never fire.
5. **VACUITY QUESTION 1, stated falsifiably: L1's needed witness count is
   EXACTLY 0 on BL0/BLc/BLd/BLm** (`List.exists Option.is_some st.needed`
   never true), while L1's condemned witness count is > 0 on BL0. If the
   needed count is non-zero, this prediction is REFUTED and the section 2.2
   exclusion-2 reasoning is wrong - record that, do not quietly delete it.
6. **VACUITY QUESTION 2, stated falsifiably: L2's inner ok-List-response
   premise count (`ok_list_resps_for s rm` non-empty) is > 0 on at least one
   of BL0/BLc/BLd/BLm.** This is the prediction most likely to be refuted;
   it is UNVERIFIED in the tree today. If it is 0 on every graph, the
   `.mli` MEASURED block says so verbatim, or the conjunct is pulled with
   that count as its pin (section 2.1, L2).
7. **BN0 (`~ordinals:[0;1]`) converges within `max_reconcile_depth` and its
   state count stays within one order of magnitude of BL0's.** This is a
   NON-BINDING structural estimate - the graph is entirely UNMEASURED and
   adds `Update_needed` / `Get_then_update` traffic no committed graph
   contains. A refutation here costs the needed-live leg, not the phase.
8. **BL0/BLc/BLd/BLm state counts equal P22's 88 / 808 / 1144 / 10216
   EXACTLY**, because the seed, bound, budget and depth are the same and
   graphs are family-blind. This is a strong prediction and a cheap one to
   check first.
9. **The four P23 gate counts are UNPREDICTED.** They cannot be derived from
   20 / 276 / 96 / 2080 - that is a different family's interesting-union.
   Anyone who writes a number here before stage B is guessing. NON-BINDING:
   no estimate is offered.
10. **Wall time.** NON-BINDING estimate only: the sole in-tree figure is the
    aggregate ~67 s for P22's four legs plus four replicas
    (`BUILD-SPEC-P22.md:338-339`, a one-machine throwaway probe). A P23 pass
    over the same graphs plus test-side replicas is the same order.
    **Measure once; do not extrapolate.**

## 5. Mutation matrix (the only thing that makes a green mean anything)

All source mutants are MANUAL Edit-apply / Edit-revert (never
`git checkout --`), residue-scanned with `git diff --stat` after each row.

**House rule, restated because it keeps mattering: a mutant killed by a BUILD
ERROR or by a TIMEOUT is NOT caught - reshape it.** A mutant must be SEEN to
red an assertion, and a mutant predicted green must be SEEN green.

- **MB1 (HEADLINE, red-capability, and the ONLY row that earns L2 its keep):**
  make the reconciler emit its pod `List_request` in a FOREIGN namespace
  (`v_stateful_set_reconciler.ml:528-531`, the `Init` arm's emit; the
  namespace it reads is the CR's own, bound at `:525-527`). **PREDICT: BL0
  flips clean -> Refuted naming L2**,
  via `list_req_content_matches` failing `String.equal lr.namespace namespace`
  (upstream `:648-651`). **Mechanism that makes this the headline:** the whole
  P21 register is BLIND to it - G4's read-only arm is
  `APIRequest::ListRequest(_) | APIRequest::GetRequest(_) => true`
  (upstream `:551`, `BUILD-SPEC-P21.md:116`), so a wrong-namespace list is
  invisible to G1-G4 and visible only to L2. **Control:** re-run the P21 and
  P22 legs under the SAME mutant and record whether they stay green; if the
  P21 register also reds, the "earns its keep" claim is WEAKER than stated and
  must be rewritten, not defended.
- **MB2 (L1 red-capability, and it is genuinely hard):** L1's name conjunct is
  close to UNFALSIFIABLE by construction. `condemned` is built by
  `partition_pods` (`v_stateful_set_reconciler.ml:405-414`) via
  `get_ordinal parent n`, and L1's `pod_name_match` rendering is INVERSION
  through that SAME `get_ordinal` (`internal_guarantee.ml:113-121`), so any
  mutation of `get_ordinal` moves both sides in lockstep. The namespace
  conjunct cannot red either, because the list is namespace-scoped from the
  CR's own namespace (`:527-531`). The only red-able mutant is a DECOUPLING
  one: `partition_pods:411` `Option.map ... (get_ordinal parent n)` given a
  `~default` fallback ordinal, PLUS a rogue-named pod (available with no
  source edit via `Bound.monkey_forge`, `bound.ml:9`, re-admitted at
  `cluster.ml:760-768`). **PREDICT: L1 reds.** **If it cannot be SEEN red, L1
  is a green that never fires and MUST be downgraded to EXCLUDE-WITH-A-PIN.**
  That downgrade is a legitimate outcome of this phase, not a failure of it.
- **MB3 (attribution datum, and it is expected to be UNFLATTERING):** the MB2
  mutant, with the leg's `violated` name recorded. **PREDICT: `violated` names
  L1, and L2 - which is strictly stronger and also false at that state -
  reports nothing**, because `Invariants.first_violated` (`invariants.ml:1046`)
  returns the FIRST member in list order. Per-member red counts from the
  replica (`t_p21_guarantee.ml:193-237`) show BOTH red. This row exists to
  MEASURE the containment consequence rather than assert it.
- **MB4 (TRAP ROW, negative control):** apply the MB1 namespace mutation to a
  request that is NOT the pod list - the `Get_then_delete` key's namespace on
  the condemned arm (`v_stateful_set_reconciler.ml:732-739`). **PREDICT: L2
  stays GREEN on every leg** (its list-request conjunct constrains only the
  pending LIST request at `After_list_pod`), while the P21 register reds.
  This is the measured witness for "a red anywhere is not L2 coverage", and
  it is the row that stops the headline claim from being laundered.
- **MB5 (premise wiring, = P21's MG7 / P22's MS5 port):** instantiate the
  family in-test with `controller_id + 1`. **PREDICT: both members'
  `interesting` = 0 on BL0, and red = 0** (the `~none:true` fold sends every
  state out of premise). Mechanism: `Cluster.ongoing_reconciles` is total and
  yields the empty map for a missing controller id (`cluster.mli:78-82`), so
  `find_opt` returns `None` at every state.
- **MB6 (the fold-direction mutant, and it targets a fold NOTHING else
  tests):** flip L1's decode fold from `~error:(fun _ -> true)` to
  `~error:(fun _ -> false)`. **PREDICT: BYTE-IDENTICAL results on every P23
  graph**, because prediction 4 says decode failures are 0. **This row is the
  reason the decode-failure counter is a separate committed assertion:** an
  identical result is exactly what proves the counter, and a DIFFERENT result
  refutes prediction 4 and is the more interesting outcome. Hedged on purpose;
  either measured outcome is the datum.
- **MB7 (the pvcs-exclusion pin):** in a THROWAWAY in-test variant, seed with
  `~vct:true` and assert the pvcs-are-empty pin. **PREDICT: the pin REDDENS**
  (`make_pvcs` now returns a non-empty list, `v_stateful_set_reconciler.ml:
  292-296` with `volume_claim_templates = Some [...]`,
  `scenario.ml:240-241`). This is what makes "excluded with a pin" mean
  something rather than mean "omitted". If the pin does NOT redden, the
  exclusion is unpinned and the conjunct must be ported.
- **MB8 (the bare-source trap, a documentation-integrity control):** append a
  parenthetical qualifier to L1's source string, e.g.
  `"...internal_rely_guarantee.rs:613 (needed+condemned only)"`. **PREDICT:
  `t_p21_regression`'s E-ledger reversal clause STILL PASSES while L1 has
  silently vanished from `roster_guarantee_lines`**, because
  `line_of_source` (`t_p21_regression.ml:358-362`) returns `None`. That
  vacuous green is the failure this row exists to exhibit; the phase must
  therefore ALSO carry a positive assertion that both `:613` and `:640` are
  PRESENT in `roster_guarantee_lines`, not merely that no excluded line is.
  MB8 is what proves that positive assertion has teeth.

## 6. Files

- `lib/assurance/local_binding.ml` / `.mli` - NEW. Two members, two exported
  vals (`binding_sources`, `binding_family`), full house `.mli` block
  (WHAT-A-RED-MEANS / Shape / rendering narrowings / borrowed-guard
  disclosure / containment disclosure / honest-vacuity / MEASURED).
  **No `lib/assurance/dune` edit** (section 2.3).
- `lib/checker/fault_check.ml` / `.mli` - `check_local_binding_under_faults`
  appended after `ml:1148`, plus its `.mli` block. **No `fault_report` field
  is added** (section 7, candidate C).
- `lib/checker/BUILD-SPEC-P23.md` - this file; sections 8 and 9 land with the
  build and the review.
- `test/p23_witness.ml` - UNLISTED in `dune (names)` (witness convention,
  `p21_witness.ml:8-10`); `p23_bound` plus all new pins, single-sourced.
- `test/t_p23_binding.ml` / `t_p23_mutation.ml` / `t_p23_regression.ml` -
  **`test/dune (names)` 76 -> 79**, appended before the closing paren.
  (76 counted this pass across `test/dune:2-20`.)
- `test/p21_witness.ml` - **EDITED** (the re-partition):
  `ledger_shipped_lines` (`:214`) `[544; 562; 581; 589]` ->
  `[544; 562; 581; 589; 613; 640]`; `ledger_e3_e5_lines` (`:217`)
  `[606; 613; 640]` -> `[606]` and RENAMED to `ledger_e3_lines`; the prose at
  `:202-212` reworded so the E3-E5 bucket becomes E3 only.
- `test/t_p21_regression.ml` - **EDITED**, and this is the edit that is easy
  to miss and is load-bearing. Its `roster_pairs` is built from a LITERAL
  thirteen-suite list local to that file (`shipped_suites :214-234`,
  `committed_roster :239-254`), so a new P23 family is NOT swept
  automatically and the reversal clause at `:385-396` would stay GREEN while
  the exclusion is in fact re-opened. Add the P23 family to BOTH literals
  (13 -> 14 there, its test name at `:425` included) and reword the clause
  text at `:390-392` from "E1 :522 / E2 :528 / E3-E5 :606/:613/:640" to E3
  `:606` only, plus the "thirteen-suite roster" string at `:386-387`.
  **RECOMMENDED: keep the single assertion site in `t_p21_regression`**
  (the house convention `t_p22_regression.ml:93-96` names) rather than
  moving the clause into `t_p23_regression`.
- `test/t_p23_regression.ml` - roster **FOURTEEN -> FIFTEEN**: append the
  P23 label with the "(P23, THIS phase)" marker, demote `p22_label` into the
  swept set, re-key the self-exclusion on the P23 label, and carry
  `Pair_guard` in both orders. `t_p22_regression.ml:328-346` is the shape;
  a verbatim copy-forward REDS (its assertions name FOURTEEN explicitly).
- Suggested commit subject:
  `feat(assurance): P23 controller-local binding register (internal_rely_guarantee.rs:613/:640; E-ledger re-partitioned 4+5 -> 6+3)`

## 7. Limits, disclosed

- **L1 IS CLOSE TO A THEOREM OF THE PORT.** Its name conjunct is
  unfalsifiable by construction (both sides invert through the same
  `get_ordinal`, section 5 MB2) and its namespace conjunct cannot red because
  the pod list is namespace-scoped from the CR's own namespace
  (`v_stateful_set_reconciler.ml:527-531`). If MB2 cannot be SEEN red, L1 is
  a green that never fires and must be downgraded to EXCLUDE-WITH-A-PIN.
- **"THE NEW REGISTER CATCHES WHAT P21 MISSES" IS FALSE FOR L1.** The L1
  red-making mutant also reds G2, because upstream `:584`
  `pod_name_match(req.key().name, vsts.metadata.name->0)` is a G2 conjunct
  too. The earns-its-keep claim survives for **L2's list-request conjunct
  only** (section 5, MB1). Phrase it that way everywhere.
- **PER-MEMBER ATTRIBUTION IS NOT AVAILABLE FROM THE LEG.** L1 is contained
  in L2, and `Invariants.first_violated` is first-in-list-order, so the leg's
  `violated` names L1 for any shared-conjunct failure. Attribution requires
  the replica technique (`t_p21_guarantee.ml:193-237`).
- **L2'S INNER FORALL (`:652-662`) MAY BE VACUOUS.** UNVERIFIED today
  (prediction 6). It fires only in states where an ok `List_response` matching
  the pending request is still in flight while the reconcile is parked at
  `After_list_pod`.
- **THE NEEDED CONJUNCT IS VACUOUS ON THE SHIPPED INSTANTIATION AND ITS FIX
  IS RISKY.** Section 2.1, exclusion 2. The de-vacuizer `~ordinals:[0;1]` is
  UNMEASURED and falls OUTSIDE the shipped seed-integrity predicate
  (`scenario.ml:495-517` requires every requested ordinal be `>= replicas`),
  so it needs its own integrity check, not a reuse.
- **THE PVCS CONJUNCT IS NOT PORTED** (excluded with the pvcs-are-empty pin).
  `vct:false` only; a `vct:true` leg is deferred.
- **DECODE-DEFAULT VACUITY IS REAL BUT NARROWER THAN P22 RECORDS, and this
  spec corrects rather than repeats it.** `BUILD-SPEC-P22.md:325` says
  `unmarshal_state` "silently defaults needed/condemned/pvcs/indices".
  Verified at `v_stateful_set_pack.ml:71-114`: it defaults ONLY when the JSON
  member is ABSENT or literally null (`Json.opt_mem`, `:78-99`), `step` is
  MANDATORY (`Json.get`, `:75-77` -> `Err.Missing_field`), a non-object
  `Value.t` is a hard `Decode_error` (`:111-114`), and `marshal_state` always
  writes all seven members (`:57-69`). Keep the decode-failure and
  decode-default counters anyway: the `~error:true` fold direction is
  otherwise untested (section 5, MB6).
- **SCOPE LIMIT, inherited from P22 and unfixed here: no structural invariant
  is evaluated on any P23 graph.** The leg asserts the binding family ALONE
  (section 3), so `Invariants.cluster_structural ~controller_id` (inv1-6) is
  never evaluated on BL0/BLc/BLd/BLm/BN0. The seed still PLANTS pods straight
  into etcd. `BUILD-SPEC-P22.md:294-311` states the consequence in full; the
  right remedy is a SEPARATE structural leg over the same seed, NOT a union.
  Weighing that is the first thing the P24 author should do before reusing
  these graphs.
- **CANDIDATE C (`fault_report.family` + `run_leg ~invs`) IS NOT SHIPPED IN
  P23.** The ruling is explicit. The blast radius is genuinely small - exactly
  ONE construction site of `fault_report` exists in the repo
  (`fault_check.ml:284-300`, inside `run_leg`), every other use is a
  `x.field` projection, no `{ r with ... }` exists, and warning 9 is disabled
  in `lib/checker/dune`, `test/dune` and `bin/dune`. The reason to refuse is
  that its claimed benefit is NOT demonstrated, and shipping it on the stated
  rationale would itself be the overclaim this discipline exists to block.
  Its motivating mutant is **already caught without it**: MC1 (leg-side family
  argument drift, `~controller_id:(controller_id + 1)`) moves `gate_states`
  from 20 to 0 against the pinned 20/276/96/2080, MEASURED as P22's MS5 row
  (`BUILD-SPEC-P22.md:428`, "all four members interesting = 0 AND red = 0 at
  the wrong id").
  **NAMED PRECONDITION MC2, which a later phase must EXHIBIT before the field
  ships:** swap the leg's family to a DIFFERENT shipped family whose
  interesting-union count coincides on all four graphs (candidate:
  `Helper_invariants.helper_family ~cr ~controller_id` at
  `fault_check.ml:1134`) and SEE the gate pins 20/276/96/2080 come back
  UNMOVED with every other pinned number byte-identical. Until MC2 is
  exhibited and seen to SURVIVE today's pins, the field's value is
  hypothetical. Note further that even once shipped, the field is stronger
  than a `(name, source)` pin only if the test EVALUATES the leg's closures on
  states, which needs the replica technique, because `run_leg` deliberately
  does not expose the reachable graph (`fault_check.ml:265-267`). Latent
  hazard to record: `family : Invariants.invariant list` would put CLOSURES
  into EVERY report, so a future polymorphic compare or hash of a clean report
  would begin raising `Invalid_argument`. No site does this today.
- **CANDIDATE B (the cluster-level structural register) IS DEFERRED TO P24,
  and the reason is that it CANNOT BE RED.** Every mutant that would make it
  mean something (uid collision, second controller owner, non-monotone rv) is
  forbidden by the seed's real `Api_server.handle_create_request` path; its
  `interesting` predicates are near-tautological (`invariants.ml:206`
  `not (is_empty (resources s))`, `:246`, `:262`); `inv6` is structurally
  vacuous on a single-CR seed (`invariants.ml:132` requires
  `cardinal (ongoing s) >= 2`); and it ships ZERO new upstream register. It is
  a green that could not have been red without sabotaging the seed builder.
  P24 must therefore bring a de-vacuizing spine (two CRs or two controllers)
  WITH it, or not bring it.
- **THE P24/P25 BANK: `proof/liveness/state_predicates.rs`.** MEASURED this
  pass: **46 `pub open spec fn`** (`rg -c 'pub open spec fn'` = 46), **34
  `StatePred` occurrences** (`rg -c 'StatePred'` = 34), and **ZERO citations
  anywhere in the port** (`rg -n 'state_predicates' lib test` = exit 1). Note
  the path drift from the ruling: the file is at
  `src/controllers/vstatefulset_controller/proof/liveness/state_predicates.rs`,
  not `proof/state_predicates.rs`. It is a genuinely stronger novelty target
  than P23's two members, but it has no ledger, no banked preconditions, one
  roughly 114-line member, roughly 9 dead PVC members and an unconstrained
  slice choice. P23 is a disciplined two-member down-payment on the same
  plumbing; the register itself is P24/P25 material and needs its own
  partition wave first.
- **REVIEW DEBT: SETTLED, not open.** Two questions the selection wave raised
  are already closed and are recorded here so they are not re-raised.
  (a) **The P21 review wave DID run.** `ctxcat-review` returned 0 findings,
  verified NON-VACUOUS, plus an opus adversarial pass that produced 6
  findings, all fixed. Scout `F-review-debt` inferred "open" from a missing
  section-9 header in `BUILD-SPEC-P21.md` - that is the absence-of-evidence
  trap, and the absence of a section is not proof the wave never ran.
  (b) **P22 finding F3 WAS re-verified**, by a dedicated confirm-by-mutation
  agent: 5 mutants, every one KILLED by an assertion. That agent also found
  TWO REAL GAPS in the landed F3 predicate - owner-ref FIDELITY (uid alone is
  not enough; `pod_filter` admits by full-ref equality), and the
  `ordinal >= desired` half never being checked - both FIXED. The open action
  recorded at `BUILD-SPEC-P22.md:276-280` is therefore discharged. One
  correction P23 inherits: that same passage says "re-run `t_p22_scaledown`
  green (6/6)", but the exe registers **SEVEN** Alcotest cases
  (`t_p22_scaledown.ml:616/:621/:629/:632/:634/:636/:641`, counted this pass).
  The 6/6 figure is stale; use 7/7.
- **Every state count, gate count and per-member `interesting` figure in this
  document is UNMEASURED until section 8 lands.** Section 4's numbers are
  predictions, not measurements.

## 8. MEASURED

Stage B, 2026-07-30, one machine, one pass. Everything below was produced by a
THROWAWAY probe (`probe/zz_p23_measure.ml`, `probe/zz_p23_bn0.ml`,
`probe/zz_p23_mech.ml` plus `probe/dune` carrying
`(copy_files# (files ../test/p*_witness.ml))` so the probe reads the witness
chain). The probe directory was DELETED after the numbers were read off, and
the tree was verified clean of it. No number below is committed as a pin yet;
committing them is the t_p23_* stage (section 8.8 lists what that leaves
UNMEASURED).

Commands, verbatim:

```
eval $(opam env --switch=anvil-ocaml --set-switch) && \
  dune build probe/zz_p23_measure.exe probe/zz_p23_bn0.exe probe/zz_p23_mech.exe
./_build/default/probe/zz_p23_measure.exe     # 8.1, 8.2, 8.6
./_build/default/probe/zz_p23_bn0.exe         # 8.4
./_build/default/probe/zz_p23_mech.exe        # 8.3 mechanism, 8.5 second level
eval $(opam env --switch=anvil-ocaml --set-switch) && dune build @runtest
```

The per-member counts come from the REPLICA technique
(`t_p21_guarantee.ml:193-237`): the same seed / bound / budget / depth through
`Fc.faulted_successors`, with `Mc.states_seen` on the replica asserted equal to
the leg's own `states` before any count is read. That equality held on all five
graphs (the `replica_states_seen` column below equals the `states` column).

### 8.1 The four shipped legs, MEASURED (zero budget FIRST)

`Fc.check_local_binding_under_faults ~depth:40 bound budget ~desired:1
~ordinals:[1]`, `bound = P23_witness.p23_bound ~desireds:[1]` (identical to
`P22_witness.p22_bound`, no widening).

| leg | budget | outcome | violated | decisive | states | gate | L1 int | L2 int | L1 red | L2 red |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BL0 | zero | CLEAN | `<none>` | true | **88** | **68** | **52** | **16** | 0 | 0 |
| BLc | crash | CLEAN | `<none>` | true | **808** | **560** | **516** | **112** | 0 | 0 |
| BLd | drop | CLEAN | `<none>` | true | **1144** | **816** | **664** | **288** | 0 | 0 |
| BLm | monkey | CLEAN | `<none>` | true | **10216** | **7920** | **1560**\* | | 0 | 0 |

\* the BLm row split out so the table stays readable: BLm L1 `interesting` =
**6496**, BLm L2 `interesting` = **1560**.

Premise-side counters, same replicas:

| leg | reconcile present | decoded | decode FAIL | needed slot Some | condemned non-empty | pvcs non-empty | at `After_list_pod` | ...with pending req | ...pending req IS the pod list |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BL0 | 76 | 76 | **0** | **20** | 32 | **0** | 16 | 16 | 16 |
| BLc | 680 | 680 | **0** | **200** | 456 | **0** | 112 | 112 | 112 |
| BLd | 1056 | 1056 | **0** | **208** | 520 | **0** | 288 | 288 | 288 |
| BLm | 8872 | 8872 | **0** | **3616** | 3136 | **0** | 1560 | 1560 | 1560 |

Wall time (`Unix.gettimeofday` around each call; whole-probe `real` from
`/usr/bin/time -p`): BL0 leg 0.04 s / replica 0.01 s; BLc 0.19 s / 0.12 s;
BLd 0.25 s / 0.15 s; BLm 12.10 s / 11.07 s. The whole measure probe, which
ALSO re-runs P22's four legs and re-explores the five P13-P21 graphs, is
**37.76 s real**. BLm is 92 percent of it.

**Gate decomposition on BL0, MEASURED** (`zz_p23_mech.exe`): L1 only 52, L2
only 16, BOTH **0**, union **68** = the leg's own `gate_states`. The two
premises are DISJOINT on that graph, and the mechanism is visible in the port:
at `After_list_pod` the partition has not run yet, so `needed` and `condemned`
are both empty and L1's witness is false exactly where L2's is true. This is
the P23 analogue of P21's "G1 dominates the union gate" disclosure, except that
here neither member dominates: the gate is a clean sum.

### 8.2 PIN RE-VERIFICATION (prediction 2), all thirteen numbers

Two independent checks, both green.

(1) The direct observed-vs-expected dump from `zz_p23_measure.exe`, verbatim:

```
P22 SL0 states (88)                    expected 88       observed 88       OK
P22 SLc states (808)                   expected 808      observed 808      OK
P22 SLd states (1144)                  expected 1144     observed 1144     OK
P22 SLm states (10216)                 expected 10216    observed 10216    OK
P22 SL0 gate (20)                      expected 20       observed 20       OK
P22 SLc gate (276)                     expected 276      observed 276      OK
P22 SLd gate (96)                      expected 96       observed 96       OK
P22 SLm gate (2080)                    expected 2080     observed 2080     OK
P13-P21 L0 (76)                        expected 76       observed 76       OK
P13-P21 Lc (464)                       expected 464      observed 464      OK
P13-P21 Ld (744)                       expected 744      observed 744      OK
P13-P21 Lm (1976)                      expected 1976     observed 1976     OK
P13-P21 L0v (116)                      expected 116      observed 116      OK
```

(2) The shipped battery: `dune build @runtest` re-explores every committed
graph and asserts observed == pinned (`t_p21_guarantee`'s `pin_safety` case,
`t_p22_scaledown`'s four `legs` cases). Exit 0, 76 executables reporting
"Test Successful", zero FAIL and zero ERROR lines.

**NO PIN MOVED.** 76 / 464 / 744 / 1976 / 116 and 88 / 808 / 1144 / 10216 with
gates 20 / 276 / 96 / 2080 all byte-identical.

### 8.3 VACUITY QUESTION 1, the needed conjunct: prediction 5 is REFUTED

**Prediction 5 said L1's needed witness count is EXACTLY 0 on
BL0/BLc/BLd/BLm. It is not. MEASURED: 20 / 200 / 208 / 3616.** The needed
conjunct C1 (upstream `:617-622`) is NOT vacuous on the shipped
`~desired:1 ~ordinals:[1]` instantiation. Section 2.1 exclusion 2's conclusion
is wrong and is left standing above, unedited, so the refutation is legible.

The section 2.1 CITES are accurate; the INFERENCE from them is what fails.
`needed` really is written once, at the `After_list_pod` arm, and
`Create_needed` really does only advance `needed_index`. What that argument
misses is that the port RE-RECONCILES: pod-0 is created in one round, and a
LATER round re-lists the pods and `partition_pods` puts the now-existing pod-0
into the `needed` slot as `Some`. MEASURED, not argued (`zz_p23_mech.exe`, BL0):

```
needed_some                        = 20
needed_some AND pod-0 in etcd      = 20
needed_some AND pod-0 NOT in etcd  = 0
pod-0 in etcd (all states)         = 64
pod-0 in etcd AND needed slot None = 36
```

Every one of the 20 witness states has pod-0 in etcd and none lacks it, which
is the round-to-round mechanism and no other. (The 36 states with pod-0 stored
but the slot still `None` are the ones inside the round that created it, which
is precisely the half of the section 2.1 argument that IS true.)

**WHICH 36, and why the witness ALSO pins a 24.** "The needed slot is `None`" is
three different predicates, and the dump above does not say which one it printed,
so `p23_witness.ml` pins all three separately rather than pick one:
`bl0_pod0_in_etcd_no_witness` = **44** (pod-0 stored and L1's needed witness does
not fire, the arithmetic complement of the 20),
`bl0_pod0_in_etcd_decoded_no_witness` = **36** (pod-0 stored, the reconcile at the
CR key EXISTS and DECODES, and the witness still does not fire), and
`bl0_pod0_in_etcd_needed_slot_none` = **24** (the strictest: decoded, the `needed`
list NON-EMPTY, and every slot in it `None`). The printed 36 above is the SECOND
of these, and it is the one this section means. The 24 is a NARROWER predicate on
the same graph, not a moved pin and not a different measurement of the same
quantity: the twelve-state gap is the decoded states whose `needed` list is still
`[]` because the round has not partitioned yet, and the eight-state gap from 36 to
44 is the states holding pod-0 with no ongoing reconcile at all. All three are
asserted against the graph in `t_p23_local_binding.ml:766-787` and all three are
green.

The second half of prediction 5 (L1's condemned witness count > 0 on BL0) is
CONFIRMED: 32 states on BL0, 456 / 520 / 3136 on BLc / BLd / BLm.

**VERDICT: SHIP the needed conjunct as written. No exclusion, no pin, no
de-vacuizer required.** The `~ordinals:[0;1]` de-vacuizer of section 2.1
exclusion 2 was conditional on a vacuity that does not exist, so its
precondition is gone. It was measured anyway (8.4) rather than dropped
unmeasured, because prediction 7 is a numbered prediction and because a
measured "not needed" is worth more than an inferred one.

### 8.4 BN0, the de-vacuizer, MEASURED (prediction 7)

`~desired:1 ~ordinals:[0;1]`, zero budget, `require_fault:false`, same bound
and depth.

**The disclosed hazard, MEASURED first.** The shipped seed-integrity predicate
`Scenario.vsts_seed_pods_intact` returns **false** on the BN0 seed at
`~ordinals:[0;1]` and **true** on the SAME seed at `~ordinals:[1]`. That
isolates the failure to ordinal 0 and confirms section 7's reading exactly: the
predicate requires every requested ordinal to be `>= replicas`, so it is
INAPPLICABLE at ordinal 0, not violated by a bad seed. BN0 was therefore given
its OWN integrity check (the same conjuncts MINUS `ord >= replicas`: present at
the canonical ref, exactly one owner reference equal on every field to the live
CR's controller owner ref, name round-tripping through `get_ordinal`). It
passes for BOTH pods: pod-0 admitted = true, pod-1 admitted = true.

**Convergence and boundedness, MEASURED by a depth sweep** (so a blow-up would
be seen growing rather than hanging):

```
depth  5 -> 16 states     depth 25 -> 88 states
depth 10 -> 36 states     depth 30 -> 88 states
depth 15 -> 53 states     depth 35 -> 88 states
depth 20 -> 72 states     depth 40 -> 88 states
```

Fixpoint at depth 25, well inside the depth-40 horizon. The leg: CLEAN,
`violated` = `<none>`, decisive, **88 states**, **gate 68**, L1 `interesting`
52, L2 `interesting` 16, both reds 0, decode failures 0, pvcs non-empty 0, and
**needed slot Some in 52 states** (up from BL0's 20, which is what the
instantiation was designed to do).

Prediction 7 is CONFIRMED and then some: it predicted "within one order of
magnitude of BL0"; the measurement is EQUAL to BL0 at 88. Recorded as an
observation, not sold as significance: the two graphs are different (different
seeds, and the needed-witness counts differ 20 vs 52), the sizes merely
coincide, and nothing in this phase depends on the coincidence.

**BN0 IS NOT SHIPPED AS A LEG.** Its only purpose was to de-vacuize a conjunct
that 8.3 measures live. Shipping a fifth graph to fix a non-problem would add a
pin and a seed-integrity obligation for no assurance. `p23_needed_ordinals`
stays in the witness as a recorded, MEASURED shape, and this section is its
result.

### 8.5 VACUITY QUESTION 2, L2's inner ok-List-response quantifier: CONFIRMED

Prediction 6 said the count is > 0 on at least one graph. **MEASURED > 0 on
EVERY graph.** States where the reconcile is parked at `After_list_pod` with a
pending request AND at least one matching ok `List_response` is in flight:

| BL0 | BLc | BLd | BLm | BN0 |
| --- | --- | --- | --- | --- |
| **8** | **60** | **48** | **816** | **8** |

Two supporting measurements, because "the premise fires" is weaker than "the
body is evaluated":

- **The list-request content test holds at every parked state.** The count of
  states at `After_list_pod` whose pending request is a `List_request` for
  `Pod.kind` in the CR's namespace, addressed to the api server, equals the
  count of parked-with-pending states on every graph (16 / 112 / 288 / 1560).
  So upstream `:646-651` is not a filter that happens to pass; it is exercised
  at 100 percent of the states where it can be.
- **The responses carry OBJECTS.** On BL0, all **8** of the 8 states have at
  least one matching ok `List_response` whose `objs` list is NON-EMPTY, so
  `resp_objs_in_namespace` (upstream `:659-661`) is actually applied to real
  objects rather than folding over an empty list.

**VERDICT: DISCLOSE, do not pull.** The conjunct is live. Section 2.1's
alternative (pull it with the count as its pin) does not apply. The numbers
above are what the `.mli` MEASURED block and the t_p23_* pins should carry.

**What the three measurements above do NOT establish, and where that is now
closed.** They establish that the PREMISE fires and that the body runs on real
objects. They do NOT establish that the CONSEQUENT (`resp_objs_in_namespace`,
upstream `:659-661`) can be seen FALSE: it is true at every state of all four
graphs, which is the same statement as "both members red = 0 on every shipped
graph", so no count in this section can move under a weakening of it. That gap
is closed at UNIT level by matrix row **MB9** (`t_p23_mutation`'s
`mb9_inner_consequent`, section 8.10), not by anything on a graph.

### 8.6 THE PVCS PIN (D): it holds

Every decoded ongoing state on every P23 graph has `pvcs = []`. The count of
decoded states with a NON-EMPTY `pvcs` is **0 / 0 / 0 / 0 / 0** on
BL0 / BLc / BLd / BLm / BN0, against **76 / 680 / 1056 / 8872 / 76** decoded
states respectively. The pin is therefore not vacuous for want of decoded
states: there are 10684 decoded states across the four shipped graphs and none
has a PVC. Section 2.1 exclusion 1 is behavior-free as claimed.

What is NOT yet done: the pin is an in-test assertion in the t_p23_* stage, and
its RED capability (matrix row MB7, `~vct:true`) is UNMEASURED. Until MB7 runs,
"excluded with a pin" is a pin that has never been seen to redden.

### 8.7 THE PREDICTION LEDGER, one for one

1. **PHASE GATE, L2 `interesting` > 0 on BL0. CONFIRMED.** 16 on BL0 (and
   112 / 288 / 1560 on the fault legs). The phase does not stop.
2. **PIN REPRODUCTION. CONFIRMED.** All thirteen numbers byte-identical (8.2).
3. **All legs CLEAN and DECISIVE, red = 0. CONFIRMED.** Four legs plus BN0,
   every one `No_counterexample` with `decisive = true`, `violated = <none>`,
   and per-member red counts of 0 for BOTH members on ALL five graphs. The
   attribution caveat was not exercised, because nothing was red; it stays a
   disclosed hazard, not a measurement.
4. **DECODE FAILURES = 0 on every P23 graph. CONFIRMED.** 0 / 0 / 0 / 0 / 0
   against 76 / 680 / 1056 / 8872 / 76 decoded states. The `~error:true` fold
   is never exercised, exactly as predicted, which is what makes matrix row
   MB6 a real control rather than a formality.
5. **L1's needed witness count EXACTLY 0. REFUTED.** 20 / 200 / 208 / 3616.
   Section 8.3 states the refutation and its measured mechanism plainly and
   the wrong reasoning is left in section 2.1 unedited. The clause's second
   half (condemned witness > 0 on BL0) is CONFIRMED at 32.
6. **L2's inner ok-List-response premise > 0 on at least one graph.
   CONFIRMED**, on all five (8 / 60 / 48 / 816 / 8), with the responses
   measured to carry objects.
7. **BN0 converges and stays within one order of magnitude of BL0. CONFIRMED.**
   Fixpoint at depth 25, 88 states, equal to BL0 (8.4).
8. **BL0/BLc/BLd/BLm state counts equal 88 / 808 / 1144 / 10216 EXACTLY.
   CONFIRMED.** Family-blindness holds as argued in section 3.
9. **The four P23 gate counts are UNPREDICTED.** Now MEASURED:
   **68 / 560 / 816 / 7920**. As section 4 said, they are not derivable from
   P22's 20 / 276 / 96 / 2080; observe that they are far LARGER, which is the
   binding family's premises being cheaper to satisfy than G1-G4's, not a
   stronger register.
10. **Wall time, NON-BINDING. MEASURED once, not extrapolated.** 37.76 s real
    for the whole measure probe (four legs, four replicas, P22's four legs
    re-run, five P13-P21 replicas); 0.45 s real for the BN0 probe including its
    eight-point depth sweep. BLm dominates at 12.10 s leg plus 11.07 s replica.
    Same order as P22's ~67 s aggregate, as predicted.

### 8.8 STILL UNMEASURED, named rather than omitted

- **The whole mutation matrix, MB1 through MB8 (section 5).** Not one row has
  been run. Every green in 8.1 is therefore a green whose RED CAPABILITY is
  unproven, which is the weakest part of this phase as it stands. In
  particular MB1 (the headline row that is the only thing earning L2 its keep),
  MB2 (whether L1 can be seen red at all, and section 7 says a failure there
  forces L1 down to EXCLUDE-WITH-A-PIN), MB7 (the pvcs pin's red capability)
  and MB8 (the bare-source trap) are all open.
- **The t_p23_* tests.** `t_p23_binding.ml`, `t_p23_mutation.ml`,
  `t_p23_regression.ml` are not written; `test/dune (names)` is still 76.
  Nothing in 8.1 through 8.6 is committed as a pin yet, so nothing here is
  protected against drift by the battery.
- **The `test/p23_witness.ml` MEASURED block** is still empty on purpose. The
  numbers that go in it are 8.1's states / gates / per-member counts, 8.3's
  needed and condemned witness counts, 8.5's ok-List-response counts, 8.6's
  zero, and 8.1's decode-failure zero.
- **The E-ledger re-partition edits** (`p21_witness.ml`,
  `t_p21_regression.ml`, section 6). Not applied. Consequence, restated
  because it is exactly the vacuous-green shape this project keeps producing:
  `t_p21_regression`'s reversal clause at `:385-396` is GREEN TODAY while L1
  and L2 are shipped, because its roster is a literal thirteen-suite list that
  does not sweep the new family. That green means nothing and must not be
  read as the ledger agreeing.
- **The `.mli` MEASURED blocks** in `local_binding.mli` and
  `fault_check.mli` still say the counts are unmeasured. They are now
  measured; updating that prose is part of the t_p23_* stage.
- **Per-member red attribution under a real red** (matrix row MB3). Nothing
  was red, so the containment consequence is still an argument, not a
  measurement.

### 8.9 DRIFT AND CORRECTIONS RECORDED

- **No cite in sections 0 through 7 was found wrong against the tree in this
  stage, and no section 0 through 7 text was edited.** The one factual claim
  now known false is section 2.1 exclusion 2's VACUITY CONCLUSION (not its
  cites), refuted in 8.3 and deliberately left in place.
- **MB6's instructions no longer match the code and must be reworded before
  that row is run** (carried forward from the build stage). Section 5 MB6 says
  "flip L1's decode fold from `~error:(fun _ -> true)` to
  `~error:(fun _ -> false)`". That literal text does not appear, because the
  lookup/decode skeleton is factored into one private helper
  `at_reconcile ~controller_id ~cr_key ~absent ~undecodable ~decoded`. The
  equivalent single-token mutant is flipping `~undecodable:true` to
  `~undecodable:false` on L1's `holds` line in `binding_family`
  (`local_binding.ml:311`). Still one site, still one Edit.
- **Section 7's "the needed conjunct is vacuous on the shipped instantiation
  and its fix is risky" is now WRONG on both halves.** It is not vacuous
  (8.3), and the fix was measured cheap and convergent rather than risky
  (8.4). Left unedited above; recorded here.

### 8.10 THE MUTATION MATRIX, RUN

Stage C, 2026-07-30, same machine. Every source mutant was a MANUAL Edit apply
/ Edit revert (never `git checkout --`, the tree being uncommitted), with a
residue scan after each row. No row below was killed by a build error or by a
timeout: every KILLED cell names an assertion that was SEEN to fail with an
Expected/Received pair, and every SURVIVED cell was SEEN green.

Per-member attribution never rides the leg's own `violated` name (which is
first-in-list-order and would name L1 for anything shared). It comes from a
THROWAWAY probe `probe/zz_mb.ml` running the REPLICA technique
(`t_p21_guarantee.ml:193-237`) over the leg's own graph, reporting `interesting`,
`red` (= `interesting && not holds`) and `nholds` (= `not holds`, UNGATED)
per member. The probe directory was deleted afterwards and the tree verified
clean of it.

| id | mutation (file:line, before -> after) | outcome | caught by |
| --- | --- | --- | --- |
| MB1 | `v_stateful_set_reconciler.ml:531` `{ kind = Pod.kind; namespace }` -> `namespace = namespace ^ "-mb1"` | **KILLED** | `t_p23_local_binding` legs, `"BL0: outcome CLEAN"` true/false; leg REFUTED naming L2 |
| MB2-a | `v_stateful_set_reconciler.ml:411` `Option.map (fun o -> (o, p)) (get_ordinal parent n)` -> `Some (Option.value ~default:99 (get_ordinal parent n), p)` | **SURVIVED** | nothing; 11/11 green, every pin byte-identical |
| MB2-b | MB2-a **plus** `:376` `pod_name parent ordinal` -> `... ^ "-mb2"` **plus** `:430-432` the name-parse conjunct of `pod_filter` -> a trivially-true test | **KILLED** | `"BL0: outcome CLEAN"`; and independently `t_p23_mutation` `red_capability`, `"control: a genuine make_pod condemned entry HOLDS for L1"` |
| MB3 | the MB2-b mutant, attribution read off | **MEASURED** | not an assertion; the containment datum below |
| MB4 | `v_stateful_set_reconciler.ml:737` `{ kind = Pod.kind; name; namespace }` -> `namespace = namespace ^ "-mb4"` | **TRAP HELD** (L2 stayed green) | L2 red 0 on BL0/BLc; the suite reds elsewhere, on the graph-size pin |
| MB5 | `t_p23_mutation.ml:626` `controller_id + 1` -> `controller_id + 0` | **KILLED** | `"...interesting = 0 over ALL of BL0 at controller_id + 1"`, 0 vs 52 |
| MB6 | `local_binding.ml:311` `~undecodable:true` -> `~undecodable:false` | **SURVIVED at graph level, then KILLED at unit level** | nothing on any graph; then `t_p23_mutation` `"MB6: L1 HOLDS on an undecodable local state"`, true/false |
| MB7 | `t_p23_mutation.ml:741` `~vct:true` -> `~vct:false` | **KILLED** | `"MB7: the PVCS-ARE-EMPTY PIN REDDENS on a vct:true seed"`, true/false |
| MB8 | `local_binding.ml:297` and `:309` both `...rs:613` -> `...rs:613 (needed+condemned only)` | **KILLED x4** | `t_p21_regression` BARE-SOURCE FIREWALL 6 vs 5; `t_p23_regression` (name, source) pairs; `t_p23_mutation` MB8 parse count 2 vs 1; and `t_p21_regression.ml:465-471`, the RESHAPED positive committed-literals row, `Expected: [613; 640] / Received: [640]` (the first three measured in the matrix run, the fourth in the review-fix pass - see the MB8 paragraph below) |
| MB9 | `local_binding.ml:211` `Option.equal String.equal om.namespace (Some namespace)` -> `Option.is_some om.namespace` (L2's inner-forall CONSEQUENT, upstream `:659-661`) | **KILLED at unit level** (survives every graph, by construction) | `t_p23_mutation` `mb9_inner_consequent`, `"MB9: L2 is RED on an in-flight ok List_response whose object is OUTSIDE the CR's namespace"`, `Expected: false / Received: true` |
| X1 | `local_binding.ml:329` `&& step_binding ...` -> `&& not (step_binding ...)` (L2's UNIQUE conjunct) | **KILLED** | `"BL0: outcome CLEAN"`; leg REFUTED naming L2, **graph pins UNMOVED** |
| X2 | `local_binding.ml:313` `bound_in_local_state ...` -> `not (bound_in_local_state ...)` (inside L1's `~decoded`) | **KILLED** | `"BL0: outcome CLEAN"`; leg REFUTED naming L1, **graph pins UNMOVED** |
| X3 | `local_binding.ml:99-100`, the two conjuncts of `pod_bound` SWAPPED | **SURVIVED, as required** | nothing: 11 + 7 + 6 + 6 tests green, every pin byte-identical |

**MB1, the headline, and its control.** BL0 flips CLEAN -> REFUTED and
`violated` names L2 (`vsts_local_pods_and_pvcs_bound_with_key`), exactly as
section 5 predicted. Replica attribution on BL0: L1 `interesting` 0, red 0;
L2 `interesting` 16, red 16 (BLc: L2 80/80). L1 goes out of premise rather than
green, because a list scoped to a foreign namespace comes back empty and
`partition_pods` never populates `needed`/`condemned`. The graph also moves
(BL0 88 -> 76, BLc 808 -> 424), so the suite would have reddened on the state
pin anyway; the attribution above is what shows the red is L2's.

The control was run and it **holds, with one correction**. Under the SAME
mutant, `t_p21_guarantee`'s L0/Lc/Ld/Lm legs each PASSED `outcome CLEAN` and
`violated = None`: the P21 register does NOT see a wrong-namespace pod list, so
"only L2 sees it" stands. What the P21 and P22 batteries do red on is
premise-VACUITY floors and graph-size pins (`"L0: G3 premise fires somewhere"`,
`"SL0: G2 premise fires somewhere"`, `pin safety Lc = 464` vs 424) - never a
guarantee violation. The honest form of the claim is therefore: a wrong-namespace
list is invisible to G1-G4 **as a red**, while still perturbing their graphs.

**MB2: L1 CAN be seen red, and section 5's MB2 recipe is wrong about how.**
Section 5 names ONE site (`partition_pods:411`) plus a `monkey_forge` pod. Run
as written it SURVIVES, and the mechanism is in the tree: `condemned` is built
from `filtered`, and `pod_filter` (`:421-432`) ALREADY requires `get_ordinal` to
parse, so the defaulted-ordinal branch is unreachable and the decoupling does
not decouple. THREE coordinated sites are needed - make the reconciler mint an
unparseable pod name, stop `pod_filter` rejecting it, and stop `partition_pods`
dropping it - and no `monkey_forge` entry is needed at all. With those three,
BL0 goes REFUTED naming L1 with L1 red = 32.

**The consequence for section 7 is a partial retraction.** "L1 is close to a
theorem of the port" survives as a statement of how hard L1 is to falsify (it
took three coordinated source edits, and the shipped seed pods are built from
`pod_name` directly at `scenario.ml:459`, not through `make_pod`, so seed
integrity is untouched). But the conditional in section 5 MB2 - "if it cannot be
SEEN red, L1 is a green that never fires and MUST be downgraded to
EXCLUDE-WITH-A-PIN" - is **NOT triggered**. L1 has been seen red. It ships as a
member.

**MB3, the containment consequence, now MEASURED rather than argued.** Under
the MB2-b mutant on BL0: L1 `interesting` 64, red 32, `nholds` 32; L2
`interesting` 16, red 0, `nholds` **32**. So L2's `holds` is false at exactly the
same 32 states - the containment (L2 implies L1) is confirmed on live states -
yet L2 reports NOTHING in either the leg's `violated` (first-in-list-order names
L1) or the replica's red column (L2 is out of premise at those states, its 16
premise states being the `After_list_pod` ones). The disclosed hazard in
`local_binding.mli` is accurate and is now a measurement: **only the ungated
`holds` column shows L2 false too.**

**MB4, the trap, HELD - and section 5's MB4 control claim is corrected.** L2 red
= 0 on BL0 and BLc, leg CLEAN, `violated = <none>`: a wrong-namespace
`Get_then_delete` is not an L2 red, so "a red anywhere is not L2 coverage" is
measured, not asserted. Section 5 predicted "while the P21 register reds" - it
does not: `t_p21_guarantee` is entirely GREEN under MB4. It is P22's G2
premise-vacuity floor that moves, plus P23's own graph-size pin (BL0 88 -> 100).

**MB6 was SURVIVED-AS-PREDICTED, and the gap is CLOSED rather than disclosed.**
The row is the reworded one from 8.9 (`~undecodable:true` -> `false` at
`local_binding.ml:311`, not the `~error:` text of section 5). It changes nothing
on any of the four graphs - 11/11 green, all states and gates byte-identical -
because prediction 4's zero makes that fold dead code, and a mutation of dead
code cannot be killed by a graph assertion however exact. Rather than leave it
as a disclosed dead branch, `t_p23_mutation.ml` gained a case
`mb6_decode_failure_fold` that supplies the input the graphs never produce: an
ongoing reconcile installed at the CR key whose `local_state` is a `Value.t`
that `V_stateful_set_pack.unmarshal_state` REJECTS. Two controls run first (the
injection landed AND the store really is undecodable; the well-formed twin
really does decode), then the row asserts both members `holds` and neither is
`interesting`. Re-run under the same mutant, that row FAILS true/false. MB6 is
now a killable row.

**MB7 retires 8.6's caveat.** The pvcs-are-empty pin was already automated on a
throwaway `~vct:true` seed and passing. Flipping that seed to `~vct:false` makes
the assertion fail (true/false), which is the evidence that the assertion is
sensitive to `volume_claim_templates` and nothing else. "Excluded with a pin"
now means excluded-and-watched: the pin HAS been seen to redden.

**MB8: the firewall is not blind, and the positive clause had to be reshaped
before it counted.** Qualifying L1's source string kills three assertions in the
matrix run itself: `t_p21_regression`'s BARE-SOURCE FIREWALL count
(`Expected 6 / Received 5`), `t_p23_regression`'s (name, source) pairs row, and
`t_p23_mutation`'s MB8 parse count (2 vs 1). It did **not** kill the positive
row section 5 demanded, and the reason is worth recording: as first written,
that row took its EXPECTED value from
`List.filter_map line_of_source Lb.binding_sources` - the same expression it
tested - so the qualifier dropped `:613` from both sides at once and the row
compared `[640]` with `[640]` and passed. Measured, under the MB8 mutant with
that row moved ahead of the firewall so it could report: the self-derived form
logs `ASSERT` and PASSES while only the firewall reds. The row is now written
against the COMMITTED LITERALS `[613; 640]`
(`t_p21_regression.ml:465-471`, ordered ahead of the count firewall so the first
failure names the member that went invisible), and under the same mutant it
FAILS `Expected: [613; 640] / Received: [640]`. So MB8 kills **four**
independent assertions, the positive one among them (`:613` and `:640` PRESENT
in `roster_guarantee_lines`, not merely no excluded line shipped). The matrix row
above names all four and marks which pass measured which: three in the matrix run
itself, the reshaped positive row in the review-fix pass.

**MB9 is a row this matrix did not originally have, and its absence was a real
hole.** The four-lens review of this phase found that L2's inner-forall
CONSEQUENT (`resp_objs_in_namespace`, `local_binding.ml:206-212`, upstream
`:659-661`) was targeted by NO row at all, and that no row could reach it: 8.5's
`8 / 60 / 48 / 816` establishes that the PREMISE fires and that the body runs on
real objects, but the consequent is TRUE at every state of all four graphs -
which is exactly the content of "both members red = 0 on every shipped graph" -
so no graph assertion can move under a weakening of it. Nor could any forged row
reach it: `t_p23_mutation`'s `forge` sets only `pending_req_msg` and
`local_state` and never puts a response on the wire, so `ok_list_resps_for`
returns `[]` on every forged state and `List.for_all` over `[]` is vacuously
true. Weakening `:211` to `Option.is_some om.namespace` therefore moved NOTHING
in the phase as it stood.

The row now exists. `mb9_inner_consequent` forges an in-flight ok
`List_response` **formed FROM the parked pending request** through
`Message.form_list_resp_msg` - so upstream `:655` (api-server source) and `:656`
(`resp_msg_matches_req_msg`) hold by construction rather than by a hand-typed
rpc id - carrying one `Dynamic_object`, the reconciler's own `make_pod` payload
marshalled, whose `metadata.namespace` is not the CR's. Four controls run FIRST,
because the failure mode being fixed is precisely a vacuous green: the ongoing
reconcile landed and decodes; **exactly one** matching ok `List_response` is
selected by the `:652-657` premise on BOTH states; the same parked shape with NO
response selects **zero** (the vacuity, exhibited); and the selected response
carries exactly one object in the intended namespace. Only then is L2 read: RED
on the foreign namespace, and GREEN on the negative control carrying the CR's
own namespace, which is what makes the red attributable to `:659-661` rather
than to a malformed forgery. L1 is asserted GREEN on both, so the containment is
not what fired.

Confirmed by mutation, per the house rule: under the `:211` weakening the row
fails `Expected: false / Received: true` with every one of its controls having
PASSED first (the log shows eight `ASSERT` lines before the `FAIL`), and no
other case in the battery moves. The mutant was reverted by writing back the
saved pre-mutation bytes, verified by SHA-256 equality with the pre-mutation
copy; `t_p23_local_binding` was then re-run from a forced rebuild (38.4s, a real
re-exploration, not a cached result) with all eleven cases green and every pin
byte-identical, and `t_p23_regression` likewise. **MB9's state is
reachable-by-forgery only** - no shipped leg's api server answers a namespaced
list with an out-of-namespace object - and it is labelled that way in the file
rather than sold as a graph-level row.

**X3, the over-pinning control, is the row that says the suite is not brittle.**
A semantically neutral edit - swapping two pure, total conjuncts of `pod_bound`
- leaves all four suites green with every pin byte-identical. A suite that
reddened here would be pinned on syntax rather than behaviour.

**METHOD FINDING, recorded because it nearly produced a false KILL.** In one
pass the runner's build list was silently emptied (an `sd` replacement string
containing `$EXES` was parsed by `sd` as a capture-group reference and expanded
to nothing, so only the probe was rebuilt). The stale `t_p23_local_binding.exe`
then reported BL0 = 100 - the PREVIOUS row's number - which reads exactly like
"MB6 kills the legs". It was caught only because the probe, rebuilt in the same
invocation, printed 88 in the same log. Two mitigations now stand in the driver:
every source is `touch`ed before the build, and a canary whose numbers must
agree with the suite's is run in the same invocation. **The house rule that a
mutated run and a restored run giving the same exit code means nothing rebuilt
has a mirror image: a mutated run giving a DIFFERENT number can also mean
nothing rebuilt.**

**RESTORE PROOF.** Every mutant was reverted by writing back the saved
pre-mutation bytes. `git diff --stat` lists only the five tracked files this
phase already touched (`fault_check.ml`, `fault_check.mli`, `test/dune`,
`p21_witness.ml`, `t_p21_regression.ml`); `v_stateful_set_reconciler.ml` is
byte-identical to `HEAD`, and the untracked `local_binding.ml` was re-verified
line by line (bare sources at `:297`/`:309`, `~undecodable:true` at `:311`/`:324`,
no negation of `bound_in_local_state` or `step_binding`, conjunct order at
`:99-100`). The battery was then re-run and all thirteen committed pins
re-verified; the result is in 8.11.

### 8.11 RESTORE PROOF AND PIN RE-VERIFICATION AFTER THE MATRIX

```
eval $(opam env --switch=anvil-ocaml --set-switch)
touch lib/**/*.ml lib/**/*.mli test/*.ml
dune build @runtest                      # EXIT 0
./_build/default/test/<each>.exe         # force-run, nine pin-bearing exes
```

`dune build @runtest` alone proves NOTHING here and is recorded as such: it is
digest-cached, and on the matrix-restore pass it re-ran exactly ONE suite
(`p23_mutation`, 7 cases at that point, the only source that had changed since
the previous green). The proof is the force-run, which cannot be served from a
verdict cache. The table below is the force-run as the phase SHIPS, re-measured
after the section 9 review fixes and the reconciliation pass that followed them,
so `t_p23_mutation` reports the 8 cases it now has:

| exe | tests | time | exit |
| --- | --- | --- | --- |
| `t_p23_local_binding` | 11 | 31.4 s | 0 |
| `t_p23_mutation` | 8 | 0.03 s | 0 |
| `t_p23_regression` | 6 | 0.00 s | 0 |
| `t_p21_guarantee` | 9 | 1.9 s | 0 |
| `t_p21_regression` | 6 | 0.00 s | 0 |
| `t_p21_mutation` | 6 | 0.00 s | 0 |
| `t_p22_scaledown` | 7 | 29.9 s | 0 |
| `t_p22_mutation` | 4 | 0.01 s | 0 |
| `t_p22_regression` | 4 | 0.00 s | 0 |

Zero FAIL and zero ERROR lines across the whole log. Each of the thirteen
committed numbers is an in-exe `check int` inside those runs, and a mismatch is
the only way these exes go non-zero:

- **P13-P21, re-EXPLORED twice** (`t_p21_guarantee` `pin_safety` and
  `t_p23_local_binding` `pin_safety`): L0 **76**, Lc **464**, Ld **744**,
  Lm **1976**, L0v **116**.
- **P22, re-MEASURED** (`t_p22_scaledown` legs) and re-asserted by the four P23
  legs, which reuse P22's seed/bound/budget/depth exactly: states
  **88 / 808 / 1144 / 10216**, gates **20 / 276 / 96 / 2080**.

**NO PIN MOVED.** All thirteen byte-identical. The P23 numbers of 8.1 are
likewise unmoved: gates **68 / 560 / 816 / 7920**, L1 `interesting`
**52 / 516 / 664 / 6496**, L2 `interesting` **16 / 112 / 288 / 1560**, both reds
**0** everywhere.

`t_p23_mutation` was **7** cases at the end of the matrix run (was 6): the case
added there is `mb6_decode_failure_fold`. It is **8** as the phase ships, the
review fixes of section 9 having added `mb9_inner_consequent`; the table above
records the shipped 8, re-measured in the reconciliation pass of section 9. No
other test count changed, and `test/dune (names)` stays at 79.

**WHAT THIS SECTION CLOSES IN 8.8.** The whole matrix is now run. The remaining
8.8 entries (the t_p23_* tests, the witness MEASURED block, the E-ledger
re-partition edits) were closed by the preceding stage. One thing 8.8 asked for
is deliberately NOT done: no `monkey_forge` leg was added, because MB2-b reached
L1 without one.

## 9. REVIEW

The review wave has RUN, in two passes over the staged phase.

**Pass 1, `ctxcat-review`, 3 lenses over a 209k-token staged bundle: 1 finding.**
It is a style nit - near-duplicate helpers in `t_p23_local_binding.ml` - and it is
NOT fixed, because it is a preference about factoring and not a defect. Recorded
here so that "one finding, unfixed" is legible rather than absent.

**Pass 2, a 4-lens opus adversarial pass (vacuity / overclaim / attribution /
ocaml) plus an adversarial judge: 27 raw findings, 7 CONFIRMED.** The judge
dropped or merged the other 20. **All seven are FIXED.**

1. `p23_witness.ml`'s STILL-UNMEASURED ledger kept live a rule to DOWNGRADE L1 to
   EXCLUDE-WITH-A-PIN, which 8.10 had already measured NOT triggered (L1 was seen
   red by MB2-b).
2. That same module's STATUS header denied that anything below it was measured,
   while the block below it was the stage B / stage C measurement.
3. `t_p23_mutation.ml`'s matrix header labelled RUN rows as UNRUN, and handed the
   MB2 recipe forward as if it worked, when the matrix had measured that recipe
   NON-FUNCTIONAL (one site, not the three that are needed).
4. `local_binding.mli` and `fault_check.mli` carried four claims that the pins
   committed in the SAME change refute.
5. L2's inner-forall CONSEQUENT (upstream `:659-661`) had no red-capability row
   anywhere, and no existing row could reach it. FIXED by adding MB9
   (`mb9_inner_consequent`), whose state is REACHABLE-BY-FORGERY ONLY.
6. The positive bare-source assertion in `t_p21_regression` derived its expected
   value from the expression under test, so it could not redden. FIXED by writing
   it against the committed literals `[613; 640]`, and the OLD shape was MEASURED
   to pass under the MB8 mutant rather than merely argued to.
7. A complement row compared three constants to each other and never read the
   graph. FIXED by summing the components against `count r pod0_in_etcd`.

**The generalisation, which is the useful part.** Findings 1-4 have ONE cause:
this pipeline writes PREDICTIONS before the build and MEASUREMENTS after it, and
nothing owned reconciling the two, so prose that was true when written stayed in
the tree after the measurement that falsified it. Findings 6 and 7 are a second,
narrower class: assertions that could not fail. Neither class is exotic and
neither was found by the three generic `ctxcat` lenses.

The evidence for the recommendation is what happened next: the fix pass for those
seven itself introduced SIX further inconsistencies (a stale case count in 8.11, a
kill count that disagreed across three files, a matrix-run block that omitted MB9
and still said L2's red capability rested on MB1 alone, three drifted line cites,
an ambiguous 36 vs 24, and this placeholder section), and they needed exactly the
same reconciliation to catch. Fixing prose MOVES prose.

**RECOMMEND for P24.** (a) A standing RECONCILIATION stage after measurement,
owning the sweep of every prose claim against the pins and cites as they then
stand, and re-run after any fix pass that edits prose. (b) A dedicated OVERCLAIM
lens in the review wave, because the three generic `ctxcat` lenses found none of
these seven.

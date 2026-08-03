# BUILD-SPEC-P25: E3 ships, :256 excluded on the SCOPE ground, the vct:true occupancy pin, and the reconciliation riders (`internal_rely_guarantee.rs:606` + the P24 §2.3.1 gate answer)

## 0. Phase identity, bounds, and the P24 gate answer

Repo: `~/Documents/anvil-ocaml` @ `99786d1` (P24 committed). Tree CLEAN, baseline
`@runtest` RC=0, **82 exes** (RULING-P25-SELECTION.md:3; exe count RE-MEASURED this
session: `rg -o 't_\w+' test/dune | sort -u | wc -l` = 82). Upstream reference:
`~/Documents/anvil-ref`.

Selection: wave `wf_7a293cd4-606`, 2026-08-02, 8 agents, 0 errors
(`~/Documents/anvil-ocaml-p25-harness/RULING-P25-SELECTION.md`, backing data
`selection-wave-result.json` + `selection-wave-journal.jsonl` + `probe-*.log`, same dir).
Design wave: 4 settlement agents (settle-e3, settle-blast, settle-256, settle-riders) +
1 adversarial refutation pass, bounds <=7 agents / <=7 findings per agent. Every
CONFIRMED refutation is APPLIED in this text (see §0.4); PLAUSIBLE refutations are
carried inline as **OPEN FLAG** markers, never silently dropped.

**P25 ships four things, NO new top-level module** (RULING:6):

1. **E3 SHIPS** (`internal_rely_guarantee.rs:606`, `local_pods_and_pvcs_are_bound_to_vsts`)
   as a NEW STANDALONE `Invariants.invariant` value in `lib/assurance/internal_guarantee.ml`,
   evaluated over the UNCHANGED committed multi-CR graphs (P12 fair `desireds=[1;1]` rc=3,
   P13 G2 crash rc=2). E-ledger moves 6 shipped/3 excluded -> **7/2**. §1.1, §2, §3.1.
2. **`:256` EXCLUDED** (`local_state_is_coherent_with_etcd`) on the SAME SCOPE ground as
   :116-124, with a fresh superseding pin. §1.2.
3. **vct:true PVC occupancy pin** ships as a new witness pin over L0v (P18's committed
   116-state vct:true graph) + the "seven -> eight" doc fix, C1-GATED. §1.3.
4. **Riders** D1/D2/D3 + the `t_p25_reconcile` 4-leg battery, battery landed AFTER
   D1-D3. §1.4.

### 0.1 The P24 §2.3.1 gate is ANSWERED: branch (b), machinery branch CLOSED, measured

BUILD-SPEC-P24.md's gate (its §2.3.1 / the `state_predicates.mli:667-674` forward
pointer: "Either P25 lands rely-condition machinery ... or it excludes :256 on the same
SCOPE ground") is answered on **branch (b): :256 EXCLUDED**. The rely-machinery branch
(a) is **CLOSED**, not deferred, on measured ground (all numbers
RULING-P25-SELECTION.md:18-27, minted from `probe-coherence-run.log`):

- **100% of pinned fail states are class (d)** - NO write of any kind in flight at the
  failing state: set-eq fails SPc **8/8** d, SPm **72/72** d; coherence fails SPc **4/4** d,
  SPm **40/40** d; classes a=b=c=**0** everywhere. Positive controls reproduced the pinned
  0/8/0/72 and 0/4/0/40 EXACTLY before classification.
- **Over-exclusion complement: 144** SPm states PASS with a rely-violating write in
  flight - a rely guard would be wrong in both directions. Effective premise of a
  rely-scoped restore: **8/60/48/672**.
- Structural ground: an in-flight guard cannot see a write that landed and was consumed
  before the observation state - which is what all 80+44 class-(d) failures are.
  `weakly_eq` STAYS OUT.

### 0.2 Novelty gates, REPAIRED form, measured NOW

MEASURED this session (2026-08-02, HEAD 99786d1, tree clean):

```
rg -n 'internal_rely_guarantee.rs:606' lib test -g '!*.md'   -> exit 1 (0 hits)
rg -n 't_p25_reconcile|p25_witness' lib test -g '!*.md'      -> exit 1 (0 hits)
```

Both gates are CLEAR. Both MUST be re-run immediately before stage A lands (RULING:64-65)
and again at seal. The `-g '!*.md'` exclusion is the REPAIRED form: spec prose citing
:606 (this file does, many times) must not trip the gate.

### 0.3 Measurement discipline (refutation GATE 4, binding)

Only the two novelty gates above were independently re-measured by the design wave (no
build was run; the wave was read-only per HARD RULES). Every other number in this spec is
one of:

- **[RULING]** - carried from RULING-P25-SELECTION.md / the selection-wave probe logs
  (`probe-e3-run-*.log`, `probe-vct-run.log`, `probe-coherence-run.log`,
  `PRE-MUTATION-api_server.ml.bytes`, all in `~/Documents/anvil-ocaml-p25-harness/`).
  These are SELECTION evidence and EXPECTED REPRODUCTION TARGETS only. Stage A/B/C must
  re-derive each one fresh with their own builds
  (`cd ~/Documents/anvil-ocaml && opam exec --switch=anvil-ocaml -- dune ...`, output
  REDIRECTED TO A FILE, never `tail` - `dune` is NOT on PATH and a bare invocation
  through `tail` produces a FAKE GREEN). No number below may be asserted as "measured"
  in committed prose until the phase's own run reproduces it.
- **[MEASURED]** - re-measured fresh by this design wave with `rg`/`Read` (file
  coordinates, list literals, exe counts, gate exits). Marked per claim.
- **[PREDICTION]** - written before the build, per BUILD-SPEC-P24 §4's convention. The
  seal stage carries a reconciliation pass so predictions do not outlive their
  measurement (predictions-before / measurements-after go stale otherwise).

### 0.4 Provenance: the four settlements + the refutation, applied

- **settle-e3**: E3's predicate, landing site, leg, pins, canonical mutant. ADOPTED in
  full - the refutation confirmed it is the only settlement fully compliant with the
  pin freeze.
- **settle-blast**: the blast-radius enumeration. ADOPTED, with its
  "SANCTIONED-CONDITIONAL ... G5 / guarantee_cardinal 4->5 / binding_cardinal 2->3"
  branch **STRUCK** (refutation GATE 1, CONFIRMED): those cardinals are P21/P23 pins
  outside the sanctioned E-ledger re-partition ("Everything else P13-P24 is FROZEN; a
  moved pin is a phase-STOP", RULING:58-62). E3's site is SETTLED, not open. The
  selection probe's ~140-line duplicate-and-extend shape
  (`t_p25_probe_e3.SOURCE.ml`) was a MEASUREMENT ARTIFACT (its own header: temporary,
  deleted before return), not a shipping-shape decision.
- **settle-256**: the :256 superseding pin text, C1 gate upheld + probe spec, C3 upheld
  with the RED-CAPABILITY-PENDING ground, the two-literal pin discipline. ADOPTED in full.
- **settle-riders**: D1/D2/D3 drafts + battery design. ADOPTED, with two corrections:
  (i) its D1 "confirm the exact site against the settle-e3 diff" hedge is RESOLVED
  (site = standalone value in `internal_guarantee.ml`, §1.1); (ii) its "roster currently
  14 entries" count was STALE - the roster has **15** entries [MEASURED:
  t_p21_regression.ml:276-293 and :300-316, read this session]; P25's row is the
  SIXTEENTH.
- **Refutation**: 5 gates. GATE 1 (cardinals frozen, E3 site settled) - applied
  throughout. GATE 2 (t_p23_regression.ml:454-491 is a must-touch) - in §2.1. GATE 3
  (D2/D3 exact swaps) - in §1.4. GATE 4 (re-measurement discipline) - §0.3. GATE 5
  (LEG4 total accessor) - §1.4, carried as OPEN FLAG (PLAUSIBLE, not yet code).
  Low-severity PLAUSIBLE (stale "THIRTEEN" at t_p21_regression.ml:43) - folded into
  §2.1's roster-row edit as an opportunistic sweep.

## 1. Members - SETTLED by the design wave

| member | upstream | verdict | mechanism |
| --- | --- | --- | --- |
| M(E3) | `internal_rely_guarantee.rs:606` | **SHIPS** | standalone `Invariants.invariant` in `internal_guarantee.ml`, ONE new `Local_binding` hook, E-ledger 6/3 -> 7/2 |
| M(:256) | `state_predicates.rs:256` | **EXCLUDED-WITH-A-PIN** (SCOPE ground, same as :116-124) | superseding pin text §1.2 + class-d pins in `p25_witness.ml` |
| M(vct) | the 8 PVC-family M1 conjuncts under vct:true | **witness pin + doc fix ONLY; conjuncts STAY EXCLUDED** | L0v occupancy pins + "seven -> eight" doc fix, C1-GATED (§1.3) |
| Riders | D1/D2/D3 + `t_p25_reconcile` battery | **SHIP, ordered** | D1-D3 first, battery AFTER (§1.4) |

### 1.1 M(E3) - `internal_rely_guarantee.rs:606` (`local_pods_and_pvcs_are_bound_to_vsts`) - SHIPS

Upstream (anvil-ref, quoted by settle-e3 from internal_rely_guarantee.rs:606-611):

```rust
pub open spec fn local_pods_and_pvcs_are_bound_to_vsts(controller_id: int) -> StatePred<ClusterState> {
    |s: ClusterState| {
        forall |k: ObjectRef| #[trigger] s.ongoing_reconciles(controller_id).contains_key(k) && k.kind == VStatefulSetView::kind()
            ==> local_pods_and_pvcs_are_bound_to_vsts_with_key(controller_id, k, s)
    }
}
```

E3 is the LIFT of L2/E5 (:640-664) over every VSTS-kind key of `ongoing_reconciles`,
folded with `Object_ref_map.for_all`, reusing L2's existing
`~absent:true ~undecodable:true` fold. `interesting` is E3's OWN premise mirror
(`Object_ref_map.exists` of a VSTS-kind key), not L2's per-key witness (settle-e3
ruling, cites local_binding.ml:252-259, :319-332; local_binding.mli:227).

**Landing site - SETTLED, not open** (settle-e3 ruling, refutation GATE 1 CONFIRMED):
a NEW STANDALONE value `local_pods_and_pvcs_are_bound_to_vsts : controller_id:int ->
Invariants.invariant` in `lib/assurance/internal_guarantee.ml`, modeled on
`Invariants.unique_reconcile_id_invariant` (invariants.mli:44-49: a controller_id-only
single invariant beside a family).

- **NOT** a 5th `guarantee_family` member: signature mismatch - E3 takes only
  `controller_id` upstream, every G1-G4 member genuinely consumes `~cr`
  (internal_guarantee.mli:197-204 [MEASURED this session]).
- **NOT** a 3rd `binding_family` member.
- Therefore `guarantee_cardinal = 4` (p21_witness.ml:200 [MEASURED]) and
  `binding_cardinal = 2` (p23_witness.ml:149 [MEASURED]) both stay **byte-identical**
  (§2.2 firewall).
- Reuse via **ONE new exported hook** `Local_binding.holds_at_key`, not a third copy of
  L1/L2's ~150-line body. [MEASURED: `rg 'at_reconcile|holds_at_key'` over
  local_binding.mli = 0 hits, confirmed by the refutation - the hook is genuinely new
  and minimal.]

#### local_binding.mli - ADD one export (`binding_sources`/`binding_family` untouched)

```ocaml
val holds_at_key :
  controller_id:int -> cr_key:Common.object_ref -> Cluster.cluster_state -> bool
(** L2's decoded predicate (:640-664, [~absent:true ~undecodable:true] - the same
    borrowed-from-E3 fold local_binding.ml:252-259 already discloses) evaluated at
    an ARBITRARY key, not only the scenario CR's. Exposed so
    {!Internal_guarantee}'s E3 lift can fold it over every VSTS-kind key of
    [Cluster.ongoing_reconciles] without a third copy of L1/L2's body. This is
    the export local_binding.mli:258-259 named in advance: "[Object_ref_map.for_all]
    is deliberately NOT used here: that is E3's lift, which this phase EXCLUDES" -
    P25 is the phase that un-excludes it, and it does so by calling OUT to this
    module, not by duplicating into it. *)
```

#### local_binding.ml - implement by partial-applying the existing `at_reconcile`

```ocaml
let holds_at_key ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : bool =
  at_reconcile ~controller_id ~cr_key ~absent:true ~undecodable:true
    ~decoded:(fun (orc : Controller.ongoing_reconcile)
                  (st : V_stateful_set_reconciler.s) (s : Cluster.cluster_state) ->
      bound_in_local_state ~key_name:cr_key.Common.name
        ~key_namespace:cr_key.Common.namespace st
      && step_binding ~namespace:cr_key.Common.namespace orc st s)
    s
```

OPTIONAL (disclose either way): reshape `binding_family`'s existing `l2` record to call
`holds_at_key` too, so exactly one copy of L2's decoded body exists. Cosmetic follow-on,
not required for E3 to ship, and it must not move `binding_sources`/`binding_cardinal`.

#### internal_guarantee.ml - NEW standalone value, beside `guarantee_family` (NOT inside it)

```ocaml
(* E3: upstream internal_rely_guarantee.rs:606-611, the LIFT of L2/E5 over every
   VSTS-kind key of [Cluster.ongoing_reconciles]. Modeled structurally on
   {!Invariants.unique_reconcile_id_invariant} (invariants.mli:44-49): a
   controller_id-only single [Invariants.invariant], not a per-cr family member -
   upstream's own signature takes only [controller_id], so [guarantee_family]'s
   [~cr:V_stateful_set.t -> ...] shape (every existing G1-G4 member genuinely
   consumes [~cr], internal_guarantee.mli:202-205) would be the wrong fit, not a
   clean extension. [holds]/[interesting] are total, pure, exception-free;
   [Object_ref_map.for_all]/[.exists] are the total-fold combinators (Map.S,
   object_ref_map.ml:17), no wildcard on the two-arm kind check ([not (...)] is
   the exhaustive complement of a single-constructor comparison, not a wildcard
   match). *)
let local_pods_and_pvcs_are_bound_to_vsts ~(controller_id : int) :
    Invariants.invariant =
  {
    Invariants.name = "local_pods_and_pvcs_are_bound_to_vsts";
    source = "vstatefulset_controller/proof/internal_rely_guarantee.rs:606";
    holds =
      (fun (s : Cluster.cluster_state) ->
        Object_ref_map.for_all
          (fun (k : Common.object_ref) (_orc : Controller.ongoing_reconcile) ->
            (not (Common.equal_kind k.Common.kind V_stateful_set.kind))
            || Local_binding.holds_at_key ~controller_id ~cr_key:k s)
          (Cluster.ongoing_reconciles s controller_id));
    interesting =
      (* P14 N3 - OWN premise mirror, not L2's per-key interesting witness. *)
      (fun (s : Cluster.cluster_state) ->
        Object_ref_map.exists
          (fun (k : Common.object_ref) (_orc : Controller.ongoing_reconcile) ->
            Common.equal_kind k.Common.kind V_stateful_set.kind)
          (Cluster.ongoing_reconciles s controller_id));
  }
```

The source string is **BARE** (`...rs:606`, no qualifier) - mandatory per the MB8
firewall (t_p21_regression.ml:535-544 / local_binding.mli:203-215): a qualifier makes
`line_of_source` return `None` and the member silently vanishes from the roster's
guarantee-lines sweep while the negative ledger-exclusion clause still passes.

#### internal_guarantee.mli - ADD the export + REWRITE the E-ledger doc block (rider D1, §1.4)

```ocaml
val local_pods_and_pvcs_are_bound_to_vsts : controller_id:int -> Invariants.invariant
(** E3 (:606-611), the LIFT of L2/E5 over every VSTS-kind key of
    [Cluster.ongoing_reconciles]. Un-excluded this phase (P25) on the ground that
    the committed multi-CR graphs (P12 fair [1;1], P13 G2 crash [1;1]) now give it
    a genuine >1-key premise - de-vacuizing the "L2 wearing a hat" collapse P21/P23
    measured on every single-CR scenario. Calls OUT to {!Local_binding.holds_at_key}
    rather than re-deriving L1/L2's body a third time. *)
```

**Selection evidence (stage B/C must REPRODUCE fresh, per §0.3)** [RULING:11-17]:

- unmutated violating = 0/0; pins reproduced EXACTLY: fair states=8580
  (t_p12_concurrent.ml:21), inv6_gate=6952 (p12_witness), premise-firing 8536; crash
  states=10552, gate=2784, premise 9200.
- named mutant api_server.ml:287 reddens 3440 (fair, of 7596 mutated states) / 3008
  (crash, of 9464). Restore byte-identical, re-verified 0/0.
- preemption probe: NO gate preempts; mutated graphs build fine, pins drift
  (states -984/-1088) - the mutant is observable by E3, not masked.

### 1.2 M(:256) - `local_state_is_coherent_with_etcd` - EXCLUDED-WITH-A-PIN, SCOPE ground

The superseding pin text, VERBATIM as it lands (settle-256's draft, adopted unmodified).
It replaces the forward pointer at `state_predicates.mli:667-674` ("RECORDED FOR
P25..."), appended as new bullets after the existing `[weakly_eq] WAS PORTED...` bullet
(mli:636-666); mirror the same replacement at `state_predicates.ml:626-633`:

```
- {b :256 [local_state_is_coherent_with_etcd] IS EXCLUDED-WITH-A-PIN ON THE SAME SCOPE
  GROUND AS :116-124, MEASURED THIS PHASE RATHER THAN ARGUED. THIS SUPERSEDES THE
  FORWARD POINTER PREVIOUSLY HERE.} P25 did not render :256's 114-line conjunct family;
  it measured whether upstream's own etcd-coherence scoping (the same rely-condition
  gap that excluded :116-124) already forecloses it, and the answer is yes.

- {b THE SCOPE GROUND, RESTATED FOR :256's OWN UPSTREAM TEXT.} Upstream
  state_predicates.rs:252-255 carries this comment immediately above the [pub open spec
  fn], quoted in full:

    {v // coherence between local state and etcd state
    // Note: there are many exceptions when the object is just updated or the index
    // haven't been incremented yet
    // message predicates for each exceptional states carry the necessary information
    // to repair the coherence v}

  Upstream does not assert this coherence unconditionally either: it depends on
  MESSAGE-CARRIED repair information supplied by exception-tracking machinery this port
  does not have - the identical gap :569-585 already names for :116-124 ({b this port has
  no rely-condition machinery}). :256 is not a new scope question; it is the same one at
  larger scale.

- {b THE MEASUREMENT: EVERY PINNED FAILURE IS CLASS (d) - NO WRITE OF ANY KIND IN
  FLIGHT.} [t_p25_probe_coherence] (probe-coherence-run.log) reproduces the pinned
  SET-EQUALITY and COHERENCE fail populations EXACTLY as a positive control (0/8/0/72 and
  0/4/0/40 on SP0/SPc/SPd/SPm) before classifying each fail state into four buckets: (a) a
  rely-violating pod-monkey write in flight, (b) a monkey write satisfying R1/R2, (c) a
  controller-sourced write with no monkey write, (d) no write in flight at all.
  SET-EQUALITY: SPc {b 8/8} class (d), SPm {b 72/72} class (d). COHERENCE: SPc {b 4/4}
  class (d), SPm {b 40/40} class (d). {b a=b=c=0 on every graph, every conjunct.} 100% of
  the pinned failure population is class (d).

- {b THE OVER-EXCLUSION COMPLEMENT: A RELY-GUARD WOULD BE WRONG IN BOTH DIRECTIONS.}
  {b 144} SPm states carrying a rely-violating write in flight PASS the etcd-coherence
  checks anyway. A guard built to exclude "rely-violating write in flight" states would
  therefore wrongly exclude 144 states needing no exclusion, while doing nothing for the
  124 (80 set-eq + 44 coherence) class-(d) failures, which have no write in flight to key
  off of. The effective premise of such a rely-scoped restoration is {b 8/60/48/672}
  (SPm's 816-state premise minus the 144 complement) - and the class-(d) failures sit
  INSIDE that narrowed premise, not outside it, so scoping the restore to "no
  rely-violating write in flight" rescues none of them.

- {b THE STRUCTURAL GROUND: AN IN-FLIGHT GUARD CANNOT SEE AN ALREADY-CONSUMED WRITE.}
  Every class-(d) failure is, by construction of the classification, a state with NO
  write of any kind outstanding: the divergence is not a writer currently violating rely
  conditions, it is a write - most plausibly a Delete, upstream's own rely-exempt request
  kind (rely_guarantee.rs:26, "Deletion/UpdateStatus requests are allowed"; ported at
  rely_conditions.ml:224-227/242-246) - that already LANDED and was CONSUMED before the
  observation state, the identical signature P24 attributed to :119-124's failures
  (mli:610-613, "the response names an owned object whose key has since left etcd"). No
  predicate evaluated AT the observation state, rely-scoped or not, can see a write that
  is no longer in flight; the missing information is exactly what upstream's :253-255
  comment says is carried by message predicates this port does not implement.

- {b :256 IS THEREFORE EXCLUDED-WITH-A-PIN ON THE SCOPE GROUND - THE THIRD MEMBER OF THAT
  GROUP, alongside :116-118 and :119-124.} It does not ship as a conjunct or a family this
  phase; [weakly_eq]/[pod_spec_weakly_eq]-class comparison (rs:292) stays OUT for the same
  reason mli:636-666 already gives. The REACHABILITY ground (:241, :246) and the SHAPE
  ground (the other seven M1 PVC-family conjuncts) are UNAFFECTED and UNCHANGED by this
  entry - :256 is a distinct upstream member, not a re-partition of M1.

- {b THE PIN, in the wording a consumer may quote:} [P25_witness]'s coherence-classification
  probe, run over SP0/SPc/SPd/SPm, asserts: set-eq class-d 0/8/0/72, coherence class-d
  0/4/0/40, a=b=c=0 everywhere, over-exclusion complement 0/0/0/144, effective premise
  8/60/48/672. Literals live in test/p25_witness.ml; a scope_exclusion_pin_256 Alcotest
  case in the P25 state-predicates test file asserts all of it, mirroring
  t_p24_state_predicates.ml's scope_exclusion_pin case exactly.
```

All numbers [RULING:21-25 / probe-coherence-run.log]; stage B re-derives them before the
pin text's "MEASURED THIS PHASE" claim is true of the committed tree.

### 1.3 M(vct) - the L0v occupancy pin + "seven -> eight" doc fix - C1-GATED

C3 settled SHIP (settle-256, upholding the judge): the witness pin and doc fix land this
phase; **the 8 PVC-family conjuncts stay EXCLUDED** until a named mutant reddens one on
L0v (deferred, §6). The exclusion ground gets a FOURTH name - do NOT file it under
REACHABILITY (which is definitionally a vacuity ground, mli:76-82, and L0v's Get_pvc-family
occupancy is measured NONZERO, the opposite of vacuous). New ground text, inserted
alongside SHAPE/REACHABILITY/SCOPE near mli:105-146:

```
- {b RED-CAPABILITY-PENDING} - the premise is proven non-vacuous (occupancy measured
  nonzero) but no mutant has yet been shown to redden the conjunct at any occupied state,
  so it is neither a proven invariant nor a proven vacuity. {b EIGHT M1 conjuncts under
  vct:true}: :197, :198, :199, :215-221, :223-228, :233, :244, :246 - all eight, because
  landing a vct:true leg retires the SHAPE ground (the PVC pin itself reddens) for all
  eight at once, not seven; see the corrected count below. They stay excluded until a
  named mutant (corrupt the Create_pvc/Skip_pvc guard, or the pvc_index derivation) is
  run against L0v and shown to redden at least one.
```

**The C1 GATE (binding, stage B):** :246's equality (`pvc_index == pvc_cnt`) was never
EVALUATED on L0v - only premise occupancy (8/116) was measured [RULING:51-52]. The
"seven -> eight" doc-fix language may not finalize as anything stronger than "returns to
scope, truth value UNCONFIRMED" until stage B runs the equality probe (§5, stage B):

- Temporary exe `test/t_p25_probe_vct_eq.ml` (added to test/dune, built, run ONCE,
  then reverted byte-identical + file deleted - the probe-vct/probe-coherence
  discipline, t_p25_probe_coherence.SOURCE.ml:1-4).
- (1) Rebuild L0v (P18's committed vct:true graph, 116 states) via the proven
  seed_of/reach_of scaffolding; (2) POSITIVE CONTROL, STOP if it fails: reproduce
  probe-vct-run.log's exact line `:246 premise non-vacuity (pvc_index>0 at
  Create_needed|Update_needed): 8`; (3) derive `pvc_cnt` INLINE, do not port a field:
  `List.length (Option.value ~default:[] cr.V_stateful_set.spec.volume_claim_templates)`
  (state_predicates.rs:259-261; the `make_pvcs` derivation local_binding.mli:113-119
  cites); (4) at each of the 8 states print PASS/FAIL for `pvc_index = pvc_cnt` plus a
  summed violation count; RC = violation count.
- **Outcome A** (equality holds on all 8): the mli:105-117 doc fix lands with exactly
  this language - "a [vct:true] leg brings EIGHT conjuncts back into scope, not seven
  (not nine) ... :246's own truth value is UNCONFIRMED: only premise-firing was
  measured ... see the RED-CAPABILITY-PENDING ground above" - and the conjunct stays
  excluded-not-committed-green per C3.
- **Outcome B** (any of the 8 violates the equality): **STOP**. Do not fold into the
  doc-fix commit. Report as a REAL FINDING (a fidelity divergence in the port's
  pvc_index/pvc_cnt tracking under vct:true); the doc-fix prose does NOT ship until
  triaged.

**Pin discipline (settle-256, mirroring P24 exactly):** only TWO values become named
literals in `test/p25_witness.ml`, because only they flip a decision:

```ocaml
let l0v_get_pvc_family_occupancy : int = 40  (* retires the SHAPE-vacuity premise on L0v *)
let l0v_246_premise_nonvacuity : int = 8     (* drives the seven->eight doc fix; gates C1 *)
```

Everything else stays SPEC-RECORDED measurement only [RULING:28-31]: decoded **104/116**;
per-step Init 8, After_list_pod 16, Get_pvc 8, After_get_pvc 16, Create_pvc 4,
After_create_pvc 8, Skip_pvc 4 (family total 40); excluded-conjunct premise occupancy
:199=8, :233=8, :244=32, blanket(:197/:198/:215-221/:223-228)=80, :246=8, :241=0
(orthogonal, stays; already pinned as `P24_witness.after_delete_outdated_occupancy_everywhere`
- do NOT re-pin under a P25 name). Recorded via a reusable structurally-checked
step_occupancy-style probe function, never per-column literals
(t_p24_state_predicates.ml:417-441 explicitly rejects per-column literal assertion:
"a row reading check int ... is n=n ... it cannot see a column DROPPED").

The doc-fix blast table (all C1-gated, land only on Outcome A; if C1 resolves against,
NONE move and only the occupancy pins ship): state_predicates.mli:41, :71-75, :76-82,
:105-117, :119-127; state_predicates.ml:246-251, :330-342, :405; fault_check.mli:2399,
:2455-2457 (the two fault_check.mli echoes of "seven M1 conjuncts on the SHAPE ground",
settle-blast finding, verified live).

### 1.4 Riders D1/D2/D3 + the `t_p25_reconcile` battery

**ORDERING RULE (binding, RULING:36-39):** D1-D3 land FIRST (stage A); the battery lands
AFTER them (stage C), so its LEG2 is not born red on stale prose. **Battery LEG2 gate: if
LEG2 is still red after D1-D3 + the 7/2 fix, that IS a finding - never edit the
assertion to force green.**

**D1 - `internal_guarantee.mli:160-171` rewrite.** Current text [MEASURED this session,
read fresh at :160-171] still reads "4 shipped + 5 excluded ... E3 :606 / E4 :613 /
E5 :640 (the controller-LOCAL register ... deferred as real plumbing, the strongest
remaining unoccupied register in the file)" - DOUBLY stale (never absorbed P23's 6/3;
known doc debt, BUILD-SPEC-P24.md §5.3). Replace the whole block with the
"RE-PARTITIONED BY P<n> ... SUPERSEDES" narrative form (house precedents:
p21_witness.ml:207-233, state_predicates.mli:667), jumping directly 4/5 -> 7/2 with the
history narrated (P21 wrote 4/5; P23 shipped E4 :613 as L1 and E5 :640 as L2 in
{!Local_binding.binding_family}, never folded into {!guarantee_family}; P25 ships E3
:606 as the standalone value above). settle-riders' draft is the base text, with its
"confirm the exact site against the settle-e3 diff" hedge DELETED - the site is settled
(§1.1): E3's body and export live in THIS module, beside `guarantee_family`, calling out
to `Local_binding.holds_at_key`. End state: **7 shipped + 2 excluded**, nine total and
disjoint: shipped G4 :544 / G1 :562 / G2 :581 / G3 :589 (P21, here) + L1 :613 / L2 :640
(P23, Local_binding) + E3 :606 (P25, here); excluded E1 :522 / E2 :528 (here) only.
NOTE the line-shift hazard: the replacement grows the block (~11 -> ~19 lines), shifting
every later line in the file; recompute the three known downstream citations
(BUILD-SPEC-P23.md:360's `:185/:197` cites; fault_check.mli:2037; local_binding.ml:8)
after the final wording is fixed - do not assume the delta without re-measuring.

**D2 - `BUILD-SPEC-P23.md:740` citation fix** (refutation GATE 3, verified byte-exact:
`fault_check.ml:1134` actually holds `Internal_guarantee.guarantee_family ~cr
~controller_id`). Single-line swap, in place:

```
- `Helper_invariants.helper_family ~cr ~controller_id` at
+ `Internal_guarantee.guarantee_family ~cr ~controller_id` at
   `fault_check.ml:1134` and SEE the gate pins 20/276/96/2080 come back
```

**D3 - `BUILD-SPEC-P23.md:463` stale cite fix** (refutation GATE 3, verified): swap
`` `p21_witness.ml:148-152` `` -> `` `p21_witness.ml:140-144` `` (the live anchor for
the 76/464/744/1976/116 re-export; positive control: invariants.ml:410 already cites
:140-144). Leave `` `p22_witness.ml:148-152` `` on the same line UNTOUCHED (verified
accurate). Do NOT touch `BUILD-SPEC-P21.md:148-152` (a different, non-drifted
self-citation).

D2/D3 site decision, recorded: the RULING (:34-36) names D2/D3 as edits at those
coordinates, so the in-place edit WINS over the P22-precedent alternative
(correct-in-next-spec-prose) that settle-blast flagged; the tension is noted here so the
choice is a decision, not an accident. BUILD-SPEC-P23.md's pin freeze covers numeric
pins, not prose citations.

**The battery - `test/t_p25_reconcile.ml`** (new registered exe, test/dune names +1;
design from settle-riders, corrected counts):

- **LEG1 tuple-coherence**: extract every `a / b / c[ / d[ / e]]` numeric run (len>=3)
  from the corpus (local_binding.mli, fault_check.mli, internal_guarantee.mli,
  BUILD-SPEC-P22.md, BUILD-SPEC-P23.md, p21..p25_witness.ml headers); assert membership
  in a set GENERATED from the in-tree witness pins (never hand-listed). Failure prints
  file:line + the unmatched tuple (phase-STOP diagnosis: fix the prose OR the generator,
  record which, never retune blindly).
- **LEG2 partition-reconciliation**, two layers, read-only against existing pins:
  (1) per-family cardinal triples:
  `internal_guarantee.mli:199` "expected cardinal 4" <-> `p21_witness.ml:200` (=4);
  `local_binding.mli:322` "expected cardinal 2" <-> `p23_witness.ml:149` (=2);
  `state_predicates.mli:760` "expected cardinal 2" <-> `p24_witness.ml:223` (=2);
  `rely_conditions.mli:239` "expected cardinal 3" <-> `t_p20_rely.ml:375` (=3);
  (2) the 9-slot E-ledger restatements in internal_guarantee.mli (post-D1) AND
  local_binding.mli:31-38, each derived-checked against
  `P21_witness.ledger_spec_fn_count`/`ledger_shipped_lines` as
  `(List.length shipped, count - List.length shipped)`; every "A shipped + B excluded"
  string must equal it UNLESS the line carries a past-tense marker ("was", "P21 wrote",
  "->", "RE-PARTITIONED BY").
- **LEG3 case-count self-verification**: for every registered `t_p2*` exe, a meta-case
  asserting `List.length cases = registered` against a NEW per-exe pin in
  p25_witness.ml, counting the ACTUAL registered `Alcotest.test_case` values (the
  shadowed-binding guard: a duplicate `let t32 ()` binding shrinks the RUN count
  silently). Pins are FRESH-MEASURED at battery-write time from the live tree - the
  orphaned scout sketch's figures are stale, do not copy.
- **LEG4 cite-pin**: a `cite_pins : (path * int * string) list` of every load-bearing
  cross-file citation coordinate (rs:606/:613/:640/:642/:646/:655-656/:659-661/:668,
  invariants.ml:1046, model_check.mli:57, scenario.ml:459/:495, vsts_invariants.ml:217,
  plus every coordinate D1/D2/D3 touched or created); for each, read the file and
  assert line `n` contains the needle. Upstream (`anvil-ref`) checks are conditional on
  the tree existing, gated by an exact checked-count pin (0 XOR K, never "some"), so an
  absent ref tree fails LOUD instead of vacuously passing.
  **OPEN FLAG (refutation GATE 5, PLAUSIBLE): the file accessor MUST be a named TOTAL
  combinator chain - `In_channel.input_lines : in_channel -> string list` +
  `List.nth_opt` (or equivalent) - never `open_in`+`seek_in`+`input_line`, which raise
  `Sys_error`/`End_of_file` on exactly the drift LEG4 exists to catch.** No test in
  this repo does runtime file I/O today (`rg 'open_in|In_channel' test lib` = 0 hits,
  reproduced by the refutation), so this is a genuinely new idiom.
- **OPEN FLAG (settle-riders, unresolved engineering risk):** test/dune's single
  `(tests (names ...))` stanza has no `(deps ...)` field; whether the prose-reading legs
  see `../lib/**` from `_build/default/test/` is UNVERIFIED. Resolve with an actual
  `opam exec --switch=anvil-ocaml -- dune build @runtest` (output to a file, never
  `tail`) before writing LEG1/LEG2/LEG4 - do not assume.
- Battery novelty gate [MEASURED this session, exit 1]:
  `rg -n 't_p25_reconcile|p25_witness' lib test -g '!*.md'` must still exit 1 before
  the battery lands.
- Zero upstream register: the battery introduces no new upstream Rust source string;
  it rides P25 rather than being a phase (BUILD-SPEC-P24.md:1258).

## 2. The E-ledger re-partition (6/3 -> 7/2): blast table + FROZEN firewall

Sanctioned scope, quoted from the RULING's Pin-safety section (:58-62, binding): "The
E-ledger re-partition (6/3 -> 7/2) is SANCTIONED but its blast radius must be enumerated
by file:line before stage A ... Everything else P13-P24 is FROZEN; a moved pin is a
phase-STOP." This section IS that enumeration. AMENDED 2026-08-03: stage A's
repartition editor phase-STOPPED on a triple-confirmed INCOMPLETENESS finding; the
enumeration is COMPLETED by §2.1-ADDENDUM below (history kept: §2.1's own rows stand
unchanged).

### 2.1 SANCTIONED to move (before -> after; all coordinates re-verified by the design wave)

| file:line | before (current, verified) | after | notes |
| --- | --- | --- | --- |
| test/p21_witness.ml:239 | `let ledger_shipped_lines : int list = [ 544; 562; 581; 589; 613; 640 ]` [MEASURED] | `[ 544; 562; 581; 589; 606; 613; 640 ]` | 606 inserted ASCENDING |
| test/p21_witness.ml:242 | `let ledger_e3_lines : int list = [ 606 ]` [MEASURED] | **REMOVED** (renamed-away, not emptied) | house convention, p21_witness.ml:235-237: a stale reader of the old name FAILS TO COMPILE instead of silently reading a narrower bucket |
| test/p21_witness.ml:202-237 | header prose "6 shipped + 3 excluded ... E3 1 - :606 ... A two-CR spine de-vacuizes it; that is a later phase" [MEASURED] | new "RE-PARTITIONED BY P25" paragraph, 7/2, E3 moved to the shipped bullet | narrative form per the P23 paragraph already there |
| test/t_p21_regression.ml:501-503 | `ledgered_excluded_lines = e1 @ e2 @ e3` | drop the `ledger_e3_lines` term | auto-reddens to compile error otherwise - the intended loud failure |
| test/t_p21_regression.ml:528-534 | positive-form clause: `[613;640]` present in roster | ADD a third positive-form clause for :606 ("every P25 E3 source names proof/internal_rely_guarantee.rs too", mirroring the P23 clause at :510-513) | ARGUED (settle-e3 leg design), adopted |
| test/t_p21_regression.ml:545-556 | bare-source-firewall count checks | auto-follow once the :606-cited standalone value is swept | mechanical |
| test/t_p21_regression.ml:557-564 | exact-list check + comment "-> 6 shipped + 3 excluded" | value auto-follows; comment -> "-> 7 shipped + 2 excluded" | |
| test/t_p21_regression.ml:565-573 | "no EXCLUDED line (E1 :522/E2 :528/E3 :606) is shipped" | drop 606 from the prose list | check itself stays correct as `ledgered_excluded_lines` shrinks |
| test/t_p21_regression.ml:577-583 | "shipped + ledgered = 9 (6+1+1+1)" | "(7+1+1)"; the numeric check (9) is unaffected | |
| test/t_p21_regression.ml:272-316 | `shipped_suites`/`committed_roster`, **15 entries** [MEASURED this session] | +1 row each (the SIXTEENTH), appended after the p24 row: `let p25_e3_label = "Internal_guarantee.local_pods_and_pvcs_are_bound_to_vsts (P25, E3)"` ... `(p25_e3_label, [ Ig.local_pods_and_pvcs_are_bound_to_vsts ~controller_id ]);` | the P23/P24 single-row precedent; roster count is DERIVED (`List.length committed_roster - 1` at :375 [MEASURED]), no numeric literal moves |
| test/t_p21_regression.ml:43, :363, :559, :603 | count prose: ":43 other THIRTEEN" (pre-existing drift, should read FOURTEEN today), ":363/:603 FIFTEEN suites", ":559 FIFTEEN-suite roster" [MEASURED via rg] | :43 -> "other FIFTEEN"; :363/:559/:603 -> SIXTEEN | folds the refutation's low-severity PLAUSIBLE drift in opportunistically; description strings only, no pin |
| **test/t_p23_regression.ml:450-452** | `ledgered_excluded_lines = P21_witness.ledger_e1_lines @ ... @ ledger_e3_lines` [MEASURED] | drop the `ledger_e3_lines` term | its OWN copy, not shared with t_p21_regression - a SECOND site (refutation GATE 2) |
| **test/t_p23_regression.ml:468** | `[ 544; 562; 581; 589; 613; 640 ]` [MEASURED] | `[ 544; 562; 581; 589; 606; 613; 640 ]` | COMMITTED P23 literal vs the live global; BREAKS ON BUILD if skipped |
| **test/t_p23_regression.ml:476-478** | prose "E3 :606 alone remains, and it is NOT shipped by this register" [MEASURED] | rewrite (E3 now ships elsewhere; the binding-lines-not-in-excluded check itself stays valid) | |
| **test/t_p23_regression.ml:481-484** | `[ 522; 528; 606 ]` [MEASURED] | `[ 522; 528 ]` | |
| **test/t_p23_regression.ml:486-487** | `"... (6 + 1 + 1 + 1)"` [MEASURED] | `"... (7 + 1 + 1)"` | description string |
| lib/assurance/internal_guarantee.mli:160-171 | "4 shipped + 5 excluded ..." [MEASURED, quoted in §1.4/D1] | D1 rewrite, 7/2 | rider D1 |
| lib/assurance/local_binding.mli:33-42 | "Why E3 :606 stays excluded ... L2 wearing a hat" | rewrite: E3 SHIPS this phase via {!holds_at_key}; keep the history in past tense | live .mli, not frozen history |
| lib/assurance/local_binding.mli:85-90, :286 | cites E3's :608 premise / "E3 :606 stays excluded" | review + update to "shipped P25" | |
| lib/assurance/local_binding.mli (new) | - | ADD `val holds_at_key` (§1.1) | the ONE new export |
| lib/assurance/local_binding.ml:252-259 | "[Object_ref_map.for_all] is deliberately NOT used here: that is E3's lift, which this phase EXCLUDES" | update: P25 un-excludes it, by calling OUT to this module (see §1.1 doc text) | |
| lib/checker/fault_check.mli:2036-2041 | "E3 :606 STAYS EXCLUDED ... 4 shipped + 5 excluded to 6 shipped + 3 excluded" | rewrite to the 7/2 partition | |
| lib/assurance/internal_guarantee.ml (new) | - | ADD the standalone E3 value (§1.1) | beside, not inside, `guarantee_family` |

### 2.1-ADDENDUM (post-stage-A amendment, sanctioned)

Added 2026-08-03. Stage A's repartition editor phase-STOPPED on a triple-confirmed
finding: the §2.1 table is INCOMPLETE - it missed a THIRD whole-roster sweep
(t_p24_regression.ml holds live `P21_witness.ledger_shipped_lines` against a
roster-derived inventory, the same shape as t_p21_regression.ml:557-564 and
t_p23_regression.ml:468) plus straggler citations. Every before-fragment below was
RE-VERIFIED against the LIVE tree before its row was written. The tree already carries
stage A's landed hybrid (D1's mli ledger block, `holds_at_key`, the standalone E3
value, `t_p25_e3_multi_cr` + `t_p25_reconcile`, the test/dune `(deps ...)` block), so
coordinates below are LIVE-TREE coordinates as of this amendment, not 99786d1
coordinates. §2.1's rows stand unchanged; this table only ADDS.

| file:line | before (current, verified) | after | notes |
| --- | --- | --- | --- |
| **test/t_p24_regression.ml:558-581 + :586-604** | `shipped_suites` / `committed_roster`, **16 entries each** [MEASURED live]; `committed_binding_pairs` at :492-498 cite `...internal_rely_guarantee.rs:613` / `:640`, NO :606; `test_source_file_partition` asserts `P21_witness.ledger_shipped_lines roster_guarantee_lines` at :767-771 | +1 row each (the SEVENTEENTH): bind `let p25_e3_label : string = "Internal_guarantee.local_pods_and_pvcs_are_bound_to_vsts (P25, E3)"` (the SAME literal as t_p21_regression's sixteenth-row label, §2.1) beside the labels at :535-545; append `(p25_e3_label, [ Ig.local_pods_and_pvcs_are_bound_to_vsts ~controller_id ]);` after the p24 row at :580; append `p25_e3_label;` after :603 - the derived inventory then equals the 7-item ledger | THE MISSED THIRD SWEEP: without this row the p21_witness.ml:239 edit reddens :767-771 (the expected side gains 606, the roster-derived inventory does not). Safe per the file's OWN coupling disclosure at :700-707; `Ig` alias live at :115; the swept count at :638 is DERIVED (`List.length committed_roster - 1`), no numeric literal moves |
| test/t_p24_regression.ml:85-86, :768-770, :825 + count-word sweep | :85-86 "the SIXTEEN-suite roster's guarantee-line inventory is still exactly {!P21_witness.ledger_shipped_lines}"; :768-770 "the SIXTEEN-suite roster's internal_rely_guarantee.rs inventory is still exactly the ledger's shipped bucket (G4 :544, G1 :562, G2 :581, G3 :589, L1 :613, L2 :640) - adding P24 moved nothing"; :825 "the roster's internal_rely_guarantee.rs inventory is unmoved" [all MEASURED] | P25-aware past tense per D1's convention: the inventory equals the RE-PARTITIONED 7-item shipped bucket (G4 :544 / G1 :562 / G2 :581 / G3 :589 / E3 :606 / L1 :613 / L2 :640); "adding P24 moved nothing; P25's E3 row is the sanctioned move". The :771 assertion itself AUTO-FOLLOWS (both sides move together) - only description strings/comments change | ALSO sweep this file's OWN count words (description strings/comments only, no pin): SIXTEEN -> SEVENTEEN at :65, :533, :628, :704-705, :766, :810; swept-set FIFTEEN -> SIXTEEN at :72, :636, :656, :679; rename `test_roster_is_sixteen_and_covers_the_newest_phases` (:626, called at :812) -> `test_roster_is_seventeen_and_covers_the_newest_phases`. LEAVE every FIFTEEN that denotes t_p23_regression's own roster (:67, :70, :628-630's "fifteen ... names FIFTEEN explicitly") |
| test/t_p21_regression.ml:528-534 - §2.1 AMBIGUITY RESOLVED | §2.1's row ("ADD a third positive-form clause for :606 ... mirroring the P23 clause at :510-513") is ambiguous between a bool prefix clause and a literal-presence extension. Verified live: :510-513 is the bool clause "every P23 binding source names proof/internal_rely_guarantee.rs too" over `Lb.binding_sources`; :533-534 holds `[ 613; 640 ]` TWICE (expected list AND filter scrutinee) | CANONICAL READING - BOTH land, the executor never guesses: (i) a :510-513-SHAPED BOOL PREFIX CLAUSE over the STANDALONE E3 source: `Alcotest.(check bool) "every P25 E3 source names proof/internal_rely_guarantee.rs too" true (List.for_all (String.starts_with ~prefix:guarantee_prefix) [ (Ig.local_pods_and_pvcs_are_bound_to_vsts ~controller_id).Invariants.source ])` - a singleton list; NO `e3_sources` export exists or is added; (ii) ADDITIONALLY extend the :528-534 literal-presence clause: BOTH `[ 613; 640 ]` occurrences (:533 expected, :534 scrutinee) -> `[ 606; 613; 640 ]` ASCENDING, and the :529-532 description names E3 :606 | (i) preserves the MB8 rationale for E3 (a qualifier on the standalone source must redden LOUD); (ii) preserves the committed-literal positive form the :514-527 comment defends |
| tense/prose stragglers INSIDE already-§2.1-sanctioned files | t_p21_regression.ml:552 "(six after the P23 re-partition)"; :574-576 comment "(NINE pub open spec fn ... 6 shipped + 3 excluded after the P23 re-partition)"; :613-616 runner "E-ledger reversal clause (re-partitioned 4+5 -> 6+3): the roster ships exactly G1-G4 + L1 :613 + L2 :640"; t_p23_regression.ml:424-435 section header (":429 6 shipped + E1 1 + E2 1 + E3 1"; :433-435 "E3 :606 stays excluded because it is the LIFT of E5 ... 'L2 wearing a hat'"); t_p23_regression.ml:530-533 runner "4 shipped + 5 excluded -> 6 shipped + 3 excluded, total and disjoint at NINE" [all MEASURED] | :552 -> "seven after the P25 re-partition"; :575 -> "7 shipped + 2 excluded after the P25 re-partition" (NINE stays); :614-615 -> "(re-partitioned 4+5 -> 6+3 -> 7+2): the roster ships exactly G1-G4 + E3 :606 + L1 :613 + L2 :640"; t_p23 :424-435 -> past tense in D1's narrative convention (E3 STAYED excluded through P24; P25 shipped it over the multi-CR graphs); t_p23 :531-532 -> "... -> 7 shipped + 2 excluded, total and disjoint at NINE" | RECORDED so the executor does not skip them under only-named-sites discipline; description strings/comments only - every numeric check on these lines is derived or unchanged |
| lib/checker/fault_check.mli:2036-2041 - §2.1 row EXTENDED | :2037 cite "(internal_guarantee.mli:167-171)"; :2038-2039 "the committed [P21_witness.ledger_e3_lines] = [[606]] pin (t_p21_regression.ml:72, :501-503)" [MEASURED] | the 7/2 rewrite must ALSO: (i) RECAST the `[P21_witness.ledger_e3_lines]` doc cite - the val is RENAMED AWAY by §2.1's p21_witness.ml:242 row, so a numbers-only rewrite leaves a DANGLING cite; past-tense it (the pin WAS `[606]` until P25 renamed the bucket away); (ii) recompute :2037's cite to `internal_guarantee.mli:160-204` - D1's LANDED ledger block spans :160-204 ("{b E-ledger}" through "only."), MEASURED live this amendment; (iii) recompute the companion cites in the same sentence (local_binding.mli:39-45; t_p21_regression.ml:72, :501-503) AFTER their own §2.1 rows land | a dangling doc cite is exactly the LEG4 hazard class the battery pins against |
| NEW stragglers (a) lib/assurance/local_binding.ml:8, (b) lib/assurance/local_binding.mli:359, (c) lib/assurance/state_predicates.ml:626-633 | (a) "(BUILD-SPEC-P21 §2.2, internal_guarantee.mli:167-171)" [MEASURED]; (b) "the export local_binding.mli:258-259 named in advance" [MEASURED - live anchor is :359] ; (c) "RECORDED FOR P25, superseding RULING §3.3(4)'s SHIP-fork reading. ... without answering that first." [MEASURED] | (a) cite -> "internal_guarantee.mli:160-204" (same live measurement as the row above); (b) ONE-CHAR fix -> "the export local_binding.ml:258-259 named in advance" - the referent comment lives at local_binding.ml:258-259 [MEASURED]; §1.1's doc block shipped the .mli typo verbatim (a-lib); (c) replace the stale forward pointer with the comment-form ORDERED MIRROR of the pin block a-prose landed at state_predicates.mli:667-740 (§1.2's bullets; spec :259-261 already ordered this mirror) | (b) is a LEG4 hazard if pinned as-is (a cite_pins row would assert the needle in the WRONG file); (c) owner = the repartition editor |
| stage-gate reconciliation - RECORD, no code edit | §5 per-stage exe counts read 82 (A) / 82 -> 84 (B) / 84 -> 85 (C); §1.4's battery novelty gate (the `rg` alternation over `t_p25_reconcile` / `p25_witness`, `-g '!*.md'`, exit 1); §1.4's `(deps ...)` OPEN FLAG; LEG1 ledger shape | (i) the quota-kill + resume produced a SANCTIONED HYBRID: exe count is **84 NOW** [MEASURED: `rg -o 't_\w+' test/dune \| sort -u \| wc -l` = 84; `t_p25_e3_multi_cr` + `t_p25_reconcile` at test/dune:22-23], `t_p25_state_predicates` NOT yet in; stage B adds it -> FINAL **85** unchanged; §5's per-stage counts read as HISTORICAL. (ii) the battery novelty gate is UNSATISFIABLE post-landing BY CONSTRUCTION (5 hits today, incl lib/assurance/state_predicates.mli, whose landed §1.2 block cites [P25_witness] - sanctioned); for the record it is SCOPED to a FILE-EXISTENCE check: test/t_p25_reconcile.ml AND test/p25_witness.ml exist. (iii) the `(deps)` flag is RESOLVED BY MEASUREMENT: test/dune:24-33 records the real `@runtest` (2026-08-03) - exactly BUILD-SPEC-P22.md, BUILD-SPEC-P23.md and the dune file itself were absent from _build, and exactly those three are declared. (iv) LEG1's 8-row recorded-unpinned ledger deviation (t_p25_reconcile.ml:644 `recorded_unpinned_ledger`: hand-typed tuples for measured-but-unpinned prose, each with quoted ground + the staleness check at :732) is RECORDED as sanctioned | the seal's §0.3 reconciliation pass consumes this row; nothing here moves a pin |
| post-green residues (2026-08-03, sanctioned): test/t_p25_reconcile.ml:854 + lib/assurance/local_binding.mli:33-34 | green2 `@runtest` RC=1, sole red = leg2_partition_reconciliation, BOTH residual rows in local_binding.mli [MEASURED, green2-leg2-failure.output]: (i) t_p25_reconcile.ml:854 pins "expected cardinal 2" at local_binding.mli:322 but the §2.1 prose insertions drifted that line to :331 [MEASURED via rg]; (ii) :33-34 wrapped the historical counts as "after P23 it became / 6 shipped + 3 excluded:" - line 34 carries NONE of the four per-line exempt markers (t_p25_reconcile.ml:805-811), so the layer-2 scanner reads the historical 6/3 as current-form against the derived 7/2 | (i) re-pin 322 -> 331 (the measured-coordinates-at-battery-write-time discipline already used for state_predicates.mli:826); (ii) LINE-COUNT-NEUTRAL re-wrap: :33 "P21's partition was 4 shipped + 5 excluded -> 6 shipped + 3 excluded" + :34 "after P23: G4 :544, ..." so both historical count phrases sit on the line carrying ' was ' and '->' | neither edit weakens an assertion: the scanner flagged HISTORICAL prose and a drifted coordinate, not a wrong pin; the re-wrap is line-neutral so :331 and fault_check.mli's recomputed local_binding cites stay true |

### 2.2 FROZEN-pin firewall (byte-identical after P25; any motion = phase-STOP)

| pin / surface | value | why frozen |
| --- | --- | --- |
| test/p21_witness.ml:200 `guarantee_cardinal` | **4** [MEASURED] | refutation GATE 1: E3 is NOT a G5; checked at t_p21_regression.ml:225 [MEASURED] |
| test/p23_witness.ml:149 `binding_cardinal` | **2** [MEASURED] | E3 is NOT a 3rd binding member; checked at t_p23_regression.ml:252 [MEASURED] |
| `internal_guarantee.ml` `guarantee_family`/`guarantee_sources` | 4 members | untouched by the standalone placement |
| `local_binding.ml` `binding_family`/`binding_sources` | 2 members | untouched (the OPTIONAL l2 reshape may not change either surface) |
| lib/checker/fault_check.ml:37-145 | - | NEVER edit (HARD RULE, RULING:63) |
| `objects_to_pods`/`pod_filter` | - | never mutated in place (RULING:63) |
| test/t_p19_regression.ml:45-46, :371-391 | P19's OWN E3' (payload-register) pin | FALSE LEAD: same letter, different upstream member; no edit |
| lib/checker/BUILD-SPEC-P21.md:148-152 | self-citation | NOT drifted (verified); distinct from the D3 target |
| lib/checker/BUILD-SPEC-P22.md:279-281 | "reds only if P23 ships E3-E5, deliberately" | accurate as history |
| test/p22_witness.ml:148-152 | re-export block | verified accurate; untouched by D3 |
| `P24_witness.after_delete_outdated_occupancy_everywhere` | 0 | :241 stays orthogonal; do NOT re-pin under a P25 name |
| every other P13-P24 committed pin | - | RULING:61-62: "Everything else P13-P24 is FROZEN; a moved pin is a phase-STOP" |

## 3. Legs and witness pins - per settle-e3's ruling

### 3.1 The E3 leg: TWO existing mechanisms reused + ONE new witness (no third)

1. **Classification/disjointness/novelty (reused, ZERO new graph exploration).** The
   sixteenth roster row in t_p21_regression.ml (§2.1). Without it the whole-tree
   E-ledger reversal clause (t_p21_regression.ml:505-583, restated at
   t_p23_regression.ml:429-491) is GREEN VACUOUSLY the moment E3 ships - the failure
   mode the file's own header names twice (:34-41, :249-257) and that P23's landing had
   to fix for L1/L2.
2. **Multi-CR non-vacuity/violation counts (NEW - the only new graph exploration this
   member needs).** `test/p25_witness.ml` (UNLISTED in test/dune - the p24_witness.ml
   convention, BUILD-SPEC-P24.md:1135-1136), single source of truth for the new
   numbers, built exactly as the selection probe was:

```ocaml
let fair_bound : Bound.t = P12_witness.p12_bound ~desireds:[ 1; 1 ]
let fair_seed : Cluster.cluster_state =
  Scenario.vsts_seed_multi ~desireds:[ 1; 1 ] ~fair:true
let fair_reach : Cluster.cluster_state Mc.reachable =
  Mc.explore ~depth:40 ~successors:(Cc.bounded_successors fair_bound cluster)
    ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ fair_seed ]
let crash_bound : Bound.t = P13_witness.p13_bound ~desireds:[ 1; 1 ]
let crash_seed : Cluster.cluster_state =
  Scenario.vsts_seed_multi_faults ~desireds:[ 1; 1 ] ~crash:true
    ~req_drop:false ~pod_monkey:false
let crash_reach : Fc.faulted Mc.reachable =
  Mc.explore ~depth:40
    ~successors:(Fc.faulted_successors crash_bound Fc.budget_crash_only cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed crash_seed ]
let e3 = Ig.local_pods_and_pvcs_are_bound_to_vsts ~controller_id
let fair_states = Mc.states_seen fair_reach
let fair_e3_premise = Mc.count_states_where fair_reach e3.Invariants.interesting
let fair_e3_violating =
  Mc.count_states_where fair_reach (fun s -> not (e3.Invariants.holds s))
(* mirror for crash_states/crash_e3_premise/crash_e3_violating over crash_reach,
   projecting Fc.faulted -> .cs the way t_p13_faults.ml does *)
```

   Registered exe `test/t_p25_e3_multi_cr.ml` (Alcotest) asserts the pins in §3.3 plus a
   **derivation guard**: `fair_states`/`crash_states` must equal t_p12_concurrent.ml's /
   p13_witness.ml's own committed graph-size literals (the P21 "derived not re-typed"
   pattern, t_p21_regression.ml:161-178), so a drifted seed/bound reddens HERE rather
   than silently re-measuring.

### 3.2 The :256 / vct assertion site

`test/t_p25_state_predicates.ml` (registered exe), two Alcotest cases mirroring
t_p24_state_predicates.ml's `scope_exclusion_pin` shape:

- `scope_exclusion_pin_256`: asserts every §1.2 pin number (set-eq class-d 0/8/0/72,
  coherence class-d 0/4/0/40, a=b=c=0, complement 0/0/0/144, effective premise
  8/60/48/672) from p25_witness.ml literals + the classification probe function.
- `vct_occupancy_witness_pin`: asserts `l0v_get_pvc_family_occupancy = 40` and
  `l0v_246_premise_nonvacuity = 8` against a rebuilt L0v.

Witness/assertion separation per P24: literals in `p25_witness.ml` (unlisted),
assertions in the registered `t_p25_*` exes. P25 does NOT bolt cases onto p23/p24
witness modules - phases never mix witness modules.

### 3.3 Witness pins to mint (all [PREDICTION] until stage B's own run reproduces them; expected values [RULING:12-15, 21-31])

| pin (test/p25_witness.ml) | expected | asserted by |
| --- | --- | --- |
| `fair_states` | 8580 | t_p25_e3_multi_cr + derivation guard vs t_p12_concurrent.ml:21 |
| `fair_e3_premise` | 8536 | t_p25_e3_multi_cr |
| `fair_e3_violating` | 0 | t_p25_e3_multi_cr |
| `crash_states` | 10552 | t_p25_e3_multi_cr + derivation guard vs p13_witness g2 pin |
| `crash_e3_premise` | 9200 | t_p25_e3_multi_cr |
| `crash_e3_violating` | 0 | t_p25_e3_multi_cr |
| `l0v_get_pvc_family_occupancy` | 40 | t_p25_state_predicates |
| `l0v_246_premise_nonvacuity` | 8 | t_p25_state_predicates |
| :256 class-d / complement / premise rows | 0/8/0/72, 0/4/0/40, 0/0/0/144, 8/60/48/672 | t_p25_state_predicates (`scope_exclusion_pin_256`) |
| LEG3 per-exe case counts | FRESH-MEASURED at battery time (deliberately not pre-stated) | t_p25_reconcile |

These are NEW pins: nothing shipped computed an E-ledger family over the multi-CR
graphs before (settle-e3, grep-confirmed zero hits), and no OCaml constant carries the
class-d or L0v numbers yet.

## 4. Mutation matrix

Per-row baseline discipline (all rows): (1) run UNMUTATED first and reproduce the §3.3
pins exactly (positive control - STOP on any mismatch); (2) apply the mutant with the
Edit tool; (3) run, record; (4) restore from saved pre-mutation bytes, NEVER
`git checkout --` (which restores from the INDEX, and a driver that dies mid-run leaves
the mutation live); (5) verify restore byte-identical + `git diff --stat` residue scan;
(6) re-run unmutated and see 0/0 again.

| row | mutant | expectation | pin surface / notes |
| --- | --- | --- | --- |
| ME3 | `lib/cluster/api_server.ml:287`: `namespace = req.namespace;` -> `namespace = "";` inside `created_ref` (the etcd-storage-key of `Object_ref_map.add created_ref created_obj s.resources` at :297) - a KEY/OBJECT namespace divergence; `metadata.namespace` at :269 UNTOUCHED | RED on both graphs: `fair_e3_violating` 0 -> nonzero (expected **3440** of **7596** mutated-fair states), `crash_e3_violating` 0 -> nonzero (expected **3008** of **9464**); `fair_states`/`crash_states` themselves drift (**-984/-1088**) - the mutant is reachability-visible too, not just predicate-visible (Object_ref_map keys feed `state_equal`/`state_hash`) | **This row is hereby NAMED the CANONICAL E3 mutant, settling C2** [RULING:53-54]. All numbers are [RULING:14-16 / probe-e3-run-mutated.log] EXPECTED REPRODUCTION TARGETS ONLY: stage C must re-run this mutant FRESH against the shipped p25 exes and may not cite the selection probe's run as the phase's own mutation evidence (probe logs + `PRE-MUTATION-api_server.ml.bytes` in `~/Documents/anvil-ocaml-p25-harness/`) |
| LEG2-red rule | (not a mutant - a standing gate) | battery LEG2 red AFTER D1-D3 + the 7/2 fix = REAL FINDING | never edit the assertion to force green (RULING:38-39) |
| L0v red-capability mutant | corrupt the Create_pvc/Skip_pvc guard or the pvc_index derivation, run against L0v | would redden >=1 of the 8 vct conjuncts | **DEFERRED to P26** (§6) - C3 ships pin + doc fix only this phase; the RED-CAPABILITY-PENDING ground (§1.3) names the pending mutant explicitly |

Mutation-evidence rule (house): a mutant killed by a BUILD error or a timeout is NOT
caught - reshape it; ME3 as specified compiles (the selection probe verified the mutated
graphs build and explore, RULING:16-17).

## 5. Stage plan - A / B / C / seal, with per-stage gates

All builds: `cd ~/Documents/anvil-ocaml && opam exec --switch=anvil-ocaml -- dune build
@runtest` (or scoped), output redirected to a file, NEVER `tail`. Never commit/push -
stage + hand over per house rule.

**Stage A - code + re-partition + riders D1/D2/D3.**
Land: `holds_at_key` (mli+ml), the standalone E3 value (ml+mli export), every §2.1
blast-table row, D1/D2/D3.
Gates:
- Novelty gate re-run IMMEDIATELY before landing: `rg -n
  'internal_rely_guarantee.rs:606' lib test -g '!*.md'` exit 1 (it was exit 1 at
  design time [MEASURED]; re-verify - the gate is stage A's, not this spec's).
- Build green, full `@runtest` RC=0, still **82 exes** (stage A adds no exe).
- FROZEN firewall (§2.2) byte-identical: `git diff` must show NO hunk touching
  p21_witness.ml:200, p23_witness.ml:149, fault_check.ml:37-145, or any §2.2 row.
- D1 line-shift recompute done (§1.4 D1 note).

**Stage B - witnesses + the C1 probe.**
Land: `test/p25_witness.ml` (unlisted), `test/t_p25_e3_multi_cr.ml`,
`test/t_p25_state_predicates.ml` (registered: test/dune names **82 -> 84**).
Run the C1 probe (`t_p25_probe_vct_eq`, TEMPORARY: dune edit + file both reverted
byte-identical after ONE run; during the probe the tree transiently has 85 names).
Gates:
- Every §3.3 [PREDICTION] reproduced EXACTLY by this stage's own runs; any mismatch is
  a phase-STOP finding, not a pin adjustment.
- Derivation guards green (fair/crash states equal the committed P12/P13 literals).
- **C1 equality evaluated**: Outcome A -> land the §1.3 doc fix (mli:105-117 et al.,
  the full C1-gated table); Outcome B -> STOP, file the fidelity finding, doc fix does
  not ship.
- Probe residue: `git status --short` shows NO trace of t_p25_probe_vct_eq after
  revert.

**Stage C - mutation + battery.**
Run ME3 fresh (§4 discipline). Then land `test/t_p25_reconcile.ml`
(test/dune names **84 -> 85**), AFTER confirming D1-D3 are in the tree (ordering rule).
Gates:
- ME3 reddens both graphs; numbers recorded against the [RULING] expectations, restore
  byte-identical, post-restore 0/0 re-verified.
- Battery: dune `(deps ...)`/sandbox question resolved by an actual build (§1.4 OPEN
  FLAG); LEG4 uses the named total accessors; LEG2 green - or red handled as a FINDING.
- LEG3 pins fresh-measured, committed in p25_witness.ml.

**Seal.**
- Full `@runtest` RC=0 at **85 exes** (82 baseline + t_p25_e3_multi_cr +
  t_p25_state_predicates + t_p25_reconcile; N=85 is DERIVED here from the three settled
  additions - each settler stated only its own +1).
- Both novelty gates re-run: the :606 gate now intentionally FIRES on the shipped
  source string? NO - the gate greps for the BARE upstream cite in lib/test; after E3
  ships, `internal_rely_guarantee.rs:606` appears in internal_guarantee.ml's source
  string, so the gate's job is DONE at stage A entry and it is not a seal invariant.
  At seal instead run the REVERSE check: exactly ONE hit in lib
  (`rg -c 'internal_rely_guarantee.rs:606' lib -g '!*.md'` = 1 file), confirming no
  double-ship.
- FROZEN firewall re-verified byte-identical vs 99786d1
  (`git diff 99786d1 -- test/p21_witness.ml` shows only the sanctioned §2.1 hunks, etc.).
- `git status`/`git diff --stat` enumerate ONLY this spec's files (§2.1 + §3 + this
  spec); anything else = review-agent mutation residue, investigate before staging.
- Reconciliation pass (its own step, per §0.3): every [PREDICTION] in this spec is
  rewritten to its measured value or the divergence is filed as a finding - predictions
  must not outlive their measurements.

## 6. Deferred to P26, and rejected outright

### 6.1 Deferred-to-P26 ledger (each with its recorded reason)

| item | status | source |
| --- | --- | --- |
| Resp-side triad (`:588`/`:676`/`:750`) | plausible but ARGUED only - P26 must PROBE first, no ship on argument | RULING:47 |
| Guarantee-side `:133-180` controller-only register | ZERO-finding vs shipped G4 on all four single-CR graphs (Update/UpdateStatus/Delete/GetThenUpdateStatus = 0, narrow AND broad scope); defer until multi-CR non-vacuity measured (P26 probe) | RULING:42-44 |
| Other-controller rely `:32-55`/`:92-129` | VACUOUS BY CONSTRUCTION today: every `Scenario.*` seed installs exactly one `controller_models` entry (scenario.ml:68, :308, ...); needs a SECOND-CONTROLLER SEED before any measurement means anything | RULING:45-46 |
| Items 1a/1b/5 (seed-adding candidates) | cost class NEVER PROBED - advisory ranking only; a P26 selection wave must probe before ranking them against probed members | RULING:48 |
| L0v red-capability mutant for the 8 vct:true PVC conjuncts | named in the RED-CAPABILITY-PENDING ground (§1.3): corrupt Create_pvc/Skip_pvc guard or pvc_index derivation, redden >=1 conjunct on L0v; until run, the conjuncts stay EXCLUDED | §1.3 / RULING:33 |
| OPTIONAL l2 reshape onto `holds_at_key` | if not taken in stage A, carry as a one-copy-of-L2's-body cleanup; must not move `binding_sources`/`binding_cardinal` | §1.1 |

### 6.2 Rejected outright (do NOT carry as deferred)

- **Rely-condition machinery for :256 (branch (a))**: CLOSED, measured - 100% class-(d)
  failures + the 144-state over-exclusion complement make a rely guard wrong in both
  directions (§0.1). Not "deferred pending machinery"; the machinery answer is no.
- **`weakly_eq`/`pod_spec_weakly_eq`-class comparison (rs:292)**: STAYS OUT
  (RULING:27), same ground as mli:636-666.
- **E1 `:522` / E2 `:528`**: remain the E-ledger's 2 excluded, on their standing grounds
  (E1 collapses to G4 on single-CR; E2 already shipped semantically as P19's M1). Not
  P26 candidates absent a new ground.
- **E3 as a G5 `guarantee_family` member / 3rd `binding_family` member**: REJECTED
  (refutation GATE 1) - signature mismatch + frozen cardinals. Struck, not conditional.
- **Per-column literal assertion of the L0v histogram**: rejected per
  t_p24_state_predicates.ml:417-441's recorded rationale (n=n cannot see a dropped
  column); the structurally-checked function + two load-bearing literals is the shape.
- **Editing BUILD-SPEC-P23.md beyond the D2/D3 line swaps**: historical record stays;
  the P22 stale-"6/6" precedent (corrected in next-spec prose, never in place) governs
  everything except the two RULING-named citation fixes.

---

*Written by the P25 design wave's spec writer, 2026-08-02, against 99786d1 (tree clean).
Sources: RULING-P25-SELECTION.md + selection probe logs (SELECTION evidence);
settle-e3 / settle-blast / settle-256 / settle-riders settlements; the adversarial
refutation (5 gates, all CONFIRMED gates applied, PLAUSIBLE items carried as OPEN
FLAGs); fresh rg/Read measurements marked [MEASURED] inline. Never commit for the user;
stage only.*

## 7. SEAL (2026-08-03)

Phase close-out, appended per section 5's seal step and section 0.3's
reconciliation discipline. Every number below is a P25-OWN measurement (stage
A/B/C runs plus the seal's forced gate), never a carried selection number; all
artifacts named live in ~/Documents/anvil-ocaml-p25-harness/.

### 7.1 Stage outcomes (measured)

- Stage A (code + repartition + riders D1/D2/D3): quota-killed mid-wave and
  RESUMED same-session (wf_16015991-293) behind a pre-resume compile gate.
  The stage's phase-STOP finding F1 was honored: no edit landed until the
  2.1-ADDENDUM sanctioned the missed rows. The 7/2 repartition landed:
  ledger_shipped_lines = [544;562;581;589;606;613;640] with 606 ascending,
  ledger_e3_lines REMOVED from code (renamed away; residual hits are .md
  prose only). Evidence: stage-a-*.json, repartition-wave-*.json.
- Stage B (witnesses + the C1 gate): C1's :246 equality [pvc_index = pvc_cnt]
  was EVALUATED on P18's committed 116-state L0v vct:true graph and HELD at
  all 8 premise-firing states (4 Create_needed + 4 Update_needed), so
  Outcome A landed: the seven -> EIGHT doc fix across the full C1-gated
  table. The 85th exe t_p25_state_predicates shipped: scope_exclusion_pin_256
  quads 0/8/0/72 and 0/4/0/40 (a=b=c=0 everywhere), over-exclusion
  complement 0/0/0/144, effective premise 8/60/48/672, vct occupancy 17-label
  histogram with Get_pvc family total 40, c1_246_equality 0 violations of 8,
  case_parity 4=4. Evidence: stage-bc-b.json, stage-b-*.log (esp.
  stage-b-c1-probe-run.log, stage-b-runtest.log).
- Stage C (mutation + battery): the canonical ME3 mutant (api_server.ml:287
  created_ref namespace corrupted to "") COMPILED (build RC=0, so the kill is
  NOT a build error) and was killed by the INTENDED assertions: fair states
  8580 -> 7596 with 3440 violating, crash states 10552 -> 9464 with 3008
  violating, exact match of the RULING expectations. Restore proven
  cmp-byte-identical (saved pre-mutation bytes, never git checkout).
  Post-restore, the final FORCED full @runtest ran 85/85 suites green, RC=0.
  Evidence: stage-bc-c.json, stage-c-*.log,
  stage-c-restored-runtest-forced.log, green2/green3 logs,
  seal-runtest-forced.log.
- Seal gates (section 5): reverse :606 check = exactly ONE lib file carries
  the upstream cite (no double-ship); FROZEN firewall byte-identical vs
  99786d1 (fault_check.ml and api_server.ml zero-diff); git diff --stat vs
  99786d1 matches the 2.1 + 2.1-ADDENDUM blast table exactly. Verified by
  the read-only audit, stage-bc-audit.json.
- Section 3.3 [PREDICTION] discharge (per 0.3, recorded append-only so no
  earlier line renumbers): every 3.3 predicted pin was reproduced EXACTLY by
  stage B/C's own runs (stage-bc-b.json pinsReproduced; the stage C positive
  control). The [PREDICTION] markers above are DISCHARGED here. The one
  code-side stale prediction found by the seal sweep
  (t_p25_e3_multi_cr.ml:122, "LEG3 (stage C) will re-measure") was rewritten
  line-count-neutrally to the measured outcome.

### 7.2 Findings ledger F1-F7

- F1 (blocker, resolved): section 2.1's blast table MISSED a third
  whole-roster sweep, t_p24_regression.ml:767-771 (test_source_file_partition
  holds live P21_witness.ledger_shipped_lines against a roster-derived
  inventory); without its row the p21_witness.ml:239 edit reddens there.
  Phase-STOP honored; the 2.1-ADDENDUM sanctioned the row BEFORE any edit
  landed.
- F2 (low, resolved): local_binding.mli doc-cite typo, "the export
  local_binding.mli:258-259 named in advance" pointing at a comment that
  lives in the .ml (addendum NEW-stragglers row (b), then-live :359). Fixed
  by the repartition wave; landed form verified live at local_binding.mli:368,
  citing local_binding.ml:259-263 (the referent's landed span). A LEG4 hazard
  class had it been pinned as-is.
- F3 (low, resolved): two green-gate residues after the repartition, both
  caught by leg2_partition_reconciliation (green2 run RC=1): (i) battery
  cardinal_triples pin drift, "expected cardinal 2" pinned at
  local_binding.mli:322 while prose insertions drifted it to :331, re-pinned
  per the measured-coordinates discipline; (ii) the local_binding.mli:33-34
  historical "6 shipped + 3 excluded" text left line 34 with no per-line
  exempt marker; fixed by a LINE-COUNT-NEUTRAL rewrap keeping ' was ' and
  '->' on the counting line. Sanctioned by addendum row 8 (post-green
  residues).
- F4 (low, doc-only): the spec's OWN Outcome-A canned quote
  (BUILD-SPEC-P25.md:372-376) is self-contradictory: it mandates landing the
  literal ":246's own truth value is UNCONFIRMED" while its trigger condition
  (equality holds on all 8) falsifies that phrase. The landed prose is
  CORRECT and stays: state_predicates.mli:105-117 and :179-181,
  fault_check.mli:2404 and :2460-2461 all state the equality was EVALUATED
  and HELD; rg 'UNCONFIRMED' over lib (excl. .md) = 0 hits. No code action;
  never re-insert the canned literal.
- F5 (low): ME3 observability gap: the shipped exe aborts each case at its
  FIRST failed check (the states derivation guard, 8580/10552), so the
  violating counts 3440/3008 cannot print in t_p25_e3_multi_cr's failure
  output. They were recorded FRESH via a one-run, byte-reverted
  re-registration of the selection probe source (stage-c-mutant-probe-run.log)
  and matched exactly. The kill remains by the intended assertions; the gap
  is observability, not evidence.
- F6 (info, resolved): the contested C1 question is SETTLED BY MEASUREMENT:
  the :246 equality holds 8/8 at every premise-firing L0v state, closing the
  selection wave's only open semantic question.
- F7 (info): stage-gate suite counts (37/37, 38) were dune-cache INCREMENTS,
  not totals; the plain post-restore @runtest re-ran ZERO suites (vacuous per
  the stale-artifact rule). The true forced total is 85/85
  (stage-c-restored-runtest-forced.log, seal-runtest-forced.log). Recorded so
  later phases never read incremental counts as evidence.

### 7.3 Deferred to P26 (unchanged from section 6.1, restated at seal)

- The L0v red-capability mutant (section 4 row 3 + section 6.1): corrupt the
  Create_pvc/Skip_pvc guard or the pvc_index derivation, redden at least one
  of the 8 vct:true conjuncts; until run, they stay EXCLUDED under the
  RED-CAPABILITY-PENDING ground.
- Guarantee-side internal_rely_guarantee.rs:133-180 controller-only register:
  multi-CR probe first (zero findings vs shipped G4 on all four single-CR
  graphs).
- Other-controller rely :32-55 / :92-129: vacuous by construction on current
  single-controller seeds; needs a second-controller seed first.
- Resp-side triad :588 / :676 / :750: argued-only, P26 must probe before any
  ship.
- Selection items 1a/1b/5 (seed-adding candidates): cost class never probed;
  advisory ranking only.
- OPTIONAL l2 reshape onto holds_at_key (one-copy cleanup; must not move
  binding_sources/binding_cardinal).

### 7.4 P26 handoff pointers

- Harness dir: ~/Documents/anvil-ocaml-p25-harness/ holds
  RULING-P25-SELECTION.md, all stage JSONs (stage-a-*.json,
  repartition-wave-*.json, stage-bc-{b,c,audit}.json), the stage logs, and
  seal-runtest-forced.log.
- Standing battery gates that keep watching: LEG2 partition reconciliation
  (prose partition counts vs code cardinals; a red is a REAL FINDING, never
  weakened) and LEG4's 0-XOR-11 upstream cite gate (an absent anvil-ref tree
  reds LOUD, never vacuous) plus its 10 repo cite pins.
- FROZEN-pin roster unchanged through P25: guarantee_cardinal 4,
  binding_cardinal 2, ledger_spec_fn_count 9 (shipped bucket
  [544;562;581;589;606;613;640], excluded [522;528]).

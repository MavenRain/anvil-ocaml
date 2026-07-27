# BUILD-SPEC-P15: reconcile-side correspondence, and the NECESSITY of upstream's fault-disabled premises

Phase 15 of the OCaml port. Branch `p15-reconcile-correspondence` off `f56b4cf` (P14).

Pure ASSURANCE CONSTRUCTION. `lib/cluster/` is NOT modified by this phase: every
field the family reads (`ongoing_reconciles`, `pending_req_msg`, `local_state`,
`in_flight`, `crash_enabled`, `req_drop_enabled`, `pod_monkey_enabled`) is already
exported. P14's one disclosed accessor deviation is not repeated or widened.

## 1. The gap this phase closes, and the correction to P14 that opens it

P14 shipped five id-level members from `proof/network.rs` and deferred a sixth,
recording the reason in `correspondence.mli:70-81`:

> Upstream's `pending_req_in_flight_or_resp_in_flight_at_reconcile_state`
> (`controller_runtime_safety.rs:90-97` ...) is the natural sixth member and is
> DELIBERATELY not shipped: its disjunct is genuinely necessary ... so a version
> written without the disjunct is false in the crash-FREE graph too and its
> refutation would prove nothing about crashes.

**That note is right about the predicate it names and wrong about the family it
dismisses, on three counts that this section fixes.** All three were found by
reading the upstream checkout now kept durably at `~/Documents/anvil-ref` (P14
warned its temp-dir copy could be GC'd; it was copied before this phase began).

1. **The cited anchor is the LEMMA, not the predicate.**
   `controller_runtime_safety.rs:90-97` is `state_comes_with_a_pending_request`
   (:90-93) plus the opening of `lemma_always_pending_req_in_flight_or_resp_in_flight_at_reconcile_state`
   (:97). The predicate itself lives in a different file:
   `controller_runtime_liveness.rs:131-145`.

2. **There are TWO predicates, not one, and they are not the same claim.**
   Alongside the `or` member sits
   `pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg`
   (`controller_runtime_liveness.rs:147-168`), which adds a third conjunct
   asserting **EXCLUSIVITY** — the request and a matching response are never both
   in flight. P14's deferral argument ("the disjunct is genuinely necessary, so a
   version without it is false crash-free") is an argument about *dropping* the
   disjunct. It says nothing about the member that *keeps* the disjunct and then
   forbids the conjunction. Exclusivity is a genuinely refutable claim about
   response mis-delivery, and it is precisely the claim an rpc-id collision
   breaks.

3. **The two members are guarded differently, and the guard is what P14's own
   result makes interesting.** The `or` member is guarded by
   `at_expected_reconcile_states` (a *state* predicate); the `xor` member is
   guarded by `ongoing_reconciles.contains_key(key) && has_pending_req_msg`.
   Both guards live on the ONGOING-RECONCILE side. Every P14 member is guarded on
   the NETWORK side (`in_flight().contains(msg)`). `restart_controller`
   (`cluster.ml:291-324`) empties `ongoing_reconciles` and leaves `s.network`
   untouched — so the crash edge *destroys* a reconcile-side guard while
   *preserving* a network-side one. **This phase is the experiment that turns
   that asymmetry from an observation into a measurement** (section 3).

**The second, larger gap.** Upstream's `xor` lemma
(`controller_runtime_safety.rs:408-500`) is proved under three explicit
fault-disabled premises:

```rust
spec.entails(always(lift_state(Self::crash_disabled(controller_id)))),   // :414
spec.entails(always(lift_state(Self::req_drop_disabled()))),             // :415
spec.entails(always(lift_state(Self::pod_monkey_disabled()))),           // :416
```

Every one of those three is DIRECTLY EXPRESSIBLE as a state predicate in this
port — `crash_enabled` sits on the `controller_and_external` record
(`cluster.mli:19`), `req_drop_enabled` and `pod_monkey_enabled` on
`cluster_state` (`cluster.mli:29`) — and P13 already ships a fault budget that
turns each fault edge on and off independently (`fault_check.mli:77-94`). No
prior phase has asked whether an upstream PREMISE is load-bearing. This one does,
and the answer is a matrix, not a yes/no (section 4.5).

## 2. The ported family (verbatim upstream statements)

Quoted bodies are the upstream Verus text, transcribed from `~/Documents/anvil-ref`,
not reconstructed. The OCaml column is the obligation for section 4.2.

### R1 `pending_req_of_key_is_unique_with_unique_id(controller_id, key)` (network.rs:104-117)

```rust
|s: ClusterState| {
    s.ongoing_reconciles(controller_id).contains_key(key)
    && s.ongoing_reconciles(controller_id)[key].pending_req_msg is Some
    ==> (
        forall |other_key: ObjectRef|
            #[trigger] s.ongoing_reconciles(controller_id).contains_key(other_key)
            && key != other_key
            && s.ongoing_reconciles(controller_id)[other_key].pending_req_msg is Some
            ==> s.ongoing_reconciles(controller_id)[key].pending_req_msg->0.rpc_id
                != s.ongoing_reconciles(controller_id)[other_key].pending_req_msg->0.rpc_id
    )
}
```

The **sixth `network.rs` member**, which P14 ported five of. It is here rather
than in P14 because it is the declared premise of BOTH R3's lemma
(`controller_runtime_safety.rs:417`) AND R2's (`controller_runtime_safety.rs:103`),
and belongs with the members it supports. Upstream `always`-proves it at
`network.rs:119`.

OCaml: fold over `Cluster.ongoing_reconciles s controller_id` with
`Object_ref_map`, comparing the key's `pending_req_msg` rpc id against every
*other* bound key's. Ship it quantified over ALL keys (upstream's per-`key`
statement, universally closed), so it is a single `Invariants.invariant` rather
than one per key — the universal closure is strictly stronger and matches how
P14's N2/N3 were shipped.

### R2 `pending_req_in_flight_or_resp_in_flight_at_reconcile_state(controller_id, key, current_state)` (controller_runtime_liveness.rs:131-145)

```rust
|s: ClusterState| {
    Self::at_expected_reconcile_states(controller_id, key, current_state)(s)
    ==> {
        let msg = s.ongoing_reconciles(controller_id)[key].pending_req_msg->0;
        &&& Self::has_pending_req_msg(controller_id, s, key)
        &&& Self::request_sent_by_controller_with_key(controller_id, key, msg)
        &&& (s.in_flight().contains(msg)
            || exists |resp_msg: Message| {
                &&& #[trigger] s.in_flight().contains(resp_msg)
                &&& resp_msg_matches_req_msg(resp_msg, msg)
            })
    }
}
```

Upstream `always`-proves it at `controller_runtime_safety.rs:97`, **under the
side condition `state_comes_with_a_pending_request` (:100, defined :90-93)**. See
section 4.3 — this side condition is NOT optional and NOT nominal, and shipping
R2 at an instantiation that violates it would manufacture a refutation that says
nothing about the port.

### R3 `pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg(controller_id, key)` (controller_runtime_liveness.rs:147-168) — THE HEADLINE

```rust
|s: ClusterState| {
    (s.ongoing_reconciles(controller_id).contains_key(key)
    && Self::has_pending_req_msg(controller_id, s, key))
    ==> {
        let msg = s.ongoing_reconciles(controller_id)[key].pending_req_msg->0;
        &&& Self::request_sent_by_controller_with_key(controller_id, key, msg)
        &&& (s.in_flight().contains(msg)
            || exists |resp_msg: Message| { ... resp_msg_matches_req_msg(resp_msg, msg) })
        &&& !(s.in_flight().contains(msg)
            && exists |resp_msg: Message| { ... resp_msg_matches_req_msg(resp_msg, msg) })
    }
}
```

Three conjuncts: **provenance** (the pending request really was sent by this
controller for this key), **existence** (it or a matching response is in flight),
**exclusivity** (never both). Exclusivity is the new dimension: P14's members
constrain ids against a counter and against each other; none of them says a
response cannot be attributed to a request that is still outstanding.

**FAITHFULNESS FLAG — R3 IS PROVED `leads_to(always(..))`, NOT `always(..)`.**
Upstream's ensures clause is
`spec.entails(true_pred().leads_to(always(lift_state(...))))`
(`controller_runtime_safety.rs:422`). Asserting R3 after EVERY step is therefore
strictly STRONGER than what upstream proves, exactly like inv10
(`invariants.ml:1008`, the `eventually_always` bucket). This phase asserts the
stronger form deliberately, and section 8 records what each outcome may and may
not be read as. If R3 is refuted only at states near the seed, that is the
`leads_to` shape appearing empirically and is NOT a port bug; the counterexample
lasso must be inspected before any such claim is made.

### R4 `no_pending_req_msg_at_reconcile_state(controller_id, key, current_state)` (controller_runtime_liveness.rs:105-110)

```rust
|s: ClusterState| {
    Self::at_expected_reconcile_states(controller_id, key, current_state)(s)
        ==> Self::no_pending_req_msg(controller_id, s, key)
}
```

Upstream `always`-proves it at `controller_runtime_safety.rs:502` under the
**dual** side condition (:507): every state satisfying `state` is produced by a
transition returning `None` for the request. R2 and R4 are duals and one checker
validates both with the polarity flipped (section 4.3).

### Supporting definitions (helpers, NOT members)

- `at_expected_reconcile_states` (`controller_runtime_liveness.rs:98-103`)
- `has_pending_req_msg` (`:21-25`) — `is Some` AND content is an api or external
  REQUEST. The content conjunct is load-bearing; do not simplify it to `is Some`.
- `request_sent_by_controller_with_key` (`:56-68`) — `msg.src == Controller(cid, key)`
  and (`dst = APIServer` with api-request content, or `dst = External(cid)` with
  external-request content). The port's `Message.host_id` carries
  `Controller of int * Common.object_ref` (`message.mli:37`), so this is an exact
  transcription, not an approximation.
- `no_pending_req_msg` (`:31-33`), `reconcile_idle` (`:183-185`).

### DELIBERATELY EXCLUDED, and why (do not "complete the family")

`pending_req_in_flight_at_reconcile_state` (`:112-120`) and
`resp_in_flight_matches_pending_req_at_reconcile_state` (`:170-181`) look like
two more members and are NOT. Upstream never proves either one `always`; both are
**leads-to TARGETS** inside the liveness argument (`:339-353`), i.e. states the
system eventually reaches. Shipping them in an `always` suite would assert that
the controller is *permanently* mid-request, which is false the moment a reconcile
ends. Excluding them is faithfulness, not scope-trimming. `req_msg_is_the_in_flight_pending_req_at_reconcile_state`
(`:122-129`) is excluded for the same reason.

## 3. The prediction that must be measured (guard location vs. crash sensitivity)

P14's measured result: under mutant MA (`restart_controller` also resets
`s.rpc_id_allocator`) the G2 leg flips to `Refuted` naming N1, while G1 stays
byte-identical. Its members are network-guarded, and the crash preserves the
network.

**PREDICTION P15-A (structural).** R1-R4 are reconcile-guarded, and
`restart_controller` empties `ongoing_reconciles` (`cluster.ml:309`). At the crash
instant every guard is false, so all four are VACUOUSLY true there. After restart
the controller schedules a fresh reconcile whose request draws a FRESH rpc id (the
allocator is untouched at `cluster.ml:311-312`), so it can collide with no orphan.
**Therefore the unmutated crash edge should refute NOTHING in this family,** and
the crash's only visible effect should be on the GATE counts.

This is a prediction of a NEGATIVE result and it is the honest one. It must be
recorded as measured or refuted, not quietly dropped if it holds. Combined with
P14 it yields the phase's structural claim:

> Crash sensitivity in this port is determined by WHERE an invariant's guard
> lives, not by what the invariant says. Network-guarded members (P14) are
> crash-sensitive; reconcile-guarded members (P15) are crash-vacuous, because the
> crash transition's whole effect is to clear the reconcile side.

**PREDICTION P15-B (the headline mutation).** Under MA, R3's EXCLUSIVITY conjunct
should fire: with the counter reset, a post-restart pending request `m2` can be
allocated the id of a surviving orphan `m1`, and once the api server answers `m1`
the resulting response matches `m2` while `m2` is itself still in flight — both
disjuncts true.

**THE EXPERIMENTAL-DESIGN TRAP, and it is a real one.** P14 measured that under MA
**N1 fires at `steps=6`, one step BEFORE a collision can form.** So a leg
asserting P14's family and P15's family TOGETHER would report N1 and never
evaluate R3's exclusivity at all — the phase's headline would be MASKED by the
earlier-firing member. **The P15 legs must therefore assert the P15 family ALONE.**
If a run under MA reports `violated = every_in_flight_msg_has_lower_id_than_allocator`,
the family lists were unioned somewhere and that is a harness bug, not a finding.

**THE DIRECTIONAL TRAP INHERITED FROM P13/P14.** M1 (restart KEEPS
`ongoing_reconciles`) refutes nothing in either prior phase. Here it is even less
likely to bite: keeping the ongoing reconciles keeps each pending request paired
with its in-flight copy. If a run reports M1 refuting this family, that is a
harness bug.

## 4. What to build

### 4.1 No `lib/cluster/` change

Confirm before building, and again before staging:
`git diff --cached --name-only lib/cluster/` must be EMPTY. P14 spent its one
deviation; this phase does not get another. If a member appears to need a new
accessor, re-derive it from the existing exports first and record the attempt.

### 4.2 `lib/assurance/reconcile_correspondence.{ml,mli}` (NEW)

A separate module, NEVER appended to `Invariants.always`, `Vsts_invariants.always`
or `Correspondence.family` — for P14's reason (`correspondence.mli:56-65`): those
lists feed `Cluster_check` and P13's G1 at `fault_check.ml:318`, and appending
would silently move P13's and P14's committed pinned counts. Exported as its own
list and consumed only by its own leg.

Each member is an `Invariants.invariant` (`invariants.mli:28-42`) with `name`,
`source` (`<file>:<line>` in the Anvil clone, checkable against
`~/Documents/anvil-ref`), `holds`, and `interesting`.

`interesting` per member, and each must be JUSTIFIED not guessed:

- R1: at least TWO ongoing reconciles both holding `Some` pending requests. With
  one bound key the inner `forall` ranges over nothing and R1 is vacuous. This
  member is therefore expected to be vacuous at `desired=1`; see 4.4.
- R2: the guard `at_expected_reconcile_states` holds at the instantiated state.
- R3: an ongoing reconcile at some key with `has_pending_req_msg` true.
- R4: same guard as R2, at R4's own instantiation.

Combinator discipline: `Object_ref_map` folds and `Message.Pool` folds, `Option`
combinators, no `match` on `Option`/`Result`, exhaustive matches on every finite
sum, no loop keywords. `Option.fold ~none:` is EAGER — fold to an accumulator and
make at most one tail call, never a recursive call in `~none:`.

### 4.3 The executable side-condition checker (the piece that makes R2/R4 honest)

Upstream's `state_comes_with_a_pending_request` (`controller_runtime_safety.rs:90-93`):

```rust
&&& forall |s| #[trigger] state(s) ==> s != (reconcile_model.init)()
&&& forall |cr, resp_o, pre_state| #[trigger] state(transition(cr, resp_o, pre_state).0)
        ==> transition(cr, resp_o, pre_state).1 is Some
```

R2 is only an upstream theorem at instantiations satisfying this. R4's dual
(`:507`) is the same with `is Some` replaced by `is None`.

Ship `state_comes_with_a_pending_request` and `state_comes_with_no_pending_request`
as EXECUTABLE checks over the REACHABLE `(triggering_cr, resp_o, pre_state)`
triples of the leg's own graph. The universal quantifier is unbounded upstream and
bounded here; **that weakening is disclosed in the `.mli`, not papered over.** A
bounded check can only ever say "no reachable counterexample to the side
condition", which is exactly the same epistemic status as every other verdict this
port produces.

**The instantiation must be DERIVED, not invented.** Read
`Vreplica_set_reconciler`'s step encoding and pick the `Value.t` predicate that
actually satisfies the side condition; validate it with the checker BEFORE
measuring R2/R4. **If no non-vacuous instantiation exists for the VRS reconciler,
that is a MEASURED RESULT: ship R2/R4 parametric, record the empty instantiation
and the reason, and do not fabricate a state predicate to make a gate nonzero.**

### 4.4 `lib/checker/fault_check.check_reconcile_correspondence_under_faults`

One new leg mirroring `check_correspondence_under_faults` (`fault_check.ml:364-394`)
and reusing `run_leg`. Signature:

```ocaml
val check_reconcile_correspondence_under_faults :
  ?depth:int -> Bound.t -> budget -> desired:int -> require_crash:bool -> fault_report
```

Same seed / bound / depth as P13 G1 and P14 G2 (`p13_bound`, `witness_desired`,
`witness_depth`) so the product graph is the SAME one those phases explored and
the three phases cross-check on `states` / `crash_witness` / `fault_free`. Only
the asserted invariant list differs. **A P15 leg whose `states` count differs from
P14's at the same budget means the seed or bound drifted — investigate before
reporting anything.**

`require_crash` keeps P14's meaning: `false` counts states exercising a member,
`true` additionally requires `crashes >= 1`.

Because R1 is expected vacuous at `desired=1` (4.2), add a second seed at
`desired=2` — or, if the VRS scenario cannot produce two concurrently-ongoing
reconciles at one controller, say so with the evidence and mark R1's gate
STRUCTURALLY 0 with the mechanism, the way P14 handled N5's vacuity. Sweep the
binding ceiling to prove it is not a bound artifact (P14 swept `reconcile_ceiling`
2->3->4->6 for N5; do the equivalent here rather than asserting).

### 4.5 The premise-necessity matrix (the phase's novel result)

Five legs, identical except for the budget, each reported with its gate and its
`pruned_by_budget` flag:

| Leg | Budget | Upstream premise under test |
| --- | --- | --- |
| L0 | `zero_budget` | control: all three premises hold; family MUST be clean |
| L1 | `max_crashes=1`, others 0 | `crash_disabled` (`:414`) |
| L2 | `max_drops=1`, others 0 | `req_drop_disabled` (`:415`) |
| L3 | `max_monkey_ops=1`, others 0 | `pod_monkey_disabled` (`:416`) |
| L4 | `budget_default` (1/1/1) | all three at once |

A premise is **measured-necessary** if its leg is `Refuted` while L0 is clean and
decisive; **measured-unnecessary-in-this-model** if its leg is clean AND decisive
AND its fault edge was actually taken (`max_crashes_seen` / `max_drops_seen` /
`max_monkeys_seen` >= 1). A clean leg whose fault counter is 0 measures NOTHING
and must be reported as vacuous, never as a pass
([[feedback-workflow-zero-findings-may-be-vacuous]]).

**PREDICTION P15-C.** L2 is clean: `drop_req` (`cluster.ml:350-378`) passes
`{recv = Some req_msg; send = singleton resp}` to `Network.deliver`, which REMOVES
the request as it adds the matched error response — exactly one disjunct at every
step, so exclusivity is preserved by construction. If L2 refutes, read
`Network.deliver` before believing it.

Report every unnecessary premise as an honest negative: upstream needs these
premises for an UNBOUNDED inductive proof over an arbitrary reconciler, and a
bounded VRS-only model failing to exhibit the counterexample is weak evidence
about the premise, not a defect found in Anvil. Section 8 fixes that wording.

### 4.6 Tests

`test/p15_witness.ml` (all pins single-sourced, reusing `P13_witness` /
`P14_witness` constants for the shared seed), plus:

- `t_p15_reconcile_correspondence.ml` — the five legs, gates, and the
  side-condition checker's verdict.
- `t_p15_mutation.ml` — the confirm-by-mutation matrix (section 6).
- `t_p15_regression.ml` — the CLASSIFICATION FIREWALL, P14's pattern: P13/P12/P14
  witness constants are still the committed literals; the P15 family is DISJOINT
  from `Invariants.always`, `Vsts_invariants.always` and `Correspondence.family`
  (this is the automated guard against the section-3 masking trap); member names
  are the upstream four.

`dune test` HANGS on this repo. Run each exe under
`perl -e 'alarm 150; exec @ARGV' _build/default/test/<name>.exe`.

## 5. Tractability

The family is cheap per state: R1 and R3 are `Object_ref_map` folds over at most
`desired` keys; R3's inner existential is one `Message.Pool` fold. The expensive
member is R3's exclusivity, which needs the pool fold even when the request IS in
flight (it must prove NO matching response exists) — so budget one full pool scan
per ongoing reconcile per state. At P14's measured scale (464 product states, pool
cardinal <= 1 fault-free and small post-crash) this is nothing; both P14 legs
closed in <0.1 s CPU.

`max_in_flight` is the ceiling to watch: post-crash orphans never drain (P14
section 1). P14 predicted this would bind and MEASURED that it did not. Do not
inherit the prediction — re-measure and disclose, and if a retune is needed report
before/after rather than silently raising it.

## 6. Confirm-by-mutation matrix

Every member gets a mutation that MUST redden a specific named test, applied and
then reverted with `Edit` (never `git checkout` — the P12 process lesson). A test
never SEEN to fail is not evidence ([[feedback-confirm-tests-by-mutation]]).

| Id | Mutation | Must redden |
| --- | --- | --- |
| MA | `restart_controller` also resets `s.rpc_id_allocator` (P14's MA, re-run against the P15 family ALONE) | R3 exclusivity, at `crashes >= 1`; NOT N1 (section 3) |
| M1 | `restart_controller` KEEPS `ongoing_reconciles` | NOTHING — negative control, cross-phase consistent with P13/P14 |
| MB | R3's exclusivity conjunct deleted (keep existence) | a forged state with both request and matching response in flight |
| MC | R3's provenance conjunct deleted | a forged state whose pending request has a foreign `src` |
| MD | R1's `key != other_key` guard deleted | R1 becomes self-refuting; must redden |
| ME | R2/R4's side-condition checker forced to `true` | the instantiation-validation test |

**Forge one per-member violating state** the way P14 did (three per-member forged
states, each asserting EXACTLY the target member is violated), so trivializing any
member's `holds` to `fun _ -> true` cannot leave the battery green. **Check each
forged test for tautology and entailment before shipping it** — P14 shipped MD as
a tautology and MC as logically entailed, and review caught both.

## 7. Convention firewall (non-negotiable)

- Combinators over loops; exhaustive matches on finite sums; no `match` on
  `Option`/`Result`; no mutation of vectors; no `_ ->` wildcard on a finite sum.
- Doc comments on every exported item.
- Never commit ([[feedback_never_commit]]): stage and hand over the commit message.
- Every `source` string must resolve in `~/Documents/anvil-ref`. Spot-check at
  least R3's and R1's by opening the cited lines.

## 8. Honest limits (bake into code and docs, not just here)

1. Nothing here is PROVED. Upstream proves R1, R2, R4 `always` and R3
   `leads_to always` in Verus. Every verdict this phase produces is bounded
   falsification up to (depth, `Bound.t`, fault budget) on ONE VRS scenario.
2. **R3 is asserted STRONGER than upstream proves it** (section 2). A clean R3 is
   a bounded strengthening; a refuted R3 near the seed is the `leads_to` shape and
   must not be reported as a port defect without inspecting the lasso.
3. **A measured-unnecessary premise is NOT a defect in Anvil.** It means this
   bounded, single-reconciler model does not exhibit the counterexample the
   premise excludes. Upstream's premises are for an unbounded proof over an
   arbitrary reconciler. Any write-up saying "premise X is unnecessary" without
   that qualifier is an overclaim, and section 4.5's wording is the one to use.
4. The side-condition checker is bounded-reachable, not universal (4.3).
5. If P15-A holds (family crash-vacuous), the phase's positive content is the
   STRUCTURAL claim plus MA, not a new refutation. Say that plainly rather than
   dressing a negative result as a pass.

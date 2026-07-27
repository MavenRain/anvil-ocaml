# BUILD-SPEC-P14: controller-runtime correspondence (the crash-SENSITIVE invariant family)

Phase 14 of the OCaml port. Branch `p14-correspondence` off `aadf678` (P13).

This phase is pure ASSURANCE CONSTRUCTION with ONE disclosed exception: it adds a
single purely-additive accessor to `lib/cluster/message.mli` (section 4.1). No
transition, no precondition and no existing invariant is changed or weakened.

## 1. The gap this phase closes

P13 shipped a fault-budgeted product system and three decisive crash legs, and
then measured an honest NEGATIVE result, recorded at `BUILD-SPEC-P13.md:309-326`
and in `fault_check.mli`:

> M1 (`restart_controller` keeps `ongoing_reconciles`) and M2 (restart resets the
> allocator) BOTH refute NOTHING. Every member of the shipped suite is
> etcd-local, or monotone in the uid/reconcile-id counters, or about request
> interference. So P13 certifies the shipped invariants ACROSS a crash but does
> NOT certify the faithfulness of the crash TRANSITION.

The diagnosis in that note is exact, and it names the fix: **no shipped
invariant constrains message IDENTITY** (see the MEASURED CORRECTION in section 3
— this originally read "reads a message", which is false and was widened past the
evidence below). `rg pending_req_msg` over `lib/assurance/` and `lib/checker/`
returns only

- `invariants.ml:356 / :692 / :719 / :763` — all inside the VRS `partition`
  closure, and
- `cluster_check.ml:31` — state equality, not an invariant.

The one correspondence predicate the port owns, inv10
`every_msg_from_key_is_pending_req_msg_of` (`invariants.ml:678-703`, upstream
`controller_runtime_safety.rs:911`), is

1. **hard-wired to a single `vrs_ref`** (bound at `invariants.ml:256`), not
   quantified over the ongoing-reconcile map, and not exported individually; and
2. **parked in the `eventually_always` bucket** (`invariants.ml:1008`), whose
   documented contract (`invariants.ml:23-24`, `invariants.mli:92`) is that it
   holds only on the fair suffix and must NOT be asserted after every step —
   i.e. it is asserted only at quiescence on `~fair:true` traces, and therefore
   has never been evaluated on a graph where a crash edge was taken.

Meanwhile the crash transition is precisely the one that breaks the
message/reconcile correspondence. `restart_controller` (`cluster.ml:291-324`):

```
ongoing_reconciles := Object_ref_map.empty     (* :309  every pending_req_msg is dropped *)
scheduled_reconciles := Object_ref_map.empty   (* :310 *)
reconcile_id_allocator := unchanged            (* :311-312 *)
                                               (* s.network            UNTOUCHED *)
                                               (* s.rpc_id_allocator   UNTOUCHED *)
```

so a pre-crash request survives in `s.network.in_flight` with **no owning
reconcile**, and it survives *permanently*: `Controller_step` filters recv
candidates to `dst = Controller (cid, _)` (`cluster.ml:617-624`), but
`continue_reconcile` needs an ongoing reconcile at the key
(`controller.ml:191-204`) and both `run_scheduled_reconcile`
(`controller.ml:138`) and `end_reconcile` (`controller.ml:272`) require
`recv = None`. A post-crash orphan response has no consumer at all.

**P14 ports the invariant family that talks about exactly this**, from upstream
`src/kubernetes_cluster/proof/network.rs` (transcribed verbatim in section 2 —
the upstream tree IS available to this phase, so nothing here is reconstructed
from memory; that retires the "no upstream checkout" faithfulness risk that
constrained earlier phases).

## 2. The ported family (verbatim upstream statements)

All five live in `src/kubernetes_cluster/proof/network.rs`. Quoted bodies are
the upstream Verus text; the OCaml column is the obligation for section 4.2.

### N1 `every_in_flight_msg_has_lower_id_than_allocator` (network.rs:35-41)

```rust
|s: ClusterState| {
    forall |msg: Message|
        #[trigger] s.in_flight().contains(msg)
        ==> msg.rpc_id < s.rpc_id_allocator.rpc_id_counter
}
```

### N2 `every_pending_req_msg_has_lower_id_than_allocator(controller_id)` (network.rs:76-83)

```rust
|s: ClusterState| {
    forall |key: ObjectRef|
        #[trigger] s.ongoing_reconciles(controller_id).contains_key(key)
        && s.ongoing_reconciles(controller_id)[key].pending_req_msg is Some
        ==> s.ongoing_reconciles(controller_id)[key].pending_req_msg->0.rpc_id
              < s.rpc_id_allocator.rpc_id_counter
}
```

### N3 `every_in_flight_req_msg_has_different_id_from_pending_req_msg_of_every_ongoing_reconcile(controller_id)` (network.rs:254-268)

```rust
|s: ClusterState| {
    forall |key: ObjectRef| {
        let pending_req = s.ongoing_reconciles(controller_id)[key].pending_req_msg->0;
        #[trigger] s.ongoing_reconciles(controller_id).contains_key(key)
        && s.ongoing_reconciles(controller_id)[key].pending_req_msg is Some
        ==> {
            forall |msg: Message|
                #[trigger] s.in_flight().contains(msg)
                && msg.content is APIRequest
                && msg != pending_req
                ==> msg.rpc_id != pending_req.rpc_id
        }
    }
}
```

### N4 `every_in_flight_req_msg_from_controller_has_valid_controller_id` (network.rs:312-320)

```rust
|s: ClusterState| {
    forall |msg: Message|
        #[trigger] s.in_flight().contains(msg)
        && msg.content is APIRequest
        && msg.src is Controller
        ==> self.controller_models.contains_key(msg.src->Controller_0)
}
```

### N5 `every_in_flight_msg_has_no_replicas_and_has_unique_id` (network.rs:382-394)

```rust
|s: ClusterState| {
    forall |msg|
        #[trigger] s.in_flight().contains(msg)
        ==> s.in_flight().count(msg) == 1
            && (
                forall |other_msg|
                    #[trigger] s.in_flight().contains(other_msg)
                    && msg != other_msg
                    ==> msg.rpc_id != other_msg.rpc_id
            )
}
```

Upstream derives `every_in_flight_msg_has_unique_id` (network.rs:514-522) from
N5 (`network.rs:530`). The port ships N5, the stronger one; the derived form is
NOT a separate member (shipping both would double the cost of every state visit
for zero discrimination).

**Deliberately OUT of scope: the XOR member.** Upstream
`pending_req_in_flight_or_resp_in_flight_at_reconcile_state`
(`controller_runtime_safety.rs:90-97`, with four
`lemma_xor_preserves_during_*_step` cases at :195/:241/:281/:335) is the natural
sixth member, and it is the one whose OCaml statement cannot be transcribed as a
plain conjunct: the disjunct is genuinely necessary (between api-server handling
and controller delivery the REQUEST is gone and only the RESPONSE is in flight),
and `drop_req` (`cluster.ml:350+`) additionally converts a request into an error
response via `form_matched_err_resp_msg` (`message.ml:331-353`). Stated without
the response disjunct it is false in the crash-FREE graph too, so a refutation
would prove nothing about crashes. It needs `resp_msg_matches_req_msg`
(`message.ml:287-292`) as the disjunct and its own non-vacuity argument.
**Deferring it is a scope decision, not an oversight, and it is the natural
P15.** Do not ship a weakened version of it to pad the family.

## 3. What makes this family CRASH-SENSITIVE, and the prediction that must be measured

The load-bearing claim of the phase, and it is a claim about **direction**:

| leg | expectation | why |
| --- | --- | --- |
| real code, crash budget 0 | clean, decisive, non-vacuous | baseline |
| real code, crash budget 1 | **clean, decisive**, and `gate_states > 0` | the allocator is global and monotone and restart preserves it (`cluster.ml:311-312` preserves the *reconcile* allocator; the *rpc* allocator is a top-level `cluster_state` field, `cluster.ml:23`, that `restart_controller` never rewrites) |
| **mutant MA: restart resets `s.rpc_id_allocator`** | **REFUTED**, at a state with `crashes >= 1`, violating N5 (and/or N1, N3) | a post-crash request reuses the rpc id of a still-in-flight pre-crash message, so two distinct in-flight messages share an id |

That third row is the whole phase. P13 *predicted* an allocator-reset mutant and
*measured* that it refutes nothing (`BUILD-SPEC-P13.md:309-318`) — correctly,
because no shipped invariant constrained message IDENTITY. P14 is the phase that
makes it bite, and the mutation matrix in section 6 must show the flip rather
than assert it.

> **MEASURED CORRECTION (review).** Section 1 and this paragraph originally said
> "no shipped invariant **reads a message**". That is FALSE. Shipped inv9
> `vrs_reconcile_request_only_interferes_with_itself` (`invariants.ml:656-675`)
> quantifies over `Message.Pool.distinct (Cluster.in_flight s)` and sits in
> `Invariants.always` (`always` = `cluster_structural @ [inv9; inv15; inv16]`,
> `invariants.mli:58`); inv8 and inv14 read messages too, and `Vsts_invariants`
> ships a VSTS analogue of inv9. The section-1 EVIDENCE was an
> `rg pending_req_msg` sweep, which supports only the narrower statement — the
> claim was widened past its evidence. The true gap: nothing related a message's
> `rpc_id` to `s.rpc_id_allocator` or to another message's `rpc_id`; `Rpc_id` was
> compared only inside `Message.equal` (`message.ml:142`) and
> `resp_msg_matches_req_msg` (`message.ml:287-292`). **The phase's result is
> unaffected and is arguably sharpened**: P13's suite already read messages and
> still refuted nothing under the crash mutants, so the id dimension — not
> message-reading as such — is what the crash edge perturbs.

**Two directional traps, both of which have already caught this project:**

1. **MA must be confirmed to flip, not merely to redden.** P12's finding #1 was
   a mutation that reddened the pinned COUNT before the semantic assertion, so
   the semantic path had zero coverage and the note misattributed the red
   (`BUILD-SPEC-P12.md` finding 1). Every P14 test asserts outcome/violated
   BEFORE any pinned count, and the MA note must name which assertion fired.
2. **M1 is the WRONG mutant here and must not be reused from P13.** Making
   `restart_controller` *keep* `ongoing_reconciles` leaves the pending request
   and its in-flight copy consistent, so N1-N5 all still HOLD. If a run reports
   M1 refuting this family, that is a bug in the harness, not a finding.

## 4. What to build

### 4.1 `lib/cluster/message.{ml,mli}` — ONE purely additive accessor

N1 and N2 compare an `Rpc_id.t` against the allocator's counter, and
`Rpc_id_allocator` (`message.ml:151-164`) exposes only `init` / `allocate` /
`equal` — the counter is unreadable. Add:

```ocaml
val rpc_id_count : t -> int
```

to `Rpc_id_allocator`, returning `a.rpc_id_counter`.

This is **precedented inside `lib/cluster/` itself**: `Reconcile_id_allocator`
already exposes exactly this accessor as `reconcile_count`
(`controller.ml:48`), and `Cluster_check` already consumes it
(`cluster_check.ml:104-110`). `Rpc_id.to_int` already exists
(`message.mli:24`), so the comparison side needs nothing.

**DISCLOSE the deviation.** P13's discipline was "`lib/cluster/` is not
modified" (`fault_check.mli:18-19`). P14 modifies it by exactly one additive
`val` with no new behaviour, no new state and no changed transition. Say so in
`correspondence.mli` and do not quietly inherit P13's stronger claim.

### 4.2 `lib/assurance/correspondence.{ml,mli}` (NEW — the family)

A new module, NOT new members appended to `Invariants.always`. Exports:

```ocaml
val family : controller_id:int -> Invariants.invariant list   (* N1..N5, in order *)
val in_flight_lower_than_allocator : Invariants.invariant                  (* N1 *)
val pending_req_lower_than_allocator : controller_id:int -> Invariants.invariant  (* N2 *)
val in_flight_req_id_differs_from_pending : controller_id:int -> Invariants.invariant (* N3 *)
val in_flight_req_from_controller_valid_id : Cluster.t -> Invariants.invariant     (* N4 *)
val in_flight_unique_id : Invariants.invariant                             (* N5 *)
```

Each is an `Invariants.invariant` record (`invariants.ml:50-55`): `name` = the
upstream spec-fn name verbatim, `source` = `"kubernetes_cluster/proof/network.rs:<line>"`,
`holds`, `interesting`.

**Why a separate module and a separate list (non-negotiable).**
`Vsts_invariants.always` feeds BOTH the fault-free legs in `cluster_check.ml`
AND P13's G1 at `fault_check.ml:318`. Appending to it would change P13's pinned
counts (464 / 152 states, gate 388 / 76 —
`BUILD-SPEC-P13.md:311-313`) and silently rewrite a shipped, committed result.
**P13's pins must come through P14 byte-identical**; a regression test asserts
this (section 4.5).

`interesting` per member — this is the anti-vacuity contract, and every one of
these must be MEASURED non-zero, not assumed:

- N1, N5: `Message.Pool.cardinal (Cluster.in_flight s) >= 1` (N5 additionally
  wants `>= 2` distinct messages to be discriminating; use `>= 2`).
- N2, N3: some key of `Cluster.ongoing_reconciles s controller_id` has
  `pending_req_msg = Some _`.
- N4: some in-flight message has `src = Controller _` and an `Api_request`
  content.

House idiom is mandatory and already exemplified at `invariants.ml:276-303`:
exhaustive matches on `host_id` / `message_content` with **no `_ ->` arm**,
`Option.fold` rather than a two-arm `match` on an option, and
`Message.Pool.distinct` to iterate the multiset. N5's replica conjunct is the
one place `Message.Pool.count` is genuinely needed — `distinct` is not enough to
state `count msg == 1`.

### 4.3 `lib/checker/fault_check.{ml,mli}` — one new leg

```ocaml
val check_correspondence_under_faults :
  ?depth:int -> Bound.t -> budget -> desired:int -> fault_report
```

Reuse `run_leg` (`fault_check.ml:268-300`) verbatim — it already does
explore / check / metadata / project. Mirror G1
(`fault_check.ml:309-332`) exactly:

- `seed = Scenario.vsts_seed_faults ~desired ~crash:<param> ~req_drop:false ~pod_monkey:false`;
- `check` = `Model_check.check_safety` over
  `Invariants.conjunction (Correspondence.family ~controller_id)` lifted
  pointwise (`fun f -> inv f.cs`);
- `violated` = `violated_of` the family, so a refutation NAMES the member;
- `gate` = states with `f.crashes >= 1 && <some member's interesting fires>` —
  the post-crash non-vacuity witness.

The crash dimension is selected by the caller's `budget`
(`budget_crash_only` vs a `max_crashes = 0` budget), so ONE entry point serves
both legs of section 5 and the two runs are directly comparable.

### 4.4 The gates

- **G1 crash-DISABLED** (`{max_crashes=0; max_drops=0; max_monkey_ops=0}`):
  family clean + decisive, `gate_states`-analogue non-zero via each member's
  `interesting`. Establishes the family is non-vacuous *before* any crash, so a
  later clean crash verdict is not clean-by-emptiness.

  > **MEASURED CORRECTION (this phase, and it is the phase's second result).**
  > The sentence above is TRUE for N1-N4 and **FALSE for N5**. Measured on the
  > G1 graph (76 states): N1/N2 `interesting` fire in 32 states, N3 and N4 in 16,
  > **N5 in 0**. Fault-free, this scenario is strict request/response lock-step,
  > so at most one message is ever in flight and N5's `cardinal >= 2` premise is
  > UNREACHABLE.
  >
  > **MEASURED anti-artifact evidence (review finding).** Arguing that zero
  > against `max_in_flight = 8` alone was too weak: that ceiling is provably
  > non-binding, while the ceiling this run actually prunes by is
  > `reconcile_ceiling = 2` (it is the sole source of the G1 report's
  > `pruned_by_ceiling = true`), and nothing varied it. Swept now, on the G1 leg:
  > `reconcile_ceiling` 2 -> 76 states / gate 32, 3 -> 112 / 48, 4 -> 148 / 64
  > (at depth 60), 6 -> 220 / 96 (at depth 100) — all clean and DECISIVE, and
  > **N5's count is 0 at every one**. Stronger still, the largest in-flight
  > cardinal over the whole crash-free graph is **1** at every ceiling, so the
  > `>= 2` premise is structurally unreachable fault-free rather than merely
  > unreached at this bound. N5's vacuity is NOT a bound artifact and the second
  > result stands. (Disclosed: at `reconcile_ceiling = 4` with the shipped
  > depth 40 the run is not decisive and `pruned_by_ceiling` flips to false —
  > depth binds before the ceiling does — so the high legs use a raised depth.)
  >
  > The companion measurement turns the exception into the phase's sharpest
  > result rather than a defect: on the G2 graph N5 fires in 84 states and its
  > POST-CRASH count is also **84**. Every state exercising N5 is post-crash, so
  > **the crash edge is the only source of two concurrently in-flight messages in
  > this bounded graph** — which is exactly why MA bites and why N5 is the member
  > that could ever see a collision. Both facts are asserted in
  > `t_p14_correspondence.ml`, not merely commented.
  >
  > Consequence for the reading of G1: it is the non-vacuity floor for the
  > id-ordering members (N1-N4), NOT for the uniqueness member. N5's floor is
  > G2's 84, and N5 is checked vacuously whenever no crash is budgeted.
- **G2 crash-ENABLED** (`budget_crash_only`): family clean + decisive,
  `crash_witness_states > 0`, and `gate_states > 0` = states that are post-crash
  AND exercise a member. This is the phase's headline.
- **G3 the discriminator, permanent and automated**: a hand-forged reachable
  state carrying two distinct in-flight messages that share an `rpc_id` must be
  `Refuted` by N5, and the same harness with distinct ids must return
  `No_counterexample`. This is P12's `test_gate_refutes_forged_collision`
  pattern (`BUILD-SPEC-P12.md` finding 1) and it is what keeps the family's
  Refuted path covered when MA is reverted.

### 4.5 Tests

- `test/p14_witness.ml` — shared non-test module: the P14 bound, `desired`, and
  every pinned count in ONE place (P12 NIT-4 / `p12_witness.ml` precedent).
- `test/t_p14_correspondence.ml` — G1, G2, per-member `interesting`-fires
  counts, robustness (achieved maxima strictly below ceilings where claimed).
- `test/t_p14_mutation.ml` — G3 forged-collision discriminator + the MA
  automated pins.
- `test/t_p14_regression.ml` (or a case inside the above): **P13's G1/G2/G3
  reports are byte-identical to their committed pins.** This is the firewall for
  the classification risk in 4.2.
- `test/dune` — add the three names.

## 5. Tractability

The binding constraint is measured, not guessed: P13's crash-only leg is 1856
states / 0.56 s CPU, but `budget_default` at depth 16 is 34990 crash-witness
states / 85 s CPU / 1 m 36 s wall, and one `reconcile_ceiling` raise cost 4 m 56 s
(`fault_check.mli:226-264`). P14 additionally faces a NEW inflation source:
post-crash orphan messages never drain (section 1), so `max_in_flight` binds
harder here than in any prior phase.

Therefore: start from the P13 crash-only shape (`desired = 1`,
`reconcile_ceiling = 2`, depth 40), keep `max_drops = max_monkey_ops = 0`, and
if a run does not close, retune `max_in_flight` FIRST and **disclose every
retune with its measured before/after**, per `fault_check.mli:333-344`. Run
every exe under `perl -e 'alarm 150; exec @ARGV'`; a 150 s alarm kill is a
tractability datum to report, never a silent retry at smaller bounds.

## 6. Confirm-by-mutation matrix

Every row must be OBSERVED, and each row names the assertion that fires.

| id | mutation | applied to | expected |
| --- | --- | --- | --- |
| MA | `restart_controller` resets `s.rpc_id_allocator` to `Rpc_id_allocator.init ()` | `lib/cluster/cluster.ml:299-323` | **G2 flips clean -> Refuted**, `violated = Some "every_in_flight_msg_has_no_replicas_and_has_unique_id"` (or N1/N3), counterexample state has `crashes >= 1`. THE headline. |
| MB | N5's uniqueness conjunct weakened to `true` | `correspondence.ml` | G3 forged-collision test goes red (the discriminator discriminates) |
| MC | N1's `<` weakened to `<=` | `correspondence.ml` | must NOT change any verdict — `<=` is implied by `<`; a change here means the harness is reading the wrong counter |
| MD | every member's `interesting` forced `false` | `correspondence.ml` | every `interesting`-fires pin goes to 0 (proves the pins are real counts, not constants) |
| M1 | `restart_controller` KEEPS `ongoing_reconciles` | `lib/cluster/cluster.ml` | **refutes NOTHING** (section 3 trap 2). Assert the negative. |

**REVISED IN REVIEW.** Three rows above were audited and found to be
un-falsifiable or under-covered; the shipped matrix is the one below, and each
row names the assertion actually SEEN to fire.

| id | mutation | applied to | OBSERVED red |
| --- | --- | --- | --- |
| N2 | N2's `holds` neutered to `fun _ -> true` | `correspondence.ml` | `N2 REJECTS a pending request whose rpc_id is NOT below the allocator counter` |
| N3 | N3's `holds` neutered to `fun _ -> true` | `correspondence.ml` | `N3 REJECTS an in-flight api request that shares the pending request's rpc_id` |
| N4 | N4's `holds` neutered to `fun _ -> true` | `correspondence.ml` | `N4 REJECTS an in-flight api request from a controller id that is NOT in controller_models` |
| MC' | N1 compares against a CONSTANT counter instead of `allocator_count s` | `correspondence.ml` | `MC: N1 REJECTS the state whose LIVE counter EQUALS it — same message, only s.rpc_id_allocator moved`. This is the failure mode the OLD MC row claimed to detect and provably could not: `<` implies `<=`, so the weakened member can never refute where the strong one did not, and that row could not fail. |
| MD' | a member's `interesting` widened (trivially true, and separately a real weakening) | `correspondence.ml` | `MD: PERTURBING each member's interesting … STRICTLY GREATER` and `MD: re-deriving each count from the LIVE family reproduces the five pins`. The OLD MD row (blind every `interesting` to `false`, assert the counts are 0) was a TAUTOLOGY: a predicate false everywhere counts 0 on any graph, and it never touched the pins it claimed to validate. |
| ME' | `violated_of`'s `Refuted` branch returns the head of the list rather than `first_violated` | `fault_check.ml` | `ME: violated_of names the PLANTED member`. Covers the leg's `violated` naming path, which no automated test observed non-`None` before (the leg itself cannot be driven red without MA, since every free parameter of it only PRUNES the reachable set). |
| F6 | N5's `interesting` weakened to `cardinal >= 1` | `correspondence.ml` | `sweep: N5's interesting count is STILL 0 at the raised reconcile ceiling` |

Mutations to `lib/cluster/` are applied under a trap-restore and the tree is
verified clean afterwards (`git status --short` on `lib/cluster/` empty), per
`feedback-review-agents-may-leave-mutations`. Never `git checkout` a file that
holds unstaged fixes (`BUILD-SPEC-P12.md` process lesson).

## 7. Convention firewall (non-negotiable)

- Exhaustive matches on every finite sum; **no `_ ->` arm** anywhere, including
  `host_id` and `message_content`.
- No two-arm `match` on `option` / `result` — `Option.fold`, `Option.map`,
  `Option.is_none`.
- No loop keywords, no `Iterator::scan` analogue, no vector mutation: fold /
  `List.exists` / `List.for_all` over `Message.Pool.distinct`.
- Doc comments on every exported item in every `.mli`.
- `dunecho build` must end 0 errors / 0 warnings.
- Nothing is committed (`feedback_never_commit`): stage and hand over.

## 8. Honest limits (bake into code and docs)

- Bounded falsification up to (`depth`, `Bound.t`, `budget`). Transfers no part
  of Anvil's Verus theorem; upstream PROVES these five inductive, P14 only fails
  to refute them on a finite reachable set.
- The XOR member is NOT shipped (section 2), so "correspondence" here means the
  **id-level** correspondence, not the full request/response lifecycle. Say
  "id-level" wherever the family is described; do not let "correspondence"
  silently widen.
- A clean G2 is evidence that the crash transition preserves id discipline; it
  is NOT evidence that the crash transition is faithful in every other respect.
  P13's negative result is narrowed by this phase, not erased.
- The `lib/cluster/` accessor deviation (4.1) is disclosed, not hidden.

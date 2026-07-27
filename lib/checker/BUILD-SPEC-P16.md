# BUILD-SPEC-P16: response/etcd correspondence, and the first legs that take a drop or a monkey edge

Phase 16 of the anvil-ocaml port. Follows P15
(`BUILD-SPEC-P15.md`, committed on `main` @ `2c07fd1`), which followed P14
(`f56b4cf`) and P13 (`aadf678`).

Branch: `p16-req-resp-correspondence` off `2c07fd1`.
Upstream reference: `~/Documents/anvil-ref` (durable since P15).
Primary upstream file: `src/kubernetes_cluster/proof/req_resp.rs`.

---

## 1. The gap this phase closes

P13 built a fault budget as a **product state** `{cs; crashes; drops; monkeys}`
and enumerated all twelve upstream cluster actions. P14 and P15 then used that
machinery to settle the crash dimension:

- P14 (network-guarded, `proof/network.rs` N1-N5): the crash edge PRESERVES
  `s.network` and `s.rpc_id_allocator`, and mutant MA (restart also resets the
  allocator) flips the leg to `Refuted`.
- P15 (reconcile-guarded, `controller_runtime_{safety,liveness}.rs` R1-R4): the
  crash edge DESTROYS `ongoing_reconciles`, so the unmutated crash refutes
  nothing and only the gate counts move.

Together those two phases established the structural thesis: **crash sensitivity
is determined by WHERE an invariant's guard lives, not by what the invariant
says.**

**The gap is that the thesis was only ever tested on ONE of the three fault
dimensions.** P15 measured, and disclosed in `fault_check.mli`, that the
`req_drop` and `pod_monkey` premises were *vacuous at the leg*: every shipped
fault leg seeds
`Scenario.vsts_seed_faults ~crash:true ~req_drop:false ~pod_monkey:false`
(`fault_check.ml:315`, `:368`, `:472`, `:507`) and the three fault flags only
ever flip `true -> false` (`Disable_*`, `cluster.ml:337`, `:385`, `:445`), so
**budget variation alone can never take a drop or a monkey edge.** P15 had to
fall back on supplementary flag-enabled probes run outside the legs.

So as of `2c07fd1`:

- No shipped leg has ever taken a `Drop_req_step` or a `Pod_monkey_step`.
- No mutation matrix in P13, P14 or P15 has ever mutated `drop_req` or
  `pod_monkey_next`. Every mutant so far (M1, M2, MA) targets
  `restart_controller`.
- No shipped invariant, in any suite, reads a response message's BODY or relates
  a message to `s.api_server` at all. (P14's N-family reads `rpc_id`s; P15's
  R-family reads `pending_req_msg` identity. Neither opens a response.)

P16 closes all three at once, by porting the upstream family whose guard lives
in the third home.

**Scouting evidence** (9-agent read-only sweep, `wf_68295025-8b5`, 0 errors;
every claim below re-verified by hand before this spec was written):

| Fact | Anchor |
| --- | --- |
| `vsts_seed_faults` builds its CR with `vsts ~desired ()`, i.e. `?vct` defaulting `false` | `scenario.ml:352`, `scenario.ml:249` |
| therefore `state.pvcs = []`, and the only `Get_request` producer is `Create_pvc`/`Get_pvc` behind `state.pvc_index < List.length state.pvcs` | `v_stateful_set_reconciler.ml:580`, `:603-611` |
| the POD create (`Create_needed`) is NOT vct-gated and fires at `desired = 1` | `v_stateful_set_reconciler.ml:641-649` |
| no shipped reconciler ever issues a plain `Update_request` (only `Get_then_update*`) | `v_stateful_set_reconciler.ml:697`, `v_deployment_reconciler.ml:335`, `:376`, `vreplica_set_reconciler.ml:179` |
| `form_matched_err_resp_msg` fabricates `{ res = Error err }` on ALL NINE request arms and keeps the request's `rpc_id` | `message.ml:339-357`, `:199-200` |
| the four pod-monkey ops write NEITHER etcd NOR `s.api_server`: each only sends a request and advances the allocator | `pod_monkey.ml:57-69`, `cluster.ml:401-426` |
| `budget` already carries `max_drops` / `max_monkey_ops` and `fault_report` already carries `max_drops_seen` / `max_monkeys_seen` | `fault_check.mli:81`, `:84`, `:194`, `:196` |

That last row is the reason this phase is small in the checker and large in the
assurance library: **the product machinery for drops and monkeys was built in
P13 and has simply never been switched on.** The blocker was always the seed.

---

## 2. The ported family (verbatim upstream statements)

All five upstream statements are `always` invariants. Every lemma requires only
`init` + `always(next)` plus, for the three matched members,
`self.controller_models.contains_key(controller_id)` and
`key.kind is CustomResourceKind`. **None of them requires a fault-disabled
premise** (`req_resp.rs:26-28`, `:81-83`, `:152-156`, `:258-262`, `:364-368`) —
upstream discharges `DropReqStep` inside the proof instead, at `:217-225`,
`:322-330` and the `:429-437` region, each time via `res is Err`. That is the
single conjunct this phase makes executable.

The family SPLITS INTO TWO LISTS by guard home. This is not cosmetic: it is the
thesis under test, and the two lists must be asserted on separate legs.

### List A — `rv_family` (network + etcd guarded, no reconcile read)

#### Q1 `object_in_ok_get_response_has_smaller_rv_than_etcd` (req_resp.rs:14-22)

```
|s: ClusterState| {
    forall |msg: Message|
        s.in_flight().contains(msg)
        && #[trigger] is_ok_get_response_msg()(msg)
        ==> msg.content.get_get_response().res->Ok_0.metadata.resource_version is Some
            && msg.content.get_get_response().res->Ok_0.metadata.resource_version->0
               < s.api_server.resource_version_counter
}
```

Nullary. Port over `Message.Pool.distinct (Cluster.in_flight s)`, reading
`s.api_server.resource_version_counter` directly (`api_server.mli:24-28`, a
public record field — unlike P14 this phase needs NO new accessor and must not
add one).

`interesting`: at least one in-flight OK get response exists.

> Upstream marks this lemma `// TODO: investigate flaky proof` (`req_resp.rs:24`).
> The STATEMENT is authoritative for the port; the `.mli` must note the upstream
> flakiness rather than citing the proof as solid.

#### Q2 `object_in_ok_get_resp_is_same_as_etcd_with_same_rv(key)` (req_resp.rs:69-78)

```
|s: ClusterState| {
    forall |msg|
        #[trigger] s.in_flight().contains(msg)
        && is_ok_get_response_msg_and_matches_key(key)(msg)
        && s.resources().contains_key(key)
        && s.resources()[key].metadata.resource_version->0
           == msg.content.get_get_response().res->Ok_0.metadata.resource_version->0
        ==> s.resources()[key] == msg.content.get_get_response().res->Ok_0
}
```

Universally closed over the bound keys, P15's disclosed strengthening: ship it as
`forall key in <bound key set>`, and say so in the `.mli`.

`interesting`: some in-flight OK get response matches a key present in
`s.api_server.resources` with equal resource version.

### List B — `matched_family` (reconcile-COUPLED: reads `pending_req_msg`)

#### Q3 `key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_pending_req(controller_id, key)` (req_resp.rs:136-149)

```
forall |msg: Message|
    #[trigger] s.in_flight().contains(msg)
    && is_ok_get_response_msg()(msg)
    && s.ongoing_reconciles(controller_id).contains_key(key)
    && s.ongoing_reconciles(controller_id)[key].pending_req_msg is Some
    && resp_msg_matches_req_msg(msg, s.ongoing_reconciles(controller_id)[key].pending_req_msg->0)
    ==> is_ok_get_response_msg_and_matches_key(
            s.ongoing_reconciles(controller_id)[key].pending_req_msg->0.content.get_get_request().key)(msg)
```

#### Q5 `key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req(controller_id, key)` (req_resp.rs:345-361) — THE HEADLINE

Same shape with `is_ok_create_response_msg()`, and one extra antecedent unique to
this member: `create_req.obj.metadata.name is Some` (generate-name creates are
excluded upstream). Upstream's trigger sits on `resp_msg_matches_req_msg`, not on
`in_flight().contains`.

`Message.resp_msg_matches_req_msg` already exists (`message.mli:242`) — use it,
do not re-derive the matching relation.

### DELIBERATELY EXCLUDED, and why (do not "complete the family")

#### Q4 `key_of_object_in_matched_ok_update_resp_message_is_same_as_key_of_pending_req` (req_resp.rs:240-255)

**Structurally unreachable in every controller and every fault configuration in
this port.** No shipped reconciler issues a plain `Update_request` — VSTS, VRS
and VDeployment all use `Get_then_update*`, which produces the DISTINCT
`Get_then_update_response` constructor. The only other producer of an OK update
response would be a pod-monkey `Update_pod` request, whose response carries the
MONKEY's freshly-allocated `rpc_id` (`pod_monkey.ml:60-67`) and therefore cannot
satisfy `resp_msg_matches_req_msg` against a controller's pending request without
violating P14's already-shipped `every_in_flight_msg_has_unique_id`.

Shipping Q4 load-bearing would reproduce P14's N5 failure exactly: a member whose
premise is unreachable, whose "clean" verdict is empty, and whose per-member
count is 0 on every graph.

**This exclusion must be MEASURED, not asserted** (the P14 N5 lesson, applied
prospectively for the first time). Section 4.6 requires a test that pins the
structural fact directly. If that test ever reddens — because a future controller
gains a plain `Update_request` — Q4 becomes portable and the exclusion note must
be revisited.

---

## 3. The predictions that must be measured

Write each of these down before running anything, and record it as measured or
refuted. Never quietly drop one.

Fault write-sets, read out of the source and cross-checked by two scout probes:

| transition | writes | leaves untouched |
| --- | --- | --- |
| `restart_controller` (`cluster.ml:291-324`) | `controller_and_externals` only | `api_server`, `network`, `rpc_id_allocator` |
| `drop_req` (`cluster.ml:348-386`) | `network` only | `api_server`, `rpc_id_allocator`, `ongoing_reconciles` |
| `pod_monkey_next` (`cluster.ml:401-438`) | `network`, `rpc_id_allocator` | `api_server` (!), `controller_and_externals` |

**Nothing writes `s.api_server` except a real `Api_server_step`.** Etcd is
therefore perturbable by a fault only TRANSITIVELY: the monkey injects a request
into the network, and a later api-server step applies it.

- **P16-A (rv_family x crash).** The crash edge cannot perturb Q1 or Q2: it
  writes neither `network` nor `api_server`. Predict CLEAN, with gate counts
  moving only because the reachable set grows. This extends the P14 side of the
  thesis to a family that reads etcd.
- **P16-B (matched_family x crash).** Q3 and Q5 read `ongoing_reconciles`, so the
  crash VACUATES them exactly as it vacuates P15's R-family. Predict clean, with
  the post-crash slice of the gate collapsing.
- **P16-C (family x drop) — the knife-edge.** `drop_req` writes the guarded field
  (`network`) with guard-ADJACENT content: the fabricated response inherits the
  request's `rpc_id`, so it SATISFIES `resp_msg_matches_req_msg` against the
  pending request. The **only** reason it cannot instantiate Q3 or Q5 is the
  `is_ok_*` conjunct, because `form_matched_err_resp_msg` fabricates
  `{ res = Error err }` on every arm. Predict the unmutated drop leg CLEAN, and
  predict that mutation MD (section 6) flips it to `Refuted` naming Q5. This is
  the drop analogue of P14's MA, and it is the phase's headline.
- **P16-D (rv_family x monkey).** The monkey is the only SECOND WRITER to etcd in
  this model. Q2 says two objects with the same key and the same resource version
  are identical; that is refutable only if some writer can reuse a resource
  version. Predict the unmutated monkey leg CLEAN, and predict that mutation MS
  refutes Q2 on the monkey leg and ONLY on the monkey leg.
- **P16-E (the vacuity floor).** Under the shipped `vct:false` seed, Q1, Q2 and
  Q3 are VACUOUS (no `Get_request` is ever issued, so no OK get response can
  exist) and only Q5 is non-vacuous. Predict `interesting = 0` for Q1/Q2/Q3 at
  `vct:false` and `> 0` at `vct:true`. **This is a prediction of vacuity and it
  must be measured, not argued** — it is the mechanism P14's N5 taught.

If any leg reports `max_drops_seen = 0` on a drop leg or `max_monkeys_seen = 0`
on a monkey leg, that leg is vacuous for its own dimension and no verdict from it
may be reported. That check is not optional; it is the exact failure P15
disclosed and this phase exists to fix.

---

## 4. What to build

### 4.1 `lib/cluster/` is NOT modified

P14 added one accessor and disclosed the deviation. P16 needs nothing: every
field Q1-Q5 read (`api_server.resources`, `api_server.resource_version_counter`,
`Cluster.in_flight`, `Message.resp_msg_matches_req_msg`) is already public.
`git diff --cached --name-only lib/cluster/` must be EMPTY at hand-over — the
mutations in section 6 are applied and reverted with `Edit`, never left in.

### 4.2 `lib/assurance/req_resp_correspondence.{ml,mli}` (NEW)

Exports, each with a `source` string resolving in `~/Documents/anvil-ref`:

```
val object_in_ok_get_response_has_smaller_rv_than_etcd : Invariants.invariant
val object_in_ok_get_resp_is_same_as_etcd_with_same_rv : Bound.t -> Invariants.invariant
val key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_pending_req :
  controller_id:int -> Invariants.invariant
val key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req :
  controller_id:int -> Invariants.invariant

val rv_family : Bound.t -> Invariants.invariant list
val matched_family : controller_id:int -> Invariants.invariant list
```

Local helper predicates (private, not exported unless a test needs them):
`is_ok_get_response`, `is_ok_create_response`, `ok_get_response_object`,
`response_object_key`. `Dynamic_object.object_ref` is `result`-valued, so key
comparison folds the `result` (`Result.fold`) rather than assuming totality —
upstream's `ObjectRef` is total and ours is not, and that difference must be
handled explicitly and documented, not papered over.

Conventions: combinators only, exhaustive matches on the finite response sum, no
two-arm `match` on `option`/`result`, doc comment on every exported item.

### 4.3 `Scenario.vsts_seed_faults` gains `?vct`

```
val vsts_seed_faults :
  desired:int -> crash:bool -> req_drop:bool -> pod_monkey:bool ->
  ?vct:bool -> unit -> Cluster.cluster_state
```

(or `?vct` in leading position with the existing trailing labelled args, whichever
keeps OCaml's optional-argument erasure satisfied without adding `unit`.)

**Default `false`, so every committed pin is byte-identical.** This is the
regression firewall: P13's 464/152/388/76, P14's 76/32 and 464/296, P15's
76/64 and 464/304/388/76 all flow through this function, and a moved default
would silently move all of them.

The existing legs keep their literal `~req_drop:false ~pod_monkey:false`. They
are NOT re-pointed at the new parameters.

### 4.4 `Fault_check.check_req_resp_under_faults` (NEW)

```
val check_req_resp_under_faults :
  ?depth:int ->
  ?req_drop:bool ->
  ?pod_monkey:bool ->
  ?vct:bool ->
  Bound.t -> budget ->
  desired:int ->
  list_select:list_select ->
  require_fault:bool ->
  fault_report
```

with `type list_select = Rv_list | Matched_list` (a sum, not a bool — the two
lists are asserted SEPARATELY and never unioned).

Built on the existing private `run_leg`, exactly as the P15 leg is: same
pointwise lift `fun f -> inv f.cs`, same `violated_of`, same `default_depth`.

**The masking discipline (mandatory).** Never union `rv_family` with
`matched_family`, and never union either with `Correspondence.family`,
`Reconcile_correspondence.family`, `Invariants.always` or
`Vsts_invariants.always`. Under MD, Q5 is the intended witness; a unioned leg
could report a P14 member first and mask the phase's headline. **A `violated`
naming any non-P16 member is a harness bug, not a finding.**

`require_fault` selects the gate the way P14/P15's `require_crash` does:
`false` counts states where some member's `interesting` fires; `true`
additionally requires the leg's own fault counter to be `>= 1` (`crashes`,
`drops` or `monkeys` according to which the budget permits).

### 4.5 `check_reconcile_correspondence_under_faults` gains `?req_drop ?pod_monkey`

Purely additive, defaults `false`. This discharges P15's own named P16 candidate
(a): with it, P15's premise-necessity matrix becomes exercisable AT THE LEG
instead of only at supplementary probes. Re-measure the two premises P15 could
only probe indirectly and record the result in `fault_check.mli` next to P15's
existing disclosure, whichever way it comes out.

Do the same for `check_correspondence_under_faults` if and only if it costs
nothing; it is not required.

### 4.6 The measurement matrix

All at `P13_witness.p13_bound`, `depth = 40`, `desired = 1`, each list asserted
alone:

| Leg | seed flags | budget | purpose |
| --- | --- | --- | --- |
| L0 | none | `zero_budget` | non-vacuity floor, fault-free |
| Lc | `crash:true` | `budget_crash_only` | P16-A / P16-B |
| Ld | `req_drop:true` | `{0; 1; 0}` | **first drop edge in a decisive leg** |
| Lm | `pod_monkey:true` | `{0; 0; 1}` | **first monkey edge in a decisive leg** |
| L0v / Ldv | `vct:true` (+ drop) | as above | de-vacuify Q1/Q2/Q3 (P16-E) |

Record per leg: `states`, `gate_states`, `violated`, decisiveness,
`max_drops_seen`, `max_monkeys_seen`, `crash_witness_states`,
`fault_free_states`, `pruned_by_ceiling`, `pruned_by_budget`, **and a per-member
`interesting` count**. The per-member counts are what make P16-E a measurement;
P14's N3 shipped a borrowed `interesting` and its count was therefore not
evidence the member had ever been evaluated.

Cross-check: L0's state count at `vct:false` must equal P14 G1 / P15 L0's 76.
A disagreement means the seed drifted — investigate before reporting anything.

### 4.7 Tests

- `test/p16_witness.ml` — every pin, single-sourced.
- `test/t_p16_req_resp.ml` — the leg measurements, the per-member `interesting`
  pins, and the drop/monkey EDGE-TAKEN assertions (`max_drops_seen >= 1`,
  `max_monkeys_seen >= 1`).
- `test/t_p16_mutation.ml` — the section-6 matrix.
- `test/t_p16_regression.ml` — the classification firewall: P13/P14/P15 witness
  constants unchanged; the P16 lists disjoint from every shipped suite AND from
  each other; **the Q4 structural-vacuity pin** (assert that no shipped
  reconciler's reachable request set contains a plain `Update_request`, driven
  off the real reconcilers rather than a comment); and a test that
  `vsts_seed_faults` with defaults is value-identical to the pre-P16 call.

---

## 5. Tractability

Per-state cost is one `Message.Pool` fold per member, plus for Q2 a bound-key
loop with an `Object_ref_map` lookup each. Cheaper than P15's R3, which needed a
pool fold per ongoing reconcile.

The bound to watch is `max_in_flight`, and for a NEW reason: this is the first
phase whose legs take drop and monkey edges, and a monkey edge INJECTS a message
without consuming one. P14 predicted post-crash orphan inflation would bind and
measured that it did not — **do not inherit that non-result across a different
fault dimension.** Measure it on Lm specifically, and if a retune is needed
report before/after rather than silently raising it. `vct:true` additionally puts
a second kind (PVC) into etcd and two more request/response pairs per round into
the pool; if a bound clips the OK-get states, the get family goes quietly vacuous
inside a passing leg. The section-4.6 per-member counts are what catch that.

---

## 6. Confirm-by-mutation matrix

Every mutation is applied and then reverted with `Edit`, never `git checkout`
(the P12 process lesson). A test never SEEN to fail is not evidence.

| Id | Mutation | Must redden |
| --- | --- | --- |
| **MD** | `form_matched_err_resp_msg`'s `Create_request` arm returns `{ res = Ok <obj> }` instead of `Error` (`message.ml:346`) | **Ld flips clean -> Refuted naming Q5.** The headline. |
| **MS** | the api-server write path reuses the old `resource_version` instead of stamping a fresh one | Q2, on Lm and ONLY on Lm (P16-D) |
| MR | the api-server write path does not bump `resource_version_counter` | Q1, on any leg with an OK get response (L0v) |
| MA | P14's allocator reset in `restart_controller` | **NOTHING** — negative control, cross-phase consistent with P14/P15 |
| MB | Q5's key-equality consequent deleted | its forged state |
| MC | Q1's `<` weakened to `<=` | its forged state |
| ME | Q3's `resp_msg_matches_req_msg` antecedent deleted | its forged state |

**Forge one per-member violating state**, so that trivializing any member's
`holds` to `fun _ -> true` cannot leave the battery green. **Audit every forged
test for tautology and for entailment before shipping it** — P14 shipped MD as a
tautology and MC as logically entailed, and review caught both. MC in particular
is the shape that already failed once: `<` implies `<=`, so a state that
witnesses the weakening must have `rv = counter` exactly.

MD's converse control matters as much as MD: the UNMUTATED drop leg must be
clean, and clean *for the stated reason* (`res = Error`), not clean because the
drop edge was never taken. Assert `max_drops_seen >= 1` in the same test.

---

## 7. Convention firewall (non-negotiable)

- Combinators over loops; exhaustive matches on finite sums; no `match` on
  `option`/`result`; no vector mutation; no `_ ->` wildcard on a finite sum.
- Doc comments on every exported item.
- Never commit: stage and hand over the commit message.
- Every `source` string must resolve in `~/Documents/anvil-ref`. Spot-check Q1's
  and Q5's by opening the cited lines.
- `lib/cluster/` diff must be empty at hand-over.

---

## 8. Honest limits (bake into code and docs, not just here)

1. Nothing here is PROVED. Upstream proves all five statements `always` in
   Verus. Every verdict this phase produces is bounded falsification up to
   (depth, `Bound.t`, fault budget) on one VStatefulSet scenario.
2. **Q4 is excluded as structurally vacuous IN THIS PORT.** That is a statement
   about the shipped reconcilers, not a claim that upstream's statement is
   redundant. Word it that way everywhere.
3. Q2 is universally closed over bound keys where upstream parameterizes by a
   single `key`. That is a strengthening; disclose it.
4. **A clean drop or monkey leg is a NEGATIVE result and must be reported as
   one.** The phase's positive content is (a) the third guard class, (b) the
   first legs that take drop and monkey edges at all, and (c) mutations MD and
   MS. Do not dress a clean leg as a pass.
5. Upstream's lemma for Q1 is marked flaky by its own authors
   (`req_resp.rs:24`). Cite the statement, not the proof.
6. The `?vct` seed variant changes the scenario, so its counts are NOT
   comparable with P13/P14/P15's pins. Only the `vct:false` legs cross-check.

# BUILD-SPEC-P12 — Concurrent-reconcile assurance (de-vacuify `every_ongoing_reconcile_has_unique_id`)

Normative, self-contained contract. Phase 12 of the anvil-ocaml port. Hand-authored
from the P12 scout (`wf_a59d8ca0-7b3`, 6 read-only agents, `agents_error=0`). Follows
P11 (`9580ea2`, VSTS assurance). Branch `p12-concurrent-reconcile` off `9580ea2`.

Build env: `eval $(opam env --switch=anvil-ocaml --set-switch); dunecho build` (expect
0/0). `dune test` HANGS — run exes directly: `perl -e 'alarm 150; exec @ARGV'
_build/default/test/<name>.exe`. Whole battery: bash `for e in
_build/default/test/*.exe; do perl -e 'alarm 150; exec @ARGV' "$e" || echo "FAIL $e";
done`.

---

## 0. The honest framing (state this in code + docs; do NOT overclaim)

P12 is an **assurance-construction** phase, NOT a cluster-model extension. The scout
established (verbatim) that the P2 transition system **already represents ≥2 concurrent
in-flight reconciles of ONE controller** with no code change:

- `Controller.state.ongoing_reconciles : ongoing_reconcile Object_ref_map.t` is keyed
  by cr `object_ref` (controller.ml:66-69), NOT a single `Option`.
- `run_scheduled_reconcile` precondition (controller.ml:131-141) gates on
  `not (Object_ref_map.mem cr_key s.ongoing_reconciles)` — **per-cr-key**, so a
  *different* cr_key may be run while the first is still ongoing.
- `schedule_controller_reconcile` (cluster.ml:250-287) has no uniqueness guard;
  `enabled_successors`' `schedule_steps` (cluster.ml:654-661) ranges over ALL etcd keys
  of the controller kind capped by `max_objects_per_kind`, and `controller_steps`
  (cluster.ml:630-635) ranges over scheduled+ongoing keys.
- Each `run_scheduled_reconcile` allocates a fresh `reconcile_id` via the per-controller
  `Reconcile_id_allocator.allocate` (controller.ml:153-161).

So the trace `schedule vsts1 → run vsts1 → schedule vsts2 → run vsts2` reaches a state
with `cardinal(ongoing) = 2` and two distinct `reconcile_id`s. Invariant #6
`every_ongoing_reconcile_has_unique_id` (invariants.ml:225-239 and byte-duplicated at
:472-487) is:

```ocaml
{ name = "every_ongoing_reconcile_has_unique_id";
  source = "kubernetes_cluster/proof/controller_runtime_safety.rs:874";
  holds = (fun s ->
    let ids = List.map (fun (_k, (orc : Controller.ongoing_reconcile)) -> orc.reconcile_id)
                (Object_ref_map.bindings (ongoing s)) in
    List.length (List.sort_uniq compare ids) = List.length ids);
  interesting = (fun s -> Object_ref_map.cardinal (ongoing s) >= 2); }
```
where `ongoing s = Cluster.ongoing_reconciles s controller_id`.

**Why it measures 0 today:** the only VSTS seed is `Scenario.vsts_seed` (scenario.ml:313)
which creates exactly ONE VSTS CR, and the P11 harness `reach_fair`
(t_p11_vsts_invariants.ml:74) explores only that single-CR seed → `ongoing` never holds
≥2 entries → `interesting` fires nowhere → pinned `("every_ongoing_reconcile_has_unique_id", 0)`
(t_p11_vsts_invariants.ml:164), DISCLOSED at :31. The VRS side is ALREADY non-vacuous via
`Scenario.seed_multi` (scenario.ml:441) exercised in `t_p4_enumerator`.

**P12 supplies the missing pieces:** a multi-CR VSTS seed + a BMC gate that explores it,
witnesses ≥2 concurrent reconciles (`gate_states = Some n>0`), confirms uniqueness holds
decisively, and is proven genuine by confirm-by-mutation. This mirrors **P8 exactly**: P8
did not change the model either; it supplied a bound + `settled` refinement + gate that
made `check_esr` non-vacuous. The `report.gate_states` slot means precisely "count of
states at which the universal is non-trivially checked" — for P12 the gate predicate is
`interesting` (≥2 concurrent), so `Some 0 ⟺ vacuous`, `Some n>0 ⟺ genuinely exercised`,
a perfect structural parallel to `check_esr_settled_vsts`.

**Do NOT change the P11 pin at :164 from 0.** The single-CR graph genuinely has 0; that
pin is a TRUE statement. Only UPDATE the disclosure comments (:31, :164) to cross-ref P12.
`max_controllers = 1` is CORRECT and STAYS 1 (the goal is two reconciles of ONE
controller, not two controllers).

---

## 1. Files (all additive to the modules except two provably-behavior-preserving refactors)

| File | Change | Kind |
|---|---|---|
| `lib/assurance/invariants.ml` | extract inv6 to one named binding referenced by both `cluster_structural` and `partition` | refactor (battery-confirmed identical) |
| `lib/assurance/invariants.mli` | expose `val unique_reconcile_id_invariant : controller_id:int -> invariant` | additive |
| `lib/assurance/scenario.ml` | add `vsts_named`, `vsts_seed_multi`; `vsts` delegates to `vsts_named ~name:"vsts1"` | additive + refactor |
| `lib/assurance/scenario.mli` | expose `vsts_named`, `vsts_seed_multi` | additive |
| `lib/checker/cluster_check.ml` | add `check_unique_reconcile_id_vsts`, `check_unique_reconcile_id_vrs` (+ shared helper) | additive |
| `lib/checker/cluster_check.mli` | expose both gates with documented contracts | additive |
| `test/t_p12_concurrent.ml` | NEW — non-vacuity + decisiveness + robustness + VRS parity + direct discrimination | new |
| `test/t_p12_mutation.ml` | NEW — confirm-by-mutation (automated analogues + manual real-source mutant plan) | new |
| `test/dune` | add `t_p12_concurrent t_p12_mutation` to `(names ...)` | additive |
| `test/t_p11_vsts_invariants.ml` | UPDATE the two DISCLOSED comments (:31, :164) to cross-ref P12 — **comment only, no assertion change** | doc |
| `lib/checker/BUILD-SPEC-P12.md` | this file | new (staged, like P5/P8/P11 specs) |

Firewall (lib AND test): List/Option/fold combinators only — **no loop keywords**, no
`List.nth`/`hd`/`tl` (`List.nth_opt`/`find_opt` OK), no `raise`/`assert`/`failwith`/
`Option.get` in lib, no naked `as`/`a.(i)`, **exhaustive matches (no `_ ->` on a finite
sum)**, `Option.fold` not two-arm option match, no `thiserror`/`anyhow` (N/A). Alcotest /
QCheck are the sanctioned test failure primitives.

---

## 2. `lib/assurance/invariants` — DRY the inv6 duplication + expose a handle

inv6 is defined twice byte-identically (invariants.ml:225-239 inside `cluster_structural`;
:472-487 inside `partition`). Extract ONE top-level binding and reference it from both:

```ocaml
(* invariants.ml — new top-level binding, placed before cluster_structural *)
let unique_reconcile_id_invariant ~(controller_id : int) : invariant =
  let ongoing s = Cluster.ongoing_reconciles s controller_id in
  {
    name = "every_ongoing_reconcile_has_unique_id";
    source = "kubernetes_cluster/proof/controller_runtime_safety.rs:874";
    holds =
      (fun s ->
        let ids =
          List.map
            (fun (_k, (orc : Controller.ongoing_reconcile)) -> orc.reconcile_id)
            (Object_ref_map.bindings (ongoing s))
        in
        List.length (List.sort_uniq compare ids) = List.length ids);
    interesting = (fun s -> Object_ref_map.cardinal (ongoing s) >= 2);
  }
```

Then in `cluster_structural ~controller_id` REPLACE the inline `inv6` with
`let inv6 = unique_reconcile_id_invariant ~controller_id in` (the list `[inv1;...;inv6]`
is unchanged). In `partition ~cr ~controller_id` REPLACE the inline `:472-487` copy the
same way. **The two bodies are byte-identical today, so this is a pure factoring with zero
behavior change — the whole P0-P11 battery MUST stay green as proof.** If the two sites
close over `controller_id` differently and the refactor is non-trivial, FALL BACK to
leaving `cluster_structural`/`partition` untouched and instead expose
`unique_reconcile_id_invariant` as a fresh binding used ONLY by the P12 gate + tests (the
duplication then persists but P12 stays purely additive — acceptable; note it in the
handoff).

`.mli`: add near the other invariant-list decls:
```ocaml
val unique_reconcile_id_invariant : controller_id:int -> invariant
(** Invariant #6 [every_ongoing_reconcile_has_unique_id] as a standalone handle
    (Anvil controller_runtime_safety.rs:874): over [Cluster.ongoing_reconciles s
    controller_id], every ongoing reconcile's [reconcile_id] is distinct. [interesting]
    fires iff ≥2 concurrent ongoing reconciles for [controller_id] — the P12 non-vacuity
    witness. The single source of truth for both [cluster_structural] and [partition]. *)
```

---

## 3. `lib/assurance/scenario` — the multi-CR VSTS seed

### 3.1 `vsts_named` (parameterized-name single-CR builder)

The existing `vsts ~desired ?vct ()` (scenario.ml:229-241) hardcodes `vsts_metadata`
(name="vsts1", uid=1, rv=0, no owner_refs) and `service_name="vsts1"`. Add a
name-parameterized builder and make `vsts` delegate:

```ocaml
let vsts_named ~(name : string) ?(vct = false) ~(desired : int) () : V_stateful_set.t =
  let metadata =
    { (Object_meta.default ()) with
      Object_meta.name = Some name;
      namespace = Some "ns";
      uid = Some (Common.Uid.of_int 1);           (* server re-stamps on create *)
      resource_version = Some (Common.Resource_version.of_int 0) }
  in
  V_stateful_set.make ~metadata
    ~spec:
      { (Stateful_set.ss_spec_default ()) with
        Stateful_set.replicas = Some desired;
        selector; template;
        service_name = name;                        (* required non-empty *)
        volume_claim_templates = (if vct then Some [ vsts_pvc_template ] else None) }
    ~status:None

let vsts ~(desired : int) ?(vct = false) () : V_stateful_set.t =
  vsts_named ~name:"vsts1" ~vct ~desired ()
```
Reproduce `vsts_metadata` EXACTLY for name="vsts1" (name/ns/uid/rv, no owner_refs) so the
refactor is behavior-identical — the P10/P11 battery is the proof. If `vsts_metadata`
differs in any field, mirror it precisely; if the delegation risks drift, keep `vsts`'s
current body verbatim and add `vsts_named` as a sibling (less DRY, zero risk).

### 3.2 `vsts_seed_multi` (the load-bearing new seed)

Mirror `vsts_seed`'s FAITHFUL real-create approach (server-stamped uid/rv, never forged),
folding one `handle_create_request` per CR with DISTINCT names `vsts1`, `vsts2`, …:

```ocaml
let vsts_seed_multi ~(desireds : int list) ~(fair : bool) : Cluster.cluster_state =
  let enabled = not fair in
  let created =
    List.fold_left
      (fun (api : Api_server.state) ((i, desired) : int * int) ->
        let name = "vsts" ^ string_of_int i in
        let api', _ =
          Api_server.handle_create_request vsts_installed
            { Api_method.namespace = "ns";
              obj = V_stateful_set.marshal (vsts_named ~name ~desired ()) }
            api
        in
        api')
      { Api_server.resources = Object_ref_map.empty; uid_counter = 1; resource_version_counter = 0 }
      (List.mapi (fun idx d -> (idx + 1, d)) desireds)
  in
  {
    Cluster.api_server = created;
    controller_and_externals =
      Imap.add controller_id
        { Cluster.controller = Controller.init; external_ = None; crash_enabled = enabled }
        Imap.empty;
    network = { Network.in_flight = Message.Pool.empty };
    rpc_id_allocator = Message.Rpc_id_allocator.init ();
    req_drop_enabled = enabled;
    pod_monkey_enabled = enabled;
  }
```
Distinct names → distinct `Object_ref_map` keys → each admits its own concurrent ongoing
reconcile under the single `controller_id`. `handle_create_request` stamps distinct uids
(uid_counter advances per create) so inv1 (`etcd_objects_have_unique_uids`) stays true. All
CRs are the SAME kind → reuse `vsts_installed` unchanged.

`.mli` (mirror the `seed_multi` doc block at scenario.mli:111-124):
```ocaml
val vsts_named : name:string -> ?vct:bool -> desired:int -> unit -> V_stateful_set.t
(** [vsts] with a parameterized metadata name and [service_name] (both = [name]); the
    per-CR builder behind [vsts_seed_multi]. [vsts ~desired () = vsts_named ~name:"vsts1"]. *)

val vsts_seed_multi : desireds:int list -> fair:bool -> Cluster.cluster_state
(** A multi-CR VSTS seed: one VStatefulSet [vstsN] per element of [desireds], each created
    through a real [Api_server.handle_create_request] (uid/rv server-stamped, distinct
    keys), all under the single [controller_id]. Unlike [vsts_seed] (one CR ⇒
    [ongoing_reconciles] never holds ≥2 ⇒ inv6 vacuous), a ≥2-element [desireds] lets the
    reachable graph reach [cardinal(ongoing) ≥ 2], the non-vacuity witness for
    [Invariants.unique_reconcile_id_invariant]. The VSTS analogue of [seed_multi]. *)
```

---

## 4. `lib/checker/cluster_check` — the P12 gate

Reuse the existing `report` type verbatim. The gate = `Model_check.check_safety` over the
inv6 `holds`, with `gate_states = Some (count of interesting states)` as the non-vacuity
witness. Private helper + two thin public wrappers (VSTS primary, VRS parity):

```ocaml
(* cluster_check.ml *)
let check_unique_reconcile_id_from ~(depth : int) (bound : Bound.t) (cluster : Cluster.t)
    ~(seed : Cluster.cluster_state) ~(controller_id : int) : report =
  let inv = Invariants.unique_reconcile_id_invariant ~controller_id in
  let reachable =
    Model_check.explore ~depth
      ~successors:(bounded_successors bound cluster)
      ~equal:state_equal ~hash:state_hash ~init:[ seed ]
  in
  let outcome = Model_check.check_safety reachable ~inv:inv.holds ~equal:state_equal in
  let gate = Model_check.count_states_where reachable inv.interesting in
  let violated =
    match outcome with
    | Model_check.Refuted _ -> Some inv
    | Model_check.No_counterexample _ -> None
  in
  { outcome;
    bound;
    max_uid_seen = max_uid_seen reachable;   (* reuse the existing folds used by check_esr* *)
    max_rv_seen = max_rv_seen reachable;
    pruned = pruned_at reachable bound cluster;
    violated;
    gate_states = Some gate }

let check_unique_reconcile_id_vsts ?(depth = 40) (bound : Bound.t)
    ~(desireds : int list) : report =
  check_unique_reconcile_id_from ~depth bound Scenario.vsts_cluster
    ~seed:(Scenario.vsts_seed_multi ~desireds ~fair:true)
    ~controller_id:Scenario.controller_id

let check_unique_reconcile_id_vrs ?(depth = 40) (bound : Bound.t)
    ~(desireds : int list) : report =
  check_unique_reconcile_id_from ~depth bound Scenario.cluster
    ~seed:(Scenario.seed_multi ~desireds ~fair:true)
    ~controller_id:Scenario.controller_id
```

**Reuse the ACTUAL helpers the existing `check_*` gates use** for `max_uid_seen` /
`max_rv_seen` / `pruned` — read how `check_esr_settled_vsts` builds its `report` in
cluster_check.ml and call the identical internal machinery (do not re-derive; if those are
inlined there, factor a tiny shared helper or replicate the exact fold). The `match` on
`outcome` is exhaustive (2 arms, both named — no wildcard). `fair:true` (disruptors off) so
the graph is finite/BFS-able exactly as the P11 `reach_fair`.

`.mli` — document with the P8/P11 discipline (gate_states meaning, non-vacuity, honest
limits):
```ocaml
val check_unique_reconcile_id_vsts : ?depth:int -> Bound.t -> desireds:int list -> report
(** CONCURRENCY-SAFETY leg (P12). Seed [Scenario.vsts_seed_multi ~desireds ~fair:true]
    (one VSTS CR per element, all under the single [controller_id]), explored over
    [Scenario.vsts_cluster]; refute inv6 [Invariants.unique_reconcile_id_invariant] by
    reachability ([Model_check.check_safety]). [report.gate_states] counts the reachable
    states with ≥2 concurrent ongoing reconciles (inv6's [interesting]): [Some n], [n>0]
    means the uniqueness universal is checked at genuinely-concurrent states
    (NON-VACUOUS); [Some 0] means it was never exercised (the single-CR vacuity of the
    P11 pin). A clean [No_counterexample {decisive=true}] with [n>0] verifies, up to the
    bound, that concurrent reconciles always carry distinct [reconcile_id]s; [Refuted]
    ([violated = Some inv6]) exhibits a real run with an id collision. Needs a [desireds]
    of length ≥2 AND a [reconcile_ceiling] ≥ (number of concurrent starts) — each
    [run_scheduled_reconcile] advances the shared per-controller reconcile counter, so
    reaching [cardinal(ongoing)=k] needs [reconcile_ceiling ≥ k]. Interpret only where
    [max_uid_seen]/[max_rv_seen] stay STRICTLY below their ceilings (bound-artifact
    discipline, BUILD-SPEC-P8 §4 / P11 §7.3). HONEST LIMIT: bounded falsification up to
    [depth] and [Bound.t]; transfers no part of Anvil's Verus theorem (arch §4). *)

val check_unique_reconcile_id_vrs : ?depth:int -> Bound.t -> desireds:int list -> report
(** The VReplicaSet sibling — same gate over [Scenario.seed_multi] / [Scenario.cluster].
    Demonstrates the P12 machinery generalizes across controllers and cross-checks the
    existing [t_p4_enumerator] VRS non-vacuity witness. Same contract as
    [check_unique_reconcile_id_vsts]. *)
```

---

## 5. Bound for the P12 gate

Base on the P11 `bfs_bound` but widened for TWO CRs. Start from:
```ocaml
let p12_bound ~(desireds : int list) : Bound.t =
  let n = List.length desireds in
  let dmax = List.fold_left max 0 desireds in
  { Bound.max_in_flight = 8;
    max_objects_per_kind = dmax + n + 2;   (* admit n CRs + their pods *)
    max_controllers = 1;                    (* STAYS 1 — two reconciles of ONE controller *)
    uid_ceiling = dmax + n + 4;             (* n creates advance uid further *)
    rv_ceiling = dmax + n + 4;
    reconcile_ceiling = n + 1;              (* n concurrent starts need ceiling ≥ n *)
    max_reconcile_depth = 24 }
```
These are STARTING values. The build MUST empirically MEASURE `gate_states`,
`frontier_emptied`, `max_uid_seen`, `max_rv_seen` and TUNE so that: (a) `gate_states > 0`
(the ≥2-concurrent state is reached — bump `reconcile_ceiling` and/or `depth` if it comes
back 0), (b) `frontier_emptied = true` (decisive), (c) `max_uid_seen`/`max_rv_seen`
STRICTLY below their ceilings (non-vacuity robustness — raise the uid/rv ceilings if they
bind). **Pin whatever is measured** (arch finding-14 discipline). `desireds:[2;2]` is the
minimal non-trivial witness; `[1;1]` is the cheapest (two 1-replica CRs) and may suffice —
prefer the smallest `desireds` that yields `gate_states > 0` with a finite graph.

---

## 6. Tests

### 6.1 `test/t_p12_concurrent.ml`
Mirror the P11 test style (module aliases `Cc`/`Mc`, `Alcotest.(check ...)`). All counts
MEASURED-then-PINNED (finding-14). Cases:

1. **`test_vsts_nonvacuous`** — `check_unique_reconcile_id_vsts (p12_bound ~desireds) ~desireds`
   with `desireds` the chosen witness (e.g. `[2;2]` or `[1;1]`):
   - `report.gate_states = Some n` with **n > 0** (PIN the exact `n`) — the ≥2-concurrent
     witness is real.
   - `outcome` is `No_counterexample {decisive=true}` (uniqueness holds, frontier emptied);
     `violated = None`.
   - `max_uid_seen < uid_ceiling` AND `max_rv_seen < rv_ceiling` (STRICT — robustness).
2. **`test_single_cr_vacuous`** — the SAME gate with `~desireds:[2]` (ONE CR):
   `gate_states = Some 0` — confirms `interesting` is NOT always-on and the P11 single-CR
   vacuity is a true measurement, not a bug in the gate.
3. **`test_robustness`** — run the witness gate with uid/rv ceilings raised by +3:
   `gate_states` stays the SAME positive `n` (or grows) AND `max_uid_seen`/`max_rv_seen`
   are unchanged — the witness is not a ceiling artifact (P11 robustness argument).
4. **`test_vrs_parity`** — `check_unique_reconcile_id_vrs (p12_bound ~desireds:[2;3]) ~desireds:[2;3]`:
   `gate_states = Some m`, **m > 0**, decisive, clean — the machinery generalizes; VRS is
   also non-vacuous (cross-checks the `t_p4_enumerator` witness).
5. **`test_direct_discrimination`** (the automated confirm-by-mutation analogue — proves
   `holds` genuinely discriminates, permanent pin): construct by hand two
   `Cluster.cluster_state`s each with `controller_id`'s `ongoing_reconciles` holding TWO
   entries under distinct cr keys — (a) with distinct `reconcile_id`s (0 and 1), (b) with
   the SAME `reconcile_id` (0 and 0). Assert
   `(unique_reconcile_id_invariant ~controller_id).holds state_a = true` and
   `... .holds state_b = false`. (Build the two ongoing entries via `Controller.init`
   then `Object_ref_map.add` of hand-made `Controller.ongoing_reconcile` records; keep it
   total, no `raise`.)

### 6.2 `test/t_p12_mutation.ml`
Confirm-by-mutation. Document the MANUAL real-source mutants (each SEEN red then reverted
via `git restore`; only GREEN pins ship — [[feedback-confirm-tests-by-mutation]]), and add
automated in-tree analogues:

- **M1 (manual, real source):** `Controller.Reconcile_id_allocator.allocate` → return a
  CONSTANT id (e.g. always `0`, allocator unchanged). Then two concurrent reconciles share
  id 0 → `check_unique_reconcile_id_vsts` flips to `Refuted` (`violated = Some inv6`). SEE
  red at `test_vsts_nonvacuous`'s clean/`violated=None` assertion, then revert. Proves the
  END-TO-END gate catches a real allocator uniqueness break.
- **M2 (automated analogue):** `test_witness_requires_multi` — assert the gate with
  `~desireds:[2]` gives `gate_states = Some 0` while `~desireds:[2;2]` gives `Some n>0`
  (the seed cardinality is load-bearing; a gate that ignored the seed would not move).
- **M3 (automated analogue):** `test_ceiling_prunes_witness` — the SAME witness `desireds`
  but with `reconcile_ceiling` set BELOW the number of concurrent starts (e.g. `1`):
  `gate_states = Some 0` and `pruned = true` (the 2nd concurrent start is ceiling-pruned,
  so the witness correctly vanishes — proves the count tracks the real reachable graph,
  not a constant).
- **M4 (automated analogue):** the `test_direct_discrimination` duplicate-id state from
  §6.1(5) restated here as the pinned "holds must reject a forged collision" mutant.

Every mutation MUST be SEEN to change the assertion (M1 red on the real source; M2/M3/M4
green-on-correct / would-be-red on the described corruption). Do not ship a mutant that was
never observed to flip. `sd` MANGLES multiline OCaml (P8 lesson) — use the Edit tool for
M1 and verify RED before trusting; restore via `git restore` / index, then confirm GREEN.

### 6.3 `test/dune`
Append `t_p12_concurrent t_p12_mutation` to the `(names ...)` list (line 12 region). All
required libs (`anvil_assurance anvil_checker alcotest qcheck-core qcheck-alcotest`) are
already listed.

---

## 7. Build workflow (sequential, green-gated; each stage leaves `dunecho build` 0/0)

1. **Invariant handle** — §2 (invariants.ml/.mli DRY + expose). Build 0/0; run the P4/P11
   invariant exes → still green (proves the refactor is behavior-identical).
2. **Seed** — §3 (scenario.ml/.mli: `vsts_named`, `vsts_seed_multi`; `vsts` delegates).
   Build 0/0; P10/P11 exes green (proves `vsts` delegation is identical).
3. **Gate** — §4 (cluster_check.ml/.mli: two gates + helper, reusing the real
   report-building machinery). Build 0/0.
4. **Tune + concurrent test** — §5/§6.1: empirically measure and tune `p12_bound`, write
   `t_p12_concurrent.ml`, wire `test/dune`. Iterate the bound until `gate_states>0`,
   `frontier_emptied`, maxima strictly below ceilings; PIN the measured values. Exe green.
5. **Mutation** — §6.2: write `t_p12_mutation.ml`; run the M1 real-source mutant, SEE red,
   revert, confirm green; keep M2-M4 automated pins.
6. **Greenup** — full battery (`for e in _build/default/test/*.exe`) all green (P0-P11 +
   the 2 new P12 exes); update the P11 disclosure comments (§0); firewall grep clean
   (no loop kw, no `List.nth/hd/tl`, no wildcard-on-finite-sum, no `raise/assert` in lib);
   `git add` the staged set; report suggested commit subject
   `feat(assurance): P12 concurrent-reconcile witness (multi-CR VSTS seed + unique-reconcile-id gate)`.

## 8. Explicitly OUT of scope
- No transition-system / cluster-model edit (already supports concurrency — §0).
- `max_controllers` stays 1 (goal = 2 reconciles of ONE controller).
- No new opam deps; pure OCaml; sandbox-verifiable (finite `fair:true` BFS, no cluster).
- Do not falsify the P11 single-CR pin (0 is true there); comment-only cross-ref.
- No native/Lwt backend work (separate menu item).

# BUILD-SPEC-P11 — VStatefulSet assurance (BMC safety + settled ESR + liveness skeleton)

Normative spec for Phase 11 of the anvil-ocaml port. Extends the **assurance spine**
(P4 property harness / P5 bounded lasso model checker / P6 typed entailment DSL / P8
settling state) from **VReplicaSet to VStatefulSet** — depth over breadth. All of
P0–P10 is committed on `main` @ `1c3d65f` (clean tree). P11 starts a NEW branch off
main (suggested `p11-vsts-assurance`).

**Scope decision (settled, via AskUserQuestion):** the user chose "extend assurance to
VStatefulSet" over a real Lwt concurrency backend / the RED native kind backend. The
payoff is a **second controller carried through the whole assurance spine**: VSTS
bounded safety invariants (`check_always_vsts`), a NON-VACUOUS settled ESR check
(`check_esr_settled_vsts`) under a VSTS settling bound, a formula-faithful cross-check
(`check_esr_temporal_vsts` via `Esr.Make(V_stateful_set)`), and a `vsts_liveness` ESR
`leads_to` skeleton over the first-pass reconcile trajectory. It demonstrates the
generic BMC engine + the P6 discharge machinery genuinely GENERALIZE past the first
controller.

**Provenance:** scout workflow `wf_626ca2a4-965` (5/6 agents; A6 died on the session
usage limit, recovered by hand from `v_stateful_set_reconciler.mli`). This spec is
self-contained. Anvil upstream: `src/controllers/vstatefulset_controller/` (invariants
in `.../proof/`; the shared cluster invariants in `kubernetes_cluster/proof/`).

Branch: `p11-vsts-assurance` off `main`. Build:
`eval $(opam env --switch=anvil-ocaml --set-switch); dunecho build`.
`dune test` HANGS — run exes directly: `perl -e 'alarm 180; exec @ARGV' _build/default/test/t_*.exe`.

---

## 0. Bounds and conventions (hard constraints)

- Whole P11 session: **≤7 findings, ≤56 agents** (scout consumed 6 of the budget:
  5 done + 1 limit-killed). Every workflow prompt must restate both caps.
- `lib` firewall (zero tolerance): no loop keywords; no wildcard `_ ->` on a finite
  sum (exhaustive arms only — every `Step.t` / `step` / `Common.kind` /
  `api_request` / `api_error` match lists all arms); no `raise`/`assert`/`failwith`/
  `Option.get` in `lib`; `Option.fold`/`Result.fold` combinators, NEVER a two-arm
  `match` on `option`/`result`; `List.nth_opt` never `List.nth`; no `List.hd`/`tl`.
  Prefer `map`/`fold`/`filter`/`for_all`/`exists` over hand recursion.
- Never commit for the user: STAGE only, output a commit message. `rg`/`sd`, never
  grep/sed.
- Confirm-by-mutation with **COMPILING** mutants only. A test never SEEN red is not
  evidence. The measured-witness tests must pin EXACT reachable-state counts (the P6
  / P8 discipline) so a bound artifact or a vacuous gate is VISIBLE.
- Trust an all-clear review only after `agents_error == 0` (vacuity discipline). Stage
  before review; restore any mutation a finder leaves in the tree.
- **Honest-vacuity is a first-class outcome, not a failure.** If the VSTS settled gate
  is empirically `Some 0` at every feasible bound (as VRS's `effectively_quiescent`
  gate is), DISCLOSE it in `.mli`/`.ml` + a permanent measured-count witness (mirror
  P5 `gate_states=Some 0`, P6 tail vacuity). Do NOT tune the goal to fake a positive.

---

## 1. The reuse split (do not re-derive; scout-confirmed)

**Reused UNCHANGED (no edit):**
- `Model_check.*` (lib/checker/model_check.ml) — generic BMC engine over state `'a`,
  Comp_cat-temporal-only. `explore` / `check_safety` / `check_reaches` /
  `check_temporal` / `count_states_where` / `frontier_emptied` / `states_seen`.
- `Cluster_check` STATE-OPS: `state_equal`, `state_hash`, `max_reconcile_id`,
  `over_ceiling` (internal), `bounded_successors`, `bounded_labelled_successors`,
  `fair_lasso` (internal), `collect_metadata` (internal), `default_depth = 40`,
  `report` type — all controller-agnostic over `Cluster.cluster_state`.
- `Discharge.*` (lib/proof) — controller-agnostic: `edge_report`, `closure_holds`,
  `drives_holds`, `invariant_holds`, `reaches_holds` (`?depth`, `default_depth = 64`),
  `obligation` (Ok true iff `holds && witnesses>0 && frontier_emptied`, else
  `Err.Ill_formed`). Every controller fact enters via injected predicates
  (`pre/post/inv : cluster_state -> bool`, `forward : Step.t -> bool`).
- `Invariants` MACHINERY: the `invariant` record type
  `{ name; source; holds : cluster_state -> bool; interesting : cluster_state -> bool }`
  + `conjunction` + `first_violated`. Reused verbatim by `Vsts_invariants`.
- `Esr.Make (R : Resource_view.RESOURCE_VIEW)` — `V_stateful_set` ALREADY satisfies the
  functor argument (it `include`s `RESOURCE_VIEW`; confirmed vs `vreplica_set.mli:55`),
  so `Esr.Make(V_stateful_set)` compiles with ZERO new members.
  `eventually_stable_reconciliation_per_cr ~cr ~current_state_matches` builds
  `T.leads_to (T.always (desired_state_is cr)) (T.always (current_state_matches cr))`.

**VRS-hardwired → needs a VSTS sibling (this phase):**
- The four `Cluster_check.check_*` entry points (pin `Scenario.vrs` + `Invariants` +
  `Esr.Make(Vreplica_set)`). → §5 adds `check_*_vsts`.
- `Invariants.always` CONTENTS (§4): inv1–6 structural (reuse), inv9 widen, inv15/inv16
  + `liveness_goal`/`current_state_matches` rewrite for VSTS.
- `Step_view` (pins `Vreplica_set_pack` + `Vreplica_set_reconciler.step`). → §6.
- `Vrs_liveness` (the whole skeleton). → §7 `Vsts_liveness`.
- `Scenario` has NO runnable VSTS cluster (`vsts_installed` exists but is never wired
  into a `Cluster.t`; `productive_successors` is VRS-cluster-coupled). → §3 Foundation.

---

## 2. Files

### New
- `lib/assurance/vsts_invariants.ml` / `.mli` — VSTS safety invariants + liveness goal.
- `lib/proof/vsts_step_view.ml` / `.mli` — read the VSTS reconcile step from a state.
- `lib/proof/vsts_liveness.ml` / `.mli` — the VSTS ESR `leads_to` skeleton.
- `test/t_p11_vsts_invariants.ml` — safety invariants: hold on reachable graph, each
  non-vacuous (interesting witness reachable).
- `test/t_p11_vsts_esr.ml` — `check_always_vsts` clean; `check_esr_settled_vsts` gate
  reachable (`gate_states = Some n`, MEASURED, with the honest verdict pinned);
  `check_esr_temporal_vsts` AGREES with `check_esr_settled_vsts` (class + decisive).
- `test/t_p11_vsts_liveness.ml` — the derivation type-checks + `matches_esr_statement`
  true; the MEASURED per-milestone reachable-state counts (vacuity made visible).
- `test/t_p11_mutation.ml` — confirm-by-mutation (COMPILING mutants), see §8.

### Edits (additive, behavior-preserving for VRS)
- `lib/assurance/scenario.ml` / `.mli` — **GAP-1**: `vsts_cluster`, `vsts_seed`;
  generalize `productive_successors` to take a `Cluster.t`. `vsts_ref` already exists.
- `lib/assurance/invariants.ml` / `.mli` — **GAP-2**: expose
  `cluster_structural : controller_id:int -> invariant list` (the shared inv1–6),
  so both `always` and `Vsts_invariants` reuse ONE source. (Fallback if the refactor
  looks risky: leave `partition` untouched and duplicate inv1–6 bodies inside the new
  exposed function — same result, no behavior change to the tested `always`.)
- `lib/checker/cluster_check.ml` / `.mli` — **GAP-3**: `settled` body uses its
  (currently unused) `Cluster.t` param; `check_always_vsts` / `check_esr_settled_vsts`
  / `check_esr_temporal_vsts` (+ a vacuous-companion `check_esr_vsts` for the honest
  cross-ref). No VRS entry point changes shape.
- `lib/checker/dune`, `lib/proof/dune`, `lib/assurance/dune`, `test/dune` — wire new
  modules/tests. (assurance/proof/checker dunes AUTO-DISCOVER; only `test/dune` needs
  explicit names — P10 fact.)

---

## 3. Foundation (GAP-1 + GAP-3): a runnable VSTS scenario cluster

The blocker: the BMC explores `bounded_successors bound cluster seed`, and the settled
gate filters `Scenario.productive_successors …` — both need a `Cluster.t` whose
`installed_types` admit VSTS + Pod + PVC and whose controller registry runs the VSTS
reconcile. Today only the VRS `cluster` is runnable.

### 3.1 Scenario additions (`scenario.mli`)

```ocaml
(* Generalize the successor enumerator to an explicit installed cluster. The VRS
   call sites pass [cluster] (behaviour identical); the VSTS checks pass
   [vsts_cluster]. This is the SAME generalization the unused [settled] Cluster.t
   param anticipated. *)
val productive_successors :
  Cluster.t -> Bound.t -> Cluster.cluster_state -> (Step.t * Cluster.cluster_state) list

val vsts_cluster : Cluster.t
(** The runnable VSTS cluster: [installed_types = vsts_installed] (admits the
    VStatefulSet CR + Pod + PVC; [marshalled_default_status] already dispatches
    exhaustively over [Common.kind]), controller registry = the
    {!V_stateful_set_pack} controller at {!controller_id}. Built EXACTLY as the
    internal VRS [cluster] but with the VSTS pack + installed types. *)

val vsts_seed : desired:int -> fair:bool -> Cluster.cluster_state
(** Mirror of {!seed} for VSTS: the {!vsts} CR ([Scenario.vsts ~desired], default
    [?vct:false] — see §3.3) created into etcd (uid/rv stamped by a real CREATE, never
    forged), the VSTS controller scheduled at {!controller_id}, disruptors gated by
    [fair] (false = full nondeterminism for safety; true = the fair suffix for ESR). *)
```

VRS `cluster`/`seed`/`is_quiescent`/`vrs`/`vrs_ref`/`controller_id`, and `vsts`/
`vsts_ref`/`vsts_installed` are UNCHANGED. Update the single VRS `productive_successors`
call site (inside `effectively_quiescent`) to pass `Scenario.cluster`.

### 3.2 Cluster_check GAP-3 (`cluster_check.ml`)

`settled`'s signature is UNCHANGED (it already takes `Cluster.t`); only its body
becomes:

```ocaml
let settled (bound : Bound.t) (cluster : Cluster.t) (s : Cluster.cluster_state) : bool =
  List.for_all
    (fun (_step, s') -> state_equal s s')
    (List.filter
       (fun (_step, s') -> not (over_ceiling bound s'))
       (Scenario.productive_successors cluster bound s))
```

`effectively_quiescent` gains no parameter — its body passes `Scenario.cluster`
explicitly (VRS behaviour preserved). VSTS uses `settled` (the P8 non-vacuous gate),
so no VSTS `effectively_quiescent` variant is required.

### 3.3 The `?vct` decision (feeds §4 goal + §7 bound)

`Scenario.vsts ~desired ?vct ()` includes a `volumeClaimTemplate` only when `vct:true`.
**P11 default = `vct:false`** for the BMC/ESR checks: it keeps the first-pass write
count minimal (no PVC create — the state space and the rv budget stay small enough for
a decisive graph), and the ordinal-identity + owned-pod-count content is fully
exercised without PVCs. A SEPARATE witness (`t_p11_vsts_liveness`, low N) runs `vct:true`
to exercise the PVC create/get milestones operationally. Rationale recorded so a reviewer
does not read the `vct:false` bound as hiding the PVC path.

---

## 4. VSTS invariants (`vsts_invariants.ml` / `.mli`)

Reuse `Invariants.invariant` + `conjunction` + `first_violated`. `always` =
`Invariants.cluster_structural ~controller_id` (inv1–6, GAP-2) `@` the three VSTS-specific
invariants below. Every `holds`/`interesting` is total, pure, no exception; every
`Common.kind` / `api_request` / `step` match is exhaustive.

```ocaml
(* vsts_invariants.mli *)
val always : cr:V_stateful_set.t -> controller_id:int -> Invariants.invariant list
(** The [always] (per-step inductive) safety invariants for the VSTS controller:
    [Invariants.cluster_structural ~controller_id] (the shared etcd/runtime-safety
    inv1–6, owner-ref/counter-generic) followed by the three VSTS invariants. Asserted
    after every step from [vsts_seed ~fair:false]. *)

val liveness_goal : cr:V_stateful_set.t -> Invariants.invariant
(** The ESR [leads_to] TARGET [current_state_matches] for VSTS (NOT in [always]; a
    transient-false goal checked only at a settled state). See {!current_state_matches}. *)

val current_state_matches : V_stateful_set.t -> Cluster.cluster_state -> bool
(** The VSTS converged shape (rewrite of the VRS replica-count goal for ordinal
    identity). True iff, with [n = Option.value ~default:1 (ss_spec cr).replicas]:
    (a) the CR's [vsts_ref] is present in [Cluster.resources s];
    (b) the set of owned Pods in etcd is EXACTLY the [n] pods at ordinals [0..n-1] —
        each present, each named [pod_name parent ord], each carrying
        [pod_name_label]/[ordinal_label] and the controller owner-ref, and
        [pod_spec_matches cr] (template match modulo injected volumes/hostname/subdomain);
    (c) no owned Pod at ordinal [>= n] (no condemned/outdated survivor).
    NOTE: the VSTS [reconcile_core] has NO status-write step (the 17 steps contain no
    [Get_then_update_status]), so — unlike VRS — the goal MUST NOT gate on
    [status.ready_replicas]; gating on a status the reconcile never writes would make
    the goal unreachable (vacuous) by construction. Status is out of the reconcile's
    control surface; the pod/pvc/ordinal shape IS the reconciled invariant. *)
```

The three VSTS-specific `always` invariants (mirror Anvil's vstatefulset predicate.rs;
each is inductive and asserted per-step):

- **`vsts_reconcile_request_only_interferes_with_itself`** (widen VRS inv9): for every
  in-flight message from `Message.Controller(controller_id, vsts_ref)`, its
  `api_request` is one of the VSTS repertoire and well-formed — `Create_request` obj is
  `Pod` (single controller owner-ref = vsts) OR `Persistent_volume_claim` (owner-ref =
  vsts); `Get_request`/`Get_then_delete_request` on a `Pod` or `Persistent_volume_claim`
  key owned by vsts; every other `api_request` arm ⇒ false. Exhaustive match over the
  request sum (no wildcard).
- **`owned_pods_have_wellformed_ordinal_identity`** (the VSTS analogue of VRS inv15/16):
  every owned Pod in etcd (controller owner-ref = vsts) has a name of the form
  `pod_name parent ord` with `get_ordinal parent name = Some ord`, `ord >= 0`, and
  carries `ordinal_label = string_of_int ord`. (The P10 review's `get_ordinal`
  injective-inverse fix is what makes this checkable; reuse `V_stateful_set_reconciler.
  get_ordinal`.) Owner-ref-binding core is owner-generic; the ordinal-name shape is the
  VSTS content.
- **`owned_pvcs_bound_to_vsts`**: every owned PVC has the vsts controller owner-ref and
  a `pvc_name`-shaped name. (When `vct:false` this is vacuous-by-absence — its
  `interesting` witness requires the `vct:true` scenario; the non-vacuity test uses it.)

**GAP-2 note (`invariants.mli`):**
```ocaml
val cluster_structural : controller_id:int -> invariant list
(** The shared cluster-level etcd/runtime-safety invariants inv1–6 (unique uids,
    weakly-well-formed + uid/rv monotone, ≤1 controller owner, scheduled/triggering CR
    uid < counter, unique reconcile ids). Independent of any CR — sourced from Anvil's
    [kubernetes_cluster] proofs, not [vreplicaset_controller]. [always ~cr ~controller_id]
    is [cluster_structural ~controller_id @ [inv9; inv15; inv16]] (unchanged result). *)
```

---

## 5. VSTS checker entry points (`cluster_check.ml` / `.mli`)

Mirror the VRS `check_*` VERBATIM in structure (§ scout has the exact bodies), swapping
`Scenario.vrs → Scenario.vsts`, `Scenario.cluster → Scenario.vsts_cluster`,
`Scenario.seed → Scenario.vsts_seed`, `Invariants → Vsts_invariants`,
`Esr.Make(Vreplica_set) → Esr.Make(V_stateful_set)`. Reuse ALL private helpers
(`collect_metadata`, `fair_lasso`, `over_ceiling`, `default_depth`, `violated_of`).

```ocaml
(* cluster_check.mli additions *)
val check_always_vsts : ?depth:int -> Bound.t -> desired:int -> report
(** VSTS SAFETY leg. Seed [vsts_seed ~desired ~fair:false];
    inv = Invariants.conjunction (Vsts_invariants.always ~cr ~controller_id);
    explore [bounded_successors bound vsts_cluster]; Model_check.check_safety. *)

val check_esr_settled_vsts : ?depth:int -> Bound.t -> desired:int -> report
(** VSTS NON-VACUOUS ESR leg. Seed [vsts_seed ~desired ~fair:true];
    target = (Vsts_invariants.liveness_goal ~cr).holds;
    gate quiescent = settled bound Scenario.vsts_cluster;
    gate_states = Some (count_states_where reach (settled bound Scenario.vsts_cluster)).
    Decisive NON-vacuously iff gate_states = Some n, n>0, under a settling bound (§7). *)

val check_esr_vsts : ?depth:int -> Bound.t -> desired:int -> report
(** The honest VACUOUS companion (parallels [check_esr]): same seed/target but gated on
    an [effectively_quiescent]-style unpruned quiescence over [vsts_cluster]. Expected
    [gate_states = Some 0] on the perpetually re-triggered model — kept + cross-ref'd so
    the settled-vs-unsettled contrast is VISIBLE (P8 discipline), not to add a verdict. *)

val check_esr_temporal_vsts : ?depth:int -> Bound.t -> desired:int -> report
(** Formula-faithful cross-check. goal = Esr.Make(V_stateful_set)
    .eventually_stable_reconciliation_per_cr ~cr
      ~current_state_matches:(fun cr' -> Vsts_invariants.current_state_matches cr');
    Model_check.check_temporal … ~fair:(fair_lasso bound). Its class + decisive flag
    MUST AGREE with [check_esr_settled_vsts] (a test asserts both). *)
```

---

## 6. VSTS step reader (`vsts_step_view.ml` / `.mli`)

Mechanical transposition of `step_view` (scout: keys are already parameters; only the
pack + reconciler-step types are VRS-named). Preserve the `Option.map`/`Option.bind`/
`Result.fold`/`Option.fold` partiality (no two-arm match, no raise); keep the
unmarshal-failure branch total (`Result.fold ~error:(fun _ -> None)`).

```ocaml
(* vsts_step_view.mli *)
val reconcile_step_of :
  controller_id:int -> cr_key:Common.object_ref ->
  Cluster.cluster_state -> V_stateful_set_reconciler.step option
(** Cluster.ongoing_reconciles s controller_id -> Object_ref_map.find_opt cr_key ->
    .local_state -> V_stateful_set_pack.unmarshal_state -> .reconcile_step. *)

val at_step :
  controller_id:int -> cr_key:Common.object_ref ->
  V_stateful_set_reconciler.step -> Cluster.cluster_state -> bool
val at_phase :
  controller_id:int -> cr_key:Common.object_ref ->
  (V_stateful_set_reconciler.step -> bool) -> Cluster.cluster_state -> bool
val scheduled_only : controller_id:int -> cr_key:Common.object_ref -> Cluster.cluster_state -> bool
val no_ongoing : controller_id:int -> cr_key:Common.object_ref -> Cluster.cluster_state -> bool
```

`at_step` compares with `V_stateful_set_reconciler.step_equal`. `at_phase` takes a
`step -> bool` phase predicate (used by §7 to name a milestone that spans an
action/after pair).

---

## 7. VSTS liveness skeleton (`vsts_liveness.ml` / `.mli`) + the settling bound

Mirror `vrs_liveness`: a `Comp_cat.Rule` entailment
`spec |= always(desired_state_is) ~> current_state_matches`, chained by `leads_to_trans`
FRONT ; body wf1 edges ; TAIL. Reuse the `wf1_edge` helper VERBATIM (scout has it),
`Discharge`, and `controller_label` (the P2 cluster `Step.t`, 12 arms exhaustive, true
only on `Controller_step (cid,_,Some k)` with `cid = controller_id && equal_object_ref k
cr_key`). The reconciler-internal `V_stateful_set_reconciler.step` (17 arms) is used ONLY
for milestone predicates via `Vsts_step_view.at_step`/`at_phase`, NEVER for forward-labels.

### 7.1 The first-pass trajectory (desired=1, `vct:false`, no stale pods)

```
Init -> After_list_pod -> Create_needed -> After_create_needed -> Done
```

(With `vct:true` the Get_pvc/After_get_pvc/Create_pvc/After_create_pvc milestones
interpose between `After_list_pod` and `Create_needed`; the `vct:false` default skips
the PVC loop, so the create-pod milestone is reached directly.) Body wf1 edges
(milestones; each `closure`+`drives` discharged via `Discharge`, forward =
`controller_label`):

- e1: `at Init` ~> `at After_list_pod`
- e2: `at After_list_pod` ~> `at (Create_needed | After_create_needed)`  (pod-create phase)
- e3: `at create-phase` ~> `at Done`

FRONT (`always desired ~> at Init`) = `assume` gated by `Discharge.reaches_holds` (the
scheduling step is cyclic — a wf1 drive on it correctly FAILS, the P6 self-catch; keep
it a reachability assume). TAIL (`at Done ~> current_state_matches`) = `leads_to_weaken`
of `leads_to_self Done` over the bounded invariant `Done => current_state_matches`.
`esr_statement_core` built independently; `matches_esr_statement` locks the derivation
goal to it via `Temporal.equal`. Chain FRONT ; e1 ; e2 ; e3 ; TAIL by `leads_to_trans`.

### 7.2 The settling bound (the crux; MEASURE-AND-PIN)

VSTS at a fresh desired=1 with NO stale pods reaches `Done` in **ONE** reconcile pass
(the multi-pass one-pod-per-round rolling only triggers when `Delete_outdated` fires on
an outdated pod — absent on a fresh create). So, exactly like VRS, `reconcile_ceiling=1`
isolates the first pass and dissolves the P5/P6 rv-ceiling vacuity. Starting guess
(the build MEASURES the true counts and pins them; adjust up only if `Done`/match is
pruned):

```ocaml
let settling_bound : Bound.t =
  { max_in_flight = 2; max_objects_per_kind = 2; max_controllers = 1;
    uid_ceiling = 4; rv_ceiling = 5; reconcile_ceiling = 1; max_reconcile_depth = 8 }
```

Reasoning: `vct:false` desired=1 writes = seed-create the CR (rv 0), then one pass:
list pods (read), create 1 pod (rv+1, uid+1). Fewer writes than VRS (which also does a
status update), so `rv_ceiling=5` should comfortably reach `Done`+match. **If the
measured `at Done` count is 0 at this bound, do NOT paper over it** — raise
`rv_ceiling` once; if still 0 at every bound with `reconcile_ceiling=1` and
`max_uid/rv_seen` strictly below ceilings, DISCLOSE the VSTS tail as honestly vacuous
(P6 tail precedent) and ship the measured 0-count witness.

### 7.3 Bound-artifact discipline (carry the P8 latent caveat forward)

`settled` filters through the FULL over_ceiling, so a bound whose `uid_ceiling`/
`rv_ceiling` bite mid-pass manufactures a starved non-matching "settled" state; a
`check_esr_settled_vsts` `Refuted` there is a bound ARTIFACT. Document in the `.mli`:
interpret a `Refuted` only where `max_uid_seen`/`max_rv_seen` stay STRICTLY below their
ceilings (a `t_p11_vsts_esr` test pins that the settling bound does).

```ocaml
(* vsts_liveness.mli — the crux exports (mirror vrs_liveness) *)
val settling_bound : Bound.t
val esr_statement_core : desired:int -> Cluster.cluster_state Comp_cat.Temporal.t
val esr_derivation :
  ?bound:Bound.t -> desired:int -> Cluster.cluster_state Comp_cat.Rule.fact Comp_cat.Res.t
val matches_esr_statement : ?bound:Bound.t -> desired:int -> bool Comp_cat.Res.t
```

---

## 8. Tests + confirm-by-mutation

Suites (Alcotest; run exes directly under `perl alarm`):
- `t_p11_vsts_invariants` — every `Vsts_invariants.always` invariant HOLDS across the
  `check_always_vsts` reachable graph; each is non-vacuous (its `interesting` witness is
  reachable). The widened inv9 and the ordinal-identity invariant are exercised.
- `t_p11_vsts_esr` — `check_always_vsts` clean+decisive; `check_esr_settled_vsts`
  `gate_states = Some n` with the MEASURED n pinned and the honest verdict asserted;
  `max_uid_seen`/`max_rv_seen` strictly below ceilings (bound-artifact guard);
  `check_esr_temporal_vsts` AGREES (class + decisive) with `check_esr_settled_vsts`;
  `check_esr_vsts` `gate_states = Some 0` pinned (the honest vacuous contrast).
- `t_p11_vsts_liveness` — `matches_esr_statement` true; the MEASURED per-milestone
  reachable-state counts (Init / After_list_pod / create-phase / Done / match) pinned
  POSITIVE (or the disclosed 0 if the tail is vacuous — vacuity made visible).
- `t_p11_mutation` — COMPILING mutants, each SEEN red then reverted; automated analogues
  kept green in-tree:
  - M1: drop the ordinal-name conjunct in `current_state_matches` → an off-ordinal pod
    passes → `check_esr_settled_vsts` must flip (or the liveness match count changes).
  - M2: widen inv9's `self_ok` to accept a foreign-owner Create → `check_always_vsts`
    Refuted.
  - M3: `settling_bound.reconcile_ceiling := 2` → the settled gate reverts toward the
    perpetual-reschedule vacuity (gate/count changes) — pins that ceiling=1 is load-bearing.
  - M4: corrupt `esr_statement_core` (swap the leads_to sides) → `matches_esr_statement`
    false.
  - M5: `current_state_matches` requires ordinal `>= n` pods too (off-by-one on the
    condemned clause) → the settled match count drops.

---

## 9. Build-wf plan (sequential; each stage GREEN before handoff)

Mirror P9/P10 (sequential general-purpose OR wf-mechanical+Edit agents; ≤7 findings,
session ≤56 agents incl. the 6 scout). Stages:

1. **Foundation** — GAP-1 (Scenario `vsts_cluster`/`vsts_seed`/`productive_successors`
   generalization) + GAP-2 (`Invariants.cluster_structural`) + GAP-3 (`settled` body).
   Gate: `dunecho build` 0/0, all P0–P10 exes still green (behavior-preserving).
2. **Invariants** — `vsts_invariants.ml/.mli` + `t_p11_vsts_invariants`. Gate: green.
3. **Checker entry points** — `check_*_vsts` in cluster_check + `t_p11_vsts_esr`;
   MEASURE + pin `gate_states` and the counter maxima. Gate: green + the honest verdict
   recorded (Some n>0 non-vacuous, or disclosed Some 0).
4. **Step view + Liveness** — `vsts_step_view` + `vsts_liveness` + `t_p11_vsts_liveness`;
   MEASURE + pin milestone counts. Gate: `matches_esr_statement` true.
5. **Mutation** — `t_p11_mutation` (M1–M5), each SEEN red then reverted; automated
   analogues green. Gate: full battery green, no P0–P10 regression.
6. **Greenup + firewall** — `dunecho build` 0/0; run EVERY test exe; grep the new `lib`
   files for loop kw / wildcard-on-sum / raise/assert/Option.get / List.nth/hd/tl / two-arm
   option-result match = CLEAN; leftover-mutation sweep (no `.bak`/probe); tree matches
   pre-build + the intended new/edited set.

---

## 10. Honest limits (bake into code + docs)

1. **Bounded, not proven.** Every verdict is falsification-up-to-(depth, Bound.t);
   `decisive` verifies only the bounded system, transfers nothing from Anvil's Verus
   theorem (arch §4).
2. **First-pass slice.** The liveness skeleton witnesses ONE reconcile invocation from a
   fresh cluster reaching the ordinal-stable match; the perpetual re-reconcile and the
   multi-round rolling update are witnessed OPERATIONALLY by the P7/P10 executable spine
   (`vct:true`, one-pod-per-round measured [1;1;1;0]), NOT claimed as a bounded proof here.
3. **wf1 omega-induction trusted-on-stream**, only closure/drives/[]j model-checked
   (same residual risk as VRS; a wf1 bug is caught only by mutation-confirmed lasso MC).
4. **No status conjunct** in `current_state_matches` — faithful, because VSTS
   `reconcile_core` writes no status; the pod/pvc/ordinal shape is the reconciled goal.
5. **`vct:false` default** for the decisive checks (state-space/rv budget); the PVC path
   is exercised by a separate `vct:true` witness, disclosed (§3.3), not silently dropped.
6. If the settled tail is empirically vacuous at every feasible bound, that is DISCLOSED
   (measured 0-count witness), not hidden — the P5/P6 honesty precedent.
```

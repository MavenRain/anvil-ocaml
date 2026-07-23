# BUILD-SPEC P4 — property-testing harness + api-server correspondence oracle

Normative contract for anvil-ocaml Phase 4 (the first leg of the assurance spine).
Author: Onyeka (Oni/MavenRain) Obi. This doc is the builder-agents' oracle; the
Anvil-fidelity oracle is the digest at
`<scratchpad>/p4_anvil_digest.md` (16 invariants + per-invariant source cites) plus
the Anvil clone at `<scratchpad>/anvil-ref`. Read both before editing.

Whole-repo plan: `comp-cat-ocaml/lib/temporal/ARCHITECTURE-anvil-ocaml.md` §4 (Leg 1)
and §5 (P4 row). P4 realises **Leg 1**: the executable cluster model is the
reference semantics; Anvil's `proof/` inductive invariants become OCaml boolean
`StatePred`s; QCheck generates random enabled-step traces; **confirm-by-mutation on
every property AND on the enumerator** (finding 14). Plus a **correspondence
oracle** scoped to the api-server (see §5, honest-limit).

## 0. Scope and non-scope

IN: (1) a reusable `lib/assurance/` library — the canonical VReplicaSet scenario,
the 16 safety invariants as pure `cluster_state -> bool` predicates, and the
api-server golden oracle; (2) a `test/` QCheck harness — random-trace invariant
checking, deep marshal round-trips, the differential oracle property, and both
flavours of confirm-by-mutation.

OUT: liveness/ESR verification (P5 BMC; P4 **cannot** observe unbounded liveness —
it only checks the ESR *goal* #11 at quiescence, as a sanity sample, never as
proof); the full-cluster-step oracle (no independent runnable Anvil model exists —
digest verdict); the P6 entailment DSL.

## 1. Module layout

```
lib/assurance/           NEW library `anvil_assurance` (dune already written; opens
                         all anvil_* libs + comp_cat, mirrors test/dune flags)
  scenario.ml/.mli       canonical VRS scenario: Cluster.t + reachable seed state
  invariants.ml/.mli     the 16 Anvil StatePreds as pure predicates + conjunction
  oracle_api_server.ml/.mli   independent re-port of Anvil's SPEC api-server handler
test/
  t_p4_invariants.ml     QCheck: random traces preserve the always-invariant
                         conjunction; liveness goal at quiescence; per-invariant
                         negative (non-vacuity) unit tests
  t_p4_enumerator.ml     finding-14: every invariant's "interesting" precondition
                         is actually REACHED under Bound.default (else vacuous)
  t_p4_roundtrip.ml      QCheck: deep reconcile-state + dynamic-object round-trips
  t_p4_oracle.ml         QCheck: our Api_server agrees with the golden oracle
```

`lib/assurance/` is qcheck-free (so P5/BMC can depend on it). All qcheck lives in
`test/`. Add the four test names + `anvil_assurance` to `test/dune`.

## 2. `scenario.mli` (hand-authored crux; see the .mli on disk — this is the semantics)

The scenario builds a `Cluster.t` running EXACTLY the vreplicaset controller at id
`0`, `installed_types` that validate the vreplicaset kind (reuse the
`Vreplica_set_pack` controller; permissive validation like `t_cluster.ml`'s
`permissive`, EXCEPT `valid_object`/`valid_transition` should accept vrs+pod
objects and `marshalled_default_status` returns the vrs default status marshalled).

`seed ~desired ~fair`:
- start from the `t_cluster.ml` `s_init` shape (api_server empty, one
  `controller_and_external` with `Controller.init`, empty network, fresh allocator);
- store `vrs ~desired` in `api_server.resources` under `vrs_ref` with a freshly
  issued uid and resource_version, and set `api_server.uid_counter` /
  `resource_version_counter` STRICTLY ABOVE the stored values (so #2's `< counter`
  bounds hold). This is a REACHABLE state (a client created the CR); it is NOT an
  `init` state (etcd non-empty) — say so in the doc comment.
- `~fair:true` sets `crash_enabled=false`, `req_drop_enabled=false`,
  `pod_monkey_enabled=false` (the fair suffix Anvil's liveness assumes; used for the
  quiescence/liveness-goal check). `~fair:false` leaves them enabled (full
  nondeterminism; used for safety-invariant checking — every safety invariant must
  hold under the failure steps too).

`vrs ~desired`: name `vrs1`, namespace `ns`, uid 1, ONE controller owner ref, spec
replicas `desired`, a selector (`app=x`) and a template. Must satisfy
`Vreplica_set._state_validation` (P3). `controller_owner_ref vrs` is `Some`.

`productive_successors b s` = `Cluster.enabled_successors b cluster s` filtered to
the productive step constructors: `Api_server_step (Some _)`, `Builtin_controllers_step _`,
`Controller_step _`, `Schedule_controller_reconcile_step _`, `Pod_monkey_step _`,
`External_step _`. Exclude `Api_server_step None`, `Restart_controller_step`,
`Disable_*`, `Drop_req_step`, `Stutter_step` (no-op / failure / liveness-toggle
steps). Match the 12-arm `Step.t` EXHAUSTIVELY (no `_ ->`).

`is_quiescent b s = productive_successors b s = []`.

## 3. `invariants.mli` (hand-authored crux)

```ocaml
type invariant = {
  name : string;         (* the Anvil spec-fn name *)
  source : string;       (* "file:line" in anvil-ref *)
  holds : Cluster.cluster_state -> bool;
      (* the StatePred, closed over the scenario's cr + controller_id *)
  interesting : Cluster.cluster_state -> bool;
      (* finding 14: the invariant's non-trivial precondition. A trace that never
         makes this true checks the invariant VACUOUSLY. e.g. for the GC invariant,
         "there is an in-flight BuiltinController delete on a pod"; for #8, "there
         is an in-flight foreign api request"; for #11/#13, "an owned pod / an
         ongoing reconcile exists". `interesting s = true` must be REACHED. *)
}

val all : cr:Vreplica_set.t -> controller_id:int -> invariant list
  (* the 15 ALWAYS-invariants: #1-#10, #12-#16 from the digest (NOT #11). *)

val liveness_goal : cr:Vreplica_set.t -> invariant
  (* #11 current_state_matches; check ONLY where Scenario.is_quiescent. *)

val conjunction : invariant list -> Cluster.cluster_state -> bool
val first_violated : invariant list -> Cluster.cluster_state -> invariant option
  (* for QCheck counterexample reporting. *)
```

Port ALL 16 predicates faithfully from the digest table + per-invariant detail +
the cited Anvil source. Non-negotiable fidelity points (from the digest "Notes"):
- **#1 unique uids**: injective `metadata.uid` over `resources` values (ignore
  entries whose uid is `None`? No — every stored object is well-formed so uid is
  `Some`; compare the `Some` uids, treat a `None` uid as a #2 violation not a #1
  clash). Use `Common.Uid` equality.
- **#2 weakly well-formed**: each stored object `well_formed_for_namespaced`,
  `object_ref () = key`, `rv < resource_version_counter`, `uid < uid_counter`. The
  `<` is STRICT. Do NOT let any Bound truncate the counters (they are global
  monotone; §Notes).
- **#3 at-most-one controller owner**: `owner_references` filtered by
  `Owner_reference.is_controller` has length `<= 1`.
- **#7 GC-does-not-delete-vrs-pods**: for every in-flight `Builtin_controller ->
  Api_server` DELETE message: its precondition uid is `Some` and `< uid_counter`,
  AND if the target key is still in etcd then it is not a vrs-owned pod in the vrs
  namespace OR its current uid `>` the precondition uid. (The subtle stale-delete
  safety; digest #7.)
- **#8 no-other-pending-request-interferes**: universally over in-flight api
  requests with `src <> Controller(controller_id, vrs.object_ref())`, verb-dispatch
  to the 7 helpers (create/update/update_status/get_then_update/delete/
  get_then_delete/get_then_update_status). Each: a foreign mutation either doesn't
  touch a vrs-owned pod, or is uid/rv-precondition-guarded, or cannot make a pod
  become vrs-owned. This is the biggest predicate; port helper-by-helper from
  `helper_invariants/predicate.rs:27-171`.
- **#9 self-scoping**, **#10 msg-from-key-is-pending**, **#14 only-controllers-
  mutate-pods**, **#15 filtered_pods matrix**, **#16 local-pods-bound**: per digest.
- **#11 current_state_matches** (liveness goal): `|matching_pods| =
  replicas.unwrap_or 1` AND etcd vrs `status.replicas = spec.replicas`.
  `matching_pods` = etcd pods with vrs prefix, vrs namespace, owner_refs contains
  `controller_owner_ref vrs`, selector matches labels, no deletion timestamp.
- **#12 inductive_current_state_matches**, **#13 spec+uid stability**: per digest.

`interesting` per invariant is the "precondition fired" witness — for message-pool
invariants it is "the pool contains a message of the relevant src/verb"; for
etcd/ownership invariants "≥2 etcd objects" or "≥1 owned pod"; for reconcile-state
invariants "an ongoing/scheduled reconcile for vrs_ref exists". State each in the
`.ml` doc comment with the bug class it de-vacuises.

Convention firewall (anvil-ocaml): NO `while`/`for`/`loop`/`return`/`break`/
`continue`; NO `_ ->` on any finite sum (`Step.t` 12, `host_id` 5, `message_content`
4, `api_request`/`api_response` variants, the vrs `step` 7 — all exhaustive); NO
two-arm `match` on `option`/`result` (combinators / `Res`); NO exceptions. Predicates
are pure `bool`. Every `.mli` val has a doc comment citing the Anvil source.

## 4. Trace generation + property harness (`test/`)

`t_p4_invariants.ml`:
- A QCheck `arbitrary` producing a random trace: from `Scenario.seed ~desired
  ~fair:false`, repeatedly draw ONE element of `Cluster.enabled_successors
  Bound.default Scenario.cluster s` uniformly (or by a small weighted `Gen`), up to
  a length bound `N` (say 40), collecting the state sequence. If `enabled_successors`
  is empty, stop early. The generator MUST be able to reach create/list/reconcile
  states (verify by the enumerator test).
- **Property P_safety**: for a random trace, `Invariants.conjunction (all ~cr
  ~controller_id) s` holds for EVERY state `s` in the trace. On failure, report the
  first violated invariant name + the offending state (QCheck shrinking).
- **Property P_liveness_sample**: from `Scenario.seed ~desired ~fair:true`, driving
  ONLY productive successors to a fixpoint (bounded fuel), any `Scenario.is_quiescent`
  state satisfies `(liveness_goal ~cr).holds`. This is a SAMPLE, not proof; label it.
- **Non-vacuity unit tests (property-side confirm-by-mutation)**: for EACH
  invariant, construct by hand a `cluster_state` that VIOLATES exactly it (e.g. two
  etcd objects sharing a uid for #1; a stored pod owned by the vrs plus an in-flight
  foreign delete with a stale-but-not-guarded precond for #7/#8), and assert
  `holds = false`. Also assert `holds = true` on `Scenario.seed`. This proves the
  predicate DISCRIMINATES (is not `fun _ -> true`).

`t_p4_enumerator.ml` (finding-14, enumerator confirm-by-mutation):
- For each invariant, run a bounded directed/random exploration from
  `Scenario.seed ~desired ~fair:false` under `Bound.default` and assert some reached
  state has `interesting = true`. If an invariant's `interesting` is never reached,
  the bounds make it VACUOUS → the test FAILS with that invariant's name. This is
  the "prove each safety invariant CAN fire under the chosen bounds" obligation.
- Document (a `log`/comment) which bounds each invariant's `interesting` needs; if
  `Bound.default` is too tight for some invariant, RAISE the relevant default (and
  say which bug class the raise re-admits) rather than silently dropping it.

`t_p4_roundtrip.ml` (marshal round-trip; guard the P1/P3 shallow-generator trap):
- QCheck `arbitrary` for `Vreplica_set_reconciler.s`: `reconcile_step` ranges over
  ALL 7 variants (Init/After_list_pods/After_create_pod n/After_delete_pod n/
  After_update_vrs_status/Done/Error, with realistic `n`), and `filtered_pods` is
  `Some [deeply-populated Pod.t; ...]` on a healthy fraction of cases (NOT always
  `None` — that was the P3 vacuity trap). Property: `unmarshal_state (marshal_state
  s) = Ok s'` with `s'` equal to `s`.
- QCheck `arbitrary` for `Dynamic_object.t` (vrs + pod kinds, populated metadata
  incl owner_refs/uid/rv), round-tripped through the relevant view marshal/unmarshal.
- Confirm-by-mutation: break one codec key, watch the property fail (documented).

`t_p4_oracle.ml` (§5).

## 5. The correspondence oracle (`oracle_api_server.ml/.mli`)

Independent re-port of Anvil's SPEC api-server handler
(`src/kubernetes_cluster/spec/api_server/state_machine.rs`, handlers l.198-820,
`transition_by_etcd` l.804 — the SPEC, not the imperative `executable_model/`; the
spec is the more direct OCaml translation and is proven-equal to the exec model).

```ocaml
type state = { resources : Api_server.stored_state; uid : int; rv : int }
val of_api_server : Api_server.state -> state
val handle : Api_server.installed_types -> Message.t -> state -> state * Message.t
  (* mirrors Api_server.transition_by_etcd: apply one api-request message to the
     etcd store, returning the next store/counters and the response message. *)
val agrees : Api_server.installed_types -> Message.t -> Api_server.state -> bool
  (* our Api_server.transition_by_etcd vs `handle`, on the SAME request+state:
     resulting stores equal (as maps of Dynamic_object, compared structurally) and
     response messages equal (Message.equal). *)
```

`agrees` is the differential property. `t_p4_oracle.ml` drives it with QCheck:
arbitrary permissive `installed_types`, arbitrary `Api_server.state` (a few stored
vrs/pod/configmap objects with populated metadata + advanced counters), and an
arbitrary in-flight api-request `Message.t` (all verbs). It MUST exercise
create/get/list/delete/update/update_status + the three get_then_* composites and
the error paths (uid/rv conflict, not-found, already-exists). Confirm-by-mutation:
perturb one branch of the oracle (or of a local copy) and watch `agrees` fail on
some request — proving the differential is live, not `fun _ -> true`.

**HONEST LIMIT (put verbatim in the .mli header, digest verdict):** this oracle is
an independent re-derivation of the SAME Anvil spec (Anvil's exec model is a
machine-proven refinement of it), so a mismatch localizes a bug in OUR
`api_server.ml` port, not in Anvil's design; it is a one-sided GOLDEN reference,
not a two-eyes differential peer. No independent runnable model of the full cluster
step (`enabled_successors`: GC/network/scheduler/crash) exists, so ONLY the
api-server handler is oracled.

## 6. Confirm-by-mutation obligations (both flavours; the P4 core discipline)

Per [[feedback-confirm-tests-by-mutation]] a property never SEEN to fail is not
evidence. Deliver BOTH:
1. **Property-side**: each invariant has a negative unit test (hand-crafted
   violating state → `holds=false`); the round-trip and oracle each have a
   documented "break one key/branch → property fails" mutation, applied once during
   build, watched failing, restored (tree left green, git diff empty — verify with
   [[feedback-review-agents-may-leave-mutations]]).
2. **Enumerator-side**: `t_p4_enumerator.ml` proves each invariant's `interesting`
   precondition is actually reached under `Bound.default`, so a passing P_safety is
   not passing vacuously (finding 14).

## 7. Build / test commands

`eval $(opam env --switch=anvil-ocaml --set-switch); dunecho build` (expect 0/0).
`dunecho test` HANGS (wrapper bug) — run each `_build/default/test/t_p4_*.exe`
directly (`perl -e 'alarm 60; exec @ARGV' _build/default/test/t_p4_invariants.exe`).
The existing 77 P1-P3 assertions must stay green (additive change).

# P2 build spec — the reconciler contract + cluster transition system

Normative contract for Phase 2 of anvil-ocaml (whole-repo plan:
`../../../comp-cat-ocaml/lib/temporal/ARCHITECTURE-anvil-ocaml.md` §3). P2 is a
faithful port of Anvil's `state_machine/`, `reconciler/spec/` and
`kubernetes_cluster/spec/` trees: the generic state-machine framework, the
`RECONCILER` contract, and the compound cluster transition system (12-variant
`Step`, six host state machines, the network-baked-in composition, bounded
`enabled_successors`, the first-class-module controller pack, and the ESR goal).

P2 is **where anvil-ocaml first consumes comp_cat** (the Phase-0 TLA core): the
`Action` temporal projections and the ESR goal are `Comp_cat.Temporal` formulas.
`comp_cat` is pinned into the `anvil-ocaml` opam switch already (`opam list`
shows `comp_cat dev`). Its temporal modules are `Comp_cat.Temporal` (AST + smart
ctors: `state_pred`/`action_pred`/`lift_state`/`lift_action`/`always`/
`eventually`/`leads_to`/`weak_fairness`/`tla_forall`/`implies`/...), plus
`Comp_cat.Verdict`, `Comp_cat.Behaviour`, `Comp_cat.Rule`.

## Ground truth

- Anvil reference clone: `<SCRATCH>/anvil-src/src/`
  (`<SCRATCH>` = `/private/tmp/claude-501/-Users-oobi-Documents-claude1/8b05c8cd-e808-4181-86d8-de9a8f03f31e/scratchpad`).
  Spec trees: `state_machine/`, `reconciler/spec/`, `kubernetes_cluster/spec/`.
  **Ignore every `proof/` file** (OCaml is not a prover).
- Pre-extracted structured digests (read the one for the module you build FIRST;
  they carry exact field/variant/guard detail with source line refs):
  `<SCRATCH>/p2-digests/digest_message.md`, `digest_api_server_types.md`,
  `digest_api_server_sm_a.md`, `digest_api_server_sm_b.md`, `digest_controller.md`,
  `digest_network_gc.md`, `digest_external_podmonkey.md`.
- P1 is done and committed: the `anvil_k8s_objects` library (`Common`,
  `Dynamic_object`, `Object_meta`, `Owner_reference`, `Value`, `Api_method`, the
  `Resource_view.Make` functor, `views/{config_map,pod,stateful_set}`). Read its
  `.mli`s for the exact surface. `anvil_support` provides `Res`/`Err`/`Smap`/
  `Sset`, and P2 adds `Imap` (`Map.Make(Int)`) and `Multiset.Make` (already
  written — see below).

## Representation decisions (locked, mirror P1)

- Verus `int`/`nat` counters (`RPCId`, `uid`, `resource_version`, reconcile ids)
  → OCaml `int` carriers behind abstract newtypes; they are ids/counters, never
  arithmetic operands beyond `+1` allocation. `nat` monotonicity is documented,
  not bignum-modelled.
- `Map<K,V>` → `Smap`/`Imap` as key demands. `Multiset<Message>` → the
  `Message.Pool` instance of `Multiset.Make` (order-insensitive bag).
- `Set<T>` → `list`/`Sset` as appropriate.
- Hilbert `choose` / `exists s'` does not port. `next` is a **relation**
  (`state -> step -> state -> bool`) plus an executable **`enabled_successors`**
  enumeration (see §Cluster).
- Anvil `spec_fn` extensional equality (e.g. `InstalledTypes` equality) does not
  port; where a spec relies on it, model the datum concretely (see api_server).

## Convention firewall (hard — the review will hunt these)

Identical to P1. No exceptions (`raise`/`failwith`/`assert`/`invalid_arg`); every
partial function returns `Res.t`. No two-arm `match` on `option`/`result` outside
`Res`/`Err` (use combinators). **Exhaustive matches on every finite sum — no
`_ ->` catch-all** (`Step` 12, `host_id` 5, `message_content` 4, `api_request`/
`api_response` 9, `api_error` 12, `Action.result` 2, `controller_step` 3, etc.).
Combinators (fold/map/filter_map) over hand-written recursion and over imperative
loops. Every public `.mli` val carries a doc comment with an Anvil source
pointer. Warning flags on every dune: `(:standard -w +a-4-9-40-41-42-44-45-70
-open ...)` — non-exhaustive match is an ERROR. Dual license is repo-level.

Note vs P1: `Common.is_controller` style helpers exist; **`HostId::is_controller_id`
uses a `_ => false` in Anvil but here it MUST be an exhaustive 5-arm match**
(4 non-`Controller` arms `-> false`) — no wildcard.

## Library layout (three new libraries)

```
lib/state_machine/  (anvil_state_machine)  deps: anvil_support comp_cat        [WRITTEN]
   action.ml/.mli          Action + pre/forward/weak_fairness + result + next_action_result
   state_machine.ml/.mli   StateMachine (init/step_to_action/action_input) + next_results (no choose); net
lib/reconciler/     (anvil_reconciler)     deps: anvil_support anvil_k8s_objects [WRITTEN]
   io.ml/.mli              request_view/response_view (2-arm) + void
   reconciler.ml           RECONCILER module type (4 members)
lib/cluster/        (anvil_cluster)         deps: anvil_support anvil_k8s_objects anvil_reconciler anvil_state_machine comp_cat
   (include_subdirs unqualified)   -- all cluster modules flat in one library, like Anvil's crate
   message.ml/.mli         [BUILDER]  host_id/message_content/Message/Pool/Rpc_id/allocator/MessageOps + constructors
   step.ml                 [CRUX, written]  the 12-variant Step
   bound.ml/.mli           [CRUX, written]  Bound.t + per-bound bug-class annotations
   controller_pack.ml/.mli [CRUX, written]  first-class-module CONTROLLER pack
   network.ml/.mli         [BUILDER]  NetworkState + deliver
   api_server.ml/.mli      [BUILDER]  APIServerState + handle_request (9 handlers) + init
   controller.ml/.mli      [BUILDER]  ControllerState + the reconcile driver (3 steps) + ReconcileModel
   builtin_controllers.ml/.mli [BUILDER] BuiltinControllerChoice + GC action
   external.ml/.mli        [BUILDER]  ExternalState + ExternalModel + external action
   pod_monkey.ml/.mli      [BUILDER]  pod-monkey create/update/delete actions
   cluster.ml/.mli         [BUILDER]  ClusterState + init + next_step relation + the 12 host actions + enabled_successors
   esr.ml/.mli             [CRUX, written]  desired_state_is + eventually_stable_reconciliation
```

The `anvil_cluster` dune (BUILDER creates it):
```
(include_subdirs unqualified)
(library
 (name anvil_cluster)
 (libraries anvil_support anvil_k8s_objects anvil_reconciler anvil_state_machine comp_cat)
 (flags (:standard -w +a-4-9-40-41-42-44-45-70 -open Anvil_support -open Anvil_k8s_objects -open Anvil_state_machine -open Anvil_reconciler)))
```
(`Anvil_state_machine` and `Anvil_reconciler` ARE opened, so `Action.t`,
`State_machine.next_results`, `Io.*` and `Reconciler.RECONCILER` are referenced
bare. `Comp_cat` is NOT opened — reference it qualified: `Comp_cat.Temporal`.)

---

## LOCKED cross-module types (the crux depends on these EXACT shapes)

### `message.ml/.mli` (source: `digest_message.md`)

```ocaml
module Rpc_id : sig
  type t                               (* Anvil RPCId = nat; abstract int newtype *)
  val zero : t
  val of_int : int -> t
  val to_int : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int          (* smaller = allocated earlier (timestamp) *)
end

type host_id =                          (* Anvil HostId, 5 variants, message.rs:25 *)
  | Api_server
  | Builtin_controller
  | Controller of int * Common.object_ref     (* controller_id, cr_key *)
  | External of int                            (* controller_id *)
  | Pod_monkey
val equal_host_id : host_id -> host_id -> bool
val is_controller_id : host_id -> int -> bool  (* EXHAUSTIVE 5-arm, no wildcard *)

type message_content =                  (* Anvil MessageContent, 4 variants, message.rs:59 *)
  | Api_request of Api_method.api_request
  | Api_response of Api_method.api_response
  | External_request of Value.t
  | External_response of Value.t

type t = { src : host_id; dst : host_id; rpc_id : Rpc_id.t; content : message_content }
val equal : t -> t -> bool              (* structural *)

module Pool : sig                       (* Multiset<Message>; instance of Multiset.Make *)
  include module type of Multiset.Make (struct
    type nonrec t = t
    let equal = equal
  end)
end
(* Implementation: `module Pool = Multiset.Make (struct type nonrec t = t let equal = equal end)` *)

module Rpc_id_allocator : sig           (* message.rs:35 *)
  type t
  val init : unit -> t                  (* rpc_id_counter = 0 *)
  val allocate : t -> t * Rpc_id.t      (* (allocator{counter+1}, allocated=counter); thread the NEW allocator forward *)
end

type message_ops = { recv : t option; send : Pool.t }   (* MessageOps, message.rs:13 *)

val form_msg : src:host_id -> dst:host_id -> rpc_id:Rpc_id.t -> content:message_content -> t
val received_msg_destined_for : t option -> host_id -> bool   (* None -> TRUE (vacuous) *)
val resp_msg_matches_req_msg : t -> t -> bool
val form_matched_err_resp_msg : t -> Api_method.api_error -> t
val form_external_resp_msg : t -> Value.t -> t               (* swaps src/dst, keeps rpc_id *)
(* PLUS every constructor family from digest_message.md §4, ALL exposed in the .mli
   with doc + source line: the 9 `form_<X>_resp_msg` (swap src/dst, wrap resp in
   Api_response(<X> resp)), the 9 `<x>_req_msg_content : ... -> message_content`
   (wrap an Api_method request struct in Api_request), and the host req builders
   `controller_req_msg`, `controller_external_req_msg`, `built_in_controller_req_msg`,
   `pod_monkey_req_msg`. Port each EXACTLY as the digest tabulates (fields, src/dst,
   Option-ness). `resp_msg_matches_req_msg` per digest §5 (same rpc_id, dst/src
   crossover, paired request/response kind). *)
```

### Host sub-state types (each in its own module; LOCKED shapes)

`api_server.ml` (digest_api_server_types + _sm_a + _sm_b):
```ocaml
type stored_state = Dynamic_object.t Object_ref_map.t   (* Anvil StoredState = Map<ObjectRef,DynamicObjectView> *)
(* Object_ref keys are not string/int; provide `module Object_ref_map = Map.Make(struct
   type t = Common.object_ref let compare = <total order on (kind,namespace,name)> end)`
   in api_server.ml (or a shared module). Deterministic ordering for enumeration. *)
type state = {
  resources : stored_state;
  uid_counter : int;                    (* next uid; +1 on create *)
  resource_version_counter : int;       (* next rv; +1 on every create/update/delete write *)
  stable_resource_version_counter : int (* if present in source; else omit *);
}
type installed_types  (* per-kind unmarshal + validation dispatch; see below *)
```
`InstalledTypes` in Anvil is an extensional map from `Kind` to spec-fn triples
(unmarshal, state_validation, transition_validation). Model it concretely as a
record of first-class-module / function fields the api-server calls to validate
and unmarshal a `Dynamic_object.t` by `kind`. The GC and api-server use it to
decide object validity. Keep it a small concrete record; document the modelling
divergence (Anvil compares it by spec-fn equality, which we do not need).

`controller.ml` (digest_controller):
```ocaml
type reconcile_id = int
module Reconcile_id_allocator : sig type t val init : unit -> t val allocate : t -> t * reconcile_id end
type ongoing_reconcile = { ... }   (* EXACT fields from digest: triggering cr key/obj, pending_req_msg : Message.t option, local_state, reconcile_id, ... *)
type state = {
  ongoing_reconciles : ongoing_reconcile Object_ref_map.t;   (* Map<ObjectRef,OngoingReconcile> *)
  scheduled_reconciles : Dynamic_object.t Object_ref_map.t;  (* Map<ObjectRef,DynamicObjectView> *)
  reconcile_id_allocator : Reconcile_id_allocator.t;
}
(* ReconcileModel = the installed reconciler as a first-class module value:
   what Anvil's ControllerModel.reconcile_model carries. Model it as a
   (module Reconciler.RECONCILER) pack plus the reconciled `kind`. See §Controller. *)
```

`network.ml` (digest_network_gc):
```ocaml
type state = { in_flight : Message.Pool.t }   (* NetworkState, network/types.rs *)
```

`external.ml`, `builtin_controllers.ml`, `pod_monkey.ml`: shapes per their digests
(`ExternalState`, `ExternalModel`, `BuiltinControllerChoice`, action inputs).

---

## §State machine framework — WRITTEN (`lib/state_machine`)

Do not edit. `Action.t = {precondition; transition}`; `Action.pre`/`forward`
(temporal projections), `Action.weak_fairness ~name`, `Action.result =
Disabled | Enabled`, `Action.next_action_result`. `State_machine.t =
{init; step_to_action; action_input}`; `State_machine.next_results ~steps`
returns ALL enabled successors (no choose); `State_machine.net`/`net_next_result`
for the single-action network machine. Host state machines instantiate these.

## §Reconciler — WRITTEN (`lib/reconciler`)

Do not edit. `Reconciler.RECONCILER` (s/k/ereq/eresp + reconcile_init_state/
reconcile_core/reconcile_done/reconcile_error); `Io.request_view`/`response_view`
(2-arm) + `Io.void`.

## §Message — BUILDER

Author `message.ml` + `message.mli` from `digest_message.md`, using the LOCKED
types above. Expose ALL constructors/predicates the hosts use. `Rpc_id_allocator
.allocate` returns `(new_allocator, allocated_id)` where `allocated = current
counter` and `new counter = current + 1` (do NOT pre-increment).

## §Host state machines — BUILDER (one module each)

Each host is a `State_machine.t` (or `.net` for the network) whose `Action`s port
the corresponding Anvil `spec fn` transitions. Port the **exact** preconditions
and effects from the digests. The heavy ones:

- **api_server**: `handle_request` dispatches on the 9 `api_request` variants
  (get/list/create/update/update_status/delete/get_then_delete/get_then_update/
  get_then_update_status). Port from `digest_api_server_sm_a.md` (get/list/create/
  update/update_status + rv/uid stamp-then-increment + validation) and
  `digest_api_server_sm_b.md` (delete/finalizers/deletion_timestamp + the three
  get_then composites + all validity helpers). `create` stamps uid (from
  `uid_counter`) and resource_version, runs `created_object_validity_check`
  (state_validation via installed_types); `update`/`update_status` run
  transition_validation; a no-op update is structural-equality-detected;
  responses are `form_<X>_resp_msg` / `form_matched_err_resp_msg`. Objects that
  fail to unmarshal are handled per the digest. Represent the "list has
  nondeterministic order" as a deterministic ordered `bindings` (document it).
- **controller** (the reconcile driver): from `digest_controller.md`. Three
  `controller_step` actions (run/continue/end reconcile — confirm exact names).
  A scheduled cr becomes an ongoing reconcile; `reconcile_core` (the installed
  `RECONCILER.reconcile_core`) is invoked with the matched response; its produced
  `Io.request_view option` becomes a sent `Message` (marshal the cr for the wire
  as needed); `reconcile_done`/`reconcile_error` end the round. `pending_req_msg`
  matches responses via `resp_msg_matches_req_msg`. The reconciler is carried as
  a `(module Reconciler.RECONCILER)` in the `ControllerModel`.
- **network**: single `deliver` action — precondition: `received` message is in
  `in_flight` (or `recv = None`); effect: `Pool.remove_one recv` then `Pool.union
  send`. Use `Message.Pool`.
- **builtin_controllers / GC**: `BuiltinControllerChoice`, the GC action deletes
  an owned object whose owner is gone (exact predicate + delete request +
  rpc_id allocation from `digest_network_gc.md`).
- **external**: `ExternalModel`/`ExternalState`; the external host consumes a
  message + resources view and emits responses (`digest_external_podmonkey.md`).
- **pod_monkey**: create/update/delete-pod actions that SEND requests to the api
  server via the network (does not mutate resources directly).

Each host `.mli` exposes: its state type, its `State_machine.t`/`.net` value (or
a `next : ... -> Action.t` constructor the cluster composes), and `init`.

## §Cluster — BUILDER (`cluster.ml/.mli`, source: `cluster.rs`, read the LOCKED relation below)

`ClusterState` (public record, plain data — mirrors `Api_method` record style):
```ocaml
type controller_and_external = {
  controller : Controller.state;
  external_ : External.state option;
  crash_enabled : bool;
}
type cluster_state = {
  api_server : Api_server.state;
  controller_and_externals : controller_and_external Imap.t;
  network : Network.state;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
  req_drop_enabled : bool;
  pod_monkey_enabled : bool;
}
type controller_model = { reconciler : (module Reconciler.RECONCILER); kind : Common.kind; external_model : External.model option }
type t = { installed_types : Api_server.installed_types; controller_models : controller_model Imap.t }   (* the Cluster *)
```
Accessors (Anvil `s.resources()`/`s.in_flight()`/...): `resources`, `in_flight`,
`ongoing_reconciles`, `scheduled_reconciles`, and — required by the WRITTEN
`esr.ml` crux — **`lookup_resource : cluster_state -> Common.object_ref ->
Dynamic_object.t option`** (etcd lookup by key). The written `esr.ml` also calls
`Object_meta.name`, `Object_meta.namespace`, `Object_meta.uid`,
`Object_meta.deletion_timestamp` and `Common.Uid.equal`: confirm those accessors
exist in P1's `object_meta.mli`/`common.mli`, and **add any missing accessor**
(non-invasively — just a projection). Do not change `esr.ml`, `step.ml`,
`bound.ml/.mli`, or `controller_pack.ml`; the builder modules must satisfy their
references.

**`init : t -> cluster_state -> bool`** — port `cluster.rs:110` exactly (api_server
init ∧ builtin init ∧ network init ∧ req_drop_enabled ∧ pod_monkey_enabled ∧ for
every controller model: its state exists ∧ is init ∧ crash_enabled ∧ external
init-if-present). Use `Imap.for_all`.

**`next_step : t -> cluster_state -> Step.t -> cluster_state -> bool`** — the
compound relation, `cluster.rs:153`. EXHAUSTIVE 12-arm match on `Step.t`; each arm
is `(host_action).forward input s s'` (i.e. `Action.forward (host_action t) input
s s'`). Reproduce EACH host action's `{precondition; transition}` from `cluster.rs`
(api_server_next, builtin_controllers_next, controller_next→chosen_controller_next,
schedule_controller_reconcile, restart_controller, disable_crash, drop_req,
disable_req_drop, pod_monkey_next, disable_pod_monkey, external_next→
chosen_external_next, stutter).

**The network-baked-in composition (TRUSTED, architecture finding 8 — reproduce
VERBATIM, do not simplify):** every message-carrying host action composes the host
machine's `next_result` AND `Network.deliver`'s result, and its precondition
requires **BOTH** `Enabled` (plus `received_msg_destined_for`), and its transition
updates the host sub-state, the network, and (for controller/gc/pod_monkey) the
`rpc_id_allocator` from the host result. Dropping either `Enabled` conjunct
silently changes the semantics; keep both. (See `cluster.rs:173-299,439-595`.)

**`next : t -> cluster_state -> cluster_state -> bool`** = `exists step,
next_step t s step s'` — but `exists` does not port; expose `next` only via
`enabled_successors` (below), and optionally a `next_rel : t -> cluster_state ->
Step.t -> cluster_state -> bool` alias of `next_step` for the assurance spine.

**`enabled_successors : Bound.t -> t -> cluster_state -> (Step.t * cluster_state)
list`** (architecture finding 14) — the executable, bounded nondeterministic
enumeration replacing `choose`. Enumerate the step domain, bounding every
unbounded index by `Bound.t`:
  - APIServerStep / drop_req: `recv` ranges over `Message.Pool.distinct
    s.network.in_flight` destined for the api server (+ `None`), capped by
    `Bound.max_in_flight`.
  - ControllerStep / ExternalStep: `controller_id` over `Imap` keys, `recv` over
    in-flight destined messages (+None), `scheduled_cr_key` over
    `scheduled_reconciles` keys.
  - ScheduleControllerReconcileStep: `(controller_id, object_key)` over
    controller models × resource keys of the matching `kind`.
  - Restart/DisableCrash/External/... over controller ids.
  - PodMonkeyStep: pods bounded by `Bound.max_objects_per_kind` (enumerate a
    bounded pod candidate set; document the bug class this may exclude).
  - Disable*/Stutter: singletons.
For each enumerated `(step, input)`, evaluate the host action's
`next_action_result`; keep the `Enabled` successors as `(step, s')`. This is
`State_machine.next_results` applied per host, unioned across the 12 step
families. **Never silently truncate** — if a `Bound` clips a domain, that is by
design and annotated; do not add hidden caps beyond `Bound.t`.

## §controller_pack — CRUX (WRITTEN)

`module type CONTROLLER` (a `RECONCILER` module `R` + `id : int` + `marshal_state`
+ `unmarshal_cr`), `type packed = (module CONTROLLER)`. The cluster's controller
map is heterogeneous by construction; the CUV and the builtin GC are two packed
entries. Value erasure at the untyped network is intrinsic and documented here.

## §Bound — CRUX (WRITTEN)

`Bound.t` record; each field is a cap on an otherwise-unbounded enumeration domain,
**annotated with the bug class it may exclude** (finding 14). A `default`.

## §Step — CRUX (WRITTEN)

The 12-variant `Step.t`, exhaustive, payloads exactly `cluster.rs:75`.

## §esr — CRUX (WRITTEN)

`desired_state_is` (a `cluster_state` `state_pred`) + `eventually_stable_
reconciliation` (`tla_forall` over cr: `always(desired) ~> always(matches)`),
`Comp_cat.Temporal` formulas (`esr.rs`).

---

## Tests (`test/`, add to the existing `test/dune` names list; deps += the new libs)

- `t_state_machine.ml`: `next_results` returns ALL enabled successors (a machine
  with 2 enabled steps yields 2), `Disabled` steps contribute nothing;
  `next_action_result` truth table.
- `t_message.ml`: `Rpc_id_allocator.allocate` monotonicity + uniqueness;
  `received_msg_destined_for None _ = true`; `form_matched_err_resp_msg` swaps
  src/dst and preserves rpc_id for each of the 9 request variants;
  `resp_msg_matches_req_msg` truth table; `Pool` multiset add/remove_one/equal.
- `t_cluster.ml`: `init` truth table; a hand-built small cluster (one ConfigMap
  reconciler) takes a `schedule_controller_reconcile` then an api-server
  `create` step via `enabled_successors`; the network-composition precondition
  rejects a step whose network side is `Disabled`; `next_step` holds for the
  produced successor and fails for a tampered one.
- `t_api_server.ml`: create stamps uid+rv and increments both counters; a
  conflicting update yields `Conflict`; delete with a finalizer stamps a
  deletion_timestamp instead of removing; a get on an absent key yields
  `ObjectNotFound`.
- `t_reconcile_driver.ml`: a trivial `RECONCILER` (one create then done) driven
  through run→(api create)→continue→end; `pending_req_msg` matched by
  `resp_msg_matches_req_msg`.
- **confirm-by-mutation** (`feedback-confirm-tests-by-mutation`): after green, for
  ≥4 guards — (a) the network-baked-in `Enabled` conjunct in a host action
  precondition, (b) `received_msg_destined_for` None-vacuity, (c) api-server
  create uid/rv stamping, (d) `enabled_successors` bound on `recv` (that a
  deliverable message actually produces a successor) — neuter the guard, show the
  paired negative test flips to failing, restore. Record which test pins which
  guard in a comment block.

## Build / run

```
eval $(opam env --switch=anvil-ocaml --set-switch)
dunecho build      # 0 warnings / 0 errors required
```
`dunecho test` HANGS (wrapper bug); run test exes directly:
`_build/default/test/<name>.exe` (wrap with `perl -e 'alarm 60; exec @ARGV' -- <exe>`).
`-j 2` if memory-bound.
```
```

# BUILD-SPEC-P7 — Executable shim (deterministic core)

Normative contract for Phase 7 of the anvil-ocaml port. Hand-authored (crux
`.mli` + this spec); `.ml` bodies, the native stub `.ml`, `bin/operator.ml`, and
tests are implemented against it. Do NOT edit the four crux `.mli`
(`concurrency`, `k8s_client`, `controller_runtime`, `exec_api_server`) or
`k8s_client_native.mli` — implement to them exactly.

## 0. Scope and honest limits (state these, do not overclaim)

P7 delivers the **deterministic executable core** of Anvil's controller runtime:
the `CONCURRENCY` + `K8S_CLIENT` interfaces, a pure `Direct` (identity-monad)
backend, an **in-memory `exec_api_server`** backend built on the trusted P2
`Api_server.transition_by_etcd`, and a `controller_runtime` reconcile loop that
drives the erased P3 `reconcile_model` to a done/error fixpoint. `bin/operator.ml`
runs a VReplicaSet reconcile to convergence, in-process, with no network.

Honest limits, baked into the code and docs:
1. **No real cluster (Leg 3 deferred).** The native list-watch/auth/TLS/discovery
   backend is `k8s_client_native` — an interface + a stub returning a documented
   `Err.t`. No fabricated network code.
2. **`Direct` models no interleaving.** `both` is sequential, `sleep` a no-op. The
   executable core is deterministic; interleaving is the P4/P5 legs' job.
3. **Correspondence is one-sided, OCaml-vs-OCaml.** `exec_api_server`'s oracle
   cross-checks the port against the P4 `Oracle_api_server` re-port. Catches OUR
   porting bugs; transfers no Anvil guarantee (identical to P4's caveat).
4. **`run_controller` is fuel/round-bounded**, not a live informer; the work
   `queue` is an explicit deterministic stand-in for a change stream.

**The P7 payoff over P5/P6:** the unbounded executable reconcile actually reaches
`Done` and actually creates the pods — the convergence the bounded checker (P5)
and liveness skeleton (P6) could only reach vacuously under a finite `rv_ceiling`.

## 1. Module inventory (`lib/exec_shim/`, library `anvil_exec`)

| file | status | content |
|---|---|---|
| `concurrency.mli` | AUTHORED | `CONCURRENCY` sig + `Direct` |
| `concurrency.ml` | TODO | `Direct` = identity monad |
| `k8s_client.mli` | AUTHORED | `K8S_CLIENT` / `WATCH_CLIENT` sigs |
| `exec_api_server.mli` | AUTHORED | in-mem backend + oracle |
| `exec_api_server.ml` | TODO | impl over `Api_server.transition_by_etcd` |
| `controller_runtime.mli` | AUTHORED | `outcome` + `Make(C)(K)` |
| `controller_runtime.ml` | TODO | reconcile loop + requeue |
| `k8s_client_native.mli` | AUTHORED | Leg-3 stub sig |
| `k8s_client_native.ml` | TODO | stub returning deferred `Err.t` |
| `dune` | AUTHORED | library `anvil_exec` |

`k8s_client.mli` is signatures-only (no `.ml`; module types need no impl).

`bin/operator.ml` + `bin/dune` — the demo (see §3).
`test/t_p7_*.ml` + `test/dune` edit — tests (see §4).

## 2. Implementation algorithms

### 2.1 `concurrency.ml`
```
module Direct = struct
  type 'a t = 'a
  let return x = x
  let bind x f = f x
  let both a b = (a, b)            (* left-to-right; a then b *)
  let sleep ~seconds:_ = ()
  let run x = x
end
```
No `open`. `both` must evaluate `a` before `b` (sequential); with strict OCaml
`(a, b)` already does. `-w +a` will warn on the unused `seconds`; name it
`~seconds:_`.

### 2.2 `exec_api_server.ml`
Backend state (mutable):
```
type t = {
  mutable st : Api_server.state;
  installed : Api_server.installed_types;
  mutable rpc : Message.Rpc_id_allocator.t;
  self : Message.host_id;         (* the Controller host we answer as *)
}
type 'a io = 'a
```
- `self`: use `Message.Controller (0, cr_ref)` where `cr_ref` is a representative
  object_ref. The api-server echoes `src` into the response `dst`; we only read
  `content`, so any valid requester works. If `seed` is non-empty, derive `cr_ref`
  from the first seed object's `Dynamic_object.object_ref` (a `Res.t`); else use a
  fixed placeholder ref (`{ kind = Custom_resource "vreplicaset"; name = "_";
  namespace = "default" }`). Confirm `src` usage by reading `Api_server.transition_by_etcd`.
- **one request cycle** (shared by `request`/`request_checked`), returns
  `(api_response, Err.t) result` and mutates `st`/`rpc`:
  1. `let (rpc', rid) = Message.Rpc_id_allocator.allocate t.rpc in` thread it:
     `t.rpc <- rpc'`.
  2. build `msg = { Message.src = t.self; dst = Api_server; rpc_id = rid;
     content = Api_request req }`.
  3. `let (st', resp_msg) = Api_server.transition_by_etcd t.installed msg t.st in`
     set `t.st <- st'`.
  4. extract: `match resp_msg.content with Api_response r -> Ok r | Api_request _
     | External_request _ | External_response _ -> Error (Malformed_value { kind =
     "api_response"; detail = "api-server returned non-response content" })`.
     (Exhaustive 4-arm match on `message_content`, no `_ ->`.)
- `request t req` = the cycle, discarding the agreement bit.
- `request_checked t req`: compute `agreed = Oracle_api_server.agrees t.installed
  msg t.st` **on the PRE-transition `t.st`** (before step 3 mutates it), then run
  the cycle, then `Ok { response; agreed }`. Reuse one `msg`. Build the message
  once, compute `agrees`, then apply `transition_by_etcd`.
- `create ~installed ?seed () `:
  - `st0 = { Api_server.resources = Object_ref_map.empty; uid_counter = 0;
    resource_version_counter = 0 }`. Confirm field names/values via `api_server.mli`.
  - fold the seed list with `Res.fold_m`, each object -> a `Create_request`
    ( `{ namespace = <obj namespace or "default">; obj }` ) run through the cycle;
    map an `api_error` in the `create_response.res` to `Err (Malformed_value {
    kind = "seed"; detail = <show error> })`. Return `t Res.t`.
  - Determine each seed's namespace from `Dynamic_object.metadata obj |>
    Object_meta.namespace` (an option; default `"default"`).
- `state t = t.st`; `lookup t k = Api_server.lookup k t.st` (note arg order:
  `lookup : object_ref -> stored_state -> _`, so `Api_server.lookup k t.st.resources`
  — confirm whether `lookup` takes the store or the state; per scout it takes
  `stored_state`, so pass `t.st.resources`).

### 2.3 `controller_runtime.ml`
```
type outcome = Reconciled | Errored | Incomplete of int
let outcome_equal a b = match a, b with
  | Reconciled, Reconciled | Errored, Errored -> true
  | Incomplete x, Incomplete y -> Int.equal x y
  | Reconciled, _ | Errored, _ | Incomplete _, _ -> false   (* exhaustive, no _ -> _ *)
```
`Make (C) (K)`:
- **`reconcile_with ~client ~model ~cr ~fuel`** — fuel-bounded recursion (NO
  `while`/`for`/`loop`), threading the `C` monad outward and `Res` inward:
  ```
  let rec drive resp state fuel =
    if fuel <= 0 then C.return (Ok (Incomplete 0))
    else if model.Controller.reconcile_error state then C.return (Ok Errored)
    else if model.Controller.reconcile_done  state then C.return (Ok Reconciled)
    else
      let (state', req_opt) = model.Controller.transition cr resp state in
      match req_opt with
      | None -> drive None state' (fuel - 1)
      | Some (Io.K_request api_req) ->
          C.bind (K.request client api_req) (fun r ->
            match r with
            | Error e -> C.return (Error e)
            | Ok api_resp ->
                drive (Some (Io.K_response api_resp)) state' (fuel - 1))
      | Some (Io.External_request _) ->
          C.return (Error (Malformed_value { kind = "external_request";
            detail = "in-memory api-server backend has no external subsystem" }))
  in
  drive None (model.Controller.init ()) fuel
  ```
  Note: `model` field access — `reconcile_model` fields are `kind`, `init`,
  `transition`, `reconcile_done`, `reconcile_error` (see §6). Access via
  `model.Controller.transition` etc. The `req_opt` match is exhaustive over
  `Io.request_view` (2 arms `K_request`/`External_request`) plus the `option`;
  fold the `option` with an explicit 3-way match here (`None` / `Some K_request` /
  `Some External_request`) which is exhaustive and NOT a two-arm option match.
  The inner `K.request` result match is a `result` — 2 arms — allowed only via a
  combinator: prefer `Res`-style but here it is inside the `C` monad, so use an
  explicit `Error`/`Ok` match (this is a genuine two-arm result). To honour the
  "no two-arm match on result" firewall, wrap it: use `Result.fold ~ok ~error` is
  not available (custom Res); instead thread with a local helper
  `let on_ok r k = match r with Ok v -> k v | Error e -> C.return (Error e)` —
  ONE such helper, documented, is the sanctioned form (mirrors how `rule.ml`
  threads `Res` inside another monad). Keep it to that single helper.
- **`run_controller ~client ~model ~queue ~fuel ~max_rounds`** — round-bounded
  recursion over a work set:
  ```
  (* dedup queue preserving first-seen order *)
  (* results : outcome Object_ref_map.t accumulated across rounds *)
  let rec round pending results rounds_left =
    if rounds_left <= 0 || pending = [] then C.return (Ok results)
    else
      (* fold pending: GET each cr, reconcile_with, collect (key, outcome);
         a Get whose response res = Error Object_not_found drops the key. *)
      ... produce (results', requeue) ...
      round requeue results' (rounds_left - 1)
  in
  round (dedup queue) Object_ref_map.empty max_rounds
  ```
  Per key: `K.request client (Get_request { key })`; on `Ok (Get_response { res =
  Ok obj })` -> `reconcile_with ~cr:obj`; record outcome; requeue if `Errored`/
  `Incomplete`. On `Ok (Get_response { res = Error Object_not_found })` -> drop
  the key (deleted cr), record nothing. Other api_errors -> record as a failure
  outcome? No — surface a transport-clean `Errored` outcome for that key and
  requeue, OR return `Error`. Simplest faithful choice: a non-`Object_not_found`
  get error requeues the key as `Errored` (transient). Dedup within a round only;
  across rounds the requeue list is already deduped by construction.
  Use `Res.fold_m` / list folds (NO loops). Thread the `C` monad with the same
  `on_ok` helper. `Object_ref_map.add key outcome results` to accumulate;
  `Object_ref_map` has no `keys` — use `bindings` if enumeration is needed.

### 2.4 `k8s_client_native.ml`
Every entry returns the deferred error. `create _ = Error (Malformed_value {
kind = "native_backend"; detail = "native list-watch/auth/TLS backend deferred to
Leg 3 (research-grade); use Exec_api_server for the deterministic core" })`.
`request`/`watch`: `t` is abstract and unconstructible to a working state, but the
functions must type-check — give `t` a concrete definition (e.g. `type t = config`)
and have `request`/`watch` return the same deferred `Malformed_value`. `type 'a io
= 'a`. Keep it tiny; its only job is to make the interface real and honest.

## 3. `bin/operator.ml` — deterministic reconcile-to-convergence demo

`bin/dune`:
```
(executable
 (name operator)
 (libraries anvil_support anvil_k8s_objects anvil_reconciler anvil_state_machine
   anvil_cluster anvil_controllers anvil_assurance anvil_exec comp_cat)
 (flags (:standard -w +a-4-9-40-41-42-44-45-70 -open Anvil_support
   -open Anvil_k8s_objects -open Anvil_reconciler -open Anvil_cluster
   -open Anvil_controllers -open Anvil_exec)))
```
`operator.ml` (deterministic; may `print_endline` a trajectory summary — the ONE
place `print` is allowed, it is a demo binary not library code):
1. Build a VReplicaSet cr `Dynamic_object.t` with `replicas = 3`, 0 owned pods.
   Reuse the P3/P4 scenario constructors if one exists (read
   `test/t_vreplica_set_driver.ml` and `Scenario`/`Vreplica_set` for how a cr is
   built and how `installed_types` for the vreplicaset is obtained — do NOT invent
   a cr shape). Prefer an existing `installed_types` builder used by the api-server
   tests / cluster.
2. `Exec_api_server.create ~installed ~seed:[cr] ()`.
3. `model = Controller.model_of_controller ~kind:Vreplica_set.kind (module
   Vreplica_set_pack.Controller)`.
4. `let key = <cr object_ref>`. `Controller_runtime.Make (Concurrency.Direct)
   (Exec_api_server)` -> `run_controller ~client ~model ~queue:[key] ~fuel:100
   ~max_rounds:5`.
5. Assert (via a printed check + non-zero exit on failure — but NO `assert`
   keyword; use an explicit `if not ok then (print; exit 1)`): the final store has
   `replicas` owned pods of the cr, and the outcome for `key` is `Reconciled`.
   `exit` is allowed in a `bin/` entrypoint.

Keep `operator.ml` free of the library firewall's stricter rules where a binary
legitimately differs (it may `print_endline`/`exit`), but still no loop keywords,
no wildcard on finite sums, no exceptions.

## 4. Tests (`test/t_p7_*.ml`, alcotest; add basenames to `test/dune` `(names ...)`)

All P7 tests run under `Concurrency.Direct`, so `X` is just the pure value.

- **`t_p7_concurrency`** (small): `Direct` monad laws on the identity monad —
  `bind (return x) f = f x`; `bind m return = m`; `both a b = (a,b)`; `sleep` is a
  no-op returning `()`. Locks the backend shape.
- **`t_p7_exec_api_server`**: against a fresh `Exec_api_server` with a
  vreplicaset `installed_types`:
  - CREATE stamps a uid and rv, GET returns it, second CREATE of the same ref ->
    `Object_already_exists`; DELETE then GET -> `Object_not_found`; UPDATE bumps
    rv; LIST returns the created objects of a kind; UPDATE_STATUS changes status;
    a `Get_then_update` composite succeeds without a spurious `Conflict`.
  - counters: uid_counter advances on CREATE only, resource_version_counter on
    every write. Assert exact counter values across a short sequence.
- **`t_p7_correspondence`** (the oracle): drive a full vreplicaset reconcile
  (via `Controller_runtime.reconcile_with` OR a hand-issued request sequence)
  using `Exec_api_server.request_checked`, and assert `agreed = true` on EVERY
  request. This is the executable-trajectory correspondence to the P4 golden
  re-port.
- **`t_p7_controller_runtime`**: `reconcile_with` on a `replicas=N` vreplicaset
  cr against a fresh store reaches `Reconciled` and the store then holds exactly
  `N` owned pods (the P7 convergence payoff). A second `reconcile_with` (or a
  second `run_controller` round) on the converged store makes no further Create
  (idempotent at the executable level, unbounded rv). `run_controller` over
  `[key]` returns `Reconciled` for the key and terminates within `max_rounds`.
  A `run_controller` whose queue key does not exist in the store drops it (empty
  result, no error). Exhausting `fuel` yields `Incomplete 0` (assert with a tiny
  fuel like 1).
- **`t_p7_mutation`** (confirm-by-mutation, the assurance spine on P7 itself):
  four mutants M1..M4, each SEEN to flip a P7 assertion green->red, then restored
  (leave the tree GREEN). Author them as commented, revert-tested defects
  described in the test file's header, exercised by asserting the CORRECT
  behaviour that each mutant would break:
  - **M1** neuter `Exec_api_server` uid/rv stamping (counters never advance) ->
    `t_p7_exec_api_server`'s counter assertions fail.
  - **M2** drop the `K_request`->`K.request` send in `reconcile_with` (treat as
    `None`) -> `t_p7_controller_runtime`'s "N pods created" assertion fails
    (no Creates ever issued).
  - **M3** corrupt `Exec_api_server`'s applied store (e.g. skip `t.st <- st'`) ->
    `t_p7_correspondence`'s `agreed` stays true but convergence fails (documents
    that the oracle checks the TRANSITION not the persisted mutation) OR, better,
    make M3 corrupt the response returned to the driver -> correspondence still
    passes but reconcile misbehaves; pick the mutant that a P7 test actually
    catches and document which test + why.
  - **M4** make `request_checked` compute `agrees` on the POST-transition state
    (after the store mutated) -> `t_p7_correspondence` no longer detects a planted
    divergence; verify by also planting a one-off oracle disagreement and showing
    the correct pre-state check catches it while the mutant does not.
  Each mutant: implement the correct code; write the test that pins it; TEMPORARILY
  apply the mutant, run, SEE red, restore, run, SEE green. Report the red/green
  transitions. Do NOT leave any mutant applied.

Run tests directly (the `dune test` wrapper HANGS): build with
`eval $(opam env --switch=anvil-ocaml --set-switch); dunecho build`, then
`perl -e 'alarm 180; exec @ARGV' _build/default/test/t_p7_<name>.exe`.

## 5. Convention firewall (audited before "done")

- No `while`/`for`/`loop`/naked `Iterator`-style recursion beyond the sanctioned
  fuel/round-bounded recursions named above.
- No `_ ->` catch-all on any finite sum: `api_request` (9), `api_response` (9),
  `api_error` (12), `message_content` (4), `host_id` (5), `Io.request_view` (2),
  `Io.response_view` (2), `outcome` (3), vreplicaset `step` (7) — all matched
  exhaustively. The `outcome_equal` and message-content matches above show the form.
- No two-arm `match` on `option`/`result` in library code except the SINGLE
  documented `on_ok` helper that threads a `Res`/`result` inside the `C` monad
  (unavoidable; there is no `C`-aware `Res.bind`). Everywhere else use
  `Res`/`Option` combinators (`Res.bind`/`let*`, `Res.map`/`let+`, `Res.fold_m`,
  `Option.fold`, `Option.map`).
- No `raise`/`failwith`/`assert`/`invalid_arg`/exceptions anywhere in `lib/`.
  `bin/operator.ml` may use `exit` and `print_endline` (it is an entrypoint).
- Every partiality flows through `Res.t = ('a, Err.t) result`.
- Doc comment on every public `.mli` value (already satisfied by the authored
  `.mli`; keep it for any new public surface).

## 6. Scouted signatures reference (verbatim; do not re-derive)

`Err.t` (lib/support/err.mli) — closed 5-arm sum, NO Budget/Unsupported:
```
type site = { layer : string; fn : string }
type t =
  | Kind_mismatch of { expected : string; found : string }
  | Malformed_value of { kind : string; detail : string }
  | Missing_field of { owner : string; field : string }
  | Decode_error of { typ : string; detail : string }   (* `typ`, not `type` *)
  | At of { site : site; inner : t }
val show : t -> string
```
`Res` (lib/support): `type 'a t = ('a, Err.t) result`; `bind` value-first
`('a t -> ('a -> 'b t) -> 'b t)`; `let*`/`and*` = bind/both, `let+`/`and+` =
map/both; `all`, `map_m`, `fold_m` (fallible left-fold, first error wins);
`context ~layer ~fn`, `of_option ~none`. NO `value`/`get`/`fold` eliminator.

`Io` (lib/reconciler/io.mli): `type void = |`;
`type 'ereq request_view = K_request of Api_method.api_request | External_request of 'ereq`;
`type 'eresp response_view = K_response of Api_method.api_response | External_response of 'eresp`.

`Controller.reconcile_model` (lib/cluster/controller.mli):
```
type reconcile_model = {
  kind : Common.kind;
  init : unit -> Value.t;
  transition : Dynamic_object.t -> Value.t Io.response_view option -> Value.t
             -> Value.t * Value.t Io.request_view option;
  reconcile_done : Value.t -> bool;
  reconcile_error : Value.t -> bool;
}
val model_of_controller :
  kind:Common.kind ->
  (module Controller_pack.CONTROLLER with type R.s = Value.t
     and type R.ereq = Value.t and type R.eresp = Value.t) ->
  reconcile_model
```
`Api_server` (lib/cluster/api_server.mli):
```
type stored_state = Dynamic_object.t Object_ref_map.t
type state = { resources : stored_state; uid_counter : int; resource_version_counter : int }
type installed_types = { unmarshallable_spec : Common.kind -> Value.t -> bool;
  unmarshallable_status : Common.kind -> Value.t -> bool;
  valid_object : Dynamic_object.t -> bool;
  valid_transition : Dynamic_object.t -> Dynamic_object.t -> bool;   (* (new,old) *)
  marshalled_default_status : Common.kind -> Value.t }
val init : state -> bool
val lookup : Common.object_ref -> stored_state -> Dynamic_object.t option
val transition_by_etcd : installed_types -> Message.t -> state -> state * Message.t
```
`Oracle_api_server` (lib/assurance/oracle_api_server.mli):
```
type state = { resources : Api_server.stored_state; uid : int; rv : int }
val of_api_server : Api_server.state -> state
val handle : Api_server.installed_types -> Message.t -> state -> state * Message.t
val agrees : Api_server.installed_types -> Message.t -> Api_server.state -> bool
```
`Message` (lib/cluster/message.mli):
```
type host_id = Api_server | Builtin_controller | Controller of int * Common.object_ref
             | External of int | Pod_monkey
type message_content = Api_request of Api_method.api_request
  | Api_response of Api_method.api_response
  | External_request of Value.t | External_response of Value.t
type t = { src : host_id; dst : host_id; rpc_id : Rpc_id.t; content : message_content }
module Rpc_id : sig type t val zero : t val of_int : int -> t val to_int : t -> int
  val equal : t -> t -> bool val compare : t -> t -> int end
module Rpc_id_allocator : sig type t val init : unit -> t
  val allocate : t -> t * Rpc_id.t val equal : t -> t -> bool end
```
`Api_method` (lib/k8s_objects/api_method.mli): `api_request` (9 variants:
`Get_request`/`List_request`/`Create_request`/`Delete_request`/`Update_request`/
`Update_status_request`/`Get_then_delete_request`/`Get_then_update_request`/
`Get_then_update_status_request`), `api_response` (9, each record field named
`res`), `api_error` (12: `Bad_request`/`Conflict`/`Forbidden`/`Invalid`/
`Object_not_found`/`Object_already_exists`/`Not_supported`/`Internal_error`/
`Timeout`/`Server_timeout`/`Transaction_abort`/`Other`). Request payloads:
`get_request={key:object_ref}`, `list_request={kind;namespace}`,
`create_request={namespace;obj:Dynamic_object.t}`,
`delete_request={key;preconditions:preconditions option}`,
`update_request={namespace;name;obj}`, `update_status_request={namespace;name;obj}`,
`get_then_*={...;owner_ref:Owner_reference.t;...}`. Response records:
Get/Create/Update/Update_status/Get_then_update/Get_then_update_status carry
`res : (Dynamic_object.t, api_error) result`; List carries
`res : (Dynamic_object.t list, api_error) result`; Delete/Get_then_delete carry
`res : (unit, api_error) result`. `create_request_key : create_request ->
Common.object_ref Res.t` (others return bare object_ref).

`Common` (lib/k8s_objects/common.mli): `type kind` (11 variants, only
`Custom_resource of string` carries a payload); `type object_ref = { kind; name;
namespace }`; `equal_object_ref`. `Object_meta.t` — 10 option fields; `default :
unit -> t`; accessors `name`/`namespace`/`uid`. `Dynamic_object.t` ABSTRACT;
`make ~kind ~metadata ~spec ~status`; accessors `kind`/`metadata`/`spec`/`status`;
`object_ref : t -> Common.object_ref Res.t`.

`Object_ref_map` (lib/cluster) — `include Map.Make(object_ref)`, used unqualified;
full stdlib `Map.S`; NO `keys` (use `bindings`); `equal` needs a value-eq first arg.

`Vreplica_set_reconciler` / `Vreplica_set_pack` (lib/controllers): `step` (7:
`Init`/`After_list_pods`/`After_create_pod of int`/`After_delete_pod of int`/
`After_update_vrs_status`/`Done`/`Error`); `s = { reconcile_step; filtered_pods }`;
`module R : Reconciler.RECONCILER with k=Vreplica_set.t, s=s, ereq=eresp=Io.void`;
`Vreplica_set_pack.Controller` (the CONTROLLER pack, id=0), `Vreplica_set_pack.packed`,
`Vreplica_set_pack.kind = Vreplica_set.kind = Custom_resource "vreplicaset"`.
To build a cr `Dynamic_object.t` and the `installed_types` for the demo/tests,
READ `test/t_vreplica_set_driver.ml`, `test/t_api_server.ml`, and
`lib/assurance/scenario.ml` — reuse their constructors; do NOT invent shapes.

## 7. Build / verify commands
```
eval $(opam env --switch=anvil-ocaml --set-switch)
dunecho build            # expect 0/0
# tests (the dune-test wrapper HANGS):
perl -e 'alarm 180; exec @ARGV' _build/default/test/t_p7_<name>.exe
# demo:
perl -e 'alarm 60; exec @ARGV' _build/default/bin/operator.exe
```
No regression: P1-P6 suites must stay green (spot-check a few t_p4/t_p5/t_p6 exes).
Tree must end CLEAN (no `.bak`/probe/mutant residue) — stage only the intended
`lib/exec_shim/*`, `bin/*`, `test/t_p7_*.ml`, and the `test/dune` + `dune-project`
(if a `bin` stanza needs it) edits.

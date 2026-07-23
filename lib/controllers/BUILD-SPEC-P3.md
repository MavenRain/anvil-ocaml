# BUILD-SPEC-P3: vreplicaset `reconcile_core` (the first concrete RECONCILER)

Normative contract for Phase 3 of the anvil-ocaml port. P3 ports Anvil's
`src/controllers/vreplicaset_controller/` **spec/model surface** into OCaml: the
VReplicaSet custom-resource view, its reconcile step enum, and the pure
`reconcile_core` state machine, then wraps it so the P2 reconcile driver
(`Controller.model_of_controller`) can run it end-to-end.

Anvil sources ported (github anvil-verifier/anvil):
- `controllers/vreplicaset_controller/trusted/spec_types.rs` -> the CR view.
- `controllers/vreplicaset_controller/trusted/step.rs` -> the step enum (view form only).
- `controllers/vreplicaset_controller/model/reconciler.rs` -> `reconcile_core` + helpers.
- `reconciler/spec/io.rs` (`is_some_k_*_resp_view` / `extract_some_k_*_resp_view`) -> `io_resp`.

The `exec/`, `proof/`, `trusted/liveness_theorem.rs`, `trusted/rely_guarantee.rs`
trees do **not** port (executable/prover-only). We port the `model` reconcile
core because it is exactly the spec-level `reconcile_core(cr, resp_o, state)`
shape the P2 `RECONCILER` contract exposes.

---

## 0. Conventions (hard gates, same as P1/P2)

- No exceptions (`Option`/`Res.t` only; the sole allowed `try/with` is P1's
  `Value.of_string`, which we do not touch). No `raise`, no `assert`.
- **No `_ ->` / `_` catch-all on any finite sum.** Every match on a variant type
  enumerates every constructor. This is enforced by an edit-time DENY hook.
  Two-arm `Option`/`Result` matches use combinators (`Option.fold`,
  `Option.value`, `Result.fold`, `Res.( let* )`), not `match`.
- No mutation, no loop keywords (`for`/`while`/`return`/`break`/`continue`);
  `List.map`/`filter`/`fold_left`/`exists`/`filter_map` instead.
- No `List.nth`/`a[i]` partial indexing: use `List.nth_opt` and route `None` to
  the honest error branch.
- Doc comment + Anvil source pointer on every public `.mli` val / type.
- Dual MIT/Apache, no new deps.

---

## 1. Module layout

New library **`anvil_controllers`** at `lib/controllers/` (mirrors Anvil's
`src/controllers/`). It depends on everything below it. Plus two reusable
additions to existing libs.

```
lib/reconciler/io_resp.ml + .mli        (NEW; in anvil_reconciler)
lib/cluster/erase.ml + .mli             (NEW; in anvil_cluster)
lib/controllers/dune                    (NEW lib anvil_controllers)
lib/controllers/vreplica_set.ml + .mli          (the CR resource view)
lib/controllers/vreplica_set_reconciler.ml + .mli (the typed reconcile_core)
lib/controllers/vreplica_set_pack.ml + .mli       (state codec + CONTROLLER pack)
test/t_vreplica_set.ml                  (CR view: validation + marshal round-trip)
test/t_vreplica_set_reconciler.ml       (every reconcile_core transition + mutations)
test/t_vreplica_set_driver.ml           (end-to-end through Controller driver)
```

`lib/controllers/dune`:
```
(library
 (name anvil_controllers)
 (libraries anvil_support anvil_k8s_objects anvil_reconciler anvil_state_machine
   anvil_cluster comp_cat)
 (flags
  (:standard -w +a-4-9-40-41-42-44-45-70 -open Anvil_support
   -open Anvil_k8s_objects -open Anvil_reconciler -open Anvil_cluster)))
```
Do **not** `include_subdirs` (flat lib). Note the `-open Anvil_cluster` so
`Controller_pack`, `Controller`, `Erase`, `Value`, `Dynamic_object` are
in scope bare. `Anvil_k8s_objects` is opened too (for `Pod`, `Object_meta`,
`Label_selector`, `Api_method`, `Common`, `Res`... note `Res`/`Err` come from
`Anvil_support`).

Add the three new test files to `test/dune`'s `(names ...)` and
`(libraries ...)` gains `anvil_controllers`, plus `-open Anvil_controllers` is
NOT added (reference modules qualified in tests to avoid clashes; use
`Anvil_controllers.Vreplica_set` etc. — actually add `-open Anvil_controllers`
for brevity; the test names don't clash).

---

## 2. Exact upstream (P1/P2) API surface the code calls

Do not re-derive these; they are verified from the current tree.

### support (`Anvil_support`, opened everywhere)
- `Res.t = ('a, Err.t) result`; `Res.ok`, `Res.error`, `Res.map`, `Res.bind`,
  `Res.of_option ~none`, `Res.( let* )`, `Res.( let+ )`, `Res.map_m`.
- `Err.t` variants: `Missing_field of {owner;field}`, `Kind_mismatch{expected;found}`,
  `Malformed_value{kind;detail}`, `Decode_error{typ;detail}`, `At{site;inner}`.
- `Smap = Map.Make(String)` (so `Smap.empty`, `Smap.cardinal`, `Smap.bindings`).

### k8s_objects (`Anvil_k8s_objects`, opened)
- `Common.kind = Config_map | Custom_resource of string | Daemon_set
  | Persistent_volume_claim | Pod | Role | Role_binding | Stateful_set
  | Service | Service_account | Secret`. `Common.object_ref = {kind; name; namespace}`.
  Modules `Common.Uid`, `Common.Resource_version`.
- `Object_meta.t = { name : string option; generate_name : string option;
  namespace : string option; resource_version; uid : Common.Uid.t option;
  labels : string Smap.t option; annotations : string Smap.t option;
  owner_references : Owner_reference.t list option; finalizers : string list option;
  deletion_timestamp : string option }` (record exposed).
  `Object_meta.default ()`, `Object_meta.with_generate_name : string -> t -> t`,
  `Object_meta.with_owner_references : Owner_reference.t list -> t -> t`,
  `Object_meta.owner_references_contains : t -> Owner_reference.t -> bool`,
  `Object_meta.well_formed_for_namespaced : t -> bool`.
- `Owner_reference.t = { block_owner_deletion : bool option;
  controller : bool option; kind : Common.kind; name : string;
  uid : Common.Uid.t }`. `Owner_reference.is_controller : t -> bool`
  (= `controller = Some true`). **This is Anvil's `controller_owner_filter()`.**
- `Label_selector.t = { match_labels : string Smap.t option }`.
  `Label_selector.matches : t -> string Smap.t -> bool`.
  `Label_selector.default ()`, `Label_selector.equal`,
  `Label_selector.to_json`, `Label_selector.of_json`.
- `Pod_template_spec.t = { metadata : Object_meta.t option; spec : Pod_spec.t option }`.
  `Pod_template_spec.default/equal/to_json/of_json`.
- `Pod` (`views/pod.ml`): `Pod.t = { metadata : Object_meta.t;
  spec : Pod_spec.t option; status : unit option }`. `Pod.kind = Common.Pod`,
  `Pod.default ()`, `Pod.make ~metadata ~spec ~status`, `Pod.with_metadata`,
  `Pod.marshal : t -> Dynamic_object.t`, `Pod.unmarshal : Dynamic_object.t -> t Res.t`,
  `Pod.equal`.
- `Dynamic_object.t` (abstract): `Dynamic_object.make ~kind ~metadata ~spec ~status`,
  `.kind/.metadata/.spec/.status`, `.to_json/.of_json`, `.equal`.
- `Value.t`: `Value.of_json : Yojson.Safe.t -> t`, `Value.json : t -> Yojson.Safe.t`,
  `Value.equal`.
- `Json` combinators: `Json.str/int_/bool_/obj/list/smap/obj/opt/obj_opt`;
  decoders `Json.to_str/to_int/to_bool/mem/get/opt_mem/to_list/to_smap`.
- `Api_method` (all 9 request + 9 response variants; source order). Requests used:
  - `Api_method.List_request of { kind : Common.kind; namespace : string }`
  - `Api_method.Create_request of { namespace : string; obj : Dynamic_object.t }`
  - `Api_method.Get_then_delete_request of { key : Common.object_ref;
    owner_ref : Owner_reference.t }`
  - `Api_method.Get_then_update_status_request of { namespace : string;
    name : string; owner_ref : Owner_reference.t; obj : Dynamic_object.t }`
  - Full request sum (for exhaustive matches): `Get_request | List_request
    | Create_request | Delete_request | Update_request | Update_status_request
    | Get_then_delete_request | Get_then_update_request | Get_then_update_status_request`.
  - `Api_method.api_error` (12 variants; only pattern-matched generically).
  Responses (the `res` field is the payload):
  - `List_response of { res : (Dynamic_object.t list, api_error) result }`
  - `Create_response of { res : (Dynamic_object.t, api_error) result }`
  - `Get_then_delete_response of { res : (unit, api_error) result }`
  - `Get_then_update_status_response of { res : (Dynamic_object.t, api_error) result }`
  - Full response sum (for exhaustive matches): `Get_response | List_response
    | Create_response | Delete_response | Update_response | Update_status_response
    | Get_then_delete_response | Get_then_update_response | Get_then_update_status_response`.
- `Resource_view.RESOURCE` / `RESOURCE_VIEW` / `Make(R)`: see `stateful_set.ml`
  for the exact instantiation pattern (nested `to_json/of_json/equal/default`,
  a `module R = struct ... end` implementing `RESOURCE`, then
  `include (Resource_view.Make (R) : RESOURCE_VIEW with type t := t and
  type spec := spec and type status := status)`).

### reconciler (`Anvil_reconciler`, opened)
- `Io.void = |`; `Io.request_view = K_request of Api_method.api_request
  | External_request of 'ereq`; `Io.response_view = K_response of
  Api_method.api_response | External_response of 'eresp`.
- `Reconciler.RECONCILER` module type: assoc types `s k ereq eresp`;
  `reconcile_init_state : unit -> s`;
  `reconcile_core : cr:k -> resp:eresp Io.response_view option -> state:s
    -> s * ereq Io.request_view option`;
  `reconcile_done : s -> bool`; `reconcile_error : s -> bool`.

### cluster (`Anvil_cluster`, opened)
- `Controller_pack.CONTROLLER` module type: `module R : Reconciler.RECONCILER`;
  `val id : int`; `val marshal_state : R.s -> Value.t`;
  `val unmarshal_cr : Dynamic_object.t -> R.k Res.t`. `type packed = (module CONTROLLER)`.
- `Controller.model_of_controller ~kind (pack : (module Controller_pack.CONTROLLER
  with type R.s = Value.t and type R.ereq = Value.t and type R.eresp = Value.t))
  : reconcile_model`. Its transition calls `C.R.reconcile_core ~cr ~resp ~state`
  where `resp : Value.t Io.response_view option`, `state : Value.t`. **Therefore
  the pack's inner reconciler R must have `R.s = R.ereq = R.eresp = Value.t`.**
- `Controller.{run_scheduled_reconcile, continue_reconcile ~controller_id,
  end_reconcile, model_of_controller, init, state, action_input,
  ongoing_reconcile, reconcile_model}` — see `t_reconcile_driver.ml`.
- `Message.form_list_resp_msg / form_create_resp_msg / form_get_then_delete_resp_msg
  / form_get_then_update_status_resp_msg`, `Message.resp_msg_matches_req_msg`,
  `Message.Rpc_id_allocator.init`, `Message.Pool.cardinal`.
- `Object_ref_map` (`.empty/.add/.mem/.find_opt`).

---

## 3. `io_resp` (lib/reconciler/io_resp.ml + .mli) — reusable

Anvil's `reconciler/spec/io.rs` splits each response test into
`is_some_k_X_resp_view` (bool) + `extract_some_k_X_resp_view` (payload). Every
call site uses them as `is_some && extract is Ok`. We fuse each pair into ONE
total viewer returning the `res` payload as an option-of-result:

```ocaml
(* .mli, one per response kind actually needed by controllers so far *)
val k_list_resp :
  'a Io.response_view option ->
  (Dynamic_object.t list, Api_method.api_error) result option
(** Anvil [is_some_k_list_resp_view] + [extract_some_k_list_resp_view]
    (reconciler/spec/io.rs). [Some res] iff [resp] is a [Some (K_response
    (List_response _))]; [None] for absent / external / other-kind responses. *)

val k_create_resp :
  'a Io.response_view option ->
  (Dynamic_object.t, Api_method.api_error) result option
val k_get_then_delete_resp :
  'a Io.response_view option -> (unit, Api_method.api_error) result option
val k_get_then_update_status_resp :
  'a Io.response_view option ->
  (Dynamic_object.t, Api_method.api_error) result option
```

Each body enumerates the full `Io.response_view` and `Api_method.api_response`
sums (no wildcard). Pattern for `k_list_resp`:
```ocaml
let k_list_resp (resp : 'a Io.response_view option) :
    (Dynamic_object.t list, Api_method.api_error) result option =
  match resp with
  | None -> None
  | Some (Io.External_response _) -> None
  | Some (Io.K_response r) -> (
    match r with
    | Api_method.List_response { res } -> Some res
    | Api_method.Get_response _ | Api_method.Create_response _
    | Api_method.Delete_response _ | Api_method.Update_response _
    | Api_method.Update_status_response _ | Api_method.Get_then_delete_response _
    | Api_method.Get_then_update_response _
    | Api_method.Get_then_update_status_response _ -> None)
```
The other three are identical modulo the picked variant + payload type.
`k_get_then_delete_resp`'s payload is `unit` (Ok is `()`).

---

## 4. `erase` (lib/cluster/erase.ml + .mli) — reusable void-erasure adapter

Anvil's `ReconcileModel` is fully `Value`-based; a **typed** reconciler with
`ereq = eresp = Io.void` reaches the driver only after its state is marshalled to
`Value` and its void external I/O is erased to `Value`. This functor does that
once, for every void controller.

```ocaml
(* .mli *)
module type STATE_CODEC = sig
  type s
  type k
  val id : int
  val marshal_state : s -> Value.t
  val unmarshal_state : Value.t -> s Res.t
  val unmarshal_cr : Dynamic_object.t -> k Res.t
end

module Void_erase
    (V : Reconciler.RECONCILER
           with type ereq = Io.void
            and type eresp = Io.void)
    (C : STATE_CODEC with type s = V.s and type k = V.k) :
  Controller_pack.CONTROLLER
    with type R.s = Value.t
     and type R.k = V.k
     and type R.ereq = Value.t
     and type R.eresp = Value.t
```

Body — the inner erased reconciler:
```ocaml
module Void_erase (V : ...) (C : ...) = struct
  module R = struct
    type s = Value.t
    type k = V.k
    type ereq = Value.t
    type eresp = Value.t

    let reconcile_init_state () : s = C.marshal_state (V.reconcile_init_state ())

    (* Value external response -> void external response: K passes through;
       a void reconciler declared no external system, so an external response
       cannot arise in a well-formed cluster and is mapped to "no response"
       (routing the typed core into its own no-matching-response error branch). *)
    let to_void_resp (resp : Value.t Io.response_view option) :
        Io.void Io.response_view option =
      match resp with
      | None -> None
      | Some (Io.K_response a) -> Some (Io.K_response a)
      | Some (Io.External_response _) -> None

    (* void request -> Value request: K passes through; External_request carries
       a void payload, unreachable (refuted). *)
    let of_void_req (req : Io.void Io.request_view option) :
        Value.t Io.request_view option =
      match req with
      | None -> None
      | Some (Io.K_request q) -> Some (Io.K_request q)
      | Some (Io.External_request _) -> .

    let reconcile_core ~(cr : k) ~(resp : eresp Io.response_view option)
        ~(state : s) : s * ereq Io.request_view option =
      Result.fold (C.unmarshal_state state)
        ~error:(fun (_ : Err.t) -> (state, None)) (* corrupt store: no-op *)
        ~ok:(fun st ->
          let st', req = V.reconcile_core ~cr ~resp:(to_void_resp resp) ~state:st in
          (C.marshal_state st', of_void_req req))

    let reconcile_done (state : s) : bool =
      Result.fold (C.unmarshal_state state) ~error:(fun _ -> false)
        ~ok:V.reconcile_done
    let reconcile_error (state : s) : bool =
      Result.fold (C.unmarshal_state state) ~error:(fun _ -> false)
        ~ok:V.reconcile_error
  end

  let id = C.id
  let marshal_state (s : R.s) : Value.t = s  (* R.s = Value.t: identity *)
  let unmarshal_cr = C.unmarshal_cr
end
```
Note `| Some (Io.External_request _) -> .` is a refutation clause valid because
`Io.void` is empty; it keeps the match exhaustive with no wildcard and no bogus
value. `Result.fold` is stdlib (`~ok ~error`).

**Faithfulness note (state round-trip).** `unmarshal_state` must be the exact
inverse of `marshal_state` on every value `marshal_state` can produce, because
the driver stores only what `marshal_state` emitted. The `Error` no-op branches
are unreachable in a well-formed run; a corrupt store degrades to a stuck (never
done, never error) reconcile rather than an exception. `t_vreplica_set_pack`
pins the round-trip with confirm-by-mutation.

---

## 5. `vreplica_set` (lib/controllers/vreplica_set.ml + .mli) — the CR view

Port `trusted/spec_types.rs`. A `Resource_view.Make` instance, structured
exactly like `views/stateful_set.ml`.

Types:
```ocaml
type vrs_spec = {
  replicas : int option;
  selector : Label_selector.t;             (* NOT optional, per Anvil *)
  template : Pod_template_spec.t option;
}
type vrs_status = { replicas : int }        (* NOT optional; default replicas = 0 *)
type t = {
  metadata : Object_meta.t;
  spec : vrs_spec;                          (* NOT optional (Anvil field is bare) *)
  status : vrs_status option;
}
type spec = vrs_spec
type status = vrs_status option
```
Note the shape difference vs stateful_set: here `spec` is **not** an option
(Anvil `VReplicaSetView.spec : VReplicaSetSpecView`), and `status` is
`Option<VReplicaSetStatusView>`. `vrs_spec.selector` is a bare
`LabelSelectorView` (not option). `RESOURCE.spec = vrs_spec`,
`RESOURCE.status = vrs_status option`.

`kind = Common.Custom_resource "vreplicaset"`. Expose `let kind_name = "vreplicaset"`.

`default ()`: `{ metadata = Object_meta.default ();
  spec = { replicas = None; selector = Label_selector.default (); template = None };
  status = None }`.

`state_validation (s : t) : bool` (port `_state_validation`, spec_types.rs:57):
```
&& (s.spec.replicas is None || s.spec.replicas->0 >= 0)
&& s.spec.selector.match_labels is Some
&& Smap.cardinal (s.spec.selector.match_labels->0) > 0
&& s.spec.template is Some
&& s.spec.template->0.metadata is Some
&& s.spec.template->0.spec is Some
&& s.spec.template->0.metadata->0.labels is Some
&& Label_selector.matches s.spec.selector (s.spec.template->0.metadata->0.labels->0)
```
Use `Option.fold`/`Option.value`, not `match`, for each option test. `is Some`
= `Option.is_some`; `->0 >= 0` guarded by fold.

`transition_validation (_ : t) ~old:(_ : t) : bool = true` (Anvil
`_transition_validation` is `true`).

Builders (port `with_*`): `with_metadata`, `with_spec`, `with_status`
(status wraps `Some`), and on `vrs_spec`: `spec_with_replicas`,
`spec_without_replicas`, `spec_with_selector`, `spec_with_template`. On
`vrs_status`: `status_with_replicas`, `status_default () = { replicas = 0 }`.

`controller_owner_ref (s : t) : Owner_reference.t option` (port
`controller_owner_ref`, spec_types.rs:21 — **honest**: Anvil unwraps
`metadata.name->0` / `metadata.uid->0` under well-formedness; we return `None`
when either is absent):
```ocaml
let controller_owner_ref (s : t) : Owner_reference.t option =
  Option.bind s.metadata.name (fun name ->
    Option.map (fun uid : Owner_reference.t ->
      { block_owner_deletion = Some true; controller = Some true;
        kind; name; uid }) s.metadata.uid)
```

Marshalling (`marshal_spec`/`unmarshal_spec`/`marshal_status`/`unmarshal_status`)
via `Json` + `Value`, mirroring stateful_set's `ss_spec_*_json` / `unmarshal_spec`
(`Null` <-> `None`; `Assoc` decodes; other JSON shapes -> `Decode_error`). JSON
keys: `replicas`, `selector`, `template` for spec; `replicas` for status (status
is a bare object, not an option-map — `vrs_status = { replicas : int }`, a
required int). `recombine ~metadata ~spec ~status = { metadata; spec; status }`.
`spec ()`/`status ()`/`metadata ()` projections. Add `equal`.

**`marshal_spec` totality:** `selector` is required (bare), so encode it always
(`Some (Label_selector.to_json o.selector)`); `replicas`/`template` optional
(dropped when `None`). `unmarshal_spec` on `` `Assoc `` reads `replicas`
(opt int), `selector` (required, `Json.get ... Label_selector.of_json`),
`template` (opt, `Pod_template_spec.of_json`). Since `RESOURCE.spec = vrs_spec`
(not an option), `unmarshal_spec (Value)` on `` `Null `` is a `Decode_error`
(a VReplicaSet always has a spec), unlike stateful_set whose spec is optional.

Finally:
```ocaml
include (Resource_view.Make (R) :
  Resource_view.RESOURCE_VIEW with type t := t and type spec := spec
   and type status := status)
```
This yields `marshal : t -> Dynamic_object.t`, `unmarshal`, `object_ref`.

---

## 6. `vreplica_set_reconciler` (lib/controllers/vreplica_set_reconciler.ml + .mli)

The typed RECONCILER. Ports `model/reconciler.rs` faithfully; the only deviations
are the honest replacements for Anvil's proof-discharged `.unwrap()`/`->0`, each
routed to `error_state` (the reconciler is total and is only ever invoked on a
well-formed CR, so on well-formed input **no** honest-error branch that Anvil
would not also reach is taken — see faithfulness notes).

### Step enum (port step.rs, view form only)
```ocaml
type step =
  | Init
  | After_list_pods
  | After_create_pod of int      (* Anvil nat; always >= 0 by construction *)
  | After_delete_pod of int
  | After_update_vrs_status
  | Done
  | Error
```
Provide `step_equal` and JSON codec (used by the pack's state codec, §7).

### Reconcile state
```ocaml
type s = { reconcile_step : step; filtered_pods : Pod.t list option }
```
(Port `VReplicaSetReconcileState`; `filtered_pods : Option<Seq<PodView>>`.)

### RECONCILER members
`type k = Vreplica_set.t`, `type ereq = Io.void`, `type eresp = Io.void`.

`reconcile_init_state () = { reconcile_step = Init; filtered_pods = None }`.
`reconcile_done s = (match s.reconcile_step with Done -> true | <other 6> -> false)`.
`reconcile_error s = (match s.reconcile_step with Error -> true | <other 6> -> false)`.
`error_state s = { s with reconcile_step = Error }`.

### `reconcile_core ~cr:(vrs) ~resp ~state`

Match on `state.reconcile_step` (all 7 arms explicit). Namespace/name/uid/template
unwraps are honest (route to `(error_state state, None)`). Ported logic:

- **`Init`**: if `vrs.metadata.deletion_timestamp is Some` ->
  `({state with reconcile_step = Done}, None)`. Else needs namespace:
  `Option.fold vrs.metadata.namespace ~none:(error_state state, None)
   ~some:(fun namespace -> let req = Io.K_request (Api_method.List_request
   {kind = Pod.kind; namespace}) in ({state with reconcile_step =
   After_list_pods}, Some req))`.

- **`After_list_pods`**: `match io_resp.k_list_resp resp with`
  - `Some (Ok objs) ->` proceed
  - `Some (Error _) | None -> (error_state state, None)`
  Proceed:
  ```
  match objects_to_pods objs with
  | None -> (error_state state, None)
  | Some pods ->
    (* need namespace + controller_owner_ref both present *)
    match vrs.metadata.namespace, Vreplica_set.controller_owner_ref vrs with
    | Some namespace, Some oref ->
      let filtered = filter_pods pods vrs oref in
      let replicas = Option.value ~default:1 vrs.spec.replicas in
      if replicas < 0 then (error_state state, None)
      else
        let desired = replicas and n = List.length filtered in
        if n = desired then update_vrs_replicas state vrs
        else if n < desired then
          (* scale up: create one pod, remember (diff-1) still to make *)
          let diff = desired - n in
          (match make_pod vrs with
           | None -> (error_state state, None)
           | Some pod ->
             let req = Io.K_request (Api_method.Create_request
               {namespace; obj = Pod.marshal pod}) in
             ({state with reconcile_step = After_create_pod (diff - 1)}, Some req))
        else
          (* scale down: delete filtered[diff-1] *)
          let diff = n - desired in
          (match List.nth_opt filtered (diff - 1) with
           | None -> (error_state state, None)
           | Some victim ->
             (match victim.Pod.metadata.name with
              | None -> (error_state state, None)
              | Some name ->
                let req = Io.K_request (Api_method.Get_then_delete_request
                  {key = {Common.kind = Pod.kind; name; namespace}; owner_ref = oref}) in
                ({reconcile_step = After_delete_pod (diff - 1);
                  filtered_pods = Some filtered}, Some req)))
    | None, _ | _, None -> (error_state state, None)
  ```
  (`n < desired` and `n > desired` both need namespace+oref; the `n = desired`
  update path uses `update_vrs_replicas`, which needs name/namespace too and
  guards them itself.)

- **`After_create_pod diff`**: `match io_resp.k_create_resp resp with`
  - `Some (Ok _) ->` if `diff = 0` then `update_vrs_replicas state vrs`
    else create another: needs namespace + make_pod (as above), next step
    `After_create_pod (diff - 1)`.
  - `Some (Error _) | None -> (error_state state, None)`.

- **`After_delete_pod diff`**: `match io_resp.k_get_then_delete_resp resp with`
  - `Some (Ok ()) ->` if `diff = 0` then `update_vrs_replicas state vrs`
    else: needs `state.filtered_pods` (`None -> error`); let `fp` be the list;
    if `diff > List.length fp` -> error; `match List.nth_opt fp (diff-1)` /
    its `.metadata.name` (`None -> error`); else emit `Get_then_delete_request`
    (namespace from `vrs.metadata.namespace`, honest-guard; `owner_ref =
    controller_owner_ref vrs`, honest-guard), next step `After_delete_pod (diff-1)`.
  - `Some (Error _) | None -> (error_state state, None)`.

- **`After_update_vrs_status`**: `match io_resp.k_get_then_update_status_resp resp with`
  - `Some (Ok _) -> ({state with reconcile_step = Done}, None)`
  - `Some (Error _) | None -> (error_state state, None)`.

- **`Done` | `Error`**: `(state, None)` (Anvil's `_ => (state, None)`; we
  enumerate both).

### Helpers (ported spec fns)
```
objects_to_pods (objs : Dynamic_object.t list) : Pod.t list option
  = if List.exists (fun o -> Result.is_error (Pod.unmarshal o)) objs then None
    else Some (List.filter_map (fun o -> Result.to_option (Pod.unmarshal o)) objs)

pod_matches (vrs) (oref) (pod : Pod.t) : bool =    (* Anvil pod_filter conjuncts *)
     Object_meta.owner_references_contains pod.metadata oref
  && Label_selector.matches vrs.spec.selector
       (Option.value ~default:Smap.empty pod.metadata.labels)
  && Option.is_none pod.metadata.deletion_timestamp
  && (match pod.metadata.name with
      | None -> false
      | Some nm -> has_vrs_prefix nm)

filter_pods pods vrs oref = List.filter (pod_matches vrs oref) pods

has_vrs_prefix (name : string) : bool =
  String.starts_with ~prefix:(Vreplica_set.kind_name ^ "-") name
  (* Anvil: exists suffix. name = "vreplicaset" + "-" + suffix.  A prefix
     check is the exact computational realisation of that existential. *)

pod_generate_name vrs : string option =
  Option.map (fun nm -> Vreplica_set.kind_name ^ "-" ^ nm ^ "-") vrs.metadata.name

make_pod (vrs) : Pod.t option =                     (* honest: template/metadata *)
  Option.bind vrs.spec.template (fun (tmpl : Pod_template_spec.t) ->
    Option.bind tmpl.metadata (fun (tm : Object_meta.t) ->
      Option.bind (pod_generate_name vrs) (fun gname ->
        Option.map (fun oref ->
          let md = { (Object_meta.default ()) with
                     labels = tm.labels; annotations = tm.annotations;
                     finalizers = tm.finalizers }
                   |> Object_meta.with_generate_name gname
                   |> Object_meta.with_owner_references [ oref ] in
          Pod.make ~metadata:md ~spec:tmpl.spec ~status:None)
          (Vreplica_set.controller_owner_ref vrs))))
  (* Anvil make_pod copies template.spec into pod.spec directly (an option),
     sets labels/annotations/finalizers from the template metadata, then
     with_generate_name + with_owner_references. make_owner_references vrs =
     [ controller_owner_ref vrs ]. *)

update_vrs_replicas (state) (vrs) : s * Io.void Io.request_view option =
  (* Anvil update_vrs_replicas: needs exactly one controller owner_ref. *)
  match vrs.metadata.owner_references with
  | None -> (error_state state, None)
  | Some orefs ->
    let ctrls = List.filter Owner_reference.is_controller orefs in
    (match ctrls with
     | [ the_owner ] ->
       (match vrs.metadata.name, vrs.metadata.namespace with
        | Some name, Some namespace ->
          let vrs' = { vrs with status =
            Some { Vreplica_set.replicas = Option.value ~default:1 vrs.spec.replicas } } in
          let req = Io.K_request (Api_method.Get_then_update_status_request
            { namespace; name; owner_ref = the_owner; obj = Vreplica_set.marshal vrs' }) in
          ({ state with reconcile_step = After_update_vrs_status }, Some req)
        | None, _ | _, None -> (error_state state, None))
     | [] | _ :: _ :: _ -> (error_state state, None))
  (* Anvil checks `.filter(controller_owner_filter()).len() == 1` and takes [0].
     `[ the_owner ]` matches exactly-one; `[]` / two-or-more -> error. *)
```
`.mli` exposes: the `step` type + `s` type (or keep `s` abstract with accessors
for tests? — expose the record so tests can inspect `reconcile_step`), the
RECONCILER members, and `error_state`. It must satisfy
`Reconciler.RECONCILER with type k = Vreplica_set.t and type s = s and
type ereq = Io.void and type eresp = Io.void`. Provide a `module Reconciler :
Reconciler.RECONCILER with ...` OR make the file itself the reconciler by
including the members; simplest: define a submodule
`module R : Reconciler.RECONCILER with type k = Vreplica_set.t and type s = s
 and type ereq = Io.void and type eresp = Io.void` so the pack can `Void_erase`
it. Keep the helpers/types top-level for tests, and `module R` re-exports the
four members.

---

## 7. `vreplica_set_pack` (lib/controllers/vreplica_set_pack.ml + .mli)

The reconcile-state codec + the driver-ready CONTROLLER pack.

State codec (`s <-> Value.t`), via JSON:
- `step` -> `{ "step": <tag>, "diff"?: int }` where tag in
  `init|afterListPods|afterCreatePod|afterDeletePod|afterUpdateVrsStatus|done|error`,
  and `diff` present only for the two `After_*_pod` steps.
- `filtered_pods : Pod.t list option` -> optional JSON list of
  `Pod.marshal p |> Dynamic_object.to_json`; decode via `Dynamic_object.of_json`
  then `Pod.unmarshal` (`Res`, first error wins).
- `marshal_state s = Value.of_json (Json.obj_opt [ ("step", Some (step_to_json ...));
  ("filteredPods", Json.opt (Json.list ...) s.filtered_pods) ])`.
- `unmarshal_state : Value.t -> s Res.t` inverts it (`Json.get` step,
  `Json.opt_mem` filteredPods).

`unmarshal_cr (o : Dynamic_object.t) : Vreplica_set.t Res.t = Vreplica_set.unmarshal o`.
`id = 0` (single controller-under-test; the GC does not use the reconcile map).

Then:
```ocaml
module Codec : Erase.STATE_CODEC
  with type s = Vreplica_set_reconciler.s and type k = Vreplica_set.t = struct
  type s = Vreplica_set_reconciler.s
  type k = Vreplica_set.t
  let id = 0
  let marshal_state = ...
  let unmarshal_state = ...
  let unmarshal_cr = Vreplica_set.unmarshal
end

module Controller = Erase.Void_erase (Vreplica_set_reconciler.R) (Codec)
(* : Controller_pack.CONTROLLER with R.s=R.ereq=R.eresp=Value.t, R.k=Vreplica_set.t *)

let packed : Controller_pack.packed = (module Controller)
let kind = Vreplica_set.kind
```
`.mli` exposes `Codec.marshal_state/unmarshal_state`, `module Controller :
Controller_pack.CONTROLLER with type R.s = Value.t and type R.ereq = Value.t
and type R.eresp = Value.t and type R.k = Vreplica_set.t`, `val packed`,
`val kind`.

---

## 8. Tests (bypass `dunecho test`; run `_build/default/test/*.exe` directly)

### t_vreplica_set.ml
- `state_validation`: a fully-populated well-formed VReplicaSet passes; each
  single omission (no selector match_labels / empty match_labels / no template /
  no template.metadata / no template.spec / no template labels / selector not
  matching template labels / negative replicas) fails. (This is the
  confirm-by-mutation surface for validation: each `&&` conjunct pinned.)
- `marshal`/`unmarshal` round-trip: `Vreplica_set.unmarshal (Vreplica_set.marshal
  v) = Ok v'` with `Vreplica_set.equal v v'` for a populated spec + status.
  A wrong-kind DynamicObject -> `Kind_mismatch`.

### t_vreplica_set_reconciler.ml (the load-bearing suite)
Drive each transition of the pure typed core with hand-built inputs:
1. `Init` + `deletion_timestamp = Some` -> `Done`, no request.
2. `Init` + no deletion -> `After_list_pods` + a `List_request { kind = Pod }`.
3. `After_list_pods` + a `List_response Ok []` with `desired = 2` -> a
   `Create_request`, step `After_create_pod 1`. (scale-up)
4. `After_list_pods` + list of exactly `desired` matching pods -> update path:
   `After_update_vrs_status` + `Get_then_update_status_request` (requires vrs
   to carry exactly one controller owner_ref).
5. `After_list_pods` + more matching pods than `desired` -> `Get_then_delete_request`,
   step `After_delete_pod (diff-1)`, `filtered_pods` populated. (scale-down)
6. `After_create_pod 0` + `Create_response Ok` -> update path.
7. `After_create_pod (n>0)` + `Create_response Ok` -> another `Create_request`,
   `After_create_pod (n-1)`.
8. `After_delete_pod 0` + `Get_then_delete_response Ok ()` -> update path.
9. `After_update_vrs_status` + `Get_then_update_status_response Ok` -> `Done`.
10. Error routing: a wrong-kind or `Error` response at any waiting step -> `Error`.
11. `objects_to_pods`: a non-pod DynamicObject in the list -> `error_state`.
12. `filter_pods`/`pod_matches`: a pod without the vrs owner_ref, or without the
    `vreplicaset-` name prefix, or with a `deletion_timestamp`, is excluded.

Confirm-by-mutation (per [[feedback-confirm-tests-by-mutation]]): after green,
neuter one guard at a time (e.g. flip `n < desired` to `n <= desired`; drop the
`diff = 0` check; make `has_vrs_prefix` always true) and confirm the paired
assertion flips to failing, then restore. Record which test each mutation flips.

### t_vreplica_set_driver.ml (end-to-end, mirrors t_reconcile_driver.ml)
Install `Vreplica_set_pack.Controller` via `Controller.model_of_controller
~kind:Vreplica_set.kind (module Vreplica_set_pack.Controller)`. Schedule a
well-formed VReplicaSet cr (desired replicas e.g. 1, no existing pods). Drive:
`run_scheduled_reconcile` -> `continue_reconcile` (emits `List_request`) ->
feed `List_response Ok []` (via `Message.form_list_resp_msg`) ->
`continue_reconcile` (emits `Create_request`) -> feed `Create_response Ok pod`
-> `continue_reconcile` (`diff=0` -> emits `Get_then_update_status_request`) ->
feed `Get_then_update_status_response Ok` -> `continue_reconcile` reaches `Done`
-> `end_reconcile` removes it. Assert `resp_msg_matches_req_msg` at each hop and
that the local state marshals/unmarshals across every step (this is the pack +
erase adapter's integration proof).

---

## 9. Faithfulness notes (the review's oracle)

1. **Honest unwrap routing.** Every Anvil `.unwrap()` / `->0` on
   `metadata.namespace`, `metadata.name`, `metadata.uid`, `spec.template`,
   `template.metadata`, and the `filtered_pods[i]` / `[0]` indexings is
   proof-discharged by Anvil under the CR's well-formedness invariant. We have no
   prover, so each becomes an explicit `None`/out-of-bounds guard routed to
   `error_state` (or `(state, None)` for the corrupt-store codec branch). **On a
   well-formed CR every such field is `Some` and every index is in range, so the
   ported core takes exactly Anvil's branches; the honest-error branches are only
   reachable on inputs Anvil's invariant excludes.** This is the identical
   pattern P1 used for `object_ref` (`Missing_field`).
2. **`has_vrs_prefix`.** Anvil's `exists suffix. name = kind + "-" + suffix` is
   realised as `String.starts_with ~prefix:(kind ^ "-")`. Exact: a suffix exists
   iff the string has the prefix.
3. **Void erasure.** The typed core has `ereq = eresp = void`; the driver needs
   `Value`. `Void_erase` marshals state at the boundary and erases void external
   I/O: `K_*` passes through, an (impossible) external response maps to
   no-response, an (unconstructible) external request is refuted. No external
   message is ever delivered to a void reconciler in a well-formed cluster, so
   this is observationally identity on the reachable behaviours.
4. **`replicas` default + non-negative recheck.** `unwrap_or(1)` ->
   `Option.value ~default:1`; the `replicas < 0 -> error` recheck is kept even
   though `state_validation` implies it (Anvil keeps it; we keep it).
5. **`objects_to_pods` double unmarshal.** Anvil filters-then-maps, calling
   `unmarshal` twice; the port's `List.exists ... ; List.filter_map ...` mirrors
   that (same result, all-Ok case). No information is dropped because the
   `exists` gate guarantees the `filter_map` keeps every element.

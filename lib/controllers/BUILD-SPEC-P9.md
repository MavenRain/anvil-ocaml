# BUILD-SPEC-P9 — VDeployment controller (the "controller of controllers")

Normative contract for Phase 9 of the anvil-ocaml port. Hand-authored by the lead
(the crux `.mli` + this spec are frozen); the build agents write the `.ml` bodies +
tests to satisfy the `.mli` and the algorithms below EXACTLY.

Upstream source of truth (raw, in this session's scratchpad; also fetchable from
`anvil-verifier/anvil` `src/controllers/vdeployment_controller/`):
- `model/reconciler.rs`  — the 8-step reconcile_core to port
- `trusted/spec_types.rs` — VDeploymentView / VDeploymentSpecView / DeploymentStrategyView / RollingUpdateDeploymentView
- `trusted/step.rs`       — the step enum
- `trusted/liveness_theorem.rs` — `valid_owned_vrs`, `match_template_without_hash` (ported into the reconciler)

## §0. Honest scope (state this in the module docs, P7 §0 voice)

P9 ports the Anvil **VDeployment** controller: a custom-resource controller that
manages **VReplicaSet** children exactly as the P3 VReplicaSet controller manages
Pods. It closes the compositional "controller of controllers" story.

- **What is delivered (verifiable in the no-cluster sandbox, no new deps):**
  the `V_deployment` CR view, the typed `V_deployment_reconciler.reconcile_core`
  (a faithful port of the rolling-update state machine), the `V_deployment_pack`
  erasure, the `Multi_controller` two-controller executable driver, `Scenario`
  additions, and four test suites incl. confirm-by-mutation.
- **THE P9 PAYOFF — operational liveness witness (NOT a bounded proof, NOT Anvil's
  Verus theorem):** running the VDeployment + VReplicaSet controllers **together**
  over one in-memory store actually converges: VDeployment creates a VReplicaSet and
  scales it +1 per reconcile (readiness-gated), the VReplicaSet controller creates a
  pod per replica and writes back `status.replicas`, and the two INTERLEAVE to a joint
  fixpoint (exactly one VReplicaSet at `replicas=desired`, `desired` pods, no old VRS,
  both reconcilers idempotent). Neither controller converges alone — the rolling-update
  `mismatch_replicas` gate only scales once `status.replicas` reflects readiness, which
  is the OTHER controller's output. This is the executable convergence the P5 bounded
  checker and P6 liveness skeleton could only reach vacuously under a finite ceiling.
- **BMC (P5) is explicitly OUT of P9 scope.** A bounded model check over TWO
  structurally different controllers + the rolling loop is a state-explosion project of
  its own. Document the gap; do not overclaim. Assurance for P9 = reconcile_core unit
  tests + the operational two-controller convergence witness + confirm-by-mutation.

## §1. File manifest (additive; P0–P8 untouched)

NEW:
- `lib/k8s_objects/deployment_strategy.ml` + `.mli` — plain field view (like Label_selector)
- `lib/controllers/v_deployment.ml` + `.mli` — the CR view
- `lib/controllers/v_deployment_reconciler.ml` + `.mli` — the reconcile_core
- `lib/controllers/v_deployment_pack.ml` + `.mli` — the erased pack
- `lib/exec_shim/multi_controller.ml` + `.mli` — the two-controller driver
- `test/t_v_deployment.ml`            — view: state_validation + marshal/unmarshal round-trip + wrong-kind
- `test/t_v_deployment_reconciler.ml` — reconcile_core: one test per transition + guard routing
- `test/t_p9_two_controller.ml`       — the exec convergence witness (VDeployment→VReplicaSet→Pods)
- `test/t_p9_mutation.ml`             — confirm-by-mutation shadow-analogues

EDITED (surgical):
- `lib/reconciler/io_resp.mli` + `.ml` — ADD `k_get_then_update_resp` (non-status)
- `lib/assurance/scenario.ml` + `.mli` — ADD `vd`, `vd_ref`, a multi-kind
  `installed_types`, and a `vd_cluster` / `vd_and_vrs_installed` helper (see §2.6)
- `lib/k8s_objects/dune` — add `deployment_strategy` if modules are listed explicitly
- `lib/exec_shim/dune` — add `multi_controller` if modules are listed explicitly
- `test/dune` — register the 4 new `t_` basenames in `(names ...)`

## §2. Exact algorithms

### §2.1 `deployment_strategy` (plain field view; mirror `label_selector.ml`)

```
type strategy_type = Recreate | Rolling_update           (* finite sum; exhaustive of_json *)
type rolling_update = { max_surge : int option; max_unavailable : int option }
type t = { type_ : strategy_type option; rolling_update : rolling_update option }
val default : unit -> t                                   (* { type_ = None; rolling_update = None } *)
val to_json : t -> Yojson.Safe.t
val of_json : Yojson.Safe.t -> t Res.t
val equal : t -> t -> bool
```
- `type_` JSON: "Recreate" | "RollingUpdate". of_json string -> exhaustive match on the
  two literals, any other string -> `Err.Decode_error { typ = "deployment_strategy.type"; detail = tag }`.
  NO wildcard in the `strategy_type` match; the string dispatch's fallthrough is the error arm.
- rolling_update JSON: `{ "maxSurge"?; "maxUnavailable"? }` via Json.obj_opt + Json.opt/opt_mem Json.to_int.
- `t` JSON: `{ "type"?; "rollingUpdate"? }`.

### §2.2 `v_deployment` (CR view; mirror `vreplica_set.ml` + `config_map.ml` unit-status)

Types (NOTE: `template` is BARE `Pod_template_spec.t`, not option — differs from VRS):
```
type vd_spec = {
  replicas : int option;
  selector : Label_selector.t;                 (* bare *)
  template : Pod_template_spec.t;              (* BARE, required *)
  min_ready_seconds : int option;
  progress_deadline_seconds : int option;
  strategy : Deployment_strategy.t option;
  revision_history_limit : int option;
  paused : bool option;
}
type status = unit                             (* EmptyStatus; copy config_map.ml verbatim *)
type t = { metadata : Object_meta.t; spec : vd_spec; status : status }
type spec = vd_spec
val kind_name : string                         (* "vdeployment" *)
val vd_spec_default : unit -> vd_spec
val vd_spec_equal : vd_spec -> vd_spec -> bool
include Resource_view.RESOURCE_VIEW with type t := t and type spec := spec and type status := status
val controller_owner_ref : t -> Owner_reference.t option
val make : metadata:Object_meta.t -> spec:spec -> status:status -> t
val equal : t -> t -> bool
```
- Spec codec (`Json.obj_opt` + per-field option-ness): replicas/min_ready_seconds/
  progress_deadline_seconds/revision_history_limit via `Json.opt Json.int_` /
  `Json.opt_mem .. Json.to_int`; paused via `Json.opt Json.bool_` / `Json.opt_mem .. Json.to_bool`
  (VERIFY `Json.bool_`/`Json.to_bool` names against `json.mli`; if absent, author them or
  use the existing bool helper); selector bare -> `("selector", Some (Label_selector.to_json ..))`
  + `Json.get j "selector" Label_selector.of_json`; template bare -> `("template", Some (Pod_template_spec.to_json ..))`
  + `Json.get j "template" Pod_template_spec.of_json`; strategy via `Json.opt Deployment_strategy.to_json`
  / `Json.opt_mem .. Deployment_strategy.of_json`. JSON keys: replicas, selector, template,
  minReadySeconds, progressDeadlineSeconds, strategy, revisionHistoryLimit, paused.
- Status codec: COPY `config_map.ml` verbatim (`marshal_status _ = Value.of_json \`Null`;
  unmarshal `\`Null -> Res.ok ()`, all other 7 poly-variants -> `Err.Decode_error { typ="v_deployment.status"; detail="expected null" }`).
  `status (_:t) = ()`; `recombine ~metadata ~spec ~status:_ = { metadata; spec; status = () }`.
- `unmarshal_spec`: `\`Assoc _ as j -> vd_spec_of_json j`, all other 7 poly-variants ->
  `Err.Decode_error { typ="v_deployment.spec"; detail="expected object" }`.
- `state_validation` (port `_state_validation`; template is bare so index directly):
```
Option.fold ~none:true ~some:(fun r -> r >= 0) s.spec.replicas
&& min_ready/progress clause (see below)
&& Option.is_some s.spec.selector.match_labels
&& Option.fold ~none:false ~some:(fun ml -> Smap.cardinal ml > 0) s.spec.selector.match_labels
&& Option.is_some s.spec.template.metadata
&& Option.is_some s.spec.template.spec
&& Option.fold ~none:false ~some:(fun (tm:Object_meta.t) ->
     Option.is_some tm.labels
     && Option.fold ~none:false ~some:(fun labels -> Label_selector.matches s.spec.selector labels) tm.labels)
     s.spec.template.metadata
&& strategy clause (see below)
```
  min_ready/progress clause (port the 4-way; use combinators — Option.fold nested, NOT a
  two-arm match on either option; the (Some,Some)/(Some,None)/(None,Some)/(None,None) split
  is expressible as nested Option.fold):
    (min Some, deadline Some) => min < deadline && min >= 0
    (min Some, None)          => min < 600 && min >= 0
    (None, deadline Some)     => deadline > 0
    (None, None)              => true
  strategy clause: `Option.fold ~none:true ~some:(fun (st:Deployment_strategy.t) -> ...) s.spec.strategy`
  where the body ports: `st.type_ is Some => ( (type=Recreate && rolling_update is None)
  || (type=RollingUpdate && (rolling_update is Some => maxSurge/maxUnavailable constraint)) )`.
  The `type_` inner branch on `Recreate|Rolling_update` MUST be a full 2-arm match (both
  named), NOT a wildcard. maxSurge/maxUnavailable constraint = the 4-way from spec_types.rs
  (both Some => s>=0 && u>=0 && !(s=0&&u=0); Some/None => s>=0; None/Some => u>=0; None/None => true).
- `controller_owner_ref`: copy `vreplica_set.controller_owner_ref` verbatim (Option.bind name
  then Option.map uid; inline `Owner_reference.t` literal with this module's `kind`).
- `transition_validation _ ~old:_ = true`.

### §2.3 `v_deployment_reconciler` (port `model/reconciler.rs`)

Step enum (snake_case; ALL nullary):
```
type step = Init | After_list_vrs | After_create_new_vrs | After_scale_new_vrs
          | After_ensure_new_vrs | After_scale_down_old_vrs | Done | Error
type s = { reconcile_step : step; new_vrs : Vreplica_set.t option;
           old_vrs_list : Vreplica_set.t list; old_vrs_index : int }
let reconcile_init_state () = { reconcile_step=Init; new_vrs=None; old_vrs_list=[]; old_vrs_index=0 }
```
- `step_equal`, `reconcile_done`, `reconcile_error`, `step_to_json`, `step_of_json`: mirror the
  VRS template; every arm nullary (NO `diff` field). step tags: "init", "afterListVrs",
  "afterCreateNewVrs", "afterScaleNewVrs", "afterEnsureNewVrs", "afterScaleDownOldVrs",
  "done", "error". decode-error `typ="v_deployment_reconciler.step"`. Exhaustive residual
  tuple pattern in step_equal; full enumeration in reconcile_done/error.
- Re-author the LOCAL `with_ok_resp` helper verbatim from `vreplica_set_reconciler.ml`.
- Helpers `replicas_or1 : int option -> int = Option.value ~default:1`.
- `error_state s = { s with reconcile_step = Error }`; `done_state s = { s with reconcile_step = Done }`;
  `new_vrs_ensured_state s = { s with reconcile_step = After_ensure_new_vrs }`.

**reconcile_core** `~(cr:V_deployment.t) ~(resp:Io.void Io.response_view option) ~(state:s)`:
guard `namespace` = `Object_meta.namespace (V_deployment.metadata cr)` via Option.fold
(none -> `(error_state state, None)`). Match `state.reconcile_step` — ALL 8 arms explicit:

- **Init**: `req = Io.K_request (List_request { kind = Vreplica_set.kind; namespace })`;
  `({ reconcile_step=After_list_vrs; new_vrs=None; old_vrs_list=[]; old_vrs_index=0 }, Some req)`.
- **After_list_vrs**: `with_ok_resp Io_resp.k_list_resp state resp ~ok:(fun objs ->`
    `objects_to_vrs_list objs` (Option.fold none -> error): unmarshal every obj via
    `Vreplica_set.unmarshal`; if ANY is Error -> None. On Some vrs_all:
    `filtered = List.filter (fun v -> valid_owned_vrs v cr) vrs_all`;
    `(new_vrs, old_vrs_list) = filter_old_and_new_vrs cr filtered`;
    `base = { reconcile_step=After_ensure_new_vrs; new_vrs; old_vrs_list; old_vrs_index=List.length old_vrs_list }`;
    Option.fold new_vrs ~none:(create_new_vrs base cr)
      ~some:(fun nv -> if mismatch_replicas cr nv then scale_new_vrs base cr else (base, None)))`.
- **After_create_new_vrs**: `with_ok_resp Io_resp.k_create_resp state resp ~ok:(fun new_obj ->`
    `Res.fold (Vreplica_set.unmarshal new_obj) ~error:(fun _ -> (error_state state, None))`
      `~ok:(fun vrs -> ({ state with reconcile_step=After_ensure_new_vrs; new_vrs=Some vrs }, None)))`
    (use Result.fold / Res combinator, NOT a two-arm match).
- **After_scale_new_vrs**: `with_ok_resp Io_resp.k_get_then_update_resp state resp
    ~ok:(fun (_:Dynamic_object.t) -> (new_vrs_ensured_state state, None))`.
- **After_ensure_new_vrs** (BARRIER, resp-free — do NOT consult resp):
    if `state.old_vrs_index = 0` -> `(done_state state, None)`
    else if `state.old_vrs_index > List.length state.old_vrs_list` -> `(error_state state, None)`
    else Option.fold (List.nth_opt state.old_vrs_list (state.old_vrs_index-1))
         ~none:(error_state state, None)
         ~some:(fun old -> if valid_owned_vrs old cr then scale_down_old_vrs state cr
                           else (error_state state, None)).
    (Use nth_opt + Option.fold; never List.nth which raises.)
- **After_scale_down_old_vrs**: `with_ok_resp Io_resp.k_get_then_update_resp state resp
    ~ok:(fun (_:Dynamic_object.t) ->` same 4-way body as After_ensure_new_vrs (index=0 -> done;
    index>len -> error; nth_opt guard + valid_owned_vrs -> scale_down_old_vrs else error))`.
- **Done** -> `(state, None)`;  **Error** -> `(state, None)`.

Helpers:
- `filter_old_and_new_vrs cr vrs_list`:
    `reusable_list = List.filter (match_template_without_hash (V_deployment.spec cr).template) vrs_list`;
    `nonempty v = Option.fold ~none:true ~some:(fun r -> r > 0) (Vreplica_set.spec v).replicas`;
    `reusable = match reusable_list with [] -> None | _ :: _ ->
        Option.fold (List.find_opt nonempty reusable_list)
          ~none:(Some (List.hd reusable_list)) ~some:(fun v -> Some v)`;
    (the `[] | _::_` split is an exhaustive list match, allowed; List.hd guarded by the `_::_`.)
    `old_vrs_list = List.filter (fun v ->
        (Option.fold reusable ~none:true ~some:(fun r -> not (uid_eq v r)))
        && Option.fold (Vreplica_set.spec v).replicas ~none:true ~some:(fun r -> r > 0)) vrs_list`
    where `uid_eq a b = Option.equal Common.Uid.equal (Vreplica_set.metadata a).uid (Vreplica_set.metadata b).uid`.
    return `(reusable, old_vrs_list)`. PRESERVE input order (List.filter/find_opt do).
- `make_replica_set cr` (port `make_replica_set`): `hash = string_of_int (rv of cr)`
    (`Common.Resource_version.to_int`/`.to_string` of `(V_deployment.metadata cr).resource_version`,
    Option.fold none -> "0" or guard; upstream unwraps — guard to a stable "0" if absent and
    document); `match_labels = Smap.add "pod-template-hash" hash (template labels)`;
    build a `Vreplica_set.t` with metadata `{ default with generate_name = Some (name ^ "-" ^ hash);
    namespace; labels = vd labels; owner_references = Some [controller_owner_ref] }` then
    `Object_meta.add_label "pod-template-hash" hash`; spec `{ replicas = Some (if replicas_or1 (vd replicas) > 0 then 1 else 0);
    selector = { match_labels = Some match_labels }; template = Some (template_with_hash cr hash) }`.
- `template_with_hash cr hash`: insert "pod-template-hash"->hash into template.metadata.labels.
- `create_new_vrs state cr`: `nv = make_replica_set cr`;
    `req = Io.K_request (Create_request { namespace; obj = Vreplica_set.marshal nv })`;
    `({ state with reconcile_step = After_create_new_vrs }, Some req)`.
- `scale_new_vrs state cr`: `nv = Option.get state.new_vrs` (guard: reached only when Some);
    `cur = replicas_or1 (Vreplica_set.spec nv).replicas`; `updated = if replicas_or1 (vd replicas) > cur then cur+1 else cur-1`;
    `nv' = nv with spec.replicas = Some updated`;
    `req = Get_then_update_request { namespace; name = nv'.metadata.name (guarded); owner_ref = V_deployment.controller_owner_ref cr (guarded); obj = Vreplica_set.marshal nv' }`;
    `({ state with reconcile_step = After_scale_new_vrs; new_vrs = Some nv' }, Some req)`.
    NB name/owner_ref are options — Option.fold to error_state if absent (never Option.get on external data).
- `scale_down_old_vrs state cr`: `idx = state.old_vrs_index - 1`; guard `List.nth_opt state.old_vrs_list idx`;
    `req = Get_then_update_request { namespace; name; owner_ref; obj = Vreplica_set.marshal (old with spec.replicas = Some 0) }`;
    `({ state with reconcile_step = After_scale_down_old_vrs; old_vrs_index = idx }, Some req)`.
- `mismatch_replicas cr vrs`:
    `( Option.equal Int.equal (Vreplica_set.spec vrs).replicas (Some 0)
       || Option.fold (Vreplica_set.status vrs) ~none:false
            ~some:(fun st -> Int.equal st.replicas (replicas_or1 (Vreplica_set.spec vrs).replicas)) )
     && not (Int.equal (replicas_or1 (Vreplica_set.spec vrs).replicas) (replicas_or1 (V_deployment.spec cr).replicas))`.
- `valid_owned_vrs vrs cr` (port `valid_owned_vrs`):
    name Some && namespace Some && namespace = vd.namespace && `Vreplica_set.state_validation vrs`
    && deletion_timestamp None && `Object_meta.owner_references_contains (Vreplica_set.metadata vrs) (V_deployment.controller_owner_ref cr guarded)`.
    (owner ref is an option -> Option.fold none:false.)
- `match_template_without_hash template vrs` (port): strip "pod-template-hash" from BOTH
    `template.metadata.labels` and `(Vreplica_set.spec vrs).template.metadata.labels`, then
    structural-equal the two `Pod_template_spec.t`. vrs template is option -> Option.fold none:false.
    Use `Smap.remove "pod-template-hash"`. Compare via `Pod_template_spec.equal` (author if absent).

**module R footer**: `module R : Reconciler.RECONCILER with type k = V_deployment.t and type s = s
and type ereq = Io.void and type eresp = Io.void = struct type nonrec s = s; type k = V_deployment.t;
type ereq = Io.void; type eresp = Io.void; let reconcile_init_state = ...; let reconcile_core = ...;
let reconcile_done = ...; let reconcile_error = ... end`.

### §2.4 `io_resp` edit — ADD `k_get_then_update_resp` (non-status)

`val k_get_then_update_resp : 'a Io.response_view option -> (Dynamic_object.t, Api_method.api_error) result option`.
Body: copy `k_get_then_update_status_resp` verbatim, match `Api_method.Get_then_update_response { res } -> Some res`,
move `Get_then_update_status_response` into the exhaustive None-list of the other 8 api_response
variants. Keep all 9 arms; NO wildcard.

### §2.5 `v_deployment_pack` (mirror `vreplica_set_pack.ml`) — CRITICAL: serialize FULL state

**The full reconcile state MUST round-trip through marshal_state/unmarshal_state** (Void_erase
calls them on EVERY transition; the exec path's `model.transition` unmarshals→reconcile_core→marshals).
The VRS pack serializes `filteredPods`; VD must serialize `newVrs` + `oldVrsList` + `oldVrsIndex`,
else the scale-down cursor resets each step and the loop breaks. (One scout agent wrongly said
`s` is not serialized — the verbatim pack read proves otherwise; the pack IS the serializer.)

```
let vrs_to_json v = Dynamic_object.to_json (Vreplica_set.marshal v)
let vrs_of_json j = Res.bind (Dynamic_object.of_json j) Vreplica_set.unmarshal
let marshal_state (st : s) : Value.t = Value.of_json (Json.obj_opt [
    ("step", Some (V_deployment_reconciler.step_to_json st.reconcile_step));
    ("newVrs", Json.opt vrs_to_json st.new_vrs);
    ("oldVrsList", Some (Json.list vrs_to_json st.old_vrs_list));
    ("oldVrsIndex", Some (Json.int_ st.old_vrs_index)); ])
let unmarshal_state v = match Value.json v with
  | `Assoc _ as j -> let open Res in
      let* reconcile_step = Json.get j "step" V_deployment_reconciler.step_of_json in
      let* new_vrs = Json.opt_mem j "newVrs" vrs_of_json in
      let* old_vrs_list = Json.opt_mem j "oldVrsList" (Json.to_list vrs_of_json)
                          |> Res.map (Option.value ~default:[]) in
      let* old_vrs_index = Json.opt_mem j "oldVrsIndex" Json.to_int
                           |> Res.map (Option.value ~default:0) in
      ok ({ reconcile_step; new_vrs; old_vrs_list; old_vrs_index } : s)
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error (Err.Decode_error { typ="v_deployment_pack.state"; detail="expected object" })
```
(Adjust `Json.opt_mem`/`Json.to_list` combinator shapes to the real json.mli; the invariant is:
`old_vrs_list` defaults `[]`, `old_vrs_index` defaults `0`, `new_vrs` optional.)
```
module Codec : Erase.STATE_CODEC with type s = V_deployment_reconciler.s and type k = V_deployment.t = struct
  type s = V_deployment_reconciler.s;  type k = V_deployment.t
  let id = 1                            (* <<< MUST differ from Vreplica_set_pack.Codec.id = 0 *)
  let marshal_state = marshal_state;  let unmarshal_state = unmarshal_state
  let unmarshal_cr = V_deployment.unmarshal
end
module Controller = Erase.Void_erase (V_deployment_reconciler.R) (Codec)
let packed : Controller_pack.packed = (module Controller)
let kind = V_deployment.kind
```
`.mli` mirrors `vreplica_set_pack.mli` (marshal_state/unmarshal_state vals, Codec, Controller
with the four `R.* = Value.t` / `R.k = V_deployment.t` equalities, packed, kind).

### §2.6 `scenario` edits — multi-kind installed_types + VD builders

- **Multi-kind `installed_types`** (ADD, do NOT mutate the existing VRS one; keep additive):
  permissive predicates (all `true`) EXCEPT `marshalled_default_status` dispatches by kind:
    vreplicaset -> `Vreplica_set.marshal_status (Some (Vreplica_set.vrs_status_default ()))`
    vdeployment -> `V_deployment.marshal_status ()`   (* \`Null *)
    other/builtin (Pod) -> `Value.of_json \`Null`.
  Match on the kind — `Common.kind` is a finite sum; enumerate exhaustively (or match the
  Custom_resource string then a builtin fallthrough that is itself exhaustive over the kind sum).
- `vd ~desired : V_deployment.t` — a well-formed VDeployment CR in namespace "ns", name "vd1",
  uid 1, rv 0, `spec.replicas = Some desired`, a selector `{ match_labels = Some {"app"->"nginx"} }`,
  a template whose metadata.labels ⊇ the selector labels and whose spec is Some (reuse the vrs
  `template`/`selector` builders; the template MUST satisfy `Label_selector.matches`).
- `vd_ref : Common.object_ref = { kind = V_deployment.kind; name = "vd1"; namespace = "ns" }`.
- `vd_and_vrs_installed : Api_server.installed_types` (the multi-kind record above) and a helper
  to build the two-entry `controller_models` Imap (vrs id 0, vdeployment id 1) if a Cluster.t is
  wanted; for the EXEC test only `installed_types` + the two `reconcile_model`s are needed.

### §2.7 `multi_controller` (NEW exec driver — the two-controller round loop)

```
module Make (C : Concurrency.CONCURRENCY) (K : K8s_client.K8S_CLIENT with type 'a io = 'a C.t) : sig
  type report = { rounds : int; converged : bool }
  (* Drive several reconcile_models over ONE shared store to a JOINT fixpoint.
     Each round, for each model in order: List the model's kind in [namespace], and
     reconcile_with each returned CR (fuel-bounded). A round that performs no store
     write (rv unchanged) => joint fixpoint reached. [rv] reads the backend's
     resource_version write-clock (Exec: (Exec_api_server.state client).resource_version_counter). *)
  val run_to_fixpoint :
    client:K.t -> models:Controller.reconcile_model list -> namespace:string ->
    rv:(unit -> int) -> fuel:int -> max_rounds:int -> (report, Err.t) result C.t
end
```
Implementation: `module CR = Controller_runtime.Make (C) (K)`. `run_to_fixpoint`:
`let rec go rounds_left rounds_done =` if `rounds_left <= 0` then `C.return (Ok { rounds=rounds_done; converged=false })`
else `let before = rv () in` run one round (fold over models: for each model, `K.request client
(List_request { kind = model.kind; namespace })`, on `Ok (List_response { res = Ok objs })` fold
`CR.reconcile_with ~client ~model ~cr:obj ~fuel` over objs threading the C monad + `on_ok`; on the
8 other api_response variants or List error -> propagate `Error`), then `let after = rv () in`
`if Int.equal before after then C.return (Ok { rounds=rounds_done+1; converged=true })
else go (rounds_left-1) (rounds_done+1)`. All recursion (no loop kw); thread results via `C.bind`
+ the sanctioned `on_ok`. Exhaustive matches on api_response (9) and Io views.
NB List_response's `res` is a `(_,api_error) result` — fold over it with Result combinator, and
enumerate all 12 api_error on the Error side or collapse via a single Error propagation.

## §3. Confirm-by-mutation plan (t_p9_mutation.ml; shadow-analogue technique, per t_p8_mutation)

Each mutant: build correct, pin the assertion, apply mutant out-of-band, SEE red, revert, SEE green,
report transitions. Leave tree green, zero residue. In-tree shadow-analogues make the mutant exercised
(vacuity guard).
- **M1** create-suppression: in `create_new_vrs`, drop the Create request (return `(state, None)`).
  Pin: the two-controller converged store contains ≥1 VReplicaSet. (Shadow: a variant reconcile that
  skips the create must yield 0 VRS.)
- **M2** always-scale: make `mismatch_replicas` return `true` unconditionally. Pin: at joint fixpoint
  the single VReplicaSet has `spec.replicas = desired` (M2 would over/under-shoot / never settle → rv
  never stabilises within max_rounds → converged=false). 
- **M3** wrong scale target / off-by-one: `scale_new_vrs` uses `cur` instead of `cur+1`. Pin: converged
  VRS.replicas = desired (M3 stalls below desired → converged=false or replicas<desired).
- **M4** planted-divergence record over the converged finals (like t_p7 M4): an automated in-tree
  detector asserting (#VRS, VRS.replicas, #pods, vd outcome) = (1, desired, desired, Reconciled).
Also a reconcile_core-level mutant: **M5** barrier mis-guard — `After_ensure_new_vrs` uses `>=` instead
of `>` on the index bound, or drops the `valid_owned_vrs` guard; pin a reconcile_core unit assertion.

## §4. Firewall (enforced by hooks + dune gate; ZERO tolerance)

- Exhaustive matches on every finite sum: `Value.json` (`\`Null|\`Bool _|\`Int _|\`Intlit _|\`Float _|\`String _|\`List _|\`Assoc _`),
  api_request (9), api_response (9), api_error (12), step (8), Io.request_view/response_view (2 each),
  Controller_runtime.outcome (3), report/Mc outcomes. NO `_ ->` on a finite sum. The void External arm
  is refuted with `-> .`. Grouped tail `A _ | B _ | ... -> ...` is fine.
- NO two-arm match on option/result: use Option.fold/Option.map/Option.bind/Option.value/Option.equal,
  Result.fold, Res.(let*)/ok/error/map/bind. SOLE sanctioned raw match = the existing `on_ok` in
  controller_runtime (reuse it in multi_controller). Genuine 2-constructor SUM matches (both arms named,
  e.g. outcome) are fine and are NOT option/result.
- NO loop keywords (for/while/return/break/continue). Driver loops = `let rec ... = match frontier with
  [] -> ... | _::_ -> ...` + List.fold_left/map/filter/concat_map; fuel/rounds are explicit decremented ints.
- NO raise/failwith/assert/invalid_arg/exception in lib/. Tests use Alcotest (`Alcotest.check`,
  `Alcotest.failf`, `Alcotest.test_case`, `Alcotest.run`). NO `List.nth`/`List.hd` on unguarded input
  (use `List.nth_opt` + Option.fold; `List.hd` only under a proven `_::_`). NO polymorphic `Stdlib.(=)`
  on states/maps/closures — use `Int.equal`/`String.equal`/`Common.equal_kind`/type `.equal`.
- Additive only: P0–P8 files and all their tests stay byte-identical and green.

## §5. Test plan (Alcotest)

- `t_v_deployment.ml` (mirror t_vreplica_set.ml): each state_validation conjunct pinned (build a valid
  CR, then one broken variant per conjunct → false); marshal→unmarshal round-trip = equal; wrong-kind
  Dynamic_object → `Err.Kind_mismatch`; strategy Recreate-with-rollingUpdate → invalid.
- `t_v_deployment_reconciler.ml` (mirror t_vreplica_set_reconciler.ml): one `test_` per transition —
  Init emits List(vreplicaset); After_list_vrs with empty list → create path (After_create_new_vrs +
  Create req); After_list_vrs with a matching ready VRS at replicas<desired → scale path; After_create_new_vrs
  Ok → After_ensure_new_vrs; After_scale_new_vrs Ok → After_ensure_new_vrs; After_ensure_new_vrs index=0 →
  Done; After_ensure_new_vrs with an old vrs → scale_down (After_scale_down_old_vrs); After_scale_down_old_vrs
  loop → Done at index 0; Error routing on wrong-kind resp / absent resp / index>len. Verify req kind
  exhaustively; use V.step_equal.
- `t_p9_two_controller.ml` (mirror t_p7_controller_runtime.ml): seed a VDeployment (desired=3) into an
  Exec_api_server built with the multi-kind installed_types; `models = [ vd_model; vrs_model ]`
  (model_of_controller for each pack); `Multi_controller.Make(Direct)(Exec_api_server).run_to_fixpoint
  ~namespace:"ns" ~rv:(fun () -> (Exec_api_server.state client).resource_version_counter) ~fuel:100
  ~max_rounds:20`. Assert converged=true; store holds exactly 1 vreplicaset with spec.replicas=3;
  exactly 3 pods; no old vrs; a second run_to_fixpoint round is a no-op (idempotent). Also assert a
  desired=1 case and a desired=2 case (rolling steps).
- `t_p9_mutation.ml` (mirror t_p8_mutation.ml): the M1–M5 shadow-analogues above.

## §6. Build / run

```
eval $(opam env --switch=anvil-ocaml --set-switch)
dunecho build                                   # expect 0/0
perl -e 'alarm 180; exec @ARGV' _build/default/test/t_v_deployment.exe
perl -e 'alarm 180; exec @ARGV' _build/default/test/t_v_deployment_reconciler.exe
perl -e 'alarm 180; exec @ARGV' _build/default/test/t_p9_two_controller.exe
perl -e 'alarm 180; exec @ARGV' _build/default/test/t_p9_mutation.exe
# regression: run every existing t_*.exe (P0–P8) directly under the alarm; all green.
```
STAGE only (`git add`), never commit ([[feedback_never_commit]]). Suggested subject:
`feat(controllers): P9 VDeployment controller + two-controller convergence witness`.

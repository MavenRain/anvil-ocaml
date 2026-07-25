# BUILD-SPEC-P10 — VStatefulSet controller

Normative spec for Phase 10 of the anvil-ocaml port. Faithful port of Anvil's
`vstatefulset_controller` (`anvil-verifier/anvil` @ `src/controllers/vstatefulset_controller/`).
Follows P9 (VDeployment). All of P0-P9 is committed on `main` @ `731dc47`.

**Scope decision (settled):** VStatefulSet manages **Pods + PVCs directly** — it is a
SINGLE-controller (like VReplicaSet), NOT a controller-of-controllers (unlike P9's VDeployment).
The payoff is therefore a *richer single-controller witness*, not a two-controller story:
ordinal-stable pod identity, per-pod PVC lifecycle, and **one-pod-per-round rolling update**.

Companion evidence (scratchpad, may be GC'd — re-fetch upstream via
`gh api -H "Accept: application/vnd.github.raw" repos/anvil-verifier/anvil/contents/<path>`):
`p10-upstream/ALGORITHM-NOTES.md` (settled 17-step reconcile_core) and `p10-upstream/P10-PORT-KIT.md`
(OCaml surface, verbatim). This spec is self-contained; those files are provenance.

Branch: `p10-vstatefulset` off `main`. Build: `eval $(opam env --switch=anvil-ocaml --set-switch); dunecho build`.
`dune test` HANGS — run exes directly: `perl -e 'alarm 180; exec @ARGV' _build/default/test/t_*.exe`.

---

## 0. Bounds and conventions (hard constraints)

- Whole P10 session: **<=7 findings, <=56 agents** (scout already consumed 6). Every workflow prompt
  must state both caps.
- `lib` firewall (zero tolerance): no loop keywords; no wildcard `_ ->` on a finite sum (exhaustive
  arms only); no exception/`raise`/`assert` in `lib`; `Option.fold`/`Result.fold` combinators, NEVER a
  two-arm `match` on `option`/`result`; `List.nth_opt` NEVER `List.nth`; no `List.hd`/`List.tl`. Prefer
  `map`/`fold`/`filter` over hand recursion where it reads naturally.
- Never commit for the user: STAGE only, output a commit message. `rg`/`sd` never grep/sed.
- Confirm-by-mutation with **COMPILING** mutants only. A test never SEEN to fail is not evidence.
- Trust an all-clear review only after checking `agents_error == 0` (vacuity discipline). Stage before
  review; restore any mutation a finder leaves in the tree.

---

## 1. Files

### New (mirror the P9 VDeployment trio)
- `lib/controllers/v_stateful_set.ml` / `.mli` — CR view (`Resource_view.Make`), `kind_name = "vstatefulset"`.
- `lib/controllers/v_stateful_set_reconciler.ml` / `.mli` — 17-step `reconcile_core` + `R` reconciler module.
- `lib/controllers/v_stateful_set_pack.ml` / `.mli` — `Void_erase` pack, `Codec.id = 2`.
- `test/t_v_stateful_set.ml` — CR view: marshal round-trip, `state_validation`, `transition_validation`.
- `test/t_v_stateful_set_reconciler.ml` — per-step transitions (all 17 arms).
- `test/t_p10_witness.ml` — operational: converge N pods + N pvcs; one-pod-per-round rolling; scale-down.
- `test/t_p10_mutation.ml` — confirm-by-mutation harness (COMPILING mutants).

### Edits
- `lib/reconciler/io_resp.ml` / `.mli` — **GAP-A**: add `k_get_resp`.
- `lib/k8s_objects/persistent_volume_claim.ml` (+ `.mli` if present) — **GAP-B**: add `kind` + `marshal`/`unmarshal`.
- `lib/reconciler/scenario.ml` / `.mli` — **GAP-D**: `vsts` builder, `vsts_ref`, `vss_installed`, status branch.
- `lib/controllers/dune`, `test/dune` — wire the new modules/tests.

---

## 2. CR view — `v_stateful_set.ml` / `.mli`

Copy the structure of `v_deployment.ml`. Differences below.

- `let kind_name = "vstatefulset"` ; `let kind = Common.Custom_resource kind_name`
  (**NOT** `Common.Stateful_set` — that is the built-in object kind).
- **Reuse decision (settled):** the CR `spec` type IS `Stateful_set.ss_spec`, and `status` IS
  `Stateful_set.ss_status option` (VReplicaSet-style non-unit status). `views/stateful_set.ml` already
  defines `ss_spec` with the EXACT 11 CR-spec fields plus all four substructs (`ordinals`,
  `rolling_update`, `update_strategy` with `type_ : string option` — a plain string, NO finite sum —,
  `retention_policy`) and `ss_status { ready_replicas : int option }`, all WITH `default`/`equal`/
  `to_json`/`of_json` codecs. This is faithful (upstream `VStatefulSetSpecView == StatefulSetSpecView`
  field-for-field) and DRY. If a reviewer objects to cross-module coupling, the fallback is a parallel
  `vss_spec` copy, but reuse is the default and keeps one source of truth for the codecs.
- `type t = { metadata : Object_meta.t; spec : Stateful_set.ss_spec; status : Stateful_set.ss_status option }`.
- `controller_owner_ref s = Option.bind s.metadata.name (fun name -> Option.map (fun uid ->
  { block_owner_deletion = Some true; controller = Some true; kind; name; uid }) s.metadata.uid)`.
- `marshal_spec = Stateful_set.ss_spec_to_json` ; `unmarshal_spec`: `` `Assoc _ as j -> Stateful_set.ss_spec_of_json j ``
  else `Err.Decode_error { typ = "v_stateful_set.spec"; detail = "expected object" }`.
- `marshal_status`: `Option.fold ~none:\`Null ~some:Stateful_set.ss_status_to_json` (VReplicaSet idiom);
  `unmarshal_status`: `` `Null -> Ok None `` else `Stateful_set.ss_status_of_json j |> Res.map Option.some`.
- `recombine ~metadata ~spec ~status = { metadata; spec; status }`.

### `state_validation : t -> bool` (port faithfully; full upstream text in ALGORITHM-NOTES §state_validation)
Conjunction (use `Option.fold`/`Option.is_some`, never two-arm option match):
1. `selector.match_labels` is `Some` AND its `Smap.cardinal > 0`.
2. `template.metadata` is `Some` AND `template.spec` is `Some`.
3. `Label_selector.matches selector (template.metadata.labels or empty)`.
4. template labels (if `Some`) do NOT contain `"statefulset.kubernetes.io/pod-name"` nor
   `"apps.kubernetes.io/pod-index"`.
5. `replicas` (if `Some`) `>= 0`.
6. `update_strategy` (if `Some`): `type_` (if `Some`) is `"OnDelete"` (and `rolling_update` is `None`)
   OR `"RollingUpdate"` (and `rolling_update` if `Some`: `partition >= 0` and `max_unavailable > 0`).
7. `volume_claim_templates` (if `Some`): each `pvc.state_validation()` AND `name` `Some` AND `namespace`
   `Some` AND `dash_free(name)` (name contains no `'-'`).
8. `min_ready_seconds` (if `Some`) `>= 0`.
9. `ordinals` (if `Some`): `start` (if `Some`) `>= 0`.
   (`pod_management_policy` and `pvc_retention_policy` checks are COMMENTED OUT upstream — OMIT them.)

Labels (CONFIRMED, `trusted_exec_types.rs`): `POD_NAME_LABEL = "statefulset.kubernetes.io/pod-name"`,
`ORDINAL_LABEL = "apps.kubernetes.io/pod-index"`. Define both as `let` constants in the reconciler and
share with the view if convenient.

### `transition_validation : t -> old:t -> bool`
Port the immutable-field check: `replicas`, `template`, `persistent_volume_claim_retention_policy` are
MUTABLE; all other spec fields immutable. Reuse `Stateful_set.ss_spec_immutable_eq` (it exists) since the
spec type is shared. (VDeployment used `true`; here we can be faithful.)

### `.mli` surface
Expose: `type t`, `kind`, `kind_name`, `default`, `metadata`/`spec`/`status` projections, `recombine`,
`marshal_spec`/`unmarshal_spec`/`marshal_status`/`unmarshal_status`, `state_validation`,
`transition_validation`, `controller_owner_ref`, and the `Resource_view.Make`-derived `object_ref`,
`marshal`, `unmarshal`. Match the shape of `v_deployment.mli`.

---

## 3. Reconciler — `v_stateful_set_reconciler.ml` / `.mli`

Copy the idiom of `v_deployment_reconciler.ml` / `vreplica_set_reconciler.ml`.

```
reconcile_core : cr:V_stateful_set.t
              -> resp:Io.void Io.response_view option
              -> state:s
              -> s * Io.void Io.request_view option
```

### State record `s`
```
type s = {
  reconcile_step  : step;
  needed          : Pod.t option list;          (* index = ordinal 0..replicas-1; None if absent *)
  needed_index    : int;
  condemned       : Pod.t list;                 (* ordinal >= replicas, sorted DESC by ordinal *)
  condemned_index : int;
  pvcs            : Persistent_volume_claim.t list;  (* pvcs for the CURRENT needed pod; reset per pod *)
  pvc_index       : int;
}
```
`init`: `reconcile_step = Init; needed = []; needed_index = 0; condemned = []; condemned_index = 0;
pvcs = []; pvc_index = 0`.

### `step` — flat closed sum, 17 variants
```
type step =
  | Init | After_list_pod | Get_pvc | After_get_pvc | Create_pvc | After_create_pvc | Skip_pvc
  | Create_needed | After_create_needed | Update_needed | After_update_needed
  | Delete_condemned | After_delete_condemned | Delete_outdated | After_delete_outdated
  | Done | Error
```
Ship `step_equal` (exhaustive, no wildcard), `step_to_json`, `step_of_json`.
`reconcile_done state = (match state.reconcile_step with Done -> true | Error | Init | ... -> false)` —
express as an exhaustive 2-clause form with NO wildcard (list the false arms, or use `step_equal state.reconcile_step Done`).
`reconcile_error` likewise for `Error`.

### Firewall combinator (copy verbatim)
```
let with_ok_resp viewer state resp ~ok =
  Option.fold (viewer resp)
    ~none:(error_state state, None)
    ~some:(Result.fold ~error:(fun _ -> (error_state state, None)) ~ok)
```
Every resp-consuming step routes through `with_ok_resp` EXCEPT `After_get_pvc` (which must inspect the
error arm — see GAP-A). `error_state state = { state with reconcile_step = Error }`.

### Per-step algorithm — EXACT (see ALGORITHM-NOTES for the fully expanded form)
`reconcile_core` reads `cr.metadata`, resolves `namespace` inside the arms that need it (VReplicaSet
style), then `match state.reconcile_step with` (exhaustive):

1. **Init**: if `metadata.deletion_timestamp` is `Some` -> `(Done, None)`; else
   `req = List_request { kind = Pod.kind; namespace }`, step := `After_list_pod`.
2. **After_list_pod**: guard `resp` is `Some` k-list AND `Ok` else Error. Unmarshal each object to `Pod`;
   if ANY fails -> Error. `filtered = pods |> List.filter (pod_filter cr)`. `replicas = spec.replicas or 1`.
   `(needed, condemned) = partition_pods(cr.name, replicas, filtered)`. `pvcs = make_pvcs(cr, 0)`;
   `needed_index = condemned_index = pvc_index = 0`. DISPATCH:
   - if `needed_index < len needed`: if `len pvcs > 0` -> `Get_pvc`; else if `needed[needed_index]` is
     `None` -> `Create_needed` else `Update_needed`;
   - else if `condemned_index < len condemned` -> `Delete_condemned` (set `pvc_index := len pvcs`);
   - else -> `Delete_outdated` (set `pvc_index := len pvcs`).
3. **Get_pvc**: guard `pvc_index < len pvcs` AND `pvcs[pvc_index].name` `Some` else Error.
   `req = Get_request { key = { kind = Persistent_volume_claim.kind; name = pvcs[pvc_index].name; namespace } }`,
   step := `After_get_pvc`.
4. **After_get_pvc** (does NOT use `with_ok_resp` — GAP-A): `Option.fold (Io_resp.k_get_resp resp)`
   `~none:(Error,None)` `~some:(Result.fold ~ok:(fun _ -> Skip_pvc-state) ~error:(fun e -> if e is
   Object_not_found then Create_pvc-state else Error-state))`.
5. **Create_pvc**: guard `pvc_index < len pvcs` else Error.
   `req = Create_request { namespace; obj = Persistent_volume_claim.marshal pvcs[pvc_index] }`;
   `pvc_index += 1`; step := `After_create_pvc`.
6. **After_create_pvc**: guard `resp` is `Some` k-create; `Ok` OR `Err Object_already_exists` ->
   `create_or_skip_pvc_helper cr state`; else Error.
7. **Skip_pvc**: guard `pvc_index < len pvcs` else Error. `pvc_index += 1`; then
   `create_or_skip_pvc_helper cr state'`.
   - `create_or_skip_pvc_helper state`: if `pvc_index < len pvcs` -> `Get_pvc`; else if
     `needed_index < len needed`: `needed[needed_index]` `None` -> `Create_needed` else `Update_needed`;
     else -> Error (unreachable).
8. **Create_needed**: guard `needed_index < len needed` else Error.
   `req = Create_request { namespace; obj = Pod.marshal (make_pod cr needed_index) }`;
   `needed_index += 1`; step := `After_create_needed`.
9. **After_create_needed**: guard `resp` is `Some` k-create; `Ok` OR `Err Object_already_exists` ->
   `create_or_after_update_needed_helper cr state`; else Error.
10. **Update_needed**: guard `needed_index < len needed` AND `needed[needed_index]` is `Some` else Error.
    `old_pod = needed[needed_index]`; guard `old_pod.name` `Some` else Error. `ordinal = needed_index`;
    `new_pod = update_storage(cr, update_identity(cr, old_pod, ordinal), ordinal)`.
    `req = Get_then_update_request { namespace; name = new_pod.name; owner_ref = controller_owner_ref cr;
    obj = Pod.marshal new_pod }`; `needed_index += 1`; step := `After_update_needed`.
11. **After_update_needed**: guard `resp` is `Some` k-get-then-update; `Ok` ->
    `create_or_after_update_needed_helper cr state`; else Error.
    - `create_or_after_update_needed_helper state`: if `needed_index < len needed`:
      `new_pvcs = make_pvcs(cr, needed_index)`, `new_pvc_index = 0`; if `len new_pvcs > 0` -> `Get_pvc`
      (`pvcs := new_pvcs`, `pvc_index := 0`); else `needed[needed_index]` `None` -> `Create_needed` else
      `Update_needed`; else if `condemned_index < len condemned` -> `Delete_condemned`; else ->
      `Delete_outdated` state.
12. **Delete_condemned**: guard `condemned_index < len condemned` else Error.
    `condemned_pod = condemned[condemned_index]`; guard `condemned_pod.name` `Some` else Error.
    `req = Get_then_delete_request { key = { kind = Pod.kind; name = condemned_pod.name; namespace };
    owner_ref = controller_owner_ref cr }`; `condemned_index += 1`; step := `After_delete_condemned`.
13. **After_delete_condemned**: guard `resp` is `Some` k-get-then-delete; `Ok` OR `Err Object_not_found`:
    if `condemned_index < len condemned` -> `Delete_condemned` else -> `Delete_outdated` state; else Error.
14. **Delete_outdated**: `p = get_largest_unmatched_pods(cr, needed)`. If `p` is `Some pod`: guard
    `pod.name` `Some` else Error; `req = Get_then_delete_request { key = { kind = Pod.kind; name =
    pod.name; namespace }; owner_ref }`; step := `After_delete_outdated`. Else -> `Done` (CONVERGENCE).
15. **After_delete_outdated**: guard `resp` is `Some` k-get-then-delete; `Ok` OR `Err Object_not_found`
    -> `Done`; else Error.
16/17. **Done** / **Error**: `(state, None)`. (These are the two terminal arms — explicit, no wildcard.)

### Helpers — EXACT (see ALGORITHM-NOTES §Helpers for full text)
- `pod_name_without_vsts_prefix parent ord = parent ^ "-" ^ string_of_int ord`.
- `pod_name parent ord = "vstatefulset" ^ "-" ^ pod_name_without_vsts_prefix parent ord`
  (e.g. `parent="web", ord=2` -> `"vstatefulset-web-2"`).
- `get_ordinal parent name`: the `ord` s.t. `name = pod_name parent ord`, else `None`. Port: strip the
  `"vstatefulset-" ^ parent ^ "-"` prefix and `int_of_string_opt` the suffix (injective).
- `pod_filter cr pod`: `pod.owner_references_contains (controller_owner_ref cr)` AND `cr.name` `Some` AND
  `pod.name` `Some` AND `get_ordinal cr.name pod.name` is `Some`. (Upstream `selector.matches` is
  COMMENTED OUT — filter by owner-ref + parseable ordinal ONLY.)
- `get_pod_with_ord parent pods ord`: first pod with `get_ordinal = Some ord`, else `None`
  (`List.find_opt`).
- `partition_pods parent replicas pods`:
  `needed = List.init replicas (fun ord -> get_pod_with_ord parent pods ord)` (length = `replicas`);
  `condemned = pods |> List.filter_map (fun p -> ord?) |> filter (ord >= replicas) |> sort DESC by ordinal`.
- `make_pod cr ordinal`: `Pod` with `meta { name = pod_name cr.name ordinal; labels =
  template.meta.labels; annotations = template.meta.annotations; owner_references = [owner_ref] }`,
  `spec = Some template.spec`; then `update_storage(cr, init_identity(cr, pod, ord), ord)`.
- `init_identity cr pod ord`: `updated = update_identity cr pod ord`; then set `updated.spec` (Some) with
  `hostname = updated.meta.name`, `subdomain = Some cr.spec.service_name`.
- `update_identity cr pod ord`: rewrite `pod.meta.labels` to `(template.meta.labels or empty)` with
  `POD_NAME_LABEL := pod.meta.name` and `ORDINAL_LABEL := string_of_int ord` inserted; set
  `owner_references = [owner_ref]`, `annotations = template.meta.annotations`, `finalizers = None`,
  `deletion_timestamp = None`.
- `pvc_name tmpl_name vsts_name ord = "vstatefulset" ^ "-" ^ tmpl_name ^ "-" ^
  pod_name_without_vsts_prefix vsts_name ord` -> `"vstatefulset-<tmpl>-<vsts>-<ord>"`.
- `make_pvc cr ord i`: `tmpl = volume_claim_templates[i]`; `PVC { meta { name = pvc_name tmpl.name
  cr.name ord; namespace = cr.namespace; labels = union_prefer_right tmpl.labels selector.match_labels };
  spec = tmpl.spec }`.
- `make_pvcs cr ord = List.init (len volume_claim_templates) (make_pvc cr ord)` or `[]` if none.
- `update_storage cr pod ord`: if `pod.spec` `None` -> `pod`; else `pvcs = make_pvcs cr ord`,
  `templates = volume_claim_templates or []`; `new_volumes = List.mapi (fun i _ -> Volume { name =
  templates[i].name; persistent_volume_claim = Some { claim_name = pvcs[i].name; read_only = Some false } })
  templates`; `filtered_current = pod.spec.volumes(or []) |> filter (name not in template names)`;
  set `pod.spec.volumes = Some (new_volumes @ filtered_current)`.
- `pod_spec_matches cr pod`: `pod.spec` `Some` AND
  `pod.spec |> without_volumes |> without_hostname |> without_subdomain =
   template.spec |> without_volumes |> without_hostname |> without_subdomain`.
- `outdated_pod_filter cr = function Some pod -> not (pod_spec_matches cr pod) | None -> false`.
- `get_largest_unmatched_pods cr needed`: `needed |> List.filter (outdated_pod_filter cr) |> List.rev
  |> List.nth_opt _ 0` (needed is ascending by ordinal, so the LAST match = largest ordinal). Use a
  combinator, never `List.nth`.

### API verbs used
`List(Pod)`, `Get(PVC)`, `Create(PVC)`, `Create(Pod)`, `GetThenUpdate(Pod)`, `GetThenDelete(Pod)`.

### GetThenDelete owner-ref gate (CAVEAT)
`handle_get_then_delete_request_msg` deletes ONLY when the stored object's
`owner_references_contains` matches `req.owner_ref`, else `Transaction_abort`. So EVERY created pod
(`make_pod` sets `owner_references = [owner_ref]` — good) AND every seeded pod/condemned pod AND every pvc
MUST carry the VStatefulSet owner_ref, or a delete aborts. Enforce this in the scenario seeds (GAP-D).

### `R` reconciler module + `.mli`
Wrap `reconcile_core` in the `R` module shape the pack expects (mirror `v_deployment_reconciler.ml`'s
`R`). Expose in `.mli`: `type s`, `type step`, `init`, `reconcile_core`, `reconcile_done`,
`reconcile_error`, `step_equal`/`step_to_json`/`step_of_json`, and `R`.

---

## 4. GAP resolutions (implement + verify during build)

### GAP-A — `io_resp` lacks `k_get_resp` (plain Get). ADD it.
`After_get_pvc` consumes a plain `Get_request` response (a PVC existence probe) and MUST discriminate
`Object_not_found` (-> `Create_pvc`) from other errors (-> `Error`). `with_ok_resp` collapses ALL errors,
so `After_get_pvc` cannot use it. Add to `io_resp.ml`/`.mli`, mirroring `k_create_resp` but matching
`Api_method.Get_response { res : (Dynamic_object.t, api_error) result }`:
```
val k_get_resp : 'a Io.response_view option -> (Dynamic_object.t, Api_method.api_error) result option
```
Verify: (1) the exact not-found variant name in `lib/k8s_objects/api_method.mli` (likely
`Object_not_found`); (2) `Api_server.transition_by_etcd` handles a plain `Get_request` end-to-end and
returns the not-found error when the key is absent. Both are load-bearing for After_get_pvc's branch.

### GAP-B — PVC has no store-object identity. ADD `kind` + `marshal`/`unmarshal`.
`persistent_volume_claim.ml` is a PLAIN RECORD (`to_json`/`of_json` only). Reconcile does
`Persistent_volume_claim.marshal pvcs[i]` (Create obj) and a `Get_request` with a PVC key of
`Persistent_volume_claim.kind`. Add (do NOT convert to a `Resource_view.Make` instance — that would churn
`views/stateful_set.ml`'s `ss_spec.volume_claim_templates : Persistent_volume_claim.t list`):
```
let kind = Common.Persistent_volume_claim
val marshal   : t -> Dynamic_object.t          (* Dynamic_object.make ~kind ~metadata ~spec-json ~status-json, mirror Pod.marshal *)
val unmarshal : Dynamic_object.t -> t Res.t     (* kind-check then decode *)
```
Verify `Common.kind` has a `Persistent_volume_claim` arm (scenario `..._installed` returns `` `Null ``
for it, implying yes). Inspect `pod.ml`'s marshal + `Dynamic_object.mli` for the exact builder shape.

### GAP-C — pack must serialize the RICHER state. `Codec.id = 2` (VRS=0, VD=1; add a guard comment).
`Void_erase` round-trips the WHOLE state through the codec on EVERY transition (P9 lesson — a dropped
list field would reset the pvc/condemned cursors each step). `marshal_state` / `unmarshal_state` members:
- `"step"`: `step_to_json` (always present).
- `"neededIndex"` / `"condemnedIndex"` / `"pvcIndex"`: `Json.int_` always-present; decode
  `Json.opt_mem + Json.to_int |> Res.map (Option.value ~default:0)` (VD `oldVrsIndex` precedent).
- `"condemned"`: `Pod.t list` — `Json.list (fun p -> Dynamic_object.to_json (Pod.marshal p))`; inverse
  `Dynamic_object.of_json` + `Pod.unmarshal` (VRS `filtered_pods` pattern).
- `"pvcs"`: `Persistent_volume_claim.t list` — same pattern using the GAP-B PVC marshal/unmarshal.
- `"needed"`: `Pod.t option list` — **NEW** (no precedent for option-in-list). Encode as `Json.list`
  where each elt is `` `Null `` for `None` else `Dynamic_object.to_json (Pod.marshal p)`; decode tolerant
  of `` `Null `` -> `None`, object -> `Some (unmarshal ...)`. Write a small null-tolerant encoder/decoder
  pair.
- `unmarshal_state` non-object fallback: exhaustive Yojson-constructor match (NO wildcard) ->
  `Err.Decode_error { typ = "v_stateful_set_pack.state"; detail = "expected object" }`.
- `Codec.unmarshal_cr = V_stateful_set.unmarshal`; `Codec.kind = V_stateful_set.kind`.

### GAP-D — scenario + exec (single-controller witness, NOT `multi_controller`).
- `scenario.ml`/`.mli`: add `vsts ~desired ?vct ?service_name ?labels ...` builder (a VStatefulSet CR with
  `selector`/`template`, `replicas = desired`, optionally ONE `volumeClaimTemplate`); `vsts_ref`; and
  `vss_installed` `installed_types` admitting VSS CR + Pod + PVC.
- `marshalled_default_status`: add a `V_stateful_set.kind_name` branch returning the VSS default status
  (`` `Null `` or `{ readyReplicas : null }`); keep the `Common.kind` match exhaustive.
- Drive with the P7 SINGLE-controller runtime: `Controller_runtime.Make(Concurrency.Direct)(Exec_api_server)`
  + `run_controller`, `model_of_controller` via `V_stateful_set_pack`. Count `Pod.kind` /
  `Persistent_volume_claim.kind` entries in the store. Seeds MUST carry the VSTS owner_ref (GetThenDelete
  gate). Confirm `run_controller`'s signature + how a CR is installed/seeded from `exec_api_server.ml` +
  `controller_runtime.ml` during the build.

---

## 5. Tests

### `t_v_stateful_set.ml` (CR view)
- `default` round-trips: `unmarshal (marshal default) = Ok default`.
- Non-trivial CR (replicas=3, a volumeClaimTemplate, update_strategy=RollingUpdate) round-trips.
- `state_validation`: one PASS case; one FAIL per clause 1-9 (each isolated). Assert the exact boolean.
- `transition_validation`: mutating `replicas`/`template`/`pvc_retention_policy` -> `true`; mutating
  `service_name` (immutable) -> `false`.
- `unmarshal` rejects a wrong-`kind` `Dynamic_object` with `Decode_error`.

### `t_v_stateful_set_reconciler.ml` (per-step)
Drive `reconcile_core` arm by arm with hand-built `resp`/`state`, asserting `(next_step, request)`:
- Init: deletion_timestamp `Some` -> Done/None; else -> After_list_pod + `List_request`.
- After_list_pod: pods `[]`, replicas=2, one vct -> needed=[None;None], pvcs len>0 -> Get_pvc.
- Get_pvc -> Get_request(PVC key). After_get_pvc Ok -> Skip_pvc; Err Object_not_found -> Create_pvc;
  Err other -> Error.
- Create_pvc -> Create_request(PVC), pvc_index+1. After_create_pvc Ok / AlreadyExists -> helper dispatch.
- Skip_pvc -> pvc_index+1 + helper dispatch.
- Create_needed -> Create_request(Pod named `vstatefulset-<name>-0`). After_create_needed Ok/AlreadyExists
  -> helper dispatch.
- Update_needed (needed[i]=Some) -> Get_then_update_request(Pod). After_update_needed Ok -> helper.
- Delete_condemned -> Get_then_delete_request(Pod). After_delete_condemned Ok/NotFound -> next / outdated.
- Delete_outdated: all needed match -> Done/None; one outdated -> Get_then_delete(largest ordinal) +
  After_delete_outdated. After_delete_outdated Ok/NotFound -> Done.
- Guard failures (index OOB, missing name) -> Error on the relevant steps.
- Helpers directly: `pod_name`, `get_ordinal` (round-trip + reject non-matching), `partition_pods`
  (needed length = replicas, condemned sorted DESC), `pod_spec_matches` (ignores volumes/hostname/
  subdomain), `get_largest_unmatched_pods` (picks largest ordinal), `update_identity` (labels inserted),
  `update_storage` (volumes rewritten to pvc-backed).

### `t_p10_witness.ml` (operational, single-controller)
- **Converge**: desired=3 + one volumeClaimTemplate -> repeated `run_controller` reaches a fixpoint with
  exactly 3 pods (`vstatefulset-<name>-0..2`) + 3 pvcs (`vstatefulset-<tmpl>-<name>-0..2`), created via the
  per-pod PVC loop then Create_needed IN ORDINAL ORDER. Assert names + counts.
- **Rolling one-per-round**: after convergence, mutate `template.spec` -> assert that ONE reconcile round
  deletes exactly the LARGEST-ordinal stale pod and ends (Done), and full convergence takes ~`replicas`
  rounds. This is the genuinely-new semantics vs VRS/VDeployment — assert it precisely (count deletions
  per round == 1).
- **Scale down**: 3 -> 1 -> pods ordinal 1,2 become condemned -> Delete_condemned each -> 1 pod remains.

### `t_p10_mutation.ml` (confirm-by-mutation, COMPILING mutants)
For each, apply the mutant, SEE a P10 test fail, restore. Suggested mutants:
1. `pod_name` drops the ordinal (`parent` only) -> witness pod-name assertions fail.
2. `partition_pods` uses `<=` instead of `<` for condemned threshold -> scale-down count wrong.
3. `get_largest_unmatched_pods` picks `List.hd` (smallest ordinal) instead of last -> rolling-order fails.
4. After_get_pvc treats `Object_not_found` as `Ok` (-> Skip_pvc) -> pvc never created, witness pvc count 0.
5. Pack drops the `"needed"` member on marshal -> cursor resets, convergence stalls/loops.
6. `update_identity` omits the `ORDINAL_LABEL` insert -> label assertion fails.

Vacuity guard: each mutation test must read a value the mutated code actually produces (not a constant).

---

## 6. Build workflow plan (sequential general-purpose agents; each GREEN before handoff)

1. **Foundation** — `io_resp.k_get_resp` (GAP-A) + PVC `marshal`/`unmarshal`/`kind` (GAP-B). `dunecho build` green.
2. **CR view** — `v_stateful_set.ml`/`.mli` (reuse `Stateful_set` substructs; `kind_name`; rich
   `state_validation`; status). Build green.
3. **Reconciler** — `v_stateful_set_reconciler.ml`/`.mli` (17 steps per §3; firewall; owner_ref on
   pods/pvcs). Build green.
4. **Pack + Scenario** — `v_stateful_set_pack.ml`/`.mli` (GAP-C, `Codec.id=2`) + scenario edits (GAP-D) +
   dune wiring. Build green.
5. **Tests** — the four test modules above. Run exes directly (test hang caveat). All green.
6. **Greenup** — full battery green (all P0-P9 suites untouched + P10); firewall check: 0 loop-kw /
   wildcard-on-finite-sum / exception in `lib`.

Then **review wf** (adversarial lens finders -> skeptic refute -> synth; check `agents_error == 0` for
non-vacuity), fix survivors, confirm-by-mutation, verify NO leftover mutations in the tree, STAGE (never
commit), update `project-anvil-ocaml-p10-vstatefulset` memory + MEMORY.md index line.

Suggested commit subject:
`feat(controllers): P10 VStatefulSet controller (ordinal identity + PVC lifecycle + one-pod-per-round rolling update)`.

---

## 7. The P10 payoff (state in memory + PR body)

VStatefulSet manages Pods+PVCs DIRECTLY (not child controllers), so P10 is a richer SINGLE-controller
witness: ordinal-stable identity, per-pod PVC lifecycle (Get->NotFound->Create), and one-pod-per-round
rolling update (delete largest-ordinal stale pod, end reconcile, requeue -> converge after ~N rounds).
Assurance = reconcile_core per-step unit tests + the operational witness + confirm-by-mutation. P5 BMC
over VStatefulSet is HONESTLY SCOPED OUT (PVC loop + ordinal partition + rolling = a separate
state-explosion project); this is NOT a bounded proof and NOT Anvil's Verus liveness theorem.

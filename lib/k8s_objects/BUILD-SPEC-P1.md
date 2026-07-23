# P1 build spec — the k8s object spec model

Normative contract for Phase 1 of anvil-ocaml (see
`../../../comp-cat-ocaml/lib/temporal/ARCHITECTURE-anvil-ocaml.md` §3.2 for the
whole-repo plan). P1 is **standalone**: `k8s_objects` does not depend on
`comp_cat`. It is a faithful port of Anvil's `kubernetes_api_objects/spec/`
tree.

## Ground truth

- Anvil reference clone: `<SCRATCH>/anvil-ref/src/kubernetes_api_objects/spec/`
  (`<SCRATCH>` = `/private/tmp/claude-501/-Users-oobi-Documents-claude1/3890aaf5-5a55-4012-a408-2b457286f292/scratchpad`).
- Pre-extracted exact field/variant digests (read these first, they are the
  port targets — do **not** invent fields Anvil does not define):
  `<SCRATCH>/digest_object_meta.json`, `digest_api_method.json`,
  `digest_config_map.json`, `digest_pod.json`, `digest_stateful_set.json`,
  `digest_volume.json`.

## Representation decisions (locked)

- `StringView` (= `Seq<char>`) → OCaml **`string`**.
- `Uid`/`ResourceVersion`/`GenerateNameCounter` → abstract int newtypes
  (already declared in `common.mli`).
- `Map<StringView,StringView>` → **`string Smap.t`** where
  `Smap = Map.Make(String)` (canonical unordered semantics, sorted-key JSON for
  deterministic round-trip). Add `Smap` to `anvil_support`.
- `Seq<T>` → OCaml **`list`**.
- Verus `int` is unbounded; OCaml `int` is the carrier (values are ids/counters,
  never arithmetic operands in this layer) — document, do not model bignum.
- `Value` (Anvil `= StringView`) → **abstract, wrapping `Yojson.Safe.t`** with a
  string bridge (see Value below). Anvil marshals via serde_json in its exec
  model, so JSON is the faithful carrier.

## Convention firewall (hard requirements — the review will hunt these)

- No exceptions: no `raise`/`failwith`/`assert`/`invalid_arg`. Every partial
  function returns `Res.t` (`open Anvil_support`; `let open Res in` for `let*`).
- The **sole** permitted `try/with` in the whole lib is `Value.of_string`
  quarantining yojson's exception-based parser. Nowhere else.
- No two-arm `match` on `option`/`result` outside `Res`/`Err`. Use `Res`/`Option`
  combinators (`Option.map`, `Option.value`, `Res.map_m`, ...).
- Exhaustive matches on every finite sum (`kind` 11, `api_request` 9,
  `api_response` 9, `api_error`, the volume-source sum, ...). **No `_ ->`
  catch-all** on any of them.
- Prefer fold/map/`List.filter` over hand-written recursion where natural; no
  imperative loops.
- Every public `.mli` value carries a doc comment with an Anvil source pointer.
- Warning flags (all dune files): `(:standard -w +a-4-9-40-41-42-44-45-70)`.
  Non-exhaustive match is an error under this set — good.
- Dual license header not required per file; the repo LICENSE-* files suffice.

## Module inventory and required signatures

`lib/support/` (library `anvil_support`) — **already written**: `err`, `res`.
Add `smap.ml`: `include Map.Make (String)`.

`lib/k8s_objects/` (library `anvil_k8s_objects`, `(libraries anvil_support
yojson)`, `(include_subdirs unqualified)` so `views/` folds in). Modules:

### `common` — DONE (`common.mli` written). Provide `common.ml`.
Implement `Uid`/`Resource_version`/`Generate_name_counter` as
`struct type t = int … end`. `equal_kind` structural (Custom_resource compares
its string). `show_kind`: ConfigMap→"ConfigMap", Pod→"Pod", …,
`Custom_resource s`→"CustomResource("^s^")". `equal_object_ref` field-wise.

### `json` — codec helpers over `Yojson.Safe.t` (NEW).
Encoders returning `Yojson.Safe.t`: `str`,`int_`,`bool_`,`obj : (string*Yojson
.Safe.t) list -> _`,`list : ('a->Yojson.Safe.t)->'a list->_`,`smap : string
Smap.t -> _` (object, keys already sorted by Smap),`opt : ('a->Yojson.Safe.t)
->'a option->Yojson.Safe.t option` (used to drop `None` fields — omit absent
optionals rather than emit null, and read them back as absent).
Decoders returning `Res.t` (`Err.Decode_error`/`Err.Missing_field`): `to_str`,
`to_int`,`to_bool`,`mem : Yojson.Safe.t -> string -> Yojson.Safe.t Res.t`
(required field),`opt_mem : Yojson.Safe.t -> string -> (Yojson.Safe.t -> 'a Res
.t) -> 'a option Res.t` (absent/`Null` → `Ok None`),`to_list : (Yojson.Safe.t
->'a Res.t) -> Yojson.Safe.t -> 'a list Res.t`,`to_smap : Yojson.Safe.t ->
string Smap.t Res.t`. Build object encoders with a helper that filters dropped
optionals: `obj_opt : (string * Yojson.Safe.t option) list -> Yojson.Safe.t`.

### `value` — the marshalled-value carrier (NEW).
```
type t                              (* abstract, wraps Yojson.Safe.t *)
val of_json : Yojson.Safe.t -> t
val json    : t -> Yojson.Safe.t
val to_string : t -> string          (* Yojson.Safe.to_string; total *)
val of_string : string -> t Res.t    (* SOLE try/with; parse -> Malformed_value *)
val equal   : t -> t -> bool          (* structural on the json *)
```

### `owner_reference` — from `digest_object_meta.json` (OwnerReferenceView).
Record: `block_owner_deletion:bool option; controller:bool option; kind:Common
.kind; name:string; uid:Common.Uid.t`. Free fns (faithful):
`to_object_reference : t -> namespace:string -> Common.object_ref`
(`{kind; namespace; name}`), `is_controller : t -> bool` (`controller = Some
true`), `eq_without_uid : t -> t -> bool` (compares controller,
block_owner_deletion, kind, name — excludes uid). `equal`. JSON codec
(`to_json`/`of_json : … Res.t`). `default` is uninterpreted in Anvil — provide a
documented all-None/empty default.

### `object_meta` — from `digest_object_meta.json` (ObjectMetaView, 10 fields).
Record, ALL fields `option`: `name:string option; generate_name:string option;
namespace:string option; resource_version:Common.Resource_version.t option;
uid:Common.Uid.t option; labels:string Smap.t option; annotations:string Smap.t
option; owner_references:Owner_reference.t list option; finalizers:string list
option; deletion_timestamp:string option`. Provide: accessors incl. `name`,
`namespace` (needed by the functor); `default : unit -> t` (all None); the
builder/mutator fns from the digest (`with_name`, `with_namespace`,
`add_label`, `without_label`, `with_labels`, `with_annotations`,
`add_annotation`, `with_owner_references`, `with_finalizers`,
`with_resource_version`, `with_deletion_timestamp`, `with_uid`,
`with_generate_name`, and the `without_*` variants); `well_formed_for_namespaced
: t -> bool` (name&namespace&resource_version&uid all Some — the ONLY
well-formedness fn); `owner_references_contains`, `finalizers_as_set` (→ a
`Sset = Set.Make(String)`; add to support); `equal`; JSON codec.

### `dynamic_object` — from `spec/dynamic.rs`.
Record `{ kind:Common.kind; metadata:Object_meta.t; spec:Value.t; status:Value
.t }`. Provide `make : kind:… -> metadata:… -> spec:… -> status:… -> t`, and
accessors `kind`,`metadata`,`spec`,`status` (the functor calls these exact
names). `object_ref : t -> Common.object_ref Res.t` (Missing_field if name/
namespace absent — mirrors the functor). `with_metadata`,`with_name`,
`with_namespace`,`with_resource_version`,`with_uid`,`with_deletion_timestamp`
(Anvil builders). `equal`. Optional whole-object JSON codec.

### `resource_view` — DONE (`.mli` + `.ml` written; do not edit the functor).
Read it: builder-supplied modules must satisfy `RESOURCE`.

### `api_method` — from `digest_api_method.json`.
`api_error` sum (Anvil `APIError`: read the digest for the exact variants —
ObjectNotFound, ObjectAlreadyExists, Conflict, InvalidRequest,
InternalError, Timeout, … port EXACTLY the source set). `preconditions`
(`PreconditionsView { uid:Uid option; resource_version:ResourceVersion option }`).
`api_resource` (`{ kind }`). Nine request structs + the `api_request` sum, nine
response structs + the `api_response` sum, all per the digest. Each request's
`key`/relevant projection fn. Exhaustive; no `_ ->`. `equal` where cheap.

### `views/` — functor instances (each an `RV = Resource_view.Make(struct … end)`).
Expose the typed view via the generated module + typed constructors. Port
**exactly** Anvil's field sets from the digests; no more, no fewer.
- `config_map` (`digest_config_map.json`): fields `{metadata; data:string Smap.t
  option}` (NO spec/status field on the struct). `spec` assoc type = the `data`
  option; `status` = unit. `spec v = v.data`; `recombine ~metadata ~spec ~status
  = {metadata; data=spec}` (status ignored). `kind=Config_map`.
  `marshal_spec`/`unmarshal_spec` = codec for `string Smap.t option`.
  `marshal_status`/`unmarshal_status` for `unit` (encode to `Null`, decode to
  `()` accepting Null). `state_validation=true`, `transition_validation _ ~old:_
  =true`.
- `pod` (`digest_pod.json`): PodView `{metadata; spec:PodSpecView option;
  status:PodStatusView option}` — check the digest for exact option-ness. Port
  PodSpecView, PodStatusView, ContainerView, ContainerPortView, VolumeMountView,
  EnvVarView, EnvVarSourceView, ObjectFieldSelectorView, ProbeView,
  ExecActionView, TCPSocketActionView, LifecycleView, LifecycleHandlerView,
  SecurityContextView, PodSecurityContextView, LocalObjectReferenceView,
  ResourceRequirementsView, AffinityView, TolerationView, VolumeView and the
  volume-source sum — **exactly** Anvil's fields. Shared nested types
  (`pod_template_spec`, `label_selector`, `volume`, `resource_requirements`,
  `persistent_volume_claim`, `volume_resource_requirements`) live in their own
  modules under `k8s_objects/` (NOT under `views/`) since `stateful_set` reuses
  them. `state_validation`/`transition_validation` per Anvil (Pod's may be
  `true`; read source).
- `stateful_set` (`digest_stateful_set.json`): StatefulSetView + spec + status +
  the nested it references (LabelSelectorView, PodTemplateSpecView,
  PersistentVolumeClaimView, the retention-policy / ordinals / update-strategy
  views). `transition_validation` is **meaningful** here (immutable-field
  checks) — port the real body, do not stub it.

Nested shared modules to create (from the pod/stateful_set/volume digests):
`container`, `pod_template_spec`, `label_selector`, `volume`,
`resource_requirements`, `volume_resource_requirements`,
`persistent_volume_claim`, `affinity`, `toleration`, `env_var`, `probe`,
`security_context`, `local_object_reference`, `object_field_selector`. Each: the
record(s), `default` where Anvil has one, `equal`, and JSON `to_json`/`of_json :
… Res.t`. Group tightly-coupled small types in one module where sensible
(e.g. probe + its actions; env_var + source + field_selector).

## Tests (`test/`, library deps `anvil_k8s_objects alcotest qcheck-core
qcheck-alcotest`)

- `t_common.ml`: kind equality/show, object_ref equality, newtype round-trip.
- `t_object_meta.ml`: builders compose; `well_formed_for_namespaced` truth
  table (each of the 4 required fields absent → false; all present → true);
  `owner_references_contains`; label add/remove.
- `t_functor.ml`: for ConfigMap, Pod, StatefulSet via the functor:
  `unmarshal (marshal o) = Ok o`; `object_ref` fails Missing_field when
  name/namespace absent and succeeds otherwise; `unmarshal` of a
  `Dynamic_object` with the wrong `kind` → `Kind_mismatch`.
- `t_marshal_props.ml` (QCheck): random generators for ConfigMap, Pod,
  StatefulSet values; properties `unmarshal (marshal o) = Ok o`,
  `unmarshal_spec (marshal_spec s) = Ok s`, and `Value.of_string (Value.to_string
  v) = Ok v` for marshalled specs. Also a `Dynamic_object` whole-object JSON
  round-trip if the codec is provided.
- `t_api_method.ml`: request/response `key`/projection sanity; exhaustive
  construction of every variant compiles.
- **confirm-by-mutation** (`feedback-confirm-tests-by-mutation`): after green,
  for at least 3 guards — (a) the functor `unmarshal` kind check, (b)
  `object_ref` Missing_field on absent name, (c) StatefulSet
  `transition_validation` immutable-field rejection — neuter the guard, show the
  paired negative test flips to failing, restore. Record which test pins which
  guard in a comment block.

## Build / run

```
eval $(opam env --switch=anvil-ocaml --set-switch)
dunecho build      # 0 warnings/0 errors required
dunecho test       # all green
```
(`dunecho` is the required wrapper; bare `dune`/`dunecho` both need the switch
env. `-j 2` discipline if memory-bound.)

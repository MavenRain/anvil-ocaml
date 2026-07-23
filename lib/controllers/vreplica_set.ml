(* Anvil source: controllers/vreplicaset_controller/trusted/spec_types.rs
   ([VReplicaSetView] and its [implement_resource_view_trait!] instance). Unlike
   StatefulSetView, VReplicaSetView.spec is a BARE VReplicaSetSpecView (not an
   Option) and status is Option<VReplicaSetStatusView>; the selector inside the
   spec is a bare LabelSelectorView. Realised through Resource_view.Make,
   mirroring views/stateful_set.ml. *)

type vrs_spec = {
  replicas : int option;
  selector : Label_selector.t;
  template : Pod_template_spec.t option;
}

type vrs_status = { replicas : int }

type t = {
  metadata : Object_meta.t;
  spec : vrs_spec;
  status : vrs_status option;
}

type spec = vrs_spec
type status = vrs_status option

let kind_name = "vreplicaset"
let kind : Common.kind = Common.Custom_resource kind_name

(* -- VReplicaSetSpecView -- *)
let vrs_spec_default () : vrs_spec =
  { replicas = None; selector = Label_selector.default (); template = None }

let vrs_spec_equal (a : vrs_spec) (b : vrs_spec) : bool =
  Option.equal Int.equal a.replicas b.replicas
  && Label_selector.equal a.selector b.selector
  && Option.equal Pod_template_spec.equal a.template b.template

let vrs_spec_to_json (o : vrs_spec) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("replicas", Json.opt Json.int_ o.replicas);
      ("selector", Some (Label_selector.to_json o.selector));
      ("template", Json.opt Pod_template_spec.to_json o.template);
    ]

let vrs_spec_of_json (j : Yojson.Safe.t) : vrs_spec Res.t =
  let open Res in
  let* replicas = Json.opt_mem j "replicas" Json.to_int in
  let* selector = Json.get j "selector" Label_selector.of_json in
  let* template = Json.opt_mem j "template" Pod_template_spec.of_json in
  ok ({ replicas; selector; template } : vrs_spec)

(* -- VReplicaSetStatusView -- *)
let vrs_status_default () : vrs_status = { replicas = 0 }

let vrs_status_equal (a : vrs_status) (b : vrs_status) : bool =
  Int.equal a.replicas b.replicas

let vrs_status_to_json (o : vrs_status) : Yojson.Safe.t =
  Json.obj [ ("replicas", Json.int_ o.replicas) ]

let vrs_status_of_json (j : Yojson.Safe.t) : vrs_status Res.t =
  let open Res in
  let* replicas = Json.get j "replicas" Json.to_int in
  ok ({ replicas } : vrs_status)

module R = struct
  type nonrec t = t
  type nonrec spec = spec
  type nonrec status = status

  let kind = kind

  let default () : t =
    {
      metadata = Object_meta.default ();
      spec = vrs_spec_default ();
      status = None;
    }

  let metadata (s : t) : Object_meta.t = s.metadata
  let spec (s : t) : spec = s.spec
  let status (s : t) : status = s.status
  let recombine ~metadata ~spec ~status : t = { metadata; spec; status }

  (* VReplicaSetView.spec is bare, so a spec always marshals to a JSON object. *)
  let marshal_spec (s : spec) : Value.t = Value.of_json (vrs_spec_to_json s)

  (* A VReplicaSet always has a spec, so a `Null` (or any non-object) Value is a
     decode error, unlike stateful_set whose spec is optional. *)
  let unmarshal_spec (v : Value.t) : spec Res.t =
    match Value.json v with
    | `Assoc _ as j -> vrs_spec_of_json j
    | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error
        (Err.Decode_error
           { typ = "vreplica_set.spec"; detail = "expected object" })

  let marshal_status (s : status) : Value.t =
    Value.of_json (Option.fold ~none:`Null ~some:vrs_status_to_json s)

  let unmarshal_status (v : Value.t) : status Res.t =
    match Value.json v with
    | `Null -> Res.ok None
    | `Assoc _ as j -> Res.map Option.some (vrs_status_of_json j)
    | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error
        (Err.Decode_error
           { typ = "vreplica_set.status"; detail = "expected object or null" })

  (* spec_types.rs:57 _state_validation: replicas (if present) non-negative; a
     non-empty selector.match_labels; a template with metadata, spec, and labels;
     and the selector matches the template's labels. Each option test uses a
     combinator (fold/is_some), never a two-arm match. *)
  let state_validation (s : t) : bool =
    Option.fold ~none:true ~some:(fun r -> r >= 0) s.spec.replicas
    && Option.is_some s.spec.selector.match_labels
    && Option.fold ~none:false
         ~some:(fun ml -> Smap.cardinal ml > 0)
         s.spec.selector.match_labels
    && Option.is_some s.spec.template
    && Option.fold ~none:false
         ~some:(fun (tmpl : Pod_template_spec.t) ->
           Option.is_some tmpl.metadata
           && Option.is_some tmpl.spec
           && Option.fold ~none:false
                ~some:(fun (tm : Object_meta.t) ->
                  Option.is_some tm.labels
                  && Option.fold ~none:false
                       ~some:(fun labels ->
                         Label_selector.matches s.spec.selector labels)
                       tm.labels)
                tmpl.metadata)
         s.spec.template

  (* spec_types.rs _transition_validation is [true]. *)
  let transition_validation (_ : t) ~old:(_ : t) : bool = true
end

include (
  Resource_view.Make (R) :
    Resource_view.RESOURCE_VIEW
      with type t := t
       and type spec := spec
       and type status := status)

(* spec_types.rs:21 controller_owner_ref. Honest: Anvil unwraps
   metadata.name/metadata.uid under well-formedness; we return None when either
   is absent. *)
let controller_owner_ref (s : t) : Owner_reference.t option =
  Option.bind s.metadata.name (fun name ->
      Option.map
        (fun uid : Owner_reference.t ->
          {
            block_owner_deletion = Some true;
            controller = Some true;
            kind;
            name;
            uid;
          })
        s.metadata.uid)

let make ~metadata ~spec ~status : t = { metadata; spec; status }
let with_metadata metadata (s : t) : t = { s with metadata }
let with_spec spec (s : t) : t = { s with spec }
let with_status status (s : t) : t = { s with status = Some status }

let spec_with_replicas r (sp : vrs_spec) : vrs_spec = { sp with replicas = Some r }
let spec_without_replicas (sp : vrs_spec) : vrs_spec = { sp with replicas = None }
let spec_with_selector selector (sp : vrs_spec) : vrs_spec = { sp with selector }

let spec_with_template template (sp : vrs_spec) : vrs_spec =
  { sp with template = Some template }

let status_with_replicas r (_ : vrs_status) : vrs_status = { replicas = r }

let status_default () : vrs_status = vrs_status_default ()

let equal (a : t) (b : t) : bool =
  Object_meta.equal a.metadata b.metadata
  && vrs_spec_equal a.spec b.spec
  && Option.equal vrs_status_equal a.status b.status

(* Anvil source: kubernetes_api_objects/spec/volume.rs. VolumeView is a struct
   with a plain [name] plus seven optional volume-source fields (Anvil models it
   as a struct-of-options, NOT a Rust enum — verified: volume.rs has no `enum`).
   Each nested source view gets its own <type>_default / <type>_equal /
   <type>_to_json / <type>_of_json; the bare [default]/[equal]/[to_json]/
   [of_json] are VolumeView's. ObjectFieldSelectorView is shared with
   [Container] and lives in [Object_field_selector]. *)

(* volume.rs KeyToPathView. default: key "", path "". *)
type key_to_path = { key : string; path : string }

(* volume.rs ConfigMapProjectionView. default: items/name None. *)
type config_map_projection = {
  items : key_to_path list option;
  name : string option;
}

(* volume.rs SecretProjectionView. Structurally identical to
   ConfigMapProjectionView but a distinct type. *)
type secret_projection = {
  items : key_to_path list option;
  name : string option;
}

(* volume.rs VolumeProjectionView. default: both None. *)
type volume_projection = {
  config_map : config_map_projection option;
  secret : secret_projection option;
}

(* volume.rs ProjectedVolumeSourceView. default: sources None. *)
type projected_volume_source = { sources : volume_projection list option }

(* volume.rs DownwardAPIVolumeFileView. default: field_ref None, path "". *)
type downward_api_volume_file = {
  field_ref : Object_field_selector.t option;
  path : string;
}

(* volume.rs DownwardAPIVolumeSourceView. default: items None. *)
type downward_api_volume_source = {
  items : downward_api_volume_file list option;
}

(* volume.rs HostPathVolumeSourceView. default: path "". *)
type host_path_volume_source = { path : string }

(* volume.rs ConfigMapVolumeSourceView. default: name None. *)
type config_map_volume_source = { name : string option }

(* volume.rs SecretVolumeSourceView. default: secret_name None. *)
type secret_volume_source = { secret_name : string option }

(* volume.rs EmptyDirVolumeSourceView. default: medium/size_limit None. *)
type empty_dir_volume_source = {
  medium : string option;
  size_limit : string option;
}

(* volume.rs PersistentVolumeClaimVolumeSourceView. default: claim_name "",
   read_only None. *)
type persistent_volume_claim_volume_source = {
  claim_name : string;
  read_only : bool option;
}

(* volume.rs VolumeView. 8 fields (name + 7 optional sources). default: name "",
   all sources None. *)
type t = {
  host_path : host_path_volume_source option;
  config_map : config_map_volume_source option;
  name : string;
  projected : projected_volume_source option;
  secret : secret_volume_source option;
  downward_api : downward_api_volume_source option;
  empty_dir : empty_dir_volume_source option;
  persistent_volume_claim : persistent_volume_claim_volume_source option;
}

(* -- KeyToPathView -- *)
let key_to_path_default () : key_to_path = { key = ""; path = "" }

let key_to_path_equal (a : key_to_path) (b : key_to_path) : bool =
  String.equal a.key b.key && String.equal a.path b.path

let key_to_path_to_json (o : key_to_path) : Yojson.Safe.t =
  Json.obj_opt
    [ ("key", Some (Json.str o.key)); ("path", Some (Json.str o.path)) ]

let key_to_path_of_json (j : Yojson.Safe.t) : key_to_path Res.t =
  let open Res in
  let* key = Json.get j "key" Json.to_str in
  let* path = Json.get j "path" Json.to_str in
  ok ({ key; path } : key_to_path)

(* -- ConfigMapProjectionView -- *)
let config_map_projection_default () : config_map_projection =
  { items = None; name = None }

let config_map_projection_equal (a : config_map_projection)
    (b : config_map_projection) : bool =
  Option.equal (List.equal key_to_path_equal) a.items b.items
  && Option.equal String.equal a.name b.name

let config_map_projection_to_json (o : config_map_projection) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("items", Json.opt (Json.list key_to_path_to_json) o.items);
      ("name", Json.opt Json.str o.name);
    ]

let config_map_projection_of_json (j : Yojson.Safe.t) :
    config_map_projection Res.t =
  let open Res in
  let* items = Json.opt_mem j "items" (Json.to_list key_to_path_of_json) in
  let* name = Json.opt_mem j "name" Json.to_str in
  ok ({ items; name } : config_map_projection)

(* -- SecretProjectionView -- *)
let secret_projection_default () : secret_projection =
  { items = None; name = None }

let secret_projection_equal (a : secret_projection) (b : secret_projection) :
    bool =
  Option.equal (List.equal key_to_path_equal) a.items b.items
  && Option.equal String.equal a.name b.name

let secret_projection_to_json (o : secret_projection) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("items", Json.opt (Json.list key_to_path_to_json) o.items);
      ("name", Json.opt Json.str o.name);
    ]

let secret_projection_of_json (j : Yojson.Safe.t) : secret_projection Res.t =
  let open Res in
  let* items = Json.opt_mem j "items" (Json.to_list key_to_path_of_json) in
  let* name = Json.opt_mem j "name" Json.to_str in
  ok ({ items; name } : secret_projection)

(* -- VolumeProjectionView -- *)
let volume_projection_default () : volume_projection =
  { config_map = None; secret = None }

let volume_projection_equal (a : volume_projection) (b : volume_projection) :
    bool =
  Option.equal config_map_projection_equal a.config_map b.config_map
  && Option.equal secret_projection_equal a.secret b.secret

let volume_projection_to_json (o : volume_projection) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("configMap", Json.opt config_map_projection_to_json o.config_map);
      ("secret", Json.opt secret_projection_to_json o.secret);
    ]

let volume_projection_of_json (j : Yojson.Safe.t) : volume_projection Res.t =
  let open Res in
  let* config_map =
    Json.opt_mem j "configMap" config_map_projection_of_json
  in
  let* secret = Json.opt_mem j "secret" secret_projection_of_json in
  ok ({ config_map; secret } : volume_projection)

(* -- ProjectedVolumeSourceView -- *)
let projected_volume_source_default () : projected_volume_source =
  { sources = None }

let projected_volume_source_equal (a : projected_volume_source)
    (b : projected_volume_source) : bool =
  Option.equal (List.equal volume_projection_equal) a.sources b.sources

let projected_volume_source_to_json (o : projected_volume_source) :
    Yojson.Safe.t =
  Json.obj_opt
    [ ("sources", Json.opt (Json.list volume_projection_to_json) o.sources) ]

let projected_volume_source_of_json (j : Yojson.Safe.t) :
    projected_volume_source Res.t =
  let open Res in
  let* sources =
    Json.opt_mem j "sources" (Json.to_list volume_projection_of_json)
  in
  ok ({ sources } : projected_volume_source)

(* -- DownwardAPIVolumeFileView -- *)
let downward_api_volume_file_default () : downward_api_volume_file =
  { field_ref = None; path = "" }

let downward_api_volume_file_equal (a : downward_api_volume_file)
    (b : downward_api_volume_file) : bool =
  Option.equal Object_field_selector.equal a.field_ref b.field_ref
  && String.equal a.path b.path

let downward_api_volume_file_to_json (o : downward_api_volume_file) :
    Yojson.Safe.t =
  Json.obj_opt
    [
      ("fieldRef", Json.opt Object_field_selector.to_json o.field_ref);
      ("path", Some (Json.str o.path));
    ]

let downward_api_volume_file_of_json (j : Yojson.Safe.t) :
    downward_api_volume_file Res.t =
  let open Res in
  let* field_ref = Json.opt_mem j "fieldRef" Object_field_selector.of_json in
  let* path = Json.get j "path" Json.to_str in
  ok ({ field_ref; path } : downward_api_volume_file)

(* -- DownwardAPIVolumeSourceView -- *)
let downward_api_volume_source_default () : downward_api_volume_source =
  { items = None }

let downward_api_volume_source_equal (a : downward_api_volume_source)
    (b : downward_api_volume_source) : bool =
  Option.equal (List.equal downward_api_volume_file_equal) a.items b.items

let downward_api_volume_source_to_json (o : downward_api_volume_source) :
    Yojson.Safe.t =
  Json.obj_opt
    [
      ( "items",
        Json.opt (Json.list downward_api_volume_file_to_json) o.items );
    ]

let downward_api_volume_source_of_json (j : Yojson.Safe.t) :
    downward_api_volume_source Res.t =
  let open Res in
  let* items =
    Json.opt_mem j "items" (Json.to_list downward_api_volume_file_of_json)
  in
  ok ({ items } : downward_api_volume_source)

(* -- HostPathVolumeSourceView -- *)
let host_path_volume_source_default () : host_path_volume_source = { path = "" }

let host_path_volume_source_equal (a : host_path_volume_source)
    (b : host_path_volume_source) : bool =
  String.equal a.path b.path

let host_path_volume_source_to_json (o : host_path_volume_source) :
    Yojson.Safe.t =
  Json.obj_opt [ ("path", Some (Json.str o.path)) ]

let host_path_volume_source_of_json (j : Yojson.Safe.t) :
    host_path_volume_source Res.t =
  let open Res in
  let* path = Json.get j "path" Json.to_str in
  ok ({ path } : host_path_volume_source)

(* -- ConfigMapVolumeSourceView -- *)
let config_map_volume_source_default () : config_map_volume_source =
  { name = None }

let config_map_volume_source_equal (a : config_map_volume_source)
    (b : config_map_volume_source) : bool =
  Option.equal String.equal a.name b.name

let config_map_volume_source_to_json (o : config_map_volume_source) :
    Yojson.Safe.t =
  Json.obj_opt [ ("name", Json.opt Json.str o.name) ]

let config_map_volume_source_of_json (j : Yojson.Safe.t) :
    config_map_volume_source Res.t =
  let open Res in
  let* name = Json.opt_mem j "name" Json.to_str in
  ok ({ name } : config_map_volume_source)

(* -- SecretVolumeSourceView -- *)
let secret_volume_source_default () : secret_volume_source =
  { secret_name = None }

let secret_volume_source_equal (a : secret_volume_source)
    (b : secret_volume_source) : bool =
  Option.equal String.equal a.secret_name b.secret_name

let secret_volume_source_to_json (o : secret_volume_source) : Yojson.Safe.t =
  Json.obj_opt [ ("secretName", Json.opt Json.str o.secret_name) ]

let secret_volume_source_of_json (j : Yojson.Safe.t) : secret_volume_source Res.t
    =
  let open Res in
  let* secret_name = Json.opt_mem j "secretName" Json.to_str in
  ok ({ secret_name } : secret_volume_source)

(* -- EmptyDirVolumeSourceView -- *)
let empty_dir_volume_source_default () : empty_dir_volume_source =
  { medium = None; size_limit = None }

let empty_dir_volume_source_equal (a : empty_dir_volume_source)
    (b : empty_dir_volume_source) : bool =
  Option.equal String.equal a.medium b.medium
  && Option.equal String.equal a.size_limit b.size_limit

let empty_dir_volume_source_to_json (o : empty_dir_volume_source) :
    Yojson.Safe.t =
  Json.obj_opt
    [
      ("medium", Json.opt Json.str o.medium);
      ("sizeLimit", Json.opt Json.str o.size_limit);
    ]

let empty_dir_volume_source_of_json (j : Yojson.Safe.t) :
    empty_dir_volume_source Res.t =
  let open Res in
  let* medium = Json.opt_mem j "medium" Json.to_str in
  let* size_limit = Json.opt_mem j "sizeLimit" Json.to_str in
  ok ({ medium; size_limit } : empty_dir_volume_source)

(* -- PersistentVolumeClaimVolumeSourceView -- *)
let persistent_volume_claim_volume_source_default () :
    persistent_volume_claim_volume_source =
  { claim_name = ""; read_only = None }

let persistent_volume_claim_volume_source_equal
    (a : persistent_volume_claim_volume_source)
    (b : persistent_volume_claim_volume_source) : bool =
  String.equal a.claim_name b.claim_name
  && Option.equal Bool.equal a.read_only b.read_only

let persistent_volume_claim_volume_source_to_json
    (o : persistent_volume_claim_volume_source) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("claimName", Some (Json.str o.claim_name));
      ("readOnly", Json.opt Json.bool_ o.read_only);
    ]

let persistent_volume_claim_volume_source_of_json (j : Yojson.Safe.t) :
    persistent_volume_claim_volume_source Res.t =
  let open Res in
  let* claim_name = Json.get j "claimName" Json.to_str in
  let* read_only = Json.opt_mem j "readOnly" Json.to_bool in
  ok ({ claim_name; read_only } : persistent_volume_claim_volume_source)

(* -- VolumeView -- *)
let default () : t =
  {
    host_path = None;
    config_map = None;
    name = "";
    projected = None;
    secret = None;
    downward_api = None;
    empty_dir = None;
    persistent_volume_claim = None;
  }

let equal (a : t) (b : t) : bool =
  Option.equal host_path_volume_source_equal a.host_path b.host_path
  && Option.equal config_map_volume_source_equal a.config_map b.config_map
  && String.equal a.name b.name
  && Option.equal projected_volume_source_equal a.projected b.projected
  && Option.equal secret_volume_source_equal a.secret b.secret
  && Option.equal downward_api_volume_source_equal a.downward_api b.downward_api
  && Option.equal empty_dir_volume_source_equal a.empty_dir b.empty_dir
  && Option.equal persistent_volume_claim_volume_source_equal
       a.persistent_volume_claim b.persistent_volume_claim

let to_json (o : t) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("hostPath", Json.opt host_path_volume_source_to_json o.host_path);
      ("configMap", Json.opt config_map_volume_source_to_json o.config_map);
      ("name", Some (Json.str o.name));
      ("projected", Json.opt projected_volume_source_to_json o.projected);
      ("secret", Json.opt secret_volume_source_to_json o.secret);
      ( "downwardAPI",
        Json.opt downward_api_volume_source_to_json o.downward_api );
      ("emptyDir", Json.opt empty_dir_volume_source_to_json o.empty_dir);
      ( "persistentVolumeClaim",
        Json.opt persistent_volume_claim_volume_source_to_json
          o.persistent_volume_claim );
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* host_path =
    Json.opt_mem j "hostPath" host_path_volume_source_of_json
  in
  let* config_map =
    Json.opt_mem j "configMap" config_map_volume_source_of_json
  in
  let* name = Json.get j "name" Json.to_str in
  let* projected =
    Json.opt_mem j "projected" projected_volume_source_of_json
  in
  let* secret = Json.opt_mem j "secret" secret_volume_source_of_json in
  let* downward_api =
    Json.opt_mem j "downwardAPI" downward_api_volume_source_of_json
  in
  let* empty_dir = Json.opt_mem j "emptyDir" empty_dir_volume_source_of_json in
  let* persistent_volume_claim =
    Json.opt_mem j "persistentVolumeClaim"
      persistent_volume_claim_volume_source_of_json
  in
  ok
    {
      host_path;
      config_map;
      name;
      projected;
      secret;
      downward_api;
      empty_dir;
      persistent_volume_claim;
    }

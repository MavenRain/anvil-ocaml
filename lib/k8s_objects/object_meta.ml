(* Anvil source: kubernetes_api_objects/spec/object_meta.rs. *)

type t = {
  name : string option;
  generate_name : string option;
  namespace : string option;
  resource_version : Common.Resource_version.t option;
  uid : Common.Uid.t option;
  labels : string Smap.t option;
  annotations : string Smap.t option;
  owner_references : Owner_reference.t list option;
  finalizers : string list option;
  deletion_timestamp : string option;
}

let default () : t =
  {
    name = None;
    generate_name = None;
    namespace = None;
    resource_version = None;
    uid = None;
    labels = None;
    annotations = None;
    owner_references = None;
    finalizers = None;
    deletion_timestamp = None;
  }

let name (m : t) : string option = m.name
let namespace (m : t) : string option = m.namespace
let with_name name m = { m with name = Some name }
let with_generate_name generate_name m = { m with generate_name = Some generate_name }
let with_namespace namespace m = { m with namespace = Some namespace }
let with_labels labels m = { m with labels = Some labels }

let add_label key value m =
  let old_map = Option.value ~default:Smap.empty m.labels in
  { m with labels = Some (Smap.add key value old_map) }

let without_label key m =
  Option.fold ~none:m
    ~some:(fun labels -> { m with labels = Some (Smap.remove key labels) })
    m.labels

let without_labels m = { m with labels = None }
let with_annotations annotations m = { m with annotations = Some annotations }
let without_annotations m = { m with annotations = None }

let add_annotation key value m =
  let old_map = Option.value ~default:Smap.empty m.annotations in
  { m with annotations = Some (Smap.add key value old_map) }

let with_resource_version resource_version m =
  { m with resource_version = Some resource_version }

let without_resource_version m = { m with resource_version = None }

let with_owner_references owner_references m =
  { m with owner_references = Some owner_references }

let with_finalizers finalizers m = { m with finalizers = Some finalizers }
let without_finalizers m = { m with finalizers = None }

let with_deletion_timestamp deletion_timestamp m =
  { m with deletion_timestamp = Some deletion_timestamp }

let without_deletion_timestamp m = { m with deletion_timestamp = None }

let owner_references_contains (m : t) (r : Owner_reference.t) : bool =
  Option.fold ~none:false
    ~some:(fun refs -> List.exists (Owner_reference.equal r) refs)
    m.owner_references

let owner_references_only_contains (m : t) (r : Owner_reference.t) : bool =
  Option.fold ~none:false
    ~some:(fun refs -> List.equal Owner_reference.equal refs [ r ])
    m.owner_references

let finalizers_as_set (m : t) : Sset.t =
  Option.fold ~none:Sset.empty ~some:Sset.of_list m.finalizers

let well_formed_for_namespaced (m : t) : bool =
  Option.is_some m.name
  && Option.is_some m.namespace
  && Option.is_some m.resource_version
  && Option.is_some m.uid

let equal (a : t) (b : t) : bool =
  Option.equal String.equal a.name b.name
  && Option.equal String.equal a.generate_name b.generate_name
  && Option.equal String.equal a.namespace b.namespace
  && Option.equal Common.Resource_version.equal a.resource_version
       b.resource_version
  && Option.equal Common.Uid.equal a.uid b.uid
  && Option.equal (Smap.equal String.equal) a.labels b.labels
  && Option.equal (Smap.equal String.equal) a.annotations b.annotations
  && Option.equal (List.equal Owner_reference.equal) a.owner_references
       b.owner_references
  && Option.equal (List.equal String.equal) a.finalizers b.finalizers
  && Option.equal String.equal a.deletion_timestamp b.deletion_timestamp

let to_json (m : t) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("name", Json.opt Json.str m.name);
      ("generateName", Json.opt Json.str m.generate_name);
      ("namespace", Json.opt Json.str m.namespace);
      ( "resourceVersion",
        Json.opt
          (fun rv -> Json.int_ (Common.Resource_version.to_int rv))
          m.resource_version );
      ("uid", Json.opt (fun u -> Json.int_ (Common.Uid.to_int u)) m.uid);
      ("labels", Json.opt Json.smap m.labels);
      ("annotations", Json.opt Json.smap m.annotations);
      ( "ownerReferences",
        Json.opt (Json.list Owner_reference.to_json) m.owner_references );
      ("finalizers", Json.opt (Json.list Json.str) m.finalizers);
      ("deletionTimestamp", Json.opt Json.str m.deletion_timestamp);
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* name = Json.opt_mem j "name" Json.to_str in
  let* generate_name = Json.opt_mem j "generateName" Json.to_str in
  let* namespace = Json.opt_mem j "namespace" Json.to_str in
  let* resource_version =
    Json.opt_mem j "resourceVersion" (fun v ->
        map Common.Resource_version.of_int (Json.to_int v))
  in
  let* uid =
    Json.opt_mem j "uid" (fun v -> map Common.Uid.of_int (Json.to_int v))
  in
  let* labels = Json.opt_mem j "labels" Json.to_smap in
  let* annotations = Json.opt_mem j "annotations" Json.to_smap in
  let* owner_references =
    Json.opt_mem j "ownerReferences" (Json.to_list Owner_reference.of_json)
  in
  let* finalizers = Json.opt_mem j "finalizers" (Json.to_list Json.to_str) in
  let* deletion_timestamp = Json.opt_mem j "deletionTimestamp" Json.to_str in
  ok
    {
      name;
      generate_name;
      namespace;
      resource_version;
      uid;
      labels;
      annotations;
      owner_references;
      finalizers;
      deletion_timestamp;
    }

(* Anvil source: kubernetes_api_objects/spec/dynamic.rs. *)

type t = {
  kind : Common.kind;
  metadata : Object_meta.t;
  spec : Value.t;
  status : Value.t;
}

let make ~kind ~metadata ~spec ~status = { kind; metadata; spec; status }
let kind (d : t) : Common.kind = d.kind
let metadata (d : t) : Object_meta.t = d.metadata
let spec (d : t) : Value.t = d.spec
let status (d : t) : Value.t = d.status

let object_ref (d : t) : Common.object_ref Res.t =
  let open Res in
  let m = d.metadata in
  let* name =
    of_option
      ~none:(Err.Missing_field { owner = "metadata"; field = "name" })
      (Object_meta.name m)
  and* namespace =
    of_option
      ~none:(Err.Missing_field { owner = "metadata"; field = "namespace" })
      (Object_meta.namespace m)
  in
  ok { Common.kind = d.kind; name; namespace }

let with_metadata metadata d = { d with metadata }

let with_name name d =
  { d with metadata = Object_meta.with_name name d.metadata }

let with_namespace namespace d =
  { d with metadata = Object_meta.with_namespace namespace d.metadata }

let with_resource_version resource_version d =
  {
    d with
    metadata = Object_meta.with_resource_version resource_version d.metadata;
  }

(* ObjectMetaView has no with_uid builder in Anvil; dynamic.rs sets the field
   directly, so we mirror that with a record update on the metadata. *)
let with_uid uid d =
  { d with metadata = { d.metadata with Object_meta.uid = Some uid } }

let with_deletion_timestamp deletion_timestamp d =
  {
    d with
    metadata =
      Object_meta.with_deletion_timestamp deletion_timestamp d.metadata;
  }

let equal (a : t) (b : t) : bool =
  Common.equal_kind a.kind b.kind
  && Object_meta.equal a.metadata b.metadata
  && Value.equal a.spec b.spec
  && Value.equal a.status b.status

let to_json (d : t) : Yojson.Safe.t =
  Json.obj
    [
      ("kind", Json.kind_to_json d.kind);
      ("metadata", Object_meta.to_json d.metadata);
      ("spec", Value.json d.spec);
      ("status", Value.json d.status);
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* kind = Json.get j "kind" Json.kind_of_json in
  let* metadata = Json.get j "metadata" Object_meta.of_json in
  let* spec = Json.mem j "spec" in
  let* status = Json.mem j "status" in
  ok { kind; metadata; spec = Value.of_json spec; status = Value.of_json status }

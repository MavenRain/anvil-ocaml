(* Anvil source: kubernetes_api_objects/spec/pod_template_spec.rs
   [PodTemplateSpecView] (pod_template_spec.rs:8). Both fields optional (note
   [metadata] is Option here, unlike PodView.metadata which is bare). Shared by
   [Stateful_set] (StatefulSetSpecView.template). *)

type t = {
  metadata : Object_meta.t option;
  spec : Pod_spec.t option;
}

let default () : t = { metadata = None; spec = None }

let equal (a : t) (b : t) : bool =
  Option.equal Object_meta.equal a.metadata b.metadata
  && Option.equal Pod_spec.equal a.spec b.spec

let to_json (o : t) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("metadata", Json.opt Object_meta.to_json o.metadata);
      ("spec", Json.opt Pod_spec.to_json o.spec);
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* metadata = Json.opt_mem j "metadata" Object_meta.of_json in
  let* spec = Json.opt_mem j "spec" Pod_spec.of_json in
  ok { metadata; spec }

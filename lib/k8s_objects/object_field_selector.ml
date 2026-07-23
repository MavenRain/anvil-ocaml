(* Anvil source: kubernetes_api_objects/spec/volume.rs [ObjectFieldSelectorView].
   Shared between [Container] (EnvVarSourceView.field_ref) and [Volume]
   (DownwardAPIVolumeFileView.field_ref), hence its own module. *)

type t = { field_path : string; api_version : string option }

let default () : t = { field_path = ""; api_version = None }

let equal (a : t) (b : t) : bool =
  String.equal a.field_path b.field_path
  && Option.equal String.equal a.api_version b.api_version

let to_json (o : t) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("fieldPath", Some (Json.str o.field_path));
      ("apiVersion", Json.opt Json.str o.api_version);
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* field_path = Json.get j "fieldPath" Json.to_str in
  let* api_version = Json.opt_mem j "apiVersion" Json.to_str in
  ok { field_path; api_version }

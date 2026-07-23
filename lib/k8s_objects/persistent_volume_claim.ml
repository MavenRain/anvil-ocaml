(* Anvil source: kubernetes_api_objects/spec/persistent_volume_claim.rs
   [PersistentVolumeClaimView] + spec + status. Anvil also registers PVC as a
   ResourceView, but Phase 1 needs it only as a nested value inside
   StatefulSetSpecView.volume_claim_templates, so it is ported as a plain record
   module (no functor instance). Status is EmptyStatusView (unit).

   [status_*] name the unit status codec; [spec_*] the PVC spec; the bare
   [default]/[equal]/[to_json]/[of_json] are PersistentVolumeClaimView's. *)

(* PersistentVolumeClaimSpecView. All three fields optional. *)
type spec = {
  storage_class_name : string option;
  access_modes : string list option;
  resources : Volume_resource_requirements.t option;
}

(* PersistentVolumeClaimStatusView = EmptyStatusView (unit). *)
type status = unit

(* PersistentVolumeClaimView: bare metadata + optional spec/status. *)
type t = {
  metadata : Object_meta.t;
  spec : spec option;
  status : status option;
}

(* -- PersistentVolumeClaimSpecView -- *)
let spec_default () : spec =
  { storage_class_name = None; access_modes = None; resources = None }

let spec_equal (a : spec) (b : spec) : bool =
  Option.equal String.equal a.storage_class_name b.storage_class_name
  && Option.equal (List.equal String.equal) a.access_modes b.access_modes
  && Option.equal Volume_resource_requirements.equal a.resources b.resources

let spec_to_json (o : spec) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("storageClassName", Json.opt Json.str o.storage_class_name);
      ("accessModes", Json.opt (Json.list Json.str) o.access_modes);
      ("resources", Json.opt Volume_resource_requirements.to_json o.resources);
    ]

let spec_of_json (j : Yojson.Safe.t) : spec Res.t =
  let open Res in
  let* storage_class_name = Json.opt_mem j "storageClassName" Json.to_str in
  let* access_modes =
    Json.opt_mem j "accessModes" (Json.to_list Json.to_str)
  in
  let* resources =
    Json.opt_mem j "resources" Volume_resource_requirements.of_json
  in
  ok ({ storage_class_name; access_modes; resources } : spec)

(* -- PersistentVolumeClaimStatusView (unit) -- *)
let status_default () : status = ()
let status_equal (_ : status) (_ : status) : bool = true
let status_to_json (_ : status) : Yojson.Safe.t = `Assoc []

(* A present ghost value marshals to an object, so decoding shape-checks for one
   (rejecting every other JSON constructor) rather than accepting any JSON. *)
let status_of_json (j : Yojson.Safe.t) : status Res.t =
  match j with
  | `Assoc _ -> Res.ok ()
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
    Res.error
      (Err.Decode_error
         { typ = "PersistentVolumeClaimStatus"; detail = "expected an object" })

(* -- PersistentVolumeClaimView -- *)
let default () : t =
  { metadata = Object_meta.default (); spec = None; status = None }

let equal (a : t) (b : t) : bool =
  Object_meta.equal a.metadata b.metadata
  && Option.equal spec_equal a.spec b.spec
  && Option.equal status_equal a.status b.status

let to_json (o : t) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("metadata", Some (Object_meta.to_json o.metadata));
      ("spec", Json.opt spec_to_json o.spec);
      ("status", Json.opt status_to_json o.status);
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* metadata = Json.get j "metadata" Object_meta.of_json in
  let* spec = Json.opt_mem j "spec" spec_of_json in
  let* status = Json.opt_mem j "status" status_of_json in
  ok { metadata; spec; status }

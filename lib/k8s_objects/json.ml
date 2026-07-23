(* Anvil source: serde_json marshalling in Anvil's exec layer. OCaml codec
   helpers over Yojson.Safe.t. Every decoder is exhaustive over the ten
   Yojson.Safe.t constructors — no [_ ->] catch-all — so a shape mismatch is a
   total {!Err.Decode_error} branch. *)

let str s : Yojson.Safe.t = `String s
let int_ n : Yojson.Safe.t = `Int n
let bool_ b : Yojson.Safe.t = `Bool b
let obj members : Yojson.Safe.t = `Assoc members
let list f xs : Yojson.Safe.t = `List (List.map f xs)
let smap m : Yojson.Safe.t = `Assoc (List.map (fun (k, v) -> (k, `String v)) (Smap.bindings m))
let opt f = Option.map f

let obj_opt members : Yojson.Safe.t =
  `Assoc (List.filter_map (fun (k, vo) -> Option.map (fun v -> (k, v)) vo) members)

let kind_to_json (k : Common.kind) : Yojson.Safe.t =
  match k with
  | Config_map -> `String "ConfigMap"
  | Custom_resource s -> `Assoc [ ("customResource", `String s) ]
  | Daemon_set -> `String "DaemonSet"
  | Persistent_volume_claim -> `String "PersistentVolumeClaim"
  | Pod -> `String "Pod"
  | Role -> `String "Role"
  | Role_binding -> `String "RoleBinding"
  | Stateful_set -> `String "StatefulSet"
  | Service -> `String "Service"
  | Service_account -> `String "ServiceAccount"
  | Secret -> `String "Secret"

let decode_error typ detail = Res.error (Err.Decode_error { typ; detail })

let to_str (j : Yojson.Safe.t) : string Res.t =
  match j with
  | `String s -> Res.ok s
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `Assoc _ | `List _ ->
    decode_error "string" "expected a JSON string"

let to_int (j : Yojson.Safe.t) : int Res.t =
  match j with
  | `Int n -> Res.ok n
  | `Null | `Bool _ | `Intlit _ | `Float _ | `String _ | `Assoc _ | `List _ ->
    decode_error "int" "expected a JSON integer"

let to_bool (j : Yojson.Safe.t) : bool Res.t =
  match j with
  | `Bool b -> Res.ok b
  | `Null | `Int _ | `Intlit _ | `Float _ | `String _ | `Assoc _ | `List _ ->
    decode_error "bool" "expected a JSON boolean"

let as_obj (j : Yojson.Safe.t) : (string * Yojson.Safe.t) list Res.t =
  match j with
  | `Assoc members -> Res.ok members
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
    decode_error "object" "expected a JSON object"

let mem (j : Yojson.Safe.t) (field : string) : Yojson.Safe.t Res.t =
  let open Res in
  let* members = as_obj j in
  of_option ~none:(Err.Missing_field { owner = "json"; field }) (List.assoc_opt field members)

let get j field f = Res.bind (mem j field) f

let opt_mem (j : Yojson.Safe.t) (field : string) (f : Yojson.Safe.t -> 'a Res.t) :
    'a option Res.t =
  let open Res in
  let* members = as_obj j in
  let decode (v : Yojson.Safe.t) : 'a option Res.t =
    match v with
    | `Null -> ok None
    | ( `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `Assoc _
      | `List _ ) as present ->
      map Option.some (f present)
  in
  List.assoc_opt field members
  |> Option.map decode
  |> Option.value ~default:(ok None)

let to_list (f : Yojson.Safe.t -> 'a Res.t) (j : Yojson.Safe.t) : 'a list Res.t =
  match j with
  | `List xs -> Res.map_m f xs
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `Assoc _ ->
    decode_error "list" "expected a JSON array"

let to_smap (j : Yojson.Safe.t) : string Smap.t Res.t =
  let open Res in
  let* members = as_obj j in
  fold_m
    (fun acc (k, v) -> map (fun s -> Smap.add k s acc) (to_str v))
    Smap.empty members

let kind_of_tag (tag : string) : Common.kind Res.t =
  match tag with
  | "ConfigMap" -> Res.ok Common.Config_map
  | "DaemonSet" -> Res.ok Common.Daemon_set
  | "PersistentVolumeClaim" -> Res.ok Common.Persistent_volume_claim
  | "Pod" -> Res.ok Common.Pod
  | "Role" -> Res.ok Common.Role
  | "RoleBinding" -> Res.ok Common.Role_binding
  | "StatefulSet" -> Res.ok Common.Stateful_set
  | "Service" -> Res.ok Common.Service
  | "ServiceAccount" -> Res.ok Common.Service_account
  | "Secret" -> Res.ok Common.Secret
  | other -> decode_error "kind" ("unknown kind tag: " ^ other)

let kind_of_json (j : Yojson.Safe.t) : Common.kind Res.t =
  match j with
  | `String tag -> kind_of_tag tag
  | `Assoc [ ("customResource", `String s) ] -> Res.ok (Common.Custom_resource s)
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `Assoc _ | `List _ ->
    decode_error "kind" "unrecognized kind encoding"

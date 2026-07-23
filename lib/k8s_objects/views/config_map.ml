(* Anvil source: kubernetes_api_objects/spec/config_map.rs. The ConfigMapView
   ResourceView instance, realised through {!Resource_view.Make}. *)

type t = { metadata : Object_meta.t; data : string Smap.t option }
type spec = string Smap.t option
type status = unit

module R = struct
  type nonrec t = t
  type nonrec spec = spec
  type nonrec status = status

  let kind = Common.Config_map
  let default () : t = { metadata = Object_meta.default (); data = None }
  let metadata (c : t) : Object_meta.t = c.metadata
  let spec (c : t) : spec = c.data
  let status (_ : t) : status = ()
  let recombine ~metadata ~spec ~status:_ = { metadata; data = spec }

  let marshal_spec (s : spec) : Value.t =
    Value.of_json (Option.fold ~none:`Null ~some:Json.smap s)

  let unmarshal_spec (v : Value.t) : spec Res.t =
    match Value.json v with
    | `Null -> Res.ok None
    | `Assoc _ as j -> Res.map Option.some (Json.to_smap j)
    | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error
        (Err.Decode_error
           { typ = "config_map.data"; detail = "expected object or null" })

  let marshal_status (_ : status) : Value.t = Value.of_json `Null

  let unmarshal_status (v : Value.t) : status Res.t =
    match Value.json v with
    | `Null -> Res.ok ()
    | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `Assoc _ | `List _
      ->
      Res.error
        (Err.Decode_error
           { typ = "config_map.status"; detail = "expected null" })

  let state_validation (_ : t) : bool = true
  let transition_validation (_ : t) ~old:(_ : t) : bool = true
end

include (
  Resource_view.Make (R) :
    Resource_view.RESOURCE_VIEW
      with type t := t
       and type spec := spec
       and type status := status)

let make ~metadata ~data = { metadata; data }
let with_metadata metadata c = { c with metadata }
let with_data data c = { c with data = Some data }
let data (c : t) : spec = c.data

let equal (a : t) (b : t) : bool =
  Object_meta.equal a.metadata b.metadata
  && Option.equal (Smap.equal String.equal) a.data b.data

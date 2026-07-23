(* Anvil source: kubernetes_api_objects/spec/pod.rs. The PodView ResourceView
   instance, realised through {!Resource_view.Make}. PodSpecView lives in
   [Pod_spec] (shared with [Pod_template_spec]); PodStatusView is EmptyStatusView
   (unit). *)

type t = {
  metadata : Object_meta.t;
  spec : Pod_spec.t option;
  status : unit option;
}

type spec = Pod_spec.t option
type status = unit option

module R = struct
  type nonrec t = t
  type nonrec spec = spec
  type nonrec status = status

  let kind = Common.Pod

  let default () : t =
    { metadata = Object_meta.default (); spec = None; status = None }

  let metadata (p : t) : Object_meta.t = p.metadata
  let spec (p : t) : spec = p.spec
  let status (p : t) : status = p.status
  let recombine ~metadata ~spec ~status : t = { metadata; spec; status }

  let marshal_spec (s : spec) : Value.t =
    Value.of_json (Option.fold ~none:`Null ~some:Pod_spec.to_json s)

  let unmarshal_spec (v : Value.t) : spec Res.t =
    match Value.json v with
    | `Null -> Res.ok None
    | `Assoc _ as j -> Res.map Option.some (Pod_spec.of_json j)
    | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error
        (Err.Decode_error
           { typ = "pod.spec"; detail = "expected object or null" })

  (* PodStatusView = unit; [Some ()] marshals to an empty object (never `Null`)
     so the drop-`None` round-trip distinguishes [Some ()] from [None]. *)
  let marshal_status (s : status) : Value.t =
    Value.of_json (Option.fold ~none:`Null ~some:(fun () -> `Assoc []) s)

  let unmarshal_status (v : Value.t) : status Res.t =
    match Value.json v with
    | `Null -> Res.ok None
    | `Assoc _ -> Res.ok (Some ())
    | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error
        (Err.Decode_error
           { typ = "pod.status"; detail = "expected object or null" })

  (* pod.rs:40 _state_validation: self.spec is Some. *)
  let state_validation (p : t) : bool = Option.is_some p.spec

  (* pod.rs:45 _transition_validation: true. *)
  let transition_validation (_ : t) ~old:(_ : t) : bool = true
end

include (
  Resource_view.Make (R) :
    Resource_view.RESOURCE_VIEW
      with type t := t
       and type spec := spec
       and type status := status)

let make ~metadata ~spec ~status : t = { metadata; spec; status }
let with_metadata metadata (p : t) : t = { p with metadata }
let with_spec spec (p : t) : t = { p with spec = Some spec }

let equal (a : t) (b : t) : bool =
  Object_meta.equal a.metadata b.metadata
  && Option.equal Pod_spec.equal a.spec b.spec
  && Option.equal (fun (_ : unit) (_ : unit) -> true) a.status b.status

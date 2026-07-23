(* Anvil source: kubernetes_api_objects/spec/affinity.rs [AffinityView].
   A ghost placeholder struct `{}` (Anvil models Affinity's presence but no
   fields); ported as the unit/empty type. Referenced by PodSpecView.affinity. *)

type t = unit

let default () : t = ()
let equal (_ : t) (_ : t) : bool = true

(* Marshalled as an empty object (never `Null`): an optional AffinityView field
   must survive the drop-`None` round-trip as `Some ()`, so its present value
   cannot itself decode as absent. *)
let to_json (_ : t) : Yojson.Safe.t = `Assoc []

(* A present ghost value marshals to an object, so decoding shape-checks for one
   (rejecting every other JSON constructor) rather than accepting any JSON. *)
let of_json (j : Yojson.Safe.t) : t Res.t =
  match j with
  | `Assoc _ -> Res.ok ()
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
    Res.error (Err.Decode_error { typ = "Affinity"; detail = "expected an object" })

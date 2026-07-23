(* Anvil source: kubernetes_api_objects/spec/toleration.rs [TolerationView].
   A ghost placeholder struct `{}`; ported as the unit/empty type. Referenced by
   PodSpecView.tolerations as Seq<TolerationView>. *)

type t = unit

let default () : t = ()
let equal (_ : t) (_ : t) : bool = true
let to_json (_ : t) : Yojson.Safe.t = `Assoc []

(* A present ghost value marshals to an object, so decoding shape-checks for one
   (rejecting every other JSON constructor) rather than accepting any JSON. *)
let of_json (j : Yojson.Safe.t) : t Res.t =
  match j with
  | `Assoc _ -> Res.ok ()
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
    Res.error
      (Err.Decode_error { typ = "Toleration"; detail = "expected an object" })

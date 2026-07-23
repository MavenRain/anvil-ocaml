(* Anvil source: kubernetes_api_objects/spec/dynamic.rs [Value]. The carrier is
   a Yojson.Safe.t. [of_string] holds the single, sanctioned [try/with] in the
   whole library, quarantining yojson's exception-based parser. *)

type t = Yojson.Safe.t

let of_json j = j
let json t = t
let to_string t = Yojson.Safe.to_string t

let of_string s : t Res.t =
  try Res.ok (Yojson.Safe.from_string s)
  with Yojson.Json_error detail ->
    Res.error (Err.Malformed_value { kind = "Value"; detail })

(* Anvil's [Value = StringView] is an ordered char sequence, so equality is
   order-SENSITIVE. [Yojson.Safe.to_string] preserves [`Assoc] key order, so
   comparing the rendered strings honours that ordering (unlike
   [Yojson.Safe.equal], which treats objects as unordered key sets). *)
let equal a b = String.equal (to_string a) (to_string b)

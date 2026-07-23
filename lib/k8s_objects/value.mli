(** Anvil source: kubernetes_api_objects/spec/dynamic.rs uses [Value] as the
    type of a [DynamicObjectView]'s marshalled spec/status. Anvil leaves [Value]
    ([= StringView]) and its per-type marshal/unmarshal uninterpreted, discharging
    the round-trip by proof; its exec model marshals through serde_json. We make
    the faithful choice and carry a {!Yojson.Safe.t}, with a string bridge. *)

type t
(** The marshalled-value carrier, wrapping a {!Yojson.Safe.t}. *)

val of_json : Yojson.Safe.t -> t
(** Wrap a JSON value. *)

val json : t -> Yojson.Safe.t
(** The underlying JSON value. *)

val to_string : t -> string
(** [Yojson.Safe.to_string]; total (Anvil's [Value] is a [StringView]). *)

val of_string : string -> t Res.t
(** Parse a string into a value; the sole [try/with] in the library quarantines
    yojson's exception-based parser, surfacing failure as {!Err.Malformed_value}. *)

val equal : t -> t -> bool
(** Order-SENSITIVE equality, mirroring Anvil's [Value = StringView] (an ordered
    char sequence): compares the rendered strings so [`Assoc] key order is
    significant, unlike [Yojson.Safe.equal]'s unordered key-set comparison. *)

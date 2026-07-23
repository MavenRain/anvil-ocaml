(** Anvil source: none directly. Anvil marshals objects with serde_json in its
    exec layer (kubernetes_api_objects/exec); this module is the OCaml codec
    hub that plays that role for the spec port, over {!Yojson.Safe.t}. Encoders
    are total; decoders return {!Res.t} with {!Err.Decode_error} /
    {!Err.Missing_field}. Optionals are dropped when [None] rather than emitted
    as null, and read back as absent. *)

(** [`String]. *)
val str : string -> Yojson.Safe.t

(** [`Int]. *)
val int_ : int -> Yojson.Safe.t

(** [`Bool]. *)
val bool_ : bool -> Yojson.Safe.t

(** [`Assoc] of already-built members. *)
val obj : (string * Yojson.Safe.t) list -> Yojson.Safe.t

(** [`List] over an element encoder (mirrors a [Seq<T>] marshal). *)
val list : ('a -> Yojson.Safe.t) -> 'a list -> Yojson.Safe.t

(** [`Assoc] of a [string Smap.t] with keys in sorted order (deterministic
    round-trip for [Map<StringView, StringView>]). *)
val smap : string Smap.t -> Yojson.Safe.t

(** Discriminant encoding of {!Common.kind} (spec/common.rs [Kind]): nullary
    kinds as a tag string, [Custom_resource] as [{"customResource": name}]. *)
val kind_to_json : Common.kind -> Yojson.Safe.t

(** Lift an element encoder over an option; [None] becomes [None] so the field
    can be dropped by {!obj_opt}. *)
val opt : ('a -> Yojson.Safe.t) -> 'a option -> Yojson.Safe.t option

(** Build an [`Assoc], dropping members whose value is [None] (absent-optional
    semantics: omit rather than emit null). *)
val obj_opt : (string * Yojson.Safe.t option) list -> Yojson.Safe.t

(** Decode a [`String]. *)
val to_str : Yojson.Safe.t -> string Res.t

(** Decode an [`Int]. *)
val to_int : Yojson.Safe.t -> int Res.t

(** Decode a [`Bool]. *)
val to_bool : Yojson.Safe.t -> bool Res.t

(** A required member of an [`Assoc]; {!Err.Missing_field} when absent. *)
val mem : Yojson.Safe.t -> string -> Yojson.Safe.t Res.t

(** A required member decoded by [f] (composition of {!mem} and a decoder). *)
val get : Yojson.Safe.t -> string -> (Yojson.Safe.t -> 'a Res.t) -> 'a Res.t

(** An optional member: absent or [`Null] gives [Ok None]; otherwise decode by
    [f] and wrap [Some]. *)
val opt_mem :
  Yojson.Safe.t -> string -> (Yojson.Safe.t -> 'a Res.t) -> 'a option Res.t

(** Decode a [`List] elementwise (first error wins). *)
val to_list : (Yojson.Safe.t -> 'a Res.t) -> Yojson.Safe.t -> 'a list Res.t

(** Decode an [`Assoc] of strings into a [string Smap.t]. *)
val to_smap : Yojson.Safe.t -> string Smap.t Res.t

(** Decode a {!Common.kind} produced by {!kind_to_json}. *)
val kind_of_json : Yojson.Safe.t -> Common.kind Res.t

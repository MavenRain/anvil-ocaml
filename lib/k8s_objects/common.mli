(** Anvil source: kubernetes_api_objects/spec/common.rs.

    The primitive identifiers and the closed set of object kinds. Anvil makes
    [Uid], [ResourceVersion] and [GenerateNameCounter] Verus [int] "so that it
    is easy to compare in spec/proof"; we mirror that with distinct abstract
    newtypes over [int] so the three cannot be confused at a call site, while
    keeping OCaml's [int] as the carrier (the values are counters, never
    arithmetic operands in the model). *)

module Uid : sig
  type t
  val of_int : int -> t
  val to_int : t -> int
  val equal : t -> t -> bool
end

module Resource_version : sig
  type t
  val of_int : int -> t
  val to_int : t -> int
  val equal : t -> t -> bool
end

module Generate_name_counter : sig
  type t
  val of_int : int -> t
  val to_int : t -> int
  val equal : t -> t -> bool
end

(** The eleven object kinds. [Custom_resource] is the sole payload-carrying
    variant (Anvil: [CustomResourceKind(StringView)]); the other ten are
    nullary. Order matches the Rust enum. Matched exhaustively everywhere:
    no [_ ->] catch-all. *)
type kind =
  | Config_map
  | Custom_resource of string
  | Daemon_set
  | Persistent_volume_claim
  | Pod
  | Role
  | Role_binding
  | Stateful_set
  | Service
  | Service_account
  | Secret

val equal_kind : kind -> kind -> bool

(** A stable, human-readable tag for a kind; used in error payloads and as the
    JSON discriminant, never parsed back into arithmetic. *)
val show_kind : kind -> string

(** Anvil: [ObjectRef { kind, name, namespace }] — the [StoredState] map key.
    [name]/[namespace] are plain strings here (Anvil's [StringView]); a
    [DynamicObject]/view whose metadata lacks either cannot form an
    [object_ref], which is surfaced as {!Err.Missing_field}, not a partial
    unwrap. *)
type object_ref = { kind : kind; name : string; namespace : string }

val equal_object_ref : object_ref -> object_ref -> bool

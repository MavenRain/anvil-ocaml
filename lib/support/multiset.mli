(** Anvil source: [vstd::multiset::Multiset<T>], the bag the cluster network
    uses for its in-flight message pool ([NetworkState.in_flight]) and the
    [MessageOps.send] batch.

    A multiset is an unordered collection with multiplicities. Anvil relies on
    exactly two facts the network transition needs: a message can be present
    more than once (two identical requests in flight are two deliverable
    messages), and delivery removes {e one} occurrence. Order carries no
    meaning; {!equal} is multiplicity equality, never list equality. Made a
    functor over an element with structural equality (mirroring {!Smap} =
    [Map.Make (String)]) so the network instantiates [Make (Message)]. *)

module type ELEMENT = sig
  type t

  val equal : t -> t -> bool
end

module Make (E : ELEMENT) : sig
  type elt = E.t

  (** A bag of [elt]s; [equal]-equal elements share a multiplicity. Abstract so
      no caller depends on the underlying order. *)
  type t

  (** The empty multiset (Anvil [Multiset::empty]). *)
  val empty : t

  (** [singleton x] (Anvil [Multiset::singleton]); one occurrence of [x]. *)
  val singleton : elt -> t

  (** [is_empty m]: no occurrences at all. *)
  val is_empty : t -> bool

  (** [add x m] (Anvil [m.insert(x)]): add one occurrence of [x]. *)
  val add : elt -> t -> t

  (** [union a b] (Anvil [a.add(b)]): pointwise multiplicity sum; used to fold a
      [send] batch into the pool. *)
  val union : t -> t -> t

  (** [remove_one x m] (Anvil [m.remove(x)] under a [contains] guard): drop a
      single occurrence of [x], or [None] when [x] is absent — the network
      [deliver] precondition is exactly this [Some]. *)
  val remove_one : elt -> t -> t option

  (** [mem x m] (Anvil [m.contains(x)]): at least one occurrence. *)
  val mem : elt -> t -> bool

  (** [count x m] (Anvil [m.count(x)]): the multiplicity of [x]. *)
  val count : elt -> t -> int

  (** Total number of occurrences (Anvil [m.len()]); a bound target. *)
  val cardinal : t -> int

  (** One representative per distinct element; the candidate set the successor
      enumeration draws a [recv] message from (each is deliverable). *)
  val distinct : t -> elt list

  (** All occurrences as a list, order unspecified (Anvil [m.dom] flattened);
      for diagnostics and enumeration, never for equality. *)
  val to_list : t -> elt list

  (** [of_list xs]: the bag with each element of [xs] added once. *)
  val of_list : elt list -> t

  (** Multiplicity equality: same distinct elements with the same counts,
      independent of insertion order (Anvil [Multiset] extensional equality). *)
  val equal : t -> t -> bool
end

(** Anvil source: kubernetes_api_objects/spec/resource.rs (the [ResourceView]
    trait and the [implement_resource_view_trait!] macro).

    This functor {b is} the OCaml realisation of that macro. Anvil's macro takes
    a resource's own projections ([spec], [status], per-type [marshal_spec] /
    [unmarshal_spec] / [marshal_status] / [unmarshal_status], [kind],
    [state_validation], [transition_validation]) and derives the uniform
    surface: [object_ref], [marshal], [unmarshal], and the [default] assembly.
    {!Make} does exactly this — the derived members live in one place instead of
    being re-expanded per type.

    Anvil's four [marshal_preserves_*] obligations are {e proofs}; OCaml carries
    no prover, so they downgrade to the QCheck round-trip properties in the test
    suite ([unmarshal (marshal o) = Ok o], and the same for spec/status). They
    are therefore absent from this contract by design, not by omission. *)

(** The per-resource atom a caller supplies: everything the Anvil macro cannot
    derive. The uninterpreted-in-spec [marshal_spec]/[unmarshal_spec] pair
    becomes a concrete, total codec here (see {!Value}); [unmarshal_spec] and
    [unmarshal_status] return {!Res.t} because a marshalled {!Value} can be
    malformed — the failure branch Anvil discharges by proof. *)
module type RESOURCE = sig
  type t
      (** the typed view (e.g. a pod view: metadata + spec + status). *)

  type spec
  type status

  val kind : Common.kind
  val default : unit -> t
  val metadata : t -> Object_meta.t
  val spec : t -> spec
  val status : t -> status

  (** The inverse of the three projections, used by the derived [unmarshal].
      Anvil's macro reassembles the struct literal (or calls a per-type
      [unmarshal] helper for resources like ConfigMap whose fields are not
      literally [{metadata; spec; status}]); [recombine] names that assembler. *)
  val recombine :
    metadata:Object_meta.t -> spec:spec -> status:status -> t

  val marshal_spec : spec -> Value.t
  val unmarshal_spec : Value.t -> spec Res.t
  val marshal_status : status -> Value.t
  val unmarshal_status : Value.t -> status Res.t

  (** Anvil [state_validation]: the rule that checks only the new object. *)
  val state_validation : t -> bool

  (** Anvil [transition_validation]: the rule relating the new object to the
      old one (immutable-field checks, monotone counters, ...). *)
  val transition_validation : t -> old:t -> bool
end

(** The full [ResourceView] surface: the atom, plus the three derived members. *)
module type RESOURCE_VIEW = sig
  include RESOURCE

  (** Anvil derives [object_ref] from [kind] + [metadata.name] + [metadata
      .namespace]. Anvil's spec unwraps the two [Option]s under a
      well-formedness invariant; lacking that invariant we return
      {!Err.Missing_field} when either is absent. *)
  val object_ref : t -> Common.object_ref Res.t

  (** Anvil: [marshal(self) = DynamicObjectView { kind, metadata, marshal_spec
      (spec), marshal_status(status) }]. Total. *)
  val marshal : t -> Dynamic_object.t

  (** Anvil: check [obj.kind == kind] (else error), then [unmarshal_spec] /
      [unmarshal_status] (either may fail), then reassemble. *)
  val unmarshal : Dynamic_object.t -> t Res.t
end

module Make (R : RESOURCE) :
  RESOURCE_VIEW
    with type t = R.t
     and type spec = R.spec
     and type status = R.status

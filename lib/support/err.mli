(** The one hand-rolled error type for the port. No exceptions anywhere in
    [anvil]: every partial function returns {!Res.t} into this closed sum.

    Anvil's Verus original threads a zero-payload [UnmarshalError = ()] and
    otherwise makes partiality disappear into proof. OCaml carries no proof,
    so the failure modes the proofs discharge (kind mismatch, a malformed
    marshalled [Value], an absent metadata field an [object_ref] needs) become
    live, total branches here. Deliberately monomorphic: parameterising by the
    resource type would infect every downstream signature. *)

(** The layer and function a failure belongs to; the frame an exception's
    stack would have carried. [layer] is the module tree ([k8s_objects],
    [reconciler], ...), [fn] the failing function's name. *)
type site = { layer : string; fn : string }

(** Closed and exhaustive: every arm is matched at each site, and the loop /
    wildcard firewalls forbid a [_ ->] catch-all. [At] is the sole context
    carrier, stacking to any depth without a field on any other arm. *)
type t =
  | Kind_mismatch of { expected : string; found : string }
      (** [unmarshal] onto the wrong resource: [obj.kind != Self::kind()] in
          Anvil's [ResourceView::unmarshal]. *)
  | Malformed_value of { kind : string; detail : string }
      (** a marshalled [Value] (a JSON string) that will not parse, or parses
          to the wrong JSON shape for this resource's spec/status. *)
  | Missing_field of { owner : string; field : string }
      (** a required field absent where Anvil's spec unwraps an [Option] via
          [->0] under a well-formedness invariant we cannot assume, e.g.
          [object_ref] needing [metadata.name] and [metadata.namespace]. *)
  | Decode_error of { typ : string; detail : string }
      (** a JSON value of the right outer shape whose contents do not decode
          into [typ]. *)
  | At of { site : site; inner : t }
      (** context frame; reads as a path from the outermost caller inward. *)

(** A one-line, stable rendering; used only for diagnostics and test messages,
    never parsed. *)
val show : t -> string

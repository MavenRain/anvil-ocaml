open Anvil_support

module type RESOURCE = sig
  type t
  type spec
  type status

  val kind : Common.kind
  val default : unit -> t
  val metadata : t -> Object_meta.t
  val spec : t -> spec
  val status : t -> status
  val recombine : metadata:Object_meta.t -> spec:spec -> status:status -> t
  val marshal_spec : spec -> Value.t
  val unmarshal_spec : Value.t -> spec Res.t
  val marshal_status : status -> Value.t
  val unmarshal_status : Value.t -> status Res.t
  val state_validation : t -> bool
  val transition_validation : t -> old:t -> bool
end

module type RESOURCE_VIEW = sig
  include RESOURCE

  val object_ref : t -> Common.object_ref Res.t
  val marshal : t -> Dynamic_object.t
  val unmarshal : Dynamic_object.t -> t Res.t
end

module Make (R : RESOURCE) = struct
  include R

  (* Anvil: object_ref(self) = { kind, name: metadata.name->0,
     namespace: metadata.namespace->0 }. The two [->0] unwraps assume a
     well-formedness invariant we cannot carry, so an absent name/namespace is
     a total {!Err.Missing_field} branch rather than a partial projection. *)
  let object_ref (v : R.t) : Common.object_ref Res.t =
    let open Res in
    let m = R.metadata v in
    let* name =
      of_option
        ~none:(Err.Missing_field { owner = "metadata"; field = "name" })
        (Object_meta.name m)
    and* namespace =
      of_option
        ~none:(Err.Missing_field { owner = "metadata"; field = "namespace" })
        (Object_meta.namespace m)
    in
    ok { Common.kind = R.kind; name; namespace }

  let marshal (v : R.t) : Dynamic_object.t =
    Dynamic_object.make ~kind:R.kind ~metadata:(R.metadata v)
      ~spec:(R.marshal_spec (R.spec v))
      ~status:(R.marshal_status (R.status v))

  (* Anvil: unmarshal(obj) errors on kind mismatch, then on a failed
     unmarshal_spec / unmarshal_status, else reassembles. *)
  let unmarshal (d : Dynamic_object.t) : R.t Res.t =
    let open Res in
    let dk = Dynamic_object.kind d in
    if Common.equal_kind dk R.kind then
      let* spec = R.unmarshal_spec (Dynamic_object.spec d)
      and* status = R.unmarshal_status (Dynamic_object.status d) in
      ok (R.recombine ~metadata:(Dynamic_object.metadata d) ~spec ~status)
    else
      error
        (Err.Kind_mismatch
           { expected = Common.show_kind R.kind; found = Common.show_kind dk })
end

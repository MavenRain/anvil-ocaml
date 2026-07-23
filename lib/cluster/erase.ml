(* Anvil source: kubernetes_cluster/spec/controller/state_machine.rs (the
   typed-reconciler -> ReconcileModel boundary). Void-erasure adapter: marshal a
   typed void reconciler's state to Value at every boundary and erase its void
   external I/O to Value, producing a uniform Controller_pack.CONTROLLER. *)

module type STATE_CODEC = sig
  type s
  type k

  val id : int
  val marshal_state : s -> Value.t
  val unmarshal_state : Value.t -> s Res.t
  val unmarshal_cr : Dynamic_object.t -> k Res.t
end

module Void_erase
    (V : Reconciler.RECONCILER
           with type ereq = Io.void
            and type eresp = Io.void)
    (C : STATE_CODEC with type s = V.s and type k = V.k) =
struct
  module R = struct
    type s = Value.t
    type k = V.k
    type ereq = Value.t
    type eresp = Value.t

    let reconcile_init_state () : s = C.marshal_state (V.reconcile_init_state ())

    (* Value external response -> void external response: K passes through; a
       void reconciler declared no external system, so an External_response
       cannot arise in a well-formed cluster and is mapped to "no response"
       (routing the typed core into its own no-matching-response branch). *)
    let to_void_resp (resp : Value.t Io.response_view option) :
        Io.void Io.response_view option =
      match resp with
      | None -> None
      | Some (Io.K_response a) -> Some (Io.K_response a)
      | Some (Io.External_response _) -> None

    (* void request -> Value request: K passes through; External_request carries
       a void (empty) payload, unreachable and hence refuted. *)
    let of_void_req (req : Io.void Io.request_view option) :
        Value.t Io.request_view option =
      match req with
      | None -> None
      | Some (Io.K_request q) -> Some (Io.K_request q)
      | Some (Io.External_request _) -> .

    let reconcile_core ~(cr : k) ~(resp : eresp Io.response_view option)
        ~(state : s) : s * ereq Io.request_view option =
      Result.fold (C.unmarshal_state state)
        ~error:(fun (_ : Err.t) -> (state, None)) (* corrupt store: no-op *)
        ~ok:(fun st ->
          let st', req =
            V.reconcile_core ~cr ~resp:(to_void_resp resp) ~state:st
          in
          (C.marshal_state st', of_void_req req))

    let reconcile_done (state : s) : bool =
      Result.fold (C.unmarshal_state state)
        ~error:(fun (_ : Err.t) -> false)
        ~ok:V.reconcile_done

    let reconcile_error (state : s) : bool =
      Result.fold (C.unmarshal_state state)
        ~error:(fun (_ : Err.t) -> false)
        ~ok:V.reconcile_error
  end

  let id = C.id
  let marshal_state (s : R.s) : Value.t = s (* R.s = Value.t: identity *)
  let unmarshal_cr = C.unmarshal_cr
end

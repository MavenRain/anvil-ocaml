(* P7 exec-shim: the reconcile driver (Anvil's [controller_runtime]). See
   controller_runtime.mli for the contract and the honest-limit documentation.
   The driver is generic over a {!Concurrency.CONCURRENCY} and a
   {!K8s_client.K8S_CLIENT}; with {!Concurrency.Direct} it is fully deterministic.
   The two sanctioned recursions are [drive] (fuel-bounded) and [round]
   (round-bounded); no other loop keyword or naked recursion appears. *)

type outcome = Reconciled | Errored | Incomplete of int

(* Structural equality on [outcome]; exhaustive over the three variants, no
   [_ ->] catch-all. *)
let outcome_equal (a : outcome) (b : outcome) : bool =
  match a, b with
  | Reconciled, Reconciled | Errored, Errored -> true
  | Incomplete x, Incomplete y -> Int.equal x y
  | Reconciled, _ | Errored, _ | Incomplete _, _ -> false

(* Requeue policy: a terminal [Errored] and a fuel-exhausted [Incomplete] both
   warrant another round; a [Reconciled] key is settled. Exhaustive, no [_ ->]. *)
let requeues (o : outcome) : bool =
  match o with Errored | Incomplete _ -> true | Reconciled -> false

module Make
    (C : Concurrency.CONCURRENCY)
    (K : K8s_client.K8S_CLIENT with type 'a io = 'a C.t) =
struct
  (* The single sanctioned helper for threading a [Res]-style result inside the
     [C] monad (mirrors how rule.ml threads [Res] inside another monad): short
     circuit an [Error], otherwise hand the value to the continuation. Keeping
     exactly one such helper is what the firewall permits in place of a bare
     two-arm result match. *)
  let on_ok (r : ('a, Err.t) result) (k : 'a -> ('b, Err.t) result C.t) :
      ('b, Err.t) result C.t =
    match r with Ok v -> k v | Error e -> C.return (Error e)

  let reconcile_with ~(client : K.t) ~(model : Controller.reconcile_model)
      ~(cr : Dynamic_object.t) ~(fuel : int) : (outcome, Err.t) result C.t =
    (* Fuel-bounded drive: from [model.init ()], feed each produced request to
       the client and thread the response back until done/error/fuel-out. Each
       transition consumes one unit of fuel; the [cr] snapshot is never re-read. *)
    let rec drive (resp : Value.t Io.response_view option) (state : Value.t)
        (fuel : int) : (outcome, Err.t) result C.t =
      if fuel <= 0 then C.return (Ok (Incomplete 0))
      else if model.Controller.reconcile_error state then C.return (Ok Errored)
      else if model.Controller.reconcile_done state then
        C.return (Ok Reconciled)
      else
        let state', req_opt = model.Controller.transition cr resp state in
        match req_opt with
        | None -> drive None state' (fuel - 1)
        | Some (Io.K_request api_req) ->
            C.bind (K.request client api_req) (fun r ->
                on_ok r (fun api_resp ->
                    drive (Some (Io.K_response api_resp)) state' (fuel - 1)))
        | Some (Io.External_request _) ->
            C.return
              (Error
                 (Err.Malformed_value
                    {
                      kind = "external_request";
                      detail =
                        "in-memory api-server backend has no external subsystem";
                    }))
    in
    drive None (model.Controller.init ()) fuel

  let run_controller ~(client : K.t) ~(model : Controller.reconcile_model)
      ~(queue : Common.object_ref list) ~(fuel : int) ~(max_rounds : int) :
      (outcome Object_ref_map.t, Err.t) result C.t =
    (* Dedup a work set preserving first-seen order (list fold, no loop). *)
    let dedup (keys : Common.object_ref list) : Common.object_ref list =
      List.rev
        (List.fold_left
           (fun acc k ->
             if List.exists (Common.equal_object_ref k) acc then acc
             else k :: acc)
           [] keys)
    in
    (* Process one key: GET the cr; on a hit, [reconcile_with] and record the
       outcome, requeuing per {!requeues}; a missing object drops the key (a
       deleted cr, not an error); any other GET api_error is a transient failure
       recorded as [Errored] and requeued. The accumulator is
       [(results, requeue)] threaded through the [C] monad. *)
    let process_key (key : Common.object_ref)
        (results : outcome Object_ref_map.t) (requeue : Common.object_ref list) :
        (outcome Object_ref_map.t * Common.object_ref list, Err.t) result C.t =
      C.bind (K.request client (Api_method.Get_request { Api_method.key }))
        (fun r ->
          on_ok r (fun api_resp ->
              match api_resp with
              | Api_method.Get_response { res = Ok obj } ->
                  C.bind (reconcile_with ~client ~model ~cr:obj ~fuel) (fun rr ->
                      on_ok rr (fun outcome ->
                          let results' = Object_ref_map.add key outcome results in
                          let requeue' =
                            if requeues outcome then key :: requeue else requeue
                          in
                          C.return (Ok (results', requeue'))))
              | Api_method.Get_response { res = Error Object_not_found } ->
                  (* deleted cr: drop the key, record nothing *)
                  C.return (Ok (results, requeue))
              | Api_method.Get_response
                  {
                    res =
                      Error
                        ( Bad_request | Conflict | Forbidden | Invalid
                        | Object_already_exists | Not_supported | Internal_error
                        | Timeout | Server_timeout | Transaction_abort | Other );
                  } ->
                  let results' = Object_ref_map.add key Errored results in
                  C.return (Ok (results', key :: requeue))
              | Api_method.List_response _ | Api_method.Create_response _
              | Api_method.Delete_response _ | Api_method.Update_response _
              | Api_method.Update_status_response _
              | Api_method.Get_then_delete_response _
              | Api_method.Get_then_update_response _
              | Api_method.Get_then_update_status_response _ ->
                  C.return
                    (Error
                       (Err.Malformed_value
                          {
                            kind = "api_response";
                            detail = "GET returned a non-get response";
                          }))))
    in
    (* Fold the pending keys through [process_key], threading the [C] monad and
       the accumulator; a per-key [Error] short-circuits the whole round. *)
    let process_all (pending : Common.object_ref list)
        (results0 : outcome Object_ref_map.t) :
        (outcome Object_ref_map.t * Common.object_ref list, Err.t) result C.t =
      List.fold_left
        (fun acc_cm key ->
          C.bind acc_cm (fun acc_res ->
              on_ok acc_res (fun (results, requeue) ->
                  process_key key results requeue)))
        (C.return (Ok (results0, [])))
        pending
    in
    (* Round-bounded manager: run every pending key once, accumulate outcomes,
       and recurse on the requeue set until it clears or [max_rounds] is spent. *)
    let rec round (pending : Common.object_ref list)
        (results : outcome Object_ref_map.t) (rounds_left : int) :
        (outcome Object_ref_map.t, Err.t) result C.t =
      if rounds_left <= 0 then C.return (Ok results)
      else
        match pending with
        | [] -> C.return (Ok results)
        | _ :: _ ->
            C.bind (process_all pending results) (fun r ->
                on_ok r (fun (results', requeue) ->
                    round (List.rev requeue) results' (rounds_left - 1)))
    in
    round (dedup queue) Object_ref_map.empty max_rounds
end

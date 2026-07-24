(* P9 exec-shim: the two-controller round driver (the "controller of
   controllers" harness). See multi_controller.mli for the contract and the
   honest-limit documentation.

   Several {!Controller.reconcile_model}s are driven over ONE shared
   {!K8s_client.K8S_CLIENT} store to a JOINT fixpoint. Each round lists every
   model's [kind] in the namespace and drives {!Controller_runtime.reconcile_with}
   over each returned custom resource; a round is the joint fixpoint iff it leaves
   the backend's resource-version write-clock unchanged AND every driven
   reconciler reached [Reconciled] (so a fuel-starved or wedged read-only round is
   never mistaken for convergence). Termination is a round-bounded [let rec]
   ([go]); no loop keyword or naked recursion appears.
   Results are threaded inside the [C] monad with {!Stdlib.Result.fold} (the
   sanctioned short-circuit combinator: [on_ok] in {!Controller_runtime} is
   module-private, so the same "stop on [Error], continue on [Ok]" shape is
   expressed via [Result.fold], never a raw two-arm result match). *)

module Make
    (C : Concurrency.CONCURRENCY)
    (K : K8s_client.K8S_CLIENT with type 'a io = 'a C.t) =
struct
  type report = {
    rounds : int;
    converged : bool;
  }

  (* One per-CR reconcile driver, shared across every model in the round. *)
  module CR = Controller_runtime.Make (C) (K)

  let run_to_fixpoint ~(client : K.t)
      ~(models : Controller.reconcile_model list) ~(namespace : string)
      ~(rv : unit -> int) ~(fuel : int) ~(max_rounds : int) :
      (report, Err.t) result C.t =
    (* Thread a [Res]-style result inside the [C] monad: short-circuit an
       [Error], otherwise hand the value to the continuation. Expressed with the
       sanctioned {!Stdlib.Result.fold} combinator (mirrors the private [on_ok]
       of {!Controller_runtime}); no raw two-arm result match. *)
    let on_ok : type a b.
        (a, Err.t) result -> (a -> (b, Err.t) result C.t) ->
        (b, Err.t) result C.t =
     fun r k -> Result.fold ~ok:k ~error:(fun e -> C.return (Error e)) r
    in
    (* Reconcile every listed cr of one model to its per-CR fixpoint, threading
       the [C] monad; a per-cr [Error] short-circuits the whole round (list
       fold, no loop keyword). Accumulate whether EVERY cr reached
       {!Controller_runtime.Reconciled}: an [Errored] or [Incomplete] (fuel-
       starved or wedged) cr makes the model not-yet-settled, so a round that
       merely LISTs without a write is not mistaken for a joint fixpoint. *)
    let reconcile_objs (model : Controller.reconcile_model)
        (objs : Dynamic_object.t list) : (bool, Err.t) result C.t =
      List.fold_left
        (fun acc_cm cr ->
          C.bind acc_cm (fun acc_res ->
              on_ok acc_res (fun (all_reconciled : bool) ->
                  C.bind (CR.reconcile_with ~client ~model ~cr ~fuel) (fun rr ->
                      on_ok rr (fun (outcome : Controller_runtime.outcome) ->
                          let cr_reconciled =
                            match outcome with
                            | Controller_runtime.Reconciled -> true
                            | Controller_runtime.Errored
                            | Controller_runtime.Incomplete _ -> false
                          in
                          C.return (Ok (all_reconciled && cr_reconciled)))))))
        (C.return (Ok true))
        objs
    in
    (* Run one model: LIST its [kind] in [namespace] and reconcile every returned
       cr. A [List_response] whose [res] is [Ok] drives the crs; an api-error
       [res] or any non-list api_response is a total [Err.t] (fold the [res]
       result with {!Stdlib.Result.fold}; enumerate the api_response sum
       exhaustively — the eight non-list verbs are the grouped tail). *)
    let run_model (model : Controller.reconcile_model) :
        (bool, Err.t) result C.t =
      C.bind
        (K.request client
           (Api_method.List_request
              { Api_method.kind = model.Controller.kind; namespace }))
        (fun r ->
          on_ok r (fun (api_resp : Api_method.api_response) ->
              match api_resp with
              | Api_method.List_response { res } ->
                  Result.fold res
                    ~ok:(fun objs -> reconcile_objs model objs)
                    ~error:(fun (_ : Api_method.api_error) ->
                      C.return
                        (Error
                           (Err.Malformed_value
                              {
                                kind = "list_response";
                                detail = "list request returned an api error";
                              })))
              | Api_method.Get_response _ | Api_method.Create_response _
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
                            detail = "LIST returned a non-list response";
                          }))))
    in
    (* Run every model once, in order, threading the [C] monad; a model's
       [Error] short-circuits the round (list fold, no loop keyword). The round
       is settled iff EVERY model's crs all reached [Reconciled]. *)
    let run_round () : (bool, Err.t) result C.t =
      List.fold_left
        (fun acc_cm model ->
          C.bind acc_cm (fun acc_res ->
              on_ok acc_res (fun (all_reconciled : bool) ->
                  C.bind (run_model model) (fun rr ->
                      on_ok rr (fun (model_reconciled : bool) ->
                          C.return (Ok (all_reconciled && model_reconciled)))))))
        (C.return (Ok true))
        models
    in
    (* Round-bounded manager: read the write-clock before and after a full
       round. The joint fixpoint requires BOTH that the round performed no store
       write (unchanged [rv]) AND that every driven reconciler reached
       [Reconciled]; a fuel-starved or wedged read-only round (rv unchanged but
       some reconciler still [Incomplete]/[Errored]) is NOT reported as
       convergence — it consumes a round like any unsettled one. Bounded by
       [max_rounds]. *)
    let rec go (rounds_left : int) (rounds_done : int) :
        (report, Err.t) result C.t =
      if rounds_left <= 0 then
        C.return (Ok { rounds = rounds_done; converged = false })
      else
        let before = rv () in
        C.bind (run_round ()) (fun r ->
            on_ok r (fun (all_reconciled : bool) ->
                let after = rv () in
                if Int.equal before after && all_reconciled then
                  C.return (Ok { rounds = rounds_done + 1; converged = true })
                else go (rounds_left - 1) (rounds_done + 1)))
    in
    go max_rounds 0
end

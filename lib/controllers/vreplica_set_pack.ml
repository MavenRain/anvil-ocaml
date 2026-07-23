(* Anvil source: the reconcile-state codec plus the driver-ready CONTROLLER pack
   for the VReplicaSet controller (model/reconciler.rs state; the kubernetes
   cluster's controller-map entry). The typed void reconciler's local state is
   marshalled to Value and its void external I/O erased through
   Erase.Void_erase, yielding a uniform Controller_pack.CONTROLLER. *)

let filtered_pods_to_json (pods : Pod.t list) : Yojson.Safe.t =
  Json.list (fun (p : Pod.t) -> Dynamic_object.to_json (Pod.marshal p)) pods

let filtered_pods_of_json (j : Yojson.Safe.t) : Pod.t list Res.t =
  Json.to_list
    (fun (jp : Yojson.Safe.t) ->
      Res.bind (Dynamic_object.of_json jp) Pod.unmarshal)
    j

let marshal_state (st : Vreplica_set_reconciler.s) : Value.t =
  Value.of_json
    (Json.obj_opt
       [
         ( "step",
           Some (Vreplica_set_reconciler.step_to_json st.reconcile_step) );
         ("filteredPods", Json.opt filtered_pods_to_json st.filtered_pods);
       ])

let unmarshal_state (v : Value.t) : Vreplica_set_reconciler.s Res.t =
  match Value.json v with
  | `Assoc _ as j ->
    let open Res in
    let* reconcile_step =
      Json.get j "step" Vreplica_set_reconciler.step_of_json
    in
    let* filtered_pods =
      Json.opt_mem j "filteredPods" filtered_pods_of_json
    in
    ok
      ({ Vreplica_set_reconciler.reconcile_step; filtered_pods }
        : Vreplica_set_reconciler.s)
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
    Res.error
      (Err.Decode_error
         { typ = "vreplica_set_pack.state"; detail = "expected object" })

module Codec :
  Erase.STATE_CODEC
    with type s = Vreplica_set_reconciler.s
     and type k = Vreplica_set.t = struct
  type s = Vreplica_set_reconciler.s
  type k = Vreplica_set.t

  let id = 0
  let marshal_state = marshal_state
  let unmarshal_state = unmarshal_state
  let unmarshal_cr = Vreplica_set.unmarshal
end

module Controller = Erase.Void_erase (Vreplica_set_reconciler.R) (Codec)

let packed : Controller_pack.packed = (module Controller)
let kind = Vreplica_set.kind

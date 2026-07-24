(* Anvil source: the reconcile-state codec plus the driver-ready CONTROLLER pack
   for the VDeployment controller (model/reconciler.rs state; the kubernetes
   cluster's controller-map entry). The typed void reconciler's local state
   (step, new_vrs, old_vrs_list, old_vrs_index) is marshalled to Value in FULL
   and its void external I/O erased through Erase.Void_erase, yielding a uniform
   Controller_pack.CONTROLLER. Void_erase invokes marshal_state/unmarshal_state on
   every transition, so the whole scale-down cursor round-trips through the store;
   child VReplicaSet objects marshal via Vreplica_set.marshal. *)

let vrs_to_json (v : Vreplica_set.t) : Yojson.Safe.t =
  Dynamic_object.to_json (Vreplica_set.marshal v)

let vrs_of_json (j : Yojson.Safe.t) : Vreplica_set.t Res.t =
  Res.bind (Dynamic_object.of_json j) Vreplica_set.unmarshal

let marshal_state (st : V_deployment_reconciler.s) : Value.t =
  Value.of_json
    (Json.obj_opt
       [
         ("step", Some (V_deployment_reconciler.step_to_json st.reconcile_step));
         ("newVrs", Json.opt vrs_to_json st.new_vrs);
         ("oldVrsList", Some (Json.list vrs_to_json st.old_vrs_list));
         ("oldVrsIndex", Some (Json.int_ st.old_vrs_index));
       ])

let unmarshal_state (v : Value.t) : V_deployment_reconciler.s Res.t =
  match Value.json v with
  | `Assoc _ as j ->
    let open Res in
    let* reconcile_step =
      Json.get j "step" V_deployment_reconciler.step_of_json
    in
    let* new_vrs = Json.opt_mem j "newVrs" vrs_of_json in
    let* old_vrs_list =
      Json.opt_mem j "oldVrsList" (Json.to_list vrs_of_json)
      |> Res.map (Option.value ~default:[])
    in
    let* old_vrs_index =
      Json.opt_mem j "oldVrsIndex" Json.to_int
      |> Res.map (Option.value ~default:0)
    in
    ok
      ({ reconcile_step; new_vrs; old_vrs_list; old_vrs_index }
        : V_deployment_reconciler.s)
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
    Res.error
      (Err.Decode_error
         { typ = "v_deployment_pack.state"; detail = "expected object" })

module Codec :
  Erase.STATE_CODEC
    with type s = V_deployment_reconciler.s
     and type k = V_deployment.t = struct
  type s = V_deployment_reconciler.s
  type k = V_deployment.t

  let id = 1
  let marshal_state = marshal_state
  let unmarshal_state = unmarshal_state
  let unmarshal_cr = V_deployment.unmarshal
end

module Controller = Erase.Void_erase (V_deployment_reconciler.R) (Codec)

let packed : Controller_pack.packed = (module Controller)
let kind = V_deployment.kind

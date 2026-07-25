(* Anvil source: the reconcile-state codec plus the driver-ready CONTROLLER pack
   for the VStatefulSet controller (model/reconciler.rs state; the kubernetes
   cluster's controller-map entry). The typed void reconciler's local state (the
   step plus the pod/pvc cursors captured across the round) is marshalled to Value
   in FULL and its void external I/O erased through Erase.Void_erase, yielding a
   uniform Controller_pack.CONTROLLER. Void_erase invokes marshal_state/
   unmarshal_state on EVERY transition, so the whole reconcile state (every list
   and every cursor) round-trips through the store each step; a dropped field
   would reset that cursor every step and stall/loop. Child Pods marshal via
   Pod.marshal and child PersistentVolumeClaims via
   Persistent_volume_claim.marshal. *)

(* A present [Pod.t] marshals to its Dynamic_object JSON; the [condemned] list
   reuses this (the vreplica_set [filtered_pods] template). *)
let pod_to_json (p : Pod.t) : Yojson.Safe.t =
  Dynamic_object.to_json (Pod.marshal p)

let pod_of_json (j : Yojson.Safe.t) : Pod.t Res.t =
  Res.bind (Dynamic_object.of_json j) Pod.unmarshal

(* PersistentVolumeClaim variant of the same object round-trip. *)
let pvc_to_json (p : Persistent_volume_claim.t) : Yojson.Safe.t =
  Dynamic_object.to_json (Persistent_volume_claim.marshal p)

let pvc_of_json (j : Yojson.Safe.t) : Persistent_volume_claim.t Res.t =
  Res.bind (Dynamic_object.of_json j) Persistent_volume_claim.unmarshal

(* [needed] is a [Pod.t option list] indexed by ordinal ([None] when the pod is
   absent). Each element serialises to `Null` for [None] and to the pod's
   Dynamic_object JSON for [Some]; the inverse dispatches on the element's JSON
   shape (`Null` -> [None], an object -> [Some] via [pod_of_json]), enumerating
   the non-object/non-null Yojson arms exactly as [pod.ml] does (no wildcard,
   no `Tuple`/`Variant`). *)
let needed_to_json (needed : Pod.t option list) : Yojson.Safe.t =
  Json.list
    (fun (po : Pod.t option) ->
      Option.fold ~none:`Null
        ~some:(fun (p : Pod.t) -> Dynamic_object.to_json (Pod.marshal p))
        po)
    needed

let needed_of_json (j : Yojson.Safe.t) : Pod.t option list Res.t =
  Json.to_list
    (fun (jp : Yojson.Safe.t) ->
      match jp with
      | `Null -> Res.ok None
      | `Assoc _ as o -> Res.map Option.some (pod_of_json o)
      | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
        Res.error
          (Err.Decode_error
             {
               typ = "v_stateful_set_pack.needed";
               detail = "expected object or null";
             }))
    j

let marshal_state (st : V_stateful_set_reconciler.s) : Value.t =
  Value.of_json
    (Json.obj_opt
       [
         ( "step",
           Some (V_stateful_set_reconciler.step_to_json st.reconcile_step) );
         ("needed", Some (needed_to_json st.needed));
         ("neededIndex", Some (Json.int_ st.needed_index));
         ("condemned", Some (Json.list pod_to_json st.condemned));
         ("condemnedIndex", Some (Json.int_ st.condemned_index));
         ("pvcs", Some (Json.list pvc_to_json st.pvcs));
         ("pvcIndex", Some (Json.int_ st.pvc_index));
       ])

let unmarshal_state (v : Value.t) : V_stateful_set_reconciler.s Res.t =
  match Value.json v with
  | `Assoc _ as j ->
    let open Res in
    let* reconcile_step =
      Json.get j "step" V_stateful_set_reconciler.step_of_json
    in
    let* needed =
      Json.opt_mem j "needed" needed_of_json |> Res.map (Option.value ~default:[])
    in
    let* needed_index =
      Json.opt_mem j "neededIndex" Json.to_int
      |> Res.map (Option.value ~default:0)
    in
    let* condemned =
      Json.opt_mem j "condemned" (Json.to_list pod_of_json)
      |> Res.map (Option.value ~default:[])
    in
    let* condemned_index =
      Json.opt_mem j "condemnedIndex" Json.to_int
      |> Res.map (Option.value ~default:0)
    in
    let* pvcs =
      Json.opt_mem j "pvcs" (Json.to_list pvc_of_json)
      |> Res.map (Option.value ~default:[])
    in
    let* pvc_index =
      Json.opt_mem j "pvcIndex" Json.to_int |> Res.map (Option.value ~default:0)
    in
    ok
      ({
         V_stateful_set_reconciler.reconcile_step;
         needed;
         needed_index;
         condemned;
         condemned_index;
         pvcs;
         pvc_index;
       }
        : V_stateful_set_reconciler.s)
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
    Res.error
      (Err.Decode_error
         { typ = "v_stateful_set_pack.state"; detail = "expected object" })

module Codec :
  Erase.STATE_CODEC
    with type s = V_stateful_set_reconciler.s
     and type k = V_stateful_set.t = struct
  type s = V_stateful_set_reconciler.s
  type k = V_stateful_set.t

  (* Controller ids in the cluster's [Map<int, _>]: VReplicaSet = 0,
     VDeployment = 1, VStatefulSet = 2 (this pack). *)
  let id = 2
  let marshal_state = marshal_state
  let unmarshal_state = unmarshal_state
  let unmarshal_cr = V_stateful_set.unmarshal
end

module Controller = Erase.Void_erase (V_stateful_set_reconciler.R) (Codec)

let packed : Controller_pack.packed = (module Controller)
let kind = V_stateful_set.kind

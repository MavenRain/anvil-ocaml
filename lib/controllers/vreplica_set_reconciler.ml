(* Anvil source: controllers/vreplicaset_controller/model/reconciler.rs
   (reconcile_core + helpers) and trusted/step.rs (the step enum, view form).

   The typed RECONCILER for VReplicaSet. Ports the pure spec-level state machine
   faithfully; the only deviations are honest replacements for Anvil's
   proof-discharged [.unwrap()]/[->0] on well-formedness-guaranteed fields, each
   routed to [error_state]. On a well-formed CR every such field is [Some] and
   every index is in range, so the ported core takes exactly Anvil's branches. *)

type step =
  | Init
  | After_list_pods
  | After_create_pod of int
  | After_delete_pod of int
  | After_update_vrs_status
  | Done
  | Error

let step_equal (a : step) (b : step) : bool =
  match (a, b) with
  | Init, Init -> true
  | After_list_pods, After_list_pods -> true
  | After_create_pod x, After_create_pod y -> Int.equal x y
  | After_delete_pod x, After_delete_pod y -> Int.equal x y
  | After_update_vrs_status, After_update_vrs_status -> true
  | Done, Done -> true
  | Error, Error -> true
  | ( ( Init | After_list_pods | After_create_pod _ | After_delete_pod _
      | After_update_vrs_status | Done | Error ),
      _ ) ->
    false

let step_to_json (st : step) : Yojson.Safe.t =
  match st with
  | Init -> Json.obj [ ("step", Json.str "init") ]
  | After_list_pods -> Json.obj [ ("step", Json.str "afterListPods") ]
  | After_create_pod d ->
    Json.obj [ ("step", Json.str "afterCreatePod"); ("diff", Json.int_ d) ]
  | After_delete_pod d ->
    Json.obj [ ("step", Json.str "afterDeletePod"); ("diff", Json.int_ d) ]
  | After_update_vrs_status ->
    Json.obj [ ("step", Json.str "afterUpdateVrsStatus") ]
  | Done -> Json.obj [ ("step", Json.str "done") ]
  | Error -> Json.obj [ ("step", Json.str "error") ]

let step_of_json (j : Yojson.Safe.t) : step Res.t =
  let open Res in
  let* tag = Json.get j "step" Json.to_str in
  match tag with
  | "init" -> ok Init
  | "afterListPods" -> ok After_list_pods
  | "afterCreatePod" ->
    let* d = Json.get j "diff" Json.to_int in
    ok (After_create_pod d)
  | "afterDeletePod" ->
    let* d = Json.get j "diff" Json.to_int in
    ok (After_delete_pod d)
  | "afterUpdateVrsStatus" -> ok After_update_vrs_status
  | "done" -> ok Done
  | "error" -> ok Error
  | _ ->
    error
      (Err.Decode_error
         { typ = "vreplica_set_reconciler.step"; detail = tag })

(* VReplicaSetReconcileState: the step plus the pods captured at list time (kept
   across a scale-down so the delete loop can index them). *)
type s = { reconcile_step : step; filtered_pods : Pod.t list option }

let reconcile_init_state () : s = { reconcile_step = Init; filtered_pods = None }
let error_state (state : s) : s = { state with reconcile_step = Error }

let reconcile_done (state : s) : bool =
  match state.reconcile_step with
  | Done -> true
  | Init | After_list_pods | After_create_pod _ | After_delete_pod _
  | After_update_vrs_status | Error ->
    false

let reconcile_error (state : s) : bool =
  match state.reconcile_step with
  | Error -> true
  | Init | After_list_pods | After_create_pod _ | After_delete_pod _
  | After_update_vrs_status | Done ->
    false

(* -- ported spec helpers -- *)

(* Anvil: name = "vreplicaset" + "-" + suffix for some suffix, i.e. the string
   carries the "vreplicaset-" prefix. *)
let has_vrs_prefix (name : string) : bool =
  String.starts_with ~prefix:(Vreplica_set.kind_name ^ "-") name

(* Anvil objects_to_pods: if any list element fails to unmarshal as a pod the
   whole conversion fails; otherwise every element unmarshals. The [exists] gate
   guarantees the following [filter_map] keeps every element. *)
let objects_to_pods (objs : Dynamic_object.t list) : Pod.t list option =
  if List.exists (fun o -> Result.is_error (Pod.unmarshal o)) objs then None
  else Some (List.filter_map (fun o -> Result.to_option (Pod.unmarshal o)) objs)

(* Anvil pod_filter conjuncts: the pod carries the vrs owner reference, its
   labels match the vrs selector, it is not being deleted, and its name has the
   "vreplicaset-" prefix. *)
let pod_matches (vrs : Vreplica_set.t) (oref : Owner_reference.t) (pod : Pod.t) :
    bool =
  let pm = Pod.metadata pod in
  Object_meta.owner_references_contains pm oref
  && Label_selector.matches (Vreplica_set.spec vrs).selector
       (Option.value ~default:Smap.empty pm.labels)
  && Option.is_none (Object_meta.deletion_timestamp pm)
  && Option.fold ~none:false ~some:has_vrs_prefix (Object_meta.name pm)

let filter_pods (pods : Pod.t list) (vrs : Vreplica_set.t)
    (oref : Owner_reference.t) : Pod.t list =
  List.filter (pod_matches vrs oref) pods

(* Anvil pod_generate_name: "vreplicaset-" + vrs.metadata.name + "-". Honest on
   the missing name (Anvil unwraps it). *)
let pod_generate_name (vrs : Vreplica_set.t) : string option =
  Option.map
    (fun nm -> Vreplica_set.kind_name ^ "-" ^ nm ^ "-")
    (Object_meta.name (Vreplica_set.metadata vrs))

(* Anvil make_pod: copy template.spec into pod.spec, carry labels/annotations/
   finalizers from the template metadata, then with_generate_name and
   with_owner_references [controller_owner_ref vrs]. Honest on the missing
   template / template.metadata / generate-name / owner-ref (Anvil unwraps). *)
let make_pod (vrs : Vreplica_set.t) : Pod.t option =
  Option.bind (Vreplica_set.spec vrs).template (fun (tmpl : Pod_template_spec.t) ->
      Option.bind tmpl.metadata (fun (tm : Object_meta.t) ->
          Option.bind (pod_generate_name vrs) (fun gname ->
              Option.map
                (fun oref ->
                  let md =
                    {
                      (Object_meta.default ()) with
                      labels = tm.labels;
                      annotations = tm.annotations;
                      finalizers = tm.finalizers;
                    }
                    |> Object_meta.with_generate_name gname
                    |> Object_meta.with_owner_references [ oref ]
                  in
                  Pod.make ~metadata:md ~spec:tmpl.spec ~status:None)
                (Vreplica_set.controller_owner_ref vrs))))

(* Anvil update_vrs_replicas: requires exactly one controller owner reference;
   sets status.replicas = replicas (default 1) and issues a status update.
   Honest on the missing name/namespace (Anvil unwraps). *)
let update_vrs_replicas (state : s) (vrs : Vreplica_set.t) :
    s * Io.void Io.request_view option =
  let md = Vreplica_set.metadata vrs in
  Option.fold md.owner_references
    ~none:(error_state state, None)
    ~some:(fun orefs ->
      let ctrls = List.filter Owner_reference.is_controller orefs in
      match ctrls with
      | [ the_owner ] ->
        let ns_name =
          Option.bind (Object_meta.name md) (fun name ->
              Option.map
                (fun namespace -> (name, namespace))
                (Object_meta.namespace md))
        in
        Option.fold ns_name
          ~none:(error_state state, None)
          ~some:(fun (name, namespace) ->
            let replicas =
              Option.value ~default:1 (Vreplica_set.spec vrs).replicas
            in
            let vrs' =
              Vreplica_set.with_status
                (Vreplica_set.status_with_replicas replicas
                   (Vreplica_set.status_default ()))
                vrs
            in
            let req =
              Io.K_request
                (Api_method.Get_then_update_status_request
                   {
                     Api_method.namespace;
                     name;
                     owner_ref = the_owner;
                     obj = Vreplica_set.marshal vrs';
                   })
            in
            ({ state with reconcile_step = After_update_vrs_status }, Some req))
      | [] | _ :: _ :: _ -> (error_state state, None))

(* Consume a Kubernetes response through [viewer]: an absent / wrong-kind
   response and an [Error] payload both route to [error_state]; an [Ok] payload
   is handed to [ok]. Uses fold combinators (no two-arm Option/Result match). *)
let with_ok_resp
    (viewer :
      Io.void Io.response_view option ->
      ('a, Api_method.api_error) result option) (state : s)
    (resp : Io.void Io.response_view option)
    ~(ok : 'a -> s * Io.void Io.request_view option) :
    s * Io.void Io.request_view option =
  Option.fold (viewer resp)
    ~none:(error_state state, None)
    ~some:(fun r ->
      Result.fold r
        ~error:(fun (_ : Api_method.api_error) -> (error_state state, None))
        ~ok)

let reconcile_core ~(cr : Vreplica_set.t)
    ~(resp : Io.void Io.response_view option) ~(state : s) :
    s * Io.void Io.request_view option =
  let md = Vreplica_set.metadata cr in
  match state.reconcile_step with
  | Init ->
    Option.fold (Object_meta.deletion_timestamp md)
      ~some:(fun (_ : string) -> ({ state with reconcile_step = Done }, None))
      ~none:
        (Option.fold (Object_meta.namespace md)
           ~none:(error_state state, None)
           ~some:(fun namespace ->
             let req =
               Io.K_request
                 (Api_method.List_request
                    { Api_method.kind = Pod.kind; namespace })
             in
             ({ state with reconcile_step = After_list_pods }, Some req)))
  | After_list_pods ->
    with_ok_resp Io_resp.k_list_resp state resp ~ok:(fun objs ->
        Option.fold (objects_to_pods objs)
          ~none:(error_state state, None)
          ~some:(fun pods ->
            let ns_oref =
              Option.bind (Object_meta.namespace md) (fun namespace ->
                  Option.map
                    (fun oref -> (namespace, oref))
                    (Vreplica_set.controller_owner_ref cr))
            in
            Option.fold ns_oref
              ~none:(error_state state, None)
              ~some:(fun (namespace, oref) ->
                let filtered = filter_pods pods cr oref in
                let replicas =
                  Option.value ~default:1 (Vreplica_set.spec cr).replicas
                in
                if replicas < 0 then (error_state state, None)
                else
                  let desired = replicas in
                  let n = List.length filtered in
                  if n = desired then update_vrs_replicas state cr
                  else if n < desired then
                    let diff = desired - n in
                    Option.fold (make_pod cr)
                      ~none:(error_state state, None)
                      ~some:(fun pod ->
                        let req =
                          Io.K_request
                            (Api_method.Create_request
                               { Api_method.namespace; obj = Pod.marshal pod })
                        in
                        ( { state with reconcile_step = After_create_pod (diff - 1) },
                          Some req ))
                  else
                    let diff = n - desired in
                    Option.fold (List.nth_opt filtered (diff - 1))
                      ~none:(error_state state, None)
                      ~some:(fun (victim : Pod.t) ->
                        Option.fold (Object_meta.name (Pod.metadata victim))
                          ~none:(error_state state, None)
                          ~some:(fun name ->
                            let req =
                              Io.K_request
                                (Api_method.Get_then_delete_request
                                   {
                                     Api_method.key =
                                       { Common.kind = Pod.kind; name; namespace };
                                     owner_ref = oref;
                                   })
                            in
                            ( {
                                reconcile_step = After_delete_pod (diff - 1);
                                filtered_pods = Some filtered;
                              },
                              Some req ))))))
  | After_create_pod diff ->
    with_ok_resp Io_resp.k_create_resp state resp
      ~ok:(fun (_ : Dynamic_object.t) ->
        if diff = 0 then update_vrs_replicas state cr
        else
          Option.fold (Object_meta.namespace md)
            ~none:(error_state state, None)
            ~some:(fun namespace ->
              Option.fold (make_pod cr)
                ~none:(error_state state, None)
                ~some:(fun pod ->
                  let req =
                    Io.K_request
                      (Api_method.Create_request
                         { Api_method.namespace; obj = Pod.marshal pod })
                  in
                  ( { state with reconcile_step = After_create_pod (diff - 1) },
                    Some req ))))
  | After_delete_pod diff ->
    with_ok_resp Io_resp.k_get_then_delete_resp state resp ~ok:(fun () ->
        if diff = 0 then update_vrs_replicas state cr
        else
          Option.fold state.filtered_pods
            ~none:(error_state state, None)
            ~some:(fun (fp : Pod.t list) ->
              if diff > List.length fp then (error_state state, None)
              else
                Option.fold (List.nth_opt fp (diff - 1))
                  ~none:(error_state state, None)
                  ~some:(fun (victim : Pod.t) ->
                    let ns_name =
                      Option.bind (Object_meta.namespace md) (fun namespace ->
                          Option.bind
                            (Object_meta.name (Pod.metadata victim))
                            (fun name ->
                              Option.map
                                (fun oref -> (namespace, name, oref))
                                (Vreplica_set.controller_owner_ref cr)))
                    in
                    Option.fold ns_name
                      ~none:(error_state state, None)
                      ~some:(fun (namespace, name, oref) ->
                        let req =
                          Io.K_request
                            (Api_method.Get_then_delete_request
                               {
                                 Api_method.key =
                                   { Common.kind = Pod.kind; name; namespace };
                                 owner_ref = oref;
                               })
                        in
                        ( { state with reconcile_step = After_delete_pod (diff - 1) },
                          Some req )))))
  | After_update_vrs_status ->
    with_ok_resp Io_resp.k_get_then_update_status_resp state resp
      ~ok:(fun (_ : Dynamic_object.t) ->
        ({ state with reconcile_step = Done }, None))
  | Done -> (state, None)
  | Error -> (state, None)

module R :
  Reconciler.RECONCILER
    with type k = Vreplica_set.t
     and type s = s
     and type ereq = Io.void
     and type eresp = Io.void = struct
  type nonrec s = s
  type k = Vreplica_set.t
  type ereq = Io.void
  type eresp = Io.void

  let reconcile_init_state = reconcile_init_state
  let reconcile_core = reconcile_core
  let reconcile_done = reconcile_done
  let reconcile_error = reconcile_error
end

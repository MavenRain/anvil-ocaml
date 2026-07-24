(* Anvil source: controllers/vdeployment_controller/model/reconciler.rs
   (reconcile_core + helpers) and trusted/step.rs (the step enum, view form),
   with [valid_owned_vrs] / [match_template_without_hash] from
   trusted/liveness_theorem.rs ported inline.

   The typed RECONCILER for VDeployment: a controller that manages VReplicaSet
   children the way [Vreplica_set_reconciler] manages Pods. Ports the pure
   spec-level rolling-update state machine faithfully; the only deviations are
   honest replacements for Anvil's proof-discharged [.unwrap()]/[->0] on
   well-formedness-guaranteed fields (name/namespace/owner-ref/resource-version),
   each routed to [error_state]. On a well-formed CR every such field is [Some]
   and every index is in range, so the ported core takes exactly Anvil's
   branches. *)

type step =
  | Init
  | After_list_vrs
  | After_create_new_vrs
  | After_scale_new_vrs
  | After_ensure_new_vrs
  | After_scale_down_old_vrs
  | Done
  | Error

let step_equal (a : step) (b : step) : bool =
  match (a, b) with
  | Init, Init -> true
  | After_list_vrs, After_list_vrs -> true
  | After_create_new_vrs, After_create_new_vrs -> true
  | After_scale_new_vrs, After_scale_new_vrs -> true
  | After_ensure_new_vrs, After_ensure_new_vrs -> true
  | After_scale_down_old_vrs, After_scale_down_old_vrs -> true
  | Done, Done -> true
  | Error, Error -> true
  | ( ( Init | After_list_vrs | After_create_new_vrs | After_scale_new_vrs
      | After_ensure_new_vrs | After_scale_down_old_vrs | Done | Error ),
      _ ) ->
    false

let step_to_json (st : step) : Yojson.Safe.t =
  match st with
  | Init -> Json.obj [ ("step", Json.str "init") ]
  | After_list_vrs -> Json.obj [ ("step", Json.str "afterListVrs") ]
  | After_create_new_vrs -> Json.obj [ ("step", Json.str "afterCreateNewVrs") ]
  | After_scale_new_vrs -> Json.obj [ ("step", Json.str "afterScaleNewVrs") ]
  | After_ensure_new_vrs -> Json.obj [ ("step", Json.str "afterEnsureNewVrs") ]
  | After_scale_down_old_vrs ->
    Json.obj [ ("step", Json.str "afterScaleDownOldVrs") ]
  | Done -> Json.obj [ ("step", Json.str "done") ]
  | Error -> Json.obj [ ("step", Json.str "error") ]

let step_of_json (j : Yojson.Safe.t) : step Res.t =
  let open Res in
  let* tag = Json.get j "step" Json.to_str in
  match tag with
  | "init" -> ok Init
  | "afterListVrs" -> ok After_list_vrs
  | "afterCreateNewVrs" -> ok After_create_new_vrs
  | "afterScaleNewVrs" -> ok After_scale_new_vrs
  | "afterEnsureNewVrs" -> ok After_ensure_new_vrs
  | "afterScaleDownOldVrs" -> ok After_scale_down_old_vrs
  | "done" -> ok Done
  | "error" -> ok Error
  | _ ->
    error
      (Err.Decode_error { typ = "v_deployment_reconciler.step"; detail = tag })

(* VDeploymentReconcileState: the step, the new VReplicaSet (once known), the old
   VReplicaSets captured at list time, and the scale-down loop cursor
   [old_vrs_index] ([>= 0] by construction). *)
type s = {
  reconcile_step : step;
  new_vrs : Vreplica_set.t option;
  old_vrs_list : Vreplica_set.t list;
  old_vrs_index : int;
}

let reconcile_init_state () : s =
  { reconcile_step = Init; new_vrs = None; old_vrs_list = []; old_vrs_index = 0 }

let error_state (state : s) : s = { state with reconcile_step = Error }
let done_state (state : s) : s = { state with reconcile_step = Done }

let new_vrs_ensured_state (state : s) : s =
  { state with reconcile_step = After_ensure_new_vrs }

let reconcile_done (state : s) : bool =
  match state.reconcile_step with
  | Done -> true
  | Init | After_list_vrs | After_create_new_vrs | After_scale_new_vrs
  | After_ensure_new_vrs | After_scale_down_old_vrs | Error ->
    false

let reconcile_error (state : s) : bool =
  match state.reconcile_step with
  | Error -> true
  | Init | After_list_vrs | After_create_new_vrs | After_scale_new_vrs
  | After_ensure_new_vrs | After_scale_down_old_vrs | Done ->
    false

(* -- ported spec helpers -- *)

(* Anvil [replicas.unwrap_or(1)]. *)
let replicas_or1 (r : int option) : int = Option.value ~default:1 r

(* Anvil objects_to_vrs_list: if any list element fails to unmarshal as a
   VReplicaSet the whole conversion fails; otherwise every element unmarshals.
   The [exists] gate guarantees the following [filter_map] keeps every element. *)
let objects_to_vrs_list (objs : Dynamic_object.t list) : Vreplica_set.t list option
    =
  if List.exists (fun o -> Result.is_error (Vreplica_set.unmarshal o)) objs then
    None
  else Some (List.filter_map (fun o -> Result.to_option (Vreplica_set.unmarshal o)) objs)

(* Anvil trusted/liveness_theorem::valid_owned_vrs: the VReplicaSet has a name
   and a namespace equal to the VDeployment's, passes its own state validation,
   is not being deleted, and carries the VDeployment's controller owner
   reference. The owner ref is an option (proof-discharged upstream): absent ->
   not owned. *)
let valid_owned_vrs (vrs : Vreplica_set.t) (cr : V_deployment.t) : bool =
  let vm = Vreplica_set.metadata vrs in
  Option.is_some (Object_meta.name vm)
  && Option.is_some (Object_meta.namespace vm)
  && Option.equal String.equal (Object_meta.namespace vm)
       (Object_meta.namespace (V_deployment.metadata cr))
  && Vreplica_set.state_validation vrs
  && Option.is_none (Object_meta.deletion_timestamp vm)
  && Option.fold (V_deployment.controller_owner_ref cr) ~none:false
       ~some:(fun (oref : Owner_reference.t) ->
         Object_meta.owner_references_contains vm oref)

(* Strip the "pod-template-hash" label from a template's metadata (leaving the
   rest of the template intact); the metadata / labels are options
   (proof-discharged upstream) so an absent one stays absent. *)
let strip_pod_template_hash (pts : Pod_template_spec.t) : Pod_template_spec.t =
  {
    pts with
    metadata =
      Option.map
        (fun (m : Object_meta.t) ->
          { m with labels = Option.map (Smap.remove "pod-template-hash") m.labels })
        pts.metadata;
  }

(* Anvil trusted/liveness_theorem::match_template_without_hash: the VDeployment
   template and the VReplicaSet's template are equal after removing the
   "pod-template-hash" label from both. The VReplicaSet template is an option
   (proof-discharged upstream): absent -> no match. *)
let match_template_without_hash (template : Pod_template_spec.t)
    (vrs : Vreplica_set.t) : bool =
  Option.fold (Vreplica_set.spec vrs).template ~none:false
    ~some:(fun (vt : Pod_template_spec.t) ->
      Pod_template_spec.equal
        (strip_pod_template_hash template)
        (strip_pod_template_hash vt))

(* Anvil filter_old_and_new_vrs: the reusable ("new") VReplicaSet is the first
   template-matching one with non-zero replicas (falling back to the first
   template-matching one); every template-matching-or-not VReplicaSet with
   non-zero replicas that is not the reusable one is an "old" VReplicaSet to
   scale down. Preserves input order. *)
let filter_old_and_new_vrs (cr : V_deployment.t) (vrs_list : Vreplica_set.t list)
    : Vreplica_set.t option * Vreplica_set.t list =
  let reusable_list =
    List.filter
      (match_template_without_hash (V_deployment.spec cr).template)
      vrs_list
  in
  let nonempty (v : Vreplica_set.t) : bool =
    Option.fold (Vreplica_set.spec v).replicas ~none:true ~some:(fun r -> r > 0)
  in
  let reusable =
    match reusable_list with
    | [] -> None
    | hd :: _ ->
      Option.fold (List.find_opt nonempty reusable_list) ~none:(Some hd)
        ~some:(fun (v : Vreplica_set.t) -> Some v)
  in
  let uid_eq (a : Vreplica_set.t) (b : Vreplica_set.t) : bool =
    Option.equal Common.Uid.equal
      (Vreplica_set.metadata a).uid
      (Vreplica_set.metadata b).uid
  in
  let old_vrs_list =
    List.filter
      (fun (v : Vreplica_set.t) ->
        Option.fold reusable ~none:true ~some:(fun (r : Vreplica_set.t) ->
            not (uid_eq v r))
        && Option.fold (Vreplica_set.spec v).replicas ~none:true ~some:(fun r ->
               r > 0))
      vrs_list
  in
  (reusable, old_vrs_list)

(* Anvil template_with_hash: the VDeployment template with "pod-template-hash"
   inserted into its metadata labels. The metadata is an option
   (proof-discharged upstream): absent stays absent. *)
let template_with_hash (cr : V_deployment.t) (hash : string) : Pod_template_spec.t
    =
  let tmpl = (V_deployment.spec cr).template in
  {
    tmpl with
    metadata =
      Option.map
        (fun (m : Object_meta.t) ->
          {
            m with
            labels =
              Some
                (Smap.add "pod-template-hash" hash
                   (Option.value ~default:Smap.empty m.labels));
          })
        tmpl.metadata;
  }

(* Anvil make_replica_set: a fresh VReplicaSet for the VDeployment, hashed by the
   VDeployment's resource version. Honest on the missing name / owner reference
   (Anvil unwraps): absent -> [None]. *)
let make_replica_set (cr : V_deployment.t) : Vreplica_set.t option =
  let md = V_deployment.metadata cr in
  let hash =
    Option.fold md.resource_version ~none:"0" ~some:(fun rv ->
        string_of_int (Common.Resource_version.to_int rv))
  in
  Option.bind (Object_meta.name md) (fun name ->
      Option.map
        (fun (oref : Owner_reference.t) ->
          let tmpl = (V_deployment.spec cr).template in
          let tmpl_labels =
            Option.fold tmpl.metadata ~none:Smap.empty
              ~some:(fun (m : Object_meta.t) ->
                Option.value ~default:Smap.empty m.labels)
          in
          let match_labels = Smap.add "pod-template-hash" hash tmpl_labels in
          let meta =
            {
              (Object_meta.default ()) with
              generate_name = Some (name ^ "-" ^ hash);
              namespace = md.namespace;
              labels = md.labels;
              owner_references = Some [ oref ];
            }
            |> Object_meta.add_label "pod-template-hash" hash
          in
          let spec : Vreplica_set.vrs_spec =
            {
              replicas =
                Some (if replicas_or1 (V_deployment.spec cr).replicas > 0 then 1 else 0);
              selector = { Label_selector.match_labels = Some match_labels };
              template = Some (template_with_hash cr hash);
            }
          in
          Vreplica_set.make ~metadata:meta ~spec ~status:None)
        (V_deployment.controller_owner_ref cr))

(* Anvil mismatch_replicas: the VReplicaSet is at zero replicas (readiness
   irrelevant) or its ready status matches its desired replicas, AND its desired
   replicas differ from the VDeployment's. *)
let mismatch_replicas (cr : V_deployment.t) (vrs : Vreplica_set.t) : bool =
  (Option.equal Int.equal (Vreplica_set.spec vrs).replicas (Some 0)
  || Option.fold (Vreplica_set.status vrs) ~none:false
       ~some:(fun (st : Vreplica_set.vrs_status) ->
         Int.equal st.replicas (replicas_or1 (Vreplica_set.spec vrs).replicas)))
  && not
       (Int.equal
          (replicas_or1 (Vreplica_set.spec vrs).replicas)
          (replicas_or1 (V_deployment.spec cr).replicas))

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

(* Anvil create_new_vrs: issue a Create for a fresh VReplicaSet, advancing to
   [After_create_new_vrs]. Honest on the missing namespace / owner reference. *)
let create_new_vrs (state : s) (cr : V_deployment.t) :
    s * Io.void Io.request_view option =
  Option.fold (Object_meta.namespace (V_deployment.metadata cr))
    ~none:(error_state state, None)
    ~some:(fun namespace ->
      Option.fold (make_replica_set cr)
        ~none:(error_state state, None)
        ~some:(fun (nv : Vreplica_set.t) ->
          let req =
            Io.K_request
              (Api_method.Create_request
                 { Api_method.namespace; obj = Vreplica_set.marshal nv })
          in
          ({ state with reconcile_step = After_create_new_vrs }, Some req)))

(* Anvil scale_new_vrs: move the new VReplicaSet's replicas one step toward the
   VDeployment's desired count, advancing to [After_scale_new_vrs]. Reached only
   when [state.new_vrs] is [Some]; the guard is honest on that plus the missing
   name / namespace / owner reference. *)
let scale_new_vrs (state : s) (cr : V_deployment.t) :
    s * Io.void Io.request_view option =
  Option.fold state.new_vrs
    ~none:(error_state state, None)
    ~some:(fun (nv : Vreplica_set.t) ->
      Option.fold (Object_meta.namespace (V_deployment.metadata cr))
        ~none:(error_state state, None)
        ~some:(fun namespace ->
          Option.fold (Object_meta.name (Vreplica_set.metadata nv))
            ~none:(error_state state, None)
            ~some:(fun name ->
              Option.fold (V_deployment.controller_owner_ref cr)
                ~none:(error_state state, None)
                ~some:(fun (oref : Owner_reference.t) ->
                  let cur = replicas_or1 (Vreplica_set.spec nv).replicas in
                  let updated =
                    if replicas_or1 (V_deployment.spec cr).replicas > cur then
                      cur + 1
                    else cur - 1
                  in
                  let nv' =
                    Vreplica_set.with_spec
                      (Vreplica_set.spec_with_replicas updated
                         (Vreplica_set.spec nv))
                      nv
                  in
                  let req =
                    Io.K_request
                      (Api_method.Get_then_update_request
                         {
                           Api_method.namespace;
                           name;
                           owner_ref = oref;
                           obj = Vreplica_set.marshal nv';
                         })
                  in
                  ( {
                      state with
                      reconcile_step = After_scale_new_vrs;
                      new_vrs = Some nv';
                    },
                    Some req )))))

(* Anvil scale_down_old_vrs: scale the old VReplicaSet at [old_vrs_index - 1] to
   zero replicas, advancing to [After_scale_down_old_vrs] with the decremented
   cursor. Honest on the out-of-range index / missing name / namespace / owner
   reference. *)
let scale_down_old_vrs (state : s) (cr : V_deployment.t) :
    s * Io.void Io.request_view option =
  let idx = state.old_vrs_index - 1 in
  Option.fold (List.nth_opt state.old_vrs_list idx)
    ~none:(error_state state, None)
    ~some:(fun (old : Vreplica_set.t) ->
      Option.fold (Object_meta.namespace (V_deployment.metadata cr))
        ~none:(error_state state, None)
        ~some:(fun namespace ->
          Option.fold (Object_meta.name (Vreplica_set.metadata old))
            ~none:(error_state state, None)
            ~some:(fun name ->
              Option.fold (V_deployment.controller_owner_ref cr)
                ~none:(error_state state, None)
                ~some:(fun (oref : Owner_reference.t) ->
                  let old' =
                    Vreplica_set.with_spec
                      (Vreplica_set.spec_with_replicas 0 (Vreplica_set.spec old))
                      old
                  in
                  let req =
                    Io.K_request
                      (Api_method.Get_then_update_request
                         {
                           Api_method.namespace;
                           name;
                           owner_ref = oref;
                           obj = Vreplica_set.marshal old';
                         })
                  in
                  ( {
                      state with
                      reconcile_step = After_scale_down_old_vrs;
                      old_vrs_index = idx;
                    },
                    Some req )))))

let reconcile_core ~(cr : V_deployment.t)
    ~(resp : Io.void Io.response_view option) ~(state : s) :
    s * Io.void Io.request_view option =
  let md = V_deployment.metadata cr in
  Option.fold (Object_meta.namespace md)
    ~none:(error_state state, None)
    ~some:(fun namespace ->
      match state.reconcile_step with
      | Init ->
        let req =
          Io.K_request
            (Api_method.List_request
               { Api_method.kind = Vreplica_set.kind; namespace })
        in
        ( {
            reconcile_step = After_list_vrs;
            new_vrs = None;
            old_vrs_list = [];
            old_vrs_index = 0;
          },
          Some req )
      | After_list_vrs ->
        with_ok_resp Io_resp.k_list_resp state resp ~ok:(fun objs ->
            Option.fold (objects_to_vrs_list objs)
              ~none:(error_state state, None)
              ~some:(fun vrs_all ->
                let filtered =
                  List.filter (fun v -> valid_owned_vrs v cr) vrs_all
                in
                let new_vrs, old_vrs_list = filter_old_and_new_vrs cr filtered in
                let base =
                  {
                    reconcile_step = After_ensure_new_vrs;
                    new_vrs;
                    old_vrs_list;
                    old_vrs_index = List.length old_vrs_list;
                  }
                in
                Option.fold new_vrs
                  ~none:(create_new_vrs base cr)
                  ~some:(fun (nv : Vreplica_set.t) ->
                    if mismatch_replicas cr nv then scale_new_vrs base cr
                    else (base, None))))
      | After_create_new_vrs ->
        with_ok_resp Io_resp.k_create_resp state resp
          ~ok:(fun (new_obj : Dynamic_object.t) ->
            Result.fold (Vreplica_set.unmarshal new_obj)
              ~error:(fun (_ : Err.t) -> (error_state state, None))
              ~ok:(fun (vrs : Vreplica_set.t) ->
                ( {
                    state with
                    reconcile_step = After_ensure_new_vrs;
                    new_vrs = Some vrs;
                  },
                  None )))
      | After_scale_new_vrs ->
        with_ok_resp Io_resp.k_get_then_update_resp state resp
          ~ok:(fun (_ : Dynamic_object.t) -> (new_vrs_ensured_state state, None))
      | After_ensure_new_vrs ->
        if state.old_vrs_index = 0 then (done_state state, None)
        else if state.old_vrs_index > List.length state.old_vrs_list then
          (error_state state, None)
        else
          Option.fold
            (List.nth_opt state.old_vrs_list (state.old_vrs_index - 1))
            ~none:(error_state state, None)
            ~some:(fun (old : Vreplica_set.t) ->
              if valid_owned_vrs old cr then scale_down_old_vrs state cr
              else (error_state state, None))
      | After_scale_down_old_vrs ->
        with_ok_resp Io_resp.k_get_then_update_resp state resp
          ~ok:(fun (_ : Dynamic_object.t) ->
            if state.old_vrs_index = 0 then (done_state state, None)
            else if state.old_vrs_index > List.length state.old_vrs_list then
              (error_state state, None)
            else
              Option.fold
                (List.nth_opt state.old_vrs_list (state.old_vrs_index - 1))
                ~none:(error_state state, None)
                ~some:(fun (old : Vreplica_set.t) ->
                  if valid_owned_vrs old cr then scale_down_old_vrs state cr
                  else (error_state state, None)))
      | Done -> (state, None)
      | Error -> (state, None))

module R :
  Reconciler.RECONCILER
    with type k = V_deployment.t
     and type s = s
     and type ereq = Io.void
     and type eresp = Io.void = struct
  type nonrec s = s
  type k = V_deployment.t
  type ereq = Io.void
  type eresp = Io.void

  let reconcile_init_state = reconcile_init_state
  let reconcile_core = reconcile_core
  let reconcile_done = reconcile_done
  let reconcile_error = reconcile_error
end

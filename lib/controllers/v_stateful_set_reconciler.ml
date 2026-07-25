(* Anvil source: controllers/vstatefulset_controller/model/reconciler.rs
   (reconcile_core + helpers) and trusted/step.rs (the step enum, view form).

   The typed RECONCILER for VStatefulSet: a SINGLE controller that manages Pods
   and their PersistentVolumeClaims directly. Ports the pure spec-level state
   machine faithfully; the only deviations are honest replacements for Anvil's
   proof-discharged [.unwrap()]/[->0] on well-formedness-guaranteed fields
   (name/namespace/owner-ref, in-range indices), each routed to [error_state].
   On a well-formed CR every such field is [Some] and every index is in range, so
   the ported core takes exactly Anvil's branches.

   The step machine alternates ACTION steps (which emit exactly one request and
   advance to their matching [After_*] step) with [After_*] steps (which consume
   the response and, via a dispatch helper, SET the next action step and return
   no request). Returning a non-terminal state with no request is the same
   handoff [V_deployment_reconciler] uses (its [After_list_vrs] no-op path), so
   the controller host re-invokes [reconcile_core] to run the chosen action. *)

type step =
  | Init
  | After_list_pod
  | Get_pvc
  | After_get_pvc
  | Create_pvc
  | After_create_pvc
  | Skip_pvc
  | Create_needed
  | After_create_needed
  | Update_needed
  | After_update_needed
  | Delete_condemned
  | After_delete_condemned
  | Delete_outdated
  | After_delete_outdated
  | Done
  | Error

(* Total rank for the 17 steps; used only to derive [step_equal] without a
   17x17 pairwise match. Exhaustive, no wildcard. *)
let step_rank (st : step) : int =
  match st with
  | Init -> 0
  | After_list_pod -> 1
  | Get_pvc -> 2
  | After_get_pvc -> 3
  | Create_pvc -> 4
  | After_create_pvc -> 5
  | Skip_pvc -> 6
  | Create_needed -> 7
  | After_create_needed -> 8
  | Update_needed -> 9
  | After_update_needed -> 10
  | Delete_condemned -> 11
  | After_delete_condemned -> 12
  | Delete_outdated -> 13
  | After_delete_outdated -> 14
  | Done -> 15
  | Error -> 16

let step_equal (a : step) (b : step) : bool =
  Int.equal (step_rank a) (step_rank b)

let step_to_json (st : step) : Yojson.Safe.t =
  match st with
  | Init -> Json.obj [ ("step", Json.str "init") ]
  | After_list_pod -> Json.obj [ ("step", Json.str "afterListPod") ]
  | Get_pvc -> Json.obj [ ("step", Json.str "getPvc") ]
  | After_get_pvc -> Json.obj [ ("step", Json.str "afterGetPvc") ]
  | Create_pvc -> Json.obj [ ("step", Json.str "createPvc") ]
  | After_create_pvc -> Json.obj [ ("step", Json.str "afterCreatePvc") ]
  | Skip_pvc -> Json.obj [ ("step", Json.str "skipPvc") ]
  | Create_needed -> Json.obj [ ("step", Json.str "createNeeded") ]
  | After_create_needed -> Json.obj [ ("step", Json.str "afterCreateNeeded") ]
  | Update_needed -> Json.obj [ ("step", Json.str "updateNeeded") ]
  | After_update_needed -> Json.obj [ ("step", Json.str "afterUpdateNeeded") ]
  | Delete_condemned -> Json.obj [ ("step", Json.str "deleteCondemned") ]
  | After_delete_condemned ->
    Json.obj [ ("step", Json.str "afterDeleteCondemned") ]
  | Delete_outdated -> Json.obj [ ("step", Json.str "deleteOutdated") ]
  | After_delete_outdated ->
    Json.obj [ ("step", Json.str "afterDeleteOutdated") ]
  | Done -> Json.obj [ ("step", Json.str "done") ]
  | Error -> Json.obj [ ("step", Json.str "error") ]

let step_of_json (j : Yojson.Safe.t) : step Res.t =
  let open Res in
  let* tag = Json.get j "step" Json.to_str in
  match tag with
  | "init" -> ok Init
  | "afterListPod" -> ok After_list_pod
  | "getPvc" -> ok Get_pvc
  | "afterGetPvc" -> ok After_get_pvc
  | "createPvc" -> ok Create_pvc
  | "afterCreatePvc" -> ok After_create_pvc
  | "skipPvc" -> ok Skip_pvc
  | "createNeeded" -> ok Create_needed
  | "afterCreateNeeded" -> ok After_create_needed
  | "updateNeeded" -> ok Update_needed
  | "afterUpdateNeeded" -> ok After_update_needed
  | "deleteCondemned" -> ok Delete_condemned
  | "afterDeleteCondemned" -> ok After_delete_condemned
  | "deleteOutdated" -> ok Delete_outdated
  | "afterDeleteOutdated" -> ok After_delete_outdated
  | "done" -> ok Done
  | "error" -> ok Error
  | _ ->
    error
      (Err.Decode_error
         { typ = "v_stateful_set_reconciler.step"; detail = tag })

(* VStatefulSetReconcileState: the step plus the pod/pvc cursors captured across
   the round. [needed] is indexed by ordinal 0..replicas-1 ([None] when the pod
   is absent); [condemned] holds ordinal >= replicas pods, descending by ordinal;
   [pvcs] holds the PVCs of the CURRENT needed pod (reset per pod). *)
type s = {
  reconcile_step : step;
  needed : Pod.t option list;
  needed_index : int;
  condemned : Pod.t list;
  condemned_index : int;
  pvcs : Persistent_volume_claim.t list;
  pvc_index : int;
}

let init : s =
  {
    reconcile_step = Init;
    needed = [];
    needed_index = 0;
    condemned = [];
    condemned_index = 0;
    pvcs = [];
    pvc_index = 0;
  }

let reconcile_init_state () : s = init
let error_state (state : s) : s = { state with reconcile_step = Error }
let reconcile_done (state : s) : bool = step_equal state.reconcile_step Done
let reconcile_error (state : s) : bool = step_equal state.reconcile_step Error

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

(* Exhaustive api_error predicates (no wildcard), so the response arms can treat
   [Object_already_exists] / [Object_not_found] as success without matching the
   sum inline. *)
let api_error_is_object_already_exists (e : Api_method.api_error) : bool =
  match e with
  | Api_method.Object_already_exists -> true
  | Api_method.Bad_request | Api_method.Conflict | Api_method.Forbidden
  | Api_method.Invalid | Api_method.Object_not_found | Api_method.Not_supported
  | Api_method.Internal_error | Api_method.Timeout | Api_method.Server_timeout
  | Api_method.Transaction_abort | Api_method.Other ->
    false

let api_error_is_object_not_found (e : Api_method.api_error) : bool =
  match e with
  | Api_method.Object_not_found -> true
  | Api_method.Bad_request | Api_method.Conflict | Api_method.Forbidden
  | Api_method.Invalid | Api_method.Object_already_exists
  | Api_method.Not_supported | Api_method.Internal_error | Api_method.Timeout
  | Api_method.Server_timeout | Api_method.Transaction_abort | Api_method.Other
    ->
    false

(* -- ported spec helpers -- *)

let pod_name_label = "statefulset.kubernetes.io/pod-name"
let ordinal_label = "apps.kubernetes.io/pod-index"

(* Anvil pod name pieces. [pod_name_without_vsts_prefix] is the bare
   "<parent>-<ord>"; [pod_name] prepends the reserved "vstatefulset-" prefix. *)
let pod_name_without_vsts_prefix (parent : string) (ord : int) : string =
  parent ^ "-" ^ string_of_int ord

let pod_name (parent : string) (ord : int) : string =
  "vstatefulset-" ^ pod_name_without_vsts_prefix parent ord

(* Anvil pvc name: "vstatefulset-<tmpl>-<vsts>-<ord>". *)
let pvc_name (tmpl_name : string) (vsts_name : string) (ord : int) : string =
  "vstatefulset-" ^ tmpl_name ^ "-"
  ^ pod_name_without_vsts_prefix vsts_name ord

(* Anvil get_ordinal: the [ord] such that [name = pod_name parent ord], else
   [None]. Upstream defines it as the exact inverse of the injective [pod_name],
   so the parse must reject any suffix that [int_of_string_opt] over-accepts but
   that [string_of_int] never emits (radix prefixes [0x_]/[0o_]/[0b_], underscore
   digit groups, a leading sign, leading zeros): we parse then re-render via
   [pod_name] and keep the ordinal only when it round-trips to the same name
   (and is non-negative). This keeps get_ordinal injective and canonical, so a
   stray owned pod with a non-canonical parseable suffix is not misclassified. *)
let get_ordinal (parent : string) (name : string) : int option =
  let prefix = "vstatefulset-" ^ parent ^ "-" in
  if String.starts_with ~prefix name then
    let plen = String.length prefix in
    let suffix = String.sub name plen (String.length name - plen) in
    Option.bind (int_of_string_opt suffix) (fun ord ->
        if ord >= 0 && String.equal (pod_name parent ord) name then Some ord
        else None)
  else None

(* Anvil owner-reference list for a child: the controller owner ref if present,
   else empty (the ref is proof-discharged upstream). *)
let make_owner_references (cr : V_stateful_set.t) : Owner_reference.t list =
  Option.fold (V_stateful_set.controller_owner_ref cr) ~none:[]
    ~some:(fun (r : Owner_reference.t) -> [ r ])

(* Anvil update_identity: stamp the pod-name / ordinal labels (over the
   template's labels) and re-assert owner refs / template annotations, clearing
   finalizers and any deletion mark. The pod-name label value is the pod's own
   name (folded on the honest missing-name guard). *)
let update_identity (cr : V_stateful_set.t) (pod : Pod.t) (ordinal : int) : Pod.t
    =
  let sp : Stateful_set.ss_spec = V_stateful_set.spec cr in
  let tmpl : Pod_template_spec.t = sp.template in
  let tmpl_labels =
    Option.bind tmpl.metadata (fun (m : Object_meta.t) -> m.labels)
  in
  let tmpl_annotations =
    Option.bind tmpl.metadata (fun (m : Object_meta.t) -> m.annotations)
  in
  let md = Pod.metadata pod in
  let base_labels = Option.value ~default:Smap.empty tmpl_labels in
  let pname = Option.value ~default:"" md.name in
  let labels' =
    base_labels
    |> Smap.add pod_name_label pname
    |> Smap.add ordinal_label (string_of_int ordinal)
  in
  let md' =
    {
      md with
      labels = Some labels';
      owner_references = Some (make_owner_references cr);
      annotations = tmpl_annotations;
      finalizers = None;
      deletion_timestamp = None;
    }
  in
  Pod.with_metadata md' pod

(* Anvil make_pvc: the i-th volumeClaimTemplate specialised to [ord], named
   "vstatefulset-<tmpl>-<vsts>-<ord>", in the CR's namespace, its labels merged
   with the selector's match-labels (selector wins on a key clash). [None] when
   the index is out of range. *)
let make_pvc (cr : V_stateful_set.t) (ord : int) (i : int) :
    Persistent_volume_claim.t option =
  let sp : Stateful_set.ss_spec = V_stateful_set.spec cr in
  let tmpls = Option.value ~default:[] sp.volume_claim_templates in
  Option.map
    (fun (tmpl : Persistent_volume_claim.t) ->
      let tmpl_name = Option.value ~default:"" tmpl.metadata.name in
      let vsts_name =
        Option.value ~default:""
          (Object_meta.name (V_stateful_set.metadata cr))
      in
      let tmpl_labels = Option.value ~default:Smap.empty tmpl.metadata.labels in
      let sel_labels =
        Option.value ~default:Smap.empty sp.selector.match_labels
      in
      let merged =
        Smap.union (fun _ _ (r : string) -> Some r) tmpl_labels sel_labels
      in
      let ns = Object_meta.namespace (V_stateful_set.metadata cr) in
      let md =
        {
          (Object_meta.default ()) with
          name = Some (pvc_name tmpl_name vsts_name ord);
          namespace = ns;
          labels = Some merged;
        }
      in
      ({ metadata = md; spec = tmpl.spec; status = None }
        : Persistent_volume_claim.t))
    (List.nth_opt tmpls i)

(* Anvil make_pvcs: the specialised PVCs for [ord], one per volumeClaimTemplate. *)
let make_pvcs (cr : V_stateful_set.t) (ord : int) :
    Persistent_volume_claim.t list =
  let sp : Stateful_set.ss_spec = V_stateful_set.spec cr in
  let tmpls = Option.value ~default:[] sp.volume_claim_templates in
  List.mapi (fun i _ -> make_pvc cr ord i) tmpls |> List.filter_map Fun.id

(* Anvil update_storage: rewrite the pod's volumes so each volumeClaimTemplate
   contributes a volume named after the template, backed by that template's
   ordinal-specific PVC, preserving any of the pod's other volumes. A pod with
   no spec is returned unchanged. *)
let update_storage (cr : V_stateful_set.t) (pod : Pod.t) (ord : int) : Pod.t =
  Option.fold (Pod.spec pod) ~none:pod
    ~some:(fun (ps : Pod_spec.t) ->
      let sp : Stateful_set.ss_spec = V_stateful_set.spec cr in
      let tmpls = Option.value ~default:[] sp.volume_claim_templates in
      let pvcs = make_pvcs cr ord in
      let template_names =
        List.map
          (fun (t : Persistent_volume_claim.t) ->
            Option.value ~default:"" t.metadata.name)
          tmpls
      in
      let new_volumes =
        List.mapi
          (fun i (t : Persistent_volume_claim.t) ->
            let vname = Option.value ~default:"" t.metadata.name in
            let claim_name =
              Option.fold (List.nth_opt pvcs i) ~none:""
                ~some:(fun (p : Persistent_volume_claim.t) ->
                  Option.value ~default:"" p.metadata.name)
            in
            ({
               (Volume.default ()) with
               name = vname;
               persistent_volume_claim =
                 Some
                   ({ claim_name; read_only = Some false }
                     : Volume.persistent_volume_claim_volume_source);
             }
              : Volume.t))
          tmpls
      in
      let current = Option.value ~default:[] ps.volumes in
      let filtered_current =
        List.filter
          (fun (v : Volume.t) -> not (List.mem v.name template_names))
          current
      in
      let ps' = { ps with volumes = Some (new_volumes @ filtered_current) } in
      Pod.with_spec ps' pod)

(* Anvil init_identity: update_identity, then set the pod's hostname to its own
   name and its subdomain to the governing service. *)
let init_identity (cr : V_stateful_set.t) (pod : Pod.t) (ordinal : int) : Pod.t =
  let u = update_identity cr pod ordinal in
  let sp : Stateful_set.ss_spec = V_stateful_set.spec cr in
  let base_spec = Option.value ~default:(Pod_spec.default ()) (Pod.spec u) in
  let spec' =
    {
      base_spec with
      hostname = (Pod.metadata u).name;
      subdomain = Some sp.service_name;
    }
  in
  Pod.with_spec spec' u

(* Anvil make_pod: a pod for [ordinal] built from the CR template (labels,
   annotations, owner refs), then given its identity (hostname/subdomain,
   reserved labels) and its storage (per-ordinal PVC volumes). *)
let make_pod (cr : V_stateful_set.t) (ordinal : int) : Pod.t =
  let sp : Stateful_set.ss_spec = V_stateful_set.spec cr in
  let tmpl : Pod_template_spec.t = sp.template in
  let parent =
    Option.value ~default:"" (Object_meta.name (V_stateful_set.metadata cr))
  in
  let tmpl_labels =
    Option.bind tmpl.metadata (fun (m : Object_meta.t) -> m.labels)
  in
  let tmpl_annotations =
    Option.bind tmpl.metadata (fun (m : Object_meta.t) -> m.annotations)
  in
  let md =
    {
      (Object_meta.default ()) with
      name = Some (pod_name parent ordinal);
      labels = tmpl_labels;
      annotations = tmpl_annotations;
      owner_references = Some (make_owner_references cr);
    }
  in
  let base = Pod.make ~metadata:md ~spec:tmpl.spec ~status:None in
  update_storage cr (init_identity cr base ordinal) ordinal

(* Anvil get_pod_with_ord: the filtered pod whose parsed ordinal is [ord]. *)
let get_pod_with_ord (parent : string) (pods : Pod.t list) (ord : int) :
    Pod.t option =
  List.find_opt
    (fun (p : Pod.t) ->
      Option.fold (Object_meta.name (Pod.metadata p)) ~none:false
        ~some:(fun (n : string) ->
          Option.fold (get_ordinal parent n) ~none:false
            ~some:(fun (o : int) -> Int.equal o ord)))
    pods

(* Anvil partition: [needed] is the pod (or absence) at each ordinal
   0..replicas-1; [condemned] is every filtered pod at ordinal >= replicas,
   descending by ordinal. *)
let partition_pods (parent : string) (replicas : int) (pods : Pod.t list) :
    Pod.t option list * Pod.t list =
  let needed =
    if replicas < 0 then []
    else List.init replicas (fun ord -> get_pod_with_ord parent pods ord)
  in
  let condemned =
    pods
    |> List.filter_map (fun (p : Pod.t) ->
           Option.bind
             (Object_meta.name (Pod.metadata p))
             (fun (n : string) ->
               Option.map (fun (o : int) -> (o, p)) (get_ordinal parent n)))
    |> List.filter (fun (o, _) -> o >= replicas)
    |> List.sort (fun (a, _) (b, _) -> Int.compare b a)
    |> List.map snd
  in
  (needed, condemned)

(* Anvil pod_filter: carries the CR's controller owner ref, has a parseable
   "vstatefulset-<parent>-<ord>" name. (The selector match is commented out
   upstream and is not applied here.) *)
let pod_filter (cr : V_stateful_set.t) (pod : Pod.t) : bool =
  let pm = Pod.metadata pod in
  Option.fold (V_stateful_set.controller_owner_ref cr) ~none:false
    ~some:(fun (oref : Owner_reference.t) ->
      Object_meta.owner_references_contains pm oref)
  && Option.fold
       (Object_meta.name (V_stateful_set.metadata cr))
       ~none:false
       ~some:(fun (parent : string) ->
         Option.fold (Object_meta.name pm) ~none:false
           ~some:(fun (pname : string) ->
             Option.is_some (get_ordinal parent pname)))

(* Anvil pod_spec_matches: the pod's spec equals the template spec after
   ignoring the identity/storage fields the controller injects. *)
let pod_spec_matches (cr : V_stateful_set.t) (pod : Pod.t) : bool =
  let sp : Stateful_set.ss_spec = V_stateful_set.spec cr in
  let normalize (x : Pod_spec.t) : Pod_spec.t =
    { x with volumes = None; hostname = None; subdomain = None }
  in
  Option.fold (Pod.spec pod) ~none:false
    ~some:(fun (ps : Pod_spec.t) ->
      Option.fold sp.template.spec ~none:false
        ~some:(fun (ts : Pod_spec.t) ->
          Pod_spec.equal (normalize ps) (normalize ts)))

let outdated_pod_filter (cr : V_stateful_set.t) (po : Pod.t option) : bool =
  Option.fold po ~none:false ~some:(fun (pod : Pod.t) ->
      not (pod_spec_matches cr pod))

(* Anvil: the largest-ordinal needed pod whose spec no longer matches the
   template ([needed] is ascending by ordinal, so the last outdated one). *)
let get_largest_unmatched_pods (cr : V_stateful_set.t)
    (needed : Pod.t option list) : Pod.t option =
  let filtered = List.filter (outdated_pod_filter cr) needed in
  let n = List.length filtered in
  if n = 0 then None else Option.join (List.nth_opt filtered (n - 1))

(* Anvil objects_to_pods: [Some] all-unmarshalled pods, or [None] if any element
   is not a pod. *)
let objects_to_pods (objs : Dynamic_object.t list) : Pod.t list option =
  if List.exists (fun o -> Result.is_error (Pod.unmarshal o)) objs then None
  else Some (List.filter_map (fun o -> Result.to_option (Pod.unmarshal o)) objs)

(* -- dispatch helpers (SET the next action step, emit no request) -- *)

(* The action step for the current needed pod: create it if absent, else update
   it. [Error] on an out-of-range index (guarded unreachable by callers). *)
let needed_step (state : s) : step =
  Option.fold
    (List.nth_opt state.needed state.needed_index)
    ~none:Error
    ~some:
      (Option.fold ~none:Create_needed ~some:(fun (_ : Pod.t) -> Update_needed))

(* After the pod list: ensure the current pod's PVCs first (if any), then
   create/update the pod, then scale down condemned pods, then prune outdated. *)
let dispatch_after_list (state : s) : s * Io.void Io.request_view option =
  if state.needed_index < List.length state.needed then
    if List.length state.pvcs > 0 then
      ({ state with reconcile_step = Get_pvc }, None)
    else ({ state with reconcile_step = needed_step state }, None)
  else if state.condemned_index < List.length state.condemned then
    ( { state with reconcile_step = Delete_condemned;
        pvc_index = List.length state.pvcs },
      None )
  else
    ( { state with reconcile_step = Delete_outdated;
        pvc_index = List.length state.pvcs },
      None )

(* After probing/creating a PVC: keep walking this pod's PVCs, else create or
   update the pod itself. *)
let create_or_skip_pvc_helper (state : s) : s * Io.void Io.request_view option =
  if state.pvc_index < List.length state.pvcs then
    ({ state with reconcile_step = Get_pvc }, None)
  else if state.needed_index < List.length state.needed then
    ({ state with reconcile_step = needed_step state }, None)
  else (error_state state, None)

(* After creating/updating a needed pod ([needed_index] already advanced): move
   to the next needed pod (re-seeding its PVCs), else to scale-down, else to
   pruning. *)
let create_or_after_update_needed_helper (cr : V_stateful_set.t) (state : s) :
    s * Io.void Io.request_view option =
  if state.needed_index < List.length state.needed then
    let new_pvcs = make_pvcs cr state.needed_index in
    if List.length new_pvcs > 0 then
      ( { state with pvcs = new_pvcs; pvc_index = 0; reconcile_step = Get_pvc },
        None )
    else ({ state with reconcile_step = needed_step state }, None)
  else if state.condemned_index < List.length state.condemned then
    ({ state with reconcile_step = Delete_condemned }, None)
  else ({ state with reconcile_step = Delete_outdated }, None)

let reconcile_core ~(cr : V_stateful_set.t)
    ~(resp : Io.void Io.response_view option) ~(state : s) :
    s * Io.void Io.request_view option =
  let md = V_stateful_set.metadata cr in
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
             ({ state with reconcile_step = After_list_pod }, Some req)))
  | After_list_pod ->
    with_ok_resp Io_resp.k_list_resp state resp
      ~ok:(fun (objs : Dynamic_object.t list) ->
        Option.fold (objects_to_pods objs)
          ~none:(error_state state, None)
          ~some:(fun (pods : Pod.t list) ->
            Option.fold (Object_meta.name md)
              ~none:(error_state state, None)
              ~some:(fun (parent : string) ->
                let sp : Stateful_set.ss_spec = V_stateful_set.spec cr in
                let filtered = List.filter (pod_filter cr) pods in
                let replicas =
                  Option.fold ~none:1 ~some:(fun (r : int) -> r) sp.replicas
                in
                if replicas < 0 then (error_state state, None)
                else
                  let needed, condemned =
                    partition_pods parent replicas filtered
                  in
                  let pvcs = make_pvcs cr 0 in
                  let state' =
                    {
                      state with
                      needed;
                      needed_index = 0;
                      condemned;
                      condemned_index = 0;
                      pvcs;
                      pvc_index = 0;
                    }
                  in
                  dispatch_after_list state')))
  | Get_pvc ->
    Option.fold (Object_meta.namespace md)
      ~none:(error_state state, None)
      ~some:(fun namespace ->
        if state.pvc_index < List.length state.pvcs then
          Option.fold
            (List.nth_opt state.pvcs state.pvc_index)
            ~none:(error_state state, None)
            ~some:(fun (pvc : Persistent_volume_claim.t) ->
              Option.fold pvc.metadata.name
                ~none:(error_state state, None)
                ~some:(fun (name : string) ->
                  let req =
                    Io.K_request
                      (Api_method.Get_request
                         {
                           Api_method.key =
                             {
                               Common.kind = Persistent_volume_claim.kind;
                               name;
                               namespace;
                             };
                         })
                  in
                  ({ state with reconcile_step = After_get_pvc }, Some req)))
        else (error_state state, None))
  | After_get_pvc ->
    Option.fold (Io_resp.k_get_resp resp)
      ~none:(error_state state, None)
      ~some:(fun r ->
        Result.fold r
          ~ok:(fun (_ : Dynamic_object.t) ->
            ({ state with reconcile_step = Skip_pvc }, None))
          ~error:(fun (e : Api_method.api_error) ->
            if api_error_is_object_not_found e then
              ({ state with reconcile_step = Create_pvc }, None)
            else (error_state state, None)))
  | Create_pvc ->
    Option.fold (Object_meta.namespace md)
      ~none:(error_state state, None)
      ~some:(fun namespace ->
        if state.pvc_index < List.length state.pvcs then
          Option.fold
            (List.nth_opt state.pvcs state.pvc_index)
            ~none:(error_state state, None)
            ~some:(fun (pvc : Persistent_volume_claim.t) ->
              let req =
                Io.K_request
                  (Api_method.Create_request
                     {
                       Api_method.namespace;
                       obj = Persistent_volume_claim.marshal pvc;
                     })
              in
              ( {
                  state with
                  reconcile_step = After_create_pvc;
                  pvc_index = state.pvc_index + 1;
                },
                Some req ))
        else (error_state state, None))
  | After_create_pvc ->
    Option.fold (Io_resp.k_create_resp resp)
      ~none:(error_state state, None)
      ~some:(fun r ->
        Result.fold r
          ~ok:(fun (_ : Dynamic_object.t) -> create_or_skip_pvc_helper state)
          ~error:(fun (e : Api_method.api_error) ->
            if api_error_is_object_already_exists e then
              create_or_skip_pvc_helper state
            else (error_state state, None)))
  | Skip_pvc ->
    if state.pvc_index < List.length state.pvcs then
      create_or_skip_pvc_helper { state with pvc_index = state.pvc_index + 1 }
    else (error_state state, None)
  | Create_needed ->
    Option.fold (Object_meta.namespace md)
      ~none:(error_state state, None)
      ~some:(fun namespace ->
        if state.needed_index < List.length state.needed then
          let pod = make_pod cr state.needed_index in
          let req =
            Io.K_request
              (Api_method.Create_request
                 { Api_method.namespace; obj = Pod.marshal pod })
          in
          ( {
              state with
              reconcile_step = After_create_needed;
              needed_index = state.needed_index + 1;
            },
            Some req )
        else (error_state state, None))
  | After_create_needed ->
    Option.fold (Io_resp.k_create_resp resp)
      ~none:(error_state state, None)
      ~some:(fun r ->
        Result.fold r
          ~ok:(fun (_ : Dynamic_object.t) ->
            create_or_after_update_needed_helper cr state)
          ~error:(fun (e : Api_method.api_error) ->
            if api_error_is_object_already_exists e then
              create_or_after_update_needed_helper cr state
            else (error_state state, None)))
  | Update_needed ->
    Option.fold (Object_meta.namespace md)
      ~none:(error_state state, None)
      ~some:(fun namespace ->
        if state.needed_index < List.length state.needed then
          Option.fold
            (List.nth_opt state.needed state.needed_index)
            ~none:(error_state state, None)
            ~some:(fun (elt : Pod.t option) ->
              Option.fold elt
                ~none:(error_state state, None)
                ~some:(fun (old_pod : Pod.t) ->
                  let ordinal = state.needed_index in
                  let new_pod =
                    update_storage cr
                      (update_identity cr old_pod ordinal)
                      ordinal
                  in
                  Option.fold
                    (Object_meta.name (Pod.metadata old_pod))
                    ~none:(error_state state, None)
                    ~some:(fun (name : string) ->
                      Option.fold (V_stateful_set.controller_owner_ref cr)
                        ~none:(error_state state, None)
                        ~some:(fun (oref : Owner_reference.t) ->
                          let req =
                            Io.K_request
                              (Api_method.Get_then_update_request
                                 {
                                   Api_method.namespace;
                                   name;
                                   owner_ref = oref;
                                   obj = Pod.marshal new_pod;
                                 })
                          in
                          ( {
                              state with
                              reconcile_step = After_update_needed;
                              needed_index = state.needed_index + 1;
                            },
                            Some req )))))
        else (error_state state, None))
  | After_update_needed ->
    with_ok_resp Io_resp.k_get_then_update_resp state resp
      ~ok:(fun (_ : Dynamic_object.t) ->
        create_or_after_update_needed_helper cr state)
  | Delete_condemned ->
    Option.fold (Object_meta.namespace md)
      ~none:(error_state state, None)
      ~some:(fun namespace ->
        if state.condemned_index < List.length state.condemned then
          Option.fold
            (List.nth_opt state.condemned state.condemned_index)
            ~none:(error_state state, None)
            ~some:(fun (pod : Pod.t) ->
              Option.fold
                (Object_meta.name (Pod.metadata pod))
                ~none:(error_state state, None)
                ~some:(fun (name : string) ->
                  Option.fold (V_stateful_set.controller_owner_ref cr)
                    ~none:(error_state state, None)
                    ~some:(fun (oref : Owner_reference.t) ->
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
                          state with
                          reconcile_step = After_delete_condemned;
                          condemned_index = state.condemned_index + 1;
                        },
                        Some req ))))
        else (error_state state, None))
  | After_delete_condemned ->
    let advance (st : s) : s * Io.void Io.request_view option =
      if st.condemned_index < List.length st.condemned then
        ({ st with reconcile_step = Delete_condemned }, None)
      else ({ st with reconcile_step = Delete_outdated }, None)
    in
    Option.fold (Io_resp.k_get_then_delete_resp resp)
      ~none:(error_state state, None)
      ~some:(fun r ->
        Result.fold r
          ~ok:(fun () -> advance state)
          ~error:(fun (e : Api_method.api_error) ->
            if api_error_is_object_not_found e then advance state
            else (error_state state, None)))
  | Delete_outdated ->
    Option.fold
      (get_largest_unmatched_pods cr state.needed)
      ~none:({ state with reconcile_step = Done }, None)
      ~some:(fun (pod : Pod.t) ->
        Option.fold (Object_meta.namespace md)
          ~none:(error_state state, None)
          ~some:(fun namespace ->
            Option.fold
              (Object_meta.name (Pod.metadata pod))
              ~none:(error_state state, None)
              ~some:(fun (name : string) ->
                Option.fold (V_stateful_set.controller_owner_ref cr)
                  ~none:(error_state state, None)
                  ~some:(fun (oref : Owner_reference.t) ->
                    let req =
                      Io.K_request
                        (Api_method.Get_then_delete_request
                           {
                             Api_method.key =
                               { Common.kind = Pod.kind; name; namespace };
                             owner_ref = oref;
                           })
                    in
                    ( { state with reconcile_step = After_delete_outdated },
                      Some req )))))
  | After_delete_outdated ->
    Option.fold (Io_resp.k_get_then_delete_resp resp)
      ~none:(error_state state, None)
      ~some:(fun r ->
        Result.fold r
          ~ok:(fun () -> ({ state with reconcile_step = Done }, None))
          ~error:(fun (e : Api_method.api_error) ->
            if api_error_is_object_not_found e then
              ({ state with reconcile_step = Done }, None)
            else (error_state state, None)))
  | Done -> (state, None)
  | Error -> (state, None)

module R :
  Reconciler.RECONCILER
    with type k = V_stateful_set.t
     and type s = s
     and type ereq = Io.void
     and type eresp = Io.void = struct
  type nonrec s = s
  type k = V_stateful_set.t
  type ereq = Io.void
  type eresp = Io.void

  let reconcile_init_state = reconcile_init_state
  let reconcile_core = reconcile_core
  let reconcile_done = reconcile_done
  let reconcile_error = reconcile_error
end

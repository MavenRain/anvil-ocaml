(* Anvil source: controllers/vstatefulset_controller/trusted/spec_types.rs
   ([VStatefulSetView] and its [implement_resource_view_trait!] instance) plus
   trusted/exec_types.rs::state_validation.

   VStatefulSet is a SINGLE controller that manages Pods + PVCs directly (unlike
   P9's VDeployment). Its spec is field-for-field the built-in StatefulSetSpecView
   ([VStatefulSetSpecView == StatefulSetSpecView] upstream), so the CR [spec] type
   REUSES {!Stateful_set.ss_spec} and the [status] REUSES
   {!Stateful_set.ss_status} [option] (a VReplicaSet-style non-unit status) — one
   source of truth for the codecs. This view differs from the built-in
   {!Stateful_set} only in three places: [kind] is [Custom_resource "vstatefulset"]
   (NOT the built-in [Stateful_set] object kind), a rich [state_validation], and
   the shared immutable-field [transition_validation]. Realised through
   {!Resource_view.Make}, mirroring {!V_deployment}. *)

type t = {
  metadata : Object_meta.t;
  spec : Stateful_set.ss_spec;
  status : Stateful_set.ss_status option;
}

type spec = Stateful_set.ss_spec
type status = Stateful_set.ss_status option

let kind_name = "vstatefulset"
let kind : Common.kind = Common.Custom_resource kind_name

(* trusted/exec_types.rs: STATEFULSET_POD_NAME_LABEL / STATEFULSET_ORDINAL_LABEL.
   The two reserved label keys a well-formed template must not carry. *)
let pod_name_label = "statefulset.kubernetes.io/pod-name"
let ordinal_label = "apps.kubernetes.io/pod-index"

module R = struct
  type nonrec t = t
  type nonrec spec = spec
  type nonrec status = status

  let kind = kind

  let default () : t =
    {
      metadata = Object_meta.default ();
      spec = Stateful_set.ss_spec_default ();
      status = None;
    }

  let metadata (s : t) : Object_meta.t = s.metadata
  let spec (s : t) : spec = s.spec
  let status (s : t) : status = s.status
  let recombine ~metadata ~spec ~status : t = { metadata; spec; status }

  (* VStatefulSetView.spec is bare, so a spec always marshals to a JSON object. *)
  let marshal_spec (s : spec) : Value.t =
    Value.of_json (Stateful_set.ss_spec_to_json s)

  (* A VStatefulSet always has a spec, so a `Null (or any non-object) Value is a
     decode error. *)
  let unmarshal_spec (v : Value.t) : spec Res.t =
    match Value.json v with
    | `Assoc _ as j -> Stateful_set.ss_spec_of_json j
    | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error
        (Err.Decode_error
           { typ = "v_stateful_set.spec"; detail = "expected object" })

  (* Optional status (VReplicaSet idiom): `None marshals to `Null, a present
     status to its object; unmarshal accepts `Null (-> None) or an object. *)
  let marshal_status (s : status) : Value.t =
    Value.of_json
      (Option.fold ~none:`Null ~some:Stateful_set.ss_status_to_json s)

  let unmarshal_status (v : Value.t) : status Res.t =
    match Value.json v with
    | `Null -> Res.ok None
    | `Assoc _ as j -> Res.map Option.some (Stateful_set.ss_status_of_json j)
    | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error
        (Err.Decode_error
           { typ = "v_stateful_set.status"; detail = "expected object or null" })

  (* trusted/exec_types.rs VStatefulSet::state_validation, ported faithfully as a
     conjunction. Upstream [pvc.state_validation()] is provably [spec is Some]
     (the exec code computes [pvc_sv = vct[idx].spec().is_some()] and asserts it
     equals [vct_view[idx].state_validation()]), so condition 7 inlines
     [Option.is_some pvc.spec] rather than calling a nonexistent
     [Persistent_volume_claim.state_validation]. [pod_management_policy] and the
     [persistent_volume_claim_retention_policy] checks are commented out upstream
     and are OMITTED here. Every option test uses a combinator (fold/is_some),
     never a two-arm match on an option. *)
  let state_validation (s : t) : bool =
    let sp : Stateful_set.ss_spec = s.spec in
    (* 1. selector.match_labels is Some and non-empty. *)
    Option.fold ~none:false
      ~some:(fun ml -> Smap.cardinal ml > 0)
      sp.selector.match_labels
    (* 2. the bare template carries both metadata and spec. *)
    && Option.is_some sp.template.metadata
    && Option.is_some sp.template.spec
    (* 3. the selector matches the template's labels (empty map if absent). *)
    && Option.fold ~none:false
         ~some:(fun (tm : Object_meta.t) ->
           Label_selector.matches sp.selector
             (Option.fold ~none:Smap.empty ~some:(fun m -> m) tm.labels))
         sp.template.metadata
    (* 4. template labels (if any) carry neither reserved key. *)
    && Option.fold ~none:true
         ~some:(fun (tm : Object_meta.t) ->
           Option.fold ~none:true
             ~some:(fun labels ->
               (not (Smap.mem pod_name_label labels))
               && not (Smap.mem ordinal_label labels))
             tm.labels)
         sp.template.metadata
    (* 5. replicas (if set) non-negative. *)
    && Option.fold ~none:true ~some:(fun r -> r >= 0) sp.replicas
    (* 6. update strategy: OnDelete (no rollingUpdate block) or RollingUpdate
       (with partition >= 0 and max_unavailable > 0 when the block is present). *)
    && Option.fold ~none:true
         ~some:(fun (us : Stateful_set.update_strategy) ->
           Option.fold ~none:true
             ~some:(fun (ty : string) ->
               (String.equal ty "OnDelete" && Option.is_none us.rolling_update)
               || (String.equal ty "RollingUpdate"
                  && Option.fold ~none:true
                       ~some:(fun (ru : Stateful_set.rolling_update) ->
                         Option.fold ~none:true
                           ~some:(fun p -> p >= 0)
                           ru.partition
                         && Option.fold ~none:true
                              ~some:(fun m -> m > 0)
                              ru.max_unavailable)
                       us.rolling_update))
             us.type_)
         sp.update_strategy
    (* 7. each volumeClaimTemplate: spec present, name and namespace present, and
       a dash-free name. *)
    && Option.fold ~none:true
         ~some:
           (List.for_all (fun (pvc : Persistent_volume_claim.t) ->
                Option.is_some pvc.spec
                && Option.is_some pvc.metadata.name
                && Option.is_some pvc.metadata.namespace
                && Option.fold ~none:false
                     ~some:(fun n -> not (String.contains n '-'))
                     pvc.metadata.name))
         sp.volume_claim_templates
    (* 8. min_ready_seconds (if set) non-negative. *)
    && Option.fold ~none:true ~some:(fun m -> m >= 0) sp.min_ready_seconds
    (* 9. ordinals.start (if set) non-negative. *)
    && Option.fold ~none:true
         ~some:(fun (o : Stateful_set.ordinals) ->
           Option.fold ~none:true ~some:(fun st -> st >= 0) o.start)
         sp.ordinals

  (* stateful_set.rs:49 immutable-field check: every spec field except
     [replicas], [template] and [persistent_volume_claim_retention_policy] is
     immutable across a transition. The spec type is shared, so we reuse
     {!Stateful_set.ss_spec_immutable_eq} directly (argument order: old, new). *)
  let transition_validation (s : t) ~(old : t) : bool =
    Stateful_set.ss_spec_immutable_eq old.spec s.spec
end

include (
  Resource_view.Make (R) :
    Resource_view.RESOURCE_VIEW
      with type t := t
       and type spec := spec
       and type status := status)

(* spec_types.rs controller_owner_ref. Honest: Anvil unwraps
   metadata.name/metadata.uid under well-formedness; we return None when either
   is absent. *)
let controller_owner_ref (s : t) : Owner_reference.t option =
  Option.bind s.metadata.name (fun name ->
      Option.map
        (fun uid : Owner_reference.t ->
          {
            block_owner_deletion = Some true;
            controller = Some true;
            kind;
            name;
            uid;
          })
        s.metadata.uid)

let make ~metadata ~spec ~status : t = { metadata; spec; status }

let equal (a : t) (b : t) : bool =
  Object_meta.equal a.metadata b.metadata
  && Stateful_set.ss_spec_equal a.spec b.spec
  && Option.equal Stateful_set.ss_status_equal a.status b.status

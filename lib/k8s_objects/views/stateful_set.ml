(* Anvil source: kubernetes_api_objects/spec/stateful_set.rs. The
   StatefulSetView ResourceView instance, realised through {!Resource_view.Make}.
   The nested StatefulSet-only views (ordinals, update-strategy, retention
   policy) live here; the shared LabelSelectorView / PodTemplateSpecView /
   PersistentVolumeClaimView come from their own modules.

   transition_validation is MEANINGFUL here: every spec field except [replicas],
   [template] and [persistent_volume_claim_retention_policy] is immutable across
   a transition (stateful_set.rs:49). *)

(* StatefulSetOrdinalsView. default: start None. *)
type ordinals = { start : int option }

(* RollingUpdateStatefulSetStrategyView. default: both None. *)
type rolling_update = { partition : int option; max_unavailable : int option }

(* StatefulSetUpdateStrategyView. field literally named type_. default: both
   None. *)
type update_strategy = {
  type_ : string option;
  rolling_update : rolling_update option;
}

(* StatefulSetPersistentVolumeClaimRetentionPolicyView. default: both None. *)
type retention_policy = {
  when_deleted : string option;
  when_scaled : string option;
}

(* StatefulSetSpecView. 11 fields; [selector]/[service_name]/[template] are not
   optional. *)
type ss_spec = {
  min_ready_seconds : int option;
  ordinals : ordinals option;
  persistent_volume_claim_retention_policy : retention_policy option;
  pod_management_policy : string option;
  replicas : int option;
  revision_history_limit : int option;
  selector : Label_selector.t;
  service_name : string;
  template : Pod_template_spec.t;
  update_strategy : update_strategy option;
  volume_claim_templates : Persistent_volume_claim.t list option;
}

(* StatefulSetStatusView. Only field: ready_replicas. *)
type ss_status = { ready_replicas : int option }

type t = {
  metadata : Object_meta.t;
  spec : ss_spec option;
  status : ss_status option;
}

type spec = ss_spec option
type status = ss_status option

(* -- StatefulSetOrdinalsView -- *)
let ordinals_default () : ordinals = { start = None }

let ordinals_equal (a : ordinals) (b : ordinals) : bool =
  Option.equal Int.equal a.start b.start

let ordinals_to_json (o : ordinals) : Yojson.Safe.t =
  Json.obj_opt [ ("start", Json.opt Json.int_ o.start) ]

let ordinals_of_json (j : Yojson.Safe.t) : ordinals Res.t =
  let open Res in
  let* start = Json.opt_mem j "start" Json.to_int in
  ok ({ start } : ordinals)

(* -- RollingUpdateStatefulSetStrategyView -- *)
let rolling_update_default () : rolling_update =
  { partition = None; max_unavailable = None }

let rolling_update_equal (a : rolling_update) (b : rolling_update) : bool =
  Option.equal Int.equal a.partition b.partition
  && Option.equal Int.equal a.max_unavailable b.max_unavailable

let rolling_update_to_json (o : rolling_update) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("partition", Json.opt Json.int_ o.partition);
      ("maxUnavailable", Json.opt Json.int_ o.max_unavailable);
    ]

let rolling_update_of_json (j : Yojson.Safe.t) : rolling_update Res.t =
  let open Res in
  let* partition = Json.opt_mem j "partition" Json.to_int in
  let* max_unavailable = Json.opt_mem j "maxUnavailable" Json.to_int in
  ok ({ partition; max_unavailable } : rolling_update)

(* -- StatefulSetUpdateStrategyView -- *)
let update_strategy_default () : update_strategy =
  { type_ = None; rolling_update = None }

let update_strategy_equal (a : update_strategy) (b : update_strategy) : bool =
  Option.equal String.equal a.type_ b.type_
  && Option.equal rolling_update_equal a.rolling_update b.rolling_update

let update_strategy_to_json (o : update_strategy) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("type", Json.opt Json.str o.type_);
      ("rollingUpdate", Json.opt rolling_update_to_json o.rolling_update);
    ]

let update_strategy_of_json (j : Yojson.Safe.t) : update_strategy Res.t =
  let open Res in
  let* type_ = Json.opt_mem j "type" Json.to_str in
  let* rolling_update =
    Json.opt_mem j "rollingUpdate" rolling_update_of_json
  in
  ok ({ type_; rolling_update } : update_strategy)

(* -- StatefulSetPersistentVolumeClaimRetentionPolicyView -- *)
let retention_policy_default () : retention_policy =
  { when_deleted = None; when_scaled = None }

let retention_policy_equal (a : retention_policy) (b : retention_policy) : bool =
  Option.equal String.equal a.when_deleted b.when_deleted
  && Option.equal String.equal a.when_scaled b.when_scaled

let retention_policy_to_json (o : retention_policy) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("whenDeleted", Json.opt Json.str o.when_deleted);
      ("whenScaled", Json.opt Json.str o.when_scaled);
    ]

let retention_policy_of_json (j : Yojson.Safe.t) : retention_policy Res.t =
  let open Res in
  let* when_deleted = Json.opt_mem j "whenDeleted" Json.to_str in
  let* when_scaled = Json.opt_mem j "whenScaled" Json.to_str in
  ok ({ when_deleted; when_scaled } : retention_policy)

(* -- StatefulSetSpecView -- *)
let ss_spec_default () : ss_spec =
  {
    min_ready_seconds = None;
    ordinals = None;
    persistent_volume_claim_retention_policy = None;
    pod_management_policy = None;
    replicas = None;
    revision_history_limit = None;
    selector = Label_selector.default ();
    service_name = "";
    template = Pod_template_spec.default ();
    update_strategy = None;
    volume_claim_templates = None;
  }

let ss_spec_equal (a : ss_spec) (b : ss_spec) : bool =
  Option.equal Int.equal a.min_ready_seconds b.min_ready_seconds
  && Option.equal ordinals_equal a.ordinals b.ordinals
  && Option.equal retention_policy_equal
       a.persistent_volume_claim_retention_policy
       b.persistent_volume_claim_retention_policy
  && Option.equal String.equal a.pod_management_policy b.pod_management_policy
  && Option.equal Int.equal a.replicas b.replicas
  && Option.equal Int.equal a.revision_history_limit b.revision_history_limit
  && Label_selector.equal a.selector b.selector
  && String.equal a.service_name b.service_name
  && Pod_template_spec.equal a.template b.template
  && Option.equal update_strategy_equal a.update_strategy b.update_strategy
  && Option.equal
       (List.equal Persistent_volume_claim.equal)
       a.volume_claim_templates b.volume_claim_templates

(* stateful_set.rs:49 transition_validation: old_spec must equal new_spec on
   every field EXCEPT replicas, template and
   persistent_volume_claim_retention_policy (those three may change). This is
   the immutable-field rejection the confirm-by-mutation test pins. *)
let ss_spec_immutable_eq (old_spec : ss_spec) (new_spec : ss_spec) : bool =
  Option.equal Int.equal old_spec.min_ready_seconds new_spec.min_ready_seconds
  && Option.equal ordinals_equal old_spec.ordinals new_spec.ordinals
  && Option.equal String.equal old_spec.pod_management_policy
       new_spec.pod_management_policy
  && Option.equal Int.equal old_spec.revision_history_limit
       new_spec.revision_history_limit
  && Label_selector.equal old_spec.selector new_spec.selector
  && String.equal old_spec.service_name new_spec.service_name
  && Option.equal update_strategy_equal old_spec.update_strategy
       new_spec.update_strategy
  && Option.equal
       (List.equal Persistent_volume_claim.equal)
       old_spec.volume_claim_templates new_spec.volume_claim_templates

let ss_spec_to_json (o : ss_spec) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("minReadySeconds", Json.opt Json.int_ o.min_ready_seconds);
      ("ordinals", Json.opt ordinals_to_json o.ordinals);
      ( "persistentVolumeClaimRetentionPolicy",
        Json.opt retention_policy_to_json
          o.persistent_volume_claim_retention_policy );
      ("podManagementPolicy", Json.opt Json.str o.pod_management_policy);
      ("replicas", Json.opt Json.int_ o.replicas);
      ("revisionHistoryLimit", Json.opt Json.int_ o.revision_history_limit);
      ("selector", Some (Label_selector.to_json o.selector));
      ("serviceName", Some (Json.str o.service_name));
      ("template", Some (Pod_template_spec.to_json o.template));
      ("updateStrategy", Json.opt update_strategy_to_json o.update_strategy);
      ( "volumeClaimTemplates",
        Json.opt
          (Json.list Persistent_volume_claim.to_json)
          o.volume_claim_templates );
    ]

let ss_spec_of_json (j : Yojson.Safe.t) : ss_spec Res.t =
  let open Res in
  let* min_ready_seconds = Json.opt_mem j "minReadySeconds" Json.to_int in
  let* ordinals = Json.opt_mem j "ordinals" ordinals_of_json in
  let* persistent_volume_claim_retention_policy =
    Json.opt_mem j "persistentVolumeClaimRetentionPolicy"
      retention_policy_of_json
  in
  let* pod_management_policy =
    Json.opt_mem j "podManagementPolicy" Json.to_str
  in
  let* replicas = Json.opt_mem j "replicas" Json.to_int in
  let* revision_history_limit =
    Json.opt_mem j "revisionHistoryLimit" Json.to_int
  in
  let* selector = Json.get j "selector" Label_selector.of_json in
  let* service_name = Json.get j "serviceName" Json.to_str in
  let* template = Json.get j "template" Pod_template_spec.of_json in
  let* update_strategy =
    Json.opt_mem j "updateStrategy" update_strategy_of_json
  in
  let* volume_claim_templates =
    Json.opt_mem j "volumeClaimTemplates"
      (Json.to_list Persistent_volume_claim.of_json)
  in
  ok
    ({
       min_ready_seconds;
       ordinals;
       persistent_volume_claim_retention_policy;
       pod_management_policy;
       replicas;
       revision_history_limit;
       selector;
       service_name;
       template;
       update_strategy;
       volume_claim_templates;
     }
      : ss_spec)

(* -- StatefulSetStatusView -- *)
let ss_status_default () : ss_status = { ready_replicas = None }

let ss_status_equal (a : ss_status) (b : ss_status) : bool =
  Option.equal Int.equal a.ready_replicas b.ready_replicas

let ss_status_to_json (o : ss_status) : Yojson.Safe.t =
  Json.obj_opt [ ("readyReplicas", Json.opt Json.int_ o.ready_replicas) ]

let ss_status_of_json (j : Yojson.Safe.t) : ss_status Res.t =
  let open Res in
  let* ready_replicas = Json.opt_mem j "readyReplicas" Json.to_int in
  ok ({ ready_replicas } : ss_status)

module R = struct
  type nonrec t = t
  type nonrec spec = spec
  type nonrec status = status

  let kind = Common.Stateful_set

  let default () : t =
    { metadata = Object_meta.default (); spec = None; status = None }

  let metadata (s : t) : Object_meta.t = s.metadata
  let spec (s : t) : spec = s.spec
  let status (s : t) : status = s.status
  let recombine ~metadata ~spec ~status : t = { metadata; spec; status }

  let marshal_spec (s : spec) : Value.t =
    Value.of_json (Option.fold ~none:`Null ~some:ss_spec_to_json s)

  let unmarshal_spec (v : Value.t) : spec Res.t =
    match Value.json v with
    | `Null -> Res.ok None
    | `Assoc _ as j -> Res.map Option.some (ss_spec_of_json j)
    | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error
        (Err.Decode_error
           { typ = "stateful_set.spec"; detail = "expected object or null" })

  let marshal_status (s : status) : Value.t =
    Value.of_json (Option.fold ~none:`Null ~some:ss_status_to_json s)

  let unmarshal_status (v : Value.t) : status Res.t =
    match Value.json v with
    | `Null -> Res.ok None
    | `Assoc _ as j -> Res.map Option.some (ss_status_of_json j)
    | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error
        (Err.Decode_error
           { typ = "stateful_set.status"; detail = "expected object or null" })

  (* stateful_set.rs:37 _state_validation: self.spec is Some, and if
     new_spec.replicas is Some then it is >= 0. *)
  let state_validation (s : t) : bool =
    Option.fold ~none:false
      ~some:(fun (sp : ss_spec) ->
        Option.fold ~none:true ~some:(fun r -> r >= 0) sp.replicas)
      s.spec

  (* stateful_set.rs:49 _transition_validation: immutable-field check across the
     old/new specs. Both specs must be present; when either is absent the
     transition cannot be validated and is rejected. *)
  let transition_validation (s : t) ~(old : t) : bool =
    Option.value ~default:false
      (Option.bind s.spec (fun new_spec ->
           Option.map
             (fun old_spec -> ss_spec_immutable_eq old_spec new_spec)
             old.spec))
end

include (
  Resource_view.Make (R) :
    Resource_view.RESOURCE_VIEW
      with type t := t
       and type spec := spec
       and type status := status)

let make ~metadata ~spec ~status : t = { metadata; spec; status }
let with_metadata metadata (s : t) : t = { s with metadata }
let with_spec spec (s : t) : t = { s with spec = Some spec }

let equal (a : t) (b : t) : bool =
  Object_meta.equal a.metadata b.metadata
  && Option.equal ss_spec_equal a.spec b.spec
  && Option.equal ss_status_equal a.status b.status

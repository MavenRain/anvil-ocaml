(* QCheck round-trip properties for the marshalling layer. For ConfigMap, Pod
   and StatefulSet:
     - unmarshal (marshal o) = Ok o            (whole-object codec)
     - unmarshal_spec (marshal_spec s) = Ok s  (spec codec)
     - Value.of_string (Value.to_string v) = Ok v for a marshalled spec value
   plus three DEDICATED codec round-trips the whole-object tests cannot reach:
     - Object_meta.of_json (Object_meta.to_json m) = Ok m
     - Owner_reference.of_json (Owner_reference.to_json o) = Ok o
     - Dynamic_object.of_json (Dynamic_object.to_json d) = Ok d
   (whole-object marshal threads metadata NATIVELY through Dynamic_object, so it
   never exercises Object_meta's JSON codec — the dedicated property must).

   These are the OCaml stand-ins for Anvil's marshal_preserves_* proof
   obligations (see resource_view.mli), which hold for ALL values. So the
   generators populate EVERY optional and nested field (Some/None both drawn),
   exercising every leaf codec — otherwise a miskeyed codec on an unpopulated
   field would pass vacuously. Lists are bounded to 0-2 and strings are small so
   runs stay well under a second. *)

module Gen = QCheck.Gen

let ( let* ) = Gen.bind

let g_string : string Gen.t =
  Gen.oneof_list [ ""; "a"; "b"; "x"; "ns"; "nginx"; "svc" ]

let g_int : int Gen.t = Gen.int_bound 1000
let g_bool : bool Gen.t = Gen.bool
let g_opt (g : 'a Gen.t) : 'a option Gen.t = Gen.option g

(* 0-2 elements: keeps deeply-nested samples bounded. *)
let g_list (g : 'a Gen.t) : 'a list Gen.t = Gen.list_size (Gen.int_bound 2) g

let g_uid : Common.Uid.t Gen.t = Gen.map Common.Uid.of_int (Gen.int_bound 1000)

let g_rv : Common.Resource_version.t Gen.t =
  Gen.map Common.Resource_version.of_int (Gen.int_bound 1000)

let g_smap : string Smap.t Gen.t =
  Gen.map
    (fun kvs ->
      List.fold_left (fun m (k, v) -> Smap.add k v m) Smap.empty kvs)
    (Gen.list_size (Gen.int_bound 3) (Gen.pair g_string g_string))

let g_kind : Common.kind Gen.t =
  Gen.oneof
    [
      Gen.return Common.Config_map;
      Gen.return Common.Daemon_set;
      Gen.return Common.Pod;
      Gen.return Common.Stateful_set;
      Gen.return Common.Secret;
      Gen.map (fun s -> Common.Custom_resource s) g_string;
    ]

let g_owner_ref : Owner_reference.t Gen.t =
  let* block_owner_deletion = g_opt g_bool in
  let* controller = g_opt g_bool in
  let* kind = g_kind in
  let* name = g_string in
  let* uid = g_uid in
  Gen.return
    ({ block_owner_deletion; controller; kind; name; uid } : Owner_reference.t)

(* All ten ObjectMetaView fields, each optional and drawn Some/None. *)
let g_meta : Object_meta.t Gen.t =
  let* name = g_opt g_string in
  let* generate_name = g_opt g_string in
  let* namespace = g_opt g_string in
  let* resource_version = g_opt g_rv in
  let* uid = g_opt g_uid in
  let* labels = g_opt g_smap in
  let* annotations = g_opt g_smap in
  let* owner_references = g_opt (g_list g_owner_ref) in
  let* finalizers = g_opt (g_list g_string) in
  let* deletion_timestamp = g_opt g_string in
  Gen.return
    ({
       name;
       generate_name;
       namespace;
       resource_version;
       uid;
       labels;
       annotations;
       owner_references;
       finalizers;
       deletion_timestamp;
     }
      : Object_meta.t)

let g_ofs : Object_field_selector.t Gen.t =
  let* field_path = g_string in
  let* api_version = g_opt g_string in
  Gen.return ({ field_path; api_version } : Object_field_selector.t)

let g_resource_requirements : Resource_requirements.t Gen.t =
  let* limits = g_opt g_smap in
  let* requests = g_opt g_smap in
  Gen.return ({ limits; requests } : Resource_requirements.t)

(* -- Container nested codecs -- *)
let g_exec_action : Container.exec_action Gen.t =
  let* command = g_opt (g_list g_string) in
  Gen.return ({ command } : Container.exec_action)

let g_tcp : Container.tcp_socket_action Gen.t =
  let* host = g_opt g_string in
  let* port = g_int in
  Gen.return ({ host; port } : Container.tcp_socket_action)

let g_lifecycle_handler : Container.lifecycle_handler Gen.t =
  let* exec_ = g_opt g_exec_action in
  Gen.return ({ exec_ } : Container.lifecycle_handler)

let g_lifecycle : Container.lifecycle Gen.t =
  let* pre_stop = g_opt g_lifecycle_handler in
  Gen.return ({ pre_stop } : Container.lifecycle)

let g_container_port : Container.container_port Gen.t =
  let* container_port = g_int in
  let* name = g_opt g_string in
  let* protocol = g_opt g_string in
  Gen.return ({ container_port; name; protocol } : Container.container_port)

let g_volume_mount : Container.volume_mount Gen.t =
  let* mount_path = g_string in
  let* name = g_string in
  let* read_only = g_opt g_bool in
  let* sub_path = g_opt g_string in
  let* mount_propagation = g_opt g_string in
  Gen.return
    ({ mount_path; name; read_only; sub_path; mount_propagation }
      : Container.volume_mount)

let g_env_var_source : Container.env_var_source Gen.t =
  let* field_ref = g_opt g_ofs in
  Gen.return ({ field_ref } : Container.env_var_source)

let g_env_var : Container.env_var Gen.t =
  let* name = g_string in
  let* value = g_opt g_string in
  let* value_from = g_opt g_env_var_source in
  Gen.return ({ name; value; value_from } : Container.env_var)

let g_probe : Container.probe Gen.t =
  let* exec_ = g_opt g_exec_action in
  let* failure_threshold = g_opt g_int in
  let* initial_delay_seconds = g_opt g_int in
  let* period_seconds = g_opt g_int in
  let* success_threshold = g_opt g_int in
  let* tcp_socket = g_opt g_tcp in
  let* timeout_seconds = g_opt g_int in
  Gen.return
    ({
       exec_;
       failure_threshold;
       initial_delay_seconds;
       period_seconds;
       success_threshold;
       tcp_socket;
       timeout_seconds;
     }
      : Container.probe)

let g_container_security_context : Container.security_context Gen.t =
  Gen.return (Container.security_context_default ())

let g_container : Container.t Gen.t =
  let* env = g_opt (g_list g_env_var) in
  let* image = g_opt g_string in
  let* name = g_string in
  let* ports = g_opt (g_list g_container_port) in
  let* volume_mounts = g_opt (g_list g_volume_mount) in
  let* lifecycle = g_opt g_lifecycle in
  let* resources = g_opt g_resource_requirements in
  let* readiness_probe = g_opt g_probe in
  let* liveness_probe = g_opt g_probe in
  let* command = g_opt (g_list g_string) in
  let* image_pull_policy = g_opt g_string in
  let* args = g_opt (g_list g_string) in
  let* security_context = g_opt g_container_security_context in
  Gen.return
    ({
       env;
       image;
       name;
       ports;
       volume_mounts;
       lifecycle;
       resources;
       readiness_probe;
       liveness_probe;
       command;
       image_pull_policy;
       args;
       security_context;
     }
      : Container.t)

(* -- Volume nested codecs -- *)
let g_key_to_path : Volume.key_to_path Gen.t =
  let* key = g_string in
  let* path = g_string in
  Gen.return ({ key; path } : Volume.key_to_path)

let g_config_map_projection : Volume.config_map_projection Gen.t =
  let* items = g_opt (g_list g_key_to_path) in
  let* name = g_opt g_string in
  Gen.return ({ items; name } : Volume.config_map_projection)

let g_secret_projection : Volume.secret_projection Gen.t =
  let* items = g_opt (g_list g_key_to_path) in
  let* name = g_opt g_string in
  Gen.return ({ items; name } : Volume.secret_projection)

let g_volume_projection : Volume.volume_projection Gen.t =
  let* config_map = g_opt g_config_map_projection in
  let* secret = g_opt g_secret_projection in
  Gen.return ({ config_map; secret } : Volume.volume_projection)

let g_projected_volume_source : Volume.projected_volume_source Gen.t =
  let* sources = g_opt (g_list g_volume_projection) in
  Gen.return ({ sources } : Volume.projected_volume_source)

let g_downward_api_volume_file : Volume.downward_api_volume_file Gen.t =
  let* field_ref = g_opt g_ofs in
  let* path = g_string in
  Gen.return ({ field_ref; path } : Volume.downward_api_volume_file)

let g_downward_api_volume_source : Volume.downward_api_volume_source Gen.t =
  let* items = g_opt (g_list g_downward_api_volume_file) in
  Gen.return ({ items } : Volume.downward_api_volume_source)

let g_host_path : Volume.host_path_volume_source Gen.t =
  let* path = g_string in
  Gen.return ({ path } : Volume.host_path_volume_source)

let g_config_map_vs : Volume.config_map_volume_source Gen.t =
  let* name = g_opt g_string in
  Gen.return ({ name } : Volume.config_map_volume_source)

let g_secret_vs : Volume.secret_volume_source Gen.t =
  let* secret_name = g_opt g_string in
  Gen.return ({ secret_name } : Volume.secret_volume_source)

let g_empty_dir : Volume.empty_dir_volume_source Gen.t =
  let* medium = g_opt g_string in
  let* size_limit = g_opt g_string in
  Gen.return ({ medium; size_limit } : Volume.empty_dir_volume_source)

let g_pvc_vs : Volume.persistent_volume_claim_volume_source Gen.t =
  let* claim_name = g_string in
  let* read_only = g_opt g_bool in
  Gen.return
    ({ claim_name; read_only }
      : Volume.persistent_volume_claim_volume_source)

let g_volume : Volume.t Gen.t =
  let* host_path = g_opt g_host_path in
  let* config_map = g_opt g_config_map_vs in
  let* name = g_string in
  let* projected = g_opt g_projected_volume_source in
  let* secret = g_opt g_secret_vs in
  let* downward_api = g_opt g_downward_api_volume_source in
  let* empty_dir = g_opt g_empty_dir in
  let* persistent_volume_claim = g_opt g_pvc_vs in
  Gen.return
    ({
       host_path;
       config_map;
       name;
       projected;
       secret;
       downward_api;
       empty_dir;
       persistent_volume_claim;
     }
      : Volume.t)

(* -- Ghost (unit) views -- *)
let g_affinity : Affinity.t Gen.t = Gen.return (Affinity.default ())
let g_toleration : Toleration.t Gen.t = Gen.return (Toleration.default ())

let g_local_object_reference : Local_object_reference.t Gen.t =
  Gen.return (Local_object_reference.default ())

let g_pod_security_context : Pod_security_context.t Gen.t =
  Gen.return (Pod_security_context.default ())

(* All seventeen PodSpecView fields, exercising volume / toleration / affinity /
   image-pull-secret codecs alongside the container codecs. *)
let g_pod_spec : Pod_spec.t Gen.t =
  let* affinity = g_opt g_affinity in
  let* containers = g_list g_container in
  let* volumes = g_opt (g_list g_volume) in
  let* init_containers = g_opt (g_list g_container) in
  let* service_account_name = g_opt g_string in
  let* tolerations = g_opt (g_list g_toleration) in
  let* node_selector = g_opt g_smap in
  let* runtime_class_name = g_opt g_string in
  let* dns_policy = g_opt g_string in
  let* priority_class_name = g_opt g_string in
  let* scheduler_name = g_opt g_string in
  let* security_context = g_opt g_pod_security_context in
  let* host_network = g_opt g_bool in
  let* termination_grace_period_seconds = g_opt g_int in
  let* image_pull_secrets = g_opt (g_list g_local_object_reference) in
  let* hostname = g_opt g_string in
  let* subdomain = g_opt g_string in
  Gen.return
    ({
       affinity;
       containers;
       volumes;
       init_containers;
       service_account_name;
       tolerations;
       node_selector;
       runtime_class_name;
       dns_policy;
       priority_class_name;
       scheduler_name;
       security_context;
       host_network;
       termination_grace_period_seconds;
       image_pull_secrets;
       hostname;
       subdomain;
     }
      : Pod_spec.t)

let g_pod : Pod.t Gen.t =
  let* metadata = g_meta in
  let* spec = g_opt g_pod_spec in
  let* status = g_opt (Gen.return ()) in
  Gen.return (Pod.make ~metadata ~spec ~status)

let g_data : string Smap.t option Gen.t = g_opt g_smap

let g_config_map : Config_map.t Gen.t =
  let* metadata = g_meta in
  let* data = g_data in
  Gen.return (Config_map.make ~metadata ~data)

(* -- PersistentVolumeClaim (nested in StatefulSet volume_claim_templates) -- *)
let g_volume_resource_requirements : Volume_resource_requirements.t Gen.t =
  let* limits = g_opt g_smap in
  let* requests = g_opt g_smap in
  Gen.return ({ limits; requests } : Volume_resource_requirements.t)

let g_pvc_spec : Persistent_volume_claim.spec Gen.t =
  let* storage_class_name = g_opt g_string in
  let* access_modes = g_opt (g_list g_string) in
  let* resources = g_opt g_volume_resource_requirements in
  Gen.return
    ({ storage_class_name; access_modes; resources }
      : Persistent_volume_claim.spec)

let g_pvc_status : Persistent_volume_claim.status Gen.t =
  Gen.return (Persistent_volume_claim.status_default ())

let g_pvc : Persistent_volume_claim.t Gen.t =
  let* metadata = g_meta in
  let* spec = g_opt g_pvc_spec in
  let* status = g_opt g_pvc_status in
  Gen.return ({ metadata; spec; status } : Persistent_volume_claim.t)

let g_pod_template : Pod_template_spec.t Gen.t =
  let* metadata = g_opt g_meta in
  let* spec = g_opt g_pod_spec in
  Gen.return ({ metadata; spec } : Pod_template_spec.t)

let g_label_selector : Label_selector.t Gen.t =
  let* match_labels = g_opt g_smap in
  Gen.return ({ match_labels } : Label_selector.t)

(* -- StatefulSet nested codecs -- *)
let g_ordinals : Stateful_set.ordinals Gen.t =
  let* start = g_opt g_int in
  Gen.return ({ start } : Stateful_set.ordinals)

let g_rolling_update : Stateful_set.rolling_update Gen.t =
  let* partition = g_opt g_int in
  let* max_unavailable = g_opt g_int in
  Gen.return ({ partition; max_unavailable } : Stateful_set.rolling_update)

let g_update_strategy : Stateful_set.update_strategy Gen.t =
  let* type_ = g_opt g_string in
  let* rolling_update = g_opt g_rolling_update in
  Gen.return ({ type_; rolling_update } : Stateful_set.update_strategy)

let g_retention_policy : Stateful_set.retention_policy Gen.t =
  let* when_deleted = g_opt g_string in
  let* when_scaled = g_opt g_string in
  Gen.return ({ when_deleted; when_scaled } : Stateful_set.retention_policy)

(* All eleven StatefulSetSpecView fields, including the four the shallow
   generator omitted: ordinals, retention policy, update strategy (with nested
   rolling_update) and volume_claim_templates. *)
let g_ss_spec : Stateful_set.ss_spec Gen.t =
  let* min_ready_seconds = g_opt g_int in
  let* ordinals = g_opt g_ordinals in
  let* persistent_volume_claim_retention_policy = g_opt g_retention_policy in
  let* pod_management_policy = g_opt g_string in
  let* replicas = g_opt g_int in
  let* revision_history_limit = g_opt g_int in
  let* selector = g_label_selector in
  let* service_name = g_string in
  let* template = g_pod_template in
  let* update_strategy = g_opt g_update_strategy in
  let* volume_claim_templates = g_opt (g_list g_pvc) in
  Gen.return
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
      : Stateful_set.ss_spec)

let g_ss_status : Stateful_set.ss_status Gen.t =
  let* ready_replicas = g_opt g_int in
  Gen.return ({ ready_replicas } : Stateful_set.ss_status)

let g_ss : Stateful_set.t Gen.t =
  let* metadata = g_meta in
  let* spec = g_opt g_ss_spec in
  let* status = g_opt g_ss_status in
  Gen.return (Stateful_set.make ~metadata ~spec ~status)

(* A non-trivial marshalled Value: the JSON of a populated PodSpec, so a
   Dynamic_object's spec/status carry nested objects and lists whose order the
   order-sensitive Value.equal must preserve. *)
let g_json_value : Yojson.Safe.t Gen.t = Gen.map Pod_spec.to_json g_pod_spec

let g_dynamic_object : Dynamic_object.t Gen.t =
  let* kind = g_kind in
  let* metadata = g_meta in
  let* spec = g_json_value in
  let* status = g_json_value in
  Gen.return
    (Dynamic_object.make ~kind ~metadata ~spec:(Value.of_json spec)
       ~status:(Value.of_json status))

let prop_roundtrip name gen equal marshal unmarshal =
  QCheck.Test.make ~count:200 ~name (QCheck.make gen) (fun o ->
      Result.fold ~ok:(equal o) ~error:(fun _ -> false) (unmarshal (marshal o)))

let prop_spec_roundtrip name gen equal marshal_spec unmarshal_spec =
  QCheck.Test.make ~count:200 ~name (QCheck.make gen) (fun s ->
      Result.fold ~ok:(equal s)
        ~error:(fun _ -> false)
        (unmarshal_spec (marshal_spec s)))

let prop_value_string name gen marshal_spec =
  QCheck.Test.make ~count:200 ~name (QCheck.make gen) (fun s ->
      let v = marshal_spec s in
      Result.fold ~ok:(Value.equal v)
        ~error:(fun _ -> false)
        (Value.of_string (Value.to_string v)))

let tests =
  [
    prop_roundtrip "config_map roundtrip" g_config_map Config_map.equal
      Config_map.marshal Config_map.unmarshal;
    prop_spec_roundtrip "config_map spec" g_data
      (Option.equal (Smap.equal String.equal))
      Config_map.marshal_spec Config_map.unmarshal_spec;
    prop_value_string "config_map value" g_data Config_map.marshal_spec;
    prop_roundtrip "pod roundtrip" g_pod Pod.equal Pod.marshal Pod.unmarshal;
    prop_spec_roundtrip "pod spec"
      (g_opt g_pod_spec)
      (Option.equal Pod_spec.equal)
      Pod.marshal_spec Pod.unmarshal_spec;
    prop_value_string "pod value" (g_opt g_pod_spec) Pod.marshal_spec;
    prop_roundtrip "stateful_set roundtrip" g_ss Stateful_set.equal
      Stateful_set.marshal Stateful_set.unmarshal;
    prop_spec_roundtrip "stateful_set spec"
      (g_opt g_ss_spec)
      (Option.equal Stateful_set.ss_spec_equal)
      Stateful_set.marshal_spec Stateful_set.unmarshal_spec;
    prop_value_string "stateful_set value"
      (g_opt g_ss_spec)
      Stateful_set.marshal_spec;
    (* Dedicated codec round-trips (metadata / owner-refs / dynamic object are
       not reached by the whole-object marshal, which threads them natively). *)
    prop_roundtrip "object_meta codec" g_meta Object_meta.equal
      Object_meta.to_json Object_meta.of_json;
    prop_roundtrip "owner_reference codec" g_owner_ref Owner_reference.equal
      Owner_reference.to_json Owner_reference.of_json;
    prop_roundtrip "dynamic_object codec" g_dynamic_object Dynamic_object.equal
      Dynamic_object.to_json Dynamic_object.of_json;
  ]

let () =
  Alcotest.run "marshal_props"
    [ ("props", List.map (fun t -> QCheck_alcotest.to_alcotest t) tests) ]

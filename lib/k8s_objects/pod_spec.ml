(* Anvil source: kubernetes_api_objects/spec/pod.rs [PodSpecView] (pod.rs:51).
   The 17-field pod spec, shared by [Pod] (as its spec) and by
   [Pod_template_spec] (PodTemplateSpecView.spec). Its own module so both can
   reuse it without a views/ dependency. [containers] is a plain list (default
   empty); every other field is optional. *)

type t = {
  affinity : Affinity.t option;
  containers : Container.t list;
  volumes : Volume.t list option;
  init_containers : Container.t list option;
  service_account_name : string option;
  tolerations : Toleration.t list option;
  node_selector : string Smap.t option;
  runtime_class_name : string option;
  dns_policy : string option;
  priority_class_name : string option;
  scheduler_name : string option;
  security_context : Pod_security_context.t option;
  host_network : bool option;
  termination_grace_period_seconds : int option;
  image_pull_secrets : Local_object_reference.t list option;
  hostname : string option;
  subdomain : string option;
}

let default () : t =
  {
    affinity = None;
    containers = [];
    volumes = None;
    init_containers = None;
    service_account_name = None;
    tolerations = None;
    node_selector = None;
    runtime_class_name = None;
    dns_policy = None;
    priority_class_name = None;
    scheduler_name = None;
    security_context = None;
    host_network = None;
    termination_grace_period_seconds = None;
    image_pull_secrets = None;
    hostname = None;
    subdomain = None;
  }

let equal (a : t) (b : t) : bool =
  Option.equal Affinity.equal a.affinity b.affinity
  && List.equal Container.equal a.containers b.containers
  && Option.equal (List.equal Volume.equal) a.volumes b.volumes
  && Option.equal (List.equal Container.equal) a.init_containers
       b.init_containers
  && Option.equal String.equal a.service_account_name b.service_account_name
  && Option.equal (List.equal Toleration.equal) a.tolerations b.tolerations
  && Option.equal (Smap.equal String.equal) a.node_selector b.node_selector
  && Option.equal String.equal a.runtime_class_name b.runtime_class_name
  && Option.equal String.equal a.dns_policy b.dns_policy
  && Option.equal String.equal a.priority_class_name b.priority_class_name
  && Option.equal String.equal a.scheduler_name b.scheduler_name
  && Option.equal Pod_security_context.equal a.security_context
       b.security_context
  && Option.equal Bool.equal a.host_network b.host_network
  && Option.equal Int.equal a.termination_grace_period_seconds
       b.termination_grace_period_seconds
  && Option.equal (List.equal Local_object_reference.equal) a.image_pull_secrets
       b.image_pull_secrets
  && Option.equal String.equal a.hostname b.hostname
  && Option.equal String.equal a.subdomain b.subdomain

let to_json (o : t) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("affinity", Json.opt Affinity.to_json o.affinity);
      ("containers", Some (Json.list Container.to_json o.containers));
      ("volumes", Json.opt (Json.list Volume.to_json) o.volumes);
      ( "initContainers",
        Json.opt (Json.list Container.to_json) o.init_containers );
      ("serviceAccountName", Json.opt Json.str o.service_account_name);
      ("tolerations", Json.opt (Json.list Toleration.to_json) o.tolerations);
      ("nodeSelector", Json.opt Json.smap o.node_selector);
      ("runtimeClassName", Json.opt Json.str o.runtime_class_name);
      ("dnsPolicy", Json.opt Json.str o.dns_policy);
      ("priorityClassName", Json.opt Json.str o.priority_class_name);
      ("schedulerName", Json.opt Json.str o.scheduler_name);
      ( "securityContext",
        Json.opt Pod_security_context.to_json o.security_context );
      ("hostNetwork", Json.opt Json.bool_ o.host_network);
      ( "terminationGracePeriodSeconds",
        Json.opt Json.int_ o.termination_grace_period_seconds );
      ( "imagePullSecrets",
        Json.opt (Json.list Local_object_reference.to_json) o.image_pull_secrets
      );
      ("hostname", Json.opt Json.str o.hostname);
      ("subdomain", Json.opt Json.str o.subdomain);
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* affinity = Json.opt_mem j "affinity" Affinity.of_json in
  let* containers =
    Json.opt_mem j "containers" (Json.to_list Container.of_json)
  in
  let containers = Option.value ~default:[] containers in
  let* volumes = Json.opt_mem j "volumes" (Json.to_list Volume.of_json) in
  let* init_containers =
    Json.opt_mem j "initContainers" (Json.to_list Container.of_json)
  in
  let* service_account_name =
    Json.opt_mem j "serviceAccountName" Json.to_str
  in
  let* tolerations =
    Json.opt_mem j "tolerations" (Json.to_list Toleration.of_json)
  in
  let* node_selector = Json.opt_mem j "nodeSelector" Json.to_smap in
  let* runtime_class_name = Json.opt_mem j "runtimeClassName" Json.to_str in
  let* dns_policy = Json.opt_mem j "dnsPolicy" Json.to_str in
  let* priority_class_name = Json.opt_mem j "priorityClassName" Json.to_str in
  let* scheduler_name = Json.opt_mem j "schedulerName" Json.to_str in
  let* security_context =
    Json.opt_mem j "securityContext" Pod_security_context.of_json
  in
  let* host_network = Json.opt_mem j "hostNetwork" Json.to_bool in
  let* termination_grace_period_seconds =
    Json.opt_mem j "terminationGracePeriodSeconds" Json.to_int
  in
  let* image_pull_secrets =
    Json.opt_mem j "imagePullSecrets"
      (Json.to_list Local_object_reference.of_json)
  in
  let* hostname = Json.opt_mem j "hostname" Json.to_str in
  let* subdomain = Json.opt_mem j "subdomain" Json.to_str in
  ok
    {
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

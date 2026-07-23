(* Anvil source: kubernetes_api_objects/spec/container.rs. The tightly-coupled
   container types: ContainerView plus its nested probe/lifecycle/env/port/mount
   views. ObjectFieldSelectorView (shared with [Volume]) and
   ResourceRequirementsView live in their own modules. Each nested type gets its
   own <type>_default / <type>_equal / <type>_to_json / <type>_of_json; the bare
   [default]/[equal]/[to_json]/[of_json] are ContainerView's. *)

(* container.rs:346 ExecActionView. default: command None. *)
type exec_action = { command : string list option }

(* container.rs:365 TCPSocketActionView. default: host None, port 0. *)
type tcp_socket_action = { host : string option; port : int }

(* container.rs:162 LifecycleHandlerView. field literally named exec_. *)
type lifecycle_handler = { exec_ : exec_action option }

(* container.rs:143 LifecycleView. default: pre_stop None. *)
type lifecycle = { pre_stop : lifecycle_handler option }

(* container.rs:181 ContainerPortView. default: container_port 0, rest None. *)
type container_port = {
  container_port : int;
  name : string option;
  protocol : string option;
}

(* container.rs:218 VolumeMountView. default: mount_path/name "", read_only
   Some false, rest None. *)
type volume_mount = {
  mount_path : string;
  name : string;
  read_only : bool option;
  sub_path : string option;
  mount_propagation : string option;
}

(* container.rs:430 EnvVarSourceView. default: field_ref None. *)
type env_var_source = { field_ref : Object_field_selector.t option }

(* container.rs:393 EnvVarView. default: name "", value/value_from None. *)
type env_var = {
  name : string;
  value : string option;
  value_from : env_var_source option;
}

(* container.rs:273 ProbeView. 7 fields, default all None. *)
type probe = {
  exec_ : exec_action option;
  failure_threshold : int option;
  initial_delay_seconds : int option;
  period_seconds : int option;
  success_threshold : int option;
  tcp_socket : tcp_socket_action option;
  timeout_seconds : int option;
}

(* container.rs:449 SecurityContextView. Ghost placeholder struct `{}`;
   unit/empty. Distinct from PodSecurityContextView. *)
type security_context = unit

(* container.rs:9 ContainerView. 13 fields; default: name "", rest None. *)
type t = {
  env : env_var list option;
  image : string option;
  name : string;
  ports : container_port list option;
  volume_mounts : volume_mount list option;
  lifecycle : lifecycle option;
  resources : Resource_requirements.t option;
  readiness_probe : probe option;
  liveness_probe : probe option;
  command : string list option;
  image_pull_policy : string option;
  args : string list option;
  security_context : security_context option;
}

(* -- ExecActionView -- *)
let exec_action_default () : exec_action = { command = None }

let exec_action_equal (a : exec_action) (b : exec_action) : bool =
  Option.equal (List.equal String.equal) a.command b.command

let exec_action_to_json (o : exec_action) : Yojson.Safe.t =
  Json.obj_opt [ ("command", Json.opt (Json.list Json.str) o.command) ]

let exec_action_of_json (j : Yojson.Safe.t) : exec_action Res.t =
  let open Res in
  let* command = Json.opt_mem j "command" (Json.to_list Json.to_str) in
  ok ({ command } : exec_action)

(* -- TCPSocketActionView -- *)
let tcp_socket_action_default () : tcp_socket_action = { host = None; port = 0 }

let tcp_socket_action_equal (a : tcp_socket_action) (b : tcp_socket_action) :
    bool =
  Option.equal String.equal a.host b.host && Int.equal a.port b.port

let tcp_socket_action_to_json (o : tcp_socket_action) : Yojson.Safe.t =
  Json.obj_opt
    [ ("host", Json.opt Json.str o.host); ("port", Some (Json.int_ o.port)) ]

let tcp_socket_action_of_json (j : Yojson.Safe.t) : tcp_socket_action Res.t =
  let open Res in
  let* host = Json.opt_mem j "host" Json.to_str in
  let* port = Json.get j "port" Json.to_int in
  ok { host; port }

(* -- LifecycleHandlerView -- *)
let lifecycle_handler_default () : lifecycle_handler = { exec_ = None }

let lifecycle_handler_equal (a : lifecycle_handler) (b : lifecycle_handler) :
    bool =
  Option.equal exec_action_equal a.exec_ b.exec_

let lifecycle_handler_to_json (o : lifecycle_handler) : Yojson.Safe.t =
  Json.obj_opt [ ("exec", Json.opt exec_action_to_json o.exec_) ]

let lifecycle_handler_of_json (j : Yojson.Safe.t) : lifecycle_handler Res.t =
  let open Res in
  let* exec_ = Json.opt_mem j "exec" exec_action_of_json in
  ok ({ exec_ } : lifecycle_handler)

(* -- LifecycleView -- *)
let lifecycle_default () : lifecycle = { pre_stop = None }

let lifecycle_equal (a : lifecycle) (b : lifecycle) : bool =
  Option.equal lifecycle_handler_equal a.pre_stop b.pre_stop

let lifecycle_to_json (o : lifecycle) : Yojson.Safe.t =
  Json.obj_opt [ ("preStop", Json.opt lifecycle_handler_to_json o.pre_stop) ]

let lifecycle_of_json (j : Yojson.Safe.t) : lifecycle Res.t =
  let open Res in
  let* pre_stop = Json.opt_mem j "preStop" lifecycle_handler_of_json in
  ok ({ pre_stop } : lifecycle)

(* -- ContainerPortView -- *)
let container_port_default () : container_port =
  { container_port = 0; name = None; protocol = None }

let container_port_equal (a : container_port) (b : container_port) : bool =
  Int.equal a.container_port b.container_port
  && Option.equal String.equal a.name b.name
  && Option.equal String.equal a.protocol b.protocol

let container_port_to_json (o : container_port) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("containerPort", Some (Json.int_ o.container_port));
      ("name", Json.opt Json.str o.name);
      ("protocol", Json.opt Json.str o.protocol);
    ]

let container_port_of_json (j : Yojson.Safe.t) : container_port Res.t =
  let open Res in
  let* container_port = Json.get j "containerPort" Json.to_int in
  let* name = Json.opt_mem j "name" Json.to_str in
  let* protocol = Json.opt_mem j "protocol" Json.to_str in
  ok ({ container_port; name; protocol } : container_port)

(* -- VolumeMountView -- *)
let volume_mount_default () : volume_mount =
  {
    mount_path = "";
    name = "";
    read_only = Some false;
    sub_path = None;
    mount_propagation = None;
  }

let volume_mount_equal (a : volume_mount) (b : volume_mount) : bool =
  String.equal a.mount_path b.mount_path
  && String.equal a.name b.name
  && Option.equal Bool.equal a.read_only b.read_only
  && Option.equal String.equal a.sub_path b.sub_path
  && Option.equal String.equal a.mount_propagation b.mount_propagation

let volume_mount_to_json (o : volume_mount) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("mountPath", Some (Json.str o.mount_path));
      ("name", Some (Json.str o.name));
      ("readOnly", Json.opt Json.bool_ o.read_only);
      ("subPath", Json.opt Json.str o.sub_path);
      ("mountPropagation", Json.opt Json.str o.mount_propagation);
    ]

let volume_mount_of_json (j : Yojson.Safe.t) : volume_mount Res.t =
  let open Res in
  let* mount_path = Json.get j "mountPath" Json.to_str in
  let* name = Json.get j "name" Json.to_str in
  let* read_only = Json.opt_mem j "readOnly" Json.to_bool in
  let* sub_path = Json.opt_mem j "subPath" Json.to_str in
  let* mount_propagation = Json.opt_mem j "mountPropagation" Json.to_str in
  ok ({ mount_path; name; read_only; sub_path; mount_propagation } : volume_mount)

(* -- EnvVarSourceView -- *)
let env_var_source_default () : env_var_source = { field_ref = None }

let env_var_source_equal (a : env_var_source) (b : env_var_source) : bool =
  Option.equal Object_field_selector.equal a.field_ref b.field_ref

let env_var_source_to_json (o : env_var_source) : Yojson.Safe.t =
  Json.obj_opt
    [ ("fieldRef", Json.opt Object_field_selector.to_json o.field_ref) ]

let env_var_source_of_json (j : Yojson.Safe.t) : env_var_source Res.t =
  let open Res in
  let* field_ref = Json.opt_mem j "fieldRef" Object_field_selector.of_json in
  ok ({ field_ref } : env_var_source)

(* -- EnvVarView -- *)
let env_var_default () : env_var = { name = ""; value = None; value_from = None }

let env_var_equal (a : env_var) (b : env_var) : bool =
  String.equal a.name b.name
  && Option.equal String.equal a.value b.value
  && Option.equal env_var_source_equal a.value_from b.value_from

let env_var_to_json (o : env_var) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("name", Some (Json.str o.name));
      ("value", Json.opt Json.str o.value);
      ("valueFrom", Json.opt env_var_source_to_json o.value_from);
    ]

let env_var_of_json (j : Yojson.Safe.t) : env_var Res.t =
  let open Res in
  let* name = Json.get j "name" Json.to_str in
  let* value = Json.opt_mem j "value" Json.to_str in
  let* value_from = Json.opt_mem j "valueFrom" env_var_source_of_json in
  ok ({ name; value; value_from } : env_var)

(* -- ProbeView -- *)
let probe_default () : probe =
  {
    exec_ = None;
    failure_threshold = None;
    initial_delay_seconds = None;
    period_seconds = None;
    success_threshold = None;
    tcp_socket = None;
    timeout_seconds = None;
  }

let probe_equal (a : probe) (b : probe) : bool =
  Option.equal exec_action_equal a.exec_ b.exec_
  && Option.equal Int.equal a.failure_threshold b.failure_threshold
  && Option.equal Int.equal a.initial_delay_seconds b.initial_delay_seconds
  && Option.equal Int.equal a.period_seconds b.period_seconds
  && Option.equal Int.equal a.success_threshold b.success_threshold
  && Option.equal tcp_socket_action_equal a.tcp_socket b.tcp_socket
  && Option.equal Int.equal a.timeout_seconds b.timeout_seconds

let probe_to_json (o : probe) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("exec", Json.opt exec_action_to_json o.exec_);
      ("failureThreshold", Json.opt Json.int_ o.failure_threshold);
      ("initialDelaySeconds", Json.opt Json.int_ o.initial_delay_seconds);
      ("periodSeconds", Json.opt Json.int_ o.period_seconds);
      ("successThreshold", Json.opt Json.int_ o.success_threshold);
      ("tcpSocket", Json.opt tcp_socket_action_to_json o.tcp_socket);
      ("timeoutSeconds", Json.opt Json.int_ o.timeout_seconds);
    ]

let probe_of_json (j : Yojson.Safe.t) : probe Res.t =
  let open Res in
  let* exec_ = Json.opt_mem j "exec" exec_action_of_json in
  let* failure_threshold = Json.opt_mem j "failureThreshold" Json.to_int in
  let* initial_delay_seconds =
    Json.opt_mem j "initialDelaySeconds" Json.to_int
  in
  let* period_seconds = Json.opt_mem j "periodSeconds" Json.to_int in
  let* success_threshold = Json.opt_mem j "successThreshold" Json.to_int in
  let* tcp_socket = Json.opt_mem j "tcpSocket" tcp_socket_action_of_json in
  let* timeout_seconds = Json.opt_mem j "timeoutSeconds" Json.to_int in
  ok
    ({
       exec_;
       failure_threshold;
       initial_delay_seconds;
       period_seconds;
       success_threshold;
       tcp_socket;
       timeout_seconds;
     }
      : probe)

(* -- SecurityContextView (ghost) -- *)
let security_context_default () : security_context = ()

let security_context_equal (_ : security_context) (_ : security_context) : bool =
  true

let security_context_to_json (_ : security_context) : Yojson.Safe.t = `Assoc []

(* A present ghost value marshals to an object, so decoding shape-checks for one
   (rejecting every other JSON constructor) rather than accepting any JSON. *)
let security_context_of_json (j : Yojson.Safe.t) : security_context Res.t =
  match j with
  | `Assoc _ -> Res.ok ()
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
    Res.error
      (Err.Decode_error { typ = "SecurityContext"; detail = "expected an object" })

(* -- ContainerView -- *)
let default () : t =
  {
    env = None;
    image = None;
    name = "";
    ports = None;
    volume_mounts = None;
    lifecycle = None;
    resources = None;
    readiness_probe = None;
    liveness_probe = None;
    command = None;
    image_pull_policy = None;
    args = None;
    security_context = None;
  }

let equal (a : t) (b : t) : bool =
  Option.equal (List.equal env_var_equal) a.env b.env
  && Option.equal String.equal a.image b.image
  && String.equal a.name b.name
  && Option.equal (List.equal container_port_equal) a.ports b.ports
  && Option.equal (List.equal volume_mount_equal) a.volume_mounts b.volume_mounts
  && Option.equal lifecycle_equal a.lifecycle b.lifecycle
  && Option.equal Resource_requirements.equal a.resources b.resources
  && Option.equal probe_equal a.readiness_probe b.readiness_probe
  && Option.equal probe_equal a.liveness_probe b.liveness_probe
  && Option.equal (List.equal String.equal) a.command b.command
  && Option.equal String.equal a.image_pull_policy b.image_pull_policy
  && Option.equal (List.equal String.equal) a.args b.args
  && Option.equal security_context_equal a.security_context b.security_context

let to_json (o : t) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("env", Json.opt (Json.list env_var_to_json) o.env);
      ("image", Json.opt Json.str o.image);
      ("name", Some (Json.str o.name));
      ("ports", Json.opt (Json.list container_port_to_json) o.ports);
      ( "volumeMounts",
        Json.opt (Json.list volume_mount_to_json) o.volume_mounts );
      ("lifecycle", Json.opt lifecycle_to_json o.lifecycle);
      ("resources", Json.opt Resource_requirements.to_json o.resources);
      ("readinessProbe", Json.opt probe_to_json o.readiness_probe);
      ("livenessProbe", Json.opt probe_to_json o.liveness_probe);
      ("command", Json.opt (Json.list Json.str) o.command);
      ("imagePullPolicy", Json.opt Json.str o.image_pull_policy);
      ("args", Json.opt (Json.list Json.str) o.args);
      ("securityContext", Json.opt security_context_to_json o.security_context);
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* env = Json.opt_mem j "env" (Json.to_list env_var_of_json) in
  let* image = Json.opt_mem j "image" Json.to_str in
  let* name = Json.get j "name" Json.to_str in
  let* ports = Json.opt_mem j "ports" (Json.to_list container_port_of_json) in
  let* volume_mounts =
    Json.opt_mem j "volumeMounts" (Json.to_list volume_mount_of_json)
  in
  let* lifecycle = Json.opt_mem j "lifecycle" lifecycle_of_json in
  let* resources = Json.opt_mem j "resources" Resource_requirements.of_json in
  let* readiness_probe = Json.opt_mem j "readinessProbe" probe_of_json in
  let* liveness_probe = Json.opt_mem j "livenessProbe" probe_of_json in
  let* command = Json.opt_mem j "command" (Json.to_list Json.to_str) in
  let* image_pull_policy = Json.opt_mem j "imagePullPolicy" Json.to_str in
  let* args = Json.opt_mem j "args" (Json.to_list Json.to_str) in
  let* security_context =
    Json.opt_mem j "securityContext" security_context_of_json
  in
  ok
    {
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

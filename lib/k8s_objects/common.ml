(* Anvil source: kubernetes_api_objects/spec/common.rs. Implements the
   interface frozen in common.mli. *)

module Uid = struct
  type t = int

  let of_int x = x
  let to_int x = x
  let equal = Int.equal
end

module Resource_version = struct
  type t = int

  let of_int x = x
  let to_int x = x
  let equal = Int.equal
end

module Generate_name_counter = struct
  type t = int

  let of_int x = x
  let to_int x = x
  let equal = Int.equal
end

type kind =
  | Config_map
  | Custom_resource of string
  | Daemon_set
  | Persistent_volume_claim
  | Pod
  | Role
  | Role_binding
  | Stateful_set
  | Service
  | Service_account
  | Secret

let equal_kind (a : kind) (b : kind) : bool =
  match (a, b) with
  | Config_map, Config_map -> true
  | Custom_resource s1, Custom_resource s2 -> String.equal s1 s2
  | Daemon_set, Daemon_set -> true
  | Persistent_volume_claim, Persistent_volume_claim -> true
  | Pod, Pod -> true
  | Role, Role -> true
  | Role_binding, Role_binding -> true
  | Stateful_set, Stateful_set -> true
  | Service, Service -> true
  | Service_account, Service_account -> true
  | Secret, Secret -> true
  | ( ( Config_map | Custom_resource _ | Daemon_set | Persistent_volume_claim
      | Pod | Role | Role_binding | Stateful_set | Service | Service_account
      | Secret ),
      _ ) ->
    false

let show_kind (k : kind) : string =
  match k with
  | Config_map -> "ConfigMap"
  | Custom_resource s -> "CustomResource(" ^ s ^ ")"
  | Daemon_set -> "DaemonSet"
  | Persistent_volume_claim -> "PersistentVolumeClaim"
  | Pod -> "Pod"
  | Role -> "Role"
  | Role_binding -> "RoleBinding"
  | Stateful_set -> "StatefulSet"
  | Service -> "Service"
  | Service_account -> "ServiceAccount"
  | Secret -> "Secret"

type object_ref = { kind : kind; name : string; namespace : string }

let equal_object_ref (a : object_ref) (b : object_ref) : bool =
  equal_kind a.kind b.kind
  && String.equal a.name b.name
  && String.equal a.namespace b.namespace

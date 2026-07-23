(* Anvil source: kubernetes_api_objects/spec/owner_reference.rs. *)

type t = {
  block_owner_deletion : bool option;
  controller : bool option;
  kind : Common.kind;
  name : string;
  uid : Common.Uid.t;
}

(* Anvil's default() is uninterpreted; this is an all-empty placeholder. *)
let default () : t =
  {
    block_owner_deletion = None;
    controller = None;
    kind = Common.Custom_resource "";
    name = "";
    uid = Common.Uid.of_int 0;
  }

let to_object_reference (o : t) ~(namespace : string) : Common.object_ref =
  { Common.kind = o.kind; namespace; name = o.name }

let is_controller (o : t) : bool = Option.value ~default:false o.controller

let eq_without_uid (a : t) (b : t) : bool =
  Option.equal Bool.equal a.controller b.controller
  && Option.equal Bool.equal a.block_owner_deletion b.block_owner_deletion
  && Common.equal_kind a.kind b.kind
  && String.equal a.name b.name

let equal (a : t) (b : t) : bool =
  eq_without_uid a b && Common.Uid.equal a.uid b.uid

let to_json (o : t) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("blockOwnerDeletion", Json.opt Json.bool_ o.block_owner_deletion);
      ("controller", Json.opt Json.bool_ o.controller);
      ("kind", Some (Json.kind_to_json o.kind));
      ("name", Some (Json.str o.name));
      ("uid", Some (Json.int_ (Common.Uid.to_int o.uid)));
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* block_owner_deletion = Json.opt_mem j "blockOwnerDeletion" Json.to_bool in
  let* controller = Json.opt_mem j "controller" Json.to_bool in
  let* kind = Json.get j "kind" Json.kind_of_json in
  let* name = Json.get j "name" Json.to_str in
  let* uid = Json.get j "uid" Json.to_int in
  ok
    {
      block_owner_deletion;
      controller;
      kind;
      name;
      uid = Common.Uid.of_int uid;
    }

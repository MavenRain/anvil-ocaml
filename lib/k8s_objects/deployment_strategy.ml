(* Anvil source: controllers/vdeployment_controller/trusted/spec_types.rs
   ([DeploymentStrategyView] + [RollingUpdateDeploymentView]). A plain field view
   (like Label_selector / Pod_template_spec), NOT a Resource_view. The VDeployment
   reconcile_core does not read the strategy; it is carried in the spec and
   constrained by V_deployment.state_validation for fidelity with Anvil's model. *)

type strategy_type =
  | Recreate
  | Rolling_update

type rolling_update = {
  max_surge : int option;
  max_unavailable : int option;
}

type t = {
  type_ : strategy_type option;
  rolling_update : rolling_update option;
}

let default () : t = { type_ = None; rolling_update = None }

(* strategy_type is a genuine 2-constructor sum: enumerate all four tuple cases
   explicitly, no wildcard. *)
let strategy_type_equal (a : strategy_type) (b : strategy_type) : bool =
  match (a, b) with
  | Recreate, Recreate -> true
  | Rolling_update, Rolling_update -> true
  | Recreate, Rolling_update -> false
  | Rolling_update, Recreate -> false

let rolling_update_equal (a : rolling_update) (b : rolling_update) : bool =
  Option.equal Int.equal a.max_surge b.max_surge
  && Option.equal Int.equal a.max_unavailable b.max_unavailable

let equal (a : t) (b : t) : bool =
  Option.equal strategy_type_equal a.type_ b.type_
  && Option.equal rolling_update_equal a.rolling_update b.rolling_update

(* JSON forms "Recreate" / "RollingUpdate". *)
let strategy_type_to_json (ty : strategy_type) : Yojson.Safe.t =
  match ty with
  | Recreate -> Json.str "Recreate"
  | Rolling_update -> Json.str "RollingUpdate"

(* Exhaustive over the two literals; any other string is a decode error (the
   string dispatch's fallthrough, NOT a wildcard on a finite sum). *)
let strategy_type_of_json (j : Yojson.Safe.t) : strategy_type Res.t =
  let open Res in
  let* tag = Json.to_str j in
  match tag with
  | "Recreate" -> ok Recreate
  | "RollingUpdate" -> ok Rolling_update
  | _ ->
    error (Err.Decode_error { typ = "deployment_strategy.type"; detail = tag })

let rolling_update_to_json (o : rolling_update) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("maxSurge", Json.opt Json.int_ o.max_surge);
      ("maxUnavailable", Json.opt Json.int_ o.max_unavailable);
    ]

let rolling_update_of_json (j : Yojson.Safe.t) : rolling_update Res.t =
  let open Res in
  let* max_surge = Json.opt_mem j "maxSurge" Json.to_int in
  let* max_unavailable = Json.opt_mem j "maxUnavailable" Json.to_int in
  ok { max_surge; max_unavailable }

let to_json (o : t) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("type", Json.opt strategy_type_to_json o.type_);
      ("rollingUpdate", Json.opt rolling_update_to_json o.rolling_update);
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* type_ = Json.opt_mem j "type" strategy_type_of_json in
  let* rolling_update = Json.opt_mem j "rollingUpdate" rolling_update_of_json in
  ok { type_; rolling_update }

(* Anvil source: kubernetes_api_objects/spec/resource_requirements.rs
   [ResourceRequirementsView]. Referenced by ContainerView.resources. *)

type t = {
  limits : string Smap.t option;
  requests : string Smap.t option;
}

let default () : t = { limits = None; requests = None }

let equal (a : t) (b : t) : bool =
  Option.equal (Smap.equal String.equal) a.limits b.limits
  && Option.equal (Smap.equal String.equal) a.requests b.requests

let to_json (o : t) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("limits", Json.opt Json.smap o.limits);
      ("requests", Json.opt Json.smap o.requests);
    ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* limits = Json.opt_mem j "limits" Json.to_smap in
  let* requests = Json.opt_mem j "requests" Json.to_smap in
  ok { limits; requests }

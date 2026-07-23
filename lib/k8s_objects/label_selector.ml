(* Anvil source: kubernetes_api_objects/spec/label_selector.rs
   [LabelSelectorView]. Only [match_labels] is modelled (match_expressions is a
   TODO in Anvil, deliberately absent). Referenced by StatefulSetSpecView.selector. *)

type t = { match_labels : string Smap.t option }

let default () : t = { match_labels = None }

let equal (a : t) (b : t) : bool =
  Option.equal (Smap.equal String.equal) a.match_labels b.match_labels

(* Anvil [matches]: if [match_labels] is None then true, else every (k,v) pair
   in [match_labels] must be present in [labels]. *)
let matches (o : t) (labels : string Smap.t) : bool =
  Option.fold ~none:true
    ~some:(fun ml ->
      Smap.for_all
        (fun k v -> Option.equal String.equal (Smap.find_opt k labels) (Some v))
        ml)
    o.match_labels

let to_json (o : t) : Yojson.Safe.t =
  Json.obj_opt [ ("matchLabels", Json.opt Json.smap o.match_labels) ]

let of_json (j : Yojson.Safe.t) : t Res.t =
  let open Res in
  let* match_labels = Json.opt_mem j "matchLabels" Json.to_smap in
  ok { match_labels }

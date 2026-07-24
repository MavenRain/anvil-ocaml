(* Anvil source: controllers/vdeployment_controller/trusted/spec_types.rs
   ([VDeploymentView] and its [implement_resource_view_trait!] instance).
   VDeploymentView.spec is a BARE VDeploymentSpecView; inside it [template] is a
   BARE PodTemplateSpecView (required, unlike VReplicaSetView where it is
   optional) and [status] is Option<VDeploymentStatusView> with
   VDeploymentStatusView = EmptyStatusView, realised as unit (the Config_map
   empty-status pattern). Realised through Resource_view.Make, mirroring
   vreplica_set.ml. *)

type vd_spec = {
  replicas : int option;
  selector : Label_selector.t;
  template : Pod_template_spec.t;
  min_ready_seconds : int option;
  progress_deadline_seconds : int option;
  strategy : Deployment_strategy.t option;
  revision_history_limit : int option;
  paused : bool option;
}

type status = unit

type t = {
  metadata : Object_meta.t;
  spec : vd_spec;
  status : status;
}

type spec = vd_spec

let kind_name = "vdeployment"
let kind : Common.kind = Common.Custom_resource kind_name

(* -- VDeploymentSpecView -- *)
let vd_spec_default () : vd_spec =
  {
    replicas = None;
    selector = Label_selector.default ();
    template = Pod_template_spec.default ();
    min_ready_seconds = None;
    progress_deadline_seconds = None;
    strategy = None;
    revision_history_limit = None;
    paused = None;
  }

let vd_spec_equal (a : vd_spec) (b : vd_spec) : bool =
  Option.equal Int.equal a.replicas b.replicas
  && Label_selector.equal a.selector b.selector
  && Pod_template_spec.equal a.template b.template
  && Option.equal Int.equal a.min_ready_seconds b.min_ready_seconds
  && Option.equal Int.equal a.progress_deadline_seconds
       b.progress_deadline_seconds
  && Option.equal Deployment_strategy.equal a.strategy b.strategy
  && Option.equal Int.equal a.revision_history_limit b.revision_history_limit
  && Option.equal Bool.equal a.paused b.paused

let vd_spec_to_json (o : vd_spec) : Yojson.Safe.t =
  Json.obj_opt
    [
      ("replicas", Json.opt Json.int_ o.replicas);
      ("selector", Some (Label_selector.to_json o.selector));
      ("template", Some (Pod_template_spec.to_json o.template));
      ("minReadySeconds", Json.opt Json.int_ o.min_ready_seconds);
      ( "progressDeadlineSeconds",
        Json.opt Json.int_ o.progress_deadline_seconds );
      ("strategy", Json.opt Deployment_strategy.to_json o.strategy);
      ("revisionHistoryLimit", Json.opt Json.int_ o.revision_history_limit);
      ("paused", Json.opt Json.bool_ o.paused);
    ]

let vd_spec_of_json (j : Yojson.Safe.t) : vd_spec Res.t =
  let open Res in
  let* replicas = Json.opt_mem j "replicas" Json.to_int in
  let* selector = Json.get j "selector" Label_selector.of_json in
  let* template = Json.get j "template" Pod_template_spec.of_json in
  let* min_ready_seconds = Json.opt_mem j "minReadySeconds" Json.to_int in
  let* progress_deadline_seconds =
    Json.opt_mem j "progressDeadlineSeconds" Json.to_int
  in
  let* strategy = Json.opt_mem j "strategy" Deployment_strategy.of_json in
  let* revision_history_limit =
    Json.opt_mem j "revisionHistoryLimit" Json.to_int
  in
  let* paused = Json.opt_mem j "paused" Json.to_bool in
  ok
    ({
       replicas;
       selector;
       template;
       min_ready_seconds;
       progress_deadline_seconds;
       strategy;
       revision_history_limit;
       paused;
     }
      : vd_spec)

module R = struct
  type nonrec t = t
  type nonrec spec = spec
  type nonrec status = status

  let kind = kind

  let default () : t =
    { metadata = Object_meta.default (); spec = vd_spec_default (); status = () }

  let metadata (s : t) : Object_meta.t = s.metadata
  let spec (s : t) : spec = s.spec
  let status (_ : t) : status = ()
  let recombine ~metadata ~spec ~status:_ = { metadata; spec; status = () }

  (* VDeploymentView.spec is bare, so a spec always marshals to a JSON object. *)
  let marshal_spec (s : spec) : Value.t = Value.of_json (vd_spec_to_json s)

  (* A VDeployment always has a spec, so a `Null` (or any non-object) Value is a
     decode error. *)
  let unmarshal_spec (v : Value.t) : spec Res.t =
    match Value.json v with
    | `Assoc _ as j -> vd_spec_of_json j
    | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `List _ ->
      Res.error
        (Err.Decode_error
           { typ = "v_deployment.spec"; detail = "expected object" })

  (* EmptyStatusView: status marshals to `Null and unmarshals only from `Null
     (Config_map empty-status pattern, verbatim). *)
  let marshal_status (_ : status) : Value.t = Value.of_json `Null

  let unmarshal_status (v : Value.t) : status Res.t =
    match Value.json v with
    | `Null -> Res.ok ()
    | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ | `Assoc _ | `List _
      ->
      Res.error
        (Err.Decode_error
           { typ = "v_deployment.status"; detail = "expected null" })

  (* spec_types.rs _state_validation: replicas non-negative; the
     minReadySeconds/progressDeadlineSeconds four-way; a non-empty
     selector.match_labels; a bare template with metadata, spec, and labels that
     the selector matches; and, if a strategy is present, the Recreate /
     RollingUpdate constraint. Every option test uses a combinator (fold/is_some),
     never a two-arm match on an option; the strategy_type branch is a full
     2-arm match on the finite sum. *)
  let state_validation (s : t) : bool =
    Option.fold ~none:true ~some:(fun r -> r >= 0) s.spec.replicas
    && Option.fold
         ~none:
           (Option.fold ~none:true
              ~some:(fun deadline -> deadline > 0)
              s.spec.progress_deadline_seconds)
         ~some:(fun min_ready ->
           Option.fold
             ~none:(min_ready < 600 && min_ready >= 0)
             ~some:(fun deadline -> min_ready < deadline && min_ready >= 0)
             s.spec.progress_deadline_seconds)
         s.spec.min_ready_seconds
    && Option.fold ~none:true
         ~some:(fun (st : Deployment_strategy.t) ->
           Option.fold ~none:true
             ~some:(fun (ty : Deployment_strategy.strategy_type) ->
               match ty with
               | Deployment_strategy.Recreate ->
                 Option.is_none st.rolling_update
               | Deployment_strategy.Rolling_update ->
                 Option.fold ~none:true
                   ~some:(fun (ru : Deployment_strategy.rolling_update) ->
                     Option.fold
                       ~none:
                         (Option.fold ~none:true
                            ~some:(fun u -> u >= 0)
                            ru.max_unavailable)
                       ~some:(fun surge ->
                         Option.fold ~none:(surge >= 0)
                           ~some:(fun unavail ->
                             surge >= 0 && unavail >= 0
                             && not (Int.equal surge 0 && Int.equal unavail 0))
                           ru.max_unavailable)
                       ru.max_surge)
                   st.rolling_update)
             st.type_)
         s.spec.strategy
    && Option.is_some s.spec.selector.match_labels
    && Option.fold ~none:false
         ~some:(fun ml -> Smap.cardinal ml > 0)
         s.spec.selector.match_labels
    && Option.is_some s.spec.template.metadata
    && Option.is_some s.spec.template.spec
    && Option.fold ~none:false
         ~some:(fun (tm : Object_meta.t) ->
           Option.is_some tm.labels
           && Option.fold ~none:false
                ~some:(fun labels ->
                  Label_selector.matches s.spec.selector labels)
                tm.labels)
         s.spec.template.metadata

  (* spec_types.rs _transition_validation is [true]. *)
  let transition_validation (_ : t) ~old:(_ : t) : bool = true
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

(* status is unit, hence trivially equal; compare metadata and spec. *)
let equal (a : t) (b : t) : bool =
  Object_meta.equal a.metadata b.metadata && vd_spec_equal a.spec b.spec

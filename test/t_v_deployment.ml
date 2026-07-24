(* VDeployment CR-view tests (BUILD-SPEC-P9 §5, t_v_deployment; mirrors
   t_vreplica_set.ml): [state_validation] (spec_types.rs [_state_validation])
   pinned conjunct-by-conjunct — a fully well-formed VDeployment passes, each
   single break fails — the marshal/unmarshal round-trip on a populated spec, a
   wrong-kind DynamicObject -> [Kind_mismatch], and the strategy clause
   (Recreate-with-rollingUpdate and a 0/0 rolling update both invalid).

   NOTE (vs VReplicaSet): [template] is a BARE [Pod_template_spec.t] here, so the
   template conjuncts index it directly (no outer [template = Some ...]). *)

let labels_xy = Smap.add "app" "x" Smap.empty

let matching_selector : Label_selector.t = { match_labels = Some labels_xy }

(* Template metadata carrying labels that match [matching_selector]. *)
let tmpl_metadata = Object_meta.with_labels labels_xy (Object_meta.default ())

let good_template : Pod_template_spec.t =
  { metadata = Some tmpl_metadata; spec = Some (Pod_spec.default ()) }

let good_spec : V_deployment.vd_spec =
  {
    (V_deployment.vd_spec_default ()) with
    replicas = Some 1;
    selector = matching_selector;
    template = good_template;
  }

let base_metadata =
  Object_meta.default ()
  |> Object_meta.with_name "vd1"
  |> Object_meta.with_namespace "ns"

let vd_of (spec : V_deployment.vd_spec) : V_deployment.t =
  V_deployment.make ~metadata:base_metadata ~spec ~status:()

(* -- state_validation: the well-formed CR passes -- *)

let test_valid_passes () =
  Alcotest.(check bool) "well-formed VDeployment validates" true
    (V_deployment.state_validation (vd_of good_spec))

(* -- state_validation: each single break fails a distinct conjunct -- *)

let negative_replicas : V_deployment.vd_spec =
  { good_spec with replicas = Some (-1) }

let no_match_labels : V_deployment.vd_spec =
  { good_spec with selector = Label_selector.default () }

let empty_match_labels : V_deployment.vd_spec =
  { good_spec with selector = { match_labels = Some Smap.empty } }

let selector_mismatch : V_deployment.vd_spec =
  { good_spec with selector = { match_labels = Some (Smap.add "app" "y" Smap.empty) } }

let no_template_metadata : V_deployment.vd_spec =
  { good_spec with template = { good_template with metadata = None } }

let no_template_spec : V_deployment.vd_spec =
  { good_spec with template = { good_template with spec = None } }

let no_template_labels : V_deployment.vd_spec =
  { good_spec with template = { good_template with metadata = Some (Object_meta.default ()) } }

(* min/progress four-way (spec_types.rs): each of the three constrained corners
   broken. (min Some, deadline Some) needs min < deadline; (min Some, None) needs
   min < 600; (None, deadline Some) needs deadline > 0. *)
let min_ge_deadline : V_deployment.vd_spec =
  { good_spec with min_ready_seconds = Some 5; progress_deadline_seconds = Some 3 }

let min_over_600 : V_deployment.vd_spec =
  { good_spec with min_ready_seconds = Some 600 }

let deadline_nonpositive : V_deployment.vd_spec =
  { good_spec with progress_deadline_seconds = Some 0 }

(* strategy clause: Recreate must have NO rolling update; a RollingUpdate with a
   0/0 surge/unavailable is invalid. *)
let recreate_with_rolling_update : V_deployment.vd_spec =
  {
    good_spec with
    strategy =
      Some
        {
          Deployment_strategy.type_ = Some Deployment_strategy.Recreate;
          rolling_update =
            Some { Deployment_strategy.max_surge = Some 1; max_unavailable = Some 1 };
        };
  }

let rolling_update_zero_zero : V_deployment.vd_spec =
  {
    good_spec with
    strategy =
      Some
        {
          Deployment_strategy.type_ = Some Deployment_strategy.Rolling_update;
          rolling_update =
            Some { Deployment_strategy.max_surge = Some 0; max_unavailable = Some 0 };
        };
  }

let test_breaks_fail () =
  List.iter
    (fun (name, spec) ->
      Alcotest.(check bool)
        (name ^ " fails validation")
        false
        (V_deployment.state_validation (vd_of spec)))
    [
      ("negative replicas", negative_replicas);
      ("no selector match_labels", no_match_labels);
      ("empty selector match_labels", empty_match_labels);
      ("selector not matching template labels", selector_mismatch);
      ("no template.metadata", no_template_metadata);
      ("no template.spec", no_template_spec);
      ("no template labels", no_template_labels);
      ("min_ready >= progress_deadline", min_ge_deadline);
      ("min_ready >= 600 with no deadline", min_over_600);
      ("progress_deadline <= 0 with no min", deadline_nonpositive);
      ("Recreate strategy with a rollingUpdate", recreate_with_rolling_update);
      ("RollingUpdate with 0/0 surge/unavailable", rolling_update_zero_zero);
    ]

(* -- marshal / unmarshal round-trip -- *)

let v_full : V_deployment.t =
  V_deployment.make ~metadata:base_metadata
    ~spec:
      {
        good_spec with
        min_ready_seconds = Some 5;
        progress_deadline_seconds = Some 30;
        strategy = Some (Deployment_strategy.default ());
        revision_history_limit = Some 10;
        paused = Some true;
      }
    ~status:()

let test_round_trip () =
  let dyn = V_deployment.marshal v_full in
  Alcotest.(check bool) "unmarshal (marshal v) = Ok v' with v = v'" true
    (Result.fold (V_deployment.unmarshal dyn)
       ~error:(fun (_ : Err.t) -> false)
       ~ok:(fun v' -> V_deployment.equal v_full v'))

let is_kind_mismatch (e : Err.t) : bool =
  match e with
  | Kind_mismatch _ -> true
  | Malformed_value _ | Missing_field _ | Decode_error _ | At _ -> false

let wrong_kind_obj =
  Dynamic_object.make ~kind:Common.Config_map
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name "vd1"
      |> Object_meta.with_namespace "ns")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let test_wrong_kind () =
  Alcotest.(check bool) "wrong-kind DynamicObject -> Kind_mismatch" true
    (Result.fold (V_deployment.unmarshal wrong_kind_obj)
       ~ok:(fun (_ : V_deployment.t) -> false)
       ~error:is_kind_mismatch)

let () =
  Alcotest.run "v_deployment"
    [
      ( "state_validation",
        [
          Alcotest.test_case "well-formed passes" `Quick test_valid_passes;
          Alcotest.test_case "each break fails" `Quick test_breaks_fail;
        ] );
      ( "marshal",
        [
          Alcotest.test_case "round-trip" `Quick test_round_trip;
          Alcotest.test_case "wrong kind" `Quick test_wrong_kind;
        ] );
    ]

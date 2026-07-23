(* VReplicaSet CR-view tests (BUILD-SPEC-P3 "## 8. Tests", t_vreplica_set):
   [state_validation] (spec_types.rs:57) pinned conjunct-by-conjunct — a fully
   well-formed VReplicaSet passes, each single omission fails — and the
   marshal/unmarshal round-trip (populated spec + status equal after a round trip;
   a wrong-kind DynamicObject -> Kind_mismatch). *)

let labels_xy = Smap.add "app" "x" Smap.empty

let matching_selector : Label_selector.t = { match_labels = Some labels_xy }

(* Template metadata that carries labels matching [matching_selector]. *)
let tmpl_metadata = Object_meta.with_labels labels_xy (Object_meta.default ())

let good_template : Pod_template_spec.t =
  { metadata = Some tmpl_metadata; spec = Some (Pod_spec.default ()) }

let good_spec : Vreplica_set.vrs_spec =
  { replicas = Some 1; selector = matching_selector; template = Some good_template }

let base_metadata =
  Object_meta.default ()
  |> Object_meta.with_name "vrs1"
  |> Object_meta.with_namespace "ns"

let vrs_of (spec : Vreplica_set.vrs_spec) : Vreplica_set.t =
  Vreplica_set.make ~metadata:base_metadata ~spec ~status:None

(* -- state_validation: the well-formed CR passes -- *)

let test_valid_passes () =
  Alcotest.(check bool) "well-formed VReplicaSet validates" true
    (Vreplica_set.state_validation (vrs_of good_spec))

(* -- state_validation: each single omission fails a distinct conjunct -- *)

let no_match_labels : Vreplica_set.vrs_spec =
  { good_spec with selector = Label_selector.default () }

let empty_match_labels : Vreplica_set.vrs_spec =
  { good_spec with selector = { match_labels = Some Smap.empty } }

let no_template : Vreplica_set.vrs_spec = { good_spec with template = None }

let no_template_metadata : Vreplica_set.vrs_spec =
  { good_spec with template = Some { good_template with metadata = None } }

let no_template_spec : Vreplica_set.vrs_spec =
  { good_spec with template = Some { good_template with spec = None } }

let no_template_labels : Vreplica_set.vrs_spec =
  {
    good_spec with
    template =
      Some { good_template with metadata = Some (Object_meta.default ()) };
  }

let selector_mismatch : Vreplica_set.vrs_spec =
  { good_spec with selector = { match_labels = Some (Smap.add "app" "y" Smap.empty) } }

let negative_replicas : Vreplica_set.vrs_spec =
  { good_spec with replicas = Some (-1) }

let test_omissions_fail () =
  List.iter
    (fun (name, spec) ->
      Alcotest.(check bool)
        (name ^ " fails validation")
        false
        (Vreplica_set.state_validation (vrs_of spec)))
    [
      ("no selector match_labels", no_match_labels);
      ("empty selector match_labels", empty_match_labels);
      ("no template", no_template);
      ("no template.metadata", no_template_metadata);
      ("no template.spec", no_template_spec);
      ("no template labels", no_template_labels);
      ("selector not matching template labels", selector_mismatch);
      ("negative replicas", negative_replicas);
    ]

(* -- marshal / unmarshal round-trip -- *)

let v_full : Vreplica_set.t =
  Vreplica_set.make ~metadata:base_metadata ~spec:good_spec
    ~status:(Some (Vreplica_set.status_with_replicas 2 (Vreplica_set.status_default ())))

let test_round_trip () =
  let dyn = Vreplica_set.marshal v_full in
  Alcotest.(check bool) "unmarshal (marshal v) = Ok v' with v = v'" true
    (Result.fold (Vreplica_set.unmarshal dyn)
       ~error:(fun (_ : Err.t) -> false)
       ~ok:(fun v' -> Vreplica_set.equal v_full v'))

let is_kind_mismatch (e : Err.t) : bool =
  match e with
  | Kind_mismatch _ -> true
  | Malformed_value _ | Missing_field _ | Decode_error _ | At _ -> false

let wrong_kind_obj =
  Dynamic_object.make ~kind:Common.Config_map
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name "vrs1"
      |> Object_meta.with_namespace "ns")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let test_wrong_kind () =
  Alcotest.(check bool) "wrong-kind DynamicObject -> Kind_mismatch" true
    (Result.fold (Vreplica_set.unmarshal wrong_kind_obj)
       ~ok:(fun (_ : Vreplica_set.t) -> false)
       ~error:is_kind_mismatch)

let () =
  Alcotest.run "vreplica_set"
    [
      ( "state_validation",
        [
          Alcotest.test_case "well-formed passes" `Quick test_valid_passes;
          Alcotest.test_case "each omission fails" `Quick test_omissions_fail;
        ] );
      ( "marshal",
        [
          Alcotest.test_case "round-trip" `Quick test_round_trip;
          Alcotest.test_case "wrong kind" `Quick test_wrong_kind;
        ] );
    ]

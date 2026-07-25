(* VStatefulSet CR-view tests (Phase 10, t_v_stateful_set; mirrors
   t_v_deployment.ml / t_vreplica_set.ml): the marshal/unmarshal round-trip on a
   populated (vct-bearing) spec, [state_validation] pinned (a well-formed CR
   passes; three targeted single-conjunct breaks fail), the
   [transition_validation] immutable-field check (a mutable field may change; an
   immutable one may not), and a wrong-kind DynamicObject -> [Kind_mismatch].

   Convention firewall: no loop keywords; no [_ ->] wildcard on a finite sum;
   Result.fold for results. *)

module Scenario = Anvil_assurance.Scenario
module Vr = V_stateful_set_reconciler

(* A fully well-formed CR carrying one volumeClaimTemplate. *)
let cr : V_stateful_set.t = Scenario.vsts ~desired:3 ~vct:true ()

(* -- marshal / unmarshal round-trip -- *)

let test_round_trip () =
  Alcotest.(check bool) "unmarshal (marshal cr) = Ok cr' with cr = cr'" true
    (Result.fold
       (V_stateful_set.unmarshal (V_stateful_set.marshal cr))
       ~ok:(V_stateful_set.equal cr)
       ~error:(fun (_ : Err.t) -> false))

(* -- state_validation: the well-formed CR passes -- *)

let test_valid_passes () =
  Alcotest.(check bool) "well-formed VStatefulSet validates" true
    (V_stateful_set.state_validation cr)

(* -- state_validation: three targeted single-conjunct breaks each fail -- *)

(* (a) selector.match_labels present but empty -> conjunct 1. *)
let empty_selector : V_stateful_set.t =
  { cr with spec = { cr.spec with selector = { match_labels = Some Smap.empty } } }

(* (b) a template label carrying the reserved pod-name key -> conjunct 4. The
   selector [app=x] still matches (it is a subset of the template labels), so it
   is precisely the reserved-key conjunct that fails. *)
let reserved_template_label : V_stateful_set.t =
  let labels =
    Smap.add Vr.pod_name_label "vsts1-0" (Smap.add "app" "x" Smap.empty)
  in
  {
    cr with
    spec =
      {
        cr.spec with
        template =
          {
            cr.spec.template with
            metadata = Some (Object_meta.with_labels labels (Object_meta.default ()));
          };
      };
  }

(* (c) an update_strategy whose type is neither OnDelete nor RollingUpdate ->
   conjunct 6. *)
let bogus_update_strategy : V_stateful_set.t =
  {
    cr with
    spec =
      {
        cr.spec with
        update_strategy = Some { Stateful_set.type_ = Some "Bogus"; rolling_update = None };
      };
  }

let test_breaks_fail () =
  List.iter
    (fun (name, c) ->
      Alcotest.(check bool)
        (name ^ " fails validation")
        false
        (V_stateful_set.state_validation c))
    [
      ("empty selector match_labels", empty_selector);
      ("reserved pod-name template label", reserved_template_label);
      ("bogus update_strategy type", bogus_update_strategy);
    ]

(* -- transition_validation: mutable may change, immutable may not -- *)

let mutated_replicas : V_stateful_set.t =
  { cr with spec = { cr.spec with replicas = Some 5 } }

let mutated_service_name : V_stateful_set.t =
  { cr with spec = { cr.spec with service_name = "vsts1-changed" } }

let test_transition_validation () =
  Alcotest.(check bool) "changing replicas (mutable) -> valid transition" true
    (V_stateful_set.transition_validation mutated_replicas ~old:cr);
  Alcotest.(check bool) "changing service_name (immutable) -> invalid transition"
    false
    (V_stateful_set.transition_validation mutated_service_name ~old:cr)

(* -- wrong-kind DynamicObject -> Kind_mismatch -- *)

let is_kind_mismatch (e : Err.t) : bool =
  match e with
  | Kind_mismatch _ -> true
  | Malformed_value _ | Missing_field _ | Decode_error _ | At _ -> false

let wrong_kind_obj =
  Dynamic_object.make ~kind:Common.Config_map
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name "vsts1"
      |> Object_meta.with_namespace "ns")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let test_wrong_kind () =
  Alcotest.(check bool) "wrong-kind DynamicObject -> Kind_mismatch" true
    (Result.fold (V_stateful_set.unmarshal wrong_kind_obj)
       ~ok:(fun (_ : V_stateful_set.t) -> false)
       ~error:is_kind_mismatch)

let () =
  Alcotest.run "v_stateful_set"
    [
      ( "marshal",
        [
          Alcotest.test_case "round-trip" `Quick test_round_trip;
          Alcotest.test_case "wrong kind" `Quick test_wrong_kind;
        ] );
      ( "state_validation",
        [
          Alcotest.test_case "well-formed passes" `Quick test_valid_passes;
          Alcotest.test_case "each break fails" `Quick test_breaks_fail;
        ] );
      ( "transition_validation",
        [ Alcotest.test_case "mutable ok, immutable rejected" `Quick test_transition_validation ] );
    ]

(* Phase 10 confirm-by-mutation for the VStatefulSet controller (t_p10_mutation;
   mirrors t_p9_mutation's shadowed-variant style). Each pin reads a value the
   real code actually produces and that the corresponding source mutant would
   break; where natural a local mutated analogue is shown to differ, so the pin
   is non-vacuous.

   - M1: [pod_name] stamps "vstatefulset-<parent>-<ord>"; an ordinal-dropping
     mutant collapses distinct ordinals to one name.
   - M2: [partition_pods] splits at [ord >= replicas]; a [<=]/[<] boundary mutant
     misplaces the boundary ordinal (drops ordinal 1 from condemned at replicas=1).
   - M3: [get_largest_unmatched_pods] returns the LARGEST-ordinal unmatched pod
     (the last of the ascending [needed]); a picks-first mutant returns ordinal 0.
   - M4: [After_get_pvc] on Object_not_found routes to [Create_pvc] (which emits a
     Create); a mutant routing to [Skip_pvc] would never create the PVC.
   - M5: the pack's state codec round-trips [needed] (length + Some/None pattern);
     a needed-dropping encode loses it (decoded needed differs in length).
   - M6: [update_identity] stamps the ordinal / pod-name reserved labels; a mutant
     omitting the ordinal label loses the [apps.kubernetes.io/pod-index] entry.
   - M7: [get_ordinal] is the canonical injective inverse of [pod_name]; a mutant
     using a bare [int_of_string_opt] over-accepts non-canonical suffixes (radix
     prefixes, underscore groups, signs, leading zeros) that [string_of_int]
     never emits, misclassifying a stray owned pod.

   Convention firewall: no loop keywords; no [_ ->] wildcard on a finite sum
   (api_request enumerated, the External arm void-refuted); Option.fold /
   Result.fold. *)

module Vr = V_stateful_set_reconciler
module Pack = V_stateful_set_pack
module Scenario = Anvil_assurance.Scenario

(* Name the emitted request by its verb (exhaustive over api_request). *)
let req_kind (r : Io.void Io.request_view option) : string =
  Option.fold r ~none:"none" ~some:(fun (rv : Io.void Io.request_view) ->
      match rv with
      | Io.K_request q -> (
        match q with
        | Api_method.List_request _ -> "list"
        | Api_method.Create_request _ -> "create"
        | Api_method.Get_request _ -> "get"
        | Api_method.Get_then_update_request _ -> "get_then_update"
        | Api_method.Get_then_delete_request _ -> "get_then_delete"
        | Api_method.Delete_request _ | Api_method.Update_request _
        | Api_method.Update_status_request _
        | Api_method.Get_then_update_status_request _ ->
          "other")
      | Io.External_request _ -> .)

let get_resp (res : (Dynamic_object.t, Api_method.api_error) result) :
    Io.void Io.response_view option =
  Some (Io.K_response (Api_method.Get_response { res }))

(* A CR whose pod template spec differs (non-default service_account_name), so
   pods built from it are unmatched against the base CR. *)
let mutate_template (cr : V_stateful_set.t) : V_stateful_set.t =
  {
    cr with
    spec =
      {
        cr.spec with
        template =
          {
            cr.spec.template with
            spec = Some { (Pod_spec.default ()) with service_account_name = Some "v2" };
          };
      };
  }

let ordinal_of (parent : string) (p : Pod.t) : int option =
  Option.bind (Object_meta.name (Pod.metadata p)) (Vr.get_ordinal parent)

(* ---- M1: pod_name drops the ordinal ---- *)
let test_m1_pod_name () =
  Alcotest.(check bool) "M1: pod_name stamps vstatefulset-<parent>-<ord>" true
    (String.equal (Vr.pod_name "web" 2) "vstatefulset-web-2");
  Alcotest.(check bool) "M1: distinct ordinals -> distinct names" true
    (not (String.equal (Vr.pod_name "web" 2) (Vr.pod_name "web" 0)))

(* ---- M2: partition_pods boundary (<= vs <) ---- *)
let test_m2_partition_boundary () =
  let cr = Scenario.vsts ~desired:3 () in
  let pods = List.map (Vr.make_pod cr) [ 0; 1; 2 ] in
  let needed, condemned = Vr.partition_pods "vsts1" 1 pods in
  Alcotest.(check int) "M2: needed length = replicas" 1 (List.length needed);
  let needed_ordinals =
    List.filter_map (fun (po : Pod.t option) -> Option.bind po (ordinal_of "vsts1")) needed
  in
  Alcotest.(check (list int)) "M2: needed covers ordinal 0" [ 0 ] needed_ordinals;
  let condemned_ordinals = List.filter_map (ordinal_of "vsts1") condemned in
  Alcotest.(check (list int)) "M2: condemned = ordinals >= replicas, descending"
    [ 2; 1 ] condemned_ordinals

(* ---- M3: get_largest_unmatched_pods picks the largest ordinal ---- *)
let test_m3_largest_unmatched () =
  let cr = Scenario.vsts ~desired:3 () in
  let mismatched = mutate_template cr in
  let pod0 = Vr.make_pod mismatched 0 in
  let pod2 = Vr.make_pod mismatched 2 in
  let needed = [ Some pod0; Some pod2 ] in
  let largest_name =
    Option.bind
      (Vr.get_largest_unmatched_pods cr needed)
      (fun (p : Pod.t) -> Object_meta.name (Pod.metadata p))
  in
  Alcotest.(check (option string)) "M3: largest-unmatched is the ordinal-2 pod"
    (Some "vstatefulset-vsts1-2") largest_name

(* ---- M4: After_get_pvc NotFound -> Create_pvc (not Skip_pvc) ---- *)
let test_m4_notfound_creates () =
  let cr_vct = Scenario.vsts ~desired:3 ~vct:true () in
  let state : Vr.s =
    {
      Vr.init with
      reconcile_step = After_get_pvc;
      pvcs = Vr.make_pvcs cr_vct 0;
      pvc_index = 0;
      needed = [ None; None; None ];
      needed_index = 0;
    }
  in
  let after =
    Vr.reconcile_core ~cr:cr_vct
      ~resp:(get_resp (Error Api_method.Object_not_found))
      ~state
  in
  Alcotest.(check bool) "M4: NotFound -> Create_pvc" true
    (Vr.step_equal Vr.Create_pvc (fst after).reconcile_step);
  Alcotest.(check bool) "M4: NOT routed to Skip_pvc" true
    (not (Vr.step_equal Vr.Skip_pvc (fst after).reconcile_step));
  (* eventually a create: the Create_pvc step emits a Create request. *)
  let creating = Vr.reconcile_core ~cr:cr_vct ~resp:None ~state:(fst after) in
  Alcotest.(check string) "M4: Create_pvc emits a Create request" "create"
    (req_kind (snd creating))

(* ---- M5: the pack state codec must not drop [needed] ---- *)
let test_m5_needed_roundtrip () =
  let cr = Scenario.vsts ~desired:3 () in
  let pod = Vr.make_pod cr 0 in
  let decoded_needed (state : Vr.s) : Pod.t option list =
    Result.fold
      (Pack.unmarshal_state (Pack.marshal_state state))
      ~ok:(fun (s : Vr.s) -> s.needed)
      ~error:(fun (_ : Err.t) -> [])
  in
  let decoded = decoded_needed { Vr.init with needed = [ Some pod; None ] } in
  Alcotest.(check (list bool)) "M5: needed round-trips with the Some/None pattern"
    [ true; false ]
    (List.map Option.is_some decoded);
  Alcotest.(check int) "M5: needed length preserved" 2 (List.length decoded);
  (* a needed-dropped analogue decodes to a DIFFERENT (shorter) needed. *)
  let dropped = decoded_needed { Vr.init with needed = [] } in
  Alcotest.(check bool) "M5: a needed-dropped state decodes to a different needed"
    true
    (not (Int.equal (List.length decoded) (List.length dropped)))

(* ---- M6: update_identity stamps the ordinal / pod-name labels ---- *)
let test_m6_ordinal_label () =
  let cr = Scenario.vsts ~desired:3 () in
  let pod = Vr.make_pod cr 2 in
  let stamped = Vr.update_identity cr pod 2 in
  let labels = Option.value ~default:Smap.empty (Pod.metadata stamped).labels in
  Alcotest.(check (option string)) "M6: ordinal_label -> \"2\"" (Some "2")
    (Smap.find_opt Vr.ordinal_label labels);
  Alcotest.(check bool) "M6: pod_name_label present" true
    (Smap.mem Vr.pod_name_label labels)

(* ---- M7: get_ordinal is the canonical injective inverse of pod_name ---- *)
let test_m7_get_ordinal_canonical () =
  Alcotest.(check (option int)) "M7: canonical decimal name round-trips" (Some 2)
    (Vr.get_ordinal "web" "vstatefulset-web-2");
  (* suffixes int_of_string_opt would accept but string_of_int never emits *)
  Alcotest.(check (option int)) "M7: radix-prefixed suffix rejected" None
    (Vr.get_ordinal "web" "vstatefulset-web-0x0");
  Alcotest.(check (option int)) "M7: underscore-grouped suffix rejected" None
    (Vr.get_ordinal "web" "vstatefulset-web-1_0");
  Alcotest.(check (option int)) "M7: leading-zero suffix rejected" None
    (Vr.get_ordinal "web" "vstatefulset-web-01");
  Alcotest.(check (option int)) "M7: signed suffix rejected" None
    (Vr.get_ordinal "web" "vstatefulset-web-+5")

let () =
  Alcotest.run "p10_mutation"
    [
      ( "confirm-by-mutation",
        [
          Alcotest.test_case "M1: pod_name keeps the ordinal" `Quick test_m1_pod_name;
          Alcotest.test_case "M2: partition boundary is >= replicas" `Quick
            test_m2_partition_boundary;
          Alcotest.test_case "M3: largest-unmatched picks the last" `Quick
            test_m3_largest_unmatched;
          Alcotest.test_case "M4: After_get_pvc NotFound creates the PVC" `Quick
            test_m4_notfound_creates;
          Alcotest.test_case "M5: pack codec keeps needed" `Quick test_m5_needed_roundtrip;
          Alcotest.test_case "M6: update_identity stamps the ordinal label" `Quick
            test_m6_ordinal_label;
          Alcotest.test_case "M7: get_ordinal is pod_name's canonical inverse"
            `Quick test_m7_get_ordinal_canonical;
        ] );
    ]

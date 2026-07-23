(* Functor smoke tests for the Pod and StatefulSet views (Config_map is covered
   by t_functor.ml):
     - unmarshal (marshal o) = Ok o (spec present and absent);
     - object_ref fails Missing_field on an absent name, succeeds otherwise;
     - unmarshal of a wrong-kind Dynamic_object => Kind_mismatch;
     - StatefulSet transition_validation immutable-field rule.

   Guard/test pinning (confirm-by-mutation targets):
     - test_pod_wrong_kind / test_ss_wrong_kind pin Resource_view.Make.unmarshal's
       kind check;
     - test_pod_object_ref / test_ss_object_ref (missing name) pin the object_ref
       Missing_field branch;
     - test_ss_transition_validation pins Stateful_set.ss_spec_immutable_eq:
       neutering it (return [true]) flips the "service_name immutable" assertion
       from false to true, so that assertion fails. *)

let meta ~name ~namespace =
  let base = Object_meta.default () in
  let base =
    Option.fold ~none:base ~some:(fun n -> Object_meta.with_name n base) name
  in
  Option.fold ~none:base
    ~some:(fun ns -> Object_meta.with_namespace ns base)
    namespace

(* ---- Pod ---- *)

let pod_spec_sample () =
  let open Pod_spec in
  {
    (default ()) with
    containers =
      [
        (let open Container in
         { (default ()) with name = "nginx"; image = Some "nginx:1" });
      ];
    service_account_name = Some "sa";
    hostname = Some "h";
  }

let pod ~name ~namespace ~spec =
  Pod.make ~metadata:(meta ~name ~namespace) ~spec ~status:None

let test_pod_roundtrip () =
  let p1 =
    pod ~name:(Some "p") ~namespace:(Some "ns")
      ~spec:(Some (pod_spec_sample ()))
  in
  Alcotest.(check bool) "pod roundtrip with spec" true
    (Result.fold ~ok:(Pod.equal p1)
       ~error:(fun _ -> false)
       (Pod.unmarshal (Pod.marshal p1)));
  let p2 = pod ~name:(Some "p") ~namespace:(Some "ns") ~spec:None in
  Alcotest.(check bool) "pod roundtrip without spec" true
    (Result.fold ~ok:(Pod.equal p2)
       ~error:(fun _ -> false)
       (Pod.unmarshal (Pod.marshal p2)))

let test_pod_object_ref () =
  let ok_pod = pod ~name:(Some "p") ~namespace:(Some "ns") ~spec:None in
  let expected = { Common.kind = Common.Pod; name = "p"; namespace = "ns" } in
  Alcotest.(check bool) "pod object_ref ok" true
    (Result.fold
       ~ok:(Common.equal_object_ref expected)
       ~error:(fun _ -> false)
       (Pod.object_ref ok_pod));
  let noname = pod ~name:None ~namespace:(Some "ns") ~spec:None in
  Alcotest.(check string) "pod missing name"
    "required field absent: metadata.name"
    (Result.fold
       ~ok:(fun _ -> "ok")
       ~error:Err.show (Pod.object_ref noname))

let test_pod_wrong_kind () =
  let d =
    Dynamic_object.make ~kind:Common.Config_map
      ~metadata:(meta ~name:(Some "x") ~namespace:(Some "ns"))
      ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)
  in
  Alcotest.(check string) "pod kind mismatch"
    "kind mismatch: expected Pod, found ConfigMap"
    (Result.fold ~ok:(fun _ -> "ok") ~error:Err.show (Pod.unmarshal d))

(* ---- StatefulSet ---- *)

let ss_spec_sample () =
  let open Stateful_set in
  { (ss_spec_default ()) with service_name = "svc"; replicas = Some 3 }

let ss ~name ~namespace ~spec ~status =
  Stateful_set.make ~metadata:(meta ~name ~namespace) ~spec ~status

let test_ss_roundtrip () =
  let s1 =
    ss ~name:(Some "s") ~namespace:(Some "ns")
      ~spec:(Some (ss_spec_sample ()))
      ~status:(Some { Stateful_set.ready_replicas = Some 2 })
  in
  Alcotest.(check bool) "stateful_set roundtrip with spec/status" true
    (Result.fold ~ok:(Stateful_set.equal s1)
       ~error:(fun _ -> false)
       (Stateful_set.unmarshal (Stateful_set.marshal s1)));
  let s2 = ss ~name:(Some "s") ~namespace:(Some "ns") ~spec:None ~status:None in
  Alcotest.(check bool) "stateful_set roundtrip empty" true
    (Result.fold ~ok:(Stateful_set.equal s2)
       ~error:(fun _ -> false)
       (Stateful_set.unmarshal (Stateful_set.marshal s2)))

let test_ss_object_ref () =
  let ok_ss =
    ss ~name:(Some "s") ~namespace:(Some "ns") ~spec:None ~status:None
  in
  let expected =
    { Common.kind = Common.Stateful_set; name = "s"; namespace = "ns" }
  in
  Alcotest.(check bool) "stateful_set object_ref ok" true
    (Result.fold
       ~ok:(Common.equal_object_ref expected)
       ~error:(fun _ -> false)
       (Stateful_set.object_ref ok_ss));
  let noname =
    ss ~name:None ~namespace:(Some "ns") ~spec:None ~status:None
  in
  Alcotest.(check string) "stateful_set missing name"
    "required field absent: metadata.name"
    (Result.fold
       ~ok:(fun _ -> "ok")
       ~error:Err.show (Stateful_set.object_ref noname))

let test_ss_wrong_kind () =
  let d =
    Dynamic_object.make ~kind:Common.Pod
      ~metadata:(meta ~name:(Some "x") ~namespace:(Some "ns"))
      ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)
  in
  Alcotest.(check string) "stateful_set kind mismatch"
    "kind mismatch: expected StatefulSet, found Pod"
    (Result.fold ~ok:(fun _ -> "ok") ~error:Err.show (Stateful_set.unmarshal d))

let test_ss_transition_validation () =
  let base = ss_spec_sample () in
  let old_ss =
    ss ~name:(Some "s") ~namespace:(Some "ns") ~spec:(Some base) ~status:None
  in
  (* replicas is a mutable field: changing it alone is a valid transition. *)
  let new_ok =
    ss ~name:(Some "s") ~namespace:(Some "ns")
      ~spec:(Some { base with Stateful_set.replicas = Some 5 })
      ~status:None
  in
  Alcotest.(check bool) "replicas mutable" true
    (Stateful_set.transition_validation new_ok ~old:old_ss);
  (* service_name is immutable: changing it must be rejected. This assertion
     pins the guard (it flips to [true] and fails if the immutable check is
     neutered). *)
  let new_bad =
    ss ~name:(Some "s") ~namespace:(Some "ns")
      ~spec:(Some { base with Stateful_set.service_name = "other" })
      ~status:None
  in
  Alcotest.(check bool) "service_name immutable" false
    (Stateful_set.transition_validation new_bad ~old:old_ss)

let () =
  Alcotest.run "functor_views"
    [
      ( "pod",
        [
          Alcotest.test_case "roundtrip" `Quick test_pod_roundtrip;
          Alcotest.test_case "object_ref" `Quick test_pod_object_ref;
          Alcotest.test_case "wrong_kind" `Quick test_pod_wrong_kind;
        ] );
      ( "stateful_set",
        [
          Alcotest.test_case "roundtrip" `Quick test_ss_roundtrip;
          Alcotest.test_case "object_ref" `Quick test_ss_object_ref;
          Alcotest.test_case "wrong_kind" `Quick test_ss_wrong_kind;
          Alcotest.test_case "transition_validation" `Quick
            test_ss_transition_validation;
        ] );
    ]

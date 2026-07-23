(* Smoke tests for the Resource_view functor via Config_map:
     - unmarshal (marshal o) = Ok o (data present and absent);
     - object_ref fails Missing_field on an absent name, succeeds otherwise;
     - unmarshal of a wrong-kind Dynamic_object => Kind_mismatch.

   Guard/test pinning (confirm-by-mutation targets):
     - test_wrong_kind pins Resource_view.Make.unmarshal's kind check;
     - test_object_ref (missing name) pins the object_ref Missing_field branch. *)

let sample_data = Smap.add "a" "1" (Smap.add "b" "2" Smap.empty)

let meta ~name ~namespace =
  let base = Object_meta.default () in
  let base =
    Option.fold ~none:base
      ~some:(fun n -> Object_meta.with_name n base)
      name
  in
  Option.fold ~none:base
    ~some:(fun ns -> Object_meta.with_namespace ns base)
    namespace

let cm ~name ~namespace ~data =
  Config_map.make ~metadata:(meta ~name ~namespace) ~data

let test_roundtrip () =
  let c = cm ~name:(Some "cm") ~namespace:(Some "ns") ~data:(Some sample_data) in
  let back = Config_map.unmarshal (Config_map.marshal c) in
  Alcotest.(check bool) "roundtrip with data" true
    (Result.fold ~ok:(Config_map.equal c) ~error:(fun _ -> false) back);
  let c2 = cm ~name:(Some "cm") ~namespace:(Some "ns") ~data:None in
  let back2 = Config_map.unmarshal (Config_map.marshal c2) in
  Alcotest.(check bool) "roundtrip without data" true
    (Result.fold ~ok:(Config_map.equal c2) ~error:(fun _ -> false) back2)

let test_object_ref () =
  let c_ok = cm ~name:(Some "cm") ~namespace:(Some "ns") ~data:None in
  let expected =
    { Common.kind = Common.Config_map; name = "cm"; namespace = "ns" }
  in
  Alcotest.(check bool) "object_ref ok" true
    (Result.fold
       ~ok:(Common.equal_object_ref expected)
       ~error:(fun _ -> false)
       (Config_map.object_ref c_ok));
  let c_noname = cm ~name:None ~namespace:(Some "ns") ~data:None in
  Alcotest.(check string) "missing name" "required field absent: metadata.name"
    (Result.fold
       ~ok:(fun _ -> "ok")
       ~error:Err.show
       (Config_map.object_ref c_noname))

let test_wrong_kind () =
  let d =
    Dynamic_object.make ~kind:Common.Pod
      ~metadata:(meta ~name:(Some "x") ~namespace:(Some "ns"))
      ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)
  in
  Alcotest.(check string) "kind mismatch"
    "kind mismatch: expected ConfigMap, found Pod"
    (Result.fold
       ~ok:(fun _ -> "ok")
       ~error:Err.show
       (Config_map.unmarshal d))

let () =
  Alcotest.run "functor"
    [
      ("config_map", [ Alcotest.test_case "roundtrip" `Quick test_roundtrip ]);
      ("object_ref", [ Alcotest.test_case "missing/present" `Quick test_object_ref ]);
      ("kind", [ Alcotest.test_case "mismatch" `Quick test_wrong_kind ]);
    ]

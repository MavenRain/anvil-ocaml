(* Smoke tests for Common: kind equality/show, object_ref equality, and the
   abstract-newtype round-trip. *)

let test_kind_equal () =
  Alcotest.(check bool) "pod=pod" true (Common.equal_kind Common.Pod Common.Pod);
  Alcotest.(check bool)
    "configmap<>pod" false
    (Common.equal_kind Common.Config_map Common.Pod);
  Alcotest.(check bool)
    "customresource eq" true
    (Common.equal_kind (Common.Custom_resource "a") (Common.Custom_resource "a"));
  Alcotest.(check bool)
    "customresource neq" false
    (Common.equal_kind (Common.Custom_resource "a") (Common.Custom_resource "b"))

let test_show () =
  Alcotest.(check string) "configmap" "ConfigMap"
    (Common.show_kind Common.Config_map);
  Alcotest.(check string) "custom" "CustomResource(Foo)"
    (Common.show_kind (Common.Custom_resource "Foo"));
  Alcotest.(check string) "rolebinding" "RoleBinding"
    (Common.show_kind Common.Role_binding);
  Alcotest.(check string) "serviceaccount" "ServiceAccount"
    (Common.show_kind Common.Service_account)

let test_object_ref () =
  let a = { Common.kind = Common.Pod; name = "n"; namespace = "ns" } in
  let b = { Common.kind = Common.Pod; name = "n"; namespace = "ns" } in
  let c = { Common.kind = Common.Pod; name = "n"; namespace = "other" } in
  Alcotest.(check bool) "equal" true (Common.equal_object_ref a b);
  Alcotest.(check bool) "differ in namespace" false (Common.equal_object_ref a c)

let test_newtypes () =
  Alcotest.(check int) "uid" 5 (Common.Uid.to_int (Common.Uid.of_int 5));
  Alcotest.(check int) "resource_version" 7
    (Common.Resource_version.to_int (Common.Resource_version.of_int 7));
  Alcotest.(check int) "generate_name_counter" 9
    (Common.Generate_name_counter.to_int
       (Common.Generate_name_counter.of_int 9))

let () =
  Alcotest.run "common"
    [
      ( "kind",
        [
          Alcotest.test_case "equal" `Quick test_kind_equal;
          Alcotest.test_case "show" `Quick test_show;
        ] );
      ("object_ref", [ Alcotest.test_case "equal" `Quick test_object_ref ]);
      ("newtypes", [ Alcotest.test_case "round-trip" `Quick test_newtypes ]);
    ]

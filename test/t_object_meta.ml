(* Smoke tests for Object_meta: builder composition, the
   well_formed_for_namespaced truth table, owner_references_contains, and label
   add/remove. *)

let full () =
  let base =
    Object_meta.(
      default () |> with_name "n" |> with_namespace "ns"
      |> with_resource_version (Common.Resource_version.of_int 1))
  in
  { base with Object_meta.uid = Some (Common.Uid.of_int 2) }

let test_compose () =
  let m = Object_meta.(default () |> with_name "n" |> with_namespace "ns") in
  Alcotest.(check (option string)) "name" (Some "n") (Object_meta.name m);
  Alcotest.(check (option string))
    "namespace" (Some "ns") (Object_meta.namespace m)

let test_well_formed () =
  let f = full () in
  Alcotest.(check bool) "all present" true
    (Object_meta.well_formed_for_namespaced f);
  Alcotest.(check bool) "no name" false
    (Object_meta.well_formed_for_namespaced { f with Object_meta.name = None });
  Alcotest.(check bool) "no namespace" false
    (Object_meta.well_formed_for_namespaced
       { f with Object_meta.namespace = None });
  Alcotest.(check bool) "no resource_version" false
    (Object_meta.well_formed_for_namespaced
       { f with Object_meta.resource_version = None });
  Alcotest.(check bool) "no uid" false
    (Object_meta.well_formed_for_namespaced { f with Object_meta.uid = None })

let owner : Owner_reference.t =
  {
    Owner_reference.block_owner_deletion = None;
    controller = Some true;
    kind = Common.Pod;
    name = "owner";
    uid = Common.Uid.of_int 3;
  }

let test_owner_refs () =
  let other = { owner with Owner_reference.name = "other" } in
  let m = Object_meta.with_owner_references [ owner ] (Object_meta.default ()) in
  Alcotest.(check bool) "contains owner" true
    (Object_meta.owner_references_contains m owner);
  Alcotest.(check bool) "does not contain other" false
    (Object_meta.owner_references_contains m other);
  Alcotest.(check bool) "none => false" false
    (Object_meta.owner_references_contains (Object_meta.default ()) owner)

let has_label k m =
  Option.fold ~none:false
    ~some:(fun labels -> Smap.mem k labels)
    m.Object_meta.labels

let test_labels () =
  let m = Object_meta.(default () |> add_label "k" "v" |> add_label "k2" "v2") in
  Alcotest.(check bool) "added k" true (has_label "k" m);
  Alcotest.(check bool) "added k2" true (has_label "k2" m);
  let m2 = Object_meta.without_label "k" m in
  Alcotest.(check bool) "removed k" false (has_label "k" m2);
  Alcotest.(check bool) "kept k2" true (has_label "k2" m2)

let () =
  Alcotest.run "object_meta"
    [
      ("builders", [ Alcotest.test_case "compose" `Quick test_compose ]);
      ( "well_formed",
        [ Alcotest.test_case "truth table" `Quick test_well_formed ] );
      ( "owner_references",
        [ Alcotest.test_case "contains" `Quick test_owner_refs ] );
      ("labels", [ Alcotest.test_case "add/remove" `Quick test_labels ]);
    ]

(lang dune 3.0)
(name anvil)
(generate_opam_files true)

(license "MIT OR Apache-2.0")
(authors "Onyeka (Oni/MavenRain) Obi")
(maintainers "Onyeka (Oni/MavenRain) Obi")
(source
 (github MavenRain/anvil-ocaml))

(package
 (name anvil)
 (allow_empty)
 (synopsis
  "A spec-executable OCaml port of the Anvil verified-Kubernetes-controller framework")
 (description
  "A faithful, spec-executable OCaml port of the Anvil verified-Kubernetes-controller framework (github anvil-verifier/anvil). Anvil's ~55k lines of Verus proof do not port (OCaml is not a prover); the trusted specification surface does. Phase 1 is the Kubernetes object spec model: the eleven-variant object Kind, ObjectRef / ObjectMeta / OwnerReference views, the untyped DynamicObject / Value marshalling layer, the RESOURCE_VIEW functor that replaces Anvil's implement_resource_view_trait! macro, the unified api_request / api_response / api_error sum, and functor-generated typed views (config_map, pod, stateful_set). The temporal-assurance layer (Phase 0, live in comp-cat-ocaml as Lamport TLA on the topos of trees) is consumed from later phases; the k8s object model is standalone and does not depend on comp_cat.")
 (depends
  (ocaml
   (>= 5.1))
  yojson
  (alcotest :with-test)
  (qcheck-core :with-test)
  (qcheck-alcotest :with-test)))

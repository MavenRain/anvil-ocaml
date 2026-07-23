# anvil-ocaml

A faithful, spec-executable OCaml port of the [Anvil](https://github.com/anvil-verifier/anvil)
verified-Kubernetes-controller framework.

Anvil is a Verus artifact: a trusted specification surface (a shallow TLA
embedding, a cluster transition system, a reconciler contract, k8s object
views), executable reconciler code, and ~55k lines of machine-checked proof.
The proofs do **not** port (OCaml is not a prover); the specification surface
does. "Verified" downgrades, deliberately and visibly, from machine-checked
total correctness to property-based testing plus bounded lasso model checking.
See `lib/k8s_objects/BUILD-SPEC-P1.md` and, for the whole-repo plan, the
architecture note that ships with the temporal core (Phase 0) in
[comp-cat-ocaml](https://github.com/MavenRain/comp-cat-ocaml).

## Status

- **Phase 0 — temporal core** (Lamport TLA re-founded as the internal logic of
  the topos of trees): lives in comp-cat-ocaml. Consumed by later phases here.
- **Phase 1 — k8s object spec model** (this repo, done): the eleven-variant
  object `Kind`, `ObjectRef` / `ObjectMeta` / `OwnerReference` views, the
  untyped `DynamicObject` / `Value` marshalling layer, the `RESOURCE_VIEW`
  functor that replaces Anvil's `implement_resource_view_trait!` macro, the
  unified `api_request` / `api_response` / `api_error` sum, and functor-generated
  typed views (`config_map`, `pod`, `stateful_set`, with their nested object
  trees). Standalone — the k8s object model does not depend on comp_cat.

## Layout

```
lib/support/        Err (one closed error sum) + Res (the sole partiality channel)
lib/k8s_objects/    the Phase-1 object model
  common            Kind, ObjectRef, Uid/ResourceVersion newtypes
  value, json       the marshalled-value carrier + a hand-rolled yojson codec layer
  object_meta, owner_reference, dynamic_object
  resource_view     the RESOURCE_VIEW functor (Anvil's macro, as a functor)
  api_method        api_request / api_response / api_error
  container, volume, pod_spec, ...   nested object types shared across views
  views/            config_map, pod, stateful_set (functor instances)
test/               functor round-trips, QCheck marshal properties, confirm-by-mutation
```

## Design notes

- No exceptions: every partial function returns `Res.t`. The single `try/with`
  in the whole library quarantines yojson's exception-based parser in
  `Value.of_string`.
- Every finite sum is matched exhaustively (no `_ ->` catch-all).
- Marshalling is hand-rolled JSON codecs over yojson (no ppx), mirroring
  Anvil's serde_json exec model. Anvil's `marshal_preserves_*` proofs downgrade
  to QCheck round-trip properties, kept non-vacuous by generators that populate
  every optional and nested field (verified by confirm-by-mutation).

## Build

```
opam switch create anvil-ocaml ocaml-base-compiler.5.3.0   # first time
opam install yojson qcheck-core qcheck-alcotest alcotest
eval $(opam env --switch=anvil-ocaml --set-switch)
dune build
dune test
```

Dual-licensed under MIT or Apache-2.0.

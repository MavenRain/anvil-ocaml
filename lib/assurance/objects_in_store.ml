(* P17 store-side family (BUILD-SPEC-P17 §2-REVISED): a physical RE-EXPORT of
   the three objects_in_store.rs members the base suite already ships as
   inv1/inv2/inv3 of [Invariants.cluster_structural] — a filter over the very
   records that function builds, NO re-transcription and NO wrappers (a second
   copy would be drift risk and would break the (name, source) classification
   firewall by construction). All audit verdicts, exclusions and the narrowed
   novelty claim live in the .mli. *)

let store_sources : string list =
  [
    "kubernetes_cluster/proof/objects_in_store.rs:23";
    "kubernetes_cluster/proof/objects_in_store.rs:33";
    "kubernetes_cluster/proof/objects_in_store.rs:299";
  ]

let store_family ~(controller_id : int) : Invariants.invariant list =
  List.filter
    (fun (i : Invariants.invariant) ->
      List.exists (String.equal i.source) store_sources)
    (Invariants.cluster_structural ~controller_id)

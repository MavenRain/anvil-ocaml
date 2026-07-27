(* BUILD-SPEC-P18 §2: the two portable always-members of Anvil's
   [vstatefulset_controller/proof/helper_invariants.rs] (1494 lines, 11
   StatePreds, 4 true always-invariants of which these 2 are portable; the
   rest are ledgered with measured pins, spec §3), exposed as a named
   CR-parameterized family for the P18 dedicated fault leg:

   - H1 all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref
     (:52-69, lemma_always :75 via init_invariant :244)
   - H2 all_pvcs_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_or_owner_ref
     (:1063-1076, lemma_always :1078 via init_invariant :1210)

   Both upstream members premise on the STORE KEY ([pod_key]/[pvc_key]:
   contains_key + kind + name shape) and inspect the stored object's metadata
   only in the consequent; the port quantifies over [Object_ref_map.bindings]
   the same way. Every rendering deviation is disclosed in the .mli. *)

let stored_bindings (s : Cluster.cluster_state) :
    (Common.object_ref * Dynamic_object.t) list =
  Object_ref_map.bindings (Cluster.resources s)

(* Constructive inverse of [V_stateful_set_reconciler.pvc_name] for a fixed
   [parent]: true iff [name = "vstatefulset-" ^ tmpl ^ "-" ^ parent ^ "-" ^
   string_of_int ord] for SOME dash-free [tmpl] and canonical [ord >= 0]
   (upstream [pvc_name_match], predicate.rs:140-143, narrowed to the CR's own
   name - .mli). The port ships no PVC-name inverse, so the parse lives here:
   strip the reserved prefix, split at the FIRST dash (a dash-free [tmpl] can
   only be the first segment, which realises upstream's [dash_free] premise
   structurally), then certify the remainder via the exported canonical
   [get_ordinal] on the re-prefixed tail - its round-trip check proves
   [remainder = parent ^ "-" ^ string_of_int ord], hence
   [name = pvc_name tmpl parent ord] exactly. *)
let pvc_name_matches (parent : string) (name : string) : bool =
  let prefix = "vstatefulset-" in
  String.starts_with ~prefix name
  &&
  let rest =
    String.sub name (String.length prefix)
      (String.length name - String.length prefix)
  in
  Option.fold (String.index_opt rest '-') ~none:false ~some:(fun i ->
      let after_tmpl = String.sub rest (i + 1) (String.length rest - i - 1) in
      Option.is_some
        (V_stateful_set_reconciler.get_ordinal parent (prefix ^ after_tmpl)))

let helper_sources : string list =
  [
    "vstatefulset_controller/proof/helper_invariants.rs:52";
    "vstatefulset_controller/proof/helper_invariants.rs:1063";
  ]

let helper_family ~(cr : V_stateful_set.t) ~controller_id:(_ : int) :
    Invariants.invariant list =
  let md_cr : Object_meta.t = V_stateful_set.metadata cr in
  let parent = Option.value ~default:"" (Object_meta.name md_cr) in
  let vsts_ns = Option.value ~default:"" (Object_meta.namespace md_cr) in
  let co = V_stateful_set.controller_owner_ref cr in
  (* H1 premise, on the store KEY (upstream :54-58). *)
  let pod_premise (key : Common.object_ref) : bool =
    Common.equal_kind key.kind Pod.kind
    && String.equal key.namespace vsts_ns
    && Option.is_some (V_stateful_set_reconciler.get_ordinal parent key.name)
  in
  (* H2 premise, on the store KEY (upstream :1066-1068; upstream has NO
     namespace conjunct, and none is added - .mli). *)
  let pvc_premise (key : Common.object_ref) : bool =
    Common.equal_kind key.kind Persistent_volume_claim.kind
    && pvc_name_matches parent key.name
  in
  let h1 =
    {
      Invariants.name =
        "all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref";
      source = "vstatefulset_controller/proof/helper_invariants.rs:52";
      holds =
        (fun s ->
          List.for_all
            (fun ((key : Common.object_ref), (obj : Dynamic_object.t)) ->
              (not (pod_premise key))
              ||
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Option.is_none md.deletion_timestamp
              && Option.is_none md.finalizers
              && Option.fold co ~none:false
                   ~some:(fun (c : Owner_reference.t) ->
                     Option.fold md.owner_references ~none:false
                       ~some:(fun (orefs : Owner_reference.t list) ->
                         match orefs with
                         | [ r ] -> Owner_reference.eq_without_uid r c
                         | [] | _ :: _ :: _ -> false)))
            (stored_bindings s));
      interesting =
        (fun s ->
          List.exists
            (fun ((key : Common.object_ref), (_ : Dynamic_object.t)) ->
              pod_premise key)
            (stored_bindings s));
    }
  in
  let h2 =
    {
      Invariants.name =
        "all_pvcs_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_or_owner_ref";
      source = "vstatefulset_controller/proof/helper_invariants.rs:1063";
      holds =
        (fun s ->
          List.for_all
            (fun ((key : Common.object_ref), (obj : Dynamic_object.t)) ->
              (not (pvc_premise key))
              ||
              let md : Object_meta.t = Dynamic_object.metadata obj in
              Option.is_none md.owner_references
              && Option.is_none md.deletion_timestamp
              && Option.is_none md.finalizers)
            (stored_bindings s));
      interesting =
        (fun s ->
          List.exists
            (fun ((key : Common.object_ref), (_ : Dynamic_object.t)) ->
              pvc_premise key)
            (stored_bindings s));
    }
  in
  [ h1; h2 ]

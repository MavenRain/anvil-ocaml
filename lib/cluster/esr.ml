module T = Comp_cat.Temporal

module Make (R : Resource_view.RESOURCE_VIEW) = struct
  (* Anvil esr.rs: cr names a namespaced object, its key exists in etcd, and the
     stored object has the same uid, no deletion timestamp, unmarshals, and has
     the same spec as cr. Result/Option threading via combinators (no two-arm
     match on option/result outside Res); a missing key / failed unmarshal makes
     the predicate false. *)
  let desired_state_is (cr : R.t) : Cluster.cluster_state T.state_pred =
   fun s ->
    let om = R.metadata cr in
    Option.is_some (Object_meta.name om)
    && Option.is_some (Object_meta.namespace om)
    && Option.value ~default:false
         (let ( let* ) = Option.bind in
          let* key = Result.to_option (R.object_ref cr) in
          let* stored = Cluster.lookup_resource s key in
          let* unm = Result.to_option (R.unmarshal stored) in
          let stored_meta = Dynamic_object.metadata stored in
          Some
            (Option.equal Common.Uid.equal (Object_meta.uid stored_meta)
               (Object_meta.uid om)
            && Option.is_none (Object_meta.deletion_timestamp stored_meta)
            && Stdlib.(R.spec unm = R.spec cr)))

  (* A stable, cr-distinguishing leaf name so the tla_forall conjuncts do not
     hash-cons together in the {!Comp_cat.Temporal} kernel. *)
  let cr_key_name (cr : R.t) =
    Result.fold
      ~ok:(fun (r : Common.object_ref) -> r.name ^ "/" ^ r.namespace)
      ~error:(fun _ -> "unkeyed")
      (R.object_ref cr)

  let eventually_stable_reconciliation_per_cr ~cr ~current_state_matches =
    let kn = cr_key_name cr in
    T.leads_to
      (T.always (T.lift_state ~name:("desired[" ^ kn ^ "]") (desired_state_is cr)))
      (T.always
         (T.lift_state
            ~name:("matches[" ^ kn ^ "]")
            (current_state_matches cr)))

  let eventually_stable_reconciliation ~crs ~current_state_matches =
    T.tla_forall
      (fun cr -> eventually_stable_reconciliation_per_cr ~cr ~current_state_matches)
      ~domain:crs
end

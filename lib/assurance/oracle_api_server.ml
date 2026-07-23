(* Independent re-port of Anvil's SPEC api-server request handler
   (src/kubernetes_cluster/spec/api_server/state_machine.rs: the [handle_*]
   handlers l.198-820 and [transition_by_etcd] l.804), re-derived directly from
   the Verus spec rather than from our own [lib/cluster/api_server.ml] port. Used
   as the golden reference behind {!agrees}. See the .mli for the HONEST LIMIT.

   Two of Anvil's symbols are [uninterp] (they have NO derivable value): the
   deletion timestamp stamped by a finalizer-guarded delete
   ([deletion_timestamp()], state_machine.rs:353) and the name synthesised for a
   [generate_name]-only create ([generated_name], state_machine.rs:247, pinned
   only by [generated_name_spec] l.254). A differential test of a spec containing
   uninterpreted symbols is meaningful only if BOTH sides realise those symbols
   the same way, so this oracle fixes each to the same concrete realisation our
   port uses: the timestamp is a fixed opaque string, and [generated_name] is the
   canonical constructive witness of [generated_name_spec] (the smallest numeric
   suffix on [generate_name] that avoids every existing key name — trivially
   dash-free, and distinct from all existing names by pigeonhole). Every other
   line here is derived only from Anvil's spec.

   Conventions (anvil-ocaml): no loop keywords; every finite sum matched
   exhaustively (message_content's 4, api_request's 9, [Common.kind]'s 11); no
   two-arm [match] on [option]/[result] (Option.fold / Result.fold); no
   exceptions — predicates are total [bool], the handlers total functions. *)

type state = {
  resources : Api_server.stored_state;
  uid : int;
  rv : int;
}

(* Anvil [deletion_timestamp()] (state_machine.rs:353): an uninterp opaque string.
   Fixed to the same realisation the port uses so the finalizer-delete path is
   comparable under {!agrees}. *)
let stamped_deletion_timestamp : string = "2000-01-01T00:00:00Z"

(* Anvil [generated_name] (state_machine.rs:247) constrained by
   [generated_name_spec] (l.254): the result equals [prefix ^ dash_free_suffix]
   and differs from every existing key's name. The canonical constructive
   witness: pick the smallest [i] with [prefix ^ string_of_int i] free. Among the
   [n+1] candidates [prefix^"0" .. prefix^"n"] over [n] keys at least one is free,
   so [find_opt] is always [Some]; the default is only a totality plug. *)
let generated_name (s : state) (prefix : string) : string =
  let existing =
    Object_ref_map.fold (fun k _ acc -> Sset.add k.Common.name acc) s.resources Sset.empty
  in
  let n = Object_ref_map.cardinal s.resources in
  let candidates = List.init (n + 1) (fun i -> prefix ^ string_of_int i) in
  Option.value
    (List.find_opt (fun c -> not (Sset.mem c existing)) candidates)
    ~default:(prefix ^ string_of_int (n + 1))

(* Anvil [unmarshallable_object] (state_machine.rs:109): spec AND status unmarshal.
   The per-[kind] dispatch is folded into [installed_types]. *)
let unmarshallable_object (it : Api_server.installed_types) (obj : Dynamic_object.t) : bool =
  it.unmarshallable_spec (Dynamic_object.kind obj) (Dynamic_object.spec obj)
  && it.unmarshallable_status (Dynamic_object.kind obj) (Dynamic_object.status obj)

(* Anvil [metadata_validity_check] (state_machine.rs:113): [Invalid] iff there is
   more than one owner reference AND more than one of them is a controller. *)
let metadata_validity_check (obj : Dynamic_object.t) : Api_method.api_error option =
  let m = Dynamic_object.metadata obj in
  Option.fold ~none:None
    ~some:(fun refs ->
      let controllers = List.filter Owner_reference.is_controller refs in
      if List.length refs > 1 && List.length controllers > 1 then Some Api_method.Invalid
      else None)
    m.owner_references

(* Anvil [metadata_transition_validity_check] (state_machine.rs:123): [Forbidden]
   iff the old object is already terminating, the new object still has finalizers,
   and the new finalizer set is NOT a subset of the old one (finalizers added
   during deletion). *)
let metadata_transition_validity_check (obj : Dynamic_object.t) (old_obj : Dynamic_object.t) :
    Api_method.api_error option =
  let om = Dynamic_object.metadata old_obj in
  let nm = Dynamic_object.metadata obj in
  let old_terminating = Option.is_some (Object_meta.deletion_timestamp om) in
  let new_has_finalizers = Option.is_some nm.finalizers in
  let not_subset =
    not (Sset.subset (Object_meta.finalizers_as_set nm) (Object_meta.finalizers_as_set om))
  in
  if old_terminating && new_has_finalizers && not_subset then Some Api_method.Forbidden else None

(* Anvil [object_validity_check] (state_machine.rs:149): [Invalid] unless the
   object passes [state_validation]. *)
let object_validity_check (it : Api_server.installed_types) (obj : Dynamic_object.t) :
    Api_method.api_error option =
  if it.valid_object obj then None else Some Api_method.Invalid

(* Anvil [object_transition_validity_check] (state_machine.rs:173): [Invalid]
   unless [transition_validation new old] holds (Anvil argument order new, old). *)
let object_transition_validity_check (it : Api_server.installed_types) (obj : Dynamic_object.t)
    (old_obj : Dynamic_object.t) : Api_method.api_error option =
  if it.valid_transition obj old_obj then None else Some Api_method.Invalid

(* First [Some] in a left-to-right list — Anvil's ordered [is Some] fall-through
   spelled as a combinator (all entries are pure/total, so eager eval is safe). *)
let first_some (checks : Api_method.api_error option list) : Api_method.api_error option =
  List.fold_left (fun acc c -> Option.fold ~none:c ~some:(fun e -> Some e) acc) None checks

(* Anvil [created_object_validity_check] (state_machine.rs:237). *)
let created_object_validity_check (it : Api_server.installed_types) (created_obj : Dynamic_object.t) :
    Api_method.api_error option =
  first_some [ metadata_validity_check created_obj; object_validity_check it created_obj ]

(* Anvil [updated_object_validity_check] (state_machine.rs:488). *)
let updated_object_validity_check (it : Api_server.installed_types) (updated_obj : Dynamic_object.t)
    (old_obj : Dynamic_object.t) : Api_method.api_error option =
  first_some
    [
      metadata_validity_check updated_obj;
      metadata_transition_validity_check updated_obj old_obj;
      object_validity_check it updated_obj;
      object_transition_validity_check it updated_obj old_obj;
    ]

(* Anvil [allow_unconditional_update] (state_machine.rs:418): every kind except a
   custom resource allows update without a resource version. Exhaustive over the
   11 kinds, no catch-all. *)
let allow_unconditional_update (k : Common.kind) : bool =
  match k with
  | Common.Custom_resource _ -> false
  | Common.Config_map | Common.Daemon_set | Common.Persistent_volume_claim | Common.Pod | Common.Role
  | Common.Role_binding | Common.Stateful_set | Common.Service | Common.Service_account | Common.Secret
    ->
    true

(* Anvil [handle_get_request] (state_machine.rs:198). *)
let handle_get_request (r : Api_method.get_request) (s : state) : Api_method.get_response =
  let key = Api_method.get_request_key r in
  ({
     Api_method.res =
       Option.fold ~none:(Error Api_method.Object_not_found) ~some:(fun o -> Ok o)
         (Object_ref_map.find_opt key s.resources);
   }
    : Api_method.get_response)

(* Anvil [handle_list_request] (state_machine.rs:209): every stored object whose
   namespace AND kind match [req], in the deterministic map key order. *)
let handle_list_request (r : Api_method.list_request) (s : state) : Api_method.list_response =
  let req_kind = r.kind in
  let req_ns = r.namespace in
  let objs =
    Object_ref_map.fold
      (fun _k o acc ->
        let m = Dynamic_object.metadata o in
        let ns_ok =
          Option.fold ~none:false ~some:(fun ns -> String.equal ns req_ns) (Object_meta.namespace m)
        in
        let kind_ok = Common.equal_kind (Dynamic_object.kind o) req_kind in
        if kind_ok && ns_ok then o :: acc else acc)
      s.resources []
  in
  ({ Api_method.res = Ok (List.rev objs) } : Api_method.list_response)

(* Anvil [handle_create_request] (state_machine.rs:273) with its inlined
   [create_request_admission_check] (l.219). uid/rv are the PRE-increment counter
   snapshots; on success both counters advance by one — the only handler that
   bumps [uid]. *)
let handle_create_request (it : Api_server.installed_types) (r : Api_method.create_request)
    (s : state) : state * Api_method.create_response =
  let obj = r.obj in
  let req_ns = r.namespace in
  let m = Dynamic_object.metadata obj in
  let name_opt = Object_meta.name m in
  let gen_opt = m.generate_name in
  let ns_opt = Object_meta.namespace m in
  let admission =
    if Option.is_none name_opt && Option.is_none gen_opt then Some Api_method.Invalid
    else if Option.fold ~none:false ~some:(fun ns -> not (String.equal req_ns ns)) ns_opt then
      Some Api_method.Bad_request
    else if not (unmarshallable_object it obj) then Some Api_method.Bad_request
    else if
      Option.fold ~none:false
        ~some:(fun nm ->
          Object_ref_map.mem
            { Common.kind = Dynamic_object.kind obj; namespace = req_ns; name = nm }
            s.resources)
        name_opt
    then Some Api_method.Object_already_exists
    else None
  in
  Option.fold
    ~some:(fun err -> (s, ({ Api_method.res = Error err } : Api_method.create_response)))
    ~none:
      (let stamped_name =
         Option.value name_opt ~default:(generated_name s (Option.value gen_opt ~default:""))
       in
       let created_md =
         {
           m with
           name = Some stamped_name;
           namespace = Some req_ns;
           resource_version = Some (Common.Resource_version.of_int s.rv);
           uid = Some (Common.Uid.of_int s.uid);
           deletion_timestamp = None;
         }
       in
       let created_obj =
         Dynamic_object.make ~kind:(Dynamic_object.kind obj) ~metadata:created_md
           ~spec:(Dynamic_object.spec obj)
           ~status:(it.marshalled_default_status (Dynamic_object.kind obj))
       in
       let created_key =
         { Common.kind = Dynamic_object.kind obj; namespace = req_ns; name = stamped_name }
       in
       if Object_ref_map.mem created_key s.resources then
         (s, ({ Api_method.res = Error Api_method.Object_already_exists } : Api_method.create_response))
       else
         Option.fold
           ~some:(fun err -> (s, ({ Api_method.res = Error err } : Api_method.create_response)))
           ~none:
             ( {
                 resources = Object_ref_map.add created_key created_obj s.resources;
                 uid = s.uid + 1;
                 rv = s.rv + 1;
               },
               ({ Api_method.res = Ok created_obj } : Api_method.create_response) )
           (created_object_validity_check it created_obj))
    admission

(* Anvil [delete_request_admission_check] (state_machine.rs:325): ObjectNotFound
   then the uid / resource-version precondition Conflicts. *)
let delete_admission (r : Api_method.delete_request) (s : state) : Api_method.api_error option =
  let key = Api_method.delete_request_key r in
  if not (Object_ref_map.mem key s.resources) then Some Api_method.Object_not_found
  else
    Option.fold ~none:None
      ~some:(fun (p : Api_method.preconditions) ->
        let stored_uid =
          Option.bind (Object_ref_map.find_opt key s.resources) (fun o ->
              (Dynamic_object.metadata o).uid)
        in
        let stored_rv =
          Option.bind (Object_ref_map.find_opt key s.resources) (fun o ->
              (Dynamic_object.metadata o).resource_version)
        in
        if Option.is_some p.uid && not (Option.equal Common.Uid.equal p.uid stored_uid) then
          Some Api_method.Conflict
        else if
          Option.is_some p.resource_version
          && not (Option.equal Common.Resource_version.equal p.resource_version stored_rv)
        then Some Api_method.Conflict
        else None)
      r.preconditions

(* The post-admission body of Anvil [handle_delete_request] (state_machine.rs:360):
   with finalizers, stamp a deletion timestamp + new rv under [req.key] (no-op if
   already terminating); without, remove the key. Both advance rv. *)
let delete_proceed (key : Common.object_ref) (s : state) : state * Api_method.delete_response =
  Option.fold
    ~none:(s, ({ Api_method.res = Error Api_method.Internal_error } : Api_method.delete_response))
    ~some:(fun obj ->
      let m = Dynamic_object.metadata obj in
      let has_finalizers = Option.fold ~none:false ~some:(fun f -> List.length f > 0) m.finalizers in
      if has_finalizers then
        if Option.is_some (Object_meta.deletion_timestamp m) then
          (s, ({ Api_method.res = Ok () } : Api_method.delete_response))
        else
          let stamped =
            obj
            |> Dynamic_object.with_deletion_timestamp stamped_deletion_timestamp
            |> Dynamic_object.with_resource_version (Common.Resource_version.of_int s.rv)
          in
          ( { s with resources = Object_ref_map.add key stamped s.resources; rv = s.rv + 1 },
            ({ Api_method.res = Ok () } : Api_method.delete_response) )
      else
        ( { s with resources = Object_ref_map.remove key s.resources; rv = s.rv + 1 },
          ({ Api_method.res = Ok () } : Api_method.delete_response) ))
    (Object_ref_map.find_opt key s.resources)

let handle_delete_request (r : Api_method.delete_request) (s : state) :
    state * Api_method.delete_response =
  let key = Api_method.delete_request_key r in
  Option.fold
    ~some:(fun err -> (s, ({ Api_method.res = Error err } : Api_method.delete_response)))
    ~none:(delete_proceed key s) (delete_admission r s)

(* Anvil [update_request_admission_check_helper] (state_machine.rs:425): four
   BadRequests, ObjectNotFound, Invalid (unconditional update of a CR), then the
   rv / uid Conflicts. Shared by update and update-status. *)
let update_admission (it : Api_server.installed_types) (req_name : string) (req_ns : string)
    (obj : Dynamic_object.t) (s : state) : Api_method.api_error option =
  let m = Dynamic_object.metadata obj in
  let name_opt = Object_meta.name m in
  let ns_opt = Object_meta.namespace m in
  let rv_opt = m.resource_version in
  let uid_opt = m.uid in
  let key = { Common.kind = Dynamic_object.kind obj; namespace = req_ns; name = req_name } in
  if Option.is_none name_opt then Some Api_method.Bad_request
  else if not (Option.fold ~none:false ~some:(fun n -> String.equal req_name n) name_opt) then
    Some Api_method.Bad_request
  else if Option.fold ~none:false ~some:(fun ns -> not (String.equal req_ns ns)) ns_opt then
    Some Api_method.Bad_request
  else if not (unmarshallable_object it obj) then Some Api_method.Bad_request
  else if not (Object_ref_map.mem key s.resources) then Some Api_method.Object_not_found
  else
    let stored_rv =
      Option.bind (Object_ref_map.find_opt key s.resources) (fun o ->
          (Dynamic_object.metadata o).resource_version)
    in
    let stored_uid =
      Option.bind (Object_ref_map.find_opt key s.resources) (fun o -> (Dynamic_object.metadata o).uid)
    in
    if Option.is_none rv_opt && not (allow_unconditional_update (Dynamic_object.kind obj)) then
      Some Api_method.Invalid
    else if
      Option.is_some rv_opt && not (Option.equal Common.Resource_version.equal rv_opt stored_rv)
    then Some Api_method.Conflict
    else if Option.is_some uid_opt && not (Option.equal Common.Uid.equal uid_opt stored_uid) then
      Some Api_method.Conflict
    else None

(* Anvil [updated_object] (state_machine.rs:472): the request object with kind /
   namespace / rv / uid / deletion_timestamp / status forced from the stored one. *)
let updated_object (req_ns : string) (req_obj : Dynamic_object.t) (old_obj : Dynamic_object.t) :
    Dynamic_object.t =
  let om = Dynamic_object.metadata old_obj in
  let rm = Dynamic_object.metadata req_obj in
  let new_md =
    {
      rm with
      namespace = Some req_ns;
      resource_version = om.resource_version;
      uid = om.uid;
      deletion_timestamp = om.deletion_timestamp;
    }
  in
  Dynamic_object.make ~kind:(Dynamic_object.kind old_obj) ~metadata:new_md
    ~spec:(Dynamic_object.spec req_obj) ~status:(Dynamic_object.status old_obj)

(* Anvil [status_updated_object] (state_machine.rs:574): the stored object with
   only its status replaced by the request's. *)
let status_updated_object (req_obj : Dynamic_object.t) (old_obj : Dynamic_object.t) :
    Dynamic_object.t =
  Dynamic_object.make ~kind:(Dynamic_object.kind old_obj) ~metadata:(Dynamic_object.metadata old_obj)
    ~spec:(Dynamic_object.spec old_obj) ~status:(Dynamic_object.status req_obj)

(* Anvil [handle_update_request] (state_machine.rs:503): a structurally-unchanged
   merge is a no-op [Ok old] (no rv bump); otherwise stamp the current rv, run the
   validity checks, then re-insert — or, when the merge leaves a deletion
   timestamp with no finalizers, remove the object (delete-during-update). *)
let handle_update_request (it : Api_server.installed_types) (r : Api_method.update_request)
    (s : state) : state * Api_method.update_response =
  let obj = r.obj in
  let req_ns = r.namespace in
  let req_name = r.name in
  let key = { Common.kind = Dynamic_object.kind obj; namespace = req_ns; name = req_name } in
  Option.fold
    ~some:(fun err -> (s, ({ Api_method.res = Error err } : Api_method.update_response)))
    ~none:
      (Option.fold
         ~none:(s, ({ Api_method.res = Error Api_method.Internal_error } : Api_method.update_response))
         ~some:(fun old_obj ->
           let updated = updated_object req_ns obj old_obj in
           if Dynamic_object.equal updated old_obj then
             (s, ({ Api_method.res = Ok old_obj } : Api_method.update_response))
           else
             let updated_rv =
               Dynamic_object.with_resource_version (Common.Resource_version.of_int s.rv) updated
             in
             Option.fold
               ~some:(fun err ->
                 (s, ({ Api_method.res = Error err } : Api_method.update_response)))
               ~none:
                 (let nm = Dynamic_object.metadata updated_rv in
                  let dt_none = Option.is_none (Object_meta.deletion_timestamp nm) in
                  let has_finalizers =
                    Option.fold ~none:false ~some:(fun f -> List.length f > 0) nm.finalizers
                  in
                  if dt_none || has_finalizers then
                    ( { s with resources = Object_ref_map.add key updated_rv s.resources; rv = s.rv + 1 },
                      ({ Api_method.res = Ok updated_rv } : Api_method.update_response) )
                  else
                    ( { s with resources = Object_ref_map.remove key s.resources; rv = s.rv + 1 },
                      ({ Api_method.res = Ok updated_rv } : Api_method.update_response) ))
               (updated_object_validity_check it updated_rv old_obj))
         (Object_ref_map.find_opt key s.resources))
    (update_admission it req_name req_ns obj s)

(* Anvil [handle_update_status_request] (state_machine.rs:585): as update but
   status-only and with no delete-during-update branch — it only ever re-inserts. *)
let handle_update_status_request (it : Api_server.installed_types)
    (r : Api_method.update_status_request) (s : state) : state * Api_method.update_status_response =
  let obj = r.obj in
  let req_ns = r.namespace in
  let req_name = r.name in
  let key = { Common.kind = Dynamic_object.kind obj; namespace = req_ns; name = req_name } in
  Option.fold
    ~some:(fun err -> (s, ({ Api_method.res = Error err } : Api_method.update_status_response)))
    ~none:
      (Option.fold
         ~none:
           (s, ({ Api_method.res = Error Api_method.Internal_error } : Api_method.update_status_response))
         ~some:(fun old_obj ->
           let updated = status_updated_object obj old_obj in
           if Dynamic_object.equal updated old_obj then
             (s, ({ Api_method.res = Ok old_obj } : Api_method.update_status_response))
           else
             let updated_rv =
               Dynamic_object.with_resource_version (Common.Resource_version.of_int s.rv) updated
             in
             Option.fold
               ~some:(fun err ->
                 (s, ({ Api_method.res = Error err } : Api_method.update_status_response)))
               ~none:
                 ( { s with resources = Object_ref_map.add key updated_rv s.resources; rv = s.rv + 1 },
                   ({ Api_method.res = Ok updated_rv } : Api_method.update_status_response) )
               (updated_object_validity_check it updated_rv old_obj))
         (Object_ref_map.find_opt key s.resources))
    (update_admission it req_name req_ns obj s)

(* Anvil [handle_get_then_delete_request_msg] (state_machine.rs:673): BadRequest if
   the request is not controller-owned; else an internal GET (forwarding
   ObjectNotFound), an owner-reference gate (TransactionAbort on fail), then an
   unconditioned delete whose result is forwarded. *)
let handle_get_then_delete_request_msg (msg : Message.t) (r : Api_method.get_then_delete_request)
    (s : state) : state * Message.t =
  if not (Api_method.get_then_delete_well_formed r) then
    ( s,
      Message.form_get_then_delete_resp_msg msg
        ({ Api_method.res = Error Api_method.Bad_request } : Api_method.get_then_delete_response) )
  else
    let key = Api_method.get_then_delete_request_key r in
    let get_resp = handle_get_request ({ Api_method.key = key } : Api_method.get_request) s in
    Result.fold
      ~error:(fun err ->
        ( s,
          Message.form_get_then_delete_resp_msg msg
            ({ Api_method.res = Error err } : Api_method.get_then_delete_response) ))
      ~ok:(fun (_ : Dynamic_object.t) ->
        Option.fold
          ~none:
            ( s,
              Message.form_get_then_delete_resp_msg msg
                ({ Api_method.res = Error Api_method.Internal_error }
                  : Api_method.get_then_delete_response) )
          ~some:(fun current ->
            if Object_meta.owner_references_contains (Dynamic_object.metadata current) r.owner_ref
            then
              let s', del_resp =
                handle_delete_request
                  ({ Api_method.key = key; preconditions = None } : Api_method.delete_request) s
              in
              ( s',
                Message.form_get_then_delete_resp_msg msg
                  ({ Api_method.res = del_resp.res } : Api_method.get_then_delete_response) )
            else
              ( s,
                Message.form_get_then_delete_resp_msg msg
                  ({ Api_method.res = Error Api_method.Transaction_abort }
                    : Api_method.get_then_delete_response) ))
          (Object_ref_map.find_opt key s.resources))
      get_resp.res

(* Anvil [handle_get_then_update_request_msg] (state_machine.rs:714): as the delete
   composite, but when owned it rebuilds the object from [req.obj] taking rv/uid
   from the stored object (so the delegated update never Conflicts). *)
let handle_get_then_update_request_msg (it : Api_server.installed_types) (msg : Message.t)
    (r : Api_method.get_then_update_request) (s : state) : state * Message.t =
  if not (Api_method.get_then_update_well_formed r) then
    ( s,
      Message.form_get_then_update_resp_msg msg
        ({ Api_method.res = Error Api_method.Bad_request } : Api_method.get_then_update_response) )
  else
    let key = Api_method.get_then_update_request_key r in
    let get_resp = handle_get_request ({ Api_method.key = key } : Api_method.get_request) s in
    Result.fold
      ~error:(fun err ->
        ( s,
          Message.form_get_then_update_resp_msg msg
            ({ Api_method.res = Error err } : Api_method.get_then_update_response) ))
      ~ok:(fun (_ : Dynamic_object.t) ->
        Option.fold
          ~none:
            ( s,
              Message.form_get_then_update_resp_msg msg
                ({ Api_method.res = Error Api_method.Internal_error }
                  : Api_method.get_then_update_response) )
          ~some:(fun current ->
            if Object_meta.owner_references_contains (Dynamic_object.metadata current) r.owner_ref
            then
              let cm = Dynamic_object.metadata current in
              let rm = Dynamic_object.metadata r.obj in
              let new_md = { rm with resource_version = cm.resource_version; uid = cm.uid } in
              let new_obj = Dynamic_object.with_metadata new_md r.obj in
              let s', upd_resp =
                handle_update_request it
                  ({ Api_method.namespace = r.namespace; name = r.name; obj = new_obj }
                    : Api_method.update_request)
                  s
              in
              ( s',
                Message.form_get_then_update_resp_msg msg
                  ({ Api_method.res = upd_resp.res } : Api_method.get_then_update_response) )
            else
              ( s,
                Message.form_get_then_update_resp_msg msg
                  ({ Api_method.res = Error Api_method.Transaction_abort }
                    : Api_method.get_then_update_response) ))
          (Object_ref_map.find_opt key s.resources))
      get_resp.res

(* Anvil [handle_get_then_update_status_request_msg] (state_machine.rs:760): as the
   update composite, but the rebuilt object is the stored object with only its
   status replaced, delegated to update-status. *)
let handle_get_then_update_status_request_msg (it : Api_server.installed_types) (msg : Message.t)
    (r : Api_method.get_then_update_status_request) (s : state) : state * Message.t =
  if not (Api_method.get_then_update_status_well_formed r) then
    ( s,
      Message.form_get_then_update_status_resp_msg msg
        ({ Api_method.res = Error Api_method.Bad_request }
          : Api_method.get_then_update_status_response) )
  else
    let key = Api_method.get_then_update_status_request_key r in
    let get_resp = handle_get_request ({ Api_method.key = key } : Api_method.get_request) s in
    Result.fold
      ~error:(fun err ->
        ( s,
          Message.form_get_then_update_status_resp_msg msg
            ({ Api_method.res = Error err } : Api_method.get_then_update_status_response) ))
      ~ok:(fun (_ : Dynamic_object.t) ->
        Option.fold
          ~none:
            ( s,
              Message.form_get_then_update_status_resp_msg msg
                ({ Api_method.res = Error Api_method.Internal_error }
                  : Api_method.get_then_update_status_response) )
          ~some:(fun current ->
            if Object_meta.owner_references_contains (Dynamic_object.metadata current) r.owner_ref
            then
              let new_obj =
                Dynamic_object.make ~kind:(Dynamic_object.kind current)
                  ~metadata:(Dynamic_object.metadata current) ~spec:(Dynamic_object.spec current)
                  ~status:(Dynamic_object.status r.obj)
              in
              let s', us_resp =
                handle_update_status_request it
                  ({ Api_method.namespace = r.namespace; name = r.name; obj = new_obj }
                    : Api_method.update_status_request)
                  s
              in
              ( s',
                Message.form_get_then_update_status_resp_msg msg
                  ({ Api_method.res = us_resp.res } : Api_method.get_then_update_status_response) )
            else
              ( s,
                Message.form_get_then_update_status_resp_msg msg
                  ({ Api_method.res = Error Api_method.Transaction_abort }
                    : Api_method.get_then_update_status_response) ))
          (Object_ref_map.find_opt key s.resources))
      get_resp.res

let of_api_server (s : Api_server.state) : state =
  { resources = s.resources; uid = s.uid_counter; rv = s.resource_version_counter }

(* Anvil [transition_by_etcd] (state_machine.rs:804): dispatch the api-request verb
   over all nine variants, wrapping each response with its paired [form_*_resp_msg].
   A message whose content is not a request is returned unchanged (the total
   completion of Anvil's [recommends msg.content is APIRequest]). *)
let handle (it : Api_server.installed_types) (msg : Message.t) (s : state) : state * Message.t =
  match msg.content with
  | Message.Api_request req -> (
    match req with
    | Api_method.Get_request r -> (s, Message.form_get_resp_msg msg (handle_get_request r s))
    | Api_method.List_request r -> (s, Message.form_list_resp_msg msg (handle_list_request r s))
    | Api_method.Create_request r ->
      let s', resp = handle_create_request it r s in
      (s', Message.form_create_resp_msg msg resp)
    | Api_method.Delete_request r ->
      let s', resp = handle_delete_request r s in
      (s', Message.form_delete_resp_msg msg resp)
    | Api_method.Update_request r ->
      let s', resp = handle_update_request it r s in
      (s', Message.form_update_resp_msg msg resp)
    | Api_method.Update_status_request r ->
      let s', resp = handle_update_status_request it r s in
      (s', Message.form_update_status_resp_msg msg resp)
    | Api_method.Get_then_delete_request r -> handle_get_then_delete_request_msg msg r s
    | Api_method.Get_then_update_request r -> handle_get_then_update_request_msg it msg r s
    | Api_method.Get_then_update_status_request r ->
      handle_get_then_update_status_request_msg it msg r s)
  | Message.Api_response _ -> (s, msg)
  | Message.External_request _ -> (s, msg)
  | Message.External_response _ -> (s, msg)

(* Two etcd stores are equal iff they bind the same keys to structurally-equal
   objects: keys through the map's own ordering, values through
   {!Dynamic_object.equal} — a field-by-field structural compare whose spec/status
   legs are themselves marshalled-string comparisons ([Value.equal]), so this is
   the representation-independent "compare as maps of Dynamic_object" the .mli asks
   for without depending on Yojson directly. *)
let stores_equal (a : Api_server.stored_state) (b : Api_server.stored_state) : bool =
  Object_ref_map.equal Dynamic_object.equal a b

let agrees (it : Api_server.installed_types) (msg : Message.t) (api_state : Api_server.state) : bool =
  let oracle_s, oracle_msg = handle it msg (of_api_server api_state) in
  let port_s, port_msg = Api_server.transition_by_etcd it msg api_state in
  stores_equal oracle_s.resources port_s.resources
  && Message.equal oracle_msg port_msg
  && oracle_s.uid = port_s.uid_counter
  && oracle_s.rv = port_s.resource_version_counter

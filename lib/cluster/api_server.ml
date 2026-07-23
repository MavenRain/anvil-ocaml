(* Anvil source: kubernetes_cluster/spec/api_server/{types.rs, state_machine.rs}.

   The API server / etcd datastore host: the persistent {!state}, the concrete
   {!installed_types} dispatch (see the .mli for the modelling divergence from
   Anvil's [spec_fn] map), and [handle_request] dispatching a received request
   over the nine [Api_method.api_request] variants.

   Firewall notes. Anvil's ordered [Option<APIError>] admission/validity checks
   ("first [Some] wins") are the {!or_else} combinator, never a two-arm [match]
   on the option. The [Some e => reject / None => continue] decision at each
   handler is {!decide} (an [Option.fold]/[Result.fold], both continuations
   lazy). Anvil's total [obj.object_ref()] (a partial [->0] unwrap sound only
   because the code path guarantees [name]/[namespace] present) is recovered by
   building the [Common.object_ref] from the stamped strings directly. The nine
   [api_request] variants and the four [message_content] variants are matched
   exhaustively, no [_ ->]. *)

type stored_state = Dynamic_object.t Object_ref_map.t

type state = {
  resources : stored_state;
  uid_counter : int;
  resource_version_counter : int;
}

type installed_types = {
  unmarshallable_spec : Common.kind -> Value.t -> bool;
  unmarshallable_status : Common.kind -> Value.t -> bool;
  valid_object : Dynamic_object.t -> bool;
  valid_transition : Dynamic_object.t -> Dynamic_object.t -> bool;
  marshalled_default_status : Common.kind -> Value.t;
}

type action_input = { recv : Message.t option }
type action_output = { send : Message.Pool.t }
type step = Handle_request

(* Anvil [deletion_timestamp()] (state_machine.rs:353) is an [uninterp] constant;
   only its [Some]-ness is observed. Modelled as one opaque marker string. *)
let deletion_timestamp : string = "2000-01-01T00:00:00Z"

(* ------------------------------------------------------------------ *)
(* Small total combinators for the ordered [Option<APIError>] checks.  *)
(* ------------------------------------------------------------------ *)

(* [guard cond err]: Anvil's [if cond { Some(err) } else { None }] clause. *)
let guard (cond : bool) (err : Api_method.api_error) : Api_method.api_error option =
  if cond then Some err else None

(* [or_else first second]: Anvil's ordered [if first is Some { first } else
   second()] validity fall-through; [second] runs only when [first] is [None].
   An [if] on a [bool] ([Option.is_none]), not a two-arm [match] on the option. *)
let or_else (first : 'a option) (second : unit -> 'a option) : 'a option =
  if Option.is_none first then second () else first

(* [decide adm ~reject ~pass]: Anvil's [match adm { Some(e) => reject(e),
   None => pass() }] where [adm] is an admission/validity result ([Some] =
   reject). Routed through [Result.fold] so both continuations stay lazy and no
   two-arm [match] on the option/result appears. *)
let decide (adm : Api_method.api_error option)
    ~(reject : Api_method.api_error -> 'r) ~(pass : unit -> 'r) : 'r =
  Result.fold ~ok:pass ~error:reject
    (Option.fold adm ~none:(Ok ()) ~some:(fun e -> Error e))

(* ------------------------------------------------------------------ *)
(* Accessors.                                                          *)
(* ------------------------------------------------------------------ *)

let lookup (key : Common.object_ref) (store : stored_state) : Dynamic_object.t option =
  Object_ref_map.find_opt key store

(* Anvil [api_server().init] (state_machine.rs:838): only [resources] empty. *)
let init (s : state) : bool = Object_ref_map.is_empty s.resources

(* ------------------------------------------------------------------ *)
(* Validation helpers (state_machine.rs:76-195).                       *)
(* ------------------------------------------------------------------ *)

(* Anvil [unmarshallable_object] (state_machine.rs:109) =
   [unmarshallable_spec && unmarshallable_status]; each dispatches on
   [obj.kind] inside {!installed_types}. *)
let unmarshallable_object (it : installed_types) (obj : Dynamic_object.t) : bool =
  it.unmarshallable_spec (Dynamic_object.kind obj) (Dynamic_object.spec obj)
  && it.unmarshallable_status (Dynamic_object.kind obj) (Dynamic_object.status obj)

(* Anvil [metadata_validity_check] (state_machine.rs:113): [Invalid] iff more
   than one owner reference is a controller-owner ([controller = Some true]);
   the [len() > 1] pre-filter is Anvil's optimisation, the controlling count is
   the real condition. *)
let metadata_validity_check (obj : Dynamic_object.t) : Api_method.api_error option =
  let m : Object_meta.t = Dynamic_object.metadata obj in
  let bad =
    Option.fold m.owner_references ~none:false ~some:(fun refs ->
        List.length refs > 1
        && List.length (List.filter Owner_reference.is_controller refs) > 1)
  in
  guard bad Api_method.Invalid

(* Anvil [metadata_transition_validity_check] (state_machine.rs:123):
   [Forbidden] iff the object is already terminating ([old.deletion_timestamp is
   Some]) and the new finalizer set is present and not a subset of the old — you
   may not ADD a finalizer once deletion has started (removing all is allowed,
   hence the [finalizers is Some] short-circuit). *)
let metadata_transition_validity_check (obj : Dynamic_object.t)
    (old_obj : Dynamic_object.t) : Api_method.api_error option =
  let m : Object_meta.t = Dynamic_object.metadata obj in
  let om : Object_meta.t = Dynamic_object.metadata old_obj in
  let bad =
    Option.is_some om.deletion_timestamp
    && Option.is_some m.finalizers
    && not
         (Sset.subset (Object_meta.finalizers_as_set m)
            (Object_meta.finalizers_as_set om))
  in
  guard bad Api_method.Forbidden

(* Anvil [object_validity_check] (state_machine.rs:149): [Invalid] iff
   [state_validation] fails. *)
let object_validity_check (it : installed_types) (obj : Dynamic_object.t) :
    Api_method.api_error option =
  guard (not (it.valid_object obj)) Api_method.Invalid

(* Anvil [object_transition_validity_check] (state_machine.rs:173): [Invalid] iff
   [transition_validation] fails; Anvil argument order is [(new, old)]. *)
let object_transition_validity_check (it : installed_types)
    (obj : Dynamic_object.t) (old_obj : Dynamic_object.t) :
    Api_method.api_error option =
  guard (not (it.valid_transition obj old_obj)) Api_method.Invalid

(* Anvil [created_object_validity_check] (state_machine.rs:237): metadata check
   then object (state) validity; NO transition check (the object is brand new). *)
let created_object_validity_check (it : installed_types)
    (created_obj : Dynamic_object.t) : Api_method.api_error option =
  or_else (metadata_validity_check created_obj) (fun () ->
      object_validity_check it created_obj)

(* Anvil [updated_object_validity_check] (state_machine.rs:488): metadata,
   metadata-transition, object, object-transition — first [Some] wins. *)
let updated_object_validity_check (it : installed_types)
    ~(updated : Dynamic_object.t) ~(old : Dynamic_object.t) :
    Api_method.api_error option =
  or_else (metadata_validity_check updated) (fun () ->
      or_else (metadata_transition_validity_check updated old) (fun () ->
          or_else (object_validity_check it updated) (fun () ->
              object_transition_validity_check it updated old)))

(* Anvil [allow_unconditional_update] (state_machine.rs:415): a custom resource
   must supply a resourceVersion; every built-in may be updated unconditionally.
   Exhaustive 11-arm match (Anvil's [_ => true] spelled out over the ten
   built-in kinds), no wildcard. *)
let allow_unconditional_update (kind : Common.kind) : bool =
  match kind with
  | Common.Custom_resource _ -> false
  | Common.Config_map | Common.Daemon_set | Common.Persistent_volume_claim
  | Common.Pod | Common.Role | Common.Role_binding | Common.Stateful_set
  | Common.Service | Common.Service_account | Common.Secret ->
      true

(* Anvil [generated_name] (state_machine.rs:247) is an [uninterp] oracle
   constrained by [generated_name_spec] (state_machine.rs:254-262) to (a) differ
   from EVERY existing key's [.name] and (b) equal [generate_name ++
   dash_free_suffix]. We realise (a) constructively: [generate_name] followed by
   a decimal suffix picked fresh against the set of existing key names. With [n]
   existing names the [n+1] candidates [generate_name ++ "0" .. generate_name ++
   string_of_int n] cannot all be blocked (pigeonhole: [n] names rule out at most
   [n] of them), so [List.find_opt] is always [Some] and the [~default] only
   totalises the call. The suffix is digits-only (dash-free), giving (b).

   Because the name is now provably disjoint from every existing name, the
   defensive [contains_key] re-check in {!handle_create_request} is DEAD for the
   [generate_name] path (it can never fire there). It is kept only for the
   explicit-client-[name] path: a create supplying [metadata.name] already in the
   store still hits that re-check and returns [ObjectAlreadyExists]. *)
let generated_name (s : state) (generate_name : string) : string =
  let names =
    Object_ref_map.fold
      (fun (k : Common.object_ref) _ acc -> Sset.add k.name acc)
      s.resources Sset.empty
  in
  let n = Sset.cardinal names in
  let candidate i = generate_name ^ string_of_int i in
  (* pigeonhole: among candidates 0..n at least one name is fresh, so find_opt
     is always Some; the default is unreachable and only totalises the call. *)
  List.find_opt (fun i -> not (Sset.mem (candidate i) names)) (List.init (n + 1) Fun.id)
  |> Option.map candidate
  |> Option.value ~default:(candidate (n + 1))

(* ------------------------------------------------------------------ *)
(* Read handlers (state_machine.rs:197-217). State unchanged.          *)
(* ------------------------------------------------------------------ *)

(* Anvil [handle_get_request] (state_machine.rs:197). *)
let handle_get_request (req : Api_method.get_request) (s : state) :
    Api_method.get_response =
  Option.fold (lookup req.key s.resources)
    ~none:({ res = Error Api_method.Object_not_found } : Api_method.get_response)
    ~some:(fun obj -> { res = Ok obj })

(* Anvil [handle_list_request] (state_machine.rs:208): every stored object whose
   namespace AND kind match (no name filter). Anvil's [.values().to_seq()] order
   is unspecified; here it is the deterministic {!Object_ref_map} key order
   ([bindings]). *)
let handle_list_request (req : Api_method.list_request) (s : state) :
    Api_method.list_response =
  let objs =
    Object_ref_map.bindings s.resources
    |> List.filter (fun ((k : Common.object_ref), _obj) ->
           String.equal k.namespace req.namespace
           && Common.equal_kind k.kind req.kind)
    |> List.map (fun (_k, obj) -> obj)
  in
  ({ res = Ok objs } : Api_method.list_response)

(* ------------------------------------------------------------------ *)
(* CREATE (state_machine.rs:219-323).                                  *)
(* ------------------------------------------------------------------ *)

(* Anvil [create_request_admission_check] (state_machine.rs:219): first hit wins
   over Invalid / BadRequest / BadRequest / ObjectAlreadyExists. *)
let create_request_admission_check (it : installed_types)
    (req : Api_method.create_request) (s : state) : Api_method.api_error option =
  let m : Object_meta.t = Dynamic_object.metadata req.obj in
  or_else
    (guard
       (Option.is_none m.name && Option.is_none m.generate_name)
       Api_method.Invalid)
    (fun () ->
      or_else
        (Option.fold m.namespace ~none:None ~some:(fun ns ->
             guard (not (String.equal req.namespace ns)) Api_method.Bad_request))
        (fun () ->
          or_else
            (guard (not (unmarshallable_object it req.obj)) Api_method.Bad_request)
            (fun () ->
              Option.fold m.name ~none:None ~some:(fun name ->
                  let key =
                    {
                      Common.kind = Dynamic_object.kind req.obj;
                      name;
                      namespace = req.namespace;
                    }
                  in
                  guard
                    (Object_ref_map.mem key s.resources)
                    Api_method.Object_already_exists))))

(* Anvil [handle_create_request] (state_machine.rs:272). Stamp the new object
   with namespace / current rv / current uid / no deletion timestamp / default
   status (a generated name when only [generate_name] is given), then the
   defensive already-exists re-check and [created_object_validity_check]; on
   success insert and advance BOTH counters (uid only advances here). rv/uid are
   the pre-increment snapshots. *)
let handle_create_request (it : installed_types)
    (req : Api_method.create_request) (s : state) :
    state * Api_method.create_response =
  decide
    (create_request_admission_check it req s)
    ~reject:(fun e -> (s, ({ res = Error e } : Api_method.create_response)))
    ~pass:(fun () ->
      let rm : Object_meta.t = Dynamic_object.metadata req.obj in
      let name_str =
        Option.value rm.name
          ~default:(generated_name s (Option.value rm.generate_name ~default:""))
      in
      let metadata =
        {
          rm with
          name = Some name_str;
          namespace = Some req.namespace;
          resource_version =
            Some (Common.Resource_version.of_int s.resource_version_counter);
          uid = Some (Common.Uid.of_int s.uid_counter);
          deletion_timestamp = None;
        }
      in
      let created_obj =
        Dynamic_object.make
          ~kind:(Dynamic_object.kind req.obj)
          ~metadata
          ~spec:(Dynamic_object.spec req.obj)
          ~status:(it.marshalled_default_status (Dynamic_object.kind req.obj))
      in
      let created_ref =
        {
          Common.kind = Dynamic_object.kind req.obj;
          name = name_str;
          namespace = req.namespace;
        }
      in
      if Object_ref_map.mem created_ref s.resources then
        (s, ({ res = Error Api_method.Object_already_exists } : Api_method.create_response))
      else
        decide
          (created_object_validity_check it created_obj)
          ~reject:(fun e -> (s, ({ res = Error e } : Api_method.create_response)))
          ~pass:(fun () ->
            let resources = Object_ref_map.add created_ref created_obj s.resources in
            ( {
                resources;
                uid_counter = s.uid_counter + 1;
                resource_version_counter = s.resource_version_counter + 1;
              },
              ({ res = Ok created_obj } : Api_method.create_response) )))

(* ------------------------------------------------------------------ *)
(* DELETE (state_machine.rs:325-413).                                  *)
(* ------------------------------------------------------------------ *)

(* Anvil [delete_request_admission_check] (state_machine.rs:325): ObjectNotFound
   if absent; else, with preconditions, uid mismatch then rv mismatch Conflict;
   else None. The option comparisons mirror Anvil's [Option<int> !=]. *)
let delete_request_admission_check (req : Api_method.delete_request) (s : state) :
    Api_method.api_error option =
  Option.fold (lookup req.key s.resources)
    ~none:(Some Api_method.Object_not_found)
    ~some:(fun obj ->
      let sm : Object_meta.t = Dynamic_object.metadata obj in
      Option.fold req.preconditions ~none:None ~some:(fun (pc : Api_method.preconditions) ->
          or_else
            (guard
               (Option.is_some pc.uid
               && not (Option.equal Common.Uid.equal pc.uid sm.uid))
               Api_method.Conflict)
            (fun () ->
              guard
                (Option.is_some pc.resource_version
                && not
                     (Option.equal Common.Resource_version.equal
                        pc.resource_version sm.resource_version))
                Api_method.Conflict)))

(* Anvil [handle_delete_request] (state_machine.rs:360). With finalizers present:
   already-stamped is a no-op [Ok ()]; otherwise stamp deletion timestamp + new
   rv and re-insert under [req.key] (rv+1). With no finalizers: remove [req.key]
   (rv+1). uid_counter is never touched; [Ok] is always [()]. *)
let handle_delete_request (req : Api_method.delete_request) (s : state) :
    state * Api_method.delete_response =
  decide
    (delete_request_admission_check req s)
    ~reject:(fun e -> (s, ({ res = Error e } : Api_method.delete_response)))
    ~pass:(fun () ->
      Option.fold (lookup req.key s.resources)
        ~none:(s, ({ res = Ok () } : Api_method.delete_response))
        ~some:(fun obj ->
          let om : Object_meta.t = Dynamic_object.metadata obj in
          let has_finalizers =
            Option.fold om.finalizers ~none:false ~some:(fun f -> List.length f > 0)
          in
          if has_finalizers then
            if Option.is_some om.deletion_timestamp then
              (s, ({ res = Ok () } : Api_method.delete_response))
            else
              let stamped =
                obj
                |> Dynamic_object.with_deletion_timestamp deletion_timestamp
                |> Dynamic_object.with_resource_version
                     (Common.Resource_version.of_int s.resource_version_counter)
              in
              let resources = Object_ref_map.add req.key stamped s.resources in
              ( {
                  s with
                  resources;
                  resource_version_counter = s.resource_version_counter + 1;
                },
                ({ res = Ok () } : Api_method.delete_response) )
          else
            let resources = Object_ref_map.remove req.key s.resources in
            ( {
                s with
                resources;
                resource_version_counter = s.resource_version_counter + 1;
              },
              ({ res = Ok () } : Api_method.delete_response) )))

(* ------------------------------------------------------------------ *)
(* UPDATE / UPDATE_STATUS (state_machine.rs:415-614).                  *)
(* ------------------------------------------------------------------ *)

(* Anvil [update_request_admission_check_helper] (state_machine.rs:425): shared
   by update and update-status. First hit wins: BadRequest (name missing / name
   mismatch / namespace mismatch / unmarshallable) / ObjectNotFound / Invalid
   (no rv where one is required) / Conflict (rv mismatch, then uid mismatch). *)
let update_request_admission_check_helper (it : installed_types) ~(name : string)
    ~(namespace : string) (obj : Dynamic_object.t) (s : state) :
    Api_method.api_error option =
  let m : Object_meta.t = Dynamic_object.metadata obj in
  let key = { Common.kind = Dynamic_object.kind obj; name; namespace } in
  let stored = lookup key s.resources in
  or_else (guard (Option.is_none m.name) Api_method.Bad_request) (fun () ->
      or_else
        (Option.fold m.name ~none:None ~some:(fun n ->
             guard (not (String.equal name n)) Api_method.Bad_request))
        (fun () ->
          or_else
            (Option.fold m.namespace ~none:None ~some:(fun ns ->
                 guard (not (String.equal namespace ns)) Api_method.Bad_request))
            (fun () ->
              or_else
                (guard (not (unmarshallable_object it obj)) Api_method.Bad_request)
                (fun () ->
                  or_else
                    (guard (Option.is_none stored) Api_method.Object_not_found)
                    (fun () ->
                      or_else
                        (guard
                           (Option.is_none m.resource_version
                           && not (allow_unconditional_update key.kind))
                           Api_method.Invalid)
                        (fun () ->
                          or_else
                            (Option.fold stored ~none:None ~some:(fun st ->
                                 let sm : Object_meta.t =
                                   Dynamic_object.metadata st
                                 in
                                 guard
                                   (Option.is_some m.resource_version
                                   && not
                                        (Option.equal
                                           Common.Resource_version.equal
                                           m.resource_version sm.resource_version))
                                   Api_method.Conflict))
                            (fun () ->
                              Option.fold stored ~none:None ~some:(fun st ->
                                  let sm : Object_meta.t =
                                    Dynamic_object.metadata st
                                  in
                                  guard
                                    (Option.is_some m.uid
                                    && not
                                         (Option.equal Common.Uid.equal m.uid
                                            sm.uid))
                                    Api_method.Conflict))))))))

(* Anvil [update_request_admission_check] (state_machine.rs:468). *)
let update_request_admission_check (it : installed_types)
    (req : Api_method.update_request) (s : state) : Api_method.api_error option =
  update_request_admission_check_helper it ~name:req.name ~namespace:req.namespace
    req.obj s

(* Anvil [update_status_request_admission_check] (state_machine.rs:570): same
   helper as update. *)
let update_status_request_admission_check (it : installed_types)
    (req : Api_method.update_status_request) (s : state) :
    Api_method.api_error option =
  update_request_admission_check_helper it ~name:req.name ~namespace:req.namespace
    req.obj s

(* Anvil [updated_object] (state_machine.rs:472): merge the request onto the
   stored object, keeping the stored kind/namespace-slot/rv/uid/deletion
   timestamp/status; namespace is re-stamped, spec and the remaining metadata
   come from the request. *)
let updated_object (req : Api_method.update_request) (old_obj : Dynamic_object.t) :
    Dynamic_object.t =
  let rm : Object_meta.t = Dynamic_object.metadata req.obj in
  let om : Object_meta.t = Dynamic_object.metadata old_obj in
  let metadata =
    {
      rm with
      namespace = Some req.namespace;
      resource_version = om.resource_version;
      uid = om.uid;
      deletion_timestamp = om.deletion_timestamp;
    }
  in
  Dynamic_object.make
    ~kind:(Dynamic_object.kind old_obj)
    ~metadata
    ~spec:(Dynamic_object.spec req.obj)
    ~status:(Dynamic_object.status old_obj)

(* Anvil [handle_update_request] (state_machine.rs:502). No-op (structural
   equality with the stored object) returns [Ok old] without an rv bump;
   otherwise stamp the current rv, run [updated_object_validity_check], and
   either re-insert (regular update) or — when the merge yields a deletion
   timestamp with no finalizers — remove the object (delete-during-update, still
   [Ok] the would-be object). rv+1 on any non-noop write; uid untouched. *)
let handle_update_request (it : installed_types) (req : Api_method.update_request)
    (s : state) : state * Api_method.update_response =
  decide
    (update_request_admission_check it req s)
    ~reject:(fun e -> (s, ({ res = Error e } : Api_method.update_response)))
    ~pass:(fun () ->
      let key = Api_method.update_request_key req in
      Option.fold (lookup key s.resources)
        ~none:(s, ({ res = Error Api_method.Object_not_found } : Api_method.update_response))
        ~some:(fun old ->
          let updated = updated_object req old in
          if Dynamic_object.equal updated old then
            (s, ({ res = Ok old } : Api_method.update_response))
          else
            let updated_rv =
              Dynamic_object.with_resource_version
                (Common.Resource_version.of_int s.resource_version_counter)
                updated
            in
            decide
              (updated_object_validity_check it ~updated:updated_rv ~old)
              ~reject:(fun e ->
                (s, ({ res = Error e } : Api_method.update_response)))
              ~pass:(fun () ->
                let um : Object_meta.t = Dynamic_object.metadata updated_rv in
                let has_finalizers =
                  Option.fold um.finalizers ~none:false ~some:(fun f ->
                      List.length f > 0)
                in
                let is_regular =
                  Option.is_none um.deletion_timestamp || has_finalizers
                in
                if is_regular then
                  let resources =
                    Object_ref_map.add key updated_rv s.resources
                  in
                  ( {
                      s with
                      resources;
                      resource_version_counter = s.resource_version_counter + 1;
                    },
                    ({ res = Ok updated_rv } : Api_method.update_response) )
                else
                  (* Delete-during-update: remove by the stamped object's own
                     ref (Anvil [updated_obj_with_new_rv.object_ref()]); its
                     name/namespace are present on this path, so the [~default]s
                     are dead. *)
                  let del_ref =
                    {
                      Common.kind = Dynamic_object.kind updated_rv;
                      name = Option.value um.name ~default:"";
                      namespace = Option.value um.namespace ~default:"";
                    }
                  in
                  let resources = Object_ref_map.remove del_ref s.resources in
                  ( {
                      s with
                      resources;
                      resource_version_counter = s.resource_version_counter + 1;
                    },
                    ({ res = Ok updated_rv } : Api_method.update_response) ))))

(* Anvil [status_updated_object] (state_machine.rs:574): the stored object with
   only [status] taken from the request. *)
let status_updated_object (req : Api_method.update_status_request)
    (old_obj : Dynamic_object.t) : Dynamic_object.t =
  Dynamic_object.make
    ~kind:(Dynamic_object.kind old_obj)
    ~metadata:(Dynamic_object.metadata old_obj)
    ~spec:(Dynamic_object.spec old_obj)
    ~status:(Dynamic_object.status req.obj)

(* Anvil [handle_update_status_request] (state_machine.rs:584): like update but
   changes only [status] and has NO delete-during-update branch (only inserts). *)
let handle_update_status_request (it : installed_types)
    (req : Api_method.update_status_request) (s : state) :
    state * Api_method.update_status_response =
  decide
    (update_status_request_admission_check it req s)
    ~reject:(fun e -> (s, ({ res = Error e } : Api_method.update_status_response)))
    ~pass:(fun () ->
      let key = Api_method.update_status_request_key req in
      Option.fold (lookup key s.resources)
        ~none:
          (s, ({ res = Error Api_method.Object_not_found }
              : Api_method.update_status_response))
        ~some:(fun old ->
          let updated = status_updated_object req old in
          if Dynamic_object.equal updated old then
            (s, ({ res = Ok old } : Api_method.update_status_response))
          else
            let updated_rv =
              Dynamic_object.with_resource_version
                (Common.Resource_version.of_int s.resource_version_counter)
                updated
            in
            decide
              (updated_object_validity_check it ~updated:updated_rv ~old)
              ~reject:(fun e ->
                (s, ({ res = Error e } : Api_method.update_status_response)))
              ~pass:(fun () ->
                let resources = Object_ref_map.add key updated_rv s.resources in
                ( {
                    s with
                    resources;
                    resource_version_counter = s.resource_version_counter + 1;
                  },
                  ({ res = Ok updated_rv } : Api_method.update_status_response) ))))

(* ------------------------------------------------------------------ *)
(* GET_THEN_* composites (state_machine.rs:673-802).                   *)
(* Skeleton: well_formed gate (BadRequest) -> internal GET (forward its          *)
(* error) -> ownership gate (TransactionAbort) -> delegate + forward.            *)
(* The internal GET's [Ok] payload IS [resources[req.key()]], so it is used      *)
(* directly as the current object (no re-lookup).                                *)
(* ------------------------------------------------------------------ *)

(* Anvil [handle_get_then_delete_request_msg] (state_machine.rs:673). *)
let handle_get_then_delete_request_msg (msg : Message.t)
    (req : Api_method.get_then_delete_request) (s : state) : state * Message.t =
  let form (r : Api_method.get_then_delete_response) : Message.t =
    Message.form_get_then_delete_resp_msg msg r
  in
  if not (Api_method.get_then_delete_well_formed req) then
    (s, form { res = Error Api_method.Bad_request })
  else
    let get_resp = handle_get_request { key = req.key } s in
    Result.fold get_resp.res
      ~error:(fun err -> (s, form { res = Error err }))
      ~ok:(fun current_obj ->
        if
          Object_meta.owner_references_contains
            (Dynamic_object.metadata current_obj)
            req.owner_ref
        then
          let s', del_resp =
            handle_delete_request { key = req.key; preconditions = None } s
          in
          (s', form { res = del_resp.res })
        else (s, form { res = Error Api_method.Transaction_abort }))

(* Anvil [handle_get_then_update_request_msg] (state_machine.rs:714). *)
let handle_get_then_update_request_msg (it : installed_types) (msg : Message.t)
    (req : Api_method.get_then_update_request) (s : state) : state * Message.t =
  let form (r : Api_method.get_then_update_response) : Message.t =
    Message.form_get_then_update_resp_msg msg r
  in
  if not (Api_method.get_then_update_well_formed req) then
    (s, form { res = Error Api_method.Bad_request })
  else
    let get_resp =
      handle_get_request { key = Api_method.get_then_update_request_key req } s
    in
    Result.fold get_resp.res
      ~error:(fun err -> (s, form { res = Error err }))
      ~ok:(fun current_obj ->
        if
          Object_meta.owner_references_contains
            (Dynamic_object.metadata current_obj)
            req.owner_ref
        then
          let rm : Object_meta.t = Dynamic_object.metadata req.obj in
          let cm : Object_meta.t = Dynamic_object.metadata current_obj in
          let metadata =
            { rm with resource_version = cm.resource_version; uid = cm.uid }
          in
          let new_obj =
            Dynamic_object.make
              ~kind:(Dynamic_object.kind req.obj)
              ~metadata
              ~spec:(Dynamic_object.spec req.obj)
              ~status:(Dynamic_object.status req.obj)
          in
          let update_req =
            ({ namespace = req.namespace; name = req.name; obj = new_obj }
              : Api_method.update_request)
          in
          let s', upd_resp = handle_update_request it update_req s in
          (s', form { res = upd_resp.res })
        else (s, form { res = Error Api_method.Transaction_abort }))

(* Anvil [handle_get_then_update_status_request_msg] (state_machine.rs:760). *)
let handle_get_then_update_status_request_msg (it : installed_types)
    (msg : Message.t) (req : Api_method.get_then_update_status_request) (s : state)
    : state * Message.t =
  let form (r : Api_method.get_then_update_status_response) : Message.t =
    Message.form_get_then_update_status_resp_msg msg r
  in
  if not (Api_method.get_then_update_status_well_formed req) then
    (s, form { res = Error Api_method.Bad_request })
  else
    let get_resp =
      handle_get_request
        { key = Api_method.get_then_update_status_request_key req }
        s
    in
    Result.fold get_resp.res
      ~error:(fun err -> (s, form { res = Error err }))
      ~ok:(fun current_obj ->
        if
          Object_meta.owner_references_contains
            (Dynamic_object.metadata current_obj)
            req.owner_ref
        then
          let new_obj =
            Dynamic_object.make
              ~kind:(Dynamic_object.kind current_obj)
              ~metadata:(Dynamic_object.metadata current_obj)
              ~spec:(Dynamic_object.spec current_obj)
              ~status:(Dynamic_object.status req.obj)
          in
          let usr =
            ({ namespace = req.namespace; name = req.name; obj = new_obj }
              : Api_method.update_status_request)
          in
          let s', ur = handle_update_status_request it usr s in
          (s', form { res = ur.res })
        else (s, form { res = Error Api_method.Transaction_abort }))

(* ------------------------------------------------------------------ *)
(* Dispatch + action (state_machine.rs:804-851).                       *)
(* ------------------------------------------------------------------ *)

(* Anvil [transition_by_etcd] (state_machine.rs:804): the 9-way dispatch on the
   received request, each wrapped by the paired [form_*_resp_msg]. The four
   [message_content] variants are matched exhaustively; a non-request content
   (excluded by {!handle_request}'s precondition) returns [msg] unchanged as the
   total completion of Anvil's [recommends]. *)
let transition_by_etcd (it : installed_types) (msg : Message.t) (s : state) :
    state * Message.t =
  match msg.Message.content with
  | Message.Api_request req -> (
      match req with
      | Api_method.Get_request r ->
          (s, Message.form_get_resp_msg msg (handle_get_request r s))
      | Api_method.List_request r ->
          (s, Message.form_list_resp_msg msg (handle_list_request r s))
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
      | Api_method.Get_then_delete_request r ->
          handle_get_then_delete_request_msg msg r s
      | Api_method.Get_then_update_request r ->
          handle_get_then_update_request_msg it msg r s
      | Api_method.Get_then_update_status_request r ->
          handle_get_then_update_status_request_msg it msg r s)
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
      (s, msg)

(* Anvil [handle_request] (state_machine.rs:821): the single api-server action. *)
let handle_request (it : installed_types) :
    (state, action_input, action_output) Action.t =
  let precondition (input : action_input) (_s : state) : bool =
    Option.fold input.recv ~none:false ~some:(fun (m : Message.t) ->
        match m.Message.content with
        | Message.Api_request _ -> true
        | Message.Api_response _ | Message.External_request _
        | Message.External_response _ ->
            false)
  in
  let transition (input : action_input) (s : state) : state * action_output =
    Option.fold input.recv
      ~none:(s, { send = Message.Pool.empty })
      ~some:(fun (m : Message.t) ->
        let s', resp_msg = transition_by_etcd it m s in
        (s', { send = Message.Pool.singleton resp_msg }))
  in
  { Action.precondition; transition }

(* Anvil [api_server] (state_machine.rs:836): the api-server state machine. *)
let state_machine (it : installed_types) :
    (state, action_input, action_input, action_output, step) State_machine.t =
  {
    State_machine.init;
    step_to_action = (fun Handle_request -> handle_request it);
    action_input = (fun Handle_request input -> input);
  }

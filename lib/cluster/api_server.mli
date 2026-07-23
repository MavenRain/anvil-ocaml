(** Anvil source: kubernetes_cluster/spec/api_server/{types.rs, state_machine.rs}.

    The API server / etcd datastore host. {!state} is the persistent key-value
    store ([StoredState]) plus the two monotone allocators; {!handle_request} is
    the single action, dispatching a received request message over the nine
    {!Api_method.api_request} variants and emitting exactly one response message.

    Every transition is total and exception-free: Anvil's total [->0] projections
    (an object's [object_ref] whose [name]/[namespace] the code path guarantees
    present) are recovered by reading the stamped strings directly, and each
    ordered [Option<APIError>] admission/validity fall-through is a first-[Some]
    combinator, never a two-arm [match]. The one modelling divergence is
    {!installed_types}: Anvil's [InstalledTypes] is an extensional [spec_fn] map
    compared by function equality (which does not port); here it is a concrete
    record of dispatch functions the handlers call, folding Anvil's per-built-in
    [match obj.kind] and its per-CR map lookup into one kind-indexed function set
    (see {!installed_types}). *)

type stored_state = Dynamic_object.t Object_ref_map.t
(** Anvil [StoredState = Map<ObjectRef, DynamicObjectView>] (resource.rs): the
    etcd store, keyed by {!Common.object_ref}. Deterministic key enumeration via
    {!Object_ref_map} models Anvil's [Map] domain iteration. *)

type state = {
  resources : stored_state;
  uid_counter : int;
  resource_version_counter : int;
}
(** Anvil [APIServerState] (api_server/types.rs:10): the whole persistent state.
    [uid_counter] is the next uid to stamp (advances on create only);
    [resource_version_counter] the next resourceVersion (advances on every
    write). Both are [int] carriers (Anvil [Uid]/[ResourceVersion] = [int]);
    read-then-bumped, never other arithmetic. Init pins only [resources] empty
    (see {!init}); the counters are unconstrained at init, only monotone in use. *)

type installed_types = {
  unmarshallable_spec : Common.kind -> Value.t -> bool;
  unmarshallable_status : Common.kind -> Value.t -> bool;
  valid_object : Dynamic_object.t -> bool;
  valid_transition : Dynamic_object.t -> Dynamic_object.t -> bool;
  marshalled_default_status : Common.kind -> Value.t;
}
(** Anvil [InstalledType] (api_server/types.rs:18) collapsed with the api-server's
    per-built-in [match obj.kind] dispatch. Anvil stores one [InstalledType]
    (five [spec_fn]s) per custom-resource kind-name in a [Map] and hardcodes the
    built-in kinds inline in [unmarshallable_spec]/[valid_object]/…; because
    OCaml cannot compare [spec_fn]s (Anvil's [type_is_installed_in_cluster]
    equality) and P1 does not carry a marshaller for every built-in kind, the
    whole kind dispatch is modelled as this one record of functions the handlers
    call. Fields, in Anvil order: [unmarshallable_spec kind spec] /
    [unmarshallable_status kind status] decide whether the marshalled value
    unmarshals; [valid_object obj] is [state_validation]; [valid_transition
    new_obj old_obj] is [transition_validation] (Anvil argument order is
    [(new, old)]); [marshalled_default_status kind] is the default status
    stamped onto a freshly created object. *)

type action_input = { recv : Message.t option }
(** Anvil [APIServerActionInput] (api_server/types.rs:30): the optionally-received
    request message. [None] means no message consumed. *)

type action_output = { send : Message.Pool.t }
(** Anvil [APIServerActionOutput] (api_server/types.rs:34): the multiset of
    emitted messages — always a singleton (one response) here. *)

type step = Handle_request
(** Anvil [APIServerStep] (api_server/types.rs:26): the single step, "process one
    incoming request". *)

val init : state -> bool
(** Anvil [api_server().init] (state_machine.rs:838): [true] iff [resources] is
    the empty map. Deliberately does NOT constrain the counters (Anvil leaves
    [uid_counter]/[resource_version_counter] unconstrained at init). *)

val lookup : Common.object_ref -> stored_state -> Dynamic_object.t option
(** Anvil [s.resources[key]] under a [contains_key] guard: the total etcd lookup,
    [None] when the key is absent. The base of {!Cluster.lookup_resource}. *)

val handle_get_request : Api_method.get_request -> state -> Api_method.get_response
(** Anvil [handle_get_request] (state_machine.rs:197): pure read;
    [Ok obj] when present, else [Err ObjectNotFound]. State unchanged. *)

val handle_list_request :
  Api_method.list_request -> state -> Api_method.list_response
(** Anvil [handle_list_request] (state_machine.rs:208): [Ok] of every stored
    object whose namespace AND kind match [req] (no name filter). Anvil's
    [.values().to_seq()] is an UNSPECIFIED order; modelled as the deterministic
    {!Object_ref_map} key order. State unchanged. *)

val handle_create_request :
  installed_types ->
  Api_method.create_request ->
  state ->
  state * Api_method.create_response
(** Anvil [handle_create_request] (state_machine.rs:272). Runs the ordered
    [create_request_admission_check] (Invalid / BadRequest / BadRequest /
    ObjectAlreadyExists), then stamps the new object with [namespace],
    [resource_version = resource_version_counter], [uid = uid_counter],
    [deletion_timestamp = None] and the default status, generating a name when
    only [generate_name] is given; a defensive already-exists re-check and
    [created_object_validity_check] follow; on success [resources] gains the
    object and BOTH counters advance by one. The only handler that bumps
    [uid_counter]; rv/uid are the pre-increment counter snapshots. *)

val handle_delete_request :
  Api_method.delete_request -> state -> state * Api_method.delete_response
(** Anvil [handle_delete_request] (state_machine.rs:360). Admission is
    ObjectNotFound then uid/rv precondition Conflicts. With finalizers present
    and no deletion timestamp yet, stamps [deletion_timestamp] + a new rv and
    re-inserts under [req.key] (object stays, rv+1); already-stamped is a no-op
    [Ok ()]; with no finalizers, removes [req.key] (rv+1). [Ok] is always [()]. *)

val handle_update_request :
  installed_types ->
  Api_method.update_request ->
  state ->
  state * Api_method.update_response
(** Anvil [handle_update_request] (state_machine.rs:502). Admission (BadRequest
    ×4 / ObjectNotFound / Invalid / Conflict ×2), then merge onto the stored
    object keeping its kind/namespace/rv/uid/deletion_timestamp/status; a
    structurally-unchanged merge is a no-op [Ok old] (no rv bump); otherwise
    stamp the current rv, run [updated_object_validity_check], and either
    re-insert (regular update) or — when the merge sets a deletion timestamp with
    no finalizers — remove the object (delete-during-update, still [Ok] the
    would-be object). rv+1 on any non-noop write; [uid_counter] untouched. *)

val handle_update_status_request :
  installed_types ->
  Api_method.update_status_request ->
  state ->
  state * Api_method.update_status_response
(** Anvil [handle_update_status_request] (state_machine.rs:584). Same admission
    as update; takes ONLY [status] from the request (kind/metadata/spec kept from
    the stored object); no-op detection and rv stamping as update, but with no
    delete-during-update branch — it only ever re-inserts. *)

val handle_get_then_delete_request_msg :
  Message.t ->
  Api_method.get_then_delete_request ->
  state ->
  state * Message.t
(** Anvil [handle_get_then_delete_request_msg] (state_machine.rs:673); the
    request is pre-extracted from [msg] by {!transition_by_etcd}. [!well_formed]
    → BadRequest; internal GET (forwarding ObjectNotFound); on the stored object,
    an [owner_references_contains req.owner_ref] gate (TransactionAbort on fail)
    then [handle_delete_request] with no preconditions, forwarding its result. *)

val handle_get_then_update_request_msg :
  installed_types ->
  Message.t ->
  Api_method.get_then_update_request ->
  state ->
  state * Message.t
(** Anvil [handle_get_then_update_request_msg] (state_machine.rs:714). As
    {!handle_get_then_delete_request_msg} but, when owned, rebuilds the object
    from [req.obj] with [resource_version]/[uid] taken from the stored object (so
    the delegated [handle_update_request] never Conflicts) and forwards its
    result. *)

val handle_get_then_update_status_request_msg :
  installed_types ->
  Message.t ->
  Api_method.get_then_update_status_request ->
  state ->
  state * Message.t
(** Anvil [handle_get_then_update_status_request_msg] (state_machine.rs:760). As
    the update composite, but the rebuilt object is the stored object with only
    [status] replaced by [req.obj]'s, delegated to
    {!handle_update_status_request}. *)

val transition_by_etcd :
  installed_types -> Message.t -> state -> state * Message.t
(** Anvil [transition_by_etcd] (state_machine.rs:804): the 9-way dispatch on the
    received message's {!Api_method.api_request}, calling the matching handler and
    wrapping the response with the paired [form_*_resp_msg]. A message whose
    content is not a request (ruled out by {!handle_request}'s precondition) is
    returned unchanged — the total completion of Anvil's [recommends]. *)

val handle_request :
  installed_types -> (state, action_input, action_output) Action.t
(** Anvil [handle_request] (state_machine.rs:821): THE api-server action.
    Precondition: [recv] is [Some] and its content is an {!Api_method.api_request}.
    Transition: run {!transition_by_etcd} and emit the single response message as
    a {!Message.Pool} singleton. *)

val state_machine :
  installed_types ->
  (state, action_input, action_input, action_output, step) State_machine.t
(** Anvil [api_server] (state_machine.rs:836): the api-server {!State_machine.t} —
    {!init}, [step_to_action] mapping the sole {!step} to {!handle_request}, and
    the identity [action_input]. *)

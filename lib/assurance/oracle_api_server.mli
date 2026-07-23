(** The api-server correspondence oracle: an INDEPENDENT re-port of Anvil's SPEC
    api-server request handler (src/kubernetes_cluster/spec/api_server/
    state_machine.rs, the pure [handle_*] handlers l.198-820 and [transition_by_etcd]
    l.804), used as a golden reference to differentially validate
    {!Api_server}.[transition_by_etcd] — the single most intricate ported module
    (the ~745-line request handler).

    HONEST LIMIT (architecture §4 finding 8; digest oracle verdict). This is an
    independent re-derivation of the SAME Anvil spec: Anvil's runnable
    [executable_model/] is a machine-proven refinement of that spec, and no
    independent runnable model of the api server exists. So a mismatch localizes a
    bug in OUR port ([lib/cluster/api_server.ml]), NOT in Anvil's design; this is a
    one-sided GOLDEN reference, not a two-eyes differential peer. And no independent
    runnable model of the FULL cluster step ([enabled_successors]: garbage
    collector, network, scheduler, crash) exists at all, so ONLY the api-server
    handler is oracled here. The value is catching transcription / porting errors in
    a large hand-ported handler, which it does. *)

type state = {
  resources : Api_server.stored_state;  (** the etcd object store. *)
  uid : int;  (** the monotone uid counter (Anvil [uid_counter]). *)
  rv : int;  (** the monotone resource-version counter (Anvil [resource_version_counter]). *)
}
(** The api-server sub-state the oracle threads, mirroring {!Api_server.state}. *)

val of_api_server : Api_server.state -> state
(** Project {!Api_server.state} onto the oracle's {!state}. *)

val handle :
  Api_server.installed_types -> Message.t -> state -> state * Message.t
(** Anvil [transition_by_etcd] (state_machine.rs:804), re-derived independently:
    apply one api-request {!Message.t} to the etcd store, returning the next
    store/counters and the response message. Dispatches the api-request verb
    (get / list / create / delete / update / update_status and the get_then_delete /
    get_then_update / get_then_update_status composites) EXHAUSTIVELY, stamping
    uid/resource_version from the counters exactly as Anvil does (create/update
    write the current counter then increment), and emitting the same
    {!Api_method.api_error} conflicts (already-exists, not-found, uid/rv
    precondition mismatch). Pure; total; no exception. *)

val agrees :
  Api_server.installed_types -> Message.t -> Api_server.state -> bool
(** The differential property: {!Api_server}.[transition_by_etcd] and {!handle}
    agree on the SAME request and state — the resulting etcd stores are equal (as
    maps of {!Dynamic_object.t}, compared structurally, e.g. by marshalled JSON),
    the post-transition [uid]/[rv] counters are equal (oracle [uid]/[rv] against
    the port's [uid_counter]/[resource_version_counter], so a divergent
    counter-increment on any verb is caught, not just the store contents), and
    the response messages are equal ({!Message.equal}). [true] when the OCaml port
    matches the golden oracle. Driven by [test/t_p4_oracle.ml] over random requests
    and states. *)

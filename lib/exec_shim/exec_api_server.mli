(** P7 exec-shim: the in-memory executable api-server backend, and the
    correspondence oracle.

    Architecture 3.6: "[exec_api_server] ports Anvil's [executable_model] as plain
    Map/Set and doubles as the correspondence oracle." Concretely this is a
    {!K8s_client.K8S_CLIENT} whose store is a mutable {!Api_server.state} (etcd map
    + uid/rv counters) driven by the {b trusted} P2 {!Api_server.transition_by_etcd}
    (the 9-verb dispatch with faithful uid/rv stamping). The transport effect is
    the identity monad ([type 'a io = 'a]), so a {!Concurrency.Direct}-based
    {!Controller_runtime} runs synchronously and deterministically against it.

    {b The correspondence oracle (Leg 1, at the executable-client boundary).}
    {!request_checked} runs, alongside the real transition, the P4
    {!Oracle_api_server} - an INDEPENDENT re-port of Anvil's spec
    [transition_by_etcd] - on the same request and state, and reports
    {!Oracle_api_server.agrees}. Driving a whole reconcile through
    {!Controller_runtime} with [request_checked] therefore cross-checks the port
    against the golden re-port along a REAL executable trajectory, not just the P4
    random/enumerated traces.

    {b Honest limit.} The oracle is ONE-SIDED and OCaml-vs-OCaml: it catches OUR
    porting bugs in {!Api_server}, and transfers NO Anvil guarantee (identical to
    P4's stated caveat). It is a golden reference, not two-eyes differential
    against Verus.

    {b Scope boundary} (from the P7 review): {!Oracle_api_server.agrees} feeds the
    SAME {!Api_server.installed_types} closures to both sides, so it cross-checks
    the 9-verb DISPATCH and the handler logic, but NOT the per-kind installed
    predicates ([valid_object] / [valid_transition] / [unmarshallable_*] /
    [marshalled_default_status]): a bug living inside one of those closures is
    invisible here, because both the port and the re-port call the identical
    function. Correspondence covers the api-server, not the installed policy. *)

type t
(** A live in-memory api-server: a mutable {!Api_server.state} (etcd store + uid
    and resource-version counters), the {!Api_server.installed_types} it validates
    against, a monotone {!Message.Rpc_id_allocator.t} for synthesising request
    messages, and the {!Message.host_id} it answers as (a [Controller]). *)

type 'a io = 'a
(** The identity transport, so {!t} satisfies
    [K8s_client.K8S_CLIENT with type 'a io = 'a] and slots directly into
    [Controller_runtime.Make (Concurrency.Direct) (Exec_api_server)]. *)

val create :
  installed:Api_server.installed_types ->
  ?seed:Dynamic_object.t list ->
  unit ->
  t Res.t
(** A fresh server with an empty etcd store and zeroed counters (Anvil
    [APIServerState] init). Each [seed] object is inserted via a real CREATE
    request, so its uid/resourceVersion are stamped exactly as a live create would
    (never hand-forged); a seed CREATE that the api-server rejects (e.g. malformed,
    already-exists) is surfaced as an {!Err.t}, keeping seeding total. *)

val state : t -> Api_server.state
(** The current api-server sub-state (store + counters). *)

val lookup : t -> Common.object_ref -> Dynamic_object.t option
(** Total etcd read ({!Api_server.lookup}); [None] when the key is absent. *)

val request :
  t -> Api_method.api_request -> (Api_method.api_response, Err.t) result io
(** The {!K8s_client.K8S_CLIENT} entry point. Wraps [req] in a request
    {!Message.t} (from this server's controller host id, a freshly allocated rpc
    id), applies {!Api_server.transition_by_etcd} in place (MUTATING the store and
    counters), and returns the unwrapped {!Api_method.api_response}. An [Err.t]
    arises only if the api-server returns non-response content (a porting
    invariant violation); an api-level {!Api_method.api_error} rides inside the
    [Ok] response's [res] field. *)

type check = {
  response : Api_method.api_response;  (** the api-server's response *)
  agreed : bool;
      (** whether the golden {!Oracle_api_server} agreed with {!Api_server} on this
          request and pre-state ({!Oracle_api_server.agrees}). *)
}

val request_checked : t -> Api_method.api_request -> (check, Err.t) result
(** As {!request}, but ALSO evaluates {!Oracle_api_server.agrees} on the same
    message and PRE-transition state, returning the response together with the
    agreement bit. This is the correspondence oracle; a test drives a full
    reconcile with it and asserts [agreed] on every request. *)

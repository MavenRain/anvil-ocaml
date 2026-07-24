(** P7 exec-shim: the Kubernetes client abstraction.

    Anvil source: the [KubernetesAPI] / unified request path behind the reconcile
    manager (executable spine). Integrating architecture finding 12: the client
    takes the {b unified} {!Api_method.api_request} sum and dispatches every verb
    in {e one} exhaustive place, rather than six per-verb typed signatures. That
    unification is what lets the three [GetThen*] conflict-retry composites have a
    home (the earlier per-method split left them with no target method), and it
    pins the variant count against {!Api_method}.

    The client is parameterised by an abstract effect ['a io] so a backend can be
    synchronous ({!Concurrency.Direct}, ['a io = 'a]) or asynchronous (Lwt). The
    only backend this phase ships is {!Exec_api_server} (in-memory, synchronous).

    Integrating architecture finding on [watch]/[Await_change]: a watch stream is a
    NATIVE-backend-only capability (chunked list-watch, [resourceVersion]
    bookmarks, 410-Gone re-list). It is therefore {b not} in the base
    {!K8S_CLIENT}; only {!WATCH_CLIENT} exposes it. The in-memory backend is
    level-triggered by an explicit work queue instead (see {!Controller_runtime}),
    and the native watch backend is deferred to Leg 3 ({!K8s_client_native}). *)

module type K8S_CLIENT = sig
  type t
  (** A handle to a live api-server (connection, or in-memory store). *)

  type 'a io
  (** The effect the backend runs in ([Concurrency.Direct.t] for the in-memory
      backend; [Lwt.t] for a native one). *)

  val request :
    t ->
    Api_method.api_request ->
    (Api_method.api_response, Err.t) result io
  (** The single unified entry point. Dispatches the {!Api_method.api_request} sum
      internally (all nine verbs, including the [Get_then_update]/[Get_then_delete]
      /[Get_then_update_status] composites, whose conflict-retry is fuel-bounded
      recursion returning {!Res.t} in the backend, honouring the loop-keyword ban).
      The outer [io] is the transport effect; the inner [result] is the api-level
      outcome (an {!Api_method.api_error} surfaces inside the [Ok] response's [res]
      field, an [Err.t] is a transport/porting failure). *)
end

(** A client that additionally exposes a level-triggered watch. NATIVE BACKENDS
    ONLY: the watch stream requires the cohttp list-watch / [resourceVersion] /
    re-list machinery of architecture 3.6, deferred to Leg 3. The in-memory
    {!Exec_api_server} deliberately does NOT satisfy this signature. *)
module type WATCH_CLIENT = sig
  include K8S_CLIENT

  val watch :
    t ->
    Common.kind ->
    namespace:string ->
    (Dynamic_object.t Seq.t, Err.t) result io
  (** Anvil [Await_change]: a level-triggered stream of the current objects of a
      kind. Only the watch-capable native backend implements it. *)
end

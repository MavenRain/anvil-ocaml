(** P7 exec-shim: the native (real-cluster) client backend - DEFERRED, Leg 3,
    research-grade.

    Architecture 3.6 + Leg 3: there is no mature OCaml kube client. A real backend
    must hand-build the list-watch/informer protocol (chunked watch stream,
    [resourceVersion] bookmarks, 410-Gone re-list), in-cluster auth (SA
    bearer-token refresh, client-cert, exec credential plugins), TLS to the
    api-server CA, and RESTMapper/discovery (Kind -> GroupVersionResource). Each is
    a multi-week effort with no library to lean on, and none can be exercised
    without a live cluster - which the deterministic assurance core deliberately
    does not require.

    This module is therefore an HONEST STUB: it fixes the {!K8s_client.WATCH_CLIENT}
    shape a native backend WILL satisfy, so the type story of the shim is complete,
    but ships no fabricated network code. Every operation returns a documented
    {!Err.t} rather than pretending to connect. The deterministic spine
    ({!Exec_api_server} + {!Controller_runtime}) is independently valuable and does
    not depend on this ever being filled in (architecture 5: "P7 may slip without
    blocking assurance"). *)

type config = {
  server : string;  (** api-server base URL (e.g. https://10.0.0.1:6443). *)
  namespace : string;  (** default namespace for namespaced requests. *)
}
(** The connection parameters a real backend would consume. Present to fix the
    intended surface; unused by the stub. *)

type t
(** A native client handle. Unconstructible to a working state in this phase. *)

type 'a io = 'a
(** Placeholder transport. A real backend would set [type 'a io = 'a Lwt.t]. *)

val create : config -> t Res.t
(** Would establish auth + TLS + discovery. The stub returns an {!Err.t}
    documenting that the native backend is deferred to Leg 3. *)

val request :
  t -> Api_method.api_request -> (Api_method.api_response, Err.t) result io
(** {!K8s_client.K8S_CLIENT} entry. Stub: returns the deferred {!Err.t}. *)

val watch :
  t ->
  Common.kind ->
  namespace:string ->
  (Dynamic_object.t Seq.t, Err.t) result io
(** {!K8s_client.WATCH_CLIENT} extension ([Await_change]). Stub: returns the
    deferred {!Err.t}. The list-watch stream is the single largest piece of the
    deferred work. *)

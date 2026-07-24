(* P7 exec-shim: the native (real-cluster) client backend - DEFERRED, Leg 3.
   See k8s_client_native.mli. An HONEST STUB: it fixes the WATCH_CLIENT shape a
   real backend will satisfy, but ships no fabricated network code. Every
   operation returns the same documented deferred [Err.t]. *)

type config = { server : string; namespace : string }
type t = config
type 'a io = 'a

(* The single deferred-backend error every entry point returns. *)
let deferred : Err.t =
  Err.Malformed_value
    {
      kind = "native_backend";
      detail =
        "native list-watch/auth/TLS backend deferred to Leg 3 (research-grade); \
         use Exec_api_server for the deterministic core";
    }

let create (_ : config) : t Res.t = Error deferred

let request (_ : t) (_ : Api_method.api_request) :
    (Api_method.api_response, Err.t) result io =
  Error deferred

let watch (_ : t) (_ : Common.kind) ~namespace:(_ : string) :
    (Dynamic_object.t Seq.t, Err.t) result io =
  Error deferred

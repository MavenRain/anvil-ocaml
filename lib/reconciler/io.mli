(** Anvil source: reconciler/spec/io.rs ([RequestView], [ResponseView],
    [VoidEReqView], [VoidERespView]).

    A reconciler's I/O is either with the Kubernetes API server (the [K_*]
    arm, carrying the unified {!Api_method.api_request} / {!Api_method
    .api_response}) or with a controller-specific external system (the
    [External_*] arm, carrying the reconciler's own [ereq]/[eresp] type). *)

(** The uninhabited external-payload type for a reconciler that talks to no
    external system (Anvil's empty [VoidEReqView]/[VoidERespView] structs).
    Instantiating [ereq]/[eresp] with {!void} makes the [External_*] arm
    unconstructible, so such a reconciler's I/O is [K_*]-only by construction,
    yet the sum stays uniform and every match remains exhaustive. *)
type void = |

(** Anvil [RequestView<T>]: a request to the API server or to the external
    system. *)
type 'ereq request_view =
  | K_request of Api_method.api_request
  | External_request of 'ereq

(** Anvil [ResponseView<T>]: a response from the API server or the external
    system. *)
type 'eresp response_view =
  | K_response of Api_method.api_response
  | External_response of 'eresp

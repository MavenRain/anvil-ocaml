(** Anvil source: kubernetes_cluster/spec/message.rs.

    The message/transport layer of the cluster transition system: the wire {!t}
    message, host addressing ({!host_id}), the request/response payload sum
    ({!message_content}), the RPC-id allocator, {!message_ops} (the per-step
    recv/send interface), and the family of pure constructor and predicate spec
    fns. No stateful transition acts here; everything is a total function
    reproducing an Anvil spec fn (Verus [_ => false] / partial [->0] projections
    become exhaustive matches / combinators, never exceptions). *)

module Rpc_id : sig
  (** Anvil [RPCId = nat] (message.rs:8): the id correlating an RPC response to
      its request, doubling as an allocation timestamp. An abstract [int]
      newtype — a counter, never an arithmetic operand beyond the allocator's
      [+1]. *)
  type t

  val zero : t
  (** The id a fresh {!Rpc_id_allocator} hands out first (counter [0]). *)

  val of_int : int -> t
  (** Carry an [int] into an id (allocator internals / tests). *)

  val to_int : t -> int
  (** Project the underlying counter (e.g. for the [<] timestamp order Anvil's
      [api_request_msg_before] relies on). *)

  val equal : t -> t -> bool
  (** Id equality (Anvil [==] on [RPCId]); the request/response correlation the
      API server preserves by echoing the same [rpc_id]. *)

  val compare : t -> t -> int
  (** Total order; [compare a b < 0] iff [a] was allocated strictly earlier —
      Anvil [message.rs:50] uses a smaller [rpc_id] as an earlier timestamp. *)
end

type host_id =
  | Api_server
  | Builtin_controller
  | Controller of int * Common.object_ref
  | External of int
  | Pod_monkey
      (** Anvil [HostId] (message.rs:26): the five state-machine actors / network
          endpoints. [Controller] carries [(controller_id, cr_key)]; [External]
          carries the controller id it is paired with. *)

val equal_host_id : host_id -> host_id -> bool
(** Structural equality on {!host_id} (Anvil derived [==]). *)

val is_controller_id : host_id -> int -> bool
(** Anvil [HostId::is_controller_id] (message.rs:242): true iff [self] is a
    [Controller] whose id equals the argument. Exhaustive five-arm match — the
    four non-[Controller] arms are [false] (Anvil's [_ => false] spelled out, no
    wildcard). *)

type message_content =
  | Api_request of Api_method.api_request
  | Api_response of Api_method.api_response
  | External_request of Value.t
  | External_response of Value.t
      (** Anvil [MessageContent] (message.rs:60): the four-variant payload sum.
          [ExternalRequest]/[ExternalResponse] are both the opaque {!Value.t}
          (nominally distinct, same carrier). *)

val equal_message_content : message_content -> message_content -> bool
(** Structural equality on {!message_content} (Anvil derived [==]); recurses
    through {!Api_method} / {!Value} equality. *)

type t = {
  src : host_id;
  dst : host_id;
  rpc_id : Rpc_id.t;
  content : message_content;
}
(** Anvil [Message] (message.rs:19): one wire message, all four fields public. *)

val equal : t -> t -> bool
(** Structural equality over all four fields (Anvil derived [==]); the
    multiplicity key of {!Pool}. *)

module Pool : sig
  include module type of Multiset.Make (struct
    type nonrec t = t

    let equal = equal
  end)
end
(** Anvil [Multiset<Message>]: the network in-flight bag ([NetworkState.in_flight])
    and the [MessageOps.send] batch. The {!Multiset.Make} instance keyed by
    {!equal}; duplicates coexist with multiplicity, order carries no meaning. *)

module Rpc_id_allocator : sig
  (** Anvil [RPCIdAllocator] (message.rs:36): a monotone counter handing out
      unique {!Rpc_id.t}s. *)
  type t

  val init : unit -> t
  (** [RPCIdAllocator { rpc_id_counter = 0 }]: the fresh allocator. *)

  val allocate : t -> t * Rpc_id.t
  (** Anvil [RPCIdAllocator::allocate] (message.rs:52): returns
      [(advanced_allocator, allocated_id)] where [allocated_id] is the CURRENT
      counter and [advanced_allocator] has [counter + 1]. Thread the returned
      allocator forward for uniqueness; do NOT pre-increment. *)

  val equal : t -> t -> bool
  (** Counter equality on Anvil [RPCIdAllocator]'s [rpc_id_counter] (message.rs:36):
      the allocator IS its monotone counter, so [Int.equal] on the counter is a
      faithful state equality. Additive, consumed by the P5 cluster-state equality
      (BUILD-SPEC-P5 §1); no behaviour change. *)

  val rpc_id_count : t -> int
  (** The number of rpc ids allocated so far (the monotone [rpc_id_counter]).
      Read-only accessor for the P14 id-level correspondence family, whose N1/N2
      members compare an in-flight or pending {!Rpc_id.t} against this counter
      (Anvil [kubernetes_cluster/proof/network.rs:35-41] and [:76-83],
      BUILD-SPEC-P14 §4.1); no behaviour change. *)
end

type message_ops = { recv : t option; send : Pool.t }
(** Anvil [MessageOps] (message.rs:14): the per-network-step interface — one
    optionally-received message and a multiset of messages to send. [recv] being
    [None] is load-bearing (see {!received_msg_destined_for}); [send] is a
    multiset, not a set. *)

val form_msg :
  src:host_id ->
  dst:host_id ->
  rpc_id:Rpc_id.t ->
  content:message_content ->
  t
(** Anvil [form_msg] (message.rs:142): the base constructor every other builder
    funnels through. *)

val controller_req_msg :
  int -> Common.object_ref -> Rpc_id.t -> Api_method.api_request -> t
(** Anvil [controller_req_msg] (message.rs:82): from [Controller(id, cr_key)] to
    [Api_server], wrapping the request in [Api_request]. Args:
    [controller_id cr_key req_id req]. *)

val controller_external_req_msg :
  int -> Common.object_ref -> Rpc_id.t -> Value.t -> t
(** Anvil [controller_external_req_msg] (message.rs:86): from [Controller(id,
    cr_key)] to [External(id)] (ids match), wrapping in [External_request]. Args:
    [controller_id cr_key req_id req]. *)

val built_in_controller_req_msg : Rpc_id.t -> message_content -> t
(** Anvil [built_in_controller_req_msg] (message.rs:90): from [Builtin_controller]
    to [Api_server]; the content is passed through verbatim (the GC's delete). *)

val pod_monkey_req_msg : Rpc_id.t -> message_content -> t
(** Anvil [pod_monkey_req_msg] (message.rs:94): from [Pod_monkey] to
    [Api_server]; content passed through verbatim. *)

val form_get_resp_msg : t -> Api_method.get_response -> t
(** Anvil [form_get_resp_msg] (message.rs:471): swap [src]/[dst], keep [rpc_id],
    wrap the response in [Api_response (Get_response _)]. *)

val form_list_resp_msg : t -> Api_method.list_response -> t
(** Anvil [form_list_resp_msg] (message.rs:473): as {!form_get_resp_msg} for
    [List_response]. *)

val form_create_resp_msg : t -> Api_method.create_response -> t
(** Anvil [form_create_resp_msg] (message.rs:475): as {!form_get_resp_msg} for
    [Create_response]. *)

val form_delete_resp_msg : t -> Api_method.delete_response -> t
(** Anvil [form_delete_resp_msg] (message.rs:477): as {!form_get_resp_msg} for
    [Delete_response]. *)

val form_update_resp_msg : t -> Api_method.update_response -> t
(** Anvil [form_update_resp_msg] (message.rs:479): as {!form_get_resp_msg} for
    [Update_response]. *)

val form_update_status_resp_msg : t -> Api_method.update_status_response -> t
(** Anvil [form_update_status_resp_msg] (message.rs:481): as {!form_get_resp_msg}
    for [Update_status_response]. *)

val form_get_then_delete_resp_msg : t -> Api_method.get_then_delete_response -> t
(** Anvil [form_get_then_delete_resp_msg] (message.rs:483): as
    {!form_get_resp_msg} for [Get_then_delete_response]. *)

val form_get_then_update_resp_msg : t -> Api_method.get_then_update_response -> t
(** Anvil [form_get_then_update_resp_msg] (message.rs:485): as
    {!form_get_resp_msg} for [Get_then_update_response]. *)

val form_get_then_update_status_resp_msg :
  t -> Api_method.get_then_update_status_response -> t
(** Anvil [form_get_then_update_status_resp_msg] (message.rs:487): as
    {!form_get_resp_msg} for [Get_then_update_status_response]. *)

val get_req_msg_content : Common.object_ref -> message_content
(** Anvil [get_req_msg_content] (message.rs:157): [Api_request (Get_request
    {key})]. *)

val list_req_msg_content : Common.kind -> string -> message_content
(** Anvil [list_req_msg_content] (message.rs:163): [Api_request (List_request
    {kind; namespace})]. Args: [kind namespace]. *)

val create_req_msg_content : string -> Dynamic_object.t -> message_content
(** Anvil [create_req_msg_content] (message.rs:170): [Api_request (Create_request
    {namespace; obj})]. Args: [namespace obj]. *)

val delete_req_msg_content :
  Common.object_ref -> Api_method.preconditions option -> message_content
(** Anvil [delete_req_msg_content] (message.rs:177): [Api_request (Delete_request
    {key; preconditions})]; [preconditions] is an [option]. *)

val update_req_msg_content :
  string -> string -> Dynamic_object.t -> message_content
(** Anvil [update_req_msg_content] (message.rs:184): [Api_request (Update_request
    {namespace; name; obj})]. Args: [namespace name obj]. *)

val update_status_req_msg_content :
  string -> string -> Dynamic_object.t -> message_content
(** Anvil [update_status_req_msg_content] (message.rs:192): [Api_request
    (Update_status_request {namespace; name; obj})]. Args: [namespace name obj]. *)

val get_then_delete_req_msg_content :
  Common.object_ref -> Owner_reference.t -> message_content
(** Anvil [get_then_delete_req_msg_content] (message.rs:200): [Api_request
    (Get_then_delete_request {key; owner_ref})]. Args: [key owner_ref]. *)

val get_then_update_req_msg_content :
  string -> string -> Owner_reference.t -> Dynamic_object.t -> message_content
(** Anvil [get_then_update_req_msg_content] (message.rs:208): [Api_request
    (Get_then_update_request {namespace; name; owner_ref; obj})]. Args:
    [namespace name owner_ref obj]. *)

val get_then_update_status_req_msg_content :
  string -> string -> Owner_reference.t -> Dynamic_object.t -> message_content
(** Anvil [get_then_update_status_req_msg_content] (message.rs:217): [Api_request
    (Get_then_update_status_request {namespace; name; owner_ref; obj})]. Args:
    [namespace name owner_ref obj]. *)

val received_msg_destined_for : t option -> host_id -> bool
(** Anvil [received_msg_destined_for] (message.rs:233): [true] when [recv] is
    [None] (vacuous — no message consumed), else the received message's [dst]
    equals [host_id]. The [None]-true case is load-bearing in the host
    preconditions; do NOT treat [None] as a rejection. *)

val resp_msg_matches_req_msg : t -> t -> bool
(** Anvil [resp_msg_matches_req_msg] (message.rs:98): the response corresponds to
    the request iff either (API) both are API messages with the [src]/[dst]
    crossover, equal [rpc_id], and paired request/response kinds, or (external)
    both are external messages with the crossover and equal [rpc_id]. *)

val form_matched_err_resp_msg : t -> Api_method.api_error -> t
(** Anvil [form_matched_err_resp_msg] (message.rs:126): for an API request,
    build the paired [*_response] carrying [Error err] (via the matching
    [form_*_resp_msg]). Anvil [recommends] the content is an [Api_request]; the
    three non-request contents (unreachable in a well-formed cluster) return the
    input unchanged — the total, exception-free completion of the [recommends]. *)

val form_external_resp_msg : t -> Value.t -> t
(** Anvil [form_external_resp_msg] (message.rs:151): swap [src]/[dst], keep
    [rpc_id], wrap [resp] in [External_response]. *)

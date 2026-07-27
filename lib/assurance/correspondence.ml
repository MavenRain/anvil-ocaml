(* Faithful OCaml port of Anvil's five ID-LEVEL correspondence StatePreds from
   src/kubernetes_cluster/proof/network.rs (N1 :35-41, N2 :76-83, N3 :254-268,
   N4 :312-320, N5 :382-394), as pure {!Cluster.cluster_state} predicates reusing
   {!Invariants.invariant}. Transcribed against the upstream checkout available
   to P14, not reconstructed from memory.

   These five are the family that constrains message IDENTITY — the gap
   BUILD-SPEC-P14 §1 names. CORRECTED (review): the gap is NOT that the shipped
   suite never inspects [s.network.in_flight] — inv9 (invariants.ml:656-675) does
   and is in {!Invariants.always} — but that nothing relates a message's [rpc_id]
   to [s.rpc_id_allocator] or to another message's [rpc_id]. That is why P13's
   crash mutants refuted nothing despite the suite reading messages. [restart_controller]
   (cluster.ml:291-324) clears [ongoing_reconciles] but touches neither
   [s.network] nor [s.rpc_id_allocator], so the crash edge is precisely the one
   that can break the message/reconcile id correspondence.

   Kept as a SEPARATE list, deliberately: appending to {!Invariants.always},
   {!Invariants.cluster_structural} or {!Vsts_invariants.always} would move
   P13's committed pinned counts and silently rewrite a shipped result
   (BUILD-SPEC-P14 §4.2).

   Convention firewall (anvil-ocaml): no loop keywords (List/Option combinators
   only), no [_ ->] catch-all on any finite sum — the [host_id] and
   [message_content] classifiers below spell every arm out, following the
   reference idiom at invariants.ml:276-303 — no two-arm match on option
   (Option.fold / Option.is_some), no exceptions. Every predicate is a total
   [bool]. *)

(* -- message classification (Anvil MessageContent / HostId discriminants) ----
   Exhaustive on both finite sums; the Verus [msg.content is APIRequest] and
   [msg.src is Controller] / [msg.src->Controller_0] projections. *)

let content_is_api_request (m : Message.t) : bool =
  match m.content with
  | Message.Api_request _ -> true
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    false

(* Anvil [msg.src is Controller] paired with its partial projection
   [msg.src->Controller_0], rendered total as an option: [Some cid] iff the
   sender is a controller host, so the [is Controller] premise and the id it
   carries come from ONE exhaustive match rather than two. *)
let src_controller_id (m : Message.t) : int option =
  match m.src with
  | Message.Controller (cid, _cr_key) -> Some cid
  | Message.Api_server | Message.Builtin_controller | Message.External _
  | Message.Pod_monkey ->
    None

(* -- shared projections ------------------------------------------------------
   [Message.Pool.distinct] is one representative per DISTINCT in-flight message,
   which is exactly the extent of Anvil's [s.in_flight().contains(msg)]
   (multiplicity >= 1), so quantifying over it is faithful for every member.
   Multiplicity itself is only ever read by N5, via [Message.Pool.count]. *)

let msgs (s : Cluster.cluster_state) : Message.t list =
  Message.Pool.distinct (Cluster.in_flight s)

(* Anvil [s.rpc_id_allocator.rpc_id_counter]: the monotone global counter, read
   through the purely additive accessor added by BUILD-SPEC-P14 §4.1. *)
let allocator_count (s : Cluster.cluster_state) : int =
  Message.Rpc_id_allocator.rpc_id_count s.rpc_id_allocator

let ongoing (s : Cluster.cluster_state) (controller_id : int) :
    Controller.ongoing_reconcile Object_ref_map.t =
  Cluster.ongoing_reconciles s controller_id

(* The shared N2 / N3 non-vacuity witness (BUILD-SPEC-P14 §4.2): some key of the
   controller's ongoing-reconcile map is actually AWAITING a response. Both
   members are vacuously true while every [pending_req_msg] is [None]. *)
let some_pending_req (controller_id : int) (s : Cluster.cluster_state) : bool =
  Object_ref_map.exists
    (fun _key (orc : Controller.ongoing_reconcile) ->
      Option.is_some orc.pending_req_msg)
    (ongoing s controller_id)

(* -- N1 every_in_flight_msg_has_lower_id_than_allocator (network.rs:35) ------
   [forall msg. s.in_flight().contains(msg) ==> msg.rpc_id < counter]. *)
let in_flight_lower_than_allocator : Invariants.invariant =
  {
    name = "every_in_flight_msg_has_lower_id_than_allocator";
    source = "kubernetes_cluster/proof/network.rs:35";
    holds =
      (fun s ->
        let counter = allocator_count s in
        List.for_all
          (fun (m : Message.t) -> Message.Rpc_id.to_int m.rpc_id < counter)
          (msgs s));
    interesting = (fun s -> Message.Pool.cardinal (Cluster.in_flight s) >= 1);
  }

(* -- N2 every_pending_req_msg_has_lower_id_than_allocator (network.rs:76) ----
   [forall key. ongoing.contains_key(key) && ongoing[key].pending_req_msg is Some
    ==> ongoing[key].pending_req_msg->0.rpc_id < counter]. The [contains_key]
   premise is [Object_ref_map.for_all] (it only visits bound keys) and the
   [is Some] premise is the [~none:true] leg of [Option.fold]. *)
let pending_req_lower_than_allocator ~(controller_id : int) :
    Invariants.invariant =
  {
    name = "every_pending_req_msg_has_lower_id_than_allocator";
    source = "kubernetes_cluster/proof/network.rs:76";
    holds =
      (fun s ->
        let counter = allocator_count s in
        Object_ref_map.for_all
          (fun _key (orc : Controller.ongoing_reconcile) ->
            Option.fold orc.pending_req_msg ~none:true
              ~some:(fun (pending_req : Message.t) ->
                Message.Rpc_id.to_int pending_req.rpc_id < counter))
          (ongoing s controller_id));
    interesting = some_pending_req controller_id;
  }

(* -- N3 every_in_flight_req_msg_has_different_id_from_pending_req_msg_of_
   every_ongoing_reconcile (network.rs:254) ------------------------------------
   For every ongoing reconcile with a pending request, no OTHER in-flight api
   REQUEST carries that request's rpc id. The two implications are rendered as
   [not premise || conclusion]; [Message.equal] is Anvil's derived [==] over all
   four fields, i.e. the [msg != pending_req] guard. *)
let in_flight_req_id_differs_from_pending ~(controller_id : int) :
    Invariants.invariant =
  {
    name =
      "every_in_flight_req_msg_has_different_id_from_pending_req_msg_of_every_ongoing_reconcile";
    source = "kubernetes_cluster/proof/network.rs:254";
    holds =
      (fun s ->
        let in_flight = msgs s in
        Object_ref_map.for_all
          (fun _key (orc : Controller.ongoing_reconcile) ->
            Option.fold orc.pending_req_msg ~none:true
              ~some:(fun (pending_req : Message.t) ->
                List.for_all
                  (fun (m : Message.t) ->
                    (not (content_is_api_request m))
                    || Message.equal m pending_req
                    || not (Message.Rpc_id.equal m.rpc_id pending_req.rpc_id))
                  in_flight))
          (ongoing s controller_id));
    (* CORRECTED (review): N3 originally borrowed N2's [some_pending_req], which
       is NOT a witness that N3 was non-trivially evaluated - with a pending
       request present but no api REQUEST in flight (e.g. the request has been
       consumed and only its response is in flight) the inner [List.for_all] is
       vacuously true. N3 is genuinely exercised only when BOTH a pending request
       exists AND some in-flight message is an api request that could collide
       with it. *)
    interesting =
      (fun s ->
        some_pending_req controller_id s
        && List.exists content_is_api_request (msgs s));
  }

(* -- N4 every_in_flight_req_msg_from_controller_has_valid_controller_id
   (network.rs:312) ------------------------------------------------------------
   Upstream reads [self.controller_models], a field of the CLUSTER (the static
   model registry), not of the cluster STATE — hence the {!Cluster.t} argument.
   [Imap] is the [Map<int, _>] Anvil indexes controller models by, so
   [Imap.mem] is [contains_key] verbatim. *)
let in_flight_req_from_controller_valid_id (c : Cluster.t) : Invariants.invariant
    =
  {
    name = "every_in_flight_req_msg_from_controller_has_valid_controller_id";
    source = "kubernetes_cluster/proof/network.rs:312";
    holds =
      (fun s ->
        List.for_all
          (fun (m : Message.t) ->
            (not (content_is_api_request m))
            || Option.fold (src_controller_id m) ~none:true ~some:(fun cid ->
                   Imap.mem cid c.controller_models))
          (msgs s));
    interesting =
      (fun s ->
        List.exists
          (fun (m : Message.t) ->
            content_is_api_request m && Option.is_some (src_controller_id m))
          (msgs s));
  }

(* -- N5 every_in_flight_msg_has_no_replicas_and_has_unique_id (network.rs:382)
   Two conjuncts: the message has NO REPLICA in the bag
   ([s.in_flight().count(msg) == 1] — the one place multiplicity is genuinely
   needed, [distinct] cannot state it), and no OTHER in-flight message shares its
   rpc id. Upstream's weaker [every_in_flight_msg_has_unique_id]
   (network.rs:514-522) is DERIVED from this one (:530) and is deliberately not a
   separate member: shipping both would double the per-state cost for zero
   discrimination. *)
let in_flight_unique_id : Invariants.invariant =
  {
    name = "every_in_flight_msg_has_no_replicas_and_has_unique_id";
    source = "kubernetes_cluster/proof/network.rs:382";
    holds =
      (fun s ->
        let pool = Cluster.in_flight s in
        let in_flight = Message.Pool.distinct pool in
        List.for_all
          (fun (m : Message.t) ->
            Message.Pool.count m pool = 1
            && List.for_all
                 (fun (other : Message.t) ->
                   Message.equal m other
                   || not (Message.Rpc_id.equal m.rpc_id other.rpc_id))
                 in_flight)
          in_flight);
    (* >= 2 OCCURRENCES, not >= 2 distinct: this fires both on two distinct
       messages (the uniqueness conjunct is then discriminating) and on one
       message present twice (the no-replicas conjunct is then discriminating),
       so it witnesses either conjunct doing work. *)
    interesting = (fun s -> Message.Pool.cardinal (Cluster.in_flight s) >= 2);
  }

let family (c : Cluster.t) ~(controller_id : int) : Invariants.invariant list =
  [
    in_flight_lower_than_allocator;
    pending_req_lower_than_allocator ~controller_id;
    in_flight_req_id_differs_from_pending ~controller_id;
    in_flight_req_from_controller_valid_id c;
    in_flight_unique_id;
  ]

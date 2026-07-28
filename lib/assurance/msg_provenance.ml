(* BUILD-SPEC-P19 §2: the message-provenance (sender-tag) family - the
   E6-register message sibling of Anvil's
   [vstatefulset_controller/proof/helper_invariants.rs:1213] plus the three
   unshipped sender-classification always-members of
   [kubernetes_cluster/proof/network.rs], exposed as a named family for the
   P19 dedicated fault leg:

   - M1 every_msg_from_vsts_controller_carries_vsts_key (:1213-1222, lemma
     :1224-1260)
   - M2 all_requests_from_pod_monkey_are_api_pod_requests (:570-587, lemma
     :589)
   - M3 all_requests_from_builtin_controllers_are_api_delete_requests
     (:618-628, lemma :630)
   - M4 no_pending_request_to_api_server_from_api_server_or_external
     (:540-549, lemma :551)

   All four members traverse [Message.Pool.distinct (Cluster.in_flight s)]
   (the [inv_self] projection precedent, vsts_invariants.ml:152): every
   classifier is per-message, so multiplicity adds nothing. Every rendering
   decision and deviation is disclosed in the .mli. *)

let msgs (s : Cluster.cluster_state) : Message.t list =
  Message.Pool.distinct (Cluster.in_flight s)

(* The [Api_request] payload projection (the [inv_self] helper shape,
   vsts_invariants.ml:156-162): [Some r] on a request, [None] on the three
   non-request contents - an exhaustive 4-arm match, no wildcard. *)
let api_request_of (m : Message.t) : Api_method.api_request option =
  match m.content with
  | Message.Api_request r -> Some r
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    None

(* M2's request classifier (upstream network.rs:576-584): the four permitted
   write arms are pod-keyed; the five remaining arms are upstream's
   [_ => false] at :583 spelled out. Key reads are PER-ARM - the port
   exports per-request key projections and no sum-level [key ()]; the
   Res.t-typed (partial) [create_request_key] is deliberately NOT consumed
   (.mli disclosure). *)
let monkey_request_ok (req : Api_method.api_request) : bool =
  let open Api_method in
  match req with
  | Create_request r -> Common.equal_kind (Dynamic_object.kind r.obj) Pod.kind
  | Update_request r -> Common.equal_kind (update_request_key r).kind Pod.kind
  | Update_status_request r ->
    Common.equal_kind (update_status_request_key r).kind Pod.kind
  | Delete_request r -> Common.equal_kind (delete_request_key r).kind Pod.kind
  | Get_request _ | List_request _ | Get_then_delete_request _
  | Get_then_update_request _ | Get_then_update_status_request _ ->
    false

(* M3's request classifier (upstream network.rs:625's
   [content.is_delete_request()], macro-generated over strictly
   [DeleteRequest] - the invocation spans spec/message.rs:321-326):
   [Delete_request] ALONE is a delete; [Get_then_delete_request] is NOT
   (.mli). *)
let builtin_request_ok (req : Api_method.api_request) : bool =
  let open Api_method in
  match req with
  | Delete_request _ -> true
  | Get_request _ | List_request _ | Create_request _ | Update_request _
  | Update_status_request _ | Get_then_delete_request _
  | Get_then_update_request _ | Get_then_update_status_request _ ->
    false

(* M4's source scope (upstream network.rs:544): src [Api_server] or
   [External _]; the other three actors are out of scope. *)
let m4_src_in_scope (m : Message.t) : bool =
  match m.src with
  | Message.Api_server | Message.External _ -> true
  | Message.Builtin_controller | Message.Controller _ | Message.Pod_monkey ->
    false

let provenance_sources : string list =
  [
    "vstatefulset_controller/proof/helper_invariants.rs:1213";
    "kubernetes_cluster/proof/network.rs:570";
    "kubernetes_cluster/proof/network.rs:618";
    "kubernetes_cluster/proof/network.rs:540";
  ]

let provenance_family ~(controller_id : int) : Invariants.invariant list =
  let m1 =
    {
      Invariants.name = "every_msg_from_vsts_controller_carries_vsts_key";
      source = "vstatefulset_controller/proof/helper_invariants.rs:1213";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              match m.src with
              | Message.Controller (cid, key) ->
                (not (Int.equal cid controller_id))
                || Common.equal_kind key.kind V_stateful_set.kind
              | Message.Api_server | Message.Builtin_controller
              | Message.External _ | Message.Pod_monkey ->
                true)
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) ->
              match m.src with
              | Message.Controller (cid, _) -> Int.equal cid controller_id
              | Message.Api_server | Message.Builtin_controller
              | Message.External _ | Message.Pod_monkey ->
                false)
            (msgs s));
    }
  in
  let m2 =
    {
      Invariants.name = "all_requests_from_pod_monkey_are_api_pod_requests";
      source = "kubernetes_cluster/proof/network.rs:570";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              match m.src with
              | Message.Pod_monkey ->
                Message.equal_host_id m.dst Message.Api_server
                && Option.fold (api_request_of m) ~none:false
                     ~some:monkey_request_ok
              | Message.Api_server | Message.Builtin_controller
              | Message.Controller _ | Message.External _ ->
                true)
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) ->
              match m.src with
              | Message.Pod_monkey -> true
              | Message.Api_server | Message.Builtin_controller
              | Message.Controller _ | Message.External _ ->
                false)
            (msgs s));
    }
  in
  let m3 =
    {
      Invariants.name =
        "all_requests_from_builtin_controllers_are_api_delete_requests";
      source = "kubernetes_cluster/proof/network.rs:618";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              match m.src with
              | Message.Builtin_controller ->
                Message.equal_host_id m.dst Message.Api_server
                && Option.fold (api_request_of m) ~none:false
                     ~some:builtin_request_ok
              | Message.Api_server | Message.Controller _
              | Message.External _ | Message.Pod_monkey ->
                true)
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) ->
              match m.src with
              | Message.Builtin_controller -> true
              | Message.Api_server | Message.Controller _
              | Message.External _ | Message.Pod_monkey ->
                false)
            (msgs s));
    }
  in
  let m4 =
    {
      Invariants.name =
        "no_pending_request_to_api_server_from_api_server_or_external";
      source = "kubernetes_cluster/proof/network.rs:540";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              not
                (m4_src_in_scope m
                && Message.equal_host_id m.dst Message.Api_server
                && Option.is_some (api_request_of m)))
            (msgs s));
      interesting =
        (fun s -> List.exists (fun (m : Message.t) -> m4_src_in_scope m) (msgs s));
    }
  in
  [ m1; m2; m3; m4 ]

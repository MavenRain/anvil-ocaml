(* Faithful OCaml port of Anvil's REQUEST/RESPONSE correspondence StatePreds
   (BUILD-SPEC-P16 section 2): Q1, Q2, Q3 and Q5 from
   src/kubernetes_cluster/proof/req_resp.rs (Q1 :14-22, Q2 :69-78, Q3 :136-149,
   Q5 :345-361), as pure {!Cluster.cluster_state} predicates reusing
   {!Invariants.invariant}. Transcribed against the durable upstream checkout
   at ~/Documents/anvil-ref, not reconstructed from memory.

   These are the first shipped members that read a response message's BODY and
   relate it to [s.api_server] (BUILD-SPEC-P16 section 1): P14's N-family reads
   only [rpc_id]s and P15's R-family reads only [pending_req_msg] identity.
   The family SPLITS INTO TWO LISTS by guard home, and that split is the
   phase's thesis under test, not cosmetics: {!rv_family} (Q1, Q2) is guarded
   on network + etcd and never reads a reconcile; {!matched_family} (Q3, Q5)
   couples the network to [ongoing_reconciles] via
   [Message.resp_msg_matches_req_msg]. The two lists are asserted on SEPARATE
   checker legs and never unioned (BUILD-SPEC-P16 section 4.4).

   Q4 (req_resp.rs:240-255) is DELIBERATELY EXCLUDED; see the .mli for the
   structural-vacuity argument about THIS PORT's shipped reconcilers.

   Convention firewall (anvil-ocaml): no loop keywords (List/Option/Result/Map
   combinators only), no [_ ->] catch-all on any finite sum (the
   [message_content] and [api_response] classifiers spell every arm out,
   following correspondence.ml:33-49), no two-arm match on option or result
   (Option.fold / Option.is_some / Result.fold), no exceptions. Every
   predicate is a total [bool]. [Option.fold ~none:] is EAGER; every [~none:]
   below is a constant, never a call. *)

(* -- shared projections ------------------------------------------------------
   [Message.Pool.distinct] is one representative per DISTINCT in-flight
   message, exactly the extent of Anvil's [s.in_flight().contains(msg)]
   (multiplicity >= 1) -- the P14 idiom (correspondence.ml:52-58). *)

let msgs (s : Cluster.cluster_state) : Message.t list =
  Message.Pool.distinct (Cluster.in_flight s)

let ongoing (s : Cluster.cluster_state) (controller_id : int) :
    Controller.ongoing_reconcile Object_ref_map.t =
  Cluster.ongoing_reconciles s controller_id

(* Anvil [metadata.resource_version] (an option on both sides of the port and
   of upstream). Qualified field access; no new cluster accessor is added
   (BUILD-SPEC-P16 section 4.1). *)
let object_rv (obj : Dynamic_object.t) : Common.Resource_version.t option =
  (Dynamic_object.metadata obj).Object_meta.resource_version

(* -- ok-response classifiers (message.rs:566-594, the
   declare_is_ok_resp_msg_functions macro) ------------------------------------
   Anvil [is_ok_get_response_msg()(msg)] is THREE conjuncts: [msg.src is
   APIServer], [msg.content.is_get_response()], [res is Ok]. Rendered as one
   total projection returning the Ok object, so the [is_ok] premise and the
   body it guards come from ONE exhaustive match rather than two. Exhaustive
   on both finite sums ([message_content], [api_response]); the [res] result
   is folded, never matched. *)

let ok_get_response_object (m : Message.t) : Dynamic_object.t option =
  if Message.equal_host_id m.src Message.Api_server then
    match m.content with
    | Message.Api_response (Api_method.Get_response { res }) ->
      Result.fold ~ok:Option.some
        ~error:(fun (_ : Api_method.api_error) -> None)
        res
    | Message.Api_response
        ( Api_method.List_response _ | Api_method.Create_response _
        | Api_method.Delete_response _ | Api_method.Update_response _
        | Api_method.Update_status_response _
        | Api_method.Get_then_delete_response _
        | Api_method.Get_then_update_response _
        | Api_method.Get_then_update_status_response _ ) ->
      None
    | Message.Api_request _ | Message.External_request _
    | Message.External_response _ ->
      None
  else None

let ok_create_response_object (m : Message.t) : Dynamic_object.t option =
  if Message.equal_host_id m.src Message.Api_server then
    match m.content with
    | Message.Api_response (Api_method.Create_response { res }) ->
      Result.fold ~ok:Option.some
        ~error:(fun (_ : Api_method.api_error) -> None)
        res
    | Message.Api_response
        ( Api_method.Get_response _ | Api_method.List_response _
        | Api_method.Delete_response _ | Api_method.Update_response _
        | Api_method.Update_status_response _
        | Api_method.Get_then_delete_response _
        | Api_method.Get_then_update_response _
        | Api_method.Get_then_update_status_response _ ) ->
      None
    | Message.Api_request _ | Message.External_request _
    | Message.External_response _ ->
      None
  else None

let is_ok_get_response (m : Message.t) : bool =
  Option.is_some (ok_get_response_object m)

let is_ok_create_response (m : Message.t) : bool =
  Option.is_some (ok_create_response_object m)

(* Anvil [res->Ok_0.object_ref() == key]. Upstream's [DynamicObjectView
   ::object_ref()] is TOTAL; the port's {!Dynamic_object.object_ref} is
   result-valued (it errors when [metadata.name] or [metadata.namespace] is
   unset). The result is FOLDED, never assumed total: an object whose ref
   cannot be formed matches NO key, so in premise position the member goes
   vacuous and in consequent position it refutes (fail loud). See the .mli. *)
let object_key_matches (key : Common.object_ref) (obj : Dynamic_object.t) :
    bool =
  Result.fold
    ~ok:(Common.equal_object_ref key)
    ~error:(fun (_ : Err.t) -> false)
    (Dynamic_object.object_ref obj)

(* Anvil [is_ok_get_response_msg_and_matches_key(key)(msg)] /
   [is_ok_create_response_msg_and_matches_key(key)(msg)]
   (message.rs:574-577). *)
let is_ok_get_response_and_matches_key (key : Common.object_ref)
    (m : Message.t) : bool =
  Option.fold (ok_get_response_object m) ~none:false
    ~some:(object_key_matches key)

let is_ok_create_response_and_matches_key (key : Common.object_ref)
    (m : Message.t) : bool =
  Option.fold (ok_create_response_object m) ~none:false
    ~some:(object_key_matches key)

(* Anvil [pending_req_msg->0.content.get_get_request().key] (req_resp.rs:147):
   upstream's projection is PARTIAL (arbitrary off a get request); here it is
   total as an option, [None] off a get request. Exhaustive on both sums. *)
let get_request_key_of (req : Message.t) : Common.object_ref option =
  match req.content with
  | Message.Api_request (Api_method.Get_request { key }) -> Some key
  | Message.Api_request
      ( Api_method.List_request _ | Api_method.Create_request _
      | Api_method.Delete_request _ | Api_method.Update_request _
      | Api_method.Update_status_request _
      | Api_method.Get_then_delete_request _
      | Api_method.Get_then_update_request _
      | Api_method.Get_then_update_status_request _ ) ->
    None
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    None

(* Anvil [pending_req.content.get_create_request()] (req_resp.rs:351), same
   partial-to-option rendering. *)
let create_request_of (req : Message.t) : Api_method.create_request option =
  match req.content with
  | Message.Api_request (Api_method.Create_request cr) -> Some cr
  | Message.Api_request
      ( Api_method.Get_request _ | Api_method.List_request _
      | Api_method.Delete_request _ | Api_method.Update_request _
      | Api_method.Update_status_request _
      | Api_method.Get_then_delete_request _
      | Api_method.Get_then_update_request _
      | Api_method.Get_then_update_status_request _ ) ->
    None
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    None

(* Anvil [s.resources()[key].metadata.resource_version->0 ==
   msg...res->Ok_0.metadata.resource_version->0] (req_resp.rs:75). Both [->0]
   projections are partial upstream (arbitrary on [None]); rendered as "both
   [Some] and equal", so a missing resource version FAILS the premise
   (vacuous) rather than comparing garbage. Disclosed in the .mli. *)
let same_resource_version (stored : Dynamic_object.t)
    (resp_obj : Dynamic_object.t) : bool =
  Option.fold (object_rv stored) ~none:false ~some:(fun stored_rv ->
      Option.fold (object_rv resp_obj) ~none:false
        ~some:(Common.Resource_version.equal stored_rv))

(* -- the Q2 bound key set ----------------------------------------------------
   The keys of [s.api_server.resources], capped per KIND by
   [max_objects_per_kind] -- exactly the checker's own candidate-key
   discipline (the gc_keys pattern, cluster.ml:719-732: per-kind filter before
   [take], so a cross-kind cap cannot silently starve later-sorting kinds).
   [Object_ref_map.bindings] is sorted, hence deterministic. *)

let take (n : int) (xs : 'a list) : 'a list =
  List.filteri (fun i _ -> i < n) xs

let bound_keys (b : Bound.t) (s : Cluster.cluster_state) :
    Common.object_ref list =
  let all_keys = List.map fst (Object_ref_map.bindings (Cluster.resources s)) in
  let kinds =
    List.fold_left
      (fun acc (k : Common.object_ref) ->
        if List.exists (Common.equal_kind k.kind) acc then acc
        else k.kind :: acc)
      [] all_keys
  in
  List.concat_map
    (fun kd ->
      take b.Bound.max_objects_per_kind
        (List.filter
           (fun (k : Common.object_ref) -> Common.equal_kind k.kind kd)
           all_keys))
    kinds

(* -- Q1 object_in_ok_get_response_has_smaller_rv_than_etcd (req_resp.rs:14) --
   [forall msg. in_flight(msg) && is_ok_get_response_msg()(msg) ==>
    rv is Some && rv->0 < s.api_server.resource_version_counter]. Nullary.
   The counter is the PUBLIC record field (api_server.mli:24-28); no accessor
   is added (BUILD-SPEC-P16 section 4.1). The [~none:false] leg is upstream's
   [resource_version is Some] conjunct failing, i.e. a refutation, not
   vacuity. Upstream marks its own PROOF flaky (req_resp.rs:24); the STATEMENT
   is what is ported (see the .mli). *)
let object_in_ok_get_response_has_smaller_rv_than_etcd : Invariants.invariant =
  {
    name = "object_in_ok_get_response_has_smaller_rv_than_etcd";
    source = "kubernetes_cluster/proof/req_resp.rs:14";
    holds =
      (fun s ->
        let counter = s.api_server.resource_version_counter in
        List.for_all
          (fun (m : Message.t) ->
            Option.fold (ok_get_response_object m) ~none:true
              ~some:(fun (obj : Dynamic_object.t) ->
                Option.fold (object_rv obj) ~none:false ~some:(fun rv ->
                    Common.Resource_version.to_int rv < counter)))
          (msgs s));
    (* BUILD-SPEC-P16 section 2: at least one in-flight OK get response
       exists. Under the vct:false seed no Get_request is ever issued, so
       this is PREDICTED zero there (P16-E) and must be measured as such. *)
    interesting = (fun s -> List.exists is_ok_get_response (msgs s));
  }

(* -- Q2 object_in_ok_get_resp_is_same_as_etcd_with_same_rv (req_resp.rs:69) --
   Upstream is per-[key]; shipped universally closed over the BOUND KEY SET
   {!bound_keys} (the disclosed strengthening, BUILD-SPEC-P16 section 2 /
   section 8.3). Upstream's [s.resources().contains_key(key)] premise is the
   [Object_ref_map.find_opt] fold ([~none:true]: key absent, premise fails,
   vacuously true); the rv-equality premise is {!same_resource_version}; the
   consequent [s.resources()[key] == res->Ok_0] is {!Dynamic_object.equal}. *)
let object_in_ok_get_resp_is_same_as_etcd_with_same_rv (b : Bound.t) :
    Invariants.invariant =
  {
    name = "object_in_ok_get_resp_is_same_as_etcd_with_same_rv";
    source = "kubernetes_cluster/proof/req_resp.rs:69";
    holds =
      (fun s ->
        let resources = Cluster.resources s in
        let in_flight = msgs s in
        List.for_all
          (fun (key : Common.object_ref) ->
            Option.fold (Object_ref_map.find_opt key resources) ~none:true
              ~some:(fun (stored : Dynamic_object.t) ->
                List.for_all
                  (fun (m : Message.t) ->
                    Option.fold (ok_get_response_object m) ~none:true
                      ~some:(fun (obj : Dynamic_object.t) ->
                        (not (object_key_matches key obj))
                        || (not (same_resource_version stored obj))
                        || Dynamic_object.equal stored obj))
                  in_flight))
          (bound_keys b s));
    (* BUILD-SPEC-P16 section 2: some in-flight OK get response matches a key
       present in [s.api_server.resources] with equal resource version --
       Q2's OWN full premise, at a key the closure actually VISITS (a key
       beyond the per-kind cap is never evaluated by [holds] and must not
       count as exercise; the P14 N3 borrowed-witness lesson). *)
    interesting =
      (fun s ->
        let resources = Cluster.resources s in
        let in_flight = msgs s in
        List.exists
          (fun (key : Common.object_ref) ->
            Option.fold (Object_ref_map.find_opt key resources) ~none:false
              ~some:(fun (stored : Dynamic_object.t) ->
                List.exists
                  (fun (m : Message.t) ->
                    Option.fold (ok_get_response_object m) ~none:false
                      ~some:(fun (obj : Dynamic_object.t) ->
                        object_key_matches key obj
                        && same_resource_version stored obj))
                  in_flight))
          (bound_keys b s));
  }

(* -- Q3 key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_
   pending_req (req_resp.rs:136) ----------------------------------------------
   Upstream is per-(controller_id, key) with [key.kind is CustomResourceKind]
   required; shipped universally closed over all bound keys of
   [ongoing_reconciles] (the P15 R-family treatment). The CR-kind premise is
   discharged by construction: scheduling filters candidate keys to the
   controller model's kind (cluster.ml:654-660), so only CR keys are ever
   bound. The [contains_key] and [is Some] premises are the [for_all] and the
   [~none:true] fold; [resp_msg_matches_req_msg] keeps upstream's (resp, req)
   argument order (message.mli:242). The consequent projects the pending GET
   request's key: [~none:false] on a non-get pending request is UNREACHABLE
   under the matching premise (paired_kind in resp_msg_matches_req_msg forces
   [Get_response] against [Get_request], message.ml:297-314) and fails loud
   rather than vacuating if that pairing invariant ever broke. *)
let key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_pending_req
    ~(controller_id : int) : Invariants.invariant =
  {
    name =
      "key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_pending_req";
    source = "kubernetes_cluster/proof/req_resp.rs:136";
    holds =
      (fun s ->
        let in_flight = msgs s in
        Object_ref_map.for_all
          (fun _key (orc : Controller.ongoing_reconcile) ->
            Option.fold orc.pending_req_msg ~none:true
              ~some:(fun (pending : Message.t) ->
                List.for_all
                  (fun (m : Message.t) ->
                    (not (is_ok_get_response m))
                    || (not (Message.resp_msg_matches_req_msg m pending))
                    || Option.fold (get_request_key_of pending) ~none:false
                         ~some:(fun k ->
                           is_ok_get_response_and_matches_key k m))
                  in_flight))
          (ongoing s controller_id));
    (* BUILD-SPEC-P16 section 4.6: Q3's OWN full antecedent fires somewhere --
       an ongoing reconcile holds a pending request AND some in-flight OK get
       response matches it. Not borrowed from any other member (the P14 N3
       lesson): Q5's witness differs in the response constructor and the
       name-is-Some conjunct, Q1's in reading no reconcile at all. *)
    interesting =
      (fun s ->
        let in_flight = msgs s in
        Object_ref_map.exists
          (fun _key (orc : Controller.ongoing_reconcile) ->
            Option.fold orc.pending_req_msg ~none:false
              ~some:(fun (pending : Message.t) ->
                List.exists
                  (fun (m : Message.t) ->
                    is_ok_get_response m
                    && Message.resp_msg_matches_req_msg m pending)
                  in_flight))
          (ongoing s controller_id));
  }

(* -- Q5 key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_
   pending_req (req_resp.rs:345) -- THE HEADLINE ------------------------------
   Same shape as Q3 with [is_ok_create_response_msg()], plus the one
   antecedent unique to this member: [create_req.obj.metadata.name is Some]
   (generate-name creates are excluded upstream, req_resp.rs:358). Upstream's
   trigger sits on [resp_msg_matches_req_msg], not on [in_flight().contains];
   triggers do not affect the STATEMENT being ported. The consequent's key is
   upstream's [create_req.key()] (message.rs:545-551 shows the same
   projection); the port's {!Api_method.create_request_key} is result-valued
   and errors exactly when [metadata.name] is [None] (api_method.ml:152-159),
   which the name-is-Some antecedent excludes, so the [~error] arm is
   unreachable under the premise and fails loud. *)
let key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req
    ~(controller_id : int) : Invariants.invariant =
  {
    name =
      "key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req";
    source = "kubernetes_cluster/proof/req_resp.rs:345";
    holds =
      (fun s ->
        let in_flight = msgs s in
        Object_ref_map.for_all
          (fun _key (orc : Controller.ongoing_reconcile) ->
            Option.fold orc.pending_req_msg ~none:true
              ~some:(fun (pending : Message.t) ->
                List.for_all
                  (fun (m : Message.t) ->
                    (not (is_ok_create_response m))
                    || (not (Message.resp_msg_matches_req_msg m pending))
                    || Option.fold (create_request_of pending) ~none:false
                         ~some:(fun (cr : Api_method.create_request) ->
                           (not
                              (Option.is_some
                                 (Object_meta.name
                                    (Dynamic_object.metadata cr.obj))))
                           || Result.fold
                                ~ok:(fun k ->
                                  is_ok_create_response_and_matches_key k m)
                                ~error:(fun (_ : Err.t) -> false)
                                (Api_method.create_request_key cr)))
                  in_flight))
          (ongoing s controller_id));
    (* BUILD-SPEC-P16 section 4.6: Q5's OWN full antecedent, including the
       name-is-Some conjunct -- a matched OK create response against a
       pending NAMED create request. Predicted non-zero even at vct:false
       (P16-E: the pod create is not vct-gated and fires at desired = 1). *)
    interesting =
      (fun s ->
        let in_flight = msgs s in
        Object_ref_map.exists
          (fun _key (orc : Controller.ongoing_reconcile) ->
            Option.fold orc.pending_req_msg ~none:false
              ~some:(fun (pending : Message.t) ->
                Option.fold (create_request_of pending) ~none:false
                  ~some:(fun (cr : Api_method.create_request) ->
                    Option.is_some
                      (Object_meta.name (Dynamic_object.metadata cr.obj))
                    && List.exists
                         (fun (m : Message.t) ->
                           is_ok_create_response m
                           && Message.resp_msg_matches_req_msg m pending)
                         in_flight)))
          (ongoing s controller_id));
  }

let rv_family (b : Bound.t) : Invariants.invariant list =
  [
    object_in_ok_get_response_has_smaller_rv_than_etcd;
    object_in_ok_get_resp_is_same_as_etcd_with_same_rv b;
  ]

let matched_family ~(controller_id : int) : Invariants.invariant list =
  [
    key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_pending_req
      ~controller_id;
    key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req
      ~controller_id;
  ]

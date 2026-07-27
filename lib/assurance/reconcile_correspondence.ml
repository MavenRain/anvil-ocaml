(* Faithful OCaml port of Anvil's four RECONCILE-SIDE correspondence StatePreds
   (BUILD-SPEC-P15 section 2): R1 from
   src/kubernetes_cluster/proof/network.rs (:104-117) and R2-R4 from
   src/kubernetes_cluster/proof/controller_runtime_liveness.rs (R2 :131-145,
   R3 :147-168, R4 :105-110), as pure {!Cluster.cluster_state} predicates
   reusing {!Invariants.invariant}. Transcribed against the durable upstream
   checkout at ~/Documents/anvil-ref, not reconstructed from memory.

   Where P14's five members are guarded on the NETWORK side
   ([in_flight().contains(msg)]), all four here are guarded on the
   ONGOING-RECONCILE side ([ongoing_reconciles.contains_key] plus a local-state
   or pending-request premise) — the asymmetry BUILD-SPEC-P15 section 3 turns
   into a measurement: [restart_controller] (cluster.ml:291-324) empties
   [ongoing_reconciles] and leaves [s.network] untouched, so the crash edge
   destroys every guard below while preserving every P14 guard.

   Kept as a SEPARATE list, deliberately: appending to {!Invariants.always},
   {!Vsts_invariants.always} or {!Correspondence.family} would move P13's and
   P14's committed pinned counts and silently rewrite shipped results
   (BUILD-SPEC-P15 section 4.2); worse, unioning with P14's family would MASK
   R3 under mutation MA, whose N1 fires one step before a collision can form
   (section 3, the experimental-design trap).

   Convention firewall (anvil-ocaml): no loop keywords (List/Option/Map
   combinators only), no [_ ->] catch-all on any finite sum — the
   [message_content] classifiers spell every arm out, following
   correspondence.ml:33-49 — no two-arm match on option (Option.fold /
   Option.is_some / Option.is_none), no exceptions. Every predicate is a total
   [bool]. [Option.fold ~none:] is EAGER; every [~none:] below is a constant,
   never a call. *)

(* -- message classification (Anvil MessageContent discriminants) -------------
   Exhaustive on the finite sum; the Verus [msg.content is APIRequest] /
   [msg.content is ExternalRequest] projections. Redeclared here rather than
   shared because correspondence.ml keeps its classifiers private (its .mli
   exports members only) and widening a committed P14 surface for a P15
   convenience would be the tail wagging the dog. *)

let content_is_api_request (m : Message.t) : bool =
  match m.content with
  | Message.Api_request _ -> true
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    false

let content_is_external_request (m : Message.t) : bool =
  match m.content with
  | Message.External_request _ -> true
  | Message.Api_request _ | Message.Api_response _
  | Message.External_response _ ->
    false

(* The content disjunct of Anvil [has_pending_req_msg]
   (controller_runtime_liveness.rs:23-24): an api REQUEST or an external
   REQUEST. LOAD-BEARING (BUILD-SPEC-P15 section 2): do not weaken to
   [Option.is_some] — a pending message that is a RESPONSE must falsify
   [has_pending_req_msg], not satisfy it. *)
let content_is_request (m : Message.t) : bool =
  content_is_api_request m || content_is_external_request m

(* -- ported helper predicates (crl.rs = controller_runtime_liveness.rs) ------ *)

let ongoing (s : Cluster.cluster_state) (controller_id : int) :
    Controller.ongoing_reconcile Object_ref_map.t =
  Cluster.ongoing_reconciles s controller_id

(* Anvil [has_pending_req_msg(controller_id, s, key)] (crl.rs:21-25), at the
   binding level: [pending_req_msg is Some] is the [~none:false] leg, the
   content disjunct is [content_is_request]. Callers that visit bound keys via
   [Object_ref_map.for_all]/[exists] discharge upstream's partial-map indexing
   ([ongoing_reconciles(controller_id)[key]]) by construction. *)
let has_pending_req_msg_orc (orc : Controller.ongoing_reconcile) : bool =
  Option.fold orc.pending_req_msg ~none:false ~some:content_is_request

(* Anvil [no_pending_req_msg(controller_id, s, key)] (crl.rs:31-33). *)
let no_pending_req_msg_orc (orc : Controller.ongoing_reconcile) : bool =
  Option.is_none orc.pending_req_msg

(* Anvil [request_sent_by_controller_with_key(controller_id, key, msg)]
   (crl.rs:56-68): [msg.src == Controller(controller_id, key)] and either
   ([dst == APIServer] with api-request content) or ([dst == External(cid)]
   with external-request content). The port's [Message.host_id] carries
   [Controller of int * Common.object_ref] (message.mli:37), so this is an
   exact transcription, not an approximation. *)
let request_sent_by_controller_with_key ~(controller_id : int)
    ~(key : Common.object_ref) (msg : Message.t) : bool =
  Message.equal_host_id msg.src (Message.Controller (controller_id, key))
  && ((Message.equal_host_id msg.dst Message.Api_server
      && content_is_api_request msg)
     || Message.equal_host_id msg.dst (Message.External controller_id)
        && content_is_external_request msg)

(* Anvil [s.in_flight().contains(msg)]: multiset membership, multiplicity >= 1. *)
let in_flight_contains (s : Cluster.cluster_state) (msg : Message.t) : bool =
  Message.Pool.mem msg (Cluster.in_flight s)

(* Anvil [exists |resp_msg| s.in_flight().contains(resp_msg) &&
   resp_msg_matches_req_msg(resp_msg, msg)] (crl.rs:139-142 / :157-165):
   [Message.Pool.distinct] is one representative per distinct in-flight
   message, exactly the extent of [contains] (the P14 idiom,
   correspondence.ml:52-58); [resp_msg_matches_req_msg] keeps upstream's
   (resp, req) argument order (message.ml:290). *)
let matching_resp_in_flight (s : Cluster.cluster_state) (req : Message.t) :
    bool =
  List.exists
    (fun (resp : Message.t) -> Message.resp_msg_matches_req_msg resp req)
    (Message.Pool.distinct (Cluster.in_flight s))

(* The R2/R4 non-vacuity witness: some bound key's local state satisfies the
   instantiated expected-states predicate, i.e. Anvil
   [at_expected_reconcile_states(controller_id, key, expected)] (crl.rs:98-103)
   holds at SOME key — [contains_key] is [Object_ref_map.exists] visiting only
   bound keys, [expected_states(local_state)] is the body. *)
let some_at_expected ~(controller_id : int) ~(expected : Value.t -> bool)
    (s : Cluster.cluster_state) : bool =
  Object_ref_map.exists
    (fun _key (orc : Controller.ongoing_reconcile) -> expected orc.local_state)
    (ongoing s controller_id)

(* -- R1 pending_req_of_key_is_unique_with_unique_id (network.rs:104-117) -----
   Upstream is per-[key]; shipped universally closed over ALL keys
   (BUILD-SPEC-P15 section 2/R1): the outer [for_all] is the closure, the
   [~none:true] leg is the [pending_req_msg is Some] premise, and the inner
   [for_all] is upstream's [forall other_key] with the [key != other_key] and
   [is Some] premises rendered as disjuncts. Strictly stronger than any single
   instantiation, matching how P14 shipped N2/N3. *)
let pending_req_of_key_is_unique_with_unique_id ~(controller_id : int) :
    Invariants.invariant =
  {
    name = "pending_req_of_key_is_unique_with_unique_id";
    source = "kubernetes_cluster/proof/network.rs:104";
    holds =
      (fun s ->
        let reconciles = ongoing s controller_id in
        Object_ref_map.for_all
          (fun key (orc : Controller.ongoing_reconcile) ->
            Option.fold orc.pending_req_msg ~none:true
              ~some:(fun (req : Message.t) ->
                Object_ref_map.for_all
                  (fun other_key (other : Controller.ongoing_reconcile) ->
                    Common.equal_object_ref key other_key
                    || Option.fold other.pending_req_msg ~none:true
                         ~some:(fun (other_req : Message.t) ->
                           not
                             (Message.Rpc_id.equal req.rpc_id other_req.rpc_id)))
                  reconciles))
          reconciles);
    (* BUILD-SPEC-P15 section 4.2: at least TWO ongoing reconciles both holding
       [Some] pending requests. With fewer, every inner premise fails (the only
       [Some]-pending other key is [key] itself) and R1 is vacuous — expected
       STRUCTURALLY at [desired = 1], which the checker leg must disclose
       rather than count as exercise. *)
    interesting =
      (fun s ->
        let pending_count =
          Object_ref_map.fold
            (fun _key (orc : Controller.ongoing_reconcile) acc ->
              if Option.is_some orc.pending_req_msg then acc + 1 else acc)
            (ongoing s controller_id) 0
        in
        pending_count >= 2);
  }

(* -- R2 pending_req_in_flight_or_resp_in_flight_at_reconcile_state
   (crl.rs:131-145) ------------------------------------------------------------
   Guard: [at_expected_reconcile_states] — [contains_key] discharged by
   [for_all] visiting bound keys, [expected orc.local_state] as the antecedent.
   Conclusion under [let msg = pending_req_msg->0]: [has_pending_req_msg]
   ([~none:false] + [content_is_request]), provenance, and the in-flight OR
   matching-response disjunction. A guard-satisfying key with NO pending
   request falsifies the member (upstream's conclusion fails at
   [has_pending_req_msg]), hence [~none:false], not [~none:true]. *)
let pending_req_in_flight_or_resp_in_flight_at_reconcile_state
    ~(controller_id : int) ~(expected : Value.t -> bool) :
    Invariants.invariant =
  {
    name = "pending_req_in_flight_or_resp_in_flight_at_reconcile_state";
    source = "kubernetes_cluster/proof/controller_runtime_liveness.rs:131";
    holds =
      (fun s ->
        Object_ref_map.for_all
          (fun key (orc : Controller.ongoing_reconcile) ->
            (not (expected orc.local_state))
            || Option.fold orc.pending_req_msg ~none:false
                 ~some:(fun (msg : Message.t) ->
                   content_is_request msg
                   && request_sent_by_controller_with_key ~controller_id ~key
                        msg
                   && (in_flight_contains s msg
                      || matching_resp_in_flight s msg)))
          (ongoing s controller_id));
    (* BUILD-SPEC-P15 section 4.2: the guard [at_expected_reconcile_states]
       holds at the instantiated state — i.e. at some bound key. While no
       ongoing local state satisfies [expected], R2 is vacuous. *)
    interesting = some_at_expected ~controller_id ~expected;
  }

(* -- R3 pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg
   (crl.rs:147-168) — THE HEADLINE ---------------------------------------------
   Premise: [contains_key && has_pending_req_msg] — the [~none:true] leg is the
   [is Some] conjunct failing (premise false, vacuously true) and
   [not (content_is_request msg)] is the content conjunct failing. Conclusion:
   provenance, existence (request or matching response in flight), and
   EXCLUSIVITY (never both) — the two pool scans are computed once and reused
   across the second and third conjuncts, a rendering not a weakening.
   Universally closed over keys like R1.

   FAITHFULNESS FLAG (BUILD-SPEC-P15 section 2): upstream proves R3
   [leads_to(always(..))] (controller_runtime_safety.rs:422), NOT [always].
   Asserting it after every step is deliberately STRONGER; a refutation near
   the seed is the leads-to shape appearing empirically, not a port bug, and
   the lasso must be inspected before any such claim. *)
let pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg
    ~(controller_id : int) : Invariants.invariant =
  {
    name = "pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg";
    source = "kubernetes_cluster/proof/controller_runtime_liveness.rs:147";
    holds =
      (fun s ->
        Object_ref_map.for_all
          (fun key (orc : Controller.ongoing_reconcile) ->
            Option.fold orc.pending_req_msg ~none:true
              ~some:(fun (msg : Message.t) ->
                (not (content_is_request msg))
                ||
                let req_in = in_flight_contains s msg in
                let resp_in = matching_resp_in_flight s msg in
                request_sent_by_controller_with_key ~controller_id ~key msg
                && (req_in || resp_in)
                && not (req_in && resp_in)))
          (ongoing s controller_id));
    (* BUILD-SPEC-P15 section 4.2: an ongoing reconcile at some key with
       [has_pending_req_msg] true — the implication's premise fires somewhere.
       The content conjunct is kept in the witness too: a [Some] pending
       RESPONSE would leave R3 vacuous and must not count as exercise. *)
    interesting =
      (fun s ->
        Object_ref_map.exists
          (fun _key (orc : Controller.ongoing_reconcile) ->
            has_pending_req_msg_orc orc)
          (ongoing s controller_id));
  }

(* -- R4 no_pending_req_msg_at_reconcile_state (crl.rs:105-110) ---------------
   [at_expected_reconcile_states ==> no_pending_req_msg]: the same guard shape
   as R2 with the polarity of the pending request flipped — R2 and R4 are the
   duals BUILD-SPEC-P15 section 2 pairs, validated by one side-condition
   checker each ({!state_comes_with_a_pending_request} /
   {!state_comes_with_no_pending_request}). *)
let no_pending_req_msg_at_reconcile_state ~(controller_id : int)
    ~(expected : Value.t -> bool) : Invariants.invariant =
  {
    name = "no_pending_req_msg_at_reconcile_state";
    source = "kubernetes_cluster/proof/controller_runtime_liveness.rs:105";
    holds =
      (fun s ->
        Object_ref_map.for_all
          (fun _key (orc : Controller.ongoing_reconcile) ->
            (not (expected orc.local_state)) || no_pending_req_msg_orc orc)
          (ongoing s controller_id));
    (* BUILD-SPEC-P15 section 4.2: the same guard as R2, at R4's OWN
       instantiation — some bound key's local state satisfies [expected]. *)
    interesting = some_at_expected ~controller_id ~expected;
  }

(* -- side-condition checkers (controller_runtime_safety.rs:90-93 / :507) -----
   R2 is an upstream theorem ONLY at instantiations satisfying
   [state_comes_with_a_pending_request]; R4 only under the dual. Executable,
   BOUNDED renderings: the transition quantifier ranges over the supplied
   reachable triples, not over all inputs (the disclosed weakening — see the
   .mli). The init conjunct of the first checker is upstream's
   [forall |s| state(s) ==> s != init()], rendered EXACTLY (not bounded) as
   [not (expected (init ()))]: the two are equivalent under value equality —
   instantiate upstream's forall at [init()] for one direction; for the other,
   any [s] with [expected s && s = init()] would give [expected (init ())]. *)

let state_comes_with_a_pending_request (model : Controller.reconcile_model)
    ~(expected : Value.t -> bool)
    (triples : (Dynamic_object.t * Value.t Io.response_view option * Value.t) list)
    : bool =
  (not (expected (model.init ())))
  && List.for_all
       (fun ( (cr : Dynamic_object.t),
              (resp_o : Value.t Io.response_view option),
              (pre_state : Value.t) ) ->
         let post_state, req_o = model.transition cr resp_o pre_state in
         (not (expected post_state)) || Option.is_some req_o)
       triples

(* Upstream's dual (controller_runtime_safety.rs:507) has NO init conjunct —
   [no_pending_req_msg] holds trivially at reconcile start, so the lemma never
   needs one. The asymmetry is upstream's, preserved here. *)
let state_comes_with_no_pending_request (model : Controller.reconcile_model)
    ~(expected : Value.t -> bool)
    (triples : (Dynamic_object.t * Value.t Io.response_view option * Value.t) list)
    : bool =
  List.for_all
    (fun ( (cr : Dynamic_object.t),
           (resp_o : Value.t Io.response_view option),
           (pre_state : Value.t) ) ->
      let post_state, req_o = model.transition cr resp_o pre_state in
      (not (expected post_state)) || Option.is_none req_o)
    triples

let family ~(controller_id : int) ~(pending_states : Value.t -> bool)
    ~(none_states : Value.t -> bool) : Invariants.invariant list =
  [
    pending_req_of_key_is_unique_with_unique_id ~controller_id;
    pending_req_in_flight_or_resp_in_flight_at_reconcile_state ~controller_id
      ~expected:pending_states;
    pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg
      ~controller_id;
    no_pending_req_msg_at_reconcile_state ~controller_id
      ~expected:none_states;
  ]

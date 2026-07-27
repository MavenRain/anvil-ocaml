(* BUILD-SPEC-P15 §6 - confirm-by-mutation for the RECONCILE-SIDE
   correspondence family (R1-R4). A clean, decisive [No_counterexample] from
   [t_p15_reconcile_correspondence] is only evidence if the family would
   actually MOVE when the thing it checks breaks; on the TRUE model every leg
   is clean, so the Refuted path would otherwise ship with ZERO observed-red
   coverage. Two forms of evidence here, exactly the P14 split: the MANUAL
   real-source mutants MA and M1 (documented below - applied, SEEN red,
   reverted; only the green tree ships, per
   [[feedback-confirm-tests-by-mutation]]), and the AUTOMATED permanent
   per-member forges, whose reddening under the §6 assurance-side mutations
   MB / MC / MD / ME was likewise SEEN and is recorded per row.

   ==== MA (MANUAL, real source; NOT shipped) - the headline of the phase =====

   Mutant: [restart_controller] (lib/cluster/cluster.ml:291-324) ALSO resets
   the global rpc-id allocator ([rpc_id_allocator = Message.Rpc_id_allocator.init ()]
   added to the post-restart state; the real transition rewrites only the
   controller's own maps and leaves the top-level allocator untouched).

   MEASURED effect (PREDICTION P15-B CONFIRMED): the L1 crash leg flips
   clean -> Refuted with
   [violated = Some "pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg"]
   - R3, by its EXCLUSIVITY conjunct, at a post-crash state ([crashes >= 1]:
   the L0 zero-budget control is UNCHANGED - clean, decisive, 76 states - so
   the refutation is attributable to the CRASH EDGE). Mechanism: the reset
   counter re-issues a surviving orphan's rpc id to the fresh post-restart
   request; once the api server answers the orphan, the response MATCHES the
   new pending request while that request is still in flight - both XOR
   disjuncts true. The §3 masking trap did NOT fire: the name is R3's, not
   N1's ([every_in_flight_msg_has_lower_id_than_allocator] would have meant
   the P14/P15 family lists were unioned somewhere - a harness bug). P14
   measured N1 firing at steps=6 under this same mutant; asserting the P15
   family ALONE is what lets R3's strictly-later collision be seen at all.

   ==== M1 (MANUAL, real source; NOT shipped) - the negative that must hold ===

   Mutant: [restart_controller] KEEPS [ongoing_reconciles] instead of
   emptying it.

   MEASURED effect: refutes NOTHING - the §3 directional trap's REQUIRED
   negative, cross-phase consistent with P13 and P14: keeping the reconcile
   map keeps every pending request paired with its in-flight copy, so R1-R4
   all still hold. Both legs stay clean and [violated] stays [None]; the
   GRAPH shrinks (L1 states 464 -> 152, exactly P14's measured shrink under
   the same mutant), so the anchor's states PIN reddens while every semantic
   assertion stays green - reading that red as "M1 refuted something" would
   repeat P12's misattribution; it is the pin moving, not the family.

   ==== the automated rows (each SEEN red under its §6 source mutation) ======

   MB  deleting R3's EXCLUSIVITY conjunct in reconcile_correspondence.ml
       reddens {!test_r3_rejects_request_and_matching_response_both_in_flight}
       and NOTHING else here - the provenance forge stays red-capable, so the
       two R3 forges really pull on different conjuncts.
   MC  deleting R3's PROVENANCE conjunct reddens
       {!test_r3_rejects_foreign_src_pending_request} and nothing else.
   MD  deleting R1's [key != other_key] guard makes R1 SELF-REFUTING: the R1
       control (distinct ids ACCEPTED) reddens, and the live legs refute
       everywhere a pending request exists.
   ME  forcing either §4.3 side-condition checker to [true] reddens
       {!test_me_side_condition_checkers_reject}: its two REJECTING
       directions are the only place the checkers' [false] path is ever
       observed ([t_p15_reconcile_correspondence]'s side-condition test
       asserts only ACCEPTING verdicts, which a constant-true checker
       satisfies).

   TAUTOLOGY/ENTAILMENT AUDIT (the P14 lesson - it shipped one tautological
   and one entailed mutation row): every forged assertion below is falsified
   by a concrete, named change - each violating forge's [false (holds ...)]
   fails iff that member's [holds] accepts the forged violation (e.g. under
   [fun _ -> true]); each control's [true (holds ...)] fails iff [holds]
   over-rejects (e.g. under [fun _ -> false], or MD for R1); each
   [violated_names = [exactly one]] fails if ANY other member moves on that
   forge; the ME rejections fail iff a checker conjunct is bypassed. No
   assertion is entailed by another: the two R3 forges differ in which
   conjunct is falsified (SEEN independent under MB/MC), and each
   control/violating pair differs in exactly the discriminating field.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches (both [Mc.outcome] arms named), no [List.nth/hd/tl], no
   [raise/assert/failwith/Option.get], Alcotest as the sanctioned failure
   primitive. Leg pins are read from {!P15_witness}, never re-typed. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Rc = Anvil_assurance.Reconcile_correspondence

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P15_witness.witness_desired
let depth : int = P15_witness.witness_depth
let bound : Bound.t = P15_witness.p15_bound ~desireds:[ desired ]

(* The family EXACTLY as the leg instantiates it (R2/R4 over the baked-in,
   side-condition-validated predicates), plus each member individually. *)

let family : Invariants.invariant list =
  Rc.family ~controller_id ~pending_states:Fc.vsts_pending_states
    ~none_states:Fc.vsts_none_states

let r1 : Invariants.invariant =
  Rc.pending_req_of_key_is_unique_with_unique_id ~controller_id

let r2 : Invariants.invariant =
  Rc.pending_req_in_flight_or_resp_in_flight_at_reconcile_state ~controller_id
    ~expected:Fc.vsts_pending_states

let r3 : Invariants.invariant =
  Rc.pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg
    ~controller_id

let r4 : Invariants.invariant =
  Rc.no_pending_req_msg_at_reconcile_state ~controller_id
    ~expected:Fc.vsts_none_states

(* ---- outcome / report projections (exhaustive 2-arm matches) --------------- *)

let refuted (o : Fc.faulted Mc.outcome) : bool =
  match o with Mc.Refuted _ -> true | Mc.No_counterexample _ -> false

let report_clean (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

let report_decisive (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let report_states (r : Fc.fault_report) : int =
  match r.outcome with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let inv_name (i : Invariants.invariant option) : string =
  Option.fold i ~none:"<none>" ~some:(fun (x : Invariants.invariant) -> x.name)

(* Every family member the state violates, by name. [[]] is "the whole family
   holds"; a singleton is "exactly this member broke" - what makes a forge an
   ISOLATION rather than merely a refutation. *)
let violated_names (s : Cluster.cluster_state) : string list =
  List.filter_map
    (fun (i : Invariants.invariant) ->
      if i.holds s then None else Some i.name)
    family

(* ---- the exact-leg-check harness (the t_p14_mutation singleton pattern) ---- *)

let singleton_reach (f : Fc.faulted) : Fc.faulted Mc.reachable =
  Mc.explore ~depth:1
    ~successors:(fun (_ : Fc.faulted) -> [])
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash ~init:[ f ]

let safety_of (invs : Invariants.invariant list) (f : Fc.faulted) :
    Fc.faulted Mc.outcome =
  let conj = Invariants.conjunction invs in
  Mc.check_safety (singleton_reach f)
    ~inv:(fun (x : Fc.faulted) -> conj x.cs)
    ~equal:Fc.faulted_equal

(* A POST-CRASH product state around a forged [cluster_state], so the forges
   run through the SAME [Fc.faulted] wrapper the leg checks. *)
let product (cs : Cluster.cluster_state) : Fc.faulted =
  { Fc.cs; crashes = 1; drops = 0; monkeys = 0 }

(* ==== the forge ============================================================= *)

(* Forge INPUTS (not measured pins, so they live here rather than in
   {!P15_witness}, which pins only measured numbers; P14 centralized its forge
   inputs in its witness because TWO files consumed them - here exactly one
   does). The id pair echoes P14's (3,3)/(3,4) collided/distinct shape. *)
let forged_shared_rpc_id : int = 3
let forged_distinct_rpc_id : int = 4

(* Structurally distinct from the scenario's registered id BY CONSTRUCTION -
   the foreign-src forge needs only the inequality, never a specific value. *)
let foreign_controller_id : int = Scenario.controller_id + 1

let cr_key : Common.object_ref =
  {
    Common.kind = Common.Custom_resource "VStatefulSet";
    name = "vsts";
    namespace = "ns";
  }

(* A SECOND CR key: R1's premise needs two concurrently-ongoing reconciles,
   which the live single-CR graph can never hold (the measured STRUCTURAL
   zero) - so R1's rejecting direction is observable ONLY on a forge. *)
let cr_key_b : Common.object_ref =
  {
    Common.kind = Common.Custom_resource "VStatefulSet";
    name = "vsts-b";
    namespace = "ns";
  }

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ()

(* An api GET request for [key], sent by controller [cid] AS the reconcile for
   [key] - [src = Controller (cid, key)], which is exactly what
   [request_sent_by_controller_with_key] demands of provenance. *)
let req_for ~(cid : int) ~(id : int) (key : Common.object_ref) : Message.t =
  Message.form_msg
    ~src:(Message.Controller (cid, key))
    ~dst:Message.Api_server ~rpc_id:(Message.Rpc_id.of_int id)
    ~content:(Message.get_req_msg_content key)

(* An ongoing reconcile awaiting [pending] with the given local state.
   [triggering_cr] and [reconcile_id] are inert - no member reads them. *)
let orc ~(local_state : Value.t) ~(pending : Message.t option) :
    Controller.ongoing_reconcile =
  {
    Controller.triggering_cr =
      V_stateful_set.marshal (Scenario.vsts ~desired ());
    pending_req_msg = pending;
    local_state;
    reconcile_id = 0;
  }

(* An UNDECODABLE local state: [vsts_pending_states] and [vsts_none_states]
   are complements over DECODABLE states only and both go FALSE here, so a
   null-state forge keeps R2 and R4 vacuous by construction - the isolation
   device for the R1 and R3 forges. *)
let null_local : Value.t = Value.of_json `Null

(* [seed] with the network replaced and the controller's [ongoing_reconciles]
   REPLACED, every other field of its entry (notably [crash_enabled])
   preserved. Total, no [Option.get]: the [~none] leg rebuilds a fresh entry,
   and every test asserts the resulting map's cardinal FIRST. *)
let forge ~(in_flight : Message.t list)
    (ongoing : (Common.object_ref * Controller.ongoing_reconcile) list) :
    Cluster.cluster_state =
  let base =
    {
      seed with
      Cluster.network = { Network.in_flight = Message.Pool.of_list in_flight };
    }
  in
  let cae : Cluster.controller_and_external =
    Option.fold
      (Imap.find_opt controller_id base.Cluster.controller_and_externals)
      ~none:
        {
          Cluster.controller = Controller.init;
          external_ = None;
          crash_enabled = true;
        }
      ~some:(fun (c : Cluster.controller_and_external) -> c)
  in
  let ongoing_map =
    List.fold_left
      (fun (m : Controller.ongoing_reconcile Object_ref_map.t)
           ((k, o) : Common.object_ref * Controller.ongoing_reconcile) ->
        Object_ref_map.add k o m)
      Object_ref_map.empty ongoing
  in
  {
    base with
    Cluster.controller_and_externals =
      Imap.add controller_id
        {
          cae with
          Cluster.controller =
            { cae.controller with Controller.ongoing_reconciles = ongoing_map };
        }
        base.Cluster.controller_and_externals;
  }

(* The registered VSTS reconcile model, read off the cluster (the R2/R4
   forges DERIVE their guard-satisfying local states from its own
   init/transition rather than hand-marshalling one - §4.3's derived-not-
   invented rule applied to the forge). *)
let registered_model : Controller.reconcile_model option =
  Option.map
    (fun (cm : Cluster.controller_model) ->
      Controller.model_of_controller ~kind:cm.Cluster.kind cm.Cluster.reconciler)
    (Imap.find_opt controller_id cluster.Cluster.controller_models)

(* ==== R1: two ongoing reconciles sharing one pending rpc id ================= *)

let r1_state ~(id_b : int) : Cluster.cluster_state =
  let req_a = req_for ~cid:controller_id ~id:forged_shared_rpc_id cr_key in
  let req_b = req_for ~cid:controller_id ~id:id_b cr_key_b in
  (* BOTH requests are also in flight with correct provenance, so R3 holds at
     both keys and the forge isolates R1. *)
  forge
    ~in_flight:[ req_a; req_b ]
    [
      (cr_key, orc ~local_state:null_local ~pending:(Some req_a));
      (cr_key_b, orc ~local_state:null_local ~pending:(Some req_b));
    ]

let r1_violating : Cluster.cluster_state = r1_state ~id_b:forged_shared_rpc_id
let r1_control : Cluster.cluster_state = r1_state ~id_b:forged_distinct_rpc_id

(* WHAT COULD MAKE THIS FAIL: the [false] check iff R1's [holds] accepts a
   cross-key rpc-id collision (e.g. [fun _ -> true]); the control iff it
   over-rejects (MD - deleting the [key != other_key] guard makes the
   distinct-id state compare each key with ITSELF and reject; SEEN red there);
   the isolation list iff any other member moves on this forge. Not entailed
   by any other test: no other forge holds two ongoing reconciles. *)
let test_r1_rejects_colliding_pending_ids () =
  (* THE FORGE IS REAL, checked before anything is concluded from it. *)
  Alcotest.(check int) "R1 forge: exactly TWO ongoing reconciles planted" 2
    (Object_ref_map.cardinal
       (Cluster.ongoing_reconciles r1_violating controller_id));
  Alcotest.(check int)
    "R1 forge: both pending requests are in flight (so R3 holds and the forge \
     isolates R1)"
    2
    (Message.Pool.cardinal (Cluster.in_flight r1_violating));
  Alcotest.(check bool)
    "R1 forge: R1's interesting fires (two Some-pending reconciles)" true
    (r1.interesting r1_violating);
  (* NEGATIVE CONTROL FIRST, so the discriminating direction is SEEN. *)
  Alcotest.(check bool) "R1 control: DISTINCT ids on the same shape ACCEPTED"
    true (r1.holds r1_control);
  Alcotest.(check bool)
    "R1 control: interesting fires there TOO (not clean-by-vacuity)" true
    (r1.interesting r1_control);
  Alcotest.(check (list string)) "R1 control: violates NO member" []
    (violated_names r1_control);
  (* SEMANTIC: the member REJECTS. *)
  Alcotest.(check bool)
    "R1 REJECTS two ongoing reconciles whose pending requests share an rpc_id"
    false (r1.holds r1_violating);
  Alcotest.(check (list string))
    "R1 is the ONLY member the forge violates (the red is attributable)"
    [ r1.name ] (violated_names r1_violating);
  Alcotest.(check bool) "R1: the EXACT leg check REFUTES the forge" true
    (refuted (safety_of family (product r1_violating)))

(* ==== R3 exclusivity: request AND matching response both in flight (MB) ===== *)

let r3x_req : Message.t =
  req_for ~cid:controller_id ~id:forged_shared_rpc_id cr_key

(* A response the api server COULD have sent for [r3x_req]: the matched-error
   former is the same one [drop_req] uses (message.ml:339), so the match is
   the real [resp_msg_matches_req_msg] relation, not a lookalike. *)
let r3x_resp : Message.t =
  Message.form_matched_err_resp_msg r3x_req Api_method.Timeout

let r3x_violating : Cluster.cluster_state =
  forge
    ~in_flight:[ r3x_req; r3x_resp ]
    [ (cr_key, orc ~local_state:null_local ~pending:(Some r3x_req)) ]

let r3x_control_req_only : Cluster.cluster_state =
  forge ~in_flight:[ r3x_req ]
    [ (cr_key, orc ~local_state:null_local ~pending:(Some r3x_req)) ]

let r3x_control_resp_only : Cluster.cluster_state =
  forge ~in_flight:[ r3x_resp ]
    [ (cr_key, orc ~local_state:null_local ~pending:(Some r3x_req)) ]

(* WHAT COULD MAKE THIS FAIL: the [false] check iff R3 accepts request AND
   matching response simultaneously in flight - exactly what MB (exclusivity
   conjunct deleted) does, SEEN red there; the req-only/resp-only controls
   iff R3 over-rejects a single-disjunct state (resp-only is the disjunct
   upstream's or-member keeps - it also guards against the existence disjunct
   collapsing to just [in_flight req]). NOT entailed by the provenance forge:
   this state's provenance is correct (asserted below), so only the
   exclusivity conjunct can reject here. *)
let test_r3_rejects_request_and_matching_response_both_in_flight () =
  (* THE FORGE IS REAL. *)
  Alcotest.(check bool)
    "R3x forge: the forged response REALLY matches the pending request \
     (resp_msg_matches_req_msg)"
    true
    (Message.resp_msg_matches_req_msg r3x_resp r3x_req);
  Alcotest.(check int) "R3x forge: request and response both in flight" 2
    (Message.Pool.cardinal (Cluster.in_flight r3x_violating));
  Alcotest.(check bool)
    "R3x forge: R3's interesting fires (a pending REQUEST exists)" true
    (r3.interesting r3x_violating);
  (* NEGATIVE CONTROLS FIRST: each XOR disjunct ALONE is accepted. *)
  Alcotest.(check bool) "R3x control: request alone in flight ACCEPTED" true
    (r3.holds r3x_control_req_only);
  Alcotest.(check bool)
    "R3x control: matching response alone in flight ACCEPTED (the kept \
     disjunct)"
    true
    (r3.holds r3x_control_resp_only);
  Alcotest.(check (list string)) "R3x control (req only): violates NO member"
    [] (violated_names r3x_control_req_only);
  Alcotest.(check (list string)) "R3x control (resp only): violates NO member"
    [] (violated_names r3x_control_resp_only);
  (* SEMANTIC: the member REJECTS - by EXCLUSIVITY, since provenance and
     existence are both satisfied here. *)
  Alcotest.(check bool)
    "R3 REJECTS the pending request and its matching response BOTH in flight"
    false (r3.holds r3x_violating);
  Alcotest.(check (list string)) "R3 is the ONLY member the forge violates"
    [ r3.name ] (violated_names r3x_violating);
  Alcotest.(check bool) "R3x: the EXACT leg check REFUTES the forge" true
    (refuted (safety_of family (product r3x_violating)))

(* ==== R3 provenance: a pending request with a FOREIGN src (MC) ============== *)

let r3p_state ~(cid : int) : Cluster.cluster_state =
  let m = req_for ~cid ~id:forged_shared_rpc_id cr_key in
  (* The request IS in flight and NO response matches it, so existence and
     exclusivity both hold and only provenance can reject. *)
  forge ~in_flight:[ m ]
    [ (cr_key, orc ~local_state:null_local ~pending:(Some m)) ]

let r3p_violating : Cluster.cluster_state = r3p_state ~cid:foreign_controller_id
let r3p_control : Cluster.cluster_state = r3p_state ~cid:controller_id

(* WHAT COULD MAKE THIS FAIL: the [false] check iff R3 accepts a pending
   request whose [src] names a DIFFERENT controller - exactly what MC
   (provenance conjunct deleted) does, SEEN red there; the control iff
   provenance over-rejects the true sender. NOT entailed by the exclusivity
   forge (whose provenance is correct) nor vice versa - MB reddened only the
   exclusivity test and MC only this one, measured. *)
let test_r3_rejects_foreign_src_pending_request () =
  (* THE FORGE IS REAL: the foreign id really differs from the registered
     one (by construction, but asserted so the forge cannot rot silently). *)
  Alcotest.(check bool) "R3p forge: foreign controller id <> registered id"
    true
    (foreign_controller_id <> controller_id);
  Alcotest.(check int) "R3p forge: exactly ONE ongoing reconcile planted" 1
    (Object_ref_map.cardinal
       (Cluster.ongoing_reconciles r3p_violating controller_id));
  Alcotest.(check int)
    "R3p forge: the pending request is in flight (existence + exclusivity \
     hold; only provenance can reject)"
    1
    (Message.Pool.cardinal (Cluster.in_flight r3p_violating));
  Alcotest.(check bool)
    "R3p forge: R3's interesting fires (a pending REQUEST exists)" true
    (r3.interesting r3p_violating);
  (* NEGATIVE CONTROL FIRST. *)
  Alcotest.(check bool)
    "R3p control: the same shape sent by the REGISTERED controller ACCEPTED"
    true (r3.holds r3p_control);
  Alcotest.(check (list string)) "R3p control: violates NO member" []
    (violated_names r3p_control);
  (* SEMANTIC: the member REJECTS - by PROVENANCE. *)
  Alcotest.(check bool)
    "R3 REJECTS a pending request whose src is a foreign controller" false
    (r3.holds r3p_violating);
  Alcotest.(check (list string)) "R3 is the ONLY member the forge violates"
    [ r3.name ] (violated_names r3p_violating);
  Alcotest.(check bool) "R3p: the EXACT leg check REFUTES the forge" true
    (refuted (safety_of family (product r3p_violating)))

(* ==== R2 / R4: guard-satisfying states with the WRONG pending polarity ======
   Both need a local state that genuinely satisfies the instantiated guard, so
   both are DERIVED from the registered model: [init ()] lands in the NONE
   class and one [transition] step from it lands in the PENDING class with a
   request emitted - asserted as forge realness before anything else. *)

(* WHAT COULD MAKE THIS FAIL: the [false] check iff R2 accepts an
   expected-state reconcile with NO pending request ([fun _ -> true], or
   [~none:false] flipped to [~none:true] - the load-bearing polarity the .ml
   header calls out); the control iff R2 over-rejects the true shape (pending
   request present, correctly-provenanced and in flight). Vacuity-proof: the
   guard genuinely fires on both forge states (asserted via [interesting]). *)
let test_r2_rejects_expected_state_without_pending_req () =
  Alcotest.(check bool) "R2: the registered VSTS model exists" true
    (Option.is_some registered_model);
  Option.fold ~none:()
    ~some:(fun (model : Controller.reconcile_model) ->
      let cr = V_stateful_set.marshal (Scenario.vsts ~desired ()) in
      let ls_none = model.Controller.init () in
      let ls_pending, req_view =
        model.Controller.transition cr None ls_none
      in
      (* FORGE REALNESS: the derived state is in the PENDING class and the
         transition that produced it really emitted a request. *)
      Alcotest.(check bool)
        "R2 forge: one transition from init lands in the PENDING class" true
        (Fc.vsts_pending_states ls_pending);
      Alcotest.(check bool) "R2 forge: and that transition emits a request"
        true
        (Option.is_some req_view);
      let m = req_for ~cid:controller_id ~id:forged_shared_rpc_id cr_key in
      let violating =
        forge ~in_flight:[]
          [ (cr_key, orc ~local_state:ls_pending ~pending:None) ]
      in
      let control =
        forge ~in_flight:[ m ]
          [ (cr_key, orc ~local_state:ls_pending ~pending:(Some m)) ]
      in
      Alcotest.(check bool)
        "R2 forge: the guard FIRES on the violating state (interesting)" true
        (r2.interesting violating);
      (* NEGATIVE CONTROL FIRST. *)
      Alcotest.(check bool)
        "R2 control: expected state WITH its pending request in flight \
         ACCEPTED"
        true (r2.holds control);
      Alcotest.(check bool)
        "R2 control: interesting fires there TOO (not clean-by-vacuity)" true
        (r2.interesting control);
      Alcotest.(check (list string)) "R2 control: violates NO member" []
        (violated_names control);
      (* SEMANTIC: the member REJECTS. *)
      Alcotest.(check bool)
        "R2 REJECTS an expected-state reconcile with NO pending request" false
        (r2.holds violating);
      Alcotest.(check (list string))
        "R2 is the ONLY member the forge violates" [ r2.name ]
        (violated_names violating);
      Alcotest.(check bool) "R2: the EXACT leg check REFUTES the forge" true
        (refuted (safety_of family (product violating))))
    registered_model

(* WHAT COULD MAKE THIS FAIL: the [false] check iff R4 accepts a
   none-expected-state reconcile that still HOLDS a pending request
   ([fun _ -> true]); the control iff R4 over-rejects the request-free shape.
   NOT the dual-by-entailment of the R2 test: R2's conclusion at its forge
   fails through [has_pending_req_msg]'s [~none:false] leg while R4's fails
   through [Option.is_none] - different members, different predicates,
   different local states (pending-class vs none-class), and each was
   independently reddened by trivializing ITS member's [holds]. *)
let test_r4_rejects_pending_req_at_none_state () =
  Alcotest.(check bool) "R4: the registered VSTS model exists" true
    (Option.is_some registered_model);
  Option.fold ~none:()
    ~some:(fun (model : Controller.reconcile_model) ->
      let ls_none = model.Controller.init () in
      (* FORGE REALNESS: init lands in the NONE class (also the init conjunct
         of the R2 side condition, here doing forge duty). *)
      Alcotest.(check bool) "R4 forge: init () lands in the NONE class" true
        (Fc.vsts_none_states ls_none);
      let m = req_for ~cid:controller_id ~id:forged_shared_rpc_id cr_key in
      (* The pending request is in flight with correct provenance, so R3
         holds and the forge isolates R4. *)
      let violating =
        forge ~in_flight:[ m ]
          [ (cr_key, orc ~local_state:ls_none ~pending:(Some m)) ]
      in
      let control =
        forge ~in_flight:[]
          [ (cr_key, orc ~local_state:ls_none ~pending:None) ]
      in
      Alcotest.(check bool)
        "R4 forge: the guard FIRES on the violating state (interesting)" true
        (r4.interesting violating);
      (* NEGATIVE CONTROL FIRST. *)
      Alcotest.(check bool)
        "R4 control: none-state reconcile with NO pending request ACCEPTED"
        true (r4.holds control);
      Alcotest.(check bool)
        "R4 control: interesting fires there TOO (not clean-by-vacuity)" true
        (r4.interesting control);
      Alcotest.(check (list string)) "R4 control: violates NO member" []
        (violated_names control);
      (* SEMANTIC: the member REJECTS. *)
      Alcotest.(check bool)
        "R4 REJECTS a none-expected-state reconcile still holding a pending \
         request"
        false (r4.holds violating);
      Alcotest.(check (list string))
        "R4 is the ONLY member the forge violates" [ r4.name ]
        (violated_names violating);
      Alcotest.(check bool) "R4: the EXACT leg check REFUTES the forge" true
        (refuted (safety_of family (product violating))))
    registered_model

(* ==== ME: the side-condition checkers' REJECTING directions ================= *)

(* WHAT COULD MAKE THIS FAIL: the first rejection iff the pending-checker's
   INIT conjunct is bypassed (the triple list is EMPTY, so nothing else can
   reject there); the second iff the none-checker's TRANSITION conjunct is
   bypassed (the probe triple lands in the pending class WITH a request, and
   the dual checker has no init conjunct - upstream's own asymmetry). Forcing
   either checker to [true] (ME) is exactly such a bypass and was SEEN to
   redden both. Not tautological: the accepting controls pass on the same
   probe, so each rejection is the checker discriminating, not a constant. *)
let test_me_side_condition_checkers_reject () =
  Alcotest.(check bool) "ME: the registered VSTS model exists" true
    (Option.is_some registered_model);
  Option.fold ~none:()
    ~some:(fun (model : Controller.reconcile_model) ->
      let cr = V_stateful_set.marshal (Scenario.vsts ~desired ()) in
      let ls_none = model.Controller.init () in
      let probe :
          (Dynamic_object.t * Value.t Io.response_view option * Value.t) list =
        [ (cr, None, ls_none) ]
      in
      let post, req_view = model.Controller.transition cr None ls_none in
      (* PROBE REALNESS. *)
      Alcotest.(check bool) "ME probe: init () lands in the NONE class" true
        (Fc.vsts_none_states ls_none);
      Alcotest.(check bool)
        "ME probe: its transition lands in the PENDING class" true
        (Fc.vsts_pending_states post);
      Alcotest.(check bool) "ME probe: and emits a request" true
        (Option.is_some req_view);
      (* ACCEPTING CONTROLS FIRST: the true instantiations pass over the
         probe, so the rejections below are discrimination, not a constant. *)
      Alcotest.(check bool)
        "ME control: pending-checker ACCEPTS the R2 instantiation on the probe"
        true
        (Rc.state_comes_with_a_pending_request model
           ~expected:Fc.vsts_pending_states probe);
      Alcotest.(check bool)
        "ME control: none-checker ACCEPTS the R4 instantiation on the probe"
        true
        (Rc.state_comes_with_no_pending_request model
           ~expected:Fc.vsts_none_states probe);
      (* THE REJECTING DIRECTIONS - the only observations of either checker's
         [false] path anywhere in the battery; what ME must lose. *)
      Alcotest.(check bool)
        "ME: pending-checker REJECTS the swapped instantiation via its INIT \
         conjunct (EMPTY triples: nothing else can reject)"
        false
        (Rc.state_comes_with_a_pending_request model
           ~expected:Fc.vsts_none_states []);
      Alcotest.(check bool)
        "ME: none-checker REJECTS the swapped instantiation via its \
         TRANSITION conjunct (the probe lands pending WITH a request)"
        false
        (Rc.state_comes_with_no_pending_request model
           ~expected:Fc.vsts_pending_states probe))
    registered_model

(* ==== the MA / M1 anchor: the live legs, violated NAMED not just None-ness ==
   Re-runs L0 and L1 through the leg function itself so the two MANUAL source
   mutations have a single test whose FAILURE OUTPUT identifies the row:
   under MA the [check string] prints the member that fired (R3's name = the
   headline confirmed; a P14 member's name = the §3 masking-trap harness
   bug); under M1 the semantic checks stay green and the states pin prints
   the shrunken graph (the P12 misattribution guard, spelled out). The pins
   are read from {!P15_witness} referentially - the single-source rule. *)

(* WHAT COULD MAKE THIS FAIL: any refutation of the family over either live
   leg graph (MA, SEEN), any leg non-decisiveness, or a graph-size drift
   (M1, SEEN via the states pin; also any seed/bound drift). Not entailed by
   [t_p15_reconcile_correspondence]'s leg tests in the direction that
   matters here: those assert [violated = None] as a BOOL, which on a red
   run reports only false - this anchor's [check string] is what makes a
   mutation run NAME the member, which §6's MA row requires observing. *)
let test_ma_m1_leg_anchor () =
  let l0 =
    Fc.check_reconcile_correspondence_under_faults ~depth bound
      P15_witness.zero_budget ~desired ~require_crash:false
  in
  let l1 =
    Fc.check_reconcile_correspondence_under_faults ~depth bound
      P15_witness.l1_budget ~desired ~require_crash:true
  in
  (* The violated NAMES first, as strings, so a red run prints the member. *)
  Alcotest.(check string) "MA/M1 anchor: L0 (control) violated names NOTHING"
    "<none>" (inv_name l0.violated);
  Alcotest.(check string)
    "MA/M1 anchor: L1 violated names NOTHING (a red here prints the firing \
     member: R3 = P15-B, any P14 name = the masking-trap harness bug)"
    "<none>" (inv_name l1.violated);
  (* Leg semantics. *)
  Alcotest.(check bool) "MA/M1 anchor: L0 clean" true (report_clean l0);
  Alcotest.(check bool) "MA/M1 anchor: L1 clean" true (report_clean l1);
  Alcotest.(check bool) "MA/M1 anchor: L0 decisive" true (report_decisive l0);
  Alcotest.(check bool) "MA/M1 anchor: L1 decisive" true (report_decisive l1);
  Alcotest.(check bool)
    "MA/M1 anchor: L1 crash REALLY taken (max_crashes_seen >= 1)" true
    (l1.max_crashes_seen >= 1);
  (* The graph pins LAST (the M1 detector - M1 shrinks, never refutes). *)
  Alcotest.(check int) "MA/M1 anchor: L0 states (pinned)" P15_witness.l0_states
    (report_states l0);
  Alcotest.(check int) "MA/M1 anchor: L1 states (pinned)" P15_witness.l1_states
    (report_states l1)

let () =
  Alcotest.run "p15_mutation"
    [
      ( "per_member_refutation",
        [
          Alcotest.test_case
            "R1 rejects two ongoing reconciles sharing a pending rpc_id \
             (distinct ids: clean)"
            `Quick test_r1_rejects_colliding_pending_ids;
          Alcotest.test_case
            "R2 rejects an expected-state reconcile with no pending request"
            `Quick test_r2_rejects_expected_state_without_pending_req;
          Alcotest.test_case
            "R4 rejects a none-state reconcile still holding a pending request"
            `Quick test_r4_rejects_pending_req_at_none_state;
        ] );
      ( "mb_r3_exclusivity",
        [
          Alcotest.test_case
            "R3 rejects the request and its matching response both in flight"
            `Quick test_r3_rejects_request_and_matching_response_both_in_flight;
        ] );
      ( "mc_r3_provenance",
        [
          Alcotest.test_case
            "R3 rejects a pending request with a foreign src" `Quick
            test_r3_rejects_foreign_src_pending_request;
        ] );
      ( "me_side_condition",
        [
          Alcotest.test_case
            "both checkers REJECT swapped instantiations (their false paths \
             observed)"
            `Quick test_me_side_condition_checkers_reject;
        ] );
      ( "ma_m1_anchor",
        [
          Alcotest.test_case
            "the live L0/L1 legs, violated NAMED (the manual rows' red \
             would print here)"
            `Quick test_ma_m1_leg_anchor;
        ] );
    ]

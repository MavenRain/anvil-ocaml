(* BUILD-SPEC-P16 §6 - confirm-by-mutation for the REQUEST/RESPONSE
   correspondence family (Q1 / Q2 / Q3 / Q5, two lists asserted separately).
   A clean, decisive [No_counterexample] from [t_p16_req_resp] is only
   evidence if the family would MOVE when what it checks breaks; on the true
   model every leg is clean, so the Refuted path would otherwise ship with
   ZERO observed-red coverage. Two forms of evidence, the P14/P15 split: the
   MANUAL real-source mutants MD / MS / MR / MA (documented below - applied
   with Edit, SEEN red or SEEN inert, reverted with Edit, never git checkout;
   only the green tree ships), and the AUTOMATED permanent per-member forges,
   whose reddening under the §6 assurance-side mutations MB / MC / ME (plus
   the supplementary S3 probe and the T1/T2 trivialisations) was SEEN and is
   recorded per row.

   ==== MD (MANUAL, message.ml:346; NOT shipped) - the headline ==============

   Mutant: [form_matched_err_resp_msg]'s [Create_request] arm fabricates
   [{ res = Ok cr.obj }] instead of [{ res = Error err }] (the request's own
   object echoed back as a SUCCESS body - the drop edge now counterfeits the
   api server's happy path).

   MEASURED effect (PREDICTION P16-C CONFIRMED): the Ld Matched leg flips
   clean -> Refuted with [violated = Some
   "key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req"]
   - Q5, BY NAME, at a [drops >= 1] state ({!test_md_converse_control}'s
   check-string printed it). Mechanism: the fabricated OK create response
   inherits the dropped request's [rpc_id], so it satisfies
   [resp_msg_matches_req_msg] against the reconciler's pending pod-create;
   the reconciler's [make_pod] object carries NO [metadata.namespace] (the
   api server would stamp it), so [Dynamic_object.object_ref] on the echoed
   body FAILS and the key-match consequent goes false - the port's
   disclosed result-valued-[object_ref] fail-loud arm is exactly what fires.
   The Ld Rv leg stayed CLEAN under MD - measured twice: this exe's Ld/Rv
   checks, and [t_p16_req_resp]'s ld_drop group run UNDER the mutant, where
   all eleven Ld/Rv semantic checks passed before Ld/Matched flipped (list
   separation: Q1/Q2 read only get responses). Every forge below stayed
   green. The §4.4 masking trap did NOT fire: the name is Q5's, no P14/P15
   member appeared.

   ==== MS (MANUAL, api_server.ml:491-495; NOT shipped) - measured INERT =====

   Mutant: [handle_update_request]'s non-noop write keeps [updated] (which
   carries the OLD [om.resource_version]) instead of stamping
   [with_resource_version s.resource_version_counter] - the §6 "write path
   reuses the old resource_version" row, sited on the PLAIN update path (the
   only write path whose sole issuer is the monkey: no shipped reconciler
   emits a plain [Update_request], BUILD-SPEC-P16 §2's Q4 evidence).

   MEASURED effect (PREDICTION P16-D's MS row REFUTED, twice over): NOTHING
   reddened - not the Lm leg, not the {!test_ms_lmv_probe} monkey-x-vct probe
   built for it, and the probe's pinned state count did not move; the FULL
   [t_p16_req_resp] battery (13 tests, all seven §4.6/probe graphs) also ran
   green under the mutant with every pin unmoved. Diagnosis,
   in strength order: (a) the mutation is DEAD CODE on every shipped graph -
   the monkey's candidate pods are the STORED pods themselves
   (cluster.ml:744-755), so its plain updates merge to [updated = old] and
   take the no-op branch before the stamping site; (b) even a live rv-reusing
   pod write could not refute Q2, whose OK-get-response premise only ever
   holds at PVC keys (the vct PVC arm is the port's sole [Get_request]
   producer) - key-disjoint from the monkey's pod writes. MS's discriminating
   duty is discharged by the Q2 FORGE instead, whose red-capability is SEEN
   under T2 below. A [Refuted] this mutant cannot produce was not dressed up:
   the row is recorded as a REAL negative (§8.4), same class as Q4's
   structural vacuity and measured the same way.

   ==== MR (MANUAL, api_server.ml:301; NOT shipped) ==========================

   Mutant: [handle_create_request]'s success branch keeps
   [resource_version_counter = s.resource_version_counter] (no bump; the
   stamp itself is untouched).

   MEASURED effect (the §6 MR row CONFIRMED): the L0v Rv leg flips clean ->
   Refuted with [violated = Some
   "object_in_ok_get_response_has_smaller_rv_than_etcd"] - Q1, BY NAME, in
   {!test_manual_anchor}'s check-string. Mechanism: the PVC is created at
   [rv = counter] and the counter no longer moves past it, so the OK get
   response's object rv is EQUAL to [s.api_server.resource_version_counter]
   and upstream's strict [<] fails - the exact boundary MC's forged witness
   pins ({!test_q1_forge}'s rv-equals-counter state). The Lmv probe reddened
   likewise, naming Q1 (every [vct:true] graph carries OK get responses).
   Every [vct:false] leg stayed clean (no OK get response exists there to
   violate, P16-E) with every pinned COUNT unmoved - {!test_md_converse_control}
   ran fully green under the mutant: the counter shift RELABELS those states
   without changing the graph's size, so not even the pins moved there.

   ==== MA (MANUAL, cluster.ml:316-320; NOT shipped) - the negative control ==

   Mutant: [restart_controller] ALSO resets the global rpc-id allocator
   ([rpc_id_allocator = Message.Rpc_id_allocator.init ()] added to the
   post-restart state) - P14's headline mutant, re-run against the P16
   family.

   MEASURED effect: refutes NOTHING in this family - the §6 row's REQUIRED
   negative, cross-phase consistent with P14 (where N1 catches it) and P15
   (where R3 catches it). Every violated-name check stayed ["<none>"], every
   clean check green, crash and monkey edges still taken; the ONLY red was
   the Lc states pin, and the graph SHRANK, 464 -> 452 measured on this run
   (the reset allocator re-issues low rpc ids post-restart, so product
   states the true model keeps distinct MERGE). That is the pin moving, not
   the family - the P15 M1 lesson, and why the anchor asserts names FIRST
   and pins LAST. The §4.4 masking-trap check was applied and passed: had a
   P14 name appeared in [violated], the lists would have been unioned
   somewhere (harness bug, not a finding).

   ==== the automated rows (each SEEN red under its §6 mutation) =============

   MB  forcing Q5's key-equality consequent true in
       req_resp_correspondence.ml ([|| true] on the fold's ok-arm) reddens
       {!test_q5_forge}'s REJECTS check and its leg check, and nothing else.
   MC  weakening Q1's [<] to [<=] reddens {!test_q1_forge}'s REJECTS check -
       observable ONLY because the forged witness has [rv = counter] EXACTLY
       (the P14 entailment lesson: [<] implies [<=], so any witness with
       [rv < counter] would be accepted by BOTH and discriminate nothing).
   ME  deleting Q3's [resp_msg_matches_req_msg] antecedent reddens
       {!test_q3_forge}'s NON-MATCHING control (the response formed off a
       DIFFERENT rpc id, accepted by the true member, rejected once the
       antecedent is gone) - an antecedent deletion STRENGTHENS, so the
       discriminator must be a control, not the violating state.
   S3  (supplementary, mirrors MB on Q3): forcing Q3's key-match consequent
       true reddens {!test_q3_forge}'s REJECTS check - Q3's acceptance
       direction seen red, which ME alone cannot show.
   T1/T2 trivialising Q1's / Q2's [holds] to [fun _ -> true] reddens exactly
       {!test_q1_forge} / {!test_q2_forge} (the battery-hole check: no
       member's [holds] can be blinded without a specific red). Q3/Q5 cannot
       be LITERALLY trivialised - SEEN: the Q5 attempt is rejected by the
       build gate itself ([E unused-value-declaration
       is_ok_create_response_and_matches_key], the orphaned private helper -
       an accidental guardrail worth recording); their acceptance directions
       are SEEN red under S3/MB, the same direction a trivialisation opens.

   TAUTOLOGY/ENTAILMENT AUDIT (the P14 lesson): every forged REJECTS check
   fails iff that member's [holds] accepts the forged violation (SEEN under
   MB / MC / S3 / T1 / T2); every control's ACCEPTED check fails iff [holds]
   over-rejects (SEEN under ME for Q3's non-matching control); every
   [violated_names = [exactly one]] fails if ANY other member moves on that
   forge. No assertion is entailed by another: each violating/control pair
   differs in exactly one discriminating field (Q1 rv-vs-counter, Q2 body
   equality, Q3 response key, Q5 response key), each forge's antecedent
   realness is asserted separately from its consequent (so no check is
   vacuously green), and MC's witness sits ON the [<]/[<=] boundary. The
   [interesting] assertions keep every forge exercise-proof: a forge whose
   premise silently failed would be accepted by the TRUE member and redden
   its REJECTS check immediately.

   Firewall honoured: List/Option/fold combinators only, no loop keywords,
   exhaustive matches on every finite sum (the 9-arm response classifier
   below names all arms), no two-arm match on option/result, no
   [raise/assert/failwith/Option.get], Alcotest as the sanctioned failure
   primitive. Leg pins are read from {!P16_witness}, never re-typed. The
   knife-edge / slice helpers are THIS exe's own copies: [t_p16_req_resp]'s
   are deliberately file-local (BUILD-SPEC-P16 §4.7 keeps every exe
   self-contained on its probes). *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Rr = Anvil_assurance.Req_resp_correspondence

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P16_witness.witness_desired
let depth : int = P16_witness.witness_depth
let bound : Bound.t = P16_witness.p16_bound ~desireds:[ desired ]

(* The four members EXACTLY as the legs instantiate them (Q2 over the leg's
   own bound - a different bound here would forge evidence about some other
   closure). *)

let q1 : Invariants.invariant =
  Rr.object_in_ok_get_response_has_smaller_rv_than_etcd

let q2 : Invariants.invariant =
  Rr.object_in_ok_get_resp_is_same_as_etcd_with_same_rv bound

let q3 : Invariants.invariant =
  Rr.key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_pending_req
    ~controller_id

let q5 : Invariants.invariant =
  Rr.key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req
    ~controller_id

let rv_family : Invariants.invariant list = Rr.rv_family bound
let matched_family : Invariants.invariant list = Rr.matched_family ~controller_id

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

(* Every P16 member the state violates, by name, each member probed
   INDIVIDUALLY - a per-member sweep, not a unioned leg (the §4.4 masking
   discipline forbids unioning the LISTS in a checked conjunction; isolation
   needs exactly this pointwise form). [[]] is "all four hold"; a singleton
   is "exactly this member broke" - what makes a forge an ISOLATION. *)
let members : (string * Invariants.invariant) list =
  [ ("Q1", q1); ("Q2", q2); ("Q3", q3); ("Q5", q5) ]

let violated_names (s : Cluster.cluster_state) : string list =
  List.filter_map
    (fun ((_, i) : string * Invariants.invariant) ->
      if i.holds s then None else Some i.name)
    members

(* ---- the exact-leg-check harness (the t_p14/t_p15 singleton pattern) ------- *)

let singleton_reach (f : Fc.faulted) : Fc.faulted Mc.reachable =
  Mc.explore ~depth:1
    ~successors:(fun (_ : Fc.faulted) -> [])
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash ~init:[ f ]

(* One LIST at a time, exactly as the leg asserts it - never the union. *)
let safety_of (invs : Invariants.invariant list) (f : Fc.faulted) :
    Fc.faulted Mc.outcome =
  let conj = Invariants.conjunction invs in
  Mc.check_safety (singleton_reach f)
    ~inv:(fun (x : Fc.faulted) -> conj x.cs)
    ~equal:Fc.faulted_equal

(* A POST-DROP product state around a forged [cluster_state] (this phase's
   headline dimension; the counters are inert to every [holds], the point is
   that the forges run through the SAME [Fc.faulted] wrapper the leg checks). *)
let product (cs : Cluster.cluster_state) : Fc.faulted =
  { Fc.cs; crashes = 0; drops = 1; monkeys = 0 }

(* ==== the forge ============================================================= *)

(* Forge INPUTS (not measured pins - {!P16_witness} pins only measured
   numbers; exactly one file consumes these). *)
let forged_rpc_id_a : int = 21
let forged_rpc_id_b : int = 22
let forge_ns : string = "ns"

let cr_key : Common.object_ref =
  {
    Common.kind = Common.Custom_resource "VStatefulSet";
    name = "vsts";
    namespace = forge_ns;
  }

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ()

(* An UNDECODABLE local state: no P16 member reads [local_state], so [`Null]
   keeps the entry inert (the P15 forge's device, reused). *)
let null_local : Value.t = Value.of_json `Null

let orc ~(pending : Message.t option) : Controller.ongoing_reconcile =
  {
    Controller.triggering_cr =
      V_stateful_set.marshal (Scenario.vsts ~desired ());
    pending_req_msg = pending;
    local_state = null_local;
    reconcile_id = 0;
  }

(* [seed] with the network, ETCD ([resources] + counter - the fields Q1/Q2
   guard on, which the P15 forge never had to touch) and the controller's
   [ongoing_reconciles] all REPLACED; every other field preserved. Total, no
   [Option.get]. *)
let forge ~(resources : (Common.object_ref * Dynamic_object.t) list)
    ~(rv_counter : int) ~(in_flight : Message.t list)
    (ongoing : (Common.object_ref * Controller.ongoing_reconcile) list) :
    Cluster.cluster_state =
  let stored =
    List.fold_left
      (fun (m : Dynamic_object.t Object_ref_map.t)
           ((k, o) : Common.object_ref * Dynamic_object.t) ->
        Object_ref_map.add k o m)
      Object_ref_map.empty resources
  in
  let base =
    {
      seed with
      Cluster.network = { Network.in_flight = Message.Pool.of_list in_flight };
      api_server =
        {
          Api_server.resources = stored;
          uid_counter = seed.Cluster.api_server.Api_server.uid_counter;
          resource_version_counter = rv_counter;
        };
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

(* A forged object of POD kind (the kind is inert to every member; Pod is the
   kind the phase's fault dimensions actually touch). [rv]/[namespace] are
   the discriminating fields, so both are explicit at every call site. *)
let mk_obj ~(name : string option) ~(namespace : string option)
    ~(rv : int option) ~(spec : Value.t) : Dynamic_object.t =
  let metadata =
    {
      (Object_meta.default ()) with
      Object_meta.name;
      namespace;
      resource_version = Option.map Common.Resource_version.of_int rv;
    }
  in
  Dynamic_object.make ~kind:Common.Pod ~metadata ~spec
    ~status:(Value.of_json `Null)

(* An api GET request sent AS the [cr_key] reconcile (provenance is not read
   by this family; the request only exists so the RESPONSE former inherits a
   real rpc id and a real src/dst flip). *)
let get_req ~(id : int) (key : Common.object_ref) : Message.t =
  Message.form_msg
    ~src:(Message.Controller (controller_id, cr_key))
    ~dst:Message.Api_server ~rpc_id:(Message.Rpc_id.of_int id)
    ~content:(Message.get_req_msg_content key)

let create_req ~(id : int) (obj : Dynamic_object.t) : Message.t =
  Message.form_msg
    ~src:(Message.Controller (controller_id, cr_key))
    ~dst:Message.Api_server ~rpc_id:(Message.Rpc_id.of_int id)
    ~content:(Message.create_req_msg_content forge_ns obj)

let pool_size (s : Cluster.cluster_state) : int =
  Message.Pool.cardinal (Cluster.in_flight s)

(* ==== Q1: OK get response rv vs the etcd counter (MC's row) ================= *)

let q1_counter : int = 2
let q1_key : Common.object_ref =
  { Common.kind = Common.Pod; name = "q1-pod"; namespace = forge_ns }

let q1_resp ~(rv : int option) : Message.t =
  Message.form_get_resp_msg
    (get_req ~id:forged_rpc_id_a q1_key)
    ({
       res =
         Ok
           (mk_obj ~name:(Some "q1-pod") ~namespace:(Some forge_ns) ~rv
              ~spec:(Value.of_json `Null));
     }
      : Api_method.get_response)

(* rv = counter EXACTLY: violates [<] while satisfying [<=] - the ONLY shape
   MC ([<] weakened to [<=]) can be observed on (the P14 entailment lesson). *)
let q1_violating : Cluster.cluster_state =
  forge ~resources:[] ~rv_counter:q1_counter
    ~in_flight:[ q1_resp ~rv:(Some q1_counter) ]
    []

(* rv ABSENT: upstream's [resource_version is Some] conjunct failing is a
   REFUTATION, not vacuity (the ported [~none:false] arm, seen rejecting). *)
let q1_none_rv : Cluster.cluster_state =
  forge ~resources:[] ~rv_counter:q1_counter ~in_flight:[ q1_resp ~rv:None ] []

let q1_control : Cluster.cluster_state =
  forge ~resources:[] ~rv_counter:q1_counter
    ~in_flight:[ q1_resp ~rv:(Some (q1_counter - 1)) ]
    []

(* WHAT COULD MAKE THIS FAIL: the REJECTS checks iff Q1's [holds] accepts an
   rv-equals-counter (or rv-less) response body - SEEN red under MC and under
   T1; the control iff [<] over-rejects a strictly-smaller rv; the isolation
   lists iff any other member moves on these forges. Not entailed by any
   other test: no other forge plants an OK GET response with a controlled
   counter. *)
let test_q1_forge () =
  (* THE FORGE IS REAL, checked before anything is concluded from it. *)
  Alcotest.(check int) "Q1 forge: exactly ONE in-flight message" 1
    (pool_size q1_violating);
  Alcotest.(check int)
    "Q1 forge (MC audit): the violating rv EQUALS the etcd counter - the \
     [<]/[<=] boundary itself"
    q1_counter
    q1_violating.Cluster.api_server.Api_server.resource_version_counter;
  Alcotest.(check bool)
    "Q1 forge: interesting fires (an OK get response is REALLY in flight)"
    true (q1.interesting q1_violating);
  (* NEGATIVE CONTROL FIRST, so the discriminating direction is SEEN. *)
  Alcotest.(check bool) "Q1 control: rv STRICTLY below the counter ACCEPTED"
    true (q1.holds q1_control);
  Alcotest.(check bool)
    "Q1 control: interesting fires there TOO (not clean-by-vacuity)" true
    (q1.interesting q1_control);
  Alcotest.(check (list string)) "Q1 control: violates NO member" []
    (violated_names q1_control);
  (* SEMANTIC: the member REJECTS - on the exact boundary. *)
  Alcotest.(check bool)
    "Q1 REJECTS an OK get response whose object rv EQUALS the counter" false
    (q1.holds q1_violating);
  Alcotest.(check bool)
    "Q1 REJECTS an OK get response with NO object rv (fail-loud arm)" false
    (q1.holds q1_none_rv);
  Alcotest.(check (list string))
    "Q1 is the ONLY member the boundary forge violates" [ q1.name ]
    (violated_names q1_violating);
  Alcotest.(check (list string))
    "Q1 is the ONLY member the none-rv forge violates" [ q1.name ]
    (violated_names q1_none_rv);
  Alcotest.(check bool) "Q1: the EXACT Rv leg check REFUTES the forge" true
    (refuted (safety_of rv_family (product q1_violating)))

(* ==== Q2: same key, same rv, DIFFERENT object (the T2-coverage forge) =======
   No named §6 row weakens Q2's body equality, which is exactly why the
   battery needs this forge: without it, trivialising Q2's [holds] would leave
   every test green (MS, its nominal partner, is measured INERT - see the
   header). *)

let q2_key : Common.object_ref =
  { Common.kind = Common.Pod; name = "q2-pod"; namespace = forge_ns }

let q2_rv : int = 1
let q2_counter : int = 2

let q2_obj ~(rv : int) ~(spec : string) : Dynamic_object.t =
  mk_obj ~name:(Some "q2-pod") ~namespace:(Some forge_ns) ~rv:(Some rv)
    ~spec:(Value.of_json (`String spec))

let q2_stored : Dynamic_object.t = q2_obj ~rv:q2_rv ~spec:"stored"

let q2_resp (obj : Dynamic_object.t) : Message.t =
  Message.form_get_resp_msg
    (get_req ~id:forged_rpc_id_a q2_key)
    ({ res = Ok obj } : Api_method.get_response)

(* Same key, same rv, divergent spec: exactly upstream's forbidden shape. The
   response rv stays STRICTLY below the counter so Q1 holds and the forge
   isolates Q2. *)
let q2_violating : Cluster.cluster_state =
  forge
    ~resources:[ (q2_key, q2_stored) ]
    ~rv_counter:q2_counter
    ~in_flight:[ q2_resp (q2_obj ~rv:q2_rv ~spec:"divergent") ]
    []

let q2_control_identical : Cluster.cluster_state =
  forge
    ~resources:[ (q2_key, q2_stored) ]
    ~rv_counter:q2_counter
    ~in_flight:[ q2_resp q2_stored ]
    []

(* Divergent body but a DIFFERENT rv: Q2's rv-equality premise fails, so the
   member must ACCEPT (the premise gate, asserted as a gate: [interesting]
   goes false here). *)
let q2_control_rv_gap : Cluster.cluster_state =
  forge
    ~resources:[ (q2_key, q2_stored) ]
    ~rv_counter:q2_counter
    ~in_flight:[ q2_resp (q2_obj ~rv:(q2_rv - 1) ~spec:"divergent") ]
    []

(* WHAT COULD MAKE THIS FAIL: the REJECTS check iff Q2 accepts two same-key
   same-rv objects with different bodies (SEEN red under T2); the identical
   control iff the [Dynamic_object.equal] consequent over-rejects the true
   shape; the rv-gap control iff the rv-equality premise stops gating; the
   isolation list iff any other member moves. The [interesting] pair proves
   the closure VISITED the key (Q2's own-bound-keys exercise rule). *)
let test_q2_forge () =
  (* THE FORGE IS REAL. *)
  Alcotest.(check int) "Q2 forge: the stored object is REALLY in etcd" 1
    (Object_ref_map.cardinal
       q2_violating.Cluster.api_server.Api_server.resources);
  Alcotest.(check bool)
    "Q2 forge: interesting fires (same key, same rv, key VISITED by the \
     bound closure)"
    true (q2.interesting q2_violating);
  Alcotest.(check bool)
    "Q2 forge: Q1 holds here (response rv strictly below the counter - the \
     isolation device)"
    true (q1.holds q2_violating);
  (* NEGATIVE CONTROLS FIRST. *)
  Alcotest.(check bool)
    "Q2 control: the IDENTICAL object at the same rv ACCEPTED" true
    (q2.holds q2_control_identical);
  Alcotest.(check bool)
    "Q2 control: interesting fires there TOO (not clean-by-vacuity)" true
    (q2.interesting q2_control_identical);
  Alcotest.(check bool)
    "Q2 rv-gap control: a divergent body at a DIFFERENT rv ACCEPTED (premise \
     gates)"
    true
    (q2.holds q2_control_rv_gap);
  Alcotest.(check bool)
    "Q2 rv-gap control: and interesting does NOT fire (the gate, observed)"
    false
    (q2.interesting q2_control_rv_gap);
  Alcotest.(check (list string)) "Q2 controls: violate NO member" []
    (List.append
       (violated_names q2_control_identical)
       (violated_names q2_control_rv_gap));
  (* SEMANTIC: the member REJECTS. *)
  Alcotest.(check bool)
    "Q2 REJECTS a same-key same-rv response body that DIFFERS from etcd"
    false (q2.holds q2_violating);
  Alcotest.(check (list string)) "Q2 is the ONLY member the forge violates"
    [ q2.name ] (violated_names q2_violating);
  Alcotest.(check bool) "Q2: the EXACT Rv leg check REFUTES the forge" true
    (refuted (safety_of rv_family (product q2_violating)))

(* ==== Q3: matched OK get response with the WRONG key (ME's row + S3) ======== *)

let q3_target_key : Common.object_ref =
  { Common.kind = Common.Pod; name = "q3-pod"; namespace = forge_ns }

let q3_pending : Message.t = get_req ~id:forged_rpc_id_a q3_target_key

let q3_body ~(name : string) : Dynamic_object.t =
  mk_obj ~name:(Some name) ~namespace:(Some forge_ns) ~rv:(Some 1)
    ~spec:(Value.of_json `Null)

let q3_resp_matching (obj : Dynamic_object.t) : Message.t =
  Message.form_get_resp_msg q3_pending
    ({ res = Ok obj } : Api_method.get_response)

(* Formed off a DIFFERENT request (rpc id b), so it does NOT match the
   pending request: the ME discriminator (deleting the matching antecedent
   makes Q3 reject THIS state and redden the control below). *)
let q3_resp_foreign : Message.t =
  Message.form_get_resp_msg
    (get_req ~id:forged_rpc_id_b q3_target_key)
    ({ res = Ok (q3_body ~name:"q3-other") } : Api_method.get_response)

let q3_with (msgs : Message.t list) : Cluster.cluster_state =
  forge ~resources:[] ~rv_counter:2 ~in_flight:msgs
    [ (cr_key, orc ~pending:(Some q3_pending)) ]

let q3_violating : Cluster.cluster_state =
  q3_with [ q3_resp_matching (q3_body ~name:"q3-other") ]

let q3_control_right_key : Cluster.cluster_state =
  q3_with [ q3_resp_matching (q3_body ~name:"q3-pod") ]

let q3_control_nonmatching : Cluster.cluster_state = q3_with [ q3_resp_foreign ]

(* WHAT COULD MAKE THIS FAIL: the REJECTS check iff Q3 accepts a MATCHED OK
   get response carrying the wrong key (SEEN red under S3); the right-key
   control iff the key consequent over-rejects the true shape; the
   non-matching control iff the matching ANTECEDENT stops gating - exactly
   ME, SEEN red there (an antecedent deletion strengthens, so the control is
   the only place it can show). *)
let test_q3_forge () =
  (* THE FORGE IS REAL. *)
  Alcotest.(check int) "Q3 forge: exactly ONE ongoing reconcile planted" 1
    (Object_ref_map.cardinal
       (Cluster.ongoing_reconciles q3_violating controller_id));
  Alcotest.(check bool)
    "Q3 forge: the matched response REALLY matches the pending request" true
    (Message.resp_msg_matches_req_msg
       (q3_resp_matching (q3_body ~name:"q3-other"))
       q3_pending);
  Alcotest.(check bool)
    "Q3 forge (ME audit): the foreign response REALLY does NOT match" false
    (Message.resp_msg_matches_req_msg q3_resp_foreign q3_pending);
  Alcotest.(check bool)
    "Q3 forge: interesting fires (a matched OK get response exists)" true
    (q3.interesting q3_violating);
  (* NEGATIVE CONTROLS FIRST. *)
  Alcotest.(check bool)
    "Q3 control: the matched response carrying the RIGHT key ACCEPTED" true
    (q3.holds q3_control_right_key);
  Alcotest.(check bool)
    "Q3 control: interesting fires there TOO (not clean-by-vacuity)" true
    (q3.interesting q3_control_right_key);
  Alcotest.(check bool)
    "Q3 control: a NON-matching wrong-key response ACCEPTED (the antecedent \
     gates; ME reddens exactly this check)"
    true
    (q3.holds q3_control_nonmatching);
  Alcotest.(check (list string)) "Q3 controls: violate NO member" []
    (List.append
       (violated_names q3_control_right_key)
       (violated_names q3_control_nonmatching));
  (* SEMANTIC: the member REJECTS. *)
  Alcotest.(check bool)
    "Q3 REJECTS a matched OK get response whose key differs from the pending \
     request's"
    false (q3.holds q3_violating);
  Alcotest.(check (list string)) "Q3 is the ONLY member the forge violates"
    [ q3.name ] (violated_names q3_violating);
  Alcotest.(check bool)
    "Q3: the EXACT Matched leg check REFUTES the forge" true
    (refuted (safety_of matched_family (product q3_violating)))

(* ==== Q5: matched OK create response with the WRONG key (MB's row) ========== *)

(* The pending create request's object mirrors the reconciler's own
   [make_pod] shape: name PRESENT (Q5's name-is-Some antecedent), namespace
   ABSENT on the object (the api server stamps it; the request's [namespace]
   FIELD carries it) - the very asymmetry MD's measured refutation runs on. *)
let q5_req_obj : Dynamic_object.t =
  mk_obj ~name:(Some "q5-pod") ~namespace:None ~rv:None
    ~spec:(Value.of_json `Null)

let q5_pending : Message.t = create_req ~id:forged_rpc_id_a q5_req_obj

let q5_body ~(name : string) : Dynamic_object.t =
  mk_obj ~name:(Some name) ~namespace:(Some forge_ns) ~rv:(Some 1)
    ~spec:(Value.of_json `Null)

let q5_resp (res : (Dynamic_object.t, Api_method.api_error) result) : Message.t
    =
  Message.form_create_resp_msg q5_pending
    ({ res } : Api_method.create_response)

let q5_with (msgs : Message.t list) : Cluster.cluster_state =
  forge ~resources:[] ~rv_counter:2 ~in_flight:msgs
    [ (cr_key, orc ~pending:(Some q5_pending)) ]

let q5_violating : Cluster.cluster_state =
  q5_with [ q5_resp (Ok (q5_body ~name:"q5-other")) ]

let q5_control_right_key : Cluster.cluster_state =
  q5_with [ q5_resp (Ok (q5_body ~name:"q5-pod")) ]

(* The drop leg's REAL shape: an Error body matching the pending request -
   Q5's [is_ok] antecedent gates it out (P16-C's knife-edge conjunct,
   observed here at unit scale; [interesting] goes false). *)
let q5_control_error_body : Cluster.cluster_state =
  q5_with [ q5_resp (Error Api_method.Timeout) ]

(* WHAT COULD MAKE THIS FAIL: the REJECTS check iff Q5 accepts a matched OK
   create response carrying the wrong key - SEEN red under MB; the right-key
   control iff the key consequent over-rejects (its key equality runs through
   [create_request_key], i.e. the REQUEST's namespace field against the
   BODY's stamped namespace - the same projection the live leg uses); the
   error-body control iff the [is_ok] antecedent stops gating. All three
   antecedents are asserted real separately, so none of the three checks can
   go green by premise failure. *)
let test_q5_forge () =
  (* THE FORGE IS REAL. *)
  Alcotest.(check bool)
    "Q5 forge: the pending create's object name IS Some (the name-is-Some \
     antecedent)"
    true
    (Option.is_some (Object_meta.name (Dynamic_object.metadata q5_req_obj)));
  Alcotest.(check bool)
    "Q5 forge: the OK response REALLY matches the pending request" true
    (Message.resp_msg_matches_req_msg
       (q5_resp (Ok (q5_body ~name:"q5-other")))
       q5_pending);
  (* The ERROR-bodied control's OWN matching antecedent, asserted separately.
     Without it, that control's two checks ([holds] true, [interesting] false)
     are both entailed by [is_ok = false] alone and cannot distinguish
     "matched but is_ok-gated" - the drop leg's real shape, P16-C's knife-edge
     conjunct at unit scale - from a silent match failure. That is exactly the
     borrowed-witness shape this file's audit paragraph claims to exclude. *)
  Alcotest.(check bool)
    "Q5 control: the ERROR-bodied response REALLY matches the pending request \
     (so its checks observe the is_ok gate, not a match failure)"
    true
    (Message.resp_msg_matches_req_msg
       (q5_resp (Error Api_method.Timeout))
       q5_pending);
  Alcotest.(check bool)
    "Q5 forge: interesting fires (a matched OK create response against a \
     NAMED pending create)"
    true (q5.interesting q5_violating);
  (* NEGATIVE CONTROLS FIRST. *)
  Alcotest.(check bool)
    "Q5 control: the matched OK response carrying the RIGHT key ACCEPTED" true
    (q5.holds q5_control_right_key);
  Alcotest.(check bool)
    "Q5 control: interesting fires there TOO (not clean-by-vacuity)" true
    (q5.interesting q5_control_right_key);
  Alcotest.(check bool)
    "Q5 control: the ERROR-bodied matched response ACCEPTED (the is_ok gate \
     - the drop leg's real shape)"
    true
    (q5.holds q5_control_error_body);
  Alcotest.(check bool)
    "Q5 control: and interesting does NOT fire on the Error body (the gate, \
     observed)"
    false
    (q5.interesting q5_control_error_body);
  Alcotest.(check (list string)) "Q5 controls: violate NO member" []
    (List.append
       (violated_names q5_control_right_key)
       (violated_names q5_control_error_body));
  (* SEMANTIC: the member REJECTS. *)
  Alcotest.(check bool)
    "Q5 REJECTS a matched OK create response whose key differs from the \
     pending create's"
    false (q5.holds q5_violating);
  Alcotest.(check (list string)) "Q5 is the ONLY member the forge violates"
    [ q5.name ] (violated_names q5_violating);
  Alcotest.(check bool)
    "Q5: the EXACT Matched leg check REFUTES the forge" true
    (refuted (safety_of matched_family (product q5_violating)))

(* ==== the live legs (the manual rows' observation points) ===================
   Every leg call is EXACTLY [t_p16_req_resp]'s; every pin is read from
   {!P16_witness} referentially. Violated NAMES are asserted FIRST as strings
   (a red run PRINTS the firing member), semantics next, states pins LAST
   (the P15 M1 lesson: a mutant can move the pin without touching the
   family). *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) ~(list_select : Fc.list_select)
    ~(require_fault : bool) : Fc.fault_report =
  Fc.check_req_resp_under_faults ~depth ~req_drop ~pod_monkey ~vct bound budget
    ~desired ~list_select ~require_fault

let leg_seed ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool) :
    Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ~vct ()

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (leg_seed ~req_drop ~pod_monkey ~vct) ]

(* ---- slices + probes: THIS exe's own copies (see the header) --------------- *)

let all_states (_ : Fc.faulted) : bool = true
let post_drop (f : Fc.faulted) : bool = f.drops >= 1
let post_monkey (f : Fc.faulted) : bool = f.monkeys >= 1

let fault_free (f : Fc.faulted) : bool =
  f.crashes = 0 && f.drops = 0 && f.monkeys = 0

let fires (reach : Fc.faulted Mc.reachable) ~(slice : Fc.faulted -> bool)
    (i : Invariants.invariant) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f && i.Invariants.interesting f.cs)

(* [Error]-bodied, exhaustively over all NINE response arms. *)
let response_is_error (r : Api_method.api_response) : bool =
  let err_obj (res : (Dynamic_object.t, Api_method.api_error) result) : bool =
    Result.fold
      ~ok:(fun (_ : Dynamic_object.t) -> false)
      ~error:(fun (_ : Api_method.api_error) -> true)
      res
  in
  let err_list (res : (Dynamic_object.t list, Api_method.api_error) result) :
      bool =
    Result.fold
      ~ok:(fun (_ : Dynamic_object.t list) -> false)
      ~error:(fun (_ : Api_method.api_error) -> true)
      res
  in
  let err_unit (res : (unit, Api_method.api_error) result) : bool =
    Result.fold
      ~ok:(fun (() : unit) -> false)
      ~error:(fun (_ : Api_method.api_error) -> true)
      res
  in
  match r with
  | Api_method.Get_response { res } -> err_obj res
  | Api_method.List_response { res } -> err_list res
  | Api_method.Create_response { res } -> err_obj res
  | Api_method.Delete_response { res } -> err_unit res
  | Api_method.Update_response { res } -> err_obj res
  | Api_method.Update_status_response { res } -> err_obj res
  | Api_method.Get_then_delete_response { res } -> err_unit res
  | Api_method.Get_then_update_response { res } -> err_obj res
  | Api_method.Get_then_update_status_response { res } -> err_obj res

let matches_some_pending (cs : Cluster.cluster_state) (m : Message.t) : bool =
  Object_ref_map.fold
    (fun (_ : Common.object_ref) (rs : Controller.ongoing_reconcile)
         (acc : bool) ->
      acc
      || Option.fold ~none:false
           ~some:(fun (req : Message.t) ->
             Message.resp_msg_matches_req_msg m req)
           rs.Controller.pending_req_msg)
    (Cluster.ongoing_reconciles cs controller_id)
    false

let knife_edge_state (cs : Cluster.cluster_state) : bool =
  List.exists
    (fun (m : Message.t) ->
      (match m.Message.content with
      | Message.Api_response r -> response_is_error r
      | Message.Api_request _ | Message.External_request _
      | Message.External_response _ ->
          false)
      && matches_some_pending cs m)
    (Message.Pool.distinct (Cluster.in_flight cs))

let knife_edge (reach : Fc.faulted Mc.reachable) ~(slice : Fc.faulted -> bool)
    : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f && knife_edge_state f.cs)

(* ==== MD's converse control =================================================
   The UNMUTATED Ld legs must be clean FOR THE STATED REASON: the drop edge
   REALLY taken, and the fabricated matched responses present in exactly the
   [drops >= 1] slice with [Error] bodies (the knife-edge). Gated on the
   SLICE, never on the bare knife-edge predicate: real Error replies match
   pending with ZERO drops elsewhere (Lc 4, Lm 24, L0v 4, Ldv fault-free 8 -
   the witness's MD-converse caveat). *)

(* WHAT COULD MAKE THIS FAIL: MD (SEEN - the violated string prints Q5's
   name and the clean checks flip), any drop-edge regression
   ([max_drops_seen] pin), any knife-edge drift (the 384 / 0 slice pins), or
   a graph drift (states pins, LAST). *)
let test_md_converse_control () =
  let ld_m =
    leg ~req_drop:true ~pod_monkey:false ~vct:false P16_witness.ld_budget
      ~list_select:Fc.Matched_list ~require_fault:true
  in
  let ld_rv =
    leg ~req_drop:true ~pod_monkey:false ~vct:false P16_witness.ld_budget
      ~list_select:Fc.Rv_list ~require_fault:true
  in
  (* Violated NAMES first: under MD the Matched red prints Q5 = P16-C
     confirmed; any P14/P15 name = the §4.4 masking-trap harness bug. *)
  Alcotest.(check string)
    "MD converse: Ld/Matched violated names NOTHING (a red here PRINTS the \
     member; Q5 = the predicted P16-C flip)"
    "<none>" (inv_name ld_m.violated);
  Alcotest.(check string)
    "MD converse: Ld/Rv violated names NOTHING (list separation: MD must \
     not touch the rv leg)"
    "<none>" (inv_name ld_rv.violated);
  (* Leg semantics. *)
  Alcotest.(check bool) "MD converse: Ld/Matched clean" true
    (report_clean ld_m);
  Alcotest.(check bool) "MD converse: Ld/Rv clean" true (report_clean ld_rv);
  Alcotest.(check bool) "MD converse: Ld/Matched decisive" true
    (report_decisive ld_m);
  (* The stated reason, half one: the drop edge REALLY taken. *)
  Alcotest.(check bool)
    "MD converse: drop edge REALLY taken (max_drops_seen >= 1)" true
    (ld_m.max_drops_seen >= 1);
  Alcotest.(check int) "MD converse: max_drops_seen (pinned)"
    P16_witness.ld_max_drops_seen ld_m.max_drops_seen;
  (* The stated reason, half two: the fabricated matched-Error responses are
     REALLY there, in exactly the drops>=1 slice. *)
  let reach =
    reach_of ~req_drop:true ~pod_monkey:false ~vct:false P16_witness.ld_budget
  in
  Alcotest.(check int)
    "MD converse: replica graph = the Matched leg's graph (replica faithful)"
    (report_states ld_m) (Mc.states_seen reach);
  Alcotest.(check int)
    "MD converse: knife-edge on the drops>=1 slice (pinned - the matching \
     premise reached, ONLY the is_ok conjunct false)"
    P16_witness.knife_edge_ld
    (knife_edge reach ~slice:post_drop);
  Alcotest.(check int)
    "MD converse: knife-edge on the FAULT-FREE slice = 0 (on THIS graph the \
     knife-edge is entirely drop-attributable)"
    0
    (knife_edge reach ~slice:fault_free);
  (* Graph pins LAST. *)
  Alcotest.(check int) "MD converse: Ld states (pinned)" P16_witness.ld_states
    (report_states ld_m);
  Alcotest.(check int) "MD converse: Ld/Rv states (same product graph)"
    P16_witness.ld_states (report_states ld_rv)

(* ==== MS's Lmv probe ========================================================
   The §6 MS row names Lm, but Q2's interesting is MEASURED 0 on Lm at
   [vct:false] (the witness's disclosed matrix gap) - so the probe re-sites
   the observation where Q2 genuinely fires under a real monkey edge:
   [~pod_monkey:true ~vct:true], budget {0;0;1}. Its pins live in
   {!P16_witness}'s Lmv block (added by this stage, single-sourced). *)

(* WHAT COULD MAKE THIS FAIL: an MS-shaped refutation (the violated string
   would print Q2 - NOT seen, measured inert; see the header), monkey-edge
   vacuity, Q2 going quietly vacuous on this graph (the fires checks), or
   graph drift (the states pin, LAST - also the liveness detector that shows
   MS never even moved this graph). *)
let test_ms_lmv_probe () =
  let lmv_rv =
    leg ~req_drop:false ~pod_monkey:true ~vct:true P16_witness.lm_budget
      ~list_select:Fc.Rv_list ~require_fault:true
  in
  Alcotest.(check string)
    "MS probe: Lmv/Rv violated names NOTHING (an MS red would PRINT Q2 here)"
    "<none>" (inv_name lmv_rv.violated);
  Alcotest.(check bool) "MS probe: Lmv/Rv clean" true (report_clean lmv_rv);
  Alcotest.(check bool) "MS probe: Lmv/Rv decisive" true
    (report_decisive lmv_rv);
  Alcotest.(check bool)
    "MS probe: monkey edge REALLY taken (max_monkeys_seen >= 1)" true
    (lmv_rv.max_monkeys_seen >= 1);
  Alcotest.(check int) "MS probe: max_monkeys_seen (pinned)"
    P16_witness.lmv_max_monkeys_seen lmv_rv.max_monkeys_seen;
  let reach =
    reach_of ~req_drop:false ~pod_monkey:true ~vct:true P16_witness.lm_budget
  in
  Alcotest.(check int)
    "MS probe: replica graph = the leg's graph (replica faithful)"
    (report_states lmv_rv) (Mc.states_seen reach);
  (* Q2 genuinely fires on this graph, INCLUDING post-monkey - the matrix
     gap closed: a Q2 witness is reachable here if any mutant can make one. *)
  Alcotest.(check int) "MS probe: Q2 interesting fires (pinned)"
    P16_witness.q2_interesting_lmv
    (fires reach ~slice:all_states q2);
  Alcotest.(check int)
    "MS probe: Q2 interesting fires on the monkeys>=1 slice (pinned)"
    P16_witness.q2_interesting_lmv_post_monkey
    (fires reach ~slice:post_monkey q2);
  (* Graph pin LAST. *)
  Alcotest.(check int) "MS probe: Lmv states (pinned)" P16_witness.lmv_states
    (report_states lmv_rv)

(* ==== the MA / MR / MS-matrix anchor ========================================
   The remaining live legs the manual rows observe: L0 (both lists,
   controls), Lc (both lists - MA's legs), Lm/Rv (the §6 MS row's own leg,
   vacuously clean by the matrix gap), L0v/Rv (MR's leg - its red prints
   Q1). *)

(* WHAT COULD MAKE THIS FAIL: MR (SEEN - L0v/Rv's violated string printed
   Q1's name), MA (SEEN partially - ONLY the Lc states pins moved, the
   required negative), any refutation of either list over these graphs, or
   seed/bound drift (the pins). *)
let test_manual_anchor () =
  let l0_rv =
    leg ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.zero_budget
      ~list_select:Fc.Rv_list ~require_fault:false
  in
  let l0_m =
    leg ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.zero_budget
      ~list_select:Fc.Matched_list ~require_fault:false
  in
  let lc_rv =
    leg ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.lc_budget
      ~list_select:Fc.Rv_list ~require_fault:true
  in
  let lc_m =
    leg ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.lc_budget
      ~list_select:Fc.Matched_list ~require_fault:true
  in
  let lm_rv =
    leg ~req_drop:false ~pod_monkey:true ~vct:false P16_witness.lm_budget
      ~list_select:Fc.Rv_list ~require_fault:true
  in
  let l0v_rv =
    leg ~req_drop:false ~pod_monkey:false ~vct:true P16_witness.zero_budget
      ~list_select:Fc.Rv_list ~require_fault:false
  in
  (* Violated NAMES first (a red PRINTS the member; a P14/P15 name anywhere
     = the §4.4 masking-trap harness bug). *)
  Alcotest.(check string) "anchor: L0/Rv violated names NOTHING" "<none>"
    (inv_name l0_rv.violated);
  Alcotest.(check string) "anchor: L0/Matched violated names NOTHING" "<none>"
    (inv_name l0_m.violated);
  Alcotest.(check string)
    "anchor: Lc/Rv violated names NOTHING (MA's leg - MA must refute \
     NOTHING here)"
    "<none>" (inv_name lc_rv.violated);
  Alcotest.(check string) "anchor: Lc/Matched violated names NOTHING (MA's \
                           leg)"
    "<none>" (inv_name lc_m.violated);
  Alcotest.(check string)
    "anchor: Lm/Rv violated names NOTHING (the §6 MS row's own leg; Q2 is \
     content-vacuous here - the witness's disclosed matrix gap)"
    "<none>" (inv_name lm_rv.violated);
  Alcotest.(check string)
    "anchor: L0v/Rv violated names NOTHING (MR's leg - its red PRINTS Q1)"
    "<none>" (inv_name l0v_rv.violated);
  (* Leg semantics. *)
  Alcotest.(check bool) "anchor: L0/Rv clean" true (report_clean l0_rv);
  Alcotest.(check bool) "anchor: L0/Matched clean" true (report_clean l0_m);
  Alcotest.(check bool) "anchor: Lc/Rv clean" true (report_clean lc_rv);
  Alcotest.(check bool) "anchor: Lc/Matched clean" true (report_clean lc_m);
  Alcotest.(check bool) "anchor: Lm/Rv clean" true (report_clean lm_rv);
  Alcotest.(check bool) "anchor: L0v/Rv clean" true (report_clean l0v_rv);
  Alcotest.(check bool) "anchor: Lc crash REALLY taken" true
    (lc_m.max_crashes_seen >= 1);
  Alcotest.(check bool) "anchor: Lm monkey REALLY taken" true
    (lm_rv.max_monkeys_seen >= 1);
  (* Graph pins LAST (under MA ONLY these may move - the P15 M1 lesson). *)
  Alcotest.(check int) "anchor: L0/Rv states (pinned)" P16_witness.l0_states
    (report_states l0_rv);
  Alcotest.(check int) "anchor: L0/Matched states (pinned)"
    P16_witness.l0_states (report_states l0_m);
  Alcotest.(check int) "anchor: Lc/Rv states (pinned)" P16_witness.lc_states
    (report_states lc_rv);
  Alcotest.(check int) "anchor: Lc/Matched states (pinned)"
    P16_witness.lc_states (report_states lc_m);
  Alcotest.(check int) "anchor: Lm/Rv states (pinned)" P16_witness.lm_states
    (report_states lm_rv);
  Alcotest.(check int) "anchor: L0v/Rv states (pinned)" P16_witness.l0v_states
    (report_states l0v_rv)

let () =
  Alcotest.run "p16_mutation"
    [
      ( "per_member_forges",
        [
          Alcotest.test_case
            "Q1 rejects an OK get response at rv = counter (MC's boundary \
             witness; below-counter control accepted)"
            `Quick test_q1_forge;
          Alcotest.test_case
            "Q2 rejects a same-key same-rv divergent response body (T2 \
             coverage; identical / rv-gap controls accepted)"
            `Quick test_q2_forge;
          Alcotest.test_case
            "Q3 rejects a matched wrong-key OK get response (S3; \
             non-matching control is ME's discriminator)"
            `Quick test_q3_forge;
          Alcotest.test_case
            "Q5 rejects a matched wrong-key OK create response (MB; \
             error-body control is the drop leg's real shape)"
            `Quick test_q5_forge;
        ] );
      ( "md_converse",
        [
          Alcotest.test_case
            "the UNMUTATED Ld legs: clean, drop edge taken, knife-edge \
             confined to the drops>=1 slice (MD's red prints Q5 here)"
            `Quick test_md_converse_control;
        ] );
      ( "ms_lmv_probe",
        [
          Alcotest.test_case
            "the monkey-x-vct probe: clean with Q2 genuinely firing \
             post-monkey (MS's red would print Q2 here; measured inert)"
            `Quick test_ms_lmv_probe;
        ] );
      ( "manual_anchor",
        [
          Alcotest.test_case
            "the live L0/Lc/Lm/L0v legs, violated NAMED (MR's red prints Q1; \
             MA may move only the Lc pins)"
            `Quick test_manual_anchor;
        ] );
    ]

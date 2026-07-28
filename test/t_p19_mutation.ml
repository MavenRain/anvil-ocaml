(* BUILD-SPEC-P19 section 7 - confirm-by-mutation for the MESSAGE-PROVENANCE
   family (M1 controller-tag / M2 pod-monkey / M3 builtin / M4
   no-reflexive-request, asserted ALONE by the four P19 legs). A clean,
   decisive [No_counterexample] from [t_p19_provenance] is only evidence if
   the family would MOVE when what it classifies breaks; on the true model
   all four legs are clean and TWO members ride an honest vacuity (M2 off
   the monkey budget, M3 everywhere on the vsts spine), so the Refuted path
   would otherwise ship with almost no observed-red coverage. Two forms of
   evidence, the P14-P18 split: the MANUAL real-source rows ML1 / ML2 / ML3
   / MN1 / MN1' (documented below - applied with Edit, SEEN red or SEEN inert,
   reverted by rewriting the saved pre-mutation bytes, never
   [git checkout --], never an [sd] empty-pattern revert; only the green
   tree ships), and the AUTOMATED permanent forges below, whose
   red-capability is asserted on every run.

   ==== ML1 (MANUAL, pod_monkey.ml:66; NOT shipped) =========================
   ==== the cross-member ATTRIBUTION flip (P14-MA style) ====================

   Mutant: the monkey's CREATE arm stamps the BUILTIN tag -
   [Message.pod_monkey_req_msg allocated content] becomes
   [Message.built_in_controller_req_msg allocated content] (same arity, same
   content; only the [src] the constructor stamps changes, message.ml:189-194).
   Spec section 7 predicts the Lm leg RED naming M3 (a monkey CREATE now
   carries [Builtin_controller], and a create is not a delete) with M2
   staying green (its premise empties for that op).

   MEASURED effect (the section-7 ML1 row CONFIRMED, both halves): the Lm
   leg flipped clean -> Refuted with [violated] naming M3 BY NAME
   ([t_p19_provenance]'s Lm case reddened at its FIRST check, "Lm: outcome
   clean", and this exe's anchor printed the full M3 name at "anchor: Lm
   violated"), while L0 / Lc / Ld stayed BYTE-UNCHANGED - all three cases
   passed IN FULL, every state / gate / per-member pin at its committed
   value (76 / 464 / 744 states, gates 32 / 296 / 448, M1 16 / 156 / 64,
   M4 16 / 208 / 448, M2 = M3 = 0 everywhere) - because no monkey step is
   enabled off the monkey budget. The ATTRIBUTION datum is the point: the
   red lands on M3, and since [violated] is [first_violated] over the
   family in order M1 -> M2 -> M3 -> M4, BOTH M1 and M2 HELD at the
   counterexample state - the misattributed creates leave M2's premise
   rather than breaking it. The orphan replica ALSO reddened, at its
   "M3 violation-free" check with 679 violating states (the generic spine
   runs a live monkey whose creates now carry the builtin tag) - a second,
   independent sighting of the same flip on a foreign graph. No graph
   identity is claimed under a mutant: 679 is the MUTANT replica's count.

   ==== ML2 (MANUAL, builtin_controllers.ml:101; NOT shipped) ===============
   ==== the floor-is-load-bearing row ======================================

   Mutant: the GC's request content stops being a delete - the single
   [let content = Message.delete_req_msg_content input.key (Some
   preconditions)] becomes an [Option.fold] over
   [Object_ref_map.find_opt input.key input.resources] emitting
   [Message.update_req_msg_content input.key.Common.namespace
   input.key.Common.name obj] for the stored object (the delete stays as
   the unreachable [~none] arm - a cheap constructor, never an expensive
   eager arm). Spec section 7 predicts all four legs INERT (the builtin never
   fires on the vsts spine - prediction 3's mechanism) and the ORPHAN
   REPLICA RED naming M3: the row that PROVES the replica floor is
   load-bearing rather than decorative.

   MEASURED effect (the section-7 ML2 row CONFIRMED, both halves): the four
   legs ran BYTE-UNCHANGED ([t_p19_provenance]'s L0 / Lc / Ld / Lm cases
   passed IN FULL, every pin at its committed value, M3's 0/0 vacuity rows
   included, and THIS exe ran FULLY GREEN - the anchor's four "<none>"
   attributions and every graph pin) and the ORPHAN REPLICA reddened at
   "orphan: M3 violation-free (holds everywhere)" - 679 violating states,
   numerically the floor count [P19_witness.m3_interesting_orphan]: every
   builtin-premise state is now a violation, because every GC emission on
   that spine is the mutated update. M3's non-vacuity floor is therefore
   load-bearing: delete the replica and M3 would ship with ZERO red
   coverage on any real graph, its four leg rows being honest vacuity.

   ==== ML3 (MANUAL, controller.ml:234; NOT shipped) ========================
   ==== the tag-kind stamp + the inv_self register-distinctness datum ======

   Mutant: the controller's request stamp carries a POD-kinded tag -
   [Message.controller_req_msg controller_id cr_key req_id r] becomes
   [Message.controller_req_msg controller_id
   { cr_key with Common.kind = Pod.kind } req_id r] (message.ml:175-179
   stamps [src = Controller (controller_id, cr_key)], so only the tag's
   KIND moves; the payload is untouched). Spec section 7 predicts every leg
   RED naming M1 at the first controller message, and [inv_self] EXPECTED
   green (it filters on EXACT src equality with [vsts_ref], so the mutated
   src leaves its premise - the register-distinctness datum that closes the
   loop on spec section 1's static argument).

   MEASURED effect (the section-7 ML3 row CONFIRMED, both halves): all four
   legs flipped clean -> Refuted with [violated] naming M1 BY NAME (this
   exe's anchor reddened at its FIRST check, "anchor: L0 violated",
   printing the full M1 name; [t_p19_provenance]'s L0 / Lc / Ld / Lm cases
   EACH reddened at their own "<leg>: outcome clean"), and the
   REGISTER-DISTINCTNESS half held: [t_p11_vsts_invariants]'s
   safety_decisive case - every [Vsts_invariants.always] member, [inv_self]
   (vsts_invariants.ml:214, folded in at :286) included - PASSED under the
   mutant. [inv_self] (exact-src-keyed, payload-constraining) never notices
   what M1 (any-cr_key, tag-kind-constraining) rejects: a message from
   [Controller (controller_id, pod-kinded key)] passes [inv_self] silently
   and is exactly what M1 polices - MEASURED, not argued.

   MEASURED-CORRECTION (ML3, an UNPREDICTED second-order effect, spec
   section 7): the mutant also COLLAPSES the graph downstream. The api
   server stamps its response [dst = req.src], which under the mutant is no
   longer the controller's own host id, so responses are undeliverable and
   the reconciler stalls after its first request - seen as
   [t_p11_vsts_invariants]'s non_vacuity case reddening (interesting-count
   [etcd_objects_have_unique_uids] 38 -> 0: nothing but the CR is ever
   stored) and [t_p16_req_resp] reddening broadly. The ATTRIBUTION half is
   untouched by this (the refutation lands at the FIRST controller message,
   before any response is needed), and the orphan replica passed IN FULL
   under ML3 - its depth-4 horizon never reaches a response delivery, so
   the tag relabelling is invisible there.

   ==== MN1 (MANUAL, message.ml:200; NOT shipped) - the NEGATIVE control ====

   Mutant: [form_get_resp_msg] stops swapping src/dst -
   [~src:req_msg.dst ~dst:req_msg.src] becomes
   [~src:req_msg.src ~dst:req_msg.dst], so every GET response is stamped
   with the REQUESTER as its source and the api server as its destination
   (api_server.ml:711 is the call site). Spec section 7 predicts the family
   INERT (a response stamped [Controller (id, vsts_ref)] still carries a
   vsts-kind tag, so M1 passes; M4 sees content [Api_response], out of its
   [Api_request] scope) and P16's [matched_family] RED (the pairing is
   broken). The family-measures-PROVENANCE-not-PAIRING boundary datum.

   MEASURED effect (the section-7 MN1 row: CONFIRMED but VACUOUS at this
   site): the P19 family did not merely stay clean, it stayed
   BYTE-IDENTICAL - [t_p19_provenance] AND this exe both ran FULLY GREEN,
   every state / gate / per-member pin at its committed value (M4's
   api-server-sourced counts included) - and [t_p16_req_resp] reddened.

   MEASURED-CORRECTION (MN1, B1's site pin refined; spec section 7):
   [form_get_resp_msg] is UNREACHABLE on all four P19 legs. The legs are
   vct:false (the k6-class cut, spec section 4) and the VSTS reconciler's
   SOLE [Get] emitter is Get_pvc (vsts_invariants.ml:181-186 documents the
   repertoire), so no get response is ever formed there. Two-sided
   evidence: every P19 pin held byte-identical (a mis-stamped get response
   would have MOVED M4's counts), and [t_p16_req_resp] reddened on EXACTLY
   its three vct:TRUE cases ([l0v_vct], [ldv_vct_drop], [lcv_supplementary])
   while its four vct:false cases ([l0_floor], [lc_crash], [ld_drop],
   [lm_monkey]) stayed GREEN. The row's inertness is therefore true but
   vacuous on the legs, so it was re-run at the reachable sibling site.

   ==== MN1' (MANUAL, message.ml:208; NOT shipped) - the REACHABLE variant ==
   ==== the prediction REFUTED on the monkey leg ============================

   Mutant: the SAME one-line shape at the site the legs actually execute -
   [form_create_resp_msg]'s [~src:req_msg.dst ~dst:req_msg.src] becomes
   [~src:req_msg.src ~dst:req_msg.dst], so every CREATE response is stamped
   with the requester as its source (spec section 7's "one
   [form_*_resp_msg] path", realised where it is reachable).

   MEASURED effect (the section-7 MN1 prediction CONFIRMED on the three
   controller-only legs, REFUTED on the monkey leg - recorded honestly):

   - L0 / Lc / Ld: the family stayed SILENT (clean, [violated] =
     ["<none>"], decisive, replica faithful, M1/M4 premises firing, gate
     non-saturating) with ONLY the graph pins moving - states 76 -> 28,
     464 -> 260, 744 -> 312, the create response being undeliverable so the
     reconciler stalls after its first create. The predicted MECHANISM
     holds exactly there: a response inheriting
     [Controller (controller_id, vsts_ref)] still carries a vsts-kind tag
     (M1 passes) and M4 sees [Api_response], out of its [Api_request]
     scope. The honest control shape: PINS move, the family does not.
   - Lm: the family REDDENED naming M2 (this exe's anchor printed
     [all_requests_from_pod_monkey_are_api_pod_requests] at "anchor: Lm
     violated"; [t_p19_provenance]'s Lm reddened at "Lm: outcome clean").
     MECHANISM: the monkey's create RESPONSE inherits [src Pod_monkey], and
     M2 - faithful to upstream network.rs:570-587 - asserts that every
     [Pod_monkey]-sourced in-flight message IS an api request
     ([api_request_of] is [None] on a response, so the
     [Option.fold ~none:false] rejects). The orphan replica reddened the
     same way (111 violating states, its live monkey).
   - THE BOUNDARY, corrected: provenance does NOT ignore all pairing
     breakage. It ignores breakage that leaves a response's inherited tag
     admissible (the controller legs), and CATCHES breakage that lets a
     RESPONSE inherit a request-only sender tag (the monkey). BONUS: this
     is M2's red capability witnessed on a LIVE graph, forge-free - spec
     section 2 predicted M2's red would come only from the forges and
     ML1.

   ==== the automated rows (permanent; red-capability asserted every run) ===

   Per-member forges, each an ISOLATION audited for tautology and
   entailment (feedback-confirm-tests-by-mutation), with the D1 4-check
   parity discipline FROM BIRTH (BUILD-SPEC-P19 section 7): (1) the target
   member's [holds] is FALSE at the forged state; (2) the target's own
   [interesting] FIRES there (a premise-fired violation, never a vacuous
   one); (3) the family CONJUNCTION is false; (4) [first_violated] NAMES
   the target - strengthened by an ISOLATION sweep ([violated_names] is the
   singleton, so every OTHER member still holds) and by the leg's own
   [Mc.check_safety] over the [Fc.faulted] wrapper, SEEN Refuted. Every
   forge carries a NEGATIVE CONTROL of the same shape that is ACCEPTED with
   the member's [interesting] still firing (so the accept is never
   clean-by-vacuity).

   The forge BASE is the legs' own seed, whose in-flight pool is EMPTY
   (spec section 5's measured fact) - so [test_seed_shape] pins that NO
   member's premise fires there, and every [interesting] below is caused by
   the forged message and nothing else. The forged pod object is the
   reconciler's REAL [make_pod] output (marshalled), so the pod-kind reads
   are not test-local fictions.

   TEST-ORDERING RULE (P12 finding 1, P13-P18 precedent): semantic facts
   FIRST - family names, controls, holds/interesting/conjunction/violated -
   and only THEN the brittle exact counts (the anchor's graph pins last),
   so under a manual row the semantic verdicts print before a moved pin
   aborts the case.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum (both [Mc.outcome] arms), no
   two-arm match on [option]/[result] (stdlib [Option.fold] - its [~none]
   is EAGER, so no expensive arm is ever placed there), no wildcard arm,
   Alcotest as the sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Mp = Anvil_assurance.Msg_provenance
module Vr = V_stateful_set_reconciler

let controller_id : int = Scenario.controller_id
let desired : int = P19_witness.witness_desired
let depth : int = P19_witness.witness_depth
let bound : Bound.t = P19_witness.p19_bound ~desireds:[ desired ]

(* The family exactly as the four legs thread it (CR-agnostic, spec
   section 2: M1 consumes [controller_id], M2-M4 are cluster-level). *)
let family : Invariants.invariant list = Mp.provenance_family ~controller_id

(* The four upstream member names (addresses, not pinned measurements -
   [t_p19_provenance] addresses the family the same way). *)
let m1_name : string = "every_msg_from_vsts_controller_carries_vsts_key"
let m2_name : string = "all_requests_from_pod_monkey_are_api_pod_requests"

let m3_name : string =
  "all_requests_from_builtin_controllers_are_api_delete_requests"

let m4_name : string =
  "no_pending_request_to_api_server_from_api_server_or_external"

(* ---- outcome / report projections (exhaustive 2-arm matches) ------------- *)

let refuted (o : Fc.faulted Mc.outcome) : bool =
  match o with Mc.Refuted _ -> true | Mc.No_counterexample _ -> false

let report_clean (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

let report_states (r : Fc.fault_report) : int =
  match r.outcome with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let report_decisive_local (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let violated_name (r : Fc.fault_report) : string =
  Option.fold r.violated ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ---- per-state family projections ---------------------------------------- *)

(* Every family member the state violates, by name, each member probed
   INDIVIDUALLY over the WHOLE family - what makes a forge an ISOLATION:
   [[]] is "all four hold"; a singleton is "exactly this member broke".
   Sound against a silently-empty family only together with
   {!test_seed_shape}'s name pin, which runs first. *)
let violated_names (s : Cluster.cluster_state) : string list =
  List.filter_map
    (fun (i : Invariants.invariant) ->
      if i.Invariants.holds s then None else Some i.Invariants.name)
    family

(* The named member's own [holds] / [interesting] - both [false] on a
   missing name, which {!test_seed_shape}'s name pin and every
   interesting-fires check below catch LOUDLY. *)
let member_holds (name : string) (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.holds s)
    family

let member_interesting (name : string) (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.interesting s)
    family

let first_violated_name (s : Cluster.cluster_state) : string =
  Option.fold
    (Invariants.first_violated family s)
    ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ---- the exact-leg-check harness (the t_p14..t_p18 singleton form) ------- *)

let singleton_reach (f : Fc.faulted) : Fc.faulted Mc.reachable =
  Mc.explore ~depth:1
    ~successors:(fun (_ : Fc.faulted) -> [])
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash ~init:[ f ]

(* The family exactly as the P19 legs assert it: the conjunction, lifted
   pointwise over the product wrapper (fault_check's [fun f -> inv f.cs]). *)
let safety_of (f : Fc.faulted) : Fc.faulted Mc.outcome =
  let conj = Invariants.conjunction family in
  Mc.check_safety (singleton_reach f)
    ~inv:(fun (x : Fc.faulted) -> conj x.cs)
    ~equal:Fc.faulted_equal

(* A POST-MONKEY product state around a forged [cluster_state] - the monkey
   is M2's only live leg. The three counters are inert to every [holds];
   the point is that the forges run through the SAME [Fc.faulted] wrapper
   the legs check. *)
let product (cs : Cluster.cluster_state) : Fc.faulted =
  { Fc.cs; crashes = 0; drops = 0; monkeys = 1 }

(* ==== the forge base: the legs' own seed, in-flight pool EMPTY ============ *)

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ()

(* The seed with ONLY the network replaced - every forge is the seed plus a
   hand-built in-flight bag, nothing else moves (the t_p14 [forged_state]
   shape, narrowed to the network because no P19 member reads the store,
   the allocator or the controller entry). *)
let forged (msgs : Message.t list) : Cluster.cluster_state =
  {
    seed with
    Cluster.network = { Network.in_flight = Message.Pool.of_list msgs };
  }

let msg ~(src : Message.host_id) ~(dst : Message.host_id)
    ~(content : Message.message_content) : Message.t =
  Message.form_msg ~src ~dst ~rpc_id:(Message.Rpc_id.of_int 0) ~content

(* ---- keys + payloads ------------------------------------------------------
   [pod_tag_key] is [Scenario.vsts_ref] with ONLY its [kind] flipped, so
   M1's red is attributable to the KIND and to nothing else (it is also
   ML3's mutant shape at forge level). *)

let vsts_tag_key : Common.object_ref = Scenario.vsts_ref

let pod_tag_key : Common.object_ref =
  { Scenario.vsts_ref with Common.kind = Pod.kind }

let pod_key : Common.object_ref =
  { Common.kind = Pod.kind; name = "forged-pod"; namespace = "ns" }

(* The reconciler's REAL pod (marshalled) - the pod-kind reads below are not
   test-local fictions; {!test_seed_shape} pins that it really is
   pod-kinded. *)
let pod_obj : Dynamic_object.t = Pod.marshal (Vr.make_pod (Scenario.vsts ~desired ()) 0)

let create_pod_content : Message.message_content =
  Message.create_req_msg_content "ns" pod_obj

let update_pod_content : Message.message_content =
  Message.update_req_msg_content "ns" "forged-pod" pod_obj

let delete_pod_content : Message.message_content =
  Message.delete_req_msg_content pod_key None

let get_pod_content : Message.message_content =
  Message.get_req_msg_content pod_key

let list_pods_content : Message.message_content =
  Message.list_req_msg_content Pod.kind "ns"

let get_then_delete_pod_content : Message.message_content =
  Message.get_then_delete_req_msg_content pod_key (Owner_reference.default ())

let get_response_content : Message.message_content =
  Message.Api_response
    (Api_method.Get_response { Api_method.res = Error Api_method.Object_not_found })

(* ---- the 4-check parity bundle (spec section 7's D1 discipline) ---------- *)

let check_forge ~(label : string) ~(name : string) (s : Cluster.cluster_state)
    : unit =
  (* (1) the member REJECTS. *)
  Alcotest.(check bool) (label ^ ": holds = false (the member REJECTS)") false
    (member_holds name s);
  (* (2) premise-FIRED, never vacuous. *)
  Alcotest.(check bool)
    (label ^ ": the member's own interesting FIRES (not a vacuous red)")
    true
    (member_interesting name s);
  (* (3) the family conjunction the leg asserts is false. *)
  Alcotest.(check bool) (label ^ ": the family conjunction is FALSE") false
    (Invariants.conjunction family s);
  (* (4) the red is ATTRIBUTED by name. *)
  Alcotest.(check string) (label ^ ": violated NAMES the member") name
    (first_violated_name s);
  (* ISOLATION: every OTHER member still holds. *)
  Alcotest.(check (list string))
    (label ^ ": ISOLATION - exactly this member is violated")
    [ name ] (violated_names s);
  (* The leg's own check, over the leg's own product wrapper. *)
  Alcotest.(check bool)
    (label ^ ": the leg's own check_safety REFUTES the product state")
    true
    (refuted (safety_of (product s)))

let check_control ~(label : string) ~(name : string)
    (s : Cluster.cluster_state) : unit =
  Alcotest.(check (list string))
    (label ^ ": ACCEPTED - violates no member")
    [] (violated_names s);
  Alcotest.(check bool)
    (label ^ ": the accept is NOT vacuous - the member's interesting fires")
    true
    (member_interesting name s);
  Alcotest.(check bool) (label ^ ": the leg harness stays clean") false
    (refuted (safety_of (product s)))

(* ==== seed shape (the fail-loud base every forge rests on) ================ *)

let test_seed_shape () =
  Alcotest.(check (list string))
    "family = the four upstream names, in member order M1-M4"
    [ m1_name; m2_name; m3_name; m4_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family);
  (* The base's in-flight pool is EMPTY (spec section 5's measured fact), so
     every [interesting] below is caused by the forged message alone. *)
  Alcotest.(check int) "seed: in-flight pool is EMPTY" 0
    (Message.Pool.cardinal (Cluster.in_flight seed));
  Alcotest.(check (list string)) "seed violates NOTHING" [] (violated_names seed);
  Alcotest.(check bool) "seed: NO member's interesting fires (all vacuous)"
    false
    (List.exists
       (fun (i : Invariants.invariant) -> i.Invariants.interesting seed)
       family);
  (* The forge payload is a REAL reconciler pod. *)
  Alcotest.(check bool) "forge payload: make_pod's object really is pod-kinded"
    true
    (Common.equal_kind (Dynamic_object.kind pod_obj) Pod.kind);
  (* The two tag keys differ in KIND ALONE, so M1's red below is
     attributable to the kind. *)
  Alcotest.(check bool)
    "tag keys differ in KIND ALONE (name/namespace identical)" true
    (String.equal vsts_tag_key.Common.name pod_tag_key.Common.name
    && String.equal vsts_tag_key.Common.namespace pod_tag_key.Common.namespace
    && not (Common.equal_kind vsts_tag_key.Common.kind pod_tag_key.Common.kind))

(* ==== F-M1: a controller tag carrying a NON-vsts key ====================== *)

(* WHAT COULD MAKE THIS FAIL: dropping M1's [equal_kind key.kind
   V_stateful_set.kind] check, the premise drifting off [controller_id]
   (the foreign-id control would then red), or the [Controller] arm being
   widened to accept any kind. *)
let test_f_m1 () =
  (* CONTROL FIRST, so the discriminating direction is SEEN: the SAME
     message with the vsts-kinded tag is accepted, with M1's premise
     firing. *)
  let control =
    forged
      [
        msg
          ~src:(Message.Controller (controller_id, vsts_tag_key))
          ~dst:Message.Api_server ~content:get_pod_content;
      ]
  in
  check_control ~label:"F-M1 control (vsts-kinded tag)" ~name:m1_name control;
  (* PREMISE discriminator: the SAME bad tag under a DIFFERENT controller id
     is accepted AND out of premise - M1 is id-keyed, not a blanket tag
     check. *)
  let foreign =
    forged
      [
        msg
          ~src:(Message.Controller (controller_id + 1, pod_tag_key))
          ~dst:Message.Api_server ~content:get_pod_content;
      ]
  in
  Alcotest.(check (list string))
    "F-M1 premise control: a pod-kinded tag under a FOREIGN controller id is \
     accepted"
    [] (violated_names foreign);
  Alcotest.(check bool)
    "F-M1 premise control: M1's interesting does NOT fire there (id-keyed \
     premise)"
    false
    (member_interesting m1_name foreign);
  (* THE FORGE. *)
  let bad =
    forged
      [
        msg
          ~src:(Message.Controller (controller_id, pod_tag_key))
          ~dst:Message.Api_server ~content:get_pod_content;
      ]
  in
  check_forge ~label:"F-M1 (pod-kinded controller tag)" ~name:m1_name bad

(* ==== F-M2a/b/c: monkey-sourced messages outside the pod-write repertoire = *)

(* WHAT COULD MAKE THIS FAIL: widening M2's request classifier to accept a
   read arm (a/b), dropping its [dst = Api_server] conjunct (c), or letting
   the KEY KIND rather than the ARM decide (b is pod-keyed and must still
   red). *)
let test_f_m2 () =
  (* CONTROL FIRST: the monkey's REAL create (pod-keyed, to the api server)
     is accepted with M2's premise firing. *)
  let control =
    forged
      [
        msg ~src:Message.Pod_monkey ~dst:Message.Api_server
          ~content:create_pod_content;
      ]
  in
  check_control ~label:"F-M2 control (the monkey's real pod create)"
    ~name:m2_name control;
  (* (a) a FALSE-arm request: List. *)
  let bad_a =
    forged
      [
        msg ~src:Message.Pod_monkey ~dst:Message.Api_server
          ~content:list_pods_content;
      ]
  in
  check_forge ~label:"F-M2a (monkey List_request - a false arm)" ~name:m2_name
    bad_a;
  (* (b) a POD-KEYED false arm: the ARM decides, not the kind. *)
  let bad_b =
    forged
      [
        msg ~src:Message.Pod_monkey ~dst:Message.Api_server
          ~content:get_pod_content;
      ]
  in
  check_forge
    ~label:"F-M2b (monkey POD-KEYED Get_request - the arm decides, not the kind)"
    ~name:m2_name bad_b;
  (* (c) the right request to the WRONG destination. *)
  let bad_c =
    forged
      [
        msg ~src:Message.Pod_monkey ~dst:Message.Builtin_controller
          ~content:create_pod_content;
      ]
  in
  check_forge ~label:"F-M2c (monkey pod create to a NON-api-server dst)"
    ~name:m2_name bad_c

(* ==== F-M3 (two variants): builtin-sourced non-deletes ==================== *)

(* WHAT COULD MAKE THIS FAIL: widening M3's classifier past [Delete_request]
   - variant 2 is exactly the STRICT-DELETE reading (upstream's
   [is_delete_request] macro is generated over strictly [DeleteRequest], so
   [Get_then_delete_request] is NOT a delete) - dropping M3's
   [dst = Api_server] conjunct (variant 3, the F-M2c shape at the builtin
   source), or flipping its non-request arm to accept (variant 4). The last
   two conjuncts have no live red witness anywhere: M3's premise is 0/0 on
   all four legs (honest vacuity) and every one of the orphan replica's 679
   premise states is a real GC delete addressed to the api server. *)
let test_f_m3 () =
  (* CONTROL FIRST: the GC's REAL delete is accepted with M3's premise
     firing. *)
  let control =
    forged
      [
        msg ~src:Message.Builtin_controller ~dst:Message.Api_server
          ~content:delete_pod_content;
      ]
  in
  check_control ~label:"F-M3 control (the GC's real delete)" ~name:m3_name
    control;
  (* Variant 1: an UPDATE from the builtin. *)
  let bad_update =
    forged
      [
        msg ~src:Message.Builtin_controller ~dst:Message.Api_server
          ~content:update_pod_content;
      ]
  in
  check_forge ~label:"F-M3 (builtin Update_request)" ~name:m3_name bad_update;
  (* Variant 2: the STRICT-DELETE reading - a get-then-delete is NOT a
     delete. *)
  let bad_gtd =
    forged
      [
        msg ~src:Message.Builtin_controller ~dst:Message.Api_server
          ~content:get_then_delete_pod_content;
      ]
  in
  check_forge
    ~label:
      "F-M3' (builtin Get_then_delete_request - the STRICT-Delete reading)"
    ~name:m3_name bad_gtd;
  (* Variant 3 (the DST conjunct, F-M2c's shape at the builtin source): the
     GC's REAL delete sent to a CONTROLLER instead of the api server. *)
  let bad_dst =
    forged
      [
        msg ~src:Message.Builtin_controller
          ~dst:(Message.Controller (controller_id, vsts_tag_key))
          ~content:delete_pod_content;
      ]
  in
  check_forge
    ~label:"F-M3'' (builtin delete to a NON-api-server dst - the DST conjunct)"
    ~name:m3_name bad_dst;
  (* Variant 4 (the NON-REQUEST arm): a builtin-sourced RESPONSE, where
     [api_request_of] is [None] and M3's [Option.fold ~none:false] must
     reject - the arm M4's content control accepts and M3 does not. *)
  let bad_resp =
    forged
      [
        msg ~src:Message.Builtin_controller ~dst:Message.Api_server
          ~content:get_response_content;
      ]
  in
  check_forge
    ~label:"F-M3''' (builtin RESPONSE - the [~none:false] non-request arm)"
    ~name:m3_name bad_resp

(* ==== F-M4 (two variants): a request to the api server from itself / an
   external system ========================================================== *)

(* WHAT COULD MAKE THIS FAIL: dropping either the [Api_server] or the
   [External _] arm of M4's source scope (variant 2 is the External arm's
   ONLY red witness - both shipped spines install [external_model = None],
   so no live graph ever produces such a message), or dropping the
   [dst = Api_server] / [Api_request] conjuncts (the two controls). *)
let test_f_m4 () =
  (* CONTROL 1 (the CONTENT conjunct): an api-server-sourced RESPONSE to
     itself is accepted - M4 scopes requests only - with its
     (violation-shaped, .mli-disclosed) premise firing. *)
  let control_resp =
    forged
      [
        msg ~src:Message.Api_server ~dst:Message.Api_server
          ~content:get_response_content;
      ]
  in
  check_control ~label:"F-M4 control 1 (api-server RESPONSE, not a request)"
    ~name:m4_name control_resp;
  (* CONTROL 2 (the DST conjunct): an api-server-sourced request to a
     CONTROLLER is accepted. *)
  let control_dst =
    forged
      [
        msg ~src:Message.Api_server
          ~dst:(Message.Controller (controller_id, vsts_tag_key))
          ~content:get_pod_content;
      ]
  in
  check_control ~label:"F-M4 control 2 (api-server request to a CONTROLLER)"
    ~name:m4_name control_dst;
  (* Variant 1: the reflexive request. *)
  let bad_self =
    forged
      [
        msg ~src:Message.Api_server ~dst:Message.Api_server
          ~content:get_pod_content;
      ]
  in
  check_forge ~label:"F-M4a (api-server request to the api server)"
    ~name:m4_name bad_self;
  (* Variant 2: the EXTERNAL arm, SEEN - its only red witness anywhere. *)
  let bad_external =
    forged
      [
        msg ~src:(Message.External controller_id) ~dst:Message.Api_server
          ~content:get_pod_content;
      ]
  in
  check_forge
    ~label:"F-M4b (EXTERNAL-sourced request - the External arm's only witness)"
    ~name:m4_name bad_external

(* ==== the MANUAL anchor: the live legs, violated NAMED ====================
   The observation point for every manual row above. Semantic verdicts
   FIRST (violated names, clean, decisive, edges), brittle graph pins LAST,
   so a manual row's attribution prints before a moved pin aborts the
   case. *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget)
    ~(require_fault : bool) : Fc.fault_report =
  Fc.check_msg_provenance_under_faults ~depth ~req_drop ~pod_monkey bound
    budget ~desired ~require_fault

let l0 : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false P19_witness.zero_budget
       ~require_fault:false)

let lc : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false P19_witness.lc_budget
       ~require_fault:true)

let ld : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:true ~pod_monkey:false P19_witness.ld_budget
       ~require_fault:true)

let lm : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:true P19_witness.lm_budget
       ~require_fault:true)

let test_manual_anchor () =
  let l0 = Lazy.force l0 in
  let lc = Lazy.force lc in
  let ld = Lazy.force ld in
  let lm = Lazy.force lm in
  (* ATTRIBUTION FIRST: the member each leg names (ML1 prints M3 on Lm,
     MN1' prints M2 on Lm, ML3 prints M1 on all four; ML2 and MN1 print
     "<none>" everywhere). *)
  Alcotest.(check string) "anchor: L0 violated" "<none>" (violated_name l0);
  Alcotest.(check string) "anchor: Lc violated" "<none>" (violated_name lc);
  Alcotest.(check string) "anchor: Ld violated" "<none>" (violated_name ld);
  Alcotest.(check string) "anchor: Lm violated" "<none>" (violated_name lm);
  Alcotest.(check bool) "anchor: L0 clean" true (report_clean l0);
  Alcotest.(check bool) "anchor: Lc clean" true (report_clean lc);
  Alcotest.(check bool) "anchor: Ld clean" true (report_clean ld);
  Alcotest.(check bool) "anchor: Lm clean" true (report_clean lm);
  Alcotest.(check bool) "anchor: L0 decisive" true (report_decisive_local l0);
  Alcotest.(check bool) "anchor: Lc decisive" true (report_decisive_local lc);
  Alcotest.(check bool) "anchor: Ld decisive" true (report_decisive_local ld);
  Alcotest.(check bool) "anchor: Lm decisive" true (report_decisive_local lm);
  (* Edge-taken: the fault edges are REALLY in the observed graphs. *)
  Alcotest.(check bool) "anchor: Lc crash REALLY taken" true
    (lc.max_crashes_seen >= 1);
  Alcotest.(check bool) "anchor: Ld drop REALLY taken" true
    (ld.max_drops_seen >= 1);
  Alcotest.(check bool) "anchor: Lm monkey REALLY taken" true
    (lm.max_monkeys_seen >= 1);
  (* Graph pins LAST (76/464/744/1976, the P13-P18 identity; MN1' moves
     these - 28/260/312 on the three controller legs - while ML1, ML2, ML3
     and MN1 leave them at their committed values). *)
  Alcotest.(check int) "anchor: L0 states (pinned)" P19_witness.l0_states
    (report_states l0);
  Alcotest.(check int) "anchor: Lc states (pinned)" P19_witness.lc_states
    (report_states lc);
  Alcotest.(check int) "anchor: Ld states (pinned)" P19_witness.ld_states
    (report_states ld);
  Alcotest.(check int) "anchor: Lm states (pinned)" P19_witness.lm_states
    (report_states lm);
  Alcotest.(check int) "anchor: L0 gate (pinned)" P19_witness.l0_gate_states
    (Option.value l0.gate_states ~default:(-1));
  Alcotest.(check int) "anchor: Lc gate (pinned)" P19_witness.lc_gate_states
    (Option.value lc.gate_states ~default:(-1));
  Alcotest.(check int) "anchor: Ld gate (pinned)" P19_witness.ld_gate_states
    (Option.value ld.gate_states ~default:(-1));
  Alcotest.(check int) "anchor: Lm gate (pinned)" P19_witness.lm_gate_states
    (Option.value lm.gate_states ~default:(-1))

let () =
  Alcotest.run "p19_mutation"
    [
      ( "seed_shape",
        [
          Alcotest.test_case
            "family names, EMPTY in-flight base, no premise fires at the seed"
            `Quick test_seed_shape;
        ] );
      ( "per_member_forges",
        [
          Alcotest.test_case
            "F-M1: a pod-kinded controller tag (vsts-kinded control accepted; \
             foreign-id control out of premise)"
            `Quick test_f_m1;
          Alcotest.test_case
            "F-M2a/b/c: monkey List / pod-keyed Get / wrong dst (the real pod \
             create accepted)"
            `Quick test_f_m2;
          Alcotest.test_case
            "F-M3 + F-M3': builtin Update / Get_then_delete (the GC's real \
             delete accepted)"
            `Quick test_f_m3;
          Alcotest.test_case
            "F-M4a/b: reflexive and EXTERNAL-sourced requests (response and \
             non-api-dst controls accepted)"
            `Quick test_f_m4;
        ] );
      ( "manual_anchor",
        [
          Alcotest.test_case
            "the live L0/Lc/Ld/Lm legs, violated NAMED (ML1 prints M3 and MN1' \
             prints M2 on Lm; ML3 prints M1 on all four; ML2 and MN1 leave the \
             family silent)"
            `Quick test_manual_anchor;
        ] );
    ]

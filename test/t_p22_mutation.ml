(* BUILD-SPEC-P22 section 5 - confirm-by-mutation for the scale-down phase:
   the matrix that makes t_p22_scaledown's green MEAN something (a pin never
   SEEN to fail is not evidence).

   WHY THIS EXE EXISTS. P22's legs come back CLEAN with G2 finally live, so
   the burden is P21's, sharpened: a green G2 is only evidence if the
   verdict MOVES when the Delete_condemned emission breaks. Source mutants
   are RECONCILER mutations whose observable is a full four-graph
   re-exploration, so those rows follow the manual protocol (Edit apply /
   probe / Edit revert / [git diff --stat] empty per row - never [git
   checkout --]); the rows that are pure test-side instantiations (MS3, MS5)
   run AUTOMATED on every battery pass - MS3 in t_p22_scaledown (it is a
   SEED control and lives beside the seed-integrity test), MS5 here -
   together with the forged-state discriminator that proves every member
   red-capable at state level on THIS phase's seed.

   ==== the matrix (spec section 5; source-row VERDICTS LANDED BY B5, the
        mutation stage - predictions recorded now so the verdicts are
        judged, not narrated) ==================================================

   MS1  HEADLINE (= P21's MG6 re-applied): wrong [owner_ref] on the
        Delete_condemned emit (v_stateful_set_reconciler.ml:732-739,
        upstream :734). Predict: SL0 flips clean -> REFUTED naming exactly
        G2 (owner-ref conjunct, upstream :585), G1/G3 green; control: the
        five committed pins byte-identical under the SAME mutant (the arm
        is dead code on every old graph - P21's measured MG6 verdict).
        VERDICT (B5, MEASURED): CONFIRMED. Wrong-NAME owner ref on the
        emit: SL0 flips clean -> REFUTED with
        violated=vsts_internal_guarantee_get_then_delete_req (the exact G2
        member, SEEN verbatim in probe output); mutant SL0 replica 92
        states, G2 int=8 red=8, G1 int=4 red=0, G3 int=4 red=0 (green),
        G4 int=24 red=8 (containment - family order names G2);
        t_p22_scaledown: all four legs FAIL at "outcome CLEAN". Controls:
        t_p21_guarantee 9 OK, pins 76/464/744/1976/116 byte-identical;
        t_p21_mutation 6 OK. MG6 INERT -> REFUTED, done. RESHAPE NOTE
        (mutant-shape lesson): a uid-99 owner-ref forgery is INVISIBLE to
        G2 - the conjunct is [Owner_reference.eq_without_uid] (upstream
        owner_reference.rs:37-42, uid-exempt BY DESIGN): measured SL0
        stayed CLEAN at 92 states, G2 int=8 red=0 (the uid-SENSITIVE api
        server refuses the delete, the pod persists, the premise fires
        MORE). A "wrong owner_ref" mutant must break a uid-exempt
        conjunct; the landed row forged the name.

   MS2  TRAP ROW (negative control): the SAME mutation on the OTHER emitter
        - the Delete_outdated arm (:777-784). Predict: ALL legs green
        including SL0 (arm dead on this seed: pod-0 is freshly created and
        template-matching, :763-765) - the measured witness that "a green
        matrix on the wrong emitter is NOT G2 coverage". VERDICT (B5,
        MEASURED): CONFIRMED - SEEN GREEN: under the same wrong-name
        mutation on the Delete_outdated arm, t_p22_scaledown ran 6/6 OK
        exit 0 and SL0 is byte-identical (88 states, gate 20, int
        4/4/4/20, red 0).

   MS3  SEED-SABOTAGE CONTROL (in-test, no source edit - RUNS in
        t_p22_scaledown's [ms3_seed_sabotage] case on every battery pass):
        surplus-pod owner-ref uid 99 in a throwaway doctored seed. Predict
        (spec section 5): pod_filter drops the pod, [condemned] = [], and
        G2 fires NOWHERE on the zero-budget graph - the gate catches
        mis-seeding. The GC-orphan contest datum is recorded with the B5
        measurements.

   MS4  PARTITION BOUNDARY: [>= replicas] -> [> replicas] in
        [partition_pods] (:399-416). Predict: ordinal-1 pod never
        condemned; the phase-gate assertion reds; graph still converges
        (Delete_outdated scans needed ordinals only, so the surplus pod
        persists benignly). VERDICT (B5, MEASURED): CONFIRMED - SL0 CLEAN
        and decisive at 76 states (P21's L0 count: ALL delete traffic
        gone), G2 int=0 red=0; the exe reds at THE PHASE GATE assertion
        on every leg plus MS3's good-seed floor (5 failures, exit 1),
        seed_integrity still green - the surplus pod persists benignly,
        exactly as predicted.

   MS5  PREMISE WIRING (= P21's MG7 port; in-test, RUNS BELOW on every
        battery pass): the family instantiated at [controller_id + 1],
        evaluated over the SL0 replica. Predict: every member's
        [interesting] = 0 AND red = 0 (vacuous TRUTH, not vacuous falsity)
        - the family cannot be green-by-accident at the wrong id, on the
        new graph exactly as on the old ones. MEASURED below.

   MS6  FAULT-INTERACTION DATUM: After_delete_condemned's NotFound
        tolerance (:748-761) narrowed to Ok-only. Predict (hedged on
        purpose - either measured outcome is the datum): SL0 byte-identical
        (the one delete finds its pod; tolerance arm unexercised
        fault-free); SLm is where the arm is load-bearing (monkey deletes
        the condemned pod first). Family green in both; record the SLm
        graph delta. VERDICT (B5, MEASURED): PARTIAL - SL0 byte-identical
        CONFIRMED (88; leg green) and family green everywhere (red 0,
        every semantic gate passes, all legs clean+decisive); SLm
        load-bearing CONFIRMED with delta -56 (10216 -> 10160; gate 2080
        and member interesting 240/432/704/2120 UNCHANGED). REFINED: the
        "SLm is where" localization was too narrow - SLc 808 -> 804 (-4)
        and SLd 1144 -> 1128 (-16) also move: crash/drop interleavings
        also yield ObjectNotFound on the condemned delete (spec
        prediction 4's disclosed surface, now measured).

   A mutant killed by a build error or a timeout is NOT caught - reshape it
   (house rule). MS1 must be SEEN to name G2; MS2 must be SEEN green.

   ==== the AUTOMATED rows (permanent; run on every battery pass) ============

   - RED-CAPABILITY DISCRIMINATOR (the t_p21_mutation forged-state pattern,
     re-based on THIS phase's seed - the stored surplus pod included, so
     the get-then-delete rows aim at the pod the graph actually condemns):
     one forged state per member proving each of G1/G2/G3/G4 CAN fail -
     wrong-namespace create reds G1 (and G4 by containment, family order
     names G1); wrong-owner get-then-delete of the CONDEMNED pod reds G2
     (family order names G2 - MS1's exact observable, at state level);
     wrong-owner-list carried object on get-then-update reds G3 (:595);
     a forbidden kind ([Update_request], the MG1 kind) reds G4 ALONE.
   - FAITHFUL-EMISSION CONTROLS: the reconciler's own shapes - a [make_pod]
     create, THE Delete_condemned emission itself (the CR's controller
     owner ref, the condemned pod's key: byte-what MS1 mutates), a
     well-formed get-then-update - are ACCEPTED with the owning member's
     premise firing, so the reds above are attributable.
   - MS5 (above): premise necessity over the REAL SL0 graph, replica
     asserted against the {!P22_witness} pin first (a drifted replica would
     silently measure a different graph).

   TEST-ORDERING RULE (P12 finding 1): semantic facts first; the only
   witness constants read are the family cardinal and the SL0 pins that
   anchor MS5's replica.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum, no two-arm match on
   [option]/[result], total accessors only, no exceptions, Alcotest as the
   sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Ig = Anvil_assurance.Internal_guarantee
module Vsr = V_stateful_set_reconciler

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P22_witness.witness_desired
let ordinals : int list = P22_witness.p22_ordinals
let depth : int = P22_witness.witness_depth
let bound : Bound.t = P22_witness.p22_bound ~desireds:[ desired ]
let cr : V_stateful_set.t = Scenario.vsts ~desired ()
let family : Invariants.invariant list = Ig.guarantee_family ~cr ~controller_id
let g1_name : string = "vsts_internal_guarantee_create_req"
let g2_name : string = "vsts_internal_guarantee_get_then_delete_req"
let g3_name : string = "vsts_internal_guarantee_get_then_update_req"
let g4_name : string = "no_interfering_request_between_vsts"

(* ---- per-state family projections (t_p21_mutation's exact shapes) --------- *)

let violated_of (fam : Invariants.invariant list) (s : Cluster.cluster_state) :
    string list =
  List.filter_map
    (fun (i : Invariants.invariant) ->
      if i.Invariants.holds s then None else Some i.Invariants.name)
    fam

let member_holds (fam : Invariants.invariant list) (name : string)
    (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.holds s)
    fam

let member_interesting (fam : Invariants.invariant list) (name : string)
    (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.interesting s)
    fam

let fires (name : string) (s : Cluster.cluster_state) : bool =
  member_interesting family name s

(* The FAMILY-ORDER projection through the EXPORTED
   {!Invariants.first_violated} - the same function the leg's [violated]
   naming rides, so the MS1 prediction ("REFUTED naming exactly G2") is
   pinned at state level by the same semantics. *)
let first_violated_name (s : Cluster.cluster_state) : string =
  Option.fold
    (Invariants.first_violated family s)
    ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ==== the forged-state base: THIS phase's seed, in-flight pool replaced ==== *)

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true ~req_drop:false
    ~pod_monkey:false ()

let forged (m : Message.t) : Cluster.cluster_state =
  { seed with Cluster.network = { Network.in_flight = Message.Pool.singleton m } }

(* ---- the CR's own coordinates, READ off the CR, never typed --------------- *)

let cr_md : Object_meta.t = V_stateful_set.metadata cr
let ns : string = Option.value ~default:"" (Object_meta.namespace cr_md)
let parent : string = Option.value ~default:"" (Object_meta.name cr_md)

let cr_key : Common.object_ref =
  { Common.kind = V_stateful_set.kind; name = parent; namespace = ns }

let vsts_owner : Owner_reference.t =
  Option.value
    (V_stateful_set.controller_owner_ref cr)
    ~default:(Owner_reference.default ())

let vsts_msg ~(rpc : int) (r : Api_method.api_request) : Message.t =
  Message.controller_req_msg controller_id cr_key (Message.Rpc_id.of_int rpc) r

(* ---- payload construction -------------------------------------------------
   The reconciler's REAL [make_pod] object (the t_p20/p21_mutation
   discipline), and - NEW this phase - the get-then-delete rows aim at the
   SEEDED surplus pod (ordinal 1): the object the P22 graph actually
   condemns, so the accepted control below is byte-what the Delete_condemned
   arm emits and the red row is byte-what MS1's mutant would emit. *)

let base_pod : Pod.t = Vsr.make_pod cr 0
let pod0_name : string = Vsr.pod_name parent 0
let surplus_name : string = Vsr.pod_name parent 1

let surplus_key : Common.object_ref =
  { Common.kind = Pod.kind; namespace = ns; name = surplus_name }

(* G3's :590-591 agreement clauses need the carried object's name AND
   namespace to match the request's, and :595 needs its owner list to be
   exactly the request's own ref - the well-formed update payload fixes all
   three; the G3 red row breaks ONLY the owner list. *)
let update_md : Object_meta.t =
  {
    (Pod.metadata base_pod) with
    Object_meta.name = Some pod0_name;
    generate_name = None;
    namespace = Some ns;
    owner_references = Some [ vsts_owner ];
  }

let update_obj : Dynamic_object.t =
  Pod.marshal (Pod.with_metadata update_md base_pod)

let update_obj_wrong_owner : Dynamic_object.t =
  Pod.marshal
    (Pod.with_metadata
       { update_md with Object_meta.owner_references = Some [] }
       base_pod)

let create_ok : Api_method.api_request =
  Api_method.Create_request
    { Api_method.namespace = ns; obj = Pod.marshal base_pod }

let create_wrong_ns : Api_method.api_request =
  Api_method.Create_request
    { Api_method.namespace = ns ^ "-p22-elsewhere"; obj = Pod.marshal base_pod }

(* THE Delete_condemned emission (:732-739): the CR's controller owner ref,
   the condemned pod's key. *)
let gtd_ok : Api_method.api_request =
  Api_method.Get_then_delete_request
    { Api_method.key = surplus_key; owner_ref = vsts_owner }

(* MS1's observable at state level: same key, wrong owner ref. *)
let gtd_wrong_owner : Api_method.api_request =
  Api_method.Get_then_delete_request
    { Api_method.key = surplus_key; owner_ref = Owner_reference.default () }

let gtu_ok : Api_method.api_request =
  Api_method.Get_then_update_request
    {
      Api_method.namespace = ns;
      name = pod0_name;
      owner_ref = vsts_owner;
      obj = update_obj;
    }

let gtu_wrong_owner_obj : Api_method.api_request =
  Api_method.Get_then_update_request
    {
      Api_method.namespace = ns;
      name = pod0_name;
      owner_ref = vsts_owner;
      obj = update_obj_wrong_owner;
    }

(* ==== family shape ========================================================= *)

let test_family_shape () =
  Alcotest.(check (list string))
    "guarantee_family = the four member names, in family order (NO new \
     family is the phase's design pin)"
    [ g1_name; g2_name; g3_name; g4_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family);
  Alcotest.(check int) "guarantee_family cardinal"
    P22_witness.guarantee_cardinal (List.length family);
  List.iter
    (fun (name : string) ->
      Alcotest.(check bool)
        ("member addressable by name: " ^ name)
        true
        (List.exists
           (fun (i : Invariants.invariant) ->
             String.equal i.Invariants.name name)
           family))
    [ g1_name; g2_name; g3_name; g4_name ]

(* ==== red capability: every member SEEN to fail on this phase's seed ====== *)

let test_red_capability () =
  let s_g1 = forged (vsts_msg ~rpc:0 create_wrong_ns) in
  Alcotest.(check bool) "G1 row: premise fires" true (fires g1_name s_g1);
  Alcotest.(check (list string))
    "wrong-namespace create: violated = [G1; G4] in family order - G1 CAN \
     fail on the P22 seed"
    [ g1_name; g4_name ] (violated_of family s_g1);
  Alcotest.(check string) "G1 row: first_violated names G1" g1_name
    (first_violated_name s_g1);
  let s_g2 = forged (vsts_msg ~rpc:0 gtd_wrong_owner) in
  Alcotest.(check bool) "G2 row: premise fires" true (fires g2_name s_g2);
  Alcotest.(check (list string))
    "wrong-owner get-then-delete of the CONDEMNED pod: violated = [G2; G4] \
     - G2 CAN fail, and this forged state is MS1's observable at state \
     level (the leg-level verdict lands with B5)"
    [ g2_name; g4_name ] (violated_of family s_g2);
  Alcotest.(check string)
    "G2 row: first_violated names G2 (what MS1's Refuted must name)" g2_name
    (first_violated_name s_g2);
  let s_g3 = forged (vsts_msg ~rpc:0 gtu_wrong_owner_obj) in
  Alcotest.(check bool) "G3 row: premise fires" true (fires g3_name s_g3);
  Alcotest.(check (list string))
    "wrong-owner-list carried object on get-then-update: violated = [G3; \
     G4] (:595's owner-list conjunct) - G3 CAN fail"
    [ g3_name; g4_name ] (violated_of family s_g3);
  Alcotest.(check string) "G3 row: first_violated names G3" g3_name
    (first_violated_name s_g3);
  let s_g4 =
    forged
      (vsts_msg ~rpc:0
         (Api_method.Update_request
            { Api_method.namespace = ns; name = pod0_name; obj = update_obj }))
  in
  Alcotest.(check bool) "G4 row: premise fires" true (fires g4_name s_g4);
  Alcotest.(check (list string))
    "forbidden kind (Update_request, the MG1 kind): violated = [G4] ALONE - \
     G4 CAN fail, and strictly (G4 is not G1 && G2 && G3)"
    [ g4_name ] (violated_of family s_g4);
  Alcotest.(check string) "G4 row: first_violated names G4" g4_name
    (first_violated_name s_g4)

(* ==== faithful-emission controls (the reds above are attributable) ========= *)

let test_faithful_emissions () =
  let s_create = forged (vsts_msg ~rpc:0 create_ok) in
  Alcotest.(check bool) "faithful create: G1 premise fires" true
    (fires g1_name s_create);
  Alcotest.(check (list string)) "faithful create: nothing violated" []
    (violated_of family s_create);
  let s_gtd = forged (vsts_msg ~rpc:0 gtd_ok) in
  Alcotest.(check bool)
    "THE Delete_condemned emission (CR's controller owner ref, condemned \
     pod's key): G2 premise fires"
    true (fires g2_name s_gtd);
  Alcotest.(check (list string))
    "THE Delete_condemned emission: nothing violated - byte-what the \
     reconciler emits on this graph, accepted"
    [] (violated_of family s_gtd);
  let s_gtu = forged (vsts_msg ~rpc:0 gtu_ok) in
  Alcotest.(check bool) "faithful get-then-update: G3 premise fires" true
    (fires g3_name s_gtu);
  Alcotest.(check (list string))
    "faithful get-then-update: nothing violated" [] (violated_of family s_gtu)

(* ==== MS5: premise wiring over the REAL SL0 graph (the MG7 port) ==========
   Evaluated over the SL0 replica - the graph t_p22_scaledown pins - so the
   0s below are measured on the phase's own graph, not on a forged state. *)

let sl0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (Mc.explore ~depth
       ~successors:
         (Fc.faulted_successors bound P22_witness.zero_budget cluster)
       ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
       ~init:
         [
           Fc.faulted_of_seed
             (Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true
                ~req_drop:false ~pod_monkey:false ());
         ])

let count_interesting (reach : Fc.faulted Mc.reachable)
    (fam : Invariants.invariant list) (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      member_interesting fam name f.cs)

let count_reds (reach : Fc.faulted Mc.reachable)
    (fam : Invariants.invariant list) (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      not (member_holds fam name f.cs))

let test_ms5_premise_wiring () =
  let reach = Lazy.force sl0_reach in
  (* replica faithfulness FIRST: a drifted replica would silently measure a
     different graph (the P13 M3/M5 precedent). *)
  Alcotest.(check int) "MS5: replica states = the SL0 pin"
    P22_witness.sl0_states (Mc.states_seen reach);
  (* the contrast, at the RIGHT id: G2 live at its pinned count. *)
  Alcotest.(check int)
    "MS5 contrast: G2 interesting at the true controller id = the SL0 pin"
    P22_witness.g2_interesting_sl0
    (count_interesting reach family g2_name);
  let family_wrong_id : Invariants.invariant list =
    Ig.guarantee_family ~cr ~controller_id:(controller_id + 1)
  in
  List.iter
    (fun (name : string) ->
      Alcotest.(check int)
        (name
       ^ ": interesting = 0 over ALL of SL0 at controller_id + 1 (the \
          premise keys on the id - no green-by-accident)")
        0
        (count_interesting reach family_wrong_id name);
      Alcotest.(check int)
        (name
       ^ ": red = 0 over ALL of SL0 at controller_id + 1 - vacuous TRUTH, \
          not vacuous falsity (the MG7 datum, on the new graph)")
        0
        (count_reds reach family_wrong_id name))
    [ g1_name; g2_name; g3_name; g4_name ]

let () =
  Alcotest.run "p22_mutation"
    [
      ( "family_shape",
        [
          Alcotest.test_case "names / cardinal / by-name addressing" `Quick
            test_family_shape;
        ] );
      ( "red_capability",
        [
          Alcotest.test_case
            "every member SEEN to fail on forged P22-seed states (G2's row \
             = MS1's observable)"
            `Quick test_red_capability;
        ] );
      ( "faithful_emissions",
        [
          Alcotest.test_case
            "the reconciler's own shapes accepted, incl. THE \
             Delete_condemned emission"
            `Quick test_faithful_emissions;
        ] );
      ( "ms5_premise_wiring",
        [
          Alcotest.test_case
            "controller_id + 1 sees NOTHING over the real SL0 graph \
             (vacuous truth; replica pinned first)"
            `Quick test_ms5_premise_wiring;
        ] );
    ]

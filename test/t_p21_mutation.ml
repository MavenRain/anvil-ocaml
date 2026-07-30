(* BUILD-SPEC-P21 section 5 - confirm-by-mutation for the internal-GUARANTEE
   family (G1 [vsts_internal_guarantee_create_req] / G2
   [vsts_internal_guarantee_get_then_delete_req] / G3
   [vsts_internal_guarantee_get_then_update_req] / G4
   [no_interfering_request_between_vsts], asserted GREEN by t_p21_guarantee's
   legs).

   WHY THIS EXE EXISTS, and why its matrix is RECORDED rather than re-run.
   P21's legs come back CLEAN, so the burden is the P14-P19 one: a green is
   only evidence if the verdict would MOVE when what the family classifies
   breaks. But every P21 mutant is a RECONCILER mutation whose observable is
   a full five-graph re-exploration (~2 minutes at baseline; row MG5 ran
   8h22m without completing even L0), so the matrix rows were run MANUALLY -
   Edit apply / probe / Edit revert / [git diff --stat] empty, per row (the
   t_p20_mutation manual-row protocol) - and their MEASURED results are
   RECORDED below as the permanent record. What runs on every battery pass
   is the AUTOMATED section after the matrix: state-level shape rows that
   exercise the same registers through forged states in milliseconds,
   including the red-capability and family-order facts the matrix measured
   at leg level.

   ==== PROVENANCE OF THE MATRIX, stated honestly ============================

   Rows MG1-MG4 were run by the measurement agent, which was then KILLED by
   the session token limit BETWEEN MG5's apply and its probe run - the exact
   die-between-apply-and-restore failure mode - leaving the MG5 mutant LIVE
   in the tree. The orphan was detected by [git status], reverted by [Edit],
   and every completed row's revert was verified [git diff --stat]-empty in
   the agent transcript before its numbers were salvaged. MG5-MG7 were then
   completed inline under the same per-row protocol. Post-matrix: the MG7
   run doubled as the final pin re-check on the reverted tree - all five
   pins OK, all four legs clean and decisive - so the matrix left no
   residue. Authoritative tabulation: BUILD-SPEC-P21 section 8.1.

   ==== the MEASURED matrix (baseline pins 76/464/744/1976/116, all rows
        judged against the section-4/5 predictions) =========================

   MG1  [Update_request] swap at v_stateful_set_reconciler.ml:697 (the
        rolling-update emission de-tupled to a plain update). REFUTED on all
        four legs, [violated] = G4. ALL FIVE pins MOVED: 72/452/736/1752/112
        (the mutant changes the emission repertoire, hence the graphs).
        Member reds: G4 ONLY - 4/16/8/200/4 across L0/Lc/Ld/Lm/L0v; G1 = G2
        = G3 = 0 everywhere. CONFIRMED - THE STRICTNESS ROW: G4 is NOT
        [G1 && G2 && G3]; no other member sees the forbidden kind. (This is
        the design point that avoids repeating P20 review-finding A: the
        analogous identity here is FALSE on purpose, and no identity pin is
        shipped anywhere.)

   MG2  [make_owner_references] -> [[]] (:218-220). REFUTED on all four
        legs, [violated] = G1 (family order). Pins: 76 OK / 444 MOVED /
        744 OK / 1928 MOVED / 116 OK. Member reds: G1 = G4 at
        8/80/32/208/8. CONFIRMED (G1 RED on the Pod arm's singleton
        owner-ref test :568-571; G4 red via containment).

   MG3  [make_pvc] given an owner ref (:279-286). All four legs CLEAN, all
        five pins OK - the mutant is LEG-INVISIBLE - and reds appear ONLY on
        the L0v replica: G1 red = 4, G4 red = 4 (G2 = G3 = 0). PARTLY
        REFUTED: the spec predicted "G1 RED (:575) only"; measured, that was
        wrong TWICE - the red exists only on the vct:true L0v replica (the
        leg's no-[?vct] cut makes the PVC arm dead on all four leg graphs),
        and G4 reds too. THIS ROW IS THE MEASURED JUSTIFICATION FOR THE
        REPLICA-ONLY FIFTH ROW in t_p21_guarantee.

   MG4  non-invertible pod name at :377. REFUTED on all four legs,
        [violated] = G1. Numerically IDENTICAL to MG2: pins 76 OK / 444
        MOVED / 744 OK / 1928 MOVED / 116 OK, G1 = G4 reds 8/80/32/208/8
        (L0v: G1 interesting 12, red 8). CONFIRMED (G1 RED via
        [pod_name_match]); the MG2-identity is itself a datum - both
        mutants collapse to "the created pod fails the same three-conjunct
        Pod arm".

   MG5  create namespace off-CR (:650). UNMEASURABLE: STATE-SPACE BLOW-UP.
        The probe ran 8h22m wall-clock at ~91% CPU (866 MB RSS, actively
        exploring, not wedged) without completing even L0, against ~2
        minutes for the full five-graph baseline; killed deliberately.
        Mechanism: pods created in the off-CR namespace are INVISIBLE to
        the reconciler's own list/get, so reconcile never converges and the
        bounded product explodes. The blow-up IS the row's datum - the
        mutant is behaviorally catastrophic long before any invariant is
        evaluated - and :563's red remains formally UNWITNESSED at this
        bound. (The automated wrong-namespace row below reds :563 at state
        level, which is the register's only cheap witness.)

   MG6  wrong owner ref on the [Get_then_delete] emission (:734). INERT:
        all four legs CLEAN, all five pins OK, zero red anywhere - the
        table is numerically IDENTICAL to baseline. The section-5
        prediction (G2 RED) is REFUTED BY VACUITY: G2 [interesting] = 0 on
        every committed graph (t_p21_guarantee's honest-vacuity case), so
        [Delete_condemned] is dead code at [desired = 1] and the mutated
        request never enters any graph. The honest reading, disclosed, not
        narrowed away; a G2-exercising scenario (scale-down) is P22
        material. (The automated G2 rows below exercise the G2 PREDICATE at
        state level - the only place in the tree it is exercised at all.)

   MG7  the family instantiated at [~controller_id:(Scenario.controller_id
        + 1)] - probe-side, permanently in probe/zz_p21_probe.ml's MG7
        block, since the family is a test-side instantiation and there is
        nothing in lib/ to mutate. Replica evaluation over L0 and Lm (same
        graphs, 76/1976): [interesting] = 0 AND red = 0 for ALL FOUR
        members on both. CONFIRMED - THE PREMISE-NECESSITY ROW: every
        member keys on [controller_id], so the family cannot be
        green-by-accident at the wrong id; and red = 0 (not red = all)
        confirms vacuous TRUTH, not vacuous falsity. (Echoed at state level
        below, where it runs on every battery pass.)

   ==== the AUTOMATED rows (permanent; run on every battery pass) ============

   Every row is a single forged state - the legs' own seed with its
   in-flight pool replaced by ONE controller-sourced request - so each
   verdict is attributable to one request shape, the F-row discipline of
   t_p20_mutation:

   - G4-STRICTNESS: each of the four FORBIDDEN kinds ([Delete_request],
     [Update_request], [Update_status_request],
     [Get_then_update_status_request] - upstream's [_ => false] at :556,
     spelled out) reddens G4 ALONE, with a FAITHFUL pod payload so the red
     is attributable to the KIND. The MG1 shape, at state level, and the
     proof that prediction 2's "reachable-but-unfired" arm CAN fire.
   - READ-ONLY arms (:551): [Get_request] / [List_request] leave all four
     members green with G4's premise firing - accepted controls.
   - DISCRIMINATION: the reconciler's own emission shapes (a [make_pod]
     create, a well-formed get-then-delete, a well-formed get-then-update)
     are ACCEPTED with the owning member's premise firing - including G2's,
     which no committed graph exercises (the MG6 vacuity counterpoint: the
     predicate is red- AND green-capable even though the register is
     graph-dead at desired = 1).
   - FAMILY-ORDER ([violated_of] semantics, through the EXPORTED
     {!Invariants.first_violated}): a wrong-namespace create reds G1 AND G4
     and [first_violated] names G1 (the MG2/MG4 leg datum: first violated
     member wins, family order); a wrong-owner get-then-delete reds G2 AND
     G4 and names G2; the forbidden-kind rows red G4 alone and name G4 (the
     MG1 datum).
   - PREMISE NECESSITY (the MG7 echo): the same family at [controller_id +
     1], and at a non-CR key, sees NOTHING - [interesting] false and
     [holds] true (vacuous truth) on the faithful-create state, all four
     members.

   TEST-ORDERING RULE (P12 finding 1): semantic facts first, and there are
   no brittle counts here at all - every assertion is a bool or a name
   list; the only witness constant read is the family cardinal.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum, no two-arm match on
   [option]/[result], total accessors only, no exceptions, Alcotest as the
   sanctioned failure primitive. *)

module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Ig = Anvil_assurance.Internal_guarantee
module Vsr = V_stateful_set_reconciler

let controller_id : int = Scenario.controller_id
let desired : int = P21_witness.witness_desired
let cr : V_stateful_set.t = Scenario.vsts ~desired ()
let family : Invariants.invariant list = Ig.guarantee_family ~cr ~controller_id

let g1_name : string = "vsts_internal_guarantee_create_req"
let g2_name : string = "vsts_internal_guarantee_get_then_delete_req"
let g3_name : string = "vsts_internal_guarantee_get_then_update_req"
let g4_name : string = "no_interfering_request_between_vsts"

(* ---- per-state family projections (t_p20_mutation's exact shapes) --------- *)

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

(* The FAMILY-ORDER projection, through the EXPORTED
   {!Invariants.first_violated} - the same function the leg's [violated]
   naming rides - so the ordering facts below pin the semantics the matrix
   rows MG1/MG2/MG4 recorded at leg level. *)
let first_violated_name (s : Cluster.cluster_state) : string =
  Option.fold
    (Invariants.first_violated family s)
    ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ==== the forged-state base: the legs' own seed, in-flight pool replaced === *)

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ()

(* ---- the CR's own coordinates, READ off the CR, never typed --------------- *)

let cr_md : Object_meta.t = V_stateful_set.metadata cr
let ns : string = Option.value ~default:"" (Object_meta.namespace cr_md)
let parent : string = Option.value ~default:"" (Object_meta.name cr_md)

(* The CR key the family's premise compares message sources against, rebuilt
   with the .mli-disclosed [Option.value ~default:""] rendering
   ([Ig.cr_key_of] is private). The premise-fires assertions below redden if
   the two renderings ever drift. *)
let cr_key : Common.object_ref =
  { Common.kind = V_stateful_set.kind; name = parent; namespace = ns }

let vsts_owner : Owner_reference.t =
  Option.value
    (V_stateful_set.controller_owner_ref cr)
    ~default:(Owner_reference.default ())

let vsts_msg ~(rpc : int) (r : Api_method.api_request) : Message.t =
  Message.controller_req_msg controller_id cr_key (Message.Rpc_id.of_int rpc) r

let forged (m : Message.t) : Cluster.cluster_state =
  { seed with Cluster.network = { Network.in_flight = Message.Pool.singleton m } }

(* ---- payload construction -------------------------------------------------
   The reconciler's REAL [make_pod] object (t_p20_mutation's discipline: the
   spec/status reads are never test-local fictions), metadata adjusted only
   where a row is ABOUT the adjustment. *)

let base_pod : Pod.t = Vsr.make_pod cr 0
let pod0_name : string = Vsr.pod_name parent 0

let pod0_key : Common.object_ref =
  { Common.kind = Pod.kind; namespace = ns; name = pod0_name }

(* G3's :590-591 agreement clauses need the carried object's name AND
   namespace to match the request's, and its :595 needs the owner list to be
   exactly the request's own ref - so the well-formed update payload fixes
   all three fields explicitly. *)
let update_obj : Dynamic_object.t =
  let md : Object_meta.t = Pod.metadata base_pod in
  Pod.marshal
    (Pod.with_metadata
       {
         md with
         Object_meta.name = Some pod0_name;
         generate_name = None;
         namespace = Some ns;
         owner_references = Some [ vsts_owner ];
       }
       base_pod)

let create_ok : Api_method.api_request =
  Api_method.Create_request
    { Api_method.namespace = ns; obj = Pod.marshal base_pod }

let create_wrong_ns : Api_method.api_request =
  Api_method.Create_request
    { Api_method.namespace = ns ^ "-p21-elsewhere"; obj = Pod.marshal base_pod }

let gtd_ok : Api_method.api_request =
  Api_method.Get_then_delete_request
    { Api_method.key = pod0_key; owner_ref = vsts_owner }

let gtd_wrong_owner : Api_method.api_request =
  Api_method.Get_then_delete_request
    { Api_method.key = pod0_key; owner_ref = Owner_reference.default () }

let gtu_ok : Api_method.api_request =
  Api_method.Get_then_update_request
    {
      Api_method.namespace = ns;
      name = pod0_name;
      owner_ref = vsts_owner;
      obj = update_obj;
    }

(* The four FORBIDDEN kinds - upstream's [_ => false] at :556, spelled out
   (the comment at :555 names only three; the rendering follows the CODE).
   Each carries the FAITHFUL pod payload / key, so the red is attributable
   to the request KIND alone. *)
let forbidden_kinds : (string * Api_method.api_request) list =
  [
    ( "Delete_request",
      Api_method.Delete_request
        { Api_method.key = pod0_key; preconditions = None } );
    ( "Update_request (the MG1 kind)",
      Api_method.Update_request
        { Api_method.namespace = ns; name = pod0_name; obj = update_obj } );
    ( "Update_status_request",
      Api_method.Update_status_request
        { Api_method.namespace = ns; name = pod0_name; obj = update_obj } );
    ( "Get_then_update_status_request",
      Api_method.Get_then_update_status_request
        {
          Api_method.namespace = ns;
          name = pod0_name;
          owner_ref = vsts_owner;
          obj = update_obj;
        } );
  ]

let read_only_arms : (string * Api_method.api_request) list =
  [
    ("Get_request", Api_method.Get_request { Api_method.key = pod0_key });
    ( "List_request",
      Api_method.List_request
        { Api_method.kind = Pod.kind; namespace = ns } );
  ]

(* ==== the family shape rows ================================================ *)

let test_family_shape () =
  Alcotest.(check (list string))
    "guarantee_family = the four member names, in family order"
    [ g1_name; g2_name; g3_name; g4_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family);
  Alcotest.(check int) "guarantee_family cardinal"
    P21_witness.guarantee_cardinal (List.length family);
  Alcotest.(check (list string))
    "member sources = guarantee_sources, same order" Ig.guarantee_sources
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.source) family);
  (* each tag findable BY NAME - the loud-on-missing guard every by-name
     projection in this exe and in t_p21_guarantee rides. *)
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

(* ==== G4-strictness: the forbidden kinds red G4 ALONE ====================== *)

let test_forbidden_kinds () =
  List.iter
    (fun ((label, req) : string * Api_method.api_request) ->
      let s = forged (vsts_msg ~rpc:0 req) in
      Alcotest.(check bool) (label ^ ": G4 premise fires") true
        (fires g4_name s);
      Alcotest.(check (list string))
        (label
       ^ ": violated = [G4] ONLY - G4 is NOT G1 && G2 && G3 (the MG1 \
          strictness datum, at state level; also the SEEN witness that \
          prediction 2's forbidden-kind arm CAN fire)")
        [ g4_name ] (violated_of family s);
      Alcotest.(check string)
        (label ^ ": first_violated names G4 (sole violated member)")
        g4_name (first_violated_name s))
    forbidden_kinds

(* ==== the read-only arms are accepted with the premise firing ============== *)

let test_read_only_arms () =
  List.iter
    (fun ((label, req) : string * Api_method.api_request) ->
      let s = forged (vsts_msg ~rpc:0 req) in
      Alcotest.(check bool)
        (label ^ ": G4 premise fires (the :551 arm is exercised, not absent)")
        true (fires g4_name s);
      Alcotest.(check (list string))
        (label ^ ": nothing violated - the read-only arms are CONTENT")
        [] (violated_of family s))
    read_only_arms

(* ==== discrimination: the reconciler's own shapes are accepted ============= *)

let test_faithful_emissions () =
  let s_create = forged (vsts_msg ~rpc:0 create_ok) in
  Alcotest.(check bool) "faithful create: G1 premise fires" true
    (fires g1_name s_create);
  Alcotest.(check bool) "faithful create: G4 premise fires" true
    (fires g4_name s_create);
  Alcotest.(check (list string))
    "faithful create: nothing violated (make_pod's own object passes its own \
     guarantee)"
    [] (violated_of family s_create);
  let s_gtd = forged (vsts_msg ~rpc:0 gtd_ok) in
  Alcotest.(check bool)
    "faithful get-then-delete: G2 premise FIRES - the G2 register exercised \
     at state level, which NO committed graph does (the MG6 vacuity \
     counterpoint)"
    true (fires g2_name s_gtd);
  Alcotest.(check (list string))
    "faithful get-then-delete: nothing violated" [] (violated_of family s_gtd);
  let s_gtu = forged (vsts_msg ~rpc:0 gtu_ok) in
  Alcotest.(check bool) "faithful get-then-update: G3 premise fires" true
    (fires g3_name s_gtu);
  Alcotest.(check (list string))
    "faithful get-then-update: nothing violated" [] (violated_of family s_gtu)

(* ==== family-order semantics of the violated naming ======================== *)

let test_family_order () =
  let s_g1 = forged (vsts_msg ~rpc:0 create_wrong_ns) in
  Alcotest.(check (list string))
    "wrong-namespace create: violated = [G1; G4] in FAMILY order (the :563 \
     conjunct at state level - the only cheap witness MG5's blow-up left \
     that register)"
    [ g1_name; g4_name ] (violated_of family s_g1);
  Alcotest.(check string)
    "wrong-namespace create: first_violated names G1 - first violated member \
     wins, family order (the MG2/MG4 leg datum)"
    g1_name (first_violated_name s_g1);
  let s_g2 = forged (vsts_msg ~rpc:0 gtd_wrong_owner) in
  Alcotest.(check (list string))
    "wrong-owner get-then-delete: violated = [G2; G4] in family order (the \
     :585 conjunct red- AND green-capable despite the register being \
     graph-dead at desired = 1)"
    [ g2_name; g4_name ] (violated_of family s_g2);
  Alcotest.(check string)
    "wrong-owner get-then-delete: first_violated names G2, not G4 - the \
     order is FAMILY order, not G4-always"
    g2_name (first_violated_name s_g2)

(* ==== premise necessity (the MG7 echo, on every battery pass) ============== *)

let test_premise_necessity () =
  let s = forged (vsts_msg ~rpc:0 create_ok) in
  let family_wrong_id : Invariants.invariant list =
    Ig.guarantee_family ~cr ~controller_id:(controller_id + 1)
  in
  List.iter
    (fun (name : string) ->
      Alcotest.(check bool)
        (name ^ ": interesting FALSE at controller_id + 1 (the premise keys \
                 on the id)")
        false
        (member_interesting family_wrong_id name s);
      Alcotest.(check bool)
        (name ^ ": holds TRUE at controller_id + 1 - vacuous TRUTH, not \
                 vacuous falsity (the MG7 red = 0 datum)")
        true
        (member_holds family_wrong_id name s))
    [ g1_name; g2_name; g3_name; g4_name ];
  (* the OTHER half of the premise: the CR key. A message from the right id
     but a different key is out of premise too. *)
  let other_key : Common.object_ref =
    { Common.kind = V_stateful_set.kind; name = parent ^ "-other"; namespace = ns }
  in
  let s_other =
    forged
      (Message.controller_req_msg controller_id other_key
         (Message.Rpc_id.of_int 0) create_ok)
  in
  Alcotest.(check bool)
    "G1: interesting FALSE at a non-CR source key (the premise keys on the \
     CR key too)"
    false
    (member_interesting family g1_name s_other);
  Alcotest.(check bool)
    "G4: interesting FALSE at a non-CR source key" false
    (member_interesting family g4_name s_other);
  Alcotest.(check bool) "G4: holds TRUE at a non-CR source key (vacuous truth)"
    true
    (member_holds family g4_name s_other)

let () =
  Alcotest.run "p21_mutation"
    [
      ( "family_shape",
        [
          Alcotest.test_case "names / cardinal / sources / by-name addressing"
            `Quick test_family_shape;
        ] );
      ( "g4_strictness",
        [
          Alcotest.test_case
            "the four forbidden kinds red G4 ALONE (the MG1 shape)" `Quick
            test_forbidden_kinds;
          Alcotest.test_case
            "the read-only arms are accepted with the premise firing" `Quick
            test_read_only_arms;
        ] );
      ( "discrimination",
        [
          Alcotest.test_case
            "the reconciler's own emission shapes are accepted (incl. the \
             graph-dead G2 register)"
            `Quick test_faithful_emissions;
        ] );
      ( "family_order",
        [
          Alcotest.test_case
            "violated naming is family-order, first violated wins (the \
             MG1/MG2/MG4 datum)"
            `Quick test_family_order;
        ] );
      ( "premise_necessity",
        [
          Alcotest.test_case
            "wrong controller id / wrong CR key see nothing - vacuous truth \
             (the MG7 echo)"
            `Quick test_premise_necessity;
        ] );
    ]

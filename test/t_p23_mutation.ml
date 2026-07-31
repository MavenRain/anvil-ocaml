(* BUILD-SPEC-P23 section 5 - confirm-by-mutation for the controller-LOCAL
   binding register: the matrix that makes t_p23_local_binding's green MEAN
   something. A pin never SEEN to fail is not evidence, and section 8.8 records
   that NOT ONE row of this matrix had been run when the measurements landed.
   This exe closes the rows that can be closed AUTOMATICALLY, and says plainly
   which rows are still open and what they would cost.

   ==== the matrix (BUILD-SPEC-P23 section 5) ================================

   MB1  HEADLINE, and the ONLY row that earns L2 its keep: make the reconciler
        emit its pod [List_request] in a FOREIGN namespace
        (v_stateful_set_reconciler.ml:528-531). PREDICT: BL0 flips clean ->
        Refuted naming L2, via [list_req_content_matches] failing
        [String.equal lr.namespace namespace] (upstream :648-651). The whole
        P21 register is BLIND to it: G4's read-only arm is
        [ListRequest(_) | GetRequest(_) => true] (upstream :551), so a
        wrong-namespace list is invisible to G1-G4. STATUS: RUN, and KILLED
        (BUILD-SPEC-P23 section 8.10). The source mutant at
        [v_stateful_set_reconciler.ml:531] flips BL0 CLEAN -> REFUTED with
        [violated] naming L2, and the replica attribution on BL0 is L2
        [interesting] 16 / red 16 while L1 goes OUT OF PREMISE (interesting 0,
        red 0), because a list scoped to a foreign namespace comes back empty
        and [partition_pods] never populates [needed]/[condemned]. The P21
        control HOLDS in its corrected form: under the same mutant
        [t_p21_guarantee] is entirely CLEAN with [violated = None], so a
        wrong-namespace pod list is invisible to G1-G4 AS A RED, while still
        perturbing their graph-size and premise-vacuity pins. Its STATE-LEVEL
        observable IS also closed below, in [red_capability]: a state parked at
        [After_list_pod] whose pending request is a pod list in a foreign
        namespace reds L2 and leaves L1 GREEN. That is strictly weaker than the
        source mutant - it proves the conjunct is red-capable, not that the
        reconciler can reach such a state - and it is labelled that way rather
        than sold as MB1.

   MB2  L1 red-capability, and it is genuinely hard: L1's name conjunct is
        close to UNFALSIFIABLE by construction, because [condemned] is built by
        [partition_pods] via [get_ordinal] and L1's [pod_name_match] rendering
        is INVERSION through that SAME [get_ordinal], so any mutation moves
        both sides in lockstep. BUILD-SPEC-P23 section 7: if L1 cannot be SEEN
        red, it must be DOWNGRADED to EXCLUDE-WITH-A-PIN. STATUS: RUN, and
        KILLED, so that conditional is NOT triggered and L1 ships as a member
        (BUILD-SPEC-P23 section 8.10). The recipe section 5 handed forward - a
        decoupled [partition_pods:411] plus a [Bound.monkey_forge] rogue pod -
        is WRONG, and was MEASURED to SURVIVE: [pod_filter] (:421-432) ALREADY
        requires [get_ordinal] to parse, so the defaulted-ordinal branch is
        unreachable and the decoupling does not decouple. Do NOT follow it; a
        SURVIVED reading of it would pull a member that has been seen red. The
        recipe that KILLS is THREE coordinated sites in
        v_stateful_set_reconciler.ml and NO [monkey_forge] entry at all: mint
        an unparseable pod name at :376 ([pod_name parent ordinal] ->
        [... ^ "-mb2"]), make [pod_filter]'s name-parse conjunct at :430-432
        trivially true so the rogue name is not rejected, and decouple
        [partition_pods] at :411 so it is not dropped. With those three, BL0
        goes REFUTED naming L1 with L1 red = 32. The state-level half IS also
        closed below: a decoded local state whose [condemned] carries a
        foreign-namespace pod, and one whose [needed] slot carries a
        non-inverting name, each red L1.

   MB3  ATTRIBUTION DATUM, expected to be UNFLATTERING: the MB2 mutant with the
        leg's [violated] name recorded. PREDICT: [violated] names L1 and L2 -
        strictly stronger and ALSO false there - reports nothing, because
        [Invariants.first_violated] (invariants.ml:1046) returns the FIRST
        member in list order. STATUS: RUN under the MB2-b mutant and MEASURED
        (BUILD-SPEC-P23 section 8.10): on BL0 L1 is [interesting] 64 / red 32 /
        [nholds] 32 while L2 is [interesting] 16 / red 0 / [nholds] 32 - the
        containment confirmed on live states, with only the UNGATED [holds]
        column showing L2 false. CLOSED below at state level in
        [containment_attribution], through the SAME exported
        [Invariants.first_violated] the leg's naming rides.

   MB4  TRAP ROW (negative control): the MB1 namespace mutation applied to a
        request that is NOT the pod list - the [Get_then_delete] key's
        namespace (:732-739). PREDICT, CORRECTED against what section 8.10
        measured: L2 stays GREEN on every leg (its list-request conjunct
        constrains only the PENDING list request at [After_list_pod]) AND the
        P21 register stays GREEN too; only premise-vacuity floors and
        graph-size pins move. The section-5 wording "while the P21 register
        reds" is FALSE and is retracted here: [t_p21_guarantee] is entirely
        GREEN under MB4. STATUS: RUN, and the TRAP HELD - L2 red = 0 on BL0 and
        BLc, leg CLEAN, [violated] none; what moved was P22's G2
        premise-vacuity floor plus P23's own graph-size pin (BL0 88 -> 100).
        Its state-level analogue IS closed below: a parked state whose
        pending request is a foreign-namespace [Get_then_delete] leaves BOTH
        members' [holds] alone in the direction that matters - L2's premise is
        [After_list_pod] AND pending, and the CONTENT test is what reds - so
        "a red anywhere is not L2 coverage" is exhibited rather than asserted.

   MB5  PREMISE WIRING (= P21's MG7 / P22's MS5 port; in-test, RUNS BELOW on
        every battery pass): the family instantiated at [controller_id + 1],
        evaluated over the REAL BL0 replica. PREDICT: both members'
        [interesting] = 0 AND red = 0 - vacuous TRUTH, not vacuous falsity.
        Mechanism: [Cluster.ongoing_reconciles] is TOTAL and yields the empty
        map for a missing id (cluster.mli:78-82), so [find_opt] is [None] at
        every state and the [~absent] fold takes over. MEASURED below.

   MB6  FOLD-DIRECTION mutant, targeting a fold nothing else tests: flip L1's
        decode arm from [~undecodable:true] to [~undecodable:false]
        (local_binding.ml:311 - and note the spec's own MB6 wording is STALE,
        corrected at BUILD-SPEC-P23 section 8.9: the skeleton is factored into
        [at_reconcile], so the single-token mutant is the labelled argument,
        not a [~error:(fun _ -> true)] literal). PREDICT: BYTE-IDENTICAL
        results on every P23 graph, because decode failures are 0
        (t_p23_local_binding's [premise_counters] pins that). An identical
        result is exactly what PROVES the counter; a different one refutes
        prediction 4 and is the more interesting outcome. STATUS: RUN. It
        SURVIVED every shipped leg BYTE-FOR-BYTE at graph level, exactly as
        predicted (that fold is dead code where decode failures are 0, and a
        mutation of dead code cannot be killed by a graph assertion however
        exact), and it was then KILLED at UNIT level by
        [mb6_decode_failure_fold] below (BUILD-SPEC-P23 section 8.10).

   MB7  THE PVCS-EXCLUSION PIN's RED CAPABILITY (in-test, RUNS BELOW): a
        THROWAWAY [vct:true] seed. PREDICT: the pvcs-are-empty pin REDDENS,
        because [make_pvcs] (:292-296) is [Option.value ~default:[]
        sp.volume_claim_templates] mapped and filtered, so it is [[]] only
        while [volume_claim_templates] is [None]. Without this row, "excluded
        with a pin" means "omitted". MEASURED below - as a FLOOR, not a pin:
        the [vct:true] graph is a throwaway control that no shipped leg
        explores, and committing its size would be a pin nothing can move.

   MB8  THE BARE-SOURCE TRAP, a documentation-integrity control (in-test, RUNS
        BELOW): append a parenthetical qualifier to a source string. PREDICT:
        [t_p21_regression]'s [line_of_source] (:358-362) returns [None], the
        member silently DROPS OUT of [roster_guarantee_lines], and a firewall
        phrased only as "no EXCLUDED line is shipped" still PASSES while the
        member is invisible. That vacuous green is the failure this row
        exhibits. The positive half now lives where it belongs - in
        t_p21_regression, which asserts that the roster's parsed line COUNT
        equals the ledger's shipped cardinal and that both P23 lines are
        PRESENT - and this row is what proves that assertion has teeth.

   MB9  L2's INNER-FORALL CONSEQUENT (in-test, RUNS BELOW), the row the
        four-lens review of this phase found MISSING: upstream :659-661
        ([resp_objs_in_namespace], local_binding.ml:206-212) is TRUE at every
        state of all four shipped graphs - both members' reds are pinned 0
        there, which IS that statement - and NO other row in this file reaches
        it, because [forge] sets only [pending_req_msg] and [local_state], so
        [ok_list_resps_for] returns [] and [List.for_all] over [] is vacuously
        TRUE. A WEAKENING of :659-661 ([Option.equal String.equal om.namespace
        (Some namespace)] -> [Option.is_some om.namespace]) therefore moved
        NOTHING in the whole phase. PREDICT: an in-flight ok [List_response]
        formed FROM the parked pod-list request, carrying one
        [Dynamic_object] whose namespace is NOT the CR's, reds L2 - and the
        SAME shape carrying the CR's own namespace stays GREEN. MEASURED below
        in [mb9_inner_consequent], and CONFIRMED by re-running that case under
        the weakening mutant above, where it fails true/false.

   A mutant killed by a BUILD ERROR or by a TIMEOUT is NOT caught - reshape it
   (house rule). Every row below that claims a red is SEEN red in the same
   assertion block as its accepted control, so no red is attributable to a
   broken injection.

   ==== what the AUTOMATED rows are, and what they are NOT ===================

   The forged-state rows are STATE-LEVEL red capability for NAMED conjuncts,
   on states built from THIS phase's own seed with the reconciler's OWN
   [make_pod] payloads. They are NOT a blanket "each member's conjuncts CAN be
   false"; the honest enumeration is:
   - L1's six sub-conjuncts, upstream :619-621 (needed) and :625-627
     (condemned), one row each in [red_capability] (MB2-a .. MB2-f);
   - L2's :645 (the pending slot is OCCUPIED) and :647-651 (the pending
     request is a pod [List_request] in the CR's namespace), by the MB1
     state-level row with its accepted counterpart, and MB4 as the trap that
     shows a red elsewhere is not coverage of them;
   - L2's INNER FORALL CONSEQUENT, upstream :659-661, by
     [mb9_inner_consequent] - and, because that row's red DEPENDS on its
     forged response being SELECTED by the :652-657 premise, a narrowing of
     any premise conjunct turns that red into a vacuous green, which is
     exactly what the row's own [ok_list_resps_for] controls assert against.
   What NO row falsifies, said plainly rather than left to be assumed:
   upstream :646 ([pending_req_msg.dst] is the api server) has no row of its
   own, both MB1's and MB4's requests being controller-formed and so addressed
   there by construction; and the pvcs forall :629-637 is EXCLUDED WITH A PIN
   whose red capability is MB7's, not a conjunct row's.
   None of these rows prove the port can REACH such a state - only a source
   mutant re-explored over the graph does that. MB1 and MB2 are those rows and
   both are now RUN and KILLED (BUILD-SPEC-P23 section 8.10); MB9's state is
   reachable-by-forgery only, and is labelled that way. Saying so is the point;
   the repo's recurring overclaim class is recorded at
   BUILD-SPEC-P22.md:113-119.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum, no two-arm match on
   [option]/[result], total accessors only, no exceptions, Alcotest as the
   sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Lb = Anvil_assurance.Local_binding
module Vsr = V_stateful_set_reconciler
module Pack = V_stateful_set_pack

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P23_witness.witness_desired
let ordinals : int list = P23_witness.p23_ordinals
let depth : int = P23_witness.witness_depth
let bound : Bound.t = P23_witness.p23_bound ~desireds:[ desired ]
let cr : V_stateful_set.t = Scenario.vsts ~desired ()
let family : Invariants.invariant list = Lb.binding_family ~cr ~controller_id
let l1_name : string = P23_witness.l1_name
let l2_name : string = P23_witness.l2_name

(* ---- per-state family projections (t_p21_mutation / t_p22_mutation shapes) - *)

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

(* The FAMILY-ORDER projection through the EXPORTED {!Invariants.first_violated}
   - the same function the leg's [violated] naming rides (fault_check.ml:249-258
   -> invariants.ml:1046), so MB3's prediction is pinned by the same semantics
   the leg would use. *)
let first_violated_name (s : Cluster.cluster_state) : string =
  Option.fold
    (Invariants.first_violated family s)
    ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ==== the CR's own coordinates, READ off the CR, never typed =============== *)

let cr_md : Object_meta.t = V_stateful_set.metadata cr
let ns : string = Option.value ~default:"" (Object_meta.namespace cr_md)
let parent : string = Option.value ~default:"" (Object_meta.name cr_md)

let cr_key : Common.object_ref =
  { Common.kind = V_stateful_set.kind; name = parent; namespace = ns }

(* ==== the forged-state base: THIS phase's seed, ongoing reconcile INSTALLED ==
   [Cluster.cluster_state] and [Controller.state] are plain public records
   (cluster.mli:19-36, controller.mli:66-73), so the injection is a record
   update, not a state-machine step. The installation is CONTROLLED below: the
   [Imap] entry could be absent, in which case [install] would return the seed
   UNCHANGED and every red row would silently become a green about nothing -
   so each row asserts the injection LANDED before it reads a verdict. *)

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true ~req_drop:false
    ~pod_monkey:false ()

let install (orc : Controller.ongoing_reconcile) : Cluster.cluster_state =
  Option.fold
    (Imap.find_opt controller_id seed.Cluster.controller_and_externals)
    ~none:seed
    ~some:(fun (ce : Cluster.controller_and_external) ->
      let cs : Controller.state = ce.Cluster.controller in
      {
        seed with
        Cluster.controller_and_externals =
          Imap.add controller_id
            {
              ce with
              Cluster.controller =
                {
                  cs with
                  Controller.ongoing_reconciles =
                    Object_ref_map.add cr_key orc
                      cs.Controller.ongoing_reconciles;
                };
            }
            seed.Cluster.controller_and_externals;
      })

let reconcile_state ~(step : Vsr.step) ~(needed : Pod.t option list)
    ~(condemned : Pod.t list) : Vsr.s =
  {
    Vsr.reconcile_step = step;
    needed;
    needed_index = 0;
    condemned;
    condemned_index = 0;
    pvcs = [];
    pvc_index = 0;
  }

let forge ~(step : Vsr.step) ~(needed : Pod.t option list)
    ~(condemned : Pod.t list) ~(pending : Message.t option) :
    Cluster.cluster_state =
  install
    {
      Controller.triggering_cr = V_stateful_set.marshal cr;
      pending_req_msg = pending;
      local_state = Pack.marshal_state (reconcile_state ~step ~needed ~condemned);
      reconcile_id = 0;
    }

(* The control every forged row runs FIRST: the reconcile really is at the CR
   key and its local state really decodes. Without it a failed injection reads
   as "L1 holds" (the [~absent:true] fold) and the whole exe goes green while
   measuring the seed. *)
let injection_landed (s : Cluster.cluster_state) : bool =
  Option.fold
    (Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id))
    ~none:false
    ~some:(fun (o : Controller.ongoing_reconcile) ->
      Result.is_ok (Pack.unmarshal_state o.Controller.local_state))

(* ---- payloads: the reconciler's OWN [make_pod] objects, metadata replaced --
   the t_p20/p21/p22_mutation discipline (spec and status are never test-local
   fictions). Pod 1 is the ordinal the P22/P23 seed plants as the surplus, so
   the accepted rows are byte-what [partition_pods] would put in [condemned]. *)

let repod (md : Object_meta.t) (p : Pod.t) : Pod.t = Pod.with_metadata md p

(* MEASURED WHILE WRITING THIS ROW, and it is not a detail: [Vsr.make_pod]
   (v_stateful_set_reconciler.ml:361-383) builds its metadata from
   [Object_meta.default ()] and sets [name], [labels], [annotations] and
   [owner_references] - but NOT [namespace]. The api server stamps the
   namespace on create (the [Create_request]'s own [namespace] field), and
   [partition_pods] builds [needed]/[condemned] from pods read BACK out of a
   [List_response]. So the faithful shape of a condemned entry is the STORED
   pod, and a raw [make_pod] output is RED for L1 on upstream :621/:627. That
   is a real red row, not a test artefact, and it is asserted as one below. *)
let listed_pod (ord : int) : Pod.t =
  let p : Pod.t = Vsr.make_pod cr ord in
  repod { (Pod.metadata p) with Object_meta.namespace = Some ns } p

let good_pod0 : Pod.t = listed_pod 0
let good_pod1 : Pod.t = listed_pod 1

(* The reconciler's OWN [make_pod], unstamped: namespace still [None]. *)
let unstamped_pod : Pod.t = Vsr.make_pod cr 1

(* Upstream :621 / :627: [pod.metadata.namespace == Some(cr_key.namespace)]. *)
let foreign_ns_pod : Pod.t =
  repod
    { (Pod.metadata good_pod1) with Object_meta.namespace = Some (ns ^ "-p23-elsewhere") }
    good_pod1

(* Upstream :620 / :626: [pod_name_match(name->0, cr_key.name)], rendered by
   INVERSION through [get_ordinal] - a name that does not invert. *)
let rogue_name_pod : Pod.t =
  repod
    { (Pod.metadata good_pod1) with Object_meta.name = Some "not-a-vstatefulset-pod" }
    good_pod1

(* Upstream :619 / :625: [pod.metadata.name is Some] - the [~none:false] half. *)
let nameless_pod : Pod.t =
  repod { (Pod.metadata good_pod1) with Object_meta.name = None } good_pod1

(* ---- pending requests: upstream :646-651 ---------------------------------- *)

let list_req (namespace : string) : Api_method.api_request =
  Api_method.List_request { Api_method.kind = Pod.kind; namespace }

let req_of (r : Api_method.api_request) : Message.t =
  Message.controller_req_msg controller_id cr_key (Message.Rpc_id.of_int 77) r

let pending_of (r : Api_method.api_request) : Message.t option = Some (req_of r)

(* MB9 needs the parked pod-list request as a VALUE and not only as the pending
   slot, because the forged response is formed FROM it (upstream :656's
   [resp_msg_matches_req_msg] is then satisfied by CONSTRUCTION rather than by
   a hand-typed rpc id that could silently drift). *)
let pod_list_req : Message.t = req_of (list_req ns)
let pending_pod_list : Message.t option = Some pod_list_req

(* MB1's observable, at state level. *)
let pending_foreign_list : Message.t option =
  pending_of (list_req (ns ^ "-p23-elsewhere"))

(* MB4's observable, at state level: the SAME foreign namespace, on a request
   that is NOT the pod list. *)
let pending_foreign_gtd : Message.t option =
  pending_of
    (Api_method.Get_then_delete_request
       {
         Api_method.key =
           {
             Common.kind = Pod.kind;
             namespace = ns ^ "-p23-elsewhere";
             name = Vsr.pod_name parent 1;
           };
         owner_ref =
           Option.value
             (V_stateful_set.controller_owner_ref cr)
             ~default:(Owner_reference.default ());
       })

(* ==== family shape ========================================================= *)

let test_family_shape () =
  Alcotest.(check (list string)) "binding_family = L1, L2 in member order"
    [ l1_name; l2_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family);
  Alcotest.(check int) "binding_family cardinal" P23_witness.binding_cardinal
    (List.length family);
  (* by-name addressing is what every row below rides; a rename would make
     every projection constantly [false] and every red row silently green. *)
  Alcotest.(check bool) "L1 is addressable by name" true
    (List.exists
       (fun (i : Invariants.invariant) -> String.equal i.Invariants.name l1_name)
       family);
  Alcotest.(check bool) "L2 is addressable by name" true
    (List.exists
       (fun (i : Invariants.invariant) -> String.equal i.Invariants.name l2_name)
       family)

(* ==== RED CAPABILITY at state level ========================================
   Each row: injection control, then the verdicts for BOTH members, then the
   accepted counterpart. BUILD-SPEC-P23 section 7 warns that L1 may be a green
   that never fires; these rows measure that it is not a predicate that CANNOT
   fail, which is a weaker and honest claim. *)

let test_red_capability () =
  (* --- accepted controls FIRST: the reconciler's own shapes are GREEN ------ *)
  let ok_condemned =
    forge ~step:Vsr.Create_needed ~needed:[] ~condemned:[ good_pod1 ]
      ~pending:None
  in
  Alcotest.(check bool) "control: the injection landed (condemned, accepted)"
    true (injection_landed ok_condemned);
  Alcotest.(check bool)
    "control: a genuine make_pod condemned entry HOLDS for L1" true
    (member_holds family l1_name ok_condemned);
  Alcotest.(check bool)
    "control: and L1's premise FIRES on it (condemned non-empty), so the reds \
     below are attributable to the payload, not to a dead premise"
    true
    (member_interesting family l1_name ok_condemned);
  let ok_needed =
    forge ~step:Vsr.Create_needed ~needed:[ Some good_pod0 ] ~condemned:[]
      ~pending:None
  in
  Alcotest.(check bool)
    "control: a genuine make_pod NEEDED slot HOLDS for L1 (the C1 conjunct \
     prediction 5 was wrong about)"
    true
    (member_holds family l1_name ok_needed);
  Alcotest.(check bool) "control: an EMPTY needed slot is vacuously bound" true
    (member_holds family l1_name
       (forge ~step:Vsr.Create_needed ~needed:[ None ] ~condemned:[]
          ~pending:None));
  (* --- L1 reds: one row per upstream sub-conjunct -------------------------- *)
  List.iter
    (fun ((label, st) : string * Cluster.cluster_state) ->
      Alcotest.(check bool) (label ^ ": the injection landed") true
        (injection_landed st);
      Alcotest.(check bool) (label ^ ": L1 is RED") false
        (member_holds family l1_name st);
      Alcotest.(check bool)
        (label
       ^ ": L2 is ALSO red - the CONTAINMENT (:642 calls E4), measured rather \
          than argued")
        false
        (member_holds family l2_name st))
    [
      ( "MB2-a condemned in a FOREIGN namespace (upstream :627)",
        forge ~step:Vsr.Create_needed ~needed:[] ~condemned:[ foreign_ns_pod ]
          ~pending:None );
      ( "MB2-b condemned whose name does NOT invert through get_ordinal (:626)",
        forge ~step:Vsr.Create_needed ~needed:[] ~condemned:[ rogue_name_pod ]
          ~pending:None );
      ( "MB2-c condemned with NO name at all (:625, the ~none:false half)",
        forge ~step:Vsr.Create_needed ~needed:[] ~condemned:[ nameless_pod ]
          ~pending:None );
      ( "MB2-d NEEDED slot in a FOREIGN namespace (:621)",
        forge ~step:Vsr.Create_needed ~needed:[ Some foreign_ns_pod ]
          ~condemned:[] ~pending:None );
      ( "MB2-e NEEDED slot whose name does not invert (:620)",
        forge ~step:Vsr.Create_needed ~needed:[ Some rogue_name_pod ]
          ~condemned:[] ~pending:None );
      ( "MB2-f the reconciler's OWN make_pod output, UNSTAMPED (namespace \
         still None because make_pod builds from Object_meta.default and the \
         api server stamps the namespace on create) - upstream :621/:627 is \
         genuinely load-bearing, not a formality",
        forge ~step:Vsr.Create_needed ~needed:[] ~condemned:[ unstamped_pod ]
          ~pending:None );
    ];
  (* --- MB1 at state level: L2 RED, L1 GREEN ------------------------------- *)
  let mb1 =
    forge ~step:Vsr.After_list_pod ~needed:[] ~condemned:[]
      ~pending:pending_foreign_list
  in
  Alcotest.(check bool) "MB1 (state level): the injection landed" true
    (injection_landed mb1);
  Alcotest.(check bool)
    "MB1 (state level): L2's premise FIRES (parked at After_list_pod with a \
     pending request)"
    true
    (member_interesting family l2_name mb1);
  Alcotest.(check bool)
    "MB1 (state level): L2 is RED on a pod list in a FOREIGN namespace \
     (upstream :648-651)"
    false
    (member_holds family l2_name mb1);
  Alcotest.(check bool)
    "MB1 (state level): L1 is GREEN there - the two members are NOT the same \
     predicate, and this is the ONLY thing that earns L2 its keep"
    true
    (member_holds family l1_name mb1);
  Alcotest.(check bool)
    "MB1 (state level): L1's premise does NOT fire there (needed and \
     condemned are both empty at After_list_pod - the disjointness the BL0 \
     gate decomposition measures)"
    false
    (member_interesting family l1_name mb1);
  (* --- the accepted counterpart: the SAME shape, right namespace ---------- *)
  let mb1_ok =
    forge ~step:Vsr.After_list_pod ~needed:[] ~condemned:[]
      ~pending:pending_pod_list
  in
  Alcotest.(check bool)
    "MB1 control: the same parked shape with the CR's OWN namespace is GREEN \
     for L2 (so the red above is the namespace, not the injection)"
    true
    (member_holds family l2_name mb1_ok);
  (* --- MB4 trap row: a foreign namespace on a request that is NOT the list - *)
  let mb4 =
    forge ~step:Vsr.After_list_pod ~needed:[] ~condemned:[]
      ~pending:pending_foreign_gtd
  in
  Alcotest.(check bool) "MB4 (trap row): the injection landed" true
    (injection_landed mb4);
  Alcotest.(check bool)
    "MB4 (trap row): L2 is RED for a DIFFERENT reason - the pending request is \
     not a pod ListRequest at all (:647). The row's POINT: a red is not \
     evidence of the namespace conjunct; only the MB1/MB1-control PAIR is."
    false
    (member_holds family l2_name mb4);
  Alcotest.(check bool)
    "MB4 (trap row): L1 is untouched by anything on the wire (it is a pure \
     function of the decoded local state)"
    true
    (member_holds family l1_name mb4);
  (* --- and a parked state with NO pending request at all: L2 red (:645) ---- *)
  Alcotest.(check bool)
    "upstream :645 ([pending_req_msg is Some]) is load-bearing: parked with NO \
     pending request is RED for L2"
    false
    (member_holds family l2_name
       (forge ~step:Vsr.After_list_pod ~needed:[] ~condemned:[] ~pending:None));
  Alcotest.(check bool)
    "...and its premise does NOT fire there, so the red is a HOLDS fact the \
     leg would never gate on - the honest reading of ~none:false in both \
     positions"
    false
    (member_interesting family l2_name
       (forge ~step:Vsr.After_list_pod ~needed:[] ~condemned:[] ~pending:None))

(* ==== MB3: the CONTAINMENT's attribution consequence, MEASURED =============
   BUILD-SPEC-P23 section 2.2 predicts it; this measures it, through the same
   [Invariants.first_violated] the leg's [violated] rides. The datum is
   UNFLATTERING and that is why it is a test and not a footnote. *)

let test_containment_attribution () =
  let shared =
    forge ~step:Vsr.Create_needed ~needed:[] ~condemned:[ foreign_ns_pod ]
      ~pending:None
  in
  Alcotest.(check bool) "MB3: the injection landed" true
    (injection_landed shared);
  Alcotest.(check bool) "MB3: L1 is red" false (member_holds family l1_name shared);
  Alcotest.(check bool) "MB3: L2 is ALSO red" false
    (member_holds family l2_name shared);
  Alcotest.(check string)
    "MB3: first_violated names L1 and ONLY L1 - so a leg's [violated] can \
     never attribute a shared-conjunct failure to L2, and per-member \
     attribution MUST come from the replica counts in t_p23_local_binding"
    l1_name (first_violated_name shared);
  (* the converse row: when ONLY L2 is false, the leg WOULD name L2 - so the
     asymmetry above is containment, not a broken projection. *)
  let l2_only =
    forge ~step:Vsr.After_list_pod ~needed:[] ~condemned:[]
      ~pending:pending_foreign_list
  in
  Alcotest.(check string)
    "MB3 converse: when L1 holds and only L2 is false, first_violated names \
     L2 - the asymmetry is CONTAINMENT, not a broken traversal"
    l2_name (first_violated_name l2_only)

(* ==== MB5: premise wiring over the REAL BL0 graph ==========================
   Evaluated over the BL0 replica - the graph t_p23_local_binding pins - so the
   zeros below are measured on the phase's own graph, not on a forged state. *)

let bl0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (Mc.explore ~depth
       ~successors:(Fc.faulted_successors bound P23_witness.zero_budget cluster)
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

let test_mb5_premise_wiring () =
  let reach = Lazy.force bl0_reach in
  (* replica faithfulness FIRST: a drifted replica would silently measure a
     different graph (the P13 M3/M5 precedent). *)
  Alcotest.(check int) "MB5: replica states = the BL0 pin" P23_witness.bl0_states
    (Mc.states_seen reach);
  (* the contrast, at the RIGHT id: both premises live at their pinned counts. *)
  Alcotest.(check int)
    "MB5 contrast: L1 interesting at the true controller id = the BL0 pin"
    P23_witness.l1_interesting_bl0
    (count_interesting reach family l1_name);
  Alcotest.(check int)
    "MB5 contrast: L2 interesting at the true controller id = the BL0 pin"
    P23_witness.l2_interesting_bl0
    (count_interesting reach family l2_name);
  let family_wrong_id : Invariants.invariant list =
    Lb.binding_family ~cr ~controller_id:(controller_id + 1)
  in
  List.iter
    (fun (name : string) ->
      Alcotest.(check int)
        (name
       ^ ": interesting = 0 over ALL of BL0 at controller_id + 1 - the \
          premise keys on the id, so a non-zero per-member interesting is the \
          only evidence the family was wired to the leg's controller at all")
        0
        (count_interesting reach family_wrong_id name);
      Alcotest.(check int)
        (name
       ^ ": red = 0 over ALL of BL0 at controller_id + 1 - vacuous TRUTH, not \
          vacuous falsity (ongoing_reconciles is TOTAL, cluster.mli:78-82)")
        0
        (count_reds reach family_wrong_id name))
    [ l1_name; l2_name ]

(* ==== MB6: the DECODE-FAILURE FOLD, given an input that EXERCISES it ========
   Matrix row MB6 (BUILD-SPEC-P23 section 5, reworded in section 8.9) flips
   L1's [~undecodable:true] to [~undecodable:false] at local_binding.ml:311.
   RUN, and it SURVIVED every shipped leg byte-for-byte, because decode
   failures measure 0 / 0 / 0 / 0 (prediction 4, section 8.1): on the four
   explored graphs that fold is DEAD CODE, and a mutation of dead code cannot
   be killed by any graph-level assertion however exact.

   This row closes the gap at UNIT level instead of disclosing it. An ongoing
   reconcile is installed at the CR key carrying a [Value.t] that
   {!V_stateful_set_pack.unmarshal_state} REJECTS, so [at_reconcile]'s
   [~error:] arm (local_binding.ml:283-286) is the arm that runs. The house
   out-of-premise rule (internal_guarantee.ml:53-55) then fixes both members:
   [holds] folds TRUE and [interesting] folds FALSE. It is the [holds = true]
   half that MB6 flips, so the row below is the assertion that kills it.

   Deliberately NOT a new graph: a leg whose seed could produce a corrupt
   store would need a new bound, a new pin and a seed-integrity obligation for
   a branch upstream models as an unconstrained value. *)

let undecodable_local_state : Value.t =
  Value.of_json (`String "MB6: deliberately not a marshalled reconcile state")

let undecodable_state : Cluster.cluster_state =
  install
    {
      Controller.triggering_cr = V_stateful_set.marshal cr;
      pending_req_msg = None;
      local_state = undecodable_local_state;
      reconcile_id = 0;
    }

let decodes_at_cr_key (s : Cluster.cluster_state) : bool option =
  Option.map
    (fun (o : Controller.ongoing_reconcile) ->
      Result.is_ok (Pack.unmarshal_state o.Controller.local_state))
    (Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id))

let test_mb6_decode_failure_fold () =
  (* Two controls FIRST, in order. Without them a failed injection reads as
     "L1 holds" through the [~absent:true] fold and this whole case would be a
     green measuring the untouched seed - the exact vacuous shape every other
     forged row in this file guards against. *)
  Alcotest.(check (option bool))
    "MB6 control: the ongoing reconcile IS installed at the CR key, and its \
     local_state is UNDECODABLE - the input the four shipped graphs never \
     produce (decode failures 0 / 0 / 0 / 0)"
    (Some false)
    (decodes_at_cr_key undecodable_state);
  Alcotest.(check (option bool))
    "MB6 control: the SAME injection with a well-formed local_state DOES \
     decode - so the line above is the codec refusing, not the injection \
     missing"
    (Some true)
    (decodes_at_cr_key
       (forge ~step:Vsr.Create_needed ~needed:[] ~condemned:[] ~pending:None));
  (* THE ROW. [~undecodable:true] at local_binding.ml:311 / :324. *)
  Alcotest.(check bool)
    "MB6: L1 HOLDS on an undecodable local state - this is \
     [~undecodable:true] at local_binding.ml:311, and flipping that single \
     token is matrix row MB6, which NOTHING else in this battery can kill"
    true
    (member_holds family l1_name undecodable_state);
  Alcotest.(check bool)
    "MB6: L2 HOLDS there too - [~undecodable:true] at local_binding.ml:324, \
     the same token on the containing member"
    true
    (member_holds family l2_name undecodable_state);
  (* the other half of the out-of-premise rule, so a mutant that made BOTH
     folds [false] could not hide as "it was never interesting anyway". *)
  Alcotest.(check bool)
    "MB6: and BOTH members are OUT OF PREMISE there ([~undecodable:false] on \
     the interesting side, :315 / :331) - out of premise is holds TRUE and \
     interesting FALSE, never both"
    true
    ((not (member_interesting family l1_name undecodable_state))
    && not (member_interesting family l2_name undecodable_state))

(* ==== MB7: the PVCS-EXCLUSION PIN's RED CAPABILITY ==========================
   The pin t_p23_local_binding asserts (no decoded ongoing state has a PVC) is
   only worth something if it CAN redden. A throwaway [vct:true] seed makes
   [make_pvcs] return a non-empty list (v_stateful_set_reconciler.ml:292-296 with
   [volume_claim_templates = Some [...]], scenario.ml:240-241) and the pin fails.
   Deliberately a FLOOR, not a pin: no shipped leg explores this graph, so
   committing its size or its exact PVC-state count would be a number nothing
   can move. *)

let vct_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (Mc.explore ~depth
       ~successors:(Fc.faulted_successors bound P23_witness.zero_budget cluster)
       ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
       ~init:
         [
           Fc.faulted_of_seed
             (Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true
                ~req_drop:false ~pod_monkey:false ~vct:true ());
         ])

let decoded_pvcs_non_empty (s : Cluster.cluster_state) : bool =
  Option.fold
    (Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id))
    ~none:false
    ~some:(fun (o : Controller.ongoing_reconcile) ->
      Option.fold
        (Result.to_option (Pack.unmarshal_state o.Controller.local_state))
        ~none:false
        ~some:(fun (st : Vsr.s) -> not (st.Vsr.pvcs = [])))

let test_mb7_pvcs_pin_reddens () =
  let reach = Lazy.force vct_reach in
  Alcotest.(check bool)
    "MB7: the throwaway vct:true graph really explored (a dead graph would \
     make the floor below vacuous)"
    true
    (Mc.states_seen reach > 0);
  Alcotest.(check bool)
    "MB7: the PVCS-ARE-EMPTY PIN REDDENS on a vct:true seed - so \
     EXCLUDE-WITH-A-PIN means excluded-and-watched, not omitted"
    true
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         decoded_pvcs_non_empty f.cs)
    > 0);
  (* the control: on the SHIPPED vct:false seed the same projection is 0, so
     the red above is the volume_claim_templates and nothing else. *)
  Alcotest.(check int)
    "MB7 control: the same projection is 0 on the SHIPPED vct:false BL0 graph"
    P23_witness.pvcs_non_empty_everywhere
    (Mc.count_states_where (Lazy.force bl0_reach) (fun (f : Fc.faulted) ->
         decoded_pvcs_non_empty f.cs))

(* ==== MB8: the BARE-SOURCE TRAP, exhibited =================================
   A verbatim copy of [t_p21_regression.ml:353-362]'s parser - the guarded-total
   [sub_opt] and [line_of_source]. Copied rather than shared, because the point
   of the row is what THAT parser does; a shared helper that drifted would take
   the exhibit with it. *)

let sub_opt (s : string) (pos : int) (len : int) : string option =
  if pos >= 0 && len >= 0 && pos + len <= String.length s then
    Some (String.sub s pos len) (* @total-accessor *)
  else None

let line_of_source (s : string) : int option =
  Option.bind (String.rindex_opt s ':') (fun (i : int) ->
      Option.bind
        (sub_opt s (i + 1) (String.length s - i - 1))
        int_of_string_opt)

let test_mb8_bare_source_trap () =
  (* the SHIPPED sources parse - the positive fact the firewall depends on. *)
  Alcotest.(check int)
    "MB8: every shipped P23 source parses to a line number (a qualifier on ANY \
     of them makes the member invisible to t_p21_regression's roster sweep)"
    (List.length Lb.binding_sources)
    (List.length (List.filter_map line_of_source Lb.binding_sources));
  Alcotest.(check (list int))
    "MB8: and they parse to L1 :613 and L2 :640, in member order"
    [ 613; 640 ]
    (List.filter_map line_of_source Lb.binding_sources);
  (* THE TRAP, exhibited: the same string with the qualifier the spec's MB8 row
     names. This is not a hypothetical - vsts_invariants.ml:217 ships that
     style, so the shape exists in the tree. *)
  Alcotest.(check bool)
    "MB8: a PARENTHETICAL QUALIFIER makes line_of_source return None - the \
     member then DROPS OUT of roster_guarantee_lines silently"
    true
    (Option.is_none
       (line_of_source
          "vstatefulset_controller/proof/internal_rely_guarantee.rs:613 \
           (needed+condemned only)"));
  Alcotest.(check bool)
    "MB8: so does a trailing space, and so does a non-numeric tail - the \
     parser is int_of_string_opt on everything after the LAST colon"
    true
    (Option.is_none
       (line_of_source
          "vstatefulset_controller/proof/internal_rely_guarantee.rs:640 ")
    && Option.is_none
         (line_of_source "vstatefulset_controller/proof/x.rs:six-forty"))

(* ==== MB9: the INNER FORALL's CONSEQUENT, upstream :659-661 ================
   THE GAP, stated the way the review stated it. L2's inner-forall CONSEQUENT
   ([resp_objs_in_namespace], local_binding.ml:206-212) is true at EVERY state
   of all four shipped graphs - "both members' reds are 0 on every shipped
   graph" IS that statement - and it is reached by no other row in this file.
   [forge] sets only [pending_req_msg] and [local_state] and never puts a
   response on the wire, so [ok_list_resps_for] returns [] on every forged
   state and [List.for_all] over [] is vacuously TRUE. The measured premise
   counts (8 / 60 / 48 / 816, BUILD-SPEC-P23 section 8.5) establish that the
   premise FIRES and that the body runs on REAL objects; they do not establish
   RED CAPABILITY, and "a pin never SEEN to fail is not evidence" is this
   file's own opening rule applied to itself.

   THE ROW supplies the input at unit level: an in-flight ok [List_response],
   formed FROM the parked pending request through {!Message.form_list_resp_msg}
   (so upstream :656's [resp_msg_matches_req_msg] and :655's api-server source
   hold by CONSTRUCTION), carrying ONE [Dynamic_object] - the reconciler's own
   [make_pod] payload marshalled, the file's standing payload discipline -
   whose [metadata.namespace] is NOT the CR's.

   Deliberately NOT a new graph: no shipped leg's api server answers a
   namespaced list with an out-of-namespace object, so reaching this state
   would need a forged store, a new bound and a new pin rather than a new
   assertion. This row is state-level red capability and is labelled as such.

   THE CONTROLS COME FIRST and they are the whole point. If the injection
   silently failed, [ok_list_resps_for] would return [] and this row would go
   GREEN vacuously - the exact failure mode it exists to fix. So the row first
   asserts that the response really is in flight, really is SELECTED by the
   premise, and really carries the foreign namespace; only then does it read a
   verdict. The NEGATIVE CONTROL (the same shape carrying the CR's OWN
   namespace, GREEN) is what makes the red attributable to the namespace rather
   than to some incidental malformation of the forged state. *)

(* DUPLICATE-AND-PIN of two PRIVATE helpers of {!Local_binding} (:174-188 and
   :193-200, themselves invariants.ml:348-360 / :361-368), the same duplication
   t_p23_local_binding.ml:345-374 already carries with the same citation. They
   are the row's CONTROLS, not the row's subject: copying them is what lets the
   control fail independently of the predicate under test. *)

let list_resp_objs (m : Message.t) : Dynamic_object.t list option =
  match m.Message.content with
  | Message.Api_response (Api_method.List_response lr) ->
    Result.to_option lr.Api_method.res
  | Message.Api_response
      ( Api_method.Get_response _ | Api_method.Create_response _
      | Api_method.Delete_response _ | Api_method.Update_response _
      | Api_method.Update_status_response _
      | Api_method.Get_then_delete_response _
      | Api_method.Get_then_update_response _
      | Api_method.Get_then_update_status_response _ ) ->
    None
  | Message.Api_request _ | Message.External_request _
  | Message.External_response _ ->
    None

let ok_list_resps_for (s : Cluster.cluster_state) (req_msg : Message.t) :
    Message.t list =
  List.filter
    (fun (m : Message.t) ->
      Message.equal_host_id m.Message.src Message.Api_server
      && Message.resp_msg_matches_req_msg m req_msg
      && Option.is_some (list_resp_objs m))
    (Message.Pool.distinct (Cluster.in_flight s))

let resp_obj_namespaces (m : Message.t) : string option list =
  Option.fold (list_resp_objs m) ~none:[]
    ~some:
      (List.map (fun (o : Dynamic_object.t) ->
           (Dynamic_object.metadata o).Object_meta.namespace))

(* The injection: a record update on [Network.state] (network.mli:9), the same
   plain-record discipline [install] uses on [Controller.state]. *)
let with_in_flight (m : Message.t) (s : Cluster.cluster_state) :
    Cluster.cluster_state =
  {
    s with
    Cluster.network =
      { Network.in_flight = Message.Pool.add m (Cluster.in_flight s) };
  }

let elsewhere_ns : string = ns ^ "-p23-elsewhere"

(* The listed object: the reconciler's OWN [make_pod] payload marshalled to the
   [Dynamic_object.t] a [List_response] carries, with the namespace stamped -
   never a hand-built object, the t_p20/p21/p22_mutation payload discipline. *)
let listed_obj (namespace : string) : Dynamic_object.t =
  Dynamic_object.with_namespace namespace (Pod.marshal good_pod0)

(* The parked state of MB1's accepted counterpart - pending pod list in the CR's
   OWN namespace, so :647-651 PASSES and the only thing left that can red L2 is
   :659-661 - plus one matching ok [List_response] in flight. *)
let parked_no_resp : Cluster.cluster_state =
  forge ~step:Vsr.After_list_pod ~needed:[] ~condemned:[]
    ~pending:pending_pod_list

let parked_with_listed_obj (namespace : string) : Cluster.cluster_state =
  with_in_flight
    (Message.form_list_resp_msg pod_list_req
       { Api_method.res = Ok [ listed_obj namespace ] })
    parked_no_resp

let mb9_foreign : Cluster.cluster_state = parked_with_listed_obj elsewhere_ns
let mb9_own : Cluster.cluster_state = parked_with_listed_obj ns

let test_mb9_inner_consequent () =
  (* --- controls that the FORGERY LANDED, before any verdict is read ------- *)
  List.iter
    (fun ((label, st) : string * Cluster.cluster_state) ->
      Alcotest.(check bool)
        (label ^ ": the ongoing reconcile landed and its local state decodes")
        true (injection_landed st);
      Alcotest.(check int)
        (label
       ^ ": EXACTLY ONE matching ok List_response is in flight - upstream \
          :652-657 SELECTS it, so List.for_all is NOT folding over the empty \
          list (the vacuity this row exists to remove)")
        1
        (List.length (ok_list_resps_for st pod_list_req)))
    [ ("MB9 (foreign namespace)", mb9_foreign); ("MB9 control (CR's own namespace)", mb9_own) ];
  (* the vacuity itself, EXHIBITED: the same parked shape WITHOUT the injection
     selects nothing at all, which is why every other forged row in this file
     is silent about :659-661. *)
  Alcotest.(check int)
    "MB9: the SAME parked shape with NO response in flight selects ZERO \
     responses - that is the vacuous green every other row of this file gives \
     the consequent"
    0
    (List.length (ok_list_resps_for parked_no_resp pod_list_req));
  (* and the selected response really carries the namespace each row intends *)
  Alcotest.(check (list (option string)))
    "MB9: the selected response carries ONE object, in the FOREIGN namespace \
     (so the red below is :659-661 and not an empty objs list)"
    [ Some elsewhere_ns ]
    (List.concat_map resp_obj_namespaces (ok_list_resps_for mb9_foreign pod_list_req));
  Alcotest.(check (list (option string)))
    "MB9 control: the negative-control response carries the SAME one object in \
     the CR's OWN namespace"
    [ Some ns ]
    (List.concat_map resp_obj_namespaces (ok_list_resps_for mb9_own pod_list_req));
  (* L2's premise fires on both, so neither verdict is an out-of-premise fold *)
  Alcotest.(check bool)
    "MB9: L2's premise FIRES on both states (parked at After_list_pod with a \
     pending request), so both verdicts below are IN premise"
    true
    (member_interesting family l2_name mb9_foreign
    && member_interesting family l2_name mb9_own);
  (* --- THE ROW ------------------------------------------------------------ *)
  Alcotest.(check bool)
    "MB9: L2 is RED on an in-flight ok List_response whose object is OUTSIDE \
     the CR's namespace - upstream :659-661, the ONE conjunct of this family \
     that no graph and no other forged row can redden"
    false
    (member_holds family l2_name mb9_foreign);
  (* --- THE NEGATIVE CONTROL ----------------------------------------------- *)
  Alcotest.(check bool)
    "MB9 negative control: the SAME shape carrying the CR's OWN namespace is \
     GREEN for L2 - so the red above is the object's namespace, not the \
     injection and not the response's mere presence"
    true
    (member_holds family l2_name mb9_own);
  (* L1 is a pure function of the decoded local state: nothing on the wire can
     move it, and saying so keeps the red attributable to L2's unique half. *)
  Alcotest.(check bool)
    "MB9: L1 is GREEN on BOTH states - it reads no message, so the red is L2's \
     unique conjunct and the containment is not what fired"
    true
    (member_holds family l1_name mb9_foreign && member_holds family l1_name mb9_own)

let () =
  Alcotest.run "p23_mutation"
    [
      ( "family_shape",
        [
          Alcotest.test_case "names / cardinal / by-name addressing" `Quick
            test_family_shape;
        ] );
      ( "red_capability",
        [
          Alcotest.test_case
            "BOTH members SEEN red on forged P23-seed states (MB1's and MB2's \
             observables at state level; MB4 is the trap control)"
            `Quick test_red_capability;
        ] );
      ( "containment_attribution",
        [
          Alcotest.test_case
            "MB3: first_violated names L1 for a SHARED-conjunct failure and \
             L2 looks green - the containment consequence, MEASURED"
            `Quick test_containment_attribution;
        ] );
      ( "mb5_premise_wiring",
        [
          Alcotest.test_case
            "controller_id + 1 sees NOTHING over the real BL0 graph (vacuous \
             truth; replica pinned first)"
            `Quick test_mb5_premise_wiring;
        ] );
      ( "mb6_decode_failure_fold",
        [
          Alcotest.test_case
            "MB6: the undecodable-local-state fold is EXERCISED at unit level \
             - the row survives every graph because decode failures are 0"
            `Quick test_mb6_decode_failure_fold;
        ] );
      ( "mb7_pvcs_pin",
        [
          Alcotest.test_case
            "the pvcs-are-empty pin REDDENS on a throwaway vct:true seed - the \
             exclusion is watched, not merely undone"
            `Quick test_mb7_pvcs_pin_reddens;
        ] );
      ( "mb8_bare_source_trap",
        [
          Alcotest.test_case
            "a qualified source string parses to None - the vacuous-green \
             shape t_p21_regression's count assertion now catches"
            `Quick test_mb8_bare_source_trap;
        ] );
      ( "mb9_inner_consequent",
        [
          Alcotest.test_case
            "MB9: L2's INNER-FORALL CONSEQUENT (upstream :659-661) is SEEN RED \
             on a forged in-flight ok List_response carrying an \
             out-of-namespace object, GREEN on the CR's own - the conjunct no \
             graph and no other forged row can redden"
            `Quick test_mb9_inner_consequent;
        ] );
    ]

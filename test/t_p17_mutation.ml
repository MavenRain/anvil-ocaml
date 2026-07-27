(* BUILD-SPEC-P17 section 5 - confirm-by-mutation for the STORE-side family
   (S1 / S2 / S3, asserted ALONE by the G7 legs). A clean, decisive
   [No_counterexample] from [t_p17_store] is only evidence if the family
   would MOVE when what it checks breaks; on the true model every leg is
   clean, so the Refuted path would otherwise ship with ZERO observed-red
   coverage. Two forms of evidence, the P14/P15/P16 split: the MANUAL
   real-source mutants MU / MR' / MO-a / MO-b / MA / MD (documented below -
   applied with Edit, SEEN red or SEEN inert, reverted with Edit, never git
   checkout; only the green tree ships), and the AUTOMATED permanent
   per-member forges below, whose red-capability is asserted on every run.

   ==== MU (MANUAL, api_server.ml:300; NOT shipped) - the headline ===========

   Mutant: [handle_create_request]'s success branch keeps
   [uid_counter = s.uid_counter] (no bump; the [uid = Some (of_int
   s.uid_counter)] stamp at :272 is untouched) - the state-side analogue of
   P16's MR.

   MEASURED effect (the section-5 MU row: leg-RED half CONFIRMED, named
   member REFUTED - recorded as a finding, the P16 MS precedent): the legs
   flip clean -> Refuted, but [violated] names S2
   [each_object_in_etcd_is_weakly_well_formed], NOT the predicted S1. SEEN:
   the anchor's L0 check-string printed S2's name, the seed-shape check
   reddened with [violated_names seed = [S2]] (so EVERY leg's graph
   contains the violating seed), and all four [t_p17_store] leg cases
   reddened ([L0: outcome clean] first). Mechanism: the seed itself creates
   the CR through the REAL [handle_create_request] (scenario.ml:355-368),
   so under MU the seed's CR carries [uid = 1] while [uid_counter] STAYS 1
   - S2's strict [uid->0 < uid_counter] conjunct fails at the SEED, before
   any second create could stamp the duplicate uid the prediction reasoned
   about. S1's dup-uid mechanism is real but MASKED by the earlier S2
   violation on every trace (the checker reports the first bad state = the
   seed, where the store has ONE object and S1 holds). S1's own red
   capability is SEEN through {!test_s1_forge} instead (equal-[Some] uids
   with every S2 conjunct kept green). The forged S2 uid-boundary witness
   ({!test_s2_forge}'s [uid = uid_counter] state) is exactly the state
   class MU drives the seed into.

   ==== MR' (MANUAL, api_server.ml:301; NOT shipped) - cross-phase ===========

   Mutant: [handle_create_request]'s success branch keeps
   [resource_version_counter = s.resource_version_counter] (no bump) -
   P16's MR verbatim, re-run against the STORE family.

   MEASURED effect (the section-5 MR' row CONFIRMED, both halves): the
   legs flip clean -> Refuted with [violated] naming S2 BY NAME (SEEN: the
   anchor's L0 check-string printed it, and the seed-shape check reddened
   with [violated_names seed = [S2]], so every leg's graph contains the
   violating seed; same mechanism class as MU - the seed CR's [rv = 0]
   meets a frozen [resource_version_counter = 0], so S2's strict
   [rv->0 < rvc] conjunct fails at the seed). AND the P16 family still
   reds under the SAME application: [t_p16_mutation]'s L0v/Rv anchor leg
   printed Q1 [object_in_ok_get_response_has_smaller_rv_than_etcd] (the
   Lmv probe reddened likewise, naming Q1 - both exactly P16's committed
   MR row) - one mutant refuting a message-side AND a state-side member,
   the cross-phase datum the row was built for. {!test_s2_forge}'s
   rv-boundary witness ([rv = rvc] exactly) is the same state class at
   forge level.

   ==== MO-a (MANUAL, v_stateful_set_reconciler.ml:218-220; NOT shipped) ====
   ==== the guard-witness observation, as a documented manual protocol ======

   Mutant: [make_owner_references] duplicates the controller ref ALONE
   ([~some:(fun r -> [ r; r ])]) - every reconciler-built pod/PVC create
   now carries TWO controller owner references; the api_server admission
   guard [metadata_validity_check] (api_server.ml:90-97) is left intact.

   PROTOCOL (manual, repeat to re-observe): apply the one-line Edit above,
   [dunecho build], run THIS exe and [t_p17_store]; then revert the Edit,
   rebuild, re-run both green. Prediction: GREEN everywhere - the guard
   rejects the >1-controller object with [Invalid], so the bad object
   NEVER reaches the store and S3 never sees it.

   MEASURED effect (the section-5 MO-a row CONFIRMED - a measurement, not
   a failed mutant): NO leg refuted - the anchor's every violated-name
   check stayed ["<none>"], every clean and every decisive check passed on
   all four legs (12 of 12 semantic checks), and every forge stayed green.
   The guard's rejection is VISIBLE in four measured collapses
   ([t_p17_store] run under the mutant): (a) S1's [interesting] count fell
   to 0 on L0 - no second object is EVER stored, the [L0: S1 interesting
   fires] check reddened; (b) the content maxima fell - [Ld:
   max_uid_seen] 3 -> 2, no create ever lands so the counters never
   advance past the seed CR; (c) the graphs rerouted - Lc states
   464 -> 368; (d) the Lm MONKEY EDGE STARVED - [max_monkeys_seen] = 0,
   the anchor's edge-taken check reddened, because the pod monkey's
   candidates are the STORED pods (cluster.ml:744-755) and nothing is
   ever stored. (d) is an unpredicted secondary datum recorded as its own
   observation: under MO-a the family's leverage edge itself disappears,
   so the Lm green is judged on a monkey-starved graph (its gate is
   structurally 0 - entailed by [max_monkeys_seen] = 0, not separately
   printed). Together these are the load-bearing witness that
   [metadata_validity_check] - not S3's own quantifier - is what keeps
   dup-controller objects out of the store: S3 holds VACUOUSLY here
   (nothing with two controller refs is ever stored), and only MO-b makes
   S3 itself do work.

   ==== MO-b (MANUAL, MO-a + api_server.ml:95; NOT shipped) - compound ======

   Mutant: MO-a AND the admission guard's controlling count weakened
   ([List.length (List.filter is_controller refs) > 1] -> [> 2]), so
   exactly-two-controller objects are ADMITTED.

   MEASURED effect (the section-5 MO-b row CONFIRMED): the legs flip
   clean -> Refuted with [violated] naming S3
   [each_object_in_etcd_has_at_most_one_controller_owner] BY NAME (the
   anchor's L0 check-string printed it; every forge and the seed-shape
   check stayed green - the seed CR carries no owner refs) - the first
   stored reconciler pod carries both controller refs and S3's own [<= 1]
   bound does the rejecting. Records that S3 reads owner references, and
   discloses the DOUBLE-GUARD structure the scout predicted: no
   single-site mutant reddens S3 - MO-a alone is absorbed by the
   admission guard (MEASURED, the MO-a row), and the guard weakening
   alone leaves every reconciler-emitted create with <= 1 controller ref
   (structural: [make_owner_references] emits at most the one ref; not
   separately run) - only the compound does.

   ==== MA (MANUAL, cluster.ml:316-320; NOT shipped) - the negative control =

   Mutant: [restart_controller] ALSO resets the global rpc-id allocator
   ([rpc_id_allocator = Message.Rpc_id_allocator.init ()] added to the
   post-restart state) - P14's headline mutant, re-run against the P17
   family.

   MEASURED effect (the section-5 MA row CONFIRMED - the REQUIRED
   negative): refutes NOTHING in the store family - every violated-name
   check stayed ["<none>"], every clean / decisive check passed, all
   three fault edges still taken, all four maxima checks and the L0
   states pin passed UNMOVED; the first and only red was the Lc states
   pin, SHRUNK 464 -> 452 exactly as P16 measured for the same mutant
   (the reset allocator re-issues low rpc ids post-restart, so product
   states the true model keeps distinct MERGE - the pin moving, not the
   family; the P15 M1 lesson, and why the anchor asserts names FIRST and
   pins LAST; the Ld/Lm pins sit after the aborting check and were not
   evaluated - structurally MA is dead code there, their budgets cap
   crashes at 0 so [restart_controller] never fires). Cross-phase
   consistent with P14/P15/P16: rpc ids are not uids, and no store member
   reads the network.

   ==== MD (MANUAL, message.ml:346; NOT shipped) - the contrast datum =======

   Mutant: [form_matched_err_resp_msg]'s [Create_request] arm fabricates
   [{ res = Ok cr.obj }] instead of [{ res = Error err }] - P16's headline
   MD, re-run against the STORE family.

   MEASURED effect (the section-5 MD row CONFIRMED on the family, with the
   graph half REFINED): INERT on the store family - all four legs stayed
   clean and decisive with every violated-name check ["<none>"], all three
   edges taken, the L0 maxima AND the Ld content maxima at L0's exact
   values (the [max_uid_seen]/[max_rv_seen] 3/2 content check - drop never
   touches store content), and the L0/Lc states pins unmoved - but the Ld
   GRAPH pin moved, 744 -> 648 (both this anchor and [t_p17_store]'s Ld
   leg, its ONLY red): the true drop edge fans a pending [Create_request]
   out across EVERY api error while the mutant fabricates the SAME Ok
   response for all of them, so those product states MERGE - the pin
   moving, not the family (the P15 M1 lesson again; Lm's 1976 pin passed
   - no drop edge there). AND under the SAME application P16's Ld/Matched
   leg still reds: [t_p16_mutation]'s MD-converse check-string printed Q5
   [key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req]
   (every P16 forge, the Lmv probe and the P16 anchor stayed green) - the
   message-side/state-side contrast datum: one mutant that refutes the
   P16 response-correspondence family while the store family cannot see
   it (drop fabricates RESPONSES; the store is written only by the
   api_server handlers).

   ==== the automated rows (permanent; red-capability asserted every run) ===

   Per-member forges, each an ISOLATION audited for tautology and
   entailment (feedback-confirm-tests-by-mutation): the forged state
   violates EXACTLY its target member - asserted as a singleton
   [violated_names] sweep over the WHOLE family, so the exactness check
   and the other-two-members-still-hold check are the same assertion, and
   an accidentally-empty family cannot silently pass (the seed-shape test
   pins the three names first). Each forge also runs through the leg's own
   [Mc.check_safety] on a singleton product state (Refuted SEEN), each
   control through the same harness (clean SEEN), and each forge fires its
   target's own [interesting] (a premise-fired violation, never a vacuous
   one). Boundary discipline (the P14/P16 entailment lesson): the S2
   witnesses sit AT the counters ([rv = rvc], [uid = uidc]) so a [<] ->
   [<=] weakening is discriminated; a below-counter witness would be
   accepted by both and discriminate nothing.

   TEST-ORDERING RULE (P12 finding 1, P13-P17 precedent): semantic facts
   FIRST - names, clean, decisive (F7: BOTH asserted on every observation
   leg, baked in from the start), edge-taken, content maxima - and only
   THEN the brittle exact counts. Under the manual rows above this
   ordering is what lets the semantic verdicts print before a moved pin
   aborts the case.

   Firewall honoured: List/Option/fold combinators only (no loop
   keywords), exhaustive matches on every finite sum (both [Mc.outcome]
   arms), no two-arm match on [option]/[result] (stdlib [Option.fold] -
   its [~none] is EAGER, so every failing arm below is a closure applied
   after the fold), Alcotest as the sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Ois = Anvil_assurance.Objects_in_store

let controller_id : int = Scenario.controller_id
let desired : int = P17_witness.witness_desired
let depth : int = P17_witness.witness_depth
let bound : Bound.t = P17_witness.p17_bound ~desireds:[ desired ]
let family : Invariants.invariant list = Ois.store_family ~controller_id

(* The three upstream member names (t_p17_store addresses the family the
   same way; names are addresses, not pinned measurements). *)
let s1_name : string = "etcd_objects_have_unique_uids"
let s2_name : string = "each_object_in_etcd_is_weakly_well_formed"

let s3_name : string =
  "each_object_in_etcd_has_at_most_one_controller_owner"

(* ---- outcome / report projections (exhaustive 2-arm matches) ------------- *)

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

(* Every store member the state violates, by name, each member probed
   INDIVIDUALLY over the WHOLE family - what makes a forge an ISOLATION:
   [[]] is "all three hold"; a singleton is "exactly this member broke".
   Sound against a silently-empty family only together with
   {!test_seed_shape}'s name pin, which every suite runs first. *)
let violated_names (s : Cluster.cluster_state) : string list =
  List.filter_map
    (fun (i : Invariants.invariant) ->
      if i.Invariants.holds s then None else Some i.Invariants.name)
    family

(* The named member's own [interesting] - [false] on a missing name. Three
   of the four consumers assert TRUE, so a renamed member fails LOUD there;
   the S3 Some-[] disclosure check asserts FALSE (a rename would pass it
   vacuously) - within that same test the name pin at the forge site
   reddens first, which is what makes the FALSE-asserting consumer safe
   (P17-review correction: the previous comment claimed ALL consumers
   assert TRUE). *)
let interesting_fires (name : string) (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.interesting s)
    family

(* ---- the exact-leg-check harness (the t_p14/t_p15/t_p16 singleton form) -- *)

let singleton_reach (f : Fc.faulted) : Fc.faulted Mc.reachable =
  Mc.explore ~depth:1
    ~successors:(fun (_ : Fc.faulted) -> [])
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash ~init:[ f ]

(* The family exactly as the G7 leg asserts it: the conjunction, pointwise
   over the product wrapper. *)
let safety_of (f : Fc.faulted) : Fc.faulted Mc.outcome =
  let conj = Invariants.conjunction family in
  Mc.check_safety (singleton_reach f)
    ~inv:(fun (x : Fc.faulted) -> conj x.cs)
    ~equal:Fc.faulted_equal

(* A POST-MONKEY product state around a forged [cluster_state] - the
   monkey is THIS phase's leverage edge (spec section 4); the counters are
   inert to every [holds], the point is that the forges run through the
   SAME [Fc.faulted] wrapper the leg checks. *)
let product (cs : Cluster.cluster_state) : Fc.faulted =
  { Fc.cs; crashes = 0; drops = 0; monkeys = 1 }

(* ==== the forge =========================================================== *)

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ()

let seed_api : Api_server.state = seed.Cluster.api_server
let seed_uidc : int = seed_api.Api_server.uid_counter
let seed_rvc : int = seed_api.Api_server.resource_version_counter

(* The seed's server-created CR (scenario.ml:355-368 stamps it through the
   REAL [handle_create_request]); [None] is impossible on the true seed and
   every consumer fails LOUD through {!with_cr}. *)
let cr_stored : Dynamic_object.t option =
  Object_ref_map.find_opt Scenario.vsts_ref (Cluster.resources seed)

(* [Option.fold]'s [~none] is EAGER (house rule): both arms are CLOSURES
   and the fold's result is applied afterwards, so [Alcotest.fail] runs
   only on the genuinely-missing side. *)
let with_cr (f : Dynamic_object.t -> unit) : unit =
  Option.fold cr_stored
    ~none:(fun () -> Alcotest.fail "forge: seed CR missing from the store")
    ~some:(fun (cr : Dynamic_object.t) () -> f cr)
    ()

(* [seed] with ONLY the store replaced (counters preserved) - every forge
   is the seed plus a hand-built [resources] map, nothing else moves. *)
let forged (resources : (Common.object_ref * Dynamic_object.t) list) :
    Cluster.cluster_state =
  let stored =
    List.fold_left
      (fun (m : Dynamic_object.t Object_ref_map.t)
           ((k, o) : Common.object_ref * Dynamic_object.t) ->
        Object_ref_map.add k o m)
      Object_ref_map.empty resources
  in
  {
    seed with
    Cluster.api_server = { seed_api with Api_server.resources = stored };
  }

let with_md (f : Object_meta.t -> Object_meta.t) (o : Dynamic_object.t) :
    Dynamic_object.t =
  Dynamic_object.with_metadata (f (Dynamic_object.metadata o)) o

(* Forge INPUTS (not measured pins). The twin key differs from
   [Scenario.vsts_ref] only in [name], so a twin whose metadata carries the
   twin name satisfies S2's [object_ref == key] conjunct under it. *)
let twin_name : string = "vsts1-forged-twin"

let twin_key : Common.object_ref =
  { Scenario.vsts_ref with Common.name = twin_name }

(* The S1 witness: a SECOND object, weakly well formed under its own key
   (name re-stamped; rv and uid COPIED from the CR - the copied uid is the
   collision). *)
let twin_of (cr : Dynamic_object.t) : Dynamic_object.t =
  with_md (fun m -> { m with Object_meta.name = Some twin_name }) cr

let uid_int (o : Dynamic_object.t) : int =
  Option.fold (Dynamic_object.metadata o).Object_meta.uid ~none:(-1)
    ~some:Common.Uid.to_int

let rv_int (o : Dynamic_object.t) : int =
  Option.fold (Dynamic_object.metadata o).Object_meta.resource_version
    ~none:(-1) ~some:Common.Resource_version.to_int

(* Owner references for the S3 forge/control: [controller = Some true] is
   exactly upstream's [controller_owner_filter] (owner_reference.ml:24). *)
let ctrl_ref (name : string) : Owner_reference.t =
  {
    (Owner_reference.default ()) with
    Owner_reference.controller = Some true;
    name;
  }

let plain_ref (name : string) : Owner_reference.t =
  { (Owner_reference.default ()) with Owner_reference.name }

(* ==== seed shape (the fail-loud base every [] check rests on) ============= *)

let test_seed_shape () =
  Alcotest.(check (list string))
    "family = the three upstream objects_in_store.rs names, in order"
    [ s1_name; s2_name; s3_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family);
  Alcotest.(check int) "seed stores exactly the CR" 1
    (Object_ref_map.cardinal (Cluster.resources seed));
  Alcotest.(check bool) "seed CR present under vsts_ref" true
    (Option.is_some cr_stored);
  Alcotest.(check (list string)) "seed violates NOTHING" []
    (violated_names seed);
  (* Derivation guards for the boundary forges: the server stamped the CR
     strictly below both counters (scenario.ml:311-319). *)
  with_cr (fun cr ->
      Alcotest.(check bool) "seed CR uid stamped strictly below uid_counter"
        true
        (uid_int cr >= 0 && uid_int cr < seed_uidc);
      Alcotest.(check bool) "seed CR rv stamped strictly below rv_counter"
        true
        (rv_int cr >= 0 && rv_int cr < seed_rvc))

(* ==== S1: equal uids (the MU row's masked mechanism, seen at forge level) = *)

(* WHAT COULD MAKE THIS FAIL: reverting the P17 Deliverable-A projection
   fix in inv1 (the [filter_map] regression re-accepts the None/None pair),
   trivialising S1's [holds], weakening [sort_uniq]'s distinctness, or the
   twin construction drifting into an S2 violation (the exactness sweep
   catches all four). *)
let test_s1_forge () =
  with_cr (fun cr ->
      let twin = twin_of cr in
      (* EXACTNESS: the copied uid violates S1 and ONLY S1 - the twin is
         weakly well formed under its own key (S2 green) and carries no
         owner refs (S3 green). *)
      Alcotest.(check (list string))
        "S1 forge: equal-uid pair violates EXACTLY S1" [ s1_name ]
        (violated_names (forged [ (Scenario.vsts_ref, cr); (twin_key, twin) ]));
      Alcotest.(check bool) "S1 forge: S1's own interesting fires (>= 2)" true
        (interesting_fires s1_name
           (forged [ (Scenario.vsts_ref, cr); (twin_key, twin) ]));
      Alcotest.(check bool)
        "S1 forge: the leg's own check_safety REFUTES the product state" true
        (refuted
           (safety_of
              (product
                 (forged [ (Scenario.vsts_ref, cr); (twin_key, twin) ]))));
      (* CONTROL (tautology audit - the test CAN fail): the same twin with
         a DISTINCT minted-range uid is accepted by all three members. *)
      let distinct = uid_int cr - 1 in
      Alcotest.(check bool)
        "S1 control: derived distinct uid is in the minted range" true
        (distinct >= 0 && distinct < seed_uidc && distinct <> uid_int cr);
      let twin' =
        with_md
          (fun m ->
            { m with Object_meta.uid = Some (Common.Uid.of_int distinct) })
          twin
      in
      Alcotest.(check (list string)) "S1 control: distinct-uid pair accepted"
        []
        (violated_names (forged [ (Scenario.vsts_ref, cr); (twin_key, twin') ]));
      Alcotest.(check bool) "S1 control: the leg harness stays clean" true
        (not
           (refuted
              (safety_of
                 (product
                    (forged [ (Scenario.vsts_ref, cr); (twin_key, twin') ])))));
      (* Deliverable-A fix pins (NOT exactness witnesses - uid = None also
         breaks S2's conjunct 1, and that entailment is DISCLOSED here):
         two [None] uids collide at the fixed total projection (upstream's
         None->0, invariants.ml inv1), while a None/Some pair stays
         distinct (the port's disclosed rendering of upstream's unprovable
         case). Without these, reverting the fix would go unSEEN. *)
      let strip_uid o =
        with_md (fun m -> { m with Object_meta.uid = None }) o
      in
      Alcotest.(check (list string))
        "S1 fix pin: None/None pair violates S1 (and S2, disclosed)"
        [ s1_name; s2_name ]
        (violated_names
           (forged
              [
                (Scenario.vsts_ref, strip_uid cr);
                (twin_key, strip_uid twin);
              ]));
      Alcotest.(check (list string))
        "S1 fix pin: None/Some pair is DISTINCT for S1 (S2-only violation)"
        [ s2_name ]
        (violated_names
           (forged [ (Scenario.vsts_ref, cr); (twin_key, strip_uid twin) ])))

(* ==== S2: the counter boundaries (MU's and MR''s observed mechanism) ====== *)

(* WHAT COULD MAKE THIS FAIL: weakening either strict [<] to [<=] (the
   witnesses sit AT the counters - the entailment lesson), dropping a
   well-formedness conjunct, or the forged-rebuild control breaking (the
   [forged] builder itself must not introduce a violation). *)
let test_s2_forge () =
  with_cr (fun cr ->
      (* CONTROL first: the REBUILT seed (identity forge) is accepted -
         the builder introduces nothing. *)
      Alcotest.(check (list string)) "S2 control: rebuilt seed accepted" []
        (violated_names (forged [ (Scenario.vsts_ref, cr) ]));
      (* rv boundary: [rv = rvc] exactly - MR''s state class. *)
      let rv_at_counter =
        with_md
          (fun m ->
            {
              m with
              Object_meta.resource_version =
                Some (Common.Resource_version.of_int seed_rvc);
            })
          cr
      in
      Alcotest.(check int) "S2 rv witness sits AT the counter" seed_rvc
        (rv_int rv_at_counter);
      Alcotest.(check (list string))
        "S2 forge: rv = rvc violates EXACTLY S2 (strict <)" [ s2_name ]
        (violated_names (forged [ (Scenario.vsts_ref, rv_at_counter) ]));
      Alcotest.(check bool) "S2 forge: S2's own interesting fires (non-empty)"
        true
        (interesting_fires s2_name
           (forged [ (Scenario.vsts_ref, rv_at_counter) ]));
      Alcotest.(check bool)
        "S2 forge: the leg's own check_safety REFUTES the product state" true
        (refuted
           (safety_of (product (forged [ (Scenario.vsts_ref, rv_at_counter) ]))));
      (* uid boundary: [uid = uidc] exactly - the state class MU drives the
         seed into (the row's MEASURED masking mechanism, forge level). *)
      let uid_at_counter =
        with_md
          (fun m ->
            { m with Object_meta.uid = Some (Common.Uid.of_int seed_uidc) })
          cr
      in
      Alcotest.(check int) "S2 uid witness sits AT the counter" seed_uidc
        (uid_int uid_at_counter);
      Alcotest.(check (list string))
        "S2 forge: uid = uidc violates EXACTLY S2 (strict <)" [ s2_name ]
        (violated_names (forged [ (Scenario.vsts_ref, uid_at_counter) ])))

(* ==== S3: two controller owners (MO-b's stored shape, forge level) ======== *)

(* WHAT COULD MAKE THIS FAIL: weakening S3's [<= 1] bound, weakening
   [is_controller]'s [Some true] filter (the control's mixed list would
   then count 2), or inv3's [interesting] drifting off its documented
   strictly-stronger witness (the Some-[] check pins the disclosure). *)
let test_s3_forge () =
  with_cr (fun cr ->
      let two_ctrl =
        with_md
          (fun m ->
            {
              m with
              Object_meta.owner_references =
                Some [ ctrl_ref "owner-a"; ctrl_ref "owner-b" ];
            })
          cr
      in
      Alcotest.(check (list string))
        "S3 forge: two controller refs violate EXACTLY S3" [ s3_name ]
        (violated_names (forged [ (Scenario.vsts_ref, two_ctrl) ]));
      Alcotest.(check bool)
        "S3 forge: S3's own interesting fires (controller entry stored)" true
        (interesting_fires s3_name (forged [ (Scenario.vsts_ref, two_ctrl) ]));
      Alcotest.(check bool)
        "S3 forge: the leg's own check_safety REFUTES the product state" true
        (refuted
           (safety_of (product (forged [ (Scenario.vsts_ref, two_ctrl) ]))));
      (* CONTROL: one controller + one plain ref is accepted by all three -
         discriminates the [is_controller] filter from raw list length
         (the admission guard's [len > 1] pre-filter would reject this;
         S3 correctly does not). *)
      let mixed =
        with_md
          (fun m ->
            {
              m with
              Object_meta.owner_references =
                Some [ ctrl_ref "owner-a"; plain_ref "owner-b" ];
            })
          cr
      in
      Alcotest.(check (list string))
        "S3 control: one controller + one plain ref accepted" []
        (violated_names (forged [ (Scenario.vsts_ref, mixed) ]));
      Alcotest.(check bool) "S3 control: the leg harness stays clean" true
        (not (refuted (safety_of (product (forged [ (Scenario.vsts_ref, mixed) ])))));
      (* The DISCLOSED inv3 witness strengthening (objects_in_store.mli):
         [Some []] fires S3's literal per-key guard but NOT the shipped
         witness - pinned here so a silent widening of [interesting] to
         the literal guard is SEEN. *)
      let empty_refs =
        with_md
          (fun m -> { m with Object_meta.owner_references = Some [] })
          cr
      in
      Alcotest.(check (list string))
        "S3 disclosure: Some [] is accepted (guard fires, nothing counted)"
        []
        (violated_names (forged [ (Scenario.vsts_ref, empty_refs) ]));
      Alcotest.(check bool)
        "S3 disclosure: interesting does NOT fire on Some [] (strictly \
         stronger witness, kept deliberately)"
        false
        (interesting_fires s3_name (forged [ (Scenario.vsts_ref, empty_refs) ])))

(* ==== the manual rows' observation anchor ==================================
   The four LIVE G7 legs, re-run here as the section-5 observation points.
   Ordering is the protocol: violated NAMES first (a red PRINTS the member
   - MEASURED: MU/MR' print S2, MO-b prints S3, MA/MD/MO-a print
   nothing), then clean, then decisive (F7: both asserted on EVERY
   observation leg, so a frontier-truncated No_counterexample under a
   manual mutant fails loud instead of reading as clean), then edge-taken
   (MEASURED: MO-a's first red is the STARVED Lm monkey edge), then the
   content maxima (MEASURED: unmoved under MA and MD - MD's
   content-inertness half; MO-a's counter collapse was observed on
   [t_p17_store]'s Ld leg, 3 -> 2, since this anchor aborts at the
   starved edge first), then the graph and gate pins LAST (MEASURED:
   under MA only the Lc states pin reddened, 464 -> 452; under MD only
   the Ld states pin, 744 -> 648 - the P15 M1 lesson both times). *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget)
    ~(require_fault : bool) : Fc.fault_report =
  Fc.check_objects_in_store_under_faults ~depth ~req_drop ~pod_monkey bound
    budget ~desired ~require_fault

let test_manual_anchor () =
  let l0 =
    leg ~req_drop:false ~pod_monkey:false P17_witness.zero_budget
      ~require_fault:false
  in
  let lc =
    leg ~req_drop:false ~pod_monkey:false P17_witness.lc_budget
      ~require_fault:true
  in
  let ld =
    leg ~req_drop:true ~pod_monkey:false P17_witness.ld_budget
      ~require_fault:true
  in
  let lm =
    leg ~req_drop:false ~pod_monkey:true P17_witness.lm_budget
      ~require_fault:true
  in
  (* Violated NAMES first (a red PRINTS the member; a non-S1/S2/S3 name
     anywhere = the lists were unioned somewhere - harness bug, not a
     finding). *)
  Alcotest.(check string)
    "anchor: L0 violated names NOTHING (MU/MR' print S2 here, MO-b S3)"
    "<none>" (inv_name l0.violated);
  Alcotest.(check string) "anchor: Lc violated names NOTHING (MA's leg)"
    "<none>" (inv_name lc.violated);
  Alcotest.(check string) "anchor: Ld violated names NOTHING (MD's leg)"
    "<none>" (inv_name ld.violated);
  Alcotest.(check string) "anchor: Lm violated names NOTHING" "<none>"
    (inv_name lm.violated);
  (* Leg semantics: clean AND decisive on every observation leg (F7). *)
  Alcotest.(check bool) "anchor: L0 clean" true (report_clean l0);
  Alcotest.(check bool) "anchor: Lc clean" true (report_clean lc);
  Alcotest.(check bool) "anchor: Ld clean" true (report_clean ld);
  Alcotest.(check bool) "anchor: Lm clean" true (report_clean lm);
  Alcotest.(check bool) "anchor: L0 decisive" true (report_decisive l0);
  Alcotest.(check bool) "anchor: Lc decisive" true (report_decisive lc);
  Alcotest.(check bool) "anchor: Ld decisive" true (report_decisive ld);
  Alcotest.(check bool) "anchor: Lm decisive" true (report_decisive lm);
  (* Edge-taken: the fault edges are REALLY in the observed graphs. *)
  Alcotest.(check bool) "anchor: Lc crash REALLY taken" true
    (lc.max_crashes_seen >= 1);
  Alcotest.(check bool) "anchor: Ld drop REALLY taken" true
    (ld.max_drops_seen >= 1);
  Alcotest.(check bool) "anchor: Lm monkey REALLY taken" true
    (lm.max_monkeys_seen >= 1);
  (* Content maxima: MD's content-inertness half lives HERE (MEASURED:
     the Ld pair stayed at L0's exact 3/2 under MD while the Ld graph pin
     below moved). MO-a's counter collapse is observed on [t_p17_store]'s
     Ld leg instead (3 -> 2): this anchor aborts at the starved Lm
     edge-taken check before reaching these. *)
  Alcotest.(check int) "anchor: L0 max_uid_seen (unmoved under MA/MD)"
    P16_witness.l0_max_uid_seen l0.max_uid_seen;
  Alcotest.(check int) "anchor: L0 max_rv_seen (unmoved under MA/MD)"
    P16_witness.l0_max_rv_seen l0.max_rv_seen;
  Alcotest.(check int) "anchor: Ld max_uid_seen = L0's (MD content check)"
    P16_witness.ld_max_uid_seen ld.max_uid_seen;
  Alcotest.(check int) "anchor: Ld max_rv_seen = L0's (MD content check)"
    P16_witness.ld_max_rv_seen ld.max_rv_seen;
  (* Graph pins LAST (under MA ONLY the Lc pins may move). *)
  Alcotest.(check int) "anchor: L0 states (pinned)" P17_witness.l0_states
    (report_states l0);
  Alcotest.(check int) "anchor: Lc states (pinned; MA shrinks this)"
    P17_witness.lc_states (report_states lc);
  Alcotest.(check int) "anchor: Ld states (pinned; MD shrinks this)"
    P17_witness.ld_states (report_states ld);
  Alcotest.(check int) "anchor: Lm states (pinned)" P17_witness.lm_states
    (report_states lm);
  Alcotest.(check int) "anchor: L0 gate (pinned)" P17_witness.l0_gate_states
    (Option.value l0.gate_states ~default:(-1));
  Alcotest.(check int) "anchor: Lc gate (pinned)" P17_witness.lc_gate_states
    (Option.value lc.gate_states ~default:(-1));
  Alcotest.(check int) "anchor: Ld gate (pinned)" P17_witness.ld_gate_states
    (Option.value ld.gate_states ~default:(-1));
  Alcotest.(check int) "anchor: Lm gate (pinned)" P17_witness.lm_gate_states
    (Option.value lm.gate_states ~default:(-1))

let () =
  Alcotest.run "p17_mutation"
    [
      ( "seed_shape",
        [
          Alcotest.test_case
            "family names, singleton store, clean seed, stamped-below \
             counters"
            `Quick test_seed_shape;
        ] );
      ( "per_member_forges",
        [
          Alcotest.test_case
            "S1 rejects an equal-uid pair (MU's masked mechanism; \
             distinct-uid control accepted; Deliverable-A None pins)"
            `Quick test_s1_forge;
          Alcotest.test_case
            "S2 rejects rv/uid AT the counters (MR'/MU state class; \
             rebuilt-seed control accepted)"
            `Quick test_s2_forge;
          Alcotest.test_case
            "S3 rejects two controller owners (MO-b's stored shape; mixed \
             control accepted; Some-[] disclosure pinned)"
            `Quick test_s3_forge;
        ] );
      ( "manual_anchor",
        [
          Alcotest.test_case
            "the live L0/Lc/Ld/Lm legs, violated NAMED (MU/MR' print S2, \
             MO-b prints S3; MA moves only the Lc pin, MD only the Ld \
             pin; MO-a starves the Lm monkey edge)"
            `Quick test_manual_anchor;
        ] );
    ]

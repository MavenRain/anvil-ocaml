(* BUILD-SPEC-P18 section 7 - confirm-by-mutation for the HELPER family
   (H1 pods / H2 PVCs, asserted ALONE by the five P18 legs). A clean,
   decisive [No_counterexample] from [t_p18_helper] is only evidence if
   the family would MOVE when what it checks breaks; on the true model
   every leg is clean, so the Refuted path would otherwise ship with ZERO
   observed-red coverage. Two forms of evidence, the P14-P17 split: the
   MANUAL real-source mutants MB1 / MB2 / MB3 / MB3' / MB4 / MB5
   (documented below - applied with Edit, SEEN red or SEEN inert,
   reverted with Edit, never git checkout; only the green tree ships),
   and the AUTOMATED permanent per-conjunct forges below, whose
   red-capability is asserted on every run.

   ==== MB1 (MANUAL, v_stateful_set_reconciler.ml:218-220; NOT shipped) =====

   Mutant: [make_owner_references] duplicates the controller ref
   ([~some:(fun r -> [ r; r ])]) - byte-identical to P17's MO-a, re-run
   against the P18 family. Spec section 7 predicts all 5 legs red naming
   H1 at the first pod create; the P17 MO-a row predicts the OPPOSITE
   (the api_server admission guard [metadata_validity_check],
   api_server.ml:90-97, rejects >1-controller creates, so nothing bad is
   ever stored).

   MEASURED effect (the section-7 MB1 row: the spec prediction REFUTED -
   recorded as a finding, the honest-negative discipline; P17's MO-a
   mechanism re-observed against H1): NO leg refuted - the anchor's five
   violated-name checks all printed ["<none>"], every clean and decisive
   check passed, Lc crash and Ld drop edges taken, and the anchor's first
   red was the STARVED Lm monkey edge ([max_monkeys_seen] = 0 - the
   monkey's candidates are the stored pods and nothing is ever stored).
   The guard ABSORBS the mutant before H1 can see it: no pod is ever
   stored, so H1's premise STARVES - [t_p18_helper] under the mutant
   reddened at [L0: H1 interesting fires (> 0)] (count 0; the L0 graph
   rerouted 76 -> 68 with the replica still faithful at 68), Lc reddened
   at [post-crash gate > 0] (gate 0), Ld at [post-drop gate > 0] (gate
   0), Lm at the starved edge, and L0v at [H1 interesting fires] AFTER
   its H2-floor check PASSED - the PVC leg still mints PVCs ([make_pvc]
   does not call [make_owner_references]), so H2's non-vacuity floor
   survived while H1's premise died. Every H1 forge failed LOUD at the
   base extraction ("stored pod: missing") - the forge bases are real
   stored objects, and there are none. H1's red capability for the
   two-owner-ref shape is SEEN at forge level instead
   ({!test_h1_owner_forges}); the double-guard datum (admission guard,
   not H1's own quantifier, keeps dup-controller pods out of the store)
   is P17 MO-a/MO-b's, re-confirmed for the name-keyed member.

   ==== MB2 (MANUAL, two variants; NOT shipped) =============================

   Mutant, spec-literal site MB2-a (v_stateful_set_reconciler.ml:373-380,
   [make_pod]'s md literal gains [finalizers = Some [ "anvil.dev/p18" ]]):
   the finalizers-conjunct de-vacuizer - no scenario seeds finalizer
   pods, so the conjunct is true-by-construction on every shipped graph.
   Create passes finalizers through UNTOUCHED (api_server.ml:265-274),
   so the spec predicts all 5 legs red naming H1.

   MEASURED effect, MB2-a: FULLY GREEN - both exes passed every check
   with every pin at its committed value. Mechanism (unpredicted, the
   directional-trap diagnosis): [make_pod] pipes its md literal through
   [init_identity] -> [update_identity], whose identity re-stamp CLEARS
   [finalizers] and [deletion_timestamp]
   (v_stateful_set_reconciler.ml:250-251) - the reconciler LAUNDERS the
   stamp before any request is formed, a second absorption layer the
   spec did not name. Recorded as a MEASURED-CORRECTION in spec
   section 7.

   MEASURED effect, MB2-b (the effective variant, the laundering site
   itself: update_identity's [finalizers = None] at :250 becomes
   [Some [ "anvil.dev/p18" ]]; the section-7 MB2 row CONFIRMED at this
   site): all five legs flip clean -> Refuted with [violated] naming H1
   BY NAME (the anchor's FIRST check, [L0 violated], printed the full H1
   name; [t_p18_helper] reddened at [outcome clean] on all five legs,
   L0v included - the finalizer rides every reconciler-emitted pod) -
   the first stored pod carries the finalizer and H1's [Option.is_none
   md.finalizers] conjunct does the rejecting. The graph pins HELD
   (seed_shape stayed green: L0 76 / L0v 116 - the finalizer-carrying
   pod is ADMITTED, confirming the api_server passthrough), and the H1
   forge bases correctly reddened their base-accepted controls (the real
   stored pods now violate); the H2/PVC side stayed green throughout.

   ==== MB3 (MANUAL, two variants; NOT shipped) =============================
   ==== the predicted-INERT negative control ================================

   Mutant: a dt stamp ALONE, at each of the two layers MB2 exposed -
   MB3-a at the spec-literal site ([make_pod]'s md literal gains
   [deletion_timestamp = Some "p18-mutant-dt"]), MB3-b at the laundering
   site (update_identity's [deletion_timestamp = None] at :251 becomes
   the same [Some]) so the stamp actually REACHES the api_server, whose
   create overrides request dt to [None] (api_server.ml:265-274; spec
   section 2: no single-site source mutation can violate the dt
   conjunct). Predict ALL legs byte-identical: graphs AND counts.

   MEASURED effect (the section-7 MB3 row CONFIRMED - byte-identical,
   BOTH variants): [t_p18_mutation] AND [t_p18_helper] ran FULLY GREEN
   under each variant separately - all 6 + 6 cases, every state / gate /
   per-member pin at its committed value (76/464/744/1976/116 states,
   gates 52/244/272/1520/80, H1 52/296/376/1624/68, H2 0/0/0/0/80),
   every clean/decisive check green. The two greens carry DIFFERENT
   mechanisms: MB3-a is erased reconciler-side (the :250-251 laundering,
   never leaves [make_pod]'s pipeline), MB3-b is erased at the create
   boundary (the server override - the request carries the dt and the
   stored object does not, with the counts UNMOVED). The dt conjunct's
   red capability lives ONLY at forge level ({!test_h1_dt_forge}) and in
   the compound MB3'.

   ==== MB3' (MANUAL, api_server.ml:273 + reconciler :251; NOT shipped) =====
   ==== the COMPOUND dt mutant (P17 MO-b precedent) =========================

   Mutant (compound, disclosed): api_server create KEEPS the request dt
   ([deletion_timestamp = rm.deletion_timestamp] at :273) AND the
   MB3-b stamp (update_identity :251 emits [Some "p18-mutant-dt"], the
   variant that reaches the server; the spec-literal make_pod site is
   doubly absorbed, see MB2-a/MB3-a). No single-site dt mutant exists
   (MB3 measured the absorption at both layers); only the compound makes
   the dt conjunct do work. Predict red naming H1 (dt conjunct).

   MEASURED effect (the section-7 MB3' row CONFIRMED): all five legs flip
   clean -> Refuted with [violated] naming H1 BY NAME (the anchor's first
   check, [L0 violated], printed it; [t_p18_helper] reddened at [outcome
   clean] on all five legs; the seed itself stays clean - the CR's create
   request carries dt None, so seed_shape stayed FULLY green and the
   refutation lands at the first pod create). The THREE-layer structure
   for dt is the MEASURED datum: md-literal stamp laundered
   reconciler-side (MB3-a), surviving stamp erased by the server
   override (MB3-b), only stamp + passthrough reds (MB3') - the dt
   analogue of P17's MO-a/MO-b owner-ref pair, one layer deeper.

   ==== MB4 (MANUAL, v_stateful_set_reconciler.ml:279-286; NOT shipped) ====

   Mutant: [make_pvc]'s metadata gains
   [owner_references = Some (make_owner_references cr)] - a singleton
   controller ref, ADMITTED by the guard (<= 1 controller refs), so the
   stored PVC violates H2's [owner_references is None] conjunct. Predict
   L0v red naming H2 while the four vct:false legs stay BYTE-UNCHANGED
   (no vct:false graph ever mints a PVC) - the vct leg SEEN load-bearing.

   MEASURED effect (the section-7 MB4 row CONFIRMED, both halves): L0v
   flipped clean -> Refuted with [violated] naming H2 BY NAME (the
   anchor's four vct:false violated-name checks printed ["<none>"] and
   its L0v check printed the full H2 name; [t_p18_helper]'s L0v case
   reddened at [outcome clean]) AND the four vct:false legs ran
   BYTE-UNCHANGED. The byte-unchanged evidence is [t_p18_helper]'s four
   vct:false L0/Lc/Ld/Lm cases, which passed IN FULL - every state /
   gate / per-member pin at its committed value (76/464/744/1976
   states, gates 52/244/272/1520, H1 52/296/376/1624, H2 0/0/0/0) -
   plus THIS exe's anchor printing ["<none>"] on all four vct:false
   violated-name checks; the anchor's own clean/decisive/edge/maxima/
   states/gate checks sit AFTER its aborting L0v violated-name check
   (fifth in the protocol order) and were NOT evaluated under MB4, and
   this exe carries no H1/H2 per-member count checks at all (those live
   in [t_p18_helper] via [P18_witness]). The only OTHER red was itself a
   confirmation: {!test_h2_pvc_owner_forge}'s base-accepted control
   caught the real stored PVC now carrying the ref (the H1 forges and
   seed_shape stayed green). The [?vct] argument G7 omitted is exactly
   what carries H2's red capability, measured.

   ==== MB5 (MANUAL, cluster.ml:309; NOT shipped) - cross-phase control =====

   Mutant: [restart_controller] KEEPS [ongoing_reconciles]
   ([= cae.controller.ongoing_reconciles] instead of
   [Object_ref_map.empty]) - P13's M1, the lineage's oldest negative
   control, re-run against the P18 family. Predict every leg stays clean
   + decisive; only a known Lc graph movement appears (P14's G2 shrank
   464 -> 152 under this same mutant; P17's MA - a different restart
   mutant - moved its Lc pin 464 -> 452; B4 records which constant moves
   HERE with the actual number). Proves pins move, not the family.

   MEASURED effect (the section-7 MB5 row CONFIRMED - the REQUIRED
   negative): refutes NOTHING - the anchor's five violated-name checks
   stayed ["<none>"], every clean / decisive check passed, all three
   fault edges taken, every maxima check unmoved, the L0 states/gate
   pins passed, and the ONLY red in each exe was the Lc STATES pin,
   464 -> 152 - EXACTLY P14's G2 number under this same mutant:
   restart-as-no-op collapses every post-crash continuation onto the 76
   fault-free cluster states, x2 for the crash counter in the product.
   [t_p18_helper]'s L0 / Ld / Lm / L0v cases passed IN FULL (every pin);
   its Lc case reddened at the states pin first, so the Lc gate and H1
   count pins sit after the aborting check and were NOT evaluated
   (structurally entailed by the collapse, not separately measured - the
   P17 MA precedent, verbatim). Cross-phase consistent with P13/P14/P17:
   the family reads the STORE; restart bookkeeping moves only the
   product graph.

   ==== the automated rows (permanent; red-capability asserted every run) ===

   Per-conjunct forges, each an ISOLATION audited for tautology and
   entailment (feedback-confirm-tests-by-mutation), with the D1 parity
   discipline FROM BIRTH (BUILD-SPEC-P18 section 6 - all four checks on
   every forge): (1) the forged state violates EXACTLY its target member,
   asserted as a singleton [violated_names] sweep over the WHOLE family
   (the exactness check and the other-member-still-holds check are the
   same assertion; the seed-shape test pins both names first so an
   accidentally-empty family cannot silently pass); (2) the target's own
   [interesting] fires (a premise-fired violation, never a vacuous one);
   (3) the forged product state runs through the leg's own
   [Mc.check_safety] with Refuted SEEN; (4) a negative control state is
   SEEN not refuted. The forge BASES are REAL stored objects lifted off
   the legs' own replicas (a reachable pod / PVC binding), so the bases
   themselves certify the true model stores compliant metadata; controls
   include the PREMISE discriminators (the same bad metadata under a
   non-matching key is accepted - H1/H2 are name-keyed, not blanket) and
   the EQUIVALENCE discriminator (a wrong-uid owner ref is accepted -
   [eq_without_uid], not [Owner_reference.equal], spec section 2).

   TEST-ORDERING RULE (P12 finding 1, P13-P17 precedent): semantic facts
   FIRST - names, clean, decisive (both asserted on every observation
   leg), edge-taken, content maxima - and only THEN the brittle exact
   counts. Under the manual rows above this ordering is what lets the
   semantic verdicts print before a moved pin aborts the case.

   Firewall honoured: List/Option/fold combinators only (no loop
   keywords), exhaustive matches on every finite sum (both [Mc.outcome]
   arms; list shapes as [ r ] / [] / _ :: _ :: _), no two-arm match on
   [option]/[result] (stdlib [Option.fold] - its [~none] is EAGER, so
   every failing arm below is a closure applied after the fold),
   Alcotest as the sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Hi = Anvil_assurance.Helper_invariants

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P18_witness.witness_desired
let depth : int = P18_witness.witness_depth
let bound : Bound.t = P18_witness.p18_bound ~desireds:[ desired ]

(* The family exactly as the legs thread it (CR-parameterized, spec
   section 2): the vct:false instance for the four vct:false legs' forges,
   the vct:true instance for the H2 forge. *)
let family_f : Invariants.invariant list =
  Hi.helper_family ~cr:(Scenario.vsts ~desired ~vct:false ()) ~controller_id

let family_v : Invariants.invariant list =
  Hi.helper_family ~cr:(Scenario.vsts ~desired ~vct:true ()) ~controller_id

(* The two upstream member names (t_p18_helper addresses the family the
   same way; names are addresses, not pinned measurements). *)
let h1_name : string =
  "all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref"

let h2_name : string =
  "all_pvcs_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_or_owner_ref"

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

let violated_name (r : Fc.fault_report) : string =
  Option.fold r.violated ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* Every family member the state violates, by name, each member probed
   INDIVIDUALLY over the WHOLE (two-member) family - what makes a forge an
   ISOLATION: [[]] is "both hold"; a singleton is "exactly this member
   broke". Sound against a silently-empty family only together with
   {!test_seed_shape}'s name pin, which runs first. *)
let violated_names (family : Invariants.invariant list)
    (s : Cluster.cluster_state) : string list =
  List.filter_map
    (fun (i : Invariants.invariant) ->
      if i.Invariants.holds s then None else Some i.Invariants.name)
    family

(* The named member's own [interesting] - [false] on a missing name; the
   seed-shape name pin reddens first if a member is renamed. *)
let interesting_fires (family : Invariants.invariant list) (name : string)
    (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.interesting s)
    family

(* ---- the exact-leg-check harness (the t_p14..t_p17 singleton form) ------- *)

let singleton_reach (f : Fc.faulted) : Fc.faulted Mc.reachable =
  Mc.explore ~depth:1
    ~successors:(fun (_ : Fc.faulted) -> [])
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash ~init:[ f ]

(* The family exactly as the P18 leg asserts it: the conjunction, pointwise
   over the product wrapper, per family instance. *)
let safety_of (family : Invariants.invariant list) (f : Fc.faulted) :
    Fc.faulted Mc.outcome =
  let conj = Invariants.conjunction family in
  Mc.check_safety (singleton_reach f)
    ~inv:(fun (x : Fc.faulted) -> conj x.cs)
    ~equal:Fc.faulted_equal

(* A POST-MONKEY product state around a forged [cluster_state] - the
   monkey is THIS phase's leverage edge (the Lm headline); the counters
   are inert to every [holds], the point is that the forges run through
   the SAME [Fc.faulted] wrapper the leg checks. *)
let product (cs : Cluster.cluster_state) : Fc.faulted =
  { Fc.cs; crashes = 0; drops = 0; monkeys = 1 }

(* ==== seeds + forge builder =============================================== *)

let seed_f : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ~vct:false ()

let seed_v : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ~vct:true ()

(* The given seed with ONLY the store replaced (counters preserved) -
   every forge is a seed plus a hand-built [resources] map, nothing else
   moves (the t_p17 [forged] shape, parameterized by seed). *)
let forged_in (seed : Cluster.cluster_state)
    (resources : (Common.object_ref * Dynamic_object.t) list) :
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
    Cluster.api_server =
      { seed.Cluster.api_server with Api_server.resources = stored };
  }

let with_md (f : Object_meta.t -> Object_meta.t) (o : Dynamic_object.t) :
    Dynamic_object.t =
  Dynamic_object.with_metadata (f (Dynamic_object.metadata o)) o

(* The seeds' server-created CRs (scenario.ml stamps them through the REAL
   [handle_create_request]); [None] is impossible on the true seeds and
   every consumer fails LOUD through {!with_some}. *)
let cr_stored_f : Dynamic_object.t option =
  Object_ref_map.find_opt Scenario.vsts_ref (Cluster.resources seed_f)

let cr_stored_v : Dynamic_object.t option =
  Object_ref_map.find_opt Scenario.vsts_ref (Cluster.resources seed_v)

(* [Option.fold]'s [~none] is EAGER (house rule): both arms are CLOSURES
   and the fold's result is applied afterwards, so [Alcotest.fail] runs
   only on the genuinely-missing side. *)
let with_some (label : string) (o : 'a option) (f : 'a -> unit) : unit =
  Option.fold o
    ~none:(fun () -> Alcotest.fail (label ^ ": missing on the true model"))
    ~some:(fun (x : 'a) () -> f x)
    ()

(* ==== forge BASES: real stored objects off the legs' own replicas =========
   The L0 replica (52 of 76 states store a matching pod) donates the pod
   base; the L0v replica (80 of 116 states store the PVC) donates the PVC
   base. Same seed / bound / budget / depth as the legs through the
   exported {!Fc.faulted_successors}; the seed-shape test asserts the
   replicas explored the legs' exact graphs (witness pins). *)

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) : Fc.faulted Mc.reachable =
  let seed =
    Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ~vct
      ()
  in
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed seed ]

let l0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:false ~vct:false
       P18_witness.zero_budget)

let l0v_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:false ~vct:true
       P18_witness.zero_budget)

(* The last stored binding of [kind] found across the replica ([~none] is
   the cheap accumulator value, never a recursive call - the eager-[~none]
   rule). *)
let stored_binding_of_kind (reach : Fc.faulted Mc.reachable)
    (kind : Common.kind) : (Common.object_ref * Dynamic_object.t) option =
  Mc.fold_states reach ~init:None
    ~f:(fun (acc : (Common.object_ref * Dynamic_object.t) option)
            (f : Fc.faulted) ->
      Option.fold
        (List.find_opt
           (fun ((k, _) : Common.object_ref * Dynamic_object.t) ->
             Common.equal_kind k.Common.kind kind)
           (Object_ref_map.bindings (Cluster.resources f.Fc.cs)))
        ~none:acc
        ~some:(fun (b : Common.object_ref * Dynamic_object.t) -> Some b))

let pod_base : (Common.object_ref * Dynamic_object.t) option Lazy.t =
  lazy (stored_binding_of_kind (Lazy.force l0_reach) Pod.kind)

let pvc_base : (Common.object_ref * Dynamic_object.t) option Lazy.t =
  lazy
    (stored_binding_of_kind (Lazy.force l0v_reach)
       Persistent_volume_claim.kind)

(* A non-matching twin of a key: H1/H2 premise on the KEY's name shape, so
   the same (bad) object under this key is the PREMISE discriminator. *)
let unmanaged_key (key : Common.object_ref) : Common.object_ref =
  { key with Common.name = "unmanaged-" ^ key.Common.name }

(* ==== seed shape (the fail-loud base every exactness check rests on) ====== *)

let test_seed_shape () =
  Alcotest.(check (list string))
    "family (vct:false) = the two upstream helper_invariants.rs names"
    [ h1_name; h2_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family_f);
  Alcotest.(check (list string))
    "family (vct:true) = the same two names" [ h1_name; h2_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family_v);
  Alcotest.(check int) "vct:false seed stores exactly the CR" 1
    (Object_ref_map.cardinal (Cluster.resources seed_f));
  Alcotest.(check int) "vct:true seed stores exactly the CR" 1
    (Object_ref_map.cardinal (Cluster.resources seed_v));
  Alcotest.(check bool) "seed CR present under vsts_ref (both seeds)" true
    (Option.is_some cr_stored_f && Option.is_some cr_stored_v);
  (* MB3'-observation point: the SEEDS stay clean under every manual row
     (the CR is neither a pod nor a PVC key; under MB3' the refutation
     must land at the first pod create, never the seed). *)
  Alcotest.(check (list string)) "vct:false seed violates NOTHING" []
    (violated_names family_f seed_f);
  Alcotest.(check (list string)) "vct:true seed violates NOTHING" []
    (violated_names family_v seed_v);
  (* Forge bases exist on the true replicas, and the replicas explored the
     legs' exact graphs (the P13 M3/M5 faithfulness precedent, via the
     witness pins). *)
  Alcotest.(check int) "L0 replica = the leg's 76-state graph"
    P18_witness.l0_states
    (Mc.states_seen (Lazy.force l0_reach));
  Alcotest.(check int) "L0v replica = the leg's 116-state graph"
    P18_witness.l0v_states
    (Mc.states_seen (Lazy.force l0v_reach));
  Alcotest.(check bool) "a matching pod IS stored somewhere on L0" true
    (Option.is_some (Lazy.force pod_base));
  Alcotest.(check bool) "a matching PVC IS stored somewhere on L0v" true
    (Option.is_some (Lazy.force pvc_base))

(* ==== H1 forge 1: deletion_timestamp Some (MB3'-class, forge level) ======= *)

(* WHAT COULD MAKE THIS FAIL: dropping H1's [Option.is_none
   md.deletion_timestamp] conjunct, the premise drifting off the key
   (the unmanaged-key control would then red), or the base extraction
   breaking (a non-compliant pod stored on the true graph). *)
let test_h1_dt_forge () =
  with_some "H1 dt forge: stored pod" (Lazy.force pod_base)
    (fun ((key, pod) : Common.object_ref * Dynamic_object.t) ->
      with_some "H1 dt forge: seed CR" cr_stored_f (fun cr ->
          (* CONTROL first: the REAL base is accepted and runs the leg
             harness clean. *)
          let base = forged_in seed_f [ (Scenario.vsts_ref, cr); (key, pod) ] in
          Alcotest.(check (list string)) "H1 base: real stored pod accepted"
            [] (violated_names family_f base);
          Alcotest.(check bool) "H1 base: the leg harness stays clean" true
            (not (refuted (safety_of family_f (product base))));
          (* The forge: dt stamped on the SAME stored pod. *)
          let marked = with_md
              (fun m -> { m with Object_meta.deletion_timestamp = Some "p18-forged-dt" })
              pod
          in
          let bad = forged_in seed_f [ (Scenario.vsts_ref, cr); (key, marked) ] in
          Alcotest.(check (list string))
            "H1 dt forge: dt Some violates EXACTLY H1" [ h1_name ]
            (violated_names family_f bad);
          Alcotest.(check bool) "H1 dt forge: H1's own interesting fires" true
            (interesting_fires family_f h1_name bad);
          Alcotest.(check bool)
            "H1 dt forge: the leg's own check_safety REFUTES the product state"
            true
            (refuted (safety_of family_f (product bad)));
          (* PREMISE discriminator: the SAME dt-marked object under a
             non-matching key is accepted - H1 is name-keyed, not a
             blanket dt check. *)
          let off =
            forged_in seed_f
              [ (Scenario.vsts_ref, cr); (unmanaged_key key, marked) ]
          in
          Alcotest.(check (list string))
            "H1 dt control: same object under a non-matching key accepted" []
            (violated_names family_f off);
          Alcotest.(check bool) "H1 dt control: the leg harness stays clean"
            true
            (not (refuted (safety_of family_f (product off))))))

(* ==== H1 forge 2: finalizers Some (the MB2 shape, forge level) ============ *)

(* WHAT COULD MAKE THIS FAIL: dropping H1's [Option.is_none md.finalizers]
   conjunct (the MB2 de-vacuized conjunct), or the base drifting. *)
let test_h1_finalizer_forge () =
  with_some "H1 finalizer forge: stored pod" (Lazy.force pod_base)
    (fun ((key, pod) : Common.object_ref * Dynamic_object.t) ->
      with_some "H1 finalizer forge: seed CR" cr_stored_f (fun cr ->
          let marked =
            with_md
              (fun m ->
                { m with Object_meta.finalizers = Some [ "anvil.dev/p18" ] })
              pod
          in
          let bad = forged_in seed_f [ (Scenario.vsts_ref, cr); (key, marked) ] in
          Alcotest.(check (list string))
            "H1 finalizer forge: finalizers Some violates EXACTLY H1"
            [ h1_name ]
            (violated_names family_f bad);
          Alcotest.(check bool)
            "H1 finalizer forge: H1's own interesting fires" true
            (interesting_fires family_f h1_name bad);
          Alcotest.(check bool)
            "H1 finalizer forge: the leg's own check_safety REFUTES the \
             product state"
            true
            (refuted (safety_of family_f (product bad)));
          (* CONTROL: the unmarked base is accepted (asserted again HERE so
             this forge is a self-contained isolation, not entailed by the
             dt test's control). *)
          let base = forged_in seed_f [ (Scenario.vsts_ref, cr); (key, pod) ] in
          Alcotest.(check (list string))
            "H1 finalizer control: unmarked base accepted" []
            (violated_names family_f base);
          Alcotest.(check bool)
            "H1 finalizer control: the leg harness stays clean" true
            (not (refuted (safety_of family_f (product base))))))

(* ==== H1 forge 3: the owner-ref conjunct, all three violation shapes ====== *)

(* WHAT COULD MAKE THIS FAIL: widening the singleton list-match (two refs
   or [Some []] accepted), swapping [eq_without_uid] for full
   [Owner_reference.equal] (the wrong-uid CONTROL reddens - the spec
   section 2 rendering decision SEEN), or weakening the name comparison
   (the wrong-name forge is accepted). *)
let test_h1_owner_forges () =
  with_some "H1 owner forges: stored pod" (Lazy.force pod_base)
    (fun ((key, pod) : Common.object_ref * Dynamic_object.t) ->
      with_some "H1 owner forges: seed CR" cr_stored_f (fun cr ->
          with_some "H1 owner forges: the stored pod's own singleton ref"
            (Option.bind
               (Dynamic_object.metadata pod).Object_meta.owner_references
               (fun (l : Owner_reference.t list) ->
                 match l with
                 | [ r ] -> Some r
                 | [] | _ :: _ :: _ -> None))
            (fun (r : Owner_reference.t) ->
              let with_refs (refs : Owner_reference.t list option) :
                  Cluster.cluster_state =
                forged_in seed_f
                  [
                    (Scenario.vsts_ref, cr);
                    ( key,
                      with_md
                        (fun m ->
                          { m with Object_meta.owner_references = refs })
                        pod );
                  ]
              in
              (* Forge a: TWO refs (MB1's stored shape, which the admission
                 guard absorbs at source level - forge level is where H1's
                 own rejection is SEEN). *)
              Alcotest.(check (list string))
                "H1 owner forge: two refs violate EXACTLY H1" [ h1_name ]
                (violated_names family_f (with_refs (Some [ r; r ])));
              Alcotest.(check bool)
                "H1 owner forge (two refs): interesting fires" true
                (interesting_fires family_f h1_name
                   (with_refs (Some [ r; r ])));
              Alcotest.(check bool)
                "H1 owner forge (two refs): check_safety REFUTES" true
                (refuted
                   (safety_of family_f (product (with_refs (Some [ r; r ])))));
              (* Forge b: WRONG-NAME ref ([eq_without_uid] compares name). *)
              let wrong_name =
                { r with Owner_reference.name = r.Owner_reference.name ^ "-not-the-cr" }
              in
              Alcotest.(check (list string))
                "H1 owner forge: wrong-name ref violates EXACTLY H1"
                [ h1_name ]
                (violated_names family_f (with_refs (Some [ wrong_name ])));
              Alcotest.(check bool)
                "H1 owner forge (wrong name): interesting fires" true
                (interesting_fires family_f h1_name
                   (with_refs (Some [ wrong_name ])));
              Alcotest.(check bool)
                "H1 owner forge (wrong name): check_safety REFUTES" true
                (refuted
                   (safety_of family_f
                      (product (with_refs (Some [ wrong_name ])))));
              (* Forge c: [Some []] - the disclosed make_owner_references
                 degradation corner (spec section 2): the singleton match
                 rejects it. *)
              Alcotest.(check (list string))
                "H1 owner forge: Some [] violates EXACTLY H1" [ h1_name ]
                (violated_names family_f (with_refs (Some [])));
              Alcotest.(check bool)
                "H1 owner forge (Some []): interesting fires" true
                (interesting_fires family_f h1_name (with_refs (Some [])));
              Alcotest.(check bool)
                "H1 owner forge (Some []): check_safety REFUTES" true
                (refuted (safety_of family_f (product (with_refs (Some [])))));
              (* CONTROL 1 (the EQUIVALENCE discriminator): a WRONG-UID ref
                 is accepted - H1 compares [eq_without_uid] (uid EXCLUDED,
                 owner_reference.rs:37-42), never full equality; the
                 uid-exact sibling is E1, excluded with a measured pin
                 (t_p18_regression). *)
              let wrong_uid =
                {
                  r with
                  Owner_reference.uid =
                    Common.Uid.of_int (Common.Uid.to_int r.Owner_reference.uid + 1);
                }
              in
              Alcotest.(check (list string))
                "H1 owner control: wrong-uid ref accepted (eq_without_uid)"
                []
                (violated_names family_f (with_refs (Some [ wrong_uid ])));
              Alcotest.(check bool)
                "H1 owner control (wrong uid): the leg harness stays clean"
                true
                (not
                   (refuted
                      (safety_of family_f
                         (product (with_refs (Some [ wrong_uid ]))))));
              (* CONTROL 2: the base singleton is accepted. *)
              Alcotest.(check (list string))
                "H1 owner control: real singleton ref accepted" []
                (violated_names family_f (with_refs (Some [ r ]))))))

(* ==== H2 forges: owner-ref / dt / finalizers on a real PVC ================
   Forge 1 is the MB4 shape (owner-ref-bearing PVC); forges 2 and 3 (P18
   review addition) give H2's OTHER two conjuncts their red evidence -
   before them, deleting the dt or finalizers conjunct from H2's [holds]
   left every exe green (never SEEN to fail). CONFIRMED BY MUTATION
   (2026-07-27): each conjunct Edit-deleted alone from
   helper_invariants.ml, rebuilt, THIS exe reddened at exactly the new
   forge's own EXACTLY-H2 check, Edit-restored, revert verified
   [git diff] EMPTY - the two forges SEEN red-capable. *)

(* WHAT COULD MAKE THIS FAIL: dropping ANY of H2's three [Option.is_none]
   conjuncts (owner_references / deletion_timestamp / finalizers - each
   now has its own forge), the PVC name matcher drifting off [pvc_name]'s
   shape (the base would stop firing), or the premise widening past the
   key (the unmanaged-key controls redden). *)
let test_h2_pvc_owner_forge () =
  with_some "H2 forge: stored PVC" (Lazy.force pvc_base)
    (fun ((key, pvc) : Common.object_ref * Dynamic_object.t) ->
      with_some "H2 forge: seed CR (vct)" cr_stored_v (fun cr ->
          with_some "H2 forge: a controller ref to plant"
            (Option.bind (Lazy.force pod_base)
               (fun ((_, pod) : Common.object_ref * Dynamic_object.t) ->
                 Option.bind
                   (Dynamic_object.metadata pod).Object_meta.owner_references
                   (fun (l : Owner_reference.t list) ->
                     match l with
                     | [ r ] -> Some r
                     | [] | _ :: _ :: _ -> None)))
            (fun (r : Owner_reference.t) ->
              (* CONTROL first: the REAL stored PVC (no owner refs, the
                 make_pvc contract) is accepted and runs the harness
                 clean. *)
              let base =
                forged_in seed_v [ (Scenario.vsts_ref, cr); (key, pvc) ]
              in
              Alcotest.(check (list string))
                "H2 base: real stored PVC accepted" []
                (violated_names family_v base);
              Alcotest.(check bool) "H2 base: the leg harness stays clean"
                true
                (not (refuted (safety_of family_v (product base))));
              (* The forge: a single controller ref planted on the PVC -
                 exactly the shape MB4 stamps at source (admitted by the
                 guard; H2's own conjunct must reject it). *)
              let marked =
                with_md
                  (fun m ->
                    { m with Object_meta.owner_references = Some [ r ] })
                  pvc
              in
              let bad =
                forged_in seed_v [ (Scenario.vsts_ref, cr); (key, marked) ]
              in
              Alcotest.(check (list string))
                "H2 forge: owner-ref-bearing PVC violates EXACTLY H2"
                [ h2_name ]
                (violated_names family_v bad);
              Alcotest.(check bool) "H2 forge: H2's own interesting fires"
                true
                (interesting_fires family_v h2_name bad);
              Alcotest.(check bool)
                "H2 forge: the leg's own check_safety REFUTES the product \
                 state"
                true
                (refuted (safety_of family_v (product bad)));
              (* PREMISE discriminator: the same marked PVC under a
                 non-matching key is accepted. *)
              let off =
                forged_in seed_v
                  [ (Scenario.vsts_ref, cr); (unmanaged_key key, marked) ]
              in
              Alcotest.(check (list string))
                "H2 control: same PVC under a non-matching key accepted" []
                (violated_names family_v off);
              Alcotest.(check bool)
                "H2 control: the leg harness stays clean" true
                (not (refuted (safety_of family_v (product off))));
              (* H2 forge 2: deletion_timestamp Some on the SAME real PVC -
                 red evidence for H2's [is_none deletion_timestamp]
                 conjunct (P18 review: previously the owner-ref conjunct
                 was the only one SEEN to fail; deleting the dt conjunct
                 kept every exe green). Same 4-check parity. *)
              let dt_marked =
                with_md
                  (fun m ->
                    {
                      m with
                      Object_meta.deletion_timestamp =
                        Some "p18-forged-pvc-dt";
                    })
                  pvc
              in
              let dt_bad =
                forged_in seed_v [ (Scenario.vsts_ref, cr); (key, dt_marked) ]
              in
              Alcotest.(check (list string))
                "H2 dt forge: dt Some violates EXACTLY H2" [ h2_name ]
                (violated_names family_v dt_bad);
              Alcotest.(check bool) "H2 dt forge: H2's own interesting fires"
                true
                (interesting_fires family_v h2_name dt_bad);
              Alcotest.(check bool)
                "H2 dt forge: the leg's own check_safety REFUTES the \
                 product state"
                true
                (refuted (safety_of family_v (product dt_bad)));
              let dt_off =
                forged_in seed_v
                  [ (Scenario.vsts_ref, cr); (unmanaged_key key, dt_marked) ]
              in
              Alcotest.(check (list string))
                "H2 dt control: same PVC under a non-matching key accepted"
                []
                (violated_names family_v dt_off);
              Alcotest.(check bool)
                "H2 dt control: the leg harness stays clean" true
                (not (refuted (safety_of family_v (product dt_off))));
              (* H2 forge 3: finalizers Some on the SAME real PVC - red
                 evidence for H2's [is_none finalizers] conjunct (the other
                 previously never-SEEN-to-fail conjunct). Same parity. *)
              let fin_marked =
                with_md
                  (fun m ->
                    {
                      m with
                      Object_meta.finalizers = Some [ "anvil.dev/p18-pvc" ];
                    })
                  pvc
              in
              let fin_bad =
                forged_in seed_v
                  [ (Scenario.vsts_ref, cr); (key, fin_marked) ]
              in
              Alcotest.(check (list string))
                "H2 finalizer forge: finalizers Some violates EXACTLY H2"
                [ h2_name ]
                (violated_names family_v fin_bad);
              Alcotest.(check bool)
                "H2 finalizer forge: H2's own interesting fires" true
                (interesting_fires family_v h2_name fin_bad);
              Alcotest.(check bool)
                "H2 finalizer forge: the leg's own check_safety REFUTES \
                 the product state"
                true
                (refuted (safety_of family_v (product fin_bad)));
              let fin_off =
                forged_in seed_v
                  [ (Scenario.vsts_ref, cr); (unmanaged_key key, fin_marked) ]
              in
              Alcotest.(check (list string))
                "H2 finalizer control: same PVC under a non-matching key \
                 accepted"
                []
                (violated_names family_v fin_off);
              Alcotest.(check bool)
                "H2 finalizer control: the leg harness stays clean" true
                (not (refuted (safety_of family_v (product fin_off)))))))

(* ==== the manual rows' observation anchor ==================================
   The five LIVE P18 legs, re-run here as the section-7 observation
   points. Ordering is the protocol: violated NAMES first (a red PRINTS
   the member - MEASURED: MB2-b/MB3' print the full H1 name at the very
   first check, MB4 passes four ["<none>"]s then prints H2 at its L0v
   check, MB1/MB3/MB5 print nothing), then clean, then decisive (both
   asserted on EVERY observation leg), then edge-taken (MEASURED: MB1
   starves the Lm monkey edge, the MO-a mechanism), then the content
   maxima, then the graph and gate pins LAST (MEASURED: under MB5 the
   FIRST and only red is the Lc states pin, 464 -> 152 - the P15 M1
   lesson again; the Lc gate pin sits after the abort and was not
   evaluated; under MB3 both variants every pin passed byte-identical). *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) ~(require_fault : bool) : Fc.fault_report =
  Fc.check_helper_invariants_under_faults ~depth ~req_drop ~pod_monkey ~vct
    bound budget ~desired ~require_fault

let test_manual_anchor () =
  let l0 =
    leg ~req_drop:false ~pod_monkey:false ~vct:false P18_witness.zero_budget
      ~require_fault:false
  in
  let lc =
    leg ~req_drop:false ~pod_monkey:false ~vct:false P18_witness.lc_budget
      ~require_fault:true
  in
  let ld =
    leg ~req_drop:true ~pod_monkey:false ~vct:false P18_witness.ld_budget
      ~require_fault:true
  in
  let lm =
    leg ~req_drop:false ~pod_monkey:true ~vct:false P18_witness.lm_budget
      ~require_fault:true
  in
  let l0v =
    leg ~req_drop:false ~pod_monkey:false ~vct:true P18_witness.zero_budget
      ~require_fault:false
  in
  (* Violated NAMES first: a red here PRINTS the member. *)
  Alcotest.(check string) "anchor: L0 violated" "<none>" (violated_name l0);
  Alcotest.(check string) "anchor: Lc violated" "<none>" (violated_name lc);
  Alcotest.(check string) "anchor: Ld violated" "<none>" (violated_name ld);
  Alcotest.(check string) "anchor: Lm violated" "<none>" (violated_name lm);
  Alcotest.(check string) "anchor: L0v violated" "<none>" (violated_name l0v);
  (* Leg semantics: clean AND decisive on every observation leg. *)
  Alcotest.(check bool) "anchor: L0 clean" true (report_clean l0);
  Alcotest.(check bool) "anchor: Lc clean" true (report_clean lc);
  Alcotest.(check bool) "anchor: Ld clean" true (report_clean ld);
  Alcotest.(check bool) "anchor: Lm clean" true (report_clean lm);
  Alcotest.(check bool) "anchor: L0v clean" true (report_clean l0v);
  Alcotest.(check bool) "anchor: L0 decisive" true (report_decisive l0);
  Alcotest.(check bool) "anchor: Lc decisive" true (report_decisive lc);
  Alcotest.(check bool) "anchor: Ld decisive" true (report_decisive ld);
  Alcotest.(check bool) "anchor: Lm decisive" true (report_decisive lm);
  Alcotest.(check bool) "anchor: L0v decisive" true (report_decisive l0v);
  (* Edge-taken: the fault edges are REALLY in the observed graphs
     (MEASURED: MB1 starves the Lm monkey edge - candidates are the
     stored pods and nothing is stored). *)
  Alcotest.(check bool) "anchor: Lc crash REALLY taken" true
    (lc.max_crashes_seen >= 1);
  Alcotest.(check bool) "anchor: Ld drop REALLY taken" true
    (ld.max_drops_seen >= 1);
  Alcotest.(check bool) "anchor: Lm monkey REALLY taken" true
    (lm.max_monkeys_seen >= 1);
  (* Content maxima (graph constants; unmoved under every P18 row). *)
  Alcotest.(check int) "anchor: L0 max_uid_seen" P16_witness.l0_max_uid_seen
    l0.max_uid_seen;
  Alcotest.(check int) "anchor: L0 max_rv_seen" P16_witness.l0_max_rv_seen
    l0.max_rv_seen;
  Alcotest.(check int) "anchor: Lm max_uid_seen (P16 graph identity)"
    P16_witness.lm_max_uid_seen lm.max_uid_seen;
  Alcotest.(check int) "anchor: L0v max_uid_seen (P16 graph identity)"
    P18_witness.l0v_max_uid_seen l0v.max_uid_seen;
  (* Graph pins LAST (under MB5 ONLY the Lc pins move). *)
  Alcotest.(check int) "anchor: L0 states (pinned)" P18_witness.l0_states
    (report_states l0);
  Alcotest.(check int) "anchor: Lc states (pinned; MB5 shrinks this)"
    P18_witness.lc_states (report_states lc);
  Alcotest.(check int) "anchor: Ld states (pinned)" P18_witness.ld_states
    (report_states ld);
  Alcotest.(check int) "anchor: Lm states (pinned)" P18_witness.lm_states
    (report_states lm);
  Alcotest.(check int) "anchor: L0v states (pinned)" P18_witness.l0v_states
    (report_states l0v);
  Alcotest.(check int) "anchor: L0 gate (pinned)" P18_witness.l0_gate_states
    (Option.value l0.gate_states ~default:(-1));
  Alcotest.(check int) "anchor: Lc gate (pinned; MB5 moves this)"
    P18_witness.lc_gate_states
    (Option.value lc.gate_states ~default:(-1));
  Alcotest.(check int) "anchor: Ld gate (pinned)" P18_witness.ld_gate_states
    (Option.value ld.gate_states ~default:(-1));
  Alcotest.(check int) "anchor: Lm gate (pinned)" P18_witness.lm_gate_states
    (Option.value lm.gate_states ~default:(-1));
  Alcotest.(check int) "anchor: L0v gate (pinned)"
    P18_witness.l0v_gate_states
    (Option.value l0v.gate_states ~default:(-1))

let () =
  Alcotest.run "p18_mutation"
    [
      ( "seed_shape",
        [
          Alcotest.test_case
            "family names, singleton clean seeds, forge bases present on \
             the true replicas"
            `Quick test_seed_shape;
        ] );
      ( "per_conjunct_forges",
        [
          Alcotest.test_case
            "H1 rejects dt Some (MB3''s stored shape; non-matching-key \
             control accepted)"
            `Quick test_h1_dt_forge;
          Alcotest.test_case
            "H1 rejects finalizers Some (MB2's stored shape; unmarked \
             control accepted)"
            `Quick test_h1_finalizer_forge;
          Alcotest.test_case
            "H1 rejects two refs / wrong-name / Some [] (MB1's absorbed \
             shape; wrong-uid control accepted - eq_without_uid SEEN)"
            `Quick test_h1_owner_forges;
          Alcotest.test_case
            "H2 rejects an owner-ref-bearing / dt-stamped / \
             finalizer-carrying PVC (per-conjunct; MB4's stored shape \
             first; non-matching-key controls accepted)"
            `Quick test_h2_pvc_owner_forge;
        ] );
      ( "manual_anchor",
        [
          Alcotest.test_case
            "the live L0/Lc/Ld/Lm/L0v legs, violated NAMED (MB2-b/MB3' \
             print H1, MB4 prints H2 on L0v; MB1 starves the Lm edge; MB3 \
             byte-identical; MB5 moves only the Lc states pin)"
            `Quick test_manual_anchor;
        ] );
    ]

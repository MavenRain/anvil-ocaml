(* BUILD-SPEC-P20 section 7 - confirm-by-mutation for the RELY-condition
   family (R1 [vsts_rely_create_req] / R2 [vsts_rely_update_req] / R3
   [vsts_rely_conditions_pod_monkey], asserted by the P20 Leg-A legs) and for
   Leg B's forge shapes.

   WHY THIS EXE EXISTS, and it is NOT the usual reason. P14-P19's mutation
   exes existed because their legs came back CLEAN and a clean leg is only
   evidence if the family would MOVE when what it classifies breaks. P20's
   headline leg comes back RED, so the burden here is the mirror image and it
   has three parts:

   1. ATTRIBUTION. Lm's red is produced by a monkey re-sending a STORED vsts
      pod, where R1's TWO conjuncts fail together and R2's THREE fail
      together. A leg red therefore proves nothing about WHICH conjunct is
      load-bearing. The F-rows below break each conjunct INDEPENDENTLY, off a
      base whose in-flight pool is empty, so every red is attributable to one
      clause of one upstream line.
   2. DISCRIMINATION. A family that rejected everything would also come back
      red. Every F-row therefore ships a negative control of the SAME shape
      that is ACCEPTED with the member's premise still firing, and the
      owner-ref row ships one control per pinned field of the section-2.1
      collapse.
   3. NECESSITY OF THE FORGE. Leg B's red must be attributable to
      RELY-VIOLATION rather than to forging as such, which is what row C1
      measures - here as a state-level differential over the two shipped
      forge shapes AND as the leg-level flip.

   THE ISOLATION FORM IS NOT P19'S, AND THE DIFFERENCE IS DISCLOSED CONTENT.
   P14-P19 assert [violated_names = [target]] - exactly one member broke.
   That is IMPOSSIBLE here by construction: [rely_conditions.mli] discloses
   [R3 <=> R1 && R2] up front (R3's match at rely_guarantee.rs:23-27 has
   exactly two constrained arms and they are R1's and R2's bodies), so any
   state that reddens an arm reddens R3 too. The isolation assertion below is
   therefore [violated_names = [target; R3]] - the target arm, R3, and
   NOTHING ELSE, which also re-measures prediction 6's identity at every
   forged state. Reading it as a weaker isolation inverts it: it is the same
   claim plus an identity check.

   ==== the automated rows (permanent; red-capability asserted every run) ====

   F-R1a  conjunct (a) via [metadata.name] (rely_guarantee.rs:61-66 then-branch)
   F-R1b  conjunct (a) via [metadata.generate_name] with [name = None] - the
          ONLY witness anywhere in the tree for upstream's :63-66 ELSE-branch,
          with the shadowing control that proves the else is really an else
   F-R1c  conjunct (b), the section-2.1 owner-ref existential collapse
          (:68-69), with one control per PINNED field and one per FREE field
   F-R2a  conjunct (a) on the REQUEST's name (:80)
   F-R2b  conjunct (b), the STORED object (:82-83) - its only red witness is a
          state where etcd ALREADY holds a vsts-owned object at the request's
          key, so this row is the only place the port's disclosed
          [Option.fold ~none:true] missing-key rendering is exercised in both
          directions
   F-R2c  conjunct (c), the NEW object becoming vsts-owned (:85)
   F-R3   the PERMITTED arms (:26) under a MAXIMALLY rely-violating payload -
          a positive control, not an absence, plus the same-state differential
          that proves the permissiveness is per-ARM and not per-PAYLOAD
   F-PVC  the PersistentVolumeClaim arm of R1/R2, whose only red witness
          anywhere is a forge (the monkey emits pod-keyed requests ONLY, which
          is what P19's M2 asserts), with the nine OTHER [Common.kind]
          constructors as accepted controls - the :71 [_ => true] arm, spelled
          out and SEEN
   C1     the containment control, twice: as a state-level differential over
          {!Anvil_checker.Fault_check.rely_violating_forge} vs
          {!Anvil_checker.Fault_check.rely_respecting_forge}, and as the
          leg-level verdict flip

   ==== the MANUAL rows (applied with Edit, SEEN, reverted by Edit) ==========

   Every manual row states its MECHANISM and its PREDICTION before running and
   records the MEASURED result even when that refutes the prediction (the P19
   MN1' discipline). Reverts rewrite the pre-mutation bytes with an exact
   [Edit] and are verified with [git diff] against the staged index - never
   [git checkout --], never an [sd] empty-pattern revert. TWO of the three
   rows below REFUTE what BUILD-SPEC-P20 section 7 predicted, and the
   refutations are the most informative rows in the matrix.

   ==== ML2 (MANUAL, rely_conditions.ml:55-56; NOT shipped) =================
   ==== the SPEC'S PREDICTION REFUTED, and the row that pays for itself =====

   Mutant: the family's own classifier stops classifying -
   [has_vsts_prefix name = String.starts_with ~prefix:vsts_prefix name]
   becomes [false && String.starts_with ~prefix:vsts_prefix name], i.e. a
   constant [false].

   METHODOLOGY NOTE, measured: the obvious spelling
   [let has_vsts_prefix (_name : string) : bool = false] does NOT COMPILE in
   this tree - it orphans [vsts_prefix] and the library's flags make warning
   32 (unused-value-declaration) an error (lib/assurance/dune:6,
   [-w +a-4-9-40-41-42-44-45-70]). The
   short-circuit spelling above keeps the binding live and is otherwise the
   same constant.

   SPEC PREDICTION (section 7 ML2): "confirm every leg reddens - a liveness
   check on the classifier itself".

   MECHANISM, worked out BEFORE running and contradicting that prediction:
   every use of [has_vsts_prefix] sits under a NEGATION (R1's conjunct (a) is
   [not (name_or_generate_has_vsts_prefix md)], R2's is
   [not (has_vsts_prefix r.name)]), so forcing it to [false] makes those
   conjuncts constantly SATISFIED. The family becomes strictly MORE
   permissive, which cannot redden any leg. And it cannot GREEN the headline
   either, because Lm's red is produced by a monkey re-sending a STORED vsts
   pod, on which R1's conjunct (b) and R2's conjuncts (b)/(c) - all three
   owner-ref tests - fail independently.

   MEASURED (the section-7 ML2 prediction REFUTED; the mechanism CONFIRMED):
   NOT ONE LEG MOVED. The Lm anchor passed IN FULL - [violated] still names
   R1, still REFUTED, gate still 832, R1 red still 208, R2 red still 208, R3
   red still 416, H1 red still 0, H1 interesting still 1624, graph still
   1976. [t_p20_rely] ran FULLY GREEN, all 14 cases. A FORCED full-battery
   sweep ([dune build @runtest --force], all 69 exes re-run, exit 1) found
   EXACTLY ONE failing exe in the tree: this one, at four cases - F-R1a,
   F-R1b, F-R2a and the F-R3 update differential, the four rows whose red
   depends on the prefix conjunct ALONE. F-R1c, F-R2b, F-R2c and F-PVC stayed
   green, because their payloads fail an owner-ref conjunct too.

   TWO CONSEQUENCES, both worth more than the row's cost:
   - the prefix conjunct is NOT independently load-bearing for the headline.
     Section 1's premise-refutation survives its complete removal; the
     owner-ref conjunct carries Lm on its own. The [.mli]'s claim that BOTH
     conjuncts fail on a stored vsts pod is true, but neither is NECESSARY.
   - [t_p20_rely]'s "behavioural prefix pin" (t_p20_rely.ml:499-505, "a
     monkey create of a RECONCILER-MINTED vsts pod reddens R1") does NOT in
     fact discriminate the prefix: its payload is [rely_violating_forge]'s
     object, which carries the vsts owner ref, so the red survives the prefix
     being deleted. B5's F-R1a / F-R1b / F-R2a rows are, by the forced sweep
     above, the ONLY prefix-conjunct witnesses in the tree.

   ==== ML1 (MANUAL, v_stateful_set_reconciler.ml:191; NOT shipped) =========
   ==== register distinctness, one half CONFIRMED and one half REFUTED =====

   Mutant: the reconciler stops minting vsts-prefixed pod names -
   [pod_name parent ord = "vstatefulset-" ^ pod_name_without_vsts_prefix
   parent ord] becomes ["zzz-p20-mutant-" ^ ...]. This is the MINTING site
   only; [get_ordinal] (:207) keeps its own independently hard-coded
   ["vstatefulset-" ^ parent ^ "-"] literal (B2 MEASURED-CORRECTION 5: the
   two literals are separate copies).

   SPEC PREDICTION (section 7 ML1): "predict R1/R2 go GREEN on Lm while H1's
   premise starves - the register-distinctness measurement".

   MECHANISM, worked out BEFORE running: [get_ordinal] both prefix-checks AND
   round-trips through the mutated [pod_name], so it returns [None] on every
   name, and H1's [pod_premise] (helper_invariants.ml:58-62) is keyed on it -
   H1's premise must starve. But [make_pod] still installs the vsts
   CONTROLLER owner ref ([make_owner_references], :218-219, untouched), so
   R1's conjunct (b) and R2's conjuncts (b)/(c) still fail on every stored
   vsts-owned pod the monkey re-sends. R1/R2 cannot go green.

   MEASURED (the H1 half CONFIRMED, the R1/R2 half REFUTED):
   - H1'S PREMISE STARVED, exactly as predicted: the anchor's non-vacuity
     guard "H1's premise FIRES on Lm" went RED, i.e. the premise fires at 0
     of the graph's states, down from the committed 1624.
   - R1/R2 DID NOT GO GREEN. The anchor's four semantic verdicts all still
     PASSED under the mutant: Lm [violated] still names R1, Lm still REFUTED,
     the monkey edge still taken, the gate still > 0, and R1, R2 and R3 are
     each still RED somewhere. Section 7's ML1 prediction is REFUTED on its
     R1/R2 half, and the reason is the same one ML2 measured from the other
     side: the owner-ref conjunct carries the headline by itself.
   - AN UNPREDICTED SECOND-ORDER EFFECT (the P19 ML3 precedent): the mutant
     also MOVES THE GRAPH. Lm went 1976 -> 1928 states, because the
     reconciler classifies the pods it lists through [get_ordinal] and now
     recognises none of its own. No graph identity is claimed under a mutant;
     1928 is the MUTANT's count and is recorded only as evidence that the
     effect is not confined to the family.
   - AND THE LEG-B WITNESS EVAPORATES: the C1 leg-level row's first semantic
     assertion flipped - the rely-VIOLATING forge leg went REFUTED -> CLEAN.
     [rely_violating_forge] builds its pod through the same [make_pod], so
     under ML1 its name is no longer vsts-prefixed, H1's premise never fires
     on it, and the assumption-necessity witness of section 4.3 disappears.
     That is the register-distinctness datum stated positively: H1 and Leg B
     depend on the MINTING literal; the rely family's headline does not.
   - BLAST RADIUS, measured: 8 of this exe's 12 cases and 7 of
     [t_p20_rely]'s 14 went red (a forced full-battery sweep was not run for
     this row).

   ==== ML2' (MANUAL, rely_conditions.ml:53 + :70; NOT shipped) =============
   ==== the reachable variant - the row that DOES flip the headline ========

   ML2 showed one token is not enough, so the row was re-run at the pair of
   sites that together neuter the family on its Pod arm (B4 measured this
   pair first; it is re-measured here independently rather than inherited):
   [vsts_prefix] ["vstatefulset-"] -> ["zzz-p20-mutant-"] AND the collapse
   test's [Common.equal_kind r.kind V_stateful_set.kind] ->
   [... Pod.kind]. Together they neuter conjunct (a) and every owner-ref
   conjunct at once.

   PREDICTION: Lm flips REFUTED -> CLEAN; the Lm GATE does NOT move (the
   premise mirrors read only [msg.src] and the message content, never the
   reddening mechanism); the Lm GRAPH PIN does NOT move (the product graph
   depends only on seed/bound/budget/depth, never on the invariant list -
   the derivation the whole witness chain rests on).

   MEASURED (all three halves CONFIRMED):
   - the anchor's FIRST assertion flipped: Lm [violated] went from
     ["vsts_rely_create_req"] to ["<none>"] and the leg is CLEAN. The
     headline verdict TRACKS THE FAMILY and is not a constant.
   - the Lm gate assertion PASSED under the mutant (still > 0), and
   - the Lm graph pin assertion PASSED under the mutant (still exactly 1976),
     as did [t_p20_rely]'s whole pin_safety case (all five committed graphs)
     and its L0 / Lc / Ld vacuity rows. Prediction 6's identity ALSO held
     under the mutant (0 disagreements), and that outcome is FORCED rather
     than informative (BUILD-SPEC-P20 REVIEW-FIX A; this line used to call it
     "two independent renderings agreeing even when both are wrong"). The
     renderings are NOT independent: R3's constrained arms call the same
     [rely_create_req] / [rely_update_req] that R1 and R2 call, so the
     identity is a theorem of the code for ANY definition of those helpers
     and cannot move under a mutant of their bodies. The pin guards R3's
     arm-DISPATCH shape only - see the header note at :30-33.
   - blast radius: 9 of this exe's 12 cases and 5 of [t_p20_rely]'s 14 went
     red. The two C1 rows stayed GREEN, because they measure H1 and not the
     rely family - the same register separation ML1 showed from the other
     direction.

   ==== NOT IN THIS EXE ====================================================

   Section 7's MN1 row (the D1 / D2 / D3 committed-test guards, each confirmed
   by mutation) belongs to [t_p20_regression], which does not exist yet: D1
   and D2 are edits to [t_p19_regression.ml] and D3 is the 12-entry
   [shipped_suites] firewall. Recorded here so the omission is deliberate and
   visible rather than silent.

   TEST-ORDERING RULE (P12 finding 1, P13-P19 precedent): semantic facts FIRST
   (family names, controls, holds / interesting / conjunction / violated), the
   brittle exact counts LAST, so under a manual row the semantic verdicts print
   before a moved pin aborts the case.

   Every pinned number comes from {!P20_witness}; none is re-typed here.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum (both [Mc.outcome] arms), and an
   exhaustive ENUMERATION - not a match - of [Common.kind] at the F-PVC site
   (its two constrained constructors as forges, the other NINE as accepted
   controls, eleven in all, common.mli:35-46), no two-arm match on
   [option]/[result] (stdlib [Option.fold] - its [~none] is EAGER, so no
   expensive arm is ever placed there), no wildcard arm, Alcotest as the
   sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Rc = Anvil_assurance.Rely_conditions
module Hi = Anvil_assurance.Helper_invariants
module Vsr = V_stateful_set_reconciler

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P20_witness.witness_desired
let depth : int = P20_witness.witness_depth
let bound : Bound.t = P20_witness.p20_bound ~desireds:[ desired ]
let cr : V_stateful_set.t = Scenario.vsts ~desired ()
let family : Invariants.invariant list = Rc.rely_family

(* P18's family, needed by row C1: Leg B checks H1/H2, not R1-R3. *)
let helper_family : Invariants.invariant list =
  Hi.helper_family ~cr ~controller_id

(* The three upstream member names, used as ADDRESSES into the family (not as
   pinned measurements - [t_p20_rely] pins the family shape). A missing name
   makes both projections below constantly [false], which {!test_seed_shape}'s
   name pin catches LOUDLY before any row could quietly pass. *)
let r1_name : string = "vsts_rely_create_req"
let r2_name : string = "vsts_rely_update_req"
let r3_name : string = "vsts_rely_conditions_pod_monkey"

let h1_name : string =
  "all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref"

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) --------
   [report_decisive] is a PHANTOM in this tree (BUILD-SPEC-P20 section 5 asked
   B1 to confirm; it did). These are the local projections of
   t_p17_store.ml:71-79, the shipped P17-P20 convention. *)

let refuted (o : Fc.faulted Mc.outcome) : bool =
  match o with Mc.Refuted _ -> true | Mc.No_counterexample _ -> false

let report_clean (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

let report_decisive_local (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

(* [Mc.Refuted] carries [{lasso; steps}] and NO [states] field
   (model_check.mli:39, B4 MEASURED-CORRECTION 1), so a refuted leg cannot
   report its graph size; [-1] is the shipped sentinel. *)
let report_states (r : Fc.fault_report) : int =
  match r.outcome with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let gate_of (r : Fc.fault_report) : int = Option.value r.gate_states ~default:(-1)

let violated_name (r : Fc.fault_report) : string =
  Option.fold r.violated ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ---- per-state family projections ---------------------------------------- *)

let violated_of (fam : Invariants.invariant list) (s : Cluster.cluster_state) :
    string list =
  List.filter_map
    (fun (i : Invariants.invariant) ->
      if i.Invariants.holds s then None else Some i.Invariants.name)
    fam

let violated_names (s : Cluster.cluster_state) : string list =
  violated_of family s

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

let holds (name : string) (s : Cluster.cluster_state) : bool =
  member_holds family name s

let fires (name : string) (s : Cluster.cluster_state) : bool =
  member_interesting family name s

let first_violated_name (s : Cluster.cluster_state) : string =
  Option.fold
    (Invariants.first_violated family s)
    ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ---- the exact-leg-check harness (the t_p14..t_p19 singleton form) --------
   Every forged state is run through the SAME [Fc.faulted] wrapper and the
   SAME [Mc.check_safety] the legs use, so a row cannot be green in the
   family and invisible to the leg. *)

let singleton_reach (f : Fc.faulted) : Fc.faulted Mc.reachable =
  Mc.explore ~depth:1
    ~successors:(fun (_ : Fc.faulted) -> [])
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash ~init:[ f ]

let safety_of (fam : Invariants.invariant list) (f : Fc.faulted) :
    Fc.faulted Mc.outcome =
  let conj = Invariants.conjunction fam in
  Mc.check_safety (singleton_reach f)
    ~inv:(fun (x : Fc.faulted) -> conj x.cs)
    ~equal:Fc.faulted_equal

(* A POST-MONKEY product state: the three counters are inert to every [holds],
   the point being that the forges run through the leg's own wrapper. *)
let product (cs : Cluster.cluster_state) : Fc.faulted =
  { Fc.cs; crashes = 0; drops = 0; monkeys = 1 }

(* ==== the forge base: the legs' own seed, in-flight pool EMPTY ============= *)

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ()

(* The seed with ONLY the network replaced (the t_p14 [forged_state] shape). *)
let forged (msgs : Message.t list) : Cluster.cluster_state =
  { seed with Cluster.network = { Network.in_flight = Message.Pool.of_list msgs } }

let add_etcd (s : Cluster.cluster_state) (key : Common.object_ref)
    (obj : Dynamic_object.t) : Cluster.cluster_state =
  {
    s with
    Cluster.api_server =
      {
        s.Cluster.api_server with
        Api_server.resources =
          Object_ref_map.add key obj s.Cluster.api_server.Api_server.resources;
      };
  }

let monkey ~(rpc : int) (content : Message.message_content) : Message.t =
  Message.pod_monkey_req_msg (Message.Rpc_id.of_int rpc) content

(* ---- the CR's own coordinates, READ off the CR, never typed -------------- *)

let cr_md : Object_meta.t = V_stateful_set.metadata cr
let ns : string = Option.value ~default:"" (Object_meta.namespace cr_md)
let parent : string = Option.value ~default:"" (Object_meta.name cr_md)

(* The vsts CONTROLLER owner ref the collapse of section 2.1 renders. Its
   presence is PINNED in {!test_seed_shape}: an absent ref would silently
   degrade every F-R1c row to the all-empty placeholder. *)
let vsts_owner : Owner_reference.t =
  Option.value
    (V_stateful_set.controller_owner_ref cr)
    ~default:(Owner_reference.default ())

(* The forged ordinal is Leg B's own (fault_check.ml:906, [desired + 1]) - one
   clear of the largest ordinal the reconciler mints, so the names below are
   the names a real forge would carry. *)
let forge_ord : int = Fc.forge_ordinal ~desired

(* A REAL reconciler-minted vsts pod name (v_stateful_set_reconciler.ml:191) -
   not a test-local string that merely LOOKS vsts-prefixed. That is what makes
   every red below a statement about the names the port actually mints. *)
let vsts_name : string = Vsr.pod_name parent forge_ord
let vsts_generate_name : string = Vsr.pod_name parent forge_ord ^ "-"

(* The rely-RESPECTING name shape, the same literal [rely_respecting_forge]
   uses (fault_check.ml:965). *)
let outsider_name : string = "p20-outsider-" ^ string_of_int forge_ord

(* ---- payload construction ------------------------------------------------
   Every payload is the reconciler's REAL [make_pod] object with its METADATA
   replaced, so the spec/status reads are not test-local fictions and the only
   thing that varies between a forge and its control is the metadata field the
   row is about. *)

let base_pod : Pod.t = Vsr.make_pod cr 0

let pod_obj ~(name : string option) ~(generate_name : string option)
    ~(owners : Owner_reference.t list option) : Dynamic_object.t =
  let md : Object_meta.t = Pod.metadata base_pod in
  Pod.marshal
    (Pod.with_metadata
       {
         md with
         Object_meta.name;
         generate_name;
         namespace = Some ns;
         owner_references = owners;
       }
       base_pod)

(* A KIND-RETAG of an otherwise byte-identical object: metadata, spec and
   status are carried across untouched, so an F-PVC red (and every
   other-kind accept) is attributable to [Dynamic_object.kind] ALONE.
   [Persistent_volume_claim] has no view module in this tree - only
   [Pod] / [Config_map] / [Stateful_set] do - so the retag is how a PVC-kinded
   object is built at all. *)
let retag (k : Common.kind) (o : Dynamic_object.t) : Dynamic_object.t =
  Dynamic_object.make ~kind:k
    ~metadata:(Dynamic_object.metadata o)
    ~spec:(Dynamic_object.spec o)
    ~status:(Dynamic_object.status o)

(* The MAXIMALLY rely-violating pod: both of R1's conjuncts fail on it and
   both of R2's object-side conjuncts do. Every "accepted" control below is
   this object with exactly one field weakened. *)
let maximal_obj : Dynamic_object.t =
  pod_obj ~name:(Some vsts_name) ~generate_name:(Some vsts_generate_name)
    ~owners:(Some [ vsts_owner ])

(* The rely-RESPECTING pod: non-vsts name, no owner refs. *)
let innocuous_obj : Dynamic_object.t =
  pod_obj ~name:(Some outsider_name) ~generate_name:None ~owners:None

let create (obj : Dynamic_object.t) : Message.message_content =
  Message.create_req_msg_content ns obj

let update (name : string) (obj : Dynamic_object.t) : Message.message_content =
  Message.update_req_msg_content ns name obj

let update_key (name : string) (obj : Dynamic_object.t) : Common.object_ref =
  Api_method.update_request_key { Api_method.namespace = ns; name; obj }

let update_status (name : string) (obj : Dynamic_object.t) :
    Message.message_content =
  Message.update_status_req_msg_content ns name obj

(* ---- the assertion bundles ------------------------------------------------
   The 4-check parity of BUILD-SPEC-P19 section 7's D1 discipline, with P20's
   disclosed isolation form. *)

let check_arm_forge ~(label : string) ~(name : string)
    (s : Cluster.cluster_state) : unit =
  (* (1) the member REJECTS. *)
  Alcotest.(check bool) (label ^ ": holds = false (the member REJECTS)") false
    (holds name s);
  (* (2) premise-FIRED, never vacuous. *)
  Alcotest.(check bool)
    (label ^ ": the member's own interesting FIRES (not a vacuous red)") true
    (fires name s);
  (* (3) the family conjunction the leg asserts is false. *)
  Alcotest.(check bool) (label ^ ": the family conjunction is FALSE") false
    (Invariants.conjunction family s);
  (* (4) the red is ATTRIBUTED by name. *)
  Alcotest.(check string) (label ^ ": violated NAMES the member") name
    (first_violated_name s);
  (* ISOLATION, P20 form: the target arm and R3 and NOTHING ELSE. R3 is red
     BY CONSTRUCTION ([rely_conditions.mli]'s disclosed R3 <=> R1 && R2), so
     this assertion is the P19 isolation PLUS an on-the-spot re-measurement of
     prediction 6's identity - the other arm is asserted to still hold. *)
  Alcotest.(check (list string))
    (label
   ^ ": ISOLATION - exactly this arm and R3 (the disclosed redundancy), the \
      other arm still holds")
    [ name; r3_name ] (violated_names s);
  (* The leg's own check, over the leg's own product wrapper. *)
  Alcotest.(check bool)
    (label ^ ": the leg's own check_safety REFUTES the product state") true
    (refuted (safety_of family (product s)))

let check_accept ~(label : string) ~(name : string) (s : Cluster.cluster_state)
    : unit =
  Alcotest.(check (list string))
    (label ^ ": ACCEPTED - violates no member")
    [] (violated_names s);
  Alcotest.(check bool)
    (label ^ ": the accept is NOT vacuous - the member's interesting fires")
    true (fires name s);
  Alcotest.(check bool) (label ^ ": the leg harness stays clean") false
    (refuted (safety_of family (product s)))

(* ==== the fail-loud base every row rests on ================================ *)

let test_seed_shape () =
  Alcotest.(check (list string))
    "family = the three upstream names, in member order R1, R2, R3"
    [ r1_name; r2_name; r3_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family);
  Alcotest.(check int) "seed: in-flight pool is EMPTY" 0
    (Message.Pool.cardinal (Cluster.in_flight seed));
  Alcotest.(check (list string)) "seed violates NOTHING" [] (violated_names seed);
  Alcotest.(check bool) "seed: NO member's interesting fires (all vacuous)"
    false
    (List.exists
       (fun (i : Invariants.invariant) -> i.Invariants.interesting seed)
       family);
  (* The vsts controller owner ref really EXISTS - otherwise every F-R1c row
     would silently be built on [Owner_reference.default ()]. *)
  Alcotest.(check bool)
    "the CR really has a controller owner ref (not the empty placeholder)" true
    (Option.is_some (V_stateful_set.controller_owner_ref cr));
  (* The payload really is a pod, and the two names really are the two shapes
     the rows claim (the minting site, v_stateful_set_reconciler.ml:191). *)
  Alcotest.(check bool) "payload: make_pod's object really is pod-kinded" true
    (Common.equal_kind (Dynamic_object.kind maximal_obj) Pod.kind);
  Alcotest.(check bool)
    "the violating name is MINTED by the reconciler and parses back (:191/:207)"
    true
    (String.starts_with ~prefix:"vstatefulset-" vsts_name
    && Option.is_some (Vsr.get_ordinal parent vsts_name));
  Alcotest.(check bool)
    "the control name is NOT vsts-prefixed and does NOT parse as an ordinal"
    true
    ((not (String.starts_with ~prefix:"vstatefulset-" outsider_name))
    && Option.is_none (Vsr.get_ordinal parent outsider_name));
  (* The forged ordinal is outside the reconciler's live range - the
     vacuous-green trap of spec section 4.3, re-pinned here because every
     payload name below carries it. *)
  Alcotest.(check bool)
    "the forged ordinal lies OUTSIDE the live range 0..desired-1" true
    (forge_ord > desired - 1)

(* ==== F-R1a: conjunct (a) through [metadata.name] (:61-66 then-branch) ==== *)

(* WHAT COULD MAKE THIS FAIL: [vsts_prefix] drifting off the reconciler's
   literal, the [Option.fold] on [md.name] losing its [~some] arm, or the
   [Pod] arm of R1's kind dispatch being widened. *)
let test_f_r1a () =
  (* CONTROL FIRST, so the discriminating direction is SEEN: the identical
     create with a NON-vsts name and no owner ref is accepted. *)
  check_accept ~label:"F-R1a control (non-vsts name, no owner ref)"
    ~name:r1_name
    (forged [ monkey ~rpc:0 (create innocuous_obj) ]);
  (* FORGE: only the NAME moves. *)
  let bad =
    pod_obj ~name:(Some vsts_name) ~generate_name:None ~owners:None
  in
  check_arm_forge ~label:"F-R1a (vsts-prefixed metadata.name)" ~name:r1_name
    (forged [ monkey ~rpc:0 (create bad) ])

(* ==== F-R1b: conjunct (a) through [generate_name] (:63-66 ELSE-branch) ====
   The ONLY witness anywhere in this tree for upstream's else-branch: nothing
   the port itself emits ever leaves [metadata.name] absent. *)
let test_f_r1b () =
  (* CONTROL 1 - the ELSE-OF-ELSE: name absent AND generate_name absent. The
     port folds [~none:false] there, so the "no name conflict" conjunct
     PASSES, which is upstream's ":63-66 with a missing generate_name makes
     the inner conjunction false". *)
  check_accept ~label:"F-R1b control 1 (name None, generate_name None)"
    ~name:r1_name
    (forged
       [
         monkey ~rpc:0
           (create (pod_obj ~name:None ~generate_name:None ~owners:None));
       ]);
  (* CONTROL 2 - the SHADOWING control: a present, INNOCUOUS name beside a
     vsts-prefixed generate_name is ACCEPTED. This is what proves the
     else-branch is really an ELSE and not a second disjunct. *)
  check_accept
    ~label:"F-R1b control 2 (innocuous name SHADOWS a vsts generate_name)"
    ~name:r1_name
    (forged
       [
         monkey ~rpc:0
           (create
              (pod_obj ~name:(Some outsider_name)
                 ~generate_name:(Some vsts_generate_name) ~owners:None));
       ]);
  (* FORGE: name absent, generate_name vsts-prefixed. *)
  check_arm_forge
    ~label:"F-R1b (name None, vsts-prefixed generate_name - the :63-66 ELSE)"
    ~name:r1_name
    (forged
       [
         monkey ~rpc:0
           (create
              (pod_obj ~name:None ~generate_name:(Some vsts_generate_name)
                 ~owners:None));
       ])

(* ==== F-R1c: conjunct (b), the section-2.1 owner-ref collapse (:68-69) ====
   The collapse FIXES three fields and leaves two free. Both halves are
   measured: one control per PINNED field (each differing from the vsts
   controller ref in exactly that field, each ACCEPTED) and one forge per FREE
   field (name / uid moved arbitrarily, still RED). *)
let test_f_r1c () =
  let with_owner (r : Owner_reference.t) : Cluster.cluster_state =
    forged
      [
        monkey ~rpc:0
          (create
             (pod_obj ~name:(Some outsider_name) ~generate_name:None
                ~owners:(Some [ r ])));
      ]
  in
  (* CONTROL 0: no owner_references AT ALL. [Object_meta.owner_references] is
     an OPTION (object_meta.mli:16), folded [~none:false] - B2
     MEASURED-CORRECTION 3. *)
  check_accept ~label:"F-R1c control 0 (owner_references = None)" ~name:r1_name
    (forged
       [
         monkey ~rpc:0
           (create
              (pod_obj ~name:(Some outsider_name) ~generate_name:None
                 ~owners:None));
       ]);
  (* CONTROL 0': an EMPTY owner-reference list - a different [option] arm from
     control 0, and the [List.exists] base case. *)
  check_accept ~label:"F-R1c control 0' (owner_references = Some [])"
    ~name:r1_name
    (forged
       [
         monkey ~rpc:0
           (create
              (pod_obj ~name:(Some outsider_name) ~generate_name:None
                 ~owners:(Some [])));
       ]);
  (* CONTROLS 1-3: one per PINNED field of the collapse. Each ref differs from
     the vsts controller ref in EXACTLY one field, and each is ACCEPTED - so
     all three fields are load-bearing, measured rather than argued. *)
  check_accept ~label:"F-R1c control 1 (block_owner_deletion = Some false)"
    ~name:r1_name
    (with_owner
       { vsts_owner with Owner_reference.block_owner_deletion = Some false });
  check_accept ~label:"F-R1c control 2 (controller = Some false)" ~name:r1_name
    (with_owner { vsts_owner with Owner_reference.controller = Some false });
  check_accept ~label:"F-R1c control 3 (kind = Pod, not VStatefulSet)"
    ~name:r1_name
    (with_owner { vsts_owner with Owner_reference.kind = Pod.kind });
  (* THE FORGE: the vsts controller owner ref itself, on a NON-vsts name, so
     the red is conjunct (b)'s and nothing else. *)
  check_arm_forge ~label:"F-R1c (the vsts CONTROLLER owner ref, :68-69)"
    ~name:r1_name (with_owner vsts_owner);
  (* THE FREE HALF of the collapse: moving [name] and [uid] arbitrarily must
     NOT rescue the object - that is precisely what makes the port's
     three-field test EQUIVALENT to upstream's existential over all vsts
     views, rather than a narrowing to the scenario CR. *)
  check_arm_forge
    ~label:"F-R1c free-field forge (owner ref name/uid moved arbitrarily)"
    ~name:r1_name
    (with_owner
       {
         vsts_owner with
         Owner_reference.name = "p20-some-other-vsts";
         uid = Common.Uid.of_int 4242;
       })

(* ==== F-R2a: conjunct (a) on the REQUEST's name (:80) =====================
   R2 reads [req.name], NOT the object's [metadata.name], so the row moves the
   request field alone and leaves the payload innocuous. *)
let test_f_r2a () =
  check_accept ~label:"F-R2a control (non-vsts REQUEST name)" ~name:r2_name
    (forged [ monkey ~rpc:0 (update outsider_name innocuous_obj) ]);
  check_arm_forge ~label:"F-R2a (vsts-prefixed REQUEST name, :80)"
    ~name:r2_name
    (forged [ monkey ~rpc:0 (update vsts_name innocuous_obj) ])

(* ==== F-R2b: conjunct (b), the STORED object (:82-83) =====================
   The ONLY red witness for this conjunct anywhere: a state where etcd ALREADY
   holds a vsts-owned object at the request's key. It is also the only place
   the port's disclosed missing-key rendering ([Option.fold ~none:true], spec
   section 2.3) is exercised in BOTH directions. *)
let test_f_r2b () =
  let msg = monkey ~rpc:0 (update outsider_name innocuous_obj) in
  let key = update_key outsider_name innocuous_obj in
  let base = forged [ msg ] in
  let owned_obj =
    pod_obj ~name:(Some outsider_name) ~generate_name:None
      ~owners:(Some [ vsts_owner ])
  in
  (* CONTROL 1 - the MISSING-KEY rendering, and it is a deliberate port
     choice: Verus [s.resources()[k]] on an absent key is an arbitrary total
     map value, so the conjunct is unconstrained there and the port folds
     [~none:true]. Nothing is stored at the key here. *)
  check_accept ~label:"F-R2b control 1 (key ABSENT - the ~none:true rendering)"
    ~name:r2_name base;
  (* CONTROL 2: a stored object that is NOT vsts-owned. The key is now
     PRESENT, so this separates "present" from "vsts-owned". *)
  check_accept ~label:"F-R2b control 2 (stored object present, NOT vsts-owned)"
    ~name:r2_name
    (add_etcd base key innocuous_obj);
  (* CONTROL 3: the vsts-owned object stored at a DIFFERENT key - the lookup
     is key-EXACT, not a scan. *)
  check_accept ~label:"F-R2b control 3 (vsts-owned object at ANOTHER key)"
    ~name:r2_name
    (add_etcd base
       { key with Common.name = outsider_name ^ "-elsewhere" }
       owned_obj);
  (* THE FORGE: the identical message, with a vsts-owned object stored at the
     request's own key. *)
  check_arm_forge
    ~label:"F-R2b (etcd holds a VSTS-OWNED object at the request's key, :82-83)"
    ~name:r2_name
    (add_etcd base key owned_obj)

(* ==== F-R2c: conjunct (c), the NEW object becomes vsts-owned (:85) ======== *)
let test_f_r2c () =
  let with_owner (r : Owner_reference.t) : Cluster.cluster_state =
    forged
      [
        monkey ~rpc:0
          (update outsider_name
             (pod_obj ~name:(Some outsider_name) ~generate_name:None
                ~owners:(Some [ r ])));
      ]
  in
  check_accept ~label:"F-R2c control (owner ref with controller = Some false)"
    ~name:r2_name
    (with_owner { vsts_owner with Owner_reference.controller = Some false });
  check_arm_forge
    ~label:"F-R2c (the NEW object carries the vsts controller owner ref, :85)"
    ~name:r2_name (with_owner vsts_owner)

(* ==== F-R3: the PERMITTED arms (:26) are CONTENT ==========================
   Upstream's [_ => true] at rely_guarantee.rs:26 ("Deletion/UpdateStatus
   requests are allowed") is the deliberate SHAPE of what VSTS lets its
   environment do. A green that came from a harmless payload would prove
   nothing, so both permitted messages carry the MAXIMALLY rely-violating
   object, and the same-state differential below shows the permissiveness is
   per-ARM and not per-PAYLOAD. *)
let test_f_r3 () =
  let delete_msg =
    monkey ~rpc:0
      (Message.delete_req_msg_content
         { Common.kind = Pod.kind; namespace = ns; name = vsts_name }
         None)
  in
  let status_msg = monkey ~rpc:1 (update_status vsts_name maximal_obj) in
  let permitted = forged [ delete_msg; status_msg ] in
  Alcotest.(check bool)
    "F-R3: R3's premise FIRES on the permitted arms (the injection landed)"
    true (fires r3_name permitted);
  Alcotest.(check (list string))
    "F-R3: Delete + Update_status carrying the MAXIMAL payload violate NOTHING \
     - the :26 permissiveness is CONTENT"
    [] (violated_names permitted);
  Alcotest.(check bool) "F-R3: the leg harness stays clean" false
    (refuted (safety_of family (product permitted)));
  (* THE DIFFERENTIAL: add the SAME payload on a CONSTRAINED arm to the SAME
     state. The permitted messages stay in flight and are still out of R1's
     and R2's constrained scope, so the flip is attributable to the ARM. *)
  let plus_create = forged [ delete_msg; status_msg; monkey ~rpc:2 (create maximal_obj) ] in
  Alcotest.(check string)
    "F-R3 differential: the IDENTICAL payload on the CREATE arm reddens R1 - \
     permissiveness is per-ARM, not per-PAYLOAD"
    r1_name (first_violated_name plus_create);
  Alcotest.(check (list string))
    "F-R3 differential: exactly R1 and R3 (R2's arm never fired)"
    [ r1_name; r3_name ] (violated_names plus_create);
  let plus_update =
    forged [ delete_msg; status_msg; monkey ~rpc:2 (update vsts_name innocuous_obj) ]
  in
  Alcotest.(check (list string))
    "F-R3 differential: the UPDATE arm reddens R2 in the same company"
    [ r2_name; r3_name ] (violated_names plus_update)

(* ==== F-PVC: the PersistentVolumeClaim arm, and the nine other kinds ======
   The PVC arm of R1/R2 has NO red witness on any live graph: the monkey emits
   pod-keyed requests ONLY, which is exactly what P19's M2
   [all_requests_from_pod_monkey_are_api_pod_requests] asserts and measures.
   A FORGE is its only witness anywhere, and this row is it. The nine
   remaining [Common.kind] constructors carry the identical maximal metadata
   and are ACCEPTED - upstream's [_ => true] at :71, spelled out and SEEN
   rather than trusted. *)
let other_kinds : (string * Common.kind) list =
  [
    ("Config_map", Common.Config_map);
    ("Custom_resource (the CR's own kind)", V_stateful_set.kind);
    ("Daemon_set", Common.Daemon_set);
    ("Role", Common.Role);
    ("Role_binding", Common.Role_binding);
    ("Secret", Common.Secret);
    ("Service", Common.Service);
    ("Service_account", Common.Service_account);
    ("Stateful_set", Common.Stateful_set);
  ]

let test_f_pvc () =
  (* R1's PVC arm: a create of a PVC-kinded retag of the maximal object. *)
  check_arm_forge
    ~label:"F-PVC create (PVC-kinded, forge-only witness - the monkey never \
            emits one)"
    ~name:r1_name
    (forged
       [
         monkey ~rpc:0
           (create (retag Common.Persistent_volume_claim maximal_obj));
       ]);
  (* R2's PVC arm, same shape on the update side. *)
  check_arm_forge ~label:"F-PVC update (PVC-kinded, :78 dispatch)" ~name:r2_name
    (forged
       [
         monkey ~rpc:0
           (update vsts_name (retag Common.Persistent_volume_claim maximal_obj));
       ]);
  (* THE NINE OTHER ARMS: identical metadata, kind alone moved, all ACCEPTED. *)
  List.iter
    (fun ((label, k) : string * Common.kind) ->
      check_accept
        ~label:("F-PVC control - create of a " ^ label ^ " (:71 _ => true)")
        ~name:r1_name
        (forged [ monkey ~rpc:0 (create (retag k maximal_obj)) ]);
      check_accept
        ~label:("F-PVC control - update of a " ^ label ^ " (:78 _ => true)")
        ~name:r2_name
        (forged [ monkey ~rpc:0 (update vsts_name (retag k maximal_obj)) ]))
    other_kinds

(* ==== C1, part 1: the STATE-LEVEL containment differential ================
   Cheap, graph-free, and it exhibits the MECHANISM the leg-level row can only
   report: the two shipped forge shapes differ in exactly the two
   rely-relevant fields, and H1's verdict flips between them because its
   PREMISE stops firing - not because the payload became harmless (both keep
   the finalizer). *)

let lf_forge : Pod.t = Fc.rely_violating_forge ~desired
let c1_forge : Pod.t = Fc.rely_respecting_forge ~desired

(* Rebuilt locally: [Fault_check.forge_key] is internal (B4 MEASURED-CORRECTION
   2). Same [~default:""] completions as the library's, so an ill-formed forge
   counts as absent rather than being silently dropped. *)
let forge_key (p : Pod.t) : Common.object_ref =
  let md : Object_meta.t = Pod.metadata p in
  {
    Common.kind = Pod.kind;
    namespace = Option.value ~default:"" md.namespace;
    name = Option.value ~default:"" md.name;
  }

let lf_key : Common.object_ref = forge_key lf_forge
let c1_key : Common.object_ref = forge_key c1_forge

let test_c1_state_level () =
  let lf_md : Object_meta.t = Pod.metadata lf_forge in
  let c1_md : Object_meta.t = Pod.metadata c1_forge in
  (* The two forges agree everywhere the row does NOT vary. *)
  Alcotest.(check (option string)) "C1: both forges carry the SAME namespace"
    lf_md.namespace c1_md.namespace;
  Alcotest.(check (option (list string)))
    "C1: the control KEEPS the finalizer - the green cannot be a harmless \
     payload"
    lf_md.finalizers c1_md.finalizers;
  Alcotest.(check bool) "C1: both forges carry the SAME spec and status" true
    (Value.equal
       (Dynamic_object.spec (Pod.marshal lf_forge))
       (Dynamic_object.spec (Pod.marshal c1_forge))
    && Value.equal
         (Dynamic_object.status (Pod.marshal lf_forge))
         (Dynamic_object.status (Pod.marshal c1_forge)));
  Alcotest.(check (option string))
    "C1: neither forge carries a deletion timestamp (the P18 MB3 laundering \
     result - only the finalizer survives the api server)"
    lf_md.deletion_timestamp c1_md.deletion_timestamp;
  (* ... and differ in exactly the two rely-relevant fields. *)
  Alcotest.(check bool) "C1: only the violating forge is vsts-prefixed" true
    (String.starts_with ~prefix:"vstatefulset-" lf_key.Common.name
    && not (String.starts_with ~prefix:"vstatefulset-" c1_key.Common.name));
  Alcotest.(check bool) "C1: only the violating forge carries owner refs" true
    (Option.is_some lf_md.owner_references
    && Option.is_none c1_md.owner_references);
  (* THE MECHANISM: H1's premise is keyed on [get_ordinal], so it fires on the
     violating key and STARVES on the respecting one. That is why C1's leg
     gate is STRUCTURALLY 0 (B3 MEASURED-CORRECTION 2) rather than a failed
     experiment. *)
  Alcotest.(check bool)
    "C1: H1's premise PARSES the violating name and NOT the respecting one \
     (this is why C1's leg gate is structurally 0)"
    true
    (Option.is_some (Vsr.get_ordinal parent lf_key.Common.name)
    && Option.is_none (Vsr.get_ordinal parent c1_key.Common.name));
  (* THE FLIP, on hand-built states: the same store, the same finalizer, only
     the two rely-relevant fields moved. *)
  Alcotest.(check bool) "C1: H1's premise is SILENT at the bare seed" false
    (member_interesting helper_family h1_name seed);
  let with_lf = add_etcd seed lf_key (Pod.marshal lf_forge) in
  let with_c1 = add_etcd seed c1_key (Pod.marshal c1_forge) in
  Alcotest.(check bool) "C1: both forged objects really ARE in etcd" true
    (Option.is_some (Cluster.lookup_resource with_lf lf_key)
    && Option.is_some (Cluster.lookup_resource with_c1 c1_key));
  Alcotest.(check bool)
    "C1: the VIOLATING forge fires H1's premise and reddens H1" true
    (member_interesting helper_family h1_name with_lf
    && not (member_holds helper_family h1_name with_lf));
  Alcotest.(check bool)
    "C1: the RESPECTING forge leaves H1 GREEN with its premise never firing - \
     CONTAINMENT, not a harmless payload"
    true
    ((not (member_interesting helper_family h1_name with_c1))
    && member_holds helper_family h1_name with_c1)

(* ==== C1, part 2: the LEG-LEVEL verdict flip =============================
   The expensive half, and the one the spec's row C1 actually asks for: the
   SAME leg function, the SAME bound modulo [Bound.monkey_forge], the SAME
   budget / depth / seed. The only input that moves is the two rely-relevant
   fields of one forged pod, and H1's leg verdict flips REFUTED -> CLEAN.
   That is what attributes Leg B's red to RELY-VIOLATION rather than to
   forging as such.

   [t_p20_rely] asserts these two legs SEPARATELY; this row asserts them as a
   DIFFERENTIAL, which is the confirm-by-mutation form and is why it is here
   and not there (the P19 precedent: t_p19_mutation re-runs the P19 legs as
   its own anchor). *)

let lf_bound : Bound.t = { bound with Bound.monkey_forge = [ lf_forge ] }
let c1_bound : Bound.t = { bound with Bound.monkey_forge = [ c1_forge ] }

let leg_b (bnd : Bound.t) : Fc.fault_report =
  Fc.check_rely_forge_under_faults ~depth ~req_drop:false ~pod_monkey:true bnd
    P20_witness.lm_budget ~desired

let lf_report : Fc.fault_report Lazy.t = lazy (leg_b lf_bound)
let c1_report : Fc.fault_report Lazy.t = lazy (leg_b c1_bound)

(* C1's own non-vacuity is NOT its gate: the replica counts states where the
   RESPECTING forge's key really reached etcd, which is what proves the
   control landed rather than being rejected at admission. *)
let c1_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (Mc.explore ~depth
       ~successors:(Fc.faulted_successors c1_bound P20_witness.lm_budget cluster)
       ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
       ~init:
         [
           Fc.faulted_of_seed
             (Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
                ~pod_monkey:true ());
         ])

let test_c1_leg_level () =
  let lf = Lazy.force lf_report in
  let c1 = Lazy.force c1_report in
  let reach = Lazy.force c1_reach in
  (* The two bounds differ in the forge ALONE. *)
  Alcotest.(check bool)
    "C1: the two bounds differ in monkey_forge ALONE (one pod each)" true
    (List.length lf_bound.Bound.monkey_forge = 1
    && List.length c1_bound.Bound.monkey_forge = 1);
  (* SEMANTIC facts first - the flip itself. *)
  Alcotest.(check bool)
    "C1: the rely-VIOLATING forge REFUTES H1 (assumption-necessity)" false
    (report_clean lf);
  Alcotest.(check string) "C1: the violating leg names H1" h1_name
    (violated_name lf);
  Alcotest.(check bool) "C1: the violating leg's gate > 0 (the forge landed)"
    true
    (gate_of lf > 0);
  Alcotest.(check bool)
    "C1: the rely-RESPECTING forge leaves the SAME leg CLEAN - THE FLIP. Leg \
     B's red is attributable to RELY-VIOLATION, not to forging as such"
    true (report_clean c1);
  Alcotest.(check string) "C1: the respecting leg names nobody" "<none>"
    (violated_name c1);
  Alcotest.(check bool) "C1: the respecting leg is DECISIVE" true
    (report_decisive_local c1);
  (* C1's non-vacuity, and it is NOT the gate (B3 MEASURED-CORRECTION 2): the
     respecting forge's key never satisfies [pod_premise], so its gate is
     STRUCTURALLY 0 no matter how well the run went. Reading that zero as a
     failed experiment inverts the row's meaning. *)
  Alcotest.(check int)
    "C1: the respecting leg's gate is STRUCTURALLY 0 (pod_premise cannot fire \
     on a non-vsts name) - NOT a failed experiment"
    0 (gate_of c1);
  Alcotest.(check bool)
    "C1: the respecting forge really REACHED ETCD on the live graph - THIS, \
     not the gate, is the row's non-vacuity"
    true
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         Option.is_some (Cluster.lookup_resource f.cs c1_key))
    > 0);
  Alcotest.(check int) "C1: H1 red over the respecting graph" P20_witness.h1_red_c1
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         not (member_holds helper_family h1_name f.cs)));
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "C1: the replica explored the leg's exact graph"
    (report_states c1) (Mc.states_seen reach);
  Alcotest.(check int) "C1: graph states" P20_witness.c1_states
    (report_states c1);
  Alcotest.(check int) "C1: forged key present in etcd"
    P20_witness.c1_forged_key_states
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         Option.is_some (Cluster.lookup_resource f.cs c1_key)));
  Alcotest.(check int) "C1: the violating leg's gate" P20_witness.lf_gate_states
    (gate_of lf)

(* ==== the MANUAL anchor: the live Lm leg, violated NAMED ==================
   The observation point for the ML rows above. [t_p20_rely] measures the same
   leg; this exe re-runs it so a manual mutation can be OBSERVED from inside
   the mutation exe itself (the t_p19_mutation anchor precedent), and so the
   per-conjunct rows above have a live-graph counterpart.

   Semantic verdicts FIRST, brittle pins LAST. *)

let lm_report : Fc.fault_report Lazy.t =
  lazy
    (Fc.check_rely_conditions_under_faults ~depth ~req_drop:false
       ~pod_monkey:true bound P20_witness.lm_budget ~desired ~require_fault:true)

let lm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (Mc.explore ~depth
       ~successors:(Fc.faulted_successors bound P20_witness.lm_budget cluster)
       ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
       ~init:
         [
           Fc.faulted_of_seed
             (Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
                ~pod_monkey:true ());
         ])

let reds (fam : Invariants.invariant list) (reach : Fc.faulted Mc.reachable)
    (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      not (member_holds fam name f.cs))

let test_manual_anchor () =
  let lm = Lazy.force lm_report in
  let reach = Lazy.force lm_reach in
  (* ATTRIBUTION FIRST (ML2' flips this to "<none>" and clean). *)
  Alcotest.(check string) "anchor: Lm violated" r1_name (violated_name lm);
  Alcotest.(check bool)
    "anchor: Lm REFUTED - the rely condition is violated forge-free on a \
     COMMITTED graph"
    false (report_clean lm);
  Alcotest.(check bool) "anchor: Lm monkey REALLY taken" true
    (lm.max_monkeys_seen >= 1);
  Alcotest.(check bool) "anchor: Lm gate > 0 (the non-vacuity floor)" true
    (gate_of lm > 0);
  (* SEMANTIC counterparts of the per-conjunct rows, stated as [> 0] BEFORE
     any brittle pin so a manual row's verdict prints even when it moves the
     graph. These are the quantities the ML rows are predicted to move. *)
  Alcotest.(check bool) "anchor: Lm R1 RED somewhere" true
    (reds family reach r1_name > 0);
  Alcotest.(check bool) "anchor: Lm R2 RED somewhere" true
    (reds family reach r2_name > 0);
  Alcotest.(check bool) "anchor: Lm R3 RED somewhere" true
    (reds family reach r3_name > 0);
  (* H1's premise must really FIRE on Lm, else prediction 5's green is
     vacuous - and this is EXACTLY the quantity ML1 is predicted to starve,
     since [pod_premise] is keyed on [get_ordinal] parsing a minted name. *)
  Alcotest.(check bool)
    "anchor: H1's premise FIRES on Lm (prediction 5's non-vacuity guard; ML1 \
     starves precisely this)"
    true
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         member_interesting helper_family h1_name f.cs)
    > 0);
  Alcotest.(check bool)
    "anchor: H1 GREEN on Lm while R3 is RED (emergent robustness, prediction 5)"
    true
    (reds helper_family reach h1_name = 0);
  (* The per-conjunct rows above are state-level; these are their live-graph
     counterparts, and they are what the ML rows move. *)
  Alcotest.(check int) "anchor: Lm graph states (pin safety, monkey_forge = [])"
    P20_witness.lm_states (Mc.states_seen reach);
  Alcotest.(check int) "anchor: Lm gate" P20_witness.lm_gate_states (gate_of lm);
  Alcotest.(check int) "anchor: Lm R1 red" P20_witness.r1_red_lm
    (reds family reach r1_name);
  Alcotest.(check int) "anchor: Lm R2 red" P20_witness.r2_red_lm
    (reds family reach r2_name);
  Alcotest.(check int) "anchor: Lm R3 red" P20_witness.r3_red_lm
    (reds family reach r3_name);
  (* H1's cross-read: green on Lm with its premise firing (prediction 5). ML1
     starves this premise; ML2/ML2' leave it alone. *)
  Alcotest.(check int) "anchor: Lm H1 red (P18's family, prediction 5)"
    P20_witness.h1_red_lm
    (reds helper_family reach h1_name);
  Alcotest.(check int) "anchor: Lm H1 interesting (P18's committed pin)"
    P18_witness.h1_interesting_lm
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         member_interesting helper_family h1_name f.cs))

let () =
  Alcotest.run "p20_mutation"
    [
      ( "seed_shape",
        [
          Alcotest.test_case
            "family names, EMPTY in-flight base, no premise fires at the seed"
            `Quick test_seed_shape;
        ] );
      ( "per_conjunct_forges",
        [
          Alcotest.test_case
            "F-R1a: a vsts-prefixed metadata.name (:61-66 then-branch)" `Quick
            test_f_r1a;
          Alcotest.test_case
            "F-R1b: a vsts-prefixed generate_name with name absent (the ONLY \
             witness for the :63-66 ELSE-branch, plus the shadowing control)"
            `Quick test_f_r1b;
          Alcotest.test_case
            "F-R1c: the owner-ref collapse (:68-69) - one control per PINNED \
             field, one forge per FREE field"
            `Quick test_f_r1c;
          Alcotest.test_case "F-R2a: a vsts-prefixed REQUEST name (:80)" `Quick
            test_f_r2a;
          Alcotest.test_case
            "F-R2b: etcd holds a vsts-owned object at the request's key \
             (:82-83), with the missing-key rendering as a control"
            `Quick test_f_r2b;
          Alcotest.test_case
            "F-R2c: the NEW object becomes vsts-owned (:85)" `Quick test_f_r2c;
        ] );
      ( "permissiveness_and_kinds",
        [
          Alcotest.test_case
            "F-R3: the permitted arms (:26) under a MAXIMAL payload, plus the \
             per-ARM differential"
            `Quick test_f_r3;
          Alcotest.test_case
            "F-PVC: the PVC arm's forge-only red witness, and the nine other \
             kinds accepted (:71 / :78)"
            `Quick test_f_pvc;
        ] );
      ( "containment_control",
        [
          Alcotest.test_case
            "C1 (state level): the two shipped forges differ in the two \
             rely-relevant fields and H1's verdict flips"
            `Quick test_c1_state_level;
          Alcotest.test_case
            "C1 (leg level): the SAME leg flips REFUTED -> CLEAN on the \
             rely-RESPECTING forge"
            `Quick test_c1_leg_level;
        ] );
      ( "manual_anchor",
        [
          Alcotest.test_case
            "the live Lm leg, violated NAMED (the observation point for ML1 / \
             ML2 / ML2')"
            `Quick test_manual_anchor;
        ] );
    ]

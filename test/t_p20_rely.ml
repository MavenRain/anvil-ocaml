(* BUILD-SPEC-P20 sections 4-5 - the RELY-condition measurement: Leg A
   ({!Anvil_checker.Fault_check.check_rely_conditions_under_faults}) over the
   four committed fault graphs, Leg B ([Lf], the rely-VIOLATING forge) and the
   C1 containment control, plus the pin-safety re-check of the [Bound.t] edit,
   the [R3 <=> R1 && R2] redundancy identity and the E1-E4 exclusion pins of
   spec section 3.

   WHAT THIS EXE ESTABLISHES.

   1. THE PORT'S FIRST ASSUMPTION REGISTER, MEASURED. Every family shipped
      before P20 asserts something upstream PROVES. R1/R2/R3 are what upstream
      ASSUMES about the environment and never discharges
      ([rely_conditions.mli]): R3 sits in the composition record's
      [environment_rely] slot. So a RED row here is an ASSUMPTION-VIOLATION
      datum - the environment left the region upstream's proof assumes - and
      is NOT a defect in Anvil, NOT a soundness finding against the port, and
      NOT a refutation of anything Anvil claims.

   2. THE HEADLINE IS A REFUTATION OF A COMMITTED READING, AND IT IS
      FORGE-FREE. P18 shipped "the port monkey is rely-UNCONSTRAINED but
      candidate-restricted, so the rely boundary has never been exercised"
      (t_p18_helper.ml:17-18). That premise is FALSE: the monkey re-sends
      STORED pods byte-identically, and every pod the reconciler mints carries
      the VSTS CONTROLLER OWNER REF ([make_owner_references],
      v_stateful_set_reconciler.ml:218-220, stamped into the pod metadata by
      [make_pod] at :379) - exactly what rely_guarantee.rs:68-69 (R1) and
      :82-83 / :85 (R2) forbid a monkey request to carry. So every monkey
      [Create_pod] / [Update_pod] on a stored vsts pod is already a
      rely-violating in-flight message. Measured here on Lm, a graph P13
      committed and five phases have re-measured - no forge involved.

      THE MECHANISM IS THE OWNER-REF CONJUNCT, NOT THE NAME PREFIX
      (BUILD-SPEC-P20 REVIEW-FIX D; this block used to credit the minted
      prefix and mention no owner ref at all). The minted name IS
      vsts-prefixed and that conjunct fails too, but the phase measured it
      NON-load-bearing from both sides: section 7's ML2 row (the family's
      [has_vsts_prefix] forced constant-false - not one leg moved and this exe
      stayed fully green) and its ML1 row (the reconciler's minted prefix
      mutated - R1/R2 stayed RED while H1's premise starved). Both are in
      t_p20_mutation.ml and tabulated at BUILD-SPEC-P20 section 5.4, whose
      section 1 forbids attributing the premise-refutation to an unmeasured
      ground.

   3. THE CORRECTED READING OF P18'S OWN HEADLINE, MEASURED DIRECTLY. P18's H1
      is GREEN on Lm while R3 is RED there. P18's "Lm CLEAN" is therefore an
      EMERGENT-ROBUSTNESS result, not a rely-consistency one: H1 held even
      though the assumption its upstream proof rests on
      (helper_invariants.rs:82) is false on that graph. This exe runs P18's H1
      on the same graph rather than inferring it from P18's committed numbers.

   4. NECESSITY, AND ITS CONTROL. [Lf] reddens H1 with a rely-violating forge
      at a gate that counts states where the forged pod ACTUALLY reached etcd
      and H1's premise fired on it; the C1 row runs the byte-identical
      rely-RESPECTING forge (same finalizer, only the two rely-relevant fields
      changed) and measures H1 GREEN with the forged key really in etcd. The
      control is what attributes Lf's red to RELY-VIOLATION rather than to
      forging as such.

   5. PIN SAFETY IS RE-CHECKED, NOT ASSUMED. [Bound.t] gained a field this
      phase. The argument that [state_equal]/[state_hash]/[faulted_equal]/
      [faulted_hash] never read a [Bound.t] is in [bound.mli]; the spec
      required it MEASURED, so all five committed graph pins (76 / 464 / 744 /
      1976 / 116) are re-asserted here with the field present and defaulted.

   HONEST VACUITY (P14 N5). L0, Lc and Ld enable no monkey step, so no
   monkey-sourced message can exist and all three members' premises are
   structurally 0 there. Those rows are reported as a MODELLING FACT, never
   as a pass: nothing about the rely condition was exercised on them.

   TEST-ORDERING RULE (P12 finding 1, P13-P19 precedent): every test asserts
   the SEMANTIC facts FIRST - outcome, [violated], decisive, floors strictly
   positive, replica faithfulness - and only THEN the brittle exact counts.

   Every pinned number comes from {!P20_witness} (single source of truth);
   none is re-typed here. Graph-identity constants are read from the witness
   chain (P20 <- P19 <- P18 <- P17/P16 <- P15/P13), never re-typed.

   [report_decisive] DOES NOT EXIST in this tree (BUILD-SPEC-P20 section 5
   flagged it as a possible phantom; B1 confirmed it still is). Every leg is
   reported through the LOCAL decisive projection below - the two-arm
   exhaustive [Mc.outcome] match of t_p17_store.ml:71-79.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum (both [Mc.outcome] arms), no two-arm
   match on [option]/[result] (stdlib [Option.fold]/[Option.bind]), Alcotest
   as the sanctioned failure primitive. *)

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

(* P18's family, run here so predictions 5 and 7 are MEASURED on P20's graphs
   rather than inferred from P18's committed pins. *)
let helper_family : Invariants.invariant list =
  Hi.helper_family ~cr ~controller_id

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) -------
   THE LOCAL DECISIVE PROJECTION (t_p17_store.ml:71-79). [report_decisive] is
   a phantom in this tree; this is the shipped stand-in every P17-P19 exe
   already uses. *)

let decisive (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let is_clean (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

(* [Mc.Refuted] carries [{lasso; steps}] and NO [states] field (model_check.mli:39),
   so a refuted leg cannot report its graph size. The [-1] sentinel is the
   P17/P19 shipped convention; on the two REFUTED legs (Lm, Lf) the graph pin is
   read off the local replica instead, and those tests say so. *)
let states_of (r : Fc.fault_report) : int =
  match r.outcome with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let gate_of (r : Fc.fault_report) : int =
  Option.value r.gate_states ~default:(-1)

let violated_name (r : Fc.fault_report) : string =
  Option.fold r.violated ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ==== the three members, addressed BY NAME off the family ==================
   A missing name makes [member_interesting] constantly [false] and
   [member_holds] constantly [false], which the family-shape test below (and
   every holds-everywhere check) reddens LOUDLY before any count could quietly
   go 0. *)

let r1_name : string = "vsts_rely_create_req"
let r2_name : string = "vsts_rely_update_req"
let r3_name : string = "vsts_rely_conditions_pod_monkey"

let h1_name : string =
  "all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref"

let member_interesting (fam : Invariants.invariant list) (name : string)
    (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.interesting s)
    fam

let member_holds (fam : Invariants.invariant list) (name : string)
    (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.holds s)
    fam

(* ==== the forge shapes and the two forge bounds ============================
   The ONLY input that separates Lf / C1 from Lm is [Bound.monkey_forge]
   (spec section 4.2: the seam is a BOUND, alongside the
   [max_objects_per_kind] cap that already governs the same candidate list -
   not a [Cluster.cluster_state] flag, which would have DOUBLED all five
   committed pins exactly as [req_drop] already does). *)

let lf_forge : Pod.t = Fc.rely_violating_forge ~desired
let c1_forge : Pod.t = Fc.rely_respecting_forge ~desired
let lf_bound : Bound.t = { bound with Bound.monkey_forge = [ lf_forge ] }
let c1_bound : Bound.t = { bound with Bound.monkey_forge = [ c1_forge ] }

(* The etcd key a forged pod lands at, rebuilt locally because
   [Fault_check.forge_key] is internal. It is the API SERVER's key, not
   [Pod.object_ref]: the monkey keys its create at
   [(Pod_monkey.pod_namespace pod, Pod_monkey.pod_name pod)]
   (pod_monkey.ml:38-43, the total completions of Anvil's [->0] unwraps) and
   the api server stores at [{kind = obj.kind; name; namespace = req.namespace}]
   (api_server.ml:285-290). The SAME [~default:""] completions are used here,
   so an ill-formed forge is counted as absent rather than silently dropped. *)
let forge_key (p : Pod.t) : Common.object_ref =
  let md : Object_meta.t = Pod.metadata p in
  {
    Common.kind = Pod.kind;
    namespace = Option.value ~default:"" md.namespace;
    name = Option.value ~default:"" md.name;
  }

let lf_key : Common.object_ref = forge_key lf_forge
let c1_key : Common.object_ref = forge_key c1_forge

(* ==== the leg runs (lazy: no test pays for an unused exploration) ========= *)

let leg_a ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget)
    ~(require_fault : bool) : Fc.fault_report =
  Fc.check_rely_conditions_under_faults ~depth ~req_drop ~pod_monkey bound
    budget ~desired ~require_fault

let l0 : Fc.fault_report Lazy.t =
  lazy
    (leg_a ~req_drop:false ~pod_monkey:false P20_witness.zero_budget
       ~require_fault:false)

let lc : Fc.fault_report Lazy.t =
  lazy
    (leg_a ~req_drop:false ~pod_monkey:false P20_witness.lc_budget
       ~require_fault:true)

let ld : Fc.fault_report Lazy.t =
  lazy
    (leg_a ~req_drop:true ~pod_monkey:false P20_witness.ld_budget
       ~require_fault:true)

let lm : Fc.fault_report Lazy.t =
  lazy
    (leg_a ~req_drop:false ~pod_monkey:true P20_witness.lm_budget
       ~require_fault:true)

(* Leg B and its control. No [~require_fault] (B3 MEASURED-CORRECTION 5: a
   forged object can only reach etcd through a [Pod_monkey_step], which
   [budget_fault_taken] already counts, so the conjunct would be a no-op). *)
let lf : Fc.fault_report Lazy.t =
  lazy
    (Fc.check_rely_forge_under_faults ~depth ~req_drop:false ~pod_monkey:true
       lf_bound P20_witness.lm_budget ~desired)

let c1 : Fc.fault_report Lazy.t =
  lazy
    (Fc.check_rely_forge_under_faults ~depth ~req_drop:false ~pod_monkey:true
       c1_bound P20_witness.lm_budget ~desired)

(* ==== LOCAL replicas of the legs' product graphs ===========================
   The per-member counts, the RED counts, the identity check and the C1
   forged-key count all need the reachable set itself, which [fault_report]
   does not carry. Same seed / bound / budget / depth through the exported
   {!Fc.faulted_successors}; every consuming test asserts [Mc.states_seen]
   against the leg's own [states] FIRST (the P13 M3/M5 precedent - a drifted
   replica would silently measure a different graph). *)

let seed_of ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool) :
    Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ~vct ()

let reach_of ~(bnd : Bound.t) ~(req_drop : bool) ~(pod_monkey : bool)
    ~(vct : bool) (budget : Fc.budget) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bnd budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed_of ~req_drop ~pod_monkey ~vct) ]

let l0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~bnd:bound ~req_drop:false ~pod_monkey:false ~vct:false
       P20_witness.zero_budget)

let lc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~bnd:bound ~req_drop:false ~pod_monkey:false ~vct:false
       P20_witness.lc_budget)

let ld_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~bnd:bound ~req_drop:true ~pod_monkey:false ~vct:false
       P20_witness.ld_budget)

let lm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~bnd:bound ~req_drop:false ~pod_monkey:true ~vct:false
       P20_witness.lm_budget)

(* The [vct:TRUE] zero-budget graph. Leg A has no [?vct] (fault_check.mli's
   PVC-arm justification), so L0v appears here ONLY as a pin-safety replica:
   it re-measures the committed 116 with [Bound.monkey_forge] present. *)
let l0v_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~bnd:bound ~req_drop:false ~pod_monkey:false ~vct:true
       P20_witness.zero_budget)

let lf_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~bnd:lf_bound ~req_drop:false ~pod_monkey:true ~vct:false
       P20_witness.lm_budget)

let c1_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~bnd:c1_bound ~req_drop:false ~pod_monkey:true ~vct:false
       P20_witness.lm_budget)

(* ---- counting projections over a replica --------------------------------- *)

let fires (fam : Invariants.invariant list) (reach : Fc.faulted Mc.reachable)
    (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      member_interesting fam name f.cs)

let reds (fam : Invariants.invariant list) (reach : Fc.faulted Mc.reachable)
    (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      not (member_holds fam name f.cs))

let key_present (key : Common.object_ref) (reach : Fc.faulted Mc.reachable) :
    int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      Option.is_some (Cluster.lookup_resource f.cs key))

(* Prediction 6: [R3 <=> R1 && R2] at EVERY reachable state. Counts the
   DISAGREEING states, so 0 is the pin and any drift names itself. *)
let identity_disagreements (reach : Fc.faulted Mc.reachable) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      not
        (Bool.equal
           (member_holds family r3_name f.cs)
           (member_holds family r1_name f.cs
           && member_holds family r2_name f.cs)))

(* ---- shared assertion bundles -------------------------------------------- *)

let check_replica_faithful (label : string) (reach : Fc.faulted Mc.reachable)
    (r : Fc.fault_report) : unit =
  Alcotest.(check int)
    (label ^ ": replica explored the leg's exact graph (states_seen)")
    (states_of r) (Mc.states_seen reach)

(* An honest VACUITY row (P14 N5), and it is spelled as one: clean + decisive
   + a gate of 0 + every member's premise silent. The 0 IS the result. *)
let check_vacuity_row (label : string) (r : Fc.fault_report)
    (reach : Fc.faulted Mc.reachable) ~(gate : int) ~(states : int)
    ~(r1 : int) ~(r2 : int) ~(r3 : int) : unit =
  Alcotest.(check bool) (label ^ ": outcome clean (VACUOUSLY - see below)")
    true (is_clean r);
  Alcotest.(check string) (label ^ ": violated = None") "<none>"
    (violated_name r);
  Alcotest.(check bool) (label ^ ": decisive") true (decisive r);
  check_replica_faithful label reach r;
  (* THE VACUITY ITSELF, asserted as the modelling fact it is: no monkey step
     is enabled on this budget, so no [src = Pod_monkey] message can exist
     and no member's premise can fire. This row is NOT evidence the rely
     condition holds. *)
  Alcotest.(check bool)
    (label ^ ": NO member premise fires - honest vacuity, not a pass") true
    (fires family reach r1_name = 0
    && fires family reach r2_name = 0
    && fires family reach r3_name = 0);
  (* graph identity (pin safety, prediction 1) then the exact pins *)
  Alcotest.(check int) (label ^ ": graph states (committed pin, monkey_forge = [])")
    states (states_of r);
  Alcotest.(check int) (label ^ ": union gate") gate (gate_of r);
  Alcotest.(check int) (label ^ ": R1 interesting") r1
    (fires family reach r1_name);
  Alcotest.(check int) (label ^ ": R2 interesting") r2
    (fires family reach r2_name);
  Alcotest.(check int) (label ^ ": R3 interesting") r3
    (fires family reach r3_name);
  Alcotest.(check int) (label ^ ": R1 red") 0 (reds family reach r1_name);
  Alcotest.(check int) (label ^ ": R2 red") 0 (reds family reach r2_name);
  Alcotest.(check int) (label ^ ": R3 red") 0 (reds family reach r3_name)

(* ==== family shape ========================================================= *)

let test_family_shape () =
  Alcotest.(check (list string))
    "rely_family = the three upstream names, in member order R1, R2, R3"
    [ r1_name; r2_name; r3_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family);
  Alcotest.(check (list string))
    "member sources = rely_sources, same order (the .mli's exposed literals)"
    Rc.rely_sources
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.source) family);
  Alcotest.(check int) "rely_family cardinal = 3" 3 (List.length family);
  Alcotest.(check int) "helper_family cardinal = 2 (P18's H1/H2)" 2
    (List.length helper_family)

(* ==== the vsts-prefix literal: THREE literals must agree ==================
   BUILD-SPEC-P20 section 2.3 requires this as a TEST, not a comment, and B2's
   MEASURED-CORRECTION 5 says why: the reconciler does NOT derive its prefix
   from the kind. [v_stateful_set_reconciler.ml:191] ([pod_name]) and [:207]
   ([get_ordinal]) each hard-code ["vstatefulset-"] independently, and the
   family ships a third copy (rely_conditions.ml:53) deliberately - so that a
   [kind_name] drift cannot silently re-point the family away from the names
   the reconciler actually MINTS.

   WHAT A DRIFT AMONG THE THREE WOULD ACTUALLY COST (BUILD-SPEC-P20
   REVIEW-FIX D; this block used to say it "would silently empty the whole
   family", which B5 MEASURED false from both sides). ML2 forced
   [has_vsts_prefix] to a constant [false] and NOT ONE LEG MOVED; ML1 mutated
   the reconciler's minted prefix and R1/R2 stayed RED (t_p20_mutation.ml's
   ML2 and ML1 blocks; BUILD-SPEC-P20 section 5.4). A drift empties the
   family's PREFIX CONJUNCT only. The OWNER-REF conjunct
   (rely_guarantee.rs:68-69 for R1, :82-83 / :85 for R2) carries every measured
   red on its own, because [make_pod] stamps the vsts controller owner ref onto
   every pod the reconciler mints ([make_owner_references],
   v_stateful_set_reconciler.ml:218-220, installed into the pod metadata at
   :379). The prefix conjunct is present but NOT load-bearing.

   The family's own copy is not exported, so it can only be pinned
   BEHAVIOURALLY - but that pin is weaker than this block used to claim
   (REVIEW-FIX C). Its POSITIVE half is OVER-DETERMINED: the payload carries
   the vsts owner ref too, and R1 is a conjunction, so the owner-ref conjunct
   alone produces the red. Only its NEGATIVE half needs both conjuncts. The
   prefix conjunct's only discriminating witnesses in the tree are
   [t_p20_mutation]'s F-R1a / F-R1b / F-R2a rows; details at the two cases
   below. *)

let parent : string =
  Option.value ~default:"" (Object_meta.name (V_stateful_set.metadata cr))

let test_prefix_literals () =
  Alcotest.(check string) "V_stateful_set.kind_name" "vstatefulset"
    V_stateful_set.kind_name;
  let minted = Vsr.pod_name parent 0 in
  Alcotest.(check bool)
    "the reconciler MINTS a \"vstatefulset-\"-prefixed pod name (:191)" true
    (String.starts_with ~prefix:"vstatefulset-" minted);
  Alcotest.(check (option int))
    "get_ordinal (:207) inverts pod_name (:191) - the two literals agree"
    (Some 0)
    (Vsr.get_ordinal parent minted);
  Alcotest.(check (option int))
    "get_ordinal rejects a non-vsts name (the literal is not matching \
     everything)"
    None
    (Vsr.get_ordinal parent "p20-outsider-0")

(* ==== E3's arm roster + the family's behavioural prefix pin ================
   Upstream's [_ => true] at rely_guarantee.rs:26 ("Deletion/UpdateStatus
   requests are allowed") is LOAD-BEARING content, not a default: it is the
   deliberate SHAPE of what VSTS lets its environment do, and it is also what
   pins exclusion E3 (the [vsts_rely_*] helpers at :92 / :105 / :120 are
   reachable only through [vsts_rely] (:39, :45-53), never through the monkey
   rely). The family spells all seven remaining arms out; a wildcard would
   have erased the phase's own subject matter.

   Each permitted arm is injected with a MAXIMALLY rely-violating payload -
   the [rely_violating_forge]'s own object, name, namespace and the vsts
   controller owner ref - so a green cannot be an artefact of a harmless
   payload. The two CONSTRAINED arms carry the identical payload and must go
   RED, which is what proves the injection really lands. *)

let base_state : Cluster.cluster_state =
  seed_of ~req_drop:false ~pod_monkey:false ~vct:false

let inject (m : Message.t) (s : Cluster.cluster_state) : Cluster.cluster_state =
  { s with Cluster.network = { Network.in_flight = Message.Pool.singleton m } }

let monkey_msg (content : Message.message_content) : Message.t =
  Message.pod_monkey_req_msg (Message.Rpc_id.of_int 0) content

let forge_md : Object_meta.t = Pod.metadata lf_forge
let forge_obj : Dynamic_object.t = Pod.marshal lf_forge
let forge_ns : string = Option.value ~default:"" forge_md.namespace
let forge_name : string = Option.value ~default:"" forge_md.name

let vsts_owner : Owner_reference.t =
  Option.value
    (V_stateful_set.controller_owner_ref cr)
    ~default:(Owner_reference.default ())

let respecting_md : Object_meta.t = Pod.metadata c1_forge
let respecting_obj : Dynamic_object.t = Pod.marshal c1_forge

let respecting_ns : string =
  Option.value ~default:"" respecting_md.namespace

let permitted_arms : (string * Message.message_content) list =
  [
    ("Get_request", Message.get_req_msg_content lf_key);
    ("List_request", Message.list_req_msg_content Pod.kind forge_ns);
    ("Delete_request", Message.delete_req_msg_content lf_key None);
    ( "Update_status_request",
      Message.update_status_req_msg_content forge_ns forge_name forge_obj );
    ( "Get_then_delete_request",
      Message.get_then_delete_req_msg_content lf_key vsts_owner );
    ( "Get_then_update_request",
      Message.get_then_update_req_msg_content forge_ns forge_name vsts_owner
        forge_obj );
    ( "Get_then_update_status_request",
      Message.get_then_update_status_req_msg_content forge_ns forge_name
        vsts_owner forge_obj );
  ]

let constrained_arms : (string * Message.message_content) list =
  [
    ("Create_request", Message.create_req_msg_content forge_ns forge_obj);
    ( "Update_request",
      Message.update_req_msg_content forge_ns forge_name forge_obj );
  ]

let test_permissiveness_and_prefix () =
  Alcotest.(check int) "E3: seven permitted arms enumerated"
    P20_witness.e3_permitted_arms (List.length permitted_arms);
  (* (a) every permitted arm: R3 GREEN, and its premise DEMONSTRABLY fires -
     a green whose premise never fired would be vacuous. *)
  List.iter
    (fun ((label, content) : string * Message.message_content) ->
      let s = inject (monkey_msg content) base_state in
      Alcotest.(check bool)
        ("E3 " ^ label ^ ": R3 premise fires (injection landed)")
        true
        (member_interesting family r3_name s);
      Alcotest.(check bool)
        ("E3 " ^ label ^ ": R3 GREEN (:26 permissiveness is CONTENT)")
        true
        (member_holds family r3_name s);
      Alcotest.(check bool)
        ("E3 " ^ label ^ ": R1 GREEN (arm not constrained by :57)")
        true
        (member_holds family r1_name s);
      Alcotest.(check bool)
        ("E3 " ^ label ^ ": R2 GREEN (arm not constrained by :76)")
        true
        (member_holds family r2_name s))
    permitted_arms;
  (* (b) the RED controls on the two constrained arms, same payload: what they
     establish is that the injection really LANDS on the two arms upstream
     constrains, against the seven it does not.

     WHAT THEY DO NOT ESTABLISH (BUILD-SPEC-P20 REVIEW-FIX C). This block used
     to say a red here "proves the family's [\"vstatefulset-\"] literal agrees
     with the minting site", and the positive assertion below was presented as
     the family's BEHAVIOURAL prefix pin. Neither is true: the payload is
     [rely_violating_forge]'s object, minted by the reconciler's own
     [make_pod], which stamps BOTH a vsts-prefixed name
     (v_stateful_set_reconciler.ml:376) AND the vsts controller owner ref
     (:379). R1 is a CONJUNCTION (rely_conditions.ml:103-105), so the owner-ref
     conjunct ALONE produces the red - the payload is OVER-DETERMINED. B5
     measured exactly this: with [has_vsts_prefix] forced to a constant
     [false], this whole exe stayed GREEN, all 14 cases (t_p20_mutation.ml's
     ML2 block). The prefix conjunct is pinned by [t_p20_mutation]'s F-R1a (a
     vsts-prefixed [metadata.name], :61-66 then-branch), F-R1b (a vsts-prefixed
     [generate_name] with [name = None], the :63-66 else-branch) and F-R2a (a
     vsts-prefixed REQUEST name, :80) rows, and nowhere else in the tree. *)
  List.iter
    (fun ((label, content) : string * Message.message_content) ->
      let s = inject (monkey_msg content) base_state in
      Alcotest.(check bool)
        ("E3 control " ^ label ^ ": R3 RED (the injection really lands)")
        false
        (member_holds family r3_name s))
    constrained_arms;
  Alcotest.(check bool)
    "prefix pin: a monkey create of a RECONCILER-MINTED vsts pod reddens R1"
    false
    (member_holds family r1_name
       (inject
          (monkey_msg (Message.create_req_msg_content forge_ns forge_obj))
          base_state));
  (* (c) the negative half of the prefix pin: the rely-RESPECTING forge's
     non-vsts name leaves R1 GREEN under the identical create arm, so the
     literal is discriminating rather than matching everything. *)
  Alcotest.(check bool)
    "prefix pin (negative): a monkey create of a NON-vsts pod leaves R1 green"
    true
    (member_holds family r1_name
       (inject
          (monkey_msg
             (Message.create_req_msg_content respecting_ns respecting_obj))
          base_state))

(* ==== Leg A: the three HONEST VACUITY rows ================================= *)

let test_l0 () =
  check_vacuity_row "L0" (Lazy.force l0) (Lazy.force l0_reach)
    ~gate:P20_witness.l0_gate_states ~states:P20_witness.l0_states
    ~r1:P20_witness.r1_interesting_l0 ~r2:P20_witness.r2_interesting_l0
    ~r3:P20_witness.r3_interesting_l0

let test_lc () =
  check_vacuity_row "Lc" (Lazy.force lc) (Lazy.force lc_reach)
    ~gate:P20_witness.lc_gate_states ~states:P20_witness.lc_states
    ~r1:P20_witness.r1_interesting_lc ~r2:P20_witness.r2_interesting_lc
    ~r3:P20_witness.r3_interesting_lc

let test_ld () =
  check_vacuity_row "Ld" (Lazy.force ld) (Lazy.force ld_reach)
    ~gate:P20_witness.ld_gate_states ~states:P20_witness.ld_states
    ~r1:P20_witness.r1_interesting_ld ~r2:P20_witness.r2_interesting_ld
    ~r3:P20_witness.r3_interesting_ld

(* ==== Lm: THE HEADLINE, forge-free, on a COMMITTED graph =================== *)

let test_lm_headline () =
  let r = Lazy.force lm in
  let reach = Lazy.force lm_reach in
  (* graph identity FIRST: if this moved, the seed or the bound moved and no
     count below means anything (spec section 4.1: STOP and diagnose, never
     retune). Read off the REPLICA, because a [Refuted] outcome carries no
     [states] field - and the replica is the graph every count below is taken
     over, which is exactly the quantity that must equal the committed pin. *)
  Alcotest.(check int)
    "Lm: graph states = the committed 1976 (pin safety, monkey_forge = [])"
    P20_witness.lm_states (Mc.states_seen reach);
  (* SEMANTIC facts next. The non-vacuity floor (prediction 3) is a genuine
     go/no-go: with a zero gate the leg would have measured nothing. *)
  Alcotest.(check bool) "Lm: gate > 0 - THE NON-VACUITY FLOOR (prediction 3)"
    true
    (gate_of r > 0);
  Alcotest.(check bool)
    "Lm: outcome REFUTED - the rely condition is VIOLATED on a committed \
     graph, forge-free (an ASSUMPTION-VIOLATION datum, NOT an Anvil defect)"
    false (is_clean r);
  Alcotest.(check string)
    "Lm: violated names R1 (first_violated's family order)" r1_name
    (violated_name r);
  (* BOTH ARMS RED (prediction 4). R2's red count is the spec's PHASE-STOP
     clause: at 0, section 1's premise-refutation would itself be refuted and
     the phase would stop for a spec revision. *)
  Alcotest.(check bool)
    "Lm: R1 RED somewhere (monkey Create_pod re-sends a stored vsts pod)" true
    (reds family reach r1_name > 0);
  Alcotest.(check bool)
    "Lm: R2 RED somewhere - THE PHASE-STOP CLAUSE (spec section 5.4); a 0 \
     here refutes section 1's premise-refutation and stops the phase"
    true
    (reds family reach r2_name > 0);
  Alcotest.(check bool) "Lm: R3 RED somewhere (both arms feed it)" true
    (reds family reach r3_name > 0);
  (* Every premise-firing state is red on both arms - measured, not assumed. *)
  Alcotest.(check bool)
    "Lm: R1 red at EVERY R1-premise state (measured coincidence, not a law)"
    true
    (reds family reach r1_name = fires family reach r1_name);
  Alcotest.(check bool)
    "Lm: R2 red at EVERY R2-premise state (measured coincidence, not a law)"
    true
    (reds family reach r2_name = fires family reach r2_name);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Lm: union gate" P20_witness.lm_gate_states (gate_of r);
  Alcotest.(check int) "Lm: R1 interesting" P20_witness.r1_interesting_lm
    (fires family reach r1_name);
  Alcotest.(check int) "Lm: R2 interesting" P20_witness.r2_interesting_lm
    (fires family reach r2_name);
  Alcotest.(check int) "Lm: R3 interesting" P20_witness.r3_interesting_lm
    (fires family reach r3_name);
  Alcotest.(check int) "Lm: R1 red" P20_witness.r1_red_lm
    (reds family reach r1_name);
  Alcotest.(check int) "Lm: R2 red (the phase-stop number)"
    P20_witness.r2_red_lm (reds family reach r2_name);
  Alcotest.(check int) "Lm: R3 red" P20_witness.r3_red_lm
    (reds family reach r3_name)

(* ==== Prediction 5: P18's H1 stays GREEN on Lm while R3 is RED ============= *)

let test_h1_green_on_lm () =
  let reach = Lazy.force lm_reach in
  Alcotest.(check int)
    "prediction 5: H1's premise really fires on Lm (else the green is \
     vacuous)"
    P18_witness.h1_interesting_lm
    (fires helper_family reach h1_name);
  Alcotest.(check bool)
    "prediction 5: R3 is RED on Lm (the assumption IS violated there)" true
    (reds family reach r3_name > 0);
  Alcotest.(check int)
    "prediction 5: P18's H1 red count on the SAME Lm graph - MEASURED here, \
     not inferred from P18's pins. Assumption violated WITHOUT consequence: \
     P18's \"Lm CLEAN\" is EMERGENT ROBUSTNESS, not rely-consistency"
    P20_witness.h1_red_lm
    (reds helper_family reach h1_name)

(* ==== Prediction 6: R3 <=> R1 && R2 over every reachable state ============= *)

let test_identity () =
  let check (label : string) (reach : Fc.faulted Mc.reachable) : unit =
    Alcotest.(check int)
      ("R3 <=> R1 && R2 disagreements on " ^ label)
      P20_witness.r3_identity_disagreements (identity_disagreements reach)
  in
  check "L0" (Lazy.force l0_reach);
  check "Lc" (Lazy.force lc_reach);
  check "Ld" (Lazy.force ld_reach);
  check "Lm" (Lazy.force lm_reach);
  check "Lf" (Lazy.force lf_reach);
  check "C1" (Lazy.force c1_reach)

(* ==== PIN SAFETY: the five committed graph pins, re-MEASURED =============== *)

let test_pin_safety () =
  (* L0 / Lc / Ld / Lm ride the leg reports (asserted in their own tests too);
     this test is the one place all five are read together, including the
     [vct:true] L0v graph no P20 leg runs. A moved pin is a STOP, never a
     retune. *)
  Alcotest.(check int) "pin safety L0 = 76" P20_witness.l0_states
    (Mc.states_seen (Lazy.force l0_reach));
  Alcotest.(check int) "pin safety Lc = 464" P20_witness.lc_states
    (Mc.states_seen (Lazy.force lc_reach));
  Alcotest.(check int) "pin safety Ld = 744" P20_witness.ld_states
    (Mc.states_seen (Lazy.force ld_reach));
  Alcotest.(check int) "pin safety Lm = 1976" P20_witness.lm_states
    (Mc.states_seen (Lazy.force lm_reach));
  Alcotest.(check int) "pin safety L0v = 116 (vct:true, replica only)"
    P20_witness.l0v_states
    (Mc.states_seen (Lazy.force l0v_reach));
  (* The field really is present and really is empty on the bound these five
     rode - otherwise the pins prove nothing about the edit. *)
  Alcotest.(check int) "the pinned bound carries monkey_forge = []" 0
    (List.length bound.Bound.monkey_forge)

(* ==== Leg B - Lf: the ASSUMPTION-NECESSITY witness ========================= *)

let test_lf () =
  let r = Lazy.force lf in
  let reach = Lazy.force lf_reach in
  (* The forge really is one pod, and it really is the rely-violating one. *)
  Alcotest.(check int) "Lf: monkey_forge is exactly one pod" 1
    (List.length lf_bound.Bound.monkey_forge);
  Alcotest.(check bool)
    "Lf: the forge's name IS vsts-prefixed (that is what violates the rely)"
    true
    (String.starts_with ~prefix:"vstatefulset-" lf_key.Common.name);
  Alcotest.(check bool)
    "Lf: the forge's ordinal is OUTSIDE the reconciler's live range 0..desired-1 \
     (the vacuous-green trap: a colliding create is rejected \
     Object_already_exists)"
    true
    (Fc.forge_ordinal ~desired > desired - 1);
  (* THE FLOOR FIRST: a zero gate would mean the leg measured NOTHING (create
     rejected, name unparseable, or wrong namespace) and would have to be read
     as a failed experiment, never as a clean run. *)
  Alcotest.(check bool)
    "Lf: gate > 0 - the forged pod REACHED ETCD and H1's premise fired on it"
    true
    (gate_of r > 0);
  Alcotest.(check bool)
    "Lf: outcome REFUTED - the ASSUMPTION-NECESSITY witness. The rely \
     condition is LOAD-BEARING for H1, not decorative. NOT a defect in Anvil \
     and NOT \"we broke H1\": the forge is exactly an environment step \
     upstream's environment_rely slot forbids"
    false (is_clean r);
  Alcotest.(check string) "Lf: violated names H1" h1_name (violated_name r);
  (* The attribution the gate exists to license: H1 is red at PRECISELY the
     gated states. *)
  Alcotest.(check int)
    "Lf: H1 red count = the gate exactly (red attributable to the forge)"
    (gate_of r)
    (reds helper_family reach h1_name);
  (* Exact MEASURED pins LAST. The Lf graph pin is P20's ONLY new graph
     constant (prediction 8) - it was measured, never predicted. *)
  Alcotest.(check int)
    "Lf: graph states (NEW pin, P20's only new graph; read off the replica - \
     a Refuted outcome carries no states field)"
    P20_witness.lf_states (Mc.states_seen reach);
  Alcotest.(check int) "Lf: gate" P20_witness.lf_gate_states (gate_of r);
  Alcotest.(check int) "Lf: H1 red" P20_witness.h1_red_lf
    (reds helper_family reach h1_name);
  Alcotest.(check int) "Lf: R1 interesting" P20_witness.r1_interesting_lf
    (fires family reach r1_name);
  Alcotest.(check int) "Lf: R2 interesting" P20_witness.r2_interesting_lf
    (fires family reach r2_name);
  Alcotest.(check int) "Lf: R3 interesting" P20_witness.r3_interesting_lf
    (fires family reach r3_name);
  Alcotest.(check int) "Lf: R1 red" P20_witness.r1_red_lf
    (reds family reach r1_name);
  Alcotest.(check int) "Lf: R2 red" P20_witness.r2_red_lf
    (reds family reach r2_name);
  Alcotest.(check int) "Lf: R3 red" P20_witness.r3_red_lf
    (reds family reach r3_name)

(* ==== C1: the containment CONTROL ========================================= *)

let test_c1 () =
  let r = Lazy.force c1 in
  let reach = Lazy.force c1_reach in
  check_replica_faithful "C1" reach r;
  Alcotest.(check bool)
    "C1: the control forge's name is NOT vsts-prefixed (the only two fields \
     that differ from Lf's forge; the FINALIZER is kept, which is what makes \
     the control sharp)"
    false
    (String.starts_with ~prefix:"vstatefulset-" c1_key.Common.name);
  (* THE ROW'S OWN NON-VACUITY, and it is NOT the gate. C1's [gate_states] is
     STRUCTURALLY 0 - the respecting forge's key never satisfies
     [pod_premise], which is the entire point of the control - so section
     4.3's "a zero gate means the leg measured nothing" does NOT apply here
     (B3 MEASURED-CORRECTION 2). The evidence is clean + decisive PLUS the
     forged key really being in etcd. *)
  Alcotest.(check int)
    "C1: gate is STRUCTURALLY 0 (pod_premise never fires on a non-vsts name) \
     - reading this as a failed experiment inverts the row's meaning"
    0 (gate_of r);
  Alcotest.(check bool)
    "C1: the control forge really LANDED in etcd (not rejected at admission) \
     - THIS, not the gate, is C1's non-vacuity"
    true
    (key_present c1_key reach > 0);
  Alcotest.(check bool)
    "C1: outcome CLEAN - H1 green under a forge that is INSIDE the rely. \
     This is what makes Lf's red decisive: it attributes the red to \
     RELY-VIOLATION, not to forging as such"
    true (is_clean r);
  Alcotest.(check string) "C1: violated = None" "<none>" (violated_name r);
  Alcotest.(check bool) "C1: decisive" true (decisive r);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "C1: graph states (NEW pin)" P20_witness.c1_states
    (states_of r);
  Alcotest.(check int) "C1: H1 red" P20_witness.h1_red_c1
    (reds helper_family reach h1_name);
  Alcotest.(check int) "C1: forged key present in etcd"
    P20_witness.c1_forged_key_states (key_present c1_key reach);
  Alcotest.(check int) "C1: R1 interesting" P20_witness.r1_interesting_c1
    (fires family reach r1_name);
  Alcotest.(check int) "C1: R2 interesting" P20_witness.r2_interesting_c1
    (fires family reach r2_name);
  Alcotest.(check int) "C1: R3 interesting" P20_witness.r3_interesting_c1
    (fires family reach r3_name);
  Alcotest.(check int)
    "C1: R1 red (the rely-RESPECTING forge adds no rely violation of its own)"
    P20_witness.r1_red_c1 (reds family reach r1_name);
  Alcotest.(check int) "C1: R2 red" P20_witness.r2_red_c1
    (reds family reach r2_name);
  Alcotest.(check int) "C1: R3 red" P20_witness.r3_red_c1
    (reds family reach r3_name)

(* ==== E1: the OTHER-CONTROLLER rely is vacuous on BOTH shipped spines ======
   The HONEST reason for excluding rely_guarantee.rs:32 / :39, not "out of
   scope": upstream's [forall other_id in controller_models.remove(
   controller_id)] ranges over an EMPTY set on both spines, so E1 is
   vacuously true at every reachable state of every leg. The exclusion is
   scenario-conditional and this pin says so: a P9-style two-controller spine
   reddens it and RE-OPENS E1 rather than leaving it silently stale. *)

let removal_set (c : Cluster.t) : int =
  Imap.cardinal (Imap.remove controller_id c.Cluster.controller_models)

let test_e1 () =
  Alcotest.(check int) "E1: vsts spine installs exactly one controller model"
    P20_witness.spine_controller_models
    (Imap.cardinal cluster.Cluster.controller_models);
  Alcotest.(check int) "E1: vrs/generic spine installs exactly one too"
    P20_witness.spine_controller_models
    (Imap.cardinal Scenario.cluster.Cluster.controller_models);
  Alcotest.(check int)
    "E1: controller_models.remove(controller_id) is EMPTY on the vsts spine \
     - upstream's forall other_id is vacuously true"
    P20_witness.spine_controller_models_after_removal (removal_set cluster);
  Alcotest.(check int)
    "E1: ... and on the vrs/generic spine (a two-controller spine reddens \
     this and re-opens E1)"
    P20_witness.spine_controller_models_after_removal
    (removal_set Scenario.cluster)

(* ==== E2 / E4: the scope ledger over trusted/rely_guarantee.rs =============
   E4 SCOPE PIN. The file has exactly 12 [pub open spec fn] (B1 COUNTED them;
   the spec body's "13" is a MEASURED-CORRECTION). The partition must be
   TOTAL: 3 shipped (R1 :57, R2 :76, R3 :17) + E1 2 (:32, :39) + E3 3 (:92,
   :105, :120) + E2 4 (:133, :152, :164, :176).

   E2 (the GUARANTEE direction - what VSTS promises OTHERS) is excluded
   because P19's E3' already pinned that register to [inv_self]; porting it
   would re-open the P17-review overlap-misread class. The pin below is the
   ledger form: no shipped source may name a guarantee line.

   The shipped side is READ OFF [Rc.rely_sources], never re-typed, so a family
   edit that re-points a source reddens the ledger. *)

let line_of_source (s : string) : int option =
  Option.bind (String.rindex_opt s ':') (fun i ->
      int_of_string_opt (String.sub s (i + 1) (String.length s - i - 1)))

let shipped_lines : int list =
  List.sort compare (List.filter_map line_of_source Rc.rely_sources)

let ledger : int list =
  P20_witness.e4_shipped_lines @ P20_witness.e4_e1_lines
  @ P20_witness.e4_e3_lines @ P20_witness.e4_e2_lines

let test_e2_e4_ledger () =
  Alcotest.(check bool)
    "E4: every shipped source names trusted/rely_guarantee.rs" true
    (List.for_all
       (String.starts_with
          ~prefix:"vstatefulset_controller/trusted/rely_guarantee.rs:")
       Rc.rely_sources);
  Alcotest.(check (list int))
    "E4: the SHIPPED lines, read off rely_sources (never re-typed)"
    P20_witness.e4_shipped_lines shipped_lines;
  Alcotest.(check int)
    "E4: the partition is TOTAL - 3 shipped + E1 2 + E3 3 + E2 4 = the file's \
     12 pub open spec fn"
    P20_witness.e4_spec_fn_count (List.length ledger);
  Alcotest.(check int) "E4: the partition is DISJOINT (no line ledgered twice)"
    P20_witness.e4_spec_fn_count
    (List.length (List.sort_uniq compare ledger));
  Alcotest.(check bool)
    "E2: no shipped source names a GUARANTEE line (:133/:152/:164/:176) - \
     P19's E3' owns that register"
    false
    (List.exists
       (fun (n : int) -> List.mem n P20_witness.e4_e2_lines)
       shipped_lines);
  Alcotest.(check bool)
    "E1/E3: no shipped source names an other-controller-rely line either"
    false
    (List.exists
       (fun (n : int) ->
         List.mem n P20_witness.e4_e1_lines
         || List.mem n P20_witness.e4_e3_lines)
       shipped_lines)

let () =
  Alcotest.run "p20_rely"
    [
      ( "family_shape",
        [
          Alcotest.test_case "rely_family = the three upstream names" `Quick
            test_family_shape;
          Alcotest.test_case
            "the vsts-prefix literal: three independent copies agree" `Quick
            test_prefix_literals;
          Alcotest.test_case
            "E3: the :26 permissiveness is CONTENT (7 arms green, 2 red \
             controls)"
            `Quick test_permissiveness_and_prefix;
        ] );
      ( "pin_safety",
        [
          Alcotest.test_case
            "the five committed graph pins survive the Bound.t edit" `Quick
            test_pin_safety;
        ] );
      ( "leg_a",
        [
          Alcotest.test_case "L0: zero-budget - HONEST VACUITY row" `Quick
            test_l0;
          Alcotest.test_case "Lc: crash-only - HONEST VACUITY row" `Quick
            test_lc;
          Alcotest.test_case "Ld: drop-only - HONEST VACUITY row" `Quick
            test_ld;
          Alcotest.test_case
            "Lm: THE HEADLINE - rely RED forge-free on a committed graph"
            `Quick test_lm_headline;
          Alcotest.test_case
            "prediction 5: P18's H1 GREEN on Lm while R3 is RED (emergent \
             robustness)"
            `Quick test_h1_green_on_lm;
          Alcotest.test_case
            "prediction 6: R3 <=> R1 && R2 at every reachable state of every \
             leg"
            `Quick test_identity;
        ] );
      ( "leg_b",
        [
          Alcotest.test_case
            "Lf: the rely-VIOLATING forge reddens H1 (assumption-necessity)"
            `Quick test_lf;
          Alcotest.test_case
            "C1: the rely-RESPECTING forge leaves H1 green (containment \
             control)"
            `Quick test_c1;
        ] );
      ( "exclusions",
        [
          Alcotest.test_case "E1: the other-controller rely is vacuous on both \
                              spines" `Quick test_e1;
          Alcotest.test_case
            "E2/E4: the trusted/rely_guarantee.rs scope ledger is total and \
             disjoint"
            `Quick test_e2_e4_ledger;
        ] );
    ]

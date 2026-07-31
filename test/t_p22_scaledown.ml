(* BUILD-SPEC-P22 sections 2-4 and 8 - the scale-down (G2-live) measurement:
   {!Anvil_checker.Fault_check.check_scale_down_under_faults} (the SHIPPED
   P21 register {!Anvil_assurance.Internal_guarantee.guarantee_family},
   G1-G4 - deliberately NO new family) over the four NEW fault graphs seeded
   by {!Anvil_assurance.Scenario.vsts_seed_with_pods}, plus the
   seed-integrity obligations and the MS3 seed-sabotage control.

   WHAT THIS EXE ESTABLISHES.

   1. THE PHASE GATE, MEASURED (spec prediction 1 CONFIRMED): G2
      ([get_then_delete], internal_rely_guarantee.rs:581) [interesting] > 0
      on SL0 - and, measured beyond the gate, on ALL FOUR legs. P21 measured
      G2 VACUOUS on all five committed graphs (fault_check.mli's MEASURED
      block; t_p21_guarantee's honest-vacuity case); this exe is that
      vacuity's removal - an unmasked measurement in the P17 style, not a
      new predicate surface - and it is what converts P21's mutant MG6
      (wrong owner ref on the Delete_condemned emit) from INERT-BY-VACUITY
      to refutable (t_p22_mutation MS1, the headline row).

   2. SEED INTEGRITY IS ASSERTED, NOT ASSUMED (spec section 2), THROUGH AN
      EXPORTED TOTAL PREDICATE (P22 review finding F3):
      {!Anvil_assurance.Scenario.vsts_seed_pods_intact} - the surplus pod
      present at its canonical ref, carrying EXACTLY ONE owner ref whose uid
      is the LIVE CR's server-stamped uid (read off the state, never the
      literal 1), its name round-tripping through the reconciler's ordinal
      parse ([get_ordinal]), and the requested ordinals DISTINCT. The
      predicate is the caller's obligation for
      [check_scale_down_under_faults], which forwards [~ordinals] unchecked;
      here it is asserted for the shipped instantiation on EVERY leg seed,
      and its RED capability is exercised SIX ways (unseeded ordinal, owner
      uid 99, emptied owner-ref list, repeated ordinal, an ordinal BELOW
      desired, and a right-uid/wrong-name owner ref) so a
      constantly-true predicate cannot pass for evidence. A mismatched
      owner-ref uid would make the pod GC-orphaned
      (builtin_controllers.ml:64-81) and silently reproduce the exact G2
      vacuity this phase removes - which is not rhetoric: the MS3 control
      below MEASURES that failure mode on the SAME doctored seed the
      predicate rejects (owner uid 99) and asserts the phase gate catches
      it (G2 fires nowhere on its zero-budget graph, run as a same-depth
      discriminating pair at a bounded horizon - the MS3 section documents
      why the full leg depth is unexplorable there, and that blow-up is
      itself the row's measured GC-contest datum).

   3. ALL FOUR LEGS GREEN ON THE NEW GRAPHS (spec prediction 2 CONFIRMED):
      clean, [violated] = None, decisive, gate non-zero, G1-G4 red 0
      everywhere, per-member [interesting] at the {!P22_witness} pins. The
      epistemic reading is P21's (a red here is a FIDELITY divergence in
      the port - the reconciler emitting a request upstream proves its
      reconciler never emits - and a real finding), now with G2's conjuncts
      actually evaluated inside the graphs.

   4. LEG ORDER IS THE MG5 LESSON: SL0 (zero-budget) FIRST, then the fault
      legs - the B3 probe order that gated the phase, preserved here.

   TEST-ORDERING RULE (P12 finding 1, P13-P21 precedent): every test asserts
   the SEMANTIC facts FIRST - outcome, [violated], decisive, replica
   faithfulness, floors (the phase gate among them) - and only THEN the
   brittle exact counts.

   Every pinned number comes from {!P22_witness} (single source of truth);
   none is re-typed here. MS3's expected 0 is a PREDICTED control verdict
   (spec section 5), not a measured pin, so it appears as the in-test
   expectation the matrix row committed to - never in the witness (P21
   review finding 6).

   [report_decisive] DOES NOT EXIST in this tree (the P20 B1 phantom
   finding, still true); every leg is reported through the LOCAL decisive
   projection below - the two-arm exhaustive [Mc.outcome] match of
   t_p17_store.ml:71-79.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum (both [Mc.outcome] arms), no
   two-arm match on [option]/[result] (stdlib [Option.fold]/[Option.value]),
   total accessors only, Alcotest as the sanctioned failure primitive. *)

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

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) -------- *)

let decisive (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let is_clean (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

(* [Mc.Refuted] carries no [states] field (model_check.mli:39); [-1] is the
   shipped sentinel. Every leg below is expected clean, so the sentinel
   surfacing in a pin assertion is itself a loud diagnosis. *)
let states_of (r : Fc.fault_report) : int =
  match r.outcome with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let gate_of (r : Fc.fault_report) : int =
  Option.value r.gate_states ~default:(-1)

let violated_name (r : Fc.fault_report) : string =
  Option.fold r.violated ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ==== the four members, addressed BY NAME off the family ===================
   t_p21_guarantee's discipline: a missing name makes both projections
   constantly [false], which the phase-gate floor below reddens LOUDLY
   before any count could quietly go 0. *)

let g1_name : string = "vsts_internal_guarantee_create_req"
let g2_name : string = "vsts_internal_guarantee_get_then_delete_req"
let g3_name : string = "vsts_internal_guarantee_get_then_update_req"
let g4_name : string = "no_interfering_request_between_vsts"

let member_interesting (name : string) (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.interesting s)
    family

let member_holds (name : string) (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.holds s)
    family

(* ==== the leg runs (lazy: no test pays for an unused exploration) ========= *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget)
    ~(require_fault : bool) : Fc.fault_report =
  Fc.check_scale_down_under_faults ~depth ~req_drop ~pod_monkey bound budget
    ~desired ~ordinals ~require_fault

let sl0 : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false P22_witness.zero_budget
       ~require_fault:false)

let slc : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false P22_witness.slc_budget
       ~require_fault:true)

let sld : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:true ~pod_monkey:false P22_witness.sld_budget
       ~require_fault:true)

let slm : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:true P22_witness.slm_budget
       ~require_fault:true)

(* ==== LOCAL replicas of the legs' product graphs ===========================
   The per-member counts need the reachable set itself, which [fault_report]
   does not carry. Same seed / bound / budget / depth through the exported
   {!Fc.faulted_successors}; every consuming test asserts [Mc.states_seen]
   against the leg's own [states] FIRST (the P13 M3/M5 precedent; B3
   measured the two EQUAL on every leg). *)

let seed_of ~(req_drop : bool) ~(pod_monkey : bool) : Cluster.cluster_state =
  Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true ~req_drop
    ~pod_monkey ()

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget) :
    Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed_of ~req_drop ~pod_monkey) ]

let sl0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false P22_witness.zero_budget)

let slc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false P22_witness.slc_budget)

let sld_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:true ~pod_monkey:false P22_witness.sld_budget)

let slm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:true P22_witness.slm_budget)

(* ---- counting projections over a replica --------------------------------- *)

let fires (reach : Fc.faulted Mc.reachable) (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      member_interesting name f.cs)

let reds (reach : Fc.faulted Mc.reachable) (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      not (member_holds name f.cs))

(* ---- the shared GREEN-leg assertion bundle --------------------------------
   Semantic facts first, exact pins last. The G2 floor inside it is THE
   PHASE GATE (header point 1): asserted [> 0] per member on EVERY leg
   before its exact pin - the exact inverse of t_p21_guarantee's
   honest-vacuity row, and the reason this exe exists. *)

let check_green_leg (label : string) (r : Fc.fault_report)
    (reach : Fc.faulted Mc.reachable) ~(states : int) ~(gate : int)
    ~(g1 : int) ~(g2 : int) ~(g3 : int) ~(g4 : int) : unit =
  Alcotest.(check bool)
    (label
   ^ ": outcome CLEAN - the guarantee HELD on a G2-live graph (a red here \
      would be a FIDELITY divergence in the port)")
    true (is_clean r);
  Alcotest.(check string) (label ^ ": violated = None") "<none>"
    (violated_name r);
  Alcotest.(check bool) (label ^ ": decisive") true (decisive r);
  Alcotest.(check int)
    (label ^ ": replica explored the leg's exact graph (states_seen)")
    (states_of r) (Mc.states_seen reach);
  Alcotest.(check bool)
    (label ^ ": family gate > 0 - the family-level non-vacuity floor (G1 \
              dominates the union gate; the G2 floor is the next line)")
    true
    (gate_of r > 0);
  Alcotest.(check bool)
    (label ^ ": G2 premise fires somewhere - THE PHASE GATE (prediction 1): \
              the condemned Get_then_delete is inside the explored graph, \
              P21's family-wide G2 vacuity removed")
    true
    (fires reach g2_name > 0);
  Alcotest.(check bool) (label ^ ": G1 premise fires somewhere") true
    (fires reach g1_name > 0);
  Alcotest.(check bool) (label ^ ": G3 premise fires somewhere") true
    (fires reach g3_name > 0);
  Alcotest.(check bool) (label ^ ": G4 premise fires somewhere") true
    (fires reach g4_name > 0);
  (* exact MEASURED pins LAST *)
  Alcotest.(check int)
    (label ^ ": graph states (committed pin - a NEW graph, new BY SEED not \
              by seam)")
    states (states_of r);
  Alcotest.(check int) (label ^ ": family gate") gate (gate_of r);
  Alcotest.(check int) (label ^ ": G1 interesting") g1 (fires reach g1_name);
  Alcotest.(check int) (label ^ ": G2 interesting") g2 (fires reach g2_name);
  Alcotest.(check int) (label ^ ": G3 interesting") g3 (fires reach g3_name);
  Alcotest.(check int) (label ^ ": G4 interesting") g4 (fires reach g4_name);
  Alcotest.(check int) (label ^ ": G1 red")
    P22_witness.scale_down_red_everywhere (reds reach g1_name);
  Alcotest.(check int) (label ^ ": G2 red")
    P22_witness.scale_down_red_everywhere (reds reach g2_name);
  Alcotest.(check int) (label ^ ": G3 red")
    P22_witness.scale_down_red_everywhere (reds reach g3_name);
  Alcotest.(check int) (label ^ ": G4 red")
    P22_witness.scale_down_red_everywhere (reds reach g4_name)

(* ==== seed integrity (spec section 2: assert, don't assume) ================ *)

let base_seed : Cluster.cluster_state =
  seed_of ~req_drop:false ~pod_monkey:false

(* The CR's own coordinates, READ off the CR, never typed. *)
let cr_md : Object_meta.t = V_stateful_set.metadata cr
let ns : string = Option.value ~default:"" (Object_meta.namespace cr_md)
let parent : string = Option.value ~default:"" (Object_meta.name cr_md)
let surplus_name : string = Vsr.pod_name parent 1

let surplus_ref : Common.object_ref =
  { Common.kind = Pod.kind; namespace = ns; name = surplus_name }

let stored_at (key : Common.object_ref) (s : Cluster.cluster_state) :
    Dynamic_object.t option =
  Object_ref_map.find_opt key s.Cluster.api_server.Api_server.resources

(* Every owner-ref uid of a stored object, as ints - so "exactly one owner
   ref, uid N" is one [(list int)] assertion with no partial accessor. *)
let owner_uids (obj : Dynamic_object.t) : int list =
  List.map
    (fun (r : Owner_reference.t) -> Common.Uid.to_int r.Owner_reference.uid)
    (Option.value ~default:[]
       (Dynamic_object.metadata obj).Object_meta.owner_references)

(* A THROWAWAY doctored state: the object stored at [key] with its owner-ref
   list rewritten by [f], everything else byte-for-byte the input. Total
   ([Option.fold], no partial accessor); an absent [key] yields the state
   UNCHANGED, which every consumer below reds on loudly (the doctoring is
   always asserted to have LANDED before it is used). Shared by the
   red-capability test and MS3, so both sabotages are built by one audited
   rewrite instead of two. *)
let doctor_owner_refs (key : Common.object_ref)
    (f : Owner_reference.t list -> Owner_reference.t list)
    (s : Cluster.cluster_state) : Cluster.cluster_state =
  Option.fold (stored_at key s) ~none:s ~some:(fun (obj : Dynamic_object.t) ->
      let md : Object_meta.t = Dynamic_object.metadata obj in
      let doctored : Dynamic_object.t =
        Dynamic_object.with_metadata
          (Object_meta.with_owner_references
             (f (Option.value ~default:[] md.Object_meta.owner_references))
             md)
          obj
      in
      {
        s with
        Cluster.api_server =
          {
            s.Cluster.api_server with
            Api_server.resources =
              Object_ref_map.add key doctored
                s.Cluster.api_server.Api_server.resources;
          };
      })

(* The surplus pod's sole owner ref re-uid'd to 99: GC-orphan shape, the pod
   [pod_filter] can no longer see. MS3 explores this very state. *)
let uid99_seed : Cluster.cluster_state =
  doctor_owner_refs surplus_ref
    (List.map (fun (r : Owner_reference.t) ->
         { r with Owner_reference.uid = Common.Uid.of_int 99 }))
    base_seed

(* The surplus pod stripped of ALL owner refs - the shape the OLD builder
   produced on any failure of its live-CR read ([~none:[]] collapse), and the
   one the rewritten builder can no longer emit (it now creates no pod at
   all). Kept as a red-capability probe: the predicate must reject it. *)
let unowned_seed : Cluster.cluster_state =
  doctor_owner_refs surplus_ref (fun _ -> []) base_seed

(* The surplus pod's sole owner ref keeps the LIVE CR's stamped uid but names a
   DIFFERENT parent. [pod_filter] admits through
   [Object_meta.owner_references_contains] (object_meta.ml:72-75), i.e. FULL
   [Owner_reference.equal] (owner_reference.ml:26-33 - controller,
   block_owner_deletion, kind, name AND uid), so this pod is dropped exactly
   like the uid-99 one. A uid-ONLY integrity check would call this seed intact:
   the probe that keeps the predicate's owner conjunct honest. *)
let misnamed_owner_seed : Cluster.cluster_state =
  doctor_owner_refs surplus_ref
    (List.map (fun (r : Owner_reference.t) ->
         { r with Owner_reference.name = parent ^ "-other" }))
    base_seed

(* A seed whose ordinals ALSO include 0 - i.e. a pod at an ordinal BELOW
   [desired]. It is present, canonically named and correctly owned; it is simply
   NEEDED rather than condemned ([partition_pods] condemns [ord >= replicas]
   only, v_stateful_set_reconciler.ml:412), so requesting it as a surplus
   ordinal is the [< desired] half of the builder's precondition and yields the
   same G2-vacuous-but-CLEAN leg. Not a doctored state: a plain
   MIS-PARAMETERISED call, which is finding F3's own failure shape. *)
let ordinal_zero_seed : Cluster.cluster_state =
  Scenario.vsts_seed_with_pods ~desired ~ordinals:[ 0; 1 ] ~crash:true
    ~req_drop:false ~pod_monkey:false ()

(* ---- the obligation, through the exported predicate ---------------------- *)

let test_seed_integrity () =
  (* THE OBLIGATION, in one total call: presence at the canonical ref,
     exactly one owner ref, owner uid = the LIVE CR's stamped uid, the
     get_ordinal round-trip, and distinct ordinals - the full set of
     conjuncts pod_filter needs before an ord >= desired pod can be
     condemned. A false here means the leg below is G2-vacuous AND still
     reports CLEAN (the union gate is dominated by G1). *)
  Alcotest.(check bool)
    "SHIPPED INSTANTIATION (~desired:1 ~ordinals:[1]): \
     Scenario.vsts_seed_pods_intact holds on the seed - the G2-liveness \
     precondition of check_scale_down_under_faults, ASSERTED not assumed"
    true
    (Scenario.vsts_seed_pods_intact base_seed ~ordinals);
  (* the same obligation on ALL FOUR legs' seeds (they differ only in fault
     flags, but nothing in the type system says so - so it is measured). *)
  Alcotest.(check bool)
    "every leg seed is intact, not just the zero-budget one (SL0 and SLc \
     share one seed value, SLd and SLm add their own toggle)"
    true
    (List.for_all
       (fun ((req_drop, pod_monkey) : bool * bool) ->
         Scenario.vsts_seed_pods_intact (seed_of ~req_drop ~pod_monkey)
           ~ordinals)
       [ (false, false); (true, false); (false, true) ]);
  (* ---- per-conjunct diagnostics: WHERE a false above would come from ---- *)
  Alcotest.(check bool)
    "the surplus pod is PRESENT at its ref post-seed (a real \
     handle_create_request landed it in etcd)"
    true
    (Option.is_some (stored_at surplus_ref base_seed));
  (* the LIVE CR's server-stamped uid, read off the seed - the value the
     owner ref must carry (a mismatch makes the pod GC-orphaned and
     reproduces the G2 vacuity; MS3 below measures exactly that). *)
  Alcotest.(check (option int))
    "the live CR at vsts_ref carries the server-stamped uid 1" (Some 1)
    (Option.bind (stored_at Scenario.vsts_ref base_seed)
       (fun (obj : Dynamic_object.t) ->
         Option.map Common.Uid.to_int
           (Dynamic_object.metadata obj).Object_meta.uid));
  Alcotest.(check (list int))
    "the surplus pod carries EXACTLY ONE owner ref, uid = the live CR's 1"
    [ 1 ]
    (Option.fold (stored_at surplus_ref base_seed) ~none:[] ~some:owner_uids);
  Alcotest.(check (option int))
    "the name round-trips through the reconciler's ordinal parse \
     (get_ordinal - the pod_filter admission conjunct)"
    (Some 1)
    (Vsr.get_ordinal parent surplus_name);
  (* brittle literal LAST (test-ordering rule): the pod name is now DERIVED
     from the live CR's own metadata name, so this pins the derivation's
     value without the builder carrying the literal. *)
  Alcotest.(check string)
    "the surplus pod's name is the committed literal (pod_name parent 1)"
    "vstatefulset-vsts1-1" surplus_name

(* ---- RED CAPABILITY: the predicate must be SEEN to reject ----------------
   A predicate that only ever returns true is not evidence (confirm-by-
   mutation, applied to the checker itself). SIX DISTINCT falsifications,
   each the shape of a real mis-seeding, all discriminated against the same
   green base_seed asserted above:

     1. an ordinal that was never seeded (the residue of a create that
        silently failed) - pod ABSENT;
     2. the owner uid doctored to 99 - present, exactly one ref, name
        round-trips, but GC-orphaned and invisible to pod_filter (this is
        MS3's state, whose G2 = 0 is measured below);
     3. the owner-ref list emptied - the old builder's [~none:[]] collapse,
        which pod_filter also drops;
     4. a REPEATED ordinal - the Object_already_exists no-op path: every
        per-pod conjunct still passes, yet the caller asked for two surplus
        pods and got one;
     5. an ordinal BELOW desired - present and correctly owned, but NEEDED
        rather than condemned (partition_pods :412), so G2 still never fires;
        a plain mis-parameterised call, no doctoring;
     6. an owner ref carrying the RIGHT uid under the WRONG parent name -
        pod_filter admits by full [Owner_reference.equal], not by uid, so a
        uid-only integrity check would wave this through.

   Each of 1-6 is the G2-vacuous-but-CLEAN leg. The predicate is the only
   thing standing between them and a green verdict. *)

let test_seed_integrity_red () =
  Alcotest.(check bool)
    "CONTROL: the good seed is intact at the shipped ordinals (the \
     discriminator - if this ever goes false the six reds below are \
     meaningless)"
    true
    (Scenario.vsts_seed_pods_intact base_seed ~ordinals);
  Alcotest.(check bool)
    "RED 1/6: an ordinal that was never seeded (2) - pod ABSENT at its \
     canonical ref, so the predicate REJECTS"
    false
    (Scenario.vsts_seed_pods_intact base_seed ~ordinals:[ 2 ]);
  (* the doctoring LANDED (control of the control) before it is used *)
  Alcotest.(check (list int))
    "RED 2/6 setup: the doctored pod carries exactly one owner ref, uid 99"
    [ 99 ]
    (Option.fold (stored_at surplus_ref uid99_seed) ~none:[] ~some:owner_uids);
  Alcotest.(check bool)
    "RED 2/6: owner uid 99 <> the live CR's stamped uid - GC-orphan shape, \
     pod_filter drops it, condemned = [], so the predicate REJECTS"
    false
    (Scenario.vsts_seed_pods_intact uid99_seed ~ordinals);
  Alcotest.(check (list int))
    "RED 3/6 setup: the doctored pod carries NO owner ref at all" []
    (Option.fold (stored_at surplus_ref unowned_seed) ~none:[] ~some:owner_uids);
  Alcotest.(check bool)
    "RED 3/6: owner_references = [] (the old builder's silent-degradation \
     shape) - not exactly one ref, so the predicate REJECTS"
    false
    (Scenario.vsts_seed_pods_intact unowned_seed ~ordinals);
  Alcotest.(check bool)
    "RED 4/6: a REPEATED ordinal [1; 1] - the second create is an \
     Object_already_exists no-op whose response the seed discards, so one \
     requested surplus pod silently does not exist: the predicate REJECTS"
    false
    (Scenario.vsts_seed_pods_intact base_seed ~ordinals:[ 1; 1 ]);
  (* the ordinal-0 seed's OWN control: at the shipped ordinals it is intact, so
     the red below isolates the ordinal conjunct and nothing else. *)
  Alcotest.(check bool)
    "RED 5/6 setup: the ordinal-0 seed is intact at the shipped ordinals - the \
     pod at 0 is present, canonically named and correctly owned; only its \
     ORDINAL is wrong"
    true
    (Scenario.vsts_seed_pods_intact ordinal_zero_seed ~ordinals);
  Alcotest.(check bool)
    "RED 5/6: ordinal 0 < desired 1 is NEEDED, never condemned \
     (partition_pods :412), so the leg would be G2-vacuous-but-CLEAN: the \
     predicate REJECTS a present, correctly-owned pod purely on its ordinal"
    false
    (Scenario.vsts_seed_pods_intact ordinal_zero_seed ~ordinals:[ 0 ]);
  Alcotest.(check bool)
    "RED 5/6 (the mis-parameterised call itself): ~ordinals:[0; 1] - the shape \
     a caller of check_scale_down_under_faults could pass unchecked"
    false
    (Scenario.vsts_seed_pods_intact ordinal_zero_seed ~ordinals:[ 0; 1 ]);
  (* the doctoring LANDED, and landed WEAKLY: uid still the live CR's 1 *)
  Alcotest.(check (list int))
    "RED 6/6 setup: the misnamed-owner pod still carries exactly one owner \
     ref whose uid is the live CR's 1 - only the ref's NAME is wrong"
    [ 1 ]
    (Option.fold
       (stored_at surplus_ref misnamed_owner_seed)
       ~none:[] ~some:owner_uids);
  Alcotest.(check bool)
    "RED 6/6: owner ref name <> the CR's name - pod_filter admits by FULL \
     Owner_reference.equal (object_meta.ml:72-75), not by uid alone, so the \
     predicate REJECTS what a uid-only check would pass"
    false
    (Scenario.vsts_seed_pods_intact misnamed_owner_seed ~ordinals)

(* ==== the four legs (SL0 FIRST - the MG5 zero-budget-first lesson) ========= *)

let test_sl0 () =
  check_green_leg "SL0" (Lazy.force sl0) (Lazy.force sl0_reach)
    ~states:P22_witness.sl0_states ~gate:P22_witness.sl0_gate_states
    ~g1:P22_witness.g1_interesting_sl0 ~g2:P22_witness.g2_interesting_sl0
    ~g3:P22_witness.g3_interesting_sl0 ~g4:P22_witness.g4_interesting_sl0

let test_slc () =
  check_green_leg "SLc" (Lazy.force slc) (Lazy.force slc_reach)
    ~states:P22_witness.slc_states ~gate:P22_witness.slc_gate_states
    ~g1:P22_witness.g1_interesting_slc ~g2:P22_witness.g2_interesting_slc
    ~g3:P22_witness.g3_interesting_slc ~g4:P22_witness.g4_interesting_slc

let test_sld () =
  check_green_leg "SLd" (Lazy.force sld) (Lazy.force sld_reach)
    ~states:P22_witness.sld_states ~gate:P22_witness.sld_gate_states
    ~g1:P22_witness.g1_interesting_sld ~g2:P22_witness.g2_interesting_sld
    ~g3:P22_witness.g3_interesting_sld ~g4:P22_witness.g4_interesting_sld

let test_slm () =
  check_green_leg "SLm" (Lazy.force slm) (Lazy.force slm_reach)
    ~states:P22_witness.slm_states ~gate:P22_witness.slm_gate_states
    ~g1:P22_witness.g1_interesting_slm ~g2:P22_witness.g2_interesting_slm
    ~g3:P22_witness.g3_interesting_slm ~g4:P22_witness.g4_interesting_slm

(* ==== MS3: the seed-sabotage control (spec section 5, in-test, no source
   edit) ======================================================================
   The good seed with the stored surplus pod's owner-ref uid rewritten to 99
   - a THROWAWAY doctored cluster_state, mirroring the builder's output
   byte-for-byte except the one uid. [pod_filter] (:421-432) drops the pod
   (the owner ref no longer matches the CR's), [condemned] = [], and the
   G2-live emission never happens: the phase gate CATCHES mis-seeding
   instead of greenlighting it. The expected 0 is the matrix row's PREDICTED
   verdict (spec section 5 MS3), committed in-test - not a witness pin.

   THE CONTROL RUNS AT A REDUCED DEPTH, and the reason is itself the row's
   graph-shape datum (spec section 5: "record whether GC contests the
   orphan, whatever is measured"). MEASURED at B4: the sabotaged pod is
   GC-ORPHANED, the contest is real, and the sabotaged zero-budget graph
   DIVERGES - roughly 4x states per 2 depth levels (197 / 861 / 3787 /
   16330 at depths 6 / 8 / 10 / 12, vs 20-44 for the good seed), still
   actively exploring after 9 minutes at the leg depth - the MG5
   blow-up CLASS (a pod the reconciler cannot see persisting in etcd),
   reached by seed sabotage instead of source mutation. So the shipped
   control is a SAME-DEPTH DISCRIMINATING PAIR at [ms3_depth]: identical
   bound / budget / depth, ONE uid changed - the good graph fires G2, the
   sabotaged graph does not. [ms3_depth] = 10 is the smallest depth at
   which the good seed's G2 fires (MEASURED, B4 probe); the good-side
   floor below reds LOUDLY if that horizon ever drifts. *)

let ms3_depth : int = 10

let ms3_reach_of (s : Cluster.cluster_state) : Fc.faulted Mc.reachable =
  Mc.explore ~depth:ms3_depth
    ~successors:(Fc.faulted_successors bound P22_witness.zero_budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed s ]

(* Byte-for-byte the state the red-capability test's RED 2/6 rejects
   ([doctor_owner_refs surplus_ref (map uid := 99) base_seed]): the predicate
   REJECTS it statically, and MS3 below MEASURES the consequence the
   prediction names - G2 fires nowhere in its graph. One doctored value, two
   independent witnesses. *)
let sabotaged_seed : Cluster.cluster_state = uid99_seed

let test_ms3_seed_sabotage () =
  (* the sabotage LANDED (control of the control): same ref, still exactly
     one owner ref, uid now 99 <> the live CR's 1. *)
  Alcotest.(check (list int))
    "MS3: the sabotaged pod carries exactly one owner ref, uid 99" [ 99 ]
    (Option.fold (stored_at surplus_ref sabotaged_seed) ~none:[]
       ~some:owner_uids);
  (* the discriminating pair, SAME depth / bound / budget: the good graph
     fires G2 at this horizon (the floor that keeps the pair honest) ... *)
  let good_reach : Fc.faulted Mc.reachable = ms3_reach_of base_seed in
  Alcotest.(check bool)
    "MS3 control-of-the-control: the GOOD seed's G2 fires at ms3_depth (the \
     pair discriminates; a red here means the horizon drifted, loudly)"
    true
    (fires good_reach g2_name > 0);
  (* ... and the sabotaged graph does not: the phase gate catches the
     mis-seed (pod_filter drops the pod, condemned = []) - the
     spec-section-5 MS3 predicted verdict. *)
  let reach : Fc.faulted Mc.reachable = ms3_reach_of sabotaged_seed in
  Alcotest.(check int)
    "MS3: G2 interesting = 0 on the sabotaged seed's zero-budget graph - \
     the exact silent-vacuity failure mode the seed-integrity test guards, \
     MEASURED caught"
    0 (fires reach g2_name);
  (* the same graph still fires the family somewhere (G1's create premise
     survives the sabotage), so the 0 above is G2-specific, not a dead
     graph. *)
  Alcotest.(check bool)
    "MS3: G1 premise still fires on the sabotaged graph (the 0 above is \
     G2-SPECIFIC, not exploration failure)"
    true
    (fires reach g1_name > 0)

let () =
  Alcotest.run "p22_scaledown"
    [
      ( "seed_integrity",
        [
          Alcotest.test_case
            "Scenario.vsts_seed_pods_intact holds on every leg seed at the \
             shipped ordinals (present, one owner ref = live CR uid, ordinal \
             round-trip, distinct ordinals)"
            `Quick test_seed_integrity;
          Alcotest.test_case
            "RED CAPABILITY: the predicate rejects an unseeded ordinal, an \
             owner uid of 99, an emptied owner-ref list, a repeated ordinal, \
             an ordinal below desired, and a right-uid/wrong-name owner ref"
            `Quick test_seed_integrity_red;
        ] );
      ( "legs",
        [
          Alcotest.test_case
            "SL0: zero-budget - GREEN, G2 LIVE (the phase gate)" `Quick
            test_sl0;
          Alcotest.test_case "SLc: crash-only - GREEN, G2 live" `Quick
            test_slc;
          Alcotest.test_case "SLd: drop-only - GREEN, G2 live" `Quick
            test_sld;
          Alcotest.test_case "SLm: monkey-only - GREEN, G2 live" `Quick
            test_slm;
        ] );
      ( "ms3_seed_sabotage",
        [
          Alcotest.test_case
            "owner uid 99 throwaway seed: G2 fires nowhere - the gate \
             catches mis-seeding (spec section 5 MS3)"
            `Quick test_ms3_seed_sabotage;
        ] );
    ]

(* BUILD-SPEC-P21 sections 3-4 and 8 - the internal-GUARANTEE measurement:
   {!Anvil_checker.Fault_check.check_internal_guarantee_under_faults} (the
   G1-G4 family of {!Anvil_assurance.Internal_guarantee.guarantee_family})
   over the four committed fault graphs, the replica-only L0v row, and the
   pvc-matcher behavioural-agreement corpus.

   WHAT THIS EXE ESTABLISHES.

   1. THE DUAL OF P20'S REGISTER, MEASURED GREEN. P20 measured that the
      port's pod monkey VIOLATES the rely condition it is assumed to respect
      (R1/R2 red 208/208 on Lm). This exe measures the other half: the
      port's own VSTS reconciler HONOURS the guarantee upstream proves it
      honours ([internal_guarantee_condition_holds],
      internal_rely_guarantee.rs:1003; [..._on_all_vsts], :1196). Every leg
      CLEAN and DECISIVE, red 0 on every member over every graph. The
      epistemic reading is the INVERSE of P20's leg: a red here would be a
      FIDELITY divergence in the port - the reconciler emitting a request
      upstream proves its reconciler never emits - and a real finding, not
      an environment datum.

   2. PIN SAFETY IS "NO NEW SEAM", AND IT IS MEASURED. The leg adds no
      [Bound.t] field, no [Cluster.cluster_state] field and threads no
      [?vct] (spec section 3), so all five committed graph pins
      (76 / 464 / 744 / 1976 / 116) must come back UNMOVED - re-asserted
      here through the local replicas. A moved pin is a phase-STOP.

   3. HONEST VACUITY, FAMILY-WIDE (P14 N5; spec prediction 4 REFUTED in
      both directions and recorded, not narrowed away). (a) G2
      ([get_then_delete]) is vacuous on ALL FIVE graphs - [interesting] = 0
      everywhere, ASSERTED below, never merely observed: at [desired = 1]
      with no scale-down the reconciler never reaches its delete steps
      (v_stateful_set_reconciler.ml:734/:779). G2's green is a vacuity row,
      not a pass; its live witness is a scale-down scenario, banked for P22.
      (b) G3 FIRES on the fault-free L0 (the rolling-update path emits
      [Get_then_update_request] with no fault involved), against the spec's
      "plausibly zero on L0" lean. Every OTHER member's premise is asserted
      NON-zero on every graph (G1/G3/G4 floors), and the family gate is
      asserted non-zero on every leg (prediction 3) - unlike P20, no leg
      here is a vacuity row at the family level, because the premise is
      CONTROLLER-sourced traffic and that exists without any adversary.

   4. L0v IS REPLICA-ONLY, and the reason is structural: the leg builds its
      seed internally with [vct] ABSENT and threads no [?vct], so the
      [vct:true] seed CANNOT reach it - exactly t_p20_rely's Leg-A shape
      (its L0v exists only as the pin-safety replica [l0v_reach]). The L0v
      case below asserts the graph pin and the per-member counts off a
      local replica; it asserts NO leg outcome and NO gate. t_p21_mutation's
      MG3 row is the measured justification that the fifth row earns its
      keep: a [make_pvc]-owner-ref mutant is INVISIBLE to all four legs and
      reds ONLY on this replica.

   5. THE PVC-MATCHER DUPLICATION, PINNED BEHAVIOURALLY.
      [internal_guarantee.ml:137] deliberately DUPLICATES P18's private
      [pvc_name_matches] (helper_invariants.ml:32-43; not exported, so it
      cannot be called), re-rendered with a guarded-total [sub_opt]. The
      corpus below drives BOTH copies through their modules' EXPORTED
      surfaces over a shared name corpus with COMMITTED verdicts - the P21
      copy through G1's PVC arm (an in-flight VSTS-sourced PVC create whose
      only varying field is the name), the P18 copy through H2's
      [interesting] (a stored PVC-kinded object at a key with that name) -
      so a later divergence of either copy from the other, or of both from
      the committed truth, reddens here rather than being silently
      tolerated.

   TEST-ORDERING RULE (P12 finding 1, P13-P20 precedent): every test asserts
   the SEMANTIC facts FIRST - outcome, [violated], decisive, replica
   faithfulness, floors - and only THEN the brittle exact counts.

   Every pinned number comes from {!P21_witness} (single source of truth);
   none is re-typed here. Graph-identity constants are read through the
   witness chain (P21 <- P20 <- P19 <- ... <- P13), never re-typed.

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
module Hi = Anvil_assurance.Helper_invariants
module Vsr = V_stateful_set_reconciler

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P21_witness.witness_desired
let depth : int = P21_witness.witness_depth
let bound : Bound.t = P21_witness.p21_bound ~desireds:[ desired ]
let cr : V_stateful_set.t = Scenario.vsts ~desired ()
let family : Invariants.invariant list = Ig.guarantee_family ~cr ~controller_id

(* P18's family, instantiated here only for the pvc-matcher corpus: H2's
   [interesting] is the exported surface P18's private matcher is probed
   through. *)
let helper_family : Invariants.invariant list =
  Hi.helper_family ~cr ~controller_id

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
   t_p20_rely's discipline: a missing name makes both projections constantly
   [false], which the family-shape test and every G1/G3/G4 floor below
   reddens LOUDLY before any count could quietly go 0. *)

let g1_name : string = "vsts_internal_guarantee_create_req"
let g2_name : string = "vsts_internal_guarantee_get_then_delete_req"
let g3_name : string = "vsts_internal_guarantee_get_then_update_req"
let g4_name : string = "no_interfering_request_between_vsts"

let h2_name : string =
  "all_pvcs_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_or_owner_ref"

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

(* ==== the leg runs (lazy: no test pays for an unused exploration) ========= *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget)
    ~(require_fault : bool) : Fc.fault_report =
  Fc.check_internal_guarantee_under_faults ~depth ~req_drop ~pod_monkey bound
    budget ~desired ~require_fault

let l0 : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false P21_witness.zero_budget
       ~require_fault:false)

let lc : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false P21_witness.lc_budget
       ~require_fault:true)

let ld : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:true ~pod_monkey:false P21_witness.ld_budget
       ~require_fault:true)

let lm : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:true P21_witness.lm_budget
       ~require_fault:true)

(* ==== LOCAL replicas of the legs' product graphs ===========================
   The per-member counts need the reachable set itself, which [fault_report]
   does not carry. Same seed / bound / budget / depth through the exported
   {!Fc.faulted_successors}; every consuming test asserts [Mc.states_seen]
   against the leg's own [states] FIRST (the P13 M3/M5 precedent - a drifted
   replica would silently measure a different graph). *)

let seed_of ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool) :
    Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ~vct ()

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed_of ~req_drop ~pod_monkey ~vct) ]

let l0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:false ~vct:false
       P21_witness.zero_budget)

let lc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:false ~vct:false P21_witness.lc_budget)

let ld_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:true ~pod_monkey:false ~vct:false P21_witness.ld_budget)

let lm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:true ~vct:false P21_witness.lm_budget)

(* The [vct:TRUE] zero-budget graph - REPLICA-ONLY (header point 4): the leg
   cannot reach it, so it appears here exactly as it does in t_p20_rely, as a
   pin-safety-plus-counts replica with no leg outcome and no gate. *)
let l0v_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:false ~vct:true
       P21_witness.zero_budget)

(* ---- counting projections over a replica --------------------------------- *)

let fires (reach : Fc.faulted Mc.reachable) (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      member_interesting family name f.cs)

let reds (reach : Fc.faulted Mc.reachable) (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      not (member_holds family name f.cs))

(* ---- the shared GREEN-leg assertion bundle --------------------------------
   Semantic facts first, exact pins last. The G2 row inside it is the honest
   vacuity assertion (header point 3a): its exact pin is 0 on every graph and
   the wording says what that 0 is. *)

let check_green_leg (label : string) (r : Fc.fault_report)
    (reach : Fc.faulted Mc.reachable) ~(states : int) ~(gate : int)
    ~(g1 : int) ~(g2 : int) ~(g3 : int) ~(g4 : int) : unit =
  Alcotest.(check bool)
    (label
   ^ ": outcome CLEAN - the guarantee HELD (a red here would be a FIDELITY \
      divergence in the port, the inverse of P20's reading)")
    true (is_clean r);
  Alcotest.(check string) (label ^ ": violated = None") "<none>"
    (violated_name r);
  Alcotest.(check bool) (label ^ ": decisive") true (decisive r);
  Alcotest.(check int)
    (label ^ ": replica explored the leg's exact graph (states_seen)")
    (states_of r) (Mc.states_seen reach);
  Alcotest.(check bool)
    (label ^ ": family gate > 0 - the NON-VACUITY FLOOR (prediction 3); \
              unlike P20, NO leg here is a vacuity row")
    true
    (gate_of r > 0);
  Alcotest.(check bool) (label ^ ": G1 premise fires somewhere") true
    (fires reach g1_name > 0);
  Alcotest.(check bool)
    (label ^ ": G3 premise fires somewhere (on L0 this is prediction 4(b)'s \
              refutation: the rolling-update path fires fault-free)")
    true
    (fires reach g3_name > 0);
  Alcotest.(check bool) (label ^ ": G4 premise fires somewhere") true
    (fires reach g4_name > 0);
  Alcotest.(check int)
    (label ^ ": G2 interesting = 0 - HONEST VACUITY, asserted not observed \
              (desired = 1, no scale-down: the delete steps :734/:779 are \
              unreached; a non-zero here is a REAL scenario change)")
    g2 (fires reach g2_name);
  (* exact MEASURED pins LAST *)
  Alcotest.(check int)
    (label ^ ": graph states (committed pin - the NO-NEW-SEAM property)")
    states (states_of r);
  Alcotest.(check int) (label ^ ": family gate") gate (gate_of r);
  Alcotest.(check int) (label ^ ": G1 interesting") g1 (fires reach g1_name);
  Alcotest.(check int) (label ^ ": G3 interesting") g3 (fires reach g3_name);
  Alcotest.(check int) (label ^ ": G4 interesting") g4 (fires reach g4_name);
  Alcotest.(check int) (label ^ ": G1 red")
    P21_witness.guarantee_red_everywhere (reds reach g1_name);
  Alcotest.(check int) (label ^ ": G2 red")
    P21_witness.guarantee_red_everywhere (reds reach g2_name);
  Alcotest.(check int) (label ^ ": G3 red")
    P21_witness.guarantee_red_everywhere (reds reach g3_name);
  Alcotest.(check int) (label ^ ": G4 red")
    P21_witness.guarantee_red_everywhere (reds reach g4_name)

(* ==== family shape ========================================================= *)

let test_family_shape () =
  Alcotest.(check (list string))
    "guarantee_family = the four upstream names, in member order G1..G4"
    [ g1_name; g2_name; g3_name; g4_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family);
  Alcotest.(check (list string))
    "member sources = guarantee_sources, same order (the .mli's exposed \
     literals)"
    Ig.guarantee_sources
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.source) family);
  Alcotest.(check int) "guarantee_family cardinal"
    P21_witness.guarantee_cardinal (List.length family);
  (* the corpus below addresses H2 by name; a rename would silently blind it,
     so the name is pinned here first (loud-on-missing). *)
  Alcotest.(check bool) "H2 is present in helper_family under its P18 name"
    true
    (List.exists
       (fun (i : Invariants.invariant) -> String.equal i.Invariants.name h2_name)
       helper_family)

(* ==== PIN SAFETY: the five committed graph pins, re-MEASURED =============== *)

let test_pin_safety () =
  (* L0 / Lc / Ld / Lm are also asserted inside their own leg tests; this is
     the one place all five are read together, including the [vct:true] L0v
     graph no P21 leg runs. A moved pin is a STOP, never a retune. *)
  Alcotest.(check int) "pin safety L0 = 76" P21_witness.l0_states
    (Mc.states_seen (Lazy.force l0_reach));
  Alcotest.(check int) "pin safety Lc = 464" P21_witness.lc_states
    (Mc.states_seen (Lazy.force lc_reach));
  Alcotest.(check int) "pin safety Ld = 744" P21_witness.ld_states
    (Mc.states_seen (Lazy.force ld_reach));
  Alcotest.(check int) "pin safety Lm = 1976" P21_witness.lm_states
    (Mc.states_seen (Lazy.force lm_reach));
  Alcotest.(check int) "pin safety L0v = 116 (vct:true, replica only)"
    P21_witness.l0v_states
    (Mc.states_seen (Lazy.force l0v_reach))

(* ==== the four legs ======================================================== *)

let test_l0 () =
  check_green_leg "L0" (Lazy.force l0) (Lazy.force l0_reach)
    ~states:P21_witness.l0_states ~gate:P21_witness.l0_gate_states
    ~g1:P21_witness.g1_interesting_l0 ~g2:P21_witness.g2_interesting_l0
    ~g3:P21_witness.g3_interesting_l0 ~g4:P21_witness.g4_interesting_l0

let test_lc () =
  check_green_leg "Lc" (Lazy.force lc) (Lazy.force lc_reach)
    ~states:P21_witness.lc_states ~gate:P21_witness.lc_gate_states
    ~g1:P21_witness.g1_interesting_lc ~g2:P21_witness.g2_interesting_lc
    ~g3:P21_witness.g3_interesting_lc ~g4:P21_witness.g4_interesting_lc

let test_ld () =
  check_green_leg "Ld" (Lazy.force ld) (Lazy.force ld_reach)
    ~states:P21_witness.ld_states ~gate:P21_witness.ld_gate_states
    ~g1:P21_witness.g1_interesting_ld ~g2:P21_witness.g2_interesting_ld
    ~g3:P21_witness.g3_interesting_ld ~g4:P21_witness.g4_interesting_ld

let test_lm () =
  check_green_leg "Lm" (Lazy.force lm) (Lazy.force lm_reach)
    ~states:P21_witness.lm_states ~gate:P21_witness.lm_gate_states
    ~g1:P21_witness.g1_interesting_lm ~g2:P21_witness.g2_interesting_lm
    ~g3:P21_witness.g3_interesting_lm ~g4:P21_witness.g4_interesting_lm

(* ==== L0v: the REPLICA-ONLY fifth row ====================================== *)

let test_l0v () =
  let reach = Lazy.force l0v_reach in
  (* NO leg outcome and NO gate are asserted here, because none exists: the
     leg threads no [?vct] and builds its seed internally with [vct] absent
     (fault_check.mli), so the [vct:true] seed cannot reach it. Graph pin
     first, then the per-member counts off the replica - and t_p21_mutation's
     MG3 row is why the row earns its keep (a make_pvc owner-ref mutant reds
     ONLY here). *)
  Alcotest.(check int)
    "L0v: replica states = the committed 116 (REPLICA-ONLY row: no leg \
     outcome, no gate)"
    P21_witness.l0v_states (Mc.states_seen reach);
  Alcotest.(check bool) "L0v: G1 premise fires somewhere" true
    (fires reach g1_name > 0);
  Alcotest.(check bool) "L0v: G3 premise fires somewhere" true
    (fires reach g3_name > 0);
  Alcotest.(check bool) "L0v: G4 premise fires somewhere" true
    (fires reach g4_name > 0);
  Alcotest.(check int)
    "L0v: G2 interesting = 0 - honest vacuity on the fifth graph too"
    P21_witness.g2_interesting_l0v (fires reach g2_name);
  Alcotest.(check int) "L0v: G1 interesting" P21_witness.g1_interesting_l0v
    (fires reach g1_name);
  Alcotest.(check int) "L0v: G3 interesting" P21_witness.g3_interesting_l0v
    (fires reach g3_name);
  Alcotest.(check int) "L0v: G4 interesting" P21_witness.g4_interesting_l0v
    (fires reach g4_name);
  Alcotest.(check int) "L0v: G1 red" P21_witness.guarantee_red_everywhere
    (reds reach g1_name);
  Alcotest.(check int) "L0v: G2 red" P21_witness.guarantee_red_everywhere
    (reds reach g2_name);
  Alcotest.(check int) "L0v: G3 red" P21_witness.guarantee_red_everywhere
    (reds reach g3_name);
  Alcotest.(check int) "L0v: G4 red" P21_witness.guarantee_red_everywhere
    (reds reach g4_name)

(* ==== G2's vacuity, gathered ===============================================
   The same five G2 pins the bundles assert, read TOGETHER in one place (the
   pin_safety precedent) so the family-wide claim - "G2 fires NOWHERE, not
   merely nowhere-we-looked" - is a single assertion a reviewer can point
   at. Consequence recorded at t_p21_mutation MG6: a mutant whose only red
   witness is a G2 premise is INERT on every committed graph; the register's
   live witness is a scale-down scenario, banked for P22. *)

let test_g2_vacuity () =
  let rows :
      (string * Fc.faulted Mc.reachable Lazy.t * int) list =
    [
      ("L0", l0_reach, P21_witness.g2_interesting_l0);
      ("Lc", lc_reach, P21_witness.g2_interesting_lc);
      ("Ld", ld_reach, P21_witness.g2_interesting_ld);
      ("Lm", lm_reach, P21_witness.g2_interesting_lm);
      ("L0v", l0v_reach, P21_witness.g2_interesting_l0v);
    ]
  in
  List.iter
    (fun ((label, reach, pin) : string * Fc.faulted Mc.reachable Lazy.t * int) ->
      Alcotest.(check int)
        (label ^ ": G2 interesting - vacuous on EVERY committed graph \
                  (prediction 4(a) refuted family-wide, disclosed)")
        pin
        (fires (Lazy.force reach) g2_name))
    rows

(* ==== the pvc-matcher behavioural-agreement corpus =========================
   (header point 5). Both copies are private; each is probed through its
   module's EXPORTED surface, over the same names, against COMMITTED
   verdicts:

   - P21 copy: G1's PVC arm. The state carries exactly one in-flight message
     - a VSTS-controller-sourced [Create_request] of a PVC-kinded object in
     the CR's namespace, no owner refs, no generate_name - so every conjunct
     of [guarantee_create_req]'s PVC arm except the name matcher is
     satisfied, and [G1.holds] IS the matcher's verdict on the name.
   - P18 copy: H2's [interesting]. The state stores exactly one extra object
     - PVC-kinded, harmless metadata - at a key carrying the name, and
     [H2.interesting] IS the matcher's verdict (H2's premise is [kind = PVC
     && pvc_name_matches parent key.name]; upstream has no namespace
     conjunct and P18 added none).

   The verdicts are COMMITTED per row, not merely compared: two copies that
   drifted together would still redden. Base-state controls prove both
   probes silent before injection, so every verdict is attributable to the
   injected name alone; the corpus is asserted DISCRIMINATING (both verdicts
   present), so the agreement cannot be vacuous. *)

let cr_md : Object_meta.t = V_stateful_set.metadata cr
let ns : string = Option.value ~default:"" (Object_meta.namespace cr_md)
let parent : string = Option.value ~default:"" (Object_meta.name cr_md)

(* The CR key the family's premise compares message sources against, rebuilt
   with the same [Option.value ~default:""] rendering internal_guarantee.ml
   documents ([cr_key_of] is private; the rendering is the .mli-disclosed
   one, so a drift there reddens the premise-fires controls below). *)
let cr_key : Common.object_ref =
  { Common.kind = V_stateful_set.kind; name = parent; namespace = ns }

let base_state : Cluster.cluster_state =
  seed_of ~req_drop:false ~pod_monkey:false ~vct:false

(* Payload base: the reconciler's REAL [make_pod] object (the t_p20_mutation
   discipline - spec/status are not test-local fictions), metadata replaced
   per corpus row, KIND-retagged to PVC via [Dynamic_object.make] (no PVC
   view module exists in this tree; the retag is how a PVC-kinded object is
   built at all, t_p20_mutation:438-448). *)
let base_pod : Pod.t = Vsr.make_pod cr 0

let pvc_obj (name : string) : Dynamic_object.t =
  let md : Object_meta.t = Pod.metadata base_pod in
  let o : Dynamic_object.t =
    Pod.marshal
      (Pod.with_metadata
         {
           md with
           Object_meta.name = Some name;
           generate_name = None;
           namespace = Some ns;
           owner_references = None;
         }
         base_pod)
  in
  Dynamic_object.make ~kind:Persistent_volume_claim.kind
    ~metadata:(Dynamic_object.metadata o)
    ~spec:(Dynamic_object.spec o)
    ~status:(Dynamic_object.status o)

(* P21 side: the injected VSTS-sourced PVC create. *)
let g1_state (name : string) : Cluster.cluster_state =
  {
    base_state with
    Cluster.network =
      {
        Network.in_flight =
          Message.Pool.singleton
            (Message.controller_req_msg controller_id cr_key
               (Message.Rpc_id.of_int 0)
               (Api_method.Create_request
                  { Api_method.namespace = ns; obj = pvc_obj name }));
      };
  }

(* P18 side: the stored PVC at a key carrying the name. *)
let h2_state (name : string) : Cluster.cluster_state =
  {
    base_state with
    Cluster.api_server =
      {
        base_state.Cluster.api_server with
        Api_server.resources =
          Object_ref_map.add
            { Common.kind = Persistent_volume_claim.kind; namespace = ns; name }
            (pvc_obj name)
            base_state.Cluster.api_server.Api_server.resources;
      };
  }

(* The corpus. [parent] is the CR's own name (read off the CR, never typed);
   "data" is the scenario's dash-free template literal, but nothing below
   depends on that - every name is built by concatenation. The rows cover
   both verdicts and every structural branch of the matcher: prefix test,
   first-dash split (the [dash_free] realisation), [get_ordinal]'s
   round-trip canonicality, and the empty template upstream's existential
   admits. *)
let corpus : (string * string * bool) list =
  [
    ("minted shape, ordinal 0", "vstatefulset-data-" ^ parent ^ "-0", true);
    ("minted shape, ordinal 1", "vstatefulset-data-" ^ parent ^ "-1", true);
    ( "empty template (upstream pvc_name \"\" vsts ord is a real name)",
      "vstatefulset--" ^ parent ^ "-0",
      true );
    ( "dashed template rejected by the FIRST-dash split (dash_free realised)",
      "vstatefulset-da-ta-" ^ parent ^ "-0",
      false );
    ("no post-template segment", "vstatefulset-data", false);
    ("bare prefix", "vstatefulset-", false);
    ("not vstatefulset-prefixed", "outsider-data-" ^ parent ^ "-0", false);
    ("wrong parent", "vstatefulset-data-x" ^ parent ^ "-0", false);
    ( "non-canonical ordinal (round-trip check)",
      "vstatefulset-data-" ^ parent ^ "-00",
      false );
    ("ordinal segment missing", "vstatefulset-data-" ^ parent, false);
  ]

let test_pvc_matcher_agreement () =
  (* controls FIRST: both probes silent on the base state. *)
  Alcotest.(check bool)
    "corpus control: no VSTS-sourced create in flight on the base seed" false
    (member_interesting family g1_name base_state);
  Alcotest.(check bool)
    "corpus control: no vsts-matching PVC stored on the base seed" false
    (member_interesting helper_family h2_name base_state);
  (* the corpus is DISCRIMINATING: both verdicts occur, so the agreement
     below is content, not vacuity. *)
  Alcotest.(check bool) "corpus contains an ACCEPTED name" true
    (List.exists (fun ((_, _, e) : string * string * bool) -> e) corpus);
  Alcotest.(check bool) "corpus contains a REJECTED name" true
    (List.exists (fun ((_, _, e) : string * string * bool) -> not e) corpus);
  List.iter
    (fun ((label, name, expected) : string * string * bool) ->
      let s = g1_state name in
      Alcotest.(check bool)
        (label ^ ": G1 premise fires (the injection really landed)")
        true
        (member_interesting family g1_name s);
      Alcotest.(check bool)
        (label ^ ": P21 copy, probed through G1's PVC arm")
        expected
        (member_holds family g1_name s);
      Alcotest.(check bool)
        (label ^ ": P18 copy, probed through H2's interesting")
        expected
        (member_interesting helper_family h2_name (h2_state name)))
    corpus

let () =
  Alcotest.run "p21_guarantee"
    [
      ( "family_shape",
        [
          Alcotest.test_case
            "guarantee_family = the four upstream names, sources, cardinal"
            `Quick test_family_shape;
        ] );
      ( "pin_safety",
        [
          Alcotest.test_case
            "the five committed graph pins survive the leg (NO NEW SEAM)"
            `Quick test_pin_safety;
        ] );
      ( "legs",
        [
          Alcotest.test_case "L0: zero-budget - GREEN, gate non-zero" `Quick
            test_l0;
          Alcotest.test_case "Lc: crash-only - GREEN, gate non-zero" `Quick
            test_lc;
          Alcotest.test_case "Ld: drop-only - GREEN, gate non-zero" `Quick
            test_ld;
          Alcotest.test_case "Lm: monkey-only - GREEN, gate non-zero" `Quick
            test_lm;
          Alcotest.test_case
            "L0v: vct:true REPLICA-ONLY row (no leg outcome, no gate)" `Quick
            test_l0v;
        ] );
      ( "honest_vacuity",
        [
          Alcotest.test_case
            "G2 interesting = 0 on ALL FIVE graphs (prediction 4(a) refuted \
             family-wide)"
            `Quick test_g2_vacuity;
        ] );
      ( "pvc_matcher_agreement",
        [
          Alcotest.test_case
            "the two private pvc_name_matches copies agree on a committed \
             corpus, probed through exported surfaces"
            `Quick test_pvc_matcher_agreement;
        ] );
    ]

(* BUILD-SPEC-P19 section 4 - the message-provenance matrix: the four legs
   (L0 / Lc / Ld / Lm, no vct dimension - the k6-class cut, spec section
   8.2) of {!Anvil_checker.Fault_check.check_msg_provenance_under_faults},
   the family asserted ALONE, their gates, per-member [interesting] counts,
   the EDGE-TAKEN assertions, AND the ORPHAN-REPLICA floor (spec section 4):
   M3's non-vacuity on the generic/vrs spine plus M1's LIVE RED CONTROL.

   WHAT THIS EXE ESTABLISHES.

   1. THE FIRST DEDICATED MEASUREMENT of the four provenance members (M1
      helper_invariants.rs:1213, M2/M3/M4 network.rs:570/:618/:540) - the
      P14-P16/P18 DISJOINT-family pattern: no member shares a NAME or a
      SOURCE with any shipped suite (t_p19_regression pins the
      (name, source) disjointness), so these legs are the members' first
      assertion site UNDER THESE CITATIONS. That sweep is SYNTACTIC, so it
      does not claim the members' SUBSTANCE is unasserted elsewhere -
      shipped [inv7] [garbage_collector_does_not_delete_vrs_pods]
      (invariants.ml:527-546) already constrains M3's premise class, the
      overlap disclosed in [msg_provenance.mli]'s M3 block.

   2. HONEST VACUITY, TWO MEMBERS (the P14 N5 discipline): M3's premise
      (a builtin-GC-sourced message) fires on NO vsts-spine graph - the
      seeded CR is never deleted and vsts pods carry live owner refs - so
      its per-member count 0 IS the result on all four legs, asserted per
      leg; its strictly positive floor lives on the ORPHAN REPLICA below
      (spec section 5 prediction 3). M2's premise fires ONLY under a
      monkey budget (prediction 4): 0/0/0 on L0/Lc/Ld, positive on Lm.

   3. THE LIVE RED CONTROL (prediction 6): M1 is MODEL-CONDITIONAL
      (upstream's lemma premises the vsts controller model at the id,
      helper_invariants.rs:1231) - on the vrs spine the SAME controller id
      0 stamps vrs-kind keys, so M1 asserted ALONE over the orphan replica
      must land [Refuted] naming M1: the member's red capability witnessed
      on a REAL graph, forge-free, while M2/M3/M4 stay green there.

   4. THE UNION GATE IS LOAD-BEARING (non-saturating on L0/Lc/Ld): the
      seed's in-flight pool is EMPTY, so no member's premise fires there
      and the gate is a PROPER subset of every graph except Lm's
      post-monkey slice (where the UNION - no single member - covers all
      1824 slice states, p19_witness note).

   TEST-ORDERING RULE (P12 finding 1, P13-P18 precedent): every test
   asserts the SEMANTIC facts FIRST - outcome clean, [violated = None],
   decisive, EDGE-TAKEN where the claim needs one, replica faithfulness -
   and only THEN the brittle exact counts.

   Every pinned number comes from {!P19_witness} (single source of truth);
   none is re-typed here. Graph-identity constants (states, slices, maxima)
   are read from the witness chain (P19 <- P18 <- P17/P16 <- P15/P13),
   never re-typed.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum (both [Mc.outcome] arms), no
   two-arm match on [option]/[result] (stdlib [Option.fold]/[Option.bind]),
   Alcotest as the sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Cc = Anvil_checker.Cluster_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Mp = Anvil_assurance.Msg_provenance

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P19_witness.witness_desired
let depth : int = P19_witness.witness_depth
let bound : Bound.t = P19_witness.p19_bound ~desireds:[ desired ]

(* The family is CR-AGNOSTIC (spec section 2): M1 consumes [controller_id]
   alone; M2-M4 are cluster-level. No [~cr] is threaded - unclaimed
   strength, the P18 residual-1 discipline. *)
let family : Invariants.invariant list = Mp.provenance_family ~controller_id

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) ------- *)

let decisive (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let is_clean (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

let states_of (r : Fc.fault_report) : int =
  match r.outcome with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let gate_of (r : Fc.fault_report) : int = Option.value r.gate_states ~default:(-1)

let violated_name (r : Fc.fault_report) : string =
  Option.fold r.violated ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ==== the four members, addressed BY NAME off the family ==================
   A missing name makes [member_interesting] constantly [false] and
   [member_holds] constantly [false], which the family-shape test below
   (and every holds-everywhere check) reddens LOUDLY before any count could
   quietly go 0. *)

let m1_name : string = "every_msg_from_vsts_controller_carries_vsts_key"
let m2_name : string = "all_requests_from_pod_monkey_are_api_pod_requests"

let m3_name : string =
  "all_requests_from_builtin_controllers_are_api_delete_requests"

let m4_name : string =
  "no_pending_request_to_api_server_from_api_server_or_external"

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

(* ==== the four leg runs (lazy: no test pays for an unused exploration) ==== *)

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

(* ==== LOCAL replicas of the legs' product graphs ===========================
   The per-member counts and the recomputed union gates need the reachable
   set itself, which [fault_report] does not carry. Same seed / bound /
   budget / depth through the exported {!Fc.faulted_successors}; every
   consuming test asserts [Mc.states_seen] against the leg's [states] FIRST
   (the P13 M3/M5 precedent - a drifted replica would silently measure a
   different graph). *)

let seed ~(req_drop : bool) ~(pod_monkey : bool) : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ()

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget) :
    Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed ~req_drop ~pod_monkey) ]

let l0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:false P19_witness.zero_budget)

let lc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false P19_witness.lc_budget)

let ld_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:true ~pod_monkey:false P19_witness.ld_budget)

let lm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:true P19_witness.lm_budget)

(* ---- slices of a product graph ------------------------------------------- *)

let all_states (_ : Fc.faulted) : bool = true
let post_crash (f : Fc.faulted) : bool = f.crashes >= 1
let post_drop (f : Fc.faulted) : bool = f.drops >= 1
let post_monkey (f : Fc.faulted) : bool = f.monkeys >= 1

(* [interesting]-fires count for ONE member over a slice. *)
let fires (reach : Fc.faulted Mc.reachable) ~(slice : Fc.faulted -> bool)
    (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f && member_interesting name f.cs)

(* The union gate the leg computes, recomputed locally over the slice the
   leg's [require_fault] selects (its budget's own dimension). *)
let union_gate (reach : Fc.faulted Mc.reachable)
    ~(slice : Fc.faulted -> bool) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f
      && List.exists
           (fun (i : Invariants.invariant) -> i.Invariants.interesting f.cs)
           family)

(* ---- shared assertion bundles -------------------------------------------- *)

let check_leg_semantics (label : string) (r : Fc.fault_report) : unit =
  Alcotest.(check bool) (label ^ ": outcome clean") true (is_clean r);
  Alcotest.(check string)
    (label ^ ": violated = None")
    "<none>" (violated_name r);
  Alcotest.(check bool) (label ^ ": decisive") true (decisive r)

let check_replica_faithful (label : string)
    (reach : Fc.faulted Mc.reachable) (r : Fc.fault_report) : unit =
  Alcotest.(check int)
    (label ^ ": replica explored the leg's exact graph (states_seen)")
    (states_of r) (Mc.states_seen reach)

(* ==== family shape ========================================================= *)

let test_family_shape () =
  Alcotest.(check (list string))
    "provenance_family = the four upstream names, in member order M1-M4"
    [ m1_name; m2_name; m3_name; m4_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family)

(* ==== L0: zero-budget control ============================================= *)

let test_l0 () =
  let r = Lazy.force l0 in
  let reach = Lazy.force l0_reach in
  check_leg_semantics "L0" r;
  Alcotest.(check int) "L0: max_crashes_seen = 0" 0 r.max_crashes_seen;
  Alcotest.(check int) "L0: max_drops_seen = 0" 0 r.max_drops_seen;
  Alcotest.(check int) "L0: max_monkeys_seen = 0" 0 r.max_monkeys_seen;
  check_replica_faithful "L0" reach r;
  (* SEMANTIC non-vacuity first (spec section 5 prediction 5): M1 and M4
     fire somewhere; M2/M3's 0s are the honest-vacuity RESULT (N5,
     predictions 3-4), pinned below, never a silent absence. *)
  Alcotest.(check bool) "L0: M1 interesting fires (> 0)" true
    (fires reach ~slice:all_states m1_name > 0);
  Alcotest.(check bool) "L0: M4 interesting fires (> 0)" true
    (fires reach ~slice:all_states m4_name > 0);
  (* No member fires at the seed (EMPTY in-flight pool), so the union gate
     is a PROPER subset of the states: load-bearing, not saturated. *)
  Alcotest.(check bool) "L0: gate < states (union gate NON-saturating)" true
    (gate_of r < states_of r);
  Alcotest.(check int) "L0: recomputed all-states union gate = gate_states"
    (gate_of r)
    (union_gate reach ~slice:all_states);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L0: states (= P13 G1 fault-free slice, derived)"
    P19_witness.l0_states (states_of r);
  Alcotest.(check int) "L0: gate_states (pinned)" P19_witness.l0_gate_states
    (gate_of r);
  Alcotest.(check int) "L0: crash_witness_states = 0" 0 r.crash_witness_states;
  Alcotest.(check int) "L0: fault_free_states = states"
    P19_witness.l0_states r.fault_free_states;
  Alcotest.(check int) "L0: max_uid_seen (graph identity with P16 L0)"
    P16_witness.l0_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "L0: max_rv_seen (graph identity with P16 L0)"
    P16_witness.l0_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "L0: M1 interesting count (pinned)"
    P19_witness.m1_interesting_l0
    (fires reach ~slice:all_states m1_name);
  Alcotest.(check int) "L0: M2 interesting count (pinned honest vacuity, N5)"
    P19_witness.m2_interesting_l0
    (fires reach ~slice:all_states m2_name);
  Alcotest.(check int) "L0: M3 interesting count (pinned honest vacuity, N5)"
    P19_witness.m3_interesting_l0
    (fires reach ~slice:all_states m3_name);
  Alcotest.(check int) "L0: M4 interesting count (pinned)"
    P19_witness.m4_interesting_l0
    (fires reach ~slice:all_states m4_name)

(* ==== Lc: crash-only {1;0;0} ============================================== *)

let test_lc () =
  let r = Lazy.force lc in
  let reach = Lazy.force lc_reach in
  check_leg_semantics "Lc" r;
  (* EDGE-TAKEN first: the clean verdict is judged across a REAL crash. *)
  Alcotest.(check bool) "Lc: max_crashes_seen >= 1 (crash edge REALLY taken)"
    true
    (r.max_crashes_seen >= 1);
  Alcotest.(check int) "Lc: max_drops_seen = 0" 0 r.max_drops_seen;
  Alcotest.(check int) "Lc: max_monkeys_seen = 0" 0 r.max_monkeys_seen;
  check_replica_faithful "Lc" reach r;
  Alcotest.(check bool) "Lc: M1 interesting fires (> 0)" true
    (fires reach ~slice:all_states m1_name > 0);
  Alcotest.(check bool) "Lc: M4 interesting fires (> 0)" true
    (fires reach ~slice:all_states m4_name > 0);
  Alcotest.(check bool) "Lc: post-crash gate > 0" true (gate_of r > 0);
  Alcotest.(check int) "Lc: recomputed post-crash union gate = gate_states"
    (gate_of r)
    (union_gate reach ~slice:post_crash);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Lc: states (= P13 G1 graph, derived)"
    P19_witness.lc_states (states_of r);
  Alcotest.(check int) "Lc: gate_states (pinned, post-crash union)"
    P19_witness.lc_gate_states (gate_of r);
  Alcotest.(check int) "Lc: crash_witness_states (derived)"
    P19_witness.lc_crash_witness_states r.crash_witness_states;
  Alcotest.(check int) "Lc: fault_free_states (derived)"
    P19_witness.lc_fault_free_states r.fault_free_states;
  Alcotest.(check int) "Lc: max_uid_seen (graph identity with P16 Lc)"
    P16_witness.lc_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Lc: max_rv_seen (graph identity with P16 Lc)"
    P16_witness.lc_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "Lc: M1 interesting count (pinned)"
    P19_witness.m1_interesting_lc
    (fires reach ~slice:all_states m1_name);
  Alcotest.(check int) "Lc: M1 post-crash count (pinned)"
    P19_witness.m1_interesting_lc_post_crash
    (fires reach ~slice:post_crash m1_name);
  Alcotest.(check int) "Lc: M2 interesting count (pinned honest vacuity, N5)"
    P19_witness.m2_interesting_lc
    (fires reach ~slice:all_states m2_name);
  Alcotest.(check int) "Lc: M2 post-crash count (pinned honest vacuity)"
    P19_witness.m2_interesting_lc_post_crash
    (fires reach ~slice:post_crash m2_name);
  Alcotest.(check int) "Lc: M3 interesting count (pinned honest vacuity, N5)"
    P19_witness.m3_interesting_lc
    (fires reach ~slice:all_states m3_name);
  Alcotest.(check int) "Lc: M3 post-crash count (pinned honest vacuity)"
    P19_witness.m3_interesting_lc_post_crash
    (fires reach ~slice:post_crash m3_name);
  Alcotest.(check int) "Lc: M4 interesting count (pinned)"
    P19_witness.m4_interesting_lc
    (fires reach ~slice:all_states m4_name);
  Alcotest.(check int) "Lc: M4 post-crash count (pinned)"
    P19_witness.m4_interesting_lc_post_crash
    (fires reach ~slice:post_crash m4_name)

(* ==== Ld: drop-only {0;1;0} =============================================== *)

let test_ld () =
  let r = Lazy.force ld in
  let reach = Lazy.force ld_reach in
  check_leg_semantics "Ld" r;
  (* EDGE-TAKEN first. *)
  Alcotest.(check bool) "Ld: max_drops_seen >= 1 (drop edge REALLY taken)"
    true
    (r.max_drops_seen >= 1);
  Alcotest.(check int) "Ld: max_crashes_seen = 0" 0 r.max_crashes_seen;
  Alcotest.(check int) "Ld: max_monkeys_seen = 0" 0 r.max_monkeys_seen;
  Alcotest.(check int) "Ld: crash_witness_states = 0" 0 r.crash_witness_states;
  check_replica_faithful "Ld" reach r;
  Alcotest.(check bool) "Ld: M1 interesting fires (> 0)" true
    (fires reach ~slice:all_states m1_name > 0);
  Alcotest.(check bool) "Ld: M4 interesting fires (> 0)" true
    (fires reach ~slice:all_states m4_name > 0);
  Alcotest.(check bool) "Ld: post-drop gate > 0" true (gate_of r > 0);
  Alcotest.(check int) "Ld: recomputed post-drop union gate = gate_states"
    (gate_of r)
    (union_gate reach ~slice:post_drop);
  (* The drop edge never touches the store, so the maxima are L0's exact
     values - asserted against L0's committed constants (the P17-review
     hardening), then pinned against Ld's own. *)
  Alcotest.(check int) "Ld: max_uid_seen = L0's (store content untouched)"
    P16_witness.l0_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Ld: max_rv_seen = L0's (store content untouched)"
    P16_witness.l0_max_rv_seen r.max_rv_seen;
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Ld: states (= P15 L2x graph, derived)"
    P19_witness.ld_states (states_of r);
  Alcotest.(check int) "Ld: gate_states (pinned, post-drop union)"
    P19_witness.ld_gate_states (gate_of r);
  Alcotest.(check int) "Ld: fault_free_states (derived)"
    P19_witness.ld_fault_free_states r.fault_free_states;
  Alcotest.(check int) "Ld: max_uid_seen (graph identity with P16 Ld)"
    P16_witness.ld_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Ld: max_rv_seen (graph identity with P16 Ld)"
    P16_witness.ld_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "Ld: M1 interesting count (pinned)"
    P19_witness.m1_interesting_ld
    (fires reach ~slice:all_states m1_name);
  Alcotest.(check int) "Ld: M1 post-drop count (pinned)"
    P19_witness.m1_interesting_ld_post_drop
    (fires reach ~slice:post_drop m1_name);
  Alcotest.(check int) "Ld: M2 interesting count (pinned honest vacuity, N5)"
    P19_witness.m2_interesting_ld
    (fires reach ~slice:all_states m2_name);
  Alcotest.(check int) "Ld: M2 post-drop count (pinned honest vacuity)"
    P19_witness.m2_interesting_ld_post_drop
    (fires reach ~slice:post_drop m2_name);
  Alcotest.(check int) "Ld: M3 interesting count (pinned honest vacuity, N5)"
    P19_witness.m3_interesting_ld
    (fires reach ~slice:all_states m3_name);
  Alcotest.(check int) "Ld: M3 post-drop count (pinned honest vacuity)"
    P19_witness.m3_interesting_ld_post_drop
    (fires reach ~slice:post_drop m3_name);
  Alcotest.(check int) "Ld: M4 interesting count (pinned)"
    P19_witness.m4_interesting_ld
    (fires reach ~slice:all_states m4_name);
  Alcotest.(check int) "Ld: M4 post-drop count (pinned)"
    P19_witness.m4_interesting_ld_post_drop
    (fires reach ~slice:post_drop m4_name)

(* ==== Lm: monkey-only {0;0;1} - M2's only live leg (prediction 4) ========= *)

let test_lm () =
  let r = Lazy.force lm in
  let reach = Lazy.force lm_reach in
  check_leg_semantics "Lm" r;
  (* EDGE-TAKEN first. *)
  Alcotest.(check bool)
    "Lm: max_monkeys_seen >= 1 (monkey edge REALLY taken)" true
    (r.max_monkeys_seen >= 1);
  Alcotest.(check int) "Lm: max_crashes_seen = 0" 0 r.max_crashes_seen;
  Alcotest.(check int) "Lm: max_drops_seen = 0" 0 r.max_drops_seen;
  Alcotest.(check int) "Lm: crash_witness_states = 0" 0 r.crash_witness_states;
  check_replica_faithful "Lm" reach r;
  (* SEMANTIC non-vacuity: M2's ONLY live leg (prediction 4) - a
     monkey-sourced message really enters the pool, and the family stays
     clean across all of them. *)
  Alcotest.(check bool) "Lm: M2 interesting fires (> 0) - THE M2 FLOOR" true
    (fires reach ~slice:all_states m2_name > 0);
  Alcotest.(check bool) "Lm: M1 interesting fires (> 0)" true
    (fires reach ~slice:all_states m1_name > 0);
  Alcotest.(check bool) "Lm: M4 interesting fires (> 0)" true
    (fires reach ~slice:all_states m4_name > 0);
  Alcotest.(check bool) "Lm: post-monkey gate > 0" true (gate_of r > 0);
  Alcotest.(check int) "Lm: recomputed post-monkey union gate = gate_states"
    (gate_of r)
    (union_gate reach ~slice:post_monkey);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Lm: states (= P15 L3x graph, derived)"
    P19_witness.lm_states (states_of r);
  Alcotest.(check int) "Lm: gate_states (pinned, post-monkey union)"
    P19_witness.lm_gate_states (gate_of r);
  Alcotest.(check int) "Lm: fault_free_states (derived)"
    P19_witness.lm_fault_free_states r.fault_free_states;
  Alcotest.(check int) "Lm: max_uid_seen (graph identity with P16 Lm)"
    P16_witness.lm_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Lm: max_rv_seen (graph identity with P16 Lm)"
    P16_witness.lm_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "Lm: M1 interesting count (pinned)"
    P19_witness.m1_interesting_lm
    (fires reach ~slice:all_states m1_name);
  Alcotest.(check int) "Lm: M1 post-monkey count (pinned)"
    P19_witness.m1_interesting_lm_post_monkey
    (fires reach ~slice:post_monkey m1_name);
  Alcotest.(check int) "Lm: M2 interesting count (pinned - the M2 floor)"
    P19_witness.m2_interesting_lm
    (fires reach ~slice:all_states m2_name);
  Alcotest.(check int)
    "Lm: M2 post-monkey count (pinned; = all-states - every monkey message \
     is post-monkey)"
    P19_witness.m2_interesting_lm_post_monkey
    (fires reach ~slice:post_monkey m2_name);
  Alcotest.(check int) "Lm: M3 interesting count (pinned honest vacuity, N5)"
    P19_witness.m3_interesting_lm
    (fires reach ~slice:all_states m3_name);
  Alcotest.(check int) "Lm: M3 post-monkey count (pinned honest vacuity)"
    P19_witness.m3_interesting_lm_post_monkey
    (fires reach ~slice:post_monkey m3_name);
  Alcotest.(check int) "Lm: M4 interesting count (pinned)"
    P19_witness.m4_interesting_lm
    (fires reach ~slice:all_states m4_name);
  Alcotest.(check int) "Lm: M4 post-monkey count (pinned)"
    P19_witness.m4_interesting_lm_post_monkey
    (fires reach ~slice:post_monkey m4_name)

(* ==== The ORPHAN REPLICA (spec section 4): M3's floor + M1's red control ==
   Generic/vrs spine from [Scenario.seed_with_orphan ~desired:1 ~fair:false]
   under plain productive successors at [Bound.default], DEPTH-LIMITED at
   depth 4 (disclosed in p19_witness: BFS exhaustion is intractable on this
   spine - 43 states at depth 2, 1518 at depth 4 - and depth 2 would leave
   the M1 control VACUOUSLY green, its premise firing nowhere). NOT a leg:
   no fault product, no budget - the GC fires here on its own. *)

let orphan_reach : Cluster.cluster_state Mc.reachable Lazy.t =
  lazy
    (Mc.explore ~depth:P19_witness.orphan_depth
       ~successors:(fun s ->
         List.map snd
           (Scenario.productive_successors Scenario.cluster Bound.default s))
       ~equal:Cc.state_equal ~hash:Cc.state_hash
       ~init:
         [ Scenario.seed_with_orphan ~desired:P19_witness.orphan_desired
             ~fair:false ])

(* M1 ALONE - the model-conditional member as a CONTROL, never an
   invariant claim on this spine (msg_provenance.mli, spec section 8.5). *)
let m1_only : Invariants.invariant list =
  List.filter
    (fun (i : Invariants.invariant) -> String.equal i.Invariants.name m1_name)
    family

let test_orphan () =
  let reach = Lazy.force orphan_reach in
  let cnt (name : string) : int =
    Mc.count_states_where reach (member_interesting name)
  in
  let violations (name : string) : int =
    Mc.count_states_where reach (fun s -> not (member_holds name s))
  in
  (* Shape guards first: M1 addressed by name really is ONE member, and the
     replica is the depth-limited graph the witness discloses. *)
  Alcotest.(check int) "orphan: m1_only is exactly one member" 1
    (List.length m1_only);
  Alcotest.(check bool)
    "orphan: frontier NOT emptied (depth-limited replica, disclosed)" false
    (Mc.frontier_emptied reach);
  (* SEMANTIC facts first. (a) THE FLOOR (spec section 5 prediction 3): a
     builtin-GC-sourced message is REALLY in flight on this spine. *)
  Alcotest.(check bool) "orphan: M3 interesting fires (>= 1) - THE FLOOR"
    true
    (cnt m3_name > 0);
  (* (b) + (c): the three cluster-level members hold at EVERY reached
     state (M2 across a LIVE monkey's emissions - the generic spine runs
     one; M4 across real api responses). *)
  Alcotest.(check int) "orphan: M3 violation-free (holds everywhere)" 0
    (violations m3_name);
  Alcotest.(check int) "orphan: M2 violation-free (holds everywhere)" 0
    (violations m2_name);
  Alcotest.(check int) "orphan: M4 violation-free (holds everywhere)" 0
    (violations m4_name);
  (* (d) THE LIVE RED CONTROL (prediction 6): M1 asserted ALONE must be
     REFUTED - the vrs spine stamps [Controller (0, vrs-kind key)] with
     the SAME controller id 0, so the kind check fails on a REAL graph,
     forge-free. The violating state names M1 through the FULL family
     ([first_violated]), the leg's own [violated_of] shape. *)
  let outcome =
    Mc.check_safety reach
      ~inv:(Invariants.conjunction m1_only)
      ~equal:Cc.state_equal
  in
  Alcotest.(check bool) "orphan: M1 alone REFUTED (live red control)" true
    (match outcome with
    | Mc.Refuted _ -> true
    | Mc.No_counterexample _ -> false);
  Alcotest.(check string)
    "orphan: violated (first_violated over the family at the counterexample \
     state) names M1"
    m1_name
    (match outcome with
    | Mc.No_counterexample _ -> "<clean>"
    | Mc.Refuted { lasso; _ } ->
      Option.fold
        (Option.bind
           (match Array.to_list lasso.Mc.loop with
           | [] -> None
           | s :: _ -> Some s)
           (Invariants.first_violated family))
        ~none:"<none>"
        ~some:(fun (i : Invariants.invariant) -> i.Invariants.name));
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "orphan: states (pinned, depth-4 replica)"
    P19_witness.orphan_states (Mc.states_seen reach);
  Alcotest.(check int) "orphan: M3 interesting count (pinned - the floor)"
    P19_witness.m3_interesting_orphan (cnt m3_name);
  Alcotest.(check int) "orphan: M1 interesting count (pinned)"
    P19_witness.m1_interesting_orphan (cnt m1_name);
  Alcotest.(check int) "orphan: M2 interesting count (pinned, live monkey)"
    P19_witness.m2_interesting_orphan (cnt m2_name);
  Alcotest.(check int) "orphan: M4 interesting count (pinned)"
    P19_witness.m4_interesting_orphan (cnt m4_name);
  Alcotest.(check int)
    "orphan: M1 violation count (pinned; = M1's premise count - every \
     controller tag on this spine is vrs-kind)"
    P19_witness.m1_violations_orphan (violations m1_name)

let () =
  Alcotest.run "p19_provenance"
    [
      ( "family_shape",
        [
          Alcotest.test_case "provenance_family = the four upstream names"
            `Quick test_family_shape;
        ] );
      ( "legs",
        [
          Alcotest.test_case "L0: zero-budget control" `Quick test_l0;
          Alcotest.test_case "Lc: crash-only" `Quick test_lc;
          Alcotest.test_case "Ld: drop-only (M4-dominated)" `Quick test_ld;
          Alcotest.test_case "Lm: monkey-only (M2's only live leg)" `Quick
            test_lm;
        ] );
      ( "orphan_replica",
        [
          Alcotest.test_case
            "orphan floor: M3 de-vacuized + M1 live red control" `Quick
            test_orphan;
        ] );
    ]

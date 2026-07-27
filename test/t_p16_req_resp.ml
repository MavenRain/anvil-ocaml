(* BUILD-SPEC-P16 §4.6 / §4.7 - the request/response correspondence matrix:
   the four [vct:false] legs (L0 / Lc / Ld / Lm) and two [vct:true] legs
   (L0v / Ldv) of {!Anvil_checker.Fault_check.check_req_resp_under_faults},
   each list ([Rv_list] = Q1-Q2, [Matched_list] = Q3 + Q5) asserted ALONE,
   their gates, per-member [interesting] counts, the drop/monkey EDGE-TAKEN
   assertions, the P16-C knife-edge probe, and the SUPPLEMENTARY crash-x-vct
   probe Lcv.

   WHAT THIS EXE ESTABLISHES.

   1. THE FIRST DROP AND MONKEY EDGES EVER TAKEN IN DECISIVE LEGS
      (BUILD-SPEC-P16 §1): Ld is clean and decisive with
      [max_drops_seen = 1], Lm with [max_monkeys_seen = 1] - the vacuity
      P15 disclosed (no shipped seed could enable either edge) is
      discharged AT THE LEG. Both clean verdicts are NEGATIVE results
      (§8.4) and are asserted as measurements, never dressed as passes.

   2. PREDICTION P16-C's leg half, the phase's knife-edge: 384 of Ld's 744
      states hold a fabricated Error-bodied response that SATISFIES
      [Message.resp_msg_matches_req_msg] against an ongoing reconcile's
      pending request - all 384 post-drop, 0 on L0 - so the matching
      premise of Q3/Q5 is genuinely reached and only the [is_ok] conjunct
      blocks it. (Mutation MD flips that conjunct; the flip lives in the
      mutation exe, not here.) The MD-CONVERSE CAVEAT is also measured:
      real, non-fabricated Error responses matching a pending request
      exist with NO drop edge at all (Lc 4, Lm 24, L0v 4, Ldv's
      fault-free 8), so only the [drops >= 1] slice is drop-attributable.

   3. PREDICTION P16-D's leg half: Lm's [max_uid_seen = max_rv_seen = 4]
      against 3 / 2 everywhere else at [vct:false] - the monkey's injected
      create was applied by a real [Api_server_step], the TRANSITIVE etcd
      write the second-writer mechanism requires. The MS MATRIX GAP is
      asserted, not hidden: Q2's [interesting] is 0 on Lm at [vct:false],
      so MS's predicted witness cannot fire through Q2's premise on this
      matrix's Lm (the mutation stage must probe at [vct:true] or re-site
      the witness).

   4. PREDICTION P16-E, measured not argued: Q1/Q2/Q3's [interesting] is 0
      on EVERY [vct:false] graph and > 0 on EVERY [vct:true] graph; Q5 is
      the sole non-vacuous member at [vct:false]. Every clean [Rv_list]
      verdict at [vct:false] is therefore CONTENT-VACUOUS ([gate = 0],
      pinned as vacuity, never as a pass).

   5. PREDICTIONS P16-A / P16-B on the crash dimension: Lc clean and
      decisive over the exact P13 G1 graph; P16-A judged non-vacuously on
      the SUPPLEMENTARY Lcv probe (Q1/Q2 fire at 56 post-crash states each
      and hold everywhere); P16-B's "post-crash gate collapses" sub-clause
      measured AGAINST as worded - the post-crash gate is 32 > 0 and
      DENSER than the fault-free slice (32/388 vs 4/76), per-crash-instant
      vacuation with post-restart re-arming, P15's own pinned L1 shape.

   TEST-ORDERING RULE (P12 finding 1, P13/P14/P15 precedent): every test
   asserts the SEMANTIC facts FIRST - outcome clean, [violated = None],
   decisive, EDGE-TAKEN where the claim needs one - and only THEN the
   brittle exact counts, so a shifted pin can never redden the exe before
   the load-bearing assertion runs.

   Every pinned number comes from {!P16_witness} (single source of truth);
   none is re-typed here.

   Firewall honoured: List/Option/fold combinators only (no loop
   keywords), exhaustive matches on every finite sum (both [Mc.outcome]
   arms, all four [Message.message_content] arms, all nine
   [Api_method.api_response] arms - payload wildcards only, never an arm
   wildcard), no two-arm match on [option]/[result] (stdlib
   [Option.fold] / [Result.fold]), Alcotest as the sanctioned failure
   primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Rr = Anvil_assurance.Req_resp_correspondence

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P16_witness.witness_desired
let depth : int = P16_witness.witness_depth
let bound : Bound.t = P16_witness.p16_bound ~desireds:[ desired ]

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) -------- *)

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

(* ==== the fourteen leg runs (lazy: no test pays for an unused exploration) = *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) ~(list_select : Fc.list_select)
    ~(require_fault : bool) : Fc.fault_report =
  Fc.check_req_resp_under_faults ~depth ~req_drop ~pod_monkey ~vct bound budget
    ~desired ~list_select ~require_fault

let l0_rv : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.zero_budget
       ~list_select:Fc.Rv_list ~require_fault:false)

let l0_matched : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.zero_budget
       ~list_select:Fc.Matched_list ~require_fault:false)

let lc_rv : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.lc_budget
       ~list_select:Fc.Rv_list ~require_fault:true)

let lc_matched : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.lc_budget
       ~list_select:Fc.Matched_list ~require_fault:true)

let ld_rv : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:true ~pod_monkey:false ~vct:false P16_witness.ld_budget
       ~list_select:Fc.Rv_list ~require_fault:true)

let ld_matched : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:true ~pod_monkey:false ~vct:false P16_witness.ld_budget
       ~list_select:Fc.Matched_list ~require_fault:true)

let lm_rv : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:true ~vct:false P16_witness.lm_budget
       ~list_select:Fc.Rv_list ~require_fault:true)

let lm_matched : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:true ~vct:false P16_witness.lm_budget
       ~list_select:Fc.Matched_list ~require_fault:true)

let l0v_rv : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:true P16_witness.zero_budget
       ~list_select:Fc.Rv_list ~require_fault:false)

let l0v_matched : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:true P16_witness.zero_budget
       ~list_select:Fc.Matched_list ~require_fault:false)

let ldv_rv : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:true ~pod_monkey:false ~vct:true P16_witness.ld_budget
       ~list_select:Fc.Rv_list ~require_fault:true)

let ldv_matched : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:true ~pod_monkey:false ~vct:true P16_witness.ld_budget
       ~list_select:Fc.Matched_list ~require_fault:true)

(* The SUPPLEMENTARY crash-x-vct probe (P16-A's non-vacuous judge; NOT a
   §4.6 matrix leg - see P16_witness's Lcv block). *)
let lcv_rv : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:true P16_witness.lc_budget
       ~list_select:Fc.Rv_list ~require_fault:true)

let lcv_matched : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:true P16_witness.lc_budget
       ~list_select:Fc.Matched_list ~require_fault:true)

(* ==== the four members, instantiated EXACTLY as the legs instantiate them ==
   Q2's bound-key closure takes THE LEG'S OWN bound (the coupling
   {!Rr.rv_family} documents): a different bound here would make the
   per-member counts evidence about some other leg. *)

let q1 : Invariants.invariant = Rr.object_in_ok_get_response_has_smaller_rv_than_etcd
let q2 : Invariants.invariant = Rr.object_in_ok_get_resp_is_same_as_etcd_with_same_rv bound

let q3 : Invariants.invariant =
  Rr.key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_pending_req
    ~controller_id

let q5 : Invariants.invariant =
  Rr.key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req
    ~controller_id

let rv_family : Invariants.invariant list = Rr.rv_family bound
let matched_family : Invariants.invariant list = Rr.matched_family ~controller_id

(* ==== LOCAL replicas of the legs' product graphs ============================
   The per-member counts, the recomputed union gates, the knife-edge probe
   and the in-flight peaks need the reachable set itself, which
   [fault_report] does not carry. Same seed / bound / budget / depth through
   the exported {!Fc.faulted_successors}; every consuming test asserts
   [Mc.states_seen] against BOTH lists' leg [states] FIRST (the P13 M3/M5
   precedent - a drifted replica would silently measure a different graph). *)

let seed ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool) :
    Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ~vct ()

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed ~req_drop ~pod_monkey ~vct) ]

let l0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.zero_budget)

let lc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.lc_budget)

let ld_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:true ~pod_monkey:false ~vct:false P16_witness.ld_budget)

let lm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:true ~vct:false P16_witness.lm_budget)

let l0v_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false ~vct:true P16_witness.zero_budget)

let ldv_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:true ~pod_monkey:false ~vct:true P16_witness.ld_budget)

let lcv_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false ~vct:true P16_witness.lc_budget)

(* ---- slices of a product graph -------------------------------------------- *)

let all_states (_ : Fc.faulted) : bool = true
let post_crash (f : Fc.faulted) : bool = f.crashes >= 1
let post_drop (f : Fc.faulted) : bool = f.drops >= 1
let post_monkey (f : Fc.faulted) : bool = f.monkeys >= 1

let fault_free (f : Fc.faulted) : bool =
  f.crashes = 0 && f.drops = 0 && f.monkeys = 0

(* [interesting]-fires count for ONE member over a slice. *)
let fires (reach : Fc.faulted Mc.reachable) ~(slice : Fc.faulted -> bool)
    (i : Invariants.invariant) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f && i.Invariants.interesting f.cs)

(* The union gate the leg computes for a given list, recomputed locally over
   the slice the leg's [require_fault] selects (its budget's own dimension). *)
let union_gate (family : Invariants.invariant list)
    (reach : Fc.faulted Mc.reachable) ~(slice : Fc.faulted -> bool) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f
      && List.exists
           (fun (i : Invariants.invariant) -> i.Invariants.interesting f.cs)
           family)

(* States at which a member's [holds] is FALSE: the replica-side per-member
   cleanliness check (the leg only reports its conjunction's verdict). *)
let holds_violations (reach : Fc.faulted Mc.reachable)
    (i : Invariants.invariant) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      not (i.Invariants.holds f.cs))

let max_over (reach : Fc.faulted Mc.reachable) ~(proj : Fc.faulted -> int) :
    int =
  Mc.fold_states reach ~init:0 ~f:(fun (acc : int) (f : Fc.faulted) ->
      max acc (proj f))

let max_in_flight (reach : Fc.faulted Mc.reachable) : int =
  max_over reach ~proj:(fun (f : Fc.faulted) ->
      Message.Pool.cardinal (Cluster.in_flight f.cs))

(* ==== the P16-C knife-edge probe ============================================
   A state is ON THE KNIFE-EDGE when some in-flight api RESPONSE with an
   [Error] body satisfies [Message.resp_msg_matches_req_msg] against some
   ongoing reconcile's pending request: Q3/Q5's matching premise is reached
   and ONLY their [is_ok] conjunct is false. On the drop legs this is the
   fabricated [form_matched_err_resp_msg] payload (rpc_id inherited from the
   dropped request); on Lc/Lm/L0v it counts REAL error responses - which is
   exactly why MD's converse control must gate on [drops >= 1], never on
   this predicate alone (P16_witness, knife_edge_lc's block). *)

(* [Error]-bodied, exhaustively over all NINE response arms (payload
   wildcards only); each arm folds its own [result] - no two-arm match. *)
let response_is_error (r : Api_method.api_response) : bool =
  let err_obj (res : (Dynamic_object.t, Api_method.api_error) result) : bool =
    Result.fold
      ~ok:(fun (_ : Dynamic_object.t) -> false)
      ~error:(fun (_ : Api_method.api_error) -> true)
      res
  in
  let err_list (res : (Dynamic_object.t list, Api_method.api_error) result) :
      bool =
    Result.fold
      ~ok:(fun (_ : Dynamic_object.t list) -> false)
      ~error:(fun (_ : Api_method.api_error) -> true)
      res
  in
  let err_unit (res : (unit, Api_method.api_error) result) : bool =
    Result.fold
      ~ok:(fun (() : unit) -> false)
      ~error:(fun (_ : Api_method.api_error) -> true)
      res
  in
  match r with
  | Api_method.Get_response { res } -> err_obj res
  | Api_method.List_response { res } -> err_list res
  | Api_method.Create_response { res } -> err_obj res
  | Api_method.Delete_response { res } -> err_unit res
  | Api_method.Update_response { res } -> err_obj res
  | Api_method.Update_status_response { res } -> err_obj res
  | Api_method.Get_then_delete_response { res } -> err_unit res
  | Api_method.Get_then_update_response { res } -> err_obj res
  | Api_method.Get_then_update_status_response { res } -> err_obj res

let matches_some_pending (cs : Cluster.cluster_state) (m : Message.t) : bool =
  Object_ref_map.fold
    (fun (_ : Common.object_ref) (rs : Controller.ongoing_reconcile)
         (acc : bool) ->
      acc
      || Option.fold ~none:false
           ~some:(fun (req : Message.t) ->
             Message.resp_msg_matches_req_msg m req)
           rs.Controller.pending_req_msg)
    (Cluster.ongoing_reconciles cs controller_id)
    false

let knife_edge_state (cs : Cluster.cluster_state) : bool =
  List.exists
    (fun (m : Message.t) ->
      (match m.Message.content with
      | Message.Api_response r -> response_is_error r
      | Message.Api_request _ | Message.External_request _
      | Message.External_response _ ->
          false)
      && matches_some_pending cs m)
    (Message.Pool.distinct (Cluster.in_flight cs))

let knife_edge (reach : Fc.faulted Mc.reachable)
    ~(slice : Fc.faulted -> bool) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f && knife_edge_state f.cs)

(* ==== the shared leg semantics (asserted BEFORE any count) ==================
   Unlike P15's helper this one does NOT assert [gate_states > 0]: the
   [Rv_list] gates are MEASURED 0 on every [vct:false] graph (P16-E), and
   each leg test pins its gate explicitly - as content-vacuity where it is
   one, never as a pass. *)

let check_leg_semantics (label : string) (r : Fc.fault_report) : unit =
  Alcotest.(check bool) (label ^ ": outcome clean (no counterexample)") true
    (is_clean r);
  Alcotest.(check bool) (label ^ ": violated = None") true
    (Option.is_none r.violated);
  Alcotest.(check bool) (label ^ ": outcome decisive (frontier emptied)") true
    (decisive r);
  Alcotest.(check bool) (label ^ ": fault_free_states positive") true
    (r.fault_free_states > 0);
  Alcotest.(check bool)
    (label ^ ": max_uid_seen STRICTLY below uid_ceiling (interpretable)") true
    (r.max_uid_seen < r.bound.uid_ceiling);
  Alcotest.(check bool)
    (label ^ ": max_rv_seen STRICTLY below rv_ceiling (interpretable)") true
    (r.max_rv_seen < r.bound.rv_ceiling);
  Alcotest.(check bool)
    (label ^ ": max_crashes_seen within budget (budget pruning is sound)") true
    (r.max_crashes_seen <= r.budget.max_crashes);
  Alcotest.(check bool)
    (label ^ ": max_drops_seen within budget") true
    (r.max_drops_seen <= r.budget.max_drops);
  Alcotest.(check bool)
    (label ^ ": max_monkeys_seen within budget") true
    (r.max_monkeys_seen <= r.budget.max_monkey_ops);
  Alcotest.(check bool) (label ^ ": pruned_by_ceiling (disclosed)") true
    r.pruned_by_ceiling;
  Alcotest.(check bool) (label ^ ": pruned_by_budget (disclosed)") true
    r.pruned_by_budget

(* If a run here ever reports [violated] naming a P14 or P15 member, the
   lists were unioned somewhere (the §4.4 masking trap): harness bug, not a
   finding. [check_leg_semantics] asserts [violated = None] on every clean
   leg, and the P16 regression exe rejects the union by NAME. *)

let check_replica_faithful (label : string) (reach : Fc.faulted Mc.reachable)
    (rv : Fc.fault_report) (matched : Fc.fault_report) : unit =
  Alcotest.(check int)
    (label ^ ": replica graph size = the Rv leg's states (replica faithful)")
    (states_of rv) (Mc.states_seen reach);
  Alcotest.(check int)
    (label
   ^ ": replica graph size = the Matched leg's states (one graph, two lists)")
    (states_of matched) (Mc.states_seen reach);
  Alcotest.(check bool) (label ^ ": replica frontier emptied") true
    (Mc.frontier_emptied reach)

let check_members_clean (label : string) (reach : Fc.faulted Mc.reachable) :
    unit =
  List.iter
    (fun ((name, i) : string * Invariants.invariant) ->
      Alcotest.(check int)
        (label ^ ": " ^ name
       ^ " holds-violations = 0 (clean per member, replica-confirmed)")
        0 (holds_violations reach i))
    [ ("Q1", q1); ("Q2", q2); ("Q3", q3); ("Q5", q5) ]

(* ==== L0: zero-budget control, vct:false ==================================== *)

let test_l0_legs () =
  let rv = Lazy.force l0_rv in
  let m = Lazy.force l0_matched in
  check_leg_semantics "L0/Rv" rv;
  check_leg_semantics "L0/Matched" m;
  (* The control really is fault-free: every dimension at zero. *)
  Alcotest.(check int) "L0: max_crashes_seen = 0" 0 rv.max_crashes_seen;
  Alcotest.(check int) "L0: max_drops_seen = 0" 0 rv.max_drops_seen;
  Alcotest.(check int) "L0: max_monkeys_seen = 0" 0 rv.max_monkeys_seen;
  Alcotest.(check int) "L0: crash_witness_states = 0 (crash-free graph)" 0
    rv.crash_witness_states;
  Alcotest.(check bool)
    "L0: states = fault_free_states (the graph IS the fault-free slice)" true
    (states_of rv = rv.fault_free_states);
  (* One graph, two lists: the product graph never depends on the asserted
     invariants. *)
  Alcotest.(check int) "L0: Rv and Matched legs explored the SAME graph"
    (states_of rv) (states_of m);
  (* The §4.6 no-seed-drift cross-check, asserted against the live leg: this
     graph is P13 G1's / P14 G1's / P15 L0's fault-free 76. A disagreement
     means the seed drifted - investigate before reporting anything. *)
  Alcotest.(check int)
    "L0: states = P13's G1 fault_free_states (same seed/bound/depth, caps 0)"
    P13_witness.g1_fault_free_states (states_of rv);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L0: states (pinned)" P16_witness.l0_states
    (states_of rv);
  Alcotest.(check int)
    "L0/Rv: gate_states = 0 (pinned CONTENT-VACUITY, P16-E: no OK get \
     response can exist at vct:false - NOT a pass for Q1/Q2 content)"
    P16_witness.l0_rv_gate_states (gate_of rv);
  Alcotest.(check int)
    "L0/Matched: gate_states (pinned; Q5 the sole non-vacuous member)"
    P16_witness.l0_matched_gate_states (gate_of m);
  Alcotest.(check int) "L0: max_uid_seen (pinned via P15's L0)"
    P16_witness.l0_max_uid_seen rv.max_uid_seen;
  Alcotest.(check int) "L0: max_rv_seen (pinned via P15's L0)"
    P16_witness.l0_max_rv_seen rv.max_rv_seen

let test_l0_members () =
  let reach = Lazy.force l0_reach in
  check_replica_faithful "L0" reach (Lazy.force l0_rv) (Lazy.force l0_matched);
  (* The legs' gates are the unions the replica recomputes - MEASURED EQUAL
     ([require_fault:false], so the slice is all-states). *)
  Alcotest.(check int)
    "L0/Rv: recomputed all-states union gate = the leg's gate_states"
    (gate_of (Lazy.force l0_rv))
    (union_gate rv_family reach ~slice:all_states);
  Alcotest.(check int)
    "L0/Matched: recomputed all-states union gate = the leg's gate_states"
    (gate_of (Lazy.force l0_matched))
    (union_gate matched_family reach ~slice:all_states);
  let count (i : Invariants.invariant) = fires reach ~slice:all_states i in
  (* SEMANTIC first: Q5 is genuinely exercised on the floor graph, and every
     member holds everywhere. *)
  Alcotest.(check bool) "L0: Q5 interesting fires (> 0)" true (count q5 > 0);
  check_members_clean "L0" reach;
  (* P16-E's vacuity floor, MEASURED (pinned zeros, not skipped members). *)
  Alcotest.(check int) "L0: Q1 interesting = 0 (P16-E floor, pinned)"
    P16_witness.q1_interesting_l0 (count q1);
  Alcotest.(check int) "L0: Q2 interesting = 0 (P16-E floor, pinned)"
    P16_witness.q2_interesting_l0 (count q2);
  Alcotest.(check int) "L0: Q3 interesting = 0 (P16-E floor, pinned)"
    P16_witness.q3_interesting_l0 (count q3);
  (* The knife-edge baseline: NO error response matches a pending request on
     the fault-free graph. *)
  Alcotest.(check int) "L0: knife-edge states (pinned baseline 0)"
    P16_witness.knife_edge_l0
    (knife_edge reach ~slice:all_states);
  (* The §5 re-measurement, floor side. *)
  Alcotest.(check int) "L0: max in-flight cardinal over the graph (pinned)"
    P16_witness.l0_max_in_flight_seen (max_in_flight reach);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L0: Q5 interesting count (pinned)"
    P16_witness.q5_interesting_l0 (count q5)

(* ==== Lc: crash-only - P16-A / P16-B ======================================= *)

let test_lc_legs () =
  let rv = Lazy.force lc_rv in
  let m = Lazy.force lc_matched in
  check_leg_semantics "Lc/Rv" rv;
  check_leg_semantics "Lc/Matched" m;
  (* The crash edge was REALLY taken, and the crash dimension is ISOLATED. *)
  Alcotest.(check bool) "Lc: max_crashes_seen >= 1 (a REAL crash occurred)"
    true
    (rv.max_crashes_seen >= 1);
  Alcotest.(check bool)
    "Lc: crash_witness_states positive (post-crash slice non-empty)" true
    (rv.crash_witness_states > 0);
  Alcotest.(check int) "Lc: max_drops_seen = 0 (crash dimension isolated)" 0
    rv.max_drops_seen;
  Alcotest.(check int) "Lc: max_monkeys_seen = 0 (crash dimension isolated)" 0
    rv.max_monkeys_seen;
  Alcotest.(check int) "Lc: Rv and Matched legs explored the SAME graph"
    (states_of rv) (states_of m);
  (* P16-B, the density form (the sub-clause MEASURED AGAINST its original
     "post-crash collapse" wording): the post-crash Matched gate is nonzero
     and DENSER than the fault-free Q5 exercise (32/388 vs 4/76) - the crash
     vacuates PER CRASH INSTANT and the gate re-arms post-restart, exactly
     P15's pinned L1 shape. Cross-multiplied to stay in integers. *)
  Alcotest.(check bool)
    "Lc (P16-B): post-crash Matched gate > 0 (no aggregate collapse)" true
    (gate_of m > 0);
  Alcotest.(check bool)
    "Lc (P16-B): post-crash gate DENSER than the fault-free slice \
     (re-arming, not collapse)"
    true
    (gate_of m * rv.fault_free_states
    > P16_witness.q5_interesting_l0 * rv.crash_witness_states);
  (* The §4.6 cross-check IDENTITY: same seed / bound / budget / depth as
     P13's G1, P14's G2 and P15's L1, so the product set is literally theirs. *)
  Alcotest.(check int)
    "Lc: states = P13's G1 states (identical product graph, different lists)"
    P13_witness.g1_states (states_of rv);
  Alcotest.(check int) "Lc: crash_witness_states = P13's G1's"
    P13_witness.g1_crash_witness_states rv.crash_witness_states;
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Lc: states (pinned)" P16_witness.lc_states
    (states_of rv);
  Alcotest.(check int)
    "Lc/Rv: gate_states = 0 (pinned CONTENT-VACUITY at vct:false, P16-E; \
     P16-A is judged on the SUPPLEMENTARY Lcv probe, not here)"
    P16_witness.lc_rv_gate_states (gate_of rv);
  Alcotest.(check int) "Lc/Matched: gate_states (pinned, post-crash union)"
    P16_witness.lc_matched_gate_states (gate_of m);
  Alcotest.(check int) "Lc: fault_free_states (pinned)"
    P16_witness.lc_fault_free_states rv.fault_free_states;
  Alcotest.(check int) "Lc: max_uid_seen (pinned)" P16_witness.lc_max_uid_seen
    rv.max_uid_seen;
  Alcotest.(check int) "Lc: max_rv_seen (pinned)" P16_witness.lc_max_rv_seen
    rv.max_rv_seen;
  Alcotest.(check int) "Lc: max_crashes_seen (pinned)"
    P16_witness.lc_max_crashes_seen rv.max_crashes_seen

let test_lc_members () =
  let reach = Lazy.force lc_reach in
  check_replica_faithful "Lc" reach (Lazy.force lc_rv) (Lazy.force lc_matched);
  (* The legs' gates are the post-crash unions the replica recomputes
     ([require_fault:true] at a crash-only budget selects [crashes >= 1]). *)
  Alcotest.(check int)
    "Lc/Rv: recomputed post-crash union gate = the leg's gate_states"
    (gate_of (Lazy.force lc_rv))
    (union_gate rv_family reach ~slice:post_crash);
  Alcotest.(check int)
    "Lc/Matched: recomputed post-crash union gate = the leg's gate_states"
    (gate_of (Lazy.force lc_matched))
    (union_gate matched_family reach ~slice:post_crash);
  let all (i : Invariants.invariant) = fires reach ~slice:all_states i in
  let post (i : Invariants.invariant) = fires reach ~slice:post_crash i in
  (* SEMANTIC first: Q5's clean-under-crash is non-vacuous (it fires at
     genuinely post-crash states) and every member holds everywhere. *)
  Alcotest.(check bool) "Lc: Q5 fires POST-CRASH (> 0)" true (post q5 > 0);
  check_members_clean "Lc" reach;
  (* The fault-free slice of this graph IS L0's graph, so its Q5 count is
     L0's pin - the slice identity, asserted live. *)
  Alcotest.(check int)
    "Lc: fault-free-slice Q5 interesting = L0's count (slice identity)"
    P16_witness.q5_interesting_l0
    (fires reach ~slice:fault_free q5);
  (* P16-E holds under crash too (pinned zeros). *)
  Alcotest.(check int) "Lc: Q1 interesting = 0 (P16-E, pinned)"
    P16_witness.q1_interesting_lc (all q1);
  Alcotest.(check int) "Lc: Q2 interesting = 0 (P16-E, pinned)"
    P16_witness.q2_interesting_lc (all q2);
  Alcotest.(check int) "Lc: Q3 interesting = 0 (P16-E, pinned)"
    P16_witness.q3_interesting_lc (all q3);
  (* The MD-converse caveat, crash flavor: 4 REAL error responses (post-crash
     create-conflict replay) match a pending request with NO drop dimension
     in the model at all; all 4 are post-crash (the fault-free slice is L0's
     graph, knife-edge 0 there). *)
  Alcotest.(check int) "Lc: knife-edge states (pinned - REAL error replies)"
    P16_witness.knife_edge_lc
    (knife_edge reach ~slice:all_states);
  Alcotest.(check int)
    "Lc: knife-edge fault-free slice = 0 (all knife-edge states post-crash)" 0
    (knife_edge reach ~slice:fault_free);
  (* The §5 re-measurement, crash side (pinned via P15's identical graph). *)
  Alcotest.(check int) "Lc: max in-flight cardinal over the graph (pinned)"
    P16_witness.lc_max_in_flight_seen (max_in_flight reach);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Lc: Q5 interesting count (pinned)"
    P16_witness.q5_interesting_lc (all q5);
  Alcotest.(check int) "Lc: Q5 post-crash interesting count (pinned)"
    P16_witness.q5_interesting_lc_post_crash (post q5)

(* ==== Ld: drop-only - the FIRST drop edge in a decisive leg (P16-C) ======== *)

let test_ld_legs () =
  let rv = Lazy.force ld_rv in
  let m = Lazy.force ld_matched in
  check_leg_semantics "Ld/Rv" rv;
  check_leg_semantics "Ld/Matched" m;
  (* THE EDGE-TAKEN ASSERTION, before any count (BUILD-SPEC-P16 §3: a drop
     leg with [max_drops_seen = 0] is vacuous for its own dimension and NO
     verdict from it may be reported - the exact failure P15 disclosed and
     this phase exists to fix). *)
  Alcotest.(check bool)
    "Ld: max_drops_seen >= 1 (the drop edge was REALLY taken - the first \
     drop edge in a decisive leg in this repo)"
    true
    (rv.max_drops_seen >= 1);
  Alcotest.(check int) "Ld: budget really admits one drop (cap = 1)" 1
    rv.budget.Fc.max_drops;
  Alcotest.(check int) "Ld: max_crashes_seen = 0 (drop dimension isolated)" 0
    rv.max_crashes_seen;
  Alcotest.(check int) "Ld: max_monkeys_seen = 0 (drop dimension isolated)" 0
    rv.max_monkeys_seen;
  Alcotest.(check int) "Ld: crash_witness_states = 0" 0 rv.crash_witness_states;
  Alcotest.(check int) "Ld: Rv and Matched legs explored the SAME graph"
    (states_of rv) (states_of m);
  (* Graph identity with P15's supplementary L2x probe (what was a probe
     there is a leg here - same seed flags, bound, budget, depth). *)
  Alcotest.(check int)
    "Ld: states = P15's L2x probe states (identical product graph)"
    P15_witness.l2x_states (states_of rv);
  (* The fault-free slice is the flag-ON zero-budget control: the enabled
     req_drop flag adds the Disable_req_drop dimension, DOUBLING L0's 76.
     NOT seed drift (L0 pinned 76 exactly above). *)
  Alcotest.(check int)
    "Ld: fault_free_states = P15's flag-ON control (the Disable_* doubling, \
     NOT seed drift)"
    P16_witness.ld_fault_free_states rv.fault_free_states;
  (* Exact MEASURED pins LAST. A CLEAN drop leg is a NEGATIVE result
     (§8.4): these pins record that the unmutated fabricated Error response
     refutes nothing - MD's flip is the mutation exe's to measure. *)
  Alcotest.(check int) "Ld: states (pinned)" P16_witness.ld_states
    (states_of rv);
  Alcotest.(check int) "Ld: max_drops_seen (pinned)"
    P16_witness.ld_max_drops_seen rv.max_drops_seen;
  Alcotest.(check int)
    "Ld/Rv: gate_states = 0 (pinned CONTENT-VACUITY at vct:false, P16-E)"
    P16_witness.ld_rv_gate_states (gate_of rv);
  Alcotest.(check int)
    "Ld/Matched: gate_states (pinned, post-drop union: Q5 exercised across \
     a REAL drop and holding)"
    P16_witness.ld_matched_gate_states (gate_of m);
  Alcotest.(check int) "Ld: max_uid_seen (pinned)" P16_witness.ld_max_uid_seen
    rv.max_uid_seen;
  Alcotest.(check int) "Ld: max_rv_seen (pinned)" P16_witness.ld_max_rv_seen
    rv.max_rv_seen

let test_ld_members () =
  let reach = Lazy.force ld_reach in
  check_replica_faithful "Ld" reach (Lazy.force ld_rv) (Lazy.force ld_matched);
  Alcotest.(check int)
    "Ld/Rv: recomputed post-drop union gate = the leg's gate_states"
    (gate_of (Lazy.force ld_rv))
    (union_gate rv_family reach ~slice:post_drop);
  Alcotest.(check int)
    "Ld/Matched: recomputed post-drop union gate = the leg's gate_states"
    (gate_of (Lazy.force ld_matched))
    (union_gate matched_family reach ~slice:post_drop);
  let all (i : Invariants.invariant) = fires reach ~slice:all_states i in
  let post (i : Invariants.invariant) = fires reach ~slice:post_drop i in
  (* SEMANTIC first: Q5 fires at genuinely post-drop states and every member
     holds everywhere - clean-across-a-real-drop is non-vacuous for Q5. *)
  Alcotest.(check bool) "Ld: Q5 fires POST-DROP (> 0)" true (post q5 > 0);
  check_members_clean "Ld" reach;
  (* P16-E at vct:false (pinned zeros). *)
  Alcotest.(check int) "Ld: Q1 interesting = 0 (P16-E, pinned)"
    P16_witness.q1_interesting_ld (all q1);
  Alcotest.(check int) "Ld: Q2 interesting = 0 (P16-E, pinned)"
    P16_witness.q2_interesting_ld (all q2);
  Alcotest.(check int) "Ld: Q3 interesting = 0 (P16-E, pinned)"
    P16_witness.q3_interesting_ld (all q3);
  (* THE KNIFE-EDGE (P16-C's mechanism, measured directly): the fabricated
     response satisfies the MATCHING premise at 384 states and only the
     [is_ok] conjunct blocks Q3/Q5. Every knife-edge state on THIS graph is
     post-drop (drop-attributable) - asserted both ways. *)
  Alcotest.(check int) "Ld: knife-edge states (pinned, the P16-C mechanism)"
    P16_witness.knife_edge_ld
    (knife_edge reach ~slice:all_states);
  Alcotest.(check int)
    "Ld: knife-edge post-drop = total (every knife-edge state is \
     drop-attributable HERE - the MD-converse gate)"
    P16_witness.knife_edge_ld
    (knife_edge reach ~slice:post_drop);
  Alcotest.(check int)
    "Ld: knife-edge fault-free slice = 0 (no real error reply matches \
     pending without the drop on this graph)"
    0
    (knife_edge reach ~slice:fault_free);
  (* The §5 re-measurement, drop side (pinned via P15's identical graph). *)
  Alcotest.(check int) "Ld: max in-flight cardinal over the graph (pinned)"
    P16_witness.ld_max_in_flight_seen (max_in_flight reach);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Ld: Q5 interesting count (pinned)"
    P16_witness.q5_interesting_ld (all q5);
  Alcotest.(check int) "Ld: Q5 post-drop interesting count (pinned)"
    P16_witness.q5_interesting_ld_post_drop (post q5)

(* ==== Lm: monkey-only - the FIRST monkey edge in a decisive leg (P16-D) ==== *)

let test_lm_legs () =
  let rv = Lazy.force lm_rv in
  let m = Lazy.force lm_matched in
  check_leg_semantics "Lm/Rv" rv;
  check_leg_semantics "Lm/Matched" m;
  (* THE EDGE-TAKEN ASSERTION, before any count (§3, as on Ld). *)
  Alcotest.(check bool)
    "Lm: max_monkeys_seen >= 1 (the monkey edge was REALLY taken - the \
     first monkey edge in a decisive leg in this repo)"
    true
    (rv.max_monkeys_seen >= 1);
  Alcotest.(check int) "Lm: budget really admits one monkey op (cap = 1)" 1
    rv.budget.Fc.max_monkey_ops;
  Alcotest.(check int) "Lm: max_crashes_seen = 0 (monkey dimension isolated)" 0
    rv.max_crashes_seen;
  Alcotest.(check int) "Lm: max_drops_seen = 0 (monkey dimension isolated)" 0
    rv.max_drops_seen;
  Alcotest.(check int) "Lm: crash_witness_states = 0" 0 rv.crash_witness_states;
  Alcotest.(check int) "Lm: Rv and Matched legs explored the SAME graph"
    (states_of rv) (states_of m);
  (* P16-D's second-writer mechanism, SEMANTIC form first: the monkey's
     injected create was applied by a real [Api_server_step] (the monkey
     itself writes neither etcd nor [s.api_server]), so the achieved uid/rv
     maxima STRICTLY exceed the crash/drop graphs' 3 / 2. *)
  Alcotest.(check bool)
    "Lm (P16-D): max_uid_seen > L0's (a real Api_server_step applied the \
     monkey's injected create - the transitive etcd write)"
    true
    (rv.max_uid_seen > P16_witness.l0_max_uid_seen);
  Alcotest.(check bool)
    "Lm (P16-D): max_rv_seen > L0's (same transitive-write signature)" true
    (rv.max_rv_seen > P16_witness.l0_max_rv_seen);
  (* Graph identity with P15's supplementary L3x probe. *)
  Alcotest.(check int)
    "Lm: states = P15's L3x probe states (identical product graph)"
    P15_witness.l3x_states (states_of rv);
  Alcotest.(check int)
    "Lm: fault_free_states = P15's flag-ON control (the Disable_* doubling, \
     NOT seed drift)"
    P16_witness.lm_fault_free_states rv.fault_free_states;
  (* Exact MEASURED pins LAST (clean monkey leg = NEGATIVE result, §8.4). *)
  Alcotest.(check int) "Lm: states (pinned)" P16_witness.lm_states
    (states_of rv);
  Alcotest.(check int) "Lm: max_monkeys_seen (pinned)"
    P16_witness.lm_max_monkeys_seen rv.max_monkeys_seen;
  Alcotest.(check int)
    "Lm/Rv: gate_states = 0 (pinned CONTENT-VACUITY at vct:false - ALSO the \
     MS matrix gap: Q2's premise cannot fire on this Lm, so the mutation \
     stage needs a vct:true monkey probe or a re-sited MS witness)"
    P16_witness.lm_rv_gate_states (gate_of rv);
  Alcotest.(check int) "Lm/Matched: gate_states (pinned, post-monkey union)"
    P16_witness.lm_matched_gate_states (gate_of m);
  Alcotest.(check int) "Lm: max_uid_seen (pinned)" P16_witness.lm_max_uid_seen
    rv.max_uid_seen;
  Alcotest.(check int) "Lm: max_rv_seen (pinned)" P16_witness.lm_max_rv_seen
    rv.max_rv_seen

let test_lm_members () =
  let reach = Lazy.force lm_reach in
  check_replica_faithful "Lm" reach (Lazy.force lm_rv) (Lazy.force lm_matched);
  Alcotest.(check int)
    "Lm/Rv: recomputed post-monkey union gate = the leg's gate_states"
    (gate_of (Lazy.force lm_rv))
    (union_gate rv_family reach ~slice:post_monkey);
  Alcotest.(check int)
    "Lm/Matched: recomputed post-monkey union gate = the leg's gate_states"
    (gate_of (Lazy.force lm_matched))
    (union_gate matched_family reach ~slice:post_monkey);
  let all (i : Invariants.invariant) = fires reach ~slice:all_states i in
  let post (i : Invariants.invariant) = fires reach ~slice:post_monkey i in
  (* SEMANTIC first. *)
  Alcotest.(check bool) "Lm: Q5 fires POST-MONKEY (> 0)" true (post q5 > 0);
  check_members_clean "Lm" reach;
  (* P16-E zeros - Q2's zero IS the MS matrix gap, pinned as a disclosed
     limitation of the matrix, never smoothed over. *)
  Alcotest.(check int) "Lm: Q1 interesting = 0 (P16-E, pinned)"
    P16_witness.q1_interesting_lm (all q1);
  Alcotest.(check int)
    "Lm: Q2 interesting = 0 (P16-E, pinned - the MS MATRIX GAP: \
     Q2-cleanliness on Lm is content-vacuous at vct:false)"
    P16_witness.q2_interesting_lm (all q2);
  Alcotest.(check int) "Lm: Q3 interesting = 0 (P16-E, pinned)"
    P16_witness.q3_interesting_lm (all q3);
  (* The MD-converse caveat, monkey flavor: 24 REAL error replies match
     pending requests with no drop edge in the model. *)
  Alcotest.(check int) "Lm: knife-edge states (pinned - REAL error replies)"
    P16_witness.knife_edge_lm
    (knife_edge reach ~slice:all_states);
  (* The §5 re-measurement ON THE MONKEY LEG SPECIFICALLY (the injected
     orphan does NOT inflate the pool; peak 2 against ceiling 8, no
     retune). *)
  Alcotest.(check int) "Lm: max in-flight cardinal over the graph (pinned)"
    P16_witness.lm_max_in_flight_seen (max_in_flight reach);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Lm: Q5 interesting count (pinned)"
    P16_witness.q5_interesting_lm (all q5);
  Alcotest.(check int) "Lm: Q5 post-monkey interesting count (pinned)"
    P16_witness.q5_interesting_lm_post_monkey (post q5)

(* ==== L0v: zero-budget, vct:TRUE - P16-E's de-vacuation half ================
   A DIFFERENT scenario: counts NOT comparable with the P13/P14/P15 pins
   (§8.6) - no cross-phase identity is asserted here, deliberately. *)

let test_l0v_legs () =
  let rv = Lazy.force l0v_rv in
  let m = Lazy.force l0v_matched in
  check_leg_semantics "L0v/Rv" rv;
  check_leg_semantics "L0v/Matched" m;
  Alcotest.(check int) "L0v: max_crashes_seen = 0" 0 rv.max_crashes_seen;
  Alcotest.(check int) "L0v: max_drops_seen = 0" 0 rv.max_drops_seen;
  Alcotest.(check int) "L0v: max_monkeys_seen = 0" 0 rv.max_monkeys_seen;
  Alcotest.(check int) "L0v: crash_witness_states = 0" 0 rv.crash_witness_states;
  Alcotest.(check bool)
    "L0v: states = fault_free_states (the graph IS the fault-free slice)" true
    (states_of rv = rv.fault_free_states);
  Alcotest.(check int) "L0v: Rv and Matched legs explored the SAME graph"
    (states_of rv) (states_of m);
  (* THE DE-VACUATION, semantic form first: the Rv gate is nonzero for the
     first time - OK get responses exist, so Q1/Q2 are genuinely evaluated. *)
  Alcotest.(check bool)
    "L0v (P16-E): Rv gate > 0 (Q1/Q2 de-vacuified at vct:true)" true
    (gate_of rv > 0);
  (* Exact MEASURED pins LAST (new literals; §8.6 forbids any cross-phase
     derivation for vct:true graphs). *)
  Alcotest.(check int) "L0v: states (pinned)" P16_witness.l0v_states
    (states_of rv);
  Alcotest.(check int) "L0v/Rv: gate_states (pinned, non-vacuous)"
    P16_witness.l0v_rv_gate_states (gate_of rv);
  Alcotest.(check int) "L0v/Matched: gate_states (pinned)"
    P16_witness.l0v_matched_gate_states (gate_of m);
  Alcotest.(check int) "L0v: max_uid_seen (pinned)"
    P16_witness.l0v_max_uid_seen rv.max_uid_seen;
  Alcotest.(check int) "L0v: max_rv_seen (pinned)" P16_witness.l0v_max_rv_seen
    rv.max_rv_seen

let test_l0v_members () =
  let reach = Lazy.force l0v_reach in
  check_replica_faithful "L0v" reach (Lazy.force l0v_rv)
    (Lazy.force l0v_matched);
  Alcotest.(check int)
    "L0v/Rv: recomputed all-states union gate = the leg's gate_states"
    (gate_of (Lazy.force l0v_rv))
    (union_gate rv_family reach ~slice:all_states);
  Alcotest.(check int)
    "L0v/Matched: recomputed all-states union gate = the leg's gate_states"
    (gate_of (Lazy.force l0v_matched))
    (union_gate matched_family reach ~slice:all_states);
  let count (i : Invariants.invariant) = fires reach ~slice:all_states i in
  (* SEMANTIC first - P16-E's vct:true half: every member now fires. *)
  Alcotest.(check bool) "L0v (P16-E): Q1 interesting fires (> 0)" true
    (count q1 > 0);
  Alcotest.(check bool) "L0v (P16-E): Q2 interesting fires (> 0)" true
    (count q2 > 0);
  Alcotest.(check bool) "L0v (P16-E): Q3 interesting fires (> 0)" true
    (count q3 > 0);
  Alcotest.(check bool) "L0v: Q5 interesting fires (> 0)" true (count q5 > 0);
  check_members_clean "L0v" reach;
  (* The MD-converse caveat, fault-FREE flavor: real error replies matching
     pending exist with no fault edge of any kind. *)
  Alcotest.(check int)
    "L0v: knife-edge states (pinned - REAL error replies, zero faults)"
    P16_witness.knife_edge_l0v
    (knife_edge reach ~slice:all_states);
  Alcotest.(check int) "L0v: max in-flight cardinal over the graph (pinned)"
    P16_witness.l0v_max_in_flight_seen (max_in_flight reach);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L0v: Q1 interesting count (pinned)"
    P16_witness.q1_interesting_l0v (count q1);
  Alcotest.(check int) "L0v: Q2 interesting count (pinned)"
    P16_witness.q2_interesting_l0v (count q2);
  Alcotest.(check int) "L0v: Q3 interesting count (pinned)"
    P16_witness.q3_interesting_l0v (count q3);
  Alcotest.(check int) "L0v: Q5 interesting count (pinned)"
    P16_witness.q5_interesting_l0v (count q5)

(* ==== Ldv: drop-only at vct:TRUE - the drop leg with non-vacuous rv ======== *)

let test_ldv_legs () =
  let rv = Lazy.force ldv_rv in
  let m = Lazy.force ldv_matched in
  check_leg_semantics "Ldv/Rv" rv;
  check_leg_semantics "Ldv/Matched" m;
  (* EDGE-TAKEN first, as on Ld. *)
  Alcotest.(check bool)
    "Ldv: max_drops_seen >= 1 (the drop edge was REALLY taken)" true
    (rv.max_drops_seen >= 1);
  Alcotest.(check int) "Ldv: budget really admits one drop (cap = 1)" 1
    rv.budget.Fc.max_drops;
  Alcotest.(check int) "Ldv: max_crashes_seen = 0" 0 rv.max_crashes_seen;
  Alcotest.(check int) "Ldv: max_monkeys_seen = 0" 0 rv.max_monkeys_seen;
  Alcotest.(check int) "Ldv: crash_witness_states = 0" 0
    rv.crash_witness_states;
  Alcotest.(check int) "Ldv: Rv and Matched legs explored the SAME graph"
    (states_of rv) (states_of m);
  (* BOTH gates non-vacuous across a real drop - the configuration where the
     drop dimension meets live rv content for the first time. *)
  Alcotest.(check bool) "Ldv (P16-E): Rv gate > 0 across a real drop" true
    (gate_of rv > 0);
  (* Exact MEASURED pins LAST (new literals, §8.6). *)
  Alcotest.(check int) "Ldv: states (pinned)" P16_witness.ldv_states
    (states_of rv);
  Alcotest.(check int) "Ldv: max_drops_seen (pinned)"
    P16_witness.ldv_max_drops_seen rv.max_drops_seen;
  Alcotest.(check int)
    "Ldv: fault_free_states (pinned; the Disable_req_drop doubling of L0v's \
     116-state slice)"
    P16_witness.ldv_fault_free_states rv.fault_free_states;
  Alcotest.(check int) "Ldv/Rv: gate_states (pinned, post-drop union)"
    P16_witness.ldv_rv_gate_states (gate_of rv);
  Alcotest.(check int) "Ldv/Matched: gate_states (pinned, post-drop union)"
    P16_witness.ldv_matched_gate_states (gate_of m);
  Alcotest.(check int) "Ldv: max_uid_seen (pinned)"
    P16_witness.ldv_max_uid_seen rv.max_uid_seen;
  Alcotest.(check int) "Ldv: max_rv_seen (pinned)" P16_witness.ldv_max_rv_seen
    rv.max_rv_seen

let test_ldv_members () =
  let reach = Lazy.force ldv_reach in
  check_replica_faithful "Ldv" reach (Lazy.force ldv_rv)
    (Lazy.force ldv_matched);
  Alcotest.(check int)
    "Ldv/Rv: recomputed post-drop union gate = the leg's gate_states"
    (gate_of (Lazy.force ldv_rv))
    (union_gate rv_family reach ~slice:post_drop);
  Alcotest.(check int)
    "Ldv/Matched: recomputed post-drop union gate = the leg's gate_states"
    (gate_of (Lazy.force ldv_matched))
    (union_gate matched_family reach ~slice:post_drop);
  (* The drop dimension really is the only one live on this graph. *)
  Alcotest.(check int)
    "Ldv: no reachable state has crashes >= 1 or monkeys >= 1" 0
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         post_crash f || post_monkey f));
  let all (i : Invariants.invariant) = fires reach ~slice:all_states i in
  let post (i : Invariants.invariant) = fires reach ~slice:post_drop i in
  (* SEMANTIC first: ALL FOUR members fire at genuinely post-drop states -
     the P16-C shape cross-checked where the rv content is live - and every
     member holds everywhere. *)
  Alcotest.(check bool) "Ldv: Q1 fires POST-DROP (> 0)" true (post q1 > 0);
  Alcotest.(check bool) "Ldv: Q2 fires POST-DROP (> 0)" true (post q2 > 0);
  Alcotest.(check bool) "Ldv: Q3 fires POST-DROP (> 0)" true (post q3 > 0);
  Alcotest.(check bool) "Ldv: Q5 fires POST-DROP (> 0)" true (post q5 > 0);
  check_members_clean "Ldv" reach;
  (* The knife-edge at vct:true, with its fault-free remainder: 8 REAL error
     replies match pending with NO drop on their history - the sharpest form
     of the MD-converse caveat (712 + 8 = 720, asserted per slice). *)
  Alcotest.(check int) "Ldv: knife-edge states (pinned)"
    P16_witness.knife_edge_ldv
    (knife_edge reach ~slice:all_states);
  Alcotest.(check int) "Ldv: knife-edge post-drop slice (pinned)"
    P16_witness.knife_edge_ldv_post_drop
    (knife_edge reach ~slice:post_drop);
  Alcotest.(check int)
    "Ldv: knife-edge fault-free slice (pinned - REAL error replies, the \
     MD-converse caveat)"
    P16_witness.knife_edge_ldv_fault_free
    (knife_edge reach ~slice:fault_free);
  Alcotest.(check int) "Ldv: max in-flight cardinal over the graph (pinned)"
    P16_witness.ldv_max_in_flight_seen (max_in_flight reach);
  (* Exact MEASURED pins LAST: all-states, then post-drop. *)
  Alcotest.(check int) "Ldv: Q1 interesting count (pinned)"
    P16_witness.q1_interesting_ldv (all q1);
  Alcotest.(check int) "Ldv: Q2 interesting count (pinned)"
    P16_witness.q2_interesting_ldv (all q2);
  Alcotest.(check int) "Ldv: Q3 interesting count (pinned)"
    P16_witness.q3_interesting_ldv (all q3);
  Alcotest.(check int) "Ldv: Q5 interesting count (pinned)"
    P16_witness.q5_interesting_ldv (all q5);
  Alcotest.(check int) "Ldv: Q1 post-drop interesting count (pinned)"
    P16_witness.q1_interesting_ldv_post_drop (post q1);
  Alcotest.(check int) "Ldv: Q2 post-drop interesting count (pinned)"
    P16_witness.q2_interesting_ldv_post_drop (post q2);
  Alcotest.(check int) "Ldv: Q3 post-drop interesting count (pinned)"
    P16_witness.q3_interesting_ldv_post_drop (post q3);
  Alcotest.(check int) "Ldv: Q5 post-drop interesting count (pinned)"
    P16_witness.q5_interesting_ldv_post_drop (post q5)

(* ==== Lcv: the SUPPLEMENTARY crash-x-vct probe (P16-A's judge) ==============
   NOT a §4.6 matrix leg and never to be read as one (P16_witness's Lcv
   block): it exists because P16-A cannot be judged non-vacuously on Lc,
   whose rv content is vacuous at vct:false (P16-E). Here Q1/Q2 fire at 56
   genuinely post-crash states each and hold at every reachable state: the
   crash edge perturbs neither [network] nor [api_server] even where the rv
   members genuinely fire. *)

let test_lcv_probe () =
  let rv = Lazy.force lcv_rv in
  let m = Lazy.force lcv_matched in
  check_leg_semantics "Lcv/Rv" rv;
  check_leg_semantics "Lcv/Matched" m;
  (* The crash edge was REALLY taken (non-vacuous for its own dimension). *)
  Alcotest.(check bool) "Lcv: max_crashes_seen >= 1 (a REAL crash occurred)"
    true
    (rv.max_crashes_seen >= 1);
  Alcotest.(check int) "Lcv: max_drops_seen = 0" 0 rv.max_drops_seen;
  Alcotest.(check int) "Lcv: max_monkeys_seen = 0" 0 rv.max_monkeys_seen;
  Alcotest.(check int) "Lcv: Rv and Matched legs explored the SAME graph"
    (states_of rv) (states_of m);
  (* The zero-counter slice of this graph IS L0v's graph - the slice
     identity, asserted against the LIVE L0v leg, then pinned. *)
  Alcotest.(check int)
    "Lcv: fault_free_states = L0v's live states (slice identity)"
    (states_of (Lazy.force l0v_rv))
    rv.fault_free_states;
  let reach = Lazy.force lcv_reach in
  check_replica_faithful "Lcv" reach rv m;
  Alcotest.(check int)
    "Lcv/Rv: recomputed post-crash union gate = the leg's gate_states"
    (gate_of rv)
    (union_gate rv_family reach ~slice:post_crash);
  Alcotest.(check int)
    "Lcv/Matched: recomputed post-crash union gate = the leg's gate_states"
    (gate_of m)
    (union_gate matched_family reach ~slice:post_crash);
  let all (i : Invariants.invariant) = fires reach ~slice:all_states i in
  let post (i : Invariants.invariant) = fires reach ~slice:post_crash i in
  (* P16-A's non-vacuous judgment, SEMANTIC first: Q1 and Q2 fire at
     genuinely post-crash states and hold everywhere. *)
  Alcotest.(check bool) "Lcv (P16-A): Q1 fires POST-CRASH (> 0)" true
    (post q1 > 0);
  Alcotest.(check bool) "Lcv (P16-A): Q2 fires POST-CRASH (> 0)" true
    (post q2 > 0);
  check_members_clean "Lcv" reach;
  (* Exact MEASURED pins LAST (probe pins, never matrix pins). *)
  Alcotest.(check int) "Lcv: states (pinned)" P16_witness.lcv_states
    (states_of rv);
  Alcotest.(check int) "Lcv: crash_witness_states (pinned)"
    P16_witness.lcv_crash_witness_states rv.crash_witness_states;
  Alcotest.(check int) "Lcv: fault_free_states (pinned = L0v's states)"
    P16_witness.lcv_fault_free_states rv.fault_free_states;
  Alcotest.(check int) "Lcv/Rv: gate_states (pinned)"
    P16_witness.lcv_rv_gate_states (gate_of rv);
  Alcotest.(check int) "Lcv/Matched: gate_states (pinned)"
    P16_witness.lcv_matched_gate_states (gate_of m);
  Alcotest.(check int) "Lcv: max_uid_seen (pinned)"
    P16_witness.lcv_max_uid_seen rv.max_uid_seen;
  Alcotest.(check int) "Lcv: max_rv_seen (pinned)" P16_witness.lcv_max_rv_seen
    rv.max_rv_seen;
  Alcotest.(check int) "Lcv: max in-flight cardinal over the graph (pinned)"
    P16_witness.lcv_max_in_flight_seen (max_in_flight reach);
  Alcotest.(check int) "Lcv: Q1 interesting count (pinned)"
    P16_witness.q1_interesting_lcv (all q1);
  Alcotest.(check int) "Lcv: Q2 interesting count (pinned)"
    P16_witness.q2_interesting_lcv (all q2);
  Alcotest.(check int) "Lcv: Q3 interesting count (pinned)"
    P16_witness.q3_interesting_lcv (all q3);
  Alcotest.(check int) "Lcv: Q5 interesting count (pinned)"
    P16_witness.q5_interesting_lcv (all q5);
  Alcotest.(check int) "Lcv: Q1 post-crash interesting count (pinned)"
    P16_witness.q1_interesting_lcv_post_crash (post q1);
  Alcotest.(check int) "Lcv: Q2 post-crash interesting count (pinned)"
    P16_witness.q2_interesting_lcv_post_crash (post q2)

let () =
  Alcotest.run "p16_req_resp"
    [
      ( "l0_floor",
        [
          Alcotest.test_case
            "L0: both lists clean + decisive, fault-free (Rv gate pinned as \
             content-vacuity)"
            `Quick test_l0_legs;
          Alcotest.test_case
            "L0: per-member exercise (Q5 fires; Q1/Q2/Q3 P16-E zeros)" `Quick
            test_l0_members;
        ] );
      ( "lc_crash",
        [
          Alcotest.test_case
            "Lc: clean + decisive ACROSS a real crash (P16-B density, not \
             collapse)"
            `Quick test_lc_legs;
          Alcotest.test_case
            "Lc: per-member counts (Q5 post-crash re-arming; knife-edge 4 \
             REAL error replies)"
            `Quick test_lc_members;
        ] );
      ( "ld_drop",
        [
          Alcotest.test_case
            "Ld: FIRST drop edge in a decisive leg; clean = NEGATIVE result \
             (P16-C leg half)"
            `Quick test_ld_legs;
          Alcotest.test_case
            "Ld: knife-edge 384, all post-drop - matching premise reached, \
             only is_ok blocks"
            `Quick test_ld_members;
        ] );
      ( "lm_monkey",
        [
          Alcotest.test_case
            "Lm: FIRST monkey edge in a decisive leg; second-writer uid/rv \
             signature (P16-D leg half)"
            `Quick test_lm_legs;
          Alcotest.test_case
            "Lm: per-member counts (Q2 zero = the disclosed MS matrix gap)"
            `Quick test_lm_members;
        ] );
      ( "l0v_vct",
        [
          Alcotest.test_case
            "L0v: vct:true de-vacuifies Q1/Q2/Q3 (P16-E measured, not argued)"
            `Quick test_l0v_legs;
          Alcotest.test_case
            "L0v: per-member counts all nonzero; knife-edge 4 with zero \
             faults"
            `Quick test_l0v_members;
        ] );
      ( "ldv_vct_drop",
        [
          Alcotest.test_case
            "Ldv: real drop edge with non-vacuous rv content (both gates \
             live)"
            `Quick test_ldv_legs;
          Alcotest.test_case
            "Ldv: per-member + knife-edge 720/712/8 (the MD-converse caveat \
             measured)"
            `Quick test_ldv_members;
        ] );
      ( "lcv_supplementary",
        [
          Alcotest.test_case
            "Lcv PROBE (not a matrix leg): P16-A judged non-vacuously - \
             Q1/Q2 fire post-crash and hold"
            `Quick test_lcv_probe;
        ] );
    ]

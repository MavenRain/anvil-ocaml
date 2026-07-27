(* BUILD-SPEC-P16 §4.6 / §4.7: the SINGLE SOURCE OF TRUTH for the P16
   request/response correspondence witness - the bound, the shape, the four
   matrix budgets, and every pinned MEASURED number of the §4.6 legs
   (L0 / Lc / Ld / Lm at [vct:false]; L0v / Ldv at [vct:true]), their
   per-member [interesting] counts, the P16-C knife-edge probe counts, and
   the SUPPLEMENTARY crash-x-vct probe Lcv. A shared non-test module (not in
   the [dune] [(names ...)] list, so dune links it into every test exe),
   following the [p15_witness.ml] / [p14_witness.ml] / [p13_witness.ml]
   precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. [t_p16_req_resp] reads every
   count from here and re-types none of them.
   ([lib/checker/fault_check.mli]'s prose disclosure of the same runs is
   documentation, not a second assertion site.)

   EACH LIST IS PINNED SEPARATELY (BUILD-SPEC-P16 §4.4): every leg names its
   [list_select] - [Rv_list] (Q1-Q2, network + etcd guarded) or
   [Matched_list] (Q3 + Q5, reconcile-coupled) - and the two lists share a
   product graph but never a gate pin. A clean [Rv_list] verdict at
   [vct:false] is CONTENT-VACUOUS (P16-E: its members' [interesting] is 0
   everywhere) and every such pin below says so; the non-vacuous rv evidence
   lives on the [vct:true] graphs.

   RETUNE DISCLOSURE (BUILD-SPEC-P16 §5 directs a RE-measurement of
   [max_in_flight] ON THE MONKEY LEG SPECIFICALLY - a monkey edge INJECTS a
   message without consuming one, so P14/P15's non-retune must not be
   inherited). {!p16_bound} is [P15_witness.p15_bound] UNCHANGED, itself
   P13's shape unchanged - THREE phases on one bound now. MEASURED: the
   largest [Message.Pool.cardinal] anywhere is {!lc_max_in_flight_seen} =
   {!lm_max_in_flight_seen} = 2 (Lc / Lm / Lcv graphs) and 1 on the other
   four graphs, against the ceiling 8; [max_rv_seen] peaks at 4 against
   [rv_ceiling] 6 and [max_uid_seen] at 4 against [uid_ceiling] 6 (both on
   Lm and the vct graphs). The §5 monkey orphan-inflation worry did NOT
   bind; no retune. All fourteen leg runs close sub-second against the
   ~150 s harness alarm.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   wildcard match on a finite sum. *)

module Fc = Anvil_checker.Fault_check

(* The P13 crash-only shape, unretuned through THREE phases now (see the
   disclosure above): [reconcile_ceiling = 2] on the P12 base. *)
let p16_bound ~(desireds : int list) : Bound.t = P15_witness.p15_bound ~desireds

(* The single-CR witness shape and depth, shared with P13, P14 AND P15 so the
   [vct:false] legs explore the SAME product graphs those phases pinned and
   cross-check on their counts (BUILD-SPEC-P16 §4.6). The [vct:true] legs are
   a DIFFERENT scenario and share nothing (§8.6). *)
let witness_desired : int = P15_witness.witness_desired
let witness_depth : int = P15_witness.witness_depth

(* ==== the §4.6 matrix budgets ==============================================
   Four legs at [vct:false], identical except for seed flag + budget; each
   nonzero budget puts exactly ONE fault dimension under test:
     L0 zero      {0;0;0}  non-vacuity floor, fault-free
     Lc crash     {1;0;0}  P16-A / P16-B
     Ld drop      {0;1;0}  first drop edge in a decisive leg (P16-C leg half)
     Lm monkey    {0;0;1}  first monkey edge in a decisive leg (P16-D leg half)
   plus L0v (zero) and Ldv (drop) at [vct:true] (P16-E's de-vacuation half).
   All four DERIVED from prior witnesses, never re-typed. *)

let zero_budget : Fc.budget = P13_witness.zero_budget
let lc_budget : Fc.budget = P13_witness.witness_budget
let ld_budget : Fc.budget = P15_witness.l2_budget
let lm_budget : Fc.budget = P15_witness.l3_budget

(* ==== L0: zero-budget control, vct:false (§4.6) ============================ *)

(* [check_req_resp_under_faults ~depth (p16_bound ~desireds:[witness_desired])
   zero_budget ~desired:witness_desired ~list_select ~require_fault:false],
   once per list. MEASURED: both lists [No_counterexample], decisive, both
   pruning flags true. DERIVED, not re-typed - the load-bearing graph
   IDENTITY P14's G1 and P15's L0 used: the product graph depends only on
   (seed, bound, budget, depth), never on the invariant checked over it, and
   this leg uses P13's G1 seed, bound and depth exactly. With all three caps
   at 0 the graph IS the fault-free slice of P13's G1 graph: 76 states. The
   leg test ASSERTS the identity against the live run (the no-seed-drift
   cross-check BUILD-SPEC-P16 §4.6 makes mandatory). *)
let l0_states : int = P13_witness.g1_fault_free_states

(* MEASURED 0: the [Rv_list] gate. CONTENT-VACUOUS, pinned as such and never
   as a pass (P16-E measured: no [Get_request] is ever issued at [vct:false],
   so Q1/Q2's [interesting] fires nowhere and L0/Rv verifies NOTHING about
   their content). *)
let l0_rv_gate_states : int = 0

(* MEASURED 4: the [Matched_list] gate - Q5 (the sole non-vacuous member at
   [vct:false]) fires at 4 of the 76 states. *)
let l0_matched_gate_states : int = 4

(* Achieved maxima and in-flight peak on the 76-state graph: DERIVED from
   P15's L0 pins - same seed, bound, budget and depth, hence the same graph
   and the same graph-only counts. *)
let l0_max_uid_seen : int = P15_witness.l0_max_uid_seen
let l0_max_rv_seen : int = P15_witness.l0_max_rv_seen
let l0_max_in_flight_seen : int = P15_witness.l0_max_in_flight_seen

(* -- per-member [interesting]-fires counts on L0's 76 states ----------------
   MEASURED over the leg's own replica, never predicted. The three zeros are
   P16-E's vacuity floor, measured not argued: the [vct:false] seed builds
   its CR without a volumeClaimTemplate, so the reconciler's PVC arm - the
   only [Get_request] producer - is unreachable and no OK get response can
   ever exist. Q5 (create responses) is the sole non-vacuous member. *)
let q1_interesting_l0 : int = 0
let q2_interesting_l0 : int = 0
let q3_interesting_l0 : int = 0
let q5_interesting_l0 : int = 4

(* MEASURED 0: the P16-C knife-edge probe (states holding an in-flight
   Error-bodied api RESPONSE that satisfies [Message.resp_msg_matches_req_msg]
   against some ongoing reconcile's pending request) finds NOTHING on the
   fault-free graph - the baseline the Lc/Ld/Lm counts are read against. *)
let knife_edge_l0 : int = 0

(* ==== Lc: crash-only {1;0;0}, vct:false - P16-A / P16-B ==================== *)

(* [~require_fault:true], once per list. MEASURED: both lists
   [No_counterexample], decisive, crash edge REALLY taken. DERIVED by the
   graph identity: same seed / bound / budget / depth as P13's G1, P14's G2
   and P15's L1 legs, so the reachable product set is literally theirs
   (464 / 388 / 76, uid 3, rv 2, crashes 1, in-flight peak 2). Only the
   asserted list differs, hence only the gates and outcome can differ. The
   FOUR phases now cross-check on these pins. *)
let lc_states : int = P13_witness.g1_states
let lc_crash_witness_states : int = P13_witness.g1_crash_witness_states
let lc_fault_free_states : int = P13_witness.g1_fault_free_states
let lc_max_uid_seen : int = P13_witness.g1_max_uid_seen
let lc_max_rv_seen : int = P13_witness.g1_max_rv_seen
let lc_max_crashes_seen : int = P13_witness.g1_max_crashes_seen
let lc_max_in_flight_seen : int = P15_witness.l1_max_in_flight_seen

(* MEASURED 0: content-vacuous exactly as L0/Rv (P16-E). P16-A is therefore
   NOT judged on this gate: its non-vacuous evidence is the supplementary
   Lcv probe below. *)
let lc_rv_gate_states : int = 0

(* MEASURED 32: post-crash states where Q3 or Q5 fires. P16-B's sub-clause
   measured AGAINST as worded: the post-crash slice of the gate does NOT
   collapse in aggregate - it is DENSER than the fault-free slice (32/388 vs
   4/76, the re-arming signature P15's own pinned L1 shows). The vacuation is
   PER CRASH INSTANT (the crash empties [ongoing_reconciles]; the firing
   states are post-restart), and the leg test asserts the density form. *)
let lc_matched_gate_states : int = 32

(* -- per-member counts on Lc's 464 states ----------------------------------- *)
let q1_interesting_lc : int = 0
let q2_interesting_lc : int = 0
let q3_interesting_lc : int = 0
let q5_interesting_lc : int = 36
let q5_interesting_lc_post_crash : int = 32

(* MEASURED 4: knife-edge states on Lc - REAL, non-fabricated Error responses
   (post-crash create-conflict replay) matching a pending request with NO
   drop edge in the model at all. All 4 are post-crash (the fault-free slice
   is L0's graph, where the count is 0 - asserted live). This is the
   MD-converse caveat: "error response matching pending" must never be
   equated with "drop edge taken". *)
let knife_edge_lc : int = 4

(* ==== Ld: drop-only {0;1;0}, req_drop:true, vct:false - P16-C leg half ===== *)

(* [~req_drop:true ~require_fault:true], once per list. MEASURED: both lists
   [No_counterexample], decisive, and [max_drops_seen = 1] - THE FIRST DROP
   EDGE EVER TAKEN IN A DECISIVE LEG in this repo (BUILD-SPEC-P16 §1,
   F2-corrected: P13 built the machinery, and [check_settles_after_disable]
   has seeded all three fault flags since P13, but its one shipped run used
   [budget_crash_only] - p13_witness.ml:53 - so no shipped leg RUN ever
   took the edge). A CLEAN drop
   leg is a NEGATIVE result (§8.4) and these pins record exactly that.
   DERIVED by the graph identity with P15's SUPPLEMENTARY flag-enabled L2x
   probe (same seed flags, bound, budget {0;1;0} and depth - what was a
   probe there is a leg here): 744 states, drop edge taken once, in-flight
   peak 1. *)
let ld_states : int = P15_witness.l2x_states
let ld_max_drops_seen : int = P15_witness.l2x_max_drops_seen
let ld_max_in_flight_seen : int = P15_witness.l2x_max_in_flight_seen

(* DERIVED = P15's flag-ON zero-budget control (152): the zero-fault-counter
   slice of Ld's graph IS that control graph - the enabled [req_drop] flag
   adds the [Disable_req_drop_step] dimension to the slice, doubling L0's 76.
   NOT seed drift (L0 pins 76 exactly); the leg test asserts the identity. *)
let ld_fault_free_states : int = P15_witness.l2x_control_states

(* Achieved maxima on Ld's graph: MEASURED literals (P15 pinned no maxima for
   the L2x probe). Their equality with L0's is a scenario coincidence - the
   counters are driven by the fault-free prefix - so deriving them would
   assert something untrue. *)
let ld_max_uid_seen : int = 3
let ld_max_rv_seen : int = 2

(* MEASURED 0: content-vacuous as on every vct:false graph (P16-E). *)
let ld_rv_gate_states : int = 0

(* MEASURED 16: post-drop states where Q5 fires - Q5 is exercised across a
   REAL drop edge and holds. *)
let ld_matched_gate_states : int = 16

(* -- per-member counts on Ld's 744 states ----------------------------------- *)
let q1_interesting_ld : int = 0
let q2_interesting_ld : int = 0
let q3_interesting_ld : int = 0
let q5_interesting_ld : int = 24
let q5_interesting_ld_post_drop : int = 16

(* MEASURED 384, THE PHASE'S KNIFE-EDGE (P16-C): 384 of Ld's 744 states hold
   a fabricated Error-bodied response satisfying [resp_msg_matches_req_msg]
   against an ongoing reconcile's pending request - the fabricated drop
   response inherits the request's [rpc_id], so the MATCHING premise of
   Q3/Q5 is genuinely reached and ONLY the [is_ok] conjunct keeps their
   antecedents false ([form_matched_err_resp_msg] fabricates [Error] on all
   nine arms). ALL 384 are in the [drops >= 1] slice and the count is 0 on
   L0's graph, so on THIS graph the knife-edge is entirely drop-attributable
   (the leg test asserts both slice facts live). Mutation MD flips exactly
   this conjunct; the flip is the mutation stage's to measure. *)
let knife_edge_ld : int = 384

(* ==== Lm: monkey-only {0;0;1}, pod_monkey:true, vct:false - P16-D leg half = *)

(* [~pod_monkey:true ~require_fault:true], once per list. MEASURED: both
   lists [No_counterexample], decisive, and [max_monkeys_seen = 1] - the
   first monkey edge in a decisive leg. A clean monkey leg is likewise a
   NEGATIVE result (§8.4). DERIVED by the graph identity with P15's L3x
   probe: 1976 states, monkey edge taken once, in-flight peak 2 (the §5
   re-measurement's binding site - still four times under the ceiling 8). *)
let lm_states : int = P15_witness.l3x_states
let lm_max_monkeys_seen : int = P15_witness.l3x_max_monkeys_seen
let lm_max_in_flight_seen : int = P15_witness.l3x_max_in_flight_seen

(* DERIVED = P15's monkey-flag-ON zero-budget control (152): same doubling
   mechanism as {!ld_fault_free_states}, [Disable_pod_monkey_step] flavor. *)
let lm_fault_free_states : int = P15_witness.l3x_control_states

(* MEASURED 4 and 4 - STRICTLY above the 3 / 2 of L0/Lc/Ld, and that
   excess IS P16-D's second-writer mechanism made visible: a real
   [Api_server_step] applied the monkey's injected create (the monkey itself
   writes neither etcd nor [s.api_server]; the etcd write is TRANSITIVE),
   minting one more uid and bumping the rv counter twice. The leg test
   asserts the strict excess semantically before pinning the values. *)
let lm_max_uid_seen : int = 4
let lm_max_rv_seen : int = 4

(* MEASURED 0: content-vacuous (P16-E). NOTE THE MATRIX GAP this implies for
   mutation MS (P16-D's second half): Q2's [interesting] is 0 on Lm at
   [vct:false], so "MS refutes Q2 on Lm and ONLY on Lm" cannot fire through
   Q2's premise on the matrix's own Lm - the mutation stage needs a
   [vct:true] monkey probe (Lmv) or a re-reading of where MS's witness can
   live. Disclosed here rather than smoothed over. *)
let lm_rv_gate_states : int = 0

(* MEASURED 80: post-monkey states where Q5 fires. *)
let lm_matched_gate_states : int = 80

(* -- per-member counts on Lm's 1976 states ---------------------------------- *)
let q1_interesting_lm : int = 0
let q2_interesting_lm : int = 0
let q3_interesting_lm : int = 0
let q5_interesting_lm : int = 88
let q5_interesting_lm_post_monkey : int = 80

(* MEASURED 24: more real Error responses matching a pending request with no
   drop edge in the model (monkey-request rejections) - the second leg of
   the MD-converse caveat recorded at {!knife_edge_lc}. *)
let knife_edge_lm : int = 24

(* ==== L0v: zero-budget, vct:TRUE - P16-E's de-vacuation half ===============
   A DIFFERENT scenario (the CR carries a volumeClaimTemplate, so the PVC
   arm, [Get_request]s and OK get responses become reachable): counts NOT
   comparable with any committed P13/P14/P15 pin (BUILD-SPEC-P16 §8.6), so
   every number here is a NEW literal. MEASURED: both lists clean, decisive,
   both pruning flags true. *)

let l0v_states : int = 116

(* MEASURED 4 / 12: the [Rv_list] gate is NON-vacuous for the first time -
   Q1/Q2 genuinely fire at [vct:true] (P16-E's positive half). *)
let l0v_rv_gate_states : int = 4
let l0v_matched_gate_states : int = 12
let l0v_max_uid_seen : int = 4
let l0v_max_rv_seen : int = 3
let l0v_max_in_flight_seen : int = 1

(* -- per-member counts on L0v's 116 states: all four members non-vacuous. -- *)
let q1_interesting_l0v : int = 4
let q2_interesting_l0v : int = 4
let q3_interesting_l0v : int = 4
let q5_interesting_l0v : int = 8

(* MEASURED 4: real Error responses matching pending exist even fault-FREE at
   [vct:true] - the third leg of the MD-converse caveat. *)
let knife_edge_l0v : int = 4

(* ==== Ldv: drop-only {0;1;0}, req_drop:true, vct:TRUE ====================== *)

(* MEASURED: both lists clean, decisive, [max_drops_seen = 1] - the drop
   dimension measured WITH non-vacuous rv content (the leg P16-C's mechanism
   claim is cross-checked on). New literals throughout (§8.6). *)
let ldv_states : int = 1832

(* MEASURED 232: the [Disable_req_drop_step] doubling of L0v's 116-state
   zero-counter slice - same mechanism as {!ld_fault_free_states}, measured
   directly on this graph rather than derived (no prior pin exists for the
   vct:true control). *)
let ldv_fault_free_states : int = 232
let ldv_max_drops_seen : int = 1
let ldv_max_uid_seen : int = 4
let ldv_max_rv_seen : int = 3
let ldv_max_in_flight_seen : int = 1

(* MEASURED 16 / 96: BOTH gates non-vacuous across a real drop edge. *)
let ldv_rv_gate_states : int = 16
let ldv_matched_gate_states : int = 96

(* -- per-member counts on Ldv's 1832 states, all-states / post-drop --------- *)
let q1_interesting_ldv : int = 24
let q2_interesting_ldv : int = 24
let q3_interesting_ldv : int = 24
let q5_interesting_ldv : int = 96
let q1_interesting_ldv_post_drop : int = 16
let q2_interesting_ldv_post_drop : int = 16
let q3_interesting_ldv_post_drop : int = 16
let q5_interesting_ldv_post_drop : int = 80

(* MEASURED 720 / 712 / 8: knife-edge states on Ldv, all-states / post-drop /
   fault-free. The 8 fault-free ones are REAL Error responses (no drop edge
   on their history at all) - the sharpest form of the MD-converse caveat,
   and the reason MD's control must gate on the [drops >= 1] slice, never on
   the bare knife-edge predicate. 712 + 8 = 720 partitions the count exactly
   (drops is the only nonzero counter on this graph; asserted live). *)
let knife_edge_ldv : int = 720
let knife_edge_ldv_post_drop : int = 712
let knife_edge_ldv_fault_free : int = 8

(* ==== Lcv: SUPPLEMENTARY crash-x-vct probe (NOT a §4.6 matrix leg) =========
   [lc_budget], [~vct:true], [~require_fault:true], once per list. Run for
   ONE purpose: P16-A cannot be judged non-vacuously on Lc (its rv content
   is vacuous at [vct:false], P16-E), so this probe re-runs the crash leg
   where Q1/Q2 genuinely fire. It is pinned here AS A PROBE, following the
   L2x/L3x precedent of [p15_witness.ml], and must never be read as a §4.6
   matrix result. MEASURED: both lists clean, decisive, crash REALLY taken
   ([max_crashes_seen = 1] against cap 1), both pruning flags true. *)

let lcv_states : int = 1136
let lcv_crash_witness_states : int = 1020

(* DERIVED = {!l0v_states}: the zero-counter slice of Lcv's graph IS L0v's
   zero-budget graph (the same slice identity every phase since P13 has
   used); the probe test asserts it against both live runs. *)
let lcv_fault_free_states : int = l0v_states
let lcv_rv_gate_states : int = 56
let lcv_matched_gate_states : int = 132
let lcv_max_uid_seen : int = 4
let lcv_max_rv_seen : int = 3
let lcv_max_in_flight_seen : int = 2

(* -- per-member counts on Lcv's 1136 states ---------------------------------
   Q1/Q2's post-crash 56s are P16-A's actual evidence: the crash edge
   perturbs neither [network] nor [api_server] at states where the rv
   members GENUINELY fire, and both hold at every one. (Q3/Q5 post-crash
   counts were not measured by the measurement stage, so no such pin exists
   here and the probe test asserts none.) *)
let q1_interesting_lcv : int = 60
let q2_interesting_lcv : int = 60
let q3_interesting_lcv : int = 28
let q5_interesting_lcv : int = 116
let q1_interesting_lcv_post_crash : int = 56
let q2_interesting_lcv_post_crash : int = 56

(* ==== Lmv: SUPPLEMENTARY monkey-x-vct probe (MUTATION stage; NOT a §4.6
   matrix leg) ================================================================
   [lm_budget], [~pod_monkey:true ~vct:true], [Rv_list],
   [~require_fault:true]. Run for ONE purpose (BUILD-SPEC-P16 §6's MS row):
   Q2's [interesting] is MEASURED 0 on Lm at [vct:false] (the matrix gap
   {!lm_rv_gate_states} discloses), so "MS refutes Q2 on the monkey leg"
   is only observable where Q2 genuinely fires under a real monkey edge -
   this graph. Pinned here AS A PROBE, following the Lcv precedent, and
   never read as a §4.6 matrix result. MEASURED by [t_p16_mutation]:
   clean, decisive, monkey edge really taken; Q2 fires on the graph AND on
   its [monkeys >= 1] slice (the gap closed); MS measured INERT against all
   of it (the mutation-stage header records the diagnosis). *)

let lmv_states : int = 3224
let lmv_max_monkeys_seen : int = 1

(* -- Q2's [interesting]-fires counts on Lmv, all-states / post-monkey ------- *)
let q2_interesting_lmv : int = 216
let q2_interesting_lmv_post_monkey : int = 208

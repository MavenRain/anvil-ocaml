(* BUILD-SPEC-P25 section 3.1 / 3.3 - the SINGLE SOURCE OF TRUTH for the P25
   E3 multi-CR witness: the two committed multi-CR graphs (P12's fair [1;1]
   at p12_bound, reconcile_ceiling 3; P13's G2 crash [1;1] at p13_bound,
   reconcile_ceiling 2) REBUILT with the exact committed seed / bound /
   budget / depth their pins were measured with, and the six E3 counts
   computed over them with the SHIPPED
   {!Anvil_assurance.Internal_guarantee.local_pods_and_pvcs_are_bound_to_vsts}
   value (E3, upstream internal_rely_guarantee.rs:606-611, landed by P25
   stage A). A shared non-test module (deliberately NOT in [test/dune]'s
   [(names ...)] list, so dune compiles it once and links it only into the
   test exes that reference it), following the [p24_witness.ml] /
   [p23_witness.ml] / [p12_witness.ml] precedent.

   UNLIKE the prior witness modules, the six E3 values below are COMPUTED at
   module initialization from the rebuilt graphs, not typed literals
   (BUILD-SPEC-P25 section 3.1's stated shape, mirroring the selection
   probe t_p25_probe_e3.SOURCE.ml): the expected literals (8580 / 8536 / 0,
   10552 / 9200 / 0) live in [t_p25_e3_multi_cr.ml] ALONE, so no pinned
   number appears in two files and "fix the red by editing the witness"
   still has to redden there. The two explorations run eagerly when this
   module is linked (roughly the committed P12 + P13-G2 costs); an exe that
   references ANY value below pays both - the three referencing exes
   (t_p25_e3_multi_cr, t_p25_reconcile, t_p25_state_predicates) each do.

   ==== STATUS OF THIS MODULE, STATED HONESTLY ==============================
   All three pin sets BUILD-SPEC-P25 names for this file are NOW PRESENT,
   each landed by its own stage: the E3 multi-CR leg (computed, above the
   split), the LEG3/LEG4 battery pins (typed literals, landed at battery
   time), and the stage-B :256 class-d / complement / effective-premise
   quads plus the two L0v occupancy literals (sections 1.2 / 1.3, landed
   with [t_p25_state_predicates] after its C1 probe ran and the :246
   equality HELD on every premise state - Outcome A). The
   computed-vs-literal split stays explicit: everything above the LEG3
   comment is computed from the rebuilt graphs, everything below is a
   typed literal asserted by exactly one registered exe.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   exceptions, no two-arm match on Option/Result, no wildcard match on a
   finite sum, no raw indexing. *)

module Cc = Anvil_checker.Cluster_check
module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Ig = Anvil_assurance.Internal_guarantee

(* The scenario controller and cluster every committed multi-CR pin was
   measured against (the selection probe used the same pair). *)
let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster

(* The exploration depth every committed P12/P13 pin was measured at
   (= Cluster_check.default_depth = Fault_check.default_depth), passed
   explicitly so each count names the dimension bounding it. *)
let witness_depth : int = 40

(* ==== the fair graph: P12's [1;1] witness, byte-for-byte the committed
   construction (P12_witness.p12_bound, reconcile_ceiling = 3 at [1;1];
   Scenario.vsts_seed_multi ~fair:true; depth 40). Its committed size is
   8580 states (t_p12_concurrent.ml:18,:21 - prose-committed, asserted as a
   literal by t_p25_e3_multi_cr) and its committed inv6 gate pin is 6952
   (p12_witness.ml:30). ==== *)

(* P12's own bound at the [1;1] witness - derived, never re-typed. *)
let fair_bound : Bound.t = P12_witness.p12_bound ~desireds:[ 1; 1 ]

(* P12's own fair multi-CR seed: two 1-replica CRs, the cheapest
   >= 2-concurrent seed (p12_witness.ml:26). *)
let fair_seed : Cluster.cluster_state =
  Scenario.vsts_seed_multi ~desireds:[ 1; 1 ] ~fair:true

(* The rebuilt fair reachable graph. *)
let fair_reach : Cluster.cluster_state Mc.reachable =
  Mc.explore ~depth:witness_depth
    ~successors:(Cc.bounded_successors fair_bound cluster)
    ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ fair_seed ]

(* ==== the crash graph: P13's G2 [1;1] witness, byte-for-byte the committed
   construction (P13_witness.p13_bound, the retuned reconcile_ceiling = 2;
   Scenario.vsts_seed_multi_faults ~crash:true only; Fc.budget_crash_only;
   depth 40). Its committed pins are g2_states = 10552 and g2_gate_states =
   2784 (p13_witness.ml:82-83). ==== *)

(* P13's own bound at the [1;1] witness - derived, never re-typed. *)
let crash_bound : Bound.t = P13_witness.p13_bound ~desireds:[ 1; 1 ]

(* P13's own crash-only multi-CR seed: the crash dimension ISOLATED, as
   every shipped P13 G2 pin was measured (p13_witness.ml:50-53). *)
let crash_seed : Cluster.cluster_state =
  Scenario.vsts_seed_multi_faults ~desireds:[ 1; 1 ] ~crash:true
    ~req_drop:false ~pod_monkey:false

(* The rebuilt crash-only faulted product graph. *)
let crash_reach : Fc.faulted Mc.reachable =
  Mc.explore ~depth:witness_depth
    ~successors:(Fc.faulted_successors crash_bound Fc.budget_crash_only cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed crash_seed ]

(* ==== E3, the SHIPPED value (never a local duplicate): stage A's standalone
   [Invariants.invariant] in lib/assurance/internal_guarantee.ml, the LIFT
   of L2/E5 over every VSTS-kind key of [Cluster.ongoing_reconciles] via
   [Local_binding.holds_at_key]. ==== *)

(* The invariant under witness. *)
let e3 : Invariants.invariant =
  Ig.local_pods_and_pvcs_are_bound_to_vsts ~controller_id

(* ==== the six computed E3 values (BUILD-SPEC-P25 section 3.3's pin names;
   expected literals asserted by t_p25_e3_multi_cr only) ==== *)

(* Fair graph size - the derivation guard target for t_p12_concurrent's
   committed 8580. *)
let fair_states : int = Mc.states_seen fair_reach

(* Fair states where E3's OWN premise mirror fires (a VSTS-kind ongoing
   key exists) - non-vacuity of the lift on the fair graph. *)
let fair_e3_premise : int =
  Mc.count_states_where fair_reach e3.Invariants.interesting

(* Fair states violating E3 - expected 0 (E3 holds on the committed graph). *)
let fair_e3_violating : int =
  Mc.count_states_where fair_reach (fun (s : Cluster.cluster_state) ->
      not (e3.Invariants.holds s))

(* Crash graph size - the derivation guard target for P13_witness.g2_states. *)
let crash_states : int = Mc.states_seen crash_reach

(* Crash states where E3's premise fires, projecting [Fc.faulted -> .cs] the
   way t_p13_faults.ml does. *)
let crash_e3_premise : int =
  Mc.count_states_where crash_reach (fun (f : Fc.faulted) ->
      e3.Invariants.interesting f.Fc.cs)

(* Crash states violating E3 - expected 0. *)
let crash_e3_violating : int =
  Mc.count_states_where crash_reach (fun (f : Fc.faulted) ->
      not (e3.Invariants.holds f.Fc.cs))

(* ==== graph-identity controls (NOT new pins - each is asserted ONLY
   against an already-committed P12/P13 witness pin, the derived-not-re-typed
   discipline of t_p21_regression.ml:161-178): the rebuilt graphs must still
   contain the committed inv6 gate populations, so a drifted seed/bound
   reddens the firewall case rather than silently re-measuring. ==== *)

(* P12's inv6 [every_ongoing_reconcile_has_unique_id], whose committed gate
   pins (6952 fair / 2784 crash) identify the two graphs. *)
let inv6 : Invariants.invariant =
  Invariants.unique_reconcile_id_invariant ~controller_id

(* Fair states in inv6's >= 2-concurrent gate - must equal the committed
   P12_witness.pinned_gate_states (6952). *)
let fair_inv6_gate : int =
  Mc.count_states_where fair_reach inv6.Invariants.interesting

(* Crash states in P13 G2's gate (>= 2-concurrent AFTER a crash) - must
   equal the committed P13_witness.g2_gate_states (2784). *)
let crash_inv6_crash_gate : int =
  Mc.count_states_where crash_reach (fun (f : Fc.faulted) ->
      inv6.Invariants.interesting f.Fc.cs && f.Fc.crashes >= 1)

(* ==== LEG3 / LEG4 battery pins (BUILD-SPEC-P25 section 1.4; appended at
   battery-write time, as the status header above anticipates). These are
   TYPED LITERALS, not computed values - the module's computed-vs-literal
   split, kept explicit: everything above this block is computed from the
   rebuilt graphs, everything below is a fresh-measured battery pin. *)

(* One row per registered t_p2* exe in test/dune's [(names ...)] list,
   INCLUDING the battery itself. The count metric is textual and fresh
   (2026-08-03): occurrences in test/<name>.ml of the registration call
   written as one token ("Alcotest." immediately followed by "test_case").
   t_p25_reconcile's LEG3 re-counts every file at run time and holds it
   against this list in BOTH directions (an exe without a pin and a pin
   without an exe both redden) - the shadowed-registration guard's counting
   half at whole-tree scope. *)
let leg3_case_counts : (string * int) list =
  [
    ("t_p20_mutation", 12);
    ("t_p20_regression", 7);
    ("t_p20_rely", 14);
    ("t_p21_guarantee", 9);
    ("t_p21_mutation", 6);
    ("t_p21_regression", 6);
    ("t_p22_mutation", 4);
    ("t_p22_regression", 4);
    ("t_p22_scaledown", 7);
    ("t_p23_local_binding", 11);
    ("t_p23_mutation", 8);
    ("t_p23_regression", 6);
    ("t_p24_mutation", 7);
    ("t_p24_regression", 7);
    ("t_p24_state_predicates", 12);
    ("t_p25_e3_multi_cr", 4);
    ("t_p25_reconcile", 5);
    ("t_p25_state_predicates", 4);
  ]

(* The exact number of upstream anvil-ref cite pins LEG4 must check when
   the ref tree is present - the "0 XOR K, never some" gate (BUILD-SPEC-P25
   section 1.4): an absent tree reds LOUDLY as 0 of K, and a silently
   shrunken pin list reds against this count. *)
let leg4_upstream_cite_count : int = 11

(* ==== stage-B pins (BUILD-SPEC-P25 sections 1.2 / 1.3; landed with
   [t_p25_state_predicates], which recomputes every number below from its
   own rebuilt graphs - the four P24 SP replicas and P18's committed L0v -
   and asserts these literals against the fresh measurement, so "fix the
   red by editing the witness" still reddens there). The :256 quads are
   keyed by graph label so a dropped row reddens the consumer's shape
   assertion. Every value below is a TYPED LITERAL on the literal side of
   the split. *)

(* :256 [local_state_is_coherent_with_etcd] class-(d) set-equality failure
   populations per graph: at EVERY pinned set-equality fail state there is
   NO write of any kind in flight (classes a/b/c all measured zero). *)
let set_eq_class_d : (string * int) list =
  [ ("SP0", 0); ("SPc", 8); ("SPd", 0); ("SPm", 72) ]

(* :256 class-(d) coherence failure populations per graph. *)
let coherence_class_d : (string * int) list =
  [ ("SP0", 0); ("SPc", 4); ("SPd", 0); ("SPm", 40) ]

(* The over-exclusion complement: PASSING states carrying a rely-violating
   write in flight anyway - a guard keyed on "rely-violating write in
   flight" would wrongly exclude every one of them while rescuing none of
   the class-(d) failures. *)
let over_exclusion_complement : (string * int) list =
  [ ("SP0", 0); ("SPc", 0); ("SPd", 0); ("SPm", 144) ]

(* The effective premise of a rely-scoped restoration: ok-list-response in
   flight AND no rely-violating write in flight. *)
let rely_effective_premise : (string * int) list =
  [ ("SP0", 8); ("SPc", 60); ("SPd", 48); ("SPm", 672) ]

(* The two L0v occupancy literals (section 1.3's pin discipline: only these
   two flip a decision, everything else stays spec-recorded). *)
let l0v_get_pvc_family_occupancy : int = 40  (* retires the SHAPE-vacuity premise on L0v *)
let l0v_246_premise_nonvacuity : int = 8     (* drives the seven->eight doc fix; gates C1 *)

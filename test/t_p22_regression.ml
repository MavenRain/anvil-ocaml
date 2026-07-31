(* BUILD-SPEC-P22 section 6 - the prior-phase firewall and the roster's
   generation step for a phase that ships NO NEW FAMILY.

   THE CLASSIFICATION, stated honestly: P22's leg
   ([Fault_check.check_scale_down_under_faults]) asserts the SHIPPED P21
   register [Internal_guarantee.guarantee_family] (G1-G4) over NEW graphs -
   deliberately no new predicate surface (BUILD-SPEC-P22 section 2, the P17
   precedent for a measurement phase). The P14-P21 disjointness obligation
   therefore DEGENERATES for exactly one roster entry: against the P21
   entry, P22's swept family is (name, source)-IDENTICAL, and this file
   keeps that degeneracy VISIBLE (the exact four-pair leak, both orders,
   committed) instead of narrowing the sweep to hide it; against the other
   TWELVE suites the sweep asserts full disjointness exactly as every
   predecessor did.

   WHAT THE IDENTITY ROW IS, AND IS NOT (P22-review finding F2, fixed here).
   The two bindings this file sweeps - [family] and the roster's
   [p21_family] - are the SAME expression
   ([Ig.guarantee_family ~cr:(Scenario.vsts ~desired ()) ~controller_id]),
   so ANY assertion comparing one against the other holds by construction
   and detects nothing; the previous wording ("asserts that identity") was
   an overclaim. This file runs no leg, reads no leg output, and therefore
   makes NO claim about what {!Fc.check_scale_down_under_faults}
   instantiates. What it does pin, with teeth, is the SHIPPED register's own
   member identity: [committed_guarantee_pairs] (and the P19/P20 coverage
   literals beside it) are COMMITTED LITERAL (name, source) pairs - the P17
   [expected_pairs] precedent, t_p17_regression.ml:170-178 - so a renamed
   member, a re-sourced citation, a re-transcribed roster row, an added or a
   dropped member each redden HERE, independent of how the register is
   implemented.

   LEG-SIDE DRIFT IS CAUGHT ELSEWHERE - AND NOT WHERE ONE WOULD GUESS.
   Should {!Fc.check_scale_down_under_faults} ever instantiate a DIFFERENT
   family or a different [cr], the red arrives in t_p22_scaledown through
   the leg-COMPUTED FAMILY GATE pins (SL0/SLc/SLd/SLm = 20/276/96/2080):
   those counts are produced INSIDE the leg (fault_check.ml's [~gate]
   closure counts the states where SOME member of the leg's own [invs] is
   [interesting]) and are pinned exactly, so they are the coupling with real
   teeth - with the leg's own clean / [violated = None] rows as a second,
   weaker one. The per-member [interesting] pins (SL0 4/4/4/20) are NOT that
   coupling: t_p22_scaledown computes them TEST-SIDE, over a local replica
   graph, off its OWN [Ig.guarantee_family] binding (t_p22_scaledown.ml's
   [family] / [member_interesting] / [fires]), and the replica's successor
   relation carries no invariant at all, so a leg that swapped families
   would leave all sixteen of those counts unmoved. Residual, stated rather
   than papered over: the gate coupling is a COUNT, so a hypothetical other
   family with an identical [interesting] union on all four graphs would
   evade it, and NO in-repo assertion reads the leg's own [invs] binding
   directly - that binding is local to [check_scale_down_under_faults] and
   unexported, so nothing outside fault_check.ml can name it.

   ---- what this file DOES --------------------------------------------------

   - THE PRIOR-PHASE FIREWALL: the P13-P21 graph literals re-typed here (the
     one sanctioned duplication - see p21_witness.ml:18-30 for the standing
     rationale) AND held against the chain {!P22_witness} claims to derive
     them from. A witness edited to make a red go away, or a derivation
     replaced by a re-typed literal that happens to agree today, reddens
     here. No P22-MEASURED number (the SL0/SLc/SLd/SLm pins) is re-typed -
     those are THIS phase's numbers and {!P22_witness} is their single
     source; t_p22_scaledown re-derives them through the shipped exe.

   - THE ROSTER, EXTENDED TO FOURTEEN AND THE SELF-EXCLUSION MOVED (the
     P20->P21 mechanism, re-run): t_p21_regression's roster was THIRTEEN
     with its own P21 entry excluded from its sweep by label. HERE the P21
     label loses its "THIS phase" marker and moves INTO the swept set -
     t_p21_regression itself is NOT edited (its roster, its self-exclusion
     and its E-ledger reversal clause stand verbatim; that clause reds only
     if P23 ships E3-E5, deliberately) - while the self-exclusion now keys
     on [p22_label].

   - THE COMMITTED MEMBER IDENTITIES: the guarantee register's four
     (name, source) pairs, and the P19/P20 registers' four and three, as
     LITERALS. [family] and [p21_family] are each checked pair-for-pair
     against the guarantee literals (order included, so a fifth member or a
     reorder reds too), and the roster's coverage rows are checked by asking
     whether the LITERALS are present in the roster's live inventory - never
     by filtering a set against itself.

   - THE SWEEP: P22's family against the other THIRTEEN roster suites via
     {!Pair_guard.pair_leaks}, BOTH argument orders. Twelve rows expect [[]]
     (fully disjoint); the P21 row expects the COMMITTED identity leak (all
     four names, family order). The two INSTANTIATIONS cannot drift apart
     from each other (one expression, bound twice); what can drift is the
     shipped register underneath them, and then the committed leak list -
     spelled from the same four literals - stops matching and this file
     reds.

   ---- what it does NOT do (anti-duplication, the P15-P21 rationale) --------

   It does NOT re-run any leg (the batteries do), does NOT model-check
   anything (pure list work, milliseconds), does NOT re-pin any P22
   MEASURED number, and does NOT duplicate t_p21_regression's E-ledger
   reversal clause - the fourteen-suite roster adds only a (name, source)
   duplicate of the P21 entry, so the clause's whole-tree conclusion is
   unchanged and its single assertion site stays in t_p21_regression.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum, no two-arm match on
   [option]/[result], total accessors only, Alcotest as the sanctioned
   failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vsts_invariants = Anvil_assurance.Vsts_invariants
module Correspondence = Anvil_assurance.Correspondence
module Rec_corr = Anvil_assurance.Reconcile_correspondence
module Rr = Anvil_assurance.Req_resp_correspondence
module Ois = Anvil_assurance.Objects_in_store
module Hi = Anvil_assurance.Helper_invariants
module Mp = Anvil_assurance.Msg_provenance
module Rely = Anvil_assurance.Rely_conditions
module Ig = Anvil_assurance.Internal_guarantee

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P22_witness.witness_desired

(* The INHERITED chain bound for the P16 suite instantiation (the rv leg's
   own bound) - NOT {!P22_witness.p22_bound}, which is the P22 leg's widened
   record and instantiates no roster suite. *)
let inherited_bound : Bound.t = P21_witness.p21_bound ~desireds:[ desired ]

(* P22's swept family: the guarantee register RE-INSTANTIATED here with the
   arguments fault_check.ml's scale-down leg passes. That the leg passes
   these arguments is NOT asserted here (this file runs no leg - see the
   header's leg-side-drift paragraph for where that is caught); what IS
   asserted, below, is that the register these arguments produce is the
   committed four (name, source) pairs. *)
let family : Invariants.invariant list =
  Ig.guarantee_family ~cr:(Scenario.vsts ~desired ()) ~controller_id

(* ==== 1. the prior-phase firewall ========================================== *)

(* The graph literals as committed on the P13-P21 branches, held against the
   witness module P22's exes actually read. P22 adds no seam to the OLD
   graphs (its bound is an own record, its seed a new function; no committed
   input edited), so these five are pure derivation guards: a drift is a
   phase-STOP, never a retune. *)

let committed_l0_states : int = 76
let committed_lc_states : int = 464
let committed_ld_states : int = 744
let committed_lm_states : int = 1976
let committed_l0v_states : int = 116

let test_p22_graph_constants_are_the_committed_literals () =
  Alcotest.(check int) "P22 L0 states = the committed 76" committed_l0_states
    P22_witness.l0_states;
  Alcotest.(check int) "P22 Lc states = the committed 464" committed_lc_states
    P22_witness.lc_states;
  Alcotest.(check int) "P22 Ld states = the committed 744" committed_ld_states
    P22_witness.ld_states;
  Alcotest.(check int) "P22 Lm states = the committed 1976" committed_lm_states
    P22_witness.lm_states;
  Alcotest.(check int) "P22 L0v states = the committed 116 (P16's, via the \
                        P18 <- P20 <- P21 chain)"
    committed_l0v_states P22_witness.l0v_states

(* The SAME constants against the chain they are DERIVED from, so a re-typed
   literal in p22_witness.ml that happens to agree with the committed value
   today still reddens the moment the phase it claims to derive from moves. *)
let test_p22_graph_constants_are_derived_not_re_typed () =
  Alcotest.(check int) "P22 L0 = P21's L0 (derivation, not coincidence)"
    P21_witness.l0_states P22_witness.l0_states;
  Alcotest.(check int) "P22 Lc = P21's Lc" P21_witness.lc_states
    P22_witness.lc_states;
  Alcotest.(check int) "P22 Ld = P21's Ld" P21_witness.ld_states
    P22_witness.ld_states;
  Alcotest.(check int) "P22 Lm = P21's Lm" P21_witness.lm_states
    P22_witness.lm_states;
  Alcotest.(check int) "P22 L0v = P21's L0v (itself P20's, itself P18's)"
    P21_witness.l0v_states P22_witness.l0v_states;
  Alcotest.(check int) "P22's witness_desired = P21's"
    P21_witness.witness_desired P22_witness.witness_desired;
  Alcotest.(check int) "P22's witness_depth = P21's" P21_witness.witness_depth
    P22_witness.witness_depth;
  Alcotest.(check int) "P22's guarantee cardinal = P21's (no new family)"
    P21_witness.guarantee_cardinal P22_witness.guarantee_cardinal

(* ==== 2. the COMMITTED member identities ==================================
   The (name, source) pairs of the three newest registers, re-typed here as
   LITERALS (the P17 [expected_pairs] pattern, t_p17_regression.ml:170-178).
   These are the file's only INDEPENDENT content about family membership:
   every other family expression in this file is the shipped one, so any
   assertion phrased purely in shipped expressions is inert. A rename, a
   re-sourced citation, an added/dropped/reordered member reddens against
   these. Wrong-by-construction is impossible to rule out by construction -
   the literals are checked against the shipped registers below, so a typo
   here fails on the first run, not silently. *)

let g1_name : string = "vsts_internal_guarantee_create_req"
let g2_name : string = "vsts_internal_guarantee_get_then_delete_req"
let g3_name : string = "vsts_internal_guarantee_get_then_update_req"
let g4_name : string = "no_interfering_request_between_vsts"

let g1_source : string =
  "vstatefulset_controller/proof/internal_rely_guarantee.rs:562"

let g2_source : string =
  "vstatefulset_controller/proof/internal_rely_guarantee.rs:581"

let g3_source : string =
  "vstatefulset_controller/proof/internal_rely_guarantee.rs:589"

let g4_source : string =
  "vstatefulset_controller/proof/internal_rely_guarantee.rs:544"

(* G1-G4 in FAMILY order (internal_guarantee.ml's [ g1; g2; g3; g4 ]). *)
let committed_guarantee_pairs : (string * string) list =
  [
    (g1_name, g1_source);
    (g2_name, g2_source);
    (g3_name, g3_source);
    (g4_name, g4_source);
  ]

(* M1-M4 in family order (msg_provenance.ml's [ m1; m2; m3; m4 ]). *)
let committed_provenance_pairs : (string * string) list =
  [
    ( "every_msg_from_vsts_controller_carries_vsts_key",
      "vstatefulset_controller/proof/helper_invariants.rs:1213" );
    ( "all_requests_from_pod_monkey_are_api_pod_requests",
      "kubernetes_cluster/proof/network.rs:570" );
    ( "all_requests_from_builtin_controllers_are_api_delete_requests",
      "kubernetes_cluster/proof/network.rs:618" );
    ( "no_pending_request_to_api_server_from_api_server_or_external",
      "kubernetes_cluster/proof/network.rs:540" );
  ]

(* R1-R3 in family order (rely_conditions.ml's [ r1; r2; r3 ]). *)
let committed_rely_pairs : (string * string) list =
  [
    ("vsts_rely_create_req", "vstatefulset_controller/trusted/rely_guarantee.rs:57");
    ("vsts_rely_update_req", "vstatefulset_controller/trusted/rely_guarantee.rs:76");
    ( "vsts_rely_conditions_pod_monkey",
      "vstatefulset_controller/trusted/rely_guarantee.rs:17" );
  ]

(* ==== 3. THE ROSTER - fourteen suites, and the self-exclusion MOVED ======= *)

let p19_label : string = "Msg_provenance.provenance_family (P19)"
let p20_label : string = "Rely_conditions.rely_family (P20)"

(* DEMOTED: the "THIS phase" marker moves off P21's label (it stopped being
   the head phase) - in THIS file only; t_p21_regression keeps its own
   marker and its own self-exclusion untouched. *)
let p21_label : string = "Internal_guarantee.guarantee_family (P21)"

let p22_label : string =
  "Internal_guarantee.guarantee_family @ scale-down leg (P22, THIS phase)"

(* The P21 roster entry's instantiation. It is bound separately from
   [family] so the sweep's two sides are two list VALUES, but it is the same
   EXPRESSION: comparing the two would be a tautology, so the assertions
   below compare each of them against [committed_guarantee_pairs] instead. *)
let p21_family : Invariants.invariant list =
  Ig.guarantee_family ~cr:(Scenario.vsts ~desired ()) ~controller_id

let shipped_suites : (string * Invariants.invariant list) list =
  let vrs = Scenario.vrs ~desired:1 in
  let vsts = Scenario.vsts ~desired:1 () in
  [
    ("Invariants.cluster_structural", Invariants.cluster_structural ~controller_id);
    ("Invariants.always", Invariants.always ~cr:vrs ~controller_id);
    ("Invariants.eventually_always", Invariants.eventually_always ~cr:vrs ~controller_id);
    ("Vsts_invariants.always", Vsts_invariants.always ~cr:vsts ~controller_id);
    ("Correspondence.family (P14)", Correspondence.family cluster ~controller_id);
    ( "Reconcile_correspondence.family (P15)",
      Rec_corr.family ~controller_id ~pending_states:Fc.vsts_pending_states
        ~none_states:Fc.vsts_none_states );
    ("Req_resp_correspondence.rv_family (P16)", Rr.rv_family inherited_bound);
    ("Req_resp_correspondence.matched_family (P16)", Rr.matched_family ~controller_id);
    ("Objects_in_store.store_family (P17)", Ois.store_family ~controller_id);
    ( "Helper_invariants.helper_family (P18)",
      Hi.helper_family ~cr:(Scenario.vsts ~desired ~vct:false ()) ~controller_id );
    (p19_label, Mp.provenance_family ~controller_id);
    (p20_label, Rely.rely_family);
    (p21_label, p21_family);
    (p22_label, family);
  ]

(* The roster's LABELS, committed as a literal list: a verbatim copy of the
   P21 roster, a dropped entry, or an un-demoted P21 marker reddens here
   before the sweep can quietly not-look at the omission. *)
let committed_roster : string list =
  [
    "Invariants.cluster_structural";
    "Invariants.always";
    "Invariants.eventually_always";
    "Vsts_invariants.always";
    "Correspondence.family (P14)";
    "Reconcile_correspondence.family (P15)";
    "Req_resp_correspondence.rv_family (P16)";
    "Req_resp_correspondence.matched_family (P16)";
    "Objects_in_store.store_family (P17)";
    "Helper_invariants.helper_family (P18)";
    p19_label;
    p20_label;
    p21_label;
    p22_label;
  ]

let others : (string * Invariants.invariant list) list =
  List.filter
    (fun ((label, _) : string * Invariants.invariant list) ->
      not (String.equal label p22_label))
    shipped_suites

let roster_pairs : (string * string) list =
  List.concat_map
    (fun ((_, invs) : string * Invariants.invariant list) ->
      Pair_guard.pairs_of invs)
    shipped_suites

(* COVERAGE, keyed on COMMITTED LITERALS (P22-review finding F2). Fed
   [Pair_guard.pairs_of <a shipped family>] this function filters
   [roster_pairs] against a list [roster_pairs] was itself built from and can
   never return anything but [[]]. Fed the section-2 literals it has teeth: a
   dropped or re-transcribed roster entry, or a renamed / re-sourced member
   upstream, leaves a committed pair unmatched and the row reddens with the
   offending pair printed. *)
let missing_from_roster (pairs : (string * string) list) :
    (string * string) list =
  List.filter (fun (p : string * string) -> not (List.mem p roster_pairs)) pairs

let test_roster_is_fourteen_and_covers_the_newest_phases () =
  Alcotest.(check (list string))
    "the roster is FOURTEEN suites - t_p21_regression's thirteen with the \
     P21 marker demoted, PLUS the P22 entry"
    committed_roster
    (List.map
       (fun ((label, _) : string * Invariants.invariant list) -> label)
       shipped_suites);
  Alcotest.(check int)
    "thirteen suites are swept (the P22 self-entry is excluded; the P21 \
     entry is IN the swept set now)"
    (List.length committed_roster - 1)
    (List.length others);
  Alcotest.(check bool)
    "the P21 entry really is in the swept set (the demotion happened)" true
    (List.exists
       (fun ((label, _) : string * Invariants.invariant list) ->
         String.equal label p21_label)
       others);
  (* COVERAGE: the COMMITTED literals against the roster's LIVE inventory
     (not the live records against themselves - see [missing_from_roster]). *)
  Alcotest.(check (list (pair string string)))
    "every COMMITTED P19 provenance pair is in the roster's live inventory"
    []
    (missing_from_roster committed_provenance_pairs);
  Alcotest.(check (list (pair string string)))
    "every COMMITTED P20 rely pair is in the roster's live inventory" []
    (missing_from_roster committed_rely_pairs);
  Alcotest.(check (list (pair string string)))
    "every COMMITTED guarantee pair (P21's register, which the P22 entry \
     re-instantiates) is in the roster's live inventory"
    []
    (missing_from_roster committed_guarantee_pairs)

(* ==== 4. the sweep: disjoint from twelve, IDENTICAL to the P21 entry ====== *)

(* The COMMITTED identity leak: {!Pair_guard.pair_leaks} reports a shared
   NAME as one line per hit, so two identical four-member families leak
   exactly the four names, in family order, in BOTH argument orders. This
   list is the "no new family" design pin made mechanical. *)
let identity_leak (label : string) : string list =
  List.map
    (fun (n : string) -> label ^ " contains name " ^ n)
    [ g1_name; g2_name; g3_name; g4_name ]

let expected_leaks (label : string) : string list =
  if String.equal label p21_label then identity_leak label else []

let test_family_disjoint_from_twelve_identical_to_p21 () =
  (* The register's identity, pinned against the COMMITTED LITERALS rather
     than against itself (P22-review finding F2): the old row compared
     [pairs_of p21_family] with [pairs_of family], two spellings of ONE
     expression, and so held whatever the register said. These two rows red
     on a rename, a re-sourced citation, an added, dropped or reordered
     member - and the "no new family" reading is then the OBSERVATION that
     the two sides meet the SAME committed list. *)
  Alcotest.(check (list (pair string string)))
    "P22's swept family = the committed four (name, source) pairs, in family \
     order"
    committed_guarantee_pairs
    (Pair_guard.pairs_of family);
  Alcotest.(check (list (pair string string)))
    "the P21 roster entry = the SAME committed four - the no-new-family \
     design pin, one register meeting one committed list twice"
    committed_guarantee_pairs
    (Pair_guard.pairs_of p21_family);
  List.iter
    (fun ((label, invs) : string * Invariants.invariant list) ->
      Alcotest.(check (list string))
        (label ^ ": family-vs-suite leaks are exactly the committed \
                  expectation (order 1 of 2)")
        (expected_leaks label)
        (Pair_guard.pair_leaks label (Pair_guard.pairs_of family)
           (Pair_guard.pairs_of invs));
      Alcotest.(check (list string))
        (label ^ ": suite-vs-family leaks are exactly the committed \
                  expectation (order 2 of 2)")
        (expected_leaks label)
        (Pair_guard.pair_leaks label (Pair_guard.pairs_of invs)
           (Pair_guard.pairs_of family)))
    others

let () =
  Alcotest.run "p22_regression"
    [
      ( "prior_phase_firewall",
        [
          Alcotest.test_case "P22's graph constants are the committed literals"
            `Quick test_p22_graph_constants_are_the_committed_literals;
          Alcotest.test_case
            "P22's graph constants are DERIVED from the P21 <- P20 chain"
            `Quick test_p22_graph_constants_are_derived_not_re_typed;
        ] );
      ( "roster",
        [
          Alcotest.test_case
            "the roster is FOURTEEN suites; P21 demoted into the swept set; \
             coverage of the COMMITTED literals"
            `Quick test_roster_is_fourteen_and_covers_the_newest_phases;
        ] );
      ( "disjointness",
        [
          Alcotest.test_case
            "family = the COMMITTED four pairs, DISJOINT from twelve suites, \
             committed identity leak vs the P21 entry (both orders)"
            `Quick test_family_disjoint_from_twelve_identical_to_p21;
        ] );
    ]

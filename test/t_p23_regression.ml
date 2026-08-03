(* BUILD-SPEC-P23 section 6 - the prior-phase firewall and the roster's
   generation step for the phase that ships the controller-LOCAL binding
   register and RE-PARTITIONS the E-ledger.

   THE CLASSIFICATION, stated in its exact MEASURED wording, because the
   tempting sentence here is FALSE. The member probe
   [rg -n 'source = "[^"]*internal_rely_guarantee.rs:(606|613|640)' lib test]
   returned ZERO hits before this phase, so L1 :613 and L2 :640 are THE FIRST
   SHIPPED MEMBERS SOURCED TO THE CONTROLLER-LOCAL BINDING FUNCTIONS. The
   companion FILE probe [rg -n 'source = "[^"]*internal_rely_guarantee' lib test]
   returns FOUR hits (internal_guarantee.ml:377/:396/:416/:436, P21's G1-G4), so
   it must NEVER be written that these are the first members from that file.
   P21 could truthfully make the file-level claim (t_p21_regression.ml:5-8);
   P23 cannot. The novelty here is MEMBER-level.

   ---- what this file DOES --------------------------------------------------

   - THE PRIOR-PHASE FIREWALL: the P13-P22 graph literals re-typed here (the
     one sanctioned duplication - p21_witness.ml:18-30 states the standing
     rationale, and p23_witness.ml:15-20 restates it for this phase) AND held
     against the chain {!P23_witness} claims to derive them from. "Fix the red
     by editing the witness" has to redden somewhere, and this is where. The
     P22 GATE pins (20 / 276 / 96 / 2080) are included: they are P22-MEASURED,
     hence PRIOR-phase for P23, and they are the only leg-side coupling P22 has
     to its own family binding. No P23-MEASURED number is re-typed here -
     {!P23_witness} is their single source and t_p23_local_binding re-derives
     them through the shipped exe.

   - THE COMMITTED MEMBER IDENTITIES: L1's and L2's (name, source) pairs as
     LITERALS (the P17 [expected_pairs] pattern, t_p17_regression.ml:170-178),
     checked pair-for-pair against the shipped register in family order, so a
     rename, a re-sourced citation, an added / dropped / reordered member
     reddens HERE regardless of how the family is implemented. BOTH SOURCES ARE
     BARE and that is load-bearing: a parenthetical qualifier makes
     t_p21_regression's [line_of_source] return [None] and the member vanishes
     from the roster sweep silently (t_p23_mutation's MB8 row exhibits it).

   - THE ROSTER, EXTENDED TO FIFTEEN AND THE SELF-EXCLUSION MOVED (the
     P20->P21->P22 mechanism, re-run): t_p22_regression's roster was FOURTEEN
     with its own P22 entry excluded by label. HERE the P22 label loses its
     "THIS phase" marker and moves INTO the swept set, and the self-exclusion
     keys on [p23_label]. A VERBATIM COPY-FORWARD OF THE P22 ROSTER REDS: that
     file's assertions name FOURTEEN explicitly.

   - THE SWEEP: the binding family against the other FOURTEEN roster suites via
     {!Pair_guard.pair_leaks}, BOTH argument orders, expecting [[]] everywhere.
     Unlike P22 there is NO identity row: P22 shipped no new family (its entry
     re-instantiated P21's register, so the two leaked all four names by
     design), whereas P23 ships two genuinely new members and the whole roster
     must come back disjoint. The sweep is SEEN red-capable against the
     roster's own P23 self-entry.

   - THE E-LEDGER RE-PARTITION, pinned from the P23 side (see the caveat
     below on where the SWEEP lives): the register's own two lines are in
     {!P21_witness.ledger_shipped_lines} and in NEITHER excluded bucket, and
     the partition is still TOTAL and DISJOINT at the file's nine
     [pub open spec fn]: 6 shipped + E1 1 + E2 1 + E3 1 at P23's landing,
     7 shipped + E1 1 + E2 1 since P25's sanctioned re-partition shipped
     E3 :606 (BUILD-SPEC-P25 §2).

   ---- what it does NOT do (anti-duplication, the P15-P22 rationale) --------

   It does NOT re-run any leg (the batteries do), does NOT model-check anything
   (pure list work, milliseconds), does NOT re-pin any P23 MEASURED number, and
   does NOT duplicate the E-LEDGER REVERSAL SWEEP. That sweep - "every
   internal_rely_guarantee.rs line cited ANYWHERE in the roster is exactly the
   shipped set" - keeps its SINGLE ASSERTION SITE in t_p21_regression (the
   house convention t_p22_regression.ml:93-96 names), which P23 EDITED: its
   roster gained the binding family, its shipped bucket became
   [544; 562; 581; 589; 613; 640] with an excluded bucket of E3 [606] alone
   (since P25's re-partition the shipped bucket is the 7-item
   [544; 562; 581; 589; 606; 613; 640] and E1 :522 / E2 :528 are the only
   excluded lines), and it gained the BARE-SOURCE COUNT assertion that makes a
   dropped-out member loud. Before the P23 edit the clause was passing
   VACUOUSLY - its roster was a
   LITERAL thirteen-suite list that never saw L1 or L2 - which is exactly the
   green-that-means-nothing shape this project keeps producing. What is pinned
   HERE is the ledger's CONSTANTS, not the roster sweep.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum, no two-arm match on
   [option]/[result], total accessors only, no exceptions, Alcotest as the
   sanctioned failure primitive. *)

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
module Lb = Anvil_assurance.Local_binding

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P23_witness.witness_desired

(* The INHERITED chain bound for the P16 suite instantiation (the rv leg's own
   bound) - NOT {!P23_witness.p23_bound}, which is the P22/P23 leg record and
   instantiates no roster suite. *)
let inherited_bound : Bound.t = P21_witness.p21_bound ~desireds:[ desired ]

(* P23's swept family: the binding register instantiated with the arguments
   fault_check.ml's local-binding leg passes. That the leg passes these
   arguments is NOT asserted here (this file runs no leg); where leg-side drift
   IS caught is t_p23_local_binding's leg-COMPUTED gate pins 68/560/816/7920,
   produced INSIDE the leg over its OWN [invs]. *)
let family : Invariants.invariant list =
  Lb.binding_family ~cr:(Scenario.vsts ~desired ()) ~controller_id

let names_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.name) invs

let sources_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.source) invs

(* ==== 1. the prior-phase firewall ========================================== *)

(* The graph literals as committed on the P13-P22 branches, held against the
   witness module P23's exes actually read. P23 adds NO seam: its bound is an
   identity derivation of P22's, it edits no committed seed and no state field,
   and [run_leg] passes [explore] no invariant argument - so graphs are
   FAMILY-BLIND and these thirteen are pure derivation guards. A drift is a
   phase-STOP, never a retune. *)

let committed_l0_states : int = 76
let committed_lc_states : int = 464
let committed_ld_states : int = 744
let committed_lm_states : int = 1976
let committed_l0v_states : int = 116
let committed_sl0_states : int = 88
let committed_slc_states : int = 808
let committed_sld_states : int = 1144
let committed_slm_states : int = 10216
let committed_sl0_gate : int = 20
let committed_slc_gate : int = 276
let committed_sld_gate : int = 96
let committed_slm_gate : int = 2080

let test_p23_graph_constants_are_the_committed_literals () =
  Alcotest.(check int) "P23 L0 states = the committed 76" committed_l0_states
    P23_witness.l0_states;
  Alcotest.(check int) "P23 Lc states = the committed 464" committed_lc_states
    P23_witness.lc_states;
  Alcotest.(check int) "P23 Ld states = the committed 744" committed_ld_states
    P23_witness.ld_states;
  Alcotest.(check int) "P23 Lm states = the committed 1976" committed_lm_states
    P23_witness.lm_states;
  Alcotest.(check int)
    "P23 L0v states = the committed 116 (P16's, via the P18 <- P20 <- P21 <- \
     P22 chain)"
    committed_l0v_states P23_witness.l0v_states;
  Alcotest.(check int) "P23 SL0 states = P22's committed 88" committed_sl0_states
    P23_witness.sl0_states;
  Alcotest.(check int) "P23 SLc states = P22's committed 808"
    committed_slc_states P23_witness.slc_states;
  Alcotest.(check int) "P23 SLd states = P22's committed 1144"
    committed_sld_states P23_witness.sld_states;
  Alcotest.(check int) "P23 SLm states = P22's committed 10216"
    committed_slm_states P23_witness.slm_states;
  Alcotest.(check int) "P23 SL0 gate = P22's committed 20" committed_sl0_gate
    P23_witness.sl0_gate_states;
  Alcotest.(check int) "P23 SLc gate = P22's committed 276" committed_slc_gate
    P23_witness.slc_gate_states;
  Alcotest.(check int) "P23 SLd gate = P22's committed 96" committed_sld_gate
    P23_witness.sld_gate_states;
  Alcotest.(check int) "P23 SLm gate = P22's committed 2080" committed_slm_gate
    P23_witness.slm_gate_states

(* The SAME constants against the chain they are DERIVED from, so a re-typed
   literal in p23_witness.ml that happens to agree with the committed value
   today still reddens the moment the phase it claims to derive from moves. *)
let test_p23_graph_constants_are_derived_not_re_typed () =
  Alcotest.(check int) "P23 L0 = P22's L0 (derivation, not coincidence)"
    P22_witness.l0_states P23_witness.l0_states;
  Alcotest.(check int) "P23 Lc = P22's Lc" P22_witness.lc_states
    P23_witness.lc_states;
  Alcotest.(check int) "P23 Ld = P22's Ld" P22_witness.ld_states
    P23_witness.ld_states;
  Alcotest.(check int) "P23 Lm = P22's Lm" P22_witness.lm_states
    P23_witness.lm_states;
  Alcotest.(check int) "P23 L0v = P22's L0v" P22_witness.l0v_states
    P23_witness.l0v_states;
  Alcotest.(check int) "P23 SL0 = P22's SL0" P22_witness.sl0_states
    P23_witness.sl0_states;
  Alcotest.(check int) "P23 SLc = P22's SLc" P22_witness.slc_states
    P23_witness.slc_states;
  Alcotest.(check int) "P23 SLd = P22's SLd" P22_witness.sld_states
    P23_witness.sld_states;
  Alcotest.(check int) "P23 SLm = P22's SLm" P22_witness.slm_states
    P23_witness.slm_states;
  Alcotest.(check int) "P23's witness_desired = P22's" P22_witness.witness_desired
    P23_witness.witness_desired;
  Alcotest.(check int) "P23's witness_depth = P22's" P22_witness.witness_depth
    P23_witness.witness_depth;
  Alcotest.(check (list int)) "P23's shipped ordinals = P22's"
    P22_witness.p22_ordinals P23_witness.p23_ordinals;
  (* PREDICTION 8 as a DERIVATION rather than four new numbers: the four P23
     legs reuse P22's (seed, bound, budget, depth), so their state counts must
     BE P22's. If stage B had measured anything else, THESE bindings are what
     redden, and the answer is a phase-STOP diagnosis, never a retune. *)
  Alcotest.(check int) "prediction 8: BL0 states ARE SL0's"
    P23_witness.sl0_states P23_witness.bl0_states;
  Alcotest.(check int) "prediction 8: BLc states ARE SLc's"
    P23_witness.slc_states P23_witness.blc_states;
  Alcotest.(check int) "prediction 8: BLd states ARE SLd's"
    P23_witness.sld_states P23_witness.bld_states;
  Alcotest.(check int) "prediction 8: BLm states ARE SLm's"
    P23_witness.slm_states P23_witness.blm_states

(* ==== 2. the COMMITTED member identities ================================== *)

let l1_name : string = "vsts_local_pods_and_pvcs_bound_in_local_state"
let l2_name : string = "vsts_local_pods_and_pvcs_bound_with_key"

(* BARE. No parenthetical qualifier, ever - see the header and MB8. *)
let l1_source : string =
  "vstatefulset_controller/proof/internal_rely_guarantee.rs:613"

let l2_source : string =
  "vstatefulset_controller/proof/internal_rely_guarantee.rs:640"

(* L1, L2 in FAMILY order (local_binding.ml's [ l1; l2 ]). *)
let committed_binding_pairs : (string * string) list =
  [ (l1_name, l1_source); (l2_name, l2_source) ]

(* P21's four, re-typed here ONLY so the roster-coverage rows below can be
   keyed on COMMITTED literals rather than on a family filtered against itself
   (the P22-review F2 correction). *)
let committed_guarantee_pairs : (string * string) list =
  [
    ( "vsts_internal_guarantee_create_req",
      "vstatefulset_controller/proof/internal_rely_guarantee.rs:562" );
    ( "vsts_internal_guarantee_get_then_delete_req",
      "vstatefulset_controller/proof/internal_rely_guarantee.rs:581" );
    ( "vsts_internal_guarantee_get_then_update_req",
      "vstatefulset_controller/proof/internal_rely_guarantee.rs:589" );
    ( "no_interfering_request_between_vsts",
      "vstatefulset_controller/proof/internal_rely_guarantee.rs:544" );
  ]

let test_family_names_and_pairs () =
  Alcotest.(check (list string)) "binding_family is L1/L2 in member order"
    [ l1_name; l2_name ] (names_of family);
  Alcotest.(check (list (pair string string)))
    "family (name, source) pairs = the committed literals, in member order"
    committed_binding_pairs
    (Pair_guard.pairs_of family);
  Alcotest.(check (list string))
    "family sources = binding_sources, in order (the .mli's exposed literals)"
    Lb.binding_sources (sources_of family);
  Alcotest.(check int) "binding_family cardinal" P23_witness.binding_cardinal
    (List.length family);
  (* the member NAMES the counting projections address the family by, pinned
     against the same literals - a rename would blind every per-member count in
     t_p23_local_binding and t_p23_mutation at once. *)
  Alcotest.(check (list string)) "the witness's member names = the committed two"
    [ l1_name; l2_name ]
    [ P23_witness.l1_name; P23_witness.l2_name ]

(* ==== 3. THE ROSTER - fifteen suites, and the self-exclusion MOVED ======== *)

let p19_label : string = "Msg_provenance.provenance_family (P19)"
let p20_label : string = "Rely_conditions.rely_family (P20)"
let p21_label : string = "Internal_guarantee.guarantee_family (P21)"

(* DEMOTED: the "THIS phase" marker moves off P22's label - in THIS file only;
   t_p22_regression keeps its own marker and its own self-exclusion. *)
let p22_label : string =
  "Internal_guarantee.guarantee_family @ scale-down leg (P22)"

let p23_label : string = "Local_binding.binding_family (P23, THIS phase)"

(* The P21 and P22 roster entries are the SAME expression (P22 shipped no new
   family), bound separately so the roster has two entries; comparing them to
   each other would be a tautology, so both are checked against
   [committed_guarantee_pairs] through the coverage row instead. *)
let p21_family : Invariants.invariant list =
  Ig.guarantee_family ~cr:(Scenario.vsts ~desired ()) ~controller_id

let p22_family : Invariants.invariant list =
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
    (p22_label, p22_family);
    (p23_label, family);
  ]

(* The roster's LABELS, committed as a literal list: a verbatim copy of the P22
   roster, a dropped entry, or an un-demoted P22 marker reddens here before the
   sweep can quietly not-look at the omission. *)
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
    p23_label;
  ]

let others : (string * Invariants.invariant list) list =
  List.filter
    (fun ((label, _) : string * Invariants.invariant list) ->
      not (String.equal label p23_label))
    shipped_suites

let roster_pairs : (string * string) list =
  List.concat_map
    (fun ((_, invs) : string * Invariants.invariant list) ->
      Pair_guard.pairs_of invs)
    shipped_suites

(* COVERAGE keyed on COMMITTED LITERALS (P22-review finding F2). Fed
   [Pair_guard.pairs_of <a roster family>] this function filters
   [roster_pairs] against a list it was itself built from and can never return
   anything but [[]]; fed the section-2 literals it has teeth. *)
let missing_from_roster (pairs : (string * string) list) :
    (string * string) list =
  List.filter (fun (p : string * string) -> not (List.mem p roster_pairs)) pairs

let test_roster_is_fifteen_and_covers_the_newest_phases () =
  Alcotest.(check (list string))
    "the roster is FIFTEEN suites - t_p22_regression's fourteen with the P22 \
     marker demoted, PLUS the P23 entry (a verbatim copy-forward REDS: that \
     file names FOURTEEN explicitly)"
    committed_roster
    (List.map
       (fun ((label, _) : string * Invariants.invariant list) -> label)
       shipped_suites);
  Alcotest.(check int)
    "fourteen suites are swept (the P23 self-entry is excluded; the P22 entry \
     is IN the swept set now)"
    (List.length committed_roster - 1)
    (List.length others);
  Alcotest.(check bool)
    "the P22 entry really is in the swept set (the demotion happened)" true
    (List.exists
       (fun ((label, _) : string * Invariants.invariant list) ->
         String.equal label p22_label)
       others);
  (* COVERAGE: the COMMITTED literals against the roster's LIVE inventory. *)
  Alcotest.(check (list (pair string string)))
    "every COMMITTED P21 guarantee pair is in the roster's live inventory" []
    (missing_from_roster committed_guarantee_pairs);
  Alcotest.(check (list (pair string string)))
    "every COMMITTED P23 binding pair is in the roster's live inventory - the \
     row that would redden if the P23 entry were dropped from the roster"
    []
    (missing_from_roster committed_binding_pairs)

(* ==== 4. the sweep: DISJOINT from all fourteen ==============================
   Unlike P22 there is no identity row: P23 ships two genuinely new members, so
   every row expects [[]]. {!Pair_guard.pair_leaks} detects a shared NAME or a
   shared SOURCE in either list, so ONE order already covers both leak
   directions; the second order makes that coverage explicit rather than
   inferred. *)

let leaks_against (suites : (string * Invariants.invariant list) list) :
    string list =
  List.concat_map
    (fun ((suite, invs) : string * Invariants.invariant list) ->
      Pair_guard.pair_leaks
        ("P23 -> " ^ suite)
        (Pair_guard.pairs_of family)
        (Pair_guard.pairs_of invs)
      @ Pair_guard.pair_leaks
          ("P23 <- " ^ suite)
          (Pair_guard.pairs_of invs)
          (Pair_guard.pairs_of family))
    suites

let test_family_is_disjoint_from_shipped_suites () =
  Alcotest.(check (list string))
    "no P23 binding member shares a name or source with any of the FOURTEEN \
     other shipped suites (both argument orders, incl. P21's and P22's - the \
     file-level probe returns four hits and the member-level probe returned \
     ZERO, which is exactly this)"
    []
    (leaks_against others);
  (* The sweep is SEEN red-capable: the same detector, run against the roster's
     own P23 self-entry, reports every member in both orders - so the empty
     list above is a MEASURED absence, not a broken traversal (the D3 lesson:
     [pair_leaks] against a shorter roster still returns [[]]). *)
  Alcotest.(check int)
    "sweep control: the roster's own P23 entry reports every member, both \
     orders"
    (2 * List.length family)
    (List.length
       (leaks_against
          (List.filter
             (fun ((label, _) : string * Invariants.invariant list) ->
               String.equal label p23_label)
             shipped_suites)))

(* ==== 5. the E-LEDGER RE-PARTITION, pinned from the P23 side ===============
   NOT the reversal SWEEP - that keeps its single assertion site in
   t_p21_regression (header). What is pinned here is the ledger's CONSTANTS
   against the register this phase actually ships: after P23 the partition of
   [proof/internal_rely_guarantee.rs]'s nine [pub open spec fn] was
   6 shipped + E1 1 + E2 1 + E3 1, still total and disjoint; after P25's
   sanctioned re-partition (BUILD-SPEC-P25 §2) it is 7 shipped + E1 1 + E2 1.

   BUILD-SPEC-P22.md:279-281 PRE-AUTHORIZED the P23 reversal in those words -
   it records that t_p21_regression's clause "reds only if P23 ships E3-E5,
   deliberately". So this was a RE-PARTITION, not a red. E3 :606 STAYED
   excluded through P24 because it is the LIFT of E5 over every VSTS-kind key
   and every shipped scenario was single-CR, so it collapsed to "L2 wearing a
   hat"; P25 shipped it over the committed multi-CR graphs as a standalone
   value in Internal_guarantee (BUILD-SPEC-P25 §1.1), outside this register. *)

let sub_opt (s : string) (pos : int) (len : int) : string option =
  if pos >= 0 && len >= 0 && pos + len <= String.length s then
    Some (String.sub s pos len) (* @total-accessor *)
  else None

let line_of_source (s : string) : int option =
  Option.bind (String.rindex_opt s ':') (fun (i : int) ->
      Option.bind
        (sub_opt s (i + 1) (String.length s - i - 1))
        int_of_string_opt)

let binding_lines : int list = List.filter_map line_of_source Lb.binding_sources

let ledgered_excluded_lines : int list =
  P21_witness.ledger_e1_lines @ P21_witness.ledger_e2_lines

let test_e_ledger_repartition () =
  (* BARE-SOURCE first: if either source acquired a qualifier, [binding_lines]
     is short and everything below it would be a claim about one member while
     reading two. *)
  Alcotest.(check int)
    "both P23 sources are BARE and parse to a line (a parenthetical qualifier \
     makes line_of_source return None - MB8's exhibit)"
    (List.length Lb.binding_sources)
    (List.length binding_lines);
  Alcotest.(check (list int)) "the P23 lines are :613 and :640" [ 613; 640 ]
    binding_lines;
  Alcotest.(check (list int))
    "the ledger's SHIPPED bucket is the re-partitioned seven (G4 :544, \
     G1 :562, G2 :581, G3 :589, E3 :606, L1 :613, L2 :640)"
    [ 544; 562; 581; 589; 606; 613; 640 ]
    P21_witness.ledger_shipped_lines;
  Alcotest.(check (list int))
    "every P23 line is now in the SHIPPED bucket" binding_lines
    (List.filter
       (fun (n : int) -> List.mem n P21_witness.ledger_shipped_lines)
       binding_lines);
  Alcotest.(check (list int))
    "and in NEITHER excluded bucket (E1 :522 / E2 :528) - E3 :606 left the \
     excluded bucket when P25 shipped it elsewhere as a standalone value; \
     this register still ships only :613 and :640"
    []
    (List.filter (fun (n : int) -> List.mem n ledgered_excluded_lines)
       binding_lines);
  Alcotest.(check (list int))
    "the excluded bucket is exactly E1 :522, E2 :528"
    [ 522; 528 ]
    (List.sort_uniq Int.compare ledgered_excluded_lines);
  Alcotest.(check int)
    "shipped + ledgered = the file's 9 pub open spec fn, no orphan and no \
     double-ledgering (7 + 1 + 1)"
    P21_witness.ledger_spec_fn_count
    (List.length
       (List.sort_uniq Int.compare
          (P21_witness.ledger_shipped_lines @ ledgered_excluded_lines)))

let () =
  Alcotest.run "p23_regression"
    [
      ( "prior_phase_firewall",
        [
          Alcotest.test_case
            "P23's graph constants are the committed P13-P22 literals (incl. \
             P22's four gates)"
            `Quick test_p23_graph_constants_are_the_committed_literals;
          Alcotest.test_case
            "P23's graph constants are DERIVED from the P22 <- P21 chain, and \
             prediction 8 is a derivation not four new numbers"
            `Quick test_p23_graph_constants_are_derived_not_re_typed;
        ] );
      ( "family_classification",
        [
          Alcotest.test_case
            "binding_family = L1 :613 / L2 :640, committed (name, source) \
             pairs, BARE sources"
            `Quick test_family_names_and_pairs;
        ] );
      ( "roster",
        [
          Alcotest.test_case
            "the roster is FIFTEEN suites; P22 demoted into the swept set; \
             coverage of the COMMITTED literals"
            `Quick test_roster_is_fifteen_and_covers_the_newest_phases;
        ] );
      ( "disjointness",
        [
          Alcotest.test_case
            "family DISJOINT from every other shipped suite (Pair_guard, both \
             orders; sweep SEEN red-capable on the self-entry)"
            `Quick test_family_is_disjoint_from_shipped_suites;
        ] );
      ( "e_ledger_repartition",
        [
          Alcotest.test_case
            "4 shipped + 5 excluded -> 6 shipped + 3 excluded -> 7 shipped + \
             2 excluded, total and disjoint at NINE (PRE-AUTHORIZED by \
             BUILD-SPEC-P22.md:279-281 and BUILD-SPEC-P25 §2)"
            `Quick test_e_ledger_repartition;
        ] );
    ]

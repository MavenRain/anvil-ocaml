(* BUILD-SPEC-P20 section 6 - the CLASSIFICATION FIREWALL of the rely-condition
   family, and the phase's DEBT DISCHARGE.

   THE CLASSIFICATION (spec section 2): R1/R2/R3 are a genuinely NEW family -
   no member is shipped anywhere (rg-swept at B1: zero hits for a [source]
   naming [rely_guarantee] in lib/ and test/ before this phase), so P17's
   filter pattern was structurally unavailable and the P14-P16/P18-P19 disjoint
   pattern applies verbatim. Pinned here in the k3-strengthened (name, source)
   form via the shared {!Pair_guard}.

   ---- what this file DOES ---------------------------------------------------

   - THE D3 FIX, and it is the reason this file exists at all. P19's roster
     ([t_p19_regression.ml:241-258], :229-246 before B6's D1/D2 edits moved
     it) carries TEN suites and does NOT include
     P19's own [Msg_provenance.provenance_family]. Copying it forward verbatim
     would have left P19 UNCOVERED by P20's sweep while
     {!Pair_guard.pair_leaks} still reported [[]] - a green that verifies
     nothing, which is exactly the silent-vacuity class D1 and D2 both turned
     out to be instances of. The roster below had TWELVE entries: those ten,
     plus P19's family, plus P20's own [Rely_conditions.rely_family].
     (P21 EXTENSION, 2026-07-29, BUILD-SPEC-P21 section 6: THIRTEEN now -
     P21's [Internal_guarantee.guarantee_family] is appended and swept, and
     the THIS-phase marker moved off the P20 label to t_p21_regression's
     P21 entry, where the self-exclusion now lives.)

     P20's family is IN the roster (it is now a shipped suite, and the next
     phase must sweep against it) and is therefore excluded from the sweep's
     own right-hand side by LABEL - a family is never disjoint from itself.
     The self-entry is not wasted: it doubles as the sweep's red-capability
     control.

   - THE DISJOINTNESS SWEEP (spec section 2): [rely_family] against the other
     eleven roster suites via {!Pair_guard.pair_leaks}, run in BOTH argument
     orders. The detector is either-component (a shared NAME or a shared
     SOURCE is a hit), so one order already covers both leak directions;
     running both makes the coverage explicit rather than inferred.

   - THE PRIOR-PHASE FIREWALL: the P13-P19 graph literals re-typed here (the
     one sanctioned duplication, P14's rationale: "fix the red by editing the
     witness" reddens HERE) AND held against the chain {!P20_witness} claims
     to derive them from. A witness edited to make a red go away, or a
     derivation replaced by a re-typed literal that happens to agree today,
     reddens here.

   - THE E4 REVERSAL CLAUSE, over the WHOLE roster. [t_p20_rely.ml:825-856]
     already pins the [trusted/rely_guarantee.rs] scope ledger, but it reads
     [Rely_conditions.rely_sources] and nothing else. That is precisely the
     scope D2 proved insufficient: a line ledgered as EXCLUDED (E1/E2/E3)
     could be shipped by some OTHER suite and the ledger would stay green.
     The guard below sweeps all twelve suites, so an E1/E2/E3 line shipped
     anywhere in the tree reddens and RE-OPENS the exclusion.

   - THE D4 REGRESSION GUARD: [inv_self]'s corrected citation, plus the
     absence of the drifted path from every roster suite.

   ---- what it does NOT do (anti-duplication, the P15-P19 rationale) --------

   It does NOT re-run any P13-P19 leg (their batteries already do), does NOT
   model-check anything (this exe is pure list work and runs in milliseconds),
   and does NOT re-pin any P20 MEASURED number - {!P20_witness} is the single
   source and this file only READS it. D1 and D2 are fixed at their own site,
   [t_p19_regression.ml]; D4 at [lib/assurance/vsts_invariants.ml:217].

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum, no two-arm match on
   [option]/[result] (stdlib [Option.fold] / [Option.map]), Alcotest as the
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

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P20_witness.witness_desired
let bound : Bound.t = P20_witness.p20_bound ~desireds:[ desired ]
let family : Invariants.invariant list = Rely.rely_family

let names_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.name) invs

let sources_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.source) invs

(* ==== 1. the prior-phase firewall ========================================== *)

(* The graph literals as committed on the P13-P19 branches, held against the
   witness modules P20's exes actually read. The product graph depends only on
   (seed, bound, budget, depth) - never on the invariant list checked over it -
   so P20 DERIVES these rather than re-measuring, and this section is where a
   derivation break, a seed drift, or a "fix the red by editing the witness"
   repair reddens.

   P20 is the first phase to ADD a field to [Bound.t] ([monkey_forge], default
   [[]]), which is exactly why these five are a measured gate this phase and
   not an inherited assumption - [t_p20_rely.ml]'s [pin_safety] case re-EXPLORES
   all five graphs, while this section pins the CONSTANTS those explorations
   are checked against. *)

let committed_l0_states : int = 76
let committed_lc_states : int = 464
let committed_ld_states : int = 744
let committed_lm_states : int = 1976
let committed_l0v_states : int = 116

let test_p20_graph_constants_are_the_committed_literals () =
  Alcotest.(check int) "P20 L0 states = the committed 76" committed_l0_states
    P20_witness.l0_states;
  Alcotest.(check int) "P20 Lc states = the committed 464" committed_lc_states
    P20_witness.lc_states;
  Alcotest.(check int) "P20 Ld states = the committed 744" committed_ld_states
    P20_witness.ld_states;
  Alcotest.(check int) "P20 Lm states = the committed 1976" committed_lm_states
    P20_witness.lm_states;
  Alcotest.(check int) "P20 L0v states = the committed 116 (P16's, via P18)"
    committed_l0v_states P20_witness.l0v_states

(* The SAME constants against the chain they are DERIVED from, so a re-typed
   literal in p20_witness.ml that happens to agree with the committed value
   today still reddens the moment the phase it claims to derive from moves. *)
let test_p20_graph_constants_are_derived_not_re_typed () =
  Alcotest.(check int) "P20 L0 = P19's L0 (derivation, not coincidence)"
    P19_witness.l0_states P20_witness.l0_states;
  Alcotest.(check int) "P20 Lc = P19's Lc" P19_witness.lc_states
    P20_witness.lc_states;
  Alcotest.(check int) "P20 Ld = P19's Ld" P19_witness.ld_states
    P20_witness.ld_states;
  Alcotest.(check int) "P20 Lm = P19's Lm" P19_witness.lm_states
    P20_witness.lm_states;
  Alcotest.(check int) "P20 L0v = P18's L0v (itself P16's)" P18_witness.l0v_states
    P20_witness.l0v_states;
  Alcotest.(check int) "P20's witness_desired = P19's" P19_witness.witness_desired
    P20_witness.witness_desired;
  Alcotest.(check int) "P20's witness_depth = P19's" P19_witness.witness_depth
    P20_witness.witness_depth

(* ==== 2. the family classification: the committed (name, source) pairs ===== *)

let r1_name : string = "vsts_rely_create_req"
let r2_name : string = "vsts_rely_update_req"
let r3_name : string = "vsts_rely_conditions_pod_monkey"
let r1_source : string = "vstatefulset_controller/trusted/rely_guarantee.rs:57"
let r2_source : string = "vstatefulset_controller/trusted/rely_guarantee.rs:76"
let r3_source : string = "vstatefulset_controller/trusted/rely_guarantee.rs:17"

(* The three (name, source) pairs as COMMITTED LITERALS, compared against the
   family - a rename, a source drift, or a re-implementation reddens HERE
   regardless of how the family is built. All three cite [trusted/], which is
   the phase's whole point: R1-R3 are what upstream ASSUMES about its
   environment and never discharges, so no [proof/] citation exists to make. *)
let expected_pairs : (string * string) list =
  [ (r1_name, r1_source); (r2_name, r2_source); (r3_name, r3_source) ]

let test_family_names_and_pairs () =
  Alcotest.(check (list string))
    "rely_family is R1/R2/R3 in upstream-helper order" [ r1_name; r2_name; r3_name ]
    (names_of family);
  Alcotest.(check (list (pair string string)))
    "family (name, source) pairs = the committed literals, in member order"
    expected_pairs
    (Pair_guard.pairs_of family);
  Alcotest.(check (list string))
    "family sources = rely_sources, in order" Rely.rely_sources
    (sources_of family)

(* ==== 3. THE D3 ROSTER - thirteen suites (twelve at P20, extended by P21) == *)

(* Every list a shipped leg consumes, instantiated exactly as those legs
   instantiate them. The first TEN are P19's roster verbatim; the next TWO are
   the D3 fix; the THIRTEENTH is the P21 extension (BUILD-SPEC-P21 section 6):
   P21's [Internal_guarantee.guarantee_family] is appended so THIS file's
   sweep measures P20's family against it, the THIS-phase marker moved off
   the P20 label (P20 is now a PRIOR phase; the marker and the self-exclusion
   position live in t_p21_regression now), and the committed label list below
   reddens a verbatim copy in either direction. The sweep's own exclusion
   still keys on [p20_label], because this exe's SUBJECT family is still
   P20's - a family is never disjoint from itself.

   WHY D3 IS THE HIGHEST-RISK OF THE THREE COMMITTED-TEST DEFECTS: a missing
   roster entry does not fail loudly. [pair_leaks] against a shorter roster
   still returns [[]], and [[] = leaked] still passes - the sweep simply never
   looks at the omitted suite. P19's own family was the omission, so a P20
   member colliding with M1/M2/M3/M4 would have gone unnoticed. MEASURED at
   B6 by mutation (see the banner at the sweep below).

   [Rely_conditions.rely_family] is here because it is now a shipped suite and
   the NEXT phase must sweep against it; the sweep below excludes it by label,
   since no family is disjoint from itself. *)

let p20_label : string = "Rely_conditions.rely_family (P20)"
let p19_label : string = "Msg_provenance.provenance_family (P19)"

let p21_label : string = "Internal_guarantee.guarantee_family (P21)"

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
    ("Req_resp_correspondence.rv_family (P16)", Rr.rv_family bound);
    ("Req_resp_correspondence.matched_family (P16)", Rr.matched_family ~controller_id);
    ("Objects_in_store.store_family (P17)", Ois.store_family ~controller_id);
    ( "Helper_invariants.helper_family (P18)",
      Hi.helper_family ~cr:(Scenario.vsts ~desired ~vct:false ()) ~controller_id );
    (p19_label, Mp.provenance_family ~controller_id);
    (p20_label, family);
    (p21_label, Ig.guarantee_family ~cr:vsts ~controller_id);
  ]

(* The roster's LABELS, committed as a literal list: this is the assertion a
   verbatim copy of P19's ten-entry roster reddens. Without it, D3's fix is
   invisible to the battery - which is the whole defect restated. *)
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
  ]

let others : (string * Invariants.invariant list) list =
  List.filter
    (fun ((label, _) : string * Invariants.invariant list) ->
      not (String.equal label p20_label))
    shipped_suites

let roster_pairs : (string * string) list =
  List.concat_map
    (fun ((_, invs) : string * Invariants.invariant list) ->
      Pair_guard.pairs_of invs)
    shipped_suites

let missing_from_roster (invs : Invariants.invariant list) :
    (string * string) list =
  List.filter
    (fun (p : string * string) -> not (List.mem p roster_pairs))
    (Pair_guard.pairs_of invs)

let test_roster_covers_p19_and_p20 () =
  Alcotest.(check (list string))
    "D3: the roster is THIRTEEN suites - P19's ten PLUS provenance_family \
     PLUS rely_family PLUS P21's guarantee_family (a verbatim copy of a \
     prior roster reddens here)"
    committed_roster
    (List.map
       (fun ((label, _) : string * Invariants.invariant list) -> label)
       shipped_suites);
  Alcotest.(check int) "D3: twelve suites are swept (the self-entry is excluded)"
    (List.length committed_roster - 1)
    (List.length others);
  (* COVERAGE, read off the LIVE records rather than off the labels: every
     member of P19's family and of P20's own is really reachable through the
     roster. A dropped entry reddens here even if its label survives. *)
  Alcotest.(check (list (pair string string)))
    "D3: every P19 provenance member is covered by the roster"
    []
    (missing_from_roster (Mp.provenance_family ~controller_id));
  Alcotest.(check (list (pair string string)))
    "D3: every P20 rely member is covered by the roster" []
    (missing_from_roster family);
  Alcotest.(check (list (pair string string)))
    "P21 extension: every P21 guarantee member is covered by the roster" []
    (missing_from_roster
       (Ig.guarantee_family ~cr:(Scenario.vsts ~desired:1 ()) ~controller_id))

(* THE MASKING-TRAP GUARD (P14-P16/P18-P19 pattern). A P20 member found in ANY
   shipped suite means prior pins are no longer measuring what they claim (pin
   reason), and a unioned leg could report an earlier-firing member instead of
   the intended one (masking reason). {!Pair_guard.pair_leaks} detects a shared
   NAME or a shared SOURCE in either list, so ONE sweep already covers both
   leak directions; the second argument order below makes that coverage
   explicit instead of inferred.

   CONFIRMED BY MUTATION (P20 stage B6; a guard never SEEN to fail is not
   evidence). R3's source in [rely_conditions.ml] was temporarily re-pointed to
   M1's ["vstatefulset_controller/proof/helper_invariants.rs:1213"] - a
   deliberate P19 collision. MEASURED: with the P19 entry REMOVED from the
   roster (i.e. P19's ten-entry roster copied forward verbatim, the D3 defect)
   this sweep stayed GREEN; with the twelve-entry roster it goes RED, naming
   the shared source in both argument orders. Same mutation, opposite verdicts.
   The mutation was reverted by exact [Edit] and [git diff] verified empty
   against the index.

   HONEST QUALIFICATION, recorded so the differential is not over-read: under
   the ten-entry roster the mutation was invisible to THIS SWEEP, not to the
   file. Three other assertions still reddened - the committed (name, source)
   pairs above, the roster-label pin, and the E4 reversal clause (R3 stopped
   citing rely_guarantee.rs at all). What D3 buys is coverage of the case those
   three cannot see: a P20 member that keeps a perfectly valid rely_guarantee
   citation and collides with a P19 member on the NAME, or a future phase
   whose family collides with P19's while every P20 pin stays green. The
   ten-entry roster leaves that case unmeasured while reporting [[]]. *)
let leaks_against (suites : (string * Invariants.invariant list) list) :
    string list =
  List.concat_map
    (fun ((suite, invs) : string * Invariants.invariant list) ->
      Pair_guard.pair_leaks
        ("P20 -> " ^ suite)
        (Pair_guard.pairs_of family)
        (Pair_guard.pairs_of invs)
      @ Pair_guard.pair_leaks
          ("P20 <- " ^ suite)
          (Pair_guard.pairs_of invs)
          (Pair_guard.pairs_of family))
    suites

let test_family_is_disjoint_from_shipped_suites () =
  Alcotest.(check (list string))
    "no P20 rely member shares a name or source with any of the twelve other \
     shipped suites (both argument orders, incl. P19's and P21's)"
    []
    (leaks_against others);
  (* The sweep is SEEN red-capable: the same detector, run against the roster's
     own P20 self-entry, reports every member in both orders - so the empty
     list above is a measured absence, not a broken traversal. *)
  Alcotest.(check int)
    "sweep control: the roster's own P20 entry reports every member, both orders"
    (2 * List.length family)
    (List.length
       (leaks_against
          (List.filter
             (fun ((label, _) : string * Invariants.invariant list) ->
               String.equal label p20_label)
             shipped_suites)))

(* ==== 4. the E4 REVERSAL CLAUSE, swept over the whole roster =============== *)

(* [t_p20_rely.ml:825-856] pins the [trusted/rely_guarantee.rs] scope ledger
   from [Rely_conditions.rely_sources]. That establishes the SHIPPED side is
   what the ledger says it is - but it cannot see a line the ledger calls
   EXCLUDED being shipped by some other module. D2 is the proof that this gap
   is not hypothetical: P19's network.rs ledger called :104 an unshipped
   leftover while P15 had been shipping it for five phases.

   So the same ledger is re-derived here from ALL TWELVE suites. E1 (:32/:39),
   E2 (:133/:152/:164/:176) and E3 (:92/:105/:120) are excluded on the grounds
   that nothing ports them; if anything ever does, this reddens and RE-OPENS
   the exclusion instead of leaving it silently stale.

   The cardinals come from {!P20_witness}; none is re-typed here. *)

let rely_guarantee_prefix : string =
  "vstatefulset_controller/trusted/rely_guarantee.rs:"

let line_of_source (s : string) : int option =
  Option.bind (String.rindex_opt s ':') (fun (i : int) ->
      int_of_string_opt (String.sub s (i + 1) (String.length s - i - 1)))

(* Every trusted/rely_guarantee.rs line cited ANYWHERE in the roster, deduped
   and ascending - read off the live records, never re-typed. *)
let roster_rely_guarantee_lines : int list =
  List.sort_uniq Int.compare
    (List.filter_map
       (fun ((_, src) : string * string) ->
         Option.bind
           (if String.starts_with ~prefix:rely_guarantee_prefix src then Some src
            else None)
           line_of_source)
       roster_pairs)

let ledgered_excluded_lines : int list =
  P20_witness.e4_e1_lines @ P20_witness.e4_e3_lines @ P20_witness.e4_e2_lines

let test_e4_reversal_clause_over_the_whole_roster () =
  Alcotest.(check (list int))
    "E4 reversal clause: the ONLY trusted/rely_guarantee.rs lines shipped \
     anywhere in the twelve-suite roster are R1/R2/R3's"
    P20_witness.e4_shipped_lines roster_rely_guarantee_lines;
  Alcotest.(check (list int))
    "E4: no line ledgered as EXCLUDED (E1/E2/E3) is shipped by any suite - a \
     hit here RE-OPENS the exclusion"
    []
    (List.filter
       (fun (n : int) -> List.mem n roster_rely_guarantee_lines)
       ledgered_excluded_lines);
  (* The ledger is still TOTAL at the file's measured cardinal. The count is
     read from the witness (B1 COUNTED 12 `pub open spec fn`; the spec body's
     "13" is a MEASURED-CORRECTION recorded at the section-3 site). *)
  Alcotest.(check int)
    "E4: shipped + ledgered = the file's 12 pub open spec fn, no orphan"
    P20_witness.e4_spec_fn_count
    (List.length
       (List.sort_uniq Int.compare
          (P20_witness.e4_shipped_lines @ ledgered_excluded_lines)))

(* ==== 5. D4 - the inv_self citation drift, fixed and guarded =============== *)

(* BUILD-SPEC-P20 section 6 D4, applied by stage B6 at
   [lib/assurance/vsts_invariants.ml:217]. P18 §8.3 and P19 §8.3 both deferred
   the fix on the belief that it would move committed (name, source) pins in
   four regression exes. MEASURED at B6 and the belief REFUTED:
   [rg 'helper_invariants/predicate' test/] returns ZERO hits, the four exes
   that mention [inv_self] carry only its NAME (t_p11_vsts_invariants.ml:169,
   t_p11_mutation.ml:225, t_p13_mutation.ml:38, t_p19_regression.ml:380), and
   [pair_guard.ml:29-49] computes pairs DYNAMICALLY off the live suites. The
   fix moved no pin; [git diff --stat] confirmed it.

   The OLD string named [vstatefulset_controller/proof/helper_invariants/
   predicate.rs], a path that does not exist: that directory layout is
   vreplicaset_controller's, and vstatefulset has the flat file
   [proof/helper_invariants.rs]. MEASURED against anvil-ref:
   [rg 'only_interferes_with_itself' src/controllers/vstatefulset_controller/]
   returns ZERO hits, so there is no vstatefulset original to cite at all -
   the shipped member is a WIDENING of the VRS one, and now says so. *)

let inv_self_name : string = "vsts_reconcile_request_only_interferes_with_itself"

let inv_self_source : string =
  "vreplicaset_controller/proof/helper_invariants/predicate.rs:237 (widened \
   inv9; vstatefulset has no upstream analogue)"

let drifted_prefix : string =
  "vstatefulset_controller/proof/helper_invariants/predicate.rs"

let source_of (invs : Invariants.invariant list) (name : string) : string option
    =
  Option.map
    (fun (i : Invariants.invariant) -> i.Invariants.source)
    (List.find_opt
       (fun (i : Invariants.invariant) -> String.equal i.Invariants.name name)
       invs)

let test_d4_inv_self_citation () =
  (* POSITIVE CONTROL first: the member is still shipped where D4 found it. *)
  Alcotest.(check bool)
    "D4 control: inv_self is still a member of Vsts_invariants.always" true
    (List.mem inv_self_name
       (names_of
          (Vsts_invariants.always ~cr:(Scenario.vsts ~desired:1 ()) ~controller_id)));
  Alcotest.(check (option string))
    "D4: inv_self cites the REAL vreplicaset file:line, with the widening \
     disclosed"
    (Some inv_self_source)
    (source_of
       (Vsts_invariants.always ~cr:(Scenario.vsts ~desired:1 ()) ~controller_id)
       inv_self_name);
  Alcotest.(check (list string))
    "D4: the nonexistent vstatefulset predicate-directory path is cited by NO \
     suite in the roster"
    []
    (List.filter
       (fun ((_, src) : string * string) ->
         String.starts_with ~prefix:drifted_prefix src)
       roster_pairs
    |> List.map (fun ((n, _) : string * string) -> n))

let () =
  Alcotest.run "p20_regression"
    [
      ( "prior_phase_firewall",
        [
          Alcotest.test_case "P20's graph constants are the committed literals"
            `Quick test_p20_graph_constants_are_the_committed_literals;
          Alcotest.test_case
            "P20's graph constants are DERIVED from the P19 <- P18 chain" `Quick
            test_p20_graph_constants_are_derived_not_re_typed;
        ] );
      ( "family_classification",
        [
          Alcotest.test_case
            "rely_family = the three upstream names, committed (name, source) \
             pairs"
            `Quick test_family_names_and_pairs;
          Alcotest.test_case
            "D3: the roster is THIRTEEN suites and really covers P19, P20 \
             and P21"
            `Quick test_roster_covers_p19_and_p20;
          Alcotest.test_case
            "family DISJOINT from every other shipped suite (Pair_guard, both \
             orders)"
            `Quick test_family_is_disjoint_from_shipped_suites;
        ] );
      ( "exclusion_pins",
        [
          Alcotest.test_case
            "E4 reversal clause: no ledgered-excluded rely_guarantee line is \
             shipped anywhere"
            `Quick test_e4_reversal_clause_over_the_whole_roster;
          Alcotest.test_case "D4: inv_self's citation drift is fixed" `Quick
            test_d4_inv_self_citation;
        ] );
    ]

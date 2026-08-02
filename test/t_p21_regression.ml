(* BUILD-SPEC-P21 sections 2/6 - the CLASSIFICATION FIREWALL of the
   internal-guarantee family, and the roster's generation step.

   THE CLASSIFICATION (spec section 1): G1-G4 are a genuinely NEW family -
   [rg -n 'source = "[^"]*internal_rely_guarantee' lib/ test/] returned ZERO
   hits before this phase (the sweep run WITHOUT a trailing slash and
   WITHOUT a narrowing suffix, the exact defect class that cost P20 a review
   finding), so no shipped member cited [proof/internal_rely_guarantee.rs]
   at all before P21 and the P14-P16/P18-P20 disjoint pattern applies
   verbatim. Pinned here in the k3-strengthened (name, source) form via the
   shared {!Pair_guard}.

   ---- what this file DOES --------------------------------------------------

   - THE PRIOR-PHASE FIREWALL: the P13-P20 graph literals re-typed here (the
     one sanctioned duplication, P14's rationale: "fix the red by editing
     the witness" reddens HERE - see p20_witness.ml:18-26 for the standing
     statement of why) AND held against the chain {!P21_witness} claims to
     derive them from. A witness edited to make a red go away, or a
     derivation replaced by a re-typed literal that happens to agree today,
     reddens here.

   - THE ROSTER, EXTENDED TO THIRTEEN AND THE SELF-EXCLUSION MOVED (spec
     section 6, the P20-residual-7 mechanism). t_p20_regression's roster was
     TWELVE suites with its own P20 entry excluded from its sweep by label.
     P21's landing does BOTH halves of the generation step: (a) that file's
     roster is extended to thirteen (its committed_roster assertion reddens
     a verbatim copy), and (b) HERE the P20 label moves OUT of the
     self-exclusion filter INTO the swept set - P20 is now a prior phase and
     this sweep measures P21's family against it - while the self-exclusion
     now keys on the P21 label (a family is never disjoint from itself; the
     self-entry doubles as the sweep's red-capability control).

     EXTENDED AGAIN TO FOURTEEN BY P23 (BUILD-SPEC-P23 section 6), and that
     edit is load-bearing rather than cosmetic. This file's roster is a
     LITERAL list, so a family shipped by a later phase is NOT swept
     automatically. Until P23 added its entry, the E-LEDGER REVERSAL CLAUSE
     below was passing VACUOUSLY: L1 :613 and L2 :640 were already shipped
     and the clause could not see them, so its green meant nothing. A green
     that was never made to sweep the new members is worthless, and that is
     precisely the failure mode this project keeps producing.

   - THE DISJOINTNESS SWEEP: [guarantee_family] against the other THIRTEEN
     roster suites via {!Pair_guard.pair_leaks}, run in BOTH argument
     orders. The detector is either-component (a shared NAME or a shared
     SOURCE is a hit), so one order already covers both leak directions;
     running both makes the coverage explicit rather than inferred.

   - THE E-LEDGER REVERSAL CLAUSE, over the WHOLE roster (the D2 lesson:
     a line ledgered as EXCLUDED could be shipped by some OTHER suite while
     the family-local ledger stays green). This is the SINGLE ASSERTION SITE
     for the whole-tree ledger sweep and it stays here (the convention
     t_p22_regression.ml:93-96 names); t_p23_regression pins the ledger's
     CONSTANTS but does not duplicate this sweep. Every
     [proof/internal_rely_guarantee.rs] line cited anywhere in the fourteen
     suites is collected and held to be exactly the SIX shipped ones -
     G1-G4 plus P23's L1 :613 and L2 :640 - and a ledgered-excluded line
     (E1 :522, E2 :528, E3 :606) appearing anywhere reddens and RE-OPENS the
     exclusion. E2's :528 carries a special reading, disclosed: it is
     ALREADY SHIPPED semantically as P19's M1 under its
     [helper_invariants.rs:1213] citation (re-measured at P21: SEMANTICALLY
     IDENTICAL, one [is_controller_id] unfolding apart, bridged by upstream
     itself at liveness/proof.rs:903-927), so a :528 citation appearing
     would be a name-collision with M1 as well as a ledger reversal.

   - THE RE-PARTITION IS NOT A RED, AND THAT WAS COMMITTED IN ADVANCE.
     BUILD-SPEC-P22.md:279-281 states verbatim that this clause "reds only if
     P23 ships E3-E5, deliberately". P23 ships E4 :613 and E5 :640 and leaves
     E3 :606 excluded (it is the LIFT of E5 over every VSTS-kind key, so on a
     single-CR scenario it collapses to "L2 wearing a hat"). The buckets in
     {!P21_witness} moved with it: [ledger_shipped_lines] gained :613/:640 and
     [ledger_e3_e5_lines] became [ledger_e3_lines] = [[606]].

   - THE BARE-SOURCE FIREWALL (BUILD-SPEC-P23 section 5, MB8). The clause's
     negative form - "no EXCLUDED line is shipped" - CANNOT SEE AN ABSENT
     MEMBER: [line_of_source] parses everything after the LAST colon, so a
     source carrying a parenthetical qualifier returns [None], the member
     drops out of [roster_guarantee_lines], and the filter passes on a
     shorter list. Three assertions close that: the count of prefixed sources
     that PARSE equals the count that BEAR the prefix, that count equals the
     ledger's shipped cardinal, and the P23 lines are asserted PRESENT
     positively. t_p23_mutation exhibits the qualifier returning [None], so
     the firewall is not merely asserted to have teeth.

   ---- what it does NOT do (anti-duplication, the P15-P20 rationale) -------

   It does NOT re-run any P13-P21 leg (their batteries already do), does NOT
   model-check anything (this exe is pure list work and runs in
   milliseconds), and does NOT re-pin any P21 MEASURED number -
   {!P21_witness} is the single source and this file only READS it (the five
   INHERITED literals below are prior-phase numbers, not P21-measured ones).

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum, no two-arm match on
   [option]/[result] (stdlib [Option.fold] / [Option.bind]), total accessors
   only (the guarded [sub_opt] below), Alcotest as the sanctioned failure
   primitive. *)

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
module Sp = Anvil_assurance.State_predicates

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P21_witness.witness_desired
let bound : Bound.t = P21_witness.p21_bound ~desireds:[ desired ]

let family : Invariants.invariant list =
  Ig.guarantee_family ~cr:(Scenario.vsts ~desired ()) ~controller_id

let names_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.name) invs

let sources_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.source) invs

(* ==== 1. the prior-phase firewall ========================================== *)

(* The graph literals as committed on the P13-P20 branches, held against the
   witness module P21's exes actually read. The product graph depends only on
   (seed, bound, budget, depth) - never on the invariant list checked over it
   - so P21 DERIVES these rather than re-measuring, and this section is where
   a derivation break, a seed drift, or a "fix the red by editing the
   witness" repair reddens.

   P21 adds NO new seam at all (no [Bound.t] field, no state field, no
   [?vct] on the leg), so unlike P20 these five are pure derivation guards
   this phase - [t_p21_guarantee]'s [pin_safety] case re-EXPLORES all five
   graphs, while this section pins the CONSTANTS those explorations are
   checked against. *)

let committed_l0_states : int = 76
let committed_lc_states : int = 464
let committed_ld_states : int = 744
let committed_lm_states : int = 1976
let committed_l0v_states : int = 116

let test_p21_graph_constants_are_the_committed_literals () =
  Alcotest.(check int) "P21 L0 states = the committed 76" committed_l0_states
    P21_witness.l0_states;
  Alcotest.(check int) "P21 Lc states = the committed 464" committed_lc_states
    P21_witness.lc_states;
  Alcotest.(check int) "P21 Ld states = the committed 744" committed_ld_states
    P21_witness.ld_states;
  Alcotest.(check int) "P21 Lm states = the committed 1976" committed_lm_states
    P21_witness.lm_states;
  Alcotest.(check int) "P21 L0v states = the committed 116 (P16's, via P20)"
    committed_l0v_states P21_witness.l0v_states

(* The SAME constants against the chain they are DERIVED from, so a re-typed
   literal in p21_witness.ml that happens to agree with the committed value
   today still reddens the moment the phase it claims to derive from moves. *)
let test_p21_graph_constants_are_derived_not_re_typed () =
  Alcotest.(check int) "P21 L0 = P20's L0 (derivation, not coincidence)"
    P20_witness.l0_states P21_witness.l0_states;
  Alcotest.(check int) "P21 Lc = P20's Lc" P20_witness.lc_states
    P21_witness.lc_states;
  Alcotest.(check int) "P21 Ld = P20's Ld" P20_witness.ld_states
    P21_witness.ld_states;
  Alcotest.(check int) "P21 Lm = P20's Lm" P20_witness.lm_states
    P21_witness.lm_states;
  Alcotest.(check int) "P21 L0v = P20's L0v (itself P18's, itself P16's)"
    P20_witness.l0v_states P21_witness.l0v_states;
  Alcotest.(check int) "P21's witness_desired = P20's"
    P20_witness.witness_desired P21_witness.witness_desired;
  Alcotest.(check int) "P21's witness_depth = P20's" P20_witness.witness_depth
    P21_witness.witness_depth

(* ==== 2. the family classification: the committed (name, source) pairs ===== *)

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

(* The four (name, source) pairs as COMMITTED LITERALS, compared against the
   family - a rename, a source drift, or a re-implementation reddens HERE
   regardless of how the family is built. All four cite [proof/], which is
   the phase's whole point: unlike P20's rely register these ARE discharged
   upstream, so the citations name the discharged definitions themselves. *)
let expected_pairs : (string * string) list =
  [
    (g1_name, g1_source);
    (g2_name, g2_source);
    (g3_name, g3_source);
    (g4_name, g4_source);
  ]

let test_family_names_and_pairs () =
  Alcotest.(check (list string))
    "guarantee_family is G1/G2/G3/G4 in member order"
    [ g1_name; g2_name; g3_name; g4_name ]
    (names_of family);
  Alcotest.(check (list (pair string string)))
    "family (name, source) pairs = the committed literals, in member order"
    expected_pairs
    (Pair_guard.pairs_of family);
  Alcotest.(check (list string))
    "family sources = guarantee_sources, in order" Ig.guarantee_sources
    (sources_of family);
  Alcotest.(check int) "guarantee_family cardinal"
    P21_witness.guarantee_cardinal (List.length family)

(* ==== 3. THE ROSTER - fourteen suites, and the self-exclusion MOVED ======= *)

(* Every list a shipped leg consumes, instantiated exactly as those legs
   instantiate them. The first TWELVE are t_p20_regression's roster (its
   D3 form); the THIRTEENTH is P21's own family; the FOURTEENTH is P23's
   binding register, added by that phase so the E-ledger clause below actually
   sweeps it (without it the clause is green about nothing).

   THE MOVE (spec section 6): the P20 entry is now IN the swept set - it
   stopped being the self-entry when P20 stopped being the head phase - and
   the self-exclusion below keys on the P21 label instead. A verbatim copy
   forward of the P20 roster reddens at the coverage assertion (P21's
   members would not be reachable through it), which is that assertion's
   whole job (the D3 lesson: a missing roster entry does not fail loudly;
   [pair_leaks] against a shorter roster still returns [[]]). *)

let p19_label : string = "Msg_provenance.provenance_family (P19)"
let p20_label : string = "Rely_conditions.rely_family (P20)"

let p21_label : string =
  "Internal_guarantee.guarantee_family (P21, THIS phase)"

(* P23's register, ADDED TO THIS ROSTER AND NOT ONLY TO t_p23_regression's,
   and this is the load-bearing half of the P23 edit. The E-ledger reversal
   clause below sweeps [roster_pairs], which is built from THIS literal list.
   A new family that is not in it is not swept, so before this entry existed
   the clause was GREEN while L1 :613 and L2 :640 were already shipped - a pin
   passing VACUOUSLY, this project's named failure mode. The clause is the
   single assertion site for the whole-tree ledger sweep
   (t_p22_regression.ml:93-96 names the convention), so the roster it sweeps
   has to be the whole roster. *)
let p23_label : string = "Local_binding.binding_family (P23)"

(* P24's register, ADDED TO THIS ROSTER for exactly the reason the P23 comment
   above gives, and the reason survives verbatim one phase on: the E-ledger
   reversal clause below sweeps [roster_pairs], which is built from THIS
   literal list, so a shipped family that is not in it is not swept. P24's
   two sources are [.../liveness/state_predicates.rs:NNN] and therefore
   cannot bear the [guarantee_prefix] the clause filters on - the addition is
   inert for the ledger BY MEASUREMENT (t_p24_regression's source-file
   partition case measures it) rather than by intention - but the entry still
   has to exist, because the roster is also what the disjointness sweep and the
   coverage rows below read. *)
let p24_label : string = "State_predicates.predicate_family (P24)"

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
    (p20_label, Rely.rely_family);
    (p21_label, family);
    (p23_label, Lb.binding_family ~cr:vsts ~controller_id);
    (p24_label, Sp.predicate_family ~cr:vsts ~controller_id);
  ]

(* The roster's LABELS, committed as a literal list: a verbatim copy of the
   P20 roster, or a dropped entry, reddens here before the sweep can quietly
   not-look at the omission. *)
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
    p23_label;
    p24_label;
  ]

let others : (string * Invariants.invariant list) list =
  List.filter
    (fun ((label, _) : string * Invariants.invariant list) ->
      not (String.equal label p21_label))
    shipped_suites

let roster_pairs : (string * string) list =
  List.concat_map
    (fun ((_, invs) : string * Invariants.invariant list) ->
      Pair_guard.pairs_of invs)
    shipped_suites

(* THE COVERAGE FILTER, in its two forms. The PAIRS form is the one with teeth:
   fed a list of COMMITTED (name, source) literals it asks whether the roster's
   LIVE inventory still contains them. The INVARIANT-LIST form below re-derives
   the pairs from a family, and when that family is one the roster itself was
   built from it filters [roster_pairs] against a list it is part of, so it can
   return nothing but [[]] - the P22 review recorded that as finding F2, and
   t_p24_regression.ml:550-556 states it by name. The P19/P20/P21/P23 rows keep
   the derived form because it is what they have always asserted; the P24 row
   below is written against literals. *)
let missing_pairs_from_roster (pairs : (string * string) list) :
    (string * string) list =
  List.filter (fun (p : string * string) -> not (List.mem p roster_pairs)) pairs

let missing_from_roster (invs : Invariants.invariant list) :
    (string * string) list =
  missing_pairs_from_roster (Pair_guard.pairs_of invs)

(* P24's two members as COMMITTED (name, source) LITERALS - re-typed here, and
   deliberately NOT read back out of {!Sp.predicate_family} or
   {!Sp.predicate_sources}. This list is the fixed point of the P24 coverage
   row below: a dropped roster entry, a renamed member and a drifted source all
   redden against it, and none of the three can redden against a list recomputed
   from the same value the roster entry holds. *)
let committed_predicate_pairs : (string * string) list =
  [
    ( "vsts_local_state_is_valid",
      "vstatefulset_controller/proof/liveness/state_predicates.rs:192" );
    ( "vsts_pending_list_pod_resp_in_flight",
      "vstatefulset_controller/proof/liveness/state_predicates.rs:107" );
  ]

let test_roster_covers_p19_p20_and_p21 () =
  Alcotest.(check (list string))
    "the roster is FIFTEEN suites - t_p20_regression's twelve PLUS \
     guarantee_family PLUS P23's binding_family PLUS P24's predicate_family (a \
     verbatim copy of the P20 roster reddens here, and so does a P23 or P24 \
     landing that forgot its entry - see the E-ledger clause below, which \
     sweeps this very list)"
    committed_roster
    (List.map
       (fun ((label, _) : string * Invariants.invariant list) -> label)
       shipped_suites);
  Alcotest.(check int)
    "fourteen suites are swept (the P21 self-entry is excluded; the P20, P23 \
     and P24 entries are IN the swept set)"
    (List.length committed_roster - 1)
    (List.length others);
  (* COVERAGE, read off the LIVE records rather than off the labels: every
     member of the three newest families is really reachable through the
     roster. A dropped entry reddens here even if its label survives. *)
  Alcotest.(check (list (pair string string)))
    "every P19 provenance member is covered by the roster" []
    (missing_from_roster (Mp.provenance_family ~controller_id));
  Alcotest.(check (list (pair string string)))
    "every P20 rely member is covered by the roster" []
    (missing_from_roster Rely.rely_family);
  Alcotest.(check (list (pair string string)))
    "every P21 guarantee member is covered by the roster" []
    (missing_from_roster family);
  (* THE P23 COVERAGE ROW. Its job is not disjointness (t_p23_regression owns
     that) but PRESENCE: if the P23 entry above were dropped, the E-ledger
     clause below would go back to sweeping a roster that cannot see :613 or
     :640 and would pass while the exclusion is in fact re-opened. *)
  Alcotest.(check (list (pair string string)))
    "every P23 binding member is covered by the roster - the entry the ledger \
     clause depends on is really there"
    []
    (missing_from_roster (Lb.binding_family ~cr:(Scenario.vsts ~desired ()) ~controller_id));
  (* THE P24 COVERAGE ROW, added for the same reason as P23's, with one
     difference stated honestly and one defect NOT repeated. The difference:
     P24's sources are [.../liveness/state_predicates.rs:NNN], so this entry can
     never reach the guarantee-prefix filter below; what it IS load-bearing for
     is the sweep in the previous case and the coverage claim here.

     THE DEFECT NOT REPEATED (P22 review finding F2). Written the way the rows
     above are - [missing_from_roster (Sp.predicate_family ...)] - this row
     would filter [roster_pairs] against pairs recomputed from the very value
     the roster entry holds, so it could return nothing but [[]]: green if the
     entry were dropped from [shipped_suites], green if a member were renamed,
     green if a source drifted. Against the COMMITTED literals all three redden,
     and the third is the one the E-ledger machinery actually depends on - a
     drifted source is exactly what makes a member invisible to a parser that
     splits on the last colon. *)
  Alcotest.(check (list (pair string string)))
    "every COMMITTED P24 state-predicate pair is in the roster's LIVE \
     inventory - keyed on literals, never on the family the roster entry \
     itself holds, so a dropped entry or a drifted source reddens instead of \
     passing vacuously (P22-review F2)"
    []
    (missing_pairs_from_roster committed_predicate_pairs)

(* THE MASKING-TRAP GUARD (P14-P16/P18-P20 pattern). A P21 member found in
   ANY shipped suite means prior pins are no longer measuring what they
   claim (pin reason), and a unioned leg could report an earlier-firing
   member instead of the intended one (masking reason).
   {!Pair_guard.pair_leaks} detects a shared NAME or a shared SOURCE in
   either list, so ONE sweep already covers both leak directions; the second
   argument order below makes that coverage explicit rather than inferred. *)
let leaks_against (suites : (string * Invariants.invariant list) list) :
    string list =
  List.concat_map
    (fun ((suite, invs) : string * Invariants.invariant list) ->
      Pair_guard.pair_leaks
        ("P21 -> " ^ suite)
        (Pair_guard.pairs_of family)
        (Pair_guard.pairs_of invs)
      @ Pair_guard.pair_leaks
          ("P21 <- " ^ suite)
          (Pair_guard.pairs_of invs)
          (Pair_guard.pairs_of family))
    suites

let test_family_is_disjoint_from_shipped_suites () =
  Alcotest.(check (list string))
    "no P21 guarantee member shares a name or source with any of the fourteen \
     other shipped suites (both argument orders, incl. P20's, P23's and P24's)"
    []
    (leaks_against others);
  (* The sweep is SEEN red-capable: the same detector, run against the
     roster's own P21 self-entry, reports every member in both orders - so
     the empty list above is a measured absence, not a broken traversal. *)
  Alcotest.(check int)
    "sweep control: the roster's own P21 entry reports every member, both \
     orders"
    (2 * List.length family)
    (List.length
       (leaks_against
          (List.filter
             (fun ((label, _) : string * Invariants.invariant list) ->
               String.equal label p21_label)
             shipped_suites)))

(* ==== 4. the E-ledger REVERSAL CLAUSE, swept over the whole roster ========= *)

(* internal_guarantee.mli carries the family-local ledger; this sweep is the
   whole-tree form (the D2 lesson restated in the header). The cardinals come
   from {!P21_witness}; none is re-typed here. *)

let guarantee_prefix : string =
  "vstatefulset_controller/proof/internal_rely_guarantee.rs:"

(* A TOTAL substring (the internal_guarantee.ml [sub_opt] rendering, reused
   deliberately over t_p20_regression's control-flow-protected [String.sub]:
   the guard on the [Some] line establishes the precondition locally). *)
let sub_opt (s : string) (pos : int) (len : int) : string option =
  if pos >= 0 && len >= 0 && pos + len <= String.length s then
    Some (String.sub s pos len) (* @total-accessor *)
  else None

let line_of_source (s : string) : int option =
  Option.bind (String.rindex_opt s ':') (fun (i : int) ->
      Option.bind
        (sub_opt s (i + 1) (String.length s - i - 1))
        int_of_string_opt)

(* Every proof/internal_rely_guarantee.rs SOURCE cited anywhere in the roster,
   deduped - read off the live records, never re-typed. Kept as a binding of
   its own so the BARE-SOURCE FIREWALL below can compare the count of sources
   that BEAR the prefix against the count that PARSE. *)
let roster_guarantee_sources : string list =
  List.sort_uniq String.compare
    (List.filter_map
       (fun ((_, src) : string * string) ->
         if String.starts_with ~prefix:guarantee_prefix src then Some src
         else None)
       roster_pairs)

(* ...and the LINES those sources parse to, deduped and ascending. *)
let roster_guarantee_lines : int list =
  List.sort_uniq Int.compare (List.filter_map line_of_source roster_guarantee_sources)

let ledgered_excluded_lines : int list =
  P21_witness.ledger_e1_lines @ P21_witness.ledger_e2_lines
  @ P21_witness.ledger_e3_lines

let test_e_ledger_reversal_clause () =
  Alcotest.(check bool)
    "every G1-G4 source names proof/internal_rely_guarantee.rs" true
    (List.for_all (String.starts_with ~prefix:guarantee_prefix)
       Ig.guarantee_sources);
  Alcotest.(check bool)
    "every P23 binding source names proof/internal_rely_guarantee.rs too" true
    (List.for_all (String.starts_with ~prefix:guarantee_prefix)
       Lb.binding_sources);
  (* THE POSITIVE CLAUSE, and why its two lines are typed as COMMITTED LITERALS
     rather than read back out of [Lb.binding_sources]. The self-derived shape -
     [List.filter_map line_of_source Lb.binding_sources] on BOTH sides - takes
     its expected value from the same expression it tests, so the MB8 qualifier
     applied to L1 ALONE makes :613 parse to [None] on both sides at once: the
     row compares [640] with [640] and passes GREEN while the member is
     invisible to this entire clause. That is precisely the vacuously-green
     shape the positive form was added to prevent. Against literals the same
     mutant leaves an expected [613; 640] beside an actual [640] and the row
     REDDENS, which is what makes local_binding.mli's "both PRESENT" disclosure
     something an assertion actually names. It runs BEFORE the count firewall
     below deliberately: Alcotest reports only the first failing row of a case,
     and "expected [613; 640], received [640]" names the member that went
     invisible, where the firewall's "6 vs 5" only says one of them did. *)
  Alcotest.(check (list int))
    "the P23 members' lines 613 and 640 are PRESENT in the roster's parsed \
     lines - the POSITIVE form, written against COMMITTED LITERALS because the \
     negative excluded-lines filter below cannot see an ABSENT member and a \
     self-derived expected value cannot see a QUALIFIED one"
    [ 613; 640 ]
    (List.filter (fun (n : int) -> List.mem n roster_guarantee_lines) [ 613; 640 ]);
  (* ---- THE BARE-SOURCE FIREWALL, and why it is a COUNT ---------------------
     [line_of_source] is [String.rindex_opt ':'] fed to [int_of_string_opt], so
     a source carrying a parenthetical qualifier (the vsts_invariants.ml:217
     style) parses to [None], DROPS OUT of [roster_guarantee_lines], AND THE
     NEGATIVE CLAUSE BELOW STILL PASSES - a member can go invisible without
     reddening anything. The equality of the two counts is what makes that
     LOUD: a dropped-out member leaves a prefixed source with no line. The
     second row anchors the surviving count to the ledger's own cardinal, so
     "all of them parsed" cannot be satisfied by a roster that lost the entry
     entirely. t_p23_mutation's MB8 row is the exhibit that these have teeth. *)
  Alcotest.(check int)
    "BARE-SOURCE FIREWALL: every internal_rely_guarantee.rs source in the \
     roster PARSES to a line - a parenthetical qualifier makes the member \
     SILENTLY invisible to this whole clause"
    (List.length roster_guarantee_sources)
    (List.length roster_guarantee_lines);
  Alcotest.(check int)
    "...and the surviving count IS the ledger's shipped cardinal (six after \
     the P23 re-partition), so a member that vanished from the roster rather \
     than from the parser reddens here too"
    (List.length P21_witness.ledger_shipped_lines)
    (List.length roster_guarantee_lines);
  Alcotest.(check (list int))
    "the ONLY internal_rely_guarantee.rs lines shipped anywhere in the \
     FIFTEEN-suite roster are G1-G4's and P23's L1 :613 / L2 :640 - P24's \
     two sources name liveness/state_predicates.rs and cannot reach this \
     filter at all (the \
     re-partition: 4 shipped + 5 excluded -> 6 shipped + 3 excluded, \
     PRE-AUTHORIZED by BUILD-SPEC-P22.md:279-281)"
    P21_witness.ledger_shipped_lines roster_guarantee_lines;
  Alcotest.(check (list int))
    "no line ledgered as EXCLUDED (E1 :522 / E2 :528 / E3 :606) is shipped by \
     any suite - a hit RE-OPENS the exclusion (and for :528 would also collide \
     with P19's M1, its semantic twin; E3 :606 is the LIFT of E5, which \
     collapses to 'L2 wearing a hat' on a single-CR scenario)"
    []
    (List.filter
       (fun (n : int) -> List.mem n roster_guarantee_lines)
       ledgered_excluded_lines);
  (* The ledger is still TOTAL and DISJOINT at the file's measured cardinal
     (NINE pub open spec fn, counted at build time; 6 shipped + 3 excluded
     after the P23 re-partition). *)
  Alcotest.(check int)
    "shipped + ledgered = the file's 9 pub open spec fn, no orphan and no \
     double-ledgering (6 + 1 + 1 + 1)"
    P21_witness.ledger_spec_fn_count
    (List.length
       (List.sort_uniq Int.compare
          (P21_witness.ledger_shipped_lines @ ledgered_excluded_lines)))

let () =
  Alcotest.run "p21_regression"
    [
      ( "prior_phase_firewall",
        [
          Alcotest.test_case "P21's graph constants are the committed literals"
            `Quick test_p21_graph_constants_are_the_committed_literals;
          Alcotest.test_case
            "P21's graph constants are DERIVED from the P20 <- P19 chain"
            `Quick test_p21_graph_constants_are_derived_not_re_typed;
        ] );
      ( "family_classification",
        [
          Alcotest.test_case
            "guarantee_family = the four upstream names, committed (name, \
             source) pairs"
            `Quick test_family_names_and_pairs;
          Alcotest.test_case
            "the roster is FIFTEEN suites and really covers P19, P20, P21, \
             P23 and P24 (the entry the ledger clause sweeps)"
            `Quick test_roster_covers_p19_p20_and_p21;
          Alcotest.test_case
            "family DISJOINT from every other shipped suite (Pair_guard, \
             both orders; P20, P23 and P24 in the swept set)"
            `Quick test_family_is_disjoint_from_shipped_suites;
        ] );
      ( "exclusion_pins",
        [
          Alcotest.test_case
            "E-ledger reversal clause (re-partitioned 4+5 -> 6+3): the roster \
             ships exactly G1-G4 + L1 :613 + L2 :640, every prefixed source \
             PARSES (the bare-source firewall), and no excluded line appears"
            `Quick test_e_ledger_reversal_clause;
        ] );
    ]

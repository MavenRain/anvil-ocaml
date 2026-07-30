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

   - THE DISJOINTNESS SWEEP: [guarantee_family] against the other TWELVE
     roster suites via {!Pair_guard.pair_leaks}, run in BOTH argument
     orders. The detector is either-component (a shared NAME or a shared
     SOURCE is a hit), so one order already covers both leak directions;
     running both makes the coverage explicit rather than inferred.

   - THE E-LEDGER REVERSAL CLAUSE, over the WHOLE roster (the D2 lesson:
     a line ledgered as EXCLUDED could be shipped by some OTHER suite while
     the family-local ledger stays green). Every
     [proof/internal_rely_guarantee.rs] line cited anywhere in the thirteen
     suites is collected and held to be exactly the four shipped ones; a
     ledgered-excluded line (E1 :522, E2 :528, E3-E5 :606/:613/:640)
     appearing anywhere reddens and RE-OPENS the exclusion. E2's :528
     carries a special reading, disclosed: it is ALREADY SHIPPED
     semantically as P19's M1 under its [helper_invariants.rs:1213]
     citation (re-measured this phase: SEMANTICALLY IDENTICAL, one
     [is_controller_id] unfolding apart, bridged by upstream itself at
     liveness/proof.rs:903-927), so a :528 citation appearing would be a
     name-collision with M1 as well as a ledger reversal.

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

(* ==== 3. THE ROSTER - thirteen suites, and the self-exclusion MOVED ======= *)

(* Every list a shipped leg consumes, instantiated exactly as those legs
   instantiate them. The first TWELVE are t_p20_regression's roster (its
   D3 form); the THIRTEENTH is P21's own family.

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

let missing_from_roster (invs : Invariants.invariant list) :
    (string * string) list =
  List.filter
    (fun (p : string * string) -> not (List.mem p roster_pairs))
    (Pair_guard.pairs_of invs)

let test_roster_covers_p19_p20_and_p21 () =
  Alcotest.(check (list string))
    "the roster is THIRTEEN suites - t_p20_regression's twelve PLUS \
     guarantee_family (a verbatim copy of the P20 roster reddens here)"
    committed_roster
    (List.map
       (fun ((label, _) : string * Invariants.invariant list) -> label)
       shipped_suites);
  Alcotest.(check int)
    "twelve suites are swept (the P21 self-entry is excluded; the P20 entry \
     is IN the swept set now)"
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
    (missing_from_roster family)

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
    "no P21 guarantee member shares a name or source with any of the twelve \
     other shipped suites (both argument orders, incl. P20's)"
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

(* Every proof/internal_rely_guarantee.rs line cited ANYWHERE in the roster,
   deduped and ascending - read off the live records, never re-typed. *)
let roster_guarantee_lines : int list =
  List.sort_uniq Int.compare
    (List.filter_map
       (fun ((_, src) : string * string) ->
         Option.bind
           (if String.starts_with ~prefix:guarantee_prefix src then Some src
            else None)
           line_of_source)
       roster_pairs)

let ledgered_excluded_lines : int list =
  P21_witness.ledger_e1_lines @ P21_witness.ledger_e2_lines
  @ P21_witness.ledger_e3_e5_lines

let test_e_ledger_reversal_clause () =
  Alcotest.(check bool)
    "every G1-G4 source names proof/internal_rely_guarantee.rs" true
    (List.for_all (String.starts_with ~prefix:guarantee_prefix)
       Ig.guarantee_sources);
  Alcotest.(check (list int))
    "the ONLY internal_rely_guarantee.rs lines shipped anywhere in the \
     thirteen-suite roster are G1-G4's"
    P21_witness.ledger_shipped_lines roster_guarantee_lines;
  Alcotest.(check (list int))
    "no line ledgered as EXCLUDED (E1 :522 / E2 :528 / E3-E5 \
     :606/:613/:640) is shipped by any suite - a hit RE-OPENS the exclusion \
     (and for :528 would also collide with P19's M1, its semantic twin)"
    []
    (List.filter
       (fun (n : int) -> List.mem n roster_guarantee_lines)
       ledgered_excluded_lines);
  (* The ledger is still TOTAL and DISJOINT at the file's measured cardinal
     (NINE pub open spec fn, counted at build time; 4 shipped + 5 excluded). *)
  Alcotest.(check int)
    "shipped + ledgered = the file's 9 pub open spec fn, no orphan and no \
     double-ledgering"
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
            "the roster is THIRTEEN suites and really covers P19, P20 and P21"
            `Quick test_roster_covers_p19_p20_and_p21;
          Alcotest.test_case
            "family DISJOINT from every other shipped suite (Pair_guard, \
             both orders; P20 now in the swept set)"
            `Quick test_family_is_disjoint_from_shipped_suites;
        ] );
      ( "exclusion_pins",
        [
          Alcotest.test_case
            "E-ledger reversal clause: no ledgered-excluded \
             internal_rely_guarantee line is shipped anywhere"
            `Quick test_e_ledger_reversal_clause;
        ] );
    ]

(* BUILD-SPEC-P19 sections 2-3 - the CLASSIFICATION FIREWALL of the
   message-provenance family (the P14-P16/P18 DISJOINT-family pattern) plus
   the measured exclusion pins E1' / E2' / E3' / E4' and the sanctioned
   P18-literal graph-pin duplication.

   THE CLASSIFICATION (spec section 2): M1-M4 are a genuinely NEW family -
   no member is shipped anywhere (rg-swept at B1: zero hits in lib/ and
   test/), so P17's filter pattern was structurally unavailable and the
   P14-P16/P18 disjoint pattern applies verbatim. Pinned here in the
   k3-strengthened (name, source) form via the shared {!Pair_guard}.

   ---- what this file DOES ---------------------------------------------------

   - P18's COMMITTED PINS re-typed as literals (the one sanctioned
     duplication, P14's rationale: "fix the red by editing the witness"
     reddens HERE), held against BOTH [P18_witness] - the module P18's own
     exes read - and [P19_witness], which DERIVES its four graph constants
     from that chain. A seed/bound drift, or a witness edited to make a red
     go away, reddens here first.

   - THE DISJOINTNESS SWEEP (spec section 2, "Classification firewall"):
     [provenance_family] against ALL shipped suites - the
     [t_p18_regression.ml:179-198] roster PLUS P18's own
     [Helper_invariants.helper_family] - via {!Pair_guard.pair_leaks}, run
     in BOTH argument orders. The detector is either-component (a shared
     NAME or a shared SOURCE is a hit), so one order already covers both
     leak directions; running both orders makes the coverage explicit
     rather than inferred.

   - THE E1' PIN (spec section 3): the valid-controller-id conjunct of the
     :1213-consuming proof (helper_invariants.rs:1206) is ALREADY SHIPPED
     as P14's N4 (correspondence.ml:160-164, network.rs:312). Including it
     would have been a pair_guard LEAK, not a fourth member. Pinned by the
     P14-N4 leak-sweep mechanism: the exact N4 (name, source) pair is
     absent from the P19 family, the family is disjoint from P14's, and a
     POSITIVE CONTROL shows the same detector finding N4 where it really
     lives.

   - THE E2' PIN (spec section 3): [internal_rely_guarantee.rs:528-540]
     defines a semantic duplicate of :1213 under the SAME upstream name.
     P19 cites [helper_invariants.rs:1213] ONLY, and the [source] string IS
     the pin - asserted here as an exact literal plus the absence of any
     [internal_rely_guarantee] citation in the family.

   - THE E3' PIN (spec section 3): the payload-register siblings
     ([vsts_guarantee], [vsts_internal_guarantee_conditions]) constrain
     controller REQUEST PAYLOADS - the register shipped [inv_self] (widened
     inv9) occupies. P19 takes the TAG register only, so [inv_self]'s name
     must still be shipped by [Vsts_invariants.always] (positive control)
     and must NOT appear in the P19 family.

   - THE E4' LEDGER (spec section 3): B1's enumeration of network.rs's
     thirteen [pub open spec fn], with P14's five, P19's three and (after
     the D2 fix) P15's one crossed out, and a one-line reason ledgered for
     every leftover. The ledger is BUILT from the shipped suites (names and
     sources read off the live invariant records) and checked against the
     committed B1 text, so a rename, a source drift, a member added to or
     dropped from any suite this file reads, or a leftover promoted INTO a
     shipped family without a ledger edit reddens HERE. SCOPE, exactly, as
     WIDENED BY D2: the crossed-out side now reads every entry of
     [shipped_suites], not just [Correspondence.family] and
     [provenance_family] - which is what the D2 defect was, since P15 had
     shipped :104 and this guard was ledgering it as an unshipped leftover.
     What is still outside reach is a member shipped by a module absent
     from that roster; the leftover strings themselves remain one binding
     used on both sides of the comparison. A second assert re-derives the
     accounting: crossed-out lines + ledgered leftovers = exactly the
     thirteen enumerated, each once.

   ---- P20 stage B6 edits (BUILD-SPEC-P20 section 6, pre-authorized) --------

   D1 and D2 ONLY, both CONFIRMED BY MUTATION at the site of each fix:
   D1 corrected the E2' [internal_rely_guarantee] prefix from a path that
   does not exist upstream (the guard could never fire); D2 reclassified
   network.rs :104 from "unshipped leftover" to "shipped by P15's R1" and
   widened the crossed-out side to every shipped suite. D3 (the 12-entry
   roster) and D4 (the [inv_self] citation drift) are NOT here - D3 lands
   in [t_p20_regression.ml], D4 in [lib/assurance/vsts_invariants.ml].

   ---- what it does NOT do (anti-duplication, the P15-P18 rationale) --------

   It does NOT re-run P13-P18's own legs (their batteries already do) and
   does NOT re-pin any P19 number ([p19_witness.ml] is the single source;
   this file only READS it). List lengths of the SHIPPED suites are
   deliberately not pinned; the family's own cardinal IS pinned (it is the
   phase's deliverable, not a shared suite).

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum, no two-arm match on
   [option]/[result] (stdlib [Option.fold] / [Option.map] - [~none] is
   EAGER, so only values sit there), Alcotest as the sanctioned failure
   primitive. *)

module Fc = Anvil_checker.Fault_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vsts_invariants = Anvil_assurance.Vsts_invariants
module Correspondence = Anvil_assurance.Correspondence
module Rc = Anvil_assurance.Reconcile_correspondence
module Rr = Anvil_assurance.Req_resp_correspondence
module Ois = Anvil_assurance.Objects_in_store
module Hi = Anvil_assurance.Helper_invariants
module Mp = Anvil_assurance.Msg_provenance

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P19_witness.witness_desired
let bound : Bound.t = P19_witness.p19_bound ~desireds:[ desired ]
let family : Invariants.invariant list = Mp.provenance_family ~controller_id

let names_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.name) invs

let sources_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.source) invs

(* ==== 1. P18's committed pins, re-pinned here as literals ================== *)

(* The literals as committed on the P18 branch, held against the witness
   modules the P18/P19 tests actually read. The four graph constants are the
   P13-P18 identity (spec section 5 prediction 1): the product graph depends
   only on (seed, bound, budget, depth), never on the invariant list, so P19
   DERIVES them rather than re-measuring - and this section is where a
   derivation break, a seed drift, or a "fix the red by editing the witness"
   repair reddens. Re-pinning is the one forbidden repair. *)

let committed_p18_l0_states : int = 76
let committed_p18_lc_states : int = 464
let committed_p18_ld_states : int = 744
let committed_p18_lm_states : int = 1976
let committed_p18_lc_crash_witness_states : int = 388
let committed_p18_lc_fault_free_states : int = 76
let committed_p18_ld_fault_free_states : int = 152
let committed_p18_lm_fault_free_states : int = 152
let committed_p18_l0_gate_states : int = 52
let committed_p18_lc_gate_states : int = 244
let committed_p18_ld_gate_states : int = 272
let committed_p18_lm_gate_states : int = 1520
let committed_p18_h1_interesting_l0 : int = 52
let committed_p18_h2_interesting_l0 : int = 0
let committed_p18_l0v_states : int = 116

let test_p18_pins_are_the_committed_literals () =
  Alcotest.(check int) "P18 L0 states: 76 (committed)" committed_p18_l0_states
    P18_witness.l0_states;
  Alcotest.(check int) "P18 Lc states: 464 (committed)" committed_p18_lc_states
    P18_witness.lc_states;
  Alcotest.(check int) "P18 Ld states: 744 (committed)" committed_p18_ld_states
    P18_witness.ld_states;
  Alcotest.(check int) "P18 Lm states: 1976 (committed)" committed_p18_lm_states
    P18_witness.lm_states;
  Alcotest.(check int) "P18 Lc crash-witness slice: 388 (committed)"
    committed_p18_lc_crash_witness_states P18_witness.lc_crash_witness_states;
  Alcotest.(check int) "P18 Lc fault-free slice: 76 (committed)"
    committed_p18_lc_fault_free_states P18_witness.lc_fault_free_states;
  Alcotest.(check int) "P18 Ld fault-free slice: 152 (committed)"
    committed_p18_ld_fault_free_states P18_witness.ld_fault_free_states;
  Alcotest.(check int) "P18 Lm fault-free slice: 152 (committed)"
    committed_p18_lm_fault_free_states P18_witness.lm_fault_free_states;
  Alcotest.(check int) "P18 L0 gate: 52 (committed)"
    committed_p18_l0_gate_states P18_witness.l0_gate_states;
  Alcotest.(check int) "P18 Lc gate: 244 (committed)"
    committed_p18_lc_gate_states P18_witness.lc_gate_states;
  Alcotest.(check int) "P18 Ld gate: 272 (committed)"
    committed_p18_ld_gate_states P18_witness.ld_gate_states;
  Alcotest.(check int) "P18 Lm gate: 1520 (committed)"
    committed_p18_lm_gate_states P18_witness.lm_gate_states;
  Alcotest.(check int) "P18 H1 L0 count: 52 (committed)"
    committed_p18_h1_interesting_l0 P18_witness.h1_interesting_l0;
  Alcotest.(check int) "P18 H2 L0 count: 0 (committed, honest vacuity)"
    committed_p18_h2_interesting_l0 P18_witness.h2_interesting_l0;
  Alcotest.(check int) "P16 L0v states: 116 (P18's derivation base)"
    committed_p18_l0v_states P18_witness.l0v_states

(* The SAME literals against P19's witness: the derivation chain
   (P19 <- P18 <- P17/P16 <- P15/P13) is what makes P19's legs the P13-P18
   graphs rather than four new measurements that happen to agree. *)
let test_p19_graph_constants_are_derived_not_new () =
  Alcotest.(check int) "P19 L0 states = the committed 76"
    committed_p18_l0_states P19_witness.l0_states;
  Alcotest.(check int) "P19 Lc states = the committed 464"
    committed_p18_lc_states P19_witness.lc_states;
  Alcotest.(check int) "P19 Ld states = the committed 744"
    committed_p18_ld_states P19_witness.ld_states;
  Alcotest.(check int) "P19 Lm states = the committed 1976"
    committed_p18_lm_states P19_witness.lm_states;
  Alcotest.(check int) "P19 Lc crash-witness slice = the committed 388"
    committed_p18_lc_crash_witness_states P19_witness.lc_crash_witness_states;
  Alcotest.(check int) "P19 Lc fault-free slice = the committed 76"
    committed_p18_lc_fault_free_states P19_witness.lc_fault_free_states;
  Alcotest.(check int) "P19 Ld fault-free slice = the committed 152"
    committed_p18_ld_fault_free_states P19_witness.ld_fault_free_states;
  Alcotest.(check int) "P19 Lm fault-free slice = the committed 152"
    committed_p18_lm_fault_free_states P19_witness.lm_fault_free_states

(* ==== 2. the family classification: DISJOINTNESS =========================== *)

let m1_name : string = "every_msg_from_vsts_controller_carries_vsts_key"
let m2_name : string = "all_requests_from_pod_monkey_are_api_pod_requests"

let m3_name : string =
  "all_requests_from_builtin_controllers_are_api_delete_requests"

let m4_name : string = "no_pending_request_to_api_server_from_api_server_or_external"
let m1_source : string = "vstatefulset_controller/proof/helper_invariants.rs:1213"
let m2_source : string = "kubernetes_cluster/proof/network.rs:570"
let m3_source : string = "kubernetes_cluster/proof/network.rs:618"
let m4_source : string = "kubernetes_cluster/proof/network.rs:540"

(* The four (name, source) pairs as COMMITTED LITERALS, compared against the
   family - a rename, a source drift, or a re-implementation reddens HERE
   regardless of how the family is built. M1 cites the vstatefulset proof
   file (E2': NOT internal_rely_guarantee.rs:528, its same-named semantic
   duplicate); M2-M4 cite the cluster network proof. *)
let expected_pairs : (string * string) list =
  [
    (m1_name, m1_source);
    (m2_name, m2_source);
    (m3_name, m3_source);
    (m4_name, m4_source);
  ]

let test_family_names_and_pairs () =
  Alcotest.(check (list string))
    "provenance_family is M1/M2/M3/M4 in upstream order"
    [ m1_name; m2_name; m3_name; m4_name ]
    (names_of family);
  Alcotest.(check (list (pair string string)))
    "family (name, source) pairs = the committed literals, in member order"
    expected_pairs
    (Pair_guard.pairs_of family);
  Alcotest.(check (list string))
    "family sources = provenance_sources, in order" Mp.provenance_sources
    (sources_of family);
  Alcotest.(check int) "provenance_family cardinal = 4" 4 (List.length family)

(* Every list a PRIOR phase's leg consumes, instantiated exactly as those
   legs instantiate them - the P14-P16 firewall roster, the P17 store family
   and P18's helper family (the suite a P19 leak would poison first: it is
   the register whose E6 guard P19 just claimed). *)
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
      Rc.family ~controller_id ~pending_states:Fc.vsts_pending_states
        ~none_states:Fc.vsts_none_states );
    ("Req_resp_correspondence.rv_family (P16)", Rr.rv_family bound);
    ("Req_resp_correspondence.matched_family (P16)", Rr.matched_family ~controller_id);
    ("Objects_in_store.store_family (P17)", Ois.store_family ~controller_id);
    ( "Helper_invariants.helper_family (P18)",
      Hi.helper_family ~cr:(Scenario.vsts ~desired ~vct:false ()) ~controller_id );
  ]

(* THE MASKING-TRAP GUARD (P14-P16/P18 pattern). A P19 member found in ANY
   shipped suite means prior pins are no longer measuring what they claim
   (pin reason), and a unioned leg could report an earlier-firing member
   instead of the intended one (masking reason). {!Pair_guard.pair_leaks}
   detects a shared NAME or a shared SOURCE in either list, so ONE sweep
   already covers both leak directions; the second argument order below
   makes that coverage explicit instead of inferred. *)
let leaks_against (suites : (string * Invariants.invariant list) list) :
    string list =
  List.concat_map
    (fun ((suite, invs) : string * Invariants.invariant list) ->
      Pair_guard.pair_leaks
        ("P19 -> " ^ suite)
        (Pair_guard.pairs_of family)
        (Pair_guard.pairs_of invs)
      @ Pair_guard.pair_leaks
          ("P19 <- " ^ suite)
          (Pair_guard.pairs_of invs)
          (Pair_guard.pairs_of family))
    suites

let test_family_is_disjoint_from_shipped_suites () =
  Alcotest.(check (list string))
    "no P19 provenance member shares a name or source with a shipped suite \
     (both argument orders, incl. P18's helper_family)"
    []
    (leaks_against shipped_suites);
  (* The sweep is SEEN red-capable: the same detector, run with the family
     against ITSELF, reports every member - so the empty list above is a
     measured absence, not a broken traversal. *)
  Alcotest.(check int)
    "sweep control: family-vs-itself reports every member in both orders"
    (2 * List.length family)
    (List.length (leaks_against [ ("SELF (control)", family) ]))

(* ==== 3. E1' - the valid-controller-id conjunct is P14's N4 ================= *)

(* helper_invariants.rs:1206 conjoins
   [every_in_flight_req_msg_from_controller_has_valid_controller_id] into the
   proof that consumes :1213. It is ALREADY SHIPPED as P14's N4
   (correspondence.ml:160-164), so P19 excluding it is not a gap: including
   it would have been a pair_guard leak. The mechanism IS the leak sweep. *)

let n4_name : string =
  "every_in_flight_req_msg_from_controller_has_valid_controller_id"

let n4_source : string = "kubernetes_cluster/proof/network.rs:312"

let p14_family : Invariants.invariant list =
  Correspondence.family cluster ~controller_id

let test_e1_valid_controller_id_is_p14_n4 () =
  (* POSITIVE CONTROL first: N4 really is where E1' says it is. *)
  Alcotest.(check bool)
    "E1' control: P14's family ships the (name, source) pair of N4" true
    (List.mem (n4_name, n4_source) (Pair_guard.pairs_of p14_family));
  Alcotest.(check bool) "E1': the N4 name is absent from the P19 family" false
    (List.mem n4_name (names_of family));
  Alcotest.(check bool) "E1': the N4 source is absent from the P19 family" false
    (List.mem n4_source (sources_of family));
  Alcotest.(check (list string))
    "E1': the four P19 pairs are disjoint from P14's five (either component)"
    []
    (leaks_against [ ("Correspondence.family (P14)", p14_family) ])

(* ==== 4. E2' - the source citation IS the pin ============================== *)

(* [internal_rely_guarantee.rs:528-540] defines a semantic duplicate of
   :1213 under the SAME upstream name (bridged in liveness/proof.rs:903-926).
   The name therefore cannot discriminate; the [source] string can, and P19
   commits to the helper_invariants citation.

   {b D1 FIX} (BUILD-SPEC-P20 section 6, applied by P20 stage B6). This prefix
   read ["kubernetes_cluster/proof/internal_rely_guarantee.rs"] - a path that
   DOES NOT EXIST upstream. MEASURED with [fd] over anvil-ref: the Anvil tree
   holds exactly one [internal_rely_guarantee.rs], at
   [src/controllers/vstatefulset_controller/proof/], and
   [kubernetes_cluster/proof/] has none. No [source] string in this port could
   ever start with the old literal, so the second assertion below filtered
   against an unmatchable prefix and asserted the empty result - VACUOUS, a
   green that verified nothing.

   CONFIRMED BY MUTATION (P20 stage B6; a guard never SEEN to fail is not
   evidence). With M1's source temporarily re-pointed to
   ["vstatefulset_controller/proof/internal_rely_guarantee.rs:528"] - exactly
   the same-named duplicate E2' exists to forbid - and [m1_source] moved with
   it so the two asserts above stay green and this one is isolated: the OLD
   literal left this assertion GREEN (0 hits) and the corrected literal takes
   it RED (1 hit). Same mutation, opposite verdicts. That differential is the
   whole evidence for D1; both edits were reverted by exact [Edit]. *)

let internal_rely_guarantee_prefix : string =
  "vstatefulset_controller/proof/internal_rely_guarantee.rs"

let has_prefix (prefix : string) (s : string) : bool =
  String.length s >= String.length prefix
  && String.equal (String.sub s 0 (String.length prefix)) prefix

let test_e2_m1_cites_helper_invariants_only () =
  Alcotest.(check (list string))
    "E2': M1's source is helper_invariants.rs:1213 (the family's only \
     vstatefulset citation)"
    [ m1_source ]
    (List.filter
       (fun (s : string) ->
         has_prefix "vstatefulset_controller/proof/" s)
       (sources_of family));
  Alcotest.(check (list string))
    "E2': no family member cites internal_rely_guarantee.rs" []
    (List.filter (has_prefix internal_rely_guarantee_prefix) (sources_of family))

(* ==== 5. E3' - the payload register stays inv_self's ======================= *)

(* [vsts_guarantee] / [vsts_internal_guarantee_conditions] constrain
   controller REQUEST PAYLOADS - the register shipped [inv_self] (widened
   inv9) occupies. P19 takes the TAG register only; porting the payload
   siblings would re-open the P17-review overlap-misread class that E6 was
   originally excluded for. *)

let inv_self_name : string =
  "vsts_reconcile_request_only_interferes_with_itself"

let test_e3_payload_register_untouched () =
  Alcotest.(check bool)
    "E3' control: inv_self still ships the payload register in \
     Vsts_invariants.always"
    true
    (List.mem inv_self_name
       (names_of
          (Vsts_invariants.always ~cr:(Scenario.vsts ~desired:1 ()) ~controller_id)));
  Alcotest.(check bool)
    "E3': the P19 family does NOT ship the payload-register name" false
    (List.mem inv_self_name (names_of family))

(* ==== 6. E4' - the network.rs remainder ledger ============================= *)

(* B1's enumeration of every [pub open spec fn] in
   kubernetes_cluster/proof/network.rs, measured against the upstream tree.
   The crossed-out entries below are BUILT from the shipped families, so the
   ledger cannot drift away from what is actually ported. *)

let b1_network_spec_fn_lines : int list =
  [ 15; 19; 35; 76; 104; 171; 254; 312; 382; 514; 540; 570; 618 ]

let network_prefix : string = "kubernetes_cluster/proof/network.rs:"

let network_line_of (i : Invariants.invariant) : int option =
  let src : string = i.Invariants.source in
  Option.bind
    (if has_prefix network_prefix src then
       Some
         (String.sub src (String.length network_prefix)
            (String.length src - String.length network_prefix))
     else None)
    int_of_string_opt

(* The (upstream line, name) of every network.rs member of a suite, in
   ascending line order - read off the LIVE records, never re-typed. *)
let network_members (invs : Invariants.invariant list) : (int * string) list =
  List.sort
    (fun ((a, _) : int * string) ((b, _) : int * string) -> Int.compare a b)
    (List.filter_map
       (fun (i : Invariants.invariant) ->
         Option.map
           (fun (line : int) -> (line, i.Invariants.name))
           (network_line_of i))
       invs)

(* {b D2 FIX} (BUILD-SPEC-P20 section 6, applied by P20 stage B6), second
   half. The ledger below used to read exactly TWO families - [p14_family] and
   P19's own [family] - and ledgered network.rs [:104] as an unshipped
   leftover because it is "key-parameterized ... inside P14's pending-req
   register". That reasoning was wrong ABOUT THE TREE:
   [Reconcile_correspondence.pending_req_of_key_is_unique_with_unique_id]
   (reconcile_correspondence.ml:127-131) has shipped that EXACT name and that
   EXACT source ["kubernetes_cluster/proof/network.rs:104"] since P15 - and
   P15's suite was already sitting in [shipped_suites] a hundred lines above,
   unread by this guard. The blind spot P19's own F1 correction described as
   HYPOTHETICAL ("a leftover shipped in a NEW module leaves the guard green")
   had already fired at the time it was written.

   Both halves of D2 are applied here: :104 is reclassified as SHIPPED (P15's
   R1) with its cite, and the CROSSED-OUT side is now built from EVERY suite
   in [shipped_suites], not from two hand-picked families. MEASURED over the
   whole roster: P15's R1 is the only network.rs member outside P14's five and
   P19's three (swept with [rg 'kubernetes_cluster/proof/network\.rs:'
   lib/assurance/] - correspondence.ml x5, msg_provenance.ml x3,
   reconcile_correspondence.ml x1). *)
let other_shipped_network_members : (int * string) list =
  let p14_lines : int list =
    List.map
      (fun ((line, _) : int * string) -> line)
      (network_members p14_family)
  in
  List.sort_uniq compare
    (List.filter
       (fun ((line, _) : int * string) -> not (List.mem line p14_lines))
       (network_members
          (List.concat_map
             (fun ((_, invs) : string * Invariants.invariant list) -> invs)
             shipped_suites)))

let member_tags : (int * string) list =
  [
    (35, "N1");
    (76, "N2");
    (104, "P15 R1, = the D2 reclassification");
    (254, "N3");
    (312, "N4, = E1'");
    (382, "N5");
    (540, "M4");
    (570, "M2");
    (618, "M3");
  ]

let tag_of (line : int) : string =
  Option.fold (List.assoc_opt line member_tags) ~none:"UNTAGGED" ~some:Fun.id

let render_member ((line, name) : int * string) : string =
  ":" ^ string_of_int line ^ " " ^ name ^ " (" ^ tag_of line ^ ")"

let render_members (ms : (int * string) list) : string =
  String.concat "; " (List.map render_member ms)

let render_lines (ls : int list) : string =
  String.concat " " (List.map (fun (l : int) -> ":" ^ string_of_int l) ls)

(* The FOUR leftovers (five before the D2 fix), each with its one-line reason
   (the E4' requirement). None is a sender-classification member - they are
   the rpc-id / allocator register - so E4' carries NO reversal clause this
   phase. *)

let e4_leftover_lines : int list = [ 15; 19; 171; 514 ]

let e4_leftovers : string list =
  [
    ":15 rpc_id_counter_is(rpc_id) - not an always-member: parameterized on a \
     counter VALUE (a witness state predicate; lemma :23 consumes it as the \
     hypothesis for :19)";
    ":19 rpc_id_counter_is_no_smaller_than(rpc_id) - not an always-member \
     either: an always only RELATIVE to a chosen rpc_id (lemma :23 premises \
     :15), so there is no closed member to port";
    ":171 every_in_flight_req_msg_has_different_id_from_pending_req_msg_of(controller_id, \
     key) - the key-parameterized specialization that P14's shipped N3 \
     (:254) already quantifies over every ongoing reconcile; no added \
     discrimination";
    ":514 every_in_flight_msg_has_unique_id() - an always-member but strictly \
     WEAKER than P14's shipped N5 (:382): upstream DERIVES it from N5 by \
     always_weaken at :530-535 (correspondence.ml:185-188 records the same \
     derivation)";
    "SCOPE PIN (E4'): no unshipped always SENDER-CLASSIFICATION sibling \
     remains in network.rs, so this phase's ledger carries no reversal \
     clause";
  ]

(* The ledger, BUILT: the header from B1's enumeration, the two crossed-out
   lines from the SHIPPED families, the leftovers from the literals above. *)
let e4_ledger : string list =
  ("network.rs has exactly "
   ^ string_of_int (List.length b1_network_spec_fn_lines)
   ^ " `pub open spec fn`: "
   ^ render_lines b1_network_spec_fn_lines)
  :: ("CROSSED OUT (P14's five): " ^ render_members (network_members p14_family))
  :: ("CROSSED OUT (P19 members): " ^ render_members (network_members family))
  :: ("CROSSED OUT (shipped by ANOTHER roster suite - the D2 fix): "
     ^ render_members other_shipped_network_members)
  :: e4_leftovers

(* The committed B1 text. A rename, a source drift, a member added to or
   dropped from ANY suite in [shipped_suites], or a leftover promoted INTO a
   shipped family without a ledger edit reddens here.

   BLIND SPOT, NARROWED BY D2 BUT NOT CLOSED. The crossed-out side is now
   built from every suite in [shipped_suites] (ten of them) rather than from
   [p14_family] + [family], so the case that actually fired here - a leftover
   shipped by a NEW module, P15's :104 - is now in reach. What remains out of
   reach is a leftover shipped by a module NOT in that roster at all: the
   roster is a hand-maintained list, and [e4_leftovers] is still the SAME
   binding on both sides of the comparison below, so that half stays a
   tautology. Keeping the roster current is each phase's own ledger edit to
   make; BUILD-SPEC-P20 section 6 D3 is exactly that edit for P19's and P20's
   own families, made in [t_p20_regression.ml]. *)
let committed_e4_ledger : string list =
  [
    "network.rs has exactly 13 `pub open spec fn`: :15 :19 :35 :76 :104 :171 \
     :254 :312 :382 :514 :540 :570 :618";
    "CROSSED OUT (P14's five): :35 every_in_flight_msg_has_lower_id_than_allocator \
     (N1); :76 every_pending_req_msg_has_lower_id_than_allocator (N2); :254 \
     every_in_flight_req_msg_has_different_id_from_pending_req_msg_of_every_ongoing_reconcile \
     (N3); :312 every_in_flight_req_msg_from_controller_has_valid_controller_id \
     (N4, = E1'); :382 every_in_flight_msg_has_no_replicas_and_has_unique_id \
     (N5)";
    "CROSSED OUT (P19 members): :540 \
     no_pending_request_to_api_server_from_api_server_or_external (M4); :570 \
     all_requests_from_pod_monkey_are_api_pod_requests (M2); :618 \
     all_requests_from_builtin_controllers_are_api_delete_requests (M3)";
    "CROSSED OUT (shipped by ANOTHER roster suite - the D2 fix): :104 \
     pending_req_of_key_is_unique_with_unique_id (P15 R1, = the D2 \
     reclassification)";
  ]
  @ e4_leftovers

let test_e4_network_remainder_ledger () =
  Alcotest.(check (list string))
    "E4': the B1 network.rs ledger, built from the shipped families"
    committed_e4_ledger e4_ledger;
  (* The accounting, re-derived: every one of the thirteen is either crossed
     out by a shipped suite or ledgered as a leftover, exactly once. The third
     disjunct is the D2 widening - :104 now enters through P15's shipped R1
     instead of through the leftover literals. *)
  Alcotest.(check (list int))
    "E4': crossed-out lines + ledgered leftovers = the thirteen enumerated, \
     each once"
    b1_network_spec_fn_lines
    (List.sort Int.compare
       (List.map (fun ((line, _) : int * string) -> line) (network_members p14_family)
       @ List.map (fun ((line, _) : int * string) -> line) (network_members family)
       @ List.map
           (fun ((line, _) : int * string) -> line)
           other_shipped_network_members
       @ e4_leftover_lines));
  (* D2's POSITIVE CONTROL, read off the LIVE P15 record rather than re-typed:
     :104 really is shipped, under upstream's own name, by the suite the old
     ledger never looked at. A P15 rename or source drift reddens here. *)
  Alcotest.(check (list (pair int string)))
    "D2: :104 is SHIPPED by P15's R1 (the reclassification's own control)"
    [ (104, "pending_req_of_key_is_unique_with_unique_id") ]
    other_shipped_network_members;
  Alcotest.(check bool)
    "D2: :104 is no longer ledgered as an unshipped leftover" false
    (List.mem 104 e4_leftover_lines);
  (* The three sender-classification lines are exactly P19's network members:
     the scope pin of the last ledger entry, mechanically. *)
  Alcotest.(check (list int)) "E4': P19's network.rs members are :540 :570 :618"
    [ 540; 570; 618 ]
    (List.map (fun ((line, _) : int * string) -> line) (network_members family))

let () =
  Alcotest.run "p19_regression"
    [
      ( "prior_phase_firewall",
        [
          Alcotest.test_case "P18/P16 witness constants are the committed pins"
            `Quick test_p18_pins_are_the_committed_literals;
          Alcotest.test_case
            "P19's graph constants are DERIVED from that chain" `Quick
            test_p19_graph_constants_are_derived_not_new;
        ] );
      ( "family_classification",
        [
          Alcotest.test_case
            "family = the four upstream names, committed (name, source) \
             pairs, cardinal 4"
            `Quick test_family_names_and_pairs;
          Alcotest.test_case
            "family DISJOINT from every shipped suite incl. P18 (Pair_guard, \
             both orders)"
            `Quick test_family_is_disjoint_from_shipped_suites;
        ] );
      ( "exclusion_pins",
        [
          Alcotest.test_case
            "E1': the valid-controller-id conjunct is P14's N4, not a member"
            `Quick test_e1_valid_controller_id_is_p14_n4;
          Alcotest.test_case
            "E2': M1 cites helper_invariants.rs:1213 only" `Quick
            test_e2_m1_cites_helper_invariants_only;
          Alcotest.test_case
            "E3': the payload register is still inv_self's" `Quick
            test_e3_payload_register_untouched;
          Alcotest.test_case
            "E4': the network.rs remainder ledger, built from shipped \
             families"
            `Quick test_e4_network_remainder_ledger;
        ] );
    ]

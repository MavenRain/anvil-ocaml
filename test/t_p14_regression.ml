(* BUILD-SPEC-P14 §4.5 - the CLASSIFICATION firewall for §4.2.

   P14 adds a five-member id-level correspondence family
   ({!Anvil_assurance.Correspondence}). §4.2 makes it a SEPARATE module with its
   own list, deliberately: {!Vsts_invariants.always} feeds BOTH the fault-free
   legs in [cluster_check.ml] AND P13's G1 at [fault_check.ml:318], so appending
   a member there would move P13's committed pins (464 / 388 / 388 / 76, G3 1856)
   and P12's (6952) and silently rewrite a shipped result.

   ---- what this module does NOT do, and why (anti-duplication) --------------

   It does NOT re-run P13's G1/G2/G3 or P12's gate to compare the numbers. Those
   comparisons ALREADY exist and already run in the battery:

     t_p13_faults.ml:478-484  Alcotest.(check int) on {!P13_witness.g1_states},
                              [g1_gate_states], [g1_crash_witness_states],
                              [g1_fault_free_states]
     t_p13_faults.ml:554      ditto {!P13_witness.g3_states}
     t_p13_mutation.ml:216-271 re-asserts g1_states / g1_gate_states /
                              g1_fault_free_states / g1_crash_witness_states
     t_p12_concurrent.ml:140  ditto {!P12_witness.pinned_gate_states}

   Re-running those model checks here would cost the battery ~50 s of CPU for
   ZERO new discrimination, which §2's "shipping both would double the cost for
   zero discrimination" argument forbids. §4.5 explicitly allows the firewall to
   be "a case inside the above", and the above is where it already is.

   ---- what this module DOES add, which those pins cannot -------------------

   Two failure modes are invisible to a count comparison:

   1. A red pin "fixed" by editing the witness CONSTANT instead of the leak.
      [test_p13_p12_pins_are_the_committed_literals] pins the literals a second
      time, in P14's own file, so the constants themselves are load-bearing.

   2. A leak that does not move any count. G1's gate is
      [f.crashes >= 1 && List.exists (fun i -> i.interesting f.cs) invs]
      ([fault_check.ml:326-332]): a member appended to {!Vsts_invariants.always}
      that HOLDS everywhere and whose [interesting] never fires changes neither
      [states] nor [gate_states]. It would still have silently reclassified the
      family. [test_family_is_disjoint_from_shipped_suites] rejects that by
      (name, source) pair (k3-strengthened, P17 §7),
      not by count.

   List lengths are deliberately NOT pinned: a later phase may legitimately
   extend a shipped suite, and its obligation is then to re-measure P13's counts,
   not to trip a length assertion that says nothing about WHICH member moved.

   Firewall honoured: List/Option combinators only (no loop keywords), no
   [List.nth/hd/tl], no [raise/assert/failwith/Option.get], Alcotest as the
   sanctioned failure primitive.

   ---- confirmed by mutation (SEEN red, then reverted) ----------------------

   Per [[feedback-confirm-tests-by-mutation]], both cases were observed failing:

   - [committed_g1_states] 464 -> 465: "P13 G1 states" FAILS with
     "Expected: `465' / Received: `464'", i.e. the assertion really reads
     {!P13_witness.g1_states} and that constant really is 464.
   - [shipped_suites] extended with [("MUTANT_leak", family)]: the disjointness
     case FAILS naming all five members, while the names case stays GREEN (the
     two cases are independent). *)

module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vsts_invariants = Anvil_assurance.Vsts_invariants
module Correspondence = Anvil_assurance.Correspondence

let controller_id : int = Scenario.controller_id

(* ==== 1. P13's and P12's committed pins, re-pinned in P14's own file ======= *)

(* The literals as committed at [aadf678] (P13) and [8a2a1ff] (P12), transcribed
   from BUILD-SPEC-P13.md:311-313 and p12_witness.ml:29. Held against the witness
   modules the P13/P12 tests actually read, so "fix the red by editing the pin"
   reddens HERE. *)

let committed_g1_states : int = 464
let committed_g1_gate_states : int = 388
let committed_g1_crash_witness_states : int = 388
let committed_g1_fault_free_states : int = 76
let committed_g3_states : int = 1856
let committed_p12_gate_states : int = 6952

let test_p13_p12_pins_are_the_committed_literals () =
  Alcotest.(check int)
    "P13 G1 states: 464 (committed at aadf678)" committed_g1_states
    P13_witness.g1_states;
  Alcotest.(check int)
    "P13 G1 gate_states: 388 (committed at aadf678)" committed_g1_gate_states
    P13_witness.g1_gate_states;
  Alcotest.(check int)
    "P13 G1 crash_witness_states: 388 (committed at aadf678)"
    committed_g1_crash_witness_states P13_witness.g1_crash_witness_states;
  Alcotest.(check int)
    "P13 G1 fault_free_states: 76 (committed at aadf678)"
    committed_g1_fault_free_states P13_witness.g1_fault_free_states;
  Alcotest.(check int)
    "P13 G3 states: 1856 (committed at aadf678)" committed_g3_states
    P13_witness.g3_states;
  Alcotest.(check int)
    "P12 gate_states: 6952 (committed at 8a2a1ff)" committed_p12_gate_states
    P12_witness.pinned_gate_states

(* ==== 2. the family is classified OUT of every shipped suite =============== *)

(* The five upstream spec-fn names, verbatim from
   [src/kubernetes_cluster/proof/network.rs] (N1 :35, N2 :76, N3 :254, N4 :312,
   N5 :382). Written out here rather than projected from the family so that a
   rename on ONE side is caught. *)
let upstream_names : string list =
  [
    "every_in_flight_msg_has_lower_id_than_allocator";
    "every_pending_req_msg_has_lower_id_than_allocator";
    "every_in_flight_req_msg_has_different_id_from_pending_req_msg_of_every_ongoing_reconcile";
    "every_in_flight_req_msg_from_controller_has_valid_controller_id";
    "every_in_flight_msg_has_no_replicas_and_has_unique_id";
  ]

let family : Invariants.invariant list =
  Correspondence.family Scenario.vsts_cluster ~controller_id

let names_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.name) invs

(* (name, source) pairs - the k3-strengthened identity for the disjointness
   guard (P17 §7): the NAME-string proxy missed a leaked member re-shipped
   under a different OCaml name (it keeps its upstream [source] citation),
   and a shipped member reusing one of these NAMES with a different source
   would still poison [violated] attribution - so a hit on EITHER component
   is reported. *)
let pairs_of (invs : Invariants.invariant list) : (string * string) list =
  List.map
    (fun (i : Invariants.invariant) -> (i.Invariants.name, i.Invariants.source))
    invs

let pair_leaks (label : string) (family_pairs : (string * string) list)
    (suite_pairs : (string * string) list) : string list =
  List.concat_map
    (fun ((n, src) : string * string) ->
      List.filter_map
        (fun ((n', src') : string * string) ->
          if String.equal n n' then Some (label ^ " contains name " ^ n)
          else if String.equal src src' then
            Some (label ^ " contains source " ^ src ^ " (as " ^ n' ^ ")")
          else None)
        suite_pairs)
    family_pairs

(* Every list that P13's G1 / P12's gate / the fault-free [cluster_check] legs
   read, instantiated exactly as those legs instantiate them
   ([fault_check.ml:311-318]). *)
let shipped_suites : (string * Invariants.invariant list) list =
  let vrs = Scenario.vrs ~desired:1 in
  let vsts = Scenario.vsts ~desired:1 () in
  [
    ("Invariants.cluster_structural", Invariants.cluster_structural ~controller_id);
    ("Invariants.always", Invariants.always ~cr:vrs ~controller_id);
    ("Invariants.eventually_always", Invariants.eventually_always ~cr:vrs ~controller_id);
    ("Vsts_invariants.always", Vsts_invariants.always ~cr:vsts ~controller_id);
  ]

let test_family_names_are_the_upstream_five () =
  Alcotest.(check (list string))
    "Correspondence.family is N1..N5 in upstream order" upstream_names
    (names_of family)

let test_family_is_disjoint_from_shipped_suites () =
  let leaked =
    List.concat_map
      (fun ((suite, invs) : string * Invariants.invariant list) ->
        pair_leaks suite (pairs_of family) (pairs_of invs))
      shipped_suites
  in
  Alcotest.(check (list string))
    "no P14 correspondence member leaked into a shipped suite" [] leaked

let () =
  Alcotest.run "p14_regression"
    [
      ( "p13_p12_firewall",
        [
          Alcotest.test_case "P13/P12 witness constants are the committed pins"
            `Quick test_p13_p12_pins_are_the_committed_literals;
        ] );
      ( "family_classification",
        [
          Alcotest.test_case "family = the five upstream network.rs names" `Quick
            test_family_names_are_the_upstream_five;
          Alcotest.test_case
            "family disjoint from every shipped invariant suite" `Quick
            test_family_is_disjoint_from_shipped_suites;
        ] );
    ]

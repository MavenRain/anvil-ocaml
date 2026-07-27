(* BUILD-SPEC-P15 §4.6 - the CLASSIFICATION firewall, P14's
   [t_p14_regression.ml] pattern extended by one phase.

   P15 adds a four-member RECONCILE-SIDE correspondence family
   ({!Anvil_assurance.Reconcile_correspondence}). §4.2 makes it a SEPARATE
   module with its own list, deliberately, for TWO reasons now instead of
   P14's one:

   1. THE PIN REASON (P14's): {!Invariants.always} / {!Vsts_invariants.always}
      feed the fault-free legs in [cluster_check.ml] AND P13's G1 at
      [fault_check.ml:318], and {!Correspondence.family} feeds P14's G2.
      Appending a member to any of them would move P13's committed pins
      (464 / 388 / 388 / 76, G3 1856), P12's (6952) or P14's (gates 32 / 296)
      and silently rewrite a shipped result.

   2. THE MASKING REASON (§3, new in P15 and the reason the disjointness test
      below is the most important test in this file): under mutation MA
      (restart also resets the rpc-id allocator) P14 MEASURED N1
      ([every_in_flight_msg_has_lower_id_than_allocator]) firing at
      [steps = 6], one step BEFORE an rpc-id collision can form. A leg
      asserting the P14 and P15 families TOGETHER would therefore report N1
      and never evaluate R3's exclusivity - the phase's headline would be
      masked by an earlier-firing member of the OTHER family. If any P15 leg
      ever reports [violated] naming a P14 member, the lists were unioned
      somewhere: harness bug, not finding.

   ---- what this module does NOT do, and why (anti-duplication) --------------

   It does NOT re-run P13's / P14's / P12's legs to compare counts. Those
   comparisons already run in the battery (t_p13_faults, t_p13_mutation,
   t_p12_concurrent, t_p14_correspondence assert every one of those pins
   against live legs), and re-running them here would cost ~50 s of CPU for
   zero new discrimination.

   ---- what it DOES add, which those pins cannot ----------------------------

   1. A red pin "fixed" by editing the witness CONSTANT instead of the leak:
      the P13/P12/P14 literals are pinned a SECOND time here, in P15's own
      file, so the constants themselves are load-bearing. (This is the one
      sanctioned duplication of pinned numbers - the duplication IS the
      firewall.)

   2. A leak that moves no count: a member appended to a shipped suite that
      HOLDS everywhere and whose [interesting] never fires changes neither
      [states] nor [gate_states] - and a P15 member unioned into
      {!Correspondence.family} would not move P14's gate at all (the gate is
      a union that P14's N1 already dominates) while still arming the §3
      masking trap. [test_family_is_disjoint_from_shipped_suites] rejects
      that by NAME, not by count.

   List lengths are deliberately NOT pinned (P14's rationale): a later phase
   may legitimately extend a shipped suite, and its obligation is then to
   re-measure the prior pins, not to trip a length assertion that says
   nothing about WHICH member moved.

   Firewall honoured: List/Option combinators only (no loop keywords), no
   [List.nth/hd/tl], no [raise/assert/failwith/Option.get], Alcotest as the
   sanctioned failure primitive. *)

module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vsts_invariants = Anvil_assurance.Vsts_invariants
module Correspondence = Anvil_assurance.Correspondence
module Rc = Anvil_assurance.Reconcile_correspondence
module Fc = Anvil_checker.Fault_check

let controller_id : int = Scenario.controller_id

(* ==== 1. P13's, P12's and P14's committed pins, re-pinned in P15's file ==== *)

(* The literals as committed at [aadf678] (P13), [8a2a1ff] (P12) and
   [f56b4cf] (P14), transcribed from BUILD-SPEC-P13.md:311-313,
   p12_witness.ml:29 and p14_witness.ml. Held against the witness modules the
   prior phases' tests actually read, so "fix the red by editing the pin"
   reddens HERE. If any of these moves, the P15 family leaked into a shared
   list (or a seed/bound drifted): STOP and find the leak - re-pinning is the
   one forbidden repair. *)

let committed_p13_g1_states : int = 464
let committed_p13_g1_gate_states : int = 388
let committed_p13_g1_crash_witness_states : int = 388
let committed_p13_g1_fault_free_states : int = 76
let committed_p13_g3_states : int = 1856
let committed_p12_gate_states : int = 6952
let committed_p14_g1_states : int = 76
let committed_p14_g1_gate_states : int = 32
let committed_p14_g2_states : int = 464
let committed_p14_g2_gate_states : int = 296
let committed_p14_g2_crash_witness_states : int = 388
let committed_p14_g2_fault_free_states : int = 76
let committed_p14_n5_interesting_g1 : int = 0
let committed_p14_n5_interesting_g2 : int = 84
let committed_p14_n5_interesting_g2_post_crash : int = 84

let test_p13_p12_pins_are_the_committed_literals () =
  Alcotest.(check int)
    "P13 G1 states: 464 (committed at aadf678)" committed_p13_g1_states
    P13_witness.g1_states;
  Alcotest.(check int)
    "P13 G1 gate_states: 388 (committed at aadf678)"
    committed_p13_g1_gate_states P13_witness.g1_gate_states;
  Alcotest.(check int)
    "P13 G1 crash_witness_states: 388 (committed at aadf678)"
    committed_p13_g1_crash_witness_states P13_witness.g1_crash_witness_states;
  Alcotest.(check int)
    "P13 G1 fault_free_states: 76 (committed at aadf678)"
    committed_p13_g1_fault_free_states P13_witness.g1_fault_free_states;
  Alcotest.(check int)
    "P13 G3 states: 1856 (committed at aadf678)" committed_p13_g3_states
    P13_witness.g3_states;
  Alcotest.(check int)
    "P12 gate_states: 6952 (committed at 8a2a1ff)" committed_p12_gate_states
    P12_witness.pinned_gate_states

let test_p14_pins_are_the_committed_literals () =
  Alcotest.(check int)
    "P14 G1 states: 76 (committed at f56b4cf)" committed_p14_g1_states
    P14_witness.g1_states;
  Alcotest.(check int)
    "P14 G1 gate_states: 32 (committed at f56b4cf)"
    committed_p14_g1_gate_states P14_witness.g1_gate_states;
  Alcotest.(check int)
    "P14 G2 states: 464 (committed at f56b4cf)" committed_p14_g2_states
    P14_witness.g2_states;
  Alcotest.(check int)
    "P14 G2 gate_states: 296 (committed at f56b4cf)"
    committed_p14_g2_gate_states P14_witness.g2_gate_states;
  Alcotest.(check int)
    "P14 G2 crash_witness_states: 388 (committed at f56b4cf)"
    committed_p14_g2_crash_witness_states P14_witness.g2_crash_witness_states;
  Alcotest.(check int)
    "P14 G2 fault_free_states: 76 (committed at f56b4cf)"
    committed_p14_g2_fault_free_states P14_witness.g2_fault_free_states;
  Alcotest.(check int)
    "P14 N5 G1 vacuity: 0 (committed at f56b4cf - the disclosed finding)"
    committed_p14_n5_interesting_g1 P14_witness.n5_interesting_g1;
  Alcotest.(check int)
    "P14 N5 G2 count: 84 (committed at f56b4cf)"
    committed_p14_n5_interesting_g2 P14_witness.n5_interesting_g2;
  Alcotest.(check int)
    "P14 N5 G2 post-crash count: 84 (committed at f56b4cf)"
    committed_p14_n5_interesting_g2_post_crash
    P14_witness.n5_interesting_g2_post_crash

(* ==== 2. the family is classified OUT of every shipped suite =============== *)

(* The four upstream spec-fn names, verbatim from the durable checkout at
   [~/Documents/anvil-ref]: R1 network.rs:104, R2
   controller_runtime_liveness.rs:131, R3 :147, R4 :105. Written out here
   rather than projected from the family so a rename on ONE side is caught. *)
let upstream_names : string list =
  [
    "pending_req_of_key_is_unique_with_unique_id";
    "pending_req_in_flight_or_resp_in_flight_at_reconcile_state";
    "pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg";
    "no_pending_req_msg_at_reconcile_state";
  ]

(* Instantiated exactly as the P15 leg instantiates it
   (fault_check.ml, [check_reconcile_correspondence_under_faults]). *)
let family : Invariants.invariant list =
  Rc.family ~controller_id ~pending_states:Fc.vsts_pending_states
    ~none_states:Fc.vsts_none_states

let names_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.name) invs

(* Every list a PRIOR phase's leg consumes, instantiated exactly as those legs
   instantiate them: the four suites P14's firewall guarded
   ([fault_check.ml:311-318] / the cluster_check legs) PLUS
   {!Correspondence.family} itself - P14's family is a shipped suite now, and
   it is the one a P15 leak would MASK (§3), not merely re-count. *)
let shipped_suites : (string * Invariants.invariant list) list =
  let vrs = Scenario.vrs ~desired:1 in
  let vsts = Scenario.vsts ~desired:1 () in
  [
    ("Invariants.cluster_structural", Invariants.cluster_structural ~controller_id);
    ("Invariants.always", Invariants.always ~cr:vrs ~controller_id);
    ("Invariants.eventually_always", Invariants.eventually_always ~cr:vrs ~controller_id);
    ("Vsts_invariants.always", Vsts_invariants.always ~cr:vsts ~controller_id);
    ( "Correspondence.family (P14)",
      Correspondence.family Scenario.vsts_cluster ~controller_id );
  ]

let test_family_names_are_the_upstream_four () =
  Alcotest.(check (list string))
    "Reconcile_correspondence.family is R1..R4 in upstream order"
    upstream_names (names_of family)

(* THE §3 MASKING-TRAP GUARD - the most important test in this file. A P15
   member found in ANY shipped suite means P13/P14/P12 pins are no longer
   measuring what they claim (pin reason), and a P15 leg unioned with P14's
   family would let N1 fire one step before R3's exclusivity can - burying
   this phase's headline behind an earlier-firing member (masking reason). *)
let test_family_is_disjoint_from_shipped_suites () =
  let leaked =
    List.concat_map
      (fun ((suite, invs) : string * Invariants.invariant list) ->
        List.filter_map
          (fun (n : string) ->
            Option.map
              (fun (hit : string) -> suite ^ " contains " ^ hit)
              (List.find_opt (String.equal n) (names_of invs)))
          upstream_names)
      shipped_suites
  in
  Alcotest.(check (list string))
    "no P15 reconcile-correspondence member leaked into a shipped suite" []
    leaked

(* And the reverse direction: no P14 member leaked INTO the P15 family - the
   union that would arm the masking trap on P15's own leg. P14's five
   upstream names, re-typed from t_p14_regression.ml (network.rs N1 :35,
   N2 :76, N3 :254, N4 :312, N5 :382). *)
let p14_upstream_names : string list =
  [
    "every_in_flight_msg_has_lower_id_than_allocator";
    "every_pending_req_msg_has_lower_id_than_allocator";
    "every_in_flight_req_msg_has_different_id_from_pending_req_msg_of_every_ongoing_reconcile";
    "every_in_flight_req_msg_from_controller_has_valid_controller_id";
    "every_in_flight_msg_has_no_replicas_and_has_unique_id";
  ]

let test_no_p14_member_in_the_p15_family () =
  let leaked =
    List.filter_map
      (fun (n : string) ->
        Option.map
          (fun (hit : string) -> "P15 family contains " ^ hit)
          (List.find_opt (String.equal n) (names_of family)))
      p14_upstream_names
  in
  Alcotest.(check (list string))
    "no P14 correspondence member unioned into the P15 family" [] leaked

let () =
  Alcotest.run "p15_regression"
    [
      ( "prior_phase_firewall",
        [
          Alcotest.test_case "P13/P12 witness constants are the committed pins"
            `Quick test_p13_p12_pins_are_the_committed_literals;
          Alcotest.test_case "P14 witness constants are the committed pins"
            `Quick test_p14_pins_are_the_committed_literals;
        ] );
      ( "family_classification",
        [
          Alcotest.test_case "family = the four upstream names in order" `Quick
            test_family_names_are_the_upstream_four;
          Alcotest.test_case
            "family disjoint from every shipped invariant suite (the §3 \
             masking-trap guard)"
            `Quick test_family_is_disjoint_from_shipped_suites;
          Alcotest.test_case "no P14 member unioned into the P15 family" `Quick
            test_no_p14_member_in_the_p15_family;
        ] );
    ]

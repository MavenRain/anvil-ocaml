(* BUILD-SPEC-P25 sections 3.1 / 3.3 - the E3 multi-CR assertion exe: the
   ONLY file that types the six new E3 pin literals (8580 / 8536 / 0 over
   P12's fair [1;1] graph; 10552 / 9200 / 0 over P13's G2 crash [1;1]
   graph), asserted against [P25_witness]'s COMPUTED values, plus the
   derivation guard / prior-phase firewall and a registered-equals-run case
   parity check. Witness/assertion separation per the P24 convention:
   graphs and computed counts live in the unlisted [p25_witness.ml]; the
   expected literals live HERE alone, so no pinned number appears in two
   files.

   THE ONE SANCTIONED EXCEPTION (p21_witness.ml:18-30's firewall rationale,
   honoured by every t_p2*_regression since): the firewall case below
   RE-TYPES the inherited P12/P13 graph literals (6952 / 10552 / 2784) and
   holds them against the committed witness modules, so "fix the red by
   editing the witness" has to redden somewhere. Those are P12/P13's
   numbers, not P25 measurements.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   exceptions, no two-arm match on Option/Result, no wildcard match on a
   finite sum, no raw indexing, no two same-named let bindings (a shadowed
   Alcotest registration dies silently). *)

(* ==== 1. the six minted E3 pins (BUILD-SPEC-P25 section 3.3) =============== *)

(* Fair graph, P12 [1;1] p12_bound (reconcile_ceiling 3), depth 40.
   8580 is the committed fair [1;1] graph size, prose-committed at
   t_p12_concurrent.ml:18,:21 ("8580 states, frontier emptied") - asserting
   the rebuilt graph's size against it IS the fair-side derivation guard. *)
let test_fair_pins () =
  Alcotest.(check int)
    "fair [1;1] states = the committed 8580 (t_p12_concurrent.ml:21 - \
     derivation guard: a moved seed/bound/depth reddens here)"
    8580 P25_witness.fair_states;
  Alcotest.(check int)
    "fair E3 premise (a VSTS-kind ongoing key exists) fires at 8536 states \
     - the multi-CR lift is genuinely non-vacuous"
    8536 P25_witness.fair_e3_premise;
  Alcotest.(check int) "fair E3 violating states = 0 (E3 holds)" 0
    P25_witness.fair_e3_violating

(* Crash graph, P13 G2 [1;1] p13_bound (reconcile_ceiling 2), crash-only
   budget, depth 40. *)
let test_crash_pins () =
  Alcotest.(check int)
    "crash [1;1] states = the committed 10552 (P13_witness.g2_states)" 10552
    P25_witness.crash_states;
  Alcotest.(check int)
    "crash E3 premise fires at 9200 states - non-vacuous under faults" 9200
    P25_witness.crash_e3_premise;
  Alcotest.(check int) "crash E3 violating states = 0 (E3 holds under crash)"
    0 P25_witness.crash_e3_violating

(* ==== 2. derivation guard + prior-phase firewall (BUILD-SPEC-P25 section
   3.1: "a drifted seed/bound reddens HERE rather than silently
   re-measuring"; section 2.2: the committed P12/P13 pins are FROZEN) ====== *)

let test_committed_p12_p13_pins_unmoved () =
  (* The committed pins themselves, RE-TYPED literals (the sanctioned
     firewall exception): a moved witness-module pin is a phase-STOP. *)
  Alcotest.(check int)
    "P12's committed inv6 gate pin is the committed 6952 (p12_witness.ml:30 \
     - FROZEN, BUILD-SPEC-P25 section 2.2)"
    6952 P12_witness.pinned_gate_states;
  Alcotest.(check int)
    "P13's committed G2 graph size is the committed 10552 \
     (p13_witness.ml:82 - FROZEN)"
    10552 P13_witness.g2_states;
  Alcotest.(check int)
    "P13's committed G2 gate pin is the committed 2784 (p13_witness.ml:83 - \
     FROZEN)"
    2784 P13_witness.g2_gate_states;
  (* Graph-identity controls, DERIVED not re-typed (t_p21_regression.ml:
     161-178's discipline): the rebuilt graphs still contain the committed
     gate populations, so P25's graphs are P12's/P13's own, not
     similarly-sized impostors. *)
  Alcotest.(check int)
    "the rebuilt fair graph's inv6 gate = P12's committed pin (derivation, \
     not coincidence)"
    P12_witness.pinned_gate_states P25_witness.fair_inv6_gate;
  Alcotest.(check int)
    "the rebuilt crash graph's >= 2-concurrent-after-a-crash gate = P13's \
     committed G2 gate pin (derivation, not coincidence)"
    P13_witness.g2_gate_states P25_witness.crash_inv6_crash_gate;
  Alcotest.(check int)
    "the rebuilt crash graph's size = P13's committed g2_states (derived \
     chain, same value the 10552 literal above re-types)"
    P13_witness.g2_states P25_witness.crash_states

(* ==== 3. registration ====================================================== *)

(* The three substantive cases; the parity case is appended at [run] and
   counts itself, so the total registered surface is asserted below. *)
let substantive_cases : unit Alcotest.test list =
  [
    ( "fair_multi_cr",
      [
        Alcotest.test_case
          "E3 over P12's fair [1;1] graph: 8580 states / premise 8536 / \
           violating 0"
          `Quick test_fair_pins;
      ] );
    ( "crash_multi_cr",
      [
        Alcotest.test_case
          "E3 over P13's G2 crash [1;1] graph: 10552 states / premise 9200 \
           / violating 0"
          `Quick test_crash_pins;
      ] );
    ( "prior_phase_firewall",
      [
        Alcotest.test_case
          "committed P12/P13 pins UNMOVED (6952 / 10552 / 2784) + the \
           rebuilt graphs reproduce them (derivation guard)"
          `Quick test_committed_p12_p13_pins_unmoved;
      ] );
  ]

(* Registered-equals-run parity (the shadowed-binding guard's counting
   half): every test_case value built above IS run, and the total - the
   three substantive cases plus this parity case itself - is FOUR. A
   silently-dropped registration (e.g. a shadowed duplicate group) moves
   the count and reddens here. t_p25_reconcile's LEG3 re-measured per-exe
   counts fresh at battery time (this exe = 4, seal-runtest-forced.log);
   this local literal is the exe's own guard, not that pin. *)
let registered_case_count : int = 4

let test_registered_equals_run () =
  Alcotest.(check int)
    "registered = run: 3 substantive cases + this parity case = 4"
    registered_case_count
    (1 + List.length (List.concat_map snd substantive_cases))

let () =
  Alcotest.run "p25_e3_multi_cr"
    (substantive_cases
    @ [
        ( "case_parity",
          [
            Alcotest.test_case "registered case count = run case count (4)"
              `Quick test_registered_equals_run;
          ] );
      ])

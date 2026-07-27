(* BUILD-SPEC-P16 §4.7 - the CLASSIFICATION firewall, P15's
   [t_p15_regression.ml] pattern extended by one phase.

   P16 adds a four-member REQUEST/RESPONSE correspondence family
   ({!Anvil_assurance.Req_resp_correspondence}), split into TWO lists by guard
   home (§2: [rv_family] = Q1-Q2, network + etcd guarded; [matched_family] =
   Q3 + Q5, reconcile-coupled). §4.4 keeps both lists in their own module,
   asserted on separate legs, for the two P15 reasons plus one:

   1. THE PIN REASON: {!Invariants.always} / {!Vsts_invariants.always} feed
      the fault-free legs and P13's G1, {!Correspondence.family} feeds P14's
      G2, {!Reconcile_correspondence.family} feeds P15's L0/L1. Appending a
      member to any of them would move a committed pin (P13's
      464 / 388 / 388 / 76 and G3 1856, P12's 6952, P14's 76 / 32 and
      464 / 296, P15's 76 / 64 and 464 / 304 / 388 / 76) and silently
      rewrite a shipped result.

   2. THE MASKING REASON (§4.4: "a [violated] naming any non-P16 member is a
      harness bug, not a finding"): under mutation MD the intended witness is
      Q5 BY NAME; a leg unioned with any earlier family could report an
      earlier-firing member (P14's N1 fires at [steps = 6] under MA) and bury
      the phase's headline. The disjointness tests below reject that by
      (name, source) pair (k3-strengthened, P17 §7).

   3. THE TWO-LIST REASON (new in P16): the rv/matched split IS the thesis
      under test, so the two lists must also be disjoint from EACH OTHER - a
      member in both would let one leg's verdict stand in for the other's.

   ---- what this file DOES beyond the P15 pattern ---------------------------

   - THE Q4 STRUCTURAL-VACUITY PIN (§2, the most important test here): Q4
     ([key_of_object_in_matched_ok_update_resp_...], req_resp.rs:240) is
     EXCLUDED as structurally unreachable because no shipped reconciler ever
     issues a plain [Api_method.Update_request] (only [Get_then_update*]).
     P14's N5 taught that such an exclusion must be MEASURED, not asserted.
     Two measurements below, both off the REAL code:
       (a) drive each shipped reconciler's [reconcile_core] over its full
           step-constructor space x a response menu and assert no emitted
           request is a plain update (and that the drive genuinely reaches
           each reconciler's [Get_then_update*] branch - the branch a plain
           update would come from);
       (b) fold over the reachable product graphs of the P16 legs (Lc, Lm,
           Ldv replicas) and assert no in-flight plain update exists from
           any non-monkey source (the pod monkey's [Update_pod] is the ONE
           sanctioned plain-update producer, and its presence on Lm is the
           detector's own non-vacuity control);
       (c) Q4's PREMISE side on the Lm graph (k2, P17 §7): zero in-flight OK
           update responses MATCH a pending request
           ([resp_msg_matches_req_msg]), with the bare in-flight OK-update
           count as the control.
     If any of these reddens, a controller gained a plain update path: Q4
     becomes portable and the §2 exclusion note must be revisited. This pin
     also witnesses ONE conjunct of why mutation MS measured INERT, namely
     that the monkey is the only plain-update producer. The other conjunct -
     that its updates merge to no-ops before the stamping site
     (cluster.ml:748-755) - is UNMEASURED here, per t_p16_mutation's MS
     header. Do not read this pin as a full dead-code witness for MS.

   - THE §4.5 RE-MEASURE AT THE LEG: P15's drop/monkey premise content could
     only be probed by supplementary flag-enabled probes (L2x / L3x).
     [check_reconcile_correspondence_under_faults] now takes [?req_drop] /
     [?pod_monkey], so the same two premises are re-measured AT THE LEG; the
     expected counts are DERIVED from P15's committed probe pins (the graphs
     are seed/bound/budget/depth-identical), never re-typed, and the result
     is recorded in [fault_check.mli] next to P15's disclosure.

   - THE SEED-DEFAULT FIREWALL (§4.3): [Scenario.vsts_seed_faults] gained
     [?vct] with default [false]; every committed pin flows through that
     default. Asserted by VALUE (the leg's own {!Fc.faulted_equal}) against
     an explicit [~vct:false] seed, with the [~vct:true] inequality as the
     comparator's non-vacuity control.

   ---- what it does NOT do (anti-duplication, the P15 rationale) ------------

   It does NOT re-run P13/P14/P15's own legs to compare counts (their
   batteries already do) and does NOT re-pin any P16 number ([p16_witness.ml]
   is the single source; this file only READS it for replica-drift guards).
   List lengths are deliberately not pinned (P14's rationale).

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum ([Api_method.api_request]'s nine
   arms, [Message.message_content]'s four, [Message.host_id]'s five, each
   reconciler's step sum - payload wildcards only), no two-arm match on
   [option]/[result] (stdlib [Option.fold] / [Result.fold]), Alcotest as the
   sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vsts_invariants = Anvil_assurance.Vsts_invariants
module Correspondence = Anvil_assurance.Correspondence
module Rc = Anvil_assurance.Reconcile_correspondence
module Rr = Anvil_assurance.Req_resp_correspondence
module Vsr = V_stateful_set_reconciler
module Vdr = V_deployment_reconciler
module Vrr = Vreplica_set_reconciler

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P16_witness.witness_desired
let depth : int = P16_witness.witness_depth
let bound : Bound.t = P16_witness.p16_bound ~desireds:[ desired ]

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) -------- *)

let decisive (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let is_clean (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

let states_of (r : Fc.fault_report) : int =
  match r.outcome with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let gate_of (r : Fc.fault_report) : int = Option.value r.gate_states ~default:(-1)

let violated_name (r : Fc.fault_report) : string =
  Option.fold r.violated ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ==== 1. P13's, P12's, P14's AND P15's committed pins, re-pinned here ====== *)

(* The literals as committed at [aadf678] (P13), [8a2a1ff] (P12), [f56b4cf]
   (P14) and [2c07fd1] (P15), held against the witness modules the prior
   phases' tests actually read, so "fix the red by editing the pin" reddens
   HERE. If any of these moves, a P16 list leaked into a shared suite (or a
   seed/bound drifted): STOP and find the leak - re-pinning is the one
   forbidden repair. (This is the one sanctioned duplication of pinned
   numbers - the duplication IS the firewall, the P14/P15 precedent.) *)

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
let committed_p15_l0_states : int = 76
let committed_p15_l0_gate_states : int = 64
let committed_p15_l1_states : int = 464
let committed_p15_l1_gate_states : int = 304
let committed_p15_l1_gate_states_all : int = 368
let committed_p15_l1_crash_witness_states : int = 388
let committed_p15_l1_fault_free_states : int = 76
let committed_p15_l2_max_drops_seen : int = 0
let committed_p15_l3_max_monkeys_seen : int = 0
let committed_p15_l2x_states : int = 744
let committed_p15_l2x_gate_states_all : int = 688
let committed_p15_l2x_max_drops_seen : int = 1
let committed_p15_l2x_control_states : int = 152
let committed_p15_l3x_states : int = 1976
let committed_p15_l3x_gate_states_all : int = 1680
let committed_p15_l3x_max_monkeys_seen : int = 1
let committed_p15_l3x_control_states : int = 152

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

let test_p15_pins_are_the_committed_literals () =
  Alcotest.(check int)
    "P15 L0 states: 76 (committed at 2c07fd1)" committed_p15_l0_states
    P15_witness.l0_states;
  Alcotest.(check int)
    "P15 L0 gate_states: 64 (committed at 2c07fd1)"
    committed_p15_l0_gate_states P15_witness.l0_gate_states;
  Alcotest.(check int)
    "P15 L1 states: 464 (committed at 2c07fd1)" committed_p15_l1_states
    P15_witness.l1_states;
  Alcotest.(check int)
    "P15 L1 gate_states: 304 (committed at 2c07fd1)"
    committed_p15_l1_gate_states P15_witness.l1_gate_states;
  Alcotest.(check int)
    "P15 L1 all-states gate: 368 (committed at 2c07fd1)"
    committed_p15_l1_gate_states_all P15_witness.l1_gate_states_all;
  Alcotest.(check int)
    "P15 L1 crash_witness_states: 388 (committed at 2c07fd1)"
    committed_p15_l1_crash_witness_states P15_witness.l1_crash_witness_states;
  Alcotest.(check int)
    "P15 L1 fault_free_states: 76 (committed at 2c07fd1)"
    committed_p15_l1_fault_free_states P15_witness.l1_fault_free_states;
  Alcotest.(check int)
    "P15 L2 vacuity-by-construction: max_drops_seen 0 (committed at 2c07fd1)"
    committed_p15_l2_max_drops_seen P15_witness.l2_max_drops_seen;
  Alcotest.(check int)
    "P15 L3 vacuity-by-construction: max_monkeys_seen 0 (committed at 2c07fd1)"
    committed_p15_l3_max_monkeys_seen P15_witness.l3_max_monkeys_seen;
  Alcotest.(check int)
    "P15 L2x probe states: 744 (committed at 2c07fd1; Ld derives from it)"
    committed_p15_l2x_states P15_witness.l2x_states;
  Alcotest.(check int)
    "P15 L2x all-states gate: 688 (committed at 2c07fd1)"
    committed_p15_l2x_gate_states_all P15_witness.l2x_gate_states_all;
  Alcotest.(check int)
    "P15 L2x max_drops_seen: 1 (committed at 2c07fd1)"
    committed_p15_l2x_max_drops_seen P15_witness.l2x_max_drops_seen;
  Alcotest.(check int)
    "P15 L2x control states: 152 (committed at 2c07fd1)"
    committed_p15_l2x_control_states P15_witness.l2x_control_states;
  Alcotest.(check int)
    "P15 L3x probe states: 1976 (committed at 2c07fd1; Lm derives from it)"
    committed_p15_l3x_states P15_witness.l3x_states;
  Alcotest.(check int)
    "P15 L3x all-states gate: 1680 (committed at 2c07fd1)"
    committed_p15_l3x_gate_states_all P15_witness.l3x_gate_states_all;
  Alcotest.(check int)
    "P15 L3x max_monkeys_seen: 1 (committed at 2c07fd1)"
    committed_p15_l3x_max_monkeys_seen P15_witness.l3x_max_monkeys_seen;
  Alcotest.(check int)
    "P15 L3x control states: 152 (committed at 2c07fd1)"
    committed_p15_l3x_control_states P15_witness.l3x_control_states

(* ==== 2. the two P16 lists are classified OUT of every shipped suite ======= *)

(* The four upstream spec-fn names, verbatim from the durable checkout at
   [~/Documents/anvil-ref]: Q1 req_resp.rs:14, Q2 :69, Q3 :136, Q5 :345.
   Written out here rather than projected from the lists so a rename on ONE
   side is caught. *)
let rv_upstream_names : string list =
  [
    "object_in_ok_get_response_has_smaller_rv_than_etcd";
    "object_in_ok_get_resp_is_same_as_etcd_with_same_rv";
  ]

let matched_upstream_names : string list =
  [
    "key_of_object_in_matched_ok_get_resp_message_is_same_as_key_of_pending_req";
    "key_of_object_in_matched_ok_create_resp_message_is_same_as_key_of_pending_req";
  ]

(* Instantiated exactly as the G6 leg instantiates them (fault_check.ml,
   [check_req_resp_under_faults]): Q2's bound-key closure takes the leg's own
   bound. *)
let rv_family : Invariants.invariant list = Rr.rv_family bound
let matched_family : Invariants.invariant list = Rr.matched_family ~controller_id

let names_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.name) invs

(* (name, source) pairs - the k3-strengthened identity for the two
   disjointness guards below (P17 §7): the NAME-string proxy missed a leaked
   member re-shipped under a different OCaml name (it keeps its upstream
   [source] citation), and a shipped member reusing one of these NAMES with
   a different source would still poison [violated] attribution - so a hit
   on EITHER component is reported. *)
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

(* Every list a PRIOR phase's leg consumes, instantiated exactly as those legs
   instantiate them - the five suites P15's firewall guarded PLUS
   {!Reconcile_correspondence.family} itself, shipped at [2c07fd1] and
   instantiated as the P15 leg does (fault_check.ml,
   [check_reconcile_correspondence_under_faults]). *)
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
    ( "Reconcile_correspondence.family (P15)",
      Rc.family ~controller_id ~pending_states:Fc.vsts_pending_states
        ~none_states:Fc.vsts_none_states );
  ]

let test_families_are_the_upstream_names () =
  Alcotest.(check (list string))
    "rv_family is Q1; Q2 in upstream order" rv_upstream_names
    (names_of rv_family);
  Alcotest.(check (list string))
    "matched_family is Q3; Q5 in upstream order" matched_upstream_names
    (names_of matched_family)

(* THE §4.4 MASKING-TRAP GUARD. A P16 member found in ANY shipped suite means
   the committed pins above are no longer measuring what they claim (pin
   reason), and a unioned leg could report an earlier-firing member of the
   other family instead of MD's intended Q5 (masking reason). *)
let test_families_are_disjoint_from_shipped_suites () =
  let leaked =
    List.concat_map
      (fun ((suite, invs) : string * Invariants.invariant list) ->
        pair_leaks suite
          (pairs_of rv_family @ pairs_of matched_family)
          (pairs_of invs))
      shipped_suites
  in
  Alcotest.(check (list string))
    "no P16 req-resp member leaked into a shipped suite" [] leaked

(* The TWO-LIST half of the discipline: the split by guard home is the thesis
   under test, so the lists must not share a member either. *)
let test_the_two_lists_are_disjoint_from_each_other () =
  let shared =
    pair_leaks "matched_family" (pairs_of rv_family) (pairs_of matched_family)
  in
  Alcotest.(check (list string))
    "rv_family and matched_family share no member (name or source)" [] shared

(* And the reverse direction: no P14/P15 member leaked INTO either P16 list -
   the union that would arm the masking trap on P16's own legs. The nine
   upstream names re-typed from t_p14_regression.ml / t_p15_regression.ml. *)
let p14_p15_upstream_names : string list =
  [
    "every_in_flight_msg_has_lower_id_than_allocator";
    "every_pending_req_msg_has_lower_id_than_allocator";
    "every_in_flight_req_msg_has_different_id_from_pending_req_msg_of_every_ongoing_reconcile";
    "every_in_flight_req_msg_from_controller_has_valid_controller_id";
    "every_in_flight_msg_has_no_replicas_and_has_unique_id";
    "pending_req_of_key_is_unique_with_unique_id";
    "pending_req_in_flight_or_resp_in_flight_at_reconcile_state";
    "pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg";
    "no_pending_req_msg_at_reconcile_state";
  ]

let test_no_prior_member_in_the_p16_lists () =
  let p16_names = names_of rv_family @ names_of matched_family in
  let leaked =
    List.filter_map
      (fun (n : string) ->
        Option.map
          (fun (hit : string) -> "a P16 list contains " ^ hit)
          (List.find_opt (String.equal n) p16_names))
      p14_p15_upstream_names
  in
  Alcotest.(check (list string))
    "no P14/P15 member unioned into a P16 list" [] leaked

(* ==== 3. THE Q4 STRUCTURAL-VACUITY PIN ===================================== *)

(* -- request classification (exhaustive over the nine-arm sum, no wildcard) - *)

let verb_of (r : Api_method.api_request) : string =
  match r with
  | Api_method.Get_request _ -> "get"
  | Api_method.List_request _ -> "list"
  | Api_method.Create_request _ -> "create"
  | Api_method.Delete_request _ -> "delete"
  | Api_method.Update_request _ -> "update"
  | Api_method.Update_status_request _ -> "update_status"
  | Api_method.Get_then_delete_request _ -> "get_then_delete"
  | Api_method.Get_then_update_request _ -> "get_then_update"
  | Api_method.Get_then_update_status_request _ -> "get_then_update_status"

let is_plain_update (r : Api_method.api_request) : bool =
  match r with
  | Api_method.Update_request _ -> true
  | Api_method.Get_request _ | Api_method.List_request _
  | Api_method.Create_request _ | Api_method.Delete_request _
  | Api_method.Update_status_request _ | Api_method.Get_then_delete_request _
  | Api_method.Get_then_update_request _
  | Api_method.Get_then_update_status_request _ ->
    false

let has_verb (reqs : Api_method.api_request list) (v : string) : bool =
  List.exists (fun (r : Api_method.api_request) -> String.equal (verb_of r) v) reqs

(* -- (a) the reconcile_core drive ------------------------------------------
   Each reconciler is driven over EVERY step constructor (the literal lists
   below; the [*_step_known] exhaustive matches make a new constructor a
   compile error in this file, forcing the list to be revisited) crossed with
   a payload menu and a response menu covering all nine response arms in Ok
   and Error flavors. This is a SUPERSET of the reachable step space and a
   MENU over payload content: honest coverage, not a proof - part (b) below
   complements it with the actually-reachable request sets. *)

let collect_requests (states : 'st list)
    (menu : Io.void Io.response_view option list)
    (core : 'st -> Io.void Io.response_view option -> Io.void Io.request_view option) :
    Api_method.api_request list =
  List.concat_map
    (fun (st : 'st) ->
      List.concat_map
        (fun (resp : Io.void Io.response_view option) ->
          Option.fold (core st resp) ~none:[]
            ~some:(fun (rv : Io.void Io.request_view) ->
              match rv with
              | Io.K_request r -> [ r ]
              | Io.External_request _ -> .))
        menu)
    states

(* The shared response menu: every response constructor, Ok with each menu
   object (or list variant), plus representative Error bodies. *)
let response_menu (objs : Dynamic_object.t list)
    (lists : Dynamic_object.t list list) : Io.void Io.response_view option list =
  (None
  :: List.concat_map
       (fun (o : Dynamic_object.t) ->
         [
           Some (Io.K_response (Api_method.Get_response { res = Ok o }));
           Some (Io.K_response (Api_method.Create_response { res = Ok o }));
           Some (Io.K_response (Api_method.Update_response { res = Ok o }));
           Some (Io.K_response (Api_method.Update_status_response { res = Ok o }));
           Some (Io.K_response (Api_method.Get_then_update_response { res = Ok o }));
           Some
             (Io.K_response
                (Api_method.Get_then_update_status_response { res = Ok o }));
         ])
       objs)
  @ List.map
      (fun (l : Dynamic_object.t list) ->
        Some (Io.K_response (Api_method.List_response { res = Ok l })))
      lists
  @ [
      Some
        (Io.K_response
           (Api_method.Get_response { res = Error Api_method.Object_not_found }));
      Some (Io.K_response (Api_method.Get_response { res = Error Api_method.Timeout }));
      Some (Io.K_response (Api_method.List_response { res = Error Api_method.Timeout }));
      Some
        (Io.K_response
           (Api_method.Create_response
              { res = Error Api_method.Object_already_exists }));
      Some
        (Io.K_response (Api_method.Create_response { res = Error Api_method.Timeout }));
      Some (Io.K_response (Api_method.Delete_response { res = Ok () }));
      Some
        (Io.K_response (Api_method.Delete_response { res = Error Api_method.Timeout }));
      Some (Io.K_response (Api_method.Get_then_delete_response { res = Ok () }));
      Some
        (Io.K_response
           (Api_method.Get_then_delete_response { res = Error Api_method.Timeout }));
      Some
        (Io.K_response
           (Api_method.Get_then_update_response { res = Error Api_method.Timeout }));
      Some
        (Io.K_response
           (Api_method.Get_then_update_status_response
              { res = Error Api_method.Timeout }));
      Some
        (Io.K_response (Api_method.Update_response { res = Error Api_method.Timeout }));
      Some
        (Io.K_response
           (Api_method.Update_status_response { res = Error Api_method.Timeout }));
    ]

(* ---- VStatefulSet ---- *)

let vsts_steps : Vsr.step list =
  [
    Vsr.Init; Vsr.After_list_pod; Vsr.Get_pvc; Vsr.After_get_pvc; Vsr.Create_pvc;
    Vsr.After_create_pvc; Vsr.Skip_pvc; Vsr.Create_needed; Vsr.After_create_needed;
    Vsr.Update_needed; Vsr.After_update_needed; Vsr.Delete_condemned;
    Vsr.After_delete_condemned; Vsr.Delete_outdated; Vsr.After_delete_outdated;
    Vsr.Done; Vsr.Error;
  ]

(* Exhaustive coverage witness: adding an 18th step constructor breaks THIS
   match, forcing {!vsts_steps} to be revisited. *)
let vsts_step_known (st : Vsr.step) : bool =
  match st with
  | Vsr.Init | Vsr.After_list_pod | Vsr.Get_pvc | Vsr.After_get_pvc
  | Vsr.Create_pvc | Vsr.After_create_pvc | Vsr.Skip_pvc | Vsr.Create_needed
  | Vsr.After_create_needed | Vsr.Update_needed | Vsr.After_update_needed
  | Vsr.Delete_condemned | Vsr.After_delete_condemned | Vsr.Delete_outdated
  | Vsr.After_delete_outdated | Vsr.Done | Vsr.Error ->
    true

let vsts_states (cr : V_stateful_set.t) : Vsr.s list =
  let p0 = Vsr.make_pod cr 0 in
  let p1 = Vsr.make_pod cr 1 in
  let pvc_menu : Persistent_volume_claim.t list list =
    [ []; Vsr.make_pvcs cr 1 ]
  in
  List.concat_map
    (fun (step : Vsr.step) ->
      List.concat_map
        (fun (needed : Pod.t option list) ->
          List.concat_map
            (fun (needed_index : int) ->
              List.concat_map
                (fun (condemned : Pod.t list) ->
                  List.concat_map
                    (fun (pvcs : Persistent_volume_claim.t list) ->
                      List.map
                        (fun (pvc_index : int) ->
                          {
                            Vsr.reconcile_step = step;
                            needed;
                            needed_index;
                            condemned;
                            condemned_index = 0;
                            pvcs;
                            pvc_index;
                          })
                        [ 0; 1 ])
                    pvc_menu)
                [ []; [ p1 ] ])
            [ 0; 1 ])
        [ []; [ Some p0 ]; [ None ]; [ Some p0; None ] ])
    vsts_steps

let vsts_requests : Api_method.api_request list =
  let vsts1 = Scenario.vsts ~desired:1 () in
  let vsts0 = Scenario.vsts ~desired:0 () in
  let vsts1v = Scenario.vsts ~desired:1 ~vct:true () in
  let pod_obj = Pod.marshal (Vsr.make_pod vsts1 0) in
  let pod_obj1 = Pod.marshal (Vsr.make_pod vsts1 1) in
  let pvc_objs =
    List.map Persistent_volume_claim.marshal (Vsr.make_pvcs vsts1v 1)
  in
  let menu =
    response_menu (pod_obj :: pvc_objs) [ []; [ pod_obj ]; [ pod_obj; pod_obj1 ] ]
  in
  List.concat_map
    (fun (cr : V_stateful_set.t) ->
      collect_requests (vsts_states cr) menu (fun st resp ->
          snd (Vsr.reconcile_core ~cr ~resp ~state:st)))
    [ vsts1; vsts0; vsts1v ]

(* ---- VDeployment (self-contained CR construction, the
   t_v_deployment_reconciler.ml shapes) ---- *)

let vd_labels : string Smap.t = Smap.add "app" "x" Smap.empty
let vd_selector : Label_selector.t = { match_labels = Some vd_labels }

let vd_template : Pod_template_spec.t =
  {
    metadata = Some (Object_meta.with_labels vd_labels (Object_meta.default ()));
    spec = Some (Pod_spec.default ());
  }

let vd_owner_ref : Owner_reference.t =
  {
    block_owner_deletion = Some true;
    controller = Some true;
    kind = V_deployment.kind;
    name = "vd1";
    uid = Common.Uid.of_int 1;
  }

let vd_metadata : Object_meta.t =
  {
    (Object_meta.default ()) with
    name = Some "vd1";
    namespace = Some "ns";
    uid = Some (Common.Uid.of_int 1);
    resource_version = Some (Common.Resource_version.of_int 0);
  }

let vd_cr (des : int) : V_deployment.t =
  V_deployment.make ~metadata:vd_metadata
    ~spec:
      {
        (V_deployment.vd_spec_default ()) with
        replicas = Some des;
        selector = vd_selector;
        template = vd_template;
      }
    ~status:()

let vd_owned_vrs ~(name : string) ~(uid : int) ~(replicas : int option)
    ~(status : Vreplica_set.vrs_status option) : Vreplica_set.t =
  Vreplica_set.make
    ~metadata:
      {
        (Object_meta.default ()) with
        name = Some name;
        namespace = Some "ns";
        uid = Some (Common.Uid.of_int uid);
        owner_references = Some [ vd_owner_ref ];
      }
    ~spec:{ Vreplica_set.replicas; selector = vd_selector; template = Some vd_template }
    ~status

let vd_ready_vrs ~(name : string) ~(uid : int) ~(replicas : int) : Vreplica_set.t =
  vd_owned_vrs ~name ~uid ~replicas:(Some replicas)
    ~status:(Some { Vreplica_set.replicas })

let vd_steps : Vdr.step list =
  [
    Vdr.Init; Vdr.After_list_vrs; Vdr.After_create_new_vrs;
    Vdr.After_scale_new_vrs; Vdr.After_ensure_new_vrs;
    Vdr.After_scale_down_old_vrs; Vdr.Done; Vdr.Error;
  ]

let vd_step_known (st : Vdr.step) : bool =
  match st with
  | Vdr.Init | Vdr.After_list_vrs | Vdr.After_create_new_vrs
  | Vdr.After_scale_new_vrs | Vdr.After_ensure_new_vrs
  | Vdr.After_scale_down_old_vrs | Vdr.Done | Vdr.Error ->
    true

let vd_states : Vdr.s list =
  let ready_low = vd_ready_vrs ~name:"vrs-a" ~uid:2 ~replicas:1 in
  let old_b = vd_owned_vrs ~name:"vrs-b" ~uid:3 ~replicas:(Some 1) ~status:None in
  List.concat_map
    (fun (step : Vdr.step) ->
      List.concat_map
        (fun (new_vrs : Vreplica_set.t option) ->
          List.concat_map
            (fun (old_vrs_list : Vreplica_set.t list) ->
              List.map
                (fun (old_vrs_index : int) ->
                  { Vdr.reconcile_step = step; new_vrs; old_vrs_list; old_vrs_index })
                [ 0; 1 ])
            [ []; [ old_b ]; [ ready_low; old_b ] ])
        [ None; Some ready_low; Some old_b ])
    vd_steps

let vd_requests : Api_method.api_request list =
  let ready_low = vd_ready_vrs ~name:"vrs-a" ~uid:2 ~replicas:1 in
  let old_b = vd_owned_vrs ~name:"vrs-b" ~uid:3 ~replicas:(Some 1) ~status:None in
  let vrs_obj = Vreplica_set.marshal ready_low in
  let vrs_obj_b = Vreplica_set.marshal old_b in
  let menu = response_menu [ vrs_obj ] [ []; [ vrs_obj ]; [ vrs_obj; vrs_obj_b ] ] in
  List.concat_map
    (fun (cr : V_deployment.t) ->
      collect_requests vd_states menu (fun st resp ->
          snd (Vdr.reconcile_core ~cr ~resp ~state:st)))
    [ vd_cr 1; vd_cr 2 ]

(* ---- VReplicaSet ---- *)

let vrs_steps : Vrr.step list =
  [
    Vrr.Init; Vrr.After_list_pods; Vrr.After_create_pod 0; Vrr.After_create_pod 1;
    Vrr.After_delete_pod 0; Vrr.After_delete_pod 1; Vrr.After_update_vrs_status;
    Vrr.Done; Vrr.Error;
  ]

let vrs_step_known (st : Vrr.step) : bool =
  match st with
  | Vrr.Init | Vrr.After_list_pods | Vrr.After_create_pod _
  | Vrr.After_delete_pod _ | Vrr.After_update_vrs_status | Vrr.Done | Vrr.Error ->
    true

let vrs_requests : Api_method.api_request list =
  let cr1 = Scenario.vrs ~desired:1 in
  let cr0 = Scenario.vrs ~desired:0 in
  let pods : Pod.t list = Option.to_list (Vrr.make_pod cr1) in
  let pod_objs = List.map Pod.marshal pods in
  let filtered_menu : Pod.t list option list =
    [ None; Some [] ] @ List.map (fun (p : Pod.t) -> Some [ p ]) pods
  in
  let states =
    List.concat_map
      (fun (step : Vrr.step) ->
        List.map
          (fun (filtered_pods : Pod.t list option) ->
            { Vrr.reconcile_step = step; filtered_pods })
          filtered_menu)
      vrs_steps
  in
  let menu = response_menu pod_objs [ []; pod_objs ] in
  List.concat_map
    (fun (cr : Vreplica_set.t) ->
      collect_requests states menu (fun st resp ->
          snd (Vrr.reconcile_core ~cr ~resp ~state:st)))
    [ cr1; cr0 ]

let test_q4_drive_vsts () =
  Alcotest.(check bool)
    "step list covers the whole sum" true
    (List.for_all vsts_step_known vsts_steps);
  Alcotest.(check (list string))
    "VSTS reconcile_core emits NO plain update anywhere on the drive" []
    (List.map verb_of (List.filter is_plain_update vsts_requests));
  Alcotest.(check bool)
    "drive non-vacuous: list emitted" true (has_verb vsts_requests "list");
  Alcotest.(check bool)
    "drive non-vacuous: create emitted" true (has_verb vsts_requests "create");
  Alcotest.(check bool)
    "drive non-vacuous: get emitted (the vct PVC arm)" true
    (has_verb vsts_requests "get");
  Alcotest.(check bool)
    "drive reaches the update-flavored branch: get_then_update emitted \
     (v_stateful_set_reconciler.ml:697 - the branch a plain update would \
     come from)"
    true
    (has_verb vsts_requests "get_then_update")

let test_q4_drive_vd () =
  Alcotest.(check bool)
    "step list covers the whole sum" true (List.for_all vd_step_known vd_steps);
  Alcotest.(check (list string))
    "VDeployment reconcile_core emits NO plain update anywhere on the drive" []
    (List.map verb_of (List.filter is_plain_update vd_requests));
  Alcotest.(check bool)
    "drive non-vacuous: list emitted" true (has_verb vd_requests "list");
  Alcotest.(check bool)
    "drive non-vacuous: create emitted" true (has_verb vd_requests "create");
  Alcotest.(check bool)
    "drive reaches the update-flavored branch: get_then_update emitted \
     (v_deployment_reconciler.ml:335/:376)"
    true
    (has_verb vd_requests "get_then_update")

let test_q4_drive_vrs () =
  Alcotest.(check bool)
    "step list covers the whole sum" true
    (List.for_all vrs_step_known vrs_steps);
  Alcotest.(check (list string))
    "VReplicaSet reconcile_core emits NO plain update anywhere on the drive" []
    (List.map verb_of (List.filter is_plain_update vrs_requests));
  Alcotest.(check bool)
    "drive non-vacuous: list emitted" true (has_verb vrs_requests "list");
  Alcotest.(check bool)
    "drive reaches the update-flavored branch: get_then_update_status \
     emitted (vreplica_set_reconciler.ml:179)"
    true
    (has_verb vrs_requests "get_then_update_status")

(* -- (b) the reachable request sets ----------------------------------------
   Local replicas of three P16 leg graphs (the t_p16_req_resp pattern: same
   seed / bound / budget / depth through {!Fc.faulted_successors}; states_seen
   asserted against the P16 witness FIRST, the replica-drift guard). Lc and
   Ldv must hold NO in-flight plain update AT ALL; on Lm every in-flight
   plain update must come from the pod monkey ([Update_pod] is the model's
   one sanctioned producer - its presence there is the detector's own
   non-vacuity control, proving the zero counts are not a blind predicate). *)

let seed ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool) :
    Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ~vct ()

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed ~req_drop ~pod_monkey ~vct) ]

let lc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false ~vct:false P16_witness.lc_budget)

let lm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:true ~vct:false P16_witness.lm_budget)

let ldv_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:true ~pod_monkey:false ~vct:true P16_witness.ld_budget)

let in_flight_count (reach : Fc.faulted Mc.reachable)
    ~(pred : Message.t -> bool) : int =
  Mc.fold_states reach ~init:0 ~f:(fun (acc : int) (f : Fc.faulted) ->
      acc
      + List.length
          (List.filter pred (Message.Pool.distinct (Cluster.in_flight f.cs))))

let msg_is_plain_update (m : Message.t) : bool =
  match m.content with
  | Message.Api_request r -> is_plain_update r
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    false

let msg_from_monkey (m : Message.t) : bool =
  Message.equal_host_id m.src Message.Pod_monkey

let msg_is_controller_request (m : Message.t) : bool =
  (match m.src with
  | Message.Controller _ -> true
  | Message.Api_server | Message.Builtin_controller | Message.External _
  | Message.Pod_monkey ->
    false)
  &&
  match m.content with
  | Message.Api_request _ -> true
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    false

(* -- (c) Q4's PREMISE side, counted on the Lm graph (k2, P17 §7) ------------
   The request-side pins above are necessary but not premise-shaped: Q4's
   antecedent is an in-flight OK [Update_response] that MATCHES
   ([Message.resp_msg_matches_req_msg]) the pending request of some ongoing
   reconcile. Lm is the one [vct:false] leg graph where plain updates are
   fielded at all (the monkey's [Update_pod]), so the count below measures
   the premise where it has its best chance; the bare in-flight OK-update
   count is the detector's own non-vacuity control. A NONZERO matched count
   REOPENS the §2 Q4 exclusion argument. *)
let msg_is_ok_update_response (m : Message.t) : bool =
  match m.Message.content with
  | Message.Api_response r ->
    (match r with
    | Api_method.Update_response { res } ->
      Result.fold res
        ~ok:(fun (_ : Dynamic_object.t) -> true)
        ~error:(fun (_ : Api_method.api_error) -> false)
    | Api_method.Get_response _ | Api_method.List_response _
    | Api_method.Create_response _ | Api_method.Delete_response _
    | Api_method.Update_status_response _
    | Api_method.Get_then_delete_response _
    | Api_method.Get_then_update_response _
    | Api_method.Get_then_update_status_response _ ->
      false)
  | Message.Api_request _ | Message.External_request _
  | Message.External_response _ ->
    false

let matches_some_pending (cs : Cluster.cluster_state) (m : Message.t) : bool =
  Object_ref_map.fold
    (fun (_ : Common.object_ref) (rs : Controller.ongoing_reconcile)
         (acc : bool) ->
      acc
      || Option.fold ~none:false
           ~some:(fun (req : Message.t) ->
             Message.resp_msg_matches_req_msg m req)
           rs.Controller.pending_req_msg)
    (Cluster.ongoing_reconciles cs controller_id)
    false

let matched_ok_update_count (reach : Fc.faulted Mc.reachable) : int =
  Mc.fold_states reach ~init:0 ~f:(fun (acc : int) (f : Fc.faulted) ->
      acc
      + List.length
          (List.filter
             (fun (m : Message.t) ->
               msg_is_ok_update_response m && matches_some_pending f.cs m)
             (Message.Pool.distinct (Cluster.in_flight f.cs))))

let test_q4_reachable_request_sets () =
  let lc = Lazy.force lc_reach in
  let lm = Lazy.force lm_reach in
  let ldv = Lazy.force ldv_reach in
  Alcotest.(check int)
    "Lc replica states_seen (drift guard FIRST)" P16_witness.lc_states
    (Mc.states_seen lc);
  Alcotest.(check int)
    "Lm replica states_seen (drift guard FIRST)" P16_witness.lm_states
    (Mc.states_seen lm);
  Alcotest.(check int)
    "Ldv replica states_seen (drift guard FIRST)" P16_witness.ldv_states
    (Mc.states_seen ldv);
  Alcotest.(check int)
    "Lc: ZERO in-flight plain updates, any source" 0
    (in_flight_count lc ~pred:msg_is_plain_update);
  Alcotest.(check int)
    "Ldv: ZERO in-flight plain updates, any source" 0
    (in_flight_count ldv ~pred:msg_is_plain_update);
  Alcotest.(check int)
    "Lm: ZERO in-flight plain updates from any NON-monkey source" 0
    (in_flight_count lm ~pred:(fun (m : Message.t) ->
         msg_is_plain_update m && not (msg_from_monkey m)));
  Alcotest.(check bool)
    "detector non-vacuity: the monkey's Update_pod DOES put a plain update \
     in flight on Lm (so the zeros above are measured, not blind)"
    true
    (in_flight_count lm ~pred:(fun (m : Message.t) ->
         msg_is_plain_update m && msg_from_monkey m)
    >= 1);
  Alcotest.(check bool)
    "sweep non-vacuity: controller-sourced requests in flight on Lc" true
    (in_flight_count lc ~pred:msg_is_controller_request >= 1);
  Alcotest.(check bool)
    "sweep non-vacuity: controller-sourced requests in flight on Ldv" true
    (in_flight_count ldv ~pred:msg_is_controller_request >= 1);
  (* (c) the k2 premise-side count (P17 §7). *)
  Alcotest.(check int)
    "Lm: ZERO matched OK update responses (Q4's premise side - a nonzero \
     here REOPENS the §2 exclusion)"
    0 (matched_ok_update_count lm);
  Alcotest.(check bool)
    "premise-count non-vacuity: OK update responses DO reach the in-flight \
     set on Lm (the zero above is measured, not blind)"
    true
    (in_flight_count lm ~pred:msg_is_ok_update_response >= 1)

(* ==== 4. the §4.5 premise re-measure AT THE LEG ============================ *)

(* P15's drop/monkey premises, re-measured through
   [check_reconcile_correspondence_under_faults] itself (the new [?req_drop] /
   [?pod_monkey] threading). Every expected count is DERIVED from the
   committed P15 L2x/L3x probe literals re-pinned in section 1: the leg's
   graph is seed/bound/budget/depth-identical to the corresponding probe
   graph, so what was a supplementary-probe result becomes a LEG result. The
   measured record lives in [fault_check.mli] next to P15's disclosure. *)

let test_p15_drop_premise_at_the_leg () =
  let r =
    Fc.check_reconcile_correspondence_under_faults ~depth ~req_drop:true bound
      P16_witness.ld_budget ~desired ~require_fault:false
  in
  Alcotest.(check string) "violated: none" "<none>" (violated_name r);
  Alcotest.(check bool) "clean" true (is_clean r);
  Alcotest.(check bool) "decisive" true (decisive r);
  Alcotest.(check int)
    "drop edge REALLY taken at the leg (max_drops_seen)"
    committed_p15_l2x_max_drops_seen r.max_drops_seen;
  Alcotest.(check int)
    "states = the committed L2x probe graph" committed_p15_l2x_states
    (states_of r);
  Alcotest.(check int)
    "all-states gate = the committed L2x gate" committed_p15_l2x_gate_states_all
    (gate_of r);
  Alcotest.(check int)
    "fault-free slice = the committed L2x control graph"
    committed_p15_l2x_control_states r.fault_free_states;
  Alcotest.(check int) "no crash edge at this budget" 0 r.crash_witness_states

let test_p15_monkey_premise_at_the_leg () =
  let r =
    Fc.check_reconcile_correspondence_under_faults ~depth ~pod_monkey:true bound
      P16_witness.lm_budget ~desired ~require_fault:false
  in
  Alcotest.(check string) "violated: none" "<none>" (violated_name r);
  Alcotest.(check bool) "clean" true (is_clean r);
  Alcotest.(check bool) "decisive" true (decisive r);
  Alcotest.(check int)
    "monkey edge REALLY taken at the leg (max_monkeys_seen)"
    committed_p15_l3x_max_monkeys_seen r.max_monkeys_seen;
  Alcotest.(check int)
    "states = the committed L3x probe graph" committed_p15_l3x_states
    (states_of r);
  Alcotest.(check int)
    "all-states gate = the committed L3x gate" committed_p15_l3x_gate_states_all
    (gate_of r);
  Alcotest.(check int)
    "fault-free slice = the committed L3x control graph"
    committed_p15_l3x_control_states r.fault_free_states;
  Alcotest.(check int) "no crash edge at this budget" 0 r.crash_witness_states

(* ==== 5. the seed-default firewall (§4.3) ================================== *)

(* [vsts_seed_faults] with [?vct] DEFAULTED must be value-identical to the
   explicit [~vct:false] call at every shipped flag combination - the default
   is what every committed pin flows through. Compared with the legs' own
   {!Fc.faulted_equal} (via {!Fc.faulted_of_seed}, counters all zero on both
   sides), and the [~vct:true] INEQUALITY is the comparator's non-vacuity
   control: a comparator that cannot distinguish the two scenarios would
   pass the identity vacuously. *)

let test_vsts_seed_faults_default_is_vct_false () =
  let combos : (bool * bool * bool) list =
    [ (true, false, false); (true, true, false); (true, false, true); (true, true, true) ]
  in
  Alcotest.(check bool)
    "default ?vct seed = explicit ~vct:false seed at every flag combo" true
    (List.for_all
       (fun ((crash, req_drop, pod_monkey) : bool * bool * bool) ->
         Fc.faulted_equal
           (Fc.faulted_of_seed
              (Scenario.vsts_seed_faults ~desired ~crash ~req_drop ~pod_monkey ()))
           (Fc.faulted_of_seed
              (Scenario.vsts_seed_faults ~desired ~crash ~req_drop ~pod_monkey
                 ~vct:false ())))
       combos);
  Alcotest.(check bool)
    "comparator non-vacuity: the ~vct:true seed DIFFERS" false
    (Fc.faulted_equal
       (Fc.faulted_of_seed
          (Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
             ~pod_monkey:false ()))
       (Fc.faulted_of_seed
          (Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
             ~pod_monkey:false ~vct:true ())))

let () =
  Alcotest.run "p16_regression"
    [
      ( "prior_phase_firewall",
        [
          Alcotest.test_case "P13/P12 witness constants are the committed pins"
            `Quick test_p13_p12_pins_are_the_committed_literals;
          Alcotest.test_case "P14 witness constants are the committed pins"
            `Quick test_p14_pins_are_the_committed_literals;
          Alcotest.test_case "P15 witness constants are the committed pins"
            `Quick test_p15_pins_are_the_committed_literals;
        ] );
      ( "family_classification",
        [
          Alcotest.test_case "the two lists = the four upstream names in order"
            `Quick test_families_are_the_upstream_names;
          Alcotest.test_case
            "lists disjoint from every shipped invariant suite (the §4.4 \
             masking-trap guard)"
            `Quick test_families_are_disjoint_from_shipped_suites;
          Alcotest.test_case "the two lists are disjoint from each other"
            `Quick test_the_two_lists_are_disjoint_from_each_other;
          Alcotest.test_case "no P14/P15 member unioned into a P16 list" `Quick
            test_no_prior_member_in_the_p16_lists;
        ] );
      ( "q4_structural_vacuity",
        [
          Alcotest.test_case
            "VSTS reconcile_core drive: no plain update (THE Q4 PIN)" `Quick
            test_q4_drive_vsts;
          Alcotest.test_case "VDeployment reconcile_core drive: no plain update"
            `Quick test_q4_drive_vd;
          Alcotest.test_case "VReplicaSet reconcile_core drive: no plain update"
            `Quick test_q4_drive_vrs;
          Alcotest.test_case
            "reachable request sets: only the monkey ever fields a plain update"
            `Quick test_q4_reachable_request_sets;
        ] );
      ( "p15_premise_releg",
        [
          Alcotest.test_case
            "drop premise re-measured AT the P15 leg (= the committed L2x graph)"
            `Quick test_p15_drop_premise_at_the_leg;
          Alcotest.test_case
            "monkey premise re-measured AT the P15 leg (= the committed L3x \
             graph)"
            `Quick test_p15_monkey_premise_at_the_leg;
        ] );
      ( "seed_default_firewall",
        [
          Alcotest.test_case
            "vsts_seed_faults default ?vct is value-identical to ~vct:false"
            `Quick test_vsts_seed_faults_default_is_vct_false;
        ] );
    ]

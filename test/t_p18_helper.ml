(* BUILD-SPEC-P18 section 4 - the helper-family matrix: the five legs
   (L0 / Lc / Ld / Lm at [vct:false], L0v at [vct:true]) of
   {!Anvil_checker.Fault_check.check_helper_invariants_under_faults}, the
   family asserted ALONE, their gates, per-member [interesting] counts, and
   the EDGE-TAKEN assertions.

   WHAT THIS EXE ESTABLISHES.

   1. THE FIRST DEDICATED MEASUREMENT of the two portable always-members of
      [vstatefulset_controller/proof/helper_invariants.rs] (H1 pods :52, H2
      PVCs :1063) - the P14-P16 DISJOINT-family pattern: neither member
      appears in ANY shipped suite (t_p18_regression pins the
      (name, source) disjointness), so these legs are the members' first
      assertion site of any kind, not an unmasking of a union.

   2. THE PHASE HEADLINE (spec section 4 prediction 4): upstream proves H1
      ONLY under [vsts_rely_conditions_pod_monkey] (helper_invariants.rs:82,
      rely_guarantee.rs:17-29) - the port's monkey is rely-UNCONSTRAINED
      but candidate-RESTRICTED (it re-sends the STORED pods byte-identically,
      pod_monkey.ml:57-100, cluster.ml:748-755). Whether the member survives
      the Lm leg is MEASURED here, not statically argued: create on a live
      key is rejected [Object_already_exists], the update merge preserves
      dt/uid/rv and re-takes the same owner_references/finalizers
      (api_server.ml:449-462), delete removes a no-finalizer pod outright,
      and delete+recreate mints a fresh uid which [eq_without_uid] ignores.

      CORRECTED READING (P20, BUILD-SPEC-P20 section 6 D5 - prose only, no
      number below moved). P18 left this headline readable as "the monkey
      stayed inside the rely, so H1 held", i.e. a rely-CONSISTENCY result.
      P20 MEASURED that reading false. On this exact Lm graph (the same 1976
      states), P20's rely family is RED: [vsts_rely_conditions_pod_monkey]
      (rely_guarantee.rs:17) is violated at 416 of its 832 premise-firing
      states, and BOTH arms are red at 208 of 208 each
      (vsts_rely_create_req :57, vsts_rely_update_req :76) - because the
      candidate restriction re-sends STORED vsts pods, which carry the vsts
      controller owner ref that rely_guarantee.rs:68-69 / :82-83 / :85
      forbid a monkey request to carry. So the rely boundary has been
      crossed on this leg since P13. H1's clean verdict here is therefore
      EMERGENT ROBUSTNESS - H1 holds even though the assumption its upstream
      proof rests on is FALSE at these states - and NOT evidence that the
      port's monkey respects the rely. Pins: p20_witness.ml r3_red_lm 416,
      r1_red_lm / r2_red_lm 208, h1_red_lm 0; asserted by t_p20_rely.

   3. HONEST VACUITY (H2, the P14 N5 discipline): no [vct:false] graph ever
      mints a PVC, so H2's per-member count 0 IS the result on L0/Lc/Ld/Lm,
      asserted per leg; H2's strictly-positive non-vacuity floor lives on
      the ONE [vct:true] leg (L0v), the reason [?vct] returned to the leg
      signature at all (G7's k6-class omission, undone).

   4. THE UNION GATE IS LOAD-BEARING AGAIN (G7's saturation disclosure's
      "future family whose union does not saturate", realised): H1's
      [interesting] is 0 at the seed (the store holds only the CR) and H2's
      is 0 on every [vct:false] state, so the gate fires on a PROPER subset
      of every graph and the union conjunct carries red-capability.

   TEST-ORDERING RULE (P12 finding 1, P13-P17 precedent): every test
   asserts the SEMANTIC facts FIRST - outcome clean, [violated = None],
   decisive, EDGE-TAKEN where the claim needs one, replica faithfulness -
   and only THEN the brittle exact counts.

   Every pinned number comes from {!P18_witness} (single source of truth);
   none is re-typed here. Graph-identity constants (states, slices, maxima)
   are read from the witness chain (P18 <- P17/P16 <- P15/P13), never
   re-typed.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum (both [Mc.outcome] arms), no
   two-arm match on [option]/[result] (stdlib [Option.fold]), Alcotest as
   the sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Hi = Anvil_assurance.Helper_invariants

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P18_witness.witness_desired
let depth : int = P18_witness.witness_depth
let bound : Bound.t = P18_witness.p18_bound ~desireds:[ desired ]

(* The family is CR-PARAMETERIZED (spec section 2, kept like upstream - no
   k5 universal closure): each leg's replica instantiates it with the SAME
   CR the leg itself threads ([Scenario.vsts ~desired ~vct ()], exactly the
   object the seed marshals into the store). *)
let family_f : Invariants.invariant list =
  Hi.helper_family ~cr:(Scenario.vsts ~desired ~vct:false ()) ~controller_id

let family_v : Invariants.invariant list =
  Hi.helper_family ~cr:(Scenario.vsts ~desired ~vct:true ()) ~controller_id

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) ------- *)

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

(* ==== the two members, addressed BY NAME off the family ====================
   A missing name makes [member_interesting] constantly [false], which the
   family-shape test below reddens LOUDLY before any count could quietly
   go 0. *)

let h1_name : string =
  "all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref"

let h2_name : string =
  "all_pvcs_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_or_owner_ref"

let member_interesting (family : Invariants.invariant list) (name : string)
    (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.interesting s)
    family

(* ==== the five leg runs (lazy: no test pays for an unused exploration) ==== *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) ~(require_fault : bool) : Fc.fault_report =
  Fc.check_helper_invariants_under_faults ~depth ~req_drop ~pod_monkey ~vct
    bound budget ~desired ~require_fault

let l0 : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:false P18_witness.zero_budget
       ~require_fault:false)

let lc : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:false P18_witness.lc_budget
       ~require_fault:true)

let ld : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:true ~pod_monkey:false ~vct:false P18_witness.ld_budget
       ~require_fault:true)

let lm : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:true ~vct:false P18_witness.lm_budget
       ~require_fault:true)

let l0v : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false ~vct:true P18_witness.zero_budget
       ~require_fault:false)

(* ==== LOCAL replicas of the legs' product graphs ===========================
   The per-member counts and the recomputed union gates need the reachable
   set itself, which [fault_report] does not carry. Same seed / bound /
   budget / depth through the exported {!Fc.faulted_successors}; every
   consuming test asserts [Mc.states_seen] against the leg's [states] FIRST
   (the P13 M3/M5 precedent - a drifted replica would silently measure a
   different graph). *)

let seed ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool) :
    Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ~vct ()

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed ~req_drop ~pod_monkey ~vct) ]

let l0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:false ~vct:false
       P18_witness.zero_budget)

let lc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:false ~vct:false
       P18_witness.lc_budget)

let ld_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:true ~pod_monkey:false ~vct:false
       P18_witness.ld_budget)

let lm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:true ~vct:false
       P18_witness.lm_budget)

let l0v_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (reach_of ~req_drop:false ~pod_monkey:false ~vct:true
       P18_witness.zero_budget)

(* ---- slices of a product graph ------------------------------------------- *)

let all_states (_ : Fc.faulted) : bool = true
let post_crash (f : Fc.faulted) : bool = f.crashes >= 1
let post_drop (f : Fc.faulted) : bool = f.drops >= 1
let post_monkey (f : Fc.faulted) : bool = f.monkeys >= 1

(* [interesting]-fires count for ONE member over a slice, against the
   family instance the leg itself threads. *)
let fires (family : Invariants.invariant list)
    (reach : Fc.faulted Mc.reachable) ~(slice : Fc.faulted -> bool)
    (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f && member_interesting family name f.cs)

(* The union gate the leg computes, recomputed locally over the slice the
   leg's [require_fault] selects (its budget's own dimension). *)
let union_gate (family : Invariants.invariant list)
    (reach : Fc.faulted Mc.reachable) ~(slice : Fc.faulted -> bool) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f
      && List.exists
           (fun (i : Invariants.invariant) -> i.Invariants.interesting f.cs)
           family)

(* ---- shared assertion bundles -------------------------------------------- *)

let check_leg_semantics (label : string) (r : Fc.fault_report) : unit =
  Alcotest.(check bool) (label ^ ": outcome clean") true (is_clean r);
  Alcotest.(check string)
    (label ^ ": violated = None")
    "<none>" (violated_name r);
  Alcotest.(check bool) (label ^ ": decisive") true (decisive r)

let check_replica_faithful (label : string)
    (reach : Fc.faulted Mc.reachable) (r : Fc.fault_report) : unit =
  Alcotest.(check int)
    (label ^ ": replica explored the leg's exact graph (states_seen)")
    (states_of r) (Mc.states_seen reach)

(* ==== family shape ========================================================= *)

let test_family_shape () =
  Alcotest.(check (list string))
    "helper_family = the two upstream helper_invariants.rs names, in order"
    [ h1_name; h2_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family_f);
  Alcotest.(check (list string))
    "helper_family at vct:true = the same two names (the CR's vct shape \
     moves no member)"
    [ h1_name; h2_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family_v)

(* ==== L0: zero-budget control, vct:false ================================== *)

let test_l0 () =
  let r = Lazy.force l0 in
  let reach = Lazy.force l0_reach in
  check_leg_semantics "L0" r;
  Alcotest.(check int) "L0: max_crashes_seen = 0" 0 r.max_crashes_seen;
  Alcotest.(check int) "L0: max_drops_seen = 0" 0 r.max_drops_seen;
  Alcotest.(check int) "L0: max_monkeys_seen = 0" 0 r.max_monkeys_seen;
  check_replica_faithful "L0" reach r;
  (* SEMANTIC non-vacuity first: H1 fires somewhere; H2's 0 is the honest-
     vacuity RESULT (N5), pinned below, never a silent absence. *)
  Alcotest.(check bool) "L0: H1 interesting fires (> 0)" true
    (fires family_f reach ~slice:all_states h1_name > 0);
  (* H1 does NOT fire at the seed (the store holds only the CR), so its
     count - and therefore the union gate - is a PROPER subset of the
     states: the gate is load-bearing again, unlike G7's saturated one. *)
  Alcotest.(check bool) "L0: H1 count < states (premise off at the seed)" true
    (fires family_f reach ~slice:all_states h1_name < states_of r);
  Alcotest.(check bool) "L0: gate < states (union gate NON-saturating)" true
    (gate_of r < states_of r);
  Alcotest.(check int) "L0: recomputed all-states union gate = gate_states"
    (gate_of r)
    (union_gate family_f reach ~slice:all_states);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L0: states (= P13 G1 fault-free slice, derived)"
    P18_witness.l0_states (states_of r);
  Alcotest.(check int) "L0: gate_states (pinned)" P18_witness.l0_gate_states
    (gate_of r);
  Alcotest.(check int) "L0: crash_witness_states = 0" 0 r.crash_witness_states;
  Alcotest.(check int) "L0: fault_free_states = states"
    P18_witness.l0_states r.fault_free_states;
  Alcotest.(check int) "L0: max_uid_seen (graph identity with P16 L0)"
    P16_witness.l0_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "L0: max_rv_seen (graph identity with P16 L0)"
    P16_witness.l0_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "L0: H1 interesting count (pinned)"
    P18_witness.h1_interesting_l0
    (fires family_f reach ~slice:all_states h1_name);
  Alcotest.(check int) "L0: H2 interesting count (pinned honest vacuity, N5)"
    P18_witness.h2_interesting_l0
    (fires family_f reach ~slice:all_states h2_name)

(* ==== Lc: crash-only {1;0;0}, vct:false =================================== *)

let test_lc () =
  let r = Lazy.force lc in
  let reach = Lazy.force lc_reach in
  check_leg_semantics "Lc" r;
  (* EDGE-TAKEN first: the clean verdict is judged across a REAL crash. *)
  Alcotest.(check bool) "Lc: max_crashes_seen >= 1 (crash edge REALLY taken)"
    true
    (r.max_crashes_seen >= 1);
  Alcotest.(check int) "Lc: max_drops_seen = 0" 0 r.max_drops_seen;
  Alcotest.(check int) "Lc: max_monkeys_seen = 0" 0 r.max_monkeys_seen;
  check_replica_faithful "Lc" reach r;
  (* Crash moves no store-side truth: clean with a nonzero post-crash gate. *)
  Alcotest.(check bool) "Lc: post-crash gate > 0" true (gate_of r > 0);
  Alcotest.(check int) "Lc: recomputed post-crash union gate = gate_states"
    (gate_of r)
    (union_gate family_f reach ~slice:post_crash);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Lc: states (= P13 G1 graph, derived)"
    P18_witness.lc_states (states_of r);
  Alcotest.(check int) "Lc: gate_states (pinned, post-crash union)"
    P18_witness.lc_gate_states (gate_of r);
  Alcotest.(check int) "Lc: crash_witness_states (derived)"
    P18_witness.lc_crash_witness_states r.crash_witness_states;
  Alcotest.(check int) "Lc: fault_free_states (derived)"
    P18_witness.lc_fault_free_states r.fault_free_states;
  Alcotest.(check int) "Lc: max_uid_seen (graph identity with P16 Lc)"
    P16_witness.lc_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Lc: max_rv_seen (graph identity with P16 Lc)"
    P16_witness.lc_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "Lc: H1 interesting count (pinned)"
    P18_witness.h1_interesting_lc
    (fires family_f reach ~slice:all_states h1_name);
  Alcotest.(check int) "Lc: H1 post-crash count (pinned)"
    P18_witness.h1_interesting_lc_post_crash
    (fires family_f reach ~slice:post_crash h1_name);
  Alcotest.(check int) "Lc: H2 interesting count (pinned honest vacuity, N5)"
    P18_witness.h2_interesting_lc
    (fires family_f reach ~slice:all_states h2_name);
  Alcotest.(check int) "Lc: H2 post-crash count (pinned honest vacuity)"
    P18_witness.h2_interesting_lc_post_crash
    (fires family_f reach ~slice:post_crash h2_name)

(* ==== Ld: drop-only {0;1;0} - content-insensitive ========================= *)

let test_ld () =
  let r = Lazy.force ld in
  let reach = Lazy.force ld_reach in
  check_leg_semantics "Ld" r;
  (* EDGE-TAKEN first. *)
  Alcotest.(check bool) "Ld: max_drops_seen >= 1 (drop edge REALLY taken)"
    true
    (r.max_drops_seen >= 1);
  Alcotest.(check int) "Ld: max_crashes_seen = 0" 0 r.max_crashes_seen;
  Alcotest.(check int) "Ld: max_monkeys_seen = 0" 0 r.max_monkeys_seen;
  Alcotest.(check int) "Ld: crash_witness_states = 0" 0 r.crash_witness_states;
  check_replica_faithful "Ld" reach r;
  Alcotest.(check bool) "Ld: post-drop gate > 0" true (gate_of r > 0);
  Alcotest.(check int) "Ld: recomputed post-drop union gate = gate_states"
    (gate_of r)
    (union_gate family_f reach ~slice:post_drop);
  (* The drop edge never touches the store, so the maxima are L0's exact
     values - asserted against L0's committed constants (the P17-review
     hardening), then pinned against Ld's own. *)
  Alcotest.(check int) "Ld: max_uid_seen = L0's (store content untouched)"
    P16_witness.l0_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Ld: max_rv_seen = L0's (store content untouched)"
    P16_witness.l0_max_rv_seen r.max_rv_seen;
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Ld: states (= P15 L2x graph, derived)"
    P18_witness.ld_states (states_of r);
  Alcotest.(check int) "Ld: gate_states (pinned, post-drop union)"
    P18_witness.ld_gate_states (gate_of r);
  Alcotest.(check int) "Ld: fault_free_states (derived)"
    P18_witness.ld_fault_free_states r.fault_free_states;
  Alcotest.(check int) "Ld: max_uid_seen (graph identity with P16 Ld)"
    P16_witness.ld_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Ld: max_rv_seen (graph identity with P16 Ld)"
    P16_witness.ld_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "Ld: H1 interesting count (pinned)"
    P18_witness.h1_interesting_ld
    (fires family_f reach ~slice:all_states h1_name);
  Alcotest.(check int) "Ld: H1 post-drop count (pinned)"
    P18_witness.h1_interesting_ld_post_drop
    (fires family_f reach ~slice:post_drop h1_name);
  Alcotest.(check int) "Ld: H2 interesting count (pinned honest vacuity, N5)"
    P18_witness.h2_interesting_ld
    (fires family_f reach ~slice:all_states h2_name);
  Alcotest.(check int) "Ld: H2 post-drop count (pinned honest vacuity)"
    P18_witness.h2_interesting_ld_post_drop
    (fires family_f reach ~slice:post_drop h2_name)

(* ==== Lm: monkey-only {0;0;1} - THE RELY-GAP PROBE (prediction 4) =========
   P20 correction (spec section 6 D5): "rely-gap" here names the gap between
   upstream's ASSUMPTION and the port's monkey MODEL, not a gap the monkey
   declines to cross. P20 measured the crossing (rely family RED on this
   graph); see the corrected reading at the top of this file. *)

let test_lm () =
  let r = Lazy.force lm in
  let reach = Lazy.force lm_reach in
  (* THE HEADLINE: clean here means the rely-UNCONSTRAINED (but candidate-
     RESTRICTED) monkey cannot violate H1 - measured, not argued.
     P20-CORRECTED READING (spec section 6 D5): clean here does NOT mean the
     monkey stayed inside the rely. P20 measured the rely REFUTED on this very
     graph (r3_red_lm 416, r1_red_lm / r2_red_lm 208, p20_witness.ml), so this
     green is EMERGENT ROBUSTNESS - H1 survives an environment outside the
     region upstream's proof assumes - not rely-compliance. *)
  check_leg_semantics "Lm" r;
  (* EDGE-TAKEN first. *)
  Alcotest.(check bool) "Lm: max_monkeys_seen >= 1 (monkey edge REALLY taken)"
    true
    (r.max_monkeys_seen >= 1);
  Alcotest.(check int) "Lm: max_crashes_seen = 0" 0 r.max_crashes_seen;
  Alcotest.(check int) "Lm: max_drops_seen = 0" 0 r.max_drops_seen;
  Alcotest.(check int) "Lm: crash_witness_states = 0" 0 r.crash_witness_states;
  check_replica_faithful "Lm" reach r;
  Alcotest.(check bool) "Lm: post-monkey gate > 0" true (gate_of r > 0);
  Alcotest.(check int) "Lm: recomputed post-monkey union gate = gate_states"
    (gate_of r)
    (union_gate family_f reach ~slice:post_monkey);
  (* Prediction 5, mechanism half: the maxima RISE above L0's via monkey-
     DELETE + reconciler re-create (NEVER "create on a live key lands" -
     BUILD-SPEC-P17.md:226's literal reading is false; such a create is
     rejected Object_already_exists). *)
  Alcotest.(check bool) "Lm: max_uid_seen > L0's (delete + re-create landed)"
    true
    (r.max_uid_seen > P16_witness.l0_max_uid_seen);
  Alcotest.(check bool) "Lm: max_rv_seen > L0's (monkey write landed)" true
    (r.max_rv_seen > P16_witness.l0_max_rv_seen);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Lm: states (= P15 L3x graph, derived)"
    P18_witness.lm_states (states_of r);
  Alcotest.(check int) "Lm: gate_states (pinned, post-monkey union)"
    P18_witness.lm_gate_states (gate_of r);
  Alcotest.(check int) "Lm: fault_free_states (derived)"
    P18_witness.lm_fault_free_states r.fault_free_states;
  (* Prediction 5, number half: max_uid_seen = 4 (graph identity with P16
     Lm - the monkey's delete frees the key, the reconciler re-creates). *)
  Alcotest.(check int) "Lm: max_uid_seen (graph identity with P16 Lm)"
    P16_witness.lm_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Lm: max_rv_seen (graph identity with P16 Lm)"
    P16_witness.lm_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "Lm: H1 interesting count (pinned, amplified)"
    P18_witness.h1_interesting_lm
    (fires family_f reach ~slice:all_states h1_name);
  Alcotest.(check int) "Lm: H1 post-monkey count (pinned)"
    P18_witness.h1_interesting_lm_post_monkey
    (fires family_f reach ~slice:post_monkey h1_name);
  Alcotest.(check int) "Lm: H2 interesting count (pinned honest vacuity, N5)"
    P18_witness.h2_interesting_lm
    (fires family_f reach ~slice:all_states h2_name);
  Alcotest.(check int) "Lm: H2 post-monkey count (pinned honest vacuity)"
    P18_witness.h2_interesting_lm_post_monkey
    (fires family_f reach ~slice:post_monkey h2_name)

(* ==== L0v: zero-budget at vct:TRUE - H2's non-vacuity floor =============== *)

let test_l0v () =
  let r = Lazy.force l0v in
  let reach = Lazy.force l0v_reach in
  check_leg_semantics "L0v" r;
  Alcotest.(check int) "L0v: max_crashes_seen = 0" 0 r.max_crashes_seen;
  Alcotest.(check int) "L0v: max_drops_seen = 0" 0 r.max_drops_seen;
  Alcotest.(check int) "L0v: max_monkeys_seen = 0" 0 r.max_monkeys_seen;
  check_replica_faithful "L0v" reach r;
  (* SEMANTIC non-vacuity first - THE FLOOR (spec section 4 prediction 3):
     H2 really fires on this graph; the four vct:false legs' 0s are honest
     vacuity, this leg is what de-vacuizes the member. *)
  Alcotest.(check bool) "L0v: H2 interesting fires (> 0) - THE FLOOR" true
    (fires family_v reach ~slice:all_states h2_name > 0);
  Alcotest.(check bool) "L0v: H1 interesting fires (> 0)" true
    (fires family_v reach ~slice:all_states h1_name > 0);
  Alcotest.(check bool) "L0v: gate < states (union gate NON-saturating)" true
    (gate_of r < states_of r);
  Alcotest.(check int) "L0v: recomputed all-states union gate = gate_states"
    (gate_of r)
    (union_gate family_v reach ~slice:all_states);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L0v: states (= P16 L0v graph, derived)"
    P18_witness.l0v_states (states_of r);
  Alcotest.(check int) "L0v: gate_states (pinned)"
    P18_witness.l0v_gate_states (gate_of r);
  Alcotest.(check int) "L0v: crash_witness_states = 0" 0
    r.crash_witness_states;
  Alcotest.(check int) "L0v: fault_free_states = states"
    P18_witness.l0v_states r.fault_free_states;
  Alcotest.(check int) "L0v: max_uid_seen (graph identity with P16 L0v)"
    P18_witness.l0v_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "L0v: max_rv_seen (graph identity with P16 L0v)"
    P18_witness.l0v_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "L0v: H1 interesting count (pinned)"
    P18_witness.h1_interesting_l0v
    (fires family_v reach ~slice:all_states h1_name);
  Alcotest.(check int) "L0v: H2 interesting count (pinned - the floor)"
    P18_witness.h2_interesting_l0v
    (fires family_v reach ~slice:all_states h2_name)

let () =
  Alcotest.run "p18_helper"
    [
      ( "family_shape",
        [
          Alcotest.test_case "helper_family = the two upstream names" `Quick
            test_family_shape;
        ] );
      ( "legs",
        [
          Alcotest.test_case "L0: zero-budget control" `Quick test_l0;
          Alcotest.test_case "Lc: crash-only" `Quick test_lc;
          Alcotest.test_case "Ld: drop-only (content-insensitive)" `Quick
            test_ld;
          Alcotest.test_case
            "Lm: monkey-only (THE RELY-GAP PROBE; P20 reading: emergent \
             robustness, the rely is RED here)" `Quick test_lm;
          Alcotest.test_case "L0v: vct:true (H2's non-vacuity floor)" `Quick
            test_l0v;
        ] );
    ]

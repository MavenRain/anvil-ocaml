(* BUILD-SPEC-P17 section 4 - the store-side matrix: the four G7 legs
   (L0 / Lc / Ld / Lm) of
   {!Anvil_checker.Fault_check.check_objects_in_store_under_faults}, the
   family asserted ALONE, their gates, per-member [interesting] counts, and
   the EDGE-TAKEN assertions. All at the [vct:false] default (k6-class
   deliberate scope cut, disclosed in [fault_check.mli]).

   WHAT THIS EXE ESTABLISHES.

   1. THE FIRST UNMASKED STORE-SIDE MEASUREMENT (the narrowed novelty claim,
      sweep-cited in [objects_in_store.mli]): S1/S2/S3 have been asserted
      under fault budgets since P13, but only inside the UNION of the full
      [always]/VSTS suites; these legs assert the three ALONE with
      per-member counts under a measured fault gate.

   2. THE FAULT-DIMENSION TRIPTYCH CLOSES (spec section 1): P14/P15
      attributed crash sensitivity to reconcile-side guards, P16 measured
      the drop dimension on message-side guards. The store family's guards
      live SERVER-SIDE in the api_server write handlers, and the measured
      signature is the predicted mirror image: crash-insensitive (Lc clean,
      saturated post-crash gate - an honest negative), drop-insensitive for
      CONTENT (Ld clean, store maxima = L0's exact 3/2) though NOT for
      premise DENSITY (the honest-negative below), and monkey-amplified
      (Lm: S1/S3 density 82.2% vs L0's 68.4%, [max_uid_seen] =
      [max_rv_seen] = 4 on this graph alone at [vct:false]) - the first
      family whose LEVERAGE edge is the monkey.

   3. HONEST NEGATIVE (spec section 4's "Ld premise counts ~ L0's"
      prediction REFUTED under the density reading, recorded per the
      honest-negative discipline): S1/S3 fire at 376/744 = 50.5% on Ld vs
      52/76 = 68.4% on L0 - the fabricated Error response stalls the
      reconciler's create on the dropped branch and DILUTES the
      >= 2-objects slice. The mechanism half of the prediction (drop never
      touches store content) is what the maxima cross-check measures.

   4. S3's count MEASURES EQUAL to S1's on every graph (52/296/376/1624):
      the first pod create is the reconciler's and carries the controller
      ref, so the two premise slices coincide ON THESE GRAPHS. Asserted as
      a per-leg measurement (an observed coincidence of this scenario,
      never a law).

   TEST-ORDERING RULE (P12 finding 1, P13-P16 precedent): every test
   asserts the SEMANTIC facts FIRST - outcome clean, [violated = None],
   decisive, EDGE-TAKEN where the claim needs one, replica faithfulness -
   and only THEN the brittle exact counts.

   Every pinned number comes from {!P17_witness} (single source of truth);
   none is re-typed here. Graph-identity constants (states, slices, maxima)
   are read from the witness chain (P17 <- P16 <- P15/P13), never re-typed.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum (both [Mc.outcome] arms), no
   two-arm match on [option]/[result] (stdlib [Option.fold]), Alcotest as
   the sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Ois = Anvil_assurance.Objects_in_store

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P17_witness.witness_desired
let depth : int = P17_witness.witness_depth
let bound : Bound.t = P17_witness.p17_bound ~desireds:[ desired ]
let family : Invariants.invariant list = Ois.store_family ~controller_id

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

(* ==== the three members, addressed BY NAME off the family ==================
   The family is a FILTER over [Invariants.cluster_structural] (never a
   copy), so members are selected by their upstream names; a missing name
   makes [member_interesting] constantly [false], which the family-shape
   test below reddens LOUDLY before any count could quietly go 0. *)

let s1_name : string = "etcd_objects_have_unique_uids"
let s2_name : string = "each_object_in_etcd_is_weakly_well_formed"

let s3_name : string =
  "each_object_in_etcd_has_at_most_one_controller_owner"

let member_interesting (name : string) (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.interesting s)
    family

(* ==== the four leg runs (lazy: no test pays for an unused exploration) ==== *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget)
    ~(require_fault : bool) : Fc.fault_report =
  Fc.check_objects_in_store_under_faults ~depth ~req_drop ~pod_monkey bound
    budget ~desired ~require_fault

let l0 : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false P17_witness.zero_budget
       ~require_fault:false)

let lc : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false P17_witness.lc_budget
       ~require_fault:true)

let ld : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:true ~pod_monkey:false P17_witness.ld_budget
       ~require_fault:true)

let lm : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:true P17_witness.lm_budget
       ~require_fault:true)

(* ==== LOCAL replicas of the legs' product graphs ===========================
   The per-member counts and the recomputed union gates need the reachable
   set itself, which [fault_report] does not carry. Same seed / bound /
   budget / depth through the exported {!Fc.faulted_successors}; every
   consuming test asserts [Mc.states_seen] against the leg's [states] FIRST
   (the P13 M3/M5 precedent - a drifted replica would silently measure a
   different graph). *)

let seed ~(req_drop : bool) ~(pod_monkey : bool) : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ()

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget) :
    Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed ~req_drop ~pod_monkey) ]

let l0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false P17_witness.zero_budget)

let lc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false P17_witness.lc_budget)

let ld_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:true ~pod_monkey:false P17_witness.ld_budget)

let lm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:true P17_witness.lm_budget)

(* ---- slices of a product graph ------------------------------------------- *)

let all_states (_ : Fc.faulted) : bool = true
let post_crash (f : Fc.faulted) : bool = f.crashes >= 1
let post_drop (f : Fc.faulted) : bool = f.drops >= 1
let post_monkey (f : Fc.faulted) : bool = f.monkeys >= 1

(* [interesting]-fires count for ONE member over a slice. *)
let fires (reach : Fc.faulted Mc.reachable) ~(slice : Fc.faulted -> bool)
    (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      slice f && member_interesting name f.cs)

(* The union gate the leg computes, recomputed locally over the slice the
   leg's [require_fault] selects (its budget's own dimension). *)
let union_gate (reach : Fc.faulted Mc.reachable)
    ~(slice : Fc.faulted -> bool) : int =
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
    "store_family = the three upstream objects_in_store.rs names, in order"
    [ s1_name; s2_name; s3_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family)

(* ==== L0: zero-budget control ============================================= *)

let test_l0 () =
  let r = Lazy.force l0 in
  let reach = Lazy.force l0_reach in
  check_leg_semantics "L0" r;
  Alcotest.(check int) "L0: max_crashes_seen = 0" 0 r.max_crashes_seen;
  Alcotest.(check int) "L0: max_drops_seen = 0" 0 r.max_drops_seen;
  Alcotest.(check int) "L0: max_monkeys_seen = 0" 0 r.max_monkeys_seen;
  check_replica_faithful "L0" reach r;
  (* SEMANTIC non-vacuity first: every member fires somewhere. *)
  Alcotest.(check bool) "L0: S1 interesting fires (> 0)" true
    (fires reach ~slice:all_states s1_name > 0);
  Alcotest.(check bool) "L0: S2 interesting fires (> 0)" true
    (fires reach ~slice:all_states s2_name > 0);
  Alcotest.(check bool) "L0: S3 interesting fires (> 0)" true
    (fires reach ~slice:all_states s3_name > 0);
  (* S1 does NOT fire at the seed slice: cardinal >= 2 needs the first
     create, so its count is a PROPER subset of the states. *)
  Alcotest.(check bool) "L0: S1 count < states (premise off at the seed)" true
    (fires reach ~slice:all_states s1_name < states_of r);
  Alcotest.(check int) "L0: recomputed all-states union gate = gate_states"
    (gate_of r)
    (union_gate reach ~slice:all_states);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "L0: states (= P13 G1 fault-free slice, derived)"
    P17_witness.l0_states (states_of r);
  Alcotest.(check int) "L0: gate_states (pinned)" P17_witness.l0_gate_states
    (gate_of r);
  Alcotest.(check int) "L0: crash_witness_states = 0" 0 r.crash_witness_states;
  Alcotest.(check int) "L0: fault_free_states = states"
    P17_witness.l0_states r.fault_free_states;
  Alcotest.(check int) "L0: max_uid_seen (graph identity with P16 L0)"
    P16_witness.l0_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "L0: max_rv_seen (graph identity with P16 L0)"
    P16_witness.l0_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "L0: S1 interesting count (pinned)"
    P17_witness.s1_interesting_l0
    (fires reach ~slice:all_states s1_name);
  Alcotest.(check int) "L0: S2 interesting count (pinned)"
    P17_witness.s2_interesting_l0
    (fires reach ~slice:all_states s2_name);
  Alcotest.(check int) "L0: S3 interesting count (pinned)"
    P17_witness.s3_interesting_l0
    (fires reach ~slice:all_states s3_name);
  Alcotest.(check int) "L0: S3 count = S1 count (measured coincidence)"
    (fires reach ~slice:all_states s1_name)
    (fires reach ~slice:all_states s3_name)

(* ==== Lc: crash-only - the P15-A mirror (honest negative) ================= *)

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
  (* PREDICTION (spec section 4) CONFIRMED as a measured NEGATIVE: crash
     moves no store-side truth - clean with a nonzero post-crash gate. *)
  Alcotest.(check bool) "Lc: post-crash gate > 0 (P15-A mirror)" true
    (gate_of r > 0);
  Alcotest.(check int) "Lc: recomputed post-crash union gate = gate_states"
    (gate_of r)
    (union_gate reach ~slice:post_crash);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Lc: states (= P13 G1 graph, derived)"
    P17_witness.lc_states (states_of r);
  Alcotest.(check int) "Lc: gate_states (pinned, post-crash union)"
    P17_witness.lc_gate_states (gate_of r);
  Alcotest.(check int) "Lc: crash_witness_states (derived)"
    P17_witness.lc_crash_witness_states r.crash_witness_states;
  Alcotest.(check int) "Lc: fault_free_states (derived)"
    P17_witness.lc_fault_free_states r.fault_free_states;
  Alcotest.(check int) "Lc: max_uid_seen (graph identity with P16 Lc)"
    P16_witness.lc_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Lc: max_rv_seen (graph identity with P16 Lc)"
    P16_witness.lc_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "Lc: S1 interesting count (pinned)"
    P17_witness.s1_interesting_lc
    (fires reach ~slice:all_states s1_name);
  Alcotest.(check int) "Lc: S2 interesting count (pinned)"
    P17_witness.s2_interesting_lc
    (fires reach ~slice:all_states s2_name);
  Alcotest.(check int) "Lc: S3 interesting count (pinned)"
    P17_witness.s3_interesting_lc
    (fires reach ~slice:all_states s3_name);
  Alcotest.(check int) "Lc: S1 post-crash count (pinned)"
    P17_witness.s1_interesting_lc_post_crash
    (fires reach ~slice:post_crash s1_name);
  Alcotest.(check int) "Lc: S2 post-crash count (pinned)"
    P17_witness.s2_interesting_lc_post_crash
    (fires reach ~slice:post_crash s2_name);
  Alcotest.(check int) "Lc: S3 post-crash count (pinned)"
    P17_witness.s3_interesting_lc_post_crash
    (fires reach ~slice:post_crash s3_name);
  Alcotest.(check int) "Lc: S3 count = S1 count (measured coincidence)"
    (fires reach ~slice:all_states s1_name)
    (fires reach ~slice:all_states s3_name)

(* ==== Ld: drop-only - content-insensitive, density-perturbed ============== *)

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
    (union_gate reach ~slice:post_drop);
  (* The CONTENT half of the spec section 4 prediction, measured: the drop
     edge never touches the store, so the maxima are L0's exact values.
     P17-review hardening: the "= L0's" identity is itself ASSERTED against
     L0's committed constants, not just against the independent Ld literals
     (an Ld-literal drift matching a same-direction L0 drift can no longer
     satisfy the claim silently). *)
  Alcotest.(check int) "Ld: max_uid_seen = L0's (store content untouched)"
    P16_witness.ld_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Ld: max_rv_seen = L0's (store content untouched)"
    P16_witness.ld_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "Ld: the Ld maxima literal IS L0's constant (uid)"
    P16_witness.l0_max_uid_seen P16_witness.ld_max_uid_seen;
  Alcotest.(check int) "Ld: the Ld maxima literal IS L0's constant (rv)"
    P16_witness.l0_max_rv_seen P16_witness.ld_max_rv_seen;
  (* Exact MEASURED pins LAST - including the HONEST-NEGATIVE density pin
     (376/744 = 50.5% vs L0's 68.4%; the "~ L0's" prediction refuted under
     the density reading, see P17_witness). *)
  Alcotest.(check int) "Ld: states (= P15 L2x graph, derived)"
    P17_witness.ld_states (states_of r);
  Alcotest.(check int) "Ld: gate_states (pinned, post-drop union)"
    P17_witness.ld_gate_states (gate_of r);
  Alcotest.(check int) "Ld: fault_free_states (derived)"
    P17_witness.ld_fault_free_states r.fault_free_states;
  Alcotest.(check int) "Ld: S1 interesting count (pinned, the honest negative)"
    P17_witness.s1_interesting_ld
    (fires reach ~slice:all_states s1_name);
  Alcotest.(check int) "Ld: S2 interesting count (pinned)"
    P17_witness.s2_interesting_ld
    (fires reach ~slice:all_states s2_name);
  Alcotest.(check int) "Ld: S3 interesting count (pinned)"
    P17_witness.s3_interesting_ld
    (fires reach ~slice:all_states s3_name);
  Alcotest.(check int) "Ld: S1 post-drop count (pinned)"
    P17_witness.s1_interesting_ld_post_drop
    (fires reach ~slice:post_drop s1_name);
  Alcotest.(check int) "Ld: S2 post-drop count (pinned)"
    P17_witness.s2_interesting_ld_post_drop
    (fires reach ~slice:post_drop s2_name);
  Alcotest.(check int) "Ld: S3 post-drop count (pinned)"
    P17_witness.s3_interesting_ld_post_drop
    (fires reach ~slice:post_drop s3_name);
  Alcotest.(check int) "Ld: S3 count = S1 count (measured coincidence)"
    (fires reach ~slice:all_states s1_name)
    (fires reach ~slice:all_states s3_name)

(* ==== Lm: monkey-only - THE LEVERAGE EDGE ================================= *)

let test_lm () =
  let r = Lazy.force lm in
  let reach = Lazy.force lm_reach in
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
    (union_gate reach ~slice:post_monkey);
  (* PREDICTION CONFIRMED semantically first: the monkey's injected create
     is a REAL transitive etcd write - the maxima RISE above L0's. *)
  Alcotest.(check bool) "Lm: max_uid_seen > L0's (monkey write landed)" true
    (r.max_uid_seen > P16_witness.l0_max_uid_seen);
  Alcotest.(check bool) "Lm: max_rv_seen > L0's (monkey write landed)" true
    (r.max_rv_seen > P16_witness.l0_max_rv_seen);
  (* Exact MEASURED pins LAST. *)
  Alcotest.(check int) "Lm: states (= P15 L3x graph, derived)"
    P17_witness.lm_states (states_of r);
  Alcotest.(check int) "Lm: gate_states (pinned, post-monkey union)"
    P17_witness.lm_gate_states (gate_of r);
  Alcotest.(check int) "Lm: fault_free_states (derived)"
    P17_witness.lm_fault_free_states r.fault_free_states;
  Alcotest.(check int) "Lm: max_uid_seen (graph identity with P16 Lm)"
    P16_witness.lm_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "Lm: max_rv_seen (graph identity with P16 Lm)"
    P16_witness.lm_max_rv_seen r.max_rv_seen;
  Alcotest.(check int) "Lm: S1 interesting count (pinned, amplified)"
    P17_witness.s1_interesting_lm
    (fires reach ~slice:all_states s1_name);
  Alcotest.(check int) "Lm: S2 interesting count (pinned)"
    P17_witness.s2_interesting_lm
    (fires reach ~slice:all_states s2_name);
  Alcotest.(check int) "Lm: S3 interesting count (pinned)"
    P17_witness.s3_interesting_lm
    (fires reach ~slice:all_states s3_name);
  Alcotest.(check int) "Lm: S1 post-monkey count (pinned)"
    P17_witness.s1_interesting_lm_post_monkey
    (fires reach ~slice:post_monkey s1_name);
  Alcotest.(check int) "Lm: S2 post-monkey count (pinned)"
    P17_witness.s2_interesting_lm_post_monkey
    (fires reach ~slice:post_monkey s2_name);
  Alcotest.(check int) "Lm: S3 post-monkey count (pinned)"
    P17_witness.s3_interesting_lm_post_monkey
    (fires reach ~slice:post_monkey s3_name);
  Alcotest.(check int) "Lm: S3 count = S1 count (measured coincidence)"
    (fires reach ~slice:all_states s1_name)
    (fires reach ~slice:all_states s3_name)

let () =
  Alcotest.run "p17_store"
    [
      ( "family_shape",
        [
          Alcotest.test_case "store_family = the three upstream names" `Quick
            test_family_shape;
        ] );
      ( "legs",
        [
          Alcotest.test_case "L0: zero-budget control" `Quick test_l0;
          Alcotest.test_case "Lc: crash-only (P15-A mirror)" `Quick test_lc;
          Alcotest.test_case "Ld: drop-only (content-insensitive)" `Quick
            test_ld;
          Alcotest.test_case "Lm: monkey-only (the leverage edge)" `Quick
            test_lm;
        ] );
    ]

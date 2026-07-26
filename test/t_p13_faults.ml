(* BUILD-SPEC-P13 section 4.5 - the three fault-leg gates of {!Fault_check}, plus
   the Refuted-branch discriminators and the section-3 soundness pins.

   WHAT THIS EXE ESTABLISHES. Before P13 the fault surface did no load-bearing
   work in any decisive result: every decisive gate in [Cluster_check] seeds
   [~fair:true] (all three adversaries OFF), and the only faults-ON legs
   ([check_always] / [check_always_vsts]) are NON-decisive because the faults-ON
   graph never closes. P12's headline [gate_states = 6952] is therefore a
   FAULT-FREE witness. These tests pin three DECISIVE verdicts in which
   [Step.Restart_controller_step] (Anvil [RestartControllerStep], cluster.rs:377)
   is genuinely taken:

     G1  the FULL shipped VSTS [always] suite holds at 388 post-crash states;
     G2  uniqueness of ongoing reconcile ids holds at 2784 states that are BOTH
         >= 2-concurrent AND post-crash (P12's witness had [crashes = 0] by
         construction, so its crash-tolerance content was exactly zero);
     G3  after the [Disable_*] prefix, all 10 states where the run stops match
         the desired state.

   TEST-ORDERING RULE (BUILD-SPEC-P13 section 4.5, from P12 review finding 1).
   Every test asserts the SEMANTIC facts FIRST (outcome shape, [violated],
   decisiveness, gate > 0) and only THEN the brittle exact counts. Alcotest halts
   at the first failing check, so a mutant that shifts a pinned count must not be
   able to redden the exe BEFORE the load-bearing semantic assertion runs - that
   is exactly how P12 shipped its Refuted path with zero observed-red coverage.

   Every pinned number comes from [P13_witness] (single source of truth); none is
   re-typed here.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches (both [Mc.outcome] arms named; the twelve-arm [Step.t]
   classifier below has no [_ ->] arm), Option.fold / Option.is_some rather than
   two-arm option matches, Alcotest as the sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vsts_invariants = Anvil_assurance.Vsts_invariants

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P13_witness.witness_desired
let desireds : int list = P13_witness.witness_desireds
let depth : int = P13_witness.witness_depth
let budget : Fc.budget = P13_witness.witness_budget
let single_bound : Bound.t = P13_witness.p13_bound ~desireds:[ desired ]
let multi_bound : Bound.t = P13_witness.p13_bound ~desireds
let cr : V_stateful_set.t = Scenario.vsts ~desired ()

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) --------- *)

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

let refuted (o : Fc.faulted Mc.outcome) : bool =
  match o with Mc.Refuted _ -> true | Mc.No_counterexample _ -> false

let inv_name (i : Invariants.invariant option) : string =
  Option.fold i ~none:"<none>" ~some:(fun (x : Invariants.invariant) -> x.name)

(* ---- fault-flag readers (the gate's own [any_fault_live], which is private) - *)

let crash_enabled (s : Cluster.cluster_state) : bool =
  Imap.find_opt controller_id s.Cluster.controller_and_externals
  |> Option.fold ~none:false ~some:(fun (cae : Cluster.controller_and_external) ->
         cae.crash_enabled)

let any_fault_live (s : Cluster.cluster_state) : bool =
  crash_enabled s || s.Cluster.req_drop_enabled || s.Cluster.pod_monkey_enabled

(* ==== the three shipped legs (computed lazily so the instant discriminators
   redden first and never pay for an exploration) ============================= *)

let g1_report : Fc.fault_report Lazy.t =
  lazy (Fc.check_invariants_under_faults ~depth single_bound budget ~desired)

let g3_report : Fc.fault_report Lazy.t =
  lazy (Fc.check_settles_after_disable ~depth single_bound budget ~desired)

let g2_report : Fc.fault_report Lazy.t =
  lazy
    (Fc.check_unique_reconcile_id_under_faults ~depth multi_bound budget ~desireds)

(* ==== section 3: the reachability / soundness argument ====================== *)

(* BUILD-SPEC-P13 section 3, PINNED here rather than only asserted in prose.
   [Cluster.init] (Anvil cluster.rs:110, lib/cluster/cluster.ml:75-97) REQUIRES all
   three fault flags TRUE, so a seed with any flag [false] is not an init state.
   Exploring from such a seed is still SOUND because every flag combination
   componentwise [<= (true, true, true)] is reachable from an init state by a
   PREFIX of [Disable_crash_step] / [Disable_req_drop_step] /
   [Disable_pod_monkey_step] (Anvil cluster.rs:407, :472, :526 =
   lib/cluster/cluster.ml:337, :385, :445), each of which flips ONLY its own flag.
   A safety violation found from such a seed is thus a genuine violation of a
   REACHABLE behaviour, and a clean verdict is falsification-up-to-bounds of the
   SUFFIX behaviours starting there. The pre-existing [~fair:true] seeds already
   rest on exactly this argument (they are the all-disabled suffix).

   [test_disable_prefix_reaches_fair_seed] below turns the prefix half of that
   argument into an EXECUTED check rather than a claim: at the all-faults-ON seed
   each of the three [Disable_*] edges is enabled, and taking all three lands
   EXACTLY on the all-faults-OFF seed (state_equal), so the fault-flag lattice
   really is traversed by disablers alone. *)

type disabler = Dis_crash | Dis_req_drop | Dis_pod_monkey | Not_a_disabler

(* Exhaustive twelve-arm [Step.t] classifier, no [_ ->] arm: a thirteenth Anvil
   step would be a COMPILE error here rather than a silently missed disabler. *)
let disabler_of (step : Step.t) : disabler =
  match step with
  | Step.Disable_crash_step _ -> Dis_crash
  | Step.Disable_req_drop_step -> Dis_req_drop
  | Step.Disable_pod_monkey_step -> Dis_pod_monkey
  | Step.Api_server_step _ | Step.Builtin_controllers_step _
  | Step.Controller_step _ | Step.Schedule_controller_reconcile_step _
  | Step.Restart_controller_step _ | Step.Drop_req_step _ | Step.Pod_monkey_step _
  | Step.External_step _ | Step.Stutter_step ->
      Not_a_disabler

let seed_faults ~(crash : bool) ~(req_drop : bool) ~(pod_monkey : bool) :
    Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash ~req_drop ~pod_monkey

(* The same state with an EMPTY etcd. [Api_server.init] (lib/cluster/api_server.ml:73,
   Anvil state_machine.rs:838) is exactly [resources] empty, so this isolates the
   ONE conjunct of [Cluster.init] that the seeds fail. *)
let with_empty_etcd (s : Cluster.cluster_state) : Cluster.cluster_state =
  let api : Api_server.state = s.Cluster.api_server in
  {
    s with
    Cluster.api_server = { api with Api_server.resources = Object_ref_map.empty };
  }

let take_disabler (which : disabler) (s : Cluster.cluster_state) :
    Cluster.cluster_state option =
  List.find_map
    (fun ((step : Step.t), (s' : Cluster.cluster_state)) ->
      if disabler_of step = which then Some s' else None)
    (Cluster.enabled_successors single_bound cluster s)

(* MEASURED CORRECTION to BUILD-SPEC-P13 section 3's final sentence, which claims
   the all-faults-ON seed "satisfies [Cluster.init] outright". It does NOT, and
   this test pins both halves of the correction so the claim cannot silently drift
   back: every FAULT-FLAG conjunct of [Cluster.init] IS satisfied (that is the
   load-bearing part; an earlier draft also called this the FIRST seed in the repo
   to satisfy it, which is false - [Scenario.vsts_seed ~fair:false] delegates to
   the identical call at [lib/assurance/scenario.ml:380-382] and is live pre-P13
   at [lib/checker/cluster_check.ml:503] - and nothing below pins a primacy claim,
   which is exactly why it could drift), but
   [Cluster.init] itself is FALSE because [Api_server.init] demands an empty etcd
   while the seed already holds the server-created CR. Emptying the etcd - and
   changing nothing else - flips [Cluster.init] to TRUE, which isolates that as the
   only failing conjunct. See [Scenario.vsts_seed_faults]'s .mli. *)
let test_g3_seed_init_conjuncts () =
  let all_on = seed_faults ~crash:true ~req_drop:true ~pod_monkey:true in
  Alcotest.(check bool) "G3 seed: crash flag TRUE (Cluster.init conjunct)" true
    (crash_enabled all_on);
  Alcotest.(check bool) "G3 seed: req_drop_enabled TRUE (Cluster.init conjunct)"
    true all_on.Cluster.req_drop_enabled;
  Alcotest.(check bool) "G3 seed: pod_monkey_enabled TRUE (Cluster.init conjunct)"
    true all_on.Cluster.pod_monkey_enabled;
  Alcotest.(check bool)
    "G3 seed: every fault flag live, so any_fault_live (the G3 quiescent gate is \
     NOT open at the seed)"
    true (any_fault_live all_on);
  (* The MEASURED refutation of the spec's stronger claim. *)
  Alcotest.(check bool)
    "Cluster.init is FALSE at the G3 seed (etcd already holds the created CR)"
    false (Cluster.init cluster all_on);
  (* ... and the isolation: the empty-etcd conjunct is the ONLY failing one. *)
  Alcotest.(check bool)
    "Cluster.init is TRUE at the same state with an empty etcd (Api_server.init \
     is the only failing conjunct)"
    true
    (Cluster.init cluster (with_empty_etcd all_on))

let test_disable_prefix_reaches_fair_seed () =
  let all_on = seed_faults ~crash:true ~req_drop:true ~pod_monkey:true in
  let all_off = seed_faults ~crash:false ~req_drop:false ~pod_monkey:false in
  let step1 = take_disabler Dis_crash all_on in
  let step2 = Option.bind step1 (take_disabler Dis_req_drop) in
  let step3 = Option.bind step2 (take_disabler Dis_pod_monkey) in
  (* SEMANTIC first: each disabler edge really is enabled along the prefix. *)
  Alcotest.(check bool) "Disable_crash_step enabled at the all-faults-ON seed" true
    (Option.is_some step1);
  Alcotest.(check bool) "Disable_req_drop_step enabled after it" true
    (Option.is_some step2);
  Alcotest.(check bool) "Disable_pod_monkey_step enabled after that" true
    (Option.is_some step3);
  (* Each flips ONLY its own flag, so the prefix lands on the all-OFF seed the
     pre-existing [~fair:true] legs explore from. *)
  Alcotest.(check bool)
    "the Disable_* prefix lands EXACTLY on the all-faults-OFF seed (section 3 \
     soundness argument, executed)"
    true
    (Option.fold step3 ~none:false ~some:(fun (s : Cluster.cluster_state) ->
         Cc.state_equal s all_off));
  Alcotest.(check bool) "and no fault flag survives the prefix" false
    (Option.fold step3 ~none:true ~some:any_fault_live)

(* ==== Refuted-branch discriminators, one per gate =========================== *)

(* Why these exist (BUILD-SPEC-P13 section 4.5, P12 review finding 1): on the TRUE
   model all three legs come back clean, so each gate's refutation wiring would
   otherwise ship with ZERO observed-red coverage - a regression collapsing
   [Refuted] into [No_counterexample] (a vacuously clean gate) would pass. Each
   discriminator hand-forges a {!Fc.faulted} that MUST be [Refuted] and runs the
   EXACT check the gate wraps over it, plus the negative control showing the same
   check is clean on the unforged seed. Modelled on
   [t_p12_concurrent.ml:225 test_gate_refutes_forged_collision]. *)

let singleton_reach (f : Fc.faulted) : Fc.faulted Mc.reachable =
  Mc.explore ~depth:1
    ~successors:(fun _ -> [])
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash ~init:[ f ]

(* A POST-CRASH product state ([crashes = 1]): the forged states sit in exactly the
   [crashes >= 1] slice the gates' non-vacuity counts range over. *)
let post_crash (cs : Cluster.cluster_state) : Fc.faulted =
  { Fc.cs; crashes = 1; drops = 0; monkeys = 0 }

(* ---- G1: the full VSTS suite, forged duplicate etcd uid -------------------- *)

let g1_invs : Invariants.invariant list =
  Vsts_invariants.always ~cr ~controller_id

let dup_uid_key : Common.object_ref =
  {
    Common.kind = Common.Custom_resource "VStatefulSet";
    name = "vsts-forged-duplicate";
    namespace = "ns";
  }

(* The G1 seed with its server-created CR ALSO stored under a second key: two etcd
   objects now carry the SAME uid, refuting inv1 [etcd_objects_have_unique_uids].
   The object itself is the real server-stamped one (never forged) - only the extra
   binding is hand-made, which is the whole point of a discriminator. *)
let forged_dup_uid : Cluster.cluster_state =
  let base = seed_faults ~crash:true ~req_drop:false ~pod_monkey:false in
  let api : Api_server.state = base.Cluster.api_server in
  Option.fold
    (Object_ref_map.find_opt Scenario.vsts_ref (Cluster.resources base))
    ~none:base
    ~some:(fun (obj : Dynamic_object.t) ->
      {
        base with
        Cluster.api_server =
          {
            api with
            Api_server.resources =
              Object_ref_map.add dup_uid_key obj api.Api_server.resources;
          };
      })

let test_g1_refutes_forged_duplicate_uid () =
  let inv = Invariants.conjunction g1_invs in
  let forged = post_crash forged_dup_uid in
  (* The forge is REAL (guards against a silently no-op discriminator). *)
  Alcotest.(check bool) "forged state really holds the duplicated etcd binding"
    true
    (Option.is_some
       (Object_ref_map.find_opt dup_uid_key (Cluster.resources forged.cs)));
  (* Negative control: the UNFORGED seed satisfies the same suite, so the check
     below discriminates rather than always refuting. *)
  Alcotest.(check bool) "unforged G1 seed satisfies the whole suite" true
    (inv (seed_faults ~crash:true ~req_drop:false ~pod_monkey:false));
  (* SEMANTIC: G1's exact check (conjunction lifted pointwise to the product)
     REFUTES the forged post-crash state. *)
  Alcotest.(check bool)
    "G1's check_safety over the lifted suite REFUTES the forged duplicate-uid \
     state"
    true
    (refuted
       (Mc.check_safety (singleton_reach forged)
          ~inv:(fun (f : Fc.faulted) -> inv f.cs)
          ~equal:Fc.faulted_equal));
  (* SEMANTIC: G1's [violated] projection ([Invariants.first_violated] at the
     lasso-loop head) actually NAMES an invariant. *)
  Alcotest.(check bool) "G1's violated projection is Some" true
    (Option.is_some (Invariants.first_violated g1_invs forged.cs));
  (* MEASURED pin LAST. *)
  Alcotest.(check string) "violated invariant name (pinned)"
    P13_witness.forged_dup_uid_violated_name
    (inv_name (Invariants.first_violated g1_invs forged.cs))

(* ---- G2: uniqueness of ongoing reconcile ids, forged id collision ---------- *)

(* Hand-built ongoing reconciles, one per [(name, reconcile_id)] under DISTINCT cr
   keys, on top of a real seed so only [ongoing_reconciles] is under test
   ([t_p12_concurrent.ml:86-104]'s [state_with_rids], re-based on the P13
   crash-enabled seed). Total, no raise. *)
let a_cr : Dynamic_object.t =
  V_stateful_set.marshal (Scenario.vsts_named ~name:"vsts1" ~desired:1 ())

let ongoing_key ~(name : string) : Common.object_ref =
  { Common.kind = Common.Custom_resource "VStatefulSet"; name; namespace = "ns" }

let ongoing_rec ~(reconcile_id : int) : Controller.ongoing_reconcile =
  {
    Controller.triggering_cr = a_cr;
    pending_req_msg = None;
    local_state = Value.of_json `Null;
    reconcile_id;
  }

let state_with_rids ~(rids : (string * int) list) : Cluster.cluster_state =
  let ongoing =
    List.fold_left
      (fun (m : Controller.ongoing_reconcile Object_ref_map.t)
           ((name, rid) : string * int) ->
        Object_ref_map.add (ongoing_key ~name) (ongoing_rec ~reconcile_id:rid) m)
      Object_ref_map.empty rids
  in
  let controller =
    { Controller.init with Controller.ongoing_reconciles = ongoing }
  in
  let base =
    Scenario.vsts_seed_multi_faults ~desireds:[ desired ] ~crash:true
      ~req_drop:false ~pod_monkey:false
  in
  {
    base with
    Cluster.controller_and_externals =
      Imap.add controller_id
        { Cluster.controller; external_ = None; crash_enabled = true }
        Imap.empty;
  }

let test_g2_refutes_forged_rid_collision () =
  let inv = Invariants.unique_reconcile_id_invariant ~controller_id in
  let distinct = post_crash (state_with_rids ~rids:[ ("vsts1", 0); ("vsts2", 1) ]) in
  let collided = post_crash (state_with_rids ~rids:[ ("vsts1", 0); ("vsts2", 0) ]) in
  (* The forged states really are in the gate's non-vacuity slice. *)
  Alcotest.(check bool) "forged states are >= 2-concurrent (inv6 interesting)" true
    (inv.interesting distinct.cs && inv.interesting collided.cs);
  (* Negative control: distinct ids are clean under the SAME check. *)
  Alcotest.(check bool) "distinct ids: G2's check is clean (discriminates)" false
    (refuted
       (Mc.check_safety (singleton_reach distinct)
          ~inv:(fun (f : Fc.faulted) -> inv.holds f.cs)
          ~equal:Fc.faulted_equal));
  (* SEMANTIC: G2's exact check REFUTES the forged post-crash collision. *)
  Alcotest.(check bool)
    "G2's check_safety over inv6.holds REFUTES a post-crash duplicate-id state"
    true
    (refuted
       (Mc.check_safety (singleton_reach collided)
          ~inv:(fun (f : Fc.faulted) -> inv.holds f.cs)
          ~equal:Fc.faulted_equal))

(* ---- G3: settling after disable, forged off-goal quiescent state ----------- *)

let g3_goal : Invariants.invariant = Vsts_invariants.liveness_goal ~cr

(* G3's own predicates, mirrored (the gate's [any_fault_live] is private). *)
let g3_quiescent (f : Fc.faulted) : bool =
  Cc.settled single_bound cluster f.Fc.cs && not (any_fault_live f.Fc.cs)

let g3_target (f : Fc.faulted) : bool = g3_goal.holds f.Fc.cs

(* All three adversaries already disabled AND an empty etcd: nothing productive is
   enabled (no cr key to schedule, no message to handle, no pod for the GC or the
   monkey), so the state is [settled] with every fault flag [false] - the
   [quiescent] gate is OPEN - while [current_state_matches] is FALSE because
   conjunct (a) of the goal (the CR is in etcd) fails. Exactly the shape G3 must
   refute: a run that STOPS, off-goal, with the adversaries switched off. *)
let forged_offgoal_quiescent : Fc.faulted =
  post_crash
    (with_empty_etcd (seed_faults ~crash:false ~req_drop:false ~pod_monkey:false))

let test_g3_refutes_forged_offgoal_quiescent () =
  let f = forged_offgoal_quiescent in
  (* The forge is REAL: the quiescent gate is open and the goal genuinely fails. *)
  Alcotest.(check bool) "forged state is settled" true
    (Cc.settled single_bound cluster f.cs);
  Alcotest.(check bool) "forged state has NO fault flag live" false
    (any_fault_live f.cs);
  Alcotest.(check bool) "so G3's quiescent gate is OPEN there" true (g3_quiescent f);
  Alcotest.(check bool) "and G3's target (the ESR goal) FAILS there" false
    (g3_target f);
  (* Negative control: the unforged all-OFF seed still has the CR in etcd, so a
     productive reconcile remains and [quiescent] is CLOSED - the same check is
     clean, i.e. it discriminates instead of always refuting. *)
  let unforged =
    post_crash (seed_faults ~crash:false ~req_drop:false ~pod_monkey:false)
  in
  Alcotest.(check bool) "unforged all-OFF seed is NOT quiescent (CR still to \
                         reconcile)" false (g3_quiescent unforged);
  Alcotest.(check bool) "unforged all-OFF seed: G3's check_reaches is clean" false
    (refuted
       (Mc.check_reaches (singleton_reach unforged) ~target:g3_target
          ~quiescent:g3_quiescent ~equal:Fc.faulted_equal));
  (* SEMANTIC: G3's exact check REFUTES the forged off-goal quiescent state. *)
  Alcotest.(check bool)
    "G3's check_reaches REFUTES a settled, all-faults-disabled, off-goal state"
    true
    (refuted
       (Mc.check_reaches (singleton_reach f) ~target:g3_target
          ~quiescent:g3_quiescent ~equal:Fc.faulted_equal));
  (* MEASURED pin LAST: the invariant G3 names on a refutation. *)
  Alcotest.(check string) "G3's violated invariant name (pinned)"
    P13_witness.g3_violated_name (inv_name (Some g3_goal))

(* ==== the three shipped legs: SEMANTICS first, exact pins last ============== *)

(* Shared by all three leg tests: the fault-dimension semantics that make a clean
   verdict mean something. [crash_witness_states > 0] with [max_crashes_seen >= 1]
   is the non-vacuity core (the crash edge was really taken);
   [fault_free_states > 0] is its CONTRAST partner (the graph straddles the fault
   boundary rather than sitting on one side); the strict [< ceiling] checks are the
   BUILD-SPEC-P8 section 4 / BUILD-SPEC-P11 section 7.3 interpretability condition
   without which a verdict cannot be read at all. *)
let check_fault_semantics (label : string) (r : Fc.fault_report) : unit =
  Alcotest.(check bool) (label ^ ": gate_states positive (leg is NOT vacuous)")
    true (gate_of r > 0);
  Alcotest.(check bool) (label ^ ": outcome clean (no counterexample)") true
    (is_clean r);
  Alcotest.(check bool) (label ^ ": outcome decisive (frontier emptied)") true
    (decisive r);
  Alcotest.(check bool) (label ^ ": violated = None") true
    (Option.is_none r.violated);
  Alcotest.(check bool) (label ^ ": max_crashes_seen >= 1 (a REAL crash occurred)")
    true (r.max_crashes_seen >= 1);
  Alcotest.(check bool) (label ^ ": crash_witness_states positive (post-crash \
                                   slice is non-empty)") true
    (r.crash_witness_states > 0);
  Alcotest.(check bool) (label ^ ": fault_free_states positive (contrast partner)")
    true (r.fault_free_states > 0);
  Alcotest.(check bool)
    (label ^ ": max_uid_seen STRICTLY below uid_ceiling (interpretable)") true
    (r.max_uid_seen < r.bound.uid_ceiling);
  Alcotest.(check bool)
    (label ^ ": max_rv_seen STRICTLY below rv_ceiling (interpretable)") true
    (r.max_rv_seen < r.bound.rv_ceiling);
  Alcotest.(check bool)
    (label ^ ": max_crashes_seen within budget (drop-only pruning is sound)") true
    (r.max_crashes_seen <= r.budget.max_crashes)

(* G1: the experiment of the phase. The FULL shipped VSTS [always] suite
   ([Invariants.cluster_structural] inv1-6 plus the three VSTS invariants) checked
   to a DECISIVE verdict against a real controller crash - something no invariant
   in this suite had ever been checked against before P13. It came back CLEAN, and
   the isolated crash dimension ([budget_crash_only]) is what makes that verdict
   attributable to the crash. *)
let test_g1_suite_survives_crash () =
  let r = Lazy.force g1_report in
  check_fault_semantics "G1" r;
  (* The crash-only budget really is isolated: no other adversary contributed. *)
  Alcotest.(check int) "G1: max_drops_seen = 0 (drops budgeted out)" 0
    r.max_drops_seen;
  Alcotest.(check int) "G1: max_monkeys_seen = 0 (monkey budgeted out)" 0
    r.max_monkeys_seen;
  (* Both disclosed pruning dimensions bit, and are REPORTED rather than hidden:
     the reconcile_ceiling clipped successors, and the second crash edge was
     clipped by the budget. *)
  Alcotest.(check bool) "G1: pruned_by_ceiling (disclosed)" true
    r.pruned_by_ceiling;
  Alcotest.(check bool) "G1: pruned_by_budget (the 2nd crash edge is clipped)" true
    r.pruned_by_budget;
  (* Exact MEASURED pins LAST: a moved count means the product graph or the
     invariants' exercise surface shifted and must be re-justified. *)
  Alcotest.(check int) "G1: states (pinned)" P13_witness.g1_states (states_of r);
  Alcotest.(check int) "G1: gate_states (pinned)" P13_witness.g1_gate_states
    (gate_of r);
  Alcotest.(check int) "G1: crash_witness_states (pinned)"
    P13_witness.g1_crash_witness_states r.crash_witness_states;
  Alcotest.(check int) "G1: fault_free_states (pinned)"
    P13_witness.g1_fault_free_states r.fault_free_states;
  Alcotest.(check int) "G1: settled_with_faults_live (pinned)"
    P13_witness.g1_settled_with_faults_live r.settled_with_faults_live;
  Alcotest.(check int) "G1: max_uid_seen (pinned)" P13_witness.g1_max_uid_seen
    r.max_uid_seen;
  Alcotest.(check int) "G1: max_rv_seen (pinned)" P13_witness.g1_max_rv_seen
    r.max_rv_seen;
  Alcotest.(check int) "G1: max_crashes_seen (pinned)"
    P13_witness.g1_max_crashes_seen r.max_crashes_seen

(* Robustness of the G1 witness: the uid / rv ceilings do NOT bind at the witness
   (max 3 < 6 and 2 < 6), so RAISING them must leave the reachable product graph -
   hence [gate_states] and the maxima - unchanged. The witness is a real
   crash-tolerance phenomenon, not a ceiling artifact.

   SELF-CONTAINED FLOOR (P12 review NIT-3): the first check asserts [gate > 0]
   OUTRIGHT, not merely [gate_raised >= gate_base]. Without it every relative
   comparison below is satisfied by a degenerate always-0 (empty-graph) gate, and
   the whole test would pass vacuously. *)
let test_robustness_raised_ceilings () =
  let r0 = Lazy.force g1_report in
  let raised =
    {
      single_bound with
      Bound.uid_ceiling = single_bound.uid_ceiling + 3;
      rv_ceiling = single_bound.rv_ceiling + 3;
    }
  in
  let r1 = Fc.check_invariants_under_faults ~depth raised budget ~desired in
  Alcotest.(check bool)
    "robustness: base gate is positive (SELF-CONTAINED floor, not a relative \
     comparison)"
    true (gate_of r0 > 0);
  Alcotest.(check bool) "robustness: raised gate is positive too (self-contained)"
    true (gate_of r1 > 0);
  Alcotest.(check bool) "robustness: raised-ceiling leg is still clean" true
    (is_clean r1);
  Alcotest.(check bool) "robustness: raised-ceiling leg is still decisive" true
    (decisive r1);
  Alcotest.(check bool) "robustness: raised gate does not shrink" true
    (gate_of r1 >= gate_of r0);
  Alcotest.(check int)
    "robustness: gate_states IDENTICAL (uid/rv are not the binding ceilings)"
    (gate_of r0) (gate_of r1);
  Alcotest.(check int) "robustness: max_uid_seen unchanged" r0.max_uid_seen
    r1.max_uid_seen;
  Alcotest.(check int) "robustness: max_rv_seen unchanged" r0.max_rv_seen
    r1.max_rv_seen;
  Alcotest.(check int) "robustness: crash_witness_states unchanged"
    r0.crash_witness_states r1.crash_witness_states

(* G3: Anvil's [failures_liveness] shape. All three adversaries live in the seed;
   after the [Disable_*] prefix, every state where the run STOPS must match the
   desired state. The [Disable_*] trio is required rather than a merely quiet
   suffix because [Cluster_check.settled] counts [Step.Pod_monkey_step] as
   PRODUCTIVE, so while the monkey is live and has an enabled op no state is
   [settled] at all.

   [settled_with_faults_live] is the honest CONTRAST (BUILD-SPEC-P13 section 4.3
   asks for it MEASURED, never predicted): states that are [settled] while some
   fault flag is still TRUE, i.e. the part of the settling evidence that does NOT
   depend on the disable prefix. It is nonzero here because
   [Step.Restart_controller_step] / [Step.Drop_req_step] are NOT productive. *)
let test_g3_settles_after_disable () =
  let r = Lazy.force g3_report in
  check_fault_semantics "G3" r;
  Alcotest.(check bool)
    "G3: settled_with_faults_live positive (settling evidence exists off the \
     disable prefix too - MEASURED contrast, not a defect)"
    true (r.settled_with_faults_live > 0);
  Alcotest.(check int) "G3: states (pinned)" P13_witness.g3_states (states_of r);
  Alcotest.(check int) "G3: gate_states = post-disable settled states (pinned)"
    P13_witness.g3_gate_states (gate_of r);
  Alcotest.(check int) "G3: crash_witness_states (pinned)"
    P13_witness.g3_crash_witness_states r.crash_witness_states;
  Alcotest.(check int) "G3: fault_free_states (pinned)"
    P13_witness.g3_fault_free_states r.fault_free_states;
  Alcotest.(check int) "G3: settled_with_faults_live (pinned)"
    P13_witness.g3_settled_with_faults_live r.settled_with_faults_live;
  Alcotest.(check int) "G3: max_uid_seen (pinned)" P13_witness.g3_max_uid_seen
    r.max_uid_seen;
  Alcotest.(check int) "G3: max_rv_seen (pinned)" P13_witness.g3_max_rv_seen
    r.max_rv_seen;
  Alcotest.(check int) "G3: max_crashes_seen (pinned)"
    P13_witness.g3_max_crashes_seen r.max_crashes_seen

(* G2: P12's uniqueness gate strengthened into the crash dimension. Same invariant
   ([every_ongoing_reconcile_has_unique_id], Anvil
   controller_runtime_safety.rs:874) and same [>= 2]-concurrent non-vacuity notion
   as [Cluster_check.check_unique_reconcile_id_vsts], but every gate state is now
   ALSO post-crash - which P12's fault-free witness could not contain by
   construction. The most expensive leg (6.645 s), so it runs last. *)
let test_g2_unique_rid_survives_crash () =
  let r = Lazy.force g2_report in
  check_fault_semantics "G2" r;
  Alcotest.(check bool)
    "G2: gate is a STRICT strengthening of P12 (every gate state is post-crash)"
    true
    (gate_of r > 0 && gate_of r <= r.crash_witness_states);
  Alcotest.(check bool) "G2: pruned_by_ceiling (disclosed reconcile_ceiling clip)"
    true r.pruned_by_ceiling;
  Alcotest.(check bool) "G2: pruned_by_budget (the 2nd crash edge is clipped)" true
    r.pruned_by_budget;
  Alcotest.(check int) "G2: states (pinned)" P13_witness.g2_states (states_of r);
  Alcotest.(check int) "G2: gate_states (pinned)" P13_witness.g2_gate_states
    (gate_of r);
  Alcotest.(check int) "G2: crash_witness_states (pinned)"
    P13_witness.g2_crash_witness_states r.crash_witness_states;
  Alcotest.(check int) "G2: fault_free_states (pinned)"
    P13_witness.g2_fault_free_states r.fault_free_states;
  Alcotest.(check int) "G2: settled_with_faults_live (pinned)"
    P13_witness.g2_settled_with_faults_live r.settled_with_faults_live;
  Alcotest.(check int) "G2: max_uid_seen (pinned)" P13_witness.g2_max_uid_seen
    r.max_uid_seen;
  Alcotest.(check int) "G2: max_rv_seen (pinned)" P13_witness.g2_max_rv_seen
    r.max_rv_seen;
  Alcotest.(check int) "G2: max_crashes_seen (pinned)"
    P13_witness.g2_max_crashes_seen r.max_crashes_seen

(* Cheap tests first, then G1 (0.317 s), robustness (a second G1 run), G3
   (2.145 s) and G2 (6.645 s) last: the whole exe is ~10 s wall, well inside the
   150 s harness alarm. *)
let () =
  Alcotest.run "p13_faults"
    [
      ( "section3_soundness",
        [
          Alcotest.test_case
            "G3 seed satisfies every fault-flag conjunct of Cluster.init (and \
             ONLY the empty-etcd conjunct fails)"
            `Quick test_g3_seed_init_conjuncts;
          Alcotest.test_case
            "the Disable_* prefix reaches the all-faults-OFF seed" `Quick
            test_disable_prefix_reaches_fair_seed;
        ] );
      ( "refuted_path",
        [
          Alcotest.test_case
            "G1's check refutes a forged duplicate-uid post-crash state" `Quick
            test_g1_refutes_forged_duplicate_uid;
          Alcotest.test_case
            "G2's check refutes a forged post-crash reconcile-id collision" `Quick
            test_g2_refutes_forged_rid_collision;
          Alcotest.test_case
            "G3's check refutes a forged off-goal quiescent state" `Quick
            test_g3_refutes_forged_offgoal_quiescent;
        ] );
      ( "g1_invariants_under_faults",
        [
          Alcotest.test_case
            "full VSTS always-suite survives a real crash, decisively" `Quick
            test_g1_suite_survives_crash;
        ] );
      ( "robustness",
        [
          Alcotest.test_case "G1 witness survives raised uid/rv ceilings" `Quick
            test_robustness_raised_ceilings;
        ] );
      ( "g3_settles_after_disable",
        [
          Alcotest.test_case
            "every post-disable settled state matches the desired state" `Quick
            test_g3_settles_after_disable;
        ] );
      ( "g2_unique_reconcile_id_under_faults",
        [
          Alcotest.test_case
            "uniqueness holds at >= 2-concurrent POST-CRASH states, decisively"
            `Quick test_g2_unique_rid_survives_crash;
        ] );
    ]

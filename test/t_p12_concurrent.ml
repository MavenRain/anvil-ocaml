(* BUILD-SPEC-P12 §5 / §6.1 - the concurrent-reconcile non-vacuity harness.

   De-vacuifies invariant #6 [every_ongoing_reconcile_has_unique_id]. The P11
   VSTS harness pins its interesting-count at 0 (t_p11_vsts_invariants.ml:164) -
   an HONEST vacuity: the single-CR seed [Scenario.vsts_seed] never reaches
   [cardinal(ongoing) >= 2], so inv6 is checked at NO state there. P12 supplies
   the missing pieces WITHOUT touching the transition system (§0): a multi-CR
   VSTS seed [Scenario.vsts_seed_multi] whose distinct cr keys admit >= 2
   CONCURRENT ongoing reconciles of the SINGLE controller, plus the P12 gate
   [Cc.check_unique_reconcile_id_vsts] that explores it, WITNESSES the
   >= 2-concurrent states ([gate_states = Some n], n > 0) and confirms uniqueness
   holds DECISIVELY (frontier emptied) at every reachable state up to the bound.

   All counts are MEASURED-then-PINNED (arch finding 14): a moved count means the
   reachable graph or the invariant's exercise surface shifted and must be
   re-justified. The witness [desireds] is [1;1] (two 1-replica CRs, the CHEAPEST
   >= 2-concurrent seed): its p12_bound graph is FINITE and DECISIVE at depth 40
   (8580 states, frontier emptied), whereas [2;2] is non-decisive at depth 40 and
   larger. Empirically measured on the anvil-ocaml switch:

     vsts [1;1]  gate=6952  decisive=true   states=8580  max_uid=5(<7) max_rv=4(<7)
     vsts [2]    gate=0     decisive=true   states=50    (the disclosed vacuity)
     vrs  [1;1]  gate=3880  decisive=true   states=5734  max_uid=5(<7) max_rv=6(<7)
                 (reconcile_ceiling=2: the minimal ceiling admitting exactly the two
                  concurrent starts - a small decisive graph; see [vrs_bound] below).

   BINDING DIMENSION (review LOW-2): at the witness [reconcile_ceiling] is AT its
   ceiling and [report.pruned = true] - it, NOT uid/rv, is the binding ceiling here
   (raising it grows the graph and eventually flips [decisive]). This is not a
   soundness gap: uniqueness holds CONSTRUCTIONALLY (the monotone
   [Reconcile_id_allocator.allocate] gives distinct ids at ANY ceiling, so a [Refuted]
   never arises from the real allocator), so the clip bounds COVERAGE, not truth. See
   [Cc.check_unique_reconcile_id_vsts]'s .mli for the full disclosure.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches (both [Mc.outcome] arms named, no wildcard-on-finite-sum),
   Option.value / Option.is_none not two-arm option match, Alcotest as the
   sanctioned failure primitive. *)

module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check

let controller_id : int = Scenario.controller_id

(* ---- §5 the P12 bound - single source of truth in [P12_witness] (review NIT-4,
   shared with t_p12_mutation so the [1;1] witness cannot drift between exes) --- *)

let p12_bound = P12_witness.p12_bound

(* ---- report field accessors (exhaustive 2-arm matches on [Mc.outcome]) ----- *)

let decisive (r : Cc.report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let is_clean (r : Cc.report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

let gate_of (r : Cc.report) : int = Option.value r.gate_states ~default:(-1)

(* ---- direct-discrimination states (§6.1(5)): hand-built ongoing reconciles - *)

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

(* A hand-built cluster_state whose single [controller_id] carries one ongoing
   reconcile per [(name, reconcile_id)] under a DISTINCT cr key. Total (no raise);
   the api-server / network / allocator fields are inherited from a real seed so
   only [ongoing_reconciles] is under test. *)
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
  let base = Scenario.vsts_seed_multi ~desireds:[ 1 ] ~fair:true in
  {
    base with
    Cluster.controller_and_externals =
      Imap.add controller_id
        { Cluster.controller; external_ = None; crash_enabled = false }
        Imap.empty;
  }

(* ==== §6.1 the five cases (all counts MEASURED-then-PINNED) ================ *)

(* The witness: two 1-replica CRs (the cheapest >= 2-concurrent seed), from the
   shared [P12_witness] module. Computed ONCE (24s exploration) and shared by
   [test_vsts_nonvacuous] and the base leg of [test_robustness]. *)
let witness_desireds : int list = P12_witness.witness_desireds
let witness_bound : Bound.t = p12_bound ~desireds:witness_desireds

let witness_report : Cc.report =
  Cc.check_unique_reconcile_id_vsts witness_bound ~desireds:witness_desireds

(* PINNED from the decisive fair:true [1;1] graph (MEASURED). *)
let pinned_gate_states : int = P12_witness.pinned_gate_states
let pinned_max_uid_seen : int = 5
let pinned_max_rv_seen : int = 4

let test_vsts_nonvacuous () =
  let r = witness_report in
  (* SEMANTIC assertions FIRST (review MED-1): a collision-inducing mutant must
     redden the gate's clean / [violated=None] wiring, NOT be masked by the brittle
     pinned count (which a mutant also shifts by merging states). Alcotest halts at
     the first failing check, so the load-bearing semantics precede the exact pins. *)
  Alcotest.(check bool) "gate_states positive (>= 2-concurrent witness is real)"
    true (gate_of r > 0);
  Alcotest.(check bool) "outcome clean (uniqueness holds, no counterexample)"
    true (is_clean r);
  Alcotest.(check bool) "outcome decisive (frontier emptied)" true (decisive r);
  Alcotest.(check bool) "violated = None" true (Option.is_none r.violated);
  Alcotest.(check bool) "max_uid_seen STRICTLY below uid_ceiling" true
    (r.max_uid_seen < r.bound.uid_ceiling);
  Alcotest.(check bool) "max_rv_seen STRICTLY below rv_ceiling" true
    (r.max_rv_seen < r.bound.rv_ceiling);
  (* Exact MEASURED pins LAST (arch finding 14): a moved count means the graph or
     the invariant's exercise surface shifted and must be re-justified. *)
  Alcotest.(check int) "gate_states (pinned)" pinned_gate_states (gate_of r);
  Alcotest.(check int) "max_uid_seen (pinned)" pinned_max_uid_seen r.max_uid_seen;
  Alcotest.(check int) "max_rv_seen (pinned)" pinned_max_rv_seen r.max_rv_seen

let test_single_cr_vacuous () =
  let r =
    Cc.check_unique_reconcile_id_vsts (p12_bound ~desireds:[ 2 ]) ~desireds:[ 2 ]
  in
  Alcotest.(check int)
    "single-CR gate_states = 0 (interesting NOT always-on; P11 vacuity is true)"
    0 (gate_of r)

(* Raising the uid/rv ceilings (which do NOT bind at the witness: max 5 < 7,
   4 < 7) must leave the reachable graph - hence [gate_states] and the maxima -
   unchanged: the witness is a real concurrency phenomenon, not a ceiling
   artifact. *)
let test_robustness () =
  let raised =
    { witness_bound with
      Bound.uid_ceiling = witness_bound.uid_ceiling + 3;
      rv_ceiling = witness_bound.rv_ceiling + 3 }
  in
  let r0 = witness_report in
  let r1 = Cc.check_unique_reconcile_id_vsts raised ~desireds:witness_desireds in
  (* Self-contained non-vacuity floor (review NIT-3): without this, every relative
     check below is satisfied by a degenerate always-0 (empty-graph) gate. *)
  Alcotest.(check bool) "robustness base gate is positive (self-contained)" true
    (gate_of r0 > 0);
  Alcotest.(check bool) "raised ceilings: gate_states unchanged (or grows)" true
    (gate_of r1 >= gate_of r0);
  Alcotest.(check int) "raised ceilings: gate_states identical (not a ceiling artifact)"
    (gate_of r0) (gate_of r1);
  Alcotest.(check int) "raised ceilings: max_uid_seen unchanged" r0.max_uid_seen
    r1.max_uid_seen;
  Alcotest.(check int) "raised ceilings: max_rv_seen unchanged" r0.max_rv_seen
    r1.max_rv_seen

(* VRS parity. The §6.1(4) prose named [p12_bound ~desireds:[2;3]]; that graph
   (and even [1;2]) is intractable within the sandbox 150s alarm. DOCUMENTED
   DEVIATION: the parity witness is [1;1] with [reconcile_ceiling = 2] - the
   MINIMAL ceiling admitting exactly the two concurrent starts - which yields a
   small DECISIVE graph (5734 states, frontier emptied) whose gate is non-vacuous
   ([gate=3880]) with the maxima strictly below their ceilings. Same intent: the
   P12 machinery generalizes across controllers and VRS is also non-vacuous
   (cross-checking the [t_p4_enumerator] VRS witness). *)
let vrs_bound : Bound.t =
  { (p12_bound ~desireds:[ 1; 1 ]) with Bound.reconcile_ceiling = 2 }

let pinned_vrs_gate_states : int = 3880

let test_vrs_parity () =
  let r = Cc.check_unique_reconcile_id_vrs vrs_bound ~desireds:[ 1; 1 ] in
  Alcotest.(check bool) "VRS gate_states positive (machinery generalizes)" true
    (gate_of r > 0);
  Alcotest.(check int) "VRS gate_states (pinned)" pinned_vrs_gate_states (gate_of r);
  Alcotest.(check bool) "VRS outcome clean" true (is_clean r);
  Alcotest.(check bool) "VRS outcome decisive" true (decisive r);
  Alcotest.(check bool) "VRS violated = None" true (Option.is_none r.violated);
  Alcotest.(check bool) "VRS max_uid_seen STRICTLY below uid_ceiling" true
    (r.max_uid_seen < r.bound.uid_ceiling);
  Alcotest.(check bool) "VRS max_rv_seen STRICTLY below rv_ceiling" true
    (r.max_rv_seen < r.bound.rv_ceiling)

(* The automated confirm-by-mutation analogue (permanent pin): inv6's [holds]
   genuinely DISCRIMINATES two hand-built >= 2-concurrent states - distinct ids
   pass, a forged collision fails - independent of reachability. *)
let test_direct_discrimination () =
  let inv = Invariants.unique_reconcile_id_invariant ~controller_id in
  Alcotest.(check bool) "distinct reconcile_ids (0,1): holds = true" true
    (inv.Invariants.holds (state_with_rids ~rids:[ ("vsts1", 0); ("vsts2", 1) ]));
  Alcotest.(check bool) "duplicate reconcile_ids (0,0): holds = false" false
    (inv.Invariants.holds (state_with_rids ~rids:[ ("vsts1", 0); ("vsts2", 0) ]));
  Alcotest.(check bool) "distinct-id state IS interesting (>= 2 concurrent)" true
    (inv.Invariants.interesting
       (state_with_rids ~rids:[ ("vsts1", 0); ("vsts2", 1) ]))

(* Permanent Refuted-path coverage (review MED-1). The real monotone allocator can
   NEVER mint a collision, so [check_unique_reconcile_id_vsts] never returns [Refuted]
   on the true model - its refutation wiring would otherwise ship with ZERO observed-
   red coverage (the M1 mutant reddens the brittle count first, masking it). Exercise
   the exact [Model_check.check_safety ~inv:holds] logic the gate wraps over a hand-
   forged reachable state carrying two ongoing reconciles that SHARE a [reconcile_id]:
   the safety check MUST refute it. A regression mapping [Refuted -> No_counterexample]
   (a vacuously-clean gate) reddens here. Confirmed to discriminate: with distinct ids
   the check returns [No_counterexample] and this test goes red (seen during review). *)
let test_gate_refutes_forged_collision () =
  let inv = Invariants.unique_reconcile_id_invariant ~controller_id in
  let forged = state_with_rids ~rids:[ ("vsts1", 0); ("vsts2", 0) ] in
  let reach =
    Mc.explore ~depth:1
      ~successors:(fun _ -> [])
      ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ forged ]
  in
  let refuted =
    match Mc.check_safety reach ~inv:inv.Invariants.holds ~equal:Cc.state_equal with
    | Mc.Refuted _ -> true
    | Mc.No_counterexample _ -> false
  in
  Alcotest.(check bool)
    "check_safety over inv6.holds REFUTES a reachable duplicate-id state" true refuted

let () =
  Alcotest.run "p12_concurrent"
    [
      ( "non_vacuity",
        [
          Alcotest.test_case "VSTS >= 2-concurrent witness is real + decisive"
            `Quick test_vsts_nonvacuous;
        ] );
      ( "single_cr_vacuous",
        [
          Alcotest.test_case
            "single-CR gate_states = 0 (interesting not always-on)" `Quick
            test_single_cr_vacuous;
        ] );
      ( "robustness",
        [
          Alcotest.test_case "witness survives raised uid/rv ceilings" `Quick
            test_robustness;
        ] );
      ( "vrs_parity",
        [
          Alcotest.test_case "VRS sibling gate non-vacuous + decisive" `Quick
            test_vrs_parity;
        ] );
      ( "direct_discrimination",
        [
          Alcotest.test_case "holds discriminates distinct vs duplicate ids"
            `Quick test_direct_discrimination;
        ] );
      ( "refuted_path",
        [
          Alcotest.test_case
            "gate's safety check refutes a forged id collision" `Quick
            test_gate_refutes_forged_collision;
        ] );
    ]

(* BUILD-SPEC-P12 §6.2 - confirm-by-mutation for the concurrent-reconcile gate.

   A clean, decisive [No_counterexample] from [t_p12_concurrent] is only evidence
   if the gate would actually MOVE when the thing it checks breaks. This module
   supplies that evidence in two forms:

   - The MANUAL real-source mutant M1 (documented below; SEEN red then reverted -
     only the green tree ships, per [[feedback-confirm-tests-by-mutation]]).
   - The AUTOMATED in-tree analogues M2/M3/M4 - permanent pins that each would go
     red under a described corruption of the gate or the invariant.

   ---- M1 (MANUAL, real source; NOT shipped) --------------------------------

   Mutant: in [lib/cluster/controller.ml] change
     [Reconcile_id_allocator.allocate] from
       ({ reconcile_id_counter = a.reconcile_id_counter + 1 }, a.reconcile_id_counter)
     to hand out a CONSTANT id (second tuple element -> [0]); the counter still
     advances (state equality/termination unchanged), but every reconcile now
     carries [reconcile_id = 0].

   Effect: two concurrent ongoing reconciles then share id 0, so inv6
   [every_ongoing_reconcile_has_unique_id] is VIOLATED on the reachable graph and
   [check_unique_reconcile_id_vsts] flips from [No_counterexample] to [Refuted]
   ([violated = Some inv6]). NOTE (review MED-1): because [reconcile_id] participates
   in cluster-state equality, the constant-0 mutant ALSO merges states and shrinks the
   interesting-count (6952 -> 2896), so pre-review the pinned-count assertion reddened
   FIRST and masked the semantic flip. Two fixes landed: (a) [test_vsts_nonvacuous] now
   checks [is_clean]/[decisive]/[violated=None] BEFORE the pinned int, so the mutant
   reddens at "outcome clean"; (b) the PERMANENT [test_gate_refutes_forged_collision]
   gives the [Refuted] path observed-red coverage with NO mutant (the real monotone
   allocator can never collide). Reverted via [git checkout -- lib/cluster/controller.ml];
   the shipped tree is GREEN.

   Firewall honoured: List/Option/fold combinators only (no loop keywords), no
   [List.nth/hd/tl], no [raise/assert/failwith/Option.get], Alcotest as the
   sanctioned failure primitive. All counts MEASURED-then-PINNED. *)

module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Cc = Anvil_checker.Cluster_check

let controller_id : int = Scenario.controller_id

(* ---- the P12 bound - single source of truth in [P12_witness] (review NIT-4,
   shared with t_p12_concurrent so the [1;1] witness cannot drift) ------------ *)

let p12_bound = P12_witness.p12_bound

let gate_of (r : Cc.report) : int = Option.value r.gate_states ~default:(-1)

(* ==== M2: the seed cardinality is load-bearing ============================= *)

(* A gate that ignored its seed would give the same count for one CR and for
   two. It does not: the ONE-CR seed [2] never reaches >= 2 concurrent ongoing
   reconciles (gate 0, the honest P11 vacuity), while the TWO-CR witness [1;1]
   reaches many (gate > 0). PINNED: single [2] = 0; multi [1;1] = 6952 (the same
   decisive computation pinned in t_p12_concurrent). *)
let pinned_single_gate : int = 0
let pinned_multi_gate : int = P12_witness.pinned_gate_states

let test_witness_requires_multi () =
  let single =
    Cc.check_unique_reconcile_id_vsts (p12_bound ~desireds:[ 2 ]) ~desireds:[ 2 ]
  in
  let multi =
    Cc.check_unique_reconcile_id_vsts
      (p12_bound ~desireds:[ 1; 1 ])
      ~desireds:[ 1; 1 ]
  in
  Alcotest.(check int) "single-CR [2]: gate_states = 0 (vacuous)" pinned_single_gate
    (gate_of single);
  Alcotest.(check bool) "multi-CR [1;1]: gate_states > 0 (non-vacuous)" true
    (gate_of multi > 0);
  Alcotest.(check int) "multi-CR [1;1]: gate_states (pinned)" pinned_multi_gate
    (gate_of multi);
  Alcotest.(check bool) "cardinality moves the gate (multi > single)" true
    (gate_of multi > gate_of single)

(* ==== M3: the count tracks the REAL reachable graph, not a constant ======== *)

(* Same witness [desireds] [1;1] but [reconcile_ceiling] set BELOW the number of
   concurrent starts (1 < 2). Reaching [cardinal(ongoing) = 2] needs
   [reconcile_ceiling >= 2] (each start advances the shared per-controller
   counter), so the 2nd concurrent start is CEILING-PRUNED: the witness correctly
   VANISHES (gate 0) and [pruned = true]. A gate emitting a constant count would
   not collapse here. PINNED: gate = 0, pruned = true. *)
let ceiling_capped_bound : Bound.t =
  { (p12_bound ~desireds:[ 1; 1 ]) with Bound.reconcile_ceiling = 1 }

let test_ceiling_prunes_witness () =
  let r =
    Cc.check_unique_reconcile_id_vsts ceiling_capped_bound ~desireds:[ 1; 1 ]
  in
  Alcotest.(check int) "reconcile_ceiling=1: gate_states = 0 (2nd start pruned)" 0
    (gate_of r);
  Alcotest.(check bool) "reconcile_ceiling=1: pruned = true (a successor dropped)"
    true r.pruned

(* ==== M4: inv6's [holds] rejects a forged id collision ===================== *)

(* The §6.1(5) direct-discrimination duplicate restated as a permanent
   confirm-by-mutation pin: [holds] must accept distinct concurrent ids and
   REJECT a duplicate - independent of reachability. Two ongoing reconciles are
   hand-built under DISTINCT cr keys on the single [controller_id]; only the
   [reconcile_id]s differ between the two states. Total (no raise). *)

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
  let base = Scenario.vsts_seed_multi ~desireds:[ 1 ] ~fair:true in
  {
    base with
    Cluster.controller_and_externals =
      Imap.add controller_id
        { Cluster.controller; external_ = None; crash_enabled = false }
        Imap.empty;
  }

let test_holds_rejects_forged_collision () =
  let inv = Invariants.unique_reconcile_id_invariant ~controller_id in
  Alcotest.(check bool) "distinct ids (0,1): holds = true" true
    (inv.Invariants.holds (state_with_rids ~rids:[ ("vsts1", 0); ("vsts2", 1) ]));
  Alcotest.(check bool) "forged duplicate ids (0,0): holds = false (mutant caught)"
    false
    (inv.Invariants.holds (state_with_rids ~rids:[ ("vsts1", 0); ("vsts2", 0) ]));
  Alcotest.(check bool) "both states ARE interesting (>= 2 concurrent)" true
    (inv.Invariants.interesting
       (state_with_rids ~rids:[ ("vsts1", 0); ("vsts2", 0) ]))

let () =
  Alcotest.run "p12_mutation"
    [
      ( "m2_seed_cardinality",
        [
          Alcotest.test_case "gate moves single->multi (seed load-bearing)"
            `Quick test_witness_requires_multi;
        ] );
      ( "m3_ceiling_prunes",
        [
          Alcotest.test_case "reconcile_ceiling below concurrency prunes witness"
            `Quick test_ceiling_prunes_witness;
        ] );
      ( "m4_holds_discriminates",
        [
          Alcotest.test_case "holds rejects a forged id collision" `Quick
            test_holds_rejects_forged_collision;
        ] );
    ]

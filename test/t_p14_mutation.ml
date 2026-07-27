(* BUILD-SPEC-P14 §4.4 (G3) and §6 rows MB / MC / MD - confirm-by-mutation for
   the ID-LEVEL correspondence family.

   A clean, decisive [No_counterexample] from [t_p14_correspondence] is only
   evidence if the family would actually MOVE when the thing it checks breaks. On
   the TRUE model both legs come back clean, so the family's Refuted path would
   otherwise ship with ZERO observed-red coverage. This module supplies the
   evidence in two forms: the MANUAL real-source mutants MA and M1 (documented
   below - SEEN then reverted, only the green tree ships, per
   [[feedback-confirm-tests-by-mutation]]), and the AUTOMATED in-tree pins G3 /
   MB / MC / MD, which are permanent and need no mutation of [lib/].

   ==== MA (MANUAL, real source; NOT shipped) - the headline of the phase =====

   Mutant: in [lib/cluster/cluster.ml] make [restart_controller] ALSO reset the
   global rpc-id allocator, i.e. add [rpc_id_allocator = Message.Rpc_id_allocator.init ()]
   to the post-restart state. The real transition leaves [s.rpc_id_allocator]
   untouched (it is a top-level [cluster_state] field, cluster.ml:23, and
   [restart_controller] rewrites only the controller's own maps, cluster.ml:309-312).

   MEASURED effect: G2 flips clean -> **Refuted at steps = 6**, with
   [violated = Some "every_in_flight_msg_has_lower_id_than_allocator"] - N1, NOT
   N5. The refutation is real and the NAME is the interesting part: §6's MA row
   predicted N5 "(or N1/N3)", and N1 is what actually fires, EARLIER than any id
   COLLISION needs to form. Once the counter resets to 0 a surviving pre-crash
   message already has [rpc_id >= counter], so N1 breaks at the very first
   post-crash state; a collision (N5) would need the reset counter to be handed
   out a SECOND time, which is strictly later. So the family detects an allocator
   reset one step before the corruption it was predicted to detect.

   CONTROL: G1 is UNCHANGED under MA - 76 states, gate 32, clean, decisive. That
   is what makes the refutation attributable to the CRASH EDGE rather than to a
   general corruption of the model: the crash-free graph never touches
   [restart_controller], so the mutation is invisible there.

   This is the row P13 could not produce. P13 predicted an allocator-reset mutant
   and MEASURED that it refuted nothing (BUILD-SPEC-P13.md:309-318), correctly,
   because no shipped invariant constrained message IDENTITY. (CORRECTED in
   review: the shipped suite DOES read messages - inv9, invariants.ml:656-675, is
   in [Invariants.always] and quantifies over the in-flight pool - but nothing
   related an [rpc_id] to the allocator or to another message's id, which is the
   dimension an allocator reset perturbs.) P14 is the phase that makes it bite.

   ==== M1 (MANUAL, real source; NOT shipped) - the negative that must hold ====

   Mutant: make [restart_controller] KEEP [ongoing_reconciles] instead of
   emptying it (cluster.ml:309).

   MEASURED effect: refutes NOTHING. BOTH legs stay clean and decisive - which is
   §3 trap 2's REQUIRED negative, not a disappointment: keeping the reconcile map
   leaves the pending request and its in-flight copy consistent, so N1-N5 all
   still hold, and a run reporting M1 refuting this family would be a harness bug.
   The graph does shrink, and the shrink is the honest measurement: G2 states
   464 -> 152, crash_witness 388 -> 76, gate 296 -> 32. (The shrink is why the
   §3 trap 1 assertion ORDER matters even for a negative row: a pinned count
   reddens under M1 while every semantic assertion stays green, and reading that
   red as "M1 refuted something" is exactly the misattribution P12 shipped.)

   ==== the automated rows =====================================================

   G3  a hand-forged state carrying two DISTINCT in-flight messages that share an
       [rpc_id] is Refuted by N5, and the SAME harness on the same state with
       DISTINCT ids returns [No_counterexample]. The negative control is the
       point: a test never SEEN to fail in the direction it guards is not
       evidence.
   MB  N5's uniqueness conjunct weakened to [true] (built INLINE - [lib/] is not
       edited) makes the G3 forge come back CLEAN, so G3's red is attributable to
       that conjunct and to nothing else.
   N2/N3/N4
       one hand-forged state per member that violates THAT member and nothing
       else, each with a sibling that satisfies it. Added in review: G3 covered
       only N5 and the manual MA only N1, so three of the five [holds] shipped
       with their rejecting behaviour never once observed - trivialising any of
       them to [fun _ -> true] left every P14 test green.
   MC  N1 reads the LIVE [s.rpc_id_allocator]: two states differing in NOTHING
       BUT that field get DIFFERENT verdicts. Replaces the old row ("[<]
       weakened to [<=] changes no verdict"), which was LOGICALLY ENTAILED and
       therefore could not detect §6's "the harness is reading the wrong
       counter"; the [<]-vs-[<=] boundary is kept as the discriminating state
       and the entailed graph checks are retained as a regression guard.
   MD  each pinned per-member count IS that member's own [interesting] over the
       leg's graph: re-deriving the five reproduces the five pins, and widening
       any member's [interesting] by one satisfiable disjunct makes its count
       STRICTLY GREATER. Replaces the old row (blind [interesting] to false,
       assert 0), which was a tautology and never touched the pins.
   ME  the leg's [violated] NAMING path, driven to a real [Refuted] through the
       exported {!Fc.violated_of} - the exact function the legs pass as
       [~violated] - since the leg itself cannot be made red without a source
       mutation. See the row's own header for why that substitution is the
       honest one.

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches (both [Mc.outcome] arms named), no [List.nth/hd/tl], no
   [raise/assert/failwith/Option.get], Alcotest as the sanctioned failure
   primitive. All counts MEASURED-then-PINNED, and every pin lives in
   {!P14_witness}. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Correspondence = Anvil_assurance.Correspondence

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P14_witness.witness_desired
let depth : int = P14_witness.witness_depth
let bound : Bound.t = P14_witness.p14_bound ~desireds:[ desired ]

let family : Invariants.invariant list =
  Correspondence.family cluster ~controller_id

(* ---- outcome projections (exhaustive 2-arm matches on [Mc.outcome]) -------- *)

let refuted (o : Fc.faulted Mc.outcome) : bool =
  match o with Mc.Refuted _ -> true | Mc.No_counterexample _ -> false

let clean_decisive (o : Fc.faulted Mc.outcome) : bool =
  match o with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let states_of (o : Fc.faulted Mc.outcome) : int =
  match o with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let inv_name (i : Invariants.invariant option) : string =
  Option.fold i ~none:"<none>" ~some:(fun (x : Invariants.invariant) -> x.name)

(* ---- the shared graph and the singleton harness ---------------------------- *)

let seed : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ()

let reach_of (budget : Fc.budget) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed seed ]

let g1_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of P14_witness.zero_budget)

let g2_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of P14_witness.witness_budget)

(* A one-state [reachable], so the EXACT check the leg wraps
   ([Mc.check_safety ... ~inv:(fun f -> conj f.cs)]) can be run over a hand-forged
   product state. The [t_p13_faults] / [t_p12_mutation] discriminator pattern. *)
let singleton_reach (f : Fc.faulted) : Fc.faulted Mc.reachable =
  Mc.explore ~depth:1
    ~successors:(fun _ -> [])
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash ~init:[ f ]

let safety_of (invs : Invariants.invariant list) (f : Fc.faulted) :
    Fc.faulted Mc.outcome =
  let conj = Invariants.conjunction invs in
  Mc.check_safety (singleton_reach f)
    ~inv:(fun (x : Fc.faulted) -> conj x.cs)
    ~equal:Fc.faulted_equal

(* ==== the forge ============================================================= *)

(* An allocator wound forward to [n] by folding the real
   [Rpc_id_allocator.allocate] - the counter is abstract and this is the only
   honest way to reach a nonzero one, so the forge cannot accidentally depend on
   allocator internals. *)
let allocator_at (n : int) : Message.Rpc_id_allocator.t =
  List.fold_left
    (fun (a : Message.Rpc_id_allocator.t) (_ : int) ->
      fst (Message.Rpc_id_allocator.allocate a))
    (Message.Rpc_id_allocator.init ())
    (List.init n (fun i -> i))

let cr_key : Common.object_ref =
  {
    Common.kind = Common.Custom_resource "VStatefulSet";
    name = "vsts";
    namespace = "ns";
  }

let pod_key : Common.object_ref =
  { Common.kind = Common.Pod; name = "forged-pod"; namespace = "ns" }

(* An api REQUEST to the api server from controller [cid], carrying [id]. The
   sender is a parameter for exactly one caller: N4's isolation forge, which
   needs an UNREGISTERED controller id. *)
let req_from ~(cid : int) ~(id : int) ~(key : Common.object_ref) : Message.t =
  Message.form_msg
    ~src:(Message.Controller (cid, cr_key))
    ~dst:Message.Api_server ~rpc_id:(Message.Rpc_id.of_int id)
    ~content:(Message.get_req_msg_content key)

(* The same request from the scenario's REGISTERED controller (so N4 holds and
   the forge isolates N5). Two calls with different [key]s give two messages that
   differ in [content], hence are DISTINCT under [Message.equal] - Anvil's
   [msg != other_msg] guard - while their [rpc_id]s are free to collide or not. *)
let req ~(id : int) ~(key : Common.object_ref) : Message.t =
  req_from ~cid:controller_id ~id ~key

(* A POST-CRASH ([crashes = 1]) product state whose network holds exactly the two
   requests above and whose allocator is wound past both ids, so N1's strict [<]
   is satisfied and cannot mask N5. The seed's [ongoing_reconciles] is empty, so
   N2 and N3 are vacuously true there: the forge really does isolate N5. *)
let forged ~(ids : int * int) : Fc.faulted =
  let id_a, id_b = ids in
  let msgs = [ req ~id:id_a ~key:cr_key; req ~id:id_b ~key:pod_key ] in
  let cs =
    {
      seed with
      Cluster.network = { Network.in_flight = Message.Pool.of_list msgs };
      rpc_id_allocator = allocator_at P14_witness.forged_allocator_count;
    }
  in
  { Fc.cs; crashes = 1; drops = 0; monkeys = 0 }

let collided : Fc.faulted = forged ~ids:P14_witness.forged_collided_ids
let distinct : Fc.faulted = forged ~ids:P14_witness.forged_distinct_ids

(* ==== G3: the forged-collision discriminator (§4.4) ========================= *)

let test_g3_refutes_forged_collision () =
  let msgs = Message.Pool.distinct (Cluster.in_flight collided.cs) in
  (* The FORGE IS REAL, checked before anything is concluded from it: two
     genuinely DISTINCT messages, each present exactly once (so the no-replicas
     conjunct is NOT what fires), both in flight at once. *)
  Alcotest.(check int) "forge: 2 distinct in-flight messages" 2
    (List.length msgs);
  Alcotest.(check int) "forge: 2 in-flight OCCURRENCES (no replica)" 2
    (Message.Pool.cardinal (Cluster.in_flight collided.cs));
  Alcotest.(check bool)
    "forge: every message has multiplicity 1 (so N5's red is the UNIQUENESS \
     conjunct, not the no-replicas one)"
    true
    (List.for_all
       (fun (m : Message.t) ->
         Message.Pool.count m (Cluster.in_flight collided.cs) = 1)
       msgs);
  Alcotest.(check bool) "forge: N5's interesting fires there (>= 2 in flight)"
    true
    (Correspondence.in_flight_unique_id.interesting collided.cs);
  (* NEGATIVE CONTROL FIRST, so the discriminating direction is SEEN: the same
     harness on the same shape with DISTINCT ids comes back clean. *)
  Alcotest.(check bool)
    "negative control: distinct-id forge satisfies the whole family" true
    (Option.is_none (Invariants.first_violated family distinct.cs));
  Alcotest.(check bool)
    "negative control: the EXACT leg check is CLEAN on the distinct-id forge"
    false
    (refuted (safety_of family distinct));
  Alcotest.(check bool)
    "negative control: N5's interesting fires there TOO (so the clean verdict is \
     not clean-by-vacuity)"
    true
    (Correspondence.in_flight_unique_id.interesting distinct.cs);
  (* SEMANTIC: the exact check the leg wraps REFUTES the collided forge. *)
  Alcotest.(check bool)
    "G3: the EXACT leg check REFUTES two distinct in-flight messages sharing an \
     rpc_id"
    true
    (refuted (safety_of family collided));
  Alcotest.(check bool) "G3: N5 itself rejects the collision" false
    (Correspondence.in_flight_unique_id.holds collided.cs);
  (* Isolation: the OTHER four members still hold there, so the red is N5's. *)
  Alcotest.(check bool) "G3: N1 still HOLDS at the forge (ids below the counter)"
    true
    (Correspondence.in_flight_lower_than_allocator.holds collided.cs);
  Alcotest.(check bool) "G3: N4 still HOLDS at the forge (registered controller)"
    true
    ((Correspondence.in_flight_req_from_controller_valid_id cluster).holds
       collided.cs);
  (* MEASURED pin LAST: the member the family NAMES on this refutation. *)
  Alcotest.(check string) "G3: violated member name (pinned)"
    P14_witness.forged_collision_violated_name
    (inv_name (Invariants.first_violated family collided.cs))

(* ==== the PER-MEMBER isolation forges (review finding F1) ==================
   WHY THESE EXIST. G3 above forges a violation of N5 and of N5 only, and the
   MANUAL MA mutant is the only thing that ever exercised N1's rejection. That
   left N2, N3 and N4 with ZERO refutation coverage: trivialising any of their
   [holds] to [fun _ -> true] left every P14 test green, so three fifths of the
   family shipped with their rejecting behaviour never once SEEN
   ([[feedback-confirm-tests-by-mutation]]). Each member below gets a hand-built
   state that violates IT and a sibling that satisfies it, built with the SAME
   helpers G3 uses ([allocator_at], [req], the [seed]-derived base), so nothing
   new is trusted.

   CONFIRMED BY MUTATION (applied, seen red, reverted - only the green tree
   ships): neutering N2's, N3's or N4's [holds] to [fun _ -> true] in
   [lib/assurance/correspondence.ml] reddens the corresponding test below. The
   assertion that fires is named in each test's header. *)

(* The members that the rows below name individually. N5 is not bound here: the
   G3 and MB rows above already reach it as
   [Correspondence.in_flight_unique_id]. *)
let n1 : Invariants.invariant = Correspondence.in_flight_lower_than_allocator

let n2 : Invariants.invariant =
  Correspondence.pending_req_lower_than_allocator ~controller_id

let n3 : Invariants.invariant =
  Correspondence.in_flight_req_id_differs_from_pending ~controller_id

let n4 : Invariants.invariant =
  Correspondence.in_flight_req_from_controller_valid_id cluster

(* Every member the state violates, by name. [[]] is "the whole family holds";
   a singleton is "exactly this member broke", which is what makes a forge an
   ISOLATION rather than merely a refutation. *)
let violated_names (s : Cluster.cluster_state) : string list =
  List.filter_map
    (fun (i : Invariants.invariant) ->
      if i.holds s then None else Some i.name)
    family

(* A POST-CRASH product state around a forged [cluster_state], so the forges run
   through the SAME [Fc.faulted] wrapper the leg checks. *)
let product (cs : Cluster.cluster_state) : Fc.faulted =
  { Fc.cs; crashes = 1; drops = 0; monkeys = 0 }

(* An ongoing reconcile awaiting [pending]. [triggering_cr], [local_state] and
   [reconcile_id] are inert here - no member of the family reads them, only
   [pending_req_msg] - so they carry the scenario's own cr and a null local
   state rather than anything load-bearing. *)
let ongoing_rec ~(pending : Message.t option) : Controller.ongoing_reconcile =
  {
    Controller.triggering_cr =
      V_stateful_set.marshal (Scenario.vsts ~desired ());
    pending_req_msg = pending;
    local_state = Value.of_json `Null;
    reconcile_id = 0;
  }

(* [s] with the controller's [ongoing_reconciles] REPLACED and every other field
   of its entry (notably [crash_enabled]) preserved. Total, no [Option.get]: the
   [~none] leg rebuilds a fresh entry, and every test below asserts the resulting
   map's cardinal FIRST, so that leg cannot silently degrade a forge. *)
let with_ongoing (s : Cluster.cluster_state)
    (ongoing : Controller.ongoing_reconcile Object_ref_map.t) :
    Cluster.cluster_state =
  let cae : Cluster.controller_and_external =
    Option.fold
      (Imap.find_opt controller_id s.Cluster.controller_and_externals)
      ~none:
        {
          Cluster.controller = Controller.init;
          external_ = None;
          crash_enabled = true;
        }
      ~some:(fun (c : Cluster.controller_and_external) -> c)
  in
  {
    s with
    Cluster.controller_and_externals =
      Imap.add controller_id
        {
          cae with
          Cluster.controller =
            { cae.controller with Controller.ongoing_reconciles = ongoing };
        }
        s.Cluster.controller_and_externals;
  }

(* The shared forged shape: the network holds exactly [in_flight], the allocator
   is wound to [alloc], and the controller carries ONE ongoing reconcile awaiting
   [pending] - or no ongoing reconcile at all when [pending] is [None], which is
   the G3 / N4 shape in which N2 and N3 are vacuously true. *)
let forged_state ~(alloc : int) ~(in_flight : Message.t list)
    ~(pending : Message.t option) : Cluster.cluster_state =
  let base =
    {
      seed with
      Cluster.network = { Network.in_flight = Message.Pool.of_list in_flight };
      rpc_id_allocator = allocator_at alloc;
    }
  in
  Option.fold pending ~none:base ~some:(fun (_ : Message.t) ->
      with_ongoing base
        (Object_ref_map.add cr_key (ongoing_rec ~pending) Object_ref_map.empty))

(* -- N2: a pending request whose id is NOT below the counter ---------------- *)

(* The network is EMPTY, so N1, N3, N4 and N5 are all vacuous here and the state
   isolates N2. The violating id EQUALS the counter - the boundary at which
   [rpc_id < counter] first fails - so the forge is minimal rather than wildly
   out of range. *)
let n2_violating : Cluster.cluster_state =
  forged_state ~alloc:P14_witness.forged_allocator_count ~in_flight:[]
    ~pending:(Some (req ~id:P14_witness.forged_pending_violating_id ~key:cr_key))

let n2_control : Cluster.cluster_state =
  forged_state ~alloc:P14_witness.forged_allocator_count ~in_flight:[]
    ~pending:(Some (req ~id:P14_witness.forged_pending_ok_id ~key:cr_key))

(* MUTATION-CONFIRMED. With N2's [holds] neutered to [fun _ -> true] the
   assertion that fires is "N2 REJECTS a pending request whose rpc_id is NOT
   below the allocator counter" (the [false] check), followed by the isolation
   list. *)
let test_n2_rejects_pending_req_at_the_counter () =
  (* THE FORGE IS REAL, checked before anything is concluded from it. *)
  Alcotest.(check int) "N2 forge: exactly ONE ongoing reconcile was planted" 1
    (Object_ref_map.cardinal
       (Cluster.ongoing_reconciles n2_violating controller_id));
  Alcotest.(check int)
    "N2 forge: the network is EMPTY (so N1/N3/N4/N5 are vacuous and the forge \
     isolates N2)"
    0
    (Message.Pool.cardinal (Cluster.in_flight n2_violating));
  Alcotest.(check bool)
    "N2 forge: N2's interesting fires (a pending request really exists)" true
    (n2.interesting n2_violating);
  (* NEGATIVE CONTROL FIRST, so the discriminating direction is SEEN: the same
     shape with the id strictly BELOW the counter is accepted. *)
  Alcotest.(check bool)
    "N2 control: a pending request BELOW the counter is ACCEPTED" true
    (n2.holds n2_control);
  Alcotest.(check bool)
    "N2 control: N2's interesting fires there TOO (the accept is not by \
     vacuity)"
    true
    (n2.interesting n2_control);
  Alcotest.(check (list string))
    "N2 control: the control state violates NO member" []
    (violated_names n2_control);
  (* SEMANTIC: the member REJECTS. *)
  Alcotest.(check bool)
    "N2 REJECTS a pending request whose rpc_id is NOT below the allocator \
     counter"
    false (n2.holds n2_violating);
  Alcotest.(check (list string))
    "N2 is the ONLY member the forge violates (the red is attributable to N2)"
    [ n2.name ] (violated_names n2_violating);
  Alcotest.(check bool)
    "N2: the EXACT leg check REFUTES the forge" true
    (refuted (safety_of family (product n2_violating)))

(* -- N3: an in-flight api REQUEST carrying the pending request's id --------- *)

(* [fst] is the IN-FLIGHT request's id and [snd] the PENDING one's, so
   {!P14_witness.forged_collided_ids} is a collision between them and
   {!P14_witness.forged_distinct_ids} is its control - the same pair, the same
   meaning as in G3. The two messages differ in CONTENT (different object keys),
   so Anvil's [msg != pending_req] guard does not excuse the shared id. Exactly
   ONE message is in flight, so N5 - which needs two - cannot be what fires. *)
let n3_state ~(ids : int * int) : Cluster.cluster_state =
  let in_flight_id, pending_id = ids in
  forged_state ~alloc:P14_witness.forged_allocator_count
    ~in_flight:[ req ~id:in_flight_id ~key:cr_key ]
    ~pending:(Some (req ~id:pending_id ~key:pod_key))

let n3_violating : Cluster.cluster_state =
  n3_state ~ids:P14_witness.forged_collided_ids

let n3_control : Cluster.cluster_state =
  n3_state ~ids:P14_witness.forged_distinct_ids

(* MUTATION-CONFIRMED. With N3's [holds] neutered to [fun _ -> true] the
   assertion that fires is "N3 REJECTS an in-flight api request that shares the
   pending request's rpc_id". *)
let test_n3_rejects_in_flight_req_sharing_the_pending_id () =
  (* THE FORGE IS REAL. *)
  Alcotest.(check int) "N3 forge: exactly ONE ongoing reconcile was planted" 1
    (Object_ref_map.cardinal
       (Cluster.ongoing_reconciles n3_violating controller_id));
  Alcotest.(check int)
    "N3 forge: exactly ONE message in flight (so N5, which needs two, cannot be \
     what fires)"
    1
    (Message.Pool.cardinal (Cluster.in_flight n3_violating));
  Alcotest.(check bool)
    "N3 forge: N3's interesting fires (a pending request AND an in-flight api \
     request)"
    true
    (n3.interesting n3_violating);
  (* NEGATIVE CONTROL FIRST. *)
  Alcotest.(check bool)
    "N3 control: DISTINCT ids on the same shape are ACCEPTED" true
    (n3.holds n3_control);
  Alcotest.(check bool)
    "N3 control: N3's interesting fires there TOO (not clean-by-vacuity)" true
    (n3.interesting n3_control);
  Alcotest.(check (list string))
    "N3 control: the control state violates NO member" []
    (violated_names n3_control);
  (* SEMANTIC: the member REJECTS. *)
  Alcotest.(check bool)
    "N3 REJECTS an in-flight api request that shares the pending request's \
     rpc_id"
    false (n3.holds n3_violating);
  Alcotest.(check (list string))
    "N3 is the ONLY member the forge violates" [ n3.name ]
    (violated_names n3_violating);
  Alcotest.(check bool)
    "N3: the EXACT leg check REFUTES the forge" true
    (refuted (safety_of family (product n3_violating)))

(* -- N4: an in-flight api request from an UNREGISTERED controller ----------- *)

let n4_violating : Cluster.cluster_state =
  forged_state ~alloc:P14_witness.forged_allocator_count
    ~in_flight:
      [
        req_from ~cid:P14_witness.forged_unregistered_controller_id
          ~id:P14_witness.forged_pending_ok_id ~key:cr_key;
      ]
    ~pending:None

let n4_control : Cluster.cluster_state =
  forged_state ~alloc:P14_witness.forged_allocator_count
    ~in_flight:[ req ~id:P14_witness.forged_pending_ok_id ~key:cr_key ]
    ~pending:None

(* MUTATION-CONFIRMED. With N4's [holds] neutered to [fun _ -> true] the
   assertion that fires is "N4 REJECTS an in-flight api request from a
   controller id that is NOT in controller_models". *)
let test_n4_rejects_unregistered_controller_sender () =
  (* THE FORGE IS REAL, and the two controller ids really are what the forge
     claims - the registered one bound in [controller_models], the forged one
     absent. Without this the [false] below could be an accident of some other
     mismatch. *)
  Alcotest.(check bool)
    "N4 forge: the scenario's controller id IS registered in controller_models"
    true
    (Imap.mem controller_id cluster.Cluster.controller_models);
  Alcotest.(check bool)
    "N4 forge: the forged sender's controller id is NOT registered" false
    (Imap.mem P14_witness.forged_unregistered_controller_id
       cluster.Cluster.controller_models);
  Alcotest.(check int) "N4 forge: exactly ONE message in flight" 1
    (Message.Pool.cardinal (Cluster.in_flight n4_violating));
  Alcotest.(check bool)
    "N4 forge: N4's interesting fires (an in-flight api request from a \
     controller)"
    true
    (n4.interesting n4_violating);
  (* NEGATIVE CONTROL FIRST. *)
  Alcotest.(check bool)
    "N4 control: the SAME request from the REGISTERED controller is ACCEPTED"
    true (n4.holds n4_control);
  Alcotest.(check bool)
    "N4 control: N4's interesting fires there TOO (not clean-by-vacuity)" true
    (n4.interesting n4_control);
  Alcotest.(check (list string))
    "N4 control: the control state violates NO member" []
    (violated_names n4_control);
  (* SEMANTIC: the member REJECTS. *)
  Alcotest.(check bool)
    "N4 REJECTS an in-flight api request from a controller id that is NOT in \
     controller_models"
    false (n4.holds n4_violating);
  Alcotest.(check (list string))
    "N4 is the ONLY member the forge violates" [ n4.name ]
    (violated_names n4_violating);
  Alcotest.(check bool)
    "N4: the EXACT leg check REFUTES the forge" true
    (refuted (safety_of family (product n4_violating)))

(* ==== MB: N5's uniqueness conjunct weakened to [true] (§6) ================== *)

(* Built INLINE - [lib/assurance/correspondence.ml] is not edited. Only the
   uniqueness conjunct is dropped; the no-replicas conjunct
   ([count msg = 1], network.rs:382's first clause) survives, which is what makes
   this a weakening of ONE conjunct rather than of the member. *)
let n5_no_uniqueness : Invariants.invariant =
  {
    Correspondence.in_flight_unique_id with
    Invariants.holds =
      (fun s ->
        let pool = Cluster.in_flight s in
        List.for_all
          (fun (m : Message.t) -> Message.Pool.count m pool = 1)
          (Message.Pool.distinct pool));
  }

let family_mb : Invariants.invariant list =
  List.map
    (fun (i : Invariants.invariant) ->
      if String.equal i.name Correspondence.in_flight_unique_id.name then
        n5_no_uniqueness
      else i)
    family

let test_mb_weakened_n5_loses_the_forge () =
  (* The mutant is a genuine WEAKENING and nothing else: it accepts the state the
     real member rejects, and still rejects a replica. *)
  Alcotest.(check bool) "MB: the weakened N5 ACCEPTS the collided forge" true
    (n5_no_uniqueness.holds collided.cs);
  Alcotest.(check bool) "MB: the real N5 REJECTS it (the conjunct is the only \
                         difference)" false
    (Correspondence.in_flight_unique_id.holds collided.cs);
  (* SEMANTIC: G3 goes red - the discriminator really does discriminate on this
     conjunct, so its green on the real tree is evidence about THIS clause. *)
  Alcotest.(check bool)
    "MB: under the weakened N5 the G3 forge is NO LONGER refuted (G3 would go \
     red - the discriminator discriminates)"
    false
    (refuted (safety_of family_mb collided));
  Alcotest.(check bool)
    "MB: and no OTHER member catches the collision either (the coverage really \
     rests on N5's uniqueness conjunct alone)"
    true
    (Option.is_none (Invariants.first_violated family_mb collided.cs))

(* ==== MC: N1 reads the LIVE allocator (§6, review finding F3) ===============

   WHAT THIS ROW USED TO ASSERT, AND WHY THAT WAS NOT EVIDENCE. MC used to be
   only "N1's [<] weakened to [<=] changes no verdict on either graph". That is
   LOGICALLY ENTAILED - [a < b] implies [a <= b], so the weakened member can
   never refute where the strong one did not - hence it could not fail, and an
   assertion that cannot fail cannot detect the failure mode §6 assigns this row
   ("the harness is reading the wrong counter"). A harness comparing against a
   CONSTANT, or against a stale snapshot of the allocator, satisfies it exactly
   as happily as the correct one.

   WHAT IT ASSERTS NOW, and CAN fail: the counter N1 reads is the LIVE
   [s.rpc_id_allocator]. Two states carrying the SAME in-flight message and
   differing in NOTHING BUT that one field receive DIFFERENT verdicts from N1.
   The [<]-vs-[<=] boundary ([rpc_id] exactly EQUAL to the counter) is kept as
   the discriminating state, because it is the single point at which the two
   spellings disagree - so the one pair does both jobs. The entailed
   graph-invariance checks are RETAINED below, relabelled as what they are: a
   regression guard on the two graphs, not evidence about the counter. *)

(* INLINE, again: [lib/] is untouched. *)
let n1_le : Invariants.invariant =
  {
    Correspondence.in_flight_lower_than_allocator with
    Invariants.holds =
      (fun s ->
        let counter =
          Message.Rpc_id_allocator.rpc_id_count s.Cluster.rpc_id_allocator
        in
        List.for_all
          (fun (m : Message.t) -> Message.Rpc_id.to_int m.rpc_id <= counter)
          (Message.Pool.distinct (Cluster.in_flight s)));
  }

let family_mc : Invariants.invariant list =
  List.map
    (fun (i : Invariants.invariant) ->
      if
        String.equal i.name
          Correspondence.in_flight_lower_than_allocator.name
      then n1_le
      else i)
    family

(* The boundary state that makes MC non-vacuous: ONE in-flight message whose
   [rpc_id] EQUALS the allocator counter. The real N1 rejects it, [<=] accepts
   it - so the two predicates are genuinely different and MC is not passing
   because the "mutant" is a copy of the original. *)
let at_the_boundary : Fc.faulted =
  let cs =
    {
      seed with
      Cluster.network =
        {
          Network.in_flight =
            Message.Pool.singleton
              (req ~id:P14_witness.forged_allocator_count ~key:cr_key);
        };
      rpc_id_allocator = allocator_at P14_witness.forged_allocator_count;
    }
  in
  { Fc.cs; crashes = 1; drops = 0; monkeys = 0 }

(* {!at_the_boundary} with the allocator wound ONE further and NOTHING else
   touched, so the very same message's [rpc_id] is now strictly below the
   counter. The pair is the F3 discriminator: same message, one field apart,
   opposite verdicts. *)
let above_the_boundary : Fc.faulted =
  {
    at_the_boundary with
    Fc.cs =
      {
        at_the_boundary.cs with
        Cluster.rpc_id_allocator =
          allocator_at P14_witness.forged_n1_counter_above;
      };
  }

let test_mc_n1_reads_the_live_allocator () =
  (* THE PAIR IS REAL: putting the base allocator back makes the two states
     IDENTICAL, so they differ in that field ALONE - and the field really does
     differ. Both checked before any verdict is read off them. *)
  Alcotest.(check bool)
    "MC: the two states differ in NOTHING BUT s.rpc_id_allocator" true
    (Fc.faulted_equal at_the_boundary
       {
         above_the_boundary with
         Fc.cs =
           {
             above_the_boundary.cs with
             Cluster.rpc_id_allocator =
               at_the_boundary.cs.Cluster.rpc_id_allocator;
           };
       });
  Alcotest.(check bool) "MC: and the two allocator counters really DO differ"
    true
    (Message.Rpc_id_allocator.rpc_id_count
       above_the_boundary.cs.Cluster.rpc_id_allocator
    <> Message.Rpc_id_allocator.rpc_id_count
         at_the_boundary.cs.Cluster.rpc_id_allocator);
  Alcotest.(check bool) "MC: N1's interesting fires on both (>= 1 in flight)"
    true
    (n1.interesting at_the_boundary.cs && n1.interesting above_the_boundary.cs);
  (* SEMANTIC, THE DISCRIMINATOR: N1's verdict MOVES when the live allocator
     moves and nothing else does. A member reading a constant, a stale copy or
     some other counter would answer identically on both. *)
  Alcotest.(check bool)
    "MC: N1 ACCEPTS the state whose LIVE counter is strictly ABOVE the \
     message's rpc_id"
    true
    (Correspondence.in_flight_lower_than_allocator.holds above_the_boundary.cs);
  Alcotest.(check bool)
    "MC: N1 REJECTS the state whose LIVE counter EQUALS it - same message, only \
     s.rpc_id_allocator moved"
    false
    (Correspondence.in_flight_lower_than_allocator.holds at_the_boundary.cs);
  Alcotest.(check (list string))
    "MC: N1 is the ONLY member that moved (the verdict change is N1's)"
    [ n1.name ]
    (violated_names at_the_boundary.cs);
  Alcotest.(check (list string))
    "MC: the above-counter sibling violates NO member" []
    (violated_names above_the_boundary.cs);
  (* The [<]-vs-[<=] boundary on that SAME discriminating state: the weakened
     spelling accepts exactly what the real one rejects, so the mutant below is
     genuinely weaker and MC is not passing because it is a copy. *)
  Alcotest.(check bool)
    "MC: the weakened N1 ([<=]) ACCEPTS the boundary state (genuinely weaker)"
    true (n1_le.holds at_the_boundary.cs);
  (* RETAINED as a REGRESSION GUARD, not as evidence: [<] implies [<=], so no
     weakened-member run can refute where the strong one did not, and the four
     checks below cannot fail for the reason §6 wanted them to. *)
  let g1 = Lazy.force g1_reach in
  let g2 = Lazy.force g2_reach in
  let conj_mc = Invariants.conjunction family_mc in
  let out_g1 =
    Mc.check_safety g1 ~inv:(fun (f : Fc.faulted) -> conj_mc f.cs)
      ~equal:Fc.faulted_equal
  in
  let out_g2 =
    Mc.check_safety g2 ~inv:(fun (f : Fc.faulted) -> conj_mc f.cs)
      ~equal:Fc.faulted_equal
  in
  Alcotest.(check bool) "MC: G1 graph still clean AND decisive under [<=]" true
    (clean_decisive out_g1);
  Alcotest.(check bool) "MC: G2 graph still clean AND decisive under [<=]" true
    (clean_decisive out_g2);
  Alcotest.(check bool) "MC: no member is violated anywhere on the G2 graph" true
    (Option.is_none
       (Invariants.first_violated family_mc (Fc.faulted_of_seed seed).cs));
  (* MEASURED pins LAST: the same graphs, so the same state counts. *)
  Alcotest.(check int) "MC: G1 graph states unchanged (pinned)"
    P14_witness.g1_states (states_of out_g1);
  Alcotest.(check int) "MC: G2 graph states unchanged (pinned)"
    P14_witness.g2_states (states_of out_g2)

(* ==== MD: each pinned count is a function of THAT member's [interesting]
   (§6, review finding F2) ====================================================

   WHAT THIS ROW USED TO ASSERT, AND WHY THAT WAS A TAUTOLOGY. MD used to blind
   every member's [interesting] to [fun _ -> false] and then assert the resulting
   counts were 0. [count_states_where] of a predicate that is false everywhere is
   0 on EVERY graph, including an empty one - the assertion cannot fail, and it
   never once touched the pins in {!P14_witness} it claimed to validate.

   WHAT IT ASSERTS NOW, and CAN fail. The real property is that each pinned
   per-member count IS the count of that member's OWN [interesting] over the
   leg's graph:

     (a) re-deriving the five counts from the LIVE family reproduces the five
         pins, in order (a member whose [interesting] drifts reddens here);
     (b) PERTURBING a member's [interesting] by one extra SATISFIABLE disjunct
         makes its count STRICTLY GREATER than the pin (a pin that had silently
         become the whole graph, or an [interesting] that was already trivially
         true, reddens here).

   The perturbing disjunct is [cardinal (in_flight s) = 0] - the empty-network
   states, which are reachable (MEASURED: 136 of G2's 464, and asserted below as
   [g2_states - n1_interesting_g2] rather than re-typed) and which no member's
   own [interesting] covers, since every one of the five premises needs either a
   message or a pending request. The blinding direction is RETAINED underneath as
   the lower contrast, now that it is no longer the whole row. *)

let fires (reach : Fc.faulted Mc.reachable) (i : Invariants.invariant) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) -> i.interesting f.cs)

(* INLINE, [lib/] untouched. Blinded: [interesting] false everywhere. *)
let family_md : Invariants.invariant list =
  List.map
    (fun (i : Invariants.invariant) ->
      { i with Invariants.interesting = (fun _ -> false) })
    family

(* INLINE. PERTURBED: the member's own premise OR the extra disjunct. Strictly
   weaker than the original, so its count can only grow - and must. *)
let widen (i : Invariants.invariant) : Invariants.invariant =
  {
    i with
    Invariants.interesting =
      (fun (s : Cluster.cluster_state) ->
        i.interesting s || Message.Pool.cardinal (Cluster.in_flight s) = 0);
  }

(* The five pins, in family order. Read from {!P14_witness}, never re-typed. *)
let pinned_g2_counts : int list =
  [
    P14_witness.n1_interesting_g2;
    P14_witness.n2_interesting_g2;
    P14_witness.n3_interesting_g2;
    P14_witness.n4_interesting_g2;
    P14_witness.n5_interesting_g2;
  ]

let test_md_counts_are_each_member_s_own_interesting () =
  let reach = Lazy.force g2_reach in
  let live = List.map (fires reach) family in
  (* SELF-CONTAINED FLOOR: the graph is REAL and non-empty, so nothing below is
     an empty-graph artifact. *)
  Alcotest.(check bool) "MD: the graph under test is non-empty" true
    (Mc.states_seen reach > 0);
  (* The perturbing disjunct is SATISFIABLE on this graph - if it were not, (b)
     below would be vacuous rather than evidence. Its extent is DERIVED from two
     pins, not a sixth pinned number. *)
  Alcotest.(check bool)
    "MD: the perturbing disjunct (empty network) is satisfiable on this graph"
    true
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         Message.Pool.cardinal (Cluster.in_flight f.cs) = 0)
    > 0);
  (* CONTRAST: on the REAL members every count is positive on this graph. *)
  Alcotest.(check bool)
    "MD contrast: every REAL member's interesting fires somewhere on this graph"
    true
    (List.for_all (fun (n : int) -> n > 0) live);
  (* SEMANTIC (b): every member's count STRICTLY GROWS under the perturbation,
     so no pin is already the whole graph and no [interesting] is trivially
     true. This is the assertion that can fail. *)
  Alcotest.(check bool)
    "MD: PERTURBING each member's interesting by one satisfiable disjunct makes \
     its count STRICTLY GREATER (each pin is a proper sub-count, not the graph)"
    true
    (List.for_all
       (fun (i : Invariants.invariant) -> fires reach (widen i) > fires reach i)
       family);
  (* SEMANTIC: blinded, every count collapses to 0 - the lower contrast. *)
  Alcotest.(check (list int))
    "MD: blinding interesting drives EVERY per-member count to 0" [ 0; 0; 0; 0; 0 ]
    (List.map (fires reach) family_md);
  (* And the leg's own union gate would collapse with them. *)
  Alcotest.(check int) "MD: the union gate over the blinded family is 0 too" 0
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         f.crashes >= 1
         && List.exists
              (fun (i : Invariants.invariant) -> i.interesting f.cs)
              family_md));
  (* MEASURED pins LAST (§3 trap 1). (a): the five live counts ARE the five
     pins, in family order. *)
  Alcotest.(check int) "MD: the graph under test is the G2 graph (pinned)"
    P14_witness.g2_states (Mc.states_seen reach);
  Alcotest.(check int)
    "MD: the empty-network states are exactly the states N1's premise misses \
     (DERIVED from two pins, not a sixth one)"
    (P14_witness.g2_states - P14_witness.n1_interesting_g2)
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         Message.Pool.cardinal (Cluster.in_flight f.cs) = 0));
  Alcotest.(check (list int))
    "MD: re-deriving each count from the LIVE family reproduces the five pins"
    pinned_g2_counts live;
  Alcotest.(check int)
    "MD: the union gate over the REAL family is G2's gate_states (pinned)"
    P14_witness.g2_gate_states
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         f.crashes >= 1
         && List.exists
              (fun (i : Invariants.invariant) -> i.interesting f.cs)
              family))

(* ==== ME: the leg's [violated] NAMING path, driven to Refuted (finding F5) ==

   WHICH OF THE TWO REPAIRS F5 ALLOWS THIS IS, AND WHY. The first - drive
   {!Fc.check_correspondence_under_faults} itself to [Refuted] - is NOT available
   without editing [lib/]. That leg fixes its own seed, its own invariant list
   ({!Correspondence.family}) and its own successor relation; its only free
   parameters are [depth], the {!Bound.t}, the {!Fc.budget}, [desired] and
   [require_crash], and every one of those can only PRUNE the reachable set. On
   the true model the family holds at every reachable product state - both
   shipped legs are clean AND decisive, so that is measured, not hoped - and no
   pruning can add a violating state. The only way to make the real leg red is
   the MA source mutation, which is manual and deliberately not shipped.

   So this row takes F5's SECOND repair, but on the REAL wiring rather than on a
   copy of it: {!Fc.violated_of} - the exact function every leg passes as
   [~violated], exported for precisely this - is applied to REAL [Refuted]
   outcomes from the same {!Mc.check_safety} call the leg makes. Two of them:

     (1) the REAL family over the G3 forged collision, where the expected name is
         N5's (this is the leg's naming path on a genuine port violation, which
         G3 itself bypasses by calling {!Invariants.first_violated} directly);
     (2) a DELIBERATELY-VIOLATING list over the REAL G2 product graph - the real
         family plus one planted always-false member APPENDED LAST - where the
         expected name is the planted member's. (2) is the one that shows the
         path works on a full exploration and reports the member that ACTUALLY
         broke rather than the head of the list. *)

(* Planted, INLINE, and appended LAST so that a [violated_of] which returned the
   head of the list (or the first member, or a constant) would name N1 and redden
   this row. Not a port: the [source] says so. *)
let planted_violation : Invariants.invariant =
  {
    Invariants.name = "p14_test_planted_always_false";
    source = "test/t_p14_mutation.ml (planted in-test; NOT an Anvil StatePred)";
    holds = (fun (_ : Cluster.cluster_state) -> false);
    interesting = (fun (_ : Cluster.cluster_state) -> true);
  }

let family_with_planted : Invariants.invariant list =
  family @ [ planted_violation ]

let safety_over (reach : Fc.faulted Mc.reachable)
    (invs : Invariants.invariant list) : Fc.faulted Mc.outcome =
  let conj = Invariants.conjunction invs in
  Mc.check_safety reach ~inv:(fun (x : Fc.faulted) -> conj x.cs)
    ~equal:Fc.faulted_equal

let test_me_violated_naming_path () =
  let g2 = Lazy.force g2_reach in
  let planted_out = safety_over g2 family_with_planted in
  let clean_out = safety_over g2 family in
  (* THE SETUP IS REAL: the planted member is genuinely LAST, so naming it is
     not the same as naming the head. *)
  Alcotest.(check int) "ME: the planted member is appended, not substituted"
    (List.length family + 1)
    (List.length family_with_planted);
  (* NEGATIVE CONTROLS FIRST: on a CLEAN outcome the naming path yields None,
     over the very same graph and the very same function. *)
  Alcotest.(check bool)
    "ME control: the REAL family over the REAL G2 graph is clean" false
    (refuted clean_out);
  Alcotest.(check string)
    "ME control: violated_of on a clean outcome names NOTHING" "<none>"
    (inv_name (Fc.violated_of family clean_out));
  Alcotest.(check string)
    "ME control: and on the clean distinct-id forge it names NOTHING either"
    "<none>"
    (inv_name (Fc.violated_of family (safety_of family distinct)));
  (* SEMANTIC (2): a real Refuted over the REAL product graph, named through the
     leg's own wiring - and named as the member that actually broke, not the
     head of the list. *)
  Alcotest.(check bool)
    "ME: the deliberately-violating list REFUTES on the real G2 graph" true
    (refuted planted_out);
  Alcotest.(check string)
    "ME: violated_of names the PLANTED member (the leg's [violated] would carry \
     this name)"
    planted_violation.name
    (inv_name (Fc.violated_of family_with_planted planted_out));
  Alcotest.(check bool)
    "ME: and it is NOT merely naming the head of the list" false
    (String.equal
       (inv_name (Fc.violated_of family_with_planted planted_out))
       n1.name);
  (* SEMANTIC (1): the same wiring on a genuine PORT violation - the G3 forged
     collision - names N5. *)
  Alcotest.(check bool) "ME: the G3 forge REFUTES the real family" true
    (refuted (safety_of family collided));
  (* MEASURED pin LAST: the member the leg's naming path reports there. *)
  Alcotest.(check string)
    "ME: violated_of names N5 at the forged collision (pinned)"
    P14_witness.forged_collision_violated_name
    (inv_name (Fc.violated_of family (safety_of family collided)))

let () =
  Alcotest.run "p14_mutation"
    [
      ( "g3_forged_collision",
        [
          Alcotest.test_case
            "N5 refutes two distinct in-flight messages sharing an rpc_id \
             (distinct ids: clean)"
            `Quick test_g3_refutes_forged_collision;
        ] );
      ( "per_member_refutation",
        [
          Alcotest.test_case
            "N2 rejects a pending request whose id is NOT below the counter"
            `Quick test_n2_rejects_pending_req_at_the_counter;
          Alcotest.test_case
            "N3 rejects an in-flight request sharing the pending request's id"
            `Quick test_n3_rejects_in_flight_req_sharing_the_pending_id;
          Alcotest.test_case
            "N4 rejects a request from an unregistered controller id" `Quick
            test_n4_rejects_unregistered_controller_sender;
        ] );
      ( "mb_weakened_n5",
        [
          Alcotest.test_case
            "dropping N5's uniqueness conjunct loses the G3 forge" `Quick
            test_mb_weakened_n5_loses_the_forge;
        ] );
      ( "mc_live_allocator",
        [
          Alcotest.test_case
            "N1's verdict moves when the LIVE allocator moves and nothing else \
             does"
            `Quick test_mc_n1_reads_the_live_allocator;
        ] );
      ( "md_pinned_counts",
        [
          Alcotest.test_case
            "each pinned count is that member's own interesting, and grows when \
             it is widened"
            `Quick test_md_counts_are_each_member_s_own_interesting;
        ] );
      ( "me_violated_naming",
        [
          Alcotest.test_case
            "the leg's violated_of names the member that actually broke" `Quick
            test_me_violated_naming_path;
        ] );
    ]

(* Anvil source: kubernetes_cluster/spec/cluster.rs. The steps this module
   classifies are the [Step] enum at cluster.rs:75 ([lib/cluster/step.ml:11-47]);
   the adversaries it charges are [RestartControllerStep] (cluster.rs:377,
   [lib/cluster/cluster.ml:289]), [DropReqStep] (cluster.rs:439,
   [cluster.ml:348]) and [PodMonkeyStep] (cluster.rs:492, [cluster.ml:388]); the
   three fault DISABLERS it deliberately leaves free are [DisableCrashStep]
   (cluster.rs:407, [cluster.ml:326], flag flip at [:337]), [DisableReqDropStep]
   (cluster.rs:472, [cluster.ml:382], flip at [:385]) and [DisablePodMonkeyStep]
   (cluster.rs:526, [cluster.ml:442], flip at [:445]).

   BUILD-SPEC-P13 sections 2 and 4.3: the fault-budgeted PRODUCT transition
   system. Nothing in [lib/cluster/] changes. This module only pairs the ported
   cluster state with three path-local fault counters and clips the fault edges
   at a budget, which is what makes the faults-ON graph finite (hence the
   verdicts decisive) and what turns "reached AFTER a real crash" into the plain
   state predicate [crashes >= 1] (hence no edge-labelled exploration).

   The equality, hash, ceiling-bounded enumeration and settling predicate are
   REUSED from {!Cluster_check} rather than re-derived, so the product legs
   inherit the soundness arguments already discharged there. No mutable state, no
   exceptions, and the [Step.t] classification is fully enumerated. *)

type budget = { max_crashes : int; max_drops : int; max_monkey_ops : int }

let budget_default : budget =
  { max_crashes = 1; max_drops = 1; max_monkey_ops = 1 }

let budget_crash_only : budget =
  { max_crashes = 1; max_drops = 0; max_monkey_ops = 0 }

type faulted = {
  cs : Cluster.cluster_state;
  crashes : int;
  drops : int;
  monkeys : int;
}

let faulted_of_seed (cs : Cluster.cluster_state) : faulted =
  { cs; crashes = 0; drops = 0; monkeys = 0 }

(* The three counters first: they are O(1) and they discriminate the fault
   epochs, so the expensive structural [state_equal] runs only on same-epoch
   pairs. Every component participates; dropping a counter would merge a
   pre-crash state with its structurally identical post-crash twin and could
   hide the very witness this phase exists to exhibit. *)
let faulted_equal (a : faulted) (b : faulted) : bool =
  a.crashes = b.crashes && a.drops = b.drops && a.monkeys = b.monkeys
  && Cluster_check.state_equal a.cs b.cs

(* Sound bucket hash: [faulted_equal a b ==> faulted_hash a = faulted_hash b],
   since [Cluster_check.state_hash] satisfies the same implication on the cluster
   component and the counters are compared by value. [Hashtbl.hash] on a
   fixed-order list of [int]s is values-only, so it never splits equal states. *)
let faulted_hash (f : faulted) : int =
  Hashtbl.hash [ Cluster_check.state_hash f.cs; f.crashes; f.drops; f.monkeys ]

(* ---- Section 4.3: the twelve-arm fault classification ---- *)

(* Which budget dimension a labelled step consumes. Private: the report exposes
   the counters themselves, never this tag. *)
type dimension = Crashes | Drops | Monkeys

(* Constructor spelling and ARM ORDER copied from the twelve-arm [Step.t] match
   in [Scenario.productive_successors] ([lib/assurance/scenario.ml:660-679]; the
   spec cites it at :619-638, its pre-P13 location, before the two generalised
   seeds were inserted ahead of it). No [_ ->] arm: every constructor is written
   out, so a thirteenth Anvil step is a compile error here, not a silently
   uncharged fault.

   The three [Disable_*] arms return [None] deliberately: they are
   fault-DISABLING, not faults. Charging them would make the settling target
   (all three flags [false]) unreachable at any budget, silently vacuifying the
   settling leg instead of failing it. *)
let step_dimension (step : Step.t) : dimension option =
  match step with
  | Step.Api_server_step _
  | Step.Builtin_controllers_step _
  | Step.Controller_step _
  | Step.Schedule_controller_reconcile_step _ ->
      None
  | Step.Pod_monkey_step _ -> Some Monkeys
  | Step.External_step _ -> None
  | Step.Restart_controller_step _ -> Some Crashes
  | Step.Disable_crash_step _ -> None
  | Step.Drop_req_step _ -> Some Drops
  | Step.Disable_req_drop_step | Step.Disable_pod_monkey_step | Step.Stutter_step
    ->
      None

(* Charge one fault edge. A successor whose charged counter would EXCEED its cap
   is DROPPED ([None]): drop-only pruning, the same discipline as the [Bound.t]
   ceilings (BUILD-SPEC-P8 section 2.1), so it never merges distinct states, it
   only truncates the graph, and the truncation is reported through
   [pruned_by_budget]. Exhaustive on the three dimensions, no wildcard. *)
let charge (b : budget) (f : faulted) (cs : Cluster.cluster_state)
    (dim : dimension) : faulted option =
  match dim with
  | Crashes ->
      let crashes = f.crashes + 1 in
      if crashes > b.max_crashes then None
      else Some { cs; crashes; drops = f.drops; monkeys = f.monkeys }
  | Drops ->
      let drops = f.drops + 1 in
      if drops > b.max_drops then None
      else Some { cs; crashes = f.crashes; drops; monkeys = f.monkeys }
  | Monkeys ->
      let monkeys = f.monkeys + 1 in
      if monkeys > b.max_monkey_ops then None
      else Some { cs; crashes = f.crashes; drops = f.drops; monkeys }

(* One labelled successor to one product successor, or [None] when a budget cap
   dropped it. The [~none] branch is a record allocation, not a recursive call,
   so the eager-[Option.fold] blow-up hazard does not apply. *)
let advance (b : budget) (f : faulted)
    (((step : Step.t), (cs : Cluster.cluster_state)) :
      Step.t * Cluster.cluster_state) : faulted option =
  Option.fold ~none:(Some { f with cs }) ~some:(charge b f cs)
    (step_dimension step)

let faulted_successors (bound : Bound.t) (b : budget) (cluster : Cluster.t)
    (f : faulted) : faulted list =
  List.filter_map (advance b f)
    (Cluster_check.bounded_labelled_successors bound cluster f.cs)

(* ---- Section 4.3: the report ---- *)

type fault_report = {
  outcome : faulted Model_check.outcome;
  bound : Bound.t;
  budget : budget;
  max_uid_seen : int;
  max_rv_seen : int;
  max_crashes_seen : int;
  max_drops_seen : int;
  max_monkeys_seen : int;
  pruned_by_ceiling : bool;
  pruned_by_budget : bool;
  violated : Invariants.invariant option;
  gate_states : int option;
  crash_witness_states : int;
  fault_free_states : int;
  settled_with_faults_live : int;
}

(* ---- Section 4.3: the shared ONE-PASS metadata over the product graph ----

   Everything the report needs about the reachable set except the leg-specific
   [outcome] / [violated] / [gate_states] is computed here, in a single
   {!Model_check.fold_states} traversal (P13 added that fold precisely so a
   caller needing several aggregates over one graph pays for one pass rather
   than one pass per statistic). Unlike {!Cluster_check.collect_metadata} this
   needs NO local BFS mirror and no visited-set table: [fold_states] visits each
   distinct reachable product state exactly once, so the maxima and counts are
   over exactly the set the engine explored, and there is no second dedup
   discipline that could drift from the engine's. *)

type metadata = {
  max_uid_seen : int;
  max_rv_seen : int;
  max_crashes_seen : int;
  max_drops_seen : int;
  max_monkeys_seen : int;
  crash_witness_states : int;
  fault_free_states : int;
  settled_with_faults_live : int;
  pruned_by_ceiling : bool;
  pruned_by_budget : bool;
}

let metadata_zero : metadata =
  {
    max_uid_seen = 0;
    max_rv_seen = 0;
    max_crashes_seen = 0;
    max_drops_seen = 0;
    max_monkeys_seen = 0;
    crash_witness_states = 0;
    fault_free_states = 0;
    settled_with_faults_live = 0;
    pruned_by_ceiling = false;
    pruned_by_budget = false;
  }

(* The crash flag lives per controller (Anvil [RestartController]'s liveness
   toggle, cluster.rs:377 / :407), so it is read off the
   [controller_and_externals] entry of the leg's controller id; a missing entry
   is read as "not crash-enabled". No two-arm option match. *)
let crash_enabled ~(controller_id : int) (s : Cluster.cluster_state) : bool =
  Imap.find_opt controller_id s.controller_and_externals
  |> Option.fold ~none:false
       ~some:(fun (cae : Cluster.controller_and_external) -> cae.crash_enabled)

let any_fault_live ~(controller_id : int) (s : Cluster.cluster_state) : bool =
  crash_enabled ~controller_id s || s.req_drop_enabled || s.pod_monkey_enabled

(* [pruned_by_ceiling] for a visited state is BUILD-SPEC-P13 section 4.3's
   definition verbatim: [Cluster.enabled_successors] produced strictly more
   children than [Cluster_check.bounded_labelled_successors] admitted.
   [pruned_by_budget] is "some labelled successor was dropped by a budget cap",
   which is exactly the drop count of the [advance] filter_map, so the two
   lengths are compared on the SAME labelled list. *)
let fault_metadata ~(bound : Bound.t) ~(budget : budget) ~(cluster : Cluster.t)
    ~(controller_id : int) (reach : faulted Model_check.reachable) : metadata =
  Model_check.fold_states reach ~init:metadata_zero
    ~f:(fun (acc : metadata) (f : faulted) : metadata ->
      let labelled =
        Cluster_check.bounded_labelled_successors bound cluster f.cs
      in
      let admitted = List.filter_map (advance budget f) labelled in
      {
        max_uid_seen = Int.max acc.max_uid_seen f.cs.api_server.uid_counter;
        max_rv_seen =
          Int.max acc.max_rv_seen f.cs.api_server.resource_version_counter;
        max_crashes_seen = Int.max acc.max_crashes_seen f.crashes;
        max_drops_seen = Int.max acc.max_drops_seen f.drops;
        max_monkeys_seen = Int.max acc.max_monkeys_seen f.monkeys;
        crash_witness_states =
          acc.crash_witness_states + Bool.to_int (f.crashes >= 1);
        fault_free_states =
          acc.fault_free_states
          + Bool.to_int (f.crashes = 0 && f.drops = 0 && f.monkeys = 0);
        settled_with_faults_live =
          acc.settled_with_faults_live
          + Bool.to_int
              (Cluster_check.settled bound cluster f.cs
              && any_fault_live ~controller_id f.cs);
        pruned_by_ceiling =
          acc.pruned_by_ceiling
          || List.length (Cluster.enabled_successors bound cluster f.cs)
             > List.length labelled;
        pruned_by_budget =
          acc.pruned_by_budget || List.length admitted < List.length labelled;
      })

(* ---- Section 4.4: the three gates ---- *)

(* The default exploration depth, the same 40 as {!Cluster_check}'s private
   [default_depth] (cluster_check.ml:344), so a P13 leg explores as deep as the
   fault-free leg it strengthens unless the caller retunes it via [?depth]
   (BUILD-SPEC-P13 section 5 retune order: [reconcile_ceiling], then [depth],
   then [max_in_flight]). It also subsumes [Bound.max_reconcile_depth]. *)
let default_depth = 40

(* Which [always]-invariant broke at the counterexample: the head of the lasso
   loop is the bad state ({!Model_check.check_safety}). Product form of
   [Cluster_check.violated_of] (cluster_check.ml:349-359), reading the cluster
   component out of the {!faulted}. No two-arm option match; the loop is nonempty
   by construction but read TOTALLY (no [Array.get], no exception). *)
let violated_of (invs : Invariants.invariant list)
    (outcome : faulted Model_check.outcome) : Invariants.invariant option =
  match outcome with
  | Model_check.No_counterexample _ -> None
  | Model_check.Refuted { lasso; _ } ->
      Option.bind
        (match Array.to_list lasso.Model_check.loop with
        | [] -> None
        | f :: _ -> Some f)
        (fun (f : faulted) -> Invariants.first_violated invs f.cs)

(* The shared explore -> check -> metadata -> report wiring, the product-system
   analogue of [Cluster_check.check_unique_reconcile_id_from]
   (cluster_check.ml:615-644): ONE {!Model_check.explore} over
   {!faulted_successors}, the leg's own [check] on that reachable set, ONE
   {!fault_metadata} pass, and the leg's [violated] / [gate] projections. Private:
   the three gates below are its only callers, and the reachable graph is
   deliberately not exposed (a caller could otherwise re-explore it with a
   different budget and report the two as one run). *)
let run_leg ~(depth : int) ~(bound : Bound.t) ~(budget : budget)
    ~(cluster : Cluster.t) ~(controller_id : int)
    ~(seed : Cluster.cluster_state)
    ~(check : faulted Model_check.reachable -> faulted Model_check.outcome)
    ~(violated : faulted Model_check.outcome -> Invariants.invariant option)
    ~(gate : faulted Model_check.reachable -> int option) : fault_report =
  let successors = faulted_successors bound budget cluster in
  let reach =
    Model_check.explore ~depth ~successors ~equal:faulted_equal
      ~hash:faulted_hash
      ~init:[ faulted_of_seed seed ]
  in
  let outcome = check reach in
  let md : metadata =
    fault_metadata ~bound ~budget ~cluster ~controller_id reach
  in
  {
    outcome;
    bound;
    budget;
    max_uid_seen = md.max_uid_seen;
    max_rv_seen = md.max_rv_seen;
    max_crashes_seen = md.max_crashes_seen;
    max_drops_seen = md.max_drops_seen;
    max_monkeys_seen = md.max_monkeys_seen;
    pruned_by_ceiling = md.pruned_by_ceiling;
    pruned_by_budget = md.pruned_by_budget;
    violated = violated outcome;
    gate_states = gate reach;
    crash_witness_states = md.crash_witness_states;
    fault_free_states = md.fault_free_states;
    settled_with_faults_live = md.settled_with_faults_live;
  }

(* G1. The FULL shipped VSTS suite ({!Vsts_invariants.always} = the shared
   inv1-6 of {!Invariants.cluster_structural} plus the three VSTS invariants)
   refuted by reachability over the crash-only product graph. The invariant is
   lifted to the product pointwise ([fun f -> inv f.cs]): the counters are
   witness bookkeeping, never part of the asserted property, so a refutation is
   a refutation of the PORTED invariant at a genuinely post-crash state, not an
   artifact of the product construction. *)
let check_invariants_under_faults ?(depth = default_depth) (bound : Bound.t)
    (budget : budget) ~(desired : int) : fault_report =
  let cr = Scenario.vsts ~desired () in
  let controller_id = Scenario.controller_id in
  let cluster = Scenario.vsts_cluster in
  let seed =
    Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
      ~pod_monkey:false ()
  in
  let invs = Vsts_invariants.always ~cr ~controller_id in
  let inv = Invariants.conjunction invs in
  run_leg ~depth ~bound ~budget ~cluster ~controller_id ~seed
    ~check:(fun reach ->
      Model_check.check_safety reach
        ~inv:(fun (f : faulted) -> inv f.cs)
        ~equal:faulted_equal)
    ~violated:(violated_of invs)
    ~gate:(fun reach ->
      Some
        (Model_check.count_states_where reach (fun (f : faulted) ->
             f.crashes >= 1
             && List.exists
                  (fun (i : Invariants.invariant) -> i.interesting f.cs)
                  invs)))

(* G4 (BUILD-SPEC-P14 section 4.3). The id-level correspondence family
   ({!Correspondence.family} = the five [proof/network.rs] StatePreds) refuted by
   reachability over the fault product. Structurally G1 with a different
   invariant list: the family is lifted pointwise ([fun f -> inv f.cs]) exactly
   as there, so a refutation is a refutation of the PORTED invariant at a
   genuinely post-crash state, never an artifact of the product construction.

   The crash DIMENSION is selected by the caller's [budget], NOT by the seed:
   both legs seed [~crash:true] (the flag ON, so [Step.Restart_controller_step]
   is enumerated at all) and differ only in [budget.max_crashes]. Same seed, same
   state shape, ONE variable - which is what makes the crash-0 and crash-1 runs
   directly comparable rather than two unrelated experiments.

   [require_crash] selects what the gate COUNTS, and it exists because the two
   legs need different non-vacuity witnesses (BUILD-SPEC-P14 section 4.3 sketched
   a single fixed gate; that is the one place the spec does not survive contact,
   because at [max_crashes = 0] a [crashes >= 1] gate is 0 BY CONSTRUCTION and so
   cannot serve as section 4.4's crash-disabled non-vacuity floor):

   - [false] (the G1 leg): count states where SOME member's [interesting] fires.
     This is the floor proving the family is exercised at all BEFORE any crash,
     so a later clean crash verdict cannot be clean-by-emptiness. MEASURED
     CORRECTION: that floor covers N1-N4 only. N5's [interesting] fires in ZERO
     G1 states (fault-free traffic is request/response lock-step, so its
     [cardinal >= 2] premise is unreachable), and on G2 its 84 firing states are
     ALL post-crash. See {!check_correspondence_under_faults} in the .mli.
   - [true] (the G2 leg): additionally require [f.crashes >= 1], i.e. count the
     states that are genuinely POST-CRASH and exercise a member. This is the
     phase's headline witness. *)
let check_correspondence_under_faults ?(depth = default_depth) (bound : Bound.t)
    (budget : budget) ~(desired : int) ~(require_crash : bool) : fault_report =
  let controller_id = Scenario.controller_id in
  let cluster = Scenario.vsts_cluster in
  let seed =
    Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
      ~pod_monkey:false ()
  in
  let invs = Correspondence.family cluster ~controller_id in
  let inv = Invariants.conjunction invs in
  run_leg ~depth ~bound ~budget ~cluster ~controller_id ~seed
    ~check:(fun reach ->
      Model_check.check_safety reach
        ~inv:(fun (f : faulted) -> inv f.cs)
        ~equal:faulted_equal)
    ~violated:(violated_of invs)
    ~gate:(fun reach ->
      Some
        (Model_check.count_states_where reach (fun (f : faulted) ->
             ((not require_crash) || f.crashes >= 1)
             && List.exists
                  (fun (i : Invariants.invariant) -> i.interesting f.cs)
                  invs)))

(* ---- G5 (BUILD-SPEC-P15 section 4.4): the reconcile-side family ---- *)

(* The step classes of [V_stateful_set_reconciler.reconcile_core]'s landing
   sites, DERIVED from the reconciler's own step encoding rather than invented
   (BUILD-SPEC-P15 section 4.3; {!Scenario.vsts_cluster}'s registered model is
   the VStatefulSet pack, so ITS encoding is the one the leg's graph runs).
   The step machine alternates ACTION steps (emit exactly one request, land in
   their matching [After_*] step) with [After_*] handler steps (consume the
   response, land in the next action step with no request): every landing in
   one of the seven [After_*] constructors is paired with [Some] request
   (v_stateful_set_reconciler.ml:533, :590, :622, :654, :707, :743, :786),
   every landing in any other constructor with [None], and [Init] is never a
   landing state at all ([reconcile_init_state] only). So "the step is an
   [After_*]" is exactly upstream's pending-request state class for this
   reconciler, and its decodable complement exactly the no-pending class.
   Exhaustive on the 17-arm sum, no wildcard: an 18th step is a compile error
   here, not a silently misclassified instantiation. *)
let vsts_step_expects_pending (st : V_stateful_set_reconciler.step) : bool =
  match st with
  | V_stateful_set_reconciler.After_list_pod
  | V_stateful_set_reconciler.After_get_pvc
  | V_stateful_set_reconciler.After_create_pvc
  | V_stateful_set_reconciler.After_create_needed
  | V_stateful_set_reconciler.After_update_needed
  | V_stateful_set_reconciler.After_delete_condemned
  | V_stateful_set_reconciler.After_delete_outdated ->
      true
  | V_stateful_set_reconciler.Init
  | V_stateful_set_reconciler.Get_pvc
  | V_stateful_set_reconciler.Create_pvc
  | V_stateful_set_reconciler.Skip_pvc
  | V_stateful_set_reconciler.Create_needed
  | V_stateful_set_reconciler.Update_needed
  | V_stateful_set_reconciler.Delete_condemned
  | V_stateful_set_reconciler.Delete_outdated
  | V_stateful_set_reconciler.Done
  | V_stateful_set_reconciler.Error ->
      false

(* An erased local state that fails to decode fires NEITHER predicate: it is
   not evidence about the step machine, so R2/R4 stay vacuous there rather
   than being refuted (or validated) by a codec mismatch. The two predicates
   are therefore complements over DECODABLE states only, not over all of
   [Value.t]. No two-arm result match: stdlib [Result.fold]. *)
let vsts_decode_step (f : V_stateful_set_reconciler.step -> bool)
    (v : Value.t) : bool =
  Result.fold
    ~error:(fun (_ : Err.t) -> false)
    ~ok:(fun (st : V_stateful_set_reconciler.s) -> f st.reconcile_step)
    (V_stateful_set_pack.unmarshal_state v)

let vsts_pending_states : Value.t -> bool =
  vsts_decode_step vsts_step_expects_pending

let vsts_none_states : Value.t -> bool =
  vsts_decode_step (fun (step : V_stateful_set_reconciler.step) ->
      not (vsts_step_expects_pending step))

(* G5. The RECONCILE-SIDE correspondence family
   ({!Reconcile_correspondence.family} = R1-R4, every guard on the
   ongoing-reconcile side where every P14 member's is on the network side)
   refuted by reachability over the fault product. Structurally
   {!check_correspondence_under_faults} with a different invariant list: same
   seed construction, same pointwise lift ([fun f -> inv f.cs]), same
   [require_crash] gate selector and the same [default_depth] - so at P13's
   bound / depth / budget the product graph is the SAME one P13 G1 and P14 G2
   explored, the three phases cross-check on [states] /
   [crash_witness_states] / [fault_free_states], and ONLY the asserted family
   differs. A [states] count that disagrees with P14's at the same budget
   means the seed or bound drifted: investigate before reporting anything
   (BUILD-SPEC-P15 section 4.4).

   THE MASKING TRAP (BUILD-SPEC-P15 section 3): the family is asserted ALONE,
   never unioned with {!Correspondence.family}, {!Invariants.always} or
   {!Vsts_invariants.always}. Under mutation MA, P14 measured N1 firing at
   [steps = 6], one step BEFORE an rpc-id collision can form; a unioned leg
   would report N1 and never evaluate R3's exclusivity, masking the phase's
   headline. A [violated] naming a P14 member here means the lists were
   unioned somewhere: harness bug, not a finding.

   [?req_drop] / [?pod_monkey] (P16, BUILD-SPEC-P16 section 4.5): purely
   additive, defaults [false], so both shipped P15 legs are value-identical
   and their pins stand. With a flag [true] at the seed AND a nonzero budget
   cap in the matching dimension, the leg can now actually take a
   [Step.Drop_req_step] / [Step.Pod_monkey_step] edge - discharging P15's
   disclosed by-construction vacuity of its L2 / L3 dimensions (the flag
   makes the edge EXIST, the budget makes it TAKEABLE). *)
let check_reconcile_correspondence_under_faults ?(depth = default_depth)
    ?(req_drop = false) ?(pod_monkey = false) (bound : Bound.t)
    (budget : budget) ~(desired : int) ~(require_crash : bool) : fault_report =
  let controller_id = Scenario.controller_id in
  let cluster = Scenario.vsts_cluster in
  let seed =
    Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ()
  in
  let invs =
    Reconcile_correspondence.family ~controller_id
      ~pending_states:vsts_pending_states ~none_states:vsts_none_states
  in
  let inv = Invariants.conjunction invs in
  run_leg ~depth ~bound ~budget ~cluster ~controller_id ~seed
    ~check:(fun reach ->
      Model_check.check_safety reach
        ~inv:(fun (f : faulted) -> inv f.cs)
        ~equal:faulted_equal)
    ~violated:(violated_of invs)
    ~gate:(fun reach ->
      Some
        (Model_check.count_states_where reach (fun (f : faulted) ->
             ((not require_crash) || f.crashes >= 1)
             && List.exists
                  (fun (i : Invariants.invariant) -> i.interesting f.cs)
                  invs)))

(* ---- G6 (BUILD-SPEC-P16 section 4.4): the request/response family ---- *)

(* Which of the two P16 lists a leg asserts. A SUM, not a bool: the two lists
   are asserted SEPARATELY and never unioned - with each other or with any
   other shipped suite (the masking trap, see the .mli). *)
type list_select = Rv_list | Matched_list

(* "The leg's OWN fault counter reached 1", where "own" is read off the BUDGET:
   a dimension counts only if the budget permits it at all ([cap >= 1]) and this
   state has actually taken such an edge. At {!budget_crash_only} this is
   [crashes >= 1] (P14/P15's [require_crash] meaning); at a drop-only or
   monkey-only budget it is [drops >= 1] / [monkeys >= 1]; at [zero_budget]
   the disjunction is empty and the gate is 0 BY CONSTRUCTION (the P14 lesson:
   such a gate cannot serve as a fault-disabled non-vacuity floor - use
   [require_fault:false] there). *)
let budget_fault_taken (b : budget) (f : faulted) : bool =
  (b.max_crashes >= 1 && f.crashes >= 1)
  || (b.max_drops >= 1 && f.drops >= 1)
  || (b.max_monkey_ops >= 1 && f.monkeys >= 1)

(* G6. The P16 request/response correspondence lists
   ({!Req_resp_correspondence.rv_family} = Q1-Q2, network + etcd guarded;
   {!Req_resp_correspondence.matched_family} = Q3 + Q5, reconcile-coupled)
   refuted by reachability over the fault product. Structurally
   {!check_reconcile_correspondence_under_faults} with the asserted list
   selected by [list_select]: same [~crash:true] seed (the crash DIMENSION is
   still selected by the caller's budget), same pointwise lift
   ([fun f -> inv f.cs]), same {!violated_of}, same [default_depth] - so at
   P13's bound / depth / budget and [vct:false] the product graph is the SAME
   one P13 G1 / P14 G2 / P15 L1 explored and the phases cross-check on
   [states] / [crash_witness_states] / [fault_free_states].

   Unlike every prior leg, the drop and monkey dimensions are REACHABLE here:
   [?req_drop] / [?pod_monkey] thread to the seed flags (edge EXISTS) and the
   budget caps make the edges TAKEABLE - the first legs in the repo that can
   take a [Step.Drop_req_step] or [Step.Pod_monkey_step] at all
   (BUILD-SPEC-P16 section 1). [?vct] threads to the seeded CR: [true] makes
   the reconciler's PVC arm (hence [Get_request]s, hence OK get responses)
   reachable, de-vacuifying Q1/Q2/Q3 (P16-E). Q2's bound-key closure is
   instantiated with THIS leg's [bound], the coupling the family module
   documents: passing a different bound would decouple the closure from the
   explored graph.

   [require_fault] generalises P14/P15's [require_crash]: [false] counts
   states where SOME selected member's [interesting] fires (the non-vacuity
   floor, intended at [zero_budget]); [true] additionally requires
   {!budget_fault_taken} (the post-fault witness, whichever dimension the
   budget permits). A drop leg with [max_drops_seen = 0] or a monkey leg with
   [max_monkeys_seen = 0] is vacuous FOR ITS OWN DIMENSION and no verdict from
   it may be reported (BUILD-SPEC-P16 section 3). *)
let check_req_resp_under_faults ?(depth = default_depth) ?(req_drop = false)
    ?(pod_monkey = false) ?(vct = false) (bound : Bound.t) (budget : budget)
    ~(desired : int) ~(list_select : list_select) ~(require_fault : bool) :
    fault_report =
  let controller_id = Scenario.controller_id in
  let cluster = Scenario.vsts_cluster in
  let seed =
    Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey ~vct
      ()
  in
  let invs =
    match list_select with
    | Rv_list -> Req_resp_correspondence.rv_family bound
    | Matched_list -> Req_resp_correspondence.matched_family ~controller_id
  in
  let inv = Invariants.conjunction invs in
  run_leg ~depth ~bound ~budget ~cluster ~controller_id ~seed
    ~check:(fun reach ->
      Model_check.check_safety reach
        ~inv:(fun (f : faulted) -> inv f.cs)
        ~equal:faulted_equal)
    ~violated:(violated_of invs)
    ~gate:(fun reach ->
      Some
        (Model_check.count_states_where reach (fun (f : faulted) ->
             ((not require_fault) || budget_fault_taken budget f)
             && List.exists
                  (fun (i : Invariants.invariant) -> i.interesting f.cs)
                  invs)))

(* G2. P12's uniqueness gate, strengthened into the crash dimension: the SAME
   {!Invariants.unique_reconcile_id_invariant}, the SAME
   [cardinal(ongoing) >= 2] non-vacuity notion (inv6's own [interesting]), but
   the gate count now additionally requires [crashes >= 1], so it counts the
   >= 2-concurrent-reconciles-AFTER-A-CRASH states that P12's fault-free witness
   could not contain by construction. [violated] is the single invariant itself
   (the [check_unique_reconcile_id_from] precedent), not a
   {!Invariants.first_violated} search, since the suite here is a singleton. *)
let check_unique_reconcile_id_under_faults ?(depth = default_depth)
    (bound : Bound.t) (budget : budget) ~(desireds : int list) : fault_report =
  let controller_id = Scenario.controller_id in
  let cluster = Scenario.vsts_cluster in
  let seed =
    Scenario.vsts_seed_multi_faults ~desireds ~crash:true ~req_drop:false
      ~pod_monkey:false
  in
  let inv = Invariants.unique_reconcile_id_invariant ~controller_id in
  run_leg ~depth ~bound ~budget ~cluster ~controller_id ~seed
    ~check:(fun reach ->
      Model_check.check_safety reach
        ~inv:(fun (f : faulted) -> inv.holds f.cs)
        ~equal:faulted_equal)
    ~violated:(fun outcome ->
      match outcome with
      | Model_check.Refuted _ -> Some inv
      | Model_check.No_counterexample _ -> None)
    ~gate:(fun reach ->
      Some
        (Model_check.count_states_where reach (fun (f : faulted) ->
             inv.interesting f.cs && f.crashes >= 1)))

(* G3. Anvil's [failures_liveness] shape, as a {!Model_check.check_reaches} leg
   over the all-three-faults-live product graph.
   {!Model_check.check_reaches}'s contract is "refute: every reachable QUIESCENT
   state satisfies TARGET", so the two predicates are:

   - [quiescent f] = [Cluster_check.settled] AND all three fault flags FALSE:
     the run has both switched the adversaries off (the [Disable_*] prefix) and
     run out of state-changing productive moves. This is BUILD-SPEC-P13 section
     4.4's predicate, in the QUIESCENT slot (see the .mli deviation note: as the
     TARGET, with [settled] alone as the gate, the leg would refute exactly when
     [settled_with_faults_live > 0], which section 4.3 asks us to MEASURE and
     report as a non-vacuity CONTRAST, not as a defect);
   - [target f] = {!Vsts_invariants.liveness_goal}, i.e. the desired state is
     actually matched there.

   So a [Refuted] is a run that stops, with every fault already disabled, in a
   state that does NOT match the desired state: the honest bounded reading of
   "the controller fails to reconcile even after the failures stop". Clean +
   [gate_states = Some n], [n > 0], is the settling evidence.

   [Cluster_check.settled] counts [Step.Pod_monkey_step] as PRODUCTIVE
   ([Scenario.productive_successors]), which is exactly why this leg needs the
   [Disable_*] trio rather than a merely quiet suffix: while the monkey is live
   and has an enabled op, no state is [settled].

   The .mli carries the MEASURED reading of this leg, including the rule that
   [bound.reconcile_ceiling] must EXCEED the number of pass-wasting fault edges
   the budget permits (otherwise a [Refuted] is starvation of the retry pass, a
   coverage artifact, which is what happens at {!budget_default} over the
   P12-shaped bound). Do not read a [Refuted] here without that check. *)
let check_settles_after_disable ?(depth = default_depth) (bound : Bound.t)
    (budget : budget) ~(desired : int) : fault_report =
  let cr = Scenario.vsts ~desired () in
  let controller_id = Scenario.controller_id in
  let cluster = Scenario.vsts_cluster in
  let seed =
    Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:true
      ~pod_monkey:true ()
  in
  let goal = Vsts_invariants.liveness_goal ~cr in
  let quiescent (f : faulted) : bool =
    Cluster_check.settled bound cluster f.cs
    && not (any_fault_live ~controller_id f.cs)
  in
  let target (f : faulted) : bool = goal.holds f.cs in
  run_leg ~depth ~bound ~budget ~cluster ~controller_id ~seed
    ~check:(fun reach ->
      Model_check.check_reaches reach ~target ~quiescent ~equal:faulted_equal)
    ~violated:(fun outcome ->
      match outcome with
      | Model_check.Refuted _ -> Some goal
      | Model_check.No_counterexample _ -> None)
    ~gate:(fun reach -> Some (Model_check.count_states_where reach quiescent))

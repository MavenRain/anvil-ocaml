(* The P5 cluster driver: wires the generic {!Model_check} engine to the
   vreplicaset {!Scenario} and the ported {!Invariants} / {!Esr} (arch
   [comp-cat-ocaml/lib/temporal/ARCHITECTURE-anvil-ocaml.md] §4 Leg 2;
   normative contract [lib/checker/BUILD-SPEC-P5.md]).

   Honest-limit notes (BUILD-SPEC §6, must appear in-code):
   1. [decisive = true] is verification ONLY of the bounded system under this
      [Bound.t] — never Anvil's ~55k-line Verus theorem, never arbitrary cluster
      size (arch §4 anti-over-claim). It is asserted only when the reachable
      frontier emptied within [depth].
   2. The DAG argument (§0.1: monotone uid / rv / rpc / reconcile counters make
      the productive reachable graph acyclic modulo the stutter self-loop) is
      what makes exploration finite once the ceilings clip counter growth; it is
      stated, not proved, in OCaml, and is guarded by the confirm-by-mutation
      tests on the enumerator (that pruning fires and violations are reachable).
   3. ESR-via-quiescence-reachability ({!check_esr}) is sound because
      [Scenario.seed ~fair:true] disables the disruptors and weak fairness
      forces every fair run off the stutter to a quiescent state, so ESR holds
      up to the bounds iff every reachable quiescent state matches (§0.1.3).
   4. {!check_esr} and {!check_esr_temporal} are cross-checked (a test asserts
      their verdicts agree); disagreement is a bug in one of them. *)

(* ---- §3.1 Sound structural equality (every field participates) ---- *)

let external_state_equal (a : External.state) (b : External.state) : bool =
  Value.equal a.state b.state

let ongoing_equal (a : Controller.ongoing_reconcile)
    (b : Controller.ongoing_reconcile) : bool =
  Dynamic_object.equal a.triggering_cr b.triggering_cr
  && Option.equal Message.equal a.pending_req_msg b.pending_req_msg
  && Value.equal a.local_state b.local_state
  && Int.equal a.reconcile_id b.reconcile_id

let controller_state_equal (a : Controller.state) (b : Controller.state) : bool =
  Object_ref_map.equal ongoing_equal a.ongoing_reconciles b.ongoing_reconciles
  && Object_ref_map.equal Dynamic_object.equal a.scheduled_reconciles
       b.scheduled_reconciles
  && Controller.Reconcile_id_allocator.equal a.reconcile_id_allocator
       b.reconcile_id_allocator

let cae_equal (a : Cluster.controller_and_external)
    (b : Cluster.controller_and_external) : bool =
  controller_state_equal a.controller b.controller
  && Option.equal external_state_equal a.external_ b.external_
  && Bool.equal a.crash_enabled b.crash_enabled

let state_equal (a : Cluster.cluster_state) (b : Cluster.cluster_state) : bool =
  Object_ref_map.equal Dynamic_object.equal a.api_server.resources
    b.api_server.resources
  && Int.equal a.api_server.uid_counter b.api_server.uid_counter
  && Int.equal a.api_server.resource_version_counter
       b.api_server.resource_version_counter
  && Imap.equal cae_equal a.controller_and_externals b.controller_and_externals
  && Message.Pool.equal a.network.in_flight b.network.in_flight
  && Message.Rpc_id_allocator.equal a.rpc_id_allocator b.rpc_id_allocator
  && Bool.equal a.req_drop_enabled b.req_drop_enabled
  && Bool.equal a.pod_monkey_enabled b.pod_monkey_enabled

(* ---- §3.2 Sound bucket hash: [state_equal a b ==> state_hash a = state_hash b].
   Only order-insensitive summaries (counters, cardinalities, bools, and a
   commutative SUM over controllers). NEVER [Hashtbl.hash] on the raw record
   (map tree shape / physical [Value.t] identity would split equal states);
   hashing a fixed-order list of ints is sound (order-fixed, values only). *)

let ongoing_scheduled_sum (c_and_e : Cluster.controller_and_external Imap.t) : int
    =
  Imap.fold
    (fun _id (cae : Cluster.controller_and_external) acc ->
      acc
      + Object_ref_map.cardinal cae.controller.ongoing_reconciles
      + Object_ref_map.cardinal cae.controller.scheduled_reconciles)
    c_and_e 0

let state_hash (s : Cluster.cluster_state) : int =
  let b2i b = if b then 1 else 0 in
  Hashtbl.hash
    [
      s.api_server.uid_counter;
      s.api_server.resource_version_counter;
      Object_ref_map.cardinal s.api_server.resources;
      Message.Pool.cardinal s.network.in_flight;
      b2i s.req_drop_enabled;
      b2i s.pod_monkey_enabled;
      Imap.cardinal s.controller_and_externals;
      ongoing_scheduled_sum s.controller_and_externals;
    ]

(* ---- §3.3 Counter-ceiling pruning (the P5 multi-step limits P2 does NOT
   enforce). The ceiling test inspects the successor STATE only, never the
   [Step.t] label, so no wildcard match on the 12-arm sum is needed.

   P8 (BUILD-SPEC-P8 §2.1) adds the [reconcile_ceiling] disjunct under the SAME
   drop-only pruning discipline as the uid/rv clauses: it only DROPS successors
   — it never merges distinct states (unlike a symmetry-reduction quotient, with
   its equivariance obligation, deliberately not taken) — so it is
   unconditionally sound. A dropped successor still surfaces as
   [report.pruned = true], and every [decisive] claim stays relative to the
   ceilings. Living in [over_ceiling], it flows through
   {!bounded_labelled_successors} / {!bounded_successors} into ALL exploration —
   P6's [Discharge.reach] included — clipping the (ceiling+1)-th reconcile
   pass. ---- *)

let max_reconcile_id (s : Cluster.cluster_state) : int =
  Imap.fold
    (fun _id (cae : Cluster.controller_and_external) acc ->
      Int.max acc
        (Controller.Reconcile_id_allocator.reconcile_count
           cae.controller.reconcile_id_allocator))
    s.controller_and_externals 0

let over_ceiling (bound : Bound.t) (s : Cluster.cluster_state) : bool =
  s.api_server.uid_counter > bound.uid_ceiling
  || s.api_server.resource_version_counter > bound.rv_ceiling
  || max_reconcile_id s > bound.reconcile_ceiling

let bounded_labelled_successors (bound : Bound.t) (cluster : Cluster.t)
    (s : Cluster.cluster_state) : (Step.t * Cluster.cluster_state) list =
  List.filter
    (fun (_step, s') -> not (over_ceiling bound s'))
    (Cluster.enabled_successors bound cluster s)

let bounded_successors (bound : Bound.t) (cluster : Cluster.t)
    (s : Cluster.cluster_state) : Cluster.cluster_state list =
  List.map snd (bounded_labelled_successors bound cluster s)

(* ---- Effective quiescence (BUG-2 fix): the liveness gate for {!check_esr}.

   [Scenario.is_quiescent] ([productive_successors = []]) is STRUCTURALLY
   UNREACHABLE on this scenario (the P4 §0 finding, carried into P5):
   [Schedule_controller_reconcile_step] is enabled whenever the CR is in etcd,
   and the CR is always in etcd, so [productive_successors] is never empty. Used
   as the [check_reaches] gate it evaluates the ESR target NOWHERE, so a clean
   [check_esr] is VACUOUS (it would pass for [fun _ -> false]).

   [effectively_quiescent] weakens "no productive successor" to "no STATE-CHANGING
   productive successor": every productive successor is [state_equal] to [s], so
   the only remaining moves are idempotent self-loops (e.g. re-scheduling a CR
   already scheduled with the same object — the reschedule self-loop). Under the
   §0.1 monotone-counter DAG this is the sound bounded-liveness notion of Done:
   the DAG terminates modulo the stutter/self-loop and [current_state_matches] is
   stable there, so "every reachable effectively-quiescent state matches" is the
   [leads_to] target reached.

   HONEST LIMIT (empirically established in-repo, [t_p5_cluster_check] /
   [t_p5_investigate]): on the ported vreplicaset scenario this predicate is
   ALSO structurally unreachable at every feasible {!Bound.t} — the reconcile is
   perpetually re-triggered (schedule -> run -> ... -> end churns the monotone
   [rpc_id] / [reconcile_id] allocators and keeps messages in flight, and after
   [end_reconcile] clears the scheduled entry the reschedule is NOT idempotent, it
   re-adds the CR). So every reachable state — including the goal-matching ones —
   still has a state-changing productive successor. {!check_esr} is therefore
   reported honestly as a VACUOUS universal; the non-vacuous liveness content that
   IS decidable here is goal-REACHABILITY ([current_state_matches] is reached
   within [depth]), which the tests witness by confirm-by-mutation on the bound.
   [effectively_quiescent] remains the correct definition and the general hook the
   day a counter-free settling state is modelled. *)

let effectively_quiescent (bound : Bound.t) (s : Cluster.cluster_state) : bool =
  List.for_all
    (fun (_step, s') -> state_equal s s')
    (Scenario.productive_successors Scenario.cluster bound s)

(* The VSTS sibling of {!effectively_quiescent}: the SAME unpruned "no
   state-changing productive successor" notion, but its productive successors are
   enumerated over {!Scenario.vsts_cluster} (the runnable VSTS registry +
   installed types), not the VRS {!Scenario.cluster}. Used by the honest VACUOUS
   companion {!check_esr_vsts}: on the perpetually re-triggered VSTS model this
   stays structurally unreachable at every feasible bound (the reschedule re-arms
   non-idempotently, exactly as for VRS — [effectively_quiescent]'s HONEST LIMIT),
   so its gate count is [Some 0]. The ceiling-pruned {!settled} is the non-vacuous
   VSTS gate ({!check_esr_settled_vsts}); this one exists only to make the
   settled-vs-unsettled contrast VISIBLE (P8 discipline). *)
let effectively_quiescent_vsts (bound : Bound.t) (s : Cluster.cluster_state) :
    bool =
  List.for_all
    (fun (_step, s') -> state_equal s s')
    (Scenario.productive_successors Scenario.vsts_cluster bound s)

(* ---- P8 settling gate (BUILD-SPEC-P8 §1): the reconcile-bounded refinement
   of {!effectively_quiescent}. Identical intent — no state-changing productive
   successor — but the productive successors are first filtered through
   [over_ceiling], exactly as {!bounded_labelled_successors} filters
   exploration, so a CEILING-PRUNED successor counts as NO successor. MEASURED
   MECHANISM (t_p8_settle test 4 pins it; the counter is allocated at RUN time,
   [run_scheduled_reconcile], NOT at schedule time): after the last admitted
   pass drains, the reschedule re-ARMS [scheduled_reconciles] one final time —
   a state change with the counter unchanged, so the drained un-armed [Done] is
   NOT settled; the settled state is that RE-ARMED one, whose only productive
   move (RUNNING the over-ceiling pass) is pruned. Under a [reconcile_ceiling]
   bound the gate is therefore reachable — unlike [effectively_quiescent],
   which stays vacuous on this scenario (its HONEST LIMIT above). CAVEAT: the
   filter applies ALL ceilings, so a bound whose uid/rv ceilings bite mid-pass
   can manufacture a starved non-matching "settled" state — see the .mli
   interpretation discipline for {!check_esr_settled}'s [Refuted]. The [cluster]
   parameter SELECTS which installed cluster's productive successors are
   enumerated: the VRS legs pass {!Scenario.cluster} (behaviour identical to the
   former [Scenario]-hardwired form), the VSTS legs pass {!Scenario.vsts_cluster}. *)

let settled (bound : Bound.t) (cluster : Cluster.t) (s : Cluster.cluster_state) :
    bool =
  List.for_all
    (fun (_step, s') -> state_equal s s')
    (List.filter
       (fun (_step, s') -> not (over_ceiling bound s'))
       (Scenario.productive_successors cluster bound s))

(* ---- Fairness filter for {!check_esr_temporal} (BUG-3 fix). A lasso whose loop
   is a pure stutter/self-loop (every loop state [state_equal] to the first) at a
   state that is NOT [effectively_quiescent] starves an enabled state-changing
   productive step forever, so it is NOT a fair run and NOT a valid ESR
   counterexample (arch §4: a fairness-antecedent property is not refuted by an
   unfair behaviour). Rejecting exactly these makes {!check_esr_temporal} agree
   with {!check_esr}: under the §0.1 DAG the only cycles are stutter self-loops,
   so once the unfair stutters are filtered no refuting lasso remains. The loop is
   nonempty by construction; read total via [Array.to_list]. *)

let fair_lasso (bound : Bound.t) (l : Cluster.cluster_state Model_check.lasso) :
    bool =
  match Array.to_list l.Model_check.loop with
  | [] -> true
  | s0 :: rest ->
      let pure_stutter = List.for_all (state_equal s0) rest in
      not (pure_stutter && not (effectively_quiescent bound s0))

(* The VSTS sibling of {!fair_lasso} (BUILD-SPEC-P11 §5 / §7). Same fairness
   notion — reject a pure-stutter loop that starves an enabled state-changing
   productive step — but the quiescence is decided by the ceiling-pruned {!settled}
   over {!Scenario.vsts_cluster}, NOT the VRS {!effectively_quiescent}. TWO reasons
   the productive successors are enumerated over the VSTS cluster AND pruned:

   (a) VSTS cluster, not VRS: the verbatim VRS [fair_lasso] enumerates productive
   successors over {!Scenario.cluster}, whose registry runs the VReplicaSet
   reconciler and whose installed types exclude the VSTS CR, so on a VStatefulSet
   state it finds NO productive successor, wrongly deems every VSTS stutter state
   quiescent, admits the seed-stutter lasso as a FAIR counterexample, and makes
   {!check_esr_temporal_vsts} spuriously [Refuted] (MEASURED). DOCUMENTED DEVIATION
   from the §5 prose, which named the reused [fair_lasso].

   (b) pruned {!settled}, not unpruned {!effectively_quiescent_vsts} (the P11 review
   NON-VACUITY fix): [effectively_quiescent_vsts] is structurally unreachable on the
   perpetually re-triggered model ([gate_states = Some 0]), so gating on it would
   deem EVERY pure-stutter lasso unfair — leaving NO fair lasso and a clean+decisive
   verdict INDEPENDENT of the goal (a tautology, clean even for [fun _ _ -> false]).
   Gating on {!settled} — reachable under the §7 [reconcile_ceiling = 1] bound
   ([gate_states = Some 1]) — admits a genuinely FAIR pure-stutter at the settled
   state, so {!check_esr_temporal_vsts} actually evaluates the ESR formula there:
   the real target is clean (the settled state matches) and a broken target flips it
   to [Refuted] ([t_p11_vsts_esr] "temporal_nonvacuous" pins both). Sound because
   under this bound the settling maxima stay STRICTLY below the ceilings, so no
   uid/rv-starved "settled" state exists (§7.3 caveat). *)
let fair_lasso_vsts (bound : Bound.t)
    (l : Cluster.cluster_state Model_check.lasso) : bool =
  match Array.to_list l.Model_check.loop with
  | [] -> true
  | s0 :: rest ->
      let pure_stutter = List.for_all (state_equal s0) rest in
      not (pure_stutter && not (settled bound Scenario.vsts_cluster s0))

(* ---- Finding-14 report metadata, computed soundly.

   The engine's [reachable] is opaque (no state access), so a local BFS mirror
   collects the achieved counter maxima and whether any ceiling fired. It uses
   the SAME seed, depth, [state_equal] / [state_hash] dedup, and self-loop
   suppression as {!Model_check.explore}, so it visits the same bounded
   reachable set — the maxima are the largest counters over that set and
   [pruned] is true iff some reachable expanded state had an enabled child that
   the ceilings dropped (BUILD-SPEC §3.4: "pruned = exists reachable s where
   enabled_successors produced a child exceeding a ceiling"). Threads the maxima
   through the fold rather than materialising the state list. *)

let collect_metadata ~depth ~(bound : Bound.t) ~(cluster : Cluster.t)
    ~(init : Cluster.cluster_state list) : int * int * bool =
  let visited : (int, Cluster.cluster_state list) Hashtbl.t =
    Hashtbl.create 1024
  in
  let seen (s : Cluster.cluster_state) =
    Hashtbl.find_opt visited (state_hash s)
    |> Option.map (List.exists (state_equal s))
    |> Option.value ~default:false
  in
  let mark (s : Cluster.cluster_state) =
    let h = state_hash s in
    Hashtbl.replace visited h
      (s :: Option.value ~default:[] (Hashtbl.find_opt visited h))
  in
  let umax (s : Cluster.cluster_state) m = Int.max m s.api_server.uid_counter in
  let vmax (s : Cluster.cluster_state) m =
    Int.max m s.api_server.resource_version_counter
  in
  let init_seed, mu0, mv0 =
    List.fold_left
      (fun (fr, mu, mv) s ->
        if seen s then (fr, mu, mv)
        else (
          mark s;
          (s :: fr, umax s mu, vmax s mv)))
      ([], 0, 0) init
  in
  let expand (s : Cluster.cluster_state) (fr, mu, mv, pruned) =
    List.fold_left
      (fun (fr, mu, mv, pruned) (_step, s') ->
        if over_ceiling bound s' then (fr, mu, mv, true)
        else if state_equal s s' then (fr, mu, mv, pruned)
        else if seen s' then (fr, mu, mv, pruned)
        else (
          mark s';
          (s' :: fr, umax s' mu, vmax s' mv, pruned)))
      (fr, mu, mv, pruned)
      (Cluster.enabled_successors bound cluster s)
  in
  let rec bfs frontier level mu mv pruned =
    match frontier with
    | [] -> (mu, mv, pruned)
    | _ :: _ ->
        if level >= depth then (mu, mv, pruned)
        else
          let fr', mu', mv', pruned' =
            List.fold_left
              (fun acc s -> expand s acc)
              ([], mu, mv, pruned) frontier
          in
          bfs (List.rev fr') (level + 1) mu' mv' pruned'
  in
  bfs (List.rev init_seed) 0 mu0 mv0 false

(* ---- §3.4 Report + entry points ---- *)

type report = {
  outcome : Cluster.cluster_state Model_check.outcome;
  bound : Bound.t;
  max_uid_seen : int;
  max_rv_seen : int;
  pruned : bool;
  violated : Invariants.invariant option;
  gate_states : int option;
}

(* The default exploration depth. 40 is comfortably above the reachability
   diameter of the vreplicaset scenario under {!Bound.default} (and the tighter
   bounds the tests use), so the frontier empties and [decisive = true] is
   achievable; the caller overrides it via [?depth]. It also subsumes
   [Bound.max_reconcile_depth] (a reconcile round is bounded by these steps). *)
let default_depth = 40

(* Which [always]-invariant broke at the counterexample: the head of the lasso
   loop is the bad state (BUILD-SPEC §0.1.1 / {!Model_check.check_safety}). No
   two-arm option match; the loop is nonempty by construction but read total. *)
let violated_of (invs : Invariants.invariant list)
    (outcome : Cluster.cluster_state Model_check.outcome) :
    Invariants.invariant option =
  match outcome with
  | Model_check.No_counterexample _ -> None
  | Model_check.Refuted { lasso; _ } ->
      Option.bind
        (match Array.to_list lasso.Model_check.loop with
        | [] -> None
        | s :: _ -> Some s)
        (fun s -> Invariants.first_violated invs s)

let check_always ?(depth = default_depth) (bound : Bound.t) ~desired : report =
  let cr = Scenario.vrs ~desired in
  let controller_id = Scenario.controller_id in
  let cluster = Scenario.cluster in
  let seed = Scenario.seed ~desired ~fair:false in
  let invs = Invariants.always ~cr ~controller_id in
  let inv = Invariants.conjunction invs in
  let successors = bounded_successors bound cluster in
  let reach =
    Model_check.explore ~depth ~successors ~equal:state_equal ~hash:state_hash
      ~init:[ seed ]
  in
  let outcome = Model_check.check_safety reach ~inv ~equal:state_equal in
  let max_uid_seen, max_rv_seen, pruned =
    collect_metadata ~depth ~bound ~cluster ~init:[ seed ]
  in
  {
    outcome;
    bound;
    max_uid_seen;
    max_rv_seen;
    pruned;
    violated = violated_of invs outcome;
    gate_states = None;
  }

let check_esr ?(depth = default_depth) (bound : Bound.t) ~desired : report =
  let cr = Scenario.vrs ~desired in
  let cluster = Scenario.cluster in
  let seed = Scenario.seed ~desired ~fair:true in
  let target = (Invariants.liveness_goal ~cr).holds in
  (* BUG-2 fix: gate on [effectively_quiescent], NOT [Scenario.is_quiescent]
     (structurally unreachable, so the old gate made [check_esr] vacuous). *)
  let quiescent = effectively_quiescent bound in
  let successors = bounded_successors bound cluster in
  let reach =
    Model_check.explore ~depth ~successors ~equal:state_equal ~hash:state_hash
      ~init:[ seed ]
  in
  let outcome = Model_check.check_reaches reach ~target ~quiescent ~equal:state_equal in
  let max_uid_seen, max_rv_seen, pruned =
    collect_metadata ~depth ~bound ~cluster ~init:[ seed ]
  in
  (* Fix C: surface the gate-state count so the vacuity is VISIBLE, not silent.
     [check_reaches] evaluates [target] only at states where [quiescent] holds;
     with 0 such states a clean outcome verifies NOTHING (it is clean for any
     target, even [fun _ -> false]).  [gate_states = Some 0] is the honest
     modeling gap (the reconcile never settles, see [effectively_quiescent]); the
     non-vacuous decidable liveness content is goal-reachability (the tests). *)
  let gate_states =
    Some (Model_check.count_states_where reach quiescent)
  in
  { outcome; bound; max_uid_seen; max_rv_seen; pruned; violated = None; gate_states }

(* P8 (BUILD-SPEC-P8 §3.2): the NON-VACUOUS companion of {!check_esr}. Same
   fair seed, target, exploration and metadata; the only change is the gate —
   {!settled} (the ceiling-pruned refinement) instead of
   [effectively_quiescent] — and [gate_states] counting the reachable settled
   states. Under a §4 settling bound the gate is reachable, so
   [gate_states = Some n] with [n > 0] and a clean outcome is a universal
   checked at real states, decisively and NON-vacuously.

   HONEST LIMIT: this witnesses a BOUNDED number of reconcile invocations
   settling to the match and staying there — never the perpetual re-reconcile,
   which the UNBOUNDED P7 executable spine witnesses operationally (its payoff);
   [decisive] remains verification only of the bounded system under these
   ceilings (arch §4). *)
let check_esr_settled ?(depth = default_depth) (bound : Bound.t) ~desired :
    report =
  let cr = Scenario.vrs ~desired in
  let cluster = Scenario.cluster in
  let seed = Scenario.seed ~desired ~fair:true in
  let target = (Invariants.liveness_goal ~cr).holds in
  let quiescent = settled bound Scenario.cluster in
  let successors = bounded_successors bound cluster in
  let reach =
    Model_check.explore ~depth ~successors ~equal:state_equal ~hash:state_hash
      ~init:[ seed ]
  in
  let outcome = Model_check.check_reaches reach ~target ~quiescent ~equal:state_equal in
  let max_uid_seen, max_rv_seen, pruned =
    collect_metadata ~depth ~bound ~cluster ~init:[ seed ]
  in
  (* The same visibility discipline as {!check_esr}'s Fix C, now with teeth:
     under a settling bound this count is POSITIVE, making non-vacuity — not
     just vacuity — visible in the report. *)
  let gate_states =
    Some (Model_check.count_states_where reach (settled bound Scenario.cluster))
  in
  { outcome; bound; max_uid_seen; max_rv_seen; pruned; violated = None; gate_states }

let check_esr_temporal ?(depth = default_depth) (bound : Bound.t) ~desired :
    report =
  let cr = Scenario.vrs ~desired in
  let cluster = Scenario.cluster in
  let seed = Scenario.seed ~desired ~fair:true in
  let module E = Esr.Make (Vreplica_set) in
  let goal =
    E.eventually_stable_reconciliation_per_cr ~cr
      ~current_state_matches:(fun cr' -> (Invariants.liveness_goal ~cr:cr').holds)
  in
  let successors = bounded_successors bound cluster in
  (* BUG-3 fix: pass the fairness filter so the always-enabled seed-stutter lasso
     (and any pure-stutter loop at a non-effectively-quiescent state) is NOT
     reported as an ESR counterexample. This makes the clean/refuted CLASS agree
     with {!check_esr} (a test asserts the agreement). *)
  let outcome =
    Model_check.check_temporal ~depth ~successors ~equal:state_equal
      ~init:[ seed ] ~fair:(fair_lasso bound) ~goal ()
  in
  let max_uid_seen, max_rv_seen, pruned =
    collect_metadata ~depth ~bound ~cluster ~init:[ seed ]
  in
  (* Same honest gate-state count as {!check_esr} (Fix C): [Some 0] flags the
     vacuous ESR universal on this model. *)
  let reach =
    Model_check.explore ~depth ~successors ~equal:state_equal ~hash:state_hash
      ~init:[ seed ]
  in
  let gate_states =
    Some (Model_check.count_states_where reach (effectively_quiescent bound))
  in
  { outcome; bound; max_uid_seen; max_rv_seen; pruned; violated = None; gate_states }

(* ---- BUILD-SPEC-P11 §5: the VStatefulSet checker entry points ----

   Structural mirrors of the four VRS [check_*] above, swapping the pinned
   scenario/invariants/resource-view for their VSTS siblings:
   [Scenario.vrs -> Scenario.vsts], [Scenario.cluster -> Scenario.vsts_cluster],
   [Scenario.seed -> Scenario.vsts_seed], [Invariants -> Vsts_invariants],
   [Esr.Make(Vreplica_set) -> Esr.Make(V_stateful_set)]. Every private helper
   ([collect_metadata], [fair_lasso], [over_ceiling] via [bounded_successors],
   [default_depth], [violated_of], [settled]) is reused unchanged — the generic
   BMC engine + the P6/P8 machinery genuinely GENERALIZE to a second controller.
   The four honest limits at the top of this module apply verbatim to the VSTS
   legs. *)

let check_always_vsts ?(depth = default_depth) (bound : Bound.t) ~desired : report
    =
  let cr = Scenario.vsts ~desired () in
  let controller_id = Scenario.controller_id in
  let cluster = Scenario.vsts_cluster in
  let seed = Scenario.vsts_seed ~desired ~fair:false in
  let invs = Vsts_invariants.always ~cr ~controller_id in
  let inv = Invariants.conjunction invs in
  let successors = bounded_successors bound cluster in
  let reach =
    Model_check.explore ~depth ~successors ~equal:state_equal ~hash:state_hash
      ~init:[ seed ]
  in
  let outcome = Model_check.check_safety reach ~inv ~equal:state_equal in
  let max_uid_seen, max_rv_seen, pruned =
    collect_metadata ~depth ~bound ~cluster ~init:[ seed ]
  in
  {
    outcome;
    bound;
    max_uid_seen;
    max_rv_seen;
    pruned;
    violated = violated_of invs outcome;
    gate_states = None;
  }

(* P11 §5: the NON-VACUOUS VSTS ESR leg — the VSTS sibling of
   {!check_esr_settled}. Fair seed, target = the {!Vsts_invariants.liveness_goal}
   ordinal-stable match, gate = the ceiling-pruned {!settled} over
   {!Scenario.vsts_cluster}, [gate_states] counting the reachable settled states.
   Under the §7 VSTS settling bound ([reconcile_ceiling = 1]) the gate is
   reachable iff the first reconcile pass reaches the match within the uid/rv
   ceilings; [gate_states = Some n], [n > 0], with a clean outcome is a universal
   checked at real states, decisively and NON-vacuously. The bound-artifact caveat
   (§7.3) applies: a [Refuted] is only meaningful where [max_uid_seen]/[max_rv_seen]
   stayed STRICTLY below their ceilings (a [t_p11_vsts_esr] test pins that the
   settling bound does). *)
let check_esr_settled_vsts ?(depth = default_depth) (bound : Bound.t) ~desired :
    report =
  let cr = Scenario.vsts ~desired () in
  let cluster = Scenario.vsts_cluster in
  let seed = Scenario.vsts_seed ~desired ~fair:true in
  let target = (Vsts_invariants.liveness_goal ~cr).holds in
  let quiescent = settled bound Scenario.vsts_cluster in
  let successors = bounded_successors bound cluster in
  let reach =
    Model_check.explore ~depth ~successors ~equal:state_equal ~hash:state_hash
      ~init:[ seed ]
  in
  let outcome =
    Model_check.check_reaches reach ~target ~quiescent ~equal:state_equal
  in
  let max_uid_seen, max_rv_seen, pruned =
    collect_metadata ~depth ~bound ~cluster ~init:[ seed ]
  in
  let gate_states =
    Some
      (Model_check.count_states_where reach (settled bound Scenario.vsts_cluster))
  in
  { outcome; bound; max_uid_seen; max_rv_seen; pruned; violated = None; gate_states }

(* P11 §5: the honest VACUOUS companion of {!check_esr_settled_vsts} — the VSTS
   sibling of {!check_esr}. Same fair seed and target, but gated on the UNPRUNED
   {!effectively_quiescent_vsts} (over {!Scenario.vsts_cluster}) instead of the
   ceiling-pruned {!settled}. On the perpetually re-triggered VSTS model this gate
   is structurally unreachable at every feasible bound (the reschedule re-arms
   non-idempotently), so [gate_states = Some 0]: a clean outcome verifies NOTHING
   (it is clean for [fun _ -> false]). Kept + cross-ref'd so the settled-vs-
   unsettled contrast is VISIBLE (P8 discipline), NOT to add a verdict. *)
let check_esr_vsts ?(depth = default_depth) (bound : Bound.t) ~desired : report =
  let cr = Scenario.vsts ~desired () in
  let cluster = Scenario.vsts_cluster in
  let seed = Scenario.vsts_seed ~desired ~fair:true in
  let target = (Vsts_invariants.liveness_goal ~cr).holds in
  let quiescent = effectively_quiescent_vsts bound in
  let successors = bounded_successors bound cluster in
  let reach =
    Model_check.explore ~depth ~successors ~equal:state_equal ~hash:state_hash
      ~init:[ seed ]
  in
  let outcome =
    Model_check.check_reaches reach ~target ~quiescent ~equal:state_equal
  in
  let max_uid_seen, max_rv_seen, pruned =
    collect_metadata ~depth ~bound ~cluster ~init:[ seed ]
  in
  let gate_states =
    Some (Model_check.count_states_where reach (effectively_quiescent_vsts bound))
  in
  { outcome; bound; max_uid_seen; max_rv_seen; pruned; violated = None; gate_states }

(* ---- BUILD-SPEC-P12 §4: the concurrent-reconcile uniqueness gate. ----

   De-vacuifies invariant #6 [every_ongoing_reconcile_has_unique_id]
   ({!Invariants.unique_reconcile_id_invariant}) — a SAFETY universal that the
   single-CR P11 seed never exercises (its [interesting] — ≥2 concurrent ongoing
   reconciles — fires nowhere, so the P11 pin measures 0, a TRUE-but-vacuous
   count). This is an ASSURANCE-CONSTRUCTION leg, NOT a model change: the P2
   transition system already represents ≥2 concurrent in-flight reconciles of ONE
   controller ([ongoing_reconciles] is keyed per cr [object_ref], the
   [run_scheduled_reconcile] precondition gates per-cr-key). The multi-CR seed
   ({!Scenario.vsts_seed_multi} / {!Scenario.seed_multi}) reaches
   [cardinal(ongoing) ≥ 2] so the universal is checked at genuinely-concurrent
   states, and [report.gate_states = Some n] counts them: [Some 0] ⟺ vacuous (the
   P11 single-CR case), [Some n>0] ⟺ genuinely exercised — the exact structural
   parallel to {!check_esr_settled_vsts}'s [settled] gate count (P8 discipline).

   The shared helper reuses the EXACT report-building machinery of the [check_*]
   gates above: {!bounded_successors} + {!Model_check.explore} for the reachable
   graph, {!Model_check.check_safety} to refute inv6's [holds] by reachability
   (arch §0.1.1: safety is reachability), and the SAME {!collect_metadata} fold
   for [max_uid_seen]/[max_rv_seen]/[pruned] that every other gate calls (no new
   fold). [gate_states] is {!Model_check.count_states_where} over inv6's
   [interesting] (≥2 concurrent). The [outcome] match is exhaustive over the two
   named {!Model_check.outcome} arms — no wildcard. *)

let check_unique_reconcile_id_from ~(depth : int) (bound : Bound.t)
    (cluster : Cluster.t) ~(seed : Cluster.cluster_state) ~(controller_id : int) :
    report =
  let inv = Invariants.unique_reconcile_id_invariant ~controller_id in
  let successors = bounded_successors bound cluster in
  let reach =
    Model_check.explore ~depth ~successors ~equal:state_equal ~hash:state_hash
      ~init:[ seed ]
  in
  let outcome =
    Model_check.check_safety reach ~inv:inv.holds ~equal:state_equal
  in
  let max_uid_seen, max_rv_seen, pruned =
    collect_metadata ~depth ~bound ~cluster ~init:[ seed ]
  in
  let gate_states =
    Some (Model_check.count_states_where reach inv.interesting)
  in
  let violated =
    match outcome with
    | Model_check.Refuted _ -> Some inv
    | Model_check.No_counterexample _ -> None
  in
  { outcome; bound; max_uid_seen; max_rv_seen; pruned; violated; gate_states }

let check_unique_reconcile_id_vsts ?(depth = default_depth) (bound : Bound.t)
    ~(desireds : int list) : report =
  check_unique_reconcile_id_from ~depth bound Scenario.vsts_cluster
    ~seed:(Scenario.vsts_seed_multi ~desireds ~fair:true)
    ~controller_id:Scenario.controller_id

let check_unique_reconcile_id_vrs ?(depth = default_depth) (bound : Bound.t)
    ~(desireds : int list) : report =
  check_unique_reconcile_id_from ~depth bound Scenario.cluster
    ~seed:(Scenario.seed_multi ~desireds ~fair:true)
    ~controller_id:Scenario.controller_id

(* P11 §5: the formula-faithful VSTS cross-check — the VSTS sibling of
   {!check_esr_temporal}. The goal is the actual {!Esr}-functor formula
   [Esr.Make(V_stateful_set).eventually_stable_reconciliation_per_cr] over the
   [?current_state_matches] target (default {!Vsts_invariants.current_state_matches};
   the label is a TEST-ONLY seam for the non-vacuity witness). Evaluated over
   enumerated lassos with the {!fair_lasso_vsts} fairness filter, which gates on the
   ceiling-pruned {!settled} (reachable) so the formula is GENUINELY evaluated at the
   settled state — see fair_lasso_vsts's note. NON-VACUOUS: a broken target flips
   this to [Refuted] ([t_p11_vsts_esr] "temporal_nonvacuous"). Its class + [decisive]
   flag AGREE with {!check_esr_settled_vsts} — a [t_p11_vsts_esr] test asserts the
   agreement on the real target; disagreement is a bug in one of them. *)
let check_esr_temporal_vsts ?(depth = default_depth)
    ?(current_state_matches = Vsts_invariants.current_state_matches)
    (bound : Bound.t) ~desired : report =
  let cr = Scenario.vsts ~desired () in
  let cluster = Scenario.vsts_cluster in
  let seed = Scenario.vsts_seed ~desired ~fair:true in
  let module E = Esr.Make (V_stateful_set) in
  let goal =
    E.eventually_stable_reconciliation_per_cr ~cr ~current_state_matches
  in
  let successors = bounded_successors bound cluster in
  let outcome =
    Model_check.check_temporal ~depth ~successors ~equal:state_equal
      ~init:[ seed ] ~fair:(fair_lasso_vsts bound) ~goal ()
  in
  let max_uid_seen, max_rv_seen, pruned =
    collect_metadata ~depth ~bound ~cluster ~init:[ seed ]
  in
  let reach =
    Model_check.explore ~depth ~successors ~equal:state_equal ~hash:state_hash
      ~init:[ seed ]
  in
  let gate_states =
    Some (Model_check.count_states_where reach (effectively_quiescent_vsts bound))
  in
  { outcome; bound; max_uid_seen; max_rv_seen; pruned; violated = None; gate_states }

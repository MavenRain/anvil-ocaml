(** The P5 cluster driver: wires the generic {!Model_check} engine to the
    vreplicaset {!Scenario} and the ported {!Invariants} / {!Esr}, with a sound
    {!Cluster.cluster_state} equality/hash, counter-ceiling pruning, and
    {!Bound.t} reporting (architecture §4 Leg 2, finding 14).

    Two assurance questions over the bounded reachable graph:
    - {!check_always}: does any reachable state violate a load-bearing SAFETY
      invariant ([Invariants.always])? (arch §0.1.1: reachability.)
    - {!check_esr}: from the fair seed, does every reachable QUIESCENT state
      satisfy [current_state_matches] (the ESR [leads_to] target)? (arch §0.1.3:
      the monotone-counter DAG + weak fairness make this the decidable form of
      bounded liveness.)

    Everything is falsification up to [depth] and {!Bound.t}; a clean run's
    [decisive] flag is verification only of the bounded system (arch §4). *)

val state_equal : Cluster.cluster_state -> Cluster.cluster_state -> bool
(** Sound structural equality on {!Cluster.cluster_state}: every field
    participates (a dropped counter would merge distinct states and could hide a
    counterexample). Composes the leaf equalities — [Object_ref_map.equal] /
    [Imap.equal] (equal keys + equal values), [Dynamic_object.equal],
    [Message.equal] / {!Message.Pool} order-insensitive [Multiset.equal],
    [Value.equal], and the allocator [equal]s. No polymorphic [Stdlib.(=)] (it
    diverges on the closures in [installed_types] and is order-sensitive on
    maps/bags). *)

val state_hash : Cluster.cluster_state -> int
(** A SOUND bucket hash for the visited set: [state_equal a b ==> state_hash a =
    state_hash b] (arch §3.2). Folds only order-insensitive structural summaries
    (the counters, map/bag cardinalities, the two bools) — NEVER [Hashtbl.hash]
    on the raw record (map tree shape / physical [Value.t] identity would give
    equal states different hashes and break visited-set termination). Too coarse
    only costs collisions; unsound would break termination, so this is
    conservative by construction. *)

val max_reconcile_id : Cluster.cluster_state -> int
(** The largest per-controller reconcile counter in [s] — [Int.max]-fold of
    [Controller.Reconcile_id_allocator.reconcile_count] over
    [controller_and_externals], base [0] — i.e. the number of reconcile
    INVOCATIONS the busiest controller has started. Feeds the P8
    [Bound.reconcile_ceiling] clause of the successor-ceiling filter under the
    same drop-only pruning discipline as the uid/rv clauses (BUILD-SPEC-P8
    §2.1: dropping never merges distinct states, so it is unconditionally
    sound). *)

val bounded_successors :
  Bound.t -> Cluster.t -> Cluster.cluster_state -> Cluster.cluster_state list
(** {!Cluster.enabled_successors} (P2 single-step bounds) with the multi-step
    ceilings applied: drop any successor whose [api_server.uid_counter >
    uid_ceiling], [resource_version_counter > rv_ceiling] (arch §0.1.2 — P2 does
    NOT enforce these; [bound.mli] reserves them for P5), or (P8)
    {!max_reconcile_id}[ > reconcile_ceiling]. [max_reconcile_depth] is
    subsumed by the exploration [depth]. Drops the {!Step.t} label; see
    {!bounded_labelled_successors} for traces. *)

val bounded_labelled_successors :
  Bound.t ->
  Cluster.t ->
  Cluster.cluster_state ->
  (Step.t * Cluster.cluster_state) list
(** As {!bounded_successors} but keeping the {!Step.t} that produced each
    successor, for reporting the step sequence a counterexample took (the
    {!Step.t} match in the ceiling filter is fully enumerated, no wildcard). *)

val effectively_quiescent : Bound.t -> Cluster.cluster_state -> bool
(** The liveness gate for {!check_esr} (the BUG-2 fix). [true] iff every
    {!Scenario.productive_successors} of [s] is {!state_equal} to [s] — i.e. no
    STATE-CHANGING productive step is enabled, only idempotent self-loops (the
    reschedule of an already-scheduled CR). This is the sound bounded form of
    "Done" under the arch §0.1 monotone-counter DAG (which terminates modulo the
    stutter/self-loop, at which [current_state_matches] is stable), and it
    replaces {!Scenario.is_quiescent} — which is STRUCTURALLY UNREACHABLE
    ([Schedule_controller_reconcile] is always enabled while the CR is in etcd,
    so [productive_successors] is never [[]]), and as the [check_reaches] gate
    evaluated the ESR target nowhere, making a clean {!check_esr} vacuous.

    HONEST LIMIT (empirical, [t_p5_cluster_check] / [t_p5_investigate]): on the
    ported vreplicaset scenario this predicate is ALSO structurally unreachable at
    every feasible {!Bound.t} — the reconcile is perpetually re-triggered
    (schedule -> run -> ... -> end advances the monotone [rpc_id] / [reconcile_id]
    allocators and keeps messages in flight, and after [end_reconcile] clears the
    scheduled entry the reschedule re-adds the CR and is NOT idempotent), so every
    reachable state, goal-matching ones included, still has a state-changing
    productive successor. {!check_esr}'s clean verdict is therefore an HONEST
    VACUOUS universal; the non-vacuous, decidable liveness content is
    goal-REACHABILITY ([current_state_matches] is reached within [depth]), which
    the tests witness by confirm-by-mutation on the bound. [effectively_quiescent]
    is nonetheless the correct definition and the general hook for a future
    counter-free settling state. *)

val settled : Bound.t -> Cluster.t -> Cluster.cluster_state -> bool
(** The reconcile-bounded refinement of {!effectively_quiescent} (P8,
    BUILD-SPEC-P8 §1): identical intent — no state-changing productive
    successor — but the {!Scenario.productive_successors} are first filtered
    through the successor ceilings (the {!max_reconcile_id} clause included),
    so a CEILING-PRUNED successor counts as NO successor. MEASURED MECHANISM
    (t_p8_settle test 4 pins it; the reconcile counter is allocated at RUN
    time, [run_scheduled_reconcile], NOT at schedule time): after the last
    admitted pass drains, the reschedule re-ARMS [scheduled_reconciles] one
    final time — a state change with the counter unchanged, so the drained
    un-armed [Done] is NOT settled; the settled state is that RE-ARMED one,
    whose only productive move (RUNNING the over-ceiling pass) is pruned.
    Under a [reconcile_ceiling] bound the gate is therefore reachable — unlike
    {!effectively_quiescent}, which stays vacuous.

    CAVEAT (review finding, latent): the filter applies ALL ceilings, so under
    a bound whose [uid_ceiling]/[rv_ceiling] bite mid-pass, a starved
    NON-matching mid-pass state (every productive successor over the uid/rv
    ceiling) also satisfies [settled], and a {!check_esr_settled} [Refuted]
    there is a bound ARTIFACT, not an ESR violation of the bounded system.
    Interpret a [Refuted] only under bounds where [max_uid_seen] /
    [max_rv_seen] stay STRICTLY below their ceilings (the BUILD-SPEC-P8 §4
    settling bounds do; t_p8_settle test 2 pins it). The [Cluster.t] parameter
    SELECTS which installed cluster's {!Scenario.productive_successors} are
    enumerated: the VRS legs pass {!Scenario.cluster}, the VSTS legs
    {!Scenario.vsts_cluster}. *)

type report = {
  outcome : Cluster.cluster_state Model_check.outcome;
      (** The engine verdict: [Refuted] with a real counterexample lasso, or
          [No_counterexample {decisive}]. *)
  bound : Bound.t;  (** The bounds this run used (for the achieved-vs-cap report). *)
  max_uid_seen : int;
      (** The largest [uid_counter] observed across the reachable graph — report
          against [bound.uid_ceiling] (arch finding 14: achieved bound). *)
  max_rv_seen : int;
      (** The largest [resource_version_counter] observed — against
          [bound.rv_ceiling]. *)
  pruned : bool;
      (** Whether a ceiling ever fired (a successor was dropped). If [true], the
          graph is NOT fully explored at these ceilings and any [decisive] claim
          is relative to them. *)
  violated : Invariants.invariant option;
      (** For {!check_always}: which invariant broke at the counterexample state
          ([Invariants.first_violated]); [None] on a clean run. *)
  gate_states : int option;
      (** For {!check_esr} / {!check_esr_temporal}: [Some n], [n] = the number of
          reachable states satisfying the {!effectively_quiescent} gate; for
          {!check_esr_settled} (P8) the gate is {!settled} instead. [Some 0]
          means the ESR universal is VACUOUS — the target was evaluated at NO
          state, so a clean outcome verifies nothing and must be read as the
          honest modeling gap (the reconcile never settles under these bounds),
          NOT as "ESR holds"; the decidable non-vacuous liveness content is
          goal-reachability. [None] for {!check_always} (not applicable). *)
}
(** The outcome plus the finding-14 non-vacuity metadata: the achieved counter
    bounds against the caps, whether pruning fired, (safety) the named broken
    invariant, and (liveness) the {!gate_states} count that makes a vacuous ESR
    universal visible. *)

val check_always : ?depth:int -> Bound.t -> desired:int -> report
(** SAFETY leg. Seed [Scenario.seed ~desired ~fair:false] (full nondeterminism —
    crash / req_drop / pod_monkey enabled), invariant [Invariants.conjunction
    (Invariants.always ~cr ~controller_id)] where [cr = Scenario.vrs ~desired].
    Explores {!bounded_successors} and refutes by reachability
    ({!Model_check.check_safety}); on [Refuted], [violated] names the broken
    invariant. Only the [always] bucket — the [eventually_always] invariants hold
    only on the fair suffix, so asserting them per-step is unsound (the P4
    Finding-A misclassification). [depth] defaults to a value that fixpoints the
    default scenario. *)

val check_esr : ?depth:int -> Bound.t -> desired:int -> report
(** ESR / bounded-liveness leg. Seed [Scenario.seed ~desired ~fair:true]
    (disruptors off = the fair suffix Anvil's leads_to assumes), [target =
    (Invariants.liveness_goal ~cr).holds] (#11 [current_state_matches]),
    [quiescent = ]{!effectively_quiescent}[ bound] (the BUG-2 fix; NOT
    {!Scenario.is_quiescent}, which is structurally unreachable). Refutes "every
    reachable effectively-quiescent state matches" ({!Model_check.check_reaches}).
    The report's {!report.gate_states} makes the verdict's meaning explicit: with
    [gate_states = Some n] and [n > 0] a clean run means ESR holds up to the
    bounds and [Refuted] exhibits a fair run that settles off-goal; with
    [gate_states = Some 0] the clean run is a VACUOUS universal (no gate state to
    check) and verifies nothing about ESR. See {!effectively_quiescent} for the
    HONEST LIMIT: on this vreplicaset model the gate is empirically unreachable
    ([gate_states = Some 0] at every feasible bound), so the clean verdict is
    vacuous and the non-vacuous decidable liveness content is goal-reachability.
    {!check_esr_settled} is the NON-VACUOUS companion: gated on {!settled}
    instead, its gate is reachable under a P8 settling bound and the same
    universal is checked at [n > 0] real states. *)

val check_esr_settled : ?depth:int -> Bound.t -> desired:int -> report
(** The NON-VACUOUS companion of {!check_esr} (P8, BUILD-SPEC-P8 §3.2): same
    fair seed, target and exploration, but gated on {!settled} — the
    reconcile-bounded refinement of {!effectively_quiescent} — with
    {!report.gate_states} counting the reachable settled states. Under a
    settling bound (BUILD-SPEC-P8 §4: [reconcile_ceiling] low,
    [uid_ceiling]/[rv_ceiling] high enough to reach [Done] in one pass) the
    gate is reachable, so [gate_states = Some n] with [n > 0] and a clean
    outcome is decisive NON-vacuously: every reachable settled state satisfies
    [current_state_matches].

    HONEST LIMIT: this witnesses a BOUNDED number of reconcile invocations
    settling to the match and staying there — never the perpetual
    re-reconcile, which is witnessed operationally by the P7 executable spine
    (its unbounded [controller_runtime] run is exactly that payoff). [decisive]
    remains verification only of the bounded system under these ceilings (arch
    §4), never Anvil's Verus theorem. *)

val check_esr_temporal : ?depth:int -> Bound.t -> desired:int -> report
(** The formula-faithful cross-check of {!check_esr}. Builds the ESR
    {!Comp_cat.Temporal.t} goal via {!Esr.Make}[(Vreplica_set)
    .eventually_stable_reconciliation_per_cr ~cr ~current_state_matches] with
    [current_state_matches cr = Comp_cat.Temporal.lift_state
    (Invariants.liveness_goal ~cr).holds], and evaluates it over enumerated
    lassos ({!Model_check.check_temporal}), passing the {!fair_lasso} filter so
    the always-enabled unfair stutter self-loop is not a false counterexample.
    Its verdict must AGREE with {!check_esr} on the same bounds — both the
    clean/refuted CLASS and the [decisive] flag (a test asserts both; the
    fair-ignore of Fix D is what makes [decisive] agree rather than being zeroed
    by the unfair stutter). The decision procedure and the P0 temporal evaluator
    cross-validate. *)

(* ---- BUILD-SPEC-P11 §5: the VStatefulSet checker entry points. Structural
   mirrors of the four VRS legs above, pinning the VSTS scenario / invariants /
   resource-view; every helper is shared, demonstrating the BMC + P6/P8 machinery
   generalizes past the first controller. All four honest limits documented above
   apply verbatim. ---- *)

val check_always_vsts : ?depth:int -> Bound.t -> desired:int -> report
(** VSTS SAFETY leg — the {!check_always} sibling. Seed
    [Scenario.vsts_seed ~desired ~fair:false] (full nondeterminism), invariant
    [Invariants.conjunction (Vsts_invariants.always ~cr ~controller_id)] where
    [cr = Scenario.vsts ~desired ()], explored over {!Scenario.vsts_cluster}
    ({!Model_check.check_safety}); on [Refuted], [violated] names the broken VSTS
    invariant. Only the [always] bucket (widened inv9 + ordinal-identity +
    PVC-ownership). *)

val check_esr_settled_vsts : ?depth:int -> Bound.t -> desired:int -> report
(** VSTS NON-VACUOUS ESR leg — the {!check_esr_settled} sibling. Seed
    [Scenario.vsts_seed ~desired ~fair:true], [target =
    (Vsts_invariants.liveness_goal ~cr).holds] (the ordinal-stable
    {!Vsts_invariants.current_state_matches}), gate [= ]{!settled}[ bound
    Scenario.vsts_cluster], with {!report.gate_states} counting the reachable
    settled states. Under the §7 VSTS settling bound ([reconcile_ceiling = 1],
    uid/rv ceilings high enough to reach the first-pass create) the gate is
    reachable, so [gate_states = Some n], [n > 0], and a clean outcome verifies
    "every reachable settled state matches" decisively and NON-vacuously.

    BOUND-ARTIFACT DISCIPLINE (§7.3): {!settled} filters through the full
    {!over_ceiling}, so a bound whose uid/rv ceilings bite mid-pass manufactures
    a starved non-matching "settled" state and a spurious [Refuted]. Interpret a
    [Refuted] ONLY where [max_uid_seen]/[max_rv_seen] stay STRICTLY below their
    ceilings (a {!check_esr_settled}-style [t_p11_vsts_esr] test pins that the
    settling bound does). HONEST LIMIT: witnesses a BOUNDED number of reconcile
    invocations settling to the match, never the perpetual re-reconcile; if the
    tail is empirically vacuous at every feasible bound ([gate_states = Some 0]
    with maxima strictly below ceilings), that is DISCLOSED via a measured
    0-count witness, not tuned away (the P6 tail precedent). *)

val check_esr_vsts : ?depth:int -> Bound.t -> desired:int -> report
(** The honest VACUOUS companion of {!check_esr_settled_vsts} — the
    {!check_esr} sibling. Same fair seed and target, but gated on the UNPRUNED
    {!effectively_quiescent_vsts} (quiescence enumerated over
    {!Scenario.vsts_cluster}) instead of the ceiling-pruned {!settled}. On the
    perpetually re-triggered VSTS model this gate is structurally unreachable at
    every feasible bound, so [gate_states = Some 0] and a clean run is a VACUOUS
    universal (the target is evaluated at NO state). Kept + cross-ref'd so the
    settled-vs-unsettled contrast is VISIBLE (P8 discipline), NOT to add a
    verdict. *)

val check_esr_temporal_vsts :
  ?depth:int ->
  ?current_state_matches:(V_stateful_set.t -> Cluster.cluster_state -> bool) ->
  Bound.t ->
  desired:int ->
  report
(** The formula-faithful VSTS cross-check — the {!check_esr_temporal} sibling.
    Builds the ESR {!Comp_cat.Temporal.t} goal via
    {!Esr.Make}[(V_stateful_set).eventually_stable_reconciliation_per_cr ~cr
    ~current_state_matches] (default [current_state_matches =
    Vsts_invariants.current_state_matches]) and evaluates it over enumerated
    lassos ({!Model_check.check_temporal}) with the VSTS fairness filter
    {!fair_lasso_vsts}.

    NON-VACUITY (the P11 review fix): [fair_lasso_vsts] admits a pure-stutter loop
    ONLY at a state that is {!settled} over {!Scenario.vsts_cluster} — the
    ceiling-pruned P8 quiescence, which under the §7 settling bound IS reachable
    ([gate_states = Some 1]). So the reachable settled state supplies a genuinely
    FAIR stutter behaviour and the ESR formula is actually evaluated there: a
    broken target ([current_state_matches = fun _ _ -> false]) flips this to
    [Refuted] (pinned by [t_p11_vsts_esr]), so the clean/decisive verdict on the
    real target is CORROBORATION, not a tautology. (Gating instead on the UNPRUNED
    {!effectively_quiescent_vsts} — [Some 0], structurally unreachable — would make
    every stutter unfair and the verdict goal-independent, the vacuity the
    {!check_esr_vsts} companion carries; that is why the filter uses the pruned
    {!settled}. DOCUMENTED DEVIATION from the §5 prose, which named the verbatim VRS
    {!fair_lasso}: that helper decides quiescence over {!Scenario.cluster}, whose
    registry excludes the VSTS CR, so it mis-deems VSTS states quiescent and
    spuriously refutes — MEASURED.)

    Its verdict AGREES with {!check_esr_settled_vsts} — both the clean/refuted CLASS
    and the [decisive] flag (a [t_p11_vsts_esr] test asserts both, on the real target
    and under the broken-target witness). The optional [?current_state_matches] is a
    TEST-ONLY seam for that non-vacuity witness; production callers omit it. The §7.3
    bound-artifact caveat applies as for {!check_esr_settled_vsts}: interpret a
    [Refuted] only where [max_uid_seen]/[max_rv_seen] stayed strictly below their
    ceilings. *)

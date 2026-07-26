(** BUILD-SPEC-P13: fault-tolerant assurance over a fault-BUDGETED product
    transition system.

    Anvil's twelve cluster steps (the [Step] enum, cluster.rs:75, ported at
    [lib/cluster/step.ml:11-47]) include the adversaries:
    [RestartControllerStep] (the crash/restart model, cluster.rs:377),
    [DropReqStep] (a transient api-server failure, cluster.rs:439) and
    [PodMonkeyStep] (cluster.rs:492), plus the three fault DISABLERS
    [DisableCrashStep] / [DisableReqDropStep] / [DisablePodMonkeyStep]
    (cluster.rs:407, :472, :526). {!Cluster.enabled_successors} already
    enumerates every one of them, so the fault surface is fully PORTED. What was
    missing before P13 is any DECISIVE verdict in which those edges do
    load-bearing work: every decisive gate in {!Cluster_check} seeds
    [~fair:true], i.e. all three disruptor flags OFF, and the only faults-ON legs
    ({!Cluster_check.check_always} / [check_always_vsts]) are NON-decisive
    because the faults-ON graph does not close. P12's headline witness is
    therefore a FAULT-FREE witness. This module supplies the missing dimension.
    It is pure ASSURANCE CONSTRUCTION: [lib/cluster/] is not modified, and no
    invariant is weakened.

    {b Why the budget is NOT a {!Bound.t} field (BUILD-SPEC-P13 section 2).}
    {!Model_check.explore} takes [successors : 'a -> 'a list], a function of the
    STATE alone, and {!Bound.t} correspondingly bounds the per-STATE successor
    ENUMERATION (in-flight messages, objects per kind, uid / rv / reconcile
    ceilings). A fault allowance is a per-PATH quantity: it must remember how
    many crash edges the run has already taken, which no state-indexed successor
    function can recover from a bare {!Cluster.cluster_state}. So instead of
    extending {!Bound.t} (which would also break twelve explicit record literals
    across the suite for no gain), P13 checks the PRODUCT system whose state
    carries the counters: {!faulted}. Two consequences, both load-bearing:

    - {b Decisiveness.} Clipping the fault edges at a {!budget} makes the
      faults-ON reachable set finite, so the frontier can empty and the verdict
      can be decisive where [check_always_vsts ~fair:false] could only ever
      report non-decisive. The honest reading becomes "falsification up to
      (depth, {!Bound.t}, {!budget})": one more DISCLOSED dimension, and strictly
      more than the zero faults checked before P13.
    - {b The counters ARE the path witness.} Non-vacuity of the kind "this state
      was reached AFTER a real crash" is the plain STATE predicate
      [crashes >= 1] on the product, so nothing here needs edge-labelled
      exploration or trace post-processing, and none is provided.

    {b Reachability / soundness (BUILD-SPEC-P13 section 3).} {!Cluster.init}
    (cluster.rs:110, [lib/cluster/cluster.ml:75-97]) REQUIRES all three fault
    flags TRUE, so a seed with any flag [false] is not an init state. Exploring
    from such a seed is still SOUND, because every flag combination
    componentwise [<= (true, true, true)] is reachable from an init state by a
    prefix of [Step.Disable_crash_step] / [Step.Disable_req_drop_step] /
    [Step.Disable_pod_monkey_step], each of which flips only its own flag
    (cluster.rs:407, :472, :526 = [lib/cluster/cluster.ml:337], [:385],
    [:445]). A safety violation found from such a seed is therefore a genuine
    violation of a REACHABLE behaviour, and a clean verdict is
    falsification-up-to-bounds of the SUFFIX behaviours starting there. The
    pre-existing [~fair:true] seeds already rest on exactly this argument (they
    are the all-disabled suffix). The full write-up, including the MEASURED
    correction to the spec's claim that the all-faults-ON seed satisfies
    {!Cluster.init} outright (it satisfies every fault-flag conjunct, but not the
    empty-etcd conjunct of [Api_server.init]), lives on
    {!Scenario.vsts_seed_faults} and is not re-derived here.

    {b Honest limits (BUILD-SPEC-P13 section 8).} Everything here is bounded
    falsification up to [depth], {!Bound.t} and {!budget}; it transfers no part
    of Anvil's Verus theorem. The budget is a NEW disclosed dimension: a defect
    that needs more than [max_crashes] crashes (or more drops, or more monkey
    ops) on a single path is excluded BY CONSTRUCTION, not shown absent. And
    {!Cluster_check.settled} treats [Step.Pod_monkey_step] as PRODUCTIVE
    ([Scenario.productive_successors], [lib/assurance/scenario.ml:660-679]), so a
    state can only be [settled] once the monkey is disabled or has no enabled
    op. *)

type budget = {
  max_crashes : int;
      (** Cap on [Step.Restart_controller_step] edges taken on ONE path (Anvil
          [RestartControllerStep], cluster.rs:377). *)
  max_drops : int;
      (** Cap on [Step.Drop_req_step] edges on one path (Anvil [DropReqStep],
          cluster.rs:439). *)
  max_monkey_ops : int;
      (** Cap on [Step.Pod_monkey_step] edges on one path (Anvil
          [PodMonkeyStep], cluster.rs:492). *)
}
(** The per-PATH fault allowance: how many of each adversarial edge a single run
    may take. Deliberately its OWN type rather than three more {!Bound.t} fields,
    for the reason in the module header (a path quantity cannot live in a
    per-state enumeration bound). Zero in a dimension switches that adversary off
    while leaving its [Step.t] arm enumerated, which is what makes the M4 budget
    pin (BUILD-SPEC-P13 section 6) a real check rather than a tautology. *)

val budget_default : budget
(** [{ max_crashes = 1; max_drops = 1; max_monkey_ops = 1 }]: one of each fault
    per path, the all-three-adversaries-live budget used by the settling leg. *)

val budget_crash_only : budget
(** [{ max_crashes = 1; max_drops = 0; max_monkey_ops = 0 }]: ISOLATES the crash
    dimension (Anvil [RestartControllerStep], cluster.rs:377) by budgeting the
    other two adversaries to zero. Used by the safety legs so that a refutation
    is attributable to the crash and the graph stays small enough to be
    decisive. *)

type faulted = {
  cs : Cluster.cluster_state;  (** The ported cluster state, unchanged. *)
  crashes : int;
      (** [Step.Restart_controller_step] edges taken on the path to this state
          (cluster.rs:377). *)
  drops : int;  (** [Step.Drop_req_step] edges taken (cluster.rs:439). *)
  monkeys : int;  (** [Step.Pod_monkey_step] edges taken (cluster.rs:492). *)
}
(** A state of the PRODUCT transition system: a {!Cluster.cluster_state} paired
    with the three path-local fault counters. Plain readable fields, following
    the {!Cluster_check.report} precedent. The counters are monotone along every
    path, so the product graph is the cluster graph stratified by fault epoch:
    the [crashes >= 1] slice is exactly the post-crash reachable set, which is
    how the fault legs state their non-vacuity without edge labels. *)

val faulted_of_seed : Cluster.cluster_state -> faulted
(** Lift a seed into the product with all three counters at [0]: the run has not
    yet taken any fault edge. The only intended way to build the [init] list for
    {!Model_check.explore} over {!faulted}. *)

val faulted_equal : faulted -> faulted -> bool
(** Sound structural equality on the product: {!Cluster_check.state_equal} on the
    cluster component AND equality of all three counters. Distinguishing the
    counters is what keeps a pre-crash state and its structurally identical
    post-crash twin APART, so the [crashes >= 1] witness slice cannot be merged
    away; dropping them would be the classic unsound quotient. Compares the three
    [int]s first, so the expensive structural comparison runs only on same-epoch
    pairs. *)

val faulted_hash : faulted -> int
(** A SOUND bucket hash for the visited set:
    [faulted_equal a b ==> faulted_hash a = faulted_hash b]. Mixes
    {!Cluster_check.state_hash} (itself sound by the same contract) with the
    three counters through [Hashtbl.hash] on a fixed-order list of [int]s, which
    is values-only and order-fixed, never [Hashtbl.hash] on the raw record (the
    record holds map trees and closures, whose physical shape would split equal
    states and break visited-set termination). Too coarse only costs collisions.
    *)

val faulted_successors : Bound.t -> budget -> Cluster.t -> faulted -> faulted list
(** The product transition relation. Maps each [(step, cs')] of
    {!Cluster_check.bounded_labelled_successors}[ bound cluster f.cs] (so every
    {!Bound.t} ceiling still applies exactly as in the fault-free legs) to a
    {!faulted}, classifying the step with an EXHAUSTIVE twelve-arm [Step.t] match
    that copies the constructor spelling and arm order of the
    [Scenario.productive_successors] match ([lib/assurance/scenario.ml:660-679]).
    There is no [_ ->] arm, so a thirteenth Anvil step would be a COMPILE error
    here rather than a silently uncharged fault. The classification:

    - [Step.Restart_controller_step _] (cluster.rs:377) charges [crashes + 1];
    - [Step.Drop_req_step _] (cluster.rs:439) charges [drops + 1];
    - [Step.Pod_monkey_step _] (cluster.rs:492) charges [monkeys + 1];
    - the other NINE arms ([Api_server_step], [Builtin_controllers_step],
      [Controller_step], [Schedule_controller_reconcile_step], [External_step],
      [Disable_crash_step], [Disable_req_drop_step], [Disable_pod_monkey_step],
      [Stutter_step]) leave all three counters UNCHANGED.

    A successor whose charged counter would EXCEED its cap is DROPPED. This is
    drop-only pruning, the same discipline as the {!Bound.t} ceilings
    (BUILD-SPEC-P8 section 2.1): it never merges two distinct states, it only
    truncates the graph, so it is unconditionally sound and its effect is
    reported rather than hidden.

    The three [Disable_*] steps are fault-DISABLING, not faults: they must never
    consume budget. Charging them would make the settling target (all three
    flags [false]) unreachable at any budget, i.e. it would silently vacuify the
    settling leg rather than fail it. *)

type fault_report = {
  outcome : faulted Model_check.outcome;
      (** The engine verdict over the PRODUCT graph: [Refuted] with a real
          counterexample lasso of {!faulted} states, or
          [No_counterexample {decisive}] where [decisive] now means exhaustive up
          to [depth], {!Bound.t} AND {!budget}. *)
  bound : Bound.t;  (** The {!Bound.t} this run used (achieved-vs-cap report). *)
  budget : budget;
      (** The {!budget} this run used: the third disclosed dimension, reported so
          a clean verdict can never be read as unconditional. *)
  max_uid_seen : int;
      (** Largest [api_server.uid_counter] over the reachable product set,
          against [bound.uid_ceiling]. *)
  max_rv_seen : int;
      (** Largest [api_server.resource_version_counter] observed, against
          [bound.rv_ceiling]. *)
  max_crashes_seen : int;
      (** Largest {!faulted.crashes} observed, against [budget.max_crashes]: the
          achieved crash depth. [0] with a nonzero cap means the crash edge was
          never taken and any crash claim is VACUOUS. *)
  max_drops_seen : int;
      (** Largest {!faulted.drops} observed, against [budget.max_drops]. *)
  max_monkeys_seen : int;
      (** Largest {!faulted.monkeys} observed, against
          [budget.max_monkey_ops]. *)
  pruned_by_ceiling : bool;
      (** A {!Bound.t} ceiling dropped some enabled successor of a visited state
          ([Cluster.enabled_successors] produced strictly more children than
          {!Cluster_check.bounded_labelled_successors} admitted). If [true] the
          graph is not fully explored at these ceilings. *)
  pruned_by_budget : bool;
      (** A {!budget} cap dropped some labelled successor of a visited state.
          [true] is the honest signature of the new dimension biting: paths with
          one more fault than the cap exist in the model and were NOT explored.
          *)
  violated : Invariants.invariant option;
      (** For the safety legs: which {!Invariants.invariant} broke at the
          counterexample state ([Invariants.first_violated]); [None] on a clean
          run. *)
  gate_states : int option;
      (** The leg's non-vacuity gate count: [Some n] where [n] is the number of
          reachable product states at which the checked property is genuinely
          exercised (per leg: an interesting state that is also post-crash, or a
          settling state). [Some 0] means the universal was evaluated NOWHERE, so
          a clean outcome verifies nothing and must be reported as a modeling gap
          rather than as a pass
          ([[feedback-workflow-zero-findings-may-be-vacuous]]). [None] where the
          leg defines no gate. *)
  crash_witness_states : int;
      (** Reachable product states with [crashes >= 1]: the post-crash slice. The
          primary vacuity detector for every crash leg (M3 / M4 of
          BUILD-SPEC-P13 section 6 pin it to [0] when the crash flag or the crash
          budget is off). *)
  fault_free_states : int;
      (** Reachable product states with all three counters [0]. The CONTRAST
          partner of {!crash_witness_states}: both nonzero means the graph really
          straddles the fault boundary rather than sitting on one side of it. *)
  settled_with_faults_live : int;
      (** Reachable product states that are {!Cluster_check.settled} while at
          least one fault flag is still TRUE (crash flag read off the
          [controller_and_externals] entry of the leg's controller id,
          [req_drop_enabled] / [pod_monkey_enabled] read off the state). The
          settling leg's honest contrast: since {!Cluster_check.settled} counts
          [Step.Pod_monkey_step] as productive, a state with the monkey still
          live can be [settled] only when the monkey has no enabled op, so this
          count measures how much of the settling evidence does NOT depend on the
          [Disable_*] prefix. MEASURED and pinned by the tests, never predicted.
          *)
}
(** The verdict plus the finding-14 non-vacuity metadata, extended for the fault
    dimension: the achieved counter maxima against their caps, the achieved fault
    depths against the {!budget}, BOTH pruning flags separated (ceiling versus
    budget, so the reader can tell which dimension bit), the named broken
    invariant, and the three fault-slice counts that make a vacuous crash claim
    impossible to state as a pass. Plain readable fields, following the
    {!Cluster_check.report} precedent. *)

val check_invariants_under_faults :
  ?depth:int -> Bound.t -> budget -> desired:int -> fault_report
(** {b G1} (BUILD-SPEC-P13 section 4.4): the FULL shipped VStatefulSet safety
    suite, refuted by reachability over the CRASH-ONLY product graph. This is the
    experiment of the phase: before it, no invariant in the suite had ever been
    checked to a decisive verdict against a crash.

    Seed [Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false] (Anvil [RestartControllerStep] live, cluster.rs:377; the
    other two adversaries off so a refutation is attributable to the crash and
    the graph stays small enough to close). Intended {!budget}:
    {!budget_crash_only}; it is a parameter so the M4 budget pin
    (BUILD-SPEC-P13 section 6) can pass [max_crashes = 0]. Invariants: the whole
    of {!Vsts_invariants.always}[ ~cr:(Scenario.vsts ~desired ())
    ~controller_id:Scenario.controller_id], i.e. the shared inv1-6 of
    {!Invariants.cluster_structural} PLUS the three VSTS invariants, conjoined
    with {!Invariants.conjunction} and lifted to the product pointwise
    ([fun f -> inv f.cs]) so the counters are witness bookkeeping and never part
    of the asserted property. On [Refuted], [violated] is
    {!Invariants.first_violated} at the counterexample state (the head of the
    lasso loop), so the report names the broken invariant and its Anvil
    [source].

    [gate_states = Some n] counts the reachable product states that are BOTH
    post-crash ([crashes >= 1]) and [interesting] for at least one invariant of
    the suite: the states at which this universal is genuinely exercised AFTER a
    real crash. [Some 0] means the crash-exercised slice is empty and a clean
    outcome verifies nothing about crashes, which must be reported as a modeling
    gap rather than a pass.

    {b MEASURED} at the P12-shaped bound ([test/p12_witness.ml:9-22] at
    [desireds = [1]]: [max_in_flight = 8], [max_objects_per_kind = 4],
    [max_controllers = 1], [uid_ceiling = 6], [rv_ceiling = 6],
    [reconcile_ceiling = 2], [max_reconcile_depth = 24]), [depth = 40],
    {!budget_crash_only}, [desired = 1]: [No_counterexample], [decisive = true],
    464 states, [gate_states = Some 388], [crash_witness_states = 388],
    [fault_free_states = 76], [settled_with_faults_live = 10],
    [max_crashes_seen = 1], [max_uid_seen = 3] and [max_rv_seen = 2] (both
    STRICTLY below their ceilings, so the BUILD-SPEC-P8 section 4 /
    BUILD-SPEC-P11 section 7.3 interpretability condition holds),
    [pruned_by_ceiling = true] (from [reconcile_ceiling], not uid/rv),
    [pruned_by_budget = true] (the second crash edge is clipped). No retune was
    needed. So the WHOLE shipped VSTS safety suite survives a real controller
    crash decisively: the invariants are not merely crash-untested, they are
    crash-CHECKED at 388 post-crash states.

    {b MEASURED confirm-by-mutation (BUILD-SPEC-P13 section 6 M1): a PREDICTION
    that FAILED.} Section 6 predicted that this gate REFUTES when
    [restart_controller] ([lib/cluster/cluster.ml:309], Anvil cluster.rs:377) is
    mutated to keep the pre-crash [ongoing_reconciles] instead of clearing them.
    MEASURED: it does not. The leg stays [No_counterexample], [decisive = true],
    [violated = None]; the mutant is caught only by the PINNED counts (464 states
    down to 152, [gate_states] 388 down to 76). The reason is structural, not
    incidental: every member of the suite is either etcd-local, or monotone in the
    uid / reconcile-id counters, or about request interference, and a surviving
    ongoing reconcile keeps its already-distinct id and its already-lower uid, so
    no member can observe the change. What M1 breaks is a TRANSITION-relation fact
    ("a restart clears the controller's in-flight work"), which a state-invariant
    suite cannot express. Read that as the honest scope of this gate: it certifies
    the shipped invariants ACROSS a crash, not the faithfulness of the crash
    transition itself. The M2 companion is on
    {!check_unique_reconcile_id_under_faults}, and the full protocol (mutants
    applied, measured, reverted) is the header of [test/t_p13_mutation.ml]. *)

val check_unique_reconcile_id_under_faults :
  ?depth:int -> Bound.t -> budget -> desireds:int list -> fault_report
(** {b G2} (BUILD-SPEC-P13 section 4.4): P12's concurrent-reconcile uniqueness
    gate, strengthened into the crash dimension. Same invariant
    ({!Invariants.unique_reconcile_id_invariant} =
    [every_ongoing_reconcile_has_unique_id],
    kubernetes_cluster/proof/controller_runtime_safety.rs:874) and same
    [>= 2-concurrent] non-vacuity notion (inv6's own [interesting],
    [cardinal(ongoing) >= 2]) as
    {!Cluster_check.check_unique_reconcile_id_vsts}, but over the crash-only
    product graph from [Scenario.vsts_seed_multi_faults ~desireds ~crash:true
    ~req_drop:false ~pod_monkey:false]. Intended {!budget}:
    {!budget_crash_only}.

    [gate_states = Some n] counts states with [cardinal(ongoing) >= 2 AND
    crashes >= 1]: the >= 2-concurrent-reconciles-AFTER-A-CRASH witness, which is
    strictly stronger than P12's fault-free witness (whose every state had
    [crashes = 0] by construction, so the crash-tolerance content there was
    zero). On [Refuted], [violated] is that single invariant (the
    {!Cluster_check.check_unique_reconcile_id_vsts} precedent), no
    {!Invariants.first_violated} search being needed for a singleton suite.

    {b MEASURED} at [desireds = [1; 1]] (P12's witness), [depth = 40],
    {!budget_crash_only}, with ONE documented retune (BUILD-SPEC-P13 section 5
    order, first lever): [reconcile_ceiling] 3 ([= n + 1] in
    [test/p12_witness.ml:19]) DOWN to 2, everything else P12-shaped
    ([max_in_flight = 8], [max_objects_per_kind = 5], [max_controllers = 1],
    [uid_ceiling = 7], [rv_ceiling = 7], [max_reconcile_depth = 24]). At the
    unretuned [reconcile_ceiling = 3] the run was KILLED at 561.67 s user /
    9 m 49.99 s wall without finishing, far past the 120 s budget; at 2 it is
    [No_counterexample], [decisive = true], 10552 states,
    [gate_states = Some 2784], [crash_witness_states = 6688],
    [fault_free_states = 3864], [settled_with_faults_live = 85],
    [max_crashes_seen = 1], [max_uid_seen = 5 < 7], [max_rv_seen = 4 < 7], both
    pruning flags [true], in 6.46 s CPU / 6.645 s wall. COVERAGE COST of the
    retune, stated rather than hidden: [reconcile_ceiling = 2] still admits the
    two CONCURRENT reconcile starts the [>= 2]-concurrent witness needs (2784
    such states are post-crash), but it clips runs that would start a THIRD
    reconcile pass, so uniqueness is checked over fewer sequential passes than
    P12's fault-free leg. Uniqueness holds CONSTRUCTIONALLY (the monotone
    [Controller.Reconcile_id_allocator.allocate] hands out distinct ids at any
    ceiling), so the clip bounds coverage, not truth - the same disclosure
    {!Cluster_check.check_unique_reconcile_id_vsts} already carries.

    {b MEASURED confirm-by-mutation (BUILD-SPEC-P13 section 6 M2): inv6 is
    INSENSITIVE to allocator reset.} Mutating [restart_controller]
    ([lib/cluster/cluster.ml:311]) so that a restart RESETS
    [Controller.Reconcile_id_allocator] to [init ()] instead of preserving it
    (upstream preserves it deliberately, cluster.rs:388-392) does NOT refute this
    gate: [No_counterexample] with [violated = None] at every depth measured
    ([depth = 14]: 8480 states against a baseline 5310; [depth = 18]: 37530
    against 9440; at the shipped [depth = 40] the mutant no longer finishes inside
    the 150 s harness alarm, killed at 142.47 s CPU, where the baseline is
    decisive in 6.1 s). Section 6's predicted reason is the measured one: a
    restart CLEARS [ongoing_reconciles], so the post-crash epoch re-allocates from
    0 into an EMPTY map and the ids present in [ongoing_reconciles] stay pairwise
    distinct. No crash adversary for inv6 is claimed here, because none was
    measured.

    {b Where the crash sensitivity actually lives}, so the paragraph above is not
    mis-read as "the crash dimension is inert": not in a refutation of any gate,
    but in the reachable-set SHAPE this {!fault_report} carries and
    [test/p13_witness.ml] pins.

    - Under the M2 reset it lives in DECISIVENESS. [Bound.reconcile_ceiling]
      prunes on [Controller.Reconcile_id_allocator.reconcile_count]
      (BUILD-SPEC-P8 section 3.2), so resetting the allocator hands the post-crash
      epoch a fresh pass allowance and the frontier stops emptying:
      {!check_invariants_under_faults} goes from 464 states / [decisive = true] to
      1191 states / [decisive = false] and {!check_settles_after_disable} from
      1856 to 4744, both still [violated = None]. The shipped exe reddens on M2 at
      a SEMANTIC assertion (t_p13_faults.ml:430, "G1: outcome decisive"), which is
      exactly what BUILD-SPEC-P13 section 4.5's semantic-before-pinned ordering
      exists to guarantee.
    - Under the sibling M1 mutant (a restart no longer clears
      [ongoing_reconciles]) it lives in the PINNED COUNTS: no invariant breaks,
      while G1 goes 464 states / gate 388 to 152 / 76 and
      {!check_settles_after_disable} 1856 / 10 to 608 / 2. Note this gate's own
      count is the WEAK detector there: G2 goes 10552 to 7728 states with
      [gate_states] UNCHANGED at 2784, so a gate-only pin would have missed M1
      entirely and the state / crash-witness pins are the ones doing the work.

    Both mutants are TRANSITION-relation faithfulness defects, which no
    state-invariant suite can express. The full protocol (mutants applied,
    measured, reverted, [lib/cluster/] left untouched) is the header of
    [test/t_p13_mutation.ml]. *)

val check_settles_after_disable :
  ?depth:int -> Bound.t -> budget -> desired:int -> fault_report
(** {b G3} (BUILD-SPEC-P13 section 4.4): the [failures_liveness] shape - after
    the adversaries are switched OFF, does a run that stops actually sit in the
    desired state? Seed [Scenario.vsts_seed_faults ~desired ~crash:true
    ~req_drop:true ~pod_monkey:true], the only leg with all three faults live
    (it satisfies every fault-flag conjunct of {!Cluster.init}, cluster.rs:110,
    but NOT {!Cluster.init} itself - see {!Scenario.vsts_seed_faults} for the two
    MEASURED corrections to the spec's stronger claims). Intended {!budget}:
    {!budget_default}. Anvil citations: the disablers
    [DisableCrashStep] / [DisableReqDropStep] / [DisablePodMonkeyStep]
    (cluster.rs:407, :472, :526); the [failures_liveness] proof is cited by NAME
    only, since this port carries no line-verified anchor for that file.

    Run through {!Model_check.check_reaches}, whose contract is "refute: every
    reachable QUIESCENT state satisfies TARGET":

    - [quiescent f] = {!Cluster_check.settled}[ bound Scenario.vsts_cluster f.cs]
      AND all three fault flags FALSE in [f.cs] (the crash flag read off the
      [controller_and_externals] entry for [Scenario.controller_id],
      [req_drop_enabled] / [pod_monkey_enabled] read off the state) - the run has
      taken the [Disable_*] prefix AND has no state-changing productive move
      left;
    - [target f] = {!Vsts_invariants.liveness_goal}[ ~cr] at [f.cs], i.e. the
      ordinal-identity converged shape is actually matched.

    So [Refuted] exhibits a run that STOPS, with every adversary already
    disabled, in a state that does NOT match the desired state; [violated] then
    names that liveness goal. A clean outcome with [gate_states = Some n], [n >
    0], is the settling evidence: the universal was evaluated at [n] real
    post-disable settled states. [gate_states = Some 0] is the honest vacuity
    signal (the disable-then-settle gate was never reached at this [depth] /
    {!Bound.t} / {!budget}), and must be reported as a modeling gap, never as a
    pass.

    {b DEVIATION from BUILD-SPEC-P13 section 4.4, disclosed (the spec is
    normative, so the divergence is stated rather than hidden).} The spec assigns
    the settled-and-all-flags-false predicate to {!Model_check.check_reaches}'s
    TARGET and leaves its QUIESCENT gate unspecified. Under
    [check_reaches]'s contract the only natural completion of that assignment -
    [quiescent = settled] alone - makes the leg refute EXACTLY when
    [settled_with_faults_live > 0], because [check_reaches] refutes at the first
    reachable state with [quiescent s && not (target s)], which is then "settled
    while some fault flag is still live". But section 4.3 introduces
    [settled_with_faults_live] as a non-vacuity CONTRAST to be MEASURED and
    pinned, not as a defect, and it is MEASURED NONZERO here (a state is
    [settled] whenever no PRODUCTIVE step changes it, and
    [Step.Restart_controller_step] / [Step.Drop_req_step] are NOT productive per
    [Scenario.productive_successors], so a state can be [settled] with the crash
    and req-drop flags still true). A leg that reports [Refuted] for exactly the
    quantity the spec asks us to report as good news would be reporting a
    tautology as a defect. So the spec's predicate is placed in the QUIESCENT
    slot and the liveness goal supplies the TARGET, which (a) honours
    [check_reaches]'s exact contract, (b) is literally the [failures_liveness]
    statement the spec names, and (c) is EXTENSIONALLY IDENTICAL to
    {!Model_check.check_safety} over the derived implication
    [fun f -> not (quiescent f) || target f] - the fallback the build task
    authorises - since [check_reaches] is implemented as the search for the first
    reachable state violating that implication. Nothing is lost: the spec's own
    predicate is still reported, as [gate_states] (the count of post-disable
    settled states) and, in its complementary form, as
    [settled_with_faults_live].

    {b Why the [Disable_*] trio and not merely a quiet suffix.}
    {!Cluster_check.settled} filters through {!Scenario.productive_successors},
    which counts [Step.Pod_monkey_step] (cluster.rs:492) as PRODUCTIVE, so while
    the monkey is live AND has an enabled op no state is [settled] at all; the
    [quiescent] gate is reachable only once the monkey is disabled (or is out of
    enabled ops), which is why this leg exists as a DISABLE leg.

    {b MEASURED, and the RULE the measurements establish.} All at [desired = 1]
    over the P12-shaped bound ([reconcile_ceiling = 2] unless stated):

    - {!budget_crash_only}, [depth = 40]: [No_counterexample],
      [decisive = true], 1856 states, [gate_states = Some 10] (ten real
      post-disable settled states, every one goal-matching),
      [crash_witness_states = 1552], [fault_free_states = 304],
      [settled_with_faults_live = 30], [max_crashes_seen = 1],
      [max_uid_seen = 3 < 6], [max_rv_seen = 2 < 6], 0.56 s CPU / 2.145 s wall.
      This is the leg's load-bearing witness: after a REAL crash and the
      [Disable_*] prefix, every state where the run stops matches the desired
      state, decisively.
    - {!budget_default}, [depth = 16] (RETUNED from 40, BUILD-SPEC-P13 section 5
      second lever: at [depth = 40] the run was killed by the 150 s harness
      alarm at 2 m 30.02 s wall): [Refuted] at [steps = 15], [violated =
      vsts_current_state_matches], [gate_states = Some 4],
      [crash_witness_states = 34990], [fault_free_states = 208],
      [settled_with_faults_live = 43], all three [max_*_seen = 1], 85.31 s CPU /
      1 m 36.40 s wall.
    - That [Refuted] is a [reconcile_ceiling] COVERAGE ARTIFACT, not a settling
      defect, and the artifact is DIAGNOSED rather than assumed: all 4 quiescent
      states have [Cluster_check.max_reconcile_id = 2 = reconcile_ceiling],
      exactly ONE state-changing productive successor (the retry pass) and ZERO
      of it admitted, with [crashes = 1] and [drops = 1]. The crash and the
      dropped request each burn one admitted reconcile pass, so at 2 admitted
      passes nothing is left to converge with; meanwhile OTHER interleavings with
      the same [crashes = 1, drops = 1] do reach the goal (a
      settled-with-faults-live state at [etcd = 2] has [goal = true]), so the
      model is not broken - the pass allowance is.
    - CONFIRMED by raising the suspected ceiling: budget [{1; 1; 0}]
      (crash + drop, no monkey) refutes identically at [reconcile_ceiling = 2]
      ([steps = 15], [gate_states = Some 73]) and goes [No_counterexample],
      [decisive = true], 31248 states, [gate_states = Some 112] at
      [reconcile_ceiling = 3] (86.69 s CPU / 3 m 01.25 s wall) - one admitted
      pass more than the two pass-wasting faults.
    - So the RULE for reading this leg: [reconcile_ceiling] must EXCEED the
      number of pass-wasting fault edges the {!budget} permits ([max_crashes +
      max_drops], plus [max_monkey_ops] for the repair pass a deleted pod needs),
      or a [Refuted] is starvation of the retry pass rather than a settling
      failure. The fully non-artifact pairing for {!budget_default}
      ([reconcile_ceiling >= 4]) is NOT reachable at a tractable depth here:
      [reconcile_ceiling = 3] at [depth = 16] already costs 101.73 s CPU /
      4 m 55.96 s wall and is honestly VACUOUS there ([gate_states = Some 0],
      [decisive = false], [settled_with_faults_live = 0] - the extra pass pushes
      settling past [depth = 16]), while [depth = 40] blows the alarm. That is a
      disclosed COVERAGE limit of the phase, not a verdict. *)

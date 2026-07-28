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
    It is pure ASSURANCE CONSTRUCTION: [lib/cluster/] is not modified BY P13
    (P14, which adds {!check_correspondence_under_faults} to this same module,
    DOES modify it by one purely additive accessor -
    [Message.Rpc_id_allocator.rpc_id_count]; see that leg's doc and
    {!Correspondence}. The unqualified claim was left standing when P14 landed
    here and is corrected rather than deleted, since it remains true of P13's own
    contribution), and no
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

val violated_of :
  Invariants.invariant list ->
  faulted Model_check.outcome ->
  Invariants.invariant option
(** The shared [~violated] wiring every safety leg here passes to its runner: on
    [Model_check.No_counterexample] the answer is [None]; on
    [Model_check.Refuted] it is {!Invariants.first_violated} of the given list at
    the HEAD OF THE LASSO LOOP, i.e. the member actually broken at the
    counterexample state, with its Anvil [source] attached. This is what fills
    {!fault_report.violated}, so the field NAMES the broken member rather than
    merely reporting that something broke.

    {b Exported for test reasons, deliberately.} On the true model every shipped
    leg is clean, so this function's [Refuted] branch would otherwise ship with
    ZERO automated coverage - exactly the "Refuted path never observed" failure
    P12 shipped ([[feedback-confirm-tests-by-mutation]]). Exporting it lets a
    test drive a REAL [Refuted] outcome (over a hand-forged product state, or
    over the real graph with a deliberately-violating invariant list) through THE
    SAME function the legs use, instead of re-implementing the naming path in the
    test and asserting about the copy. Purely additive: no leg's behaviour
    changes. *)

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

val check_correspondence_under_faults :
  ?depth:int ->
  Bound.t ->
  budget ->
  desired:int ->
  require_crash:bool ->
  fault_report
(** BUILD-SPEC-P14 section 4.3: the ID-LEVEL correspondence family
    ({!Correspondence.family}, the five [proof/network.rs] StatePreds) checked by
    reachability over the fault product.

    {b What this leg is for.} P13 measured that mutating the crash transition
    refutes NOTHING of the shipped suite, because no member of it READS A MESSAGE
    (BUILD-SPEC-P13 section 6, restated on {!Correspondence}). This is the leg
    that closes that gap: [restart_controller] (cluster.ml:291-324) empties
    [ongoing_reconciles] while leaving [s.network] and [s.rpc_id_allocator]
    untouched, so the crash edge is precisely the one that can break rpc-id
    discipline, and these five predicates are the ones that would see it.

    {b The seed is constant; the budget is the variable.} Both legs seed
    [~crash:true] (so [Step.Restart_controller_step] is enumerated at all) and
    differ ONLY in [budget.max_crashes]. Same seed, same state shape, one
    variable - the crash-0 and crash-1 runs are therefore directly comparable
    rather than two unrelated experiments. Passing [~crash:false] instead would
    change the seed STATE (the flag is part of state equality) and confound the
    comparison.

    {b [require_crash] selects what [gate_states] counts.} The two legs need
    different non-vacuity witnesses:

    - [~require_crash:false] (the G1 leg, run at [max_crashes = 0]): states where
      some member's [interesting] fires. The floor showing the family is
      exercised at all BEFORE any crash, so a later clean crash verdict cannot be
      clean-by-emptiness — but see the MEASURED CORRECTION below: that floor
      covers N1-N4 only.
    - [~require_crash:true] (the G2 leg, run at {!budget_crash_only}):
      additionally requires [f.crashes >= 1] - the states that are genuinely
      POST-CRASH and exercise a member. This is the phase's headline witness, and
      it is the count that must be [> 0] for the leg to mean anything.

    {b Disclosed deviation from BUILD-SPEC-P14 section 4.3,} which sketched a
    single fixed [crashes >= 1] gate: at [max_crashes = 0] that gate is [0] BY
    CONSTRUCTION, so it cannot serve as section 4.4's crash-disabled non-vacuity
    floor. The selector is the minimal repair and is explicit rather than
    implicit in the budget.

    {b Reading a verdict.} [No_counterexample {decisive = true}] means
    falsification up to ([depth], {!Bound.t}, {!budget}) - evidence that the crash
    transition preserves ID discipline, NOT that it is faithful in every other
    respect. A [Refuted] names the offending member through [violated], because
    [violated_of] is applied to the family rather than to a singleton.

    {b MEASURED} (all at [desired = 1], [P13_witness.p13_bound], [depth = 40];
    pinned once in [test/p14_witness.ml]):

    - G1 ([zero_budget], [~require_crash:false]): [No_counterexample],
      [decisive = true], 76 states, [gate_states = Some 32],
      [crash_witness_states = 0], [fault_free_states = 76],
      [max_uid_seen = 3], [max_rv_seen = 2], [max_crashes_seen = 0]. 0.01 s CPU.
    - G2 ({!budget_crash_only}, [~require_crash:true]): [No_counterexample],
      [decisive = true], 464 states, [gate_states = Some 296],
      [crash_witness_states = 388], [fault_free_states = 76],
      [max_crashes_seen = 1]. 0.06 s CPU. The 464 / 388 / 76 triple is the SAME
      product graph P13's G1 explores (same seed, bound and budget), so the two
      phases' counts are cross-checkable; only the asserted invariant differs.
    - Section 5 predicted [max_in_flight] would bind harder here than in any
      prior phase, because post-crash orphan messages never drain. It did NOT:
      no retune was needed and both legs close in under 0.1 s CPU. Recorded as a
      measured NON-retune so the prediction is not left standing.

    {b MEASURED CORRECTION - N5 is VACUOUS on the crash-free graph.} Per-member
    [interesting] counts, G1 then G2-all then G2-post-crash: N1 32 / 328 / 296,
    N2 32 / 180 / 148, N3 16 / 100 / 84, N4 16 / 156 / 140,
    {b N5 0 / 84 / 84}. Fault-free traffic in this scenario is strict
    request/response lock-step, so at most one message is ever in flight and
    N5's [cardinal >= 2] premise is unreachable; this is NOT a ceiling artifact
    ([max_in_flight = 8], four times what N5 needs; the tests assert a [>= 4]
    FLOOR on that ceiling, not the literal 8 - corrected in review, the prose
    previously claimed they pinned the 8).

    {b MEASURED anti-artifact evidence for that zero (review finding).} Arguing
    the zero against [max_in_flight = 8] alone was too weak: the ceiling this run
    actually PRUNES by is [reconcile_ceiling = 2] (it is what makes
    [pruned_by_ceiling] true), and the earlier robustness run varied only
    [uid_ceiling] / [rv_ceiling], which the same run reports were never reached -
    so its invariance was guaranteed a priori. The BINDING ceiling has now been
    swept on the G1 leg, and N5's count stays 0 at every setting:
    [reconcile_ceiling] 2 -> 76 states / gate 32, 3 -> 112 / 48,
    4 -> 148 / 64 (at [depth = 60]), 6 -> 220 / 96 (at [depth = 100]) - all four
    decisive, all four with N5's [interesting] count 0. The mechanism is stronger
    than the count: the LARGEST [Message.Pool.cardinal (Cluster.in_flight s)]
    over the whole crash-free graph is {b 1} at every one of those ceilings, so
    the [>= 2] premise is not merely unreached, it is structurally unreachable
    fault-free. N5's vacuity is a property of the lock-step message discipline,
    not of the bound. (At [reconcile_ceiling = 4] with the shipped [depth = 40]
    the run is NOT decisive and [pruned_by_ceiling] flips to false - depth
    becomes the binding limit before the ceiling does - which is why the
    higher-ceiling legs are run at a raised depth.)
    N5's G2 count EQUALS its post-crash count (84 = 84), i.e. every state
    exercising N5 is post-crash: {b the crash edge is the only source of two
    concurrently in-flight messages in this bounded graph}. CAREFUL: that is NOT
    the mechanism by which the allocator-reset mutant bites - it bites via N1,
    with no collision forming at all (see the crash-sensitivity paragraph). N5's
    84 = 84 identity is a statement about where two-in-flight states come from,
    not about what catches MA. So G1 is the non-vacuity floor for the
    id-ORDERING members only; N5 is checked vacuously whenever no crash is
    budgeted, and its floor is G2's 84.

    {b The crash-sensitivity result (BUILD-SPEC-P14 section 6, confirmed by
    mutation, not asserted).} Mutating [restart_controller] (cluster.ml:291-324)
    to ALSO reset [s.rpc_id_allocator] flips G2 from clean to [Refuted] at
    [steps = 6], [violated = every_in_flight_msg_has_lower_id_than_allocator],
    while G1 stays byte-identical at 76 states / gate 32 - the control proving
    the refutation is attributable to the crash edge. N1 is what fires, NOT the
    N5 the spec predicted: once the counter resets to 0 a surviving pre-crash
    message trips [rpc_id < counter] immediately, one step before a collision
    can form. The converse mutant (restart KEEPS [ongoing_reconciles]) refutes
    NOTHING - both legs stay clean, G2 merely shrinks to 152 states /
    [crash_witness_states = 76]. Together these close P13's negative result: the
    allocator-reset mutation that refuted nothing there is refuted here. *)

val vsts_pending_states : Value.t -> bool
(** The R2 instantiation {!check_reconcile_correspondence_under_faults} bakes
    in, DERIVED from the VStatefulSet reconciler's step encoding rather than
    invented (BUILD-SPEC-P15 section 4.3): [true] iff the erased local state
    decodes ([V_stateful_set_pack.unmarshal_state]) and its step is one of
    the seven [After_*] constructors. Those are exactly the states
    [V_stateful_set_reconciler.reconcile_core] lands in TOGETHER WITH a
    [Some] request (v_stateful_set_reconciler.ml:533, :590, :622, :654,
    :707, :743, :786 - the action / [After_*] alternation), so this is
    upstream's pending-request state class for the reconciler the leg's
    scenario actually runs ({!Scenario.vsts_cluster}'s registered model). A
    local state that fails to decode fires NO guard: R2 is vacuous there,
    never refuted (or validated) by a codec mismatch, so this predicate and
    {!vsts_none_states} are complements over DECODABLE states only.

    Exported deliberately (the {!violated_of} precedent above): the
    side-condition validation and the per-member gate measurements must run
    against THE SAME predicate the leg asserts, not a re-implementation in
    the test that could drift from it.

    {b MEASURED - the side-condition verdict, reported before any R2 verdict
    is read} (an upstream theorem only under that side condition):
    {!Reconcile_correspondence.state_comes_with_a_pending_request} HOLDS for
    this predicate over the reachable continue-transition triples of BOTH
    shipped legs ([zero_budget] and {!budget_crash_only}), and NON-vacuously:
    the init conjunct genuinely discriminates
    ([vsts_pending_states (init ())] is [false]) and the pending landing
    class is populated on both graphs - 24 of 60 triples fault-free, 126 of
    348 crash-enabled, with the two landing classes partitioning each triple
    set exactly. So R2 was measured at a VALIDATED instantiation;
    BUILD-SPEC-P15 section 4.3's "no non-vacuous instantiation exists"
    branch was not taken. *)

val vsts_none_states : Value.t -> bool
(** The R4 instantiation {!check_reconcile_correspondence_under_faults} bakes
    in - the dual of {!vsts_pending_states}: [true] iff the erased local
    state decodes and its step is NOT an [After_*] constructor. Derived from
    the same landing-site reading: every [reconcile_core] transition landing
    in a non-[After_*] step returns [None] for the request, and [Init] -
    included here - is never a landing state at all ([reconcile_init_state]
    only) and carries no pending request at insert, so the R4 side
    condition's transition conjunct holds for it vacuously. Same
    decode-failure behaviour and the same deliberate-export rationale as
    {!vsts_pending_states}.

    {b MEASURED - the dual side-condition verdict} (upstream proves R4 only
    under it, controller_runtime_safety.rs:507):
    {!Reconcile_correspondence.state_comes_with_no_pending_request} HOLDS
    for this predicate over BOTH shipped legs' reachable continue-transition
    triples, NON-vacuously: 36 of 60 fault-free triples and 222 of 348
    crash-enabled triples land in none states (no init conjunct to
    discriminate - upstream's own asymmetry). R4, like R2, was therefore
    measured at a validated instantiation. *)

val check_reconcile_correspondence_under_faults :
  ?depth:int ->
  ?req_drop:bool ->
  ?pod_monkey:bool ->
  Bound.t ->
  budget ->
  desired:int ->
  require_fault:bool ->
  fault_report
(** {b G5} (BUILD-SPEC-P15 section 4.4): the RECONCILE-SIDE correspondence
    family ({!Reconcile_correspondence.family} = R1-R4) checked by
    reachability over the fault product.

    {b What this leg is for.} Every P14 member is guarded on the NETWORK side
    ([in_flight().contains(msg)]); every member here is guarded on the
    ONGOING-RECONCILE side. [restart_controller] (cluster.ml:291-324) empties
    [ongoing_reconciles] and leaves [s.network] and [s.rpc_id_allocator]
    untouched, so the crash edge DESTROYS every guard in this family while
    PRESERVING every guard in P14's. This leg is the experiment that turns
    that asymmetry into a measurement. Prediction P15-A (BUILD-SPEC-P15
    section 3): the UNMUTATED crash edge refutes nothing here - at the crash
    instant all four members are vacuously true, and the fresh post-restart
    reconcile draws a fresh rpc id - so the crash's only visible effect
    should be on the GATE counts. That is a prediction of a NEGATIVE result;
    it must be recorded as measured or refuted, never quietly dropped, and if
    it holds the phase's positive content is the structural claim
    ("crash sensitivity is determined by where a guard lives, not by what the
    invariant says") plus mutation MA - not a new refutation.

    {b The family is asserted ALONE (the section-3 masking trap).} Never
    unioned with {!Correspondence.family}, {!Invariants.always} or
    {!Vsts_invariants.always}. Under mutation MA (restart also resets the
    rpc-id allocator) P14 MEASURED N1 firing at [steps = 6], one step BEFORE
    an rpc-id collision can form: a combined leg would report N1 and never
    evaluate R3's exclusivity, masking this phase's headline behind an
    earlier-firing member. If a run here ever reports [violated] naming a P14
    member ([every_in_flight_msg_has_lower_id_than_allocator] or any other),
    the family lists were unioned somewhere: that is a harness bug, not a
    finding.

    {b Same product graph as P13 G1 / P14 G2, by construction.} Same seed
    ([Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey
    ()] with both P16 options defaulting [false] - the crash DIMENSION is
    selected by the caller's {!budget}, not by the seed, exactly as on
    {!check_correspondence_under_faults}), same default depth, same
    {!faulted_successors} product construction. At
    ([P13_witness.p13_bound], [depth = 40], [desired = 1]) the reachable
    product set is therefore the SAME graph those phases explored and pinned
    - 76 states fault-free at [zero_budget]; 464 / 388 / 76 for [states] /
    [crash_witness_states] / [fault_free_states] at {!budget_crash_only} -
    so the three phases cross-check on those counts and ONLY the asserted
    invariant list differs. A P15 leg whose [states] count differs from
    P14's at the same budget means the seed or bound drifted: investigate
    before reporting anything (BUILD-SPEC-P15 section 4.4).

    {b The R2/R4 instantiation is baked in and DERIVED, not invented:}
    {!vsts_pending_states} / {!vsts_none_states} (see their blocks for the
    derivation and the side-condition duty). The leg's signature carries no
    instantiation parameter deliberately - a caller-supplied predicate would
    reintroduce the invented-instantiation hazard BUILD-SPEC-P15 section 4.3
    exists to exclude, and would decouple the measured leg from the validated
    predicates.

    {b [require_fault] selects what [gate_states] counts} - RENAMED from
    [require_crash] and its crash conjunct generalised under the P16
    review's F6 (applied on the P17 branch, next to P15's disclosure below):
    the P16 options made drop / monkey edges takeable AT THIS LEG, and the
    old [(not require_crash) || crashes >= 1] gate under a drop- or
    monkey-only budget was structurally 0 SILENTLY. [~require_fault:false]
    counts states where SOME member's [interesting] fires (the pre-fault
    exercise floor, intended at [zero_budget]); [~require_fault:true]
    additionally requires the leg's OWN fault counter [>= 1] - [crashes],
    [drops] or [monkeys] according to which dimensions the budget permits
    ([cap >= 1]), the same [budget_fault_taken] gate
    {!check_req_resp_under_faults} documents. On every shipped run the
    change is EXTENSIONALLY IDENTICAL to the old crash conjunct (each
    [true] run uses a flags-off seed, where [drops] / [monkeys] are
    identically 0, and a budget with [max_crashes = 1]); the full battery
    was re-run on the rename and every committed pin below is UNCHANGED.
    Per-member expectations (BUILD-SPEC-P15 section
    4.2), each justified not guessed: R1 needs at least TWO ongoing
    reconciles both holding [Some] pending requests, so its [interesting] is
    expected STRUCTURALLY 0 at [desired = 1] (one CR, one key: the inner
    quantifier ranges over nothing) - the [desired = 2] / multi-key seed and
    the binding-ceiling sweep proving that zero is not a bound artifact
    (P14's N5 protocol) are the measurement stage's duty; R2/R4 fire at
    states whose local step satisfies their own instantiation; R3 fires at
    any ongoing reconcile with a full [has_pending_req_msg] (content
    conjunct included).

    {b Reading a verdict.} R3 is asserted after EVERY step, which is
    STRONGER than upstream's [leads_to(always(..))] proof
    (controller_runtime_safety.rs:422): a refutation near the seed may be
    the leads-to shape appearing empirically and MUST NOT be reported as a
    port defect without inspecting the counterexample lasso
    ({!Reconcile_correspondence} header; BUILD-SPEC-P15 sections 2 and 8).
    [No_counterexample {decisive = true}] is bounded falsification up to
    ([depth], {!Bound.t}, {!budget}) on ONE VSTS scenario - and under a
    nonzero budget it is evidence about THIS bounded model only, never
    absolution for upstream's fault-disabled premises (:414-:416): the
    section-4.5 premise matrix consumes this function at varying budgets,
    and a clean leg whose fault counter never reached 1 measures NOTHING
    and must be reported as vacuous. A [Refuted] names the offending member
    through [violated] ({!violated_of} over the four-member family).

    {b MEASURED} (all at [desired = 1], [P13_witness.p13_bound],
    [depth = 40]; pinned once in [test/p15_witness.ml]; L0/L1 are the
    section-4.5 matrix's names for the two shipped legs):

    - L0 ([zero_budget], [~require_fault:false]): [No_counterexample],
      [decisive = true], 76 states, [gate_states = Some 64],
      [crash_witness_states = 0], [fault_free_states = 76],
      [max_uid_seen = 3], [max_rv_seen = 2], [max_crashes_seen = 0], both
      pruning flags [true]. 0.013 s CPU. Per-member [interesting]: R1 0
      (structurally vacuous at [desired = 1] - see below), R2 32, R3 32,
      R4 32.
    - L1 ({!budget_crash_only}, [~require_fault:true]): [No_counterexample],
      [decisive = true], 464 states, [gate_states = Some 304] (368 on the
      all-states union, recomputed over the replica),
      [crash_witness_states = 388], [fault_free_states = 76],
      [max_crashes_seen = 1], both pruning flags [true]. 0.077 s CPU. The
      464 / 388 / 76 triple is the EXACT product graph P14's G2 and P13's
      G1 committed (same seed, bound and budget), so the three phases
      cross-check on those counts; only the asserted family differs.
      Per-member [interesting], all-states / post-crash: R1 0 / 0,
      R2 180 / 148, R3 180 / 148, R4 188 / 156.
    - {b PREDICTION P15-A CONFIRMED} - a measured NEGATIVE result, recorded
      per BUILD-SPEC-P15 section 8.5: the unmutated crash edge refutes
      NOTHING in this family; its only visible effect is on the gate counts
      (64 -> 304 post-crash).
    - Side-condition verdicts: BOTH HOLD, non-vacuously, over both legs'
      reachable triples - the measured counts live in the
      {!vsts_pending_states} / {!vsts_none_states} blocks above.
    - [max_in_flight] re-measured, per section 5, not inherited: the
      ceiling 8 NEVER binds (largest [Message.Pool.cardinal] is 1 on L0's
      graph, 2 on L1's, and 3 even with all three fault dimensions live);
      [pruned_by_ceiling = true] on every leg is [reconcile_ceiling = 2]
      biting, not the pool cap. P14's non-retune re-confirmed: no retune.

    {b MEASURED crash-sensitivity (mutation MA).} Mutating
    [restart_controller] to ALSO reset [s.rpc_id_allocator] (manual source
    mutation) flips L1 from clean to [Refuted] naming R3 through [violated]
    ([pending_req_in_flight_xor_resp_in_flight_if_has_pending_req_msg]),
    while L0 stays byte-identical - the control proving the refutation is
    attributable to the crash edge. The converse mutant M1 (restart KEEPS
    [ongoing_reconciles]) refutes NOTHING: the L1 graph merely shrinks
    464 -> 152, P14's exact measured shrink.

    {b MEASURED - R1's zero is STRUCTURAL at [desired = 1], not a bound
    artifact} (P14's N5 protocol, run on the BINDING ceiling): the
    [reconcile_ceiling] sweep 2 / 3 / 4 / 6 gives 76 / 112 / 148 / 220
    zero-budget states and 464 / 984 crash-only at 2 / 3, and EVERY point
    keeps R1's [interesting] at 0 with the per-state maximum of
    concurrently-pending ongoing reconciles at 1. Mechanism:
    [ongoing_reconciles] is keyed by [object_ref], so a single-CR seed can
    never hold two ongoing reconciles at any ceiling. On P12's multi-CR
    [1; 1] seed R1 IS non-vacuously exercised - [interesting] fires at 928
    of 3864 zero-budget states and 1856 of 10552 crash-only states - and is
    violated at ZERO reachable states.

    {b DISCLOSED LIMITATION (P15) - budget variation alone cannot exercise
    the drop / monkey dimensions at this leg.} As shipped by P15 the seed
    pinned [~req_drop:false] [~pod_monkey:false] and fault flags only flip
    [true -> false], so NO budget could make this leg take a drop or monkey
    edge: BUILD-SPEC-P15 section 4.5's L2 / L3 dimensions were vacuous BY
    CONSTRUCTION here. Their premise content was measured by supplementary
    direct-graph probes with the flags enabled at the seed (drop-enabled:
    744 states, all-states gate 688, clean, decisive, drop edge really
    taken; monkey-enabled: 1976 states, gate 1680, clean, decisive, monkey
    edge really taken) - both premises measured-unnecessary-in-this-model
    for R2/R3/R4, always with section 8.3's qualifier: a bounded
    single-scenario model failing to exhibit the excluded counterexample is
    weak evidence about the model, not about upstream's premise.

    {b P16 DISCHARGE of that limitation (BUILD-SPEC-P16 section 4.5).}
    [?req_drop] / [?pod_monkey] (defaults [false]) now thread to the seed
    flags, purely additively: every existing call is value-identical, so
    the L0/L1 pins above stand unchanged. With a flag [true] AND a nonzero
    budget cap in the matching dimension, the L2 / L3 dimensions become
    exercisable AT THIS LEG rather than only at the supplementary probes -
    the flag makes the edge exist, the budget makes it takeable, and
    [max_drops_seen] / [max_monkeys_seen] must be checked [>= 1] before
    any verdict from such a leg is read (a zero means the leg was vacuous
    for its own dimension).

    {b MEASURED (P16) - the premise re-measure AT THE LEG}
    ([t_p16_regression]'s p15_premise_releg group, run through THIS
    function; both runs at [desired = 1], the P13 bound shape,
    [depth = 40], [~require_fault:false], every expected count DERIVED
    from the committed P15 probe pins, never re-typed):

    - drop ([~req_drop:true], budget [{0; 1; 0}]): [No_counterexample],
      [decisive = true], 744 states, [gate_states = Some 688],
      [max_drops_seen = 1] (the first drop edge ever taken at THIS leg),
      [fault_free_states = 152], [crash_witness_states = 0],
      [violated = None].
    - monkey ([~pod_monkey:true], budget [{0; 0; 1}]):
      [No_counterexample], [decisive = true], 1976 states,
      [gate_states = Some 1680], [max_monkeys_seen = 1],
      [fault_free_states = 152], [crash_witness_states = 0],
      [violated = None].

    Both leg graphs are STATE-IDENTICAL to P15's supplementary L2x / L3x
    probe graphs (same seed flags, bound, budget and depth), so the
    supplementary-probe verdicts are now LEG verdicts: both premises
    remain measured-unnecessary-in-this-model for R2/R3/R4, always with
    section 8.3's qualifier - a bounded single-scenario model failing to
    exhibit the excluded counterexample is weak evidence about the model,
    not about upstream's premise. *)

type list_select = Rv_list | Matched_list
(** Which of the two P16 request/response lists
    {!check_req_resp_under_faults} asserts: [Rv_list] selects
    {!Req_resp_correspondence.rv_family} (Q1-Q2, guarded on network + etcd,
    no reconcile read), [Matched_list] selects
    {!Req_resp_correspondence.matched_family} (Q3 + Q5, reconcile-COUPLED
    through [resp_msg_matches_req_msg]). A SUM, not a bool (BUILD-SPEC-P16
    section 4.4): the selector's whole point is that the two lists are
    asserted SEPARATELY, on separate legs, and never unioned - the split by
    guard home IS the thesis under test. *)

val check_req_resp_under_faults :
  ?depth:int ->
  ?req_drop:bool ->
  ?pod_monkey:bool ->
  ?vct:bool ->
  Bound.t ->
  budget ->
  desired:int ->
  list_select:list_select ->
  require_fault:bool ->
  fault_report
(** {b G6} (BUILD-SPEC-P16 section 4.4): the request/response correspondence
    family ({!Req_resp_correspondence}, [proof/req_resp.rs]) checked by
    reachability over the fault product, one of its two lists at a time
    ([list_select]).

    {b What this leg is for.} P14 (network-guarded) and P15
    (reconcile-guarded) settled the CRASH dimension of the thesis that fault
    sensitivity is determined by WHERE a guard lives. This leg carries the
    thesis onto the remaining two dimensions with the family whose members
    are the first to open a response message's BODY and relate it to
    [s.api_server] while quantifying over ALL in-flight messages
    ({!Req_resp_correspondence}'s header carries the F1-narrowed claim and
    its sweep: shipped inv15/inv16 already open list-response bodies, but
    only for the single pending request of one decoded ongoing VRS
    reconcile). These are the first legs whose RUNS take a
    [Step.Drop_req_step] or [Step.Pod_monkey_step] under a measured fault
    gate (BUILD-SPEC-P16 section 1, F2-corrected: P13 built the drop /
    monkey budget machinery, and {!check_settles_after_disable} has seeded
    all three fault flags TRUE since P13 - but its one shipped run used
    {!budget_crash_only}, p13_witness.ml:53, so no shipped leg RUN ever
    TOOK a drop or monkey edge before these).

    {b Seed and dimensions.} [Scenario.vsts_seed_faults ~desired ~crash:true
    ~req_drop ~pod_monkey ~vct ()]: the crash flag stays ON and its
    dimension is selected by the caller's {!budget}, exactly as on the
    P14/P15 legs, so at [vct:false] and P13's bound / depth / budget the
    product graph is the SAME one those phases pinned (76 fault-free at
    [zero_budget]; 464 / 388 / 76 at {!budget_crash_only}) and the phases
    cross-check. [?req_drop] / [?pod_monkey] (defaults [false]) enable the
    other two dimensions: the seed flag makes the edge EXIST, the budget cap
    makes it TAKEABLE. [?vct] (default [false]) seeds the CR with a
    volumeClaimTemplate, making the reconciler's PVC arm - hence
    [Get_request]s, hence OK get responses - reachable at all: predicted
    (P16-E) to de-vacuify Q1/Q2/Q3, whose [interesting] is expected 0 under
    [vct:false]. A [vct:true] leg is a DIFFERENT scenario whose counts are
    NOT comparable with the P13/P14/P15 pins (BUILD-SPEC-P16 section 8.6).

    {b The selected list is asserted ALONE (the masking trap, mandatory).}
    Never union {!Req_resp_correspondence.rv_family} with
    {!Req_resp_correspondence.matched_family}, and never union either with
    {!Correspondence.family}, {!Reconcile_correspondence.family},
    {!Invariants.always} or {!Vsts_invariants.always}. Under mutation MD
    (the drop fabricator's [Create_request] arm returning [Ok]), Q5 is the
    phase's intended witness; a unioned leg could report an earlier-firing
    P14 member first and mask the headline, exactly as P14 measured N1
    firing one step before an rpc-id collision can form under MA. A
    [violated] naming ANY non-P16 member here is a harness bug, not a
    finding (BUILD-SPEC-P16 section 4.4).

    {b Q2's bound coupling.} [bound] both bounds the exploration AND
    instantiates Q2's bound-key closure ({!Req_resp_correspondence.rv_family}
    documents the coupling): the leg passes the SAME [bound] to both, and a
    caller re-checking per-member [interesting] counts must do likewise or
    the counts stop being evidence about this leg.

    {b [require_fault] selects what [gate_states] counts,} generalising
    P14's [require_crash] (the P15 leg adopted the same [require_fault]
    gate under P17 F6): [~require_fault:false] counts states where
    SOME selected member's [interesting] fires (the non-vacuity floor,
    intended at [zero_budget]); [~require_fault:true] additionally requires
    the leg's OWN fault counter [>= 1] - [crashes], [drops] or [monkeys]
    according to which dimensions the budget permits ([cap >= 1]). At
    [zero_budget] with [~require_fault:true] the gate is 0 by construction
    (P14's [require_crash] lesson), so the floor leg must use [false].

    {b Reading a verdict.} [No_counterexample {decisive = true}] is bounded
    falsification up to ([depth], {!Bound.t}, {!budget}) on ONE VStatefulSet
    scenario - never a proof, and on a drop or monkey leg a CLEAN verdict is
    a NEGATIVE result and must be reported as one (BUILD-SPEC-P16 section
    8.4). Before reading ANY verdict from a drop leg check
    [max_drops_seen >= 1], and from a monkey leg [max_monkeys_seen >= 1]: a
    zero means the leg never took its own dimension's edge and is vacuous
    for it, the exact failure P15 disclosed and this phase exists to fix
    (BUILD-SPEC-P16 section 3). A [Refuted] names the offending member
    through [violated] ({!violated_of} over the selected two-member list).

    {b MEASURED} (BUILD-SPEC-P16 section 4.6; all at [desired = 1], the
    P13 bound shape unchanged through three phases, [depth = 40], each
    list asserted ALONE; every number pinned once in [test/p16_witness.ml]
    and asserted by [test/t_p16_req_resp.ml]; all fourteen runs
    sub-second):

    - L0 ([zero_budget], [~require_fault:false], [vct:false]): BOTH lists
      [No_counterexample], [decisive = true], 76 states - exactly P14 G1 /
      P15 L0's fault-free graph, the mandatory no-seed-drift cross-check -
      [gate_states = Some 0] on [Rv_list] and [Some 4] on [Matched_list],
      both pruning flags [true]. Per-member [interesting]: Q1 0, Q2 0,
      Q3 0, Q5 4.
    - Lc ({!budget_crash_only}, [~require_fault:true]): both lists clean
      and decisive over the EXACT P13 G1 product graph (464 / 388 / 76,
      [max_crashes_seen = 1]); gates [Some 0] (Rv) / [Some 32] (Matched).
      Q5 [interesting] 36 all-states / 32 post-crash; Q1/Q2/Q3 0.
    - Ld ([~req_drop:true], budget [{0; 1; 0}], [~require_fault:true]):
      both lists clean and decisive with [max_drops_seen = 1] - THE FIRST
      DROP EDGE EVER TAKEN IN A DECISIVE LEG in this repo. 744 states
      (= P15's supplementary L2x probe graph), [fault_free_states = 152]
      (the enabled flag adds the [Disable_req_drop_step] dimension to the
      zero-counter slice, doubling L0's 76 - NOT seed drift), gates
      [Some 0] (Rv) / [Some 16] (Matched); Q5 24 all-states / 16
      post-drop; Q1/Q2/Q3 0. THE KNIFE-EDGE MEASURED DIRECTLY (P16-C's
      mechanism): 384 of the 744 states hold a fabricated Error-bodied
      response satisfying [Message.resp_msg_matches_req_msg] against an
      ongoing reconcile's pending request - every one of the 384 in the
      [drops >= 1] slice, 0 of 76 on L0 - so the matching premise IS
      reached and ONLY the [is_ok] conjunct keeps Q3/Q5's antecedents
      false, precisely as section 3 predicted.
    - Lm ([~pod_monkey:true], budget [{0; 0; 1}], [~require_fault:true]):
      both lists clean and decisive with [max_monkeys_seen = 1] - the
      first monkey edge in a decisive leg. 1976 states (= P15's L3x probe
      graph), [fault_free_states = 152] (same doubling), gates [Some 0]
      (Rv) / [Some 80] (Matched); Q5 88 all-states / 80 post-monkey;
      Q1/Q2/Q3 0. The second-writer mechanism is VISIBLE:
      [max_uid_seen = max_rv_seen = 4] against 3 / 2 on L0 / Lc / Ld - a
      real [Api_server_step] applied the monkey's injected create, the
      transitive etcd write P16-D requires.
    - L0v / Ldv ([~vct:true]; a DIFFERENT scenario, counts NOT comparable
      with any committed P13/P14/P15 pin, section 8.6): both clean and
      decisive; 116 / 1832 states; gates (Rv / Matched) [Some 4] /
      [Some 12] and [Some 16] / [Some 96]; Ldv [max_drops_seen = 1],
      [fault_free_states = 232]. Per-member [interesting]: L0v Q1/Q2/Q3 4
      each, Q5 8; Ldv 24 each, Q5 96 (post-drop 16 each, Q5 80).
      Knife-edge on Ldv: 720 states - 712 post-drop, 8 fault-free.
    - Lcv (SUPPLEMENTARY crash-x-vct probe: {!budget_crash_only},
      [~vct:true], [~require_fault:true]), run ONLY so P16-A could be
      judged non-vacuously; NOT a section-4.6 matrix leg and not pinned as
      one: clean, decisive, 1136 states (1020 post-crash; 116 fault-free
      = L0v's graph, the slice identity), gates [Some 56] (Rv) /
      [Some 132] (Matched); Q1 60 (56 post-crash), Q2 60 (56 post-crash),
      Q3 28, Q5 116.

    {b Prediction verdicts (section 3), stated plainly.} Every clean drop
    or monkey verdict here is a NEGATIVE result (section 8.4): the phase's
    positive content is the third guard class, the first drop and monkey
    edges taken in decisive legs, and the section-6 mutations - not the
    cleanliness itself.

    - {b P16-A CONFIRMED}: the crash edge perturbs neither [network] nor
      [api_server] where Q1/Q2 genuinely fire. At [vct:false] Lc's rv
      content is VACUOUS ([interesting] 0, exactly P16-E), so the
      non-vacuous judgment rests on the supplementary Lcv probe: clean
      over 56 post-crash Q1-firing and 56 post-crash Q2-firing states,
      zero holds-violations. Gate and slice counts moved only with
      reachable-set growth (76 -> 464 / 116 -> 1136).
    - {b P16-B CONFIRMED, with one sub-clause measured AGAINST as
      worded}: Q3/Q5 vacuate PER CRASH INSTANT (the crash empties
      [ongoing_reconciles]; the firing states are post-restart), NOT as an
      aggregate collapse of the post-crash gate - the gate is 32 > 0 and
      DENSER post-crash than fault-free (32/388 vs 4/76), the same
      re-arming signature P15's own pinned L1 shows (post-crash R2-R4
      [interesting] 148-156 > 0 against gate 304).
    - {b P16-C, leg half CONFIRMED} (the Ld knife-edge above; Ldv shows
      the same shape at [vct:true] with 712 post-drop knife-edge states).
      The other half - mutation MD flipping Ld to [Refuted] naming Q5 -
      is the mutation stage's to measure, not judged here.
    - {b P16-D, leg half CONFIRMED} (the second-writer mechanism under
      Lm). MATRIX GAP, disclosed rather than smoothed: Q2's [interesting]
      is 0 on Lm at [vct:false], so the predicted "MS refutes Q2 on Lm
      and ONLY on Lm" cannot fire through Q2's premise on the matrix's
      own Lm - the mutation stage needs a [vct:true] monkey probe (Lmv)
      or a re-reading of where MS's witness can live. RESOLVED by the
      mutation stage: MS was run against exactly that Lmv probe (where
      Q2 fires under a real monkey edge) and measured INERT - the
      plain-update write path it mutates is DEAD CODE on every shipped
      graph, the SAME structural fact as Q4's exclusion (no shipped
      reconciler issues a plain [Update_request]; the monkey's candidate
      pods are the stored pods themselves, so its plain updates merge to
      no-ops before the stamping site). {b Scope of the witness, stated
      precisely:} [t_p16_regression]'s Q4 structural-vacuity pin observes
      only the PRODUCER conjunct of that diagnosis (the monkey is the sole
      plain-update source, and no controller ever issues one). The second
      conjunct - that the monkey's plain updates merge to [updated = old]
      and take the no-op branch BEFORE the stamping site (cluster.ml:748-755,
      api_server.ml:488-495) - is diagnosis only and is observed by NO
      staged test; indeed the pin establishes that monkey plain updates DO
      reach the api server, so MS's site is dead solely via that unmeasured
      equality branch, and a monkey that perturbed the pod would take the
      site live while the pin stayed green ([t_p16_mutation]'s MS header
      carries the full diagnosis). If the pin ever reddens, BOTH the Q4
      exclusion and MS's inertness must be revisited together.
    - {b P16-E CONFIRMED, measured not argued}: Q1/Q2/Q3 [interesting]
      = 0 on EVERY [vct:false] graph (76 / 464 / 744 / 1976 states) and
      > 0 on EVERY [vct:true] graph (L0v 4/4/4, Ldv 24/24/24, Lcv
      60/60/28); Q5 is the sole non-vacuous member at [vct:false]
      (4 / 36 / 24 / 88) and stays non-vacuous at [vct:true]
      (8 / 96 / 116). Consequence for reading this leg: a clean
      [Rv_list] verdict at [vct:false] is CONTENT-VACUOUS
      ([gate_states = Some 0]) and is pinned as vacuity, never as a pass.

    {b MD's converse-control caveat} (measured here, binding on the
    mutation stage): real, NON-fabricated Error responses matching a
    pending request exist WITHOUT any drop edge - knife-edge counts 4 on
    Lc (post-crash create-conflict replay), 24 on Lm, 4 on fault-free
    L0v, 8 in Ldv's fault-free slice - so "error response matching
    pending" must never be equated with "drop edge taken"; only the
    [drops >= 1] slice (384 of 384 on Ld) is drop-attributable.

    {b Section 5 re-measured on Lm specifically, not inherited}: a monkey
    edge injects a message without consuming one, yet the largest
    [Message.Pool.cardinal] anywhere is 2 (Lc / Lm / Lcv graphs; 1 on
    L0 / Ld / L0v / Ldv) against the ceiling 8, [max_rv_seen] peaks at 4
    against [rv_ceiling] 6 and [max_uid_seen] at 4 against [uid_ceiling]
    6. The predicted monkey orphan-inflation did not bind; no retune. *)

val check_objects_in_store_under_faults :
  ?depth:int ->
  ?req_drop:bool ->
  ?pod_monkey:bool ->
  Bound.t ->
  budget ->
  desired:int ->
  require_fault:bool ->
  fault_report
(** {b G7} (BUILD-SPEC-P17 section 4): the STORE-SIDE object family
    ({!Objects_in_store.store_family} = S1
    [etcd_objects_have_unique_uids], S2
    [each_object_in_etcd_is_weakly_well_formed], S3
    [each_object_in_etcd_has_at_most_one_controller_owner] - physically the
    inv1/inv2/inv3 records of {!Invariants.cluster_structural}, a filter,
    never a copy) checked by reachability over the fault product.

    {b What this leg is for.} It closes the fault-dimension triptych
    (BUILD-SPEC-P17 section 1): P14/P15 attributed crash sensitivity to
    where a guard LIVES (reconcile side vs network side), P16 measured the
    drop dimension on message-side guards. All three store members are
    guarded SERVER-SIDE in the api_server write handlers, so the predicted
    signature is the mirror image - crash-insensitive (the crash empties
    [ongoing_reconciles] and never touches [resources s]),
    drop-insensitive (a dropped request fabricates an Error response;
    the store write never happened), monkey-PREMISE-AMPLIFIED (the pod
    monkey drives create/update/update-status/delete through the very
    handlers the guards live in). Per BUILD-SPEC-P17 section 1 this is the
    first family whose LEVERAGE edge is the monkey (P14/P15's decisive
    edge was the crash, P16's the drop knife-edge; no earlier phase
    attributed its headline to a monkey edge), and the store-side novelty
    claim in its narrow, sweep-cited form lives in [objects_in_store.mli]
    (the base suite has asserted these members since P13, but only inside
    a UNION).

    {b The family is asserted ALONE - the masking trap, INVERTED.} Unlike
    the P14-P16 families, S1/S2/S3 ARE base-suite members: every prior
    TRAJECTORY-LEG assertion of them under a fault budget evaluated them
    only inside the conjunction of the full [always]/VSTS suites, where an
    earlier-firing member could mask them and no per-member [interesting]
    count was taken (the non-leg assertion sites - forged-state unit
    checks, [first_violated] name pins, fault-FREE per-member counts - are
    classified in [objects_in_store.mli]'s sweep). This leg asserts
    the three alone with per-member counts: the first unmasked store-side
    measurement. A [violated] naming any non-S1/S2/S3 member here means
    the lists were unioned somewhere: harness bug, not a finding.
    [t_p17_regression] pins the family as an INCLUSION in
    [Invariants.cluster_structural] by (name, source) pair - the
    DELIBERATE divergence from the P14-P16 disjointness pattern
    (BUILD-SPEC-P17 section 2-REVISED); the four existing disjointness
    guards remain in force (k3-strengthened to (name, source) pairs this
    same phase - strengthened, not removed).

    {b Same product graphs as P13-P16, by construction.} Same seed
    ([Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey
    ()], both options defaulting [false]), same [default_depth], same
    {!faulted_successors} product - the graph depends only on (seed,
    bound, budget, depth), never on the invariant list, so at P13's bound
    and the four matrix budgets the graphs ARE P16's L0 / Lc / Ld / Lm
    (76 / 464 / 744 / 1976 states) and the phases cross-check on
    [states] / [crash_witness_states] / [fault_free_states] and the
    achieved maxima. A [states] count that disagrees means the seed or
    bound drifted: investigate before reporting anything.

    {b No [?vct] - a deliberate scope cut (k6-class), disclosed.} The P16
    leg needed [?vct] because Q1-Q3's premises die without a [Get_request]
    producer; the store members' premises need only stored OBJECTS, which
    exist from the seed on every graph ([vct:false] included), so the vct
    dimension buys no de-vacuation here and its legs are deliberately out
    of scope this phase. A future vct leg would measure the same members
    over a PVC-bearing store - new content, not a repaired vacuity.

    {b [require_fault]} selects what [gate_states] counts, exactly as on
    {!check_req_resp_under_faults}: [false] counts states where SOME
    member's [interesting] fires (the non-vacuity floor, intended at
    [zero_budget]); [true] additionally requires {!budget_fault_taken}.
    NOTE the floor SATURATES here: S2's [interesting] (store non-empty)
    fires at every state because the seed itself stores the CR, so the
    union gate always equals the counted slice and the discriminating
    signal is in the PER-MEMBER counts (S1/S3 fire on proper subsets),
    measured over the replicas in [t_p17_store]. Consequence (P17-review
    disclosure): on these four graphs the union-interesting conjunct of
    the gate is identically true, so the gate pins verify ONLY the
    [require_fault] slice - trivializing (or dropping) the union conjunct
    would move no shipped pin. Its red-capability is carried by the
    per-member count pins, not by the gate; a future family whose union
    does NOT saturate would make the conjunct load-bearing again.

    {b MEASURED} (all at [desired = 1], the P13 bound shape, [depth = 40],
    [vct] absent; pinned once in [test/p17_witness.ml]; wall times from
    the B3 measurement run, same machine as the battery):

    - L0 ([zero_budget], [~require_fault:false]): [No_counterexample],
      [decisive = true], 76 states, [gate_states = Some 76] (saturated -
      see above), [crash_witness_states = 0], [fault_free_states = 76],
      [max_uid_seen = 3], [max_rv_seen = 2], both pruning flags [true].
      0.010 s. Per-member [interesting]: S1 52, S2 76, S3 52 - S1 is 0 at
      the seed (one stored object) and fires only after the first create,
      the spec section 4 prediction, measured.
    - Lc ({!budget_crash_only}, [~require_fault:true]): clean, decisive,
      464 states, [gate_states = Some 388] (= the whole post-crash
      slice), 388 / 76 crash-witness / fault-free, crash edge really
      taken, maxima 3 / 2. 0.059 s. Per-member all-states / post-crash:
      S1 296 / 244, S2 464 / 388, S3 296 / 244. {b PREDICTION CONFIRMED
      as a measured negative} (the P15-A mirror): the crash moves NO
      store-side truth - the store premises keep firing across the crash
      and all three members hold at every post-crash state.
    - Ld (drop-only [{0; 1; 0}], [~req_drop:true],
      [~require_fault:true]): clean, decisive, 744 states,
      [gate_states = Some 592] (= the post-drop slice),
      [fault_free_states = 152], drop edge really taken, maxima 3 / 2 -
      L0's exact values: the drop edge NEVER touches store content.
      0.130 s. Per-member all-states / post-drop: S1 376 / 272,
      S2 744 / 592, S3 376 / 272. {b HONEST NEGATIVE - the section 4
      "Ld premise counts ~ L0's" prediction is REFUTED under the density
      reading}: S1/S3 fire at 376/744 = 50.5% vs L0's 52/76 = 68.4% -
      the fabricated Error response stalls the reconciler's create on the
      dropped branch and dilutes the >= 2-objects slice. The mechanism
      half (store untouched) stands, measured via the maxima.
    - Lm (monkey-only [{0; 0; 1}], [~pod_monkey:true],
      [~require_fault:true]): clean, decisive, 1976 states,
      [gate_states = Some 1824] (= the post-monkey slice),
      [fault_free_states = 152], monkey edge really taken,
      [max_uid_seen = max_rv_seen = 4] - the ONLY [vct:false] graph where
      the maxima rise (P16-D's transitive-write datum, re-read here as
      the monkey's create genuinely landing in etcd). 0.782 s.
      Per-member all-states / post-monkey: S1 1624 / 1520, S2 1976 /
      1824, S3 1624 / 1520. {b PREDICTION CONFIRMED - the monkey is the
      leverage edge}: premise density rises to 82.2% (vs 68.4% L0,
      63.8% Lc, 50.5% Ld) and the churn rides the real handlers, yet all
      three members hold at every state: the server-side guards absorb
      it. The clean verdict is a negative result and is recorded as a
      measurement, never dressed as a pass.
    - MEASURED COINCIDENCE, asserted per leg in [t_p17_store]: S3's count
      equals S1's on all four graphs (52 / 296 / 376 / 1624) - the first
      pod create is the reconciler's and carries the controller ref, so
      the >= 2-objects and controller-ref slices coincide on THESE
      graphs. A scenario fact, not a law.

    {b Exclusion pins} (BUILD-SPEC-P17 section 3, measured in
    [t_p17_regression] over the L0 replica): E1's well-formed
    strengthening delta is extensionally EMPTY (0 of 76 states differ,
    kind-coverage control 0) and E2's contradictory premise is
    UNSATISFIABLE (0 of 76, vsts-kind control 76) - both exclusions
    measured, not asserted. See [objects_in_store.mli] for the upstream
    citations and the B2 audit verdicts. *)

val check_helper_invariants_under_faults :
  ?depth:int ->
  ?req_drop:bool ->
  ?pod_monkey:bool ->
  ?vct:bool ->
  Bound.t ->
  budget ->
  desired:int ->
  require_fault:bool ->
  fault_report
(** {b P18} (BUILD-SPEC-P18 section 4): the pod/PVC metadata family
    ({!Helper_invariants.helper_family} = H1
    [all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref],
    H2
    [all_pvcs_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_or_owner_ref]
    - the two portable always-members of
    [vstatefulset_controller/proof/helper_invariants.rs]; port renderings,
    disclosed deviations and the E1-E7 exclusion ledger live in
    [helper_invariants.mli]) checked by reachability over the fault
    product, asserted ALONE with per-member [interesting] counts - the
    P14-P16 DISJOINT-family pattern (no shipped suite contains either
    member; [t_p18_regression] pins the (name, source) disjointness).

    {b Shape: G7's clone with [?vct] back.} Same seed family
    ([Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey
    ~vct ()], the crash flag ON with the crash DIMENSION selected by the
    caller's budget), same [default_depth], same {!faulted_successors}
    product, same {!violated_of} naming, same
    [require_fault]/{!budget_fault_taken} gate. The ONE deviation from
    {!check_objects_in_store_under_faults} is [?vct] (default [false]):
    G7's omission was a disclosed k6-class scope cut, undone here because
    H2's premise needs a stored PVC and no [vct:false] graph ever mints
    one - the [vct:true] zero-budget leg (L0v) is H2's non-vacuity floor.
    The family CR is the SEEDED CR itself ([Scenario.vsts ~desired ~vct
    ()], exactly the object the seed marshals into the store), so the
    premises quantify over the scenario's own CR, never a forged twin.

    {b The five-leg matrix} (bound = P13's shape, [depth = 40],
    [desired = 1]; budget literals via the witness chain,
    [test/p18_witness.ml] deriving from p17/p16):
    L0 ([zero_budget], [vct:false], [~require_fault:false]) /
    Lc ({!budget_crash_only}, [vct:false], [~require_fault:true]) /
    Ld (drop-only [{0; 1; 0}], [~req_drop:true], [~require_fault:true]) /
    Lm (monkey-only [{0; 0; 1}], [~pod_monkey:true],
    [~require_fault:true]) / L0v ([zero_budget], {b [vct:true]},
    [~require_fault:false]). Graph identity: the product graph depends
    only on (seed, bound, budget, depth), never on the invariant list, so
    the four [vct:false] graphs must be EXACTLY P13-P17's 76 / 464 / 744 /
    1976 states and the L0v graph is P16's L0v (116 states,
    [test/p16_witness.ml] - same seed, bound, budget, depth). Any drift
    means the seed or bound moved: STOP and diagnose, never retune.

    {b The union gate is load-bearing again} (the G7 saturation
    disclosure's "future family whose union does not saturate", realised):
    [gate_states] counts states where SOME member's [interesting] fires
    (AND {!budget_fault_taken} at [require_fault:true]). H1's
    [interesting] (a stored Pod key in the CR's namespace with a
    [pod_name]-shaped name) is 0 at the seed - the store holds only the
    CR - and H2's (a stored [pvc_name]-shaped PVC key) is 0 on EVERY
    [vct:false] state, so the gate fires on a proper subset of every
    graph and its union conjunct carries red-capability, unlike G7's.
    Per-member counts are measured test-side over a LOCAL REPLICA
    ([t_p17_store]'s discipline: replica faithfulness asserted FIRST -
    the replica's state count = the leg's [states] - then fires-by-name
    over the all / post-crash / post-drop / post-monkey slices, then the
    union gate recomputed locally and asserted equal to [gate_states]).

    {b Honest-vacuity discipline (H2, P14 N5)}: on the four [vct:false]
    legs H2's per-member count 0 IS the result, asserted per leg; H2's
    strictly positive floor lives on L0v alone.

    {b MEASURED (B3, 2026-07-27; every spec section 4 prediction CONFIRMED
    BY NUMBER - BUILD-SPEC-P18 section 5 carries the full table; pins in
    [test/p18_witness.ml], asserted by [t_p18_helper]).} All five legs
    clean + DECISIVE with faithful local replicas. (1) Graphs exact:
    L0 76 / Lc 464 / Ld 744 / Lm 1976 (P13-P17 identity, no drift), L0v
    116 (= P16's). (2) H1 [interesting] = 52 / 296 / 376 / 1624 - the P17
    S1/S3 slice TO THE STATE, post-fault slices 244 (crash) / 272 (drop) /
    1520 (monkey); asserted per leg as scenario facts, never a law.
    (3) H2 = 0 on every [vct:false] state (honest vacuity, pinned per
    leg) with the strictly positive L0v floor: 80 of 116 states. (4) {b
    The phase headline}: Lm clean + decisive across 1520 post-monkey
    H1-premise states - the rely-UNCONSTRAINED but candidate-RESTRICTED
    monkey cannot violate H1 on this graph (the shipped monkey only; a
    fabricating monkey remains future surface, spec section 8.6).
    (5) Lm [max_uid_seen = 4] (= P16's Lm constant, [max_rv_seen = 4])
    via monkey-DELETE + reconciler re-create, never "create on a live
    key lands" (BUILD-SPEC-P17.md:226's literal reading is false - such
    a create is rejected [Object_already_exists]). Gates: 52 / 244 /
    272 / 1520 / 80 - equal to the fault-slice H1 count on every
    [vct:false] leg, and on L0v equal to H2's own count (the 68
    H1-firing states are a measured strict subset of the 80 H2-firing
    ones: the reconciler creates the ordinal's PVC before its pod).
    Exclusion pins measured: E1 uid-exact-vs-H1 delta 0 on L0; E4
    owner-ref-carrying stored PVCs 0 with control 80 on L0v. Wall times
    0.08 / 0.18 / 0.48 / 2.26 / 0.05 s. *)

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

val check_msg_provenance_under_faults :
  ?depth:int ->
  ?req_drop:bool ->
  ?pod_monkey:bool ->
  Bound.t ->
  budget ->
  desired:int ->
  require_fault:bool ->
  fault_report
(** {b P19} (BUILD-SPEC-P19 section 4): the message-provenance family
    ({!Msg_provenance.provenance_family} = M1
    [every_msg_from_vsts_controller_carries_vsts_key], M2
    [all_requests_from_pod_monkey_are_api_pod_requests], M3
    [all_requests_from_builtin_controllers_are_api_delete_requests], M4
    [no_pending_request_to_api_server_from_api_server_or_external] - port
    renderings, disclosed deviations and the upstream citations live in
    [msg_provenance.mli]; the E1'-E5' exclusion ledger in BUILD-SPEC-P19
    section 3) checked by reachability over the fault product, asserted
    ALONE with per-member [interesting] counts - the P14-P16/P18
    DISJOINT-family pattern (no shipped suite contains any member;
    [t_p19_regression] pins the (name, source) disjointness).

    {b Shape: the P18 leg's clone MINUS [?vct] - the k6-class cut
    returns.} Same seed family ([Scenario.vsts_seed_faults ~desired
    ~crash:true ~req_drop ~pod_monkey ()], exactly G7's - the crash flag
    ON with the crash DIMENSION selected by the caller's budget), same
    [default_depth], same {!faulted_successors} product, same
    {!violated_of} naming, same [require_fault]/{!budget_fault_taken}
    gate. The ONE deviation from {!check_helper_invariants_under_faults}
    is that [?vct] is ABSENT: P18 re-admitted it because H2's premise
    needs a stored PVC, but no P19 member's premise reads PVCs or volumes
    at all (all four quantify over
    [Message.Pool.distinct (Cluster.in_flight s)] only), so the vct
    dimension buys no de-vacuation and its legs are deliberately out of
    scope this phase - the same disclosure class as
    {!check_objects_in_store_under_faults}'s cut, with the stronger
    justification (BUILD-SPEC-P19 section 8.2).

    {b The four-leg matrix} (bound = P13's shape, [depth = 40],
    [desired = 1]; budget literals via the witness chain):
    L0 ([zero_budget], [~require_fault:false]) /
    Lc ({!budget_crash_only}, [~require_fault:true]) /
    Ld (drop-only [{0; 1; 0}], [~req_drop:true], [~require_fault:true]) /
    Lm (monkey-only [{0; 0; 1}], [~pod_monkey:true],
    [~require_fault:true]). Graph identity: the product graph depends
    only on (seed, bound, budget, depth), never on the invariant list, so
    the four graphs must be EXACTLY P13-P18's 76 / 464 / 744 / 1976
    states. Any drift means the seed or bound moved: STOP and diagnose,
    never retune.

    {b Honest-vacuity discipline (M3, P14 N5)}: no vsts-spine graph fires
    the builtin controller (BUILD-SPEC-P19 section 5 prediction 3), so
    M3's per-member count 0 on all four legs IS the expected result,
    asserted per leg; its strictly positive floor lives in the ORPHAN
    REPLICA owned by [t_p19_provenance] (spec section 4) - a test-level
    replica over the generic spine, NOT a leg of this function. M1 is
    MODEL-CONDITIONAL (claimed on the vsts spine only); the orphan
    replica measures it as a live RED CONTROL, never asserts it
    ([msg_provenance.mli], spec section 8.5).

    {b [require_fault]} selects what [gate_states] counts, exactly as on
    the sibling legs: [false] counts states where SOME member's
    [interesting] fires (the non-vacuity floor, intended at
    [zero_budget]); [true] additionally requires {!budget_fault_taken}.

    {b MEASURED (B3-B5, 2026-07-27; every BUILD-SPEC-P19 section 5
    prediction CONFIRMED BY NUMBER - that section carries the full table;
    pins in [test/p19_witness.ml], asserted by [t_p19_provenance]).} All
    four legs clean + DECISIVE with faithful local replicas (replica
    [states_seen] = leg [states] on all four; recomputed union gates =
    [gate_states] on all four). (1) Graphs exact: L0 76 / Lc 464 / Ld 744 /
    Lm 1976 - the P13-P18 identity, no drift. (2) Gates 32 / 296 / 448 /
    1824, load-bearing (the seed's in-flight pool is EMPTY, so the gate is
    a PROPER subset on L0/Lc/Ld). (3) Per-member [interesting]:
    M1 16 / 156 / 64 / 368; M2 0 / 0 / 0 / 832 (its premise needs the
    monkey budget); M3 0 on EVERY leg (the honest vacuity above), with its
    strictly positive floor 679 of 1518 states on the orphan replica;
    M4 16 / 208 / 448 / 1216. (4) The orphan replica additionally refutes
    M1 asserted ALONE ([check_safety] = [Refuted], [first_violated] naming
    M1 - the live RED CONTROL, forge-free) while M2/M3/M4 stay green
    there. CPU times ([Sys.time], leg-call-only) 0.012 / 0.067 / 0.133 /
    0.813 s, replica 0.475 s. *)

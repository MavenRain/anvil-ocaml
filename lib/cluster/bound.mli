(** The explicit bounding policy for {!Cluster.enabled_successors}
    (architecture §4, finding 14).

    Several cluster [Step] families range over unbounded domains: an
    [APIServerStep] over any in-flight message, a [PodMonkeyStep] over any pod,
    uid / resource-version / rpc-id counters over all of [nat]. A computable
    successor enumeration must clip each domain, and — this is the point of
    finding 14 — the clipping is {b soundness-critical}: too tight a bound
    silently excludes the very interleavings a safety invariant targets, making
    a model-checking pass pass vacuously.

    So the policy is lifted out of the enumerator into this one record, and
    {b every field is documented with the bug class its bound may exclude}. The
    model checker (Phase 5) reports the achieved bound against these caps, and
    the enumerator must never impose a hidden cap beyond what [t] states. *)

type t = {
  max_in_flight : int;
      (** How many distinct in-flight messages are treated as deliverable / as
          [recv] candidates per step. Excludes message-reordering bugs that
          need more than this many messages simultaneously in flight. *)
  max_objects_per_kind : int;
      (** How many objects of a kind the pod-monkey / schedule enumeration
          ranges over. Excludes object-count-symmetry bugs (e.g. a replica
          fan-out) that only manifest above this many objects. *)
  max_controllers : int;
      (** How many controller ids the controller / external / restart
          enumeration ranges over. Excludes multi-controller interference bugs
          needing more coexisting controllers than this. *)
  uid_ceiling : int;
      (** The largest uid value the api-server allocator is allowed to reach.
          Excludes uid-reuse / dangling-owner-reference bugs that need uids
          above the ceiling. *)
  rv_ceiling : int;
      (** The largest resource-version the api-server allocator is allowed to
          reach. Excludes stale-resource-version / optimistic-concurrency bugs
          that need more writes than this. *)
  reconcile_ceiling : int;
      (** The largest per-controller [reconcile_id] (number of reconcile
          INVOCATIONS) any run may reach. Excludes
          multi-reconcile-interference / steady-state-re-reconcile bugs that
          need more than this many invocations. Like [uid_ceiling] /
          [rv_ceiling] it is a MULTI-STEP exploration limit, reserved for the
          checker; P2 does not enforce it. *)
  max_reconcile_depth : int;
      (** The reconcile-step fuel per reconcile round (bounds the run/continue
          chain). Excludes long-reconcile-chain bugs deeper than this. *)
  monkey_forge : Pod.t list;
      (** {b P20 (BUILD-SPEC-P20 §4.2): extra pod-monkey candidates that are NOT
          required to be present in etcd.}

          {b Why this is a BOUND and not an adversary.} Every other field here
          NARROWS a domain the port's enumerator would otherwise have to range
          over infinitely. This one WIDENS one back, and it belongs in the same
          record for the reason [max_objects_per_kind] does:
          {!Cluster.enabled_successors} already documents its pod-monkey
          candidate set as a SEARCH decision tied to that cap
          ([cluster.ml:744-747] — "candidate pods are the stored Pod objects,
          capped by [max_objects_per_kind]. This excludes pod-monkey states
          reached from pods never present in etcd"). Upstream Anvil's monkey has
          precondition [true] on an ARBITRARY [Pod] (pod_monkey/state_machine.rs
          :8/:32/:54/:79, ported verbatim at [pod_monkey.ml:58/:73/:88/:104]),
          so the port's monkey is not a WEAKER MODEL than upstream's — it is the
          SAME model under a candidate restriction. Listing a pod here widens
          the search back toward upstream's true model on that one axis; it does
          not add an actor, a step, a flag or a fault dimension, and nothing in
          [Cluster.cluster_state] observes it.

          {b THE DELIBERATE ASYMMETRY, disclosed.} Forged candidates are
          appended AFTER the [take max_objects_per_kind] of the stored pods and
          are themselves NOT subject to that cap ([cluster.ml:748-758]). This is
          intentional: the stored list is DERIVED and unbounded in principle, so
          it needs a cap; this list is an explicit, finite, hand-authored
          constant, and capping it could silently drop the very witness a leg
          exists to produce (a forge list longer than [max_objects_per_kind]
          would be truncated with no diagnostic). The cost of the asymmetry is
          that the per-state monkey fan-out is
          [max_objects_per_kind + List.length monkey_forge], not
          [max_objects_per_kind] — a reader budgeting the state space must add
          the two.

          {b Default [[]], and that default is PIN-PRESERVING.}
          {!Cluster_check.state_equal} / [state_hash]
          ([cluster_check.ml:48-58] / [:75-87]) and
          {!Fault_check.faulted_equal} / [faulted_hash]
          ([fault_check.ml:46-48] / [:54-55]) read only
          [Cluster.cluster_state] (plus, for the latter pair, the three fault
          counters); none of the four reads a [Bound.t]. With [monkey_forge =
          []] the appended list is empty and the successor list is
          element-for-element what it was before this field existed. That was
          MEASURED, not merely argued, when the field landed: the five committed
          graph pins (L0 76 / Lc 464 / Ld 744 / Lm 1976 / L0v 116) are unchanged
          with the field present and defaulted. *)
}

(** A small default suitable for unit tests and shallow BMC. Not a claim of
    adequacy: any assurance run must justify its bounds against the invariant
    it checks (finding 14) and report the achieved bound. *)
val default : t

(** Which fields P2 actually consumes. Only [max_in_flight], [max_objects_per_kind],
    [max_controllers] and (since P20) [monkey_forge] bound the SINGLE-STEP
    {!Cluster.enabled_successors} enumeration (the first three clip the per-step
    [recv] / object / controller domains; [monkey_forge] EXTENDS the pod-monkey
    candidate domain, the one axis where the port clipped BELOW upstream's own
    model — see the field's own note).
    [uid_ceiling], [rv_ceiling], [reconcile_ceiling] and [max_reconcile_depth]
    are MULTI-STEP exploration limits: they bound a whole run (uid/rv growth,
    reconcile-invocation count, reconcile-chain depth), so a single successor
    step cannot observe them. They are reserved for the Phase-5 depth-bounded
    model-checking driver and are NOT yet consumed in P2 — no reader should
    assume P2 enforces them. *)

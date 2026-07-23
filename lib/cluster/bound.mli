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
  max_reconcile_depth : int;
      (** The reconcile-step fuel per reconcile round (bounds the run/continue
          chain). Excludes long-reconcile-chain bugs deeper than this. *)
}

(** A small default suitable for unit tests and shallow BMC. Not a claim of
    adequacy: any assurance run must justify its bounds against the invariant
    it checks (finding 14) and report the achieved bound. *)
val default : t

(** Which fields P2 actually consumes. Only [max_in_flight], [max_objects_per_kind]
    and [max_controllers] bound the SINGLE-STEP {!Cluster.enabled_successors}
    enumeration (they clip the per-step [recv] / object / controller domains).
    [uid_ceiling], [rv_ceiling] and [max_reconcile_depth] are MULTI-STEP
    exploration limits: they bound a whole run (uid/rv growth, reconcile-chain
    depth), so a single successor step cannot observe them. They are reserved for
    the Phase-5 depth-bounded model-checking driver and are NOT yet consumed in
    P2 — no reader should assume P2 enforces them. *)

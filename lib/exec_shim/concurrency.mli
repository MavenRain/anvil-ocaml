(** P7 exec-shim: the cooperative-concurrency abstraction.

    Anvil source: the [Concurrency] capability behind the reconcile manager
    (executable spine, {e not} the spec). We reproduce only the four monadic
    operations a reconcile driver actually needs.

    The signature is deliberately {b Lwt-shaped} ([return]/[bind]/[both]/[sleep]
    genuinely are Lwt's shapes), so a real [Lwt] backend drops in without changing
    a line of {!Controller_runtime}. The backend shipped in this phase is
    {!Direct}, the pure identity monad: the whole executable core is then
    DETERMINISTIC and depends on no async library.

    {b Honest limit (stated up front, per the architecture's anti-over-claim
    discipline).} {!Direct} does {e not} model interleaving: [both a b] evaluates
    [a] then [b] left-to-right, and [sleep] returns immediately. This shim gives a
    runnable, deterministic controller, {e not} a concurrency model. Exploring
    interleavings is the job of the P4 property harness and the P5 bounded model
    checker over [enabled_successors], never of this monad. A backend that DOES
    model concurrency (Lwt over a real scheduler) would satisfy the same signature
    but carries no extra soundness for the assurance story. *)

module type CONCURRENCY = sig
  type 'a t
  (** A computation yielding an ['a]. *)

  val return : 'a -> 'a t
  (** [return x] is the already-completed computation of [x]. *)

  val bind : 'a t -> ('a -> 'b t) -> 'b t
  (** Monadic sequencing: run the first computation, feed its result to [f].
      Value-first argument order, matching {!Res.bind}. *)

  val both : 'a t -> 'b t -> ('a * 'b) t
  (** Run two computations and pair their results. On {!Direct} this is
      left-to-right sequential (see the honest limit above), never parallel. *)

  val sleep : seconds:float -> unit t
  (** A cooperative delay. On {!Direct} it is an immediate no-op (the deterministic
      core has no wall clock); a real backend suspends the fiber. *)
end

(** The identity-monad backend: ['a t = 'a]. Deterministic, dependency-free, and
    the only backend this phase ships. [run] extracts the value (identity here);
    it exists so callers can name the pure result without exposing that
    ['a t = 'a] at every use site. *)
module Direct : sig
  include CONCURRENCY with type 'a t = 'a

  val run : 'a t -> 'a
  (** Extract the completed value. The identity function on {!Direct}; a real
      backend would spin its event loop to completion here. *)
end

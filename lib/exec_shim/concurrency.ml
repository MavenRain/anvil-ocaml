(* P7 exec-shim: the cooperative-concurrency backend. See concurrency.mli for the
   CONCURRENCY signature and the honest-limit documentation. [Direct] is the pure
   identity monad: deterministic, dependency-free, no interleaving. *)

module type CONCURRENCY = sig
  type 'a t

  val return : 'a -> 'a t
  val bind : 'a t -> ('a -> 'b t) -> 'b t
  val both : 'a t -> 'b t -> ('a * 'b) t
  val sleep : seconds:float -> unit t
end

module Direct = struct
  type 'a t = 'a

  let return x = x
  let bind x f = f x
  let both a b = (a, b) (* strict OCaml evaluates [a] before [b], left-to-right *)
  let sleep ~seconds:_ = ()
  let run x = x
end

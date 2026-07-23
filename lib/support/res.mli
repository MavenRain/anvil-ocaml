(** The one partiality channel. Every partial function in [anvil] returns
    into ['a t] rather than raising. No two-arm [match] on [result] appears
    outside this file. *)

(** Transparent on purpose: [Ok]/[Error] are the ambient constructors and
    sealing them would force a wrapper at every arm. *)
type 'a t = ('a, Err.t) result

val ok : 'a -> 'a t
val error : Err.t -> 'a t
val map : ('a -> 'b) -> 'a t -> 'b t
val bind : 'a t -> ('a -> 'b t) -> 'b t

(** Left-biased: the first error wins. *)
val both : 'a t -> 'b t -> ('a * 'b) t

val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
val ( and* ) : 'a t -> 'b t -> ('a * 'b) t
val ( and+ ) : 'a t -> 'b t -> ('a * 'b) t

(** Stack an {!Err.At} frame naming the layer and function, so a deep failure
    reads as a path. *)
val context : layer:string -> fn:string -> 'a t -> 'a t

(** Bridge an option-returning total variant into the partiality channel. *)
val of_option : none:Err.t -> 'a option -> 'a t

(** Sequence a list of results, preserving order; the first error wins. *)
val all : 'a t list -> 'a list t

(** [map_m f xs] is [all (List.map f xs)]. *)
val map_m : ('a -> 'b t) -> 'a list -> 'b list t

(** Fallible left fold; the first error wins. *)
val fold_m : ('acc -> 'x -> 'acc t) -> 'acc -> 'x list -> 'acc t

(* Implementation of {!Multiset}. The carrier is a plain list treated as a bag:
   every public operation is order-insensitive, and [equal] compares
   multiplicities, so no caller can observe the list order. Written with list
   combinators (no imperative loop, no naked recursion) per the convention
   firewall. *)

module type ELEMENT = sig
  type t

  val equal : t -> t -> bool
end

module Make (E : ELEMENT) = struct
  type elt = E.t
  type t = elt list

  let empty : t = []
  let singleton x : t = [ x ]
  let is_empty (m : t) = match m with [] -> true | _ :: _ -> false
  let add x (m : t) : t = x :: m
  let union (a : t) (b : t) : t = List.append a b
  let mem x (m : t) = List.exists (E.equal x) m
  let count x (m : t) = List.length (List.filter (E.equal x) m)
  let cardinal (m : t) = List.length m
  let to_list (m : t) = m
  let of_list (xs : elt list) : t = xs

  (* Drop the first element [equal] to [x]; [removed] latches so exactly one
     occurrence is taken. Absent [x] yields [None] (the delivery guard). *)
  let remove_one x (m : t) : t option =
    let removed, rev_kept =
      List.fold_left
        (fun (removed, kept) y ->
          if (not removed) && E.equal x y then (true, kept)
          else (removed, y :: kept))
        (false, []) m
    in
    if removed then Some (List.rev rev_kept) else None

  let distinct (m : t) : elt list =
    List.rev
      (List.fold_left
         (fun acc x -> if List.exists (E.equal x) acc then acc else x :: acc)
         [] m)

  let equal (a : t) (b : t) =
    Int.equal (cardinal a) (cardinal b)
    && List.for_all (fun x -> Int.equal (count x a) (count x b)) (distinct a)
end

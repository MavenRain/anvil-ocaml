type 'a t = ('a, Err.t) result

let ok x = Ok x
let error e = Error e

(* The sanctioned two-arm matches on [result] live here and nowhere else. *)
let map f = function Ok x -> Ok (f x) | Error _ as e -> e
let bind m f = match m with Ok x -> f x | Error _ as e -> e

let both a b =
  match a with
  | Error _ as e -> e
  | Ok x -> ( match b with Error e -> Error e | Ok y -> Ok (x, y) )

let ( let* ) = bind
let ( let+ ) m f = map f m
let ( and* ) = both
let ( and+ ) = both

let context ~layer ~fn = function
  | Ok _ as k -> k
  | Error inner -> Error (Err.At { site = { layer; fn }; inner })

let of_option ~none = function Some x -> Ok x | None -> Error none

let all xs =
  let step acc x =
    let* ys = acc in
    let+ y = x in
    y :: ys
  in
  map List.rev (List.fold_left step (Ok []) xs)

let map_m f xs = all (List.map f xs)

let fold_m f init xs =
  List.fold_left (fun acc x -> bind acc (fun a -> f a x)) (Ok init) xs

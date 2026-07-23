type site = { layer : string; fn : string }

type t =
  | Kind_mismatch of { expected : string; found : string }
  | Malformed_value of { kind : string; detail : string }
  | Missing_field of { owner : string; field : string }
  | Decode_error of { typ : string; detail : string }
  | At of { site : site; inner : t }

let rec show = function
  | Kind_mismatch { expected; found } ->
    "kind mismatch: expected " ^ expected ^ ", found " ^ found
  | Malformed_value { kind; detail } ->
    "malformed marshalled value for " ^ kind ^ ": " ^ detail
  | Missing_field { owner; field } ->
    "required field absent: " ^ owner ^ "." ^ field
  | Decode_error { typ; detail } -> "cannot decode " ^ typ ^ ": " ^ detail
  | At { site; inner } ->
    site.layer ^ "." ^ site.fn ^ " <- " ^ show inner

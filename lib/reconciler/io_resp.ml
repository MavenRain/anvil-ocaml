(* Anvil source: reconciler/spec/io.rs (is_some_k_*_resp_view +
   extract_some_k_*_resp_view). Each viewer fuses the boolean test and the
   payload extractor into one total function returning the [res] payload as an
   option-of-result. Every body enumerates the full Io.response_view and
   Api_method.api_response sums (no wildcard). *)

let k_list_resp (resp : 'a Io.response_view option) :
    (Dynamic_object.t list, Api_method.api_error) result option =
  match resp with
  | None -> None
  | Some (Io.External_response _) -> None
  | Some (Io.K_response r) -> (
    match r with
    | Api_method.List_response { res } -> Some res
    | Api_method.Get_response _ | Api_method.Create_response _
    | Api_method.Delete_response _ | Api_method.Update_response _
    | Api_method.Update_status_response _ | Api_method.Get_then_delete_response _
    | Api_method.Get_then_update_response _
    | Api_method.Get_then_update_status_response _ ->
      None)

let k_create_resp (resp : 'a Io.response_view option) :
    (Dynamic_object.t, Api_method.api_error) result option =
  match resp with
  | None -> None
  | Some (Io.External_response _) -> None
  | Some (Io.K_response r) -> (
    match r with
    | Api_method.Create_response { res } -> Some res
    | Api_method.Get_response _ | Api_method.List_response _
    | Api_method.Delete_response _ | Api_method.Update_response _
    | Api_method.Update_status_response _ | Api_method.Get_then_delete_response _
    | Api_method.Get_then_update_response _
    | Api_method.Get_then_update_status_response _ ->
      None)

let k_get_then_delete_resp (resp : 'a Io.response_view option) :
    (unit, Api_method.api_error) result option =
  match resp with
  | None -> None
  | Some (Io.External_response _) -> None
  | Some (Io.K_response r) -> (
    match r with
    | Api_method.Get_then_delete_response { res } -> Some res
    | Api_method.Get_response _ | Api_method.List_response _
    | Api_method.Create_response _ | Api_method.Delete_response _
    | Api_method.Update_response _ | Api_method.Update_status_response _
    | Api_method.Get_then_update_response _
    | Api_method.Get_then_update_status_response _ ->
      None)

let k_get_then_update_status_resp (resp : 'a Io.response_view option) :
    (Dynamic_object.t, Api_method.api_error) result option =
  match resp with
  | None -> None
  | Some (Io.External_response _) -> None
  | Some (Io.K_response r) -> (
    match r with
    | Api_method.Get_then_update_status_response { res } -> Some res
    | Api_method.Get_response _ | Api_method.List_response _
    | Api_method.Create_response _ | Api_method.Delete_response _
    | Api_method.Update_response _ | Api_method.Update_status_response _
    | Api_method.Get_then_delete_response _ | Api_method.Get_then_update_response _
      ->
      None)

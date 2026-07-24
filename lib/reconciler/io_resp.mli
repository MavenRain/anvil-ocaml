(** Anvil source: reconciler/spec/io.rs
    ([is_some_k_*_resp_view] + [extract_some_k_*_resp_view]).

    Anvil splits every response test into a boolean [is_some_k_X_resp_view] and
    a payload extractor [extract_some_k_X_resp_view], used together at each call
    site as [is_some && extract is Ok]. Each pair is fused here into one total
    viewer that returns the response's [res] payload as an option-of-result:
    [Some res] iff the response is present, a {!Io.K_response}, and of the
    matching kind; [None] for absent / external / other-kind responses. *)

(** Anvil [is_some_k_list_resp_view] + [extract_some_k_list_resp_view]. [Some
    res] iff [resp] is [Some (K_response (List_response _))]; [None] for absent /
    external / other-kind responses. *)
val k_list_resp :
  'a Io.response_view option ->
  (Dynamic_object.t list, Api_method.api_error) result option

(** Anvil [is_some_k_create_resp_view] + [extract_some_k_create_resp_view].
    [Some res] iff [resp] is [Some (K_response (Create_response _))]. *)
val k_create_resp :
  'a Io.response_view option ->
  (Dynamic_object.t, Api_method.api_error) result option

(** Anvil [is_some_k_get_then_delete_resp_view] +
    [extract_some_k_get_then_delete_resp_view]. [Some res] iff [resp] is
    [Some (K_response (Get_then_delete_response _))]; the [Ok] payload is [()]. *)
val k_get_then_delete_resp :
  'a Io.response_view option -> (unit, Api_method.api_error) result option

(** Anvil [is_some_k_get_then_update_resp_view] +
    [extract_some_k_get_then_update_resp_view]. [Some res] iff [resp] is
    [Some (K_response (Get_then_update_response _))]. *)
val k_get_then_update_resp :
  'a Io.response_view option ->
  (Dynamic_object.t, Api_method.api_error) result option

(** Anvil [is_some_k_get_then_update_status_resp_view] +
    [extract_some_k_get_then_update_status_resp_view]. [Some res] iff [resp] is
    [Some (K_response (Get_then_update_status_response _))]. *)
val k_get_then_update_status_resp :
  'a Io.response_view option ->
  (Dynamic_object.t, Api_method.api_error) result option

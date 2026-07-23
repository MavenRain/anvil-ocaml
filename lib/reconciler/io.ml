type void = |

type 'ereq request_view =
  | K_request of Api_method.api_request
  | External_request of 'ereq

type 'eresp response_view =
  | K_response of Api_method.api_response
  | External_response of 'eresp

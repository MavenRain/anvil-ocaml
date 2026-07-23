type t = {
  max_in_flight : int;
  max_objects_per_kind : int;
  max_controllers : int;
  uid_ceiling : int;
  rv_ceiling : int;
  max_reconcile_depth : int;
}

let default =
  {
    max_in_flight = 8;
    max_objects_per_kind = 4;
    max_controllers = 2;
    uid_ceiling = 16;
    rv_ceiling = 32;
    max_reconcile_depth = 16;
  }

(* Anvil source: Map<int, _> from vstd, used for the cluster's
   [controller_and_externals] and [controller_models] indexed by a controller
   id. The ordered [bindings] give a deterministic controller-iteration order
   for the bounded successor enumeration. *)
include Map.Make (Int)

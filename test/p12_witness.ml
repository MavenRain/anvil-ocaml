(* BUILD-SPEC-P12 review NIT-4: the single source of truth for the P12 witness
   bound and the measured [1;1] gate-state pin, shared by [t_p12_concurrent] and
   [t_p12_mutation] (a non-test module, so dune links it into both exes). Keeping
   [p12_bound] and [pinned_gate_states] here means a future re-tune cannot drift
   the two P12 exes into asserting different [1;1] witnesses.

   Firewall: List/fold combinators only, no loop keywords, no wildcard match. *)

let p12_bound ~(desireds : int list) : Bound.t =
  let n = List.length desireds in
  let dmax = List.fold_left max 0 desireds in
  {
    Bound.max_in_flight = 8;
    max_objects_per_kind = dmax + n + 2;
    max_controllers = 1;
    (* STAYS 1 - two reconciles of ONE controller *)
    uid_ceiling = dmax + n + 4;
    rv_ceiling = dmax + n + 4;
    reconcile_ceiling = n + 1;
    (* n concurrent starts need ceiling >= n *)
    max_reconcile_depth = 24;
  }

(* The witness: two 1-replica CRs, the cheapest >= 2-concurrent seed. *)
let witness_desireds : int list = [ 1; 1 ]

(* PINNED from the decisive fair:true [1;1] graph (MEASURED on the anvil-ocaml
   switch): the count of reachable states with >= 2 concurrent ongoing reconciles. *)
let pinned_gate_states : int = 6952

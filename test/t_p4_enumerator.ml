(* BUILD-SPEC P4 §4 "t_p4_enumerator" — the finding-14 enumerator obligation
   (architecture finding 14 = enumerator confirm-by-mutation).

   A passing [t_p4_invariants] proves the invariant conjunctions are never
   VIOLATED in their regimes. That is worthless if the invariants are only ever
   evaluated on states where their non-trivial precondition is FALSE — a predicate
   that is vacuously true (its antecedent never fires) contributes no assurance.
   This test discharges the other half of confirm-by-mutation
   ([[feedback-confirm-tests-by-mutation]]): for EVERY invariant across BOTH sets
   ([Invariants.all]) PLUS the ESR goal ([Invariants.liveness_goal], #11) — sixteen
   witnesses in all — it proves the invariant's [interesting] state (invariants.mli)
   is ACTUALLY REACHED by a bounded exploration of [Cluster.enabled_successors]
   under [Bound.default], over the UNION of the reachable scenario seeds. If a
   witness is never reached its [holds] was only ever checked vacuously; the harness
   FAILS that case naming the invariant AND the seed/extension that admits it (spec
   §4: "do NOT silently pass").

   ---- the seed union (architecture finding 14: the single-CR scale-up [seed]
        cannot reach the [interesting] preconditions of #6/#7/#15/#16, so the
        scenario is widened with reachable states that de-vacuise them) ----------
     - [seed ~desired:2]                — the canonical single-CR scale-up.
     - [seed_multi ~desireds:[2;3]]     — two CRs → >=2 concurrent ongoing
       reconciles, de-vacuising #6 every_ongoing_reconcile_has_unique_id.
     - [seed_with_pods ~desired:1 ~existing:2] and [~desired:2 ~existing:3] — a
       scale-DOWN (existing > desired) so After_list_pods records
       [filtered_pods = Some (_ :: _)], de-vacuising #15 filtered_pods_invariant_
       matrix and #16 local_pods_are_bound_to_vrs_with_key; and immediately
       matching pods for #11 current_state_matches.
     - [seed_with_orphan ~desired:1]    — an orphan pod whose owner uid is absent,
       so the garbage collector emits an in-flight DELETE, de-vacuising #7
       garbage_collector_does_not_delete_vrs_pods.

   ---- exploration strategy (no visited set needed: every walk is fuel/depth-
        bounded, so termination is structural) ---------------------------------
     (A) [~fair:false] (full nondeterminism: crash / req-drop / pod-monkey enabled)
         from every seed: a greedy reconcile-forward drive (first productive
         successor) with a per-node full one-step fan-out (reaches the pod-monkey /
         GC / drop neighbours the forward spine skips — the foreign-request
         witnesses #8/#14), plus many random full-successor traces (interleavings
         the drive misses, e.g. the #6 second concurrent reconcile).
     (B) [~fair:true] (crash / req-drop / pod-monkey DISABLED) from every seed: a
         reconcile-forward drive that converges the reconcile, exercising the
         steady-state witnesses #12 (ongoing at the CR), #13 (scheduled|ongoing at
         the CR), #11 (matching pods) on the fair suffix the eventually_always
         invariants are asserted over.

   Each visited state ORs every not-yet-witnessed invariant's [interesting] into a
   satisfaction table (folded incrementally; the state sequence is never retained).
   A per-invariant Alcotest case then asserts its witness was seen across the union.

   Convention firewall (anvil-ocaml) honoured here too: no while/for/loop/return/
   break/continue (bounded recursion + List/Option combinators); no [_ ->] on any
   finite sum (the only matches are the exhaustive list [[] | _ :: _]); no two-arm
   match on option/result (Option.fold / Option.value); no exceptions in the logic
   (Alcotest.check is the sanctioned failure primitive). *)

module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants

let controller_id : int = Scenario.controller_id
let cr : Vreplica_set.t = Scenario.vrs ~desired:2
let b : Bound.t = Bound.default

(* The sixteen witnesses: both invariant sets ([Invariants.all], fifteen) plus the
   ESR goal #11 [current_state_matches] ([Invariants.liveness_goal]). *)
let witnesses : Invariants.invariant list =
  Invariants.all ~cr ~controller_id @ [ Invariants.liveness_goal ~cr ]

(* ---- the satisfaction table: invariant name -> "its interesting was reached" -- *)

let sat : (string, bool) Hashtbl.t = Hashtbl.create 32

let () =
  List.iter (fun (i : Invariants.invariant) -> Hashtbl.replace sat i.name false) witnesses

let is_sat (name : string) : bool =
  Option.value ~default:false (Hashtbl.find_opt sat name)

let n_sat () : int =
  Hashtbl.fold (fun _ v acc -> if v then acc + 1 else acc) sat 0

let all_sat () : bool = n_sat () = List.length witnesses

(* OR each not-yet-witnessed invariant's [interesting] over one reached state. *)
let visit (s : Cluster.cluster_state) : unit =
  List.iter
    (fun (i : Invariants.invariant) ->
      if (not (is_sat i.name)) && i.interesting s then
        Hashtbl.replace sat i.name true)
    witnesses

(* ---- exploration primitives -------------------------------------------------- *)

let succs (s : Cluster.cluster_state) : (Step.t * Cluster.cluster_state) list =
  Cluster.enabled_successors b Scenario.cluster s

(* Visit every one-step successor of [s] (full enabled set, failure steps too). *)
let fan_out (s : Cluster.cluster_state) : unit =
  List.iter
    (fun ((_step : Step.t), (s' : Cluster.cluster_state)) -> visit s')
    (succs s)

(* (A)/(B) greedy reconcile-forward drive with a per-node full fan-out. Bounded by
   [fuel]; total via [List.nth_opt]; short-circuits once every witness is in. *)
let rec drive (fuel : int) (s : Cluster.cluster_state) : unit =
  visit s;
  fan_out s;
  if fuel <= 0 || all_sat () then ()
  else
    Option.fold
      (List.nth_opt (Scenario.productive_successors b s) 0)
      ~none:()
      ~some:(fun ((_step : Step.t), (s' : Cluster.cluster_state)) ->
        drive (fuel - 1) s')

(* (A) one random full-successor trace: uniform successor each step, fuel-bounded. *)
let rec walk (rng : Random.State.t) (fuel : int) (s : Cluster.cluster_state) : unit
    =
  visit s;
  if fuel <= 0 || all_sat () then ()
  else
    match succs s with
    | [] -> ()
    | _ :: _ as xs ->
      let i = Random.State.int rng (List.length xs) in
      Option.fold (List.nth_opt xs i) ~none:()
        ~some:(fun ((_step : Step.t), (s' : Cluster.cluster_state)) ->
          walk rng (fuel - 1) s')

(* Many random traces from [s0], stopping after [stale_stop] consecutive traces add
   no new witness (diminishing returns) or the trace budget is spent. Bounded
   recursion; [stale] counts fruitless traces since the last new witness. *)
let run_random ~(ntraces : int) ~(depth : int) ~(stale_stop : int)
    (s0 : Cluster.cluster_state) : unit =
  let rec loop (k : int) (stale : int) : unit =
    if k <= 0 || stale >= stale_stop || all_sat () then ()
    else
      let before = n_sat () in
      let rng = Random.State.make [| (k * 40_503) + 12_345 |] in
      let () = walk rng depth s0 in
      let after = n_sat () in
      loop (k - 1) (if after > before then 0 else stale + 1)
  in
  loop ntraces 0

(* ---- the seed union -------------------------------------------------------- *)

let ff_seeds : Cluster.cluster_state list =
  [
    Scenario.seed ~desired:2 ~fair:false;
    Scenario.seed_multi ~desireds:[ 2; 3 ] ~fair:false;
    Scenario.seed_with_pods ~desired:1 ~existing:2 ~fair:false;
    Scenario.seed_with_pods ~desired:2 ~existing:3 ~fair:false;
    Scenario.seed_with_orphan ~desired:1 ~fair:false;
  ]

let ft_seeds : Cluster.cluster_state list =
  [
    Scenario.seed ~desired:2 ~fair:true;
    Scenario.seed_multi ~desireds:[ 2; 3 ] ~fair:true;
    Scenario.seed_with_pods ~desired:1 ~existing:2 ~fair:true;
    Scenario.seed_with_pods ~desired:2 ~existing:3 ~fair:true;
    Scenario.seed_with_orphan ~desired:1 ~fair:true;
  ]

(* ---- run the exploration ONCE at module init -------------------------------- *)

(* (A) fair:false: forward drive + per-node fan-out, then random interleavings. *)
let () = List.iter (fun s -> drive 300 s) ff_seeds
let () = List.iter (run_random ~ntraces:200 ~depth:100 ~stale_stop:80) ff_seeds

(* (B) fair:true: forward drive converges the reconcile (steady-state witnesses). *)
let () = List.iter (fun s -> drive 300 s) ft_seeds

(* diagnostic: the live REACHED / NOT-REACHED split. *)
let () =
  Printf.printf
    "\n[t_p4_enumerator] exploration under Bound.default over the seed union: \
     %d/%d witnesses reached\n"
    (n_sat ()) (List.length witnesses);
  List.iter
    (fun (i : Invariants.invariant) ->
      Printf.printf "  [%s] %s\n"
        (if is_sat i.name then "REACHED    " else "NOT REACHED")
        i.name)
    witnesses

(* ---- per-invariant assertion ------------------------------------------------ *)

(* Which seed/regime admits each witness, for the failure message (spec §4: name
   the scenario extension + the bug class an unreached witness would leave
   vacuous). All sixteen are reached under the union above; this note only shows
   on a REGRESSION. *)
let reaching_note (name : string) : string =
  Option.value
    ~default:
      "strengthen the exploration (deeper drive / more random traces) or extend \
       the scenario union"
    (List.assoc_opt name
       [
         ( "every_ongoing_reconcile_has_unique_id",
           "needs >=2 CONCURRENT ongoing reconciles → seed_multi ~desireds:[2;3] \
            (two CRs both scheduled). Guards: reconcile-id COLLISION across \
            concurrent reconciles." );
         ( "garbage_collector_does_not_delete_vrs_pods",
           "needs an in-flight builtin(GC)->api-server DELETE → seed_with_orphan \
            ~desired:1 (a pod whose owner uid is absent from etcd). Guards: the GC \
            stale-delete race that could reap a live VRS pod." );
         ( "filtered_pods_invariant_matrix",
           "needs an ongoing reconcile with filtered_pods=Some → seed_with_pods \
            with existing > desired (scale-DOWN After_list_pods branch). Guards: \
            the filtered-pods list-consistency bug class (stale rv / wrong \
            namespace / mismatched owner)." );
         ( "local_pods_are_bound_to_vrs_with_key",
           "needs an ongoing reconcile with a NON-EMPTY filtered_pods → \
            seed_with_pods with existing > desired (scale-DOWN). Guards: the \
            local-pods ownership-binding (prefix / namespace / controller-owner) \
            bug class." );
         ( "no_other_pending_request_interferes_with_vrs_reconcile",
           "needs a foreign (non-vrs-key) api request → a pod-monkey request under \
            ~fair:false once a pod exists. Guards: cross-reconcile interference." );
         ( "no_pending_mutation_request_not_from_controller_on_pods",
           "needs a foreign non-controller mutation on pods → a pod-monkey \
            Create/Update under ~fair:false. Guards: rogue pod mutation." );
         ( "current_state_matches",
           "needs matching pods for the CR → seed_with_pods, or the fair:true \
            drive after the reconcile creates pods. Guards: the ESR liveness goal \
            observed vacuously." );
       ])

let check_reached (i : Invariants.invariant) () : unit =
  Alcotest.(check bool)
    (Printf.sprintf
       "%s: 'interesting' witness reached under Bound.default across the seed \
        union (else checked VACUOUSLY — %s)"
       i.name (reaching_note i.name))
    true (is_sat i.name)

let () =
  Alcotest.run "p4_enumerator"
    [
      ( "enumerator_interesting_reached",
        List.map
          (fun (i : Invariants.invariant) ->
            Alcotest.test_case i.name `Quick (check_reached i))
          witnesses );
    ]

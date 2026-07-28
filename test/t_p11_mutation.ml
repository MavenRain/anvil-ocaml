(* BUILD-SPEC-P11 §8 "t_p11_mutation" — confirm-by-mutation for the VStatefulSet
   assurance leg (the P11 sibling of t_p8_mutation / t_p10_mutation). Five
   COMPILING source mutants (M1-M5, see the BUILD-SPEC §8 list) were each applied,
   built, SEEN to turn a pinned assertion RED, and reverted; only the green pins
   ship. These tests are the always-on in-tree ANALOGUES: every pin reads a value
   the REAL source produces and that its mutant would break, and (where the mutant
   is otherwise unreachable on the bounded graph) plants the divergent witness the
   mutant would wrongly accept — so the pin is non-vacuous.

   - M1 (drop the ordinal-name conjunct (c) [exactly-n owned pods] in
     [Vsts_invariants.current_state_matches]): an EXTRA owned pod at an off-ordinal
     key would pass. The real matcher REJECTS such a planted state (owned-pod count
     != n); a clause-(c)-dropped analogue ACCEPTS it. This off-ordinal state is NOT
     reachable at the settling bound, so M1 is caught ONLY here (a LOAD-BEARING pin).
   - M2 (widen inv9 [self_ok] to accept a foreign-owner Create): the real
     [vsts_reconcile_request_only_interferes_with_itself] invariant is VIOLATED by a
     planted in-flight foreign-owner Create from the vsts controller (and clean on a
     self-owned Create); a widened analogue accepts the foreign one. The foreign
     create never arises on the reachable graph, so M2 is caught ONLY here.
   - M3 ([Vsts_liveness.settling_bound.reconcile_ceiling := 2]): the ceiling=1 pin
     is load-bearing — raising it grows the reachable graph (the second reconcile
     pass is admitted), so the pinned milestone graph size moves. Pinned directly +
     the graph-size divergence shown.
   - M4 (swap the [leads_to] sides of [Vsts_liveness.esr_statement_core]): the
     assembled derivation's goal no longer equals the (corrupted) core, so
     [matches_esr_statement] flips to [Ok false]. Pinned + a local swapped-core is
     shown to be detectably un-equal to the derivation goal.
   - M5 ([current_state_matches] requires ordinal >= n pods too — off-by-one on the
     ordinal range): a genuinely converged reachable state stops matching. The real
     matcher is TRUE on a reachable converged state; a require-(n+1) analogue is
     FALSE on it. Also caught by t_p11_vsts_liveness / _esr (match count -> 0).

   Convention firewall: no loop keywords (BFS via recursion + List folds); no [_ ->]
   wildcard on a finite sum (two-arm {!Mc.outcome} matches are exhaustive; the list
   [[] | _ :: _] BFS match lists both constructors); Option.fold / Result.fold for
   option/result; [Int.equal] / [String.equal]; [List.nth_opt] never [List.nth]. *)

module Scenario = Anvil_assurance.Scenario
module Vi = Anvil_assurance.Vsts_invariants
module Invariants = Anvil_assurance.Invariants
module Vl = Anvil_proof.Vsts_liveness
module Cc = Anvil_checker.Cluster_check
module Mc = Anvil_checker.Model_check
module R = V_stateful_set_reconciler

let desired = 1
let depth = 40
let controller_id = Scenario.controller_id
let cr : V_stateful_set.t = Scenario.vsts ~desired ()
let cr_md : Object_meta.t = V_stateful_set.metadata cr
let parent = Option.value ~default:"" cr_md.name
let vsts_ns = Option.value ~default:"" cr_md.namespace

(* The §7.2 settling bound (reconcile_ceiling = 1 isolates the first pass). *)
let settling_bound : Bound.t =
  {
    Bound.max_in_flight = 2;
    max_objects_per_kind = 2;
    max_controllers = 1;
    uid_ceiling = 4;
    rv_ceiling = 5;
    reconcile_ceiling = 1;
    max_reconcile_depth = 8;
    monkey_forge = [];
  }

let always_invs : Invariants.invariant list =
  Vi.always ~cr ~controller_id

(* -- reachable-state collector (the abstract {!Mc.reachable} does not expose the
   states; BFS via recursion + folds, as in t_p8_mutation) ------------------- *)

let reachable_states () : Cluster.cluster_state list =
  let seed = Scenario.vsts_seed ~desired ~fair:true in
  let succ = Cc.bounded_successors settling_bound Scenario.vsts_cluster in
  let visited : (int, Cluster.cluster_state list) Hashtbl.t = Hashtbl.create 4096 in
  let seen s =
    Hashtbl.find_opt visited (Cc.state_hash s)
    |> Option.map (List.exists (Cc.state_equal s))
    |> Option.value ~default:false
  in
  let mark s =
    let h = Cc.state_hash s in
    Hashtbl.replace visited h
      (s :: Option.value ~default:[] (Hashtbl.find_opt visited h))
  in
  let rec bfs frontier level acc =
    match frontier with
    | [] -> acc
    | _ :: _ ->
      if level >= depth then acc
      else
        let next =
          List.fold_left
            (fun fr s ->
              List.fold_left
                (fun fr s' ->
                  if seen s' then fr else (mark s'; s' :: fr))
                fr (succ s))
            [] frontier
        in
        bfs (List.rev next) (level + 1) (List.rev_append next acc)
  in
  let () = if not (seen seed) then mark seed in
  bfs [ seed ] 0 [ seed ]

let matches (s : Cluster.cluster_state) : bool =
  Vi.current_state_matches cr s

let a_matching_state : Cluster.cluster_state option =
  List.nth_opt (List.filter matches (reachable_states ())) 0

(* -- state-construction helpers -------------------------------------------- *)

let add_etcd (s : Cluster.cluster_state) (key : Common.object_ref)
    (obj : Dynamic_object.t) : Cluster.cluster_state =
  {
    s with
    Cluster.api_server =
      {
        s.Cluster.api_server with
        Api_server.resources =
          Object_ref_map.add key obj s.Cluster.api_server.Api_server.resources;
      };
  }

let set_network (s : Cluster.cluster_state) (m : Message.t) :
    Cluster.cluster_state =
  { s with Cluster.network = { Network.in_flight = Message.Pool.singleton m } }

let pod_key (ord : int) : Common.object_ref =
  { Common.kind = Pod.kind; name = R.pod_name parent ord; namespace = vsts_ns }

(* -- M1: an EXTRA off-ordinal owned pod makes the exactly-n conjunct bite ---- *)

(* the same pod-0 object the reachable matcher already owns, re-inserted under the
   ordinal-1 key: it carries the vsts owner-ref, so [owned_pods] counts it (-> 2),
   while ordinal 0 is still present and valid. Real matcher rejects (count != 1);
   clause-(c)-dropped analogue accepts. *)
let planted_extra_pod (s : Cluster.cluster_state) : Cluster.cluster_state option =
  Option.map
    (fun (pod0 : Dynamic_object.t) -> add_etcd s (pod_key 1) pod0)
    (Object_ref_map.find_opt (pod_key 0) (Cluster.resources s))

(* current_state_matches WITHOUT clause (c) [the exactly-n owned-pod count]. NOTE
   (P11 review): this analogue's [owned_pod_at] also elides clause-(b)'s CONTENT
   sub-checks (ordinal_label / pod_name_label / pod_spec_matches), keeping only the
   kind + owner-ref checks — so its divergence from the real matcher is attributable
   to the named clause (c) ONLY under the current valid-pod witness [planted_extra_pod],
   whose planted pod carries correct labels and a matching spec (the elided sub-checks
   agree there). It is NOT a byte-faithful single-clause mutant for an arbitrary pod. *)
let matches_drop_c (s : Cluster.cluster_state) : bool =
  let co = V_stateful_set.controller_owner_ref cr in
  let n = Option.value ~default:1 (V_stateful_set.spec cr).replicas in
  let owned_pod_at (ord : int) : bool =
    Option.fold
      (Object_ref_map.find_opt (pod_key ord) (Cluster.resources s))
      ~none:false
      ~some:(fun (obj : Dynamic_object.t) ->
        let md : Object_meta.t = Dynamic_object.metadata obj in
        Common.equal_kind (Dynamic_object.kind obj) Pod.kind
        && Option.fold co ~none:false
             ~some:(Object_meta.owner_references_contains md))
  in
  Option.is_some
    (Object_ref_map.find_opt Scenario.vsts_ref (Cluster.resources s))
  && List.for_all owned_pod_at (List.init (max 0 n) Fun.id)

let test_m1_off_ordinal_conjunct () =
  Alcotest.(check bool) "M1: a reachable matching state exists to plant from" true
    (Option.is_some a_matching_state);
  Option.iter
    (fun (s : Cluster.cluster_state) ->
      Alcotest.(check bool) "M1 baseline: the clean converged state matches" true
        (matches s);
      Alcotest.(check bool) "M1: matching state has an ordinal-0 pod to clone" true
        (Option.is_some (planted_extra_pod s));
      Option.iter
        (fun (planted : Cluster.cluster_state) ->
          Alcotest.(check bool)
            "M1: REAL matcher REJECTS an extra off-ordinal owned pod (clause c)"
            false (matches planted);
          Alcotest.(check bool)
            "M1: the clause-(c)-dropped analogue WRONGLY accepts it (divergence)"
            true (matches_drop_c planted))
        (planted_extra_pod s))
    a_matching_state

(* -- M2: a foreign-owner Create from the vsts controller ------------------- *)

let mk_owner ~(kind : Common.kind) ~(name : string) ~(uid : int) :
    Owner_reference.t =
  {
    Owner_reference.block_owner_deletion = Some true;
    controller = Some true;
    kind;
    name;
    uid = Common.Uid.of_int uid;
  }

let proper_owner : Owner_reference.t =
  mk_owner ~kind:V_stateful_set.kind ~name:parent ~uid:1

let foreign_owner : Owner_reference.t =
  mk_owner ~kind:Vreplica_set.kind ~name:"foreign" ~uid:9

let create_pod_obj (owner : Owner_reference.t) : Dynamic_object.t =
  Dynamic_object.make ~kind:Pod.kind
    ~metadata:
      {
        (Object_meta.default ()) with
        Object_meta.name = Some (R.pod_name parent 0);
        namespace = Some vsts_ns;
        uid = Some (Common.Uid.of_int 7);
        owner_references = Some [ owner ];
      }
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let create_msg (owner : Owner_reference.t) : Message.t =
  Message.controller_req_msg controller_id Scenario.vsts_ref
    (Message.Rpc_id.of_int 0)
    (Api_method.Create_request
       { namespace = vsts_ns; obj = create_pod_obj owner })

let self_inv_name = "vsts_reconcile_request_only_interferes_with_itself"

let violates_self_inv (s : Cluster.cluster_state) : bool =
  Option.fold
    (Invariants.first_violated always_invs s)
    ~none:false
    ~some:(fun (i : Invariants.invariant) -> String.equal i.name self_inv_name)

let test_m2_foreign_owner_create () =
  let seed = Scenario.vsts_seed ~desired ~fair:true in
  let s_proper = set_network seed (create_msg proper_owner) in
  let s_foreign = set_network seed (create_msg foreign_owner) in
  (* non-vacuity: a self-owned Create in flight breaks NO invariant. *)
  Alcotest.(check bool)
    "M2 baseline: a self-owned Create violates no VSTS invariant" false
    (Option.is_some (Invariants.first_violated always_invs s_proper));
  (* the load-bearing pin: the REAL invariant flags the foreign-owner Create. *)
  Alcotest.(check bool)
    "M2: REAL inv9 is VIOLATED by a foreign-owner Create (self_ok rejects)" true
    (violates_self_inv s_foreign)

(* -- M3: reconcile_ceiling = 1 is load-bearing ----------------------------- *)

let states_seen_at (ceiling : int) : int =
  let seed = Scenario.vsts_seed ~desired ~fair:true in
  let b = { settling_bound with Bound.reconcile_ceiling = ceiling } in
  Mc.states_seen
    (Mc.explore ~depth
       ~successors:(Cc.bounded_successors b Scenario.vsts_cluster)
       ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ seed ])

let test_m3_reconcile_ceiling_load_bearing () =
  Alcotest.(check int)
    "M3: Vsts_liveness.settling_bound.reconcile_ceiling = 1 (load-bearing)" 1
    Vl.settling_bound.reconcile_ceiling;
  (* raising the ceiling admits the second pass -> the graph grows. *)
  Alcotest.(check bool)
    "M3: raising reconcile_ceiling to 2 changes the reachable graph size" true
    (not (Int.equal (states_seen_at 1) (states_seen_at 2)))

(* -- M4: esr_statement_core leads_to-side swap ----------------------------- *)

let is_ok_true (r : bool Comp_cat.Res.t) : bool =
  Result.fold r ~ok:(fun b -> b) ~error:(fun _ -> false)

(* the de-stabilized core with its leads_to sides SWAPPED. *)
let swapped_core ~desired : Cluster.cluster_state Comp_cat.Temporal.t =
  Comp_cat.Temporal.leads_to
    (Vl.f_current_state_matches ~desired)
    (Comp_cat.Temporal.always (Vl.f_desired_state_is ~desired))

let test_m4_esr_core_swap () =
  (* the headline pin: the derivation's goal equals the (real) core. *)
  Alcotest.(check bool) "M4: matches_esr_statement ~desired:1 = Ok true" true
    (is_ok_true (Vl.matches_esr_statement ~bound:settling_bound ~desired));
  Result.fold (Vl.esr_derivation ~bound:settling_bound ~desired)
    ~ok:(fun fact ->
      let goal = Comp_cat.Rule.goal_of fact in
      Alcotest.(check bool) "M4: derivation goal equals the REAL esr core" true
        (Comp_cat.Temporal.equal goal (Vl.esr_statement_core ~desired));
      Alcotest.(check bool)
        "M4: the swapped core is detectably UN-equal to the goal (divergence)"
        false
        (Comp_cat.Temporal.equal goal (swapped_core ~desired)))
    ~error:(fun _ ->
      Alcotest.fail "M4: esr_derivation = Error (should assemble cleanly)")

(* -- M5: the ordinal-range off-by-one (requires a pod at ordinal n too) ----- *)

(* current_state_matches with clause (b) widened to ordinals 0..n (one too many).
   NOTE (P11 review): as with [matches_drop_c], [owned_pod_at] elides clause-(b)'s
   content sub-checks (labels / pod_spec_matches). Harmless for THIS test: the
   divergence is that ordinal n has no pod at all ([find_opt] = None), so the content
   sub-checks never enter — the off-by-one range IS the sole cause of the flip. *)
let matches_require_n_plus_1 (s : Cluster.cluster_state) : bool =
  let co = V_stateful_set.controller_owner_ref cr in
  let n = Option.value ~default:1 (V_stateful_set.spec cr).replicas in
  let owned_pod_at (ord : int) : bool =
    Option.fold
      (Object_ref_map.find_opt (pod_key ord) (Cluster.resources s))
      ~none:false
      ~some:(fun (obj : Dynamic_object.t) ->
        let md : Object_meta.t = Dynamic_object.metadata obj in
        Common.equal_kind (Dynamic_object.kind obj) Pod.kind
        && Option.fold co ~none:false
             ~some:(Object_meta.owner_references_contains md))
  in
  Option.is_some
    (Object_ref_map.find_opt Scenario.vsts_ref (Cluster.resources s))
  && List.for_all owned_pod_at (List.init (max 0 (n + 1)) Fun.id)

let test_m5_ordinal_off_by_one () =
  Alcotest.(check bool) "M5: a reachable matching state exists" true
    (Option.is_some a_matching_state);
  Option.iter
    (fun (s : Cluster.cluster_state) ->
      Alcotest.(check bool)
        "M5: REAL matcher is TRUE on a genuinely converged reachable state" true
        (matches s);
      Alcotest.(check bool)
        "M5: the require-(n+1) analogue is FALSE on it (no pod at ordinal n)"
        false (matches_require_n_plus_1 s))
    a_matching_state

let () =
  Alcotest.run "p11_mutation"
    [
      ( "confirm-by-mutation",
        [
          Alcotest.test_case
            "M1: exactly-n conjunct rejects an off-ordinal pod" `Quick
            test_m1_off_ordinal_conjunct;
          Alcotest.test_case "M2: inv9 flags a foreign-owner Create" `Quick
            test_m2_foreign_owner_create;
          Alcotest.test_case "M3: reconcile_ceiling = 1 is load-bearing" `Quick
            test_m3_reconcile_ceiling_load_bearing;
          Alcotest.test_case "M4: esr_statement_core swap flips the cross-lock"
            `Quick test_m4_esr_core_swap;
          Alcotest.test_case "M5: ordinal range off-by-one drops the match" `Quick
            test_m5_ordinal_off_by_one;
        ] );
    ]

(* BUILD-SPEC-P17 sections 2-REVISED and 3 - the CLASSIFICATION firewall,
   the P14-P16 pattern with ONE deliberate divergence, plus the two
   measured exclusion pins (E1 / E2).

   THE DELIBERATE DIVERGENCE (spec section 2-REVISED, disclosed in
   [objects_in_store.mli]): the P14-P16 regressions pin their families
   DISJOINT from every shipped suite; this family is instead pinned as an
   INCLUSION in [Invariants.cluster_structural] by exact (name, source)
   pair - S1/S2/S3 ARE the base-suite inv1/inv2/inv3, and
   {!Anvil_assurance.Objects_in_store.store_family} is a FILTER over the
   very records [cluster_structural] builds (a second copy would be drift
   risk and would break this firewall by construction). The four existing
   disjointness guards for the P14-P16 families REMAIN IN FORCE - this same
   phase k3-strengthens their bodies to (name, source) pairs, strengthened
   not removed (they live in
   t_p14/t_p15/t_p16_regression); the inverse direction - no P17 member
   leaked INTO a correspondence family - is asserted here by the same
   k3-strengthened either-component (name, source) detector.

   ---- what this file DOES beyond the P16 pattern ---------------------------

   - THE E1 PIN (spec section 3, measured not asserted): the upstream
     well-formed STRENGTHENING (objects_in_store.rs:101, quantified at :110
     builtin / :185 custom = weakly + [unmarshallable_object] +
     [valid_object] over [installed_types]) is EXTENSIONALLY EMPTY on the
     L0 graph: both members, evaluated with the leg cluster's OWN
     [installed_types], agree with shipped S2 state-by-state at all 76
     states. Every shipped scenario wires permissive [installed_types]
     (sweep cited in [objects_in_store.mli]); if a scenario ever gains a
     restrictive one, this pin reddens and the E1 exclusion must be
     revisited (port the :110/:185 members instead of excluding them).
     That redden-on-restrictive promise is CERTIFIED red-capable by
     [test_e1_detector_red_capability] (P17-review hardening): the same
     transcribed predicates are SEEN rejecting under restrictive tables
     and wrong-key pairings, so a weakening transcription bug cannot
     keep the delta silently empty.

   - THE E2 PIN (spec section 3, per the B2 verdict): upstream
     [each_object_in_etcd_is_well_formed<T>] (:267) has a CONTRADICTORY
     premise (:270-271: [key.kind !is CustomResourceKind && key.kind ==
     T::kind()] with [T::kind()] a [CustomResourceKind] by
     spec/resource.rs:122-123). The port's rendering of that premise is
     asserted UNSATISFIABLE on the L0 graph, with the vsts-kind-key count
     as the control proving the zero is the contradiction's, not an empty
     store's, and the kind-coverage control proving no stored key escapes
     the builtin-or-vsts dichotomy the E1 conjunction quantifies over.

   ---- what it does NOT do (anti-duplication, the P15/P16 rationale) --------

   It does NOT re-run P13-P16's own legs (their batteries already do) and
   does NOT re-pin any P17 number ([p17_witness.ml] is the single source;
   this file only READS it). The COMMITTED-literal block below duplicates
   P16's committed pins deliberately - the duplication IS the firewall
   (P14's rationale): "fix the red by editing the witness" reddens here.
   List lengths of the SHIPPED suites are deliberately not pinned (P14's
   rationale); the family's own cardinal IS pinned (it is the phase's
   deliverable, not a shared suite).

   Firewall honoured: List/Option/fold combinators only (no loop
   keywords), exhaustive matches on every finite sum (the eleven
   [Common.kind] constructors - payload wildcard only on
   [Custom_resource _], never an arm wildcard), no two-arm match on
   [option]/[result] (stdlib [Option.fold]/[Result.fold]), Alcotest as the
   sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Correspondence = Anvil_assurance.Correspondence
module Rc = Anvil_assurance.Reconcile_correspondence
module Rr = Anvil_assurance.Req_resp_correspondence
module Ois = Anvil_assurance.Objects_in_store

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P17_witness.witness_desired
let depth : int = P17_witness.witness_depth
let bound : Bound.t = P17_witness.p17_bound ~desireds:[ desired ]
let family : Invariants.invariant list = Ois.store_family ~controller_id

(* ==== 1. P16's committed pins, re-pinned here as literals ================== *)

(* The literals as committed at [90325b6] (P16), held against the witness
   module the P16 tests actually read, so "fix the red by editing the pin"
   reddens HERE. If any of these moves, a list leaked into a shared suite or
   a seed/bound drifted: STOP and find the leak - re-pinning is the one
   forbidden repair. *)

let committed_p16_l0_states : int = 76
let committed_p16_lc_states : int = 464
let committed_p16_ld_states : int = 744
let committed_p16_lm_states : int = 1976
let committed_p16_l0_rv_gate_states : int = 0
let committed_p16_l0_matched_gate_states : int = 4
let committed_p16_lc_rv_gate_states : int = 0
let committed_p16_lc_matched_gate_states : int = 32
let committed_p16_ld_rv_gate_states : int = 0
let committed_p16_ld_matched_gate_states : int = 16
let committed_p16_lm_rv_gate_states : int = 0
let committed_p16_lm_matched_gate_states : int = 80

let test_p16_pins_are_the_committed_literals () =
  Alcotest.(check int) "P16 L0 states: 76 (committed at 90325b6)"
    committed_p16_l0_states P16_witness.l0_states;
  Alcotest.(check int) "P16 Lc states: 464 (committed at 90325b6)"
    committed_p16_lc_states P16_witness.lc_states;
  Alcotest.(check int) "P16 Ld states: 744 (committed at 90325b6)"
    committed_p16_ld_states P16_witness.ld_states;
  Alcotest.(check int) "P16 Lm states: 1976 (committed at 90325b6)"
    committed_p16_lm_states P16_witness.lm_states;
  Alcotest.(check int) "P16 L0/Rv gate: 0 (committed at 90325b6)"
    committed_p16_l0_rv_gate_states P16_witness.l0_rv_gate_states;
  Alcotest.(check int) "P16 L0/Matched gate: 4 (committed at 90325b6)"
    committed_p16_l0_matched_gate_states P16_witness.l0_matched_gate_states;
  Alcotest.(check int) "P16 Lc/Rv gate: 0 (committed at 90325b6)"
    committed_p16_lc_rv_gate_states P16_witness.lc_rv_gate_states;
  Alcotest.(check int) "P16 Lc/Matched gate: 32 (committed at 90325b6)"
    committed_p16_lc_matched_gate_states P16_witness.lc_matched_gate_states;
  Alcotest.(check int) "P16 Ld/Rv gate: 0 (committed at 90325b6)"
    committed_p16_ld_rv_gate_states P16_witness.ld_rv_gate_states;
  Alcotest.(check int) "P16 Ld/Matched gate: 16 (committed at 90325b6)"
    committed_p16_ld_matched_gate_states P16_witness.ld_matched_gate_states;
  Alcotest.(check int) "P16 Lm/Rv gate: 0 (committed at 90325b6)"
    committed_p16_lm_rv_gate_states P16_witness.lm_rv_gate_states;
  Alcotest.(check int) "P16 Lm/Matched gate: 80 (committed at 90325b6)"
    committed_p16_lm_matched_gate_states P16_witness.lm_matched_gate_states

(* ==== 2. the family classification: INCLUSION, not disjointness ============ *)

(* The three upstream spec-fn names, verbatim from
   [src/kubernetes_cluster/proof/objects_in_store.rs] (S1 :23, S2 :33,
   S3 :299). Written out here rather than projected from the family so that
   a rename on ONE side is caught. *)
let upstream_names : string list =
  [
    "etcd_objects_have_unique_uids";
    "each_object_in_etcd_is_weakly_well_formed";
    "each_object_in_etcd_has_at_most_one_controller_owner";
  ]

let names_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.name) invs

let pairs_of (invs : Invariants.invariant list) : (string * string) list =
  List.map
    (fun (i : Invariants.invariant) -> (i.Invariants.name, i.Invariants.source))
    invs

(* Either-component leak detector, the k3-strengthened identity (P17
   section 7 precedent): a hit on EITHER the name or the source is
   reported. Used here for the INVERSE direction of the P14-P16 guards. *)
let pair_leaks (label : string) (family_pairs : (string * string) list)
    (suite_pairs : (string * string) list) : string list =
  List.concat_map
    (fun ((n, src) : string * string) ->
      List.filter_map
        (fun ((n', src') : string * string) ->
          if String.equal n n' then Some (label ^ " contains name " ^ n)
          else if String.equal src src' then
            Some (label ^ " contains source " ^ src ^ " (as " ^ n' ^ ")")
          else None)
        suite_pairs)
    family_pairs

let test_family_names_are_the_upstream_three () =
  Alcotest.(check (list string))
    "store_family is S1/S2/S3 in upstream order" upstream_names
    (names_of family)

(* THE INCLUSION PIN (spec section 2-REVISED). P17-review hardening: the
   subset check below compares the filter's output against the very list it
   filters, so BY ITSELF it is inert while [store_family] stays a filter (it
   reddens only if the family is ever re-implemented independently - the
   drift class it guards). The INDEPENDENT content is [expected_pairs]: the
   three (name, source) pairs as COMMITTED LITERALS, compared against both
   the family and the base suite - a rename, source drift, or filter bug
   reddens HERE regardless of implementation. *)
let expected_pairs : (string * string) list =
  [
    ( "etcd_objects_have_unique_uids",
      "kubernetes_cluster/proof/objects_in_store.rs:23" );
    ( "each_object_in_etcd_is_weakly_well_formed",
      "kubernetes_cluster/proof/objects_in_store.rs:33" );
    ( "each_object_in_etcd_has_at_most_one_controller_owner",
      "kubernetes_cluster/proof/objects_in_store.rs:299" );
  ]

let test_family_is_included_in_cluster_structural () =
  let base_pairs : (string * string) list =
    pairs_of (Invariants.cluster_structural ~controller_id)
  in
  (* Independent-literal pins FIRST (red-capable under every drift class). *)
  Alcotest.(check (list (pair string string)))
    "family (name, source) pairs = the committed literals, in upstream order"
    expected_pairs (pairs_of family);
  let missing_from_base : string list =
    List.filter_map
      (fun ((n, src) : string * string) ->
        if
          List.exists
            (fun ((n', src') : string * string) ->
              String.equal n n' && String.equal src src')
            base_pairs
        then None
        else Some (n ^ " @ " ^ src))
      expected_pairs
  in
  Alcotest.(check (list string))
    "every committed-literal pair IS a cluster_structural pair" []
    missing_from_base;
  let missing : string list =
    List.filter_map
      (fun ((n, src) : string * string) ->
        if
          List.exists
            (fun ((n', src') : string * string) ->
              String.equal n n' && String.equal src src')
            base_pairs
        then None
        else Some (n ^ " @ " ^ src))
      (pairs_of family)
  in
  Alcotest.(check (list string))
    "every store_family (name, source) pair IS a cluster_structural pair \
     (inert while the family is a filter; guards re-implementation drift)"
    [] missing;
  Alcotest.(check int) "store_family cardinal = 3" 3 (List.length family);
  Alcotest.(check (list string))
    "family sources = store_sources, in order" Ois.store_sources
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.source) family)

(* The INVERSE of the four shipped disjointness guards: no P17 member leaked
   INTO a P14/P15/P16 correspondence list (masking-trap direction: a store
   member unioned into a correspondence leg could fire first and poison
   [violated] attribution there). *)
let test_family_not_in_correspondence_families () =
  let correspondence_suites : (string * Invariants.invariant list) list =
    [
      ("Correspondence.family", Correspondence.family cluster ~controller_id);
      ( "Reconcile_correspondence.family",
        Rc.family ~controller_id ~pending_states:Fc.vsts_pending_states
          ~none_states:Fc.vsts_none_states );
      ("Req_resp_correspondence.rv_family", Rr.rv_family bound);
      ( "Req_resp_correspondence.matched_family",
        Rr.matched_family ~controller_id );
    ]
  in
  let leaked : string list =
    List.concat_map
      (fun ((suite, invs) : string * Invariants.invariant list) ->
        pair_leaks suite (pairs_of family) (pairs_of invs))
      correspondence_suites
  in
  Alcotest.(check (list string))
    "no store member leaked into a correspondence family" [] leaked

(* ==== 3. the L0 replica for the E1/E2 pins ================================= *)

let l0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (Mc.explore ~depth
       ~successors:(Fc.faulted_successors bound P17_witness.zero_budget cluster)
       ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
       ~init:
         [
           Fc.faulted_of_seed
             (Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
                ~pod_monkey:false ());
         ])

(* ---- E1 predicates: upstream :101/:110/:185 transcribed for the pin ------ *)

(* Exhaustive on the eleven kinds; [Custom_resource _] is a payload
   wildcard, never an arm wildcard. *)
let kind_is_custom (k : Common.kind) : bool =
  match k with
  | Common.Custom_resource _ -> true
  | Common.Config_map | Common.Daemon_set | Common.Persistent_volume_claim
  | Common.Pod | Common.Role | Common.Role_binding | Common.Stateful_set
  | Common.Service | Common.Service_account | Common.Secret ->
      false

let vsts_kind : Common.kind = V_stateful_set_pack.kind

(* The leg cluster's OWN installed_types - the pin evaluates the REAL
   record the api_server runs with, so a future restrictive scenario
   reddens it. *)
let installed : Api_server.installed_types = cluster.Cluster.installed_types

(* Anvil [unmarshallable_object] (state_machine.rs:109), reconstructed from
   the public [installed_types] fields exactly as api_server.ml:82-84
   composes them (the function itself is private to the api_server).
   Parameterized on the table (P17-review hardening) so the red-capability
   witness below can feed a RESTRICTIVE table; its one consumer is
   [well_formed_for_key_it], whose zero-table delegate closes over the leg
   cluster's real record. *)
let unmarshallable_object_it (it : Api_server.installed_types)
    (obj : Dynamic_object.t) : bool =
  it.Api_server.unmarshallable_spec (Dynamic_object.kind obj)
    (Dynamic_object.spec obj)
  && it.Api_server.unmarshallable_status (Dynamic_object.kind obj)
       (Dynamic_object.status obj)

(* Upstream [etcd_object_is_weakly_well_formed(key)] per key
   (objects_in_store.rs:13-21) - the same four conjuncts shipped S2
   quantifies (invariants.ml inv2); transcribed HERE so the E1 delta
   comparison has an independent rendering of the per-key base. *)
let weakly_for_key (s : Cluster.cluster_state) (key : Common.object_ref)
    (obj : Dynamic_object.t) : bool =
  let md : Object_meta.t = Dynamic_object.metadata obj in
  Object_meta.well_formed_for_namespaced md
  && Result.fold (Dynamic_object.object_ref obj)
       ~error:(fun _ -> false)
       ~ok:(fun r -> Common.equal_object_ref r key)
  && Option.fold md.resource_version ~none:false ~some:(fun rv ->
         Common.Resource_version.to_int rv
         < s.Cluster.api_server.resource_version_counter)
  && Option.fold md.uid ~none:false ~some:(fun u ->
         Common.Uid.to_int u < s.Cluster.api_server.uid_counter)

(* Upstream [etcd_object_is_well_formed(key)] (:101-107): weakly + the two
   installed_types conjuncts. *)
let well_formed_for_key_it (it : Api_server.installed_types)
    (s : Cluster.cluster_state) (key : Common.object_ref)
    (obj : Dynamic_object.t) : bool =
  weakly_for_key s key obj
  && unmarshallable_object_it it obj
  && it.Api_server.valid_object obj

let well_formed_for_key :
    Cluster.cluster_state -> Common.object_ref -> Dynamic_object.t -> bool =
  well_formed_for_key_it installed

(* Upstream [each_builtin_object_in_etcd_is_well_formed] (:110). *)
let builtin_member (s : Cluster.cluster_state) : bool =
  Object_ref_map.for_all
    (fun (key : Common.object_ref) obj ->
      kind_is_custom key.Common.kind || well_formed_for_key s key obj)
    (Cluster.resources s)

(* Upstream [each_custom_object_in_etcd_is_well_formed<T>] (:185) at
   [T = VStatefulSet], the one custom kind these scenarios install. *)
let custom_member_it (it : Api_server.installed_types)
    (s : Cluster.cluster_state) : bool =
  Object_ref_map.for_all
    (fun (key : Common.object_ref) obj ->
      (not (Common.equal_kind key.Common.kind vsts_kind))
      || well_formed_for_key_it it s key obj)
    (Cluster.resources s)

let custom_member : Cluster.cluster_state -> bool = custom_member_it installed

(* Shipped S2's [holds], read off the family BY NAME (total: constantly
   [true] on a missing name, which [test_family_names_are_the_upstream_three]
   reddens loudly first). *)
let s2_name : string = "each_object_in_etcd_is_weakly_well_formed"

let s2_holds (s : Cluster.cluster_state) : bool =
  List.for_all
    (fun (i : Invariants.invariant) ->
      (not (String.equal i.Invariants.name s2_name)) || i.Invariants.holds s)
    family

(* ---- E2 predicate: the :270-271 premise rendering ------------------------ *)

let e2_premise (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (((key : Common.object_ref), _) : Common.object_ref * Dynamic_object.t)
       ->
      (not (kind_is_custom key.Common.kind))
      && Common.equal_kind key.Common.kind vsts_kind)
    (Object_ref_map.bindings (Cluster.resources s))

let e2_control (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (((key : Common.object_ref), _) : Common.object_ref * Dynamic_object.t)
       -> Common.equal_kind key.Common.kind vsts_kind)
    (Object_ref_map.bindings (Cluster.resources s))

let uncovered_kind (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (((key : Common.object_ref), _) : Common.object_ref * Dynamic_object.t)
       ->
      kind_is_custom key.Common.kind
      && not (Common.equal_kind key.Common.kind vsts_kind))
    (Object_ref_map.bindings (Cluster.resources s))

(* ==== 4. the E1 pin ======================================================== *)

let test_e1_strengthening_delta_is_empty () =
  let reach = Lazy.force l0_reach in
  (* Replica faithfulness FIRST (the P13 M3/M5 precedent). *)
  Alcotest.(check int) "E1: replica explored the L0 graph"
    P17_witness.l0_states (Mc.states_seen reach);
  (* Kind coverage: the builtin+custom conjunction quantifies over EVERY
     stored key on this graph. *)
  Alcotest.(check int) "E1: uncovered-kind states = 0 (pinned)"
    P17_witness.uncovered_kind_l0
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         uncovered_kind f.cs));
  (* THE PIN: state-by-state agreement of shipped S2 with the strengthened
     upstream members, at every one of the 76 states. *)
  Alcotest.(check int) "E1: strengthening delta on L0 = 0 (pinned)"
    P17_witness.e1_delta_l0
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         not
           (Bool.equal (s2_holds f.cs)
              (builtin_member f.cs && custom_member f.cs))))

(* P17-review hardening ([feedback-confirm-tests-by-mutation]): the delta pin
   above never OBSERVES [well_formed_for_key] rejecting - the shipped tables
   are permissive, so a weakening transcription bug (e.g.
   [well_formed_for_key] extensionally = [weakly_for_key]) would keep delta 0
   forever and silently void the redden-on-restrictive promise. This witness
   feeds RESTRICTIVE tables through the SAME transcribed predicates and
   requires each strengthening conjunct to reject the stored VSTS CR at
   EVERY L0 state (weakly still passes there, so it is exactly the
   strengthening delta firing), plus a wrong-key probe certifying the weakly
   base itself discriminates. *)
let test_e1_detector_red_capability () =
  let reach = Lazy.force l0_reach in
  Alcotest.(check int) "E1 witness: replica explored the L0 graph"
    P17_witness.l0_states (Mc.states_seen reach);
  Alcotest.(check int) "E1 witness: store non-empty at every state (control)"
    P17_witness.l0_states
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         not (Object_ref_map.is_empty (Cluster.resources f.cs))));
  let reject_valid : Api_server.installed_types =
    { installed with Api_server.valid_object = (fun _ -> false) }
  in
  let reject_spec : Api_server.installed_types =
    { installed with Api_server.unmarshallable_spec = (fun _ _ -> false) }
  in
  Alcotest.(check int)
    "E1 witness: valid_object-restrictive table -> custom member rejects at \
     every state (the strengthening conjunct SEEN to discriminate)"
    P17_witness.l0_states
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         not (custom_member_it reject_valid f.cs)));
  Alcotest.(check int)
    "E1 witness: unmarshallable-restrictive table -> custom member rejects \
     at every state"
    P17_witness.l0_states
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         not (custom_member_it reject_spec f.cs)));
  Alcotest.(check int)
    "E1 witness: wrong-key pairing rejected by the weakly base at every \
     stored binding of every state"
    0
    (Mc.count_states_where reach (fun (f : Fc.faulted) ->
         List.exists
           (fun
             (((key : Common.object_ref), obj) :
               Common.object_ref * Dynamic_object.t)
           ->
             weakly_for_key f.cs
               { key with Common.name = key.Common.name ^ "-p17-witness" }
               obj)
           (Object_ref_map.bindings (Cluster.resources f.cs))))

(* ==== 5. the E2 pin ======================================================== *)

let test_e2_premise_is_unsatisfiable_on_l0 () =
  let reach = Lazy.force l0_reach in
  Alcotest.(check int) "E2: replica explored the L0 graph"
    P17_witness.l0_states (Mc.states_seen reach);
  (* CONTROL first: the second conjunct alone fires EVERYWHERE (the seed
     stores the CR), so the zero below is the contradiction's. *)
  Alcotest.(check int) "E2: vsts-kind-key control = every state (pinned)"
    P17_witness.e2_control_l0
    (Mc.count_states_where reach (fun (f : Fc.faulted) -> e2_control f.cs));
  Alcotest.(check int) "E2: premise-satisfying states = 0 (pinned)"
    P17_witness.e2_premise_l0
    (Mc.count_states_where reach (fun (f : Fc.faulted) -> e2_premise f.cs))

let () =
  Alcotest.run "p17_regression"
    [
      ( "prior_phase_firewall",
        [
          Alcotest.test_case "P16 witness constants are the committed pins"
            `Quick test_p16_pins_are_the_committed_literals;
        ] );
      ( "family_classification",
        [
          Alcotest.test_case "family = the three upstream names" `Quick
            test_family_names_are_the_upstream_three;
          Alcotest.test_case
            "family INCLUDED in cluster_structural by (name, source) pair \
             (the deliberate divergence)"
            `Quick test_family_is_included_in_cluster_structural;
          Alcotest.test_case
            "family disjoint from the P14-P16 correspondence families" `Quick
            test_family_not_in_correspondence_families;
        ] );
      ( "exclusion_pins",
        [
          Alcotest.test_case "E1: well-formed strengthening delta empty on L0"
            `Quick test_e1_strengthening_delta_is_empty;
          Alcotest.test_case
            "E1: the delta detector SEEN to discriminate (restrictive-table \
             + wrong-key witnesses)"
            `Quick test_e1_detector_red_capability;
          Alcotest.test_case "E2: contradictory premise unsatisfiable on L0"
            `Quick test_e2_premise_is_unsatisfiable_on_l0;
        ] );
    ]

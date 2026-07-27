(* BUILD-SPEC-P18 sections 2-3 - the CLASSIFICATION firewall (the
   P14-P16 DISJOINT-family pattern, back after P17's deliberate
   inclusion divergence) plus the measured exclusion pins E1 / E4 and
   the E6 register guard.

   THE CLASSIFICATION (spec section 2): H1/H2 are the P14-P16 pattern -
   a genuinely NEW family, appearing in NO shipped suite (P17's filter
   pattern is structurally unavailable: the member is CR-parameterized;
   nothing in [cluster_structural] corresponds). Pinned here in the
   k3-strengthened (name, source) form via the shared {!Pair_guard}
   (section 6 D2 - this file uses it from birth; the four prior
   regressions were rewired to it on this same branch).

   ---- what this file DOES ---------------------------------------------------

   - P17's COMMITTED PINS re-typed as literals (the one sanctioned
     duplication, P14's rationale: "fix the red by editing the witness"
     reddens HERE), plus the P16 constants P18's witness DERIVES its L0v
     graph from.

   - THE E1 PIN (spec section 3, measured not asserted): the uid-exact
     sibling (upstream :36-49, eventually-only, lemma :700) differs from
     H1 ONLY in the owner-ref clause (full [Owner_reference.equal] incl.
     uid vs [eq_without_uid]); the gap is exactly the
     created-deleted-recreated-same-name CR corner, unreachable in the
     port (the step alphabet deletes pods only; the seeded CR is never
     GC-collectible). MEASURED delta 0 on the L0 replica - the uid-exact
     rendering and the SHIPPED H1 agree state-by-state - with a forged
     wrong-uid CONTROL seen red on the uid-exact rendering while H1
     holds (the delta detector SEEN red-capable, so a weakening
     transcription bug cannot keep the delta silently empty).

   - THE E4 PIN (spec section 3): upstream's owned-PVC GC member (:796,
     lemma :1018) guards "PVCs OWNED by the vsts" - EMPTY in the port by
     construction ([make_pvc] stamps no owner refs), even at vct:true.
     MEASURED on the L0v replica, counting convention disclosed in
     [p18_witness.ml] (SUMMED (state, stored-PVC-key) pairs over the 116
     states): owner-ref-carrying pairs 0, CONTROL total stored-PVC pairs
     80 (the detector looked at real PVCs).

   - THE E6 REGISTER GUARD (spec section 3): the message-guarantee
     register is occupied by shipped [inv_self] (widened inv9); the
     upstream :1213 name must equal NO shipped member name, so a future
     port of the message sibling cannot silently collide (reversal
     clause: a natural P19 candidate). The guard carries a POSITIVE
     control - the same detector SEEN finding a shipped name (h1_name,
     exactly one hit) - so the absence pin cannot pass vacuously.

   ---- what it does NOT do (anti-duplication, the P15-P17 rationale) --------

   It does NOT re-run P13-P17's own legs (their batteries already do)
   and does NOT re-pin any P18 number ([p18_witness.ml] is the single
   source; this file only READS it). List lengths of the SHIPPED suites
   are deliberately not pinned; the family's own cardinal IS pinned (it
   is the phase's deliverable, not a shared suite).

   Firewall honoured: List/Option/fold combinators only (no loop
   keywords), exhaustive matches on every finite sum (list shapes as
   [ r ] / [] / _ :: _ :: _), no two-arm match on [option]/[result]
   (stdlib [Option.fold] - its [~none] is EAGER, closures on failing
   arms), Alcotest as the sanctioned failure primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Vsts_invariants = Anvil_assurance.Vsts_invariants
module Correspondence = Anvil_assurance.Correspondence
module Rc = Anvil_assurance.Reconcile_correspondence
module Rr = Anvil_assurance.Req_resp_correspondence
module Ois = Anvil_assurance.Objects_in_store
module Hi = Anvil_assurance.Helper_invariants

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P18_witness.witness_desired
let depth : int = P18_witness.witness_depth
let bound : Bound.t = P18_witness.p18_bound ~desireds:[ desired ]

let family : Invariants.invariant list =
  Hi.helper_family ~cr:(Scenario.vsts ~desired ~vct:false ()) ~controller_id

(* ==== 1. P17's committed pins, re-pinned here as literals ================== *)

(* The literals as committed at [0c0662d] (P17), held against the witness
   modules the P17/P18 tests actually read, so "fix the red by editing the
   pin" reddens HERE. The P16 L0v trio is included because P18's witness
   DERIVES its first vct:true graph from those constants. If any of these
   moves, a list leaked into a shared suite or a seed/bound drifted: STOP
   and find the leak - re-pinning is the one forbidden repair. *)

let committed_p17_l0_states : int = 76
let committed_p17_lc_states : int = 464
let committed_p17_ld_states : int = 744
let committed_p17_lm_states : int = 1976
let committed_p17_l0_gate_states : int = 76
let committed_p17_lc_gate_states : int = 388
let committed_p17_ld_gate_states : int = 592
let committed_p17_lm_gate_states : int = 1824
let committed_p17_s1_interesting_l0 : int = 52
let committed_p17_s2_interesting_l0 : int = 76
let committed_p17_s3_interesting_l0 : int = 52
let committed_p16_l0v_states : int = 116
let committed_p16_l0v_max_uid_seen : int = 4
let committed_p16_l0v_max_rv_seen : int = 3

let test_p17_pins_are_the_committed_literals () =
  Alcotest.(check int) "P17 L0 states: 76 (committed at 0c0662d)"
    committed_p17_l0_states P17_witness.l0_states;
  Alcotest.(check int) "P17 Lc states: 464 (committed at 0c0662d)"
    committed_p17_lc_states P17_witness.lc_states;
  Alcotest.(check int) "P17 Ld states: 744 (committed at 0c0662d)"
    committed_p17_ld_states P17_witness.ld_states;
  Alcotest.(check int) "P17 Lm states: 1976 (committed at 0c0662d)"
    committed_p17_lm_states P17_witness.lm_states;
  Alcotest.(check int) "P17 L0 gate: 76 (committed at 0c0662d)"
    committed_p17_l0_gate_states P17_witness.l0_gate_states;
  Alcotest.(check int) "P17 Lc gate: 388 (committed at 0c0662d)"
    committed_p17_lc_gate_states P17_witness.lc_gate_states;
  Alcotest.(check int) "P17 Ld gate: 592 (committed at 0c0662d)"
    committed_p17_ld_gate_states P17_witness.ld_gate_states;
  Alcotest.(check int) "P17 Lm gate: 1824 (committed at 0c0662d)"
    committed_p17_lm_gate_states P17_witness.lm_gate_states;
  Alcotest.(check int) "P17 S1 L0 count: 52 (committed at 0c0662d)"
    committed_p17_s1_interesting_l0 P17_witness.s1_interesting_l0;
  Alcotest.(check int) "P17 S2 L0 count: 76 (committed at 0c0662d)"
    committed_p17_s2_interesting_l0 P17_witness.s2_interesting_l0;
  Alcotest.(check int) "P17 S3 L0 count: 52 (committed at 0c0662d)"
    committed_p17_s3_interesting_l0 P17_witness.s3_interesting_l0;
  Alcotest.(check int) "P16 L0v states: 116 (P18's derivation base)"
    committed_p16_l0v_states P16_witness.l0v_states;
  Alcotest.(check int) "P16 L0v max_uid: 4 (P18's derivation base)"
    committed_p16_l0v_max_uid_seen P16_witness.l0v_max_uid_seen;
  Alcotest.(check int) "P16 L0v max_rv: 3 (P18's derivation base)"
    committed_p16_l0v_max_rv_seen P16_witness.l0v_max_rv_seen

(* ==== 2. the family classification: DISJOINTNESS =========================== *)

let h1_name : string =
  "all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref"

let h2_name : string =
  "all_pvcs_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_or_owner_ref"

let names_of (invs : Invariants.invariant list) : string list =
  List.map (fun (i : Invariants.invariant) -> i.Invariants.name) invs

(* The two (name, source) pairs as COMMITTED LITERALS, compared against
   the family - a rename, source drift, or re-implementation reddens HERE
   regardless of how the family is built. The sources cite the REAL
   vstatefulset path (single file [proof/helper_invariants.rs]); the
   drifted VRS-layout string shipped in [inv_self]'s source is a section-8
   residual, NOT copied here. *)
let expected_pairs : (string * string) list =
  [
    ( "all_pods_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_and_one_owner_ref",
      "vstatefulset_controller/proof/helper_invariants.rs:52" );
    ( "all_pvcs_in_etcd_matching_vsts_have_no_finalizer_or_deletion_timestamp_or_owner_ref",
      "vstatefulset_controller/proof/helper_invariants.rs:1063" );
  ]

let test_family_names_and_pairs () =
  Alcotest.(check (list string))
    "helper_family is H1/H2 in upstream order" [ h1_name; h2_name ]
    (names_of family);
  Alcotest.(check (list (pair string string)))
    "family (name, source) pairs = the committed literals, in upstream order"
    expected_pairs
    (Pair_guard.pairs_of family);
  Alcotest.(check (list string))
    "family sources = helper_sources, in order" Hi.helper_sources
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.source) family);
  Alcotest.(check int) "helper_family cardinal = 2" 2 (List.length family)

(* Every list a PRIOR phase's leg consumes, instantiated exactly as those
   legs instantiate them - the P14-P16 firewall roster PLUS the P17 store
   family ([Ois.store_family], shipped at 0c0662d and the suite a P18
   leak would poison first: it quantifies over the same store). *)
let shipped_suites : (string * Invariants.invariant list) list =
  let vrs = Scenario.vrs ~desired:1 in
  let vsts = Scenario.vsts ~desired:1 () in
  [
    ( "Invariants.cluster_structural",
      Invariants.cluster_structural ~controller_id );
    ("Invariants.always", Invariants.always ~cr:vrs ~controller_id);
    ( "Invariants.eventually_always",
      Invariants.eventually_always ~cr:vrs ~controller_id );
    ("Vsts_invariants.always", Vsts_invariants.always ~cr:vsts ~controller_id);
    ( "Correspondence.family (P14)",
      Correspondence.family cluster ~controller_id );
    ( "Reconcile_correspondence.family (P15)",
      Rc.family ~controller_id ~pending_states:Fc.vsts_pending_states
        ~none_states:Fc.vsts_none_states );
    ("Req_resp_correspondence.rv_family (P16)", Rr.rv_family bound);
    ( "Req_resp_correspondence.matched_family (P16)",
      Rr.matched_family ~controller_id );
    ("Objects_in_store.store_family (P17)", Ois.store_family ~controller_id);
  ]

(* THE MASKING-TRAP GUARD (P14-P16 pattern). A P18 member found in ANY
   shipped suite means prior pins are no longer measuring what they claim
   (pin reason), and a unioned leg could report an earlier-firing member
   instead of the intended one (masking reason). {!Pair_guard.pair_leaks}
   detects a shared NAME or a shared SOURCE in either list, so this one
   sweep covers both leak directions. *)
let test_family_is_disjoint_from_shipped_suites () =
  let leaked : string list =
    List.concat_map
      (fun ((suite, invs) : string * Invariants.invariant list) ->
        Pair_guard.pair_leaks suite
          (Pair_guard.pairs_of family)
          (Pair_guard.pairs_of invs))
      shipped_suites
  in
  Alcotest.(check (list string))
    "no P18 helper member shares a name or source with a shipped suite" []
    leaked

(* THE E6 REGISTER GUARD: upstream :1213's name equals NO shipped member
   name (and neither P18 name), keeping the message-guarantee register
   unambiguously [inv_self]'s until a deliberate P19 port claims it. *)
let e6_name : string = "every_msg_from_vsts_controller_carries_vsts_key"

let test_e6_register_guard () =
  let hits_of (needle : string) : string list =
    List.concat_map
      (fun ((suite, invs) : string * Invariants.invariant list) ->
        List.filter_map
          (fun (n : string) ->
            if String.equal n needle then Some (suite ^ " ships " ^ n)
            else None)
          (names_of invs))
      (("Helper_invariants.helper_family (P18)", family) :: shipped_suites)
  in
  (* POSITIVE CONTROL first (P18 review): the SAME detector run for a name
     known to be shipped produces exactly one hit - the absence assertion
     below is not vacuous against a typo'd needle or an empty [names_of]
     traversal (the detector SEEN capable of finding a shipped name). *)
  Alcotest.(check (list string))
    "E6 control: the detector finds a shipped name (exactly one hit)"
    [ "Helper_invariants.helper_family (P18) ships " ^ h1_name ]
    (hits_of h1_name);
  Alcotest.(check (list string))
    "the :1213 message-sibling name is shipped by NO suite" []
    (hits_of e6_name)

(* ==== 3. the L0 / L0v replicas for the E1 / E4 pins ======================== *)

let reach_of ~(vct : bool) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound P18_witness.zero_budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:
      [
        Fc.faulted_of_seed
          (Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
             ~pod_monkey:false ~vct ());
      ]

let l0_reach : Fc.faulted Mc.reachable Lazy.t = lazy (reach_of ~vct:false)
let l0v_reach : Fc.faulted Mc.reachable Lazy.t = lazy (reach_of ~vct:true)

(* ==== 4. the E1 pin ========================================================
   The uid-exact rendering: H1's body VERBATIM except the owner-ref
   comparison, full [Owner_reference.equal] (uid INCLUDED) instead of
   [eq_without_uid] - upstream :36-49's distinguishing clause. Premise
   transcribed from [helper_invariants.ml] (key kind / namespace /
   canonical get_ordinal). *)

let scenario_cr : V_stateful_set.t = Scenario.vsts ~desired ~vct:false ()

let parent : string =
  Option.value ~default:"" (Object_meta.name (V_stateful_set.metadata scenario_cr))

let vsts_ns : string =
  Option.value ~default:""
    (Object_meta.namespace (V_stateful_set.metadata scenario_cr))

let co : Owner_reference.t option =
  V_stateful_set.controller_owner_ref scenario_cr

let pod_premise (key : Common.object_ref) : bool =
  Common.equal_kind key.Common.kind Pod.kind
  && String.equal key.Common.namespace vsts_ns
  && Option.is_some
       (V_stateful_set_reconciler.get_ordinal parent key.Common.name)

(* H1's body with the owner-ref equivalence a PARAMETER - [eq_without_uid]
   reproduces the shipped member (transcription-faithfulness pin below),
   [Owner_reference.equal] is the E1 sibling. *)
let holds_with (eq : Owner_reference.t -> Owner_reference.t -> bool)
    (s : Cluster.cluster_state) : bool =
  List.for_all
    (fun ((key, obj) : Common.object_ref * Dynamic_object.t) ->
      (not (pod_premise key))
      ||
      let md : Object_meta.t = Dynamic_object.metadata obj in
      Option.is_none md.Object_meta.deletion_timestamp
      && Option.is_none md.Object_meta.finalizers
      && Option.fold co ~none:false ~some:(fun (c : Owner_reference.t) ->
             Option.fold md.Object_meta.owner_references ~none:false
               ~some:(fun (l : Owner_reference.t list) ->
                 match l with
                 | [ r ] -> eq r c
                 | [] | _ :: _ :: _ -> false)))
    (Object_ref_map.bindings (Cluster.resources s))

let uid_exact_holds : Cluster.cluster_state -> bool =
  holds_with Owner_reference.equal

let transcript_holds : Cluster.cluster_state -> bool =
  holds_with Owner_reference.eq_without_uid

(* The SHIPPED H1, addressed by name off the family the legs thread -
   [None] is impossible (the name pin above runs first) and fails LOUD. *)
let h1_shipped : Invariants.invariant option =
  List.find_opt
    (fun (i : Invariants.invariant) -> String.equal i.Invariants.name h1_name)
    family

let with_h1 (f : Invariants.invariant -> unit) : unit =
  Option.fold h1_shipped
    ~none:(fun () -> Alcotest.fail "E1: H1 missing from the family")
    ~some:(fun (i : Invariants.invariant) () -> f i)
    ()

let test_e1_delta_is_zero_on_l0 () =
  with_h1 (fun h1 ->
      let reach = Lazy.force l0_reach in
      Alcotest.(check int) "E1: replica explored the L0 graph"
        P18_witness.l0_states (Mc.states_seen reach);
      (* Transcription faithfulness FIRST: the eq_without_uid instance of
         the parameterized body IS the shipped H1, state-by-state. *)
      Alcotest.(check int)
        "E1: transcript (eq_without_uid) = shipped H1 at every state" 0
        (Mc.count_states_where reach (fun (f : Fc.faulted) ->
             not (Bool.equal (transcript_holds f.Fc.cs) (h1.Invariants.holds f.Fc.cs))));
      (* THE PIN: uid-exact never diverges from H1 on this graph (the
         CR-delete corner is unreachable in the port). *)
      Alcotest.(check int) "E1: uid-exact delta = 0 (pinned)"
        P18_witness.e1_delta_l0
        (Mc.count_states_where reach (fun (f : Fc.faulted) ->
             not
               (Bool.equal (uid_exact_holds f.Fc.cs) (h1.Invariants.holds f.Fc.cs)))))

(* The E1 CONTROL (spec section 3): a forged wrong-uid owner ref makes the
   uid-exact rendering fail while the SHIPPED H1 holds - the delta
   detector SEEN red-capable, exactly the corner (a re-created owner with
   a fresh uid) the excluded sibling exists for upstream. *)
let stored_pod_binding : (Common.object_ref * Dynamic_object.t) option Lazy.t =
  lazy
    (Mc.fold_states (Lazy.force l0_reach) ~init:None
       ~f:(fun (acc : (Common.object_ref * Dynamic_object.t) option)
               (f : Fc.faulted) ->
         Option.fold
           (List.find_opt
              (fun ((k, _) : Common.object_ref * Dynamic_object.t) ->
                Common.equal_kind k.Common.kind Pod.kind)
              (Object_ref_map.bindings (Cluster.resources f.Fc.cs)))
           ~none:acc
           ~some:(fun (b : Common.object_ref * Dynamic_object.t) -> Some b)))

let seed_f : Cluster.cluster_state =
  Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop:false
    ~pod_monkey:false ~vct:false ()

let forged_in (resources : (Common.object_ref * Dynamic_object.t) list) :
    Cluster.cluster_state =
  let stored =
    List.fold_left
      (fun (m : Dynamic_object.t Object_ref_map.t)
           ((k, o) : Common.object_ref * Dynamic_object.t) ->
        Object_ref_map.add k o m)
      Object_ref_map.empty resources
  in
  {
    seed_f with
    Cluster.api_server =
      { seed_f.Cluster.api_server with Api_server.resources = stored };
  }

let with_some (label : string) (o : 'a option) (f : 'a -> unit) : unit =
  Option.fold o
    ~none:(fun () -> Alcotest.fail (label ^ ": missing on the true model"))
    ~some:(fun (x : 'a) () -> f x)
    ()

let test_e1_detector_red_capability () =
  with_h1 (fun h1 ->
      with_some "E1 control: stored pod" (Lazy.force stored_pod_binding)
        (fun ((key, pod) : Common.object_ref * Dynamic_object.t) ->
          with_some "E1 control: seed CR"
            (Object_ref_map.find_opt Scenario.vsts_ref
               (Cluster.resources seed_f))
            (fun (cr : Dynamic_object.t) ->
              with_some "E1 control: the stored pod's singleton ref"
                (Option.bind
                   (Dynamic_object.metadata pod).Object_meta.owner_references
                   (fun (l : Owner_reference.t list) ->
                     match l with
                     | [ r ] -> Some r
                     | [] | _ :: _ :: _ -> None))
                (fun (r : Owner_reference.t) ->
                  let wrong_uid =
                    {
                      r with
                      Owner_reference.uid =
                        Common.Uid.of_int
                          (Common.Uid.to_int r.Owner_reference.uid + 1);
                    }
                  in
                  let forged =
                    forged_in
                      [
                        (Scenario.vsts_ref, cr);
                        ( key,
                          Dynamic_object.with_metadata
                            {
                              (Dynamic_object.metadata pod) with
                              Object_meta.owner_references =
                                Some [ wrong_uid ];
                            }
                            pod );
                      ]
                  in
                  Alcotest.(check bool)
                    "E1 control: shipped H1 HOLDS on the wrong-uid forge \
                     (eq_without_uid ignores uid)"
                    true
                    (h1.Invariants.holds forged);
                  Alcotest.(check bool)
                    "E1 control: the uid-exact rendering FAILS on the same \
                     state (the delta detector is red-capable)"
                    false (uid_exact_holds forged)))))

(* ==== 5. the E4 pin ======================================================== *)

(* Non-empty owner_references on a stored object ([Some l], [l] non-empty
   - the disclosed "owned" convention, p18_witness.ml). *)
let owned (o : Dynamic_object.t) : bool =
  Option.fold (Dynamic_object.metadata o).Object_meta.owner_references
    ~none:false
    ~some:(fun (l : Owner_reference.t list) ->
      match l with [] -> false | _ :: _ -> true)

let pvc_pairs_where (reach : Fc.faulted Mc.reachable)
    (keep : Dynamic_object.t -> bool) : int =
  Mc.fold_states reach ~init:0 ~f:(fun (acc : int) (f : Fc.faulted) ->
      acc
      + List.length
          (List.filter
             (fun ((k, o) : Common.object_ref * Dynamic_object.t) ->
               Common.equal_kind k.Common.kind Persistent_volume_claim.kind
               && keep o)
             (Object_ref_map.bindings (Cluster.resources f.Fc.cs))))

let test_e4_no_owned_pvcs_on_l0v () =
  let reach = Lazy.force l0v_reach in
  Alcotest.(check int) "E4: replica explored the L0v graph"
    P18_witness.l0v_states (Mc.states_seen reach);
  (* CONTROL first: the detector sees real PVCs (80 (state, key) pairs,
     summed convention - the zero below is make_pvc's contract, not an
     empty store's). *)
  Alcotest.(check int) "E4 control: stored-PVC pairs (pinned)"
    P18_witness.e4_control_pvcs_l0v
    (pvc_pairs_where reach (fun (_ : Dynamic_object.t) -> true));
  Alcotest.(check int) "E4: owner-ref-carrying stored-PVC pairs = 0 (pinned)"
    P18_witness.e4_owned_pvcs_l0v
    (pvc_pairs_where reach owned);
  (* The detector itself is red-capable: it is the same [owned] predicate
     the E1-control forge just drove red at pod level, and the H2 forge
     ([t_p18_mutation]) plants exactly the owner-ref-bearing PVC shape it
     counts. Cheap in-place witness: a PVC binding lifted off the replica
     and marked with a default ref IS counted. *)
  with_some "E4 witness: stored PVC"
    (Mc.fold_states reach ~init:None
       ~f:(fun (acc : (Common.object_ref * Dynamic_object.t) option)
               (f : Fc.faulted) ->
         Option.fold
           (List.find_opt
              (fun ((k, _) : Common.object_ref * Dynamic_object.t) ->
                Common.equal_kind k.Common.kind
                  Persistent_volume_claim.kind)
              (Object_ref_map.bindings (Cluster.resources f.Fc.cs)))
           ~none:acc
           ~some:(fun (b : Common.object_ref * Dynamic_object.t) -> Some b)))
    (fun ((_, pvc) : Common.object_ref * Dynamic_object.t) ->
      Alcotest.(check bool)
        "E4 witness: an owner-ref-marked copy of a real PVC IS counted as \
         owned"
        true
        (owned
           (Dynamic_object.with_metadata
              {
                (Dynamic_object.metadata pvc) with
                Object_meta.owner_references =
                  Some [ Owner_reference.default () ];
              }
              pvc)))

let () =
  Alcotest.run "p18_regression"
    [
      ( "prior_phase_firewall",
        [
          Alcotest.test_case
            "P17/P16 witness constants are the committed pins" `Quick
            test_p17_pins_are_the_committed_literals;
        ] );
      ( "family_classification",
        [
          Alcotest.test_case
            "family = the two upstream names, committed (name, source) \
             pairs, cardinal 2"
            `Quick test_family_names_and_pairs;
          Alcotest.test_case
            "family DISJOINT from every shipped suite (Pair_guard, both \
             components)"
            `Quick test_family_is_disjoint_from_shipped_suites;
          Alcotest.test_case "E6: the :1213 name is shipped by no suite"
            `Quick test_e6_register_guard;
        ] );
      ( "exclusion_pins",
        [
          Alcotest.test_case
            "E1: uid-exact sibling agrees with H1 at all 76 L0 states"
            `Quick test_e1_delta_is_zero_on_l0;
          Alcotest.test_case
            "E1: the delta detector SEEN red-capable (wrong-uid forge)"
            `Quick test_e1_detector_red_capability;
          Alcotest.test_case
            "E4: zero owned stored PVCs on L0v (control 80 pairs)" `Quick
            test_e4_no_owned_pvcs_on_l0v;
        ] );
    ]

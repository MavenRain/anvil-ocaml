(* P26 pin exe (BUILD-SPEC-P26 section 3): the superseding measurement pins
   for the 8 EXCLUDED vct:true M1 conjuncts (state_predicates.mli:97-115;
   upstream state_predicates.rs :197 :198 :199 :215-221 :223-228 :233 :244
   :246), the guarantee quad, and the resp-side occupancy triad. Derived
   from probe X23 (anvil-ocaml-p26-harness/t_p26_probe.SOURCE.ml): the
   graph constructions and conjunct closures are copied byte-for-byte, the
   report shape is kept. The 8 conjuncts are NOT committed green: their
   exclusion ground stays RED-CAPABILITY-PENDING, refined by the inertness
   pin below.

   An Alcotest suite with ONE pin per test case, so a failing pin reds its
   own case and the run still completes every other case. Graph-identity
   positive controls (states_seen, inv6 gates) keep the probe's printf
   shape: a mismatch prints MISMATCH-WARN and the run CONTINUES to the
   Alcotest cases (the P25 F5 observability trap, deliberately not
   reproduced). The exe never calls [exit].

   Pin roster (BUILD-SPEC-P26 section 3.1):
   - the FULL-EVALUATION pin (C1: the four occupancy literals PROMOTED from
     P25's WARN-only controls): all eight premises Alcotest-pinned, with
     violating=0 for every one of them and blanket=80; :246u (the bare step
     gate) stays WARN-only info;
   - the INERTNESS pin, named for v_stateful_set_reconciler.ml:485/:489;
   - the GUARANTEE QUAD pins over both committed multi-CR graphs, per CR;
     G2 :581 premise=0 is pinned as the C3 vacuity record,
     vacuous-pending-scale-down;
   - the RESP OCCUPANCY pins over the fair, crash and L0v graphs;
   - the isolated List_response column (C2), FRESH-MEASURED at stage B
     (2026-08-07) and pinned then, under the pre-stated bucket-sum
     constraint: List distinct_msgs plus residual-Other distinct_msgs must
     equal the old Other bucket, 3760 FAIR / 3264 CRASH / 12 L0v, and the
     SUM-MATCH control stays green.

   Two disclosed renderings ride with the pins, copied from the probe:
   - :220's [pvc.state_validation()] is rendered [Option.is_some pvc.spec],
     the equivalence v_stateful_set.ml:81-86 discloses as provable upstream;
   - :224-227 index [state.pvcs[i]] for i < pvc_cnt; the port zips templates
     against [pvcs] positionally and renders a too-short [pvcs] as false.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   exceptions, no two-arm match on Option/Result, no wildcard match on a
   finite sum, no raw indexing. *)

module Cc = Anvil_checker.Cluster_check
module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Ig = Anvil_assurance.Internal_guarantee
module Vsr = V_stateful_set_reconciler
module W = P24_witness

(* The scenario coordinates every committed pin was measured against. *)
let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster

(* ==== SECTION A GRAPH: L0v, P18's committed 116-state vct:true graph,
   byte-for-byte t_p18_regression.ml:259-271's [reach_of ~vct:true] (the
   t_p26_probe.SOURCE.ml:65-104 copy). *)

let l0v_desired : int = P18_witness.witness_desired
let l0v_depth : int = P18_witness.witness_depth
let l0v_bound : Bound.t = P18_witness.p18_bound ~desireds:[ l0v_desired ]

let l0v_reach : Fc.faulted Mc.reachable =
  Mc.explore ~depth:l0v_depth
    ~successors:(Fc.faulted_successors l0v_bound P18_witness.zero_budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:
      [
        Fc.faulted_of_seed
          (Scenario.vsts_seed_faults ~desired:l0v_desired ~crash:true
             ~req_drop:false ~pod_monkey:false ~vct:true ());
      ]

(* The vct:true CR (the same scenario CR the L0v seed marshals). *)
let cr_v : V_stateful_set.t = Scenario.vsts ~desired:l0v_desired ~vct:true ()
let cr_key_v : Common.object_ref = W.cr_key_of cr_v
let name_v : string = W.name_of cr_v
let namespace_v : string = W.namespace_of cr_v

(* [pvc_cnt] and the template list, derived INLINE from the CR spec, never a
   ported field (state_predicates.rs:193 / :259-261). *)
let templates_v : Persistent_volume_claim.t list =
  Option.value ~default:[]
    (V_stateful_set.spec cr_v).Stateful_set.volume_claim_templates

let pvc_cnt : int = List.length templates_v

(* Count L0v cluster states satisfying [p] (project the faulted product). *)
let count_l0v (p : Cluster.cluster_state -> bool) : int =
  Mc.count_states_where l0v_reach (fun (f : Fc.faulted) -> p f.Fc.cs)

let sum_l0v (g : Cluster.cluster_state -> int) : int =
  Mc.fold_states l0v_reach ~init:0
    ~f:(fun (acc : int) (f : Fc.faulted) -> acc + g f.Fc.cs)

(* M1's blanket premise: the FOURTEEN steps at which upstream ever asserts
   [local_state_is_valid] - a deliberate inline duplicate of the unexported
   State_predicates.at_valid_step (state_predicates.ml:237-244). *)
let at_valid_step (step : Vsr.step) : bool =
  match step with
  | Vsr.Get_pvc | Vsr.After_get_pvc | Vsr.Create_pvc | Vsr.After_create_pvc
  | Vsr.Skip_pvc | Vsr.Create_needed | Vsr.After_create_needed
  | Vsr.Update_needed | Vsr.After_update_needed | Vsr.Delete_condemned
  | Vsr.After_delete_condemned | Vsr.Delete_outdated
  | Vsr.After_delete_outdated | Vsr.Done ->
    true
  | Vsr.Init | Vsr.After_list_pod | Vsr.Error -> false

let at_step (st : Vsr.s) (step : Vsr.step) : bool =
  Vsr.step_equal st.Vsr.reconcile_step step

(* :215-221's per-PVC forall. :220 [state_validation()] rendered
   [Option.is_some pvc.spec] per the v_stateful_set.ml:81-86 disclosure. *)
let pvcs_forall_ok (st : Vsr.s) : bool =
  List.for_all
    (fun (pvc : Persistent_volume_claim.t) ->
      let md : Object_meta.t = pvc.Persistent_volume_claim.metadata in
      Option.is_some md.name
      && Option.equal String.equal md.namespace (Some namespace_v)
      && Option.is_none md.owner_references
      && Option.is_some pvc.Persistent_volume_claim.spec)
    st.Vsr.pvcs

(* :223-228's pvc-name block: for every i < pvc_cnt,
   pvcs[i].metadata.name = Some (pvc_name templates[i].metadata.name
   vsts_name needed_index) (rs:225 reads NEEDED_index, not pvc_index).
   Positional zip via a fold; a [pvcs] shorter than [templates_v] is false. *)
let pvc_names_ok (st : Vsr.s) : bool =
  let template_name_ok (tmpl : Persistent_volume_claim.t)
      (pvc : Persistent_volume_claim.t) : bool =
    let tmd : Object_meta.t = tmpl.Persistent_volume_claim.metadata in
    let pmd : Object_meta.t = pvc.Persistent_volume_claim.metadata in
    Option.fold tmd.name ~none:false ~some:(fun (tn : string) ->
        Option.equal String.equal pmd.name
          (Some (Vsr.pvc_name tn name_v st.Vsr.needed_index)))
  in
  let ok, _rest =
    List.fold_left
      (fun ((ok, rest) : bool * Persistent_volume_claim.t list)
           (tmpl : Persistent_volume_claim.t) ->
        match rest with
        | [] -> (false, [])
        | pvc :: tl -> (ok && template_name_ok tmpl pvc, tl))
      (true, st.Vsr.pvcs) templates_v
  in
  ok

(* The 5-step Get_pvc family (:223's own antecedent). *)
let at_get_pvc_family (st : Vsr.s) : bool =
  at_step st Vsr.Get_pvc || at_step st Vsr.After_get_pvc
  || at_step st Vsr.Create_pvc || at_step st Vsr.After_create_pvc
  || at_step st Vsr.Skip_pvc

(* :244's 4-step antecedent. *)
let at_244_family (st : Vsr.s) : bool =
  at_step st Vsr.Get_pvc || at_step st Vsr.After_get_pvc
  || at_step st Vsr.Create_pvc || at_step st Vsr.Skip_pvc

(* :246's antecedent, in BOTH forms: the P25-measured premise (step gate AND
   pvc_index > 0, the pinned-8 form: t_p25_state_predicates.ml:281-284) and
   the bare upstream step gate. *)
let at_246_step (st : Vsr.s) : bool =
  at_step st Vsr.Create_needed || at_step st Vsr.Update_needed

let at_246_premise_p25 (st : Vsr.s) : bool =
  at_246_step st && st.Vsr.pvc_index > 0

(* Lift a Vsr.s predicate to L0v cluster states at the vct CR's key. *)
let lift_v (p : Vsr.s -> bool) : Cluster.cluster_state -> bool =
  W.at_orc ~controller_id ~cr_key:cr_key_v (fun _ (st : Vsr.s) _ -> p st)

(* One conjunct's measured (premise, violating) pair over L0v: [violating]
   counts states where the inner premise fires AND the consequent fails -
   for the step-gated conjuncts this equals "blanket premise AND full
   implication false", since the implication is vacuous off its own gate. *)
let measure_a (inner : Vsr.s -> bool) (consequent : Vsr.s -> bool) : int * int
    =
  ( count_l0v (lift_v inner),
    count_l0v (lift_v (fun (st : Vsr.s) -> inner st && not (consequent st))) )

let blanket_occupancy : int =
  count_l0v (lift_v (fun (st : Vsr.s) -> at_valid_step st.Vsr.reconcile_step))

(* The eight conjunct pairs, measured ONCE at module init and shared by the
   report and the pins (no keyed lookup between them: a missed lookup would
   pass vacuously). *)
let a_197 : int * int =
  measure_a
    (fun (st : Vsr.s) -> at_valid_step st.Vsr.reconcile_step)
    (fun (st : Vsr.s) -> st.Vsr.pvc_index <= pvc_cnt)

let a_198 : int * int =
  measure_a
    (fun (st : Vsr.s) -> at_valid_step st.Vsr.reconcile_step)
    (fun (st : Vsr.s) -> List.length st.Vsr.pvcs = pvc_cnt)

let a_199 : int * int =
  measure_a
    (fun (st : Vsr.s) -> at_step st Vsr.Get_pvc)
    (fun (st : Vsr.s) -> st.Vsr.pvc_index < List.length st.Vsr.pvcs)

let a_215_221 : int * int =
  measure_a
    (fun (st : Vsr.s) -> at_valid_step st.Vsr.reconcile_step)
    pvcs_forall_ok

let a_223_228 : int * int = measure_a at_get_pvc_family pvc_names_ok

let a_233 : int * int =
  measure_a
    (fun (st : Vsr.s) -> at_step st Vsr.After_create_pvc)
    (fun (st : Vsr.s) -> st.Vsr.pvc_index > 0)

let a_244 : int * int =
  measure_a at_244_family (fun (st : Vsr.s) -> st.Vsr.pvc_index < pvc_cnt)

let a_246 : int * int =
  measure_a at_246_premise_p25 (fun (st : Vsr.s) ->
      st.Vsr.pvc_index = pvc_cnt)

(* :246u stays WARN-only info (BUILD-SPEC-P26 section 3.1): reported, never
   Alcotest-pinned. *)
let a_246u : int * int =
  measure_a at_246_step (fun (st : Vsr.s) -> st.Vsr.pvc_index = pvc_cnt)

(* The report rows: (label, measured pair, expected premise option). The
   expected occupancies are now all Alcotest-pinned below (C1 PROMOTED);
   the option here only drives the probe-shaped expect note. *)
let section_a_report_rows : (string * (int * int) * int option) list =
  [
    (":197 pvc_index<=pvc_cnt", a_197, Some 80);
    (":198 pvcs.len=pvc_cnt", a_198, Some 80);
    (":199 GetPVC=>idx<pvcs.len", a_199, Some 8);
    (":215-221 pvcs-forall", a_215_221, Some 80);
    (":223-228 pvc-names", a_223_228, Some 40);
    (":233 AfterCreatePVC=>idx>0", a_233, Some 8);
    (":244 4-step=>idx<pvc_cnt", a_244, Some 32);
    (":246 (P25 premise idx>0)", a_246, Some 8);
    (":246u (bare step gate)", a_246u, None);
  ]

(* ==== SECTION B/C GRAPHS: the two committed multi-CR graphs, byte-for-byte
   as p25_witness.ml:41-99 rebuilds them (this exe does NOT reference
   P25_witness's graphs, so the eager explorations there are not paid
   twice). ==== *)

let multi_depth : int = 40

let fair_bound : Bound.t = P12_witness.p12_bound ~desireds:[ 1; 1 ]

let fair_seed : Cluster.cluster_state =
  Scenario.vsts_seed_multi ~desireds:[ 1; 1 ] ~fair:true

let fair_reach : Cluster.cluster_state Mc.reachable =
  Mc.explore ~depth:multi_depth
    ~successors:(Cc.bounded_successors fair_bound cluster)
    ~equal:Cc.state_equal ~hash:Cc.state_hash ~init:[ fair_seed ]

let crash_bound : Bound.t = P13_witness.p13_bound ~desireds:[ 1; 1 ]

let crash_seed : Cluster.cluster_state =
  Scenario.vsts_seed_multi_faults ~desireds:[ 1; 1 ] ~crash:true
    ~req_drop:false ~pod_monkey:false

let crash_reach : Fc.faulted Mc.reachable =
  Mc.explore ~depth:multi_depth
    ~successors:(Fc.faulted_successors crash_bound Fc.budget_crash_only cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed crash_seed ]

let count_fair (p : Cluster.cluster_state -> bool) : int =
  Mc.count_states_where fair_reach p

let count_crash (p : Cluster.cluster_state -> bool) : int =
  Mc.count_states_where crash_reach (fun (f : Fc.faulted) -> p f.Fc.cs)

let sum_fair (g : Cluster.cluster_state -> int) : int =
  Mc.fold_states fair_reach ~init:0
    ~f:(fun (acc : int) (s : Cluster.cluster_state) -> acc + g s)

let sum_crash (g : Cluster.cluster_state -> int) : int =
  Mc.fold_states crash_reach ~init:0
    ~f:(fun (acc : int) (f : Fc.faulted) -> acc + g f.Fc.cs)

(* Graph-identity controls (derived pins, never re-typed where a witness
   exports them): inv6's committed gate populations identify the two graphs. *)
let inv6 : Anvil_assurance.Invariants.invariant =
  Anvil_assurance.Invariants.unique_reconcile_id_invariant ~controller_id

let fair_inv6_gate : int =
  count_fair inv6.Anvil_assurance.Invariants.interesting

let crash_inv6_crash_gate : int =
  Mc.count_states_where crash_reach (fun (f : Fc.faulted) ->
      inv6.Anvil_assurance.Invariants.interesting f.Fc.cs && f.Fc.crashes >= 1)

(* ==== SECTION B: the shipped guarantee family per multi-seed CR ==========
   The two CRs exactly as scenario.ml:619-639 admits them: names "vsts1" /
   "vsts2", desired 1 each, vct:false. All four member names in family
   order (internal_guarantee.ml:376-441); G4 is upstream :544, the
   :133-180 window's own premise. *)

let cr_1 : V_stateful_set.t = Scenario.vsts_named ~name:"vsts1" ~desired:1 ()
let cr_2 : V_stateful_set.t = Scenario.vsts_named ~name:"vsts2" ~desired:1 ()

let g1_name : string = "vsts_internal_guarantee_create_req"
let g2_name : string = "vsts_internal_guarantee_get_then_delete_req"
let g3_name : string = "vsts_internal_guarantee_get_then_update_req"
let g4_name : string = "no_interfering_request_between_vsts"

(* One member's measured (premise, violating) pair on one graph for one CR,
   via the SHIPPED [Ig.guarantee_family] members - never a re-derivation. *)
let measure_b (count : (Cluster.cluster_state -> bool) -> int)
    (cr : V_stateful_set.t) (mname : string) : int * int =
  let fam = Ig.guarantee_family ~cr ~controller_id in
  ( count (W.member_interesting fam mname),
    count (fun (s : Cluster.cluster_state) ->
        W.member_interesting fam mname s && not (W.member_holds fam mname s))
  )

let b_fair_1_g1 : int * int = measure_b count_fair cr_1 g1_name
let b_fair_1_g2 : int * int = measure_b count_fair cr_1 g2_name
let b_fair_1_g3 : int * int = measure_b count_fair cr_1 g3_name
let b_fair_1_g4 : int * int = measure_b count_fair cr_1 g4_name
let b_fair_2_g1 : int * int = measure_b count_fair cr_2 g1_name
let b_fair_2_g2 : int * int = measure_b count_fair cr_2 g2_name
let b_fair_2_g3 : int * int = measure_b count_fair cr_2 g3_name
let b_fair_2_g4 : int * int = measure_b count_fair cr_2 g4_name
let b_crash_1_g1 : int * int = measure_b count_crash cr_1 g1_name
let b_crash_1_g2 : int * int = measure_b count_crash cr_1 g2_name
let b_crash_1_g3 : int * int = measure_b count_crash cr_1 g3_name
let b_crash_1_g4 : int * int = measure_b count_crash cr_1 g4_name
let b_crash_2_g1 : int * int = measure_b count_crash cr_2 g1_name
let b_crash_2_g2 : int * int = measure_b count_crash cr_2 g2_name
let b_crash_2_g3 : int * int = measure_b count_crash cr_2 g3_name
let b_crash_2_g4 : int * int = measure_b count_crash cr_2 g4_name

(* The report rows, in the probe's print order. *)
let section_b_report : (string * string * string * (int * int)) list =
  [
    ("FAIR", "vsts1", g1_name, b_fair_1_g1);
    ("FAIR", "vsts1", g2_name, b_fair_1_g2);
    ("FAIR", "vsts1", g3_name, b_fair_1_g3);
    ("FAIR", "vsts1", g4_name, b_fair_1_g4);
    ("FAIR", "vsts2", g1_name, b_fair_2_g1);
    ("FAIR", "vsts2", g2_name, b_fair_2_g2);
    ("FAIR", "vsts2", g3_name, b_fair_2_g3);
    ("FAIR", "vsts2", g4_name, b_fair_2_g4);
    ("CRASH", "vsts1", g1_name, b_crash_1_g1);
    ("CRASH", "vsts1", g2_name, b_crash_1_g2);
    ("CRASH", "vsts1", g3_name, b_crash_1_g3);
    ("CRASH", "vsts1", g4_name, b_crash_1_g4);
    ("CRASH", "vsts2", g1_name, b_crash_2_g1);
    ("CRASH", "vsts2", g2_name, b_crash_2_g2);
    ("CRASH", "vsts2", g3_name, b_crash_2_g3);
    ("CRASH", "vsts2", g4_name, b_crash_2_g4);
  ]

(* ==== SECTION C: resp-in-flight occupancy per kind =======================
   All NINE [Api_method.api_response] constructors, exhaustively. C2: the
   List_response column is ISOLATED (the probe folded it to "Other"); the
   residual Other bucket is the remaining four constructors. *)

let resp_kind_label (r : Api_method.api_response) : string =
  match r with
  | Api_method.Create_response _ -> "Create_response"
  | Api_method.Update_response _ -> "Update_response"
  | Api_method.Delete_response _ -> "Delete_response"
  | Api_method.Get_response _ -> "Get_response"
  | Api_method.List_response _ -> "List_response"
  | Api_method.Update_status_response _ -> "Other"
  | Api_method.Get_then_delete_response _ -> "Other"
  | Api_method.Get_then_update_response _ -> "Other"
  | Api_method.Get_then_update_status_response _ -> "Other"

(* The distinct in-flight responses of a state. *)
let resps (s : Cluster.cluster_state) : Api_method.api_response list =
  List.filter_map
    (fun (m : Message.t) ->
      match m.Message.content with
      | Message.Api_request _ -> None
      | Message.Api_response r -> Some r
      | Message.External_request _ -> None
      | Message.External_response _ -> None)
    (Message.Pool.distinct (Cluster.in_flight s))

(* One kind's (states, distinct_msgs) cell on one graph. *)
let measure_c (count : (Cluster.cluster_state -> bool) -> int)
    (sum : (Cluster.cluster_state -> int) -> int) (k : string) : int * int =
  ( count (fun (s : Cluster.cluster_state) ->
        List.exists
          (fun (r : Api_method.api_response) ->
            String.equal (resp_kind_label r) k)
          (resps s)),
    sum (fun (s : Cluster.cluster_state) ->
        List.length
          (List.filter
             (fun (r : Api_method.api_response) ->
               String.equal (resp_kind_label r) k)
             (resps s))) )

let measure_c_any (count : (Cluster.cluster_state -> bool) -> int)
    (sum : (Cluster.cluster_state -> int) -> int) : int * int =
  ( count (fun (s : Cluster.cluster_state) -> not (resps s = [])),
    sum (fun (s : Cluster.cluster_state) -> List.length (resps s)) )

let c_fair_create : int * int = measure_c count_fair sum_fair "Create_response"
let c_fair_update : int * int = measure_c count_fair sum_fair "Update_response"
let c_fair_delete : int * int = measure_c count_fair sum_fair "Delete_response"
let c_fair_get : int * int = measure_c count_fair sum_fair "Get_response"
let c_fair_list : int * int = measure_c count_fair sum_fair "List_response"
let c_fair_other : int * int = measure_c count_fair sum_fair "Other"
let c_fair_any : int * int = measure_c_any count_fair sum_fair

let c_crash_create : int * int =
  measure_c count_crash sum_crash "Create_response"

let c_crash_update : int * int =
  measure_c count_crash sum_crash "Update_response"

let c_crash_delete : int * int =
  measure_c count_crash sum_crash "Delete_response"

let c_crash_get : int * int = measure_c count_crash sum_crash "Get_response"
let c_crash_list : int * int = measure_c count_crash sum_crash "List_response"
let c_crash_other : int * int = measure_c count_crash sum_crash "Other"
let c_crash_any : int * int = measure_c_any count_crash sum_crash

let c_l0v_create : int * int = measure_c count_l0v sum_l0v "Create_response"
let c_l0v_update : int * int = measure_c count_l0v sum_l0v "Update_response"
let c_l0v_delete : int * int = measure_c count_l0v sum_l0v "Delete_response"
let c_l0v_get : int * int = measure_c count_l0v sum_l0v "Get_response"
let c_l0v_list : int * int = measure_c count_l0v sum_l0v "List_response"
let c_l0v_other : int * int = measure_c count_l0v sum_l0v "Other"
let c_l0v_any : int * int = measure_c_any count_l0v sum_l0v

let c_rows_fair : (string * (int * int)) list =
  [
    ("Create_response", c_fair_create);
    ("Update_response", c_fair_update);
    ("Delete_response", c_fair_delete);
    ("Get_response", c_fair_get);
    ("List_response", c_fair_list);
    ("Other", c_fair_other);
  ]

let c_rows_crash : (string * (int * int)) list =
  [
    ("Create_response", c_crash_create);
    ("Update_response", c_crash_update);
    ("Delete_response", c_crash_delete);
    ("Get_response", c_crash_get);
    ("List_response", c_crash_list);
    ("Other", c_crash_other);
  ]

let c_rows_l0v : (string * (int * int)) list =
  [
    ("Create_response", c_l0v_create);
    ("Update_response", c_l0v_update);
    ("Delete_response", c_l0v_delete);
    ("Get_response", c_l0v_get);
    ("List_response", c_l0v_list);
    ("Other", c_l0v_other);
  ]

(* ==== probe-shaped report (WARN-only controls; the run always reaches the
   Alcotest cases) ========================================================= *)

let control_line (label : string) (got : int) (pinned : int) : string =
  Printf.sprintf "%s = %d (expect %d) -> %s" label got pinned
    (if got = pinned then "MATCH" else "MISMATCH-WARN (continuing anyway)")

let print_a ((label, (premise, violating), expected) :
              string * (int * int) * int option) : unit =
  let expect_note =
    Option.fold expected ~none:"(no pin)" ~some:(fun (e : int) ->
        Printf.sprintf "(expect %d -> %s)" e
          (if premise = e then "MATCH" else "MISMATCH-WARN"))
  in
  Printf.printf "  A %-28s premise=%-4d %-28s violating=%d\n" label premise
    expect_note violating

let print_b ((glabel, crlabel, mname, (premise, violating)) :
              string * string * string * (int * int)) : unit =
  Printf.printf "  B %-5s cr=%s %-44s premise=%d violating=%d\n" glabel
    crlabel mname premise violating

let print_c (glabel : string) (rows : (string * (int * int)) list)
    ((any_states, total_msgs) : int * int) : unit =
  let bucket_sum =
    List.fold_left
      (fun (acc : int) ((_, (_, m)) : string * (int * int)) -> acc + m)
      0 rows
  in
  List.iter
    (fun ((k, (st_n, msg_n)) : string * (int * int)) ->
      Printf.printf "  C %-5s resp-kind %-16s states=%d distinct_msgs=%d\n"
        glabel k st_n msg_n)
    rows;
  Printf.printf
    "  C %-5s ANY_response       states=%d distinct_msgs=%d bucket_sum=%d -> %s\n"
    glabel any_states total_msgs bucket_sum
    (if bucket_sum = total_msgs then "SUM-MATCH" else "SUM-MISMATCH-WARN")

(* ==== Alcotest pins ====================================================== *)

(* Full-evaluation pin (C1 PROMOTED): blanket occupancy. *)
let test_blanket_occupancy () : unit =
  Alcotest.(check int) "L0v blanket (at_valid_step) occupancy = 80" 80
    blanket_occupancy

let test_pin_197 () : unit =
  Alcotest.(check (pair int int))
    ":197 pvc_index<=pvc_cnt on L0v: premise=80, violating=0" (80, 0) a_197

let test_pin_198 () : unit =
  Alcotest.(check (pair int int))
    ":198 pvcs.len=pvc_cnt on L0v: premise=80, violating=0" (80, 0) a_198

let test_pin_199 () : unit =
  Alcotest.(check (pair int int))
    ":199 GetPVC=>idx<pvcs.len on L0v: premise=8, violating=0" (8, 0) a_199

let test_pin_215_221 () : unit =
  Alcotest.(check (pair int int))
    ":215-221 pvcs-forall on L0v: premise=80, violating=0" (80, 0) a_215_221

let test_pin_223_228 () : unit =
  Alcotest.(check (pair int int))
    ":223-228 pvc-names on L0v: premise=40, violating=0" (40, 0) a_223_228

let test_pin_233 () : unit =
  Alcotest.(check (pair int int))
    ":233 AfterCreatePVC=>idx>0 on L0v: premise=8, violating=0" (8, 0) a_233

let test_pin_244 () : unit =
  Alcotest.(check (pair int int))
    ":244 4-step=>idx<pvc_cnt on L0v: premise=32, violating=0" (32, 0) a_244

let test_pin_246 () : unit =
  Alcotest.(check (pair int int))
    ":246 (P25 premise idx>0) on L0v: premise=8, violating=0" (8, 0) a_246

(* The INERTNESS pin, named for v_stateful_set_reconciler.ml:485/:489.
   Ground (BUILD-SPEC-P26 section 3.1): :198 pins pvcs.len=pvc_cnt=1 at
   every blanket state, so a state minted by a mutated else-leg would carry
   pvc_index=2>1 and redden :197; violating=0 proves BOTH
   dispatch_after_list else-legs (v_stateful_set_reconciler.ml:485
   Delete_condemned, :489 Delete_outdated) unreachable on L0v
   (After_list_pod always takes ml:479-482 via ml:565). Evidence:
   probe-p26-run-mutated.log and probe-p26-run-mutated-485.log
   byte-identical per row. *)
let test_inertness_ml485_489 () : unit =
  Alcotest.(check (pair int int))
    "ml:485/:489 inertness: :197 violating=0 AND :198 violating=0 on L0v"
    (0, 0)
    (snd a_197, snd a_198)

(* Guarantee quad pins: each case pins one member's (premise, violating)
   for BOTH CRs against the same literals, so vsts1 = vsts2 is asserted per
   member (identical per CR). *)
let test_quad_fair_g1 () : unit =
  Alcotest.(check (list (pair int int)))
    "FAIR G1 create: premise=668 violating=0, vsts1 = vsts2"
    [ (668, 0); (668, 0) ]
    [ b_fair_1_g1; b_fair_2_g1 ]

(* G2 :581 premise=0 is the C3 vacuity record: vacuous-pending-scale-down.
   desired=1 per CR and no scale-down ever emits Get_then_delete_request;
   a graph that later un-vacuizes G2 reds this pin instead of drifting
   silently. *)
let test_quad_fair_g2 () : unit =
  Alcotest.(check (list (pair int int)))
    "FAIR G2 :581 get_then_delete: premise=0 (vacuous-pending-scale-down) \
     violating=0, vsts1 = vsts2"
    [ (0, 0); (0, 0) ]
    [ b_fair_1_g2; b_fair_2_g2 ]

let test_quad_fair_g3 () : unit =
  Alcotest.(check (list (pair int int)))
    "FAIR G3 get_then_update: premise=440 violating=0, vsts1 = vsts2"
    [ (440, 0); (440, 0) ]
    [ b_fair_1_g3; b_fair_2_g3 ]

let test_quad_fair_g4 () : unit =
  Alcotest.(check (list (pair int int)))
    "FAIR G4 no_interfering: premise=2088 violating=0, vsts1 = vsts2"
    [ (2088, 0); (2088, 0) ]
    [ b_fair_1_g4; b_fair_2_g4 ]

let test_quad_crash_g1 () : unit =
  Alcotest.(check (list (pair int int)))
    "CRASH G1 create: premise=1224 violating=0, vsts1 = vsts2"
    [ (1224, 0); (1224, 0) ]
    [ b_crash_1_g1; b_crash_2_g1 ]

let test_quad_crash_g2 () : unit =
  Alcotest.(check (list (pair int int)))
    "CRASH G2 :581 get_then_delete: premise=0 (vacuous-pending-scale-down) \
     violating=0, vsts1 = vsts2"
    [ (0, 0); (0, 0) ]
    [ b_crash_1_g2; b_crash_2_g2 ]

let test_quad_crash_g3 () : unit =
  Alcotest.(check (list (pair int int)))
    "CRASH G3 get_then_update: premise=32 violating=0, vsts1 = vsts2"
    [ (32, 0); (32, 0) ]
    [ b_crash_1_g3; b_crash_2_g3 ]

let test_quad_crash_g4 () : unit =
  Alcotest.(check (list (pair int int)))
    "CRASH G4 no_interfering: premise=2328 violating=0, vsts1 = vsts2"
    [ (2328, 0); (2328, 0) ]
    [ b_crash_1_g4; b_crash_2_g4 ]

(* Resp occupancy pins (states column; the four requested kinds per graph). *)
let test_resp_occupancy_fair () : unit =
  Alcotest.(check (list (pair string int)))
    "FAIR resp-kind state occupancy: Create=2064, Update=0, Delete=0, Get=0"
    [
      ("Create_response", 2064);
      ("Update_response", 0);
      ("Delete_response", 0);
      ("Get_response", 0);
    ]
    [
      ("Create_response", fst c_fair_create);
      ("Update_response", fst c_fair_update);
      ("Delete_response", fst c_fair_delete);
      ("Get_response", fst c_fair_get);
    ]

let test_resp_occupancy_crash () : unit =
  Alcotest.(check (list (pair string int)))
    "CRASH resp-kind state occupancy: Create=3552, Update=0, Delete=0, Get=0"
    [
      ("Create_response", 3552);
      ("Update_response", 0);
      ("Delete_response", 0);
      ("Get_response", 0);
    ]
    [
      ("Create_response", fst c_crash_create);
      ("Update_response", fst c_crash_update);
      ("Delete_response", fst c_crash_delete);
      ("Get_response", fst c_crash_get);
    ]

let test_resp_occupancy_l0v () : unit =
  Alcotest.(check (list (pair string int)))
    "L0v resp-kind state occupancy: Create=8, Update=0, Delete=0, Get=8"
    [
      ("Create_response", 8);
      ("Update_response", 0);
      ("Delete_response", 0);
      ("Get_response", 8);
    ]
    [
      ("Create_response", fst c_l0v_create);
      ("Update_response", fst c_l0v_update);
      ("Delete_response", fst c_l0v_delete);
      ("Get_response", fst c_l0v_get);
    ]

(* List_response column (C2), FRESH-MEASURED at stage B and pinned then
   (the P25 LEG3 precedent): each case pins one graph's
   ((List states, List distinct_msgs), (residual-Other states,
   residual-Other distinct_msgs)) quad, minted from this exe's own stage-B
   run (anvil-ocaml-p26-harness/stageB-exec-pass1.log:45-46,52-53,59-60). *)
let test_list_column_fair () : unit =
  Alcotest.(check (pair (pair int int) (pair int int)))
    "FAIR List_response (states, distinct_msgs) and residual Other, \
     fresh-measured 2026-08-07"
    ((2736, 2880), (880, 880))
    (c_fair_list, c_fair_other)

let test_list_column_crash () : unit =
  Alcotest.(check (pair (pair int int) (pair int int)))
    "CRASH List_response (states, distinct_msgs) and residual Other, \
     fresh-measured 2026-08-07"
    ((3088, 3200), (64, 64))
    (c_crash_list, c_crash_other)

let test_list_column_l0v () : unit =
  Alcotest.(check (pair (pair int int) (pair int int)))
    "L0v List_response (states, distinct_msgs) and residual Other, \
     fresh-measured 2026-08-07"
    ((8, 8), (4, 4))
    (c_l0v_list, c_l0v_other)

(* The pre-stated bucket-sum constraint (BUILD-SPEC-P26 section 1.2): per
   graph, List distinct_msgs plus residual-Other distinct_msgs must equal
   the old Other bucket. *)
let test_list_sum_fair () : unit =
  Alcotest.(check int)
    "FAIR List + residual-Other distinct_msgs = old Other bucket 3760" 3760
    (snd c_fair_list + snd c_fair_other)

let test_list_sum_crash () : unit =
  Alcotest.(check int)
    "CRASH List + residual-Other distinct_msgs = old Other bucket 3264" 3264
    (snd c_crash_list + snd c_crash_other)

let test_list_sum_l0v () : unit =
  Alcotest.(check int)
    "L0v List + residual-Other distinct_msgs = old Other bucket 12" 12
    (snd c_l0v_list + snd c_l0v_other)

(* ==== report, then the suite ============================================= *)

let () =
  Printf.printf "\n[t_p26_pins] ==== PIN DUMP (committed graphs) ====\n\n";
  Printf.printf "== SECTION A: 8 excluded vct:true M1 conjuncts over L0v ==\n";
  Printf.printf "%s\n"
    (control_line "L0v states_seen" (Mc.states_seen l0v_reach)
       P18_witness.l0v_states);
  Printf.printf "L0v decoded=%d pvc_cnt=%d (info, no pin)\n"
    (count_l0v (W.decoded ~controller_id ~cr_key:cr_key_v))
    pvc_cnt;
  Printf.printf "%s\n"
    (control_line "L0v blanket (at_valid_step) occupancy" blanket_occupancy 80);
  List.iter print_a section_a_report_rows;
  Printf.printf
    "\n== SECTION B: guarantee family (upstream :133-180) over multi-CR \
     graphs ==\n";
  Printf.printf "%s\n"
    (control_line "FAIR [1;1] states_seen" (Mc.states_seen fair_reach) 8580);
  Printf.printf "%s\n"
    (control_line "FAIR inv6 gate" fair_inv6_gate P12_witness.pinned_gate_states);
  Printf.printf "%s\n"
    (control_line "CRASH G2 [1;1] states_seen" (Mc.states_seen crash_reach)
       10552);
  Printf.printf "%s\n"
    (control_line "CRASH inv6 post-crash gate" crash_inv6_crash_gate
       P13_witness.g2_gate_states);
  List.iter print_b section_b_report;
  Printf.printf
    "\n== SECTION C: resp-in-flight occupancy per kind (premise half ONLY; \
     C2: List_response isolated) ==\n";
  print_c "FAIR" c_rows_fair c_fair_any;
  print_c "CRASH" c_rows_crash c_crash_any;
  print_c "L0V" c_rows_l0v c_l0v_any;
  Printf.printf "\n[t_p26_pins] ==== END PIN DUMP ====\n\n";
  Alcotest.run "p26_pins"
    [
      ( "full_evaluation_pin",
        [
          Alcotest.test_case
            "L0v blanket (at_valid_step) occupancy is the promoted literal 80"
            `Quick test_blanket_occupancy;
          Alcotest.test_case ":197 premise=80 violating=0 (L0v)" `Quick
            test_pin_197;
          Alcotest.test_case ":198 premise=80 violating=0 (L0v)" `Quick
            test_pin_198;
          Alcotest.test_case ":199 premise=8 violating=0 (L0v, C1 promoted)"
            `Quick test_pin_199;
          Alcotest.test_case ":215-221 premise=80 violating=0 (L0v)" `Quick
            test_pin_215_221;
          Alcotest.test_case ":223-228 premise=40 violating=0 (L0v)" `Quick
            test_pin_223_228;
          Alcotest.test_case ":233 premise=8 violating=0 (L0v, C1 promoted)"
            `Quick test_pin_233;
          Alcotest.test_case ":244 premise=32 violating=0 (L0v, C1 promoted)"
            `Quick test_pin_244;
          Alcotest.test_case ":246 premise=8 violating=0 (L0v, P25 premise)"
            `Quick test_pin_246;
        ] );
      ( "inertness_pin_ml485_489",
        [
          Alcotest.test_case
            "both dispatch_after_list else-legs (ml:485/:489) unreachable on \
             L0v: :197/:198 violating=0"
            `Quick test_inertness_ml485_489;
        ] );
      ( "guarantee_quad_pins",
        [
          Alcotest.test_case "FAIR G1 create premise=668, both CRs" `Quick
            test_quad_fair_g1;
          Alcotest.test_case
            "FAIR G2 :581 premise=0, vacuous-pending-scale-down (C3)" `Quick
            test_quad_fair_g2;
          Alcotest.test_case "FAIR G3 get_then_update premise=440, both CRs"
            `Quick test_quad_fair_g3;
          Alcotest.test_case "FAIR G4 no_interfering premise=2088, both CRs"
            `Quick test_quad_fair_g4;
          Alcotest.test_case "CRASH G1 create premise=1224, both CRs" `Quick
            test_quad_crash_g1;
          Alcotest.test_case
            "CRASH G2 :581 premise=0, vacuous-pending-scale-down (C3)" `Quick
            test_quad_crash_g2;
          Alcotest.test_case "CRASH G3 get_then_update premise=32, both CRs"
            `Quick test_quad_crash_g3;
          Alcotest.test_case "CRASH G4 no_interfering premise=2328, both CRs"
            `Quick test_quad_crash_g4;
        ] );
      ( "resp_occupancy_pins",
        [
          Alcotest.test_case "FAIR requested-kind state occupancies" `Quick
            test_resp_occupancy_fair;
          Alcotest.test_case "CRASH requested-kind state occupancies" `Quick
            test_resp_occupancy_crash;
          Alcotest.test_case "L0v requested-kind state occupancies" `Quick
            test_resp_occupancy_l0v;
        ] );
      ( "list_response_column",
        [
          Alcotest.test_case
            "FAIR List_response column quad, fresh-measured at stage B"
            `Quick test_list_column_fair;
          Alcotest.test_case
            "CRASH List_response column quad, fresh-measured at stage B"
            `Quick test_list_column_crash;
          Alcotest.test_case
            "L0v List_response column quad, fresh-measured at stage B" `Quick
            test_list_column_l0v;
          Alcotest.test_case
            "FAIR List + residual-Other distinct_msgs = 3760 (pre-stated)"
            `Quick test_list_sum_fair;
          Alcotest.test_case
            "CRASH List + residual-Other distinct_msgs = 3264 (pre-stated)"
            `Quick test_list_sum_crash;
          Alcotest.test_case
            "L0v List + residual-Other distinct_msgs = 12 (pre-stated)" `Quick
            test_list_sum_l0v;
        ] );
    ]

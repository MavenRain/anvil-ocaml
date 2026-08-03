(* BUILD-SPEC-P25 sections 1.2 / 1.3 / 3.2 - the :256 / vct assertion exe.
   Two witness-pin cases mirroring t_p24_state_predicates.ml's
   scope_exclusion_pin shape, plus the C1 equality case and a
   registered-equals-run parity case:

   - scope_exclusion_pin_256: the :256 [local_state_is_coherent_with_etcd]
     EXCLUDED-WITH-A-PIN measurement (SCOPE ground, the third member of the
     :116-124 group). Over the four committed P24 graphs SP0/SPc/SPd/SPm,
     every pinned set-equality and coherence failure is class (d) - no write
     of any kind in flight - the over-exclusion complement shows a
     rely-guard would wrongly exclude passing states, and the effective
     premise of a rely-scoped restoration is pinned. Literals live in
     p25_witness.ml (section 1.2's stated placement); this exe recomputes
     every number fresh from rebuilt graphs and asserts the two agree.

   - vct_occupancy_witness_pin: the L0v occupancy pins (section 1.3). L0v is
     P18's committed 116-state vct:true graph, rebuilt via the proven
     scaffolding (t_p18_regression.ml:259-271). The Get_pvc-family occupancy
     and :246's premise non-vacuity are asserted against the two
     p25_witness.ml literals; the step histogram is structurally checked
     (labels typed independently, columns summing to the decoded
     population - t_p24_state_predicates.ml:417-441's discipline); :241's
     zero is asserted against P24's OWN pin name, never re-pinned.

   - c1_246_equality: the C1 gate's durable half. The temporary probe
     (t_p25_probe_vct_eq, run once and reverted, log in the P25 harness)
     evaluated :246's equality [pvc_index = pvc_cnt] at all 8
     premise-firing L0v states and it HELD on every one (Outcome A). This
     case re-evaluates it fresh on every run: 0 violating states, with the
     premise population held against the witness pin first so the zero can
     never go vacuous silently.

   Witness/assertion separation per the P24 convention: the pinned literals
   are single-sourced in the unlisted p25_witness.ml; this exe recomputes
   each from its own rebuilt graph and asserts equality, so "fix the red by
   editing the witness" still reddens here.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   exceptions, no two-arm match on Option/Result, no wildcard match on a
   finite sum, no raw indexing, no two same-named let bindings (a shadowed
   registration dies silently). *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Rc = Anvil_assurance.Rely_conditions
module Vsr = V_stateful_set_reconciler
module W = P24_witness

(* ==== 1. the four P24 graphs, rebuilt at the committed coordinates ======== *)

(* The scenario coordinates every committed P24 pin was measured against -
   read through P24's witness, never re-typed. *)
let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = W.witness_desired
let ordinals : int list = W.p24_ordinals
let depth : int = W.witness_depth
let bound : Bound.t = W.p24_bound ~desireds:[ desired ]
let cr : V_stateful_set.t = Scenario.vsts ~desired ()
let cr_key : Common.object_ref = W.cr_key_of cr

(* The CR's controller owner reference (B5's control shows it is Some). *)
let owner_ref : Owner_reference.t option =
  V_stateful_set.controller_owner_ref cr

(* Namespace read off cr_key, so premise and etcd side cannot disagree. *)
let cr_namespace : string = cr_key.Common.namespace

(* The four leg replicas, built exactly as t_p24_state_predicates.ml builds
   them (same seed / bound / budget / depth). *)
let seed_of ~(req_drop : bool) ~(pod_monkey : bool) : Cluster.cluster_state =
  Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true ~req_drop
    ~pod_monkey ()

(* One rebuilt faulted product graph. *)
let reach_of ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget) :
    Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed_of ~req_drop ~pod_monkey) ]

let sp0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false W.zero_budget)

let spc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false W.spc_budget)

let spd_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:true ~pod_monkey:false W.spd_budget)

let spm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:true W.spm_budget)

(* Count cluster states of a faulted replica satisfying [p]. *)
let count (reach : Fc.faulted Mc.reachable) (p : Cluster.cluster_state -> bool)
    : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) -> p f.Fc.cs)

(* ==== 2. reused P24 predicates (never re-derived) ========================= *)

(* The set-equality failure detector, at this leg's coordinates. *)
let set_eq_fails : Cluster.cluster_state -> bool =
  W.set_equality_fails ~controller_id ~cr_key ~namespace:cr_namespace
    ~owner_ref

(* The coherence failure detector. *)
let coh_fails : Cluster.cluster_state -> bool =
  W.coherence_fails ~controller_id ~cr_key ~owner_ref

(* The ok-list-response premise population. *)
let ok_resp_in_flight : Cluster.cluster_state -> bool =
  W.ok_resp_in_flight ~controller_id ~cr_key

(* ==== 3. the 4-way write-in-flight classification (BUILD-SPEC-P25 section
   1.2; ported from the selection probe t_p25_probe_coherence.SOURCE.ml,
   whose run minted the expected numbers) ================================== *)

(* R3 is R1 && R2 by construction (rely_conditions.mli), and its
   [interesting] fires on ANY monkey-sourced Api_request - all four monkey
   arms are writes, so "some monkey Api_request" and "some monkey write"
   coincide on every graph this port can build. *)
let r3_name : string = "vsts_rely_conditions_pod_monkey"

(* Class (a)'s detector: some in-flight monkey write violates R1/R2. *)
let rely_violating (s : Cluster.cluster_state) : bool =
  not (W.member_holds Rc.rely_family r3_name s)

(* A monkey write is present at all (R3's own premise mirror). *)
let monkey_write_present (s : Cluster.cluster_state) : bool =
  W.member_interesting Rc.rely_family r3_name s

(* Distinct in-flight messages of a state. *)
let msgs (s : Cluster.cluster_state) : Message.t list =
  Message.Pool.distinct (Cluster.in_flight s)

(* Project the Api_request payload out of a message, if any. *)
let api_request_of (m : Message.t) : Api_method.api_request option =
  match m.Message.content with
  | Message.Api_request req -> Some req
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    None

(* Write-request classifier over all nine request constructors. *)
let is_write_request (req : Api_method.api_request) : bool =
  match req with
  | Api_method.List_request _ | Api_method.Get_request _ -> false
  | Api_method.Create_request _ | Api_method.Update_request _
  | Api_method.Delete_request _ | Api_method.Update_status_request _
  | Api_method.Get_then_delete_request _ | Api_method.Get_then_update_request _
  | Api_method.Get_then_update_status_request _ ->
    true

(* Controller-sourced host classifier over all five host constructors. *)
let is_controller_src (h : Message.host_id) : bool =
  match h with
  | Message.Controller _ -> true
  | Message.Api_server | Message.Builtin_controller | Message.External _
  | Message.Pod_monkey ->
    false

(* Class (c)'s detector: ANY controller-sourced write anywhere in the
   in-flight pool (a crash-orphaned request is still in the pool). *)
let controller_write_present (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (m : Message.t) ->
      is_controller_src m.Message.src
      && Option.fold (api_request_of m) ~none:false ~some:is_write_request)
    (msgs s)

(* The four classes, priority order a > b > c > d: exhaustive and mutually
   exclusive by construction (each guard negates every predecessor), so
   a+b+c+d sums to the classified population and the sum is ASSERTED as a
   partition control rather than trusted. *)
let class_a (s : Cluster.cluster_state) : bool = rely_violating s

let class_b (s : Cluster.cluster_state) : bool =
  (not (class_a s)) && monkey_write_present s

let class_c (s : Cluster.cluster_state) : bool =
  (not (class_a s)) && (not (class_b s)) && controller_write_present s

let class_d (s : Cluster.cluster_state) : bool =
  (not (class_a s)) && (not (class_b s)) && not (class_c s)

(* The four rows, in matrix order, with the committed P24 graph sizes as
   identity controls (derived, never re-typed). *)
let rows : (string * Fc.faulted Mc.reachable Lazy.t * int) list =
  [
    ("SP0", sp0_reach, W.sp0_states);
    ("SPc", spc_reach, W.spc_states);
    ("SPd", spd_reach, W.spd_states);
    ("SPm", spm_reach, W.spm_states);
  ]

(* ==== 4. L0v, rebuilt at P18's committed coordinates (section 1.3) ======== *)

(* P18's own coordinates for the vct:true graph - read through the chain. *)
let l0v_desired : int = P18_witness.witness_desired
let l0v_depth : int = P18_witness.witness_depth
let l0v_bound : Bound.t = P18_witness.p18_bound ~desireds:[ l0v_desired ]

(* L0v: zero budget, crash:true req_drop:false pod_monkey:false vct:TRUE -
   t_p18_regression.ml's [reach_of ~vct:true], byte-for-byte. *)
let l0v_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy
    (Mc.explore ~depth:l0v_depth
       ~successors:
         (Fc.faulted_successors l0v_bound P18_witness.zero_budget cluster)
       ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
       ~init:
         [
           Fc.faulted_of_seed
             (Scenario.vsts_seed_faults ~desired:l0v_desired ~crash:true
                ~req_drop:false ~pod_monkey:false ~vct:true ());
         ])

(* The vct:true CR (the same scenario CR the L0v seed marshals). *)
let cr_v : V_stateful_set.t = Scenario.vsts ~desired:l0v_desired ~vct:true ()

(* Decode key for L0v's ongoing reconcile. *)
let cr_key_v : Common.object_ref = W.cr_key_of cr_v

(* :246's comparand, derived INLINE from the CR spec, never a ported field
   (state_predicates.rs:259-261's make_pvcs derivation). *)
let pvc_cnt : int =
  List.length
    (Option.value ~default:[]
       (V_stateful_set.spec cr_v).Stateful_set.volume_claim_templates)

(* Decoded-ongoing detector at L0v's key. *)
let decoded_v : Cluster.cluster_state -> bool =
  W.decoded ~controller_id ~cr_key:cr_key_v

(* The reconcile-step occupancy histogram over L0v (P24's structurally
   checked probe function, at L0v's key). *)
let histogram_v (reach : Fc.faulted Mc.reachable) : (string * int) list =
  W.step_occupancy ~count:(count reach) ~controller_id ~cr_key:cr_key_v

(* The seventeen step labels, typed INDEPENDENTLY of the histogram (the
   t_p24_state_predicates.ml:417-441 discipline: a step dropped from the
   enumeration reddens here whatever its occupancy). *)
let expected_step_labels : string list =
  [
    "Init";
    "After_list_pod";
    "Get_pvc";
    "After_get_pvc";
    "Create_pvc";
    "After_create_pvc";
    "Skip_pvc";
    "Create_needed";
    "After_create_needed";
    "Update_needed";
    "After_update_needed";
    "Delete_condemned";
    "After_delete_condemned";
    "Delete_outdated";
    "After_delete_outdated";
    "Done";
    "Error";
  ]

(* The five Get_pvc-family columns, in histogram order. *)
let family_labels : string list =
  [ "Get_pvc"; "After_get_pvc"; "Create_pvc"; "After_create_pvc"; "Skip_pvc" ]

(* Sum named columns out of a histogram; a missing column poisons to None. *)
let columns_total (hist : (string * int) list) (labels : string list) :
    int option =
  List.fold_left
    (fun (acc : int option) (label : string) ->
      Option.bind acc (fun (a : int) ->
          Option.map (fun (n : int) -> a + n) (W.hist_lookup hist label)))
    (Some 0) labels

(* :246's premise, exactly as the selection probe measured it: the decoded
   reconcile sits at Create_needed or Update_needed with pvc_index > 0. *)
let at_246_premise (st : Vsr.s) : bool =
  (Vsr.step_equal st.Vsr.reconcile_step Vsr.Create_needed
  || Vsr.step_equal st.Vsr.reconcile_step Vsr.Update_needed)
  && st.Vsr.pvc_index > 0

(* Premise-firing states of L0v. *)
let premise_246 (s : Cluster.cluster_state) : bool =
  W.at_orc ~controller_id ~cr_key:cr_key_v
    (fun _ (st : Vsr.s) _ -> at_246_premise st)
    s

(* Premise states violating :246's equality [pvc_index = pvc_cnt]. *)
let violating_246 (s : Cluster.cluster_state) : bool =
  W.at_orc ~controller_id ~cr_key:cr_key_v
    (fun _ (st : Vsr.s) _ -> at_246_premise st && st.Vsr.pvc_index <> pvc_cnt)
    s

(* PVC-carrying decoded states (the P23 SHAPE pin's premise, which measures
   0 on every vct:false graph and must be NON-zero here). *)
let pvcs_non_empty_v (s : Cluster.cluster_state) : bool =
  W.at_orc ~controller_id ~cr_key:cr_key_v
    (fun _ (st : Vsr.s) _ -> not (st.Vsr.pvcs = []))
    s

(* ==== 5. row helpers (accumulate-then-assert, per t_p24) ================== *)

(* A boolean row: named failure when false. *)
let row_bool (label : string) ~(actual : bool) : string list =
  if actual then [] else [ label ^ " -- expected true, got false" ]

(* An integer row: named failure with both sides on mismatch. *)
let row_int (label : string) ~(expected : int) ~(actual : int) : string list =
  if Int.equal expected actual then []
  else [ Printf.sprintf "%s -- expected %d, got %d" label expected actual ]

(* Render an optional integer. *)
let show_opt_int (o : int option) : string =
  Option.fold o ~none:"<none>" ~some:string_of_int

(* An optional-integer row (a None side names a dropped column/row). *)
let row_opt_int (label : string) ~(expected : int option)
    ~(actual : int option) : string list =
  if Option.equal Int.equal expected actual then []
  else
    [
      Printf.sprintf "%s -- expected %s, got %s" label (show_opt_int expected)
        (show_opt_int actual);
    ]

(* A string-list row (label-shape assertions). *)
let row_list_string (label : string) ~(expected : string list)
    ~(actual : string list) : string list =
  if List.equal String.equal expected actual then []
  else
    [
      Printf.sprintf "%s -- expected [%s], got [%s]" label
        (String.concat "; " expected)
        (String.concat "; " actual);
    ]

(* One report per case: empty, or every failing row at once. *)
let report (label : string) (failures : string list) : unit =
  Alcotest.(check (list string))
    (label
   ^ ": EVERY row of this case is observed on EVERY run - this list is \
      empty, or it names every failing row at once")
    [] failures

(* ==== 6. the scope_exclusion_pin_256 case (section 1.2) =================== *)

(* The four graph labels the witness quads are keyed by, typed once here and
   asserted against every witness list's own key column. *)
let sp_graph_labels : string list = [ "SP0"; "SPc"; "SPd"; "SPm" ]

(* P24's committed set-equality fail-population pins, keyed by graph label
   (derived from the P24 witness, never re-typed). *)
let p24_set_eq_pins : (string * int) list =
  [
    ("SP0", W.set_equality_failures_sp0);
    ("SPc", W.set_equality_failures_spc);
    ("SPd", W.set_equality_failures_spd);
    ("SPm", W.set_equality_failures_spm);
  ]

(* P24's committed coherence fail-population pins, keyed by graph label. *)
let p24_coherence_pins : (string * int) list =
  [
    ("SP0", W.coherence_failures_sp0);
    ("SPc", W.coherence_failures_spc);
    ("SPd", W.coherence_failures_spd);
    ("SPm", W.coherence_failures_spm);
  ]

(* Classification rows for one graph against one failure population. *)
let classification_rows (glabel : string) (reach : Fc.faulted Mc.reachable)
    (pop_name : string) (pop : Cluster.cluster_state -> bool)
    (pinned_d : (string * int) list) : string list =
  let in_pop (c : Cluster.cluster_state -> bool) : int =
    count reach (fun (s : Cluster.cluster_state) -> pop s && c s)
  in
  let a = in_pop class_a in
  let b = in_pop class_b in
  let c = in_pop class_c in
  let d = in_pop class_d in
  let total = count reach pop in
  List.concat
    [
      row_int
        (Printf.sprintf "%s %s class (a) rely-violating write in flight = 0"
           glabel pop_name)
        ~expected:0 ~actual:a;
      row_int
        (Printf.sprintf "%s %s class (b) compliant monkey write = 0" glabel
           pop_name)
        ~expected:0 ~actual:b;
      row_int
        (Printf.sprintf "%s %s class (c) controller write, no monkey = 0"
           glabel pop_name)
        ~expected:0 ~actual:c;
      row_opt_int
        (Printf.sprintf
           "%s %s class (d) NO write of any kind in flight = the witness pin"
           glabel pop_name)
        ~expected:(List.assoc_opt glabel pinned_d)
        ~actual:(Some d);
      row_int
        (Printf.sprintf
           "%s %s partition control: a+b+c+d = the whole fail population"
           glabel pop_name)
        ~expected:total ~actual:(a + b + c + d);
    ]

(* The :256 scope-exclusion pin, whole-matrix. *)
let test_scope_exclusion_pin_256 () =
  report "scope_exclusion_pin_256"
    (List.concat
       [
         row_bool
           "control: the CR HAS a controller owner reference (a None would \
            make every population below vacuous)"
           ~actual:(Option.is_some owner_ref);
         row_list_string
           "the witness quads are keyed by exactly SP0/SPc/SPd/SPm, in order \
            (a dropped witness row reddens here)"
           ~expected:
             (List.concat
                [
                  sp_graph_labels;
                  List.map fst P25_witness.set_eq_class_d;
                  List.map fst P25_witness.coherence_class_d;
                  List.map fst P25_witness.over_exclusion_complement;
                  List.map fst P25_witness.rely_effective_premise;
                ])
           ~actual:
             (List.concat
                [
                  List.map
                    (fun ((l, _, _) :
                           string * Fc.faulted Mc.reachable Lazy.t * int) -> l)
                    rows;
                  sp_graph_labels;
                  sp_graph_labels;
                  sp_graph_labels;
                  sp_graph_labels;
                ]);
         List.concat_map
           (fun ((glabel, reach, committed_states) :
                  string * Fc.faulted Mc.reachable Lazy.t * int) ->
             let r = Lazy.force reach in
             List.concat
               [
                 (* graph identity, derived from P24's committed pins *)
                 row_int
                   (glabel
                  ^ ": rebuilt graph size = P24's committed size (identity \
                     control, derived not re-typed)")
                   ~expected:committed_states ~actual:(Mc.states_seen r);
                 (* positive controls: P24's pinned fail populations
                    reproduced EXACTLY before classification *)
                 row_opt_int
                   (glabel
                  ^ ": set-equality fail population = P24's committed pin \
                     (positive control)")
                   ~expected:(List.assoc_opt glabel p24_set_eq_pins)
                   ~actual:(Some (count r set_eq_fails));
                 row_opt_int
                   (glabel
                  ^ ": coherence fail population = P24's committed pin \
                     (positive control)")
                   ~expected:(List.assoc_opt glabel p24_coherence_pins)
                   ~actual:(Some (count r coh_fails));
                 classification_rows glabel r "set-eq" set_eq_fails
                   P25_witness.set_eq_class_d;
                 classification_rows glabel r "coherence" coh_fails
                   P25_witness.coherence_class_d;
                 (* the over-exclusion complement: PASSING states carrying a
                    rely-violating write anyway *)
                 row_opt_int
                   (glabel
                  ^ ": over-exclusion complement (passing states with a \
                     rely-violating write in flight) = the witness pin")
                   ~expected:
                     (List.assoc_opt glabel
                        P25_witness.over_exclusion_complement)
                   ~actual:
                     (Some
                        (count r (fun (s : Cluster.cluster_state) ->
                             ok_resp_in_flight s
                             && (not (set_eq_fails s))
                             && (not (coh_fails s))
                             && rely_violating s)));
                 (* the effective premise of a rely-scoped restoration *)
                 row_opt_int
                   (glabel
                  ^ ": effective premise of a rely-scoped restoration \
                     (ok-list-response AND no rely-violating write) = the \
                     witness pin")
                   ~expected:
                     (List.assoc_opt glabel P25_witness.rely_effective_premise)
                   ~actual:
                     (Some
                        (count r (fun (s : Cluster.cluster_state) ->
                             ok_resp_in_flight s && not (rely_violating s))));
               ])
           rows;
       ])

(* ==== 7. the vct_occupancy_witness_pin case (section 1.3) ================= *)

(* The L0v occupancy pins, structurally guarded. *)
let test_vct_occupancy_witness_pin () =
  let r = Lazy.force l0v_reach in
  let hist = histogram_v r in
  report "vct_occupancy_witness_pin"
    (List.concat
       [
         row_int
           "L0v rebuilt graph size = P18's committed l0v_states (identity \
            control, derived not re-typed)"
           ~expected:P18_witness.l0v_states ~actual:(Mc.states_seen r);
         row_bool "L0v has decoded ongoing states at all (decoded > 0)"
           ~actual:(count r decoded_v > 0);
         row_list_string
           "the histogram's columns ARE the seventeen reconcile steps, in \
            order, against a list typed independently (a dropped column \
            reddens whatever its occupancy)"
           ~expected:expected_step_labels ~actual:(List.map fst hist);
         row_int
           "coverage guard: the seventeen columns SUM to the decoded \
            population (a dropped step would make this short)"
           ~expected:(count r decoded_v)
           ~actual:
             (List.fold_left
                (fun (acc : int) ((_, n) : string * int) -> acc + n)
                0 hist);
         row_bool
           "vct:true control: some decoded state carries a non-empty [pvcs] \
            - the P23 SHAPE pin's premise, zero on every vct:false graph, is \
            LIVE here (retiring the SHAPE-vacuity reading)"
           ~actual:(count r pvcs_non_empty_v > 0);
         row_opt_int
           "THE PIN: Get_pvc-family occupancy \
            (Get_pvc/After_get_pvc/Create_pvc/After_create_pvc/Skip_pvc) = \
            P25_witness.l0v_get_pvc_family_occupancy"
           ~expected:(Some P25_witness.l0v_get_pvc_family_occupancy)
           ~actual:(columns_total hist family_labels);
         row_int
           "THE PIN: :246 premise non-vacuity (pvc_index>0 at \
            Create_needed|Update_needed) = \
            P25_witness.l0v_246_premise_nonvacuity"
           ~expected:P25_witness.l0v_246_premise_nonvacuity
           ~actual:(count r premise_246);
         row_opt_int
           ":241 stays ORTHOGONAL even at vct:true: the \
            After_delete_outdated column is P24's own committed zero \
            (P24_witness.after_delete_outdated_occupancy_everywhere, never \
            re-pinned under a P25 name)"
           ~expected:(Some W.after_delete_outdated_occupancy_everywhere)
           ~actual:(W.hist_lookup hist "After_delete_outdated");
       ])

(* ==== 8. the C1 equality case (section 1.3's gate, Outcome A) ============= *)

(* :246's equality re-evaluated fresh on every run. *)
let test_c1_246_equality () =
  let r = Lazy.force l0v_reach in
  report "c1_246_equality"
    (List.concat
       [
         row_int
           "control: the premise population = the witness pin (the zero \
            below cannot go vacuous silently)"
           ~expected:P25_witness.l0v_246_premise_nonvacuity
           ~actual:(count r premise_246);
         row_bool
           "control: pvc_cnt derived from the vct:true CR spec is positive \
            (the equality compares against a real template count)"
           ~actual:(pvc_cnt > 0);
         row_int
           "C1 (Outcome A, measured by this run): [pvc_index = pvc_cnt] \
            HOLDS at every premise-firing L0v state - 0 violations"
           ~expected:0
           ~actual:(count r violating_246);
       ])

(* ==== 9. registration ===================================================== *)

(* The three substantive groups; the parity case is appended at [run] and
   counts itself, so the total registered surface is asserted below. *)
let substantive_cases : unit Alcotest.test list =
  [
    ( "scope_exclusion_pin_256",
      [
        Alcotest.test_case
          ":256 excluded-with-a-pin on the SCOPE ground: every pinned \
           failure is class (d), complement and effective premise pinned"
          `Quick test_scope_exclusion_pin_256;
      ] );
    ( "vct_occupancy_witness_pin",
      [
        Alcotest.test_case
          "L0v occupancy pins: Get_pvc-family occupancy and :246 premise \
           non-vacuity, structurally guarded"
          `Quick test_vct_occupancy_witness_pin;
      ] );
    ( "c1_246_equality",
      [
        Alcotest.test_case
          "C1: :246's equality holds at every premise-firing L0v state \
           (Outcome A)"
          `Quick test_c1_246_equality;
      ] );
  ]

(* Registered-equals-run parity (the shadowed-binding guard's counting
   half): the three substantive cases plus this parity case itself is FOUR.
   t_p25_reconcile's LEG3 re-measures this file's registration-token count
   against its p25_witness.ml pin; this local literal is the exe's own
   guard, not that pin. *)
let registered_case_count : int = 4

let test_registered_equals_run () =
  Alcotest.(check int)
    "registered = run: 3 substantive cases + this parity case = 4"
    registered_case_count
    (1 + List.length (List.concat_map snd substantive_cases))

(* ==== 10. the stage-B measurement dump ===================================
   Numbers BUILD-SPEC-P25 section 1.3 keeps SPEC-RECORDED (decoded
   population, per-step occupancy, the excluded-conjunct premise
   occupancies) are PRINTED here and consumed as disclosed prose; none of
   them may be quoted as a pin. Everything pinned is asserted in the cases
   above. *)
let () =
  Printf.printf "\n[t_p25_state_predicates] ==== STAGE-B MEASUREMENT DUMP ====\n";
  List.iter
    (fun ((glabel, reach, _) : string * Fc.faulted Mc.reachable Lazy.t * int) ->
      let r = Lazy.force reach in
      let in_pop (pop : Cluster.cluster_state -> bool)
          (c : Cluster.cluster_state -> bool) : int =
        count r (fun (s : Cluster.cluster_state) -> pop s && c s)
      in
      Printf.printf
        "  %s set_eq_fails a=%d b=%d c=%d d=%d total=%d | coh_fails a=%d \
         b=%d c=%d d=%d total=%d | complement=%d effective=%d premise=%d\n"
        glabel (in_pop set_eq_fails class_a) (in_pop set_eq_fails class_b)
        (in_pop set_eq_fails class_c) (in_pop set_eq_fails class_d)
        (count r set_eq_fails) (in_pop coh_fails class_a)
        (in_pop coh_fails class_b) (in_pop coh_fails class_c)
        (in_pop coh_fails class_d) (count r coh_fails)
        (count r (fun (s : Cluster.cluster_state) ->
             ok_resp_in_flight s
             && (not (set_eq_fails s))
             && (not (coh_fails s))
             && rely_violating s))
        (count r (fun (s : Cluster.cluster_state) ->
             ok_resp_in_flight s && not (rely_violating s)))
        (count r ok_resp_in_flight))
    rows;
  let r = Lazy.force l0v_reach in
  let hist = histogram_v r in
  Printf.printf "  L0v states_seen=%d decoded=%d pvc_cnt=%d\n"
    (Mc.states_seen r) (count r decoded_v) pvc_cnt;
  List.iter
    (fun ((label, n) : string * int) ->
      Printf.printf "    %-24s %d\n" label n)
    hist;
  Printf.printf
    "  L0v premise occupancy: :199=%s :233=%s :244=%s blanket(14-step)=%d \
     :246=%d :241=%s | Get_pvc-family total=%s | :246 equality violations=%d\n"
    (show_opt_int (W.hist_lookup hist "Get_pvc"))
    (show_opt_int (W.hist_lookup hist "After_create_pvc"))
    (show_opt_int
       (columns_total hist
          [ "Get_pvc"; "After_get_pvc"; "Create_pvc"; "Skip_pvc" ]))
    (W.valid_step_total hist)
    (count r premise_246)
    (show_opt_int (W.hist_lookup hist "After_delete_outdated"))
    (show_opt_int (columns_total hist family_labels))
    (count r violating_246);
  Printf.printf "[t_p25_state_predicates] ==== END STAGE-B DUMP ====\n\n";
  flush stdout

let () =
  Alcotest.run "p25_state_predicates"
    (substantive_cases
    @ [
        ( "case_parity",
          [
            Alcotest.test_case "registered case count = run case count (4)"
              `Quick test_registered_equals_run;
          ] );
      ])

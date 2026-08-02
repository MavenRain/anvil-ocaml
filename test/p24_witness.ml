(* BUILD-SPEC-P24 section 4 / RULING.md section 4 - the SINGLE SOURCE OF TRUTH
   for the P24 state-predicate witness: the bound, the leg-matrix shape
   constants, the four leg budgets (SP0 / SPc / SPd / SPm), the family's shape
   constants and - once STAGE B has run - every pinned MEASURED number of the
   {!Anvil_checker.Fault_check.check_state_predicates_under_faults} leg. A
   shared non-test module (deliberately NOT in [test/dune]'s [(names ...)]
   list, so dune compiles it once and links it into every test exe that
   references it), following the [p23_witness.ml] / [p22_witness.ml] /
   [p21_witness.ml] precedent.

   NO PINNED NUMBER MAY APPEAR IN TWO FILES. The P24 tests read every count
   from here and re-type none of them. THE ONE SANCTIONED EXCEPTION is the
   P14-P23 firewall rationale (stated at p21_witness.ml:18-30, restated at
   p23_witness.ml:15-20 and honoured unchanged here): [t_p24_regression.ml]
   re-types the INHERITED P13-P23 graph literals as its prior-phase firewall
   and holds them against this module's chain re-exports below. Those are
   P13-P23's numbers, not P24-MEASURED ones, and the duplication is the POINT -
   "fix the red by editing the witness" has to redden somewhere.

   ==== STATUS OF THIS MODULE, STATED HONESTLY ==============================
   STAGE B HAS RUN, and the MEASURED BLOCK AT THE BOTTOM carries the vacuity
   zeroes it measured (the :241 occupancy zero, the owner-ref filter's reject
   zero and the [rm.src] complement zero that CUT M2) plus the probe-B5
   scope-exclusion refutation, and nothing else. The sequencing RULING section 7
   sets - A (write) -> B (measure) -> C (mutate) - is what keeps that block
   short: a pin typed before its measurement is a guess dressed as evidence, so
   every OTHER stage-B number stays PRINTED prose and no test may assert it.
   What this module ships is

   1. DERIVED CHAIN RE-EXPORTS of already-committed P13-P23 pins (they move
      only if a PRIOR phase moved, which is a phase-STOP, never a retune);
   2. SHAPE constants (the family cardinal - {b 2}, M1 and M3 - the two member
      names, the four leg labels): facts about what was WRITTEN, not about what
      was measured;
   3. THE FOUR STAGE-B PROBES as PROJECTIONS with no numbers attached. Every
      one of them is a total, pure, exception-free predicate over a
      {!Cluster.cluster_state}; the P24 test exes apply them to the leg
      replicas, PRINT what they compute, and pin NOTHING except where a phase
      decision rests on the number. Stage B read those printed numbers; THREE
      of them became vacuity literals in the MEASURED block below (the :241
      exclusion pin; the owner-reference filter's REJECT-PATH zero added when
      B3's complement was de-tautologised; and B4's [rm.src] complement, pinned
      when the main loop CUT M2 on it), the probe-B5 refutation joined them as
      a measured non-vacuity, and the rest are consumed as disclosed prose in
      [State_predicates]'s interface. A test may assert only the literals that
      live here.

   THE FOUR STAGE-B MEASUREMENTS, verbatim from RULING section 7 (each has its
   probe in tier 3 below, and its printer in [t_p24_state_predicates.ml]):

   B1. every P24 gate/state count on BL0/BLc/BLd/BLm (here SP0/SPc/SPd/SPm -
       the same four graphs under this phase's labels);
   B2. a [reconcile_step] OCCUPANCY HISTOGRAM - it SETTLED upstream :241 (the
       [AfterDeleteOutdated] implication) and the step-gated rows 11 and
       13-20/23. The only OTHER [After_delete_outdated = 0] pin in the tree is
       t_p11_vsts_liveness.ml:113-114, on a DIFFERENT, smaller 20-state
       [fair:true] P11 graph, and
       [rg 'After_delete_outdated' test/p23_witness.ml] returns zero hits, so
       nothing was inherited from it. VERDICT: 0 on all four graphs, so :241
       moved to EXCLUDE-WITH-A-PIN and the pin is the one literal this file
       carries; every other step-gated row's guard measured OCCUPIED and those
       rows stay PORTED;
   B3. [owned_objs] NON-EMPTINESS over the ok-list-response population
       (8/60/48/816, the [P23_witness.ok_list_resps_] pins) - it settled the
       fork of
       RULING section 3.3, i.e. whether M3's two etcd-consuming conjuncts
       :116-118 and :119-124 ship at all and whether [weakly_eq] is written
       in P24. VERDICT: NON-EMPTY at 8 / 60 / 40 / 776, so both conjuncts ship
       and [weakly_eq] is written;
   B4. the [rm.src = Controller (controller_id, cr_key)] POSITIVE CONTROL over
       every parked state on all four graphs - it REPLACED the refuted
       "structurally 100% red" prediction for upstream :49 (refute verdict C6,
       adopted), whose only support was plausibility-from-construction at
       lib/cluster/message.ml:175-179 on BL0, never a measurement across the
       fault graphs where adversarial actions exist. VERDICT, and it decided a
       member: the complement is {b 0 on all four} over denominators
       16 / 112 / 288 / 1560, so upstream :49 is TRUE wherever it is evaluated
       and the M2 candidate it was the whole claimed coverage of is CUT. The
       probe stays LIVE because it is now that finding's evidence.

   GRAPH IDENTITY, and why no committed pin can move. The P24 leg RIDES P23's
   four graphs rather than adding any: same seed
   ({!Anvil_assurance.Scenario.vsts_seed_with_pods} at the same [~desired] /
   [~ordinals]), same bound, same budgets, same depth. [Fault_check.run_leg]
   passes [Model_check.explore] only [~depth ~successors ~equal ~hash ~init]
   and [explore] takes NO invariant argument (model_check.mli:57-63), so GRAPHS
   ARE FAMILY-BLIND: swapping the asserted family cannot move a state count.
   The shared [faulted] block (fault_check.ml:37-145) is NOT edited by this
   phase - editing it would retroactively perturb all FOURTEEN legs' graphs at
   once, which is the one mechanism that could break this argument. A moved pin
   is a phase-STOP, never a retune.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   exceptions, no partial accessor, no two-arm match on [option]/[result], no
   indexing, and every match on a finite sum is EXHAUSTIVE with no wildcard
   arm (the seventeen reconcile steps, the nine [Api_method] response
   constructors and the four [Message.message_content] constructors are all
   spelled out below). *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Invariants = Anvil_assurance.Invariants
module Vsr = V_stateful_set_reconciler
module Pack = V_stateful_set_pack

(* ==== TIER 1: DERIVED chain re-exports ====================================
   Every binding in this tier is an ALIAS. None is a new literal, so a P23 (or
   earlier) retune propagates here instead of silently diverging, and
   t_p24_regression's firewall holds each one against the committed literal it
   is supposed to equal. *)

(* The P24 bound: DERIVED from {!P23_witness.p23_bound} with NO widening. The
   leg adds no seed, no ordinal and no ceiling, which is what keeps it on P23's
   exact four graphs. *)
let p24_bound ~(desireds : int list) : Bound.t =
  P23_witness.p23_bound ~desireds

let witness_desired : int = P23_witness.witness_desired
let witness_depth : int = P23_witness.witness_depth
let p24_ordinals : int list = P23_witness.p23_ordinals

(* The four matrix budgets, DERIVED from P23 (never re-typed):
     SP0  zero    {0;0;0}  fault-free control ([~require_fault:false])
     SPc  crash   {1;0;0}  crash dimension
     SPd  drop    {0;1;0}  drop dimension  ([~req_drop:true])
     SPm  monkey  {0;0;1}  monkey dimension ([~pod_monkey:true])
   Leg ORDER is the MG5 lesson (zero-budget FIRST, then faults): SP0's
   non-vacuity floor is diagnosed before any fault leg is run. *)
let zero_budget : Fc.budget = P23_witness.zero_budget
let spc_budget : Fc.budget = P23_witness.blc_budget
let spd_budget : Fc.budget = P23_witness.bld_budget
let spm_budget : Fc.budget = P23_witness.blm_budget

(* ---- the committed graph pins, DERIVED --------------------------------- *)

(* The five P13-P21 pins (76 / 464 / 744 / 1976 / 116). *)
let l0_states : int = P23_witness.l0_states
let lc_states : int = P23_witness.lc_states
let ld_states : int = P23_witness.ld_states
let lm_states : int = P23_witness.lm_states
let l0v_states : int = P23_witness.l0v_states

(* P22's four (88 / 808 / 1144 / 10216) and its four gates (20 / 276 / 96 /
   2080). *)
let sl0_states : int = P23_witness.sl0_states
let slc_states : int = P23_witness.slc_states
let sld_states : int = P23_witness.sld_states
let slm_states : int = P23_witness.slm_states
let sl0_gate_states : int = P23_witness.sl0_gate_states
let slc_gate_states : int = P23_witness.slc_gate_states
let sld_gate_states : int = P23_witness.sld_gate_states
let slm_gate_states : int = P23_witness.slm_gate_states

(* P23's four graphs and its four MEASURED gates (68 / 560 / 816 / 7920), which
   are PRIOR-phase for P24 and therefore firewall material here. *)
let bl0_states : int = P23_witness.bl0_states
let blc_states : int = P23_witness.blc_states
let bld_states : int = P23_witness.bld_states
let blm_states : int = P23_witness.blm_states
let bl0_gate_states : int = P23_witness.bl0_gate_states
let blc_gate_states : int = P23_witness.blc_gate_states
let bld_gate_states : int = P23_witness.bld_gate_states
let blm_gate_states : int = P23_witness.blm_gate_states

(* P23's premise-side counters, re-exported so the P24 suite can state the
   POPULATION its own probes run over without re-typing a P23 number: the
   decoded counts 76/680/1056/8872, the parked counts 16/112/288/1560 that
   probe B4 quantifies over, and the ok-list-response counts 8/60/48/816 that
   probe B3 quantifies over. *)
let decoded_bl0 : int = P23_witness.decoded_bl0
let decoded_blc : int = P23_witness.decoded_blc
let decoded_bld : int = P23_witness.decoded_bld
let decoded_blm : int = P23_witness.decoded_blm
let parked_bl0 : int = P23_witness.parked_bl0
let parked_blc : int = P23_witness.parked_blc
let parked_bld : int = P23_witness.parked_bld
let parked_blm : int = P23_witness.parked_blm
let ok_list_resps_bl0 : int = P23_witness.ok_list_resps_bl0
let ok_list_resps_blc : int = P23_witness.ok_list_resps_blc
let ok_list_resps_bld : int = P23_witness.ok_list_resps_bld
let ok_list_resps_blm : int = P23_witness.ok_list_resps_blm
let pvcs_non_empty_everywhere : int = P23_witness.pvcs_non_empty_everywhere
let decode_failures_everywhere : int = P23_witness.decode_failures_everywhere

(* P23's family shape, for the M1-vs-L1 discrimination rows in
   t_p24_mutation (M1's :200-204 is STRICTLY STRONGER than L1's
   [pod_name_matches], and :212 has no L1 counterpart at all). *)
let binding_cardinal : int = P23_witness.binding_cardinal
let l1_name : string = P23_witness.l1_name
let l2_name : string = P23_witness.l2_name

(* ==== PREDICTION P1, recorded as a DERIVATION rather than four new literals =
   BUILD-SPEC-P24 section 4 prediction P1: the four P24 legs reuse P23's
   [(seed, bound, budget, depth)] exactly and graphs are family-blind, so their
   state counts must EQUAL P23's. Expressing that as an alias rather than as
   four numbers is what makes the prediction falsifiable in ONE place: if stage
   B measures anything else, THESE bindings are what redden, and the answer is
   a phase-STOP diagnosis, never a retune. *)
let sp0_states : int = bl0_states
let spc_states : int = blc_states
let spd_states : int = bld_states
let spm_states : int = blm_states

(* ==== TIER 2: family SHAPE ===============================================
   Facts about what was WRITTEN, not about what was measured. The (name,
   source) LITERALS themselves live in
   {!Anvil_assurance.State_predicates.predicate_sources} and are restated by
   t_p24_regression under the firewall rationale (a guard must not read the
   very binding it guards); the SOURCES are not re-typed here. These NAMES are
   what the per-member counting projections address the family BY, so a rename
   makes every projection constantly [false] and the [> 0] floors in
   t_p24_state_predicates redden LOUDLY before any count could quietly go 0.

   THE CARDINAL IS 2, AND IT WAS 3. M2 (upstream :45 closed by :59-66) was
   written, built, measured and mutation-tested and is CUT; the negative result
   that cut it lives in state_predicates.ml{,i}. The probes M2 used to be read
   through - [pending_src_*], [pending_still_in_flight] and [delivery_window] in
   tier 3 below - are deliberately NOT removed with it: they are that finding's
   evidence and stay ASSERTABLE, which is why this module still measures the
   parked request's [src] and its network membership although no shipped member
   reads either. *)

let predicate_cardinal : int = 2
let m1_name : string = "vsts_local_state_is_valid"
let m3_name : string = "vsts_pending_list_pod_resp_in_flight"
let member_names : string list = [ m1_name; m3_name ]

(* The four leg labels, in matrix order, so the three exes cannot disagree
   about which graph a printed row belongs to. *)
let leg_labels : string list = [ "SP0"; "SPc"; "SPd"; "SPm" ]

(* ==== TIER 3: THE FOUR STAGE-B PROBES =====================================
   Projections, not numbers. They are defined HERE, once, rather than
   duplicated into three exes, because B1-B4 must be the SAME predicate
   wherever they are read - a probe that drifted between the behavioural suite
   and the mutation suite would produce two numbers for one measurement and
   neither would be the phase's.

   They are a DELIBERATE DUPLICATION of private helpers of
   {!Anvil_assurance.State_predicates} (the duplicate-and-pin house precedent,
   internal_guarantee.ml:131-136, re-used by t_p23_local_binding.ml:268-424).
   The module exports exactly two vals ([predicate_sources],
   [predicate_family]), so the lookup / decode / list-response projections a
   COUNTER needs are not callable, and re-exporting them to make a test easier
   would widen a shipped surface for a test's convenience. Where the
   duplication is load-bearing it is PINNED by the counts agreeing with the
   members' own [interesting] (t_p24_state_predicates asserts exactly that). *)

(* ---- addressing the family BY NAME -------------------------------------- *)

let member_interesting (fam : Invariants.invariant list) (name : string)
    (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.interesting s)
    fam

let member_holds (fam : Invariants.invariant list) (name : string)
    (s : Cluster.cluster_state) : bool =
  List.exists
    (fun (i : Invariants.invariant) ->
      String.equal i.Invariants.name name && i.Invariants.holds s)
    fam

(* ---- the CR's coordinates, READ off the CR and never typed ---------------
   [cr_key_of], state_predicates.ml:67-72 (itself local_binding.ml:73-78,
   itself internal_guarantee.ml:93-98), with the same disclosed
   [Option.value ~default:""] reading: the port EXPORTS
   [V_stateful_set.object_ref] but it is [Res.t]-typed hence partial, and a
   total classifier must not consume it. *)

let namespace_of (cr : V_stateful_set.t) : string =
  Option.value ~default:"" (Object_meta.namespace (V_stateful_set.metadata cr))

let name_of (cr : V_stateful_set.t) : string =
  Option.value ~default:"" (Object_meta.name (V_stateful_set.metadata cr))

let cr_key_of (cr : V_stateful_set.t) : Common.object_ref =
  {
    Common.kind = V_stateful_set.kind;
    name = name_of cr;
    namespace = namespace_of cr;
  }

(* ---- the lookup / decode skeleton, in COUNTER polarity -------------------
   The skeleton of [State_predicates.at_reconcile] (:142-156) with BOTH
   out-of-premise directions folded to [false], because every consumer here is
   a COUNTER (a count of states where something is TRUE), not a [holds].
   [Cluster.ongoing_reconciles] is TOTAL - a missing controller id yields the
   empty map (cluster.mli:78-82) - so a wrong [~controller_id] sends every
   state out of premise rather than raising. *)

let orc_of ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : Controller.ongoing_reconcile option =
  Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id)

let has_reconcile ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : bool =
  Option.is_some (orc_of ~controller_id ~cr_key s)

let at_orc ~(controller_id : int) ~(cr_key : Common.object_ref)
    (f :
      Controller.ongoing_reconcile -> Vsr.s -> Cluster.cluster_state -> bool)
    (s : Cluster.cluster_state) : bool =
  Option.fold
    (orc_of ~controller_id ~cr_key s)
    ~none:false
    ~some:(fun (o : Controller.ongoing_reconcile) ->
      Option.fold
        (Result.to_option (Pack.unmarshal_state o.Controller.local_state))
        ~none:false
        ~some:(fun (st : Vsr.s) -> f o st s))

let decoded ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : bool =
  at_orc ~controller_id ~cr_key (fun _ _ _ -> true) s

let decode_failed ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : bool =
  Option.fold
    (orc_of ~controller_id ~cr_key s)
    ~none:false
    ~some:(fun (o : Controller.ongoing_reconcile) ->
      Result.is_error (Pack.unmarshal_state o.Controller.local_state))

(* ==== PROBE B2: the [reconcile_step] OCCUPANCY HISTOGRAM ==================
   The measurement RULING section 1 makes an OPEN OBLIGATION of the phase.
   [needed_witness] / [condemned_witness] (P23's counters) measure "some slot
   is populated", which is a DIFFERENT predicate from "[reconcile_step] = X"
   (refute verdict C3, confirmed against local_binding.ml:142-144), so no
   committed counter answers this and none may be pressed into service.

   [all_steps] is an EXHAUSTIVE enumeration of
   [V_stateful_set_reconciler.step] (v_stateful_set_reconciler.mli:14-31) and
   [step_label] is an EXHAUSTIVE 17-arm match with NO wildcard arm - the
   [step_binding] precedent (local_binding.ml:227-240). Never a [List.mem] over
   a literal step list: that silently omits a newly-added step instead of
   forcing a revisit.

   THE COVERAGE GUARD, and it needs no pinned number: the histogram's column
   sum must EQUAL the count of decoded states, because the seventeen steps
   partition the decoded population. A step dropped from [all_steps] makes the
   sum SHORT and reddens, which is the assertion t_p24_state_predicates runs
   before it prints a single row. *)

let all_steps : Vsr.step list =
  [
    Vsr.Init;
    Vsr.After_list_pod;
    Vsr.Get_pvc;
    Vsr.After_get_pvc;
    Vsr.Create_pvc;
    Vsr.After_create_pvc;
    Vsr.Skip_pvc;
    Vsr.Create_needed;
    Vsr.After_create_needed;
    Vsr.Update_needed;
    Vsr.After_update_needed;
    Vsr.Delete_condemned;
    Vsr.After_delete_condemned;
    Vsr.Delete_outdated;
    Vsr.After_delete_outdated;
    Vsr.Done;
    Vsr.Error;
  ]

let step_label (step : Vsr.step) : string =
  match step with
  | Vsr.Init -> "Init"
  | Vsr.After_list_pod -> "After_list_pod"
  | Vsr.Get_pvc -> "Get_pvc"
  | Vsr.After_get_pvc -> "After_get_pvc"
  | Vsr.Create_pvc -> "Create_pvc"
  | Vsr.After_create_pvc -> "After_create_pvc"
  | Vsr.Skip_pvc -> "Skip_pvc"
  | Vsr.Create_needed -> "Create_needed"
  | Vsr.After_create_needed -> "After_create_needed"
  | Vsr.Update_needed -> "Update_needed"
  | Vsr.After_update_needed -> "After_update_needed"
  | Vsr.Delete_condemned -> "Delete_condemned"
  | Vsr.After_delete_condemned -> "After_delete_condemned"
  | Vsr.Delete_outdated -> "Delete_outdated"
  | Vsr.After_delete_outdated -> "After_delete_outdated"
  | Vsr.Done -> "Done"
  | Vsr.Error -> "Error"

let at_step ~(controller_id : int) ~(cr_key : Common.object_ref)
    (step : Vsr.step) (s : Cluster.cluster_state) : bool =
  at_orc ~controller_id ~cr_key
    (fun _ (st : Vsr.s) _ -> Vsr.step_equal st.Vsr.reconcile_step step)
    s

(* The histogram itself, as (label, count) rows in [all_steps] order. [count]
   is supplied by the caller - it is the caller's replica that is being
   measured - so this module never explores a graph at module-initialisation
   time. That matters: dune links this module into EVERY test exe, so any
   top-level exploration here would be paid by all eighty-two of them. *)
let step_occupancy ~(count : (Cluster.cluster_state -> bool) -> int)
    ~(controller_id : int) ~(cr_key : Common.object_ref) : (string * int) list =
  List.map
    (fun (step : Vsr.step) ->
      (step_label step, count (at_step ~controller_id ~cr_key step)))
    all_steps

(* The union of the FOURTEEN steps at which upstream ever asserts
   [local_state_is_valid] - M1's borrowed [at_vsts_step] premise
   (state_predicates.ml:266-273). Written here as a projection over the
   histogram rather than as a second 17-arm match, so the two cannot drift:
   it names the three steps that are OUT ([Init], [After_list_pod], [Error])
   and takes the complement. *)
let non_valid_step_labels : string list =
  [ step_label Vsr.Init; step_label Vsr.After_list_pod; step_label Vsr.Error ]

let valid_step_total (hist : (string * int) list) : int =
  List.fold_left
    (fun (acc : int) ((label, n) : string * int) ->
      if List.mem label non_valid_step_labels then acc else acc + n)
    0 hist

let hist_total (hist : (string * int) list) : int =
  List.fold_left (fun (acc : int) ((_, n) : string * int) -> acc + n) 0 hist

let hist_lookup (hist : (string * int) list) (label : string) : int option =
  Option.map snd
    (List.find_opt
       (fun ((l, _) : string * int) -> String.equal l label)
       hist)

(* ==== the message-side projections shared by probes B3 and B4 ==============
   [list_resp_objs] is state_predicates.ml:100-114 verbatim (itself
   local_binding.ml:174-188, itself invariants.ml:348-360) and
   [ok_list_resps_for] is state_predicates.ml:119-126 verbatim. Both spell out
   all nine [Api_method] response constructors and all four
   [Message.message_content] constructors; no wildcard arm. *)

let msgs (s : Cluster.cluster_state) : Message.t list =
  Message.Pool.distinct (Cluster.in_flight s)

let list_resp_objs (m : Message.t) : Dynamic_object.t list option =
  match m.Message.content with
  | Message.Api_response (Api_method.List_response lr) ->
    Result.to_option lr.Api_method.res
  | Message.Api_response
      ( Api_method.Get_response _ | Api_method.Create_response _
      | Api_method.Delete_response _ | Api_method.Update_response _
      | Api_method.Update_status_response _
      | Api_method.Get_then_delete_response _
      | Api_method.Get_then_update_response _
      | Api_method.Get_then_update_status_response _ ) ->
    None
  | Message.Api_request _ | Message.External_request _
  | Message.External_response _ ->
    None

let ok_list_resps_for (s : Cluster.cluster_state) (req_msg : Message.t) :
    Message.t list =
  List.filter
    (fun (m : Message.t) ->
      Message.equal_host_id m.Message.src Message.Api_server
      && Message.resp_msg_matches_req_msg m req_msg
      && Option.is_some (list_resp_objs m))
    (msgs s)

(* reconcile_correspondence.ml:103-107. The shipped family no longer carries a
   copy of this - it went out with the cut member, whose delivery-window
   narrowing was its only consumer there - so this is now the tree's witness-side
   rendering of it, and [delivery_window] below is its one caller. *)
let matching_resp_in_flight (s : Cluster.cluster_state) (req : Message.t) : bool
    =
  List.exists
    (fun (resp : Message.t) -> Message.resp_msg_matches_req_msg resp req)
    (msgs s)

(* The parked chain: at [After_list_pod]; with a pending request; and the
   pending request seen as a VALUE. Each is a strict superset of the next, and
   t_p24_state_predicates asserts that ordering before it prints a count. *)

let parked ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : bool =
  at_step ~controller_id ~cr_key Vsr.After_list_pod s

let parked_with_pending ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : bool =
  at_orc ~controller_id ~cr_key
    (fun (o : Controller.ongoing_reconcile) (st : Vsr.s) _ ->
      Vsr.step_equal st.Vsr.reconcile_step Vsr.After_list_pod
      && Option.is_some o.Controller.pending_req_msg)
    s

let on_pending ~(controller_id : int) ~(cr_key : Common.object_ref)
    (f : Message.t -> Cluster.cluster_state -> bool)
    (s : Cluster.cluster_state) : bool =
  at_orc ~controller_id ~cr_key
    (fun (o : Controller.ongoing_reconcile) (st : Vsr.s)
         (cs : Cluster.cluster_state) ->
      Vsr.step_equal st.Vsr.reconcile_step Vsr.After_list_pod
      && Option.fold o.Controller.pending_req_msg ~none:false
           ~some:(fun (rm : Message.t) -> f rm cs))
    s

(* ==== PROBE B4: the [rm.src] MEASUREMENT THAT CUT M2 ======================
   THIS PROBE OUTLIVED THE MEMBER IT WAS BUILT FOR, AND THAT IS ITS POINT NOW.
   Upstream :49 requires [req_msg.src == Controller(controller_id, vsts_key)]
   and was, at the end of stage B, the ONE conjunct M2 claimed as new coverage.
   B4 measured it. The complement - a parked pending request sourced anywhere
   ELSE - is {b 0 on all four graphs}, over denominators 16 / 112 / 288 / 1560,
   pinned below as [pending_src_not_controller_everywhere]. Upstream :49 is TRUE
   at every state at which it is ever evaluated: a green that could not have
   been red, which is the defect condition that already excluded :241, :246 and
   the eight PVC conjuncts. That measurement is what CUT M2 - see the NEGATIVE
   RESULT block in state_predicates.ml - so this probe is now the finding's
   evidence and must stay live and assertable.

   :49's ABSENCE FROM L2 IS REAL AND IS NOT WHAT WAS AT ISSUE (refute verdict
   C5, confirmed: exactly one [.src] occurrence exists across
   local_binding.ml/.mli and it is on the RESPONSE variable inside
   [ok_list_resps_for] :193-200, while [after_list_pod_ok] :217-225 checks
   [rm.dst] and never [rm.src]). What was at issue is whether the conjunct has
   EXERCISABLE CONTENT on these graphs, and it does not.

   NO RED RATE MAY BE PREDICTED FOR IT, AND NONE IS. The "structurally always
   true, hence 100% of parked states" reading was refuted as UNMEASURED (verdict
   C6, adopted): lib/cluster/message.ml:175-179 always building api-server-bound
   requests with [~src:(Controller (controller_id, cr_key))] is
   plausibility-from-construction on BL0, not a measurement across BLc/BLd/BLm
   where adversarial actions exist. The number below is a MEASUREMENT ON THESE
   FOUR GRAPHS and is quoted as exactly that. Both polarities are probed, so the
   complement is measured rather than inferred by subtraction. *)

let pending_src_is_controller ~(controller_id : int)
    ~(cr_key : Common.object_ref) (s : Cluster.cluster_state) : bool =
  on_pending ~controller_id ~cr_key
    (fun (rm : Message.t) _ ->
      Message.equal_host_id rm.Message.src
        (Message.Controller (controller_id, cr_key)))
    s

(* ---- THE SRC HISTOGRAM: the complement's OWN route ------------------------
   [pending_src_is_not_controller] used to read [parked_with_pending && not
   pending_src_is_controller]. As the SUBTRACTED complement it made B4's
   partition control an IDENTITY that holds for ANY implementation of the
   positive projection, a constant one included - a control that cannot fail is
   not a control.

   So the pending request's [src] is CLASSIFIED here, by an EXHAUSTIVE five-arm
   match on {!Message.host_id} (message.mli:37-45) with the [Controller] arm
   split by the [(id, key)] it carries, and BOTH polarities are read off that
   classification. The route is genuinely different from
   [pending_src_is_controller]'s [Message.equal_host_id]: constructor match plus
   field equality, versus structural equality on the whole value. A constant
   positive projection therefore breaks the partition sum AND the
   bucket-agreement row, instead of cancelling out of both. Same shape as probe
   B2's step histogram, and for the same reason. *)

let this_controller_src_label : string = "Controller_this"

let src_label ~(controller_id : int) ~(cr_key : Common.object_ref)
    (h : Message.host_id) : string =
  match h with
  | Message.Api_server -> "Api_server"
  | Message.Builtin_controller -> "Builtin_controller"
  | Message.Controller (id, key) ->
    if Int.equal id controller_id && Common.equal_object_ref key cr_key then
      this_controller_src_label
    else "Controller_other"
  | Message.External _ -> "External"
  | Message.Pod_monkey -> "Pod_monkey"

let all_src_labels : string list =
  [
    this_controller_src_label;
    "Controller_other";
    "Api_server";
    "Builtin_controller";
    "External";
    "Pod_monkey";
  ]

let pending_src_at ~(controller_id : int) ~(cr_key : Common.object_ref)
    (label : string) (s : Cluster.cluster_state) : bool =
  on_pending ~controller_id ~cr_key
    (fun (rm : Message.t) _ ->
      String.equal (src_label ~controller_id ~cr_key rm.Message.src) label)
    s

(* Like [step_occupancy], the caller supplies [count] so this module never
   explores a graph at module-initialisation time. *)
let pending_src_occupancy ~(count : (Cluster.cluster_state -> bool) -> int)
    ~(controller_id : int) ~(cr_key : Common.object_ref) : (string * int) list =
  List.map
    (fun (label : string) ->
      (label, count (pending_src_at ~controller_id ~cr_key label)))
    all_src_labels

let src_other_total (hist : (string * int) list) : int =
  List.fold_left
    (fun (acc : int) ((label, n) : string * int) ->
      if String.equal label this_controller_src_label then acc else acc + n)
    0 hist

let pending_src_is_not_controller ~(controller_id : int)
    ~(cr_key : Common.object_ref) (s : Cluster.cluster_state) : bool =
  on_pending ~controller_id ~cr_key
    (fun (rm : Message.t) _ ->
      not
        (String.equal
           (src_label ~controller_id ~cr_key rm.Message.src)
           this_controller_src_label))
    s

(* Upstream :65, the RAW REQUEST's own network membership. It is strictly
   narrower than anything L2 checks because delivery is ATOMIC -
   lib/cluster/network.ml:19-37 mirrors upstream's
   [in_flight.remove(recv).add(send)] - so once a response exists that request
   occurrence is gone. THAT IS ALSO WHY IT BUYS NOTHING HERE: this projection is
   what MEASURED :65 entailed by the delivery window, reporting the same
   8 / 52 / 48 / 744 as [delivery_window] below on every graph. It STRUCK the
   M2b' mutant row first and then formed one half of the finding that CUT M2
   entirely. The equality is ASSERTED by t_p24_state_predicates rather than
   left as prose, which is why both this probe and [delivery_window] are still
   here. *)
let pending_still_in_flight ~(controller_id : int)
    ~(cr_key : Common.object_ref) (s : Cluster.cluster_state) : bool =
  on_pending ~controller_id ~cr_key
    (fun (rm : Message.t) (cs : Cluster.cluster_state) ->
      Message.Pool.mem rm (Cluster.in_flight cs))
    s

(* THE DELIVERY WINDOW: parked at [After_list_pod], pending slot is [Some], and
   no matching response is in flight YET. It was the CUT member's [interesting];
   it survives as the denominator of the :65 entailment above (equal populations
   are what "entailed" MEANS here) and as the population upstream's
   [pending_list_pod_req_in_flight] would have to be read over if a later phase
   ever revisits it. Named for the population, not for the member, because the
   member is gone. *)
let delivery_window ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : bool =
  on_pending ~controller_id ~cr_key
    (fun (rm : Message.t) (cs : Cluster.cluster_state) ->
      not (matching_resp_in_flight cs rm))
    s

(* M3's premise: parked, pending is [Some], and at least one matching ok
   [List_response] is in flight (state_predicates.ml:737-743). This is the
   population P23 already measured at 8 / 60 / 48 / 816. *)
let ok_resp_in_flight ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : bool =
  on_pending ~controller_id ~cr_key
    (fun (rm : Message.t) (cs : Cluster.cluster_state) ->
      not (ok_list_resps_for cs rm = []))
    s

(* ==== PROBE B3: [owned_objs] NON-EMPTINESS ================================
   The fork of RULING section 3.3, and the ONE measurement that decides whether
   M3's etcd-consuming conjuncts :116-118 and :119-124 ship and whether
   [weakly_eq] is written in P24 at all.

   Upstream :112 is
   [owned_objs = resp_objs.filter(|o| o.metadata.owner_references_contains(
      vsts.controller_owner_ref()))].
   The committed 8-of-8 BL0 pin [P23_witness.bl0_ok_list_resps_with_objs] is a
   STRICTLY WEAKER fact - it measures [resp_objs] non-emptiness, and
   [rg -n 'owned' test/p23_witness.ml] returns ZERO hits (refute verdict C14,
   confirmed; adopted). Nothing about the owner-ref-filtered subset was known
   before this probe ran, which is why it was probed and not predicted. STAGE B
   HAS SINCE RUN IT: the subset is NON-EMPTY at 8 / 60 / 40 / 776 over the
   8 / 60 / 48 / 816 population, i.e. RULING section 3.3's SHIP fork. The number
   itself stays PROSE in [State_predicates]'s interface; the only literal this
   block contributes is the reject-path ZERO pinned at the bottom of the file.

   THE OWNER REF IS AN [option] AND THAT IS LOAD-BEARING.
   [V_stateful_set.controller_owner_ref] (v_stateful_set.mli:42) returns
   [Owner_reference.t option]; a [None] would make every filter below empty and
   the whole probe would report a vacuous ZERO that looks exactly like the
   EXCLUDE fork. So the option is folded to [false] here and
   t_p24_state_predicates asserts [Option.is_some] on it as a POSITIVE CONTROL
   BEFORE it reads any owned count. A missed keyed lookup passing vacuously is
   this project's named failure mode. *)

let owned_objs ~(owner_ref : Owner_reference.t)
    (objs : Dynamic_object.t list) : Dynamic_object.t list =
  List.filter
    (fun (o : Dynamic_object.t) ->
      Object_meta.owner_references_contains (Dynamic_object.metadata o)
        owner_ref)
    objs

(* "at least one matching ok response carries at least one OWNED object" - the
   non-emptiness question in its exact wording. *)
let ok_resp_with_owned_objs ~(controller_id : int)
    ~(cr_key : Common.object_ref) ~(owner_ref : Owner_reference.t option)
    (s : Cluster.cluster_state) : bool =
  Option.fold owner_ref ~none:false ~some:(fun (r : Owner_reference.t) ->
      on_pending ~controller_id ~cr_key
        (fun (rm : Message.t) (cs : Cluster.cluster_state) ->
          List.exists
            (fun (m : Message.t) ->
              Option.fold (list_resp_objs m) ~none:false
                ~some:(fun (objs : Dynamic_object.t list) ->
                  not (owned_objs ~owner_ref:r objs = [])))
            (ok_list_resps_for cs rm))
        s)

(* ---- THE COMPLEMENT AND THE REJECT PATH, EACH ON ITS OWN ROUTE ------------
   [ok_resp_with_unowned_objs_only] used to read [ok_resp_in_flight && not
   ok_resp_with_owned_objs]. That had TWO defects, both of them the house's
   "green that could not have been red" condition:

   1. as the SUBTRACTED complement it made B3's partition control an IDENTITY.
      [population && not positive] plus [positive] sums to [population] for ANY
      implementation of the positive projection, a constant one included, so no
      mutation of it could ever redden the row;
   2. it did not measure what its own comment claimed. A state whose matching
      ok responses carry NO objects at all satisfied it WITHOUT the owner-ref
      filter ever rejecting anything - which is why the number it reported
      (0 / 0 / 8 / 40) was exactly [ok_resps - with_objs] and never a count of
      rejected objects.

   The population is therefore split THREE ways, each side computed from the
   response objects by its own route and NONE of them by subtraction:

     [ok_resp_with_owned_objs]         some matching response carries an OWNED
                                       object;
     [ok_resp_with_unowned_objs_only]  some matching response carries an object
                                       AND every object of every matching
                                       response is unowned - the filter ran and
                                       rejected all of them;
     [ok_resp_with_no_objs]            every matching response carries an EMPTY
                                       [objs] list - there was nothing to
                                       filter.

   The three are mutually exclusive and cover the population, so their sum is
   asserted against the count the GRAPH reports; and because the second and
   third never mention the first, a constant positive projection now breaks
   that sum instead of cancelling out of it. *)

(* The [objs] lists of every matching ok list-response, as data.
   [ok_list_resps_for] already filters on [Option.is_some (list_resp_objs m)],
   so this [filter_map] drops nothing and its length is the response count -
   which is what makes "[objss] is empty" the same fact as "the premise does
   not fire". *)
let resp_objs_of (s : Cluster.cluster_state) (rm : Message.t) :
    Dynamic_object.t list list =
  List.filter_map list_resp_objs (ok_list_resps_for s rm)

let ok_resp_with_unowned_objs_only ~(controller_id : int)
    ~(cr_key : Common.object_ref) ~(owner_ref : Owner_reference.t option)
    (s : Cluster.cluster_state) : bool =
  Option.fold owner_ref ~none:false ~some:(fun (r : Owner_reference.t) ->
      on_pending ~controller_id ~cr_key
        (fun (rm : Message.t) (cs : Cluster.cluster_state) ->
          let objss = resp_objs_of cs rm in
          List.exists
            (fun (objs : Dynamic_object.t list) -> not (objs = []))
            objss
          && List.for_all
               (fun (objs : Dynamic_object.t list) ->
                 owned_objs ~owner_ref:r objs = [])
               objss)
        s)

let ok_resp_with_no_objs ~(controller_id : int)
    ~(cr_key : Common.object_ref) (s : Cluster.cluster_state) : bool =
  on_pending ~controller_id ~cr_key
    (fun (rm : Message.t) (cs : Cluster.cluster_state) ->
      let objss = resp_objs_of cs rm in
      (not (objss = []))
      && List.for_all (fun (objs : Dynamic_object.t list) -> objs = []) objss)
    s

(* THE REJECT-PATH PROBE PROPER, and the only one that can witness the
   owner-reference filter saying NO about a real object: at least one object of
   one matching ok response FAILS
   [Object_meta.owner_references_contains]. It is deliberately NOT phrased over
   [owned_objs] - it applies the leaf predicate itself in the negative
   direction, so it is not the arithmetic dual of the positive projection but a
   separate traversal of the same data. *)
let ok_resp_with_some_unowned_obj ~(controller_id : int)
    ~(cr_key : Common.object_ref) ~(owner_ref : Owner_reference.t option)
    (s : Cluster.cluster_state) : bool =
  Option.fold owner_ref ~none:false ~some:(fun (r : Owner_reference.t) ->
      on_pending ~controller_id ~cr_key
        (fun (rm : Message.t) (cs : Cluster.cluster_state) ->
          List.exists
            (fun (objs : Dynamic_object.t list) ->
              List.exists
                (fun (o : Dynamic_object.t) ->
                  not
                    (Object_meta.owner_references_contains
                       (Dynamic_object.metadata o) r))
                objs)
            (resp_objs_of cs rm))
        s)

(* The weaker committed fact, re-derived here so B3's number can be read
   BESIDE it rather than against a remembered one: at least one matching ok
   response carries a NON-EMPTY [objs] list at all (P23's [:321] reading). *)
let ok_resp_with_objs ~(controller_id : int) ~(cr_key : Common.object_ref)
    (s : Cluster.cluster_state) : bool =
  on_pending ~controller_id ~cr_key
    (fun (rm : Message.t) (cs : Cluster.cluster_state) ->
      List.exists
        (fun (m : Message.t) ->
          Option.fold (list_resp_objs m) ~none:false
            ~some:(fun (objs : Dynamic_object.t list) -> not (objs = [])))
        (ok_list_resps_for cs rm))
    s

(* ==== PROBE B5: THE SCOPE-EXCLUSION REFUTATION, WITH ATTRIBUTION ==========
   Upstream's :116-118 (the owned-object-ref SET equality against
   [s.resources()]) and :119-124 (the forall whose body is :122 key-presence
   and :123 [weakly_eq]) are EXCLUDED-WITH-A-PIN on a SCOPE ground - a THIRD
   exclusion ground, distinct from the PVC pin (a SHAPE ground) and from
   :241/:246 (a REACHABILITY ground). The ground is upstream's own comment at
   state_predicates.rs:116, quoted verbatim:

     // coherence with etcd which preserves across steps taken by other
     // controllers satisfying rely conditions

   This port has no rely-condition machinery - that is a fact about the port,
   stated as one - and the BLc / BLm graphs inject by construction exactly the
   rely-violating writers the assumption excludes (a crash-orphaned request
   applied late; the pod monkey). Asserting these two conjuncts on those graphs
   asserts upstream's predicate OUTSIDE ITS STATED SCOPE.

   THIS PIN IS STRONGER THAN THE PHASE'S OTHER NINE, AND THE PROBES BELOW ARE
   WHY. The PVC pin and the :241/:246 pins record a VACUITY - a green that could
   not have been red. This one records a MEASURED REFUTATION WITH ATTRIBUTION:
   the excluded conjuncts were rendered, run over all four graphs, and SEEN red
   at named states, and the attribution says which conjunct, in which direction,
   and rules out the alternative diagnosis. So the numbers are ASSERTED, not
   narrated, and the probes stay live after the conjuncts are gone from
   {!Anvil_assurance.State_predicates} - they ARE the pin's evidence.

   The four things measured, each on its own traversal and none by subtraction:

   B5a  :116-118 SET-EQUALITY failures, and the two DIRECTIONS separately -
        [etcd_side_extra] (etcd holds a valid-owned object the response does
        not) and [resp_side_extra] (the response holds an owned object etcd no
        longer has). Two directions, two traversals, so a mutation of either
        containment moves exactly one column.
   B5b  :119-124 COHERENCE failures, split into the :122 key-presence half and
        the :123 [weakly_eq] half, so "every failure is :122" is a measurement
        rather than a reading.
   B5c  [weakly_eq]'s OWN comparison disagreements, arm by arm (metadata
        without resource version, kind, spec), counted ONLY over owned objects
        whose key IS in etcd. This is the load-bearing zero: it is what makes
        the diagnosis "the response is STALE" rather than "[weakly_eq] is
        wrong", so it is pinned rather than narrated - and its POSITIVE CONTROL
        ([weakly_eq_compared], some owned object really was compared against an
        etcd copy) is what stops the zero being an unexplored region.
   B5d  the MULTIPLICITY of matching ok list-responses, as a histogram. A state
        carrying two of them would make "the member is red" and "this response
        is stale" different claims - a universal-vs-existential artifact - so
        the bucket is measured, not assumed away.

   [weakly_eq] itself (upstream proof/predicate.rs:26-30) is duplicated here
   ARM BY ARM rather than as one boolean, because a single boolean cannot say
   WHICH arm disagreed and the whole point of B5c is to say which.

   THE PROBES WERE CONFIRMED BY MUTATION, AND ONE MUTANT SURVIVED - DISCLOSED
   RATHER THAN OMITTED.
   - [coherence_key_missing]'s [Option.is_none] flipped to [Option.is_some]:
     KILLED. The coherence pins and the containment relation both reddened, so
     those columns are not greens that could not have been red.
   - [weakly_eq_metadata_ne] with [Object_meta.without_resource_version]
     DROPPED, i.e. comparing raw metadata including [resource_version]:
     {b SURVIVED}. The column stayed 0 on all four graphs. That is a MEASURED
     fact and it strengthens the pin rather than weakening it - on these graphs
     an in-flight response object whose key IS still in etcd matches etcd's copy
     EXACTLY, resource version included - but it also means upstream's
     resource-version TOLERANCE (predicate.rs:25, "allow status and rv updates")
     has no witness here: nothing on these graphs distinguishes [weakly_eq]'s
     metadata arm from raw [Object_meta.equal]. A restorer of [weakly_eq] must
     not read its metadata arm as confirmed in that direction. *)

(* [obj.object_ref()] rendered TOTALLY - state_predicates.ml:425-431 verbatim.
   [Dynamic_object.object_ref] (dynamic_object.mli:29) is
   [Common.object_ref Res.t], i.e. PARTIAL, and a total classifier must not
   consume it (the P19 M2 / P20 R1 precedent). *)
let dyn_object_ref (o : Dynamic_object.t) : Common.object_ref =
  let om : Object_meta.t = Dynamic_object.metadata o in
  {
    Common.kind = Dynamic_object.kind o;
    name = Option.value ~default:"" om.Object_meta.name;
    namespace = Option.value ~default:"" om.Object_meta.namespace;
  }

(* Upstream [valid_owned_object_filter] (proof/predicate.rs:44-52), the ETCD
   side of the :116-118 set equality: :46 kind is [PodKind], :47 name is
   [Some], :48-49 namespace is [Some] the CR's, :50 the controller owner
   reference is present. *)
let valid_owned_object ~(namespace : string) ~(owner_ref : Owner_reference.t)
    (o : Dynamic_object.t) : bool =
  let om : Object_meta.t = Dynamic_object.metadata o in
  Common.equal_kind (Dynamic_object.kind o) Pod.kind
  && Option.is_some om.Object_meta.name
  && Option.equal String.equal om.Object_meta.namespace (Some namespace)
  && Object_meta.owner_references_contains om owner_ref

(* [s.resources().values().filter(valid_owned_object_filter(vsts))
    .map(|obj| obj.object_ref())]. Read through [Object_ref_map.bindings], the
   deterministic domain enumeration {!Object_ref_map} documents as the stand-in
   for Anvil's [Map] iteration, taking each VALUE's own [object_ref] and never
   the map key - which is what upstream's [.values().map(...)] does. *)
let etcd_valid_owned_refs ~(namespace : string)
    ~(owner_ref : Owner_reference.t) (s : Cluster.cluster_state) :
    Common.object_ref list =
  List.map dyn_object_ref
    (List.filter
       (valid_owned_object ~namespace ~owner_ref)
       (List.map snd (Object_ref_map.bindings (Cluster.resources s))))

let resp_owned_refs ~(owner_ref : Owner_reference.t)
    (objs : Dynamic_object.t list) : Common.object_ref list =
  List.map dyn_object_ref (owned_objs ~owner_ref objs)

let ref_mem (r : Common.object_ref) (rs : Common.object_ref list) : bool =
  List.exists (Common.equal_object_ref r) rs

(* :117-118 DIRECTION ONE: etcd holds a valid-owned object whose ref the
   response's owned set does NOT carry. *)
let etcd_side_extra ~(namespace : string) ~(owner_ref : Owner_reference.t)
    (s : Cluster.cluster_state) (objs : Dynamic_object.t list) : bool =
  let carried : Common.object_ref list = resp_owned_refs ~owner_ref objs in
  List.exists
    (fun (r : Common.object_ref) -> not (ref_mem r carried))
    (etcd_valid_owned_refs ~namespace ~owner_ref s)

(* :117-118 DIRECTION TWO: the response carries an OWNED object whose ref etcd's
   valid-owned set no longer has. *)
let resp_side_extra ~(namespace : string) ~(owner_ref : Owner_reference.t)
    (s : Cluster.cluster_state) (objs : Dynamic_object.t list) : bool =
  let held : Common.object_ref list =
    etcd_valid_owned_refs ~namespace ~owner_ref s
  in
  List.exists
    (fun (r : Common.object_ref) -> not (ref_mem r held))
    (resp_owned_refs ~owner_ref objs)

(* Both sides non-empty: the CONTROL that makes a zero on either direction a
   measured zero rather than an empty-versus-empty comparison. *)
let set_equality_has_content ~(namespace : string)
    ~(owner_ref : Owner_reference.t) (s : Cluster.cluster_state)
    (objs : Dynamic_object.t list) : bool =
  (not (resp_owned_refs ~owner_ref objs = []))
  && not (etcd_valid_owned_refs ~namespace ~owner_ref s = [])

(* :122, the key-presence conjunct: an OWNED response object whose key is not in
   [s.resources()] at all. *)
let coherence_key_missing ~(owner_ref : Owner_reference.t)
    (s : Cluster.cluster_state) (objs : Dynamic_object.t list) : bool =
  List.exists
    (fun (o : Dynamic_object.t) ->
      Option.is_none
        (Object_ref_map.find_opt (dyn_object_ref o) (Cluster.resources s)))
    (owned_objs ~owner_ref objs)

(* :123, [weakly_eq] (proof/predicate.rs:26-30), ARM BY ARM and only over owned
   objects whose key IS present - so each column answers "this arm disagreed",
   never "the lookup missed". [Dynamic_object.equal] (dynamic_object.mli:51) is
   NOT a shortcut: it also compares [status] and does not exclude
   [resource_version], the two fields upstream's comment at predicate.rs:25 says
   the relation must tolerate. *)
let on_present_owned ~(owner_ref : Owner_reference.t)
    (f : Dynamic_object.t -> Dynamic_object.t -> bool)
    (s : Cluster.cluster_state) (objs : Dynamic_object.t list) : bool =
  List.exists
    (fun (o : Dynamic_object.t) ->
      Option.fold
        (Object_ref_map.find_opt (dyn_object_ref o) (Cluster.resources s))
        ~none:false
        ~some:(fun (etcd_obj : Dynamic_object.t) -> f o etcd_obj))
    (owned_objs ~owner_ref objs)

let weakly_eq_metadata_ne ~(owner_ref : Owner_reference.t)
    (s : Cluster.cluster_state) (objs : Dynamic_object.t list) : bool =
  on_present_owned ~owner_ref
    (fun (a : Dynamic_object.t) (b : Dynamic_object.t) ->
      not
        (Object_meta.equal
           (Object_meta.without_resource_version (Dynamic_object.metadata a))
           (Object_meta.without_resource_version (Dynamic_object.metadata b))))
    s objs

let weakly_eq_kind_ne ~(owner_ref : Owner_reference.t)
    (s : Cluster.cluster_state) (objs : Dynamic_object.t list) : bool =
  on_present_owned ~owner_ref
    (fun (a : Dynamic_object.t) (b : Dynamic_object.t) ->
      not (Common.equal_kind (Dynamic_object.kind a) (Dynamic_object.kind b)))
    s objs

let weakly_eq_spec_ne ~(owner_ref : Owner_reference.t)
    (s : Cluster.cluster_state) (objs : Dynamic_object.t list) : bool =
  on_present_owned ~owner_ref
    (fun (a : Dynamic_object.t) (b : Dynamic_object.t) ->
      not (Value.equal (Dynamic_object.spec a) (Dynamic_object.spec b)))
    s objs

(* THE POSITIVE CONTROL for the three arms above: some owned response object
   really was looked up and FOUND, so a comparison genuinely happened. Without
   this row the three zeroes could all be "nothing was ever compared". *)
let weakly_eq_compared ~(owner_ref : Owner_reference.t)
    (s : Cluster.cluster_state) (objs : Dynamic_object.t list) : bool =
  on_present_owned ~owner_ref (fun _ _ -> true) s objs

(* ---- lifting a per-response projection to a STATE projection --------------
   The M3 premise ("parked, pending [Some], some matching ok list-response in
   flight") with the per-response body applied EXISTENTIALLY over the matching
   responses - exactly the polarity a counter needs, and the same polarity
   [ok_list_resp_shape]'s failure had. Probe B5d measures the multiplicity, so
   the existential is not silently standing in for a universal. *)

let on_matching_resp_objs ~(controller_id : int) ~(cr_key : Common.object_ref)
    (f : Cluster.cluster_state -> Dynamic_object.t list -> bool)
    (s : Cluster.cluster_state) : bool =
  on_pending ~controller_id ~cr_key
    (fun (rm : Message.t) (cs : Cluster.cluster_state) ->
      List.exists
        (fun (objs : Dynamic_object.t list) -> f cs objs)
        (resp_objs_of cs rm))
    s

let with_owner_ref ~(owner_ref : Owner_reference.t option)
    (f : Owner_reference.t -> Cluster.cluster_state -> bool)
    (s : Cluster.cluster_state) : bool =
  Option.fold owner_ref ~none:false ~some:(fun (r : Owner_reference.t) -> f r s)

(* B5a - the SET-EQUALITY column and its two directions. *)

let set_equality_fails ~(controller_id : int) ~(cr_key : Common.object_ref)
    ~(namespace : string) ~(owner_ref : Owner_reference.t option)
    (s : Cluster.cluster_state) : bool =
  with_owner_ref ~owner_ref
    (fun (r : Owner_reference.t) ->
      on_matching_resp_objs ~controller_id ~cr_key
        (fun (cs : Cluster.cluster_state) (objs : Dynamic_object.t list) ->
          etcd_side_extra ~namespace ~owner_ref:r cs objs
          || resp_side_extra ~namespace ~owner_ref:r cs objs))
    s

let set_equality_etcd_extra ~(controller_id : int)
    ~(cr_key : Common.object_ref) ~(namespace : string)
    ~(owner_ref : Owner_reference.t option) (s : Cluster.cluster_state) : bool =
  with_owner_ref ~owner_ref
    (fun (r : Owner_reference.t) ->
      on_matching_resp_objs ~controller_id ~cr_key
        (etcd_side_extra ~namespace ~owner_ref:r))
    s

let set_equality_resp_extra ~(controller_id : int)
    ~(cr_key : Common.object_ref) ~(namespace : string)
    ~(owner_ref : Owner_reference.t option) (s : Cluster.cluster_state) : bool =
  with_owner_ref ~owner_ref
    (fun (r : Owner_reference.t) ->
      on_matching_resp_objs ~controller_id ~cr_key
        (resp_side_extra ~namespace ~owner_ref:r))
    s

let set_equality_comparable ~(controller_id : int)
    ~(cr_key : Common.object_ref) ~(namespace : string)
    ~(owner_ref : Owner_reference.t option) (s : Cluster.cluster_state) : bool =
  with_owner_ref ~owner_ref
    (fun (r : Owner_reference.t) ->
      on_matching_resp_objs ~controller_id ~cr_key
        (set_equality_has_content ~namespace ~owner_ref:r))
    s

(* B5b - the COHERENCE column, split :122 / :123. *)

let coherence_fails ~(controller_id : int) ~(cr_key : Common.object_ref)
    ~(owner_ref : Owner_reference.t option) (s : Cluster.cluster_state) : bool =
  with_owner_ref ~owner_ref
    (fun (r : Owner_reference.t) ->
      on_matching_resp_objs ~controller_id ~cr_key
        (fun (cs : Cluster.cluster_state) (objs : Dynamic_object.t list) ->
          coherence_key_missing ~owner_ref:r cs objs
          || weakly_eq_metadata_ne ~owner_ref:r cs objs
          || weakly_eq_kind_ne ~owner_ref:r cs objs
          || weakly_eq_spec_ne ~owner_ref:r cs objs))
    s

let coherence_key_absent ~(controller_id : int) ~(cr_key : Common.object_ref)
    ~(owner_ref : Owner_reference.t option) (s : Cluster.cluster_state) : bool =
  with_owner_ref ~owner_ref
    (fun (r : Owner_reference.t) ->
      on_matching_resp_objs ~controller_id ~cr_key
        (coherence_key_missing ~owner_ref:r))
    s

(* B5c - [weakly_eq]'s own arms, and the control that they ran. *)

let weakly_eq_metadata_disagrees ~(controller_id : int)
    ~(cr_key : Common.object_ref) ~(owner_ref : Owner_reference.t option)
    (s : Cluster.cluster_state) : bool =
  with_owner_ref ~owner_ref
    (fun (r : Owner_reference.t) ->
      on_matching_resp_objs ~controller_id ~cr_key
        (weakly_eq_metadata_ne ~owner_ref:r))
    s

let weakly_eq_kind_disagrees ~(controller_id : int)
    ~(cr_key : Common.object_ref) ~(owner_ref : Owner_reference.t option)
    (s : Cluster.cluster_state) : bool =
  with_owner_ref ~owner_ref
    (fun (r : Owner_reference.t) ->
      on_matching_resp_objs ~controller_id ~cr_key
        (weakly_eq_kind_ne ~owner_ref:r))
    s

let weakly_eq_spec_disagrees ~(controller_id : int)
    ~(cr_key : Common.object_ref) ~(owner_ref : Owner_reference.t option)
    (s : Cluster.cluster_state) : bool =
  with_owner_ref ~owner_ref
    (fun (r : Owner_reference.t) ->
      on_matching_resp_objs ~controller_id ~cr_key
        (weakly_eq_spec_ne ~owner_ref:r))
    s

let weakly_eq_ran ~(controller_id : int) ~(cr_key : Common.object_ref)
    ~(owner_ref : Owner_reference.t option) (s : Cluster.cluster_state) : bool =
  with_owner_ref ~owner_ref
    (fun (r : Owner_reference.t) ->
      on_matching_resp_objs ~controller_id ~cr_key
        (weakly_eq_compared ~owner_ref:r))
    s

(* B5d - THE MULTIPLICITY HISTOGRAM. Buckets, not a boolean, and read the same
   way probes B2 and B4 are read: the three columns SUM to the
   parked-with-pending population, so a dropped bucket makes the sum SHORT
   instead of quietly reporting zero. The ["2+"] column is the one the pin
   names; the ["1"] column is its positive control. *)

let ok_resp_multiplicity_label (n : int) : string =
  if n = 0 then "0" else if n = 1 then "1" else "2+"

let all_multiplicity_labels : string list = [ "0"; "1"; "2+" ]
let multi_resp_label : string = "2+"

let ok_resp_multiplicity_at ~(controller_id : int)
    ~(cr_key : Common.object_ref) (label : string)
    (s : Cluster.cluster_state) : bool =
  on_pending ~controller_id ~cr_key
    (fun (rm : Message.t) (cs : Cluster.cluster_state) ->
      String.equal
        (ok_resp_multiplicity_label (List.length (ok_list_resps_for cs rm)))
        label)
    s

let ok_resp_multiplicity_occupancy
    ~(count : (Cluster.cluster_state -> bool) -> int) ~(controller_id : int)
    ~(cr_key : Common.object_ref) : (string * int) list =
  List.map
    (fun (label : string) ->
      (label, count (ok_resp_multiplicity_at ~controller_id ~cr_key label)))
    all_multiplicity_labels

(* ==== MEASURED (BUILD-SPEC-P24 stage B) ===================================

   STAGE B HAS RUN. [opam exec --switch=anvil-ocaml -- dune build @runtest] was
   run from the repo root, never piped through [tail] (which reports the
   pager's exit code and manufactures a fake green), and the four probe blocks
   printed by [t_p24_state_predicates.ml] were READ. The full dump is durable
   at ~/Documents/anvil-ocaml-p24-harness/stageB-p24-sp.log.

   THREE STAGE-B LITERALS ARE PINNED HERE, and each is a measured ZERO that a
   phase decision rests on:

   1. the [After_delete_outdated] occupancy that moves upstream :241 to
      EXCLUDE-WITH-A-PIN (the phase's own OPEN OBLIGATION);
   2. the OWNER-REFERENCE FILTER'S REJECT COUNT, added when probe B3's
      complement was de-tautologised. The B3 fork stayed NON-ZERO - owned
      objects are found on every graph - but the filter is never observed to
      REJECT one, and pinning that zero is what stops a later reader from
      believing the reject path was covered;
   3. B4's [rm.src] COMPLEMENT, and this one CUT A MEMBER. Upstream :49 is the
      only conjunct P23's L2 does not carry out of the seven the M2 candidate
      rendered, and the complement of its positive control is 0 on all four
      graphs over denominators 16 / 112 / 288 / 1560 - so :49 is TRUE at every
      state at which it is evaluated, a green that could not have been red, and
      the member buys nothing over L2. The pin is the finding's evidence and it
      is why this zero, unlike every other B4 number, is a literal.

   A THIRD GROUP HAS SINCE JOINED THEM, AND IT IS OF A DIFFERENT KIND - the
   PROBE-B5 SCOPE-EXCLUSION pins. Those are NOT vacuity zeroes. They record a
   MEASURED REFUTATION WITH ATTRIBUTION: upstream's :116-118 and :119-124 were
   rendered, run on all four graphs and SEEN RED, and the main loop then
   EXCLUDED them on a SCOPE ground (upstream's own rely-condition comment at
   state_predicates.rs:116 versus a port with no rely-condition machinery).
   Pinning the refutation is how the exclusion stays honest - a later reader
   must be able to see WHAT was refuted, WHERE and BY HOW MUCH, and that
   [weakly_eq] was never the cause. They are asserted in full at the bottom of
   this block.

   Every other stage-B number (B1's gate and per-member [interesting] counts,
   B3's [owned_objs] non-emptiness itself, B4's POSITIVE src column and the rest
   of its histogram) is PRINTED by the dump and consumed as PROSE in
   [State_predicates]'s interface; none of them is pinned as a literal, and no
   test may quote one as though it were. That distinction is the difference
   between a measurement and a pin, and this file only carries pins.

   A MOVED PIN IS A PHASE-STOP, NEVER A RETUNE. *)

(* THE :241 EXCLUSION PIN. Measured by PROBE B2 above, on this phase's own four
   graphs BL0 / BLc / BLd / BLm, and NEVER inherited from
   t_p11_vsts_liveness.ml:113-114 - that pin lives on a different, smaller
   20-state [fair:true] P11 graph, and extrapolating it here is exactly the
   error RULING section 1 forbids.

   Upstream :241 is [AfterDeleteOutdated ==> get_largest_unmatched_pods(vsts,
   needed) is Some]. Its guarding step is occupied at ZERO states on every one
   of the four graphs, so the implication is satisfied vacuously everywhere and
   no mutation of its consequent could ever turn it red - the house's
   "green that could not have been red" defect condition. It is therefore
   EXCLUDED from the shipped M1, on a REACHABILITY ground, which is the same
   ground :246 is excluded on and a DIFFERENT ground from the eight PVC
   conjuncts (those die on [P23_witness.pvcs_non_empty_everywhere = 0]).

   IT IS NOT A VACUOUS ZERO, and the control is measured rather than argued:
   the sibling step [Delete_outdated] is occupied at 8 / 76 / 64 / 1272 on the
   same four graphs, so the outdated pipeline IS entered - the reconciler just
   never advances past it under any shipped seed. [t_p24_state_predicates]
   asserts that floor in the same case that asserts this pin, and the
   histogram's own totality assertion (the seventeen columns sum to the decoded
   population) forbids the zero from being a dropped column. *)
let after_delete_outdated_occupancy_everywhere : int = 0

(* THE OWNER-REFERENCE FILTER'S REJECT PIN, and it is a FINDING, not a
   convenience. Measured by [ok_resp_with_some_unowned_obj] above on all four
   graphs: NOT ONE object carried by any matching ok list-response, on any P24
   graph, fails [Object_meta.owner_references_contains] against this CR's
   controller owner reference. Upstream :112's filter
   [resp_objs.filter(owner_references_contains(vsts.controller_owner_ref()))]
   is therefore only ever seen ACCEPTING; its reject path has no witness here,
   and no mutation of the filter's rejecting direction could be seen red on
   these graphs.

   THIS IS NOT A VACUOUS ZERO, and the controls are asserted BEFORE it in the
   same case: the CR really has a controller owner reference
   ([Option.is_some], without which every filter would be empty), the ok-list-
   response population is non-empty, and the responses really carry objects
   ([ok_resp_with_objs] > 0 on every graph). So the filter ran, on real
   objects, and accepted all of them.

   WHAT IT REPLACES. The old complement [ok_resp_with_unowned_objs_only] was
   [population && not owned] and reported 0 / 0 / 8 / 40; every one of those
   states is one whose matching responses carry NO objects at all, so it was
   read - by this file's own comment and by state_predicates.mli - as evidence
   that the filter had rejected something, which it never did. The recorded
   consequence for P25: the :256 flagship inherits an owner-ref filter whose
   negative direction is UNCOVERED on these graphs, and must budget a seed that
   plants a foreign-owned object if it wants that direction measured. *)
let ok_resp_some_unowned_obj_everywhere : int = 0

(* THE PIN THAT CUT M2, and it is a FINDING with a member's name on it.
   Measured by [pending_src_is_not_controller] above - read off the EXHAUSTIVE
   src histogram, never subtracted from the positive projection - over the
   parked-with-pending population on all four graphs: NOT ONE state at which a
   reconcile is parked at [After_list_pod] with a pending request has that
   request sourced anywhere but [Controller (controller_id, cr_key)]. Upstream
   :49 ([req_msg.src == Controller(controller_id, vsts_key)]) is therefore TRUE
   at every state at which it is ever evaluated: a GREEN THAT COULD NOT HAVE
   BEEN RED, the same defect condition that excluded :241, :246 and the eight
   PVC conjuncts.

   THAT IS WHY THE FAMILY HAS TWO MEMBERS AND NOT THREE. :49 was the whole of
   the M2 candidate's claimed new coverage (its other six conjuncts are P23's L2
   - five literally, :65 by an entailment this file's own
   [pending_still_in_flight] / [delivery_window] equality measures), so with :49
   unwitnessed the member bought NOTHING over L2 and the main loop CUT it. The
   full record is the NEGATIVE RESULT block in state_predicates.ml and the
   matching block in its .mli.

   THIS IS NOT A VACUOUS ZERO, and the controls are asserted BEFORE it in the
   same case, on routes that do not share an implementation with it: the
   parked-with-pending population is non-empty on every graph; the six src
   buckets are the six {!Message.host_id} classifications in order, against a
   list typed independently; they SUM to that population; and the
   [Controller_this] bucket AGREES with the positive projection computed by
   structural [Message.equal_host_id]. Making the positive projection constant
   was SEEN to redden the partition (BUILD-SPEC-P24 5.0.1, rows MC2 / MC2').
   The denominators the zero sits against are 16 / 112 / 288 / 1560, PRINTED in
   the B4 dump and asserted there as the population the buckets sum to. *)
let pending_src_not_controller_everywhere : int = 0

(* ==== THE SCOPE-EXCLUSION PINS (probe B5) =================================
   Upstream :116-118 and :119-124 are EXCLUDED-WITH-A-PIN on a SCOPE ground,
   the phase's THIRD exclusion ground - distinct from the PVC pin (a SHAPE
   ground, seven conjuncts) and from :241 / :246 (a REACHABILITY ground, two).
   The ground is upstream's own comment at state_predicates.rs:116, quoted
   verbatim in state_predicates.mli, against the fact that this port has no
   rely-condition machinery while BLc and BLm inject by construction exactly
   the rely-violating writers the assumption excludes.

   THESE PINS ARE ASSERTED NUMBERS, NOT PROSE, AND THEY ARE NOT ZEROES.
   Everything else this file pins is a vacuity - a green that could not have
   been red. These record the opposite: two conjuncts that WERE rendered, WERE
   run over all four graphs, and WERE seen red at named states. An exclusion
   whose evidence is not pinned degrades, one revision at a time, into an
   omission, so the refutation is carried as a literal with the same force as a
   graph pin. A MOVED NUMBER HERE IS A PHASE-STOP: it means either the graphs
   moved (which the state pins would also catch) or the probes drifted from the
   conjuncts they stand in for.

   RE-MEASURED FOR THIS RULING, not copied: probe B5 was written, built and run
   over SP0 / SPc / SPd / SPm BEFORE the conjuncts were removed, and every
   column below is read off that run
   (~/Documents/anvil-ocaml-p24-harness/stageB-p24-sp.log's successor dump,
   printed by t_p24_state_predicates' B5 block).

   THE ATTRIBUTION THAT LICENSES THE EXCLUSION, measured while the conjuncts
   were still shipped: M3's per-state RED count on the replica was
   0 / 8 / 0 / 72 - EQUAL, graph by graph, to the union of the two columns
   below. The member's red set was EXACTLY the set these probes select, so the
   exclusion removes those states and nothing else. That identity cannot be
   re-asserted now (the shipped member is green everywhere), which is precisely
   why the two halves are printed side by side in the B5 dump. *)

(* :116-118, the owned-object-ref SET equality, per graph. *)
let set_equality_failures_sp0 : int = 0
let set_equality_failures_spc : int = 8
let set_equality_failures_spd : int = 0
let set_equality_failures_spm : int = 72

(* ...and its two DIRECTIONS, each measured on its own traversal so a mutation
   of either containment moves exactly one column. DIRECTION ONE: etcd holds a
   valid-owned object the response does not. *)
let set_equality_etcd_extra_sp0 : int = 0
let set_equality_etcd_extra_spc : int = 4
let set_equality_etcd_extra_spd : int = 0
let set_equality_etcd_extra_spm : int = 32

(* DIRECTION TWO: the response holds an owned object etcd no longer has. *)
let set_equality_resp_extra_sp0 : int = 0
let set_equality_resp_extra_spc : int = 4
let set_equality_resp_extra_spd : int = 0
let set_equality_resp_extra_spm : int = 40

(* :119-124, the coherence forall, per graph. *)
let coherence_failures_sp0 : int = 0
let coherence_failures_spc : int = 4
let coherence_failures_spd : int = 0
let coherence_failures_spm : int = 40

(* ...and the :122 KEY-PRESENCE half of it, measured separately. The two
   columns are EQUAL on every graph, which is the measurement behind "every
   :119-124 failure is :122": the response names an owned object whose key has
   since left etcd. Pinning both is what makes that an assertion rather than a
   reading - if :123 ever contributed, these two would part. *)
let coherence_key_absent_sp0 : int = 0
let coherence_key_absent_spc : int = 4
let coherence_key_absent_spd : int = 0
let coherence_key_absent_spm : int = 40

(* [weakly_eq]'s OWN comparison, ARM BY ARM, over owned response objects whose
   key IS in etcd. THIS IS THE LOAD-BEARING ZERO OF THE WHOLE EXCLUSION: it is
   what makes the diagnosis "the in-flight response is STALE relative to etcd"
   rather than "[weakly_eq] is wrong", so it is pinned and not narrated. Its
   POSITIVE CONTROL is [P24_witness.weakly_eq_ran], asserted non-zero on every
   graph immediately before these are read - without it the three zeroes could
   equally mean nothing was ever compared. *)
let weakly_eq_metadata_disagreements_everywhere : int = 0
let weakly_eq_kind_disagreements_everywhere : int = 0
let weakly_eq_spec_disagreements_everywhere : int = 0

(* The MULTIPLICITY zero: no premise state carries TWO matching ok
   list-responses. Without it, "the member is red" and "this response is stale"
   would be different claims and the attribution above would be a
   universal-versus-existential artifact. Its positive control is the ["1"]
   bucket of the same three-column histogram, which measures the whole
   ok-list-response population 8 / 60 / 48 / 816, and the histogram's own
   totality (three columns summing to parked-with-pending) forbids the zero
   from being a dropped bucket. *)
let multi_matching_ok_resps_everywhere : int = 0

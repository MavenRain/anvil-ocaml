(* BUILD-SPEC-P23 sections 3-4 and 8 - the controller-LOCAL binding
   measurement: {!Anvil_checker.Fault_check.check_local_binding_under_faults}
   (the L1/L2 family of {!Anvil_assurance.Local_binding.binding_family}) over
   the four shipped fault graphs BL0 / BLc / BLd / BLm, with every MEASURED
   number of section 8 committed as a pin.

   WHAT THIS EXE ESTABLISHES.

   1. THE OTHER AXIS OF internal_rely_guarantee.rs, MEASURED GREEN. P21 shipped
      the four WIRE members of that file - what the VSTS controller guarantees
      about the requests it EMITS. This family is what the controller is
      HOLDING: the pods the reconcile round decoded into [needed] and
      [condemned] are bound to the CR whose key the round runs under (L1,
      upstream :613), and the round parked at [AfterListPod] really is parked on
      a pod-[ListRequest] in the CR's namespace (L2, :640). Upstream DISCHARGES
      both as cluster invariants (:668), so the P21 epistemic reading carries
      over unchanged: a red is a FIDELITY DIVERGENCE in the port and a real
      finding, not an environment datum.

   2. PIN SAFETY IS STRUCTURAL, AND IT IS RE-MEASURED HERE. [run_leg] passes
      [Model_check.explore] only [~depth ~successors ~equal ~hash ~init] and
      [explore] takes no invariant argument, so GRAPHS ARE FAMILY-BLIND: the new
      leg reuses P22's [(seed, bound, budget, depth)] and cannot move a state
      count. The argument is not trusted, it is measured - the four leg rows
      below re-assert P22's 88 / 808 / 1144 / 10216, and the [pin_safety] case
      re-EXPLORES all five P13-P21 graphs (76 / 464 / 744 / 1976 / 116). A moved
      pin is a phase-STOP, never a retune.

   3. PER-MEMBER ATTRIBUTION COMES FROM A REPLICA, NEVER FROM THE LEG. L1 is
      CONTAINED in L2 (upstream :642 calls E4), so L2's [holds] strictly implies
      L1's; [Invariants.first_violated] (invariants.ml:1046) is
      FIRST-IN-LIST-ORDER and the leg's [~violated] resolves through it
      (fault_check.ml:249-258). So for ANY shared-conjunct failure L1 is the
      member NAMED and L2 LOOKS GREEN. Every per-member count below is therefore
      computed test-side over a local replica of the leg's product graph (the
      t_p21_guarantee.ml:193-237 technique), with the replica's [Mc.states_seen]
      asserted equal to the leg's own [states] BEFORE any count is read.

   4. HONEST VACUITY, AND ONE COMMITTED PREDICTION REFUTED. BUILD-SPEC-P23
      prediction 5 said L1's needed-witness count is EXACTLY 0 on all four
      graphs. It is 20 / 200 / 208 / 3616. The [needed_non_vacuity] case pins
      that refutation AND its measured mechanism: the port RE-RECONCILES, so
      pod-0 created in one round lands in the needed slot in a LATER round.
      Every one of BL0's 20 witness states has pod-0 in etcd and none lacks it.
      The needed conjunct C1 therefore ships AS WRITTEN - no exclusion, no pin,
      no de-vacuizer. The wrong reasoning is left standing in the spec's section
      2.1 unedited, so the refutation stays legible.

   5. THE EXCLUDED PVCS FORALL IS PINNED, NOT MERELY OMITTED. Upstream :629-637
      is not ported (BUILD-SPEC-P23 section 2.1 exclusion 1). The
      [pvcs_exclusion_pin] case asserts, over EVERY P23 graph, that no decoded
      ongoing state has a PVC - 10684 decoded states, zero PVCs - so the
      omission is behavior-free. The pin's RED CAPABILITY is measured next door
      in t_p23_mutation (row MB7, a throwaway [vct:true] replica); a pin never
      SEEN to redden is not evidence, and that is where it is seen.

   6. L2'S INNER FORALL IS LIVE, MEASURED, NOT ASSUMED - AND ITS CONSEQUENT NOW
      HAS A RED-CAPABILITY ROW OF ITS OWN. Prediction 6 was the one most likely
      to be refuted and was UNVERIFIED in the tree. The [inner_premise] case
      pins the count of states parked at [After_list_pod] with a matching ok
      [List_response] in flight (8 / 60 / 48 / 816) AND the two supporting
      facts: the list-request content test holds at 100 percent of the
      parked-with-pending states, and on BL0 all 8 of the 8 responses carry a
      NON-EMPTY [objs] list, so :659-661 is applied to real objects.

      WHAT THOSE THREE MEASUREMENTS ESTABLISH, exactly: the PREMISE fires, and
      the body RUNS on real objects. They do NOT establish that the CONSEQUENT
      ([resp_objs_in_namespace], local_binding.ml:206-212) can be seen FALSE.
      It is TRUE at every state of all four graphs - which is precisely what
      "both members red = 0 on every shipped graph" says - so NO assertion in
      this file can move under a weakening of it. That remaining step is closed
      next door in t_p23_mutation by row [mb9_inner_consequent]: it forges an
      in-flight ok [List_response], formed FROM the parked pending request so
      the :652-657 premise selects it by construction, carrying one object
      whose namespace is NOT the CR's, and SEES L2 RED there - with the same
      shape in the CR's own namespace GREEN as the negative control. The row
      was itself confirmed by mutation: weaken local_binding.ml:211 to
      [Option.is_some om.namespace] and it fails Expected [false] / Received
      [true], while every graph pin in this file stays byte-identical.

   TEST-ORDERING RULE (P12 finding 1, P13-P22 precedent): every test asserts the
   SEMANTIC facts FIRST - outcome, [violated], decisive, replica faithfulness,
   floors - and only THEN the brittle exact counts.

   Every pinned number comes from {!P23_witness} (single source of truth); none
   is re-typed here. Graph-identity constants are read through the witness chain
   (P23 <- P22 <- P21 <- ... <- P13), never re-typed.

   [report_decisive] DOES NOT EXIST in this tree (the P20 B1 phantom finding,
   still true); every leg is reported through the LOCAL decisive projection
   below - the two-arm exhaustive [Mc.outcome] match of t_p17_store.ml:71-79.

   THE PREMISE PROJECTIONS BELOW ARE A DELIBERATE DUPLICATION of
   [Local_binding]'s private helpers, with their origins cited - the
   duplicate-and-pin house precedent (internal_guarantee.ml:131-136). The module
   exports exactly two vals ([binding_sources], [binding_family]), so the
   lookup / decode / list-request / ok-response projections a counter needs are
   NOT callable, and re-exporting them to make a test easier would widen a
   shipped surface for a test's convenience. The duplication is pinned by the
   counts agreeing with the members' own [interesting] where they must
   ([l2_interesting_*] against [parked_with_pending]).

   Firewall honoured: List/Option/fold combinators only (no loop keywords),
   exhaustive matches on every finite sum (both [Mc.outcome] arms, all nine
   [Api_method] request and response constructors, all four
   [Message.message_content] constructors), no two-arm match on
   [option]/[result] (stdlib [Option.fold] / [Option.bind] / [Result.to_option]),
   total accessors only, no exceptions, Alcotest as the sanctioned failure
   primitive. *)

module Fc = Anvil_checker.Fault_check
module Mc = Anvil_checker.Model_check
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants
module Lb = Anvil_assurance.Local_binding
module Vsr = V_stateful_set_reconciler
module Pack = V_stateful_set_pack

let controller_id : int = Scenario.controller_id
let cluster : Cluster.t = Scenario.vsts_cluster
let desired : int = P23_witness.witness_desired
let ordinals : int list = P23_witness.p23_ordinals
let depth : int = P23_witness.witness_depth
let bound : Bound.t = P23_witness.p23_bound ~desireds:[ desired ]
let cr : V_stateful_set.t = Scenario.vsts ~desired ()
let family : Invariants.invariant list = Lb.binding_family ~cr ~controller_id

(* ---- report projections (exhaustive 2-arm matches on [Mc.outcome]) -------- *)

let decisive (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample { decisive; _ } -> decisive
  | Mc.Refuted _ -> false

let is_clean (r : Fc.fault_report) : bool =
  match r.outcome with
  | Mc.No_counterexample _ -> true
  | Mc.Refuted _ -> false

(* [Mc.Refuted] carries no [states] field (model_check.mli:39); [-1] is the
   shipped sentinel. Every leg below is expected clean, so the sentinel
   surfacing in a pin assertion is itself a loud diagnosis. *)
let states_of (r : Fc.fault_report) : int =
  match r.outcome with
  | Mc.No_counterexample { states; _ } -> states
  | Mc.Refuted _ -> -1

let gate_of (r : Fc.fault_report) : int = Option.value r.gate_states ~default:(-1)

let violated_name (r : Fc.fault_report) : string =
  Option.fold r.violated ~none:"<none>"
    ~some:(fun (i : Invariants.invariant) -> i.Invariants.name)

(* ==== the two members, addressed BY NAME off the family ====================
   t_p20_rely's discipline, inherited through P21/P22: a missing name makes both
   projections constantly [false], which the family-shape test and every [> 0]
   floor below reddens LOUDLY before any count could quietly go 0. *)

let l1_name : string = P23_witness.l1_name
let l2_name : string = P23_witness.l2_name

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

(* ==== the leg runs (lazy: no test pays for an unused exploration) ========= *)

let leg ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget)
    ~(require_fault : bool) : Fc.fault_report =
  Fc.check_local_binding_under_faults ~depth ~req_drop ~pod_monkey bound budget
    ~desired ~ordinals ~require_fault

let bl0 : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false P23_witness.zero_budget
       ~require_fault:false)

let blc : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:false P23_witness.blc_budget
       ~require_fault:true)

let bld : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:true ~pod_monkey:false P23_witness.bld_budget
       ~require_fault:true)

let blm : Fc.fault_report Lazy.t =
  lazy
    (leg ~req_drop:false ~pod_monkey:true P23_witness.blm_budget
       ~require_fault:true)

(* ==== LOCAL replicas of the legs' product graphs ===========================
   The per-member counts need the reachable set itself, which [fault_report]
   does not carry. Same seed / bound / budget / depth through the exported
   {!Fc.faulted_successors}; every consuming test asserts [Mc.states_seen]
   against the leg's own [states] FIRST (the P13 M3/M5 precedent - a drifted
   replica would silently measure a DIFFERENT graph and every count below it
   would be a number about nothing). *)

let seed_of ~(req_drop : bool) ~(pod_monkey : bool) : Cluster.cluster_state =
  Scenario.vsts_seed_with_pods ~desired ~ordinals ~crash:true ~req_drop
    ~pod_monkey ()

let reach_of ~(req_drop : bool) ~(pod_monkey : bool) (budget : Fc.budget) :
    Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:[ Fc.faulted_of_seed (seed_of ~req_drop ~pod_monkey) ]

let bl0_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false P23_witness.zero_budget)

let blc_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:false P23_witness.blc_budget)

let bld_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:true ~pod_monkey:false P23_witness.bld_budget)

let blm_reach : Fc.faulted Mc.reachable Lazy.t =
  lazy (reach_of ~req_drop:false ~pod_monkey:true P23_witness.blm_budget)

(* ==== the INHERITED P13-P21 graphs, re-explored for pin safety =============
   Their own bound and their own seed builder (no [~ordinals]) - the P21 leg's
   inputs exactly, read through the chain rather than re-typed. This phase
   edits none of them; the case exists so the family-blindness ARGUMENT is
   measured rather than trusted. *)

let inherited_bound : Bound.t = P21_witness.p21_bound ~desireds:[ desired ]

let inherited_reach ~(req_drop : bool) ~(pod_monkey : bool) ~(vct : bool)
    (budget : Fc.budget) : Fc.faulted Mc.reachable =
  Mc.explore ~depth
    ~successors:(Fc.faulted_successors inherited_bound budget cluster)
    ~equal:Fc.faulted_equal ~hash:Fc.faulted_hash
    ~init:
      [
        Fc.faulted_of_seed
          (Scenario.vsts_seed_faults ~desired ~crash:true ~req_drop ~pod_monkey
             ~vct ());
      ]

(* ---- counting projections over a replica --------------------------------- *)

let fires (reach : Fc.faulted Mc.reachable) (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      member_interesting family name f.cs)

let reds (reach : Fc.faulted Mc.reachable) (name : string) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) ->
      not (member_holds family name f.cs))

let count (reach : Fc.faulted Mc.reachable)
    (p : Cluster.cluster_state -> bool) : int =
  Mc.count_states_where reach (fun (f : Fc.faulted) -> p f.cs)

(* ==== PREMISE PROJECTIONS - the duplicate-and-pin block ====================
   Copied from {!Local_binding}'s private helpers with their origins cited (see
   the header). Every one is total, pure and exception-free. *)

(* [cr_key_of], local_binding.ml:73-78 (itself internal_guarantee.ml:93-98),
   with the same disclosed [Option.value ~default:""] reading: the port EXPORTS
   [V_stateful_set.object_ref] but it is [Res.t]-typed hence partial, and a
   total classifier must not consume it. *)
let cr_md : Object_meta.t = V_stateful_set.metadata cr
let ns : string = Option.value ~default:"" (Object_meta.namespace cr_md)
let parent : string = Option.value ~default:"" (Object_meta.name cr_md)

let cr_key : Common.object_ref =
  { Common.kind = V_stateful_set.kind; name = parent; namespace = ns }

(* [Cluster.ongoing_reconciles] is TOTAL: a missing controller id yields the
   empty map (cluster.mli:78-82), so this is [None] rather than an exception at
   a wrong id. *)
let orc_of (s : Cluster.cluster_state) : Controller.ongoing_reconcile option =
  Object_ref_map.find_opt cr_key (Cluster.ongoing_reconciles s controller_id)

let has_reconcile (s : Cluster.cluster_state) : bool = Option.is_some (orc_of s)

let decode_failed (s : Cluster.cluster_state) : bool =
  Option.fold (orc_of s) ~none:false ~some:(fun (o : Controller.ongoing_reconcile) ->
      Result.is_error (Pack.unmarshal_state o.Controller.local_state))

(* The lookup/decode skeleton of [Local_binding.at_reconcile] (:272-286), with
   BOTH out-of-premise directions folded to [false] because every consumer here
   is a COUNTER (a count of states where something is TRUE), not a [holds]. *)
let at_orc (f : Controller.ongoing_reconcile -> Vsr.s -> bool)
    (s : Cluster.cluster_state) : bool =
  Option.fold (orc_of s) ~none:false ~some:(fun (o : Controller.ongoing_reconcile) ->
      Option.fold
        (Result.to_option (Pack.unmarshal_state o.Controller.local_state))
        ~none:false
        ~some:(fun (st : Vsr.s) -> f o st))

let decoded (s : Cluster.cluster_state) : bool = at_orc (fun _ _ -> true) s

let needed_witness (s : Cluster.cluster_state) : bool =
  at_orc (fun _ (st : Vsr.s) -> List.exists Option.is_some st.Vsr.needed) s

(* The NARROW reading of "the needed slot is None" (section 8.3's 36): the
   reconcile decodes, the [needed] list is NON-EMPTY, and every slot in it is
   [None]. Distinct from "L1's needed witness does not fire", which also holds
   where there is no reconcile at all or where [needed] is still [[]]. *)
let needed_slot_all_none (s : Cluster.cluster_state) : bool =
  at_orc
    (fun _ (st : Vsr.s) ->
      (not (st.Vsr.needed = []))
      && List.for_all (fun (p : Pod.t option) -> Option.is_none p) st.Vsr.needed)
    s

let condemned_witness (s : Cluster.cluster_state) : bool =
  at_orc (fun _ (st : Vsr.s) -> not (st.Vsr.condemned = [])) s

let pvcs_non_empty (s : Cluster.cluster_state) : bool =
  at_orc (fun _ (st : Vsr.s) -> not (st.Vsr.pvcs = [])) s

let parked (s : Cluster.cluster_state) : bool =
  at_orc
    (fun _ (st : Vsr.s) ->
      Vsr.step_equal st.Vsr.reconcile_step Vsr.After_list_pod)
    s

let parked_with_pending (s : Cluster.cluster_state) : bool =
  at_orc
    (fun (o : Controller.ongoing_reconcile) (st : Vsr.s) ->
      Vsr.step_equal st.Vsr.reconcile_step Vsr.After_list_pod
      && Option.is_some o.Controller.pending_req_msg)
    s

(* [list_req_content_matches], local_binding.ml:151-166 (itself
   invariants.ml:334-347, transposed VRS -> VSTS): upstream :647 plus :648-651
   read as ONE content test. All nine request constructors and all four content
   constructors are spelled out; no wildcard arm. *)
let list_req_content_matches (m : Message.t) ~(namespace : string) : bool =
  match m.Message.content with
  | Message.Api_request (Api_method.List_request lr) ->
    Common.equal_kind lr.Api_method.kind Pod.kind
    && String.equal lr.Api_method.namespace namespace
  | Message.Api_request
      ( Api_method.Get_request _ | Api_method.Create_request _
      | Api_method.Delete_request _ | Api_method.Update_request _
      | Api_method.Update_status_request _ | Api_method.Get_then_delete_request _
      | Api_method.Get_then_update_request _
      | Api_method.Get_then_update_status_request _ ) ->
    false
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    false

(* [list_resp_objs], local_binding.ml:174-188 (itself invariants.ml:348-360):
   upstream :657's [is_ok_resp] plus :659's [res.unwrap()] read together as "the
   content is a [List_response] whose [res] is [Ok]". *)
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

(* [ok_list_resps_for], local_binding.ml:193-200 (itself invariants.ml:361-368):
   the inner forall's PREMISE - in flight (:653), source is the api server
   (:655), the response matches the pending request (:656), ok response (:657). *)
let ok_list_resps_for (s : Cluster.cluster_state) (req_msg : Message.t) :
    Message.t list =
  List.filter
    (fun (m : Message.t) ->
      Message.equal_host_id m.Message.src Message.Api_server
      && Message.resp_msg_matches_req_msg m req_msg
      && Option.is_some (list_resp_objs m))
    (Message.Pool.distinct (Cluster.in_flight s))

(* The parked state's pending request really IS the pod list, addressed to the
   api server - upstream :646-651. *)
let on_pending (f : Message.t -> Cluster.cluster_state -> bool)
    (s : Cluster.cluster_state) : bool =
  at_orc
    (fun (o : Controller.ongoing_reconcile) (st : Vsr.s) ->
      Vsr.step_equal st.Vsr.reconcile_step Vsr.After_list_pod
      && Option.fold o.Controller.pending_req_msg ~none:false
           ~some:(fun (rm : Message.t) -> f rm s))
    s

let parked_pod_list (s : Cluster.cluster_state) : bool =
  on_pending
    (fun (rm : Message.t) _ ->
      Message.equal_host_id rm.Message.dst Message.Api_server
      && list_req_content_matches rm ~namespace:ns)
    s

let ok_resp_in_flight (s : Cluster.cluster_state) : bool =
  on_pending
    (fun (rm : Message.t) (st : Cluster.cluster_state) ->
      not (ok_list_resps_for st rm = []))
    s

let ok_resp_with_objs (s : Cluster.cluster_state) : bool =
  on_pending
    (fun (rm : Message.t) (st : Cluster.cluster_state) ->
      List.exists
        (fun (m : Message.t) ->
          Option.fold (list_resp_objs m) ~none:false ~some:(fun objs ->
              not (objs = [])))
        (ok_list_resps_for st rm))
    s

(* Section 8.3's mechanism probe: is pod-0 stored in etcd at this state?
   [Cluster.lookup_resource] is the guarded etcd read (cluster.mli:89-92). *)
let pod0_key : Common.object_ref =
  { Common.kind = Pod.kind; namespace = ns; name = Vsr.pod_name parent 0 }

let pod0_in_etcd (s : Cluster.cluster_state) : bool =
  Option.is_some (Cluster.lookup_resource s pod0_key)

(* ---- the shared GREEN-leg assertion bundle --------------------------------
   Semantic facts first, exact pins last. Both members' [interesting] floors are
   asserted [> 0] BEFORE their exact pins: unlike P21's G2 row there is no
   honest-vacuity member here, and a phase whose new register fired nowhere
   would be a green about nothing. *)

let check_green_leg (label : string) (r : Fc.fault_report)
    (reach : Fc.faulted Mc.reachable) ~(states : int) ~(gate : int) ~(l1 : int)
    ~(l2 : int) : unit =
  Alcotest.(check bool)
    (label
   ^ ": outcome CLEAN - the LOCAL binding HELD (a red here is a FIDELITY \
      divergence in the port, upstream discharges both members at :668)")
    true (is_clean r);
  Alcotest.(check string) (label ^ ": violated = None") "<none>"
    (violated_name r);
  Alcotest.(check bool) (label ^ ": decisive") true (decisive r);
  Alcotest.(check int)
    (label ^ ": replica explored the leg's exact graph (states_seen)")
    (states_of r) (Mc.states_seen reach);
  Alcotest.(check bool)
    (label
   ^ ": family gate > 0 - the NON-VACUITY FLOOR; a zero here means the leg \
      asserted a family that never fired")
    true (gate_of r > 0);
  Alcotest.(check bool)
    (label ^ ": L1 premise fires somewhere (the needed/condemned witness)") true
    (fires reach l1_name > 0);
  Alcotest.(check bool)
    (label
   ^ ": L2 premise fires somewhere - PREDICTION 1, THE PHASE GATE: the \
      reconcile really does park at After_list_pod with a pending request")
    true
    (fires reach l2_name > 0);
  (* exact MEASURED pins LAST *)
  Alcotest.(check int)
    (label
   ^ ": graph states (P22's committed pin, re-measured - graphs are \
      FAMILY-BLIND, so a move here is a phase-STOP)")
    states (states_of r);
  Alcotest.(check int) (label ^ ": family gate (leg-COMPUTED union)") gate
    (gate_of r);
  Alcotest.(check int) (label ^ ": L1 interesting") l1 (fires reach l1_name);
  Alcotest.(check int) (label ^ ": L2 interesting") l2 (fires reach l2_name);
  Alcotest.(check int)
    (label ^ ": L1 red (a red is a FIDELITY finding, not noise)")
    P23_witness.binding_red_everywhere (reds reach l1_name);
  Alcotest.(check int)
    (label
   ^ ": L2 red - and note the CONTAINMENT: L2 implies L1, and \
      first_violated is first-in-list-order, so a shared-conjunct red would \
      name L1 and leave L2 apparently green. These are REPLICA counts, not \
      the leg's violated name.")
    P23_witness.binding_red_everywhere (reds reach l2_name)

(* ==== family shape ========================================================= *)

let test_family_shape () =
  Alcotest.(check (list string))
    "binding_family = the two upstream names, in member order L1, L2"
    [ l1_name; l2_name ]
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.name) family);
  Alcotest.(check (list string))
    "member sources = binding_sources, same order (the .mli's exposed literals)"
    Lb.binding_sources
    (List.map (fun (i : Invariants.invariant) -> i.Invariants.source) family);
  Alcotest.(check int) "binding_family cardinal" P23_witness.binding_cardinal
    (List.length family)

(* ==== PIN SAFETY: the five INHERITED P13-P21 graphs, re-EXPLORED =========== *)

let test_pin_safety () =
  (* P22's four graphs are re-asserted inside the leg rows below (BL0/BLc/BLd/
     BLm reuse them exactly). This case covers the OTHER five, including the
     [vct:true] L0v graph no P23 leg runs. A moved pin is a STOP, never a
     retune. *)
  Alcotest.(check int) "pin safety L0 = 76" P23_witness.l0_states
    (Mc.states_seen
       (inherited_reach ~req_drop:false ~pod_monkey:false ~vct:false
          P21_witness.zero_budget));
  Alcotest.(check int) "pin safety Lc = 464" P23_witness.lc_states
    (Mc.states_seen
       (inherited_reach ~req_drop:false ~pod_monkey:false ~vct:false
          P21_witness.lc_budget));
  Alcotest.(check int) "pin safety Ld = 744" P23_witness.ld_states
    (Mc.states_seen
       (inherited_reach ~req_drop:true ~pod_monkey:false ~vct:false
          P21_witness.ld_budget));
  Alcotest.(check int) "pin safety Lm = 1976" P23_witness.lm_states
    (Mc.states_seen
       (inherited_reach ~req_drop:false ~pod_monkey:true ~vct:false
          P21_witness.lm_budget));
  Alcotest.(check int) "pin safety L0v = 116 (vct:true, replica only)"
    P23_witness.l0v_states
    (Mc.states_seen
       (inherited_reach ~req_drop:false ~pod_monkey:false ~vct:true
          P21_witness.zero_budget))

(* ==== the four legs ======================================================== *)

let test_bl0 () =
  check_green_leg "BL0" (Lazy.force bl0) (Lazy.force bl0_reach)
    ~states:P23_witness.bl0_states ~gate:P23_witness.bl0_gate_states
    ~l1:P23_witness.l1_interesting_bl0 ~l2:P23_witness.l2_interesting_bl0

let test_blc () =
  check_green_leg "BLc" (Lazy.force blc) (Lazy.force blc_reach)
    ~states:P23_witness.blc_states ~gate:P23_witness.blc_gate_states
    ~l1:P23_witness.l1_interesting_blc ~l2:P23_witness.l2_interesting_blc

let test_bld () =
  check_green_leg "BLd" (Lazy.force bld) (Lazy.force bld_reach)
    ~states:P23_witness.bld_states ~gate:P23_witness.bld_gate_states
    ~l1:P23_witness.l1_interesting_bld ~l2:P23_witness.l2_interesting_bld

let test_blm () =
  check_green_leg "BLm" (Lazy.force blm) (Lazy.force blm_reach)
    ~states:P23_witness.blm_states ~gate:P23_witness.blm_gate_states
    ~l1:P23_witness.l1_interesting_blm ~l2:P23_witness.l2_interesting_blm

(* ==== the premise-side counters, gathered per graph ========================
   The row shape of BUILD-SPEC-P23 section 8.1's second table. Each row asserts
   the SEMANTIC facts first (the reconcile is present somewhere; decode never
   failed; the parked chain does not shrink) and only then the exact counts. *)

let rows : (string * Fc.faulted Mc.reachable Lazy.t) list =
  [ ("BL0", bl0_reach); ("BLc", blc_reach); ("BLd", bld_reach); ("BLm", blm_reach) ]

let check_premises (label : string) (reach : Fc.faulted Mc.reachable)
    ~(dec : int) ~(needed : int) ~(condemned : int) ~(parked_n : int)
    ~(pod_list : int) ~(l2 : int) : unit =
  (* SEMANTIC first: the decode arm is never taken, stated from BOTH sides. *)
  Alcotest.(check int)
    (label
   ^ ": decode FAILURES = 0 (prediction 4) - the ~undecodable fold arm of \
      Local_binding.at_reconcile is NEVER exercised, which is what makes \
      matrix row MB6 a control rather than a formality")
    P23_witness.decode_failures_everywhere
    (count reach decode_failed);
  Alcotest.(check int)
    (label
   ^ ": every state whose reconcile EXISTS also DECODES (the same 0 read \
      from the other side)")
    (count reach has_reconcile) (count reach decoded);
  Alcotest.(check bool)
    (label ^ ": the reconcile at the CR key is present somewhere (premise floor)")
    true
    (count reach has_reconcile > 0);
  (* the parked chain cannot shrink: pod-list-parked <= with-pending <= parked *)
  Alcotest.(check bool)
    (label ^ ": parked-with-pending <= parked at After_list_pod") true
    (count reach parked_with_pending <= count reach parked);
  Alcotest.(check bool)
    (label ^ ": pending-IS-the-pod-list <= parked-with-pending") true
    (count reach parked_pod_list <= count reach parked_with_pending);
  (* exact MEASURED pins LAST *)
  Alcotest.(check int) (label ^ ": decoded ongoing states") dec
    (count reach decoded);
  Alcotest.(check int)
    (label
   ^ ": needed slot Some - PREDICTION 5 REFUTED (it said EXACTLY 0; the port \
      RE-RECONCILES, so pod-0 created in one round lands in the needed slot \
      in a later one). C1 ships as written: no exclusion, no pin.")
    needed (count reach needed_witness);
  Alcotest.(check int)
    (label ^ ": condemned non-empty (prediction 5's second half, CONFIRMED)")
    condemned
    (count reach condemned_witness);
  Alcotest.(check int) (label ^ ": states at After_list_pod") parked_n
    (count reach parked);
  Alcotest.(check int)
    (label
   ^ ": ...whose pending request IS the pod ListRequest in the CR's \
      namespace, addressed to the api server (upstream :646-651)")
    pod_list
    (count reach parked_pod_list);
  (* THE COINCIDENCE IS THE CONTENT (section 8.5's first supporting row):
     upstream :646-651 is not a filter that happens to pass - it holds at 100
     percent of the states where it CAN, and L2's own [interesting] agrees with
     the test-side projection, which is what pins the duplicate-and-pin block
     above against the shipped member. *)
  Alcotest.(check int)
    (label
   ^ ": parked-with-pending = the pod-list count - :646-651 is exercised at \
      100 PERCENT of the states where it can be")
    (count reach parked_pod_list)
    (count reach parked_with_pending);
  Alcotest.(check int)
    (label
   ^ ": L2's own interesting = the test-side parked-with-pending projection \
      (the duplicate-and-pin agreement)")
    l2
    (count reach parked_with_pending)

let test_premise_counters () =
  check_premises "BL0" (Lazy.force bl0_reach) ~dec:P23_witness.decoded_bl0
    ~needed:P23_witness.needed_witness_bl0
    ~condemned:P23_witness.condemned_witness_bl0 ~parked_n:P23_witness.parked_bl0
    ~pod_list:P23_witness.parked_pod_list_bl0 ~l2:P23_witness.l2_interesting_bl0;
  check_premises "BLc" (Lazy.force blc_reach) ~dec:P23_witness.decoded_blc
    ~needed:P23_witness.needed_witness_blc
    ~condemned:P23_witness.condemned_witness_blc ~parked_n:P23_witness.parked_blc
    ~pod_list:P23_witness.parked_pod_list_blc ~l2:P23_witness.l2_interesting_blc;
  check_premises "BLd" (Lazy.force bld_reach) ~dec:P23_witness.decoded_bld
    ~needed:P23_witness.needed_witness_bld
    ~condemned:P23_witness.condemned_witness_bld ~parked_n:P23_witness.parked_bld
    ~pod_list:P23_witness.parked_pod_list_bld ~l2:P23_witness.l2_interesting_bld;
  check_premises "BLm" (Lazy.force blm_reach) ~dec:P23_witness.decoded_blm
    ~needed:P23_witness.needed_witness_blm
    ~condemned:P23_witness.condemned_witness_blm ~parked_n:P23_witness.parked_blm
    ~pod_list:P23_witness.parked_pod_list_blm ~l2:P23_witness.l2_interesting_blm

(* ==== THE PVCS-EXCLUSION PIN (section 8.6) =================================
   Upstream's pvcs forall :629-637 is NOT ported. This is what makes the
   omission BEHAVIOR-FREE rather than merely undone: on every P23 graph, every
   decoded ongoing state has [pvcs = []]. Asserted against a NON-ZERO decoded
   count on the same graph, so the pin cannot pass for want of decoded states.
   Its RED capability is measured in t_p23_mutation (row MB7). *)

let test_pvcs_exclusion_pin () =
  List.iter
    (fun ((label, reach) : string * Fc.faulted Mc.reachable Lazy.t) ->
      let r = Lazy.force reach in
      Alcotest.(check bool)
        (label
       ^ ": the pin is not vacuous for want of decoded states (decoded > 0)")
        true
        (count r decoded > 0);
      Alcotest.(check int)
        (label
       ^ ": NO decoded ongoing state has a PVC - the excluded :629-637 forall \
          is behavior-free; the moment a vct:true leg lands this reddens")
        P23_witness.pvcs_non_empty_everywhere
        (count r pvcs_non_empty))
    rows

(* ==== L2'S INNER FORALL: LIVE, not assumed (section 8.5, prediction 6) ===== *)

let test_inner_premise () =
  List.iter
    (fun ((label, reach, pin) :
           string * Fc.faulted Mc.reachable Lazy.t * int) ->
      let r = Lazy.force reach in
      Alcotest.(check bool)
        (label
       ^ ": L2's inner ok-List-response premise FIRES (prediction 6 was \
          UNVERIFIED in the tree and is CONFIRMED on every graph; a 0 would \
          have meant the whole :652-662 conjunct sleeps)")
        true
        (count r ok_resp_in_flight > 0);
      Alcotest.(check bool)
        (label ^ ": inner premise <= parked-with-pending (it is a subset)") true
        (count r ok_resp_in_flight <= count r parked_with_pending);
      Alcotest.(check int)
        (label ^ ": states with a matching ok List_response in flight") pin
        (count r ok_resp_in_flight))
    [
      ("BL0", bl0_reach, P23_witness.ok_list_resps_bl0);
      ("BLc", blc_reach, P23_witness.ok_list_resps_blc);
      ("BLd", bld_reach, P23_witness.ok_list_resps_bld);
      ("BLm", blm_reach, P23_witness.ok_list_resps_blm);
    ];
  (* "the premise fires" is weaker than "the body is evaluated": on BL0 every
     one of the 8 responses carries a NON-EMPTY objs list, so :659-661 is
     applied to real objects rather than folding over an empty list. *)
  let r0 = Lazy.force bl0_reach in
  Alcotest.(check int)
    "BL0: responses carrying OBJECTS - :659-661 is applied to real objects, \
     not folded over an empty list"
    P23_witness.bl0_ok_list_resps_with_objs
    (count r0 ok_resp_with_objs);
  Alcotest.(check int)
    "BL0: every one of the premise states carries objects (the two counts \
     coincide - no state fires the premise on an empty response)"
    (count r0 ok_resp_in_flight)
    (count r0 ok_resp_with_objs)

(* ==== PREDICTION 5's REFUTATION AND ITS MEASURED MECHANISM (section 8.3) ===
   Recorded as a test rather than as prose, because "the port re-reconciles" is
   the kind of claim that decays into folklore. On BL0: every needed-witness
   state has pod-0 IN ETCD and NONE lacks it - the round-to-round mechanism and
   no other. The 36 states holding pod-0 with the slot still [None] are the ones
   inside the round that created it, which is precisely the half of the spec's
   section 2.1 argument that IS true. *)

let test_needed_non_vacuity () =
  let r = Lazy.force bl0_reach in
  Alcotest.(check bool)
    "BL0: L1's needed conjunct is NOT vacuous - prediction 5 said EXACTLY 0"
    true
    (count r needed_witness > 0);
  Alcotest.(check int) "BL0: needed slot Some" P23_witness.needed_witness_bl0
    (count r needed_witness);
  (* THE PARTITION FRAME, and why it is READ OFF THE GRAPH. The three exact
     pins below split the pod-0-in-etcd states into a needed-witness bucket and
     its complement. Stating that split as arithmetic over the three CONSTANTS
     alone (64 = 20 + 44) asserts nothing whatever: it is true by arithmetic
     for any graph, and it survives the exact drift it would claim to prevent -
     a coordinated retune of 64 / 20 / 44 to 70 / 22 / 48 keeps it green.
     Summed against [count r pod0_in_etcd] it has teeth: the same coordinated
     retune leaves 22 + 48 beside the 64 the GRAPH reports and REDDENS here. *)
  Alcotest.(check int)
    "BL0: the pod-0-in-etcd states really DO split into the needed-witness \
     bucket and its complement - the two component pins SUMMED and read \
     against the GRAPH's own pod-0 count, so a retune of the two cannot agree \
     with each other instead of with the states"
    (P23_witness.bl0_needed_witness_with_pod0
   + P23_witness.bl0_pod0_in_etcd_no_witness)
    (count r pod0_in_etcd);
  Alcotest.(check int)
    "BL0: needed-witness states that ALSO have pod-0 in etcd - the \
     re-reconcile mechanism"
    P23_witness.bl0_needed_witness_with_pod0
    (count r (fun (s : Cluster.cluster_state) ->
         needed_witness s && pod0_in_etcd s));
  Alcotest.(check int)
    "BL0: needed-witness states WITHOUT pod-0 in etcd - zero, so the \
     mechanism is round-to-round and no other"
    P23_witness.bl0_needed_witness_without_pod0
    (count r (fun (s : Cluster.cluster_state) ->
         needed_witness s && not (pod0_in_etcd s)));
  Alcotest.(check int) "BL0: pod-0 in etcd, all states"
    P23_witness.bl0_pod0_in_etcd
    (count r pod0_in_etcd);
  (* TWO readings of "pod-0 stored but the slot is still None", pinned
     separately because they are two predicates and BUILD-SPEC-P23 section 8.3
     prints numbers that cannot both belong to one of them (64 - 20 = 44, and
     the section prints 36). The wide one is the arithmetic complement; the
     narrow one - a decoded, NON-EMPTY needed list all of whose slots are
     [None] - is the states INSIDE the round that created pod-0, and it
     reproduces the printed 36. The gap is the states with no decoded needed
     list to have a slot at all. *)
  Alcotest.(check int)
    "BL0: pod-0 stored and L1's needed witness does NOT fire - the arithmetic \
     complement of the 20 (and the row where section 8.3's printed 36 does \
     not fit: 64 - 20 = 44)"
    P23_witness.bl0_pod0_in_etcd_no_witness
    (count r (fun (s : Cluster.cluster_state) ->
         pod0_in_etcd s && not (needed_witness s)));
  Alcotest.(check int)
    "BL0: pod-0 stored, the reconcile EXISTS and DECODES, and the needed \
     witness still does not fire - the states INSIDE the round that created \
     it (the half of the spec's section 2.1 argument that IS true), and the \
     reading that reproduces section 8.3's printed 36"
    P23_witness.bl0_pod0_in_etcd_decoded_no_witness
    (count r (fun (s : Cluster.cluster_state) ->
         pod0_in_etcd s && decoded s && not (needed_witness s)));
  Alcotest.(check int)
    "BL0: ...and the STRICTEST reading - decoded, needed list NON-EMPTY, every \
     slot None - is smaller again; the gap is the decoded states whose needed \
     list is still [] because the round has not partitioned yet"
    P23_witness.bl0_pod0_in_etcd_needed_slot_none
    (count r (fun (s : Cluster.cluster_state) ->
         pod0_in_etcd s && needed_slot_all_none s));
  Alcotest.(check int)
    "BL0: condemned witness (prediction 5's second half, CONFIRMED)"
    P23_witness.condemned_witness_bl0
    (count r condemned_witness)

(* ==== THE BL0 GATE DECOMPOSITION (section 8.1) =============================
   The leg-computed gate is the UNION of the two members' premises. On BL0 the
   two are DISJOINT and the gate is a clean sum: at [After_list_pod] the
   partition has not run yet, so [needed] and [condemned] are both empty and
   L1's witness is false exactly where L2's is true. NEITHER MEMBER DOMINATES -
   the P23 analogue of P21's "G1 dominates the union gate" disclosure, with the
   opposite verdict. The disjointness is a BL0 fact ONLY: the assertion below
   deliberately does NOT claim it on the fault graphs, where the union is
   strictly smaller than the sum. *)

let test_bl0_gate_decomposition () =
  let r = Lazy.force bl0_reach in
  let l1_only =
    count r (fun (s : Cluster.cluster_state) ->
        member_interesting family l1_name s
        && not (member_interesting family l2_name s))
  in
  let l2_only =
    count r (fun (s : Cluster.cluster_state) ->
        member_interesting family l2_name s
        && not (member_interesting family l1_name s))
  in
  let both =
    count r (fun (s : Cluster.cluster_state) ->
        member_interesting family l1_name s && member_interesting family l2_name s)
  in
  Alcotest.(check int) "BL0: L1-only states" P23_witness.bl0_gate_l1_only l1_only;
  Alcotest.(check int) "BL0: L2-only states" P23_witness.bl0_gate_l2_only l2_only;
  Alcotest.(check int)
    "BL0: states where BOTH premises fire - ZERO, the two premises are \
     DISJOINT on this graph"
    P23_witness.bl0_gate_both both;
  Alcotest.(check int)
    "BL0: the decomposition sums to the leg's OWN gate_states (the union gate \
     is a clean sum here, and neither member dominates)"
    (gate_of (Lazy.force bl0))
    (l1_only + l2_only + both);
  Alcotest.(check int) "BL0: and that gate is the committed pin"
    P23_witness.bl0_gate_states
    (gate_of (Lazy.force bl0))

let () =
  Alcotest.run "p23_local_binding"
    [
      ( "family_shape",
        [
          Alcotest.test_case
            "binding_family = L1 :613 / L2 :640, sources = binding_sources, \
             cardinal 2"
            `Quick test_family_shape;
        ] );
      ( "pin_safety",
        [
          Alcotest.test_case
            "the five INHERITED P13-P21 graph pins survive the new leg \
             (graphs are FAMILY-BLIND)"
            `Quick test_pin_safety;
        ] );
      ( "legs",
        [
          Alcotest.test_case
            "BL0: zero-budget - GREEN, both premises live (THE PHASE GATE)"
            `Quick test_bl0;
          Alcotest.test_case "BLc: crash-only - GREEN, both premises live"
            `Quick test_blc;
          Alcotest.test_case "BLd: drop-only - GREEN, both premises live" `Quick
            test_bld;
          Alcotest.test_case "BLm: monkey-only - GREEN, both premises live"
            `Quick test_blm;
        ] );
      ( "premise_counters",
        [
          Alcotest.test_case
            "decode failures 0, decoded / needed / condemned / parked / \
             pod-list counts on all four graphs"
            `Quick test_premise_counters;
        ] );
      ( "pvcs_exclusion_pin",
        [
          Alcotest.test_case
            "NO decoded ongoing state has a PVC on any P23 graph - the \
             excluded :629-637 forall is behavior-free"
            `Quick test_pvcs_exclusion_pin;
        ] );
      ( "inner_premise",
        [
          Alcotest.test_case
            "L2's inner ok-List-response quantifier is LIVE on every graph \
             (prediction 6 CONFIRMED), and its responses carry objects"
            `Quick test_inner_premise;
        ] );
      ( "needed_non_vacuity",
        [
          Alcotest.test_case
            "PREDICTION 5 REFUTED: L1's needed conjunct fires, and the \
             mechanism is the port RE-RECONCILING (pod-0 in etcd)"
            `Quick test_needed_non_vacuity;
        ] );
      ( "gate_decomposition",
        [
          Alcotest.test_case
            "BL0: L1-only 52 + L2-only 16 + both 0 = the leg's own gate 68 \
             (disjoint premises, neither member dominates)"
            `Quick test_bl0_gate_decomposition;
        ] );
    ]

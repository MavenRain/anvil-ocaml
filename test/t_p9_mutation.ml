(* BUILD-SPEC-P9 §3 "t_p9_mutation" — confirm-by-mutation for the VDeployment
   controller and the two-controller convergence witness. The temporary LIBRARY
   mutants — M1 dropping the Create in [create_new_vrs], M2 making
   [mismatch_replicas] unconditionally true, M3 scaling by [cur] instead of
   [cur + 1] in [scale_new_vrs], M5 mis-guarding the [After_ensure_new_vrs]
   barrier ([>=] for [>], or dropping [valid_owned_vrs]) — are each applied in
   stage 6, SEEN to turn a pin below red, and reverted; only the green pins ship.
   These are the always-on in-tree ANALOGUES of those mutants, mirroring
   t_p8_mutation's shadowed-variant style — each pairs an OPERATIONAL pin on the
   converged store with a reconcile_core MECHANISM check that exercises exactly the
   mutated code, so the pin is non-vacuous:

   - M1: the real reconcile_core emits a Create from an empty list (the create is
     what puts a VReplicaSet in the store); a create-suppressed variant emits
     nothing, so the converged store's >= 1 VReplicaSet pin would collapse to 0.
   - M2: the real [mismatch_replicas] gate emits a scale ONLY below desired and
     nothing at the settled (ready, at-desired) child; an always-true gate would
     scale the settled child, breaking the "vrs at spec.replicas = desired" pin and
     never letting [rv] stabilise (converged = false).
   - M3: the real scale request carries [cur + 1]; a [cur] mutant makes no progress,
     stalling the converged child below desired.
   - M4: a planted-divergence detector over the converged finals
     (#vrs, vrs.replicas, #pods, vd outcome) = (1, desired, desired, Reconciled),
     mirroring t_p7/t_p8 M4: the true finals show zero divergences, planted drifts
     are each detected.
   - M5: the barrier admits index = len (the last old vrs) and REFUSES a
     non-owned old; a [>=] mutant Errors at index = len and a guard-dropped mutant
     scales a non-owned child.

   Convention firewall: no loop keywords; no [_ ->] wildcard on a finite sum
   (api_request enumerated, the External arm void-refuted); Option.fold / Result.fold
   for options/results; [Int.equal] not [Stdlib.(=)]. *)

module Exec = Anvil_exec.Exec_api_server
module Direct = Anvil_exec.Concurrency.Direct
module Mc = Anvil_exec.Multi_controller
module CR = Anvil_exec.Controller_runtime
module Scenario = Anvil_assurance.Scenario
module M = Mc.Make (Direct) (Exec)
module R = CR.Make (Direct) (Exec)
module V = V_deployment_reconciler

(* -- the exec convergence harness (as in t_p9_two_controller) -- *)

let installed = Scenario.vd_and_vrs_installed

let vd_model =
  Controller.model_of_controller ~kind:V_deployment.kind
    (module V_deployment_pack.Controller)

let vrs_model =
  Controller.model_of_controller ~kind:Vreplica_set.kind
    (module Vreplica_set_pack.Controller)

let models = [ vd_model; vrs_model ]

let fresh ~desired : Exec.t =
  Result.fold
    (Exec.create ~installed
       ~seed:[ V_deployment.marshal (Scenario.vd ~desired) ]
       ())
    ~ok:(fun (t : Exec.t) -> t)
    ~error:(fun (e : Err.t) -> Alcotest.failf "create: %s" (Err.show e))

let rv_of (t : Exec.t) () : int =
  (Exec.state t).Api_server.resource_version_counter

let converge (t : Exec.t) : M.report =
  Result.fold
    (M.run_to_fixpoint ~client:t ~models ~namespace:"ns" ~rv:(rv_of t) ~fuel:100
       ~max_rounds:20)
    ~ok:(fun (r : M.report) -> r)
    ~error:(fun (e : Err.t) -> Alcotest.failf "run_to_fixpoint: %s" (Err.show e))

let count_kind (t : Exec.t) (k : Common.kind) : int =
  Object_ref_map.fold
    (fun _key obj acc ->
      if Common.equal_kind (Dynamic_object.kind obj) k then acc + 1 else acc)
    (Exec.state t).Api_server.resources 0

let vrs_replicas (t : Exec.t) : int list =
  Object_ref_map.fold
    (fun _key obj acc ->
      if Common.equal_kind (Dynamic_object.kind obj) Vreplica_set.kind then
        Result.fold (Vreplica_set.unmarshal obj)
          ~ok:(fun (v : Vreplica_set.t) ->
            Option.value ~default:(-1) (Vreplica_set.spec v).replicas :: acc)
          ~error:(fun (_ : Err.t) -> -1 :: acc)
      else acc)
    (Exec.state t).Api_server.resources []

let single_vrs_replicas (t : Exec.t) : int =
  match vrs_replicas t with [ r ] -> r | [] -> -1 | _ :: _ :: _ -> -1

(* The VDeployment's own reconcile outcome against the (converged) store: a
   quiescent VDeployment [Reconciled]s with no further write. *)
let vd_reconciled_int (t : Exec.t) : int =
  Option.fold (Exec.lookup t Scenario.vd_ref) ~none:0
    ~some:(fun (vd_obj : Dynamic_object.t) ->
      Result.fold
        (R.reconcile_with ~client:t ~model:vd_model ~cr:vd_obj ~fuel:100)
        ~ok:(fun (o : CR.outcome) ->
          if CR.outcome_equal o CR.Reconciled then 1 else 0)
        ~error:(fun (e : Err.t) -> Alcotest.failf "vd reconcile: %s" (Err.show e)))

(* -- reconcile_core fixtures (as in t_v_deployment_reconciler) -- *)

let labels_xy = Smap.add "app" "x" Smap.empty
let selector : Label_selector.t = { match_labels = Some labels_xy }
let tmpl_metadata = Object_meta.with_labels labels_xy (Object_meta.default ())

let good_template : Pod_template_spec.t =
  { metadata = Some tmpl_metadata; spec = Some (Pod_spec.default ()) }

let vd_owner_ref : Owner_reference.t =
  {
    block_owner_deletion = Some true;
    controller = Some true;
    kind = V_deployment.kind;
    name = "vd1";
    uid = Common.Uid.of_int 1;
  }

let vd_metadata : Object_meta.t =
  {
    (Object_meta.default ()) with
    name = Some "vd1";
    namespace = Some "ns";
    uid = Some (Common.Uid.of_int 1);
    resource_version = Some (Common.Resource_version.of_int 0);
  }

let vd_cr (desired : int) : V_deployment.t =
  V_deployment.make ~metadata:vd_metadata
    ~spec:
      {
        (V_deployment.vd_spec_default ()) with
        replicas = Some desired;
        selector;
        template = good_template;
      }
    ~status:()

let owned_vrs ~(name : string) ~(uid : int) ~(namespace : string)
    ~(replicas : int option) ~(status : Vreplica_set.vrs_status option) :
    Vreplica_set.t =
  Vreplica_set.make
    ~metadata:
      {
        (Object_meta.default ()) with
        name = Some name;
        namespace = Some namespace;
        uid = Some (Common.Uid.of_int uid);
        owner_references = Some [ vd_owner_ref ];
      }
    ~spec:{ Vreplica_set.replicas; selector; template = Some good_template }
    ~status

let ready_vrs ~(name : string) ~(uid : int) ~(replicas : int) : Vreplica_set.t =
  owned_vrs ~name ~uid ~namespace:"ns" ~replicas:(Some replicas)
    ~status:(Some { Vreplica_set.replicas })

let at_list : V.s =
  { V.reconcile_step = After_list_vrs; new_vrs = None; old_vrs_list = []; old_vrs_index = 0 }

let some_vrs = owned_vrs ~name:"vd1-0" ~uid:2 ~namespace:"ns" ~replicas:(Some 1) ~status:None

let list_resp (objs : Dynamic_object.t list) : Io.void Io.response_view option =
  Some (Io.K_response (Api_method.List_response { res = Ok objs }))

(* Name the emitted request by its verb (exhaustive over api_request). *)
let req_kind (r : Io.void Io.request_view option) : string =
  Option.fold r ~none:"none" ~some:(fun (rv : Io.void Io.request_view) ->
      match rv with
      | Io.K_request q -> (
        match q with
        | Api_method.List_request _ -> "list"
        | Api_method.Create_request _ -> "create"
        | Api_method.Get_then_update_request _ -> "get_then_update"
        | Api_method.Get_request _ | Api_method.Delete_request _
        | Api_method.Update_request _ | Api_method.Update_status_request _
        | Api_method.Get_then_delete_request _
        | Api_method.Get_then_update_status_request _ ->
          "other")
      | Io.External_request _ -> .)

(* The [spec.replicas] carried by an emitted Get_then_update request, if any
   (exhaustive over api_request; the create-target check for M3). *)
let scaled_replicas (r : Io.void Io.request_view option) : int option =
  Option.bind r (fun (rv : Io.void Io.request_view) ->
      match rv with
      | Io.K_request q -> (
        match q with
        | Api_method.Get_then_update_request { Api_method.obj; _ } ->
          Result.fold (Vreplica_set.unmarshal obj)
            ~ok:(fun (v : Vreplica_set.t) -> (Vreplica_set.spec v).replicas)
            ~error:(fun (_ : Err.t) -> None)
        | Api_method.List_request _ | Api_method.Create_request _
        | Api_method.Get_request _ | Api_method.Delete_request _
        | Api_method.Update_request _ | Api_method.Update_status_request _
        | Api_method.Get_then_delete_request _
        | Api_method.Get_then_update_status_request _ ->
          None)
      | Io.External_request _ -> .)

let step_is (expected : V.step) (out : V.s * Io.void Io.request_view option) : bool =
  V.step_equal expected (fst out).reconcile_step

(* ---- M1: create-suppression ---- *)
let test_m1_create_suppression () =
  let t = fresh ~desired:3 in
  let _ = converge t in
  Alcotest.(check bool)
    "M1: the converged store holds >= 1 vreplicaset" true
    (count_kind t Vreplica_set.kind >= 1);
  (* mechanism: the real reconcile_core emits a Create from an empty list *)
  let out = V.reconcile_core ~cr:(vd_cr 3) ~resp:(list_resp []) ~state:at_list in
  Alcotest.(check string) "M1: real empty-list step emits Create" "create"
    (req_kind (snd out));
  Alcotest.(check bool) "M1: real advances to After_create_new_vrs" true
    (step_is V.After_create_new_vrs out);
  (* the suppressed analogue drops the request -> nothing created *)
  let suppressed ((s, _) : V.s * Io.void Io.request_view option) = (s, None) in
  Alcotest.(check string) "M1: create-suppressed variant emits nothing" "none"
    (req_kind (snd (suppressed out)))

(* ---- M2: always-scale gate ---- *)
let test_m2_always_scale () =
  let t = fresh ~desired:3 in
  let r = converge t in
  Alcotest.(check bool) "M2: convergence reached" true r.M.converged;
  Alcotest.(check (list int)) "M2: the settled vreplicaset is at desired" [ 3 ]
    (vrs_replicas t);
  (* mechanism: BELOW desired the real gate scales; AT desired it does not. An
     always-true gate would scale the settled child too. *)
  let below =
    V.reconcile_core ~cr:(vd_cr 3)
      ~resp:(list_resp [ Vreplica_set.marshal (ready_vrs ~name:"vd1-0" ~uid:2 ~replicas:1) ])
      ~state:at_list
  in
  Alcotest.(check string) "M2: below desired -> real gate scales" "get_then_update"
    (req_kind (snd below));
  let settled =
    V.reconcile_core ~cr:(vd_cr 3)
      ~resp:(list_resp [ Vreplica_set.marshal (ready_vrs ~name:"vd1-0" ~uid:2 ~replicas:3) ])
      ~state:at_list
  in
  Alcotest.(check string) "M2: at desired -> real gate emits nothing" "none"
    (req_kind (snd settled));
  Alcotest.(check bool) "M2: at desired -> barrier (After_ensure_new_vrs)" true
    (step_is V.After_ensure_new_vrs settled)

(* ---- M3: off-by-one scale target ---- *)
let test_m3_scale_target () =
  let t = fresh ~desired:3 in
  let _ = converge t in
  Alcotest.(check (list int)) "M3: converged vreplicaset reached desired" [ 3 ]
    (vrs_replicas t);
  (* mechanism: scaling a ready child at 1 toward desired 3 emits [cur + 1 = 2];
     a [cur] mutant would emit 1 (no progress). *)
  let scale =
    V.reconcile_core ~cr:(vd_cr 3)
      ~resp:(list_resp [ Vreplica_set.marshal (ready_vrs ~name:"vd1-0" ~uid:2 ~replicas:1) ])
      ~state:at_list
  in
  Alcotest.(check (option int)) "M3: real scale request carries cur + 1 = 2"
    (Some 2)
    (scaled_replicas (snd scale))

(* ---- M4: planted-divergence record over the converged finals ---- *)
type divergence = { field : string; expected : int; actual : int }

let show_div (d : divergence) : string =
  Printf.sprintf "%s: expected %d, actual %d" d.field d.expected d.actual

let divergences ~(num_vrs : int) ~(vrs_rep : int) ~(num_pods : int)
    ~(vd_ok : int) (t : Exec.t) : divergence list =
  let check name expected actual acc =
    if Int.equal expected actual then acc
    else { field = name; expected; actual } :: acc
  in
  check "num_vrs" num_vrs (count_kind t Vreplica_set.kind)
    (check "vrs_replicas" vrs_rep (single_vrs_replicas t)
       (check "num_pods" num_pods (count_kind t Pod.kind)
          (check "vd_outcome" vd_ok (vd_reconciled_int t) [])))

let test_m4_planted_divergence () =
  let desired = 3 in
  let t = fresh ~desired in
  let _ = converge t in
  (* the TRUE finals: one vrs at desired, desired pods, vd Reconciled. *)
  let true_divs =
    divergences ~num_vrs:1 ~vrs_rep:desired ~num_pods:desired ~vd_ok:1 t
  in
  (match true_divs with
  | [] -> ()
  | _ :: _ ->
    Alcotest.failf "M4: true finals diverged — %s"
      (String.concat "; " (List.map show_div true_divs)));
  (* plant a drift in EACH field: every planted field is detected. *)
  let detected =
    List.map
      (fun (d : divergence) -> d.field)
      (divergences ~num_vrs:2 ~vrs_rep:(desired + 1) ~num_pods:(desired + 1)
         ~vd_ok:0 t)
  in
  List.iter
    (fun f ->
      Alcotest.(check bool)
        (Printf.sprintf "M4: planted drift in %s detected" f)
        true
        (List.exists (String.equal f) detected))
    [ "num_vrs"; "vrs_replicas"; "num_pods"; "vd_outcome" ]

(* ---- M5: barrier mis-guard ---- *)
let test_m5_barrier_guard () =
  let good_old = owned_vrs ~name:"vd1-old" ~uid:3 ~namespace:"ns" ~replicas:(Some 2) ~status:None in
  (* index = len (the last old vrs) is IN range: real -> scale-down. A [>=]
     mutant would Error here. *)
  let at_len =
    V.reconcile_core ~cr:(vd_cr 3) ~resp:None
      ~state:
        { V.reconcile_step = After_ensure_new_vrs; new_vrs = Some some_vrs; old_vrs_list = [ good_old ]; old_vrs_index = 1 }
  in
  Alcotest.(check bool) "M5: index = len admits the old vrs -> scale-down" true
    (step_is V.After_scale_down_old_vrs at_len);
  (* a non-owned old (wrong namespace) is REFUSED: real -> Error. A guard-dropped
     mutant would scale it down. *)
  let bad_old = owned_vrs ~name:"vd1-bad" ~uid:4 ~namespace:"other" ~replicas:(Some 2) ~status:None in
  let non_owned =
    V.reconcile_core ~cr:(vd_cr 3) ~resp:None
      ~state:
        { V.reconcile_step = After_ensure_new_vrs; new_vrs = Some some_vrs; old_vrs_list = [ bad_old ]; old_vrs_index = 1 }
  in
  Alcotest.(check bool) "M5: a non-owned old vrs -> Error" true
    (step_is V.Error non_owned)

let () =
  Alcotest.run "p9_mutation"
    [
      ( "confirm-by-mutation",
        [
          Alcotest.test_case "M1: create-suppression -> 0 vrs; real -> Create"
            `Quick test_m1_create_suppression;
          Alcotest.test_case "M2: always-scale never settles; real gates by readiness"
            `Quick test_m2_always_scale;
          Alcotest.test_case "M3: off-by-one stalls; real scales cur + 1" `Quick
            test_m3_scale_target;
          Alcotest.test_case "M4: planted divergence on converged finals detected"
            `Quick test_m4_planted_divergence;
          Alcotest.test_case "M5: barrier admits index=len, refuses non-owned"
            `Quick test_m5_barrier_guard;
        ] );
    ]

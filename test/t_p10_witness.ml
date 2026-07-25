(* Phase 10 VStatefulSet operational witness (t_p10_witness): the real
   Controller_runtime driving the erased VStatefulSet pack against a live
   in-memory api-server. Three end-to-end pins:

   - Converge: from the bare CR (desired 3, one volumeClaimTemplate) a single
     reconcile pass reaches [Reconciled] and the store holds exactly the three
     ordinal Pods AND the three per-ordinal PVCs (exact sorted name sets).
   - Rolling one-per-round: from an all-stale store (three original-template pods
     under a template-mutated CR), N reconcile passes each delete AT MOST one
     pod, at least one round deletes exactly one, and after enough rounds every
     stored pod matches the new template (the recreate-in-place semantics).
   - Scale-down: desired 1 with three pre-existing owned pods ends with exactly
     the ordinal-0 pod (ordinals 1 and 2 pruned).

   Drive mechanics: each logical step is a two-phase handoff (>= 2 transitions,
   one fuel unit each), so passes use [~fuel:2000]; a converged pass ends
   [Reconciled] and is NOT auto-requeued, so convergence is one [reconcile_with].

   Convention firewall: no loop keywords (List.init / List.map / fold); no
   [_ ->] wildcard on a finite sum; Option.fold / Result.fold. *)

module Exec = Anvil_exec.Exec_api_server
module Direct = Anvil_exec.Concurrency.Direct
module CR = Anvil_exec.Controller_runtime
module R = CR.Make (Direct) (Exec)
module Scenario = Anvil_assurance.Scenario
module Vr = V_stateful_set_reconciler

let model =
  Controller.model_of_controller ~kind:V_stateful_set.kind
    (module V_stateful_set_pack.Controller)

(* -- harness -- *)

let fresh (seed : Dynamic_object.t list) : Exec.t =
  Result.fold
    (Exec.create ~installed:Scenario.vsts_installed ~seed ())
    ~ok:(fun (t : Exec.t) -> t)
    ~error:(fun (e : Err.t) -> Alcotest.failf "create: %s" (Err.show e))

(* One reconcile pass over the CR currently in the store (re-fetched each call,
   as the drive mechanics require). *)
let reconcile_once (t : Exec.t) : CR.outcome =
  Option.fold
    (Exec.lookup t Scenario.vsts_ref)
    ~none:(fun () -> Alcotest.failf "vsts CR missing from store")
    ~some:(fun (cr_obj : Dynamic_object.t) () ->
      Result.fold
        (R.reconcile_with ~client:t ~model ~cr:cr_obj ~fuel:2000)
        ~ok:(fun (o : CR.outcome) -> o)
        ~error:(fun (e : Err.t) -> Alcotest.failf "reconcile_with: %s" (Err.show e)))
    ()

let is_reconciled (o : CR.outcome) : bool = CR.outcome_equal o CR.Reconciled

(* The CR as currently stored (its api-server-stamped uid), so pods seeded to be
   OWNED by it carry the exact owner_ref the reconciler's [controller_owner_ref]
   recomputes. *)
let stored_cr (t : Exec.t) : V_stateful_set.t =
  Option.fold
    (Exec.lookup t Scenario.vsts_ref)
    ~none:(fun () -> Alcotest.failf "vsts CR missing from store")
    ~some:(fun (obj : Dynamic_object.t) () ->
      Result.fold (V_stateful_set.unmarshal obj)
        ~ok:(fun (c : V_stateful_set.t) -> c)
        ~error:(fun (e : Err.t) -> Alcotest.failf "unmarshal stored CR: %s" (Err.show e)))
    ()

(* Create a pod into the store via a real CREATE in namespace "ns" (make_pod
   leaves namespace unset; the request re-stamps it). Returns success. *)
let create_pod (t : Exec.t) (pod : Pod.t) : bool =
  Result.fold
    (Exec.request t (Api_method.Create_request { Api_method.namespace = "ns"; obj = Pod.marshal pod }))
    ~ok:(fun (resp : Api_method.api_response) ->
      match resp with
      | Api_method.Create_response { res = Ok _ } -> true
      | Api_method.Create_response { res = Error _ }
      | Api_method.Get_response _ | Api_method.List_response _
      | Api_method.Delete_response _ | Api_method.Update_response _
      | Api_method.Update_status_response _ | Api_method.Get_then_delete_response _
      | Api_method.Get_then_update_response _
      | Api_method.Get_then_update_status_response _ ->
        false)
    ~error:(fun (_ : Err.t) -> false)

(* Human-readable outcome (exhaustive over the finite sum) for failure messages. *)
let outcome_str (o : CR.outcome) : string =
  match o with
  | CR.Reconciled -> "Reconciled"
  | CR.Errored -> "Errored"
  | CR.Incomplete n -> Printf.sprintf "Incomplete %d" n

(* -- store inspectors -- *)

let pod_name_of (obj : Dynamic_object.t) : string option =
  Result.fold (Pod.unmarshal obj)
    ~ok:(fun (p : Pod.t) -> Object_meta.name (Pod.metadata p))
    ~error:(fun (_ : Err.t) -> None)

let pvc_name_of (obj : Dynamic_object.t) : string option =
  Result.fold (Persistent_volume_claim.unmarshal obj)
    ~ok:(fun (p : Persistent_volume_claim.t) -> p.metadata.name)
    ~error:(fun (_ : Err.t) -> None)

let names_of_kind (t : Exec.t) (k : Common.kind)
    (name_of : Dynamic_object.t -> string option) : string list =
  Object_ref_map.fold
    (fun _key (obj : Dynamic_object.t) acc ->
      if Common.equal_kind (Dynamic_object.kind obj) k then
        Option.fold (name_of obj) ~none:acc ~some:(fun (n : string) -> n :: acc)
      else acc)
    (Exec.state t).Api_server.resources []
  |> List.sort String.compare

let pod_names (t : Exec.t) : string list = names_of_kind t Pod.kind pod_name_of
let pvc_names (t : Exec.t) : string list =
  names_of_kind t Persistent_volume_claim.kind pvc_name_of

(* -- 1. Converge -- *)

let test_converge () =
  let t = fresh [ V_stateful_set.marshal (Scenario.vsts ~desired:3 ~vct:true ()) ] in
  let outcome = reconcile_once t in
  Alcotest.(check bool)
    (Printf.sprintf "converge outcome is Reconciled (got %s)" (outcome_str outcome))
    true (is_reconciled outcome);
  let expected_pods =
    List.sort String.compare
      [ Vr.pod_name "vsts1" 0; Vr.pod_name "vsts1" 1; Vr.pod_name "vsts1" 2 ]
  in
  let expected_pvcs =
    List.sort String.compare
      [
        Vr.pvc_name "data" "vsts1" 0;
        Vr.pvc_name "data" "vsts1" 1;
        Vr.pvc_name "data" "vsts1" 2;
      ]
  in
  Alcotest.(check (list string)) "exactly the three ordinal pod names" expected_pods
    (pod_names t);
  Alcotest.(check (list string)) "exactly the three ordinal pvc names" expected_pvcs
    (pvc_names t)

(* -- 2. Rolling one-per-round -- *)

(* A CR whose pod template spec differs from the seeded pods' (a non-default
   service_account_name surviving [pod_spec_matches] normalization). *)
let mutate_template (cr : V_stateful_set.t) : V_stateful_set.t =
  {
    cr with
    spec =
      {
        cr.spec with
        template =
          {
            cr.spec.template with
            spec = Some { (Pod_spec.default ()) with service_account_name = Some "v2" };
          };
      };
  }

let all_pods_match (t : Exec.t) (cr : V_stateful_set.t) : bool =
  Object_ref_map.fold
    (fun _key (obj : Dynamic_object.t) acc ->
      if Common.equal_kind (Dynamic_object.kind obj) Pod.kind then
        acc
        && Result.fold (Pod.unmarshal obj)
             ~ok:(fun (p : Pod.t) -> Vr.pod_spec_matches cr p)
             ~error:(fun (_ : Err.t) -> false)
      else acc)
    (Exec.state t).Api_server.resources true

let test_rolling () =
  let orig = Scenario.vsts ~desired:3 () in
  let mutated = mutate_template orig in
  let t = fresh [ V_stateful_set.marshal mutated ] in
  (* three pre-existing owned pods carrying the STORED CR's identity (owner_ref)
     but the ORIGINAL (stale) template spec, so they mismatch [mutated] and each
     is a rolling-update candidate. *)
  let base =
    let sc = stored_cr t in
    { sc with spec = { sc.spec with template = orig.spec.template } }
  in
  let stale_pods = List.map (Vr.make_pod base) [ 0; 1; 2 ] in
  Alcotest.(check bool) "the three stale pods seed successfully" true
    (List.for_all (create_pod t) stale_pods);
  Alcotest.(check int) "the rolling store starts with three pods" 3
    (List.length (pod_names t));
  (* four rounds; record pods deleted per round via the name-set difference. *)
  let deletes =
    List.map
      (fun (_round : int) ->
        let before = pod_names t in
        let _ = reconcile_once t in
        let after = pod_names t in
        List.length (List.filter (fun (n : string) -> not (List.mem n after)) before))
      (List.init 4 Fun.id)
  in
  Alcotest.(check bool) "no round deletes more than one pod (one-per-round)" true
    (List.for_all (fun (d : int) -> d <= 1) deletes);
  Alcotest.(check bool) "at least one round deletes exactly one pod" true
    (List.exists (fun (d : int) -> Int.equal d 1) deletes);
  Alcotest.(check bool) "after four rounds every stored pod matches the new template"
    true (all_pods_match t mutated);
  Alcotest.(check int) "the rolling store still holds three pods" 3
    (List.length (pod_names t))

(* -- 3. Scale-down -- *)

let test_scale_down () =
  let t = fresh [ V_stateful_set.marshal (Scenario.vsts ~desired:1 ()) ] in
  (* three pre-existing owned pods (ordinals 0,1,2) at the stored CR's identity. *)
  let pods = List.map (Vr.make_pod (stored_cr t)) [ 0; 1; 2 ] in
  Alcotest.(check bool) "the three pods seed successfully" true
    (List.for_all (create_pod t) pods);
  let outcome = reconcile_once t in
  Alcotest.(check bool)
    (Printf.sprintf "scale-down outcome is Reconciled (got %s)" (outcome_str outcome))
    true (is_reconciled outcome);
  Alcotest.(check (list string)) "store ends with only the ordinal-0 pod"
    [ Vr.pod_name "vsts1" 0 ]
    (pod_names t)

let () =
  Alcotest.run "p10_witness"
    [
      ( "operational",
        [
          Alcotest.test_case "converge -> 3 pods + 3 pvcs, Reconciled" `Quick test_converge;
          Alcotest.test_case "rolling one pod deleted per round" `Quick test_rolling;
          Alcotest.test_case "scale-down 3 -> 1 keeps ordinal 0" `Quick test_scale_down;
        ] );
    ]

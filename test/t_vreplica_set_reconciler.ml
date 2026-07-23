(* VReplicaSet reconcile_core tests (BUILD-SPEC-P3 "## 8. Tests",
   t_vreplica_set_reconciler): the load-bearing suite. Every transition of the
   pure typed core is driven with hand-built inputs (Init -> list; scale-up;
   exact-count update; scale-down; create loop; delete loop; status update; done;
   error routing on wrong-kind / absent response; objects_to_pods on a non-pod;
   filter_pods / pod_matches exclusion). Confirm-by-mutation is applied to four
   guards out of band (see the stage report). *)

module V = Vreplica_set_reconciler

let labels_xy = Smap.add "app" "x" Smap.empty

(* The vrs's own controller owner reference (= [controller_owner_ref cr]): points
   at "vrs1"/uid 1 under the vreplicaset kind. Pods that this vrs owns carry it. *)
let vrs_self_ref : Owner_reference.t =
  {
    block_owner_deletion = Some true;
    controller = Some true;
    kind = Vreplica_set.kind;
    name = "vrs1";
    uid = Common.Uid.of_int 1;
  }

(* A distinct controller owner ref the vrs itself carries in its metadata (Anvil's
   update_vrs_replicas requires exactly one controller owner reference). *)
let parent_ref : Owner_reference.t =
  {
    block_owner_deletion = Some true;
    controller = Some true;
    kind = Common.Custom_resource "deployment";
    name = "parent";
    uid = Common.Uid.of_int 9;
  }

let cr_metadata : Object_meta.t =
  {
    (Object_meta.default ()) with
    name = Some "vrs1";
    namespace = Some "ns";
    uid = Some (Common.Uid.of_int 1);
    owner_references = Some [ parent_ref ];
  }

let cr_spec (replicas : int) : Vreplica_set.vrs_spec =
  Vreplica_set.vrs_spec_default ()
  |> Vreplica_set.spec_with_replicas replicas
  |> Vreplica_set.spec_with_selector { match_labels = Some labels_xy }
  |> Vreplica_set.spec_with_template
       { metadata = Some (Object_meta.default ()); spec = None }

let cr (replicas : int) : Vreplica_set.t =
  Vreplica_set.make ~metadata:cr_metadata ~spec:(cr_spec replicas) ~status:None

(* -- pod builders -- *)

let mk_pod ~(name : string) ~(owner : Owner_reference.t list option)
    ~(labels : string Smap.t option) ~(del : string option) : Pod.t =
  Pod.make
    ~metadata:
      {
        (Object_meta.default ()) with
        name = Some name;
        owner_references = owner;
        labels;
        deletion_timestamp = del;
      }
    ~spec:None ~status:None

let good_pod =
  mk_pod ~name:"vreplicaset-vrs1-a" ~owner:(Some [ vrs_self_ref ])
    ~labels:(Some labels_xy) ~del:None

let good_pod2 =
  mk_pod ~name:"vreplicaset-vrs1-b" ~owner:(Some [ vrs_self_ref ])
    ~labels:(Some labels_xy) ~del:None

(* -- helpers to inspect reconcile outputs -- *)

let step_of (s : V.s) : V.step = s.reconcile_step

let check_step (msg : string) (expected : V.step) (s : V.s) : unit =
  Alcotest.(check bool) msg true (V.step_equal expected (step_of s))

(* Name the emitted request by its Kubernetes verb (or "none" / "external"). *)
let req_kind (r : Io.void Io.request_view option) : string =
  Option.fold r ~none:"none" ~some:(fun (rv : Io.void Io.request_view) ->
      match rv with
      | Io.K_request q -> (
        match q with
        | Api_method.List_request _ -> "list"
        | Api_method.Create_request _ -> "create"
        | Api_method.Get_then_delete_request _ -> "get_then_delete"
        | Api_method.Get_then_update_status_request _ -> "get_then_update_status"
        | Api_method.Get_request _ | Api_method.Delete_request _
        | Api_method.Update_request _ | Api_method.Update_status_request _
        | Api_method.Get_then_update_request _ ->
          "other")
      | Io.External_request _ -> .)

let check_req (msg : string) (expected : string)
    (out : V.s * Io.void Io.request_view option) : unit =
  Alcotest.(check string) msg expected (req_kind (snd out))

(* -- response builders (K_response only; External_response is void) -- *)

let list_resp (objs : Dynamic_object.t list) : Io.void Io.response_view option =
  Some (Io.K_response (Api_method.List_response { res = Ok objs }))

let list_err : Io.void Io.response_view option =
  Some (Io.K_response (Api_method.List_response { res = Error Api_method.Internal_error }))

let create_resp : Io.void Io.response_view option =
  Some (Io.K_response (Api_method.Create_response { res = Ok (Pod.marshal good_pod) }))

let get_then_delete_resp : Io.void Io.response_view option =
  Some (Io.K_response (Api_method.Get_then_delete_response { res = Ok () }))

let get_then_update_status_resp : Io.void Io.response_view option =
  Some
    (Io.K_response
       (Api_method.Get_then_update_status_response { res = Ok (Pod.marshal good_pod) }))

let at_list = { V.reconcile_step = After_list_pods; filtered_pods = None }

(* ===== 1. Init + deletion_timestamp -> Done, no request ===== *)
let test_init_deleting () =
  let cr_del =
    Vreplica_set.with_metadata
      (Object_meta.with_deletion_timestamp "2024-01-01" cr_metadata)
      (cr 1)
  in
  let s', req = V.reconcile_core ~cr:cr_del ~resp:None ~state:(V.reconcile_init_state ()) in
  check_step "init+deletion -> Done" V.Done s';
  Alcotest.(check string) "no request emitted" "none" (req_kind req)

(* ===== 2. Init + no deletion -> After_list_pods + List_request ===== *)
let test_init_list () =
  let out = V.reconcile_core ~cr:(cr 1) ~resp:None ~state:(V.reconcile_init_state ()) in
  check_step "init -> After_list_pods" V.After_list_pods (fst out);
  check_req "init emits List_request" "list" out

(* ===== 3. After_list_pods + [] with desired 2 -> Create_request, After_create_pod 1 ===== *)
let test_scale_up () =
  let out = V.reconcile_core ~cr:(cr 2) ~resp:(list_resp []) ~state:at_list in
  check_step "scale-up -> After_create_pod 1" (V.After_create_pod 1) (fst out);
  check_req "scale-up emits Create_request" "create" out

(* ===== 4. After_list_pods + exactly desired matching pods -> update path ===== *)
let test_exact_update () =
  let objs = [ Pod.marshal good_pod; Pod.marshal good_pod2 ] in
  let out = V.reconcile_core ~cr:(cr 2) ~resp:(list_resp objs) ~state:at_list in
  check_step "exact -> After_update_vrs_status" V.After_update_vrs_status (fst out);
  check_req "exact emits Get_then_update_status_request" "get_then_update_status" out

(* ===== 5. After_list_pods + more than desired -> Get_then_delete, filtered kept ===== *)
let test_scale_down () =
  let objs = [ Pod.marshal good_pod; Pod.marshal good_pod2 ] in
  let s', req = V.reconcile_core ~cr:(cr 1) ~resp:(list_resp objs) ~state:at_list in
  check_step "scale-down -> After_delete_pod 0" (V.After_delete_pod 0) s';
  Alcotest.(check string) "scale-down emits Get_then_delete_request" "get_then_delete"
    (req_kind req);
  Alcotest.(check int) "filtered_pods carried (2)" 2
    (Option.fold s'.filtered_pods ~none:(-1) ~some:List.length)

(* ===== 6. After_create_pod 0 + Create_response Ok -> update path ===== *)
let test_create_done () =
  let out =
    V.reconcile_core ~cr:(cr 1) ~resp:create_resp
      ~state:{ V.reconcile_step = After_create_pod 0; filtered_pods = None }
  in
  check_step "create-done -> After_update_vrs_status" V.After_update_vrs_status (fst out);
  check_req "create-done emits Get_then_update_status_request" "get_then_update_status" out

(* ===== 7. After_create_pod (n>0) + Create_response Ok -> Create_request, n-1 ===== *)
let test_create_loop () =
  let out =
    V.reconcile_core ~cr:(cr 3) ~resp:create_resp
      ~state:{ V.reconcile_step = After_create_pod 2; filtered_pods = None }
  in
  check_step "create-loop -> After_create_pod 1" (V.After_create_pod 1) (fst out);
  check_req "create-loop emits Create_request" "create" out

(* ===== 8. After_delete_pod 0 + Get_then_delete_response Ok () -> update path ===== *)
let test_delete_done () =
  let out =
    V.reconcile_core ~cr:(cr 1) ~resp:get_then_delete_resp
      ~state:{ V.reconcile_step = After_delete_pod 0; filtered_pods = None }
  in
  check_step "delete-done -> After_update_vrs_status" V.After_update_vrs_status (fst out);
  check_req "delete-done emits Get_then_update_status_request" "get_then_update_status" out

(* ===== 9. After_update_vrs_status + Get_then_update_status_response Ok -> Done ===== *)
let test_status_done () =
  let s', req =
    V.reconcile_core ~cr:(cr 1) ~resp:get_then_update_status_resp
      ~state:{ V.reconcile_step = After_update_vrs_status; filtered_pods = None }
  in
  check_step "status-update -> Done" V.Done s';
  Alcotest.(check string) "done emits no request" "none" (req_kind req)

(* ===== 10. Error routing: wrong-kind / Error / absent response -> Error ===== *)
let test_error_routing () =
  (* wrong-kind response (Create where a List is awaited) *)
  check_step "wrong-kind resp -> Error" V.Error
    (fst (V.reconcile_core ~cr:(cr 1) ~resp:create_resp ~state:at_list));
  (* an Error api payload *)
  check_step "Error payload -> Error" V.Error
    (fst (V.reconcile_core ~cr:(cr 1) ~resp:list_err ~state:at_list));
  (* an absent response at a waiting step *)
  check_step "absent resp at waiting step -> Error" V.Error
    (fst
       (V.reconcile_core ~cr:(cr 1) ~resp:None
          ~state:{ V.reconcile_step = After_update_vrs_status; filtered_pods = None }))

(* ===== 11. objects_to_pods: a non-pod DynamicObject in the list -> error ===== *)
let non_pod_obj =
  Dynamic_object.make ~kind:Common.Config_map
    ~metadata:(Object_meta.default () |> Object_meta.with_name "cm")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let test_non_pod () =
  Alcotest.(check bool) "objects_to_pods rejects a non-pod" true
    (Option.is_none (V.objects_to_pods [ Pod.marshal good_pod; non_pod_obj ]));
  check_step "non-pod in list resp -> Error" V.Error
    (fst (V.reconcile_core ~cr:(cr 1) ~resp:(list_resp [ non_pod_obj ]) ~state:at_list))

(* ===== 12. filter_pods / pod_matches exclusion ===== *)
let no_owner_pod =
  mk_pod ~name:"vreplicaset-vrs1-c" ~owner:None ~labels:(Some labels_xy) ~del:None

let no_prefix_pod =
  mk_pod ~name:"other-c" ~owner:(Some [ vrs_self_ref ]) ~labels:(Some labels_xy) ~del:None

let deleting_pod =
  mk_pod ~name:"vreplicaset-vrs1-d" ~owner:(Some [ vrs_self_ref ])
    ~labels:(Some labels_xy) ~del:(Some "2024-01-01")

let test_filter_pods () =
  let all = [ good_pod; no_owner_pod; no_prefix_pod; deleting_pod ] in
  let kept = V.filter_pods all (cr 1) vrs_self_ref in
  Alcotest.(check int) "only the fully-matching pod survives" 1 (List.length kept);
  Alcotest.(check bool) "the survivor is good_pod" true
    (List.exists (Pod.equal good_pod) kept);
  Alcotest.(check bool) "good_pod matches" true (V.pod_matches (cr 1) vrs_self_ref good_pod);
  Alcotest.(check bool) "no-owner excluded" false
    (V.pod_matches (cr 1) vrs_self_ref no_owner_pod);
  Alcotest.(check bool) "no-prefix excluded" false
    (V.pod_matches (cr 1) vrs_self_ref no_prefix_pod);
  Alcotest.(check bool) "deleting excluded" false
    (V.pod_matches (cr 1) vrs_self_ref deleting_pod);
  Alcotest.(check bool) "has_vrs_prefix true for prefixed name" true
    (V.has_vrs_prefix "vreplicaset-vrs1-a");
  Alcotest.(check bool) "has_vrs_prefix false for other name" false
    (V.has_vrs_prefix "other-c")

(* ===== 13. State codec round-trip (Vreplica_set_pack): the driver marshals the
   reconcile state between EVERY step, so a populated filtered_pods list (carried
   only on the After_delete_pod path) must survive marshal_state -> unmarshal_state.
   This is the erase/codec infra's load-bearing round-trip, exercised by no
   scale-up driver run. ===== *)
let pods_equal = List.equal Pod.equal

let roundtrip (st : V.s) : V.s Res.t =
  Vreplica_set_pack.unmarshal_state (Vreplica_set_pack.marshal_state st)

let test_state_codec () =
  let st =
    { V.reconcile_step = V.After_delete_pod 3;
      filtered_pods = Some [ good_pod; good_pod2 ] }
  in
  Result.fold (roundtrip st)
    ~error:(fun (e : Err.t) ->
      Alcotest.failf "codec round-trip failed: %s" (Err.show e))
    ~ok:(fun (st' : V.s) ->
      check_step "codec preserves After_delete_pod 3" (V.After_delete_pod 3) st';
      Alcotest.(check bool) "codec preserves populated filtered_pods" true
        (Option.fold st'.filtered_pods ~none:false ~some:(fun ps ->
             pods_equal ps [ good_pod; good_pod2 ])));
  (* absent filtered_pods must round-trip to None, not [] *)
  Result.fold
    (roundtrip { V.reconcile_step = V.After_create_pod 2; filtered_pods = None })
    ~error:(fun (e : Err.t) ->
      Alcotest.failf "codec round-trip (None) failed: %s" (Err.show e))
    ~ok:(fun (st' : V.s) ->
      check_step "codec preserves After_create_pod 2" (V.After_create_pod 2) st';
      Alcotest.(check bool) "codec preserves absent filtered_pods" true
        (Option.is_none st'.filtered_pods))

(* ===== 14. After_delete_pod diff>0 + delete Ok -> another Get_then_delete with
   diff decremented (reads state.filtered_pods[diff-1]); plus the filtered_pods=None
   and diff>len error guards. ===== *)
let del_pods =
  [
    mk_pod ~name:"vreplicaset-vrs1-a" ~owner:(Some [ vrs_self_ref ])
      ~labels:(Some labels_xy) ~del:None;
    mk_pod ~name:"vreplicaset-vrs1-b" ~owner:(Some [ vrs_self_ref ])
      ~labels:(Some labels_xy) ~del:None;
    mk_pod ~name:"vreplicaset-vrs1-c" ~owner:(Some [ vrs_self_ref ])
      ~labels:(Some labels_xy) ~del:None;
  ]

let test_delete_loop () =
  let out =
    V.reconcile_core ~cr:(cr 1) ~resp:get_then_delete_resp
      ~state:{ V.reconcile_step = V.After_delete_pod 2; filtered_pods = Some del_pods }
  in
  check_step "delete-loop -> After_delete_pod 1" (V.After_delete_pod 1) (fst out);
  check_req "delete-loop emits Get_then_delete_request" "get_then_delete" out;
  (* a continuing delete step with no carried filtered_pods -> Error *)
  check_step "delete-loop w/o filtered_pods -> Error" V.Error
    (fst
       (V.reconcile_core ~cr:(cr 1) ~resp:get_then_delete_resp
          ~state:{ V.reconcile_step = V.After_delete_pod 2; filtered_pods = None }));
  (* diff greater than the filtered list length -> Error *)
  check_step "delete-loop diff>len -> Error" V.Error
    (fst
       (V.reconcile_core ~cr:(cr 1) ~resp:get_then_delete_resp
          ~state:{ V.reconcile_step = V.After_delete_pod 4; filtered_pods = Some del_pods }))

(* ===== 15. update_vrs_replicas owner-reference guard: Anvil requires EXACTLY one
   controller owner ref on the vrs; zero / two / absent all route to Error. ===== *)
let another_controller_ref : Owner_reference.t =
  {
    block_owner_deletion = Some true;
    controller = Some true;
    kind = Common.Custom_resource "deployment";
    name = "parent2";
    uid = Common.Uid.of_int 8;
  }

let non_controller_ref : Owner_reference.t =
  {
    block_owner_deletion = None;
    controller = Some false;
    kind = Common.Custom_resource "deployment";
    name = "plain";
    uid = Common.Uid.of_int 7;
  }

let cr_with_owners (replicas : int) (owners : Owner_reference.t list option) :
    Vreplica_set.t =
  Vreplica_set.make
    ~metadata:{ cr_metadata with owner_references = owners }
    ~spec:(cr_spec replicas) ~status:None

let exact_objs = [ Pod.marshal good_pod; Pod.marshal good_pod2 ]

let test_update_owner_guards () =
  (* baseline: exactly one controller owner ref reaches the status update *)
  check_step "update w/ one controller -> After_update_vrs_status"
    V.After_update_vrs_status
    (fst
       (V.reconcile_core
          ~cr:(cr_with_owners 2 (Some [ parent_ref ]))
          ~resp:(list_resp exact_objs) ~state:at_list));
  (* two controller owner refs -> not exactly one -> Error *)
  check_step "update w/ two controllers -> Error" V.Error
    (fst
       (V.reconcile_core
          ~cr:(cr_with_owners 2 (Some [ parent_ref; another_controller_ref ]))
          ~resp:(list_resp exact_objs) ~state:at_list));
  (* no owner_references at all -> Error *)
  check_step "update w/ no owner_references -> Error" V.Error
    (fst
       (V.reconcile_core
          ~cr:(cr_with_owners 2 None)
          ~resp:(list_resp exact_objs) ~state:at_list));
  (* owner_references present but zero controllers -> Error *)
  check_step "update w/ zero controllers -> Error" V.Error
    (fst
       (V.reconcile_core
          ~cr:(cr_with_owners 2 (Some [ non_controller_ref ]))
          ~resp:(list_resp exact_objs) ~state:at_list))

(* ===== 16. Honest unwrap (BUILD-SPEC section 9): a required field Anvil unwraps
   under well-formedness (here metadata.namespace) routes to Error rather than
   raising, and is observed taking that error path. ===== *)
let test_honest_unwrap () =
  let cr_no_ns =
    Vreplica_set.make
      ~metadata:{ cr_metadata with namespace = None }
      ~spec:(cr_spec 1) ~status:None
  in
  let s', req =
    V.reconcile_core ~cr:cr_no_ns ~resp:None ~state:(V.reconcile_init_state ())
  in
  check_step "init w/ no namespace -> Error (honest unwrap)" V.Error s';
  Alcotest.(check string) "no request when namespace missing" "none" (req_kind req)

let () =
  Alcotest.run "vreplica_set_reconciler"
    [
      ( "transitions",
        [
          Alcotest.test_case "1 init+deletion -> done" `Quick test_init_deleting;
          Alcotest.test_case "2 init -> list" `Quick test_init_list;
          Alcotest.test_case "3 scale up" `Quick test_scale_up;
          Alcotest.test_case "4 exact -> update" `Quick test_exact_update;
          Alcotest.test_case "5 scale down" `Quick test_scale_down;
          Alcotest.test_case "6 create done" `Quick test_create_done;
          Alcotest.test_case "7 create loop" `Quick test_create_loop;
          Alcotest.test_case "8 delete done" `Quick test_delete_done;
          Alcotest.test_case "9 status -> done" `Quick test_status_done;
        ] );
      ( "guards",
        [
          Alcotest.test_case "10 error routing" `Quick test_error_routing;
          Alcotest.test_case "11 non-pod list" `Quick test_non_pod;
          Alcotest.test_case "12 filter pods" `Quick test_filter_pods;
          Alcotest.test_case "13 state codec round-trip" `Quick test_state_codec;
          Alcotest.test_case "14 delete loop" `Quick test_delete_loop;
          Alcotest.test_case "15 update owner guards" `Quick test_update_owner_guards;
          Alcotest.test_case "16 honest unwrap namespace" `Quick test_honest_unwrap;
        ] );
    ]

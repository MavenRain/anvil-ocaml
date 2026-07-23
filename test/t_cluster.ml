(* Compound-cluster tests (BUILD-SPEC-P2 "## Tests", t_cluster):
   - [init] truth table (holds for an initial state; each tampered field breaks
     it);
   - a hand-built one-ConfigMap-reconciler cluster takes a
     [schedule_controller_reconcile] via [enabled_successors];
   - an api-server create step is produced by [enabled_successors] from a
     deliverable in-flight request;
   - the network-baked-in composition precondition rejects a step whose network
     side is [Disabled];
   - [next_step] holds for the produced successor and fails for a tampered one.

   CONFIRM-BY-MUTATION (feedback-confirm-tests-by-mutation), two guards:

   (a) [test_network_baked_in]'s "rejected when the network side is disabled"
       assertion pins the network-baked-in [Enabled] conjunct of
       [Cluster.api_server_next] (cluster.ml:112-115, the
       [let* net' = enabled_to_opt (Network.deliver ...)]). Neuter it (bind
       [net'] to [s.network] unconditionally), rebuild: the assertion flips to
       failing. Restore and it is green.

   (d) [test_deliverable_produces_successor]'s "a deliverable message produces an
       Api_server_step successor" assertion pins the [recv] bound of
       [Cluster.enabled_successors] (cluster.ml:564, the
       [None :: List.map (fun m -> Some m) for_api] recv candidates). Neuter it to
       [[ None ]] (drop the in-flight recv candidates), rebuild: the assertion
       flips to failing. Restore and it is green.

   Every mutation was restored (tree left green). *)

(* -- A trivial installed reconciler + its first-class-module pack. Not driven
   here (schedule / api steps do not force reconcile_core); it only has to type. *)
module Triv_R = struct
  type s = Value.t
  type k = Dynamic_object.t
  type ereq = Value.t
  type eresp = Value.t

  let reconcile_init_state () = Value.of_json (`String "init")

  let reconcile_core ~cr:(_ : k) ~(resp : eresp Io.response_view option)
      ~(state : s) : s * ereq Io.request_view option =
    let _ = resp in
    (state, None)

  let reconcile_done (s : s) = Value.equal s (Value.of_json (`String "done"))
  let reconcile_error (_ : s) = false
end

module Triv_C :
  Controller_pack.CONTROLLER
    with type R.s = Value.t
     and type R.ereq = Value.t
     and type R.eresp = Value.t = struct
  module R = Triv_R

  let id = 0
  let marshal_state (s : R.s) = s
  let unmarshal_cr (o : Dynamic_object.t) : R.k Res.t = Res.ok o
end

let pack :
    (module Controller_pack.CONTROLLER
       with type R.s = Value.t
        and type R.ereq = Value.t
        and type R.eresp = Value.t) =
  (module Triv_C)

let permissive : Api_server.installed_types =
  {
    Api_server.unmarshallable_spec = (fun _ _ -> true);
    unmarshallable_status = (fun _ _ -> true);
    valid_object = (fun _ -> true);
    valid_transition = (fun _ _ -> true);
    marshalled_default_status = (fun _ -> Value.of_json `Null);
  }

let cm_ref = { Common.kind = Common.Config_map; name = "cm"; namespace = "ns" }

let cm_obj =
  Dynamic_object.make ~kind:Common.Config_map
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name "cm"
      |> Object_meta.with_namespace "ns")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let controller_model : Cluster.controller_model =
  { Cluster.reconciler = pack; kind = Common.Config_map; external_model = None }

let clu : Cluster.t =
  {
    Cluster.installed_types = permissive;
    controller_models = Imap.add 0 controller_model Imap.empty;
  }

let cae0 : Cluster.controller_and_external =
  { Cluster.controller = Controller.init; external_ = None; crash_enabled = true }

let empty_api : Api_server.state =
  { Api_server.resources = Object_ref_map.empty; uid_counter = 0; resource_version_counter = 0 }

let s_init : Cluster.cluster_state =
  {
    Cluster.api_server = empty_api;
    controller_and_externals = Imap.add 0 cae0 Imap.empty;
    network = { Network.in_flight = Message.Pool.empty };
    rpc_id_allocator = Message.Rpc_id_allocator.init ();
    req_drop_enabled = true;
    pod_monkey_enabled = true;
  }

(* -- init truth table -- *)
let test_init () =
  Alcotest.(check bool) "init holds for an initial state" true
    (Cluster.init clu s_init);
  let bad_crash =
    {
      s_init with
      Cluster.controller_and_externals =
        Imap.add 0 { cae0 with Cluster.crash_enabled = false } Imap.empty;
    }
  in
  Alcotest.(check bool) "crash disabled breaks init" false (Cluster.init clu bad_crash);
  let bad_res =
    {
      s_init with
      Cluster.api_server =
        { empty_api with Api_server.resources = Object_ref_map.add cm_ref cm_obj Object_ref_map.empty };
    }
  in
  Alcotest.(check bool) "nonempty resources breaks init" false
    (Cluster.init clu bad_res);
  Alcotest.(check bool) "pod monkey disabled breaks init" false
    (Cluster.init clu { s_init with Cluster.pod_monkey_enabled = false });
  Alcotest.(check bool) "req-drop disabled breaks init" false
    (Cluster.init clu { s_init with Cluster.req_drop_enabled = false })

(* -- schedule_controller_reconcile via enabled_successors + next_step -- *)
let is_schedule_step (step : Step.t) : bool =
  match step with
  | Step.Schedule_controller_reconcile_step (cid, key) ->
    cid = 0 && Common.equal_object_ref key cm_ref
  | Step.Api_server_step _ | Step.Builtin_controllers_step _
  | Step.Controller_step _ | Step.Restart_controller_step _
  | Step.Disable_crash_step _ | Step.Drop_req_step _ | Step.Disable_req_drop_step
  | Step.Pod_monkey_step _ | Step.Disable_pod_monkey_step | Step.External_step _
  | Step.Stutter_step ->
    false

let test_schedule () =
  (* the ConfigMap cr is stored, ready to be scheduled. *)
  let s0 =
    {
      s_init with
      Cluster.api_server =
        { empty_api with Api_server.resources = Object_ref_map.add cm_ref cm_obj Object_ref_map.empty };
    }
  in
  let succs = Cluster.enabled_successors Bound.default clu s0 in
  let sched = List.find_opt (fun (step, _) -> is_schedule_step step) succs in
  Alcotest.(check bool) "schedule step enumerated" true (Option.is_some sched);
  Alcotest.(check bool) "cr is scheduled after applying the step" true
    (Option.fold sched ~none:false ~some:(fun (_, s1) ->
         Object_ref_map.mem cm_ref (Cluster.scheduled_reconciles s1 0)));
  Option.fold sched ~none:() ~some:(fun (step, s1) ->
      Alcotest.(check bool) "next_step holds for the produced successor" true
        (Cluster.next_step clu s0 step s1);
      let tampered =
        { s1 with Cluster.pod_monkey_enabled = not s1.Cluster.pod_monkey_enabled }
      in
      Alcotest.(check bool) "next_step fails for a tampered successor" false
        (Cluster.next_step clu s0 step tampered))

(* -- api-server create via enabled_successors, and the network-baked-in
   composition. A separate controller-free cluster keeps the successor set to the
   one api step. -- *)
let clu_api : Cluster.t =
  { Cluster.installed_types = permissive; controller_models = Imap.empty }

let msg_create : Message.t =
  Message.pod_monkey_req_msg (Message.Rpc_id.of_int 0)
    (Message.create_req_msg_content "ns" cm_obj)

let s_net : Cluster.cluster_state =
  {
    s_init with
    Cluster.controller_and_externals = Imap.empty;
    network = { Network.in_flight = Message.Pool.singleton msg_create };
    req_drop_enabled = false;
    pod_monkey_enabled = false;
  }

let is_api_step (msg : Message.t) (step : Step.t) : bool =
  match step with
  | Step.Api_server_step recv ->
    Option.fold recv ~none:false ~some:(fun m -> Message.equal m msg)
  | Step.Builtin_controllers_step _ | Step.Controller_step _
  | Step.Schedule_controller_reconcile_step _ | Step.Restart_controller_step _
  | Step.Disable_crash_step _ | Step.Drop_req_step _ | Step.Disable_req_drop_step
  | Step.Pod_monkey_step _ | Step.Disable_pod_monkey_step | Step.External_step _
  | Step.Stutter_step ->
    false

let test_deliverable_produces_successor () =
  let succs = Cluster.enabled_successors Bound.default clu_api s_net in
  let api = List.find_opt (fun (step, _) -> is_api_step msg_create step) succs in
  (* CONFIRM-BY-MUTATION (d): the deliverable in-flight request must produce a
     recv=Some successor. *)
  Alcotest.(check bool) "a deliverable message produces an Api_server_step successor"
    true (Option.is_some api);
  Alcotest.(check bool) "applying the step creates the object" true
    (Option.fold api ~none:false ~some:(fun (_, s') ->
         Option.is_some (Cluster.lookup_resource s' cm_ref)))

let test_network_baked_in () =
  let act = Cluster.api_server_next clu_api in
  Alcotest.(check bool) "enabled when the request is deliverable" true
    (act.Action.precondition (Some msg_create) s_net);
  (* CONFIRM-BY-MUTATION (a): with the same request NOT in flight, the network
     side is Disabled, so the compound action is rejected. *)
  let s_dry = { s_net with Cluster.network = { Network.in_flight = Message.Pool.empty } } in
  Alcotest.(check bool) "rejected when the network side is disabled" false
    (act.Action.precondition (Some msg_create) s_dry)

(* -- gc_keys per-kind cap (FIX 2): an orphan of a later-sorting kind must remain
   a GC candidate even when an earlier-sorting kind fills max_objects_per_kind.
   The store holds [max_objects_per_kind] non-orphan ConfigMaps ("ConfigMap" sorts
   before "Secret") plus one fully-orphaned Secret at the tail. A single
   cross-kind [take max_objects_per_kind] keeps only the ConfigMaps and drops the
   Secret; the per-kind cap keeps it, so a [Builtin_controllers_step] targets it. -- *)
let ghost_owner =
  {
    (Owner_reference.default ()) with
    Owner_reference.kind = Common.Config_map;
    name = "ghost";
    uid = Common.Uid.of_int 99;
  }

let orphan_ref =
  { Common.kind = Common.Secret; name = "orphan"; namespace = "default" }

let orphan_obj =
  Dynamic_object.make ~kind:Common.Secret
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name "orphan"
      |> Object_meta.with_namespace "default"
      |> Object_meta.with_owner_references [ ghost_owner ])
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let gc_cm_ref i =
  { Common.kind = Common.Config_map; name = "c" ^ string_of_int i; namespace = "default" }

let gc_cm_obj i =
  Dynamic_object.make ~kind:Common.Config_map
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name ("c" ^ string_of_int i)
      |> Object_meta.with_namespace "default")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let gc_resources =
  List.fold_left
    (fun acc i -> Object_ref_map.add (gc_cm_ref i) (gc_cm_obj i) acc)
    (Object_ref_map.add orphan_ref orphan_obj Object_ref_map.empty)
    (List.init Bound.(default.max_objects_per_kind) Fun.id)

let s_gc : Cluster.cluster_state =
  {
    s_init with
    Cluster.api_server = { empty_api with Api_server.resources = gc_resources };
    controller_and_externals = Imap.empty;
    network = { Network.in_flight = Message.Pool.empty };
    req_drop_enabled = false;
    pod_monkey_enabled = false;
  }

let is_gc_step_for (target : Common.object_ref) (step : Step.t) : bool =
  match step with
  | Step.Builtin_controllers_step (Builtin_controllers.Garbage_collector, key) ->
    Common.equal_object_ref key target
  | Step.Api_server_step _ | Step.Controller_step _
  | Step.Schedule_controller_reconcile_step _ | Step.Restart_controller_step _
  | Step.Disable_crash_step _ | Step.Drop_req_step _ | Step.Disable_req_drop_step
  | Step.Pod_monkey_step _ | Step.Disable_pod_monkey_step | Step.External_step _
  | Step.Stutter_step ->
    false

let test_gc_per_kind_cap () =
  let succs = Cluster.enabled_successors Bound.default clu_api s_gc in
  let gc = List.find_opt (fun (step, _) -> is_gc_step_for orphan_ref step) succs in
  (* CONFIRM-BY-MUTATION (FIX 2): under a cross-kind [take] the ConfigMaps fill
     the cap and this orphaned Secret is dropped, so no GC step targets it. *)
  Alcotest.(check bool) "GC step enumerated for the later-sorting orphan" true
    (Option.is_some gc)

let () =
  Alcotest.run "cluster"
    [
      ("init", [ Alcotest.test_case "truth table" `Quick test_init ]);
      ( "enabled_successors",
        [
          Alcotest.test_case "schedule + next_step" `Quick test_schedule;
          Alcotest.test_case "deliverable produces successor" `Quick
            test_deliverable_produces_successor;
          Alcotest.test_case "gc_keys per-kind cap" `Quick test_gc_per_kind_cap;
        ] );
      ( "network_composition",
        [ Alcotest.test_case "baked-in Enabled conjunct" `Quick test_network_baked_in ] );
    ]

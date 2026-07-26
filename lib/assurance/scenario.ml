(* The canonical VReplicaSet reconcile scenario (BUILD-SPEC-P4 §2).

   A [Cluster.t] running exactly the VReplicaSet reconciler at controller id [0],
   plus a REACHABLE seed [Cluster.cluster_state] in which the CR is already stored
   in etcd (Anvil's [desired_state_is] antecedent). Reused by the P4 QCheck harness
   and (later) the P5 bounded model checker.

   Shapes reuse the P2/P3 test templates (test/t_cluster.ml `permissive`/`s_init`,
   test/t_vreplica_set.ml `good_spec`/`good_template`) verbatim so the assurance
   spine exercises the SAME objects the unit tests pin.

   OWNER-REFERENCE NOTE (load-bearing): the scenario CR carries EXACTLY ONE
   controller owner reference (scenario.mli), and that reference is a SELF-
   reference — [{ kind = vreplicaset; name = "vrs1"; uid = 1; controller = true }],
   byte-identical to [Vreplica_set.controller_owner_ref vrs]. This is deliberate:
   the garbage collector (lib/cluster/builtin_controllers.ml) fires on any object
   ALL of whose owner references are [owner_gone] (absent, or present with a
   mismatched uid). A ref to a non-existent parent would make the CR a GC orphan,
   so a productive [Builtin_controllers_step] would delete it and the liveness
   fixpoint would self-destruct. A self-reference resolves to the stored CR with a
   matching uid, so [owner_gone = false] and the CR is never collected, while still
   satisfying "exactly one controller owner reference" and giving invariant #3
   (at-most-one-controller-owner) a live witness. If the spec author instead meant
   "no owner reference on the CR itself", flip [vrs_owner_ref]/[owner_references]
   to [None] — nothing else depends on it ([controller_owner_ref] is derived from
   name+uid, not from [owner_references]). *)

let controller_id : int = 0

let kind : Common.kind = Vreplica_set.kind

(* Permissive validation (t_cluster.ml `permissive`) EXCEPT [marshalled_default_
   status], which returns the VReplicaSet default status marshalled (spec §2). The
   permissive [valid_object]/[valid_transition] admit vrs + pod objects (they admit
   everything). *)
let installed_types : Api_server.installed_types =
  {
    Api_server.unmarshallable_spec = (fun _ _ -> true);
    unmarshallable_status = (fun _ _ -> true);
    valid_object = (fun _ -> true);
    valid_transition = (fun _ _ -> true);
    marshalled_default_status =
      (fun (_ : Common.kind) ->
        Vreplica_set.marshal_status (Some (Vreplica_set.vrs_status_default ())));
  }

(* The single controller model: the VReplicaSet pack erased to the [Value.t]-based
   [CONTROLLER] the cluster's heterogeneous [Imap] stores (cf. t_cluster.ml `pack`).
   [Vreplica_set_pack.packed] has the existential [Controller_pack.packed] type
   [(module CONTROLLER)] whose [R.s] is opaque, so it cannot unify with the
   [reconciler] field's [with type R.s = Value.t ...] constraint; the concrete
   [Vreplica_set_pack.Controller] module carries those equalities and does. *)
let controller_model : Cluster.controller_model =
  {
    Cluster.reconciler =
      (module Vreplica_set_pack.Controller
      : Controller_pack.CONTROLLER
        with type R.s = Value.t
         and type R.ereq = Value.t
         and type R.eresp = Value.t);
    kind;
    external_model = None;
  }

let cluster : Cluster.t =
  {
    Cluster.installed_types;
    controller_models = Imap.add controller_id controller_model Imap.empty;
  }

(* -- The canonical CR: [vrs1] in [ns], uid 1, one (self) controller owner ref,
   [desired] replicas, selector [app=x] and a matching pod template (the P3
   [good_spec]/[good_template] shape, so [state_validation] holds). -- *)

let app_labels = Smap.add "app" "x" Smap.empty

let selector : Label_selector.t = { match_labels = Some app_labels }

let template : Pod_template_spec.t =
  {
    metadata = Some (Object_meta.with_labels app_labels (Object_meta.default ()));
    spec = Some (Pod_spec.default ());
  }

(* The self controller owner reference — equal to [controller_owner_ref vrs]; see
   the OWNER-REFERENCE NOTE above. *)
let vrs_owner_ref : Owner_reference.t =
  {
    Owner_reference.block_owner_deletion = Some true;
    controller = Some true;
    kind;
    name = "vrs1";
    uid = Common.Uid.of_int 1;
  }

(* Metadata with uid 1 and resource_version 0 baked in (Object_meta exposes no
   [with_uid], so we use a record update); the seed advances the api-server
   counters STRICTLY past both. *)
let vrs_metadata : Object_meta.t =
  {
    (Object_meta.default ()) with
    Object_meta.name = Some "vrs1";
    namespace = Some "ns";
    uid = Some (Common.Uid.of_int 1);
    resource_version = Some (Common.Resource_version.of_int 0);
    owner_references = Some [ vrs_owner_ref ];
  }

let vrs ~desired : Vreplica_set.t =
  Vreplica_set.make ~metadata:vrs_metadata
    ~spec:{ Vreplica_set.replicas = Some desired; selector; template = Some template }
    ~status:None

let vrs_ref : Common.object_ref = { Common.kind; name = "vrs1"; namespace = "ns" }

(* -- P9 additions: the VDeployment CR + a multi-kind installed_types so the two-
   controller exec witness (VDeployment -> VReplicaSet -> Pods) can seed a
   VDeployment and have the api-server default-status BOTH kinds. Additive: the
   vrs-only [installed_types]/[cluster] above are untouched. -- *)

(* Metadata for the canonical VDeployment: [vd1] in [ns], uid 1, resource_version
   0 (the api-server counters advance strictly past both when seeded). No owner
   reference: the exec witness runs against Exec_api_server (no built-in garbage
   collector), and [V_deployment.controller_owner_ref] is derived from name+uid,
   not from [owner_references]. *)
let vd_metadata : Object_meta.t =
  {
    (Object_meta.default ()) with
    Object_meta.name = Some "vd1";
    namespace = Some "ns";
    uid = Some (Common.Uid.of_int 1);
    resource_version = Some (Common.Resource_version.of_int 0);
  }

(* A well-formed VDeployment named [vd1] in [ns] with uid 1 / rv 0, [desired]
   replicas, and the shared [selector] ([app=x]) and [template] (whose metadata
   labels are [app=x], satisfying [Label_selector.matches selector]) reused from
   the vrs builders above, so [V_deployment.state_validation] holds. Its bare
   template spec is [Some], and [strategy]/[minReadySeconds]/[progressDeadline]
   default to [None] (the [None,None] and no-strategy clauses of state_validation
   both admit). *)
let vd ~desired : V_deployment.t =
  V_deployment.make ~metadata:vd_metadata
    ~spec:
      {
        (V_deployment.vd_spec_default ()) with
        V_deployment.replicas = Some desired;
        selector;
        template;
      }
    ~status:()

let vd_ref : Common.object_ref =
  { Common.kind = V_deployment.kind; name = "vd1"; namespace = "ns" }

(* A multi-kind [installed_types] admitting BOTH the vreplicaset and vdeployment
   custom resources (plus pods). Predicates stay permissive (all [true]); only
   [marshalled_default_status] dispatches by kind, EXHAUSTIVELY over [Common.kind]:
   vreplicaset -> the vrs default status marshalled; vdeployment -> the (empty)
   vdeployment status marshalled ([`Null]); every builtin kind (Pod, ...) -> a
   [`Null] default. Used by the P9 two-controller exec witness. *)
let vd_and_vrs_installed : Api_server.installed_types =
  {
    Api_server.unmarshallable_spec = (fun _ _ -> true);
    unmarshallable_status = (fun _ _ -> true);
    valid_object = (fun _ -> true);
    valid_transition = (fun _ _ -> true);
    marshalled_default_status =
      (fun (k : Common.kind) ->
        match k with
        | Common.Custom_resource s ->
          if String.equal s Vreplica_set.kind_name then
            Vreplica_set.marshal_status
              (Some (Vreplica_set.vrs_status_default ()))
          else if String.equal s V_deployment.kind_name then
            V_deployment.marshal_status ()
          else Value.of_json `Null
        | Common.Config_map | Common.Daemon_set
        | Common.Persistent_volume_claim | Common.Pod | Common.Role
        | Common.Role_binding | Common.Stateful_set | Common.Service
        | Common.Service_account | Common.Secret ->
          Value.of_json `Null);
  }

(* -- P10 additions: the VStatefulSet CR (single controller managing Pods + PVCs
   directly) plus a VSS-admitting installed_types, so a P10 exec/model witness can
   seed a VStatefulSet and have the api-server default-status its kind (and admit
   the Pods / PVCs it creates). Additive: the vrs-only [installed_types]/[cluster]
   above are untouched. -- *)

(* Metadata for the canonical VStatefulSet: [vsts1] in [ns], uid 1, rv 0 (the
   api-server counters advance strictly past both when seeded). Name + uid + ns
   are Some, so [V_stateful_set.controller_owner_ref] is [Some] and the make_pod /
   make_pvcs child owner refs resolve. *)
let vsts_metadata : Object_meta.t =
  {
    (Object_meta.default ()) with
    Object_meta.name = Some "vsts1";
    namespace = Some "ns";
    uid = Some (Common.Uid.of_int 1);
    resource_version = Some (Common.Resource_version.of_int 0);
  }

(* One volumeClaimTemplate, included in the CR spec only when [vsts ~vct:true].
   The template name is dash-free ([data]) and its namespace is [ns], as
   [V_stateful_set.state_validation] condition 7 requires; its spec is [Some]. The
   reconciler's [make_pvcs] specialises it per ordinal to
   [vstatefulset-data-vsts1-<ord>]. *)
let vsts_pvc_template : Persistent_volume_claim.t =
  {
    Persistent_volume_claim.metadata =
      {
        (Object_meta.default ()) with
        Object_meta.name = Some "data";
        namespace = Some "ns";
      };
    spec = Some (Persistent_volume_claim.spec_default ());
    status = None;
  }

(* A well-formed VStatefulSet named [vsts1] in [ns] with uid 1 / rv 0, [desired]
   replicas, a non-empty [service_name], the shared [selector] ([app=x]) and
   [template] (whose metadata labels are [app=x], matching the selector and
   carrying NEITHER reserved key), and — when [~vct:true] — exactly one
   volumeClaimTemplate. Every other spec field defaults to [None]
   ([ss_spec_default]), so all nine clauses of [V_stateful_set.state_validation]
   hold and [controller_owner_ref] is [Some]. Mirrors the [vrs]/[vd] builder
   argument style ([~desired]), with [?vct] gating the storage template. *)
let vsts ~desired ?(vct = false) () : V_stateful_set.t =
  V_stateful_set.make ~metadata:vsts_metadata
    ~spec:
      {
        (Stateful_set.ss_spec_default ()) with
        Stateful_set.replicas = Some desired;
        selector;
        template;
        service_name = "vsts1";
        volume_claim_templates =
          (if vct then Some [ vsts_pvc_template ] else None);
      }
    ~status:None

let vsts_ref : Common.object_ref =
  { Common.kind = V_stateful_set.kind; name = "vsts1"; namespace = "ns" }

(* A multi-kind [installed_types] admitting the vstatefulset custom resource (plus
   the Pods and PersistentVolumeClaims it manages). Predicates stay permissive
   (all [true]); only [marshalled_default_status] dispatches by kind, EXHAUSTIVELY
   over [Common.kind]: vstatefulset -> the VSS default status marshalled (the
   [ready_replicas] status, i.e. [{ "readyReplicas": null }]); every other kind ->
   a [`Null] default. Used by the P10 VStatefulSet witness. *)
let vsts_installed : Api_server.installed_types =
  {
    Api_server.unmarshallable_spec = (fun _ _ -> true);
    unmarshallable_status = (fun _ _ -> true);
    valid_object = (fun _ -> true);
    valid_transition = (fun _ _ -> true);
    marshalled_default_status =
      (fun (k : Common.kind) ->
        match k with
        | Common.Custom_resource s ->
          if String.equal s V_stateful_set.kind_name then
            V_stateful_set.marshal_status
              (Some (Stateful_set.ss_status_default ()))
          else Value.of_json `Null
        | Common.Config_map | Common.Daemon_set
        | Common.Persistent_volume_claim | Common.Pod | Common.Role
        | Common.Role_binding | Common.Stateful_set | Common.Service
        | Common.Service_account | Common.Secret ->
          Value.of_json `Null);
  }

(* The VSTS controller model: the erased VStatefulSet pack ([V_stateful_set_pack.
   Controller]) coerced to the [Value.t]-based [CONTROLLER] the cluster's
   heterogeneous [Imap] stores, exactly as {!controller_model} does for the vrs
   pack. The pack's extra [R.k = V_stateful_set.t] equality is dropped by the
   coercion (only [R.s]/[R.ereq]/[R.eresp] are constrained). *)
let vsts_controller_model : Cluster.controller_model =
  {
    Cluster.reconciler =
      (module V_stateful_set_pack.Controller
      : Controller_pack.CONTROLLER
        with type R.s = Value.t
         and type R.ereq = Value.t
         and type R.eresp = Value.t);
    kind = V_stateful_set.kind;
    external_model = None;
  }

(* The runnable VSTS cluster: built EXACTLY as {!cluster} but with
   [installed_types = vsts_installed] (admits the VStatefulSet CR + its Pods +
   PVCs) and a single controller model = the {!V_stateful_set_pack} controller at
   {!controller_id}. This is the [Cluster.t] the VSTS BMC/ESR legs explore and the
   [Cluster.t] the generalized {!productive_successors} / {!Cluster_check.settled}
   enumerate over. *)
let vsts_cluster : Cluster.t =
  {
    Cluster.installed_types = vsts_installed;
    controller_models = Imap.add controller_id vsts_controller_model Imap.empty;
  }

(* A reachable initial state for the VSTS cluster, the mirror of {!seed}: the
   {!vsts}[ ~desired] CR ([?vct:false] default) is put into etcd by a REAL
   {!Api_server.handle_create_request} against a fresh empty api-server
   ([uid_counter = 1], [resource_version_counter = 0]), so its uid (1) and
   resource_version (0) are STAMPED by the server (never forged into metadata) and
   both counters advance strictly past them (to 2 / 1) — the same uid/rv/counter
   shape {!seed} carries, obtained legitimately. The VSTS controller sits at
   {!controller_id} with an empty {!Controller.init} reconcile state (the reconcile
   is scheduled during exploration, exactly as for {!seed}); [fair] gates the three
   disruptor toggles together ([false] = full nondeterminism for safety, [true] =
   the fair suffix for ESR). *)
let vsts_seed ~desired ~fair : Cluster.cluster_state =
  let enabled = not fair in
  let created, _ =
    Api_server.handle_create_request vsts_installed
      {
        Api_method.namespace = "ns";
        obj = V_stateful_set.marshal (vsts ~desired ());
      }
      {
        Api_server.resources = Object_ref_map.empty;
        uid_counter = 1;
        resource_version_counter = 0;
      }
  in
  {
    Cluster.api_server = created;
    controller_and_externals =
      Imap.add controller_id
        {
          Cluster.controller = Controller.init;
          external_ = None;
          crash_enabled = enabled;
        }
        Imap.empty;
    network = { Network.in_flight = Message.Pool.empty };
    rpc_id_allocator = Message.Rpc_id_allocator.init ();
    req_drop_enabled = enabled;
    pod_monkey_enabled = enabled;
  }

(* A reachable (NOT [Cluster.init]) state: etcd already holds [vrs ~desired] under
   [vrs_ref] with uid 1 / rv 0, and the api-server counters sit strictly above them
   (uid_counter 2 > 1, resource_version_counter 1 > 0) so Invariants #2's [< counter]
   bounds hold. [~fair] toggles the three liveness switches together. *)
let seed ~desired ~fair : Cluster.cluster_state =
  let enabled = not fair in
  let stored = Vreplica_set.marshal (vrs ~desired) in
  {
    Cluster.api_server =
      {
        Api_server.resources =
          Object_ref_map.add vrs_ref stored Object_ref_map.empty;
        uid_counter = 2;
        resource_version_counter = 1;
      };
    controller_and_externals =
      Imap.add controller_id
        {
          Cluster.controller = Controller.init;
          external_ = None;
          crash_enabled = enabled;
        }
        Imap.empty;
    network = { Network.in_flight = Message.Pool.empty };
    rpc_id_allocator = Message.Rpc_id_allocator.init ();
    req_drop_enabled = enabled;
    pod_monkey_enabled = enabled;
  }

(* -- Widened seeds (BUILD-SPEC-P4 architecture finding 14). The single-CR
   scale-up [seed] cannot reach the [interesting] preconditions of invariants
   #6, #7, #15, #16 (no second reconcile, no in-flight gc delete, no non-empty
   filtered_pods), so the enumerator reds them as vacuous. These three seeds are
   REACHABLE states that de-vacuise them; each holds every ALWAYS invariant
   (unique uids, uids/rvs strictly below the api-server counters, well-formed
   namespaced metadata, at most one controller owner ref per object). -- *)

(* The common cluster scaffold shared by every seed: empty controller reconcile
   state, fresh rpc allocator, empty network, the three liveness toggles wired to
   [enabled] together. Only [resources] and the two counters vary. *)
let make_state ~enabled ~resources ~uid_counter ~resource_version_counter :
    Cluster.cluster_state =
  {
    Cluster.api_server = { Api_server.resources; uid_counter; resource_version_counter };
    controller_and_externals =
      Imap.add controller_id
        {
          Cluster.controller = Controller.init;
          external_ = None;
          crash_enabled = enabled;
        }
        Imap.empty;
    network = { Network.in_flight = Message.Pool.empty };
    rpc_id_allocator = Message.Rpc_id_allocator.init ();
    req_drop_enabled = enabled;
    pod_monkey_enabled = enabled;
  }

(* A SELF controller owner reference for a CR named [name] with [uid] — byte-
   identical to [Vreplica_set.controller_owner_ref] of that CR (see the OWNER-
   REFERENCE NOTE). Resolves to the live CR (matching uid) so [owner_gone] is
   false and the CR is never garbage-collected. [vrs_owner_ref] is the [~name:
   "vrs1" ~uid:1] instance of this. *)
let self_owner_ref ~name ~uid : Owner_reference.t =
  {
    Owner_reference.block_owner_deletion = Some true;
    controller = Some true;
    kind;
    name;
    uid = Common.Uid.of_int uid;
  }

(* A well-formed VReplicaSet named [name] in [ns] with [uid] (rv 0), one self
   controller owner ref, [desired] replicas and the shared [selector]/[template].
   [cr ~name:"vrs1" ~uid:1 ~desired] is byte-identical to [vrs ~desired]. *)
let cr ~name ~uid ~desired : Vreplica_set.t =
  let metadata =
    {
      (Object_meta.default ()) with
      Object_meta.name = Some name;
      namespace = Some "ns";
      uid = Some (Common.Uid.of_int uid);
      resource_version = Some (Common.Resource_version.of_int 0);
      owner_references = Some [ self_owner_ref ~name ~uid ];
    }
  in
  Vreplica_set.make ~metadata
    ~spec:{ Vreplica_set.replicas = Some desired; selector; template = Some template }
    ~status:None

let cr_ref ~name : Common.object_ref = { Common.kind; name; namespace = "ns" }

(* De-vacuises #6 every_ongoing_reconcile_has_unique_id (interesting = >= 2
   concurrent ongoing reconciles): one CR per [desireds] element, keys
   [vrs1], [vrs2], ... with distinct names, uids [1..n] and distinct rvs [0..n-1]
   (each object freshly issued, [resource_version_counter = n] strictly past every
   rv, mirroring [uid_counter]), all stored in etcd, so scheduling each drives
   >= 2 simultaneous reconciles. *)
let seed_multi ~desireds ~fair : Cluster.cluster_state =
  let enabled = not fair in
  let resources =
    List.fold_left
      (fun acc (i, desired) ->
        let name = "vrs" ^ string_of_int i in
        Object_ref_map.add (cr_ref ~name)
          (Dynamic_object.with_resource_version
             (Common.Resource_version.of_int (i - 1))
             (Vreplica_set.marshal (cr ~name ~uid:i ~desired)))
          acc)
      Object_ref_map.empty
      (List.mapi (fun idx desired -> (idx + 1, desired)) desireds)
  in
  make_state ~enabled ~resources
    ~uid_counter:(List.length desireds + 1)
    ~resource_version_counter:(List.length desireds)

(* A pod already owned by [vrs1]: vrs-prefixed name, [app=x] labels matching the
   selector, the [vrs_owner_ref] controller owner ref, no deletion timestamp,
   uid [uid] / rv 0. Satisfies [Vreplica_set_reconciler.pod_matches vrs
   (controller_owner_ref vrs)], so [After_list_pods] returns it and the reconcile
   records it in [filtered_pods]. *)
let owned_pod ~index ~uid : Pod.t =
  let metadata =
    {
      (Object_meta.default ()) with
      Object_meta.name = Some ("vreplicaset-vrs1-" ^ string_of_int index);
      namespace = Some "ns";
      uid = Some (Common.Uid.of_int uid);
      resource_version = Some (Common.Resource_version.of_int 0);
      labels = Some app_labels;
      owner_references = Some [ vrs_owner_ref ];
    }
  in
  Pod.make ~metadata ~spec:(Some (Pod_spec.default ())) ~status:None

let owned_pod_ref ~index : Common.object_ref =
  { Common.kind = Pod.kind; name = "vreplicaset-vrs1-" ^ string_of_int index; namespace = "ns" }

(* De-vacuises #15 filtered_pods_invariant_matrix and #16 local_pods_are_bound_
   to_vrs_with_key (interesting = a non-empty [filtered_pods]): [vrs1] plus
   [existing] pods it already owns, all in etcd, so [After_list_pods] returns a
   non-empty list and the reconcile writes [filtered_pods = Some (_ :: _)]. When
   [existing > desired] the scale-DOWN [After_delete_pod] path also fires. Pods
   take uids [2..existing+1] (the CR is uid 1) and rvs [1..existing] (the CR is
   rv 0); [uid_counter] and [resource_version_counter = existing+1] sit strictly
   above them, so every stored rv is distinct and freshly issued. *)
let seed_with_pods ~desired ~existing ~fair : Cluster.cluster_state =
  let enabled = not fair in
  let base = Object_ref_map.add vrs_ref (Vreplica_set.marshal (vrs ~desired)) Object_ref_map.empty in
  let resources =
    List.fold_left
      (fun acc index ->
        Object_ref_map.add (owned_pod_ref ~index)
          (Dynamic_object.with_resource_version
             (Common.Resource_version.of_int (index + 1))
             (Pod.marshal (owned_pod ~index ~uid:(index + 2))))
          acc)
      base
      (List.init existing Fun.id)
  in
  make_state ~enabled ~resources
    ~uid_counter:(existing + 2)
    ~resource_version_counter:(existing + 1)

(* The ghost controller owner ref carried by the orphan pod: a controller owner
   reference to a vreplicaset named [ghost] that is NOT in etcd, so every owner
   ref of the pod is [owner_gone] and [Builtin_controllers.object_is_orphaned]
   holds. Its uid does not match the [vrs1] controller owner ref, so #7's
   [contains_co] guard is false and the invariant holds while non-vacuous. *)
let orphan_owner_ref : Owner_reference.t =
  {
    Owner_reference.block_owner_deletion = Some true;
    controller = Some true;
    kind;
    name = "ghost";
    uid = Common.Uid.of_int 999;
  }

(* De-vacuises #7 garbage_collector_does_not_delete_vrs_pods (interesting = an
   in-flight BuiltinController delete on a pod): [vrs1] plus one orphan pod whose
   sole (controller) owner references a uid absent from etcd, so the garbage
   collector's precondition fires and it issues a delete for the orphan. The
   orphan is uid 2 / rv 1 (the CR is uid 1 / rv 0), each rv distinct and below the
   [resource_version_counter], so the two stored rvs are freshly-issued. *)
let seed_with_orphan ~desired ~fair : Cluster.cluster_state =
  let enabled = not fair in
  let orphan_metadata =
    {
      (Object_meta.default ()) with
      Object_meta.name = Some "vreplicaset-orphan-0";
      namespace = Some "ns";
      uid = Some (Common.Uid.of_int 2);
      resource_version = Some (Common.Resource_version.of_int 0);
      labels = Some app_labels;
      owner_references = Some [ orphan_owner_ref ];
    }
  in
  let orphan = Pod.make ~metadata:orphan_metadata ~spec:(Some (Pod_spec.default ())) ~status:None in
  let orphan_ref : Common.object_ref =
    { Common.kind = Pod.kind; name = "vreplicaset-orphan-0"; namespace = "ns" }
  in
  let resources =
    Object_ref_map.empty
    |> Object_ref_map.add vrs_ref (Vreplica_set.marshal (vrs ~desired))
    |> Object_ref_map.add orphan_ref
         (Dynamic_object.with_resource_version (Common.Resource_version.of_int 1)
            (Pod.marshal orphan))
  in
  make_state ~enabled ~resources ~uid_counter:3 ~resource_version_counter:2

(* [enabled_successors] kept to the productive step families: an api-server step
   that actually consumes a message ([Api_server_step (Some _)]), a GC step, a
   controller step, a schedule step, a pod-monkey step, an external step. The no-op
   / failure / liveness-toggle families are dropped. The [Step.t] match is
   exhaustive (all 12 constructors, no wildcard). *)
let productive_successors (t : Cluster.t) (b : Bound.t)
    (s : Cluster.cluster_state) : (Step.t * Cluster.cluster_state) list =
  List.filter
    (fun ((step : Step.t), (_ : Cluster.cluster_state)) ->
      match step with
      | Step.Api_server_step recv -> Option.is_some recv
      | Step.Builtin_controllers_step _
      | Step.Controller_step _
      | Step.Schedule_controller_reconcile_step _
      | Step.Pod_monkey_step _
      | Step.External_step _ ->
        true
      | Step.Restart_controller_step _
      | Step.Disable_crash_step _
      | Step.Drop_req_step _
      | Step.Disable_req_drop_step
      | Step.Disable_pod_monkey_step
      | Step.Stutter_step ->
        false)
    (Cluster.enabled_successors b t s)

let is_quiescent (b : Bound.t) (s : Cluster.cluster_state) : bool =
  productive_successors cluster b s = []

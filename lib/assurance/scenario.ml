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
let vsts_named ~(name : string) ?(vct = false) ~(desired : int) () :
    V_stateful_set.t =
  let metadata = { vsts_metadata with Object_meta.name = Some name } in
  V_stateful_set.make ~metadata
    ~spec:
      {
        (Stateful_set.ss_spec_default ()) with
        Stateful_set.replicas = Some desired;
        selector;
        template;
        service_name = name;
        volume_claim_templates =
          (if vct then Some [ vsts_pvc_template ] else None);
      }
    ~status:None

(* [vsts ~desired ?vct ()] delegates to [vsts_named ~name:"vsts1"]. For that name
   [{ vsts_metadata with name = Some "vsts1" }] is [vsts_metadata] itself and
   [service_name = "vsts1"], so the result is BYTE-IDENTICAL to the former hardcoded
   body — the green P10/P11 battery is the behavior-preservation proof. *)
let vsts ~(desired : int) ?(vct = false) () : V_stateful_set.t =
  vsts_named ~name:"vsts1" ~vct ~desired ()

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
   is scheduled during exploration, exactly as for {!seed}).

   The three disruptor toggles are INDEPENDENT here ([vsts_seed] below is the
   all-three-together specialisation): [crash] is the controller's
   [crash_enabled] (Anvil's [RestartController] fault), [req_drop] the
   api-server transient-failure switch, [pod_monkey] the pod disruptor. P13
   needs them separable to isolate the crash dimension.

   Soundness of a seed with any flag FALSE (BUILD-SPEC-P13 §3): [Cluster.init]
   (cluster.ml:75-97) requires all three flags TRUE, so such a seed is not an
   init state. Exploring from it is still sound because every flag combination
   componentwise <= [(true, true, true)] is reachable from an init state by a
   prefix of [Disable_crash_step] / [Disable_req_drop_step] /
   [Disable_pod_monkey_step], each of which only flips its own flag
   (cluster.ml:337, :385, :445). So a violation found from such a seed is a
   violation of a genuinely reachable behaviour; a clean verdict is
   falsification-up-to-bounds of the SUFFIX behaviours starting there. The
   pre-existing [~fair:true] seeds already rest on exactly this argument (they
   are the all-disabled suffix).

   MEASURED (contra BUILD-SPEC-P13 §3, which predicts otherwise): even the
   all-faults-ON seed does NOT satisfy [Cluster.init], because [Api_server.init]
   (api_server.ml:73) demands an EMPTY etcd while the seed already holds the
   server-created CR. It satisfies every FAULT-FLAG conjunct of [Cluster.init],
   and that is the part P13 needs; the already-created CR rests on the same
   standing "a client created the CR first" argument every seed here rests on.
   See scenario.mli for the isolating measurement.

   [?vct] (P16, BUILD-SPEC-P16 section 4.3) threads to the {!vsts} CR builder:
   [true] puts a volumeClaimTemplate on the seeded CR, which is what makes the
   reconciler's PVC arm (and hence any [Get_request]) reachable. DEFAULT [false],
   so every pre-P16 call produces a byte-identical seed and every committed pin
   flows unchanged. The trailing [unit] is required for OCaml's optional-argument
   erasure: every other parameter is labelled, and an optional followed only by
   labels is unerasable (warning 16) - measured, not assumed; the spec's
   leading-position alternative does not compile. *)
let vsts_seed_faults ~desired ~crash ~req_drop ~pod_monkey ?(vct = false) () :
    Cluster.cluster_state =
  let created, _ =
    Api_server.handle_create_request vsts_installed
      {
        Api_method.namespace = "ns";
        obj = V_stateful_set.marshal (vsts ~desired ~vct ());
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
          crash_enabled = crash;
        }
        Imap.empty;
    network = { Network.in_flight = Message.Pool.empty };
    rpc_id_allocator = Message.Rpc_id_allocator.init ();
    req_drop_enabled = req_drop;
    pod_monkey_enabled = pod_monkey;
  }

(* {!vsts_seed_faults} with the three disruptor toggles gated TOGETHER by [fair]
   ([false] = full nondeterminism for safety, [true] = the fair suffix for ESR):
   a thin delegation with all three flags = [not fair], so behaviour is
   byte-identical to the pre-P13 body. *)
let vsts_seed ~desired ~fair : Cluster.cluster_state =
  vsts_seed_faults ~desired ~crash:(not fair) ~req_drop:(not fair)
    ~pod_monkey:(not fair) ()

(* {!vsts_seed_faults} plus one hand-built surplus Pod per element of
   [ordinals] (P22): the CR create is byte-for-byte the [vsts_seed_faults]
   chain (server stamps uid 1), then the pod creates are FOLDED over
   [ordinals], each a REAL [Api_server.handle_create_request] threading the
   api-server state; every response is discarded by design (seed
   construction, not protocol) and [vsts_seed_pods_intact] below is the
   ASSERTION that recovers what the discard drops.

   ONE READ OF THE LIVE CR SUPPLIES BOTH THE OWNER REF AND THE PARENT NAME
   (P22 review finding F3, second reviewer's arm): the stored CR is looked up
   at [vsts_ref], unmarshalled, and passed through
   [V_stateful_set.controller_owner_ref] - which COPIES [metadata.name] into
   the ref's [name] field (v_stateful_set.ml:173-184) - so the pod's parent
   name is that very field and the pod name can NEVER drift from the CR the
   reconciler reads (the former hardcoded ["vsts1"] could). The singleton
   owner-ref list replicates the reconciler's unexported
   [make_owner_references] (v_stateful_set_reconciler.ml:218-220), so its uid
   is the SERVER-STAMPED uid by construction, never forged (a mismatch would
   make the pod GC-orphaned, builtin_controllers.ml:64-81, and silently
   reproduce the G2 vacuity this seed removes).

   FAILURE IS NOW LOUD, NOT SILENT. If that read fails (unreachable: the CR
   create succeeds by construction) NO pod is created at all, so
   [vsts_seed_pods_intact] reds instead of the seed handing back a pod with
   an EMPTY owner-ref list - which [pod_filter] drops, emptying [condemned]
   and making the leg G2-vacuous-but-CLEAN, the exact failure this phase
   exists to eliminate.

   PRECONDITION (the caller's, checkable by [vsts_seed_pods_intact]):
   [ordinals] must be DISTINCT and each element >= [desired]. A repeated
   ordinal makes the second create an [Object_already_exists] no-op, whose
   response this fold discards, so the surplus pod count silently falls short;
   an ordinal < [desired] is not condemned at all. Cluster shape identical to
   [vsts_seed_faults], only the api-server resources differ. *)
let vsts_seed_with_pods ~desired ~ordinals ~crash ~req_drop ~pod_monkey
    ?(vct = false) () : Cluster.cluster_state =
  let created, _ =
    Api_server.handle_create_request vsts_installed
      {
        Api_method.namespace = "ns";
        obj = V_stateful_set.marshal (vsts ~desired ~vct ());
      }
      {
        Api_server.resources = Object_ref_map.empty;
        uid_counter = 1;
        resource_version_counter = 0;
      }
  in
  let cr_owner : Owner_reference.t option =
    Option.bind
      (Object_ref_map.find_opt vsts_ref created.Api_server.resources)
      (fun (obj : Dynamic_object.t) ->
        Result.fold (V_stateful_set.unmarshal obj)
          ~error:(fun _ -> None)
          ~ok:(fun (live : V_stateful_set.t) ->
            V_stateful_set.controller_owner_ref live))
  in
  let with_pods =
    Option.fold cr_owner ~none:created ~some:(fun (owner : Owner_reference.t) ->
        List.fold_left
          (fun (api : Api_server.state) (ord : int) ->
            let metadata =
              {
                (Object_meta.default ()) with
                Object_meta.name =
                  Some
                    (V_stateful_set_reconciler.pod_name
                       owner.Owner_reference.name ord);
                namespace = Some "ns";
                owner_references = Some [ owner ];
              }
            in
            let api', _ =
              Api_server.handle_create_request vsts_installed
                {
                  Api_method.namespace = "ns";
                  obj =
                    Pod.marshal
                      (Pod.make ~metadata ~spec:(Some (Pod_spec.default ()))
                         ~status:None);
                }
                api
            in
            api')
          created ordinals)
  in
  {
    Cluster.api_server = with_pods;
    controller_and_externals =
      Imap.add controller_id
        {
          Cluster.controller = Controller.init;
          external_ = None;
          crash_enabled = crash;
        }
        Imap.empty;
    network = { Network.in_flight = Message.Pool.empty };
    rpc_id_allocator = Message.Rpc_id_allocator.init ();
    req_drop_enabled = req_drop;
    pod_monkey_enabled = pod_monkey;
  }

(* The seed-integrity OBLIGATION of [vsts_seed_with_pods], as a total predicate
   (P22 review finding F3): every conjunct [pod_filter]
   (v_stateful_set_reconciler.ml:421-432) needs before an [ord >= desired] pod
   can land in [condemned] and make G2's premise fire. TRUE iff

   - [ordinals] are DISTINCT (a repeat makes the second create an
     [Object_already_exists] no-op whose response the seed discards, so a
     requested surplus pod is silently missing while every other conjunct still
     passes), and
   - the live CR is present at [vsts_ref] and unmarshals, and carries a name /
     namespace / uid, and
   - the live CR's replica count (the reconciler's own [~none:1] reading,
     :545-548) is non-negative, and
   - for EVERY requested ordinal: that ordinal is [>= replicas] (only those are
     CONDEMNED, :412 - a smaller one is [needed] and G2 never fires), the pod is
     present at its canonical ref ([Pod.kind], the CR's namespace,
     [pod_name parent ord]), carries EXACTLY ONE owner reference, that reference
     matches the CR's controller owner ref on every field [Owner_reference.equal]
     compares - uid (equal to the uid stored on the LIVE CR in this same state:
     READ, never the literal 1 - plus name, kind and the [controller] /
     [block_owner_deletion] flags, since [pod_filter] admits by full-ref equality
     and not by uid alone - and the pod's name round-trips through
     [V_stateful_set_reconciler.get_ordinal parent] back to that ordinal.

   Everything is read off the state passed in, so a caller can check its OWN
   seed; a [false] is exactly the G2-vacuous-but-CLEAN leg (pod dropped by
   [pod_filter] => [condemned] = [] => G2 [interesting] = 0 while the union gate,
   dominated by G1, still reports the leg clean). Parent name and uid are read
   from the live CR's metadata DIRECTLY, not from
   [V_stateful_set.controller_owner_ref], so the predicate does not reuse the
   builder's own derivation. Total: [Option.fold]/[Result.fold]/[List.for_all]
   only, no partial accessor, no exception. *)
let vsts_seed_pods_intact (s : Cluster.cluster_state) ~(ordinals : int list) :
    bool =
  let resources = s.Cluster.api_server.Api_server.resources in
  (* [pod_filter] admits a pod via [Object_meta.owner_references_contains]
     (object_meta.ml:72-75), i.e. [Owner_reference.equal] against the CR's
     controller owner ref - which compares [controller], [block_owner_deletion],
     [kind] and [name] as well as [uid] (owner_reference.ml:26-33). A uid-only
     check would therefore PASS a pod that [pod_filter] silently DROPS (wrong
     kind / wrong parent name / [controller = None]), i.e. the very
     G2-vacuous-but-CLEAN leg this predicate exists to catch. Every field is
     rebuilt from the LIVE CR's metadata plus the two flags the reconciler's
     [make_owner_references] stamps, NOT by calling
     [V_stateful_set.controller_owner_ref], so the check stays independent of
     the builder's own derivation. *)
  let owner_admissible ~(parent : string) ~(cr_uid : Common.Uid.t)
      (r : Owner_reference.t) : bool =
    Common.Uid.equal r.Owner_reference.uid cr_uid
    && String.equal r.Owner_reference.name parent
    && Common.equal_kind r.Owner_reference.kind V_stateful_set.kind
    && Option.equal Bool.equal r.Owner_reference.controller (Some true)
    && Option.equal Bool.equal r.Owner_reference.block_owner_deletion
         (Some true)
  in
  let pod_intact ~(parent : string) ~(ns : string) ~(cr_uid : Common.Uid.t)
      ~(replicas : int) (ord : int) : bool =
    let pname = V_stateful_set_reconciler.pod_name parent ord in
    (* [partition_pods] condemns only [ord >= replicas] (:412); a pod at a
       SMALLER ordinal is [needed], never condemned, so G2's premise never
       fires - the [ordinals] mis-parameterisation the builder documents as a
       caller precondition, now actually CHECKED here rather than assumed. *)
    ord >= replicas
    && Option.fold
         (Object_ref_map.find_opt
            { Common.kind = Pod.kind; namespace = ns; name = pname }
            resources)
         ~none:false
         ~some:(fun (obj : Dynamic_object.t) ->
           let owners : Owner_reference.t list =
             Option.value ~default:[]
               (Dynamic_object.metadata obj).Object_meta.owner_references
           in
           List.length owners = 1
           && List.for_all (owner_admissible ~parent ~cr_uid) owners
           && Option.fold
                (V_stateful_set_reconciler.get_ordinal parent pname)
                ~none:false
                ~some:(fun (parsed : int) -> parsed = ord))
  in
  List.compare_lengths (List.sort_uniq Int.compare ordinals) ordinals = 0
  && Option.fold
       (Object_ref_map.find_opt vsts_ref resources)
       ~none:false
       ~some:(fun (obj : Dynamic_object.t) ->
         Result.fold (V_stateful_set.unmarshal obj)
           ~error:(fun _ -> false)
           ~ok:(fun (live : V_stateful_set.t) ->
             let md : Object_meta.t = V_stateful_set.metadata live in
             let sp : Stateful_set.ss_spec = V_stateful_set.spec live in
             (* the reconciler's OWN replica reading, default included
                (:545-548): [None] means 1, and a NEGATIVE count sends the
                reconcile to [error_state] before [partition_pods] runs, so no
                pod is ever condemned. *)
             let replicas : int =
               Option.fold ~none:1 ~some:(fun (r : int) -> r)
                 sp.Stateful_set.replicas
             in
             replicas >= 0
             && Option.fold (Object_meta.name md) ~none:false
                  ~some:(fun (parent : string) ->
                    Option.fold (Object_meta.namespace md) ~none:false
                      ~some:(fun (ns : string) ->
                        Option.fold md.Object_meta.uid ~none:false
                          ~some:(fun (cr_uid : Common.Uid.t) ->
                            List.for_all
                              (pod_intact ~parent ~ns ~cr_uid ~replicas)
                              ordinals)))))

(* The multi-CR analogue of [vsts_seed]: one VStatefulSet [vstsN] per element of
   [desireds] (distinct names "vsts1".."vstsN" => distinct [Object_ref_map] keys),
   each admitted through a REAL [Api_server.handle_create_request] against a single
   fresh api-server, so every uid/rv is SERVER-STAMPED (never forged) and the
   counters advance strictly past every issued value — inv1
   ([etcd_objects_have_unique_uids]) stays true because each create bumps
   [uid_counter]. Distinct keys let the reachable graph reach
   [cardinal(ongoing) >= 2] (each CR admits its own concurrent ongoing reconcile
   under the single [controller_id]) — the P12 non-vacuity witness for
   [Invariants.unique_reconcile_id_invariant], unreachable from the single-CR
   [vsts_seed]. All CRs are the SAME kind, so [vsts_installed] is reused unchanged.
   The three disruptor toggles are INDEPENDENT here, exactly as in
   [vsts_seed_faults], and the same BUILD-SPEC-P13 §3 reachability argument makes
   an any-flag-false seed sound (the Disable_* prefix from an init state). The
   VSTS analogue of [seed_multi]. *)
let vsts_seed_multi_faults ~(desireds : int list) ~(crash : bool)
    ~(req_drop : bool) ~(pod_monkey : bool) : Cluster.cluster_state =
  let created =
    List.fold_left
      (fun (api : Api_server.state) ((i, desired) : int * int) ->
        let name = "vsts" ^ string_of_int i in
        let api', _ =
          Api_server.handle_create_request vsts_installed
            {
              Api_method.namespace = "ns";
              obj = V_stateful_set.marshal (vsts_named ~name ~desired ());
            }
            api
        in
        api')
      {
        Api_server.resources = Object_ref_map.empty;
        uid_counter = 1;
        resource_version_counter = 0;
      }
      (List.mapi (fun idx d -> (idx + 1, d)) desireds)
  in
  {
    Cluster.api_server = created;
    controller_and_externals =
      Imap.add controller_id
        {
          Cluster.controller = Controller.init;
          external_ = None;
          crash_enabled = crash;
        }
        Imap.empty;
    network = { Network.in_flight = Message.Pool.empty };
    rpc_id_allocator = Message.Rpc_id_allocator.init ();
    req_drop_enabled = req_drop;
    pod_monkey_enabled = pod_monkey;
  }

(* {!vsts_seed_multi_faults} with the three disruptor toggles gated TOGETHER by
   [fair], exactly as [vsts_seed] does for [vsts_seed_faults]: a thin delegation
   with all three flags = [not fair], byte-identical to the pre-P13 body. *)
let vsts_seed_multi ~(desireds : int list) ~(fair : bool) :
    Cluster.cluster_state =
  vsts_seed_multi_faults ~desireds ~crash:(not fair) ~req_drop:(not fair)
    ~pod_monkey:(not fair)

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

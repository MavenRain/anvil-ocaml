(* BUILD-SPEC-P20 §2: the VSTS pod-monkey RELY condition family - the port's
   first ASSUMPTION register. Every family shipped before this one (P14-P19,
   plus the older [Invariants] / [Vsts_invariants] cores) asserts something
   upstream PROVES; these three members are what upstream ASSUMES about the
   environment and never discharges. Upstream file:
   [vstatefulset_controller/trusted/rely_guarantee.rs], threaded into the
   composition record's [environment_rely] slot
   (composition/vstatefulset_reconciler.rs:23).

   - R1 vsts_rely_create_req (:57-73), LIFTED over monkey-sourced creates
   - R2 vsts_rely_update_req (:76-90), LIFTED over monkey-sourced updates
   - R3 vsts_rely_conditions_pod_monkey (:17-29), upstream's own always-member

   All three traverse [Message.Pool.distinct (Cluster.in_flight s)] - the
   [inv_self] projection precedent (vsts_invariants.ml:152) and P19's
   (msg_provenance.ml:22-23). Upstream's forall at :19-23 quantifies over
   [s.in_flight()] ALONE (no [pending_req_msg] conjunct), so the port's pool is
   the exact analogue. Every rendering decision and every deviation is disclosed
   in the .mli. *)

let msgs (s : Cluster.cluster_state) : Message.t list =
  Message.Pool.distinct (Cluster.in_flight s)

(* The [Api_request] payload projection (the [inv_self] helper shape,
   vsts_invariants.ml:156-162; P19 msg_provenance.ml:28-33): [Some r] on a
   request, [None] on the three non-request contents - an exhaustive 4-arm
   match, no wildcard. *)
let api_request_of (m : Message.t) : Api_method.api_request option =
  match m.content with
  | Message.Api_request r -> Some r
  | Message.Api_response _ | Message.External_request _
  | Message.External_response _ ->
    None

(* Upstream's shared premise at :19-23 / :24-25: [msg.src is PodMonkey] AND
   [msg.content is APIRequest]. [None] means the message is out of premise, so
   every member's [holds] folds it to [true] and every [interesting] folds it to
   [false]. The five src arms are spelled out (no wildcard). *)
let monkey_request_of (m : Message.t) : Api_method.api_request option =
  match m.src with
  | Message.Pod_monkey -> api_request_of m
  | Message.Api_server | Message.Builtin_controller | Message.Controller _
  | Message.External _ ->
    None

(* Upstream [has_vsts_prefix] (proof/predicate.rs:40-42):
   [exists suffix. name == VStatefulSetView::kind()->CustomResourceKind_0 + "-"
   + suffix], i.e. a literal prefix test. The literal is used rather than
   [V_stateful_set.kind_name ^ "-"] on purpose (.mli): the family must stay
   pinned to the string the reconciler actually MINTS
   (v_stateful_set_reconciler.ml:191 / :207), which is itself a hard-coded
   literal. The three-way agreement is a TEST pin, not a comment. *)
let vsts_prefix : string = "vstatefulset-"

let has_vsts_prefix (name : string) : bool =
  String.starts_with ~prefix:vsts_prefix name

(* The §2.1 owner-ref existential collapse, right-hand side. Upstream
   [!exists |vsts: VStatefulSetView| md.owner_references_contains(
   vsts.controller_owner_ref())] quantifies over an infinite type;
   [V_stateful_set.controller_owner_ref] (v_stateful_set.ml:173-184) FIXES
   [block_owner_deletion = Some true] (:178), [controller = Some true] (:179)
   and [kind] (:180), leaving only [name] (:181) and [uid] (:182) free, and
   [Owner_reference.t] has exactly those five fields (owner_reference.mli:4-10).
   Ranging over all vsts views makes name/uid range freely, so the existential
   is EQUIVALENT to "some owner ref carries the three pinned fields". *)
let is_vsts_controller_owner_ref (r : Owner_reference.t) : bool =
  Option.value ~default:false r.block_owner_deletion
  && Owner_reference.is_controller r
  && Common.equal_kind r.kind V_stateful_set.kind

(* [Object_meta.owner_references] is [Owner_reference.t list option]
   (object_meta.mli:16). [None] = no owner refs at all, so the existential is
   [false] there - the reading of [Object_meta.owner_references_contains]
   itself (object_meta.mli:94-96) and of shipped [inv_self]
   (vsts_invariants.ml:193). *)
let vsts_controller_owned (md : Object_meta.t) : bool =
  Option.fold md.owner_references ~none:false
    ~some:(List.exists is_vsts_controller_owner_ref)

(* R1 conjunct (a), upstream :61-66: the name test reads [metadata.name] when
   [is Some], ELSE [metadata.generate_name] (and a missing generate_name makes
   the inner conjunction false). Rendered with nested [Option.fold], never a
   [match] on an option. The eager [~none:] arm is a pure, non-recursive fold,
   so the eagerness costs nothing. *)
let name_or_generate_has_vsts_prefix (md : Object_meta.t) : bool =
  Option.fold md.name
    ~none:(Option.fold md.generate_name ~none:false ~some:has_vsts_prefix)
    ~some:has_vsts_prefix

(* R1's per-request predicate, upstream [vsts_rely_create_req] (:57-73). The
   kind dispatch is upstream's [match req.obj.kind] at :58, with the [_ => true]
   at :71 spelled out over the remaining NINE [Common.kind] constructors
   (common.mli:35-46). The object's kind is read as [Dynamic_object.kind r.obj]
   directly - [create_request_key] is [Res.t]-typed hence partial
   (api_method.mli:137-139) and a total classifier must not consume it (the P19
   M2 precedent, msg_provenance.ml:38-44). *)
let rely_create_req (r : Api_method.create_request) : bool =
  let md : Object_meta.t = Dynamic_object.metadata r.obj in
  match Dynamic_object.kind r.obj with
  | Common.Pod | Common.Persistent_volume_claim ->
    (* no name conflict (:61-66) *)
    (not (name_or_generate_has_vsts_prefix md))
    (* no ownership interference (:68-69) *)
    && not (vsts_controller_owned md)
  | Common.Config_map | Common.Custom_resource _ | Common.Daemon_set
  | Common.Role | Common.Role_binding | Common.Secret | Common.Service
  | Common.Service_account | Common.Stateful_set ->
    true

(* R2's per-request STATE predicate, upstream [vsts_rely_update_req] (:76-90):
   conjunct 2 (:82-83) reads [s.resources()[req.key()]], so this one is a
   StatePred, not a pure message predicate. The kind dispatch is upstream's
   [match req.obj.kind] at :78 - the OBJECT's kind, not the key's; the port
   reads [Dynamic_object.kind r.obj] directly (the two coincide,
   [update_request_key] being [{obj.kind; namespace; name}],
   api_method.mli:121-122). Missing-key rendering: Verus [s.resources()[k]] on
   an absent key is an arbitrary total-map value, so the conjunct is
   unconstrained there; the port folds [~none:true] and DISCLOSES it (.mli). *)
let rely_update_req (s : Cluster.cluster_state) (r : Api_method.update_request)
    : bool =
  match Dynamic_object.kind r.obj with
  | Common.Pod | Common.Persistent_volume_claim ->
    (* (a) the request name is not vsts-prefixed (:80) *)
    (not (has_vsts_prefix r.name))
    (* (b) the STORED object is not vsts-owned (:82-83) *)
    && Option.fold
         (Cluster.lookup_resource s (Api_method.update_request_key r))
         ~none:true
         ~some:(fun (stored : Dynamic_object.t) ->
           not (vsts_controller_owned (Dynamic_object.metadata stored)))
    (* (c) the NEW object does not become vsts-owned (:85) *)
    && not (vsts_controller_owned (Dynamic_object.metadata r.obj))
  | Common.Config_map | Common.Custom_resource _ | Common.Daemon_set
  | Common.Role | Common.Role_binding | Common.Secret | Common.Service
  | Common.Service_account | Common.Stateful_set ->
    true

(* R1's and R2's [interesting] premise mirrors (P14 N3 - no borrowing): each
   member fires exactly on its own lifted arm. Both classifiers are exhaustive
   over the nine [Api_method.api_request] constructors (api_method.mli:103-113). *)
let is_create_request (req : Api_method.api_request) : bool =
  let open Api_method in
  match req with
  | Create_request _ -> true
  | Get_request _ | List_request _ | Delete_request _ | Update_request _
  | Update_status_request _ | Get_then_delete_request _
  | Get_then_update_request _ | Get_then_update_status_request _ ->
    false

let is_update_request (req : Api_method.api_request) : bool =
  let open Api_method in
  match req with
  | Update_request _ -> true
  | Get_request _ | List_request _ | Create_request _ | Delete_request _
  | Update_status_request _ | Get_then_delete_request _
  | Get_then_update_request _ | Get_then_update_status_request _ ->
    false

let rely_sources : string list =
  [
    "vstatefulset_controller/trusted/rely_guarantee.rs:57";
    "vstatefulset_controller/trusted/rely_guarantee.rs:76";
    "vstatefulset_controller/trusted/rely_guarantee.rs:17";
  ]

let rely_family : Invariants.invariant list =
  let r1 =
    {
      Invariants.name = "vsts_rely_create_req";
      source = "vstatefulset_controller/trusted/rely_guarantee.rs:57";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              Option.fold (monkey_request_of m) ~none:true
                ~some:(fun (req : Api_method.api_request) ->
                  let open Api_method in
                  match req with
                  | Create_request r -> rely_create_req r
                  | Get_request _ | List_request _ | Delete_request _
                  | Update_request _ | Update_status_request _
                  | Get_then_delete_request _ | Get_then_update_request _
                  | Get_then_update_status_request _ ->
                    true))
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) ->
              Option.fold (monkey_request_of m) ~none:false
                ~some:is_create_request)
            (msgs s));
    }
  in
  let r2 =
    {
      Invariants.name = "vsts_rely_update_req";
      source = "vstatefulset_controller/trusted/rely_guarantee.rs:76";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              Option.fold (monkey_request_of m) ~none:true
                ~some:(fun (req : Api_method.api_request) ->
                  let open Api_method in
                  match req with
                  | Update_request r -> rely_update_req s r
                  | Get_request _ | List_request _ | Create_request _
                  | Delete_request _ | Update_status_request _
                  | Get_then_delete_request _ | Get_then_update_request _
                  | Get_then_update_status_request _ ->
                    true))
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) ->
              Option.fold (monkey_request_of m) ~none:false
                ~some:is_update_request)
            (msgs s));
    }
  in
  (* R3 is upstream's actual always-member, and its [_ => true] at :26
     ("Deletion/UpdateStatus requests are allowed") is LOAD-BEARING content, not
     a default: the seven non-Create/Update arms are spelled out returning
     [true]. A wildcard here would erase the phase's own subject matter. *)
  let r3 =
    {
      Invariants.name = "vsts_rely_conditions_pod_monkey";
      source = "vstatefulset_controller/trusted/rely_guarantee.rs:17";
      holds =
        (fun s ->
          List.for_all
            (fun (m : Message.t) ->
              Option.fold (monkey_request_of m) ~none:true
                ~some:(fun (req : Api_method.api_request) ->
                  let open Api_method in
                  match req with
                  | Create_request r -> rely_create_req r
                  | Update_request r -> rely_update_req s r
                  | Get_request _ | List_request _ | Delete_request _
                  | Update_status_request _ | Get_then_delete_request _
                  | Get_then_update_request _
                  | Get_then_update_status_request _ ->
                    true))
            (msgs s));
      interesting =
        (fun s ->
          List.exists
            (fun (m : Message.t) -> Option.is_some (monkey_request_of m))
            (msgs s));
    }
  in
  [ r1; r2; r3 ]

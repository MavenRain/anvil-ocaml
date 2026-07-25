(** Anvil source: controllers/vstatefulset_controller/model/reconciler.rs
    ([reconcile_core] + helpers) and trusted/step.rs (the step enum, view form).

    The typed {!Reconciler.RECONCILER} for VStatefulSet: a single controller that
    manages Pods and their PersistentVolumeClaims directly. The pure spec-level
    state machine, with Anvil's proof-discharged unwraps replaced by explicit
    guards routed to {!error_state}; on a well-formed CR those guards never fire,
    so the ported core takes exactly Anvil's branches.

    The step machine alternates ACTION steps (each emits one request and advances
    to its [After_*] step) with [After_*] steps (each consumes the response and,
    via a dispatch helper, sets the next action step and returns no request). *)

type step =
  | Init
  | After_list_pod
  | Get_pvc
  | After_get_pvc
  | Create_pvc
  | After_create_pvc
  | Skip_pvc
  | Create_needed
  | After_create_needed
  | Update_needed
  | After_update_needed
  | Delete_condemned
  | After_delete_condemned
  | Delete_outdated
  | After_delete_outdated
  | Done
  | Error
      (** Anvil [VStatefulSetReconcileStepView] (step.rs), view form: the 17
          flat steps of the create/update/scale-down/prune pipeline. *)

val step_equal : step -> step -> bool
(** Structural equality on {!step}. *)

val step_to_json : step -> Yojson.Safe.t
(** Encode a step as [{ "step": <tag> }]. Used by the pack's reconcile-state
    codec. *)

val step_of_json : Yojson.Safe.t -> step Res.t
(** Inverse of {!step_to_json}; an unknown tag is a {!Err.Decode_error}. *)

type s = {
  reconcile_step : step;
  needed : Pod.t option list;
  needed_index : int;
  condemned : Pod.t list;
  condemned_index : int;
  pvcs : Persistent_volume_claim.t list;
  pvc_index : int;
}
(** Anvil [VStatefulSetReconcileState]: the step plus the pod/pvc cursors carried
    across the round. [needed] is indexed by ordinal [0..replicas-1] ([None] when
    the pod is absent); [condemned] holds ordinal [>= replicas] pods, descending
    by ordinal; [pvcs] holds the PVCs of the current needed pod (reset per pod).
    The record is exposed so tests can inspect the cursors. *)

val init : s
(** The local state a reconcile round starts from: {!Init} with empty cursors. *)

val reconcile_init_state : unit -> s
(** Anvil [reconcile_init_state]: {!init}. *)

val error_state : s -> s
(** Anvil [error_state]: move the reconcile to {!Error}. Every honest-unwrap
    guard routes here. *)

val reconcile_core :
  cr:V_stateful_set.t ->
  resp:Io.void Io.response_view option ->
  state:s ->
  s * Io.void Io.request_view option
(** Anvil [reconcile_core]: the pure step function. All 17 step arms are
    enumerated; no external I/O ([ereq = eresp = Io.void]). *)

val reconcile_done : s -> bool
(** Anvil [reconcile_done]: the step is {!Done}. *)

val reconcile_error : s -> bool
(** Anvil [reconcile_error]: the step is {!Error}. *)

val pod_name_label : string
(** Reserved label ["statefulset.kubernetes.io/pod-name"] the controller stamps
    on managed pods. *)

val ordinal_label : string
(** Reserved label ["apps.kubernetes.io/pod-index"] carrying the pod ordinal. *)

val pod_name : string -> int -> string
(** Anvil [pod_name parent ord]: ["vstatefulset-" ^ parent ^ "-" ^ ord]. *)

val pvc_name : string -> string -> int -> string
(** Anvil [pvc_name tmpl_name vsts_name ord]:
    ["vstatefulset-" ^ tmpl_name ^ "-" ^ vsts_name ^ "-" ^ ord]. *)

val get_ordinal : string -> string -> int option
(** Anvil [get_ordinal parent name]: parse the ordinal out of a
    ["vstatefulset-<parent>-<ord>"] name; [None] on a non-matching name or a
    non-numeric suffix. *)

val partition_pods :
  string -> int -> Pod.t list -> Pod.t option list * Pod.t list
(** Anvil partition: [(needed, condemned)] — the pod (or absence) at each ordinal
    [0..replicas-1], and every filtered pod at ordinal [>= replicas] descending
    by ordinal. *)

val make_pod : V_stateful_set.t -> int -> Pod.t
(** Anvil [make_pod cr ordinal]: the pod for [ordinal] built from the CR template
    with its stamped identity and per-ordinal PVC volumes. *)

val make_pvcs : V_stateful_set.t -> int -> Persistent_volume_claim.t list
(** Anvil [make_pvcs cr ord]: the [ord]-specialised PVCs, one per
    volumeClaimTemplate. *)

val update_identity : V_stateful_set.t -> Pod.t -> int -> Pod.t
(** Anvil [update_identity]: stamp the pod-name / ordinal labels, re-assert owner
    refs and template annotations, and clear finalizers / deletion mark. *)

val pod_spec_matches : V_stateful_set.t -> Pod.t -> bool
(** Anvil [pod_spec_matches]: the pod's spec equals the template spec once the
    controller-injected [volumes]/[hostname]/[subdomain] are ignored. *)

val get_largest_unmatched_pods :
  V_stateful_set.t -> Pod.t option list -> Pod.t option
(** Anvil: the largest-ordinal needed pod whose spec no longer matches the
    template ([None] when all match). *)

(** The reconciler as a {!Reconciler.RECONCILER}, re-exporting the four members
    at [ereq = eresp = Io.void] so the pack can erase it via {!Erase.Void_erase}. *)
module R :
  Reconciler.RECONCILER
    with type k = V_stateful_set.t
     and type s = s
     and type ereq = Io.void
     and type eresp = Io.void

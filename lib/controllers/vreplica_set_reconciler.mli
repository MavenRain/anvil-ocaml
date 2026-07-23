(** Anvil source: controllers/vreplicaset_controller/model/reconciler.rs
    ([reconcile_core] + helpers) and trusted/step.rs (the step enum, view form).

    The typed {!Reconciler.RECONCILER} for VReplicaSet. The pure spec-level state
    machine, with Anvil's proof-discharged unwraps replaced by explicit guards
    routed to {!error_state}; on a well-formed CR those guards never fire, so the
    ported core takes exactly Anvil's branches. *)

type step =
  | Init
  | After_list_pods
  | After_create_pod of int
  | After_delete_pod of int
  | After_update_vrs_status
  | Done
  | Error
      (** Anvil [VReplicaSetReconcileStepView] (step.rs), view form. The [int]
          payloads are Anvil naturals, always [>= 0] by construction. *)

val step_equal : step -> step -> bool
(** Structural equality on {!step}. *)

val step_to_json : step -> Yojson.Safe.t
(** Encode a step as [{ "step": <tag>, "diff"?: int }] ([diff] only for the two
    [After_*_pod] steps). Used by the pack's reconcile-state codec. *)

val step_of_json : Yojson.Safe.t -> step Res.t
(** Inverse of {!step_to_json}; an unknown tag is a {!Err.Decode_error}. *)

type s = { reconcile_step : step; filtered_pods : Pod.t list option }
(** Anvil [VReplicaSetReconcileState]: the current step plus the pods captured at
    list time (retained across a scale-down so the delete loop can index them).
    The record is exposed so tests can inspect [reconcile_step]. *)

val error_state : s -> s
(** Anvil [error_state]: move the reconcile to {!Error}. Every honest-unwrap
    guard routes here. *)

val reconcile_init_state : unit -> s
(** Anvil [reconcile_init_state]: [{ reconcile_step = Init; filtered_pods = None }]. *)

val reconcile_core :
  cr:Vreplica_set.t ->
  resp:Io.void Io.response_view option ->
  state:s ->
  s * Io.void Io.request_view option
(** Anvil [reconcile_core]: the pure step function. All seven step arms are
    enumerated; no external I/O ([ereq = eresp = Io.void]). *)

val reconcile_done : s -> bool
(** Anvil [reconcile_done]: the step is {!Done}. *)

val reconcile_error : s -> bool
(** Anvil [reconcile_error]: the step is {!Error}. *)

val has_vrs_prefix : string -> bool
(** Anvil name predicate: [name] has the ["vreplicaset-"] prefix (the exact
    realisation of Anvil's [exists suffix. name = kind ^ "-" ^ suffix]). *)

val objects_to_pods : Dynamic_object.t list -> Pod.t list option
(** Anvil [objects_to_pods]: [Some] all-unmarshalled pods, or [None] if any
    element is not a pod. *)

val pod_matches : Vreplica_set.t -> Owner_reference.t -> Pod.t -> bool
(** Anvil [pod_filter] conjuncts: owner-ref present, selector matches labels, not
    being deleted, name carries the ["vreplicaset-"] prefix. *)

val filter_pods : Pod.t list -> Vreplica_set.t -> Owner_reference.t -> Pod.t list
(** Anvil [filter_pods]: keep the pods for which {!pod_matches} holds. *)

val pod_generate_name : Vreplica_set.t -> string option
(** Anvil [pod_generate_name]: ["vreplicaset-" ^ name ^ "-"]; [None] on the
    honest missing-name guard. *)

val make_pod : Vreplica_set.t -> Pod.t option
(** Anvil [make_pod]: a pod from the vrs template metadata/spec, generate-name,
    and controller owner reference; [None] on any honest unwrap guard. *)

val update_vrs_replicas :
  s -> Vreplica_set.t -> s * Io.void Io.request_view option
(** Anvil [update_vrs_replicas]: with exactly one controller owner reference,
    set [status.replicas] and issue a status update ({!After_update_vrs_status});
    otherwise route to {!error_state}. *)

(** The reconciler as a {!Reconciler.RECONCILER}, re-exporting the four members
    at [ereq = eresp = Io.void] so the pack can erase it via {!Erase.Void_erase}. *)
module R :
  Reconciler.RECONCILER
    with type k = Vreplica_set.t
     and type s = s
     and type ereq = Io.void
     and type eresp = Io.void

(* Anvil source: kubernetes_cluster/spec/cluster.rs (the [Step] enum, line 75).

   The binding variable the compound cluster state machine chooses in each
   transition: which host acts and with what input. {!Cluster.next_step} matches
   on this exhaustively (all twelve arms, no [_ ->]), dispatching each to the
   corresponding host action's [forward]. The payloads are exactly Anvil's:
   [Option<Message>] for message-consuming hosts, controller/external ids as
   [int], the pod-monkey's target [PodView], and unit for the parameterless
   disable / stutter steps. *)

type t =
  | Api_server_step of Message.t option
      (** Anvil [APIServerStep(Option<Message>)]: the api server handles one
          request message (or [None]). *)
  | Builtin_controllers_step of Builtin_controllers.choice * Common.object_ref
      (** Anvil [BuiltinControllersStep((BuiltinControllerChoice, ObjectRef))]:
          a builtin controller (the GC) acts on one object key. *)
  | Controller_step of int * Message.t option * Common.object_ref option
      (** Anvil [ControllerStep((int, Option<Message>, Option<ObjectRef>))]: the
          controller [int] handles a response (or [None]) for a scheduled cr
          key. *)
  | Schedule_controller_reconcile_step of int * Common.object_ref
      (** Anvil [ScheduleControllerReconcileStep((int, ObjectRef))]: schedule
          controller [int] to reconcile the object key. *)
  | Restart_controller_step of int
      (** Anvil [RestartControllerStep(int)]: reset controller [int] to its
          initial state (crash/restart model). *)
  | Disable_crash_step of int
      (** Anvil [DisableCrashStep(int)]: stop controller [int] from crashing
          (liveness constraint). *)
  | Drop_req_step of Message.t * Api_method.api_error
      (** Anvil [DropReqStep((Message, APIError))]: drop a request to the api
          server, returning [APIError] to the sender (transient failure). *)
  | Disable_req_drop_step
      (** Anvil [DisableReqDropStep]: stop the network dropping requests
          (liveness constraint). *)
  | Pod_monkey_step of Pod.t
      (** Anvil [PodMonkeyStep(PodView)]: the pod monkey creates/updates/deletes
          a pod. *)
  | Disable_pod_monkey_step
      (** Anvil [DisablePodMonkeyStep]: stop the pod monkey (liveness
          constraint). *)
  | External_step of int * Message.t option
      (** Anvil [ExternalStep((int, Option<Message>))]: the external system of
          controller [int] handles a message (or [None]). *)
  | Stutter_step
      (** Anvil [StutterStep]: do nothing (keeps [always(next)] true). *)

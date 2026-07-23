(* Anvil source: kubernetes_cluster/spec/builtin_controllers/
   {types.rs, state_machine.rs, garbage_collector.rs}.

   The builtin-controllers host. Anvil currently models exactly one builtin
   controller, the garbage collector, so both [choice] and [step] are
   single-variant; they are matched exhaustively (no [_ ->]) so a future variant
   is a compile error. The host state is [unit]: all data rides in the action
   input/output. The GC forms a single unconditional [DeleteRequest] MESSAGE to
   the api server (dst [Api_server]); it never mutates [resources] itself. Anvil
   binds [resources[key].metadata.owner_references->0] at the top of the
   precondition (garbage_collector.rs:20) before the [is Some] clause; a strict
   OCaml port must guard [contains_key] and [is Some] BEFORE forcing that
   projection, which the combinator nesting below does (no partial unwrap). *)

type choice = Garbage_collector

let equal_choice (a : choice) (b : choice) : bool =
  match (a, b) with Garbage_collector, Garbage_collector -> true

type step = Run_garbage_collector

type state = unit

type action_input = {
  choice : choice;
  key : Common.object_ref;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
  resources : Dynamic_object.t Object_ref_map.t;
}

type action_output = {
  send : Message.Pool.t;
  rpc_id_allocator : Message.Rpc_id_allocator.t;
}

(* Anvil garbage_collector.rs:22: [input.choice is GarbageCollector]. Exhaustive
   single-arm match (no wildcard) rather than a derived [is]-discriminant. *)
let choice_is_garbage_collector (c : choice) : bool =
  match c with Garbage_collector -> true

(* Anvil garbage_collector.rs:31-35: the owner referred to by [orf] (resolved via
   [owner_reference_to_object_reference] to an [ObjectRef] in [namespace]) is
   "gone" -- either absent from [resources] (:32), or present with a [uid]
   different from the one the owner reference records (:35). A [None] stored uid
   is a mismatch too ([None <> Some _]). *)
let owner_gone (resources : Dynamic_object.t Object_ref_map.t) (namespace : string)
    (orf : Owner_reference.t) : bool =
  let owner_key = Owner_reference.to_object_reference orf ~namespace in
  Object_ref_map.find_opt owner_key resources
  |> Option.fold ~none:true
       ~some:(fun (owner : Dynamic_object.t) ->
         let uid_matches =
           Option.fold ~none:false
             ~some:(fun u -> Common.Uid.equal u orf.uid)
             (Dynamic_object.metadata owner).uid
         in
         not uid_matches)

(* Anvil garbage_collector.rs:26-36: the object exists and carries a non-empty
   owner-references sequence (clauses 3 [is Some] and 4 [len > 0] kept as
   separate guards), and EVERY owner reference is [owner_gone] (the object is
   fully orphaned). If even one owner reference resolves to a live matching-uid
   owner, the GC does not fire. *)
let object_is_orphaned (resources : Dynamic_object.t Object_ref_map.t)
    (key : Common.object_ref) : bool =
  Object_ref_map.find_opt key resources
  |> Option.fold ~none:false
       ~some:(fun (obj : Dynamic_object.t) ->
         (Dynamic_object.metadata obj).owner_references
         |> Option.fold ~none:false
              ~some:(fun (refs : Owner_reference.t list) ->
                let non_empty = match refs with [] -> false | _ :: _ -> true in
                non_empty && List.for_all (owner_gone resources key.namespace) refs))

(* Anvil garbage_collector.rs:22-36. Clause 2 ([resources.contains_key]) is kept
   explicitly alongside {!object_is_orphaned} (which folds contains_key + is Some
   + len + the forall) so the port mirrors the source clause by clause. *)
let precondition (input : action_input) (_s : state) : bool =
  choice_is_garbage_collector input.choice
  && Object_ref_map.mem input.key input.resources
  && object_is_orphaned input.resources input.key

(* Anvil garbage_collector.rs:38-53. [preconditions.uid] is the target object's
   current uid ([resources[key].metadata.uid], :42); the [find_opt]/[map]/[join]
   completes the Verus map-index totally (the precondition guarantees presence,
   so the [None] default is unreachable). [allocate] returns [(advanced, id)]:
   the message carries the current [id] (:46) and the output the [advanced]
   allocator (:50). *)
let transition (input : action_input) (_s : state) : state * action_output =
  let uid =
    Object_ref_map.find_opt input.key input.resources
    |> Option.map (fun (obj : Dynamic_object.t) -> (Dynamic_object.metadata obj).uid)
    |> Option.join
  in
  let preconditions : Api_method.preconditions =
    { Api_method.uid; resource_version = None }
  in
  let advanced, allocated =
    Message.Rpc_id_allocator.allocate input.rpc_id_allocator
  in
  let content = Message.delete_req_msg_content input.key (Some preconditions) in
  let delete_req_msg = Message.built_in_controller_req_msg allocated content in
  ((), { send = Message.Pool.singleton delete_req_msg; rpc_id_allocator = advanced })

let run_garbage_collector : (state, action_input, action_output) Action.t =
  { precondition; transition }

let init (_s : state) : bool = true

let step_to_action (step : step) : (state, action_input, action_output) Action.t =
  match step with Run_garbage_collector -> run_garbage_collector

let state_machine :
    (state, action_input, action_input, action_output, step) State_machine.t =
  {
    State_machine.init;
    step_to_action;
    action_input = (fun (_step : step) (input : action_input) -> input);
  }

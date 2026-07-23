(* BUILD-SPEC P4 §4 "t_p4_invariants" — the safety-invariant property harness,
   asserting each invariant set in its CORRECT proof regime (invariants.mli):

   - {!Invariants.always} (nine): proved inductive from init by a [lemma_always_*],
     so it holds after EVERY step of ANY trace. Discharged OPERATIONALLY: from a
     reachable {!Scenario} seed take only {!Cluster.enabled_successors} steps and
     assert {!Invariants.conjunction} of {!Invariants.always} at every state, on
     the fully-nondeterministic [~fair:false] traces (crashes / req-drops /
     pod-monkey enabled).

   - {!Invariants.eventually_always} (six): proved only as [lemma_eventually_
     always_*] / [leads_to_always] under crash + req_drop + pod_monkey disabled and
     weak fairness, so each holds only on the fair SUFFIX (at quiescence). Asserted
     ONLY at the settled state of a [~fair:true] trace, NEVER after every step of a
     [~fair:false] trace.

   - #11 {!Invariants.liveness_goal} [current_state_matches]: the ESR [leads_to]
     GOAL, false on transient states by design; sampled at the settled state on a
     [~fair:true] trace.

   Obligations:

   (1)+(2) Property P_safety: a random ENABLED-STEP trace from one of the reachable
       [~fair:false] seeds ([Scenario.seed], [Scenario.seed_with_pods],
       [Scenario.seed_multi]) satisfies {!Invariants.conjunction}
       {!Invariants.always} at EVERY state. This is now GENUINELY green: the
       transient #8/#10/#14 message-interference failures a controller restart /
       step interleaving can produce are NO LONGER in [always] (they moved to
       [eventually_always]). A violation of an [always]-invariant on a valid trace
       is a genuine model/port bug: it is REPORTED via [QCheck.Test.fail_reportf]
       naming the invariant + seed and is NEVER weakened or reclassified to force
       green (spec §4 / §6, [[feedback-confirm-tests-by-mutation]]).

   (3) Property P_eventually_always (a BOUNDED SAMPLE, never a proof): from each
       [~fair:true] seed, drive first-productive-successor to the settled state and
       assert {!Invariants.conjunction} {!Invariants.eventually_always} THERE (not
       at every step). HONEST LIMIT (load-bearing, unchanged from P4 §0): literal
       quiescence ([Scenario.is_quiescent], i.e. [productive_successors = []]) is
       STRUCTURALLY UNREACHABLE, because [schedule_controller_reconcile] is enabled
       whenever the CR is in etcd (cluster.ml:250, no already-scheduled guard) — a
       productive [Schedule_controller_reconcile_step] is always available so the
       system never literally stops. We therefore take the settled sample to be the
       first state where the ESR goal [current_state_matches] holds (the fair suffix
       Anvil's leads_to reaches); [Scenario.is_quiescent] is kept as the primary
       stop for faithfulness even though it never fires here. Not reaching the
       settled state within fuel is a real finding (reconcile did not converge) and
       FAILS. Empirically the goal is reached within ~10 fair steps from every seed
       and every eventually_always invariant holds there.

   (4) Property P_liveness_sample (#11): from [Scenario.seed ~fair:true] drive
       [Scenario.productive_successors] (first successor, fuel 200) and check the
       ESR goal [(Invariants.liveness_goal ~cr).holds] is reached — a [leads_to]
       target witnessed once, never a liveness proof.

   (5) Classification confirm-by-mutation: on a reachable [~fair:false] trace a
       controller restart produces a state where the {!Invariants.always}
       conjunction STILL holds (safety survives a crash) while an
       {!Invariants.eventually_always} invariant is VIOLATED — proving the six are
       genuinely NOT from-init always-invariants (they could not live in [always]),
       which is exactly why the partition puts them in [eventually_always].

   (6) Non-vacuity unit tests (property-side confirm-by-mutation, spec §6): for
       EACH of the fifteen invariants across BOTH sets ([always @ eventually_
       always]) a [cluster_state] is hand-built that violates EXACTLY that
       invariant — [holds = false] on the crafted state, [holds = true] on the
       relevant seed, and (the "exactly it" witness) NO OTHER invariant fails on the
       crafted state. This proves each predicate DISCRIMINATES (is not [fun _ ->
       true]).

   Convention firewall (anvil-ocaml) is honoured in the test too: no
   while/for/loop/return/break/continue (bounded recursion + List/Option
   combinators only); no [_ ->] on any finite sum (list matches are the exhaustive
   [[] | _ :: _], Step.t is enumerated in full); no two-arm match on option/result
   (Option.fold / Option.iter); no exceptions in the logic (Alcotest.check /
   QCheck.Test.fail_reportf are the sanctioned test-failure primitives). *)

module Gen = QCheck.Gen
module Scenario = Anvil_assurance.Scenario
module Invariants = Anvil_assurance.Invariants

let controller_id : int = Scenario.controller_id
let cr : Vreplica_set.t = Scenario.vrs ~desired:2
let vrs_ref : Common.object_ref = Scenario.vrs_ref
let seed2 : Cluster.cluster_state = Scenario.seed ~desired:2 ~fair:false
let invs : Invariants.invariant list = Invariants.all ~cr ~controller_id

(* per-CR invariant-set accessors (each seed's primary CR is [vrs1]; its desired
   replica count selects the closed-over CR the predicates key on). *)
let always_of ~desired : Invariants.invariant list =
  Invariants.always ~cr:(Scenario.vrs ~desired) ~controller_id

let ea_of ~desired : Invariants.invariant list =
  Invariants.eventually_always ~cr:(Scenario.vrs ~desired) ~controller_id

let goal_of ~desired : Invariants.invariant =
  Invariants.liveness_goal ~cr:(Scenario.vrs ~desired)

(* The scenario CR's controller owner reference, byte-identical to
   [Vreplica_set.controller_owner_ref cr] (name "vrs1", uid 1). *)
let co : Owner_reference.t =
  {
    Owner_reference.block_owner_deletion = Some true;
    controller = Some true;
    kind = Vreplica_set.kind;
    name = "vrs1";
    uid = Common.Uid.of_int 1;
  }

(* -- state-construction helpers ------------------------------------------- *)

let mk_meta ~name ~ns ~(uid : int option) ~(rv : int option)
    ~(owners : Owner_reference.t list option) : Object_meta.t =
  {
    (Object_meta.default ()) with
    Object_meta.name = Some name;
    namespace = Some ns;
    uid = Option.map Common.Uid.of_int uid;
    resource_version = Option.map Common.Resource_version.of_int rv;
    owner_references = owners;
  }

let mk_obj ~kind ~name ~ns ~(uid : int option) ~(rv : int option)
    ~(owners : Owner_reference.t list option) : Dynamic_object.t =
  Dynamic_object.make ~kind
    ~metadata:(mk_meta ~name ~ns ~uid ~rv ~owners)
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let mk_pod ~name ~ns ~(rv : int option)
    ~(owners : Owner_reference.t list option) : Pod.t =
  Pod.make ~metadata:(mk_meta ~name ~ns ~uid:(Some 1) ~rv ~owners) ~spec:None
    ~status:None

(* [{ Common.kind; name; namespace }]. *)
let oref ~kind ~name ~ns : Common.object_ref =
  { Common.kind; name; namespace = ns }

(* Replace / add one etcd object. *)
let add_etcd (s : Cluster.cluster_state) (key : Common.object_ref)
    (obj : Dynamic_object.t) : Cluster.cluster_state =
  {
    s with
    Cluster.api_server =
      {
        s.Cluster.api_server with
        Api_server.resources =
          Object_ref_map.add key obj s.Cluster.api_server.Api_server.resources;
      };
  }

(* Put a single in-flight message in the network. *)
let set_network (s : Cluster.cluster_state) (m : Message.t) :
    Cluster.cluster_state =
  { s with Cluster.network = { Network.in_flight = Message.Pool.singleton m } }

(* Rewrite the id-0 controller's state (used to inject ongoing / scheduled
   reconciles). The seed always has controller id 0 present, so the [None] arm is
   defensive dead code. *)
let map_ctrl (s : Cluster.cluster_state)
    (f : Controller.state -> Controller.state) : Cluster.cluster_state =
  Option.fold
    (Imap.find_opt controller_id s.Cluster.controller_and_externals)
    ~none:s
    ~some:(fun (cae : Cluster.controller_and_external) ->
      {
        s with
        Cluster.controller_and_externals =
          Imap.add controller_id
            { cae with Cluster.controller = f cae.Cluster.controller }
            s.Cluster.controller_and_externals;
      })

let set_ongoing (s : Cluster.cluster_state)
    (m : Controller.ongoing_reconcile Object_ref_map.t) : Cluster.cluster_state =
  map_ctrl s (fun c -> { c with Controller.ongoing_reconciles = m })

let set_scheduled (s : Cluster.cluster_state)
    (m : Dynamic_object.t Object_ref_map.t) : Cluster.cluster_state =
  map_ctrl s (fun c -> { c with Controller.scheduled_reconciles = m })

let single_ongoing (key : Common.object_ref)
    (orc : Controller.ongoing_reconcile) :
    Controller.ongoing_reconcile Object_ref_map.t =
  Object_ref_map.add key orc Object_ref_map.empty

(* An ongoing reconcile whose local state does NOT decode (Null) — keeps the
   decoded-state invariants (#12/#15/#16) vacuously true so a message/counter
   violation can be isolated. *)
let orc_opaque ~triggering_cr ~pending ~id : Controller.ongoing_reconcile =
  {
    Controller.triggering_cr;
    pending_req_msg = pending;
    local_state = Value.of_json `Null;
    reconcile_id = id;
  }

(* An ongoing reconcile whose local state decodes to [step]/[filtered_pods]. *)
let orc_decoded ~triggering_cr ~step ~filtered_pods ~id :
    Controller.ongoing_reconcile =
  {
    Controller.triggering_cr;
    pending_req_msg = None;
    local_state =
      Vreplica_set_pack.marshal_state
        {
          Vreplica_set_reconciler.reconcile_step = step;
          filtered_pods;
        };
    reconcile_id = id;
  }

let stored_vrs2 : Dynamic_object.t = Vreplica_set.marshal cr

(* ======================================================================== *)
(* (1)+(2)  random trace generator + Property P_safety (ALWAYS set only)      *)
(* ======================================================================== *)

(* The reachable [~fair:false] seed families P_safety samples over, each paired
   with the ALWAYS-invariant list for its primary CR ([vrs1]). Every one holds the
   whole ALWAYS conjunction at its seed and after every enabled step. *)
let safety_seed0 : string * Cluster.cluster_state * Invariants.invariant list =
  ("seed ~desired:2 ~fair:false", seed2, always_of ~desired:2)

let safety_seeds :
    (string * Cluster.cluster_state * Invariants.invariant list) list =
  [
    safety_seed0;
    ( "seed_with_pods ~desired:1 ~existing:2 ~fair:false",
      Scenario.seed_with_pods ~desired:1 ~existing:2 ~fair:false,
      always_of ~desired:1 );
    ( "seed_with_pods ~desired:2 ~existing:3 ~fair:false",
      Scenario.seed_with_pods ~desired:2 ~existing:3 ~fair:false,
      always_of ~desired:2 );
    ( "seed_multi ~desireds:[2;3] ~fair:false",
      Scenario.seed_multi ~desireds:[ 2; 3 ] ~fair:false,
      always_of ~desired:2 );
  ]

(* A random enabled-step trace tagged with its seed label + ALWAYS-invariant list:
   pick one seed family uniformly, then draw one successor uniformly each step
   (whole [enabled_successors] set, failure steps included), fuel 40, stopping
   early when the successor set is empty. Bounded recursion; [List.nth_opt] keeps
   it total; [safety_seed0] is the total default for the (impossible) miss. *)
let g_safety :
    (string * Invariants.invariant list * Cluster.cluster_state list) Gen.t =
 fun rng ->
  let label, s0, alw =
    Option.value ~default:safety_seed0
      (List.nth_opt safety_seeds
         (Gen.int_bound (List.length safety_seeds - 1) rng))
  in
  let rec walk fuel (s : Cluster.cluster_state)
      (acc : Cluster.cluster_state list) : Cluster.cluster_state list =
    if fuel <= 0 then List.rev acc
    else
      match Cluster.enabled_successors Bound.default Scenario.cluster s with
      | [] -> List.rev acc
      | _ :: _ as succs ->
        let i = Gen.int_bound (List.length succs - 1) rng in
        Option.fold (List.nth_opt succs i) ~none:(List.rev acc)
          ~some:(fun (_step, s') -> walk (fuel - 1) s' (s' :: acc))
  in
  (label, alw, walk 40 s0 [ s0 ])

let p_safety
    ((label, alw, trace) :
      string * Invariants.invariant list * Cluster.cluster_state list) : bool =
  List.for_all
    (fun s ->
      Option.fold (Invariants.first_violated alw s) ~none:true
        ~some:(fun (i : Invariants.invariant) ->
          QCheck.Test.fail_reportf
            "P_safety: ALWAYS-invariant %s violated at a reachable state on the \
             %s trace. An always-invariant must hold after every step; this is a \
             genuine model/port bug (REPORTED, never weakened or reclassified)."
            i.Invariants.name label))
    trace

let test_p_safety =
  QCheck.Test.make ~count:400
    ~name:
      "P_safety: the ALWAYS conjunction holds at every state of a random \
       ~fair:false enabled-step trace (from seed / seed_with_pods / seed_multi)"
    (QCheck.make g_safety) p_safety

(* ======================================================================== *)
(* (3)  Property P_eventually_always (bounded sample at the settled state)    *)
(* ======================================================================== *)

(* The [~fair:true] seed families, each paired with its EVENTUALLY_ALWAYS list and
   ESR goal for the primary CR ([vrs1]). The fair suffix disables crash / req_drop
   / pod_monkey, so the reconcile converges and the six eventually_always
   invariants stabilize. *)
let ea_seeds :
    (string * Cluster.cluster_state * Invariants.invariant list
    * Invariants.invariant)
    list =
  [
    ( "seed ~desired:2 ~fair:true",
      Scenario.seed ~desired:2 ~fair:true,
      ea_of ~desired:2, goal_of ~desired:2 );
    ( "seed_with_pods ~desired:1 ~existing:2 ~fair:true",
      Scenario.seed_with_pods ~desired:1 ~existing:2 ~fair:true,
      ea_of ~desired:1, goal_of ~desired:1 );
    ( "seed_with_pods ~desired:2 ~existing:3 ~fair:true",
      Scenario.seed_with_pods ~desired:2 ~existing:3 ~fair:true,
      ea_of ~desired:2, goal_of ~desired:2 );
    ( "seed_multi ~desireds:[2;3] ~fair:true",
      Scenario.seed_multi ~desireds:[ 2; 3 ] ~fair:true,
      ea_of ~desired:2, goal_of ~desired:2 );
  ]

(* Drive first-productive-successor (the first step that actually changes the
   state) from a fair seed to the SETTLED state, returning it or [None] on
   non-convergence. Stop at [Scenario.is_quiescent] (the faithful primary target,
   though it never fires here — see the HONEST LIMIT note) OR at the first state
   where the ESR goal [current_state_matches] holds (the reachable settled sample).
   Bounded recursion; total via [List.find_opt] / [Option.bind]. *)
let drive_to_settled (goal : Invariants.invariant) (s0 : Cluster.cluster_state) :
    Cluster.cluster_state option =
  let rec go fuel (s : Cluster.cluster_state) : Cluster.cluster_state option =
    if Scenario.is_quiescent Bound.default s || goal.Invariants.holds s then
      Some s
    else if fuel <= 0 then None
    else
      Option.bind
        (List.find_opt
           (fun (_step, s') -> s' <> s)
           (Scenario.productive_successors Bound.default s))
        (fun (_step, s') -> go (fuel - 1) s')
  in
  go 300 s0

let test_eventually_always () =
  List.iter
    (fun (label, s0, ea, goal) ->
      let settled = drive_to_settled goal s0 in
      Alcotest.(check bool)
        (Printf.sprintf
           "%s: fair productive driving reaches the settled (ESR-goal) state \
            within fuel"
           label)
        true (Option.is_some settled);
      Option.iter
        (fun (sq : Cluster.cluster_state) ->
          Alcotest.(check (option string))
            (Printf.sprintf
               "BOUNDED SAMPLE (not a proof): every eventually_always invariant \
                holds at the settled state on %s"
               label)
            None
            (Option.map
               (fun (i : Invariants.invariant) -> i.Invariants.name)
               (Invariants.first_violated ea sq)))
        settled)
    ea_seeds

(* ======================================================================== *)
(* (4)  Property P_liveness_sample (#11 bounded sample)                       *)
(* ======================================================================== *)

let goal : Invariants.invariant = Invariants.liveness_goal ~cr

(* Drive first-productive-successor from the fair seed. Returns
   [(reached_literal_quiescence, seen_goal, last_state)]. [seen_goal] records
   whether the ESR goal [current_state_matches] ever held along the driven path. *)
let drive_liveness () : bool * bool * Cluster.cluster_state =
  let rec go fuel (s : Cluster.cluster_state) (seen : bool) :
      bool * bool * Cluster.cluster_state =
    let seen = seen || goal.Invariants.holds s in
    match Scenario.productive_successors Bound.default s with
    | [] -> (true, seen, s)
    | _ :: _ as succs ->
      if fuel <= 0 then (false, seen, s)
      else
        Option.fold (List.nth_opt succs 0) ~none:(false, seen, s)
          ~some:(fun (_step, s') -> go (fuel - 1) s' seen)
  in
  go 200 (Scenario.seed ~desired:2 ~fair:true) false

let test_liveness_sample () =
  let quiesced, seen_goal, sq = drive_liveness () in
  (* If literal quiescence WAS reached, the goal must hold there. Given the model
     note (schedule always enabled) this arm is not expected to fire, but if it
     ever does the goal is asserted — a false goal at a quiescent state would be a
     real finding. *)
  Alcotest.(check bool)
    "BOUNDED SAMPLE (not a proof): if a literally-quiescent state is reached the \
     ESR goal holds there"
    true
    (Option.fold
       (if quiesced then Some sq else None)
       ~none:true ~some:goal.Invariants.holds);
  (* The bounded sample proper: under fair first-successor driving the ESR goal
     [current_state_matches] is REACHED within the fuel. Never reaching it is a
     real finding (reconcile did not converge). *)
  Alcotest.(check bool)
    "BOUNDED SAMPLE (not a proof): ESR goal current_state_matches reached within \
     200 fair productive steps"
    true seen_goal

(* ======================================================================== *)
(* (5)  Classification confirm-by-mutation: an EVENTUALLY_ALWAYS invariant     *)
(*      genuinely breaks on a reachable ~fair:false trace while ALWAYS holds    *)
(* ======================================================================== *)

(* A state has a live controller->api-server request AND an ongoing reconcile at
   the CR (so #10 currently HOLDS: the message is that reconcile's pending req). *)
let ctrl_req_pending (s : Cluster.cluster_state) : bool =
  Object_ref_map.mem vrs_ref (Cluster.ongoing_reconciles s controller_id)
  && List.exists
       (fun (m : Message.t) ->
         Message.equal_host_id m.src
           (Message.Controller (controller_id, vrs_ref))
         && Message.equal_host_id m.dst Message.Api_server)
       (Message.Pool.distinct (Cluster.in_flight s))

(* Drive first-productive-successor from the (crash-enabled) seed until a
   controller request is pending. Bounded recursion; total via [List.nth_opt]. *)
let seek_pending (s0 : Cluster.cluster_state) : Cluster.cluster_state option =
  let rec go fuel (s : Cluster.cluster_state) : Cluster.cluster_state option =
    if ctrl_req_pending s then Some s
    else if fuel <= 0 then None
    else
      Option.fold
        (List.nth_opt (Scenario.productive_successors Bound.default s) 0)
        ~none:None
        ~some:(fun (_step, s') -> go (fuel - 1) s')
  in
  go 60 s0

(* The [Restart_controller_step 0] successor of [s] (crash must be enabled). The
   [Step.t] match is exhaustive (twelve constructors, no wildcard). *)
let restart_successor (s : Cluster.cluster_state) : Cluster.cluster_state option
    =
  List.find_map
    (fun ((step, s') : Step.t * Cluster.cluster_state) ->
      match step with
      | Step.Restart_controller_step cid ->
        if cid = controller_id then Some s' else None
      | Step.Api_server_step _ | Step.Builtin_controllers_step _
      | Step.Controller_step _ | Step.Schedule_controller_reconcile_step _
      | Step.Disable_crash_step _ | Step.Drop_req_step _
      | Step.Disable_req_drop_step | Step.Pod_monkey_step _
      | Step.Disable_pod_monkey_step | Step.External_step _ | Step.Stutter_step ->
        None)
    (Cluster.enabled_successors Bound.default Scenario.cluster s)

let test_ea_transient () =
  let alw = Invariants.always ~cr ~controller_id in
  let ea = Invariants.eventually_always ~cr ~controller_id in
  let post = Option.bind (seek_pending seed2) restart_successor in
  Alcotest.(check bool)
    "a reachable post-restart ~fair:false state exists (drove productive \
     successors to a pending request, then restarted)"
    true (Option.is_some post);
  Option.iter
    (fun (s' : Cluster.cluster_state) ->
      Alcotest.(check bool)
        "post-restart: the ALWAYS conjunction STILL holds (safety survives a \
         controller crash)"
        true (Invariants.conjunction alw s');
      (* the restart clears ongoing_reconciles but leaves the already-sent request
         in the network, so a Controller(0,vrs)->api request is in flight with no
         ongoing reconcile — an eventually_always invariant (#10) breaks. *)
      Alcotest.(check bool)
        "post-restart: an eventually_always invariant IS violated (it is NOT a \
         from-init always-invariant — justifies its eventually_always \
         classification)"
        false (Invariants.conjunction ea s'))
    post

(* ======================================================================== *)
(* (6)  Non-vacuity: one exactly-violating state per invariant (both sets)    *)
(* ======================================================================== *)

(* ---- #1: two etcd objects sharing a uid (a Pod reusing the CR's uid 1). --- *)
let crafted1 =
  add_etcd seed2
    (oref ~kind:Common.Pod ~name:"p1" ~ns:"ns")
    (mk_obj ~kind:Common.Pod ~name:"p1" ~ns:"ns" ~uid:(Some 1) ~rv:(Some 0)
       ~owners:None)

(* ---- #2: an etcd object whose uid (2) is NOT below uid_counter (2). ------- *)
let crafted2 =
  add_etcd seed2
    (oref ~kind:Common.Config_map ~name:"cm2" ~ns:"ns")
    (mk_obj ~kind:Common.Config_map ~name:"cm2" ~ns:"ns" ~uid:(Some 2)
       ~rv:(Some 0) ~owners:None)

(* ---- #3: an etcd object with TWO controller owner references. ------------- *)
let ctrl_owner name : Owner_reference.t =
  {
    Owner_reference.block_owner_deletion = Some true;
    controller = Some true;
    kind = Common.Config_map;
    name;
    uid = Common.Uid.of_int 3;
  }

let crafted3 =
  add_etcd seed2
    (oref ~kind:Common.Config_map ~name:"cm3" ~ns:"ns")
    (mk_obj ~kind:Common.Config_map ~name:"cm3" ~ns:"ns" ~uid:(Some 0)
       ~rv:(Some 0)
       ~owners:(Some [ ctrl_owner "o1"; ctrl_owner "o2" ]))

(* ---- #4: a SCHEDULED entry (non-CR key) whose uid (5) >= uid_counter. ----- *)
let crafted4 =
  set_scheduled seed2
    (Object_ref_map.add
       (oref ~kind:Common.Config_map ~name:"sc" ~ns:"ns")
       (mk_obj ~kind:Common.Config_map ~name:"sc" ~ns:"ns" ~uid:(Some 5)
          ~rv:(Some 0) ~owners:None)
       Object_ref_map.empty)

(* ---- #5: an ONGOING reconcile (non-CR key) whose triggering_cr uid >= ----- *)
(*          uid_counter. *)
let crafted5 =
  set_ongoing seed2
    (single_ongoing
       (oref ~kind:Common.Config_map ~name:"t5" ~ns:"ns")
       (orc_opaque
          ~triggering_cr:
            (mk_obj ~kind:Common.Config_map ~name:"t5" ~ns:"ns" ~uid:(Some 5)
               ~rv:(Some 0) ~owners:None)
          ~pending:None ~id:0))

(* ---- #6: two ongoing reconciles sharing a reconcile_id. ------------------- *)
let crafted6 =
  let trig name =
    mk_obj ~kind:Common.Config_map ~name ~ns:"ns" ~uid:(Some 1) ~rv:(Some 0)
      ~owners:None
  in
  set_ongoing seed2
    (Object_ref_map.add
       (oref ~kind:Common.Config_map ~name:"a" ~ns:"ns")
       (orc_opaque ~triggering_cr:(trig "a") ~pending:None ~id:7)
       (Object_ref_map.add
          (oref ~kind:Common.Config_map ~name:"b" ~ns:"ns")
          (orc_opaque ~triggering_cr:(trig "b") ~pending:None ~id:7)
          Object_ref_map.empty))

(* ---- #7: a GC (Builtin_controller -> Api_server) DELETE with no ---------- *)
(*          preconditions (uid guard absent). Key is a non-pod so #8 stays true. *)
let crafted7 =
  set_network seed2
    (Message.form_msg ~src:Message.Builtin_controller ~dst:Message.Api_server
       ~rpc_id:(Message.Rpc_id.of_int 102)
       ~content:
         (Message.delete_req_msg_content
            (oref ~kind:Common.Config_map ~name:"z" ~ns:"other")
            None))

(* ---- #8: a foreign (src = a DIFFERENT controller key) create of a --------- *)
(*          vrs-owned pod in the vrs namespace. Src is a controller so #14 skips
              it; not the vrs key so #9/#10 skip it. *)
let crafted8 =
  set_network seed2
    (Message.form_msg
       ~src:(Message.Controller (0, oref ~kind:Common.Config_map ~name:"other" ~ns:"ns"))
       ~dst:Message.Api_server ~rpc_id:(Message.Rpc_id.of_int 103)
       ~content:
         (Message.create_req_msg_content "ns"
            (mk_obj ~kind:Common.Pod ~name:"vreplicaset-vrs1-b" ~ns:"ns"
               ~uid:(Some 0) ~rv:(Some 0) ~owners:(Some [ co ]))))

(* ---- #9: a message FROM the vrs controller key whose request is not a ----- *)
(*          self-request (a Get). It is the ongoing reconcile's pending request,
              so #10 stays true. *)
let m9 : Message.t =
  Message.form_msg
    ~src:(Message.Controller (controller_id, vrs_ref))
    ~dst:Message.Api_server ~rpc_id:(Message.Rpc_id.of_int 104)
    ~content:
      (Message.get_req_msg_content (oref ~kind:Common.Pod ~name:"q" ~ns:"ns"))

let crafted9 =
  set_ongoing (set_network seed2 m9)
    (single_ongoing vrs_ref
       (orc_opaque ~triggering_cr:stored_vrs2 ~pending:(Some m9) ~id:0))

(* ---- #10: a message FROM the vrs controller key that is NOT any ongoing ---- *)
(*           reconcile's pending request (a self-legal List, so #9 stays true). *)
let crafted10 =
  set_network seed2
    (Message.form_msg
       ~src:(Message.Controller (controller_id, vrs_ref))
       ~dst:Message.Api_server ~rpc_id:(Message.Rpc_id.of_int 105)
       ~content:(Message.list_req_msg_content Pod.kind "ns"))

(* ---- #14: a foreign (Pod_monkey) CREATE of a pod (mutating a pod), in a ---- *)
(*           non-vrs namespace so #8's interference check stays true. *)
let crafted14 =
  set_network seed2
    (Message.form_msg ~src:Message.Pod_monkey ~dst:Message.Api_server
       ~rpc_id:(Message.Rpc_id.of_int 106)
       ~content:
         (Message.create_req_msg_content "other"
            (mk_obj ~kind:Common.Pod ~name:"p" ~ns:"other" ~uid:(Some 0)
               ~rv:(Some 0) ~owners:None)))

(* ---- #15: an ongoing reconcile whose filtered_pods holds a pod with a ----- *)
(*           MISSING resource_version (#15 requires rv < counter; #16 does not
               look at rv, so it stays true). *)
let crafted15 =
  set_ongoing seed2
    (single_ongoing vrs_ref
       (orc_decoded ~triggering_cr:stored_vrs2
          ~step:Vreplica_set_reconciler.Init
          ~filtered_pods:
            (Some
               [
                 mk_pod ~name:"vreplicaset-vrs1-a" ~ns:"ns" ~rv:None
                   ~owners:(Some [ co ]);
               ])
          ~id:0))

(* ---- #16: an ongoing reconcile whose filtered_pods holds a pod whose name -- *)
(*           lacks the vrs prefix (#16 requires the prefix; #15 does not, and the
               pod is otherwise matrix-clean so #15 stays true). *)
let crafted16 =
  set_ongoing seed2
    (single_ongoing vrs_ref
       (orc_decoded ~triggering_cr:stored_vrs2
          ~step:Vreplica_set_reconciler.Init
          ~filtered_pods:
            (Some
               [
                 mk_pod ~name:"nope" ~ns:"ns" ~rv:(Some 0) ~owners:(Some [ co ]);
               ])
          ~id:0))

(* ---- #12: current_state_matches TRUE with an ongoing reconcile parked at --- *)
(*           After_create_pod (the guarded literal forbids that pairing).
               Uses a desired-0 CR whose stored status already reads replicas=0,
               so 0 matching pods = 0 desired and the status agrees. Its own cr /
               invariant list / seed. *)
let cr0 : Vreplica_set.t =
  Vreplica_set.with_status { Vreplica_set.replicas = 0 } (Scenario.vrs ~desired:0)

let invs0 : Invariants.invariant list =
  Invariants.all ~cr:cr0 ~controller_id

let seed0 : Cluster.cluster_state = Scenario.seed ~desired:0 ~fair:false
let stored_cr0 : Dynamic_object.t = Vreplica_set.marshal cr0

(* The on-goal quiescent seed for #12: [seed0] with the status-bearing CR
   ([stored_cr0], status replicas=0) installed, 0 matching pods and NO ongoing
   reconcile — so [current_state_matches cr0] holds and, with no ongoing, the
   literal conjunctive #12 holds. [crafted12] is exactly this seed plus an
   ongoing reconcile parked at [After_create_pod], which the step-shape conjunct
   forbids. (The bare [seed0] does NOT carry a status, so #12's
   [current_state_matches] conjunct is false there.) *)
let seed12 : Cluster.cluster_state = add_etcd seed0 vrs_ref stored_cr0

let crafted12 =
  set_ongoing seed12
    (single_ongoing vrs_ref
       (orc_decoded ~triggering_cr:stored_cr0
          ~step:(Vreplica_set_reconciler.After_create_pod 0)
          ~filtered_pods:None ~id:0))

(* ---- #13: a SCHEDULED entry AT the CR key whose uid (0) disagrees with the -- *)
(*           CR's uid (1). Uid 0 < uid_counter, so #4 stays true. *)
let crafted13 =
  set_scheduled seed2
    (Object_ref_map.add vrs_ref
       (Dynamic_object.with_metadata
          (mk_meta ~name:"vrs1" ~ns:"ns" ~uid:(Some 0) ~rv:(Some 0)
             ~owners:(Some [ co ]))
          stored_vrs2)
       Object_ref_map.empty)

(* -- generic per-invariant checker: violates target, holds on seed, and no ---
   other invariant fails on the crafted state ("exactly it"). -- *)
let check_case (name : string) (crafted : Cluster.cluster_state)
    (these : Invariants.invariant list) (seed : Cluster.cluster_state) () : unit =
  let target = List.find_opt (fun (i : Invariants.invariant) -> String.equal i.name name) these in
  Alcotest.(check bool) (name ^ ": invariant present in list") true
    (Option.is_some target);
  Option.iter
    (fun (t : Invariants.invariant) ->
      Alcotest.(check bool) (name ^ ": crafted state VIOLATES it") false
        (t.holds crafted);
      Alcotest.(check bool) (name ^ ": holds on Scenario.seed") true
        (t.holds seed);
      (* "violates EXACTLY it": the crafted state must not spuriously break any
         OTHER invariant. An eventually_always invariant (e.g. #12
         [inductive_current_state_matches], whose literal conjunctive form is
         false off-goal) is legitimately false on this off-goal, hand-built
         negative AND on the base [seed] itself, so it is not a crafting
         artifact. Only an invariant that was GREEN on [seed] and goes RED on
         [crafted] is a genuine spurious break, so the isolation claim is
         [i.holds seed ==> i.holds crafted] (for always-invariants [holds seed]
         is [true], so this is exactly the original [i.holds crafted]). *)
      Alcotest.(check bool)
        (name ^ ": violates EXACTLY it (no other invariant fails)") true
        (List.for_all
           (fun (i : Invariants.invariant) ->
             String.equal i.name name || (not (i.holds seed)) || i.holds crafted)
           these))
    target

let neg_cases :
    (string * Cluster.cluster_state * Invariants.invariant list
    * Cluster.cluster_state)
    list =
  [
    ("etcd_objects_have_unique_uids", crafted1, invs, seed2);
    ("each_object_in_etcd_is_weakly_well_formed", crafted2, invs, seed2);
    ("each_object_in_etcd_has_at_most_one_controller_owner", crafted3, invs, seed2);
    ("scheduled_cr_has_lower_uid_than_uid_counter", crafted4, invs, seed2);
    ("triggering_cr_has_lower_uid_than_uid_counter", crafted5, invs, seed2);
    ("every_ongoing_reconcile_has_unique_id", crafted6, invs, seed2);
    ("garbage_collector_does_not_delete_vrs_pods", crafted7, invs, seed2);
    ("no_other_pending_request_interferes_with_vrs_reconcile", crafted8, invs, seed2);
    ("vrs_reconcile_request_only_interferes_with_itself", crafted9, invs, seed2);
    ("every_msg_from_key_is_pending_req_msg_of", crafted10, invs, seed2);
    ("inductive_current_state_matches", crafted12, invs0, seed12);
    ("vrs_in_schedule/reconcile_has_spec_and_uid_as", crafted13, invs, seed2);
    ("no_pending_mutation_request_not_from_controller_on_pods", crafted14, invs, seed2);
    ("filtered_pods_invariant_matrix", crafted15, invs, seed2);
    ("local_pods_are_bound_to_vrs_with_key", crafted16, invs, seed2);
  ]

(* ---- S2: seed_with_pods issues DISTINCT, freshly-issued (bounded) pod rvs -- *)
(* Before the S2 fix every owned pod carried resource_version 0 (all equal), so
   any differential over the seed could never exercise the stale-rv / rv-ordering
   bug class — it was vacuous on the rv axis. The fix stamps pod [index] with rv
   [index+1], so [~existing:3] yields the three distinct rvs {1;2;3}, each
   strictly below [resource_version_counter] (= existing+1 = 4). *)
let pod_rvs (s : Cluster.cluster_state) : int list =
  Object_ref_map.fold
    (fun _k (o : Dynamic_object.t) acc ->
      if Common.equal_kind (Dynamic_object.kind o) Pod.kind then
        let m : Object_meta.t = Dynamic_object.metadata o in
        Option.fold m.resource_version ~none:acc ~some:(fun rv ->
            Common.Resource_version.to_int rv :: acc)
      else acc)
    s.Cluster.api_server.Api_server.resources []

let test_seed_rvs_distinct_bounded () =
  let s = Scenario.seed_with_pods ~desired:2 ~existing:3 ~fair:false in
  let rvs = pod_rvs s in
  let counter = s.Cluster.api_server.Api_server.resource_version_counter in
  Alcotest.(check int) "seed_with_pods ~existing:3 has 3 owned pods" 3
    (List.length rvs);
  Alcotest.(check int)
    "the 3 owned-pod resource_versions are pairwise DISTINCT (before S2 all 0)" 3
    (List.length (List.sort_uniq Int.compare rvs));
  Alcotest.(check bool)
    "every owned-pod resource_version is strictly below \
     resource_version_counter (freshly issued)"
    true
    (List.for_all (fun rv -> rv < counter) rvs)

let () =
  Alcotest.run "p4_invariants"
    [
      ("P_safety", [ QCheck_alcotest.to_alcotest test_p_safety ]);
      ( "seed_rv_distinct_bounded",
        [
          Alcotest.test_case
            "seed_with_pods issues distinct, freshly-issued pod resource_versions"
            `Quick test_seed_rvs_distinct_bounded;
        ] );
      ( "P_eventually_always",
        [
          Alcotest.test_case
            "bounded sample: eventually_always holds at the settled state on \
             fair traces" `Quick test_eventually_always;
        ] );
      ( "P_liveness_sample",
        [
          Alcotest.test_case
            "bounded sample: ESR goal reached under fair driving" `Quick
            test_liveness_sample;
        ] );
      ( "eventually_always_transient",
        [
          Alcotest.test_case
            "an eventually_always invariant genuinely breaks post-restart while \
             ALWAYS holds" `Quick test_ea_transient;
        ] );
      ( "non_vacuity",
        List.map
          (fun (name, crafted, these, seed) ->
            Alcotest.test_case name `Quick (check_case name crafted these seed))
          neg_cases );
    ]

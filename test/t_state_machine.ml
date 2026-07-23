(* State-machine framework tests (BUILD-SPEC-P2 "## Tests", t_state_machine):
   - [next_results] returns ALL enabled successors (a machine with 2 enabled
     steps yields 2), in the given step order;
   - [Disabled] steps contribute nothing;
   - the host [action_input] is threaded into each action's precondition;
   - [next_action_result] / [net_next_result] truth table.

   A tiny toy machine (state = counter, three steps with distinct guards) stands
   in for a host: the framework is generic, so nothing cluster-specific is
   needed here. *)

(* A three-step toy. The host [action_input] is a NON-trivial transform (it adds
   one to the raw input), so [Inc] fires when [state >= input + 1], [Big] when
   [state >= 10] (input-independent), [Never] is always disabled. The transform is
   what makes it observable whether [next_results] actually applies
   [sm.action_input]: at [state = input] the threaded ai ([input + 1]) disables
   Inc, whereas the raw input would enable it. *)
type toy_step = Inc | Big | Never

let inc_action : (int, int, int) Action.t =
  { Action.precondition = (fun ai s -> s >= ai); transition = (fun _ai s -> (s + 1, s)) }

let big_action : (int, int, int) Action.t =
  { Action.precondition = (fun _ai s -> s >= 10); transition = (fun _ai s -> (s + 2, s)) }

let never_action : (int, int, int) Action.t =
  { Action.precondition = (fun _ai _s -> false); transition = (fun _ai s -> (s, s)) }

let toy : (int, int, int, int, toy_step) State_machine.t =
  {
    State_machine.init = (fun s -> s = 0);
    step_to_action =
      (fun step ->
        match step with Inc -> inc_action | Big -> big_action | Never -> never_action);
    action_input = (fun (_ : toy_step) (input : int) -> input + 1);
  }

let steps = [ Inc; Big; Never ]

(* Exhaustive two-arm classifier on the finite [Action.result] sum (allowed: not
   option/result). *)
let is_enabled : ('s, 'o) Action.result -> bool = function
  | Action.Enabled _ -> true
  | Action.Disabled -> false

let enabled_pair : (int, int) Action.result -> (int * int) option = function
  | Action.Enabled (s', o) -> Some (s', o)
  | Action.Disabled -> None

let test_all_enabled () =
  (* state 10, input 0: Inc enabled (10>=0), Big enabled (10>=10), Never off. *)
  let succs = State_machine.next_results toy ~steps 0 10 in
  Alcotest.(check int) "two enabled successors" 2 (List.length succs);
  Alcotest.(check (list (pair int int)))
    "successors in step order" [ (11, 10); (12, 10) ] succs

let test_disabled_contribute_nothing () =
  (* state 5: Inc enabled (5>=0), Big disabled (5<10), Never disabled. *)
  let succs = State_machine.next_results toy ~steps 0 5 in
  Alcotest.(check int) "one enabled successor" 1 (List.length succs);
  Alcotest.(check (list (pair int int))) "only Inc" [ (6, 5) ] succs

let test_input_threading () =
  (* input 11, state 10: ai = 12, so Inc's bar is 12 and Inc is disabled; Big on. *)
  let succs = State_machine.next_results toy ~steps 11 10 in
  Alcotest.(check (list (pair int int))) "input raises Inc's bar" [ (12, 10) ] succs

(* CONFIRM-BY-MUTATION (FIX 4): the toy's action_input adds one, so at
   [state = input] the threaded ai raises Inc's bar above the state and Inc is
   DISABLED. If [next_results] fed the raw [input] instead of [sm.action_input
   step input], Inc's bar would be [input], Inc would fire, and a second successor
   would appear. Neuter state_machine.ml next_results to pass [input] and this
   test flips to failing; restore [ai] and it is green again. *)
let test_action_input_applied () =
  (* input 10, state 10: ai = 11, Inc bar 11 > 10 -> Inc off; Big on. *)
  let succs = State_machine.next_results toy ~steps 10 10 in
  Alcotest.(check (list (pair int int)))
    "action_input raises Inc's bar above the state" [ (12, 10) ] succs

let test_next_action_result () =
  Alcotest.(check bool) "enabled when precond holds" true
    (is_enabled (Action.next_action_result inc_action 0 5));
  Alcotest.(check bool) "disabled when precond fails" false
    (is_enabled (Action.next_action_result never_action 0 5));
  Alcotest.(check (option (pair int int)))
    "Enabled carries transition result" (Some (12, 10))
    (enabled_pair (Action.next_action_result big_action 0 10))

(* The network machine has a single [deliver] action and no step indirection. *)
let toy_net : (int, int) State_machine.net =
  {
    State_machine.net_init = (fun s -> s = 0);
    deliver =
      {
        Action.precondition = (fun mo s -> mo + s >= 0);
        transition = (fun mo s -> (s + mo, ()));
      };
  }

let test_net () =
  Alcotest.(check bool) "net enabled when deliver enabled" true
    (is_enabled (State_machine.net_next_result toy_net 3 1));
  Alcotest.(check bool) "net disabled when deliver disabled" false
    (is_enabled (State_machine.net_next_result toy_net (-5) 1))

let () =
  Alcotest.run "state_machine"
    [
      ( "next_results",
        [
          Alcotest.test_case "all enabled" `Quick test_all_enabled;
          Alcotest.test_case "disabled contribute nothing" `Quick
            test_disabled_contribute_nothing;
          Alcotest.test_case "input threading" `Quick test_input_threading;
          Alcotest.test_case "action_input applied" `Quick
            test_action_input_applied;
        ] );
      ( "next_action_result",
        [
          Alcotest.test_case "truth table" `Quick test_next_action_result;
          Alcotest.test_case "net truth table" `Quick test_net;
        ] );
    ]

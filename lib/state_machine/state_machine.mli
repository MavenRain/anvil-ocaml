(** Anvil source: state_machine/state_machine.rs ([StateMachine],
    [NetworkStateMachine]).

    A host state machine bundles an [init] predicate with a family of
    {!Action.t}s indexed by a [step] binding variable: [step_to_action] names
    the action a step selects and [action_input] builds that action's input
    from the host [input]. Anvil's [actions : Set<Action>] field is a
    proof-only artefact (it exists to state that every [step_to_action] output
    is in the set) and is dropped here.

    The key executable divergence from Anvil (Section 3.3 of the architecture):
    Anvil's [next_result] uses Hilbert [choose] to pick {e one} enabled step,
    which is not computable. {!next_results} instead enumerates the given step
    domain and returns {e every} enabled successor. Determinism is recovered
    only downstream, in the reconciler driver where [reconcile_core] is a
    genuine function. *)

type ('state, 'input, 'action_input, 'output, 'step) t = {
  init : 'state -> bool;
  step_to_action : 'step -> ('state, 'action_input, 'output) Action.t;
  action_input : 'step -> 'input -> 'action_input;
}

(** The [choose]-free replacement for Anvil [StateMachine::next_result]: for
    each step in [steps], select its action and input, and keep the successors
    whose action is [Enabled]. Returns all of them (nondeterminism made
    explicit as a list), never picking one. [steps] is the caller-supplied,
    bounded enumeration of the step domain (unbounded step domains are bounded
    by the cluster's {!Bound.t}); a step whose action is [Disabled] contributes
    nothing. *)
val next_results :
  ('state, 'input, 'action_input, 'output, 'step) t ->
  steps:'step list ->
  'input ->
  'state ->
  ('state * 'output) list

(** Anvil [NetworkStateMachine]: a state machine with a single [deliver]
    action and hence no [step]/[action_input] indirection. *)
type ('state, 'message_ops) net = {
  net_init : 'state -> bool;
  deliver : ('state, 'message_ops, unit) Action.t;
}

(** Anvil [NetworkStateMachine::next_result]: [Enabled (s', ())] iff [deliver]
    is enabled on [msg_ops]/[s]. *)
val net_next_result :
  ('state, 'message_ops) net ->
  'message_ops ->
  'state ->
  ('state, unit) Action.result

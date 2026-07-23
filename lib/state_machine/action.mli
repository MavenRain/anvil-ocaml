(** Anvil source: state_machine/action.rs ([Action], [ActionResult]).

    An [Action] is a guarded transition: a [precondition] that decides whether
    the action is enabled in a given [state] under a given [input], and a
    [transition] that produces the new state and an output. This is the atom
    every host state machine (api server, controller, network, ...) is built
    from.

    The two temporal projections [pre]/[forward] are the bridge to the Phase-0
    TLA core in {!Comp_cat.Temporal}: [pre] is Anvil's [StatePred] (the raw
    enabling predicate) and [forward] its [ActionPred] (a step that respects the
    precondition and lands on the transition's target), exactly as
    [action.rs::pre]/[forward]. They feed the assurance spine (weak fairness,
    [wf1]); the executable spine uses {!next_action_result} directly. *)

(** [Action { precondition; transition }]. [transition] is only meaningful when
    [precondition] holds; {!next_action_result} enforces that pairing. *)
type ('state, 'input, 'output) t = {
  precondition : 'input -> 'state -> bool;
  transition : 'input -> 'state -> 'state * 'output;
}

(** Anvil [action.rs::pre]: the enabling predicate at a fixed [input]
    ([|s| precondition input s]); Anvil's [StatePred<State>]. *)
val pre : ('state, 'input, 'output) t -> 'input -> 'state Comp_cat.Temporal.state_pred

(** Anvil [action.rs::forward]: the action predicate at a fixed [input]
    ([|s, s'| precondition input s && s' == (transition input s).0], output
    dropped); Anvil's [ActionPred<State>]. *)
val forward :
  ('state, 'input, 'output) t -> 'input -> 'state Comp_cat.Temporal.action_pred

(** Anvil [action.rs::weak_fairness]:
    [always(lift_state(pre input)).leads_to(lift_action(forward input))]. The
    [name] interns the two temporal leaves ([name.pre] / [name.forward]) so the
    hash-consed {!Comp_cat.Temporal} kernel can compare them; give each host
    action a stable, distinct [name]. *)
val weak_fairness :
  name:string -> ('state, 'input, 'output) t -> 'input -> 'state Comp_cat.Temporal.t

(** Anvil [ActionResult]: [Disabled] when the precondition fails, else
    [Enabled (state', output)]. Matched exhaustively; no [_ ->]. *)
type ('state, 'output) result = Disabled | Enabled of 'state * 'output

(** Anvil [StateMachine::next_action_result]: run [t] on [input]/[s], returning
    [Enabled (s', o)] iff the precondition holds. This is the executable,
    [choose]-free evaluation of a single action. *)
val next_action_result :
  ('state, 'input, 'output) t -> 'input -> 'state -> ('state, 'output) result

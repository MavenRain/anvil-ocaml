type ('state, 'input, 'action_input, 'output, 'step) t = {
  init : 'state -> bool;
  step_to_action : 'step -> ('state, 'action_input, 'output) Action.t;
  action_input : 'step -> 'input -> 'action_input;
}

let next_results (sm : _ t) ~steps input s =
  List.filter_map
    (fun step ->
      let action = sm.step_to_action step in
      let ai = sm.action_input step input in
      match Action.next_action_result action ai s with
      | Action.Enabled (s', o) -> Some (s', o)
      | Action.Disabled -> None)
    steps

type ('state, 'message_ops) net = {
  net_init : 'state -> bool;
  deliver : ('state, 'message_ops, unit) Action.t;
}

let net_next_result (n : _ net) msg_ops s =
  Action.next_action_result n.deliver msg_ops s

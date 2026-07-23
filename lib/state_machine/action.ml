module T = Comp_cat.Temporal

type ('state, 'input, 'output) t = {
  precondition : 'input -> 'state -> bool;
  transition : 'input -> 'state -> 'state * 'output;
}

let pre (a : _ t) input : _ T.state_pred = fun s -> a.precondition input s

(* Anvil: [s_prime == (transition)(input, s).0]. Structural equality mirrors
   Verus [==]; [forward] is consumed only by the temporal evaluator, never on
   the executable path, so the polymorphic compare is acceptable here. *)
let forward (a : _ t) input : _ T.action_pred =
 fun s s_prime -> a.precondition input s && Stdlib.( = ) (fst (a.transition input s)) s_prime

let weak_fairness ~name (a : _ t) input =
  T.weak_fairness
    ~pre_name:(name ^ ".pre")
    (pre a input)
    ~fwd_name:(name ^ ".forward")
    (forward a input)

type ('state, 'output) result = Disabled | Enabled of 'state * 'output

let next_action_result (a : _ t) input s =
  if a.precondition input s then
    let s', o = a.transition input s in
    Enabled (s', o)
  else Disabled

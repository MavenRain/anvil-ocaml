(* Anvil source: kubernetes_cluster/spec/network/{types.rs, state_machine.rs}.

   The network host. [in_flight] is a true multiset (Anvil [Multiset<Message>]);
   [deliver] removes one occurrence of the received message and unions the whole
   [send] batch. Option handling is via combinators (no two-arm match on the
   [recv] option). *)

type state = { in_flight : Message.Pool.t }

let init : state = { in_flight = Message.Pool.empty }

(* Anvil [deliver] precondition (network/state_machine.rs:11): [recv is Some ==>
   in_flight.contains(recv)]; [None] is vacuously enabled. *)
let precondition (msg_ops : Message.message_ops) (s : state) : bool =
  Option.fold ~none:true
    ~some:(fun (m : Message.t) -> Message.Pool.mem m s.in_flight)
    msg_ops.Message.recv

(* Anvil [deliver] transition (network/state_machine.rs:14): with a received
   message, remove one occurrence then add [send]; without one, add [send] only.
   [Message.Pool.remove_one] returns [None] only when the message is absent,
   which the precondition rules out; the [~default] keeps the function total
   (no removal in that unreachable case). *)
let transition (msg_ops : Message.message_ops) (s : state) : state * unit =
  let send = msg_ops.Message.send in
  let in_flight =
    Option.fold
      ~none:(Message.Pool.union s.in_flight send)
      ~some:(fun (m : Message.t) ->
        let removed =
          Option.value (Message.Pool.remove_one m s.in_flight)
            ~default:s.in_flight
        in
        Message.Pool.union removed send)
      msg_ops.Message.recv
  in
  ({ in_flight }, ())

let deliver : (state, Message.message_ops, unit) Action.t =
  { precondition; transition }

let network : (state, Message.message_ops) State_machine.net =
  {
    State_machine.net_init = (fun (s : state) -> Message.Pool.is_empty s.in_flight);
    deliver;
  }

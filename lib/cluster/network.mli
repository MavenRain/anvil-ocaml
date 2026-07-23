(** Anvil source: kubernetes_cluster/spec/network/{types.rs, state_machine.rs}.

    The cluster's network host: a {!state} holding the in-flight message bag and
    one {!deliver} action that optionally consumes a received message and adds a
    batch of sent messages. Anvil models the network as the single-action
    [NetworkStateMachine] ({!State_machine.net}) — no step / action-input
    indirection, unlike the other hosts. *)

type state = { in_flight : Message.Pool.t }
(** Anvil [NetworkState] (network/types.rs:6): the bag of messages currently in
    transit. A {!Message.Pool} multiset, so a message may be in flight with
    multiplicity > 1 (two identical requests are two deliverable messages). *)

val init : state
(** Anvil [network().init] (network/state_machine.rs:31): the initial network
    state — an empty in-flight bag ([Message.Pool.empty]). *)

val deliver : (state, Message.message_ops, unit) Action.t
(** Anvil [deliver] (network/state_machine.rs:9). Precondition: when
    [msg_ops.recv] is [Some m], [m] is currently in [in_flight] ([recv = None] is
    vacuously enabled). Transition: remove ONE occurrence of the received message
    (when present), then multiset-union the [send] batch into [in_flight]; output
    is [()]. *)

val network : (state, Message.message_ops) State_machine.net
(** Anvil [network()] (network/state_machine.rs:30): the network state machine —
    [net_init] asserting an empty in-flight bag, and {!deliver} as its single
    action. *)

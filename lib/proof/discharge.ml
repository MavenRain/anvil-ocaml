(** [Discharge]: the P5 bridge turning a wf1 / invariant edge's operational
    side-condition into a verdict computed by the bounded model checker.
    Implementation of [discharge.mli]. Every discharge explores the bounded
    reachable graph once with {!Model_check.explore} over
    {!Cluster_check.bounded_successors}, then answers a first-order question about
    that finite graph with {!Model_check.count_states_where} — no infinite
    behaviour, no loop keyword, no exception. *)

type edge_report = {
  holds : bool;
  witnesses : int;
  states_checked : int;
  frontier_emptied : bool;
}

(** The module-internal exploration depth. Large enough that {!edge_report.
    frontier_emptied} (graph closure), not [depth], is the real gate on the
    tightened bound; every non-[reaches_holds] discharge uses it. *)
let default_depth = 64

(** Build the bounded reachable graph once from [init] over the P5 successor
    relation, deduped by the sound cluster equality/hash. *)
let reach (bound : Bound.t) (cluster : Cluster.t)
    ~(init : Cluster.cluster_state) ~depth =
  Model_check.explore ~depth
    ~successors:(Cluster_check.bounded_successors bound cluster)
    ~equal:Cluster_check.state_equal ~hash:Cluster_check.state_hash
    ~init:[ init ]

(** The wf1 [closure] obligation over the bounded graph: no reachable [pre]-state
    has a successor outside [pre \/ post]. *)
let closure_holds (bound : Bound.t) (cluster : Cluster.t) ~init ~pre ~post :
    edge_report =
  let r = reach bound cluster ~init ~depth:default_depth in
  let bad =
    Model_check.count_states_where r (fun s ->
        pre s
        && List.exists
             (fun s' -> not (pre s' || post s'))
             (Cluster_check.bounded_successors bound cluster s))
  in
  {
    holds = bad = 0;
    witnesses = Model_check.count_states_where r pre;
    states_checked = Model_check.states_seen r;
    frontier_emptied = Model_check.frontier_emptied r;
  }

(** The wf1 [drives] obligation over the bounded graph: every
    [forward]-labelled successor of a reachable [pre]-state satisfies [post]. *)
let drives_holds (bound : Bound.t) (cluster : Cluster.t) ~init ~pre ~forward
    ~post : edge_report =
  let r = reach bound cluster ~init ~depth:default_depth in
  let bad =
    Model_check.count_states_where r (fun s ->
        pre s
        && List.exists
             (fun (step, s') -> forward step && not (post s'))
             (Cluster_check.bounded_labelled_successors bound cluster s))
  in
  {
    holds = bad = 0;
    witnesses = Model_check.count_states_where r pre;
    states_checked = Model_check.states_seen r;
    frontier_emptied = Model_check.frontier_emptied r;
  }

(** The [[]j] obligation: every reachable state satisfies [inv]. [witnesses =
    states_checked] since an [always] has no separate antecedent to exercise. *)
let invariant_holds (bound : Bound.t) (cluster : Cluster.t) ~init ~inv :
    edge_report =
  let r = reach bound cluster ~init ~depth:default_depth in
  let bad = Model_check.count_states_where r (fun s -> not (inv s)) in
  let seen = Model_check.states_seen r in
  {
    holds = bad = 0;
    witnesses = seen;
    states_checked = seen;
    frontier_emptied = Model_check.frontier_emptied r;
  }

(** The non-vacuous liveness cross-check: [post] is reachable within [depth] and
    [pre] is reached. Not a wf1 obligation — a corroborating report. *)
let reaches_holds ?(depth = default_depth) (bound : Bound.t)
    (cluster : Cluster.t) ~init ~pre ~post : edge_report =
  let r = reach bound cluster ~init ~depth in
  {
    holds = Model_check.count_states_where r post > 0;
    witnesses = Model_check.count_states_where r pre;
    states_checked = Model_check.states_seen r;
    frontier_emptied = Model_check.frontier_emptied r;
  }

(** Adapt an {!edge_report} to a {!Comp_cat.Rule} side-condition payload:
    [Ok true] iff the edge held, was exercised, and the graph closed; otherwise a
    reasoned [Ill_formed] so the consuming wf1 / borrow_inv call does NOT build a
    fact. The [why] is chosen by the guard chain [holds], then [witnesses > 0],
    then [frontier_emptied] — a plain boolean [if]/[else if], not a loop. *)
let obligation (rep : edge_report) : bool Comp_cat.Res.t =
  if rep.holds && rep.witnesses > 0 && rep.frontier_emptied then Ok true
  else
    let why =
      if not rep.holds then "violated"
      else if not (rep.witnesses > 0) then "vacuous (witnesses=0)"
      else "graph truncated"
    in
    Error (Comp_cat.Err.Ill_formed { fn = "Discharge.obligation"; why })

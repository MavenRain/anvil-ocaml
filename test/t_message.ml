(* Message-layer tests (BUILD-SPEC-P2 "## Tests", t_message):
   - [Rpc_id_allocator.allocate] monotonicity + uniqueness (allocate-old, +1);
   - [received_msg_destined_for None _ = true] (None is vacuously destined);
   - [form_matched_err_resp_msg] swaps src/dst and preserves rpc_id for each of
     the 9 request variants (and the paired response matches);
   - [resp_msg_matches_req_msg] truth table (API + external);
   - [Pool] multiset add / remove_one / equal.

   CONFIRM-BY-MUTATION (feedback-confirm-tests-by-mutation), guard (b):
   [test_destined]'s "None is vacuously true" assertion pins
   [Message.received_msg_destined_for]'s [~none:true] (message.ml:276). Neuter it
   to [~none:false], rebuild, and this test flips to failing; restore to [~none:
   true] and it is green again. Every mutation was restored (tree left green). *)

let cref = { Common.kind = Common.Config_map; name = "cm"; namespace = "ns" }
let ctrl = Message.Controller (0, cref)

let dobj =
  Dynamic_object.make ~kind:Common.Config_map
    ~metadata:
      (Object_meta.default ()
      |> Object_meta.with_name "cm"
      |> Object_meta.with_namespace "ns")
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let owner =
  { (Owner_reference.default ()) with Owner_reference.controller = Some true; name = "owner" }

(* -- allocator: allocate-old-then-increment, ids distinct and increasing -- *)

let ids_of (n : int) : Message.Rpc_id.t list =
  let idxs = List.init n (fun i -> i) in
  let _final, rev =
    List.fold_left
      (fun (a, acc) _ ->
        let a', id = Message.Rpc_id_allocator.allocate a in
        (a', id :: acc))
      (Message.Rpc_id_allocator.init (), [])
      idxs
  in
  List.rev rev

let test_alloc () =
  let a0 = Message.Rpc_id_allocator.init () in
  let a1, id0 = Message.Rpc_id_allocator.allocate a0 in
  let a2, id1 = Message.Rpc_id_allocator.allocate a1 in
  let _a3, id2 = Message.Rpc_id_allocator.allocate a2 in
  Alcotest.(check int) "first id is 0" 0 (Message.Rpc_id.to_int id0);
  Alcotest.(check int) "second id is 1" 1 (Message.Rpc_id.to_int id1);
  Alcotest.(check int) "third id is 2" 2 (Message.Rpc_id.to_int id2);
  Alcotest.(check bool) "strictly increasing" true
    (Message.Rpc_id.compare id0 id1 < 0 && Message.Rpc_id.compare id1 id2 < 0);
  Alcotest.(check bool) "pairwise distinct" true
    (not (Message.Rpc_id.equal id0 id1)
    && not (Message.Rpc_id.equal id1 id2)
    && not (Message.Rpc_id.equal id0 id2))

let prop_alloc =
  QCheck.Test.make ~count:200 ~name:"allocate yields 0..n-1 (unique, monotone)"
    (QCheck.int_range 0 60) (fun n ->
      List.equal Int.equal
        (List.map Message.Rpc_id.to_int (ids_of n))
        (List.init n (fun i -> i)))

(* -- received_msg_destined_for: None is vacuously destined (guard b) -- *)

let test_destined () =
  (* CONFIRM-BY-MUTATION (b): this assertion pins the [~none:true] vacuity. *)
  Alcotest.(check bool) "None is vacuously destined" true
    (Message.received_msg_destined_for None Message.Api_server);
  let m =
    Message.form_msg ~src:ctrl ~dst:Message.Api_server
      ~rpc_id:(Message.Rpc_id.of_int 0)
      ~content:(Message.get_req_msg_content cref)
  in
  Alcotest.(check bool) "Some to matching dst" true
    (Message.received_msg_destined_for (Some m) Message.Api_server);
  Alcotest.(check bool) "Some to other dst" false
    (Message.received_msg_destined_for (Some m) (Message.External 0))

(* -- form_matched_err_resp_msg over all 9 request variants -- *)

let request_contents : Message.message_content list =
  [
    Message.get_req_msg_content cref;
    Message.list_req_msg_content Common.Config_map "ns";
    Message.create_req_msg_content "ns" dobj;
    Message.delete_req_msg_content cref None;
    Message.update_req_msg_content "ns" "cm" dobj;
    Message.update_status_req_msg_content "ns" "cm" dobj;
    Message.get_then_delete_req_msg_content cref owner;
    Message.get_then_update_req_msg_content "ns" "cm" owner dobj;
    Message.get_then_update_status_req_msg_content "ns" "cm" owner dobj;
  ]

let test_err_resp () =
  Alcotest.(check int) "nine request contents" 9 (List.length request_contents);
  let r = Message.Rpc_id.of_int 7 in
  List.iteri
    (fun i content ->
      let req =
        Message.form_msg ~src:ctrl ~dst:Message.Api_server ~rpc_id:r ~content
      in
      let resp = Message.form_matched_err_resp_msg req Api_method.Internal_error in
      let name = "variant " ^ string_of_int i in
      Alcotest.(check bool) (name ^ ": src<-req.dst") true
        (Message.equal_host_id resp.Message.src Message.Api_server);
      Alcotest.(check bool) (name ^ ": dst<-req.src") true
        (Message.equal_host_id resp.Message.dst ctrl);
      Alcotest.(check bool) (name ^ ": rpc_id preserved") true
        (Message.Rpc_id.equal resp.Message.rpc_id r);
      Alcotest.(check bool) (name ^ ": paired response matches request") true
        (Message.resp_msg_matches_req_msg resp req))
    request_contents

(* -- resp_msg_matches_req_msg truth table -- *)

let test_matches () =
  let r = Message.Rpc_id.of_int 5 in
  let req =
    Message.form_msg ~src:ctrl ~dst:Message.Api_server ~rpc_id:r
      ~content:(Message.get_req_msg_content cref)
  in
  let good = Message.form_get_resp_msg req { Api_method.res = Ok dobj } in
  Alcotest.(check bool) "matching get pair" true
    (Message.resp_msg_matches_req_msg good req);
  let bad_id = { good with Message.rpc_id = Message.Rpc_id.of_int 6 } in
  Alcotest.(check bool) "wrong rpc_id" false
    (Message.resp_msg_matches_req_msg bad_id req);
  let bad_cross = { good with Message.dst = Message.Pod_monkey } in
  Alcotest.(check bool) "broken src/dst crossover" false
    (Message.resp_msg_matches_req_msg bad_cross req);
  (* Only the [resp.src = req.dst] conjunct is violated (message.ml:286): rpc_id,
     the paired kind and the OTHER crossover conjunct [resp.dst = req.src] all
     still hold, so a false result isolates that conjunct. *)
  let bad_src = { good with Message.src = Message.Pod_monkey } in
  Alcotest.(check bool) "broken src<-req.dst crossover" false
    (Message.resp_msg_matches_req_msg bad_src req);
  let wrong_kind = Message.form_list_resp_msg req { Api_method.res = Ok [] } in
  Alcotest.(check bool) "mismatched request/response kind" false
    (Message.resp_msg_matches_req_msg wrong_kind req);
  (* external block: matching external pair; an API resp must NOT match it. *)
  let ereq = Message.controller_external_req_msg 0 cref r (Value.of_json `Null) in
  let eresp = Message.form_external_resp_msg ereq (Value.of_json `Null) in
  Alcotest.(check bool) "matching external pair" true
    (Message.resp_msg_matches_req_msg eresp ereq);
  Alcotest.(check bool) "API response vs external request" false
    (Message.resp_msg_matches_req_msg good ereq)

(* -- Pool multiset: multiplicity add / remove_one / equal -- *)

let test_pool () =
  let m1 =
    Message.form_msg ~src:ctrl ~dst:Message.Api_server
      ~rpc_id:(Message.Rpc_id.of_int 0)
      ~content:(Message.get_req_msg_content cref)
  in
  let m2 = { m1 with Message.rpc_id = Message.Rpc_id.of_int 9 } in
  let p2 = Message.Pool.add m1 (Message.Pool.add m1 Message.Pool.empty) in
  Alcotest.(check int) "count after two adds" 2 (Message.Pool.count m1 p2);
  Alcotest.(check int) "cardinal" 2 (Message.Pool.cardinal p2);
  Alcotest.(check (option int)) "count after remove_one" (Some 1)
    (Option.map (Message.Pool.count m1) (Message.Pool.remove_one m1 p2));
  Alcotest.(check bool) "remove_one of absent is None" true
    (Option.is_none (Message.Pool.remove_one m2 Message.Pool.empty));
  let a = Message.Pool.of_list [ m1; m2; m1 ] in
  let b = Message.Pool.of_list [ m1; m1; m2 ] in
  Alcotest.(check bool) "multiset equal ignores order" true (Message.Pool.equal a b);
  let c = Message.Pool.of_list [ m1; m2 ] in
  Alcotest.(check bool) "different multiplicity not equal" false
    (Message.Pool.equal a c)

let () =
  Alcotest.run "message"
    [
      ( "rpc_id_allocator",
        [
          Alcotest.test_case "monotone unique" `Quick test_alloc;
          QCheck_alcotest.to_alcotest prop_alloc;
        ] );
      ( "predicates",
        [
          Alcotest.test_case "received_msg_destined_for" `Quick test_destined;
          Alcotest.test_case "resp_msg_matches_req_msg" `Quick test_matches;
        ] );
      ( "constructors",
        [ Alcotest.test_case "form_matched_err_resp_msg" `Quick test_err_resp ] );
      ("pool", [ Alcotest.test_case "multiset ops" `Quick test_pool ]);
    ]

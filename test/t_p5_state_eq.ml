(* BUILD-SPEC P5 §4 "t_p5_state_eq" — soundness of the {!Cluster_check.state_equal}
   / {!Cluster_check.state_hash} pair the visited-set termination depends on
   (arch §3.1 / §3.2), plus the additive allocator equality (§1).

   Obligations:
   - reflexivity: [state_equal s s] on a real scenario seed.
   - a counter bump ([uid_counter + 1]) makes two states UNEQUAL (a dropped or
     merged counter would hide a counterexample / give an unsound [decisive]).
   - order-insensitivity (TERMINATION-critical, §3.2): two states whose etcd map
     is built by DIFFERENT insertion orders but with equal contents are
     [state_equal], AND their [state_hash] is EQUAL (the [equal a b ==> hash a =
     hash b] invariant the [Hashtbl.Make] visited set relies on; an unsound hash
     would let the visited set miss a state and break termination).
   - {!Message.Rpc_id_allocator.equal} (the §1 additive monotone-counter equality)
     is [false] after one [allocate] and [true] reflexively.

   Convention firewall: no loop keywords; the only matches are the exhaustive list
   [[] | _ :: _]; option handling via Option.fold; [Int.equal] not [Stdlib.(=)];
   [.mli]-free test module (alcotest executable). *)

module Cc = Anvil_checker.Cluster_check
module Scenario = Anvil_assurance.Scenario

let seed : Cluster.cluster_state = Scenario.seed ~desired:1 ~fair:false

(* ---- a small etcd object + key builder (fresh, spec/status Null) ---- *)

let mk_obj ~(name : string) : Dynamic_object.t =
  Dynamic_object.make ~kind:Vreplica_set.kind
    ~metadata:
      {
        (Object_meta.default ()) with
        Object_meta.name = Some name;
        namespace = Some "default";
      }
    ~spec:(Value.of_json `Null) ~status:(Value.of_json `Null)

let key ~(name : string) : Common.object_ref =
  { Common.kind = Vreplica_set.kind; name; namespace = "default" }

let keyA = key ~name:"a"
let keyB = key ~name:"b"
let objA = mk_obj ~name:"a"
let objB = mk_obj ~name:"b"

(* the SAME two bindings, inserted in opposite orders. *)
let etcd_ab : Dynamic_object.t Object_ref_map.t =
  Object_ref_map.add keyB objB (Object_ref_map.add keyA objA Object_ref_map.empty)

let etcd_ba : Dynamic_object.t Object_ref_map.t =
  Object_ref_map.add keyA objA (Object_ref_map.add keyB objB Object_ref_map.empty)

let with_resources (s : Cluster.cluster_state) (r : Dynamic_object.t Object_ref_map.t) :
    Cluster.cluster_state =
  { s with Cluster.api_server = { s.Cluster.api_server with Api_server.resources = r } }

let s_ab = with_resources seed etcd_ab
let s_ba = with_resources seed etcd_ba

let bumped_uid : Cluster.cluster_state =
  {
    seed with
    Cluster.api_server =
      { seed.Cluster.api_server with Api_server.uid_counter = seed.Cluster.api_server.Api_server.uid_counter + 1 };
  }

(* ---- tests ---- *)

let test_reflexive () =
  Alcotest.(check bool) "state_equal is reflexive on the seed" true (Cc.state_equal seed seed)

let test_counter_bump_unequal () =
  Alcotest.(check bool) "a uid_counter bump makes the states UNEQUAL" false
    (Cc.state_equal seed bumped_uid);
  (* symmetry of the discrimination. *)
  Alcotest.(check bool) "unequal is symmetric" false (Cc.state_equal bumped_uid seed)

let test_insertion_order_equal_and_hash () =
  Alcotest.(check bool) "different etcd insertion order, equal contents => state_equal" true
    (Cc.state_equal s_ab s_ba);
  Alcotest.(check int) "and state_hash is EQUAL (equal => hash-equal; termination-critical)"
    (Cc.state_hash s_ab) (Cc.state_hash s_ba)

let test_rpc_allocator_equal () =
  let a0 = Message.Rpc_id_allocator.init () in
  Alcotest.(check bool) "Rpc_id_allocator.equal reflexive" true
    (Message.Rpc_id_allocator.equal a0 a0);
  let a1, _id = Message.Rpc_id_allocator.allocate a0 in
  Alcotest.(check bool) "Rpc_id_allocator.equal is FALSE after one allocate" false
    (Message.Rpc_id_allocator.equal a0 a1)

let () =
  Alcotest.run "p5_state_eq"
    [
      ("reflexive", [ Alcotest.test_case "state_equal s s" `Quick test_reflexive ]);
      ("counter_bump", [ Alcotest.test_case "uid bump -> unequal" `Quick test_counter_bump_unequal ]);
      ("order_insensitive",
       [ Alcotest.test_case "insertion order irrelevant; hash equal" `Quick test_insertion_order_equal_and_hash ]);
      ("rpc_allocator", [ Alcotest.test_case "allocate -> unequal" `Quick test_rpc_allocator_equal ]);
    ]

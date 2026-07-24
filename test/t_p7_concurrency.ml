(* P7 exec-shim tests: the {!Concurrency.Direct} identity-monad backend
   (BUILD-SPEC-P7 §4). Locks the deterministic backend shape the whole exec core
   runs on: the two monad laws, [both] as a left-to-right pair, [sleep] as a
   no-op, and [run] as the identity extraction. *)

module Direct = Anvil_exec.Concurrency.Direct

let test_left_identity () =
  let f x = x + 100 in
  Alcotest.(check int) "bind (return x) f = f x" (f 5)
    (Direct.bind (Direct.return 5) f)

let test_right_identity () =
  let m = 7 in
  Alcotest.(check int) "bind m return = m" m (Direct.bind m Direct.return)

let test_both () =
  Alcotest.(check (pair int string)) "both a b = (a, b)" (3, "x")
    (Direct.both 3 "x")

let test_sleep () =
  Alcotest.(check unit) "sleep is an immediate no-op" () (Direct.sleep ~seconds:1.5)

let test_run () = Alcotest.(check int) "run x = x" 42 (Direct.run 42)

let () =
  Alcotest.run "p7_concurrency"
    [
      ( "direct-monad",
        [
          Alcotest.test_case "left identity" `Quick test_left_identity;
          Alcotest.test_case "right identity" `Quick test_right_identity;
          Alcotest.test_case "both is a sequential pair" `Quick test_both;
          Alcotest.test_case "sleep no-op" `Quick test_sleep;
          Alcotest.test_case "run extracts" `Quick test_run;
        ] );
    ]

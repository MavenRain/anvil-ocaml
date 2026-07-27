(* BUILD-SPEC-P18 section 6, D2 - the (name, source) classification-leak
   detector, extracted from its four byte-identical copies
   (t_p14_regression.ml:132/137, t_p15_regression.ml:175/180,
   t_p16_regression.ml:307/312, t_p17_regression.ml:145/153; P17 disclosed
   residual). A shared NON-test module (not in the [dune] [(names ...)]
   list, so dune links it into every test exe that references it - the
   [p17_witness.ml] precedent), carrying its OWN alias of
   [Anvil_assurance.Invariants] because [test/dune]'s [-open] flags omit
   [Anvil_assurance].

   WHY (name, source) PAIRS - the k3-strengthened identity (P17 section 7):
   the NAME-string proxy missed a leaked member re-shipped under a
   different OCaml name (it keeps its upstream [source] citation), and a
   shipped member reusing one of these NAMES with a different source would
   still poison [violated] attribution - so a hit on EITHER component is
   reported.

   Pure D2 refactor: the four rewired exes' assertions are byte-unchanged
   (only the duplicate definitions moved here); the battery re-green is the
   proof. [t_p18_regression] uses it from birth.

   Firewall honoured: List combinators only, no loop keywords, no wildcard
   match arms. *)

module Invariants = Anvil_assurance.Invariants

(** The (name, source) identity of every member of a suite, in suite
    order - the leak-detection currency (never the OCaml binding name). *)
let pairs_of (invs : Invariants.invariant list) : (string * string) list =
  List.map
    (fun (i : Invariants.invariant) -> (i.Invariants.name, i.Invariants.source))
    invs

(** Every leak of a [family_pairs] member into [suite_pairs], reported as
    one human-readable line per hit ([label] names the suite): a shared
    NAME or a shared SOURCE each counts (either-component detection, the
    k3-strengthened identity above). [[]] is "fully disjoint". *)
let pair_leaks (label : string) (family_pairs : (string * string) list)
    (suite_pairs : (string * string) list) : string list =
  List.concat_map
    (fun ((n, src) : string * string) ->
      List.filter_map
        (fun ((n', src') : string * string) ->
          if String.equal n n' then Some (label ^ " contains name " ^ n)
          else if String.equal src src' then
            Some (label ^ " contains source " ^ src ^ " (as " ^ n' ^ ")")
          else None)
        suite_pairs)
    family_pairs

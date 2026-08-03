(* BUILD-SPEC-P25 section 1.4 - the t_p25_reconcile 4-leg battery, landed
   AFTER riders D1/D2/D3 (the ordering rule, RULING:36-39).

   LEG1 tuple-coherence: every slash-separated numeric run (length >= 3)
   in the corpus (local_binding.mli, fault_check.mli, internal_guarantee.mli,
   BUILD-SPEC-P22.md, BUILD-SPEC-P23.md, p21..p25_witness.ml HEADERS) must be
   a member of a set GENERATED from in-tree witness pins (identifier
   references, never re-typed numbers), or carry a row in the
   recorded-unpinned ledger below (each row quotes the frozen prose's own
   ground for being unpinned - the diagnosis BUILD-SPEC-P25 section 1.4
   demands recorded, not retuned).
   LEG2 partition-reconciliation: prose partition counts == code family
   cardinals across the spec's (file, prose-site, code-site) triples, plus
   every current-form "A shipped + B excluded" string in
   internal_guarantee.mli / local_binding.mli derived-checked against
   (List.length P21_witness.ledger_shipped_lines,
    P21_witness.ledger_spec_fn_count - that length). A red here is a REAL
   FINDING by construction (RULING:38-39) - the assertion is never weakened.
   LEG3 case-count parity: per-exe registered test-case counts (textual
   metric, see p25_witness.ml's pin block) against P25_witness.leg3_case_counts,
   both directions, plus this exe's own registered-equals-run parity.
   LEG4 cite-pins: (path, line, needle) coordinates read with TOTAL
   accessors ONLY - In_channel.input_lines + List.nth_opt (the GATE 5 open
   flag) - never open_in/seek_in/input_line/raw indexing. Upstream anvil-ref
   pins are gated 0 XOR K: an absent ref tree reds LOUDLY.

   File access at run time resolves the repo root by probing "." then ".."
   (dune's @runtest actions run from _build/default/test; a direct exe run
   starts at the repo root). The test/dune (deps ...) question was resolved
   by a REAL @runtest build (2026-08-03): _build/default materializes every
   compiled source, but BUILD-SPEC-P22.md, BUILD-SPEC-P23.md and test/dune
   itself were measured ABSENT, so exactly those three are declared as
   (deps ...) on the stanza - see the comment there.

   Firewall: List/Option/fold combinators only, no loop keywords, no
   exceptions, no two-arm match on Option/Result, no wildcard match on a
   finite sum, no raw indexing (string access goes through String.to_seq),
   no two same-named let bindings. *)

(* ==== 0. total-accessor plumbing ========================================= *)

(* The repo root as seen from the process cwd: "." for a direct run from the
   repo root, ".." for dune's _build/default/test action cwd. Probed by a
   marker file, never assumed. *)
let repo_root : string option =
  List.find_opt
    (fun (cand : string) ->
      Sys.file_exists
        (Filename.concat cand "lib/assurance/internal_guarantee.mli"))
    [ "."; ".."; Filename.concat ".." ".." ]

(* Root-relative path resolution; [None] when no root marker was found. *)
let in_repo (rel : string) : string option =
  Option.map (fun (r : string) -> Filename.concat r rel) repo_root

(* Total whole-file read: [None] instead of an exception on a missing path.
   [In_channel.with_open_text]/[input_all] is the GATE 5 named total chain;
   no [open_in], no [seek_in], no [input_line]. *)
let read_file (path : string) : string option =
  if Sys.file_exists path then
    Some (In_channel.with_open_text path In_channel.input_all)
  else None

(* Root-relative total read. *)
let read_repo_file (rel : string) : string option =
  Option.bind (in_repo rel) read_file

(* Lines of a file content; index access below is List.nth_opt ONLY. *)
let lines_of (content : string) : string list =
  String.split_on_char '\n' content

(* Characters of a string, so no [s.[i]] appears anywhere in this file. *)
let chars_of (s : string) : char list = List.of_seq (String.to_seq s)

(* Character classes for the scanner (ASCII, matching the corpus). *)
let is_digit (c : char) : bool = c >= '0' && c <= '9'

(* "Word" characters end/forbid a numeric-run component: digits, letters,
   underscore - the boundary rule that keeps "82exes"-style tokens and
   ":606"-style cite runs out of LEG1's extraction. *)
let is_word (c : char) : bool =
  is_digit c || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_'

(* [is_prefix needle hay]: total char-list prefix test. *)
let rec is_prefix (needle : char list) (hay : char list) : bool =
  match needle with
  | [] -> true
  | nc :: ntl -> (
      match hay with
      | [] -> false
      | hc :: htl -> Char.equal nc hc && is_prefix ntl htl)

(* Occurrences of [needle] in [hay], counted at every start position. *)
let count_substring ~(needle : string) (hay : string) : int =
  let ncs = chars_of needle in
  let rec go (h : char list) (acc : int) : int =
    match h with
    | [] -> acc
    | _head :: htl -> go htl (acc + (if is_prefix ncs h then 1 else 0))
  in
  if String.length needle = 0 then 0 else go (chars_of hay) 0

(* Substring containment via the counter (one code path, no duplication). *)
let contains_sub ~(needle : string) (hay : string) : bool =
  count_substring ~needle hay > 0

(* Every maximal digit run in a line, in order - LEG2's literal extractor
   for the t_p20_rely code-site line. *)
let ints_in_line (line : string) : int list =
  let step ((acc : int list), (cur : int option)) (c : char) :
      int list * int option =
    if is_digit c then
      (acc, Some ((Option.value ~default:0 cur * 10) + (Char.code c - 48)))
    else (Option.fold ~none:acc ~some:(fun (v : int) -> v :: acc) cur, None)
  in
  let acc, cur = List.fold_left step ([], None) (chars_of line) in
  List.rev (Option.fold ~none:acc ~some:(fun (v : int) -> v :: acc) cur)

(* Render a tuple the way the corpus writes it. *)
let tuple_str (t : int list) : string =
  String.concat "/" (List.map string_of_int t)

(* ==== 1. the LEG1 scanner (token stream, so wrapped runs join) =========== *)

(* Scanner tokens: a number with its boundary context, a slash, or any other
   non-whitespace character (which breaks a run). Whitespace - including
   newlines, hence the multi-line joins the corpus needs (e.g.
   fault_check.mli:2150-2151) - is dropped between tokens. *)
type scan_token =
  | Tok_num of { value : int; line : int; prev : char; tail_ok : bool }
  | Tok_slash
  | Tok_break

(* Tokenize file content. [prev] is the raw character immediately before a
   number (start-of-file counts as whitespace); [tail_ok] is false when the
   character after the digits is a word character. Tail-recursive. *)
let tokenize (content : string) : scan_token list =
  let rec digits (cs : char list) (v : int) : int * char list =
    match cs with
    | [] -> (v, [])
    | d :: dtl ->
        if is_digit d then digits dtl ((v * 10) + (Char.code d - 48))
        else (v, d :: dtl)
  in
  let rec go (cs : char list) (line : int) (prev : char)
      (acc : scan_token list) : scan_token list =
    match cs with
    | [] -> List.rev acc
    | c :: tl ->
        if Char.equal c '\n' then go tl (line + 1) c acc
        else if Char.equal c ' ' || Char.equal c '\t' || Char.equal c '\r'
        then go tl line c acc
        else if Char.equal c '/' then go tl line c (Tok_slash :: acc)
        else if is_digit c then
          let v, rest = digits tl (Char.code c - 48) in
          let tail_ok =
            match rest with [] -> true | r :: _rtl -> not (is_word r)
          in
          go rest line '0' (Tok_num { value = v; line; prev; tail_ok } :: acc)
        else go tl line c (Tok_break :: acc)
  in
  go (chars_of content) 1 ' ' []

(* Assemble numeric runs from the token stream. A run STARTS at a number
   whose [prev] is not ':', not '/', not a word character (that excludes
   cite runs like ":562/581/589/544" whole, tails included) and whose tail
   is clean; it CONTINUES across slash + number where the number's [prev]
   is not ':' and not a word character. Runs shorter than 3 are dropped.
   Tail-recursive fold; result carries the run's first line. *)
let runs_of_tokens (tokens : scan_token list) : (int * int list) list =
  let flush (cur : (int * int list) option) (acc : (int * int list) list) :
      (int * int list) list =
    Option.fold ~none:acc
      ~some:(fun ((ln : int), (rev_vals : int list)) ->
        let vals = List.rev rev_vals in
        if List.length vals >= 3 then (ln, vals) :: acc else acc)
      cur
  in
  let step
      (((acc : (int * int list) list),
        (cur : (int * int list) option),
        (after_slash : bool)))
      (t : scan_token) : (int * int list) list * (int * int list) option * bool
      =
    match t with
    | Tok_break -> (flush cur acc, None, false)
    | Tok_slash ->
        if after_slash then (flush cur acc, None, false)
        else if Option.is_some cur then (acc, cur, true)
        else (acc, None, false)
    | Tok_num { value; line; prev; tail_ok } ->
        let bad_prev_common = Char.equal prev ':' || is_word prev in
        let start_ok =
          tail_ok && (not bad_prev_common) && not (Char.equal prev '/')
        in
        let cont_ok = tail_ok && not bad_prev_common in
        if after_slash then
          if cont_ok && Option.is_some cur then
            ( acc,
              Option.map
                (fun ((ln : int), (vs : int list)) -> (ln, value :: vs))
                cur,
              false )
          else (flush cur acc, None, false)
        else
          let acc2 = flush cur acc in
          if start_ok then (acc2, Some (line, [ value ]), false)
          else (acc2, None, false)
  in
  let acc, cur, _after = List.fold_left step ([], None, false) tokens in
  List.rev (flush cur acc)

(* The two corpus slices BUILD-SPEC-P25 section 1.4 names: whole files, and
   witness-module HEADERS (every line before the first top-level [let ]/
   [module ] line). *)
type corpus_slice = Full_file | Header_only

(* Clip a witness module to its header per the rule above. *)
let header_only (content : string) : string =
  let rec take (ls : string list) (acc : string list) : string list =
    match ls with
    | [] -> List.rev acc
    | l :: tl ->
        if
          String.starts_with ~prefix:"let " l
          || String.starts_with ~prefix:"module " l
        then List.rev acc
        else take tl (l :: acc)
  in
  String.concat "\n" (take (lines_of content) [])

(* Extract every length >= 3 numeric run from one corpus file. *)
let runs_of_slice (content : string) (slice : corpus_slice) :
    (int * int list) list =
  let text =
    match slice with Full_file -> content | Header_only -> header_only content
  in
  runs_of_tokens (tokenize text)

(* ==== 2. LEG1 data: corpus, witness-generated set, recorded-unpinned
   ledger ================================================================= *)

(* The corpus, exactly as BUILD-SPEC-P25 section 1.4 enumerates it. *)
let leg1_corpus : (string * corpus_slice) list =
  [
    ("lib/assurance/local_binding.mli", Full_file);
    ("lib/checker/fault_check.mli", Full_file);
    ("lib/assurance/internal_guarantee.mli", Full_file);
    ("lib/checker/BUILD-SPEC-P22.md", Full_file);
    ("lib/checker/BUILD-SPEC-P23.md", Full_file);
    ("test/p21_witness.ml", Header_only);
    ("test/p22_witness.ml", Header_only);
    ("test/p23_witness.ml", Header_only);
    ("test/p24_witness.ml", Header_only);
    ("test/p25_witness.ml", Header_only);
  ]

(* The witness-generated tuple set: every element is a list of WITNESS
   IDENTIFIER references (or, for the reconcile-ceiling slot, a field of a
   witness bound), never a re-typed number - the "generated, never
   hand-listed" rule. Labels say what each tuple is. The two P25 rows are
   COMPUTED by P25_witness at run time, so a drifted graph reds here too. *)
let witness_backed_tuples : (string * int list) list =
  [
    ( "P25 fair [1;1] E3 trio (states/premise/violating), computed",
      [
        P25_witness.fair_states;
        P25_witness.fair_e3_premise;
        P25_witness.fair_e3_violating;
      ] );
    ( "P25 crash [1;1] E3 trio (states/premise/violating), computed",
      [
        P25_witness.crash_states;
        P25_witness.crash_e3_premise;
        P25_witness.crash_e3_violating;
      ] );
    ( "P13-P21 graph quint L0/Lc/Ld/Lm/L0v",
      [
        P21_witness.l0_states;
        P21_witness.lc_states;
        P21_witness.ld_states;
        P21_witness.lm_states;
        P21_witness.l0v_states;
      ] );
    ( "P13-P21 graph quad L0/Lc/Ld/Lm",
      [
        P21_witness.l0_states;
        P21_witness.lc_states;
        P21_witness.ld_states;
        P21_witness.lm_states;
      ] );
    ( "P22 scale-down graph quad SL0/SLc/SLd/SLm",
      [
        P22_witness.sl0_states;
        P22_witness.slc_states;
        P22_witness.sld_states;
        P22_witness.slm_states;
      ] );
    ( "P22 family-gate quad SL0/SLc/SLd/SLm",
      [
        P22_witness.sl0_gate_states;
        P22_witness.slc_gate_states;
        P22_witness.sld_gate_states;
        P22_witness.slm_gate_states;
      ] );
    ( "P22 per-graph member interesting, SL0 (G1..G4)",
      [
        P22_witness.g1_interesting_sl0;
        P22_witness.g2_interesting_sl0;
        P22_witness.g3_interesting_sl0;
        P22_witness.g4_interesting_sl0;
      ] );
    ( "P22 per-graph member interesting, SLc (G1..G4)",
      [
        P22_witness.g1_interesting_slc;
        P22_witness.g2_interesting_slc;
        P22_witness.g3_interesting_slc;
        P22_witness.g4_interesting_slc;
      ] );
    ( "P22 per-graph member interesting, SLd (G1..G4)",
      [
        P22_witness.g1_interesting_sld;
        P22_witness.g2_interesting_sld;
        P22_witness.g3_interesting_sld;
        P22_witness.g4_interesting_sld;
      ] );
    ( "P22 per-graph member interesting, SLm (G1..G4)",
      [
        P22_witness.g1_interesting_slm;
        P22_witness.g2_interesting_slm;
        P22_witness.g3_interesting_slm;
        P22_witness.g4_interesting_slm;
      ] );
    ( "P22 member-major G2 interesting over SL0/SLc/SLd/SLm",
      [
        P22_witness.g2_interesting_sl0;
        P22_witness.g2_interesting_slc;
        P22_witness.g2_interesting_sld;
        P22_witness.g2_interesting_slm;
      ] );
    ( "P22 member-major G3 interesting over SL0/SLc/SLd/SLm",
      [
        P22_witness.g3_interesting_sl0;
        P22_witness.g3_interesting_slc;
        P22_witness.g3_interesting_sld;
        P22_witness.g3_interesting_slm;
      ] );
    ( "P21 per-graph member interesting, L0 (G1..G4)",
      [
        P21_witness.g1_interesting_l0;
        P21_witness.g2_interesting_l0;
        P21_witness.g3_interesting_l0;
        P21_witness.g4_interesting_l0;
      ] );
    ( "P21 per-graph member interesting, Lc (G1..G4)",
      [
        P21_witness.g1_interesting_lc;
        P21_witness.g2_interesting_lc;
        P21_witness.g3_interesting_lc;
        P21_witness.g4_interesting_lc;
      ] );
    ( "P21 per-graph member interesting, Ld (G1..G4)",
      [
        P21_witness.g1_interesting_ld;
        P21_witness.g2_interesting_ld;
        P21_witness.g3_interesting_ld;
        P21_witness.g4_interesting_ld;
      ] );
    ( "P21 per-graph member interesting, Lm (G1..G4)",
      [
        P21_witness.g1_interesting_lm;
        P21_witness.g2_interesting_lm;
        P21_witness.g3_interesting_lm;
        P21_witness.g4_interesting_lm;
      ] );
    ( "P21 per-graph member interesting, L0v (G1..G4)",
      [
        P21_witness.g1_interesting_l0v;
        P21_witness.g2_interesting_l0v;
        P21_witness.g3_interesting_l0v;
        P21_witness.g4_interesting_l0v;
      ] );
    ( "P14 N1 interesting trio (G1 / G2-all / G2-post-crash)",
      [
        P14_witness.n1_interesting_g1;
        P14_witness.n1_interesting_g2;
        P14_witness.n1_interesting_g2_post_crash;
      ] );
    ( "P14 N2 interesting trio",
      [
        P14_witness.n2_interesting_g1;
        P14_witness.n2_interesting_g2;
        P14_witness.n2_interesting_g2_post_crash;
      ] );
    ( "P14 N3 interesting trio",
      [
        P14_witness.n3_interesting_g1;
        P14_witness.n3_interesting_g2;
        P14_witness.n3_interesting_g2_post_crash;
      ] );
    ( "P14 N4 interesting trio",
      [
        P14_witness.n4_interesting_g1;
        P14_witness.n4_interesting_g2;
        P14_witness.n4_interesting_g2_post_crash;
      ] );
    ( "P14 N5 interesting trio (the vacuity-correction datum)",
      [
        P14_witness.n5_interesting_g1;
        P14_witness.n5_interesting_g2;
        P14_witness.n5_interesting_g2_post_crash;
      ] );
    ( "P13-G1-identity triple (states / crash-witness / fault-free)",
      [
        P15_witness.l1_states;
        P15_witness.l1_crash_witness_states;
        P15_witness.l1_fault_free_states;
      ] );
    ( "P15 reconcile-ceiling sweep: shipped ceiling then the swept ceilings",
      [
        (P15_witness.p15_bound ~desireds:[ P15_witness.witness_desired ])
          .Bound.reconcile_ceiling;
        P15_witness.rc_sweep_low;
        P15_witness.rc_sweep_mid;
        P15_witness.rc_sweep_high;
      ] );
    ( "P15 reconcile-ceiling sweep: zero-budget state counts",
      [
        P15_witness.l0_states;
        P15_witness.l0_rc_low_states;
        P15_witness.l0_rc_mid_states;
        P15_witness.l0_rc_high_states;
      ] );
    ( "P16 Q1/Q2/Q3 interesting on L0v",
      [
        P16_witness.q1_interesting_l0v;
        P16_witness.q2_interesting_l0v;
        P16_witness.q3_interesting_l0v;
      ] );
    ( "P16 Q1/Q2/Q3 interesting on Ldv",
      [
        P16_witness.q1_interesting_ldv;
        P16_witness.q2_interesting_ldv;
        P16_witness.q3_interesting_ldv;
      ] );
    ( "P16 Q1/Q2/Q3 interesting on Lcv",
      [
        P16_witness.q1_interesting_lcv;
        P16_witness.q2_interesting_lcv;
        P16_witness.q3_interesting_lcv;
      ] );
    ( "P16 Q5 interesting quad at vct:false (L0/Lc/Ld/Lm)",
      [
        P16_witness.q5_interesting_l0;
        P16_witness.q5_interesting_lc;
        P16_witness.q5_interesting_ld;
        P16_witness.q5_interesting_lm;
      ] );
    ( "P16 Q5 interesting trio at vct:true (L0v/Ldv/Lcv)",
      [
        P16_witness.q5_interesting_l0v;
        P16_witness.q5_interesting_ldv;
        P16_witness.q5_interesting_lcv;
      ] );
    ( "P17 S1 interesting quad (equal to S3's, the measured coincidence)",
      [
        P17_witness.s1_interesting_l0;
        P17_witness.s1_interesting_lc;
        P17_witness.s1_interesting_ld;
        P17_witness.s1_interesting_lm;
      ] );
    ( "P18 family-gate quint L0/Lc/Ld/Lm/L0v",
      [
        P18_witness.l0_gate_states;
        P18_witness.lc_gate_states;
        P18_witness.ld_gate_states;
        P18_witness.lm_gate_states;
        P18_witness.l0v_gate_states;
      ] );
    ( "P19 family-gate quad L0/Lc/Ld/Lm",
      [
        P19_witness.l0_gate_states;
        P19_witness.lc_gate_states;
        P19_witness.ld_gate_states;
        P19_witness.lm_gate_states;
      ] );
    ( "P19 M1 interesting quad",
      [
        P19_witness.m1_interesting_l0;
        P19_witness.m1_interesting_lc;
        P19_witness.m1_interesting_ld;
        P19_witness.m1_interesting_lm;
      ] );
    ( "P19 M2 interesting quad (zero off the monkey leg)",
      [
        P19_witness.m2_interesting_l0;
        P19_witness.m2_interesting_lc;
        P19_witness.m2_interesting_ld;
        P19_witness.m2_interesting_lm;
      ] );
    ( "P19 M4 interesting quad",
      [
        P19_witness.m4_interesting_l0;
        P19_witness.m4_interesting_lc;
        P19_witness.m4_interesting_ld;
        P19_witness.m4_interesting_lm;
      ] );
    ( "P20 R1/R2/R3 interesting on the forge leg Lf",
      [
        P20_witness.r1_interesting_lf;
        P20_witness.r2_interesting_lf;
        P20_witness.r3_interesting_lf;
      ] );
    ( "P23 C1 needed-forall witness quad",
      [
        P23_witness.needed_witness_bl0;
        P23_witness.needed_witness_blc;
        P23_witness.needed_witness_bld;
        P23_witness.needed_witness_blm;
      ] );
    ( "P23 C2 condemned-forall witness quad",
      [
        P23_witness.condemned_witness_bl0;
        P23_witness.condemned_witness_blc;
        P23_witness.condemned_witness_bld;
        P23_witness.condemned_witness_blm;
      ] );
    ( "P23 C2 condemned-forall fault-leg trio (a wrapped quad's own line)",
      [
        P23_witness.condemned_witness_blc;
        P23_witness.condemned_witness_bld;
        P23_witness.condemned_witness_blm;
      ] );
    ( "P23 L1 interesting quad",
      [
        P23_witness.l1_interesting_bl0;
        P23_witness.l1_interesting_blc;
        P23_witness.l1_interesting_bld;
        P23_witness.l1_interesting_blm;
      ] );
    ( "P23 L2 interesting quad (also the parked-with-pending count)",
      [
        P23_witness.l2_interesting_bl0;
        P23_witness.l2_interesting_blc;
        P23_witness.l2_interesting_bld;
        P23_witness.l2_interesting_blm;
      ] );
    ( "P23 L2 interesting fault-leg trio (the prediction-ledger line)",
      [
        P23_witness.l2_interesting_blc;
        P23_witness.l2_interesting_bld;
        P23_witness.l2_interesting_blm;
      ] );
    ( "P23 family-gate quad BL0/BLc/BLd/BLm",
      [
        P23_witness.bl0_gate_states;
        P23_witness.blc_gate_states;
        P23_witness.bld_gate_states;
        P23_witness.blm_gate_states;
      ] );
    ( "P23 decoded-ongoing quad",
      [
        P23_witness.decoded_bl0;
        P23_witness.decoded_blc;
        P23_witness.decoded_bld;
        P23_witness.decoded_blm;
      ] );
    ( "P23 ok-List-response premise quad",
      [
        P23_witness.ok_list_resps_bl0;
        P23_witness.ok_list_resps_blc;
        P23_witness.ok_list_resps_bld;
        P23_witness.ok_list_resps_blm;
      ] );
    ( "P23 ok-List-response quint (quad + BL0's with-objs count)",
      [
        P23_witness.ok_list_resps_bl0;
        P23_witness.ok_list_resps_blc;
        P23_witness.ok_list_resps_bld;
        P23_witness.ok_list_resps_blm;
        P23_witness.bl0_ok_list_resps_with_objs;
      ] );
    ( "P23 decode-failure zeros, everywhere-zero pin over the four fault legs",
      [
        P23_witness.decode_failures_everywhere;
        P23_witness.decode_failures_everywhere;
        P23_witness.decode_failures_everywhere;
        P23_witness.decode_failures_everywhere;
      ] );
    ( "P23 decode-failure zeros, everywhere-zero pin over all five graphs",
      [
        P23_witness.decode_failures_everywhere;
        P23_witness.decode_failures_everywhere;
        P23_witness.decode_failures_everywhere;
        P23_witness.decode_failures_everywhere;
        P23_witness.decode_failures_everywhere;
      ] );
    ( "P24 set-equality failure quad SP0/SPc/SPd/SPm",
      [
        P24_witness.set_equality_failures_sp0;
        P24_witness.set_equality_failures_spc;
        P24_witness.set_equality_failures_spd;
        P24_witness.set_equality_failures_spm;
      ] );
    ( "P24 set-equality etcd-extra quad",
      [
        P24_witness.set_equality_etcd_extra_sp0;
        P24_witness.set_equality_etcd_extra_spc;
        P24_witness.set_equality_etcd_extra_spd;
        P24_witness.set_equality_etcd_extra_spm;
      ] );
    ( "P24 set-equality resp-extra quad",
      [
        P24_witness.set_equality_resp_extra_sp0;
        P24_witness.set_equality_resp_extra_spc;
        P24_witness.set_equality_resp_extra_spd;
        P24_witness.set_equality_resp_extra_spm;
      ] );
    ( "P24 coherence-failure quad",
      [
        P24_witness.coherence_failures_sp0;
        P24_witness.coherence_failures_spc;
        P24_witness.coherence_failures_spd;
        P24_witness.coherence_failures_spm;
      ] );
    ( "P24 coherence key-absent quad",
      [
        P24_witness.coherence_key_absent_sp0;
        P24_witness.coherence_key_absent_spc;
        P24_witness.coherence_key_absent_spd;
        P24_witness.coherence_key_absent_spm;
      ] );
  ]

(* The recorded-unpinned ledger: corpus tuples whose OWN prose (or the
   witness module beside them) records them as measured-but-unpinned, in
   FROZEN history this phase may not edit (BUILD-SPEC-P25 section 6.2).
   Each row is (corpus file, tuple, verbatim ground). These integers are
   typed here - a DEVIATION from the never-hand-listed rule, taken instead
   of editing frozen specs or minting P25-named re-pins of other phases'
   numbers, and reported in the battery's landing summary. A row whose
   tuple stops appearing in its file reds the staleness check below, so
   the ledger cannot outlive the prose it excuses. *)
let recorded_unpinned_ledger : (string * int list * string) list =
  [
    ( "lib/checker/BUILD-SPEC-P22.md",
      [ 1; 14; 15; 67 ],
      "P22 spec :360-362 'Secondary aggregates (recorded, not pinned): ... \
       settled_with_faults_live 1 / 14 / 15 / 67' - deliberately unpinned \
       frozen history" );
    ( "lib/checker/BUILD-SPEC-P22.md",
      [ 6; 8; 10; 12 ],
      "P22 spec :426 (MS3 row): the sabotaged-seed divergence probe's depth \
       sweep, 'documented in the exe header', never a witness pin" );
    ( "lib/checker/BUILD-SPEC-P22.md",
      [ 197; 861; 3787; 16330 ],
      "P22 spec :426 (MS3 row): the divergence state counts at depths \
       6/8/10/12, same recorded-not-pinned ground" );
    ( "lib/checker/fault_check.mli",
      [ 8; 52; 48; 744 ],
      "p24_witness.ml:617-620: the pending-still-in-flight = delivery-window \
       equality was measured and 'left as prose'; asserted computationally \
       by the P24 exes, no witness int pin exists" );
    ( "lib/checker/fault_check.mli",
      [ 8; 60; 40; 776 ],
      "p24_witness.ml:63-69 (B3): ok-list responses 'NON-EMPTY at 8 / 60 / \
       40 / 776' is a stage-B verdict recorded in prose; no witness int pin" );
    ( "test/p24_witness.ml",
      [ 8; 60; 40; 776 ],
      "p24_witness.ml:63-69 (B3), the same prose verdict in its own header" );
    ( "lib/checker/fault_check.mli",
      [ 8; 76; 64; 1272 ],
      "fault_check.mli:2431-2434: the sibling Delete_outdated occupancy \
       column; only the zero (P24_witness.\
       after_delete_outdated_occupancy_everywhere) is pinned" );
    ( "lib/checker/BUILD-SPEC-P23.md",
      [ 76; 680; 1056; 8872; 76 ],
      "P23 spec :1032/:1052: the five-graph decoded row; the four fault-leg \
       slots are pinned (P23_witness.decoded_bl*), BN0's fifth 76 exists in \
       spec prose only" );
  ]

(* ==== 3. LEG1 ============================================================ *)

(* Extract, then check: every corpus tuple is witness-backed or ledgered;
   every ledger row still occurs; the scanner sentinel proves the extractor
   reaches the corpus (a P22-gate tuple appears at least twice in
   local_binding.mli). Failures carry file:line + the tuple. *)
let leg1_tuple_coherence () : unit =
  let corpus_runs : (string * (int * int list) list option) list =
    List.map
      (fun ((rel : string), (slice : corpus_slice)) ->
        ( rel,
          Option.map
            (fun (content : string) -> runs_of_slice content slice)
            (read_repo_file rel) ))
      leg1_corpus
  in
  let allowed : int list list = List.map snd witness_backed_tuples in
  let is_allowed (run : int list) : bool =
    List.exists (fun (t : int list) -> List.equal Int.equal t run) allowed
  in
  let is_ledgered (rel : string) (run : int list) : bool =
    List.exists
      (fun ((lf : string), (lt : int list), (_ground : string)) ->
        String.equal lf rel && List.equal Int.equal lt run)
      recorded_unpinned_ledger
  in
  let file_failures =
    List.concat_map
      (fun ((rel : string), (runs_opt : (int * int list) list option)) ->
        Option.fold
          ~none:
            [
              Printf.sprintf
                "%s: corpus file MISSING at run time (the test/dune (deps \
                 ...) open flag, BUILD-SPEC-P25 section 1.4)"
                rel;
            ]
          ~some:
            (List.filter_map (fun ((line : int), (run : int list)) ->
                 if is_allowed run || is_ledgered rel run then None
                 else
                   Some
                     (Printf.sprintf
                        "%s:%d: tuple %s is neither witness-backed nor in \
                         the recorded-unpinned ledger"
                        rel line (tuple_str run))))
          runs_opt)
      corpus_runs
  in
  let ledger_staleness =
    List.filter_map
      (fun ((lf : string), (lt : int list), (_ground : string)) ->
        let present =
          List.exists
            (fun ((rel : string), (runs_opt : (int * int list) list option)) ->
              String.equal rel lf
              && Option.fold ~none:false
                   ~some:
                     (List.exists (fun ((_l : int), (run : int list)) ->
                          List.equal Int.equal run lt))
                   runs_opt)
            corpus_runs
        in
        if present then None
        else
          Some
            (Printf.sprintf
               "STALE ledger row: %s no longer contains tuple %s - delete \
                the row"
               lf (tuple_str lt)))
      recorded_unpinned_ledger
  in
  let sentinel_count =
    List.fold_left
      (fun (acc : int) ((rel : string), (runs_opt : (int * int list) list option))
           ->
        if String.equal rel "lib/assurance/local_binding.mli" then
          acc
          + Option.fold ~none:0
              ~some:
                (List.fold_left
                   (fun (a : int) ((_l : int), (run : int list)) ->
                     if
                       List.equal Int.equal run
                         [
                           P22_witness.sl0_gate_states;
                           P22_witness.slc_gate_states;
                           P22_witness.sld_gate_states;
                           P22_witness.slm_gate_states;
                         ]
                     then a + 1
                     else a)
                   0)
              runs_opt
        else acc)
      0 corpus_runs
  in
  let sentinel_failures =
    if sentinel_count >= 2 then []
    else
      [
        Printf.sprintf
          "scanner sentinel: expected the P22 gate quad at least twice in \
           local_binding.mli, saw %d - the extractor is not reaching the \
           corpus"
          sentinel_count;
      ]
  in
  Alcotest.(check (list string))
    "LEG1: every corpus tuple is witness-backed (or carries a recorded \
     unpinned ground), no stale ledger rows, sentinel extracted"
    []
    (file_failures @ ledger_staleness @ sentinel_failures)

(* ==== 4. LEG2 ============================================================ *)

(* The derived partition: (shipped, excluded) from the live P21 witness
   pins, per BUILD-SPEC-P25 section 1.4 LEG2 - never re-typed. *)
let derived_partition () : int * int =
  let shipped = List.length P21_witness.ledger_shipped_lines in
  (shipped, P21_witness.ledger_spec_fn_count - shipped)

(* Past-tense markers exempting a partition restatement line (the spec's
   list, applied per line): " was ", "P21 wrote", "->", "RE-PARTITIONED BY". *)
let partition_line_exempt (line : string) : bool =
  contains_sub ~needle:" was " line
  || contains_sub ~needle:"P21 wrote" line
  || contains_sub ~needle:"->" line
  || contains_sub ~needle:"RE-PARTITIONED BY" line

(* Parse "A shipped + B excluded" out of a line (word-wise, punctuation
   tolerated after "excluded"). *)
let partition_counts (line : string) : (int * int) option =
  let words =
    List.filter
      (fun (w : string) -> not (String.equal w ""))
      (String.split_on_char ' ' line)
  in
  let rec seek (ws : string list) : (int * int) option =
    match ws with
    | [] -> None
    | a :: tl ->
        let here =
          match tl with
          | s :: p :: b :: e :: _rest ->
              if
                String.equal s "shipped" && String.equal p "+"
                && String.starts_with ~prefix:"excluded" e
              then
                Option.bind (int_of_string_opt a) (fun (n : int) ->
                    Option.map (fun (m : int) -> (n, m)) (int_of_string_opt b))
              else None
          | [] -> None
          | [ _w1 ] -> None
          | [ _w1; _w2 ] -> None
          | [ _w1; _w2; _w3 ] -> None
        in
        if Option.is_some here then here else seek tl
  in
  seek words

(* Layer 1 cardinal triples with module-valued code sites: (prose file,
   prose line, pin label, pin value). The prose line must contain
   "expected cardinal <pin>" with <pin> DERIVED from the witness value. *)
let cardinal_triples : (string * int * string * int) list =
  [
    ( "lib/assurance/internal_guarantee.mli",
      232,
      "P21_witness.guarantee_cardinal",
      P21_witness.guarantee_cardinal );
    ( "lib/assurance/local_binding.mli",
      331,
      "P23_witness.binding_cardinal",
      P23_witness.binding_cardinal );
    ( "lib/assurance/state_predicates.mli",
      861,
      "P24_witness.predicate_cardinal",
      P24_witness.predicate_cardinal );
  ]

(* The rely triple's code site is a committed literal in another exe's
   source (t_p20_rely.ml:375, "rely_family cardinal = 3"), read textually:
   all integers on that line must agree, and that value is the pin. *)
let rely_code_site : string * int = ("test/t_p20_rely.ml", 375)

(* LEG2 proper: layer 1 (cardinal triples) then layer 2 (E-ledger
   restatements in internal_guarantee.mli and local_binding.mli against the
   derived partition). Reds print the exact mismatch and are REAL FINDINGS
   (never weaken this assertion - BUILD-SPEC-P25 section 1.4 / section 4's
   LEG2-red rule). *)
let leg2_partition_reconciliation () : unit =
  let check_prose_line ((rel : string), (line_no : int), (label : string),
                        (pin : int)) : string option =
    let needle = Printf.sprintf "expected cardinal %d" pin in
    Option.fold
      ~none:
        (Some
           (Printf.sprintf "%s: unreadable at run time (cardinal triple)" rel))
      ~some:(fun (content : string) ->
        Option.fold
          ~none:
            (Some
               (Printf.sprintf "%s:%d: line does not exist (cardinal triple)"
                  rel line_no))
          ~some:(fun (line : string) ->
            if contains_sub ~needle line then None
            else
              Some
                (Printf.sprintf
                   "%s:%d: expected \"%s\" (from %s = %d), line reads: %s" rel
                   line_no needle label pin (String.trim line)))
          (List.nth_opt (lines_of content) (line_no - 1)))
      (read_repo_file rel)
  in
  let layer1_module_sites = List.filter_map check_prose_line cardinal_triples in
  let rely_failures =
    let rel, line_no = rely_code_site in
    Option.fold
      ~none:[ Printf.sprintf "%s: unreadable at run time (rely triple)" rel ]
      ~some:(fun (content : string) ->
        Option.fold
          ~none:
            [
              Printf.sprintf "%s:%d: line does not exist (rely triple)" rel
                line_no;
            ]
          ~some:(fun (line : string) ->
            let ints = ints_in_line line in
            let all_equal =
              match ints with
              | [] -> false
              | v :: rest -> List.for_all (fun (x : int) -> x = v) rest
            in
            match ints with
            | [] ->
                [
                  Printf.sprintf
                    "%s:%d: no integer literal found (rely triple)" rel
                    line_no;
                ]
            | v :: _rest ->
                if not all_equal then
                  [
                    Printf.sprintf
                      "%s:%d: integers on the line disagree (rely triple)" rel
                      line_no;
                  ]
                else
                  Option.fold ~none:[]
                    ~some:(fun (f : string) -> [ f ])
                    (check_prose_line
                       ( "lib/assurance/rely_conditions.mli",
                         239,
                         Printf.sprintf "t_p20_rely.ml:%d committed literal"
                           line_no,
                         v )))
          (List.nth_opt (lines_of content) (line_no - 1)))
      (read_repo_file rel)
  in
  let shipped, excluded = derived_partition () in
  let layer2_failures =
    List.concat_map
      (fun (rel : string) ->
        Option.fold
          ~none:
            [
              Printf.sprintf "%s: unreadable at run time (E-ledger layer)" rel;
            ]
          ~some:(fun (content : string) ->
            List.filter_map
              (fun ((idx : int), (line : string)) ->
                Option.bind (partition_counts line)
                  (fun ((n : int), (m : int)) ->
                    if partition_line_exempt line then None
                    else if n = shipped && m = excluded then None
                    else
                      Some
                        (Printf.sprintf
                           "%s:%d: current-form partition \"%d shipped + %d \
                            excluded\" but the pins derive (%d shipped + %d \
                            excluded) from P21_witness.ledger_shipped_lines \
                            / ledger_spec_fn_count"
                           rel idx n m shipped excluded)))
              (List.mapi
                 (fun (i : int) (l : string) -> (i + 1, l))
                 (lines_of content)))
          (read_repo_file rel))
      [ "lib/assurance/internal_guarantee.mli"; "lib/assurance/local_binding.mli" ]
  in
  Alcotest.(check (list string))
    "LEG2: cardinal triples agree and every current-form E-ledger \
     restatement equals the derived partition"
    []
    (layer1_module_sites @ rely_failures @ layer2_failures)

(* ==== 5. LEG3 ============================================================ *)

(* The registration-call token, split so THIS occurrence is not counted by
   the textual metric it defines. *)
let case_needle : string = "Alcotest." ^ "test_case"

(* Word characters for dune-name tokenization (names are [a-z0-9_]). *)
let dune_names (dune_src : string) : string list =
  let step ((acc : string list), (cur : char list)) (c : char) :
      string list * char list =
    if is_word c then (acc, c :: cur)
    else if List.length cur > 0 then
      (String.init (List.length cur) (fun (i : int) ->
           Option.value ~default:' '
             (List.nth_opt (List.rev cur) i))
       :: acc,
       [])
    else (acc, [])
  in
  let acc, cur = List.fold_left step ([], []) (chars_of dune_src) in
  let words =
    if List.length cur > 0 then
      String.init (List.length cur) (fun (i : int) ->
          Option.value ~default:' ' (List.nth_opt (List.rev cur) i))
      :: acc
    else acc
  in
  List.sort_uniq String.compare
    (List.filter (String.starts_with ~prefix:"t_p2") words)

(* LEG3: dune-registered t_p2* exes vs P25_witness.leg3_case_counts, both
   directions, and per-exe textual registration counts. *)
let leg3_case_count_parity () : unit =
  let pins = P25_witness.leg3_case_counts in
  (* [~none] is EAGER, so it carries a plain failure list, never an
     effect; the single check runs once at the end. *)
  let failures =
    Option.fold
      ~none:[ "test/dune: unreadable at run time" ]
      ~some:(fun (dune_src : string) ->
      let names = dune_names dune_src in
      let missing_pins =
        List.filter_map
          (fun (n : string) ->
            if
              Option.is_some
                (List.assoc_opt n pins)
            then None
            else
              Some
                (Printf.sprintf
                   "%s: registered in test/dune but has no LEG3 pin in \
                    p25_witness.ml"
                   n))
          names
      in
      let orphan_pins =
        List.filter_map
          (fun ((n : string), (_c : int)) ->
            if List.exists (String.equal n) names then None
            else
              Some
                (Printf.sprintf
                   "%s: has a LEG3 pin but is not a registered t_p2* exe in \
                    test/dune"
                   n))
          pins
      in
      let count_failures =
        List.filter_map
          (fun (n : string) ->
            Option.bind (List.assoc_opt n pins) (fun (expected : int) ->
                Option.fold
                  ~none:
                    (Some
                       (Printf.sprintf "test/%s.ml: unreadable at run time" n))
                  ~some:(fun (src : string) ->
                    let got = count_substring ~needle:case_needle src in
                    if got = expected then None
                    else
                      Some
                        (Printf.sprintf
                           "test/%s.ml: %d registration tokens, pin says %d \
                            (a shadowed or dropped registration moves this)"
                           n got expected))
                  (read_repo_file (Printf.sprintf "test/%s.ml" n))))
          names
      in
      missing_pins @ orphan_pins @ count_failures)
      (read_repo_file "test/dune")
  in
  Alcotest.(check (list string))
    "LEG3: pin domain = dune t_p2* exe set and every per-exe registration \
     count matches its pin"
    [] failures

(* ==== 6. LEG4 ============================================================ *)

(* Repo-side cite pins: (root-relative path, 1-indexed line, needle). The
   D1/D2/D3 rows pin the riders' landed coordinates. *)
let repo_cite_pins : (string * int * string) list =
  [
    ("lib/assurance/invariants.ml", 1046, "first_violated");
    ("lib/checker/model_check.mli", 57, "val explore");
    ("lib/assurance/scenario.ml", 459, "V_stateful_set_reconciler.pod_name");
    ("lib/assurance/scenario.ml", 495, "seed-integrity OBLIGATION");
    ( "lib/assurance/vsts_invariants.ml",
      217,
      "helper_invariants/predicate.rs:237" );
    ("lib/assurance/internal_guarantee.mli", 181, "RE-PARTITIONED BY P25");
    ("lib/assurance/internal_guarantee.mli", 201, "7 shipped + 2 excluded");
    ( "lib/assurance/internal_guarantee.mli",
      252,
      "val local_pods_and_pvcs_are_bound_to_vsts" );
    ("lib/checker/BUILD-SPEC-P23.md", 463, "p21_witness.ml:140-144");
    ( "lib/checker/BUILD-SPEC-P23.md",
      740,
      "Internal_guarantee.guarantee_family ~cr ~controller_id" );
  ]

(* Upstream cite pins into anvil-ref's internal_rely_guarantee.rs: E3's
   :606 definition, E4/E5 (:613/:640), the with_key body lines L2 renders
   (:642/:646/:655-656/:659-661) and the preservation lemma (:668). *)
let upstream_cite_pins : (int * string) list =
  [
    (606, "pub open spec fn local_pods_and_pvcs_are_bound_to_vsts(controller_id: int)");
    (613, "pub open spec fn local_pods_and_pvcs_are_bound_to_vsts_with_key_in_local_state");
    (640, "pub open spec fn local_pods_and_pvcs_are_bound_to_vsts_with_key(controller_id: int");
    (642, "local_pods_and_pvcs_are_bound_to_vsts_with_key_in_local_state(cr_key, local_state)");
    (646, "req_msg.dst is APIServer");
    (655, "msg.src is APIServer");
    (656, "resp_msg_matches_req_msg(msg, req_msg)");
    (659, "get_list_response().res.unwrap()");
    (660, "0 <= i < resp_objs.len()");
    (661, "resp_objs[i].metadata.namespace == Some(cr_key.namespace)");
    (668,
     "lemma_local_pods_and_pvcs_are_bound_to_vsts_with_key_preserves_from_s_to_s_prime_during_controller_step");
  ]

(* The upstream file, HOME-anchored (the ref tree is a sibling checkout,
   never inside this repo). *)
let upstream_rs_path : string option =
  Option.map
    (fun (home : string) ->
      Filename.concat home
        "Documents/anvil-ref/src/controllers/vstatefulset_controller/proof/internal_rely_guarantee.rs")
    (Sys.getenv_opt "HOME")

(* Check one (line, needle) pin against pre-read lines. *)
let check_line_pin (label : string) (file_lines : string list)
    ((line_no : int), (needle : string)) : string option =
  Option.fold
    ~none:
      (Some (Printf.sprintf "%s:%d: line does not exist" label line_no))
    ~some:(fun (line : string) ->
      if contains_sub ~needle line then None
      else
        Some
          (Printf.sprintf "%s:%d: needle \"%s\" not found; line reads: %s"
             label line_no needle (String.trim line)))
    (List.nth_opt file_lines (line_no - 1))

(* LEG4: every repo pin holds; upstream pins are all-or-nothing (0 XOR K)
   with an absent tree failing LOUD, and the checked count held against
   P25_witness.leg4_upstream_cite_count. *)
let leg4_cite_pins () : unit =
  let repo_failures =
    List.filter_map
      (fun ((rel : string), (line_no : int), (needle : string)) ->
        Option.fold
          ~none:(Some (Printf.sprintf "%s: unreadable at run time" rel))
          ~some:(fun (content : string) ->
            check_line_pin rel (lines_of content) (line_no, needle))
          (read_repo_file rel))
      repo_cite_pins
  in
  let k = P25_witness.leg4_upstream_cite_count in
  let upstream_failures =
    Option.fold
      ~none:
        [
          Printf.sprintf
            "anvil-ref: HOME not set - 0 of %d upstream cite pins checked \
             (0 XOR K gate: LOUD, not vacuous)"
            k;
        ]
      ~some:(fun (path : string) ->
        Option.fold
          ~none:
            [
              Printf.sprintf
                "anvil-ref tree ABSENT at %s - 0 of %d upstream cite pins \
                 checked (0 XOR K gate: LOUD, not vacuous)"
                path k;
            ]
          ~some:(fun (content : string) ->
            let file_lines = lines_of content in
            let pin_failures =
              List.filter_map
                (check_line_pin "internal_rely_guarantee.rs" file_lines)
                upstream_cite_pins
            in
            let count_failures =
              if List.length upstream_cite_pins = k then []
              else
                [
                  Printf.sprintf
                    "upstream pin list length %d does not equal the \
                     committed checked-count pin %d"
                    (List.length upstream_cite_pins)
                    k;
                ]
            in
            pin_failures @ count_failures)
          (read_file path))
      upstream_rs_path
  in
  Alcotest.(check (list string))
    "LEG4: every repo cite pin and all K upstream cite pins hold (absent \
     ref tree reds loud)"
    []
    (repo_failures @ upstream_failures)

(* ==== 7. registration ==================================================== *)

(* The four legs; the parity case is appended at [run] and counts itself. *)
let leg_cases : unit Alcotest.test list =
  [
    ( "leg1_tuple_coherence",
      [
        Alcotest.test_case
          "every corpus slash-tuple is witness-generated or carries a \
           recorded unpinned ground"
          `Quick leg1_tuple_coherence;
      ] );
    ( "leg2_partition_reconciliation",
      [
        Alcotest.test_case
          "prose partition counts equal code family cardinals (a red here \
           is a REAL FINDING, never weakened)"
          `Quick leg2_partition_reconciliation;
      ] );
    ( "leg3_case_count_parity",
      [
        Alcotest.test_case
          "per-exe registered-case counts match the fresh-measured pins, \
           both directions"
          `Quick leg3_case_count_parity;
      ] );
    ( "leg4_cite_pins",
      [
        Alcotest.test_case
          "load-bearing cross-file citation coordinates hold (total \
           accessors; upstream 0 XOR K)"
          `Quick leg4_cite_pins;
      ] );
  ]

(* Registered-equals-run parity: four leg cases plus this case is FIVE,
   held against both the local count and the exe's own LEG3 pin, so a
   silently-dropped registration reds twice. *)
let battery_registered_case_count : int = 5

let test_registered_equals_run () : unit =
  Alcotest.(check int)
    "registered = run: 4 leg cases + this parity case = 5"
    battery_registered_case_count
    (1 + List.length (List.concat_map snd leg_cases));
  Alcotest.(check (option int))
    "the battery's own LEG3 pin agrees with its registered surface"
    (Some battery_registered_case_count)
    (List.assoc_opt "t_p25_reconcile" P25_witness.leg3_case_counts)

let () =
  Alcotest.run "p25_reconcile"
    (leg_cases
    @ [
        ( "case_parity",
          [
            Alcotest.test_case
              "registered case count = run case count (5), and the LEG3 \
               self pin agrees"
              `Quick test_registered_equals_run;
          ] );
      ])

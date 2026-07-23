(* BUILD-SPEC P4 §4 "t_p4_roundtrip" — deep marshal round-trips.

   Two QCheck round-trips, each an OCaml stand-in for one of Anvil's
   marshal_preserves_* obligations (which hold for ALL values):

   (a) Vreplica_set_reconciler.s through Vreplica_set_pack.marshal_state /
       unmarshal_state. reconcile_step ranges over ALL SEVEN step variants
       (Init / After_list_pods / After_create_pod n / After_delete_pod n /
       After_update_vrs_status / Done / Error, with realistic n), and
       filtered_pods is Some [deeply-populated Pod.t; ...] on a healthy fraction
       of cases — NOT always None. (None-only was the P3 vacuity trap: the
       filteredPods leg of the codec is never exercised, so a miskeyed pod-list
       codec would pass silently.) Property: unmarshal_state (marshal_state s)
       = Ok s' with s' equal to s.

   (b) The vrs+pod *views* through their Dynamic_object marshal / unmarshal
       (Pod.marshal : t -> Dynamic_object.t, Pod.unmarshal : Dynamic_object.t ->
       t Res.t; same for Vreplica_set). The generated view carries populated
       metadata — owner_refs / uid / rv all Some on a healthy fraction — so the
       Dynamic_object threaded through marshal is itself populated (spec §4(b)
       "arbitrary Dynamic_object.t, vrs + pod kinds, populated metadata incl
       owner_refs/uid/rv, round-tripped through the matching view").
       Property: unmarshal (marshal v) = Ok v' with v' equal to v.

   Confirm-by-mutation ([[feedback-confirm-tests-by-mutation]], spec §6): the
   `mutation` suite corrupts a marshalled state one key at a time and asserts the
   round-trip property (unmarshal = Ok s) then FAILS — proving the property is
   live and its equality discriminates, not vacuously true. A second, transient
   demonstration was performed against the library codec during build and is
   documented at the foot of this file.

   Generators mirror test/t_marshal_props.ml's style. Lists are 0-3, strings
   small, so each 200-count property stays well under a second. *)

module Gen = QCheck.Gen

let ( let* ) = Gen.bind

let g_string : string Gen.t =
  Gen.oneof_list [ ""; "a"; "b"; "x"; "ns"; "nginx"; "svc"; "vreplicaset-x" ]

let g_int : int Gen.t = Gen.int_bound 1000
let g_bool : bool Gen.t = Gen.bool
let g_opt (g : 'a Gen.t) : 'a option Gen.t = Gen.option g

(* 0-3 elements: keeps deeply-nested samples bounded. *)
let g_list (g : 'a Gen.t) : 'a list Gen.t = Gen.list_size (Gen.int_bound 3) g

(* Some four times out of five: populates the "incl owner_refs/uid/rv" fields
   on a healthy fraction while still drawing None sometimes (both legs of every
   optional codec must round-trip). *)
let g_some_biased (g : 'a Gen.t) : 'a option Gen.t =
  Gen.oneof_weighted [ (4, Gen.map Option.some g); (1, Gen.return None) ]

let g_uid : Common.Uid.t Gen.t = Gen.map Common.Uid.of_int (Gen.int_bound 1000)

let g_rv : Common.Resource_version.t Gen.t =
  Gen.map Common.Resource_version.of_int (Gen.int_bound 1000)

let g_smap : string Smap.t Gen.t =
  Gen.map
    (fun kvs -> List.fold_left (fun m (k, v) -> Smap.add k v m) Smap.empty kvs)
    (Gen.list_size (Gen.int_bound 3) (Gen.pair g_string g_string))

let g_kind : Common.kind Gen.t =
  Gen.oneof
    [
      Gen.return Common.Pod;
      Gen.return Common.Config_map;
      Gen.return Common.Stateful_set;
      Gen.map (fun s -> Common.Custom_resource s) g_string;
    ]

let g_owner_ref : Owner_reference.t Gen.t =
  let* block_owner_deletion = g_opt g_bool in
  let* controller = g_opt g_bool in
  let* kind = g_kind in
  let* name = g_string in
  let* uid = g_uid in
  Gen.return
    ({ block_owner_deletion; controller; kind; name; uid } : Owner_reference.t)

(* Populated metadata: name/namespace/uid/rv/labels/owner_references drawn
   Some-biased so the round-trip exercises them; the rest plain optional. *)
let g_meta : Object_meta.t Gen.t =
  let* name = g_some_biased g_string in
  let* generate_name = g_opt g_string in
  let* namespace = g_some_biased g_string in
  let* resource_version = g_some_biased g_rv in
  let* uid = g_some_biased g_uid in
  let* labels = g_some_biased g_smap in
  let* annotations = g_opt g_smap in
  let* owner_references = g_some_biased (g_list g_owner_ref) in
  let* finalizers = g_opt (g_list g_string) in
  let* deletion_timestamp = g_opt g_string in
  Gen.return
    ({
       name;
       generate_name;
       namespace;
       resource_version;
       uid;
       labels;
       annotations;
       owner_references;
       finalizers;
       deletion_timestamp;
     }
      : Object_meta.t)

let g_container_port : Container.container_port Gen.t =
  let* container_port = g_int in
  let* name = g_opt g_string in
  let* protocol = g_opt g_string in
  Gen.return ({ container_port; name; protocol } : Container.container_port)

(* Start from the default and populate the leaf-codec-bearing fields; the deep
   container/volume codecs are exhaustively covered by t_marshal_props, so a
   moderately populated container suffices to give the pod list real content. *)
let g_container : Container.t Gen.t =
  let* name = g_string in
  let* image = g_opt g_string in
  let* ports = g_opt (g_list g_container_port) in
  let* command = g_opt (g_list g_string) in
  Gen.return { (Container.default ()) with name; image; ports; command }

let g_pod_spec : Pod_spec.t Gen.t =
  let* containers = g_list g_container in
  let* node_selector = g_opt g_smap in
  let* service_account_name = g_opt g_string in
  let* hostname = g_opt g_string in
  Gen.return
    {
      (Pod_spec.default ()) with
      containers;
      node_selector;
      service_account_name;
      hostname;
    }

let g_pod : Pod.t Gen.t =
  let* metadata = g_meta in
  let* spec = g_opt g_pod_spec in
  let* status = g_opt (Gen.return ()) in
  Gen.return (Pod.make ~metadata ~spec ~status)

(* -- (a) reconcile-state generators -- *)

(* All SEVEN step variants; the two After_*_pod carry a realistic natural. *)
let g_step : Vreplica_set_reconciler.step Gen.t =
  let module V = Vreplica_set_reconciler in
  Gen.oneof
    [
      Gen.return V.Init;
      Gen.return V.After_list_pods;
      Gen.map (fun n -> V.After_create_pod n) (Gen.int_bound 100);
      Gen.map (fun n -> V.After_delete_pod n) (Gen.int_bound 100);
      Gen.return V.After_update_vrs_status;
      Gen.return V.Done;
      Gen.return V.Error;
    ]

(* Some (non-empty) on a healthy fraction, Some [] and None both drawn so the
   None-vs-empty-list codec boundary is covered; guards the P3 vacuity trap. *)
let g_filtered_pods : Pod.t list option Gen.t =
  Gen.oneof_weighted
    [
      (3, Gen.map Option.some (Gen.list_size (Gen.map succ (Gen.int_bound 2)) g_pod));
      (1, Gen.return (Some []));
      (1, Gen.return None);
    ]

let g_s : Vreplica_set_reconciler.s Gen.t =
  let* reconcile_step = g_step in
  let* filtered_pods = g_filtered_pods in
  Gen.return
    ({ Vreplica_set_reconciler.reconcile_step; filtered_pods }
      : Vreplica_set_reconciler.s)

let s_equal (a : Vreplica_set_reconciler.s) (b : Vreplica_set_reconciler.s) : bool
    =
  Vreplica_set_reconciler.step_equal a.Vreplica_set_reconciler.reconcile_step
    b.Vreplica_set_reconciler.reconcile_step
  && Option.equal (List.equal Pod.equal) a.Vreplica_set_reconciler.filtered_pods
       b.Vreplica_set_reconciler.filtered_pods

(* -- (b) vrs-view generators -- *)

let g_label_selector : Label_selector.t Gen.t =
  let* match_labels = g_opt g_smap in
  Gen.return ({ match_labels } : Label_selector.t)

let g_pod_template : Pod_template_spec.t Gen.t =
  let* metadata = g_opt g_meta in
  let* spec = g_opt g_pod_spec in
  Gen.return ({ metadata; spec } : Pod_template_spec.t)

let g_vrs_spec : Vreplica_set.vrs_spec Gen.t =
  let* replicas = g_opt g_int in
  let* selector = g_label_selector in
  let* template = g_opt g_pod_template in
  Gen.return ({ replicas; selector; template } : Vreplica_set.vrs_spec)

let g_vrs_status : Vreplica_set.vrs_status Gen.t =
  let* replicas = g_int in
  Gen.return ({ replicas } : Vreplica_set.vrs_status)

let g_vrs : Vreplica_set.t Gen.t =
  let* metadata = g_meta in
  let* spec = g_vrs_spec in
  let* status = g_opt g_vrs_status in
  Gen.return (Vreplica_set.make ~metadata ~spec ~status)

(* Generic round-trip: unmarshal (marshal o) = Ok o' with o' equal to o. *)
let prop_roundtrip name gen equal marshal unmarshal =
  QCheck.Test.make ~count:200 ~name (QCheck.make gen) (fun o ->
      Result.fold ~ok:(equal o) ~error:(fun _ -> false) (unmarshal (marshal o)))

let tests =
  [
    (* (a) deep reconcile-state round-trip. *)
    prop_roundtrip "reconcile_state roundtrip" g_s s_equal
      Vreplica_set_pack.marshal_state Vreplica_set_pack.unmarshal_state;
    (* (b) vrs + pod views through their Dynamic_object marshal/unmarshal. *)
    prop_roundtrip "pod view roundtrip" g_pod Pod.equal Pod.marshal Pod.unmarshal;
    prop_roundtrip "vrs view roundtrip" g_vrs Vreplica_set.equal
      Vreplica_set.marshal Vreplica_set.unmarshal;
  ]

(* -- Confirm-by-mutation (spec §6, property-side) --------------------------- *)

(* A round-trip returns Ok-and-equal? *)
let roundtrips (s : Vreplica_set_reconciler.s) (v : Value.t) : bool =
  Result.fold ~ok:(s_equal s) ~error:(fun _ -> false)
    (Vreplica_set_pack.unmarshal_state v)

(* Whole-object equality on the marshalled Value, so we can hand-corrupt a key
   and confirm the codec/equality actually discriminate it. *)
let sample_pod : Pod.t =
  let metadata : Object_meta.t =
    {
      (Object_meta.default ()) with
      name = Some "vreplicaset-x-abc";
      namespace = Some "ns";
      uid = Some (Common.Uid.of_int 7);
      resource_version = Some (Common.Resource_version.of_int 3);
    }
  in
  Pod.make ~metadata ~spec:(Some (Pod_spec.default ())) ~status:(Some ())

let sample_state : Vreplica_set_reconciler.s =
  {
    Vreplica_set_reconciler.reconcile_step =
      Vreplica_set_reconciler.After_create_pod 5;
    filtered_pods = Some [ sample_pod ];
  }

(* Sanity: the honest marshalled value DOES round-trip (baseline). *)
let mutation_baseline () =
  let v = Vreplica_set_pack.marshal_state sample_state in
  Alcotest.(check bool) "honest marshalled state round-trips" true
    (roundtrips sample_state v)

(* Mutant 1 — corrupt the step tag: encode After_create_pod 5 as "init".
   unmarshal succeeds but yields Init, so s_equal false => property fails. *)
let mutation_step_tag () =
  let mutant =
    Value.of_json (`Assoc [ ("step", `Assoc [ ("step", `String "init") ]) ])
  in
  Alcotest.(check bool) "mutated step tag breaks the round-trip" false
    (roundtrips sample_state mutant)

(* Mutant 2 — drop the "diff" key from an After_create_pod step: step_of_json's
   diff read then fails, unmarshal errors => property fails. *)
let mutation_drop_diff () =
  let mutant =
    Value.of_json
      (`Assoc [ ("step", `Assoc [ ("step", `String "afterCreatePod") ]) ])
  in
  Alcotest.(check bool) "dropping the diff key breaks the round-trip" false
    (roundtrips sample_state mutant)

(* Mutant 3 — drop the filteredPods key: unmarshal yields filtered_pods=None,
   which is not equal to Some [pod] => property fails (guards the P3 trap: the
   pod-list leg genuinely matters to equality). *)
let mutation_drop_pods () =
  let mutant =
    Value.of_json
      (`Assoc
         [ ("step", `Assoc [ ("step", `String "afterCreatePod"); ("diff", `Int 5) ]) ])
  in
  Alcotest.(check bool) "dropping filteredPods breaks the round-trip" false
    (roundtrips sample_state mutant)

let mutation_tests =
  [
    Alcotest.test_case "baseline round-trips" `Quick mutation_baseline;
    Alcotest.test_case "mutant: step tag" `Quick mutation_step_tag;
    Alcotest.test_case "mutant: missing diff" `Quick mutation_drop_diff;
    Alcotest.test_case "mutant: missing filteredPods" `Quick mutation_drop_pods;
  ]

let () =
  Alcotest.run "p4_roundtrip"
    [
      ("props", List.map (fun t -> QCheck_alcotest.to_alcotest t) tests);
      ("mutation", mutation_tests);
    ]

(* Transient library-codec mutation performed during build (spec §6, restored;
   git tree left clean):
     vreplica_set_reconciler.ml step_to_json — the After_create_pod arm's
       ("diff", Json.int_ d) was changed to ("diff2", Json.int_ d).
     Rebuilt and ran this executable: the QCheck "reconcile_state roundtrip"
       property went RED (and the After_create_pod-based baseline mutation case
       too) because step_of_json still reads "diff", so unmarshal errored on
       every After_create_pod sample.
     Reverted the edit; property back to green; `git diff lib` empty. *)

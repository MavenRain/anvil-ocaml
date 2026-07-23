(* Anvil source: kubernetes_api_objects/spec/resource.rs
   ([StoredState = Map<ObjectRef, DynamicObjectView>]) and its uses as the
   api-server etcd store and the controller's reconcile maps
   (kubernetes_cluster/spec/controller/types.rs).

   Anvil keys these maps by [ObjectRef { kind, name, namespace }] and relies on
   [Map]'s structural key equality/lookup and on a deterministic domain
   enumeration (the successor-generation step iterates the map's keys). OCaml's
   [Map.Make] gives both: it needs a TOTAL order on the key, so we lift one from
   [ObjectRef]'s three fields. [Kind] is not [int]-comparable, so it is ordered
   through its stable {!Common.show_kind} tag; [namespace] and [name] are ordered
   by [String.compare]. The order is (kind, namespace, name); it exists only to
   satisfy [Map] and to make key enumeration deterministic, never as domain
   arithmetic. Total by construction: every comparison bottoms out in
   {!String.compare}. *)

include Map.Make (struct
  type t = Common.object_ref

  let compare (a : Common.object_ref) (b : Common.object_ref) : int =
    let by_kind = String.compare (Common.show_kind a.kind) (Common.show_kind b.kind) in
    if by_kind <> 0 then by_kind
    else
      let by_namespace = String.compare a.namespace b.namespace in
      if by_namespace <> 0 then by_namespace else String.compare a.name b.name
end)

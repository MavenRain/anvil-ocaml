(* Anvil source: Set<StringView> from vstd. Backs
   [ObjectMetaView::finalizers_as_set] (spec/object_meta.rs). *)
include Set.Make (String)

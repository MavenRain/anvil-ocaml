(* Anvil source: Map<StringView, StringView> from vstd. The canonical
   unordered string-keyed map used for ObjectMeta labels/annotations and
   ConfigMap data. Its ordered [bindings] give deterministic, sorted-key JSON
   so marshal/unmarshal round-trips are stable. *)
include Map.Make (String)

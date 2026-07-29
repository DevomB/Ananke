(** Compile-time registry of packed domains for CLI dispatch.

    Domains are first-class modules fixed at link time — not Dynlink plugins.

    Use [Ananke_runtime.Domain.S] (not bare [Domain.S]) so [Base.Domain] cannot
    shadow the packing after [open Base] in implementations. *)

type packed = (module Ananke_runtime.Domain.S)

(** Built-in example domains, in registration order. *)
val all : packed list

(** Lowercase domain names from [all]. *)
val names : string list

(** Comma-separated [names] for help text. *)
val names_doc : string

(** Case-insensitive lookup by [Domain.S.name]. *)
val find : string -> packed option

val find_exn : string -> packed

(** Apply [f] to the packed domain named [name], or fail with a clear error. *)
val with_domain : string -> f:(packed -> 'a) -> 'a

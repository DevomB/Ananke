(** Domain registry and command dispatch for the Ananke CLI. *)

val cmd : unit Cmdliner.Cmd.t
val run : string -> string -> int option -> string option -> unit
val replay : string -> unit
val diff : string -> string -> unit
val verify : string -> unit
val trace_cmd : string -> unit
val inspect : string -> unit
val snapshot : string -> int -> string -> unit
val report : string -> string -> unit
val benchmark : int -> string -> unit
val init_domain : string -> string -> unit
val doctor : unit -> unit

(** Read and write Chronicle artifacts as sexp files. *)

val read_sexp : string -> (Sexp.t, Chronicle_error.t) Result.t
val write_sexp : string -> Sexp.t -> (unit, Chronicle_error.t) Result.t
val read_trace : string -> (Trace.t, Chronicle_error.t) Result.t
val write_trace : string -> Trace.t -> (unit, Chronicle_error.t) Result.t
val read_snapshot : string -> (Snapshot.t, Chronicle_error.t) Result.t
val write_snapshot : string -> Snapshot.t -> (unit, Chronicle_error.t) Result.t

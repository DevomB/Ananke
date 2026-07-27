(** Read and write Ananke artifacts as sexp files. *)

val read_sexp : string -> (Sexp.t, Ananke_error.t) Result.t
val write_sexp : string -> Sexp.t -> (unit, Ananke_error.t) Result.t
val read_trace : string -> (Trace.t, Ananke_error.t) Result.t
val write_trace : string -> Trace.t -> (unit, Ananke_error.t) Result.t
val read_snapshot : string -> (Snapshot.t, Ananke_error.t) Result.t
val write_snapshot : string -> Snapshot.t -> (unit, Ananke_error.t) Result.t

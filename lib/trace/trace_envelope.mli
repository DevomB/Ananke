open Base

(** Versioned on-disk wrapper around [Trace.t]. *)

type t =
  { version : Trace_version.t
  ; trace : Trace.t
  }
[@@deriving sexp, compare, equal]

type compatibility =
  | Compatible
  | Needs_migration of
      { from : Trace_version.t
      ; toward : Trace_version.t
      }
  | Incompatible of
      { found : Trace_version.t
      ; reason : string
      }
[@@deriving sexp, compare, equal]

val wrap : Trace.t -> t
val check : Trace_version.t -> compatibility

(** Apply one migration step. Returns the next version and updated payload. *)
val migrate_step
  :  Trace_version.t
  -> Trace.t
  -> (Trace_version.t * Trace.t, Ananke_error.t) Result.t

(** Migrate a payload from [from] up to [Trace_version.current]. *)
val migrate : from:Trace_version.t -> Trace.t -> (Trace.t, Ananke_error.t) Result.t

(** Parse wire sexp (envelope or legacy bare trace), check, migrate to current. *)
val of_wire_sexp : Sexp.t -> (Trace.t, Ananke_error.t) Result.t

(** Wrap at current version for writing. *)
val to_wire_sexp : Trace.t -> Sexp.t

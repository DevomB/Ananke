(** A command submitted to the runtime at a logical time. *)

type t =
  { id : Command_id.t
  ; at : Logical_time.t
  ; payload : Sexp.t
  }
[@@deriving compare, equal, sexp]

val create : Command_id.t -> Logical_time.t -> Sexp.t -> t

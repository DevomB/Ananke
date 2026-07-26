open Base

type t =
  { id : Command_id.t
  ; at : Logical_time.t
  ; payload : Sexp.t
  }
[@@deriving compare, equal, sexp]

let create id at payload = { id; at; payload }

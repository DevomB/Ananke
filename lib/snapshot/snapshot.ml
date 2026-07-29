open Base

type t =
  { version : Snapshot_version.t
  ; at : Logical_time.t
  ; at_index : Event_index.t
  ; state : Sexp.t
  ; rng : Sexp.t
  ; digest : string
  }
[@@deriving compare, equal, sexp]

let digest_of_capture ~state ~rng =
  Sexp.List [ state; rng ]
  |> Sexp.to_string
  |> Stdlib.Digest.string
  |> Stdlib.Digest.to_hex
;;

let create version at at_index ~state ~rng =
  { version; at; at_index; state; rng; digest = digest_of_capture ~state ~rng }
;;

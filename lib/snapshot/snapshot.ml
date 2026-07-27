open Base

type t =
  { version : Snapshot_version.t
  ; at : Logical_time.t
  ; at_index : Event_index.t
  ; state : Sexp.t
  ; digest : string
  }
[@@deriving compare, equal, sexp]

let digest_of_state state =
  state |> Sexp.to_string |> Base.Md5.Digest.string |> Base.Md5.to_hex
;;

let create version at at_index state =
  { version; at; at_index; state; digest = digest_of_state state }
;;

(** Schema version for on-disk trace envelopes. *)

type t = int [@@deriving compare, equal, sexp]

(** Current wire format version. *)
val current : t

(** Oldest version this build can migrate from (0 = pre-envelope bare traces). *)
val min_supported : t

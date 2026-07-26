(** Indexed view over a trace for fast lookup. *)

type t

val of_events : Event.t list -> t
val length : t -> int
val get : t -> Event_index.t -> Event.t option
val events : t -> Event.t list

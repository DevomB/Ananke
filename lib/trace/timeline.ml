open Base

type t = { events : Event.t array }

let of_events events = { events = Array.of_list events }
let length t = Array.length t.events

let get t (index : Event_index.t) =
  let i = Event_index.to_int index in
  if i < 0 || i >= Array.length t.events then None else Some t.events.(i)
;;

let events t = Array.to_list t.events

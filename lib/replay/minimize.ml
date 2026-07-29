(* Alias before [open Base] — Base.Domain (OCaml 5) would otherwise shadow. *)
module Domain_ = Domain
open Base

type 'a t =
  { original : 'a list
  ; minimized : 'a list
  ; attempts : int
  }
[@@deriving sexp, compare, equal]

let length_reduced t = List.length t.minimized < List.length t.original

(** Drop elements while [fails] still holds. Prefer half-cuts, then single drops
    — classic Quickcheck list shrinking over ordered sequences. *)
let shrink ~fails original =
  let attempts = ref 0 in
  let still_fails candidate =
    Int.incr attempts;
    fails candidate
  in
  if not (still_fails original)
  then { original; minimized = original; attempts = !attempts }
  else (
    let rec shrink_list xs =
      match xs with
      | [] | [ _ ] -> xs
      | _ ->
        let n = List.length xs in
        let mid = n / 2 in
        let left = List.take xs mid in
        let right = List.drop xs mid in
        if still_fails left
        then shrink_list left
        else if still_fails right
        then shrink_list right
        else (
          let rec remove_one i =
            if i >= List.length xs
            then xs
            else (
              let candidate = List.filteri xs ~f:(fun j _ -> not (Int.equal i j)) in
              if still_fails candidate then shrink_list candidate else remove_one (i + 1))
          in
          remove_one 0)
    in
    (* Bind minimized first — record field evaluation order is unspecified, so
       reading [!attempts] inline with [shrink_list] can observe a stale count. *)
    let minimized = shrink_list original in
    { original; minimized; attempts = !attempts })
;;

module Make (D : Domain_.S) = struct
  module R = Runtime.Make (D)
  module Rep = Replay.Make (D)

  let run_fails config commands =
    match R.create config |> fun runtime -> R.run runtime commands with
    | Error _ -> true
    | Ok _ -> false
  ;;

  let minimize config ?fails commands =
    let fails =
      match fails with
      | Some fails -> fails
      | None ->
        (match R.create config |> fun runtime -> R.run runtime commands with
         | Ok _ -> Fn.const false
         | Error expected ->
           fun candidate ->
             (match R.create config |> fun runtime -> R.run runtime candidate with
              | Ok _ -> false
              | Error actual -> Ananke_error.equal expected actual))
    in
    shrink ~fails commands
  ;;

  let minimize_command_sexps config ?fails sexps =
    match Rep.commands_of_sexps sexps with
    | Error _ as err -> err
    | Ok commands -> Ok (minimize config ?fails commands)
  ;;
end

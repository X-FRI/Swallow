(****************************************************************************)
(* Swallow                                                                    *)
(* Copyright (C) 2022 Muqiu Han                                             *)
(*                                                                          *)
(* This program is free software: you can redistribute it and/or modify     *)
(* it under the terms of the GNU Affero General Public License as published *)
(* by the Free Software Foundation, either version 3 of the License, or     *)
(* (at your option) any later version.                                      *)
(*                                                                          *)
(* This program is distributed in the hope that it will be useful,          *)
(* but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(* GNU Affero General Public License for more details.                      *)
(*                                                                          *)
(* You should have received a copy of the GNU Affero General Public License *)
(* along with this program.  If not, see <https://www.gnu.org/licenses/>.   *)
(****************************************************************************)

open Swallow_utils
open Swallow_repl
open Swallow_stdlib

let get_input_channel () =
    try open_in Sys.argv.(1) with Invalid_argument _ -> stdin

let () =
    let input_channel = get_input_channel () in
    let stream =
        if input_channel = stdin then (
          print_endline
            "Swallow v0.1.7 (main, 2023-01-03 10:45 AM) [OCaml 5.0.0]\n";
          Stream_wrapper.make_filestream input_channel
        ) else
          Stream_wrapper.make_filestream input_channel ~file_name:Sys.argv.(1)
    in
        try Repl.repl stream Stdlib.stdlib
        with e ->
          if input_channel <> stdin then
            close_in input_channel
          else
            print_endline "Goodbye!";
          raise e

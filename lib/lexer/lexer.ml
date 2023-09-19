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
open Swallow_object
open Swallow_error
open Swallow_utils.Stream_wrapper
open Swallow_vars

let read_char stream =
    match stream.chrs with
    | [] ->
        let ch = Stream.next stream.stm in
            if ch = '\n' then (
              stream.line_num <- stream.line_num + 1;
              stream.column_number <- 0;
              ch
            ) else (
              stream.column_number <- stream.column_number + 1;
              ch
            )
    | ch :: rest ->
        stream.chrs <- rest;
        ch

let unread_char stream ch = stream.chrs <- ch :: stream.chrs

let rec eat_whitespace stream =
    let ch = read_char stream in
        if Char.is_whitespace ch then
          eat_whitespace stream
        else
          unread_char stream ch

let rec eat_comment stream =
    if read_char stream = '\n' then
      ()
    else
      eat_comment stream

let read_integer stream acc =
    let rec loop acc =
        let num_char = read_char stream in
            if Char.is_digit num_char then
              num_char |> Char.escaped |> ( ^ ) acc |> loop
            else
              let _ = unread_char stream num_char in
                  Object.Integer (Int64.of_string acc)
    in
        loop acc

let is_symbol_start_char = function
    | '*' | '/' | '>' | '<' | '=' | '?' | '!' | '-' | '+' -> true
    | ch -> Char.is_alpha ch

let rec read_symbol stream =
    let is_delimiter = function
        | '(' | ')' | '{' | '}' | ';' -> true
        | ch -> Char.is_whitespace ch
    in
    let next_char = read_char stream in
        if is_delimiter next_char then
          let _ = unread_char stream next_char in
              ""
        else
          Object.string_of_char next_char ^ read_symbol stream

let read_boolean stream =
    match read_char stream with
    | 't' -> Object.Boolean true
    | 'f' -> Object.Boolean false
    | x ->
        raise
          (Errors.Syntax_error_exn (Invalid_boolean_literal (Char.escaped x)))

let read_string stream =
    let rec loop acc =
        let ch = read_char stream in
            if Char.equal ch '"' then
              Object.String acc
            else
              ch |> Char.escaped |> ( ^ ) acc |> loop
    in
        loop ""

(** Read in a whole number *)
let rec read_sexpr stream =
    eat_whitespace stream;
    let ch = read_char stream in
        if ch = ';' then (
          eat_comment stream;
          read_sexpr stream
        ) else if is_symbol_start_char ch then
          Object.Symbol (Object.string_of_char ch ^ read_symbol stream)
        else if Char.is_digit ch || Char.equal ch '~' then
          (if Char.equal '~' ch then
             '-'
           else
             ch)
          |> Char.escaped
          |> read_integer stream
        else if Char.equal ch '(' then
          read_list stream
        else if Char.is_boolean ch then
          read_boolean stream
        else if Char.equal ch '\'' then
          Quote (read_sexpr stream)
        else if Char.equal ch '\"' then
          read_string stream
        else
          raise
            (Errors.Syntax_error_exn (Unexcepted_character (Char.escaped ch)))

and read_list stream =
    (* Better REPL *)
    (let ch = read_char stream in
         if stream.stdin && Char.equal ch '\n' then (
           print_string
             (String.make (String.length Repl.prompt_tip - 1) ' ' ^ "| ");
           Out_channel.flush stdout
         ) else
           unread_char stream ch);
    eat_whitespace stream;
    let ch = read_char stream in
        if ch = ')' then
          Nil
        else (
          unread_char stream ch;
          let car = read_sexpr stream in
          let cdr = read_list stream in
              Pair (car, cdr)
        )

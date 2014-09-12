(*********************************************************************************)
(*                Ojs-filetree                                                   *)
(*                                                                               *)
(*    Copyright (C) 2014 INRIA. All rights reserved.                             *)
(*                                                                               *)
(*    This program is free software; you can redistribute it and/or modify       *)
(*    it under the terms of the GNU General Public License as                    *)
(*    published by the Free Software Foundation, version 3 of the License.       *)
(*                                                                               *)
(*    This program is distributed in the hope that it will be useful,            *)
(*    but WITHOUT ANY WARRANTY; without even the implied warranty of             *)
(*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the               *)
(*    GNU Library General Public License for more details.                       *)
(*                                                                               *)
(*    You should have received a copy of the GNU General Public                  *)
(*    License along with this program; if not, write to the Free Software        *)
(*    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA                   *)
(*    02111-1307  USA                                                            *)
(*                                                                               *)
(*    As a special exception, you have permission to link this program           *)
(*    with the OCaml compiler and distribute executables, as long as you         *)
(*    follow the requirements of the GNU GPL in regard to all of the             *)
(*    software in the executable aside from the OCaml compiler.                  *)
(*                                                                               *)
(*    Contact: Maxence.Guesdon@inria.fr                                          *)
(*                                                                               *)
(*********************************************************************************)

(** *)

let (>>=) = Lwt.bind
let rec wait_forever () = Lwt_unix.sleep 1000.0 >>= wait_forever

module J = Yojson.Safe

let send_msg push id msg =
  let msg = `Ojsft_msg (id, msg) in
  let json = J.to_string (Ojsft_types.server_msg_to_yojson msg) in
  let frame = Websocket.Frame.of_string json in
  Lwt.return (push (Some frame))

let handle_messages root stream push =
 let f frame =
    let s = Websocket.Frame.content frame in
    try
      let json = J.from_string s in
      match Ojsft_types.client_msg_of_yojson json with
        `Error s -> raise (Yojson.Json_error s)
      | `Ok (`Ojsft_msg (id, t)) ->
          match t with
            `Get_tree ->
              let files = Ojsft_files.file_trees_of_dir
                (fun _ -> true) root
              in
              send_msg push id (`Tree files)
          | _ -> raise (Yojson.Json_error "Unhandled message")
    with Yojson.Json_error s ->
        Lwt.return (prerr_endline s)
  in
  Lwt.catch
    (fun _ -> Lwt_stream.iter_s f stream)
    (fun _ -> Lwt.return_unit)


let handle_con root uri (stream, push) = handle_messages root stream push
let server root sockaddr = Websocket.establish_server sockaddr (handle_con root)

let run_server root host port =
  Lwt_io_ext.sockaddr_of_dns host (string_of_int port) >>= fun sa ->
    Lwt.return (server root sa) >>= fun _ -> wait_forever ()

let _ = Lwt_unix.run (run_server "." "0.0.0.0" 8080)
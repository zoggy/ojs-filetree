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

open Ojsft_types

module SMap = Map.Make(String)

let log s = Firebug.console##log (Js.string s);;

type tree_config = {
    root_id : string ;
    ws : WebSockets.webSocket Js.t ;
    on_select : string -> unit ;
  }

let nodes = ref (SMap.empty : string SMap.t)

let file_trees = ref (SMap.empty : tree_config SMap.t)


let clear_children node =
  let children = node##childNodes in
  for i = 0 to children##length - 1 do
    Js.Opt.iter (node##firstChild) (fun n -> Dom.removeChild node n)
  done

let node_by_id id =
  let node = Dom_html.document##getElementById (Js.string id) in
  Js.Opt.case node (fun _ -> failwith ("No node with id = "^id)) (fun x -> x)

let gen_id = let n = ref 0 in fun () -> incr n; Printf.sprintf "ojsftid%d" !n

let build_from_tree ~id tree_files =
  let doc = Dom_html.document in
  let node = node_by_id id in
  clear_children node ;
  let rec insert t = function
    `Dir (s, l) ->
      let label = Filename.basename s in
      let div = doc##createElement (Js.string "div") in
      let div_id = gen_id () in
      div##setAttribute (Js.string "id", Js.string div_id);
      div##setAttribute (Js.string "class", Js.string "ojsft-dir");
      let div_subs = doc##createElement (Js.string "div") in
      div_subs##setAttribute (Js.string "id", Js.string (div_id^"subs"));
      div_subs##setAttribute (Js.string "class", Js.string "ojsft-dir-subs");
      let text = doc##createTextNode (Js.string label) in
      Dom.appendChild t div ;
      Dom.appendChild div text ;
      Dom.appendChild div div_subs ;
      List.iter (insert div_subs) l
  | `File s ->
      let label = Filename.basename s in
      let div = doc##createElement (Js.string "div") in
      let div_id = gen_id () in
      div##setAttribute (Js.string "id", Js.string div_id);
      div##setAttribute (Js.string "class", Js.string "ojsft-file");
      let text = doc##createTextNode (Js.string label) in
      Dom.appendChild t div ;
      Dom.appendChild div text
  in
  List.iter (insert node) tree_files

let send_msg ws id msg =
  let msg = Yojson.to_string
    (Ojsft_types.client_msg_to_yojson (`Ojsft_msg (id, msg)))
  in
  ws##send (Js.string msg)

let ws_onmessage ws id _ event =
   try
    log "message received on ws";
    let json = Js.to_string event##data in
    let msg = Ojsft_types.server_msg_of_yojson (Yojson.Safe.from_string json) in
    (
     match msg with
       `Error s -> failwith (s^"\n"^json);
     | `Ok (`Ojsft_msg (_, t)) ->
         match t with
           `Tree l -> build_from_tree id l
         | _ -> failwith "Unhandled message received from server"
    );
    Js._false
  with
   e ->
      log (Printexc.to_string e);
      Js._false


let setup_ws id url =
  try
    log ("connecting with websocket to "^url);
    let ws = jsnew WebSockets.webSocket(Js.string url) in
    ws##onopen <- Dom.handler (fun _ -> send_msg ws id (`Get_tree); Js._false);
    ws##onclose <- Dom.handler (fun _ -> log "WS now CLOSED"; Js._false);
    ws##onmessage <- Dom.full_handler (ws_onmessage ws id) ;
    Some ws
  with e ->
    log (Printexc.to_string e);
    None
;;


let start ?(on_select=fun _ -> ()) ~id url =
  match setup_ws id url with
    None -> failwith ("Could not connect to "^url)
  | Some ws ->
      let cfg = { root_id = id ; ws ; on_select } in
      file_trees := SMap.add id cfg !file_trees



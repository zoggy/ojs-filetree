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

(*c==v=[String.split_string]=1.2====*)
let split_string ?(keep_empty=false) s chars =
  let len = String.length s in
  let rec iter acc pos =
    if pos >= len then
      match acc with
        "" -> if keep_empty then [""] else []
      | _ -> [acc]
    else
      if List.mem s.[pos] chars then
        match acc with
          "" ->
            if keep_empty then
              "" :: iter "" (pos + 1)
            else
              iter "" (pos + 1)
        | _ -> acc :: (iter "" (pos + 1))
      else
        iter (Printf.sprintf "%s%c" acc s.[pos]) (pos + 1)
  in
  iter "" 0
(*/c==v=[String.split_string]=1.2====*)


type id = string

type tree_info = {
    root_id : id ;
    ws : WebSockets.webSocket Js.t ;
    show_files : bool ;
    on_select : string -> unit ;
    on_deselect : string -> unit ;
    mutable selected : (id * string) option ;
  }

type node_type = [`File | `Dir of id ] (* `Dir of (div id) *)
type tree_node =
  { tn_content : string ;
    tn_span_id : id ;
    tn_type : node_type ;
  }
let tree_nodes = ref (SMap.empty : tree_node SMap.t)
let trees = ref (SMap.empty : tree_info SMap.t)

let (+=) map (key, v) = map := SMap.add key v !map
let (-=) map key = map := SMap.remove key !map

let clear_children node =
  let children = node##childNodes in
  for i = 0 to children##length - 1 do
    Js.Opt.iter (node##firstChild) (fun n -> Dom.removeChild node n)
  done

let node_by_id id =
  let node = Dom_html.document##getElementById (Js.string id) in
  Js.Opt.case node (fun _ -> failwith ("No node with id = "^id)) (fun x -> x)

let gen_id = let n = ref 0 in fun () -> incr n; Printf.sprintf "ojsftid%d" !n

let set_onclick node f =
  ignore(Dom_html.addEventListener node
   Dom_html.Event.click
     (Dom.handler (fun e -> f e; Js.bool true))
     (Js.bool true))

let get_classes node =
  let s =Js.to_string node##className in
  split_string s [' ']

let unset_class span_id cl =
  try
    let node = node_by_id span_id in
    node##classList##remove(Js.string cl)
  with
    Failure msg -> log msg

let set_class span_id cl =
  try
    let node = node_by_id span_id in
    node##classList##add(Js.string cl)
  with
    Failure msg -> log msg

let set_unselected ti div_id label =
  (
   try
     let span_id = (SMap.find div_id !tree_nodes).tn_span_id in
     unset_class span_id "selected" ;
   with Not_found -> ()
  );
  ti.selected <- None ;
  ti.on_deselect label

let set_selected ti div_id label =
  (
   try
     let span_id = (SMap.find div_id !tree_nodes).tn_span_id in
     set_class span_id "selected" ;
   with Not_found -> ()
  );
  ti.selected <- Some (div_id, label) ;
  ti.on_select label

let set_tree_onclick id node div_id label =
  let f _ =
    try
      let ti = SMap.find id !trees in
      match ti.selected with
      | None ->  set_selected ti div_id label
      | Some (old_id,l) when id <> div_id ->
          set_unselected ti old_id l ;
          set_selected ti div_id label
      | _ -> ()
    with
      Not_found -> ()
  in
  set_onclick node f

let build_from_tree ~id tree_files =
  let doc = Dom_html.document in
  let node = node_by_id id in
  clear_children node ;
  let cfg =
    try SMap.find id !trees
    with Not_found -> failwith ("No config for file_tree "^id)
  in
  let rec insert t = function
    `Dir (s, l) ->
      let label = Filename.basename s in
      let div = doc##createElement (Js.string "div") in
      let div_id = gen_id () in
      div##setAttribute (Js.string "id", Js.string div_id);
      div##setAttribute (Js.string "class", Js.string "ojsft-dir");

      let span_id = div_id^"text" in
      let span = doc##createElement (Js.string "span") in
      span##setAttribute (Js.string "id", Js.string span_id);
      set_tree_onclick id span div_id label ;

      let subs_id = div_id^"subs" in
      let div_subs = doc##createElement (Js.string "div") in
      div_subs##setAttribute (Js.string "id", Js.string subs_id);
      div_subs##setAttribute (Js.string "class", Js.string "ojsft-dir-subs");

      let text = doc##createTextNode (Js.string label) in

      let tn = {
          tn_span_id = span_id ;
          tn_content = label ;
          tn_type = `Dir subs_id ;
          }
      in
      tree_nodes += (div_id, tn) ;

      Dom.appendChild t div ;
      Dom.appendChild div span ;
      Dom.appendChild span text ;
      Dom.appendChild div div_subs ;
      List.iter (insert div_subs) l

  | `File s ->
      if cfg.show_files then
        begin
          let label = Filename.basename s in
          let div = doc##createElement (Js.string "div") in
          let div_id = gen_id () in
          div##setAttribute (Js.string "id", Js.string div_id);
          div##setAttribute (Js.string "class", Js.string "ojsft-file");

          let span_id = div_id^"text" in
          let span = doc##createElement (Js.string span_id) in
          span##setAttribute (Js.string "id", Js.string (div_id^"text"));
          set_tree_onclick id span div_id label;

          let tn = {
              tn_span_id = span_id ;
              tn_content = label ;
              tn_type = `File ;
            }
          in
          tree_nodes += (div_id, tn) ;

          let text = doc##createTextNode (Js.string label) in
          Dom.appendChild t div ;
          Dom.appendChild div span ;
          Dom.appendChild span text
        end
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
       `Error s -> failwith (s^"\n"^json)
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


let start
  ?(show_files=true)
  ?(on_select=fun _ -> ())
  ?(on_deselect=fun _ -> ()) ~id url =
  match setup_ws id url with
    None -> failwith ("Could not connect to "^url)
  | Some ws ->
        let cfg = {
            root_id = id ; ws ;
            on_select ; on_deselect ; show_files ;
            selected = None ;
          }
        in
        trees += (id, cfg)



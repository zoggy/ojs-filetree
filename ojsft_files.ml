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

module Find = Ojsft_find

let is_dir file = (Unix.stat file).Unix.st_kind = Unix.S_DIR

let rec file_trees_of_dir pred_ign dir =
  let len = String.length dir in
  let entries =
    Find.find_list
      Find.Stderr
      [dir]
      [ Find.Maxdepth 1 ;
        Find.Predicate pred_ign ;
      ]
  in
  let pred s =
    s <> dir
      && (Filename.basename s <> Filename.current_dir_name)
      && (Filename.basename s <> Filename.parent_dir_name)
  in
  let entries = List.filter pred entries in
  let entries = List.sort String.compare entries in
  let (dirs, files) = List.partition is_dir entries in
  let basename s =
    let len_s = String.length s in
    if len_s > len then
      String.sub s len (len_s - len)
    else
      failwith ("Invalid file entry: "^s)
  in

  let dir s = `Dir (basename s, file_trees_of_dir pred_ign s) in
  let file s = `File (basename s) in
  (List.map dir dirs) @ (List.map file files)



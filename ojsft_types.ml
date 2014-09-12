(** *)

type file_tree = [
 | `Dir of string * file_tree list
 | `File of string
 ] [@@deriving Yojson]

type server_msg = [
  | `Tree of file_tree
  ] [@@deriving Yojson]
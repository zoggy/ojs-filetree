
let on_deselect name =
  Ojsft_js.log (Printf.sprintf "Node %S deselected" name)

let on_select name =
  Ojsft_js.log (Printf.sprintf "Node %S selected" name)

let () = ignore(Ojsft_js.start ~on_select ~on_deselect ~id: "ft" "ws://localhost:8080")
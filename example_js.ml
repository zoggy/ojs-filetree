
let on_select ~id ~name =
  Ojsft_js.log (Printf.sprintf "Node %s selected, this is file %S" id name)

let () = ignore(Ojsft_js.start ~on_select ~id: "ft" "ws://localhost:8080")
// import gleam/list
// import gleam/result
// import infrastructure.{type DesugaringError}
// import vxml_parser.{type VXML, T, V}

// fn is_blank_line(x) {
//   case x {
//     T(_, _) -> False
//     V(_, tag, _, _) -> tag == "BlankLine"
//   }
// }

// fn create_chunk(vxml: VXML, children: List(VXML)) -> VXML {
//   case vxml {
//     T(blame, _) -> V(blame, "VerticalChunk", [], children)
//     V(blame, _, _, _) -> V(blame, "VerticalChunk", [], children)
//   }
// }

// fn append_chunk_child(rest: List(VXML)) -> #(Bool, List(VXML), List(VXML)) {
//   // returns
//   // bool indicating if a blank line is found
//   // list of chunk children
//   // list of elements rest
//   case rest {
//     [] -> #(False, [], rest)
//     [first, ..rest] -> {
//       case is_blank_line(first) {
//         True -> #(True, [], rest)
//         False -> {
//           let #(end, appended, rest) = append_chunk_child(rest)
//           #(end, list.append([first], appended), rest)
//         }
//       }
//     }
//   }
// }

// fn split(
//   chlidren: List(VXML),
//   output: List(VXML),
// ) -> Result(List(VXML), DesugaringError) {
//   case chlidren {
//     [] -> Ok([])
//     [first, ..rest] -> {
//       let #(end, chunk_children, rest) =
//         append_chunk_child(list.append([first], rest))
//       case end {
//         True -> {
//           case split(rest, output) {
//             Ok(c) -> Ok(list.append([create_chunk(first, chunk_children)], c))
//             Error(e) -> Error(e)
//           }
//         }
//         False -> {
//           case split(rest, output) {
//             Ok(c) -> Ok(list.append(chunk_children, c))
//             Error(e) -> Error(e)
//           }
//         }
//       }
//     }
//   }
// }

// pub fn split_vertical_chunks_transform(
//   vxml: VXML,
//   _: List(VXML),
//   _: Nil,
// ) -> Result(VXML, DesugaringError) {
//   case vxml {
//     T(_, _) -> Ok(vxml)
//     V(b, t, a, children) -> {
//       use updated_children <- result.try(split(children, []))
//       Ok(V(b, t, a, updated_children))
//     }
//   }
// }
import gleam/list
import gleam/option.{type Option, None, Some}
import infrastructure.{type DesugaringError}
import vxml_parser.{type Blame, type VXML, T, V}

fn is_blank_line(vxml: VXML) -> #(Bool, Blame) {
  case vxml {
    T(blame, _) -> #(False, blame)
    V(blame, tag, _, _) ->
      case tag == "BlankLine" {
        True -> #(True, blame)
        False -> #(False, blame)
      }
  }
}

fn eat_blank_lines(vxmls: List(VXML)) -> List(VXML) {
  case vxmls {
    [] -> []
    [first, ..rest] ->
      case is_blank_line(first) {
        #(True, _) -> eat_blank_lines(rest)
        #(False, _) -> vxmls
      }
  }
}

fn prepend_to_second_element_of_optional_pair(
  first: a,
  list: Option(#(b, List(a))),
) -> List(a) {
  case list {
    None -> [first]
    Some(#(_, list)) -> [first, ..list]
  }
}

fn eat_and_record_non_blank_lines(
  vxmls: List(VXML),
) -> #(Option(#(Blame, List(VXML))), List(VXML)) {
  // returns #(None, ..) if vxmls is empty or starts with a blank line,
  // else #(Some(blame, ..), ..) where 'blame' is blame of first line
  case vxmls {
    [] -> #(None, [])
    [first, ..rest] -> {
      case is_blank_line(first) {
        #(True, _) -> #(None, eat_blank_lines(rest))
        #(False, blame) -> {
          let #(prefix, suffix) = eat_and_record_non_blank_lines(rest)
          #(
            Some(#(
              blame,
              prepend_to_second_element_of_optional_pair(first, prefix),
            )),
            suffix,
          )
        }
      }
    }
  }
}

fn prepend_if_not_none(m: Option(a), z: List(a)) {
  case m {
    None -> z
    Some(thing) -> [thing, ..z]
  }
}

fn lists_of_non_blank_line_chunks(
  vxmls: List(VXML),
) -> List(#(Blame, List(VXML))) {
  let #(first_chunk, remaining_vxmls_after_first_chunk) =
    eat_and_record_non_blank_lines(vxmls)
  let other_chunks = case remaining_vxmls_after_first_chunk {
    [] -> []
    _ -> lists_of_non_blank_line_chunks(remaining_vxmls_after_first_chunk)
  }
  prepend_if_not_none(first_chunk, other_chunks)
}

pub fn chunk_constructor(blame_and_children: #(Blame, List(VXML))) -> VXML {
  let #(blame, children) = blame_and_children
  V(blame, "VerticalChunk", [], children)
}

pub fn split_vertical_chunks_transform(
  vxml: VXML,
  _: List(VXML),
  _: Nil,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      let new_children =
        lists_of_non_blank_line_chunks(children)
        |> list.map(chunk_constructor)
      Ok(V(blame, tag, attrs, new_children))
    }
  }
}

import gleam/result
import gleam/list
import infrastructure.{type DesugaringError}
import vxml_parser.{type VXML, T, V}

fn is_blank_line(x) {
  case x {
    T(_, _) -> False
    V(_, tag, _, _) -> tag == "BlankLine"
  }
}

fn create_chunk(vxml: VXML, children: List(VXML)) -> VXML {
  case vxml {
    T(blame, _) -> V(blame, "VerticalChunk", [], children)
    V(blame, _, _, _) -> V(blame, "VerticalChunk", [], children)
  }
}

fn append_chunk_child(rest: List(VXML)) -> #(Bool, List(VXML), List(VXML)) {
  // returns
  // bool indicating if a blank line is found
  // list of chunk children
  // list of elements rest
  case rest {
    [] -> #(False, [], rest)
    [first, ..rest] -> {
      case is_blank_line(first) {
        True -> #(True, [], rest)
        False ->{
          let #(end, appended, rest) = append_chunk_child(rest)
           #(end, list.append([first], appended), rest)}
      }
    }
  }
}

fn split(chlidren: List(VXML), output: List(VXML)) -> Result(List(VXML), DesugaringError) {
  case chlidren {
    [] -> Ok([])
    [first, ..rest] -> {
        let #(end, chunk_children, rest) = append_chunk_child(list.append([first], rest))
        case end {
          True ->{
              case split(rest, output) {
                Ok(c) -> Ok(list.append([create_chunk(first, chunk_children)], c))
                Error(e) -> Error(e)
              }
          }
          False -> {
            case split(rest, output) {
              Ok(c) -> Ok(list.append(chunk_children, c))
              Error(e) -> Error(e)
            }
          }
        }
      }
    }
}

pub fn split_vertical_chunks_transform(
  vxml: VXML,
  _: List(VXML),
  _: Nil,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(b, t, a, children) -> {
      use updated_children <- result.try(split(children, []))
      Ok(V(b, t, a, updated_children))
    }
  }
}
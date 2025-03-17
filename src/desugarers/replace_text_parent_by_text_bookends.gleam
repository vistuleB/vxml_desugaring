import gleam/option.{None}
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, Pipe, DesugarerDescription, DesugaringError } as infra
import vxml_parser.{type VXML, T, V}
import gleam/list

fn param_transform(vxml: VXML, extra: Extra) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(blame, tag, _, children) -> {
      let #(del_tag, opening, closing) = extra
      case del_tag == tag {
        True -> {
          let opening = V(blame, opening, [], [])
          let closing = V(blame, closing, [], [])
          Ok(list.flatten([[opening], children, [closing]]))
        }
        False -> Ok([vxml])
      }
      
    }
  }
}

type Extra =
  #(String, String, String)

fn transform_factory(extra: Extra) -> infra.NodeToNodesTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(extra))
}

pub fn replace_text_parent_by_text_bookends(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("replace_text_parent_by_text_bookends", None, "..."),
    desugarer: desugarer_factory(extra),
  )
}

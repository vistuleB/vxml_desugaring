import gleam/option.{None}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V,  BlamedContent}
import gleam/io

fn delimiters_transform(vxml: VXML, extra: Extra) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      let #(del_tag, to) = extra
      case children {
        [T(_, [BlamedContent(b, content)])] -> case del_tag == tag {
          False -> Ok(vxml)
          True -> Ok(T(blame, [BlamedContent(b, to <> content <> to)]))
        }
        _ -> Ok(vxml)
      }
     
    }
  }
}

type Extra =
  #(String, String)

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  delimiters_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

pub fn delimiters(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("delimiters", None, "..."),
    desugarer_factory(extra),
  )
}

import gleam/list
import gleam/option.{None}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe,
  type StatefulNodeToNodeTransform, DesugarerDescription, DesugaringError,
} as infra
import vxml_parser.{type VXML, BlamedAttribute, T, V}

fn define_article_output_path_transform(
  node: VXML,
  extra: Extra,
  index: Int,
) -> Result(#(VXML, Int), DesugaringError) {
  case node {
    T(_, _) -> Ok(#(node, index))
    V(b, t, attributes, c) -> {
      let #(tag, path, extension, key) = extra
      let #(index, new_attribute) = case tag == t {
        True -> {
          #(index + 1, [
            BlamedAttribute(
              b,
              key,
              path <> string.inspect(index) <> "." <> extension,
            ),
          ])
        }
        False -> #(index, [])
      }

      Ok(#(V(b, t, list.flatten([attributes, new_attribute]), c), index))
    }
  }
}

fn transform_factory(extra: Extra) -> StatefulNodeToNodeTransform(Int) {
  fn(vxml, s) { define_article_output_path_transform(vxml, extra, s) }
  // define_article_output_path_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.stateful_node_to_node_desugarer_factory(transform_factory(extra), 1)
}

type Extra =
  #(String, String, String, String)

//        ^         ^       ^       ^
//       Tag     File     file       attribute key
//               Path     extension

pub fn define_article_output_path(extra: Extra) -> Pipe {
  #(DesugarerDescription("", None, "..."), desugarer_factory(extra))
}

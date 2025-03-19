import blamedlines.{type Blame, Blame}
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml_parser.{type VXML, BlamedAttribute, T, V}

fn generate_id(blame: Blame) {
  string.inspect(int.random(9999))
  <> string.inspect(blame.line_no)
  <> string.inspect(int.random(9999))
}

fn transform(node: VXML) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(b, t, attributes, c) -> {
      let id = generate_id(b)

      let has_handles =
        list.filter(attributes, fn(att) {
          string.starts_with(att.key, "handle_")
        })

      let attributes =
        attributes
        |> list.index_map(fn(att, _) {
          case string.starts_with(att.key, "handle_") {
            True -> BlamedAttribute(..att, value: id <> " | " <> att.value)
            False -> att
          }
        })

      let id_attribute = case list.is_empty(has_handles) {
        False -> [BlamedAttribute(b, key: "id", value: id)]
        True -> []
      }

      Ok(V(b, t, list.flatten([attributes, id_attribute]), c))
    }
  }
}

fn transform_factory() -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn handles_generate_ids() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "handles_generate_ids",
      None,
      "unique Id generator for handles",
    ),
    desugarer: desugarer_factory(),
  )
}

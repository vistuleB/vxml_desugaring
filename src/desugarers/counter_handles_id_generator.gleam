import blamedlines.{type Blame, Blame}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, BlamedAttribute, T, V}

fn generate_id(blame: Blame) {
  string.inspect(int.random(9999))
  <> string.inspect(blame.line_no)
  <> string.inspect(int.random(9999))
}

fn generate_id_for_handles_transform(
  node: VXML,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(b, t, attributes, c) -> {
      let id = generate_id(b)

      let has_handles =
        list.filter(attributes, fn(att) {
          string.starts_with(att.key, "handle_")
        })

      let attributes =
        has_handles
        |> list.index_map(fn(att, _) {
          BlamedAttribute(..att, value: id <> " | " <> att.value)
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
  generate_id_for_handles_transform(_)
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn generate_id_for_handles() -> Pipe {
  #(
    DesugarerDescription("Unique Id generator for handles", None, "..."),
    desugarer_factory(),
  )
}

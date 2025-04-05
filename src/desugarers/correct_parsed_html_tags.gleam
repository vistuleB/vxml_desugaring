import gleam/option.{None}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

fn correct_tag(tag: String) {
  tag |> string.drop_start(1) |> string.drop_end(1)
}

fn param_transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      Ok(V(blame, correct_tag(tag), attrs, children))
    }
  }
}

fn transform_factory() -> infra.NodeToNodeTransform {
  param_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn correct_parsed_html_tags() -> Pipe {
  Pipe(
    description: DesugarerDescription("correct_parsed_html_tags", None, "..."),
    desugarer: desugarer_factory(),
  )
}

import gleam/option.{None}
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn correct_tag(tag: String) {
  tag |> string.drop_start(1) |> string.drop_end(1)
}

fn transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      Ok(V(blame, correct_tag(tag), attrs, children))
    }
  }
}

fn transform_factory(_param: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

pub fn correct_parsed_html_tags() -> Pipe {
  Pipe(
    description: DesugarerDescription("correct_parsed_html_tags", None, "..."),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}

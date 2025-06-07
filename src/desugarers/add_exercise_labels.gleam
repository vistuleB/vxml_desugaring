import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, "Exercises", attributes, children) -> {
      let new_attribute = [
        BlamedAttribute(
          blame,
          "labels",
          "vec!"
            <> string.inspect(
            list.index_map(children, fn(_, i) { string.inspect(i) }),
          ),
        ),
      ]
      Ok(V(
        blame,
        "Exercises",
        list.flatten([new_attribute, attributes]),
        children,
      ))
    }
    _ -> Ok(vxml)
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

/// adds labels attribute to Exercises tags with indexed children
pub fn add_exercise_labels() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "add_exercise_labels",
      stringified_param: option.None,
      general_description: "
/// adds labels attribute to Exercises tags with indexed children
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

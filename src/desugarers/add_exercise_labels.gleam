import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn transform(vxml: VXML) -> Result(VXML, DesugaringError) {
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

pub fn add_exercise_labels() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "add_exercise_labels",
      option.None,
      "..."
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}

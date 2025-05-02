import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe } as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn param_transform(vxml: VXML, param: Param) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, old_attributes, children) -> {
      case dict.get(param, tag) {
        Ok(counter_names) -> {
          let #(unassigned_handle_attributes, other_attributes) = list.partition(old_attributes, fn(attr) {
            let assert True = attr.value == string.trim(attr.value)
            attr.key == "handle" &&
            string.split(attr.value, " ") |> list.length == 1 
          })

          let handles_str =
            unassigned_handle_attributes
            |> list.map(fn(attr) { attr.value <> "<<" })
            |> string.join("")

          let new_attributes =
            counter_names
            |> list.index_map(fn(counter_name, index) {
              case index == 0 {
                True -> BlamedAttribute(blame, ".", counter_name <> " " <> handles_str <> "::++" <> counter_name)
                False -> BlamedAttribute(blame, ".", counter_name <> " " <> "::++" <> counter_name)
              }
            })

          Ok(V(blame, tag, list.flatten([other_attributes, new_attributes]), children))
        }
        Error(Nil) -> Ok(vxml)
      }
    }
  }
}

fn extra_to_param(extra: Extra) -> Param {
  extra |> infra.aggregate_on_first
}

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

type Param =
  Dict(String, List(String))

type Extra =
  List(#(String, String))

//        tag     counter_name

pub fn associate_counter_by_prepending_incrementing_attribute(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "associate_counter_by_prepending_incrementing_attribute",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra |> extra_to_param),
  )
}
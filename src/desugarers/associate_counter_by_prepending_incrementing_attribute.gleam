import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, old_attributes, children) -> {
      case dict.get(inner, tag) {
        Ok(counter_names) -> {
          let #(unassigned_handle_attributes, other_attributes) =
            list.partition(old_attributes, fn(attr) {
              let assert True = attr.value == string.trim(attr.value)
              attr.key == "handle"
              && string.split(attr.value, " ") |> list.length == 1
            })

          let handles_str =
            unassigned_handle_attributes
            |> list.map(fn(attr) { attr.value <> "<<" })
            |> string.join("")

          let new_attributes =
            counter_names
            |> list.index_map(fn(counter_name, index) {
              case index == 0 {
                True ->
                  BlamedAttribute(
                    blame,
                    ".",
                    counter_name <> " " <> handles_str <> "::++" <> counter_name,
                  )
                False ->
                  BlamedAttribute(
                    blame,
                    ".",
                    counter_name <> " " <> "::++" <> counter_name,
                  )
              }
            })

          Ok(V(
            blame,
            tag,
            list.flatten([other_attributes, new_attributes]),
            children,
          ))
        }
        Error(Nil) -> Ok(vxml)
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(infra.aggregate_on_first(param))
}

type Param =
  List(#(String, String))
//       ↖      ↖
//       tag    counter_name

type InnerParam =
  Dict(String, List(String))

/// associates counters by prepending incrementing attributes to specified tags
pub fn associate_counter_by_prepending_incrementing_attribute(
  param: Param,
) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "associate_counter_by_prepending_incrementing_attribute",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// associates counters by prepending incrementing attributes to specified tags
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    },
  )
}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/pair
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn build_blamed_attributes(
  blame,
  attributes: List(#(String, String)),
) -> List(BlamedAttribute) {
  attributes
  |> list.map(fn(attr) {
    BlamedAttribute(blame, attr |> pair.first, attr |> pair.second)
  })
}

fn transform(vxml: VXML, inner_param: InnerParam) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, old_attributes, children) -> {
      case dict.get(inner_param, tag) {
        Ok(new_attributes) -> {
          Ok(V(
            blame,
            tag,
            list.flatten([
              old_attributes,
              build_blamed_attributes(blame, new_attributes),
            ]),
            children,
          ))
        }
        Error(Nil) -> Ok(vxml)
      }
    }
  }
}

fn transform_factory(inner_param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner_param)
}

fn desugarer_factory(inner_param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner_param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param |> infra.triples_to_aggregated_dict)
}

type Param =
  List(#(String, String, String))

//        tag     attr   value

type InnerParam =
  Dict(String, List(#(String, String)))

pub fn add_attributes(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "add_attributes",
      option.Some(string.inspect(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner_param) -> desugarer_factory(inner_param)
    }
  )
}
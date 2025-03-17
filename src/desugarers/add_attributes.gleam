import gleam/list
import gleam/dict.{type Dict}
import gleam/option
import gleam/pair
import gleam/string
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, Pipe, DesugarerDescription, DesugaringError } as infra
import vxml_parser.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn build_blamed_attributes(
  blame,
  attributes: List(#(String, String)),
) -> List(BlamedAttribute) {
  attributes
  |> list.map(fn(attr) {
    BlamedAttribute(blame, attr |> pair.first, attr |> pair.second)
  })
}

fn param_transform(
  vxml: VXML,
  param: Param,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, old_attributes, children) -> {
      case dict.get(param, tag) {
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

fn extra_to_param(extra: Extra) -> Param {
  extra |> infra.triples_to_aggregated_dict
}

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

type Param = Dict(String, List(#(String, String)))

type Extra = List(#(String, String, String))
//                  tag     attr    value

pub fn add_attributes(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("add_attributes", option.Some(string.inspect(extra)), "..."),
    desugarer: desugarer_factory(extra |> extra_to_param),
  )
}

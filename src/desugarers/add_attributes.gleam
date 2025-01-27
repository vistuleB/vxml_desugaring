import gleam/list
import gleam/dict.{type Dict}
import gleam/option
import gleam/pair
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription,
} as infra
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

type Param = Dict(String, List(#(String, String)))

fn triple_to_pair_pair(t: #(a, b, c)) -> #(a, #(b, c)) {
  let #(a, b, c) = t
  #(a, #(b, c))
}

fn extra_to_param(extra: Extra) -> Param {
  extra
  |> list.map(triple_to_pair_pair)
  |> infra.aggregate_on_first
}


fn transform_factory(
  param: Param,
) -> NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(
  param: Param,
) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

type Extra = List(#(String, String, String))

pub fn add_attributes(extra: Extra) -> Pipe {
  #(
    DesugarerDescription(
      "add_attributes",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer_factory(extra |> extra_to_param),
  )
}

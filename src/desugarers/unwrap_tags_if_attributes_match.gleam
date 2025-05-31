import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type BlamedAttribute, type VXML, T, V}

fn matches_all_key_value_pairs(
  attrs: List(BlamedAttribute),
  key_value_pairs: List(#(String, String)),
) -> Bool {
  list.all(key_value_pairs, fn(key_value) {
    let #(key, value) = key_value
    list.any(attrs, fn(attr) { attr.key == key && attr.value == value })
  })
}

fn transform(
  node: VXML,
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> Ok([node])
    V(_, tag, attrs, children) -> {
      case list.find(param, fn(pair) { pair |> pair.first == tag }) {
        Error(Nil) -> Ok([node])
        Ok(#(_, attrs_to_match)) -> {
          case matches_all_key_value_pairs(attrs, attrs_to_match) {
            False -> Ok([node])
            True -> Ok(children)
            // bye-bye
          }
        }
      }
    }
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodesTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String, List(#(String, String))))

type InnerParam = Param

pub fn unwrap_tags_if_attributes_match(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "unwrap_tags_if_attributes_match",
      Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}

import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra

import vxml.{type VXML, T, V, type BlamedAttribute, BlamedAttribute}

fn rename(attr: BlamedAttribute, inner: InnerParam) -> BlamedAttribute {
  case infra.use_list_pair_as_dict(inner, attr.key) {
    Ok(key) -> BlamedAttribute(..attr, key: key)
    Error(_) -> attr
  }
}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, _, attrs, _) -> {
      Ok(V(..vxml, attributes: list.map(attrs, rename(_, inner) )))
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
  Ok(param)
}

type Param =
  List(#(String, String))
//       ↖      ↖
//       from   to

type InnerParam = Param

/// renames attribute keys
pub fn rename_attributes(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "rename_attributes",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// renames attribute keys
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

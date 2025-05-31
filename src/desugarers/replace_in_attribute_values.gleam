import gleam/list
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn replacer(mister: BlamedAttribute, param: InnerParam) -> BlamedAttribute {
  BlamedAttribute(
    mister.blame,
    mister.key,
    list.fold(param, mister.value, fn(current, pair) {
      let #(from, to) = pair
      string.replace(current, from, to)
    }),
  )
}

fn transform(vxml: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) ->
      Ok(V(blame, tag, attrs |> list.map(replacer(_, param)), children))
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String, String))

type InnerParam = Param

/// performs exact match find-replace in every
/// attribute value of every node using the
/// 'string.replace' function
pub fn replace_in_attribute_values(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "replace_in_attribute_values",
      Some(ins(param)),
      "
performs exact match find-replace in every
attribute value of every node using the
'string.replace' function
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}

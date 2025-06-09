import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn replacer(mister: BlamedAttribute, inner: InnerParam) -> BlamedAttribute {
  BlamedAttribute(
    mister.blame,
    mister.key,
    list.fold(inner, mister.value, fn(current, pair) {
      let #(from, to) = pair
      string.replace(current, from, to)
    }),
  )
}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) ->
      Ok(V(blame, tag, attrs |> list.map(replacer(_, inner)), children))
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

/// performs exact match find-replace in every
/// attribute value of every node using the
/// 'string.replace' function
pub fn replace_in_attribute_values(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "replace_in_attribute_values",
      stringified_param: option.Some(ins(param)),
      general_description:
      "
/// performs exact match find-replace in every
/// attribute value of every node using the
/// 'string.replace' function
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
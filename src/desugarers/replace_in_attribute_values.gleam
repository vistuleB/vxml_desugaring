import gleam/list
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml_parser.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn replacer(mister: BlamedAttribute, extra: Extra) -> BlamedAttribute {
  BlamedAttribute(
    mister.blame,
    mister.key,
    list.fold(extra, mister.value, fn(current, pair) {
      let #(from, to) = pair
      string.replace(current, from, to)
    }),
  )
}

fn param_transform(vxml: VXML, extra: Extra) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) ->
      Ok(V(blame, tag, attrs |> list.map(replacer(_, extra)), children))
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

type Extra =
  List(#(String, String))

/// performs exact match find-replace in every
/// attribute value of every node using the
/// 'string.replace' function
pub fn replace_in_attribute_values(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "replace_in_attribute_values",
      Some(ins(extra)),
      "performs exact match find-replace in every
attribute value of every node using the
'string.replace' function",
    ),
    desugarer: desugarer_factory(extra),
  )
}

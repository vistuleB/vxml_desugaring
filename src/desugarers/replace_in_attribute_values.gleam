import gleam/option.{Some}
import gleam/list
import gleam/string.{inspect as ins}
import vxml_parser.{type VXML, type BlamedAttribute, BlamedAttribute, V, T}
import infrastructure.{
  type Desugarer, type Pipe,
  DesugarerDescription, type DesugaringError
} as infra

fn replacer(
  mister: BlamedAttribute,
  extra: Extra,
) -> BlamedAttribute {
  BlamedAttribute(
    mister.blame,
    mister.key,
    list.fold(
      extra,
      mister.value,
      fn (current, pair) {
        let #(from, to) = pair
        string.replace(current, from, to)
      }
    )
  )
}

fn param_transform(
  vxml: VXML,
  extra: Extra,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> Ok(V(
      blame,
      tag,
      attrs |> list.map(replacer(_, extra)),
      children
    ))
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

pub fn replace_in_attribute_values(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("replace_in_attribute_values", Some(ins(extra)), "..."),
    desugarer_factory(extra),
  )
}

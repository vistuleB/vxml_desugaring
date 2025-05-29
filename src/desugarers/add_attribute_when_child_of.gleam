import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, V}

fn transform(
  vxml: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  inner_param: InnerParam,
) -> Result(VXML, DesugaringError) {
  use blame, tag, attributes, children <- infra.on_t_on_v(vxml, fn(_, _) {
    Ok(vxml)
  })

  use parent, _ <- infra.on_lazy_empty_on_nonempty(ancestors, fn() { Ok(vxml) })

  let assert V(_, parent_tag, _, _) = parent

  use attributes_to_add <- infra.on_error_on_ok(
    dict.get(inner_param, #(tag, parent_tag)),
    fn(_) { Ok(vxml)}
  )

  let old_attribute_keys = infra.get_attribute_keys(attributes)

  let attributes_to_add =
    list.fold(
      over: attributes_to_add,
      from: [],
      with: fn(so_far, pair) {
        let #(key, value) = pair
        case list.contains(old_attribute_keys, key) {
          True -> so_far
          False -> [BlamedAttribute(blame, key, value), ..so_far]
        }
      }
    )
    |> list.reverse

  Ok(V(blame, tag, list.append(attributes, attributes_to_add), children))
}

fn transform_factory(inner_param: InnerParam) -> infra.NodeToNodeFancyTransform {
  fn(vxml, ancestors, s1, s2, s3) {
    transform(vxml, ancestors, s1, s2, s3, inner_param)
  }
}

fn desugarer_factory(inner_param: InnerParam) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(inner_param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param
  |> infra.quadruples_to_pairs_pairs
  |> infra.aggregate_on_first)
}

type Param =
  List(#(String, String, String, String))
//       tag     parent  attr    value

type InnerParam =
  Dict(#(String, String), List(#(String, String)))

/// adds an attribute-pair to a tag
/// when it is the child of another specified
/// tag; will not overwrite if attribute with
/// that key already exists
pub fn add_attribute_when_child_of(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "add_attribute_when_child_of",
      option.Some(string.inspect(param)),
      "
adds an attribute-pair to a tag
when it is the child of another specified
tag; will not overwrite if attribute with
that key already exists
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner_param) -> desugarer_factory(inner_param)
    }
  )
}
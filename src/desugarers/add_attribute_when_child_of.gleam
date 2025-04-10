import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, V}

fn param_transform(
  vxml: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  param: Param,
) -> Result(VXML, DesugaringError) {
  use blame, tag, attributes, children <- infra.on_t_on_v(vxml, fn(_, _) {
    Ok(vxml)
  })

  use parent, _ <- infra.on_lazy_empty_on_nonempty(ancestors, fn() { Ok(vxml) })

  let assert V(_, parent_tag, _, _) = parent

  use attributes_to_add <- infra.on_error_on_ok(
    dict.get(param, #(tag, parent_tag)),
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

fn extra_to_param(extra: Extra) -> Param {
  extra
  |> infra.quadruples_to_pairs_pairs
  |> infra.aggregate_on_first
}

fn transform_factory(param: Param) -> infra.NodeToNodeFancyTransform {
  fn(vxml, ancestors, s1, s2, s3) {
    param_transform(vxml, ancestors, s1, s2, s3, param)
  }
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(param))
}

type Param =
  Dict(#(String, String), List(#(String, String)))

type Extra =
  List(#(String, String, String, String))
//       tag     parent  attr    value

/// adds an attribute-pair to a tag
/// when it is the child of another specified
/// tag; will not overwrite if attribute with
/// that key already exists
pub fn add_attribute_when_child_of(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("add_attribute_when_child_of", option.Some(string.inspect(extra)), "adds an attribute-pair to a tag
when it is the child of another specified
tag; will not overwrite if attribute with
that key already exists",
    ),
    desugarer: desugarer_factory(extra |> extra_to_param),
  )
}

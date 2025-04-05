import gleam/list
import gleam/option.{None}
import gleam/dict.{type Dict}
import gleam/result
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe} as infra
import vxml.{type VXML, V, BlamedAttribute}

fn param_transform(
  vxml: VXML,
  param: Param,
) -> Result(VXML, DesugaringError) {
  use blame, tag, attributes, children <- infra.on_t_on_v(
    vxml, 
    fn(_, _) { Ok(vxml) }
  )

  use #(new_name, attributes_to_add) <- infra.on_error_on_ok(
    dict.get(param, tag),
    fn(_) { Ok(vxml) }
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

  Ok(V(blame, new_name, list.append(attributes, attributes_to_add), children))
}

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  case validate_extra(extra) {
    Ok(_) -> param_transform(_, extra |> extra_2_param)
    Error(e) -> fn(_) { Error(e) }
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

fn validate_extra(extra: Extra) -> Result(Nil, DesugaringError) {
  extra
  |> list.map(fn (tuple) { 
    let #(_, to, _) = tuple
    case infra.valid_tag(to) {
      True -> Ok(Nil)
      False -> Error(DesugaringError(infra.no_blame, "invalid tag name: '" <> to <> "'"))
    }
  })
  |> result.all
  |> result.map(fn(_) {Nil})
}

fn extra_2_param(extra: Extra) -> Param {
  infra.triples_to_dict(extra)
}

type Param =
  Dict(String, #(String, List(#(String, String))))

type Extra =
  List(#(String, String, List(#(String, String))))

pub fn rename_with_attributes(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("rename_with_attributes", None, "..."),
    desugarer: desugarer_factory(extra),
  )
}

import gleam/list
import gleam/option
import gleam/dict.{type Dict}
import gleam/result
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe} as infra
import vxml.{type VXML, V, BlamedAttribute}

fn transform(
  vxml: VXML,
  param: InnerParam,
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

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  use _ <- result.try(
    param
    |> list.map(fn (tuple) {
      let #(_, to, _) = tuple
      case infra.valid_tag(to) {
        True -> Ok(Nil)
        False -> Error(DesugaringError(infra.no_blame, "invalid tag name: '" <> to <> "'"))
      }
    })
    |> result.all
    |> result.map(fn(_) {Nil})
  )
  Ok(infra.triples_to_dict(param))
}

type Param =
  List(#(String, String, List(#(String, String))))

type InnerParam =
  Dict(String, #(String, List(#(String, String))))

pub fn rename_with_attributes(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "rename_with_attributes",
      option.None,
      "..."
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}

import gleam/list
import gleam/option
import gleam/dict.{type Dict}
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe} as infra
import vxml.{type VXML, V, BlamedAttribute}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  use blame, tag, attributes, children <- infra.on_t_on_v(
    vxml,
    fn(_, _) { Ok(vxml) }
  )

  use #(new_name, attributes_to_add) <- infra.on_error_on_ok(
    dict.get(inner, tag),
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

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
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
  )
  Ok(infra.triples_to_dict(param))
}

type Param =
  List(#(String, String, List(#(String, String))))
//       ↖      ↖       ↖
//       from   to      attributes to add

type InnerParam =
  Dict(String, #(String, List(#(String, String))))

/// renames tags and optionally adds attributes
pub fn rename_with_attributes(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "rename_with_attributes",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// renames tags and optionally adds attributes
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

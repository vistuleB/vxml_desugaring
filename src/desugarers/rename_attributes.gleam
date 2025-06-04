import gleam/pair
import gleam/list
import gleam/option.{None}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

fn param_transform(vxml: VXML, param: Param) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {

      case list.find(param, fn(attr_pair){
        infra.get_attribute_keys(attrs) |> list.contains(attr_pair |> pair.first)
      })
      {
        Error(_) -> Ok(vxml)
        Ok(attr_pair) -> {
          attrs
          |> list.map(fn(attr){
            case pair.first(attr_pair) == attr.key {
              True -> vxml.BlamedAttribute(..attr, key: pair.second(attr_pair))
              False -> attr
            }
          })
          |> V(blame, tag, _, children)
          |> Ok
        }
      }
    }
  }
}

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

type Param =
  List(#(String, String))

pub fn rename_attributes(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription("rename_attributes", None, "renames attributes keys"),
    desugarer: desugarer_factory(param),
  )
}

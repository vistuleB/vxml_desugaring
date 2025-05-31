import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(vxml: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case dict.get(param, tag) {
        Error(Nil) -> Ok(vxml)
        Ok(inner_dict) -> {
          let new_children =
            list.map(children, fn(child) {
              case child {
                T(_, _) -> child
                V(child_blame, child_tag, child_attrs, grandchildren) -> {
                  case dict.get(inner_dict, child_tag) {
                    Error(Nil) -> child
                    Ok(new_name) ->
                      V(child_blame, new_name, child_attrs, grandchildren)
                  }
                }
              }
            })
          Ok(V(blame, tag, attrs, new_children))
        }
      }
    }
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  let inner_param = param
    |> list.fold(
      from: dict.from_list([]),
      with: fn(
        state: Dict(String, Dict(String, String)),
        incoming: #(String, String, String),
      ) {
        let #(old_name, new_name, parent_name) = incoming
        case dict.get(state, parent_name) {
          Error(Nil) -> {
            dict.insert(
              state,
              parent_name,
              dict.from_list([#(old_name, new_name)]),
            )
          }
          Ok(existing_dict) -> {
            dict.insert(
              state,
              parent_name,
              dict.insert(existing_dict, old_name, new_name),
            )
          }
        }
      },
    )
  Ok(inner_param)
}

type Param =
  List(#(String,   String,   String))
//       old_name, new_name, parent
//********************************

type InnerParam =
  Dict(String, Dict(String, String))

pub fn rename_when_child_of(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "rename_when_child_of",
      option.None,
      "..."
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}

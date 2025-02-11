import gleam/option.{None}
import gleam/dict.{type Dict}
import gleam/list
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V}

fn param_transform(
  vxml: VXML, 
  param: Param
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case dict.get(param, tag) {
        Error(Nil) -> Ok(vxml)
        Ok(inner_dict) -> {
          let new_children = list.map(
            children,
            fn (child) {
              case child {
                T(_, _) -> child
                V(child_blame, child_tag, child_attrs, grandchildren) -> {
                  case dict.get(inner_dict, child_tag) {
                    Error(Nil) -> child
                    Ok(new_name) -> V(child_blame, new_name, child_attrs, grandchildren)
                  }
                }
              }
            }
          )
          Ok(V(blame, tag, attrs, new_children))
        }
      }
    }
  }
}

fn param(extra: Extra) -> Param {
  extra
  |> list.fold(
    from: dict.from_list([]),
    with: fn(
      state: Dict(String, Dict(String, String)),
      incoming: #(String, String, String)
    ) {
      let #(old_name, new_name, parent_name) = incoming
      case dict.get(state, parent_name) {
        Error(Nil) -> {
          dict.insert(state, parent_name, dict.from_list([#(old_name, new_name)]))
        }
        Ok(existing_dict) -> {
          dict.insert(
            state,
            parent_name,
            dict.insert(
              existing_dict,
              old_name,
              new_name
            )
          )
        }
      }
    }
  )
}

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  param_transform(_, extra |> param)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

type Param = Dict(String, Dict(String, String))

type Extra =
  List(#(String, String, String))
//********************************
//    old_name, new_name, parent
//********************************

pub fn rename_when_child_of(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("rename_when_child_of", None, "..."),
    desugarer_factory(extra),
  )
}

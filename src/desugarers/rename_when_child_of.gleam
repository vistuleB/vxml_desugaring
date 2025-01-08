import gleam/option.{None}
import gleam/dict.{type Dict}
import gleam/list
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V}

// fn param_transform_v2(
//   node: VXML,
//   ancestors: List(VXML),
//   _: List(VXML),
//   _: List(VXML),
//   _: List(VXML),
//   param: Param
// ) -> Result(VXML, DesugaringError) {
//   case node {
//     T(_, _) -> Ok(node)
//     V(blame, tag, attrs, children) -> {
//       case dict.get(param, tag) -> {
//         Error(Nil) -> Ok(node)
//         Ok(inner_dict) -> {
//           case list.first(ancestors) {
//             Error(Nil) -> Ok(node)
//             Ok(parent) -> {
//               let assert V(_, parent_tag, _, _) = parent
//               case dict.get(inner_dict, parent_tag) {
//                 Error(Nil) -> Ok(node)
//                 Ok(new_name) -> Ok(V(blame, new_name, attrs, children))
//               }
//             }
//           }
//         }
//       }
//     }
//   }
// }

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

fn convert_extra_to_param(extra: Extra) -> Param {
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

type Param = Dict(String, Dict(String, String))

type Extra =
  List(#(String, String, String))
//********************************
//    old_name, new_name, parent
//********************************

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  let param = convert_extra_to_param(extra)
  param_transform(_, param)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

pub fn rename_when_child_of(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("rename_when_child_of", None, "..."),
    desugarer_factory(extra),
  )
}

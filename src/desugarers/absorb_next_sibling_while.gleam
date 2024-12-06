import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V}

const ins = string.inspect

fn update_children(children: List(VXML), param: Dict(String, List(String))) {
  case children {
    [] -> []
    [first, ..rest] -> {
      let #(last_child, previous_children) =
        list.fold(
          over: rest,
          from: #(first, []),
          with: fn(state: #(VXML, List(VXML)), incoming: VXML) -> #(
            VXML,
            List(VXML),
          ) {
            let #(previous_sibling, already_bundled) = state
            case previous_sibling {
              T(_, _) -> #(incoming, [previous_sibling, ..already_bundled])
              V(
                previous_sibling_blame,
                previous_sibiling_tag,
                previous_sibling_attributes,
                previous_sibling_children,
              ) -> {
                case incoming {
                  T(_, _) -> #(incoming, [previous_sibling, ..already_bundled])
                  V(_, incoming_tag, _, _) -> {
                    case dict.get(param, previous_sibiling_tag) {
                      Error(Nil) -> #(incoming, [
                        previous_sibling,
                        ..already_bundled
                      ])
                      Ok(absorbed_tags) -> {
                        case list.contains(absorbed_tags, incoming_tag) {
                          False -> #(incoming, [
                            previous_sibling,
                            ..already_bundled
                          ])
                          True -> {
                            let new_previous_sibling_children =
                              list.append(previous_sibling_children, [incoming])
                            let new_previous_sibling =
                              V(
                                previous_sibling_blame,
                                previous_sibiling_tag,
                                previous_sibling_attributes,
                                new_previous_sibling_children,
                              )
                            #(new_previous_sibling, already_bundled)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          },
        )
      [last_child, ..previous_children] |> list.reverse
    }
  }
}

fn param_transform(node: VXML, pairs: Param) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attributes, children) ->
      Ok(V(blame, tag, attributes, update_children(children, pairs)))
    _ -> Ok(node)
  }
}

type Param =
  Dict(String, List(String))

fn extra_2_param(extra: Extra) -> Param {
  list.fold(
    over: extra,
    from: dict.from_list([]),
    with: fn(current_dict, incoming: #(String, String)) {
      let #(absorbing_tag, absorbed_tag) = incoming
      case dict.get(current_dict, absorbing_tag) {
        Error(Nil) -> dict.insert(current_dict, absorbing_tag, [absorbed_tag])
        Ok(existing_absorbed) ->
          case list.contains(existing_absorbed, absorbed_tag) {
            False ->
              dict.insert(current_dict, absorbing_tag, [
                absorbed_tag,
                ..existing_absorbed
              ])
            True -> current_dict
          }
      }
    },
  )
}

//**********************************
// type Extra = List(#(String,            String))
//                       ↖ tag that         ↖ tag that will
//                         will absorb        be absorbed by
//                         next sibling       previous sibling
//**********************************
type Extra =
  List(#(String, String))

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

pub fn absorb_next_sibling_while(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("absorb_next_sibling_while", Some(ins(extra)), "..."),
    desugarer_factory(extra_2_param(extra)),
  )
}

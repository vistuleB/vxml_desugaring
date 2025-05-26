import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

const ins = string.inspect

fn list_first_rest(l: List(a)) -> Result(#(a, List(a)), Nil) {
  case l {
    [] -> Error(Nil)
    [first, ..rest] -> Ok(#(first, rest))
  }
}

fn result_map_both(
  over r: Result(a, b),
  with_for_error with_for_error: fn(b) -> c,
  with_for_ok with_for_ok: fn(a) -> c,
) -> c {
  case r {
    Ok(t) -> with_for_ok(t)
    Error(t) -> with_for_error(t)
  }
}

fn prepend_first_item_to_second_item(p: #(a, List(a))) -> List(a) {
  [p |> pair.first, ..{ p |> pair.second }]
}

fn update_children(
  children: List(VXML),
  inner_param: InnerParam,
) -> List(VXML) {
  use #(first, rest) <- result_map_both(
    list_first_rest(children),
    with_for_error: fn(_) { [] },
  )

  list.fold(
    over: rest,
    from: #(first, []),
    with: fn(state: #(VXML, List(VXML)), incoming: VXML) -> #(VXML, List(VXML)) {
      let #(previous_sibling, already_bundled) = state
      case previous_sibling, incoming {
        T(_, _), _ -> #(incoming, [previous_sibling, ..already_bundled])
        _, T(_, _) -> #(incoming, [previous_sibling, ..already_bundled])
        V(
          previous_sibling_blame,
          previous_sibiling_tag,
          previous_sibling_attributes,
          previous_sibling_children,
        ),
          V(_, incoming_tag, _, _)
        -> {
          case dict.get(inner_param, previous_sibiling_tag) {
            Error(Nil) -> #(incoming, [previous_sibling, ..already_bundled])
            Ok(absorbed_tags) -> {
              case list.contains(absorbed_tags, incoming_tag) {
                False -> #(incoming, [previous_sibling, ..already_bundled])
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
    },
  )
  |> prepend_first_item_to_second_item
  |> list.reverse
}

fn transform(node: VXML, inner_param: InnerParam) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attributes, children) ->
      Ok(V(blame, tag, attributes, update_children(children, inner_param)))
    _ -> Ok(node)
  }
}

fn transform_factory(inner_param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner_param)
}

fn desugarer_factory(inner_param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner_param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(list.fold(
    over: param,
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
  ))
}

//**********************************
// type Param = List(#(String,            String))
//                       ↖ tag that         ↖ tag that will
//                         will absorb        be absorbed by
//                         next sibling       previous sibling
//**********************************
type Param =
  List(#(String, String))

type InnerParam =
  Dict(String, List(String))

/// if the arguments are [#(\"Tag1\", \"Child1\"),
/// (\"Tag1\", \"Child1\")] then will cause Tag1
/// nodes to absorb all subsequent Child1 & Child2
/// nodes, as long as they come immediately after
/// Tag1 (in any order)"
pub fn absorb_next_sibling_while(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "absorb_next_sibling_while",
      Some(ins(param)),
      "if the arguments are [#(\"Tag1\", \"Child1\"),
(\"Tag1\", \"Child1\")] then will cause Tag1
nodes to absorb all subsequent Child1 & Child2
nodes, as long as they come immediately after
Tag1 (in any order)",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner_param) -> desugarer_factory(inner_param)
    }
  )
}
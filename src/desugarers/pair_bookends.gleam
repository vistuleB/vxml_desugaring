import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn pair_bookends_children_accumulator(
  opening: List(String),
  closing: List(String),
  enclosing: String,
  already_processed: List(VXML),
  last_opening: Option(VXML),
  after_last_opening: List(VXML),
  remaining: List(VXML),
) -> List(VXML) {
  case remaining {
    [] ->
      case last_opening {
        None -> {
          let assert [] = after_last_opening
          already_processed |> list.reverse
        }
        Some(dude) -> {
          list.flatten([after_last_opening, [dude, ..already_processed]])
          |> list.reverse
        }
      }
    [T(_, _) as first, ..rest] ->
      case last_opening {
        None -> {
          // *
          // absorb the T-node into already_processed
          // *
          let assert [] = after_last_opening
          pair_bookends_children_accumulator(
            opening,
            closing,
            enclosing,
            [first, ..already_processed],
            None,
            [],
            rest,
          )
        }
        Some(_) ->
          // *
          // absorb the T-node into after_last_opening
          // *
          pair_bookends_children_accumulator(
            opening,
            closing,
            enclosing,
            already_processed,
            last_opening,
            [first, ..after_last_opening],
            rest,
          )
      }
    [V(_, tag, _, _) as first, ..rest] ->
      case list.contains(opening, tag), list.contains(closing, tag) {
        False, False ->
          // *
          // treat the V-node like the T-node above
          // *
          case last_opening {
            None -> {
              // *
              // absorb the V-node into already_processed
              // *
              let assert [] = after_last_opening
              pair_bookends_children_accumulator(
                opening,
                closing,
                enclosing,
                [first, ..already_processed],
                None,
                [],
                rest,
              )
            }
            Some(_) ->
              // *
              // absorb the V-node into after_last_opening
              // *
              pair_bookends_children_accumulator(
                opening,
                closing,
                enclosing,
                already_processed,
                last_opening,
                [first, ..after_last_opening],
                rest,
              )
          }
        True, False ->
          case last_opening {
            None -> {
              // *
              // we make the V-node the new value of last_opening
              // *
              let assert [] = after_last_opening
              pair_bookends_children_accumulator(
                opening,
                closing,
                enclosing,
                already_processed,
                Some(first),
                [],
                rest,
              )
            }
            Some(dude) ->
              // *
              // we discard the previous last_opening and his followers and make the V-node the new value of last_opening
              // *
              pair_bookends_children_accumulator(
                opening,
                closing,
                enclosing,
                list.flatten([after_last_opening, [dude, ..already_processed]]),
                Some(first),
                [],
                rest,
              )
          }
        False, True ->
          case last_opening {
            None -> {
              // *
              // we absorb the V-node into already_processed
              // *
              let assert [] = after_last_opening
              pair_bookends_children_accumulator(
                opening,
                closing,
                enclosing,
                [first, ..already_processed],
                None,
                [],
                rest,
              )
            }
            Some(dude) ->
              // *
              // we do a pairing
              // *
              pair_bookends_children_accumulator(
                opening,
                closing,
                enclosing,
                [
                  V(
                    infra.get_blame(dude)
                      |> infra.append_blame_comment(
                        "paired with " <> ins(infra.get_blame(first)),
                      ),
                    enclosing,
                    [],
                    after_last_opening |> list.reverse,
                  ),
                  ..already_processed
                ],
                None,
                [],
                rest,
              )
          }
        True, True ->
          case last_opening {
            None -> {
              // *
              // we make the V-node the new value of last_opening
              // *
              let assert [] = after_last_opening
              pair_bookends_children_accumulator(
                opening,
                closing,
                enclosing,
                already_processed,
                Some(first),
                [],
                rest,
              )
            }
            Some(dude) ->
              // *
              // we do a pairing
              // *
              pair_bookends_children_accumulator(
                opening,
                closing,
                enclosing,
                [
                  V(
                    infra.get_blame(dude)
                      |> infra.append_blame_comment(
                        "paired with " <> ins(infra.get_blame(first)),
                      ),
                    enclosing,
                    [],
                    after_last_opening |> list.reverse,
                  ),
                  ..already_processed
                ],
                None,
                [],
                rest,
              )
          }
      }
  }
}

fn transform(
  node: VXML,
  opening: List(String),
  closing: List(String),
  enclosing: String,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attrs, children) -> {
      let new_children =
        pair_bookends_children_accumulator(
          opening,
          closing,
          enclosing,
          [],
          None,
          [],
          children,
        )
      Ok(V(blame, tag, attrs, new_children))
    }
  }
}

fn transform_factory(
  param: InnerParam,
) -> infra.NodeToNodeTransform {
  let #(opening, closing, enclosing) = param
  transform(_, opening, closing, enclosing)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(List(String), List(String), String)

type InnerParam = Param

pub fn pair_bookends(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription("pair_bookends", Some(ins(param)), "..."),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml_parser.{type VXML, BlamedContent, T, V}

const ins = string.inspect

fn last_line_concatenate_with_first_line(node1: VXML, node2: VXML) -> VXML {
  let assert T(blame1, lines1) = node1
  let assert T(_, lines2) = node2

  let assert [BlamedContent(blame_last, content_last), ..other_lines1] =
    lines1 |> list.reverse
  let assert [BlamedContent(_, content_first), ..other_lines2] = lines2

  T(
    blame1,
    list.flatten([
      other_lines1 |> list.reverse,
      [BlamedContent(blame_last, content_last <> content_first)],
      other_lines2,
    ]),
  )
}

fn turn_into_text_node(node: VXML, text: String) -> VXML {
  let blame = infra.get_blame(node)
  T(blame, [BlamedContent(blame, text)])
}

fn fold_tags_into_text_children_accumulator(
  tags2texts: Dict(String, String),
  already_processed: List(VXML),
  optional_last_t: Option(VXML),
  optional_last_v: Option(#(VXML, String)),
  remaining: List(VXML),
) -> List(VXML) {
  // *
  // - already_processed: previously processed children in
  //   reverse order (last stuff is first in the list)
  //
  // - optional_last_t is:
  //   * the node right before optional_last_v if 
  //     optional_last_v != None
  //   * the last node before remaining if 
  //     optional_last_v == None
  //
  // - optional_last_v is a possible previoux v-node that
  //   matched the dictionary; if it is not None, it is the
  //   immediately previous node to 'remaining'
  //
  // PURPOSE: this function should turn tags that appear
  //     in the tags2texts dictionary into text fragments
  //     that become into last/first line of the previous/next
  //     text nodes to the tag, if any, possibly resulting
  //     in the two text nodes on either side of the tag
  //     becoming joined into one text gone (by glued via
  //     the tag text); if there are no adjacent text nodes,
  //     the tag becomes a new standalone text node
  // *
  case remaining {
    [] ->
      case optional_last_t {
        None -> {
          case optional_last_v {
            None ->
              // *
              // case N00: - no following node
              //           - no previous t node
              //           - no previous v node
              //
              // we reverse the list
              // *
              already_processed |> list.reverse
            Some(#(last_v, last_v_text)) ->
              // *
              // case N01: - no following node
              //           - no previous t node
              //           - there is a previous v node
              //
              // we turn the previous v node into a standalone text node
              // *
              [turn_into_text_node(last_v, last_v_text), ..already_processed]
              |> list.reverse
          }
        }
        Some(last_t) ->
          case optional_last_v {
            None ->
              // *
              // case N10: - no following node
              //           - there is a previous t node
              //           - no previous v node
              //
              // we add the t to already_processed, reverse the list
              // *
              [last_t, ..already_processed] |> list.reverse
            Some(#(_, replacement_text)) ->
              // *
              // case N11: - no following node
              //           - there is a previous t node
              //           - there is a previous v node
              //
              // we bundle the t & v, add to already_processed, reverse the list
              // *
              [
                infra.t_end_insert_text(last_t, replacement_text),
                ..already_processed
              ]
              |> list.reverse
          }
      }
    [T(_, _) as first, ..rest] ->
      case optional_last_t {
        None ->
          case optional_last_v {
            None ->
              // *
              // case T00: - 'first' is a Text node
              //           - no previous t node
              //           - no previous v node
              //
              // we make 'first' the previous t node
              // *
              fold_tags_into_text_children_accumulator(
                tags2texts,
                already_processed,
                Some(first),
                None,
                rest,
              )
            Some(#(_, last_v_text)) ->
              // *
              // case T01: - 'first' is a Text node
              //           - no previous t node
              //           - there exists a previous v node
              //
              // we bundle the v & first, add to already_processed, reset v to None
              // *
              fold_tags_into_text_children_accumulator(
                tags2texts,
                already_processed,
                Some(infra.t_start_insert_text(first, last_v_text)),
                None,
                rest,
              )
          }
        Some(last_t) -> {
          case optional_last_v {
            None ->
              // *
              // case T10: - 'first' is a Text node
              //           - there exists a previous t node
              //           - no previous v node
              //
              // we pass the previous t into already_processed and make 'first' the new optional_last_t
              // *
              fold_tags_into_text_children_accumulator(
                tags2texts,
                [last_t, ..already_processed],
                Some(first),
                None,
                rest,
              )
            Some(#(_, text)) -> {
              // *
              // case T11: - 'first' is a Text node
              //           - there exists a previous t node
              //           - there exists a previous v node
              //
              // we bundle t & v & first and etc
              // *
              fold_tags_into_text_children_accumulator(
                tags2texts,
                already_processed,
                Some(last_line_concatenate_with_first_line(
                  last_t,
                  infra.t_start_insert_text(first, text),
                )),
                None,
                rest,
              )
            }
          }
        }
      }
    [V(_, tag, _, _) as first, ..rest] ->
      case optional_last_t {
        None -> {
          case optional_last_v {
            None ->
              case dict.get(tags2texts, tag) {
                Error(Nil) ->
                  // *
                  // case W00: - 'first' is non-matching V-node
                  //           - no previous t node
                  //           - no previous v node
                  //
                  // add 'first' to already_processed
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags2texts,
                    [first, ..already_processed],
                    None,
                    None,
                    rest,
                  )
                Ok(text) ->
                  // *
                  // case M00: - 'first' is matching V-node
                  //           - no previous t node
                  //           - no previous v node
                  //
                  // make 'first' the optional_last_v
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags2texts,
                    already_processed,
                    None,
                    Some(#(first, text)),
                    rest,
                  )
              }
            Some(#(last_v, last_v_text)) ->
              case dict.get(tags2texts, tag) {
                Error(Nil) ->
                  // *
                  // case W01: - 'first' is non-matching V-node
                  //           - no previous t node
                  //           - there exists a previous v node
                  //
                  // standalone-bundle the previous v node & add first to already processed
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags2texts,
                    [
                      first,
                      turn_into_text_node(last_v, last_v_text),
                      ..already_processed
                    ],
                    None,
                    None,
                    rest,
                  )
                Ok(text) ->
                  // *
                  // case M01: - 'first' is matching V-node
                  //           - no previous t node
                  //           - there exists a previous v node
                  //
                  // standalone-bundle the previous v node & make 'first' the optional_last_v
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags2texts,
                    already_processed,
                    Some(turn_into_text_node(last_v, last_v_text)),
                    Some(#(first, text)),
                    rest,
                  )
              }
          }
        }
        Some(last_t) ->
          case optional_last_v {
            None ->
              case dict.get(tags2texts, tag) {
                Error(Nil) ->
                  // *
                  // case W10: - 'first' is a non-matching V-node
                  //           - there exists a previous t node
                  //           - no previous v node
                  //
                  // add 'first' and previoux t node to already_processed
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags2texts,
                    [first, last_t, ..already_processed],
                    None,
                    None,
                    rest,
                  )
                Ok(text) ->
                  // *
                  // case M10: - 'first' is a matching V-node
                  //           - there exists a previous t node
                  //           - no previous v node
                  //
                  // keep the previous t node, make 'first' the optional_last_v
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags2texts,
                    already_processed,
                    optional_last_t,
                    Some(#(first, text)),
                    rest,
                  )
              }
            Some(#(_, last_v_text)) ->
              case dict.get(tags2texts, tag) {
                Error(Nil) ->
                  // *
                  // case W11: - 'first' is a non-matching V-node
                  //           - there exists a previous t node
                  //           - there exists a previous v node
                  //
                  // fold t & v, put first & folder t/v into already_processed
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags2texts,
                    [
                      first,
                      infra.t_end_insert_text(last_t, last_v_text),
                      ..already_processed
                    ],
                    None,
                    None,
                    rest,
                  )
                Ok(text) ->
                  // *
                  // case M11: - 'first' is matching V-node
                  //           - there exists a previous t node
                  //           - there exists a previous v node
                  //
                  // fold t & v, put into already_processed, make v the new optional_last_v
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags2texts,
                    already_processed,
                    Some(infra.t_end_insert_text(last_t, text)),
                    Some(#(first, text)),
                    rest,
                  )
              }
          }
      }
  }
}

fn param_transform(
  node: VXML,
  tags_and_texts: Param,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attrs, children) -> {
      let new_children =
        fold_tags_into_text_children_accumulator(
          tags_and_texts,
          [],
          None,
          None,
          children,
        )
      Ok(V(blame, tag, attrs, new_children))
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
  Dict(String, String)

//*********************************
// - first string is tag name
// - second string is replacement value to use
type Extra =
  List(#(String, String))

pub fn fold_tags_into_text(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "fold_tags_into_text",
      Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra |> dict.from_list),
  )
}

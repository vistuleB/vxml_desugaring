import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription, DesugaringError,
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

fn inside_text_node(node: VXML) -> VXML {
  let assert V(_, _, _, children) = node
  let assert [T(_, _) as child] = children
  child
}

fn fold_tags_into_text_children_accumulator(
  tags: Extra,
  already_processed: List(VXML),
  optional_last_t: Option(VXML),
  optional_last_v: Option(VXML),
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
            Some(last_v) ->
              // *
              // case N01: - no following node
              //           - no previous t node
              //           - there is a previous v node
              //
              // we turn the previous v node into a standalone text node
              // *
              [inside_text_node(last_v), ..already_processed]
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
            Some(last_v) ->
              // *
              // case N11: - no following node
              //           - there is a previous t node
              //           - there is a previous v node
              //
              // we bundle the t & v, add to already_processed, reverse the list
              // *
              [last_line_concatenate_with_first_line(last_t, inside_text_node(last_v)), ..already_processed]
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
                tags,
                already_processed,
                Some(first),
                None,
                rest,
              )
            Some(last_v) ->
              // *
              // case T01: - 'first' is a Text node
              //           - no previous t node
              //           - there exists a previous v node
              //
              // we bundle the v & first, add to already_processed, reset v to None
              // *
              fold_tags_into_text_children_accumulator(
                tags,
                already_processed,
                Some(last_line_concatenate_with_first_line(inside_text_node(last_v), first)),
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
                tags,
                [last_t, ..already_processed],
                Some(first),
                None,
                rest,
              )
            Some(last_v) -> {
              // *
              // case T11: - 'first' is a Text node
              //           - there exists a previous t node
              //           - there exists a previous v node
              //
              // we bundle t & v & first and etc
              // *
              fold_tags_into_text_children_accumulator(
                tags,
                already_processed,
                Some(last_line_concatenate_with_first_line(
                  last_t,
                  last_line_concatenate_with_first_line(
                    inside_text_node(last_v),
                    first
                  ),
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
              case list.contains(tags, tag) {
                False ->
                  // *
                  // case W00: - 'first' is non-matching V-node
                  //           - no previous t node
                  //           - no previous v node
                  //
                  // add 'first' to already_processed
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags,
                    [first, ..already_processed],
                    None,
                    None,
                    rest,
                  )
                True ->
                  // *
                  // case M00: - 'first' is matching V-node
                  //           - no previous t node
                  //           - no previous v node
                  //
                  // make 'first' the optional_last_v
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags,
                    already_processed,
                    None,
                    Some(first),
                    rest,
                  )
              }
            Some(last_v) ->
              case list.contains(tags, tag) {
                False ->
                  // *
                  // case W01: - 'first' is non-matching V-node
                  //           - no previous t node
                  //           - there exists a previous v node
                  //
                  // standalone-bundle the previous v node & add first to already processed
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags,
                    [
                      first,
                      inside_text_node(last_v),
                      ..already_processed
                    ],
                    None,
                    None,
                    rest,
                  )
                True ->
                  // *
                  // case M01: - 'first' is matching V-node
                  //           - no previous t node
                  //           - there exists a previous v node
                  //
                  // standalone-bundle the previous v node & make 'first' the optional_last_v
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags,
                    already_processed,
                    Some(inside_text_node(last_v)),
                    Some(first),
                    rest,
                  )
              }
          }
        }
        Some(last_t) ->
          case optional_last_v {
            None ->
              case list.contains(tags, tag) {
                False ->
                  // *
                  // case W10: - 'first' is a non-matching V-node
                  //           - there exists a previous t node
                  //           - no previous v node
                  //
                  // add 'first' and previoux t node to already_processed
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags,
                    [first, last_t, ..already_processed],
                    None,
                    None,
                    rest,
                  )
                True ->
                  // *
                  // case M10: - 'first' is a matching V-node
                  //           - there exists a previous t node
                  //           - no previous v node
                  //
                  // keep the previous t node, make 'first' the optional_last_v
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags,
                    already_processed,
                    optional_last_t,
                    Some(first),
                    rest,
                  )
              }
            Some(last_v) ->
              case list.contains(tags, tag) {
                False ->
                  // *
                  // case W11: - 'first' is a non-matching V-node
                  //           - there exists a previous t node
                  //           - there exists a previous v node
                  //
                  // fold t & v, put first & folder t/v into already_processed
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags,
                    [
                      first,
                      last_line_concatenate_with_first_line(last_t, inside_text_node(last_v)),
                      ..already_processed
                    ],
                    None,
                    None,
                    rest,
                  )
                True ->
                  // *
                  // case M11: - 'first' is matching V-node
                  //           - there exists a previous t node
                  //           - there exists a previous v node
                  //
                  // fold t & v, put into already_processed, make v the new optional_last_v
                  // *
                  fold_tags_into_text_children_accumulator(
                    tags,
                    already_processed,
                    Some(last_line_concatenate_with_first_line(last_t, inside_text_node(last_v))),
                    Some(first),
                    rest,
                  )
              }
          }
      }
  }
}

fn param_transform(
  node: VXML,
  tags: Extra,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attrs, children) -> {
      let new_children =
        fold_tags_into_text_children_accumulator(
          tags,
          [],
          None,
          None,
          children,
        )
      Ok(V(blame, tag, attrs, new_children))
    }
  }
}

fn transform_factory(extra: Extra) -> NodeToNodeTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

//*********************************
// list of tags whose contents should
// be folded into surrounding text
type Extra = List(String)

pub fn fold_tag_contents_into_text(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("fold_tag_contents_into_text", Some(ins(extra)), "..."),
    desugarer_factory(extra),
  )
}

import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/string
import infrastructure.{type DesugaringError}
import vxml_parser.{
  type Blame, type BlamedContent, type VXML, BlamedContent, T, V,
}

pub type SplitDelimitersChunksExtraArgs {
  SplitDelimitersChunksExtraArgs(
    open_delimiter: String,
    close_delimiter: String,
    tag_name: String,
    splits_chunks: Bool,
    can_be_nested_inside: List(String),
  )
}

type Splits {
  DelimiterSurrounding(list: PositionedBlamedContents)
  DelimiterContent(list: PositionedBlamedContents)
}

type InlineTags =
  List(#(VXML, Int))

type PositionedBlamedContents =
  List(#(BlamedContent, Int))

fn look_for_closing_delimiter(
  rest: PositionedBlamedContents,
  extra: SplitDelimitersChunksExtraArgs,
  output: PositionedBlamedContents,
) -> #(Bool, PositionedBlamedContents, PositionedBlamedContents) {
  // return list of blamed contents inside delimiter and rest of blamed contents
  case rest {
    [] -> #(False, [], [])
    [#(first, pos), ..rest] -> {
      let cropped = string.crop(first.content, extra.close_delimiter)
      case cropped == first.content {
        True -> {
          let #(found, output, rest) =
            look_for_closing_delimiter(rest, extra, output)
          #(found, [#(first, pos), ..output], rest)
        }
        False -> {
          let before_closing_del =
            cropped |> string.length() |> string.drop_right(first.content, _)
          let after_closing_del =
            extra.close_delimiter
            |> string.length()
            |> string.drop_left(cropped, _)

          #(
            True,
            list.append(output, [
              #(
                BlamedContent(blame: first.blame, content: before_closing_del),
                pos,
              ),
            ]),
            [
              #(
                BlamedContent(blame: first.blame, content: after_closing_del),
                pos,
              ),
              ..rest
            ],
          )
        }
      }
    }
  }
}

fn split_blamed_contents_by_delimiter(
  contents: PositionedBlamedContents,
  extra: SplitDelimitersChunksExtraArgs,
  iteration: Int,
) -> List(Splits) {
  case contents {
    [] -> []
    [#(first, pos), ..rest] -> {
      let cropped = string.crop(first.content, extra.open_delimiter)
      case
        cropped == first.content,
        string.starts_with(first.content, extra.open_delimiter)
      {
        True, False -> {
          [
            DelimiterSurrounding([#(first, pos)]),
            ..split_blamed_contents_by_delimiter(rest, extra, iteration + 1)
          ]
        }
        _, _ -> {
          // check closing
          let cropped_str_length = string.length(cropped)
          let before_delimiter_split =
            BlamedContent(
              blame: first.blame,
              content: string.drop_right(first.content, cropped_str_length),
            )

          let current_line_delimiter_content =
            BlamedContent(
              blame: first.blame,
              content: extra.open_delimiter
                |> string.length()
                |> string.drop_left(cropped, _),
            )

          let #(found, delimiter_content, rest) =
            look_for_closing_delimiter(
              list.append([#(current_line_delimiter_content, pos)], rest),
              extra,
              [],
            )
          case found {
            True -> {
              let after_delimiter_split =
                split_blamed_contents_by_delimiter(rest, extra, iteration + 1)

              [DelimiterSurrounding([#(before_delimiter_split, pos)])]
              |> list.append([DelimiterContent(delimiter_content)])
              |> list.append(after_delimiter_split)
            }
            False -> {
              [
                DelimiterSurrounding([#(first, pos)]),
                ..split_blamed_contents_by_delimiter(rest, extra, iteration + 1)
              ]
            }
          }
        }
      }
    }
  }
}

fn get_inline_tags_before(
  inline_tags: InlineTags,
  contents_pos: Int,
  extra: SplitDelimitersChunksExtraArgs,
) -> #(List(VXML), InlineTags) {
  case inline_tags {
    [] -> #([], [])
    [#(tag, position), ..rest] -> {
      case int.compare(position, contents_pos - 1) {
        order.Eq -> {
          let previous_elements =
            inline_tags
            |> list.filter(fn(x) {
              let #(_, prev_pos) = x
              prev_pos <= position
            })
            |> list.map(fn(x) {
              let #(e, _) = x
              e
            })

          #(previous_elements, rest)
        }
        order.Lt -> {
          let #(tags, rest) = get_inline_tags_before(rest, contents_pos, extra)
          #([tag, ..tags], rest)
        }
        order.Gt -> {
          #([], [#(tag, position), ..rest])
        }
      }
    }
  }
}

fn append_until_tag(
  list: List(VXML),
  output: List(BlamedContent),
) -> #(List(BlamedContent), List(VXML)) {
  case list {
    [] -> #(output, [])
    [first, ..rest] -> {
      case first {
        V(_, _, _, _) -> #(output, [first, ..rest])
        T(_, contents) -> {
          let #(output, rest) = append_until_tag(rest, output)
          #(list.append(contents, output), rest)
        }
      }
    }
  }
}

fn assemble_lines(list: List(VXML)) -> List(VXML) {
  case list {
    [] -> []
    [first, ..rest] -> {
      case first {
        V(_, _, _, _) -> [first, ..assemble_lines(rest)]
        T(blame, contents) -> {
          let #(next_contents, rest) = append_until_tag(rest, [])
          [
            T(blame, list.append(contents, next_contents)),
            ..assemble_lines(rest)
          ]
        }
      }
    }
  }
}

fn merge_split_list_with_inline_tags(
  blame: Blame,
  list: PositionedBlamedContents,
  inline_tags: InlineTags,
  extra: SplitDelimitersChunksExtraArgs,
) -> #(List(VXML), InlineTags) {
  case list {
    [] -> #([], inline_tags)

    [#(blamed_content, pos), ..rest] -> {
      let #(tags, rest_tags) = get_inline_tags_before(inline_tags, pos, extra)

      let #(merged, rest_tags) =
        merge_split_list_with_inline_tags(blame, rest, rest_tags, extra)

      #(
        tags
          |> list.append(case string.is_empty(blamed_content.content) {
            True -> []
            False -> [T(blame, [blamed_content])]
          })
          |> list.append(merged),
        rest_tags,
      )
    }
  }
}

fn append_until_delimiter(
  blame: Blame,
  rest: List(Splits),
  extra: SplitDelimitersChunksExtraArgs,
  output: List(VXML),
  inline_tags: InlineTags,
) -> #(List(VXML), List(Splits), InlineTags) {
  case rest {
    [] -> #(output, [], inline_tags)
    [first, ..rest] -> {
      case first {
        DelimiterSurrounding(list) -> {
          let #(vxmls, rest_tags) =
            merge_split_list_with_inline_tags(blame, list, inline_tags, extra)

          let #(output, rest, rest_tags) =
            append_until_delimiter(blame, rest, extra, output, rest_tags)

          #(list.append(vxmls, output), rest, rest_tags)
        }
        DelimiterContent(_) -> {
          #(output, [first, ..rest], inline_tags)
        }
      }
    }
  }
}

fn map_splits_to_vxml(
  blame: Blame,
  splits: List(Splits),
  inline_tags: InlineTags,
  extra: SplitDelimitersChunksExtraArgs,
) -> List(VXML) {
  case splits {
    [] -> []
    [first, ..rest] -> {
      case first {
        DelimiterSurrounding(list) -> {
          let #(vxmls, rest_tags) =
            merge_split_list_with_inline_tags(blame, list, inline_tags, extra)

          let #(output, rest, rest_tags) =
            append_until_delimiter(blame, rest, extra, [], rest_tags)

          let assembled = assemble_lines(list.append(vxmls, output))
          case extra.splits_chunks {
            True -> {
              case assembled {
                [] -> []
                assembled -> {
                  let chunk = V(blame, "VerticalChunk", [], assembled)
                  [chunk, ..map_splits_to_vxml(blame, rest, rest_tags, extra)]
                }
              }
            }
            False -> {
              list.append(
                assembled,
                map_splits_to_vxml(blame, rest, rest_tags, extra),
              )
            }
          }
        }
        DelimiterContent(list) -> {
          let #(vxmls, rest_tags) =
            merge_split_list_with_inline_tags(blame, list, inline_tags, extra)
          let assembled = assemble_lines(vxmls)

          let new_chunk = V(blame, extra.tag_name, [], assembled)
          [new_chunk, ..map_splits_to_vxml(blame, rest, rest_tags, extra)]
        }
      }
    }
  }
}

fn flatten_chunk_contents(
  children: List(VXML),
  iteration: Int,
) -> #(PositionedBlamedContents, InlineTags) {
  case children {
    [] -> #([], [])
    [first, ..rest] -> {
      let #(res, inline_tags) = flatten_chunk_contents(rest, iteration + 1)

      case first {
        V(_, _, _, _) -> {
          #(res, [#(first, iteration), ..inline_tags])
        }
        T(_, contents) -> {
          let contents_with_position =
            contents
            |> list.map(fn(x) { #(x, iteration) })
            |> list.append(res)
          #(contents_with_position, inline_tags)
        }
      }
    }
  }
}

fn split_chunk_children(children: List(VXML), tag: String, extra) -> List(VXML) {
  case children {
    [] -> []
    [first, ..rest] -> {
      let #(flatten, inline_tags) = flatten_chunk_contents([first, ..rest], 0)

      let mapped_vxml =
        split_blamed_contents_by_delimiter(flatten, extra, 0)
        |> map_splits_to_vxml(first.blame, _, inline_tags, extra)

      let mapped_vxml =
        list.map(mapped_vxml, fn(x) {
          case x {
            T(_, _) -> x
            V(_, tag, _, children) -> {
              case list.contains(extra.can_be_nested_inside, tag) {
                False -> x
                True -> {
                  let assert [updated_vxml] =
                    children
                    |> split_chunk_children(tag, extra)

                  updated_vxml
                }
              }
            }
          }
        })

      case extra.splits_chunks {
        True -> mapped_vxml
        False -> {
          [V(first.blame, tag, [], mapped_vxml)]
        }
      }
    }
  }
}

/// The idea is as follows :
/// 1. split all the children into flatten content and inline tags , flatten content will have all contents followed by each other ignoring any inline tags in between, inline tags should save the tags in between with their position so we can re-merge later 
/// 2. split flattened content by delimiter into splits of what come before delimiter and the delimiter content and what comes after , splits should also save the original position of the line for the re-merge
/// 3. Each split is then merged with tags that comes before it . and give the vxml reltive 
/// 4. if the delimiter can be nested inside other one , we check the mapped_vxml and call the desugarer recursevly on the element that accepts nesting
pub fn split_delimiters_chunks_transform(
  node: VXML,
  _: List(VXML),
  extra: SplitDelimitersChunksExtraArgs,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> Ok([node])
    V(_, "VerticalChunk", _, children) -> {
      children
      |> split_chunk_children("VerticalChunk", extra)
      |> Ok()
    }
    V(_, _, _, _) -> Ok([node])
  }
}

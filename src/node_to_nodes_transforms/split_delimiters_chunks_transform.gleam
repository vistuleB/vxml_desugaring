import gleam/list
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
) -> #(List(VXML), InlineTags) {
  case inline_tags {
    [] -> #([], [])
    [#(inline_tag, position), ..rest] -> {
      case position == contents_pos - 1 {
        True -> {
          let previous_elements =
            inline_tags
            |> list.filter(fn(x) {
              let #(_, prev_pos) = x
              prev_pos < position
            })
            |> list.map(fn(x) {
              let #(e, _) = x
              e
            })

          #(list.append(previous_elements, [inline_tag]), rest)
        }
        False -> {
          #([], [#(inline_tag, position), ..rest])
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
) -> #(List(VXML), InlineTags) {
  case list {
    [] -> #([], inline_tags)

    [#(blamed_content, pos), ..rest] -> {
      let #(tags, rest_tags) = get_inline_tags_before(inline_tags, pos)
      let #(merged, rest_tags) =
        merge_split_list_with_inline_tags(blame, rest, rest_tags)

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
) -> #(List(VXML), List(Splits)) {
  case rest {
    [] -> #(output, [])
    [first, ..rest] -> {
      case first {
        DelimiterSurrounding(list) -> {
          let #(vxmls, rest_tags) =
            merge_split_list_with_inline_tags(blame, list, inline_tags)

          let #(output, rest) =
            append_until_delimiter(blame, rest, extra, output, rest_tags)

          #(list.append(output, vxmls), rest)
        }
        DelimiterContent(_) -> {
          #(output, [first, ..rest])
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
            merge_split_list_with_inline_tags(blame, list, inline_tags)

          let #(output, rest) =
            append_until_delimiter(blame, rest, extra, vxmls, rest_tags)
          let assembled = assemble_lines(output)

          case assembled {
            [] -> []
            assembled -> {
              let chunk = V(blame, "VerticalChunk", [], assembled)
              [chunk, ..map_splits_to_vxml(blame, rest, rest_tags, extra)]
            }
          }
        }
        DelimiterContent(list) -> {
          let #(vxmls, rest_tags) =
            merge_split_list_with_inline_tags(blame, list, inline_tags)
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

fn split_chunk_children(children: List(VXML), extra) -> List(VXML) {
  case children {
    [] -> []
    [first, ..rest] -> {
      let #(flatten, inline_tags) = flatten_chunk_contents([first, ..rest], 0)
      let mapped_vxml =
        split_blamed_contents_by_delimiter(flatten, extra, 0)
        |> map_splits_to_vxml(first.blame, _, inline_tags, extra)

      mapped_vxml
    }
  }
}

pub fn split_delimiters_chunks_transform(
  node: VXML,
  _: List(VXML),
  extra: SplitDelimitersChunksExtraArgs,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> Ok([node])
    V(_, tag, _, children) -> {
      case tag == "VerticalChunk" {
        False -> Ok([node])
        True -> {
          children
          |> split_chunk_children(extra)
          |> Ok()
        }
      }
    }
  }
}

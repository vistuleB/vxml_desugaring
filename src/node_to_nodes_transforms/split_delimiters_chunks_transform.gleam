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

fn look_for_closing_delimiter(
  rest: List(BlamedContent),
  extra: SplitDelimitersChunksExtraArgs,
  output: List(BlamedContent),
) -> #(List(BlamedContent), List(BlamedContent)) {
  // return list of blamed contents inside delimiter and rest of blamed contents
  case rest {
    [] -> #([], [])
    [first, ..rest] -> {
      let cropped = string.crop(first.content, extra.close_delimiter)
      case cropped == first.content {
        True -> {
          let #(output, rest) = look_for_closing_delimiter(rest, extra, output)
          #([first, ..output], rest)
        }
        False -> {
          let before_closing_del =
            cropped |> string.length() |> string.drop_right(first.content, _)
          let after_closing_del =
            extra.close_delimiter
            |> string.length()
            |> string.drop_left(cropped, _)

          #(
            list.append(output, [
              BlamedContent(blame: first.blame, content: before_closing_del),
            ]),
            [BlamedContent(blame: first.blame, content: after_closing_del), ..rest],
          )
        }
      }
    }
  }
}

type Splits {
  DelimiterSurrounding(list: List(BlamedContent))
  DelimiterContent(list: List(BlamedContent))
}

fn split_blamed_contents_by_delimiter(
  contents: List(BlamedContent),
  extra: SplitDelimitersChunksExtraArgs,
) -> List(Splits) {
  case contents {
    [] -> []
    [first, ..rest] -> {
      let cropped = string.crop(first.content, extra.open_delimiter)
      case
        cropped == first.content,
        string.starts_with(first.content, extra.open_delimiter)
      {
        True, False -> {
          [DelimiterSurrounding([first]), ..split_blamed_contents_by_delimiter(rest, extra)]
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

          let #(delimiter_content, rest) =
            look_for_closing_delimiter(
              list.append([current_line_delimiter_content], rest),
              extra,
              [],
            )

          let after_delimiter_split =
            split_blamed_contents_by_delimiter(rest, extra)

          [DelimiterSurrounding([before_delimiter_split])]
          |> list.append([DelimiterContent(delimiter_content)])
          |> list.append(after_delimiter_split)
        }
      }
    }
  }
}

fn append_until_delimiter(
  blame: Blame,
  rest: List(Splits),
  extra: SplitDelimitersChunksExtraArgs,
  output: List(VXML),
) -> #(List(VXML), List(Splits)) {
  case rest {
    [] -> #(output, rest)
    [first, ..rest] -> {
      case first {
        DelimiterSurrounding(list) -> {
          let #(output, rest) =
            append_until_delimiter(blame, rest, extra, output)
          #(list.append(output, [T(blame, list)]), rest)
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
  extra: SplitDelimitersChunksExtraArgs,
) -> List(VXML) {
  case splits {
    [] -> []
    [first, ..rest] -> {
      case first {
        DelimiterSurrounding(list) -> {
          let #(output, rest) =
            append_until_delimiter(blame, rest, extra, [T(blame, list)])
          case output {
            [] -> []
            output -> {
              let normal_chunk = V(blame, "VerticalChunk", [], output)
              [normal_chunk, ..map_splits_to_vxml(blame, rest, extra)]
            }
          }
        }
        DelimiterContent(list) -> {
          let normal_chunk = V(blame, extra.tag_name, [], [T(blame, list)])
          [normal_chunk, ..map_splits_to_vxml(blame, rest, extra)]
        }
      }
    }
  }
}

fn flatten_chunk_contents(children) -> #(List(BlamedContent), List(VXML)) {
  case children {
    [] -> #([], [])
    [first, ..rest] -> {
      case first {
        V(_, _, _, _) -> #([], list.append([], rest))
        T(_, contents) -> {
          let #(res, rest) = flatten_chunk_contents(rest)
          #(list.append(contents, res), rest)
        }
      }
    }
  }
}

fn split_chunk_children(node: VXML, children: List(VXML), extra) -> List(VXML) {
  case children {
    [] -> []
    [first, ..rest] -> {
      case first {
        V(_, _, _, _) ->
          list.append([node], split_chunk_children(node, rest, extra))
        T(blame, _) -> {
          let #(flatten, rest) =
            flatten_chunk_contents([first, ..rest])

          split_blamed_contents_by_delimiter(flatten, extra)
          |> map_splits_to_vxml(blame, _, extra)
          |> list.append(split_chunk_children(node, rest, extra))
        }
      }
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
          |> split_chunk_children(node, _, extra)
          |> Ok()
        }
      }
    }
  }
}

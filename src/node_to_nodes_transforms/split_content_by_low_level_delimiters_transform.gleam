import gleam/option
import gleam/list
import gleam/string
import infrastructure.{type DesugaringError}
import vxml_parser.{
  type Blame, type BlamedContent, type VXML, BlamedContent, T, V,
}

type Delimiter {
  Delimiter(symbol: String, tag: String)
}

const delimiters = [ Delimiter("*", "b"), Delimiter("_", "i"), Delimiter("$", "Math") ]


fn look_for_closing_delimiter(str: String, delimiter: Delimiter) -> #(Bool, String, String) {
      let cropped = str |> string.crop(delimiter.symbol)
      case cropped == str {
        True -> #(False, "", str)
        False -> {
          let content = cropped |> string.length() |> string.drop_right(str, _)
          let rest_of_str = cropped |> string.drop_left(1)
          #(True, content, rest_of_str)
        }
      }
}

fn look_for_opening_delimiter(str: String, delimiters: List(Delimiter), dels_to_ignore: List(Delimiter)) -> #(option.Option(Delimiter), String) {
  let delimiters_to_search = delimiters |> list.filter(fn(d) { ! list.contains(dels_to_ignore, d) })
  case delimiters_to_search {
    [] -> #(option.None, str)
    [first, ..rest] -> {
      let cropped = str |> string.crop(first.symbol)
      case cropped == str, string.starts_with(str, first.symbol) {
        True, False -> look_for_opening_delimiter(str, rest, dels_to_ignore)
        _, _ -> {
          let rest_of_str = cropped |> string.drop_left(1)
          #(option.Some(first), rest_of_str)
        }
      }
    }
  }
}

fn append_until_delimiter(contents: List(BlamedContent), output: List(BlamedContent), dels_to_ignore: List(Delimiter)) -> #(List(BlamedContent), List(BlamedContent)) {
    case contents {
      [] -> #(output, [])
      [first, ..rest] -> {
        let #(del, _) = look_for_opening_delimiter(first.content, delimiters, dels_to_ignore)
        case del {
          option.None -> {
              let #(output, rest) = append_until_delimiter(rest, list.append(output, [first]), dels_to_ignore)
              #(output, rest)
            }
          option.Some(_) -> {
              #(output, [first, ..rest])
          }
        }
      }
    }
}

fn split_delimiters(blame: Blame, contents: List(BlamedContent), dels_to_ignore: List(Delimiter)) -> List(VXML) {

  case contents {
    [] -> []
    [first, ..rest] -> {

      let #(del, rest_of_str) = look_for_opening_delimiter(first.content, delimiters, dels_to_ignore)

      case del {
        option.None -> {
            let #(output, rest) = append_until_delimiter(rest, [first], dels_to_ignore) // get all lines that follows and do not have delimiter to be in same list 
            [T(first.blame, output), ..split_delimiters(blame, rest, dels_to_ignore)]
          }
        option.Some(del) -> {
            let #(found, del_content, rest_of_str) = look_for_closing_delimiter(rest_of_str, del)

            let blamed_line_for_rest_of_string = BlamedContent(first.blame, rest_of_str)

            let blamed_line_for_del_content = BlamedContent(first.blame, del_content)

            let new_element = V(first.blame, del.tag, [], [T(first.blame, [blamed_line_for_del_content])])

            case found, string.is_empty(rest_of_str) {
              False, True -> split_delimiters(blame, rest, [])
              False, False -> split_delimiters(blame, contents, [del, ..dels_to_ignore])
              True, True -> {
                  [new_element, ..split_delimiters(blame, rest, [del, ..dels_to_ignore])]
              }
              True, False -> {
                  [new_element, ..split_delimiters(blame, [blamed_line_for_rest_of_string, ..rest], [del, ..dels_to_ignore])]
              }
            }
        }
      }
    }
  }
}

pub fn split_content_by_low_level_delimiters_transform(node: VXML,
  _: List(VXML),
  _: Nil,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, _, _, _) -> Ok([node])
    T(blame, contents) -> {
        split_delimiters(blame, contents, [])
          |> Ok()
    }
  }
}
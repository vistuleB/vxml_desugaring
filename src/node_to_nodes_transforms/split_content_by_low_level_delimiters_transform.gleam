import gleam/int
import gleam/result
import gleam/option
import gleam/list
import gleam/string
import infrastructure.{type DesugaringError}
import vxml_parser.{
  type Blame, type BlamedContent, type VXML, BlamedContent, T, V,
}

type IgnoreWhen {
  IgnoreWhen(before: List(String), after: List(String))
}

type Delimiter {
  Delimiter(symbol: String, tag: String, can_nest: Bool, ignore_when: IgnoreWhen)
}

const delimiters = [
  Delimiter("*", "b", True, IgnoreWhen(
    before: ["(", "[", "{", "*", "\\"],
    after: [ ")", "]", "}", "*"]
   )),
  Delimiter("_", "i", True, IgnoreWhen(
    before: ["(", "[", "{", "\\"],
    after: [")", "]", "}"]
    )), 
  Delimiter("$", "Math", False, IgnoreWhen(["\\"], [])) 
]

fn look_for_closing_delimiter(str: String, delimiter: Delimiter) -> #(Bool, String, String) {
      let cropped = str |> string.crop(delimiter.symbol)
      let before_del_str = cropped |> string.length() |> string.drop_right(str, _)
      let rest_of_str = cropped |> string.drop_left(1)

      case cropped == str || is_escaped(delimiter, before_del_str, rest_of_str) {
        True -> #(False, "", str)
        False -> {
          let content = cropped |> string.length() |> string.drop_right(str, _)
          #(True, content, rest_of_str)
        }
      }
}

fn is_escaped(del: Delimiter, before_del_str: String, rest_str: String) -> Bool {
  case string.last(before_del_str), string.first(rest_str) {
    Ok(before), _ -> del.ignore_when.before |> list.contains(before)
    _, Ok(after) -> del.ignore_when.after |> list.contains(after)
    _, _ -> False
  }
}

fn look_for_opening_delimiter(str: String, dels_to_ignore: List(Delimiter)) -> #(option.Option(Delimiter), String, String) {
  let delimiters_to_search = delimiters |> list.filter(fn(d) { ! list.contains(dels_to_ignore, d) })

  // we need to find first delimiter in the string
  let cropped_all = delimiters_to_search |> list.map( fn(x) {
      #(str |> string.crop(x.symbol), x)
  })
  // cropped with least length is related to found delimiter
  
  case cropped_all 
      |> list.sort(fn(a, b) {  
          let #(len_a, _) = a
          let #(len_b, _) = b  
          int.compare(string.length(len_b), string.length(len_a))
        }) 
      |> list.first() {
        Ok(#(_, found_del)) -> {
          let cropped = str |> string.crop(found_del.symbol)
            case cropped == str, string.starts_with(str, found_del.symbol) {
              True, False -> look_for_opening_delimiter(str, [found_del, ..dels_to_ignore])
              _, _ -> {
                let rest_of_str = cropped |> string.drop_left(1)
                let before_del_str = cropped |> string.length() |> string.drop_right(str, _)

                case is_escaped(found_del, before_del_str, rest_of_str) {
                  True -> {

                    let #(next_found_del, next_before_del_str, rest_of_str) = look_for_opening_delimiter(rest_of_str, dels_to_ignore)

                    #(next_found_del, before_del_str <> found_del.symbol <> next_before_del_str, rest_of_str)
                  }
                  False -> #(option.Some(found_del), before_del_str, rest_of_str)
                }
              }
            }
        }
        Error(_) -> #(option.None, "", "")
      }
}

fn append_until_delimiter(contents: List(BlamedContent), output: List(BlamedContent), dels_to_ignore: List(Delimiter)) -> #(List(BlamedContent), List(BlamedContent)) {
    case contents {
      [] -> #(output, [])
      [first, ..rest] -> {
        let #(del, _, _) = look_for_opening_delimiter(first.content, dels_to_ignore)
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

fn split_delimiters(blame: Blame, contents: List(BlamedContent), dels_to_ignore: List(Delimiter)) -> Result(List(VXML), DesugaringError) {

  case contents {
    [] -> Ok([])
    [first, ..rest] -> {

      let #(del, before_del_str, rest_of_str) = look_for_opening_delimiter(first.content, dels_to_ignore)
      case del {
        option.None -> {
            let #(output, rest) = append_until_delimiter(rest, [first], dels_to_ignore) // get all lines that follows and do not have delimiter to be in same list 
            use rest <- result.try(split_delimiters(blame, rest, dels_to_ignore))
            Ok([T(first.blame, output), ..rest])
          }
        option.Some(del) -> {

            let #(found, del_content, rest_of_str) = look_for_closing_delimiter(rest_of_str, del)

            let blamed_line_for_string_before_delimiter = BlamedContent(first.blame, before_del_str)

            let blamed_line_for_rest_of_string = BlamedContent(first.blame, rest_of_str)

            let blamed_line_for_del_content = BlamedContent(first.blame, del_content)

            use nested_delimiters_vxml <- result.try(split_content_by_low_level_delimiters_transform(T(first.blame, [blamed_line_for_del_content]), [], Nil))
            
            let new_element = V(first.blame, del.tag, [], nested_delimiters_vxml)
            
            case found, string.is_empty(rest_of_str) {
              False, False -> split_delimiters(blame, contents, [del, ..dels_to_ignore])
              False, True -> {
                use rest <- result.try(split_delimiters(blame, rest, []))
                Ok([T(first.blame, [blamed_line_for_string_before_delimiter]), ..rest])
              }
              True, True -> {
                  use rest <- result.try(split_delimiters(blame, rest, dels_to_ignore))

                  case string.is_empty(before_del_str){
                      True -> Ok([new_element, ..rest])
                      False ->  Ok([T(first.blame, [blamed_line_for_string_before_delimiter]), new_element, ..rest])
                  } 
              }
              True, False -> {
                  use rest <- result.try(split_delimiters(blame, [blamed_line_for_rest_of_string, ..rest], dels_to_ignore))

                  case string.is_empty(before_del_str){
                      True -> Ok([new_element, ..rest])
                      False ->  Ok([T(first.blame, [blamed_line_for_string_before_delimiter]), new_element, ..rest])
                  }   
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
    }
  }
}
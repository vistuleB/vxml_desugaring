import blamedlines.{type Blame, Blame}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe, DesugarerDescription, DesugaringError,
}
import roman
import vxml_parser.{
  type BlamedAttribute, type BlamedContent, type VXML, BlamedAttribute,
  BlamedContent, T, V,
}

type CounterType {
  ArabicCounter
  RomanCounter
}

type CounterInstance {
  CounterInstance(
    counter_type: CounterType,
    name: String,
    current_value: String,
  )
}

type HandleInstance {
  HandleInstance(name: String, value: String)
}

fn check_counter_already_defined(
  new_counter_name: String,
  counters: List(CounterInstance),
  blame: Blame,
) -> Result(Nil, DesugaringError) {
  let existing_counter_names =
    counters
    |> list.map(fn(x) { x.name })

  case list.contains(existing_counter_names, new_counter_name) {
    True ->
      Error(DesugaringError(
        blame: blame,
        message: "Counter " <> new_counter_name <> " has already been used",
      ))
    False -> Ok(Nil)
  }
}

fn check_handle_already_defined(
  new_handle_name: String,
  handles: List(HandleInstance),
  blame: Blame,
) -> Result(Nil, DesugaringError) {
  let existing_handle_names =
    handles
    |> list.map(fn(x) { x.name })

  case list.contains(existing_handle_names, new_handle_name) {
    True ->
      Error(DesugaringError(
        blame: blame,
        message: "Handle " <> new_handle_name <> " has already been used",
      ))
    False -> Ok(Nil)
  }
}

fn get_counters_from_attributes(
  attributes: List(BlamedAttribute),
  counters: List(CounterInstance),
) -> Result(List(CounterInstance), DesugaringError) {
  case attributes {
    [] -> Ok([])
    [first, ..rest] -> {
      let att = case first.key {
        "counter" -> Some(CounterInstance(ArabicCounter, first.value, "0"))
        "roman_counter" -> Some(CounterInstance(RomanCounter, first.value, "."))
        _ -> None
      }

      case get_counters_from_attributes(rest, counters) {
        Ok(res) -> {
          use _ <- result.try(check_counter_already_defined(
            first.value,
            counters,
            first.blame,
          ))
          case att {
            Some(att) -> Ok([att, ..res])
            None -> Ok(res)
          }
        }
        Error(error) -> Error(error)
      }
    }
  }
}

fn mutate(
  blame: Blame,
  counter_type: CounterType,
  value: String,
  mutate_by: Int,
) -> Result(String, DesugaringError) {
  case counter_type {
    ArabicCounter -> {
      let assert Ok(int_val) = int.parse(value)
      case int_val + mutate_by < 0 {
        True ->
          Error(DesugaringError(
            blame,
            "Counter can't be decremented to less than 0",
          ))
        False -> Ok(string.inspect(int_val + mutate_by))
      }
    }
    RomanCounter -> {
      let int_value = case value {
        "." ->
          value
          |> roman.string_to_roman()
          |> option.unwrap([])
          |> roman.roman_to_int()
        _ -> 0
      }
      case int_value + mutate_by < 0 {
        True ->
          Error(DesugaringError(
            blame,
            "Counter can't be decremented to less than 0",
          ))
        False ->
          int_value
          |> int.add(mutate_by)
          |> roman.int_to_roman()
          |> option.unwrap([])
          |> roman.roman_to_string()
          |> Ok()
      }
    }
  }
}

fn update_counter(
  blame: Blame,
  counters: List(CounterInstance),
  counter_name: String,
  mutation: String,
) -> Result(List(CounterInstance), DesugaringError) {
  list.try_map(counters, fn(x) {
    case x.name == counter_name {
      True -> {
        case mutation {
          "++" -> {
            use new_value <- result.try(mutate(
              blame,
              x.counter_type,
              x.current_value,
              1,
            ))
            Ok(CounterInstance(..x, current_value: new_value))
          }
          "--" -> {
            use new_value <- result.try(mutate(
              blame,
              x.counter_type,
              x.current_value,
              -1,
            ))
            Ok(CounterInstance(..x, current_value: new_value))
          }
          _ -> Ok(x)
        }
      }
      False -> Ok(x)
    }
  })
}

fn assign_to_handles(
  blame: Blame,
  handles: List(HandleInstance),
  handle_names: Option(List(String)),
  value: String,
) -> Result(List(HandleInstance), DesugaringError) {
  case handle_names {
    None -> Ok(handles)
    Some(handle_names) -> {
      use _ <- result.try(
        list.try_each(handle_names, fn(handle_name) {
          check_handle_already_defined(handle_name, handles, blame)
        }),
      )
      let handles =
        list.scan(handle_names, handles, fn(acc, handle_name) {
          list.flatten([acc, [HandleInstance(handle_name, value)]])
        })
        |> list.last()
        |> result.unwrap([])

      Ok(handles)
    }
  }
}

fn handles_as_attributes(
  blame: Blame,
  node: VXML,
  handle_names: Option(List(String)),
  value: String,
) -> VXML {
  case handle_names {
    Some(names) -> {
      let attributes =
        names
        |> list.map(fn(name) {
          BlamedAttribute(blame, "handle_" <> name, value)
        })

      let assert V(b, t, a, c) = node
      V(b, t, list.flatten([a, attributes]), c)
    }
    None -> node
  }
}

fn get_all_handles_from_match_content(match_content: String) -> List(String) {
  let assert [_, ..rest] = string.split(match_content, "<<") |> list.reverse()
  list.reverse(rest)
}

fn split_expressions(
  splits: List(String),
) -> List(#(String, String, String, Option(String))) {
  case splits {
    [] -> []
    splits -> {
      let assert [_, insert_or_not, mutation, counter_name, ..rest] = splits

      let #(split_char, rest) = case list.length(rest) > 1 {
        True -> {
          let assert [split_char, ..rest_rest] = rest
          #(option.Some(split_char), ["", ..rest_rest])
        }
        False -> #(option.None, [])
      }

      [
        #(insert_or_not, mutation, counter_name, split_char),
        ..split_expressions(rest)
      ]
    }
  }
}

fn get_all_counters_from_match_content(
  match_content: String,
  // insert or not
  // mutation
  // counter name
  // splits character
) -> List(#(String, String, String, Option(String))) {
  let assert [last, ..] = string.split(match_content, "<<") |> list.reverse()
  let assert Ok(re) = regexp.from_string("(::|\\.\\.)(::|\\+\\+|--)(\\w+)")
  let splits = regexp.split(re, last)
  split_expressions(splits)
}

fn handle_counter_expressions(
  blame: Blame,
  expressions: List(#(String, String, String, Option(String))),
  counters: List(CounterInstance),
  // ignores insert_or_not  outout that 
  // to be used as          will be put 
  // value fo handles       in the result
  //           |          /
  //           |         /
  //           |        /
) -> Result(#(String, String, List(CounterInstance)), DesugaringError) {
  case expressions {
    [] -> Ok(#("", "", counters))
    [#(insert_or_not, mutation, counter_name, split_char), ..rest] -> {
      case
        list.find(counters, fn(x: CounterInstance) { x.name == counter_name })
      {
        Ok(_) -> {
          // update counter
          use updated_counters <- result.try(update_counter(
            blame,
            counters,
            counter_name,
            mutation,
          ))
          let assert Ok(updated_instance) =
            list.find(updated_counters, fn(x: CounterInstance) {
              x.name == counter_name
            })

          use #(rest_handles_value, rest_string_output, updated_counters) <- result.try(
            handle_counter_expressions(blame, rest, updated_counters),
          )

          let split_char = case split_char {
            Some(s) -> s
            None -> ""
          }

          case insert_or_not == "::" {
            True -> {
              Ok(#(
                updated_instance.current_value
                  <> split_char
                  <> rest_handles_value,
                updated_instance.current_value <> rest_string_output,
                updated_counters,
              ))
            }
            False ->
              Ok(#(
                updated_instance.current_value
                  <> split_char
                  <> rest_handles_value,
                rest_string_output,
                counters,
              ))
          }
        }
        Error(_) ->
          Error(DesugaringError(
            blame,
            "Counter " <> counter_name <> " is not defined",
          ))
      }
    }
  }
}

fn construct_span(blame: Blame, value: String) {
  // let #(id, filename, value) = handle
  V(blame, "span", [], [T(blame, [BlamedContent(blame, value)])])
}

fn handle_matches(
  blame: Blame,
  matches: List(regexp.Match),
  splits: List(String),
  counters: List(CounterInstance),
) -> Result(#(List(VXML), List(CounterInstance)), DesugaringError) {
  case matches {
    [] -> {
      case splits {
        [] -> Ok(#([], counters))
        _ ->
          Ok(#(
            [T(blame, [BlamedContent(blame, string.join(splits, " "))])],
            counters,
          ))
      }
    }
    [first, ..rest] -> {
      let regexp.Match(content, sub_matches) = first
      // we need to get all counter expressions from content
      let assert [_, handle_name, ..] = sub_matches

      let counter_expressions = get_all_counters_from_match_content(content)

      use #(handles_value, expressions_output, updated_counters) <- result.try(
        handle_counter_expressions(blame, counter_expressions, counters),
      )

      let handle_names = case handle_name {
        None -> None
        Some(_) -> Some(get_all_handles_from_match_content(content))
      }

      let span =
        construct_span(blame, expressions_output)
        |> handles_as_attributes(blame, _, handle_names, handles_value)

      let assert [first_split, _, _, _, _, _, _, _, _, _, _, _, ..rest_splits] =
        splits
      use #(rest_output, updated_counters) <- result.try(handle_matches(
        blame,
        rest,
        rest_splits,
        updated_counters,
      ))

      let t = case string.is_empty(first_split) {
        True -> []
        False -> [T(blame, [BlamedContent(blame, first_split)])]
      }
      Ok(#(list.flatten([t, [span], rest_output]), updated_counters))
      // let #(insert_or_not, mutation, counter_name) = exp
    }
  }
}

fn counter_regex(
  blame: Blame,
  content: String,
  counters: List(CounterInstance),
) -> Result(#(List(VXML), List(CounterInstance)), DesugaringError) {
  // examples 

  // 1) one handle | one counter
  // ---------------------------

  // "more handle<<::::MyCounter more" will result in
  // sub-matches of first match :
  //   [Some("handle<<"), Some("handle"), Some("<<"), Some("::"), Some("::"), Some   ("MyCounter")]
  // splits:
  //   ["more ", "handle<<", "handle", "<<", "::", "::", "MyCounter", " more"]

  // 2) multiple handles | one counter
  // ---------------------------------

  // "more handle1<<handle2<<::::MyCounter more" will result in
  // content of first match : (only diff between first case) 
  //    \"handle2<<handle1<<::::Counter\"
  // sub-matches of first match :
  //   [Some("handle2<<"), Some("handle2"), Some("<<"), Some("::"), Some("::"), Some   ("MyCounter")]
  // splits:
  //   ["more ", "handle2<<", "handle2", "<<", "::", "::", "MyCounter", " more"]

  // 3) 0 handles | one counter
  // --------------------------

  // "more ::::MyCounter more" will result in
  // sub-matches of first match :
  //   [None, None, None, Some("::"), Some("::"), Some   ("MyCounter")]
  // splits:
  //   ["more ", "", "", "", "::", "::", "MyCounter", " more"]

  // 4) x handle | multiple counters + random text
  // ---------------------------------------------

  // "more handle<<::::MyCounter-::--HisCounter more" will result in
  // ** content of first match: handle<<::::MyCounter-::--HisCounter

  // sub-matches of first match :
  //   [Some("handle<<"), Some("handle"), Some("<<"), Some("::"), Some("::"), Some("MyCounter"), Some("-::++HisCounter"), Some("-"), Some("::"), Some("++"), Some("HisCounter")]

  // splits:
  //   ["", "handle<<", "handle", "<<", "::", "::", "MyCounter", "-::++HisCounter", "-", "::", "++", "HisCounter", " more"]

  // if there are multiple appearances of last regex part - only last one will be in splits and matches . so we need to use match content to get all of them

  let assert Ok(re) =
    regexp.from_string(
      "((\\w+)(<<))*(::|\\.\\.)(::|\\+\\+|--)(\\w+)((-|_|.|:|;|::|,)(::|\\.\\.)(::|\\+\\+|--)(\\w+))*",
    )

  let matches = regexp.scan(re, content)

  let splits = regexp.split(re, content)

  handle_matches(blame, matches, splits, counters)
}

fn update_contents(
  blame: Blame,
  contents: List(BlamedContent),
  counters: List(CounterInstance),
) -> Result(#(List(VXML), List(CounterInstance)), DesugaringError) {
  case contents {
    [] -> Ok(#([T(blame, contents)], counters))
    [first, ..rest] -> {
      use #(updated_content, updated_counters) <- result.try(counter_regex(
        first.blame,
        first.content,
        counters,
      ))
      use #(rest_content, updated_counters) <- result.try(update_contents(
        blame,
        rest,
        updated_counters,
      ))

      Ok(#(list.flatten([updated_content, rest_content]), updated_counters))
    }
  }
}

fn take_existing_counters(
  current: List(CounterInstance),
  new: List(CounterInstance),
) -> List(CounterInstance) {
  let current_names = current |> list.map(fn(x) { x.name })
  new
  |> list.filter(fn(x) { current_names |> list.contains(x.name) })
}

fn transform_children_recursive(
  children: List(VXML),
  counters: List(CounterInstance),
) -> Result(#(List(VXML), List(CounterInstance)), DesugaringError) {
  case children {
    [] -> Ok(#([], counters))
    [first, ..rest] -> {
      use #(updated_first, updated_counters) <- result.try(counter_transform(
        first,
        counters,
      ))
      // next children will not have counters that were added by nested children ( because of take_existing_counter)
      // handles will have them
      use #(updated_rest, updated_counters) <- result.try(
        transform_children_recursive(rest, updated_counters),
      )
      Ok(#(list.flatten([updated_first, updated_rest]), updated_counters))
    }
  }
}

fn counter_transform(
  vxml: VXML,
  counters: List(CounterInstance),
) -> Result(#(List(VXML), List(CounterInstance)), DesugaringError) {
  case vxml {
    V(b, t, attributes, children) -> {
      use new_counters <- result.try(
        attributes
        |> get_counters_from_attributes(counters),
      )
      use #(updated_children, updated_counters) <- result.try(
        transform_children_recursive(
          children,
          list.append(counters, new_counters),
        ),
      )
      // let handles_as_attributs = convert_handles_to_attributes(updated_handles)

      Ok(#(
        [V(b, t, attributes, updated_children)],
        take_existing_counters(counters, updated_counters),
      ))
    }
    T(b, contents) -> {
      use #(updated_contents, updated_counters) <- result.try(update_contents(
        b,
        contents,
        counters,
      ))
      Ok(#(updated_contents, updated_counters))
    }
  }
}

pub fn counter_desugarer() -> Pipe {
  #(DesugarerDescription("Counter", None, "..."), fn(vxml) {
    use #(vxml, _) <- result.try(counter_transform(vxml, []))
    let assert [vxml] = vxml
    Ok(vxml)
  })
}

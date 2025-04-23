import blamedlines.{type Blame, Blame}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe,
}
import roman
import vxml.{
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
    step: Float,
  )
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

fn parse_value(
  blame: Blame,
  value: String,
  message: String,
) -> Result(Float, DesugaringError) {
  case int.parse(value) {
    Ok(i) -> Ok(int.to_float(i))
    Error(_) -> {
      case float.parse(value) {
        Ok(f) -> Ok(f)
        Error(_) -> Error(DesugaringError(blame, message))
      }
    }
  }
}

fn handle_att_value(
  blame: Blame,
  value: String,
) -> Result(#(String, Option(String), Option(Float)), DesugaringError) {
  let splits = string.split(value, " ")
  case splits {
    [counter_name, default_value, step] -> {
      use _ <- result.try(parse_value(
        blame,
        default_value,
        "Default value for counter " <> counter_name <> " must be a number",
      ))
      use step <- result.try(parse_value(
        blame,
        step,
        "Step for counter " <> counter_name <> " must be a number",
      ))

      Ok(#(counter_name, Some(default_value), Some(step)))
    }
    [counter_name, default_value] -> {
      use _ <- result.try(parse_value(
        blame,
        default_value,
        "Default value for counter " <> counter_name <> " must be a number",
      ))

      Ok(#(counter_name, Some(default_value), None))
    }
    [counter_name] -> Ok(#(counter_name, None, None))
    _ -> Error(DesugaringError(blame, "Counter attribute must have a name"))
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
        "counter" -> {
          use #(counter_name, default_value, step) <- result.try(
            handle_att_value(first.blame, first.value),
          )

          Ok(
            Some(CounterInstance(
              ArabicCounter,
              counter_name,
              option.unwrap(default_value, "0"),
              option.unwrap(step, 1.0),
            )),
          )
        }
        "roman_counter" -> {
          use #(counter_name, default_value, step) <- result.try(
            handle_att_value(first.blame, first.value),
          )
          Ok(
            Some(CounterInstance(
              RomanCounter,
              counter_name,
              option.unwrap(default_value, "."),
              option.unwrap(step, 1.0),
            )),
          )
        }
        _ -> Ok(None)
      }
      use att <- result.try(att)

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
  mutate_by: Float,
) -> Result(String, DesugaringError) {
  case counter_type {
    ArabicCounter -> {
      let assert Ok(float_val) = parse_value(blame, value, "")

      let sum = float.sum([float_val, mutate_by]) |> float.to_precision(2)
      case sum <. 0.0 {
        True ->
          Error(DesugaringError(
            blame,
            "Counter can't be decremented to less than 0",
          ))
        False -> {
          case float.ceiling(sum) == sum {
            // remove trailing zero
            True -> Ok(string.inspect(float.round(sum)))
            False -> Ok(string.inspect(sum))
          }
        }
      }
    }
    RomanCounter -> {
      let assert Ok(mutate_by) = mutate_by |> string.inspect() |> int.parse()

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
              x.step,
            ))
            Ok(CounterInstance(..x, current_value: new_value))
          }
          "--" -> {
            use new_value <- result.try(mutate(
              blame,
              x.counter_type,
              x.current_value,
              x.step *. -1.0,
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
                updated_instance.current_value
                  <> split_char
                  <> rest_string_output,
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

fn handle_matches(
  blame: Blame,
  matches: List(regexp.Match),
  splits: List(String),
  counters: List(CounterInstance),
  parent: VXML,
) -> Result(#(String, VXML, List(CounterInstance)), DesugaringError) {
  case matches {
    [] -> {
      Ok(#(string.join(splits, ""), parent, counters))
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

      let updated_parent =
        handles_as_attributes(blame, parent, handle_names, handles_value)

      let assert [first_split, _, _, _, _, _, _, _, _, _, _, _, ..rest_splits] =
        splits
      use #(rest_output, updated_parent, updated_counters) <- result.try(
        handle_matches(
          blame,
          rest,
          rest_splits,
          updated_counters,
          updated_parent,
        ),
      )

      Ok(#(
        first_split <> expressions_output <> rest_output,
        updated_parent,
        updated_counters,
      ))
      // let #(insert_or_not, mutation, counter_name) = exp
    }
  }
}

fn counter_regex(
  blame: Blame,
  content: String,
  counters: List(CounterInstance),
  parent: VXML,
) -> Result(#(String, VXML, List(CounterInstance)), DesugaringError) {
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

  handle_matches(blame, matches, splits, counters, parent)
}

fn update_contents(
  contents: List(BlamedContent),
  counters: List(CounterInstance),
  parent: VXML,
) -> Result(
  #(List(BlamedContent), VXML, List(CounterInstance)),
  DesugaringError,
) {
  case contents {
    [] -> Ok(#(contents, parent, counters))
    [first, ..rest] -> {
      use #(updated_content, updated_parent, updated_counters) <- result.try(
        counter_regex(first.blame, first.content, counters, parent),
      )
      use #(rest_content, updated_parent, updated_counters) <- result.try(
        update_contents(rest, updated_counters, updated_parent),
      )

      Ok(#(
        [BlamedContent(first.blame, updated_content), ..rest_content],
        updated_parent,
        updated_counters,
      ))
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
  parent: Option(VXML),
  children: List(VXML),
  counters: List(CounterInstance),
) -> Result(#(List(VXML), Option(VXML), List(CounterInstance)), DesugaringError) {
  case children {
    [] -> Ok(#([], parent, counters))
    [first, ..rest] -> {
      use #(updated_first, updated_parent, updated_counters) <- result.try(
        counter_transform(first, parent, counters),
      )
      // next children will not have counters that were added by nested children ( because of take_existing_counter)
      // handles will have them
      use #(updated_rest, updated_parent, updated_counters) <- result.try(
        transform_children_recursive(updated_parent, rest, updated_counters),
      )
      Ok(#([updated_first, ..updated_rest], updated_parent, updated_counters))
    }
  }
}

fn counter_transform(
  vxml: VXML,
  parent: Option(VXML),
  counters: List(CounterInstance),
) -> Result(#(VXML, Option(VXML), List(CounterInstance)), DesugaringError) {
  case vxml {
    V(b, t, attributes, children) -> {
      use new_counters <- result.try(
        attributes
        |> get_counters_from_attributes(counters),
      )
      use #(updated_children, updated_parent, updated_counters) <- result.try(
        transform_children_recursive(
          Some(vxml),
          children,
          list.append(counters, new_counters),
        ),
      )

      let updated_attributes = case updated_parent {
        Some(V(_, _, a, _)) -> a
        _ -> attributes
      }

      Ok(#(
        V(b, t, updated_attributes, updated_children),
        parent,
        take_existing_counters(counters, updated_counters),
      ))
    }
    T(b, contents) -> {
      let assert Some(parent) = parent
      use #(updated_contents, updated_parent, updated_counters) <- result.try(
        update_contents(contents, counters, parent),
      )
      Ok(#(T(b, updated_contents), Some(updated_parent), updated_counters))
    }
  }
}

/// Used for subsituting counters by their numerical
/// value, converted to a string, and assiging those
/// values to prefixed handles.
/// 
/// If a counter named 'MyCounterName' is defined by
/// ancestor, replaces strings of the form
/// 
/// <aa><bb>MyCounterName
/// 
/// where 
/// 
/// <aa> == \"::\"|\"..\" indicates whether
/// the counter occurrence should be echoed as a
/// string appearing in the document or not (\"::\" == echo,
/// \"..\" == suppress), and where
/// 
/// <bb> ==  \"++\"|\"--\"|\"::\" indicates whether
/// the counter should be incremented, decremented, or
/// neither prior to possible insertion,
/// 
/// by the appropriate replacement string (possibly
/// none), and assigns handles coming to the left
/// using the '<<' assignment, e.g.,
/// 
/// handleName<<..++MyCounterName
/// 
/// would assign the stringified incremented value
/// of MyCounterName to handle 'handleName' without
/// echoing the value to the document, whereas
/// 
/// handleName<<::++MyCounterName
/// 
/// will do the same but also insert the new counter 
/// value at that point in the document.
/// 
/// The computed handle assignments are not directly
/// used by this desugarer, but are stored inside as
/// attributes on the parent tag to be later used by
/// these desugarers.
/// 
/// -- handles_generate_dictionary
/// -- handles_generate_ids
/// -- handles_substitute
pub fn counters_substitute_and_assign_handles() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "counters_substitute_and_assign_handles",
      None,
      "
Used for subsituting counters by their numerical
value, converted to a string, and assiging those
values to prefixed handles.

If a counter named 'MyCounterName' is defined by
ancestor, replaces strings of the form

<aa><bb>MyCounterName

where 

<aa> == \"::\"|\"..\" indicates whether
the counter occurrence should be echoed as a
string appearing in the document or not (\"::\" == echo,
\"..\" == suppress), and where

<bb> ==  \"++\"|\"--\"|\"::\" indicates whether
the counter should be incremented, decremented, or
neither prior to possible insertion,

by the appropriate replacement string (possibly
none), and assigns handles coming to the left
using the '<<' assignment, e.g.,

handleName<<..++MyCounterName

would assign the stringified incremented value
of MyCounterName to handle 'handleName' without
echoing the value to the document, whereas

handleName<<::++MyCounterName

will do the same but also insert the new counter 
value at that point in the document.

The computed handle assignments are not directly
used by this desugarer, but are stored inside as
attributes on the parent tag to be later used by
these desugarers.

-- handles_generate_dictionary
-- handles_generate_ids
-- handles_substitute",
    ),
    desugarer: fn(vxml) {
      use #(vxml, _, _) <- result.try(counter_transform(vxml, None, []))
      Ok(vxml)
    },
  )
}

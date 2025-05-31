import blamedlines.{type Blame}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type Regexp}
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe}
import infrastructure as infra
import roman
import vxml.{type BlamedAttribute, type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V}

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

type HandleAssignment =
  #(String, String)

type StringAndRegexVersion {
  StringAndRegexVersion(string: String, regex_string: String)
}

const loud = StringAndRegexVersion(string: "::", regex_string: "::")
const soft = StringAndRegexVersion(string: "..", regex_string: "\\.\\.")
const increment = StringAndRegexVersion(string: "++", regex_string: "\\+\\+")
const decrement = StringAndRegexVersion(string: "--", regex_string: "--")
const no_change = StringAndRegexVersion(string: "øø", regex_string: "øø")

fn mutate(
  counter_type: CounterType,
  value: String,
  mutate_by: Float,
) -> Result(String, String) {
  case counter_type {
    ArabicCounter -> {
      let assert Ok(float_val) = parse_value(value, "")

      let sum = float.sum([float_val, mutate_by]) |> float.to_precision(2)
      case sum <. 0.0 {
        True -> Error("Counter can't be decremented to less than 0")
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
        True -> Error("Counter can't be decremented to less than 0")
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
  counters: List(CounterInstance),
  counter_name: String,
  mutation: String,
) -> Result(List(CounterInstance), String) {
  list.try_map(counters, fn(x) {
    case x.name == counter_name {
      True -> {
        case mutation {
          _ if mutation == increment.string -> {
            use new_value <- result.try(mutate(
              x.counter_type,
              x.current_value,
              x.step,
            ))
            Ok(CounterInstance(..x, current_value: new_value))
          }
          _ if mutation == decrement.string -> {
            use new_value <- result.try(mutate(
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
  regexes: #(Regexp, Regexp),
) -> List(#(String, String, String, Option(String))) {
  let assert [last, ..] = string.split(match_content, "<<") |> list.reverse()
  let #(re, _) = regexes
  let splits = regexp.split(re, last)
  split_expressions(splits)
}

fn handle_counter_expressions(
  expressions: List(#(String, String, String, Option(String))),
  counters: List(CounterInstance),
  // ignores insert_or_not  outout that
  // to be used as          will be put
  // value fo handles       in the result
  //           |          /
  //           |         /
  //           |        /
) -> Result(#(String, String, List(CounterInstance)), String) {
  case expressions {
    [] -> Ok(#("", "", counters))
    [#(insert_or_not, mutation, counter_name, split_char), ..rest] -> {
      case
        list.find(counters, fn(x: CounterInstance) { x.name == counter_name })
      {
        Ok(_) -> {
          // update counter
          use updated_counters <- result.try(update_counter(
            counters,
            counter_name,
            mutation,
          ))
          let assert Ok(updated_instance) =
            list.find(updated_counters, fn(x: CounterInstance) {
              x.name == counter_name
            })

          use #(rest_handles_value, rest_string_output, updated_counters) <- result.try(
            handle_counter_expressions(rest, updated_counters),
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
        Error(_) -> Error("Counter " <> counter_name <> " is not defined")
      }
    }
  }
}

fn handle_matches(
  matches: List(regexp.Match),
  splits: List(String),
  counters: List(CounterInstance),
  regexes: #(Regexp, Regexp),
) -> Result(#(String, List(CounterInstance), List(HandleAssignment)), String) {
  case matches {
    [] -> {
      Ok(#(string.join(splits, ""), counters, []))
    }
    [first, ..rest] -> {
      let regexp.Match(content, sub_matches) = first
      let assert [_, handle_name, ..] = sub_matches
      let counter_expressions =
        get_all_counters_from_match_content(content, regexes)

      use #(handles_value, expressions_output, updated_counters) <- result.try(
        handle_counter_expressions(counter_expressions, counters),
      )

      let handle_names = case handle_name {
        None -> None
        Some(_) -> Some(get_all_handles_from_match_content(content))
      }

      let handle_assignments = case handle_names {
        None -> []
        Some(names) -> names |> list.map(fn(x) { #(x, handles_value) })
      }

      let assert [first_split, _, _, _, _, _, _, _, _, _, _, _, ..rest_splits] =
        splits

      use #(rest_output, updated_counters, rest_handle_assignments) <- result.try(
        handle_matches(rest, rest_splits, updated_counters, regexes),
      )

      Ok(#(
        first_split <> expressions_output <> rest_output,
        updated_counters,
        list.flatten([handle_assignments, rest_handle_assignments]),
      ))
    }
  }
}

fn substitute_counters_and_generate_handle_assignments(
  content: String,
  counters: List(CounterInstance),
  regexes: #(Regexp, Regexp),
  // MySpecialCounterRegexErrorTypeNotADesugaringErrorYet
) -> Result(#(String, List(CounterInstance), List(HandleAssignment)), String) {
  // examples

  // 1) one handle | one counter
  // ---------------------------

  // "more handle<<::++MyCounter more" will result in
  // sub-matches of first match :
  //   [Some("handle<<"), Some("handle"), Some("<<"), Some("::"), Some("++"), Some   ("MyCounter")]
  // splits:
  //   ["more ", "handle<<", "handle", "<<", "::", "++", "MyCounter", " more"]

  // 2) multiple handles | one counter
  // ---------------------------------

  // "more handle1<<handle2<<::++MyCounter more" will result in
  // content of first match : (only diff between first case)
  //    \"handle2<<handle1<<::++Counter\"
  // sub-matches of first match :
  //   [Some("handle2<<"), Some("handle2"), Some("<<"), Some("::"), Some("++"), Some   ("MyCounter")]
  // splits:
  //   ["more ", "handle2<<", "handle2", "<<", "::", "++", "MyCounter", " more"]

  // 3) 0 handles | one counter
  // --------------------------

  // "more ::++MyCounter more" will result in
  // sub-matches of first match :
  //   [None, None, None, Some("::"), Some("++"), Some   ("MyCounter")]
  // splits:
  //   ["more ", "", "", "", "::", "++", "MyCounter", " more"]

  // 4) x handle | multiple counters + random text
  // ---------------------------------------------

  // "more handle<<::++MyCounter-::--HisCounter more" will result in
  // ** content of first match: handle<<::++MyCounter-::--HisCounter

  // sub-matches of first match :
  //   [Some("handle<<"), Some("handle"), Some("<<"), Some("::"), Some("++"), Some("MyCounter"), Some("-::--HisCounter"), Some("-"), Some("::"), Some("--"), Some("HisCounter")]

  // splits:
  //   ["", "handle<<", "handle", "<<", "::", "++", "MyCounter", "-::--HisCounter", "-", "::", "--", "HisCounter", " more"]

  // if there are multiple appearances of last regex part - only last one will be in splits and matches . so we need to use match content to get all of them

  let #(_, re) = regexes
  let matches = regexp.scan(re, content)
  let splits = regexp.split(re, content)
  handle_matches(matches, splits, counters, regexes)
}

fn update_blamed_content(
  bl: BlamedContent,
  counters: List(CounterInstance),
  regexes: #(Regexp, Regexp),
) -> Result(
  #(BlamedContent, List(CounterInstance), List(HandleAssignment)),
  DesugaringError,
) {
  case
    substitute_counters_and_generate_handle_assignments(
      bl.content,
      counters,
      regexes,
    )
  {
    Ok(#(updated_content, counters, handles)) -> {
      Ok(#(BlamedContent(bl.blame, updated_content), counters, handles))
    }
    Error(e) -> Error(DesugaringError(bl.blame, e))
  }
}

fn update_blamed_contents(
  contents: List(BlamedContent),
  counters: List(CounterInstance),
  regexes: #(Regexp, Regexp),
) -> Result(
  #(List(BlamedContent), List(CounterInstance), List(HandleAssignment)),
  DesugaringError,
) {
  let init_acc = #([], counters, [])

  contents
  |> list.try_fold(init_acc, fn(acc, content) {
    let #(old_contents, counters, handles) = acc
    use #(updated_content, updated_counters, new_handles) <- result.try(
      update_blamed_content(content, counters, regexes),
    )
    Ok(#(
      list.append(old_contents, [updated_content]),
      updated_counters,
      list.flatten([handles, new_handles]),
    ))
  })
}

fn handle_assignment_blamed_attributes_from_handle_assignments(
  handles: List(HandleAssignment),
) -> List(BlamedAttribute) {
  handles
  |> list.map(fn(handle) {
    let #(name, value) = handle
    BlamedAttribute(infra.blame_us("..."), "handle", name <> " " <> value)
  })
}

fn take_existing_counters(
  current: List(CounterInstance),
  new: List(CounterInstance),
) -> List(CounterInstance) {
  let current_names = current |> list.map(fn(x) { x.name })
  new |> list.filter(fn(x) { current_names |> list.contains(x.name) })
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

fn parse_value(value: String, message: String) -> Result(Float, DesugaringError) {
  case int.parse(value) {
    Ok(i) -> Ok(int.to_float(i))
    Error(_) -> {
      case float.parse(value) {
        Ok(f) -> Ok(f)
        Error(_) -> Error(DesugaringError(infra.blame_us("..."), message))
      }
    }
  }
}

fn handle_att_value(
  value: String,
) -> Result(#(String, Option(String), Option(Float)), DesugaringError) {
  let splits = string.split(value, " ")
  case splits {
    [counter_name, default_value, step] -> {
      use _ <- result.try(parse_value(
        default_value,
        "Default value for counter " <> counter_name <> " must be a number",
      ))
      use step <- result.try(parse_value(
        step,
        "Step for counter " <> counter_name <> " must be a number",
      ))

      Ok(#(counter_name, Some(default_value), Some(step)))
    }
    [counter_name, default_value] -> {
      use _ <- result.try(parse_value(
        default_value,
        "Default value for counter " <> counter_name <> " must be a number",
      ))

      Ok(#(counter_name, Some(default_value), None))
    }
    [counter_name] -> Ok(#(counter_name, None, None))
    _ ->
      Error(DesugaringError(
        infra.blame_us("..."),
        "Counter attribute must have a name",
      ))
  }
}

fn get_counters_from_attributes(
  attribute: BlamedAttribute,
  counters: List(CounterInstance),
) -> Result(List(CounterInstance), DesugaringError) {
  case attribute.key {
    "counter" -> {
      use #(counter_name, default_value, step) <- result.try(handle_att_value(
        attribute.value,
      ))
      use _ <- result.try(check_counter_already_defined(
        counter_name,
        counters,
        attribute.blame,
      ))
      Ok([
        CounterInstance(
          ArabicCounter,
          counter_name,
          option.unwrap(default_value, "0"),
          option.unwrap(step, 1.0),
        ),
      ])
    }
    "roman_counter" -> {
      use #(counter_name, default_value, step) <- result.try(handle_att_value(
        attribute.value,
      ))
      use _ <- result.try(check_counter_already_defined(
        counter_name,
        counters,
        attribute.blame,
      ))
      Ok([
        CounterInstance(
          RomanCounter,
          counter_name,
          option.unwrap(default_value, "."),
          option.unwrap(step, 1.0),
        ),
      ])
    }
    _ -> Ok([])
  }
}

fn fancy_one_attribute_processor(
  to_process: BlamedAttribute,
  counters: List(CounterInstance),
  regexes: #(Regexp, Regexp),
) -> Result(
  #(BlamedAttribute, List(CounterInstance), List(HandleAssignment)),
  DesugaringError,
) {
  use #(key, counters, assignments1) <- result.then(
    result.map_error(
      substitute_counters_and_generate_handle_assignments(
        to_process.key,
        counters,
        regexes,
      ),
      fn(e) { DesugaringError(blame: to_process.blame, message: e) },
    ),
  )

  let assert True = key == string.trim(key)

  use <- infra.on_true_on_false(
    key == "",
    Error(DesugaringError(
      to_process.blame,
      "empty key after processing counters; original key: '"
        <> to_process.key
        <> "'",
    )),
  )

  use #(value, counters, assignments2) <- result.then(
    result.map_error(
      substitute_counters_and_generate_handle_assignments(
        to_process.value,
        counters,
        regexes,
      ),
      fn(e) { DesugaringError(blame: to_process.blame, message: e) },
    ),
  )

  Ok(#(
    BlamedAttribute(to_process.blame, key, value),
    counters,
    list.flatten([assignments1, assignments2]),
  ))
}

fn fancy_attribute_processor(
  already_processed: List(BlamedAttribute),
  yet_to_be_processed: List(BlamedAttribute),
  counters: List(CounterInstance),
  regexes: #(Regexp, Regexp),
) -> Result(#(List(BlamedAttribute), List(CounterInstance)), DesugaringError) {
  case yet_to_be_processed {
    [] -> Ok(#(already_processed |> list.reverse, counters))

    [next, ..rest] -> {
      use #(next, counters, assignments) <- result.then(
        fancy_one_attribute_processor(next, counters, regexes),
      )

      let assignment_attributes =
        list.map(assignments, fn(handle_assignment) {
          let #(handle_name, handle_value) = handle_assignment
          BlamedAttribute(
            next.blame,
            "handle",
            handle_name <> " " <> handle_value,
          )
        })

      use new_counter <- result.then(get_counters_from_attributes(
        next,
        counters,
      ))

      let already_processed =
        list.flatten([
          assignment_attributes |> list.reverse,
          // try to keep order of assignments same as order they occur in source
          [next],
          already_processed,
        ])

      fancy_attribute_processor(
        already_processed,
        rest,
        list.flatten([new_counter, counters]),
        regexes,
      )
    }
  }
}

fn v_before_transforming_children(
  vxml: VXML,
  state: State,
  regexes: #(Regexp, Regexp),
) -> Result(#(VXML, State), DesugaringError) {
  let assert V(b, t, attributes, c) = vxml
  let #(counters, handles) = state

  use #(attributes, counters) <- result.then(fancy_attribute_processor(
    [],
    list.reverse(attributes),
    counters,
    regexes,
  ))

  Ok(#(V(b, t, attributes, c), #(counters, handles)))
}

fn t_transform(
  vxml: VXML,
  state: State,
  regexes: #(Regexp, Regexp),
) -> Result(#(VXML, State), DesugaringError) {
  let assert T(blame, contents) = vxml
  let #(counters, old_handles) = state

  use #(contents, updated_counters, new_handles) <- result.then(
    update_blamed_contents(contents, counters, regexes),
  )

  use <- infra.on_some_on_none(
    infra.get_contained(new_handles, old_handles),
    fn(old_handle) {
      Error(DesugaringError(
        blame,
        "found previously-defined handle: " <> ins(old_handle),
      ))
    },
  )

  Ok(
    #(T(blame, contents), #(
      updated_counters,
      list.flatten([old_handles, new_handles]),
    )),
  )
}

fn v_after_transforming_children(
  vxml: VXML,
  state_before: State,
  state_after: State,
) -> Result(#(VXML, State), DesugaringError) {
  let assert V(blame, tag, attributes, children) = vxml
  let #(counters_before, handles_before) = state_before
  let #(counters_after, handles_after) = state_after

  let handles_from_our_children =
    list.filter(handles_after, fn(h) { !list.contains(handles_before, h) })

  let attributes =
    list.append(
      attributes,
      handle_assignment_blamed_attributes_from_handle_assignments(
        handles_from_our_children,
      ),
    )

  let counters = take_existing_counters(counters_before, counters_after)

  Ok(#(V(blame, tag, attributes, children), #(counters, handles_before)))
}

fn our_two_regexes() -> #(Regexp, Regexp) {
  let any_number_of_handle_assignments = "((\\w+)(<<))*"

  let counter_prefix_and_counter =
    "("
    <> loud.regex_string
    <> "|"
    <> soft.regex_string
    <> ")("
    <> increment.regex_string
    <> "|"
    <> decrement.regex_string
    <> "|"
    <> no_change.regex_string
    <> ")(\\w+)"

  let any_number_of_counter_prefixes_and_counters_prefaced_by_punctuation =
    "((-|_|.|:|;|::|,)" <> counter_prefix_and_counter <> ")*"

  let assert Ok(big) =
    regexp.from_string(
      any_number_of_handle_assignments
      <> counter_prefix_and_counter
      <> any_number_of_counter_prefixes_and_counters_prefaced_by_punctuation,
    )

  let assert Ok(small) = regexp.from_string(counter_prefix_and_counter)

  #(small, big)
}

type State =
  #(List(CounterInstance), List(HandleAssignment))

fn transform_factory(_: InnerParam) -> infra.StatefulDownAndUpNodeToNodeTransform(State) {
  let regexes = our_two_regexes()
  infra.StatefulDownAndUpNodeToNodeTransform(
    v_before_transforming_children: fn(vxml, state) {
      v_before_transforming_children(vxml, state, regexes)
    },
    v_after_transforming_children: v_after_transforming_children,
    t_transform: fn(vxml, state) { t_transform(vxml, state, regexes) },
  )
}

fn desugarer_factory(param: InnerParam) -> infra.Desugarer {
  infra.stateful_down_up_node_to_node_desugarer_factory(
    transform_factory(param),
    #([], []),
  )
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

/// Substitutes counters by their numerical
/// value converted to string form and assigns those
/// values to prefixed handles.
///
/// If a counter named 'MyCounterName' is defined by
/// an ancestor, replaces strings of the form
///
/// \<aa>\<bb>MyCounterName
///
/// where
///
/// \<aa> == \"::\"|\"..\" indicates whether
/// the counter occurrence should be echoed as a
/// string appearing in the document or not (\"::\" == echo,
/// \"..\" == suppress), and where
///
/// \<bb> ==  \"++\"|\"--\"|\"øø\" indicates whether
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
/// The computed handle assignments are recorded as
/// attributes of the form
///
/// handle_\<handleName> <counterValue>
///
/// on the parent tag to be later used by the
/// 'handles_generate_dictionary' desugarer
pub fn counters_substitute_and_assign_handles() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "counters_substitute_and_assign_handles",
      option.Some(string.inspect(None)),
      "
Substitutes counters by their numerical
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

<bb> ==  \"++\"|\"--\"|\"øø\" indicates whether
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

The computed handle assignments are recorded as
attributes of the form

handle_<handleName> <counterValue>

on the parent tag to be later used by the
'handles_generate_dictionary' desugarer
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}

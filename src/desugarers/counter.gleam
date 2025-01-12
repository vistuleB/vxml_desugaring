import blamedlines.{type Blame, Blame}
import gleam/int
import gleam/list
import gleam/option
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
        "counter" ->
          option.Some(CounterInstance(ArabicCounter, first.value, "0"))
        "roman_counter" ->
          option.Some(CounterInstance(RomanCounter, first.value, "."))
        _ -> option.None
      }

      case get_counters_from_attributes(rest, counters) {
        Ok(res) -> {
          use _ <- result.try(check_counter_already_defined(
            first.value,
            counters,
            first.blame,
          ))
          case att {
            option.Some(att) -> Ok([att, ..res])
            option.None -> Ok(res)
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
  handle_names: option.Option(List(String)),
  value: String,
) -> Result(List(HandleInstance), DesugaringError) {
  case handle_names {
    option.None -> Ok(handles)
    option.Some(handle_names) -> {
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

fn get_all_handles_from_match_content(match_content: String) -> List(String) {
  let assert [_, ..rest] = string.split(match_content, "<<") |> list.reverse()
  list.reverse(rest)
}

fn handle_matches(
  blame: Blame,
  matches: List(regexp.Match),
  splits: List(String),
  counters: List(CounterInstance),
  handles: List(HandleInstance),
) -> Result(
  #(String, List(CounterInstance), List(HandleInstance)),
  DesugaringError,
) {
  case matches {
    [] -> {
      Ok(#(string.join(splits, ""), counters, handles))
    }
    [first, ..rest] -> {
      let regexp.Match(content, sub_matches) = first

      let assert [_, handle_name, _, insert_or_not, mutation, counter_name] =
        sub_matches
      let assert option.Some(counter_name) = counter_name
      let assert option.Some(mutation) = mutation

      let handle_names = case handle_name {
        option.None -> option.None
        option.Some(_) ->
          option.Some(get_all_handles_from_match_content(content))
      }

      case
        list.find(counters, fn(x: CounterInstance) { x.name == counter_name })
      {
        Ok(_) -> {
          // update counter
          use counters <- result.try(update_counter(
            blame,
            counters,
            counter_name,
            mutation,
          ))
          let assert Ok(updated_instance) =
            list.find(counters, fn(x: CounterInstance) {
              x.name == counter_name
            })
          // update handles
          use updated_handles <- result.try(assign_to_handles(
            blame,
            handles,
            handle_names,
            updated_instance.current_value,
          ))
          // handle rest of matches
          let assert [first_split, _, _, _, _, _, _, ..rest_splits] = splits
          use #(str, updated_counters, updated_handles) <- result.try(
            handle_matches(blame, rest, rest_splits, counters, updated_handles),
          )
          // replace counter syntax
          case insert_or_not == option.Some("::") {
            True -> {
              Ok(#(
                first_split <> updated_instance.current_value <> str,
                updated_counters,
                updated_handles,
              ))
            }
            False ->
              Ok(#(first_split <> str, updated_counters, updated_handles))
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

fn counter_regex(
  blame: Blame,
  content: String,
  counters: List(CounterInstance),
  handles: List(HandleInstance),
) -> Result(
  #(String, List(CounterInstance), List(HandleInstance)),
  DesugaringError,
) {
  // examples

  // "more handle<<::::MyCounter more" will result in
  // sub-matches of first match :
  //   [Some("handle<<"), Some("handle"), Some("<<"), Some("::"), Some("::"), Some   ("MyCounter")]
  // splits:
  //   ["more ", "handle<<", "handle", "<<", "::", "::", "MyCounter", " more"]

  // "more handle1<<handle2<<::::MyCounter more" will result in
  // content of first match : (only diff between first case) 
  //    \"handle2<<handle1<<::::Counter\"
  // sub-matches of first match :
  //   [Some("handle2<<"), Some("handle2"), Some("<<"), Some("::"), Some("::"), Some   ("MyCounter")]
  // splits:
  //   ["more ", "handle2<<", "handle2", "<<", "::", "::", "MyCounter", " more"]

  // "more ::::MyCounter more" will result in
  // sub-matches of first match :
  //   [None, None, None, Some("::"), Some("::"), Some   ("MyCounter")]
  // splits:
  //   ["more ", "", "", "", "::", "::", "MyCounter", " more"]
  let assert Ok(re) =
    regexp.from_string("((\\w+)(<<))*(::|\\.\\.)(::|\\+\\+|--)(\\w+)")

  let matches = regexp.scan(re, content)

  let splits = regexp.split(re, content)

  handle_matches(blame, matches, splits, counters, handles)
}

fn update_contents(
  contents: List(BlamedContent),
  counters: List(CounterInstance),
  handles: List(HandleInstance),
) -> Result(
  #(List(BlamedContent), List(CounterInstance), List(HandleInstance)),
  DesugaringError,
) {
  case contents {
    [] -> Ok(#(contents, counters, handles))
    [first, ..rest] -> {
      use #(updated_content, updated_counters, updated_handles) <- result.try(
        counter_regex(first.blame, first.content, counters, handles),
      )
      use #(rest_content, updated_counters, updated_handles) <- result.try(
        update_contents(rest, updated_counters, updated_handles),
      )

      Ok(#(
        [BlamedContent(first.blame, updated_content), ..rest_content],
        updated_counters,
        updated_handles,
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
  children: List(VXML),
  counters: List(CounterInstance),
  handles: List(HandleInstance),
) {
  case children {
    [] -> Ok(#([], counters, handles))
    [first, ..rest] -> {
      use #(updated_first, updated_counters, updated_handles) <- result.try(
        counter_transform(first, counters, handles, False),
      )
      // next children will not have counters that were added by nested children ( because of take_existing_counter)
      // handles will have them
      use #(updated_rest, updated_counters, updated_handles) <- result.try(
        transform_children_recursive(rest, updated_counters, updated_handles),
      )
      Ok(#([updated_first, ..updated_rest], updated_counters, updated_handles))
    }
  }
}

fn convert_handles_to_attributes(
  handles: List(HandleInstance),
) -> List(BlamedAttribute) {
  let blame = Blame("", 0, [])

  list.map(handles, fn(handle) {
    BlamedAttribute(
      blame: blame,
      key: "handle_" <> handle.name,
      value: handle.value,
    )
  })
}

fn counter_transform(
  vxml: VXML,
  counters: List(CounterInstance),
  handles: List(HandleInstance),
  is_root: Bool,
) -> Result(
  #(VXML, List(CounterInstance), List(HandleInstance)),
  DesugaringError,
) {
  case vxml {
    V(b, t, attributes, children) -> {
      use new_counters <- result.try(
        attributes
        |> get_counters_from_attributes(counters),
      )
      use #(updated_children, updated_counters, updated_handles) <- result.try(
        transform_children_recursive(
          children,
          list.append(counters, new_counters),
          handles,
        ),
      )

      case is_root {
        True -> {
          let handles_as_attributs =
            convert_handles_to_attributes(updated_handles)
          let updated_root = V(b, t, attributes, updated_children)
          let new_root =
            V(b, "GrandWrapper", handles_as_attributs, [updated_root])
          Ok(#(
            new_root,
            take_existing_counters(counters, updated_counters),
            updated_handles,
          ))
        }
        False -> {
          Ok(#(
            V(b, t, attributes, updated_children),
            take_existing_counters(counters, updated_counters),
            updated_handles,
          ))
        }
      }
    }
    T(b, contents) -> {
      use #(updated_contents, updated_counters, updated_handles) <- result.try(
        update_contents(contents, counters, handles),
      )
      Ok(#(T(b, updated_contents), updated_counters, updated_handles))
    }
  }
}

pub fn counter_desugarer() -> Pipe {
  #(DesugarerDescription("Counter", option.None, "..."), fn(vxml) {
    use #(vxml, _, _) <- result.try(counter_transform(vxml, [], [], True))
    Ok(vxml)
  })
}

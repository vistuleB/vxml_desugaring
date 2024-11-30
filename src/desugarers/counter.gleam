import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/regex
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription, DesugaringError,
} as infra
import roman
import vxml_parser.{
  type Blame, type BlamedAttribute, type BlamedContent, type VXML,
  BlamedAttribute, BlamedContent, T, V,
}

pub type CounterType {
  ArabicCounter
  RomanCounter
}

pub type CounterInstance {
  CounterInstance(
    counter_type: CounterType,
    name: String,
    current_value: String,
    // handle_assignments: Dict(String, String),
  )
}

pub type HandleInstance {
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

fn assign_to_handle(
  blame: Blame,
  handles: List(HandleInstance),
  handle_name: Option(String),
  value: String,
) -> Result(List(HandleInstance), DesugaringError) {
  case handle_name {
    option.None -> Ok(handles)
    option.Some(name) -> {
      use _ <- result.try(check_handle_already_defined(name, handles, blame))
      Ok(list.flatten([handles, [HandleInstance(name, value)]]))
    }
  }
}

fn handle_matches(
  blame: Blame,
  matches: List(regex.Match),
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
      let regex.Match(_, sub_matches) = first

      let assert [_, handle_name, _, insert_or_not, mutation, counter_name] =
        sub_matches
      let assert option.Some(counter_name) = counter_name
      let assert option.Some(mutation) = mutation

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
          // update handle
          use updated_handles <- result.try(assign_to_handle(
            blame,
            handles,
            handle_name,
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

  // "more ::::MyCounter more" will result in
  // sub-matches of first match :
  //   [None, None, None, Some("::"), Some("::"), Some   ("MyCounter")]
  // splits:
  //   ["more ", "", "", "", "::", "::", "MyCounter", " more"]
  let assert Ok(re) =
    regex.from_string("((\\w+)(<<))?(::|\\.\\.)(::|\\+\\+|--)(\\w+)")

  let matches = regex.scan(re, content)
  let splits = regex.split(re, content)
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
        counter_transform(first, counters, handles),
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

fn counter_transform(
  vxml: VXML,
  counters: List(CounterInstance),
  handles: List(HandleInstance),
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
      Ok(#(
        V(b, t, attributes, updated_children),
        take_existing_counters(counters, updated_counters),
        updated_handles,
      ))
    }
    T(b, contents) -> {
      use #(updated_contents, updated_counters, updated_handles) <- result.try(
        update_contents(contents, counters, handles),
      )
      Ok(#(T(b, updated_contents), updated_counters, updated_handles))
    }
  }
}

// *************************
// handle values replacement
// *************************
fn handle_handle_matches(
  blame: Blame,
  matches: List(regex.Match),
  splits: List(String),
  handles: List(HandleInstance),
) -> Result(String, DesugaringError) {
  case matches {
    [] -> {
      Ok(string.join(splits, ""))
    }
    [first, ..rest] -> {
      let regex.Match(_, sub_matches) = first

      let assert [_, handle_name] = sub_matches
      let assert option.Some(handle_name) = handle_name
      case list.find(handles, fn(x) { x.name == handle_name }) {
        Error(_) ->
          Error(DesugaringError(
            blame,
            "Handle " <> handle_name <> " was not assigned",
          ))
        Ok(handle) -> {
          let assert [first_split, _, _, ..rest_splits] = splits
          use rest_content <- result.try(handle_handle_matches(
            blame,
            rest,
            rest_splits,
            handles,
          ))
          Ok(first_split <> handle.value <> rest_content)
        }
      }
    }
  }
}

fn print_handle(
  blamed_line: BlamedContent,
  handles: List(HandleInstance),
) -> Result(String, DesugaringError) {
  let assert Ok(re) = regex.from_string("(>>)(\\w+)")

  let matches = regex.scan(re, blamed_line.content)
  let splits = regex.split(re, blamed_line.content)
  handle_handle_matches(blamed_line.blame, matches, splits, handles)
}

fn print_handle_for_contents(
  contents: List(BlamedContent),
  handles: List(HandleInstance),
) -> Result(List(BlamedContent), DesugaringError) {
  case contents {
    [] -> Ok([])
    [first, ..rest] -> {
      use updated_line <- result.try(print_handle(first, handles))
      use updated_rest <- result.try(print_handle_for_contents(rest, handles))

      Ok([BlamedContent(first.blame, updated_line), ..updated_rest])
    }
  }
}

fn handles_transform(
  vxml: VXML,
  handles: List(HandleInstance),
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(b, contents) -> {
      use update_contents <- result.try(print_handle_for_contents(
        contents,
        handles,
      ))
      Ok(T(b, update_contents))
    }
    _ -> {
      Ok(vxml)
    }
  }
}

fn handle_transform_factory(
  handles: List(HandleInstance),
) -> NodeToNodeTransform {
  handles_transform(_, handles)
}

fn handle_desugarer_factory(handles: List(HandleInstance)) {
  infra.node_to_node_desugarer_factory(handle_transform_factory(handles))
}

pub fn counter_desugarer() -> Pipe {
  #(DesugarerDescription("Counter", option.None, "..."), fn(vxml) {
    use #(vxml, _, handles) <- result.try(counter_transform(vxml, [], []))
    handle_desugarer_factory(handles)(vxml)
  })
}

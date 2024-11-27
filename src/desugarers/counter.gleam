import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/regex
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe, DesugarerDescription, DesugaringError,
}
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

fn get_counters_from_attributes(
  //node: VXML,
  attributes: List(BlamedAttribute),
  counters: List(CounterInstance),
) -> Result(List(CounterInstance), DesugaringError) {
  case attributes {
    [] -> Ok([])
    [first, ..rest] -> {
      let att = case first.key {
        "counter" ->
          option.Some(CounterInstance(ArabicCounter, first.value, "1"))
        "roman_counter" ->
          option.Some(CounterInstance(RomanCounter, first.value, "i"))
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

fn mutate(counter_type: CounterType, value: String, mutate_by: Int) -> String {
  case counter_type {
    ArabicCounter -> {
      let assert Ok(int_val) = int.parse(value)
      string.inspect(int_val + mutate_by)
    }
    RomanCounter -> {
      let assert option.Some(romans) = roman.string_to_roman(value)
      romans
      |> roman.roman_to_int()
      |> int.add(mutate_by)
      |> roman.int_to_roman()
      |> option.unwrap([])
      |> roman.roman_to_string()
    }
  }
}

fn update_counter(
  counters: List(CounterInstance),
  counter_name: String,
  mutation: String,
) -> List(CounterInstance) {
  list.map(counters, fn(x) {
    case x.name == counter_name {
      True -> {
        case mutation {
          "++" ->
            CounterInstance(
              ..x,
              current_value: mutate(x.counter_type, x.current_value, 1),
            )
          "--" ->
            CounterInstance(
              ..x,
              current_value: mutate(x.counter_type, x.current_value, -1),
            )
          _ -> x
        }
      }
      False -> x
    }
  })
}

fn handle_matches(
  blame: Blame,
  matches: List(regex.Match),
  splits: List(String),
  counters: List(CounterInstance),
) -> Result(#(String, List(CounterInstance)), DesugaringError) {
  case matches {
    [] -> {
      Ok(#(string.join(splits, ""), counters))
    }
    [first, ..rest] -> {
      let regex.Match(_, sub_matches) = first

      let assert [insert_or_not, mutation, counter_name] = sub_matches
      let assert option.Some(counter_name) = counter_name
      let assert option.Some(mutation) = mutation

      case
        list.find(counters, fn(x: CounterInstance) { x.name == counter_name })
      {
        Ok(_) -> {
          let counters = update_counter(counters, counter_name, mutation)
          let assert Ok(updated_instance) =
            list.find(counters, fn(x: CounterInstance) {
              x.name == counter_name
            })

          let assert [first_split, _, _, _, ..rest_splits] = splits

          use #(str, counters) <- result.try(handle_matches(
            blame,
            rest,
            rest_splits,
            counters,
          ))

          case insert_or_not == option.Some("::") {
            True -> {
              Ok(#(
                first_split <> updated_instance.current_value <> str,
                counters,
              ))
            }
            False -> Ok(#(first_split <> str, counters))
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
) -> Result(#(String, List(CounterInstance)), DesugaringError) {
  let assert Ok(re) = regex.from_string("(::|\\.\\.)(::|\\+\\+|--)(\\w+)")
  let matches = regex.scan(re, content)
  let splits = regex.split(re, content)
  io.debug(splits)
  handle_matches(blame, matches, splits, counters)
}

fn update_contents(
  contents: List(BlamedContent),
  counters: List(CounterInstance),
) -> Result(#(List(BlamedContent), List(CounterInstance)), DesugaringError) {
  case contents {
    [] -> Ok(#(contents, counters))
    [first, ..rest] -> {
      use #(updated_content, updated_counters) <- result.try(counter_regex(
        first.blame,
        first.content,
        counters,
      ))
      use #(rest_content, updated_counters) <- result.try(update_contents(
        rest,
        updated_counters,
      ))

      Ok(#(
        [BlamedContent(first.blame, updated_content), ..rest_content],
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
  children: List(VXML),
  counters: List(CounterInstance),
) {
  case children {
    [] -> Ok(#([], counters))
    [first, ..rest] -> {
      use #(updated_first, updated_counters) <- result.try(counter_transform(
        first,
        counters,
      ))
      use #(updated_rest, updated_counters) <- result.try(
        transform_children_recursive(rest, updated_counters),
      )
      Ok(#([updated_first, ..updated_rest], updated_counters))
    }
  }
}

pub fn counter_transform(
  vxml: VXML,
  counters: List(CounterInstance),
) -> Result(#(VXML, List(CounterInstance)), DesugaringError) {
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
      Ok(#(
        V(b, t, attributes, updated_children),
        take_existing_counters(counters, updated_counters),
      ))
    }
    T(b, contents) -> {
      case counters {
        [] -> Ok(#(T(b, contents), []))
        _ -> {
          use #(updated_contents, counters) <- result.try(update_contents(
            contents,
            counters,
          ))
          Ok(#(T(b, updated_contents), counters))
        }
      }
    }
  }
}

pub fn counter_desugarer() -> Pipe {
  #(DesugarerDescription("Counter", option.None, "..."), fn(vxml) {
    case counter_transform(vxml, []) {
      Ok(#(vxml, _)) -> Ok(vxml)
      Error(error) -> Error(error)
    }
  })
}

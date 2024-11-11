import gleam/list
import gleam/pair
import gleam/string
import infrastructure.{type DesugaringError}
import writerly_parser.{
  type Blame, type BlamedContent, type VXML, BlamedContent, T, V,
}

fn alternating_list_insert(ze_list: List(a), ze_thing: a) -> List(a) {
  case ze_list {
    [] -> []
    [first] -> [first]
    [first, ..rest] -> [
      first,
      ze_thing,
      ..alternating_list_insert(rest, ze_thing)
    ]
  }
}

type EitherOr(a, b) {
  Either(a)
  Or(b)
}

fn break_line_by_double_dollars(
  line: BlamedContent,
) -> List(EitherOr(BlamedContent, Blame)) {
  let BlamedContent(blame, content) = line
  string.split(content, "$$")
  |> list.map(fn(thing) { Either(BlamedContent(blame, thing)) })
  |> alternating_list_insert(Or(blame))
  |> list.filter(fn(thing) {
    case thing {
      Either(BlamedContent(_, content)) -> !string.is_empty(content)
      _ -> True
    }
  })
}

fn regroup_either_or_1st_argument_internal(
  ze_list: List(EitherOr(a, b)),
) -> #(Bool, List(EitherOr(List(a), b))) {
  case ze_list {
    [] -> #(False, [])

    [Either(thing1), ..rest] -> {
      let first_return_value = True
      let second_return_value = case
        regroup_either_or_1st_argument_internal(rest)
      {
        #(True, regrouped) -> {
          let assert [Either(list_of_as), ..beyond] = regrouped
          [Either([thing1, ..list_of_as]), ..beyond]
        }
        #(False, regrouped) -> [Either([thing1]), ..regrouped]
      }
      #(first_return_value, second_return_value)
    }

    [Or(thing2), ..rest] -> {
      let first_return_value = False
      let second_return_value = [
        Or(thing2),
        ..regroup_either_or_1st_argument_internal(rest)
        |> pair.second
      ]
      #(first_return_value, second_return_value)
    }
  }
}

fn regroup_either_or_1st_argument(
  ze_list: List(EitherOr(a, b)),
) -> List(EitherOr(List(a), b)) {
  regroup_either_or_1st_argument_internal(ze_list)
  |> pair.second
}

fn text_else_tag(
  thing: EitherOr(List(BlamedContent), Blame),
  tag_name: String,
) -> VXML {
  case thing {
    Either(blamed_contents) -> {
      let assert [BlamedContent(blame, _), ..] = blamed_contents
      T(blame, blamed_contents)
    }
    Or(blame) -> V(blame, tag_name, [], [])
  }
}

pub fn break_up_text_by_double_dollars_transform(
  node: VXML,
  _: List(VXML),
  _: Nil,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, _, _, _) -> Ok([node])
    T(_, lines) -> {
      lines
      |> list.map(break_line_by_double_dollars)
      |> list.flatten
      |> regroup_either_or_1st_argument
      |> list.map(text_else_tag(_, "DoubleDollar"))
      |> Ok
    }
  }
}

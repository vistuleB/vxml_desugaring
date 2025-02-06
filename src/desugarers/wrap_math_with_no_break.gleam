import gleam/list
import gleam/option.{Some}
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription, DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V}

fn wrap_second_element_if_its_math_and_recurse(children: List(VXML)) -> List(VXML) {
  use first, after_first <- infra.on_lazy_empty_on_nonempty(
    children,
    fn() { [] }
  )

  use math, after_second <- infra.on_lazy_empty_on_nonempty(
    after_first,
    fn() { children }
  )

  use <- infra.on_lazy_false_on_true(
    infra.is_v_and_tag_equals(math, "Math"),
    fn() {[first, ..wrap_second_element_if_its_math_and_recurse([math, ..after_second])]}
  )

  let #(first, last_word_of_first) = infra.extract_last_word_from_t_node_if_t(first)

  use third, after_third <- infra.on_lazy_empty_on_nonempty(
    after_second,
    fn() {[
      first,
      V(
        math.blame,
        "NoBreak",
        [],
        [
          last_word_of_first,
          Some(math)
        ] |> option.values
      ),
      ..wrap_second_element_if_its_math_and_recurse(after_second)
    ]}
  )

  let #(first_word_of_third, third) = infra.extract_first_word_from_t_node_if_t(third)

  [
    first,
    V(
      math.blame,
      "NoBreak",
      [],
      [
        last_word_of_first,
        Some(math),
        first_word_of_third
      ] |> option.values
    ),
    ..wrap_second_element_if_its_math_and_recurse([third, ..after_third])
  ]
}

fn wrap_math_with_no_break_transform(
  node: VXML,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(b, t, a, children) -> {
      Ok(
        V(
          b,
          t,
          a,
          [V(b, "Dummy", [], []), ..children]
          |> wrap_second_element_if_its_math_and_recurse
          |> list.drop(1)
        )
      )
    }
  }
}

fn transform_factory() -> NodeToNodeTransform {
  wrap_math_with_no_break_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn wrap_math_with_no_break() -> Pipe {
  #(
    DesugarerDescription("wrap_math_with_no_break", option.None, "..."),
    desugarer_factory(),
  )
}

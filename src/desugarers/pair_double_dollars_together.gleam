import blamedlines.{type Blame}
import gleam/list
import gleam/option.{type Option}
import gleam/result
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe} as infra
import vxml.{type VXML, T, V}

fn is_double_dollar(x: VXML) -> Option(Blame) {
  case x {
    T(_, _) -> option.None
    V(blame, tag, _, _) ->
      case tag == "DoubleDollar" {
        True -> option.Some(blame)
        False -> option.None
      }
  }
}

pub fn scan_to_next_double_dollar(
  vxmls: List(VXML),
) -> #(List(VXML), Option(#(Blame, List(VXML)))) {
  case vxmls {
    [] -> #([], option.None)
    [first, ..rest] ->
      case is_double_dollar(first) {
        option.Some(blame) -> #([], option.Some(#(blame, rest)))
        option.None -> {
          let #(list, option) = scan_to_next_double_dollar(rest)
          #([first, ..list], option)
        }
      }
  }
}

fn pair_double_dollars_odd(
  vxmls: List(VXML),
  blame_of_guy_to_pair: Blame,
) -> Result(#(List(VXML), List(VXML)), DesugaringError) {
  case scan_to_next_double_dollar(vxmls) {
    #(before_first_double_dollar, option.Some(#(_, after_first_double_dollar))) ->
      case pair_double_dollars_even(after_first_double_dollar) {
        Ok(after_first_double_dollar_transformed) ->
          Ok(#(
            before_first_double_dollar,
            after_first_double_dollar_transformed,
          ))
        Error(err) -> Error(err)
      }
    #(_, option.None) ->
      Error(DesugaringError(blame_of_guy_to_pair, "$$ missing matching pair"))
  }
}

fn pair_double_dollars_even(
  vxmls: List(VXML),
) -> Result(List(VXML), DesugaringError) {
  case scan_to_next_double_dollar(vxmls) {
    #(
      before_first_double_dollar,
      option.Some(#(first_double_dollar_blame, after_first_double_dollar)),
    ) ->
      case
        pair_double_dollars_odd(
          after_first_double_dollar,
          first_double_dollar_blame,
        )
      {
        Ok(#(
          between_first_and_second_double_dollars,
          after_second_double_dollar,
        )) -> {
          let mathblock_node =
            V(
              blame: first_double_dollar_blame,
              tag: "MathBlock",
              attributes: [],
              children: between_first_and_second_double_dollars,
            )
          let node_and_after_node = [
            mathblock_node,
            ..after_second_double_dollar
          ]
          Ok(list.append(before_first_double_dollar, node_and_after_node))
        }
        Error(err) -> Error(err)
      }
    #(before_first_double_dollar, option.None) -> Ok(before_first_double_dollar)
  }
}

fn transform(
  node: VXML,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attrs, children) -> {
      use new_children <- result.try(pair_double_dollars_even(children))
      Ok(V(blame, tag, attrs, new_children))
    }
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

pub const desugarer_name = "pair_double_dollars_together_desugarer"
pub const desugarer_pipe = pair_double_dollars_together_desugarer

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------

/// pairs DoubleDollar tags together and wraps content between them in MathBlock tags
pub fn pair_double_dollars_together_desugarer() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.None,
      general_description: "
/// pairs DoubleDollar tags together and wraps content between them in MathBlock tags
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data_nil_param(desugarer_name, assertive_tests_data(), desugarer_pipe)
}

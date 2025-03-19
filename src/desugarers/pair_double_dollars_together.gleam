import blamedlines.{type Blame}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml_parser.{type VXML, T, V}

fn is_double_dollar(x: VXML) -> Option(Blame) {
  case x {
    T(_, _) -> None
    V(blame, tag, _, _) ->
      case tag == "DoubleDollar" {
        True -> Some(blame)
        False -> None
      }
  }
}

pub fn scan_to_next_double_dollar(
  vxmls: List(VXML),
) -> #(List(VXML), Option(#(Blame, List(VXML)))) {
  case vxmls {
    [] -> #([], None)
    [first, ..rest] ->
      case is_double_dollar(first) {
        Some(blame) -> #([], Some(#(blame, rest)))
        None -> {
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
    #(before_first_double_dollar, Some(#(_, after_first_double_dollar))) ->
      case pair_double_dollars_even(after_first_double_dollar) {
        Ok(after_first_double_dollar_transformed) ->
          Ok(#(
            before_first_double_dollar,
            after_first_double_dollar_transformed,
          ))
        Error(err) -> Error(err)
      }
    #(_, None) ->
      Error(DesugaringError(blame_of_guy_to_pair, "$$ missing matching pair"))
  }
}

fn pair_double_dollars_even(
  vxmls: List(VXML),
) -> Result(List(VXML), DesugaringError) {
  case scan_to_next_double_dollar(vxmls) {
    #(
      before_first_double_dollar,
      Some(#(first_double_dollar_blame, after_first_double_dollar)),
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
    #(before_first_double_dollar, None) -> Ok(before_first_double_dollar)
  }
}

pub fn pair_double_dollars_together_transform(
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

fn transform_factory() -> infra.NodeToNodeTransform {
  pair_double_dollars_together_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn pair_double_dollars_together_desugarer() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "pair_double_dollars_together_desugarer",
      option.None,
      "...",
    ),
    desugarer: desugarer_factory(),
  )
}

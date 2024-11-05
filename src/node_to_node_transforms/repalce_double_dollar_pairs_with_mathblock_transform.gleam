import gleam/result
import gleam/list
import vxml_parser.{type VXML, T, V}
import infrastructure.{type DesugaringError, DesugaringError}

fn is_double_dollar(x: VXML) {
  case x {
    T(_, _) -> False
    V(_, tag, _, _) -> tag == "DoubleDollar"
  }
}

fn has_closing_pair(rest: List(VXML)) {
  case rest {
    [] -> False
    [first, ..rest] -> is_double_dollar(first) || has_closing_pair(rest)
  }
}

fn pair_double_dollars(children: List(VXML), output: List(VXML)) -> Result(List(VXML), DesugaringError) {
  case children {
    [] -> Ok(output)
    [first, ..rest] -> {
      case is_double_dollar(first), has_closing_pair(rest) {
        True, True -> {
          case first {
            T(_, _) -> Ok([]) // not possible
            V(blame, _, _, _) -> {
              let mathblock_child = case rest {
                [] -> [] // not possible
                [second, ..] -> [second]
              }
              let mathblock = V(blame: blame, tag: "MathBlock", attributes: [], children: mathblock_child)
              let output = list.append(output, [mathblock])
              // skip 2 next vxmls as first is the blamed content and second is closing pair
              let rest = case rest {
                [_, _,  ..rest] -> rest
                _ -> [] // not possible
              }
              pair_double_dollars(rest, output)
            }
          }
        }
        _, _ -> pair_double_dollars(rest, list.append(output, [first]))
      }
    }
  }
}

pub fn repalce_double_dollar_pairs_with_mathblock_transform(
  node: VXML,
  _: List(VXML),
  _: Nil,
) -> Result(VXML, DesugaringError) {
  // find node that have DoubleDollar as children
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, att, children) -> {
      let have_double_dollar = list.filter(children, is_double_dollar)

      case list.length(have_double_dollar) > 1 {
        True -> {
          //let updated_children = pair_double_dollars()
          use updated_children <- result.try(pair_double_dollars(children, []))
          Ok(V(blame, tag, att, updated_children))
        }
        False -> Ok(node)
      }
    }
  }
}
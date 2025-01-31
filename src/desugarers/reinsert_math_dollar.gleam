import gleam/dict
import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription,
} as infra
import vxml_parser.{type VXML, BlamedContent, T, V}

const ins = string.inspect

type Where {
  First
  Last
  Both
}

fn insert_dollar(node: VXML, dollar: String, where: Where) -> List(VXML) {
  case node {
    T(blame, contents) -> {
      case where {
        First -> [T(blame, [BlamedContent(blame, dollar), ..contents])]
        Last -> [T(blame, list.append(contents, [BlamedContent(blame, dollar)]))]
        Both -> [
          T(
            blame,
            list.flatten([
              [BlamedContent(blame, dollar)],
              contents,
              [BlamedContent(blame, dollar)],
            ]),
          ),
        ]
      }
    }
    V(blame, _, _, _) -> {
      case where {
        First -> [T(blame, [BlamedContent(blame, dollar)]), node]
        Last -> [node, T(blame, [BlamedContent(blame, dollar)])]
        Both -> [
          T(blame, [BlamedContent(blame, dollar)]),
          node,
          T(blame, [BlamedContent(blame, dollar)]),
        ]
      }
    }
  }
}

fn update_children(nodes: List(VXML), dollar: String) -> List(VXML) {
  let assert [first, ..rest] = nodes
  let last = list.last(rest)

  case last {
    Ok(last) -> {
      panic as {"more than 1 child in node:" <> ins(nodes) }
      let assert [_, ..in_between_reversed] = rest |> list.reverse()
      list.flatten([
        insert_dollar(first, dollar, First),
        in_between_reversed |> list.reverse(),
        insert_dollar(last, dollar, Last),
      ])
    }
    Error(_) -> {
      insert_dollar(first, dollar, Both)
    }
  }
}

fn param_transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  let math_map = dict.from_list([#("Math", "$"), #("MathBlock", "$$")])

  case vxml {
    V(blame, tag, atts, children) -> {
      case dict.get(math_map, tag) {
        Ok(delimiter) -> {
          Ok(V(blame, tag, atts, update_children(children, delimiter)))
        }
        Error(_) -> Ok(vxml)
      }
    }
    _ -> Ok(vxml)
  }
}

fn transform_factory() -> NodeToNodeTransform {
  param_transform(_)
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn reinsert_math_dollar() -> Pipe {
  #(
    DesugarerDescription("reinsert_math_dollar", option.None, "..."),
    desugarer_factory(),
  )
}

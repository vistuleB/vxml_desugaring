import gleam/dict
import gleam/list
import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription,
} as infra
import vxml_parser.{type VXML, BlamedContent, T, V}

type Where {
  First
  Last
  Both
}

fn insert_dolar(node: VXML, dolar: String, where: Where) -> List(VXML) {
  case node {
    T(blame, contents) -> {
      case where {
        First -> [T(blame, [BlamedContent(blame, dolar), ..contents])]
        Last -> [T(blame, list.append(contents, [BlamedContent(blame, dolar)]))]
        Both -> [
          T(
            blame,
            list.flatten([
              [BlamedContent(blame, dolar)],
              contents,
              [BlamedContent(blame, dolar)],
            ]),
          ),
        ]
      }
    }
    V(blame, _, _, _) -> {
      case where {
        First -> [T(blame, [BlamedContent(blame, dolar)]), node]
        Last -> [node, T(blame, [BlamedContent(blame, dolar)])]
        Both -> [
          T(blame, [BlamedContent(blame, dolar)]),
          node,
          T(blame, [BlamedContent(blame, dolar)]),
        ]
      }
    }
  }
}

fn update_children(nodes: List(VXML), dolar: String) -> List(VXML) {
  let assert [first, ..rest] = nodes
  let last = list.last(rest)

  case last {
    Ok(last) -> {
      let assert [_, ..in_between_reversed] = rest |> list.reverse()
      list.flatten([
        insert_dolar(first, dolar, First),
        in_between_reversed |> list.reverse(),
        insert_dolar(last, dolar, Last),
      ])
    }
    Error(_) -> {
      insert_dolar(first, dolar, Both)
    }
  }
}

fn reinsert_math_dolar_transform(vxml: VXML) -> Result(VXML, DesugaringError) {
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
  reinsert_math_dolar_transform(_)
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn reinsert_math_dolar() -> Pipe {
  #(
    DesugarerDescription("reinsert_math_dolar", option.None, "..."),
    desugarer_factory(),
  )
}

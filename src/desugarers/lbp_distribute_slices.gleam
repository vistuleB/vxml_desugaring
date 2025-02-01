import gleam/list
import gleam/io
import gleam/option.{None}
import infrastructure.{
  type Desugarer, type EarlyReturnNodeToNodeTransform, type Pipe,
  DesugarerDescription, type EarlyReturn, Continue, GoBack
} as infra
import vxml_parser.{type VXML, T, V, BlamedAttribute}

fn is_known_outer_element(
  vxml: VXML
) -> Bool {
  case vxml {
    V(_, tag, _, _) -> {
      case list.contains(
        [
          "Book",
          "Chapter",
          "Bootcamp",
          "Section",
          "TOCAuthorSuppliedContent",
          "PanelAuthorSuppliedContent",
          "Example",
          "Exercises",
          "Exercise",
          "Solution",
        ],
        tag
      ) {
        True -> True
        False -> False
      }
    }
    T(_, _) -> False
  }
}

fn is_known_inner_element(
  vxml: VXML
) -> Bool {
  case vxml {
    V(_, tag, _, _) -> {
      case list.contains(
        [
          "div", 
          "p",
          "table",
          "ul",
          "ol",
          "MathBlock",
          "Spacer",
          "StarDivider",
          "CentralDisplayItalic",
          "CentralDisplay",
          "Pause",
          "Image",
          "Grid",
          "Table",
          "List",
        ],
        tag
      ) {
        True -> True
        False -> False
      }
    }
    T(_, _) -> True
  }
}

fn param_transform(
  vxml: VXML,
  _: List(VXML)
) -> EarlyReturn(VXML) {
  use <- infra.on_true_on_false(
    is_known_outer_element(vxml),
    Continue(vxml)
  )

  use <- infra.on_lazy_true_on_false(
    is_known_inner_element(vxml),
    fn() {
      let blame = vxml |> infra.get_blame
      GoBack(
        V(
          blame,
          "div",
          [BlamedAttribute(blame, "class", "slice")],
          [vxml]
        )
      )
    }
  )

  io.println("unclassified element: " <> {vxml |> infra.digest})

  GoBack(vxml)
}

fn transform_factory() -> EarlyReturnNodeToNodeTransform {
  param_transform
}

fn desugarer_factory() -> Desugarer {
  infra.early_return_node_to_node_desugarer_factory(transform_factory())
}

pub fn lbp_distribute_slices() -> Pipe {
  #(
    DesugarerDescription("lbp_distribute_slices", None, "..."),
    desugarer_factory(),
  )
}

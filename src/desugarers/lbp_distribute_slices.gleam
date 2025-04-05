import gleam/io
import gleam/list
import gleam/option.{None}
import infrastructure.{type Desugarer, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, T, V}

fn is_known_outer_element(vxml: VXML) -> Bool {
  case vxml {
    V(_, tag, _, _) -> {
      case
        list.contains(
          [
            "Book", "Chapter", "Bootcamp", "Section", "TOCAuthorSuppliedContent",
            "PanelAuthorSuppliedContent", "Example", "Exercises", "Exercise",
            "Solution",
          ],
          tag,
        )
      {
        True -> True
        False -> False
      }
    }
    T(_, _) -> False
  }
}

fn is_known_inner_element(vxml: VXML) -> Bool {
  case vxml {
    V(_, tag, _, _) -> {
      case
        list.contains(
          [
            "ul", "ol", "MathBlock", "Spacer", "StarDivider",
            "CentralDisplayItalic", "CentralDisplay", "Image", "Grid", "List",
          ],
          tag,
        )
      {
        True -> True
        False -> False
      }
    }
    T(_, _) -> True
  }
}

fn is_known_other_element(vxml: VXML) -> Bool {
  let assert V(_, tag, _, _) = vxml
  list.contains(["Table", "table", "Pause", "p"], tag)
}

fn param_transform(vxml: VXML, _: List(VXML)) -> infra.EarlyReturn(VXML) {
  use <- infra.on_true_on_false(
    is_known_outer_element(vxml),
    infra.Continue(vxml),
  )

  use <- infra.on_lazy_true_on_false(is_known_inner_element(vxml), fn() {
    let blame = vxml |> infra.get_blame
    infra.GoBack(
      V(blame, "div", [BlamedAttribute(blame, "class", "slice")], [vxml]),
    )
  })

  use <- infra.on_true_on_false(
    is_known_other_element(vxml),
    infra.GoBack(vxml),
  )

  io.println("unclassified element: " <> { vxml |> infra.digest })

  infra.GoBack(vxml)
}

fn transform_factory() -> infra.EarlyReturnNodeToNodeTransform {
  param_transform
}

fn desugarer_factory() -> Desugarer {
  infra.early_return_node_to_node_desugarer_factory(transform_factory())
}

pub fn lbp_distribute_slices() -> Pipe {
  Pipe(
    description: DesugarerDescription("lbp_distribute_slices", None, "..."),
    desugarer: desugarer_factory(),
  )
}

import gleam/io
import gleam/list
import gleam/option
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, BlamedAttribute, T, V}

fn is_known_outer_element(vxml: VXML) -> Bool {
  case vxml {
    V(_, tag, _, _) -> {
      case
        list.contains(
          [
            "Book", "Chapter", "Bootcamp", "Section", "TOCAuthorSuppliedContent",
            "HamburgerPanelAuthorSuppliedContents", "Example", "Exercises",
            "Exercise", "Solution",
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

fn transform(vxml: VXML, _: List(VXML)) -> n2t.EarlyReturn(VXML) {
  use <- infra.on_true_on_false(
    is_known_outer_element(vxml),
    n2t.Continue(vxml),
  )

  use <- infra.on_lazy_true_on_false(is_known_inner_element(vxml), fn() {
    let blame = vxml |> infra.get_blame
    n2t.GoBack(
      V(blame, "div", [BlamedAttribute(blame, "class", "slice")], [vxml]),
    )
  })

  use <- infra.on_true_on_false(
    is_known_other_element(vxml),
    n2t.GoBack(vxml),
  )

  io.println("unclassified element: " <> { vxml |> infra.digest })

  n2t.GoBack(vxml)
}

fn transform_factory(_: InnerParam) -> n2t.EarlyReturnNodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.early_return_node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

const name = "lbp_distribute_slices"
const constructor = lbp_distribute_slices

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// distributes slice wrappers around inner elements
/// for LBP content
pub fn lbp_distribute_slices(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// distributes slice wrappers around inner elements
/// for LBP content
    ",
    case param_to_inner_param(param) {
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
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}

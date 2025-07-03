import gleam/io
import gleam/list
import gleam/option
import infrastructure.{type Desugarer,type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, T, V}

fn is_known_outer_element(vxml: VXML) -> Bool {
  case vxml {
    V(_, tag, _, _) -> {
      case
        list.contains(
          [
            "Book", "Chapter", "Bootcamp", "Section", "TOCAuthorSuppliedContent",
            "HamburgerPanelAuthorSuppliedContents", "Example", "Exercises", "Exercise",
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

fn transform(vxml: VXML, _: List(VXML)) -> infra.EarlyReturn(VXML) {
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

fn transform_factory(_: InnerParam) -> infra.EarlyReturnNodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.early_return_node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

pub const desugarer_name = "lbp_distribute_slices"
pub const desugarer_pipe = lbp_distribute_slices

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// distributes slice wrappers around inner elements for LBP content
pub fn lbp_distribute_slices() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.None,
      general_description: "
/// distributes slice wrappers around inner elements for LBP content
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

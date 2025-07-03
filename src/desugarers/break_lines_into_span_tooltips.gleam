import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe } as infra
import vxml.{ type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V }

fn line_to_tooltip_span(bc: BlamedContent, inner: InnerParam) -> VXML {
  let location =
    inner <> bc.blame.filename <> ":" <> ins(bc.blame.line_no) <> ":" <> "50"
  V(
    bc.blame,
    "span",
    [BlamedAttribute(bc.blame, "class", "tooltip-3003-container")],
    [
      V(
        bc.blame,
        "span",
        [
          BlamedAttribute(bc.blame, "class", "tooltip-3003-text")
        ],
        [
          T(bc.blame, [BlamedContent(bc.blame, bc.content)])
        ],
      ),
      V(
        bc.blame,
        "span",
        [
          BlamedAttribute(bc.blame, "class", "tooltip-3003"),
          BlamedAttribute(bc.blame, "onClick", "sendCmdTo3003('code --goto " <> location <> "');"),
        ],
        [
          T(bc.blame, [BlamedContent(bc.blame, location)])
        ],
      ),
    ],
  )
}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(blame, lines) -> {
      Ok([
        V(
          blame,
          "span",
          [],
          lines
            |> list.map(line_to_tooltip_span(_, inner))
            |> list.intersperse(
              T(blame, [BlamedContent(blame, ""), BlamedContent(blame, "")]),
            ),
        ),
      ])
    }
    _ -> Ok([vxml])
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesFancyTransform {
  transform(_, inner)
  |> infra.prevent_node_to_nodes_transform_inside(["Math", "MathBlock"])
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = String

type InnerParam = Param

pub const desugarer_name = "break_lines_into_span_tooltips"
pub const desugarer_pipe = break_lines_into_span_tooltips

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------

/// breaks lines into span tooltips with location information
pub fn break_lines_into_span_tooltips(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// breaks lines into span tooltips with location information
      ",
    ),
    desugarer: case param_to_inner_param(param) {
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
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}
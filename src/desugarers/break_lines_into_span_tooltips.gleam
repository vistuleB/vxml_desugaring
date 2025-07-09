import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{ type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError } as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{ type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V }

fn line_to_tooltip_span(
  bc: BlamedContent,
  inner: InnerParam,
) -> VXML {
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

fn nodemap(
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

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToManyNodeMap {
  nodemap(_, inner)
  |> n2t.prevent_node_to_nodes_transform_inside(["Math", "MathBlock"])
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.fancy_one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = String
//           ↖
//           local path
//           of source

type InnerParam = Param

const name = "break_lines_into_span_tooltips"
const constructor = break_lines_into_span_tooltips

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53

/// breaks lines into span tooltips with location
/// information
pub fn break_lines_into_span_tooltips(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// breaks lines into span tooltips with location
/// information
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
  [
    // note 1: not sure if following test is correct
    // it was reverse-engineered from the desugarer's
    // output long after this desugarer had already
    // stopped being used (but it might be correct)
    //
    // note 2: 'test' is the filename assigned by the
    // infrastructure.gleam test runner, which is why 
    // '../path/to/content/test' shows up in the expected 
    // output
    infra.AssertiveTestData(
      param: "../path/to/content/",
      source:   "
                <> root
                  <>
                    \"some text\"
                ",
      expected: "
                <> root
                  <> span
                    <> span
                      class=tooltip-3003-container
                      <> span
                        class=tooltip-3003-text
                        <>
                          \"some text\"
                      <> span
                        class=tooltip-3003
                        onClick=sendCmdTo3003('code --goto ../path/to/content/test break_lines_into_span_tooltips:3:50');
                        <>
                          \"../path/to/content/test break_lines_into_span_tooltips:3:50\"
                "
    ),
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
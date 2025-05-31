import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe } as infra
import vxml.{ type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V }

fn line_to_tooltip_span(bc: BlamedContent, prefix: InnerParam) -> VXML {
  let location =
    prefix <> bc.blame.filename <> ":" <> ins(bc.blame.line_no) <> ":" <> "50"
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
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(blame, lines) -> {
      Ok([
        V(
          blame,
          "span",
          [],
          lines
            |> list.map(line_to_tooltip_span(_, param))
            |> list.intersperse(
              T(blame, [BlamedContent(blame, ""), BlamedContent(blame, "")]),
            ),
        ),
      ])
    }
    _ -> Ok([vxml])
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodesFancyTransform {
  transform(_, param)
  |> infra.prevent_node_to_nodes_transform_inside(["Math", "MathBlock"])
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = String
type InnerParam = Param

pub fn break_lines_into_span_tooltips(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "break_lines_into_span_tooltips",
      option.Some(string.inspect(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}

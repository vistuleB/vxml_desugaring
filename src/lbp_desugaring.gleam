import desugarers/add_attributes_desugarer.{add_attributes_desugarer}
import desugarers/break_up_text_nodes_by_double_dollars_desugarer.{
  break_up_text_nodes_by_double_dollars_desugarer,
}
import desugarers/helpers/add_attributes_helpers.{
  type AddAttributesExtraArgs, AddAttributesExtraArgs, Attribute,
}
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import infrastructure.{type DesugaringError, DesugaringError}
import vxml_parser.{type VXML}

const ins = string.inspect

fn get_root(vxmls: List(VXML), path: String) -> Result(VXML, DesugaringError) {
  case vxmls {
    [root] -> Ok(root)
    _ ->
      Error(DesugaringError(
        blame: vxml_parser.Blame("", 0, []),
        message: "found "
          <> ins(list.length)
          <> " != 1 root-level nodes in "
          <> path,
      ))
  }
}

pub fn desugar(vxmls: List(VXML), path) -> Result(VXML, DesugaringError) {
  let extra_1 =
    AddAttributesExtraArgs(["Section", "Item"], [Attribute("label", "test")])

  get_root(vxmls, path)
  |> result.then(add_attributes_desugarer(_, extra_1))
  |> result.then(break_up_text_nodes_by_double_dollars_desugarer(_))
}

pub fn main() {
  let path = "test/sample.vxml"

  case vxml_parser.parse_file(path, "sample", False) {
    Ok(vxmls) -> {
      case desugar(vxmls, path) {
        Ok(desugared) -> {
          vxml_parser.debug_print_vxmls("(add attribute desugarer)", [desugared])
        }

        Error(e) -> {
          io.println("there was a desugaring error: " <> ins(e))
        }
      }
    }

    Error(e) ->
      io.println("there was a parsing error for " <> path <> ": " <> ins(e))
  }
}

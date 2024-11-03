import infrastructure
import gleam/result
import desurageres/add_attributes_desugarer.{add_attributes_desugarer}
import desurageres/break_up_text_nodes_by_double_dollars_desugarer.{break_up_text_nodes_by_double_dollars_desugarer}
import desurageres/helpers/add_attributes_helpers.{Attribute, AddAttributesExtraArgs}

import gleam/io
import gleam/string
import vxml_parser.{type VXML}

const ins = string.inspect

fn pre_desugar(vxmls: List(VXML), file_path: String) -> Result(VXML, infrastructure.DesugaringError) {
  case vxmls {
    [one] -> Ok(one)
    _ ->  Error(infrastructure.DesugaringError(blame: vxml_parser.Blame(file_path, 0, []) , message: "Input should be inside one root"))
  }
}

pub fn desuger(vxmls: List(VXML), path) {
      use res <- result.try(pre_desugar(vxmls, path))
      use res <- result.try(add_attributes_desugarer(res, AddAttributesExtraArgs(to: ["Section", "Item"], attributes: [Attribute("label", "test")])))
      use res <- result.try(break_up_text_nodes_by_double_dollars_desugarer(res))

      Ok([res])
}

pub fn main() {

  let path = "test/sample.vxml"

  case vxml_parser.parse_file(path, "sample", False) {
    Ok(vxmls) -> {
      case desuger(vxmls, path) {
        Ok(desugared) -> {
          vxml_parser.debug_print_vxmls("(add attribute desugarer)", desugared)
        }
        Error(err) -> {
          io.println("there was a desugaring error: " <> ins(err))
        }
      }
    }
    Error(e) -> io.println("there was an error: " <> ins(e))
  }
}

import desurageres/add_attributes_desugarer.{add_attributes_desugarer_many}
import desurageres/helpers/add_attributes_helpers.{Attribute, AddAttributesExtraArgs}

import gleam/io
import gleam/string
import vxml_parser

const ins = string.inspect

pub fn main() {

  let path = "test/sample.vxml"

  case vxml_parser.parse_file(path, "sample", False) {
    Ok(vxmls) -> {

      let result = add_attributes_desugarer_many(vxmls, AddAttributesExtraArgs(to: ["Section", "Item"], attributes: [Attribute("label", "test")]))

      case result {
        Ok(desugared) -> {
          vxml_parser.debug_print_vxmls("(add attribute desugarer)", desugared)
          io.println("")
        }
        Error(err) -> {
          io.println("there was a desugaring error: " <> ins(err))
        }
      }

    }
    Error(e) -> io.println("there was an error: " <> ins(e))
  }
}

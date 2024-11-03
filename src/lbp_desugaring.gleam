import add_attributes
import gleam/io
import gleam/string
import vxml_parser

const ins = string.inspect

pub fn main() {

  let path = "test/sample.vxml"

  case vxml_parser.parse_file(path, "sample", False) {
    Ok(vxmls) -> {

      let result = add_attributes.add_attributes_desugarer_many(vxmls, add_attributes.AddAttributesExtraArgs(to: ["Section", "Item"], attributes: [add_attributes.Attribute("label", "test")]))

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

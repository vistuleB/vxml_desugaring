import gleeunit
import gleeunit/should
import infrastructure
import vxml.{V, BlamedAttribute}
import blamedlines.{Blame}
import desugarers/rename_attributes_by_function

pub fn main() {
  gleeunit.main()
}

pub fn rename_attributes_by_function_test() {
  let blame = Blame("test", 1, 0, [])
  let original_node = V(
    blame,
    "div",
    [
      BlamedAttribute(blame, "data-test", "value1"),
      BlamedAttribute(blame, "my-attr", "value2"),
      BlamedAttribute(blame, "another-long-name", "value3")
    ],
    []
  )
  
  let pipe = rename_attributes_by_function.rename_attributes_by_function(
    infrastructure.kabob_case_to_pascal_case
  )
  
  let result = case pipe.desugarer(original_node) {
    Ok(transformed) -> transformed
    Error(_) -> original_node
  }
  
  let assert V(_, _, attrs, _) = result
  
  // Check that attribute keys were transformed correctly
  attrs
  |> infrastructure.get_attribute_keys
  |> should.equal(["DataTest", "MyAttr", "AnotherLongName"])
}
import gleeunit
import gleeunit/should
import gleam/list
import infrastructure
import vxml.{V, T, BlamedAttribute}
import blamedlines.{Blame}

pub fn main() {
  gleeunit.main()
}

pub fn kabob_case_to_camel_case_test() {
  // Test basic kabob case to camel case conversion
  infrastructure.kabob_case_to_camel_case("hello-world")
  |> should.equal("helloWorld")
  
  // Test single word
  infrastructure.kabob_case_to_camel_case("hello")
  |> should.equal("hello")
  
  // Test multiple dashes
  infrastructure.kabob_case_to_camel_case("my-long-attribute-name")
  |> should.equal("myLongAttributeName")
  
  // Test empty string
  infrastructure.kabob_case_to_camel_case("")
  |> should.equal("")
  
  // Test single dash
  infrastructure.kabob_case_to_camel_case("-")
  |> should.equal("")
  
  // Test leading dash
  infrastructure.kabob_case_to_camel_case("-hello-world")
  |> should.equal("helloWorld")
  
  // Test trailing dash
  infrastructure.kabob_case_to_camel_case("hello-world-")
  |> should.equal("helloWorld")
  
  // Test multiple consecutive dashes
  infrastructure.kabob_case_to_camel_case("hello--world")
  |> should.equal("helloWorld")
  
  // Test single character words
  infrastructure.kabob_case_to_camel_case("a-b-c")
  |> should.equal("aBC")
  
  // Test numbers
  infrastructure.kabob_case_to_camel_case("data-2-test")
  |> should.equal("data2Test")
}

pub fn has_class_test() {
  let blame = Blame("test", 1, 0, [])
  
  // Test node with single class that matches
  let node_with_class = V(
    blame,
    "div",
    [BlamedAttribute(blame, "class", "my-class")],
    []
  )
  infrastructure.has_class(node_with_class, "my-class")
  |> should.equal(True)
  
  // Test node with multiple classes, one matches
  let node_with_multiple_classes = V(
    blame,
    "div", 
    [BlamedAttribute(blame, "class", "first-class my-class last-class")],
    []
  )
  infrastructure.has_class(node_with_multiple_classes, "my-class")
  |> should.equal(True)
  
  // Test node with classes but none match
  let node_with_other_classes = V(
    blame,
    "div",
    [BlamedAttribute(blame, "class", "other-class different-class")],
    []
  )
  infrastructure.has_class(node_with_other_classes, "my-class")
  |> should.equal(False)
  
  // Test node with no class attribute
  let node_without_class = V(
    blame,
    "div",
    [BlamedAttribute(blame, "id", "some-id")],
    []
  )
  infrastructure.has_class(node_without_class, "my-class")
  |> should.equal(False)
  
  // Test node with empty class attribute
  let node_with_empty_class = V(
    blame,
    "div",
    [BlamedAttribute(blame, "class", "")],
    []
  )
  infrastructure.has_class(node_with_empty_class, "my-class")
  |> should.equal(False)
  
  // Test partial class name match (should return False)
  let node_with_partial_match = V(
    blame,
    "div",
    [BlamedAttribute(blame, "class", "my-class-extended")],
    []
  )
  infrastructure.has_class(node_with_partial_match, "my-class")
  |> should.equal(False)
}

pub fn filter_descendants_test() {
  let blame = Blame("test", 1, 0, [])
  
  // Create a nested structure for testing
  // <div class="parent">
  //   <span class="child">text</span>
  //   <div class="nested">
  //     <p class="deep">deep content</p>
  //     <span class="deeper">deeper content</span>
  //   </div>
  //   <p class="sibling">sibling content</p>
  // </div>
  
  let deep_p = V(
    blame,
    "p",
    [BlamedAttribute(blame, "class", "deep")],
    []
  )
  
  let deeper_span = V(
    blame,
    "span", 
    [BlamedAttribute(blame, "class", "deeper")],
    []
  )
  
  let nested_div = V(
    blame,
    "div",
    [BlamedAttribute(blame, "class", "nested")],
    [deep_p, deeper_span]
  )
  
  let child_span = V(
    blame,
    "span",
    [BlamedAttribute(blame, "class", "child")],
    []
  )
  
  let sibling_p = V(
    blame,
    "p",
    [BlamedAttribute(blame, "class", "sibling")],
    []
  )
  
  let parent_div = V(
    blame,
    "div",
    [BlamedAttribute(blame, "class", "parent")],
    [child_span, nested_div, sibling_p]
  )
  
  // Test filtering by tag - should find all p tags in descendants
  let p_tags = infrastructure.filter_descendants(parent_div, fn(node) {
    infrastructure.is_v_and_tag_equals(node, "p")
  })
  p_tags |> list.length |> should.equal(2)
  
  // Test filtering by tag - should find all span tags in descendants
  let span_tags = infrastructure.filter_descendants(parent_div, fn(node) {
    infrastructure.is_v_and_tag_equals(node, "span")
  })
  span_tags |> list.length |> should.equal(2)
  
  // Test filtering by class - should find nodes with "deep" class
  let deep_nodes = infrastructure.filter_descendants(parent_div, fn(node) {
    infrastructure.has_class(node, "deep")
  })
  deep_nodes |> list.length |> should.equal(1)
  
  // Test that root is not included - filter for "parent" class should return empty
  let parent_nodes = infrastructure.filter_descendants(parent_div, fn(node) {
    infrastructure.has_class(node, "parent")
  })
  parent_nodes |> list.length |> should.equal(0)
  
  // Test with text node - should return empty list
  let text_node = T(blame, [])
  let text_results = infrastructure.filter_descendants(text_node, fn(_) { True })
  text_results |> list.length |> should.equal(0)
  
  // Test with condition that matches nothing
  let no_matches = infrastructure.filter_descendants(parent_div, fn(node) {
    infrastructure.has_class(node, "nonexistent")
  })
  no_matches |> list.length |> should.equal(0)
}

pub fn descendants_with_key_value_test() {
  let blame = Blame("test", 1, 0, [])
  
  // Create a nested structure for testing
  // <div class="parent">
  //   <span data-id="child1">text</span>
  //   <div data-id="nested">
  //     <p data-id="deep">deep content</p>
  //     <span data-id="child1">deeper content</span>
  //   </div>
  //   <p data-id="sibling">sibling content</p>
  // </div>
  
  let deep_p = V(
    blame,
    "p",
    [BlamedAttribute(blame, "data-id", "deep")],
    []
  )
  
  let deeper_span = V(
    blame,
    "span", 
    [BlamedAttribute(blame, "data-id", "child1")],
    []
  )
  
  let nested_div = V(
    blame,
    "div",
    [BlamedAttribute(blame, "data-id", "nested")],
    [deep_p, deeper_span]
  )
  
  let child_span = V(
    blame,
    "span",
    [BlamedAttribute(blame, "data-id", "child1")],
    []
  )
  
  let sibling_p = V(
    blame,
    "p",
    [BlamedAttribute(blame, "data-id", "sibling")],
    []
  )
  
  let parent_div = V(
    blame,
    "div",
    [BlamedAttribute(blame, "class", "parent")],
    [child_span, nested_div, sibling_p]
  )
  
  // Test finding descendants with specific key-value pair
  let child1_nodes = infrastructure.descendants_with_key_value(parent_div, "data-id", "child1")
  child1_nodes |> list.length |> should.equal(2)
  
  // Test finding single descendant
  let deep_nodes = infrastructure.descendants_with_key_value(parent_div, "data-id", "deep")
  deep_nodes |> list.length |> should.equal(1)
  
  // Test finding no matches
  let no_matches = infrastructure.descendants_with_key_value(parent_div, "data-id", "nonexistent")
  no_matches |> list.length |> should.equal(0)
  
  // Test that root is not included - parent div has class="parent", not data-id
  let parent_matches = infrastructure.descendants_with_key_value(parent_div, "class", "parent")
  parent_matches |> list.length |> should.equal(0)
  
  // Test with text node - should return empty list
  let text_node = T(blame, [])
  let text_results = infrastructure.descendants_with_key_value(text_node, "data-id", "anything")
  text_results |> list.length |> should.equal(0)
}

pub fn descendants_with_tag_test() {
  let blame = Blame("test", 1, 0, [])
  
  // Create a nested structure for testing
  // <div class="parent">
  //   <span>text</span>
  //   <div class="nested">
  //     <p>deep content</p>
  //     <span>deeper content</span>
  //   </div>
  //   <p>sibling content</p>
  // </div>
  
  let deep_p = V(
    blame,
    "p",
    [BlamedAttribute(blame, "class", "deep")],
    []
  )
  
  let deeper_span = V(
    blame,
    "span", 
    [BlamedAttribute(blame, "class", "deeper")],
    []
  )
  
  let nested_div = V(
    blame,
    "div",
    [BlamedAttribute(blame, "class", "nested")],
    [deep_p, deeper_span]
  )
  
  let child_span = V(
    blame,
    "span",
    [BlamedAttribute(blame, "class", "child")],
    []
  )
  
  let sibling_p = V(
    blame,
    "p",
    [BlamedAttribute(blame, "class", "sibling")],
    []
  )
  
  let parent_div = V(
    blame,
    "div",
    [BlamedAttribute(blame, "class", "parent")],
    [child_span, nested_div, sibling_p]
  )
  
  // Test finding descendants with specific tag
  let p_tags = infrastructure.descendants_with_tag(parent_div, "p")
  p_tags |> list.length |> should.equal(2)
  
  // Test finding all span tags in descendants
  let span_tags = infrastructure.descendants_with_tag(parent_div, "span")
  span_tags |> list.length |> should.equal(2)
  
  // Test finding single tag type
  let div_tags = infrastructure.descendants_with_tag(parent_div, "div")
  div_tags |> list.length |> should.equal(1)
  
  // Test finding no matches
  let no_matches = infrastructure.descendants_with_tag(parent_div, "article")
  no_matches |> list.length |> should.equal(0)
  
  // Test that root is not included - parent div should not be in results
  let root_tags = infrastructure.descendants_with_tag(parent_div, "div")
  root_tags |> list.length |> should.equal(1) // only the nested div, not the parent
  
  // Test with text node - should return empty list
  let text_node = T(blame, [])
  let text_results = infrastructure.descendants_with_tag(text_node, "p")
  text_results |> list.length |> should.equal(0)
}
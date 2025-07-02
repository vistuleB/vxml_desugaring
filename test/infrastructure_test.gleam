import gleeunit
import gleeunit/should
import infrastructure

pub fn main() {
  gleeunit.main()
}

pub fn kabob_case_to_pascal_case_test() {
  // Test basic kabob case to pascal case conversion
  infrastructure.kabob_case_to_pascal_case("hello-world")
  |> should.equal("HelloWorld")
  
  // Test single word
  infrastructure.kabob_case_to_pascal_case("hello")
  |> should.equal("Hello")
  
  // Test multiple dashes
  infrastructure.kabob_case_to_pascal_case("my-long-attribute-name")
  |> should.equal("MyLongAttributeName")
  
  // Test empty string
  infrastructure.kabob_case_to_pascal_case("")
  |> should.equal("")
  
  // Test single dash
  infrastructure.kabob_case_to_pascal_case("-")
  |> should.equal("")
  
  // Test leading dash
  infrastructure.kabob_case_to_pascal_case("-hello-world")
  |> should.equal("HelloWorld")
  
  // Test trailing dash
  infrastructure.kabob_case_to_pascal_case("hello-world-")
  |> should.equal("HelloWorld")
  
  // Test multiple consecutive dashes
  infrastructure.kabob_case_to_pascal_case("hello--world")
  |> should.equal("HelloWorld")
  
  // Test single character words
  infrastructure.kabob_case_to_pascal_case("a-b-c")
  |> should.equal("ABC")
  
  // Test numbers
  infrastructure.kabob_case_to_pascal_case("data-2-test")
  |> should.equal("Data2Test")
}
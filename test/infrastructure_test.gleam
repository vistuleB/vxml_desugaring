import gleeunit
import gleeunit/should
import infrastructure

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
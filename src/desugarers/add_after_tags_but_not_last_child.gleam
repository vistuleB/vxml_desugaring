import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import vxml.{type VXML, BlamedAttribute, V, T}

fn add_before_2nd_or_above(
  vxmls: List(VXML),
  inner: InnerParam,
) -> List(VXML) {
  case vxmls {
    [first, V(blame, tag, _, _) as second, ..rest] -> {
      case dict.get(inner, tag) {
        Error(Nil) -> [
          first, 
        ..add_before_2nd_or_above([second, ..rest], inner)
        ]
        Ok(#(new_element_tag, new_element_attributes)) -> [
          first,
          V(
            infra.blame_us("add_after_tags_but_not_last_child"),
            new_element_tag,
            list.map(new_element_attributes, fn(pair) {BlamedAttribute(blame, pair.0, pair.1)}),
            [],
          ),
          ..add_before_2nd_or_above([second, ..rest], inner)
        ]
      }
    }
    [first, T(_, _) as second, ..rest] -> [
      first,
      ..add_before_2nd_or_above([second, ..rest], inner)
    ]
    _ -> vxmls
  }
}

fn transform_children(
  children: List(VXML),
  inner: InnerParam,
) -> List(VXML) {
  children
  |> list.reverse
  |> add_before_2nd_or_above(inner)
  |> list.reverse
}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    V(_, _, _, _) -> 
      Ok(V(..vxml, children: transform_children(vxml.children, inner)))
    _ -> Ok(vxml)
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(infra.triples_to_dict(param))
}

type Param =
  List(#(String,        String,          List(#(String, String))))
//       ↖              ↖                ↖
//       insert after   tag name         attributes
//       tag of this    of new element
//       name (except
//       if last child)

type InnerParam =
  Dict(String, #(String, List(#(String, String))))

const name = "add_after_tags_but_not_first_child_tags"
const constructor =  add_after_tags_but_not_first_child_tags

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// adds new elements after specified tags but not 
/// if they are the last child
pub fn add_after_tags_but_not_first_child_tags(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// adds new elements after specified tags but not 
/// if they are the last child
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
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
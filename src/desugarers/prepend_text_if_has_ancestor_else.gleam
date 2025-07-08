import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, Pipe} as infra
import vxml.{ type VXML, BlamedContent, T, V }

fn transform(
  vxml: VXML,
  ancestors: List(VXML),
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case infra.use_list_pair_as_dict(inner, tag) {
        Ok(#(ancestor_tag, if_version, else_version)) -> {
          let ancestor_tags = ancestors |> list.map(infra.get_tag)
          let text = case list.contains(ancestor_tags, ancestor_tag) {
            True -> if_version
            False -> else_version
          }
          let contents = string.split(text, "\n")
          let new_text_node =
            T(
              blame,
              list.map(
                contents,
                fn (content) { BlamedContent(blame, content) }
              )
            )
          Ok(
            V(blame, tag, attrs, [new_text_node, ..children])
          )
        }
        Error(Nil) -> Ok(vxml)
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeFancyTransform {
  fn(vxml, ancestors, _, _, _) {
    transform(vxml, ancestors, inner)
  }
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  param
  |> infra.quads_to_pairs
  |> Ok
}

type Param =
  List(#(String, String,    String,      String))
//       ↖       ↖          ↖            ↖
//       tag     ancestor   if_version   else_version

type InnerParam =
  List(#(String, #(String, String, String)))

pub const desugarer_name = "prepend_text_if_has_ancestor_else"
pub const desugarer_pipe = prepend_text_if_has_ancestor_else

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// prepend one of two specified text fragments to
/// nodes of a certain tag depending on wether the 
/// node has an ancestor of specified type or not
pub fn prepend_text_if_has_ancestor_else(param: Param) -> Pipe {
  Pipe(
    desugarer_name,
    option.Some(ins(param)),
    "
/// prepend one of two specified text fragments to
/// nodes of a certain tag depending on wether the 
/// node has an ancestor of specified type or not
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
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}

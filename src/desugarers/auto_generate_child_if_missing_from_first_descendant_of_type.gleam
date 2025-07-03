import gleam/option
import gleam/string.{inspect as ins}
import gleam/list
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  let #(parent_tag, child_tag, descendant_tag) = inner
  case node {
    V(_, tag, _, _) if tag == parent_tag -> {
      // return early if we have a child of tag child_tag:
      use _ <- infra.on_ok_on_error(
        infra.children_with_tag(node, child_tag) |> list.first,
        fn(_) {Ok(node)},
      )

      // return early if we don't have a descendant of tag descendant_tag:
      use descendant <- infra.on_error_on_ok(
        infra.descendants_with_tag(node, descendant_tag) |> list.first,
        fn (_) {Ok(node)},
      )

      let assert V(_, _, _, _) = descendant

      Ok(V(
        ..node,
        children: [
          V(
            ..descendant,
            tag: child_tag,
          ),
          ..node.children
        ]
      ))
    }

    _ -> Ok(node)
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String, String, String)
//             ↖       ↖       ↖
//             parent  child   descendant
//             tag     tag     tag

type InnerParam = Param

pub const desugarer_name = "auto_generate_child_if_missing_from_first_descendant_of_type"
pub const desugarer_pipe = auto_generate_child_if_missing_from_first_descendant_of_type

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------
/// Given arguments
/// ```
/// parent_tag, child_tag, descendant_tag
/// ```
/// will, for each node of tag `parent_tag`,
/// generate, if the node has no existing
/// children tag `child_tag`, a node of type
/// `child_tag` by copy-pasting the contents
/// and attributes of the first descendant
/// of `parent_tag` that has tag `descendant_tag`.
/// If no such descendant exists, does nothing
/// to the node of tag `parent_tag`.
pub fn auto_generate_child_if_missing_from_first_descendant_of_type(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// Given arguments
/// ```
/// parent_tag, child_tag, descendant_tag
/// ```
/// will, for each node of tag `parent_tag`,
/// generate, if the node has no existing
/// children tag `child_tag`, a node of type
/// `child_tag` by copy-pasting the contents
/// and attributes of the first descendant
/// of `parent_tag` that has tag `descendant_tag`.
/// If no such descendant exists, does nothing
/// to the node of tag `parent_tag`.
      ",
    ),
    desugarer: case param_to_inner_param(param) {
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

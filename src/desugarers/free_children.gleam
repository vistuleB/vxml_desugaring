import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn child_must_escape(child: VXML, parent_tag: String, inner: InnerParam) -> Bool {
  case child {
    T(_, _) -> False
    V(_, child_tag, _, _) -> list.contains(inner, #(child_tag, parent_tag))
  }
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(blame, tag, attributes, children) -> {
      children
      |> infra.either_or_misceginator(child_must_escape(_, tag, inner))
      |> infra.regroup_ors
      |> infra.map_either_ors(
        fn(either: VXML) -> VXML { either },
        fn(or: List(VXML)) -> VXML { V(blame, tag, attributes, or) },
      )
      |> Ok
    }
    _ -> Ok([node])
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String,       String))
//       ↖            ↖
//       tag of       ...when
//       child to     parent is
//       free from    this tag
//       parent

type InnerParam = Param

pub const desugarer_name = "free_children"
pub const desugarer_pipe = free_children

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------
/// given a parent-child structure of the form
///
///     A[parent]
///
///         B[child]
///
///         C[child]
///
///         B[child]
///
///         D[child]
///
///         C[child]
///
///         B[child]
///
/// where A, B, C, D represent tags, a call to
///
/// free_children([#(A, C)])
///
/// will for example result in the updated
/// structure
///
///     A[parent]
///
///         B[child]
///
///     C[parent]
///
///     A[parent]
///
///         B[child]
///
///         D[child]
///
///     C[parent]
///
///     A[parent]
///
///         B[child]
///
/// with the original attribute values of A
/// copied over to the newly created 'copies' of
/// A
pub fn free_children(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// given a parent-child structure of the form
///
///     A[parent]
///
///         B[child]
///
///         C[child]
///
///         B[child]
///
///         D[child]
///
///         C[child]
///
///         B[child]
///
/// where A, B, C, D represent tags, a call to
///
/// free_children([#(A, C)])
///
/// will for example result in the updated
/// structure
///
///     A[parent]
///
///         B[child]
///
///     C[parent]
///
///     A[parent]
///
///         B[child]
///
///         D[child]
///
///     C[parent]
///
///     A[parent]
///
///         B[child]
///
/// with the original attribute values of A
/// copied over to the newly created 'copies' of
/// A
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
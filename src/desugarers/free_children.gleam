import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn child_must_escape(child: VXML, parent_tag: String, inner: InnerParam) -> Bool {
  case child {
    T(_, _) -> False
    V(_, child_tag, _, _) -> list.contains(inner, #(child_tag, parent_tag))
  }
}

fn nodemap(
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

fn nodemap_factory(inner: InnerParam) -> n2t.OneToManyNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
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

const name = "free_children"
const constructor = free_children

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
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
pub fn free_children(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
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
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
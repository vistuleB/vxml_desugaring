import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

const ins = string.inspect

fn child_must_escape(child: VXML, parent_tag: String, param: InnerParam) -> Bool {
  case child {
    T(_, _) -> False
    V(_, child_tag, _, _) -> list.contains(param, #(child_tag, parent_tag))
  }
}

fn transform(
  node: VXML,
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(blame, tag, attributes, children) -> {
      children
      |> infra.either_or_misceginator(child_must_escape(_, tag, param))
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

fn transform_factory(param: InnerParam) -> infra.NodeToNodesTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String, String))

//**********************************
// type Param = List(#(String,         String      ))
//                       ↖ tag of      ↖ ...when
//                         child to      parent is
//                         free from     this tag
//                         parent
//**********************************

type InnerParam = Param

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
      "free_children",
      Some(ins(param)),
      "
given a parent-child structure of the form

    A[parent]

        B[child]

        C[child]

        B[child]

        D[child]

        C[child]

        B[child]

where A, B, C, D represent tags, a call to

free_children([#(A, C)])

will for example result in the updated
structure

    A[parent]

        B[child]

    C[parent]

    A[parent]

        B[child]

        D[child]

    C[parent]

    A[parent]

        B[child]

with the original attribute values of A
copied over to the newly created 'copies' of
A
",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}

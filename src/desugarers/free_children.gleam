import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

const ins = string.inspect

fn child_must_escape(child: VXML, parent_tag: String, extra: Extra) -> Bool {
  case child {
    T(_, _) -> False
    V(_, child_tag, _, _) -> list.contains(extra, #(child_tag, parent_tag))
  }
}

fn param_transform(
  node: VXML,
  extra: Extra,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(blame, tag, attributes, children) -> {
      children
      |> infra.either_or_misceginator(child_must_escape(_, tag, extra))
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

//**********************************
// type Extra = List(#(String,         String      ))
//                       ↖ tag of      ↖ ...when
//                         child to      parent is
//                         free from     this tag
//                         parent
//**********************************
type Extra =
  List(#(String, String))

fn transform_factory(extra: Extra) -> infra.NodeToNodesTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(extra))
}

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
pub fn free_children(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "free_children",
      Some(ins(extra)),
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
    desugarer: desugarer_factory(extra),
  )
}

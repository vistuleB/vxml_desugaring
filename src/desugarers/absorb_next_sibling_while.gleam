import gleam/result
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn get_absorbing_tags(
  vxml: VXML,
  inner: InnerParam,
) -> List(String) {
  case vxml {
    T(_, _) -> []
    V(_, tag, _, _) -> 
      dict.get(inner, tag)
      |> result.map_error(fn(_){[]})
      |> result.unwrap_both
  }
}

fn update_children(
  children: List(VXML),
  inner: InnerParam,
) -> List(VXML) {
  use #(first, rest) <- infra.on_error_on_ok(
    infra.first_rest(children),
    fn(_) {[]},
  )

  let first_tags_to_be_absorbed = get_absorbing_tags(first, inner)

  list.fold(
    over: rest,
    from: #(first, [], first_tags_to_be_absorbed),
    with: fn(
      state: #(VXML, List(VXML), List(String)),
      incoming: VXML,
    ) -> #(VXML, List(VXML), List(String)) {
      let #(previous_sibling, already_bundled, tags_to_be_absorbed) = state
      case incoming {
        T(_, _) -> #(incoming, [previous_sibling, ..already_bundled], [])
        V(_, incoming_tag, _, _) -> {
          case list.contains(tags_to_be_absorbed, incoming_tag) {
            False -> #(
              incoming,
              [previous_sibling, ..already_bundled],
              get_absorbing_tags(incoming, inner),
            )
            True -> {
              let assert V(_, _, _, prev_children) = previous_sibling
              #(
                V(..previous_sibling, children: list.append(prev_children, [incoming])),
                already_bundled,
                tags_to_be_absorbed,
              )
            }
          }
        }
      }
    }
  )
  |> fn (state) {[state.0, ..state.1]}
  |> list.reverse
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attributes, children) ->
      Ok(V(blame, tag, attributes, update_children(children, inner)))
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
  Ok(infra.aggregate_on_first(param))
}

type Param =
  List(#(String,        String))
//       ↖              ↖
//       tag that       tag that will
//       will absorb    be absorbed by
//       next sibling   previous sibling

type InnerParam =
  Dict(String, List(String))

/// if the arguments are [#("Tag1", "Child1"),
/// ("Tag1", "Child1")] then will cause Tag1
/// nodes to absorb all subsequent Child1 & Child2
/// nodes, as long as they come immediately after
/// Tag1 (in any order)
pub fn absorb_next_sibling_while(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "absorb_next_sibling_while",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// if the arguments are [#(\"Tag1\", \"Child1\"),
/// (\"Tag1\", \"Child1\")] then will cause Tag1
/// nodes to absorb all subsequent Child1 & Child2
/// nodes, as long as they come immediately after
/// Tag1 (in any order)
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

pub fn test_group() -> infra.AssertiveTestGroup(Param) {
  infra.AssertiveTestGroup(
    name: "absorb_next_sibling_while",
    pipe: absorb_next_sibling_while,
    tests: [
    infra.AssertiveTest(
      param: [#("Absorber", "Absorbee")],
      source: "
<> Root
    <> Absorber
        <> 
            \"text\"
    <> Absorbee
    <> last
      ",
      expected: "
<> Root
    <> Absorber
        <> 
            \"text\"
        <> Absorbee
    <> last
      ",
    ),
    infra.AssertiveTest(
      param: [#("Absorber", "Absorbee")],
      source: "
<> Root
    <> Absorber
        <> 
            \"text\"
    <> Absorbee
    <> Absorbee
    <> last
      ",
      expected: "
<> Root
    <> Absorber
        <> 
            \"text\"
        <> Absorbee
        <> Absorbee
    <> last
      ",
    )
  ])
}
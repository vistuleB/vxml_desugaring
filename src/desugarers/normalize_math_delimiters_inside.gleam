import gleam/result
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe, type LatexDelimiterPair} as infra
import vxml.{type VXML, T, V}

fn strip_delimiter_pair_if_there(
  t_node: VXML,
  to_strip: LatexDelimiterPair,
) -> Result(VXML, DesugaringError) {
  let #(opening, closing)  = infra.opening_and_closing_string_for_pair(to_strip)
  let assert T(blame, lines) = 
    t_node
    |> infra.t_trim_start
    |> infra.t_trim_end

  let assert [first_line, ..] = lines
  let assert [last_line, ..] = lines |> list.reverse

  case string.starts_with(first_line.content, opening), 
       string.ends_with(last_line.content, closing)
  {
    False, False -> Ok(t_node)
    True, True -> {
      T(blame, lines)
      |> infra.t_drop_start(opening |> string.length)
      |> infra.t_drop_end(closing |> string.length)
      |> Ok
    }
    True, _ -> Error(DesugaringError(blame, "Missing closing '" <> closing <> "' delimiter"))
    _, True -> Error(DesugaringError(blame, "Missing opening '" <> opening <> "' delimiter"))
  }
}

fn strip_all_delimiter_pairs(
  t_node: VXML,
) -> Result(VXML, DesugaringError) {
  let assert T(_, _) = t_node
  list.try_fold(infra.latex_delimiter_pairs_list(), t_node, fn(node, pair){
    strip_delimiter_pair_if_there(node, pair)
  })
}

fn normalize_delimiters(
  t_node: VXML,
  target_delimiter_to_use: LatexDelimiterPair,
) -> Result(VXML, DesugaringError) {
  let assert T(_, _) = t_node
  let #(opening_delimiter, closing_delimiter) = infra.opening_and_closing_string_for_pair(target_delimiter_to_use)

  use stripped_t_node <- result.try(strip_all_delimiter_pairs(t_node))

  stripped_t_node 
  |> infra.t_start_insert_text(opening_delimiter)
  |> infra.t_end_insert_text(closing_delimiter)
  |> Ok
}

fn assert_node_has_one_t(node: VXML) -> Result(VXML, DesugaringError) {
  let assert V(b, _, _ , children) = node
  case children {
    [T(b, c)] -> Ok(T(b, c))
    _ -> Error(DesugaringError(b, "Node should have 1 text node"))
  }
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  let #(tags, delimiter_pair) = inner
  case node {
    V(b, tag, a , _) -> {
      use <- infra.on_false_on_true(
        list.contains(tags, tag),
        Ok(node)
      )
      use t_node <- result.try(assert_node_has_one_t(node))
      use normalized <- result.try(normalize_delimiters(t_node, delimiter_pair))
      Ok(V(b, tag, a, [normalized]))
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

type Param =
  #(List(String), LatexDelimiterPair)
//  ↖             ↖
//  tags          delimiter pair
//                to use

type InnerParam = Param

/// adds flexiblilty to user's custom
/// mathblock element
/// ```
/// |> Mathblock
///     math
/// ```
/// should be same as
/// ```
/// |> Mathblock
///     $$math$$
/// ```
pub fn normalize_math_delimiters_inside(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "normalize_math_delimiters_inside",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// adds flexiblilty to user's custom
/// mathblock element
/// ```
/// |> Mathblock
///     math
/// ```
/// should be same as
/// ```
/// |> Mathblock
///     $$math$$
/// ```
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
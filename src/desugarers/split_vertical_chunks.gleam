import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type Blame, type VXML, T, V}

fn is_blank_line(vxml: VXML) -> #(Bool, Blame) {
  case vxml {
    T(blame, _) -> #(False, blame)
    V(blame, tag, _, _) ->
      case tag == "WriterlyBlankLine" {
        True -> #(True, blame)
        False -> #(False, blame)
      }
  }
}

fn eat_blank_lines(vxmls: List(VXML)) -> List(VXML) {
  case vxmls {
    [] -> []
    [first, ..rest] ->
      case is_blank_line(first) {
        #(True, _) -> eat_blank_lines(rest)
        #(False, _) -> vxmls
      }
  }
}

fn prepend_to_second_element_of_optional_pair(
  first: a,
  list: Option(#(b, List(a))),
) -> List(a) {
  case list {
    None -> [first]
    Some(#(_, list)) -> [first, ..list]
  }
}

fn eat_and_record_non_blank_lines(
  vxmls: List(VXML),
) -> #(Option(#(Blame, List(VXML))), List(VXML)) {
  // returns #(None, ..) if vxmls is empty or starts with a blank line,
  // else #(Some(blame, ..), ..) where 'blame' is blame of first line
  case vxmls {
    [] -> #(None, [])
    [first, ..rest] -> {
      case is_blank_line(first) {
        #(True, _) -> #(None, eat_blank_lines(rest))
        #(False, blame) -> {
          let #(prefix, suffix) = eat_and_record_non_blank_lines(rest)
          #(
            Some(#(
              blame,
              prepend_to_second_element_of_optional_pair(first, prefix),
            )),
            suffix,
          )
        }
      }
    }
  }
}

fn prepend_if_not_none(m: Option(a), z: List(a)) {
  case m {
    None -> z
    Some(thing) -> [thing, ..z]
  }
}

fn lists_of_non_blank_line_chunks(
  vxmls: List(VXML),
) -> List(#(Blame, List(VXML))) {
  let #(first_chunk, remaining_vxmls_after_first_chunk) =
    eat_and_record_non_blank_lines(vxmls)
  case remaining_vxmls_after_first_chunk {
    [] -> []
    _ -> lists_of_non_blank_line_chunks(remaining_vxmls_after_first_chunk)
  }
  |> prepend_if_not_none(first_chunk, _)
}

pub fn chunk_constructor(
  blame_and_children: #(Blame, List(VXML)),
  tag: String,
  tag_wrapper_pairs: List(#(String, String)),
) -> VXML {
  let #(blame, children) = blame_and_children

  let #(_, wrapper) =
    tag_wrapper_pairs
    |> list.find(fn(pair) {
      let #(tag_, _) = pair
      tag_ == tag
    })
    |> result.unwrap(#("", "VerticalChunk"))

  V(blame, wrapper, [], children)
}

fn split_vertical_chunks_transform(
  vxml: VXML,
  tag_wrapper_pairs: List(#(String, String)),
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      let new_children =
        lists_of_non_blank_line_chunks(children)
        |> list.map(chunk_constructor(_, tag, tag_wrapper_pairs))
      Ok(V(blame, tag, attrs, new_children))
    }
  }
}

type Extras =
  #(
    List(
      String,
      // List to exclude from vertical chunking
    ),
    List(#(String, String)),
    // List of tag and wrapper pairs
  )

fn transform_factory(extras: Extras) -> infra.NodeToNodeFancyTransform {
  let #(excluded_tags, wrappers) = extras
  infra.prevent_node_to_node_transform_inside(
    split_vertical_chunks_transform(_, wrappers),
    excluded_tags,
  )
}

fn desugarer_factory(extras: Extras) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(extras))
}

pub fn split_vertical_chunks(extras: Extras) -> Pipe {
  #(
    DesugarerDescription("split_vertical_chunks_desugarer", option.None, "..."),
    desugarer_factory(extras),
  )
}

import blamedlines.{type Blame}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{
  type BlamedAttribute, type VXML, BlamedAttribute, BlamedContent, T, V,
}

const ins = string.inspect

fn filter_out_handle_attributes(
  attributes: List(BlamedAttribute),
) -> #(List(BlamedAttribute), List(BlamedAttribute)) {
  list.fold(
    over: attributes,
    from: #([], []),
    with: fn(pairs, blamed_attribute) {
      let #(current_attrs, current_handles) = pairs
      let BlamedAttribute(_, key, _) = blamed_attribute
      case key == "handle" {
        True -> #(current_attrs, [blamed_attribute, ..current_handles])
        False -> #([blamed_attribute, ..current_attrs], current_handles)
      }
    },
  )
}

fn attribute_value(blamed_attribute: BlamedAttribute) -> String {
  let BlamedAttribute(_, _, value) = blamed_attribute
  value
}

fn counter_attributes_for_node(
  blame: Blame,
  tag: String,
  tuples: List(ManyStrings),
) {
  list.fold(over: tuples, from: [], with: fn(attributes_so_far, tuple) -> List(
    BlamedAttribute,
  ) {
    let #(parent, counter_name, _, _, _, _) = tuple
    case parent == tag {
      True -> [
        BlamedAttribute(blame, "counter", counter_name),
        ..attributes_so_far
      ]
      False -> attributes_so_far
    }
  })
}

fn tuples_for_tag(tag: String, tuples: Extra) -> List(ManyStrings) {
  case tuples {
    [] -> []
    [#(_, _, tag_name, _, _, _) as first, ..rest] ->
      case tag_name == tag {
        True -> [first, ..tuples_for_tag(tag, rest)]
        False -> tuples_for_tag(tag, rest)
      }
  }
}

fn first_in_list_1_for_which_exists_in_list_2(
  list_1: List(a),
  list_2: List(b),
  comparer: fn(a, b) -> Bool,
) -> Option(b) {
  case list_1 {
    [] -> None
    [first, ..rest] ->
      case list.find(list_2, comparer(first, _)) {
        Ok(thing) -> Some(thing)
        Error(Nil) ->
          first_in_list_1_for_which_exists_in_list_2(rest, list_2, comparer)
      }
  }
}

fn first_ancestor_that_appears_as_a_parent_in_tuples(
  ancestors: List(VXML),
  tuples: List(ManyStrings),
) -> Option(ManyStrings) {
  first_in_list_1_for_which_exists_in_list_2(ancestors, tuples, fn(vxml, tuple) {
    let assert V(_, ancestor, _, _) = vxml
    let #(parent, _, _, _, _, _) = tuple
    ancestor == parent
  })
}

fn ancestors_contain(ancestors: List(VXML), particular_tag: String) -> Bool {
  list.any(ancestors, fn(ancestor) {
    let assert V(_, name, _, _) = ancestor
    name == particular_tag
  })
}

fn param_transform(
  node: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  tuples: Extra,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attributes_v0, children) -> {
      let #(attributes_v1, handle_attributes) =
        filter_out_handle_attributes(attributes_v0)
      let attributes_v2 =
        list.flatten([
          counter_attributes_for_node(blame, tag, tuples),
          attributes_v1,
        ])
      let our_tuples = tuples_for_tag(tag, tuples)
      case
        first_ancestor_that_appears_as_a_parent_in_tuples(ancestors, our_tuples)
      {
        None -> {
          let attributes_v3 = list.append(attributes_v2, handle_attributes)
          Ok(V(blame, tag, attributes_v3, children))
        }
        Some(tuple) -> {
          let #(tag_that_declared_counter, counter_name, _, pre, post, fallback) =
            tuple
          case ancestors_contain(ancestors, tag_that_declared_counter) {
            False -> {
              let attributes_v3 = list.append(attributes_v2, handle_attributes)
              let text_node_to_insert =
                T(blame, [BlamedContent(blame, fallback)])
              Ok(
                V(blame, tag, attributes_v3, [text_node_to_insert, ..children]),
              )
            }
            True -> {
              let attributes_v3 = attributes_v2
              let handle_assignments_string = case
                list.is_empty(handle_attributes)
              {
                True -> ""
                False ->
                  {
                    handle_attributes
                    |> list.map(attribute_value)
                    |> string.join("<<")
                  }
                  <> "<<"
              }
              let text_node_to_insert =
                T(blame, [
                  BlamedContent(
                    blame,
                    pre
                      <> handle_assignments_string
                      <> "::++"
                      <> counter_name
                      <> post,
                  ),
                ])
              Ok(
                V(blame, tag, attributes_v3, [text_node_to_insert, ..children]),
              )
            }
          }
        }
      }
    }
  }
}

type ManyStrings =
  #(String, String, String, String, String, String)

//**********************************
// type Extra = List(#(String,         String,       String,        String,         String,             String))
//                       ↖ parent or     ↖ counter     ↖ element      ↖ pre-counter   ↖ post-counter      ↖ fallback phrase
//                         ancestor        name          to add         phrase          phrase              if element is encountered
//                         tag that                      title to                                           parent/ancestor that holds
//                         contains                                                                         counter
//                         counter
//**********************************
type Extra =
  List(ManyStrings)

fn check_uniqueness_generic(list: List(a)) -> Option(a) {
  case list {
    [] -> None
    [first, ..rest] ->
      case list.contains(rest, first) {
        True -> Some(first)
        False -> check_uniqueness_generic(rest)
      }
  }
}

fn check_uniqueness_extra(tuples: Extra) -> Option(#(String, String)) {
  tuples
  |> list.map(fn(tuple) {
    let #(parent, _, tag, _, _, _) = tuple
    #(parent, tag)
  })
  |> check_uniqueness_generic
}

fn transform_factory(extra: Extra) -> infra.NodeToNodeFancyTransform {
  fn(node, ancestors, s1, s2, s3) {
    param_transform(node, ancestors, s1, s2, s3, extra)
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(extra))
}

pub fn add_title_counters_and_titles_with_handle_assignments(
  extra: Extra,
) -> Pipe {
  #(
    DesugarerDescription(
      "add_title_counters_and_titles_with_handle_assignments",
      Some(ins(extra)),
      "...",
    ),
    case check_uniqueness_extra(extra) {
      Some(pair) -> {
        fn(vxml) {
          Error(DesugaringError(
            infra.get_blame(vxml),
            "duplicate parent-element pair in add_title_counters_and_titles_with_handle_assignments: "
              <> ins(pair),
          ))
        }
      }
      None -> desugarer_factory(extra)
    },
  )
}

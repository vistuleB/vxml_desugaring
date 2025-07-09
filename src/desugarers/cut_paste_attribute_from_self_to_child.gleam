import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V, type BlamedAttribute}

fn update_child(child: VXML, child_tag: String, attribute: BlamedAttribute)
-> VXML {
  case child {
    V(_, tag, _, _) if tag == child_tag ->
      V(..child, attributes: list.append(child.attributes, [attribute]))
    _ -> child
  }
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  let #(parent_tag, child_tag, key) = inner
  case node {
    V(_, tag, _, _) if tag == parent_tag -> {
      case infra.v_attribute_with_key(node, key) {
        option.None -> Ok(node)
        option.Some(attribute) -> {
          Ok(V(
            ..node,
            attributes: node.attributes |> list.filter(fn(x) { x.key != key }),
            children: node.children |> list.map(update_child(_, child_tag, attribute)),
          ))
        }
      }
    }
    _ -> Ok(node)
  }
}

fn transform_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
    transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, String, String)
//  ↖       ↖       ↖
//  parent  child   attribute
//  tag     tag     key

type InnerParam = Param

const name = "cut_paste_attribute_from_self_to_child"
const constructor = cut_paste_attribute_from_self_to_child

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------
/// For all nodes with a given `parent_tag`,
/// removes all attributes of a given key. If
/// the list of removed attributes is nonempty,
/// pastes the first element of the list to all
/// children of the `parent_tag` node that have
/// a given `child_tag` tag.
/// ```
/// #Param:
/// - parent_tag
/// - child_tag
/// - attribute_key
/// ```
pub fn cut_paste_attribute_from_self_to_child(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// For all nodes with a given `parent_tag`,
/// removes all attributes of a given key. If
/// the list of removed attributes is nonempty,
/// pastes the first element of the list to all
/// children of the `parent_tag` node that have
/// a given `child_tag` tag.
/// ```
/// #Param:
/// - parent_tag
/// - child_tag
/// - attribute_key
/// ```
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
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}

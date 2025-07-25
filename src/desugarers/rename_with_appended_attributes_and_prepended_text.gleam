import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V, T, BlamedContent}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case dict.get(inner, tag) {
        Error(Nil) -> Ok(vxml)
        Ok(#(new_tag, text, new_attrs)) -> {
          let text_node = T(blame, [BlamedContent(blame, text)])
          let attrs = list.append(attrs, new_attrs)
          Ok(V(blame, new_tag, attrs, [text_node, ..children]))
        }
      }
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  let inner_param = param
    |> list.map(fn(renaming: #(String, String, String, List(#(String, String)))) {
      let #(old_tag, new_tag, text, attrs) = renaming
      let attrs_converted = list.map(attrs, fn(attr) {
        let #(key, value) = attr
        vxml.BlamedAttribute(infra.blame_us(name), key, value)
      })
      #(old_tag, #(new_tag, text, attrs_converted))
    })
    |> dict.from_list
  Ok(inner_param)
}

type Param =
  List(#(String, String, String, List(#(String, String))))
//       ↖       ↖        ↖      ↖
//       old_tag new_tag  text   list of attributes as key value pairs

type InnerParam =
  Dict(String, #(String, String, List(vxml.BlamedAttribute)))

const name = "rename_with_appended_attributes_and_prepended_text"
const constructor = rename_with_appended_attributes_and_prepended_text

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// renames tags while adding attributes and
/// prepending a new text node as the first child
/// of the renamed tag
pub fn rename_with_appended_attributes_and_prepended_text(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// renames tags while adding attributes and
/// prepending a new text node as the first child
/// of the renamed tag
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
  [
    infra.AssertiveTestData(
      param: [#("QED", "span", "\\(\\square\\)", [#("class", "qed")])],
      source:   "
                <> root
                  <> QED
                ",
      expected: "
                <> root
                  <> span
                    class=qed
                    <>
                      \"\\(\\square\\)\"
                ",
    ),

  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}

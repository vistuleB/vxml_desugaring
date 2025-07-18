import gleam/int
import gleam/list
import gleam/option.{Some, None}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, BlamedAttribute, T, V}

fn ensure_has_id_attribute(
  vxml: VXML, counter: Int
) -> #(VXML, Int, String) {
  let assert V(_, _, _, _) = vxml
  case infra.v_attribute_with_key(vxml, "id") {
    Some(attr) -> #(vxml, counter, attr.value)
    None -> {
      let counter = counter + 1
      let id = "_" <> ins(counter) <> "_" <> ins(int.random(9999))
      let attributes = list.append(
        vxml.attributes,
        [BlamedAttribute(vxml.blame, "id", id)]
      )
      #(V(..vxml, attributes: attributes), counter, id)
    }
  }
}

fn nodemap(
  node: VXML,
  counter: Int,
) -> Result(#(VXML, Int), DesugaringError) {
  case node {
    T(_, _) -> Ok(#(node, counter))

    V(_, _, attributes, _) -> {
      let handle_attributes =
        attributes
        |> list.filter(fn(att) { string.starts_with(att.key, "handle")})

      use <- infra.on_true_on_false(
        list.is_empty(handle_attributes),
        Ok(#(node, counter)),
      )

      let assert #(
        V(_, _, attributes, _) as node,
        counter,
        id,
      ) = ensure_has_id_attribute(node, counter)

      let assert True = id != ""
      let assert True = id == string.trim(id)

      let attributes =
        attributes
        |> list.map(
          fn(att) {
            case string.starts_with(att.key, "handle") {
              False -> att
              True -> {
                // use an empty handle_value if not there:
                let #(handle_name, handle_value) = case string.split_once(att.value, " ") {
                  Ok(#(first, second)) -> #(first, second)
                  Error(_) -> #(att.value, "")
                }
                BlamedAttribute(..att, value: handle_name <> " | " <> id <> " | " <> handle_value)
              }
            }
          }
        )

      Ok(#(V(..node, attributes: attributes), counter))
    }
  }
}

fn nodemap_factory(_: InnerParam) -> n2t.OneToOneStatefulNodeMap(Int) {
  nodemap
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_stateful_nodemap_2_desugarer_transform(nodemap_factory(inner), 0)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

const name = "handles_generate_ids"
const constructor = handles_generate_ids

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Generates a unique ID and filters attributes to
/// find any that start with "handle" in which their
/// values are expected to be in the format 
/// ```
/// ...=handle_name handle_value
/// ```
/// It does the following two things:
/// 1- Processes these "handle" attributes values 
/// by:
///  . Splitting their values on space
///  . Reformatting them to include the  generated
///    ID in the format:
///      handle_name | id | handle_value
///    or just
///      value | id 
///    if the value is not splitable,
///  
/// 2- Add id attribute to the node
///    ( usefull for html href link ?id=x )
/// 
/// Returns a new V node with the transformed
/// attributes
pub fn handles_generate_ids() -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// Generates a unique ID and filters attributes to
/// find any that start with \"handle\" in which their
/// values are expected to be in the format 
/// ```
/// ...=handle_name handle_value
/// ```
/// It does the following two things:
/// 1- Processes these \"handle\" attributes values 
/// by:
///  . Splitting their values on space
///  . Reformatting them to include the  generated
///    ID in the format:
///      handle_name | id | handle_value
///    or just
///      value | id 
///    if the value is not splitable,
///  
/// 2- Add id attribute to the node
///    ( usefull for html href link ?id=x )
/// 
/// Returns a new V node with the transformed
/// attributes
    ",
    case param_to_inner_param(Nil) {
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
  infra.assertive_tests_from_data_nil_param(name, assertive_tests_data(), constructor)
}

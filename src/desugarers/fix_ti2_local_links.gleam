import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, tag, atts, children) -> {
      use href <- infra.on_none_on_some(
        infra.v_attribute_with_key(vxml, "href"),
        Ok(vxml),
      )
      use <- infra.on_false_on_true(
        string.starts_with(href.value, "../../demo"),
        Ok(vxml),
      )
      let atts =
        atts
        |> list.map(fn(att) {
          case att.key {
            "href" ->
              vxml.BlamedAttribute(
                att.blame,
                "href",
                att.value
                  |> string.replace(
                    "../../demos",
                    "https://www.tu-chemnitz.de/informatik/theoretische-informatik/demos",
                  ),
              )
            _ -> att
          }
        })
      Ok(V(blame, tag, atts, children))
    }
    T(_, _) -> Ok(vxml)
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

pub const desugarer_name = "fix_ti2_local_links"
pub const desugarer_pipe = fix_ti2_local_links

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// fixes local links in TI2 content by converting
/// relative paths to absolute URLs
pub fn fix_ti2_local_links() -> Pipe {
  Pipe(
    desugarer_name,
    option.None,
    "
/// fixes local links in TI2 content by converting
/// relative paths to absolute URLs
    ",
    case param_to_inner_param(Nil) {
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
  infra.assertive_tests_from_data_nil_param(desugarer_name, assertive_tests_data(), desugarer_pipe)
}

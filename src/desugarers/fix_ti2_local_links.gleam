import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, tag, atts, children) -> {
      use href <- infra.on_none_on_some(
        infra.get_attribute_by_name(vxml, "href"),
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

fn transform_factory(_param: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

pub fn fix_ti2_local_links() -> Pipe {
  Pipe(
    description: DesugarerDescription("fix_ti2_local_links", option.None, "..."),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}

import gleam/string
import gleam/pair
import gleam/list
import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription,
} as infra
import vxml_parser.{type VXML, T, V}

fn param_transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, tag, atts, children) -> {

      use href <- infra.on_none_on_some(
        infra.get_attribute_by_name(vxml, "href"),
        Ok(vxml)
      )
      use <- infra.on_false_on_true(
        string.starts_with(href.value, "../../demo"),
        Ok(vxml)
      )
      let atts = atts |> list.map(fn(att) {
        case att.key {
          "href" -> vxml_parser.BlamedAttribute(att.blame, "href", att.value |> string.replace("../../demos", "https://www.tu-chemnitz.de/informatik/theoretische-informatik/demos"))
          _ -> att
        }
      })
      Ok(V(blame, tag, atts, children))

    }
    T(_, _) -> Ok(vxml)
  }
}

fn transform_factory() -> NodeToNodeTransform {
  param_transform(_)
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}



pub fn fix_ti2_local_links() -> Pipe {
  #(
    DesugarerDescription("fix_ti2_local_links", option.None, "..."),
    desugarer_factory(),
  )
}

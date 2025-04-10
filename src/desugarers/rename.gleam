import gleam/option.{None}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

fn param_transform(vxml: VXML, extra: Extra) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      let #(from, to) = extra
      case from == tag {
        False -> Ok(vxml)
        True -> Ok(V(blame, to, attrs, children))
      }
    }
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  let #(_, to) = extra
  case infra.valid_tag(to) {
    True -> param_transform(_, extra)
    False -> fn(_) {
      Error(DesugaringError(infra.no_blame, "invalid target tag name '" <> to <> "'"))
    }
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

type Extra =
  #(String, String)

pub fn rename(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("rename", None, "renames one tag"),
    desugarer: desugarer_factory(extra),
  )
}

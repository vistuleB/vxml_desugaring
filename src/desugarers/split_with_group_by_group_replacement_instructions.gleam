import blamedlines.{Blame}
import gleam/list
import gleam/option.{None, Some}
import gleam/regexp.{type Regexp}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V}

pub type RegexpMatchedGroupReplacementInstructions {
  Keep
  Trash
  TagReplaceTrashPayload(String)
  TagReplaceKeepPayloadAsAttribute(String, String)
  TagReplaceKeepPayloadAsTextChild(String)
}

pub type RegexpWithGroupReplacementInstructions {
  RegexpWithGroupReplacementInstructions(
    re: Regexp,
    instructions: List(RegexpMatchedGroupReplacementInstructions),
  )
}

fn process_blamed_line(
  line: BlamedContent,
  w: RegexpWithGroupReplacementInstructions,
) -> List(VXML) {
  let BlamedContent(blame, content) = line
  let splits = regexp.split(w.re, content)
  let num_groups = list.length(w.instructions)
  let num_matches: Int = { list.length(splits) - 1 } / { num_groups + 1 }
  let assert True = { num_matches * { num_groups + 1 } } + 1 == list.length(splits)

  let #(_, results) = infra.index_map_fold(
    splits,
    0, // <-- the 'acc' is the char_offset from start of content for next split
    fn(acc, split, index) {
      let mod_index = index % { num_groups + 1 } - 1
      let instruction = case mod_index != -1 {
        True -> case infra.get_at(w.instructions, mod_index) {
          Ok(instr) -> instr
          Error(_) -> Keep
        }
        False -> Keep
      }
      let updated_blame = Blame(..blame, char_no: blame.char_no + acc)
      let node_replacement = case instruction {
        Trash -> None
        Keep -> Some(T(updated_blame, [BlamedContent(updated_blame, split)]))
        TagReplaceTrashPayload(tag) -> Some(V(updated_blame, tag, [], []))
        TagReplaceKeepPayloadAsAttribute(tag, key) -> Some(V(
          updated_blame,
          tag,
          [BlamedAttribute(updated_blame, key, split)],
          [],
        ))
        TagReplaceKeepPayloadAsTextChild(tag) -> Some(V(
          updated_blame,
          tag,
          [],
          [T(updated_blame, [BlamedContent(updated_blame, split)])],
        ))
      }
      let new_acc = acc + string.length(split)
      #(new_acc, node_replacement)
    }
  )

  results
  |> list.filter(fn(opt) {
    case opt {
      Some(_) -> True
      None -> False
    }
  })
  |> list.map(fn(opt) {
    let assert Some(node) = opt
    node
  })
}

fn nodemap(
  vxml: VXML,
  inner: RegexpWithGroupReplacementInstructions,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    V(_, _, _, _) -> Ok([vxml])
    T(_, lines) -> {
      lines
      |> list.map(process_blamed_line(_, inner))
      |> list.flatten
      |> infra.plain_concatenation_in_list
      |> Ok
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToManyNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = RegexpWithGroupReplacementInstructions

type InnerParam = RegexpWithGroupReplacementInstructions

const name = "split_with_group_by_group_replacement_instructions"
const constructor = split_with_group_by_group_replacement_instructions

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// splits text nodes by regexp with group-by-group
/// replacement instructions
pub fn split_with_group_by_group_replacement_instructions(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// splits text nodes by regexp with group-by-group
/// replacement instructions
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
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}

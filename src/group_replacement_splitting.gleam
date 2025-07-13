import blamedlines.{type Blame, Blame}
import gleam/list
import gleam/option.{None, Some}
import gleam/regexp.{type Regexp}
import gleam/string
import infrastructure.{type DesugaringError} as infra
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

pub fn split_content_with_replacement(
  blame: Blame,
  content: String,
  w: RegexpWithGroupReplacementInstructions,
) -> List(VXML) {
  use <- infra.on_true_on_false(
    content == "",
    [T(blame, [BlamedContent(blame, content)])]
  )

  let splits = regexp.split(w.re, content)
  let num_groups = list.length(w.instructions)
  let num_matches: Int = { list.length(splits) - 1 } / { num_groups + 1 }
  let assert True = { num_matches * { num_groups + 1 } } + 1 == list.length(splits)

  let #(_, results) = infra.index_map_fold(
    splits,
    0, // <-- the 'acc' is the char_offset from start of content for next split
    fn(acc, split, index) {
      let mod_index = index % { num_groups + 1 } - 1
      let assert Ok(instruction) = case mod_index != -1 {
        True -> infra.get_at(w.instructions, mod_index)
        False -> Ok(Keep)
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

pub fn split_blamed_line_with_replacement(
  line: BlamedContent,
  w: RegexpWithGroupReplacementInstructions,
) -> List(VXML) {
  split_content_with_replacement(line.blame, line.content, w)
}

pub fn split_if_t_with_replacement(
  vxml: VXML,
  inner: RegexpWithGroupReplacementInstructions,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    V(_, _, _, _) -> Ok([vxml])
    T(_, lines) -> {
      lines
      |> list.map(split_blamed_line_with_replacement(_, inner))
      |> list.flatten
      |> infra.plain_concatenation_in_list
      |> Ok
    }
  }
}
import desugarers_docs

import node_to_nodes_transforms/split_delimiters_chunks_transform.{
  SplitDelimitersChunksExtraArgs,
}
import node_to_nodes_transforms/wrap_elements_by_blankline_transform.{
  WrapByBlankLineExtraArgs,
}

pub fn pipeline_constructor() {
  let extra_2 =
    WrapByBlankLineExtraArgs(tags: [
      "MathBlock", "Image", "Table", "Exercises", "Solution", "Example",
      "Section", "Exercise",
    ])

  let extra_3 =
    SplitDelimitersChunksExtraArgs(
      open_delimiter: "__",
      close_delimiter: "__",
      tag_name: "CentralItalicDisplay",
    )

  let extra_4 =
    SplitDelimitersChunksExtraArgs(
      open_delimiter: "_|",
      close_delimiter: "|_",
      tag_name: "CentralDisplay",
    )

  [
    desugarers_docs.remove_writerly_blurb_tags_around_text_nodes_pipe(),
    desugarers_docs.break_up_text_by_double_dollars_pipe(),
    desugarers_docs.pair_double_dollars_together_pipe(),
    desugarers_docs.wrap_elements_by_blankline_pipe(extra_2),
    desugarers_docs.split_vertical_chunks_pipe(),
    desugarers_docs.remove_vertical_chunks_with_no_text_child_pipe(),
    desugarers_docs.insert_indent_pipe(),
    desugarers_docs.split_delimiters_chunks_pipe(extra_3),
    desugarers_docs.split_delimiters_chunks_pipe(extra_4),
    desugarers_docs.split_content_by_low_level_delimiters_pipe(),
    desugarers_docs.wrap_math_with_no_break_pipe(),
  ]
}

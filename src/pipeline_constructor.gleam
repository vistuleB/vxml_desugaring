import desugarers_docs

pub fn pipeline_constructor() {
  [
    desugarers_docs.remove_writerly_blurb_tags_around_text_nodes_pipe(),
    desugarers_docs.break_up_text_by_double_dollars_pipe(),
    desugarers_docs.pair_double_dollars_together_pipe(),
    desugarers_docs.wrap_elements_by_blankline_pipe([
      "MathBlock", "Image", "Table", "Exercises", "Solution", "Example",
      "Section", "Exercise", "List", "Grid",
    ]),
    desugarers_docs.split_vertical_chunks_pipe(),
    desugarers_docs.remove_vertical_chunks_with_no_text_child_pipe(),
    desugarers_docs.insert_indent_pipe(),
    desugarers_docs.wrap_element_children_pipe(#(["List", "Grid"], "Item")),
    desugarers_docs.split_delimiters_chunks_pipe(
      #("__", "__", "CentralItalicDisplay", True, []),
    ),
    desugarers_docs.split_delimiters_chunks_pipe(
      #("_|", "|_", "CentralDisplay", True, []),
    ),
    desugarers_docs.split_delimiters_chunks_pipe(#("_", "_", "i", False, ["*"])),
    desugarers_docs.split_delimiters_chunks_pipe(#("*", "*", "b", False, ["i"])),
    desugarers_docs.split_delimiters_chunks_pipe(
      #("$", "$", "Math", False, ["i", "*"]),
    ),
    desugarers_docs.wrap_math_with_no_break_pipe(),
  ]
}

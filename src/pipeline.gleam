import desugarers/break_up_text_by_double_dollars.{
  break_up_text_by_double_dollars_desugarer,
}
import desugarers/insert_indent.{insert_indent_desugarer}
import desugarers/pair_double_dollars_together.{
  pair_double_dollars_together_desugarer,
}
import desugarers/remove_vertical_chunks_with_no_text_child.{
  remove_vertical_chunks_with_no_text_child_desugarer,
}
import desugarers/remove_writerly_blurb_tags_around_text_nodes.{
  remove_writerly_blurb_tags_around_text_nodes_desugarer,
}
import desugarers/split_delimiters_chunks.{split_delimiters_chunks_desugarer}
import desugarers/split_vertical_chunks.{split_vertical_chunks_desugarer}
import desugarers/wrap_element_children.{wrap_element_children_desugarer}
import desugarers/wrap_elements_by_blankline.{
  wrap_elements_by_blankline_desugarer,
}
import desugarers/wrap_math_with_no_break.{wrap_math_with_no_break_desugarer}
import infrastructure.{type Pipe}

pub fn pipeline_constructor() -> List(Pipe) {
  [
    remove_writerly_blurb_tags_around_text_nodes_desugarer(),
    break_up_text_by_double_dollars_desugarer(),
    pair_double_dollars_together_desugarer(),
    wrap_elements_by_blankline_desugarer([
      "MathBlock", "Image", "Table", "Exercises", "Solution", "Example",
      "Section", "Exercise", "List", "Grid",
    ]),
    split_vertical_chunks_desugarer(),
    remove_vertical_chunks_with_no_text_child_desugarer(),
    insert_indent_desugarer(),
    wrap_element_children_desugarer(#(["List", "Grid"], "Item")),
    split_delimiters_chunks_desugarer(
      #("__", "__", "CentralItalicDisplay", True, []),
    ),
    split_delimiters_chunks_desugarer(#("_|", "|_", "CentralDisplay", True, [])),
    split_delimiters_chunks_desugarer(#("_", "_", "i", False, ["*"])),
    split_delimiters_chunks_desugarer(#("*", "*", "b", False, ["i"])),
    split_delimiters_chunks_desugarer(#("$", "$", "Math", False, ["i", "*"])),
    wrap_math_with_no_break_desugarer(),
  ]
}

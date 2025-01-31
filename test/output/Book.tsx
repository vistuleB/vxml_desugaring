const Article = () => {
  return (
    <Book
         title=""
         mobile_title="">
      <WriterlyBlankLine />
      <Chapter
           title="Derivatives">
        <WriterlyBlankLine />
        <Exercises>
          <Exercise>
            <WriterlyCodeBlock
                 language="python">
              hello = hi
            </WriterlyCodeBlock>
            <WriterlyBlurb>
              hihi
            </WriterlyBlurb>
            <WriterlyBlankLine />
            <WriterlyBlurb>
              Glory
            </WriterlyBlurb>
            <test
                 src="hi" />
            <WriterlyBlurb>
              _ in time,
              test{" "}
            </WriterlyBlurb>
            <InlineImage
                 src="hi" />
            <WriterlyBlurb>
              *exa*mine_ 
              how long it would take__
            </WriterlyBlurb>
            <WriterlyBlankLine />
            <WriterlyBlurb>
              This paragraph should get an indent.
            </WriterlyBlurb>
            <WriterlyBlankLine />
            <Solution>
              <WriterlyBlurb>
                hi
              </WriterlyBlurb>
              <WriterlyBlankLine />
              <WriterlyBlankLine />
            </Solution>
          </Exercise>
        </Exercises>
      </Chapter>
    </Book>
  );
};

export default Article;
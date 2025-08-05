import Something from "./Somewhere";

const OurSuperComponent = () => {
  return (
    <>
      <WriterlyBlankLine />
      <Section>
        *Notation.*
        Curly braces typically denote the beginning
        “$\&#123;$” and ending “$\&#125;$” of a collection of
        elements, otherwise known as a _set_.
        For example, this is a set containing the
        numbers $1$, $2$ and $3$ (and nothing else):
        <WriterlyBlankLine />
        $$\Large\&#123;1, 2, 3\&#125;$$
        <WriterlyBlankLine />
        Also,
        <WriterlyBlankLine />
        $$\Large\&#123;1\&#125;$$
        <WriterlyBlankLine />
        is a set containing just the number $1$, while
        <WriterlyBlankLine />
        $$\Large\&#123;1, 3\&#125;$$
        <WriterlyBlankLine />
        is a set containing just the numbers $1$
        and $3$, etc. Even,
        <WriterlyBlankLine />
        $$\Large\&#123;\&#125;$$
        <WriterlyBlankLine />
        is an _empty_ set, a set with no elements!
      </Section>
      <WriterlyBlankLine />
      <Section>
        *What it does.*
        The “API” (a computer science notion,
        roughly meaning
        <WriterlyBlankLine />
        __the interface offered to the outside world__
        <WriterlyBlankLine />
        as in, for example, the buttons and clock
        display and door handle of a microwave oven)
        of a set consists of just one functionality:
        a set can answer questions of the form
        <WriterlyBlankLine />
        __do you contain ... ?__
        <WriterlyBlankLine />
        and nothing else.
        For example, you could ask a set
        <WriterlyBlankLine />
        __do you contain 3?__
        <WriterlyBlankLine />
        to which $\&#123;1, 3\&#125;$ would answer “yes”, but
        $\&#123; 1\&#125;$ would answer “no”, or
        <WriterlyBlankLine />
        __do you contain 2?__
        <WriterlyBlankLine />
        to which $\&#123;1\&#125;$ and $\&#123;1, 3\&#125;$ would
        both answer “no”, but $\&#123;1, 2, 3\&#125;$ would
        answer “yes”.
        <WriterlyBlankLine />
        Notation-wise, the expression
        <WriterlyBlankLine />
        $$\Large x \in A$$
        <WriterlyBlankLine />
        means
        <WriterlyBlankLine />
        __$A$ contains $x$__
        <WriterlyBlankLine />
        or
        <WriterlyBlankLine />
        __$A$ answers “yes” to the
        question “do you contain $x$?”__
        <WriterlyBlankLine />
        equivalently. [One can also say
        <WriterlyBlankLine />
        __$x$ in $A$__
        <WriterlyBlankLine />
        or
        <WriterlyBlankLine />
        __$x$ is in $A$__
        <WriterlyBlankLine />
        or
        <WriterlyBlankLine />
        __$x$ is an element of $A$__
        <WriterlyBlankLine />
        depending on one's mood and/or tastes.]
        As in all of mathematics, any such statement
        evaluates to either “true” or “false”.
        For example,
        <WriterlyBlankLine />
        $$\Large 1 \in \&#123;1, 2\&#125;$$
        <WriterlyBlankLine />
        is true, because $1$ _is_ an element of the set
        $\&#123;1, 2\&#125;$, whereas
        <WriterlyBlankLine />
        $$\Large 3 \in \&#123;1, 2\&#125;$$
        <WriterlyBlankLine />
        is false, because $3$ _is not_
        an element of the set $\&#123;1, 2\&#125;$.
      </Section>
      <WriterlyBlankLine />
      <Section>
        *Set Equality.*
        Two sets are deemed to be
        equal if and only if they
        answer the same to
        all “do you contain ...?” questions.
        For example, while
        $$
        \Large\&#123;2, 1\&#125;
        $$
        might look superficially different from
        $$
        \Large\&#123;1, 2\&#125;
        $$
        these sets are actually one and the same,
        because they both answer “yes” to
        <WriterlyBlankLine />
        __do you contain 1?__
        __do you contain 2?__
        <WriterlyBlankLine />
        and answer “no” to all else. For that matter,
        $$
        \Large\&#123;1, 1, 2\&#125;
        $$
        might also look superficially different from
        $$
        \Large\&#123;1, 2\&#125;
        $$
        but since both sets answer “yes” to
        <WriterlyBlankLine />
        __do you contain 1?__
        __do you contain 2?__
        <WriterlyBlankLine />
        and answer “no” to all else,
        they are by definition the same.
        <WriterlyBlankLine />
        (These examples demonstrate that human notation
        is redundant: there are several different ways of
        writing down the same set. They also demonstrate
        that sets do not keep track of the
        <WriterlyBlankLine />
        __order__
        <WriterlyBlankLine />
        nor of the
        <WriterlyBlankLine />
        __multiplicity__
        <WriterlyBlankLine />
        of their elements. Such notions are simply not part
        of the “API” of a set.)
        <WriterlyBlankLine />
        Moreover, any empty set is equal to any other
        empty set. Equality follows because both sets
        answer all questions the same way: they both
        answer “no” to everything. So there is
        <WriterlyBlankLine />
        __one__
        <WriterlyBlankLine />
        and only one empty set. Therefore, mathematicians
        speak of
        <WriterlyBlankLine />
        __the__
        <WriterlyBlankLine />
        empty set—the one and only!
      </Section>
      <WriterlyBlankLine />
      <Section>
        *Second notation for the empty set.*
        While the empty set can be written
        $$
        \Large \&#123;\&#125;
        $$
        another available notation is
        $$
        \Large \phi
        $$
        which is the Greek letter phi, read “fee”. (Or
        “fie”? Hum.) (Or you can just say “the empty set”,
        and keep it safe.)
      </Section>
      <WriterlyBlankLine />
      <Section>
        *Sets within sets.*
        Sets can be nested much like Russian dolls. In
        fact, the result of doing this might even look
        like a little bit like a Russian doll (no?):
        <WriterlyBlankLine />
        $$
        \Large \&#123;\&#123;\&#123;\&#123;\&#125;\&#125;\&#125;\&#125;
        $$
        <WriterlyBlankLine />
        The above is “a set containing a set containing
        a set containing a set containing the empty set”.
        Eschewing complete adherence to the Russian doll
        aesthetic, we could also write
        <WriterlyBlankLine />
        $$
        \Large \&#123;\&#123;\&#123;\phi\&#125;\&#125;\&#125;
        $$
        <WriterlyBlankLine />
        for the same thing, given that $\phi = \&#123;\&#125;$.
        <WriterlyBlankLine />
        Mind you, concerning this example, that
        <WriterlyBlankLine />
        $$
        \Large \&#123;\&#123;\&#125; \&#125; \ne \&#123;\&#125;
        $$
        <WriterlyBlankLine />
        <ImageRight
        src="images/svg_bt1_bt_empty_set_cloud.svg"
        offset_x="3em"
         />
        <WriterlyBlankLine />
        because a box containing an empty box is not the
        same thing as an empty box! Specifically,
        <WriterlyBlankLine />
        $$
        \Large \&#123; \&#123;\&#125; \&#125;
        $$
        <WriterlyBlankLine />
        answers “yes” to the question “do you contain
        $\&#123;\&#125;$?” (a.k.a., “do you contain $\phi$?”) whereas
        <WriterlyBlankLine />
        $$
        \Large \&#123;\&#125;
        $$
        <WriterlyBlankLine />
        answers “no” to the same question. (Indeed, while
        the empty set _contains_ nothing, it _is_ something.)
        Similarly,
        <WriterlyBlankLine />
        $$
        \Large \&#123;\&#123;\&#123;\&#125;\&#125; \&#125; \ne \&#123;\&#123;\&#125;\&#125;
        $$
        <WriterlyBlankLine />
        etc, etc: adding a new outer layer changes the
        whole set each time.
      </Section>
      <WriterlyBlankLine />
      <Section>
        *Set union and set intersection.*
        The so-called _union_ of two sets $A$ and $B$ is
        written $$\Large A \cup B$$ and consists of the set
        of all things that are either in $A$ or in $B$. For
        example,
        <WriterlyBlankLine />
        $$
        \Large \&#123;1, 2\&#125; \cup \&#123;2, 5\&#125; = \&#123;1, 2, 5\&#125;
        $$
        <WriterlyBlankLine />
        as $1$, $2$ and $5$ are the only elements to find
        themselves either in $\&#123;1, 2\&#125;$ or in $\&#123;2, 5\&#125;$.
        The so-called _intersection_ of two sets $A$ and
        $B$ is written
        <WriterlyBlankLine />
        $$
        \Large A \cap B
        $$
        <WriterlyBlankLine />
        and consists of the set of all things that are both
        in $A$ and in $B$. For example,
        <WriterlyBlankLine />
        $$
        \Large \&#123;1, 2\&#125; \cap \&#123;2, 5\&#125; = \&#123;2\&#125;
        $$
        <WriterlyBlankLine />
        as $2$ is the only element that is both in $\&#123;1, 2\&#125;$
        and in $\&#123;2, 5\&#125;$.
        <WriterlyBlankLine />
        Note that
        <WriterlyBlankLine />
        $$
        \Large x \in (A \cup B)
        $$
        <WriterlyBlankLine />
        if and only if
        <WriterlyBlankLine />
        $$
        \Large x \in A
        $$
        <WriterlyBlankLine />
        _or_
        <WriterlyBlankLine />
        $$
        \Large x \in B
        $$
        <WriterlyBlankLine />
        because that's how we defined “union”. (Replace
        “or” by “and” to get a definition of intersection.)
        In fact, a logician would define the union of two
        sets by an abstruse expression of the type
        <WriterlyBlankLine />
        $$
        \Large x \in (A \cup B) \iff (x \in A) \vee (x \in B)
        $$
        <WriterlyBlankLine />
        read
        <WriterlyBlankLine />
        __an element $x$ is in the thing I call “$A \cup B$”
        if and only if $x$ is in $A$ or $x$ is in $B$__
        <WriterlyBlankLine />
        as “$\!\!\iff\!\!$” means “if and only if” and
        “$\vee$” means “or”. (You can figure out the
        similar definition for the intersection of two sets
        if we tell you that
        <WriterlyBlankLine />
        $$
        \Large \wedge
        $$
        <WriterlyBlankLine />
        means “and”.)
      </Section>
      <WriterlyBlankLine />
      <Section>
        *Sets encountered in calculus.*
        In calculus, you will see sets such as _the real
        numbers_
        <WriterlyBlankLine />
        $$
        \Large\rr
        $$
        <WriterlyBlankLine />
        which is an infinite set containing all “ordinary”
        decimal numbers, or such as _the integers_
        $$
        \Large\zz
        $$
        which contains all “whole” numbers, including the
        negative ones. You might also encounter
        _the natural numbers_
        $$
        \Large\nn
        $$
        which contains only those integers that are greater
        than $0$ (i.e., $\nn = \&#123;1, 2, 3, \ldots \&#125;$).
        <WriterlyBlankLine />
        Secondly—and this pretty much wraps it up for those
        sets  that are commonly seen in calculus—you will
        encounter _intervals_. For example,
        <WriterlyBlankLine />
        $$
        \Large [a, b]
        $$
        <WriterlyBlankLine />
        is a _closed interval_, consisting of all (real)
        numbers greater than or equal to $a$, and less than
        or equal to $b$. Or
        <WriterlyBlankLine />
        $$
        \Large [a, b)
        $$
        <WriterlyBlankLine />
        is a _half-open_ interval, consisting of all real
        numbers greater than or equal to $a$, and less than
        $b$. Etc.
        <WriterlyBlankLine />
        Note that
        <WriterlyBlankLine />
        $$
        \Large (-\infty, \infty) = \rr
        $$
        <WriterlyBlankLine />
        since
        <WriterlyBlankLine />
        $$
        \Large (-\infty, \infty)
        $$
        <WriterlyBlankLine />
        (which is an _open_ interval, by the way) means
        <WriterlyBlankLine />
        __the set of real numbers with no bound below,
        and no bound above__
        <WriterlyBlankLine />
        which is all of $\rr$.
      </Section>
      <WriterlyBlankLine />
      <Section>
        *Sets not encountered in calculus.*
        If you take a more advanced course, you might
        encounter the so-called _set of extended real numbers_,
        written
        <WriterlyBlankLine />
        $$
        \Large\overline&#123;\rr&#125;
        $$
        <WriterlyBlankLine />
        and which consists of all the numbers in $\rr$, plus
        the formal symbols “$-\infty$”, “$\infty$” as well:
        <WriterlyBlankLine />
        $$
        \Large\overline&#123;\rr&#125; = \rr \cup \&#123;-\infty, \infty\&#125;
        $$
        <WriterlyBlankLine />
        (I.e., ...well, you get it!)
        <WriterlyBlankLine />
        You can view $\overline&#123;\rr&#125;$ as a kind “closed interval”
        version of $\rr$, that is, think of $\overline&#123;\rr&#125;$
        as being the closed interval
        <WriterlyBlankLine />
        $$
        \Large [-\infty, \infty]
        $$
        <WriterlyBlankLine />
        with the two infinite endpoints _included_.
        <WriterlyBlankLine />
        Does all this have any “real meaning”? Good question!
        The answer is: _not until you give it one_.
        <WriterlyBlankLine />
        E.g. (to give you a brief flavor, before we move on
        forever from the topic), the value of something like
        <WriterlyBlankLine />
        $$
        \Large 0.5+ \infty
        $$
        <WriterlyBlankLine />
        must be _defined_. (It is defined to be $\infty$, in
        case you're curious. In fact, one has $a + \infty = \infty$
        for any $a \ne -\infty$.) And some things remain
        explicitly _undefined_. For example, the expression
        <WriterlyBlankLine />
        $$
        \Large (-\infty) + \infty
        $$
        <WriterlyBlankLine />
        has an _undefined_ value—the same way, say, that
        division by $0$ is undefined in $\rr$.
        (Well, anyway, end of lesson.)
      </Section>
    </>
  );
};

export default OurSuperComponent;
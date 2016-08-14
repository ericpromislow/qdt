# QDT - Quick-and-Dirty Templating language for Perl

Designed for limited Perl installations.  Pure Perl. No C compiler needed.

# The QDT language

The templating language is much like Ruby's `erb`, but of course what goes inside
the delimiters is Perl code.

`<% ... %>` - Logical code, like if-blocks and while-loops. Don't forget the `<% } %>` bits to end blocks.

`<%= ... %>` - Eval and emit the contained code.

`<%# ... %>` - Comments go in here, won't show up in the output

Anything else is emitted verbatim.

# Command-line usage:

    perl -Ilib bin/qdt.pl <file>

There's no installer to put the library in a perl system directory because this library
is intended for libraries that are missing libs like
`ExtUtils::MakeMaker`, which depend on `XS` code. If there's a tool to
do that in pure Perl please let me know.  If you're system supports
`XS`, go use one of the many other Perl templating systems. *QDT* is
for everyone else.


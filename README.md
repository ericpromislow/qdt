# QDT - Quick-and-Dirty Templating language for Perl

Designed for limited Perl installations.  Pure Perl. No C compiler needed.

# The QDT language

The templating language is much like Ruby's `erb`, but of course what goes inside
the delimiters is Perl code.

`<% ... %>` - Logical code, like if-blocks and while-loops. Don't forget the `<% } %>` bits to end blocks.

`<%= ... %>` - Eval and emit the contained code.

`<%# ... %>` - Comments go in here, won't show up in the output

Anything else is emitted verbatim.

Note that a comment in a `<% ... %>` tag ends until either a
newline in the construct, or the end of the tag, but doesn't extend
further. In other words, 

    <% foo(args...); # call foo %>more

will produce the same output as:

    <% foo(args...); # call foo %>
    more

## Available functions

    get_p(env-var name[, default-value])

if the specified environment variable isn't set, returns the
default-value if given, otherwise gives a fatal error message.
If it's set, return its value.

## Compound values

Arrays need to be specified with `'["value 1", "value 2" ...]'` syntax.
Hashes need to be specified with `'["key 1" => "value 1", "key 2" =>
"value 2"]'` syntax.

Compound arrays and hashes currently aren't supported.  These values
are parsed with the eval() function.  See the warning below for the
implications of this.

# Command-line usage:

    perl -Ilib bin/qdt.pl <file>

There's no installer to put the library in a perl system directory because this library
is intended for libraries that are missing libs like
`ExtUtils::MakeMaker`, which depend on `XS` code. If there's a tool to
do that in pure Perl please let me know.  If you're system supports
`XS`, go use one of the many other Perl templating systems. *QDT* is
for everyone else.

# WARNING

QDT calls eval liberally, and without doing any taint-checking. It's
intended for internal use only, such as for interpolating environment
variables into configuration templates. If user-supplied content is
getting interpolated into a template, you'll need to do the necessary
analysis to ensure the content can be safely eval'ed.

-module(gemini_text_line).

-moduledoc """
Classify a single line of Gemini text.

This module is internal to `m:gemini_text`: it knows nothing about
documents, line endings or preformatted state. Only `tag/1`,
`pref_marker/1` and `alt_text/1` are public.
""".

-export([tag/1, pref_marker/1, alt_text/1]).
% but export *everything* if running under eunit
-ifdef(TEST).
-compile([export_all, nowarn_export_all]).
-endif.


-export_type([line_element/0, link_line/0]).

-type simple_tag()    :: h1 | h2 | h3 | para.
-type simple_line()   :: {simple_tag(), binary()}.
-type tag()           :: simple_tag() | link.
-doc """
A link: `{link, Url, Label}`. `Label` may be empty.
""".
-type link_line()     :: {link, binary(), binary()}.
-doc """
What `tag/1` returns: any element except a preformatted block, that is
`{h1 | h2 | h3 | para, Text}`, `{link, Url, Label}` or `blank`.
""".
-type line_element()  :: simple_line() | link_line() | blank.

-doc """
Is the line a preformatted-block fence (does it start with three
backticks)?

True for both the opening and the closing fence.
""".
-spec pref_marker(Line) -> Result
              when Line   :: binary(),
                   Result :: boolean().
pref_marker(Line) ->
    prefix(<<"```">>, Line).


-doc """
Return the alt text following the opening fence of a preformatted block,
trimmed of surrounding whitespace.

The line must start with three backticks.
""".
-spec alt_text(Line) -> Result
              when Line   :: binary(),
                   Result :: binary().
alt_text(<<"```", Rest/binary>>) ->
    string:trim(Rest).


-doc """
Classify a single line.

Returns `blank`, `{h1 | h2 | h3 | para, Text}` or `{link, Url, Label}`.
Heading captions and link labels are trimmed, and the space after `#` or
`=>` is optional. A fourth `#` is part of an h3 caption. Leading
whitespace is significant, so an indented `#` or `=>` line is a `para`.

The preformatted state is not known here, so a fence line is returned as
a `para`.
""".
-spec tag(Arg) -> Result
              when Arg    :: binary(),
                   Result :: line_element().
tag(<<>>) -> blank;
tag(Line) ->
    Matcher = [
               {<<"=> ">>, link},
               {<<"=>\t">>, link},
               {<<"=>">>, link_no_space},
               {<<"###">>, h3},
               {<<"##">>, h2},
               {<<"#">>, h1},
               {<<>>, para}
              ],
    tag2(Line, Matcher).


-spec tag2(Line, Matcher) -> Result
              when Line    :: binary(),
                   Matcher :: [{binary(), tag() | link_no_space}],
                   Result  :: line_element().

tag2(Line, [{Prefix, Tag}|T]) ->
    case prefix(Prefix, Line) of
        true  -> tag3(Line, Tag);
        false -> tag2(Line, T)
    end.


-spec tag3(Line, Tag) -> Result
              when Line   :: binary(),
                   Tag    :: tag() | link_no_space,
                   Result :: line_element().

tag3(Line, link) ->
    {_Tag, URLandCaption} = split_once(Line),
    {URL, Caption} = split_once(URLandCaption),
    {link, URL, Caption};
tag3(Line, link_no_space) ->
    % remove the leading "=>", which tag2/2 has already matched
    <<$=, $>, RestOfLine/binary>> = Line,
    {URL, Caption} = split_once(RestOfLine),
    {link, URL, Caption};
tag3(Line, para) ->
    {para, Line};
tag3(Line, Tag) ->
    N = heading_level(Tag),
    <<_:N/binary, Caption/binary>> = Line,
    {Tag, string:trim(Caption)}.


-spec heading_level(Tag) -> Result
              when Tag    :: h1 | h2 | h3,
                   Result :: 1..3.
heading_level(h1) -> 1;
heading_level(h2) -> 2;
heading_level(h3) -> 3.


-spec prefix(Prefix, Line) -> Result
              when Prefix :: binary(),
                   Line   :: binary(),
                   Result :: boolean().
prefix(Prefix, Line) ->
    binary:longest_common_prefix([Prefix, Line]) =:= byte_size(Prefix).


% split binary on first space or tab; trim the remainder
-spec split_once(S) -> Result
              when S      :: binary(),
                   Result :: {binary(), binary()}.
split_once(S) ->
    {Prefix, Suffix} = case binary:split(S, [<<" ">>, <<"\t">>]) of
                           [P, Rest] -> {P, Rest};
                           [P] -> {P, <<>>}
                       end,
    {Prefix, string:trim(Suffix)}.

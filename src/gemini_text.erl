%%%-------------------------------------------------------------------
%%% @copyright (C) 2023, Martin Keegan
%%% Created : 23 Dec 2023
%%%-------------------------------------------------------------------

-module(gemini_text).

-moduledoc """
Parse Gemini-formatted text.

[`parse/1`](`parse/1`) takes a binary and returns a list of elements
(see `t:tagged_line/0`) in document order, or an error, for example
`{error, {invalid_utf8, 3}}` if line 3 is not valid UTF-8 (see
`t:parse_error/0`).

A document can also be fed in chunks, of any size and split anywhere,
with [`new_context/0`](`new_context/0`), [`parse/2`](`parse/2`) and
[`finish/1`](`finish/1`); the result is the same as for `parse/1` on
the whole text. [`new_context/1`](`new_context/1`) takes options (see
`t:option/0`).

[`links/1`](`links/1`) and [`urls/1`](`urls/1`) are helpers which
extract just the links, or just their URLs. To read a page as a
subscription feed, see `m:gemini_text_feed`.
""".

-author('martin@no.ucant.org').

-export([parse/1, links/1, urls/1]).
-export([new_context/0, new_context/1, parse/2, finish/1]).

-export_type([tagged_line/0, pref_block/0,
              error_reason/0, parse_error/0, context/0, option/0]).

-doc """
A preformatted block: `{preformatted, Alt, Lines}`.

`Alt` is the text after the opening fence, trimmed of spaces and tabs
(it may be empty).
`Lines` are the lines of the body, verbatim and without line endings.
""".
-type pref_block()  :: {preformatted, binary(), [binary()]}.
-doc """
Why parsing failed: the input was not valid UTF-8 (`invalid_utf8`), or a
line was longer than the `max_line_length` option (`line_too_long`), or
had a control character and `control_chars` is `reject`
(`invalid_char`).
""".
-type error_reason() :: invalid_utf8 | line_too_long | invalid_char.
-doc """
A parse error: the reason and the 1-based number of the offending line.
Every line counts, including blank ones.
""".
-type parse_error()  :: {error_reason(), pos_integer()}.
-type pref_state()  :: none | {binary(), [binary()]}.
-type state()       :: {[tagged_line()], pref_state()}.
-type opts()        :: {pos_integer() | infinity, pass | strip | reject}.
-define(DEFAULT_MAX_LINE_LENGTH, 1048576).
% C0 controls except tab, DEL, and the C1 controls
-define(CONTROL_CHARS, "[\\x{0}-\\x{8}\\x{a}-\\x{1f}\\x{7f}-\\x{9f}]").
-record(ctx, {pref = none :: pref_state(),
              partial = <<>> :: binary(),
              line = 1 :: pos_integer(),
              max_line = ?DEFAULT_MAX_LINE_LENGTH
                  :: pos_integer() | infinity,
              control_chars = pass :: pass | strip | reject}).
-doc """
The state of a streaming parse: see `new_context/0`, `parse/2` and
`finish/1`. It is opaque.

`parse/2` does not change the context it is given: it returns a new one.
So an earlier context can be used again, and parsing the same chunks
from it gives the same results. `finish/1` ends the stream and returns
no context, so a stream cannot be continued after it.
""".
-opaque context()   :: #ctx{}.
-doc """
An option for `new_context/1`.

- `{max_line_length, Bytes | infinity}`: the longest line allowed, in
  bytes, counted before the LF and including a CR before it. Default
  1048576 (1 MiB). A longer line is the error `line_too_long`.
- `{control_chars, pass | strip | reject}`: what to do with control
  characters, that is C0 controls other than tab, DEL and the C1
  controls (U+0080 to U+009F), including a CR inside a line. `pass`
  (the default) leaves them in; `strip` removes them, everywhere
  including preformatted blocks; `reject` is the error `invalid_char`.
  This is done after the UTF-8 check and before the line is classified,
  so the result is the same as parsing the text with those characters
  already removed (for example `strip` turns the line `<<1, "# t">>` into
  a heading).
""".
-type option()      :: {max_line_length, pos_integer() | infinity}
                     | {control_chars, pass | strip | reject}.
-doc """
One element of a Gemini document. It is one of:

- `{h1 | h2 | h3 | para | list_item | quote, Text}`
- `{link, Url, Label}`
- `t:pref_block/0`
- `blank`
""".
-type tagged_line() :: gemini_text_line:line_element() | pref_block().

%%% API %%%

-doc """
Extract all the URLs in the links in the given Gemini page.

URLs are returned as written, in document order, and are not resolved
against any base. Links inside preformatted blocks are not extracted.
The result is an error in the same cases as [`parse/1`](`parse/1`).
""".
-spec urls(Text) -> Result
              when Text   :: binary(),
                   Result :: {ok, [binary()]} | {error, parse_error()}.

urls(Text) when is_binary(Text) ->
    case links(Text) of
        {ok, Links}        -> {ok, [URL || {link, URL, _} <- Links]};
        {error, _} = Error -> Error
    end.


-doc """
Extract all the links in the given Gemini page.

Each link is `{link, Url, Label}`, in document order. Links inside
preformatted blocks are not extracted. The result is an error in the same
cases as [`parse/1`](`parse/1`).
""".
-spec links(Text) -> Result
              when Text   :: binary(),
                   Result :: {ok, [gemini_text_line:link_line()]}
                           | {error, parse_error()}.
links(Text) when is_binary(Text) ->
    case parse(Text) of
        {ok, Elts}         -> {ok, [L || L = {link, _, _} <- Elts]};
        {error, _} = Error -> Error
    end.


-doc """
Parse `Text` as a Gemini document.

Returns `{ok, Elements}` in document order (see `t:tagged_line/0`), or
`{error, {invalid_utf8, N}}` if line `N` (counting from 1, blank lines
included) is not valid UTF-8, stopping at the first such line. Lines
may end in LF or CRLF, mixed freely; a bare CR is not a line break.
Blank lines are kept, as `blank`. A preformatted block still open at the
end of the input is returned as if it had been closed.

A line over 1 MiB (1048576 bytes, counted before the LF and including
any CR) is the error `{line_too_long, N}`; this is checked before UTF-8.
Use `new_context/1` with `parse/2` to change the limit.

The input must be UTF-8; text in any other charset must be transcoded
first. Text is passed through unfiltered, including control characters,
so renderers should sanitise it before display.
""".
-spec parse(Text) -> Result
              when Text   :: binary(),
                   Result :: {ok, [tagged_line()]} | {error, parse_error()}.
parse(Text) when is_binary(Text) ->
    case parse(Text, new_context()) of
        {ok, Elts, Ctx} ->
            case finish(Ctx) of
                {ok, Rest}         -> {ok, Elts ++ Rest};
                {error, _} = Error -> Error
            end;
        {error, _} = Error ->
            Error
    end.


-doc """
Start a streaming parse, with nothing seen yet and the default options.

[`parse/1`](`parse/1`) uses this too, so it also has the default
`max_line_length`.
""".
-spec new_context() -> context().
new_context() ->
    {ok, Ctx} = new_context([]),
    Ctx.


-doc """
Start a streaming parse with the given options (see `t:option/0`).

The options are a proplist: the first occurrence of a key wins. An
unknown or malformed option gives `{error, {bad_option, Option}}`.
""".
-spec new_context(Options) -> Result
              when Options :: [option()],
                   Result  :: {ok, context()}
                            | {error, {bad_option, term()}}.
new_context(Options) when is_list(Options) ->
    case lists:dropwhile(fun valid_option/1, Options) of
        [] ->
            Max = proplists:get_value(max_line_length, Options,
                                      ?DEFAULT_MAX_LINE_LENGTH),
            Ctrl = proplists:get_value(control_chars, Options, pass),
            {ok, #ctx{max_line = Max, control_chars = Ctrl}};
        [Bad|_] ->
            {error, {bad_option, Bad}}
    end.


-doc """
Parse the next chunk of a document.

The chunk may be of any size and may end anywhere, even in the middle of
a line, a CRLF or a multibyte character. Returns the elements completed
by this chunk, in document order, and the new context to use for the
next chunk. A line is only parsed, and checked, once its LF has arrived.
A preformatted block is returned as one element when its closing fence
arrives, or by [`finish/1`](`finish/1`).

On an error, no context is returned, so the stream cannot be continued.
The errors are those of [`parse/1`](`parse/1`).
""".
-spec parse(Chunk, Context) -> Result
              when Chunk   :: binary(),
                   Context :: context(),
                   Result  :: {ok, [tagged_line()], context()}
                            | {error, parse_error()}.
parse(Chunk, #ctx{pref = Pref, partial = Partial, line = N,
                  max_line = Max, control_chars = Ctrl} = Ctx)
  when is_binary(Chunk) ->
    {Lines, Partial1} = split_lines(<<Partial/binary, Chunk/binary>>),
    case parse_lines(Lines, N, {Max, Ctrl}, {[], Pref}) of
        {ok, N1, {Acc, Pref1}} ->
            case too_long(Partial1, Max) of
                false ->
                    {ok, lists:reverse(Acc),
                     Ctx#ctx{pref = Pref1, partial = Partial1, line = N1}};
                true ->
                    {error, {line_too_long, N1}}
            end;
        {error, _} = Error ->
            Error
    end.


-doc """
End a streaming parse.

Parses the last line if the document did not end in a line ending, and
returns the elements still pending, including a preformatted block which
was never closed. The errors are those of [`parse/1`](`parse/1`).
""".
-spec finish(Context) -> Result
              when Context :: context(),
                   Result  :: {ok, [tagged_line()]}
                            | {error, parse_error()}.
finish(#ctx{pref = Pref, partial = <<>>}) ->
    {ok, lists:reverse(finish_pref(Pref, []))};
finish(#ctx{pref = Pref, partial = Partial, line = N,
            max_line = Max, control_chars = Ctrl}) ->
    % the length check in check_line/3 is redundant here, as parse/2
    % already caps the partial line, but the other checks are needed
    case check_line(Partial, N, {Max, Ctrl}) of
        {ok, Line} ->
            {Acc, Pref1} = parse_line(Line, {[], Pref}),
            {ok, lists:reverse(finish_pref(Pref1, Acc))};
        {error, _} = Error ->
            Error
    end.


%%% Internal %%%

% fold parse_line/2 over the lines, stopping at the first line which
% is not valid UTF-8; N is the number of the first line, and the number
% of the line after the last one is returned
-spec parse_lines(Lines, N, Opts, State) -> Result
              when Lines  :: [binary()],
                   N      :: pos_integer(),
                   Opts   :: opts(),
                   State  :: state(),
                   Result :: {ok, pos_integer(), state()}
                           | {error, parse_error()}.
parse_lines([], N, _Opts, State) ->
    {ok, N, State};
parse_lines([Raw|Lines], N, Opts, State) ->
    case check_line(Raw, N, Opts) of
        {ok, Line} -> parse_lines(Lines, N + 1, Opts,
                                  parse_line(Line, State));
        {error, _} = Error -> Error
    end.


% check a raw line (with any CR, without the LF) in this order: length,
% UTF-8, control characters; return it without the CR, and with the
% control characters dealt with
-spec check_line(Raw, N, Opts) -> Result
              when Raw    :: binary(),
                   N      :: pos_integer(),
                   Opts   :: opts(),
                   Result :: {ok, binary()} | {error, parse_error()}.
check_line(Raw, N, {Max, Ctrl}) ->
    Line = strip_cr(Raw),
    case {too_long(Raw, Max), valid_utf8(Line)} of
        {true, _}      -> {error, {line_too_long, N}};
        {false, false} -> {error, {invalid_utf8, N}};
        {false, true}  -> control_chars(Line, N, Ctrl)
    end.


-spec control_chars(Line, N, Ctrl) -> Result
              when Line   :: binary(),
                   N      :: pos_integer(),
                   Ctrl   :: pass | strip | reject,
                   Result :: {ok, binary()} | {error, parse_error()}.
control_chars(Line, _N, pass) ->
    {ok, Line};
control_chars(Line, _N, strip) ->
    {ok, re:replace(Line, ?CONTROL_CHARS, <<>>,
                    [global, unicode, {return, binary}])};
control_chars(Line, N, reject) ->
    case re:run(Line, ?CONTROL_CHARS, [unicode]) of
        nomatch -> {ok, Line};
        {match, _} -> {error, {invalid_char, N}}
    end.


% is the raw line (with any CR, without the LF) over the limit?
-spec too_long(Line, Max) -> Result
              when Line   :: binary(),
                   Max    :: pos_integer() | infinity,
                   Result :: boolean().
too_long(_Line, infinity) -> false;
too_long(Line, Max) -> byte_size(Line) > Max.


-spec valid_option(Option) -> Result
              when Option :: term(),
                   Result :: boolean().
valid_option({max_line_length, infinity}) -> true;
valid_option({max_line_length, N}) -> is_integer(N) andalso N > 0;
valid_option({control_chars, V}) -> lists:member(V, [pass, strip, reject]);
valid_option(_) -> false.


-spec valid_utf8(Line) -> Result
              when Line   :: binary(),
                   Result :: boolean().
valid_utf8(Line) ->
    is_binary(unicode:characters_to_binary(Line, utf8, utf8)).


% an unterminated preformatted block is still emitted
-spec finish_pref(Pref, Acc) -> Result
              when Pref   :: pref_state(),
                   Acc    :: [tagged_line()],
                   Result :: [tagged_line()].
finish_pref(none, Acc) ->
    Acc;
finish_pref(Pref, Acc) ->
    [pref_block(Pref)|Acc].


% Acc is in reverse order; Pref is the preformatted block being built
-spec parse_line(Line, State) -> Result
              when Line   :: binary(),
                   State  :: state(),
                   Result :: state().
parse_line(Line, {Acc, Pref}) ->
    case {gemini_text_line:pref_marker(Line), Pref} of
        {false, none} ->
            {[gemini_text_line:tag(Line)|Acc], none};
        {false, {Alt, PrefAcc}} ->
            {Acc, {Alt, [Line|PrefAcc]}};
        {true, none} ->
            {Acc, {gemini_text_line:alt_text(Line), []}};
        {true, _} ->
            {[pref_block(Pref)|Acc], none}
    end.


% lines end in LF or CRLF (the CR is not stripped here); blank lines
% are kept. Returns the complete lines and the rest, which has no LF
% yet and may be empty.
-spec split_lines(Text) -> Result
              when Text   :: binary(),
                   Result :: {[binary()], binary()}.
split_lines(Text) ->
    [Rest|RevLines] = lists:reverse(binary:split(Text, <<"\n">>, [global])),
    {lists:reverse(RevLines), Rest}.


-spec strip_cr(Line) -> Result
              when Line   :: binary(),
                   Result :: binary().
strip_cr(<<>>) ->
    <<>>;
strip_cr(Line) ->
    Size = byte_size(Line) - 1,
    case Line of
        <<Init:Size/binary, $\r>> -> Init;
        _ -> Line
    end.


-spec pref_block(Pref) -> Result
              when Pref   :: {binary(), [binary()]},
                   Result :: pref_block().
pref_block({Alt, PrefAcc}) ->
    {preformatted, Alt, lists:reverse(PrefAcc)}.

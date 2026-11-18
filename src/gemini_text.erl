%%%-------------------------------------------------------------------
%%% @author Martin Keegan <mk270@stove>
%%% @copyright (C) 2023, Martin Keegan
%%% Created : 23 Dec 2023 by Martin Keegan <mk270@stove>
%%%-------------------------------------------------------------------

-module(gemini_text).

-moduledoc """
Parse Gemini-formatted text.

[`parse/1`](`parse/1`) takes a binary and returns a list of elements
(see `t:tagged_line/0`) in document order, or `{error, invalid_utf8}` if
the input is not valid UTF-8.

[`links/1`](`links/1`) and [`urls/1`](`urls/1`) are helpers which
extract just the links, or just their URLs.
""".

-author('martin@no.ucant.org').

-export([parse/1, links/1, urls/1]).

-export_type([tagged_line/0, pref_block/0]).

-doc """
A preformatted block: `{preformatted, Alt, Lines}`.

`Alt` is the text after the opening fence, trimmed (it may be empty).
`Lines` are the lines of the body, verbatim and without line endings.
""".
-type pref_block()  :: {preformatted, binary(), [binary()]}.
-type pref_state()  :: none | {binary(), [binary()]}.
-type state()       :: {[tagged_line()], pref_state()}.
-doc """
One element of a Gemini document. It is one of:

- `{h1 | h2 | h3 | para, Text}`
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
                   Result :: {ok, [binary()]} | {error, term()}.

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
                           | {error, term()}.
links(Text) when is_binary(Text) ->
    case parse(Text) of
        {ok, Elts}         -> {ok, [L || L = {link, _, _} <- Elts]};
        {error, _} = Error -> Error
    end.


-doc """
Parse `Text` as a Gemini document.

Returns `{ok, Elements}` in document order (see `t:tagged_line/0`), or
`{error, invalid_utf8}` if any line is not valid UTF-8. Lines end in LF
or CRLF. Blank lines are kept, as `blank`. A preformatted block still
open at the end of the input is returned as if it had been closed.
""".
-spec parse(Text) -> Result
              when Text   :: binary(),
                   Result :: {ok, [tagged_line()]} | {error, term()}.
parse(Text) when is_binary(Text) ->
    Lines = split_lines(Text),
    case parse_lines(Lines, {[], none}) of
        {ok, {Acc, Pref}}  -> {ok, lists:reverse(finish_pref(Pref, Acc))};
        {error, _} = Error -> Error
    end.


%%% Internal %%%

% fold parse_line/2 over the lines, stopping at the first line which
% is not valid UTF-8
-spec parse_lines(Lines, State) -> Result
              when Lines  :: [binary()],
                   State  :: state(),
                   Result :: {ok, state()} | {error, invalid_utf8}.
parse_lines([], State) ->
    {ok, State};
parse_lines([Line|Lines], State) ->
    case valid_utf8(Line) of
        true -> parse_lines(Lines, parse_line(Line, State));
        false -> {error, invalid_utf8}
    end.


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


% lines end in LF or CRLF; blank lines are kept
-spec split_lines(Text) -> Result
              when Text   :: binary(),
                   Result :: [binary()].
split_lines(Text) ->
    Lines = binary:split(Text, <<"\n">>, [global]),
    Lines1 = case lists:reverse(Lines) of
                 [<<>>|Rev] -> lists:reverse(Rev);
                 _ -> Lines
             end,
    [strip_cr(L) || L <- Lines1].


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

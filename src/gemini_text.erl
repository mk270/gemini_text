%%%-------------------------------------------------------------------
%%% @author Martin Keegan <mk270@stove>
%%% @copyright (C) 2023, Martin Keegan
%%% @doc
%%%
%%% @end
%%% Created : 23 Dec 2023 by Martin Keegan <mk270@stove>
%%%-------------------------------------------------------------------

% transitional from v1.0.0 to v2.0.0:
%
% the only call we need to support is:
%
%   urls/1:
%
%   -spec urls(Body) -> Result
%           when Body   :: binary(),
%                Result :: {ok, [binary()]} | {error, term()}.
%

-module(gemini_text).

% todo:
%   docs
%   tests for the other bits
%   multiple blank lines

-export([parse/1, links/1, urls/1]).

-type simple_tag()  :: h1 | h2 | h3 | para.
-type simple_line() :: {simple_tag(), binary()}.
-type tag()         :: simple_tag() | link.
-type link_line()   :: {link, binary(), binary()}.
-type pref_block()  :: {preformatted, binary(), [binary()]}.
-type pref_state()  :: none | {binary(), [binary()]}.
-type state()       :: {[tagged_line()], pref_state()}.
-type tagged_line() :: simple_line() | link_line() | pref_block() | blank.

-doc "Extract all the URLs in the links in the given Gemini page.".
-spec urls(Text) -> Result
              when Text   :: binary(),
                   Result :: {ok, [binary()]} | {error, term()}.
urls(Text) when is_binary(Text) ->
    {ok, Links} = links(Text),
    {ok, [URL || {link, URL, _} <- Links]}.


-spec links(Text) -> Result
              when Text   :: binary(),
                   Result :: {ok, [link_line()]} | {error, term()}.
links(Text) when is_binary(Text) ->
    {ok, Elts} = parse(Text),
    {ok, [L || L = {link, _, _} <- Elts]}.


-spec parse(Text) -> Result
              when Text   :: binary(),
                   Result :: {ok, [tagged_line()]} | {error, term()}.
parse(Text) when is_binary(Text) ->
    Lines = split_lines(Text),
    {Acc, Pref} = lists:foldl(fun parse_line/2, {[], none}, Lines),
    {ok, lists:reverse(finish_pref(Pref, Acc))}.


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
    case {pref_marker(Line), Pref} of
        {false, none} -> {[tag(Line)|Acc], none};
        {false, {Alt, PrefAcc}} -> {Acc, {Alt, [Line|PrefAcc]}};
        {true, none} -> {Acc, {alt_text(Line), []}};
        {true, _} -> {[pref_block(Pref)|Acc], none}
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


% is this line one that begins/ends a preformatted block?
-spec pref_marker(Line) -> Result
              when Line   :: binary(),
                   Result :: boolean().
pref_marker(Line) ->
    prefix(<<"```">>, Line).


% the text after the ``` which opens a preformatted block
-spec alt_text(Line) -> Result
              when Line   :: binary(),
                   Result :: binary().
alt_text(<<"```", Rest/binary>>) ->
    string:trim(Rest).


-spec tag(Arg) -> Result
              when Arg    :: binary(),
                   Result :: tagged_line().
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
                   Result  :: tagged_line().

tag2(Line, [{Prefix, Tag}|T]) ->
    case prefix(Prefix, Line) of
        true -> tag3(Line, Tag);
        false -> tag2(Line, T)
    end.


-spec tag3(Line, Tag) -> Result
              when Line   :: binary(),
                   Tag    :: tag() | link_no_space,
                   Result :: tagged_line().

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

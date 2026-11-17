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
-include_lib("eunit/include/eunit.hrl").

% todo:
%   preformatting
%   docs
%   tests for the other bits
%   specs
%   multiple blank lines

-export([parse/1, links/1, urls/1]).

-type simple_tag()  :: h1 | h2 | h3 | para | preformatted_line.
-type simple_line() :: {simple_tag(), binary()}.
-type tag()         :: simple_tag() | link.
-type link_line()   :: {link, binary(), binary()}.
-type tagged_line() :: simple_line() | link_line().

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
    Lines = binary:split(Text, [<<"\r">>, <<"\n">>], [global, trim_all]),
    Unformatted = unformat(Lines),
    Tagged = [tag(Line) || Line <- Unformatted],
    RevTagged = lists:reverse(Tagged),
    {ok, gather_preformatted(RevTagged)}.


-spec gather_preformatted(Lines) -> Result
              when Lines  :: [tagged_line()],
                   Result :: [tagged_line() | {preformatted, [binary()]}].
gather_preformatted(Lines) ->
    gather_preformatted(Lines, [], []).


-spec gather_preformatted(Lines, Acc, PrefAcc) -> Result
              when Lines   :: [tagged_line()],
                   Acc     :: [tagged_line() | {preformatted, [binary()]}],
                   PrefAcc :: [binary()],
                   Result  :: [tagged_line() | {preformatted, [binary()]}].

gather_preformatted([], Acc, []) ->
    lists:reverse(Acc);

gather_preformatted([], Acc, PrefAcc) ->
    P = {preformatted, lists:reverse(PrefAcc)},
    lists:reverse([P|Acc]);

gather_preformatted([{preformatted_line, PL}|Tail], Acc, PrefAcc) ->
    gather_preformatted(Tail, Acc, [PL|PrefAcc]);

gather_preformatted([Head|Tail], Acc, []) ->
    gather_preformatted(Tail, [Head|Acc], []);

gather_preformatted([Head|Tail], Acc, PrefAcc) ->
    P = {preformatted, lists:reverse(PrefAcc)},
    gather_preformatted(Tail, [Head|[P|Acc]], []).


-spec unformat(Lines) -> Result
              when Lines  :: [binary()],
                   Result :: [{binary(), boolean()}].
unformat(Lines) ->
    unformat(Lines, [], false).


% this (or something else) should collate the preformatted lines
-spec unformat(Head, Acc, Preformatted) -> Result
              when Head         :: [binary()],
                   Acc          :: [{binary(), boolean()}],
                   Preformatted :: boolean(),
                   Result       :: [{binary(), boolean()}].

unformat([], Acc, _) ->
    Acc;
unformat([H|T], Acc, Preformatted) ->
    case {pref_marker(H), Preformatted} of
        {false, _} -> unformat(T, [{H,Preformatted}|Acc], Preformatted);
        {true, true} -> unformat(T, Acc, false);
        {true, false} -> unformat(T, Acc, true)
    end.


% is this line one that begins/ends a preformatted block?
-spec pref_marker(Line) -> Result
              when Line   :: binary(),
                   Result :: boolean().
pref_marker(Line) ->
    prefix(<<"```">>, Line).


-spec tag(Arg) -> Result
              when Arg    :: {binary(), boolean()},
                   Result :: tagged_line().
tag({Line, true}) -> {preformatted_line, Line};
tag({Line, false}) ->
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

tag2(Line, []) ->
    {para, Line}; % shouldn't hit here, due to the {<<>>, para} guard
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
    % hackily remove first two chars, known to be ">="
    <<$=, $>, RestOfLine/binary>> = Line,
    {URL, Caption} = split_once(RestOfLine),
    {link, URL, Caption};
tag3(Line, para) ->
    {para, Line};
tag3(Line, Tag) ->
    {_Tag, Caption} = split_once(Line),
    {Tag, Caption}.


-spec prefix(Prefix, Line) -> Result
              when Prefix :: binary(),
                   Line   :: binary(),
                   Result :: boolean().
prefix(Prefix, Line) ->
    binary:longest_common_prefix([Prefix, Line]) =:= byte_size(Prefix).


% split string on first space
-spec split_once(S) -> Result
              when S      :: binary(),
                   Result :: {binary(), binary()}.
split_once(S) ->
    {Prefix, Suffix} = case binary:split(S, [<<" ">>, <<"\t">>]) of
                           [P, Rest] -> {P, Rest};
                           [P] -> {P, <<>>}
                       end,
    {Prefix, string:trim(Suffix)}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                                TESTS                                    %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parser_test_() ->
    Tests = [
             {[{h1, <<"hi">>}],
              <<"# hi\r\n">>},

             {[{link, <<"foo">>, <<"bar">>}],
              <<"=> foo bar\r\n">>},

             {[{link, <<"foo">>, <<"bar">>}],
              <<"=> foo  bar\r\n">>},

             {[{link, <<"foo">>, <<"bar baz">>}],
              <<"=>  foo bar baz\r\n">>},

             {[{link, <<"foo">>, <<"bar  baz">>}],
              <<"=> foo bar  baz\r\n">>},

             {[{link, <<"foo">>, <<"bar baz">>}],
              <<"=>\tfoo\tbar baz\r\n">>},

             {[{link, <<"foo">>, <<"baq baqz">>}],
              <<"=>foo baq baqz\r\n">>}

            ],
    [?_assertEqual({ok, Expected}, parse(Input))
     || {Expected, Input} <- Tests].

urls_test_() ->
    [?_assertEqual({ok, [<<"foo">>]}, urls(<<"=> foo bar\r\n">>))].

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

-type simple_tag()  :: h1 | h2 | h3 | para.
-type simple_line() :: {simple_tag(), binary()}.
-type tag()         :: simple_tag() | link.
-type link_line()   :: {link, binary(), binary()}.
-type pref_block()  :: {preformatted, binary(), [binary()]}.
-type pref_line()   :: {preformatted_line, binary()}.
-type fence_line()  :: {preformatted_start, binary()}.
-type raw_line()    :: tagged_line() | pref_line() | fence_line().
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
    Unformatted = unformat(Lines),
    Tagged = [tag(Line) || Line <- Unformatted],
    RevTagged = lists:reverse(Tagged),
    {ok, gather_preformatted(RevTagged)}.


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


-spec gather_preformatted(Lines) -> Result
              when Lines  :: [raw_line()],
                   Result :: [tagged_line()].
gather_preformatted(Lines) ->
    gather_preformatted(Lines, [], none).


-spec gather_preformatted(Lines, Acc, Pref) -> Result
              when Lines  :: [raw_line()],
                   Acc    :: [tagged_line()],
                   Pref   :: none | {binary(), [binary()]},
                   Result :: [tagged_line()].

gather_preformatted([], Acc, none) ->
    lists:reverse(Acc);

gather_preformatted([], Acc, Pref) ->
    lists:reverse([pref_block(Pref)|Acc]);

gather_preformatted([{preformatted_start, Alt}|Tail], Acc, none) ->
    gather_preformatted(Tail, Acc, {Alt, []});

gather_preformatted([{preformatted_start, Alt}|Tail], Acc, Pref) ->
    gather_preformatted(Tail, [pref_block(Pref)|Acc], {Alt, []});

gather_preformatted([{preformatted_line, PL}|Tail], Acc, {Alt, PrefAcc}) ->
    gather_preformatted(Tail, Acc, {Alt, [PL|PrefAcc]});

gather_preformatted([Head|Tail], Acc, none) ->
    gather_preformatted(Tail, [Head|Acc], none);

gather_preformatted([Head|Tail], Acc, Pref) ->
    gather_preformatted(Tail, [Head|[pref_block(Pref)|Acc]], none).


-spec pref_block(Pref) -> Result
              when Pref   :: {binary(), [binary()]},
                   Result :: pref_block().
pref_block({Alt, PrefAcc}) ->
    {preformatted, Alt, lists:reverse(PrefAcc)}.


-spec unformat(Lines) -> Result
              when Lines  :: [binary()],
                   Result :: [{binary(), boolean() | fence}].
unformat(Lines) ->
    unformat(Lines, [], false).


% this (or something else) should collate the preformatted lines
-spec unformat(Head, Acc, Preformatted) -> Result
              when Head         :: [binary()],
                   Acc          :: [{binary(), boolean() | fence}],
                   Preformatted :: boolean(),
                   Result       :: [{binary(), boolean() | fence}].

unformat([], Acc, _) ->
    Acc;
unformat([H|T], Acc, Preformatted) ->
    case {pref_marker(H), Preformatted} of
        {false, _} -> unformat(T, [{H,Preformatted}|Acc], Preformatted);
        {true, true} -> unformat(T, Acc, false);
        {true, false} -> unformat(T, [{alt_text(H),fence}|Acc], true)
    end.


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
              when Arg    :: {binary(), boolean() | fence},
                   Result :: raw_line().
tag({Line, true}) -> {preformatted_line, Line};
tag({Alt, fence}) -> {preformatted_start, Alt};
tag({<<>>, false}) -> blank;
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

heading_test_() ->
    [?_assertEqual({ok, [{h1, <<"hi">>}]}, parse(<<"#hi\r\n">>)),
     ?_assertEqual({ok, [{h2, <<"hi">>}]}, parse(<<"##hi\r\n">>)),
     ?_assertEqual({ok, [{h3, <<"hi">>}]}, parse(<<"###  hi\r\n">>)),
     ?_assertEqual({ok, [{h1, <<"hi there">>}]},
                   parse(<<"# hi there\r\n">>))].

blank_line_test_() ->
    [?_assertEqual({ok, []}, parse(<<>>)),
     ?_assertEqual({ok, [blank]}, parse(<<"\r\n">>)),
     ?_assertEqual({ok, [{para, <<"a">>}, blank, {para, <<"b">>}]},
                   parse(<<"a\r\n\r\nb\r\n">>)),
     ?_assertEqual({ok, [blank, blank]}, parse(<<"\n\n">>)),
     ?_assertEqual({ok, [{para, <<"a">>}]}, parse(<<"a">>)),
     ?_assertEqual({ok, [{para, <<"a\rb">>}]}, parse(<<"a\rb\r\n">>))].

preformatted_test_() ->
    [?_assertEqual({ok, [{preformatted, <<>>, [<<"=> x y">>]}]},
                   parse(<<"```\r\n=> x y\r\n```\r\n">>)),
     ?_assertEqual({ok, [{preformatted, <<"alt text">>, [<<"a">>, <<>>]}]},
                   parse(<<"``` alt text \r\na\r\n\r\n```\r\n">>)),
     ?_assertEqual({ok, [{preformatted, <<>>, []}]},
                   parse(<<"```\r\n```\r\n">>)),
     ?_assertEqual({ok, [{preformatted, <<"x">>, [<<"a">>]}]},
                   parse(<<"```x\r\na\r\n">>)),
     ?_assertEqual({ok, [{para, <<"p">>},
                         {preformatted, <<"x">>, [<<"a">>]},
                         {preformatted, <<"y">>, [<<"b">>]},
                         {para, <<"q">>}]},
                   parse(<<"p\r\n```x\r\na\r\n```\r\n"
                           "```y\r\nb\r\n```\r\nq\r\n">>))].

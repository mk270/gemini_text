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
%           when Body   :: string(),
%                Result :: [string()].
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
-type simple_line() :: {simple_tag(), string()}.
-type tag()         :: simple_tag() | link.
-type link_line()   :: {link, string(), string()}.
-type tagged_line() :: simple_line() | link_line().

-doc "Extract all the URLs in the links in the given Gemini page.".
-spec urls(Text) -> Result
              when Text   :: string(),
                   Result :: [string()].
urls(Text) when is_list(Text) ->
    [URL || {link, URL, _} <- links(Text)].


-spec links(Text) -> Result
              when Text   :: string(),
                   Result :: [link_line()].
links(Text) when is_list(Text) ->
    Elts = parse(Text),
    [L || L = {link, _, _} <- Elts].         


-spec parse(Text) -> Result
              when Text   :: string(),
                   Result :: [tagged_line()].
parse(Text) when is_list(Text) ->
    Lines = string:tokens(Text, "\r\n"),
    Unformatted = unformat(Lines),
    Tagged = [tag(Line) || Line <- Unformatted],
    RevTagged = lists:reverse(Tagged),
    gather_preformatted(RevTagged).


gather_preformatted(Lines) ->
    gather_preformatted(Lines, [], []).


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
              when Lines  :: [string()],
                   Result :: [{string(), boolean()}].
unformat(Lines) ->
    unformat(Lines, [], false).


% this (or something else) should collate the preformatted lines
-spec unformat(Head, Acc, Preformatted) -> Result
              when Head         :: [string()],
                   Acc          :: [{string(), boolean()}],
                   Preformatted :: boolean(),
                   Result       :: [{string(), boolean()}].

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
              when Line   :: string(),
                   Result :: boolean().
pref_marker(Line) ->
    lists:prefix("```", Line).


-spec tag(Arg) -> Result
              when Arg    :: {string(), boolean()},
                   Result :: tagged_line().
tag({Line, true}) -> {preformatted_line, Line};
tag({Line, false}) ->
    Matcher = [
               {"=> ", link},
               {"=>\t", link},
               {"=>", link_no_space},
               {"###", h3},
               {"##", h2},
               {"#", h1},
               {"", para}
              ],
    tag2(Line, Matcher).


-spec tag2(Line, Matcher) -> Result
              when Line    :: string(),
                   Matcher :: [{string(), tag() | link_no_space}],
                   Result  :: tagged_line().

tag2(Line, []) ->
    {para, Line}; % shouldn't hit here, due to the {"", para} guard
tag2(Line, [{Prefix, Tag}|T]) ->
    case lists:prefix(Prefix, Line) of
        true -> tag3(Line, Tag);
        false -> tag2(Line, T)
    end.


-spec tag3(Line, Tag) -> Result
              when Line   :: string(),
                   Tag    :: tag() | link_no_space,
                   Result :: tagged_line().

tag3(Line, link) ->
    {_Tag, URLandCaption} = split_once(Line),
    {URL, Caption} = split_once(URLandCaption),
    {link, URL, Caption};
tag3(Line, link_no_space) ->
    % hackily remove first two chars, known to be ">="
    [$=|[$>|RestOfLine]] = Line,
    {URL, Caption} = split_once(RestOfLine),
    {link, URL, Caption};
tag3(Line, para) ->
    {para, Line};
tag3(Line, Tag) ->
    {_Tag, Caption} = split_once(Line),
    {Tag, Caption}.


% split string on first space
-spec split_once(S) -> Result
              when S      :: string(),
                   Result :: {string(), string()}.
split_once(S) ->
    {Prefix, Suffix} = lists:splitwith(
                         fun(X) -> case X of
                                       $   -> false;
                                       $\t -> false;
                                       _ -> true
                                   end
                         end, S),
    {Prefix, string:trim(Suffix)}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                                TESTS                                    %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parser_test_() ->
    Tests = [
             {[{h1, "hi"}],
              "# hi\r\n"},

             {[{link, "foo", "bar"}],
              "=> foo bar\r\n"},

             {[{link, "foo", "bar"}],
              "=> foo  bar\r\n"},

             {[{link, "foo", "bar baz"}],
              "=>  foo bar baz\r\n"},

             {[{link, "foo", "bar  baz"}],
              "=> foo bar  baz\r\n"},

             {[{link, "foo", "bar baz"}],
              "=>\tfoo\tbar baz\r\n"},

             {[{link, "foo", "baq baqz"}],
              "=>foo baq baqz\r\n"}

            ],
    [?_assertEqual(Expected, parse(Input)) || {Expected, Input} <- Tests].

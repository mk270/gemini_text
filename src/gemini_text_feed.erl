%%%-------------------------------------------------------------------
%%% @copyright (C) 2026, Martin Keegan
%%%-------------------------------------------------------------------

-module(gemini_text_feed).

-moduledoc """
Extract a subscription feed from a Gemini page, following the Gemini
subscription convention.

[`feed/1`](`feed/1`) takes the text of a page and returns its title and
its entries (see `t:gemsub_entry/0`).
""".

-author('martin@no.ucant.org').

-export([feed/1]).

-export_type([gemsub_entry/0]).

-include("gemini_text.hrl").

-doc """
An entry of a subscribable page: `#gemsub_entry{url, date, title}`, with
the record defined in `include/gemini_text.hrl`. See `feed/1`.
""".
-type gemsub_entry() :: #gemsub_entry{}.

%%% API %%%

-doc """
Extract a subscription feed from the given Gemini page.

Returns `{ok, Title, Entries}`. `Title` is the text of the first
`#` heading, or the result is `{error, no_title}` if there is none.
Each entry (see `t:gemsub_entry/0`) comes from a link whose label starts
with a date, `YYYY-MM-DD`; other links are ignored, as are labels whose
date is not a real one. The entry's title is the label without its first
word (the one with the date) and without a following `-` separator, if
any. Entries are in document order, and their URLs are as written, not
resolved against any base. The result is an error in the same cases as
`gemini_text:parse/1`.
""".
-spec feed(Text) -> Result
              when Text   :: binary(),
                   Result :: {ok, Title :: binary(), [gemsub_entry()]}
                           | {error, no_title
                                   | gemini_text:parse_error()}.

feed(Text) when is_binary(Text) ->
    case gemini_text:parse(Text) of
        {ok, Elts} ->
            case lists:keyfind(h1, 1, Elts) of
                {h1, Title} ->
                    {ok, Title,
                     [E || {link, Url, Label} <- Elts,
                           E <- entry(Url, Label)]};
                false ->
                    {error, no_title}
            end;
        {error, _} = Error ->
            Error
    end.


% A link line is an entry if its label starts with a real date.
-spec entry(binary(), binary()) -> [gemsub_entry()].
entry(Url, <<Y:4/binary, $-, M:2/binary, $-, D:2/binary, Rest/binary>>) ->
    case date(Y, M, D) of
        {ok, Date} ->
            [#gemsub_entry{url = Url, date = Date, title = title(Rest)}];
        error ->
            []
    end;
entry(_Url, _Label) ->
    [].

-spec date(binary(), binary(), binary()) -> {ok, calendar:date()} | error.
date(Y, M, D) ->
    case lists:all(fun is_digits/1, [Y, M, D]) of
        true ->
            Date = {binary_to_integer(Y), binary_to_integer(M),
                    binary_to_integer(D)},
            case calendar:valid_date(Date) of
                true  -> {ok, Date};
                false -> error
            end;
        false ->
            error
    end.

is_digits(Bin) ->
    [C || <<C>> <= Bin, C < $0 orelse C > $9] =:= [].

% what is left of the label after the first word (which has the date),
% minus a "-" separator
-spec title(binary()) -> binary().
title(Rest) ->
    case binary:split(Rest, [<<" ">>, <<"\t">>]) of
        [_Word, Tail] -> strip_sep(trim(Tail));
        [_Word]       -> <<>>
    end.

strip_sep(<<$-, C, Tail/binary>>) when C =:= $\s; C =:= $\t -> trim(Tail);
strip_sep(<<$->>)                                           -> <<>>;
strip_sep(Tail)                                             -> Tail.

trim(Bin) ->
    string:trim(Bin, leading, [$\s, $\t]).

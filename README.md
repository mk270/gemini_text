# gemini_text

A parser for Gemini text (`text/gemini`, "gemtext") in Erlang.

## Parsing a whole document

```erlang
1> gemini_text:parse(<<"# Hello\r\n=> gemini://example.org/ A link\r\n">>).
{ok,[{h1,<<"Hello">>},
     {link,<<"gemini://example.org/">>,<<"A link">>}]}
```

## Parsing a stream

Chunks can be any size and can end anywhere, even in the middle of a line.

```erlang
1> C0 = gemini_text:new_context().
2> {ok, E1, C1} = gemini_text:parse(<<"# Hel">>, C0).
3> {ok, E2, C2} = gemini_text:parse(<<"lo\r\n=> gemini://exa">>, C1).
4> {ok, E3, C3} = gemini_text:parse(<<"mple.org/ A link\r\n">>, C2).
5> [E1, E2, E3].
[[],
 [{h1,<<"Hello">>}],
 [{link,<<"gemini://example.org/">>,<<"A link">>}]]
6> gemini_text:finish(C3).
{ok,[]}
```

## API documentation

<https://gemini-text.hexdocs.pm/api-reference.html>

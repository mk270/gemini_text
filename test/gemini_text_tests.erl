-module(gemini_text_tests).
-include_lib("eunit/include/eunit.hrl").

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
    [?_assertEqual({ok, Expected}, gemini_text:parse(Input))
     || {Expected, Input} <- Tests].

urls_test_() ->
    [?_assertEqual({ok, [<<"foo">>]},
                   gemini_text:urls(<<"=> foo bar\r\n">>))].

heading_test_() ->
    [?_assertEqual({ok, [{h1, <<"hi">>}]}, gemini_text:parse(<<"#hi\r\n">>)),
     ?_assertEqual({ok, [{h2, <<"hi">>}]}, gemini_text:parse(<<"##hi\r\n">>)),
     ?_assertEqual({ok, [{h3, <<"hi">>}]},
                   gemini_text:parse(<<"###  hi\r\n">>)),
     ?_assertEqual({ok, [{h1, <<"hi there">>}]},
                   gemini_text:parse(<<"# hi there\r\n">>))].

blank_line_test_() ->
    [?_assertEqual({ok, []}, gemini_text:parse(<<>>)),
     ?_assertEqual({ok, [blank]}, gemini_text:parse(<<"\r\n">>)),
     ?_assertEqual({ok, [{para, <<"a">>}, blank, {para, <<"b">>}]},
                   gemini_text:parse(<<"a\r\n\r\nb\r\n">>)),
     ?_assertEqual({ok, [blank, blank]}, gemini_text:parse(<<"\n\n">>)),
     ?_assertEqual({ok, [{para, <<"a">>}]}, gemini_text:parse(<<"a">>)),
     ?_assertEqual({ok, [{para, <<"a\rb">>}]},
                   gemini_text:parse(<<"a\rb\r\n">>))].

preformatted_test_() ->
    [?_assertEqual({ok, [{preformatted, <<>>, [<<"=> x y">>]}]},
                   gemini_text:parse(<<"```\r\n=> x y\r\n```\r\n">>)),
     ?_assertEqual({ok, [{preformatted, <<"alt text">>, [<<"a">>, <<>>]}]},
                   gemini_text:parse(<<"``` alt text \r\na\r\n\r\n"
                                       "```\r\n">>)),
     ?_assertEqual({ok, [{preformatted, <<>>, []}]},
                   gemini_text:parse(<<"```\r\n```\r\n">>)),
     ?_assertEqual({ok, [{preformatted, <<"x">>, [<<"a">>]}]},
                   gemini_text:parse(<<"```x\r\na\r\n">>)),
     ?_assertEqual({ok, [{para, <<"p">>},
                         {preformatted, <<"x">>, [<<"a">>]},
                         {preformatted, <<"y">>, [<<"b">>]},
                         {para, <<"q">>}]},
                   gemini_text:parse(<<"p\r\n```x\r\na\r\n```\r\n"
                           "```y\r\nb\r\n```\r\nq\r\n">>))].

heading_quirks_test_() ->
    [?_assertEqual({ok, [{h1, <<"hashtag">>}]},
                   gemini_text:parse(<<"#hashtag\r\n">>)),
     ?_assertEqual({ok, [{h1, <<>>}]}, gemini_text:parse(<<"#\r\n">>)),
     ?_assertEqual({ok, [{h3, <<"#x">>}]},
                   gemini_text:parse(<<"####x\r\n">>))].

link_edge_test_() ->
    [?_assertEqual({ok, [{link, <<"foo">>, <<>>}]},
                   gemini_text:parse(<<"=> foo\r\n">>)),
     ?_assertEqual({ok, [{link, <<"foo">>, <<>>}]},
                   gemini_text:parse(<<"=> foo   \r\n">>)),
     ?_assertEqual({ok, [{link, <<>>, <<>>}]},
                   gemini_text:parse(<<"=>\r\n">>)),
     ?_assertEqual({ok, [{link, <<>>, <<>>}]},
                   gemini_text:parse(<<"=> \r\n">>)),
     ?_assertEqual({ok, [{link, <<>>, <<>>}]},
                   gemini_text:parse(<<"=>\t\r\n">>))].

preformatted_content_test_() ->
    [?_assertEqual({ok, [{preformatted, <<>>,
                          [<<"# h">>, <<"=> u l">>, <<>>, <<"  x">>]}]},
                   gemini_text:parse(<<"```\r\n# h\r\n=> u l\r\n\r\n"
                                       "  x\r\n```\r\n">>))].

preformatted_close_test_() ->
    [?_assertEqual({ok, [{preformatted, <<"x">>, [<<"a">>]},
                         {para, <<"b">>}]},
                   gemini_text:parse(<<"```x\r\na\r\n``` junk\r\nb\r\n">>))].

preformatted_unterminated_test_() ->
    [?_assertEqual({ok, [{preformatted, <<>>, []}]},
                   gemini_text:parse(<<"```\r\n">>)),
     ?_assertEqual({ok, [{preformatted, <<>>, []}]},
                   gemini_text:parse(<<"```">>)),
     ?_assertEqual({ok, [{preformatted, <<"x">>, [<<"a">>, <<"b">>]}]},
                   gemini_text:parse(<<"```x\r\na\r\nb">>))].

no_final_terminator_test_() ->
    [?_assertEqual({ok, [{h1, <<"hi">>}]}, gemini_text:parse(<<"# hi">>)),
     ?_assertEqual({ok, [{link, <<"foo">>, <<"bar">>}]},
                   gemini_text:parse(<<"=> foo bar">>)),
     ?_assertEqual({ok, [{para, <<"a">>}, {para, <<"b">>}]},
                   gemini_text:parse(<<"a\r\nb">>))].

line_ending_test_() ->
    [?_assertEqual({ok, [{para, <<"a">>}, {para, <<"b">>},
                         {para, <<"c">>}]},
                   gemini_text:parse(<<"a\nb\r\nc\n">>)),
     ?_assertEqual({ok, [{para, <<"a">>}, blank, {para, <<"b">>}]},
                   gemini_text:parse(<<"a\r\n\nb\r\n">>))].

whitespace_line_test_() ->
    [?_assertEqual({ok, [{para, <<"  ">>}]},
                   gemini_text:parse(<<"  \r\n">>)),
     ?_assertEqual({ok, [{para, <<" a">>}]},
                   gemini_text:parse(<<" a\r\n">>))].

links_test_() ->
    [?_assertEqual({ok, [{link, <<"a">>, <<"x">>},
                         {link, <<"b">>, <<>>}]},
                   gemini_text:links(<<"# t\r\n=> a x\r\ntext\r\n"
                                       "=> b\r\n">>)),
     ?_assertEqual({ok, []}, gemini_text:links(<<"# t\r\ntext\r\n">>)),
     ?_assertEqual({ok, []}, gemini_text:links(<<>>))].

urls_more_test_() ->
    [?_assertEqual({ok, [<<"a">>, <<"b">>]},
                   gemini_text:urls(<<"=> a x\r\ntext\r\n=> b\r\n">>)),
     ?_assertEqual({ok, []}, gemini_text:urls(<<"# t\r\n">>)),
     ?_assertEqual({ok, []}, gemini_text:urls(<<>>)),
     ?_assertEqual({ok, [<<"z">>]},
                   gemini_text:urls(<<"```\r\n=> x y\r\n```\r\n"
                                      "=> z\r\n">>))].

invalid_utf8_test_() ->
    Err = {error, {invalid_utf8, 1}},
    [?_assertEqual(Err, gemini_text:parse(<<"# h\xff\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"p\xff\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"=> u\xff l\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"=> u \xff\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"# \xc3\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"```a\xff\r\n">>)),
     ?_assertEqual({error, {invalid_utf8, 2}},
                   gemini_text:parse(<<"```\r\n\xff\r\n```\r\n">>)),
     ?_assertEqual({error, {invalid_utf8, 2}},
                   gemini_text:parse(<<"a\r\nb\xff">>))].

% line numbers count every line, including blank ones; the first bad
% line is the one reported
invalid_utf8_line_test_() ->
    [?_assertEqual({error, {invalid_utf8, 4}},
                   gemini_text:parse(<<"a\n\n\nb\xff\nc\xff\n">>)),
     ?_assertEqual({error, {invalid_utf8, 3}},
                   gemini_text:parse(<<"a\r\n\r\n\xff">>))].

invalid_utf8_api_test_() ->
    Err = {error, {invalid_utf8, 1}},
    [?_assertEqual(Err, gemini_text:links(<<"=> a\xff b\r\n">>)),
     ?_assertEqual(Err, gemini_text:urls(<<"=> a b\xff\r\n">>))].

valid_utf8_test_() ->
    [?_assertEqual({ok, [{para, <<"caf\xc3\xa9">>}]},
                   gemini_text:parse(<<"caf\xc3\xa9\r\n">>)),
     ?_assertEqual({ok, [{link, <<"u">>, <<"\xe2\x82\xac">>}]},
                   gemini_text:parse(<<"=> u \xe2\x82\xac\r\n">>))].

list_item_quote_test_() ->
    [?_assertEqual({ok, [{list_item, <<"a">>}, {list_item, <<"b">>}]},
                   gemini_text:parse(<<"* a\r\n*  b\r\n">>)),
     ?_assertEqual({ok, [{quote, <<"a">>}, {quote, <<>>},
                         {para, <<"*">>}]},
                   gemini_text:parse(<<"> a\r\n>\r\n*\r\n">>)),
     % verbatim inside a preformatted block
     ?_assertEqual({ok, [{preformatted, <<>>, [<<"* a">>, <<"> b">>]}]},
                   gemini_text:parse(<<"```\r\n* a\r\n> b\r\n```\r\n">>))].

% feed the chunks to parse/2, then finish/1, and combine the results
stream(Chunks) ->
    stream_with(gemini_text:new_context(), Chunks).

stream_with(Ctx, Chunks) ->
    stream(Chunks, Ctx, []).

stream([], Ctx, Acc) ->
    case gemini_text:finish(Ctx) of
        {ok, Elts}         -> {ok, lists:append(lists:reverse([Elts|Acc]))};
        {error, _} = Error -> Error
    end;
stream([Chunk|Chunks], Ctx, Acc) ->
    case gemini_text:parse(Chunk, Ctx) of
        {ok, Elts, Ctx1}   -> stream(Chunks, Ctx1, [Elts|Acc]);
        {error, _} = Error -> Error
    end.

% split at every byte position: same elements, or same error, as parse/1
split_everywhere_test_() ->
    Docs = [<<"# h\r\n=> u l\nplain\r\n\r\n* i\r\n> q\r\n">>,
            <<"a\r\nb\nc">>,
            <<"caf\xc3\xa9 \xe2\x82\xac\r\n">>,
            <<"p\r\n```alt\r\n# x\r\n=> y z\r\n\r\n```\r\nq\r\n">>,
            <<"```x\r\na\r\nb">>,
            <<"=> u \xe2\x82\xac\r\n=> v">>,
            <<"a\r\n\r\n\r\nb\xff\r\nc\xff\r\n">>,
            <<"```\r\n\xc3\xff\r\n```\r\n">>,
            <<"a\rb\r\n\r">>,
            <<>>],
    [?_assertEqual(gemini_text:parse(Doc),
                   stream([Head, Tail]))
     || Doc <- Docs,
        N <- lists:seq(0, byte_size(Doc)),
        {Head, Tail} <- [{binary:part(Doc, 0, N),
                          binary:part(Doc, N, byte_size(Doc) - N)}]].

% one byte at a time, and a chunk per line
split_bytes_test_() ->
    Doc = <<"# h\r\n=> u \xe2\x82\xac\r\n```a\r\n* x\r\n```\r\nz\r\n\r\n">>,
    [?_assertEqual(gemini_text:parse(Doc),
                   stream([<<B>> || <<B>> <= Doc])),
     ?_assertEqual(gemini_text:parse(Doc),
                   stream(re:split(Doc, "(?<=\n)", [{return, binary}])))].

stream_incremental_test_() ->
    C0 = gemini_text:new_context(),
    {ok, E1, C1} = gemini_text:parse(<<"# h\r">>, C0),
    {ok, E2, C2} = gemini_text:parse(<<"\n```a\r\nb\r\n">>, C1),
    {ok, E3, C3} = gemini_text:parse(<<"```\r\nc">>, C2),
    [?_assertEqual([], E1),
     ?_assertEqual([{h1, <<"h">>}], E2),
     ?_assertEqual([{preformatted, <<"a">>, [<<"b">>]}], E3),
     ?_assertEqual({ok, [{para, <<"c">>}]}, gemini_text:finish(C3))].

stream_replay_test_() ->
    C0 = gemini_text:new_context(),
    {ok, E1, C1} = gemini_text:parse(<<"a\r\n```x\r\nb">>, C0),
    {ok, E2, _C2} = gemini_text:parse(<<"\r\n```\r\nc">>, C1),
    % C1 is an immutable value: using it again replays from that point
    {ok, E2b, _} = gemini_text:parse(<<"\r\n```\r\nc">>, C1),
    [?_assertEqual([{para, <<"a">>}], E1),
     ?_assertEqual([{preformatted, <<"x">>, [<<"b">>]}], E2),
     ?_assertEqual(E2, E2b),
     ?_assertEqual(gemini_text:finish(C1), gemini_text:finish(C1)),
     % finish/1 gives no context, so a stream cannot be continued
     ?_assertMatch({ok, [{preformatted, <<"x">>, [<<"b">>]}]},
                   gemini_text:finish(C1))].

stream_error_test_() ->
    C0 = gemini_text:new_context(),
    {ok, [{para, <<"a">>}], C1} =
        gemini_text:parse(<<"a\r\nb\xc3">>, C0),
    [?_assertEqual({error, {invalid_utf8, 2}},
                   gemini_text:parse(<<"\r\n">>, C1)),
     ?_assertEqual({error, {invalid_utf8, 2}}, gemini_text:finish(C1))].

ctx(Opts) ->
    {ok, Ctx} = gemini_text:new_context(Opts),
    Ctx.

max_line_length_test_() ->
    C3 = ctx([{max_line_length, 3}]),
    [?_assertMatch({ok, [{para, <<"abc">>}], _},
                   gemini_text:parse(<<"abc\n">>, C3)),
     % CR counts, LF does not
     ?_assertMatch({ok, [{para, <<"ab">>}], _},
                   gemini_text:parse(<<"ab\r\n">>, C3)),
     ?_assertEqual({error, {line_too_long, 1}},
                   gemini_text:parse(<<"abc\r\n">>, C3)),
     ?_assertEqual({error, {line_too_long, 3}},
                   gemini_text:parse(<<"a\n\nabcd\n">>, C3)),
     % over-long partial line is caught before its LF arrives
     ?_assertEqual({error, {line_too_long, 2}},
                   gemini_text:parse(<<"a\nabcd">>, C3)),
     % length is checked before UTF-8
     ?_assertEqual({error, {line_too_long, 1}},
                   gemini_text:parse(<<"\xff\xff\xff\xff\n">>, C3)),
     ?_assertEqual({error, {invalid_utf8, 1}},
                   gemini_text:parse(<<"\xff\n">>, C3)),
     % applies inside preformatted blocks too
     ?_assertEqual({error, {line_too_long, 2}},
                   gemini_text:parse(<<"```\nabcd\n">>, C3)),
     % chunked: same error, however the input is split
     ?_assertEqual({error, {line_too_long, 2}},
                   stream_with(C3, [<<"a\nab">>, <<"cd">>, <<"\n">>])),
     ?_assertEqual({ok, [{para, <<"abc">>}]},
                   stream_with(C3, [<<"a">>, <<"bc">>]))].

max_line_length_default_test_() ->
    Max = 1048576,
    Ok = binary:copy(<<"a">>, Max),
    Long = <<Ok/binary, "a">>,
    [?_assertEqual({ok, [{para, Ok}]}, gemini_text:parse(Ok)),
     ?_assertEqual({error, {line_too_long, 1}}, gemini_text:parse(Long)),
     ?_assertEqual({error, {line_too_long, 2}},
                   gemini_text:parse(<<"a\n", Long/binary, "\n">>)),
     ?_assertEqual({ok, [{para, Long}]},
                   begin
                       C = ctx([{max_line_length, infinity}]),
                       stream_with(C, [Long])
                   end)].

options_test_() ->
    [?_assertMatch({ok, _}, gemini_text:new_context([])),
     ?_assertMatch({ok, _}, gemini_text:new_context([{max_line_length, 1}])),
     % the first occurrence of a key wins
     ?_assertEqual({error, {line_too_long, 1}},
                   gemini_text:parse(<<"ab">>,
                       ctx([{max_line_length, 1},
                            {max_line_length, 5}]))),
     ?_assertEqual({error, {bad_option, foo}},
                   gemini_text:new_context([foo])),
     ?_assertEqual({error, {bad_option, {foo, 1}}},
                   gemini_text:new_context([{foo, 1}])),
     ?_assertEqual({error, {bad_option, max_line_length}},
                   gemini_text:new_context([max_line_length])),
     ?_assertEqual({error, {bad_option, {max_line_length, 0}}},
                   gemini_text:new_context([{max_line_length, 0}])),
     ?_assertEqual({error, {bad_option, {max_line_length, a}}},
                   gemini_text:new_context([{max_line_length, a}]))].

control_chars_pass_test_() ->
    [?_assertEqual({ok, [{para, <<"a\x01b\x7f\xc2\x85c\ra">>}]},
                   gemini_text:parse(<<"a\x01b\x7f\xc2\x85c\ra\r\n">>)),
     ?_assertEqual({ok, [{para, <<"a\x01">>}]},
                   stream_with(ctx([{control_chars, pass}]),
                               [<<"a\x01\n">>]))].

control_chars_strip_test_() ->
    C = ctx([{control_chars, strip}]),
    [?_assertEqual({ok, [{para, <<"abc \xe2\x82\xac\t">>}]},
                   stream_with(C, [<<"a\x01b\x7f\xc2\x85c\x1f \xe2\x82\xac"
                                     "\t\r\n">>])),
     % a lone CR inside the line goes; the CR of the CRLF is not a char
     ?_assertEqual({ok, [{para, <<"ab">>}]},
                   stream_with(C, [<<"a\rb\r\n">>])),
     % U+00A0 and U+2028 are not controls here
     ?_assertEqual({ok, [{para, <<"\xc2\xa0\xe2\x80\xa8">>}]},
                   stream_with(C, [<<"\xc2\xa0\xe2\x80\xa8\n">>])),
     % applies inside preformatted blocks, and before classification
     ?_assertEqual({ok, [{preformatted, <<"a">>, [<<"xy">>]}]},
                   stream_with(C, [<<"```a\x01\nx\x02y\n```\n">>])),
     ?_assertEqual({ok, [{h1, <<"t">>}]},
                   stream_with(C, [<<"\x01# t\n">>])),
     % the unterminated last line too
     ?_assertEqual({ok, [{para, <<"ab">>}]},
                   stream_with(C, [<<"a\x01">>, <<"b">>]))].

control_chars_reject_test_() ->
    C = ctx([{control_chars, reject}]),
    [?_assertEqual({ok, [{para, <<"a\tb \xc2\xa0">>}]},
                   stream_with(C, [<<"a\tb \xc2\xa0\r\n">>])),
     ?_assertEqual({error, {invalid_char, 2}},
                   stream_with(C, [<<"a\nb\x01\n">>])),
     ?_assertEqual({error, {invalid_char, 1}},
                   stream_with(C, [<<"a\x7f\n">>])),
     ?_assertEqual({error, {invalid_char, 1}},
                   stream_with(C, [<<"a\xc2\x9f\n">>])),
     ?_assertEqual({error, {invalid_char, 1}},
                   stream_with(C, [<<"a\rb\n">>])),
     ?_assertEqual({error, {invalid_char, 2}},
                   stream_with(C, [<<"```\n">>, <<"\x01">>])),
     % UTF-8 is checked first
     ?_assertEqual({error, {invalid_utf8, 1}},
                   stream_with(C, [<<"\x01\xff\n">>])),
     % length is checked first
     ?_assertEqual({error, {line_too_long, 1}},
                   stream_with(ctx([{control_chars, reject},
                                    {max_line_length, 2}]),
                               [<<"\x01\x01\x01\n">>]))].

control_chars_option_test_() ->
    [?_assertEqual({error, {bad_option, {control_chars, drop}}},
                   gemini_text:new_context([{control_chars, drop}])),
     ?_assertEqual({error, {bad_option, control_chars}},
                   gemini_text:new_context([control_chars])),
     % first occurrence wins
     ?_assertEqual({ok, [{para, <<"ab">>}]},
                   stream_with(ctx([{control_chars, strip},
                                    {control_chars, reject}]),
                               [<<"a\x01b\n">>]))].

% chunking does not change results with options either
split_everywhere_options_test_() ->
    Doc = <<"a\x01\r\n```\x02x\r\nb\r\n```\r\n\xe2\x82\xac\x85\n">>,
    [?_assertEqual(stream_with(C, [Doc]),
                   stream_with(C, [binary:part(Doc, 0, N),
                                   binary:part(Doc, N,
                                               byte_size(Doc) - N)]))
     || C <- [ctx([{control_chars, strip}]), ctx([{control_chars, reject}]),
              ctx([{max_line_length, 4}])],
        N <- lists:seq(0, byte_size(Doc))].

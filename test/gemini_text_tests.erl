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
    Err = {error, invalid_utf8},
    [?_assertEqual(Err, gemini_text:parse(<<"# h\xff\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"p\xff\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"=> u\xff l\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"=> u \xff\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"# \xc3\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"```a\xff\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"```\r\n\xff\r\n```\r\n">>)),
     ?_assertEqual(Err, gemini_text:parse(<<"a\r\nb\xff">>))].

invalid_utf8_api_test_() ->
    Err = {error, invalid_utf8},
    [?_assertEqual(Err, gemini_text:links(<<"=> a\xff b\r\n">>)),
     ?_assertEqual(Err, gemini_text:urls(<<"=> a b\xff\r\n">>))].

valid_utf8_test_() ->
    [?_assertEqual({ok, [{para, <<"caf\xc3\xa9">>}]},
                   gemini_text:parse(<<"caf\xc3\xa9\r\n">>)),
     ?_assertEqual({ok, [{link, <<"u">>, <<"\xe2\x82\xac">>}]},
                   gemini_text:parse(<<"=> u \xe2\x82\xac\r\n">>))].

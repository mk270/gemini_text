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

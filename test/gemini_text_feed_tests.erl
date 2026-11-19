-module(gemini_text_feed_tests).
-include_lib("eunit/include/eunit.hrl").

feed_test_() ->
    Doc = <<"# J's gemlog\r\n"
            "Welcome\r\n"
            "## Posts\r\n"
            "=> a.gmi\t2020-11-20 - Early Bokashi\r\n"
            "=> b.gmi 2020-11-13 Finite groups\r\n"
            "=> gemini://x/ Other gemlog\r\n"
            "=> c.gmi 2020-13-45 Bad date\r\n"
            "=> d.gmi 2020-11-06\r\n"
            "=> e.gmi 2020-11-05 -no space\r\n">>,
    E = fun(U, D, T) -> {gemsub_entry, U, D, T} end,
    [?_assertEqual({ok, <<"J's gemlog">>,
                    [E(<<"a.gmi">>, {2020,11,20}, <<"Early Bokashi">>),
                     E(<<"b.gmi">>, {2020,11,13}, <<"Finite groups">>),
                     E(<<"d.gmi">>, {2020,11,6}, <<>>),
                     E(<<"e.gmi">>, {2020,11,5}, <<"-no space">>)]},
                   gemini_text_feed:feed(Doc)),
     ?_assertEqual({ok, <<"t">>, []},
                   gemini_text_feed:feed(<<"# t\r\n">>)),
     ?_assertEqual({error, no_title},
                   gemini_text_feed:feed(<<"## t\r\n"
                                           "=> a 2020-01-01 x\r\n">>)),
     ?_assertEqual({error, no_title}, gemini_text_feed:feed(<<>>)),
     ?_assertEqual({error, {invalid_utf8, 2}},
                   gemini_text_feed:feed(<<"# t\r\n", 255, "\r\n">>))].

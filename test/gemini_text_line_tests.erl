-module(gemini_text_line_tests).
-include_lib("eunit/include/eunit.hrl").

tag_blank_para_test_() ->
    [?_assertEqual(blank, gemini_text_line:tag(<<>>)),
     ?_assertEqual({para, <<"text">>}, gemini_text_line:tag(<<"text">>)),
     % leading whitespace is not stripped, and defeats the prefixes
     ?_assertEqual({para, <<" # a">>}, gemini_text_line:tag(<<" # a">>)),
     ?_assertEqual({para, <<" => a b">>},
                   gemini_text_line:tag(<<" => a b">>)),
     ?_assertEqual({para, <<"= > a">>}, gemini_text_line:tag(<<"= > a">>))].

tag_heading_test_() ->
    [?_assertEqual({h1, <<"a b">>}, gemini_text_line:tag(<<"# a b">>)),
     ?_assertEqual({h2, <<"a b">>}, gemini_text_line:tag(<<"## a b">>)),
     ?_assertEqual({h3, <<"a b">>}, gemini_text_line:tag(<<"### a b">>)),
     % the space after the hashes is optional, and extra space is trimmed
     ?_assertEqual({h1, <<"a">>}, gemini_text_line:tag(<<"#a">>)),
     ?_assertEqual({h1, <<"a">>}, gemini_text_line:tag(<<"#   a  ">>)),
     % no h4: the fourth hash becomes part of the caption
     ?_assertEqual({h3, <<"# a">>}, gemini_text_line:tag(<<"#### a">>))].

tag_link_test_() ->
    [?_assertEqual({link, <<"u">>, <<"l m">>},
                   gemini_text_line:tag(<<"=> u l m">>)),
     ?_assertEqual({link, <<"u">>, <<"l">>},
                   gemini_text_line:tag(<<"=>\tu\tl">>)),
     % no space after the arrow
     ?_assertEqual({link, <<"u">>, <<"l">>},
                   gemini_text_line:tag(<<"=>u l">>)),
     ?_assertEqual({link, <<"u">>, <<>>}, gemini_text_line:tag(<<"=>u">>)),
     ?_assertEqual({link, <<>>, <<>>}, gemini_text_line:tag(<<"=>">>))].

pref_marker_test_() ->
    [?_assert(gemini_text_line:pref_marker(<<"```">>)),
     ?_assert(gemini_text_line:pref_marker(<<"```alt">>)),
     ?_assert(gemini_text_line:pref_marker(<<"```` x">>)),
     ?_assertNot(gemini_text_line:pref_marker(<<"``">>)),
     ?_assertNot(gemini_text_line:pref_marker(<<" ```">>)),
     ?_assertNot(gemini_text_line:pref_marker(<<"a```">>)),
     ?_assertNot(gemini_text_line:pref_marker(<<>>))].

alt_text_test_() ->
    [?_assertEqual(<<>>, gemini_text_line:alt_text(<<"```">>)),
     ?_assertEqual(<<"a b">>, gemini_text_line:alt_text(<<"```a b">>)),
     ?_assertEqual(<<"a b">>, gemini_text_line:alt_text(<<"``` a b  ">>)),
     ?_assertEqual(<<"x">>, gemini_text_line:alt_text(<<"```\tx">>))].

prefix_test_() ->
    [?_assert(gemini_text_line:prefix(<<"ab">>, <<"abc">>)),
     ?_assert(gemini_text_line:prefix(<<"ab">>, <<"ab">>)),
     ?_assertNot(gemini_text_line:prefix(<<"ab">>, <<"a">>)),
     ?_assertNot(gemini_text_line:prefix(<<"ab">>, <<"ba">>)),
     % the empty prefix matches everything, including the empty line
     ?_assert(gemini_text_line:prefix(<<>>, <<"x">>)),
     ?_assert(gemini_text_line:prefix(<<>>, <<>>))].

split_once_test_() ->
    [?_assertEqual({<<"a">>, <<"b">>},
                   gemini_text_line:split_once(<<"a b">>)),
     ?_assertEqual({<<"a">>, <<"b">>},
                   gemini_text_line:split_once(<<"a\tb">>)),
     % only the first separator splits; the rest is trimmed at the ends
     ?_assertEqual({<<"a">>, <<"b  c">>},
                   gemini_text_line:split_once(<<"a   b  c  ">>)),
     ?_assertEqual({<<"a">>, <<>>}, gemini_text_line:split_once(<<"a">>)),
     ?_assertEqual({<<"a">>, <<>>},
                   gemini_text_line:split_once(<<"a   ">>)),
     ?_assertEqual({<<>>, <<>>}, gemini_text_line:split_once(<<>>)),
     % a leading separator gives an empty first part
     ?_assertEqual({<<>>, <<"a">>}, gemini_text_line:split_once(<<" a">>))].

heading_level_test_() ->
    [?_assertEqual(1, gemini_text_line:heading_level(h1)),
     ?_assertEqual(2, gemini_text_line:heading_level(h2)),
     ?_assertEqual(3, gemini_text_line:heading_level(h3))].

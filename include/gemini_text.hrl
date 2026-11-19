%%% Public records for gemini_text.

%% One entry of a subscribable page: see gemini_text:feed/1.
%% `date' is the date at the start of the link label, `title' is the
%% rest of the label.
-record(gemsub_entry, {url   :: binary(),
                       date  :: calendar:date(),
                       title :: binary()}).

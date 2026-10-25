local UnreadSummary = require("WhisperMessenger.UI.Shared.UnreadSummary")
local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  -- test_whispers_only_text_is_the_plain_unread_count
  do
    assert(UnreadSummary.Format(2, 0) == "2 unread", "got " .. tostring(UnreadSummary.Format(2, 0)))
    assert(UnreadSummary.Format(2) == "2 unread", "panel count is optional")
  end

  -- test_whispers_and_panel_items_are_split
  do
    local text = UnreadSummary.Format(2, 1)
    assert(text == "2 unread, 1 in addon pages", "got " .. tostring(text))
  end

  -- test_panel_items_alone_leave_out_the_unread_part
  do
    local text = UnreadSummary.Format(0, 1)
    assert(text == "1 in addon pages", "got " .. tostring(text))
  end

  -- test_nothing_to_report_is_an_empty_string
  do
    assert(UnreadSummary.Format(0, 0) == "", "nothing waiting")
    assert(UnreadSummary.Format(nil, nil) == "", "nil counts are zero")
  end

  -- test_split_derives_panel_items_from_total_and_whisper_count
  do
    local unread, panel = UnreadSummary.Split(3, 1)
    assert(unread == 1 and panel == 2, "3 total, 1 whisper -> 1 + 2; got " .. tostring(unread) .. "," .. tostring(panel))
    unread, panel = UnreadSummary.Split(2)
    assert(unread == 2 and panel == 0, "no whisper count -> all whispers")
    _, panel = UnreadSummary.Split(0, 2)
    assert(panel == 0, "a whisper count above the total never gives negative panel items")
  end

  -- test_text_is_translated
  do
    Localization.Configure({ language = "deDE" })
    local text = UnreadSummary.Format(2, 1)
    Localization.Configure({ language = "enUS" })
    assert(text == "2 ungelesen, 1 auf Addon-Seiten", "deDE text, got " .. tostring(text))
  end
end

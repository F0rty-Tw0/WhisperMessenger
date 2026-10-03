local Localization = require("WhisperMessenger.Locale.Localization")
local BlockedCount = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.BlockedCount")

return function()
  Localization.Configure({ language = "enUS" })

  -- test_counts_up_to_999_are_exact
  assert(BlockedCount.Format(0) == "0", "zero shown as 0")
  assert(BlockedCount.Format(999) == "999", "999 shown exactly, got " .. BlockedCount.Format(999))

  -- test_counts_above_999_are_capped
  assert(BlockedCount.Format(1000) == "999+", "1000 shown as 999+, got " .. BlockedCount.Format(1000))

  -- test_missing_count_is_zero
  assert(BlockedCount.Format(nil) == "0", "a missing count is 0")

  -- test_text_says_this_session
  assert(BlockedCount.Text(3) == "Blocked 3 this session", "got " .. BlockedCount.Text(3))
  assert(BlockedCount.Text(5000) == "Blocked 999+ this session", "capped count in the text")
end

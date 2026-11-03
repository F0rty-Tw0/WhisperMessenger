local FakeUI = require("tests.helpers.fake_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local IconTooltip = require("WhisperMessenger.UI.ToggleIcon.IconTooltip")

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local savedTooltip = _G.GameTooltip
  local title
  local hidden = false
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function(_self, value)
      title = value
    end,
    AddLine = function() end,
    Show = function() end,
    Hide = function()
      hidden = true
    end,
  }

  local frame = factory.CreateFrame("Button", nil, parent)
  local badge = factory.CreateFrame("Frame", nil, frame)
  local locked = false
  local tooltip = IconTooltip.Create(frame, {
    badge = badge,
    isLocked = function()
      return locked
    end,
    options = {},
  })

  -- test_title_has_summary_only_while_badge_shown

  badge:Hide()
  tooltip.show("3 unread", false)
  assert(title == "Whisper Messenger", "test_title_has_summary_only_while_badge_shown: hidden badge drops the summary, got " .. tostring(title))

  badge:Show()
  tooltip.show("3 unread", false)
  assert(title == "Whisper Messenger — 3 unread", "test_title_has_summary_only_while_badge_shown: got " .. tostring(title))

  -- test_title_lists_pause_and_lock_notes

  locked = true
  tooltip.show("3 unread", true)
  assert(title == "Whisper Messenger — 3 unread\nPaused in M+\nLocked", "test_title_lists_pause_and_lock_notes: got " .. tostring(title))

  -- test_hide_hides_game_tooltip

  tooltip.hide()
  assert(hidden == true, "test_hide_hides_game_tooltip: hide should hide the game tooltip")

  _G.GameTooltip = savedTooltip
end

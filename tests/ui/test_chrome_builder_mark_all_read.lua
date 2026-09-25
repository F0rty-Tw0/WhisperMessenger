-- Mark-all-read button sits last in the left title-bar group (after What's
-- New) in both chrome paths, and only shows while something is unread.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local MarkAllReadButton = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.MarkAllReadButton")
local Localization = require("WhisperMessenger.Locale.Localization")

local function withTooltip(fn)
  local saved = _G.GameTooltip
  local state = {}
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, text)
      state.text = text
    end,
    Show = function()
      state.shown = true
    end,
    Hide = function()
      state.hidden = true
    end,
  }
  local ok, err = pcall(fn, state)
  _G.GameTooltip = saved
  assert(ok, err)
end

return function()
  Localization.Configure({ language = "enUS" })

  for _, case in ipairs({
    { name = "modern chrome", useNativeChrome = false },
    { name = "native chrome", useNativeChrome = true },
  }) do
    local clicks = 0
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {
      useNativeChrome = case.useNativeChrome,
      onMarkAllRead = function()
        clicks = clicks + 1
      end,
    })
    local button = chrome.markAllReadButton
    local glyph = button and button._wmGlyph

    -- test_mark_all_read_button_sits_after_whats_new
    assert(button ~= nil, case.name .. ": expected a mark all read button")
    local point, relativeTo, relativePoint = button:GetPoint()
    assert(point == "LEFT" and relativeTo == chrome.patchNotesButton and relativePoint == "RIGHT", case.name .. ": anchored right of What's New")
    assert(glyph.texturePath == Theme.TEXTURES.title_mark_read_icon, case.name .. ": double-check glyph")

    -- test_mark_all_read_button_starts_hidden
    assert(button:IsShown() == false, case.name .. ": hidden until unread arrives")

    -- test_unread_shows_the_button
    chrome.setMarkAllReadShown(true)
    assert(button:IsShown() == true, case.name .. ": shown with unread")

    -- test_hover_shows_tooltip
    withTooltip(function(tooltip)
      button:GetScript("OnEnter")(button)
      assert(tooltip.text == "Mark all as read", case.name .. ": tooltip names the action")
      assert(tooltip.shown == true, case.name .. ": tooltip shown")
    end)

    -- test_click_marks_all_read
    button:GetScript("OnClick")(button)
    assert(clicks == 1, case.name .. ": click runs onMarkAllRead")

    -- test_nothing_unread_hides_again
    chrome.setMarkAllReadShown(false)
    assert(button:IsShown() == false, case.name .. ": hidden again when nothing is unread")
  end

  -- test_has_unread_checks_every_contact
  assert(MarkAllReadButton.HasUnread({}) == false, "empty list has nothing unread")
  assert(MarkAllReadButton.HasUnread({ { unreadCount = 0 }, {} }) == false, "zero or missing counts are read")
  assert(MarkAllReadButton.HasUnread({ { unreadCount = 0 }, { unreadCount = 2 } }) == true, "any unread contact counts")
end

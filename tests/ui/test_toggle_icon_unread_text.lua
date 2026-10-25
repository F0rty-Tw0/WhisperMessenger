local AnimatedFactory = require("tests.helpers.animated_factory")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

-- Hover text after setUnreadCount(total, unread).
local function hoverText(total, unread)
  local factory = AnimatedFactory.newAnimatedFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:Show()
  local icon = ToggleIcon.Create(factory, {
    parent = parent,
    getShowUnreadBadge = function()
      return true
    end,
  })
  local text = nil
  local original = _G.GameTooltip
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function(_self, value)
      text = value
    end,
    AddLine = function() end,
    AddDoubleLine = function() end,
    Show = function() end,
    Hide = function() end,
  }
  icon.setUnreadCount(total, unread)
  icon.frame:GetScript("OnEnter")(icon.frame)
  _G.GameTooltip = original
  return assert(text, "tooltip text was set")
end

return function()
  -- test_tooltip_without_panel_items_is_todays_text
  do
    local text = hoverText(2, 2)
    assert(string.find(text, "Whisper Messenger — 2 unread", 1, true), "got " .. tostring(text))
    assert(not string.find(text, "addon pages", 1, true), "no panel part")
  end

  -- test_tooltip_old_callers_without_whisper_count_are_unchanged
  do
    local text = hoverText(2)
    assert(string.find(text, "Whisper Messenger — 2 unread", 1, true), "got " .. tostring(text))
  end

  -- test_tooltip_splits_whispers_and_panel_items
  do
    local text = hoverText(3, 2)
    assert(string.find(text, "Whisper Messenger — 2 unread, 1 in addon pages", 1, true), "got " .. tostring(text))
  end

  -- test_tooltip_panel_items_alone
  do
    local text = hoverText(1, 0)
    assert(string.find(text, "Whisper Messenger — 1 in addon pages", 1, true), "got " .. tostring(text))
    assert(not string.find(text, "unread", 1, true), "no unread part")
  end
end

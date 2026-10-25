local AnimatedFactory = require("tests.helpers.animated_factory")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")

-- Hover lines after setUnreadCount(total, unread).
local function hoverLines(total, unread)
  local factory = AnimatedFactory.newAnimatedFactory()
  local parent = factory.CreateFrame("Frame", "Minimap", nil)
  parent:SetSize(140, 140)
  local icon = MinimapIcon.Create(factory, {
    parent = parent,
    getShowUnreadBadge = function()
      return true
    end,
  })
  local lines = {}
  local original = _G.GameTooltip
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function(_self, value)
      lines[#lines + 1] = value
    end,
    AddDoubleLine = function() end,
    Show = function() end,
    Hide = function() end,
  }
  icon.setUnreadCount(total, unread)
  icon.frame:GetScript("OnEnter")(icon.frame)
  _G.GameTooltip = original
  return lines
end

return function()
  -- test_tooltip_without_panel_items_is_todays_text
  do
    assert(hoverLines(2, 2)[1] == "2 unread", "got " .. tostring(hoverLines(2, 2)[1]))
    assert(hoverLines(2)[1] == "2 unread", "old callers unchanged")
  end

  -- test_tooltip_splits_whispers_and_panel_items
  do
    assert(hoverLines(3, 2)[1] == "2 unread, 1 in addon pages", "got " .. tostring(hoverLines(3, 2)[1]))
  end

  -- test_tooltip_panel_items_alone
  do
    assert(hoverLines(1, 0)[1] == "1 in addon pages", "got " .. tostring(hoverLines(1, 0)[1]))
  end
end

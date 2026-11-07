local FakeUI = require("tests.helpers.fake_ui")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

local function createIcon(transparency, extraOptions)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local options = {
    parent = parent,
    getWidgetTransparency = function()
      return transparency
    end,
  }
  for key, value in pairs(extraOptions or {}) do
    options[key] = value
  end

  return ToggleIcon.Create(factory, options)
end

return function()
  -- test_fully_transparent_icon_turns_opaque_while_unread

  do
    local icon = createIcon(1)
    assert(icon.frame.alpha == 0, "a fully transparent icon should start invisible")

    icon.setUnreadCount(2)
    assert(icon.frame.alpha == 1, "unread whispers should make a fully transparent icon opaque")
  end

  -- test_icon_returns_to_chosen_transparency_when_unread_clears

  do
    local icon = createIcon(1)
    icon.setUnreadCount(2)

    icon.setUnreadCount(0)
    assert(icon.frame.alpha == 0, "clearing unread should restore the chosen transparency")
  end

  -- test_partially_transparent_icon_turns_opaque_while_unread

  do
    local icon = createIcon(0.6)
    assert(icon.frame.alpha == 0.4, "60% transparency should start at 40% alpha")

    icon.setUnreadCount(1)
    assert(icon.frame.alpha == 1, "unread whispers should make a partly transparent icon opaque")
  end

  -- test_hidden_unread_badge_still_makes_icon_opaque

  do
    local icon = createIcon(1, {
      getShowUnreadBadge = function()
        return false
      end,
    })

    icon.setUnreadCount(3)
    assert(icon.frame.alpha == 1, "hiding the badge should not hide the icon while whispers are unread")
  end

  -- test_leaving_hover_keeps_icon_opaque_while_unread

  do
    local icon = createIcon(1)
    icon.setUnreadCount(2)

    icon.frame:GetScript("OnEnter")(icon.frame)
    icon.frame:GetScript("OnLeave")(icon.frame)
    assert(icon.frame.alpha == 1, "leaving hover should keep the icon opaque while whispers are unread")
  end

  -- test_panel_badge_unread_alone_makes_icon_opaque

  do
    local icon = createIcon(1)
    icon.setUnreadCount(2, 0)
    assert(icon.frame.alpha == 1, "unread panel badges with no whispers should still make the icon opaque")
  end

  -- test_icon_created_with_unread_starts_opaque

  do
    local icon = createIcon(1, { unreadCount = 4 })
    assert(icon.frame.alpha == 1, "an icon created with unread whispers should start opaque")
  end
end

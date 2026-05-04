local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon.ToggleIcon")
local FakeUI = require("tests.helpers.fake_ui")
local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(800, 600)

  local icon = ToggleIcon.Create(factory, parent, {})

  -- test_russian_toggle_icon_tooltip
  do
    Localization.Configure({ language = "ruRU" })
    local tooltipText = nil
    local originalTooltip = _G.GameTooltip
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_self, text)
        tooltipText = text
      end,
      Show = function() end,
      Hide = function() end,
    }

    local onEnter = icon.frame:GetScript("OnEnter")
    assert(onEnter ~= nil, "icon should have OnEnter script")
    onEnter(icon.frame)
    assert(string.find(tooltipText, "WhisperMessenger", 1, true), "tooltip should still start with WhisperMessenger")

    icon.setUnreadCount(3)
    onEnter(icon.frame)
    assert(string.find(tooltipText, "3 непрочитанных", 1, true), "tooltip should have localized unread count, got: " .. tostring(tooltipText))

    icon.setCompetitiveContent(true)
    onEnter(icon.frame)
    assert(string.find(tooltipText, "Пауза в M+", 1, true), "tooltip should have localized competitive indicator, got: " .. tostring(tooltipText))

    _G.GameTooltip = originalTooltip
    Localization.Configure({ language = "enUS" })
  end
end

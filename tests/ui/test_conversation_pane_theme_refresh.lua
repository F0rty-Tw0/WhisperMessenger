local FakeUI = require("tests.helpers.fake_ui")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local ThemeRefresh = require("WhisperMessenger.UI.ConversationPane.ThemeRefresh")
local Theme = require("WhisperMessenger.UI.Theme")

local function newView()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(640, 420)
  return ConversationPane.Create(factory, parent, { displayName = "Arthas", channel = "WOW" }, { messages = {} })
end

return function()
  -- test_apply_repaints_the_active_status_banner_with_the_system_color
  do
    local view = newView()
    view.activeStatusBanner:SetTextColor(0.1, 0.2, 0.3, 1)

    ThemeRefresh.Apply(view)

    local tc = view.activeStatusBanner.textColor
    local expected = Theme.COLORS.text_system
    assert(tc[1] == expected[1] and tc[2] == expected[2] and tc[3] == expected[3], "banner repainted, got " .. tostring(tc[1]))
  end

  -- test_apply_refreshes_each_banner_once
  do
    local view = newView()
    local calls = { request = 0, reply = 0, info = 0 }
    view.requestBanner.refreshTheme = function()
      calls.request = calls.request + 1
    end
    view.replyBanner.refreshTheme = function()
      calls.reply = calls.reply + 1
    end
    view.infoStrip.refreshTheme = function()
      calls.info = calls.info + 1
    end

    ThemeRefresh.Apply(view)

    assert(calls.request == 1 and calls.reply == 1 and calls.info == 1, "each banner refreshed once")
  end
end

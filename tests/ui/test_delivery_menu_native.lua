local FakeUI = require("tests.helpers.fake_ui")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Localization = require("WhisperMessenger.Locale.Localization")
local DeliveryMenu = require("WhisperMessenger.UI.ChatBubble.DeliveryMenu")

-- Under the Native WoW HUD the delivery menu is a tooltip-border frame, so its
-- rows sit inside the border instead of on it.

local PAD = 4

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local savedUIParent, savedSpecialFrames = _G.UIParent, _G.UISpecialFrames
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UISpecialFrames = {}
  local anchor = factory.CreateFrame("Button", nil, _G.UIParent)
  local message = { direction = "out", text = "hi", delivery = "failed" }

  Hud.Configure("classic")
  DeliveryMenu.Open(factory, anchor, message, { "retry", "discard" }, function() end)
  Hud.Configure("off")
  local menu = DeliveryMenu.GetFrame()
  local inset = Theme.LAYOUT.NATIVE_BORDER_INSET

  -- test_hud_rows_clear_the_tooltip_border
  do
    local first = menu._buttons[1].point
    assert(first[4] == PAD + inset and first[5] == -(PAD + inset), "first row sits inside the border, got " .. first[4] .. "," .. first[5])
    local second = menu._buttons[2].point
    assert(second[5] == -(PAD + inset) - menu._buttons[1]:GetHeight(), "second row stacks under the first")
  end

  -- test_hud_menu_grows_by_the_border
  do
    local rowWidth = menu._buttons[1]:GetWidth()
    assert(menu:GetWidth() == rowWidth + (PAD + inset) * 2, "menu widens by the border on both sides")
    assert(menu:GetHeight() == menu._buttons[1]:GetHeight() * 2 + (PAD + inset) * 2, "menu grows by the border top and bottom")
  end

  DeliveryMenu.Close()
  _G.UIParent, _G.UISpecialFrames = savedUIParent, savedSpecialFrames
end

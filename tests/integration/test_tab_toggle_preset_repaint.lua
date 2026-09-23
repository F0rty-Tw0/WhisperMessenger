local FakeUI = require("tests.helpers.fake_ui")
local TabParts = require("tests.helpers.tab_toggle_parts")
local Theme = require("WhisperMessenger.UI.Theme")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

local function sameColor(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- A live preset switch (window.refreshTheme) must repaint the Whispers /
-- Groups tab bar, which otherwise only repaints on mode/unread/hover changes.
return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  local window = MessengerWindow.Create(factory, { title = "WhisperMessenger", contacts = {} })

  local tabToggle = window.tabToggle
  assert(tabToggle ~= nil, "window should expose its tab toggle")
  assert(sameColor(TabParts.whispers(tabToggle).underline.color, Theme.COLORS.accent_bar), "wow_default: underline uses the accent")

  -- test_refresh_theme_repaints_tab_bar_for_new_preset
  Theme.SetPreset("wow_native")
  window.refreshTheme()
  assert(TabParts.footerTint(tabToggle).shown == true, "footer tint stays shown on every preset")
  assert(sameColor(TabParts.whispers(tabToggle).underline.color, Theme.COLORS.accent_bar), "wow_native: underline repainted with the gold accent")

  _G.UIParent = savedUIParent
  Theme.SetPreset(previousPreset)
  print("PASS: test_tab_toggle_preset_repaint")
end

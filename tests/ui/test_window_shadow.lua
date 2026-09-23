local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ModernChrome = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ModernChrome")

local SHADOW_PATH = "Interface\\AddOns\\WhisperMessenger\\Media\\shadow.png"

local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "ShadowTestWindow", nil)
  frame:SetSize(900, 580)
  local chrome = ModernChrome.Build(factory, frame, {}, Theme)
  chrome.applyChromePaint(Theme)
  return chrome, frame
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_modern_window_has_soft_outer_shadow
  do
    Theme.SetPreset("wow_default")
    local chrome, frame = build()
    local shadow = chrome.shadow
    assert(shadow ~= nil and #shadow.parts == 8, "modern: 4 corners + 4 edges")
    for _, part in ipairs(shadow.parts) do
      assert(part.shown == true, "modern: shadow part shown")
      assert(part.texturePath == SHADOW_PATH, "modern: uses the bundled shadow texture")
      assert(part.vertexColor[4] == 0.5, "modern: shadow at 0.5 alpha")
    end
    local topLeft = shadow.parts[1]
    local pt = topLeft.point
    assert(pt[1] == "BOTTOMRIGHT" and pt[2] == frame and pt[3] == "TOPLEFT", "corner sits fully outside the window")
    assert(topLeft.width == 14 and topLeft.height == 14, "shadow extends 14px outside")
  end

  -- test_azeroth_has_the_shadow_too
  do
    Theme.SetPreset("wow_native")
    local chrome = build()
    for _, part in ipairs(chrome.shadow.parts) do
      assert(part.shown == true, "azeroth: drop shadow shown like every preset")
    end
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_window_shadow")
end

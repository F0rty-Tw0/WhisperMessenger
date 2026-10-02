local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local ResizeGrip = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ResizeGrip")

local function build()
  Hud.Configure("classic")
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  frame:SetSize(900, 580)
  local grip = ResizeGrip.Create(factory, frame)
  grip.applyTheme(Theme)
  Hud.Configure("off")
  return grip, frame
end

return function()
  -- test_hud_grip_uses_the_chat_frame_size_grabber
  do
    local button = build().grip
    assert(button.normalTexture == "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up", "HUD: normal size grabber art")
    assert(button.pushedTexture == "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down", "HUD: pushed size grabber art")
    assert(button.highlightTexture == "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight", "HUD: highlight size grabber art")
  end

  -- test_hud_grip_draws_no_custom_dots
  do
    local dots = FindUI.ofType(build().grip, "Texture")
    assert(#dots == 0, "HUD: no dotted diagonals, got " .. #dots)
  end

  -- test_hud_grip_sits_inside_the_frame_border
  do
    local grip, frame = build()
    local button = grip.grip
    local pt = button.point
    local L = Theme.LAYOUT
    assert(pt[1] == "BOTTOMRIGHT" and pt[2] == frame and pt[3] == "BOTTOMRIGHT", "HUD: grip anchored to the bottom-right corner")
    assert(
      pt[4] == -L.HUD_INSET_RIGHT and pt[5] == L.HUD_INSET_BOTTOM,
      "HUD: grip inside the border, got " .. tostring(pt[4]) .. "," .. tostring(pt[5])
    )
    assert(button.width == 16 and button.height == 16, "HUD: hit area stays 16x16")
  end

  print("PASS: test_resize_grip_hud")
end

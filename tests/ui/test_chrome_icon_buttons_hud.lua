local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")

local ICON_GLOW = "Interface\\Buttons\\UI-Common-MouseHilight"
local HOVER_CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function build()
  Hud.Configure("classic")
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = true })
  Hud.Configure("off")
  return chrome
end

local function textureWithPath(button, path)
  return FindUI.find(button, function(node)
    return node.texturePath == path
  end)
end

local function hover(button, over)
  button.mouseOver = over
  button:GetScript(over and "OnEnter" or "OnLeave")(button)
end

local function sameRgb(actual, expected)
  return actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3]
end

local function titleButtons(chrome)
  return {
    newWhisper = chrome.newConversationButton,
    markAllRead = chrome.markAllReadButton,
    whatsNew = chrome.patchNotesButton,
    options = chrome.optionsButton,
    back = chrome.backButton,
  }
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  -- test_hud_title_bar_buttons_hover_with_the_blizzard_glow
  do
    local chrome = build()
    for name, button in pairs(titleButtons(chrome)) do
      local glow = assert(textureWithPath(button, ICON_GLOW), name .. ": has the mouse-over glow")
      assert(glow.blendMode == "ADD", name .. ": glow is additive")
      assert(glow.shown ~= true, name .. ": no glow at rest")
      hover(button, true)
      assert(glow.shown == true, name .. ": glow on hover")
      hover(button, false)
      assert(glow.shown == false, name .. ": glow hides on leave")
    end
  end

  -- test_hud_title_bar_buttons_have_no_white_circle
  do
    local chrome = build()
    for name, button in pairs(titleButtons(chrome)) do
      assert(textureWithPath(button, HOVER_CIRCLE) == nil, name .. ": no white hover circle")
    end
  end

  -- test_hud_title_bar_glyphs_keep_the_preset_tint
  do
    local chrome = build()
    for name, button in pairs(titleButtons(chrome)) do
      assert(sameRgb(button._wmGlyph.vertexColor, Theme.COLORS.text_secondary), name .. ": text_secondary glyph at rest")
      hover(button, true)
      assert(sameRgb(button._wmGlyph.vertexColor, Theme.COLORS.text_primary), name .. ": text_primary glyph on hover")
      hover(button, false)
    end
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_chrome_icon_buttons_hud")
end

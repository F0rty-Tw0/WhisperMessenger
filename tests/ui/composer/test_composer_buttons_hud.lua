local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Composer = require("WhisperMessenger.UI.Composer")

local ICON_GLOW = "Interface\\Buttons\\UI-Common-MouseHilight"
local HOVER_CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SEND_ICON = "Interface\\AddOns\\WhisperMessenger\\Media\\send.png"
local CONTACT = { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }

local function create()
  Hud.Configure("classic")
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local composer = Composer.Create(factory, parent, CONTACT, function() end, nil, nil, nil, { nativeChrome = true })
  Hud.Configure("off")
  return composer
end

local function textureWithPath(frame, path)
  return FindUI.find(frame, function(node)
    return node.texturePath == path
  end)
end

local function sameRgb(actual, expected)
  return actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3]
end

local function withTooltip(fn)
  local original = _G.GameTooltip
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function() end,
    Show = function() end,
    Hide = function() end,
  }
  fn()
  _G.GameTooltip = original
end

local function iconButtons(composer)
  return { send = composer.sendButton, emoji = composer.emojiButton, quickReply = composer.quickReplyButton }
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  -- test_hud_composer_buttons_hover_with_the_blizzard_glow
  withTooltip(function()
    local composer = create()
    for name, button in pairs(iconButtons(composer)) do
      local glow = assert(textureWithPath(button, ICON_GLOW), name .. ": has the mouse-over glow")
      assert(glow.blendMode == "ADD", name .. ": glow is additive")
      assert(glow.shown ~= true, name .. ": no glow at rest")
      button.scripts.OnEnter(button)
      assert(glow.shown == true, name .. ": glow on hover")
      button.scripts.OnLeave(button)
      assert(glow.shown == false, name .. ": glow hides on leave")
    end
  end)

  -- test_hud_composer_buttons_have_no_circle_or_rounded_bg
  do
    local composer = create()
    assert(textureWithPath(composer.sendButton, HOVER_CIRCLE) == nil, "send: no white hover circle")
    assert(composer.emojiButton.bg == nil, "emoji: no rounded hover background")
    assert(composer.quickReplyButton.bg == nil, "quick reply: no rounded hover background")
  end

  -- test_hud_send_glyph_keeps_the_accent_tint
  do
    local composer = create()
    local icon = assert(textureWithPath(composer.sendButton, SEND_ICON), "send glyph present")
    assert(sameRgb(icon.vertexColor, Theme.COLORS.accent), "send glyph is the preset accent")
  end

  -- test_hud_disabled_composer_buttons_show_no_glow
  withTooltip(function()
    local composer = create()
    composer.setEnabled(false)
    for name, button in pairs(iconButtons(composer)) do
      button.scripts.OnEnter(button)
      local glow = assert(textureWithPath(button, ICON_GLOW), name .. ": has the mouse-over glow")
      assert(glow.shown ~= true, name .. ": disabled button shows no glow")
      button.scripts.OnLeave(button)
    end
  end)

  Theme.SetPreset(previousPreset)
  print("PASS: test_composer_buttons_hud")
end

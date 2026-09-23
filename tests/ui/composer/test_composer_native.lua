local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Composer = require("WhisperMessenger.UI.Composer.Composer")
local ComposerSurface = require("WhisperMessenger.UI.Composer.ComposerSurface")

local CONTACT = { conversationKey = "me::WOW::arthas", displayName = "Arthas", channel = "WOW" }

local function create(nativeChrome, onSend)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 60)
  return Composer.Create(factory, parent, CONTACT, onSend or function() end, nil, nil, nil, { nativeChrome = nativeChrome })
end

local function borderTextures(input)
  local out = {}
  for _, child in ipairs(input.children or {}) do
    if child.frameType == "Texture" and child.texturePath == ComposerSurface.NATIVE_BORDER_TEXTURE then
      out[#out + 1] = child
    end
  end
  return out
end

local function anyEdgeShown(border)
  for _, edge in pairs(border) do
    if edge.shown then
      return true
    end
  end
  return false
end

return function()
  -- test_hud_composer_draws_blizzard_input_border_on_existing_edit_box
  do
    local composer = create(true)
    assert(composer.input.template == nil, "HUD: composer keeps its own EditBox (art applied, not re-templated)")
    assert(#borderTextures(composer.input) == 3, "HUD: left/middle/right input border art, got " .. #borderTextures(composer.input))
  end

  -- test_hud_composer_has_no_custom_fill
  do
    local composer = create(true)
    assert(composer.paneBg.color[4] == 0, "HUD: composer pane background transparent")
    assert(anyEdgeShown(composer.border) == false, "HUD: no custom hairline over the Blizzard art")
    assert(composer.sheen == nil, "HUD: no gloss sheen")
  end

  -- test_hud_theme_refresh_keeps_blizzard_look
  do
    local composer = create(true)
    composer.refreshTheme()
    assert(composer.paneBg.color[4] == 0, "HUD refresh: pane stays transparent")
    local c = composer.input.textColor
    assert(c[1] == 1 and c[2] == 1 and c[3] == 1, "HUD refresh: input text stays Blizzard white")
    assert(anyEdgeShown(composer.border) == false, "HUD refresh: hairline stays hidden")
  end

  -- test_hud_composer_still_sends
  do
    local sent = nil
    local composer = create(true, function(payload)
      sent = payload
    end)
    composer.input:SetText("hello")
    composer.input.scripts.OnEnterPressed(composer.input)
    assert(sent and sent.text == "hello" and sent.target == "Arthas", "HUD: Enter still sends")
    assert(composer.input:GetText() == "", "HUD: input clears after send")
    assert(composer.sendButton.scripts.OnClick ~= nil and composer.emojiButton.scripts.OnClick ~= nil, "HUD: send + emoji buttons wired")
  end

  -- test_modern_composer_unchanged
  do
    local composer = create(false)
    assert(#borderTextures(composer.input) == 0, "modern: no Blizzard border art")
    assert(composer.sheen ~= nil, "modern: sheen kept")
    assert(composer.paneBg.color[4] ~= 0 or Theme.COLORS.bg_composer[4] == 0, "modern: pane painted with bg_composer")
    assert(composer.border.top.shown == true, "modern: top hairline kept")
  end

  -- test_default_args_are_modern
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(600, 60)
    local composer = Composer.Create(factory, parent, CONTACT, function() end)
    assert(#borderTextures(composer.input) == 0 and composer.sheen ~= nil, "no options -> modern composer")
  end
end

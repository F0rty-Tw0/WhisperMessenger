local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = false })
end

-- Glyph color of a title-bar button (icon vertex color).
local function glyphColor(button)
  return button._wmGlyph.vertexColor
end

local function hover(button, over)
  button.mouseOver = over
  local script = button:GetScript(over and "OnEnter" or "OnLeave")
  script(button)
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_modern_title_bar_buttons_are_borderless_icons
  Theme.SetPreset("wow_default")
  local chrome = build()
  chrome.backButton:Show()
  for name, button in pairs({
    newWhisper = chrome.newConversationButton,
    whatsNew = chrome.patchNotesButton,
    options = chrome.optionsButton,
    back = chrome.backButton,
    close = chrome.closeButton,
  }) do
    local circle = button._wmHoverCircle
    assert(circle ~= nil and button._wmGlyph ~= nil, name .. ": exposes hover circle + glyph")
    assert(button._wmBg.color[4] == 0, name .. ": no square fill")
    assert(circle.shown ~= true, name .. ": no circle at rest")
    assert(glyphColor(button)[4] == Theme.COLORS.text_secondary[4], name .. ": neutral text_secondary glyph at rest")

    hover(button, true)
    assert(circle.shown == true, name .. ": faint circle on hover")
    local c = circle.vertexColor
    assert(c[1] == 1 and c[2] == 1 and c[3] == 1, name .. ": hover circle is white")
    assert(circle.alpha == 0.06, name .. ": hover circle fades to 0.06, not 1")
    assert(glyphColor(button)[4] == 1, name .. ": glyph at full alpha on hover")
    assert(button._wmBg.color[4] == 0, name .. ": still no square fill on hover")
    hover(button, false)
    assert(circle.shown == false, name .. ": circle hides on leave")
  end

  -- test_azeroth_title_bar_buttons_are_borderless_icons_too
  Theme.SetPreset("wow_native")
  chrome = build()
  assert(chrome.newConversationButton._wmBg.color[4] == 0, "azeroth: new whisper has no square fill")
  assert(chrome.patchNotesButton._wmBg.color[4] == 0, "azeroth: what's new has no square fill")

  -- test_title_bar_buttons_render_above_title_bar_background
  -- The title bar and the buttons are siblings; an equal frame level lets the
  -- near-opaque title bar (Shadowlands, Pandaria) paint over the glyphs.
  for _, preset in ipairs({ "elvui_dark", "jade_dark" }) do
    Theme.SetPreset(preset)
    chrome = build()
    local barLevel = chrome.titleBar:GetFrameLevel()
    for name, button in pairs({
      newWhisper = chrome.newConversationButton,
      whatsNew = chrome.patchNotesButton,
      options = chrome.optionsButton,
      back = chrome.backButton,
      close = chrome.closeButton,
    }) do
      assert(button:GetFrameLevel() > barLevel, preset .. ": " .. name .. " must sit above the title bar")
    end
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_chrome_icon_buttons")
end

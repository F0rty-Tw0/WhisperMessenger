local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = false })
end

local function titleButtons(chrome)
  return {
    newWhisper = chrome.newConversationButton,
    whatsNew = chrome.patchNotesButton,
    options = chrome.optionsButton,
    back = chrome.backButton,
    close = chrome.closeButton,
  }
end

local function assertPoint(region, point, relativeTo, relativePoint, x, y, label)
  local p, rel, rp, px, py = region:GetPoint()
  assert(p == point and rel == relativeTo and rp == relativePoint, label .. ": anchor " .. tostring(p) .. "/" .. tostring(rp))
  assert(px == x and py == y, label .. ": offset " .. tostring(px) .. "," .. tostring(py) .. " expected " .. x .. "," .. y)
end

return function()
  local previousPreset = Theme.GetPreset()
  local T = Theme.TEXTURES
  local L = Theme.LAYOUT

  -- test_modern_title_buttons_use_bundled_line_icons
  Theme.SetPreset("wow_default")
  local chrome = build()
  local expected = {
    newWhisper = T.title_new_whisper_icon,
    whatsNew = T.title_whats_new_icon,
    options = T.title_settings_icon,
    back = T.title_back_icon,
    close = T.title_close_icon,
  }
  for name, button in pairs(titleButtons(chrome)) do
    assert(type(expected[name]) == "string" and expected[name]:find("Media"), name .. ": texture registered in Theme.TEXTURES")
    assert(button._wmGlyph.texturePath == expected[name], name .. ": modern glyph is " .. tostring(button._wmGlyph.texturePath))
  end

  -- test_modern_title_buttons_share_one_size
  for name, button in pairs(titleButtons(chrome)) do
    assert(button.width == L.TITLE_BUTTON_SIZE and button.height == L.TITLE_BUTTON_SIZE, name .. ": hit size " .. tostring(button.width))
    local glyph = button._wmGlyph
    assert(glyph.width == L.CHROME_BUTTON_ICON_SIZE, name .. ": icon size " .. tostring(glyph.width))
  end

  -- test_modern_title_buttons_evenly_spaced_and_centered
  local gap = L.TITLE_BUTTON_GAP
  assertPoint(chrome.closeButton, "RIGHT", chrome.titleBar, "RIGHT", -L.TITLE_BAR_INSET_X, 0, "close")
  assertPoint(chrome.optionsButton, "RIGHT", chrome.closeButton, "LEFT", -gap, 0, "options")
  assertPoint(chrome.backButton, "RIGHT", chrome.optionsButton, "LEFT", -gap, 0, "back")
  assertPoint(chrome.newConversationButton, "LEFT", chrome.title, "RIGHT", gap, 0, "new whisper")
  assertPoint(chrome.patchNotesButton, "LEFT", chrome.newConversationButton, "RIGHT", gap, 0, "what's new")
  -- Title ink lines up with the close glyph's ink on the other side.
  local titleInset = L.TITLE_BAR_INSET_X + (L.TITLE_BUTTON_SIZE - L.CHROME_BUTTON_ICON_SIZE) / 2
  assertPoint(chrome.title, "LEFT", chrome.titleBar, "LEFT", titleInset, 0, "title")

  -- test_modern_hover_fades_circle_and_brightens_glyph
  for name, button in pairs(titleButtons(chrome)) do
    local circle, glyph = button._wmHoverCircle, button._wmGlyph
    button.mouseOver = false
    button:GetScript("OnLeave")(button)
    assert(circle:IsShown() ~= true, name .. ": no circle at rest")
    assert(glyph.vertexColor[4] == Theme.COLORS.text_secondary[4], name .. ": idle glyph uses text_secondary")
    button.mouseOver = true
    button:GetScript("OnEnter")(button)
    assert(circle:IsShown() == true, name .. ": circle on hover")
    assert(circle.vertexColor[4] == 1, name .. ": circle colour carried at full alpha (HoverFade.paintVertex)")
    assert(circle.alpha > 0 and circle.alpha <= 0.08, name .. ": circle fades to a faint peak, got " .. tostring(circle.alpha))
    if name ~= "close" then
      assert(glyph.vertexColor[1] == Theme.COLORS.text_primary[1], name .. ": hover glyph uses text_primary")
    end
    button.mouseOver = false
    button:GetScript("OnLeave")(button)
  end

  -- test_modern_close_turns_danger_red_on_hover
  chrome.closeButton.mouseOver = true
  chrome.closeButton:GetScript("OnEnter")(chrome.closeButton)
  local c = chrome.closeButton._wmGlyph.vertexColor
  assert(c[1] > 0.8 and c[2] < 0.5 and c[3] < 0.5, "close glyph goes red on hover")

  -- test_azeroth_title_bar_matches_every_preset
  Theme.SetPreset("wow_native")
  chrome = build()
  for name, button in pairs(titleButtons(chrome)) do
    assert(button._wmGlyph.texturePath == expected[name], "azeroth: " .. name .. " uses the bundled line icon")
  end
  assert(chrome.closeButton.width == L.TITLE_BUTTON_SIZE, "azeroth: shared title-bar hit size")
  assertPoint(chrome.optionsButton, "RIGHT", chrome.closeButton, "LEFT", -gap, 0, "azeroth options")

  -- test_preset_switch_keeps_title_bar
  Theme.SetPreset("jade_dark")
  chrome.applyTheme(Theme)
  assert(chrome.closeButton._wmGlyph.texturePath == T.title_close_icon, "switch: close icon kept")
  assert(chrome.closeButton.width == L.TITLE_BUTTON_SIZE, "switch: size updated")
  assertPoint(chrome.optionsButton, "RIGHT", chrome.closeButton, "LEFT", -gap, 0, "switch options")

  Theme.SetPreset(previousPreset)
  print("PASS: test_title_bar_modern")
end

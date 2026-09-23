local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Presets = require("WhisperMessenger.UI.Theme.Presets")
local ModernChrome = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ModernChrome")

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  for i = 1, 4 do
    if math.abs((actual[i] or 1) - (expected[i] or 1)) > 0.0001 then
      return false
    end
  end
  return true
end

-- Window-edge hairlines: the frame's textures painted with window_border.
local function edgeTextures(chrome, color)
  local edges = {}
  for _, region in ipairs({ chrome.background.parent:GetRegions() }) do
    if colorsMatch(region.color, color) then
      edges[#edges + 1] = region
    end
  end
  return edges
end

local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "WindowTest", nil)
  frame:SetSize(900, 580)
  return ModernChrome.Build(factory, frame, {}, Theme)
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_every_preset_defines_window_border
  for _, key in ipairs(Presets.ListKeys()) do
    local palette = assert(Presets.Get(key), key .. ": expected preset palette")
    assert(type(palette.window_border) == "table", key .. ": expected window_border token")
  end

  -- test_modern_window_edge_uses_window_border
  do
    Theme.SetPreset("wow_default")
    local edges = edgeTextures(build(), Theme.COLORS.window_border)
    assert(#edges == 4, "modern: all four window edges should use window_border, got " .. #edges)
    assert(edges[1].color[4] <= 0.10, "modern: window edge should be a subtle white-plus-alpha hairline")
  end

  -- test_modern_title_is_full_name
  do
    Theme.SetPreset("wow_default")
    local chrome = build()
    assert(chrome.title.text == Theme.MODERN_TITLE, "modern: title should be the full addon name, got " .. tostring(chrome.title.text))
    assert(chrome.title.text == "WhisperMessenger", "modern: MODERN_TITLE should read WhisperMessenger")
  end

  -- test_modern_title_shadow_comes_from_font_object
  do
    local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
    Fonts.Initialize("default")
    local titleFont = _G[Theme.FONTS.window_title]
    assert(titleFont ~= nil, "a dedicated title font object exists")
    assert(titleFont._shadowOffset[1] == 1 and titleFont._shadowOffset[2] == -1, "title font object carries the shadow offset")
    assert(titleFont._shadowColor[4] == 0.85, "title font object carries the shadow colour")
    Theme.SetPreset("wow_default")
    local chrome = build()
    assert(chrome.title.fontObject == titleFont, "modern: title uses the shadowed font object")
  end

  -- test_title_follows_runtime_preset_switch
  do
    Theme.SetPreset("plumber_warm")
    local chrome = build()
    local edges = edgeTextures(chrome, Theme.COLORS.window_border)
    Theme.SetPreset("jade_dark")
    chrome.applyChromePaint(Theme)
    assert(chrome.title.text == Theme.MODERN_TITLE, "switching preset should keep the full title")
    assert(#edges == 4, "expected four window edges before the preset switch")
    for _, edge in ipairs(edges) do
      assert(colorsMatch(edge.color, Theme.COLORS.window_border), "switching preset should repaint the window edge")
    end
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_modern_chrome")
end

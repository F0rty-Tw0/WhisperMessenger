local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Shapes = require("WhisperMessenger.UI.Helpers.Shapes")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")

local function colorsMatch(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function lastPoint(region, anchor)
  local found
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == anchor then
      found = pt
    end
  end
  return found
end

local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  return SettingsControls.CreateHeader(frame, { title = "Apparence", hint = "Hint text" })
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_modern_section_title_with_fading_hairlines
  do
    Theme.SetPreset("wow_default")
    local header = build()
    assert(header.title.text == "Apparence", "title text kept as-is (no forced uppercase)")
    assert(header.title.fontObject == (_G[Theme.FONTS.system_text] or Theme.FONTS.system_text), "modern: small title font")
    assert(colorsMatch(header.title.textColor, Theme.COLORS.text_secondary), "modern: secondary text colour")
    for _, side in ipairs({ "leftLine", "rightLine" }) do
      local line = header[side]
      assert(line.shown == true, "modern: " .. side .. " shown")
      assert(line.height == Shapes.hairlineThickness(line, 1), "modern: " .. side .. " is a pixel hairline")
      assert(line.width > 0, "modern: " .. side .. " has width")
    end
    assert(lastPoint(header.leftLine, "RIGHT")[2] == header.title, "left line ends at the title")
    assert(lastPoint(header.rightLine, "LEFT")[2] == header.title, "right line starts at the title")
  end

  -- test_azeroth_uses_the_same_section_title
  do
    Theme.SetPreset("wow_native")
    local header = build()
    assert(header.title.fontObject == (_G[Theme.FONTS.system_text] or Theme.FONTS.system_text), "azeroth: small title font")
    assert(header.leftLine.shown == true and header.rightLine.shown == true, "azeroth: fading hairlines shown")
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_settings_header")
end

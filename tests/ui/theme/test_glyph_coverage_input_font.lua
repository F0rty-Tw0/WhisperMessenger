local FakeUI = require("tests.helpers.fake_ui")
local GlyphCoverage = require("WhisperMessenger.UI.Theme.GlyphCoverage")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

local SHARED_MEDIA_FONT = "Interface\\AddOns\\SharedMedia\\Roboto.ttf"
local CHAT_FONT = "Fonts\\ARIALN.TTF"

-- A LibSharedMedia that knows one font, "Roboto".
local function withSharedMedia(fn)
  local savedLibStub = rawget(_G, "LibStub")
  local lsm = {
    List = function()
      return { "Roboto" }
    end,
    Fetch = function(_, _mediaType, name)
      return name == "Roboto" and SHARED_MEDIA_FONT or nil
    end,
  }
  rawset(
    _G,
    "LibStub",
    setmetatable({}, {
      __call = function(_, name)
        return name == "LibSharedMedia-3.0" and lsm or nil
      end,
    })
  )
  local ok, err = pcall(fn)
  rawset(_G, "LibStub", savedLibStub)
  Fonts.Initialize("default")
  if not ok then
    error(err, 0)
  end
end

-- Text boxes sit on the chat-font twin for good: a live edit box ignores a
-- font swap made while it holds text, and answers nil to GetFontObject.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })

  -- test_a_box_on_a_font_with_those_letters_moves_to_the_twin_once_one_is_made
  -- Runs first: no twin may exist yet while the chosen font needs none.
  withSharedMedia(function()
    Fonts.Initialize("Roboto")
    local base = rawget(_G, "WM_ChatNormal")
    assert(GlyphCoverage.TwinOf(base) == nil, "no twin while the chosen font has those letters")

    local box = factory.CreateFrame("EditBox", nil, nil)
    ---@diagnostic disable-next-line: duplicate-set-field
    box.GetFontObject = function()
      return nil
    end
    GlyphCoverage.SetInputFont(box, "WM_ChatNormal")
    assert(box.fontObject == base, "the box stays on the chosen font")

    Fonts.SetMode("default")
    local twin = GlyphCoverage.TwinOf(base)
    assert(twin ~= nil and box.fontObject == twin, "the box moves to the twin made on the switch back")
    assert(twin:GetFont() == CHAT_FONT, "the twin is on the chat font, got " .. tostring(twin:GetFont()))
  end)

  -- test_input_font_names_the_twin_for_a_name_or_an_object
  do
    Fonts.Initialize("default")
    local wide = rawget(_G, "WM_ChatNormal_Wide")
    assert(GlyphCoverage.InputFont("WM_ChatNormal") == wide, "by global name")
    assert(GlyphCoverage.InputFont(rawget(_G, "WM_ChatNormal")) == wide, "by font object")
    local plain = rawget(_G, "GameFontNormal")
    assert(GlyphCoverage.InputFont(plain) == plain, "a font without a twin stays as it is")
  end

  -- test_set_input_font_keeps_the_text_colour
  do
    Fonts.Initialize("default")
    local box = factory.CreateFrame("EditBox", nil, nil)
    box:SetTextColor(0.2, 0.4, 0.6, 1)
    GlyphCoverage.SetInputFont(box, "WM_ChatNormal")
    local r, g, b = box:GetTextColor()
    assert(r == 0.2 and g == 0.4 and b == 0.6, "the colour survives the font change")
  end
end

local FakeUI = require("tests.helpers.fake_ui")
local GlyphCoverage = require("WhisperMessenger.UI.Theme.GlyphCoverage")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

local SHARED_MEDIA_FONT = "Interface\\AddOns\\SharedMedia\\Roboto.ttf"

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

local function newLabel(factory, fontName)
  local parent = factory.CreateFrame("Frame", nil, nil)
  local label = parent:CreateFontString(nil, "OVERLAY")
  label:SetFontObject(_G[fontName])
  return label
end

-- WoW's default UI font (Friz Quadrata) has no "ő", "ű" or most other Latin
-- Extended letters; text that needs them switches to a twin on the chat font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })

  -- test_needs_extended_latin_spots_hungarian_and_polish_letters
  do
    assert(GlyphCoverage.NeedsExtendedLatin("tűzőgép"), "ő and ű need it")
    assert(GlyphCoverage.NeedsExtendedLatin("Łódź"), "Polish letters need it")
    assert(GlyphCoverage.NeedsExtendedLatin("ș"), "Latin Extended-B (Romanian) needs it")
    assert(not GlyphCoverage.NeedsExtendedLatin("árvíztükör"), "Latin-1 accents are in the default font")
    assert(not GlyphCoverage.NeedsExtendedLatin("plain"), "ASCII is fine")
    assert(not GlyphCoverage.NeedsExtendedLatin(nil), "nil is fine")
  end

  -- test_needs_extended_latin_never_reads_a_secret_value
  do
    local savedIsSecret = rawget(_G, "issecretvalue")
    rawset(_G, "issecretvalue", function()
      return true
    end)
    local ok, needs = pcall(GlyphCoverage.NeedsExtendedLatin, "ő")
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(ok and needs == false, "a secret value is left alone")
  end

  -- test_default_fonts_get_a_chat_font_twin_of_the_same_size
  do
    Fonts.Initialize("default")
    local twin = GlyphCoverage.TwinOf(rawget(_G, "WM_Highlight"))
    assert(twin ~= nil and twin == rawget(_G, "WM_Highlight_Wide"), "message text has a twin")
    local path, size = twin:GetFont()
    assert(path == "Fonts\\ARIALN.TTF", "twin uses the chat font, got " .. tostring(path))
    local _, baseSize = rawget(_G, "WM_Highlight"):GetFont()
    assert(size == baseSize, "same size as the base")
    Fonts.SetFontSize(16)
    local _, newSize = twin:GetFont()
    assert(newSize == 16, "twin follows the size setting")
    Fonts.SetOutline("OUTLINE")
    local _, _, flags = twin:GetFont()
    assert(flags == "OUTLINE", "twin follows the outline setting")
    Fonts.Initialize("default")
  end

  -- test_twin_keeps_the_base_shadow_and_colour
  do
    Fonts.Initialize("default")
    local title, titleTwin = rawget(_G, "WM_Title"), rawget(_G, "WM_Title_Wide")
    assert(titleTwin._shadowOffset ~= nil, "the title twin has a shadow")
    assert(titleTwin._shadowOffset[1] == title._shadowOffset[1] and titleTwin._shadowOffset[2] == title._shadowOffset[2], "same shadow offset")
    assert(titleTwin._shadowColor[4] == title._shadowColor[4], "same shadow alpha")
    local r, g, b = rawget(_G, "WM_Normal_Wide"):GetTextColor()
    assert(r == 1 and g == 0.82 and b == 0, "contact names keep the gold colour, got " .. tostring(g))
  end

  -- test_apply_swaps_to_the_twin_and_back
  do
    Fonts.Initialize("default")
    local label = newLabel(factory, "WM_Highlight")
    assert(GlyphCoverage.Apply(label, "hosszú ő és ű") == "hosszú ő és ű", "Apply hands the text back")
    assert(label:GetFontObject() == rawget(_G, "WM_Highlight_Wide"), "text with ő uses the twin")
    GlyphCoverage.Apply(label, "ű")
    assert(label:GetFontObject() == rawget(_G, "WM_Highlight_Wide"), "stays on the twin")
    GlyphCoverage.Apply(label, "csak sima szöveg")
    assert(label:GetFontObject() == rawget(_G, "WM_Highlight"), "plain text goes back to the base font")
  end

  -- test_apply_keeps_the_text_colour
  do
    Fonts.Initialize("default")
    local label = newLabel(factory, "WM_DisableSmall")
    label:SetTextColor(0.2, 0.4, 0.6, 1)
    GlyphCoverage.Apply(label, "ő")
    local r, g, b = label:GetTextColor()
    assert(r == 0.2 and g == 0.4 and b == 0.6, "swapping to the twin keeps the colour")
    GlyphCoverage.Apply(label, "o")
    r, g, b = label:GetTextColor()
    assert(r == 0.2 and g == 0.4 and b == 0.6, "swapping back keeps the colour")
  end

  -- test_shared_media_font_brings_a_twin_user_back_and_follows_its_size
  withSharedMedia(function()
    Fonts.Initialize("default")
    local box = newLabel(factory, "WM_ChatNormal")
    GlyphCoverage.Apply(box, "tűzőgép")
    assert(box:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "on the twin first")
    Fonts.SetMode("Roboto")
    Fonts.SetFontSize(18)
    local path, size = box:GetFontObject():GetFont()
    assert(path == SHARED_MEDIA_FONT and size == 18, "a box left on the twin shows the chosen font, got " .. tostring(path) .. " " .. tostring(size))
    GlyphCoverage.Apply(box, "szia")
    assert(box:GetFontObject() == rawget(_G, "WM_ChatNormal"), "back on the base font")
    GlyphCoverage.Apply(box, "tűzőgép")
    assert(box:GetFontObject() == rawget(_G, "WM_ChatNormal"), "the chosen font draws ő itself")
    local _, baseSize = box:GetFontObject():GetFont()
    assert(baseSize == 18, "follows the size setting")
  end)

  -- test_back_on_the_default_font_the_twin_works_again
  withSharedMedia(function()
    Fonts.Initialize("default")
    Fonts.SetMode("Roboto")
    Fonts.SetMode("default")
    local label = newLabel(factory, "WM_Highlight")
    GlyphCoverage.Apply(label, "ő")
    assert(label:GetFontObject() == rawget(_G, "WM_Highlight_Wide"), "twin is used again")
    assert(rawget(_G, "WM_Highlight_Wide"):GetFont() == "Fonts\\ARIALN.TTF", "on the chat font again")
  end)

  -- test_other_language_display_brings_a_twin_user_back
  do
    local savedGetLocale = rawget(_G, "GetLocale")
    rawset(_G, "GetLocale", function()
      return "enUS"
    end)
    Fonts.Initialize("default")
    local label = newLabel(factory, "WM_Highlight")
    GlyphCoverage.Apply(label, "ő")
    Fonts.SetLanguage("ruRU")
    GlyphCoverage.Apply(label, "привет")
    rawset(_G, "GetLocale", savedGetLocale)
    assert(
      label:GetFontObject() == rawget(_G, "WM_Highlight"),
      "back on the base font, got " .. tostring(label:GetFontObject() and label:GetFontObject().name)
    )
    Fonts.Initialize("default")
  end

  -- test_other_language_display_keeps_its_font_chain_even_on_friz
  do
    local savedGetLocale = rawget(_G, "GetLocale")
    rawset(_G, "GetLocale", function()
      return "enUS"
    end)
    local tooltip = rawget(_G, "GameTooltipText")
    local savedPath, savedSize, savedFlags = tooltip:GetFont()
    -- On an enUS client the tooltip font is Friz Quadrata itself.
    tooltip:SetFont("Fonts\\FRIZQT__.TTF", savedSize, savedFlags)
    Fonts.Initialize("default")
    Fonts.SetLanguage("ruRU")
    local label = newLabel(factory, "WM_Highlight")
    GlyphCoverage.Apply(label, "ő")
    tooltip:SetFont(savedPath, savedSize, savedFlags)
    rawset(_G, "GetLocale", savedGetLocale)
    Fonts.Initialize("default")
    assert(label:GetFontObject() == rawget(_G, "WM_Highlight"), "the multi-script font chain is kept whole")
  end

  -- test_apply_ignores_widgets_without_font_objects
  do
    assert(GlyphCoverage.Apply(nil, "ő") == "ő", "nil widget")
    GlyphCoverage.Apply({}, "ő")
    GlyphCoverage.Apply({
      GetFontObject = function() end,
      SetFontObject = function()
        error("must not be called")
      end,
    }, "ő")
  end
end

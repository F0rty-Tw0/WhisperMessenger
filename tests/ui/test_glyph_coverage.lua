local FakeUI = require("tests.helpers.fake_ui")
local GlyphCoverage = require("WhisperMessenger.UI.Theme.GlyphCoverage")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

-- "ő" and "ű" (and the rest of Latin Extended) have no glyph in WoW's
-- default UI font; text that needs them switches to the chat font's twin.
return function()
  FakeUI.NewFactory()

  -- test_needs_extended_latin_spots_hungarian_double_acutes
  do
    assert(GlyphCoverage.NeedsExtendedLatin("tűzőgép"), "ő and ű need it")
    assert(GlyphCoverage.NeedsExtendedLatin("Łódź"), "Polish letters need it")
    assert(not GlyphCoverage.NeedsExtendedLatin("árvíztükör"), "Latin-1 accents are in the default font")
    assert(not GlyphCoverage.NeedsExtendedLatin("plain"), "ASCII is fine")
    assert(not GlyphCoverage.NeedsExtendedLatin(nil))
  end

  -- test_lacks_extended_latin_only_for_friz_quadrata
  do
    assert(GlyphCoverage.LacksExtendedLatin("Fonts\\FRIZQT__.TTF"))
    assert(not GlyphCoverage.LacksExtendedLatin("Fonts\\ARIALN.TTF"))
    assert(not GlyphCoverage.LacksExtendedLatin(nil))
  end

  -- test_default_fonts_get_a_chat_font_twin
  do
    Fonts.Initialize("default")
    local base = _G.WM_Highlight
    local twin = GlyphCoverage.TwinOf(base)
    assert(twin ~= nil and twin == _G.WM_Highlight_Wide, "message text has a twin")
    local path, size = twin:GetFont()
    assert(path == "Fonts\\ARIALN.TTF", "twin uses the chat font, got " .. tostring(path))
    local _, baseSize = base:GetFont()
    assert(size == baseSize, "same size as the base")
    Fonts.SetFontSize(16)
    local _, newSize = twin:GetFont()
    assert(newSize == 16, "twin follows the size setting")
    Fonts.SetFontSize(Fonts.DEFAULT_BASE_SIZE)
  end

  -- test_apply_swaps_to_the_twin_and_back
  do
    Fonts.Initialize("default")
    local label = { fontObject = _G.WM_Highlight }
    function label:GetFontObject()
      return self.fontObject
    end
    function label:SetFontObject(value)
      self.fontObject = value
    end
    GlyphCoverage.Apply(label, "hosszú ő és ű")
    assert(label.fontObject == _G.WM_Highlight_Wide, "text with ő uses the twin")
    GlyphCoverage.Apply(label, "csak sima szöveg")
    assert(label.fontObject == _G.WM_Highlight, "plain text goes back to the base font")
    GlyphCoverage.Apply(label, "ű")
    GlyphCoverage.Apply(label, "ő")
    assert(label.fontObject == _G.WM_Highlight_Wide, "stays on the twin")
  end

  -- test_fonts_that_have_the_letters_get_no_twin
  do
    Fonts.Initialize("default")
    GlyphCoverage.Register(_G.WM_Highlight, nil)
    local label = { fontObject = _G.WM_Highlight }
    function label:GetFontObject()
      return self.fontObject
    end
    function label:SetFontObject(value)
      self.fontObject = value
    end
    GlyphCoverage.Apply(label, "ő")
    assert(label.fontObject == _G.WM_Highlight, "no twin, no switch")
    Fonts.Initialize("default")
  end

  -- test_apply_ignores_widgets_without_font_objects
  do
    GlyphCoverage.Apply(nil, "ő")
    GlyphCoverage.Apply({}, "ő")
    GlyphCoverage.Apply({
      GetFontObject = function() end,
      SetFontObject = function()
        error("must not be called")
      end,
    }, "ő")
  end
end

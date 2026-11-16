local FakeUI = require("tests.helpers.fake_ui")
local GlyphCoverage = require("WhisperMessenger.UI.Theme.GlyphCoverage")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local FontBox = require("tests.helpers.font_box")

local SHARED_MEDIA_FONT = "Interface\\AddOns\\SharedMedia\\Roboto.ttf"
local CHAT_FONT = "Fonts\\ARIALN.TTF"
local FRIZ_FONT = FontBox.FRIZ

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

-- Counts the SetFont / SetFontObject calls box gets from now on.
local function countCalls(box)
  local calls = { setFont = 0, setFontObject = 0 }
  local setFont, setFontObject = box.SetFont, box.SetFontObject
  ---@diagnostic disable-next-line: duplicate-set-field
  box.SetFont = function(self, ...)
    calls.setFont = calls.setFont + 1
    return setFont(self, ...)
  end
  ---@diagnostic disable-next-line: duplicate-set-field
  box.SetFontObject = function(self, ...)
    calls.setFontObject = calls.setFontObject + 1
    return setFontObject(self, ...)
  end
  return calls
end

local function withSecretValues(fn, ...)
  local savedIsSecret = rawget(_G, "issecretvalue")
  rawset(_G, "issecretvalue", function()
    return true
  end)
  local ok, result = pcall(fn, ...)
  rawset(_G, "issecretvalue", savedIsSecret)
  return ok, result
end

-- Text boxes keep their base font and switch to the chat font file with
-- SetFont only while their text holds a letter the base font lacks.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })

  -- test_needs_chat_font_spots_letters_from_u0100_up
  do
    assert(GlyphCoverage.NeedsChatFont("szia") == false, "ASCII stays on the base font")
    assert(GlyphCoverage.NeedsChatFont("árvíztükör") == false, "Latin-1 accents are in the default font")
    assert(GlyphCoverage.NeedsChatFont("tűz") == true, "ű needs the chat font")
    assert(GlyphCoverage.NeedsChatFont("привет") == true, "Cyrillic needs the chat font")
    assert(GlyphCoverage.NeedsChatFont(nil) == false, "nil needs nothing")
  end

  -- test_needs_chat_font_never_reads_a_secret_value
  do
    local ok, needs = withSecretValues(GlyphCoverage.NeedsChatFont, "ő")
    assert(ok and needs == false, "a secret value is left alone")
  end

  -- test_a_box_on_a_chosen_font_gets_the_chat_font_for_its_text_once_the_base_lacks_those_letters
  -- Runs first of the font tests: no twin may exist yet while the chosen font needs none.
  withSharedMedia(function()
    Fonts.Initialize("Roboto")
    local base = rawget(_G, "WM_ChatNormal")
    assert(rawget(_G, "WM_ChatNormal_Wide") == nil, "no twin while the chosen font has those letters")

    local box = factory.CreateFrame("EditBox", nil, nil)
    GlyphCoverage.SetInputFont(box, "WM_ChatNormal")
    assert(box.fontObject == base, "the box stays on the chosen font")
    local calls = countCalls(box)
    box:SetText("tűz")
    GlyphCoverage.UpdateInput(box)
    assert(calls.setFont == 0, "no font swap while the base is not on a font lacking those letters")

    Fonts.SetMode("default")
    assert(rawget(_G, "WM_ChatNormal_Wide") ~= nil, "the twin is made on the switch back")
    assert(box:GetFont() == CHAT_FONT, "the text needs the chat font, got " .. tostring(box:GetFont()))
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

  -- test_a_box_starts_on_the_base_face_and_follows_its_text
  do
    Fonts.Initialize("default")
    local base = rawget(_G, "WM_ChatNormal")
    local _, baseSize = base:GetFont()
    local box = factory.CreateFrame("EditBox", nil, nil)
    GlyphCoverage.SetInputFont(box, "WM_ChatNormal")
    local path, size = box:GetFont()
    assert(path == FRIZ_FONT and size == baseSize, "empty box on the base face, got " .. tostring(path))
    box:SetText("tűz")
    GlyphCoverage.UpdateInput(box)
    path, size = box:GetFont()
    assert(path == CHAT_FONT and size == baseSize, "text with ű on the chat font at the same size, got " .. tostring(path))
    box:SetText("tz")
    GlyphCoverage.UpdateInput(box)
    assert(box:GetFont() == FRIZ_FONT, "back on the base face once the letter is gone")
  end

  -- test_update_input_swaps_only_when_the_face_changes
  do
    Fonts.Initialize("default")
    local box = factory.CreateFrame("EditBox", nil, nil)
    GlyphCoverage.SetInputFont(box, "WM_ChatNormal")
    local calls = countCalls(box)
    box:SetText("plain")
    GlyphCoverage.UpdateInput(box)
    GlyphCoverage.UpdateInput(box)
    assert(calls.setFont == 0, "same face twice: no SetFont, got " .. calls.setFont)
    box:SetText("tűz")
    GlyphCoverage.UpdateInput(box)
    GlyphCoverage.UpdateInput(box)
    assert(calls.setFont == 1, "one SetFont for the move to the chat face, got " .. calls.setFont)
    assert(calls.setFontObject == 0, "UpdateInput never calls SetFontObject")
  end

  -- test_refresh_inputs_follows_the_size_setting_on_both_faces
  do
    Fonts.Initialize("default")
    local plainBox = factory.CreateFrame("EditBox", nil, nil)
    GlyphCoverage.SetInputFont(plainBox, "WM_ChatNormal")
    local wideBox = factory.CreateFrame("EditBox", nil, nil)
    GlyphCoverage.SetInputFont(wideBox, "WM_ChatNormal")
    wideBox:SetText("tűz")
    GlyphCoverage.UpdateInput(wideBox)
    Fonts.SetFontSize(18)
    local _, baseSize = rawget(_G, "WM_ChatNormal"):GetFont()
    local plainPath, plainSize = plainBox:GetFont()
    local widePath, wideSize = wideBox:GetFont()
    Fonts.Initialize("default")
    assert(baseSize == 18, "the base font follows the slider, got " .. tostring(baseSize))
    assert(plainPath == FRIZ_FONT and plainSize == baseSize, "base face at the new size, got " .. tostring(plainSize))
    assert(widePath == CHAT_FONT and wideSize == baseSize, "chat face at the new size, got " .. tostring(wideSize))
  end

  -- test_other_language_display_moves_a_box_back_to_its_base_font
  -- That language keeps the game's multi-script font chain on base.
  do
    local savedGetLocale = rawget(_G, "GetLocale")
    rawset(_G, "GetLocale", function()
      return "enUS"
    end)
    Fonts.Initialize("default")
    local base = rawget(_G, "WM_ChatNormal")
    local box = factory.CreateFrame("EditBox", nil, nil)
    GlyphCoverage.SetInputFont(box, "WM_ChatNormal")
    Fonts.SetLanguage("ruRU")
    local onBase = box.fontObject == base
    local calls = countCalls(box)
    box:SetText("tűz")
    GlyphCoverage.UpdateInput(box)
    local swapsInRuRU = calls.setFont
    box:SetText("")
    Fonts.SetLanguage("auto")
    local backOnBase = box.fontObject == base and box:GetFont() == FRIZ_FONT
    rawset(_G, "GetLocale", savedGetLocale)
    Fonts.Initialize("default")
    assert(onBase, "the box is on the base font for that language")
    assert(swapsInRuRU == 0, "the multi-script chain stays whole: no SetFont, got " .. swapsInRuRU)
    assert(backOnBase, "after auto the box is on the base font with the Friz face")
  end

  -- test_a_font_name_not_built_yet_leaves_the_box_alone
  do
    local box = factory.CreateFrame("EditBox", nil, nil)
    GlyphCoverage.SetInputFont(box, "WM_NotYetBuiltFont")
    local calls = countCalls(box)
    box:SetText("tűz")
    local ok = pcall(GlyphCoverage.UpdateInput, box)
    assert(ok, "no error for a font that does not exist yet")
    assert(calls.setFont == 0, "no SetFont, got " .. calls.setFont)
  end

  -- test_a_secret_text_puts_the_box_back_on_the_base_face
  do
    Fonts.Initialize("default")
    local box = factory.CreateFrame("EditBox", nil, nil)
    GlyphCoverage.SetInputFont(box, "WM_ChatNormal")
    box:SetText("tűz")
    GlyphCoverage.UpdateInput(box)
    assert(box:GetFont() == CHAT_FONT, "on the chat face first")
    local ok = withSecretValues(GlyphCoverage.UpdateInput, box)
    assert(ok and box:GetFont() == FRIZ_FONT, "a secret text is read as plain: base face")
  end

  -- test_game_input_font_keeps_the_boxes_own_face
  do
    local box = FontBox.Give(factory.CreateFrame("EditBox", nil, nil), FRIZ_FONT, 12)
    GlyphCoverage.SetGameInputFont(box)
    local path, size = box:GetFont()
    assert(path == FRIZ_FONT and size == 12, "plain text: its own face, got " .. tostring(path))
    box:SetText("tűz")
    GlyphCoverage.UpdateInput(box)
    path, size = box:GetFont()
    assert(path == CHAT_FONT and size == 12, "text with ű: chat font at its own size, got " .. tostring(path))
    GlyphCoverage.SetGameInputFont(box)
    box:SetText("tz")
    GlyphCoverage.UpdateInput(box)
    path, size = box:GetFont()
    assert(path == FRIZ_FONT and size == 12, "a second call kept Friz 12 as its own face, got " .. tostring(path))
  end

  -- test_use_chat_face_moves_a_friz_box_to_the_chat_font_and_back
  do
    local box = FontBox.Give(factory.CreateFrame("EditBox", nil, nil), FontBox.FRIZ, 13, "OUTLINE")
    local saved = GlyphCoverage.UseChatFace(box)
    local path, size, flags = box:GetFont()
    assert(path == CHAT_FONT and size == 13 and flags == "OUTLINE", "on the chat font at its own size, got " .. tostring(path))
    assert(GlyphCoverage.UseChatFace(box) == nil, "a second call leaves it alone")
    GlyphCoverage.RestoreFace(box, saved)
    assert(box:GetFont() == FontBox.FRIZ, "back on its own font")
  end

  -- test_use_chat_face_leaves_a_font_with_those_letters_alone
  do
    local box = FontBox.Give(factory.CreateFrame("EditBox", nil, nil), "Fonts\\ARKai_T.ttf")
    assert(GlyphCoverage.UseChatFace(box) == nil, "nothing to restore")
    assert(box:GetFont() == "Fonts\\ARKai_T.ttf", "a locale font stays")
  end

  -- test_game_input_font_leaves_a_font_with_those_letters_alone
  do
    local box = FontBox.Give(factory.CreateFrame("EditBox", nil, nil), "Fonts\\ARKai_T.ttf", 12)
    local calls = countCalls(box)
    GlyphCoverage.SetGameInputFont(box)
    assert(calls.setFont == 0, "registering a locale-font box sets no font, got " .. calls.setFont)
    GlyphCoverage.RefreshInputs()
    assert(calls.setFont == 0, "a font rebuild sets no font on it, got " .. calls.setFont)
    box:SetText("tűz")
    GlyphCoverage.UpdateInput(box)
    assert(calls.setFont == 0, "typing ű sets no font on it, got " .. calls.setFont)
    assert(box:GetFont() == "Fonts\\ARKai_T.ttf", "a locale font stays")
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

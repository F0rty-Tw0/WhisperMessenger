local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local UIHelpers = require("WhisperMessenger.UI.Helpers")
local ComposerSurface = require("WhisperMessenger.UI.Composer.ComposerSurface")
local PreviewReplyRow = require("WhisperMessenger.UI.ToggleIcon.PreviewReplyRow")

local function build()
  local factory = FakeUI.NewFactory()
  local card = factory.CreateFrame("Frame", nil, nil)
  card:Show()
  return PreviewReplyRow.Create(factory, card, {})
end

local function fileBorderPieces(input)
  local count = 0
  for _, child in ipairs(input.children or {}) do
    if child.frameType == "Texture" and child.texturePath == ComposerSurface.NATIVE_BORDER_TEXTURE then
      count = count + 1
    end
  end
  return count
end

local function atlasPieces(input)
  local out = {}
  for _, child in ipairs(input.children or {}) do
    if child.frameType == "Texture" and child.atlas then
      out[child.atlas] = true
    end
  end
  return out
end

local function isColor(fontString, r, g, b)
  local cr, cg, cb = fontString:GetTextColor()
  return cr == r and cg == g and cb == b
end

-- Runs fn(callCount) with createRoundedBackground wrapped by a call counter.
local function countingRoundedFill(fn)
  local original = UIHelpers.createRoundedBackground
  local calls = 0
  UIHelpers.createRoundedBackground = function(...)
    calls = calls + 1
    return original(...)
  end
  local ok, err = pcall(fn, function()
    return calls
  end)
  UIHelpers.createRoundedBackground = original
  if not ok then
    error(err, 0)
  end
end

-- Runs fn with the classic HUD configured, then turns it off again.
local function withClassicHud(fn)
  Hud.Configure("classic")
  local ok, err = pcall(fn)
  Hud.Configure("off")
  if not ok then
    error(err, 0)
  end
end

return function()
  local function test_hud_reply_row_draws_native_border()
    withClassicHud(function()
      local row = build()
      assert(fileBorderPieces(row.input) == 3, "HUD: 3 file-art border pieces, got " .. fileBorderPieces(row.input))
    end)
  end

  local function test_hud_reply_row_has_no_rounded_fill()
    withClassicHud(function()
      countingRoundedFill(function(calls)
        build()
        assert(calls() == 0, "HUD: no rounded fill, got " .. calls())
      end)
    end)
    countingRoundedFill(function(calls)
      local row = build()
      assert(calls() == 1, "HUD off: rounded fill kept, got " .. calls())
      assert(fileBorderPieces(row.input) == 0, "HUD off: no border art")
    end)
  end

  local function test_hud_reply_row_native_colours_survive_apply_theme()
    withClassicHud(function()
      local row = build()
      row.applyTheme(Theme)
      assert(isColor(row.input, 1, 1, 1), "HUD: input text stays white after applyTheme")
      assert(isColor(row.placeholder, 0.5, 0.5, 0.5), "HUD: placeholder stays grey after applyTheme")
    end)
  end

  local function test_hud_off_reply_row_uses_theme_colours()
    local row = build()
    local c = Theme.COLORS.text_secondary
    assert(isColor(row.placeholder, c[1], c[2], c[3]), "HUD off: placeholder uses text_secondary")
  end

  local function test_hud_reply_row_disabled_reason_stays_grey()
    withClassicHud(function()
      local row = build()
      row.setEnabled(false, "In combat")
      assert(row.placeholder:GetText() == "In combat", "disabled row shows the reason")
      assert(isColor(row.placeholder, 0.5, 0.5, 0.5), "HUD: reason text stays grey")
    end)
  end

  local function test_retail_hud_reply_row_uses_search_atlases()
    RetailHud.With(function()
      RetailHud.WithAtlas(true, function()
        local row = build()
        local atlases = atlasPieces(row.input)
        assert(next(atlases) ~= nil, "retail HUD: reply row draws atlas pieces")
        for _, name in pairs(ComposerSurface.NATIVE_SEARCH_ATLAS) do
          assert(atlases[name], "retail HUD: reply row draws atlas " .. name)
        end
        assert(fileBorderPieces(row.input) == 0, "retail HUD: no file-art pieces mixed in")
      end)
    end)
  end

  test_hud_reply_row_draws_native_border()
  test_hud_reply_row_has_no_rounded_fill()
  test_hud_reply_row_native_colours_survive_apply_theme()
  test_hud_off_reply_row_uses_theme_colours()
  test_hud_reply_row_disabled_reason_stays_grey()
  test_retail_hud_reply_row_uses_search_atlases()
end

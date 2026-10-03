local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local FakeUI = require("tests.helpers.fake_ui")

-- The header stacks three text rows (name, status, detail). A bigger font
-- must grow the header so the rows stay inside it instead of spilling into
-- the transcript.

local BASE_HEADER = Theme.LAYOUT.HEADER_HEIGHT
local MAX_FONT_SIZE = 17

local function newPane(factory)
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  return ConversationPane.Create(factory, parent, { displayName = "Arthas" }, { messages = {} })
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_header_height_stays_base_at_default_and_smaller_fonts
  do
    Fonts.SetFontSize(12)
    assert(Theme.HeaderHeight() == BASE_HEADER, "12px font keeps the base header, got " .. Theme.HeaderHeight())
    Fonts.SetFontSize(9)
    assert(Theme.HeaderHeight() == BASE_HEADER, "small fonts never shrink the header, got " .. Theme.HeaderHeight())
  end

  -- test_header_height_grows_per_font_px_above_default
  do
    Fonts.SetFontSize(MAX_FONT_SIZE)
    local grown = (MAX_FONT_SIZE - Fonts.DEFAULT_BASE_SIZE) * Theme.LAYOUT.HEADER_GROWTH_PER_FONT_PX
    assert(Theme.HeaderHeight() == BASE_HEADER + grown, "17px font adds " .. grown .. "px, got " .. Theme.HeaderHeight())
  end

  -- test_header_growth_covers_all_three_text_rows
  do
    -- Name, status and detail each grow 1px per font px, plus line leading.
    assert(Theme.LAYOUT.HEADER_GROWTH_PER_FONT_PX > 3, "growth must exceed the three rows' glyph growth")
  end

  -- test_pane_created_at_big_font_uses_grown_header
  do
    Fonts.SetFontSize(MAX_FONT_SIZE)
    local view = newPane(factory)
    local expectedHeader = Theme.HeaderHeight()
    assert(view.headerFrame.height == expectedHeader, "header is " .. expectedHeader .. ", got " .. tostring(view.headerFrame.height))
    local sf = view.transcript.scrollFrame
    assert(sf:GetHeight() == 420 - expectedHeader, "transcript fills below the grown header, got " .. tostring(sf:GetHeight()))
  end

  -- test_relayout_uses_grown_header
  do
    Fonts.SetFontSize(MAX_FONT_SIZE)
    local view = newPane(factory)
    ConversationPane.Relayout(view, 600, 400)
    local sf = view.transcript.scrollFrame
    assert(sf:GetHeight() == 400 - Theme.HeaderHeight(), "relayout sizes the transcript below the grown header, got " .. tostring(sf:GetHeight()))
  end

  -- test_live_font_change_resizes_header_and_transcript_on_theme_refresh
  do
    Fonts.SetFontSize(12)
    local view = newPane(factory)
    ConversationPane.Relayout(view, 600, 400)
    assert(view.headerFrame.height == BASE_HEADER, "default font keeps the base header")

    Fonts.SetFontSize(MAX_FONT_SIZE)
    view.refreshTheme()
    local grownHeader = Theme.HeaderHeight()
    assert(view.headerFrame.height == grownHeader, "font change grows the header to " .. grownHeader .. ", got " .. tostring(view.headerFrame.height))
    local sf = view.transcript.scrollFrame
    assert(sf:GetHeight() == 400 - grownHeader, "font change shrinks the transcript to match, got " .. tostring(sf:GetHeight()))

    Fonts.SetFontSize(12)
    view.refreshTheme()
    assert(view.headerFrame.height == BASE_HEADER, "back to default font restores the base header, got " .. tostring(view.headerFrame.height))
    assert(sf:GetHeight() == 400 - BASE_HEADER, "back to default font restores the transcript, got " .. tostring(sf:GetHeight()))
  end

  -- test_long_zone_detail_is_ellipsized_to_the_header_width
  do
    Fonts.SetFontSize(MAX_FONT_SIZE)
    local view = newPane(factory)
    view._headerStatusDetailVisible = true
    view._headerStatusDetailFullText = "Paladin - Horde - The Exodar, Crystalsong Forest Northern Approach"
    ConversationPane.Relayout(view, 300, 400)
    local detail = view.headerStatusDetail
    assert(string.sub(detail:GetText(), -3) == "...", "long zone ends in an ellipsis, got " .. detail:GetText())
    assert(detail:GetStringWidth() <= detail:GetWidth(), "long zone stays within its label width")
  end

  Fonts.SetFontSize(12)
end

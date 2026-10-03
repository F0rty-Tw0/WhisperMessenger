local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local BottomBanner = require("WhisperMessenger.UI.ConversationPane.BottomBanner")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local FakeUI = require("tests.helpers.fake_ui")

-- A long notice (the Mythic+ pause) wraps onto several lines at big fonts.
-- The transcript must make room for every line so the notice never covers
-- the last chat bubble.

local NOTICE = "Messages are paused in Mythic content and will resume after you leave. To reply now, type /w and their name in the game's chat."
local PANE_W, PANE_H = 600, 400
-- The notice keeps a 4px gap below and above its text.
local TEXT_PAD = 8

local function newPane(factory)
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(PANE_W, 420)
  local view = ConversationPane.Create(factory, parent, { displayName = "Arthas" }, { messages = {} })
  ConversationPane.Relayout(view, PANE_W, PANE_H)
  return view
end

local function stubTextHeight(view, height)
  view.activeStatusBanner.GetStringHeight = function()
    return height
  end
end

local function transcriptH(view)
  return view.transcript.scrollFrame:GetHeight()
end

local function expectedH(reserved)
  return PANE_H - Theme.HeaderHeight() - reserved
end

return function()
  local factory = FakeUI.NewFactory()
  Fonts.SetFontSize(12)

  -- test_single_line_notice_reserves_the_base_banner_height
  do
    local view = newPane(factory)
    stubTextHeight(view, 12)
    ConversationPane.SetNotice(view, "Paused")
    local want = expectedH(BottomBanner.HEIGHT)
    assert(transcriptH(view) == want, "single line reserves the base height " .. want .. ", got " .. transcriptH(view))
  end

  -- test_wrapped_notice_reserves_its_wrapped_height
  do
    local view = newPane(factory)
    stubTextHeight(view, 54)
    ConversationPane.SetNotice(view, NOTICE)
    local want = expectedH(54 + TEXT_PAD)
    assert(transcriptH(view) == want, "three-line notice reserves " .. want .. ", got " .. transcriptH(view))
  end

  -- test_clearing_wrapped_notice_restores_the_transcript
  do
    local view = newPane(factory)
    stubTextHeight(view, 54)
    ConversationPane.SetNotice(view, NOTICE)
    ConversationPane.SetNotice(view, "")
    local want = expectedH(0)
    assert(transcriptH(view) == want, "cleared notice gives the space back, got " .. transcriptH(view))
  end

  -- test_notice_text_change_to_more_lines_grows_the_reservation
  do
    local view = newPane(factory)
    stubTextHeight(view, 18)
    ConversationPane.SetNotice(view, "Short")
    stubTextHeight(view, 54)
    ConversationPane.SetNotice(view, NOTICE)
    local want = expectedH(54 + TEXT_PAD)
    assert(transcriptH(view) == want, "longer notice grows the reservation to " .. want .. ", got " .. transcriptH(view))
  end

  -- test_relayout_remeasures_the_wrapped_notice
  do
    local view = newPane(factory)
    stubTextHeight(view, 54)
    ConversationPane.SetNotice(view, NOTICE)
    -- A wider pane fits the notice on two lines.
    stubTextHeight(view, 36)
    ConversationPane.Relayout(view, PANE_W, PANE_H)
    local want = expectedH(36 + TEXT_PAD)
    assert(transcriptH(view) == want, "relayout re-measures the notice to " .. want .. ", got " .. transcriptH(view))
  end

  -- test_live_font_change_remeasures_the_notice
  do
    local view = newPane(factory)
    view.activeStatusBanner.GetStringHeight = function()
      return Fonts.GetFontSize() > 12 and 60 or 14
    end
    ConversationPane.SetNotice(view, NOTICE)
    Fonts.SetFontSize(17)
    view.refreshTheme()
    local want = expectedH(60 + TEXT_PAD)
    assert(transcriptH(view) == want, "big font reserves the wrapped notice " .. want .. ", got " .. transcriptH(view))
    Fonts.SetFontSize(12)
  end

  -- test_reply_strip_keeps_the_base_banner_height
  do
    local view = newPane(factory)
    stubTextHeight(view, 54)
    ConversationPane.SetReply(view, { text = "hi", playerName = "Arthas" }, function() end)
    local want = expectedH(BottomBanner.HEIGHT)
    assert(transcriptH(view) == want, "reply strip reserves the base height, got " .. transcriptH(view))
  end
end

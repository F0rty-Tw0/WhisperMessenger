local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

-- A window resize relays the pane out; the transcript's scrollbar must stay
-- inside the narrower pane instead of sliding past its right edge.

local PANE_WIDTH = 600
local PANE_HEIGHT = 420
local NARROWER = 500
local MESSAGE_COUNT = 60

local function manyMessages()
  local messages = {}
  for index = 1, MESSAGE_COUNT do
    messages[index] = { direction = "in", playerName = "Arthas", sentAt = index, text = "line " .. index }
  end
  return messages
end

local function overflowingPane()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(PANE_WIDTH, PANE_HEIGHT)
  local contact = { conversationKey = "me::WOW::arthas", displayName = "Arthas" }
  local view = ConversationPane.Create(factory, parent, contact, { messages = manyMessages() })
  assert(view.transcript.hasOverflow == true, "setup: the history overflows the transcript")
  return view
end

-- Right edge of the scrollbar, measured from the pane's left edge.
local function barRightEdge(view)
  local t = view.transcript
  return Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER + t.scrollFrame:GetWidth() + t.scrollBar:GetWidth()
end

return function()
  -- test_relayout_keeps_the_transcript_scrollbar_inside_the_pane
  do
    local view = overflowingPane()
    view.frame.height = nil
    ConversationPane.Relayout(view, NARROWER, PANE_HEIGHT)
    local expected = NARROWER - (Theme.LAYOUT.TRANSCRIPT_HORIZONTAL_INSET - Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER)
    assert(barRightEdge(view) == expected, "bar keeps the gutter after relayout, got " .. tostring(barRightEdge(view)))
  end
end

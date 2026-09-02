local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

-- 8px below the header + 8px above the composer; no dead band.
local TRANSCRIPT_VERTICAL_GAP = 16

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  local view = ConversationPane.Create(factory, parent, { displayName = "Arthas" }, { messages = {} })
  local sf = view.transcript.scrollFrame

  -- test_transcript_fills_thread_pane_on_create
  do
    local expected = 420 - Theme.LAYOUT.HEADER_HEIGHT - TRANSCRIPT_VERTICAL_GAP
    assert(sf:GetHeight() == expected, "expected transcript height " .. expected .. ", got " .. tostring(sf:GetHeight()))
  end

  -- test_transcript_fills_thread_pane_on_relayout
  do
    ConversationPane.Relayout(view, 600, 400)
    local expected = 400 - Theme.LAYOUT.HEADER_HEIGHT - TRANSCRIPT_VERTICAL_GAP
    assert(sf:GetHeight() == expected, "expected transcript height " .. expected .. ", got " .. tostring(sf:GetHeight()))
  end

  -- test_relayout_prefers_live_pane_height_over_metric
  do
    -- Live client: the pane is dual-anchored, so its real height can differ
    -- from the window-derived metric passed in. The real height wins.
    view.frame.height = 380
    ConversationPane.Relayout(view, 600, 400)
    local expected = 380 - Theme.LAYOUT.HEADER_HEIGHT - TRANSCRIPT_VERTICAL_GAP
    assert(sf:GetHeight() == expected, "expected transcript height from live pane " .. expected .. ", got " .. tostring(sf:GetHeight()))
  end
end

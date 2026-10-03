local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")

-- The classic HUD knob is wide; it sits in the transcript's right gutter,
-- flush with the pane edge, instead of floating a gutter's width inside it.

local PANE_WIDTH = 600
local PANE_HEIGHT = 420
local TALL_CONTENT = 5000

local function newPane(style)
  Hud.Configure(style)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(PANE_WIDTH, PANE_HEIGHT)
  local view = ConversationPane.Create(factory, parent, { displayName = "Arthas" }, { messages = {} })
  Hud.Configure("off")
  return view
end

-- Right edge of the scrollbar, measured from the pane's left edge.
local function barRightEdge(view)
  local t = view.transcript
  local offset = t.scrollBar.points[1][4] or 0
  return Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER + t.scrollFrame:GetWidth() + offset + t.scrollBar:GetWidth()
end

return function()
  -- test_classic_bar_sits_flush_with_the_pane_edge
  do
    local view = newPane("classic")
    ScrollView.RefreshMetrics(view.transcript, TALL_CONTENT)
    assert(barRightEdge(view) == PANE_WIDTH, "classic: knob ends at the pane edge, got " .. tostring(barRightEdge(view)))
  end

  -- test_classic_bar_stays_flush_after_relayout
  do
    local view = newPane("classic")
    ScrollView.RefreshMetrics(view.transcript, TALL_CONTENT)
    local narrower = PANE_WIDTH - 100
    view.frame.height = nil
    ConversationPane.Relayout(view, narrower, PANE_HEIGHT)
    ScrollView.RefreshMetrics(view.transcript, TALL_CONTENT)
    assert(barRightEdge(view) == narrower, "classic: knob ends at the resized pane edge, got " .. tostring(barRightEdge(view)))
  end

  -- test_modern_hud_bar_moves_5px_into_the_gutter
  do
    local view
    RetailHud.With(function()
      local factory = FakeUI.NewFactory()
      local parent = factory.CreateFrame("Frame", "Parent", nil)
      parent:SetSize(PANE_WIDTH, PANE_HEIGHT)
      view = ConversationPane.Create(factory, parent, { displayName = "Arthas" }, { messages = {} })
    end)
    ScrollView.RefreshMetrics(view.transcript, TALL_CONTENT)
    local gutter = Theme.LAYOUT.TRANSCRIPT_HORIZONTAL_INSET - Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER
    local expected = PANE_WIDTH - gutter + 5
    assert(barRightEdge(view) == expected, "Modern HUD: slim bar sits 5px nearer the edge, got " .. tostring(barRightEdge(view)))
  end

  -- test_modern_bar_keeps_the_gutter
  do
    local view = newPane("off")
    ScrollView.RefreshMetrics(view.transcript, TALL_CONTENT)
    local expected = PANE_WIDTH - (Theme.LAYOUT.TRANSCRIPT_HORIZONTAL_INSET - Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER)
    assert(barRightEdge(view) == expected, "modern: thin bar keeps the gutter, got " .. tostring(barRightEdge(view)))
  end
end

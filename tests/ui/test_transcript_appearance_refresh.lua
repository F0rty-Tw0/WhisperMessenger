-- Appearance settings reach the transcript through a plain re-render. The
-- bubbles kept on screen must pick up the new look too, not only the rows
-- that scroll in later.

local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local Theme = require("WhisperMessenger.UI.Theme")
local TimeFormat = require("WhisperMessenger.Util.TimeFormat")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

local function makeTranscript()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 200)
  local transcript = ScrollView.Create(factory, parent, {
    width = 400,
    height = 200,
    step = TranscriptView.TRANSCRIPT_SCROLL_STEP,
  })
  transcript.factory = factory
  transcript.seenReceipts = false
  TranscriptSetup.ConfigureTranscript(factory, transcript, 400)
  return transcript
end

local function makeMessages(count)
  local messages = {}
  for index = 1, count do
    messages[index] = {
      direction = "in",
      kind = "user",
      playerName = index % 2 == 0 and "Arthas" or "Jaina",
      sentAt = 1700000000 + index * 60,
      text = "message " .. index,
    }
  end
  return messages
end

-- Renders, applies the setting, re-renders without force, and returns the
-- active pooled frames.
local function renderAcrossChange(applySetting)
  local transcript = makeTranscript()
  local messages = makeMessages(100)
  TranscriptView.RenderTranscript(transcript, messages)
  applySetting()
  TranscriptView.RenderTranscript(transcript, messages)
  return transcript.content._activeFrames
end

local function bubbles(frames)
  local result = {}
  for _, frame in ipairs(frames) do
    if frame._textFS and frame._wmMessage then
      result[#result + 1] = frame
    end
  end
  assert(#result > 0, "no bubbles on screen")
  return result
end

return function()
  -- test_font_color_change_recolors_on_screen_bubbles
  do
    Fonts.SetFontColor("default")
    local frames = renderAcrossChange(function()
      Fonts.SetFontColor("gold")
    end)
    local gold = assert(Fonts.GetFontColorRGBA(), "gold preset missing")
    for _, frame in ipairs(bubbles(frames)) do
      local r, g = frame._textFS:GetTextColor()
      assert(r == gold[1] and g == gold[2], "test_font_color_change_recolors_on_screen_bubbles: a bubble kept the old text color")
    end
    Fonts.SetFontColor("default")
  end

  -- test_bubble_color_change_recolors_on_screen_bubbles
  do
    Theme.SetBubblePreset("default")
    local frames = renderAcrossChange(function()
      Theme.SetBubblePreset("ember")
    end)
    local expected = Theme.COLORS.bg_bubble_in[1]
    for _, frame in ipairs(bubbles(frames)) do
      local fill = frame._bgFills[1]
      assert(fill.color[1] == expected, "test_bubble_color_change_recolors_on_screen_bubbles: a bubble kept the old background")
    end
    Theme.SetBubblePreset("default")
  end

  -- test_time_format_change_bumps_geometry_revision
  -- Sender labels bake in the time text. Offline they render no time (no
  -- shared ns), so check the redraw trigger itself.
  do
    TimeFormat.Configure({ timeFormat = "12h", timeSource = "local" })
    local before = Layout.GetGeometryRevision()
    TimeFormat.Configure({ timeFormat = "24h" })
    local afterFormat = Layout.GetGeometryRevision()
    TimeFormat.Configure({ timeSource = "server" })
    local afterSource = Layout.GetGeometryRevision()
    assert(afterFormat ~= before, "test_time_format_change_bumps_geometry_revision: time format change not seen")
    assert(afterSource ~= afterFormat, "test_time_format_change_bumps_geometry_revision: time source change not seen")
    TimeFormat.Configure({ timeFormat = "12h", timeSource = "local" })
  end
end

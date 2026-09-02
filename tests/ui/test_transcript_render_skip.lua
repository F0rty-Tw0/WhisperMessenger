-- Renders that change nothing must not re-lay-out the visible chat bubbles.
-- The background status refresh runs every ~30s; rebuilding every bubble there
-- was the single largest source of UI garbage while the window is open.

local FakeUI = require("tests.helpers.fake_ui")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local Virtualization = require("WhisperMessenger.UI.ConversationPane.TranscriptVirtualization")

local function makeMessages(count)
  local messages = {}
  for index = 1, count do
    messages[index] = {
      direction = index % 3 == 0 and "out" or "in",
      kind = "user",
      playerName = "Arthas",
      sentAt = index,
      text = "message " .. index,
    }
  end
  return messages
end

local function makeTranscript(width, height)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(width, height)
  local transcript = ScrollView.Create(factory, parent, {
    width = width,
    height = height,
    step = TranscriptView.TRANSCRIPT_SCROLL_STEP,
  })
  transcript.factory = factory
  TranscriptSetup.ConfigureTranscript(factory, transcript, width)
  return transcript
end

-- Replace Layout.LayoutRange with a counting wrapper. Returns a `stop` function
-- that restores the original and reports how many times it ran.
local function spyLayoutRange()
  local original = Layout.LayoutRange
  local calls = 0
  ---@diagnostic disable-next-line: duplicate-set-field
  Layout.LayoutRange = function(...)
    calls = calls + 1
    return original(...)
  end
  return function()
    Layout.LayoutRange = original
    return calls
  end
end

local function renderCount(fn)
  local stop = spyLayoutRange()
  local ok, err = pcall(fn)
  local calls = stop()
  if not ok then
    error(err)
  end
  return calls
end

return function()
  ----------------------------------------------------------------------------
  -- Re-rendering the identical message list skips the bubble relayout.
  ----------------------------------------------------------------------------
  do
    local transcript = makeTranscript(400, 300)
    local messages = makeMessages(5)
    TranscriptView.RenderTranscript(transcript, messages)

    local calls = renderCount(function()
      TranscriptView.RenderTranscript(transcript, messages)
    end)
    assert(calls == 0, "unchanged re-render should not lay out bubbles, got " .. calls .. " calls")
  end

  ----------------------------------------------------------------------------
  -- Render reports whether it relaid out, so callers can skip follow-up work.
  ----------------------------------------------------------------------------
  do
    local transcript = makeTranscript(400, 300)
    local messages = makeMessages(5)
    local options = { fallbackClassTag = "MAGE" }

    local _, _, _, firstRelaidOut = Virtualization.Render(transcript, messages, 400, options)
    assert(firstRelaidOut == true, "first render should relayout")

    local _, _, _, secondRelaidOut = Virtualization.Render(transcript, messages, 400, options)
    assert(secondRelaidOut == false, "unchanged render should report relaidOut=false")
  end

  ----------------------------------------------------------------------------
  -- Editing a message's text forces the relayout.
  ----------------------------------------------------------------------------
  do
    local transcript = makeTranscript(400, 300)
    local messages = makeMessages(5)
    TranscriptView.RenderTranscript(transcript, messages)

    messages[3].text = "edited body text"
    local calls = renderCount(function()
      TranscriptView.RenderTranscript(transcript, messages)
    end)
    assert(calls > 0, "changed message text should lay out bubbles")
  end

  ----------------------------------------------------------------------------
  -- Appending a message forces the relayout.
  ----------------------------------------------------------------------------
  do
    local transcript = makeTranscript(400, 300)
    local messages = makeMessages(5)
    TranscriptView.RenderTranscript(transcript, messages)

    messages[6] = { direction = "in", kind = "user", playerName = "Arthas", sentAt = 6, text = "message 6" }
    local calls = renderCount(function()
      TranscriptView.RenderTranscript(transcript, messages)
    end)
    assert(calls > 0, "appended message should lay out bubbles")
  end

  ----------------------------------------------------------------------------
  -- Removing the last message forces the relayout.
  ----------------------------------------------------------------------------
  do
    local transcript = makeTranscript(400, 300)
    local messages = makeMessages(5)
    TranscriptView.RenderTranscript(transcript, messages)

    messages[5] = nil
    local calls = renderCount(function()
      TranscriptView.RenderTranscript(transcript, messages)
    end)
    assert(calls > 0, "removed message should lay out bubbles")
  end

  ----------------------------------------------------------------------------
  -- An explicit force flag lays out even when nothing changed.
  ----------------------------------------------------------------------------
  do
    local transcript = makeTranscript(400, 300)
    local messages = makeMessages(5)
    TranscriptView.RenderTranscript(transcript, messages)

    local calls = renderCount(function()
      TranscriptView.RenderTranscript(transcript, messages, { force = true })
    end)
    assert(calls > 0, "force=true should lay out bubbles")
  end

  ----------------------------------------------------------------------------
  -- A different pane width lays out (bubble wrapping depends on it).
  ----------------------------------------------------------------------------
  do
    local transcript = makeTranscript(400, 300)
    local messages = makeMessages(5)
    local options = { fallbackClassTag = "MAGE" }
    Virtualization.Render(transcript, messages, 400, options)

    local calls = renderCount(function()
      Virtualization.Render(transcript, messages, 320, options)
    end)
    assert(calls > 0, "different pane width should lay out bubbles")
  end

  ----------------------------------------------------------------------------
  -- A different fallback class tag recolors names, so it must lay out.
  ----------------------------------------------------------------------------
  do
    local transcript = makeTranscript(400, 300)
    local messages = makeMessages(5)
    Virtualization.Render(transcript, messages, 400, { fallbackClassTag = "MAGE" })

    local calls = renderCount(function()
      Virtualization.Render(transcript, messages, 400, { fallbackClassTag = "ROGUE" })
    end)
    assert(calls > 0, "changed fallbackClassTag should lay out bubbles")
  end
end

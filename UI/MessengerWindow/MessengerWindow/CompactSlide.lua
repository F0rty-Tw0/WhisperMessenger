local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local CompactViewport = ns.MessengerWindowLayoutCompactViewport or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.CompactViewport")
local GlideClock = ns.GlideClock or require("WhisperMessenger.UI.Shared.GlideClock")

-- Moves the compact layout's strip between the list (0) and the chat (1).
-- Clipping runs only during a slide, and at rest the off-screen pane hides:
-- pop-ups inside the panes are never cut off, and nothing unseen takes clicks.
-- GlideClock eases the slide and caps each frame's step, so a slow first
-- frame pauses the slide instead of skipping it.
local CompactSlide = {}

-- options: layout, theme, isCovered() (settings or a panel hide the panes).
function CompactSlide.Create(options)
  local layout = options.layout
  local viewport = layout.compactViewport
  local contactsPane = layout.contactsPane
  local contentPane = layout.contentPane
  local duration = options.theme.LAYOUT.COMPACT_SLIDE_SECONDS
  local isCovered = options.isCovered

  local target = layout.compactProgress or 0
  local from = target
  local onDone = nil
  local sliding = false

  local function place(progress)
    layout.compactProgress = progress
    CompactViewport.Place(layout)
  end

  local function settle()
    if isCovered() or sliding then
      return
    end
    contactsPane:SetShown(target == 0)
    contentPane:SetShown(target == 1)
  end

  local function stopTicking()
    sliding = false
    GlideClock.Stop(viewport)
    if viewport.SetClipsChildren then
      viewport:SetClipsChildren(false)
    end
  end

  local function finishNow()
    if not sliding then
      return
    end
    stopTicking()
    place(target)
    settle()
    local done = onDone
    onDone = nil
    if done then
      done()
    end
  end

  local function step(_t, p)
    place(from + (target - from) * p)
  end

  local function snapTo(nextTarget)
    onDone = nil
    stopTicking()
    target = nextTarget
    place(target)
    settle()
  end

  -- done runs once the strip rests at nextTarget; a newer slide or snap drops it.
  local function animateTo(nextTarget, done)
    if not viewport.SetClipsChildren then
      snapTo(nextTarget)
      if done then
        done()
      end
      return
    end
    from = layout.compactProgress or 0
    target = nextTarget
    onDone = done
    sliding = true
    contactsPane:Show()
    contentPane:Show()
    viewport:SetClipsChildren(true)
    GlideClock.Run(viewport, duration, step, finishNow)
  end

  return {
    snapTo = snapTo,
    animateTo = animateTo,
    finishNow = finishNow,
    settle = settle,
  }
end

ns.MessengerWindowCompactSlide = CompactSlide

return CompactSlide

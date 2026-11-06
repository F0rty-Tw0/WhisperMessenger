local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PhoneViewport = ns.MessengerWindowLayoutPhoneViewport or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.PhoneViewport")

-- Moves the phone layout's strip between the list (0) and the chat (1).
-- Clipping runs only during a slide, and at rest the off-screen pane hides:
-- pop-ups inside the panes are never cut off, and nothing unseen takes clicks.
local PhoneSlide = {}

local function easeOut(t)
  local inverse = 1 - t
  return 1 - inverse * inverse * inverse
end

-- options: layout, theme, isCovered() (settings or a panel hide the panes).
function PhoneSlide.Create(options)
  local layout = options.layout
  local viewport = layout.phoneViewport
  local contactsPane = layout.contactsPane
  local contentPane = layout.contentPane
  local duration = options.theme.LAYOUT.PHONE_SLIDE_SECONDS
  local isCovered = options.isCovered

  local target = layout.phoneProgress or 0
  local from = target
  local elapsed = 0
  local onDone = nil
  local sliding = false

  local function place(progress)
    layout.phoneProgress = progress
    PhoneViewport.Place(layout)
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
    viewport:SetScript("OnUpdate", nil)
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

  local function tick(_self, delta)
    elapsed = elapsed + delta
    if elapsed >= duration then
      finishNow()
      return
    end
    place(from + (target - from) * easeOut(elapsed / duration))
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
    from = layout.phoneProgress or 0
    target = nextTarget
    elapsed = 0
    onDone = done
    sliding = true
    contactsPane:Show()
    contentPane:Show()
    viewport:SetClipsChildren(true)
    viewport:SetScript("OnUpdate", tick)
  end

  return {
    snapTo = snapTo,
    animateTo = animateTo,
    finishNow = finishNow,
    settle = settle,
  }
end

ns.MessengerWindowPhoneSlide = PhoneSlide

return PhoneSlide

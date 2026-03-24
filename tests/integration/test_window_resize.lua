local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  local positionChanged = nil
  local window = MessengerWindow.Create(factory, {
    contacts = {},
    onPositionChanged = function(state)
      positionChanged = state
    end,
  })

  -- Resize grip should exist and be a frame (not just a texture)
  assert(window.resizeGrip ~= nil, "expected a resize grip")
  assert(window.resizeGrip.mouseEnabled == true, "expected resize grip to accept mouse input")

  -- Mousedown on grip should start sizing the main frame
  assert(type(window.resizeGrip.scripts.OnMouseDown) == "function", "expected OnMouseDown on resize grip")
  window.resizeGrip.scripts.OnMouseDown(window.resizeGrip, "LeftButton")
  assert(window.frame.sizingAnchor == "BOTTOMRIGHT", "expected frame to start sizing from BOTTOMRIGHT")

  -- Mouseup should stop sizing and persist
  assert(type(window.resizeGrip.scripts.OnMouseUp) == "function", "expected OnMouseUp on resize grip")
  window.resizeGrip.scripts.OnMouseUp(window.resizeGrip, "LeftButton")
  assert(window.frame.sizing == false, "expected frame to stop sizing")
  assert(positionChanged ~= nil, "expected onPositionChanged to fire after resize")

  -- Simulate a resize: change frame size and fire OnSizeChanged
  local newWidth = 1100
  local newHeight = 700
  window.frame:SetSize(newWidth, newHeight)
  assert(type(window.frame.scripts.OnSizeChanged) == "function", "expected OnSizeChanged handler")
  window.frame.scripts.OnSizeChanged(window.frame, newWidth, newHeight)

  -- Contacts pane height should update
  local expectedContactsH = newHeight - Theme.TOP_BAR_HEIGHT
  assert(
    window.contactsPane.height == expectedContactsH,
    "expected contacts height " .. expectedContactsH .. " but got " .. tostring(window.contactsPane.height)
  )

  -- Contacts scroll view should update
  assert(
    window.contacts.scrollFrame.height == expectedContactsH,
    "expected contacts scrollFrame height "
      .. expectedContactsH
      .. " but got "
      .. tostring(window.contacts.scrollFrame.height)
  )

  -- Content pane should update
  local expectedContentW = newWidth - Theme.CONTACTS_WIDTH - Theme.DIVIDER_THICKNESS
  assert(
    window.contentPane.width == expectedContentW,
    "expected content width " .. expectedContentW .. " but got " .. tostring(window.contentPane.width)
  )
  assert(
    window.contentPane.height == expectedContactsH,
    "expected content height " .. expectedContactsH .. " but got " .. tostring(window.contentPane.height)
  )

  -- Thread pane should update
  local expectedThreadH = expectedContactsH - Theme.COMPOSER_HEIGHT - Theme.DIVIDER_THICKNESS
  assert(
    window.threadPane.width == expectedContentW,
    "expected thread width " .. expectedContentW .. " but got " .. tostring(window.threadPane.width)
  )
  assert(
    window.threadPane.height == expectedThreadH,
    "expected thread height " .. expectedThreadH .. " but got " .. tostring(window.threadPane.height)
  )

  -- Composer pane width should update
  assert(
    window.composerPane.width == expectedContentW,
    "expected composer width " .. expectedContentW .. " but got " .. tostring(window.composerPane.width)
  )

  -- Composer input and inputBg should scale with new width
  local buttonSize = 44
  local buttonGap = 8
  local expectedInputW = expectedContentW - 24 - buttonSize - buttonGap
  assert(
    window.composer.input.width == expectedInputW,
    "expected composer input width " .. expectedInputW .. " but got " .. tostring(window.composer.input.width)
  )

  -- Transcript scroll view should resize with the thread pane
  local HEADER_HEIGHT = 56
  local TRANSCRIPT_BOTTOM_GAP = 56
  local expectedTranscriptW = expectedContentW - 32
  local expectedTranscriptH = expectedThreadH - HEADER_HEIGHT - TRANSCRIPT_BOTTOM_GAP
  assert(
    window.conversation.transcript.scrollFrame.width == expectedTranscriptW,
    "expected transcript width "
      .. expectedTranscriptW
      .. " but got "
      .. tostring(window.conversation.transcript.scrollFrame.width)
  )
  assert(
    window.conversation.transcript.scrollFrame.height == expectedTranscriptH,
    "expected transcript height "
      .. expectedTranscriptH
      .. " but got "
      .. tostring(window.conversation.transcript.scrollFrame.height)
  )

  _G.UIParent = savedUIParent
end

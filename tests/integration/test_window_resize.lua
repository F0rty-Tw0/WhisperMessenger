local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)

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
  -- Contacts-only resize handle should clamp to min width and persist contactsWidth.
  assert(window.contactsResizeHandle ~= nil, "expected contacts resize handle")
  assert(window.contactsResizeHandle.mouseEnabled == true, "expected contacts resize handle to accept mouse input")
  assert(
    type(window.contactsResizeHandle.scripts.OnMouseDown) == "function",
    "expected contacts resize handle OnMouseDown script"
  )
  assert(
    type(window.contactsResizeHandle.scripts.OnMouseUp) == "function",
    "expected contacts resize handle OnMouseUp script"
  )

  assert(window.contactsResizeHandle.hoverBg ~= nil, "expected contacts resize hover background")
  assert(window.contactsResizeHandle.outline ~= nil, "expected contacts resize outline textures")
  assert(window.contactsResizeHandle.outline.left ~= nil, "expected left outline texture")

  window.contactsResizeHandle.scripts.OnEnter(window.contactsResizeHandle)
  assert(
    window.contactsResizeHandle.hoverBg.color ~= nil and window.contactsResizeHandle.hoverBg.color[4] > 0,
    "expected resize handle hover background alpha to increase on hover"
  )
  assert(window.contactsResizeHandle.outline.left.shown == true, "expected resize outline to show on hover")

  window.contactsResizeHandle.scripts.OnLeave(window.contactsResizeHandle)
  assert(
    window.contactsResizeHandle.hoverBg.color ~= nil and window.contactsResizeHandle.hoverBg.color[4] == 0,
    "expected resize handle hover background to clear on leave"
  )
  assert(window.contactsResizeHandle.outline.left.shown == false, "expected resize outline to hide on leave")

  local originalGetCursorPosition = _G.GetCursorPosition
  _G.GetCursorPosition = function()
    return 240
  end
  window.frame.GetLeft = function()
    return 100
  end
  window.frame.GetEffectiveScale = function()
    return 1
  end

  window.contactsResizeHandle.scripts.OnMouseDown(window.contactsResizeHandle, "LeftButton")
  window.frame.scripts.OnUpdate(window.frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)

  local expectedMinContactsW = Theme.LAYOUT.CONTACTS_MIN_WIDTH
  local expectedNarrowContentW = newWidth - expectedMinContactsW - Theme.DIVIDER_THICKNESS
  assert(
    window.contactsPane.width == expectedMinContactsW,
    "expected contacts pane width to clamp to min "
      .. tostring(expectedMinContactsW)
      .. " but got "
      .. tostring(window.contactsPane.width)
  )
  assert(
    window.contentPane.width == expectedNarrowContentW,
    "expected content width to follow contacts resize to "
      .. tostring(expectedNarrowContentW)
      .. " but got "
      .. tostring(window.contentPane.width)
  )

  window.contactsResizeHandle.scripts.OnMouseUp(window.contactsResizeHandle, "LeftButton")
  assert(positionChanged ~= nil, "expected contacts resize to persist window state")
  assert(
    positionChanged.contactsWidth == expectedMinContactsW,
    "expected persisted contacts width "
      .. tostring(expectedMinContactsW)
      .. " but got "
      .. tostring(positionChanged.contactsWidth)
  )

  _G.GetCursorPosition = originalGetCursorPosition

  -- Oversized saved state and oversize resize attempts should clamp to the screen bounds
  local clampedState = nil
  local oversizedWindow = MessengerWindow.Create(factory, {
    contacts = {},
    state = {
      anchorPoint = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = 0,
      width = 2000,
      height = 1200,
    },
    onPositionChanged = function(state)
      clampedState = state
    end,
  })

  assert(
    oversizedWindow.frame.width <= _G.UIParent:GetWidth(),
    "expected oversized saved width to clamp within UIParent width, got " .. tostring(oversizedWindow.frame.width)
  )
  assert(
    oversizedWindow.frame.height <= _G.UIParent:GetHeight(),
    "expected oversized saved height to clamp within UIParent height, got " .. tostring(oversizedWindow.frame.height)
  )
  assert(
    oversizedWindow.frame.resizeBounds[3] == _G.UIParent:GetWidth(),
    "expected native resize max width to track UIParent width, got " .. tostring(oversizedWindow.frame.resizeBounds[3])
  )
  assert(
    oversizedWindow.frame.resizeBounds[4] == _G.UIParent:GetHeight(),
    "expected native resize max height to track UIParent height, got "
      .. tostring(oversizedWindow.frame.resizeBounds[4])
  )

  local unsizedParent = factory.CreateFrame("Frame", "UnsizedParent", nil)
  local recoveredWindow = MessengerWindow.Create(factory, {
    parent = unsizedParent,
    contacts = {},
    state = {
      anchorPoint = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = 0,
      width = 2000,
      height = 1200,
    },
  })

  assert(
    recoveredWindow.frame.width <= Theme.WINDOW_WIDTH,
    "expected unsized parent fallback to recover width to a sane default, got " .. tostring(recoveredWindow.frame.width)
  )
  assert(
    recoveredWindow.frame.height <= Theme.WINDOW_HEIGHT,
    "expected unsized parent fallback to recover height to a sane default, got "
      .. tostring(recoveredWindow.frame.height)
  )

  oversizedWindow.resizeGrip.scripts.OnMouseDown(oversizedWindow.resizeGrip, "LeftButton")
  oversizedWindow.frame:SetSize(2400, 1600)
  oversizedWindow.resizeGrip.scripts.OnMouseUp(oversizedWindow.resizeGrip, "LeftButton")

  assert(clampedState ~= nil, "expected oversized resize attempt to persist a state")
  assert(
    clampedState.width <= _G.UIParent:GetWidth(),
    "expected persisted width to clamp within UIParent width, got " .. tostring(clampedState.width)
  )
  assert(
    clampedState.height <= _G.UIParent:GetHeight(),
    "expected persisted height to clamp within UIParent height, got " .. tostring(clampedState.height)
  )
  _G.UIParent = savedUIParent
end

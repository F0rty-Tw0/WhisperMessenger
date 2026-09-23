local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsResize = {}

function ContactsResize.New(options)
  local contactsResizeHandle = options.contactsResizeHandle
  local frameTheme = options.frameTheme

  local resizing = false

  -- Keep the bare hairline and fade a thin line in over it: neutral on
  -- hover, accent while dragging.
  local function setHighlight(isActive)
    local lineFade = contactsResizeHandle and contactsResizeHandle.lineFade
    if not lineFade then
      return
    end
    if isActive then
      local colors = frameTheme.COLORS or {}
      local lineColor = resizing and colors.accent_primary or colors.contacts_divider_hover
      if lineColor then
        lineFade.paintColor(lineColor)
      end
    end
    lineFade.set(isActive)
  end

  local function updateFromCursor()
    if not resizing then
      return
    end

    local cursorX = options.getCursorX()
    local frameLeft = options.getFrameLeft()
    if type(cursorX) ~= "number" or type(frameLeft) ~= "number" then
      return
    end

    options.relayoutWindow(options.frameWidth(), options.frameHeight(), cursorX - frameLeft, true)
  end

  local function stop(button)
    if button ~= "LeftButton" or not resizing then
      return
    end

    -- Commit the exact release position BEFORE clearing the flag —
    -- updateFromCursor early-returns once resizing is false.
    updateFromCursor()
    resizing = false
    setHighlight(false)

    local nextState = options.buildState(options.frame)
    if options.onPositionChanged then
      options.onPositionChanged(nextState)
    end
  end

  local function start(button)
    if button ~= "LeftButton" then
      return
    end

    resizing = true
    setHighlight(true)
    updateFromCursor()
  end

  local function reset()
    resizing = false
    setHighlight(false)
  end

  return {
    start = start,
    stop = stop,
    updateFromCursor = updateFromCursor,
    reset = reset,
    setHighlight = setHighlight,
    isResizing = function()
      return resizing
    end,
  }
end

ns.MessengerWindowWindowScriptsFrameContactsResize = ContactsResize

return ContactsResize

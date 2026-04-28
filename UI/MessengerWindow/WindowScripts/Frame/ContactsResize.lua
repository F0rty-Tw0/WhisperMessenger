local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsResize = {}

function ContactsResize.New(options)
  local contactsResizeHandle = options.contactsResizeHandle
  local frameTheme = options.frameTheme

  local resizing = false

  local function setHighlight(isActive)
    if not contactsResizeHandle then
      return
    end

    local divider = options.layout and options.layout.contactsDivider or nil
    local dividerColor = frameTheme.COLORS and (frameTheme.COLORS.contacts_divider or frameTheme.COLORS.divider) or { 0.20, 0.22, 0.28, 1 }
    local dividerHoverColor = frameTheme.COLORS and (frameTheme.COLORS.contacts_divider_hover or frameTheme.COLORS.accent_primary)
      or { 0.24, 0.32, 0.54, 0.95 }
    local hoverFillColor = frameTheme.COLORS and (frameTheme.COLORS.contacts_resize_hover_fill or frameTheme.COLORS.bg_contact_hover)
      or { 0.24, 0.32, 0.54, 0.22 }
    local outlineColor = frameTheme.COLORS and (frameTheme.COLORS.contacts_resize_outline or dividerHoverColor) or { 0.24, 0.32, 0.54, 0.62 }

    if divider and divider.SetColorTexture then
      if isActive then
        divider:SetColorTexture(dividerHoverColor[1], dividerHoverColor[2], dividerHoverColor[3], dividerHoverColor[4] or 1)
      else
        divider:SetColorTexture(dividerColor[1], dividerColor[2], dividerColor[3], dividerColor[4] or 1)
      end
    end

    if contactsResizeHandle.hoverBg and contactsResizeHandle.hoverBg.SetColorTexture then
      if isActive then
        contactsResizeHandle.hoverBg:SetColorTexture(hoverFillColor[1], hoverFillColor[2], hoverFillColor[3], hoverFillColor[4] or 1)
      else
        contactsResizeHandle.hoverBg:SetColorTexture(0, 0, 0, 0)
      end
    end

    local outline = contactsResizeHandle.outline
    if outline then
      for _, edge in pairs(outline) do
        if edge and edge.SetColorTexture then
          if isActive then
            edge:SetColorTexture(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 1)
            if edge.Show then
              edge:Show()
            end
          else
            edge:SetColorTexture(0, 0, 0, 0)
            if edge.Hide then
              edge:Hide()
            end
          end
        end
      end
    end
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

    resizing = false
    updateFromCursor()
    setHighlight(false)

    local nextState = options.buildState(options.frame)
    options.trace("contacts resize stop", nextState.contactsWidth)
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
    options.trace("contacts resize start")
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

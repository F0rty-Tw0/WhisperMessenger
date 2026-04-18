local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local WindowResize = ns.MessengerWindowWindowScriptsFrameWindowResize
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.WindowResize")
local ContactsResize = ns.MessengerWindowWindowScriptsFrameContactsResize
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.ContactsResize")
local ScriptBindings = ns.MessengerWindowWindowScriptsFrameScriptBindings
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.ScriptBindings")

local Frame = {}

local RESIZE_PREVIEW_FILL_ALPHA = 0.20
local RESIZE_PREVIEW_BORDER_ALPHA = 0.85
local RESIZE_DRAG_FRAME_ALPHA = 0.08

-- Wire OnShow, OnHide, OnEnter, OnLeave, OnUpdate, OnSizeChanged,
-- OnDragStart, OnDragStop on the main frame, plus OnMouseDown/OnMouseUp
-- on both resize handles.
--
-- refs:
--   frame, resizeGrip, contactsResizeHandle
--
-- options:
--   refreshWindowAlpha, layout, composer, contactsController, conversation,
--   buildState, trace, onPositionChanged, Theme
--   relayout (optional), refreshContactsLayout (optional),
--   getCursorX/getCursorY (optional), getFrameLeft/getFrameTop (optional)
function Frame.WireFrame(refs, options)
  local frame = refs.frame
  local resizeGrip = refs.resizeGrip
  local contactsResizeHandle = refs.contactsResizeHandle

  local frameTheme = options.Theme or Theme
  local suppressSizeChangedRelayout = false

  local function relayoutWindow(w, h, requestedContactsWidth, refreshContactsLayout)
    if options.relayout then
      options.relayout(w, h, requestedContactsWidth, refreshContactsLayout)
      return
    end

    if options.layout and options.layout.contactsPane then
      LayoutBuilder.Relayout(options.layout, w, h, requestedContactsWidth)
    end

    local contentW = w - frameTheme.CONTACTS_WIDTH - frameTheme.DIVIDER_THICKNESS
    if options.composer and options.composer.relayout then
      options.composer.relayout(contentW)
    end
    local contactsH = h - frameTheme.TOP_BAR_HEIGHT
    if options.contactsController and options.contactsController.fillViewport then
      options.contactsController.fillViewport(contactsH)
    end
    local threadH = contactsH - frameTheme.COMPOSER_HEIGHT - frameTheme.DIVIDER_THICKNESS
    if options.conversation then
      ConversationPane.Relayout(options.conversation, contentW, threadH)
    end
    if refreshContactsLayout and options.refreshContactsLayout then
      options.refreshContactsLayout()
    end
  end

  local function frameWidth()
    if frame and frame.GetWidth then
      return frame:GetWidth()
    end
    return frameTheme.WINDOW_WIDTH
  end

  local function frameHeight()
    if frame and frame.GetHeight then
      return frame:GetHeight()
    end
    return frameTheme.WINDOW_HEIGHT
  end

  local function cursorPosition()
    if type(_G.GetCursorPosition) ~= "function" then
      return nil, nil
    end

    local cursorX, cursorY = _G.GetCursorPosition()
    local scale = 1
    if frame and frame.GetEffectiveScale then
      local effectiveScale = frame:GetEffectiveScale()
      if type(effectiveScale) == "number" and effectiveScale > 0 then
        scale = effectiveScale
      end
    end
    local scaledCursorX = type(cursorX) == "number" and (cursorX / scale) or nil
    local scaledCursorY = type(cursorY) == "number" and (cursorY / scale) or nil
    return scaledCursorX, scaledCursorY
  end

  local function getCursorX()
    if options.getCursorX then
      return options.getCursorX()
    end
    local cursorX = cursorPosition()
    return cursorX
  end

  local function getFrameLeft()
    if options.getFrameLeft then
      return options.getFrameLeft()
    end
    if frame and frame.GetLeft then
      return frame:GetLeft()
    end
    return nil
  end

  local function getCursorY()
    if options.getCursorY then
      return options.getCursorY()
    end
    local _, cursorY = cursorPosition()
    return cursorY
  end

  local function getFrameTop()
    if options.getFrameTop then
      return options.getFrameTop()
    end
    if frame and frame.GetTop then
      return frame:GetTop()
    end
    return nil
  end

  local function getFrameParent()
    if options.getFrameParent then
      return options.getFrameParent()
    end
    if frame and frame.parent then
      return frame.parent
    end
    if _G.UIParent then
      return _G.UIParent
    end
    return nil
  end

  local function resolveResizeBounds()
    local themeLayout = frameTheme.LAYOUT or {}
    local minWidth = themeLayout.WINDOW_MIN_WIDTH or frameTheme.WINDOW_MIN_WIDTH or 640
    local minHeight = themeLayout.WINDOW_MIN_HEIGHT or frameTheme.WINDOW_MIN_HEIGHT or 420
    local maxWidth, maxHeight = nil, nil

    if frame and type(frame.resizeBounds) == "table" then
      minWidth = frame.resizeBounds[1] or minWidth
      minHeight = frame.resizeBounds[2] or minHeight
      maxWidth = frame.resizeBounds[3]
      maxHeight = frame.resizeBounds[4]
    elseif frame and type(frame.minResize) == "table" then
      minWidth = frame.minResize[1] or minWidth
      minHeight = frame.minResize[2] or minHeight
    end

    return minWidth, minHeight, maxWidth, maxHeight
  end

  local function clampWindowSize(width, height)
    local minWidth, minHeight, maxWidth, maxHeight = resolveResizeBounds()
    local clampedWidth = math.max(minWidth, width or minWidth)
    local clampedHeight = math.max(minHeight, height or minHeight)
    if type(maxWidth) == "number" and maxWidth > 0 then
      clampedWidth = math.min(clampedWidth, maxWidth)
    end
    if type(maxHeight) == "number" and maxHeight > 0 then
      clampedHeight = math.min(clampedHeight, maxHeight)
    end
    return clampedWidth, clampedHeight
  end

  local function applyCommittedWindowSize(nextWidth, nextHeight)
    local stableLeft = getFrameLeft()
    local stableTop = getFrameTop()

    suppressSizeChangedRelayout = true
    if frame and frame.SetSize then
      frame:SetSize(nextWidth, nextHeight)
    end
    if
      frame
      and frame.ClearAllPoints
      and frame.SetPoint
      and type(stableLeft) == "number"
      and type(stableTop) == "number"
    then
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", getFrameParent(), "BOTTOMLEFT", stableLeft, stableTop)
    end
    suppressSizeChangedRelayout = false
    relayoutWindow(nextWidth, nextHeight, nil, false)
  end

  local windowResize = WindowResize.New({
    frame = frame,
    resizeGrip = resizeGrip,
    frameTheme = frameTheme,
    previewFillAlpha = RESIZE_PREVIEW_FILL_ALPHA,
    previewBorderAlpha = RESIZE_PREVIEW_BORDER_ALPHA,
    dragFrameAlpha = RESIZE_DRAG_FRAME_ALPHA,
    getCursorX = getCursorX,
    getCursorY = getCursorY,
    getFrameLeft = getFrameLeft,
    getFrameTop = getFrameTop,
    getFrameParent = getFrameParent,
    frameWidth = frameWidth,
    frameHeight = frameHeight,
    clampWindowSize = clampWindowSize,
    applyCommittedSize = applyCommittedWindowSize,
    buildState = options.buildState,
    trace = options.trace,
    onPositionChanged = options.onPositionChanged,
  })

  local contactsResize = ContactsResize.New({
    frame = frame,
    contactsResizeHandle = contactsResizeHandle,
    frameTheme = frameTheme,
    layout = options.layout,
    getCursorX = getCursorX,
    getFrameLeft = getFrameLeft,
    frameWidth = frameWidth,
    frameHeight = frameHeight,
    relayoutWindow = relayoutWindow,
    buildState = options.buildState,
    trace = options.trace,
    onPositionChanged = options.onPositionChanged,
  })

  ScriptBindings.Bind({
    frame = frame,
    resizeGrip = resizeGrip,
    contactsResizeHandle = contactsResizeHandle,
    frameTheme = frameTheme,
    windowResize = windowResize,
    contactsResize = contactsResize,
    relayoutWindow = relayoutWindow,
    isSuppressSizeChangedRelayout = function()
      return suppressSizeChangedRelayout
    end,
    refreshWindowAlpha = options.refreshWindowAlpha,
    composerInput = options.composerInput,
    getAutoFocusChatInput = options.getAutoFocusChatInput,
    buildState = options.buildState,
    onPositionChanged = options.onPositionChanged,
    trace = options.trace,
  })
end

ns.MessengerWindowWindowScriptsFrame = Frame

return Frame

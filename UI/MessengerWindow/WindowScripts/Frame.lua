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
local unpackValues = table.unpack or _G.unpack

local Frame = {}

local RESIZE_PREVIEW_FILL_ALPHA = 0.20
local RESIZE_PREVIEW_BORDER_ALPHA = 0.85
local RESIZE_DRAG_FRAME_ALPHA = 0.08

local function isPositiveFiniteNumber(value)
  return type(value) == "number" and value == value and value > 0 and value < math.huge
end

local function effectiveScaleOrOne(target)
  if target and type(target.GetEffectiveScale) == "function" then
    local scale = target:GetEffectiveScale()
    if isPositiveFiniteNumber(scale) then
      return scale
    end
  end
  return 1
end

-- Wire OnShow, OnHide, OnEnter, OnLeave, OnUpdate, OnSizeChanged,
-- OnDragStart, OnDragStop on the main frame, plus OnMouseDown/OnMouseUp
-- on both resize handles.
--
-- refs:
--   frame, resizeGrip, contactsResizeHandle
--
-- options:
--   refreshWindowAlpha, layout, composer, contactsController, conversation,
--   buildState, onPositionChanged, Theme
--   relayout (optional), refreshContactsLayout (optional),
--   getCursorX/getCursorY (optional), getFrameLeft/getFrameTop (optional)
function Frame.WireFrame(refs, options)
  local frame = refs.frame
  local resizeGrip = refs.resizeGrip
  local contactsResizeHandle = refs.contactsResizeHandle

  local frameTheme = options.Theme or Theme
  local suppressSizeChangedRelayout = false
  local function pack(...)
    return { n = select("#", ...), ... }
  end

  local function withSizeChangedRelayoutSuppressed(callback)
    local wasSuppressed = suppressSizeChangedRelayout
    suppressSizeChangedRelayout = true
    local results = pack(pcall(callback))
    suppressSizeChangedRelayout = wasSuppressed
    if not results[1] then
      error(results[2], 0)
    end
    return unpackValues(results, 2, results.n)
  end

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
    if frame and type(frame.GetParent) == "function" then
      local parent = frame:GetParent()
      if parent ~= nil then
        return parent
      end
    end
    return _G.UIParent
  end

  local function resolveResizeBounds()
    local themeLayout = frameTheme.LAYOUT or {}
    local minWidth = themeLayout.WINDOW_MIN_WIDTH or frameTheme.WINDOW_MIN_WIDTH or 640
    local minHeight = themeLayout.WINDOW_MIN_HEIGHT or frameTheme.WINDOW_MIN_HEIGHT or 420
    local maxWidth, maxHeight = nil, nil

    if frame and type(frame.GetResizeBounds) == "function" then
      local nativeMinWidth, nativeMinHeight, nativeMaxWidth, nativeMaxHeight = frame:GetResizeBounds()
      if isPositiveFiniteNumber(nativeMinWidth) then
        minWidth = nativeMinWidth
      end
      if isPositiveFiniteNumber(nativeMinHeight) then
        minHeight = nativeMinHeight
      end
      if isPositiveFiniteNumber(nativeMaxWidth) and nativeMaxWidth >= minWidth then
        maxWidth = nativeMaxWidth
      end
      if isPositiveFiniteNumber(nativeMaxHeight) and nativeMaxHeight >= minHeight then
        maxHeight = nativeMaxHeight
      end
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
    local parent = getFrameParent()
    local parentLeft = 0
    local parentBottom = 0
    if parent and type(parent.GetLeft) == "function" then
      local left = parent:GetLeft()
      if type(left) == "number" then
        parentLeft = left
      end
    end
    if parent and type(parent.GetBottom) == "function" then
      local bottom = parent:GetBottom()
      if type(bottom) == "number" then
        parentBottom = bottom
      end
    end
    local frameScale = effectiveScaleOrOne(frame)
    local parentScale = effectiveScaleOrOne(parent)

    withSizeChangedRelayoutSuppressed(function()
      if frame and frame.SetSize then
        frame:SetSize(nextWidth, nextHeight)
      end
      if frame and frame.ClearAllPoints and frame.SetPoint and type(stableLeft) == "number" and type(stableTop) == "number" then
        local commitX = stableLeft - parentLeft * parentScale / frameScale
        local commitY = stableTop - parentBottom * parentScale / frameScale
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", commitX, commitY)
      end
    end)
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
  })
  return {
    withSizeChangedRelayoutSuppressed = withSizeChangedRelayoutSuppressed,
  }
end

ns.MessengerWindowWindowScriptsFrame = Frame

return Frame

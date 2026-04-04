local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WindowResize = {}

function WindowResize.New(options)
  local frame = options.frame
  local resizeGrip = options.resizeGrip
  local frameTheme = options.frameTheme

  local resizing = false
  local pendingWidth = nil
  local pendingHeight = nil
  local preResizeAlpha = nil

  local windowResizePreviewHost = options.getFrameParent() or frame
  local windowResizePreview = nil
  if windowResizePreviewHost and windowResizePreviewHost.CreateTexture then
    local dividerColor = frameTheme.COLORS and frameTheme.COLORS.divider or { 0.20, 0.22, 0.28, 1 }
    local fillColor = frameTheme.COLORS and frameTheme.COLORS.bg_secondary or { 0.10, 0.10, 0.14, 1 }

    windowResizePreview = {
      bg = windowResizePreviewHost:CreateTexture(nil, "OVERLAY"),
      top = windowResizePreviewHost:CreateTexture(nil, "OVERLAY"),
      bottom = windowResizePreviewHost:CreateTexture(nil, "OVERLAY"),
      left = windowResizePreviewHost:CreateTexture(nil, "OVERLAY"),
      right = windowResizePreviewHost:CreateTexture(nil, "OVERLAY"),
    }

    windowResizePreview.bg:SetColorTexture(fillColor[1], fillColor[2], fillColor[3], options.previewFillAlpha)
    windowResizePreview.top:SetColorTexture(
      dividerColor[1],
      dividerColor[2],
      dividerColor[3],
      options.previewBorderAlpha
    )
    windowResizePreview.bottom:SetColorTexture(
      dividerColor[1],
      dividerColor[2],
      dividerColor[3],
      options.previewBorderAlpha
    )
    windowResizePreview.left:SetColorTexture(
      dividerColor[1],
      dividerColor[2],
      dividerColor[3],
      options.previewBorderAlpha
    )
    windowResizePreview.right:SetColorTexture(
      dividerColor[1],
      dividerColor[2],
      dividerColor[3],
      options.previewBorderAlpha
    )

    if resizeGrip then
      resizeGrip.preview = windowResizePreview
    end
    for _, texture in pairs(windowResizePreview) do
      if texture.Hide then
        texture:Hide()
      end
    end
  end

  local function setPreviewShown(isShown)
    if not windowResizePreview then
      return
    end

    for _, texture in pairs(windowResizePreview) do
      if isShown then
        if texture.Show then
          texture:Show()
        end
      elseif texture.Hide then
        texture:Hide()
      end
    end
  end

  local function updatePreview(width, height)
    if not windowResizePreview then
      return
    end

    local previewLeft = options.getFrameLeft()
    local previewTop = options.getFrameTop()
    if type(previewLeft) ~= "number" or type(previewTop) ~= "number" then
      return
    end

    local previewWidth = math.max(1, width or options.frameWidth())
    local previewHeight = math.max(1, height or options.frameHeight())

    if windowResizePreview.bg.ClearAllPoints then
      windowResizePreview.bg:ClearAllPoints()
    end
    windowResizePreview.bg:SetPoint("TOPLEFT", windowResizePreviewHost, "BOTTOMLEFT", previewLeft, previewTop)
    windowResizePreview.bg:SetSize(previewWidth, previewHeight)

    if windowResizePreview.top.ClearAllPoints then
      windowResizePreview.top:ClearAllPoints()
    end
    windowResizePreview.top:SetPoint("TOPLEFT", windowResizePreviewHost, "BOTTOMLEFT", previewLeft, previewTop)
    windowResizePreview.top:SetPoint(
      "TOPRIGHT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft + previewWidth,
      previewTop
    )
    windowResizePreview.top:SetHeight(1)

    if windowResizePreview.bottom.ClearAllPoints then
      windowResizePreview.bottom:ClearAllPoints()
    end
    windowResizePreview.bottom:SetPoint(
      "BOTTOMLEFT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft,
      previewTop - previewHeight
    )
    windowResizePreview.bottom:SetPoint(
      "BOTTOMRIGHT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft + previewWidth,
      previewTop - previewHeight
    )
    windowResizePreview.bottom:SetHeight(1)

    if windowResizePreview.left.ClearAllPoints then
      windowResizePreview.left:ClearAllPoints()
    end
    windowResizePreview.left:SetPoint("TOPLEFT", windowResizePreviewHost, "BOTTOMLEFT", previewLeft, previewTop)
    windowResizePreview.left:SetPoint(
      "BOTTOMLEFT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft,
      previewTop - previewHeight
    )
    windowResizePreview.left:SetWidth(1)

    if windowResizePreview.right.ClearAllPoints then
      windowResizePreview.right:ClearAllPoints()
    end
    windowResizePreview.right:SetPoint(
      "TOPRIGHT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft + previewWidth,
      previewTop
    )
    windowResizePreview.right:SetPoint(
      "BOTTOMRIGHT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft + previewWidth,
      previewTop - previewHeight
    )
    windowResizePreview.right:SetWidth(1)

    setPreviewShown(true)
  end

  local function updateFromCursor()
    if not resizing then
      return
    end

    local cursorX = options.getCursorX()
    local cursorY = options.getCursorY()
    local frameLeft = options.getFrameLeft()
    local frameTop = options.getFrameTop()
    if
      type(cursorX) ~= "number"
      or type(cursorY) ~= "number"
      or type(frameLeft) ~= "number"
      or type(frameTop) ~= "number"
    then
      return
    end

    local nextWidth, nextHeight = options.clampWindowSize(cursorX - frameLeft, frameTop - cursorY)
    pendingWidth = nextWidth
    pendingHeight = nextHeight
    updatePreview(nextWidth, nextHeight)
  end

  local function stop(button)
    if button ~= "LeftButton" or not resizing then
      return
    end

    resizing = false
    setPreviewShown(false)
    if frame and frame.SetAlpha then
      frame:SetAlpha(preResizeAlpha or 1)
      preResizeAlpha = nil
    end

    local nextWidth, nextHeight =
      options.clampWindowSize(pendingWidth or options.frameWidth(), pendingHeight or options.frameHeight())
    pendingWidth = nil
    pendingHeight = nil

    options.applyCommittedSize(nextWidth, nextHeight)

    local nextState = options.buildState(frame)
    options.trace("window resize stop", nextState.width, nextState.height)
    if options.onPositionChanged then
      options.onPositionChanged(nextState)
    end
  end

  local function start(button)
    if button ~= "LeftButton" then
      return
    end

    resizing = true
    pendingWidth, pendingHeight = options.clampWindowSize(options.frameWidth(), options.frameHeight())
    if frame and frame.GetAlpha then
      preResizeAlpha = frame:GetAlpha()
    else
      preResizeAlpha = 1
    end
    if frame and frame.SetAlpha then
      frame:SetAlpha(options.dragFrameAlpha)
    end

    updateFromCursor()
    updatePreview(pendingWidth, pendingHeight)
    options.trace("window resize start")
  end

  local function reset()
    resizing = false
    pendingWidth = nil
    pendingHeight = nil
    preResizeAlpha = nil
    setPreviewShown(false)
  end

  return {
    start = start,
    stop = stop,
    updateFromCursor = updateFromCursor,
    reset = reset,
    isResizing = function()
      return resizing
    end,
  }
end

ns.MessengerWindowWindowScriptsFrameWindowResize = WindowResize

return WindowResize

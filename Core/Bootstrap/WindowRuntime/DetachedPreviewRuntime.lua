local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconRuntime = ns.BootstrapWindowRuntimeIconRuntime or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")
local IncomingPreview = ns.ToggleIconIncomingPreview or require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local DEFAULT_SPOT_X = 0
local DEFAULT_SPOT_Y = -150
local DRAG_RELEASE_SECONDS = 0.5
local DRAG_CLICK_THRESHOLD = 4

local DetachedPreviewRuntime = {}

function DetachedPreviewRuntime.IsDetached(settings)
  return settings ~= nil and settings.widgetPreviewPosition == "detached"
end

function DetachedPreviewRuntime.ActiveSurface(settings, getDetached, getWidget)
  if DetachedPreviewRuntime.IsDetached(settings) then
    return getDetached()
  end
  return getWidget()
end

-- A card that floats free of the widget: a 1x1 holder anchored by its TOP to
-- the screen top, the card dragged by its body.
function DetachedPreviewRuntime.Create(options)
  local uiFactory = options.uiFactory
  local uiParent = options.uiParent
  local accountState = options.accountState
  local characterState = options.characterState
  local getWidgetIcon = options.getWidgetIcon
  local now = options.now or _G.GetTime

  local function settings()
    return accountState.settings or {}
  end

  local function isShared()
    return settings().shareWidgetPosition == true
  end

  local function readSpot()
    if not isShared() then
      return characterState.detachedPreview
    end
    if accountState.sharedDetachedPreview == nil then
      accountState.sharedDetachedPreview = TableUtils.copyState(characterState.detachedPreview)
    end
    return accountState.sharedDetachedPreview
  end

  local function saveSpot(spot)
    if isShared() then
      accountState.sharedDetachedPreview = spot
    else
      characterState.detachedPreview = spot
    end
  end

  local holder = uiFactory.CreateFrame("Frame", nil, uiParent)
  holder:SetSize(1, 1)
  holder:SetMovable(true)
  holder:SetClampedToScreen(true)
  holder:Show()

  local function anchorTop(x, y)
    holder:ClearAllPoints()
    holder:SetPoint("TOP", uiParent, "TOP", x, y)
  end

  local function applySavedSpot()
    local spot = readSpot()
    local x = tonumber(spot and spot.x) or DEFAULT_SPOT_X
    local y = tonumber(spot and spot.y) or DEFAULT_SPOT_Y
    anchorTop(x, y)
  end

  local dragging = false
  local releaseConsumed = false
  local draggedAt = nil
  local dragStartX = 0
  local dragStartY = 0

  local function holderMovedPastClick()
    local x = holder:GetCenter()
    local movedX = math.abs(x - dragStartX)
    local movedY = math.abs(holder:GetTop() - dragStartY)

    return movedX > DRAG_CLICK_THRESHOLD or movedY > DRAG_CLICK_THRESHOLD
  end

  local function shouldIgnoreMouseUp()
    if dragging then
      if not holderMovedPastClick() then
        return false
      end
      releaseConsumed = true
      return true
    end
    if draggedAt == nil then
      return false
    end
    local recent = now() - draggedAt <= DRAG_RELEASE_SECONDS
    draggedAt = nil
    return recent
  end

  local card = IncomingPreview.Create(uiFactory, holder, {
    getPreviewPosition = function()
      return "detached"
    end,
    getPreviewAutoDismissSeconds = function()
      return IconRuntime.ResolveAutoDismissSeconds(settings())
    end,
    onDismissPreview = function()
      options.acknowledgeLatestWidgetPreview(options.buildContacts())
      options.refreshWindow()
    end,
    onOpenPreview = options.onOpenPreview,
    quickReply = options.quickReply,
    shouldIgnoreMouseUp = shouldIgnoreMouseUp,
    onExternalChanged = function()
      local widget = getWidgetIcon()
      if widget and widget.refreshPulse then
        widget.refreshPulse()
      end
    end,
  })

  local function onDragStart()
    if settings().lockToggleIcon == true then
      return
    end
    dragging = true
    releaseConsumed = false
    dragStartX = holder:GetCenter()
    dragStartY = holder:GetTop()
    holder:StartMoving()
  end

  local function onDragStop()
    if not dragging then
      return
    end
    holder:StopMovingOrSizing()
    if not holderMovedPastClick() then
      applySavedSpot()
      releaseConsumed = false
      dragging = false
      return
    end
    local holderX = holder:GetCenter()
    local parentX = uiParent:GetCenter()
    local x = holderX - parentX
    local y = holder:GetTop() - uiParent:GetTop()
    anchorTop(x, y)
    saveSpot({ x = x, y = y })
    if not releaseConsumed then
      draggedAt = now()
    end
    releaseConsumed = false
    dragging = false
  end

  card.frame:RegisterForDrag("LeftButton")
  card.frame:SetScript("OnDragStart", onDragStart)
  card.frame:SetScript("OnDragStop", onDragStop)
  -- No mouse-up reaches a hidden card, so a drag it ended here must not leave
  -- a pending release to swallow the first click after it shows again.
  local function onHide()
    onDragStop()
    draggedAt = nil
  end

  if card.frame.HookScript then
    card.frame:HookScript("OnHide", onHide)
  end

  applySavedSpot()

  return {
    holder = holder,
    previewFrame = card.frame,
    setIncomingPreview = card.setIncomingPreview,
    setExternalPreview = card.setExternalPreview,
    isExternalPreviewShown = card.isExternalShown,
    openShownPreview = card.openShownPreview,
    refreshTheme = function()
      card.applyTheme(Theme)
    end,
    applySavedSpot = applySavedSpot,
  }
end

local function onPositionChanged(ctx, value)
  if value == "detached" then
    ctx.ensureSurface()
  end
  ctx.updateIconSurfaces()
end

local function onShareChanged(ctx, value)
  if value == true then
    local own = ctx.characterState.detachedPreview
    ctx.accountState.sharedDetachedPreview = own and TableUtils.copyState(own) or nil
  end
  local surface = ctx.getSurface()
  if surface then
    surface.applySavedSpot()
  end
end

local function onIconModeChanged(ctx)
  if DetachedPreviewRuntime.IsDetached(ctx.accountState.settings) then
    ctx.updateIconSurfaces()
  end
end

local SETTING_REACTIONS = {
  widgetPreviewPosition = onPositionChanged,
  shareWidgetPosition = onShareChanged,
  iconMode = onIconModeChanged,
}

-- ctx = { accountState, characterState, getSurface, ensureSurface, updateIconSurfaces }
function DetachedPreviewRuntime.OnSettingChanged(ctx, key, value)
  local react = SETTING_REACTIONS[key]
  if react then
    react(ctx, value)
  end
end

ns.BootstrapWindowRuntimeDetachedPreviewRuntime = DetachedPreviewRuntime

return DetachedPreviewRuntime

local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Badge = ns.Badge or require("WhisperMessenger.UI.Badge")
local CompetitiveIndicator = ns.CompetitiveIndicator or require("WhisperMessenger.UI.ToggleIcon.CompetitiveIndicator")
local IncomingPreview = ns.ToggleIconIncomingPreview or require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")
local PulseGlow = ns.ToggleIconPulseGlow or require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
local PulseState = ns.ToggleIconPulseState or require("WhisperMessenger.UI.ToggleIcon.PulseState")
local Desaturation = ns.ToggleIconDesaturation or require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local SquareLook = ns.ToggleIconSquareLook or require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local IconArt = ns.ToggleIconIconArt or require("WhisperMessenger.UI.ToggleIcon.IconArt")
local IconBorder = ns.ToggleIconIconBorder or require("WhisperMessenger.UI.ToggleIcon.IconBorder")
local LockGlyph = ns.ToggleIconLockGlyph or require("WhisperMessenger.UI.ToggleIcon.LockGlyph")
local IconTooltip = ns.ToggleIconIconTooltip or require("WhisperMessenger.UI.ToggleIcon.IconTooltip")
local IconScripts = ns.ToggleIconIconScripts or require("WhisperMessenger.UI.ToggleIcon.IconScripts")
local IconRide = ns.ToggleIconIconRide or require("WhisperMessenger.UI.ToggleIcon.IconRide")
local DockedLook = ns.ToggleIconDockedLook or require("WhisperMessenger.UI.ToggleIcon.DockedLook")
local IconTransparency = ns.ToggleIconIconTransparency or require("WhisperMessenger.UI.ToggleIcon.IconTransparency")

local UnreadSummary = ns.UnreadSummary or require("WhisperMessenger.UI.Shared.UnreadSummary")

local BADGE_LEVEL_OFFSET = 10 -- above the pulse glow (parent + 5)

local ToggleIcon = {}

function ToggleIcon.Create(factory, options)
  options = options or {}

  local parent = options.parent or _G.UIParent
  local state = options.state or {}
  local anchorPoint = state.anchorPoint or "CENTER"
  local relativePoint = state.relativePoint or anchorPoint
  local x = state.x or 0
  local y = state.y or 0

  local ICON_SIZE = options.iconSize or Theme.LAYOUT.ICON_SIZE

  local frame = factory.CreateFrame("Button", "WhisperMessengerToggleIcon", parent)
  frame:SetSize(ICON_SIZE, ICON_SIZE)
  frame:SetPoint(anchorPoint, parent, relativePoint, x, y)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  -- Float above action bars and bags, same as the minimap icon.
  if frame.SetFrameStrata then
    frame:SetFrameStrata("HIGH")
  end

  local art = IconArt.Create(frame, ICON_SIZE)
  local background = art.background
  local chatIcon = art.chatIcon
  -- The full ring keeps the rim's outer size and bubbles when the background goes.
  local border = IconBorder.Create(frame, {
    glyph = chatIcon,
    glyphRatio = IconArt.GLYPH_RATIO,
    withSquareFrame = true,
    ringScale = IconBorder.RIM_SCALE,
    ringGlyphRatio = IconArt.GLYPH_RATIO,
  })

  -- Glow pulse for unread messages (CraftScan-style looping animation)
  local pulseGlow = PulseGlow.Create(factory, frame, {
    theme = Theme,
    accent = Theme.COLORS.accent,
  })

  -- Riding the window the button wears the default circle; the saved look returns on landing.
  local docked = false
  local dockedLook = DockedLook.Wrap(options, function()
    return docked
  end)
  local squareLook = SquareLook.Create(frame, {
    background = background,
    glyph = chatIcon,
    roundBackground = IconArt.CIRCLE_TEX,
    getShowBackground = dockedLook.getIconBackground,
    getWidgetShape = dockedLook.getWidgetShape,
    getShowBorder = dockedLook.getIconBorder,
    getBorderThemed = dockedLook.getIconBorderThemed,
    border = border,
    pulse = pulseGlow,
  })

  -- Unread badge, outlined so it reads where it overlaps the circle's edge
  local badgeResult = Badge.Create(factory, frame, { outline = true })
  local badge = badgeResult.frame
  local innerSetUnreadCount = badgeResult.setCount
  badge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 6, 6)
  badge:SetFrameLevel(frame:GetFrameLevel() + BADGE_LEVEL_OFFSET)

  -- Competitive content indicator via CompetitiveIndicator submodule
  local competitiveResult = CompetitiveIndicator.Create(factory, frame)
  local innerSetCompetitiveActive = competitiveResult.setActive
  local isCompetitiveActive = false

  local function setCompetitiveContent(active)
    isCompetitiveActive = active == true
    innerSetCompetitiveActive(isCompetitiveActive)
  end

  local pulseState
  local incomingPreview = IncomingPreview.Create(factory, frame, {
    theme = Theme,
    getPreviewPosition = options.getPreviewPosition,
    getPreviewAutoDismissSeconds = options.getPreviewAutoDismissSeconds,
    onDismissPreview = options.onDismissPreview,
    onOpenPreview = options.onOpenPreview,
    quickReply = options.quickReply,
    onExternalChanged = function()
      pulseState.refresh()
    end,
  })
  pulseState = PulseState.New({
    start = pulseGlow.start,
    stop = pulseGlow.stop,
    getBadgePulse = options.getBadgePulse,
    isExternalShown = function()
      local shownElsewhere = options.isExternalShownElsewhere
      return incomingPreview.isExternalShown() or (shownElsewhere ~= nil and shownElsewhere() == true)
    end,
  })

  local getShowUnreadBadge = options.getShowUnreadBadge
  local getBadgePulse = options.getBadgePulse
  local getIconDesaturated = options.getIconDesaturated
  local getIsLocked = options.getIsLocked
  local getWidgetTransparency = options.getWidgetTransparency

  local function isLocked()
    return type(getIsLocked) == "function" and getIsLocked() == true
  end

  -- Hover state shared with the lock glyph, which shows only while hovered.
  local hover = { active = false }
  local lock = LockGlyph.Create(frame, ICON_SIZE, { isLocked = isLocked, hover = hover })
  local syncLockGlyphVisibility = lock.syncVisibility
  local refreshLockGlyph = lock.refresh

  local transparency = IconTransparency.Create(frame, {
    hover = hover,
    getWidgetTransparency = getWidgetTransparency,
  })

  local desaturation = Desaturation.Create({ getIconDesaturated = getIconDesaturated })

  -- count is the number shown; pulseCount (default count) starts the glow.
  local unreadSummary = ""
  local function setUnreadCount(count, pulseCount)
    unreadSummary = UnreadSummary.Format(UnreadSummary.Split(count, pulseCount))
    local showBadge = not getShowUnreadBadge or getShowUnreadBadge()
    local allowPulse = not getBadgePulse or getBadgePulse()
    local unreadCount = tonumber(count) or 0
    if showBadge then
      innerSetUnreadCount(count)
    else
      innerSetUnreadCount(0)
    end

    pulseState.setUnreadWants((tonumber(pulseCount or count) or 0) > 0 and allowPulse and showBadge)

    desaturation.update(unreadCount)
    squareLook.apply(desaturation.isActive())
    transparency.setHasUnread(unreadCount > 0)
  end

  local tooltip = IconTooltip.Create(frame, { badge = badge, isLocked = isLocked, options = options })
  local drag = IconScripts.Attach(frame, {
    hover = hover,
    syncLockGlyphVisibility = syncLockGlyphVisibility,
    refreshTransparency = transparency.refresh,
    art = art,
    squareLook = squareLook,
    tooltip = tooltip,
    getUnreadSummary = function()
      return unreadSummary
    end,
    getCompetitiveActive = function()
      return isCompetitiveActive
    end,
    isLocked = isLocked,
    options = options,
  })

  -- The badge's level is set by number, so it does not follow the frame's.
  local setDocked
  local ride = IconRide.Create(frame, {
    theme = Theme,
    parent = parent,
    isLocked = isLocked,
    onPositionChanged = options.onPositionChanged,
    onRidingChanged = function(riding)
      incomingPreview.setSuppressed(riding)
      setDocked(riding)
    end,
    onLevel = function(level)
      badge:SetFrameLevel(level + BADGE_LEVEL_OFFSET)
    end,
  })

  local function refreshDesaturation()
    IconArt.PaintFace(art, hover.active)
    squareLook.apply(desaturation.isActive())
  end

  setDocked = function(value)
    local nextDocked = value == true
    if nextDocked == docked then
      return
    end

    docked = nextDocked
    refreshDesaturation()
  end

  local function refreshTheme()
    badgeResult.paint()
    pulseGlow.applyTheme(Theme)
    incomingPreview.applyTheme(Theme)
    refreshDesaturation()
  end

  local function applyIconSize(newSize)
    newSize = tonumber(newSize) or ICON_SIZE
    frame:SetSize(newSize, newSize)
    art.applySize(newSize)
    lock.applyLayout(newSize)
    squareLook.apply(desaturation.isActive()) -- glows sized from the glyph
  end

  setUnreadCount(options.unreadCount)
  incomingPreview.setIncomingPreview(options.previewSenderName, options.previewMessageText, options.previewClassTag)
  refreshTheme()
  refreshLockGlyph()
  transparency.refresh()

  return {
    frame = frame,
    background = background,
    ring = border.ring,
    squareFrame = border.squareFrame,
    accentGlyph = squareLook.accentGlyph,
    hoverGlow = squareLook.hoverGlow,
    glyphOutline = squareLook.outline,
    squareHover = squareLook.hoverEffect,
    squarePushed = squareLook.pushEffect,
    squareBackdrop = squareLook.backdrop,
    squareHoverEdges = squareLook.hoverEdges,
    squarePushedEdges = squareLook.pushEdges,
    squareMask = squareLook.mask,
    pulseTexture = pulseGlow.glowTexture,
    label = chatIcon,
    badge = badge,
    badgeBackground = badgeResult.background,
    badgeOutline = badgeResult.outline,
    badgeLabel = badgeResult.label,
    previewFrame = incomingPreview.frame,
    previewSenderLabel = incomingPreview.senderLabel,
    previewMessageLabel = incomingPreview.messageLabel,
    previewDetailLabel = incomingPreview.detailLabel,
    previewDismissButton = incomingPreview.dismissButton,
    previewDismissLabel = incomingPreview.dismissLabel,
    previewClassIcon = incomingPreview.classIcon,
    previewClassIconFrame = incomingPreview.classIconFrame,
    setUnreadCount = setUnreadCount,
    setCompetitiveContent = setCompetitiveContent,
    setIncomingPreview = incomingPreview.setIncomingPreview,
    setExternalPreview = incomingPreview.setExternalPreview,
    isExternalPreviewShown = incomingPreview.isExternalShown,
    openShownPreview = incomingPreview.openShownPreview,
    setExternalPulse = pulseState.setExternal,
    refreshPulse = pulseState.refresh,
    applyPreviewPosition = incomingPreview.applyPreviewPosition,
    applyIconSize = applyIconSize,
    refreshDesaturation = refreshDesaturation,
    refreshTheme = refreshTheme,
    lockGlyph = lock.texture,
    refreshLockGlyph = refreshLockGlyph,
    refreshTransparency = transparency.refresh,
    setDocked = setDocked,
    rideTo = ride.rideTo,
    rideHome = ride.rideHome,
    isRiding = ride.isRiding,
    adoptRidePosition = ride.adoptRidePosition,
    setRideHome = ride.setHome,
    setRideStrata = ride.setStrata,
    setRideHandlers = drag.setRideHandlers,
  }
end

ns.ToggleIcon = ToggleIcon
return ToggleIcon

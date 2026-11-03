local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor
local Badge = ns.Badge or require("WhisperMessenger.UI.Badge")
local CompetitiveIndicator = ns.CompetitiveIndicator or require("WhisperMessenger.UI.ToggleIcon.CompetitiveIndicator")
local IncomingPreview = ns.ToggleIconIncomingPreview or require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")
local PulseGlow = ns.ToggleIconPulseGlow or require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
local PulseState = ns.ToggleIconPulseState or require("WhisperMessenger.UI.ToggleIcon.PulseState")
local Desaturation = ns.ToggleIconDesaturation or require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local IconClick = ns.ToggleIconIconClick or require("WhisperMessenger.UI.ToggleIcon.IconClick")
local SquareLook = ns.ToggleIconSquareLook or require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local IconArt = ns.ToggleIconIconArt or require("WhisperMessenger.UI.ToggleIcon.IconArt")
local LockGlyph = ns.ToggleIconLockGlyph or require("WhisperMessenger.UI.ToggleIcon.LockGlyph")
local IconTooltip = ns.ToggleIconIconTooltip or require("WhisperMessenger.UI.ToggleIcon.IconTooltip")
local IconDrag = ns.ToggleIconIconDrag or require("WhisperMessenger.UI.ToggleIcon.IconDrag")

local UnreadSummary = ns.UnreadSummary or require("WhisperMessenger.UI.Shared.UnreadSummary")

local HOVER_ICON_COLOR = { 1, 1, 1, 0.65 }
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

  local resolveBgColor = IconArt.ResolveBgColor
  local resolveRingColor = IconArt.ResolveRingColor
  local resolveGlyphColor = IconArt.ResolveGlyphColor
  local art = IconArt.Create(frame, ICON_SIZE)
  local background = art.background
  local border = art.border
  local chatIcon = art.chatIcon

  local label = chatIcon -- reference kept for return table

  -- Glow pulse for unread messages (CraftScan-style looping animation)
  local pulseGlow = PulseGlow.Create(factory, frame, {
    theme = Theme,
    accent = Theme.COLORS.accent,
  })

  local squareLook = SquareLook.Create(frame, {
    background = background,
    border = border,
    glyph = chatIcon,
    roundBackground = IconArt.CIRCLE_TEX,
    roundGlyph = IconArt.ADDON_ICON_TEXTURE,
    getShowBackground = options.getIconBackground,
    pulse = pulseGlow,
  })

  -- Unread badge, outlined so it reads where it overlaps the ring
  local badgeResult = Badge.Create(factory, frame, { outline = true })
  local badge = badgeResult.frame
  local badgeBackground = badgeResult.background
  local badgeOutline = badgeResult.outline
  local badgeLabel = badgeResult.label
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
    onExternalChanged = function()
      pulseState.refresh()
    end,
  })
  pulseState = PulseState.New({
    start = pulseGlow.start,
    stop = pulseGlow.stop,
    getBadgePulse = options.getBadgePulse,
    isExternalShown = incomingPreview.isExternalShown,
  })
  local previewFrame = incomingPreview.frame
  local previewSenderLabel = incomingPreview.senderLabel
  local previewMessageLabel = incomingPreview.messageLabel
  local previewDismissButton = incomingPreview.dismissButton
  local previewDismissLabel = incomingPreview.dismissLabel
  local previewClassIcon = incomingPreview.classIcon
  local previewClassIconFrame = incomingPreview.classIconFrame
  local setIncomingPreview = incomingPreview.setIncomingPreview

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
  local lockGlyph = lock.texture
  local syncLockGlyphVisibility = lock.syncVisibility
  local refreshLockGlyph = lock.refresh

  local function resolveWidgetTransparency()
    local value = type(getWidgetTransparency) == "function" and tonumber(getWidgetTransparency()) or nil
    if value == nil or value ~= value then
      return 0
    end
    return math.min(1, math.max(0, value))
  end

  local function refreshTransparency()
    if frame.SetAlpha then
      local alpha = not hover.active and (1 - resolveWidgetTransparency()) or 1
      frame:SetAlpha(alpha)
    end
  end

  local desaturation = Desaturation.Create({
    textures = { chatIcon = chatIcon, background = background, border = border },
    resolveColors = {
      chatIcon = resolveGlyphColor,
      background = resolveBgColor,
      border = resolveRingColor,
    },
    getIconDesaturated = getIconDesaturated,
    applyVertexColor = applyVertexColor,
    keepColors = Theme.UsesSquareWidget,
  })

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
  end

  local tooltip = IconTooltip.Create(frame, { badge = badge, isLocked = isLocked, options = options })

  -- Hover glow effect
  if frame.SetScript then
    frame:SetScript("OnEnter", function()
      hover.active = true
      syncLockGlyphVisibility()
      refreshTransparency()
      if squareLook.isSquare() then
        squareLook.setHover(true)
      elseif not desaturation.paintsGrey() then
        applyVertexColor(background, Theme.COLORS.send_button_hover)
        applyVertexColor(chatIcon, HOVER_ICON_COLOR)
      end
      tooltip.show(unreadSummary, isCompetitiveActive)
    end)

    frame:SetScript("OnLeave", function()
      hover.active = false
      syncLockGlyphVisibility()
      refreshTransparency()
      local isDesat = desaturation.paintsGrey()
      applyVertexColor(background, isDesat and desaturation.DESAT_BG or resolveBgColor())
      if not isDesat then
        applyVertexColor(chatIcon, resolveGlyphColor())
      end
      squareLook.setHover(false) -- after the repaint: the square has its own fill
      tooltip.hide()
    end)

    frame:SetScript("OnClick", IconClick.Create(options))

    frame:SetScript("OnMouseDown", function()
      squareLook.setPushed(true)
    end)
    frame:SetScript("OnMouseUp", function()
      squareLook.setPushed(false)
    end)

    IconDrag.Attach(frame, isLocked, options)
  end

  local function refreshDesaturation()
    desaturation.refresh()
    squareLook.apply(desaturation.isActive())
  end

  local function refreshTheme()
    badgeResult.paint()
    desaturation.refreshOriginalColors()
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
  setIncomingPreview(options.previewSenderName, options.previewMessageText, options.previewClassTag)
  refreshTheme()
  refreshLockGlyph()
  refreshTransparency()

  return {
    frame = frame,
    background = background,
    border = border,
    squareEdges = squareLook.edges,
    accentGlyph = squareLook.accentGlyph,
    hoverGlow = squareLook.hoverGlow,
    glyphOutline = squareLook.outline,
    squareHover = squareLook.hoverEffect,
    squarePushed = squareLook.pushEffect,
    pulseTexture = pulseGlow.glowTexture,
    label = label,
    badge = badge,
    badgeBackground = badgeBackground,
    badgeOutline = badgeOutline,
    badgeLabel = badgeLabel,
    previewFrame = previewFrame,
    previewSenderLabel = previewSenderLabel,
    previewMessageLabel = previewMessageLabel,
    previewDetailLabel = incomingPreview.detailLabel,
    previewDismissButton = previewDismissButton,
    previewDismissLabel = previewDismissLabel,
    previewClassIcon = previewClassIcon,
    previewClassIconFrame = previewClassIconFrame,
    setUnreadCount = setUnreadCount,
    setCompetitiveContent = setCompetitiveContent,
    setIncomingPreview = setIncomingPreview,
    setExternalPreview = incomingPreview.setExternalPreview,
    isExternalPreviewShown = incomingPreview.isExternalShown,
    setExternalPulse = pulseState.setExternal,
    applyPreviewPosition = incomingPreview.applyPreviewPosition,
    applyIconSize = applyIconSize,
    refreshDesaturation = refreshDesaturation,
    refreshTheme = refreshTheme,
    lockGlyph = lockGlyph,
    refreshLockGlyph = refreshLockGlyph,
    refreshTransparency = refreshTransparency,
  }
end

ns.ToggleIcon = ToggleIcon
return ToggleIcon

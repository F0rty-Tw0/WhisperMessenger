local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local captureFramePosition = UIHelpers.captureFramePosition
local applyVertexColor = UIHelpers.applyVertexColor
local Badge = ns.Badge or require("WhisperMessenger.UI.Badge")
local CompetitiveIndicator = ns.CompetitiveIndicator or require("WhisperMessenger.UI.ToggleIcon.CompetitiveIndicator")
local IncomingPreview = ns.ToggleIconIncomingPreview or require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")
local PulseGlow = ns.ToggleIconPulseGlow or require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
local PulseState = ns.ToggleIconPulseState or require("WhisperMessenger.UI.ToggleIcon.PulseState")
local Desaturation = ns.ToggleIconDesaturation or require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local IconClick = ns.ToggleIconIconClick or require("WhisperMessenger.UI.ToggleIcon.IconClick")

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local KeybindHints = ns.KeybindHints or require("WhisperMessenger.UI.Shared.KeybindHints")
local UnreadSummary = ns.UnreadSummary or require("WhisperMessenger.UI.Shared.UnreadSummary")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local IconRing = ns.IconRing or require("WhisperMessenger.UI.Shared.IconRing")
local IconHover = ns.IconHover or require("WhisperMessenger.UI.Shared.IconHover")

local CHAT_ICON_RATIO = 0.9 -- chat icon scale factor vs ICON_SIZE
local LOCK_GLYPH_RATIO = 0.45 -- lock indicator size vs ICON_SIZE
local LOCK_GLYPH_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
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

  -- Circular background: use the circle texture directly, tinted to desired color
  local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

  local function resolveBgColor()
    return Theme.COLORS.toggle_icon_bg
  end
  local function resolveRingColor()
    return IconRing.RingColor(Theme.COLORS)
  end
  local function resolveGlyphColor()
    return Theme.COLORS.toggle_icon_glyph or Theme.COLORS.text_primary
  end

  -- The logo carries its own disc, so the low-res tinted circle behind it
  -- stays hidden (kept for the hover and desaturate paint that tint it).
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetTexture(CIRCLE_TEX)
  applyVertexColor(background, resolveBgColor())
  background:Hide()

  -- The minimap-button ring for the Native WoW HUD style (IconRing), tinted
  -- with the theme's ring color; no ring with the HUD off.
  local border = frame:CreateTexture(nil, "OVERLAY")
  applyVertexColor(border, resolveRingColor())

  -- The addon logo (full, or without its rim inside the ring)
  local chatIcon = frame:CreateTexture(nil, "ARTWORK")
  applyVertexColor(chatIcon, resolveGlyphColor())

  local ringKind = IconRing.Kind(Hud.Style())
  local function applyRing(size)
    IconRing.Apply({ frame = frame, icon = chatIcon, ring = border }, ringKind, size, CHAT_ICON_RATIO)
  end
  applyRing(ICON_SIZE)
  -- Hover: the logo lights up in the theme's color
  local iconHover = IconHover.Create(frame, chatIcon)

  local label = chatIcon -- reference kept for return table

  -- Glow pulse for unread messages (CraftScan-style looping animation)
  local pulseGlow = PulseGlow.Create(factory, frame, {
    theme = Theme,
    accent = Theme.COLORS.accent,
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

  -- Lock glyph overlay: small padlock texture pinned to the bottom-right of
  -- the icon. Hidden by default; shown only while the icon is locked AND the
  -- cursor is hovering it, so the indicator stays out of sight otherwise.
  local lockGlyph = frame:CreateTexture(nil, "OVERLAY")
  local function applyLockGlyphLayout(size)
    local s = math.max(8, math.floor((tonumber(size) or ICON_SIZE) * LOCK_GLYPH_RATIO))
    lockGlyph:SetSize(s, s)
    if lockGlyph.ClearAllPoints then
      lockGlyph:ClearAllPoints()
    end
    lockGlyph:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
  end
  applyLockGlyphLayout(ICON_SIZE)
  lockGlyph:SetTexture(LOCK_GLYPH_TEXTURE)
  if lockGlyph.Hide then
    lockGlyph:Hide()
  end

  local isHoveringIcon = false

  local function resolveWidgetTransparency()
    local value = type(getWidgetTransparency) == "function" and tonumber(getWidgetTransparency()) or nil
    if value == nil or value ~= value then
      return 0
    end
    return math.min(1, math.max(0, value))
  end

  local function refreshTransparency()
    if frame.SetAlpha then
      local alpha = not isHoveringIcon and (1 - resolveWidgetTransparency()) or 1
      frame:SetAlpha(alpha)
    end
  end

  local function syncLockGlyphVisibility()
    local show = isHoveringIcon and isLocked()
    if show then
      if lockGlyph.Show then
        lockGlyph:Show()
      end
    else
      if lockGlyph.Hide then
        lockGlyph:Hide()
      end
    end
  end

  local function refreshLockGlyph()
    if frame.SetMovable then
      frame:SetMovable(not isLocked())
    end
    syncLockGlyphVisibility()
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
  end

  -- Hover glow effect
  if frame.SetScript then
    frame:SetScript("OnEnter", function()
      isHoveringIcon = true
      syncLockGlyphVisibility()
      refreshTransparency()
      desaturation.setHovered(true)
      iconHover.set(true)
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        local unreadText = badge:IsShown() and " — " .. unreadSummary or ""
        local competitiveText = ""
        if isCompetitiveActive then
          competitiveText = "\n" .. Localization.Text("Paused in M+")
        end
        local lockedText = ""
        if isLocked() then
          lockedText = "\n" .. Localization.Text("Locked")
        end
        _G.GameTooltip:SetText("Whisper Messenger" .. unreadText .. competitiveText .. lockedText)
        KeybindHints.AddToTooltip(_G.GameTooltip, type(options.getHideFromDefaultChat) == "function" and options.getHideFromDefaultChat() == true)
        KeybindHints.AddClickHint(_G.GameTooltip)
        _G.GameTooltip:Show()
      end
    end)

    frame:SetScript("OnLeave", function()
      isHoveringIcon = false
      syncLockGlyphVisibility()
      refreshTransparency()
      desaturation.setHovered(false)
      iconHover.set(false)
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)

    frame:SetScript("OnClick", IconClick.Create(options))

    frame:SetScript("OnDragStart", function(self)
      if isLocked() then
        return
      end
      if self.IsMovable == nil or self:IsMovable() then
        self:StartMoving()
      end
    end)

    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local nextState = captureFramePosition(self)

      if options.onPositionChanged then
        options.onPositionChanged(nextState)
      end
    end)
  end

  local refreshDesaturation = desaturation.refresh

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
    applyRing(newSize)
    applyLockGlyphLayout(newSize)
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
    label = label,
    logoGlow = iconHover.glow,
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

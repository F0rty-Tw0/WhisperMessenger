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
local Desaturation = ns.ToggleIconDesaturation or require("WhisperMessenger.UI.ToggleIcon.Desaturation")

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local KeybindHints = ns.KeybindHints or require("WhisperMessenger.UI.Shared.KeybindHints")
local ADDON_ICON_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png"

local CHAT_ICON_RATIO = 0.9 -- chat icon scale factor vs ICON_SIZE
local HOVER_ICON_COLOR = { 1, 1, 1, 0.65 }
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
  local RING_TEX = "Interface\\COMMON\\RingBorder"

  local function resolveBgColor()
    return Theme.COLORS.toggle_icon_bg
  end
  local function resolveRingColor()
    local c = Theme.COLORS.toggle_icon_ring
    if c then
      return c
    end
    local a = Theme.COLORS.accent or { 1, 1, 1, 1 }
    return { a[1], a[2], a[3], 0.3 }
  end
  local function resolveGlyphColor()
    return Theme.COLORS.toggle_icon_glyph or Theme.COLORS.text_primary
  end

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetTexture(CIRCLE_TEX)
  applyVertexColor(background, resolveBgColor())

  -- Circular border ring: the generic `COMMON\RingBorder` hoop, which
  -- paints cleanly with any vertex-color tint from the preset palette.
  local border = frame:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
  border:SetTexture(RING_TEX)
  applyVertexColor(border, resolveRingColor())

  -- Chat icon (speech bubble) instead of text label
  local chatIcon = frame:CreateTexture(nil, "ARTWORK")
  chatIcon:SetSize(ICON_SIZE * CHAT_ICON_RATIO, ICON_SIZE * CHAT_ICON_RATIO)
  chatIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
  chatIcon:SetTexture(ADDON_ICON_TEXTURE)
  applyVertexColor(chatIcon, resolveGlyphColor())

  local label = chatIcon -- reference kept for return table

  -- Glow pulse for unread messages (CraftScan-style looping animation)
  local pulseGlow = PulseGlow.Create(factory, frame, {
    theme = Theme,
    accent = Theme.COLORS.accent,
  })
  local startPulse = pulseGlow.start
  local stopPulse = pulseGlow.stop

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

  local incomingPreview = IncomingPreview.Create(factory, frame, {
    theme = Theme,
    getPreviewPosition = options.getPreviewPosition,
    getPreviewAutoDismissSeconds = options.getPreviewAutoDismissSeconds,
    onDismissPreview = options.onDismissPreview,
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

  local function setUnreadCount(count)
    local showBadge = not getShowUnreadBadge or getShowUnreadBadge()
    local allowPulse = not getBadgePulse or getBadgePulse()
    local unreadCount = tonumber(count) or 0

    if showBadge then
      innerSetUnreadCount(count)
    else
      innerSetUnreadCount(0)
    end

    if unreadCount > 0 and allowPulse and showBadge then
      startPulse()
    else
      stopPulse()
    end

    desaturation.update(unreadCount)
  end

  -- Hover glow effect
  if frame.SetScript then
    frame:SetScript("OnEnter", function()
      isHoveringIcon = true
      syncLockGlyphVisibility()
      refreshTransparency()
      if not desaturation.isActive() then
        applyVertexColor(background, Theme.COLORS.send_button_hover)
        applyVertexColor(chatIcon, HOVER_ICON_COLOR)
      end
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        local unreadText = ""
        if badge:IsShown() then
          unreadText = " — " .. badgeLabel:GetText() .. " " .. Localization.Text("unread")
        end
        local competitiveText = ""
        if isCompetitiveActive then
          competitiveText = "\n" .. Localization.Text("Paused in M+")
        end
        local lockedText = ""
        if isLocked() then
          lockedText = "\n" .. Localization.Text("Locked")
        end
        _G.GameTooltip:SetText("WhisperMessenger" .. unreadText .. competitiveText .. lockedText)
        KeybindHints.AddToTooltip(_G.GameTooltip, type(options.getHideFromDefaultChat) == "function" and options.getHideFromDefaultChat() == true)
        _G.GameTooltip:Show()
      end
    end)

    frame:SetScript("OnLeave", function()
      isHoveringIcon = false
      syncLockGlyphVisibility()
      refreshTransparency()
      local isDesat = desaturation.isActive()
      applyVertexColor(background, isDesat and desaturation.DESAT_BG or resolveBgColor())
      if not isDesat then
        applyVertexColor(chatIcon, resolveGlyphColor())
      end
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)

    frame:SetScript("OnClick", function()
      if options.onToggle then
        options.onToggle()
      end
    end)

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
    chatIcon:SetSize(math.floor(newSize * CHAT_ICON_RATIO), math.floor(newSize * CHAT_ICON_RATIO))
    if border.SetPoint and border.ClearAllPoints then
      border:ClearAllPoints()
      border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
      border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    end
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
    badge = badge,
    badgeBackground = badgeBackground,
    badgeOutline = badgeOutline,
    badgeLabel = badgeLabel,
    previewFrame = previewFrame,
    previewSenderLabel = previewSenderLabel,
    previewMessageLabel = previewMessageLabel,
    previewDismissButton = previewDismissButton,
    previewDismissLabel = previewDismissLabel,
    previewClassIcon = previewClassIcon,
    previewClassIconFrame = previewClassIconFrame,
    setUnreadCount = setUnreadCount,
    setCompetitiveContent = setCompetitiveContent,
    setIncomingPreview = setIncomingPreview,
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

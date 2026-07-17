local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor
local Badge = ns.ToggleIconBadge or require("WhisperMessenger.UI.ToggleIcon.Badge")
local trace = ns.trace or require("WhisperMessenger.Core.Trace")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local IncomingPreview = ns.ToggleIconIncomingPreview or require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")

local MinimapIcon = {}

-- Standard minimap button size — larger than classic 20px so the unread
-- badge is legible, but small enough to not dominate the minimap ring.
local ICON_SIZE = 30
local ICON_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png"

-- Default radial position: top-right quadrant, 45 degrees.
local DEFAULT_DEGREES = 45
-- How far outside the minimap edge to place the icon (in px).
local ICON_RADIUS_OFFSET = 5

-- Minimap shape → which quadrants accept radial placement.
-- Quadrant indices: 1=TL, 2=BL, 3=TR, 4=BR (x<0→+1, y>0→+2).
-- Mirrors LibDBIcon-1.0's minimapShapes table for compatibility.
local MINIMAP_SHAPES = {
  ["ROUND"] = { true, true, true, true },
  ["SQUARE"] = { false, false, false, false },
  ["CORNER-TOPLEFT"] = { false, false, false, true },
  ["CORNER-TOPRIGHT"] = { false, false, true, false },
  ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
  ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
  ["SIDE-LEFT"] = { false, true, false, true },
  ["SIDE-RIGHT"] = { true, false, true, false },
  ["SIDE-TOP"] = { false, false, true, true },
  ["SIDE-BOTTOM"] = { true, true, false, false },
  ["TRICORNER-TOPLEFT"] = { false, true, true, true },
  ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
  ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
  ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

-- Module-local helpers

local rad, deg, cos, sin, sqrt, max, min = math.rad, math.deg, math.cos, math.sin, math.sqrt, math.max, math.min

local function getMinimapShape()
  if type(_G.GetMinimapShape) == "function" then
    return _G.GetMinimapShape() or "ROUND"
  end
  return "ROUND"
end

-- Position the button on the minimap ring at the given angle (degrees).
-- Respects the current minimap shape: round shapes place on the ring
-- radius; non-round shape quadrants clamp within the visible area.
local function updatePosition(button, parent, positionDegrees, radiusOffset)
  local angle = rad(positionDegrees)
  local x, y = cos(angle), sin(angle)
  -- Quadrant: 1=TL, 2=BL, 3=TR, 4=BR
  local q = 1
  if x < 0 then
    q = q + 1
  end
  if y > 0 then
    q = q + 2
  end

  local shape = getMinimapShape()
  local quadTable = MINIMAP_SHAPES[shape] or MINIMAP_SHAPES["ROUND"]
  local w = (parent:GetWidth() or 140) / 2 + (radiusOffset or ICON_RADIUS_OFFSET)
  local h = (parent:GetHeight() or 140) / 2 + (radiusOffset or ICON_RADIUS_OFFSET)

  if quadTable and quadTable[q] then
    -- Valid quadrant for this shape: place on the ring.
    x, y = x * w, y * h
  else
    -- Clamp to the diagonal radius within the visible area.
    local diagRadiusW = sqrt(2 * w * w) - 10
    local diagRadiusH = sqrt(2 * h * h) - 10
    x = max(-w, min(x * diagRadiusW, w))
    y = max(-h, min(y * diagRadiusH, h))
  end

  if button.ClearAllPoints then
    button:ClearAllPoints()
  end
  button:SetPoint("CENTER", parent, "CENTER", x, y)
end

-- Public API

function MinimapIcon.Create(factory, options)
  options = options or {}

  local parent = options.parent or _G.Minimap or _G.UIParent
  local state = options.state or {}
  local degrees = state.degrees or DEFAULT_DEGREES

  local frame = factory.CreateFrame("Button", "WhisperMessengerMinimapIcon", parent)
  frame:SetSize(ICON_SIZE, ICON_SIZE)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")

  -- Background disc so the icon is visible against any minimap
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(frame)
  bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  applyVertexColor(bg, { 0.08, 0.08, 0.08, 0.85 })

  -- Addon icon texture (fills the button)
  local iconTex = frame:CreateTexture(nil, "ARTWORK")
  iconTex:SetAllPoints(frame)
  iconTex:SetTexture(ICON_TEXTURE)
  -- Ring border (same skin-aware texture as the widget icon)
  local border = frame:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
  border:SetTexture("Interface\\COMMON\\RingBorder")
  applyVertexColor(border, { 0.3, 0.3, 0.3, 0.4 })

  -- Unread badge (scaled down for minimap size)
  local badgeResult = Badge.Create(factory, frame)
  local badge = badgeResult.badge
  local badgeBackground = badgeResult.badgeBackground
  local badgeLabel = badgeResult.badgeLabel
  local innerSetUnreadCount = badgeResult.setUnreadCount
  -- Scale badge from widget size (20px) down to minimap size (~14px)
  badge:SetSize(14, 14)
  badge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4)

  -- Incoming message preview (reuses the same module as the widget icon)
  local incomingPreview = IncomingPreview.Create(factory, frame, {
    theme = Theme,
    getPreviewPosition = options.getPreviewPosition,
    getPreviewAutoDismissSeconds = options.getPreviewAutoDismissSeconds,
    onDismissPreview = options.onDismissPreview,
  })
  -- Reparent to UIParent so the preview isn't clipped by the Minimap.
  incomingPreview.frame:SetParent(_G.UIParent)

  -- Initial radial placement
  local function applyRadialPosition(d)
    updatePosition(frame, parent, d or degrees, ICON_RADIUS_OFFSET)
  end

  applyRadialPosition()

  local getShowUnreadBadge = options.getShowUnreadBadge

  -- Drag: orbit around minimap center with live radial constraint.
  -- Uses RegisterForDrag + OnDragStart/OnDragStop (no StartMoving,
  -- no SetMovable). An OnUpdate script repositions the button every
  -- frame during drag so the icon stays snapped to the minimap ring.
  -- OnClick only fires when the button was not dragged, giving clean
  -- click-vs-drag separation without manual state tracking.

  if frame.SetScript then
    frame:SetScript("OnDragStart", function(self)
      self:SetScript("OnUpdate", function()
        local mx, my = parent:GetCenter()
        local px, py = _G.GetCursorPosition()
        local scale = parent:GetEffectiveScale() or 1
        px, py = px / scale, py / scale
        degrees = deg(math.atan2(py - my, px - mx)) % 360
        updatePosition(self, parent, degrees, ICON_RADIUS_OFFSET)
      end)
    end)

    frame:SetScript("OnDragStop", function(self)
      self:SetScript("OnUpdate", nil)
      if options.onPositionChanged then
        options.onPositionChanged({ degrees = degrees })
      end
      trace("minimap icon drag stop", degrees)
    end)

    -- Click: toggle window
    frame:SetScript("OnClick", function(self, buttonName)
      if buttonName == "LeftButton" and options.onToggle then
        options.onToggle()
      end
    end)

    frame:SetScript("OnEnter", function()
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        _G.GameTooltip:SetText("WhisperMessenger")
        local showBadge = not getShowUnreadBadge or getShowUnreadBadge()
        if showBadge and badge:IsShown() then
          _G.GameTooltip:AddLine(badgeLabel:GetText() .. " " .. (Localization and Localization.Text("unread") or "unread"))
        end
        _G.GameTooltip:Show()
      end
    end)

    frame:SetScript("OnLeave", function()
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
  end

  local function setUnreadCount(count)
    local showBadge = not getShowUnreadBadge or getShowUnreadBadge()

    if showBadge then
      innerSetUnreadCount(count)
    else
      innerSetUnreadCount(0)
    end
  end

  local setIncomingPreview = incomingPreview.setIncomingPreview

  -- Desaturation: grey out the icon when no unread messages.
  local function setDesaturated(active)
    if active then
      iconTex:SetDesaturated(true)
      border:SetDesaturated(true)
    else
      iconTex:SetDesaturated(false)
      border:SetDesaturated(false)
    end
  end

  local function refreshDesaturation()
    if type(getIconDesaturated) == "function" and getIconDesaturated() then
      setDesaturated(true)
    else
      setDesaturated(false)
    end
  end

  refreshDesaturation()

  -- Theme refresh
  local function refreshTheme()
    incomingPreview.applyTheme(Theme)
    refreshDesaturation()
  end

  setUnreadCount(options.unreadCount or 0)

  refreshTheme()

  trace("minimap icon created", degrees)

  return {
    frame = frame,
    iconTex = iconTex,
    border = border,
    badge = badge,
    badgeBackground = badgeBackground,
    badgeLabel = badgeLabel,
    setUnreadCount = setUnreadCount,
    setIncomingPreview = setIncomingPreview,
    applyPreviewPosition = incomingPreview.applyPreviewPosition,
    refreshDesaturation = refreshDesaturation,
    refreshTheme = refreshTheme,
    applyRadialPosition = function()
      return applyRadialPosition(degrees)
    end,
  }
end

ns.MinimapIcon = MinimapIcon
return MinimapIcon

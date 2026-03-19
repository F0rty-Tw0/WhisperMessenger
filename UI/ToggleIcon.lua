local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local function loadModule(name, key)
  if ns[key] then return ns[key] end
  local ok, loaded = pcall(require, name)
  if ok then return loaded end
  error(key .. " module not available")
end

local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")

local function trace(...)
  if type(_G.print) == "function" then
    _G.print("[WM]", ...)
  end
end

local ToggleIcon = {}

function ToggleIcon.Create(factory, options)
  options = options or {}

  local parent = options.parent or _G.UIParent
  local state = options.state or {}
  local anchorPoint = state.anchorPoint or "CENTER"
  local relativePoint = state.relativePoint or anchorPoint
  local x = state.x or 0
  local y = state.y or 0

  local ICON_SIZE = Theme.LAYOUT.ICON_SIZE
  local BADGE_SIZE = Theme.LAYOUT.ICON_BADGE_SIZE

  local frame = factory.CreateFrame("Button", "WhisperMessengerToggleIcon", parent)
  frame:SetSize(ICON_SIZE, ICON_SIZE)
  frame:SetPoint(anchorPoint, parent, relativePoint, x, y)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")

  -- Circular icon background (solid color + circular mask)
  local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  local c = Theme.COLORS.icon_bg
  if background.SetColorTexture then
    background:SetColorTexture(c[1], c[2], c[3], c[4])
  end
  if background.SetMask then
    background:SetMask(CIRCLE_MASK)
  end

  -- Circular border ring
  local border = frame:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
  border:SetTexture("Interface\\COMMON\\RingBorder")
  if border.SetVertexColor then
    local bc = Theme.COLORS.accent
    border:SetVertexColor(bc[1], bc[2], bc[3], 0.3)
  end

  -- Label
  local label = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  label:SetPoint("CENTER", frame, "CENTER", 0, 0)
  label:SetText("WM")

  -- Unread badge (accent blue style)
  local badge = factory.CreateFrame("Frame", nil, frame)
  badge:SetSize(BADGE_SIZE, BADGE_SIZE)
  badge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 6, 6)

  local badgeBackground = badge:CreateTexture(nil, "BACKGROUND")
  badgeBackground:SetAllPoints(badge)
  local bgc = Theme.COLORS.badge_bg
  if badgeBackground.SetColorTexture then
    badgeBackground:SetColorTexture(bgc[1], bgc[2], bgc[3], bgc[4])
  end
  if badgeBackground.SetMask then
    badgeBackground:SetMask(CIRCLE_MASK)
  end

  local badgeLabel = badge:CreateFontString(nil, "OVERLAY", Theme.FONTS.unread_badge)
  badgeLabel:SetPoint("CENTER", badge, "CENTER", 0, 0)
  badgeLabel:SetText("")
  if badge.Hide then
    badge:Hide()
  end

  -- Hover glow effect
  if frame.SetScript then
    frame:SetScript("OnEnter", function()
      if background.SetColorTexture then
        local hc = Theme.COLORS.send_button_hover
        background:SetColorTexture(hc[1], hc[2], hc[3], hc[4])
        if background.SetMask then
          background:SetMask(CIRCLE_MASK)
        end
      end
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        local unreadText = ""
        if badge:IsShown() then
          unreadText = " — " .. badgeLabel:GetText() .. " unread"
        end
        _G.GameTooltip:SetText("WhisperMessenger" .. unreadText)
        _G.GameTooltip:Show()
      end
    end)

    frame:SetScript("OnLeave", function()
      if background.SetColorTexture then
        local lc = Theme.COLORS.icon_bg
        background:SetColorTexture(lc[1], lc[2], lc[3], lc[4])
        if background.SetMask then
          background:SetMask(CIRCLE_MASK)
        end
      end
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)

    frame:SetScript("OnClick", function()
      trace("icon click")
      if options.onToggle then
        options.onToggle()
      end
    end)

    frame:SetScript("OnDragStart", function(self)
      if self.IsMovable == nil or self:IsMovable() then
        self:StartMoving()
        trace("icon drag start")
      end
    end)

    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, _, relative, offsetX, offsetY
      if self.GetPoint then
        point, _, relative, offsetX, offsetY = self:GetPoint()
      else
        local savedPoint = self.point or {}
        point, relative, offsetX, offsetY = savedPoint[1], savedPoint[3], savedPoint[4], savedPoint[5]
      end

      local nextState = {
        anchorPoint = point or "CENTER",
        relativePoint = relative or point or "CENTER",
        x = offsetX or 0,
        y = offsetY or 0,
      }

      trace("icon drag stop", nextState.anchorPoint, nextState.x, nextState.y)
      if options.onPositionChanged then
        options.onPositionChanged(nextState)
      end
    end)
  end

  local function setUnreadCount(count)
    local unreadCount = tonumber(count) or 0
    local text = ""
    if unreadCount > 0 then
      text = unreadCount > 99 and "99+" or tostring(unreadCount)
    end

    badgeLabel:SetText(text)
    if text == "" then
      if badge.Hide then
        badge:Hide()
      end
      return
    end

    if badge.Show then
      badge:Show()
    end
  end

  setUnreadCount(options.unreadCount)

  trace("icon created", anchorPoint, x, y)

  return {
    frame = frame,
    background = background,
    border = border,
    label = label,
    badge = badge,
    badgeBackground = badgeBackground,
    badgeLabel = badgeLabel,
    setUnreadCount = setUnreadCount,
  }
end

ns.ToggleIcon = ToggleIcon

return ToggleIcon

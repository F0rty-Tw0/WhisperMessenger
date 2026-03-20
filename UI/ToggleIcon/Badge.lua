local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule
local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")
local UIHelpers = loadModule("WhisperMessenger.UI.Helpers", "UIHelpers")
local applyVertexColor = UIHelpers.applyVertexColor

local Badge = {}

function Badge.Create(factory, parentFrame)
  local BADGE_SIZE = Theme.LAYOUT.ICON_BADGE_SIZE
  local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

  local badge = factory.CreateFrame("Frame", nil, parentFrame)
  badge:SetSize(BADGE_SIZE, BADGE_SIZE)
  badge:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 6, 6)

  local badgeBackground = badge:CreateTexture(nil, "BACKGROUND")
  badgeBackground:SetAllPoints(badge)
  badgeBackground:SetTexture(CIRCLE_TEX)
  applyVertexColor(badgeBackground, Theme.COLORS.badge_bg)

  local badgeLabel = badge:CreateFontString(nil, "OVERLAY", Theme.FONTS.unread_badge)
  badgeLabel:SetPoint("CENTER", badge, "CENTER", 0, 0)
  badgeLabel:SetText("")
  if badge.Hide then
    badge:Hide()
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

  return {
    badge = badge,
    badgeBackground = badgeBackground,
    badgeLabel = badgeLabel,
    setUnreadCount = setUnreadCount,
  }
end

ns.ToggleIconBadge = Badge
return Badge

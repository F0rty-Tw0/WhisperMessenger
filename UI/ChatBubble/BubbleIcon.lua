local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local BubbleIcon = {}

function BubbleIcon.CreateIcon(factory, parent, bubbleFrame, message, direction, options)
  options = options or {}
  local bubbleIcon = UIHelpers.createCircularIcon(factory, parent, Theme.LAYOUT.BUBBLE_ICON_SIZE)
  local iconFrame = bubbleIcon.frame
  local icon = bubbleIcon.texture

  local gap = Theme.LAYOUT.BUBBLE_ICON_GAP or 8
  if direction == "in" then
    iconFrame:SetPoint("TOPRIGHT", bubbleFrame, "TOPLEFT", -gap, 0)
  else
    iconFrame:SetPoint("TOPLEFT", bubbleFrame, "TOPRIGHT", gap, 0)
  end

  local iconPath
  if direction == "out" then
    -- Stored class of the character that actually sent this message. Prefer
    -- this over the live UnitClass so relogging to another char doesn't
    -- rewrite history bubbles with the new char's class icon.
    if message.senderClassTag then
      iconPath = Theme.ClassIcon(message.senderClassTag)
    end
    if not iconPath and type(_G.UnitClass) == "function" then
      local _, classTag = _G.UnitClass("player")
      iconPath = Theme.ClassIcon(classTag)
    end
    if not iconPath then
      iconPath = "Interface\\CHATFRAME\\UI-ChatIcon-ArmoryChat"
    end
  else
    iconPath = Theme.ClassIcon(message.classTag or message.senderClassTag or options.fallbackClassTag)
    if not iconPath then
      iconPath = Theme.TEXTURES.bnet_icon
    end
  end

  if icon.SetTexture then
    icon:SetTexture(iconPath)
  end

  return { frame = iconFrame, texture = icon }
end

ns.ChatBubbleBubbleIcon = BubbleIcon
return BubbleIcon

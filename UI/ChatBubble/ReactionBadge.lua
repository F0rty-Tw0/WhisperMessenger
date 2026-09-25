local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")

-- The reaction icon under a chat bubble, cached on the bubble frame.
local ReactionBadge = {}

local function hideReactionTooltip(frame)
  if frame and frame._reactionTooltipOwned and _G.GameTooltip and type(_G.GameTooltip.Hide) == "function" then
    _G.GameTooltip:Hide()
  end
  if frame then
    frame._reactionTooltipOwned = nil
  end
end

-- Clears a (pooled) bubble's badge: hides it, drops hover scripts and any
-- tooltip it owns.
function ReactionBadge.Reset(frame)
  local reactionFrame = frame._reactionFrame
  if reactionFrame then
    hideReactionTooltip(reactionFrame)
    if reactionFrame.SetScript then
      reactionFrame:SetScript("OnEnter", nil)
      reactionFrame:SetScript("OnLeave", nil)
    end
    if reactionFrame.ClearAllPoints then
      reactionFrame:ClearAllPoints()
    end
    if reactionFrame.Hide then
      reactionFrame:Hide()
    end
  end
  local texture = frame._reactionTexture
  if texture then
    if texture.SetTexture then
      texture:SetTexture(nil)
    end
    if texture.SetTexCoord then
      texture:SetTexCoord(0, 1, 0, 1)
    end
    if texture.Hide then
      texture:Hide()
    end
  end
  frame._reactionKey = nil
  if reactionFrame then
    reactionFrame._wmReactionKey = nil
  end
end

local function reactionOnEnter(self)
  local tooltip = _G.GameTooltip
  if type(tooltip) ~= "table" then
    return
  end
  self._reactionTooltipOwned = true
  if type(tooltip.SetOwner) == "function" then
    tooltip:SetOwner(self, "ANCHOR_TOP")
  end
  if type(tooltip.SetText) == "function" then
    tooltip:SetText(":" .. tostring(self._wmReactionKey or "") .. ":")
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
end

local function reactionOnLeave(self)
  hideReactionTooltip(self)
end

-- Shows the reaction's icon hanging off the bubble's bottom edge (left for
-- outgoing, right for incoming) with a ":key:" tooltip. Returns frame, texture.
function ReactionBadge.Show(factory, frame, reaction, direction)
  local reactionFrame = frame._reactionFrame
  if reactionFrame == nil then
    reactionFrame = factory.CreateFrame("Frame", nil, frame)
    if reactionFrame.EnableMouse then
      reactionFrame:EnableMouse(true)
    end
    frame._reactionFrame = reactionFrame
    frame._reactionTexture = reactionFrame:CreateTexture(nil, "ARTWORK")
  end

  local iconSize = ReactionAssets.GetIconSize()
  reactionFrame:SetSize(iconSize, iconSize)
  local texture = frame._reactionTexture
  texture:ClearAllPoints()
  texture:SetPoint("CENTER", reactionFrame, "CENTER", 0, 0)
  texture:SetSize(iconSize, iconSize)
  local coords = ReactionAssets.GetTexCoords(reaction.key)
  texture:SetTexture(ReactionAssets.TEXTURE)
  texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  if texture.Show then
    texture:Show()
  end

  reactionFrame:ClearAllPoints()
  if direction == "out" then
    reactionFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 5, ReactionAssets.BADGE_OFFSET_Y)
  else
    reactionFrame:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -5, ReactionAssets.BADGE_OFFSET_Y)
  end
  reactionFrame._wmReactionKey = reaction.key
  reactionFrame:SetScript("OnEnter", reactionOnEnter)
  reactionFrame:SetScript("OnLeave", reactionOnLeave)
  reactionFrame:Show()
  frame._reactionKey = reaction.key
  return reactionFrame, texture
end

ns.ChatBubbleReactionBadge = ReactionBadge
return ReactionBadge

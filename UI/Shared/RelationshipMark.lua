local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")
local Relationship = ns.Relationship or require("WhisperMessenger.Model.Relationship")

-- Small icon for how the player knows a contact, drawn by the contact row and
-- the chat header. A motion-only hover frame over it shows every tie in the
-- GameTooltip; clicks pass through to whatever sits below.
local RelationshipMark = {}

local WHITE = { 1, 1, 1, 1 }

local function textureFor(rel)
  if type(rel) ~= "table" or type(rel.primary) ~= "string" then
    return nil
  end
  return Theme.TEXTURES["relationship_" .. rel.primary]
end

-- Paints the tie's atlas when it has one and the client can draw it.
-- Returns false otherwise, leaving the icon untouched.
local function paintAtlas(icon, tie)
  local atlas = Theme.RelationshipAtlas(tie)
  if atlas == nil or type(icon.SetAtlas) ~= "function" or NativeArt.AtlasInfo(atlas) == nil then
    return false
  end
  icon:SetAtlas(atlas, false)
  return true
end

local function paintTexture(icon, path)
  icon:SetTexture(path)
  -- An earlier atlas bind leaves its crop behind; show the whole image.
  if icon.SetTexCoord then
    icon:SetTexCoord(0, 1, 0, 1)
  end
end

local function showTooltip(mark)
  local tooltip = _G.GameTooltip
  if mark.rel == nil or not tooltip or not tooltip.SetOwner then
    return
  end
  local lines = Relationship.TooltipLines(mark.rel)
  tooltip:SetOwner(mark.hover, "ANCHOR_RIGHT")
  tooltip:SetText(lines[1], 1, 1, 1)
  for i = 2, #lines do
    tooltip:AddLine(lines[i], 1, 1, 1)
  end
  tooltip:Show()
end

local function hideTooltip()
  local tooltip = _G.GameTooltip
  if tooltip and tooltip.Hide then
    tooltip:Hide()
  end
end

function RelationshipMark.Create(parent, size)
  local icon = parent:CreateTexture(nil, "ARTWORK")
  icon:SetSize(size, size)
  icon:Hide()

  local hover = _G.CreateFrame("Frame", nil, parent)
  hover:SetAllPoints(icon)
  -- Without click pass-through a mouse-enabled frame would eat row clicks,
  -- so such clients get no tooltip instead.
  if hover.SetMouseClickEnabled and hover.EnableMouse then
    hover:EnableMouse(true)
    hover:SetMouseClickEnabled(false)
    if hover.SetMouseMotionEnabled then
      hover:SetMouseMotionEnabled(true)
    end
  end
  hover:Hide()

  local mark = { icon = icon, hover = hover }
  hover:SetScript("OnEnter", function()
    showTooltip(mark)
  end)
  hover:SetScript("OnLeave", hideTooltip)
  return mark
end

-- Returns true when the mark is shown. A rel whose primary tie has no art
-- counts as no rel.
function RelationshipMark.Bind(mark, rel)
  local path = textureFor(rel)
  if path == nil then
    mark.icon:Hide()
    mark.hover:Hide()
    mark.rel = nil
    return false
  end
  local icon = mark.icon
  -- Atlas art is drawn as is; only the file fallback takes the tie's tint.
  local tint = nil
  if not paintAtlas(icon, rel.primary) then
    paintTexture(icon, path)
    tint = Theme.RelationshipTint(rel.primary)
  end
  if icon.SetDesaturated then
    icon:SetDesaturated(tint ~= nil)
  end
  UIHelpers.applyVertexColor(icon, tint or WHITE)
  icon:Show()
  mark.hover:Show()
  mark.rel = rel
  return true
end

ns.RelationshipMark = RelationshipMark
return RelationshipMark

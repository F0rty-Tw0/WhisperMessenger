local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- A plain click on an item link runs Blizzard's SetItemRef, which pins the
-- item tooltip after calling ShowUIPanel(ItemRefTooltip). Our link frames'
-- click script is addon code, so the whole click runs tainted; in combat
-- ShowUIPanel refuses a tainted caller and the game prints "Interface action
-- failed because of an AddOn". The tooltip needs no panel, so TryPin pins it
-- the way SetItemRef does (ItemRef.lua), minus ShowUIPanel.
local CombatItemRef = {}

-- Link types whose Blizzard handler passes a plain click on to the tooltip
-- (item; spell once the combat log has loaded). A type with no Blizzard
-- handler always goes there. Handlers that also act first (store, map pins)
-- stay with Blizzard.
local TOOLTIP_LINK_TYPES = { item = true, spell = true }

local function inCombat()
  return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() == true
end

local function isModifiedClick()
  return type(_G.IsModifiedClick) == "function" and _G.IsModifiedClick() and true or false
end

local function opensItemRefTooltip(link)
  local linkType = type(link) == "string" and string.match(link, "^([^:]+)") or nil
  if linkType == nil then
    return false
  end
  if TOOLTIP_LINK_TYPES[linkType] then
    return true
  end
  local linkUtil = _G.LinkUtil
  if type(linkUtil) ~= "table" or type(linkUtil.IsLinkHandlerRegistered) ~= "function" then
    return false
  end
  return not linkUtil.IsLinkHandlerRegistered(linkType)
end

-- Retail and WoW: Forever pin through ItemRefSetHyperlink, Classic through
-- SetHyperlink.
local function tooltipSetter(tooltip)
  if type(tooltip) ~= "table" or type(tooltip.IsShown) ~= "function" or type(tooltip.SetOwner) ~= "function" then
    return nil
  end
  local setter = tooltip.ItemRefSetHyperlink or tooltip.SetHyperlink
  if type(setter) ~= "function" then
    return nil
  end
  return setter
end

-- Pins the tooltip for a plain click in combat and returns true. Returns false
-- (nothing done) for every other click, so the caller hands it to Blizzard.
function CombatItemRef.TryPin(link)
  if not inCombat() or isModifiedClick() or not opensItemRefTooltip(link) then
    return false
  end
  local tooltip = _G.ItemRefTooltip
  local setter = tooltipSetter(tooltip)
  if tooltip == nil or setter == nil then
    return false
  end
  if not tooltip:IsShown() then
    tooltip:SetOwner(_G.UIParent, "ANCHOR_PRESERVE")
  end
  setter(tooltip, link)
  return true
end

ns.UIHyperlinksCombatItemRef = CombatItemRef
return CombatItemRef

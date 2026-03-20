local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Textures = {
  class_icon_prefix = "Interface\\ICONS\\ClassIcon_",
  faction_alliance = "Interface\\ICONS\\PVPCurrency-Honor-Alliance",
  faction_horde = "Interface\\ICONS\\PVPCurrency-Honor-Horde",
  bnet_icon = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
}

--- Map classTag to atlas icon path
local function ClassIcon(classTag)
  if not classTag or classTag == "" then
    return nil
  end
  return Textures.class_icon_prefix .. classTag
end

--- Map factionName to atlas icon path
local function FactionIcon(factionName)
  if factionName == "Alliance" then
    return Textures.faction_alliance
  elseif factionName == "Horde" then
    return Textures.faction_horde
  end
  return nil
end

local ThemeTextures = {
  TEXTURES = Textures,
  ClassIcon = ClassIcon,
  FactionIcon = FactionIcon,
}

ns.ThemeTextures = ThemeTextures
return ThemeTextures

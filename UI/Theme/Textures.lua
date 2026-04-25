local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Textures = {
  class_icon_prefix = "Interface\\ICONS\\ClassIcon_",
  faction_alliance = "Interface\\ICONS\\PVPCurrency-Honor-Alliance",
  faction_horde = "Interface\\ICONS\\PVPCurrency-Honor-Horde",
  bnet_icon = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
  pin_up_icon = "Interface\\BUTTONS\\Arrow-Up-Up",
  pin_down_icon = "Interface\\BUTTONS\\Arrow-Down-Up",
  remove_icon = "Interface\\Buttons\\UI-StopButton",
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

--- Map ChannelType constant to a representative icon texture.
-- Returns nil for whisper-type channels (the class icon is used instead).
local CHANNEL_ICONS = {
  -- These icons are from achievement / Cata talent art (3.0+ and 4.0+
  -- respectively). Classic Era 1.15 and TBC Classic 2.5 may not bundle them,
  -- in which case the missing-texture placeholder shows. Swap to vanilla-safe
  -- paths (e.g. GROUPFRAME / TargetingFrame / Calendar) if that happens.
  PARTY = "Interface\\ICONS\\Achievement_BG_winAB_5Cap",
  INSTANCE_CHAT = "Interface\\ICONS\\Achievement_Arena_2v2_7",
  RAID = "Interface\\ICONS\\Ability_Hunter_HunterVsWild",
  GUILD = "Interface\\ICONS\\Achievement_PVP_G_09",
  OFFICER = "Interface\\ICONS\\Achievement_PVP_O_06",
  BN_CONVERSATION = "Interface\\ICONS\\Achievement_FeatsOfStrength_Gladiator_09",
  COMMUNITY = "Interface\\ICONS\\Achievement_Reputation_ArgentChampion",
  CHANNEL = "Interface\\ICONS\\Achievement_Profession_Fishing_OldManBarlowned",
}

local function ChannelIcon(channel)
  return CHANNEL_ICONS[channel]
end

local ThemeTextures = {
  TEXTURES = Textures,
  ClassIcon = ClassIcon,
  FactionIcon = FactionIcon,
  ChannelIcon = ChannelIcon,
}

ns.ThemeTextures = ThemeTextures
return ThemeTextures

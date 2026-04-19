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
  PARTY = "Interface\\LFGFrame\\LFGIcon-Dungeon",
  INSTANCE_CHAT = "Interface\\LFGFrame\\LFGIcon-Dungeon",
  RAID = "Interface\\LFGFrame\\LFGIcon-Raid",
  GUILD = "Interface\\ICONS\\INV_Misc_Tabard_GuildTabard",
  OFFICER = "Interface\\GossipFrame\\IncomingQuestIcon",
  BN_CONVERSATION = "Interface\\FriendsFrame\\Battlenet-BattlenetIcon",
  COMMUNITY = "Interface\\FriendsFrame\\Battlenet-BattlenetIcon",
  CHANNEL = "Interface\\ChatFrame\\UI-ChatIcon-Channel",
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

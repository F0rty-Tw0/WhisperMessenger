local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Textures = {
  class_icon_prefix = "Interface\\ICONS\\ClassIcon_",
  faction_alliance = "Interface\\ICONS\\PVPCurrency-Honor-Alliance",
  faction_horde = "Interface\\ICONS\\PVPCurrency-Honor-Horde",
  bnet_icon = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
  addon_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png",
  -- Pin glyphs (bundled, white on transparent; tinted at runtime).
  pin_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\pin.png",
  unpin_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\unpin.png",
  pinned_marker = "Interface\\AddOns\\WhisperMessenger\\Media\\pinned.png",
  trash_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\remove.png",
  -- Title-bar line icons (white on transparent; tinted at runtime).
  title_close_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\close.png",
  title_settings_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\settings.png",
  title_back_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\back.png",
  title_new_whisper_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\new_whisper.png",
  title_whats_new_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\whats_new.png",
  title_mark_read_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\mark_read.png",
  quick_reply_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\quick_reply.png",
  muted_icon = "Interface\\AddOns\\WhisperMessenger\\Media\\muted.png",
}

-- Class tokens with a matching ClassIcon_* texture. Unknown tags must
-- return nil so callers fall back to the BNet icon instead of silently
-- pointing SetTexture at a nonexistent path (renders as an empty circle).
local KNOWN_CLASS_TAGS = {
  WARRIOR = true,
  PALADIN = true,
  HUNTER = true,
  ROGUE = true,
  PRIEST = true,
  DEATHKNIGHT = true,
  SHAMAN = true,
  MAGE = true,
  WARLOCK = true,
  MONK = true,
  DRUID = true,
  DEMONHUNTER = true,
  EVOKER = true,
}

--- Map classTag to atlas icon path
local function ClassIcon(classTag)
  if not classTag or not KNOWN_CLASS_TAGS[classTag] then
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

-- Built-in chat channels by the slug that ends their conversation key
-- ("channel::<profile>::trade"). Vanilla-era art so every flavor has it;
-- custom channels ("c:<name>") keep the shared CHANNEL icon.
local BUILT_IN_CHANNEL_ICONS = {
  general = "Interface\\ICONS\\Ability_Warrior_BattleShout",
  trade = "Interface\\ICONS\\INV_Misc_Coin_01",
  tradeservices = "Interface\\ICONS\\Trade_BlackSmithing",
  localdefense = "Interface\\ICONS\\Ability_Warrior_DefensiveStance",
  worlddefense = "Interface\\ICONS\\INV_Shield_06",
  lfg = "Interface\\ICONS\\Spell_Holy_PrayerOfFortitude",
}

local function ChannelIcon(channel, conversationKey)
  if channel == "CHANNEL" and type(conversationKey) == "string" then
    local slug = string.match(conversationKey, "^channel::.-::(.+)$")
    local icon = slug and BUILT_IN_CHANNEL_ICONS[slug]
    if icon then
      return icon
    end
  end
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

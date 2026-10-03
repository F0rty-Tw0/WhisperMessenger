local Theme = require("WhisperMessenger.UI.Theme")

local SHARED_CHANNEL_ICON = "Interface\\ICONS\\Achievement_Profession_Fishing_OldManBarlowned"

local BUILT_IN_ICONS = {
  general = "Interface\\ICONS\\Ability_Warrior_BattleShout",
  trade = "Interface\\ICONS\\INV_Misc_Coin_01",
  tradeservices = "Interface\\ICONS\\Trade_BlackSmithing",
  localdefense = "Interface\\ICONS\\Ability_Warrior_DefensiveStance",
  worlddefense = "Interface\\ICONS\\INV_Shield_06",
  lfg = "Interface\\ICONS\\Spell_Holy_PrayerOfFortitude",
}

return function()
  -- test_built_in_channels_get_their_own_icon
  for slug, expected in pairs(BUILT_IN_ICONS) do
    local actual = Theme.ChannelIcon("CHANNEL", "channel::me-realm::" .. slug)
    assert(actual == expected, slug .. ": expected " .. expected .. ", got " .. tostring(actual))
  end

  -- test_custom_channel_keeps_the_shared_channel_icon
  do
    local actual = Theme.ChannelIcon("CHANNEL", "channel::me-realm::c:trade")
    assert(actual == SHARED_CHANNEL_ICON, "custom channel named like a built-in one, got " .. tostring(actual))
  end

  -- test_channel_without_a_key_keeps_the_shared_channel_icon
  assert(Theme.ChannelIcon("CHANNEL") == SHARED_CHANNEL_ICON, "one-argument call unchanged")

  -- test_other_group_types_ignore_the_key
  assert(Theme.ChannelIcon("GUILD", "guild::me-realm") == Theme.ChannelIcon("GUILD"), "guild icon unchanged")
end

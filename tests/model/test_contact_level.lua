local WoWStatus = require("WhisperMessenger.Model.ContactEnricher.WoWStatus")
local AvailabilityEnricher = require("WhisperMessenger.Model.ContactEnricher.AvailabilityEnricher")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local DisplayName = require("WhisperMessenger.Util.DisplayName")

local function seedCache(members)
  PresenceCache._reset()
  PresenceCache._initForTest({
    GetGuildClubId = function()
      return 1
    end,
    GetSubscribedClubs = function()
      return {}
    end,
    GetClubMembers = function()
      local ids = {}
      for i = 1, #members do
        ids[i] = i
      end
      return ids
    end,
    GetMemberInfo = function(_clubId, memberId)
      return members[memberId]
    end,
  }, {
    now = function()
      return 100
    end,
  })
end

local function runtimeWith(conversations)
  return { store = { conversations = conversations }, availabilityByGUID = {} }
end

return function()
  -- known cache level goes onto the item and the stored conversation
  do
    seedCache({ { guid = "Player-G", presence = 1, level = 70 } })
    local conversation = {}
    local item = { guid = "Player-G", conversationKey = "wow::g" }
    WoWStatus.ApplyLevel(item, runtimeWith({ ["wow::g"] = conversation }))
    assert(item.characterLevel == 70, "item should get level 70, got " .. tostring(item.characterLevel))
    assert(conversation.characterLevel == 70, "conversation should store level 70")
  end

  -- offline member with no cache level keeps the stored level
  do
    seedCache({ { guid = "Player-G", presence = 3 } })
    local conversation = { characterLevel = 60 }
    local item = ConversationSnapshot.Build("wow::g", conversation)
    item.guid = "Player-G"
    WoWStatus.ApplyLevel(item, runtimeWith({ ["wow::g"] = conversation }))
    assert(item.characterLevel == 60, "item should keep stored level 60, got " .. tostring(item.characterLevel))
    assert(conversation.characterLevel == 60, "stored level should stay 60")
  end

  -- nil store does not error
  do
    seedCache({ { guid = "Player-G", presence = 1, level = 70 } })
    local item = { guid = "Player-G", conversationKey = "wow::g" }
    WoWStatus.ApplyLevel(item, { availabilityByGUID = {} })
    assert(item.characterLevel == 70, "item should still get the level without a store")
  end

  -- the enricher applies guild level to WoW contacts, never to BNet ones
  do
    seedCache({
      { guid = "Player-W", presence = 1, level = 70 },
      { guid = "Player-B", presence = 1, level = 70 },
    })
    local wowItem = { guid = "Player-W", channel = "WOW", conversationKey = "wow::w" }
    local bnetItem = { guid = "Player-B", channel = "BN", conversationKey = "bnet::b", characterLevel = 80 }
    AvailabilityEnricher.EnrichContactsAvailability({ wowItem, bnetItem }, runtimeWith({}))
    assert(wowItem.characterLevel == 70, "WoW contact should get guild level")
    assert(bnetItem.characterLevel == 80, "BNet contact must keep its BNet level")
  end

  -- snapshot carries the stored level
  do
    assert(ConversationSnapshot.Build("k", { characterLevel = 45 }).characterLevel == 45, "snapshot should copy characterLevel")
  end

  DisplayName.Configure({ showPlayerLevels = true })

  -- test_seen_level_fills_a_stranger_without_guild_level
  do
    seedCache({})
    SeenLevel._reset()
    SeenLevel.Record("Player-S", nil, 75)
    local conversation = {}
    local item = { guid = "Player-S", conversationKey = "wow::s" }
    WoWStatus.ApplySeenLevel(item, runtimeWith({ ["wow::s"] = conversation }))
    assert(item.characterLevel == 75, "item should get seen level 75, got " .. tostring(item.characterLevel))
    assert(conversation.characterLevel == 75, "conversation should store seen level 75")
  end

  -- test_guild_level_wins_over_seen_level
  do
    seedCache({ { guid = "Player-G", presence = 1, level = 70 } })
    SeenLevel._reset()
    SeenLevel.Record("Player-G", nil, 75)
    local item = { guid = "Player-G", channel = "WOW", conversationKey = "wow::g" }
    AvailabilityEnricher.EnrichContactsAvailability({ item }, runtimeWith({}))
    assert(item.characterLevel == 70, "guild level should win, got " .. tostring(item.characterLevel))
  end

  -- test_nothing_seen_keeps_snapshot_level
  do
    seedCache({})
    SeenLevel._reset()
    local conversation = { characterLevel = 60 }
    local item = ConversationSnapshot.Build("wow::s", conversation)
    item.guid = "Player-S"
    WoWStatus.ApplySeenLevel(item, runtimeWith({ ["wow::s"] = conversation }))
    assert(item.characterLevel == 60, "item should keep snapshot level 60, got " .. tostring(item.characterLevel))
  end

  -- test_seen_level_never_touches_bnet_contacts
  do
    seedCache({})
    SeenLevel._reset()
    SeenLevel.Record("Player-B", nil, 75)
    local wowItem = { guid = "Player-W", channel = "WOW", conversationKey = "wow::w" }
    SeenLevel.Record("Player-W", nil, 30)
    local bnetItem = { guid = "Player-B", channel = "BN", conversationKey = "bnet::b", characterLevel = 80 }
    AvailabilityEnricher.EnrichContactsAvailability({ wowItem, bnetItem }, runtimeWith({}))
    assert(wowItem.characterLevel == 30, "WoW contact should get its seen level, got " .. tostring(wowItem.characterLevel))
    assert(bnetItem.characterLevel == 80, "BNet contact must keep its BNet level")
  end

  -- test_seen_level_fills_a_chat_without_guid
  do
    seedCache({})
    SeenLevel._reset()
    SeenLevel.Record(nil, "Firstmoon", 75)
    local conversation = {}
    local item = { channel = "WOW", displayName = "Firstmoon", conversationKey = "wow::f" }
    AvailabilityEnricher.EnrichContactsAvailability({ item }, runtimeWith({ ["wow::f"] = conversation }))
    assert(item.characterLevel == 75, "chat without guid should get seen level 75, got " .. tostring(item.characterLevel))
    assert(conversation.characterLevel == 75, "conversation should store seen level 75")
  end

  -- test_seen_level_by_name_fills_a_chat_with_guid
  do
    seedCache({})
    SeenLevel._reset()
    SeenLevel.Record(nil, "Firstmoon", 75)
    local item = { guid = "Player-F", channel = "WOW", displayName = "Firstmoon", conversationKey = "wow::f" }
    AvailabilityEnricher.EnrichContactsAvailability({ item }, runtimeWith({}))
    assert(item.characterLevel == 75, "name entry should fill a guid chat, got " .. tostring(item.characterLevel))
  end

  -- test_seen_level_skips_group_and_channel_chats
  do
    seedCache({})
    SeenLevel._reset()
    SeenLevel.Record(nil, "Trade", 60)
    local channelConversation = {}
    local channelItem = { channel = "CHANNEL", displayName = "Trade", conversationKey = "channel::trade" }
    local partyItem = { channel = "PARTY", displayName = "Trade", conversationKey = "party::me" }
    local wowItem = { channel = "WOW", displayName = "Trade", conversationKey = "wow::trade" }
    local runtime = runtimeWith({ ["channel::trade"] = channelConversation })
    AvailabilityEnricher.EnrichContactsAvailability({ channelItem, partyItem, wowItem }, runtime)
    assert(channelItem.characterLevel == nil, "channel chat must not get a level, got " .. tostring(channelItem.characterLevel))
    assert(channelConversation.characterLevel == nil, "channel conversation must not store a level")
    assert(partyItem.characterLevel == nil, "party chat must not get a level, got " .. tostring(partyItem.characterLevel))
    assert(wowItem.characterLevel == 60, "whisper chat should still get its seen level, got " .. tostring(wowItem.characterLevel))
  end

  -- test_option_off_keeps_snapshot_level
  do
    DisplayName.Configure({ showPlayerLevels = false })
    seedCache({})
    SeenLevel._reset()
    SeenLevel.Record("Player-S", "Firstmoon", 75)
    local conversation = { characterLevel = 60 }
    local item = ConversationSnapshot.Build("wow::s", conversation)
    item.guid = "Player-S"
    WoWStatus.ApplySeenLevel(item, runtimeWith({ ["wow::s"] = conversation }))
    assert(item.characterLevel == 60, "option off should keep snapshot level 60, got " .. tostring(item.characterLevel))
    assert(conversation.characterLevel == 60, "option off should keep stored level 60")
  end

  DisplayName.Configure({ showPlayerLevels = false })
  SeenLevel._reset()

  print("  All contact level tests passed")
end

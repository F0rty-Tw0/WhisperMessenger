local WoWStatus = require("WhisperMessenger.Model.ContactEnricher.WoWStatus")
local AvailabilityEnricher = require("WhisperMessenger.Model.ContactEnricher.AvailabilityEnricher")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

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

  print("  All contact level tests passed")
end

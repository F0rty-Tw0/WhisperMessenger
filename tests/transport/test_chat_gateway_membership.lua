local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local ChatGateway = require("WhisperMessenger.Transport.ChatGateway")

-- Helpers for stubbing/restoring WoW globals used by the membership checks.
local function saveGlobals(keys)
  local saved = {}
  for _, k in ipairs(keys) do
    saved[k] = rawget(_G, k)
  end
  return saved
end

local function restoreGlobals(saved)
  for k, v in pairs(saved) do
    rawset(_G, k, v)
  end
end

return function()
  -- ---------------------------------------------------------------------------
  -- 1. PARTY: CanSend false when IsInGroup returns false
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInGroup", "LE_PARTY_CATEGORY_HOME" })
    rawset(_G, "LE_PARTY_CATEGORY_HOME", 1)
    rawset(_G, "IsInGroup", function(_category)
      return false
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.PARTY }
    assert(ChatGateway.CanSend(api, conv) == false, "CanSend PARTY should be false when IsInGroup returns false")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 2. PARTY: CanSend true when IsInGroup returns true
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInGroup", "LE_PARTY_CATEGORY_HOME" })
    rawset(_G, "LE_PARTY_CATEGORY_HOME", 1)
    rawset(_G, "IsInGroup", function(_category)
      return true
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.PARTY }
    assert(ChatGateway.CanSend(api, conv) == true, "CanSend PARTY should be true when IsInGroup returns true")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 3. INSTANCE_CHAT: CanSend false when IsInGroup(LE_PARTY_CATEGORY_INSTANCE) false
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInGroup", "LE_PARTY_CATEGORY_INSTANCE" })
    rawset(_G, "LE_PARTY_CATEGORY_INSTANCE", 2)
    rawset(_G, "IsInGroup", function(_category)
      return false
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.INSTANCE_CHAT }
    assert(ChatGateway.CanSend(api, conv) == false, "CanSend INSTANCE_CHAT should be false when not in instance group")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 4. INSTANCE_CHAT: CanSend true when IsInGroup(LE_PARTY_CATEGORY_INSTANCE) true
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInGroup", "LE_PARTY_CATEGORY_INSTANCE" })
    rawset(_G, "LE_PARTY_CATEGORY_INSTANCE", 2)
    rawset(_G, "IsInGroup", function(_category)
      return true
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.INSTANCE_CHAT }
    assert(ChatGateway.CanSend(api, conv) == true, "CanSend INSTANCE_CHAT should be true when in instance group")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 5. RAID: CanSend false when IsInRaid returns false
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInRaid" })
    rawset(_G, "IsInRaid", function()
      return false
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.RAID }
    assert(ChatGateway.CanSend(api, conv) == false, "CanSend RAID should be false when IsInRaid returns false")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 6. RAID: CanSend true when IsInRaid returns true
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInRaid" })
    rawset(_G, "IsInRaid", function()
      return true
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.RAID }
    assert(ChatGateway.CanSend(api, conv) == true, "CanSend RAID should be true when IsInRaid returns true")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 7. GUILD: CanSend false when IsInGuild returns false
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInGuild" })
    rawset(_G, "IsInGuild", function()
      return false
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.GUILD }
    assert(ChatGateway.CanSend(api, conv) == false, "CanSend GUILD should be false when IsInGuild returns false")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 8. GUILD: CanSend true when IsInGuild returns true
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInGuild" })
    rawset(_G, "IsInGuild", function()
      return true
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.GUILD }
    assert(ChatGateway.CanSend(api, conv) == true, "CanSend GUILD should be true when IsInGuild returns true")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 9. OFFICER: CanSend false when IsInGuild returns false
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInGuild" })
    rawset(_G, "IsInGuild", function()
      return false
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.OFFICER }
    assert(ChatGateway.CanSend(api, conv) == false, "CanSend OFFICER should be false when IsInGuild returns false")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 10. OFFICER: CanSend true when IsInGuild returns true
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInGuild" })
    rawset(_G, "IsInGuild", function()
      return true
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.OFFICER }
    assert(ChatGateway.CanSend(api, conv) == true, "CanSend OFFICER should be true when IsInGuild returns true")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 11. BN_CONVERSATION: CanSend false when BNGetConversationInfo returns nil
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "BNGetConversationInfo" })
    rawset(_G, "BNGetConversationInfo", function(_id)
      return nil
    end)

    local api = { SendConversationMessage = function() end }
    local conv = { channel = ChannelType.BN_CONVERSATION, conversationID = 5 }
    assert(ChatGateway.CanSend(api, conv) == false, "CanSend BN_CONVERSATION should be false when BNGetConversationInfo returns nil")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 12. BN_CONVERSATION: CanSend true when BNGetConversationInfo returns non-nil
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "BNGetConversationInfo" })
    rawset(_G, "BNGetConversationInfo", function(_id)
      return "convInfo"
    end)

    local api = { SendConversationMessage = function() end }
    local conv = { channel = ChannelType.BN_CONVERSATION, conversationID = 5 }
    assert(ChatGateway.CanSend(api, conv) == true, "CanSend BN_CONVERSATION should be true when BNGetConversationInfo returns non-nil")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 13. BN_CONVERSATION: CanSend true when BNGetConversationInfo absent (no API guard)
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "BNGetConversationInfo" })
    rawset(_G, "BNGetConversationInfo", nil)

    local api = { SendConversationMessage = function() end }
    local conv = { channel = ChannelType.BN_CONVERSATION, conversationID = 5 }
    -- When BNGetConversationInfo is unavailable we skip the membership check
    -- (the API may not be present on all clients) and fall through to sender check.
    assert(ChatGateway.CanSend(api, conv) == true, "CanSend BN_CONVERSATION should be true when BNGetConversationInfo is unavailable")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 14. CHANNEL: CanSend false when GetChannelName returns 0
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "GetChannelName" })
    rawset(_G, "GetChannelName", function(_name)
      return 0
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.CHANNEL, channelBaseName = "General" }
    assert(ChatGateway.CanSend(api, conv) == false, "CanSend CHANNEL should be false when GetChannelName returns 0")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 15. CHANNEL: CanSend true when GetChannelName returns non-zero
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "GetChannelName" })
    rawset(_G, "GetChannelName", function(_name)
      return 1
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.CHANNEL, channelBaseName = "General" }
    assert(ChatGateway.CanSend(api, conv) == true, "CanSend CHANNEL should be true when GetChannelName returns non-zero")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 16. CHANNEL: CanSend true when GetChannelName absent (skip check)
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "GetChannelName" })
    rawset(_G, "GetChannelName", nil)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.CHANNEL, channelBaseName = "General" }
    assert(ChatGateway.CanSend(api, conv) == true, "CanSend CHANNEL should be true when GetChannelName is unavailable")

    restoreGlobals(saved)
  end

  -- ---------------------------------------------------------------------------
  -- 17. WHISPER/BN_WHISPER: membership checks do NOT regress
  -- ---------------------------------------------------------------------------
  do
    local api = {
      SendChatMessage = function() end,
      RequestCanLocalWhisperTarget = function() end,
    }
    -- WHISPER with no target → CanSend false (existing behaviour)
    assert(
      ChatGateway.CanSend(api, { channel = ChannelType.WHISPER }) == false
        or ChatGateway.CanSend(api, { channel = ChannelType.WHISPER, target = "X" }) ~= nil,
      "WHISPER CanSend should not throw"
    )
    -- BN_WHISPER no accountID → false
    assert(ChatGateway.CanSend(api, { channel = ChannelType.BN_WHISPER }) ~= nil, "BN_WHISPER CanSend should not throw")
  end

  -- ---------------------------------------------------------------------------
  -- 18. CanSend never throws even when membership globals error
  -- ---------------------------------------------------------------------------
  do
    local saved = saveGlobals({ "IsInGroup", "LE_PARTY_CATEGORY_HOME" })
    rawset(_G, "LE_PARTY_CATEGORY_HOME", 1)
    rawset(_G, "IsInGroup", function()
      error("boom")
    end)

    local api = { SendChatMessage = function() end }
    local conv = { channel = ChannelType.PARTY }
    local ok, result = pcall(ChatGateway.CanSend, api, conv)
    assert(ok == true, "CanSend must not propagate errors from membership globals")
    assert(result == false, "CanSend should return false when membership check errors")

    restoreGlobals(saved)
  end

  print("PASS: test_chat_gateway_membership")
end

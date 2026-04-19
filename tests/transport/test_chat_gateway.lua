local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local ChatGateway = require("WhisperMessenger.Transport.ChatGateway")

return function()
  -- ---------------------------------------------------------------------------
  -- Helpers
  -- ---------------------------------------------------------------------------

  -- Build a spy api that records every SendChatMessage and SendConversationMessage call.
  local function makeSpyApi()
    local calls = {}
    local api = {
      _calls = calls,
      SendChatMessage = function(message, chatType, languageID, target)
        table.insert(calls, {
          fn = "SendChatMessage",
          message = message,
          chatType = chatType,
          languageID = languageID,
          target = target,
        })
      end,
      SendWhisper = function(bnetAccountID, text)
        table.insert(calls, {
          fn = "SendWhisper",
          bnetAccountID = bnetAccountID,
          text = text,
        })
        return true
      end,
      SendConversationMessage = function(conversationID, text)
        table.insert(calls, {
          fn = "SendConversationMessage",
          conversationID = conversationID,
          text = text,
        })
      end,
    }
    return api
  end

  -- ---------------------------------------------------------------------------
  -- 1. WHISPER dispatch delegates to WhisperGateway character send
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local conv = { channel = ChannelType.WHISPER, target = "Arthas-Area52" }
    ChatGateway.Send(api, conv, "hello whisper")
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendChatMessage", "expected SendChatMessage")
    assert(api._calls[1].chatType == "WHISPER", "expected WHISPER chat type")
    assert(api._calls[1].target == "Arthas-Area52", "expected target forwarded")
    assert(api._calls[1].message == "hello whisper", "expected message forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 2. BN_WHISPER dispatch delegates to WhisperGateway BNet send
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local conv = { channel = ChannelType.BN_WHISPER, bnetAccountID = 99 }
    ChatGateway.Send(api, conv, "hello bn")
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendWhisper", "expected SendWhisper")
    assert(api._calls[1].bnetAccountID == 99, "expected bnetAccountID forwarded")
    assert(api._calls[1].text == "hello bn", "expected text forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 3. BN_CONVERSATION dispatch calls SendConversationMessage
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local conv = { channel = ChannelType.BN_CONVERSATION, conversationID = 7 }
    ChatGateway.Send(api, conv, "hello conv")
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendConversationMessage", "expected SendConversationMessage")
    assert(api._calls[1].conversationID == 7, "expected conversationID forwarded")
    assert(api._calls[1].text == "hello conv", "expected text forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 4. PARTY dispatch calls SendChatMessage with "PARTY"
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local conv = { channel = ChannelType.PARTY }
    ChatGateway.Send(api, conv, "party msg")
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendChatMessage", "expected SendChatMessage")
    assert(api._calls[1].chatType == "PARTY", "expected PARTY chat type")
    assert(api._calls[1].message == "party msg", "expected message forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 5. RAID non-warning dispatch calls SendChatMessage with "RAID"
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local conv = { channel = ChannelType.RAID }
    ChatGateway.Send(api, conv, "raid msg")
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendChatMessage", "expected SendChatMessage")
    assert(api._calls[1].chatType == "RAID", "expected RAID chat type")
    assert(api._calls[1].message == "raid msg", "expected message forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 6. RAID warning via SendRaid(api, text, true) uses "RAID_WARNING"
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    ChatGateway.SendRaid(api, "warning!", true)
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendChatMessage", "expected SendChatMessage")
    assert(api._calls[1].chatType == "RAID_WARNING", "expected RAID_WARNING chat type")
    assert(api._calls[1].message == "warning!", "expected message forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 7. INSTANCE_CHAT dispatch calls SendChatMessage with "INSTANCE_CHAT"
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local conv = { channel = ChannelType.INSTANCE_CHAT }
    ChatGateway.Send(api, conv, "instance msg")
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendChatMessage", "expected SendChatMessage")
    assert(api._calls[1].chatType == "INSTANCE_CHAT", "expected INSTANCE_CHAT chat type")
    assert(api._calls[1].message == "instance msg", "expected message forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 8. GUILD dispatch calls SendChatMessage with "GUILD"
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local conv = { channel = ChannelType.GUILD }
    ChatGateway.Send(api, conv, "guild msg")
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendChatMessage", "expected SendChatMessage")
    assert(api._calls[1].chatType == "GUILD", "expected GUILD chat type")
    assert(api._calls[1].message == "guild msg", "expected message forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 9. OFFICER dispatch calls SendChatMessage with "OFFICER"
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local conv = { channel = ChannelType.OFFICER }
    ChatGateway.Send(api, conv, "officer msg")
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendChatMessage", "expected SendChatMessage")
    assert(api._calls[1].chatType == "OFFICER", "expected OFFICER chat type")
    assert(api._calls[1].message == "officer msg", "expected message forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 10. CHANNEL dispatch calls SendChatMessage with "CHANNEL" and channelIndex
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    ChatGateway.SendChannel(api, 3, "channel hello")
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendChatMessage", "expected SendChatMessage")
    assert(api._calls[1].chatType == "CHANNEL", "expected CHANNEL chat type")
    assert(api._calls[1].message == "channel hello", "expected message forwarded")
    assert(api._calls[1].target == 3, "expected channelIndex as target/4th arg")
  end

  -- ---------------------------------------------------------------------------
  -- 11. CHANNEL dispatch via Send(api, conv, text)
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local conv = { channel = ChannelType.CHANNEL, channelIndex = 5 }
    ChatGateway.Send(api, conv, "channel via send")
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendChatMessage", "expected SendChatMessage")
    assert(api._calls[1].chatType == "CHANNEL", "expected CHANNEL chat type")
    assert(api._calls[1].target == 5, "expected channelIndex forwarded")
  end

  -- ---------------------------------------------------------------------------
  -- 12. COMMUNITY via Send errors with "receive-only" message
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local ok, err = pcall(ChatGateway.Send, api, { channel = ChannelType.COMMUNITY }, "x")
    assert(ok == false, "expected Send to error for COMMUNITY")
    assert(
      type(err) == "string" and err:find("receive%-only") ~= nil,
      "expected error to mention 'receive-only', got: " .. tostring(err)
    )
  end

  -- ---------------------------------------------------------------------------
  -- 13. Unknown channel string errors with "Unknown channel"
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local ok, err = pcall(ChatGateway.Send, api, { channel = "BOGUS" }, "x")
    assert(ok == false, "expected Send to error for unknown channel")
    assert(
      type(err) == "string" and err:find("Unknown channel") ~= nil,
      "expected error to mention 'Unknown channel', got: " .. tostring(err)
    )
  end

  -- ---------------------------------------------------------------------------
  -- 14. Missing channel field errors with "Unknown channel"
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local ok, err = pcall(ChatGateway.Send, api, {}, "x")
    assert(ok == false, "expected Send to error for missing channel")
    assert(
      type(err) == "string" and err:find("Unknown channel") ~= nil,
      "expected error to mention 'Unknown channel', got: " .. tostring(err)
    )
  end

  -- ---------------------------------------------------------------------------
  -- 15. CanSend — true for sendable channels, false for COMMUNITY and no-sender
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()

    -- All sendable channels should return true with spy api injected
    local sendable = {
      { channel = ChannelType.WHISPER, target = "X" },
      { channel = ChannelType.BN_WHISPER, bnetAccountID = 1 },
      { channel = ChannelType.BN_CONVERSATION, conversationID = 1 },
      { channel = ChannelType.PARTY },
      { channel = ChannelType.RAID },
      { channel = ChannelType.INSTANCE_CHAT },
      { channel = ChannelType.GUILD },
      { channel = ChannelType.OFFICER },
      { channel = ChannelType.CHANNEL, channelIndex = 1 },
    }
    for _, conv in ipairs(sendable) do
      assert(ChatGateway.CanSend(api, conv) == true, "expected CanSend true for channel: " .. tostring(conv.channel))
    end

    -- COMMUNITY must always return false
    assert(
      ChatGateway.CanSend(api, { channel = ChannelType.COMMUNITY }) == false,
      "expected CanSend false for COMMUNITY"
    )

    -- nil conversation must return false
    assert(ChatGateway.CanSend(api, nil) == false, "expected CanSend false for nil conv")

    -- Unknown channel must return false
    assert(ChatGateway.CanSend(api, { channel = "BOGUS" }) == false, "expected CanSend false for unknown channel")

    -- Empty api with no globals available — BN_CONVERSATION should return false
    -- (no api.SendConversationMessage and no _G.BNSendConversationMessage)
    local savedGlobal = rawget(_G, "BNSendConversationMessage")
    rawset(_G, "BNSendConversationMessage", nil)
    assert(
      ChatGateway.CanSend({}, { channel = ChannelType.BN_CONVERSATION, conversationID = 1 }) == false,
      "expected CanSend false when no BN conversation sender available"
    )
    rawset(_G, "BNSendConversationMessage", savedGlobal)
  end

  -- ---------------------------------------------------------------------------
  -- 16. Legacy fallback to _G.C_ChatInfo.SendChatMessage for group channels
  -- ---------------------------------------------------------------------------
  do
    local savedCChatInfo = rawget(_G, "C_ChatInfo")
    local legacyCalls = {}
    rawset(_G, "C_ChatInfo", {
      SendChatMessage = function(message, chatType, languageID, target)
        table.insert(legacyCalls, {
          message = message,
          chatType = chatType,
          languageID = languageID,
          target = target,
        })
      end,
    })

    -- Pass empty api — forces fallback to _G.C_ChatInfo.SendChatMessage
    ChatGateway.SendParty({}, "legacy party")

    rawset(_G, "C_ChatInfo", savedCChatInfo)

    assert(#legacyCalls == 1, "expected one call to legacy C_ChatInfo.SendChatMessage")
    assert(legacyCalls[1].message == "legacy party", "expected message forwarded to legacy")
    assert(legacyCalls[1].chatType == "PARTY", "expected PARTY chat type in legacy call")
  end

  -- ---------------------------------------------------------------------------
  -- 17. Legacy fallback to _G.BNSendConversationMessage
  -- ---------------------------------------------------------------------------
  do
    local savedGlobal = rawget(_G, "BNSendConversationMessage")
    local legacyCalls = {}
    rawset(_G, "BNSendConversationMessage", function(conversationID, text)
      table.insert(legacyCalls, { conversationID = conversationID, text = text })
    end)

    -- Pass empty api — forces fallback to _G.BNSendConversationMessage
    ChatGateway.SendBattleNetConversation({}, 42, "legacy conv msg")

    rawset(_G, "BNSendConversationMessage", savedGlobal)

    assert(#legacyCalls == 1, "expected one call to legacy BNSendConversationMessage")
    assert(legacyCalls[1].conversationID == 42, "expected conversationID forwarded")
    assert(legacyCalls[1].text == "legacy conv msg", "expected text forwarded")
  end
end

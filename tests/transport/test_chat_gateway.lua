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
  -- 1. Whisper channels are not group chats: Send rejects them, CanSend is false
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    for _, conv in ipairs({
      { channel = ChannelType.WHISPER, target = "Arthas-Area52" },
      { channel = ChannelType.BN_WHISPER, bnetAccountID = 99 },
    }) do
      local ok, err = pcall(ChatGateway.Send, api, conv, "hello whisper")
      assert(ok == false, "expected Send to error for " .. conv.channel)
      assert(
        type(err) == "string" and err:find("Unknown channel") ~= nil,
        "expected 'Unknown channel' for " .. conv.channel .. ", got: " .. tostring(err)
      )
      assert(ChatGateway.CanSend(api, conv) == false, "expected CanSend false for " .. conv.channel)
    end
    assert(#api._calls == 0, "a whisper channel is never sent through ChatGateway")
    assert(ChatGateway.SendWhisper == nil and ChatGateway.SendBattleNetWhisper == nil, "whisper senders live in WhisperGateway only")
  end

  -- ---------------------------------------------------------------------------
  -- 2. BN_CONVERSATION dispatch calls SendConversationMessage
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
  -- 3. PARTY dispatch calls SendChatMessage with "PARTY"
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
  -- 4. RAID non-warning dispatch calls SendChatMessage with "RAID"
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
  -- 5. INSTANCE_CHAT dispatch calls SendChatMessage with "INSTANCE_CHAT"
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
  -- 6. GUILD dispatch calls SendChatMessage with "GUILD"
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
  -- 7. OFFICER dispatch calls SendChatMessage with "OFFICER"
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
  -- 8. CHANNEL dispatch calls SendChatMessage with "CHANNEL" and channelIndex
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
  -- 9. CHANNEL dispatch via Send(api, conv, text)
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local savedList = rawget(_G, "GetChannelList")
    -- Stored as channel 5, but after a renumber Trade is now channel 3.
    rawset(_G, "GetChannelList", function()
      return 1, "General", false, 3, "Trade", false
    end)
    local conv = { channel = ChannelType.CHANNEL, channelIndex = 5, channelBaseName = "Trade - Stormwind City" }
    ChatGateway.Send(api, conv, "channel via send")
    local ok = pcall(ChatGateway.Send, api, { channel = ChannelType.CHANNEL, channelIndex = 5, channelBaseName = "CraftScan" }, "x")
    rawset(_G, "GetChannelList", savedList)
    assert(api._calls[1] ~= nil, "expected a call")
    assert(api._calls[1].fn == "SendChatMessage", "expected SendChatMessage")
    assert(api._calls[1].chatType == "CHANNEL", "expected CHANNEL chat type")
    assert(api._calls[1].target == 3, "expected the live channel number, got " .. tostring(api._calls[1].target))
    assert(ok == false and #api._calls == 1, "a channel the player is not in is never sent to")
  end

  -- ---------------------------------------------------------------------------
  -- 10. COMMUNITY via Send errors with "receive-only" message
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local ok, err = pcall(ChatGateway.Send, api, { channel = ChannelType.COMMUNITY }, "x")
    assert(ok == false, "expected Send to error for COMMUNITY")
    assert(type(err) == "string" and err:find("receive%-only") ~= nil, "expected error to mention 'receive-only', got: " .. tostring(err))
  end

  -- ---------------------------------------------------------------------------
  -- 11. Unknown channel string errors with "Unknown channel"
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local ok, err = pcall(ChatGateway.Send, api, { channel = "BOGUS" }, "x")
    assert(ok == false, "expected Send to error for unknown channel")
    assert(type(err) == "string" and err:find("Unknown channel") ~= nil, "expected error to mention 'Unknown channel', got: " .. tostring(err))
  end

  -- ---------------------------------------------------------------------------
  -- 12. Missing channel field errors with "Unknown channel"
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()
    local ok, err = pcall(ChatGateway.Send, api, {}, "x")
    assert(ok == false, "expected Send to error for missing channel")
    assert(type(err) == "string" and err:find("Unknown channel") ~= nil, "expected error to mention 'Unknown channel', got: " .. tostring(err))
  end

  -- ---------------------------------------------------------------------------
  -- 13. CanSend — true for sendable channels, false for COMMUNITY and no-sender
  -- ---------------------------------------------------------------------------
  do
    local api = makeSpyApi()

    -- All sendable channels should return true with spy api injected
    local sendable = {
      { channel = ChannelType.BN_CONVERSATION, conversationID = 1 },
      { channel = ChannelType.PARTY },
      { channel = ChannelType.RAID },
      { channel = ChannelType.INSTANCE_CHAT },
      { channel = ChannelType.GUILD },
      { channel = ChannelType.OFFICER },
    }
    for _, conv in ipairs(sendable) do
      assert(ChatGateway.CanSend(api, conv) == true, "expected CanSend true for channel: " .. tostring(conv.channel))
    end

    -- COMMUNITY must always return false
    assert(ChatGateway.CanSend(api, { channel = ChannelType.COMMUNITY }) == false, "expected CanSend false for COMMUNITY")

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
  -- 14. Legacy fallback to _G.C_ChatInfo.SendChatMessage for group channels
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
  -- 15. Legacy fallback to _G.BNSendConversationMessage
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

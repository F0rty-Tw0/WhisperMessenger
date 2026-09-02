local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local GroupSendPolicy = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")

return function()
  -- Whisper conversations never show group send notices.
  do
    local policy = GroupSendPolicy.Create({
      runtime = { localProfileId = "jaina-area52", chatApi = {} },
      chatGateway = {
        CanSend = function()
          error("legacy whisper should not ask group gateway")
        end,
      },
    })

    assert(policy.getNotice(nil) == nil, "nil conversation should have no notice")
    assert(policy.getNotice({ channel = "WOW" }) == nil, "WOW whisper should have no group notice")
    assert(policy.getNotice({ channel = "BN" }) == nil, "BN whisper should have no group notice")
    assert(policy.getNotice({ channel = ChannelType.COMMUNITY }) == nil, "community is receive-only, not membership notice")
  end

  -- Foreign-character group histories are read-only.
  do
    local policy = GroupSendPolicy.Create({
      runtime = { localProfileId = "jaina-area52", chatApi = {} },
      chatGateway = {
        CanSend = function()
          return true
        end,
      },
    })

    assert(
      policy.getNotice({ channel = ChannelType.PARTY, conversationKey = "party::thrall-draenor" }) == "Another character's history — read-only.",
      "foreign party history should be read-only"
    )
    assert(
      policy.getNotice({ channel = ChannelType.RAID, conversationKey = "raid::jaina-area52" }) == nil,
      "current character group history should not be read-only"
    )
  end

  -- GUID-scoped current-character histories use their stamped owner rather
  -- than parsing the suffixed key as a foreign profile.
  do
    local policy = GroupSendPolicy.Create({
      runtime = { localProfileId = "jaina-area52", chatApi = {} },
      chatGateway = {
        CanSend = function()
          return true
        end,
      },
    })

    assert(policy.getNotice({
      channel = ChannelType.PARTY,
      conversationKey = "party::jaina-area52::1::Party-0-0000000000000001",
      ownerProfileId = "jaina-area52",
    }) == nil, "current GUID party history should not be foreign")
    assert(policy.getNotice({
      channel = ChannelType.PARTY,
      conversationKey = "party::thrall-draenor::1::Party-0-0000000000000001",
      ownerProfileId = "thrall-draenor",
    }) == "Another character's history — read-only.", "foreign GUID party history should stay read-only")
  end

  -- Guild histories are account-wide and compare against the current live guild.
  do
    local policy = GroupSendPolicy.Create({
      runtime = { localProfileId = "jaina-area52", chatApi = {} },
      getPlayerGuildName = function()
        return "Knights of Ni"
      end,
      chatGateway = {
        CanSend = function()
          return true
        end,
      },
    })

    assert(policy.getNotice({
      channel = ChannelType.GUILD,
      conversationKey = "guild::Knights of Ni",
      guildName = "knights of ni",
    }) == nil, "same guild should remain sendable")
    assert(policy.getNotice({
      channel = ChannelType.GUILD,
      conversationKey = "guild::Other Guild",
      guildName = "Other Guild",
    }) == "Another character's history — read-only.", "different guild history should be read-only")
  end

  -- Current-character group without membership shows the group send notice.
  do
    local policy = GroupSendPolicy.Create({
      runtime = { localProfileId = "jaina-area52", chatApi = {} },
      chatGateway = {
        CanSend = function()
          return false
        end,
      },
    })

    assert(
      policy.getNotice({ channel = ChannelType.PARTY, conversationKey = "party::jaina-area52" }) == "Not in group — can't send.",
      "missing membership should show send notice"
    )
  end

  -- A closed GUID session remains read-only even if membership for its
  -- channel is currently true because a different group was joined.
  do
    local policy = GroupSendPolicy.Create({
      runtime = { localProfileId = "jaina-area52", chatApi = {} },
      chatGateway = {
        CanSend = function()
          return true
        end,
      },
    })

    assert(policy.getNotice({
      channel = ChannelType.PARTY,
      conversationKey = "party::jaina-area52::1::Party-0-0000000000000001",
      ownerProfileId = "jaina-area52",
      leftGroup = true,
    }) == "Historical group chat — read-only.", "closed GUID party history must remain read-only after another party join")
  end

  -- Group payloads route through ChatGateway; legacy whispers stay with SendHandler.
  do
    local sendCalls = 0
    local policy = GroupSendPolicy.Create({
      runtime = { localProfileId = "jaina-area52", chatApi = { tag = "api" } },
      chatGateway = {
        CanSend = function(_api, payload)
          return payload.channel == ChannelType.PARTY
        end,
        Send = function(api, payload, text)
          sendCalls = sendCalls + 1
          assert(api.tag == "api", "expected runtime chatApi")
          assert(payload.channel == ChannelType.PARTY, "expected party payload")
          assert(text == "hello party", "expected payload text")
        end,
      },
    })

    assert(policy.shouldRoutePayload({ channel = "WOW" }) == false, "legacy WOW should not route as group")
    assert(policy.shouldRoutePayload({ channel = ChannelType.PARTY }) == true, "party should route as group")
    assert(policy.sendPayload({ conversationKey = "party::jaina-area52", channel = ChannelType.PARTY, text = "hello party" }) == true, "party send should succeed")
    assert(sendCalls == 1, "ChatGateway.Send should be called once")
    assert(policy.sendPayload({ channel = ChannelType.RAID, text = "raid" }) == false, "unsendable group should return false")
  end

  -- A non-throwing Blizzard group dispatch is accepted even when its return
  -- value is false; dispatch itself is the acceptance boundary.
  do
    local falseReturnCalls = 0
    local policy = GroupSendPolicy.Create({
      runtime = { localProfileId = "jaina-area52", chatApi = {} },
      chatGateway = {
        CanSend = function()
          return true
        end,
        Send = function()
          falseReturnCalls = falseReturnCalls + 1
          return false
        end,
      },
    })
    assert(
      policy.sendPayload({ conversationKey = "party::jaina-area52", channel = ChannelType.PARTY, text = "dispatched" }) == true,
      "non-throwing group API false must accept the dispatch"
    )
    assert(falseReturnCalls == 1, "group API false return must dispatch exactly once")

    local errorPolicy = GroupSendPolicy.Create({
      runtime = { localProfileId = "jaina-area52", chatApi = {} },
      chatGateway = {
        CanSend = function()
          return true
        end,
        Send = function()
          error("group API error")
        end,
      },
    })
    assert(
      errorPolicy.sendPayload({ conversationKey = "party::jaina-area52", channel = ChannelType.PARTY, text = "error" }) == false,
      "group API error must reject the send"
    )
  end
  -- Every addon-supported group channel sends normal text then same-channel metadata.
  do
    local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
    local channels = { "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "OFFICER" }
    for _, channel in ipairs(channels) do
      local normalCalls = {}
      local addonCalls = {}
      local runtime = {
        localProfileId = "jaina-area52",
        chatApi = { tag = channel },
        now = function()
          return 500
        end,
      }
      local policy = GroupSendPolicy.Create({
        runtime = runtime,
        chatGateway = {
          CanSend = function(_, payload)
            return payload.channel == channel
          end,
          Send = function(...)
            assert(select("#", ...) == 3, "group normal send must not pass a whisper target")
            local api, payload, text = ...
            normalCalls[#normalCalls + 1] = { api = api, payload = payload, text = text }
          end,
        },
        addonComm = {
          SendGroup = function(...)
            assert(select("#", ...) == 4, "group addon send must not pass a whisper target")
            local api, prefix, payload, sentChannel = ...
            addonCalls[#addonCalls + 1] = { api = api, prefix = prefix, payload = payload, channel = sentChannel }
            return true
          end,
        },
      })
      local payload = { conversationKey = "group::" .. channel, channel = channel, text = "hello " .. channel }

      assert(policy.sendPayload(payload) == true, channel .. " ordinary group send should succeed")
      assert(#normalCalls == 1 and normalCalls[1].text == payload.text, channel .. " normal group text should send first")
      assert(#addonCalls == 1 and addonCalls[1].channel == channel, channel .. " identity should use matching group channel")
      local identity = Protocol.Decode(addonCalls[1].payload)
      assert(identity and identity.type == "identity", channel .. " ordinary group metadata should decode as identity")
      local ordinaryPending = runtime.pendingGroupOutgoing[payload.conversationKey]
      assert(
        ordinaryPending
          and ordinaryPending[1].text == payload.text
          and ordinaryPending[1].channel == channel
          and ordinaryPending[1].createdAt == 500
          and ordinaryPending[1].wireId == identity.wireId,
        channel .. " ordinary group pending entry should preserve wire contract"
      )

      local target = { kind = "user", direction = "in", text = "target " .. channel, wireId = "target1", guid = "Player-1", playerName = "Thrall" }
      local accepted, returnedReactionControl =
        policy.sendReaction({ conversationKey = payload.conversationKey, channel = channel }, target, "heart", "set", "Artio", "pending1")
      assert(accepted == true, channel .. " group reaction should accept only after both dispatches")
      assert(#normalCalls == 2 and string.find(normalCalls[2].text, "Artio", 1, true) == nil, channel .. " group fallback must be actor-free")
      local operation = Protocol.Decode(addonCalls[2].payload)
      assert(
        operation
          and operation.type == "groupReaction"
          and operation.wireId == "target1"
          and operation.targetGuid == "Player-1"
          and operation.targetName == "Thrall",
        channel .. " group reaction metadata should retain target identity"
      )
      local reactionPending = runtime.pendingGroupOutgoing[payload.conversationKey][2]
      assert(
        reactionPending
          and reactionPending.reactionControl
          and reactionPending.reactionControl.operation.type == "groupReaction"
          and reactionPending.reactionControl.operation.fallbackFingerprint == operation.fallbackFingerprint
          and reactionPending.reactionControl.pendingToken == "pending1"
          and reactionPending.reactionControl.actorName == "Artio"
          and reactionPending.reactionControl.targetMessage == target
          and reactionPending.reactionControl.targetConversation.conversationKey == payload.conversationKey,
        channel .. " group reaction pending entry should retain local echo control"
      )
      assert(returnedReactionControl == reactionPending.reactionControl, channel .. " group reaction must return its exact pending control")
    end
  end

  -- Normal failure removes pending, while failed reaction metadata removes its pending entry.
  do
    local sent = 0
    local runtime = {
      chatApi = {},
      now = function()
        return 600
      end,
    }
    local policy = GroupSendPolicy.Create({
      runtime = runtime,
      chatGateway = {
        CanSend = function()
          return true
        end,
        Send = function()
          sent = sent + 1
          if sent == 1 then
            error("normal failure")
          end
        end,
      },
      addonComm = {
        SendGroup = function()
          return false
        end,
      },
    })
    local payload = { conversationKey = "group::PARTY", channel = "PARTY", text = "normal failure" }
    assert(policy.sendPayload(payload) == false, "normal failure should reject group send")
    assert(
      runtime.pendingGroupOutgoing == nil or runtime.pendingGroupOutgoing[payload.conversationKey] == nil,
      "normal failure should remove pending"
    )
    payload.text = "identity failure"
    assert(policy.sendPayload(payload) == true, "identity addon failure must not reject ordinary group text")
    local ordinaryPending = runtime.pendingGroupOutgoing[payload.conversationKey]
    assert(
      ordinaryPending and #ordinaryPending == 1 and ordinaryPending[1].wireId ~= nil,
      "ordinary pending should remain after identity addon failure"
    )
    local target = { kind = "user", direction = "in", text = "target", wireId = "target1", guid = "Player-1", playerName = "Thrall" }
    assert(policy.sendReaction(payload, target, "heart", "set", "Artio", "pending1") == false, "addon failure should reject group reaction")
    assert(#runtime.pendingGroupOutgoing[payload.conversationKey] == 1, "failed reaction metadata should remove only its pending entry")
  end
  -- Pending group entries older than the correlation window are pruned before
  -- enqueue; pruning is reusable by the later receive path and preserves FIFO.
  do
    local normalCalls = 0
    local runtime = {
      chatApi = {},
      now = function()
        return 100
      end,
      pendingGroupOutgoing = {
        ["party::current"] = {
          { text = "stale duplicate", channel = "PARTY", createdAt = 84 },
          { text = "stale duplicate", channel = "PARTY", createdAt = 84 },
          { text = "at boundary", channel = "PARTY", createdAt = 85 },
        },
        ["party::old-session"] = {
          { text = "stale old session", channel = "PARTY", createdAt = 84 },
        },
      },
    }
    local policy = GroupSendPolicy.Create({
      runtime = runtime,
      chatGateway = {
        CanSend = function()
          return true
        end,
        Send = function()
          normalCalls = normalCalls + 1
        end,
      },
      addonComm = {
        SendGroup = function()
          return true
        end,
      },
    })
    local payload = { conversationKey = "party::current", channel = "PARTY", text = "new message" }

    assert(policy.sendPayload(payload) == true, "supported group dispatch should accept")
    local queue = runtime.pendingGroupOutgoing[payload.conversationKey]
    assert(normalCalls == 1, "valid group dispatch should send once")
    assert(#queue == 2 and queue[1].text == "at boundary" and queue[2].text == "new message", "enqueue must prune stale duplicates and retain FIFO")
    assert(runtime.pendingGroupOutgoing["party::old-session"] == nil, "enqueue must prune stale queues from older sessions")
    assert(type(policy.prunePending) == "function", "group pending expiry must be reusable by receive")
    policy.prunePending(payload.conversationKey, 101)
    assert(#queue == 1 and queue[1].text == "new message", "reusable prune must remove expired entries only")
  end

  -- Supported group sends require a nonempty correlation key before either transport.
  do
    local normalCalls = 0
    local addonCalls = 0
    local runtime = { chatApi = {} }
    local policy = GroupSendPolicy.Create({
      runtime = runtime,
      chatGateway = {
        CanSend = function()
          return true
        end,
        Send = function()
          normalCalls = normalCalls + 1
        end,
      },
      addonComm = {
        SendGroup = function()
          addonCalls = addonCalls + 1
          return true
        end,
      },
    })
    local target = { kind = "user", direction = "in", text = "target", wireId = "target1" }

    assert(policy.sendPayload({ channel = "PARTY", text = "nil key" }) == false, "nil group key must reject")
    assert(policy.sendPayload({ conversationKey = "", channel = "PARTY", text = "empty key" }) == false, "empty group key must reject")
    assert(policy.sendReaction({ channel = "PARTY" }, target, "heart", "set", "Artio", "pending1") == false, "nil reaction key must reject")
    assert(
      policy.sendReaction({ conversationKey = "", channel = "PARTY" }, target, "heart", "set", "Artio", "pending2") == false,
      "empty reaction key must reject"
    )
    assert(normalCalls == 0 and addonCalls == 0, "invalid group keys must not transport")
  end

  -- Read-only and competitive group reactions reject before either transport.
  do
    local normalCalls = 0
    local addonCalls = 0
    local competitive = false
    local runtime = {
      localProfileId = "jaina-area52",
      chatApi = {},
      isCompetitiveContent = function()
        return competitive
      end,
    }
    local policy = GroupSendPolicy.Create({
      runtime = runtime,
      chatGateway = {
        CanSend = function()
          return true
        end,
        Send = function()
          normalCalls = normalCalls + 1
        end,
      },
      addonComm = {
        SendGroup = function()
          addonCalls = addonCalls + 1
          return true
        end,
      },
    })
    local target = { kind = "user", direction = "in", text = "target", wireId = "target1" }
    local foreign = { conversationKey = "party::thrall-draenor", channel = "PARTY" }
    local left = { conversationKey = "party::jaina-area52", channel = "PARTY", leftGroup = true }
    local current = { conversationKey = "party::jaina-area52", channel = "PARTY" }

    assert(policy.sendReaction(foreign, target, "heart", "set", "Artio", "pending1") == false, "foreign group reaction must reject")
    assert(policy.sendReaction(left, target, "heart", "set", "Artio", "pending2") == false, "left group reaction must reject")
    competitive = true
    assert(
      policy.sendPayload({ conversationKey = current.conversationKey, channel = current.channel, text = "competitive" }) == false,
      "competitive group send must reject"
    )
    assert(policy.sendReaction(current, target, "heart", "set", "Artio", "pending3") == false, "competitive group reaction must reject")
    assert(normalCalls == 0 and addonCalls == 0, "read-only and competitive group actions must not transport")
  end

  -- Composer routing remains broad for unsupported non-whisper channels and
  -- never attaches group identity metadata to those normal sends.
  do
    local normalChannels = {}
    local policy = GroupSendPolicy.Create({
      runtime = { chatApi = {} },
      chatGateway = {
        CanSend = function()
          return true
        end,
        Send = function(_, payload)
          normalChannels[#normalChannels + 1] = payload.channel
        end,
      },
      addonComm = {
        SendGroup = function()
          error("unsupported normal composer routes must not send WMRX")
        end,
      },
    })

    assert(policy.shouldRoutePayload({ channel = "CHANNEL" }) == true, "CHANNEL composer payload must route through group policy")
    assert(policy.shouldRoutePayload({ channel = "BN_CONVERSATION" }) == true, "BN_CONVERSATION composer payload must route through group policy")
    assert(policy.sendPayload({ channel = "CHANNEL", text = "channel" }) == true, "CHANNEL normal composer send must remain accepted")
    assert(policy.sendPayload({ channel = "BN_CONVERSATION", text = "conversation" }) == true, "BN_CONVERSATION normal composer send must remain accepted")
    assert(normalChannels[1] == "CHANNEL" and normalChannels[2] == "BN_CONVERSATION", "unsupported normal composer sends must still dispatch")
  end
end

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
    assert(policy.getNotice({ channel = ChannelType.WHISPER }) == nil, "typed whisper should have no group notice")
    assert(policy.getNotice({ channel = ChannelType.BN_WHISPER }) == nil, "typed BN whisper should have no group notice")
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
    assert(policy.sendPayload({ channel = ChannelType.PARTY, text = "hello party" }, function() end) == true, "party send should succeed")
    assert(sendCalls == 1, "ChatGateway.Send should be called once")
    assert(policy.sendPayload({ channel = ChannelType.RAID, text = "raid" }, function() end) == false, "unsendable group should return false")
  end
end

local ChatGateway = require("WhisperMessenger.Transport.ChatGateway")
local GroupSendPolicy = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")

-- Sending from a channel chat: the composer payload names only the chat, so
-- the policy reads the stored channel name and the gateway finds the live
-- channel number. A channel the player is not in shows a notice instead.
local TRADE_KEY = "channel::arthas-area52::trade"

local function makePolicy(sent)
  local conversation = {
    conversationKey = TRADE_KEY,
    channel = "CHANNEL",
    channelIndex = 5,
    channelBaseName = "Trade - Stormwind City",
    ownerProfileId = "arthas-area52",
  }
  local runtime = {
    localProfileId = "arthas-area52",
    store = { conversations = { [TRADE_KEY] = conversation } },
    chatApi = {
      SendChatMessage = function(text, chatType, _, target)
        sent[#sent + 1] = { text = text, chatType = chatType, target = target }
      end,
    },
  }
  return GroupSendPolicy.Create({ runtime = runtime, chatGateway = ChatGateway }), conversation
end

local function withChannels(list, fn)
  local saved = rawget(_G, "GetChannelList")
  rawset(_G, "GetChannelList", list)
  local ok, err = pcall(fn)
  rawset(_G, "GetChannelList", saved)
  assert(ok, err)
end

return function()
  -- test_send_uses_live_number_after_renumber
  do
    local sent = {}
    local policy, conversation = makePolicy(sent)
    withChannels(function()
      return 1, "General", false, 3, "Trade", false
    end, function()
      assert(policy.getNotice(conversation) == nil, "a joined channel shows no notice")
      local accepted = policy.sendPayload({ channel = "CHANNEL", conversationKey = TRADE_KEY, text = "WTB ore" })
      assert(accepted == true, "the send is accepted")
    end)
    assert(#sent == 1 and sent[1].chatType == "CHANNEL", "one channel message is sent")
    assert(sent[1].target == 3, "the live channel number is used, got " .. tostring(sent[1].target))
  end

  -- test_unresolvable_channel_shows_notice_and_does_not_send
  do
    local sent = {}
    local policy, conversation = makePolicy(sent)
    withChannels(function()
      return 1, "General", false
    end, function()
      assert(policy.getNotice(conversation) == "Not in this channel — can't send.", "a channel the player is not in shows a notice")
      assert(policy.sendPayload({ channel = "CHANNEL", conversationKey = TRADE_KEY, text = "WTB ore" }) == false, "the send is refused")
    end)
    assert(#sent == 0, "nothing is sent")
  end

  -- test_other_characters_channel_chat_is_read_only
  do
    local sent = {}
    local policy, conversation = makePolicy(sent)
    conversation.conversationKey = "channel::thrall-draenor::trade"
    conversation.ownerProfileId = "thrall-draenor"
    withChannels(function()
      return 2, "Trade", false
    end, function()
      assert(policy.getNotice(conversation) == "Another character's history — read-only.", "an alt's channel chat is read-only")
    end)
  end
end

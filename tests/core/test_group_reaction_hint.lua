local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local GroupSendPolicy = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")

return function()
  local suffixConst = Protocol.ADDON_HINT_SUFFIX

  local function newTarget()
    return { kind = "user", direction = "in", text = "Group message", wireId = "party1", guid = "Player-1", playerName = "Thrall" }
  end

  -- The first group reaction on a conversation gets a one-time hint suffix;
  -- a second reaction on the same conversation must not repeat it.
  do
    local normalCalls = {}
    local runtime = {
      localProfileId = "artio-area52",
      chatApi = {},
      now = function()
        return 500
      end,
    }
    local policy = GroupSendPolicy.Create({
      runtime = runtime,
      chatGateway = {
        CanSend = function()
          return true
        end,
        Send = function(_, _payload, text)
          table.insert(normalCalls, text)
        end,
      },
      addonComm = {
        SendGroup = function()
          return true
        end,
      },
    })
    local conversation = { conversationKey = "party::artio-area52", channel = ChannelType.PARTY }

    assert(policy.sendReaction(conversation, newTarget(), "heart", "set", "Artio", "pending1") == true, "first group reaction should accept")
    assert(
      #normalCalls == 1 and string.sub(normalCalls[1], -#suffixConst) == suffixConst,
      "first group reaction fallback should include the hint suffix"
    )
    assert(conversation.addonHintSent == true, "first accepted group reaction should mark the hint as sent")

    assert(policy.sendReaction(conversation, newTarget(), "laugh", "set", "Artio", "pending2") == true, "second group reaction should accept")
    assert(
      #normalCalls == 2 and string.sub(normalCalls[2], -#suffixConst) ~= suffixConst,
      "second group reaction fallback should not repeat the hint suffix"
    )
  end

  -- A failed normal-chat dispatch must not mark the hint as sent.
  do
    local runtime = {
      localProfileId = "artio-area52",
      chatApi = {},
      now = function()
        return 500
      end,
    }
    local policy = GroupSendPolicy.Create({
      runtime = runtime,
      chatGateway = {
        CanSend = function()
          return true
        end,
        Send = function()
          error("simulated normal-chat failure")
        end,
      },
      addonComm = {
        SendGroup = function()
          error("addon send must not run after normal-chat failure")
        end,
      },
    })
    local conversation = { conversationKey = "party::artio-area52", channel = ChannelType.PARTY }

    assert(policy.sendReaction(conversation, newTarget(), "heart", "set", "Artio", "pending1") == false, "failed normal-chat dispatch should reject")
    assert(conversation.addonHintSent == nil, "failed group reaction must leave the hint flag unset")
  end
end

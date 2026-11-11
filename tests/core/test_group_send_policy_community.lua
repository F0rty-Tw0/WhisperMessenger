local ChatGateway = require("WhisperMessenger.Transport.ChatGateway")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local GroupSendPolicy = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")

-- Community chats are receive-only: replies go through the game's
-- Communities window, so selecting one shows a notice and disables the composer.

return function()
  -- test_community_has_read_only_notice
  do
    local policy = GroupSendPolicy.Create({
      runtime = { localProfileId = "arthas-area52", chatApi = {} },
      chatGateway = ChatGateway,
    })
    local notice = policy.getNotice({ channel = ChannelType.COMMUNITY })
    assert(notice == "Read-only here. Reply in the game's Communities window.", "community chat explains where to reply, got: " .. tostring(notice))
  end
end

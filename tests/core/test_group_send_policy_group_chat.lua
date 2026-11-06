local GroupSendPolicy = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")

-- A party-free group chat: the composer's send and notice go through
-- runtime.groupChats instead of the game's chat channels.
local KEY = "wmgroup::abcd1234"

local function makePolicy(service)
  local refreshed = {}
  local runtime = {
    localProfileId = "me-kazzak",
    store = { conversations = {} },
    chatApi = {},
    groupChats = service,
    refreshWindow = function(key)
      refreshed[#refreshed + 1] = key
    end,
  }
  return GroupSendPolicy.Create({ runtime = runtime }), refreshed
end

return function()
  -- test_send_goes_to_the_group_chat_service_and_redraws
  do
    local sent = {}
    local policy, refreshed = makePolicy({
      Send = function(key, text)
        sent[#sent + 1] = { key = key, text = text }
        return true
      end,
      Notice = function()
        return nil
      end,
    })
    local payload = { channel = "WM_GROUP", conversationKey = KEY, text = "hi" }
    assert(policy.shouldRoutePayload(payload), "group chat sends are routed by the policy")
    assert(policy.sendPayload(payload) == true)
    assert(#sent == 1 and sent[1].key == KEY and sent[1].text == "hi")
    assert(refreshed[1] == KEY, "the window redraws the conversation")
  end

  -- test_failed_send_reports_false_without_redraw
  do
    local policy, refreshed = makePolicy({
      Send = function()
        return false
      end,
      Notice = function()
        return nil
      end,
    })
    assert(policy.sendPayload({ channel = "WM_GROUP", conversationKey = KEY, text = "hi" }) == false)
    assert(#refreshed == 0)
  end

  -- test_notice_comes_from_the_service
  do
    local policy = makePolicy({
      Send = function()
        return true
      end,
      Notice = function(key)
        return key == KEY and "You left this group chat." or nil
      end,
    })
    assert(policy.getNotice({ channel = "WM_GROUP", conversationKey = KEY }) == "You left this group chat.")
  end

  -- test_without_the_service_the_chat_is_read_only
  do
    local policy = makePolicy(nil)
    assert(policy.getNotice({ channel = "WM_GROUP", conversationKey = KEY }) == "Group chat not found.")
    assert(policy.sendPayload({ channel = "WM_GROUP", conversationKey = KEY, text = "hi" }) == false)
  end
end

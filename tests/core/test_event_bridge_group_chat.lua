local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local GroupChatService = require("WhisperMessenger.Core.GroupChat.GroupChatService")
local GroupChatEnv = require("tests.helpers.group_chat_env")

-- Party-free group chat packets travel the live addon-message route into
-- runtime.groupChats; a chat line alerts like a whisper.
local GROUP_ID = "abcd1234"
local KEY = "wmgroup::" .. GROUP_ID

local function route(env, refresh, sender, body)
  local result
  for _, payload in ipairs(env.packets(sender, body)) do
    result = EventBridge.RouteLiveEvent(env.runtime, refresh, "CHAT_MSG_ADDON", payload.prefix, payload.text, "WHISPER", sender)
  end
  return result
end

return function()
  local savedFlash = _G.FlashClientIcon

  -- test_group_chat_line_is_stored_refreshed_and_alerts
  do
    local env = GroupChatEnv.New()
    env.runtime.groupChats = GroupChatService.Create({ runtime = env.runtime, timer = env.timer })
    local flashes = 0
    _G.FlashClientIcon = function()
      flashes = flashes + 1
    end
    local refreshed = {}
    local function refresh(key)
      refreshed[#refreshed + 1] = key
    end
    route(env, refresh, "Anna-Kazzak", "R~" .. GROUP_ID .. "~G~Anna-Kazzak,Me-Kazzak")
    assert(flashes == 0, "being added is not an alert")
    local result = route(env, refresh, "Anna-Kazzak", "M~" .. GROUP_ID .. "~hello")
    assert(result and result.conversationKey == KEY, "the group conversation comes back")
    assert(refreshed[#refreshed] == KEY, "the window redraws the conversation")
    assert(flashes == 1, "a chat line alerts")
    assert(env.runtime.lastIncomingWhisperKey == nil, "a group line is never the reply target")

    env.runtime.store.conversations[KEY].muted = true
    env.clock = env.clock + 10
    route(env, refresh, "Anna-Kazzak", "M~" .. GROUP_ID .. "~again")
    assert(flashes == 1, "a muted group stays quiet")
    env.restore()
  end

  -- test_group_chat_packets_on_other_channels_are_dropped
  do
    local env = GroupChatEnv.New()
    local handled = 0
    env.runtime.groupChats = {
      HandleAddonMessage = function()
        handled = handled + 1
      end,
    }
    EventBridge.RouteLiveEvent(env.runtime, nil, "CHAT_MSG_ADDON", "WMGC", "1aaaa11x", "GUILD", "Anna-Kazzak")
    EventBridge.RouteLiveEvent(env.runtime, nil, "CHAT_MSG_ADDON", "WMGC", "1aaaa11x", "WHISPER", "Anna-Kazzak")
    assert(handled == 1, "only addon whispers reach the group chat service")
    env.restore()
  end

  -- test_not_found_line_reaches_the_group_chat_after_a_send
  do
    local env = GroupChatEnv.New()
    local service = GroupChatService.Create({ runtime = env.runtime, timer = env.timer })
    env.runtime.groupChats = service
    env.runtime.pendingOutgoing = {}
    service.Create("Anna")
    EventBridge.RouteLiveEvent(env.runtime, nil, "CHAT_MSG_SYSTEM", "No player named 'Anna' is currently playing.")
    assert(service.outbox.IsSkipped("Anna-Kazzak"), "the offline member is skipped")
    env.restore()
  end

  _G.FlashClientIcon = savedFlash
end

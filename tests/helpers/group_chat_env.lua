-- A runtime, a recording addon-message API and a logged-in "Me-Kazzak" for
-- the group chat tests. Call env.restore() at the end of each test.
local Store = require("WhisperMessenger.Model.ConversationStore")

local GroupChatEnv = {}

function GroupChatEnv.New(options)
  options = options or {}
  local saved = {
    UnitName = _G.UnitName,
    GetNormalizedRealmName = _G.GetNormalizedRealmName,
    UnitClass = _G.UnitClass,
    ERR = _G.ERR_CHAT_PLAYER_NOT_FOUND_S,
  }
  _G.UnitName = function()
    return "Me"
  end
  _G.GetNormalizedRealmName = function()
    return "Kazzak"
  end
  _G.UnitClass = function()
    return "Mage", "MAGE"
  end
  _G.ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."

  local env = { sent = {}, clock = options.now or 1000, refuse = 0 }
  env.chatApi = {
    RegisterAddonMessagePrefix = function()
      return true
    end,
    SendAddonMessage = function(prefix, payload, channel, target)
      if env.refuse > 0 then
        env.refuse = env.refuse - 1
        return false
      end
      env.sent[#env.sent + 1] = { prefix = prefix, payload = payload, channel = channel, target = target }
      return true
    end,
  }
  env.timer = {
    pending = {},
    After = function(_delay, fn)
      env.timer.pending[#env.timer.pending + 1] = fn
    end,
  }
  function env.runTimers()
    local pending = env.timer.pending
    env.timer.pending = {}
    for _, fn in ipairs(pending) do
      fn()
    end
  end
  env.accountState = { settings = {}, filters = { ignored = {}, rules = {} } }
  env.runtime = {
    accountState = env.accountState,
    store = Store.New({ maxMessagesPerConversation = 200, maxConversations = 100, messageMaxAge = 86400, conversationMaxAge = 86400 }, function()
      return env.clock
    end),
    chatApi = env.chatApi,
    now = function()
      return env.clock
    end,
  }
  env.runtime.store.conversations = {}

  -- The bodies sent to target, reassembled.
  function env.bodiesTo(target)
    local GroupChatProtocol = require("WhisperMessenger.Model.GroupChatProtocol")
    local buffer, bodies = {}, {}
    for _, call in ipairs(env.sent) do
      if call.target == target then
        local body = GroupChatProtocol.Receive(buffer, "me", call.payload, 0)
        if body then
          bodies[#bodies + 1] = body
        end
      end
    end
    return bodies
  end

  -- A CHAT_MSG_ADDON payload carrying body from sender, one per frame.
  function env.packets(sender, body)
    local GroupChatProtocol = require("WhisperMessenger.Model.GroupChatProtocol")
    env.packetCounter = env.packetCounter or {}
    local frames = GroupChatProtocol.Split(
      body,
      GroupChatProtocol.NextMessageId(env.packetCounter, function()
        return 100
      end)
    )
    local payloads = {}
    for _, frame in ipairs(frames) do
      payloads[#payloads + 1] = { prefix = "WMGC", text = frame, channel = "WHISPER", playerName = sender }
    end
    return payloads
  end

  function env.restore()
    _G.UnitName = saved.UnitName
    _G.GetNormalizedRealmName = saved.GetNormalizedRealmName
    _G.UnitClass = saved.UnitClass
    _G.ERR_CHAT_PLAYER_NOT_FOUND_S = saved.ERR
  end

  return env
end

return GroupChatEnv

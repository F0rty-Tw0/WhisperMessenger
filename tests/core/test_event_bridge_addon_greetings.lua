local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

-- Addon greetings end to end through the live route: the robots.txt
-- announcement tags the next whisper, "Hide" keeps it silent, and nothing is
-- ever sent back on robots.txt.

local SENDER = "Crafter-Realm"

local function announce(runtime)
  EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_ADDON", "robots.txt", "Q:CraftScan", "WHISPER", SENDER)
end

local function whisper(runtime)
  EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", "Hi! I can craft that.", SENDER, "", "", "", "", "", "", "", "", 7, "Player-1-CRAFT")
end

local function onlyConversation(runtime)
  local _, conversation = next(runtime.store.conversations)
  return conversation
end

return function()
  local alerts, sentOnGreetingPrefix
  local function spySend(prefix)
    if prefix == "robots.txt" then
      sentOnGreetingPrefix = sentOnGreetingPrefix + 1
    end
    return true
  end

  local function setup(settings)
    alerts, sentOnGreetingPrefix = 0, 0
    rawset(_G, "FlashClientIcon", function()
      alerts = alerts + 1
    end)
    rawset(_G, "PlaySound", function()
      alerts = alerts + 1
    end)
    rawset(_G, "InCombatLockdown", function()
      return false
    end)
    _G.C_Timer = { After = function() end }
    _G.C_ChatInfo = {
      SendAddonMessage = spySend,
      RegisterAddonMessagePrefix = function()
        return true
      end,
    }
    return {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      pendingOutgoing = {},
      chatApi = _G.C_ChatInfo,
      accountState = { settings = settings },
    }
  end

  -- test_announced_whisper_is_tagged
  do
    local runtime = setup({ playSoundOnWhisper = true })
    announce(runtime)
    whisper(runtime)
    local conversation = onlyConversation(runtime)
    assert(conversation and conversation.messages[1].addonGreeting == "CraftScan", "live whisper tagged Sent by CraftScan")
    assert(sentOnGreetingPrefix == 0, "nothing sent on robots.txt")
  end

  -- test_hidden_greeting_is_silent
  do
    local runtime = setup({ playSoundOnWhisper = true, addonGreetings = "hide" })
    announce(runtime)
    whisper(runtime)
    assert(next(runtime.store.conversations) == nil, "hidden greeting not stored")
    assert(alerts == 0, "hidden greeting never alerts")
    assert(sentOnGreetingPrefix == 0, "nothing sent on robots.txt")
  end

  for _, name in ipairs({ "FlashClientIcon", "PlaySound", "InCombatLockdown" }) do
    rawset(_G, name, nil)
  end
  _G.C_Timer = nil
  _G.C_ChatInfo = nil
end

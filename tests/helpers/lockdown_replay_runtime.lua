-- A runtime that routes replayed whispers for real, with a real lockdown
-- catcher whose held lines are read back through FakeChatLines.

local FakeChatLines = require("tests.helpers.fake_chat_lines")
local LockdownCatcher = require("WhisperMessenger.Core.Bootstrap.LockdownCatcher")
local Store = require("WhisperMessenger.Model.ConversationStore")
local IncomingAlerts = require("WhisperMessenger.Core.Bootstrap.EventBridge.IncomingAlerts")
local ChatPrint = require("WhisperMessenger.Util.ChatPrint")

local SECRET = FakeChatLines.SECRET
local HELD_AT_DEFAULT = 500

local LockdownReplayRuntime = {}

LockdownReplayRuntime.HELD_AT = HELD_AT_DEFAULT

function LockdownReplayRuntime.New()
  return {
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    localProfileId = "me",
    now = function()
      return 1000
    end,
    availabilityByGUID = {},
    pendingOutgoing = {},
    accountState = { settings = {} },
    bnetApi = {},
    isChatLocked = function()
      return FakeChatLines.locked
    end,
    refreshWindow = function() end,
    lockdownCatcher = LockdownCatcher.New({
      isMythicContent = function()
        return false
      end,
      now = function()
        return LockdownReplayRuntime.HELD_AT
      end,
    }),
  }
end

-- Holds a whisper the way the catcher sees it during a lock: every arg
-- secret except the line ID.
function LockdownReplayRuntime.Hold(runtime, eventName, lineID)
  local handle = runtime.lockdownCatcher.handle
  if string.find(eventName, "CHAT_MSG_BN_", 1, true) == 1 then
    handle(eventName, SECRET, SECRET, nil, nil, nil, nil, nil, nil, nil, nil, lineID, nil, SECRET)
  else
    handle(eventName, SECRET, SECRET, nil, nil, nil, nil, nil, nil, nil, nil, lineID, SECRET)
  end
end

function LockdownReplayRuntime.FireUntilDone(runtime, limit)
  for _ = 1, limit or 50 do
    if runtime.lockdownReplay and runtime.lockdownReplay.lastSummary then
      return
    end
    FakeChatLines.Fire()
  end
end

local function spyOn(module, name)
  local saved = module[name]
  local calls = {}
  module[name] = function(...)
    calls[#calls + 1] = { ... }
  end
  return calls, function()
    module[name] = saved
  end
end

-- Installs the line fakes, spies on alerts, chat prints and window refreshes,
-- and holds each { eventName, lineID, receivedAt? } in a fresh runtime.
function LockdownReplayRuntime.Probe(lines, holds)
  local restoreLines = FakeChatLines.Install(lines)
  local notified, restoreNotify = spyOn(IncomingAlerts, "Notify")
  local printed, restorePrint = spyOn(ChatPrint, "Print")
  local runtime = LockdownReplayRuntime.New()
  local refreshes = {}
  runtime.refreshWindow = function(conversationKey)
    refreshes[#refreshes + 1] = { key = conversationKey }
  end
  for _, hold in ipairs(holds or {}) do
    LockdownReplayRuntime.HELD_AT = hold[3] or HELD_AT_DEFAULT
    LockdownReplayRuntime.Hold(runtime, hold[1], hold[2])
  end
  LockdownReplayRuntime.HELD_AT = HELD_AT_DEFAULT
  return {
    runtime = runtime,
    notified = notified,
    printed = printed,
    refreshes = refreshes,
    restore = function()
      restorePrint()
      restoreNotify()
      restoreLines()
    end,
  }
end

return LockdownReplayRuntime

-- A live whisper's window refresh runs on the next frame, after the event
-- handler returned. A refresh that throws there must still go through the
-- whisper failsafe: the error is reported, each whisper of that frame is
-- echoed to chat, and after repeated errors whispers stop being hidden.

local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local Failsafe = require("WhisperMessenger.Core.Bootstrap.WhisperIngestFailsafe")
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local ChatPrint = require("WhisperMessenger.Util.ChatPrint")

local unpack = unpack or table.unpack

local GLOBALS = { "C_Timer", "InCombatLockdown", "geterrorhandler", "UIParent", "SlashCmdList" }

local function saveGlobals()
  local saved = {}
  for _, name in ipairs(GLOBALS) do
    saved[name] = rawget(_G, name)
  end
  return saved
end

local function restoreGlobals(saved)
  for _, name in ipairs(GLOBALS) do
    rawset(_G, name, saved[name])
  end
end

local function setup()
  local h = { frameQueue = {}, reported = {}, printed = {} }
  rawset(_G, "C_Timer", {
    After = function(_delay, fn)
      h.frameQueue[#h.frameQueue + 1] = fn
    end,
    NewTicker = function()
      return { Cancel = function() end }
    end,
    NewTimer = function()
      return { Cancel = function() end }
    end,
  })
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "geterrorhandler", function()
    return function(err)
      h.reported[#h.reported + 1] = err
    end
  end)
  local factory = FakeUI.NewFactory()
  rawset(_G, "UIParent", factory.CreateFrame("Frame", "UIParent", nil))
  _G.UIParent:SetSize(1920, 1080)
  _G.UIParent:Show()
  rawset(_G, "SlashCmdList", {})
  h.runtime = Bootstrap.Initialize(factory, {
    localProfileId = "me",
    accountState = { schemaVersion = 1, conversations = {}, settings = {} },
    characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
  })
  h.runtime.setWindowVisible(true)
  return h
end

-- Runs the timers queued so far, as the next frame would; returns how many
-- of them threw out of their callback.
local function nextFrame(h)
  local queue = h.frameQueue
  h.frameQueue = {}
  local escaped = 0
  for _, fn in ipairs(queue) do
    if not pcall(fn) then
      escaped = escaped + 1
    end
  end
  return escaped
end

local function whisper(h, text, index)
  local guid = "Player-1-" .. index
  local args = { text, "Arthas-Area52", "", "", "", 0, 0, "", 0, 100 + index, 1000 + index, guid }
  Failsafe.RouteLiveEvent(Bootstrap, EventBridge, h.runtime, h.runtime.refreshWindow, "CHAT_MSG_WHISPER", unpack(args))
end

return function()
  local saved = saveGlobals()
  local savedPrint = ChatPrint.Print
  local savedBuildItems = ContactsList.BuildItemsForProfile
  local h = setup()
  nextFrame(h)
  local savedRegistered = Bootstrap._filtersRegistered
  Bootstrap._filtersRegistered = true
  ChatPrint.Print = function(message)
    h.printed[#h.printed + 1] = message
  end
  ContactsList.BuildItemsForProfile = function()
    error("draw broke")
  end

  local ok, err = pcall(function()
    -- test_throwing_next_frame_refresh_trips_the_whisper_failsafe
    local escaped = 0
    for index = 1, Failsafe.MAX_ERRORS do
      whisper(h, "part " .. index, index)
      escaped = escaped + nextFrame(h)
    end
    assert(escaped == 0, "the refresh error must not escape the timer, got " .. escaped)
    assert(#h.reported == Failsafe.MAX_ERRORS, "each refresh error is reported, got " .. #h.reported)
    assert(Bootstrap._whisperIngestErrors == Failsafe.MAX_ERRORS, "each refreshed whisper counts, got " .. tostring(Bootstrap._whisperIngestErrors))
    assert(Bootstrap._whisperFiltersDisabled == true, "repeated refresh errors stop hiding whispers")
    assert(string.find(h.printed[1] or "", "part 1", 1, true), "the whisper is echoed to chat, got " .. tostring(h.printed[1]))
  end)

  ChatPrint.Print = savedPrint
  ContactsList.BuildItemsForProfile = savedBuildItems
  Bootstrap._filtersRegistered = savedRegistered
  Bootstrap._whisperIngestErrors = nil
  Bootstrap._whisperFiltersDisabled = nil
  restoreGlobals(saved)
  assert(ok, err)
end

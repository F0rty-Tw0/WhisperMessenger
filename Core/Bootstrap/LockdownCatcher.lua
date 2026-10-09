local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local select = select
local type = type

-- Holds the line IDs of whispers that arrive while chat is locked for addons
-- (their text, sender and IDs are secret values) so they can be read back by
-- line ID after the lock lifts. Runs on its own frame because the main event
-- frame is suspended in Mythic+ content.
local LockdownCatcher = {}

LockdownCatcher.CAP = 200

local FRAME_NAME = "WhisperMessengerLockdownCatcher"
local LINE_ID_ARG = 11
local GUID_ARG = 12
local BNET_ACCOUNT_ARG = 13

local WHISPER_EVENTS = {
  "CHAT_MSG_WHISPER",
  "CHAT_MSG_WHISPER_INFORM",
  "CHAT_MSG_BN_WHISPER",
  "CHAT_MSG_BN_WHISPER_INFORM",
}

local CHARACTER_EVENTS = {
  CHAT_MSG_WHISPER = true,
  CHAT_MSG_WHISPER_INFORM = true,
}

local BNET_EVENTS = {
  CHAT_MSG_BN_WHISPER = true,
  CHAT_MSG_BN_WHISPER_INFORM = true,
}

local INCOMING_EVENTS = {
  CHAT_MSG_WHISPER = true,
  CHAT_MSG_BN_WHISPER = true,
}

local function isSecret(value)
  local issecretvalue = _G.issecretvalue
  return type(issecretvalue) == "function" and issecretvalue(value) == true
end

function LockdownCatcher.New(deps)
  local isMythicContent = deps.isMythicContent
  local now = deps.now
  local lines = {}
  local overCapLost = 0

  local catcher = {}

  function catcher.handle(eventName, ...)
    local isCharacter = CHARACTER_EVENTS[eventName] == true
    if not isCharacter and not BNET_EVENTS[eventName] then
      return
    end

    local lineID = select(LINE_ID_ARG, ...)
    if isSecret(lineID) or type(lineID) ~= "number" then
      return
    end

    -- BNet whispers whose only secret arg is the GUID are filed by the live
    -- path, so holding them would file them twice.
    local text, sender = ...
    local id = select(isCharacter and GUID_ARG or BNET_ACCOUNT_ARG, ...)
    if not (isSecret(text) or isSecret(sender) or isSecret(id) or isMythicContent()) then
      return
    end

    local incoming = INCOMING_EVENTS[eventName] == true
    if #lines >= LockdownCatcher.CAP then
      if incoming then
        overCapLost = overCapLost + 1
      end
      return
    end

    lines[#lines + 1] = { event = eventName, lineID = lineID, receivedAt = now(), incoming = incoming }
  end

  function catcher.isEmpty()
    return #lines == 0
  end

  function catcher.drain()
    local drained, lost = lines, overCapLost
    lines = {}
    overCapLost = 0
    return drained, lost
  end

  return catcher
end

local function canReadLinesLater()
  local chatInfo = _G.C_ChatInfo
  return type(_G.issecretvalue) == "function" and type(chatInfo) == "table" and type(chatInfo.GetChatLineText) == "function"
end

function LockdownCatcher.Install(deps)
  deps = deps or {}
  local Bootstrap = deps.Bootstrap or {}
  local createFrame = deps.createFrame or _G.CreateFrame
  if type(createFrame) ~= "function" or not canReadLinesLater() then
    return nil
  end

  local catcher = LockdownCatcher.New({
    isMythicContent = function()
      return Bootstrap._inMythicContent == true
    end,
    now = function()
      local runtime = Bootstrap.runtime
      if runtime and type(runtime.now) == "function" then
        return runtime.now()
      end
      return _G.time()
    end,
  })

  local frame = createFrame("Frame", FRAME_NAME)
  for _, eventName in ipairs(WHISPER_EVENTS) do
    frame:RegisterEvent(eventName)
  end
  frame:SetScript("OnEvent", function(_, eventName, ...)
    catcher.handle(eventName, ...)
  end)

  Bootstrap._lockdownCatcher = catcher
  return catcher
end

ns.BootstrapLockdownCatcher = LockdownCatcher

return LockdownCatcher

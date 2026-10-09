-- Fakes for chat-line lookups during a chat lockdown: a secret-value sentinel,
-- C_ChatInfo line reads keyed by line ID, and controllable C_Timer tickers.

local FakeChatLines = {}

FakeChatLines.SECRET = setmetatable({}, {
  __tostring = function()
    return "<secret>"
  end,
})
FakeChatLines.locked = false
FakeChatLines.ticks = {}

local afterQueue = nil

local function copyFields(source)
  local copy = {}
  if type(source) == "table" then
    for key, value in pairs(source) do
      copy[key] = value
    end
  end
  return copy
end

local function newTicker(_interval, callback)
  local ticker = { callback = callback }
  function ticker.Cancel()
    for index, live in ipairs(FakeChatLines.ticks) do
      if live == ticker then
        table.remove(FakeChatLines.ticks, index)
        break
      end
    end
  end
  FakeChatLines.ticks[#FakeChatLines.ticks + 1] = ticker
  return ticker
end

function FakeChatLines.Fire()
  local snapshot = copyFields(FakeChatLines.ticks)
  for _, ticker in ipairs(snapshot) do
    ticker.callback(ticker)
  end
end

function FakeChatLines.DeferAfter()
  afterQueue = {}
  _G.C_Timer.After = function(_delay, callback)
    afterQueue[#afterQueue + 1] = callback
  end
end

function FakeChatLines.FlushAfter()
  local queued = afterQueue or {}
  afterQueue = {}
  for _, callback in ipairs(queued) do
    callback()
  end
end

function FakeChatLines.Install(lines)
  lines = lines or {}
  local saved = {
    issecretvalue = rawget(_G, "issecretvalue"),
    C_ChatInfo = rawget(_G, "C_ChatInfo"),
    C_Timer = rawget(_G, "C_Timer"),
  }

  local function field(lineID, key)
    local line = lines[lineID]
    return line and line[key]
  end

  rawset(_G, "issecretvalue", function(value)
    return value == FakeChatLines.SECRET
  end)

  -- Copies the existing C_ChatInfo so other stubbed fields keep working.
  local chatInfo = copyFields(saved.C_ChatInfo)
  local fakes = {
    GetChatLineText = function(lineID)
      return field(lineID, "text")
    end,
    GetChatLineSenderName = function(lineID)
      return field(lineID, "name")
    end,
    GetChatLineSenderGUID = function(lineID)
      return field(lineID, "guid")
    end,
    IsValidChatLine = function(lineID)
      return lines[lineID] ~= nil and lines[lineID].valid ~= false
    end,
    InChatMessagingLockdown = function()
      return FakeChatLines.locked
    end,
  }
  for key, fake in pairs(fakes) do
    chatInfo[key] = fake
  end
  rawset(_G, "C_ChatInfo", chatInfo)

  local timer = copyFields(saved.C_Timer)
  timer.After = timer.After or function(_delay, callback)
    callback()
  end
  timer.NewTicker = newTicker
  rawset(_G, "C_Timer", timer)

  return function()
    rawset(_G, "issecretvalue", saved.issecretvalue)
    rawset(_G, "C_ChatInfo", saved.C_ChatInfo)
    rawset(_G, "C_Timer", saved.C_Timer)
    FakeChatLines.locked = false
    FakeChatLines.ticks = {}
    afterQueue = nil
  end
end

return FakeChatLines

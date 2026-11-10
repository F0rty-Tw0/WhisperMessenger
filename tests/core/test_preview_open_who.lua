local PreviewOpen = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PreviewOpen")
local WhoTriggers = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WhoTriggers")

local function build(competitive)
  local log = {}
  local runtime
  runtime = {
    isCompetitiveContent = function()
      return competitive == true
    end,
    isMythicLockdown = function()
      return false
    end,
    ensureWindow = function()
      log[#log + 1] = "ensureWindow"
      runtime.window = {}
    end,
    setWindowVisible = function() end,
  }
  local open = PreviewOpen.Create({
    runtime = runtime,
    buildContacts = function()
      return {}
    end,
    buildLatestIncomingPreview = function()
      return nil
    end,
    selectConversation = function(key)
      log[#log + 1] = "select:" .. key
    end,
  })
  return open, log, runtime
end

-- Stubs WhoTriggers.AskFor on the module table, runs fn, always restores it.
local function withAskFor(log, fn)
  local original = WhoTriggers.AskFor
  WhoTriggers.AskFor = function(runtime, key)
    log[#log + 1] = { "ask", runtime, key }
  end
  local ok, err = pcall(fn)
  WhoTriggers.AskFor = original
  assert(ok, err)
end

local function test_preview_open_asks_who_for_opened_chat()
  local open, log, runtime = build(false)
  withAskFor(log, function()
    assert(open("wow::jaina") == true)
  end)
  assert(#log == 3, "expected ask, open, select, got " .. #log .. " entries")
  -- In game the /who is blocked when the window opens first in the same click.
  local call = log[1]
  assert(type(call) == "table" and call[1] == "ask", "the /who is asked before the window opens")
  assert(call[2] == runtime and call[3] == "wow::jaina", "ask for the chat being opened")
  assert(log[2] == "ensureWindow" and log[3] == "select:wow::jaina", "then the window opens on the chat")
end

local function test_refused_preview_open_asks_nothing()
  local open, log = build(true)
  withAskFor(log, function()
    assert(open("wow::jaina") == false)
  end)
  assert(#log == 0, "a refused open asks nothing, got " .. #log .. " entries")
end

return function()
  test_preview_open_asks_who_for_opened_chat()
  test_refused_preview_open_asks_nothing()
end

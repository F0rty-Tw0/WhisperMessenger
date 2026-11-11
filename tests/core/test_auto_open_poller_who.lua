local Poller = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.Poller")

-- Which whisper intents may send the quiet /who: only those still inside the
-- player's click. Timers, focus, typing and code-set text may not.
local GLOBALS = { "hooksecurefunc", "ChatFrameUtil", "ChatFrame_SendTell", "ChatFrame_SendBNetTell", "C_Timer" }

local function makeEditBox(log)
  local box = { text = "", scripts = {}, attributes = { chatType = "SAY", stickyType = "SAY" } }
  function box:GetText()
    return self.text
  end
  function box:SetText(text)
    self.text = text
  end
  function box:GetAttribute(key)
    return self.attributes[key]
  end
  function box:SetAttribute(key, value)
    self.attributes[key] = value
  end
  function box:HookScript(scriptName, handler)
    self.scripts[scriptName] = handler
  end
  function box:HasFocus()
    return log.focused == true
  end
  function box:Hide() end
  return box
end

local function postHook(target, method, hook)
  if type(target) == "string" then
    target, method, hook = _G, target, method
  end
  local original = target[method]
  target[method] = function(...)
    original(...)
    hook(...)
  end
end

-- The game's whisper launchers: each points the box at a target, as the real
-- ones do, before our post-hooks run.
local function installGame(log, editBox)
  rawset(_G, "hooksecurefunc", postHook)
  rawset(_G, "C_Timer", {
    After = function(_seconds, fn)
      log.timers[#log.timers + 1] = fn
    end,
  })
  local function aim(chatType, name)
    editBox.attributes.chatType = chatType
    editBox.attributes.tellTarget = name
    log.focused = true
  end
  rawset(_G, "ChatFrameUtil", {
    SendTellWithMessage = function(name, _text, _chatFrame)
      aim("WHISPER", name)
    end,
    SendBNetTell = function(name)
      aim("BN_WHISPER", name)
    end,
  })
  rawset(_G, "ChatFrame_SendTell", function(name)
    aim("WHISPER", name)
  end)
end

local function install(state)
  local saved = {}
  for _, key in ipairs(GLOBALS) do
    saved[key] = rawget(_G, key)
  end
  local log = { asks = {}, tells = {}, timers = {} }
  local editBox = makeEditBox(log)
  installGame(log, editBox)
  local hooks = {
    onSendTell = function(target, inHardwareEvent)
      log.tells[#log.tells + 1] = { target = target, hardware = inHardwareEvent == true }
      return true
    end,
    askWhoForTell = function(name)
      log.asks[#log.asks + 1] = name
    end,
  }
  local runtime = {
    isCompetitiveContent = function()
      return state.competitive == true
    end,
  }
  Poller.Install(runtime, hooks, {
    isSuspended = function()
      return state.suspended == true
    end,
    getNumChatWindows = function()
      return 1
    end,
    getEditBox = function()
      return editBox
    end,
    deactivateChat = function() end,
  })
  log.restore = function()
    for _, key in ipairs(GLOBALS) do
      rawset(_G, key, saved[key])
    end
  end
  return log, editBox
end

local function case(label, state, fn)
  local log, editBox = install(state or {})
  local ok, err = pcall(fn, log, editBox)
  log.restore()
  assert(ok, label .. ": " .. tostring(err))
end

local function runTimers(log)
  local pending = log.timers
  log.timers = {}
  for _, fn in ipairs(pending) do
    fn()
  end
end

return function()
  case("right-click whisper asks inside the hook", nil, function(log)
    _G.ChatFrameUtil.SendTellWithMessage("Thrall", "", nil)
    assert(#log.asks == 1 and log.asks[1] == "Thrall", "asked " .. #log.asks)
    assert(#log.tells == 0, "the chat opens a frame later")
  end)

  case("right-click whisper's deferred open asks nothing more", nil, function(log)
    _G.ChatFrameUtil.SendTellWithMessage("Thrall", "", nil)
    runTimers(log)
    assert(#log.asks == 1, "asked " .. #log.asks)
    assert(log.tells[1] and log.tells[1].target == "Thrall", "the deferred open still routes")
    assert(log.tells[1].hardware == false, "a timer is not a click")
  end)

  case("right-click whisper while suspended asks nothing", { suspended = true }, function(log)
    _G.ChatFrameUtil.SendTellWithMessage("Thrall", "", nil)
    assert(#log.asks == 0, "asked " .. #log.asks)
  end)

  case("right-click whisper in competitive content asks nothing", { competitive = true }, function(log)
    _G.ChatFrameUtil.SendTellWithMessage("Thrall", "", nil)
    assert(#log.asks == 0, "asked " .. #log.asks)
  end)

  case("Battle.net whisper asks nothing", nil, function(log)
    _G.ChatFrameUtil.SendBNetTell("Friend#1234")
    runTimers(log)
    assert(#log.asks == 0, "asked " .. #log.asks)
  end)

  -- The game does not count OnTextChanged as a hardware event for SendWho:
  -- asking there raised ADDON_ACTION_BLOCKED in game (2026-11-11).
  case("typed slash whisper routes without a hardware event", nil, function(log, editBox)
    editBox.text = "/w Thrall "
    editBox.scripts.OnTextChanged(editBox, true)
    assert(log.tells[1] and log.tells[1].hardware == false, "typing is not a hardware event for /who")
  end)

  -- The game's own handler runs first: on the space after "/w Name" it turns
  -- the box into a whisper to Name and clears the text.
  case("typed whisper the game already converted routes without a hardware event", nil, function(log, editBox)
    editBox.attributes.chatType = "WHISPER"
    editBox.attributes.tellTarget = "Thrall"
    editBox.text = ""
    editBox.scripts.OnTextChanged(editBox, true)
    assert(log.tells[1] and log.tells[1].hardware == false, "typing is not a hardware event for /who")
  end)

  case("code-set slash whisper text routes nothing", nil, function(log, editBox)
    editBox.text = "/w Thrall "
    editBox.scripts.OnTextChanged(editBox, false)
    assert(#log.tells == 0)
  end)

  case("focus on a whisper box routes without a key press", nil, function(log, editBox)
    editBox.attributes.chatType = "WHISPER"
    editBox.attributes.tellTarget = "Thrall"
    editBox.scripts.OnEditFocusGained(editBox)
    assert(log.tells[1] and log.tells[1].hardware == false, "focus is not a key press")
  end)

  case("focus on a slash whisper box routes without a key press", nil, function(log, editBox)
    editBox.text = "/w Thrall "
    editBox.scripts.OnEditFocusGained(editBox)
    assert(log.tells[1] and log.tells[1].hardware == false, "focus is not a key press")
  end)

  case("ChatFrame_SendTell routes as a click", nil, function(log)
    _G.ChatFrame_SendTell("Thrall")
    assert(log.tells[1] and log.tells[1].target == "Thrall" and log.tells[1].hardware == true)
  end)
end

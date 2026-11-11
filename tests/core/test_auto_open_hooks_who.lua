local AutoOpenHooks = require("WhisperMessenger.Core.Bootstrap.AutoOpenHooks")

-- A whisper started from the game's chat or a right-click Whisper asks the
-- quiet /who, but only for a chat WM will really open.
local function makeDeps(overrides)
  local log = {}
  local deps = {
    getSettings = function()
      return { autoOpenOutgoing = overrides.autoOpenOutgoing ~= false }
    end,
    isInCombat = function()
      return overrides.inCombat == true
    end,
    isCompetitive = function()
      return overrides.competitive == true
    end,
    isWindowVisible = function()
      return overrides.visible == true
    end,
    ensureWindow = function() end,
    setWindowVisible = function() end,
    focusComposer = function() end,
    selectConversation = function(key)
      log[#log + 1] = "select:" .. key
    end,
    findConversationKeyByName = function(name)
      return overrides.keysByName and overrides.keysByName[name] or nil
    end,
    buildConversationKeyFromName = function(name)
      return "built:" .. name
    end,
    ensureConversation = function(key)
      log[#log + 1] = "ensure:" .. key
    end,
    askWho = function(key)
      log[#log + 1] = "ask:" .. key
    end,
    askWhoForName = function(name, key)
      log[#log + 1] = "askName:" .. name .. ":" .. key
    end,
  }
  return deps, log
end

local function test_send_tell_in_hardware_event_asks_after_ensure_before_select()
  local deps, log = makeDeps({})
  AutoOpenHooks.Create(deps).onSendTell("Thrall", true)
  local order = table.concat(log, ",")
  assert(order == "ensure:built:Thrall,ask:built:Thrall,select:built:Thrall", order)
end

local function test_send_tell_outside_hardware_event_asks_nothing()
  local deps, log = makeDeps({})
  AutoOpenHooks.Create(deps).onSendTell("Thrall")
  local order = table.concat(log, ",")
  assert(order == "ensure:built:Thrall,select:built:Thrall", order)
end

local function test_unrouted_send_tell_asks_nothing()
  local deps, log = makeDeps({ autoOpenOutgoing = false })
  assert(AutoOpenHooks.Create(deps).onSendTell("Thrall", true) == false)
  assert(#log == 0, table.concat(log, ","))
end

local function test_ask_for_tell_uses_existing_key()
  local deps, log = makeDeps({ keysByName = { Thrall = "k1" } })
  AutoOpenHooks.Create(deps).askWhoForTell("Thrall")
  assert(log[1] == "askName:Thrall:k1" and #log == 1, table.concat(log, ","))
end

local function test_ask_for_tell_builds_key_for_stranger_without_creating_chat()
  local deps, log = makeDeps({})
  AutoOpenHooks.Create(deps).askWhoForTell("Thrall")
  assert(log[1] == "askName:Thrall:built:Thrall" and #log == 1, table.concat(log, ","))
end

local function test_ask_for_tell_with_outgoing_auto_open_off_asks_nothing()
  local deps, log = makeDeps({ autoOpenOutgoing = false })
  AutoOpenHooks.Create(deps).askWhoForTell("Thrall")
  assert(#log == 0, table.concat(log, ","))
end

local function test_ask_for_tell_with_outgoing_off_but_window_open_asks()
  local deps, log = makeDeps({ autoOpenOutgoing = false, visible = true })
  AutoOpenHooks.Create(deps).askWhoForTell("Thrall")
  assert(#log == 1, table.concat(log, ","))
end

local function test_ask_for_tell_in_competitive_content_asks_nothing()
  local deps, log = makeDeps({ competitive = true })
  AutoOpenHooks.Create(deps).askWhoForTell("Thrall")
  assert(#log == 0, table.concat(log, ","))
end

local function test_ask_for_tell_in_combat_with_window_hidden_asks_nothing()
  local deps, log = makeDeps({ inCombat = true })
  AutoOpenHooks.Create(deps).askWhoForTell("Thrall")
  assert(#log == 0, table.concat(log, ","))
end

local function test_ask_for_tell_without_name_asks_nothing()
  local deps, log = makeDeps({})
  AutoOpenHooks.Create(deps).askWhoForTell(nil)
  assert(#log == 0, table.concat(log, ","))
end

return function()
  test_send_tell_in_hardware_event_asks_after_ensure_before_select()
  test_send_tell_outside_hardware_event_asks_nothing()
  test_unrouted_send_tell_asks_nothing()
  test_ask_for_tell_uses_existing_key()
  test_ask_for_tell_builds_key_for_stranger_without_creating_chat()
  test_ask_for_tell_with_outgoing_auto_open_off_asks_nothing()
  test_ask_for_tell_with_outgoing_off_but_window_open_asks()
  test_ask_for_tell_in_competitive_content_asks_nothing()
  test_ask_for_tell_in_combat_with_window_hidden_asks_nothing()
  test_ask_for_tell_without_name_asks_nothing()
end

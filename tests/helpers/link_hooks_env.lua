-- Fakes for LinkHooks tests: Blizzard's insert-link functions, a ChatFrameUtil
-- proxy that records every assignment made to it, and a hooksecurefunc that
-- post-hooks like the real one.
--
-- The Blizzard globals LinkHooks touches are kept off _G and served by a
-- metatable on _G, so every assignment to them is recorded, even one that
-- writes Blizzard's own function back (that write is the taint). The fake
-- hooksecurefunc writes the backing tables directly, so its own writes are
-- never counted. Restore() puts every global and _G's metatable back.
local LinkHooksEnv = {}

local MODULE = "WhisperMessenger.UI.Composer.LinkHooks"

-- The test runner's require drops the "WhisperMessenger." prefix, so the module
-- is cached under the short name. Clearing both gives each env a fresh
-- LinkHooks (its register-once flag included).
local function unloadModule()
  package.loaded[MODULE] = nil
  package.loaded[(string.gsub(MODULE, "^WhisperMessenger%.", ""))] = nil
end
local GLOBALS = {
  "hooksecurefunc",
  "GetTime",
  "_wmSuspended",
  "IsModifiedClick",
  "EventUtil",
}
local WATCHED_GLOBALS = {
  "SetItemRef",
  "ChatEdit_GetActiveWindow",
  "ChatEdit_InsertLink",
  "ChatFrameUtil",
  "QuestLogTitleButton_OnClick",
  "AchievementButton_OnClick",
}

local function newChatFrameUtil(env, insertLink)
  local backing = {
    GetActiveWindow = env.originalGetActiveWindow,
    InsertLink = insertLink,
  }
  env.chatFrameUtilBacking = backing
  return setmetatable({}, {
    __index = backing,
    __newindex = function(_, key, value)
      table.insert(env.writes, "ChatFrameUtil." .. key)
      backing[key] = value
    end,
  })
end

local function watchGlobals(env)
  local watched = {}
  for _, key in ipairs(WATCHED_GLOBALS) do
    watched[key] = true
    rawset(_G, key, nil)
  end
  setmetatable(_G, {
    __index = function(_, key)
      if watched[key] then
        return env.globals[key]
      end
      return nil
    end,
    __newindex = function(t, key, value)
      if watched[key] then
        table.insert(env.writes, key)
        env.globals[key] = value
        return
      end
      rawset(t, key, value)
    end,
  })
end

local function installHooksecurefunc(env)
  rawset(_G, "hooksecurefunc", function(target, method, hook)
    local container, key, label = env.globals, target, target
    if type(target) == "table" then
      container, key, label = target, method, "ChatFrameUtil." .. method
      if target == env.chatFrameUtil then
        container = env.chatFrameUtilBacking
      end
    else
      hook = method
    end
    local original = container[key]
    if type(original) ~= "function" then
      error("hooksecurefunc: " .. tostring(key) .. " is not a function")
    end
    env.hooks[label] = hook
    rawset(container, key, function(...)
      local result = original(...)
      hook(...)
      return result
    end)
  end)
end

-- opts.chatFrameUtil = false leaves ChatFrameUtil out (Classic clients).
-- opts.globalInsertLink replaces the stub ChatEdit_InsertLink.
function LinkHooksEnv.New(opts)
  opts = opts or {}
  local env = { saved = {}, savedWatched = {}, hooks = {}, writes = {}, inserts = {}, frameTime = 100 }
  for _, key in ipairs(GLOBALS) do
    env.saved[key] = rawget(_G, key)
  end
  for _, key in ipairs(WATCHED_GLOBALS) do
    env.savedWatched[key] = rawget(_G, key)
  end
  env.savedMetatable = getmetatable(_G)

  -- Set env.blizzardActiveWindow to simulate an open Blizzard chat box.
  env.originalGetActiveWindow = function()
    return env.blizzardActiveWindow
  end
  env.originalInsertLink = function(_text)
    return false
  end
  env.globals = {
    SetItemRef = function(_link, _text, _button, _frame) end,
    ChatEdit_GetActiveWindow = env.originalGetActiveWindow,
    ChatEdit_InsertLink = opts.globalInsertLink or env.originalInsertLink,
    QuestLogTitleButton_OnClick = function(_button, _mouseButton) end,
  }
  if opts.chatFrameUtil ~= false then
    env.chatFrameUtil = newChatFrameUtil(env, env.originalInsertLink)
    env.globals.ChatFrameUtil = env.chatFrameUtil
  end
  watchGlobals(env)
  rawset(_G, "GetTime", function()
    return env.frameTime
  end)
  rawset(_G, "_wmSuspended", nil)
  rawset(_G, "IsModifiedClick", function(action)
    return action == "CHATLINK"
  end)
  rawset(_G, "EventUtil", nil)
  installHooksecurefunc(env)

  unloadModule()
  env.LinkHooks = require(MODULE)

  function env.NewInput()
    local input = { focused = false, shown = true, scripts = {} }
    function input.IsVisible(self)
      return self.shown
    end
    function input.IsShown(self)
      return self.shown
    end
    function input.HasFocus(self)
      return self.focused
    end
    function input.Insert(_self, text)
      table.insert(env.inserts, text)
    end
    function input.HookScript(self, event, fn)
      self.scripts[event] = self.scripts[event] or {}
      table.insert(self.scripts[event], fn)
    end
    return input
  end

  function env.Fire(input, event)
    for _, fn in ipairs(input.scripts[event] or {}) do
      fn(input)
    end
  end

  function env.Reset()
    env.inserts = {}
    env.frameTime = env.frameTime + 1
  end

  function env.Restore()
    setmetatable(_G, env.savedMetatable)
    for _, key in ipairs(WATCHED_GLOBALS) do
      rawset(_G, key, env.savedWatched[key])
    end
    for _, key in ipairs(GLOBALS) do
      rawset(_G, key, env.saved[key])
    end
    unloadModule()
  end

  return env
end

return LinkHooksEnv

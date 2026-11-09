-- Test env for the chat-link source hooks: clears the listed globals, fakes
-- hooksecurefunc (global and table forms, post-hook like the real one) and
-- IsModifiedClick, runs setup(env), registers the module with an insert spy
-- and runs body(env). Every listed global is put back afterwards.
--
-- env.chatLink toggles the CHATLINK modifier. env.pendingAddOns[name] holds
-- the callback waiting for a Blizzard addon when setup installs EventUtil via
-- env.DeferAddOns().
--
-- Taint guard: after setup, the listed globals move off _G into a backing
-- table that a metatable on _G serves, so every assignment to _G from
-- Register and the hooks (even one writing Blizzard's own function back) is
-- recorded; With fails when there is any. Fake Blizzard tables and frames go
-- through env.Watch, which records field writes the same way. The fake
-- hooksecurefunc and test code write with rawset, which is never recorded.
local WriteWatch = require("tests.helpers.write_watch")

local ChatLinkSourcesEnv = {}

local BASE_GLOBALS = { "hooksecurefunc", "IsModifiedClick", "EventUtil" }

-- Globals a test body rawsets stay on _G itself; the moved ones live in backing.
local function hookContainer(container, key, backing)
  if container == _G and rawget(_G, key) == nil then
    return backing
  end
  return container
end

local function postHook(container, key, hook)
  container = WriteWatch.Backing(container)
  local original = rawget(container, key)
  if type(original) ~= "function" then
    error("hooksecurefunc: " .. tostring(key) .. " is not a function")
  end
  rawset(container, key, function(...)
    original(...)
    hook(...)
  end)
end

local function watchGlobals(env, keys)
  env.backing = {}
  for _, key in ipairs(keys) do
    env.backing[key] = rawget(_G, key)
    rawset(_G, key, nil)
  end
  setmetatable(_G, {
    __index = function(_, key)
      return env.backing[key]
    end,
    __newindex = function(_, key, value)
      table.insert(env.writes, tostring(key))
      env.backing[key] = value
    end,
  })
end

-- The test runner's require drops the "WhisperMessenger." prefix, so the
-- module is cached under the short name; clear both for a fresh load.
local function unloadModule(moduleName)
  package.loaded[moduleName] = nil
  package.loaded[(string.gsub(moduleName, "^WhisperMessenger%.", ""))] = nil
end

function ChatLinkSourcesEnv.With(moduleName, globals, setup, body)
  local keys = {}
  for _, key in ipairs(BASE_GLOBALS) do
    table.insert(keys, key)
  end
  for _, key in ipairs(globals) do
    table.insert(keys, key)
  end
  local saved = {}
  for _, key in ipairs(keys) do
    saved[key] = rawget(_G, key)
    rawset(_G, key, nil)
  end
  local savedMetatable = getmetatable(_G)

  local env = { chatLink = true, inserts = {}, pendingAddOns = {}, writes = {} }
  -- Wraps a fake Blizzard table or frame so any field write to it is recorded.
  function env.Watch(label, target)
    return WriteWatch.Wrap(label, target, env.writes)
  end
  function env.DeferAddOns()
    rawset(_G, "EventUtil", {
      ContinueOnAddOnLoaded = function(name, callback)
        env.pendingAddOns[name] = callback
      end,
    })
  end
  rawset(_G, "hooksecurefunc", function(target, method, hook)
    if type(target) == "table" then
      postHook(target, method, hook)
    else
      postHook(hookContainer(_G, target, env.backing), target, method)
    end
  end)
  rawset(_G, "IsModifiedClick", function(action)
    return action == "CHATLINK" and env.chatLink
  end)
  setup(env)
  watchGlobals(env, keys)
  unloadModule(moduleName)
  local ok, err = pcall(function()
    require(moduleName).Register(function(link)
      table.insert(env.inserts, link)
    end)
    body(env)
  end)
  setmetatable(_G, savedMetatable)
  for _, key in ipairs(keys) do
    rawset(_G, key, saved[key])
  end
  unloadModule(moduleName)
  assert(ok, err)
  assert(#env.writes == 0, "hook registration assigned Blizzard slot " .. table.concat(env.writes, ", "))
end

return ChatLinkSourcesEnv

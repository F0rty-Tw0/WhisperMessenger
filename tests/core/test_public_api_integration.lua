-- Allow addon integration off: the API stays published but refuses every call.
local PublicApiEnv = require("tests.helpers.public_api_env")

local unpack = unpack or table.unpack

local function noop() end

-- Calls that succeed on a fresh runtime while integration is allowed.
local CALLS = {
  { "OpenConversation", { "Jaina-Proudmoore" } },
  { "RegisterPanel", { "ca", { title = "Alerts", onShow = noop } } },
  { "SetContactInfo", { "ca", "Jaina-Proudmoore", "x" } },
  { "Block", { "Jaina-Proudmoore" } },
  { "Unblock", { "Jaina-Proudmoore" } },
}

local function boot(settings)
  local runtime, api = PublicApiEnv.Initialize(settings)
  return runtime, api
end

local function each(fn)
  local ok, err = pcall(fn)
  PublicApiEnv.Reset()
  if not ok then
    error(err, 0)
  end
end

local function sortedFunctionKeys(api)
  local keys = {}
  for key, value in pairs(api) do
    if type(value) == "function" then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)
  return table.concat(keys, ",")
end

return function()
  -- test_unset_setting_keeps_the_api_working
  each(function()
    local _, api = boot({})
    for _, call in ipairs(CALLS) do
      assert(api[call[1]](unpack(call[2])) == true, call[1] .. " works by default")
    end
  end)

  -- test_setting_off_refuses_every_call
  each(function()
    local runtime, api = boot({ allowAddonIntegration = false })
    for _, call in ipairs(CALLS) do
      assert(api[call[1]](unpack(call[2])) == false, call[1] .. " is refused")
    end
    for key, value in pairs(api) do
      if type(value) == "function" then
        assert(value() == false, key .. " returns false")
      end
    end
    assert(runtime.isWindowVisible() ~= true, "a refused OpenConversation leaves the window closed")
  end)

  -- test_setting_off_still_publishes_the_same_table_shape
  each(function()
    local _, onApi = boot({})
    local onKeys = sortedFunctionKeys(onApi)
    PublicApiEnv.Reset()
    local _, offApi = boot({ allowAddonIntegration = false })
    assert(type(_G.WhisperMessengerAPI) == "table" and _G.WhisperMessengerAPI == offApi, "the global is still a table")
    assert(offApi.version == 1, "version still published, got " .. tostring(offApi.version))
    assert(sortedFunctionKeys(offApi) == onKeys, "same functions as when on, got " .. sortedFunctionKeys(offApi))
  end)
end

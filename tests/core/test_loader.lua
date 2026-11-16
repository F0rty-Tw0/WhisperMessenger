local Loader = require("WhisperMessenger.Core.Loader")

local BROKEN_MODULE = "tests.core.loader_broken_module"
local BROKEN_REASON = "unexpected symbol near '='"

local function contains(text, needle)
  return string.find(tostring(text), needle, 1, true) ~= nil
end

local function test_load_module_returns_a_loadable_module()
  assert(type(Loader.LoadModule) == "function", "LoadModule should be a function")

  local ok, err = pcall(Loader.LoadModule, "WhisperMessenger.Model.Identity", "Identity")
  assert(ok, "LoadModule should load Identity: " .. tostring(err))
end

local function test_load_module_errors_on_missing_module()
  local ok = pcall(Loader.LoadModule, "nonexistent.module", "Nope")
  assert(not ok, "LoadModule should error on missing module")
end

local function test_load_error_reports_the_underlying_failure()
  package.preload[BROKEN_MODULE] = function()
    error(BROKEN_REASON)
  end

  local ok, err = pcall(Loader.LoadModule, BROKEN_MODULE, "BrokenKey")
  package.preload[BROKEN_MODULE] = nil

  assert(not ok, "a module that fails while loading should raise")
  assert(contains(err, "BrokenKey"), "the error should name the module key: " .. tostring(err))
  assert(contains(err, BROKEN_REASON), "the error should keep the real failure: " .. tostring(err))
end

local function test_load_error_names_the_module_when_require_is_absent()
  local savedRequire = _G.require
  _G.require = nil

  local ok, err = pcall(Loader.LoadModule, "nonexistent.module", "Nope")
  _G.require = savedRequire

  assert(not ok, "LoadModule should error when nothing can load the module")
  assert(contains(err, "Nope module not available"), "the error should name the module key: " .. tostring(err))
end

return function()
  test_load_module_returns_a_loadable_module()
  test_load_module_errors_on_missing_module()
  test_load_error_reports_the_underlying_failure()
  test_load_error_names_the_module_when_require_is_absent()
end

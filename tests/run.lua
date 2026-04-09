-- Lua 5.1 compat: plain Lua 5.1 (used by CI) does not provide table.unpack.
-- WoW's runtime and LuaJIT both do. Polyfill it here so any test file can
-- use table.unpack regardless of which interpreter run.lua is invoked from.
table.unpack = table.unpack or unpack

package.path = table.concat({
  "./?.lua",
  "./?/init.lua",
  package.path,
}, ";")

local rawRequire = require

local function normalizeModuleName(name)
  if type(name) == "string" and string.find(name, "WhisperMessenger.", 1, true) == 1 then
    return string.sub(name, string.len("WhisperMessenger.") + 1)
  end

  return name
end

require = function(name)
  return rawRequire(normalizeModuleName(name))
end
_G.require = require

local path = ...
assert(path, "expected a test file path")

local ok, testFn = pcall(dofile, path)
if not ok then
  error(testFn)
end

if type(testFn) == "function" then
  testFn()
end

print("PASS " .. path)

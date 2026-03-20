local Loader = require("WhisperMessenger.Core.Loader")

return function()
  assert(type(Loader.LoadModule) == "function", "LoadModule should be a function")

  local ok, err = pcall(Loader.LoadModule, "WhisperMessenger.Model.Identity", "Identity")
  assert(ok, "LoadModule should load Identity: " .. tostring(err))

  local ok2, err2 = pcall(Loader.LoadModule, "nonexistent.module", "Nope")
  assert(not ok2, "LoadModule should error on missing module")
end

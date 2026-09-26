-- The live client exposes a global `require` that throws for unknown modules,
-- so every file's `ns.X or require(...)` fallback must never be reached:
-- each dependency has to load earlier in the TOC.
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local savedRequire = require
  local savedCreateFrame = _G.CreateFrame
  local factory = FakeUI.NewFactory()

  rawset(_G, "CreateFrame", factory.CreateFrame)
  _G.require = function(moduleName)
    error("Invalid import: No module with that name exists (" .. tostring(moduleName) .. ")")
  end

  local ns = {}
  local ok, err = pcall(function()
    for line in io.lines("WhisperMessenger.toc") do
      if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
        local chunk = assert(loadfile(line))
        local loaded, loadErr = pcall(chunk, "WhisperMessenger", ns)
        assert(loaded, line .. ": " .. tostring(loadErr))
      end
    end
  end)

  _G.require = savedRequire
  rawset(_G, "CreateFrame", savedCreateFrame)

  assert(ok, tostring(err))
end

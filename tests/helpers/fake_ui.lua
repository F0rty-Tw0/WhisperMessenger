-- Slim facade: composes sub-modules into the public FakeUI API.
-- Sub-modules are plain Lua files that use require(), not the WoW addon pattern.

local FrameModule = require("tests.helpers.fake_ui.frame")
local FontObjects = require("tests.helpers.fake_ui.fontobjects")

-- Install _G.CreateFont, standard font objects, and _G.C_Timer once.
FontObjects.Install()

local FakeUI = {}

function FakeUI.NewFactory()
  local factory = {}
  factory.CreateFrame = FrameModule.makeCreateFrame()
  return factory
end

-- Install a default _G.CreateFrame backed by FakeUI.
-- run_test.py provides a no-op fallback; tests that load the addon's bootstrap
-- chain (which calls _G.CreateFrame at top level -> :RegisterEvent at install
-- time) need real frame methods. Tests requiring richer behavior may still
-- rawset their own override before loading the addon.
do
  local _sharedFactory = FakeUI.NewFactory()
  rawset(_G, "CreateFrame", function(frameType, name, parent, template)
    return _sharedFactory.CreateFrame(frameType, name, parent, template)
  end)
end

return FakeUI

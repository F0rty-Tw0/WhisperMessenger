local FakeUI = require("tests.helpers.fake_ui")
local FakeChatLines = require("tests.helpers.fake_chat_lines")
local AddonEventFrame = require("WhisperMessenger.Core.Bootstrap.AddonEventFrame")

return function()
  local restore = FakeChatLines.Install({})

  -- test_install_also_installs_lockdown_catcher

  do
    local factory = FakeUI.NewFactory()
    local Bootstrap = {}
    local loadFrame = AddonEventFrame.Install({ Bootstrap = Bootstrap, createFrame = factory.CreateFrame })
    assert(loadFrame == Bootstrap._loadFrame, "setup: install must return the load frame")
    assert(type(Bootstrap._lockdownCatcher) == "table", "install must set Bootstrap._lockdownCatcher")
    assert(type(Bootstrap._lockdownCatcher.handle) == "function", "the installed catcher must expose handle")
  end

  restore()
end

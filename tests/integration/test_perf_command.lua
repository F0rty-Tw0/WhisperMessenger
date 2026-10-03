-- /wmsg perf prints the debug counters to the chat frame and leaves the
-- messenger window alone.

local Bootstrap = require("WhisperMessenger.Bootstrap")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedSlashCmdList = _G.SlashCmdList
  local savedChatFrame = rawget(_G, "DEFAULT_CHAT_FRAME")
  local savedProfiler = rawget(_G, "C_AddOnProfiler")

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  rawset(_G, "C_AddOnProfiler", nil)

  local runtime = Bootstrap.Initialize(factory, {
    accountState = { schemaVersion = 1, conversations = {}, contacts = {}, pendingHydration = {} },
    characterState = {
      window = { x = 0, y = 0, width = 900, height = 560, minimized = false },
      icon = { anchorPoint = "TOPLEFT", relativePoint = "TOPLEFT", x = 25, y = -40 },
    },
    localProfileId = "me",
  })

  local printed = {}
  rawset(_G, "DEFAULT_CHAT_FRAME", {
    AddMessage = function(_, text)
      printed[#printed + 1] = text
    end,
  })

  _G.SlashCmdList["WHISPERMESSENGER"]("perf")

  assert(#printed == 7, "perf prints one line per counter, got " .. #printed)
  assert(string.find(printed[1], "groupLines", 1, true), "first line names groupLines: " .. tostring(printed[1]))
  assert(runtime.window == nil, "perf must not open the messenger window")

  rawset(_G, "DEFAULT_CHAT_FRAME", savedChatFrame)
  rawset(_G, "C_AddOnProfiler", savedProfiler)
  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
end

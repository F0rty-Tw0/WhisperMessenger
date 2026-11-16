-- /wmsg perf prints the debug counters to the chat frame and leaves the
-- messenger window alone.

local Bootstrap = require("WhisperMessenger.Bootstrap")
local FakeUI = require("tests.helpers.fake_ui")
local Store = require("WhisperMessenger.Model.ConversationStore")

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
    accountState = { schemaVersion = 1, conversations = {} },
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

  assert(#printed == 9, "perf prints one line per counter plus the stored count, got " .. #printed)
  assert(string.find(printed[1], "groupLines", 1, true), "first line names groupLines: " .. tostring(printed[1]))
  assert(string.find(printed[9], "stored messages: 0 in 0 chats", 1, true), "an empty history reads as zero: " .. tostring(printed[9]))
  assert(runtime.window == nil, "perf must not open the messenger window")

  -- test_perf_counts_messages_saved_since_login
  local sentAt = os.time()
  for index = 1, 3 do
    Store.AppendIncoming(
      runtime.store,
      "me::WOW::arthas-area52",
      { id = "a" .. index, direction = "in", kind = "user", text = "hi", sentAt = sentAt },
      false
    )
  end
  Store.AppendIncoming(runtime.store, "me::WOW::jaina-area52", { id = "j1", direction = "in", kind = "user", text = "hey", sentAt = sentAt }, false)
  printed = {}

  _G.SlashCmdList["WHISPERMESSENGER"]("perf")

  assert(
    string.find(printed[#printed], "stored messages: 4 in 2 chats", 1, true),
    "new messages show in the stored count: " .. tostring(printed[#printed])
  )

  rawset(_G, "DEFAULT_CHAT_FRAME", savedChatFrame)
  rawset(_G, "C_AddOnProfiler", savedProfiler)
  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
end

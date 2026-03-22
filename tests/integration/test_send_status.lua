local Bootstrap = require("WhisperMessenger.Bootstrap")
local Availability = require("WhisperMessenger.Transport.Availability")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
  local guid = "Player-3676-0ABCDEF0"
  local availabilityRequests = {}

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil

  local runtime = Bootstrap.Initialize(factory, {
    accountState = {
      schemaVersion = 1,
      conversations = {
        ["me::WOW::arthas-area52"] = {
          displayName = "Arthas-Area52",
          guid = guid,
          unreadCount = 1,
          lastPreview = "Need help?",
          lastActivityAt = 20,
          channel = "WOW",
          messages = {
            {
              direction = "in",
              kind = "user",
              playerName = "Arthas-Area52",
              text = "Need help?",
              sentAt = 1,
              guid = guid,
            },
          },
        },
      },
      contacts = {},
      pendingHydration = {},
    },
    characterState = nil,
    localProfileId = "me",
    chatApi = {
      RequestCanLocalWhisperTarget = function(requestGuid)
        table.insert(availabilityRequests, requestGuid)
      end,
    },
  })

  runtime.availabilityByGUID[guid] = Availability.FromStatus("Offline")
  runtime.toggle()
  runtime.window.contacts.rows[1].scripts.OnClick()

  assert(availabilityRequests[1] == guid)
  assert(runtime.window.conversation.statusBanner.text == "Offline")

  runtime.window.composer.input:SetText("hello")
  runtime.window.composer.sendButton.scripts.OnClick()

  -- Enriched availability (Offline) takes precedence over sendStatusByConversation
  -- in the header banner. The send status is still tracked in runtime for other uses.
  assert(runtime.window.conversation.statusBanner.text == "Offline")
  local pending = runtime.pendingOutgoing["me::WOW::arthas-area52"]
  assert(pending == nil or #pending == 0)

  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
end

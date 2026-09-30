local Bootstrap = require("WhisperMessenger.Bootstrap")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local FakeUI = require("tests.helpers.fake_ui")

-- Two stored Battle.net friends that share a name keep their numbers from
-- login on, before any contact list or icon has been built, so an early
-- "is now online" line can't hide which friend it means.
local function bnetConversation(battleTag)
  return {
    displayName = battleTag,
    battleTag = battleTag,
    channel = "BN",
    unreadCount = 0,
    lastActivityAt = 10,
    messages = {},
  }
end

local function initialize(iconMode)
  local factory = FakeUI.NewFactory()
  local savedUIParent, savedSlash = _G.UIParent, _G.SlashCmdList
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  DisplayName.SetBattleTags({})
  Bootstrap.Initialize(factory, {
    accountState = {
      schemaVersion = 1,
      settings = { iconMode = iconMode },
      conversations = {
        ["bnet::Mike#1234"] = bnetConversation("Mike#1234"),
        ["bnet::Mike#5678"] = bnetConversation("Mike#5678"),
      },
      contacts = {},
      pendingHydration = {},
    },
    characterState = {
      window = { x = 0, y = 0, width = 900, height = 560, minimized = false },
      icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    },
    localProfileId = "me",
  })
  _G.UIParent, _G.SlashCmdList = savedUIParent, savedSlash
end

return function()
  for _, iconMode in ipairs({ "widget", "minimap", "both", "none" }) do
    -- test_clashing_battletags_known_right_after_login
    initialize(iconMode)
    assert(DisplayName.Format("Mike#1234") == "Mike#1234", "clash known after login with iconMode " .. iconMode)
  end
end

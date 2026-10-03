-- Channel chats pause in mythic content, encounters, competitive content and
-- chat-messaging lockdown; Classic clients without the lockdown API never
-- report one.
return function()
  local Bootstrap = require("WhisperMessenger.Bootstrap")
  local FakeUI = require("tests.helpers.fake_ui")
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedChatInfo = _G.C_ChatInfo
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.C_ChatInfo = {}

  local runtime = Bootstrap.Initialize(factory, {
    accountState = { schemaVersion = 1, conversations = {}, contacts = {}, pendingHydration = {}, settings = {} },
    characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
  })
  local function reset()
    Bootstrap._inMythicContent = false
    Bootstrap._inEncounter = false
    Bootstrap._inCompetitiveContent = false
  end

  -- test_open_world_without_lockdown_api_is_not_suspended
  reset()
  assert(runtime.isChannelIngestSuspended() == false, "open world on a client without the lockdown API ingests channels")

  -- test_restricted_content_suspends
  for _, flag in ipairs({ "_inMythicContent", "_inEncounter", "_inCompetitiveContent" }) do
    reset()
    Bootstrap[flag] = true
    assert(runtime.isChannelIngestSuspended() == true, flag .. " suspends channel chats")
  end

  -- test_chat_lockdown_suspends
  reset()
  local lockdownThrows = false
  _G.C_ChatInfo.InChatMessagingLockdown = function()
    if lockdownThrows then
      error("unavailable")
    end
    return true
  end
  assert(runtime.isChannelIngestSuspended() == true, "chat-messaging lockdown suspends channel chats")

  -- test_throwing_lockdown_api_is_not_suspended
  lockdownThrows = true
  assert(runtime.isChannelIngestSuspended() == false, "a throwing lockdown check never suspends")

  reset()
  _G.C_ChatInfo = savedChatInfo
  _G.UIParent = savedUIParent
end
